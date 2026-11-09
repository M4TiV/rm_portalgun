-- Shared: the ground a neutrino blast throws up. Big chunks of earth fly up from a ring around the blast, break
-- apart high in the air and come down as small burning meteorites. The same seed gives the same pieces on the
-- server (where they land and hurt) and on every client (what you see).
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
RMPG.NEUTRINO_GRAVITY = 600
-- our own rocks (radius ~16): some HL2 rocks miss textures in Garry's Mod
RMPG.NEUTRINO_ROCKS = { "models/rmpg/rock_a.mdl", "models/rmpg/rock_b.mdl" }
local CHUNKS, FRAGS = 16, 5

-- A small random generator of our own, so both sides draw the same numbers
local function Rng(seed)
	local s = seed % 2147483647
	if s <= 0 then s = s + 2147483646 end
	return function(a, b)
		s = (s * 16807) % 2147483647
		return a + (b - a) * (s / 2147483647)
	end
end

local function Ground(pos, down)
	local tr = util.TraceLine({ start = pos, endpos = pos - UP * (down or 4000), mask = MASK_SOLID_BRUSHONLY })
	if tr.Hit and not tr.StartSolid and not tr.HitSky then return tr.HitPos end
end

-- Where a piece thrown from p0 with velocity v0 is t seconds later
function RMPG.NeutrinoAt(p0, v0, t)
	return p0 + v0 * t - UP * (0.5 * RMPG.NEUTRINO_GRAVITY * t * t)
end

-- When and where a piece comes down: solve the fall to a ground height, look at the ground under that spot, again
local function Landing(p0, v0)
	local g = RMPG.NEUTRINO_GRAVITY
	local apex = p0.z + math.max(v0.z, 0) ^ 2 / (2 * g)
	local z = p0.z - 300
	local t, at
	for _ = 1, 3 do
		local disc = v0.z * v0.z + 2 * g * (p0.z - z)
		if disc < 0 then break end
		t = (v0.z + math.sqrt(disc)) / g
		local p = RMPG.NeutrinoAt(p0, v0, t)
		local gp = Ground(Vector(p.x, p.y, apex))
		if not gp then return t, nil end
		at = gp
		z = gp.z
	end
	return t or 4, at
end

-- The pieces of one blast: chunks { from, vel, delay, split, model, size, spin, frags = { { vel, land, at, ... } } }.
-- A chunk leaves the ground delay seconds after the blast and breaks at split seconds of flight; each fragment
-- then flies from there and lands land seconds later at at (nil when it falls out of the map)
function RMPG.NeutrinoPieces(seed, center, R)
	local rnd = Rng(seed)
	local rocks = RMPG.NEUTRINO_ROCKS
	local g = RMPG.NEUTRINO_GRAVITY
	local list = {}
	for i = 1, CHUNKS do
		local a = i / CHUNKS * math.pi * 2 + rnd(-0.2, 0.2)
		local d = rnd(0.1, 0.4) * R
		local dir = Vector(math.cos(a), math.sin(a), 0)
		local spot = center + dir * d
		local from = Ground(spot + UP * 200, 2000) or spot
		local c = {
			from = from,
			vel = dir * rnd(120, 320) + UP * rnd(800, 1150),
			delay = rnd(0.05, 0.6),
			split = rnd(1.0, 1.5),
			model = rocks[math.floor(rnd(1, #rocks + 1))],
			size = rnd(2.4, 4),
			spin = Angle(rnd(-220, 220), rnd(-220, 220), rnd(-220, 220)),
			frags = {},
		}
		local sp = RMPG.NeutrinoAt(c.from, c.vel, c.split)
		local sv = c.vel - UP * (g * c.split)
		c.splitPos = sp
		for k = 1, FRAGS do
			local fv = sv + Vector(rnd(-1, 1), rnd(-1, 1), rnd(-0.3, 0.7)) * rnd(160, 420)
			local f = {
				vel = fv,
				model = rocks[math.floor(rnd(1, #rocks + 1))],
				size = rnd(0.6, 1.2),
				spin = Angle(rnd(-400, 400), rnd(-400, 400), rnd(-400, 400)),
			}
			f.land, f.at = Landing(sp, fv)
			c.frags[k] = f
		end
		list[i] = c
	end
	return list
end
