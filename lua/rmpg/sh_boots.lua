-- Gravity boots (weapon_rmpg_grav_boots turns them on): walls and ceilings become the floor. Walk into a wall and you are
-- standing on it, walk over an edge and you go round it. Source's player is an upright box that falls along -Z, so while
-- the boots are on the player's hull is a cube around their middle (it fits any way up), Move does its own walking along
-- the surface under the feet (RMPG_BootsUp), and the client turns the camera and the whole skeleton to match.
-- EyeAngles stay the real direction you look in and the real eye position is moved along the new up, so shots, E, tools
-- and the portal gun all work from where the camera is. The server's hitboxes cannot turn over, so the player stops
-- being solid and rmpg_boots_body stands in for the body.
RMPG = RMPG or {}
RMPG.BOOTS = "weapon_rmpg_grav_boots"

local UP = Vector(0, 0, 1)
local HALF, EYES, EYES_DUCK, STEP, SNAP = 16, 64, 28, 18, 20
local GRAVITY, AIR_RESET = 700, 1.5 -- falling "down" towards the surface; after that long in the air down is down again
local TILT = 0.94 -- a slope gentler than this (about 20 degrees) is walked as it is, the floor does not tip with every bump

local function BodyScale(ply) return ply:GetNW2Float("RMPG_Scale", 1) end

function RMPG.BootsOn(ply) return IsValid(ply) and ply:GetNW2Bool("RMPG_BootsOn") end
function RMPG.BootsUp(ply) return ply:GetNW2Vector("RMPG_BootsUp", UP) end

-- How far the cube's middle is from a surface with this normal
local function Extent(n, h)
	return h * (math.abs(n.x) + math.abs(n.y) + math.abs(n.z))
end

-- v turned about a unit axis
local function Rotate(v, axis, rad)
	local c, s = math.cos(rad), math.sin(rad)
	return v * c + axis:Cross(v) * s + axis * (axis:Dot(v) * (1 - c))
end

-- v turned by the rotation that takes a onto b
local function Turn(v, a, b, part)
	local axis = a:Cross(b)
	local s, c = axis:Length(), a:Dot(b)
	if s < 0.0001 then
		if c > 0 then return v end
		axis = a:Cross(math.abs(a.z) < 0.9 and UP or Vector(1, 0, 0))
		axis:Normalize()
		return Rotate(v, axis, math.pi * (part or 1))
	end
	return Rotate(v, axis / s, math.atan2(s, c) * (part or 1))
end

local function BodyHull(ply, on)
	if ply.RMPG_BootsHull == on then return end
	ply.RMPG_BootsHull = on
	if on then
		local h = HALF * BodyScale(ply)
		local mins, maxs = Vector(-h, -h, -h), Vector(h, h, h)
		ply:SetHull(mins, maxs)
		ply:SetHullDuck(mins, maxs)
	else
		RMPG.ApplyBodyScale(ply, BodyScale(ply))
	end
end

local sweep = { mask = MASK_PLAYERSOLID, collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT }
local function Sweep(ply, from, to, h)
	sweep.start, sweep.endpos = from, to
	sweep.filter = { ply, ply:GetNW2Entity("RMPG_BootBody") }
	sweep.mins, sweep.maxs = Vector(-h, -h, -h), Vector(h, h, h)
	return util.TraceHull(sweep)
end

-- Where the soles are
function RMPG.BootsFeet(ply, up)
	return ply:GetPos() - up * Extent(up, HALF * BodyScale(ply))
end

-- How far the eyes are from the cube's middle: their height, less if a low ceiling is in the way
local function EyeReach(ply, pos, up, duck)
	local s = BodyScale(ply)
	local d = (duck and EYES_DUCK or EYES) * s - Extent(up, HALF * s)
	local tr = util.TraceLine({ start = pos, endpos = pos + up * (d + 6), mask = MASK_SOLID_BRUSHONLY })
	return tr.Hit and math.max(tr.Fraction * (d + 6) - 6, 1) or d
end

