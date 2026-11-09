-- Server: requests coming from the portal gun menu
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)

for _, n in ipairs({ "rmpg_menu", "rmpg_dest", "rmpg_color", "rmpg_core", "rmpg_reload",
	"rmpg_close", "rmpg_selfdestruct", "rmpg_svset", "rmpg_variant", "rmpg_action",
	"rmpg_share", "rmpg_trust", "rmpg_shared", "rmpg_body" }) do
	util.AddNetworkString(n)
end

-- Simple per-player rate limit for menu requests
local function Allow(ply, key, dt)
	ply.RMPG_NetT = ply.RMPG_NetT or {}
	local t = CurTime()
	if (ply.RMPG_NetT[key] or 0) > t then return false end
	ply.RMPG_NetT[key] = t + (dt or 0.15)
	return true
end

local function Gun(ply)
	local w = ply:GetWeapon(RMPG.WEAPON)
	return IsValid(w) and w or nil
end

net.Receive("rmpg_dest", function(_, ply)
	if not Allow(ply, "dest") then return end
	local mode = net.ReadUInt(RMPG.DEST_BITS)
	local d = { mode = mode }
	if mode == RMPG.DEST_LOCATION then
		d.pos = net.ReadVector()
		d.yaw = net.ReadFloat()
		d.name = string.sub(net.ReadString(), 1, 48)
		d.code = string.sub(net.ReadString(), 1, 12)
		if not util.IsInWorld(d.pos + UP * 36) then
			RMPG.Notify(ply, "n_bad_location", nil, 1)
			return
		end
	elseif mode == RMPG.DEST_PLAYER then
		d.target = net.ReadEntity()
		if not IsValid(d.target) or not d.target:IsPlayer() or d.target == ply then
			RMPG.Notify(ply, "n_no_target", nil, 1)
			return
		end
	elseif mode == RMPG.DEST_COORDS then
		d.pos = net.ReadVector()
		d.pitch = math.Clamp(net.ReadFloat(), -90, 90)
		d.yaw = math.NormalizeAngle(net.ReadFloat())
		if not util.IsInWorld(d.pos) then
			RMPG.Notify(ply, "n_coords_bad", nil, 1)
			return
		end
	elseif mode == RMPG.DEST_MAP then
		d.map = string.sub(net.ReadString(), 1, 64)
		if not RMPG.MapTravelAllowed(ply) then
			RMPG.Notify(ply, "n_map_denied", nil, 1)
			return
		end
		if not string.match(d.map, "^[%w_%-%.]+$") or not file.Exists("maps/" .. d.map .. ".bsp", "GAME") then
			RMPG.Notify(ply, "n_map_missing", { d.map }, 1)
			return
		end
	elseif mode ~= RMPG.DEST_RANDOM and mode ~= RMPG.DEST_MANUAL and mode ~= RMPG.DEST_QUICK and mode ~= RMPG.DEST_TRAP
		and mode ~= RMPG.DEST_CHAIN then
		return
	end
	ply.RMPG_Dest = d
	if mode ~= RMPG.DEST_MANUAL and IsValid(ply.RMPG_PendingA) then
		ply.RMPG_PendingA:Close()
		ply.RMPG_PendingA = nil
	end
	RMPG.ApplyDestLabel(ply)
end)

net.Receive("rmpg_color", function(_, ply)
	if not Allow(ply, "color", 0.05) then return end
	local c = Vector(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))
	ply.RMPG_Color = c
	local w = Gun(ply)
	if w then w:SetFluidColor(c) end
end)

net.Receive("rmpg_variant", function(_, ply)
	if not Allow(ply, "variant", 0.2) then return end
	local v = math.Clamp(net.ReadUInt(3), 0, RMPG.GUN_COUNT - 1)
	ply.RMPG_Variant = v
	local w = Gun(ply)
	if w then w:SetVariant(v) end
end)

-- The body colour: your own, or the model's (custom = false)
net.Receive("rmpg_body", function(_, ply)
	if not Allow(ply, "body", 0.05) then return end
	local custom = net.ReadBool()
	local c = Vector(math.max(net.ReadUInt(8), 1), math.max(net.ReadUInt(8), 1), math.max(net.ReadUInt(8), 1))
	ply.RMPG_BodyCustom = custom
	ply.RMPG_Body = c
	local w = Gun(ply)
	if w then w:SetBodyColor(custom and c or vector_origin) end
end)

-- Key binds handled by the client (quick portal, quick close, swap flask)
net.Receive("rmpg_action", function(_, ply)
	if not Allow(ply, "action", 0.1) then return end
	local a = net.ReadString()
	local w = Gun(ply)
	local holding = w and ply:GetActiveWeapon() == w
	if a == "quick" then
		if holding then w:FireQuick() end
	elseif a == "close" then
		RMPG.ClosePortals(ply)
		RMPG.Notify(ply, "n_closed", nil, 0)
	elseif a == "reload" then
		if holding then w:Reload() end
	end
end)

net.Receive("rmpg_core", function(_, ply)
	if not Allow(ply, "core", 0.5) then return end
	local install = net.ReadBool()
	local w = Gun(ply)
	if not w then return end
	if not RMPG.CV.coreMenu:GetBool() then
		RMPG.Notify(ply, "n_core_denied", nil, 1)
		return
	end
	if install then
		if w:GetCore() then RMPG.Notify(ply, "n_core_has", nil, 0) return end
		w:InstallCore()
	elseif w:GetCore() then
		w:SetCore(false)
		w:SetCharges(RMPG.MaxCharges())
		w:EmitSound(RMPG.SND.reloadIn, 70)
		RMPG.Notify(ply, "n_core_removed", nil, 2)
	end
end)

