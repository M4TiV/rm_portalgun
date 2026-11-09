AddCSLuaFile()

-- Detonator for Rick Prime's bombs: our remote (models/rmpg/detonator.mdl) in the HL2 SLAM hands.
-- E on a bomb links it to you, LMB sets off every linked bomb, R unlinks them.
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("detonator_name") or "Detonator"
SWEP.Author = "Rick Prime"
SWEP.Purpose = "Sets off Rick Prime's bombs linked to you."
SWEP.Instructions = "E on a bomb - link it, LMB - detonate, R - unlink all"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_detonator.png"

SWEP.Slot = 4
SWEP.SlotPos = 6
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/detonator.mdl"
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
	self:NetworkVar("Float", 0, "IdleAt")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:PredSound(snd, lvl, pitch)
	if CLIENT and (game.SinglePlayer() or not IsFirstTimePredicted()) then return end
	self:EmitSound(snd, lvl or 70, pitch or 100)
end

-- Play a viewmodel animation and go back to idle when it ends
function SWEP:Anim(act)
	self:SendWeaponAnim(act)
	local ply = self:GetOwner()
	local vm = IsValid(ply) and ply:GetViewModel()
	self:SetIdleAt(CurTime() + (IsValid(vm) and vm:SequenceDuration() or 0.5))
end

function SWEP:Deploy()
	self:Anim(ACT_SLAM_DETONATOR_DRAW)
	self:SetNextPrimaryFire(CurTime() + 0.4)
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
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	self:SetNextPrimaryFire(CurTime() + 0.6)
	self:Anim(ACT_SLAM_DETONATOR_DETONATE)
	ply:SetAnimation(PLAYER_ATTACK1)
	self:PredSound(RMPG.SND.detClick, 65)
	if CLIENT then return end
	local n = RMPG.DetonateBombs(ply)
	if n > 0 then
		RMPG.Notify(ply, "n_bomb_go", { n }, 3)
	else
		RMPG.Notify(ply, "n_bomb_none", nil, 1)
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
	if CLIENT or (self.NextUnlink or 0) > CurTime() then return end
	self.NextUnlink = CurTime() + 1
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local n = RMPG.UnlinkBombs(ply)
	if n > 0 then
		self:EmitSound(RMPG.SND.bombDisarm, 60)
		RMPG.Notify(ply, "n_bomb_unlinked", { n }, 0)
	end
end

if CLIENT then
	local ICON = Material("entities/rmpg_prime_bomb.png", "smooth")

	function SWEP:PreDrawViewModel()
		RMPG.HideSlam()
	end

	function SWEP:PostDrawViewModel(vm)
		RMPG.DrawDetonatorVM(self, vm)
	end

	function SWEP:DrawWorldModel()
		RMPG.DrawHeld(self)
	end

	function SWEP:DrawHUD()
		RMPG.DrawDetonatorHUD(self)
	end

	function SWEP:DrawWeaponSelection(x, y, w, h, a)
		local s = math.min(w, h) * 0.85
		surface.SetMaterial(ICON)
		surface.SetDrawColor(255, 255, 255, a)
		surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
	end
end
