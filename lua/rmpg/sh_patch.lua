-- Evil Morty's eyepatch, shared part: how it sits on the head (each player sets that up in the editor, everyone sees
-- it the same) and which mechanisms it can hack
RMPG = RMPG or {}

RMPG.PATCH_OFF, RMPG.PATCH_PORTAL, RMPG.PATCH_XRAY, RMPG.PATCH_HACK, RMPG.PATCH_SCAN, RMPG.PATCH_CAMERA, RMPG.PATCH_BINOC = 0, 1, 2, 3, 4, 5, 6
RMPG.PATCH_A_CFG, RMPG.PATCH_A_MODE, RMPG.PATCH_A_OFF, RMPG.PATCH_A_SCAN, RMPG.PATCH_A_AIM = 1, 2, 3, 4, 5

-- What the auto-aim can lock on to
RMPG.PATCH_PARTS = {
	{ "aim_head", "ValveBiped.Bip01_Head1" },
	{ "aim_chest", "ValveBiped.Bip01_Spine2" },
	{ "aim_belly", "ValveBiped.Bip01_Pelvis" },
	{ "aim_arm", "ValveBiped.Bip01_R_Forearm" },
	{ "aim_leg", "ValveBiped.Bip01_R_Calf" },
}

-- key, default, min, max. p*: the pad in head space - forward, right, up, turned (yaw, pitch, roll), size.
-- s*: the strap - where its middle is (forward, right, up), radii front-back and sideways, width, tilt.
-- The defaults sit right on the HL2 citizens; other heads are what the editor is for.
RMPG.PATCH_FIELDS = {
	{ "pf", 4.35, 0, 12 }, { "pr", 1.55, -6, 6 }, { "pu", 3.55, -4, 12 },
	{ "pyaw", -26, -60, 60 }, { "ppitch", 0, -45, 45 }, { "proll", 0, -45, 45 }, { "psize", 0.8, 0.4, 2.5 },
	{ "sf", 0.7, -4, 6 }, { "sr", 0, -4, 4 }, { "su", 3.9, -2, 10 },
	{ "sx", 4.15, 2, 9 }, { "sy", 3.6, 2, 9 }, { "sw", 0.5, 0.15, 2 },
	{ "spitch", 10, -45, 45 }, { "sroll", 8, -45, 45 },
}

function RMPG.PatchDefaults()
	local t = {}
	for _, f in ipairs(RMPG.PATCH_FIELDS) do t[f[1]] = f[2] end
	return t
end

-- The settings travel as one short string of numbers; anything out of range is pulled back in
function RMPG.PatchParse(str)
	local t = RMPG.PatchDefaults()
	local i = 0
	for v in string.gmatch(str or "", "[^,]+") do
		i = i + 1
		local f = RMPG.PATCH_FIELDS[i]
		if not f then break end
		local n = tonumber(v)
		if n then t[f[1]] = math.Clamp(n, f[3], f[4]) end
	end
	return t
end

function RMPG.PatchString(t)
	local out = {}
	for i, f in ipairs(RMPG.PATCH_FIELDS) do out[i] = tostring(math.Round(t[f[1]] or f[2], 2)) end
	return table.concat(out, ",")
end

-- Where the patch goes: the head bone turned into forward / right / up of the face (on a ValveBiped head the bone's X
-- runs up the head, its -Y out of the face and its Z to the right)
function RMPG.PatchFrame(e)
	local b = e:LookupBone("ValveBiped.Bip01_Head1")
	local m = b and e:GetBoneMatrix(b)
	if not m then return end
	local a = m:GetAngles()
	return m:GetTranslation(), a:Right():AngleEx(a:Forward())
end

-- What can be hacked, with the label the screen shows (not RMPG.PATCH_HACK: that is the hack mode's number, and this
-- table once took its name, so picking the mode sent a table and hacking never switched on)
RMPG.PATCH_HACKABLE = {
	gmod_button = "hk_button", gmod_wire_button = "hk_button", func_button = "hk_button", func_rot_button = "hk_button", momentary_rot_button = "hk_button",
	gmod_dynamite = "hk_dynamite",
	gmod_lamp = "hk_light", gmod_light = "hk_light",
	gmod_thruster = "hk_engine", gmod_hoverball = "hk_engine", gmod_emitter = "hk_engine",
	func_door = "hk_door", func_door_rotating = "hk_door", prop_door_rotating = "hk_door",
	npc_turret_floor = "hk_turret", npc_turret_ceiling = "hk_turret", npc_combine_camera = "hk_camera",
	rmpg_prime_bomb = "hk_bomb", rmpg_neutrino_bomb = "hk_bomb",
	rmpg_portal = "hk_portal",
}

-- The thing closest to the middle of the view (within about 10 degrees, or as close as limit says)
function RMPG.PatchPick(eye, aim, list, limit)
	local best, bd = nil, limit or 0.985
	for _, e in ipairs(list) do
		if IsValid(e) then
			local d = e:WorldSpaceCenter() - eye
			local k = d:Dot(aim) / math.max(d:Length(), 1)
			if k > bd then best, bd = e, k end
		end
	end
	return best
end

-- Everything hackable within reach of a point
function RMPG.PatchHackables(pos, range)
	local t = {}
	for _, e in ipairs(ents.FindInSphere(pos, range)) do
		if RMPG.PATCH_HACKABLE[e:GetClass()] then t[#t + 1] = e end
	end
	return t
end

-- Whom the thermal view and the scan pick out
function RMPG.PatchEnemy(e, me)
	if e == me then return false end
	if e:IsPlayer() then return e:Alive() end
	if e:IsNPC() or e:IsNextBot() then return e:Health() > 0 end
	return e:GetClass() == "rmpg_brain_worm"
end
