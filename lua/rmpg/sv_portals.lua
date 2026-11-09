-- Server: portal pairs, teleportation, destinations, firing, vaporising
RMPG = RMPG or {}
RMPG.Pairs = RMPG.Pairs or {}

local UP = Vector(0, 0, 1)
local HULL_MIN, HULL_MAX = Vector(-16, -16, 0), Vector(16, 16, 72)

util.AddNetworkString("rmpg_notify")
util.AddNetworkString("rmpg_fx")
util.AddNetworkString("rmpg_tpflash")

function RMPG.Notify(ply, key, args, kind)
	if not IsValid(ply) then return end
	net.Start("rmpg_notify")
	net.WriteString(key)
	net.WriteTable(args or {})
	net.WriteUInt(kind or 0, 2)
	net.Send(ply)
end

---------------------------------------------------------------------------
-- Pairs
---------------------------------------------------------------------------

local function PairsOf(ply)
	local list = RMPG.Pairs[ply] or {}
	for i = #list, 1, -1 do
		local p = list[i]
		if not IsValid(p[1]) and not IsValid(p[2]) then table.remove(list, i) end
	end
	RMPG.Pairs[ply] = list
	return list
end

function RMPG.SpawnPortal(ply, pos, ang, col, free, core)
	local p = ents.Create("rmpg_portal")
	if not IsValid(p) then return end
	p:SetPos(pos)
	p:SetAngles(ang)
	p:SetPortalColor(col)
	p:SetRadius(RMPG.Radius())
	p:SetFreestanding(free and true or false)
	p:SetCore(core and true or false)
	p:SetOwnerPlayer(ply)
	p:Spawn()
	p:Activate()
	local life = RMPG.CV.lifetime:GetFloat()
	if life > 0 then p.DieTime = CurTime() + life end
	return p
end

function RMPG.LinkPair(ply, a, b)
	a:SetPartner(b)
	b:SetPartner(a)
	a.WasLinked, b.WasLinked = true, true
	local life = RMPG.CV.lifetime:GetFloat()
	local die = life > 0 and CurTime() + life or nil
	a.DieTime, b.DieTime = die, die
	local list = PairsOf(ply)
	table.insert(list, { a, b })
	while #list > RMPG.CV.maxPairs:GetInt() do
		local old = table.remove(list, 1)
		if IsValid(old[1]) then old[1]:Close() end
		if IsValid(old[2]) then old[2]:Close() end
	end
end

---------------------------------------------------------------------------
-- Chained portals: P1 -> P2 -> P3 ... Each new portal is where the newest one so far leads, and the newest leads
-- nowhere until the next shot. A link that closes is skipped: the one before it leads into the one after it.
---------------------------------------------------------------------------

local function ChainOf(ply)
	local list = ply.RMPG_ChainList or {}
	for i = #list, 1, -1 do
		local p = list[i]
		if not IsValid(p) or p:GetCloseTime() > 0 then table.remove(list, i) end
	end
	ply.RMPG_ChainList = list
	return list
end

function RMPG.ChainRelink(ply)
	if not IsValid(ply) then return end
	local list = ChainOf(ply)
	for i, p in ipairs(list) do
		local nxt = list[i + 1]
		if nxt ~= p:GetPartner() then p:SetPartner(IsValid(nxt) and nxt or NULL) end
	end
end

