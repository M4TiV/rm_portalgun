-- The tentacle implant: a steel arm of links out of the back. It drags things along behind you, swings you about like a
-- grappling hook, reels in what it is shot at, and on its own catches hold of anything when you fall from high up: then
-- Jump throws you upwards and Ctrl lets you slide down in a shower of sparks. The arm itself is drawn in cl_tentacle.lua.
RMPG = RMPG or {}

local GRAB, HOOK, CATCH, PULL = 1, 2, 3, 4
RMPG.TENT_GRAB, RMPG.TENT_HOOK, RMPG.TENT_CATCH, RMPG.TENT_PULL = GRAB, HOOK, CATCH, PULL

local UP = Vector(0, 0, 1)
local CHEST = Vector(0, 0, 48)
local REEL = 320     -- how fast the hook shortens the rope
local MAX_SPEED = 1500

function RMPG.HasTent(ply)
	return ply:GetNW2Bool("RMPG_Tent", false)
end

function RMPG.TentMode(ply)
	return ply:GetNW2Int("RMPG_TentMode", 0)
end

-- Where the end of the rope is
function RMPG.TentAnchor(ply)
	local e = ply:GetNW2Entity("RMPG_TentEnt")
	if not IsValid(e) then return ply:GetNW2Vector("RMPG_TentAt") end
	local bone = ply:GetNW2Int("RMPG_TentBone", -1)
	local m = bone >= 0 and e:GetBoneMatrix(bone)
	if m then return m:GetTranslation() end
	return e:LocalToWorld(ply:GetNW2Vector("RMPG_TentPos"))
end

-- The rope holds the player: nothing pulls them further away than its length, the hook also reels them in
hook.Add("SetupMove", "rmpg_tentacle", function(ply, mv, cmd)
	local mode = RMPG.TentMode(ply)
	if mode ~= HOOK and mode ~= CATCH then return end
	local dt = engine.TickInterval()
	local to = RMPG.TentAnchor(ply) - (mv:GetOrigin() + CHEST)
	local d = math.max(to:Length(), 1)
	local n = to / d
	local v = mv:GetVelocity()
	local len = ply:GetNW2Float("RMPG_TentLen", d)
	if mode == HOOK then
		len = math.max(len - REEL * (CurTime() - ply:GetNW2Float("RMPG_TentT", 0)), 70)
		if d > 80 then v = v + n * (RMPG.CV.tentPull:GetFloat() * dt) end
		-- the movement keys steer the swing
		local ang = mv:GetMoveAngles()
		local wish = ang:Forward() * mv:GetForwardSpeed() + ang:Right() * mv:GetSideSpeed()
		if wish:LengthSqr() > 1 then v = v + wish:GetNormalized() * (500 * dt) end
	else
		v = v * (1 - math.min(3 * dt, 1)) -- hanging: the swing dies away
	end
	if d > len then
		local along = v:Dot(n)
		if along < 0 then v = v - n * along end
		v = v + n * math.min((d - len) * 6, 400)
	end
	if v:LengthSqr() > MAX_SPEED * MAX_SPEED then v = v:GetNormalized() * MAX_SPEED end
	mv:SetVelocity(v)
end)

if CLIENT then return end

local function Snd(name, n)
	return string.format(RMPG.SND[name], math.random(1, n))
end

-- phys: the limb, when it holds a ragdoll
local function Set(ply, mode, ent, at, phys)
	local has = IsValid(ent)
	ply.RMPG_TentOnEnt = has
	ply.RMPG_TentPhys = phys
	ply:SetNW2Entity("RMPG_TentEnt", has and ent or NULL)
	ply:SetNW2Int("RMPG_TentBone", phys and ent:TranslatePhysBoneToBone(phys) or -1)
	ply:SetNW2Vector("RMPG_TentPos", has and ent:WorldToLocal(at) or at)
	ply:SetNW2Vector("RMPG_TentAt", at)
	ply:SetNW2Float("RMPG_TentLen", (ply:GetPos() + CHEST):Distance(at))
	ply:SetNW2Float("RMPG_TentT", CurTime())
	ply:SetNW2Int("RMPG_TentMode", mode)
end

function RMPG.TentRelease(ply)
	if RMPG.TentMode(ply) == 0 then return end
	ply:SetNW2Int("RMPG_TentMode", 0)
	ply:SetNW2Entity("RMPG_TentEnt", NULL)
	ply:EmitSound(Snd("tentBack", 3), 62, 125)
end

function RMPG.ImplantTent(ply)
	if RMPG.HasTent(ply) then return false end
	ply:SetNW2Bool("RMPG_Tent", true)
	ply:EmitSound(RMPG.SND.shieldImplant, 70, 80)
	return true
end

function RMPG.RemoveTent(ply)
	RMPG.TentRelease(ply)
	ply:SetNW2Bool("RMPG_Tent", false)
end

local function Sparks(at, normal)
	local ed = EffectData()
	ed:SetOrigin(at)
	ed:SetNormal(normal)
	util.Effect("MetalSpark", ed, true, true)
end