net.Receive("rmpg_reload", function(_, ply)
	if not Allow(ply, "reload", 0.5) then return end
	local w = Gun(ply)
	if w and ply:GetActiveWeapon() == w then w:StartReload() end
end)

net.Receive("rmpg_close", function(_, ply)
	if not Allow(ply, "close", 0.5) then return end
	RMPG.ClosePortals(ply)
	RMPG.Notify(ply, "n_closed", nil, 0)
end)

net.Receive("rmpg_selfdestruct", function(_, ply)
	if not Allow(ply, "sd", 1) then return end
	if not ply:Alive() then return end
	RMPG.SelfDestruct(ply)
end)

local allowed = {}
for _, s in ipairs(RMPG.SERVER_SETTINGS) do allowed[s[1]] = s end

net.Receive("rmpg_svset", function(_, ply)
	if not Allow(ply, "svset", 0.05) then return end
	local name, value = net.ReadString(), net.ReadString()
	if not ply:IsSuperAdmin() then
		RMPG.Notify(ply, "n_noaccess", nil, 1)
		return
	end
	local def = allowed[name]
	if not def then return end
	local v = tonumber(value)
	if not v then return end
	if def[2] == "bool" then
		v = v ~= 0 and 1 or 0
	else
		v = math.Clamp(v, def[3], def[4])
	end
	RunConsoleCommand(name, tostring(v))
end)

-- Things still being made (W.I.P in their names): a word when one is spawned or given
RMPG.WIP_CLASSES = { rmpg_acid_vat = true, rmpg_acid_vat_fake = true, rmpg_prime_chip = true, rmpg_tentacle_chip = true,
	rmpg_arm_chip = true, weapon_rmpg_grav_boots = true, rmpg_fruit_potato = true }

local function WipWarn(ply, class)
	if IsValid(ply) and RMPG.WIP_CLASSES[class] then RMPG.Notify(ply, "n_wip", nil, 3) end
end
hook.Add("PlayerSpawnedSENT", "rmpg_wip", function(ply, ent) WipWarn(ply, ent:GetClass()) end)
hook.Add("PlayerSpawnedSWEP", "rmpg_wip", function(ply, ent) WipWarn(ply, ent:GetClass()) end)
hook.Add("PlayerGiveSWEP", "rmpg_wip", function(ply, class) WipWarn(ply, class) end)

concommand.Add("rmpg_selfdestruct", function(ply)
	if IsValid(ply) and ply:Alive() then RMPG.SelfDestruct(ply) end
end)

concommand.Add("rmpg_closeportals", function(ply)
	if IsValid(ply) then RMPG.ClosePortals(ply) end
end)

---------------------------------------------------------------------------
-- Shared locations: "public" ones go to everybody, "for trusted players" ones only to
-- the players their owner trusts. Every client gets its own list.
---------------------------------------------------------------------------

local MAX_SHARED, MAX_SENT = 64, 300

local function Key(ply)
	return ply:SteamID64() or ("BOT" .. ply:UserID())
end

local function SendShared(viewer)
	local vk = Key(viewer)
	local out, trusters = {}, {}
	for _, owner in ipairs(player.GetHumans()) do
		if owner ~= viewer then
			local trusts = owner.RMPG_Trusted ~= nil and owner.RMPG_Trusted[vk] == true
			if trusts then trusters[#trusters + 1] = owner end
			for _, l in ipairs(owner.RMPG_Shared or {}) do
				if l.share == RMPG.SHARE_PUBLIC or (l.share == RMPG.SHARE_TRUSTED and trusts) then out[#out + 1] = { owner, l } end
			end
		end
	end
	local n = math.min(#out, MAX_SENT)
	net.Start("rmpg_shared")
	net.WriteUInt(n, 10)
	for i = 1, n do
		local o, l = out[i][1], out[i][2]
		net.WriteEntity(o)
		net.WriteString(o:Nick())
		net.WriteString(l.name)
		net.WriteString(l.code)
		net.WriteVector(l.pos)
		net.WriteFloat(l.yaw)
		net.WriteUInt(l.share, 2)
	end
	net.WriteUInt(math.min(#trusters, 255), 8)
	for i = 1, math.min(#trusters, 255) do net.WriteEntity(trusters[i]) end
	net.Send(viewer)
end

function RMPG.QueueShareSync()
	timer.Create("rmpg_share_sync", 0.5, 1, function()
		for _, p in ipairs(player.GetHumans()) do SendShared(p) end
	end)
end

net.Receive("rmpg_share", function(_, ply)
	if not Allow(ply, "share", 0.25) then return end
	local list = {}
	for _ = 1, math.min(net.ReadUInt(7), MAX_SHARED) do
		local l = {
			name = string.sub(net.ReadString(), 1, 48),
			code = string.sub(net.ReadString(), 1, 12),
			pos = net.ReadVector(),
			yaw = net.ReadFloat(),
			share = net.ReadUInt(2),
		}
		if l.share == RMPG.SHARE_TRUSTED or l.share == RMPG.SHARE_PUBLIC then list[#list + 1] = l end
	end
	ply.RMPG_Shared = list
	RMPG.QueueShareSync()
end)

net.Receive("rmpg_trust", function(_, ply)
	if not Allow(ply, "trust", 0.25) then return end
	local set = {}
	for _ = 1, net.ReadUInt(8) do set[string.sub(net.ReadString(), 1, 32)] = true end
	ply.RMPG_Trusted = set
	RMPG.QueueShareSync()
end)

hook.Add("PlayerDisconnected", "rmpg_share", function() RMPG.QueueShareSync() end)