-- An upright portal in front of someone standing on a surface: "upright" means along their up
function RMPG.BootsFrontPlacement(ply)
	local up = RMPG.BootsUp(ply)
	local feet = RMPG.BootsFeet(ply, up)
	local aim = select(2, RMPG.Aim(ply)) -- in VR: along the gun in the hand
	local fwd = aim - up * aim:Dot(up)
	if fwd:LengthSqr() < 0.01 then return nil end
	fwd:Normalize()
	local start = feet + up * 40
	local tr = util.TraceHull({ start = start, endpos = start + fwd * 110, mins = Vector(-12, -12, -12), maxs = Vector(12, 12, 12), filter = ply, mask = MASK_PLAYERSOLID_BRUSHONLY })
	local dist = tr.Fraction * 110
	if dist < 56 then return nil end
	local spot = start + fwd * (dist - (tr.Hit and 16 or 0))
	local down = util.TraceLine({ start = spot, endpos = spot - up * 300, mask = MASK_PLAYERSOLID_BRUSHONLY, filter = ply })
	local ground = down.Hit and down.HitPos or (feet + fwd * dist)
	return ground + up * (RMPG.Radius() * RMPG.ShapeBottom - 4), (-fwd):AngleEx(up), true
end

local function Speed(ply, mv)
	local s = mv:KeyDown(IN_SPEED) and ply:GetRunSpeed() or ply:GetWalkSpeed()
	if mv:KeyDown(IN_WALK) then s = ply:GetSlowWalkSpeed() end
	if mv:KeyDown(IN_DUCK) then s = s * ply:GetCrouchedWalkSpeed() end
	return s
end

-- Up a stair instead of up the wall: over the step, along, back down onto something flat. Returns where, or nil.
local function StepUp(ply, pos, up, move, h, s)
	local flat = move - up * move:Dot(up)
	local len = flat:Length()
	if len < 0.01 then return end
	flat = flat / len
	local top = Sweep(ply, pos, pos + up * (STEP * s), h)
	if top.StartSolid then return end
	local along = Sweep(ply, top.HitPos, top.HitPos + flat * math.max(len, 3), h)
	if along.StartSolid or along.Fraction < 0.25 then return end
	local down = Sweep(ply, along.HitPos, along.HitPos - up * (STEP * s + 1), h)
	if down.Hit and not down.StartSolid and down.HitNormal:Dot(up) > 0.7 then return down.HitPos end
end

-- Walked off an edge with nothing under the feet: is there a face round the corner to carry on along?
local function RoundCorner(ply, pos, up, vel, h)
	local dir = vel - up * vel:Dot(up)
	if dir:LengthSqr() < 1 then return end
	dir:Normalize()
	local ext = Extent(up, h)
	local from = pos - up * (ext + 2)
	local tr = util.TraceLine({ start = from, endpos = from - dir * (ext * 2 + 12), mask = MASK_PLAYERSOLID, filter = ply })
	if not tr.Hit or tr.HitSky or tr.StartSolid or tr.HitNormal:Dot(dir) < 0.5 then return end
	local n = tr.HitNormal
	local np = tr.HitPos + n * (Extent(n, h) + 1)
	if Sweep(ply, np, np, h).Hit then return end
	return np, n
end