-- The claw flies out and bites in with a clang when it gets there. normal: it hit something hard enough to spark
local function Shoot(ply, at, normal)
	ply:EmitSound(Snd("tentShoot", 3), 72, 135)
	timer.Simple(0.14, function()
		sound.Play(Snd("tentHit", 3), at, 78, math.random(105, 125))
		if normal then Sparks(at, normal) end
	end)
end

local function Aim(ply, range)
	local from = ply:GetShootPos()
	return util.TraceLine({ start = from, endpos = from + ply:GetAimVector() * range, filter = ply, mask = MASK_SHOT })
end

-- What can be taken hold of: anything loose, an NPC, or a player if the server says so
local function Takeable(e)
	if not IsValid(e) or e:IsWorld() or e:IsVehicle() then return false end
	if e:IsPlayer() then return RMPG.CV.tentPvP:GetBool() and e:Alive() end
	if e:IsNPC() or e:IsNextBot() then return e:Health() > 0 end
	local po = e:GetPhysicsObject()
	return IsValid(po) and po:IsMotionEnabled()
end

local function Attach(ply, mode, tr)
	local e = tr.Entity
	local solid = IsValid(e) and not e:IsWorld()
	-- a ragdoll is held by the limb that was hit and the rest of it hangs off that
	Set(ply, mode, solid and e or NULL, tr.HitPos, solid and e:IsRagdoll() and tr.PhysicsBone or nil)
	Shoot(ply, tr.HitPos, not solid and tr.HitNormal or nil)
end

-- The grab: what you look at comes along behind you, until it is pressed again
function RMPG.TentGrab(ply)
	if not RMPG.HasTent(ply) or not ply:Alive() then return end
	if RMPG.TentMode(ply) == GRAB then
		RMPG.TentRelease(ply)
		return
	end
	if RMPG.TentMode(ply) ~= 0 then return end
	local tr = Aim(ply, RMPG.CV.tentRange:GetFloat())
	if Takeable(tr.Entity) then
		Attach(ply, GRAB, tr)
	else
		RMPG.Notify(ply, "n_tent_nothing", nil, 0)
	end
end

-- The hook button. Jumping or in the air it takes you to what you look at; standing still it brings that to you
function RMPG.TentHook(ply, down)
	if not RMPG.HasTent(ply) then return end
	if not down then
		local m = RMPG.TentMode(ply)
		if m == HOOK or m == PULL then RMPG.TentRelease(ply) end
		return
	end
	if not ply:Alive() or RMPG.TentMode(ply) ~= 0 or ply:InVehicle() then return end
	local tr = Aim(ply, RMPG.CV.tentRange:GetFloat())
	if not tr.Hit or tr.HitSky then return end
	if not ply:IsOnGround() or ply:KeyDown(IN_JUMP) then
		Attach(ply, HOOK, tr)
		if ply:IsOnGround() then ply:SetVelocity(UP * 260) end
	elseif Takeable(tr.Entity) then
		Attach(ply, PULL, tr)
	else
		RMPG.Notify(ply, "n_tent_jump", nil, 0)
	end
end

-- The strongest hold within reach, as high as can be
local function FindGrip(ply)
	local from = ply:WorldSpaceCenter()
	local reach = RMPG.CV.tentCatch:GetFloat()
	local best, bz
	for _, up in ipairs({ 0.9, 0.5, 0.15 }) do
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local d = Vector(math.cos(a), math.sin(a), up):GetNormalized()
			local tr = util.TraceLine({ start = from, endpos = from + d * reach, filter = ply, mask = MASK_SOLID })
			if tr.Hit and not tr.HitSky and (not bz or tr.HitPos.z > bz) then best, bz = tr, tr.HitPos.z end
		end
	end
	local top = util.TraceLine({ start = from, endpos = from + UP * reach, filter = ply, mask = MASK_SOLID })
	if top.Hit and not top.HitSky then best = top end
	return best
end

local function Falling(ply, now)
	if ply:GetMoveType() ~= MOVETYPE_WALK or ply:IsOnGround() or ply:InVehicle() then return false end
	if ply:GetVelocity().z > -RMPG.CV.tentFall:GetFloat() or now < (ply.RMPG_TentNext or 0) then return false end
	if RMPG.BootsOn(ply) then return false end
	local p = ply:GetPos()
	return not util.TraceLine({ start = p, endpos = p - UP * 140, filter = ply, mask = MASK_SOLID }).Hit
end

local function Catch(ply, tr)
	Set(ply, CATCH, NULL, tr.HitPos)
	ply.RMPG_TentN = tr.HitNormal
	ply.RMPG_TentCaught = CurTime()
	ply:EmitSound(RMPG.SND.tentCatch, 80, 125)
	Shoot(ply, tr.HitPos, tr.HitNormal)
	RMPG.Notify(ply, "n_tent_caught", nil, 0)
end

