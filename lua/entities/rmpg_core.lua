AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.core"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local RADIUS = 5

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "FluidColor")
end

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 12)
		local c = IsValid(ply) and (ply.RMPG_Color or Vector(ply:GetInfoNum("rmpg_fluid_r", 84), ply:GetInfoNum("rmpg_fluid_g", 255), ply:GetInfoNum("rmpg_fluid_b", 64)))
		e:SetFluidColor(c or RMPG.DEFAULT_COLOR)
		e:Spawn()
		e:Activate()
		return e
	end

	function ENT:Initialize()
		self:SetModel(util.IsValidModel("models/rmpg/energy_core.mdl") and "models/rmpg/energy_core.mdl" or "models/props_junk/PopCan01a.mdl")
		self:PhysicsInitSphere(RADIUS, "metal")
		self:SetCollisionBounds(Vector(-RADIUS, -RADIUS, -RADIUS), Vector(RADIUS, RADIUS, RADIUS))
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(8)
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
		if w:GetCore() then
			RMPG.Notify(ply, "n_core_has", nil, 0)
			return
		end
		w:InstallCore()
		self:Remove()
	end
else
	function ENT:Initialize()
		self:SetRenderBounds(Vector(-16, -16, -16), Vector(16, 16, 16))
	end

	function ENT:Draw() end

	function ENT:DrawTranslucent()
		if not RMPG.Model then return end
		local c = self:GetFluidColor()
		if c.x + c.y + c.z < 1 then c = RMPG.DEFAULT_COLOR end
		local fr = RMPG.Model.FrameFromAngle(self:GetPos(), self:GetAngles(), 4)
		RMPG.Model.DrawCoreItem(fr, c)
		RMPG.ResetTints()
	end

	function ENT:Think()
		if not RMPG.CL or not RMPG.CL.particles:GetBool() then return end
		local c = self:GetFluidColor()
		local dl = DynamicLight(self:EntIndex())
		if dl then
			dl.pos = self:GetPos()
			dl.r, dl.g, dl.b = c.x, c.y, c.z
			dl.brightness = 1.5
			dl.decay = 800
			dl.size = 160
			dl.dietime = CurTime() + 0.2
		end
	end
end