local function BootsMove(ply, mv)
	local dt = FrameTime()
	local s = BodyScale(ply)
	local h = HALF * s
	local up = RMPG.BootsUp(ply)
	local pos, vel = mv:GetOrigin(), mv:GetVelocity()
	local was = ply.RMPG_BootsGround

	-- out of a portal: whichever way that faces, down is down until the next surface
	if (ply.RMPG_LastTP or 0) > (ply.RMPG_BootsTP or 0) then
		ply.RMPG_BootsTP = ply.RMPG_LastTP
		up, was = UP, false
		ply.RMPG_BootsAir = 0
	end

	-- what is under the feet (a little further when walking, so stairs and bumps down do not count as falling)
	local under = Sweep(ply, pos, pos - up * ((was and SNAP or 3) * s), h)
	local ground = under.Hit and not under.StartSolid and not under.HitSky and under.HitNormal:Dot(up) > 0.5
	if ground then
		if under.HitNormal:Dot(up) < TILT then up = under.HitNormal end
		pos = under.HitPos + under.HitNormal * 0.05
		vel = vel - up * vel:Dot(up)
	elseif was then
		local np, n = RoundCorner(ply, pos, up, vel, h)
		if np then
			vel = Turn(vel, up, n)
			pos, up, ground = np, n, true
		end
	end

	-- where the keys want to go, along the surface
	local look = mv:GetMoveAngles():Forward()
	local fwd = look - up * look:Dot(up)
	if fwd:LengthSqr() < 0.0004 then
		fwd = mv:GetMoveAngles():Up() * (look:Dot(up) > 0 and -1 or 1)
		fwd = fwd - up * fwd:Dot(up)
	end
	fwd:Normalize()
	local right = fwd:Cross(up)
	local wish = fwd * mv:GetForwardSpeed() + right * mv:GetSideSpeed()
	if wish:LengthSqr() > 1 then wish = wish:GetNormalized() * Speed(ply, mv) else wish = vector_origin end

	if ground then
		vel = LerpVector(1 - math.exp(-12 * dt), vel, wish)
		if mv:KeyPressed(IN_JUMP) then
			vel = vel + up * ply:GetJumpPower()
			ground = false
		end
		ply.RMPG_BootsAir = 0
	else
		vel = vel - up * (GRAVITY * dt) + wish * (1.5 * dt)
		ply.RMPG_BootsAir = (ply.RMPG_BootsAir or 0) + dt
		if ply.RMPG_BootsAir > AIR_RESET then up = UP end
	end

	-- move, sliding along what is in the way; a wall walked into becomes the new floor
	local left = dt
	for _ = 1, 4 do
		local move = vel * left
		if move:LengthSqr() < 0.0001 then break end
		local tr = Sweep(ply, pos, pos + move, h)
		if tr.StartSolid then
			pos = pos + up
			break
		end
		pos = tr.HitPos
		if not tr.Hit then break end
		left = left * (1 - tr.Fraction)
		local n = tr.HitNormal
		if n:Dot(up) < 0.7 and vel:GetNormalized():Dot(n) < -0.2 and not tr.HitSky then
			local stair = ground and StepUp(ply, pos, up, move, h, s)
			if stair then
				pos = stair
			else
				vel = Turn(vel, up, n)
				up, ground = n, true
				break
			end
		else
			vel = vel - n * vel:Dot(n)
		end
	end

	mv:SetOrigin(pos)
	mv:SetVelocity(vel)
	ply.RMPG_BootsGround = ground
	if up ~= RMPG.BootsUp(ply) then ply:SetNW2Vector("RMPG_BootsUp", up) end
	-- the real eye position: SetViewOffset only says where it should settle, and the walking that would do so is ours now
	ply:SetCurrentViewOffset(up * EyeReach(ply, pos, up, mv:KeyDown(IN_DUCK)))
	if ground then
		ply:AddFlags(FL_ONGROUND)
	else
		ply:RemoveFlags(FL_ONGROUND)
	end
	if SERVER and ground and vel:LengthSqr() > 6400 and CurTime() >= (ply.RMPG_BootsStep or 0) then
		ply.RMPG_BootsStep = CurTime() + math.Clamp(90 / vel:Length(), 0.22, 0.6)
		ply:EmitSound(string.format(RMPG.SND.bootsStep, math.random(1, 4)), 62, math.random(92, 108))
	end
end

hook.Add("SetupMove", "rmpg_boots", function(ply)
	BodyHull(ply, RMPG.BootsOn(ply))
end)

-- A body size change (Operation Phoenix) resets the hull: make the cube again
hook.Add("EntityNetworkedVarChanged", "rmpg_boots_scale", function(ent, name)
	if name == "RMPG_Scale" and IsValid(ent) and ent:IsPlayer() then ent.RMPG_BootsHull = nil end
end)

hook.Add("Move", "rmpg_boots", function(ply, mv)
	if not RMPG.BootsOn(ply) or not ply:Alive() or ply:GetMoveType() ~= MOVETYPE_WALK then return end
	if SERVER and not ply:HasWeapon(RMPG.BOOTS) then
		RMPG.BootsSet(ply, false)
		return
	end
	BootsMove(ply, mv)
	return true
end)

