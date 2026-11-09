AddCSLuaFile()

-- Evil Morty's eyepatch: LMB puts it on or takes it off, RMB opens the editor (where it sits on the head). Worn, it stays
-- on with any weapon in hand; its abilities are on a wheel of their own (rmpg/cl_patch.lua, hold the mouse wheel).
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("patch_name") or "Evil Morty's Eyepatch"
SWEP.Author = "Evil Morty"
SWEP.Purpose = "See where portals lead, see through walls, hack whatever you look at."
SWEP.Instructions = "LMB - put on / take off, RMB - where it sits, hold the mouse wheel - abilities"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_eyepatch.png"

SWEP.Slot = 5
SWEP.SlotPos = 8
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/eyepatch.mdl"
SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.HoldType = "slam"

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
	self:DrawShadow(false)
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
	self:SetNextPrimaryFire(CurTime() + 0.4)
	return true
end

function SWEP:Holster()
	if CLIENT and IsValid(self.PadEnt) then self.PadEnt:Remove() end
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.8)
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)
	self.IdleAt = CurTime() + 0.6
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	if SERVER then RMPG.PatchWear(self:GetOwner(), not self:GetOwner():GetNW2Bool("RMPG_Patch")) end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.5)
	if CLIENT and IsFirstTimePredicted() then RMPG.OpenPatchEditor() end
	if SERVER and game.SinglePlayer() then self:CallOnClient("OpenEditor") end
end

function SWEP:OpenEditor()
	if CLIENT then RMPG.OpenPatchEditor() end
end

function SWEP:Think()
	if self.IdleAt and CurTime() >= self.IdleAt then
		self.IdleAt = nil
		self:SendWeaponAnim(ACT_SLAM_DETONATOR_IDLE)
	end
end

if SERVER then return end

local INVIS = CreateMaterial("rmpg_invisible_patch", "UnlitGeneric", {
	["$translucent"] = 1,
	["$alpha"] = 0,
	["$vertexalpha"] = 1,
})
local DET_CENTER = Vector(9.49, 64.64, 21.68) -- the detonator in its bone's space (c_slam.mdl): where the hand holds it
local VM_SCALE = 1.7

function SWEP:OnRemove()
	if IsValid(self.PadEnt) then self.PadEnt:Remove() end
end

function SWEP:PreDrawViewModel()
	-- hide the detonator, keep the animated hands
	render.ModelMaterialOverride(INVIS)
end

function SWEP:PostDrawViewModel(vm)
	render.ModelMaterialOverride()
	if LocalPlayer():GetNW2Bool("RMPG_Patch") then return end
	local bone = vm:LookupBone("Detonator")
	local m = bone and vm:GetBoneMatrix(bone)
	if not m then return end
	if not IsValid(self.PadEnt) then
		self.PadEnt = ClientsideModel(self.WorldModel, RENDERGROUP_OPAQUE)
		if not IsValid(self.PadEnt) then return end
		self.PadEnt:SetNoDraw(true)
		self.PadEnt:SetModelScale(VM_SCALE, 0)
	end
	local ea = EyeAngles()
	self.PadEnt:SetPos(LocalToWorld(DET_CENTER, angle_zero, m:GetTranslation(), m:GetAngles()))
	self.PadEnt:SetAngles(Angle(-ea.p, ea.y + 180, 0))
	self.PadEnt:SetupBones()
	self.PadEnt:DrawModel()
end

hook.Add("PreDrawPlayerHands", "rmpg_patch_hands", function(hands, vm, ply, wep)
	if IsValid(wep) and wep:GetClass() == "weapon_rmpg_eyepatch" then render.ModelMaterialOverride() end
end)

function SWEP:DrawWorldModel()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		self:DrawModel()
		return
	end
	if owner:GetNW2Bool("RMPG_Patch") then return end
	local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = bone and owner:GetBoneMatrix(bone)
	if not m then return end
	self:SetRenderOrigin(m:GetTranslation() + m:GetForward() * 3.5 + m:GetRight() * 1.5)
	self:SetRenderAngles(m:GetAngles())
	self:DrawModel()
	self:SetRenderOrigin()
	self:SetRenderAngles()
end

function SWEP:DrawHUD()
	if not RMPG.CL.hud:GetBool() then return end
	local w, h = 420, 62
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	local worn = LocalPlayer():GetNW2Bool("RMPG_Patch")
	local ui = RMPG.PatchUI
	RMPG.HoloBox(x, y, w, h, ui.bg, ui.accent)
	RMPG.HoloText(RMPG.T(worn and "patch_hud_on" or "patch_hud_off"), "RMPG_BodyB", x + 14, y + 12, ui.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(RMPG.T("patch_hud_hint"), "RMPG_Small", x + 14, y + 38, ui.muted)
end

local ICON = Material("entities/weapon_rmpg_eyepatch.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, a)
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(ICON)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
