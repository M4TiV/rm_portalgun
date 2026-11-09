AddCSLuaFile()

-- DNA syringe for Operation Phoenix. LMB: take DNA from a human ragdoll, or inject the DNA into a Phoenix tank.
-- RMB: inject yourself - your own DNA goes into the nearest free tank (or stays in the syringe).
-- With a fruit (a potato, a watermelon) LMB takes its DNA, and RMB then injects it into you: you become that
-- fruit (rmpg/sh_fruit.lua).
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("syringe_name") or "DNA Syringe"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "Takes DNA and grows bodies in the Phoenix tank."
SWEP.Instructions = "LMB - take DNA from a ragdoll / inject into a tank, RMB - your own DNA"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_dna_syringe.png"

SWEP.Slot = 5
SWEP.SlotPos = 6
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/dna_syringe.mdl"
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
	self:NetworkVar("String", 0, "DNAModel")
	self:NetworkVar("String", 1, "DNABodygroups")
	self:NetworkVar("String", 2, "DNALabel")
	self:NetworkVar("Int", 0, "DNASkin")
	self:NetworkVar("Entity", 0, "DNAOwner")
	self:NetworkVar("Float", 0, "StabTime")
	self:NetworkVar("Float", 1, "IdleAt")
	self:NetworkVar("Bool", 0, "StabSelf")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
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
	function SWEP:Store(dna)
		self:SetDNAModel(dna.model)
		self:SetDNASkin(dna.skin or 0)
		self:SetDNABodygroups(dna.bodygroups or "")
		self:SetDNALabel(dna.label or "")
		self:SetDNAOwner(dna.owner or NULL)
	end

	function SWEP:Stored()
		if self:GetDNAModel() == "" then return end
		return { model = self:GetDNAModel(), skin = self:GetDNASkin(), bodygroups = self:GetDNABodygroups(), label = self:GetDNALabel(), owner = self:GetDNAOwner() }
	end

	function SWEP:Inject(tank, dna, ply)
		if tank:GetBroken() then
			RMPG.Notify(ply, "n_phx_tank_broken", nil, 1)
			return
		end
		if tank:GetState() ~= 0 then
			RMPG.Notify(ply, "n_phx_busy", nil, 1)
			return
		end
		if tank:LoadDNA(dna, ply) then
			self:SetDNAModel("")
			RMPG.Notify(ply, "n_phx_loaded", nil, 2)
			RMPG.PhxOpenMenu(ply, tank)
		end
	end
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 1)
	self:Stab()
	if CLIENT then return end
	local ply = self:GetOwner()
	local src, dir = ply:GetShootPos(), ply:GetAimVector()
	local tr = util.TraceLine({ start = src, endpos = src + dir * 110, filter = ply })
	local e = tr.Entity
	if not IsValid(e) then
		-- a fruit is small: the one nearest the line you aim along will do
		local best, bd
		for _, f in ipairs(ents.FindInSphere(src + dir * 55, 60)) do
			if RMPG.FruitKind(f) then
				local c = f:WorldSpaceCenter()
				local along = (c - src):Dot(dir)
				local d = (src + dir * along):DistToSqr(c)
				if along > 0 and d < 18 * 18 and (not bd or d < bd) then best, bd = f, d end
			end
		end
		e = best
	end
	if IsValid(e) and e:GetClass() == RMPG.TANK then
		local dna = self:Stored()
		if not dna then
			RMPG.Notify(ply, "n_phx_no_dna", nil, 1)
			return
		end
		if string.sub(dna.model, 1, 6) == "fruit:" then
			RMPG.Notify(ply, "n_fruit_tank", nil, 1)
			return
		end
		self:Inject(e, dna, ply)
		return
	end
	if not IsValid(e) then return end
	local kind = RMPG.FruitKind(e)
	if kind then
		self:Store({ model = "fruit:" .. kind, label = "#fruit_" .. kind })
		e:EmitSound(RMPG.SND.phxTake, 65, 130)
		RMPG.Notify(ply, "n_fruit_taken", { "#fruit_" .. kind }, 2)
		return
	end
	local dna, why = RMPG.PhxTakeDNA(e)
	if not dna then
		RMPG.Notify(ply, why, nil, 1)
		return
	end
	self:Store(dna)
	e:EmitSound(RMPG.SND.phxTake, 65)
	RMPG.Notify(ply, "n_phx_taken", { dna.label }, 2)
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 1)
	self:Stab(true)
	if CLIENT then return end
	local ply = self:GetOwner()
	-- a fruit's DNA goes into you: you become the fruit
	local held = self:Stored()
	if held and string.sub(held.model, 1, 6) == "fruit:" then
		if RMPG.FruitBecome(ply, string.sub(held.model, 7)) then self:SetDNAModel("") end
		return
	end
	local dna = RMPG.PhxOwnDNA(ply)
	local tank = RMPG.PhxFreeTank(ply, ply:GetPos(), 1000)
	if tank then
		self:Inject(tank, dna, ply)
	else
		self:Store(dna)
		RMPG.Notify(ply, "n_phx_no_tank", nil, 0)
	end
end

if SERVER then return end

-- skin 0 is full, skin 1 empty
function SWEP:Skin()
	return self:GetDNAModel() ~= "" and 0 or 1
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
	local w, h = 360, 62
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	local col = Color(90, 255, 160)
	RMPG.HoloBox(x, y, w, h, Color(3, 18, 12, 215), col)
	local model = self:GetDNAModel()
	local label = IsValid(self:GetDNAOwner()) and self:GetDNAOwner() == LocalPlayer() and RMPG.T("phx_your_dna") or self:GetDNALabel()
	if string.sub(label, 1, 1) == "#" then label = RMPG.T(string.sub(label, 2)) end
	RMPG.HoloText(model ~= "" and string.format(RMPG.T("phx_dna"), label) or RMPG.T("phx_no_dna"), "RMPG_BodyB", x + 14, y + 12, model ~= "" and Color(225, 255, 236) or Color(150, 200, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(RMPG.T("phx_hud_hint"), "RMPG_Small", x + 14, y + 38, Color(150, 200, 170))
end

local ICON = Material("entities/weapon_rmpg_dna_syringe.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, a)
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(ICON)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
