-- Server: the portal trap, a mode of the portal gun. One portal opens where you aim and leads nowhere. Whoever touches
-- the portal itself - anyone, the one who opened it too - is pulled in and torn to pieces: a ragdoll of the body takes
-- their place, its head, arms and legs come off one after another in sprays of blood, everything is swallowed and bits
-- of bone fly back out. Nothing is pulled from a distance any more: it takes only what touches it. A prop that touches
-- it is spat back out in a shower of sparks. It closes after rmpg_portal_trap_time seconds; the streaks running into it
-- are drawn in cl_trap.lua.
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local TEAR = { "head", "larm", "rarm", "lleg", "rleg" }
local TEAR_EVERY = 0.07  -- a limb off this often
local SWALLOW = 30       -- this close to the middle a piece is gone
local BODY_LIFE = 2.5    -- whatever is still out after this long is swallowed anyway
local GIBS = { "models/gibs/hgibs.mdl", "models/gibs/hgibs_rib.mdl", "models/gibs/hgibs_scapula.mdl", "models/gibs/hgibs_spine.mdl",
	"models/gibs/hgibs_rib.mdl" }
local SKIP = { rmpg_portal = true, rmpg_boots_body = true, predicted_viewmodel = true, gmod_hands = true, physgun_beam = true,
	rmpg_worm_seg = true, rmpg_phoenix_tank = true }
local traps = {}

local function Snd(name, a, b)
	return string.format(RMPG.SND[name], math.random(a, b))
end

-- Opens the trap where the player aims. Gives where, for the shot's effect
function RMPG.OpenTrap(ply, col, core)
	local pos, ang, free = RMPG.SurfacePlacement(ply)
	if not pos then return end
	local p = RMPG.SpawnPortal(ply, pos, ang, col, free, core)
	if not IsValid(p) then return end
	p.DieTime = CurTime() + RMPG.CV.trapTime:GetFloat()
	p:SetNW2Bool("RMPG_Trap", true)
	p:EmitSound(RMPG.SND.trapOpen, 85)
	if IsValid(ply.RMPG_TrapPortal) then ply.RMPG_TrapPortal:Close() end
	ply.RMPG_TrapPortal = p
	traps[p] = { owner = ply, bodies = {}, spat = {}, wind = 0 }
	return pos
end

local function Living(e)
	if e:IsPlayer() then return e:Alive() and not e:HasGodMode() end
	if e.IsLambdaPlayer then return RMPG.PersonAlive(e) end
	return (e:IsNPC() or e:IsNextBot()) and e:Health() > 0
end

local function BloodOf(e)
	local c = e.GetBloodColor and e:GetBloodColor()
	if c == nil then return BLOOD_COLOR_RED end
	return c
end

local function Sparks(pos, normal)
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetNormal(normal)
	ed:SetMagnitude(3)
	ed:SetRadius(8)
	ed:SetScale(2)
	util.Effect("MetalSpark", ed, true, true)
	util.Effect("ManhackSparks", ed, true, true)
end

-- Blood flying from pos along dir, a splash on whatever wall it reaches; robots and the like spark instead
local function Spray(pos, dir, color, big)
	if color == DONT_BLEED then
		Sparks(pos, dir)
		return
	end
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetNormal(dir)
	ed:SetScale(big and 14 or 8)
	ed:SetFlags(7) -- drops, gore and a cloud
	ed:SetColor(color)
	util.Effect("bloodspray", ed, true, true)
	util.Effect("BloodImpact", ed, true, true)
	local decal = color == BLOOD_COLOR_RED and "Blood" or "YellowBlood"
	for _ = 1, big and 3 or 1 do
		local d = (dir + VectorRand() * 0.7):GetNormalized()
		local tr = util.TraceLine({ start = pos, endpos = pos + d * 220, mask = MASK_SOLID_BRUSHONLY })
		if tr.Hit then util.Decal(decal, tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal) end
	end
end

