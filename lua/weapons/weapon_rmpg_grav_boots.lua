AddCSLuaFile()

-- Gravity boots: RMB turns them on or off. On, they stay on with any weapon in hand: walls and ceilings become the floor
-- (rmpg/sh_boots.lua does the walking).
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("boots_name") or "Gravity Boots"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "Walls are just floors that have not met you yet."
SWEP.Instructions = "RMB - on / off. Walk into a wall to stand on it, walk over an edge to go round it."
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_grav_boots.png"

SWEP.Slot = 5
SWEP.SlotPos = 9
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/grav_boots_prop.mdl"
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
	return true
end

function SWEP:Holster()
	if CLIENT and IsValid(self.PairEnt) then self.PairEnt:Remove() end
	return true
end

function SWEP:PrimaryAttack() end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.6)
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)
	self.IdleAt = CurTime() + 0.6
	local ply = self:GetOwner()
	ply:SetAnimation(PLAYER_ATTACK1)
	if SERVER then RMPG.BootsSet(ply, not RMPG.BootsOn(ply)) end
end

function SWEP:Think()
	if self.IdleAt and CurTime() >= self.IdleAt then
		self.IdleAt = nil
		self:SendWeaponAnim(ACT_SLAM_DETONATOR_IDLE)
	end
end

if SERVER then return end

local INVIS = CreateMaterial("rmpg_invisible_boots", "UnlitGeneric", {
	["$translucent"] = 1,
	["$alpha"] = 0,
	["$vertexalpha"] = 1,
})
local DET_CENTER = Vector(9.49, 64.64, 21.68) -- the detonator in its bone's space (c_slam.mdl): where the hand holds it

function SWEP:OnRemove()
	if IsValid(self.PairEnt) then self.PairEnt:Remove() end
end

function SWEP:PreDrawViewModel()
	-- hide the detonator, keep the animated hands
	render.ModelMaterialOverride(INVIS)
end

function SWEP:PostDrawViewModel(vm)
	render.ModelMaterialOverride()
	if RMPG.BootsOn(LocalPlayer()) then return end -- they are on the feet now
	local bone = vm:LookupBone("Detonator")
	local m = bone and vm:GetBoneMatrix(bone)
	if not m then return end
	if not IsValid(self.PairEnt) then
		self.PairEnt = ClientsideModel(self.WorldModel, RENDERGROUP_OPAQUE)
		if not IsValid(self.PairEnt) then return end
		self.PairEnt:SetNoDraw(true)
		self.PairEnt:SetModelScale(0.42, 0)
	end
	local _, a = LocalToWorld(vector_origin, Angle(0, 150, 0), vector_origin, vm:GetAngles())
	self.PairEnt:SetPos(LocalToWorld(DET_CENTER, angle_zero, m:GetTranslation(), m:GetAngles()) - a:Up() * 1.5)
	self.PairEnt:SetAngles(a)
	self.PairEnt:SetupBones()
	self.PairEnt:DrawModel()
end

hook.Add("PreDrawPlayerHands", "rmpg_boots_hands", function(hands, vm, ply, wep)
	if IsValid(wep) and wep:GetClass() == "weapon_rmpg_grav_boots" then render.ModelMaterialOverride() end
end)

function SWEP:DrawWorldModel()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		self:DrawModel()
		return
	end
	if RMPG.BootsOn(owner) then return end
	local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = bone and owner:GetBoneMatrix(bone)
	if not m then return end
	self:SetModelScale(0.5, 0)
	self:SetRenderOrigin(m:GetTranslation() + m:GetForward() * 4 + m:GetRight() * 2)
	self:SetRenderAngles(m:GetAngles())
	self:DrawModel()
	self:SetRenderOrigin()
	self:SetRenderAngles()
end

function SWEP:DrawHUD()
	if not RMPG.CL.hud:GetBool() then return end
	local w, h = 420, 62
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	local on = RMPG.BootsOn(LocalPlayer())
	local ac = Color(255, 150, 60)
	RMPG.HoloBox(x, y, w, h, Color(20, 10, 4, 215), ac)
	RMPG.HoloText(RMPG.T(on and "boots_hud_on" or "boots_hud_off"), "RMPG_BodyB", x + 14, y + 12, Color(255, 235, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(RMPG.T("boots_hud_hint"), "RMPG_Small", x + 14, y + 38, Color(225, 180, 140))
end

local ICON = Material("entities/weapon_rmpg_grav_boots.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, a)
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(ICON)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
