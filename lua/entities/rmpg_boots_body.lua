AddCSLuaFile()

-- The body of a player in gravity boots, for everything that traces: the server's hitboxes cannot turn over with the
-- player, so while the boots are on the player is not solid and this stands in - a row of balls from the soles to the
-- top of the head, along whichever way is up for them. Hits on it go to the player, the top of it counts as the head.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gravity boots body"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

local R, HEIGHT = 13, 72
local HEAD_FROM = 58 -- above this height a hit counts as the head

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Wearer")
end

-- Shots, blows and bodies meet it; sight does not: NPCs look through it at the player (a body in the way of their line
-- of sight made the player invisible to them, so nothing ever attacked a player in boots)
local SIGHT = bit.bor(CONTENTS_BLOCKLOS, CONTENTS_OPAQUE)

-- How far a point is from the segment a-b
local function DistToSegment(p, a, b)
	local ab = b - a
	local t = ab:LengthSqr() > 0 and math.Clamp((p - a):Dot(ab) / ab:LengthSqr(), 0, 1) or 0
	return p:Distance(a + ab * t)
end

function ENT:TestCollision(start, delta, isbox, extents, mask)
	if mask and bit.band(mask, SIGHT) ~= 0 then return end
	local ply = self:GetWearer()
	if not IsValid(ply) then return end
	-- an NPC checks that its shot can reach the player with a line that ends on them (between their middle and their
	-- eyes) and fires only if nothing else is in the way: such a line goes through. Real shots run on far past them
	-- and still hit this body, and blows are boxes, so they hit it too.
	if not isbox and DistToSegment(start + delta, ply:WorldSpaceCenter(), ply:EyePos()) < 16 then return end
	local up = RMPG.BootsUp(ply)
	local s = ply:GetNW2Float("RMPG_Scale", 1)
	local feet = RMPG.BootsFeet(ply, up)
	local r = R * s
	local from = start
	if isbox then
		r = r + math.min(extents.x, extents.z)
		from = start + Vector(0, 0, extents.z) -- a hull's start is its bottom middle
	end
	local a = delta:Dot(delta)
	if a <= 0 then return end
	local best, bn
	for i = 0, 4 do
		local c = feet + up * ((R + (HEIGHT - R * 2) * i / 4) * s)
		local o = from - c
		local q = o:Dot(o) - r * r
		local b = o:Dot(delta)
		if q > 0 and b < 0 then -- starting inside lets a shot of their own out
			local disc = b * b - a * q
			if disc >= 0 then
				local t = (-b - math.sqrt(disc)) / a
				if t >= 0 and t <= 1 and (not best or t < best) then best, bn = t, (o + delta * t):GetNormalized() end
			end
		end
	end
	if best then return { HitPos = start + delta * best, Fraction = best, Normal = bn } end
end

if SERVER then
	function ENT:Initialize()
		self:SetWearer(self.WearerPly)
		self:SetModel("models/rmpg/worm_seg.mdl") -- no hitbox, which would throw the hits above away
		self:SetSolid(SOLID_OBB)
		self:SetMoveType(MOVETYPE_NONE)
		local e = Vector(HEIGHT + 20, HEIGHT + 20, HEIGHT + 20)
		self:SetCollisionBounds(-e, e)
		self:EnableCustomCollisions(true)
		self:DrawShadow(false)
	end

	function ENT:OnTakeDamage(dmg)
		local ply = self:GetWearer()
		-- blasts reach the player by themselves
		if not IsValid(ply) or not ply:Alive() or dmg:GetAttacker() == ply or dmg:IsExplosionDamage() then return end
		local up = RMPG.BootsUp(ply)
		local h = (dmg:GetDamagePosition() - RMPG.BootsFeet(ply, up)):Dot(up) / ply:GetNW2Float("RMPG_Scale", 1)
		if h > HEAD_FROM and dmg:IsBulletDamage() then dmg:ScaleDamage(2) end
		ply:TakeDamageInfo(dmg)
		local ed = EffectData()
		ed:SetOrigin(dmg:GetDamagePosition())
		ed:SetColor(0)
		util.Effect("BloodImpact", ed, true, true)
	end

	return
end

function ENT:Initialize()
	self:EnableCustomCollisions(true)
end

function ENT:Draw() end
