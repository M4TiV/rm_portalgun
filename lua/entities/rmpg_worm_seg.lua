AddCSLuaFile()

-- One physical piece of a brain worm (rmpg_brain_worm links them into a rope with ball joints and draws the body).
-- Hits and E on a piece go to the worm. The engine would trace bullets, the physgun and players against the model's own
-- collision, not against the physics ball, so traces get a sphere of their own here (TestCollision) and the model
-- (models/rmpg/worm_seg.mdl) has no hitbox that could throw such a hit away.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.worm"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Ball")
end

-- A trace against the ball; a hull trace sees it swollen by the hull's size (a hull's start is its bottom middle)
function ENT:TestCollision(start, delta, isbox, extents)
	local r = self:GetBall()
	if r <= 0 then return end
	local c = self:GetPos()
	local ox, oy, oz = start.x - c.x, start.y - c.y, start.z - c.z
	local rx, ry, rz = r, r, r
	if isbox then
		rx, ry, rz = r + extents.x, r + extents.y, r + extents.z
		oz = oz + extents.z
	end
	ox, oy, oz = ox / rx, oy / ry, oz / rz
	local dx, dy, dz = delta.x / rx, delta.y / ry, delta.z / rz
	local a = dx * dx + dy * dy + dz * dz
	if a <= 0 then return end
	local b = ox * dx + oy * dy + oz * dz
	local q = ox * ox + oy * oy + oz * oz - 1
	if q <= 0 then
		-- starting inside: anything may leave, nothing goes further in
		if b >= 0 then return end
		return { HitPos = start, Fraction = 0, Normal = Vector(ox, oy, oz):GetNormalized() }
	end
	if b >= 0 then return end
	local disc = b * b - a * q
	if disc < 0 then return end
	local t = (-b - math.sqrt(disc)) / a
	if t > 1 then return end
	t = math.max(t, 0)
	return { HitPos = start + delta * t, Fraction = t, Normal = Vector((ox + dx * t) / rx, (oy + dy * t) / ry, (oz + dz * t) / rz):GetNormalized() }
end

if SERVER then
	function ENT:Initialize()
		local r = self.Radius or 2
		self:SetBall(r)
		self:SetModel("models/rmpg/worm_seg.mdl")
		self:PhysicsInitSphere(r, "flesh")
		self:SetCollisionBounds(Vector(-r, -r, -r), Vector(r, r, r))
		self:EnableCustomCollisions(true)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)
		local po = self:GetPhysicsObject()
		if IsValid(po) then
			po:SetMass(self.Mass or 2)
			po:SetDamping(0.8, 3)
			po:Wake()
		end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:OnTakeDamage(dmg)
		if IsValid(self.Worm) then
			local ed = EffectData()
			ed:SetOrigin(dmg:GetDamagePosition())
			ed:SetColor(0)
			util.Effect("BloodImpact", ed, true, true)
			self.Worm:Hurt(dmg)
		end
	end

	function ENT:Use(ply)
		if IsValid(self.Worm) then self.Worm:Use(ply, self) end
	end

	return
end

function ENT:Initialize()
	self:EnableCustomCollisions(true)
end

function ENT:Draw() end
