AddCSLuaFile()

-- A visitor from another dimension: a copy of one of the players (their model, colours and name) that steps out of
-- a green portal. It acts like a player who has just joined - a "joined the game" line, a row in TAB, chat lines -
-- and either hunts the player it came for or brings them a present, then leaves the same way (sv_clones.lua).
ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "#rmpg.clone"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Spawnable = false
ENT.LambdaPlayerSTALP = true -- Lambda Players treat it as one of the players

list.Set("NPC", "rmpg_clone", { Name = "#rmpg.clone", Class = "rmpg_clone", Category = "Rick and Morty" })

local UP = Vector(0, 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Source")  -- the player it is a copy of
	self:NetworkVar("Entity", 1, "Target")  -- the player it came for
	self:NetworkVar("Bool", 0, "Hostile")
	self:NetworkVar("String", 0, "CloneName")
	self:NetworkVar("Vector", 0, "CloneColor")
	self:NetworkVar("Int", 0, "CloneID")
end

-- Player models colour themselves from this (the PlayerColor material proxy)
function ENT:GetPlayerColor()
	return self:GetCloneColor()
end

if SERVER then
	-- The usual player animations; sequence names are a fallback for models that lack the activity
	local FALLBACK = {
		[ACT_HL2MP_IDLE] = "idle_all_01", [ACT_HL2MP_WALK] = "walk_all", [ACT_HL2MP_RUN] = "run_all_01",
		[ACT_HL2MP_IDLE_PISTOL] = "idle_pistol", [ACT_HL2MP_WALK_PISTOL] = "walk_pistol", [ACT_HL2MP_RUN_PISTOL] = "run_pistol",
	}

	function ENT:Initialize()
		local src = self.SourcePly
		if not IsValid(src) then
			local all = player.GetAll()
			src = all[math.random(math.max(#all, 1))]
		end
		if IsValid(src) then
			self:SetSource(src)
			self:SetCloneName(RMPG.PersonName(src))
			self:SetModel(src:GetModel())
			self:SetSkin(src:GetSkin())
			for i = 0, src:GetNumBodyGroups() - 1 do self:SetBodygroup(i, src:GetBodygroup(i)) end
			self:SetCloneColor(RMPG.PersonColor(src))
		else
			self:SetModel("models/player/kleiner.mdl")
			self:SetCloneName("Player")
			self:SetCloneColor(Vector(0.24, 0.34, 0.41))
		end
		if not IsValid(self:GetTarget()) then self:SetTarget(self.TargetPly or src) end
		if self.ForceHostile ~= nil then
			self:SetHostile(self.ForceHostile)
		else
			self:SetHostile(math.random() * 100 < RMPG.CV.cloneHostile:GetFloat())
		end
		self:SetHealth(100)
		self:SetMaxHealth(100)
		self:SetCollisionBounds(Vector(-14, -14, 0), Vector(14, 14, 72))
		self.loco:SetDesiredSpeed(self:GetHostile() and 260 or 200)
		self.loco:SetAcceleration(900)
		self.loco:SetDeceleration(1200)
		self.loco:SetStepHeight(18)
		self.loco:SetJumpHeight(58)
		self.LeaveAt = CurTime() + (self:GetHostile() and 120 or 60)
		-- already announced by RMPG.SpawnClone, or joining now (the spawn menu)
		if self.PresetID and RMPG.Clones[self.PresetID] then
			self:SetCloneID(self.PresetID)
		elseif self:GetCloneID() == 0 then
			RMPG.CloneJoined(self)
		end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
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
		local gun = self:GetHostile()
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
	function ENT:StepToward(goal)
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

	function ENT:OnStuck()
		self.loco:Jump()
		self.loco:ClearStuck()
	end

	function ENT:CanSee(e)
		local tr = util.TraceLine({ start = self:GetPos() + UP * 60, endpos = e:WorldSpaceCenter(), filter = { self, e }, mask = MASK_SHOT })
		return not tr.Hit
	end

	function ENT:Shoot(t)
		local src = self:GetPos() + UP * 58 + self:GetForward() * 14
		local dir = (t:WorldSpaceCenter() - src):GetNormalized()
		self:FireBullets({
			Attacker = self, Inflictor = self, Src = src, Dir = dir, Spread = Vector(0.045, 0.045, 0),
			Num = 1, Damage = RMPG.CV.cloneDamage:GetFloat(), Force = 3, Tracer = 1, TracerName = "Tracer",
		})
		self:EmitSound(RMPG.SND.cloneShot, 80, math.random(95, 105))
		self:Gesture(ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL)
	end

	-- A present for the player it came for, put down in front of them
	function ENT:Gift(t)
		local list = RMPG.CLONE_GIFTS
		local class = list[math.random(#list)]
		local e = ents.Create(class)
		if not IsValid(e) then return end
		local dir = (self:GetPos() - t:GetPos())
		dir.z = 0
		dir:Normalize()
		local pos = t:GetPos() + dir * 50 + UP * 20
		e:SetPos(pos)
		e:Spawn()
		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetScale(0.7)
		util.Effect("rmpg_meeseeks_poof", ed, true, true)
		self:EmitSound(RMPG.SND.pickup, 70)
	end

	function ENT:RunBehaviour()
		coroutine.wait(0.8) -- a moment in front of the portal it came out of
		RMPG.CloneSay(self, self:GetHostile() and "clone_hello_bad" or "clone_hello")
		local gifted, lostT = false, nil
		while true do
			if CurTime() > self.LeaveAt then
				RMPG.CloneSay(self, "clone_bye")
				coroutine.wait(1)
				RMPG.CloneLeave(self)
				return
			end
			local t = self:GetTarget()
			if not RMPG.PersonAlive(t) then
				-- the one it came for is gone: wait around a little, then leave
				lostT = lostT or CurTime()
				if CurTime() - lostT > 8 then self.LeaveAt = 0 end
				self:SetAnim(ACT_HL2MP_IDLE)
			else
				lostT = nil
				local d = t:GetPos():Distance(self:GetPos())
				if self:GetHostile() then
					if t:IsPlayer() and RMPG.IgnorePlayers() then
						self.loco:FaceTowards(t:GetPos()) -- ai_ignoreplayers: it does not fight players
					elseif d > 450 or not self:CanSee(t) then
						self:StepToward(t:GetPos())
					else
						self.loco:FaceTowards(t:GetPos())
						if (self.NextShot or 0) < CurTime() then
							self.NextShot = CurTime() + math.Rand(0.45, 0.85)
							self:Shoot(t)
						end
					end
				elseif not gifted then
					if d > 90 then
						self:StepToward(t:GetPos())
					else
						self.loco:FaceTowards(t:GetPos())
						self:Gesture(ACT_GMOD_GESTURE_WAVE)
						self:EmitSound(string.format(RMPG.SND.cloneHi, math.random(1, 2)), 70)
						RMPG.CloneSay(self, "clone_gift")
						coroutine.wait(0.8)
						if IsValid(t) then self:Gift(t) end
						gifted = true
						self.LeaveAt = math.min(self.LeaveAt, CurTime() + 25)
					end
				elseif d > 180 then
					self:StepToward(t:GetPos())
				else
					self.loco:FaceTowards(t:GetPos())
				end
			end
			coroutine.yield()
		end
	end

	function ENT:OnInjured(dmg)
		if (self.NextOuch or 0) < CurTime() then
			self.NextOuch = CurTime() + 1
			self:EmitSound(string.format(RMPG.SND.clonePain, math.random(1, 9)), 75)
		end
		-- a friendly copy that gets shot shoots back
		local a = dmg:GetAttacker()
		if not self:GetHostile() and IsValid(a) and ((a:IsPlayer() and not RMPG.IgnorePlayers()) or a.IsLambdaPlayer) then
			self:SetHostile(true)
			self:SetTarget(a)
			self.loco:SetDesiredSpeed(260)
		end
	end

	function ENT:OnKilled(dmg)
		hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
		RMPG.CloneDied(self, dmg:GetAttacker())
		self:BecomeRagdoll(dmg)
	end

	function ENT:OnRemove()
		if not self.Left then RMPG.CloneGone(self) end
	end

	-- a kill by the copy counts in its TAB row
	hook.Add("PlayerDeath", "rmpg_clone_frags", function(victim, inflictor, attacker)
		if IsValid(attacker) and attacker:GetClass() == "rmpg_clone" then RMPG.CloneFrag(attacker) end
	end)

	return
end

---------------------------------------------------------------------------
-- Client: a pistol in the hand of a hostile copy
---------------------------------------------------------------------------

function ENT:Draw()
	self:DrawModel()
	if not self:GetHostile() then
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
