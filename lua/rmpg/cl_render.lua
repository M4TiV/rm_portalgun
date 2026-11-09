-- Client: materials and low level drawing helpers (portal texture, deformable portal mesh, sprites)
RMPG = RMPG or {}
RMPG.Mat = RMPG.Mat or {}

-- Untextured, vertex coloured materials for the procedural gun model
local function Flat(name, kind)
	local params = { ["$basetexture"] = "vgui/white", ["$vertexcolor"] = 1, ["$nocull"] = 1 }
	if kind == "alpha" then
		params["$translucent"] = 1
		params["$vertexalpha"] = 1
	elseif kind == "add" then
		params["$additive"] = 1
		params["$vertexalpha"] = 1
	end
	return CreateMaterial(name, "UnlitGeneric", params)
end

local M = RMPG.Mat
-- Our textures are used through the PNG materials themselves (alpha blended, vertex coloured);
-- glows and beams use stock additive materials that are always textured.
M.sheet   = Material("rmpg/portal_sheet.png", "smooth mips nocull")
M.outline = Material("rmpg/portal_outline.png", "smooth mips nocull")
M.ring    = Material("rmpg/ring.png", "smooth mips nocull")
M.glow    = Material("sprites/light_glow02_add")
M.spark   = Material("sprites/light_glow02_add")
M.beam    = Material("trails/laser")
M.flat    = Flat("rmpg_flat3")
M.hull    = Flat("rmpg_hull3")
M.glass   = Flat("rmpg_glass3", "alpha")
M.liquid  = Flat("rmpg_liquid3", "alpha")
M.tint    = Flat("rmpg_tint3", "alpha")
M.add     = Flat("rmpg_add3", "add")
-- 2D (surface library) versions
M.sheet2D   = Material("rmpg/portal_sheet.png", "smooth")
M.outline2D = Material("rmpg/portal_outline.png", "smooth")
M.glow2D    = Material("rmpg/glow.png", "smooth")
M.ring2D    = Material("rmpg/ring.png", "smooth")

local WHITE = Vector(1, 1, 1)
function RMPG.ResetTints()
	M.flat:SetVector("$color", WHITE)
	M.liquid:SetVector("$color", WHITE)
	M.tint:SetVector("$color", WHITE)
	M.add:SetVector("$color", WHITE)
end

-- UV rectangle of an animation frame in the sprite sheet
function RMPG.FrameUV(frame)
	local S = RMPG.Shape
	local i = frame - 1
	local col, row = i % S.cols, math.floor(i / S.cols)
	local c = S.cell / S.sheet
	local e = 0.5 / S.sheet
	return col * c + e, row * c + e, (col + 1) * c - e, (row + 1) * c - e
end

-- Quad centred at c spanning ax (right) and ay (up)
function RMPG.DrawQuad(c, ax, ay, hw, hh, u0, v0, u1, v1, r, g, b, a)
	local x, y = ax * hw, ay * hh
	mesh.Begin(MATERIAL_QUADS, 1)
		mesh.Position(c - x + y) mesh.TexCoord(0, u0, v0) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
		mesh.Position(c + x + y) mesh.TexCoord(0, u1, v0) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
		mesh.Position(c + x - y) mesh.TexCoord(0, u1, v1) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
		mesh.Position(c - x - y) mesh.TexCoord(0, u0, v1) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
	mesh.End()
end

local function clamp255(v) return v > 255 and 255 or (v < 0 and 0 or v) end

---------------------------------------------------------------------------
-- Deformable portal surface (only used up close, where it can be seen)
---------------------------------------------------------------------------

local GRID = 12
local gx, gy, gz = {}, {}, {}

