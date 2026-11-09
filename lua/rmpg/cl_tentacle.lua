-- Client: the tentacle itself, steel links on ball joints from a plate on the back to a claw of five wires. While combat
-- mode is on it stands beside the player and clacks its wires now and then. When it reaches out the links run out of the
-- back along a rope's curve, counted from the claw, so reeling in draws them back in. Sounds of the claw are client side,
-- the rest come from the server (rmpg/sh_tentacle.lua). The parts are built by dev/model_src/build_tentacle.py.
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local LINK, MAX_LINKS = 30, 40 -- length of the link model, and how many at most: past that they are stretched
local STEPS = 24               -- points on the rope's curve
local OUT, BACK = 0.16, 0.22   -- seconds to reach out, and to be drawn in
local HUB = 4.6                -- length of the claw's hub
local CLICK = 0.17             -- one clack of the wires
-- The resting pose, joint after joint, in units along (out of the back, up the spine, to the right) from the plate
local IDLE = { Vector(28, 8, 3), Vector(13.4, 34, 5), Vector(-15.6, 31, 9) }
local RATE = { 16, 11, 8 }     -- how quickly each joint follows: the far ones lag behind a turn

local PARTS = {}
local SCALE, MAT = Vector(1, 1, 1), Matrix()

local function Part(name)
	local e = PARTS[name]
	if IsValid(e) then return e end
	e = ClientsideModel("models/rmpg/tent_" .. name .. ".mdl", RENDERGROUP_OPAQUE)
	if not IsValid(e) then return end
	e:SetNoDraw(true)
	PARTS[name] = e
	return e
end

local function Put(name, pos, ang, stretch)
	local e = Part(name)
	if not e then return end
	SCALE.x = stretch or 1
	MAT:Identity()
	MAT:Scale(SCALE)
	e:EnableMatrix("RenderMultiply", MAT)
	e:SetPos(pos)
	e:SetAngles(ang)
	e:InvalidateBoneCache()
	e:SetupBones()
	e:DrawModel()
end

local function FirstPerson(ply)
	return ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer()
end

-- The joint on the plate and the axes of the back. The skin is 2.4 behind the Spine4 bone on the stock models (measured
-- with dev/tools/backmount.py), and which way that is comes from the bone itself, so it stays on a twisted or bent body.
local function Frame(ply)
	local yaw = Angle(0, ply:EyeAngles().y, 0)
	local f = yaw:Forward()
	if FirstPerson(ply) then return EyePos() - f * 7 - UP * 7, -f, UP, yaw:Right() end
	local bone = ply:LookupBone("ValveBiped.Bip01_Spine4") or ply:LookupBone("ValveBiped.Bip01_Spine2")
	local m = bone and ply:GetBoneMatrix(bone)
	if not m then return ply:GetPos() + UP * 56 - f * 6, -f, UP, yaw:Right() end
	local back = m:GetRight()
	if back:Dot(f) > 0 then back = -back end
	local up = m:GetForward()
	return m:GetTranslation() + back * 4.4, back, up, up:Cross(back)
end

-- Now and then it clacks the wires, a few times in a row. Gives how far open they are, in degrees
local function Clack(ply, now)
	local i = (now - (ply.RMPG_ClackT or 0)) / CLICK
	if i >= (ply.RMPG_ClackN or 0) then
		if now >= (ply.RMPG_ClackNext or 0) then
			ply.RMPG_ClackT, ply.RMPG_ClackN = now, math.random(2, 4)
			ply.RMPG_ClackDone = -1
			ply.RMPG_ClackNext = now + math.Rand(1.8, 5)
			ply:EmitSound(string.format(RMPG.SND.tentServo, math.random(1, 3)), 52, math.random(105, 120), 0.25)
		end
		return 16 + math.sin(now * 1.7) * 4
	end
	local k = math.floor(i)
	if k ~= ply.RMPG_ClackDone then
		ply.RMPG_ClackDone = k
		ply:EmitSound(RMPG.SND.tentClick, 55, math.random(115, 135), 0.4)
	end
	return Lerp(math.abs(math.sin((i % 1) * math.pi)), 16, -14)
end

-- Once a frame, though the drawing hook runs for every view: the joints follow, it grows out or folds away
local function Step(ply, now, back, up, right)
	local frame = FrameNumber()
	if ply.RMPG_TentFrame == frame then return end
	ply.RMPG_TentFrame = frame
	local dt = math.min(RealFrameTime(), 0.1)
	local rel = ply.RMPG_TentRel
	if not rel then
		rel = { Vector(), Vector(), Vector() }
		ply.RMPG_TentRel = rel
	end
	local t = now * 1.1 + ply:EntIndex() * 1.7
	local trail = ply:GetVelocity() * 0.012
	for i, p in ipairs(IDLE) do
		local s = 0.3 * i * i + 0.4
		local want = back * (p.x + math.sin(t + i) * s) + up * (p.y + math.sin(t * 1.3 + i * 2) * s) + right * (p.z + math.cos(t * 0.8 + i) * s) - trail * (i / 3)
		rel[i] = LerpVector(1 - math.exp(-RATE[i] * dt), rel[i], want)
	end
	local busy = RMPG.TentMode(ply) ~= 0 or now - (ply.RMPG_TentSeen or -9) < BACK
	local want = (busy or ply:GetNW2Bool("RMPG_Combat", false)) and 1 or 0
	local show = math.Approach(ply.RMPG_TentShow or 0, want, dt * (want > 0 and 7 or 3.5))
	ply.RMPG_TentShow = show
	ply.RMPG_TentOpen = (show > 0.9 and not busy) and Clack(ply, now) or 16
