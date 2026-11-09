-- Shared portal maths: texture silhouette, frames, transforms and placement
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local S = RMPG.Shape

RMPG.OPEN_TIME = 0.7
RMPG.CLOSE_TIME = 0.45

-- Animation frame of the portal texture at a given time (1-based, same on server and client)
function RMPG.ShapeFrame(t)
	return math.floor((t or CurTime()) * S.fps) % S.frames + 1
end

-- Distance from the texture centre to the visible edge (1 = half of the quad) at angle theta
function RMPG.ShapeRadius(frame, theta)
	local n = S.angles
	local k = (theta / (2 * math.pi) * n) % n
	local i0 = math.floor(k)
	local fr = k - i0
	local row = S.r[frame] or S.r[1]
	local a = row[i0 + 1]
	local b = row[(i0 + 1) % n + 1]
	return a + (b - a) * fr
end

do
	local down = math.floor(S.angles * 0.75) + 1
	local sum = 0
	for i = 1, S.frames do sum = sum + S.r[i][down] end
	-- how far the bottom edge of the texture sits below its centre
	RMPG.ShapeBottom = sum / S.frames
end

-- Portal frame: f = normal (front), ax = texture right seen from the front, ay = texture up
function RMPG.PortalAxes(ang)
	return ang:Forward(), -ang:Right(), ang:Up()
end

-- Opening "plop" with overshoot and the closing shrink
function RMPG.OpenScale(openT, closeT, now)
	now = now or CurTime()
	local o = math.Clamp((now - openT) / RMPG.OPEN_TIME, 0, 1)
	local s = o >= 1 and 1 or 1 - math.exp(-6 * o) * math.cos(9 * o)
	if closeT and closeT > 0 then
		local c = 1 - math.Clamp((now - closeT) / RMPG.CLOSE_TIME, 0, 1)
		s = s * c * c * (3 - 2 * c)
	end
	return math.max(s, 0)
end

-- Going in through the front of one portal = coming out of the front of the other
function RMPG.TransformDir(dir, fromAng, toAng)
	local lf, lr, lu = dir:Dot(fromAng:Forward()), dir:Dot(fromAng:Right()), dir:Dot(fromAng:Up())
	return toAng:Forward() * -lf + toAng:Right() * -lr + toAng:Up() * lu
end

function RMPG.TransformAng(a, fromAng, toAng)
	local f = RMPG.TransformDir(a:Forward(), fromAng, toAng)
	local u = RMPG.TransformDir(a:Up(), fromAng, toAng)
	return f:AngleEx(u)
end

function RMPG.TransformPoint(p, from, to)
	return to:GetPos() + RMPG.TransformDir(p - from:GetPos(), from:GetAngles(), to:GetAngles())
end

-- Half-extent of an entity's bounding box along a direction
function RMPG.Extent(ent, dir, ang)
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local hx, hy, hz = (maxs.x - mins.x) * 0.5, (maxs.y - mins.y) * 0.5, (maxs.z - mins.z) * 0.5
	if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
		-- movement hulls are axis aligned
		return math.abs(dir.x) * hx + math.abs(dir.y) * hy + math.abs(dir.z) * hz
	end
	ang = ang or ent:GetAngles()
	return math.abs(dir:Dot(ang:Forward())) * hx + math.abs(dir:Dot(ang:Right())) * hy + math.abs(dir:Dot(ang:Up())) * hz
end

-- True when any part of the entity's box overlaps the visible (irregular) portal texture
-- extra widens the touch zone in front of / behind the plane, radiusMul grows the silhouette
function RMPG.TouchesPortal(ent, center, ang, half, frame, extra, radiusMul)
	local f, ax, ay = RMPG.PortalAxes(ang)
	local d = ent:WorldSpaceCenter() - center
	local depth = d:Dot(f)
	if math.abs(depth) > RMPG.Extent(ent, f) + 3 + (extra or 0) then return false end
	local px, py = d:Dot(ax), d:Dot(ay)
	local ex, ey = RMPG.Extent(ent, ax), RMPG.Extent(ent, ay)
	-- closest point of the entity's footprint to the portal centre
	local qx = math.Clamp(0, px - ex, px + ex)
	local qy = math.Clamp(0, py - ey, py + ey)
	local r = math.sqrt(qx * qx + qy * qy)
	if r < 0.01 then return true end
	return r <= half * (radiusMul or 1) * RMPG.ShapeRadius(frame, math.atan2(qy, qx))
