-- Server: portals to another map, a mode of the portal gun. Who may open one is a server setting
-- (rmpg_maptravel_everyone: superadmins only, or everyone). They pick a map from the server's own list and fire: one
-- portal opens where they aim. When the one who opened it walks in, the map changes at once if nobody else is on the
-- server; otherwise a countdown of rmpg_maptravel_wait seconds starts, and everyone who walks in waits inside with them - hidden, held still and unhurt - and can step back out with a
-- button. At zero the server changes map, and on the new map whoever was inside comes out of one portal together.
-- The game moves every player to the new map; the ones who stayed outside simply appear where they always do.
-- The screen inside and the map list are in cl_maptravel.lua.
RMPG = RMPG or {}

util.AddNetworkString("rmpg_maps")    -- client asks for the list, the server sends it
util.AddNetworkString("rmpg_mapstep") -- client: step back out of the portal

local FILE = "rmpg/maptrip.txt"
local UP = Vector(0, 0, 1)
local trip -- { portal, owner, map, ends (0 until the owner is inside), inside = { [ply] = saved state } }

function RMPG.MapTravelAllowed(ply)
	return IsValid(ply) and ply:IsPlayer() and (ply:IsSuperAdmin() or RMPG.CV.mapEveryone:GetBool())
end

local function NotifyAll(key, args, kind)
	for _, p in ipairs(player.GetHumans()) do RMPG.Notify(p, key, args, kind) end
end

local function Id(ply)
	return ply:IsBot() and ("BOT_" .. ply:Nick()) or ply:SteamID64()
end

---------------------------------------------------------------------------
-- The list of maps the server has
---------------------------------------------------------------------------

local HIDE = { "^background", "_background", "^devtest", "^test_", "^styleguide", "^credits", "^sdk_", "^lobby", "^c4a1y" }

local function MapList()
	local out = {}
	for _, f in ipairs(file.Find("maps/*.bsp", "GAME")) do
		local name = string.StripExtension(f)
		local hidden = false
		for _, pat in ipairs(HIDE) do
			if string.find(name, pat) then hidden = true break end
		end
		if not hidden then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

