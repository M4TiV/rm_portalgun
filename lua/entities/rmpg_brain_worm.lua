AddCSLuaFile()

-- Brain worm: a fleshy worm that is a real physical rope - a chain of balls on ball joints (rmpg_worm_seg) that sags,
-- swings and can be grabbed, thrown and shot. Its size is counted in players: at 1 it stands as tall as a player, at
-- 2 (the most, rmpg_worm_maxsize) as tall as two - a monster that crushes everything in its way.
-- It crawls about looking for something: prey, a corpse to eat, a ceiling to hang from and wait (while it is small
-- enough to climb), props to smash (when it is huge). A small one drops onto heads and bites - shoot it off or tear
-- it off with E (it ends up in your hand) within rmpg_worm_enter seconds, or it is inside - a middle one strikes, a
-- huge one rolls over everything. It grows slowly with time and with what it eats.
-- The symbiont syringe (weapon_rmpg_worm_syringe) puts a tiny one into a head: there it grows rmpg_worm_headgrow a
-- minute, the head swells, the host's health shows only "??", and when it is full grown (or the host dies) it bursts
-- out at the size it has reached. An empty syringe pulls it out again - unless it is huge by then: then it jumps out
-- through the ear and goes after the host.
-- The body is a skinned model (models/rmpg/brain_worm.mdl, dev/model_src/build_worm.py): every frame its bones are
-- put on the physics balls, nothing else is computed in Lua.
-- It eats corpses, the pieces of other worms and loose props, and a big one swallows people whole. Experimental: worms
-- that meet grow together into one, and a big worm with several people around tears itself up to go after them all.
-- Killed, it leaves bloody pieces (rmpg_worm_chunk): one from a small worm, three from a big one.
-- A worm picks a sheltered spot, builds a lair there (rmpg_worm_nest) and lies curled up in it as the queen, budding off
-- workers. They haul props and corpses home, eggs are laid in them (rmpg_worm_egg), and the colony spreads like an ant
-- hill. They defend it together, run when badly hurt, and leave a thin trail of slime wherever they crawl.
-- Given a plumbus (weapon_rmpg_plumbus) a worm is tamed: it follows you about like a dog, bounces, runs round the room,
-- meows, likes to be stroked (E), and goes for whoever hurts you.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.worm"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.IconOverride = "entities/rmpg_brain_worm.png"
ENT.WormModel = "models/rmpg/brain_worm.mdl"

list.Set("NPC", "rmpg_brain_worm", { Name = "#rmpg.worm", Class = "rmpg_brain_worm", Category = "Rick and Morty" })
list.Set("NPC", "rmpg_brain_worm_huge", { Name = "#rmpg.worm_huge", Class = "rmpg_brain_worm", Category = "Rick and Morty", KeyValues = { worm_size = "2" } })

local SEGS = 12
local WANDER, CLIMB, CLING, HUNT, LUNGE, LATCH, EAT, EMERGE, MERGE, SWALLOW, SEEK, QUEEN, CARRY, FLEE, PET = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
local UP = Vector(0, 0, 1)
local START_SIZE = 0.08 -- from the spawn menu
local TINY, CLIMBER, HUGE = 0.3, 0.9, 1.2 -- below TINY it rides heads, below CLIMBER it climbs, from HUGE it crushes
local SWALLOW_MIN = 0.8 -- from this size it can take a person whole
local QUEEN_MIN = 0.1   -- the smallest worm that can start a lair
local HOME_RANGE = 1600 -- how far workers go from their lair
game.AddDecal("RMPG_SlimeBig", "rmpg/decal_slime_big")
RMPG.WORM_HUGE = HUGE

-- Body ball radius, head radius and the gap between balls for a size
local function BodyR(size) return 0.8 + 24 * size end
local function HeadR(size) return BodyR(size) * 1.6 end
local function Gap(size) return BodyR(size) * 1.8 end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Size")
	self:NetworkVar("Float", 1, "BiteT") -- last bite / strike, for the mouth
	self:NetworkVar("Float", 2, "Built") -- the size the physics balls have now (drawn at that)
	self:NetworkVar("Int", 0, "State")
	self:NetworkVar("Entity", 0, "Victim")
	self:NetworkVar("Entity", 1, "Master") -- whoever tamed it with a plumbus
end

-- The balls of the body, head first
function ENT:Segments()
	local list = self.SegCache
	local n = self:GetNW2Int("SegN", 0)
	if list and #list == n and IsValid(list[1]) and IsValid(list[n]) and list[1] == self:GetNW2Entity("Seg1") then return list end
	list = {}
	for i = 1, n do
		local s = self:GetNW2Entity("Seg" .. i)
		if not IsValid(s) then break end
		list[i] = s
	end
	self.SegCache = list
	return list
end

-- The top of a player's or NPC's head
local function HeadOf(e)
	if RMPG.BootsOn(e) then return e:EyePos() end -- the server's bones of someone on a wall stay upright
	local b = e:LookupBone("ValveBiped.Bip01_Head1")
	local m = b and e:GetBoneMatrix(b)
	if m then return m:GetTranslation() end
	if e:IsPlayer() then return e:EyePos() end
	return e:GetPos() + UP * e:OBBMaxs().z
end