function RMPG.ChainAdd(ply, p)
	local list = ChainOf(ply)
	p.RMPG_Chain = true
	list[#list + 1] = p
	while #list > RMPG.CV.chainMax:GetInt() do
		local old = table.remove(list, 1)
		if IsValid(old) then
			old.RMPG_Chain = nil -- out of the chain already: it closes without relinking
			old:SetPartner(NULL)
			old:Close()
		end
	end
	RMPG.ChainRelink(ply)
	if #list == 1 then RMPG.Notify(ply, "n_chain_first", nil, 0) end
end

function RMPG.ClosePortals(ply)
	for _, p in ipairs(PairsOf(ply)) do
		if IsValid(p[1]) then p[1]:Close() end
		if IsValid(p[2]) then p[2]:Close() end
	end
	for _, p in ipairs(ChainOf(ply)) do
		p.RMPG_Chain = nil
		p:Close()
	end
	ply.RMPG_ChainList = {}
	if RMPG.MapTripClose then RMPG.MapTripClose(ply) end
	RMPG.Pairs[ply] = {}
	if IsValid(ply.RMPG_PendingA) then ply.RMPG_PendingA:Close() end
	ply.RMPG_PendingA = nil
end

hook.Add("PlayerDisconnected", "rmpg_cleanup", function(ply)
	RMPG.ClosePortals(ply)
	RMPG.Pairs[ply] = nil
end)

---------------------------------------------------------------------------
-- Who can travel
---------------------------------------------------------------------------

function RMPG.CanTeleport(ent)
	if not IsValid(ent) or ent:IsWorld() then return false end
	if (ent.RMPG_NextTP or 0) > CurTime() then return false end
	local c = ent:GetClass()
	if c == "rmpg_portal" or c == "rmpg_meltdown" or c == "rmpg_worm_seg" or c == "rmpg_brain_worm" then return false end
	if IsValid(ent:GetParent()) then return false end
	if ent:IsPlayer() then
		return ent:Alive() and not ent:InVehicle() and ent:GetObserverMode() == OBS_MODE_NONE
	end
	if ent:IsNPC() or ent:IsNextBot() then
		return RMPG.CV.tpNPCs:GetBool() and ent:Health() > 0
	end
	if ent:IsVehicle() then
		return RMPG.CV.tpCars:GetBool() and IsValid(ent:GetPhysicsObject())
	end
	if not RMPG.CV.tpProps:GetBool() then return false end
	if ent:IsWeapon() and IsValid(ent:GetOwner()) then return false end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) or not phys:IsMoveable() then return false end
	if constraint and constraint.HasConstraints and constraint.HasConstraints(ent) then return false end
	return true
end

local function HullFreeAt(ent, pos, mins, maxs)
	local tr = util.TraceHull({ start = pos, endpos = pos, mins = mins, maxs = maxs, filter = ent, mask = MASK_PLAYERSOLID })
	return not tr.Hit
end

local function MinOut(v, dir, speed)
	local o = v:Dot(dir)
	if o < speed then v = v + dir * (speed - o) end
	return v
end

---------------------------------------------------------------------------
-- Teleport
---------------------------------------------------------------------------