net.Receive("rmpg_maps", function(_, ply)
	if (ply.RMPG_MapsAsked or 0) > CurTime() then return end
	ply.RMPG_MapsAsked = CurTime() + 2
	local list = MapList()
	local n = math.min(#list, 2000)
	net.Start("rmpg_maps")
	net.WriteBool(RMPG.MapTravelAllowed(ply))
	net.WriteString(game.GetMap())
	net.WriteUInt(n, 12)
	for i = 1, n do net.WriteString(list[i]) end
	net.Send(ply)
end)

---------------------------------------------------------------------------
-- Inside the portal
---------------------------------------------------------------------------

local function Hide(ply, on)
	ply:SetNoDraw(on)
	ply:SetNotSolid(on)
	ply:DrawViewModel(not on)
	ply:DrawWorldModel(not on)
	ply:Freeze(on)
	if on then ply:SetVelocity(-ply:GetVelocity()) end
end

local function Publish()
	if not trip then
		SetGlobal2String("RMPG_MapTrip", "")
		SetGlobal2Float("RMPG_MapTripEnds", 0)
		SetGlobal2Int("RMPG_MapTripIn", 0)
		return
	end
	local n = 0
	for ply in pairs(trip.inside) do
		if IsValid(ply) then n = n + 1 end
	end
	SetGlobal2String("RMPG_MapTrip", trip.map)
	SetGlobal2Float("RMPG_MapTripEnds", trip.ends)
	SetGlobal2Int("RMPG_MapTripIn", n)
	SetGlobal2Entity("RMPG_MapTripOwner", IsValid(trip.owner) and trip.owner or NULL)
end

local function GoOut(ply, quiet)
	if not trip or not trip.inside[ply] then return end
	local saved = trip.inside[ply]
	trip.inside[ply] = nil
	if not IsValid(ply) then return end
	ply:SetNW2Entity("RMPG_InMapPortal", NULL)
	ply:SetNW2Bool("RMPG_InMapTrip", false)
	Hide(ply, false)
	if not saved.god then ply:GodDisable() end
	if ply:Alive() and IsValid(trip.portal) then
		-- out the way one comes out of any portal, facing away from it
		ply.RMPG_NextTP = 0
		RMPG.Teleport(ply, trip.portal, trip.portal)
	end
	if not quiet then ply:EmitSound(RMPG.SND.enter, 70, 90) end
	Publish()
end

local function EndTrip(key)
	if not trip then return end
	local t = trip
	for ply in pairs(t.inside) do GoOut(ply, true) end
	if IsValid(t.portal) then
		t.portal.RMPG_MapPortal = nil
		t.portal:Close()
	end
	if key and key ~= "" then NotifyAll(key, { t.map }, 1) end
	trip = nil
	Publish()
end

local Depart -- below; GoIn may need it at once

local function GoIn(ply)
	if trip.inside[ply] then return end
	trip.inside[ply] = { god = ply:HasGodMode() }
	ply:GodEnable()
	Hide(ply, true)
	ply:SetNW2Entity("RMPG_InMapPortal", trip.portal)
	ply:SetNW2Bool("RMPG_InMapTrip", true)
	trip.portal:EmitSound(RMPG.SND.enter, 75, math.random(95, 105))
	local ed = EffectData()
	ed:SetOrigin(ply:WorldSpaceCenter())
	ed:SetNormal(trip.portal:GetForward())
	ed:SetStart(trip.portal:GetPortalColor())
	ed:SetScale(1)
	util.Effect("rmpg_burst", ed, true, true)
	if ply == trip.owner and trip.ends == 0 then
		-- alone on the server there is nobody to wait for: the map changes now
		if #player.GetHumans() <= 1 then
			trip.ends = CurTime()
			trip.portal:SetNW2Float("RMPG_MapEnds", trip.ends)
			Publish()
			Depart()
			return
		end
		local wait = RMPG.CV.mapWait:GetFloat()
		trip.ends = CurTime() + wait
		trip.portal.DieTime = trip.ends + 10
		trip.portal:SetNW2Float("RMPG_MapEnds", trip.ends)
		NotifyAll("n_map_trip", { ply:Nick(), trip.map, math.floor(wait) }, 2)
	end
	Publish()
end

-- The one allowed to fires: a portal where they aim, waiting for them to go in
function RMPG.OpenMapPortal(ply, col, core, dest)
	if not RMPG.MapTravelAllowed(ply) then
		RMPG.Notify(ply, "n_map_denied", nil, 1)
		return
	end
	local map = dest.map
	if not map or not file.Exists("maps/" .. map .. ".bsp", "GAME") then
		RMPG.Notify(ply, "n_map_missing", { map or "?" }, 1)
		return
	end
	if trip and IsValid(trip.portal) then
		if trip.owner ~= ply or trip.ends > 0 then
			RMPG.Notify(ply, "n_map_busy", nil, 1)
			return
		end
		EndTrip() -- their own portal that nobody is waiting in yet: it moves
	end
	local pos, ang, free = RMPG.SurfacePlacement(ply)
	if not pos then return end
	local p = RMPG.SpawnPortal(ply, pos, ang, col, free, core)
	if not IsValid(p) then return end
	p.DieTime = CurTime() + 120 -- it waits two minutes for its opener
	p.RMPG_MapPortal = true
	p:SetNW2String("RMPG_MapTo", map)
	p:SetNW2Float("RMPG_MapEnds", 0)
	trip = { portal = p, owner = ply, map = map, ends = 0, inside = {} }
	Publish()
	RMPG.Notify(ply, "n_map_open", { map }, 0)
	return pos
end

Depart = function()
	local t = trip
	local ids = {}
	for ply in pairs(t.inside) do
		if IsValid(ply) then ids[#ids + 1] = Id(ply) end
	end
	file.CreateDir("rmpg")
	file.Write(FILE, util.TableToJSON({ map = t.map, from = game.GetMap(), time = os.time(), ids = ids }))
	NotifyAll("n_map_go", { t.map }, 2)
	for _, p in ipairs(player.GetHumans()) do p:ScreenFade(SCREENFADE.OUT, Color(255, 255, 255), 1.2, 3) end
	t.departing = true
	timer.Simple(1.3, function()
		if trip ~= t then return end
		RunConsoleCommand("changelevel", t.map)
	end)
end

-- The close-portals button of the one who opened it takes it down too, while nobody is on the way yet
function RMPG.MapTripClose(ply)
	if trip and trip.owner == ply and not trip.departing then EndTrip("n_map_cancel") end
end

net.Receive("rmpg_mapstep", function(_, ply)
	if not trip or not trip.inside[ply] or trip.departing then return end
	if ply == trip.owner then
		-- without the one who opened it nobody goes anywhere
		EndTrip("n_map_cancel")
	else
		GoOut(ply)
	end
end)

local nextThink = 0
hook.Add("Think", "rmpg_maptravel", function()
	if not trip then return end
	local now = CurTime()
	if now < nextThink then return end
	nextThink = now + 0.05
	local p = trip.portal
	if trip.departing then
		-- the map should have changed by now; if it did not, everyone comes back out
		if now > trip.ends + 8 then EndTrip("n_map_cancel") end
		return
	end
	if not IsValid(p) or p:GetCloseTime() > 0 then
		EndTrip("n_map_cancel")
		return
	end
	if not IsValid(trip.owner) then
		EndTrip("n_map_cancel")
		return
	end
	if trip.ends > 0 and now >= trip.ends then
		Depart()
		return
	end
	-- walking into it
	local s = p:OpenScale()
	if s < 0.6 then return end
	local center, ang = p:GetPos(), p:GetAngles()
	local half = p:GetRadius() * s
	local frame = RMPG.ShapeFrame(now)
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and not trip.inside[ply] and not ply:InVehicle() and ply:GetPos():DistToSqr(center) < (half + 160) ^ 2
			and ply.RMPG_IgnorePortal ~= p and RMPG.TouchesPortal(ply, center, ang, half, frame, 4, 1.06) then
			GoIn(ply)
		elseif ply.RMPG_IgnorePortal == p and not RMPG.TouchesPortal(ply, center, ang, half, frame, 4, 1.06) and now > (ply.RMPG_IgnoreUntil or 0) then
			ply.RMPG_IgnorePortal = nil
		end
	end
	-- whoever died or left while inside is out of it
	for ply in pairs(trip.inside) do
		if not IsValid(ply) or not ply:Alive() then GoOut(ply, true) end
	end
end)

hook.Add("PlayerDisconnected", "rmpg_maptravel", function(ply)
	if trip and trip.inside[ply] then trip.inside[ply] = nil Publish() end
end)

-- Nothing hurts or moves you while you wait inside
hook.Add("PlayerShouldTakeDamage", "rmpg_maptravel", function(ply)
	if trip and trip.inside[ply] then return false end
end)

---------------------------------------------------------------------------
-- The new map: the ones who were inside come out of one portal together
---------------------------------------------------------------------------

local arrival -- { ids = set, untilT, portal }

hook.Add("InitPostEntity", "rmpg_maptravel", function()
	local raw = file.Read(FILE, "DATA")
	if not raw then return end
	file.Delete(FILE)
	local t = util.JSONToTable(raw)
	if not istable(t) or t.map ~= game.GetMap() or math.abs(os.time() - (tonumber(t.time) or 0)) > 900 then return end
	arrival = { ids = {}, untilT = CurTime() + 300 }
	for _, id in ipairs(t.ids or {}) do arrival.ids[tostring(id)] = true end
end)

local function ArrivalPortal(ply)
	local p = arrival.portal
	if IsValid(p) and p:GetCloseTime() == 0 then
		p.DieTime = CurTime() + 20
		return p
	end
	local g = ply:GetPos()
	local fwd = RMPG.OpenDirection(g)
	local c, a = RMPG.UprightPortal(g, fwd)
	if not c then return end
	p = RMPG.SpawnPortal(ply, c, a, RMPG.DEFAULT_COLOR, true, false)
	if not IsValid(p) then return end
	p.DieTime = CurTime() + 20
	arrival.portal = p
	return p
end

local function Arrive(ply)
	local p = ArrivalPortal(ply)
	if not IsValid(p) then return end
	-- a moment for the portal to open, then out they come
	timer.Simple(0.6, function()
		if not IsValid(ply) or not ply:Alive() or not IsValid(p) then return end
		ply.RMPG_NextTP = 0
		RMPG.Teleport(ply, p, p)
		RMPG.Notify(ply, "n_map_arrived", nil, 2)
	end)
end

hook.Add("PlayerSpawn", "rmpg_maptravel", function(ply)
	if not arrival or CurTime() > arrival.untilT then return end
	local id = Id(ply)
	if not arrival.ids[id] then return end
	arrival.ids[id] = nil
	timer.Simple(0.3, function()
		if IsValid(ply) and ply:Alive() then Arrive(ply) end
	end)
end)
