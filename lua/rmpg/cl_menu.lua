-- Client: the portal gun menu - a green/red hologram projected by the gun (opened with RMB)
RMPG = RMPG or {}
RMPG.UI = RMPG.UI or {}
local UI = RMPG.UI

local GREEN    = Color(90, 255, 150)
local GREEN_MD = Color(40, 170, 100)
local GREEN_DK = Color(20, 80, 50)
local RED      = Color(255, 64, 84)
local RED_DK   = Color(120, 18, 32, 220)
local BG       = Color(3, 12, 10, 232)
local OUTLINE  = Color(4, 34, 22, 230)
local SCREEN2  = Color(8, 32, 24, 190)
local SCREEN3  = Color(3, 15, 12, 215)
local TILE     = Color(12, 46, 34, 200)
local TILE_HOV = Color(24, 84, 58, 225)
local TILE_HI  = GREEN_MD
local TILE_LO  = GREEN_DK
local TEXT     = Color(222, 255, 234)
local MUTED    = Color(122, 204, 162)
local HAZARD   = RED
local BEZEL_SH = Color(150, 220, 180)

surface.CreateFont("RMPG_Tile", { font = "Trebuchet MS", size = 21, weight = 900, extended = true, antialias = true })
surface.CreateFont("RMPG_TileBig", { font = "Trebuchet MS", size = 26, weight = 900, extended = true, antialias = true })
surface.CreateFont("RMPG_ScreenTitle", { font = "Trebuchet MS", size = 28, weight = 900, extended = true, antialias = true })

local NOPAINT = function() end
local ICONS = {}
local function Icon(path)
	ICONS[path] = ICONS[path] or Material(path)
	return ICONS[path]
end

local function Accent()
	local c = RMPG.LocalColor()
	return Color(c.x, c.y, c.z)
end

local function Mix(a, b, k)
	return Color(Lerp(k, a.r, b.r), Lerp(k, a.g, b.g), Lerp(k, a.b, b.b), Lerp(k, a.a or 255, b.a or 255))
end

local function Contrast(c)
	return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) > 150 and Color(20, 8, 10) or Color(255, 255, 255)
end

local function Snd(name)
	local snd = ({ ui_click = "uiClick", ui_hover = "uiHover", ui_open = "uiOpen", ui_close = "uiClose" })[name]
	if snd and RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND[snd]) end
end

-- Hologram box: translucent fill, thin neon border, faint inner line and bright corner brackets
local function Bevel(x, y, w, h, fill, edge, _, b)
	surface.SetDrawColor(fill)
	surface.DrawRect(x, y, w, h)
	edge = edge or GREEN_MD
	surface.SetDrawColor(edge.r, edge.g, edge.b, 170)
	surface.DrawOutlinedRect(x, y, w, h, 1)
	if w > 12 and h > 12 then
		surface.SetDrawColor(edge.r, edge.g, edge.b, 36)
		surface.DrawOutlinedRect(x + 3, y + 3, w - 6, h - 6, 1)
	end
	local L = math.floor(math.min(12, w / 4, h / 4))
	surface.SetDrawColor(edge.r, edge.g, edge.b, 255)
	surface.DrawRect(x, y, L, 2) surface.DrawRect(x, y, 2, L)
	surface.DrawRect(x + w - L, y, L, 2) surface.DrawRect(x + w - 2, y, 2, L)
	surface.DrawRect(x, y + h - 2, L, 2) surface.DrawRect(x, y + h - L, 2, L)
	surface.DrawRect(x + w - L, y + h - 2, L, 2) surface.DrawRect(x + w - 2, y + h - L, 2, L)
end

-- Text with a slight red / green split, like a hologram
local function Shadowed(text, font, x, y, col, ax, ay)
	local a = (col.a or 255) / 255
	draw.SimpleText(text, font, x - 1, y, Color(255, 50, 80, 120 * a), ax, ay)
	draw.SimpleText(text, font, x + 1, y, Color(60, 255, 150, 120 * a), ax, ay)
	draw.SimpleText(text, font, x, y, col, ax, ay)
end

