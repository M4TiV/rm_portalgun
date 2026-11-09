AddCSLuaFile()

-- A bloody piece of a dead brain worm (models/rmpg/worm_chunk.mdl): it leaves blood on whatever it lands on or slides
-- over, can be picked up, and other worms eat it.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.worm"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

local MODEL = "models/rmpg/worm_chunk.mdl"
local BOX = Vector(5.5, 5, 4)
local UP = Vector(0, 0, 1)

if SERVER then
	function ENT:Initialize()
		local s = self.Scale or 1
		self:SetModel(MODEL)
		self:SetModelScale(s, 0)
		self:PhysicsInitBox(-BOX * s, BOX * s)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:SetUseType(SIMPLE_USE)
		local po = self:GetPhysicsObject()
		if IsValid(po) then
			po:SetMass(math.Clamp(3 * s * s, 1, 30))
			po:SetMaterial("flesh")
			po:Wake()
		end
		self.NextMark, self.NextSquish = 0, 0
		SafeRemoveEntityDelayed(self, RMPG.CV.wormChunkTime:GetFloat())
	end

	function ENT:Stain(pos, normal)
		util.Decal("Blood", pos + normal * 4, pos - normal * 4, self)
	end

	function ENT:PhysicsCollide(data)
		if data.Speed < 20 then return end
		local now = CurTime()
		if now >= self.NextMark then
			self.NextMark = now + 0.05
			self:Stain(data.HitPos, data.HitNormal)
		end
		if data.Speed > 90 and now >= self.NextSquish then
			self.NextSquish = now + 0.2
			self:EmitSound(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), 65, math.random(95, 125))
			local ed = EffectData()
			ed:SetOrigin(data.HitPos)
			ed:SetColor(0)
			util.Effect("BloodImpact", ed, true, true)
		end
	end

	-- Sliding or rolling along the ground smears it too
	function ENT:Think()
		local po = self:GetPhysicsObject()
		if IsValid(po) and po:GetVelocity():LengthSqr() > 500 then
			local p = self:GetPos()
			local tr = util.TraceLine({ start = p, endpos = p - UP * (9 * (self.Scale or 1) + 6), mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit then self:Stain(tr.HitPos, tr.HitNormal) end
		end
		self:NextThink(CurTime() + 0.1)
		return true
	end

	function ENT:Use(ply)
		if IsValid(ply) and ply:IsPlayer() then ply:PickupObject(self) end
	end

	return
end

function ENT:Draw(flags)
	self:DrawModel(flags)
end
