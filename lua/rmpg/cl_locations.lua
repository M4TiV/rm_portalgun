-- Client: saved locations (stored per map in data/rmpg/), sharing them with other players, destination requests
RMPG = RMPG or {}
RMPG.Locations = RMPG.Locations or {}

RMPG.SharedLocations = RMPG.SharedLocations or {} -- other players' locations you may use
RMPG.SharedVersion = RMPG.SharedVersion or 0
RMPG.Trusted = RMPG.Trusted or {}                 -- SteamID64 -> nick
RMPG.TrustsMe = RMPG.TrustsMe or {}               -- players that trust you

local function FilePath()
	return "rmpg/locations_" .. game.GetMap() .. ".json"
end

function RMPG.LoadLocations()
	file.CreateDir("rmpg")
	local raw = file.Read(FilePath(), "DATA")
	local t = raw and util.JSONToTable(raw) or {}
	RMPG.Locations = istable(t) and t or {}
end

function RMPG.SaveLocations()
	file.CreateDir("rmpg")
	file.Write(FilePath(), util.TableToJSON(RMPG.Locations, true))
end

function RMPG.LocPos(loc)
	return Vector(loc.x or 0, loc.y or 0, loc.z or 0)
end

function RMPG.AddLocation(name, pos, yaw)
	local n = #RMPG.Locations + 1
	if not name or string.Trim(name) == "" then name = RMPG.T("loc_default", n) end
	local loc = {
		name = string.sub(name, 1, 48),
		x = math.Round(pos.x, 1), y = math.Round(pos.y, 1), z = math.Round(pos.z, 1),
		yaw = math.Round(yaw, 1),
		code = RMPG.MakeCode(pos),
		time = os.time(),
		share = RMPG.SHARE_TRUSTED,
	}
	table.insert(RMPG.Locations, loc)
	RMPG.SaveLocations()
	RMPG.QueueShare()
	RMPG.AddNote(RMPG.T("n_location_saved", loc.name), 2)
	return loc
end

function RMPG.RemoveLocation(i)
	table.remove(RMPG.Locations, i)
	RMPG.SaveLocations()
	RMPG.QueueShare()
end

function RMPG.RenameLocation(i, name)
	local loc = RMPG.Locations[i]
	if not loc or string.Trim(name or "") == "" then return end
	loc.name = string.sub(name, 1, 48)
	RMPG.SaveLocations()
	RMPG.QueueShare()
end

---------------------------------------------------------------------------
-- Sharing: public locations and trusted players
---------------------------------------------------------------------------

-- Locations saved before sharing existed count as "for trusted players"
function RMPG.LocShare(loc)
	return loc.share or RMPG.SHARE_TRUSTED
end

function RMPG.SetLocationShare(i, v)
	local loc = RMPG.Locations[i]
	if not loc then return end
	loc.share = v
	RMPG.SaveLocations()
	RMPG.QueueShare()
	RMPG.AddNote(RMPG.T("n_loc_share", loc.name or "?", RMPG.T("loc_share_" .. v)), 0)
end

