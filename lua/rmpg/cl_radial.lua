-- Client: radial quick menu (hold the mouse wheel) and rebindable key actions
RMPG = RMPG or {}
RMPG.Radial = RMPG.Radial or {}
local Radial = RMPG.Radial

Radial.MAX = 12
local FILE = "rmpg/radial.json"
local DEFAULT = { "mode:random", "mode:quick", "mode:manual", "mode:player", "mode:trap", "act:close", "act:vertical", "act:reload", "act:menu" }

local ICONS = {}
local function Icon(path)
	ICONS[path] = ICONS[path] or Material(path)
	return ICONS[path]
end

local function LocalGun()
	local ply = LocalPlayer()
	if not IsValid(ply) then return nil end
	local w = ply:GetActiveWeapon()
	if IsValid(w) and w:GetClass() == RMPG.WEAPON then return w end
	return nil
end
Radial.LocalGun = LocalGun

---------------------------------------------------------------------------
-- Items that can be put on the wheel
---------------------------------------------------------------------------

local function FindLocation(id)
	local code, name = string.match(id, "^loc:(.-)|(.*)$")
	for i, loc in ipairs(RMPG.Locations) do
		if loc.code == code and loc.name == name then return loc, i end
	end
end

function RMPG.ToggleVertical()
	local cv = RMPG.CL.vertical
	cv:SetBool(not cv:GetBool())
	RMPG.AddNote(RMPG.T(cv:GetBool() and "n_vertical_on" or "n_vertical_off"), 0)
end

function RMPG.Action(name)
	net.Start("rmpg_action")
	net.WriteString(name)
	net.SendToServer()
end

local ACTIONS = {
	["mode:random"] = { "act_random", "icon16/arrow_rotate_clockwise.png", function() RMPG.SendDest(RMPG.DEST_RANDOM) end, RMPG.DEST_RANDOM },
	["mode:quick"] = { "act_quick", "icon16/lightning_go.png", function() RMPG.SendDest(RMPG.DEST_QUICK) end, RMPG.DEST_QUICK },
	["mode:manual"] = { "act_manual", "icon16/arrow_switch.png", function() RMPG.SendDest(RMPG.DEST_MANUAL) end, RMPG.DEST_MANUAL },
	["mode:player"] = { "act_player", "icon16/user_green.png", function()
		if IsValid(RMPG.SelectedPlayer) then RMPG.SendDest(RMPG.DEST_PLAYER, RMPG.SelectedPlayer) else RMPG.OpenMenu("players") end
	end, RMPG.DEST_PLAYER },
	["mode:trap"] = { "act_trap", "icon16/arrow_in.png", function() RMPG.SendDest(RMPG.DEST_TRAP) end, RMPG.DEST_TRAP },
	["mode:chain"] = { "act_chain", "icon16/link.png", function() RMPG.SendDest(RMPG.DEST_CHAIN) end, RMPG.DEST_CHAIN },
	["mode:coords"] = { "act_coords", "icon16/map_go.png", function()
		local c = RMPG.CoordsLoad and RMPG.CoordsLoad()
		if c then RMPG.SendDest(RMPG.DEST_COORDS, c) else RMPG.OpenMenu("coords") end
	end, RMPG.DEST_COORDS },
	["act:maps"] = { "act_maps", "icon16/world_go.png", function() RMPG.OpenMenu("maps") end, RMPG.DEST_MAP },
	["act:close"] = { "act_close", "icon16/cancel.png", function() RMPG.Action("close") end },
	["act:vertical"] = { "act_vertical", "icon16/door.png", function() RMPG.ToggleVertical() end },
	["act:reload"] = { "act_reload", "icon16/drink.png", function() RMPG.Action("reload") end },
	["act:menu"] = { "act_menu", "icon16/application_view_tile.png", function() RMPG.OpenMenu() end },
	-- the way into the eyepatch's wheel while the portal gun is in hand (only shown with the patch on)
	["act:patch"] = { "act_patch", "icon16/eye.png", function() RMPG.PatchWheel.Open(true) end },
	-- and into the implants' wheel, once there is an implant
	["act:implants"] = { "impl_wheel", "icon16/lightning.png", function() RMPG.ImplantWheel.Open(true) end },
}
Radial.ActionIds = { "mode:random", "mode:quick", "mode:manual", "mode:player", "mode:trap", "mode:chain", "mode:coords", "act:maps", "act:close", "act:vertical", "act:reload", "act:menu" }