end

---------------------------------------------------------------------------
-- Placement (shared so the client can preview where the portal will open)
---------------------------------------------------------------------------

function RMPG.GroundBelow(pos, maxDown, filter)
	local tr = util.TraceLine({
		start = pos,
		endpos = pos - UP * (maxDown or 512),
		mask = MASK_PLAYERSOLID_BRUSHONLY,
		filter = filter,
	})
	if tr.Hit and not tr.StartSolid and not tr.HitSky then return tr.HitPos, tr end
end

-- A free-standing portal standing on the ground, front facing faceDir
function RMPG.UprightPortal(ground, faceDir)
	local center = ground + UP * (RMPG.Radius() * RMPG.ShapeBottom - 4)
	return center, faceDir:AngleEx(UP)
end

-- Keeps the texture away from walls/floors around a surface portal
function RMPG.FitOnSurface(pos, ang, half)
	local f, ax, ay = RMPG.PortalAxes(ang)
	local dirs = { ax, -ax, ay, -ay }
	local reach = half * 0.8
	for _ = 1, 2 do
		for _, d in ipairs(dirs) do
			local s = pos + f * 4
			local tr = util.TraceLine({ start = s, endpos = s + d * reach, mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit and not tr.StartSolid then
				pos = pos - d * (reach * (1 - tr.Fraction))
			end
		end
	end
	return pos
end

-- VRMod: the right hand of a player in VR, turned like the hand bone the guns are held by (VRMod sends that bone turned
-- by 180 degrees of roll). Nothing when VRMod is not there or the player is not in VR.
local HAND_FIST, HAND_ANG = Vector(2.6, -1.5, -0.64), Angle(0, 0, 180)
function RMPG.VRHand(ply)
	if not (vrmod and vrmod.IsPlayerInVR and vrmod.GetRightHandPose) or not IsValid(ply) or not ply:IsPlayer() then return end
	if not vrmod.IsPlayerInVR(ply) then return end
	local pos, ang = vrmod.GetRightHandPose(ply)
	if not pos or pos:IsZero() then return end
	return pos, Angle(ang.p, ang.y, ang.r + 180)
end

-- Where a player aims from and along: the eyes, or in VR the gun in the right hand (there the view and the barrel are
-- two different things)
function RMPG.Aim(ply)
	local pos, ang = RMPG.VRHand(ply)
	if pos then
		local p, a = LocalToWorld(HAND_FIST, HAND_ANG, pos, ang)
		return p, a:Forward()
	end
	return ply:GetShootPos(), ply:GetAimVector()
end

if CLIENT then
	-- The local player seen from their own eyes, so their gun is the viewmodel. Not in third person (from any addon:
	-- the camera is simply not at the eyes) and not in VR.
	function RMPG.FirstPerson(ply)
		if ply ~= LocalPlayer() or ply:ShouldDrawLocalPlayer() or ply:GetViewEntity() ~= ply or RMPG.VRHand(ply) then return false end
		return EyePos():DistToSqr(ply:EyePos()) < 24 * 24
	end
end

-- Upright portal in front of the player ("vertical portal" setting)
function RMPG.FrontPlacement(ply)
	if RMPG.BootsOn(ply) then return RMPG.BootsFrontPlacement(ply) end
	local _, fwd = RMPG.Aim(ply)
	fwd.z = 0
	if fwd:LengthSqr() < 0.01 then fwd = ply:GetForward() fwd.z = 0 end
	fwd:Normalize()
	local start = ply:GetPos() + UP * 40
	local tr = util.TraceHull({
		start = start, endpos = start + fwd * 110,
		mins = Vector(-12, -12, -12), maxs = Vector(12, 12, 12),
		filter = ply, mask = MASK_PLAYERSOLID_BRUSHONLY,
	})
	local dist = tr.Fraction * 110
	if dist < 56 then return nil end
	local spot = start + fwd * (dist - (tr.Hit and 16 or 0))
	local ground = RMPG.GroundBelow(spot, 300, ply) or (ply:GetPos() + fwd * dist)
	local c, a = RMPG.UprightPortal(ground, -fwd)
	return c, a, true
end

-- The NPC setting "Ignore Players" (ai_ignoreplayers): worms and visitors leave players alone too
local ignorePlayers
function RMPG.IgnorePlayers()
	ignorePlayers = ignorePlayers or GetConVar("ai_ignoreplayers")
	return ignorePlayers ~= nil and ignorePlayers:GetBool()
end

-- Portal flat on whatever surface the player aims at
function RMPG.SurfacePlacement(ply)
	local start, aim = RMPG.Aim(ply)
	local tr = util.TraceLine({ start = start, endpos = start + aim * 8000, filter = ply, mask = MASK_SHOT })
	if not tr.Hit or tr.HitSky then return nil end
	if not tr.HitWorld then
		-- hit a prop or a creature: open an upright portal on the ground in front of it
		local ground = RMPG.GroundBelow(tr.HitPos - aim * 40 + UP * 10, 600, ply)
		if not ground then return nil end
		local dir = -aim
		dir.z = 0
		dir:Normalize()
		local c, a = RMPG.UprightPortal(ground, dir)
		return c, a, true
	end
	local n = tr.HitNormal
	local up
	if math.abs(n.z) > 0.7 then
		-- floor / ceiling: the top of the texture points away from the shooter
		up = Vector(aim.x, aim.y, 0)
		if up:LengthSqr() < 0.001 then up = ply:GetForward() end
		up:Normalize()
	else
		up = Vector(0, 0, 1)
	end
	up = up - n * up:Dot(n)
	up:Normalize()
	local ang = n:AngleEx(up)
	local pos = RMPG.FitOnSurface(tr.HitPos + n * 1.5, ang, RMPG.Radius())
	return pos, ang, false
end

function RMPG.ComputeEntry(ply, vertical)
	if vertical then
		local c, a, free = RMPG.FrontPlacement(ply)
		if c then return c, a, free end
	end
	local c, a, free = RMPG.SurfacePlacement(ply)
	if c then return c, a, free end
	return RMPG.FrontPlacement(ply)
end

-- Dimension-style code for a position, e.g. "C-137"
function RMPG.MakeCode(pos)
	local h = tonumber(util.CRC(string.format("%d_%d_%d", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)))) or 0
	local letters = { "C", "J", "D", "K", "Z", "R" }
	return letters[h % #letters + 1] .. "-" .. (100 + math.floor(h / 7) % 900)
end

-- What the server forbade Meeseeks: whole jobs, and things to make (kind: 0 prop, 1 weapon, 2 entity, 3 NPC). The lists
-- hold parts of names, so "combine" bans every model or class with that in it.
local BANS = { [0] = "mrBanProps", "mrBanWeapons", "mrBanEnts", "mrBanNPCs" }

function RMPG.MrBanned(kind, value)
	local cv = RMPG.CV[BANS[kind] or ""]
	if not cv then return false end
	value = string.lower(value or "")
	for part in string.gmatch(cv:GetString(), "[^,]+") do
		part = string.Trim(string.lower(part))
		if part ~= "" and string.find(value, part, 1, true) then return true end
	end
	return false
end

function RMPG.MrJobOff(id)
	for part in string.gmatch(RMPG.CV.mrBanJobs:GetString(), "[^,]+") do
		if tonumber(part) == id then return true end
	end
	return false
end