-- Tell the server which of our locations other players may use
function RMPG.SendShared()
	local list = {}
	for _, loc in ipairs(RMPG.Locations) do
		if RMPG.LocShare(loc) > 0 and #list < 64 then list[#list + 1] = loc end
	end
	net.Start("rmpg_share")
	net.WriteUInt(#list, 7)
	for _, loc in ipairs(list) do
		net.WriteString(loc.name or "")
		net.WriteString(loc.code or "")
		net.WriteVector(RMPG.LocPos(loc))
		net.WriteFloat(loc.yaw or 0)
		net.WriteUInt(RMPG.LocShare(loc), 2)
	end
	net.SendToServer()
end

function RMPG.QueueShare()
	timer.Create("rmpg_share_send", 0.4, 1, RMPG.SendShared)
end

function RMPG.PlayerKey(ply)
	return ply:SteamID64() or ("BOT" .. ply:UserID())
end

local TRUST_FILE = "rmpg/trusted.json"

function RMPG.LoadTrusted()
	local raw = file.Read(TRUST_FILE, "DATA")
	local t = raw and util.JSONToTable(raw) or {}
	RMPG.Trusted = istable(t) and t or {}
end

function RMPG.IsTrusted(ply)
	return IsValid(ply) and RMPG.Trusted[RMPG.PlayerKey(ply)] ~= nil
end

function RMPG.SendTrust()
	local keys = table.GetKeys(RMPG.Trusted)
	local n = math.min(#keys, 255)
	net.Start("rmpg_trust")
	net.WriteUInt(n, 8)
	for i = 1, n do net.WriteString(keys[i]) end
	net.SendToServer()
end

-- Trusted players can use your locations marked "for trusted players"
function RMPG.SetTrusted(ply, on)
	if not IsValid(ply) then return end
	RMPG.Trusted[RMPG.PlayerKey(ply)] = on and ply:Nick() or nil
	file.CreateDir("rmpg")
	file.Write(TRUST_FILE, util.TableToJSON(RMPG.Trusted, true))
	RMPG.SendTrust()
	RMPG.AddNote(RMPG.T(on and "n_trust_on" or "n_trust_off", ply:Nick()), on and 2 or 0)
end

-- Forget a saved friend, also one who is not on the server
function RMPG.UntrustKey(key)
	local nick = RMPG.Trusted[key]
	RMPG.Trusted[key] = nil
	file.CreateDir("rmpg")
	file.Write(TRUST_FILE, util.TableToJSON(RMPG.Trusted, true))
	RMPG.SendTrust()
	if nick then RMPG.AddNote(RMPG.T("n_trust_off", nick), 0) end
end

net.Receive("rmpg_shared", function()
	local list = {}
	for i = 1, net.ReadUInt(10) do
		local ownerEnt, owner = net.ReadEntity(), net.ReadString()
		local name, code, pos, yaw, share = net.ReadString(), net.ReadString(), net.ReadVector(), net.ReadFloat(), net.ReadUInt(2)
		list[i] = { owner = owner, ownerEnt = ownerEnt, name = name, code = code, x = pos.x, y = pos.y, z = pos.z, yaw = yaw, share = share }
	end
	local trusts = {}
	for _ = 1, net.ReadUInt(8) do
		local p = net.ReadEntity()
		if IsValid(p) then trusts[p] = true end
	end
	RMPG.SharedLocations = list
	RMPG.TrustsMe = trusts
	RMPG.SharedVersion = RMPG.SharedVersion + 1
end)

-- Where the player stands right now
function RMPG.SaveHere(name)
	local ply = LocalPlayer()
	return RMPG.AddLocation(name, ply:GetPos(), ply:EyeAngles().y)
end

-- The ground point the player is aiming at
function RMPG.SaveAim(name)
	local ply = LocalPlayer()
	local tr = ply:GetEyeTrace()
	local pos = tr.HitPos
	if tr.HitNormal.z < 0.7 then
		pos = RMPG.GroundBelow(tr.HitPos - ply:GetAimVector() * 24 + Vector(0, 0, 8), 2000) or tr.HitPos
	end
	return RMPG.AddLocation(name, pos, ply:EyeAngles().y)
end

---------------------------------------------------------------------------
-- Destination requests
---------------------------------------------------------------------------

function RMPG.SendDest(mode, data)
	net.Start("rmpg_dest")
	net.WriteUInt(mode, RMPG.DEST_BITS)
	if mode == RMPG.DEST_LOCATION then
		net.WriteVector(RMPG.LocPos(data))
		net.WriteFloat(data.yaw or 0)
		net.WriteString(data.name or "")
		net.WriteString(data.code or "")
	elseif mode == RMPG.DEST_PLAYER then
		net.WriteEntity(data)
	elseif mode == RMPG.DEST_COORDS then
		net.WriteVector(data.pos)
		net.WriteFloat(data.pitch or 0)
		net.WriteFloat(data.yaw or 0)
	elseif mode == RMPG.DEST_MAP then
		net.WriteString(data or "")
	end
	net.SendToServer()

	local label
	if mode == RMPG.DEST_LOCATION then label = data.code .. " · " .. data.name
	elseif mode == RMPG.DEST_PLAYER then label = IsValid(data) and data:Nick() or "?"
	elseif mode == RMPG.DEST_MANUAL then label = RMPG.T("dest_manual")
	elseif mode == RMPG.DEST_QUICK then label = RMPG.T("dest_quick")
	elseif mode == RMPG.DEST_TRAP then label = RMPG.T("dest_trap")
	elseif mode == RMPG.DEST_CHAIN then label = RMPG.T("dest_chain")
	elseif mode == RMPG.DEST_COORDS then label = string.format("%d %d %d", math.Round(data.pos.x), math.Round(data.pos.y), math.Round(data.pos.z))
	elseif mode == RMPG.DEST_MAP then label = RMPG.T("dest_map", data or "?")
	else label = RMPG.T("dest_random") end
	RMPG.AddNote(RMPG.T("n_dest_set", label), 0)
end

-- Readable name of the destination stored on a weapon
function RMPG.DestText(wep)
	if not IsValid(wep) then return RMPG.T("dest_none") end
	local l = wep:GetDestLabel()
	if l == "" then return RMPG.T("dest_random") end
	local c = string.sub(l, 1, 1)
	if c == "#" then return RMPG.T(string.sub(l, 2)) end
	if c == "@" then return RMPG.T("dest_player", string.sub(l, 2)) end
	return l
end

local function Startup()
	RMPG.LoadLocations()
	RMPG.LoadTrusted()
	RMPG.SendShared()
	RMPG.SendTrust()
end

hook.Add("InitPostEntity", "rmpg_locations", Startup)
RMPG.LoadLocations()
RMPG.LoadTrusted()
if IsValid(LocalPlayer()) then timer.Simple(0, Startup) end -- Lua refresh while in game
