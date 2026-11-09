-- Client: procedural portal gun models, built from meshes and cartoon shaded.
--   Variant 0 "classic": flat C-137 body, glass dome with fluid and the yellow core, red LED display, curved grip
--   Variant 1 "prime":   Rick Prime gun, emitter block with a 3x3 LED matrix, green dome, open frame, red button
--   Variants 2..6 are built from the data in cl_model_parts.lua: Evil Morty's gun, the prototype, the kids' toy gun and
--   two from Rick's cabinet (with a vial, with an antenna).
-- Every gun's shell is drawn in the "paint" layer, which takes the body colour the player picked (or the gun's own).
--
-- Model space: +X forward (emitter), +Y left, +Z up. Units are "model units";
-- a frame {O, F, L, U, s} places the model in the world (s = world units per model unit).
RMPG = RMPG or {}
RMPG.Model = RMPG.Model or {}
local Model = RMPG.Model
local M = RMPG.Mat

local WHITE = Vector(1, 1, 1)
local LIGHT = Vector(-0.3, 0.5, 0.82):GetNormalized()

local C_WHITE  = { 234, 236, 240 }
local C_SHELL  = { 222, 226, 232 }
local C_GRIP   = { 208, 212, 218 }
local C_SEAM   = { 150, 156, 164 }
local C_MID    = { 146, 155, 168 }
local C_DARK   = { 74, 80, 92 }
local C_BLACK  = { 26, 28, 32 }
local C_SCREEN = { 12, 8, 8 }
local C_PANEL  = { 36, 40, 48 }
local C_RED    = { 228, 34, 30 }
local C_YELLOW = { 246, 226, 74 }
local C_CORE   = { 250, 248, 240 } -- the core: tinted with the portal colour when drawn (CoreTint)
local C_HULL   = { 12, 12, 16 }
-- the paint layer is baked white (or a little darker) and tinted with the body colour when drawn
local PAINT      = { 255, 255, 255 }
local PAINT2     = { 242, 242, 242 }
local PAINT_GRIP = { 227, 227, 227 }
local PAINT_STOCK = Vector(234, 236, 240) -- the white of the classic and Prime guns

---------------------------------------------------------------------------
-- Geometry builder
---------------------------------------------------------------------------

local B = {}
B.__index = B

local function NewBuilder()
	return setmetatable({ layers = {} }, B)
end

