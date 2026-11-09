AddCSLuaFile()

-- A brain worm's lair: a ring of raw flesh on the ground with the queen lying curled up in it (rmpg_brain_worm). She buds
-- off the first workers; after that the colony lives on what they drag home: every prop or corpse brought here gets eggs
-- laid in it (rmpg_worm_egg), which hatch into more workers. When the lair is full one of them leaves to start another,
-- so the worms slowly take over the area, and slime spreads round the lair as it grows. Attack it and they all come.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.worm_nest"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.IconOverride = "entities/rmpg_worm_nest.png"
ENT.RMPG_Bombable = true

local MODEL = "models/rmpg/worm_nest.mdl"
local RADIUS, HEIGHT = 115, 20
local MAX_BROOD = 6
local UP = Vector(0, 0, 1)

if SERVER then
	-- From the spawn menu it comes with its queen
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		if not IsValid(e) then return end
		e.QueenSize = 0.5
		e:SetPos(tr.HitPos)
		e:Spawn()
		e:Activate()
		local w = ents.Create(RMPG.WORM)
		if IsValid(w) then
			w.StartSize = 0.5
			w:SetPos(tr.HitPos + UP * 30)
			w:Spawn()
			w:Activate()
			w:BecomeQueen(e)
		end
		return e
	end

	function ENT:Initialize()
		local s = math.Clamp(0.45 + (self.QueenSize or 0.3) * 1.1, 0.45, 1.6)
		self.Size = s
		self:SetModel(MODEL)
		self:SetModelScale(s, 0)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-RADIUS, -RADIUS, 0) * s, Vector(RADIUS, RADIUS, HEIGHT) * s)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:DrawShadow(false)
		self.HP = RMPG.CV.wormNestHP:GetFloat()
		self.Members, self.Brood = {}, {}
		self.Creep = 110 * s
		local now = CurTime()
		self.NextBud, self.NextCreep, self.NextExpand = now + 8, now + 2, now + 60
		sound.Play(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), self:GetPos(), 75, 80)
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	-- How near a worker has to come with its load
	function ENT:Reach()
		return RADIUS * self.Size + 20
	end

	function ENT:Count()
		local n = 0
		for w in pairs(self.Members) do
			if IsValid(w) and not w.Dead then n = n + 1 else self.Members[w] = nil end
		end
		return n
	end

	local function Eggs(nest)
		local n = 0
		for _, e in ipairs(ents.FindByClass("rmpg_worm_egg")) do
			if e.Nest == nest then n = n + 1 end
		end
		return n
	end

	function ENT:HasRoom()
		return self:Count() < RMPG.CV.wormColony:GetInt()
	end

	-- Room for what is already in the eggs and one more
	function ENT:WantsFood()
		for i = #self.Brood, 1, -1 do
			if not IsValid(self.Brood[i]) then table.remove(self.Brood, i) end
		end
		return #self.Brood < MAX_BROOD and self:Count() + Eggs(self) < RMPG.CV.wormColony:GetInt()
	end

	function ENT:Join(w)
		self.Members[w] = true
		w.Colony = self
	end

	function ENT:Leave(w)
		self.Members[w] = nil
		if w.Colony == self then w.Colony = nil end
	end

	function ENT:Alarm(att)
		local now = CurTime()
		if (self.NextAlarm or 0) > now then return end
		self.NextAlarm = now + 3
		local pos = self:GetPos()
		for w in pairs(self.Members) do
			if IsValid(w) and w:GetPos():DistToSqr(pos) < 2000 * 2000 then w:OnAlarm(att) end
		end
	end

	-- A load is home: it stays here, and eggs are laid in it
	function ENT:Store(item)
		item.RMPG_Brood = self
		for i = 0, item:GetPhysicsObjectCount() - 1 do
			local po = item:GetPhysicsObjectNum(i)
			if IsValid(po) then
				po:SetVelocity(vector_origin)
				po:EnableMotion(false)
			end
		end
		self.Brood[#self.Brood + 1] = item
		local corpse = item:GetClass() == "prop_ragdoll"
		local n = corpse and 3 or math.Clamp(math.ceil(item:BoundingRadius() / 14), 1, 2)
		item.RMPG_Eggs = 0
		for _ = 1, n do
			local at
			if corpse then
				local po = item:GetPhysicsObjectNum(math.random(0, math.max(item:GetPhysicsObjectCount() - 1, 0)))
				at = IsValid(po) and po:GetPos() or item:WorldSpaceCenter()
			else
				local c = item:WorldSpaceCenter()
				local dir = (VectorRand() + UP):GetNormalized()
				local tr = util.TraceLine({ start = c + dir * (item:BoundingRadius() + 10), endpos = c, mask = MASK_SHOT })
				at = tr.Entity == item and tr.HitPos or c + dir * item:BoundingRadius() * 0.5
			end
			local e = ents.Create("rmpg_worm_egg")
			if IsValid(e) then
				e.Nest, e.Item = self, item
				item.RMPG_Eggs = item.RMPG_Eggs + 1
				e:SetPos(at)
				e:SetAngles(Angle(0, math.Rand(0, 360), 0))
				e:Spawn()
			end
		end
		sound.Play(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), item:WorldSpaceCenter(), 70, 110)
	end

	-- A hatched egg: the area the colony holds grows
	function ENT:Hatched()
		self.Creep = math.min(self.Creep + 40, 900)
	end

	local function Queenly(w)
		return IsValid(w) and not w.Dead and w:IsQueen()
	end

	function ENT:Think()
		local now = CurTime()
		if RMPG.TimeStopped then
			self:NextThink(now + 0.5)
			return true
		end
		local n = self:Count()
		if Queenly(self.Queen) then
			self.Orphan = nil
			if n < 3 and self:HasRoom() and now >= self.NextBud then
				self.NextBud = now + RMPG.CV.wormBudTime:GetFloat()
				self.Queen:Bud()
			end
		else
			-- the queen is gone: the biggest worker takes her place, and with no one left the lair dies
			self.Orphan = self.Orphan or now
			if now - self.Orphan > 8 then
				local best, bs
				for w in pairs(self.Members) do
					if IsValid(w) and not w.Dead and (not bs or w:GetSize() > bs) then best, bs = w, w:GetSize() end
				end
				if best then
					self.Orphan = nil
					best:BecomeQueen(self)
				elseif now - self.Orphan > 60 and Eggs(self) == 0 then
					self:Remove()
					return
				end
			end
		end
		-- slime creeps out over the ground it holds
		if now >= self.NextCreep then
			self.NextCreep = now + 3
			local a, r = math.Rand(0, math.pi * 2), self.Creep * math.sqrt(math.random())
			local p = self:GetPos() + Vector(math.cos(a) * r, math.sin(a) * r, 40)
			local tr = util.TraceLine({ start = p, endpos = p - UP * 200, mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit and not tr.StartSolid and RMPG.CV.wormSlime:GetBool() then util.Decal("RMPG_SlimeBig", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal) end
		end
		-- full: one of them leaves to start another lair
		if now >= self.NextExpand then
			self.NextExpand = now + 45
			if not self:HasRoom() and RMPG.CV.wormNest:GetBool() then
				for w in pairs(self.Members) do
					if IsValid(w) and w ~= self.Queen and w:GetSize() >= 0.12 and w:GetState() == 0 then
						w:GoFound(now, w:GetPos(), true)
						break
					end
				end
			end
		end
		self:NextThink(now + 0.5)
		return true
	end

	function ENT:OnTakeDamage(dmg)
		local att = dmg:GetAttacker()
		if IsValid(att) then self:Alarm(att) end
		self.HP = self.HP - dmg:GetDamage()
		local ed = EffectData()
		ed:SetOrigin(dmg:GetDamagePosition())
		ed:SetColor(0)
		util.Effect("BloodImpact", ed, true, true)
		if self.HP > 0 or self.Dead then return end
		self.Dead = true
		local pos = self:GetPos()
		ed:SetOrigin(pos + UP * 12)
		for _ = 1, 8 do util.Effect("BloodImpact", ed, true, true) end
		sound.Play(RMPG.SND.wormDie, pos, 85, 70)
		self:Remove()
	end

	return
end

function ENT:Draw(flags)
	self:DrawModel(flags)
end
