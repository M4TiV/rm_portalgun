AddCSLuaFile()

-- Mr. Meeseeks box. LMB presses the button and a Meeseeks pops out; walk up to him and press E to give him a job.
-- R sends all of your Meeseeks away. First person uses the HL2 SLAM detonator animations (the thumb presses the
-- button) with the stock model hidden and the box drawn where the detonator is held.
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("mrbox_name") or "Mr. Meeseeks Box"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "Press the button, get a Meeseeks, give him a job."
SWEP.Instructions = "LMB - summon a Meeseeks, E (or RMB) on a Meeseeks - give a job, R - send them all away"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_meeseeks_box.png"

SWEP.Slot = 4
SWEP.SlotPos = 7
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/meeseeks_box.mdl"
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
	self:NetworkVar("Float", 1, "PressTime")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	self:DrawShadow(false)
end

function SWEP:PredSound(snd, lvl, pitch)
	if CLIENT and (game.SinglePlayer() or not IsFirstTimePredicted()) then return end
	self:EmitSound(snd, lvl or 70, pitch or 100)
end

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
	self:SetNextPrimaryFire(CurTime() + 0.9)
	self:Anim(ACT_SLAM_DETONATOR_DETONATE)
	ply:SetAnimation(PLAYER_ATTACK1)
	self:SetPressTime(CurTime())
	self:PredSound(RMPG.SND.mrButton, 65, 110)
	if SERVER then
		-- the Meeseeks pops out when the thumb is all the way down
		timer.Simple(0.25, function()
			if IsValid(self) and IsValid(ply) and ply:GetActiveWeapon() == self then RMPG.SummonMeeseeks(ply) end
		end)
	end
end

-- RMB at one of your Meeseeks opens his job window too (same as E on him)
function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.5)
	if CLIENT then return end
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local tr = util.TraceLine({ start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 300, filter = ply })
	local e = tr.Entity
	if IsValid(e) and e:GetClass() == RMPG.MEESEEKS and e:GetMaster() == ply and not e:GetFrenzy() then
		RMPG.OpenMeeseeksMenu(ply, e)
	end
end

function SWEP:Reload()
	if CLIENT or (self.NextDismiss or 0) > CurTime() then return end
	self.NextDismiss = CurTime() + 1
	local n = RMPG.DismissMeeseeks(self:GetOwner())
	if n > 0 then RMPG.Notify(self:GetOwner(), "n_mr_dismissed", { n }, 0) end
end

if SERVER then return end

---------------------------------------------------------------------------
-- Client: the box in the hand
---------------------------------------------------------------------------

local INVIS = CreateMaterial("rmpg_invisible", "UnlitGeneric", {
	["$translucent"] = 1,
	["$alpha"] = 0,
	["$vertexalpha"] = 1,
})
-- centre of the detonator mesh in its bone's space (measured from c_slam.mdl / c_slam.vvd)
local DET_CENTER = Vector(9.49, 64.64, 21.68)
local VM_SIZE = 1.95   -- half size of the box in first person, world units: a bit bigger than the palm
local DET_HALF = 1.45  -- the size the detonator spot fits; a bigger box is pushed out of the palm by the difference

function SWEP:Press()
	local t = CurTime() - self:GetPressTime()
	if t < 0 or t > 0.6 then return 0 end
	return math.sin(math.Clamp(t / 0.6, 0, 1) * math.pi)
end

local function Light(pos)
	local l = render.GetLightColor(pos)
	return math.Clamp(math.max(l.x, l.y, l.z) * 1.8 + 0.3, 0.4, 1)
end

-- Turns a bone matrix into box axes: the bone axis closest to the view's up becomes the top (button), the one
-- closest to the view's forward the front, so the box follows the hand but keeps its button up
local function BoxAngle(m)
	local axes = { m:GetForward(), -m:GetRight(), m:GetUp() }
	local ea = EyeAngles()
	local function Best(dir, skip)
		local bi, bd = 1, -1
		for i, a in ipairs(axes) do
			if i ~= skip and math.abs(a:Dot(dir)) > bd then bi, bd = i, math.abs(a:Dot(dir)) end
		end
		local v = axes[bi]
		return v:Dot(dir) < 0 and -v or v, bi
	end
	local up, ui = Best(ea:Up())
	local fwd = Best(ea:Forward(), ui)
	local ang = fwd:AngleEx(up)
	ang:RotateAroundAxis(ang:Up(), 25) -- show a corner, two sides at once
	return ang
end

function SWEP:HandFrame(vm)
	local bone = vm:LookupBone("Detonator")
	local m = bone and vm:GetBoneMatrix(bone)
	if not m then return end
	local pos = LocalToWorld(DET_CENTER, angle_zero, m:GetTranslation(), m:GetAngles())
	-- safety: if that is not near a hand, hold the box in the nearest palm
	local best, bd
	for _, name in ipairs({ "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand" }) do
		local hb = vm:LookupBone(name)
		local hm = hb and vm:GetBoneMatrix(hb)
		if hm then
			local d = hm:GetTranslation():Distance(pos)
			if not bd or d < bd then best, bd = hm, d end
		end
	end
	if best and bd > 12 then pos = best:GetTranslation() + best:GetForward() * 3.5 end
	if best then
		-- move the centre away from the palm so the fingers stay on the surface of the bigger box
		local palm = best:GetTranslation() + best:GetForward() * 2.5
		local out = pos - palm
		if out:LengthSqr() > 0.01 then pos = pos + out:GetNormalized() * ((VM_SIZE - DET_HALF) * 1.1) end
	end
	return RMPG.Model.FrameFromAngle(pos, BoxAngle(m), VM_SIZE)
end

function SWEP:PreDrawViewModel(vm)
	-- hide the detonator and the mine, keep the animated hands
	render.ModelMaterialOverride(INVIS)
end

function SWEP:PostDrawViewModel(vm)
	render.ModelMaterialOverride()
	if not RMPG.Model then return end
	local fr = self:HandFrame(vm)
	if not fr then return end
	RMPG.Model.DrawMeeseeksBox(fr, { press = self:Press(), light = Light(EyePos()), outline = RMPG.CL.outline:GetBool() })
	RMPG.ResetTints()
end

hook.Add("PreDrawPlayerHands", "rmpg_mr_hands", function(hands, vm, ply, wep)
	if IsValid(wep) and wep:GetClass() == "weapon_rmpg_meeseeks_box" then render.ModelMaterialOverride() end
end)

function SWEP:DrawWorldModel()
	if not RMPG.Model then self:DrawModel() return end
	local owner = self:GetOwner()
	local fr
	if IsValid(owner) then
		local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
		local m = bone and owner:GetBoneMatrix(bone)
		if m then
			local ang = owner:EyeAngles()
			ang.p, ang.r = 0, 0
			fr = RMPG.Model.FrameFromAngle(m:GetTranslation() + m:GetForward() * 3.6 + m:GetRight() * 1.6, ang, 2.7)
		end
	end
	if not fr then
		-- dropped on the ground: the real model (models/rmpg/meeseeks_box.mdl)
		self:DrawModel()
		return
	end
	RMPG.Model.DrawMeeseeksBox(fr, { press = self:Press(), light = Light(fr.O), outline = RMPG.CL.outline:GetBool() })
	RMPG.ResetTints()
end

function SWEP:DrawHUD()
	if RMPG.DrawMeeseeksHUD then RMPG.DrawMeeseeksHUD(self) end
end

local ICON = Material("entities/weapon_rmpg_meeseeks_box.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, a)
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(ICON)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