-- label, icon material, run function, is-current check
function Radial.Describe(id)
	local a = ACTIONS[id]
	if a then
		return RMPG.T(a[1]), Icon(a[2]), a[3], function()
			if a[4] then
				local w = LocalGun()
				return w ~= nil and w:GetDestMode() == a[4]
			end
			if id == "act:vertical" then return RMPG.CL.vertical:GetBool() end
			return false
		end
	end
	local loc, i = FindLocation(id)
	if loc then
		return (loc.code or "") .. " " .. (loc.name or ""), Icon("icon16/flag_green.png"), function()
			RMPG.SelectedLoc = i
			RMPG.SendDest(RMPG.DEST_LOCATION, loc)
		end, function()
			local w = LocalGun()
			return w ~= nil and w:GetDestMode() == RMPG.DEST_LOCATION and w:GetDestCode() == loc.code and w:GetDestLabel() == loc.name
		end
	end
end

function Radial.LocationId(loc)
	return "loc:" .. (loc.code or "") .. "|" .. (loc.name or "")
end

---------------------------------------------------------------------------
-- Layout storage
---------------------------------------------------------------------------

function Radial.Load()
	local raw = file.Read(FILE, "DATA")
	local t = raw and util.JSONToTable(raw)
	Radial.Items = istable(t) and t or table.Copy(DEFAULT)
end

function Radial.Save()
	file.CreateDir("rmpg")
	file.Write(FILE, util.TableToJSON(Radial.Items, true))
end

function Radial.Reset()
	Radial.Items = table.Copy(DEFAULT)
	Radial.Save()
end