-- Ctrl while hanging: down the wall, the end of the rope scraping along it; from a ceiling it just pays out
local function Slide(ply, dt)
	local speed = RMPG.CV.tentSlide:GetFloat()
	local n = ply.RMPG_TentN or UP
	local a = ply:GetNW2Vector("RMPG_TentAt")
	if math.abs(n.z) > 0.6 then
		ply:SetNW2Float("RMPG_TentLen", ply:GetNW2Float("RMPG_TentLen", 0) + speed * dt)
	else
		local at = a - UP * (speed * dt)
		local tr = util.TraceLine({ start = at + n * 6, endpos = at - n * 12, filter = ply, mask = MASK_SOLID })
		if not tr.Hit then
			RMPG.TentRelease(ply)
			return
		end
		a = tr.HitPos
		ply:SetNW2Vector("RMPG_TentAt", a)
	end
	local now = CurTime()
	if now >= (ply.RMPG_TentScrape or 0) then
		ply.RMPG_TentScrape = now + 0.35
		ply:EmitSound(Snd("tentSlide", 5), 72, math.random(95, 120), 0.7)
	end
	if now < (ply.RMPG_TentSpark or 0) then return end
	ply.RMPG_TentSpark = now + 0.08
	local ed = EffectData()
	ed:SetOrigin(a)
	ed:SetNormal(n)
	util.Effect("ManhackSparks", ed, true, true)
end

-- Brings something along: to a point, as fast as it is far. Of a ragdoll only the limb it holds is pulled
local function Haul(ply, e, target, dt)
	local limb = ply.RMPG_TentPhys
	local po = (not e:IsPlayer()) and e:GetPhysicsObjectNum(limb or 0) or nil
	local to = target - ((limb and IsValid(po)) and po:GetPos() or e:WorldSpaceCenter())
	local dist = to:Length()
	local v = to:GetNormalized() * math.min(dist * 5, limb and 700 or 900)
	if e:IsPlayer() then
		e:SetVelocity(v - e:GetVelocity())
	elseif e:IsNPC() or e:IsNextBot() then
		if dist > 30 then
			local from = e:GetPos()
			local tr = util.TraceEntity({ start = from, endpos = from + v * dt, filter = e, mask = MASK_NPCSOLID }, e)
			if not tr.StartSolid then e:SetPos(tr.HitPos) end
		end
	elseif IsValid(po) then
		po:Wake()
		po:SetVelocity(v)
	end
end

hook.Add("Think", "rmpg_tentacle", function()
	local now, dt = CurTime(), FrameTime()
	for _, ply in ipairs(player.GetAll()) do
		if RMPG.HasTent(ply) then
			local mode = RMPG.TentMode(ply)
			if mode ~= 0 and (not ply:Alive() or ply:InVehicle() or ply:GetMoveType() == MOVETYPE_NOCLIP) then
				RMPG.TentRelease(ply)
			elseif (mode == 0 or mode == GRAB) and ply:Alive() and Falling(ply, now) then
				local tr = FindGrip(ply)
				if tr then Catch(ply, tr) end
			elseif mode == 0 then -- nothing to do
			elseif mode == CATCH then
				if ply:IsOnGround() and now - (ply.RMPG_TentCaught or 0) > 0.3 then
					RMPG.TentRelease(ply)
				elseif ply:KeyDown(IN_DUCK) then
					Slide(ply, dt)
				end
			elseif mode == HOOK then
				if ply.RMPG_TentOnEnt and not IsValid(ply:GetNW2Entity("RMPG_TentEnt")) then RMPG.TentRelease(ply) end
			else
				local e = ply:GetNW2Entity("RMPG_TentEnt")
				if not Takeable(e) then
					RMPG.TentRelease(ply)
				else
					local size = ply.RMPG_TentPhys and 0 or e:BoundingRadius()
					local f = ply:GetForward()
					f.z = 0
					f:Normalize()
					if mode == PULL then
						Haul(ply, e, ply:GetPos() + UP * 40 + f * (60 + size), dt)
					else
						Haul(ply, e, ply:GetPos() + UP * 30 - f * (90 + size), dt)
					end
				end
			end
		end
	end
end)

-- Hanging, Jump: the tentacle throws you upwards
hook.Add("KeyPress", "rmpg_tentacle", function(ply, key)
	if key ~= IN_JUMP or RMPG.TentMode(ply) ~= CATCH then return end
	RMPG.TentRelease(ply)
	ply.RMPG_TentNext = CurTime() + 0.5
	local aim = ply:GetAimVector()
	aim.z = 0
	ply:SetVelocity(UP * RMPG.CV.tentThrow:GetFloat() + aim * 160 - ply:GetVelocity())
	ply:EmitSound(Snd("tentThrow", 5), 78, 115)
	ply:EmitSound(Snd("tentServo", 3), 70, 90)
end)

hook.Add("PostPlayerDeath", "rmpg_tentacle", function(ply)
	RMPG.TentRelease(ply)
	if not RMPG.CV.tentKeep:GetBool() then RMPG.RemoveTent(ply) end
end)

concommand.Add("rmpg_tentacle_remove", function(ply)
	if IsValid(ply) and RMPG.HasTent(ply) then
		RMPG.RemoveTent(ply)
		RMPG.Notify(ply, "n_evac_removed", nil, 0)
	end
end)