if SERVER then
	-- the ceiling first, then walls, the floor last: at the foot of a wall it climbs instead of pushing into it
	local DIRS = { UP, Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), -UP }
	local PROPS = { prop_physics = true, prop_physics_multiplayer = true, func_physbox = true, func_breakable = true, prop_ragdoll = true, func_pushable = true }

	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 8)
		e:Spawn()
		e:Activate()
		return e
	end

	function ENT:KeyValue(k, v)
		if k == "worm_size" then self.StartSize = tonumber(v) end
	end

	function ENT:Initialize()
		self:SetModel(self.WormModel)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetNotSolid(true)
		self:DrawShadow(false)
		self.Fed = 0
		self.LastGrow = CurTime()
		self.NextLairTry = CurTime() + math.Rand(20, 40)
		if IsValid(self.Colony) then self.Colony:Join(self) end
		local size = math.Clamp(self.StartSize or START_SIZE, 0.03, math.max(RMPG.CV.wormMax:GetFloat(), 0.1))
		if self.EmergeTo then
			-- bursting out of a head: out comes a small one that swells to its real size in a few seconds
			self.EmergeFrom = CurTime()
			size = math.min(self.EmergeTo, 0.25)
		end
		self:SetSize(size)
		if not self.EmergeTo then
			-- the head resting on the ground, not stuck in it
			local rh = HeadR(size)
			local tr = util.TraceLine({ start = self:GetPos() + UP * 4, endpos = self:GetPos() - UP * (rh + 64), mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit then self:SetPos(tr.HitPos + UP * (rh + 2)) end
		end
		self:Build(size, self.StartDir)
		self:SetState(self.EmergeTo and EMERGE or WANDER)
		self:ApplyMode()
		if self.EmergeTo then
			sound.Play(string.format(RMPG.SND.wormRoar, math.random(1, 3)), self:GetPos(), 85, math.Clamp(140 - self.EmergeTo * 40, 60, 140))
		end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	-- Points at arc lengths along a path (a list of points), going straight on past its end
	local function AlongPath(pts, dists)
		local out = {}
		local k, acc = 1, 0
		for i, want in ipairs(dists) do
			while k < #pts and acc + pts[k]:Distance(pts[k + 1]) < want do
				acc = acc + pts[k]:Distance(pts[k + 1])
				k = k + 1
			end
			if k < #pts then
				local a, b = pts[k], pts[k + 1]
				out[i] = a + (b - a) * ((want - acc) / math.max(a:Distance(b), 0.001))
			else
				local last, prev = pts[#pts], pts[math.max(#pts - 1, 1)]
				local dir = last - prev
				if dir:LengthSqr() < 0.01 then dir = -UP end
				out[i] = last + dir:GetNormalized() * (want - acc)
			end
		end
		return out
	end

	-- (Re)builds the body at a size along the shape it has now (or lying out from where it stands), so growing keeps
	-- its curve; balls that would end up in a wall stop at the wall
	function ENT:Build(size, along)
		local old = self.Segs or {}
		local pts = {}
		for _, s in ipairs(old) do
			if IsValid(s) then pts[#pts + 1] = s:GetPos() end
		end
		local rb, rh, gap = BodyR(size), HeadR(size), Gap(size)
		local len = gap * (SEGS - 1)
		if #pts < 2 then
			local head = pts[1] or self:GetPos()
			if not along then
				local a = math.Rand(0, math.pi * 2)
				along = Vector(math.cos(a), math.sin(a), 0)
			end
			-- room for the whole body that way? Otherwise another way
			for _, d in ipairs({ along, -along, along:Cross(UP), -along:Cross(UP), UP, -UP }) do
				local tr = util.TraceHull({ start = head, endpos = head + d * len, mins = Vector(-rb, -rb, -rb), maxs = Vector(rb, rb, rb), mask = MASK_SOLID })
				if not tr.Hit then
					along = d
					break
				end
			end
			pts = { head, head + along * len }
		end
		local dists = {}
		for i = 1, SEGS do dists[i] = gap * (i - 1) end
		local where = AlongPath(pts, dists)
		for _, s in ipairs(old) do
			if IsValid(s) then s:Remove() end
		end
		self.Segs = {}
		self.BuiltSize = size
		self:SetBuilt(size)
		self.Gap = gap
		self.MaxHP = 25 + 640 * size ^ 1.5
		self.HP = math.min(self.HP or self.MaxHP, self.MaxHP) + (self.Built and self.MaxHP * 0.15 or 0)
		self.HP = math.min(self.HP, self.MaxHP)
		self.Built = true
		local prev
		for i = 1, SEGS do
			local r = i == 1 and rh or rb * (1 - 0.5 * (i - 2) / (SEGS - 2))
			local pos = where[i]
			if IsValid(prev) then
				-- into a wall: bend along it (or any free way) instead of piling up against it
				local from = prev:GetPos()
				local box = Vector(r, r, r) * 0.8
				local tr = util.TraceHull({ start = from, endpos = pos, mins = -box, maxs = box, mask = MASK_SOLID_BRUSHONLY })
				if tr.Hit then
					local d = (pos - from):GetNormalized()
					local slide = d - tr.HitNormal * d:Dot(tr.HitNormal)
					local found
					for _, try in ipairs({ slide, UP, slide:Cross(UP), -slide:Cross(UP), -UP }) do
						if try:LengthSqr() > 0.01 then
							local alt = from + try:GetNormalized() * gap
							if not util.TraceHull({ start = from, endpos = alt, mins = -box, maxs = box, mask = MASK_SOLID_BRUSHONLY }).Hit then
								found = alt
								break
							end
						end
					end
					pos = found or tr.HitPos
				end
			end
			local s = ents.Create("rmpg_worm_seg")
			if not IsValid(s) then break end
			s.Radius = r
			-- a small one is light enough to pick up
			s.Mass = size < TINY and math.Clamp(0.2 * r * r, 0.5, 20) or math.Clamp(1 + 1.4 * r * r, 1, 30000)
			s.Worm = self
			s:SetPos(pos)
			s:Spawn()
			s:Activate()
			if IsValid(prev) then
				constraint.Ballsocket(s, prev, 0, 0, prev:WorldToLocal((prev:GetPos() + pos) / 2), 0, 0, 1)
			end
			self.Segs[i] = s
			self:SetNW2Entity("Seg" .. i, s)
			prev = s
		end
		self:SetNW2Int("SegN", #self.Segs)
	end

	-- Gravity / frozen head to match what it is doing
	function ENT:ApplyMode()
		local st = self:GetState()
		for i, s in ipairs(self.Segs or {}) do
			local po = IsValid(s) and s:GetPhysicsObject()
			if IsValid(po) then
				if st == CLING and i == 1 then
					po:EnableMotion(false)
				else
					po:EnableMotion(true)
					po:EnableGravity(st ~= CLIMB and st ~= QUEEN)
					po:Wake()
				end
			end
		end
	end

	function ENT:SetMode(state)
		if state ~= CARRY and self.Cargo then self:DropCargo() end
		self:SetState(state)
		self:ApplyMode()
	end

	function ENT:IsQueen()
		return self:GetState() == QUEEN
	end

	function ENT:Speed()
		return 60 + 110 * self:GetSize()
	end

	local function Prey(e)
		if not IsValid(e) or e.RMPG_Vaporized then return false end
		if e:IsPlayer() then return not RMPG.IgnorePlayers() and e:Alive() and not e:HasGodMode() and e:GetMoveType() ~= MOVETYPE_NOCLIP end
		if e.IsLambdaPlayer then return RMPG.PersonAlive(e) end
		if e:IsNPC() or e:IsNextBot() then return e:Health() > 0 end
		return false
	end

	local function Seen(from, e)
		local tr = util.TraceLine({ start = from, endpos = e:WorldSpaceCenter(), mask = MASK_SOLID_BRUSHONLY })
		return not tr.Hit
	end

	local function Range(size)
		return size < TINY and 260 or size < HUGE and 750 or 1600
	end

	-- Everyone it can see from here
	function ENT:AllPrey(pos)
		local list = {}
		for _, e in ipairs(ents.FindInSphere(pos, Range(self:GetSize()))) do
			if Prey(e) and Seen(pos, e) then list[#list + 1] = e end
		end
		return list
	end

	-- The nearest prey it can see
	function ENT:FindPrey(pos)
		local range = Range(self:GetSize())
		local best, bd
		for _, e in ipairs(ents.FindInSphere(pos, range)) do
			if Prey(e) then
				local d = e:GetPos():DistToSqr(pos)
				if (not bd or d < bd) and Seen(pos, e) then best, bd = e, d end
			end
		end
		return best
	end

	local function Meaty(e)
		local c = e:GetClass()
		return c == "prop_ragdoll" or c == "rmpg_worm_chunk"
	end

	local NOT_FOOD = { rmpg_worm_seg = true, rmpg_worm_nest = true, rmpg_worm_egg = true, rmpg_boots_body = true, rmpg_portal = true,
		rmpg_meltdown = true, rmpg_phoenix_tank = true, rmpg_brain_worm = true, weapon_rmpg_plumbus = true }

	-- Anything loose that goes into its mouth (what is fixed to the world or to something else stays)
	local function Edible(e, reach)
		if NOT_FOOD[e:GetClass()] or e:IsPlayer() or e:IsNPC() or e:IsNextBot() or e:IsVehicle() then return false end
		if e:GetMoveType() ~= MOVETYPE_VPHYSICS or e:BoundingRadius() > reach or IsValid(e:GetParent()) then return false end
		if e:IsWeapon() and IsValid(e:GetOwner()) then return false end
		if constraint.HasConstraints(e) then return false end
		local po = e:GetPhysicsObject()
		return IsValid(po) and po:IsMotionEnabled()
	end

	-- Nobody has it, it is not in a lair and nothing failed on it lately
	local function Free(e)
		return not e.RMPG_Eaten and not e.RMPG_Brood and not e.RMPG_CarriedBy and (e.RMPG_NoFood or 0) < CurTime() and not e:IsPlayerHolding()
	end

	-- Something to eat: a corpse, a piece of a worm or a loose prop
	function ENT:FindFood(pos)
		local props = RMPG.CV.wormEatProps:GetBool()
		local reach = 14 + 80 * self:GetSize()
		local best, bd
		for _, e in ipairs(ents.FindInSphere(pos, 1200)) do
			if (Meaty(e) or (props and Edible(e, reach))) and Free(e) then
				local d = e:GetPos():DistToSqr(pos)
				if (not bd or d < bd) and Seen(pos, e) then best, bd = e, d end
			end
		end
		return best
	end

	-- What a worker can drag home: a corpse, or anything loose it can get its mouth round
	function ENT:FindCargo(pos)
		local size = self:GetSize()
		local props = RMPG.CV.wormEatProps:GetBool()
		local reach = 14 + 80 * size
		local best, bd
		for _, e in ipairs(ents.FindInSphere(pos, 1400)) do
			local corpse = e:GetClass() == "prop_ragdoll" and size >= 0.1
			if (corpse or (props and Edible(e, reach))) and Free(e) then
				local d = e:GetPos():DistToSqr(pos)
				if (not bd or d < bd) and Seen(pos, e) then best, bd = e, d end
			end
		end
		return best
	end

	-- A lair nearby with room for one more
	local function FindNest(pos)
		for _, n in ipairs(ents.FindByClass("rmpg_worm_nest")) do
			if n:GetPos():DistToSqr(pos) < 2000 * 2000 and n:HasRoom() then return n end
		end
	end

	-- Where to build a lair: flat ground with walls around and a roof if it can be had, away from people and other lairs
	function ENT:FindLairSpot(hp, far)
		local nests = ents.FindByClass("rmpg_worm_nest")
		local best, bs
		for _ = 1, 10 do
			local a = math.Rand(0, math.pi * 2)
			local d = Vector(math.cos(a), math.sin(a), 0)
			local from = hp + UP * 20
			local tr = util.TraceLine({ start = from, endpos = from + d * math.Rand(far and 1200 or 150, far and 2500 or 900), mask = MASK_SOLID_BRUSHONLY })
			local p = tr.HitPos - d * 70
			local down = util.TraceLine({ start = p, endpos = p - UP * 300, mask = MASK_SOLID_BRUSHONLY })
			if down.Hit and not down.StartSolid and not down.HitSky and down.HitNormal.z > 0.8 then
				local g = down.HitPos
				local score = math.Rand(0, 1)
				for k = 0, 7 do
					local w = k / 8 * math.pi * 2
					if util.TraceLine({ start = g + UP * 30, endpos = g + UP * 30 + Vector(math.cos(w), math.sin(w), 0) * 260, mask = MASK_SOLID_BRUSHONLY }).Hit then score = score + 1 end
				end
				if util.TraceLine({ start = g + UP * 30, endpos = g + UP * 430, mask = MASK_SOLID_BRUSHONLY }).Hit then score = score + 2 end
				for _, ply in ipairs(player.GetAll()) do
					if ply:GetPos():DistToSqr(g) < 300 * 300 then score = score - 3 end
				end
				local ok = true
				for _, n in ipairs(nests) do
					if n:GetPos():DistToSqr(g) < 1200 * 1200 then ok = false end
				end
				if ok and (not bs or score > bs) then best, bs = g, score end
			end
		end
		return best
	end

	-- Another worm to grow together with: both free, and not bigger than a worm can be
	function ENT:FindMate(pos)
		local now = CurTime()
		if now < (self.NoMergeUntil or 0) then return end
		local room = math.max(RMPG.CV.wormMax:GetFloat(), 0.1) - self:GetSize()
		local best, bd
		for _, w in ipairs(ents.FindByClass("rmpg_brain_worm")) do
			local st = w:GetState()
			if w ~= self and not w.Dead and (st == WANDER or st == MERGE) and not IsValid(w.Colony) and w:GetSize() <= room and now >= (w.NoMergeUntil or 0) then
				local d = w:GetPos():DistToSqr(pos)
				if d < 1200 * 1200 and (not bd or d < bd) and Seen(pos, w) then best, bd = w, d end
			end
		end
		return best
	end

	-- Something to smash (a huge worm goes for props)
	function ENT:FindProp(pos)
		local best, bd
		for _, e in ipairs(ents.FindInSphere(pos, 1000)) do
			if PROPS[e:GetClass()] and e:GetClass() ~= "prop_ragdoll" and (e.RMPG_Smashed or 0) < CurTime() then
				local d = e:GetPos():DistToSqr(pos)
				if not bd or d < bd then best, bd = e, d end
			end
		end
		return best
	end

	-- Touching a surface: the worm can hold on there; returns the trace of the surface
	function ENT:Grip(pos, r)
		for _, d in ipairs(DIRS) do
			local tr = util.TraceLine({ start = pos, endpos = pos + d * (r + 4), mask = MASK_SOLID, filter = self.Segs })
			if tr.Hit and not tr.HitSky then return tr end
		end
	end

	-- The nearest wall around (where to climb from the floor), or nil
	function ENT:FindWall(pos)
		local best, bd
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local d = Vector(math.cos(a), math.sin(a), 0)
			local tr = util.TraceLine({ start = pos, endpos = pos + d * 800, mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit and math.abs(tr.HitNormal.z) < 0.4 and (not bd or tr.Fraction < bd) then best, bd = d, tr.Fraction end
		end
		return best
	end

	-- Somewhere to crawl to: a random way (away from a wall if given) as far as there is room
	function ENT:RoamGoal(pos, away)
		-- a worker does not stray too far from home
		local nest = self.Colony
		if IsValid(nest) and nest:GetPos():DistToSqr(pos) > HOME_RANGE * HOME_RANGE then return nest:GetPos() end
		local reach = 250 + 500 * self:GetSize()
		for _ = 1, 6 do
			local a = math.Rand(0, math.pi * 2)
			local d = Vector(math.cos(a), math.sin(a), 0)
			if away then d = (d + Vector(away.x, away.y, 0) * 1.2):GetNormalized() end
			local tr = util.TraceLine({ start = pos, endpos = pos + d * reach, mask = MASK_SOLID_BRUSHONLY })
			if tr.Fraction > 0.3 then return pos + d * (reach * tr.Fraction * 0.9) end
		end
		return pos + VectorRand() * 100
	end

	-- On the ground or a surface right under the head?
	function ENT:Grounded(pos)
		-- the head may be lying on its own body: that much above the ground still counts, or it would just stop there
		local reach = HeadR(self.BuiltSize) + BodyR(self.BuiltSize) * 2.4 + 12
		local tr = util.TraceLine({ start = pos, endpos = pos - UP * reach, mask = MASK_SOLID, filter = self.Segs })
		return tr.Hit
	end

	-- The head crawls one way with a snake's wiggle; the body follows it along its path (each ball pulled after the
	-- one in front), so it crawls rather than being dragged. Climbing, everything moves in 3D without gravity.
	function ENT:Crawl(dir, speed, climbing)
		local head = self.Segs[1]
		local po = IsValid(head) and head:GetPhysicsObject()
		if not IsValid(po) then return end
		local v = po:GetVelocity()
		local want = dir * speed
		if not climbing then
			local side = dir:Cross(UP)
			want = want + side * (math.sin(CurTime() * 3) * 0.35 * speed)
			want.z = v.z
		end
		po:SetVelocity(LerpVector(0.25, v, want))
		for i = 2, #self.Segs do
			local s, prev = self.Segs[i], self.Segs[i - 1]
			local sp = IsValid(s) and s:GetPhysicsObject()
			if IsValid(sp) and IsValid(prev) then
				local d = (prev:GetPos() - s:GetPos()):GetNormalized() * (speed * 0.8)
				local sv = sp:GetVelocity()
				if climbing then
					sp:SetVelocity(LerpVector(0.25, sv, d))
				else
					sp:SetVelocity(Vector(Lerp(0.2, sv.x, d.x), Lerp(0.2, sv.y, d.y), sv.z))
				end
			end
		end
	end

	-- Stuck against something while crawling: off another way, with a little hop
	function ENT:Unstick(now, hp, speed)
		local head = self.Segs[1]
		local po = head:GetPhysicsObject()
		if po:GetVelocity():Length2D() < speed * 0.2 then
			self.StuckFor = (self.StuckFor or 0) + FrameTime()
			if self.StuckFor > 1.5 then
				self.StuckFor = 0
				self.Goal = self:RoamGoal(hp)
				self.GoalEnd = now + 6
				po:SetVelocity(po:GetVelocity() + UP * speed * 0.6)
				return true
			end
		else
			self.StuckFor = 0
		end
	end

	function ENT:Bite(v, amount, kind)
		local d = DamageInfo()
		d:SetDamage(amount)
		d:SetDamageType(kind or DMG_SLASH)
		d:SetAttacker(self)
		d:SetInflictor(self)
		d:SetDamagePosition(HeadOf(v))
		d:SetDamageForce((v:WorldSpaceCenter() - self:GetPos()):GetNormalized() * amount * 300)
		v:TakeDamageInfo(d)
		self.Fed = self.Fed + amount * 0.0006
		if not Prey(v) then self.Fed = self.Fed + 0.03 end -- it got them
		self:SetBiteT(CurTime())
		local head = self.Segs[1]
		head:EmitSound(string.format(RMPG.SND.wormBite, math.random(1, 3)), 70 + 10 * self:GetSize(), math.Clamp(125 - self:GetSize() * 35, 55, 130))
		local ed = EffectData()
		ed:SetOrigin(HeadOf(v))
		ed:SetColor(0)
		util.Effect("BloodImpact", ed, true, true)
	end

	function ENT:BiteDamage()
		return RMPG.CV.wormDamage:GetFloat() * (0.5 + 1.5 * self:GetSize())
	end

	function ENT:StartHunt(e)
		self:SetVictim(e)
		self:SetMode(HUNT)
		self.HuntEnd = CurTime() + 20
		local head = self.Segs[1]
		head:EmitSound(string.format(self:GetSize() >= HUGE and RMPG.SND.wormRoar or RMPG.SND.wormScream, math.random(1, 3)), 75 + 10 * self:GetSize(), math.Clamp(150 - self:GetSize() * 45, 50, 150))
	end

	-- In through the ear: the worm on the head becomes the worm in the head
	function ENT:EnterHead(v)
		self.Dead = true
		local size = self:GetSize()
		self:Release()
		RMPG.WormInfect(v, size)
		local ed = EffectData()
		ed:SetOrigin(HeadOf(v))
		ed:SetColor(0)
		for _ = 1, 3 do util.Effect("BloodImpact", ed, true, true) end
		self:Remove()
	end

	function ENT:Lunge(e)
		local head = self.Segs[1]
		local po = IsValid(head) and head:GetPhysicsObject()
		if not IsValid(po) then return end
		self:SetVictim(e)
		self:SetMode(LUNGE)
		self.LungeEnd = CurTime() + 1.6
		po:SetVelocity((HeadOf(e) - head:GetPos()):GetNormalized() * (650 + 200 * self:GetSize()) + UP * 60)
		self:SetBiteT(CurTime())
		head:EmitSound(string.format(RMPG.SND.wormScream, math.random(1, 3)), 75, math.Clamp(150 - self:GetSize() * 45, 60, 150))
	end

	function ENT:Release()
		local v = self:GetVictim()
		if IsValid(v) and v:IsPlayer() then
			v:SetNW2Entity("RMPG_WormOn", NULL)
			v:SetNW2Float("RMPG_WormEnterAt", 0)
		end
		self.EnterAt = nil
		self.Mate = nil
		self:SetVictim(NULL)
		self:SetMode(WANDER)
		self.NextHunt = CurTime() + 4
	end

	-- Hanging from a ceiling is over (or it cannot hold on any more): down it goes
	function ENT:Drop()
		self.NextAmbush = CurTime() + math.Rand(15, 30)
		self:SetMode(WANDER)
	end

	---------------------------------------------------------------------------
	-- What it does
	---------------------------------------------------------------------------

	-- What a worm does with its time: a worker hauls food home, a free worm joins a lair or starts its own
	function ENT:Work(now, hp)
		local nest = self.Colony
		if IsValid(nest) then
			if now >= (self.NextCargo or 0) and nest:WantsFood() then
				self.NextCargo = now + 2
				local item = self:FindCargo(hp)
				if item then
					self:StartCarry(item, now)
					return true
				end
			end
			return false
		end
		self.Colony = nil
		if now < (self.NextLairTry or 0) or not RMPG.CV.wormNest:GetBool() then return false end
		self.NextLairTry = now + math.Rand(15, 30)
		local near = FindNest(hp)
		if near then
			near:Join(self)
			return false
		end
		if self:GetSize() < QUEEN_MIN then return false end
		return self:GoFound(now, hp, false)
	end

	-- Off to build a lair
	function ENT:GoFound(now, hp, far)
		if #ents.FindByClass("rmpg_worm_nest") >= RMPG.CV.wormNestMax:GetInt() then return false end
		local spot = self:FindLairSpot(hp, far)
		if not spot then return false end
		if IsValid(self.Colony) then self.Colony:Leave(self) end
		self.LairSpot, self.SeekEnd = spot, now + 30
		self:SetMode(SEEK)
		return true
	end

	function ENT:Wander(now, hp)
		local size = self:GetSize()
		local speed = self:Speed() * 0.8
		if (self.NextLook or 0) < now then
			self.NextLook = now + 0.5
			-- the one whose head it came out of comes first
			if Prey(self.Grudge) and size >= TINY then
				self:StartHunt(self.Grudge)
				self.HuntEnd = now + 90
				return
			end
			if (self.NextHunt or 0) < now then
				local prey = self:FindPrey(hp)
				if prey then
					if size < TINY then
						if prey:GetPos():Distance(hp) < 200 then self:Lunge(prey) return end
					else
						if (self.NextSplit or 0) < now and self:Split(now, hp) then return end
						self:StartHunt(prey)
						return
					end
				end
			end
			-- two worms with nothing better to do grow together
			if now > (self.NextMate or 0) and RMPG.CV.wormMerge:GetBool() and not IsValid(self.Colony) then
				self.NextMate = now + math.Rand(5, 10)
				local mate = self:FindMate(hp)
				if mate then
					self.Mate, self.MateEnd = mate, now + 12
					self:SetMode(MERGE)
					return
				end
			end
			if self:Work(now, hp) then return end
			if now > (self.NextMeal or 0) then
				self.NextMeal = now + 2
				local food = self:FindFood(hp)
				if food then
					self.Meal = food
					self.MealEnd = now + 15
					self:SetMode(EAT)
					return
				end
			end
			-- small and middle worms like to hang from a ceiling and wait for someone to walk under
			if size < CLIMBER and now > (self.NextAmbush or 0) and not IsValid(self.Colony) then
				self.NextAmbush = now + math.Rand(30, 60)
				local up = util.TraceLine({ start = hp, endpos = hp + UP * 900, mask = MASK_SOLID_BRUSHONLY })
				if up.Hit and not up.HitSky and up.Fraction * 900 > HeadR(size) * 3 then
					local wall = self:FindWall(hp)
					if wall then
						self.WallDir = wall
						self.ClimbEnd = now + 25
						self.LostAt = nil
						self:SetMode(CLIMB)
						return
					end
				end
			end
			-- a huge one goes for the props around
			if size >= HUGE and (not IsValid(self.GoalEnt) or now > (self.GoalEnd or 0)) then
				local p = self:FindProp(hp)
				if IsValid(p) then
					self.GoalEnt = p
					self.Goal = p:WorldSpaceCenter()
					self.GoalEnd = now + 8
				end
			end
			if IsValid(self.GoalEnt) then self.Goal = self.GoalEnt:WorldSpaceCenter() end
			if not self.Goal or hp:Distance2D(self.Goal) < HeadR(size) * 2 or now > (self.GoalEnd or 0) then
				self.GoalEnt = nil
				self.Goal = self:RoamGoal(hp)
				self.GoalEnd = now + 8
			end
		end
		if not self:Grounded(hp) then return end
		local dir = (self.Goal or hp + self:GetForward()) - hp
		dir.z = 0
		dir:Normalize()
		-- a wall right ahead: turn away from it
		local r = HeadR(size)
		local tr = util.TraceHull({ start = hp, endpos = hp + dir * r * 2.5, mins = Vector(-r, -r, -r) * 0.5, maxs = Vector(r, r, r) * 0.5, mask = MASK_SOLID_BRUSHONLY })
		if tr.Hit and tr.HitNormal.z < 0.5 then
			self.GoalEnt = nil
			self.Goal = self:RoamGoal(hp, tr.HitNormal)
			self.GoalEnd = now + 6
		end
		if not self:Unstick(now, hp, speed) then self:Crawl(dir, speed) end
	end

	function ENT:Climb(now, hp)
		local size = self:GetSize()
		if now > self.ClimbEnd or size >= CLIMBER then
			self:Drop()
			return
		end
		local head = self.Segs[1]
		local po = head:GetPhysicsObject()
		local grip = self:Grip(hp, HeadR(size))
		local speed = self:Speed()
		local dir
		if grip then
			self.LostAt = nil
			local n = grip.HitNormal
			if n.z > 0.7 then
				dir = self.WallDir                      -- on the floor: off to the wall
			elseif n.z > -0.7 then
				dir = (UP - n * 0.4):GetNormalized()     -- on a wall: up it, pressed against it
			else
				-- reached the ceiling: hold on there and let the body hang
				self.ClingEnd = now + math.Rand(15, 30)
				self:SetMode(CLING)
				return
			end
		else
			-- lost the surface for a moment (a gap, a push): keep going for the wall, give up if it lasts
			self.LostAt = self.LostAt or now
			if now - self.LostAt > 1.5 then
				self:Drop()
				return
			end
			dir = (self.WallDir + UP * 0.3):GetNormalized()
		end
		self:Crawl(dir, speed, true)
		if not IsValid(po) then return end
		-- someone walks right past: go for them
		if (self.NextHunt or 0) < now then
			self.NextHunt = now + 0.4
			for _, e in ipairs(ents.FindInSphere(hp, 90 + 120 * size)) do
				if Prey(e) then
					self:Lunge(e)
					break
				end
			end
		end
	end

	function ENT:Cling(now, hp)
		local size = self:GetSize()
		if now > (self.ClingEnd or 0) or size >= CLIMBER then
			self:Drop()
			return
		end
		if (self.NextHunt or 0) < now then
			self.NextHunt = now + 0.3
			local reach = 110 + 220 * size
			for _, e in ipairs(ents.FindInSphere(hp, 900)) do
				if Prey(e) then
					local d = HeadOf(e) - hp
					if d.z < -16 and d:Length2D() < reach and Seen(hp, e) then
						self:Lunge(e)
						break
					end
				end
			end
		end
	end

	function ENT:Hunt(now, hp)
		local v = self:GetVictim()
		local size = self:GetSize()
		if not Prey(v) or now > (self.HuntEnd or 0) or (v ~= self.Grudge and v:GetPos():Distance(hp) > 2400) then
			self:SetVictim(NULL)
			self.NextHunt = now + 2
			self:SetMode(WANDER)
			return
		end
		local head = self.Segs[1]
		local po = head:GetPhysicsObject()
		local rh = HeadR(size)
		local d = v:WorldSpaceCenter() - hp
		local dist = d:Length()
		-- big enough: it takes them whole
		if size >= SWALLOW_MIN and now > (self.NextSwallow or 0) and RMPG.CV.wormEatPeople:GetBool() and HeadOf(v):Distance(hp) < rh + 46 then
			self:StartSwallow(v, now)
			return
		end
		-- a middle-sized one strikes with its mouth; a huge one just rolls over them (Crush does that)
		if size < HUGE then
			if self.StrikeEnd and now < self.StrikeEnd then
				if not self.StrikeHit and HeadOf(v):Distance(hp) < rh + 30 then
					self.StrikeHit = true
					self:Bite(v, self:BiteDamage())
				end
				return
			end
			if dist < rh + 110 and now > (self.NextStrike or 0) and IsValid(po) then
				self.StrikeEnd = now + 0.6
				self.StrikeHit = false
				self.NextStrike = now + 1.4
				self:SetBiteT(now)
				po:SetVelocity((HeadOf(v) - hp):GetNormalized() * (420 + 150 * size) + UP * 80)
				head:EmitSound(string.format(RMPG.SND.wormScream, math.random(1, 3)), 75, math.Clamp(150 - size * 45, 60, 150))
				return
			end
		end
		if not self:Grounded(hp) then return end
		d.z = 0
		d:Normalize()
		if not self:Unstick(now, hp, self:Speed()) then self:Crawl(d, self:Speed()) end
	end

	function ENT:LungeThink(now, hp)
		local v = self:GetVictim()
		local size = self:GetSize()
		local head = self.Segs[1]
		local po = head:GetPhysicsObject()
		if not Prey(v) or now > self.LungeEnd then
			self:Release()
		elseif HeadOf(v):Distance(hp) < HeadR(size) + 26 then
			if size < TINY then
				-- a small one wraps itself on top of the head and holds on
				self:SetMode(LATCH)
				self.LatchEnd = now + 10
				self.LatchHP = self.HP
				self.NextBite = now + 0.3
				local enter = RMPG.CV.wormEnter:GetFloat()
				self.EnterAt = enter > 0 and now + enter or nil
				if v:IsPlayer() then
					v:SetNW2Entity("RMPG_WormOn", self)
					v:SetNW2Float("RMPG_WormEnterAt", self.EnterAt or 0)
				end
			else
				self:Bite(v, self:BiteDamage())
				self:StartHunt(v)
			end
		elseif IsValid(po) then
			po:SetVelocity(LerpVector(0.3, po:GetVelocity(), (HeadOf(v) - hp):GetNormalized() * 650))
		end
	end

	function ENT:Latch(now, hp)
		local v = self:GetVictim()
		local head = self.Segs[1]
		local po = head:GetPhysicsObject()
		if not Prey(v) or now > self.LatchEnd or self.HP < self.LatchHP * 0.7 then
			-- let go: it is dead, it took too long or the worm was shot off
			self:Release()
		elseif IsValid(po) then
			po:SetPos(HeadOf(v) + UP * (HeadR(self:GetSize()) + 2))
			po:SetVelocity(v:GetVelocity())
			-- not torn off in time: it goes in
			if self.EnterAt and now >= self.EnterAt and v:GetNW2Float("RMPG_Wormed", 0) <= 0 then
				self:EnterHead(v)
				return
			end
			if now >= self.NextBite then
				self.NextBite = now + 1
				self:Bite(v, self:BiteDamage())
			end
		end
	end

	-- The way to the spot it chose for the lair
	function ENT:SeekThink(now, hp)
		local spot = self.LairSpot
		if not spot or now > self.SeekEnd then
			self.LairSpot = nil
			self:SetMode(WANDER)
			return
		end
		local d = spot - hp
		d.z = 0
		if d:Length() < HeadR(self:GetSize()) * 2 + 20 then
			local nest = ents.Create("rmpg_worm_nest")
			if IsValid(nest) then
				nest.QueenSize = self:GetSize()
				nest:SetPos(spot)
				nest:SetAngles(Angle(0, math.Rand(0, 360), 0))
				nest:Spawn()
				nest:Activate()
				self:BecomeQueen(nest)
			else
				self:SetMode(WANDER)
			end
			return
		end
		d:Normalize()
		if self:Grounded(hp) and not self:Unstick(now, hp, self:Speed()) then self:Crawl(d, self:Speed()) end
	end

	-- A spiral from the tail in the middle out to the head, a body's width between the turns
	local function CoilPoints(ground, size, n)
		local rb, gap = BodyR(size), Gap(size)
		local pts = {}
		local a, r = 0, rb * 1.3
		local step = rb * 2.4 / (2 * math.pi)
		for i = n, 1, -1 do
			local ball = i == 1 and HeadR(size) or rb * (1 - 0.5 * (i - 2) / (SEGS - 2))
			pts[i] = ground + Vector(math.cos(a) * r, math.sin(a) * r, ball + 3)
			local da = gap / math.max(r, gap * 0.6)
			a = a + da
			r = r + step * da
		end
		return pts
	end

	-- It lies down curled up in the lair
	function ENT:BecomeQueen(nest)
		self.Colony = nest
		nest.Queen = self
		nest:Join(self)
		self.Coil = CoilPoints(nest:GetPos(), self.BuiltSize, #self.Segs)
		self.CoilEnd = CurTime() + 4
		self:SetVictim(NULL)
		self:SetMode(QUEEN)
	end

	function ENT:QueenThink(now, hp)
		if not IsValid(self.Colony) then
			self.CoilEnd = nil
			self.Colony = nil
			self:SetMode(WANDER)
			return
		end
		if not self.CoilEnd then return end
		local frozen = now >= self.CoilEnd
		for i, s in ipairs(self.Segs) do
			local po = IsValid(s) and s:GetPhysicsObject()
			if IsValid(po) then
				if frozen then
					po:EnableMotion(false)
				else
					po:SetVelocity((self.Coil[i] - s:GetPos()) * 4)
				end
			end
		end
		if frozen then self.CoilEnd = nil end
	end

	-- A new little worm grows out of the queen's side
	function ENT:Bud()
		local s = self.Segs[math.Clamp(#self.Segs - 2, 1, #self.Segs)]
		local pos = (IsValid(s) and s:GetPos() or self:GetPos()) + UP * 10
		local w = ents.Create("rmpg_brain_worm")
		if IsValid(w) then
			w.StartSize = 0.1
			w.Colony = self.Colony
			w:SetPos(pos)
			w:Spawn()
			w:Activate()
		end
		self:SetBiteT(CurTime())
		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetColor(0)
		for _ = 1, 3 do util.Effect("BloodImpact", ed, true, true) end
		sound.Play(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), pos, 75, 120)
	end

	-- Someone is attacking the colony: everyone who can fight goes for them
	function ENT:OnAlarm(att)
		local st = self:GetState()
		if not Prey(att) or st == QUEEN or st == LATCH or st == SWALLOW or st == EMERGE then return end
		if self:GetSize() >= TINY then
			self:StartHunt(att)
		elseif att:GetPos():DistToSqr(self:GetPos()) < 300 * 300 then
			self:Lunge(att)
		end
	end

	function ENT:StartCarry(item, now)
		self.Cargo, self.CargoEnd, self.Hauling = item, now + 40, false
		self:SetMode(CARRY)
	end

	function ENT:DropCargo()
		local e = self.Cargo
		self.Cargo, self.Hauling = nil, false
		if not IsValid(e) or e.RMPG_CarriedBy ~= self then return end
		e.RMPG_CarriedBy = nil
		if e.RMPG_OldGroup then e:SetCollisionGroup(e.RMPG_OldGroup) end
		e.RMPG_OldGroup = nil
	end

	-- Pulled along just ahead of the mouth (a body by its middle, the rest of it drags behind)
	local function Pull(e, at)
		local po = e:GetPhysicsObjectNum(0)
		if not IsValid(po) then return end
		po:Wake()
		local v = (at - po:GetPos()) * 6
		if v:LengthSqr() > 360000 then v = v:GetNormalized() * 600 end
		po:SetVelocity(v)
	end

	-- A worker: to the thing, then home with it in its mouth
	function ENT:CarryThink(now, hp)
		local e, nest = self.Cargo, self.Colony
		if not IsValid(e) or not IsValid(nest) or now > self.CargoEnd or e:IsPlayerHolding() or (e.RMPG_CarriedBy and e.RMPG_CarriedBy ~= self) then
			if IsValid(e) then e.RMPG_NoFood = now + 30 end
			self:SetMode(WANDER)
			return
		end
		local size = self:GetSize()
		local rh = HeadR(size)
		local radius = e:BoundingRadius()
		if not self.Hauling then
			local d = e:WorldSpaceCenter() - hp
			if d:Length() < rh + radius * 0.6 + 30 then
				self.Hauling = true
				e.RMPG_CarriedBy = self
				e.RMPG_OldGroup = e:GetCollisionGroup()
				e:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				self:SetBiteT(now)
				self.Segs[1]:EmitSound(string.format(RMPG.SND.wormBite, math.random(1, 3)), 70, math.Clamp(125 - size * 35, 55, 130))
				return
			end
			d.z = 0
			d:Normalize()
			if self:Grounded(hp) and not self:Unstick(now, hp, self:Speed()) then self:Crawl(d, self:Speed()) end
			return
		end
		local to = nest:GetPos() - hp
		to.z = 0
		if to:Length() < nest:Reach() then
			self:DropCargo()
			nest:Store(e)
			self.Fed = self.Fed + 0.01
			self:SetMode(WANDER)
			return
		end
		to:Normalize()
		Pull(e, hp + to * (rh + radius * 0.5 + 6))
		self:SetBiteT(now)
		if self:Grounded(hp) and not self:Unstick(now, hp, self:Speed()) then self:Crawl(to, self:Speed() * 0.75) end
	end

	-- Badly hurt: away from whoever did it, home if it has one
	function ENT:FleeThink(now, hp)
		local from = self.FleeFrom
		if not IsValid(from) or now > self.FleeEnd then
			self:SetMode(WANDER)
			return
		end
		local d = IsValid(self.Colony) and self.Colony:GetPos() - hp or hp - from:GetPos()
		d.z = 0
		d:Normalize()
		if self:Grounded(hp) and not self:Unstick(now, hp, self:Speed()) then self:Crawl(d, self:Speed() * 1.4) end
	end

	-- It has not got anywhere for a while: whatever it was after cannot be reached, so on to something else
	function ENT:Watchdog(now, hp)
		if now < (self.NextCheck or 0) then return end
		self.NextCheck = now + 3
		local last = self.LastSpot
		self.LastSpot = hp
		if self.ChewEnd or not last or last:DistToSqr(hp) > 576 then return end
		local bad = self.Meal or self.Cargo
		if IsValid(bad) then bad.RMPG_NoFood = now + 30 end
		self.Meal = nil
		self.GoalEnt = nil
		self.LairSpot = nil
		self.Goal = self:RoamGoal(hp)
		self.GoalEnd = now + 8
		if self:GetState() ~= WANDER then self:SetMode(WANDER) end
		local po = self.Segs[1]:GetPhysicsObject()
		if IsValid(po) then po:SetVelocity(po:GetVelocity() + UP * (60 + 120 * self:GetSize()) + VectorRand() * 40) end
	end

	-- Given a plumbus: it is somebody's pet from now on, whatever it was doing and whatever colony it belonged to
	function ENT:Tame(ply)
		if self.Dead then return false end
		self.CoilEnd = nil
		self:Release()
		local nest = self.Colony
		if IsValid(nest) then
			if nest.Queen == self then nest.Queen = nil end
			nest:Leave(self)
		end
		self.Colony, self.Grudge, self.Meal = nil, nil, nil
		self:SetMaster(ply)
		self:SetMode(PET)
		self.NextHop, self.NextMeow = CurTime() + 0.8, CurTime() + 0.5
		self:Happy()
		return true
	end

	function ENT:Meow()
		self:SetBiteT(CurTime())
		self.Segs[1]:EmitSound(string.format(RMPG.SND.wormMeow, math.random(1, 3)), 70, math.Clamp(125 - self:GetSize() * 40, 70, 125))
	end

	-- A leap of the whole body, the head highest
	function ENT:Hop(dir)
		local up = 300 + 120 * self:GetSize()
		for i, s in ipairs(self.Segs) do
			local po = IsValid(s) and s:GetPhysicsObject()
			if IsValid(po) then
				local k = 1 - (i - 1) / #self.Segs * 0.7
				po:SetVelocity(po:GetVelocity() + (UP * up + dir * 140) * k)
			end
		end
	end

	-- A bounce, a meow and hearts
	function ENT:Happy()
		self:Meow()
		self:Hop(vector_origin)
		local ed = EffectData()
		ed:SetOrigin(self.Segs[1]:GetPos() + UP * HeadR(self:GetSize()))
		util.Effect("rmpg_worm_hearts", ed, true, true)
	end

	local function NearBy(p)
		local a, r = math.Rand(0, math.pi * 2), math.Rand(120, 420)
		return p + Vector(math.cos(a) * r, math.sin(a) * r, 0)
	end

	-- A pet: it comes along, bounces round its master, runs about the room and meows; whoever hurts the master gets bitten
	function ENT:PetThink(now, hp)
		local m = self:GetMaster()
		if not IsValid(m) then
			-- the master is gone for good: back to the wild
			self:SetMaster(NULL)
			self:SetMode(WANDER)
			return
		end
		local bad = m.RMPG_HurtBy
		if bad ~= m and Prey(bad) and now - (m.RMPG_HurtT or 0) < 3 then
			self:StartHunt(bad)
			self.HuntEnd = now + 12
			return
		end
		if now >= (self.NextMeow or 0) then
			self.NextMeow = now + math.Rand(5, 12)
			self:Meow()
		end
		local size = self:GetSize()
		local speed = self:Speed() + 90
		local ground = self:Grounded(hp)
		-- a mad dash round the room
		if now < (self.ZoomEnd or 0) then
			local d = self.ZoomGoal - hp
			d.z = 0
			if d:Length() < HeadR(size) * 2 + 30 then
				self.ZoomGoal = NearBy(m:GetPos())
			elseif ground and not self:Unstick(now, hp, speed) then
				self:Crawl(d:GetNormalized(), speed * 1.6)
			end
			return
		end
		local to = m:GetPos() - hp
		to.z = 0
		local dist = to:Length()
		to:Normalize()
		if dist > 130 + HeadR(size) * 3 then
			if ground and not self:Unstick(now, hp, speed) then self:Crawl(to, speed * (dist > 700 and 1.6 or 1)) end
		elseif ground and now >= (self.NextHop or 0) then
			-- at the master's feet: it bounces, and now and then it is off again
			self.NextHop = now + math.Rand(0.7, 2)
			if math.random() < 0.25 then
				self.ZoomGoal = NearBy(m:GetPos())
				self.ZoomEnd = now + 3
			else
				local a = math.Rand(0, math.pi * 2)
				self:Hop((to + Vector(math.cos(a), math.sin(a), 0)):GetNormalized())
			end
		end
	end

	-- Grown together: the bigger worm takes the other one in
	function ENT:Absorb(o)
		local now = CurTime()
		local pos = o:GetPos()
		self:SetSize(math.min(self:GetSize() + o:GetSize(), math.max(RMPG.CV.wormMax:GetFloat(), 0.1)))
		self.HP = self.HP + (o.HP or 0)
		self.Mate = nil
		self.NextSplit = now + 30
		self.NoMergeUntil = now + 15
		if self:GetState() == MERGE then self:SetMode(WANDER) end
		o.Dead = true
		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetColor(0)
		for _ = 1, 4 do util.Effect("BloodImpact", ed, true, true) end
		sound.Play(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), pos, 80, 80)
		o:Remove()
	end

	function ENT:MergeThink(now, hp)
		local m = self.Mate
		if not IsValid(m) or m.Dead or now > (self.MateEnd or 0) then
			self.Mate = nil
			self:SetMode(WANDER)
			return
		end
		local size = self:GetSize()
		local d = m:GetPos() - hp
		if d:Length() < HeadR(size) + HeadR(m:GetSize()) + 24 then
			if size >= m:GetSize() then self:Absorb(m) else m:Absorb(self) end
			return
		end
		if not self:Grounded(hp) then return end
		d.z = 0
		d:Normalize()
		if not self:Unstick(now, hp, self:Speed()) then self:Crawl(d, self:Speed()) end
	end

	-- Several people around: it tears itself into smaller worms, one for each (they stay apart for a while)
	function ENT:Split(now, hp)
		self.NextSplit = now + 20
		local size = self:GetSize()
		if not RMPG.CV.wormSplit:GetBool() or size < TINY * 2 then return false end
		local list = self:AllPrey(hp)
		local n = math.min(#list, math.floor(size / TINY), 4)
		if n < 2 then return false end
		local part = size / n
		for i = 2, n do
			local s = self.Segs[math.Clamp(math.floor(#self.Segs * (i - 1) / n), 2, #self.Segs)]
			local pos = IsValid(s) and s:GetPos() or hp
			local w = ents.Create("rmpg_brain_worm")
			if IsValid(w) then
				w.StartSize = part
				w.Colony = self.Colony
				w.Grudge = list[i]
				w.NoMergeUntil = now + 45
				w.NextSplit = now + 30
				w:SetPos(pos)
				w:Spawn()
				w:Activate()
			end
			local ed = EffectData()
			ed:SetOrigin(pos)
			ed:SetColor(0)
			for _ = 1, 4 do util.Effect("BloodImpact", ed, true, true) end
		end
		self.NoMergeUntil = now + 45
		self.Fed = 0
		self:SetSize(part)
		self:Build(part)
		self:ApplyMode()
		sound.Play(string.format(RMPG.SND.wormRoar, math.random(1, 3)), hp, 85, 120)
		self:StartHunt(list[1])
		return true
	end

	-- Whole: the victim is dragged into the mouth, and that is the end of them (no corpse)
	function ENT:StartSwallow(v, now)
		self.NextSwallow = now + 6
		self.SwallowAt, self.SwallowEnd = now, now + 1.3
		self:SetVictim(v)
		self:SetMode(SWALLOW)
		self:SetBiteT(now)
		local head = self.Segs[1]
		head:EmitSound(string.format(RMPG.SND.wormRoar, math.random(1, 3)), 85, math.Clamp(130 - self:GetSize() * 30, 60, 130))
		if v:IsPlayer() then RMPG.Notify(v, "n_worm_swallow", nil, 1) end
	end

	function ENT:SwallowThink(now, hp)
		local v = self:GetVictim()
		if not Prey(v) then
			self:Release()
			return
		end
		self:SetBiteT(now)
		local po = self.Segs[1]:GetPhysicsObject()
		if IsValid(po) then po:SetVelocity(po:GetVelocity() * 0.5) end
		local k = math.Clamp((now - self.SwallowAt) / (self.SwallowEnd - self.SwallowAt), 0, 1)
		v:SetPos(LerpVector(0.15 + 0.5 * k, v:GetPos(), hp - UP * 30))
		if v:IsPlayer() then v:SetVelocity(-v:GetVelocity()) end
		if now < self.SwallowEnd then return end
		v:SetNW2Float("RMPG_Vapor", now)
		local d = DamageInfo()
		d:SetDamage(v:Health() + (v:IsPlayer() and v:Armor() or 0) + 1000)
		d:SetDamageType(bit.bor(DMG_DIRECT, DMG_SLASH))
		d:SetAttacker(self)
		d:SetInflictor(self)
		d:SetDamagePosition(hp)
		v:TakeDamageInfo(d)
		if IsValid(v) then
			if v:IsPlayer() then
				if v:Alive() then v:Kill() end
			elseif v:Health() > 0 then
				v:Remove()
			end
		end
		local ed = EffectData()
		ed:SetOrigin(hp)
		ed:SetColor(0)
		for _ = 1, 5 do util.Effect("BloodImpact", ed, true, true) end
		self.Segs[1]:EmitSound(string.format(RMPG.SND.wormEat, math.random(1, 2)), 80, 70)
		self.Fed = self.Fed + 0.12
		self:Release()
	end

	-- A meal: crawl over, chew on it for a while, and it is gone (and the worm a bit bigger)
	function ENT:Eat(now, hp)
		local meal = self.Meal
		if not IsValid(meal) or now > self.MealEnd or meal:IsPlayerHolding() or meal.RMPG_Brood or meal.RMPG_CarriedBy then
			-- out of reach: not this one again for a while
			if IsValid(meal) then meal.RMPG_NoFood = now + 30 end
			self.Meal = nil
			self:SetMode(WANDER)
			return
		end
		local size = self:GetSize()
		local d = meal:WorldSpaceCenter() - hp
		if d:Length() < HeadR(size) + 30 then
			self.ChewEnd = self.ChewEnd or now + math.Clamp(5 - size * 2, 1.5, 5)
			if (self.NextChew or 0) < now then
				self.NextChew = now + 0.5
				self:SetBiteT(now)
				local head = self.Segs[1]
				head:EmitSound(string.format(RMPG.SND.wormEat, math.random(1, 2)), 65, math.Clamp(120 - size * 30, 60, 120))
				if Meaty(meal) then
					local ed = EffectData()
					ed:SetOrigin(meal:WorldSpaceCenter())
					ed:SetColor(0)
					util.Effect("BloodImpact", ed, true, true)
				end
			end
			if now >= self.ChewEnd then
				self.ChewEnd = nil
				meal.RMPG_Eaten = true
				local meat = Meaty(meal)
				local c = meal:WorldSpaceCenter()
				if meat then
					local ed = EffectData()
					ed:SetOrigin(c)
					ed:SetColor(0)
					for _ = 1, 4 do util.Effect("BloodImpact", ed, true, true) end
					sound.Play(RMPG.SND.wormDie, c, 70, 120)
				else
					sound.Play(string.format(RMPG.SND.wormSmash, math.random(1, 4)), c, 70, 130)
				end
				meal:Remove()
				self.Fed = self.Fed + (meat and 0.06 or 0.02)
				self.Meal = nil
				self.NextMeal = now + 6
				self:SetMode(WANDER)
			end
			return
		end
		self.ChewEnd = nil
		if not self:Grounded(hp) then return end
		d.z = 0
		d:Normalize()
		if not self:Unstick(now, hp, self:Speed()) then self:Crawl(d, self:Speed() * 0.8) end
	end

	-- A huge worm crushes whatever its body rolls over: people get hurt and thrown, props get smashed, knocked loose
	-- and flung, breakables break
	function ENT:Crush(now)
		if (self.NextCrush or 0) > now then return end
		self.NextCrush = now + 0.25
		local size = self:GetSize()
		local dmg = RMPG.CV.wormDamage:GetFloat() * 2.5 * size
		self.Hit = self.Hit or {}
		local mine = {}
		for _, s in ipairs(self.Segs) do mine[s] = true end
		for i, s in ipairs(self.Segs) do
			if IsValid(s) then
				local c = s:GetPos()
				local r = (s.Radius or 10) + 20
				for _, e in ipairs(ents.FindInSphere(c, r)) do
					if not mine[e] and e ~= self and (self.Hit[e] or 0) < now then
						local push = (e:WorldSpaceCenter() - c)
						push.z = math.max(push.z, 0)
						push = (push:GetNormalized() + UP * 0.5):GetNormalized()
						if Prey(e) then
							self.Hit[e] = now + 0.5
							local d = DamageInfo()
							d:SetDamage(dmg)
							d:SetDamageType(DMG_CRUSH)
							d:SetAttacker(self)
							d:SetInflictor(self)
							d:SetDamagePosition(e:WorldSpaceCenter())
							d:SetDamageForce(push * dmg * 400)
							e:TakeDamageInfo(d)
							if e:IsPlayer() then e:SetVelocity(push * (250 + 120 * size)) end
							if not Prey(e) then self.Fed = self.Fed + 0.03 end
							s:EmitSound(string.format(RMPG.SND.wormSmash, math.random(1, 4)), 80, math.random(80, 100))
						elseif PROPS[e:GetClass()] then
							self.Hit[e] = now + 0.6
							e.RMPG_Smashed = now + 6
							local po = e:GetPhysicsObject()
							if IsValid(po) then
								if not po:IsMotionEnabled() then po:EnableMotion(true) end
								po:Wake()
								po:SetVelocity(po:GetVelocity() + push * (300 + 150 * size))
							end
							local d = DamageInfo()
							d:SetDamage(dmg * 2)
							d:SetDamageType(DMG_CRUSH)
							d:SetAttacker(self)
							d:SetInflictor(self)
							d:SetDamagePosition(e:WorldSpaceCenter())
							e:TakeDamageInfo(d)
							s:EmitSound(string.format(RMPG.SND.wormSmash, math.random(1, 4)), 80, math.random(90, 110))
						end
					end
				end
			end
		end
	end

	-- Growing: slowly with time, and with what it eats; the body is rebuilt bigger every step of 15 %
	function ENT:Grow(now)
		local dt = now - (self.LastGrow or now)
		self.LastGrow = now
		local maxs = math.max(RMPG.CV.wormMax:GetFloat(), 0.1)
		local size = self:GetSize()
		local state = self:GetState()
		if state == EMERGE then
			-- out of a head: swelling to its real size over three seconds
			local k = math.Clamp((now - self.EmergeFrom) / 3, 0, 1)
			size = Lerp(k, math.min(self.EmergeTo, 0.25), self.EmergeTo)
			self:SetSize(size)
			if size >= self.BuiltSize * 1.4 or (k >= 1 and size > self.BuiltSize) then
				self:Build(size)
				self:ApplyMode()
			end
			if k >= 1 then self:SetMode(WANDER) end
			return
		end
		if self:Held() or state == QUEEN or IsValid(self:GetMaster()) then return end
		if size < maxs then
			size = math.min(size + dt * RMPG.CV.wormGrowOut:GetFloat() / 60 + self.Fed, maxs)
			self:SetSize(size)
		end
		self.Fed = 0
		if (size >= self.BuiltSize * 1.15 or (size >= maxs and size > self.BuiltSize + 0.001)) and state ~= LATCH and state ~= LUNGE then
			local head = self.Segs[1]
			if IsValid(head) then head:EmitSound(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), 70 + 10 * size, math.Clamp(100 - size * 25, 50, 100)) end
			self:Build(size)
			self:ApplyMode()
		end
	end

	function ENT:Think()
		local now = CurTime()
		if RMPG.TimeStopped then
			self:NextThink(now + 0.2)
			return true
		end
		local head = self.Segs and self.Segs[1]
		if not IsValid(head) then
			self:Remove()
			return
		end
		local hp = head:GetPos()
		self:SetPos(hp)
		self:Grow(now)
		head = self.Segs[1]
		if not IsValid(head) then return end
		hp = head:GetPos()
		local state = self:GetState()
		-- whatever a pet was off doing, it comes back to its master
		if state == WANDER and IsValid(self:GetMaster()) then
			state = PET
			self:SetMode(PET)
		end
		if self:Held() then
			-- in somebody's hands: it lets go of everything and struggles, and is dazed for a moment after
			if state ~= WANDER and state ~= EMERGE and state ~= EAT and state ~= PET then self:Release() end
			self.DazedUntil = now + 1.5
			if (self.NextWriggle or 0) < now then
				self.NextWriggle = now + 0.25
				for i = 2, #self.Segs do
					local po = IsValid(self.Segs[i]) and self.Segs[i]:GetPhysicsObject()
					if IsValid(po) then po:SetVelocity(po:GetVelocity() + VectorRand() * 12 * math.min(i, 5) * (1 + self:GetSize())) end
				end
			end
		elseif now < (self.DazedUntil or 0) then
			state = -1
		end
		if self:Held() then
			self:NextThink(now)
			return true
		end
		if state == WANDER then
			self:Wander(now, hp)
		elseif state == CLIMB then
			self:Climb(now, hp)
		elseif state == CLING then
			self:Cling(now, hp)
		elseif state == HUNT then
			self:Hunt(now, hp)
		elseif state == LUNGE then
			self:LungeThink(now, hp)
		elseif state == LATCH then
			self:Latch(now, hp)
		elseif state == EAT then
			self:Eat(now, hp)
		elseif state == MERGE then
			self:MergeThink(now, hp)
		elseif state == SWALLOW then
			self:SwallowThink(now, hp)
		elseif state == SEEK then
			self:SeekThink(now, hp)
		elseif state == QUEEN then
			self:QueenThink(now, hp)
		elseif state == CARRY then
			self:CarryThink(now, hp)
		elseif state == FLEE then
			self:FleeThink(now, hp)
		elseif state == PET then
			self:PetThink(now, hp)
		end
		if self.Dead then return end
		if state == WANDER or state == EAT or state == CARRY or state == SEEK or state == MERGE then self:Watchdog(now, hp) end
		if self:GetSize() >= HUGE and state ~= QUEEN and not IsValid(self:GetMaster()) then self:Crush(now) end
		self:NextThink(now)
		return true
	end

	function ENT:Hurt(dmg)
		if self.Dead then return end
		-- bumping into things and its own crushing do not hurt it; being hit by people does
		local att = dmg:GetAttacker()
		if dmg:IsDamageType(DMG_CRUSH) and not (IsValid(att) and (att:IsPlayer() or att:IsNPC())) then return end
		self.HP = self.HP - dmg:GetDamage()
		local head = self.Segs[1]
		local size = self:GetSize()
		if (self.NextOuch or 0) < CurTime() and IsValid(head) then
			self.NextOuch = CurTime() + 0.6
			head:EmitSound(string.format(size >= HUGE and RMPG.SND.wormRoar or RMPG.SND.wormScream, math.random(1, 3)), 70 + 10 * size, math.Clamp(170 - size * 50, 50, 170))
		end
		-- the colony comes to help
		if IsValid(self.Colony) and IsValid(att) then self.Colony:Alarm(att) end
		local st = self:GetState()
		if self.HP <= 0 then
			self:Die()
		elseif size < HUGE and self.HP < self.MaxHP * 0.35 and CurTime() > (self.NextFlee or 0) and IsValid(att) and st ~= QUEEN and st ~= LATCH and st ~= SWALLOW then
			-- badly hurt: it runs
			self.NextFlee = CurTime() + 15
			self.FleeFrom, self.FleeEnd = att, CurTime() + 5
			self:SetMode(FLEE)
		elseif Prey(att) and att ~= self:GetMaster() and size >= TINY and (st == WANDER or st == EAT or st == MERGE or st == CARRY or st == SEEK or st == PET) then
			-- whoever hurts it becomes the prey
			self:StartHunt(att)
		end
	end

	-- What is left of it: one bloody piece from a small worm, three from a big one
	function ENT:DropChunks()
		if not RMPG.CV.wormChunks:GetBool() then return end
		local size = self:GetSize()
		local n = size >= CLIMBER and 3 or 1
		local scale = math.Clamp(0.45 + size * 0.75, 0.45, 2)
		for i = 1, n do
			local s = self.Segs[math.Clamp(math.ceil(#self.Segs * i / (n + 1)), 1, #self.Segs)]
			local e = IsValid(s) and ents.Create("rmpg_worm_chunk")
			if IsValid(e) then
				e.Scale = scale
				e:SetPos(s:GetPos() + UP * 6)
				e:SetAngles(AngleRand())
				e:Spawn()
				e:Activate()
				local po = e:GetPhysicsObject()
				if IsValid(po) then
					po:SetVelocity(VectorRand() * 160 + UP * 180)
					po:AddAngleVelocity(VectorRand() * 400)
				end
			end
		end
	end

	function ENT:Die()
		self.Dead = true
		self:DropChunks()
		local n = math.Clamp(math.floor(1 + self:GetSize() * 2), 1, 5)
		for _, s in ipairs(self.Segs) do
			if IsValid(s) then
				local ed = EffectData()
				ed:SetOrigin(s:GetPos())
				ed:SetColor(0)
				for _ = 1, n do util.Effect("BloodImpact", ed, true, true) end
			end
		end
		if IsValid(self.Segs[1]) then sound.Play(RMPG.SND.wormDie, self.Segs[1]:GetPos(), 75 + 10 * self:GetSize(), math.Clamp(100 - self:GetSize() * 25, 50, 100)) end
		self:Remove()
	end

	-- Is anyone holding a piece of it (E, the gravity gun or the physgun)?
	function ENT:Held()
		for _, s in ipairs(self.Segs or {}) do
			if IsValid(s) and (s.RMPG_Physgun or s:IsPlayerHolding()) then return true end
		end
		return false
	end

	-- Torn off a head: a bit of the scalp goes with it and it ends up in the hand of whoever tore it off
	function ENT:RipOff(ply)
		local v = self:GetVictim()
		local head = self.Segs[1]
		if IsValid(v) then self:Bite(v, math.min(self:BiteDamage(), 6)) end
		self:Release()
		self.NextHunt = CurTime() + 6
		self.DazedUntil = CurTime() + 2
		if IsValid(head) then head:EmitSound(string.format(RMPG.SND.wormScream, math.random(1, 3)), 75, 160) end
		timer.Simple(0, function()
			if IsValid(head) and IsValid(ply) and ply:Alive() then ply:PickupObject(head) end
		end)
	end

	-- E on it: tears it off a head, and a small one can simply be picked up
	function ENT:Use(ply, seg)
		if self.Dead or not IsValid(ply) or not ply:IsPlayer() then return end
		-- its master strokes it
		if self:GetMaster() == ply then
			if (self.NextStroke or 0) < CurTime() then
				self.NextStroke = CurTime() + 0.8
				self:Happy()
			end
			return
		end
		if self:GetState() == LATCH then
			self:RipOff(ply)
		elseif self:GetSize() < TINY and IsValid(seg) then
			ply:PickupObject(seg)
		end
	end

	function ENT:OnRemove()
		local v = self:GetVictim()
		if IsValid(v) and v:IsPlayer() then v:SetNW2Entity("RMPG_WormOn", NULL) end
		self:DropCargo()
		if IsValid(self.Colony) then self.Colony:Leave(self) end
		for _, s in ipairs(self.Segs or {}) do
			if IsValid(s) then s:Remove() end
		end
	end

	---------------------------------------------------------------------------
	-- A worm in a head (put there with the symbiont syringe): it grows rmpg_worm_headgrow a minute, the head swells,
	-- and when it is full grown - or the host dies - it bursts out at the size it has reached
	---------------------------------------------------------------------------

	local function HeadScale(e, s)
		local b = e:LookupBone("ValveBiped.Bip01_Head1")
		if b then e:ManipulateBoneScale(b, Vector(s, s, s)) end
	end

	local hosts = {}

	-- E with a worm on your head: you tear it off yourself
	hook.Add("KeyPress", "rmpg_worm_rip", function(ply, key)
		if key ~= IN_USE then return end
		local w = ply:GetNW2Entity("RMPG_WormOn")
		if IsValid(w) then w:RipOff(ply) end
	end)

	-- The physgun does not count as holding for IsPlayerHolding on every branch, so it is tracked here
	hook.Add("OnPhysgunPickup", "rmpg_worm", function(ply, e)
		if e:GetClass() == "rmpg_worm_seg" then e.RMPG_Physgun = true end
	end)
	hook.Add("PhysgunDrop", "rmpg_worm", function(ply, e)
		if e:GetClass() == "rmpg_worm_seg" then e.RMPG_Physgun = nil end
	end)

	-- Puts a worm into a player's or an NPC's head (size: what came out of the syringe); false if there is one already
	function RMPG.WormInfect(e, size)
		if not IsValid(e) or e:GetNW2Float("RMPG_Wormed", 0) > 0 then return false end
		if e:IsPlayer() and not e:Alive() then return false end
		e:SetNW2Float("RMPG_Wormed", math.max(size or 0.05, 0.05))
		e.RMPG_WormSince = CurTime()
		hosts[e] = true
		e:EmitSound(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), 70, 120)
		if e:IsPlayer() then RMPG.Notify(e, "n_worm_in", nil, 1) end
		return true
	end

	local function Cure(e)
		hosts[e] = nil
		if not IsValid(e) or e:GetNW2Float("RMPG_Wormed", 0) == 0 then return end
		e:SetNW2Float("RMPG_Wormed", 0)
		HeadScale(e, 1)
	end

	-- A syringe at the head: a worm that is not huge yet is sucked out (returns its size); a huge one jumps out through
	-- the ear and goes after the host (returns false); nil if there is no worm in there
	function RMPG.WormExtract(e)
		local size = IsValid(e) and e:GetNW2Float("RMPG_Wormed", 0) or 0
		if size <= 0 then return nil end
		if size < HUGE then
			Cure(e)
			e:EmitSound(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), 70, 140)
			return size
		end
		local ear = HeadOf(e) + e:GetRight() * 6
		Cure(e)
		local ed = EffectData()
		ed:SetOrigin(ear)
		ed:SetColor(0)
		for _ = 1, 3 do util.Effect("BloodImpact", ed, true, true) end
		sound.Play(RMPG.SND.wormDie, ear, 80, 90)
		local w = ents.Create("rmpg_brain_worm")
		if IsValid(w) then
			w.EmergeTo = size
			w.StartDir = e:GetRight()
			w.Grudge = e
			w:SetPos(ear + e:GetRight() * 6)
			w:Spawn()
			w:Activate()
		end
		local d = DamageInfo()
		d:SetDamage(15)
		d:SetDamageType(DMG_SLASH)
		d:SetAttacker(IsValid(w) and w or game.GetWorld())
		d:SetInflictor(IsValid(w) and w or game.GetWorld())
		d:SetDamagePosition(ear)
		e:TakeDamageInfo(d)
		return false
	end

	-- Out it comes: the host dies (if still alive) and the worm swells to its size outside
	local function Burst(e)
		local size = e:GetNW2Float("RMPG_Wormed", 0)
		if size <= 0 then return end
		local pos = HeadOf(e)
		Cure(e)
		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetColor(0)
		for _ = 1, 6 do util.Effect("BloodImpact", ed, true, true) end
		sound.Play(RMPG.SND.wormDie, pos, 85, 70)
		local w = ents.Create("rmpg_brain_worm")
		if IsValid(w) then
			w.EmergeTo = size
			w.StartDir = UP
			w:SetPos(pos + UP * 4)
			w:Spawn()
			w:Activate()
		end
		local alive = e:IsPlayer() and e:Alive() or (e:IsNPC() and e:Health() > 0)
		if alive then
			local d = DamageInfo()
			d:SetDamage(e:Health() + e:GetMaxHealth() + (e:IsPlayer() and e:Armor() or 0) + 100)
			d:SetDamageType(bit.bor(DMG_DIRECT, DMG_SLASH))
			d:SetAttacker(IsValid(w) and w or game.GetWorld())
			d:SetInflictor(IsValid(w) and w or game.GetWorld())
			d:SetDamagePosition(pos)
			e:TakeDamageInfo(d)
		end
	end

	local nextCheck = 0
	hook.Add("Think", "rmpg_worm_inside", function()
		local now = CurTime()
		if now < nextCheck or RMPG.TimeStopped then return end
		local dt = now - (nextCheck - 0.5)
		nextCheck = now + 0.5
		local maxs = math.max(RMPG.CV.wormMax:GetFloat(), 0.1)
		for e in pairs(hosts) do
			local size = IsValid(e) and e:GetNW2Float("RMPG_Wormed", 0) or 0
			if size <= 0 then
				hosts[e] = nil
			else
				size = math.min(size + RMPG.CV.wormHeadGrow:GetFloat() / 60 * math.Clamp(dt, 0, 1), maxs)
				e:SetNW2Float("RMPG_Wormed", size)
				HeadScale(e, 1 + 0.6 * size / maxs)
				if math.random() < 0.05 + 0.1 * size / maxs then e:EmitSound(string.format(RMPG.SND.wormEat, math.random(1, 2)), 55 + 10 * size, math.Clamp(130 - 30 * size, 70, 130)) end
				if size >= maxs then Burst(e) end
			end
		end
	end)

	-- A bomb took the body (RMPG.WipeBody): the worm inside or on it is gone too
	function RMPG.WormWipe(e)
		Cure(e)
		for _, w in ipairs(ents.FindByClass("rmpg_brain_worm")) do
			if w:GetVictim() == e and w:GetState() == LATCH then
				w.Dead = true
				w:Remove()
			end
		end
	end

	-- the host died with it inside: out it comes now, at the size it reached - unless there is no body left to come out of
	local function Died(e, inflictor)
		if e.RMPG_Vaporized or RMPG.IsBomb(inflictor) then
			RMPG.WipeBody(e)
		else
			Burst(e)
		end
	end
	hook.Add("PlayerDeath", "rmpg_worm_inside", function(ply, inflictor) Died(ply, inflictor) end)
	hook.Add("OnNPCKilled", "rmpg_worm_inside", function(npc, attacker, inflictor) Died(npc, inflictor) end)

	-- The dead usually fall as client side ragdolls, which a worm on the server cannot see: near a worm they leave a real
	-- corpse for it to eat or drag home
	local MAX_CORPSES = 10
	local corpses = {}

	local function Corpse(e)
		if e.RMPG_Vaporized or CurTime() - e:GetNW2Float("RMPG_Vapor", -100) < 1 then return end
		local model = e:GetModel()
		if not model or not util.IsValidRagdoll(model) then return end
		local pos = e:GetPos()
		local near = false
		for _, w in ipairs(ents.FindByClass("rmpg_brain_worm")) do
			if w:GetPos():DistToSqr(pos) < 1500 * 1500 then
				near = true
				break
			end
		end
		for i = #corpses, 1, -1 do
			if not IsValid(corpses[i]) then table.remove(corpses, i) end
		end
		if not near or #corpses >= MAX_CORPSES then return end
		e:SetNW2Float("RMPG_Vapor", CurTime()) -- the usual corpse is hidden (rmpg/cl_hud.lua), this one takes its place
		local rag = ents.Create("prop_ragdoll")
		if not IsValid(rag) then return end
		rag:SetModel(model)
		rag:SetSkin(e:GetSkin())
		for _, bg in ipairs(e:GetBodyGroups() or {}) do rag:SetBodygroup(bg.id, e:GetBodygroup(bg.id)) end
		rag:SetPos(pos)
		rag:SetAngles(e:GetAngles())
		rag:Spawn()
		rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		local vel = e:GetVelocity()
		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local po = rag:GetPhysicsObjectNum(i)
			local bone = rag:TranslatePhysBoneToBone(i)
			local m = bone and e:GetBoneMatrix(bone)
			if IsValid(po) and m then
				po:SetPos(m:GetTranslation())
				po:SetAngles(m:GetAngles())
				po:SetVelocity(vel)
			end
		end
		corpses[#corpses + 1] = rag
		SafeRemoveEntityDelayed(rag, 180)
	end
	hook.Add("DoPlayerDeath", "rmpg_worm_corpse", function(ply) Corpse(ply) end)
	hook.Add("OnNPCKilled", "rmpg_worm_corpse", function(npc) Corpse(npc) end)
	hook.Add("PlayerSpawn", "rmpg_worm_inside", Cure)
	hook.Add("PlayerDisconnected", "rmpg_worm_inside", Cure)
	hook.Add("EntityRemoved", "rmpg_worm_inside", function(e) hosts[e] = nil end)

	return
end

---------------------------------------------------------------------------
-- Client: the model with its bones on the balls.
-- A bitten player sees red at the edges; a player with a worm inside sees the world swim, everything turns lovely
-- (rmpg/cl_happy.lua) and their health only shows "??" (the damage arrows are gone too) - they cannot tell if they
-- are dying.
---------------------------------------------------------------------------

-- Where the moving parts sit in the model (build_worm.py): head space at body radius 10
local JAW_BASE = { Vector(10.88, 5.44, -8.16), Vector(10.88, -5.44, -8.16) }
local PALP_BASE = { Vector(11.52, 8.8, -10.24), Vector(11.52, -8.8, -10.24) }
local LEG_Y = { 5.85, 5.64, 5.39 }
local JAW_AXIS = Vector(-0.6, 0, -0.8)

-- What it is drawn at: the size its physics balls really have (eased, so a growth step swells instead of popping)
function ENT:DrawSize()
	local want = self:GetBuilt() > 0 and self:GetBuilt() or self:GetSize()
	local t = RealTime()
	local dt = math.min(t - (self.DrawT or t), 0.1)
	self.DrawT = t
	self.Drawn = self.Drawn and math.Approach(self.Drawn, want, math.max(math.abs(want - self.Drawn), 0.02) * dt * 4) or want
	return self.Drawn
end

local function BoneTable(e)
	local t = { body = {} }
	for i = 1, SEGS do
		t.body[i] = e:LookupBone(string.format("body%02d", i - 1))
		if not t.body[i] then return end
	end
	t.jaw = { e:LookupBone("jaw_l"), e:LookupBone("jaw_r") }
	t.palp = { e:LookupBone("palp_l"), e:LookupBone("palp_r") }
	t.leg = {}
	for l = 1, 3 do t.leg[l] = { e:LookupBone("leg_l" .. l), e:LookupBone("leg_r" .. l) } end
	return t
end

-- Puts the bones on the physics balls; the mandibles, palps and legs move on top of that
local function SetBones(e)
	local segs = e:Segments()
	local n = #segs
	if n < 2 then return end
	e.Bones = e.Bones or BoneTable(e)
	local bt = e.Bones
	if not bt then return end
	local now = CurTime()
	local k = BodyR(e:DrawSize()) / 10
	local scale = Vector(k, k, k)
	local head, U
	for i = 1, SEGS do
		local p = segs[math.min(i, n)]:GetPos()
		local a, b = segs[math.max(math.min(i, n) - 1, 1)]:GetPos(), segs[math.min(i + 1, n)]:GetPos()
		local F = (a - b):GetNormalized()
		if i == 1 then
			-- the top of the head stays up as far as it can
			local side = F:Cross(UP)
			if side:LengthSqr() > 0.04 then
				U = side:Cross(F):GetNormalized()
				e.LastUp = U
			else
				U = e.LastUp or Vector(1, 0, 0)
			end
		end
		U = (U - F * U:Dot(F)):GetNormalized()
		local m = Matrix()
		m:SetTranslation(p)
		m:SetAngles(F:AngleEx(U))
		m:Scale(scale)
		e:SetBoneMatrix(bt.body[i], m)
		if i == 1 then head = m end
		if i >= 2 and i <= 4 then
			for s = 1, 2 do
				if bt.leg[i - 1][s] then
					local l = Matrix(m)
					l:Translate(Vector(0, (s == 1 and 1 or -1) * LEG_Y[i - 1], -LEG_Y[i - 1]))
					l:Rotate(Angle(math.sin(now * 9 + i * 2.1 + s * math.pi) * 22, 0, 0))
					e:SetBoneMatrix(bt.leg[i - 1][s], l)
				end
			end
		end
	end
	local bite = math.Clamp(1 - (now - e:GetBiteT()) / 0.5, 0, 1)
	local state = e:GetState()
	if state == LUNGE or state == LATCH or state == SWALLOW then bite = math.max(bite, 0.7) end
	local chew = 0.12 * (0.5 + 0.5 * math.sin(now * 5)) + 0.88 * bite
	for s = 1, 2 do
		local side = s == 1 and -1 or 1
		if bt.jaw[s] then
			local a = Angle()
			a:RotateAroundAxis(JAW_AXIS, side * math.deg(0.05 + 1.0 * chew))
			local j = Matrix(head)
			j:Translate(JAW_BASE[s])
			j:Rotate(a)
			e:SetBoneMatrix(bt.jaw[s], j)
		end
		if bt.palp[s] then
			local j = Matrix(head)
			j:Translate(PALP_BASE[s])
			j:Rotate(Angle(math.sin(now * 6 + s) * 14, 0, 0))
			e:SetBoneMatrix(bt.palp[s], j)
		end
	end
end

function ENT:Initialize()
	self:AddCallback("BuildBonePositions", SetBones)
end

-- The slime it leaves behind: a thin wet ribbon on the ground that dries up in two seconds. Every client keeps its own,
-- so nothing has to be sent for it.
local SIDES = { Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0) }
local SLIME_LIFE = 2
local ribbons = {}

local function Slime(self, segs)
	if not RMPG.CV.wormSlime:GetBool() then return end
	local p = segs[#segs]:GetPos()
	local size = self:GetBuilt()
	local step = math.max(8, BodyR(size) * 0.8)
	local from = self.SlimeAt
	if from and from:DistToSqr(p) < step * step then return end
	self.SlimeAt = p
	local reach = BodyR(size) * 1.6 + 12
	local tr = util.TraceLine({ start = p, endpos = p - UP * reach, mask = MASK_SOLID_BRUSHONLY })
	if not tr.Hit and self:GetState() == CLIMB then
		for _, d in ipairs(SIDES) do
			tr = util.TraceLine({ start = p, endpos = p + d * reach, mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit then break end
		end
	end
	if not tr.Hit or tr.HitSky then
		self.SlimeRibbon = nil
		return
	end
	local side = (from and p - from or self:GetForward()):Cross(tr.HitNormal)
	if side:LengthSqr() < 0.01 then side = tr.HitNormal:Cross(Vector(1, 0, 0)) end
	side:Normalize()
	side:Mul(math.max(2.5, BodyR(size) * 0.55))
	local at = tr.HitPos + tr.HitNormal * 0.6
	-- a jump breaks the ribbon
	local rib = self.SlimeRibbon
	if not rib or not from or from:DistToSqr(p) > (step * 3) ^ 2 then
		rib = {}
		self.SlimeRibbon = rib
	end
	ribbons[rib] = true
	rib[#rib + 1] = { a = at + side, b = at - side, t = CurTime() }
end

local function RibbonVertex(pos, alpha)
	mesh.Position(pos)
	mesh.Color(176, 226, 136, alpha)
	mesh.TexCoord(0, 0.5, 0.5)
	mesh.AdvanceVertex()
end

hook.Add("PostDrawTranslucentRenderables", "rmpg_worm_slime", function(depth, sky)
	if depth or sky or next(ribbons) == nil then return end
	local now = CurTime()
	render.SetMaterial(RMPG.Mat.glass)
	for rib in pairs(ribbons) do
		while rib[1] and now - rib[1].t > SLIME_LIFE do table.remove(rib, 1) end
		local n = #rib
		if n == 0 then
			ribbons[rib] = nil
		elseif n >= 2 then
			mesh.Begin(MATERIAL_QUADS, n - 1)
			for i = 1, n - 1 do
				local p, q = rib[i], rib[i + 1]
				local ap, aq = 150 * (1 - (now - p.t) / SLIME_LIFE), 150 * (1 - (now - q.t) / SLIME_LIFE)
				RibbonVertex(p.a, ap)
				RibbonVertex(p.b, ap)
				RibbonVertex(q.b, aq)
				RibbonVertex(q.a, aq)
			end
			mesh.End()
		end
	end
end)

function ENT:Think()
	local segs = self:Segments()
	if #segs < 2 then return end
	Slime(self, segs)
	local mins, maxs = segs[1]:GetPos(), segs[1]:GetPos()
	for _, s in ipairs(segs) do
		local p = s:GetPos()
		mins = Vector(math.min(mins.x, p.x), math.min(mins.y, p.y), math.min(mins.z, p.z))
		maxs = Vector(math.max(maxs.x, p.x), math.max(maxs.y, p.y), math.max(maxs.z, p.z))
	end
	local r = HeadR(self.Drawn or self:GetSize()) * 2 + 16
	local pad = Vector(r, r, r)
	self:SetRenderBoundsWS(mins - pad, maxs + pad)
end

function ENT:Draw(flags)
	if #self:Segments() < 2 then return end
	self:InvalidateBoneCache()
	self:DrawModel(flags)
end

---------------------------------------------------------------------------
-- The host's screen
---------------------------------------------------------------------------

local function WormIn(ply)
	return IsValid(ply) and ply:GetNW2Float("RMPG_Wormed", 0) or 0
end

local function WormK(ply)
	return math.Clamp(WormIn(ply) / math.max(RMPG.CV.wormMax:GetFloat(), 0.1), 0, 1)
end

-- Bitten: red at the edges and a shaking view; a worm inside: the world swims as it grows, and looks wonderful
-- (rmpg/cl_happy.lua)
hook.Add("HUDPaint", "rmpg_worm", function()
	local me = LocalPlayer()
	if not IsValid(me:GetNW2Entity("RMPG_WormOn")) then return end
	-- how long until it is inside
	local at = me:GetNW2Float("RMPG_WormEnterAt", 0)
	if at > 0 then
		local left = math.max(at - CurTime(), 0)
		local k = left / math.max(RMPG.CV.wormEnter:GetFloat(), 0.1)
		local w, cx, cy = 340, ScrW() / 2, ScrH() * 0.3
		local on = math.sin(CurTime() * 14) > 0
		draw.SimpleTextOutlined(RMPG.T("worm_entering"), "RMPG_Head", cx, cy, on and Color(255, 70, 70) or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined(RMPG.T("worm_tear_off"), "RMPG_BodyB", cx, cy + 26, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(cx - w / 2, cy + 44, w, 12)
		surface.SetDrawColor(255, 60, 60)
		surface.DrawRect(cx - w / 2 + 2, cy + 46, (w - 4) * k, 8)
	end
	local a = 70 + 40 * math.sin(CurTime() * 8)
	surface.SetMaterial(RMPG.Mat.glow2D)
	surface.SetDrawColor(200, 0, 0, a)
	local sw, sh = ScrW(), ScrH()
	for i = 0, 11 do
		local ang = i / 12 * math.pi * 2
		local s = sh * 0.9
		surface.DrawTexturedRect(sw / 2 + math.cos(ang) * sw * 0.62 - s / 2, sh / 2 + math.sin(ang) * sh * 0.62 - s / 2, s, s)
	end
end)

hook.Add("CalcView", "rmpg_worm", function(ply, pos, ang, fov)
	local inside = WormIn(ply) > 0
	if not inside and not IsValid(ply:GetNW2Entity("RMPG_WormOn")) then return end
	if RMPG.BootsOn(ply) then return end
	local k = inside and 0.1 + 0.5 * WormK(ply) or 0.6
	local now = CurTime()
	ang = Angle(ang.p + math.sin(now * 1.7) * 2.5 * k, ang.y + math.sin(now * 1.1) * 2 * k, ang.r + math.sin(now * 1.3) * 4 * k)
	return { origin = pos, angles = ang, fov = fov }
end)

-- With a worm inside: no health number and no damage arrows - an HL2-style health box showing "??" instead
local function HudFonts()
	local s = ScrH() / 480
	surface.CreateFont("RMPG_HudQ", { font = "Trebuchet MS", size = math.floor(30 * s), weight = 500, antialias = true, additive = true })
	surface.CreateFont("RMPG_HudQGlow", { font = "Trebuchet MS", size = math.floor(30 * s), weight = 500, antialias = true, additive = true, blursize = math.floor(4 * s), scanlines = 2 })
	surface.CreateFont("RMPG_HudQLabel", { font = "Verdana", size = math.floor(9 * s), weight = 900, antialias = true, additive = true })
end
HudFonts()
hook.Add("OnScreenSizeChanged", "rmpg_worm_hud", HudFonts)

local HIDE = { CHudHealth = true, CHudDamageIndicator = true, CHudPoisonDamageIndicator = true }
hook.Add("HUDShouldDraw", "rmpg_worm_hud", function(name)
	if HIDE[name] and WormIn(LocalPlayer()) > 0 then return false end
end)

local HUD_FG = Color(255, 235, 20, 255)
hook.Add("HUDPaint", "rmpg_worm_hud", function()
	local me = LocalPlayer()
	if WormIn(me) <= 0 or not me:Alive() or not GetConVar("cl_drawhud"):GetBool() then return end
	local s = ScrH() / 480
	local x, y, w, h = 16 * s, ScrH() - 48 * s, 102 * s, 36 * s
	draw.RoundedBox(math.floor(8 * s), x, y, w, h, Color(0, 0, 0, 76))
	local label = language.GetPhrase("Valve_Hud_HEALTH")
	if label == "Valve_Hud_HEALTH" then label = "HEALTH" end
	draw.SimpleText(label, "RMPG_HudQLabel", x + 8 * s, y + 20 * s, HUD_FG)
	draw.SimpleText("??", "RMPG_HudQGlow", x + 50 * s, y + 2 * s, HUD_FG)
	draw.SimpleText("??", "RMPG_HudQ", x + 50 * s, y + 2 * s, HUD_FG)
end)