-- The legs walk by the speed along the surface, whichever way that is
hook.Add("CalcMainActivity", "rmpg_boots", function(ply, vel)
	if not RMPG.BootsOn(ply) then return end
	local sp = vel:LengthSqr()
	local act
	if not ply:IsOnGround() then
		act = ACT_MP_JUMP
	elseif ply:KeyDown(IN_DUCK) then
		act = sp > 0.25 and ACT_MP_CROUCHWALK or ACT_MP_CROUCH_IDLE
	else
		act = sp > 22500 and ACT_MP_RUN or (sp > 0.25 and ACT_MP_WALK or ACT_MP_STAND_IDLE)
	end
	ply.CalcIdeal, ply.CalcSeqOverride = act, -1
	return act, -1
end)

if SERVER then
	function RMPG.BootsSet(ply, on)
		if on == RMPG.BootsOn(ply) then return end
		local h = HALF * BodyScale(ply)
		if on then
			ply:SetNW2Vector("RMPG_BootsUp", UP)
			ply:SetNW2Bool("RMPG_BootsOn", true)
			BodyHull(ply, true)
			-- the origin moves from the feet to the middle of the cube
			ply:SetPos(ply:GetPos() + UP * h)
			ply.RMPG_BootsGround, ply.RMPG_BootsAir = true, 0
			ply.RMPG_BootsTP = ply.RMPG_LastTP
			ply:SetCurrentViewOffset(UP * ((EYES - HALF) * BodyScale(ply)))
			-- bullets and everyone else meet this instead of the upright hitboxes
			local b = ents.Create("rmpg_boots_body")
			if IsValid(b) then
				b.WearerPly = ply
				b:SetPos(ply:GetPos())
				b:SetParent(ply)
				b:Spawn()
				ply:SetNW2Entity("RMPG_BootBody", b)
				ply:SetNotSolid(true)
			end
			ply:EmitSound(RMPG.SND.bootsOn, 65)
		else
			local mid = ply:GetPos()
			ply:SetNW2Bool("RMPG_BootsOn", false)
			ply:SetNW2Vector("RMPG_BootsUp", UP)
			local b = ply:GetNW2Entity("RMPG_BootBody")
			if IsValid(b) then b:Remove() end
			ply:SetNW2Entity("RMPG_BootBody", NULL)
			ply:SetNotSolid(false)
			BodyHull(ply, false)
			ply:SetCurrentViewOffset(Vector(0, 0, EYES * BodyScale(ply)))
			ply:RemoveFlags(FL_ONGROUND)
			-- find room for the normal, tall body near the middle of the cube; from there gravity takes over
			local mins, maxs = ply:GetHull()
			for _, dz in ipairs({ -h, -h + 8, -h - 8, 0, -h - 16, -h - 32, 8, -h - 48, -h - 56, 24 }) do
				local p = mid + UP * dz
				if not util.TraceHull({ start = p, endpos = p, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = ply }).Hit then
					ply:SetPos(p)
					break
				end
			end
			ply:EmitSound(RMPG.SND.bootsOff, 65)
		end
	end

	local function Off(ply) RMPG.BootsSet(ply, false) end
	hook.Add("PlayerDeath", "rmpg_boots", Off)
	hook.Add("PlayerSilentDeath", "rmpg_boots", Off)
	hook.Add("PlayerSpawn", "rmpg_boots", Off)
	hook.Add("PlayerDisconnected", "rmpg_boots", Off)
	hook.Add("PlayerEnteredVehicle", "rmpg_boots", Off)
	-- noclip is a different kind of walking altogether
	hook.Add("PlayerNoClip", "rmpg_boots", function(ply, on)
		if on then Off(ply) end
	end)

	return
end

---------------------------------------------------------------------------
-- Client: the camera, the mouse, the turned-over body and the boots on the feet
---------------------------------------------------------------------------

local View = { up = Vector(0, 0, 1), on = false }

-- A step of up towards the surface, so a change of floor turns smoothly instead of snapping
local function Ease(cur, want, dt)
	return Turn(cur, cur, want, 1 - math.exp(-dt * 9)):GetNormalized()
end

