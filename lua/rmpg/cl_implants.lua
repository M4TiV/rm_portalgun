-- Client: implants. The emergency evacuation's hologram - the body slices away into blue light where it stood and builds
-- up again a metre or two off - and the Implants tab of the C menu, where you choose which implant answers first.
RMPG = RMPG or {}
local UI = RMPG.UI
local M = RMPG.Mat

local ORDER = CreateClientConVar("rmpg_implant_order", "shield,evac", true, true, "Which implant answers damage first")
local KEY = CreateClientConVar("rmpg_bind_implants", tostring(MOUSE_MIDDLE), true, false, "Button that holds the implants' wheel open")
local FIRE = CreateClientConVar("rmpg_bind_implant_fire", tostring(KEY_H), true, false, "Button that fires a shot of the Akira Laser in combat mode")
local POWER = CreateClientConVar("rmpg_bind_implant_power", tostring(KEY_Y), true, false, "Button of the Akira Laser's big burst in combat mode")
local GRAB = CreateClientConVar("rmpg_bind_tentacle_grab", tostring(MOUSE_MIDDLE), true, false, "Button that makes the tentacle take hold of something or let it go")
local CLONE_KEY = CreateClientConVar("rmpg_bind_prime_clone", tostring(KEY_K), true, false, "Button that makes a body of yourself (Rick Prime chip)")
local SWAP_KEY = CreateClientConVar("rmpg_bind_prime_swap", tostring(KEY_L), true, false, "Button that moves your mind into your next body (Rick Prime chip)")
local HOOK_KEY = CreateClientConVar("rmpg_bind_tentacle_hook", tostring(KEY_J), true, false, "Button of the tentacle's hook")
local LIFE, BUILD = 0.55, 0.4
local HEIGHT = 76
local BLUE = Color(90, 200, 255)
local UP = Vector(0, 0, 1)
local BG = Color(3, 12, 18, 225)
local TEXT = Color(225, 245, 255)
local MUTED = Color(130, 180, 205)

local HOLO = Material("rmpg/fx_holo")
local PIXEL = Material("rmpg/fx_pixel")
local ghosts, flash = {}, -10
local drawing = false

---------------------------------------------------------------------------
-- The hologram
---------------------------------------------------------------------------

local function Pixels(pos, n)
	if not RMPG.CL.particles:GetBool() then return end
	local em = ParticleEmitter(pos, false)
	if not em then return end
	for _ = 1, n do
		local p = em:Add(PIXEL, pos + Vector(math.Rand(-14, 14), math.Rand(-14, 14), math.Rand(0, HEIGHT)))
		if p then
			p:SetVelocity(VectorRand() * 26 + UP * math.Rand(10, 70))
			p:SetDieTime(math.Rand(0.3, 0.8))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(0.8, 2.4))
			p:SetEndSize(0.3)
			p:SetColor(BLUE.r, BLUE.g, BLUE.b)
		end
	end
	em:Finish()
end

