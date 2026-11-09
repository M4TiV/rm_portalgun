AddCSLuaFile()

-- Dramatic exit pills, a bottle of 25: LMB shakes a pill out of the bottle and eats it - a few seconds later you
-- start to fade out like a hero at the climax of a film, and once you are gone you turn up at the saved location
-- picked with RMB (portal gun locations), or anywhere at random when you have none. weapon_rmpg_pill (one pill)
-- is built on this. First person reuses the HL2 SLAM detonator hands with the bottle and the pill drawn in them.
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("pills_name") or "Dramatic Exit Pills"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "Leave like in the movies."
SWEP.Instructions = "LMB - eat a pill, RMB - where you turn up"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_pills.png"

SWEP.Slot = 4
SWEP.SlotPos = 8
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/rmpg/pill_bottle.mdl"
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

SWEP.Single = false -- one pill that is used up (weapon_rmpg_pill)
SWEP.EatLen = 1.4   -- seconds of the whole move: shake a pill out, to the mouth, bottle back down
SWEP.Swallow = 0.95 -- the pill reaches the mouth
local PILLS = 25

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "EatTime")
	self:NetworkVar("Float", 1, "DestYaw")
	self:NetworkVar("Vector", 0, "DestPos")
	self:NetworkVar("Bool", 0, "HasDest")
	self:NetworkVar("String", 0, "DestName")
	self:NetworkVar("Int", 0, "Pills")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	self:DrawShadow(false)
	if SERVER then self:SetPills(self.Single and 1 or PILLS) end
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_SLAM_DETONATOR_DRAW)
	self:SetNextPrimaryFire(CurTime() + 0.4)
	return true
end

function SWEP:PredSound(snd, lvl, pitch)
	if CLIENT and (game.SinglePlayer() or not IsFirstTimePredicted()) then return end
	self:EmitSound(snd, lvl or 65, pitch or 100)
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	if not IsValid(ply) or self:GetPills() <= 0 then return end
	-- one pill at a time: not while the last one is still working
	if ply:GetNW2Float("RMPG_PillBack", 0) > CurTime() then return end
	self:SetNextPrimaryFire(CurTime() + self.EatLen + 0.3)
	self:SetEatTime(CurTime())
	ply:SetAnimation(PLAYER_ATTACK1)
	if not self.Single then self:PredSound(string.format(RMPG.SND.pillShake, math.random(1, 4)), 60, math.random(110, 125)) end
	if CLIENT then return end
	timer.Simple(self.Swallow, function()
		if not IsValid(self) or not IsValid(ply) or ply:GetActiveWeapon() ~= self then return end
		ply:EmitSound(RMPG.SND.pillSwallow, 65, math.random(95, 110))
		if not RMPG.PillStart(ply, self) then return end
		self:SetPills(self:GetPills() - 1)
		if self:GetPills() <= 0 then
			-- the last pill (or the only one): the rest of the move, then it is gone
			local class = self:GetClass()
			timer.Simple(self.EatLen - self.Swallow, function()
				if IsValid(ply) and ply:HasWeapon(class) then ply:StripWeapon(class) end
			end)
		end
	end)
end

-- RMB: pick where you turn up (the menu is the client's: the saved locations are stored there)
function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.5)
	if SERVER then
		net.Start("rmpg_pill_menu")
		net.Send(self:GetOwner())
	end
end

if SERVER then return end

---------------------------------------------------------------------------
-- Client: the bottle and the pill in the hand, going to the mouth; the HUD
---------------------------------------------------------------------------

local INVIS = CreateMaterial("rmpg_invisible_pills", "UnlitGeneric", {
	["$translucent"] = 1,
	["$alpha"] = 0,
	["$vertexalpha"] = 1,
})
local DET_CENTER = Vector(9.49, 64.64, 21.68) -- the detonator in its bone's space (c_slam.mdl)
local BOTTLE_MID = 2.6                       -- half the bottle's height (models/rmpg/pill_bottle.mdl)
local PILL_VM = 1.7                          -- the pill a bit bigger in first person, so it reads

local function Smooth(x)
	x = math.Clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function Prop(self, key, model)
	if not IsValid(self[key]) then
		self[key] = ClientsideModel(model, RENDERGROUP_OPAQUE)
		if IsValid(self[key]) then self[key]:SetNoDraw(true) end
	end
	return self[key]
end

function SWEP:OnRemove()
	if IsValid(self.BottleEnt) then self.BottleEnt:Remove() end
	if IsValid(self.PillEnt) then self.PillEnt:Remove() end
end