end

-- The rope's middle line: from the back up over the head, then to the claw. It hangs and moves a little, less the tighter
-- it is held
local function Curve(from, via, to, slack, phase)
	local span = to - from
	local len = span:Length()
	local side = span:Cross(UP)
	if side:LengthSqr() < 1 then side = Vector(1, 0, 0) end
	side:Normalize()
	local amp, sag = (2 + len * 0.02) * slack, len * 0.06 * slack
	local c = {}
	for i = 0, STEPS do
		local t = i / STEPS
		local bow = math.sin(t * math.pi)
		c[i] = LerpVector(t, LerpVector(t, from, via), LerpVector(t, via, to)) + side * (math.sin(t * 9 + phase) * amp * bow) - UP * (sag * bow)
	end
	return c
end

-- The joints along a curve, claw first. A last short link is left at the back, so links go in there and not everywhere
local function Joints(c)
	local total = 0
	for i = 1, STEPS do total = total + c[i - 1]:Distance(c[i]) end
	local step = math.max(LINK, total / MAX_LINKS)
	local out = { c[STEPS] }
	local want, run = step, 0
	for i = STEPS, 1, -1 do
		local a, b = c[i], c[i - 1]
		local seg = a:Distance(b)
		while seg > 0 and run + seg >= want do
			out[#out + 1] = LerpVector((want - run) / seg, a, b)
			want = want + step
		end
		run = run + seg
	end
	if out[#out]:DistToSqr(c[0]) > 1 then out[#out + 1] = c[0] end
	return out
end

local function DrawLinks(joints)
	for i = #joints, 2, -1 do
		local a = joints[i]
		local d = joints[i - 1] - a
		local len = d:Length()
		local ang = d:Angle()
		Put("ball", a, ang)
		if len > 0.5 then Put("link", a, ang, len / LINK) end
	end
end

local function DrawClaw(pos, dir, open, now)
	local ang = dir:Angle()
	Put("claw", pos, ang)
	local tip = pos + dir * HUB
	for i = 1, 5 do
		local a = Angle(ang.p, ang.y, ang.r)
		a:RotateAroundAxis(a:Forward(), i * 72)
		local at = tip - a:Right() * 1.4
		a:RotateAroundAxis(a:Up(), open + math.sin(i * 2.1 + now * 2.3) * 3)
		Put("wire", at, a)
	end
end

local function Draw(ply, now)
	local root, back, up, right = Frame(ply)
	Step(ply, now, back, up, right)
	local fp = FirstPerson(ply)
	if not fp then Put("mount", root - back * 2, back:Angle()) end
	local show = ply.RMPG_TentShow
	if show <= 0.01 then return end
	local mode = RMPG.TentMode(ply)
	local to, k = nil, 1
	if mode ~= 0 then
		to = RMPG.TentAnchor(ply)
		ply.RMPG_TentTo, ply.RMPG_TentSeen = to, now
		k = math.Clamp((now - ply:GetNW2Float("RMPG_TentT", 0)) / OUT, 0, 1)
	elseif ply.RMPG_TentSeen and now - ply.RMPG_TentSeen < BACK then
		to = ply.RMPG_TentTo
		k = 1 - (now - ply.RMPG_TentSeen) / BACK
	end
	local rel = ply.RMPG_TentRel
	local rest = root + rel[3] * show
	if not to then
		local elbow = root + rel[2] * show
		DrawLinks({ rest, elbow, root + rel[1] * show, root })
		DrawClaw(rest, (rest - elbow):GetNormalized(), ply.RMPG_TentOpen, now)
		return
	end
	local from = root
	if fp then
		local a = EyeAngles()
		from = EyePos() + a:Right() * 9 - a:Up() * 13 - a:Forward() * 4
	end
	local tip = LerpVector(k * k * (3 - 2 * k), rest, to)
	local via = fp and LerpVector(0.3, from, tip) or from + up * 50 + back * 4
	local slack = (mode == RMPG.TENT_HOOK or mode == RMPG.TENT_CATCH) and 0.25 or 1
	local c = Curve(from, via, tip, slack, now * 5 + ply:EntIndex())
	local dir = (c[STEPS] - c[STEPS - 2]):GetNormalized()
	c[STEPS] = c[STEPS] - dir * HUB
	DrawLinks(Joints(c))
	DrawClaw(c[STEPS], dir, (k < 1 or mode == 0) and 34 or -9, now)
end

hook.Add("PostDrawOpaqueRenderables", "rmpg_tentacle", function(depth, sky)
	if depth or sky then return end
	local now = CurTime()
	for _, ply in ipairs(player.GetAll()) do
		if RMPG.HasTent(ply) and ply:Alive() and not ply:IsDormant() and not ply:GetNoDraw() then Draw(ply, now) end
	end
end)