hook.Add("InputMouseApply", "rmpg_boots", function(cmd, x, y, ang)
	local me = LocalPlayer()
	local on = RMPG.BootsOn(me) and me:Alive() and not me:InVehicle()
	if not on then
		View.on = false
		return
	end
	local want = RMPG.BootsUp(me)
	if not View.on then
		View.on = true
		View.up = want
	end
	-- the view turns with the body when the floor changes, then the mouse moves it in the frame of that floor
	local old = View.up
	local up = Ease(old, want, RealFrameTime())
	View.up = up
	local d = Turn(ang:Forward(), old, up)
	d = Rotate(d, up, -math.rad(x * GetConVar("m_yaw"):GetFloat()))
	local a = math.deg(math.acos(math.Clamp(d:Dot(up), -1, 1)))
	local b = math.Clamp(a + y * GetConVar("m_pitch"):GetFloat(), 3, 177)
	local right = d:Cross(up)
	if right:LengthSqr() > 0.00001 then d = Rotate(d, right:GetNormalized(), -math.rad(b - a)) end
	cmd:SetViewAngles(d:Angle())
	return true
end)

hook.Add("CalcView", "rmpg_boots", function(ply, pos, ang, fov)
	if not RMPG.BootsOn(ply) or not ply:Alive() or ply:InVehicle() or ply:GetViewEntity() ~= ply then return end
	local up = View.on and View.up or RMPG.BootsUp(ply)
	local d = ang:Forward()
	local u = up - d * up:Dot(d)
	if u:LengthSqr() < 0.0001 then u = ang:Up() end
	u:Normalize()
	local base = ply:GetPos()
	View.pos, View.ang = base + up * EyeReach(ply, base, up, ply:KeyDown(IN_DUCK)), d:AngleEx(u)
	return { origin = View.pos, angles = View.ang, fov = fov * (RMPG.PatchFovK or 1) }
end)

hook.Add("CalcViewModelView", "rmpg_boots", function(wep, vm, oldPos, oldAng, pos, ang)
	if not RMPG.BootsOn(LocalPlayer()) or not View.pos then return end
	local p, a = View.pos * 1, View.ang * 1
	if wep.GetViewModelPosition then
		local np, na = wep:GetViewModelPosition(p * 1, a * 1)
		p, a = np or p, na or a
	end
	return p, a
end)

-- Which way a player's body stands (smoothed for other players as well)
local function BodyUp(ply)
	if ply == LocalPlayer() and View.on then return View.up end
	local want = RMPG.BootsUp(ply)
	local t = RealTime()
	local dt = math.min(t - (ply.RMPG_BootsT or t), 0.1)
	ply.RMPG_BootsT = t
	ply.RMPG_BootsView = Ease(ply.RMPG_BootsView or want, want, dt)
	return ply.RMPG_BootsView
end

-- Forward along the surface for someone looking along d
local function Along(d, up, ang)
	local f = d - up * d:Dot(up)
	if f:LengthSqr() < 0.0004 then
		f = ang:Up() * (d:Dot(up) > 0 and -1 or 1)
		f = f - up * f:Dot(up)
	end
	return f:GetNormalized()
end

-- The skeleton comes out standing upright on the cube's middle; turn all of it onto the surface
local function TurnBones(ply, n)
	if not RMPG.BootsOn(ply) or not ply:Alive() then return end
	local up = BodyUp(ply)
	local base = ply:GetPos()
	local ang = ply:EyeAngles()
	local to = Matrix()
	to:SetTranslation(RMPG.BootsFeet(ply, up))
	to:SetAngles(Along(ang:Forward(), up, ang):AngleEx(up))
	local from = Matrix()
	local ra = ply:GetRenderAngles()
	from:SetAngles(Angle(0, ra and ra.y or ang.y, 0))
	from:Invert()
	local m = to * from
	m:Translate(-base)
	-- a bone outside this build (a far LOD leaves fingers out) still holds last frame's turned matrix: turning it again
	-- every frame would carry it further and further away, so only bones near the upright body are turned
	local lim = 200 * BodyScale(ply)
	for i = 0, n - 1 do
		local b = ply:GetBoneMatrix(i)
		if b and b:GetTranslation():DistToSqr(base) < lim * lim then ply:SetBoneMatrix(i, m * b) end
	end
end

