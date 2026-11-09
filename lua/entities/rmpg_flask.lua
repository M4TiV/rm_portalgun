AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.flask"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

local MODEL = "models/rmpg/fluid_flask.mdl"
local MINS, MAXS = Vector(-1.6, -1.6, -2.2), Vector(1.6, 1.6, 2.2)

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "FluidColor")
end

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 8)
		local c = IsValid(ply) and (ply.RMPG_Color or Vector(ply:GetInfoNum("rmpg_fluid_r", 84), ply:GetInfoNum("rmpg_fluid_g", 255), ply:GetInfoNum("rmpg_fluid_b", 64)))
		e:SetFluidColor(c or RMPG.DEFAULT_COLOR)
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
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(4)
			phys:SetMaterial("glass")
			phys:Wake()
		end
		local c = self:GetFluidColor()
		if c.x + c.y + c.z < 1 then self:SetFluidColor(RMPG.DEFAULT_COLOR) end
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		local w = ply:GetWeapon(RMPG.WEAPON)
		if not IsValid(w) then
			RMPG.Notify(ply, "n_need_gun", nil, 1)
			return
		end
		w:SetFlasks(w:GetFlasks() + 1)
		ply:EmitSound(RMPG.SND.pickup, 60)
		RMPG.Notify(ply, "n_flask_picked", nil, 2)
		self:Remove()
	end
else
	function ENT:Initialize()
		self:SetRenderBounds(Vector(-10, -10, -10), Vector(10, 10, 10))
	end

	function ENT:Draw()
		if not RMPG.Model then return end
		local c = self:GetFluidColor()
		if c.x + c.y + c.z < 1 then c = RMPG.DEFAULT_COLOR end
		local fr = RMPG.Model.FrameFromAngle(self:GetPos(), self:GetAngles(), 0.9)
		local l = render.GetLightColor(self:GetPos())
		RMPG.Model.DrawFlask(fr, c, 1, math.Clamp(math.max(l.x, l.y, l.z) * 1.8 + 0.2, 0.3, 1))
		RMPG.ResetTints()
		render.SetMaterial(RMPG.Mat.glow)
		render.DrawSprite(self:GetPos(), 22, 22, Color(c.x, c.y, c.z, 90))
	end
end
