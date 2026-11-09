-- Server: Evil Morty's eyepatch - putting it on, the ability chosen on its wheel, the record of who killed whom that the
-- scan reads, and the hacking itself
RMPG = RMPG or {}

util.AddNetworkString("rmpg_patch")
util.AddNetworkString("rmpg_patch_scan")

local PORTAL, XRAY, HACK, SCAN, BINOC = RMPG.PATCH_PORTAL, RMPG.PATCH_XRAY, RMPG.PATCH_HACK, RMPG.PATCH_SCAN, RMPG.PATCH_BINOC
local KILLS = 3 -- how many kills are kept for each killer

function RMPG.PatchWear(ply, on)
	if not IsValid(ply) or on == ply:GetNW2Bool("RMPG_Patch") then return end
	ply:SetNW2Bool("RMPG_Patch", on)
	ply:SetNW2Int("RMPG_PatchMode", RMPG.PATCH_OFF)
	ply:SetNW2Float("RMPG_AimUntil", 0)
	if on then ply:SetNW2String("RMPG_PatchCfg", RMPG.PatchString(RMPG.PatchParse(ply:GetInfo("rmpg_patch_cfg")))) end
	ply:EmitSound(RMPG.SND.patchOn, 60, on and 110 or 85)
	RMPG.Notify(ply, on and "n_patch_on" or "n_patch_off", nil, 0)
end

