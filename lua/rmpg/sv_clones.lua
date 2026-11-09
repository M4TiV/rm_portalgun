-- Server: visitors from other dimensions. Now and then (rmpg_clone_chance percent a minute for each player) a copy
-- of that player steps out of a green portal next to them - announced like a player joining and listed in TAB - and
-- either hunts them or brings a present. The "joined / left the game" lines are printed by the game itself, the same
-- way it prints them for real players, and the copy comes through a few seconds after "joining", like a real player
-- loading in. "event 01 [count]" in the console calls them (admins); with a count above
-- one the others are copies of other players on the server. Up to rmpg_clone_max at once.
RMPG = RMPG or {}

util.AddNetworkString("rmpg_clone_ev")

local UP = Vector(0, 0, 1)
local HULL_MIN, HULL_MAX = Vector(-16, -16, 0), Vector(16, 16, 72)
local EV_JOIN, EV_LEAVE, EV_DIE, EV_FRAG, EV_SAY = 1, 2, 3, 4, 5
local LOADING = 4 -- seconds between "joined the game" and the portal

RMPG.CLONE_GIFTS = { "item_healthkit", "item_battery", "weapon_rmpg_pill", "weapon_rmpg_laser", "weapon_shotgun",
	"weapon_357", "weapon_crossbow", "item_ammo_smg1_grenade", "weapon_frag" }
RMPG.Clones = RMPG.Clones or {} -- id -> { name, source, team, kills, deaths }
local nextID = 0

local function Send(ev, id, write, to)
	net.Start("rmpg_clone_ev")
	net.WriteUInt(ev, 3)
	net.WriteUInt(id, 16)
	if write then write() end
	if to then net.Send(to) else net.Broadcast() end
end

local function WriteJoin(info)
	return function()
		net.WriteString(info.name)
		net.WriteEntity(IsValid(info.source) and info.source or NULL)
		net.WriteUInt(info.team, 16)
		net.WriteUInt(info.kills, 12)
		net.WriteUInt(info.deaths, 12)
	end
end

-- A line in everyone's chat printed by the game itself - the way it prints a real player joining or leaving
local function SystemLine(text)
	PrintMessage(HUD_PRINTTALK, text)
end

-- "Player X has joined the game" and a row in TAB; returns the visitor's id
local function Announce(src)
	nextID = nextID % 60000 + 1
	local info = { name = RMPG.PersonName(src), source = src, team = IsValid(src) and src:IsPlayer() and src:Team() or TEAM_UNASSIGNED, kills = 0, deaths = 0 }
	RMPG.Clones[nextID] = info
	SystemLine("Player " .. info.name .. " has joined the game")
	Send(EV_JOIN, nextID, WriteJoin(info))
	return nextID
end

-- A copy that came some other way (the spawn menu) joins on the spot
function RMPG.CloneJoined(clone)
	clone:SetCloneID(Announce(clone:GetSource()))
end

