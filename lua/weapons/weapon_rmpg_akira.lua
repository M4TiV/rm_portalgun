AddCSLuaFile()

-- The laser arm's hand. The shots are RMPG.ArmShot and the burst RMPG.ArmFire in rmpg/sv_implants.lua: this is put in
-- your hand while you shoot or it burns, for the raised palm (LMB shoots too), and taken away again after. First person uses the left hand of the HL2 SLAM with the
-- fingers opened and the arm raised (dev/tools/palm_pose.py works out the numbers).
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("arm_name") or "Akira Laser (W.I.P)"
SWEP.Author = "Evil Morty"
SWEP.Purpose = "The laser in your arm."
SWEP.Instructions = "Fired with the button from the Implants tab."
SWEP.Category = "Rick and Morty"
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/rmpg_arm_chip.png"

SWEP.Slot = 5
SWEP.SlotPos = 9
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.HoldType = "magic"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.1)
	if SERVER and IsValid(self:GetOwner()) then RMPG.ArmShot(self:GetOwner()) end
end
function SWEP:SecondaryAttack() end
function SWEP:Reload() end

-- A burst cannot be put away halfway
function SWEP:Holster()
	local ply = self:GetOwner()
	return not IsValid(ply) or not ply:GetNW2Bool("RMPG_ArmOn", false)
end

if SERVER then
	function SWEP:OnDrop()
		self:Remove()
	end

	return
end

---------------------------------------------------------------------------
-- Client: the hand with its fingers open, raised while it fires
---------------------------------------------------------------------------

local RAISED, SHIFT = Angle(-56.2, 61, 1.7), Vector(18, -18, -20)
-- Each finger joint back to straight from how it is closed round the detonator (dev/tools/palm_pose.py)
local FINGERS = {
	["ValveBiped.Bip01_L_Finger41"] = Angle(0, 60.5, 0), ["ValveBiped.Bip01_L_Finger42"] = Angle(0, 67.8, 0),
	["ValveBiped.Bip01_L_Finger31"] = Angle(0, 54.1, 0), ["ValveBiped.Bip01_L_Finger32"] = Angle(0, 73.4, 0),
	["ValveBiped.Bip01_L_Finger2"] = Angle(-2.8, 0.7, -4.6), ["ValveBiped.Bip01_L_Finger21"] = Angle(0.3, 54.3, 0), ["ValveBiped.Bip01_L_Finger22"] = Angle(0.2, 57.1, 0),
	["ValveBiped.Bip01_L_Finger1"] = Angle(5.6, -12.9, 3.2), ["ValveBiped.Bip01_L_Finger11"] = Angle(0.2, 26.6, 0), ["ValveBiped.Bip01_L_Finger12"] = Angle(0.1, 26, 0),
	["ValveBiped.Bip01_L_Finger0"] = Angle(5.4, 10.1, -1.7), ["ValveBiped.Bip01_L_Finger01"] = Angle(0, -14.6, 0), ["ValveBiped.Bip01_L_Finger02"] = Angle(0, -20.8, 0),
}

-- The viewmodel is shared by all weapons, so the fingers are closed again as soon as this one is not in hand
local open = false

local function SetFingers(vm, on)
	for name, ang in pairs(FINGERS) do
		local b = vm:LookupBone(name)
		if b then vm:ManipulateBoneAngles(b, on and ang or angle_zero) end
	end
	open = on
end

hook.Add("Think", "rmpg_arm_fingers", function()
	if not open then return end
	local me = LocalPlayer()
	local w = IsValid(me) and me:GetActiveWeapon()
	if IsValid(w) and w:GetClass() == RMPG.ARM then return end
	local vm = IsValid(me) and me:GetViewModel()
	if IsValid(vm) then SetFingers(vm, false) end
	open = false
end)

function SWEP:GetViewModelPosition(pos, ang)
	local t = RealTime()
	local dt = math.min(t - (self.RaiseT or t), 0.1)
	self.RaiseT = t
	local ply = self:GetOwner()
	local up = IsValid(ply) and (ply:GetNW2Bool("RMPG_ArmOn", false) or ply:GetNW2Bool("RMPG_ArmHand", false))
	self.Raise = math.Approach(self.Raise or 0, up and 1 or 0.3, dt * 9)
	local k = self.Raise * self.Raise * (3 - 2 * self.Raise)
	local wp, wa = LocalToWorld(SHIFT, RAISED, pos, ang)
	return LerpVector(k, pos, wp), LerpAngle(k, ang, wa)
end

function SWEP:PreDrawViewModel(vm)
	if not open then SetFingers(vm, true) end
	RMPG.HideSlam()
end

function SWEP:PostDrawViewModel()
	render.ModelMaterialOverride()
end

function SWEP:DrawWorldModel() end

local ICON = Material("entities/rmpg_arm_chip.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, a)
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(ICON)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