-- Seconds into the eating move, or nil
function SWEP:EatT()
	local t = CurTime() - self:GetEatTime()
	if self:GetEatTime() <= 0 or t < 0 or t > self.EatLen then return end
	return t
end

local function Draw(e, pos, ang, scale)
	if not IsValid(e) then return end
	e:SetPos(pos)
	e:SetAngles(ang)
	e:SetModelScale(scale or 1, 0)
	e:SetupBones()
	e:DrawModel()
end

function SWEP:PreDrawViewModel(vm)
	render.ModelMaterialOverride(INVIS)
end

function SWEP:PostDrawViewModel(vm)
	render.ModelMaterialOverride()
	local bone = vm:LookupBone("Detonator")
	local m = bone and vm:GetBoneMatrix(bone)
	if not m then return end
	local ea = EyeAngles()
	local hand = LocalToWorld(DET_CENTER, angle_zero, m:GetTranslation(), m:GetAngles())
	local mouth = EyePos() + ea:Forward() * 6 - ea:Up() * 2.2
	local t = self:EatT()
	local pill = Prop(self, "PillEnt", "models/rmpg/pill.mdl")
	local pillAng = Angle(0, ea.y + 70, 25)
	if self.Single then
		-- the pill between the fingers, up to the mouth and gone
		if t and t >= self.Swallow then return end
		local k = t and Smooth(t / self.Swallow) or 0
		Draw(pill, LerpVector(k, hand, mouth) + ea:Up() * (math.sin(k * math.pi) * 2), pillAng, PILL_VM)
		return
	end
	-- the bottle: lifted and tipped to shake a pill out, which then goes up to the mouth
	local lift = 0
	if t then lift = t < self.Swallow and Smooth(t / 0.35) or 1 - Smooth((t - self.Swallow) / (self.EatLen - self.Swallow)) end
	local bang = Angle(0, ea.y + 20, 0)
	bang:RotateAroundAxis(ea:Forward(), -60 * lift)
	local mid = hand + ea:Up() * (2.5 * lift) + ea:Right() * (1.5 * lift)
	if self:GetPills() > 0 or t then Draw(Prop(self, "BottleEnt", self.WorldModel), mid - bang:Up() * BOTTLE_MID, bang) end
	if t and t >= 0.35 and t < self.Swallow then
		local k = Smooth((t - 0.35) / (self.Swallow - 0.35))
		local from = mid + bang:Up() * (BOTTLE_MID + 0.8)
		Draw(pill, LerpVector(k, from, mouth) + ea:Up() * (math.sin(k * math.pi) * 2.5), pillAng, PILL_VM)
	end
end

hook.Add("PreDrawPlayerHands", "rmpg_pills_hands", function(hands, vm, ply, wep)
	if IsValid(wep) and (wep:GetClass() == "weapon_rmpg_pills" or wep:GetClass() == "weapon_rmpg_pill") then render.ModelMaterialOverride() end
end)

function SWEP:DrawWorldModel()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		self:DrawModel()
		return
	end
	local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = bone and owner:GetBoneMatrix(bone)
	if not m then return end
	local ang = m:GetAngles()
	ang:RotateAroundAxis(ang:Forward(), 90)
	local off = self.Single and 0 or BOTTLE_MID
	self:SetRenderOrigin(m:GetTranslation() + m:GetForward() * 3.2 + m:GetRight() * 1.6 - ang:Up() * off)
	self:SetRenderAngles(ang)
	self:DrawModel()
	self:SetRenderOrigin()
	self:SetRenderAngles()
end

function SWEP:DrawHUD()
	if not RMPG.CL.hud:GetBool() then return end
	local w, h = 380, 62
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	local col = Color(255, 170, 70)
	RMPG.HoloBox(x, y, w, h, Color(24, 12, 4, 215), col)
	local dest = self:GetHasDest() and self:GetDestName() or RMPG.T("dest_random")
	RMPG.HoloText(string.format(RMPG.T("pills_dest"), dest), "RMPG_BodyB", x + 14, y + 12, Color(255, 236, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	if not self.Single then
		RMPG.HoloText(string.format(RMPG.T("pills_count"), self:GetPills()), "RMPG_BodyB", x + w - 14, y + 12, Color(255, 236, 214), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
	draw.SimpleText(RMPG.T(self.Single and "pill_hint" or "pills_hint"), "RMPG_Small", x + 14, y + 38, Color(220, 180, 140))
end

function SWEP:DrawWeaponSelection(x, y, w, h, a)
	self.IconMat = self.IconMat or Material(self.IconOverride, "smooth")
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(self.IconMat)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