-- Bits of bone thrown back out of the portal
local function Gibs(center, normal, n)
	for _ = 1, n do
		local g = ents.Create("prop_physics")
		if not IsValid(g) then return end
		g:SetModel(GIBS[math.random(#GIBS)])
		g:SetPos(center + normal * 6 + VectorRand() * 6)
		g:SetAngles(AngleRand())
		g:Spawn()
		g:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		local po = g:GetPhysicsObject()
		if IsValid(po) then
			po:SetVelocity((normal + VectorRand() * 0.55):GetNormalized() * math.Rand(260, 520) + UP * 80)
			po:AddAngleVelocity(VectorRand() * 900)
		end
		SafeRemoveEntityDelayed(g, 12)
	end
end

-- Someone alive touched it: a ragdoll in the pose they are in takes their place, and their own corpse is hidden. A shield
-- can keep them alive, and then they stay as they are
local function Take(st, e, portal, now)
	if (e.RMPG_TrapSafe or 0) > now then return end
	local center = portal:GetPos()
	local blood = BloodOf(e)
	local rag = RMPG.RagdollOf(e, (center - e:WorldSpaceCenter()):GetNormalized() * 300)
	e:SetNW2Float("RMPG_Vapor", now)
	local d = DamageInfo()
	d:SetDamage(e:Health() + (e:IsPlayer() and e:Armor() or 0) + 1000)
	d:SetDamageType(DMG_CRUSH)
	d:SetAttacker(IsValid(st.owner) and st.owner or portal)
	d:SetInflictor(portal)
	d:SetDamagePosition(center)
	e:TakeDamageInfo(d)
	local alive = IsValid(e) and (e:IsPlayer() and e:Alive() or (not e:IsPlayer() and e:Health() > 0 and not (e.IsLambdaPlayer and e:GetIsDead())))
	if alive then
		e:SetNW2Float("RMPG_Vapor", -100)
		e.RMPG_TrapSafe = now + 2
		SafeRemoveEntity(rag)
		return
	end
	if IsValid(e) and e:IsPlayer() and e:Alive() then e:Kill() end
	if IsValid(e) and not e:IsPlayer() and not e.IsLambdaPlayer and e:Health() > 0 then e:Remove() end
	portal:EmitSound(Snd("trapTear", 2, 4), 90, math.random(85, 100))
	portal:EmitSound(RMPG.SND.trapCrunch, 85, math.random(95, 110))
	Spray(center, portal:GetForward(), blood, true)
	if IsValid(rag) then st.bodies[rag] = { t = now, next = 1, blood = blood, body = true } end
end

-- Pulls every part of e into the portal, faster the closer it gets, and a little round about
local function Pull(e, center, normal, speed)
	for i = 0, e:GetPhysicsObjectCount() - 1 do
		local po = e:GetPhysicsObjectNum(i)
		if IsValid(po) then
			local to = center - po:GetPos()
			local d = math.max(to:Length(), 1)
			local swirl = to:Cross(normal)
			if swirl:LengthSqr() > 0.01 then swirl:Normalize() end
			po:Wake()
			po:SetVelocity(to / d * math.min(speed + d * 4, 1400) + swirl * 120)
		end
	end
end

local function Touches(e, center, ang, half, frame)
	return RMPG.TouchesPortal(e, center, ang, half, frame, e:IsPlayer() and 4 or 2, e:IsPlayer() and 1.06 or 1)
end

local function Think(portal, st, now)
	local center, ang = portal:GetPos(), portal:GetAngles()
	local normal = ang:Forward()
	local s = portal:OpenScale()
	if now >= st.wind then
		st.wind = now + 2
		portal:EmitSound(Snd("trapWind", 1, 5), 75, 70)
	end
	if s > 0.6 then
		local half = portal:GetRadius() * s
		local frame = RMPG.ShapeFrame(now)
		for _, e in ipairs(ents.FindInSphere(center, half + 140)) do
			if IsValid(e) and not SKIP[e:GetClass()] and not st.bodies[e] and not IsValid(e:GetParent()) and Touches(e, center, ang, half, frame) then
				if Living(e) then
					if RMPG.CV.trapPeople:GetBool() then Take(st, e, portal, now) end
				elseif e:GetClass() == "prop_ragdoll" and not e.RMPG_TrapDone then
					-- a corpse that touches it goes the same way
					st.bodies[e] = { t = now, next = e.RMPG_Limb and #TEAR + 1 or 1, blood = BLOOD_COLOR_RED, body = not e.RMPG_Limb }
				elseif e:GetMoveType() == MOVETYPE_VPHYSICS and not (e:IsWeapon() and IsValid(e:GetOwner())) and (st.spat[e] or 0) < now then
					local po = e:GetPhysicsObject()
					if IsValid(po) and po:IsMotionEnabled() then
						st.spat[e] = now + 1.5
						po:Wake()
						po:SetVelocity(normal * 850 + VectorRand() * 160 + UP * 120)
						po:AddAngleVelocity(VectorRand() * 600)
						Sparks(e:WorldSpaceCenter(), normal)
						e:EmitSound(Snd("trapSpit", 1, 4), 80, math.random(90, 110))
					end
				end
			end
		end
	end
	-- the torn: pulled in, a limb off one after another, and gone when they get there
	for rag, b in pairs(st.bodies) do
		if not IsValid(rag) then
			st.bodies[rag] = nil
		else
			Pull(rag, center, normal, 500)
			if b.next <= #TEAR and now - b.t >= TEAR_EVERY * b.next then
				local push = VectorRand() * 260 + normal * 220
				local piece = RMPG.TearLimb(rag, TEAR[b.next], push)
				b.next = b.next + 1
				if IsValid(piece) then
					st.bodies[piece] = { t = now, next = #TEAR + 1, blood = b.blood }
					local root = piece:LookupBone(RMPG.LIMBS[piece.RMPG_Limb or "head"] or "")
					Spray(root and piece:GetBonePosition(root) or rag:WorldSpaceCenter(), push:GetNormalized(), b.blood, false)
					portal:EmitSound(Snd("trapTear", 2, 4), 80, math.random(95, 115))
					portal:EmitSound(Snd("trapSquish", 1, 4), 75, math.random(90, 110))
				end
			end
			local po = rag:GetPhysicsObject()
			if (IsValid(po) and po:GetPos():Distance(center) < SWALLOW) or now - b.t > BODY_LIFE then
				Spray(center, normal, b.blood, b.body)
				if b.body and b.blood ~= DONT_BLEED then Gibs(center, normal, math.random(3, 5)) end
				portal:EmitSound(RMPG.SND.trapSwallow, 80, math.random(90, 110))
				st.bodies[rag] = nil
				rag:Remove()
			end
		end
	end
	for e, t in pairs(st.spat) do
		if not IsValid(e) or t < now - 5 then st.spat[e] = nil end
	end
end

local nextThink = 0
hook.Add("Think", "rmpg_trap", function()
	local now = CurTime()
	if now < nextThink then return end
	nextThink = now + 0.05
	for portal, st in pairs(traps) do
		if not IsValid(portal) or portal:GetCloseTime() > 0 then
			-- what was on its way in falls where it is
			for rag in pairs(st.bodies) do
				if IsValid(rag) then
					rag.RMPG_TrapDone = true
					SafeRemoveEntityDelayed(rag, 15)
				end
			end
			traps[portal] = nil
		else
			Think(portal, st, now)
		end
	end
end)