function B:Tri(layer, a, b, c, col)
	local L = self.layers[layer]
	if not L then L = {} self.layers[layer] = L end
	L[#L + 1] = { a[1], a[2], col }
	L[#L + 1] = { b[1], b[2], col }
	L[#L + 1] = { c[1], c[2], col }
end

function B:Grid(grid, nu, nv, col, layer)
	for j = 0, nv - 1 do
		for i = 0, nu - 1 do
			local a, b, c, d = grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]
			self:Tri(layer, a, b, c, col)
			self:Tri(layer, a, c, d, col)
		end
	end
end

local function spow(v, e)
	local s = v < 0 and -1 or 1
	return s * math.abs(v) ^ e
end

-- Superellipsoid: e < 1 gives a rounded box, e = 1 an ellipsoid
function B:Super(center, size, e1, e2, col, layer, rot, nu, nv)
	nu, nv = nu or 28, nv or 14
	local grid = {}
	for j = 0, nv do
		local eta = -math.pi / 2 + math.pi * j / nv
		local ce, se = math.cos(eta), math.sin(eta)
		local row = {}
		for i = 0, nu do
			local w = -math.pi + 2 * math.pi * i / nu
			local cw, sw = math.cos(w), math.sin(w)
			local p = Vector(size.x * spow(ce, e1) * spow(cw, e2), size.y * spow(ce, e1) * spow(sw, e2), size.z * spow(se, e1))
			local n = Vector(spow(ce, 2 - e1) * spow(cw, 2 - e2) / size.x, spow(ce, 2 - e1) * spow(sw, 2 - e2) / size.y, spow(se, 2 - e1) / size.z)
			if n:LengthSqr() < 1e-10 then n = Vector(0, 0, se < 0 and -1 or 1) end
			n:Normalize()
			if rot then p:Rotate(rot) n:Rotate(rot) end
			row[i] = { center + p, n }
		end
		grid[j] = row
	end
	self:Grid(grid, nu, nv, col, layer or "opaque")
end

-- Surface of revolution around local X. profile = { {x, r, sharp?}, ... }
function B:Lathe(origin, rot, profile, seg, col, layer)
	seg = seg or 24
	local np = #profile
	local segN = {}
	for k = 1, np - 1 do
		local dx = profile[k + 1][1] - profile[k][1]
		local dr = profile[k + 1][2] - profile[k][2]
		local l = math.sqrt(dx * dx + dr * dr)
		if l < 1e-6 then l = 1 end
		segN[k] = { -dr / l, dx / l }
	end
	local function vn(idx, k)
		if profile[idx][3] then return segN[k] end
		local a = segN[idx - 1] or segN[idx]
		local b = segN[idx] or segN[idx - 1]
		local nx, nr = a[1] + b[1], a[2] + b[2]
		local l = math.sqrt(nx * nx + nr * nr)
		if l < 1e-6 then return segN[k] end
		return { nx / l, nr / l }
	end
	local function V(pt, nn, ang)
		local cy, sy = math.cos(ang), math.sin(ang)
		local p = Vector(pt[1], pt[2] * cy, pt[2] * sy)
		local n = Vector(nn[1], nn[2] * cy, nn[2] * sy)
		if rot then p:Rotate(rot) n:Rotate(rot) end
		return { origin + p, n }
	end
	for k = 1, np - 1 do
		local n0, n1 = vn(k, k), vn(k + 1, k)
		for i = 0, seg - 1 do
			local a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
			local A, Bv = V(profile[k], n0, a0), V(profile[k], n0, a1)
			local C, D = V(profile[k + 1], n1, a1), V(profile[k + 1], n1, a0)
			self:Tri(layer or "opaque", A, Bv, C, col)
			self:Tri(layer or "opaque", A, C, D, col)
		end
	end
end

-- Ring around local X
function B:Torus(origin, rot, R, r, nu, nv, col, layer)
	local grid = {}
	for j = 0, nv do
		local bta = 2 * math.pi * j / nv
		local row = {}
		for i = 0, nu do
			local a = 2 * math.pi * i / nu
			local p = Vector(r * math.sin(bta), (R + r * math.cos(bta)) * math.cos(a), (R + r * math.cos(bta)) * math.sin(a))
			local n = Vector(math.sin(bta), math.cos(bta) * math.cos(a), math.cos(bta) * math.sin(a))
			if rot then p:Rotate(rot) n:Rotate(rot) end
			row[i] = { origin + p, n }
		end
		grid[j] = row
	end
	self:Grid(grid, nu, nv, col, layer or "opaque")
end

-- Flat-shaded hexahedron: p[1..4] bottom (back-right, front-right, front-left, back-left), p[5..8] top
local HEX_FACES = { { 1, 2, 3, 4 }, { 5, 8, 7, 6 }, { 2, 6, 7, 3 }, { 1, 4, 8, 5 }, { 1, 5, 6, 2 }, { 4, 3, 7, 8 } }
function B:Hex(p, col, layer)
	local c = Vector(0, 0, 0)
	for i = 1, 8 do c = c + p[i] end
	c = c / 8
	for _, f in ipairs(HEX_FACES) do
		local a, b, cc, d = p[f[1]], p[f[2]], p[f[3]], p[f[4]]
		local n = (cc - a):Cross(d - b)
		n:Normalize()
		if n:Dot((a + b + cc + d) / 4 - c) < 0 then n = -n end
		local A, Bv, C, D = { a, n }, { b, n }, { cc, n }, { d, n }
		self:Tri(layer or "opaque", A, Bv, C, col)
		self:Tri(layer or "opaque", A, C, D, col)
	end
end

-- Tube along a curve in the XZ plane with a super-elliptic cross-section.
-- pts = { {x, z, halfWidthY, halfThickness}, ... }
function B:SweepXZ(pts, e, seg, col, layer)
	local Y = Vector(0, 1, 0)
	local n = #pts
	local grid, centers, tangents = {}, {}, {}
	for i = 1, n do
		local prev, nxt = pts[math.max(i - 1, 1)], pts[math.min(i + 1, n)]
		local t = Vector(nxt[1] - prev[1], 0, nxt[2] - prev[2])
		t:Normalize()
		local side = Y:Cross(t)
		local p = Vector(pts[i][1], 0, pts[i][2])
		local a, b = pts[i][3], pts[i][4]
		local row = {}
		for j = 0, seg do
			local th = 2 * math.pi * j / seg
			local cs, sn = math.cos(th), math.sin(th)
			local nrm = Y * (spow(cs, 2 - e) / a) + side * (spow(sn, 2 - e) / b)
			nrm:Normalize()
			row[j] = { p + Y * (a * spow(cs, e)) + side * (b * spow(sn, e)), nrm }
		end
		grid[i - 1] = row
		centers[i], tangents[i] = p, t
	end
	self:Grid(grid, seg, n - 1, col, layer or "opaque")
	for _, k in ipairs({ 1, n }) do
		local nrm = k == 1 and -tangents[k] or tangents[k]
		local row = grid[k - 1]
		for j = 0, seg - 1 do
			self:Tri(layer or "opaque", { centers[k], nrm }, { row[j][1], nrm }, { row[j + 1][1], nrm }, col)
		end
	end
end

-- Thin round tube along any 3D polyline (tendrils)
function B:Tube(pts, radii, seg, col, layer)
	local n = #pts
	local grid = {}
	for i = 1, n do
		local t = pts[math.min(i + 1, n)] - pts[math.max(i - 1, 1)]
		t:Normalize()
		local ref = math.abs(t.z) > 0.9 and Vector(1, 0, 0) or Vector(0, 0, 1)
		local n1 = t:Cross(ref)
		n1:Normalize()
		local n2 = t:Cross(n1)
		local row = {}
		for j = 0, seg do
			local th = 2 * math.pi * j / seg
			local d = n1 * math.cos(th) + n2 * math.sin(th)
			row[j] = { pts[i] + d * radii[i], d }
		end
		grid[i - 1] = row
	end
	self:Grid(grid, seg, n - 1, col, layer or "opaque")
end

local function Dome(len, rad, steps, sharpBase)
	local pr = {}
	for i = 0, steps do
		local a = (math.pi / 2) * i / steps
		pr[#pr + 1] = { len * math.sin(a), rad * math.cos(a), (i == 0 and sharpBase) or nil }
	end
	return pr
end

local function Sphere(rad, steps)
	local pr = {}
	for i = 0, steps do
		local a = -math.pi / 2 + math.pi * i / steps
		pr[#pr + 1] = { rad * math.sin(a), rad * math.cos(a) }
	end
	return pr
end

-- Cylinder of radius r and height h ending in a hemisphere (dome shape), starting at x = 0
local function Capsule(r, h, closedBase)
	local pr = {}
	if closedBase then
		pr[#pr + 1] = { 0, 0, true }
		pr[#pr + 1] = { 0, r, true }
	else
		pr[#pr + 1] = { 0, r }
	end
	for i = 0, 10 do
		local a = (math.pi / 2) * i / 10
		pr[#pr + 1] = { h + r * math.sin(a), r * math.cos(a) }
	end
	return pr
end

local AXIS_Z = Angle(-90, 0, 0)   -- lathe axis pointing up
local AXIS_NY = Angle(0, -90, 0)  -- lathe axis pointing right (-Y)

---------------------------------------------------------------------------
-- Colouring and mesh baking
---------------------------------------------------------------------------

local function clampc(v) return math.floor(v < 0 and 0 or (v > 255 and 255 or v)) end

local COLOR = {}
-- cartoon two-tone ramp with a soft rim highlight
COLOR.opaque = function(c, n)
	local d = n:Dot(LIGHT)
	local k = 0.6 + 0.4 * math.Clamp((d + 0.15) * 3.5, 0, 1)
	local hi = math.Clamp((d - 0.8) * 5, 0, 1) * 0.16
	return clampc(c[1] * k + 255 * hi), clampc(c[2] * k + 255 * hi), clampc(c[3] * k + 255 * hi), 255
end
COLOR.hull = function() return C_HULL[1], C_HULL[2], C_HULL[3], 255 end
COLOR.glass = function(_, n)
	local hi = math.Clamp((n:Dot(LIGHT) - 0.72) * 6, 0, 1)
	return clampc(200 + 55 * hi), clampc(232 + 23 * hi), 255, clampc(45 + 160 * hi)
end
COLOR.liquid = function(_, n)
	local k = 0.72 + 0.28 * math.Clamp((n:Dot(LIGHT) + 0.3) * 1.4, 0, 1)
	return clampc(255 * k), clampc(255 * k), clampc(255 * k), 200
end
COLOR.tint = function(c, n)
	local hi = math.Clamp((n:Dot(LIGHT) - 0.6) * 4, 0, 1)
	return clampc(c[1] * (0.75 + 0.25 * hi) + 60 * hi), clampc(c[2] * (0.75 + 0.25 * hi) + 60 * hi), clampc(c[3] * (0.75 + 0.25 * hi) + 60 * hi), clampc((c[4] or 200) + 55 * hi)
end
COLOR.add = function(c) return c[1], c[2], c[3], c[4] or 255 end
COLOR.paint = COLOR.opaque

local MATS = { opaque = "flat", hull = "hull", glass = "glass", liquid = "liquid", tint = "tint", add = "add", paint = "flat" }

local function BuildMeshes(verts, mat, colorFn)
	local list = {}
	local total = #verts
	local i = 1
	while i <= total do
		local nTri = math.min(9000, math.floor((total - i + 1) / 3))
		if nTri <= 0 then break end
		local m = Mesh(mat)
		mesh.Begin(m, MATERIAL_TRIANGLES, nTri)
		for k = i, i + nTri * 3 - 1 do
			local v = verts[k]
			local r, g, b, a = colorFn(v[3], v[2])
			mesh.Position(v[1])
			mesh.Normal(v[2])
			mesh.Color(r, g, b, a)
			mesh.TexCoord(0, 0.5, 0.5)
			mesh.AdvanceVertex()
		end
		mesh.End()
		list[#list + 1] = m
		i = i + nTri * 3
	end
	return list
end
Model.BuildMeshes = BuildMeshes

-- Inverted-hull outline: vertices pushed out along position-averaged normals
local function HullVerts(verts, w)
	local acc = {}
	local function key(p)
		return math.floor(p.x * 200 + 0.5) .. "_" .. math.floor(p.y * 200 + 0.5) .. "_" .. math.floor(p.z * 200 + 0.5)
	end
	for _, v in ipairs(verts) do
		local k = key(v[1])
		if acc[k] then acc[k]:Add(v[2]) else acc[k] = Vector(v[2]) end
	end
	local out = {}
	for i, v in ipairs(verts) do
		local n = acc[key(v[1])]:GetNormalized()
		out[i] = { v[1] + n * w, n, C_HULL }
	end
	return out
end

local function Finish(b, hullWidth)
	local g = {}
	for layer, verts in pairs(b.layers) do
		g[layer] = BuildMeshes(verts, M[MATS[layer]], COLOR[layer])
	end
	if hullWidth and (b.layers.opaque or b.layers.paint) then
		local all = {}
		for _, l in ipairs({ "opaque", "paint" }) do
			for _, v in ipairs(b.layers[l] or {}) do all[#all + 1] = v end
		end
		g.hull = BuildMeshes(HullVerts(all, hullWidth), M.hull, COLOR.hull)
	end
	return g
end

---------------------------------------------------------------------------
-- Variant descriptions (anchor points used by the animation code)
---------------------------------------------------------------------------

local PRIME_SCR_N = Vector(-0.083, 0, 1):GetNormalized()
local PRIME_LEDS = {}
for _, gy in ipairs({ 1.45, 0, -1.45 }) do
	for _, gz in ipairs({ 1.5, 0.1, -1.3 }) do
		PRIME_LEDS[#PRIME_LEDS + 1] = Vector(9.2, gy, gz)
	end
end

Model.Variants = {
	[0] = {
		id = 0,
		key = "classic",
		paint = PAINT_STOCK,
		dome = Vector(2.6, 0, 1.4),                     -- pivot of the removable dome (bottom centre)
		liquid = { zc = 2.985, hl = 2.035, rl = 1.52 }, -- fluid volume inside the dome
		coreZ = 2.9,
		shell = "glass",
		tip = Vector(9.6, 0, 0),
		glow = Vector(9.3, 0, 0),
		leds = { Vector(9.35, 2.0, 0), Vector(9.35, 0, 0), Vector(9.35, -2.0, 0) },
		led = Vector(-4.9, -1.7, 1.47),
		knob = Vector(-5.0, 0, 1.86),
		knobAxis = "z",
		screen = { c = Vector(-2.6, 0, 1.46), n = Vector(0, 0, 1), x = Vector(0, -1, 0), w = 3.6, h = 1.7 },
		grip = Vector(-6.4, 0, -3.2),         -- middle of the grip, goes into the palm
		handTilt = 6,                         -- nose up in the hand: this grip sweeps back further than a pistol's
		palm = { ahead = 3.6, up = 1.4 },     -- fist relative to the wrist bone (world units)
		cam = { scale = 0.5, z = -5.4 },
		center = Vector(0.6, 0, -2.4),
	},
	[1] = {
		id = 1,
		key = "prime",
		paint = PAINT_STOCK,
		dome = Vector(6.0, 0, 2.6),
		liquid = { zc = 2.775, hl = 2.025, rl = 1.8 },
		coreZ = 2.7,
		shell = "tint",
		tip = Vector(9.5, 0, 0.1),
		glow = Vector(9.15, 0, 0.1),
		leds = PRIME_LEDS,
		led = Vector(8.2, -2.95, 0.7),
		knob = Vector(6.0, -3.12, -0.2),
		knobAxis = "y",
		screen = { c = Vector(-2.2, 0, 2.17) + PRIME_SCR_N * 0.06, n = PRIME_SCR_N, x = Vector(0, -1, 0), w = 2.9, h = 1.7 },
		grip = Vector(-5.3, 0, -1.5),
		handTilt = 0,
		palm = { ahead = 3.6, up = 1.4 },
		cam = { scale = 0.46, z = -5.8 },
		center = Vector(0.4, 0, -2.6),
	},
}

-- The guns built from cl_model_parts.lua: their dome pivot, tilt and colour come with the data, the rest is here
local function DataVariant(id, key, t)
	local d = RMPG.GunParts[key]
	t.id, t.key, t.data = id, key, true
	t.dome = Vector(d.domePos[1], d.domePos[2], d.domePos[3])
	t.domeAng = d.domeAng and Angle(d.domeAng[1], d.domeAng[2], d.domeAng[3]) or nil
	t.paint = Vector(d.paint[1], d.paint[2], d.paint[3])
	t.palm = t.palm or { ahead = 3.6, up = 1.4 }
	Model.Variants[id] = t
end

DataVariant(2, "evil", {
	liquid = { zc = 3.43, hl = 2.87, rl = 1.18 }, coreZ = 3.4, shell = "glass",
	tip = Vector(11.05, 0, 0.25), glow = Vector(10.6, 0, 0.25),
	leds = { Vector(7.2, 3.1, 0.3), Vector(7.2, -3.1, 0.3) },
	led = Vector(6.9, -1.5, 3.56), knob = Vector(5.6, -1.5, 3.96), knobAxis = "z",
	grip = Vector(-3.8, 0, -5.5), handTilt = 6, size = 0.96,
	cam = { scale = 0.42, z = -5.0 }, center = Vector(0.9, 0, -1.8),
})
DataVariant(3, "proto", {
	liquid = { zc = 2.55, hl = 1.83, rl = 1.16 }, coreZ = 2.55, shell = "glass",
	tip = Vector(9.25, 0, 1.0), glow = Vector(8.9, 0, 1.0),
	leds = { Vector(9.0, -1.2, -2.6) },
	led = Vector(3.9, -2.3, -2.7), knob = Vector(1.7, -2.53, -0.4), knobAxis = "y",
	grip = Vector(-4.1, 0, -5.0), handTilt = 4, size = 1.04,
	cam = { scale = 0.42, z = -5.4 }, center = Vector(0.6, 0, -0.8),
})
DataVariant(4, "kids", {
	liquid = { zc = 1.3, hl = 1.2, rl = 1.8 }, coreZ = 1.4, shell = "tint",
	tip = Vector(6.95, 0, -0.15), glow = Vector(6.7, 0, -0.15),
	led = Vector(-6.6, 0, 1.3), knob = Vector(-2.8, 0, 2.6), knobAxis = "z",
	grip = Vector(-4.95, 0, -3.7), handTilt = 7, size = 1.12,
	cam = { scale = 0.46, z = -5.4 }, center = Vector(-0.2, 0, -1.0),
	-- "PORTAL GUN JR" on both sides
	sticker = {
		{ c = Vector(1.7, -2.62, -0.1), n = Vector(0, -1, 0), x = Vector(1, 0, 0), w = 4.6, h = 2.7 },
		{ c = Vector(1.7, 2.62, -0.1), n = Vector(0, 1, 0), x = Vector(-1, 0, 0), w = 4.6, h = 2.7 },
	},
})
DataVariant(5, "cabinet", {
	liquid = { zc = 2.3, hl = 1.68, rl = 1.0 }, coreZ = 2.3, shell = "glass",
	tip = Vector(7.2, 0, 0.3), glow = Vector(6.9, 0, 0.3),
	leds = { Vector(6.75, 1.2, 0.2), Vector(6.75, 0, 0.2), Vector(6.75, -1.2, 0.2) },
	led = Vector(-5.7, 0, 1.85), knob = Vector(-4.6, 0, 2.17), knobAxis = "z",
	grip = Vector(-4.6, 0, -4.6), handTilt = 2, size = 1.1,
	cam = { scale = 0.46, z = -5.6 }, center = Vector(0.3, 0, -1.6),
})
DataVariant(6, "antenna", {
	liquid = { zc = 1.4, hl = 0.98, rl = 1.02 }, coreZ = 1.3, shell = "glass",
	tip = Vector(6.0, 0, 0.3), glow = Vector(5.9, 0, 0.3),
	leds = { Vector(6.05, 0.95, 0.95), Vector(6.05, -0.95, 0.95), Vector(6.05, 0.95, -0.35), Vector(6.05, -0.95, -0.35), Vector(-2.4, 1.3, 6.9) },
	led = Vector(3.4, -2.56, 1.6), knob = Vector(-1.8, -1.2, 2.9), knobAxis = "z",
	grip = Vector(-1.2, 0, -4.8), handTilt = 1, size = 1.12,
	cam = { scale = 0.48, z = -5.8 }, center = Vector(1.4, 0, -1.4),
})

-- The order of the guns in the menu
Model.Order = { 0, 1, 2, 3, 4, 5, 6 }

Model.TIP = Model.Variants[0].tip

function Model.Variant(id)
	return Model.Variants[id or 0] or Model.Variants[0]
end

---------------------------------------------------------------------------
-- The parts
---------------------------------------------------------------------------

-- The yellow energy core floating in the classic gun's dome: a lumpy body (its tendrils are drawn live)
local CORE_C = Vector(0, 0, 2.75)
local function BuildBlob(b)
	b:Super(CORE_C, Vector(0.62, 0.58, 0.6), 0.85, 0.85, C_CORE, nil, nil, 16, 10)
	for k = 1, 5 do
		local a = k * 1.3
		b:Super(CORE_C + Vector(math.cos(a) * 0.45, math.sin(a) * 0.45, math.sin(a * 2.1) * 0.35), Vector(0.24, 0.24, 0.24), 1, 1, C_CORE, nil, nil, 10, 6)
	end
end

local function BuildClassic()
	local G = {}
	local HULL = 0.1

	local b = NewBuilder()
	-- flat body with a seam running around it
	b:Super(Vector(1.5, 0, 0), Vector(7.5, 3.2, 1.4), 0.25, 0.22, PAINT, "paint", nil, 36, 16)
	b:Super(Vector(1.5, 0, -0.35), Vector(7.53, 3.23, 0.05), 0.25, 0.22, C_SEAM, nil, nil, 36, 4)
	-- curved grip sweeping down and back from the rear of the body
	b:SweepXZ({
		{ -3.8, 0.0, 1.45, 1.6 },
		{ -5.2, -1.2, 1.45, 1.6 },
		{ -6.3, -2.9, 1.42, 1.52 },
		{ -7.1, -4.9, 1.4, 1.48 },
		{ -7.6, -7.0, 1.38, 1.48 },
		{ -7.8, -8.9, 1.32, 1.42 },
		{ -7.8, -9.9, 1.1, 1.15 },
		{ -7.75, -10.45, 0.65, 0.7 },
		{ -7.7, -10.65, 0.1, 0.1 },
	}, 0.8, 20, PAINT2, "paint")
	b:Super(Vector(-4.6, 0, -1.55), Vector(1.35, 1.44, 0.9), 0.6, 0.6, PAINT2, "paint", Angle(30, 0, 0), 16, 10)
	-- dial knob on the top rear, red LED window, emitter lens
	b:Lathe(Vector(-5.0, 0, 1.3), AXIS_Z, { { 0, 0.95, true }, { 0.4, 0.95 }, { 0.5, 0.85, true }, { 0.55, 0, true } }, 22, C_DARK)
	b:Super(Vector(-2.6, 0, 1.4), Vector(0.92, 1.85, 0.05), 0.15, 0.15, C_SCREEN, nil, nil, 16, 6)
	for _, y in ipairs({ -2.0, 0, 2.0 }) do
		b:Lathe(Vector(8.95, y, 0), nil, { { 0, 0.98, true }, { 0.14, 0.98 }, { 0.2, 0.82, true }, { 0.2, 0.74, true } }, 20, C_MID)
		b:Lathe(Vector(9.0, y, 0), nil, Dome(0.42, 0.76, 6, true), 20, { 255, 255, 255, 225 }, "tint")
	end
	-- white ring the dome sits in
	b:Lathe(Vector(2.6, 0, 1.3), AXIS_Z, { { 0, 2.2, true }, { 0.5, 2.2 }, { 0.62, 2.05 }, { 0.7, 1.85, true }, { 0.7, 0, true } }, 28, PAINT, "paint")
	G.body = Finish(b, HULL)

	b = NewBuilder()
	b:Lathe(Vector(0, 0, 0.35), AXIS_Z, { { 0, 0, true }, { 0, 1.7, true }, { 0.06, 1.78 }, { 0.55, 1.78 }, { 0.6, 1.66, true }, { 0.6, 1.5, true } }, 24, C_MID)
	b:Lathe(Vector(0, 0, 0.9), AXIS_Z, Capsule(1.62, 2.6, false), 24, C_WHITE, "glass")
	b:Lathe(Vector(0, 0, 0.95), AXIS_Z, Capsule(1.52, 2.55, true), 24, C_WHITE, "liquid")
	G.dome = Finish(b, HULL)

	b = NewBuilder()
	BuildBlob(b)
	G.blob = Finish(b, 0.05)

	b = NewBuilder()
	b:Super(Vector(0.45, 0, 0), Vector(0.42, 0.08, 0.04), 0.3, 0.3, C_WHITE, nil, nil, 10, 6)
	G.marker = Finish(b)
	return G
end

local function BuildPrime()
	local G = {}
	local HULL = 0.1

	local b = NewBuilder()
	-- emitter block with the dark LED panel
	b:Super(Vector(6.0, 0, 0.1), Vector(3.0, 2.8, 2.5), 0.12, 0.12, PAINT, "paint", nil, 28, 12)
	b:Super(Vector(8.98, 0, 0.1), Vector(0.08, 2.35, 2.05), 0.12, 0.12, C_PANEL, nil, nil, 16, 6)
	for _, p in ipairs(PRIME_LEDS) do
		b:Lathe(Vector(9.0, p.y, p.z), nil, Dome(0.38, 0.48, 6, true), 12, { 255, 255, 255, 230 }, "tint")
	end
	-- top bridge sloping down to the grip
	b:Hex({
		Vector(-5.2, -1.9, 0.9), Vector(3.2, -2.3, 0.6), Vector(3.2, 2.3, 0.6), Vector(-5.2, 1.9, 0.9),
		Vector(-5.2, -1.9, 1.9), Vector(3.2, -2.3, 2.6), Vector(3.2, 2.3, 2.6), Vector(-5.2, 1.9, 1.9),
	}, PAINT, "paint")
	-- lower strut rising from the block to the grip (leaves the open window)
	b:Hex({
		Vector(-4.4, -1.7, -2.0), Vector(3.2, -1.9, -2.4), Vector(3.2, 1.9, -2.4), Vector(-4.4, 1.7, -2.0),
		Vector(-4.4, -1.7, -0.9), Vector(3.2, -1.9, -1.3), Vector(3.2, 1.9, -1.3), Vector(-4.4, 1.7, -0.9),
	}, PAINT, "paint")
	-- grip
	b:Hex({
		Vector(-8.2, -1.55, -9.6), Vector(-5.0, -1.55, -9.6), Vector(-5.0, 1.55, -9.6), Vector(-8.2, 1.55, -9.6),
		Vector(-6.4, -1.65, 1.9), Vector(-3.0, -1.65, 1.9), Vector(-3.0, 1.65, 1.9), Vector(-6.4, 1.65, 1.9),
	}, PAINT_GRIP, "paint")
	b:Super(Vector(-2.55, 0, -0.55), Vector(0.3, 0.38, 0.85), 0.5, 0.5, C_BLACK, nil, Angle(-15, 0, 0), 12, 8)
	-- red button on the back of the grip
	b:Super(Vector(-6.55, 0, 1.15), Vector(0.2, 0.8, 0.62), 0.2, 0.2, C_BLACK, nil, nil, 14, 8)
	b:Super(Vector(-6.78, 0, 1.15), Vector(0.14, 0.62, 0.48), 0.25, 0.25, C_RED, nil, nil, 14, 8)
	-- screw heads on the top
	for _, p in ipairs({ Vector(3.6, 2.3, 2.6), Vector(3.6, -2.3, 2.6), Vector(8.4, 2.3, 2.6), Vector(8.4, -2.3, 2.6),
		Vector(-4.6, 1.5, 1.94), Vector(-4.6, -1.5, 1.94) }) do
		b:Super(p, Vector(0.13, 0.13, 0.04), 1, 1, C_SEAM, nil, nil, 8, 4)
	end
	-- dial, toggle switch, LED and a port on the right side of the block
	b:Lathe(Vector(6.0, -2.8, -0.2), AXIS_NY, { { -0.1, 1.75, true }, { 0.1, 1.75 }, { 0.16, 1.6, true }, { 0.16, 1.3, true }, { 0.28, 1.25 }, { 0.28, 0, true } }, 28, C_SHELL)
	b:Torus(Vector(6.0, -3.0, -0.2), Angle(0, 90, 0), 1.45, 0.06, 28, 6, C_SEAM)
	b:Lathe(Vector(8.2, -2.8, 1.8), AXIS_NY, { { 0, 0.22, true }, { 0.15, 0.22 }, { 0.15, 0, true } }, 10, C_MID)
	b:Super(Vector(8.28, -3.2, 1.92), Vector(0.05, 0.34, 0.05), 1, 1, C_SHELL, nil, Angle(0, 0, -25), 8, 6)
	b:Lathe(Vector(8.2, -2.8, 0.7), AXIS_NY, Dome(0.12, 0.17, 4, true), 10, { 255, 255, 255, 230 }, "tint")
	b:Super(Vector(8.2, -2.81, -0.4), Vector(0.02, 0.17, 0.17), 1, 1, C_BLACK, nil, nil, 10, 6)
	-- red LED display on the bridge and the metal dome ring
	b:Super(Vector(-2.2, 0, 2.17), Vector(1.0, 1.55, 0.05), 0.15, 0.15, C_SCREEN, nil, Angle(-4.76, 0, 0), 16, 6)
	b:Lathe(Vector(6.0, 0, 2.5), AXIS_Z, { { 0, 2.15, true }, { 0.4, 2.15 }, { 0.52, 2.0 }, { 0.58, 1.95, true }, { 0.58, 0, true } }, 28, C_MID)
	G.body = Finish(b, HULL)

	b = NewBuilder()
	b:Lathe(Vector(0, 0, 0.25), AXIS_Z, { { 0, 0, true }, { 0, 1.9, true }, { 0.06, 2.0 }, { 0.45, 2.0 }, { 0.5, 1.9, true }, { 0.5, 1.7, true } }, 24, C_MID)
	b:Lathe(Vector(0, 0, 0.7), AXIS_Z, Capsule(1.9, 2.3, false), 24, { 255, 255, 255, 110 }, "tint")
	b:Lathe(Vector(0, 0, 0.75), AXIS_Z, Capsule(1.8, 2.25, true), 24, C_WHITE, "liquid")
	G.dome = Finish(b, HULL)

	b = NewBuilder()
	b:Super(Vector(0, 0, 0), Vector(1.05, 0.06, 0.17), 0.3, 0.3, C_MID, nil, nil, 10, 6)
	G.marker = Finish(b)
	return G
end

---------------------------------------------------------------------------
-- Guns from data (cl_model_parts.lua; dev/tools/gun_render.py builds the same offline)
---------------------------------------------------------------------------

local NAMED = {
	white = C_WHITE, shell = C_SHELL, grip = C_GRIP, seam = C_SEAM, mid = C_MID, dark = C_DARK, black = C_BLACK,
	screen = C_SCREEN, panel = C_PANEL, red = C_RED, yellow = C_YELLOW,
	wood = { 198, 160, 100 }, wood2 = { 160, 124, 74 }, tape = { 234, 224, 184 }, copper = { 200, 114, 64 },
	copper2 = { 146, 78, 44 }, hose = { 176, 58, 44 }, teal = { 84, 172, 172 }, steel = { 164, 170, 180 },
	cream = { 238, 230, 204 }, cyan = { 40, 220, 235 }, blue = { 64, 116, 226 }, green = { 80, 205, 96 },
	grey = { 122, 128, 136 }, lightgrey = { 198, 202, 208 }, orange = { 232, 142, 52 }, hazard = { 240, 200, 30 },
	rust = { 150, 96, 70 }, glow = { 255, 255, 255, 230 },
	paint = PAINT, paint2 = PAINT2, paint3 = { 206, 206, 206 },
}
local AXES = { z = AXIS_Z, ny = AXIS_NY, y = Angle(0, 90, 0), nz = Angle(90, 0, 0), nx = Angle(0, 180, 0) }

local function V3(t) return Vector(t[1], t[2], t[3]) end

local function Ang(a)
	if a == nil or a == "x" then return nil end
	if isstring(a) then return AXES[a] end
	return Angle(a[1], a[2], a[3])
end

local function ColLayer(c, layer)
	if isstring(c) then
		if string.sub(c, 1, 5) == "paint" then return NAMED[c] or PAINT, "paint" end
		return NAMED[c] or C_WHITE, layer or "opaque"
	end
	return c, layer or "opaque"
end

local function BuildParts(b, parts)
	for _, p in ipairs(parts or {}) do
		local kind = p[1]
		if kind == "super" then
			local col, layer = ColLayer(p[6], p[7])
			b:Super(V3(p[2]), V3(p[3]), p[4], p[5], col, layer, p[8] and Ang(p[8]) or nil, p[9], p[10])
		elseif kind == "lathe" then
			local col, layer = ColLayer(p[6], p[7])
			b:Lathe(V3(p[2]), Ang(p[3]), p[4], p[5], col, layer)
		elseif kind == "dome" then
			local col, layer = ColLayer(p[7], p[8])
			b:Lathe(V3(p[2]), Ang(p[3]), Dome(p[4], p[5], p[6], true), p[9] or 20, col, layer)
		elseif kind == "capsule" then
			local col, layer = ColLayer(p[6], p[7])
			b:Lathe(V3(p[2]), Ang(p[3]), Capsule(p[4], p[5], true), p[8] or 24, col, layer)
		elseif kind == "sphere" then
			local col, layer = ColLayer(p[4], p[5])
			b:Lathe(V3(p[2]), nil, Sphere(p[3], p[6] or 10), p[7] or 16, col, layer)
		elseif kind == "cyl" then
			local col, layer = ColLayer(p[6], p[7])
			local r, l = p[4], p[5]
			b:Lathe(V3(p[2]), Ang(p[3]), { { 0, 0, true }, { 0, r, true }, { l, r, true }, { l, 0, true } }, p[8] or 20, col, layer)
		elseif kind == "ring" then
			local col, layer = ColLayer(p[7], p[8])
			local ri, ro, l = p[4], p[5], p[6]
			b:Lathe(V3(p[2]), Ang(p[3]), { { 0, ri, true }, { 0, ro, true }, { l, ro, true }, { l, ri, true }, { 0, ri, true } }, p[9] or 24, col, layer)
		elseif kind == "torus" then
			local col, layer = ColLayer(p[6], p[7])
			b:Torus(V3(p[2]), Ang(p[3]), p[4], p[5], p[8] or 24, p[9] or 6, col, layer)
		elseif kind == "hex" then
			local col, layer = ColLayer(p[3], p[4])
			local pts = {}
			for i = 1, 8 do pts[i] = V3(p[2][i]) end
			b:Hex(pts, col, layer)
		elseif kind == "box" then
			local col, layer = ColLayer(p[4], p[5])
			local c, h, rot = V3(p[2]), p[3], p[6] and Ang(p[6]) or nil
			local pts = {}
			for _, sz in ipairs({ -1, 1 }) do
				for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
					local v = Vector(s[1] * h[1], s[2] * h[2], sz * h[3])
					if rot then v:Rotate(rot) end
					pts[#pts + 1] = c + v
				end
			end
			b:Hex(pts, col, layer)
		elseif kind == "sweep" then
			local col, layer = ColLayer(p[5], p[6])
			b:SweepXZ(p[2], p[3], p[4], col, layer)
		elseif kind == "tube" then
			local col, layer = ColLayer(p[5], p[6])
			local pts, radii = {}, {}
			for i, q in ipairs(p[2]) do
				pts[i] = V3(q)
				radii[i] = istable(p[3]) and p[3][i] or p[3]
			end
			b:Tube(pts, radii, p[4], col, layer)
		end
	end
end

local function BuildData(key)
	local d = RMPG.GunParts[key]
	local G = {}
	local b = NewBuilder()
	BuildParts(b, d.body)
	G.body = Finish(b, 0.1)
	b = NewBuilder()
	BuildParts(b, d.dome)
	G.dome = Finish(b, 0.1)
	b = NewBuilder()
	BuildParts(b, d.marker)
	G.marker = Finish(b)
	return G
end

-- Any group built from parts data, and its drawing (the acid vats use these)
function Model.PartsGroup(parts, hullWidth)
	local b = NewBuilder()
	BuildParts(b, parts)
	return Finish(b, hullWidth)
end

function Model.Build()
	if Model.G then return end
	local G = { [0] = BuildClassic(), [1] = BuildPrime() }
	for id, V in pairs(Model.Variants) do
		if V.data then G[id] = BuildData(V.key) end
	end

	-- energy core parts (shared)
	local b = NewBuilder()
	b:Lathe(Vector(0, 0, 0), nil, Sphere(0.6, 10), 20, { 255, 255, 255, 235 }, "tint")
	G.core = Finish(b)
	b = NewBuilder()
	b:Torus(Vector(0, 0, 0), nil, 0.92, 0.06, 32, 6, { 255, 255, 255, 220 }, "tint")
	G.ring = Finish(b)

	Model.G = G
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local function Mat4(fr)
	local F, L, U, s, O = fr.F, fr.L, fr.U, fr.s, fr.O
	return Matrix({
		{ F.x * s, L.x * s, U.x * s, O.x },
		{ F.y * s, L.y * s, U.y * s, O.y },
		{ F.z * s, L.z * s, U.z * s, O.z },
		{ 0, 0, 0, 1 },
	})
end

function Model.ToWorld(fr, p)
	return fr.O + fr.F * (p.x * fr.s) + fr.L * (p.y * fr.s) + fr.U * (p.z * fr.s)
end

function Model.Dir(fr, v)
	return fr.F * v.x + fr.L * v.y + fr.U * v.z
end

function Model.Child(fr, offset, ang)
	local F, L, U = Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1)
	if ang then F:Rotate(ang) L:Rotate(ang) U:Rotate(ang) end
	return { O = Model.ToWorld(fr, offset), F = Model.Dir(fr, F), L = Model.Dir(fr, L), U = Model.Dir(fr, U), s = fr.s }
end

-- Frame from a world position and angle (forward/left/up of the angle)
function Model.FrameFromAngle(pos, ang, s)
	return { O = pos, F = ang:Forward(), L = -ang:Right(), U = ang:Up(), s = s }
end

-- Frame that puts the middle of a variant at pos (menu previews, the self-destruct)
function Model.CenteredFrame(pos, ang, s, variant)
	local V = Model.Variant(variant)
	s = s * (V.size or 1)
	local fr = Model.FrameFromAngle(pos, ang, s)
	local c = V.center
	fr.O = pos - Model.Dir(fr, c) * s
	return fr
end

local function DrawLayer(fr, group, layer, mat)
	local list = group and group[layer]
	if not list then return end
	render.SetMaterial(mat)
	cam.PushModelMatrix(Mat4(fr))
	for i = 1, #list do list[i]:Draw() end
	cam.PopModelMatrix()
end

-- Drawing a group built with Model.PartsGroup (the acid vats)
function Model.DrawGroup(fr, G, light, outline)
	if outline then
		render.OverrideDepthEnable(true, false)
		DrawLayer(fr, G, "hull", M.hull)
		render.OverrideDepthEnable(false, false)
	end
	M.flat:SetVector("$color", Vector(light, light, light))
	DrawLayer(fr, G, "opaque", M.flat)
	DrawLayer(fr, G, "paint", M.flat)
	M.flat:SetVector("$color", WHITE)
end

function Model.DrawGroupLayer(fr, G, layer, mat)
	DrawLayer(fr, G, layer, mat)
end


---------------------------------------------------------------------------
-- Animated pieces
---------------------------------------------------------------------------

-- Fluid inside a dome frame; the surface stays level with the world and drops as charges are used
function Model.DrawLiquid(dfr, st, col, liq, group)
	local lvl = math.Clamp(st.level or 1, 0, 1)
	if lvl <= 0.003 then return end
	local s = dfr.s
	local az = math.abs(dfr.U.z)
	local center = Model.ToWorld(dfr, Vector(0, 0, liq.zc))
	local ext = az * liq.hl * s + liq.rl * s * math.sqrt(math.max(0, 1 - az * az))
	local n = Vector(0, 0, 1)
	if st.slosh then
		n = n + st.slosh
		n:Normalize()
	end
	local planeP = center + Vector(0, 0, (lvl * 2 - 1) * ext)
	local clip = lvl < 0.995
	local old
	if clip then
		old = render.EnableClipping(true)
		local cn = -n
		render.PushCustomClipPlane(cn, cn:Dot(planeP))
	end

	M.liquid:SetVector("$color", Vector(col.x / 255, col.y / 255, col.z / 255))
	DrawLayer(dfr, group, "liquid", M.liquid)
	M.liquid:SetVector("$color", WHITE)

	render.SetMaterial(M.glow)
	local t = st.time or CurTime()
	local burst = st.fire or 0
	local bottom = liq.zc - liq.hl
	for i = 1, 9 do
		local ph = (t * (0.3 + i * 0.045) + i * 0.37) % 1
		local a = i * 2.39996
		local rr = liq.rl * (0.25 + 0.5 * ((i * 0.618) % 1))
		local p = Model.ToWorld(dfr, Vector(math.cos(a + t * 0.6) * rr, math.sin(a + t * 0.6) * rr, bottom + 0.2 + ph * liq.hl * 1.9))
		local sz = s * (0.26 + 0.1 * math.sin(i)) * (1 + burst * 1.5)
		render.DrawSprite(p, sz, sz, Color(255, 255, 255, 160))
	end

	if clip then
		render.PopCustomClipPlane()
		render.EnableClipping(old)
	end
end

-- Energy core: glowing orb, spinning rings and arcs (cfr's forward axis is the arc direction)
function Model.DrawCore(cfr, st, col)
	local t = st.time or CurTime()
	local c, s = cfr.O, cfr.s
	local pulse = 0.8 + 0.2 * math.sin(t * 9)
	render.SetMaterial(M.glow)
	render.DrawSprite(c, s * 6 * pulse, s * 6 * pulse, Color(col.x, col.y, col.z, 255))
	render.DrawSprite(c, s * 2.4, s * 2.4, Color(255, 255, 255, 255))

	M.tint:SetVector("$color", Vector(math.min(1, col.x / 255 + 0.45), math.min(1, col.y / 255 + 0.45), math.min(1, col.z / 255 + 0.45)))
	DrawLayer(Model.Child(cfr, vector_origin, Angle(0, t * 90, 0)), Model.G.core, "tint", M.tint)
	M.tint:SetVector("$color", Vector(col.x / 255, col.y / 255, col.z / 255))
	for i = 1, 3 do
		local a = Angle(t * (70 + i * 25) + i * 40, t * (40 + i * 30) + i * 60, i * 50)
		DrawLayer(Model.Child(cfr, vector_origin, a), Model.G.ring, "tint", M.tint)
	end
	M.tint:SetVector("$color", WHITE)

	if (st.detail or 1) > 0 then
		local len = st.arc or 4.2
		render.SetMaterial(M.beam)
		for k = 1, 2 do
			local sx = (k == 1) and -len or len
			local prev = c
			for j = 1, 5 do
				local f = j / 5
				local p = Model.ToWorld(cfr, Vector(sx * f, math.Rand(-0.55, 0.55), math.Rand(-0.55, 0.55)))
				render.DrawBeam(prev, p, s * 0.28, 0, 1, Color(col.x, col.y, col.z, 220))
				prev = p
			end
		end
	end
end

---------------------------------------------------------------------------
-- The core's tendrils: they writhe all the time and spit lightning at the glass
---------------------------------------------------------------------------

local TENDRILS = {}
for k = 1, 7 do
	local phi = k * (2 * math.pi / 7) + 0.4
	local elev = (k % 3 - 1) * 0.45
	local dir = Vector(math.cos(phi) * math.cos(elev), math.sin(phi) * math.cos(elev), math.sin(elev))
	local side = dir:Cross(Vector(0, 0, 1))
	if side:LengthSqr() < 0.01 then side = Vector(1, 0, 0) end
	side:Normalize()
	TENDRILS[k] = { dir = dir, side = side, phase = k * 1.7 }
end

-- Centre line of tendril k at time t (dome space); energy makes them thrash faster
local function TendrilPoints(k, t, energy)
	local td = TENDRILS[k]
	local speed = 1 + energy * 1.5
	local pts = {}
	for i = 0, 7 do
		local u = i / 7
		local p = CORE_C + td.dir * (0.5 + 0.85 * u)
			+ td.side * (math.sin(u * math.pi * 2.5 + td.phase + t * 3.1 * speed) * 0.26 * u)
			+ Vector(0, 0, math.sin(u * math.pi * 1.5 + td.phase * 0.7 + t * 2.3 * speed) * 0.26 * u)
		local hl = math.sqrt(p.x * p.x + p.y * p.y)
		if hl > 1.3 then p = Vector(p.x / hl * 1.3, p.y / hl * 1.3, p.z) end
		pts[i + 1] = p
	end
	return pts
end

-- The core's colour: the portal's, lightened a little so a dark portal still has a visible core
local function CoreTint(cv, k)
	return Vector(k * (0.3 + 0.7 * cv.x), k * (0.3 + 0.7 * cv.y), k * (0.3 + 0.7 * cv.z))
end

local function DrawTendrils(bfr, t, energy, light)
	render.SetMaterial(M.flat)
	local k0 = light * (1 + 0.3 * energy)
	M.flat:SetVector("$color", Vector(k0, k0, k0))
	cam.PushModelMatrix(Mat4(bfr))
	mesh.Begin(MATERIAL_QUADS, #TENDRILS * 7 * 6)
	for k = 1, #TENDRILS do
		local pts = TendrilPoints(k, t, energy)
		local rings = {}
		for i = 1, 8 do
			local a = pts[math.min(i + 1, 8)] - pts[math.max(i - 1, 1)]
			a:Normalize()
			local n1 = a:Cross(math.abs(a.z) > 0.9 and Vector(1, 0, 0) or Vector(0, 0, 1))
			n1:Normalize()
			local n2 = a:Cross(n1)
			local r = 0.085 * (1 - (i - 1) / 7 * 0.6)
			local ring = {}
			for j = 0, 5 do
				local th = j / 6 * math.pi * 2
				local d = n1 * math.cos(th) + n2 * math.sin(th)
				ring[j] = { pts[i] + d * r, d }
			end
			rings[i] = ring
		end
		for i = 1, 7 do
			for j = 0, 5 do
				local j2 = (j + 1) % 6
				local quad = { rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j] }
				for q = 1, 4 do
					local v = quad[q]
					local cr, cg, cb = COLOR.opaque(C_CORE, v[2])
					mesh.Position(v[1])
					mesh.Normal(v[2])
					mesh.Color(cr, cg, cb, 255)
					mesh.TexCoord(0, 0.5, 0.5)
					mesh.AdvanceVertex()
				end
			end
		end
	end
	mesh.End()
	cam.PopModelMatrix()
	M.flat:SetVector("$color", WHITE)
end

-- The same tendrils, still, as triangles for one static mesh: a spare flask lying in the world does not rebuild them
-- vertex by vertex every frame, and its blob still turns them around
local function StillTendrils()
	local out = {}
	for k = 1, #TENDRILS do
		local pts = TendrilPoints(k, 0, 0)
		local rings = {}
		for i = 1, 8 do
			local a = pts[math.min(i + 1, 8)] - pts[math.max(i - 1, 1)]
			a:Normalize()
			local n1 = a:Cross(math.abs(a.z) > 0.9 and Vector(1, 0, 0) or Vector(0, 0, 1))
			n1:Normalize()
			local n2 = a:Cross(n1)
			local r = 0.085 * (1 - (i - 1) / 7 * 0.6)
			local ring = {}
			for j = 0, 5 do
				local th = j / 6 * math.pi * 2
				local d = n1 * math.cos(th) + n2 * math.sin(th)
				ring[j] = { pts[i] + d * r, d, C_CORE }
			end
			rings[i] = ring
		end
		for i = 1, 7 do
			for j = 0, 5 do
				local j2 = (j + 1) % 6
				local a, b, c, d = rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]
				for _, v in ipairs({ a, b, c, a, c, d }) do out[#out + 1] = v end
			end
		end
	end
	return out
end

local function DrawZaps(bfr, dfr, t, energy, col)
	render.SetMaterial(M.beam)
	local s = bfr.s
	local slot = math.floor(t * 18)
	local zc = Color(math.min(255, col.x + 120), math.min(255, col.y + 120), math.min(255, col.z + 120), 255)
	for k = 1, #TENDRILS do
		-- every tendril sparks now and then; with an energy core they crackle non-stop
		if energy > 0 or (slot + k * 5) % 9 == 0 then
			local pts = TendrilPoints(k, t, energy)
			local tip = Model.ToWorld(bfr, pts[8])
			local a = util.SharedRandom("rmpg_zap", 0, math.pi * 2, slot * 13 + k)
			local h = util.SharedRandom("rmpg_zaph", 1.2, 4.3, slot * 7 + k)
			local target = Model.ToWorld(dfr, Vector(math.cos(a) * 1.5, math.sin(a) * 1.5, h))
			local prev = tip
			for j = 1, 4 do
				local p = LerpVector(j / 4, tip, target)
				if j < 4 then p = p + VectorRand() * (s * 0.25) end
				render.DrawBeam(prev, p, s * (0.18 + 0.14 * energy), 0, 1, zc)
				prev = p
			end
		end
	end
end

-- With an energy core the dome is filled with light instead of fluid
local function DrawEnergyFill(dfr, V, st, col)
	local t = st.time or CurTime()
	local c = Model.ToWorld(dfr, Vector(0, 0, V.coreZ))
	local s = dfr.s
	local pulse = 0.75 + 0.25 * math.sin(t * 9)
	render.SetMaterial(M.glow)
	render.DrawSprite(c, s * 7 * pulse, s * 9 * pulse, Color(col.x, col.y, col.z, 220))
	render.DrawSprite(c, s * 3.2, s * 3.2, Color(255, 255, 255, 210))
end

---------------------------------------------------------------------------
-- Red seven-segment LED display
---------------------------------------------------------------------------

local SEG = {
	["0"] = "abcdef", ["1"] = "bc", ["2"] = "abdeg", ["3"] = "abcdg", ["4"] = "bcfg", ["5"] = "acdfg",
	["6"] = "acdefg", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg",
	A = "abcefg", B = "cdefg", C = "adef", D = "bcdeg", E = "adefg", F = "aefg", G = "acdef", H = "bcefg",
	I = "bc", J = "bcde", K = "bcefg", L = "def", N = "abcef", O = "abcdef", P = "abefg", Q = "abcfg",
	R = "eg", S = "acdfg", T = "defg", U = "bcdef", Y = "bcdfg", Z = "abdeg",
	b = "cdefg", c = "deg", d = "bcdeg", e = "abdefg", h = "cefg", i = "c", n = "ceg", o = "cdeg",
	r = "eg", t = "defg", u = "cde", y = "bcdfg",
	["-"] = "g", ["_"] = "d", ["?"] = "abeg", ["="] = "dg", [" "] = "",
}
local SEG_IDS = { "a", "b", "c", "d", "e", "f", "g" }

local function SegRect(id, x, y, w, h, th)
	if id == "a" then return x + th, y, w - 2 * th, th end
	if id == "g" then return x + th, y + h / 2 - th / 2, w - 2 * th, th end
	if id == "d" then return x + th, y + h - th, w - 2 * th, th end
	if id == "f" then return x, y + th * 0.6, th, h / 2 - th * 1.1 end
	if id == "b" then return x + w - th, y + th * 0.6, th, h / 2 - th * 1.1 end
	if id == "e" then return x, y + h / 2 + th * 0.5, th, h / 2 - th * 1.1 end
	return x + w - th, y + h / 2 + th * 0.5, th, h / 2 - th * 1.1
end

-- Count of digit cells in a string (a "." rides on the previous digit)
local function SegCells(text)
	local _, dots = string.gsub(text, "%.", "")
	return #text - dots
end

local function Seg7(text, x, y, w, h, on, off)
	local th = math.max(2, math.floor(h * 0.12))
	local gap = w * 0.3
	local cx = x
	local i = 1
	while i <= #text do
		local ch = string.sub(text, i, i)
		local segs = SEG[ch] or SEG[string.upper(ch)] or ""
		for _, id in ipairs(SEG_IDS) do
			local lit = string.find(segs, id, 1, true) ~= nil
			surface.SetDrawColor(lit and on or off)
			surface.DrawRect(SegRect(id, cx, y, w, h, th))
		end
		local dp = string.sub(text, i + 1, i + 1) == "."
		surface.SetDrawColor(dp and on or off)
		surface.DrawRect(cx + w + gap * 0.2, y + h - th, th, th)
		if dp then i = i + 1 end
		cx = cx + w + gap
		i = i + 1
	end
end

local LED_ON = Color(255, 42, 30)
local LED_OFF = Color(52, 8, 8)

function Model.DrawScreen(fr, st, S)
	local N = Model.Dir(fr, S.n)
	local X = Model.Dir(fr, S.x)
	local Dn = X:Cross(N)
	local s = fr.s
	local origin = Model.ToWorld(fr, S.c) - X * (S.w * 0.5 * s) - Dn * (S.h * 0.5 * s)
	local d = st.display
	local t = st.time or CurTime()
	local W, H = S.w * 100, S.h * 100
	local blinkOff = d.blink and math.floor(t * 4) % 2 == 0
	cam.Start3D2D(origin, X:AngleEx(N), 0.01 * s)
		surface.SetDrawColor(6, 2, 2, 255)
		surface.DrawRect(0, 0, W, H)
		-- first row: destination code
		local big = d.big or ""
		local cells = math.max(SegCells(big), 4)
		local dh = H * 0.46
		local dw = dh * 0.55
		if cells * dw * 1.3 > W * 0.92 then
			dw = W * 0.92 / (cells * 1.3)
			dh = dw / 0.55
		end
		local on = (blinkOff and not d.warn) and LED_OFF or LED_ON
		local bx = (W - SegCells(big) * dw * 1.3 + dw * 0.3) / 2
		Seg7(big, bx, H * 0.08, dw, dh, on, LED_OFF)
		-- second row: charges + level bar
		local sh = H * 0.28
		local sw = sh * 0.55
		local small = d.small or ""
		local on2 = (blinkOff and d.warn) and LED_OFF or LED_ON
		Seg7(small, W * 0.06, H * 0.64, sw, sh, on2, LED_OFF)
		if d.bar then
			local x0 = W * 0.06 + math.max(SegCells(small), 2) * sw * 1.3 + 8
			local bw = W * 0.94 - x0
			local n = 8
			for k = 0, n - 1 do
				local lit = (k + 0.5) / n <= d.bar
				surface.SetDrawColor(lit and LED_ON or LED_OFF)
				surface.DrawRect(x0 + k * bw / n, H * 0.7, bw / n - 3, sh * 0.6)
			end
		end
	cam.End3D2D()
	render.SetMaterial(M.glow)
	local gs = s * S.w * 1.1
	render.DrawSprite(Model.ToWorld(fr, S.c) + N * (0.15 * s), gs, gs * 0.6, Color(255, 40, 20, 40))
end

local function EaseOut(x) x = math.Clamp(x, 0, 1) return 1 - (1 - x) ^ 3 end

---------------------------------------------------------------------------
-- Whole gun
--   st = { variant, color, level, core, fire, reload, dial, display, light, outline, time, slosh, glow, detail }
---------------------------------------------------------------------------

local function DomeFrame(fr, V, rf)
	local base = V.domeAng and Model.Child(fr, V.dome, V.domeAng)
	if not rf then return base or Model.Child(fr, V.dome), true end
	local spin, rise, side, sc = 0, 0, 0, 1
	if rf < 0.1 then
		spin = 0
	elseif rf < 0.35 then
		local u = (rf - 0.1) / 0.25
		spin, rise = 540 * u * u, 0.8 * u
	elseif rf < 0.5 then
		local v = (rf - 0.35) / 0.15
		spin, rise, side, sc = 540 + 200 * v, 0.8 + 3.5 * v, -3 * v * v, 1 - v
	elseif rf < 0.55 then
		sc = 0
	elseif rf < 0.8 then
		local v = (rf - 0.55) / 0.25
		local e = EaseOut(v)
		rise, spin, sc = 4.5 * (1 - e) + 0.8 * e, -300 * (1 - e), math.min(1, v * 2)
	elseif rf < 0.95 then
		local u = (rf - 0.8) / 0.15
		rise, spin = 0.8 * (1 - u), -540 * u
	end
	if sc <= 0.02 then return nil, false end
	local d = base and Model.Child(base, Vector(0, side, rise), Angle(0, spin, 0)) or Model.Child(fr, V.dome + Vector(0, side, rise), Angle(0, spin, 0))
	d.s = fr.s * sc
	return d, true
end

function Model.DrawGun(fr, st)
	Model.Build()
	local V = Model.Variant(st.variant)
	local G = Model.G[V.id]
	local col = st.color or RMPG.DEFAULT_COLOR
	local t = st.time or CurTime()
	local light = st.light or 1
	local cv = Vector(col.x / 255, col.y / 255, col.z / 255)
	local fire = st.fire or 0

	local dfr, domeVisible = DomeFrame(fr, V, st.reload)
	local showBlob = domeVisible and G.blob ~= nil
	local energy = st.core and 1 or 0
	local bfr
	local knobFr = V.knobAxis == "z" and Model.Child(fr, V.knob, Angle(0, st.dial or 0, 0)) or Model.Child(fr, V.knob, Angle(st.dial or 0, 0, 0))

	if st.outline then
		render.OverrideDepthEnable(true, false)
		DrawLayer(fr, G.body, "hull", M.hull)
		if domeVisible then DrawLayer(dfr, G.dome, "hull", M.hull) end
		render.OverrideDepthEnable(false, false)
	end

	M.flat:SetVector("$color", Vector(light, light, light))
	DrawLayer(fr, G.body, "opaque", M.flat)
	DrawLayer(knobFr, G.marker, "opaque", M.flat)
	if domeVisible then DrawLayer(dfr, G.dome, "opaque", M.flat) end
	-- the shell in the body colour: the player's own, or the gun's
	local pc = st.body or V.paint or PAINT_STOCK
	M.flat:SetVector("$color", Vector(pc.x / 255 * light, pc.y / 255 * light, pc.z / 255 * light))
	DrawLayer(fr, G.body, "paint", M.flat)
	if domeVisible then DrawLayer(dfr, G.dome, "paint", M.flat) end
	if showBlob then
		-- the core floats, slowly turns and bobs; with an energy core it glows and spins faster
		bfr = Model.Child(dfr, Vector(0, 0, math.sin(t * 1.7) * 0.08), Angle(0, t * 25 * (1 + energy * 2), 0))
		bfr.s = dfr.s
		local k = light * (0.85 + 0.15 * math.sin(t * 3) + 0.35 * energy)
		M.flat:SetVector("$color", CoreTint(cv, k))
		DrawLayer(bfr, G.blob, "opaque", M.flat)
		DrawTendrils(bfr, t, energy, light)
	end
	M.flat:SetVector("$color", WHITE)

	-- emitter lens / LED matrix
	M.tint:SetVector("$color", cv * (0.6 + 0.4 * light + fire))
	DrawLayer(fr, G.body, "tint", M.tint)
	M.tint:SetVector("$color", WHITE)

	if domeVisible then
		if st.core and showBlob then
			DrawEnergyFill(dfr, V, st, col)
		elseif st.core then
			st.arc = 2.0
			Model.DrawCore(Model.Child(dfr, Vector(0, 0, V.coreZ), Angle(-90, 0, 0)), st, col)
		else
			Model.DrawLiquid(dfr, st, col, V.liquid, G.dome)
		end
		if showBlob and (st.detail or 1) > 0 then DrawZaps(bfr, dfr, t, energy, col) end
		if V.shell == "tint" then
			M.tint:SetVector("$color", cv * (0.45 + 0.35 * light))
			DrawLayer(dfr, G.dome, "tint", M.tint)
			M.tint:SetVector("$color", WHITE)
		else
			DrawLayer(dfr, G.dome, "glass", M.glass)
		end
	end

	if st.glow ~= false then
		local pulse = 0.8 + 0.2 * math.sin(t * 4)
		render.SetMaterial(M.glow)
		-- the dome lights up the gun around it
		if domeVisible then
			local lvl = st.core and 1 or math.Clamp(st.level or 1, 0, 1)
			local gs = fr.s * 9 * (0.4 + 0.6 * lvl) * pulse
			render.DrawSprite(Model.ToWorld(dfr, Vector(0, 0, V.liquid.zc)), gs, gs * 1.2, Color(col.x, col.y, col.z, 120))
		end
		local es = fr.s * (3 + 10 * fire)
		render.DrawSprite(Model.ToWorld(fr, V.glow), es, es, Color(col.x, col.y, col.z, 200))
		if V.leds then
			for _, p in ipairs(V.leds) do
				local ls = fr.s * (1.6 + 3 * fire) * pulse
				render.DrawSprite(Model.ToWorld(fr, p), ls, ls, Color(col.x, col.y, col.z, 200))
			end
		end
		if fire > 0 then
			local fs = fr.s * 24 * fire
			render.DrawSprite(Model.ToWorld(fr, V.tip), fs, fs, Color(255, 255, 255, 255 * fire))
		end
		local blink = (math.floor(t * 2) % 2 == 0) and 1 or 0.3
		render.DrawSprite(Model.ToWorld(fr, V.led), fr.s * 1.2, fr.s * 1.2, Color(col.x, col.y, col.z, 255 * blink))
	end

	if st.display and V.screen then Model.DrawScreen(fr, st, V.screen) end
	if V.sticker and (st.detail or 1) > 0 then
		for _, S in ipairs(V.sticker) do Model.DrawSticker(fr, S) end
	end
end

-- The sticker on the kids' gun: "PORTAL / GUN" in bright letters on a green blob with a round "JR" badge, like the toy's
surface.CreateFont("RMPG_Sticker", { font = "Comic Sans MS", size = 96, weight = 900, extended = true, antialias = true })
surface.CreateFont("RMPG_StickerJr", { font = "Comic Sans MS", size = 56, weight = 900, extended = true, antialias = true })
local STICK_LINES = {
	{ { "P", Color(170, 110, 220) }, { "O", Color(170, 230, 60) }, { "R", Color(240, 130, 60) }, { "T", Color(60, 170, 190) },
		{ "A", Color(170, 110, 220) }, { "L", Color(90, 200, 90) } },
	{ { "G", Color(200, 120, 60) }, { "U", Color(70, 150, 230) }, { "N", Color(60, 170, 120) } },
}

function Model.DrawSticker(fr, S)
	local N = Model.Dir(fr, S.n)
	local X = Model.Dir(fr, S.x)
	local Dn = X:Cross(N)
	local s = fr.s
	local origin = Model.ToWorld(fr, S.c) - X * (S.w * 0.5 * s) - Dn * (S.h * 0.5 * s) + N * (0.03 * s)
	local W, H = S.w * 100, S.h * 100
	cam.Start3D2D(origin, X:AngleEx(N), 0.01 * s)
		draw.RoundedBox(math.floor(H * 0.3), 0, 0, W, H, Color(40, 110, 60))
		draw.RoundedBox(math.floor(H * 0.26), 8, 8, W - 16, H - 16, Color(176, 238, 160))
		surface.SetFont("RMPG_Sticker")
		for li, line in ipairs(STICK_LINES) do
			local total = 0
			for _, l in ipairs(line) do total = total + surface.GetTextSize(l[1]) end
			local x = li == 1 and (W - total) / 2 or W * 0.12
			local y = H * (li == 1 and 0.3 or 0.7)
			for i, l in ipairs(line) do
				local cw = surface.GetTextSize(l[1])
				draw.SimpleTextOutlined(l[1], "RMPG_Sticker", x + cw / 2, y + math.sin(i * 1.9 + li) * H * 0.03, l[2], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, Color(30, 60, 40))
				x = x + cw
			end
			if li == 2 then
				-- the round JR badge after GUN
				local r = H * 0.2
				local cx, cy = x + r * 1.3, y
				draw.RoundedBox(r, cx - r - 4, cy - r - 4, (r + 4) * 2, (r + 4) * 2, Color(30, 60, 40))
				draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, Color(40, 130, 70))
				draw.SimpleText("JR", "RMPG_StickerJr", cx, cy, Color(200, 255, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	cam.End3D2D()
end

-- Spare flask: the classic dome on its own (fr is centred on the capsule)
function Model.DrawFlask(fr, col, level, light)
	Model.Build()
	local V = Model.Variants[0]
	local G = Model.G[0]
	local dfr = Model.Child(fr, Vector(0, 0, -2.73))
	local st = { color = col, level = level or 1, time = CurTime() }
	render.OverrideDepthEnable(true, false)
	DrawLayer(dfr, G.dome, "hull", M.hull)
	render.OverrideDepthEnable(false, false)
	M.flat:SetVector("$color", Vector(light or 1, light or 1, light or 1))
	DrawLayer(dfr, G.dome, "opaque", M.flat)
	local bfr = Model.Child(dfr, vector_origin, Angle(0, CurTime() * 25, 0))
	M.flat:SetVector("$color", CoreTint(Vector(col.x / 255, col.y / 255, col.z / 255), light or 1))
	DrawLayer(bfr, G.blob, "opaque", M.flat)
	G.blob.still = G.blob.still or BuildMeshes(StillTendrils(), M.flat, COLOR.opaque)
	DrawLayer(bfr, G.blob, "still", M.flat)
	M.flat:SetVector("$color", WHITE)
	Model.DrawLiquid(dfr, st, col, V.liquid, G.dome)
	DrawLayer(dfr, G.dome, "glass", M.glass)
end

-- Loose energy core
function Model.DrawCoreItem(fr, col)
	Model.Build()
	Model.DrawCore(fr, { time = CurTime(), detail = 0 }, col)
end

---------------------------------------------------------------------------
-- Rick Prime's bomb: a dark sphere studded with 32 octagonal sockets (soccer-ball layout).
-- Each socket is a raised collar whose cone sinks to a lens; the lenses are tinted live
-- (dark maroon when off, pink-red glow when armed / counting down).
---------------------------------------------------------------------------

local BOMB_R = 10
local SOCK_OUT, SOCK_IN, SOCK_LENS = 3.0, 2.2, 1.5
local SOCK_TOP, SOCK_LENS_H = BOMB_R + 1.5, BOMB_R + 0.35
local C_BOMB      = { 40, 44, 52 }
local C_COLLAR    = { 70, 75, 84 }
local C_RIM       = { 136, 142, 152 }
local C_RECESS    = { 30, 24, 30 }
local C_LENS_BASE = { 245, 245, 245 }

-- Socket directions: icosahedron vertices (12) plus its face centres (20)
local SOCKETS = {}
do
	local p = (1 + math.sqrt(5)) / 2
	local V = {
		Vector(-1, p, 0), Vector(1, p, 0), Vector(-1, -p, 0), Vector(1, -p, 0),
		Vector(0, -1, p), Vector(0, 1, p), Vector(0, -1, -p), Vector(0, 1, -p),
		Vector(p, 0, -1), Vector(p, 0, 1), Vector(-p, 0, -1), Vector(-p, 0, 1),
	}
	for _, v in ipairs(V) do SOCKETS[#SOCKETS + 1] = v:GetNormalized() end
	for i = 1, 12 do
		for j = i + 1, 12 do
			for k = j + 1, 12 do
				if math.abs(V[i]:Distance(V[j]) - 2) < 0.01 and math.abs(V[j]:Distance(V[k]) - 2) < 0.01 and math.abs(V[i]:Distance(V[k]) - 2) < 0.01 then
					SOCKETS[#SOCKETS + 1] = ((V[i] + V[j] + V[k]) / 3):GetNormalized()
				end
			end
		end
	end
	-- tilt the pattern so no socket sits exactly on the bottom
	local tilt = Angle(17, 23, 9)
	-- studiomdl turns the compiled models/rmpg/prime_bomb.mdl 90 degrees in yaw; turn the sockets the same
	-- way so the glow sprites sit on its lenses
	local studio = Angle(0, 90, 0)
	for _, d in ipairs(SOCKETS) do
		d:Rotate(tilt)
		d:Rotate(studio)
	end
end
Model.BOMB_SOCKETS = SOCKETS
Model.BOMB_RADIUS = SOCK_TOP

local function SocketBasis(d)
	local a = d:Angle()
	return a, -a:Right(), a:Up()
end

local function BuildBomb()
	local b = NewBuilder()
	b:Lathe(Vector(0, 0, 0), AXIS_Z, Sphere(BOMB_R, 18), 36, C_BOMB)
	local lens = NewBuilder()
	local base = math.sqrt(BOMB_R * BOMB_R - SOCK_OUT * SOCK_OUT) - 0.3
	for _, d in ipairs(SOCKETS) do
		local a, t1, t2 = SocketBasis(d)
		local function P(r, h, k)
			local th = 2 * math.pi * k / 8
			return d * h + t1 * (r * math.cos(th)) + t2 * (r * math.sin(th))
		end
		for k = 0, 7 do
			-- outer wall of the collar (flat sides)
			local b0, b1 = P(SOCK_OUT, base, k), P(SOCK_OUT, base, k + 1)
			local o0, o1 = P(SOCK_OUT * 0.96, SOCK_TOP, k), P(SOCK_OUT * 0.96, SOCK_TOP, k + 1)
			local n = (b1 - b0):Cross(o0 - b0):GetNormalized()
			if n:Dot((b0 + b1) / 2 - d * base) < 0 then n = -n end
			b:Tri("opaque", { b0, n }, { b1, n }, { o1, n }, C_COLLAR)
			b:Tri("opaque", { b0, n }, { o1, n }, { o0, n }, C_COLLAR)
			-- flat rim on top
			local i0, i1 = P(SOCK_IN, SOCK_TOP, k), P(SOCK_IN, SOCK_TOP, k + 1)
			b:Tri("opaque", { o0, d }, { o1, d }, { i1, d }, C_RIM)
			b:Tri("opaque", { o0, d }, { i1, d }, { i0, d }, C_RIM)
			-- cone sinking to the lens
			local l0, l1 = P(SOCK_LENS, SOCK_LENS_H, k), P(SOCK_LENS, SOCK_LENS_H, k + 1)
			local cn = (i1 - i0):Cross(l0 - i0):GetNormalized()
			if cn:Dot(d) < 0 then cn = -cn end
			b:Tri("opaque", { i0, cn }, { i1, cn }, { l1, cn }, C_RECESS)
			b:Tri("opaque", { i0, cn }, { l1, cn }, { l0, cn }, C_RECESS)
		end
		lens:Lathe(d * SOCK_LENS_H, a, Dome(0.7, SOCK_LENS, 4, true), 8, C_LENS_BASE)
	end
	return { body = Finish(b, 0.25), lens = Finish(lens) }
end

-- Just above the lens of socket i, inside the collar, in a frame (for glow sprites)
function Model.BombLens(fr, i)
	return Model.ToWorld(fr, SOCKETS[i] * (SOCK_LENS_H + 1))
end

-- st = { lens = Vector tint 0..1, light = brightness, outline = bool }
function Model.DrawBomb(fr, st)
	if not Model.GB then Model.GB = BuildBomb() end
	local G = Model.GB
	if st.outline ~= false then
		render.OverrideDepthEnable(true, false)
		DrawLayer(fr, G.body, "hull", M.hull)
		render.OverrideDepthEnable(false, false)
	end
	local l = st.light or 1
	M.flat:SetVector("$color", Vector(l, l, l))
	DrawLayer(fr, G.body, "opaque", M.flat)
	M.flat:SetVector("$color", st.lens or Vector(0.4, 0.08, 0.12))
	DrawLayer(fr, G.lens, "opaque", M.flat)
	M.flat:SetVector("$color", WHITE)
end

---------------------------------------------------------------------------
-- Energy shield chip: a hexagonal plate with gold contacts and a glowing hex core (tinted live)
---------------------------------------------------------------------------

local C_CHIP     = { 34, 38, 46 }
local C_CHIP_RIM = { 150, 156, 166 }
local C_GOLD     = { 226, 182, 70 }

local function BuildChip()
	local b = NewBuilder()
	b:Lathe(Vector(0, 0, 0), AXIS_Z, {
		{ 0, 0, true }, { 0, 3.0, true }, { 0.15, 3.2 }, { 0.55, 3.2 }, { 0.7, 3.0, true }, { 0.7, 2.25, true }, { 0.82, 2.1, true }, { 0.82, 0, true },
	}, 6, C_CHIP)
	b:Lathe(Vector(0, 0, 0.66), AXIS_Z, { { 0, 2.95, true }, { 0.12, 2.95, true }, { 0.12, 2.3, true }, { 0, 2.3, true } }, 6, C_CHIP_RIM)
	-- contacts on every side
	for k = 0, 5 do
		local a = math.rad(30 + k * 60)
		local dir = Vector(math.cos(a), math.sin(a), 0)
		for _, off in ipairs({ -0.9, 0, 0.9 }) do
			local side = Vector(-dir.y, dir.x, 0) * off
			b:Super(dir * 3.0 + side + Vector(0, 0, 0.35), Vector(0.45, 0.22, 0.14), 0.4, 0.4, C_GOLD, nil, dir:Angle(), 8, 4)
		end
	end
	local core = NewBuilder()
	core:Lathe(Vector(0, 0, 0.8), AXIS_Z, { { 0, 1.85, true }, { 0.12, 1.85 }, { 0.35, 1.2 }, { 0.42, 0 } }, 6, C_LENS_BASE)
	return { body = Finish(b, 0.12), core = Finish(core) }
end

---------------------------------------------------------------------------
-- Mr. Meeseeks box: a teal cube (half size 1), every side a navy panel with a light circuit border and a green
-- octagon, a blue button on top. The button is a separate mesh so it can be pushed in.
---------------------------------------------------------------------------

local C_MR_BODY   = { 34, 128, 112 }
local C_MR_PANEL  = { 24, 42, 72 }
local C_MR_LINE   = { 84, 196, 168 }
local C_MR_OCT    = { 120, 222, 120 }
local C_MR_BUTTON = { 50, 104, 230 }

local function BuildMrBox()
	local b = NewBuilder()
	b:Super(Vector(0, 0, 0), Vector(1, 1, 1), 0.18, 0.18, C_MR_BODY, nil, nil, 24, 12)
	for _, n in ipairs({ Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1) }) do
		local a = n:Angle()
		local t1, t2 = -a:Right(), a:Up()
		b:Super(n * 0.985, Vector(0.04, 0.8, 0.8), 0.3, 0.3, C_MR_PANEL, nil, a, 12, 6)
		-- circuit border: a frame with notched corners
		for _, s in ipairs({ -1, 1 }) do
			b:Super(n * 1.02 + t1 * (0.66 * s), Vector(0.02, 0.035, 0.5), 0.4, 0.4, C_MR_LINE, nil, a, 6, 4)
			b:Super(n * 1.02 + t2 * (0.66 * s), Vector(0.02, 0.5, 0.035), 0.4, 0.4, C_MR_LINE, nil, a, 6, 4)
			for _, s2 in ipairs({ -1, 1 }) do
				-- chamfered corner joining the two bars
				local along = (t1 * s - t2 * s2):GetNormalized()
				b:Super(n * 1.02 + t1 * (0.58 * s) + t2 * (0.58 * s2), Vector(0.13, 0.035, 0.02), 0.4, 0.4, C_MR_LINE, nil, along:AngleEx(n), 6, 4)
			end
		end
		if n.z < 0.5 then
			b:Lathe(n * 1.0, a, { { 0, 0, true }, { 0, 0.42, true }, { 0.05, 0.42, true }, { 0.05, 0, true } }, 8, C_MR_OCT)
		else
			b:Lathe(n * 1.0, a, { { 0, 0.5, true }, { 0.04, 0.5, true }, { 0.04, 0.4, true }, { 0, 0.4, true } }, 24, C_MR_LINE)
		end
	end
	local btn = NewBuilder()
	btn:Lathe(Vector(0, 0, 0.98), AXIS_Z, { { 0, 0.38, true }, { 0.14, 0.38 }, { 0.22, 0.32 }, { 0.27, 0.18 }, { 0.29, 0 } }, 20, C_MR_BUTTON)
	return { body = Finish(b, 0.035), button = Finish(btn, 0.035) }
end

-- st = { press = 0..1 (button pushed in), light = brightness, outline = bool }
function Model.DrawMeeseeksBox(fr, st)
	if not Model.GM then Model.GM = BuildMrBox() end
	local G = Model.GM
	local bfr = Model.Child(fr, Vector(0, 0, -0.16 * (st.press or 0)))
	if st.outline ~= false then
		render.OverrideDepthEnable(true, false)
		DrawLayer(fr, G.body, "hull", M.hull)
		DrawLayer(bfr, G.button, "hull", M.hull)
		render.OverrideDepthEnable(false, false)
	end
	local l = st.light or 1
	M.flat:SetVector("$color", Vector(l, l, l))
	DrawLayer(fr, G.body, "opaque", M.flat)
	DrawLayer(bfr, G.button, "opaque", M.flat)
	M.flat:SetVector("$color", WHITE)
end

-- st = { glow = Vector tint 0..1, light = brightness, outline = bool }
function Model.DrawChip(fr, st)
	if not Model.GC then Model.GC = BuildChip() end
	local G = Model.GC
	if st.outline ~= false then
		render.OverrideDepthEnable(true, false)
		DrawLayer(fr, G.body, "hull", M.hull)
		render.OverrideDepthEnable(false, false)
	end
	local l = st.light or 1
	M.flat:SetVector("$color", Vector(l, l, l))
	DrawLayer(fr, G.body, "opaque", M.flat)
	M.flat:SetVector("$color", st.glow or Vector(0.3, 0.95, 1))
	DrawLayer(fr, G.core, "opaque", M.flat)
	M.flat:SetVector("$color", WHITE)
end

---------------------------------------------------------------------------
-- Mr. Meeseeks face: the body is the GMod corpse player model painted blue (see rmpg_meeseeks.lua); these small meshes add
-- his eyes, mouth and the orange tuft. Face space: +X out of the face, +Y to his left, +Z up, origin at the head bone
-- (measured on models/player/corpse1.mdl: the face surface is about 3 units in front of the bone).
---------------------------------------------------------------------------

local C_MR_INK   = { 18, 22, 30 }
local C_MR_MOUTH = { 140, 34, 86 }
local C_MR_TEETH = { 248, 248, 244 }
local C_MR_TUFT  = { 242, 122, 44 }
local MR_Y0 = -0.9 -- middle of the face
local MR_EYE_Z, MR_MOUTH_Z, MR_FRONT = 4.3, 1.5, 3.25

local function Line(b, fn, u0, u1, r, col)
	local pts, radii = {}, {}
	for i = 0, 10 do
		local u = Lerp(i / 10, u0, u1)
		pts[#pts + 1] = fn(u)
		radii[#radii + 1] = r * (0.45 + 0.55 * math.sin(i / 10 * math.pi))
	end
	b:Tube(pts, radii, 6, col)
end

local function Fill(b, pts, col, x)
	local cy, cz = 0, 0
	for _, p in ipairs(pts) do cy, cz = cy + p[1], cz + p[2] end
	local n = Vector(1, 0, 0)
	local c = { Vector(x, cy / #pts, cz / #pts), n }
	for i = 1, #pts do
		local p, q = pts[i], pts[i % #pts + 1]
		b:Tri("opaque", c, { Vector(x, p[1], p[2]), n }, { Vector(x, q[1], q[2]), n }, col)
	end
end

local function MouthTop(u) return MR_MOUTH_Z + 0.45 + 0.06 * u * u end
local function MouthBottom(u) return MouthTop(u) - 1.9 * math.sqrt(math.max(1 - (u / 2.3) ^ 2, 0)) end

local function BuildMeeseeksFace()
	local G = {}
	local b = NewBuilder()
	for _, s in ipairs({ 1, -1 }) do
		local y = MR_Y0 + 1.45 * s
		b:Super(Vector(MR_FRONT, y, MR_EYE_Z), Vector(0.4, 0.62, 0.8), 1, 1, C_MR_INK, nil, nil, 12, 8)
		b:Super(Vector(MR_FRONT + 0.36, y + 0.18, MR_EYE_Z + 0.3), Vector(0.2, 0.2, 0.2), 1, 1, { 255, 255, 255 }, nil, nil, 8, 6)
	end
	G.eyes = Finish(b)
	b = NewBuilder()
	for _, s in ipairs({ 1, -1 }) do
		local y = MR_Y0 + 1.45 * s
		Line(b, function(u) return Vector(MR_FRONT + 0.1, y + u, MR_EYE_Z - 0.15 - 0.25 * u * u) end, -0.7, 0.7, 0.18, C_MR_INK)
	end
	G.eyesShut = Finish(b)
	b = NewBuilder()
	Line(b, function(u) return Vector(MR_FRONT - 0.05 * u * u, MR_Y0 + u, MR_MOUTH_Z + 0.1 * u * u) end, -2.5, 2.5, 0.2, C_MR_INK)
	G.mouthShut = Finish(b)
	b = NewBuilder()
	local outline = {}
	for i = 0, 10 do
		local u = Lerp(i / 10, 2.3, -2.3)
		outline[#outline + 1] = { MR_Y0 + u, MouthTop(u) }
	end
	for i = 1, 9 do
		local u = Lerp(i / 10, -2.3, 2.3)
		outline[#outline + 1] = { MR_Y0 + u, MouthBottom(u) }
	end
	Fill(b, outline, C_MR_MOUTH, MR_FRONT)
	for k = 0, 4 do
		local u = -1.6 + k * 0.8
		local z = MouthTop(u) - 0.35
		b:Super(Vector(MR_FRONT + 0.06, MR_Y0 + u, z), Vector(0.05, 0.33, 0.3), 0.5, 0.5, C_MR_TEETH, nil, nil, 6, 4)
	end
	Line(b, function(u) return Vector(MR_FRONT + 0.05, MR_Y0 + u, MouthTop(u)) end, -2.4, 2.4, 0.18, C_MR_INK)
	Line(b, function(u) return Vector(MR_FRONT + 0.05, MR_Y0 + u, MouthBottom(u)) end, -2.3, 2.3, 0.18, C_MR_INK)
	G.mouthOpen = Finish(b)
	b = NewBuilder()
	local top = Vector(-0.1, MR_Y0 - 0.3, 8.0)
	for k = 0, 4 do
		local a = math.rad(k * 72 + 20)
		local dir = Vector(math.cos(a) * 0.8, math.sin(a) * 0.8, 1):GetNormalized()
		b:Super(top + dir * 0.8, Vector(1.0, 0.35, 0.4), 0.6, 0.6, C_MR_TUFT, nil, dir:Angle(), 10, 6)
	end
	G.tuft = Finish(b, 0.12)
	return G
end

-- fr: face frame on the head bone; st = { talk, blink, light }
function Model.DrawMeeseeksFace(fr, st)
	if not Model.GMrFace then Model.GMrFace = BuildMeeseeksFace() end
	local G = Model.GMrFace
	local l = st.light or 1
	M.flat:SetVector("$color", Vector(l, l, l))
	render.OverrideDepthEnable(true, false)
	DrawLayer(fr, G.tuft, "hull", M.hull)
	render.OverrideDepthEnable(false, false)
	DrawLayer(fr, G.tuft, "opaque", M.flat)
	DrawLayer(fr, st.blink and G.eyesShut or G.eyes, "opaque", M.flat)
	DrawLayer(fr, st.talk and G.mouthOpen or G.mouthShut, "opaque", M.flat)
	M.flat:SetVector("$color", WHITE)
end