hook.Add("PrePlayerDraw", "rmpg_boots", function(ply)
	if not RMPG.BootsOn(ply) then return end
	if not ply.RMPG_BootsCB then
		ply.RMPG_BootsCB = true
		ply:AddCallback("BuildBonePositions", TurnBones)
	end
	-- legs and head in the frame of the surface (the engine only knows the world's)
	local up = BodyUp(ply)
	local ang = ply:EyeAngles()
	local d = ang:Forward()
	local f = Along(d, up, ang)
	local r = f:Cross(up)
	local v = ply:GetVelocity()
	local vf, vr = v:Dot(f), v:Dot(r)
	local sp = math.sqrt(vf * vf + vr * vr)
	ply:SetPoseParameter("move_x", sp > 1 and vf / sp or 0)
	ply:SetPoseParameter("move_y", sp > 1 and vr / sp or 0)
	local pitch = math.deg(math.asin(math.Clamp(d:Dot(up), -1, 1)))
	ply:SetPoseParameter("aim_pitch", pitch)
	ply:SetPoseParameter("head_pitch", pitch)
	ply:SetPoseParameter("aim_yaw", 0)
	ply:SetPoseParameter("head_yaw", 0)
	ply:InvalidateBoneCache()
end)

-- The boots on the feet: a model of our own, not parented to the player. Every time it is drawn its four bones (both
-- feet and toes) are copied from the player's skeleton, which is turned onto the surface already. Parented with
-- EF_BONEMERGE, drawing it drew the player again from inside the player's own drawing, and that loop crashed the game
-- of everyone who could see a player in boots.
local boots = {} -- player -> its boots model
local drawingBoots = false

local function CopyFeet(e, n)
	local ply = e.RMPG_Wearer
	if not IsValid(ply) then return end
	local model = ply:GetModel()
	if e.RMPG_MapModel ~= model then
		local map = {}
		for i = 0, n - 1 do
			local name = e:GetBoneName(i)
			local j = name and ply:LookupBone(name)
			if j then map[i] = j end
		end
		e.RMPG_Map, e.RMPG_MapModel = map, model
	end
	for i, j in pairs(e.RMPG_Map) do
		local m = ply:GetBoneMatrix(j)
		if m then e:SetBoneMatrix(i, m) end
	end
end

local function BootsModel(ply)
	local e = boots[ply]
	if IsValid(e) then return e end
	e = ClientsideModel("models/rmpg/grav_boots.mdl", RENDERGROUP_OPAQUE)
	if not IsValid(e) then return end
	e:SetNoDraw(true)
	e.RMPG_Wearer = ply
	e:AddCallback("BuildBonePositions", CopyFeet)
	boots[ply] = e
	return e
end

local function DropBoots(ply)
	if IsValid(boots[ply]) then boots[ply]:Remove() end
	boots[ply] = nil
end

hook.Add("PostPlayerDraw", "rmpg_boots", function(ply)
	if drawingBoots or not RMPG.BootsOn(ply) or not ply:Alive() then return end
	local e = BootsModel(ply)
	if not IsValid(e) then return end
	drawingBoots = true
	e:SetPos(ply:GetPos())
	e:InvalidateBoneCache()
	e:DrawModel()
	drawingBoots = false
end)

hook.Add("EntityRemoved", "rmpg_boots", function(ent)
	if boots[ent] then DropBoots(ent) end
end)

-- A turned-over player sticks out of the box the engine culls by; boots of whoever took them off (or left) go away
hook.Add("Think", "rmpg_boots_bounds", function()
	for ply in pairs(boots) do
		if not IsValid(ply) or not RMPG.BootsOn(ply) then DropBoots(ply) end
	end
	for _, ply in ipairs(player.GetAll()) do
		local on = RMPG.BootsOn(ply)
		if on ~= (ply.RMPG_BootsWide or false) then
			ply.RMPG_BootsWide = on
			if on then
				ply:SetRenderBounds(Vector(-100, -100, -100), Vector(100, 100, 100))
			else
				ply:SetRenderBounds(Vector(-40, -40, 0), Vector(40, 40, 80))
			end
		end
	end
end)

hook.Add("HUDPaint", "rmpg_boots", function()
	if not RMPG.BootsOn(LocalPlayer()) or not RMPG.CL.hud:GetBool() then return end
	draw.SimpleTextOutlined(RMPG.T("boots_on"), "RMPG_SmallB", ScrW() / 2, ScrH() - 34, Color(255, 170, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)
