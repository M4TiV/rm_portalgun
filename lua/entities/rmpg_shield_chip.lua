AddCSLuaFile()

-- Energy shield chip: press E to implant it and get a personal energy shield
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.chip"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "entities/rmpg_shield_chip.png"

local MODEL = "models/rmpg/shield_chip.mdl"
local SCALE = 1.5
local MINS, MAXS = Vector(-4.8, -4.8, 0), Vector(4.8, 4.8, 1.4)
local CYAN = Color(90, 230, 255)

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 4)
		e:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		e:Spawn()
		e:Activate()
		return e
	end

	function ENT:Initialize()
		if util.IsValidModel(MODEL) then
			self:SetModel(MODEL)
			self:PhysicsInit(SOLID_VPHYSICS)
		else
			self:SetModel("models/props_junk/PopCan01a.mdl")
			self:PhysicsInitBox(MINS, MAXS)
			self:SetCollisionBounds(MINS, MAXS)
		end
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)
		local po = self:GetPhysicsObject()
		if IsValid(po) then
			po:SetMass(3)
			po:SetMaterial("metal")
			po:Wake()
		end
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not RMPG.ImplantShield(ply) then
			RMPG.Notify(ply, "n_shield_has", nil, 0)
			return
		end
		RMPG.Notify(ply, "n_shield_implanted", nil, 2)
		RMPG.ImplantHint(ply)
		self:Remove()
	end

	return
end

function ENT:Initialize()
	self:SetRenderBounds(Vector(-16, -16, -8), Vector(16, 16, 16))
end

function ENT:Pulse()
	return 0.65 + 0.35 * math.sin(CurTime() * 4 + self:EntIndex())
end

function ENT:Draw()
	if self:GetModel() == MODEL then
		self:DrawModel()
		return
	end
	if not RMPG.Model then return end
	local l = render.GetLightColor(self:GetPos())
	local p = self:Pulse()
	RMPG.Model.DrawChip(RMPG.Model.FrameFromAngle(self:GetPos(), self:GetAngles(), SCALE), {
		glow = Vector(0.25 + 0.15 * p, 0.75 + 0.25 * p, 1),
		light = math.Clamp(math.max(l.x, l.y, l.z) * 1.8 + 0.25, 0.35, 1),
		outline = RMPG.CL.outline:GetBool(),
	})
	RMPG.ResetTints()
end

function ENT:DrawTranslucent()
	local p = self:Pulse()
	local top = self:GetPos() + self:GetUp() * 1.8 * SCALE
	render.SetMaterial(RMPG.Mat.glow)
	local c = self.GlowColor or CYAN
	render.DrawSprite(top, 22 * p, 22 * p, Color(c.r, c.g, c.b, 150 * p))
	render.DrawSprite(top, 8, 8, Color(220, 250, 255, 200))
end
