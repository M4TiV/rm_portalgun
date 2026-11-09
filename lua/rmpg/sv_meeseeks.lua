-- Server: Mr. Meeseeks - summoning from the box, the job menu, checking and starting jobs, and the
-- search helpers the jobs use (rmpg_meeseeks.lua runs the jobs themselves)
RMPG = RMPG or {}

util.AddNetworkString("rmpg_mr_menu")
util.AddNetworkString("rmpg_mr_task")
util.AddNetworkString("rmpg_mr_ban")

local UP = Vector(0, 0, 1)
local HULL_MIN, HULL_MAX = Vector(-12, -12, 0), Vector(12, 12, 82)
local MR_DISMISS = 15

function RMPG.MrAlive(e)
	if not IsValid(e) or e.RMPG_Vaporized then return false end
	if e:IsPlayer() then return e:Alive() end
	if e:IsNPC() or e:IsNextBot() then return e:Health() > 0 end
	return true
end

function RMPG.MyMeeseeks(ply)
	local list = {}
	for _, m in ipairs(ents.FindByClass(RMPG.MEESEEKS)) do
		if m:GetMaster() == ply and not m.Poofed then list[#list + 1] = m end
	end
	return list
end

-- A free spot for a Meeseeks near pos (on the ground)
local function SpotNear(pos, ply)
	for _, off in ipairs({ vector_origin, Vector(40, 0, 0), Vector(-40, 0, 0), Vector(0, 40, 0), Vector(0, -40, 0) }) do
		local p = pos + off
		local down = util.TraceLine({ start = p + UP * 40, endpos = p - UP * 300, mask = MASK_SOLID_BRUSHONLY })
		local g = down.HitPos + UP * 2
		local tr = util.TraceHull({ start = g, endpos = g, mins = HULL_MIN, maxs = HULL_MAX, filter = ply, mask = MASK_PLAYERSOLID })
		if not tr.StartSolid then return g end
	end
end

-- LMB on the box: a Meeseeks pops out in front of you (or at pos, already with a job when a Meeseeks calls for help)
function RMPG.SummonMeeseeks(ply, pos, job)
	if not IsValid(ply) then return end
	if #RMPG.MyMeeseeks(ply) >= RMPG.CV.mrMax:GetInt() then
		if not job then RMPG.Notify(ply, "n_mr_limit", { RMPG.CV.mrMax:GetInt() }, 1) end
		return
	end
	if not pos then
		local fwd = ply:GetAimVector()
		fwd.z = 0
		fwd:Normalize()
		local tr = util.TraceHull({ start = ply:GetPos() + UP * 40, endpos = ply:GetPos() + UP * 40 + fwd * 90, mins = Vector(-12, -12, -30), maxs = Vector(12, 12, 30), filter = ply, mask = MASK_PLAYERSOLID })
		pos = tr.HitPos - fwd * 6
	end
	local spot = SpotNear(pos, ply)
	if not spot then
		if not job then RMPG.Notify(ply, "n_mr_no_room", nil, 1) end
		return
	end
	local mr = ents.Create(RMPG.MEESEEKS)
	if not IsValid(mr) then return end
	mr:SetPos(spot)
	mr:SetAngles(Angle(0, (ply:GetPos() - spot):Angle().y, 0))
	mr:SetMaster(ply)
	mr:Spawn()
	mr:Activate()
	local ed = EffectData()
	ed:SetOrigin(spot + UP * 40)
	ed:SetScale(1.3)
	util.Effect("rmpg_meeseeks_poof", ed, true, true)
	sound.Play(RMPG.SND.mrPoof, spot + UP * 40, 75, 90)
	undo.Create("rmpg_meeseeks")
		undo.AddEntity(mr)
		undo.SetPlayer(ply)
		undo.SetCustomUndoText("Undone Mr. Meeseeks")
	undo.Finish()
	if ply.AddCleanup then ply:AddCleanup("npcs", mr) end
	if job then mr:SetJob(job) end
	return mr
end

-- R on the box: every Meeseeks of yours vanishes
function RMPG.DismissMeeseeks(ply)
	local list = RMPG.MyMeeseeks(ply)
	for _, m in ipairs(list) do m:Poof() end
	return #list
end

hook.Add("PlayerDisconnected", "rmpg_meeseeks", function(ply) RMPG.DismissMeeseeks(ply) end)

---------------------------------------------------------------------------
-- Through the portal after you: a Meeseeks following someone (protecting them, healing or bringing something
-- to the master, hunting them) runs into the same portal they went through (rmpg_meeseeks.lua: PortalGoal)
---------------------------------------------------------------------------

local FOLLOW_RANGE = 3000
local MAX_TRAIL = 4

-- Who he is following right now; nil when his job keeps him in one place
local function Following(mr)
	local job = mr.Job
	if not job then return end
	if job.id == RMPG.MR_PROTECT or job.id == RMPG.MR_KILL then return job.ent end
	if job.id == RMPG.MR_HEAL or IsValid(mr.Carrying) then return mr:GetMaster() end
end

function RMPG.MrFollowPortal(ent, from, to)
	if not RMPG.CV.tpNPCs:GetBool() then return end
	for _, mr in ipairs(ents.FindByClass(RMPG.MEESEEKS)) do
		if mr ~= ent and not mr.Poofed and Following(mr) == ent then
			local trail = mr.PortalTrail
			local p = mr:GetPos()
			local d = p:DistToSqr(from:GetPos())
			-- one already on the trail follows it all; a new one only from this side of the portal
			if trail and #trail > 0 then
				if #trail < MAX_TRAIL then trail[#trail + 1] = { from = from, since = CurTime() } end
			elseif d < FOLLOW_RANGE ^ 2 and d < p:DistToSqr(to:GetPos()) then
				mr.PortalTrail = { { from = from, since = CurTime() } }
				if not mr:GetFrenzy() then mr:Say("mr_portal") end
			end
		end
	end
end

---------------------------------------------------------------------------
-- What the jobs look for
---------------------------------------------------------------------------

local NOT_FINDABLE = { "^func_", "^info_", "^env_", "^logic_", "^point_", "^trigger_", "^path_", "^ai_", "^lua_run", "^game_",
	"^filter_", "^math_", "^light", "^shadow_", "^sky_", "^water_", "^beam", "^spotlight", "^keyframe_", "^move_rope", "^phys_",
	"^predicted_", "^gmod_hands", "^physgun_beam", "^player", "^worldspawn", "^soundent", "^bodyque", "^scene_manager", "^team_",
	"^network", "^gmod_gamerules", "^ambient_", "^npc_template", "^infodecal", "^env", "^prop_physics", "^prop_ragdoll", "^viewmodel",
	"^rmpg_meeseeks$", "^rmpg_portal$", "^manipulate_", "^raggib" }

local function Findable(e)
	if not IsValid(e) or e:IsWorld() or IsValid(e:GetParent()) or e:IsPlayer() then return false end
	if e:IsWeapon() and IsValid(e:GetOwner()) then return false end
	local c = e:GetClass()
	for _, pat in ipairs(NOT_FINDABLE) do
		if string.find(c, pat) then return false end
	end
	return e:GetNoDraw() == false
end

local function Nearest(from, list)
	local best, bd
	for _, e in ipairs(list) do
		local d = e:GetPos():DistToSqr(from)
		if not bd or d < bd then best, bd = e, d end
	end
	return best
end

function RMPG.MrNearestProp(mr, model)
	local list = {}
	for _, e in ipairs(ents.FindByModel(model)) do
		if string.find(e:GetClass(), "^prop_physics") and not e.RMPG_CarriedBy and not IsValid(e:GetParent()) then list[#list + 1] = e end
	end
	return Nearest(mr:GetPos(), list)
end

function RMPG.MrNearestOfClass(mr, class)
	local list = {}
	for _, e in ipairs(ents.FindByClass(class)) do
		if Findable(e) and not e.RMPG_CarriedBy then list[#list + 1] = e end
	end
	return Nearest(mr:GetPos(), list)
end

-- Small loose things he can carry back instead of pointing at them
function RMPG.MrCarryable(e)
	if e:IsNPC() or e:IsNextBot() or e:IsVehicle() or e:IsPlayer() then return false end
	local po = e:GetPhysicsObject()
	return e:GetMoveType() == MOVETYPE_VPHYSICS and IsValid(po) and po:IsMotionEnabled() and po:GetMass() < 80 and e:BoundingRadius() < 45
end

-- Nearest NPC within r of pos that is hostile to ply
function RMPG.MrNearestEnemy(ply, pos, r)
	local best, bd
	for _, e in ipairs(ents.FindInSphere(pos, r)) do
		if e:IsNPC() and e:Health() > 0 and e:Disposition(ply) == D_HT then
			local d = e:GetPos():DistToSqr(pos)
			if not bd or d < bd then best, bd = e, d end
		end
	end
	return best
end

local function Trusted(master, ply)
	return IsValid(master) and master.RMPG_Trusted ~= nil and master.RMPG_Trusted[ply:SteamID64() or ""] == true
end

-- Who the Meeseeks should fight around pos: enemies of who, whoever hurt who or the Meeseeks lately and,
-- when guarding, players walking into the guarded zone (after a warning)
function RMPG.MrThreat(mr, who, pos, r, guard)
	local pvp = RMPG.CV.mrPvP:GetBool()
	local master = mr:GetMaster()
	local now = CurTime()
	local best, bd
	for _, e in ipairs(ents.FindInSphere(pos, r)) do
		if e ~= mr and e ~= who and e ~= master and RMPG.MrAlive(e) then
			local bad = false
			if e:IsNPC() then
				bad = (IsValid(who) and (e:GetEnemy() == who or e:Disposition(who) == D_HT)) or e:GetEnemy() == mr
			elseif e:IsPlayer() then
				if pvp and not Trusted(master, e) then
					bad = (IsValid(who) and who.RMPG_HurtBy == e and now - (who.RMPG_HurtT or 0) < 6)
						or (mr.HurtBy == e and now - (mr.HurtT or 0) < 6)
					if guard and not bad then
						-- intruders get a warning first
						mr.Warned = mr.Warned or {}
						local w = mr.Warned[e]
						if not w or now - w > 20 then
							mr.Warned[e] = now
							mr:Say("mr_halt", e:Nick())
						elseif now - w > 2.5 then
							bad = true
						end
					end
				end
			elseif e:IsNextBot() and e:GetClass() ~= RMPG.MEESEEKS then
				bad = (mr.HurtBy == e and now - (mr.HurtT or 0) < 6) or (IsValid(who) and who.RMPG_HurtBy == e and now - (who.RMPG_HurtT or 0) < 6)
			end
			if not bad and (e:IsNPC() or e:IsNextBot()) and mr.HurtBy == e and now - (mr.HurtT or 0) < 6 then bad = true end
			if bad then
				local d = e:GetPos():DistToSqr(mr:GetPos())
				if not bd or d < bd then best, bd = e, d end
			end
		end
	end
	return best
end

-- Remember who hurt a player, so a protecting Meeseeks knows whom to punch
hook.Add("EntityTakeDamage", "rmpg_meeseeks", function(ent, dmg)
	if ent:IsPlayer() then
		local a = dmg:GetAttacker()
		if IsValid(a) and a ~= ent then
			ent.RMPG_HurtBy, ent.RMPG_HurtT = a, CurTime()
		end
	end
end)

---------------------------------------------------------------------------
-- Making props, weapons, entities and NPCs (with the same checks and limits as the spawn menu)
---------------------------------------------------------------------------

local function CheckMake(ply, kind, value)
	if RMPG.MrBanned(kind, value) then return false, "n_mr_banned" end
	if kind == 2 then
		if not RMPG.CV.mrMakeEnts:GetBool() then return false, "n_mr_no_ents" end
		local info = list.Get("SpawnableEntities")[value]
		if not info or not isfunction(Spawn_SENT) then return false, "n_mr_bad_item" end
		if info.AdminOnly and not ply:IsAdmin() then return false, "n_mr_bad_item" end
		if hook.Run("PlayerSpawnSENT", ply, value) == false then return false end
		return true
	end
	if kind == 3 then
		if not RMPG.CV.mrMakeNPCs:GetBool() then return false, "n_mr_no_npcs" end
		local info = list.Get("NPC")[value]
		if not info or not isfunction(Spawn_NPC) then return false, "n_mr_bad_item" end
		if RMPG.MrBanned(3, info.Class) then return false, "n_mr_banned" end
		if info.AdminOnly and not ply:IsAdmin() then return false, "n_mr_bad_item" end
		if hook.Run("PlayerSpawnNPC", ply, value, "") == false then return false end
		return true
	end
	if kind == 1 then
		if not RMPG.CV.mrWeapons:GetBool() then return false, "n_mr_no_weapons" end
		local info = list.Get("Weapon")[value]
		if not info then return false, "n_mr_bad_item" end
		if (not info.Spawnable or info.AdminOnly) and not ply:IsAdmin() then return false, "n_mr_bad_item" end
		if hook.Run("PlayerSpawnSWEP", ply, value, info) == false then return false end
		return true
	end
	if not isstring(value) or not string.find(value, "%.mdl$") or not util.IsValidModel(value) or not util.IsValidProp(value) then
		return false, "n_mr_bad_item"
	end
	if hook.Run("PlayerSpawnProp", ply, value) == false then return false end
	return true
end

-- Where an entity or NPC goes: the floor in front of him stands in for what the player would aim at
local function MakeTrace(mr, pos, info)
	local ceiling = info and info.OnCeiling and not info.OnFloor
	local tr = util.TraceLine({ start = pos + UP * 40, endpos = ceiling and pos + UP * 1000 or pos - UP * 200, filter = mr, mask = MASK_SOLID })
	if not tr.Hit then tr.Hit, tr.HitPos, tr.HitNormal = true, pos, UP end
	return tr
end

-- The weapon the spawn menu would give this NPC
local function NPCWeapon(ply, info)
	local pick = ply:GetInfo("gmod_npcweapon")
	if pick and pick ~= "" then return pick end
	local w = info.Weapons
	if istable(w) and #w > 0 then return w[math.random(#w)] end
	return ""
end

local function Puff(e)
	local ed = EffectData()
	ed:SetOrigin(e:WorldSpaceCenter())
	ed:SetScale(0.7)
	util.Effect("rmpg_meeseeks_poof", ed, true, true)
end

function RMPG.MrMake(mr, job)
	local ply = mr:GetMaster()
	if not IsValid(ply) then return false end
	local ok, why = CheckMake(ply, job.kind, job.value)
	if not ok then
		if why then RMPG.Notify(ply, why, nil, 1) end
		return false
	end
	local pos = mr:GetPos() + mr:GetForward() * 45 + UP * 12
	local e
	if job.kind >= 2 then
		-- the sandbox's own spawning: its limits, undo and cleanup, and every entity's SpawnFunction
		if job.kind == 2 then
			e = Spawn_SENT(ply, job.value, MakeTrace(mr, pos))
		else
			local info = list.Get("NPC")[job.value]
			e = Spawn_NPC(ply, job.value, NPCWeapon(ply, info), MakeTrace(mr, pos, info))
		end
		if not IsValid(e) then return false end
		Puff(e)
		return true
	end
	if job.kind == 1 then
		e = ents.Create(job.value)
		if not IsValid(e) then return false end
		e:SetPos(pos + UP * 10)
		e:Spawn()
		e:Activate()
		hook.Run("PlayerSpawnedSWEP", ply, e)
		undo.Create("SWEP")
	else
		e = ents.Create("prop_physics")
		if not IsValid(e) then return false end
		e:SetModel(job.value)
		e:SetAngles(Angle(0, mr:GetAngles().y, 0))
		e:SetPos(pos)
		e:Spawn()
		e:Activate()
		-- stand it on the ground in front of him
		local mins = e:OBBMins()
		local tr = util.TraceLine({ start = pos + UP * 40, endpos = pos - UP * 200, filter = { e, mr }, mask = MASK_SOLID })
		e:SetPos(tr.HitPos - UP * mins.z + mr:GetForward() * math.max(e:BoundingRadius() - 20, 0))
		if ply.AddCount then ply:AddCount("props", e) end
		if ply.AddCleanup then ply:AddCleanup("props", e) end
		hook.Run("PlayerSpawnedProp", ply, job.value, e)
		undo.Create("Prop")
	end
		undo.AddEntity(e)
		undo.SetPlayer(ply)
	undo.Finish()
	Puff(e)
	return true
end

---------------------------------------------------------------------------
-- The job menu
---------------------------------------------------------------------------

local function Label(e)
	if e:IsPlayer() then return e:Nick() end
	return e:GetClass()
end

function RMPG.OpenMeeseeksMenu(ply, mr)
	local pos = ply:GetPos()
	-- targets: living NPCs, nextbots and players, nearest first
	local targets = {}
	for _, e in ipairs(ents.GetAll()) do
		if e ~= ply and RMPG.MrAlive(e) and (e:IsNPC() or (e:IsNextBot() and e:GetClass() ~= RMPG.MEESEEKS) or e:IsPlayer()) then
			targets[#targets + 1] = { e, e:GetPos():Distance(pos) }
		end
	end
	table.sort(targets, function(a, b) return a[2] < b[2] end)
	-- props and other things on the map, grouped
	local props, classes, seenM, seenC = {}, {}, {}, {}
	for _, e in ipairs(ents.GetAll()) do
		if IsValid(e) and string.find(e:GetClass(), "^prop_physics") and not IsValid(e:GetParent()) then
			local m = e:GetModel()
			if m and not seenM[m] then
				seenM[m] = { m, 0, math.huge }
				props[#props + 1] = seenM[m]
			end
			if m then
				seenM[m][2] = seenM[m][2] + 1
				seenM[m][3] = math.min(seenM[m][3], e:GetPos():Distance(pos))
			end
		elseif Findable(e) then
			local c = e:GetClass()
			if not seenC[c] then
				seenC[c] = { c, 0, math.huge }
				classes[#classes + 1] = seenC[c]
			end
			seenC[c][2] = seenC[c][2] + 1
			seenC[c][3] = math.min(seenC[c][3], e:GetPos():Distance(pos))
		end
	end
	table.sort(props, function(a, b) return a[3] < b[3] end)
	table.sort(classes, function(a, b) return a[3] < b[3] end)

	net.Start("rmpg_mr_menu")
	net.WriteEntity(mr)
	local n = math.min(#targets, 40)
	net.WriteUInt(n, 6)
	for i = 1, n do
		local e = targets[i][1]
		net.WriteUInt(e:EntIndex(), 16)
		net.WriteString(Label(e))
		net.WriteFloat(targets[i][2])
		net.WriteInt(math.Clamp(e:Health(), -1, 65000), 17)
		net.WriteBool(e:IsPlayer())
	end
	n = math.min(#props, 48)
	net.WriteUInt(n, 6)
	for i = 1, n do
		net.WriteString(props[i][1])
		net.WriteUInt(math.min(props[i][2], 1023), 10)
	end
	n = math.min(#classes, 48)
	net.WriteUInt(n, 6)
	for i = 1, n do
		net.WriteString(classes[i][1])
		net.WriteUInt(math.min(classes[i][2], 1023), 10)
	end
	net.Send(ply)
end

local function Allow(ply)
	if (ply.RMPG_MrNet or 0) > CurTime() then return false end
	ply.RMPG_MrNet = CurTime() + 0.3
	return true
end

net.Receive("rmpg_mr_task", function(_, ply)
	if not Allow(ply) then return end
	local mr = net.ReadEntity()
	local id = net.ReadUInt(4)
	if not IsValid(mr) or mr:GetClass() ~= RMPG.MEESEEKS or mr:GetMaster() ~= ply or mr:GetFrenzy() then return end
	if mr:GetPos():Distance(ply:GetPos()) > 400 then return end
	if id == MR_DISMISS then
		mr:Say("mr_bye")
		timer.Simple(0.6, function() if IsValid(mr) then mr:Poof() end end)
		return
	end
	if RMPG.MrJobOff(id) then
		RMPG.Notify(ply, "n_mr_job_off", nil, 1)
		return
	end

	local job = { id = id }
	if id == RMPG.MR_KILL then
		local idx = net.ReadUInt(16)
		local t = idx == 0 and RMPG.MrNearestEnemy(ply, ply:GetPos(), 3000) or Entity(idx)
		if not RMPG.MrAlive(t) or t == ply or t == mr or not (t:IsNPC() or t:IsNextBot() or t:IsPlayer()) then
			RMPG.Notify(ply, "n_mr_no_target", nil, 1)
			return
		end
		if t:IsPlayer() and not RMPG.CV.mrPvP:GetBool() then
			RMPG.Notify(ply, "n_mr_no_pvp", nil, 1)
			return
		end
		job.ent, job.label = t, Label(t)
	elseif id == RMPG.MR_FINDPROP then
		job.model = string.sub(net.ReadString(), 1, 200)
		job.label = string.GetFileFromFilename(job.model)
	elseif id == RMPG.MR_MAKE then
		job.kind = net.ReadUInt(2)
		job.value = string.sub(net.ReadString(), 1, 200)
		local ok, why = CheckMake(ply, job.kind, job.value)
		if not ok then
			RMPG.Notify(ply, why or "n_mr_bad_item", nil, 1)
			return
		end
		if job.kind == 1 then
			local info = list.Get("Weapon")[job.value]
			job.label = info and info.PrintName or job.value
		elseif job.kind == 2 then
			local info = list.Get("SpawnableEntities")[job.value]
			job.label = info and info.PrintName or job.value
		elseif job.kind == 3 then
			local info = list.Get("NPC")[job.value]
			job.label = info and info.Name or job.value
		else
			job.label = string.GetFileFromFilename(job.value)
		end
	elseif id == RMPG.MR_FINDENT then
		job.class = string.sub(net.ReadString(), 1, 64)
		job.label = job.class
	elseif id == RMPG.MR_PROTECT then
		local t = Entity(net.ReadUInt(16))
		if not IsValid(t) or not t:IsPlayer() then t = ply end
		job.ent, job.label = t, t:Nick()
	elseif id == RMPG.MR_GUARD then
		local aim = net.ReadUInt(1) == 1
		local p = ply:GetPos()
		if aim then
			local tr = ply:GetEyeTrace()
			if tr.Hit and tr.HitPos:Distance(ply:GetShootPos()) < 3000 then p = tr.HitPos end
		end
		job.pos = p
	elseif id ~= RMPG.MR_HEAL and id ~= RMPG.MR_DISTRACT then
		return
	end
	mr:SetJob(job)
end)

-- The blacklists from the settings: 0 props, 1 weapons, 2 entities, 3 NPCs, 4 jobs
local BAN_CV = { [0] = "rmpg_mr_ban_props", "rmpg_mr_ban_weapons", "rmpg_mr_ban_ents", "rmpg_mr_ban_npcs", "rmpg_mr_ban_jobs" }

net.Receive("rmpg_mr_ban", function(_, ply)
	if not ply:IsSuperAdmin() then
		RMPG.Notify(ply, "n_noaccess", nil, 1)
		return
	end
	local name = BAN_CV[net.ReadUInt(3)]
	local value = string.gsub(string.sub(net.ReadString(), 1, 2000), "[\"';\r\n]", "")
	if name then RunConsoleCommand(name, value) end
end)

concommand.Add("rmpg_meeseeks_dismiss", function(ply)
	if IsValid(ply) then RMPG.DismissMeeseeks(ply) end
end)
