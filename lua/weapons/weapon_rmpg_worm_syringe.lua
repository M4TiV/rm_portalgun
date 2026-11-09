AddCSLuaFile()

-- Symbiont syringe: one tiny brain worm in pink goo. LMB injects it into the head of whoever is in front of you (a
-- player or an NPC), RMB into your own, R lets it out. In the head it grows (rmpg_worm_headgrow a minute), the host's
-- health only shows "??", and full grown - or when the host dies - it bursts out (see entities/rmpg_brain_worm.lua).
-- Empty, the same keys pull a worm back out of a head: it goes into the syringe, or if it is huge by then it jumps
-- out through the ear and goes after the host.
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("wsyr_name") or "Symbiont Syringe"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "A brain worm in a syringe. Don't."
SWEP.Instructions = "LMB - the one in front of you, RMB - yourself, R - let the worm out"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_worm_syringe.png"

SWEP.Slot = 5
SWEP.SlotPos = 7
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/worm_syringe.mdl"
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

local GOO = Color(255, 120, 160)

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "Worm") -- the size of the worm inside, 0 = empty
	self:NetworkVar("Float", 1, "StabTime")
	self:NetworkVar("Float", 2, "IdleAt")
	self:NetworkVar("Bool", 0, "StabSelf")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	if SERVER then self:SetWorm(0.05) end
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
	return true
end

-- The thumb goes down on the plunger; rmpg/cl_items.lua moves the syringe itself
function SWEP:Stab(own)
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DETONATE)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	self:SetStabTime(CurTime())
	self:SetStabSelf(own or false)
	self:SetIdleAt(CurTime() + 0.7)
	if SERVER then self:EmitSound(RMPG.SND.phxInject, 65) end
end

function SWEP:Think()
	local t = self:GetIdleAt()
	if t > 0 and CurTime() >= t then
		self:SetIdleAt(0)
		self:SendWeaponAnim(ACT_SLAM_DETONATOR_IDLE)
	end
end

if SERVER then
	-- Full: in it goes. Empty: out it comes (or jumps out on its own, if it is huge by now)
	function SWEP:Act(ply, target)
		if self:GetWorm() > 0 then
			if RMPG.WormInfect(target, self:GetWorm()) then
				self:SetWorm(0)
				if target ~= ply then RMPG.Notify(ply, "n_wsyr_done", nil, 2) end
			else
				RMPG.Notify(ply, "n_wsyr_already", nil, 1)
			end
			return
		end
		local size = RMPG.WormExtract(target)
		if size == nil then
			RMPG.Notify(ply, "n_wsyr_no_worm", nil, 1)
		elseif size == false then
			RMPG.Notify(ply, "n_wsyr_escaped", nil, 1)
		else
			self:SetWorm(size)
			RMPG.Notify(ply, "n_wsyr_pulled", nil, 2)
		end
	end
end

-- The player or NPC right in front (a little forgiving with the aim)
function SWEP:Target()
	local ply = self:GetOwner()
	local tr = util.TraceHull({ start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 90, mins = Vector(-6, -6, -6), maxs = Vector(6, 6, 6), filter = ply, mask = MASK_SHOT_HULL })
	local e = tr.Entity
	if IsValid(e) and (e:IsPlayer() or e:IsNPC() or e:IsNextBot()) and e:Health() > 0 then return e end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 1)
	self:SetNextSecondaryFire(CurTime() + 1)
	self:Stab()
	if CLIENT then return end
	local ply = self:GetOwner()
	local e = self:Target()
	if not e then
		RMPG.Notify(ply, "n_wsyr_nobody", nil, 1)
		return
	end
	self:Act(ply, e)
end

function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + 1)
	self:SetNextSecondaryFire(CurTime() + 1)
	self:Stab(true)
	if CLIENT then return end
	self:Act(self:GetOwner(), self:GetOwner())
end

-- R: the worm drops out of the syringe and crawls off
function SWEP:Reload()
	if CLIENT or self:GetWorm() <= 0 or (self.NextEmpty or 0) > CurTime() then return end
	self.NextEmpty = CurTime() + 1
	local ply = self:GetOwner()
	local tr = util.TraceLine({ start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 70, filter = ply })
	local w = ents.Create("rmpg_brain_worm")
	if not IsValid(w) then return end
	w.StartSize = self:GetWorm()
	w:SetPos(tr.HitPos + tr.HitNormal * 6)
	w:Spawn()
	w:Activate()
	self:SetWorm(0)
end

if SERVER then return end

-- skin 0 has the worm in its goo, skin 1 is empty
function SWEP:Skin()
	return self:GetWorm() > 0 and 0 or 1
end

function SWEP:GetViewModelPosition(pos, ang)
	return RMPG.SyringeShift(self, pos, ang)
end

function SWEP:PreDrawViewModel()
	RMPG.HideSlam()
end

function SWEP:PostDrawViewModel(vm)
	RMPG.DrawSyringeVM(self, vm, self:Skin())
end

function SWEP:DrawWorldModel()
	RMPG.DrawHeld(self, self:Skin())
end

function SWEP:DrawHUD()
	if not RMPG.CL.hud:GetBool() then return end
	local w, h = 380, 62
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	RMPG.HoloBox(x, y, w, h, Color(22, 6, 12, 215), GOO)
	local full = self:GetWorm() > 0
	RMPG.HoloText(RMPG.T(full and "wsyr_hud" or "wsyr_hud_empty"), "RMPG_BodyB", x + 14, y + 12, Color(255, 225, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(RMPG.T(full and "wsyr_hint" or "wsyr_hint_empty"), "RMPG_Small", x + 14, y + 38, Color(220, 160, 180))
end

local ICON = Material("entities/weapon_rmpg_worm_syringe.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, a)
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(ICON)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