-- bulges = { {x, y, s, r}, ... } in plane coordinates: the surface reaches toward things in front of it
local function BuildSurface(half, bulges, t)
	local n = GRID
	local idx = 0
	for j = 0, n do
		for i = 0, n do
			idx = idx + 1
			local u, v = -1 + 2 * i / n, 1 - 2 * j / n
			local x, y = u * half, v * half
			local rr = math.sqrt(u * u + v * v)
			local z = math.sin(t * 3.2 - rr * 6) * 0.7 * math.min(rr, 1)
			for k = 1, #bulges do
				local b = bulges[k]
				local dx, dy = x - b[1], y - b[2]
				local w = math.exp(-(dx * dx + dy * dy) / (b[4] * b[4]))
				local pull = 0.12 * math.min(math.abs(b[3]) / 12, 1) * w
				z = z + b[3] * w
				x, y = x - dx * pull, y - dy * pull
			end
			gx[idx], gy[idx], gz[idx] = x, y, z
		end
	end
end

local function DrawSurface(c, f, ax, ay, scale, zoff, u0, v0, u1, v1, r, g, b, a)
	local n = GRID
	local du, dv = (u1 - u0) / n, (v1 - v0) / n
	mesh.Begin(MATERIAL_QUADS, n * n)
	for j = 0, n - 1 do
		for i = 0, n - 1 do
			local i00 = j * (n + 1) + i + 1
			local i10, i11, i01 = i00 + 1, i00 + n + 2, i00 + n + 1
			local ua, ub = u0 + i * du, u0 + (i + 1) * du
			local va, vb = v0 + j * dv, v0 + (j + 1) * dv
			mesh.Position(c + ax * (gx[i00] * scale) + ay * (gy[i00] * scale) + f * (gz[i00] + zoff)) mesh.TexCoord(0, ua, va) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
			mesh.Position(c + ax * (gx[i10] * scale) + ay * (gy[i10] * scale) + f * (gz[i10] + zoff)) mesh.TexCoord(0, ub, va) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
			mesh.Position(c + ax * (gx[i11] * scale) + ay * (gy[i11] * scale) + f * (gz[i11] + zoff)) mesh.TexCoord(0, ub, vb) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
			mesh.Position(c + ax * (gx[i01] * scale) + ay * (gy[i01] * scale) + f * (gz[i01] + zoff)) mesh.TexCoord(0, ua, vb) mesh.Color(r, g, b, a) mesh.AdvanceVertex()
		end
	end
	mesh.End()
end

-- The portal: the GIF swirl, a soft halo and the glowing outline baked from the texture's contour.
-- dist is the distance to the camera (far portals are drawn as flat quads to keep it cheap).
function RMPG.DrawPortal(center, ang, half, col, alpha, frame, core, bulges, dist)
	local f, ax, ay = RMPG.PortalAxes(ang)
	local u0, v0, u1, v1 = RMPG.FrameUV(frame)
	local r, g, b = col.x, col.y, col.z
	local a = 255 * math.Clamp(alpha, 0, 1)
	local t = CurTime()
	local c = center + f * 0.25
	dist = dist or 0
	local orr, org, orb = clamp255(r * 0.55 + 115), clamp255(g * 0.55 + 115), clamp255(b * 0.55 + 115)

	render.SetMaterial(M.glow)
	RMPG.DrawQuad(c - f * 0.15, ax, ay, half * 1.35, half * 1.35, 0, 0, 1, 1, r * 0.6, g * 0.6, b * 0.6, a)

	if dist < 900 and bulges and #bulges > 0 then
		BuildSurface(half, bulges, t)
		render.SetMaterial(M.sheet)
		DrawSurface(c, f, ax, ay, 1, 0, u0, v0, u1, v1, r, g, b, a)
		render.SetMaterial(M.outline)
		DrawSurface(c, f, ax, ay, 1, 0.1, u0, v0, u1, v1, orr, org, orb, a)
	else
		render.SetMaterial(M.sheet)
		RMPG.DrawQuad(c, ax, ay, half, half, u0, v0, u1, v1, r, g, b, a)
		render.SetMaterial(M.outline)
		RMPG.DrawQuad(c + f * 0.1, ax, ay, half, half, u0, v0, u1, v1, orr, org, orb, a)
	end
	if dist < 1500 then
		local pulse = 0.5 + 0.5 * math.sin(t * 6)
		RMPG.DrawQuad(c + f * 0.12, ax, ay, half * 1.04, half * 1.04, u0, v0, u1, v1, r, g, b, a * (0.25 + 0.35 * pulse))
	end

	-- bright heart of the swirl
	render.SetMaterial(M.glow)
	RMPG.DrawQuad(c + f * 0.3, ax, ay, half * 0.5, half * 0.5, 0, 0, 1, 1, r * 0.35, g * 0.35, b * 0.35, a)

	if core and dist < 1500 then
		-- energy core portals crackle along the rim
		render.SetMaterial(M.beam)
		local seed = math.floor(t * 20)
		for k = 1, 3 do
			local th = util.SharedRandom("rmpg_arc", 0, math.pi * 2, seed * 3 + k)
			local prev
			for j = 0, 4 do
				local tt = th + j * 0.12
				local rr = half * RMPG.ShapeRadius(frame, tt) * (1 + util.SharedRandom("rmpg_arcj", -0.06, 0.06, seed * 31 + k * 7 + j))
				local p = c + f * 0.4 + ax * (math.cos(tt) * rr) + ay * (math.sin(tt) * rr)
				if prev then render.DrawBeam(prev, p, 4, 0, 1, Color(orr, org, orb, a)) end
				prev = p
			end
		end
	end
