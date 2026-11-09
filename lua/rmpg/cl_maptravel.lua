-- Client: portals to another map (sv_maptravel.lua). The server's map list for the menu, the screen while you wait
-- inside the portal with its "step out" button (E or Space do it too), a line at the top for everyone else while a trip
-- counts down, and the map's name over the portal.
RMPG = RMPG or {}
RMPG.Maps = RMPG.Maps or { list = {}, allowed = false, version = 0, current = "" }

function RMPG.RequestMaps()
	if (RMPG.Maps.asked or 0) > RealTime() then return end
	RMPG.Maps.asked = RealTime() + 2
	net.Start("rmpg_maps")
	net.SendToServer()
end

net.Receive("rmpg_maps", function()
	local m = RMPG.Maps
	m.allowed = net.ReadBool()
	m.current = net.ReadString()
	local list = {}
	for i = 1, net.ReadUInt(12) do list[i] = net.ReadString() end
	m.list = list
	m.version = m.version + 1
end)

-- A map's picture, where the game's own menu finds it (false when this game has none)
local thumbs = {}
function RMPG.MapThumb(name)
	local t = thumbs[name]
	if t == nil then
		local m = Material("maps/thumb/" .. name .. ".png", "smooth")
		if m:IsError() then m = Material("maps/" .. name .. ".png", "smooth") end
		t = not m:IsError() and m or false
		thumbs[name] = t
	end
	return t
end

-- Which shelf of the list a map goes on, by the start of its name
RMPG.MAP_CATS = {
	{ "map_cat_sandbox", { "^gm_" } },
	{ "map_cat_rp", { "^rp_", "^darkrp" } },
	{ "map_cat_ttt", { "^ttt_" } },
	{ "map_cat_css", { "^de_", "^cs_", "^aim_", "^awp_", "^fy_", "^surf_", "^bhop_", "^kz_" } },
	{ "map_cat_hl2", { "^d1_", "^d2_", "^d3_", "^ep1_", "^ep2_", "^dm_" } },
	{ "map_cat_tf2", { "^ctf_", "^cp_", "^pl_", "^koth_", "^arena_", "^mvm_" } },
	{ "map_cat_horror", { "^zs_", "^zm_", "^ze_", "^hns_", "^jb_", "^ba_", "^mu_", "^ph_" } },
}
function RMPG.MapCategory(name)
	for _, c in ipairs(RMPG.MAP_CATS) do
		for _, pat in ipairs(c[2]) do
			if string.find(name, pat) then return c[1] end
		end
	end
	return "map_cat_other"
end

local function Inside()
	return LocalPlayer():GetNW2Bool("RMPG_InMapTrip", false)
end

local function StepOut()
	if (RMPG.MapStepT or 0) > RealTime() then return end
	RMPG.MapStepT = RealTime() + 0.5
	net.Start("rmpg_mapstep")
	net.SendToServer()
end

---------------------------------------------------------------------------
-- Inside: the portal fills the screen, the countdown and a button out
---------------------------------------------------------------------------

local panel
local function Panel(on)
	if on and not IsValid(panel) then
		panel = vgui.Create("DPanel")
		panel:SetSize(340, 64)
		panel.Paint = function() end
		local b = RMPG.UI.Button(panel, RMPG.T("map_step_out"), "danger", StepOut, "icon16/door_out.png")
		b:Dock(FILL)
		gui.EnableScreenClicker(true)
	elseif not on and IsValid(panel) then
		panel:Remove()
		panel = nil
		gui.EnableScreenClicker(false)
	end
	if IsValid(panel) then panel:SetPos(ScrW() / 2 - 170, ScrH() * 0.72) end
end

hook.Add("Think", "rmpg_maptravel", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	Panel(Inside() and me:Alive())
end)

hook.Add("PlayerBindPress", "rmpg_maptravel", function(ply, bind, pressed)
	if not pressed or not Inside() then return end
	if string.find(bind, "+use", 1, true) or string.find(bind, "+jump", 1, true) then
		StepOut()
		return true
	end
end)