net.Receive("rmpg_evac_fx", function()
	local ply = net.ReadEntity()
	local from, to = net.ReadVector(), net.ReadVector()
	if not IsValid(ply) then return end
	local now = CurTime()
	-- a copy of the body where it was, in the same pose
	local g = ClientsideModel(ply:GetModel(), RENDERGROUP_TRANSLUCENT)
	if IsValid(g) then
		g:SetNoDraw(true)
		g:SetPos(from)
		g:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		g:SetSkin(ply:GetSkin())
		for i = 0, ply:GetNumBodyGroups() - 1 do g:SetBodygroup(i, ply:GetBodygroup(i)) end
		g:SetSequence(ply:GetSequence())
		g:SetCycle(ply:GetCycle())
		g:SetPlaybackRate(0)
		ghosts[#ghosts + 1] = { m = g, t = now, from = from, to = to }
	end
	ply.RMPG_EvacIn = now
	Pixels(from, 28)
	Pixels(to, 16)
	if ply == LocalPlayer() then flash = RealTime() end
end)

local function ScrollHolo()
	local m = Matrix()
	m:Translate(Vector(0, CurTime() * 2 % 1, 0))
	HOLO:SetMatrix("$basetexturetransform", m)
end

local function HoloDraw(e, z, keepBelow, alpha)
	render.EnableClipping(true)
	if keepBelow then
		render.PushCustomClipPlane(-UP, -z) -- what is above z is gone
	else
		render.PushCustomClipPlane(UP, z)
	end
	render.SuppressEngineLighting(true)
	render.MaterialOverride(HOLO)
	render.SetColorModulation(BLUE.r / 255, BLUE.g / 255, BLUE.b / 255)
	render.SetBlend(alpha)
	e:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
	render.SuppressEngineLighting(false)
	render.PopCustomClipPlane()
	render.EnableClipping(false)
end

hook.Add("PostDrawTranslucentRenderables", "rmpg_evac", function(depth, sky)
	if depth or sky or #ghosts == 0 then return end
	ScrollHolo()
	local now = CurTime()
	for i = #ghosts, 1, -1 do
		local g = ghosts[i]
		local k = (now - g.t) / LIFE
		if k >= 1 or not IsValid(g.m) then
			if IsValid(g.m) then g.m:Remove() end
			table.remove(ghosts, i)
		else
			-- sliced away from the top, and a streak of light to where it went
			HoloDraw(g.m, g.from.z + HEIGHT * (1 - k), true, 0.9 * (1 - k * 0.5))
			render.SetMaterial(M.beam)
			local a, b = g.from + UP * 40, g.to + UP * 40
			render.DrawBeam(a, LerpVector(math.min(k * 3, 1), a, b), 7 * (1 - k), 0, 1, Color(BLUE.r, BLUE.g, BLUE.b, 220 * (1 - k)))
		end
	end
end)

-- Where it went: the body builds up from the feet, with the hologram over it
hook.Add("PostPlayerDraw", "rmpg_evac", function(ply)
	if drawing or not ply.RMPG_EvacIn then return end
	local k = (CurTime() - ply.RMPG_EvacIn) / BUILD
	if k >= 1 then
		ply.RMPG_EvacIn = nil
		return
	end
	drawing = true
	ScrollHolo()
	HoloDraw(ply, ply:GetPos().z + HEIGHT * k, true, 0.85)
	drawing = false
end)

hook.Add("HUDPaint", "rmpg_evac", function()
	local me = LocalPlayer()
	local a = 1 - (RealTime() - flash) / 0.3
	if a > 0 then
		surface.SetDrawColor(BLUE.r, BLUE.g, BLUE.b, 110 * a)
		surface.DrawRect(0, 0, ScrW(), ScrH())
		-- broken scanlines while you are nowhere
		surface.SetDrawColor(220, 245, 255, 90 * a)
		for y = 0, ScrH(), 9 do
			if (y * 7 + math.floor(RealTime() * 60)) % 5 == 0 then surface.DrawRect(0, y, ScrW(), 2) end
		end
	end
	if not IsValid(me) or not me:Alive() or not RMPG.HasEvacLocal(me) or not RMPG.CL.hud:GetBool() then return end
	local w, h = 300, 44
	local x, y = 28, ScrH() - h - (me:GetNW2Bool("RMPG_Shield", false) and 220 or 150)
	local back = me:GetNW2Float("RMPG_EvacBack", 0)
	RMPG.HoloBox(x, y, w, h, Color(3, 14, 22, 215), BLUE)
	RMPG.HoloText(RMPG.T("hud_evac"), "RMPG_SmallB", x + 12, y + 6, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local f
	if back > 0 then
		local left = math.max(back - CurTime(), 0)
		f = 1 - left / math.max(RMPG.CV.evacRegen:GetFloat(), 1)
		RMPG.HoloText(string.format("%d:%02d", left / 60, left % 60), "RMPG_SmallB", x + w - 12, y + 6, Color(255, 120, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	else
		local n = me:GetNW2Int("RMPG_EvacLeft", 0)
		f = n / math.max(RMPG.CV.evacCharges:GetInt(), 1)
		RMPG.HoloText(n .. " / " .. RMPG.CV.evacCharges:GetInt(), "RMPG_SmallB", x + w - 12, y + 6, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
	surface.SetDrawColor(10, 30, 40, 230)
	surface.DrawRect(x + 12, y + 26, w - 24, 8)
	surface.SetDrawColor(back > 0 and Color(255, 120, 100) or BLUE)
	surface.DrawRect(x + 12, y + 26, (w - 24) * math.Clamp(f, 0, 1), 8)
end)

function RMPG.HasEvacLocal(ply)
	return ply:GetNW2Bool("RMPG_Evac", false)
end

function RMPG.HasImplants(ply)
	return IsValid(ply) and (ply:GetNW2Bool("RMPG_Evac", false) or ply:GetNW2Bool("RMPG_Shield", false) or ply:GetNW2Bool("RMPG_Arm", false) or ply:GetNW2Bool("RMPG_Tent", false) or ply:GetNW2Bool("RMPG_Prime", false))
end

---------------------------------------------------------------------------
-- The Implants tab of the C menu
---------------------------------------------------------------------------

local INFO = {
	shield = { "impl_shield", "impl_shield_d", "entities/rmpg_shield_chip.png", "RMPG_Shield", "rmpg_shield_remove" },
	evac = { "impl_evac", "impl_evac_d", "entities/rmpg_evac_chip.png", "RMPG_Evac", "rmpg_evac_remove" },
}

local function Order()
	local out, seen = {}, {}
	for id in string.gmatch(ORDER:GetString(), "[^,]+") do
		if INFO[id] and not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	for _, id in ipairs({ "shield", "evac" }) do
		if not seen[id] then out[#out + 1] = id end
	end
	return out
end

-- What it is doing right now, in a few words
local function State(id)
	local me = LocalPlayer()
	if not me:GetNW2Bool(INFO[id][4], false) then return RMPG.T("impl_none"), Color(150, 150, 150) end
	if id == "shield" then
		if me:GetNW2Float("RMPG_ShieldBack", 0) > 0 then return RMPG.T("impl_down"), Color(255, 110, 100) end
		return math.floor(me:GetNW2Float("RMPG_ShieldPct", 100)) .. " %", Color(120, 255, 170)
	end
	if me:GetNW2Float("RMPG_EvacBack", 0) > 0 then return RMPG.T("impl_down"), Color(255, 110, 100) end
	return me:GetNW2Int("RMPG_EvacLeft", 0) .. " / " .. RMPG.CV.evacCharges:GetInt(), Color(120, 255, 170)
end

function RMPG.ImplantsTab(sheet)
	local p = vgui.Create("DPanel", sheet)
	p.Paint = function(s, w, h)
		surface.SetDrawColor(BG)
		surface.DrawRect(0, 0, w, h)
	end
	local hint = vgui.Create("DLabel", p)
	hint:Dock(TOP)
	hint:DockMargin(14, 10, 14, 6)
	hint:SetWrap(true)
	hint:SetAutoStretchVertical(true)
	hint:SetFont("RMPG_Body")
	hint:SetTextColor(TEXT)
	hint:SetText(RMPG.T("impl_hint"))

	-- the chain: what a hit goes through, in order
	local chain = vgui.Create("DPanel", p)
	chain:Dock(TOP)
	chain:SetTall(54)
	chain:DockMargin(14, 2, 14, 8)
	chain.Paint = function(s, w, h)
		local names = { RMPG.T("impl_hit") }
		for _, id in ipairs(Order()) do names[#names + 1] = RMPG.T(INFO[id][1]) end
		names[#names + 1] = RMPG.T("impl_health")
		local n = #names
		local gap, bw = 26, 0
		bw = (w - gap * (n - 1)) / n
		for i, name in ipairs(names) do
			local x = (i - 1) * (bw + gap)
			local edge = i == 1 and Color(255, 110, 100) or (i == n and Color(120, 255, 170) or BLUE)
			RMPG.HoloBox(x, 6, bw, h - 12, Color(4, 22, 32, 240), edge)
			draw.SimpleText(name, "RMPG_SmallB", x + bw / 2, h / 2, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if i < n then draw.SimpleText(">", "RMPG_Head", x + bw + gap / 2, h / 2, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
		end
	end

	local list = UI.Scroll(p)
	list:Dock(FILL)
	list:DockMargin(14, 0, 10, 10)
	local Refresh

	local function Move(i, d)
		local o = Order()
		o[i], o[i + d] = o[i + d], o[i]
		ORDER:SetString(table.concat(o, ","))
		timer.Simple(0, Refresh)
	end

	Refresh = function()
		if not IsValid(list) then return end
		list:Clear()
		local order = Order()
		for i, id in ipairs(order) do
			local info = INFO[id]
			local card = vgui.Create("DPanel", list)
			card:Dock(TOP)
			card:DockMargin(0, 0, 8, 8)
			card:SetTall(96)
			local icon = Material(info[3], "smooth")
			card.Paint = function(s, w, h)
				RMPG.HoloBox(0, 0, w, h, Color(4, 20, 30, 240), BLUE)
				draw.SimpleText(tostring(i), "RMPG_Big", 34, h / 2, BLUE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				surface.SetMaterial(icon)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(66, 14, 68, 68)
				RMPG.HoloText(RMPG.T(info[1]), "RMPG_BodyB", 148, 12, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText(RMPG.T(info[2]), "RMPG_Small", 148, 38, MUTED)
				local st, col = State(id)
				draw.SimpleText(st, "RMPG_SmallB", 148, 62, col)
			end
			local side = vgui.Create("DPanel", card)
			side:Dock(RIGHT)
			side:SetWide(124)
			side:DockMargin(0, 6, 8, 6)
			side.Paint = function() end
			local out = RMPG.ImplantOutButton(card, id, info[4])
			out:Dock(RIGHT)
			out:DockMargin(0, 26, 8, 26)
			if i > 1 then
				local up = UI.Button(side, RMPG.T("impl_up"), "dark", function() Move(i, -1) end, "icon16/arrow_up.png")
				up:Dock(TOP)
				up:SetTall(38)
				up:DockMargin(0, 0, 0, 4)
			end
			if i < #order then
				local down = UI.Button(side, RMPG.T("impl_down_btn"), "dark", function() Move(i, 1) end, "icon16/arrow_down.png")
				down:Dock(TOP)
				down:SetTall(38)
			end
		end
		local rem = UI.Button(list, RMPG.T("impl_reset"), "tile", function()
			ORDER:SetString("shield,evac")
			timer.Simple(0, Refresh)
		end, "icon16/arrow_undo.png")
		rem:Dock(TOP)
		rem:SetTall(38)
		rem:DockMargin(0, 4, 8, 0)
		RMPG.ImplantWeaponsUI(list)
	end
	Refresh()
	sheet:AddSheet(RMPG.T("impl_tab"), p, "icon16/heart.png")
end

---------------------------------------------------------------------------
-- The weapon implants: their part of the tab, the wheel, the fire button, the beam
---------------------------------------------------------------------------

local GOLD = Color(255, 214, 80)
local STEEL = Color(176, 196, 222)
local LASER = Material("entities/rmpg_arm_chip.png", "smooth")
local TENT = Material("entities/rmpg_tentacle_chip.png", "smooth")
local PRIME = Material("entities/rmpg_prime_chip.png", "smooth")

local function SendAction(a, write)
	net.Start("rmpg_implant")
	net.WriteUInt(a, RMPG.IMPL_BITS)
	if write then write() end
	net.SendToServer()
end

-- "Take out": enabled while the implant is in; the chip falls out in front of you (sv_implants.lua)
function RMPG.ImplantOutButton(parent, id, nw)
	local b = UI.Button(parent, RMPG.T("impl_out"), "danger", function()
		net.Start("rmpg_implant_out")
		net.WriteString(id)
		net.SendToServer()
	end, "icon16/arrow_out.png")
	b:SetWide(120)
	b:SetTooltip(RMPG.T("impl_out_tip"))
	b.Think = function(s)
		local on = LocalPlayer():GetNW2Bool(nw, false)
		if s:IsEnabled() ~= on then s:SetEnabled(on) end
	end
	return b
end

local function WeaponCard(parent, title, line, col, icon)
	local card = vgui.Create("DPanel", parent)
	card:Dock(TOP)
	card:DockMargin(0, 0, 8, 8)
	card:SetTall(84)
	card.Paint = function(s, w, h)
		RMPG.HoloBox(0, 0, w, h, Color(4, 20, 30, 240), col)
		if icon then
			surface.SetMaterial(icon)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(12, 8, 68, 68)
		end
		RMPG.HoloText(title, "RMPG_BodyB", 94, 14, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(isfunction(line) and line() or line, "RMPG_Small", 94, 44, col)
	end
	return card
end

local function BindRow(parent, label, cv)
	local row = vgui.Create("DPanel", parent)
	row:Dock(TOP)
	row:SetTall(38)
	row:DockMargin(0, 6, 8, 0)
	row.Paint = function(s, w, h) draw.SimpleText(label, "RMPG_Small", 4, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
	local b = vgui.Create("DBinder", row)
	b:Dock(RIGHT)
	b:SetWide(180)
	b:SetSelectedNumber(cv:GetInt())
	b.OnChange = function(s, num) cv:SetInt(num) end
end

function RMPG.ImplantWeaponsUI(list)
	UI.Header(list, RMPG.T("impl_weapons")):Dock(TOP)
	local me = LocalPlayer()
	local function Out(card, id, nw)
		local b = RMPG.ImplantOutButton(card, id, nw)
		b:Dock(RIGHT)
		b:DockMargin(0, 22, 10, 22)
	end
	Out(WeaponCard(list, RMPG.T("arm_name"), function()
		if not me:GetNW2Bool("RMPG_Arm", false) then return RMPG.T("impl_none") end
		return RMPG.T(me:GetNW2Float("RMPG_ArmBack", 0) > CurTime() and "impl_down" or "arm_ready")
	end, GOLD, LASER), "arm", "RMPG_Arm")
	Out(WeaponCard(list, RMPG.T("tent_name"), function()
		return RMPG.T(me:GetNW2Bool("RMPG_Tent", false) and "tent_ready" or "impl_none")
	end, STEEL, TENT), "tent", "RMPG_Tent")
	Out(WeaponCard(list, RMPG.T("prime_name"), function()
		if not me:GetNW2Bool("RMPG_Prime", false) then return RMPG.T("impl_none") end
		local back = me:GetNW2Float("RMPG_PrimeBack", 0) - CurTime()
		return back > 0 and RMPG.T("prime_wait", math.ceil(back)) or RMPG.T("prime_ready")
	end, Color(235, 80, 80), PRIME), "prime", "RMPG_Prime")
	local b = UI.Button(list, function() return RMPG.T(me:GetNW2Bool("RMPG_Combat", false) and "impl_combat_off" or "impl_combat_on") end, "accent", function()
		if not RMPG.HasImplants(me) then
			RMPG.AddNote(RMPG.T("impl_no_chip"), 1)
			return
		end
		SendAction(me:GetNW2Bool("RMPG_Combat", false) and RMPG.IMPL_OFF or RMPG.IMPL_ON)
	end, "icon16/lightning.png")
	b:Dock(TOP)
	b:SetTall(40)
	b:DockMargin(0, 2, 8, 0)
	BindRow(list, RMPG.T("impl_bind_wheel"), KEY)
	BindRow(list, RMPG.T("impl_bind_fire"), FIRE)
	BindRow(list, RMPG.T("impl_bind_power"), POWER)
	BindRow(list, RMPG.T("impl_bind_grab"), GRAB)
	BindRow(list, RMPG.T("impl_bind_hook"), HOOK_KEY)
	BindRow(list, RMPG.T("impl_bind_clone"), CLONE_KEY)
	BindRow(list, RMPG.T("impl_bind_swap"), SWAP_KEY)
end

local Wheel = {}
RMPG.ImplantWheel = Wheel
local THEME = { slice = Color(6, 28, 42, 220), hover = Color(28, 120, 180, 240), current = Color(150, 112, 20, 235), edge = Color(2, 10, 16, 235) }
local ICONS = {}
local function Icon(path)
	ICONS[path] = ICONS[path] or Material(path)
	return ICONS[path]
end

local function InCombat()
	return LocalPlayer():GetNW2Bool("RMPG_Combat", false)
end

local ITEMS = {
	on = { "impl_combat_on", "icon16/lightning.png", function() SendAction(RMPG.IMPL_ON) end },
	arm = { "arm_name", nil, function()
		if LocalPlayer():GetNW2Bool("RMPG_Arm", false) then
			SendAction(RMPG.IMPL_FIRE)
		else
			RMPG.AddNote(RMPG.T("impl_no_chip"), 1)
		end
	end },
	tent = { "tent_name", nil, function()
		if LocalPlayer():GetNW2Bool("RMPG_Tent", false) then
			SendAction(RMPG.IMPL_GRAB)
		else
			RMPG.AddNote(RMPG.T("impl_no_chip"), 1)
		end
	end },
	off = { "impl_combat_off", "icon16/cross.png", function() SendAction(RMPG.IMPL_OFF) end },
}

local function Describe(id)
	local it = ITEMS[id]
	if not it then return end
	local cover = (id == "arm" and LASER) or (id == "tent" and TENT) or nil
	return RMPG.T(it[1]), cover or Icon(it[2]), it[3], function()
		local me = LocalPlayer()
		if id == "arm" then return me:GetNW2Bool("RMPG_ArmOn", false) end
		return id == "tent" and RMPG.TentMode(me) ~= 0
	end, cover and 72 or nil
end

function Wheel.Open(sticky)
	if Wheel.IsOpen then return end
	Wheel.IsOpen = true
	Wheel.Sticky = sticky
	Wheel.Ids = InCombat() and { "arm", "tent", "off" } or { "on" }
	Wheel.Hover = nil
	Wheel.Opened = RealTime()
	gui.EnableScreenClicker(true)
	input.SetCursorPos(ScrW() / 2, ScrH() / 2)
	if RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiOpen) end
end

function Wheel.Close(run)
	if not Wheel.IsOpen then return end
	Wheel.IsOpen = false
	gui.EnableScreenClicker(false)
	Wheel.BlockAttack = true
	if run and Wheel.Hover then
		local _, _, fn = Describe(Wheel.Ids[Wheel.Hover])
		if fn then fn() end
		if RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiClick) end
	elseif RMPG.CL.uisounds:GetBool() then
		surface.PlaySound(RMPG.SND.uiClose)
	end
end

hook.Add("HUDPaint", "rmpg_implant_wheel", function()
	if not Wheel.IsOpen then return end
	local cx, cy = ScrW() / 2, ScrH() / 2
	local mx, my = input.GetCursorPos()
	local dx, dy = mx - cx, my - cy
	local ids = Wheel.Ids
	local n = #ids
	Wheel.Hover = nil
	if dx * dx + dy * dy > 45 * 45 then
		local step = math.pi * 2 / n
		Wheel.Hover = math.floor(((math.atan2(dy, dx) + math.pi / 2 + step / 2) % (math.pi * 2)) / step) + 1
	end
	local k = math.Clamp((RealTime() - Wheel.Opened) / 0.12, 0, 1)
	surface.SetMaterial(RMPG.Mat.glow2D)
	surface.SetDrawColor(GOLD.r, GOLD.g, GOLD.b, 50 * k)
	surface.DrawTexturedRect(cx - 360, cy - 360, 720, 720)
	RMPG.Radial.DrawWheel(cx, cy, 0.85 + 0.15 * k, ids, Wheel.Hover, k, Describe, THEME)
	local title = Wheel.Hover and Describe(ids[Wheel.Hover]) or RMPG.T("impl_wheel")
	draw.SimpleTextOutlined(title, "RMPG_Head", cx, cy + 249, Color(255, 255, 255, 255 * k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 12, 20, 220 * k))
end)

local prevHeld, lmbPrev, rmbPrev, firePrev, grabPrev, hookPrev = false, false, false, false, false, false
local powerPrev = false
local tapAt
local clonePrev, swapPrev = false, false
local chatOpen = false
hook.Add("StartChat", "rmpg_implants", function() chatOpen = true end)
hook.Add("FinishChat", "rmpg_implants", function() chatOpen = false end)

hook.Add("Think", "rmpg_implant_keys", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	if not RMPG.HasImplants(me) or not me:Alive() then
		if Wheel.IsOpen then Wheel.Close(false) end
		return
	end
	-- with the Q or C menu (or any window with a cursor) open the mouse buttons belong to it, the wheel stays shut
	local typing = chatOpen or gui.IsGameUIVisible() or IsValid(vgui.GetKeyboardFocus()) or IsValid(RMPG.MenuFrame) or vgui.CursorVisible()
	local held = RMPG.IsBindHeld(KEY:GetInt())
	-- with the portal gun or the eyepatch this button opens their wheel, and there this one is a slice
	local taken = RMPG.Radial.LocalGun() ~= nil or me:GetNW2Bool("RMPG_Patch", false)
	local hasTent = me:GetNW2Bool("RMPG_Tent", false)
	-- on the wheel's own button a short press takes hold, a long one still opens the wheel
	local tap = hasTent and InCombat() and GRAB:GetInt() == KEY:GetInt() and not taken
	if held and not prevHeld and not typing and not taken and not RMPG.Radial.IsOpen then
		if tap then tapAt = RealTime() else Wheel.Open(false) end
	elseif not held and prevHeld and Wheel.IsOpen and not Wheel.Sticky then
		Wheel.Close(true)
	end
	if tapAt then
		if not held then
			tapAt = nil
			SendAction(RMPG.IMPL_GRAB)
		elseif RealTime() - tapAt > 0.25 then
			tapAt = nil
			Wheel.Open(false)
		end
	end
	prevHeld = held
	if hasTent and GRAB:GetInt() ~= KEY:GetInt() then
		local g = RMPG.IsBindHeld(GRAB:GetInt()) and not typing
		if g and not grabPrev then SendAction(RMPG.IMPL_GRAB) end
		grabPrev = g
	end
	local h = RMPG.IsBindHeld(HOOK_KEY:GetInt()) and not typing
	if h ~= hookPrev and hasTent then
		hookPrev = h
		SendAction(RMPG.IMPL_HOOK, function() net.WriteBool(h) end)
	end
	-- Rick Prime's chip: these work with or without combat mode
	local prime = me:GetNW2Bool("RMPG_Prime", false)
	local c = prime and RMPG.IsBindHeld(CLONE_KEY:GetInt()) and not typing
	if c and not clonePrev then SendAction(RMPG.IMPL_CLONE) end
	clonePrev = c
	local s = prime and RMPG.IsBindHeld(SWAP_KEY:GetInt()) and not typing
	if s and not swapPrev then SendAction(RMPG.IMPL_SWAP) end
	swapPrev = s
	local lmb, rmb = input.IsMouseDown(MOUSE_LEFT), input.IsMouseDown(MOUSE_RIGHT)
	if Wheel.IsOpen then
		if lmb and not lmbPrev then
			Wheel.Close(true)
		elseif rmb and not rmbPrev then
			Wheel.Close(false)
		end
	end
	lmbPrev, rmbPrev = lmb, rmb
	-- the laser: one press, one shot; its other button, one press, one burst
	local fire = RMPG.IsBindHeld(FIRE:GetInt()) and not typing and me:GetNW2Bool("RMPG_Arm", false)
	if fire and not firePrev then SendAction(RMPG.IMPL_FIRE) end
	firePrev = fire
	local power = RMPG.IsBindHeld(POWER:GetInt()) and not typing and me:GetNW2Bool("RMPG_Arm", false)
	if power and not powerPrev then SendAction(RMPG.IMPL_POWER) end
	powerPrev = power
end)

hook.Add("CreateMove", "rmpg_implant_wheel", function(cmd)
	if Wheel.IsOpen then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	elseif Wheel.BlockAttack then
		if input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT) then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
		else
			Wheel.BlockAttack = false
		end
	end
end)

local function KeyText(cv)
	return string.upper(input.GetKeyName(cv:GetInt()) or "?")
end

-- In combat mode: every implant with its buttons, and how far the laser has recharged
hook.Add("HUDPaint", "rmpg_combat", function()
	local me = LocalPlayer()
	if not IsValid(me) or not me:Alive() or not InCombat() or not RMPG.CL.hud:GetBool() then return end
	local arm, tent = me:GetNW2Bool("RMPG_Arm", false), me:GetNW2Bool("RMPG_Tent", false)
	local w, h = 300, 32 + (arm and 62 or 0) + (tent and 24 or 0)
	local x, y = 28, ScrH() - h - 290
	RMPG.HoloBox(x, y, w, h, Color(20, 16, 4, 215), GOLD)
	RMPG.HoloText(RMPG.T("hud_combat"), "RMPG_SmallB", x + 12, y + 6, GOLD, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local row = y + 28
	if arm then
		draw.SimpleText(RMPG.T("arm_shot"), "RMPG_Small", x + 12, row, TEXT)
		RMPG.HoloText(KeyText(FIRE), "RMPG_SmallB", x + w - 12, row, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		row = row + 22
		draw.SimpleText(RMPG.T("arm_power"), "RMPG_Small", x + 12, row, TEXT)
		RMPG.HoloText(KeyText(POWER), "RMPG_SmallB", x + w - 12, row, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		local now = CurTime()
		local on = me:GetNW2Bool("RMPG_ArmOn", false)
		local back = me:GetNW2Float("RMPG_ArmBack", 0)
		local f = 1
		if on then
			f = 1 - (now - me:GetNW2Float("RMPG_ArmT", 0)) / math.max(RMPG.CV.armTime:GetFloat(), 0.1)
		elseif back > now then
			f = 1 - (back - now) / math.max(RMPG.CV.armCool:GetFloat(), 0.1)
		end
		surface.SetDrawColor(30, 24, 8, 230)
		surface.DrawRect(x + 12, row + 22, w - 24, 8)
		surface.SetDrawColor((back > now and not on) and Color(255, 120, 100) or GOLD)
		surface.DrawRect(x + 12, row + 22, (w - 24) * math.Clamp(f, 0, 1), 8)
		row = row + 40
	end
	if tent then
		draw.SimpleText(RMPG.T("tent_name"), "RMPG_Small", x + 12, row, TEXT)
		RMPG.HoloText(KeyText(GRAB) .. " / " .. KeyText(HOOK_KEY), "RMPG_SmallB", x + w - 12, row, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
end)

-- Where the beam leaves the hand: the open palm on the viewmodel in first person, the right hand otherwise
local function ArmStart(ply)
	if RMPG.FirstPerson(ply) then
		local w = ply:GetActiveWeapon()
		local vm = ply:GetViewModel()
		local b = IsValid(vm) and vm:LookupBone("ValveBiped.Bip01_L_Hand")
		local m = b and vm:GetBoneMatrix(b)
		if IsValid(w) and m then return RMPG.VMToWorld(m:GetTranslation() + m:GetForward() * 3, w.ViewModelFOV) end
		return ply:GetShootPos() - ply:EyeAngles():Up() * 8
	end
	local b = ply:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = b and ply:GetBoneMatrix(b)
	return m and m:GetTranslation() + m:GetForward() * 5 or ply:GetShootPos()
end

RMPG.ArmStart = ArmStart

local function BeamLayer(from, to, dir, width, col)
	local len = from:Distance(to)
	render.StartBeam(3)
	render.AddBeam(from, width * 0.15, 0, col)
	render.AddBeam(from + dir * math.min(150, len * 0.5), width, 0.1, col)
	render.AddBeam(to, width, 1, col)
	render.EndBeam()
end

hook.Add("PostDrawTranslucentRenderables", "rmpg_arm_beam", function(depth, sky)
	if depth or sky then return end
	for _, ply in ipairs(player.GetAll()) do
		if ply:GetNW2Bool("RMPG_ArmOn", false) and ply:Alive() then
			local src = ply:GetShootPos()
			local tr = util.TraceLine({ start = src, endpos = src + ply:GetAimVector() * RMPG.CV.armRange:GetFloat(), mask = MASK_SOLID_BRUSHONLY })
			local from, to = ArmStart(ply), tr.HitPos
			local dir = (to - from):GetNormalized()
			-- the burst: it bursts out wider than the beam, settles, and is gone in a moment at the end
			local age = CurTime() - ply:GetNW2Float("RMPG_ArmT", 0)
			local surge = math.exp(-age * 5)
			local env = math.Clamp(age / 0.08, 0, 1) * math.Clamp((RMPG.CV.armTime:GetFloat() - age) / 0.25, 0, 1)
			local w = RMPG.CV.armRadius:GetFloat() * 2 * env * (1 + surge * 0.7) * (1 + math.sin(CurTime() * 40) * 0.05)
			render.SetMaterial(M.beam)
			BeamLayer(from, to, dir, w * 1.3, Color(255, 190, 40, 200))
			BeamLayer(from, to, dir, w, Color(255, 225, 70, 255))
			BeamLayer(from, to, dir, w * 0.45, Color(255, 250, 215, 255))
			render.SetMaterial(M.glow)
			render.DrawSprite(from, 34 + 200 * surge, 34 + 200 * surge, Color(255, 235, 150, 255))
			render.DrawSprite(to, w * 3.2, w * 3.2, Color(255, 215, 90, 255))
			-- yellow, not so bright that the wall turns white
			local dl = DynamicLight(ply:EntIndex() + 5000)
			if dl then
				dl.pos = to + tr.HitNormal * 20
				dl.r, dl.g, dl.b = 255, 200, 60
				dl.brightness = 2
				dl.size = 320
				dl.decay = 1500
				dl.dietime = CurTime() + 0.15
			end
		end
	end
end)