end

-- Flat ring lying in the plane (normal n)
function RMPG.DrawRing(c, n, radius, r, g, b, a)
	local ang = n:Angle()
	render.SetMaterial(M.ring)
	RMPG.DrawQuad(c, ang:Right(), ang:Up(), radius, radius, 0, 0, 1, 1, r, g, b, a)
end

-- Soft glow disc lying in a plane
function RMPG.DrawGlowDisc(c, n, radius, r, g, b, a)
	local ang = n:Angle()
	render.SetMaterial(M.glow)
	RMPG.DrawQuad(c, ang:Right(), ang:Up(), radius, radius, 0, 0, 1, 1, r, g, b, a)
end

-- Limits how many dynamic lights the addon creates in one frame (they are expensive)
local lightFrame, lightCount = 0, 0
function RMPG.LightBudget(limit)
	local fn = FrameNumber()
	if fn ~= lightFrame then lightFrame, lightCount = fn, 0 end
	if lightCount >= (limit or 4) then return false end
	lightCount = lightCount + 1
	return true
end

-- Converts a point drawn with the viewmodel FOV to the world point that appears in the same place
function RMPG.VMToWorld(pos, vmFov)
	local ep, ea = EyePos(), EyeAngles()
	local d = pos - ep
	local F, R, U = ea:Forward(), ea:Right(), ea:Up()
	local x, y, z = d:Dot(F), d:Dot(R), d:Dot(U)
	local wf = LocalPlayer():GetFOV()
	local k = math.tan(math.rad(wf * 0.5)) / math.tan(math.rad((vmFov or 54) * 0.5))
	return ep + F * x + R * (y * k) + U * (z * k)
end

-- Draws an animated portal swirl inside a 2D panel
function RMPG.DrawSwirl2D(x, y, size, col, alpha, frame)
	frame = frame or RMPG.ShapeFrame(RealTime())
	local u0, v0, u1, v1 = RMPG.FrameUV(frame)
	local r, g, b = col.r or col.x, col.g or col.y, col.b or col.z
	alpha = alpha or 255
	surface.SetMaterial(M.glow2D)
	surface.SetDrawColor(r, g, b, alpha * 0.45)
	surface.DrawTexturedRect(x - size * 0.3, y - size * 0.3, size * 1.6, size * 1.6)
	surface.SetMaterial(M.sheet2D)
	surface.SetDrawColor(r, g, b, alpha)
	surface.DrawTexturedRectUV(x, y, size, size, u0, v0, u1, v1)
	surface.SetMaterial(M.outline2D)
	surface.SetDrawColor(clamp255(r * 0.6 + 110), clamp255(g * 0.6 + 110), clamp255(b * 0.6 + 110), alpha)
	surface.DrawTexturedRectUV(x, y, size, size, u0, v0, u1, v1)
end
