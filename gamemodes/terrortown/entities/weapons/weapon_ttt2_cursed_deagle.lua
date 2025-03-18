--Shamelessly taken from the Sidekick Deagle

if not CURSED then
	return
end

SWEP.Base = "weapon_tttbase"

SWEP.Spawnable = true
SWEP.AutoSpawnable = false
SWEP.AdminSpawnable = true

SWEP.HoldType = "revolver"

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

if SERVER then
	AddCSLuaFile()
	
	resource.AddFile("materials/vgui/ttt/icon_cursed_deagle.vmt")
	
	util.AddNetworkString("ttt_cursed_deagle_refilled")
	util.AddNetworkString("ttt_cursed_deagle_miss")
end

if CLIENT then
	SWEP.PrintName = "Cursed Deagle"
	SWEP.Author = "BlackMagicFine"
	
	SWEP.ViewModelFOV = 54
	SWEP.ViewModelFlip = false
	
	SWEP.Category = "Deagle"
	SWEP.Icon = "vgui/ttt/icon_cursed_deagle.vtf"
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "wep_cursed_deagle",
		desc = "wep_cursed_deagle_desc"
	}
end

--Gun stats
SWEP.Primary.Delay = 1
SWEP.Primary.Recoil = 6
SWEP.Primary.Automatic = false
SWEP.Primary.NumShots = 1
SWEP.Primary.Damage = 0
SWEP.Primary.Cone = 0.00001
SWEP.Primary.Ammo = ""
SWEP.Primary.ClipSize = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.DefaultClip = 1

--Misc.
SWEP.InLoadoutFor = nil
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.UseHands = true
SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true
SWEP.globalLimited = true
SWEP.NoRandom = true

--Model
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.Weight = 5
SWEP.Primary.Sound = Sound("Weapon_Deagle.Single")

--Iron sights
SWEP.IronSightsPos = Vector(-6.361, -3.701, 2.15)
SWEP.IronSightsAng = Vector(0, 0, 0)

local function CursedDeagleRefilled(wep)
	if not IsValid(wep) then
		return
	end
	
	local text = LANG.GetTranslation("RECHARGED_CURSED_DEAGLE")
	MSTACK:AddMessage(text)
	
	STATUS:RemoveStatus("ttt2_cursed_deagle_reloading")
	net.Start("ttt_cursed_deagle_refilled")
	net.WriteEntity(wep)
	net.SendToServer()
end

local function CursedDeagleCallback(attacker, tr, dmg)
	if CLIENT then return end
	
	local target = tr.Entity
	
	--Invalid shot return
	if GetRoundState() ~= ROUND_ACTIVE or not IsValid(attacker) or not attacker:IsPlayer() or not attacker:IsTerror() then
		return
	end
	
	local target_is_valid_ply = IsValid(target) and target:IsPlayer() and target:IsTerror()
	local can_affect_det = GetConVar("ttt2_cursed_deagle_affect_det"):GetBool()
	if not target_is_valid_ply or (not can_affect_det and (target:GetBaseRole() == ROLE_DETECTIVE or target:GetSubRole() == ROLE_DEFECTIVE)) or target:GetSubRole() == ROLE_CURSED or target.curs_last_tagged ~= nil then
		--Miss or failed: start cooldown timer and return
		if GetConVar("ttt2_cursed_deagle_refill_time"):GetInt() > 0 then
			net.Start("ttt_cursed_deagle_miss")
			net.Send(attacker)
		end
		
		if target_is_valid_ply then
			if target:GetSubRole() == ROLE_CURSED then
				LANG.Msg(attacker, "ALREADY_CURSED_DEAGLE", {name = target:GetName()}, MSG_MSTACK_WARN)
			elseif not can_affect_det and (target:GetBaseRole() == ROLE_DETECTIVE or target:GetSubRole() == ROLE_DEFECTIVE) then
				LANG.Msg(attacker, "NO_DET_CURSED_DEAGLE", {name = target:GetName()}, MSG_MSTACK_WARN)
			elseif target.curs_last_tagged ~= nil then
				LANG.Msg(attacker, "PROTECTED_CURSED_DEAGLE", {name = target:GetName()}, MSG_MSTACK_WARN)
			end
		end
		
		return
	end
	
	target:SetRole(ROLE_CURSED)
	--Call this whenever a role change has occurred.
	SendFullStateUpdate()
	
	local deagle = attacker:GetWeapon("weapon_ttt2_cursed_deagle")
	if IsValid(deagle) then
		deagle:Remove()
	end
	
	return true
end

function SWEP:ShootBullet(dmg, recoil, numbul, cone)
	cone = cone or 0.01
	
	local bullet = {}
	bullet.Num = 1
	bullet.Src = self:GetOwner():GetShootPos()
	bullet.Dir = self:GetOwner():GetAimVector()
	bullet.Spread = Vector(cone, cone, 0)
	bullet.Tracer = 0
	bullet.TracerName = self.Tracer or "Tracer"
	bullet.Force = 10
	bullet.Damage = 0
	bullet.Callback = CursedDeagleCallback
	
	self:GetOwner():FireBullets(bullet)
	self.BaseClass.ShootBullet(self, dmg, recoil, numbul, cone)
end

function SWEP:OnRemove()
	if CLIENT then
		STATUS:RemoveStatus("ttt2_cursed_deagle_reloading")
		
		timer.Stop("ttt2_cursed_deagle_refill_timer")
	end
end

if CLIENT then
	hook.Add("Initialize", "InitializeCursedDeagle", function()
		STATUS:RegisterStatus("ttt2_cursed_deagle_reloading", {
			hud = Material("vgui/ttt/hud_icon_deagle.png"),
			type = "bad"
		})
	end)
	
	net.Receive("ttt_cursed_deagle_miss", function()
		local client = LocalPlayer()
		if not IsValid(client) or not client:IsTerror() or not client:HasWeapon("weapon_ttt2_cursed_deagle") then
			return
		end
		
		local wep = client:GetWeapon("weapon_ttt2_cursed_deagle")
		if not IsValid(wep) then
			return
		end
		
		local cooldown = GetConVar("ttt2_cursed_deagle_refill_time"):GetInt()
		STATUS:AddTimedStatus("ttt2_cursed_deagle_reloading", cooldown, true)
		timer.Create("ttt2_cursed_deagle_refill_timer", cooldown, 1, function()
			if not IsValid(wep) then
				return
			end
			
			CursedDeagleRefilled(wep)
		end)
	end)
else --SERVER
	net.Receive("ttt_cursed_deagle_refilled", function()
		local wep = net.ReadEntity()
		
		if not IsValid(wep) then
			return
		end
		
		wep:SetClip1(1)
	end)
end