-- Client: fonts, notifications, gun HUD, crosshair, shot tracers, placement preview, screen effects
RMPG = RMPG or {}

local function Font(name, font, size, weight)
	surface.CreateFont(name, { font = font, size = size, weight = weight or 500, extended = true, antialias = true })
end
Font("RMPG_Title", "Trebuchet MS", 30, 900)
Font("RMPG_Head", "Trebuchet MS", 20, 800)
Font("RMPG_Sub", "Trebuchet MS", 15, 700)
Font("RMPG_Body", "Tahoma", 16, 500)
Font("RMPG_BodyB", "Tahoma", 16, 800)
Font("RMPG_Small", "Tahoma", 13, 500)
Font("RMPG_SmallB", "Tahoma", 13, 800)
Font("RMPG_Big", "Trebuchet MS", 44, 900)
Font("RMPG_Mono", "Consolas", 20, 700)
Font("RMPG_MonoBig", "Consolas", 52, 900)

local function Alpha(c, a) return Color(c.r, c.g, c.b, a) end

function RMPG.AccentOf(wep)
	local c = (IsValid(wep) and wep.FluidColor) and wep:FluidColor() or RMPG.LocalColor()
	return Color(c.x, c.y, c.z, 255)
end

---------------------------------------------------------------------------
-- Notifications
---------------------------------------------------------------------------

RMPG.Notes = RMPG.Notes or {}
local KIND_COLOR = {
	[0] = nil, -- accent
	[1] = Color(255, 80, 70),
	[2] = Color(90, 230, 120),
	[3] = Color(255, 120, 40),
}

function RMPG.AddNote(text, kind)
	table.insert(RMPG.Notes, 1, { text = text, kind = kind or 0, t = RealTime() })
	while #RMPG.Notes > 4 do table.remove(RMPG.Notes) end
	if RMPG.CL.uisounds:GetBool() then
		surface.PlaySound(kind == 1 and RMPG.SND.uiError or (kind == 3 and RMPG.SND.beep or RMPG.SND.uiClick))
	end
end

net.Receive("rmpg_notify", function()
	local key = net.ReadString()
	local args = net.ReadTable()
	local kind = net.ReadUInt(2)
	-- "#key" in the arguments is a text of its own, in this player's language
	for i, a in ipairs(args) do
		if isstring(a) and string.sub(a, 1, 1) == "#" then args[i] = RMPG.T(string.sub(a, 2)) end
	end
	RMPG.AddNote(RMPG.T(key, unpack(args)), kind)
end)

-- Hologram style shared by the HUD and the notifications (same look as the menu)
local H_GREEN = Color(90, 255, 150)
local H_GREEN_MD = Color(40, 170, 100)
local H_GREEN_DK = Color(20, 80, 50)
local H_RED = Color(255, 64, 84)
local H_BG = Color(3, 14, 11, 215)
local H_TEXT = Color(222, 255, 234)
local H_MUTED = Color(122, 204, 162)

function RMPG.HoloBox(x, y, w, h, fill, edge)
	surface.SetDrawColor(fill)
	surface.DrawRect(x, y, w, h)
	edge = edge or H_GREEN_MD
	surface.SetDrawColor(edge.r, edge.g, edge.b, 160)
	surface.DrawOutlinedRect(x, y, w, h, 1)
	if w > 12 and h > 12 then
		surface.SetDrawColor(edge.r, edge.g, edge.b, 34)
		surface.DrawOutlinedRect(x + 3, y + 3, w - 6, h - 6, 1)
	end
	local L = math.floor(math.min(12, w / 4, h / 4))
	surface.SetDrawColor(edge.r, edge.g, edge.b, 255)
	surface.DrawRect(x, y, L, 2) surface.DrawRect(x, y, 2, L)
	surface.DrawRect(x + w - L, y, L, 2) surface.DrawRect(x + w - 2, y, 2, L)
	surface.DrawRect(x, y + h - 2, L, 2) surface.DrawRect(x, y + h - L, 2, L)
	surface.DrawRect(x + w - L, y + h - 2, L, 2) surface.DrawRect(x + w - 2, y + h - L, 2, L)
end