hook.Add("HUDShouldDraw", "rmpg_maptravel", function(name)
	if (name == "CHudCrosshair" or name == "CHudWeaponSelection") and IsValid(LocalPlayer()) and Inside() then return false end
end)

local function Countdown()
	local ends = GetGlobal2Float("RMPG_MapTripEnds", 0)
	if ends <= 0 then return nil end
	return math.max(0, math.ceil(ends - CurTime()))
end

hook.Add("HUDPaint", "rmpg_maptravel", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local map = GetGlobal2String("RMPG_MapTrip", "")
	if Inside() then
		local sw, sh = ScrW(), ScrH()
		local col = RMPG.LocalColor()
		surface.SetDrawColor(2, 10, 6, 235)
		surface.DrawRect(0, 0, sw, sh)
		local size = math.min(sw, sh) * 0.75
		RMPG.DrawSwirl2D(sw / 2 - size / 2, sh * 0.42 - size / 2, size, Color(col.x, col.y, col.z), 200)
		draw.SimpleTextOutlined(RMPG.T("map_inside"), "RMPG_Big", sw / 2, sh * 0.16, Color(230, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined(RMPG.T("map_to", map), "RMPG_Head", sw / 2, sh * 0.24, Color(150, 255, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		local left = Countdown()
		local text = left and tostring(left) or RMPG.T("map_wait_owner")
		draw.SimpleTextOutlined(text, left and "RMPG_Big" or "RMPG_Head", sw / 2, sh * 0.42, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, color_black)
		draw.SimpleTextOutlined(RMPG.T("map_inside_n", GetGlobal2Int("RMPG_MapTripIn", 0)), "RMPG_BodyB", sw / 2, sh * 0.62, Color(220, 240, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		draw.SimpleTextOutlined(RMPG.T("map_step_hint"), "RMPG_Small", sw / 2, sh * 0.72 + 80, Color(200, 220, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		return
	end
	-- everyone else: where the trip goes and how long is left to join it
	local left = Countdown()
	if map == "" or not left or not RMPG.CL.hud:GetBool() then return end
	local owner = GetGlobal2Entity("RMPG_MapTripOwner", NULL)
	local text = RMPG.T("map_banner", IsValid(owner) and owner:Nick() or "?", map, left)
	surface.SetFont("RMPG_BodyB")
	local tw = surface.GetTextSize(text)
	local w, h = tw + 40, 40
	local x, y = ScrW() / 2 - w / 2, 18
	RMPG.HoloBox(x, y, w, h, Color(4, 26, 16, 220), Color(90, 255, 150))
	draw.SimpleText(text, "RMPG_BodyB", ScrW() / 2, y + h / 2, Color(225, 255, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- The map's name over its portal, turned to whoever looks at it
hook.Add("PostDrawTranslucentRenderables", "rmpg_maptravel", function(depth, sky)
	if depth or sky then return end
	for _, p in ipairs(ents.FindByClass("rmpg_portal")) do
		local map = p:GetNW2String("RMPG_MapTo", "")
		if map ~= "" and p:GetCloseTime() == 0 and p:GetPos():DistToSqr(EyePos()) < 1500 * 1500 then
			local pos = p:GetPos() + p:GetAngles():Up() * (p:GetRadius() + 14)
			local ang = (EyePos() - pos):Angle()
			ang:RotateAroundAxis(ang:Up(), 90)
			ang:RotateAroundAxis(ang:Forward(), 90)
			local ends = p:GetNW2Float("RMPG_MapEnds", 0)
			cam.Start3D2D(pos, ang, 0.12)
				draw.SimpleTextOutlined("» " .. map, "RMPG_Big", 0, 0, Color(150, 255, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, color_black)
				local sub = ends > 0 and RMPG.T("map_left", math.max(0, math.ceil(ends - CurTime()))) or RMPG.T("map_enter_first")
				draw.SimpleTextOutlined(sub, "RMPG_Head", 0, 46, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
			cam.End3D2D()
		end
	end
end)