function RMPG.Teleport(ent, from, to)
	if ent:IsPlayer() then RMPG.NPCFollow(ent, from) end
	local fa, ta = from:GetAngles(), to:GetAngles()
	local tf = ta:Forward()
	local tc = to:GetPos()
	local exitCenter

	if ent:IsPlayer() then
		local mins, maxs
		if ent:Crouching() then mins, maxs = ent:GetHullDuck() else mins, maxs = ent:GetHull() end
		local hz = (maxs.z - mins.z) * 0.5
		local ext = math.abs(tf.x) * maxs.x + math.abs(tf.y) * maxs.y + math.abs(tf.z) * hz
		exitCenter = tc + tf * (ext + 4)
		-- in gravity boots the player's origin is their middle already
		local pos = RMPG.BootsOn(ent) and exitCenter or exitCenter - UP * hz
		if not HullFreeAt(ent, pos, mins, maxs) then
			local found = false
			for _, k in ipairs({ 8, 16, 32, 48, 64 }) do
				for _, d in ipairs({ tf, UP, -UP }) do
					if not found and HullFreeAt(ent, pos + d * k, mins, maxs) then
						pos = pos + d * k
						found = true
					end
				end
			end
		end
		local nv = MinOut(RMPG.TransformDir(ent:GetVelocity(), fa, ta), tf, 160)
		local na = RMPG.TransformDir(ent:EyeAngles():Forward(), fa, ta):Angle()
		na.r = 0
		ent:SetPos(pos)
		ent:SetEyeAngles(na)
		ent:SetVelocity(nv - ent:GetVelocity())
		ent.RMPG_LastTP = CurTime()
		net.Start("rmpg_tpflash")
		net.WriteVector(to:GetPortalColor())
		net.Send(ent)
	elseif ent:IsNPC() or ent:IsNextBot() then
		local ext = RMPG.Extent(ent, tf)
		exitCenter = tc + tf * (ext + 6)
		local off = ent:WorldSpaceCenter() - ent:GetPos()
		local yaw = RMPG.TransformDir(ent:GetForward(), fa, ta):Angle().y
		ent:SetPos(exitCenter - off)
		ent:SetAngles(Angle(0, yaw, 0))
		RMPG.AfterNPCExit(ent)
	elseif ent:IsVehicle() then
		local newAng = RMPG.TransformAng(ent:GetAngles(), fa, ta)
		local ext = RMPG.Extent(ent, tf, newAng)
		exitCenter = tc + tf * (ext + 6)
		local offLocal = ent:WorldToLocal(ent:WorldSpaceCenter())
		local newPos = exitCenter - LocalToWorld(offLocal, angle_zero, vector_origin, newAng)
		-- remember every physics object relative to the body so the wheels come along
		local oldPos, oldAng = ent:GetPos(), ent:GetAngles()
		local parts = {}
		for i = 0, ent:GetPhysicsObjectCount() - 1 do
			local po = ent:GetPhysicsObjectNum(i)
			if IsValid(po) then
				local lp, la = WorldToLocal(po:GetPos(), po:GetAngles(), oldPos, oldAng)
				parts[#parts + 1] = { po, lp, la, RMPG.TransformDir(po:GetVelocity(), fa, ta) }
			end
		end
		ent:SetPos(newPos)
		ent:SetAngles(newAng)
		for _, part in ipairs(parts) do
			local wp, wa = LocalToWorld(part[2], part[3], newPos, newAng)
			part[1]:SetPos(wp, true)
			part[1]:SetAngles(wa)
			part[1]:SetVelocity(MinOut(part[4], tf, 200))
			part[1]:Wake()
		end
		local drv = ent.GetDriver and ent:GetDriver()
		if IsValid(drv) and drv:IsPlayer() then
			drv.RMPG_LastTP = CurTime()
			net.Start("rmpg_tpflash")
			net.WriteVector(to:GetPortalColor())
			net.Send(drv)
		end
	else
		local newAng = RMPG.TransformAng(ent:GetAngles(), fa, ta)
		local ext = RMPG.Extent(ent, tf, newAng)
		local wsc = ent:WorldSpaceCenter()
		exitCenter = tc + tf * (ext + 4)
		local count = ent:GetPhysicsObjectCount()
		if count <= 1 then
			local phys = ent:GetPhysicsObject()
			local vel = IsValid(phys) and phys:GetVelocity() or ent:GetVelocity()
			local nv = MinOut(RMPG.TransformDir(vel, fa, ta), tf, 160)
			local offLocal = ent:WorldToLocal(wsc)
			local rotated = LocalToWorld(offLocal, angle_zero, vector_origin, newAng)
			ent:SetPos(exitCenter - rotated)
			ent:SetAngles(newAng)
			if IsValid(phys) then
				phys:SetVelocity(nv)
				phys:Wake()
			end
		else
			-- ragdolls: move every bone through the portal and keep the pose
			local shift = exitCenter - RMPG.TransformPoint(wsc, from, to)
			for i = 0, count - 1 do
				local po = ent:GetPhysicsObjectNum(i)
				if IsValid(po) then
					local p = RMPG.TransformPoint(po:GetPos(), from, to) + shift
					local a = RMPG.TransformAng(po:GetAngles(), fa, ta)
					local v = MinOut(RMPG.TransformDir(po:GetVelocity(), fa, ta), tf, 160)
					po:SetPos(p)
					po:SetAngles(a)
					po:SetVelocity(v)
					po:Wake()
				end
			end
		end
	end

	ent.RMPG_NextTP = CurTime() + 0.15
	ent.RMPG_IgnorePortal = to
	ent.RMPG_IgnoreUntil = CurTime() + 0.3
	ent.RMPG_LastPortal, ent.RMPG_LastPortalT = from, CurTime()
	-- Meeseeks following this one run into the same portal
	if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then RMPG.MrFollowPortal(ent, from, to) end

	from:EmitSound(RMPG.SND.enter, 70, math.random(95, 108))
	to:EmitSound(RMPG.SND.enter, 70, math.random(95, 108))
	local ed = EffectData()
	ed:SetOrigin(exitCenter or tc)
	ed:SetNormal(tf)
	ed:SetStart(to:GetPortalColor())
	ed:SetScale(1)
	util.Effect("rmpg_burst", ed, true, true)
end

-- Coming out of a portal never ends with fall damage (portals can save you from a fall)
hook.Add("GetFallDamage", "rmpg_portal_landing", function(ply)
	if CurTime() - (ply.RMPG_LastTP or 0) < 1.2 then return 0 end
end)

---------------------------------------------------------------------------
-- NPCs chasing (or escorting) a player go through the same portal
---------------------------------------------------------------------------

RMPG.Followers = RMPG.Followers or {}

function RMPG.NPCFollow(ply, portal)
	if not RMPG.CV.npcFollow:GetBool() or not RMPG.CV.tpNPCs:GetBool() then return end
	local pos = portal:GetPos()
	for _, npc in ipairs(ents.FindInSphere(pos, 1600)) do
		if npc:IsNPC() and npc:Health() > 0 and not RMPG.Followers[npc] then
			local hunting = npc:GetEnemy() == ply
			local friend = npc:Disposition(ply) == D_LI and npc:GetPos():DistToSqr(pos) < 900 * 900
			if (hunting or friend) and (npc:Visible(ply) or npc:GetPos():DistToSqr(pos) < 500 * 500) then
				RMPG.Followers[npc] = { portal = portal, target = ply, hostile = hunting, untilT = CurTime() + 15, nextT = CurTime() + math.Rand(0.1, 0.6) }
			end
		end
	end
end

function RMPG.AfterNPCExit(npc)
	local d = RMPG.Followers[npc]
	RMPG.Followers[npc] = nil
	if not d or not IsValid(d.target) or not d.target:Alive() then return end
	if d.hostile then
		npc:SetEnemy(d.target)
		npc:UpdateEnemyMemory(d.target, d.target:GetPos())
	else
		npc:SetLastPosition(d.target:GetPos())
		npc:SetSchedule(SCHED_FORCED_GO_RUN)
	end
end

hook.Add("Think", "rmpg_npc_follow", function()
	if next(RMPG.Followers) == nil then return end
	local t = CurTime()
	for npc, d in pairs(RMPG.Followers) do
		if not IsValid(npc) or npc:Health() <= 0 or not IsValid(d.portal) or d.portal:GetCloseTime() > 0 or t > d.untilT then
			RMPG.Followers[npc] = nil
		elseif t >= d.nextT then
			d.nextT = t + 0.7
			local f = d.portal:GetAngles():Forward()
			local goal = d.portal:GetPos() + f * 10
			goal = RMPG.GroundBelow(goal + UP * 20, 400) or goal
			npc:SetLastPosition(goal)
			npc:SetSchedule(SCHED_FORCED_GO_RUN)
		end
	end
end)

---------------------------------------------------------------------------
-- Destination search
---------------------------------------------------------------------------

function RMPG.HullFree(pos, filter)
	local tr = util.TraceHull({
		start = pos + UP * 2, endpos = pos + UP * 2,
		mins = HULL_MIN, maxs = HULL_MAX,
		mask = MASK_PLAYERSOLID, filter = filter,
	})
	return not tr.Hit
end

-- Room for an upright portal at ground point g facing fwd, plus room to step out of it
function RMPG.SpotOK(g, fwd, filter)
	local R = RMPG.Radius()
	if not RMPG.HullFree(g + fwd * 22, filter) then return false end
	local top = util.TraceLine({ start = g + UP * 8, endpos = g + UP * (R * (RMPG.ShapeBottom + 0.8)), mask = MASK_SOLID_BRUSHONLY })
	if top.Hit then return false end
	local c = g + UP * (R * RMPG.ShapeBottom)
	if bit.band(util.PointContents(c), CONTENTS_SOLID) ~= 0 then return false end
	local right = fwd:Cross(UP)
	for _, s in ipairs({ 1, -1 }) do
		local tr = util.TraceLine({ start = c, endpos = c + right * (s * R * 0.7), mask = MASK_SOLID_BRUSHONLY })
		if tr.Hit then return false end
	end
	return true
end

function RMPG.OpenDirection(g)
	local best, bestF = Vector(1, 0, 0), -1
	local off = math.random() * 360
	for i = 0, 7 do
		local dir = Angle(0, off + i * 45, 0):Forward()
		local s = g + UP * 40
		local tr = util.TraceLine({ start = s, endpos = s + dir * 800, mask = MASK_PLAYERSOLID_BRUSHONLY })
		if tr.Fraction > bestF then best, bestF = dir, tr.Fraction end
	end
	return best
end

-- About 10 steps from the target; if there is no room, practically point-blank
function RMPG.FindNearPlayer(t)
	local tp = t:GetPos()
	local eyeYaw = t:EyeAngles().y
	local base = RMPG.CV.findDist:GetFloat()
	for _, k in ipairs({ 1, 0.8, 0.6, 0.45, 0.3 }) do
		local d = base * k
		for i = 0, 15 do
			-- start in front of the target and alternate left / right
			local yaw = eyeYaw + (i % 2 == 0 and 1 or -1) * math.ceil(i / 2) * 22.5
			local dir = Angle(0, yaw, 0):Forward()
			local probe = tp + dir * d + UP * 36
			local los = util.TraceLine({ start = tp + UP * 36, endpos = probe, mask = MASK_SOLID_BRUSHONLY })
			if not los.Hit then
				local g = RMPG.GroundBelow(probe, 160)
				if g and math.abs(g.z - tp.z) < 120 then
					local face = tp - g
					face.z = 0
					face:Normalize()
					if RMPG.SpotOK(g, face, t) then return g, face end
				end
			end
		end
	end
	for _, d in ipairs({ 72, 60 }) do
		for i = 0, 7 do
			local dir = Angle(0, eyeYaw + i * 45, 0):Forward()
			local g = RMPG.GroundBelow(tp + dir * d + UP * 30, 100) or (tp + dir * d)
			local face = -dir
			if RMPG.HullFree(g + face * 22) then return g, face end
		end
	end
	local dir = Angle(0, eyeYaw, 0):Forward()
	return tp + dir * 60, -dir
end

local skyCams
local function NearSkybox(p)
	skyCams = skyCams or ents.FindByClass("sky_camera")
	for _, e in ipairs(skyCams) do
		if IsValid(e) and e:GetPos():DistToSqr(p) < 2500 * 2500 then return true end
	end
	return false
end

local mapMins, mapMaxs
local function MapBounds()
	if mapMins then return mapMins, mapMaxs end
	local ok, mins, maxs = pcall(function() return game.GetWorld():GetModelBounds() end)
	if not ok or not isvector(mins) or not isvector(maxs) or (maxs - mins):Length() < 512 then
		mins, maxs = Vector(-16000, -16000, -16000), Vector(16000, 16000, 16000)
	end
	mapMins, mapMaxs = mins, maxs
	return mins, maxs
end

-- One random try: a navmesh area if the map has one, otherwise a random point inside the map
local navAreas
local function RandomAttempt()
	local g
	navAreas = navAreas or navmesh.GetAllNavAreas() or {}
	if #navAreas > 0 and math.random() < 0.8 then
		local a = navAreas[math.random(#navAreas)]
		if a:GetSizeX() >= 40 and a:GetSizeY() >= 40 and not a:IsUnderwater() then g = a:GetRandomPoint() end
	else
		local mins, maxs = MapBounds()
		local p = Vector(math.Rand(mins.x, maxs.x), math.Rand(mins.y, maxs.y), math.Rand(mins.z, maxs.z))
		if util.IsInWorld(p) then
			local hit, tr = RMPG.GroundBelow(p, 4096)
			if hit and tr.HitWorld and not tr.HitNoDraw and tr.HitNormal.z > 0.7 then g = hit end
		end
	end
	if not g or NearSkybox(g) then return nil end
	if bit.band(util.PointContents(g + UP * 16), CONTENTS_WATER) ~= 0 then return nil end
	local fwd = RMPG.OpenDirection(g)
	if not RMPG.SpotOK(g, fwd) then return nil end
	return g, fwd
end

-- Free spots are collected a few at a time in the background, so a "random" shot never stalls the server
RMPG.SpotPool = RMPG.SpotPool or {}
hook.Add("Think", "rmpg_spot_pool", function()
	local pool = RMPG.SpotPool
	if #pool >= 40 then return end
	for _ = 1, 4 do
		local g, fwd = RandomAttempt()
		if g then pool[#pool + 1] = { g, fwd } end
	end
end)

function RMPG.RandomSpot(ply)
	local from = IsValid(ply) and ply:GetPos() or vector_origin
	local pool = RMPG.SpotPool
	local start = math.random(math.max(#pool, 1))
	for k = 0, #pool - 1 do
		local i = (start + k - 1) % #pool + 1
		local spot = pool[i]
		if spot[1]:DistToSqr(from) > 600 * 600 then
			table.remove(pool, i)
			if RMPG.SpotOK(spot[1], spot[2]) then return spot[1], spot[2] end
			break
		end
	end
	for _ = 1, 60 do
		local g, fwd = RandomAttempt()
		if g and g:DistToSqr(from) > 600 * 600 then return g, fwd end
	end
	local spawns = {}
	for _, c in ipairs({ "info_player_start", "info_player_deathmatch", "info_player_combine",
		"info_player_rebel", "info_player_terrorist", "info_player_counterterrorist" }) do
		table.Add(spawns, ents.FindByClass(c))
	end
	if #spawns > 0 then
		local g = spawns[math.random(#spawns)]:GetPos()
		return g, RMPG.OpenDirection(g)
	end
end

-- Returns the exit portal position/angle for the player's chosen destination
function RMPG.ResolveExit(ply, dest)
	if dest.mode == RMPG.DEST_LOCATION then
		if not dest.pos then return nil, nil, "n_no_location" end
		local fwd = Angle(0, dest.yaw or 0, 0):Forward()
		local ground = RMPG.GroundBelow(dest.pos + UP * 24, 200) or dest.pos
		local c, a = RMPG.UprightPortal(ground - fwd * 22, fwd)
		return c, a
	elseif dest.mode == RMPG.DEST_PLAYER then
		local t = dest.target
		if not IsValid(t) or not t:IsPlayer() or t == ply then return nil, nil, "n_no_target" end
		if not t:Alive() then return nil, nil, "n_target_gone" end
		local g, face = RMPG.FindNearPlayer(t)
		local c, a = RMPG.UprightPortal(g, face)
		return c, a
	elseif dest.mode == RMPG.DEST_COORDS then
		-- the portal's middle exactly where it was typed, turned as it was set
		local pos = dest.pos
		if not pos or not util.IsInWorld(pos) then return nil, nil, "n_coords_bad" end
		if bit.band(util.PointContents(pos), CONTENTS_SOLID) ~= 0 then return nil, nil, "n_coords_solid" end
		return pos, Angle(dest.pitch or 0, dest.yaw or 0, 0)
	end
	local g, fwd = RMPG.RandomSpot(ply)
	if not g then return nil, nil, "n_random_fail" end
	local c, a = RMPG.UprightPortal(g, fwd)
	return c, a
end

---------------------------------------------------------------------------
-- Firing
---------------------------------------------------------------------------

local function ShotFX(wep, hitPos, col)
	net.Start("rmpg_fx")
	net.WriteEntity(wep)
	net.WriteVector(hitPos)
	net.WriteVector(col)
	net.Broadcast()
end

-- Replace the player's own portals that overlap a new one
local function ClearOverlap(ply, pos)
	local R = RMPG.Radius()
	for _, p in ipairs(ents.FindByClass("rmpg_portal")) do
		if p:GetOwnerPlayer() == ply and p:GetCloseTime() == 0 and p:GetPos():DistToSqr(pos) < (R * 1.4) ^ 2 then
			p:Close()
		end
	end
end

-- Upright portal right next to the player (Quick Portal)
local function NearPlayerPortal(ply)
	local c, a = RMPG.FrontPlacement(ply)
	if c then return c, a end
	-- a wall right in front: open it behind the player instead
	local _, fwd = RMPG.Aim(ply)
	if RMPG.BootsOn(ply) then
		local up = RMPG.BootsUp(ply)
		fwd = (fwd - up * fwd:Dot(up)):GetNormalized()
		local behind = RMPG.BootsFeet(ply, up) - fwd * 80
		return behind + up * (RMPG.Radius() * RMPG.ShapeBottom - 4), fwd:AngleEx(up)
	end
	fwd.z = 0
	fwd:Normalize()
	local g = RMPG.GroundBelow(ply:GetPos() - fwd * 80 + UP * 30, 200, ply) or (ply:GetPos() - fwd * 80)
	return RMPG.UprightPortal(g, fwd)
end

function RMPG.FireGun(ply, wep, quick)
	local col = wep:GetFluidColor()
	local core = wep:GetCore()
	local R = RMPG.Radius()
	local dest = ply.RMPG_Dest or { mode = RMPG.DEST_RANDOM }

	if not quick and dest.mode == RMPG.DEST_TRAP then
		local pos = RMPG.OpenTrap(ply, col, core)
		if pos then ShotFX(wep, pos, col) end
		return pos ~= nil
	end

	if not quick and dest.mode == RMPG.DEST_MAP then
		local pos = RMPG.OpenMapPortal(ply, col, core, dest)
		if pos then ShotFX(wep, pos, col) end
		return pos ~= nil
	end

	if quick or dest.mode == RMPG.DEST_QUICK then
		-- exit where the player aims, entrance right next to them
		local xPos, xAng, xFree = RMPG.SurfacePlacement(ply)
		if not xPos then return false end
		local nPos, nAng = NearPlayerPortal(ply)
		if xPos:DistToSqr(nPos) < (R * 2.2) ^ 2 then
			RMPG.Notify(ply, "n_too_close", nil, 1)
			return false
		end
		ClearOverlap(ply, nPos)
		ClearOverlap(ply, xPos)
		ShotFX(wep, xPos, col)
		local A = RMPG.SpawnPortal(ply, nPos, nAng, col, true, core)
		local B = RMPG.SpawnPortal(ply, xPos, xAng, col, xFree, core)
		if not IsValid(A) or not IsValid(B) then
			SafeRemoveEntity(A)
			SafeRemoveEntity(B)
			return false
		end
		RMPG.LinkPair(ply, A, B)
		return true
	end

	local vertical = ply:GetInfoNum("rmpg_vertical_front", 0) == 1
	local ePos, eAng, eFree = RMPG.ComputeEntry(ply, vertical)
	if not ePos then return false end

	if dest.mode == RMPG.DEST_CHAIN then
		ClearOverlap(ply, ePos)
		ShotFX(wep, ePos, col)
		local p = RMPG.SpawnPortal(ply, ePos, eAng, col, eFree, core)
		if not IsValid(p) then return false end
		RMPG.ChainAdd(ply, p)
		return true
	end

	if dest.mode == RMPG.DEST_MANUAL then
		local A = ply.RMPG_PendingA
		if IsValid(A) and A:GetCloseTime() == 0 then
			if A:GetPos():DistToSqr(ePos) < (R * 1.8) ^ 2 then
				RMPG.Notify(ply, "n_too_close", nil, 1)
				return false
			end
			ShotFX(wep, ePos, col)
			local B = RMPG.SpawnPortal(ply, ePos, eAng, col, eFree, core)
			if not IsValid(B) then return false end
			RMPG.LinkPair(ply, A, B)
			ply.RMPG_PendingA = nil
		else
			ClearOverlap(ply, ePos)
			ShotFX(wep, ePos, col)
			ply.RMPG_PendingA = RMPG.SpawnPortal(ply, ePos, eAng, col, eFree, core)
			RMPG.Notify(ply, "n_manual_a", nil, 0)
		end
		return true
	end

	local xPos, xAng, err = RMPG.ResolveExit(ply, dest)
	if not xPos then
		RMPG.Notify(ply, err or "n_random_fail", nil, 1)
		return false
	end
	if xPos:DistToSqr(ePos) < (R * 2.2) ^ 2 then
		RMPG.Notify(ply, "n_too_close", nil, 1)
		return false
	end
	ClearOverlap(ply, ePos)
	ShotFX(wep, ePos, col)
	local A = RMPG.SpawnPortal(ply, ePos, eAng, col, eFree, core)
	local B = RMPG.SpawnPortal(ply, xPos, xAng, col, true, core)
	if not IsValid(A) or not IsValid(B) then
		SafeRemoveEntity(A)
		SafeRemoveEntity(B)
		return false
	end
	RMPG.LinkPair(ply, A, B)
	return true
end

---------------------------------------------------------------------------
-- Destination labels shown on the gun
---------------------------------------------------------------------------

function RMPG.ApplyDestLabel(ply, wep)
	wep = wep or ply:GetWeapon(RMPG.WEAPON)
	if not IsValid(wep) then return end
	local d = ply.RMPG_Dest or { mode = RMPG.DEST_RANDOM }
	wep:SetDestMode(d.mode)
	if d.mode == RMPG.DEST_LOCATION then
		wep:SetDestLabel(d.name or "?")
		wep:SetDestCode(d.code or "C-137")
	elseif d.mode == RMPG.DEST_PLAYER then
		wep:SetDestLabel("@" .. (IsValid(d.target) and d.target:Nick() or "?"))
		wep:SetDestCode("P-" .. string.format("%02d", IsValid(d.target) and d.target:EntIndex() or 0))
	elseif d.mode == RMPG.DEST_MANUAL then
		wep:SetDestLabel("#dest_manual")
		wep:SetDestCode("A-B")
	elseif d.mode == RMPG.DEST_QUICK then
		wep:SetDestLabel("#dest_quick")
		wep:SetDestCode("Q-P")
	elseif d.mode == RMPG.DEST_TRAP then
		wep:SetDestLabel("#dest_trap")
		wep:SetDestCode("TRAP")
	elseif d.mode == RMPG.DEST_CHAIN then
		wep:SetDestLabel("#dest_chain")
		wep:SetDestCode("CHAIN")
	elseif d.mode == RMPG.DEST_COORDS then
		local p = d.pos or vector_origin
		wep:SetDestLabel(string.format("%d %d %d", math.Round(p.x), math.Round(p.y), math.Round(p.z)))
		wep:SetDestCode("XYZ")
	elseif d.mode == RMPG.DEST_MAP then
		wep:SetDestLabel(d.map or "?")
		wep:SetDestCode("MAP")
	else
		wep:SetDestLabel("#dest_random")
		wep:SetDestCode("???")
	end
end

---------------------------------------------------------------------------
-- Self-destruct and vaporising
---------------------------------------------------------------------------

local ENT_META = FindMetaTable("Entity")

function RMPG.Dissolve(ent, origin)
	if not IsValid(ent) then return end
	if ENT_META.Dissolve then
		local ok = pcall(ENT_META.Dissolve, ent, 0, 0, origin or ent:GetPos())
		if ok then return end
	end
	local name = "rmpg_dis_" .. ent:EntIndex() .. "_" .. math.floor(CurTime() * 100)
	ent:SetName(name)
	local d = ents.Create("env_entity_dissolver")
	if not IsValid(d) then SafeRemoveEntity(ent) return end
	d:SetKeyValue("dissolvetype", "0")
	d:SetKeyValue("magnitude", "0")
	d:SetPos(ent:GetPos())
	d:Spawn()
	d:Fire("Dissolve", name, 0)
	d:Fire("Kill", "", 0.2)
end

function RMPG.Vaporize(ent, attacker, inflictor, origin)
	if not IsValid(ent) or ent.RMPG_Vaporized then return end
	attacker = IsValid(attacker) and attacker or game.GetWorld()
	inflictor = IsValid(inflictor) and inflictor or attacker

	if ent:IsPlayer() then
		if ent:HasGodMode() or not ent:Alive() then return end
		ent.RMPG_Vaporized = true
		timer.Simple(1, function() if IsValid(ent) then ent.RMPG_Vaporized = nil end end)
		ent:EmitSound(RMPG.SND.zap, 80, math.random(90, 115))
		-- a dissolving copy of the body replaces the normal corpse
		local rag = ents.Create("prop_ragdoll")
		if IsValid(rag) then
			rag:SetModel(ent:GetModel())
			rag:SetPos(ent:GetPos())
			rag:SetAngles(Angle(0, ent:EyeAngles().y, 0))
			rag:SetSkin(ent:GetSkin())
			for _, bg in ipairs(ent:GetBodyGroups() or {}) do rag:SetBodygroup(bg.id, ent:GetBodygroup(bg.id)) end
			rag:Spawn()
			rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			for i = 0, rag:GetPhysicsObjectCount() - 1 do
				local po = rag:GetPhysicsObjectNum(i)
				local bone = rag:TranslatePhysBoneToBone(i)
				local m = bone and ent:GetBoneMatrix(bone)
				if IsValid(po) and m then
					po:SetPos(m:GetTranslation())
					po:SetAngles(m:GetAngles())
					po:SetVelocity(ent:GetVelocity())
				end
			end
			RMPG.Dissolve(rag, origin)
		end
		ent:SetNW2Float("RMPG_Vapor", CurTime())
		local dmg = DamageInfo()
		dmg:SetDamage(ent:Health() + ent:Armor() + 1000)
		dmg:SetDamageType(DMG_DISSOLVE)
		dmg:SetAttacker(attacker)
		dmg:SetInflictor(inflictor)
		dmg:SetDamagePosition(origin or ent:GetPos())
		ent:TakeDamageInfo(dmg)
		if ent:Alive() then ent:Kill() end
		return
	end

	ent.RMPG_Vaporized = true
	ent:EmitSound(RMPG.SND.zap, 75, math.random(90, 120))
	if ent:IsNPC() or ent:IsNextBot() then
		local dmg = DamageInfo()
		dmg:SetDamage(ent:Health() + 1000)
		dmg:SetDamageType(DMG_DISSOLVE)
		dmg:SetAttacker(attacker)
		dmg:SetInflictor(inflictor)
		dmg:SetDamagePosition(origin or ent:GetPos())
		ent:TakeDamageInfo(dmg)
		timer.Simple(0, function()
			if IsValid(ent) and ent:Health() > 0 then RMPG.Dissolve(ent, origin) end
		end)
		return
	end
	RMPG.Dissolve(ent, origin)
end

function RMPG.SelfDestruct(ply)
	local wep = ply:GetWeapon(RMPG.WEAPON)
	if not IsValid(wep) or wep.RMPG_Melting then return end
	wep.RMPG_Melting = true
	local start = ply:GetShootPos()
	local dir = ply:GetAimVector()
	dir.z = 0
	dir:Normalize()
	local tr = util.TraceLine({ start = start, endpos = start + dir * 50 - UP * 14, filter = ply, mask = MASK_SOLID_BRUSHONLY })
	local pos = tr.Hit and (tr.HitPos - dir * 12) or tr.HitPos
	local m = ents.Create("rmpg_meltdown")
	if not IsValid(m) then wep.RMPG_Melting = nil return end
	m:SetPos(pos)
	m:SetAngles(Angle(0, ply:EyeAngles().y, 0))
	m:SetFluidColor(wep:GetFluidColor())
	m:SetCore(wep:GetCore())
	m:SetVariant(wep:GetVariant())
	m:SetBodyColor(wep:GetBodyColor())
	m:SetInstigator(ply)
	m:Spawn()
	ply:StripWeapon(RMPG.WEAPON)
	RMPG.Notify(ply, "n_sd_start", nil, 3)
end