-- Text with a slight red / green split
function RMPG.HoloText(text, font, x, y, col, ax, ay)
	local a = (col.a or 255) / 255
	draw.SimpleText(text, font, x - 1, y, Color(255, 50, 80, 120 * a), ax, ay)
	draw.SimpleText(text, font, x + 1, y, Color(60, 255, 150, 120 * a), ax, ay)
	draw.SimpleText(text, font, x, y, col, ax, ay)
end

-- Faint grid, scanlines and a slow sweep inside a hologram rectangle
local function HoloFX(x, y, w, h, t)
	surface.SetDrawColor(60, 255, 150, 8)
	for gx = x + 16, x + w - 1, 16 do surface.DrawRect(gx, y + 1, 1, h - 2) end
	surface.SetDrawColor(0, 0, 0, 34)
	for gy = y + (t * 30) % 4, y + h - 2, 4 do surface.DrawRect(x + 1, gy, w - 2, 1) end
	surface.SetDrawColor(90, 255, 160, 14)
	surface.DrawRect(x + 1, y + (t * 0.35 % 1) * (h - 14), w - 2, 14)
end

local function HoloLine(x, y, w, h)
	surface.SetDrawColor(H_GREEN.r, H_GREEN.g, H_GREEN.b, 90)
	surface.DrawRect(x, y, w, h)
end

