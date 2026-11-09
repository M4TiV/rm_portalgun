AddCSLuaFile()

-- A body of yourself from Rick Prime's chip (rmpg/sv_prime.lua). With rmpg_implant_prime_guard on it has a mind of its
-- own: it follows you, takes out a pistol and shoots NPCs that hate you and whoever hurt you or one of your bodies, and
-- never shoots you or your other bodies. Off, it stands where it was made and watches you. The swap button moves your
-- mind into it; it can be shot, and it falls down like anyone else.
ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "#rmpg.prime_body"
ENT.Author = "Rick Prime"
ENT.Spawnable = false

local UP = Vector(0, 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Mind")
	self:NetworkVar("Vector", 0, "BodyColor")
	self:NetworkVar("Bool", 0, "Armed") -- the pistol is out
end

function ENT:GetPlayerColor()
	return self:GetBodyColor()
end

if SERVER then
	-- The usual player animations; sequence names are a fallback for models that lack the activity
	local FALLBACK = {
		[ACT_HL2MP_IDLE] = "idle_all_01", [ACT_HL2MP_WALK] = "walk_all", [ACT_HL2MP_RUN] = "run_all_01",
		[ACT_HL2MP_IDLE_PISTOL] = "idle_pistol", [ACT_HL2MP_WALK_PISTOL] = "walk_pistol", [ACT_HL2MP_RUN_PISTOL] = "run_pistol",
	}
	local LOOK = 1500   -- how far it looks for NPCs that hate you
	local LEASH = 900   -- how far from you it goes after someone
	local NEAR, FAR = 110, 220 -- it stops this close to you and sets off again when you are this far

	function ENT:Initialize()
		self:SetHealth(100)
		self:SetMaxHealth(100)
		self:SetCollisionBounds(Vector(-13, -13, 0), Vector(13, 13, 72))
		self.loco:SetDesiredSpeed(0)
		self.loco:SetAcceleration(900)
		self.loco:SetDeceleration(1200)
		self.loco:SetStepHeight(18)
		self.loco:SetJumpHeight(58)
		self.loco:SetMaxYawRate(250)
		-- NPCs on your side take it for one of their own
		local m = self:GetMind()
		if IsValid(m) then
			for _, n in ipairs(ents.FindByClass("npc_*")) do
				if n:IsNPC() and n:Disposition(m) == D_LI then n:AddEntityRelationship(self, D_LI, 50) end
			end
		end
	end

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

	function ENT:BodyUpdate()
		local speed = self.loco:GetVelocity():Length2D()
		local gun = self:GetArmed()
		local act
		if speed > 150 then
			act = gun and ACT_HL2MP_RUN_PISTOL or ACT_HL2MP_RUN
		elseif speed > 15 then
			act = gun and ACT_HL2MP_WALK_PISTOL or ACT_HL2MP_WALK
		else
			act = gun and ACT_HL2MP_IDLE_PISTOL or ACT_HL2MP_IDLE
		end
		self:SetAnim(act)
		if speed > 15 then self:BodyMoveXY() else self:FrameAdvance() end
	end

	function ENT:Gesture(act)
		local seq = self:SelectWeightedSequence(act)
		if seq and seq > 0 then self:AddGestureSequence(seq, true) end
	end

	-- One tick toward a point: along the navmesh when the map has one, straight otherwise
	function ENT:StepToward(goal, speed)
		self.loco:SetDesiredSpeed(speed)
		if navmesh.IsLoaded() and navmesh.GetNavAreaCount() > 0 then
			self.Path = self.Path or Path("Follow")
			if (self.PathT or 0) < CurTime() or not self.PathGoal or self.PathGoal:DistToSqr(goal) > 4096 then
				self.Path:SetMinLookAheadDistance(200)
				self.Path:SetGoalTolerance(24)
				self.Path:Compute(self, goal)
				self.PathT = CurTime() + 0.5
				self.PathGoal = goal
			end
			if self.Path:IsValid() then
				self.Path:Update(self)
				return
			end
		end
		self.loco:FaceTowards(goal)
		self.loco:Approach(goal, 1)
	end

	function ENT:Stand()
		self.loco:SetDesiredSpeed(0)
	end

	function ENT:OnStuck()
		self.loco:Jump()
		self.loco:ClearStuck()
	end

	function ENT:CanSee(e)
		local tr = util.TraceLine({ start = self:GetPos() + UP * 60, endpos = e:WorldSpaceCenter(), filter = { self, e, self:GetMind() }, mask = MASK_SHOT })
		return not tr.Hit
	end

	-- Someone it may fight: alive, not you, not one of your bodies
	function ENT:IsFoe(m, e)
		if not IsValid(e) or e == self or e == m or e:Health() <= 0 or e:GetNoDraw() then return false end
		if e:IsPlayer() then
			if not e:Alive() or RMPG.IgnorePlayers() then return false end
		elseif e.IsLambdaPlayer and e.GetIsDead and e:GetIsDead() then
			return false
		end
		if e:GetClass() == "rmpg_prime_body" and e:GetMind() == m then return false end
		return true
	end

	-- Whom to fight: whoever just hurt you or one of your bodies, else the nearest NPC in sight that hates you
	function ENT:PickFoe(m)
		local now = CurTime()
		if now < (self.NextLook or 0) then return self:IsFoe(m, self.Foe) and self.Foe or nil end
		self.NextLook = now + 0.4
		local pos = self:GetPos()
		local f = m.RMPG_PrimeFoe
		if now - (m.RMPG_PrimeFoeT or 0) < 15 and self:IsFoe(m, f) and f:GetPos():DistToSqr(pos) < 2500 * 2500 then
			self.Foe = f
			return f
		end
		local best, bd
		for _, e in ipairs(ents.FindInSphere(pos, LOOK)) do
			if e:IsNPC() and e:GetClass() ~= "npc_bullseye" and e:Disposition(m) == D_HT and self:IsFoe(m, e) then
				local d = e:GetPos():DistToSqr(pos)
				if (not bd or d < bd) and self:CanSee(e) then best, bd = e, d end
			end
		end
		self.Foe = best
		return best
	end

	function ENT:Shoot(t)
		local src = self:GetPos() + UP * 58 + self:GetForward() * 14
		local dir = (t:WorldSpaceCenter() - src):GetNormalized()
		self:FireBullets({
			Attacker = self, Inflictor = self, Src = src, Dir = dir, Spread = Vector(0.035, 0.035, 0),
			Num = 1, Damage = RMPG.CV.primeDamage:GetFloat(), Force = 3, Tracer = 1, TracerName = "Tracer",
			IgnoreEntity = self:GetMind(),
		})
		self:EmitSound(RMPG.SND.cloneShot, 80, math.random(95, 105))
		self:Gesture(ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL)
		-- the NPC it shoots at fights back
		if t:IsNPC() and self.Angered ~= t then
			self.Angered = t
			t:AddEntityRelationship(self, D_HT, 60)
		end
	end

	function ENT:Fight(m, t)
		local pos = self:GetPos()
		local to = t:GetPos() - pos
		local d = to:Length()
		local mine = IsValid(m) and m:GetPos():DistToSqr(pos) or 0
		if d < 1400 and self:CanSee(t) then
			self:Stand()
			self.loco:FaceTowards(t:GetPos())
			to.z = 0
			if self:GetForward():Dot(to:GetNormalized()) > 0.85 and (self.NextShot or 0) < CurTime() then
				self.NextShot = CurTime() + math.Rand(0.35, 0.6)
				self:Shoot(t)
			end
		elseif mine < LEASH * LEASH then
			self:StepToward(t:GetPos(), 250) -- after it, but not too far from you
		else
			self:StepToward(m:GetPos(), 250)
		end
	end

	function ENT:RunBehaviour()
		while true do
			local m = self:GetMind()
			local guard = RMPG.CV.primeGuard:GetBool()
			local alive = IsValid(m) and m:Alive()
			local t = guard and alive and self:PickFoe(m) or nil
			if t then self.ArmedUntil = CurTime() + 6 end
			local armed = CurTime() < (self.ArmedUntil or 0)
			if self:GetArmed() ~= armed then self:SetArmed(armed) end
			if t then
				self:Fight(m, t)
			elseif alive then
				local d = m:GetPos():Distance(self:GetPos())
				if guard and (d > FAR or (self.Following and d > NEAR)) then
					self.Following = true
					self:StepToward(m:GetPos(), d > 400 and 250 or 140)
				else
					self.Following = false
					self:Stand()
					if d < 700 then self.loco:FaceTowards(m:GetPos()) end
				end
			else
				self:Stand()
			end
			coroutine.yield()
		end
	end

	function ENT:OnKilled(dmg)
		hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
		self:BecomeRagdoll(dmg)
	end

	return
end

---------------------------------------------------------------------------
-- Client: the pistol in its hand while it fights
---------------------------------------------------------------------------

function ENT:Draw()
	self:DrawModel()
	if not self:GetArmed() then
		if IsValid(self.Gun) then self.Gun:SetNoDraw(true) end
		return
	end
	if not IsValid(self.Gun) then
		self.Gun = ClientsideModel("models/weapons/w_pistol.mdl", RENDERGROUP_OPAQUE)
		if not IsValid(self.Gun) then return end
		self.Gun:SetParent(self)
		self.Gun:AddEffects(EF_BONEMERGE)
		self.Gun:SetNoDraw(true)
	end
	self.Gun:DrawModel()
end

function ENT:OnRemove()
	if IsValid(self.Gun) then self.Gun:Remove() end
end