-- The last kills of an entity, newest first
local function SendScan(ply, e)
	local who = e
	if e:GetClass() == "rmpg_worm_seg" and IsValid(e.Worm) then who = e.Worm end
	local log = who.RMPG_KillLog or {}
	local now = CurTime()
	net.Start("rmpg_patch_scan")
	net.WriteEntity(e)
	net.WriteUInt(#log, 3)
	for _, k in ipairs(log) do
		net.WriteString(k.who)
		net.WriteString(k.with)
		net.WriteUInt(k.clock, 32)
		net.WriteFloat(now - k.t)
	end
	net.Send(ply)
end

net.Receive("rmpg_patch", function(_, ply)
	local a = net.ReadUInt(3)
	if a == RMPG.PATCH_A_CFG then
		local str = net.ReadString()
		if #str <= 200 and ply:GetNW2Bool("RMPG_Patch") then ply:SetNW2String("RMPG_PatchCfg", RMPG.PatchString(RMPG.PatchParse(str))) end
	elseif a == RMPG.PATCH_A_MODE then
		local m = net.ReadUInt(3)
		if not ply:GetNW2Bool("RMPG_Patch") then return end
		if m == HACK and not RMPG.CV.patchHack:GetBool() then
			RMPG.Notify(ply, "n_patch_no_hack", nil, 1)
			return
		end
		ply:SetNW2Int("RMPG_PatchMode", m == ply:GetNW2Int("RMPG_PatchMode") and RMPG.PATCH_OFF or m)
		ply:EmitSound(RMPG.SND.patchMode, 50, 120)
	elseif a == RMPG.PATCH_A_OFF then
		RMPG.PatchWear(ply, false)
	elseif a == RMPG.PATCH_A_SCAN then
		local e = net.ReadEntity()
		local mode = ply:GetNW2Int("RMPG_PatchMode")
		if IsValid(e) and (mode == SCAN or mode == BINOC) and (ply.RMPG_NextScan or 0) <= CurTime() then
			ply.RMPG_NextScan = CurTime() + 0.2
			SendScan(ply, e)
		end
	elseif a == RMPG.PATCH_A_AIM then
		local part = net.ReadUInt(3)
		if not ply:GetNW2Bool("RMPG_Patch") or not RMPG.PATCH_PARTS[part] then return end
		if not RMPG.CV.patchAim:GetBool() then
			RMPG.Notify(ply, "n_patch_no_aim", nil, 1)
			return
		end
		local now = CurTime()
		ply:SetNW2Int("RMPG_AimPart", part)
		if ply:GetNW2Float("RMPG_AimUntil", 0) > now then return end -- already on: only the body part changes
		if (ply.RMPG_AimReady or 0) > now then
			RMPG.Notify(ply, "n_patch_aim_wait", { math.ceil(ply.RMPG_AimReady - now) }, 1)
			return
		end
		local time = RMPG.CV.patchAimTime:GetFloat()
		ply:SetNW2Float("RMPG_AimUntil", now + time)
		ply.RMPG_AimReady = now + time + RMPG.CV.patchAimCool:GetFloat()
		ply:EmitSound(RMPG.SND.patchMode, 55, 90)
	end
end)

---------------------------------------------------------------------------
-- Who killed whom: kept on the killer, a player or any other entity
---------------------------------------------------------------------------

local function NameOf(e)
	if e:IsPlayer() then return e:Nick() end
	if e.GetCloneName then return e:GetCloneName() end
	return e:GetClass()
end

-- What it was done with: what did the damage, or what the killer had in hand when the killer itself is the inflictor
local function ToolOf(attacker, inflictor)
	if IsValid(inflictor) and inflictor ~= attacker then return inflictor:GetClass() end
	if attacker.GetActiveWeapon then
		local w = attacker:GetActiveWeapon()
		if IsValid(w) then return w:GetClass() end
	end
	return attacker:GetClass()
end

local function Log(attacker, inflictor, victim)
	if not IsValid(attacker) or attacker:IsWorld() or attacker == victim or not IsValid(victim) then return end
	local log = attacker.RMPG_KillLog or {}
	attacker.RMPG_KillLog = log
	table.insert(log, 1, { who = NameOf(victim), with = ToolOf(attacker, inflictor), clock = os.time(), t = CurTime() })
	log[KILLS + 1] = nil
end

hook.Add("PlayerDeath", "rmpg_patch_log", function(victim, inflictor, attacker) Log(attacker, inflictor, victim) end)
hook.Add("OnNPCKilled", "rmpg_patch_log", function(npc, attacker, inflictor) Log(attacker, inflictor, npc) end)

-- It comes off when you die
local function Off(ply) RMPG.PatchWear(ply, false) end
hook.Add("PlayerDeath", "rmpg_patch", Off)
hook.Add("PlayerSilentDeath", "rmpg_patch", Off)

-- What is behind walls has to reach the wearer at all: the people the X-ray shows, the far side of the portals
hook.Add("SetupPlayerVisibility", "rmpg_patch", function(ply)
	local mode = ply:GetNW2Int("RMPG_PatchMode")
	-- what the binoculars look at may be anywhere on the map
	if mode == BINOC then AddOriginToPVS(ply:GetEyeTrace().HitPos) return end
	if mode ~= PORTAL and mode ~= XRAY and mode ~= SCAN then return end
	local now = CurTime()
	if (ply.RMPG_PvsAt or 0) < now then
		ply.RMPG_PvsAt = now + 0.5
		local t = {}
		if mode ~= PORTAL then
			for _, e in ipairs(ents.FindInSphere(ply:GetPos(), RMPG.CV.patchXray:GetFloat())) do
				if RMPG.PatchEnemy(e, ply) then
					t[#t + 1] = e
					if #t >= 16 then break end
				end
			end
		else
			for _, p in ipairs(ents.FindByClass("rmpg_portal")) do
				if IsValid(p:GetPartner()) then
					t[#t + 1] = p:GetPartner()
					if #t >= 6 then break end
				end
			end
		end
		ply.RMPG_Pvs = t
	end
	for _, e in ipairs(ply.RMPG_Pvs or {}) do
		if IsValid(e) then AddOriginToPVS(e:GetPos()) end
	end
end)

---------------------------------------------------------------------------
-- Hacking: E while the ability is on sets off whatever is in the middle of the view, however far and whoever's it is;
-- Shift+E is the second action: bombs are taken over, dynamite is made safe
---------------------------------------------------------------------------

local function Press(e) e:Fire("Press") end
local function Toggle(e) e:Fire("Toggle") end
local function Own(e) e:Toggle() end
-- exactly what pressing it would do, or the button's own code later switches itself off with nobody attached
local function UseIt(e, ply) e:Use(ply, ply, USE_ON, 1) end

-- A bomb counting down is defused, one linked to a detonator is cut off it, an idle one starts counting
local function Bomb(e, ply)
	if e:GetExploded() then return end
	if e:GetBlastTime() > 0 then
		e:Defuse(ply)
	elseif e:IsLinked() then
		e:SetArmed(false)
		e:SetLinker(NULL)
		e:EmitSound(RMPG.SND.bombDisarm, 70)
		RMPG.Notify(ply, "n_patch_cut", nil, 0)
	else
		e:Trigger()
	end
end

-- Whatever it was doing stops, and it answers to your detonator now
local function TakeOver(e, ply)
	if e:GetExploded() then return end
	if e:GetBlastTime() > 0 then e:Defuse(ply) end
	e:SetArmed(true)
	e:SetLinker(ply)
	if not ply:HasWeapon(RMPG.DETONATOR) then ply:Give(RMPG.DETONATOR) end
	RMPG.Notify(ply, "n_patch_taken", nil, 2)
end

local ACT = {
	gmod_button = UseIt,
	gmod_dynamite = function(e, ply) e:Explode(0, ply) end,
	gmod_lamp = Own, gmod_light = Own, gmod_hoverball = Own,
	gmod_thruster = function(e) e:Switch(not e:GetOn()) end,
	gmod_emitter = function(e) e:SetOn(not e:GetOn()) end,
	gmod_wire_button = UseIt,
	func_button = Press, func_rot_button = Press, momentary_rot_button = Press,
	func_door = Toggle, func_door_rotating = Toggle,
	prop_door_rotating = function(e)
		e:Fire("Unlock")
		e:Fire("Toggle")
	end,
	npc_turret_floor = Toggle, npc_turret_ceiling = Toggle,
	npc_combine_camera = function(e) e:Fire("Disable") end,
	rmpg_prime_bomb = Bomb, rmpg_neutrino_bomb = Bomb,
	rmpg_portal = function(e) e:Close() end,
}

-- Shift+E
local ALT = {
	rmpg_prime_bomb = TakeOver, rmpg_neutrino_bomb = TakeOver,
	gmod_dynamite = function(e, ply)
		e:Remove()
		RMPG.Notify(ply, "n_patch_safe", nil, 0)
	end,
}

local function Hack(ply)
	local now = CurTime()
	if (ply.RMPG_NextHack or 0) > now then return end
	local e = RMPG.PatchPick(ply:EyePos(), ply:GetAimVector(), RMPG.PatchHackables(ply:EyePos(), RMPG.CV.patchHackRange:GetFloat()))
	if not e then return end
	ply.RMPG_NextHack = now + RMPG.CV.patchHackCool:GetFloat()
	ply.RMPG_HackedAt = now
	local pos = e:WorldSpaceCenter()
	local act = ply:KeyDown(IN_SPEED) and ALT[e:GetClass()] or ACT[e:GetClass()]
	-- whatever a mechanism from another addon does when poked must not break the eyepatch
	if act then
		local ok, err = pcall(act, e, ply)
		if not ok then
			print("[rm_portalgun] hack of " .. e:GetClass() .. " failed: " .. tostring(err))
			RMPG.Notify(ply, "n_patch_hack_failed", nil, 1)
		end
	end
	local ed = EffectData()
	ed:SetOrigin(pos)
	util.Effect("ManhackSparks", ed, true, true)
	sound.Play(RMPG.SND.patchHack, pos, 70, 110)
	ply:EmitSound(RMPG.SND.patchHack, 50, 140)
end

hook.Add("KeyPress", "rmpg_patch_hack", function(ply, key)
	if key == IN_USE and ply:GetNW2Int("RMPG_PatchMode") == HACK then Hack(ply) end
end)

-- The same E must not also press what you happen to be standing at
hook.Add("PlayerUse", "rmpg_patch_hack", function(ply)
	if CurTime() - (ply.RMPG_HackedAt or -1) < 0.3 then return false end
end)
