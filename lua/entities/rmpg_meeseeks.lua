AddCSLuaFile()

-- Mr. Meeseeks: pops out of the box in a puff of cloud, does one job and vanishes. Existence is pain!
-- Jobs run in the NextBot coroutine (JOBS below); the summoning, the job menu and the helpers live in sv_meeseeks.lua.
ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "#rmpg.meeseeks"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

local UP = Vector(0, 0, 1)
local LINE_TIME = 3.5

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Master")
	self:NetworkVar("Entity", 1, "Found")    -- what he found and is pointing at
	self:NetworkVar("Int", 0, "Task")
	self:NetworkVar("String", 0, "TaskInfo") -- shown in the HUD next to the job
	self:NetworkVar("String", 1, "Line")     -- speech bubble: language key
	self:NetworkVar("String", 2, "LineArg")
	self:NetworkVar("Float", 0, "LineTime")
	self:NetworkVar("Bool", 0, "Frenzy")
	self:NetworkVar("Vector", 0, "GuardPos")
end

if SERVER then
	local JOBS = {}

	function ENT:Initialize()
		-- the Mr. Meeseeks player model shipped with the addon; if it is missing, the GMod corpse player model
		-- painted blue with a drawn-on face (both have the player skeleton and player animations)
		self:SetModel(util.IsValidModel(RMPG.MR_MODEL) and RMPG.MR_MODEL or RMPG.MR_FALLBACK)
		local hp = RMPG.CV.mrHealth:GetInt()
		self:SetHealth(hp)
		self:SetMaxHealth(hp)
		self:SetCollisionBounds(Vector(-10, -10, 0), Vector(10, 10, 80))
		self:SetUseType(SIMPLE_USE)
		self.loco:SetDesiredSpeed(RMPG.CV.mrSpeed:GetFloat())
		self.loco:SetAcceleration(1200)
		self.loco:SetDeceleration(1600)
		self.loco:SetStepHeight(20)
		self.loco:SetJumpHeight(60)
		self.Serial = 0
		self.Born = CurTime()
	end

	function ENT:Say(key, arg)
		self:SetLine(key)
		self:SetLineArg(arg or "")
		self:SetLineTime(CurTime())
	end

	function ENT:SetJob(job)
		self.Job = job
		self.Serial = self.Serial + 1
		job.start = CurTime()
		self:SetTask(job.id)
		self:SetTaskInfo(job.label or "")
		self:SetFound(NULL)
		self:SetGuardPos(vector_origin)
		self.Fists, self.Crouch = false, false
		self.PortalTrail = nil
		self:Drop()
		if not job.frenzy then self:Say("mr_ok") end
	end

	function ENT:Changed(serial)
		return self.Serial ~= serial
	end

	function ENT:Wait(t, serial)
		local untilT = CurTime() + t
		while CurTime() < untilT do
			if serial and self:Changed(serial) then return false end
			coroutine.yield()
		end
		return true
	end

	---------------------------------------------------------------------------
	-- Moving, animating, punching
	---------------------------------------------------------------------------

	function ENT:UseNav()
		if self.NavKnown == nil then self.NavKnown = navmesh.IsLoaded() and navmesh.GetNavAreaCount() > 0 end
		return self.NavKnown
	end

	-- The one he follows went through portals (RMPG.MrFollowPortal): the spot in front of the next one on their
	-- trail, oldest first. Close enough, he jumps in; nil once the trail is done (or a portal closed, or 20 s passed)
	function ENT:PortalGoal()
		local trail = self.PortalTrail
		while trail and trail[1] do
			local s = trail[1]
			local p = s.from
			if self.RMPG_LastPortal == p and (self.RMPG_LastPortalT or 0) >= s.since then
				-- already went through it (the portal itself caught him)
				table.remove(trail, 1)
			elseif not IsValid(p) or p:GetCloseTime() > 0 or not IsValid(p:GetPartner()) or CurTime() > s.since + 20 then
				table.remove(trail, 1)
			else
				local c, f = p:GetPos(), p:GetAngles():Forward()
				-- nearest point of his body (feet to head) to the portal centre, in front of the portal
				local feet = self:GetPos()
				local body = Vector(feet.x, feet.y, math.Clamp(c.z, feet.z, feet.z + 80))
				if body:DistToSqr(c) < (p:GetRadius() + 16) ^ 2 and (body - c):Dot(f) > -8 then
					-- right after another portal he waits a moment; then in he goes (or forgets this one if it won't take him)
					if (self.RMPG_NextTP or 0) > CurTime() then return end
					table.remove(trail, 1)
					if RMPG.CanTeleport(self) then
						RMPG.Teleport(self, p, p:GetPartner())
						self.PathT = 0
					end
					return
				end
				s.goal = s.goal or RMPG.GroundBelow(c + f * 12, 400) or c
				return s.goal
			end
		end
		self.PortalTrail = nil
	end

	-- One tick toward a point: along the navmesh when the map has one, straight otherwise
	-- (into the portal first when the one he follows went through it)
	function ENT:StepToward(gpos)
		gpos = self:PortalGoal() or gpos
		if self:UseNav() then
			self.Path = self.Path or Path("Follow")
			if (self.PathT or 0) < CurTime() or not self.PathGoal or self.PathGoal:DistToSqr(gpos) > 4096 then
				self.Path:SetMinLookAheadDistance(150)
				self.Path:SetGoalTolerance(16)
				self.Path:Compute(self, gpos)
				self.PathT = CurTime() + 0.6
				self.PathGoal = gpos
			end
			if self.Path:IsValid() then
				self.Path:Update(self)
				return
			end
		end
		self.loco:FaceTowards(gpos)
		self.loco:Approach(gpos, 1)
	end

	-- Walks until within dist of a point or an entity: "ok", "lost", "timeout" or "changed"
	function ENT:GoTo(goal, dist, maxTime, serial)
		local deadline = CurTime() + (maxTime or 30)
		while CurTime() < deadline do
			if serial and self:Changed(serial) then return "changed" end
			local gpos = isvector(goal) and goal or (IsValid(goal) and goal:GetPos())
			if not gpos then return "lost" end
			local d = gpos - self:GetPos()
			if d:Length2D() <= dist and math.abs(d.z) < 72 then return "ok" end
			self:StepToward(gpos)
			coroutine.yield()
		end
		return "timeout"
	end

	function ENT:OnStuck()
		self.loco:Jump()
		self.loco:ClearStuck()
	end

	-- The usual player animations, by activity; the sequence names are a fallback for models that lack the activity
	local FALLBACK = {
		[ACT_HL2MP_IDLE] = "idle_all_01", [ACT_HL2MP_WALK] = "walk_all", [ACT_HL2MP_RUN] = "run_all_01",
		[ACT_HL2MP_IDLE_FIST] = "idle_fist", [ACT_HL2MP_WALK_FIST] = "walk_fist", [ACT_HL2MP_RUN_FIST] = "run_fist",
		[ACT_HL2MP_IDLE_CROUCH] = "cidle_all",
	}

	function ENT:SetAnim(act)
		if self.CurAct == act then return end
		self.CurAct = act
		if self:SelectWeightedSequence(act) > 0 then
			self:StartActivity(act)
		else
			local seq = self:LookupSequence(FALLBACK[act] or "idle_all_01")
			if seq and seq > 0 then
				self:ResetSequence(seq)
				self:SetPlaybackRate(1)
			end
		end
	end

	-- A full-body sequence (the "look at me!" cheer): plays once, and never longer than maxTime, so a missing
	-- or odd sequence can't leave him frozen in its first frame
	function ENT:PlaySeq(name, maxTime)
		local seq = self:LookupSequence(name)
		if not seq or seq < 0 then return end
		self:ResetSequence(seq)
		self:SetCycle(0)
		self:SetPlaybackRate(1)
		local dur = math.Clamp(self:SequenceDuration(seq) or 0, 0.1, maxTime or 3)
		self.CurAct = nil
		self.SeqUntil = CurTime() + dur
		coroutine.wait(dur)
	end

	function ENT:BodyUpdate()
		if self.SeqUntil then
			if CurTime() < self.SeqUntil then
				self:FrameAdvance()
				return
			end
			self.SeqUntil = nil
		end
		local speed = self.loco:GetVelocity():Length2D()
		local act
		if speed > 150 then
			act = self.Fists and ACT_HL2MP_RUN_FIST or ACT_HL2MP_RUN
		elseif speed > 15 then
			act = self.Fists and ACT_HL2MP_WALK_FIST or ACT_HL2MP_WALK
		elseif self.Crouch then
			act = ACT_HL2MP_IDLE_CROUCH
		else
			act = self.Fists and ACT_HL2MP_IDLE_FIST or ACT_HL2MP_IDLE
		end
		self:SetAnim(act)
		if speed > 15 then self:BodyMoveXY() else self:FrameAdvance() end
	end

	function ENT:Gesture(act)
		local seq = self:SelectWeightedSequence(act)
		if seq and seq > 0 then self:AddGestureSequence(seq, true) end
	end

	function ENT:Punch(target)
		if (self.NextPunch or 0) > CurTime() then return end
		self.NextPunch = CurTime() + 0.75
		self.loco:FaceTowards(target:GetPos())
		self:Gesture(ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST)
		self:EmitSound(string.format(RMPG.SND.mrSwing, math.random(1, 2)), 70)
		timer.Simple(0.2, function()
			if not IsValid(self) or not IsValid(target) then return end
			if (target:GetPos() - self:GetPos()):Length2D() > 95 then return end
			local d = DamageInfo()
			d:SetDamage(RMPG.CV.mrDamage:GetFloat())
			d:SetDamageType(DMG_CLUB)
			d:SetAttacker(self)
			d:SetInflictor(self)
			d:SetDamagePosition(target:WorldSpaceCenter())
			d:SetDamageForce((target:GetPos() - self:GetPos()):GetNormalized() * 5000)
			target:TakeDamageInfo(d)
			target:EmitSound(string.format(RMPG.SND.mrPunch, math.random(1, 6)), 70)
		end)
	end

	-- One tick of a fight; false once the target is gone
	function ENT:FightStep(target)
		if not RMPG.MrAlive(target) then return false end
		if (target:GetPos() - self:GetPos()):Length2D() > 60 then
			self:StepToward(target:GetPos())
		else
			self.loco:FaceTowards(target:GetPos())
			self:Punch(target)
		end
		return true
	end

	---------------------------------------------------------------------------
	-- Carrying things over his head
	---------------------------------------------------------------------------

	function ENT:Carry(e)
		self.Carrying = e
		e.RMPG_CarriedBy = self
		e.RMPG_OldGroup = e:GetCollisionGroup()
		e:SetCollisionGroup(COLLISION_GROUP_WORLD)
		local po = e:GetPhysicsObject()
		if IsValid(po) then po:EnableMotion(false) end
		self:EmitSound(RMPG.SND.pickup, 65)
	end

	-- Puts the carried thing down (in front of a player when given)
	function ENT:Drop(toward)
		local e = self.Carrying
		self.Carrying = nil
		if not IsValid(e) then return end
		e.RMPG_CarriedBy = nil
		local r = math.min(e:BoundingRadius(), 120)
		local pos = self:GetPos() + self:GetForward() * (30 + r) + UP * (20 + r)
		if IsValid(toward) then
			local dir = self:GetPos() - toward:GetPos()
			dir.z = 0
			dir:Normalize()
			pos = toward:GetPos() + dir * (45 + r) + UP * (20 + r)
		end
		e:SetPos(pos)
		e:SetCollisionGroup(e.RMPG_OldGroup or COLLISION_GROUP_NONE)
		local po = e:GetPhysicsObject()
		if IsValid(po) then
			po:EnableMotion(true)
			po:Wake()
		end
	end

	function ENT:Think()
		local e = self.Carrying
		if IsValid(e) then
			e:SetPos(self:GetPos() + UP * (90 + math.min(e:BoundingRadius(), 120) * 0.7))
			e:SetAngles(Angle(0, self:GetAngles().y, 0))
		elseif e then
			self.Carrying = nil
		end
		self:NextThink(CurTime())
		return true
	end

	---------------------------------------------------------------------------
	-- Stress: a job that drags on brings a helper Meeseeks and, much later, madness
	---------------------------------------------------------------------------

	function ENT:Stress(job)
		if job.frenzy then return end
		local t = CurTime() - job.start
		if t > 45 and not job.helped then
			job.helped = true
			local copy = table.Copy(job)
			copy.helped = true
			if RMPG.SummonMeeseeks(self:GetMaster(), self:GetPos() + self:GetRight() * 60, copy) then self:Say("mr_help") end
		end
		if RMPG.CV.mrFrenzy:GetBool() and t > RMPG.CV.mrFrenzyTime:GetFloat() and IsValid(self:GetMaster()) then
			self:SetFrenzy(true)
			self:Say("mr_pain")
			self.loco:SetDesiredSpeed(RMPG.CV.mrSpeed:GetFloat() * 1.4)
			self:SetJob({ id = RMPG.MR_KILL, ent = self:GetMaster(), frenzy = true, label = self:GetMaster():Nick() })
		end
	end

	---------------------------------------------------------------------------
	-- Jobs: each returns "done", "impossible" or nothing when the job was changed
	---------------------------------------------------------------------------

	JOBS[RMPG.MR_KILL] = function(self, job, serial)
		local t = job.ent
		if not RMPG.MrAlive(t) then return "done" end
		if t:IsNPC() then t:AddEntityRelationship(self, D_HT, 99) end
		self.Fists = true
		while not self:Changed(serial) do
			if not self:FightStep(t) then
				self.Fists = false
				return "done"
			end
			self:Stress(job)
			coroutine.yield()
		end
	end

	-- Finds the nearest matching thing, walks to it and carries it back to the master
	local function Fetch(self, job, serial, find)
		local target = find(self)
		if not target then return "impossible" end
		self:Say("mr_searching")
		while true do
			if self:Changed(serial) then return end
			if not IsValid(target) or target.RMPG_CarriedBy then
				target = find(self)
				if not target then return "impossible" end
			end
			local r = self:GoTo(target, 45 + math.min(target:BoundingRadius(), 150) * 0.5, 4, serial)
			if r == "changed" then return end
			if r == "ok" then break end
			self:Stress(job)
		end
		self:Carry(target)
		self:Say("mr_got_it")
		local m = self:GetMaster()
		while IsValid(m) do
			local r = self:GoTo(m, 110, 4, serial)
			if r == "changed" then
				self:Drop()
				return
			end
			if r == "ok" then break end
			self:Stress(job)
		end
		self:Drop(m)
		return "done"
	end

	JOBS[RMPG.MR_FINDPROP] = function(self, job, serial)
		return Fetch(self, job, serial, function(me) return RMPG.MrNearestProp(me, job.model) end)
	end

	JOBS[RMPG.MR_MAKE] = function(self, job, serial)
		local m = self:GetMaster()
		if IsValid(m) and self:GoTo(m, 130, 15, serial) == "changed" then return end
		self:Say("mr_working")
		self.Crouch = true
		local untilT = CurTime() + RMPG.CV.mrCraft:GetFloat() * ({ [0] = 1, 1.5, 1.5, 2.5 })[job.kind]
		while CurTime() < untilT do
			if self:Changed(serial) then
				self.Crouch = false
				return
			end
			if (self.NextHit or 0) < CurTime() then
				self.NextHit = CurTime() + 0.45
				self:Gesture(ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE)
				self:EmitSound(string.format(RMPG.SND.mrCraft, math.random(1, 2)), 65, math.random(95, 115))
				local ed = EffectData()
				ed:SetOrigin(self:GetPos() + self:GetForward() * 26 + UP * 8)
				ed:SetNormal(UP)
				util.Effect("ManhackSparks", ed, true, true)
			end
			coroutine.yield()
		end
		self.Crouch = false
		if not RMPG.MrMake(self, job) then return "impossible" end
		return "done"
	end

	JOBS[RMPG.MR_FINDENT] = function(self, job, serial)
		local find = function(me) return RMPG.MrNearestOfClass(me, job.class) end
		local target = find(self)
		if not target then return "impossible" end
		-- small loose things are simply brought back
		if RMPG.MrCarryable(target) then return Fetch(self, job, serial, find) end
		self:Say("mr_searching")
		while true do
			if self:Changed(serial) then return end
			if not IsValid(target) then
				target = find(self)
				if not target then return "impossible" end
			end
			local r = self:GoTo(target, 70 + math.min(target:BoundingRadius(), 200) * 0.5, 4, serial)
			if r == "changed" then return end
			if r == "ok" then break end
			self:Stress(job)
		end
		-- point it out until the master comes over
		self:SetFound(target)
		self:Say("mr_found")
		local m = self:GetMaster()
		local untilT = CurTime() + 90
		while CurTime() < untilT and not self:Changed(serial) do
			if not IsValid(m) or not IsValid(target) then break end
			self.loco:FaceTowards(m:GetPos())
			if m:GetPos():Distance(self:GetPos()) < 220 then break end
			if (self.NextWave or 0) < CurTime() then
				self.NextWave = CurTime() + 4
				self:Gesture(ACT_GMOD_GESTURE_WAVE)
				self:Say("mr_over_here")
			end
			coroutine.yield()
		end
		self:SetFound(NULL)
		if self:Changed(serial) then return end
		return "done"
	end

	JOBS[RMPG.MR_PROTECT] = function(self, job, serial)
		local who = job.ent
		local slot = (self:EntIndex() % 6) / 6 * math.pi * 2
		local untilT = CurTime() + RMPG.CV.mrLife:GetFloat()
		while CurTime() < untilT and not self:Changed(serial) do
			if not RMPG.MrAlive(who) then
				self:Say("mr_sorry")
				return "done"
			end
			local threat = RMPG.MrThreat(self, who, who:GetPos(), 700)
			if threat then
				self.Fists = true
				self:FightStep(threat)
			else
				self.Fists = false
				local spot = who:GetPos() + Vector(math.cos(slot), math.sin(slot), 0) * 80
				if (spot - self:GetPos()):Length2D() > 60 then self:StepToward(spot) else self.loco:FaceTowards(who:GetPos() + who:GetForward() * 300) end
			end
			coroutine.yield()
		end
		if self:Changed(serial) then return end
		return "done"
	end

	JOBS[RMPG.MR_GUARD] = function(self, job, serial)
		local pos = job.pos
		local R = 380
		self:SetGuardPos(pos)
		local untilT = CurTime() + RMPG.CV.mrLife:GetFloat()
		while CurTime() < untilT and not self:Changed(serial) do
			local threat = RMPG.MrThreat(self, self:GetMaster(), pos, R, true)
			if threat then
				self.Fists = true
				self:FightStep(threat)
			else
				self.Fists = false
				if (pos - self:GetPos()):Length2D() > 40 then
					self:StepToward(pos)
				elseif (self.NextLook or 0) < CurTime() then
					self.NextLook = CurTime() + math.Rand(2, 4)
					self.loco:FaceTowards(pos + VectorRand() * 300)
				end
			end
			coroutine.yield()
		end
		if self:Changed(serial) then return end
		self:SetGuardPos(vector_origin)
		return "done"
	end

	JOBS[RMPG.MR_HEAL] = function(self, job, serial)
		local m = self:GetMaster()
		if not IsValid(m) then return "impossible" end
		if m:Health() >= m:GetMaxHealth() then
			self:Say("mr_healthy")
			self:Wait(1.5, serial)
			return "done"
		end
		local untilT = CurTime() + 30
		while IsValid(m) and m:Alive() and CurTime() < untilT and not self:Changed(serial) do
			if (m:GetPos() - self:GetPos()):Length2D() > 70 then
				self:StepToward(m:GetPos())
			else
				self.loco:FaceTowards(m:GetPos())
				if m:Health() >= m:GetMaxHealth() then return "done" end
				if (self.NextHeal or 0) < CurTime() then
					self.NextHeal = CurTime() + 0.5
					m:SetHealth(math.min(m:GetMaxHealth(), m:Health() + 5))
					self:Gesture(ACT_GMOD_GESTURE_ITEM_GIVE)
					if math.random(3) == 1 then self:EmitSound(RMPG.SND.mrHeal, 60) end
				end
			end
			coroutine.yield()
		end
		if self:Changed(serial) then return end
		return "done"
	end

	JOBS[RMPG.MR_DISTRACT] = function(self, job, serial)
		local m = self:GetMaster()
		if not IsValid(m) or not RMPG.MrNearestEnemy(m, m:GetPos(), 2500) then return "impossible" end
		self:Say("mr_hey")
		local untilT = CurTime() + math.min(RMPG.CV.mrLife:GetFloat(), 60)
		while CurTime() < untilT and not self:Changed(serial) do
			local e = RMPG.MrNearestEnemy(m, self:GetPos(), 2500)
			if not e then return "done" end
			if (self.NextTaunt or 0) < CurTime() then
				-- every enemy around now wants him, not you
				self.NextTaunt = CurTime() + 1
				for _, npc in ipairs(ents.FindInSphere(self:GetPos(), 2500)) do
					if npc:IsNPC() and npc:Health() > 0 and npc:Disposition(m) == D_HT then
						npc:AddEntityRelationship(self, D_HT, 99)
						if npc:GetEnemy() ~= self then
							npc:SetEnemy(self)
							npc:UpdateEnemyMemory(self, self:GetPos())
						end
					end
				end
			end
			if (self.NextShout or 0) < CurTime() then
				self.NextShout = CurTime() + 5
				self:Say("mr_lookatme")
				self:EmitSound(RMPG.SND.mrHello, 80, math.random(95, 110))
			end
			-- run circles around the nearest enemy
			local a = CurTime() * 0.7 + self:EntIndex()
			self:StepToward(e:GetPos() + Vector(math.cos(a), math.sin(a), 0) * 320)
			coroutine.yield()
		end
		if self:Changed(serial) then return end
		return "done"
	end

	---------------------------------------------------------------------------
	-- Life
	---------------------------------------------------------------------------

	function ENT:Intro()
		self:SetModelScale(0.3)
		self:SetModelScale(1, 0.25)
		self:EmitSound(RMPG.SND.mrHello, 80)
		self:Say("mr_hello")
		local m = self:GetMaster()
		if IsValid(m) then self:SetAngles(Angle(0, (m:GetPos() - self:GetPos()):Angle().y, 0)) end
		self:PlaySeq("taunt_cheer", 2.8)
		if not self.Job then self:Say("mr_ask") end
	end

	-- Waiting for a job: face the master, remind him now and then, give up after a while
	function ENT:IdleStep()
		local m = self:GetMaster()
		if IsValid(m) then
			self.loco:FaceTowards(m:GetPos())
			if (self.NextAsk or 0) < CurTime() then
				self.NextAsk = CurTime() + 15
				if self.Asked then self:Say("mr_ask") end
				self.Asked = true
			end
		end
		if CurTime() - self.Born > RMPG.CV.mrLife:GetFloat() then
			self:Say("mr_bored")
			self:Wait(1.5)
			self:Poof()
		end
	end

	function ENT:Finish()
		self.Fists, self.Crouch = false, false
		self:SetTask(0)
		self:Say(self:GetFrenzy() and "mr_finally" or "mr_done")
		self:Gesture(ACT_GMOD_GESTURE_WAVE)
		self:Wait(1.3)
		self:Poof()
	end

	function ENT:RunBehaviour()
		self:Intro()
		while IsValid(self) and not self.Poofed do
			local job = self.Job
			if job then
				local serial = self.Serial
				local res = JOBS[job.id](self, job, serial)
				if not self:Changed(serial) then
					if res == "done" then
						self:Finish()
						return
					elseif res == "impossible" then
						-- nothing like that here: wait for another job instead of going mad
						self.Job = nil
						self:SetTask(0)
						self:SetTaskInfo("")
						self.Fists, self.Crouch = false, false
						self:Say("mr_impossible")
					end
				end
			else
				self:IdleStep()
			end
			coroutine.yield()
		end
	end

	-- Gone in a puff of cloud
	function ENT:Poof()
		if self.Poofed then return end
		self.Poofed = true
		local ed = EffectData()
		ed:SetOrigin(self:GetPos() + UP * 40)
		ed:SetScale(1)
		util.Effect("rmpg_meeseeks_poof", ed, true, true)
		sound.Play(RMPG.SND.mrPoof, self:GetPos() + UP * 40, 75, math.random(95, 110))
		self:Drop()
		self:Remove()
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() or self:GetFrenzy() then return end
		local m = self:GetMaster()
		if ply ~= m then
			self:Say("mr_not_yours", IsValid(m) and m:Nick() or "?")
			return
		end
		RMPG.OpenMeeseeksMenu(ply, self)
	end

	function ENT:OnInjured(dmg)
		self.HurtBy, self.HurtT = dmg:GetAttacker(), CurTime()
		if (self.NextOuch or 0) < CurTime() then
			self.NextOuch = CurTime() + 2
			self:Say("mr_ouch")
		end
	end

	function ENT:OnKilled(dmg)
		hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
		self:Poof()
	end

	function ENT:OnRemove()
		self:Drop()
	end

	return
end

---------------------------------------------------------------------------
-- Client: the Meeseeks himself (his own model as it is; the fallback corpse model painted blue with a drawn face),
-- speech bubbles and the "E - give a job" prompt
---------------------------------------------------------------------------

surface.CreateFont("RMPG_Bubble", { font = "Comic Sans MS", size = 34, weight = 800, extended = true, antialias = true })
surface.CreateFont("RMPG_BubbleS", { font = "Tahoma", size = 22, weight = 800, extended = true, antialias = true })

local SKIN = Vector(0.38, 0.78, 0.94)
local WHITE = Material("models/debug/debugwhite")

function ENT:Initialize()
	self:SetRenderBounds(Vector(-40, -40, 0), Vector(40, 40, 100))
end

function ENT:Draw()
	if self:GetModel() ~= RMPG.MR_FALLBACK then
		-- the real Meeseeks model has his face and colour in its texture
		self:DrawModel()
		return
	end
	render.MaterialOverride(WHITE)
	render.SetColorModulation(SKIN.x, SKIN.y, SKIN.z)
	self:DrawModel()
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
	if not RMPG.Model or EyePos():DistToSqr(self:GetPos()) > 3000 * 3000 then return end
	-- eyes, mouth and the tuft follow the head bone's position, but face where he faces and stay upright: the head
	-- bone's own axes don't match the face once the player animations play (measured on models/player/corpse1.mdl,
	-- the face is ~3 units in front of the bone, the eyes ~4.3 above it)
	local hb = self:LookupBone("ValveBiped.Bip01_Head1")
	local m = hb and self:GetBoneMatrix(hb)
	if not m then return end
	local fwd = Angle(0, self:GetAngles().y, 0):Forward()
	local up = UP
	local left = up:Cross(fwd)
	local now = CurTime()
	local talkAge = now - self:GetLineTime()
	local l = render.GetLightColor(self:GetPos() + UP * 60)
	RMPG.Model.DrawMeeseeksFace({ O = m:GetTranslation(), F = fwd, L = left, U = up, s = 1 }, {
		talk = self:GetFrenzy() or (self:GetLine() ~= "" and talkAge < 1.8 and math.abs(math.sin(talkAge * 13)) > 0.3),
		blink = (now * 0.27 + self:EntIndex() * 0.37) % 1 < 0.035,
		light = math.Clamp(math.max(l.x, l.y, l.z) * 1.8 + 0.3, 0.4, 1),
	})
	RMPG.ResetTints()
end

local function HeadPos(self)
	return self:GetPos() + UP * (92 * self:GetModelScale())
end

function ENT:DrawTranslucent()
	local eye = EyePos()
	local pos = HeadPos(self)
	if eye:DistToSqr(pos) > 1500 * 1500 then return end
	local ang = EyeAngles()
	ang:RotateAroundAxis(ang:Up(), -90)
	ang:RotateAroundAxis(ang:Forward(), 90)

	local key = self:GetLine()
	local age = CurTime() - self:GetLineTime()
	local me = LocalPlayer()
	local prompt = self:GetMaster() == me and self:GetTask() == 0 and not self:GetFrenzy() and eye:DistToSqr(pos) < 260 * 260
	cam.Start3D2D(pos, ang, 0.1)
		if key ~= "" and age < LINE_TIME then
			local a = math.Clamp((LINE_TIME - age) * 3, 0, 1) * math.Clamp(age * 8, 0, 1)
			local text = RMPG.T(key, self:GetLineArg())
			surface.SetFont("RMPG_Bubble")
			local tw, th = surface.GetTextSize(text)
			local w, h = tw + 44, th + 26
			local frenzy = self:GetFrenzy()
			draw.RoundedBox(18, -w / 2 - 4, -h - 4, w + 8, h + 8, Color(20, 40, 60, 255 * a))
			draw.RoundedBox(16, -w / 2, -h, w, h, frenzy and Color(255, 210, 210, 255 * a) or Color(255, 255, 255, 255 * a))
			draw.NoTexture()
			surface.SetDrawColor(frenzy and Color(255, 210, 210, 255 * a) or Color(255, 255, 255, 255 * a))
			surface.DrawPoly({ { x = -12, y = -2 }, { x = 12, y = -2 }, { x = 0, y = 22 } })
			draw.SimpleText(text, "RMPG_Bubble", 0, -h / 2, frenzy and Color(200, 20, 30, 255 * a) or Color(30, 70, 120, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		if prompt then
			local txt = RMPG.T("mr_prompt")
			surface.SetFont("RMPG_BubbleS")
			local tw = surface.GetTextSize(txt)
			RMPG.HoloBox(-tw / 2 - 14, 34, tw + 28, 34, Color(3, 14, 20, 220), Color(100, 210, 255))
			RMPG.HoloText(txt, "RMPG_BubbleS", 0, 51, Color(220, 245, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	cam.End3D2D()
end