-- Slices that can actually be shown (locations deleted since are skipped)
function Radial.Visible()
	local out = {}
	for _, id in ipairs(Radial.Items or {}) do
		if Radial.Describe(id) then out[#out + 1] = id end
	end
	if LocalPlayer():GetNW2Bool("RMPG_Patch") then out[#out + 1] = "act:patch" end
	if RMPG.HasImplants(LocalPlayer()) then out[#out + 1] = "act:implants" end
	return out
end

Radial.Load()

---------------------------------------------------------------------------
-- The wheel
---------------------------------------------------------------------------

local INNER, OUTER = 70, 215
local SLICE = Color(10, 46, 32, 215)
local SLICE_HOV = Color(36, 150, 90, 235)
local SLICE_CUR = Color(130, 20, 36, 230)
local EDGE = Color(2, 14, 10, 225)

function Radial.Open()
	if Radial.IsOpen then return end
	Radial.IsOpen = true
	Radial.Hover = nil
	Radial.Opened = RealTime()
	Radial.Ids = Radial.Visible()
	gui.EnableScreenClicker(true)
	input.SetCursorPos(ScrW() / 2, ScrH() / 2)
	if RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiOpen) end
end

function Radial.Close(run)
	if not Radial.IsOpen then return end
	Radial.IsOpen = false
	gui.EnableScreenClicker(false)
	Radial.BlockAttack = true
	if run and Radial.Hover then
		local _, _, fn = Radial.Describe(Radial.Ids[Radial.Hover])
		if fn then fn() end
		if RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiClick) end
	elseif RMPG.CL.uisounds:GetBool() then
		surface.PlaySound(RMPG.SND.uiClose)
	end
end

local function Sector(cx, cy, r0, r1, a0, a1, col)
	local steps = math.max(2, math.ceil((a1 - a0) / 0.12))
	draw.NoTexture()
	surface.SetDrawColor(col)
	for i = 0, steps - 1 do
		local b0 = a0 + (a1 - a0) * i / steps
		local b1 = a0 + (a1 - a0) * (i + 1) / steps
		surface.DrawPoly({
			{ x = cx + math.cos(b0) * r1, y = cy + math.sin(b0) * r1 },
			{ x = cx + math.cos(b1) * r1, y = cy + math.sin(b1) * r1 },
			{ x = cx + math.cos(b1) * r0, y = cy + math.sin(b1) * r0 },
			{ x = cx + math.cos(b0) * r0, y = cy + math.sin(b0) * r0 },
		})
	end
end

local function Circle(cx, cy, r, col)
	local pts = {}
	for i = 0, 39 do
		local a = i / 40 * math.pi * 2
		pts[#pts + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
	end
	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly(pts)
end

-- Draws a wheel for the given ids; also used by the setup screen preview, and with a describe function and colours of
-- its own by the eyepatch's wheel
function Radial.DrawWheel(cx, cy, scale, ids, hover, alpha, describe, theme)
	alpha = alpha or 1
	describe = describe or Radial.Describe
	local cSlice, cHover, cCur, cEdge = SLICE, SLICE_HOV, SLICE_CUR, EDGE
	if theme then cSlice, cHover, cCur, cEdge = theme.slice, theme.hover, theme.current, theme.edge end
	local n = #ids
	local r0, r1 = INNER * scale, OUTER * scale
	Circle(cx, cy, r1 + 8 * scale, Color(cEdge.r, cEdge.g, cEdge.b, 230 * alpha))
	if n == 0 then return end
	local step = math.pi * 2 / n
	for i, id in ipairs(ids) do
		local a0 = -math.pi / 2 + (i - 1.5) * step
		local a1 = a0 + step
		local label, icon, _, current, iconSize = describe(id)
		local col = (hover == i) and cHover or (current and current() and cCur or cSlice)
		local pad = 0.012
		Sector(cx, cy, r0, r1 + ((hover == i) and 6 * scale or 0), a0 + pad, a1 - pad, Color(col.r, col.g, col.b, col.a * alpha))
		local mid = (a0 + a1) / 2
		local mr = (r0 + r1) / 2
		local ix, iy = cx + math.cos(mid) * mr, cy + math.sin(mid) * mr
		if icon then
			surface.SetMaterial(icon)
			surface.SetDrawColor(255, 255, 255, 255 * alpha)
			local s = (iconSize or 24) * scale
			surface.DrawTexturedRect(ix - s / 2, iy - 10 * scale - s / 2, s, s)
		end
		if scale > 0.6 and label then
			if #label > 16 then label = string.sub(label, 1, 15) .. "…" end
			draw.SimpleTextOutlined(label, "RMPG_SmallB", ix, iy + 12 * scale, Color(255, 255, 255, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 20, 12, 200 * alpha))
		end
		if current and current() then
			Sector(cx, cy, r1 - 5 * scale, r1, a0 + pad, a1 - pad, Color(255, 70, 90, 230 * alpha))
		end
	end
	Circle(cx, cy, r0 - 6 * scale, Color(cEdge.r, cEdge.g, cEdge.b, 245 * alpha))
end

hook.Add("HUDPaint", "rmpg_radial", function()
	if not Radial.IsOpen then return end
	local cx, cy = ScrW() / 2, ScrH() / 2
	local ids = Radial.Ids or {}
	local mx, my = input.GetCursorPos()
	local dx, dy = mx - cx, my - cy
	local n = #ids
	Radial.Hover = nil
	if n > 0 and dx * dx + dy * dy > 45 * 45 then
		local a = math.atan2(dy, dx) + math.pi / 2
		local step = math.pi * 2 / n
		Radial.Hover = math.floor(((a + step / 2) % (math.pi * 2)) / step) + 1
	end
	if Radial.Hover ~= Radial.LastHover then
		Radial.LastHover = Radial.Hover
		if Radial.Hover and RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiHover) end
	end
	local k = math.Clamp((RealTime() - Radial.Opened) / 0.12, 0, 1)
	local w = LocalGun()
	local c = w and w:FluidColor() or RMPG.LocalColor()
	surface.SetMaterial(RMPG.Mat.glow2D)
	surface.SetDrawColor(c.x, c.y, c.z, 60 * k)
	surface.DrawTexturedRect(cx - 360, cy - 360, 720, 720)
	Radial.DrawWheel(cx, cy, 0.85 + 0.15 * k, ids, Radial.Hover, k)
	RMPG.DrawSwirl2D(cx - 46, cy - 46, 92, c, 220 * k)
	local title = Radial.Hover and Radial.Describe(ids[Radial.Hover]) or RMPG.T("radial_title")
	draw.SimpleTextOutlined(title, "RMPG_Head", cx, cy + OUTER + 34, Color(255, 255, 255, 255 * k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 20, 12, 220 * k))
	if n == 0 then
		draw.SimpleTextOutlined(RMPG.T("radial_empty"), "RMPG_Body", cx, cy + OUTER + 60, Color(200, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 20, 12))
	end
end)

---------------------------------------------------------------------------
-- Key binds
---------------------------------------------------------------------------

local function BindCode(id)
	local cv = RMPG.CL.binds[id]
	return cv and cv:GetInt() or 0
end

local function IsHeld(code)
	if not code or code <= 0 then return false end
	if code >= MOUSE_FIRST and code <= MOUSE_LAST then
		if code == MOUSE_WHEEL_UP or code == MOUSE_WHEEL_DOWN then return false end
		return input.IsMouseDown(code)
	end
	return input.IsKeyDown(code)
end
RMPG.IsBindHeld = IsHeld

local chatOpen = false
hook.Add("StartChat", "rmpg_binds", function() chatOpen = true end)
hook.Add("FinishChat", "rmpg_binds", function() chatOpen = false end)

local MODE_CYCLE = { RMPG.DEST_RANDOM, RMPG.DEST_LOCATION, RMPG.DEST_PLAYER, RMPG.DEST_MANUAL, RMPG.DEST_QUICK, RMPG.DEST_TRAP, RMPG.DEST_CHAIN, RMPG.DEST_COORDS }

local function NextMode(w)
	local cur = w:GetDestMode()
	local start = 1
	for i, m in ipairs(MODE_CYCLE) do if m == cur then start = i end end
	for k = 1, #MODE_CYCLE do
		local m = MODE_CYCLE[(start + k - 1) % #MODE_CYCLE + 1]
		if m == RMPG.DEST_LOCATION then
			local loc = RMPG.SelectedLoc and RMPG.Locations[RMPG.SelectedLoc] or RMPG.Locations[1]
			if loc then RMPG.SendDest(m, loc) return end
		elseif m == RMPG.DEST_PLAYER then
			if IsValid(RMPG.SelectedPlayer) then RMPG.SendDest(m, RMPG.SelectedPlayer) return end
		elseif m == RMPG.DEST_COORDS then
			local c = RMPG.CoordsLoad and RMPG.CoordsLoad()
			if c then RMPG.SendDest(m, c) return end
		else
			RMPG.SendDest(m)
			return
		end
	end
end

local lastSD = 0
local PRESS = {
	quick = function() RMPG.Action("quick") end,
	close = function() RMPG.Action("close") end,
	vertical = function() RMPG.ToggleVertical() end,
	nextmode = function(w) NextMode(w) end,
	menu = function() RMPG.OpenMenu() end,
	reload = function() RMPG.Action("reload") end,
	selfdestruct = function()
		if RealTime() - lastSD < 1.2 then
			net.Start("rmpg_selfdestruct")
			net.SendToServer()
			lastSD = 0
		else
			lastSD = RealTime()
			RMPG.AddNote(RMPG.T("n_sd_confirm"), 3)
		end
	end,
}

local prev = {}
local rmbPrev = false
local lmbPrev = false

hook.Add("Think", "rmpg_binds", function()
	local w = LocalGun()
	-- with the Q or C menu (or any window with a cursor) open the mouse buttons belong to it, the wheel stays shut
	local typing = chatOpen or gui.IsGameUIVisible() or IsValid(vgui.GetKeyboardFocus()) or IsValid(RMPG.MenuFrame) or vgui.CursorVisible()
	if not w or (typing and not Radial.IsOpen) then
		if Radial.IsOpen then Radial.Close(false) end
		for id in pairs(prev) do prev[id] = true end -- wait for keys to be released
		return
	end

	for _, b in ipairs(RMPG.BINDS) do
		local id = b[1]
		local held = IsHeld(BindCode(id))
		if id == "radial" then
			if held and not prev[id] then
				Radial.Open()
			elseif not held and prev[id] and Radial.IsOpen then
				Radial.Close(true)
			end
		elseif held and not prev[id] and not Radial.IsOpen then
			PRESS[id](w)
		end
		prev[id] = held
	end

	if Radial.IsOpen then
		local lmb, rmb = input.IsMouseDown(MOUSE_LEFT), input.IsMouseDown(MOUSE_RIGHT)
		if lmb and not lmbPrev then
			Radial.Close(true)
		elseif rmb and not rmbPrev then
			-- wheel + RMB: set the wheel up
			Radial.Close(false)
			RMPG.OpenMenu("radial")
		end
		lmbPrev, rmbPrev = lmb, rmb
	else
		lmbPrev, rmbPrev = input.IsMouseDown(MOUSE_LEFT), input.IsMouseDown(MOUSE_RIGHT)
	end
end)

-- Clicking a slice must not also fire the gun or open the big menu
hook.Add("CreateMove", "rmpg_radial", function(cmd)
	if Radial.IsOpen then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	elseif Radial.BlockAttack then
		if input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT) then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
		else
			Radial.BlockAttack = false
		end
	end
end)

function RMPG.ResetBinds()
	for _, b in ipairs(RMPG.BINDS) do RMPG.CL.binds[b[1]]:SetInt(b[3]) end
end