---------------------------------------------------------------------------
-- Lambda Players (https://github.com/IcyStarFrost/Lambda-Players), when that addon is installed: nothing below needs it.
-- Lambda Players count as people: visitors copy them and come for them, and with rmpg_clone_lambda on a visitor itself
-- comes through the portal as a Lambda Player wearing the name, model and colours of the one it copies. Every call into
-- that addon is guarded, so if a later version of it changes, a normal visitor comes instead.
---------------------------------------------------------------------------

local LAMBDA = "npc_lambdaplayer"

function RMPG.LambdaInstalled()
	return scripted_ents.GetStored(LAMBDA) ~= nil
end

-- Lambda Players have no Nick(), and their colour is a network var of their own (GetPlayerColor is client only)
function RMPG.PersonName(e)
	if not IsValid(e) then return "Player" end
	if e.IsLambdaPlayer then return e.GetLambdaName and e:GetLambdaName() or "Lambda" end
	return e.Nick and e:Nick() or "Player"
end

function RMPG.PersonColor(e)
	local fallback = Vector(0.24, 0.34, 0.41)
	if not IsValid(e) then return fallback end
	if e.IsLambdaPlayer then return e.GetPlyColor and e:GetPlyColor() or fallback end
	return e.GetPlayerColor and e:GetPlayerColor() or fallback
end

function RMPG.PersonAlive(e)
	if not IsValid(e) then return false end
	if e.IsLambdaPlayer then return not e:GetIsDead() end
	return e:Alive()
end

-- Everyone who can be copied or visited
function RMPG.ClonePeople()
	local all = {}
	for _, p in ipairs(player.GetAll()) do
		if p:Alive() and not p.RMPG_Visit then all[#all + 1] = p end
	end
	if RMPG.LambdaInstalled() then
		for _, l in ipairs(ents.FindByClass(LAMBDA)) do
			if not l.RMPG_CloneID and RMPG.PersonAlive(l) then all[#all + 1] = l end
		end
	end
	return all
end

-- The name, model and colours of the one it copies. Lambda Players pick their own when they spawn, so it runs twice.
local function DressLambda(c, source, name)
	if not IsValid(c) then return end
	c:SetRespawn(false)
	c:SetLambdaName(name)
	if IsValid(source) then
		c:SetPlayerModel(source:GetModel(), true)
		c:SetSkin(source:GetSkin())
		for i = 0, source:GetNumBodyGroups() - 1 do c:SetBodygroup(i, source:GetBodygroup(i)) end
		c:SetPlyColor(RMPG.PersonColor(source))
	end
end

-- A chat line of its own, in the language of the one it came for (the server has none of its own)
local function LambdaLine(c, key, target)
	if not IsValid(c) or not c.Say then return end
	local ru = IsValid(target) and target:IsPlayer() and target:GetInfo("gmod_language") == "ru"
	c:Say((ru and RMPG.Lang.ru or RMPG.Lang.en)[key] or key)
end

-- Lambda Players come with their own row in TAB and their own chat, so the visitor's made-up row goes
local function BecomeLambda(c, id, source, target, hostile)
	local info = RMPG.Clones[id]
	info.lambda = true
	Send(EV_LEAVE, id)
	c.RMPG_CloneID = id
	c.GetCloneID = function() return id end
	if not hostile then c.RMPG_Friend = target end
	DressLambda(c, source, info.name)
	timer.Simple(0.3, function()
		DressLambda(c, source, info.name)
		if not IsValid(c) then return end
		if hostile and IsValid(target) then
			if c.SwitchToLethalWeapon then c:SwitchToLethalWeapon() end
			c:AttackTarget(target, true)
		end
		LambdaLine(c, hostile and "clone_hello_bad" or "clone_hello", target)
	end)
	timer.Simple(hostile and 120 or 60, function()
		if not IsValid(c) or c.Left or c:GetIsDead() then return end
		LambdaLine(c, "clone_bye", target)
		timer.Simple(1, function()
			if IsValid(c) and not c.Left then RMPG.CloneLeave(c) end
		end)
	end)
	if not hostile and IsValid(target) then
		-- the present is waiting by the portal
		local list = RMPG.CLONE_GIFTS
		local e = ents.Create(list[math.random(#list)])
		if IsValid(e) then
			e:SetPos(c:GetPos() + c:GetForward() * 40 + UP * 20)
			e:Spawn()
		end
	end
end

-- Spawns the visitor as a Lambda Player; false when that cannot be done, and a normal visitor comes
function RMPG.CloneAsLambda(id, source, target, hostile, pos, yaw)
	if not RMPG.CV.cloneLambda:GetBool() or not RMPG.LambdaInstalled() then return false end
	if hostile == nil then hostile = math.random() * 100 < RMPG.CV.cloneHostile:GetFloat() end
	local c = ents.Create(LAMBDA)
	if not IsValid(c) then return false end
	c.l_NoRandomModel = true
	c:SetPos(pos)
	c:SetAngles(Angle(0, yaw, 0))
	local ok, err = pcall(function()
		c:Spawn()
		c:Activate()
		BecomeLambda(c, id, source, target, hostile)
	end)
	if ok then return true end
	print("[rm_portalgun] a visitor could not come as a Lambda Player: " .. tostring(err))
	if IsValid(c) then c:Remove() end
	return false
end

-- The friendly one leaves the one it came for alone
hook.Add("LambdaCanTarget", "rmpg_clones", function(lambda, target)
	if lambda.RMPG_Friend == target then return true end
end)

hook.Add("LambdaOnKilled", "rmpg_clones", function(lambda, info)
	local a = info:GetAttacker()
	if IsValid(a) and a:GetClass() == "rmpg_clone" then RMPG.CloneFrag(a) end
	if lambda.RMPG_CloneID and not lambda.Left then RMPG.CloneDied(lambda, a) end
end)

-- A chat line from the copy (the clients translate the key)
function RMPG.CloneSay(clone, key)
	if not RMPG.Clones[clone:GetCloneID()] then return end
	Send(EV_SAY, clone:GetCloneID(), function() net.WriteString(key) end)
end

local function Gone(id)
	local info = RMPG.Clones[id]
	if not info then return end
	RMPG.Clones[id] = nil
	SystemLine("Player " .. info.name .. " left the game (Disconnect by user.)")
	Send(EV_LEAVE, id)
end

hook.Add("LambdaOnRemove", "rmpg_clones", function(lambda)
	if lambda.RMPG_CloneID and not lambda.Left then Gone(lambda.RMPG_CloneID) end
end)

-- A free-standing green portal on the ground facing dir, closed again after a moment
local function Portal(ground, dir)
	local center, ang = RMPG.UprightPortal(ground, dir)
	local p = RMPG.SpawnPortal(NULL, center, ang, RMPG.DEFAULT_COLOR, true)
	if IsValid(p) then timer.Simple(2.6, function() if IsValid(p) then p:Close() end end) end
	return p
end

-- Back through a portal: "left the game"
function RMPG.CloneLeave(clone)
	if clone.Left then return end
	clone.Left = true
	local fwd = clone:GetForward()
	Portal(clone:GetPos() + fwd * 30, -fwd)
	local ed = EffectData()
	ed:SetOrigin(clone:WorldSpaceCenter())
	ed:SetNormal(fwd)
	ed:SetStart(RMPG.DEFAULT_COLOR)
	ed:SetScale(1)
	util.Effect("rmpg_burst", ed, true, true)
	local id = clone:GetCloneID()
	timer.Simple(0.5, function()
		if IsValid(clone) then clone:Remove() end
		Gone(id)
	end)
end

-- Killed: the row turns red, and a few seconds later the copy "leaves" (it rage-quits)
function RMPG.CloneDied(clone, attacker)
	local id = clone:GetCloneID()
	local info = RMPG.Clones[id]
	clone.Left = true
	if not info then return end
	info.deaths = info.deaths + 1
	Send(EV_DIE, id)
	timer.Simple(4, function() Gone(id) end)
end

-- Removed some other way (undo, cleanup)
function RMPG.CloneGone(clone)
	Gone(clone:GetCloneID())
end

function RMPG.CloneFrag(clone)
	local info = RMPG.Clones[clone:GetCloneID()]
	if not info then return end
	info.kills = info.kills + 1
	Send(EV_FRAG, clone:GetCloneID())
end

-- A free spot a few steps from the player, behind them if possible, with a clear line to them
local function FindSpot(ply)
	local base = ply:GetPos()
	local yaw = ply:EyeAngles().y
	for _, dist in ipairs({ 220, 160, 300, 120 }) do
		for _, off in ipairs({ 180, 150, 210, 120, 240, 90, 270, 0 }) do
			local a = math.rad(yaw + off)
			local p = base + Vector(math.cos(a), math.sin(a), 0) * dist
			local down = util.TraceLine({ start = p + UP * 60, endpos = p - UP * 200, mask = MASK_PLAYERSOLID_BRUSHONLY })
			if down.Hit and not down.StartSolid then
				local g = down.HitPos + UP * 2
				local hull = util.TraceHull({ start = g, endpos = g, mins = HULL_MIN, maxs = HULL_MAX, mask = MASK_PLAYERSOLID })
				local see = util.TraceLine({ start = g + UP * 50, endpos = ply:WorldSpaceCenter(), filter = ply, mask = MASK_SOLID_BRUSHONLY })
				if not hull.Hit and not see.Hit then
					local face = base - g
					face.z = 0
					return g, face:GetNormalized()
				end
			end
		end
	end
end

-- A copy of source "joins the game" and a few seconds later steps out of a portal near target (hostile: true /
-- false / nil = by the server setting)
function RMPG.SpawnClone(target, source, hostile)
	if not RMPG.PersonAlive(target) then return false end
	if table.Count(RMPG.Clones) + RMPG.VisitBots() >= RMPG.CV.cloneMax:GetInt() then return false end
	if not FindSpot(target) then return false end
	source = IsValid(source) and source or target
	-- a real player bot when there is room for one: it joins the game the moment it steps out of the portal
	if RMPG.CanVisitBot() then
		timer.Simple(LOADING, function()
			local spot, face
			if RMPG.PersonAlive(target) then spot, face = FindSpot(target) end
			if not spot then return end
			Portal(spot - face * 24, face)
			timer.Simple(0.6, function()
				if RMPG.PersonAlive(target) and RMPG.CanVisitBot() then RMPG.SpawnVisitBot(target, source, hostile, spot, face:Angle().y) end
			end)
		end)
		return true
	end
	local id = Announce(source)
	timer.Simple(LOADING, function()
		-- the one it came for is gone or dead: it "leaves" again
		local spot, face
		if RMPG.PersonAlive(target) then spot, face = FindSpot(target) end
		if not spot then
			Gone(id)
			return
		end
		Portal(spot - face * 24, face)
		timer.Simple(0.6, function()
			if IsValid(target) and RMPG.Clones[id] and RMPG.CloneAsLambda(id, source, target, hostile, spot, face:Angle().y) then return end
			local c = IsValid(target) and RMPG.Clones[id] and ents.Create("rmpg_clone")
			if not IsValid(c) then
				Gone(id)
				return
			end
			c.SourcePly = IsValid(source) and source or target
			c.TargetPly = target
			c.ForceHostile = hostile
			c.PresetID = id
			c:SetPos(spot)
			c:SetAngles(Angle(0, face:Angle().y, 0))
			c:Spawn()
			c:Activate()
		end)
	end)
	return true
end

-- Now and then a copy drops by
timer.Create("rmpg_clone_event", 60, 0, function()
	local chance = RMPG.CV.cloneChance:GetFloat()
	if chance <= 0 then return end
	for _, ply in ipairs(RMPG.ClonePeople()) do
		if math.random() * 100 < chance then RMPG.SpawnClone(ply, ply) end
	end
end)

-- event 01 [count]: the visitors, now
local function EventCmd(ply, cmd, args)
	if IsValid(ply) and not ply:IsAdmin() then
		RMPG.Notify(ply, "n_noaccess", nil, 1)
		return
	end
	if tonumber(args[1] or "") ~= 1 then
		if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "event 01 [count] - visitors from other dimensions") end
		return
	end
	local all = RMPG.ClonePeople()
	local target = IsValid(ply) and ply or all[math.random(math.max(#all, 1))]
	if not IsValid(target) or #all == 0 then return end
	local count = math.Clamp(math.floor(tonumber(args[2] or "1") or 1), 1, RMPG.CV.cloneMax:GetInt())
	for i = 1, count do
		-- the first is your own copy, the rest copies of whoever is on the server
		local src = i == 1 and target or all[math.random(#all)]
		timer.Simple((i - 1) * 1.3, function() RMPG.SpawnClone(target, src) end)
	end
end
concommand.Add("event", EventCmd)
concommand.Add("rmpg_event", EventCmd)

-- Someone joining later sees the copies already here
hook.Add("PlayerInitialSpawn", "rmpg_clones", function(ply)
	timer.Simple(3, function()
		if not IsValid(ply) then return end
		for id, info in pairs(RMPG.Clones) do
			if not info.lambda then Send(EV_JOIN, id, WriteJoin(info), ply) end
		end
	end)
end)