local function DrawNotes()
	local now = RealTime()
	local y = ScrH() * 0.11
	for i = #RMPG.Notes, 1, -1 do
		if now - RMPG.Notes[i].t > 4.5 then table.remove(RMPG.Notes, i) end
	end
	for _, n in ipairs(RMPG.Notes) do
		local age = now - n.t
		local a = math.Clamp(age * 6, 0, 1) * math.Clamp((4.5 - age) * 2, 0, 1)
		local slide = (1 - math.Clamp(age * 5, 0, 1)) * -20
		surface.SetFont("RMPG_BodyB")
		local tw = surface.GetTextSize(n.text)
		local w, h = tw + 56, 40
		local x = ScrW() / 2 - w / 2
		local c = (n.kind == 1 or n.kind == 3) and H_RED or H_GREEN
		if n.kind == 3 then c = Color(c.r, c.g, c.b, 160 + 95 * math.abs(math.sin(now * 10))) end
		local yy = y + slide
		RMPG.HoloBox(x, yy, w, h, Color(H_BG.r, H_BG.g, H_BG.b, H_BG.a * a), Color(c.r, c.g, c.b, (c.a or 255) * a))
		surface.SetDrawColor(c.r, c.g, c.b, 255 * a)
		surface.DrawRect(x + 10, yy + 10, 4, h - 20)
		RMPG.HoloText(n.text, "RMPG_BodyB", x + 26, yy + h / 2, Color(H_TEXT.r, H_TEXT.g, H_TEXT.b, 255 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		y = y + h + 8
	end
end

---------------------------------------------------------------------------
-- Full screen flash (teleport / implosion)
---------------------------------------------------------------------------

RMPG.Flash = nil
function RMPG.ScreenFlash(col, strength, dur)
	RMPG.Flash = { col = col, s = strength or 1, d = dur or 0.6, t = RealTime() }
end

net.Receive("rmpg_tpflash", function()
	local c = net.ReadVector()
	RMPG.ScreenFlash(c, 0.9, 0.65)
	if RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.enter) end
end)

-- Prime bomb: a violet-white flash with light rays bursting from the blast (k = strength 0..1)
function RMPG.BombFlash(pos, k)
	RMPG.Flash = { col = Vector(205, 120, 255), s = k, d = 0.6 + 1.2 * k, t = RealTime(), rays = pos }
end

local function DrawRays(f, a, p)
	local sp = f.rays:ToScreen()
	local sw, sh = ScrW(), ScrH()
	local cx, cy = sp.x, sp.y
	if not sp.visible then cx, cy = sw / 2, sh * 0.45 end
	local L = math.max(sw, sh) * 1.6
	local spin = p * 0.25
	draw.NoTexture()
	for i = 0, 23 do
		local a0 = i / 24 * math.pi * 2 + spin + math.sin(i * 7.3) * 0.08
		local wid = 0.05 + 0.03 * math.sin(i * 3.1)
		local x1, y1 = cx + math.cos(a0 - wid) * L, cy + math.sin(a0 - wid) * L
		local x2, y2 = cx + math.cos(a0 + wid) * L, cy + math.sin(a0 + wid) * L
		if i % 2 == 0 then surface.SetDrawColor(255, 235, 255, 150 * a) else surface.SetDrawColor(220, 140, 255, 110 * a) end
		surface.DrawPoly({ { x = cx, y = cy }, { x = x1, y = y1 }, { x = x2, y = y2 } })
	end
	surface.SetMaterial(RMPG.Mat.glow2D)
	local g = sh * (0.9 + 1.4 * p)
	surface.SetDrawColor(255, 255, 255, 255 * a)
	surface.DrawTexturedRect(cx - g / 2, cy - g / 2, g, g)
end

local function DrawFlash()
	local f = RMPG.Flash
	if not f then return end
	local p = (RealTime() - f.t) / f.d
	if p >= 1 then RMPG.Flash = nil return end
	local a = (1 - p) ^ 2 * f.s
	local sw, sh = ScrW(), ScrH()
	surface.SetDrawColor(f.col.x, f.col.y, f.col.z, 170 * a)
	surface.DrawRect(0, 0, sw, sh)
	if f.rays then
		DrawRays(f, a, p)
		surface.SetDrawColor(255, 245, 255, 235 * a * a)
		surface.DrawRect(0, 0, sw, sh)
		return
	end
	local size = sh * (0.7 + 2.2 * p)
	RMPG.DrawSwirl2D(sw / 2 - size / 2, sh / 2 - size / 2, size, f.col, 255 * a)
	surface.SetDrawColor(255, 255, 255, 120 * a * a)
	surface.DrawRect(0, 0, sw, sh)
end

---------------------------------------------------------------------------
-- Shots: a glowing glob flies from the emitter to the surface
---------------------------------------------------------------------------

RMPG.Shots = RMPG.Shots or {}
local SHOT_TIME = 0.22

net.Receive("rmpg_fx", function()
	local wep = net.ReadEntity()
	local hit = net.ReadVector()
	local col = net.ReadVector()
	local start = (IsValid(wep) and wep.TipPosition) and wep:TipPosition() or hit
	table.insert(RMPG.Shots, { s = start, e = hit, col = col, t = CurTime() })
	local ed = EffectData()
	ed:SetOrigin(hit)
	ed:SetNormal((start - hit):GetNormalized())
	ed:SetStart(col)
	ed:SetScale(0.8)
	util.Effect("rmpg_burst", ed)
end)

local function DrawShots()
	local now = CurTime()
	for i = #RMPG.Shots, 1, -1 do
		local s = RMPG.Shots[i]
		local p = (now - s.t) / SHOT_TIME
		if p > 1.4 then
			table.remove(RMPG.Shots, i)
		else
			local c = s.col
			local head = LerpVector(math.min(p, 1), s.s, s.e)
			local tail = LerpVector(math.Clamp(p - 0.45, 0, 1), s.s, s.e)
			local fade = p > 1 and (1 - (p - 1) / 0.4) or 1
			render.SetMaterial(RMPG.Mat.beam)
			render.DrawBeam(tail, head, 7, 0, 1, Color(c.x, c.y, c.z, 220 * fade))
			render.DrawBeam(tail, head, 2.5, 0, 1, Color(255, 255, 255, 230 * fade))
			render.SetMaterial(RMPG.Mat.glow)
			render.DrawSprite(head, 26, 26, Color(c.x, c.y, c.z, 255 * fade))
			render.DrawSprite(head, 10, 10, Color(255, 255, 255, 255 * fade))
		end
	end
end

---------------------------------------------------------------------------
-- Ghost outline where the next portal will open
---------------------------------------------------------------------------

local function DrawPreview()
	if not RMPG.CL.preview:GetBool() then return end
	local ply = LocalPlayer()
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or wep:GetClass() ~= RMPG.WEAPON or wep:IsReloading() then return end
	if not wep:GetCore() and wep:GetCharges() <= 0 then return end
	local pos, ang
	local m = wep:GetDestMode()
	if m == RMPG.DEST_QUICK or m == RMPG.DEST_TRAP or m == RMPG.DEST_MAP then
		pos, ang = RMPG.SurfacePlacement(ply)
	else
		pos, ang = RMPG.ComputeEntry(ply, RMPG.CL.vertical:GetBool())
	end
	if not pos or pos:DistToSqr(ply:GetShootPos()) > 4000 * 4000 then return end
	local f, ax, ay = RMPG.PortalAxes(ang)
	local u0, v0, u1, v1 = RMPG.FrameUV(RMPG.ShapeFrame(CurTime()))
	local c = wep:FluidColor()
	local half = RMPG.Radius()
	render.SetMaterial(RMPG.Mat.outline)
	RMPG.DrawQuad(pos + f * 0.6, ax, ay, half, half, u0, v0, u1, v1, c.x, c.y, c.z, 60 + 30 * math.sin(CurTime() * 5))
end

hook.Add("PostDrawTranslucentRenderables", "rmpg_world_fx", function(depth, sky)
	if depth or sky then return end
	DrawShots()
	DrawPreview()
	RMPG.ResetTints()
end)

---------------------------------------------------------------------------
-- Screen effects near a self-destructing gun
---------------------------------------------------------------------------

hook.Add("RenderScreenspaceEffects", "rmpg_meltdown_fx", function()
	local ep = EyePos()
	for _, m in ipairs(ents.FindByClass("rmpg_meltdown")) do
		local phase = m:Phase()
		local R = m:GetRadius()
		if phase == 2 and R > 0 then
			local d = ep:Distance(m:GetVortexPos())
			local k = math.Clamp(1.5 - d / R, 0, 1)
			if k > 0 then
				local c = m:FluidCol()
				DrawMotionBlur(0.2, 0.55 * k, 0.01)
				DrawColorModify({
					["$pp_colour_addr"] = c.x / 255 * 0.06 * k,
					["$pp_colour_addg"] = c.y / 255 * 0.06 * k,
					["$pp_colour_addb"] = c.z / 255 * 0.06 * k,
					["$pp_colour_brightness"] = 0,
					["$pp_colour_contrast"] = 1 + 0.15 * k,
					["$pp_colour_colour"] = 1 - 0.3 * k,
					["$pp_colour_mulr"] = 0,
					["$pp_colour_mulg"] = 0,
					["$pp_colour_mulb"] = 0,
				})
			end
		end
	end
end)

-- Kill feed icons for what can kill, borrowed from the stock ones
killicon.AddAlias("weapon_rmpg_laser", "weapon_ar2")
killicon.AddAlias("weapon_rmpg_akira", "prop_combine_ball")
killicon.AddAlias("rmpg_clone", "weapon_pistol")
killicon.AddAlias("rmpg_portal", "prop_combine_ball")
killicon.AddAlias("rmpg_neutrino_bomb", "npc_grenade_frag")
killicon.AddAlias("rmpg_black_hole", "prop_combine_ball")
killicon.AddAlias("rmpg_brain_worm", "weapon_crowbar")
killicon.AddAlias("rmpg_worm_seg", "weapon_crowbar")
-- everything else of ours that can end up in the kill feed: without an icon the game prints a warning for it
hook.Add("InitPostEntity", "rmpg_killicons", function()
	for class in pairs(scripted_ents.GetList()) do
		if string.sub(class, 1, 5) == "rmpg_" and not killicon.Exists(class) then killicon.AddAlias(class, "prop_combine_ball") end
	end
	for _, w in ipairs(weapons.GetList()) do
		local class = w.ClassName or ""
		if string.find(class, "^weapon_rm") and not killicon.Exists(class) then killicon.AddAlias(class, "prop_combine_ball") end
	end
end)

-- Vaporised players leave no regular corpse (a dissolving copy is spawned instead);
-- players and NPCs disintegrated by the Prime bomb leave nothing at all
hook.Add("CreateClientsideRagdoll", "rmpg_vapor", function(ent, rag)
	if IsValid(ent) and CurTime() - ent:GetNW2Float("RMPG_Vapor", -100) < 1.5 then
		rag:SetNoDraw(true)
	end
end)

---------------------------------------------------------------------------
-- Gun HUD
---------------------------------------------------------------------------

local function Capsule(x, y, w, h, col)
	draw.RoundedBox(math.floor(w / 2), x, y, w, h, col)
end

function RMPG.DrawGunHUD(wep)
	if not RMPG.CL.hud:GetBool() then return end
	local sw, sh = ScrW(), ScrH()
	local w, h = 372, 136
	local x, y = sw - w - 28, sh - h - 28
	local fluid = RMPG.AccentOf(wep)
	local now = RealTime()
	local core = wep:GetCore()
	local max = math.max(RMPG.MaxCharges(), 1)
	local charges = wep:GetCharges()
	local frac = core and 1 or charges / max

	-- body of the hologram
	surface.SetMaterial(RMPG.Mat.glow2D)
	surface.SetDrawColor(60, 255, 140, 30)
	surface.DrawTexturedRect(x - 80, y - 90, 300, 300)
	surface.SetDrawColor(255, 50, 80, 22)
	surface.DrawTexturedRect(x + w - 200, y + h - 150, 280, 260)
	RMPG.HoloBox(x, y, w, h, H_BG, H_GREEN)
	HoloFX(x, y, w, h, now)
	surface.SetDrawColor(H_RED)
	surface.DrawRect(x + 16, y + 5, 40, 2)
	surface.DrawRect(x + w - 56, y + h - 7, 40, 2)

	-- fluid tube: neon outline, the fluid drains as you shoot
	local gx, gy, gw, gh = x + 18, y + 16, 30, h - 32
	RMPG.HoloBox(gx, gy, gw, gh, Color(2, 10, 8, 230), H_GREEN_MD)
	local lvl = math.Clamp(wep:DisplayLevel(), 0, 1)
	local fh = math.floor((gh - 8) * lvl)
	if fh > 1 then
		local fc = fluid
		if core then
			local p = 0.75 + 0.25 * math.sin(now * 8)
			fc = Color(math.min(255, fluid.r * p + 60), math.min(255, fluid.g * p + 60), math.min(255, fluid.b * p + 60))
		end
		local fy = gy + 4 + (gh - 8 - fh)
		surface.SetDrawColor(fc.r, fc.g, fc.b, 210)
		surface.DrawRect(gx + 4, fy, gw - 8, fh)
		surface.SetDrawColor(255, 255, 255, 120)
		surface.DrawRect(gx + 4, fy, gw - 8, 2)
		render.SetScissorRect(gx + 4, fy, gx + gw - 4, gy + gh - 4, true)
		for i = 1, 6 do
			local ph = (now * (0.4 + i * 0.07) + i * 0.3) % 1
			local bx = gx + 7 + ((i * 37) % (gw - 16))
			local by = gy + gh - 6 - ph * (gh - 8)
			surface.SetDrawColor(255, 255, 255, 140)
			surface.DrawRect(bx, by, 3, 3)
		end
		render.SetScissorRect(0, 0, 0, 0, false)
	end
	for k = 1, 4 do
		surface.SetDrawColor(H_GREEN.r, H_GREEN.g, H_GREEN.b, 70)
		surface.DrawRect(gx + gw + 3, gy + gh * k / 5, 5, 1)
	end

	-- charges
	local tx = gx + gw + 22
	RMPG.HoloText(core and RMPG.T("hud_core") or RMPG.T("hud_charges"), "RMPG_SmallB", tx, y + 14, H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local big = core and "∞" or tostring(charges)
	local bigCol = H_TEXT
	if not core and charges <= 0 then bigCol = Color(H_RED.r, H_RED.g, H_RED.b, 150 + 105 * math.abs(math.sin(now * 5))) end
	RMPG.HoloText(big, "RMPG_Big", tx, y + 26, bigCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	if not core then
		surface.SetFont("RMPG_Big")
		local bw = surface.GetTextSize(big)
		draw.SimpleText("/" .. max, "RMPG_Head", tx + bw + 4, y + 50, H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	local segs, sx, sy = 14, tx, y + 76
	local segW = (x + w - 18 - sx) / segs
	for k = 0, segs - 1 do
		local lit = (k + 0.5) / segs <= frac
		surface.SetDrawColor(lit and H_GREEN or Color(10, 40, 26, 230))
		surface.DrawRect(sx + k * segW, sy, segW - 3, 9)
	end

	-- spare flasks
	local fx = x + w - 96
	RMPG.HoloText(RMPG.T("hud_flasks"), "RMPG_SmallB", fx, y + 14, H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local fl = RMPG.CV.infinite:GetBool() and "∞" or tostring(wep:GetFlasks())
	RMPG.HoloBox(fx, y + 34, 16, 30, Color(2, 10, 8, 230), H_GREEN_MD)
	surface.SetDrawColor(fluid.r, fluid.g, fluid.b, 220)
	surface.DrawRect(fx + 4, y + 44, 8, 16)
	RMPG.HoloText("× " .. fl, "RMPG_Head", fx + 24, y + 49, H_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- target / state line
	HoloLine(tx, y + h - 40, x + w - 18 - tx, 1)
	local ly = y + h - 24
	local rf = wep:ReloadFraction()
	if rf then
		RMPG.HoloText(RMPG.T("hud_reloading"), "RMPG_SmallB", tx, ly, H_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(10, 40, 26, 230)
		surface.DrawRect(tx + 150, ly - 3, x + w - 18 - tx - 150, 6)
		surface.SetDrawColor(H_GREEN)
		surface.DrawRect(tx + 150, ly - 3, (x + w - 18 - tx - 150) * rf, 6)
	elseif not core and charges <= 0 then
		local has = RMPG.CV.infinite:GetBool() or wep:GetFlasks() > 0
		RMPG.HoloText(RMPG.T(has and "hud_empty" or "hud_noflask"), "RMPG_SmallB", tx, ly, Color(H_RED.r, H_RED.g, H_RED.b, 150 + 105 * math.abs(math.sin(now * 5))), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	else
		local code = wep:GetDestCode()
		draw.SimpleText(RMPG.T("hud_dest"), "RMPG_SmallB", tx, ly, H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("RMPG_SmallB")
		local lw = surface.GetTextSize(RMPG.T("hud_dest")) + 10
		if code == "" then code = "???" end
		draw.SimpleText(code, "RMPG_Mono", tx + lw, ly, H_RED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("RMPG_Mono")
		local cw = surface.GetTextSize(code) + 10
		local txt = RMPG.DestText(wep)
		if #txt > 24 then txt = string.sub(txt, 1, 23) .. "…" end
		RMPG.HoloText(txt, "RMPG_SmallB", tx + lw + cw, ly, H_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

---------------------------------------------------------------------------
-- Detonator HUD: linked bombs, the countdown and markers over every bomb you own
---------------------------------------------------------------------------

local BOMB_ICON = Material("entities/rmpg_prime_bomb.png", "smooth")

function RMPG.MyBombs()
	local me = LocalPlayer()
	local list = {}
	for _, b in ipairs(ents.FindByClass(RMPG.BOMB)) do
		if b.IsLinked and b:IsLinked() and b:GetLinker() == me and not b:GetExploded() then list[#list + 1] = b end
	end
	return list
end

local function BombMarker(b, now)
	local pos = b:WorldSpaceCenter()
	local sp = (pos + Vector(0, 0, 26)):ToScreen()
	if not sp.visible then return end
	local counting = b:GetBlastTime() > 0
	local col = counting and Color(H_RED.r, H_RED.g, H_RED.b, 150 + 105 * math.abs(math.sin(now * 12))) or H_GREEN
	local x, y = math.floor(sp.x), math.floor(sp.y)
	surface.SetDrawColor(col)
	surface.DrawLine(x - 9, y, x, y - 9) surface.DrawLine(x, y - 9, x + 9, y)
	surface.DrawLine(x + 9, y, x, y + 9) surface.DrawLine(x, y + 9, x - 9, y)
	surface.DrawRect(x - 2, y - 2, 4, 4)
	local d = LocalPlayer():GetPos():Distance(pos) / RMPG.UNITS_PER_METER
	local txt = counting and string.format("%.1f", math.max(b:GetBlastTime() - CurTime(), 0)) or RMPG.T("meters", math.floor(d))
	RMPG.HoloText(txt, counting and "RMPG_Mono" or "RMPG_SmallB", x, y - 14, counting and col or H_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end

function RMPG.DrawDetonatorHUD(wep)
	local now = RealTime()
	local bombs = RMPG.MyBombs()
	for _, b in ipairs(bombs) do BombMarker(b, now) end
	if not RMPG.CL.hud:GetBool() then return end

	local sw, sh = ScrW(), ScrH()
	local w, h = 340, 118
	local x, y = sw - w - 28, sh - h - 28
	surface.SetMaterial(RMPG.Mat.glow2D)
	surface.SetDrawColor(255, 50, 120, 26)
	surface.DrawTexturedRect(x - 90, y - 90, 300, 300)
	RMPG.HoloBox(x, y, w, h, H_BG, H_GREEN)
	HoloFX(x, y, w, h, now)
	surface.SetDrawColor(H_RED)
	surface.DrawRect(x + 16, y + 5, 40, 2)
	surface.DrawRect(x + w - 56, y + h - 7, 40, 2)

	-- the bomb icon
	RMPG.HoloBox(x + 14, y + 14, 70, 70, Color(2, 10, 8, 230), H_GREEN_MD)
	surface.SetMaterial(BOMB_ICON)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(x + 17, y + 17, 64, 64)

	local soonest
	for _, b in ipairs(bombs) do
		local bt = b:GetBlastTime()
		if bt > 0 and (not soonest or bt < soonest) then soonest = bt end
	end
	local tx = x + 98
	RMPG.HoloText(RMPG.T("hud_det"), "RMPG_SmallB", tx, y + 14, H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	RMPG.HoloText(tostring(#bombs), "RMPG_Big", tx, y + 26, #bombs > 0 and H_TEXT or H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetFont("RMPG_Big")
	local bw = surface.GetTextSize(tostring(#bombs))
	draw.SimpleText(RMPG.T("hud_bombs"), "RMPG_SmallB", tx + bw + 8, y + 52, H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	HoloLine(tx, y + h - 40, x + w - 18 - tx, 1)
	local ly = y + h - 24
	if soonest then
		local left = math.max(soonest - CurTime(), 0)
		local blink = Color(H_RED.r, H_RED.g, H_RED.b, 150 + 105 * math.abs(math.sin(now * 12)))
		draw.SimpleText(RMPG.T("hud_det_blast"), "RMPG_SmallB", tx, ly, blink, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("RMPG_SmallB")
		local lw = surface.GetTextSize(RMPG.T("hud_det_blast")) + 10
		draw.SimpleText(string.format("%.1f", left), "RMPG_Mono", tx + lw, ly, blink, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	elseif #bombs > 0 then
		RMPG.HoloText(RMPG.T("hud_det_ready"), "RMPG_SmallB", tx, ly, H_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	else
		RMPG.HoloText(RMPG.T("hud_det_none"), "RMPG_SmallB", tx, ly, H_MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	draw.SimpleText(RMPG.T("hud_det_hint"), "RMPG_Small", x + w - 16, y + 16, H_MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

function RMPG.DrawCrosshair(wep, x, y)
	local ac = RMPG.AccentOf(wep)
	local t = RealTime()
	local fire = math.Clamp(1 - (CurTime() - wep:GetFireTime()) / 0.3, 0, 1)
	local r = 11 + 6 * fire
	surface.SetDrawColor(ac.r, ac.g, ac.b, 230)
	for i = 0, 2 do
		local a0 = t * 1.6 + i * (math.pi * 2 / 3)
		for j = 0, 5 do
			local a1, a2 = a0 + j * 0.13, a0 + (j + 1) * 0.13
			surface.DrawLine(x + math.cos(a1) * r, y + math.sin(a1) * r, x + math.cos(a2) * r, y + math.sin(a2) * r)
		end
	end
	draw.RoundedBox(2, x - 2, y - 2, 4, 4, Color(255, 255, 255, 235))
	return true
end

hook.Add("HUDPaint", "rmpg_hud", function()
	DrawFlash()
	DrawNotes()
end)
