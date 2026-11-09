AddCSLuaFile()

-- A regular old plumbus. Everyone has one at home. LMB squeezes it. RMB uses it: you take it by the neck or by the body,
-- and pointed at a worm it is given to the worm, which becomes your pet for good (entities/rmpg_brain_worm.lua). First
-- person uses the HL2 SLAM hands with our model in the fist (rmpg/cl_items.lua).
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("plumbus_name") or "Plumbus"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "Everyone has a plumbus in their home."
SWEP.Instructions = "LMB - squeeze, RMB - use"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_plumbus.png"

SWEP.Slot = 5
SWEP.SlotPos = 8
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/plumbus.mdl"
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

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "Squeezed")
	self:NetworkVar("Float", 1, "IdleAt")
	self:NetworkVar("Bool", 0, "NeckGrip") -- held by the narrow part
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
	return true
end

function SWEP:Think()
	local t = self:GetIdleAt()
	if t > 0 and CurTime() >= t then
		self:SetIdleAt(0)
		self:SendWeaponAnim(ACT_SLAM_DETONATOR_IDLE)
	end
end

function SWEP:PrimaryAttack()
	local now = CurTime()
	self:SetNextPrimaryFire(now + 0.18)
	self:SetSqueezed(now)
	self:SetIdleAt(now + 0.6)
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)
	if CLIENT and (game.SinglePlayer() or not IsFirstTimePredicted()) then return end
	self:EmitSound(string.format(RMPG.SND.plumbus, math.random(1, 3)), 65, math.random(130, 170))
end

-- RMB: into the mouth of the worm in front of you, or with no worm there the other grip
function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.4)
	if CLIENT then return end
	local ply = self:GetOwner()
	local tr = util.TraceHull({ start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 170, mins = Vector(-8, -8, -8), maxs = Vector(8, 8, 8), filter = ply, mask = MASK_SHOT_HULL })
	local e = tr.Entity
	local worm = IsValid(e) and (e.Worm or (e:GetClass() == RMPG.WORM and e))
	if not IsValid(worm) or worm:GetMaster() == ply then
		self:SetNeckGrip(not self:GetNeckGrip())
		return
	end
	if worm:Tame(ply) then
		RMPG.Notify(ply, "n_worm_tamed", nil, 2)
		ply:StripWeapon(self:GetClass())
	end
end

if SERVER then return end

function SWEP:PreDrawViewModel()
	RMPG.HideSlam()
end

function SWEP:PostDrawViewModel(vm)
	RMPG.DrawPlumbusVM(self, vm)
end

function SWEP:DrawWorldModel()
	self:SetModelScale(IsValid(self:GetOwner()) and 0.6 or 1, 0)
	RMPG.DrawHeld(self, 0, self:GetNeckGrip() and 4.4 or 0)
end

function SWEP:DrawHUD()
	if not RMPG.CL.hud:GetBool() then return end
	local w, h = 340, 44
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	local col = Color(255, 150, 165)
	RMPG.HoloBox(x, y, w, h, Color(26, 10, 14, 215), col)
	draw.SimpleText(RMPG.T("plumbus_hint"), "RMPG_Small", x + 14, y + 14, Color(255, 220, 225))
end

local ICON = Material("entities/weapon_rmpg_plumbus.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, a)
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(ICON)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
