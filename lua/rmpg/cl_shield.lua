-- Client: the energy shield. Normally invisible; a hit lights up a patch of cyan hexagons around the impact with a
-- ripple running over the bubble, a crack throws the cells off with electric arcs, and a restored shield is
-- scanned in from the feet up. In first person the hexagons flash at the screen edge on the side of the hit.
RMPG = RMPG or {}
RMPG.ShieldFX = RMPG.ShieldFX or {}

local M = RMPG.Mat
M.hex = Material("rmpg/hex.png", "smooth mips nocull")
M.hex2D = Material("rmpg/hex.png", "smooth")

local UP = Vector(0, 0, 1)
local CYAN = Color(90, 230, 255)
local HIT_LIFE, BREAK_LIFE, UP_LIFE = 0.75, 1.1, 1.3

-- Cells spread evenly over a unit sphere (Fibonacci lattice)
local CELLS = {}
do
	local N = 150
	local ga = math.pi * (3 - math.sqrt(5))
	for i = 0, N - 1 do
		local z = 1 - 2 * (i + 0.5) / N
		local r = math.sqrt(1 - z * z)
		local a = ga * i
		CELLS[#CELLS + 1] = { d = Vector(math.cos(a) * r, math.sin(a) * r, z), rnd = (i * 0.618034) % 1 }
	end
end

net.Receive("rmpg_shield_fx", function()
	local ply = net.ReadEntity()
	local kind = net.ReadUInt(2)
	local dir = net.ReadNormal()
	local k = net.ReadUInt(7) / 100
	if not IsValid(ply) then return end
	local fx = RMPG.ShieldFX[ply] or { hits = {} }
	RMPG.ShieldFX[ply] = fx
	local now = CurTime()
	if kind == RMPG.SHIELD_HIT then
		table.insert(fx.hits, { dir = dir, t = now, k = k })
		while #fx.hits > 6 do table.remove(fx.hits, 1) end
	elseif kind == RMPG.SHIELD_BREAK then
		fx.brk = now
		fx.brkDir = dir
		fx.hits = {}
	else
		fx.up = now
	end
	if ply == LocalPlayer() then fx.screen = now end
end)

local function Arc(a, b, width, col, segs, jitter)
	local prev = a
	for i = 1, segs do
		local f = i / segs
		local p = LerpVector(f, a, b)
		if i < segs then p = p + VectorRand() * jitter * math.sin(f * math.pi) end
		render.DrawBeam(prev, p, width, 0, 1, col)
		prev = p
	end
end

-- Bubble size around a player (follows crouching)
local function Bubble(ply)
	local mins, maxs = ply:OBBMins(), ply:OBBMaxs()
	return ply:WorldSpaceCenter(), 27, math.max(30, (maxs.z - mins.z) * 0.5 + 9)
end

-- Brightness 0..1 of a cell from hits, the crack and the restore scan; also its outward offset when cracking
local function CellAlpha(fx, cell, now)
	local a, push = 0, 0
	for _, h in ipairs(fx.hits) do
		local age = now - h.t
		if age < HIT_LIFE then
			local I = (1 - age / HIT_LIFE) ^ 1.5 * (0.45 + 0.55 * h.k)
			local ang = math.acos(math.Clamp(cell.d:Dot(h.dir), -1, 1))
			local ripple = age * 4.2
			a = a + I * (math.exp(-(ang / 0.5) ^ 2) + 0.55 * math.exp(-((ang - ripple) / 0.28) ^ 2) + 0.1)
		end
	end
	if fx.brk then
		local age = now - fx.brk
		if age < BREAK_LIFE then
			a = a + (1 - age / BREAK_LIFE) ^ 1.3
			push = age * (40 + 70 * cell.rnd)
		end
	end
	if fx.up then
		local age = now - fx.up
		if age < UP_LIFE then
			local scan = age / (UP_LIFE * 0.7) * 2 - 1 -- from -1 (feet) to 1 (head)
			local below = cell.d.z < scan
			a = a + math.exp(-((cell.d.z - scan) / 0.18) ^ 2) + (below and 0.3 * (1 - age / UP_LIFE) or 0)
		end
	end
	return math.min(a, 1.4), push
end

local function Active(fx, now)
	if fx.brk and now - fx.brk < BREAK_LIFE then return true end
	if fx.up and now - fx.up < UP_LIFE then return true end
	for _, h in ipairs(fx.hits) do
		if now - h.t < HIT_LIFE then return true end
	end
	return false
end

local function DrawBubble(ply, fx, now)
	local c, rx, rz = Bubble(ply)
	local eye = EyePos()
	local verts = {}
	local vis = 0
	for _, cell in ipairs(CELLS) do
		local a, push = CellAlpha(fx, cell, now)
		if a > 0.02 then
			local d = cell.d
			local n = Vector(d.x / rx, d.y / rx, d.z / rz)
			n:Normalize()
			local p = c + Vector(d.x * rx, d.y * rx, d.z * rz) + n * push
			if push > 0 then p = p - UP * push * push * 0.01 end
			local facing = n:Dot(eye - p) > 0
			if not facing then a = a * 0.4 end
			local t1 = math.abs(n.z) > 0.95 and Vector(1, 0, 0) or n:Cross(UP)
			t1:Normalize()
			local t2 = t1:Cross(n)
			if push > 0 then
				-- cracked cells tumble
				local spin = push * 0.05 * (cell.rnd - 0.5)
				t1, t2 = t1 * math.cos(spin) + t2 * math.sin(spin), t2 * math.cos(spin) - t1 * math.sin(spin)
			end
			verts[#verts + 1] = { p, t1 * 5.8, t2 * 5.8, math.min(a, 1) }
			vis = math.max(vis, a)
		end
	end
	if #verts == 0 then return end

	-- faint rim of the whole bubble
	local ang = (eye - c):Angle()
	render.SetMaterial(M.ring)
	RMPG.DrawQuad(c, ang:Right(), ang:Up(), rx * 1.08, rz * 1.04, 0, 0, 1, 1, CYAN.r, CYAN.g, CYAN.b, 110 * math.min(vis, 1))

	render.SetMaterial(M.hex)
	mesh.Begin(MATERIAL_QUADS, #verts)
	for _, v in ipairs(verts) do
		local p, x, y, a = v[1], v[2], v[3], v[4]
		local w = math.Clamp((a - 0.7) * 2, 0, 1) -- the brightest cells go white
		local r, g, b = Lerp(w, CYAN.r, 230), Lerp(w, CYAN.g, 252), 255
		mesh.Position(p - x + y) mesh.TexCoord(0, 0, 0) mesh.Color(r, g, b, 255 * a) mesh.AdvanceVertex()
		mesh.Position(p + x + y) mesh.TexCoord(0, 1, 0) mesh.Color(r, g, b, 255 * a) mesh.AdvanceVertex()
		mesh.Position(p + x - y) mesh.TexCoord(0, 1, 1) mesh.Color(r, g, b, 255 * a) mesh.AdvanceVertex()
		mesh.Position(p - x - y) mesh.TexCoord(0, 0, 1) mesh.Color(r, g, b, 255 * a) mesh.AdvanceVertex()
	end
	mesh.End()

	-- impact flashes: a glow and a little star of sparks where it hit
	render.SetMaterial(M.glow)
	for _, h in ipairs(fx.hits) do
		local age = now - h.t
		if age < 0.35 then
			local I = (1 - age / 0.35) * (0.5 + 0.5 * h.k)
			local hp = c + Vector(h.dir.x * rx, h.dir.y * rx, h.dir.z * rz)
			render.DrawSprite(hp, 70 * I, 70 * I, Color(CYAN.r, CYAN.g, CYAN.b, 255 * I))
			render.DrawSprite(hp, 24 * I, 24 * I, Color(255, 255, 255, 255 * I))
			render.SetMaterial(M.beam)
			local t1 = h.dir:Cross(UP)
			if t1:LengthSqr() < 0.01 then t1 = Vector(1, 0, 0) end
			t1:Normalize()
			local t2 = t1:Cross(h.dir)
			for i = 0, 5 do
				local a = i / 6 * math.pi * 2 + h.t * 7
				local sdir = t1 * math.cos(a) + t2 * math.sin(a) + h.dir * 0.4
				render.DrawBeam(hp, hp + sdir * (10 + 16 * I) * I, 3 * I, 0, 1, Color(200, 250, 255, 255 * I))
			end
			render.SetMaterial(M.glow)
		end
	end

	-- electric arcs crawling over the bubble when it cracks or comes back
	local arcs = 0
	if fx.brk and now - fx.brk < 0.6 then arcs = 7 end
	if fx.up and now - fx.up < UP_LIFE * 0.8 then arcs = math.max(arcs, 4) end
	if arcs > 0 then
		render.SetMaterial(M.beam)
		for _ = 1, arcs do
			local d1 = VectorRand():GetNormalized()
			local d2 = (d1 + VectorRand() * 0.8):GetNormalized()
			local a = c + Vector(d1.x * rx, d1.y * rx, d1.z * rz)
			local b = c + Vector(d2.x * rx, d2.y * rx, d2.z * rz)
			Arc(a, b, 2.5, CYAN, 6, 5)
			Arc(a, b, 1, color_white, 6, 3)
		end
	end
end

hook.Add("PostDrawTranslucentRenderables", "rmpg_shield", function(depth, sky)
	if depth or sky then return end
	local now = CurTime()
	local me = LocalPlayer()
	for ply, fx in pairs(RMPG.ShieldFX) do
		if not IsValid(ply) then
			RMPG.ShieldFX[ply] = nil
		elseif Active(fx, now) then
			if ply:Alive() and not (ply == me and not ply:ShouldDrawLocalPlayer()) then DrawBubble(ply, fx, now) end
		elseif not (fx.screen and now - fx.screen < 2) then
			RMPG.ShieldFX[ply] = nil
		end
	end
end)

---------------------------------------------------------------------------
-- First person: hexagons flash at the screen edges (brighter on the side of the hit)
---------------------------------------------------------------------------

local function DrawScreenHex()
	local me = LocalPlayer()
	local fx = RMPG.ShieldFX[me]
	if not fx or me:ShouldDrawLocalPlayer() then return end
	local now = CurTime()
	local sw, sh = ScrW(), ScrH()
	local ea = EyeAngles()
	local R, Fw, Up = ea:Right(), ea:Forward(), ea:Up()

	-- strength and screen direction of every effect
	local list, total = {}, 0
	for _, h in ipairs(fx.hits) do
		local age = now - h.t
		if age < 0.6 then
			local I = (1 - age / 0.6) ^ 1.5 * (0.4 + 0.6 * h.k)
			local sx, sy = h.dir:Dot(R), -h.dir:Dot(Up)
			local l = math.sqrt(sx * sx + sy * sy)
			list[#list + 1] = { I, l > 0.2 and sx / l or 0, l > 0.2 and sy / l or 0, h.dir:Dot(Fw) }
			total = total + I
		end
	end
	local brk = fx.brk and now - fx.brk < 0.9 and (1 - (now - fx.brk) / 0.9) or 0
	local up = fx.up and now - fx.up < UP_LIFE and (now - fx.up) / UP_LIFE or nil
	if total <= 0.01 and brk <= 0 and not up then return end

	surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 40 * math.min(total, 1) + 90 * brk)
	surface.DrawRect(0, 0, sw, sh)

	local cell = math.floor(sh / 15)
	local stepX, stepY = cell * 1.5, cell * 1.732
	local size = cell * 2.2
	local cx, cy = sw / 2, sh / 2
	local half = math.sqrt(cx * cx + cy * cy)
	surface.SetMaterial(M.hex2D)
	local col = 0
	for x = -cell, sw + cell, stepX do
		local yoff = (col % 2 == 1) and stepY / 2 or 0
		col = col + 1
		for y = -cell + yoff, sh + cell, stepY do
			local dx, dy = x - cx, y - cy
			local dist = math.sqrt(dx * dx + dy * dy) / half
			local edge = math.Clamp((dist - 0.42) / 0.58, 0, 1) ^ 1.4
			local a = 0
			for _, e in ipairs(list) do
				local side = 1
				if e[2] ~= 0 or e[3] ~= 0 then side = 0.25 + 0.75 * math.Clamp((dx * e[2] + dy * e[3]) / (dist * half + 1) * 0.5 + 0.5, 0, 1) ^ 2 end
				a = a + e[1] * side
			end
			a = a * edge + brk * (0.5 * edge + 0.25)
			local ox, oy = 0, 0
			if brk > 0 then
				local k = (1 - brk) * 60
				ox, oy = dx / (dist * half + 1) * k, dy / (dist * half + 1) * k
			end
			if up then
				local scan = sh * (1 - up * 1.2)
				a = a + math.exp(-((y - scan) / (sh * 0.06)) ^ 2) * 0.8 * edge + (y > scan and 0.15 * edge * (1 - up) or 0)
			end
			if a > 0.02 then
				surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, math.min(255, 220 * a))
				surface.DrawTexturedRect(x - size / 2 + ox, y - size / 2 + oy, size, size)
			end
		end
	end
end

---------------------------------------------------------------------------
-- HUD: shield strength above the health (bottom left)
---------------------------------------------------------------------------

local BG = Color(3, 14, 11, 215)
local EDGE = Color(90, 230, 255)
local TEXT = Color(222, 250, 255)
local MUTED = Color(120, 190, 210)
local RED = Color(255, 64, 84)

local function DrawShieldHUD()
	local me = LocalPlayer()
	if not me:Alive() or not me:GetNW2Bool("RMPG_Shield", false) or not RMPG.CL.hud:GetBool() then return end
	local now = RealTime()
	local pct = me:GetNW2Float("RMPG_ShieldPct", 100)
	local back = me:GetNW2Float("RMPG_ShieldBack", 0)
	local w, h = 300, 62
	local x, y = 28, ScrH() - h - 150

	surface.SetMaterial(M.glow2D)
	surface.SetDrawColor(60, 220, 255, 22)
	surface.DrawTexturedRect(x - 70, y - 90, 240, 240)
	RMPG.HoloBox(x, y, w, h, BG, back > 0 and RED or EDGE)

	-- hexagon icon
	surface.SetMaterial(M.hex2D)
	local ic = back > 0 and Color(RED.r, RED.g, RED.b, 140 + 115 * math.abs(math.sin(now * 5))) or EDGE
	surface.SetDrawColor(ic)
	surface.DrawTexturedRect(x + 10, y + 9, 44, 44)

	local tx = x + 64
	RMPG.HoloText(RMPG.T("hud_shield"), "RMPG_SmallB", tx, y + 10, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local segs, bx, by = 20, tx, y + 34
	local bw = (x + w - 14 - bx) / segs
	if back > 0 then
		local left = math.max(back - CurTime(), 0)
		local total = math.max(RMPG.CV.shieldRecover:GetFloat(), 1)
		local f = 1 - left / total
		RMPG.HoloText(string.format(RMPG.T("hud_shield_down"), math.floor(left / 60), math.floor(left % 60)), "RMPG_SmallB", x + w - 14, y + 10, ic, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		for k = 0, segs - 1 do
			local lit = (k + 0.5) / segs <= f
			surface.SetDrawColor(lit and Color(RED.r, RED.g, RED.b, 150) or Color(40, 10, 16, 230))
			surface.DrawRect(bx + k * bw, by, bw - 3, 12)
		end
		return
	end
	RMPG.HoloText(math.floor(pct + 0.5) .. "%", "RMPG_Head", x + w - 14, y + 6, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	for k = 0, segs - 1 do
		local lit = (k + 0.5) / segs <= pct / 100
		surface.SetDrawColor(lit and EDGE or Color(8, 32, 40, 230))
		surface.DrawRect(bx + k * bw, by, bw - 3, 12)
	end
	if pct < 100 then
		-- recharging shimmer running along the bar
		local sx = bx + ((now * 0.8) % 1) * (pct / 100) * (x + w - 14 - bx)
		surface.SetDrawColor(255, 255, 255, 120)
		surface.DrawRect(sx, by, 3, 12)
	end
end

hook.Add("HUDPaint", "rmpg_shield", function()
	DrawScreenHex()
	DrawShieldHUD()
end)