local wrapCache = {}
local function Wrap(text, font, width)
	local key = font .. "|" .. width .. "|" .. text
	if wrapCache[key] then return wrapCache[key] end
	surface.SetFont(font)
	local lines = {}
	for para in string.gmatch(text .. "\n", "(.-)\n") do
		local cur = ""
		for word in string.gmatch(para, "%S+") do
			local test = cur == "" and word or (cur .. " " .. word)
			if cur ~= "" and surface.GetTextSize(test) > width then
				lines[#lines + 1] = cur
				cur = word
			else
				cur = test
			end
		end
		lines[#lines + 1] = cur
	end
	wrapCache[key] = lines
	return lines
end

local function DrawWrapped(text, font, x, y, width, col, lineH)
	local lines = Wrap(text, font, width)
	for i, l in ipairs(lines) do
		draw.SimpleText(l, font, x, y + (i - 1) * lineH, col)
	end
	return #lines * lineH
end

local function LocalGun()
	local ply = LocalPlayer()
	if not IsValid(ply) then return nil end
	local w = ply:GetWeapon(RMPG.WEAPON)
	return IsValid(w) and w or nil
end

local function DrawX(cx, cy, r, col)
	surface.SetDrawColor(col)
	for o = -2, 2 do
		surface.DrawLine(cx - r + o, cy - r, cx + r + o, cy + r)
		surface.DrawLine(cx + r + o, cy - r, cx - r + o, cy + r)
	end
end

-- Screen rectangle of a panel clipped by all of its parents (scroll areas)
local function VisibleRect(pnl)
	local x0, y0 = pnl:LocalToScreen(0, 0)
	local x1, y1 = x0 + pnl:GetWide(), y0 + pnl:GetTall()
	local p = pnl:GetParent()
	while IsValid(p) do
		local px, py = p:LocalToScreen(0, 0)
		x0, y0 = math.max(x0, px), math.max(y0, py)
		x1, y1 = math.min(x1, px + p:GetWide()), math.min(y1, py + p:GetTall())
		p = p:GetParent()
	end
	return x0, y0, x1, y1
end

-- Moving yellow/black warning stripes filling a panel
local function Hazard(pnl, w, h, t)
	surface.SetDrawColor(30, 4, 10, 200)
	surface.DrawRect(0, 0, w, h)
	local x0, y0, x1, y1 = VisibleRect(pnl)
	render.SetScissorRect(x0, y0, x1, y1, true)
	draw.NoTexture()
	surface.SetDrawColor(HAZARD.r, HAZARD.g, HAZARD.b, 90)
	local off = (t * 30) % 28
	for sx = -h - 28, w + 28, 28 do
		local x = sx + off
		surface.DrawPoly({
			{ x = x + h, y = 0 },
			{ x = x + 14 + h, y = 0 },
			{ x = x + 14, y = h },
			{ x = x, y = h },
		})
	end
	render.SetScissorRect(0, 0, 0, 0, false)
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local function TileColors(kind, hov, down)
	if kind == "accent" then
		local f = Mix(Color(18, 92, 54, 215), Color(32, 146, 84, 235), hov)
		if down then f = Mix(f, Color(0, 0, 0, 235), 0.25) end
		return f, GREEN, nil, TEXT
	elseif kind == "dark" then
		local f = Mix(Color(4, 16, 12, 210), Color(12, 42, 30, 225), hov)
		return f, Mix(GREEN_DK, GREEN_MD, hov), nil, TEXT
	elseif kind == "danger" then
		local f = Mix(Color(54, 6, 14, 215), Color(96, 12, 26, 235), hov)
		return f, RED, nil, Color(255, 205, 210)
	end
	local f = Mix(TILE, TILE_HOV, hov)
	if down then f = Mix(f, Color(0, 0, 0, 235), 0.25) end
	return f, Mix(GREEN_MD, GREEN, hov), nil, TEXT
end

-- kind: "tile" (default), "accent", "dark" or "danger"; text may be a function
function UI.Button(parent, text, kind, onClick, icon)
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.Label = text
	b.Kind = kind or "tile"
	b.Icon = icon and Icon(icon)
	b.Hov = 0
	b.Paint = function(s, w, h)
		s.Hov = Lerp(FrameTime() * 14, s.Hov, (s:IsHovered() and s:IsEnabled()) and 1 or 0)
		local fill, hi, lo, tc = TileColors(s.Kind, s.Hov, s:IsDown())
		if not s:IsEnabled() then fill, hi, lo, tc = SCREEN2, nil, nil, MUTED end
		Bevel(0, 0, w, h, fill, hi, lo)
		local label = isfunction(s.Label) and s.Label() or s.Label
		local dy = s:IsDown() and 1 or 0
		if s.Icon then
			local has = label and label ~= ""
			local ix = has and 12 or (w / 2 - 8)
			surface.SetMaterial(s.Icon)
			surface.SetDrawColor(255, 255, 255, s:IsEnabled() and 255 or 120)
			surface.DrawTexturedRect(ix, h / 2 - 8 + dy, 16, 16)
			if has then draw.SimpleText(label, "RMPG_BodyB", 36, h / 2 + dy, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
		elseif label then
			draw.SimpleText(label, "RMPG_BodyB", w / 2, h / 2 + dy, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	b.OnCursorEntered = function(s) if s:IsEnabled() then Snd("ui_hover") end end
	b.DoClick = function(s)
		Snd("ui_click")
		if onClick then onClick(s) end
	end
	return b
end

-- Big home-screen tile with an icon (or the animated portal) and a caption
function UI.Tile(parent, title, icon, onClick, opts)
	opts = opts or {}
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.Hov = 0
	local mat = icon and Icon(icon)
	b.Paint = function(s, w, h)
		s.Hov = Lerp(FrameTime() * 14, s.Hov, s:IsHovered() and 1 or 0)
		local fill, hi, lo = TileColors("tile", s.Hov, s:IsDown())
		Bevel(0, 0, w, h, fill, hi, lo, 4)
		local dy = s:IsDown() and 2 or 0
		if opts.swirl then
			local size = math.min(w, h) - 70
			RMPG.DrawSwirl2D(w / 2 - size / 2, (h - 34) / 2 - size / 2 + dy, size, Accent(), 255)
			Shadowed(title, "RMPG_TileBig", w / 2, h - 26 + dy, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			if mat then
				surface.SetMaterial(mat)
				surface.SetDrawColor(0, 0, 0, 120)
				surface.DrawTexturedRect(20, h / 2 - 14 + dy, 32, 32)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(18, h / 2 - 16 + dy, 32, 32)
			end
			Shadowed(title, "RMPG_Tile", 64, h / 2 + dy, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			if opts.sub then
				draw.SimpleText(opts.sub(), "RMPG_Small", 64, h / 2 + 18 + dy, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
	end
	b.OnCursorEntered = function() Snd("ui_hover") end
	b.DoClick = function()
		Snd("ui_click")
		onClick()
	end
	return b
end

function UI.Header(parent, text)
	local p = vgui.Create("DPanel", parent)
	p:SetTall(32)
	p.Paint = function(s, w, h)
		Shadowed(text, "RMPG_Sub", 0, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("RMPG_Sub")
		local tw = surface.GetTextSize(text)
		surface.SetDrawColor(OUTLINE)
		surface.DrawRect(tw + 12, h / 2 - 1, w - tw - 12, 3)
		surface.SetDrawColor(TILE_HI)
		surface.DrawRect(tw + 12, h / 2 - 1, w - tw - 12, 1)
	end
	return p
end

function UI.Toggle(parent, label, desc, getter, setter)
	local p = vgui.Create("DButton", parent)
	p:SetText("")
	p:SetTall(desc and 68 or 46)
	p.Anim = getter() and 1 or 0
	p.Hov = 0
	p.Paint = function(s, w, h)
		local ac = GREEN
		s.Anim = Lerp(FrameTime() * 16, s.Anim, getter() and 1 or 0)
		s.Hov = Lerp(FrameTime() * 12, s.Hov, s:IsHovered() and 1 or 0)
		Bevel(0, 0, w, h, Mix(SCREEN2, TILE, 0.3 * s.Hov), nil, nil)
		if desc then
			Shadowed(label, "RMPG_BodyB", 14, 12, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			DrawWrapped(desc, "RMPG_Small", 14, 34, w - 110, MUTED, 15)
		else
			Shadowed(label, "RMPG_BodyB", 14, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		local sw, sh = 54, 26
		local sx, sy = w - sw - 16, h / 2 - sh / 2
		Bevel(sx, sy, sw, sh, Mix(SCREEN3, ac, s.Anim), nil, nil, 3)
		local kx = sx + 3 + (sw - sh) * s.Anim
		surface.SetDrawColor(OUTLINE)
		surface.DrawRect(kx, sy + 3, sh - 6, sh - 6)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawRect(kx + 2, sy + 5, sh - 10, sh - 10)
	end
	p.OnCursorEntered = function() Snd("ui_hover") end
	p.DoClick = function()
		Snd("ui_click")
		setter(not getter())
	end
	return p
end

function UI.Segmented(parent, label, options, getter, setter)
	local p = vgui.Create("DPanel", parent)
	p:SetTall(54)
	p.Paint = function(s, w, h)
		Bevel(0, 0, w, h, SCREEN2)
		Shadowed(label, "RMPG_BodyB", 14, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local holder = vgui.Create("DPanel", p)
	holder:Dock(RIGHT)
	holder:DockMargin(0, 9, 9, 9)
	holder:SetWide(#options * 104)
	holder.Paint = NOPAINT
	for _, o in ipairs(options) do
		local b = vgui.Create("DButton", holder)
		b:SetText("")
		b:Dock(LEFT)
		b:DockMargin(0, 0, 4, 0)
		b:SetWide(100)
		b.Paint = function(s, w, h)
			local sel = getter() == o[1]
			local fill, hi, lo, tc = TileColors(sel and "accent" or "dark", s:IsHovered() and 1 or 0, s:IsDown())
			Bevel(0, 0, w, h, fill, hi, lo)
			draw.SimpleText(o[2], "RMPG_SmallB", w / 2, h / 2, tc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			Snd("ui_click")
			setter(o[1])
		end
	end
	return p
end

-- onRelease: called once when the knob is let go (used for server settings)
function UI.Slider(parent, label, min, max, decimals, getter, setter, onRelease)
	local p = vgui.Create("DPanel", parent)
	p:SetTall(58)
	p:SetCursor("hand")
	local function Value(s) return s.Drag and s.Cur or getter() end
	p.Paint = function(s, w, h)
		local ac = GREEN
		Bevel(0, 0, w, h, SCREEN2)
		local v = Value(s)
		Shadowed(label, "RMPG_Body", 14, 8, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		Shadowed(string.format("%." .. decimals .. "f", v), "RMPG_BodyB", w - 14, 8, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		local tx, ty, tw = 16, 36, w - 32
		local f = math.Clamp((v - min) / (max - min), 0, 1)
		Bevel(tx, ty, tw, 12, SCREEN3, nil, nil, 2)
		surface.SetDrawColor(ac)
		surface.DrawRect(tx + 2, ty + 2, (tw - 4) * f, 8)
		Bevel(tx + tw * f - 8, ty - 5, 16, 22, Color(255, 255, 255), nil, BEZEL_SH, 2)
	end
	local function Update(s)
		local mx = s:CursorPos()
		local f = math.Clamp((mx - 16) / math.max(s:GetWide() - 32, 1), 0, 1)
		local v = math.Round(min + (max - min) * f, decimals)
		if v ~= s.Cur then
			s.Cur = v
			if setter then setter(v) end
		end
	end
	p.OnMousePressed = function(s, code)
		if code ~= MOUSE_LEFT then return end
		s.Drag = true
		s.Cur = getter()
		s:MouseCapture(true)
		Update(s)
	end
	p.OnMouseReleased = function(s)
		if not s.Drag then return end
		s.Drag = false
		s:MouseCapture(false)
		if onRelease then onRelease(s.Cur) end
	end
	p.Think = function(s)
		if not s.Drag then return end
		if not input.IsMouseDown(MOUSE_LEFT) then
			s:OnMouseReleased(MOUSE_LEFT)
			return
		end
		Update(s)
	end
	return p
end

function UI.Entry(parent, placeholder)
	local e = vgui.Create("DTextEntry", parent)
	e:SetFont("RMPG_Body")
	e:SetDrawLanguageID(false)
	e.Paint = function(s, w, h)
		local focus = s:HasFocus()
		Bevel(0, 0, w, h, focus and SCREEN3 or Mix(SCREEN3, SCREEN2, 0.4))
		if s:GetValue() == "" and not focus then
			draw.SimpleText(placeholder, "RMPG_Body", 4, h / 2, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		s:DrawTextEntryText(TEXT, GREEN, TEXT)
	end
	return e
end

function UI.Scroll(parent)
	local sp = vgui.Create("DScrollPanel", parent)
	local bar = sp:GetVBar()
	bar:SetWide(10)
	bar:SetHideButtons(true)
	bar.Paint = function(s, w, h) surface.SetDrawColor(SCREEN3) surface.DrawRect(2, 0, w - 4, h) end
	bar.btnGrip.Paint = function(s, w, h) Bevel(0, 0, w, h, TILE, TILE_HI, TILE_LO, 2) end
	return sp
end

-- Selectable card with icon, title and description
function UI.Card(parent, title, desc, icon, isSelected, onClick, opts)
	opts = opts or {}
	local c = vgui.Create("DButton", parent)
	c:SetText("")
	c.Hov = 0
	local mat = icon and Icon(icon)
	c.Paint = function(s, w, h)
		local sel = isSelected()
		s.Hov = Lerp(FrameTime() * 12, s.Hov, s:IsHovered() and 1 or 0)
		local fill, hi, lo = TileColors("tile", s.Hov, s:IsDown())
		if sel then fill = Mix(fill, Color(255, 255, 255), 0.12) end
		Bevel(0, 0, w, h, fill, hi, lo, 3)
		if sel then
			surface.SetDrawColor(RED)
			surface.DrawOutlinedRect(5, 5, w - 10, h - 10, 2)
		end
		Bevel(14, 14, 40, 40, sel and RED_DK or SCREEN2, sel and RED or nil, nil, 2)
		if mat then
			surface.SetMaterial(mat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(26, 26, 16, 16)
		end
		Shadowed(isfunction(title) and title() or title, "RMPG_Tile", 66, 14, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		DrawWrapped(isfunction(desc) and desc() or desc, "RMPG_Small", 66, 42, w - 84, MUTED, 16)
		if opts.locked and opts.locked() then
			surface.SetMaterial(Icon("icon16/lock.png"))
			surface.SetDrawColor(255, 255, 255, 220)
			surface.DrawTexturedRect(w - 28, h - 28, 16, 16)
		end
	end
	c.OnCursorEntered = function() Snd("ui_hover") end
	c.DoClick = function()
		Snd("ui_click")
		onClick()
	end
	return c
end

-- Rotating 3D gun inside a panel. opts = { variant = fn, scale, label }
function UI.ModelPreview(parent, opts)
	opts = opts or {}
	local pv = vgui.Create("DPanel", parent)
	pv.Paint = function(s, w, h)
		local ac = Accent()
		Bevel(0, 0, w, h, SCREEN3)
		surface.SetMaterial(RMPG.Mat.glow2D)
		surface.SetDrawColor(ac.r, ac.g, ac.b, 60)
		surface.DrawTexturedRect(-w * 0.25, -h * 0.25, w * 1.5, h * 1.5)
		local x, y = s:LocalToScreen(0, 0)
		local wep = LocalGun()
		local t = RealTime()
		local variant = opts.variant and opts.variant() or (wep and wep:GetVariant()) or RMPG.CL.model:GetInt()
		local ang = Angle(-8, (t * 30) % 360 + 200, 0)
		local st = {
			variant = variant,
			color = RMPG.LocalColor(),
			level = wep and wep:DisplayLevel() or (0.6 + 0.3 * math.sin(t)),
			core = wep and wep:GetCore() or false,
			fire = 0, time = CurTime(), outline = RMPG.CL.outline:GetBool(), light = 1, glow = true, detail = 1,
			display = wep and wep:DisplayContent() or { big = "C-137", small = "30", bar = 1 },
			dial = wep and wep.RMPG_Dial or 0,
			body = RMPG.LocalBody(),
		}
		local cx0, cy0, cx1, cy1 = VisibleRect(s)
		if cx1 <= cx0 or cy1 <= cy0 then return end
		render.SetScissorRect(cx0 + 3, cy0 + 3, cx1 - 3, cy1 - 3, true)
		cam.Start3D(Vector(40, 0, 8), Angle(11, 180, 0), 40, x, y, w, h, 1, 500)
			RMPG.Model.DrawGun(RMPG.Model.CenteredFrame(vector_origin, ang, opts.scale or 1.05, variant), st)
			RMPG.ResetTints()
		cam.End3D()
		render.SetScissorRect(0, 0, 0, 0, false)
		if opts.label then Shadowed(opts.label(), "RMPG_SmallB", 12, 10, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
	end
	return pv
end

local function Dock(panel, gap)
	panel:Dock(TOP)
	panel:DockMargin(0, 0, 10, gap or 8)
	return panel
end

-- Lays out child panels in a grid when the parent is sized
local function Grid(parent, cols, rowH, gap, children)
	parent.PerformLayout = function(s, w)
		local cw = (w - gap * (cols - 1)) / cols
		for i, c in ipairs(children) do
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
			c:SetPos(col * (cw + gap), row * (rowH + gap))
			c:SetSize(cw, rowH)
		end
	end
	parent:SetTall(math.ceil(#children / cols) * (rowH + gap) - gap)
end

---------------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------------

local SCREENS = {}

SCREENS.home = function(p, f)
	local left = UI.Tile(p, RMPG.T("tab_locations"), nil, function() f.Go("locations") end, { swirl = true })
	local right = vgui.Create("DPanel", p)
	right.Paint = NOPAINT
	local bottom = vgui.Create("DPanel", p)
	bottom.Paint = function(s, w, h)
		local wep = LocalGun()
		local ac = Accent()
		Bevel(0, 0, w, h, SCREEN3)
		Shadowed(RMPG.T("home_target"), "RMPG_SmallB", 16, h / 2, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local code = wep and wep:GetDestCode() or "---"
		if code == "" then code = "???" end
		draw.SimpleText(code, "RMPG_Mono", 80, h / 2, Color(255, 60, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetFont("RMPG_Mono")
		local cw = surface.GetTextSize(code)
		Shadowed(RMPG.DestText(wep), "RMPG_BodyB", 96 + cw, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		local vert = RMPG.CL.vertical:GetBool()
		draw.SimpleText(RMPG.T("act_vertical") .. ": " .. (vert and "ON" or "OFF"), "RMPG_SmallB", w - 16, h / 2, vert and ac or MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	local tiles = {
		UI.Tile(right, RMPG.T("tab_dest"), "icon16/world.png", function() f.Go("dest") end, { sub = function() local w = LocalGun() return w and RMPG.DestText(w) or "" end }),
		UI.Tile(right, RMPG.T("tab_players"), "icon16/group.png", function() f.Go("players") end),
		UI.Tile(right, RMPG.T("tab_gun"), "icon16/color_wheel.png", function() f.Go("gun") end),
		UI.Tile(right, RMPG.T("tab_radial"), "icon16/chart_pie.png", function() f.Go("radial") end),
		UI.Tile(right, RMPG.T("tab_binds"), "icon16/keyboard.png", function() f.Go("binds") end),
		UI.Tile(right, RMPG.T("tab_settings"), "icon16/cog.png", function() f.Go("settings") end),
	}
	p.PerformLayout = function(s, w, h)
		local bh = 52
		local lw = math.floor(w * 0.36)
		left:SetPos(0, 0)
		left:SetSize(lw, h - bh - 12)
		right:SetPos(lw + 12, 0)
		right:SetSize(w - lw - 12, h - bh - 12)
		bottom:SetPos(0, h - bh)
		bottom:SetSize(w, bh)
		local rw, rh = right:GetWide(), right:GetTall()
		local rows = math.ceil(#tiles / 2)
		local cw, chh = (rw - 12) / 2, (rh - 12 * (rows - 1)) / rows
		for i, tl in ipairs(tiles) do
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			tl:SetPos(col * (cw + 12), row * (chh + 12))
			tl:SetSize(cw, chh)
		end
	end
end

-- Coordinates: where the exit opens (its middle) and which way it faces - turned round and tilted up or down. Your own
-- spot or the spot you aim at can be taken with a button; the last coordinates are remembered.
local function CoordsLoad()
	local x, y, z, pi, ya = string.match(cookie.GetString("rmpg_coords", ""), "^(%S+) (%S+) (%S+) (%S+) (%S+)$")
	if not x then return nil end
	return { pos = Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0), pitch = tonumber(pi) or 0, yaw = tonumber(ya) or 0 }
end
RMPG.CoordsLoad = CoordsLoad

local function CoordsSave(c)
	cookie.Set("rmpg_coords", string.format("%.1f %.1f %.1f %.1f %.1f", c.pos.x, c.pos.y, c.pos.z, c.pitch, c.yaw))
end

SCREENS.coords = function(p, f)
	local me = LocalPlayer()
	local c = CoordsLoad() or { pos = me:GetPos() + Vector(0, 0, 40), pitch = 0, yaw = math.Round(me:EyeAngles().y) }
	local sc = UI.Scroll(p)
	sc:Dock(FILL)
	local hint = Dock(vgui.Create("DPanel", sc), 8)
	hint:SetTall(58)
	hint.Paint = function(s, w, h)
		DrawWrapped(RMPG.T("coords_hint"), "RMPG_Small", 2, 2, w - 4, MUTED, 16)
		local pos = LocalPlayer():GetPos()
		draw.SimpleText(RMPG.T("coords_now", math.Round(pos.x), math.Round(pos.y), math.Round(pos.z), math.Round(LocalPlayer():EyeAngles().y % 360)),
			"RMPG_SmallB", 2, h - 16, TEXT)
	end

	Dock(UI.Header(sc, RMPG.T("coords_pos")))
	local row = Dock(vgui.Create("DPanel", sc), 10)
	row:SetTall(44)
	row.Paint = NOPAINT
	local AXES = { "x", "y", "z" }
	local entries = {}
	for _, axis in ipairs(AXES) do
		local holder = vgui.Create("DPanel", row)
		holder.Paint = function(s, w, h)
			Bevel(0, 0, 30, h, SCREEN2)
			Shadowed(string.upper(axis), "RMPG_BodyB", 15, h / 2, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		local e = UI.Entry(holder, "0")
		e:Dock(FILL)
		e:DockMargin(34, 0, 0, 0)
		e:SetNumeric(true)
		e:SetUpdateOnType(true)
		e:SetValue(string.format("%.1f", c.pos[axis]))
		e.OnValueChange = function(s, v)
			local n = tonumber(v)
			if n then c.pos[axis] = math.Clamp(n, -32768, 32768) end
		end
		entries[axis] = e
	end
	row.PerformLayout = function(s, w, h)
		local cw = (w - 20) / 3
		for i, axis in ipairs(AXES) do
			local holder = entries[axis]:GetParent()
			holder:SetPos((i - 1) * (cw + 10), 0)
			holder:SetSize(cw, h)
		end
	end
	local function Fill()
		for _, axis in ipairs(AXES) do entries[axis]:SetValue(string.format("%.1f", c.pos[axis])) end
	end

	Dock(UI.Header(sc, RMPG.T("coords_turn")))
	Dock(UI.Slider(sc, RMPG.T("coords_yaw"), 0, 359, 0, function() return math.Round(c.yaw % 360) end, function(v) c.yaw = v end))
	Dock(UI.Slider(sc, RMPG.T("coords_tilt"), -90, 90, 0, function() return math.Round(-c.pitch) end, function(v) c.pitch = -v end))
	local tiltHint = Dock(vgui.Create("DPanel", sc), 10)
	tiltHint:SetTall(20)
	tiltHint.Paint = function(s, w, h) draw.SimpleText(RMPG.T("coords_tilt_hint"), "RMPG_Small", 2, h / 2, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end

	local btns = Dock(vgui.Create("DPanel", sc), 10)
	btns:SetTall(44)
	btns.Paint = NOPAINT
	local here = UI.Button(btns, RMPG.T("coords_here"), "tile", function()
		local pl = LocalPlayer()
		c.pos = pl:GetPos() + Vector(0, 0, 40)
		c.yaw = math.Round(pl:EyeAngles().y % 360)
		c.pitch = 0
		Fill()
	end, "icon16/user.png")
	local aim = UI.Button(btns, RMPG.T("coords_aim"), "tile", function()
		local tr = LocalPlayer():GetEyeTrace()
		if not tr.Hit or tr.HitSky then return end
		-- flat on what you aim at, facing out of it
		local a = tr.HitNormal:Angle()
		c.pos = tr.HitPos + tr.HitNormal * 2
		c.yaw = math.Round(a.y % 360)
		c.pitch = math.Round(math.NormalizeAngle(a.p))
		Fill()
	end, "icon16/zoom.png")
	local go = UI.Button(btns, RMPG.T("coords_go"), "accent", function()
		CoordsSave(c)
		RMPG.SendDest(RMPG.DEST_COORDS, { pos = Vector(c.pos), pitch = c.pitch, yaw = c.yaw })
	end, "icon16/map_go.png")
	btns.PerformLayout = function(s, w, h)
		local bw = (w - 20) / 3
		here:SetPos(0, 0) here:SetSize(bw, h)
		aim:SetPos(bw + 10, 0) aim:SetSize(bw, h)
		go:SetPos((bw + 10) * 2, 0) go:SetSize(bw, h)
	end
end

-- The text cut to fit a width, with an ellipsis
local function FitText(text, font, width)
	surface.SetFont(font)
	if surface.GetTextSize(text) <= width then return text end
	while #text > 1 and surface.GetTextSize(text .. "...") > width do text = string.sub(text, 1, -2) end
	return text .. "..."
end

-- Portals to another map: the server's maps with their pictures, a search and shelves by kind
SCREENS.maps = function(p, f)
	RMPG.RequestMaps()
	local cat, cards, catBtns = "all", {}, {}
	local top = vgui.Create("DPanel", p)
	top:Dock(TOP)
	top:SetTall(42)
	top.Paint = NOPAINT
	local search = UI.Entry(top, RMPG.T("map_search"))
	search:Dock(FILL)
	search:SetUpdateOnType(true)
	local cats = vgui.Create("DPanel", p)
	cats:Dock(TOP)
	cats:SetTall(32)
	cats:DockMargin(0, 8, 0, 0)
	cats.Paint = NOPAINT
	local info = vgui.Create("DPanel", p)
	info:Dock(TOP)
	info:SetTall(38)
	info:DockMargin(0, 6, 0, 6)
	info.Paint = function(s, w, h)
		local who = RMPG.T(RMPG.CV.mapEveryone:GetBool() and "map_who_all" or "map_who_super")
		local line = RMPG.T("map_hint", RMPG.CV.mapWait:GetInt()) .. " " .. who
		if not RMPG.Maps.allowed and #RMPG.Maps.list > 0 then line = RMPG.T("n_map_denied") end
		DrawWrapped(line, "RMPG_Small", 2, 2, w - 4, RMPG.Maps.allowed and MUTED or RED, 16)
	end
	local sc = UI.Scroll(p)
	sc:Dock(FILL)
	local grid = vgui.Create("DPanel", sc)
	grid:Dock(TOP)
	grid.Paint = function(s, w, h)
		if #cards == 0 then
			local key = (#RMPG.Maps.list == 0) and "map_loading" or "map_none"
			Shadowed(RMPG.T(key), "RMPG_Body", w / 2, 40, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local function Chosen(name)
		local w = LocalGun()
		return w ~= nil and w:GetDestMode() == RMPG.DEST_MAP and w:GetDestLabel() == name
	end

	local function Card(name)
		local b = vgui.Create("DButton", grid)
		b:SetText("")
		b.Hov = 0
		b.Paint = function(s, w, h)
			s.Hov = Lerp(FrameTime() * 12, s.Hov, s:IsHovered() and 1 or 0)
			local sel = Chosen(name)
			local fill, hi, lo = TileColors("tile", s.Hov, s:IsDown())
			Bevel(0, 0, w, h, sel and Mix(fill, Color(255, 255, 255), 0.12) or fill, hi, lo)
			local iw = w - 16
			local th = RMPG.MapThumb(name)
			if th then
				surface.SetMaterial(th)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(8, 8, iw, iw)
			else
				Bevel(8, 8, iw, iw, SCREEN3)
				RMPG.DrawSwirl2D(8 + iw * 0.18, 8 + iw * 0.18, iw * 0.64, Accent(), 150)
			end
			if name == RMPG.Maps.current then
				Bevel(12, 12, 96, 22, Color(10, 40, 24, 230), GREEN)
				draw.SimpleText(RMPG.T("map_here"), "RMPG_SmallB", 60, 23, GREEN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			if sel then
				surface.SetDrawColor(RED)
				surface.DrawOutlinedRect(4, 4, w - 8, h - 8, 2)
			end
			Shadowed(FitText(name, "RMPG_SmallB", w - 14), "RMPG_SmallB", w / 2, h - 15, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		b:SetTooltip(name)
		b.OnCursorEntered = function() Snd("ui_hover") end
		b.DoClick = function()
			Snd("ui_click")
			if not RMPG.Maps.allowed then
				RMPG.AddNote(RMPG.T("n_map_denied"), 1)
				return
			end
			RMPG.SelectedMap = name
			RMPG.SendDest(RMPG.DEST_MAP, name)
		end
		return b
	end

	local function Rebuild()
		grid:Clear()
		cards = {}
		local q = string.lower(search:GetValue() or "")
		for _, name in ipairs(RMPG.Maps.list) do
			if (cat == "all" or RMPG.MapCategory(name) == cat) and (q == "" or string.find(string.lower(name), q, 1, true)) then
				cards[#cards + 1] = Card(name)
			end
		end
		grid:InvalidateLayout(true)
	end

	local function Shelves()
		cats:Clear()
		catBtns = {}
		local have = { all = #RMPG.Maps.list }
		for _, name in ipairs(RMPG.Maps.list) do
			local k = RMPG.MapCategory(name)
			have[k] = (have[k] or 0) + 1
		end
		local order = { "all" }
		for _, c in ipairs(RMPG.MAP_CATS) do order[#order + 1] = c[1] end
		order[#order + 1] = "map_cat_other"
		for _, key in ipairs(order) do
			if (have[key] or 0) > 0 then
				local label = (key == "all" and RMPG.T("map_cat_all") or RMPG.T(key)) .. " " .. have[key]
				local b = UI.Button(cats, label, cat == key and "accent" or "dark", function(btn)
					cat = key
					for _, o in ipairs(catBtns) do o.Kind = o.Key == key and "accent" or "dark" end
					Rebuild()
				end)
				b.Key = key
				surface.SetFont("RMPG_BodyB")
				b:SetWide(surface.GetTextSize(label) + 28)
				b:Dock(LEFT)
				b:DockMargin(0, 0, 6, 0)
				catBtns[#catBtns + 1] = b
			end
		end
	end

	grid.PerformLayout = function(s, w)
		local gap = 10
		local cols = math.max(1, math.floor((w + gap) / (150 + gap)))
		local cw = (w - gap * (cols - 1)) / cols
		local ch = cw + 24
		for i, c in ipairs(cards) do
			local col, r = (i - 1) % cols, math.floor((i - 1) / cols)
			c:SetPos(col * (cw + gap), r * (ch + gap))
			c:SetSize(cw, ch)
		end
		local tall = math.max(80, math.ceil(#cards / cols) * (ch + gap))
		if s:GetTall() ~= tall then s:SetTall(tall) end
	end

	search.OnValueChange = function() Rebuild() end
	p.Think = function()
		if p.Version ~= RMPG.Maps.version then
			p.Version = RMPG.Maps.version
			Shelves()
			Rebuild()
		end
	end
end

SCREENS.dest = function(p, f)
	local sc = UI.Scroll(p)
	sc:Dock(FILL)
	local grid = Dock(vgui.Create("DPanel", sc), 12)
	grid.Paint = NOPAINT
	local modes = {
		{ RMPG.DEST_RANDOM, "mode_random", "icon16/arrow_rotate_clockwise.png", function() RMPG.SendDest(RMPG.DEST_RANDOM) end },
		{ RMPG.DEST_LOCATION, "mode_location", "icon16/flag_green.png", function()
			local loc = RMPG.SelectedLoc and RMPG.Locations[RMPG.SelectedLoc]
			if loc then RMPG.SendDest(RMPG.DEST_LOCATION, loc) else f.Go("locations") end
		end },
		{ RMPG.DEST_PLAYER, "mode_player", "icon16/user_green.png", function()
			if IsValid(RMPG.SelectedPlayer) then RMPG.SendDest(RMPG.DEST_PLAYER, RMPG.SelectedPlayer) else f.Go("players") end
		end },
		{ RMPG.DEST_MANUAL, "mode_manual", "icon16/arrow_switch.png", function() RMPG.SendDest(RMPG.DEST_MANUAL) end },
		{ RMPG.DEST_QUICK, "mode_quick", "icon16/lightning_go.png", function() RMPG.SendDest(RMPG.DEST_QUICK) end },
		{ RMPG.DEST_TRAP, "mode_trap", "icon16/arrow_in.png", function() RMPG.SendDest(RMPG.DEST_TRAP) end },
		{ RMPG.DEST_CHAIN, "mode_chain", "icon16/link.png", function() RMPG.SendDest(RMPG.DEST_CHAIN) end },
		{ RMPG.DEST_COORDS, "mode_coords", "icon16/map_go.png", function() f.Go("coords") end },
		{ RMPG.DEST_MAP, "mode_map", "icon16/world_go.png", function() f.Go("maps") end },
	}
	local cards = {}
	for _, m in ipairs(modes) do
		cards[#cards + 1] = UI.Card(grid, RMPG.T(m[2]), RMPG.T(m[2] .. "_desc"), m[3], function()
			local w = LocalGun()
			return w ~= nil and w:GetDestMode() == m[1]
		end, m[4])
	end
	local key = RMPG.CL.binds.close:GetInt()
	local keyName = key > 0 and string.upper(input.GetKeyName(key) or "?") or RMPG.T("bind_none")
	cards[#cards + 1] = UI.Card(grid, RMPG.T("close_portals"), RMPG.T("bind_close") .. ": " .. keyName, "icon16/cancel.png", function() return false end, function()
		RMPG.Action("close")
	end)
	Grid(grid, 2, 112, 12, cards)
end

SCREENS.locations = function(p)
	local top = vgui.Create("DPanel", p)
	top:Dock(TOP)
	top:SetTall(44)
	top.Paint = NOPAINT
	local sc

	local function IsChosen(loc)
		local w = LocalGun()
		return w ~= nil and w:GetDestMode() == RMPG.DEST_LOCATION and w:GetDestCode() == loc.code and w:GetDestLabel() == loc.name
	end

	local SHARE_ICONS = { [0] = "icon16/lock.png", [1] = "icon16/group.png", [2] = "icon16/world.png" }

	local Refresh

	-- One location row: your own (share / rename / delete) or one shared by another player (copy)
	local function LocRow(loc, i)
		local own = i ~= nil
		local row = Dock(vgui.Create("DPanel", sc))
		row:SetTall(64)
		row.Paint = function(s, w, h)
			local chosen = IsChosen(loc)
			Bevel(0, 0, w, h, chosen and Mix(SCREEN2, TILE, 0.6) or SCREEN2, chosen and TILE_HI or nil, nil)
			Bevel(12, 13, 96, 38, Color(14, 4, 4))
			draw.SimpleText(loc.code or "?", "RMPG_Mono", 60, 32, Color(255, 60, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			Shadowed(loc.name or "?", "RMPG_BodyB", 122, 13, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local d = math.floor(LocalPlayer():GetPos():Distance(RMPG.LocPos(loc)) / RMPG.UNITS_PER_METER)
			local info
			if own then
				info = string.format("%d, %d, %d   ·   ", math.floor(loc.x or 0), math.floor(loc.y or 0), math.floor(loc.z or 0)) .. RMPG.T("meters", d)
					.. "   ·   " .. RMPG.T("loc_share_" .. RMPG.LocShare(loc))
			else
				info = RMPG.T("loc_by", loc.owner or "?") .. "   ·   " .. RMPG.T("meters", d) .. "   ·   " .. RMPG.T("loc_share_" .. (loc.share or 2))
			end
			draw.SimpleText(info, "RMPG_Small", 122, 37, MUTED)
		end
		if own then
			local del = UI.Button(row, "", "dark", function(b)
				if b.Confirm and RealTime() - b.Confirm < 2.5 then
					if RMPG.SelectedLoc == i then RMPG.SelectedLoc = nil end
					RMPG.RemoveLocation(i)
					Refresh()
				else
					b.Confirm = RealTime()
					b.Kind = "danger"
					timer.Simple(2.5, function() if IsValid(b) then b.Kind = "dark" end end)
				end
			end, "icon16/cross.png")
			del:Dock(RIGHT)
			del:DockMargin(6, 12, 12, 12)
			del:SetWide(40)
			del:SetTooltip(RMPG.T("loc_delete"))
			local ren = UI.Button(row, "", "dark", function()
				Derma_StringRequest(RMPG.T("loc_rename"), "", loc.name or "", function(txt)
					RMPG.RenameLocation(i, txt)
					Refresh()
				end)
			end, "icon16/pencil.png")
			ren:Dock(RIGHT)
			ren:DockMargin(6, 12, 0, 12)
			ren:SetWide(40)
			ren:SetTooltip(RMPG.T("loc_rename"))
			-- who may use it: private -> trusted players -> everyone
			local sh = UI.Button(row, "", "dark", function(b)
				local v = (RMPG.LocShare(loc) + 1) % 3
				RMPG.SetLocationShare(i, v)
				b.Icon = Icon(SHARE_ICONS[v])
				b.Kind = v == RMPG.SHARE_PUBLIC and "accent" or "dark"
			end, SHARE_ICONS[RMPG.LocShare(loc)])
			sh.Kind = RMPG.LocShare(loc) == RMPG.SHARE_PUBLIC and "accent" or "dark"
			sh:Dock(RIGHT)
			sh:DockMargin(6, 12, 0, 12)
			sh:SetWide(40)
			sh:SetTooltip(RMPG.T("loc_share_tip"))
		else
			local copy = UI.Button(row, "", "dark", function()
				RMPG.AddLocation(loc.name, RMPG.LocPos(loc), loc.yaw or 0)
				Refresh()
			end, "icon16/page_copy.png")
			copy:Dock(RIGHT)
			copy:DockMargin(6, 12, 12, 12)
			copy:SetWide(40)
			copy:SetTooltip(RMPG.T("loc_copy"))
		end
		local sel = UI.Button(row, function() return IsChosen(loc) and RMPG.T("loc_selected") or RMPG.T("loc_select") end, "accent", function()
			RMPG.SelectedLoc = i
			RMPG.SendDest(RMPG.DEST_LOCATION, loc)
		end)
		sel:Dock(RIGHT)
		sel:DockMargin(0, 12, 0, 12)
		sel:SetWide(130)
	end

	Refresh = function()
		sc:Clear()
		sc.Version = RMPG.SharedVersion
		if #RMPG.Locations == 0 then
			local e = vgui.Create("DPanel", sc)
			e:Dock(TOP)
			e:SetTall(230)
			e.Paint = function(s, w, h)
				RMPG.DrawSwirl2D(w / 2 - 60, 10, 120, Accent(), 160)
				for i, l in ipairs(Wrap(RMPG.T("loc_empty"), "RMPG_Body", w - 80)) do
					Shadowed(l, "RMPG_Body", w / 2, 160 + (i - 1) * 22, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
				end
			end
		end
		for i, loc in ipairs(RMPG.Locations) do LocRow(loc, i) end
		if #RMPG.SharedLocations > 0 then
			local hd = Dock(UI.Header(sc, RMPG.T("loc_shared_head")))
			hd:DockMargin(0, 8, 10, 6)
			for _, loc in ipairs(RMPG.SharedLocations) do LocRow(loc, nil) end
		end
	end
	p.Think = function()
		if sc.Version ~= RMPG.SharedVersion then Refresh() end
	end

	local entry
	local bAim = UI.Button(top, RMPG.T("loc_save_aim"), "tile", function()
		RMPG.SaveAim(entry:GetValue())
		entry:SetValue("")
		Refresh()
	end, "icon16/zoom.png")
	bAim:Dock(RIGHT)
	bAim:DockMargin(10, 0, 0, 0)
	bAim:SetWide(230)
	local bHere = UI.Button(top, RMPG.T("loc_save_here"), "accent", function()
		RMPG.SaveHere(entry:GetValue())
		entry:SetValue("")
		Refresh()
	end)
	bHere:Dock(RIGHT)
	bHere:DockMargin(10, 0, 0, 0)
	bHere:SetWide(170)
	entry = UI.Entry(top, RMPG.T("loc_name_ph"))
	entry:Dock(FILL)
	entry.OnEnter = function() bHere:DoClick() end

	local info = vgui.Create("DPanel", p)
	info:Dock(TOP)
	info:SetTall(30)
	info:DockMargin(0, 8, 0, 6)
	info.Paint = function(s, w, h)
		Shadowed(RMPG.T("loc_count", game.GetMap(), #RMPG.Locations), "RMPG_SmallB", 2, h / 2, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(RMPG.T("loc_share_hint"), "RMPG_Small", w - 12, h / 2, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	sc = UI.Scroll(p)
	sc:Dock(FILL)
	Refresh()
end

SCREENS.players = function(p)
	local search = UI.Entry(p, RMPG.T("players_search"))
	search:Dock(TOP)
	search:SetTall(42)
	local hint = vgui.Create("DPanel", p)
	hint:Dock(TOP)
	hint:SetTall(26)
	hint:DockMargin(0, 6, 0, 0)
	hint.Paint = function(s, w, h)
		draw.SimpleText(RMPG.T("players_trust_hint"), "RMPG_Small", 2, h / 2, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	local sc = UI.Scroll(p)
	sc:Dock(FILL)
	sc:DockMargin(0, 6, 0, 0)

	local function IsChosen(ply)
		local w = LocalGun()
		return w ~= nil and w:GetDestMode() == RMPG.DEST_PLAYER and IsValid(ply) and w:GetDestLabel() == "@" .. ply:Nick()
	end

	local function Refresh()
		sc:Clear()
		local q = string.lower(search:GetValue() or "")
		local me = LocalPlayer()
		local list = {}
		for _, ply in ipairs(player.GetAll()) do
			if ply ~= me and (q == "" or string.find(string.lower(ply:Nick()), q, 1, true)) then
				list[#list + 1] = ply
			end
		end
		table.sort(list, function(a, b) return a:GetPos():DistToSqr(me:GetPos()) < b:GetPos():DistToSqr(me:GetPos()) end)
		if #list == 0 then
			local e = vgui.Create("DPanel", sc)
			e:Dock(TOP)
			e:SetTall(220)
			e.Paint = function(s, w, h)
				RMPG.DrawSwirl2D(w / 2 - 60, 16, 120, Accent(), 160)
				Shadowed(RMPG.T("players_empty"), "RMPG_Body", w / 2, 170, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
			return
		end
		for _, ply in ipairs(list) do
			local row = Dock(vgui.Create("DPanel", sc))
			row:SetTall(68)
			local av = vgui.Create("AvatarImage", row)
			av:SetSize(44, 44)
			av:SetPos(15, 12)
			av:SetPlayer(ply, 64)
			row.Paint = function(s, w, h)
				if not IsValid(ply) then return end
				local chosen = IsChosen(ply)
				Bevel(0, 0, w, h, chosen and Mix(SCREEN2, TILE, 0.6) or SCREEN2, chosen and TILE_HI or nil, nil)
				Bevel(11, 8, 52, 52, OUTLINE, chosen and RED or GREEN_DK)
				local tc = team.GetColor(ply:Team())
				surface.SetDrawColor(tc)
				surface.DrawRect(74, 18, 8, 8)
				Shadowed(ply:Nick(), "RMPG_BodyB", 88, 13, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				local d = LocalPlayer():GetPos():Distance(ply:GetPos()) / RMPG.UNITS_PER_METER
				local info = RMPG.T("meters", math.floor(d)) .. "   ·   " .. RMPG.T("player_hp", math.max(ply:Health(), 0))
				if RMPG.TrustsMe[ply] then info = info .. "   ·   " .. RMPG.T("player_trusts_you") end
				draw.SimpleText(info, "RMPG_Small", 74, 40, MUTED)
			end
			local b = UI.Button(row, RMPG.T("player_find"), "accent", function()
				if not IsValid(ply) then return end
				RMPG.SelectedPlayer = ply
				RMPG.SendDest(RMPG.DEST_PLAYER, ply)
			end, "icon16/find.png")
			b:Dock(RIGHT)
			b:DockMargin(0, 14, 12, 14)
			b:SetWide(124)
			-- trusted players may use your locations marked "for trusted players"
			local function TrustLook(btn)
				local on = RMPG.IsTrusted(ply)
				btn.Kind = on and "accent" or "dark"
				btn.Icon = Icon(on and "icon16/star.png" or "icon16/user_add.png")
			end
			local tb = UI.Button(row, function() return RMPG.IsTrusted(ply) and RMPG.T("player_trusted") or RMPG.T("player_trust") end, "dark", function(btn)
				if not IsValid(ply) then return end
				RMPG.SetTrusted(ply, not RMPG.IsTrusted(ply))
				TrustLook(btn)
			end, "icon16/user_add.png")
			TrustLook(tb)
			tb:Dock(RIGHT)
			tb:DockMargin(0, 14, 8, 14)
			tb:SetWide(158)
			tb:SetTooltip(RMPG.T("player_trust_tip"))
		end
	end

	search:SetUpdateOnType(true)
	search.OnChange = function() Refresh() end
	Refresh()
	p.Think = function(s)
		if (s.NextCheck or 0) > RealTime() then return end
		s.NextCheck = RealTime() + 1
		local n = player.GetCount()
		if n ~= s.Count then
			if s.Count then Refresh() end
			s.Count = n
		end
	end
end

function RMPG.SetFluidColor(col)
	local r, g, b = math.floor(col.r), math.floor(col.g), math.floor(col.b)
	RMPG.CL.r:SetInt(r)
	RMPG.CL.g:SetInt(g)
	RMPG.CL.b:SetInt(b)
	timer.Create("rmpg_send_color", 0.12, 1, function()
		net.Start("rmpg_color")
		net.WriteUInt(r, 8)
		net.WriteUInt(g, 8)
		net.WriteUInt(b, 8)
		net.SendToServer()
	end)
end

function RMPG.SetVariant(v)
	RMPG.CL.model:SetInt(v)
	net.Start("rmpg_variant")
	net.WriteUInt(v, 3)
	net.SendToServer()
	RMPG.AddNote(RMPG.T("n_model_set", RMPG.T("model_" .. RMPG.Model.Variant(v).key)), 2)
end

-- The body colour: a colour of your own, or nil for the model's
RMPG.BODY_PRESETS = {
	{ 236, 196, 44 }, { 234, 236, 240 }, { 40, 42, 48 }, { 214, 40, 44 }, { 52, 110, 220 }, { 70, 190, 90 },
	{ 238, 120, 40 }, { 150, 70, 200 }, { 240, 110, 170 }, { 120, 200, 220 }, { 196, 158, 98 },
}
function RMPG.SetBodyColor(col)
	local custom = col ~= nil
	RMPG.CL.bodyOn:SetBool(custom)
	if col then
		RMPG.CL.bodyR:SetInt(math.floor(col.r))
		RMPG.CL.bodyG:SetInt(math.floor(col.g))
		RMPG.CL.bodyB:SetInt(math.floor(col.b))
	end
	timer.Create("rmpg_send_body", 0.12, 1, function()
		net.Start("rmpg_body")
		net.WriteBool(custom)
		net.WriteUInt(math.Clamp(RMPG.CL.bodyR:GetInt(), 0, 255), 8)
		net.WriteUInt(math.Clamp(RMPG.CL.bodyG:GetInt(), 0, 255), 8)
		net.WriteUInt(math.Clamp(RMPG.CL.bodyB:GetInt(), 0, 255), 8)
		net.SendToServer()
	end)
end

SCREENS.gun = function(p, f)
	local sc = UI.Scroll(p)
	sc:Dock(FILL)

	-- model + status ---------------------------------------------------------
	local r1 = Dock(vgui.Create("DPanel", sc), 14)
	r1:SetTall(240)
	r1.Paint = NOPAINT
	local prev = UI.ModelPreview(r1, { label = function() return RMPG.T("fluid_preview") end })
	prev:Dock(LEFT)
	prev:SetWide(320)
	local stat = vgui.Create("DPanel", r1)
	stat:Dock(FILL)
	stat:DockMargin(12, 0, 0, 0)
	stat.Paint = function(s, w, h)
		local ac = Accent()
		local wep = LocalGun()
		Bevel(0, 0, w, h, SCREEN2)
		Shadowed(RMPG.T("fluid_status"), "RMPG_Sub", 18, 14, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(RMPG.T("fluid_charges"), "RMPG_SmallB", 18, 44, MUTED)
		local core = wep and wep:GetCore()
		local max = math.max(RMPG.MaxCharges(), 1)
		local txt = wep and (core and "∞" or (wep:GetCharges() .. " / " .. max)) or "—"
		Shadowed(txt, "RMPG_Big", 18, 56, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		local frac = wep and (core and 1 or wep:GetCharges() / max) or 0
		local n = 16
		local bw = (w - 36) / n
		for k = 0, n - 1 do
			surface.SetDrawColor((k + 0.5) / n <= frac and GREEN or SCREEN3)
			surface.DrawRect(18 + k * bw, 108, bw - 3, 12)
		end
		draw.SimpleText(RMPG.T("fluid_flasks"), "RMPG_SmallB", 18, 132, MUTED)
		local fl = wep and (RMPG.CV.infinite:GetBool() and "∞" or tostring(wep:GetFlasks())) or "—"
		Shadowed(fl, "RMPG_Head", 18, 150, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	local rb = UI.Button(stat, RMPG.T("fluid_reload"), "accent", function() RMPG.Action("reload") end, "icon16/arrow_refresh.png")
	rb:Dock(BOTTOM)
	rb:DockMargin(18, 0, 18, 16)
	rb:SetTall(42)

	-- model choice ---------------------------------------------------------------
	Dock(UI.Header(sc, RMPG.T("model_title")))
	local rm = Dock(vgui.Create("DPanel", sc), 14)
	rm.Paint = NOPAINT
	local variants = {}
	for _, v in ipairs(RMPG.Model.Order) do
		local key = "model_" .. RMPG.Model.Variant(v).key
		local card = vgui.Create("DButton", rm)
		card:SetText("")
		card.Hov = 0
		card.Paint = function(s, w, h)
			local sel = RMPG.CL.model:GetInt() == v
			s.Hov = Lerp(FrameTime() * 12, s.Hov, s:IsHovered() and 1 or 0)
			local fill, hi, lo = TileColors("tile", s.Hov, s:IsDown())
			Bevel(0, 0, w, h, sel and Mix(fill, Color(255, 255, 255), 0.12) or fill, hi, lo)
			if sel then
				surface.SetDrawColor(RED)
				surface.DrawOutlinedRect(5, 5, w - 10, h - 10, 2)
			end
			Shadowed(RMPG.T(key), "RMPG_Tile", 14, 10, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			DrawWrapped(RMPG.T(key .. "_desc"), "RMPG_Small", 14, h - 50, w - 28, MUTED, 15)
		end
		card.DoClick = function()
			Snd("ui_click")
			RMPG.SetVariant(v)
		end
		local pv = UI.ModelPreview(card, { variant = function() return v end, scale = 0.8 })
		pv:SetMouseInputEnabled(false)
		card.PerformLayout = function(s, w, h)
			pv:SetPos(10, 38)
			pv:SetSize(w - 20, h - 92)
		end
		variants[#variants + 1] = card
	end
	Grid(rm, 3, 236, 10, variants)

	-- body colour ----------------------------------------------------------------
	Dock(UI.Header(sc, RMPG.T("body_color")))
	local rb2 = Dock(vgui.Create("DPanel", sc), 14)
	rb2:SetTall(250)
	rb2.Paint = NOPAINT
	local bprev = UI.ModelPreview(rb2, { label = function() return RMPG.T(RMPG.CL.bodyOn:GetBool() and "body_own" or "body_stock") end })
	bprev:Dock(RIGHT)
	bprev:SetWide(260)
	bprev:DockMargin(12, 0, 0, 0)
	local bl = vgui.Create("DPanel", rb2)
	bl:Dock(FILL)
	bl.Paint = function(s, w, h) Bevel(0, 0, w, h, SCREEN2) end
	local bmixer
	local tog = UI.Toggle(bl, RMPG.T("body_custom"), RMPG.T("body_custom_d"), function() return RMPG.CL.bodyOn:GetBool() end, function(on)
		RMPG.SetBodyColor(on and Color(RMPG.CL.bodyR:GetInt(), RMPG.CL.bodyG:GetInt(), RMPG.CL.bodyB:GetInt()) or nil)
	end)
	tog:Dock(TOP)
	tog:DockMargin(10, 10, 10, 0)
	local bsw = vgui.Create("DPanel", bl)
	bsw:Dock(TOP)
	bsw:SetTall(40)
	bsw:DockMargin(10, 8, 10, 0)
	bsw.Paint = NOPAINT
	for _, c in ipairs(RMPG.BODY_PRESETS) do
		local b = vgui.Create("DButton", bsw)
		b:SetText("")
		b:Dock(LEFT)
		b:SetWide(32)
		b:DockMargin(0, 4, 6, 4)
		local col = Color(c[1], c[2], c[3])
		b.Paint = function(s, w, h)
			local on = RMPG.CL.bodyOn:GetBool() and RMPG.CL.bodyR:GetInt() == c[1] and RMPG.CL.bodyG:GetInt() == c[2] and RMPG.CL.bodyB:GetInt() == c[3]
			Bevel(0, 0, w, h, col, Mix(col, Color(255, 255, 255), 0.5), Mix(col, Color(0, 0, 0), 0.4), (on or s:IsHovered()) and 4 or 2)
			if on then
				surface.SetDrawColor(255, 255, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
			end
		end
		b.DoClick = function()
			Snd("ui_click")
			RMPG.SetBodyColor(col)
			if IsValid(bmixer) then bmixer:SetColor(col) end
		end
	end
	bmixer = vgui.Create("DColorMixer", bl)
	bmixer:Dock(FILL)
	bmixer:DockMargin(10, 8, 10, 10)
	bmixer:SetPalette(false)
	bmixer:SetAlphaBar(false)
	bmixer:SetWangs(true)
	bmixer:SetColor(Color(RMPG.CL.bodyR:GetInt(), RMPG.CL.bodyG:GetInt(), RMPG.CL.bodyB:GetInt()))
	bmixer.ValueChanged = function(s, col) RMPG.SetBodyColor(col) end

	-- filling type -------------------------------------------------------------
	Dock(UI.Header(sc, RMPG.T("fluid_type")))
	local r2 = Dock(vgui.Create("DPanel", sc), 14)
	r2.Paint = NOPAINT
	local function HasCore() local w = LocalGun() return w ~= nil and w:GetCore() end
	local std = UI.Card(r2, RMPG.T("fluid_standard"), RMPG.T("fluid_standard_desc", RMPG.MaxCharges()), "icon16/drink.png",
		function() return LocalGun() ~= nil and not HasCore() end,
		function()
			if HasCore() then
				net.Start("rmpg_core")
				net.WriteBool(false)
				net.SendToServer()
			end
		end)
	local core = UI.Card(r2, RMPG.T("fluid_core"), RMPG.T("fluid_core_desc", RMPG.CV.sdCore:GetInt()), "icon16/lightning.png",
		HasCore,
		function()
			if not RMPG.CV.coreMenu:GetBool() then
				RMPG.AddNote(RMPG.T("n_core_denied"), 1)
				return
			end
			net.Start("rmpg_core")
			net.WriteBool(true)
			net.SendToServer()
		end, { locked = function() return not RMPG.CV.coreMenu:GetBool() end })
	Grid(r2, 2, 104, 12, { std, core })

	-- colour ---------------------------------------------------------------------
	Dock(UI.Header(sc, RMPG.T("fluid_color")))
	local r3 = Dock(vgui.Create("DPanel", sc), 14)
	r3:SetTall(220)
	r3.Paint = NOPAINT
	local swirl = vgui.Create("DPanel", r3)
	swirl:Dock(RIGHT)
	swirl:SetWide(220)
	swirl:DockMargin(12, 0, 0, 0)
	swirl.Paint = function(s, w, h)
		Bevel(0, 0, w, h, SCREEN3)
		RMPG.DrawSwirl2D(w / 2 - 80, h / 2 - 80, 160, Accent(), 255)
	end
	local left = vgui.Create("DPanel", r3)
	left:Dock(FILL)
	left.Paint = function(s, w, h) Bevel(0, 0, w, h, SCREEN2) end
	local sw = vgui.Create("DPanel", left)
	sw:Dock(TOP)
	sw:SetTall(44)
	sw:DockMargin(12, 10, 12, 0)
	sw.Paint = NOPAINT
	local mixer
	for _, c in ipairs(RMPG.PRESETS) do
		local b = vgui.Create("DButton", sw)
		b:SetText("")
		b:Dock(LEFT)
		b:SetWide(34)
		b:DockMargin(0, 5, 6, 5)
		local col = Color(c[1], c[2], c[3])
		b.Paint = function(s, w, h)
			local cur = RMPG.LocalColor()
			local sel = cur.x == c[1] and cur.y == c[2] and cur.z == c[3]
			Bevel(0, 0, w, h, col, Mix(col, Color(255, 255, 255), 0.5), Mix(col, Color(0, 0, 0), 0.4), (sel or s:IsHovered()) and 4 or 2)
			if sel then
				surface.SetDrawColor(255, 255, 255)
				surface.DrawOutlinedRect(0, 0, w, h, 2)
			end
		end
		b.DoClick = function()
			Snd("ui_click")
			RMPG.SetFluidColor(col)
			if IsValid(mixer) then mixer:SetColor(col) end
		end
	end
	mixer = vgui.Create("DColorMixer", left)
	mixer:Dock(FILL)
	mixer:DockMargin(12, 8, 12, 12)
	mixer:SetPalette(false)
	mixer:SetAlphaBar(false)
	mixer:SetWangs(true)
	mixer:SetColor(Accent())
	mixer.ValueChanged = function(s, col) RMPG.SetFluidColor(col) end

	-- self-destruct ----------------------------------------------------------------
	Dock(UI.Header(sc, RMPG.T("sd_title")))
	local sd = Dock(vgui.Create("DPanel", sc), 8)
	sd:SetTall(132)
	sd.Paint = function(s, w, h)
		Hazard(s, w, h, RealTime())
		Bevel(8, 8, w - 16, h - 16, Color(20, 4, 8, 230), RED)
		surface.SetMaterial(Icon("icon16/bomb.png"))
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(24, 22, 16, 16)
		Shadowed(RMPG.T("sd_title"), "RMPG_Tile", 48, 18, HAZARD, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		local wep = LocalGun()
		local radius = (wep and wep:GetCore()) and RMPG.CV.sdCore:GetInt() or RMPG.CV.sdRadius:GetInt()
		DrawWrapped(RMPG.T("sd_desc", radius), "RMPG_Small", 24, 48, w - 330, Color(255, 200, 205), 16)
	end
	local hold = vgui.Create("DButton", sd)
	hold:SetText("")
	hold:Dock(RIGHT)
	hold:DockMargin(0, 34, 24, 34)
	hold:SetWide(270)
	hold.Hold = 0
	hold.Think = function(s)
		if s.Fired then return end
		if s:IsDown() and LocalGun() then
			s.Hold = math.min(1, s.Hold + FrameTime() / 2)
			if RealTime() > (s.NextTick or 0) then
				s.NextTick = RealTime() + 0.32 - s.Hold * 0.22
				surface.PlaySound(RMPG.SND.beep)
			end
			if s.Hold >= 1 then
				s.Fired = true
				net.Start("rmpg_selfdestruct")
				net.SendToServer()
				timer.Simple(0.35, function() if IsValid(f) then f:Close() end end)
			end
		else
			s.Hold = math.max(0, s.Hold - FrameTime() * 2.5)
		end
	end
	hold.Paint = function(s, w, h)
		Bevel(0, 0, w, h, Color(50, 6, 12, 220), RED, nil)
		surface.SetDrawColor(255, 60, 80, 200)
		surface.DrawRect(3, 3, (w - 6) * s.Hold, h - 6)
		Shadowed(s.Fired and RMPG.T("sd_go") or RMPG.T("sd_hold"), "RMPG_BodyB", w / 2, h / 2, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

SCREENS.radial = function(p)
	local R = RMPG.Radial
	local hint = vgui.Create("DPanel", p)
	hint:Dock(TOP)
	hint:SetTall(40)
	hint:DockMargin(0, 0, 0, 8)
	hint.Paint = function(s, w, h) DrawWrapped(RMPG.T("radial_hint"), "RMPG_Small", 2, 2, w - 4, MUTED, 16) end

	local bottom = vgui.Create("DPanel", p)
	bottom:Dock(BOTTOM)
	bottom:SetTall(42)
	bottom:DockMargin(0, 10, 0, 0)
	bottom.Paint = NOPAINT

	local cols = vgui.Create("DPanel", p)
	cols:Dock(FILL)
	cols.Paint = NOPAINT
	local slots = vgui.Create("DPanel", cols)
	slots.Paint = function(s, w, h) Bevel(0, 0, w, h, SCREEN2) Shadowed(RMPG.T("radial_slots"), "RMPG_SmallB", 12, 10, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
	local wheel = vgui.Create("DPanel", cols)
	wheel.Paint = function(s, w, h)
		Bevel(0, 0, w, h, SCREEN3)
		local x, y = w / 2, h / 2
		R.DrawWheel(x, y, math.min(w, h) / 470, R.Visible(), nil, 1)
		RMPG.DrawSwirl2D(x - 28, y - 28, 56, Accent(), 220)
	end
	local add = vgui.Create("DPanel", cols)
	add.Paint = function(s, w, h) Bevel(0, 0, w, h, SCREEN2) Shadowed(RMPG.T("radial_add"), "RMPG_SmallB", 12, 10, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
	cols.PerformLayout = function(s, w, h)
		local cw = (w - 24) * 0.36
		local mw = w - 24 - cw * 2
		slots:SetPos(0, 0) slots:SetSize(cw, h)
		wheel:SetPos(cw + 12, 0) wheel:SetSize(mw, h)
		add:SetPos(cw + mw + 24, 0) add:SetSize(cw, h)
	end

	local slotList = UI.Scroll(slots)
	slotList:Dock(FILL)
	slotList:DockMargin(8, 34, 4, 8)
	local addList = UI.Scroll(add)
	addList:Dock(FILL)
	addList:DockMargin(8, 34, 4, 8)

	local Refresh
	local function Row(parent, id, buttons)
		local label, icon = R.Describe(id)
		local row = vgui.Create("DPanel", parent)
		row:Dock(TOP)
		row:DockMargin(0, 0, 6, 4)
		row:SetTall(36)
		row.Paint = function(s, w, h)
			Bevel(0, 0, w, h, TILE, TILE_HI, TILE_LO, 2)
			if icon then
				surface.SetMaterial(icon)
				surface.SetDrawColor(255, 255, 255)
				surface.DrawTexturedRect(9, h / 2 - 8, 16, 16)
			end
			local l = label or id
			if #l > 22 then l = string.sub(l, 1, 21) .. "…" end
			Shadowed(l, "RMPG_SmallB", 32, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		for i = #buttons, 1, -1 do
			local bt = buttons[i]
			local b = UI.Button(row, "", "dark", bt[2], bt[1])
			b:Dock(RIGHT)
			b:DockMargin(2, 4, 4, 4)
			b:SetWide(28)
		end
	end

	Refresh = function()
		slotList:Clear()
		addList:Clear()
		local items = R.Items
		if #items == 0 then
			local e = vgui.Create("DPanel", slotList)
			e:Dock(TOP)
			e:SetTall(60)
			e.Paint = function(s, w, h) DrawWrapped(RMPG.T("radial_empty"), "RMPG_Small", 4, 4, w - 8, MUTED, 16) end
		end
		for i, id in ipairs(items) do
			Row(slotList, id, {
				{ "icon16/arrow_up.png", function()
					if i > 1 then items[i], items[i - 1] = items[i - 1], items[i] R.Save() Refresh() end
				end },
				{ "icon16/arrow_down.png", function()
					if i < #items then items[i], items[i + 1] = items[i + 1], items[i] R.Save() Refresh() end
				end },
				{ "icon16/cross.png", function() table.remove(items, i) R.Save() Refresh() end },
			})
		end
		local used = {}
		for _, id in ipairs(items) do used[id] = true end
		local function Add(id)
			if #items >= R.MAX then
				RMPG.AddNote(RMPG.T("radial_max", R.MAX), 1)
				return
			end
			table.insert(items, id)
			R.Save()
			Refresh()
		end
		Dock(UI.Header(addList, RMPG.T("radial_modes")), 4)
		for _, id in ipairs(R.ActionIds) do
			if not used[id] then Row(addList, id, { { "icon16/add.png", function() Add(id) end } }) end
		end
		Dock(UI.Header(addList, RMPG.T("radial_locs")), 4)
		local any = false
		for _, loc in ipairs(RMPG.Locations) do
			local id = R.LocationId(loc)
			if not used[id] then
				any = true
				Row(addList, id, { { "icon16/add.png", function() Add(id) end } })
			end
		end
		if not any and #RMPG.Locations == 0 then
			local e = vgui.Create("DPanel", addList)
			e:Dock(TOP)
			e:SetTall(24)
			e.Paint = function(s, w, h) draw.SimpleText(RMPG.T("radial_noloc"), "RMPG_Small", 4, h / 2, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
		end
	end
	Refresh()

	local reset = UI.Button(bottom, RMPG.T("radial_reset"), "tile", function() R.Reset() Refresh() end, "icon16/arrow_undo.png")
	reset:Dock(LEFT)
	reset:SetWide(220)
end

SCREENS.binds = function(p)
	local hint = vgui.Create("DPanel", p)
	hint:Dock(TOP)
	hint:SetTall(44)
	hint:DockMargin(0, 0, 0, 8)
	hint.Paint = function(s, w, h) DrawWrapped(RMPG.T("binds_hint"), "RMPG_Small", 2, 2, w - 4, MUTED, 16) end
	local sc = UI.Scroll(p)
	sc:Dock(FILL)
	local trapping
	for _, b in ipairs(RMPG.BINDS) do
		local id = b[1]
		local cv = RMPG.CL.binds[id]
		local row = Dock(vgui.Create("DPanel", sc), 6)
		row:SetTall(50)
		row.Paint = function(s, w, h)
			Bevel(0, 0, w, h, SCREEN2)
			Shadowed(RMPG.T("bind_" .. id), "RMPG_BodyB", 14, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		local btn = UI.Button(row, function()
			if trapping == id then
				return (math.floor(RealTime() * 3) % 2 == 0) and RMPG.T("bind_press") or ""
			end
			local code = cv:GetInt()
			if code <= 0 then return RMPG.T("bind_none") end
			return string.upper(input.GetKeyName(code) or tostring(code))
		end, "accent", function()
			trapping = id
			input.StartKeyTrapping()
		end)
		btn:Dock(RIGHT)
		btn:DockMargin(0, 8, 10, 8)
		btn:SetWide(220)
		btn.Think = function()
			if trapping ~= id or not input.IsKeyTrapping() then
				if trapping == id and not input.IsKeyTrapping() then trapping = nil end
				return
			end
			local code = input.CheckKeyTrapping()
			if code then
				if code == KEY_BACKSPACE then cv:SetInt(0)
				elseif code ~= KEY_ESCAPE then cv:SetInt(code) end
				trapping = nil
				Snd("ui_click")
			end
		end
	end
	local reset = Dock(UI.Button(sc, RMPG.T("binds_reset"), "tile", function() RMPG.ResetBinds() end, "icon16/arrow_undo.png"), 6)
	reset:SetTall(40)
end

SCREENS.settings = function(p)
	local sc = UI.Scroll(p)
	sc:Dock(FILL)
	local CL = RMPG.CL
	local function Get(cv) return function() return cv:GetBool() end end
	local function Set(cv) return function(v) cv:SetBool(v) end end

	Dock(UI.Header(sc, RMPG.T("set_general")))
	Dock(UI.Segmented(sc, RMPG.T("set_language"), {
		{ "auto", RMPG.T("lang_auto") }, { "ru", RMPG.T("lang_ru") }, { "en", RMPG.T("lang_en") },
	}, function() return CL.lang:GetString() end, function(v)
		CL.lang:SetString(v)
		RMPG.ApplyLanguage()
		timer.Simple(0, function() RMPG.OpenMenu("settings") end)
	end))
	Dock(UI.Toggle(sc, RMPG.T("set_vertical"), RMPG.T("set_vertical_desc"), Get(CL.vertical), Set(CL.vertical)))
	Dock(UI.Toggle(sc, RMPG.T("set_preview"), nil, Get(CL.preview), Set(CL.preview)))
	Dock(UI.Toggle(sc, RMPG.T("set_hands"), nil, Get(CL.hands), Set(CL.hands)))
	Dock(UI.Toggle(sc, RMPG.T("set_outline"), nil, Get(CL.outline), Set(CL.outline)))
	Dock(UI.Toggle(sc, RMPG.T("set_hud"), nil, Get(CL.hud), Set(CL.hud)))
	Dock(UI.Toggle(sc, RMPG.T("set_particles"), nil, Get(CL.particles), Set(CL.particles)))
	Dock(UI.Toggle(sc, RMPG.T("set_uisounds"), nil, Get(CL.uisounds), Set(CL.uisounds)), 16)

	Dock(UI.Header(sc, RMPG.T("set_vm")))
	local function Num(cv) return function() return cv:GetFloat() end end
	local function SetNum(cv) return function(v) cv:SetFloat(v) end end
	Dock(UI.Slider(sc, RMPG.T("vm_scale"), 0.5, 2, 2, Num(CL.vmScale), SetNum(CL.vmScale)))
	Dock(UI.Slider(sc, RMPG.T("vm_x"), -10, 10, 1, Num(CL.vmX), SetNum(CL.vmX)))
	Dock(UI.Slider(sc, RMPG.T("vm_y"), -10, 10, 1, Num(CL.vmY), SetNum(CL.vmY)))
	Dock(UI.Slider(sc, RMPG.T("vm_z"), -10, 10, 1, Num(CL.vmZ), SetNum(CL.vmZ)))
	Dock(UI.Slider(sc, RMPG.T("vm_pitch"), -60, 60, 0, Num(CL.vmPitch), SetNum(CL.vmPitch)))
	Dock(UI.Slider(sc, RMPG.T("vm_yaw"), -60, 60, 0, Num(CL.vmYaw), SetNum(CL.vmYaw)))
	Dock(UI.Slider(sc, RMPG.T("vm_roll"), -60, 60, 0, Num(CL.vmRoll), SetNum(CL.vmRoll)))
	local factory = Dock(UI.Button(sc, RMPG.T("factory_reset"), "accent", function()
		for _, cv in ipairs({ CL.vmScale, CL.vmX, CL.vmY, CL.vmZ, CL.vmPitch, CL.vmYaw, CL.vmRoll }) do
			cv:SetString(cv:GetDefault())
		end
	end, "icon16/arrow_undo.png"), 16)
	factory:SetTall(40)


	if not LocalPlayer():IsSuperAdmin() then return end
	Dock(UI.Header(sc, RMPG.T("set_server")))
	local function SvSet(name, v)
		net.Start("rmpg_svset")
		net.WriteString(name)
		net.WriteString(tostring(v))
		net.SendToServer()
	end
	for _, s in ipairs(RMPG.SERVER_SETTINGS) do
		local name = s[1]
		local cv = GetConVar(name)
		if cv then
			if s[2] == "bool" then
				Dock(UI.Toggle(sc, RMPG.T("sv_" .. name), nil, function() return cv:GetBool() end, function(v) SvSet(name, v and 1 or 0) end))
			else
				Dock(UI.Slider(sc, RMPG.T("sv_" .. name), s[3], s[4], s[5], function() return cv:GetFloat() end, nil, function(v) SvSet(name, v) end))
			end
		end
	end
end

local TITLES = {
	home = "menu_title", dest = "tab_dest", locations = "tab_locations", players = "tab_players",
	gun = "tab_gun", radial = "tab_radial", binds = "tab_binds", settings = "tab_settings",
	coords = "mode_coords", maps = "mode_map",
}
-- Where the back button goes from a screen that is not on the home screen
local PARENTS = { coords = "dest", maps = "dest" }

---------------------------------------------------------------------------
-- Frame: white gun-body bezel around a red screen
---------------------------------------------------------------------------

function RMPG.OpenMenu(screen)
	if IsValid(RMPG.MenuFrame) then RMPG.MenuFrame:Remove() end
	local W, H = math.min(1000, ScrW() - 40), math.min(700, ScrH() - 40)
	local SIDE, NECK, PAD = 66, 54, 14
	local BW, BH = W - SIDE, H - NECK
	local SX, SY, SW, SH = PAD, PAD, BW - PAD * 2, BH - PAD * 2
	local HEAD = 64

	local f = vgui.Create("DFrame")
	f:SetSize(W, H)
	f:Center()
	f:SetTitle("")
	f:ShowCloseButton(false)
	f:SetDraggable(false)
	f:SetSizable(false)
	f:MakePopup()
	f:SetAlpha(0)
	f:AlphaTo(255, 0.15)
	RMPG.MenuFrame = f
	Snd("ui_open")

	f.Opened = RealTime()
	f.Paint = function(s, w, h)
		local t = RealTime()
		local k = math.Clamp((t - s.Opened) / 0.25, 0, 1)
		-- the hologram unfolds from a bright line
		local hh = math.max(BH * k * k * (3 - 2 * k), 2)
		local y0 = (BH - hh) / 2
		local flick = 0.93 + 0.07 * math.sin(t * 23) * math.sin(t * 7.3)
		-- projector beam rising from the gun under the hologram
		draw.NoTexture()
		surface.SetDrawColor(60, 255, 150, 26)
		surface.DrawPoly({
			{ x = BW / 2 - 140, y = BH },
			{ x = BW / 2 + 140, y = BH },
			{ x = BW / 2 + 26, y = H - 8 },
			{ x = BW / 2 - 26, y = H - 8 },
		})
		draw.RoundedBox(3, BW / 2 - 46, H - 10, 92, 8, Color(90, 255, 160, 200))
		draw.RoundedBox(3, BW / 2 - 18, H - 10, 36, 8, Color(255, 80, 100, 220))
		-- body of the hologram
		surface.SetDrawColor(BG.r, BG.g, BG.b, BG.a * flick)
		surface.DrawRect(0, y0, BW, hh)
		surface.SetMaterial(RMPG.Mat.glow2D)
		surface.SetDrawColor(60, 255, 140, 40)
		surface.DrawTexturedRect(-260, y0 - 260, 780, 640)
		surface.SetDrawColor(255, 50, 80, 34)
		surface.DrawTexturedRect(BW - 520, y0 + hh - 380, 780, 640)
		surface.SetDrawColor(60, 255, 150, 9)
		for x = 0, BW, 32 do surface.DrawRect(x, y0, 1, hh) end
		for y = y0, y0 + hh, 32 do surface.DrawRect(0, y, BW, 1) end
		surface.SetDrawColor(0, 0, 0, 38)
		for y = y0 + (t * 40) % 6, y0 + hh, 6 do surface.DrawRect(0, y, BW, 2) end
		surface.SetDrawColor(90, 255, 160, 16)
		surface.DrawRect(0, y0 + (t * 0.3 % 1) * hh, BW, 26)
		Bevel(0, y0, BW, hh, Color(0, 0, 0, 0), GREEN)
		surface.SetDrawColor(RED)
		surface.DrawRect(20, y0 + 6, 46, 2)
		surface.DrawRect(BW - 66, y0 + hh - 8, 46, 2)
		if k < 1 then return end
		-- header line and footer hint
		surface.SetDrawColor(GREEN.r, GREEN.g, GREEN.b, 90)
		surface.DrawRect(SX + 12, SY + HEAD - 4, SW - 24, 1)
		surface.SetDrawColor(RED.r, RED.g, RED.b, 160)
		surface.DrawRect(SX + 12, SY + HEAD - 4, 80, 1)
		draw.SimpleText(RMPG.T("controls"), "RMPG_Small", BW / 2, BH - 12, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	f.Think = function(s)
		if input.IsKeyDown(KEY_ESCAPE) and not input.IsKeyTrapping() then
			gui.HideGameUI()
			s:Close()
		end
	end
	f.OnClose = function() Snd("ui_close") end
	f.OnMousePressed = function(s, code)
		if code == MOUSE_RIGHT then s:Close() return end
		if code == MOUSE_LEFT then s.Drag = { gui.MouseX() - s.x, gui.MouseY() - s.y } end
	end
	f.OnMouseReleased = function(s) s.Drag = nil end
	local oldThink = f.Think
	f.Think = function(s)
		oldThink(s)
		if s.Drag then
			if not input.IsMouseDown(MOUSE_LEFT) then s.Drag = nil return end
			s:SetPos(math.Clamp(gui.MouseX() - s.Drag[1], 0, ScrW() - W), math.Clamp(gui.MouseY() - s.Drag[2], 0, ScrH() - H))
		end
	end

	-- side buttons: swap flask and close
	local flask = vgui.Create("DButton", f)
	flask:SetText("")
	flask:SetPos(W - 54, 30)
	flask:SetSize(48, 48)
	flask:SetTooltip(RMPG.T("fluid_reload"))
	flask.Paint = function(s, w, h)
		local ac = Accent()
		Bevel(0, 0, w, h, s:IsHovered() and TILE_HOV or BG, GREEN)
		draw.RoundedBox(4, w / 2 - 7, 9, 14, 30, Color(200, 255, 230, 80))
		draw.RoundedBox(4, w / 2 - 5, 18, 10, 19, ac)
		surface.SetDrawColor(GREEN)
		surface.DrawRect(w / 2 - 8, 7, 16, 3)
	end
	flask.DoClick = function()
		Snd("ui_click")
		RMPG.Action("reload")
	end
	local close = vgui.Create("DButton", f)
	close:SetText("")
	close:SetPos(W - 54, 86)
	close:SetSize(48, 48)
	close.Paint = function(s, w, h)
		Bevel(0, 0, w, h, s:IsHovered() and Color(120, 14, 30, 235) or Color(40, 4, 10, 225), RED)
		DrawX(w / 2, h / 2, 9, s:IsHovered() and Color(255, 255, 255) or RED)
	end
	close.DoClick = function() f:Close() end

	-- screen header: back button, title, charge bar
	local head = vgui.Create("DPanel", f)
	head:SetPos(SX + 12, SY + 10)
	head:SetSize(SW - 24, HEAD - 18)
	head.Paint = function(s, w, h)
		local ac = Accent()
		local wep = LocalGun()
		local tx = f.Screen == "home" and 54 or 150
		if f.Screen == "home" then RMPG.DrawSwirl2D(4, 2, 40, ac, 255) end
		Shadowed(RMPG.T(TITLES[f.Screen] or "menu_title"), "RMPG_ScreenTitle", tx, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		-- CHARGE: |||||||||
		local n = 12
		local bx = w - n * 10 - 4
		Shadowed(RMPG.T("home_charge") .. ":", "RMPG_SmallB", bx - 10, h / 2, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		local frac = 0
		if wep then frac = wep:GetCore() and 1 or wep:GetCharges() / math.max(RMPG.MaxCharges(), 1) end
		surface.SetDrawColor(OUTLINE)
		surface.DrawRect(bx - 3, h / 2 - 11, n * 10 + 4, 22)
		for k = 0, n - 1 do
			local lit = (k + 0.5) / n <= frac
			surface.SetDrawColor(lit and GREEN or Color(10, 40, 26))
			surface.DrawRect(bx + k * 10, h / 2 - 8, 7, 16)
		end
	end
	local back = UI.Button(head, "◄ " .. RMPG.T("back"), "tile", function() f.Go(PARENTS[f.Screen] or "home") end)
	back:SetPos(0, 2)
	back:SetSize(132, head:GetTall() - 4)

	local content = vgui.Create("DPanel", f)
	content:SetPos(SX + 14, SY + HEAD + 8)
	content:SetSize(SW - 28, SH - HEAD - 20)
	content.Paint = NOPAINT

	f.Go = function(id)
		if not SCREENS[id] then id = "home" end
		content:Clear()
		f.Screen = id
		RMPG.LastScreen = id
		back:SetVisible(id ~= "home")
		local inner = vgui.Create("DPanel", content)
		inner:Dock(FILL)
		inner.Paint = NOPAINT
		SCREENS[id](inner, f)
	end
	f.SelectTab = f.Go
	f.Go(screen or "home")
	return f
end

net.Receive("rmpg_menu", function()
	if IsValid(RMPG.MenuFrame) then
		RMPG.MenuFrame:Close()
	elseif not (RMPG.Radial and RMPG.Radial.IsOpen) then
		RMPG.OpenMenu()
	end
end)

concommand.Add("rmpg_menu", function(_, _, args)
	RMPG.OpenMenu(args[1])
end)
