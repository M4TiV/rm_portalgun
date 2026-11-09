-- Client: Evil Morty's eyepatch - drawn on the head, its own wheel of abilities (hold the mouse wheel), the abilities on
-- screen (where a portal leads, the thermal view, the X-ray scan with its kill record, what can be hacked, the video
-- camera, the binoculars, the auto-aim) and the editor: a head in a window, where the pad and the strap are dragged into
-- place and sized
RMPG = RMPG or {}
local UI = RMPG.UI
local Radial = RMPG.Radial

local PORTAL, XRAY, HACK, SCAN = RMPG.PATCH_PORTAL, RMPG.PATCH_XRAY, RMPG.PATCH_HACK, RMPG.PATCH_SCAN
local CAMERA, BINOC = RMPG.PATCH_CAMERA, RMPG.PATCH_BINOC
local UP = Vector(0, 0, 1)
local CFG = CreateClientConVar("rmpg_patch_cfg", RMPG.PatchString(RMPG.PatchDefaults()), true, true, "Where the eyepatch sits (set in its editor)")
local KEY = CreateClientConVar("rmpg_bind_patch", tostring(MOUSE_MIDDLE), true, false, "Button that holds the eyepatch wheel open")
local REC_KEY = CreateClientConVar("rmpg_bind_patch_rec", "0", true, false, "Button that starts and stops the eyepatch's video camera")
local COL_R = CreateClientConVar("rmpg_patch_r", "255", true, false, "Eyepatch interface colour: red", 0, 255)
local COL_G = CreateClientConVar("rmpg_patch_g", "196", true, false, "Eyepatch interface colour: green", 0, 255)
local COL_B = CreateClientConVar("rmpg_patch_b", "44", true, false, "Eyepatch interface colour: blue", 0, 255)
local ACCENT, TEXT, MUTED, BG = Color(255, 196, 44), Color(255, 244, 214), Color(255, 222, 150), Color(18, 13, 4, 236)
local THEME = { slice = Color(46, 34, 8, 220), hover = Color(178, 137, 30, 240), current = Color(97, 74, 16, 235), edge = Color(12, 9, 2, 235) }

-- The whole interface follows one colour: gold, unless it was changed in the C menu
local function Shade(c, k, to)
	c.r = math.floor(Lerp(k, ACCENT.r, to))
	c.g = math.floor(Lerp(k, ACCENT.g, to))
	c.b = math.floor(Lerp(k, ACCENT.b, to))
end

local function Recolor()
	ACCENT.r, ACCENT.g, ACCENT.b = math.Clamp(COL_R:GetInt(), 0, 255), math.Clamp(COL_G:GetInt(), 0, 255), math.Clamp(COL_B:GetInt(), 0, 255)
	Shade(TEXT, 0.82, 255)
	Shade(MUTED, 0.4, 255)
	Shade(BG, 0.93, 0)
	Shade(THEME.slice, 0.82, 0)
	Shade(THEME.hover, 0.3, 0)
	Shade(THEME.current, 0.62, 0)
	Shade(THEME.edge, 0.95, 0)
end
Recolor()
for _, name in ipairs({ "rmpg_patch_r", "rmpg_patch_g", "rmpg_patch_b" }) do
	cvars.AddChangeCallback(name, Recolor, "rmpg_patch_color")
end
RMPG.PatchUI = { accent = ACCENT, text = TEXT, muted = MUTED, bg = BG }

local function Send(a, write)
	net.Start("rmpg_patch")
	net.WriteUInt(a, 3)
	if write then write() end
	net.SendToServer()
end

local function Worn(ply) return IsValid(ply) and ply:GetNW2Bool("RMPG_Patch") end
local function Mode() return Worn(LocalPlayer()) and LocalPlayer():GetNW2Int("RMPG_PatchMode") or 0 end

---------------------------------------------------------------------------
-- On the head
---------------------------------------------------------------------------

local parsed = {}
local function CfgOf(ply)
	local str = ply:GetNW2String("RMPG_PatchCfg")
	parsed[str] = parsed[str] or RMPG.PatchParse(str)
	return parsed[str]
end

local pads = {}
local function Piece(model)
	if not IsValid(pads[model]) then
		pads[model] = ClientsideModel(model, RENDERGROUP_OPAQUE)
		if IsValid(pads[model]) then pads[model]:SetNoDraw(true) end
	end
	return pads[model]
end

local function Put(e, pos, ang, scale)
	if not IsValid(e) then return end
	local m = Matrix()
	m:Scale(scale)
	e:EnableMatrix("RenderMultiply", m)
	e:SetPos(pos)
	e:SetAngles(ang)
	e:InvalidateBoneCache()
	e:SetupBones()
	e:DrawModel()
end

-- The pad and the strap on a head (a player, or the head in the editor)
local function DrawOn(ent, c)
	local pos, ang = RMPG.PatchFrame(ent)
	if not pos then return end
	local p, a = LocalToWorld(Vector(c.pf, -c.pr, c.pu), Angle(c.ppitch, c.pyaw, c.proll), pos, ang)
	Put(Piece("models/rmpg/eyepatch.mdl"), p, a, Vector(c.psize, c.psize, c.psize))
	p, a = LocalToWorld(Vector(c.sf, -c.sr, c.su), Angle(c.spitch, 0, c.sroll), pos, ang)
	Put(Piece("models/rmpg/eyepatch_strap.mdl"), p, a, Vector(c.sx, c.sy, c.sw))
end

hook.Add("PostPlayerDraw", "rmpg_patch", function(ply)
	if Worn(ply) and not RMPG.PatchInView then DrawOn(ply, CfgOf(ply)) end
end)

---------------------------------------------------------------------------
-- The wheel
---------------------------------------------------------------------------

local Wheel = {}
RMPG.PatchWheel = Wheel
local MAIN = { "portal", "xray", "scan", "hack", "camera", "binoc", "aim", "editor", "off" }
local AIM_PAGE = { "part1", "part2", "part3", "part4", "part5", "back" }
Wheel.Ids = MAIN
local ICONS = {}
local function Icon(path)
	ICONS[path] = ICONS[path] or Material(path)
	return ICONS[path]
end

local function Pick(m) Send(RMPG.PATCH_A_MODE, function() net.WriteUInt(m, 3) end) end

local ITEMS = {
	portal = { "patch_a_portal", "icon16/door_open.png", function() Pick(PORTAL) end, PORTAL },
	xray = { "patch_a_xray", "icon16/weather_sun.png", function() Pick(XRAY) end, XRAY },
	scan = { "patch_a_scan", "icon16/eye.png", function() Pick(SCAN) end, SCAN },
	hack = { "patch_a_hack", "icon16/lightning.png", function() Pick(HACK) end, HACK },
	camera = { "patch_a_camera", "icon16/camera.png", function()
		Pick(CAMERA)
		if REC_KEY:GetInt() <= 0 then RMPG.PatchRecBind() end
	end, CAMERA },
	binoc = { "patch_a_binoc", "icon16/zoom.png", function() Pick(BINOC) end, BINOC },
	aim = { "patch_a_aim", "icon16/bullet_red.png", function() Wheel.Open(true, AIM_PAGE) end },
	editor = { "patch_a_editor", "icon16/cog.png", function() RMPG.OpenPatchEditor() end },
	off = { "patch_a_off", "icon16/cross.png", function() Send(RMPG.PATCH_A_OFF) end },
	back = { "patch_a_back", "icon16/arrow_left.png", function() Wheel.Open(true) end },
	implants = { "impl_wheel", "icon16/lightning.png", function() RMPG.ImplantWheel.Open(true) end },
}
for i, p in ipairs(RMPG.PATCH_PARTS) do
	ITEMS["part" .. i] = { p[1], "icon16/bullet_red.png", function() Send(RMPG.PATCH_A_AIM, function() net.WriteUInt(i, 3) end) end, nil, i }
end

local function Describe(id)
	local it = ITEMS[id]
	if not it then return end
	return RMPG.T(it[1]), Icon(it[2]), it[3], function()
		if it[5] then return LocalPlayer():GetNW2Int("RMPG_AimPart", 0) == it[5] end
		return it[4] ~= nil and Mode() == it[4]
	end
end

-- sticky: stays open by itself (opened from the portal gun's wheel, the button is not held any more)
function Wheel.Open(sticky, ids)
	if Wheel.IsOpen then return end
	Wheel.IsOpen = true
	Wheel.Sticky = sticky
	local main = MAIN
	if RMPG.HasImplants(LocalPlayer()) then
		main = table.Copy(MAIN)
		main[#main + 1] = "implants"
	end
	Wheel.Ids = ids or main
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

hook.Add("HUDPaint", "rmpg_patch_wheel", function()
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
	if Wheel.Hover ~= Wheel.LastHover then
		Wheel.LastHover = Wheel.Hover
		if Wheel.Hover and RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiHover) end
	end
	local k = math.Clamp((RealTime() - Wheel.Opened) / 0.12, 0, 1)
	surface.SetMaterial(RMPG.Mat.glow2D)
	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 60 * k)
	surface.DrawTexturedRect(cx - 360, cy - 360, 720, 720)
	Radial.DrawWheel(cx, cy, 0.85 + 0.15 * k, ids, Wheel.Hover, k, Describe, THEME)
	local title = Wheel.Hover and Describe(ids[Wheel.Hover]) or RMPG.T(ids == AIM_PAGE and "patch_a_aim" or "patch_name")
	draw.SimpleTextOutlined(title, "RMPG_Head", cx, cy + 249, Color(255, 255, 255, 255 * k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(BG.r, BG.g, BG.b, 220 * k))
end)

local prevHeld, lmbPrev, rmbPrev = false, false, false
local chatOpen = false
hook.Add("StartChat", "rmpg_patch", function() chatOpen = true end)
hook.Add("FinishChat", "rmpg_patch", function() chatOpen = false end)

hook.Add("Think", "rmpg_patch_keys", function()
	local me = LocalPlayer()
	RMPG.PatchFovK = Mode() == BINOC and RMPG.PatchZoom or nil
	if not Worn(me) then
		if Wheel.IsOpen then Wheel.Close(false) end
		RMPG.PatchRecKey(true)
		return
	end
	-- with the Q or C menu (or any window with a cursor) open the mouse buttons belong to it, the wheel stays shut
	local typing = chatOpen or gui.IsGameUIVisible() or IsValid(vgui.GetKeyboardFocus()) or IsValid(RMPG.MenuFrame) or vgui.CursorVisible()
	local held = RMPG.IsBindHeld(KEY:GetInt())
	-- with the portal gun in hand the same button is the gun's wheel, which has a way into this one
	local gunWheel = Radial.LocalGun() ~= nil and KEY:GetInt() == RMPG.CL.binds.radial:GetInt()
	if held and not prevHeld and not typing and not gunWheel and not Radial.IsOpen then
		Wheel.Open(false)
	elseif not held and prevHeld and Wheel.IsOpen and not Wheel.Sticky then
		Wheel.Close(true)
	end
	prevHeld = held
	RMPG.PatchRecKey(typing)
	local lmb, rmb = input.IsMouseDown(MOUSE_LEFT), input.IsMouseDown(MOUSE_RIGHT)
	if Wheel.IsOpen then
		if lmb and not lmbPrev then
			Wheel.Close(true)
		elseif rmb and not rmbPrev then
			Wheel.Close(false)
		end
	end
	lmbPrev, rmbPrev = lmb, rmb
end)

-- Clicking a slice must not also fire the weapon in hand
hook.Add("CreateMove", "rmpg_patch_wheel", function(cmd)
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

---------------------------------------------------------------------------
-- What the patch finds around you: bodies for the thermal view and the scan, mechanisms for hacking
---------------------------------------------------------------------------

local enemies, hackables = {}, {}
local nextScan = 0
local Info = { sel = 1, kills = {}, asked = 0 } -- the scan: who is in the sights and their record from the server

local function DisplayName(e)
	if e:IsPlayer() then return e:Nick() end
	if e.GetCloneName then return e:GetCloneName() end
	if e:GetClass() == "rmpg_brain_worm" then return RMPG.T("worm_name") end
	return language.GetPhrase(e:GetClass())
end

-- How a thing sits on the screen: the box around it, nil when it is not in front of the eye. Everything the patch has to
-- say about a thing is written over the top of this box.
local function ScreenBox(e)
	local a, b = e:WorldSpaceAABB()
	local x0, y0, x1, y1
	for i = 0, 7 do
		local p = Vector(bit.band(i, 1) > 0 and b.x or a.x, bit.band(i, 2) > 0 and b.y or a.y, bit.band(i, 4) > 0 and b.z or a.z):ToScreen()
		if p.visible then
			x0, y0 = math.min(x0 or p.x, p.x), math.min(y0 or p.y, p.y)
			x1, y1 = math.max(x1 or p.x, p.x), math.max(y1 or p.y, p.y)
		end
	end
	if x0 then return x0, y0, x1, y1 end
end

-- A weapon or tool class as a name people know
local function ToolName(class)
	local w = weapons.GetStored(class)
	if w and w.PrintName then return language.GetPhrase(w.PrintName) end
	return language.GetPhrase(class)
end

-- In the sights: a body in the middle of the view, through walls too, else whatever the eye is on. Through the
-- binoculars the middle of the view is a very narrow place, and what the eye is on comes first.
local function PickTarget(zoomed)
	local me = LocalPlayer()
	local e
	if zoomed then
		local tr = me:GetEyeTrace()
		if IsValid(tr.Entity) then e = tr.Entity end
	end
	e = e or RMPG.PatchPick(EyePos(), EyeAngles():Forward(), enemies, zoomed and 0.9995 or nil)
	if not e then
		local tr = me:GetEyeTrace()
		if IsValid(tr.Entity) then e = tr.Entity end
	end
	if e and e:GetClass() == "rmpg_boots_body" then e = e:GetWearer() end
	-- a piece of a worm means the worm
	if e and e:GetClass() == "rmpg_worm_seg" then
		for _, w in ipairs(ents.FindByClass("rmpg_brain_worm")) do
			if table.HasValue(w:Segments(), e) then
				e = w
				break
			end
		end
	end
	if e ~= Info.target then
		Info.target, Info.kills, Info.sel, Info.asked = e, {}, 1, 0
		Info.x, Info.y = nil, nil
	end
	if IsValid(e) and RealTime() >= Info.asked then
		Info.asked = RealTime() + 1
		Send(RMPG.PATCH_A_SCAN, function() net.WriteEntity(e) end)
	end
end

local function Scan()
	local now = RealTime()
	if now < nextScan then return end
	nextScan = now + 0.25
	local me = LocalPlayer()
	local mode = Mode()
	enemies, hackables = {}, {}
	if mode == XRAY or mode == SCAN then
		for _, e in ipairs(ents.FindInSphere(EyePos(), RMPG.CV.patchXray:GetFloat())) do
			if RMPG.PatchEnemy(e, me) and not e:IsDormant() and not e:GetNoDraw() then enemies[#enemies + 1] = e end
		end
		if mode == SCAN then PickTarget() end
	elseif mode == BINOC then
		for _, e in ipairs(ents.FindInCone(EyePos(), EyeAngles():Forward(), 30000, 0.99)) do
			if RMPG.PatchEnemy(e, me) and not e:IsDormant() then enemies[#enemies + 1] = e end
		end
		PickTarget(true)
	elseif mode == HACK then
		hackables = RMPG.PatchHackables(EyePos(), RMPG.CV.patchHackRange:GetFloat())
	end
end

net.Receive("rmpg_patch_scan", function()
	local e = net.ReadEntity()
	local kills = {}
	for i = 1, net.ReadUInt(3) do
		kills[i] = { who = net.ReadString(), with = net.ReadString(), clock = net.ReadUInt(32), ago = net.ReadFloat(), got = CurTime() }
	end
	if e == Info.target then
		Info.kills = kills
		Info.sel = math.Clamp(Info.sel, 1, math.max(#kills, 1))
	end
end)

-- The mouse wheel walks through the kills instead of the weapons while there is something to pick
hook.Add("PlayerBindPress", "rmpg_patch_scan", function(ply, bind, pressed)
	if not pressed then return end
	local d = (bind == "invnext" and 1) or (bind == "invprev" and -1)
	if not d then return end
	if Mode() == BINOC then
		RMPG.PatchZoom = math.Clamp(RMPG.PatchZoom * (d > 0 and 1.25 or 0.8), 0.04, 0.6)
		return true
	end
	if Mode() ~= SCAN or not IsValid(Info.target) or #Info.kills < 2 then return end
	Info.sel = (Info.sel - 1 + d) % #Info.kills + 1
	return true
end)

---------------------------------------------------------------------------
-- The thermal view: the world goes cold and blue, bodies glow through the walls, hottest in the middle. A parasite in
-- a head burns brighter than anything else.
---------------------------------------------------------------------------

local HEAT = CreateMaterial("rmpg_patch_heat", "UnlitGeneric", {
	["$basetexture"] = "vgui/white",
	["$translucent"] = 1,
	["$vertexalpha"] = 1,
	["$vertexcolor"] = 1,
	["$model"] = 1,
})
local COLD = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0.02, ["$pp_colour_addb"] = 0.1,
	["$pp_colour_brightness"] = -0.14, ["$pp_colour_contrast"] = 0.8, ["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}
local CORE, WARM = Color(255, 240, 170, 230), Color(255, 170, 40, 200)

local function Infested(e)
	return e:GetNW2Float("RMPG_Wormed", 0) > 0 or IsValid(e:GetNW2Entity("RMPG_WormOn"))
end

local function BodyHeat(e)
	if e:GetClass() == "rmpg_brain_worm" then return 1, 0.15, 0.8 end
	return 1, 0.22, 0.05
end

local function BonePos(e, name)
	local b = e:LookupBone(name)
	local m = b and e:GetBoneMatrix(b)
	return m and m:GetTranslation()
end

local function Glow(pos, size, col)
	if pos then render.DrawSprite(pos, size, size, col) end
end

hook.Add("RenderScreenspaceEffects", "rmpg_patch_thermal", function()
	if Mode() ~= XRAY or RMPG.PatchInView then return end
	DrawColorModify(COLD)
	cam.Start3D()
	cam.IgnoreZ(true)
	render.SuppressEngineLighting(true)
	render.MaterialOverride(HEAT)
	render.SetBlend(0.95)
	for _, e in ipairs(enemies) do
		if IsValid(e) then
			render.SetColorModulation(BodyHeat(e))
			e:DrawModel()
		end
	end
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
	render.SuppressEngineLighting(false)
	render.SetMaterial(RMPG.Mat.glow)
	local beat = 0.75 + 0.25 * math.sin(CurTime() * 7)
	for _, e in ipairs(enemies) do
		if IsValid(e) then
			e:SetupBones()
			local head = BonePos(e, "ValveBiped.Bip01_Head1")
			Glow(BonePos(e, "ValveBiped.Bip01_Spine2") or e:WorldSpaceCenter(), 34, CORE)
			Glow(BonePos(e, "ValveBiped.Bip01_Pelvis"), 24, WARM)
			Glow(head, 16, CORE)
			if head and Infested(e) then
				Glow(head + UP * 3, 46 * beat, Color(255, 30, 200, 255))
				Glow(head + UP * 3, 20 * beat, color_white)
			end
		end
	end
	cam.IgnoreZ(false)
	cam.End3D()
end)

local function DrawThermal()
	local eye = EyePos()
	for _, e in ipairs(enemies) do
		if IsValid(e) then
			local x0, y0, x1 = ScreenBox(e)
			if x0 then
				local cx = (x0 + x1) / 2
				draw.SimpleTextOutlined(DisplayName(e), "RMPG_SmallB", cx, y0 - 24, ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				draw.SimpleTextOutlined(math.floor(e:GetPos():Distance(eye) * 0.01905) .. " m", "RMPG_Small", cx, y0 - 10, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				if Infested(e) then
					draw.SimpleTextOutlined(RMPG.T("patch_parasite"), "RMPG_BodyB", cx, y0 - 42, Color(255, 60, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- The X-ray scan: the one in the sights turns to glass with the skeleton showing, and a card tells all about them
---------------------------------------------------------------------------

local function Skeleton(e)
	e:SetupBones()
	render.SetMaterial(RMPG.Mat.beam)
	for i = 0, e:GetBoneCount() - 1 do
		local p = e:GetBoneParent(i)
		local name = e:GetBoneName(i)
		if p and p >= 0 and name and string.find(name, "Bip01", 1, true) and not string.find(name, "Finger", 1, true) then
			local a, b = e:GetBoneMatrix(i), e:GetBoneMatrix(p)
			if a and b then render.DrawBeam(a:GetTranslation(), b:GetTranslation(), 1.6, 0, 1, TEXT) end
		end
	end
end

hook.Add("PostDrawTranslucentRenderables", "rmpg_patch_scan", function(depth, sky)
	if depth or sky or RMPG.PatchInView or Mode() ~= SCAN then return end
	local e = Info.target
	if not IsValid(e) then return end
	cam.IgnoreZ(true)
	render.SuppressEngineLighting(true)
	render.MaterialOverride(HEAT)
	render.SetColorModulation(ACCENT.r / 255, ACCENT.g / 255, ACCENT.b / 255)
	render.SetBlend(0.22)
	e:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride()
	render.SuppressEngineLighting(false)
	if e:GetBoneCount() > 3 then Skeleton(e) end
	cam.IgnoreZ(false)
end)

local function Row(label, value, x, y, w, col)
	draw.SimpleText(label, "RMPG_Small", x, y, MUTED)
	draw.SimpleText(value, "RMPG_SmallB", x + w, y, col or TEXT, TEXT_ALIGN_RIGHT)
	return y + 18
end

local function Sheet(e)
	local t = {}
	local function Add(key, v, col) t[#t + 1] = { RMPG.T(key), tostring(v), col } end
	if e:IsPlayer() then
		Add("scan_hp", e:Health())
		Add("scan_armor", e:Armor())
		Add("scan_kd", e:Frags() .. " / " .. e:Deaths())
	elseif e:Health() > 0 then
		Add("scan_hp", e:Health())
	end
	if e.GetActiveWeapon then
		local w = e:GetActiveWeapon()
		if IsValid(w) then Add("scan_weapon", ToolName(w:GetClass())) end
	end
	Add("scan_dist", math.floor(e:GetPos():Distance(EyePos()) * 0.01905) .. " m")
	Add("scan_model", string.GetFileFromFilename(e:GetModel() or "?"))
	if e:IsPlayer() or e:IsNPC() or e:IsNextBot() then
		local size = e:GetNW2Float("RMPG_Wormed", 0)
		if size > 0 then
			Add("scan_worm", string.format(RMPG.T("scan_worm_size"), size), Color(255, 80, 210))
		else
			Add("scan_worm", RMPG.T("scan_worm_none"))
		end
	end
	return t
end

-- Who else is around someone
local function Near(e)
	local names = {}
	for _, o in ipairs(ents.FindInSphere(e:GetPos(), 400)) do
		if o ~= e and RMPG.PatchEnemy(o, LocalPlayer()) then
			names[#names + 1] = DisplayName(o)
			if #names >= 4 then break end
		end
	end
	return #names > 0 and table.concat(names, ", ") or RMPG.T("scan_alone")
end

local function DrawScan(withNear)
	local e = Info.target
	if not IsValid(e) then
		draw.SimpleTextOutlined(RMPG.T("scan_hint"), "RMPG_Small", ScrW() / 2, ScrH() * 0.62, ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
		return
	end
	local sheet = Sheet(e)
	if withNear then sheet[#sheet + 1] = { RMPG.T("scan_near"), Near(e) } end
	local kills = Info.kills
	local w = 360
	local h = 64 + #sheet * 18 + 30 + math.max(#kills, 1) * 20 + (#kills > 0 and 44 or 0) + (#kills > 1 and 20 or 0)
	-- over the one it is about, as near as the screen lets it be
	local x0, y0, x1 = ScreenBox(e)
	local cx, top = x0 and (x0 + x1) / 2 or ScrW() / 2, y0 or ScrH() / 2
	local margin = withNear and ScrH() * 0.07 + 8 or 52
	local wx = math.Clamp(cx - w / 2, 10, ScrW() - w - 10)
	local wy = math.Clamp(top - h - 20, margin, math.max(ScrH() - h - margin, margin))
	local k = math.min(RealFrameTime() * 14, 1)
	Info.x = Info.x and Lerp(k, Info.x, wx) or wx
	Info.y = Info.y and Lerp(k, Info.y, wy) or wy
	local x, y = math.floor(Info.x), math.floor(Info.y)
	if y0 and y + h < top then
		surface.SetDrawColor(ACCENT)
		surface.DrawLine(math.Clamp(cx, x, x + w), y + h, cx, top)
	end
	RMPG.HoloBox(x, y, w, h, BG, ACCENT)
	RMPG.HoloText(DisplayName(e), "RMPG_Head", x + 14, y + 10, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local cy = y + 44
	for _, r in ipairs(sheet) do cy = Row(r[1], r[2], x + 14, cy, w - 28, r[3]) end
	cy = cy + 8
	RMPG.HoloText(RMPG.T("scan_kills"), "RMPG_SmallB", x + 14, cy, ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	cy = cy + 20
	if #kills == 0 then
		draw.SimpleText(RMPG.T("scan_no_kills"), "RMPG_Small", x + 14, cy, MUTED)
		return
	end
	for i, k in ipairs(kills) do
		local on = i == Info.sel
		if on then
			surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 40)
			surface.DrawRect(x + 8, cy - 1, w - 16, 19)
		end
		draw.SimpleText(i .. ". " .. language.GetPhrase(k.who), on and "RMPG_SmallB" or "RMPG_Small", x + 14, cy, on and color_white or TEXT)
		cy = cy + 20
	end
	local k = kills[Info.sel]
	if k then
		cy = cy + 4
		local ago = math.floor(k.ago + CurTime() - k.got)
		draw.SimpleText(string.format(RMPG.T("scan_when"), os.date("%H:%M:%S", k.clock), ago), "RMPG_Small", x + 14, cy, ACCENT)
		draw.SimpleText(string.format(RMPG.T("scan_with"), ToolName(k.with)), "RMPG_Small", x + 14, cy + 18, ACCENT)
		cy = cy + 40
	end
	if #kills > 1 then draw.SimpleText(RMPG.T("scan_wheel"), "RMPG_Small", x + 14, cy, MUTED) end
end

---------------------------------------------------------------------------
-- Hacking: everything in reach is marked, E sets off what is in the middle of the view
---------------------------------------------------------------------------

-- The keys for this one: bombs and dynamite have a second action
local function HackKeys(e)
	if e.GetBlastTime then
		if e:GetBlastTime() > 0 then return RMPG.T("hack_defuse") end
		return RMPG.T(e:IsLinked() and "hack_cut" or "hack_arm")
	end
	if e:GetClass() == "gmod_dynamite" then return RMPG.T("hack_dynamite") end
	return RMPG.T("patch_hack_key")
end

local function DrawHack()
	local target = RMPG.PatchPick(EyePos(), EyeAngles():Forward(), hackables)
	Info.hack = target
	for _, e in ipairs(hackables) do
		if IsValid(e) then
			if e == target then
				local x0, y0, x1 = ScreenBox(e)
				if x0 then
					local cx = (x0 + x1) / 2
					draw.SimpleTextOutlined(RMPG.T(RMPG.PATCH_HACKABLE[e:GetClass()] or "hk_engine"), "RMPG_BodyB", cx, y0 - 34, ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
					draw.SimpleTextOutlined(HackKeys(e), "RMPG_SmallB", cx, y0 - 14, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				end
			else
				local p = e:WorldSpaceCenter():ToScreen()
				if p.visible then
					surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 200)
					surface.DrawOutlinedRect(p.x - 7, p.y - 7, 14, 14, 1)
				end
			end
		end
	end
end

-- The contour round what the patch is looking at, through walls too
hook.Add("PreDrawHalos", "rmpg_patch", function()
	local mode = Mode()
	if mode == SCAN or mode == BINOC then
		if IsValid(Info.target) then halo.Add({ Info.target }, ACCENT, 2, 2, 2, true, true) end
	elseif mode == XRAY then
		local list = {}
		for _, e in ipairs(enemies) do
			if IsValid(e) then list[#list + 1] = e end
		end
		if #list > 0 then halo.Add(list, ACCENT, 1, 1, 1, true, true) end
	elseif mode == HACK and IsValid(Info.hack) then
		halo.Add({ Info.hack }, ACCENT, 2, 2, 2, true, true)
	end
end)

---------------------------------------------------------------------------
-- Where a portal leads: a window with the view out of the portal on the far side
---------------------------------------------------------------------------

local function PortalInView()
	local eye, aim = EyePos(), EyeAngles():Forward()
	local best, bd = nil, 0.93
	for _, p in ipairs(ents.FindByClass("rmpg_portal")) do
		local d = p:GetPos() - eye
		local k = d:Dot(aim) / math.max(d:Length(), 1)
		if k > bd then best, bd = p, k end
	end
	return best
end

local function DrawPortalView()
	local p = PortalInView()
	if not IsValid(p) then return end
	local w, h = math.floor(ScrW() * 0.3), math.floor(ScrH() * 0.3)
	local x, y = ScrW() - w - 30, 90
	RMPG.HoloBox(x - 8, y - 34, w + 16, h + 42, BG, ACCENT)
	local to = p:GetPartner()
	if not IsValid(to) then
		RMPG.HoloText(RMPG.T("patch_portal_title"), "RMPG_BodyB", x, y - 26, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(RMPG.T("patch_portal_none"), "RMPG_Body", x + w / 2, y + h / 2, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end
	RMPG.HoloText(RMPG.T("patch_portal_title"), "RMPG_BodyB", x, y - 26, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	local aim = RMPG.TransformDir(EyeAngles():Forward(), p:GetAngles(), to:GetAngles())
	RMPG.PatchInView = true
	render.RenderView({
		origin = to:GetPos() + to:GetAngles():Forward() * 14,
		angles = aim:Angle(),
		x = x, y = y, w = w, h = h,
		fov = 80,
		drawhud = false, drawviewmodel = false, drawmonitors = false, dopostprocess = false, bloomtone = false,
	})
	RMPG.PatchInView = false
end

---------------------------------------------------------------------------
-- The camera: a button of your choice records what you see into garrysmod/videos
---------------------------------------------------------------------------

local Rec = {}
local recHeld = false

local function RecStop()
	if not Rec.writer then return end
	Rec.writer:Finish()
	Rec.writer = nil
	RMPG.AddNote(string.format(RMPG.T("patch_rec_saved"), Rec.name), 2)
end

local function RecStart()
	if not video or not video.Record then
		RMPG.AddNote(RMPG.T("patch_rec_none"), 1)
		return
	end
	local w = math.min(ScrW(), 1280)
	local name = "evil_morty " .. game.GetMap() .. " " .. util.DateStamp()
	local writer, err = video.Record({
		name = name, container = "webm", video = "vp8", audio = "vorbis", quality = 0, bitrate = 1024 * 64,
		width = w, height = math.Round(ScrH() * (w / ScrW())), fps = 30, lockfps = true,
	})
	if not writer then
		RMPG.AddNote(tostring(err), 1)
		return
	end
	writer:SetRecordSound(true)
	Rec.writer, Rec.name, Rec.t0 = writer, name, RealTime()
end

hook.Add("DrawOverlay", "rmpg_patch_rec", function()
	if Rec.writer then Rec.writer:AddFrame(FrameTime(), true) end
end)
hook.Add("ShutDown", "rmpg_patch_rec", RecStop)

-- The record button while the camera is the chosen ability (and the recording stops when it no longer is)
function RMPG.PatchRecKey(typing)
	if Mode() ~= CAMERA then
		RecStop()
		recHeld = false
		return
	end
	local held = RMPG.IsBindHeld(REC_KEY:GetInt()) and not typing
	if held and not recHeld then
		if Rec.writer then RecStop() else RecStart() end
	end
	recHeld = held
end

-- The first time the camera is chosen: which button records?
function RMPG.PatchRecBind()
	if IsValid(RMPG.PatchRecFrame) then RMPG.PatchRecFrame:Remove() end
	local f = vgui.Create("EditablePanel")
	RMPG.PatchRecFrame = f
	f:SetSize(440, 180)
	f:Center()
	f:MakePopup()
	f.Paint = function(s, w, h)
		RMPG.HoloBox(0, 0, w, h, BG, ACCENT)
		RMPG.HoloText(RMPG.T("patch_rec_title"), "RMPG_Head", 18, 14, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(RMPG.T("patch_rec_hint"), "RMPG_Small", 18, 46, MUTED)
	end
	local b = vgui.Create("DBinder", f)
	b:SetPos(18, 76)
	b:SetSize(404, 40)
	b:SetSelectedNumber(REC_KEY:GetInt())
	b.OnChange = function(s, num) REC_KEY:SetInt(num) end
	local done = UI.Button(f, RMPG.T("patch_e_done"), "accent", function() f:Remove() end, "icon16/accept.png")
	done:SetPos(252, 128)
	done:SetSize(170, 38)
end
concommand.Add("rmpg_patch_recbind", function() RMPG.PatchRecBind() end)

local function DrawCamera()
	local w, h = ScrW(), ScrH()
	local m, L = 40, 60
	surface.SetDrawColor(255, 255, 255, 180)
	for _, c in ipairs({ { m, m, 1, 1 }, { w - m, m, -1, 1 }, { m, h - m, 1, -1 }, { w - m, h - m, -1, -1 } }) do
		surface.DrawRect(math.min(c[1], c[1] + c[3] * L), c[2], L, 2)
		surface.DrawRect(c[1], math.min(c[2], c[2] + c[4] * L), 2, L)
	end
	local key = REC_KEY:GetInt()
	if Rec.writer then
		if math.floor(RealTime() * 2) % 2 == 0 then
			surface.SetMaterial(RMPG.Mat.glow2D)
			surface.SetDrawColor(255, 30, 30)
			surface.DrawTexturedRect(m + 8, m + 8, 26, 26)
		end
		local t = RealTime() - Rec.t0
		draw.SimpleTextOutlined(string.format("REC  %02d:%02d", t / 60, t % 60), "RMPG_Head", m + 42, m + 21, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, color_black)
	end
	local hint = key > 0 and string.format(RMPG.T(Rec.writer and "patch_rec_stop" or "patch_rec_start"), string.upper(input.GetKeyName(key) or "?")) or RMPG.T("patch_rec_nokey")
	draw.SimpleTextOutlined(hint, "RMPG_SmallB", w / 2, h - m - 12, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end

---------------------------------------------------------------------------
-- The binoculars: the mouse wheel zooms, the card tells who that is and who is near them
---------------------------------------------------------------------------

RMPG.PatchZoom = 0.25

hook.Add("CalcView", "rmpg_patch_zoom", function(ply, pos, ang, fov)
	if RMPG.PatchFovK and not RMPG.BootsOn(ply) and not ply:InVehicle() then
		return { origin = pos, angles = ang, fov = fov * RMPG.PatchFovK }
	end
end)

hook.Add("AdjustMouseSensitivity", "rmpg_patch_zoom", function()
	if RMPG.PatchFovK then return math.max(RMPG.PatchFovK * 1.4, 0.08) end
end)

hook.Add("PreDrawViewModel", "rmpg_patch_zoom", function()
	if RMPG.PatchFovK then return true end
end)

hook.Add("PreDrawPlayerHands", "rmpg_patch_zoom", function()
	if RMPG.PatchFovK then return true end
end)

local function DrawBinoculars()
	local w, h = ScrW(), ScrH()
	local cx, cy = w / 2, h / 2
	surface.SetDrawColor(0, 0, 0, 215)
	surface.DrawRect(0, 0, w, h * 0.07)
	surface.DrawRect(0, h * 0.93, w, h * 0.07)
	surface.SetDrawColor(255, 255, 255, 170)
	surface.DrawRect(cx - 60, cy, 45, 1)
	surface.DrawRect(cx + 15, cy, 45, 1)
	surface.DrawRect(cx, cy - 60, 1, 45)
	surface.DrawRect(cx, cy + 15, 1, 45)
	local tr = LocalPlayer():GetEyeTrace()
	local info = string.format("x%.1f   ·   %d m", 1 / RMPG.PatchZoom, tr.HitPos:Distance(EyePos()) * 0.01905)
	draw.SimpleTextOutlined(info, "RMPG_Head", cx, h * 0.035, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	draw.SimpleTextOutlined(RMPG.T("patch_zoom_hint"), "RMPG_Small", cx, h * 0.965, MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	DrawScan(true)
end

---------------------------------------------------------------------------
-- The auto-aim: for a while the view locks on to the chosen part of whoever is nearest the middle of the screen
---------------------------------------------------------------------------

local FRIENDS = { npc_citizen = true, npc_alyx = true, npc_barney = true, npc_kleiner = true, npc_monk = true, npc_mossman = true, npc_eli = true, npc_vortigaunt = true, npc_dog = true, npc_magnusson = true }
local Aim = { nextLook = 0 }

local function PartPos(e, bone)
	local b = e:LookupBone(bone)
	local m = b and e:GetBoneMatrix(b)
	return m and m:GetTranslation() or e:WorldSpaceCenter()
end

local function AimPart(me)
	return RMPG.PATCH_PARTS[me:GetNW2Int("RMPG_AimPart", 1)] or RMPG.PATCH_PARTS[1]
end

local function AimOn(me)
	return Worn(me) and me:GetNW2Float("RMPG_AimUntil", 0) > CurTime()
end

local function CanHit(me, eye, e, pos)
	local tr = util.TraceLine({ start = eye, endpos = pos, filter = { me, me:GetNW2Entity("RMPG_BootBody") }, mask = MASK_SHOT })
	return not tr.Hit or tr.Entity == e or (IsValid(tr.Entity) and tr.Entity:GetClass() == "rmpg_boots_body" and tr.Entity:GetWearer() == e)
end

local function FindAim(me)
	local eye, aim = me:GetShootPos(), me:GetAimVector()
	local bone = AimPart(me)[2]
	local best, bd
	for _, e in ipairs(ents.FindInCone(eye, aim, 6000, 0.8)) do
		if RMPG.PatchEnemy(e, me) and e:GetClass() ~= "rmpg_brain_worm" and not e:IsDormant() and not FRIENDS[e:GetClass()] and not (e:IsPlayer() and RMPG.IsTrusted(e)) then
			local pos = PartPos(e, bone)
			local d = pos - eye
			local k = d:Dot(aim) / math.max(d:Length(), 1)
			if (not bd or k > bd) and CanHit(me, eye, e, pos) then best, bd = e, k end
		end
	end
	return best
end

hook.Add("CreateMove", "rmpg_patch_aim", function(cmd)
	local me = LocalPlayer()
	if not AimOn(me) or not me:Alive() or Wheel.IsOpen then
		Aim.target = nil
		return
	end
	local now = RealTime()
	if now >= Aim.nextLook then
		Aim.nextLook = now + 0.1
		Aim.target = FindAim(me)
	end
	local e = Aim.target
	if not IsValid(e) then return end
	local want = (PartPos(e, AimPart(me)[2]) - me:GetShootPos()):Angle()
	local cur = cmd:GetViewAngles()
	cmd:SetViewAngles(Angle(cur.p + math.AngleDifference(want.p, cur.p) * 0.4, cur.y + math.AngleDifference(want.y, cur.y) * 0.4, 0))
end)

local function DrawAim(me)
	local left = me:GetNW2Float("RMPG_AimUntil", 0) - CurTime()
	local w, x, y = 300, ScrW() / 2 - 150, 62
	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawRect(x, y, w, 8)
	surface.SetDrawColor(ACCENT)
	surface.DrawRect(x + 1, y + 1, (w - 2) * math.Clamp(left / math.max(RMPG.CV.patchAimTime:GetFloat(), 0.1), 0, 1), 6)
	draw.SimpleTextOutlined(string.format(RMPG.T("patch_aim_left"), RMPG.T(AimPart(me)[1]), math.ceil(left)), "RMPG_SmallB", ScrW() / 2, y + 20, ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
	local e = Aim.target
	if IsValid(e) then
		local p = PartPos(e, AimPart(me)[2]):ToScreen()
		if p.visible then
			surface.SetDrawColor(ACCENT)
			surface.DrawOutlinedRect(p.x - 14, p.y - 14, 28, 28, 2)
		end
	end
end

local TITLES = { [PORTAL] = "patch_a_portal", [XRAY] = "patch_a_xray", [HACK] = "patch_a_hack", [SCAN] = "patch_a_scan", [CAMERA] = "patch_a_camera", [BINOC] = "patch_a_binoc" }

hook.Add("HUDPaint", "rmpg_patch", function()
	local me = LocalPlayer()
	if AimOn(me) then DrawAim(me) end
	local mode = Mode()
	if mode == 0 then return end
	Scan()
	if mode == XRAY then
		DrawThermal()
	elseif mode == SCAN then
		DrawScan()
	elseif mode == HACK then
		DrawHack()
	elseif mode == CAMERA then
		DrawCamera()
	elseif mode == BINOC then
		DrawBinoculars()
	else
		DrawPortalView()
	end
	draw.SimpleTextOutlined(RMPG.T(TITLES[mode]), "RMPG_SmallB", ScrW() / 2, 40, ACCENT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)

---------------------------------------------------------------------------
-- The editor
---------------------------------------------------------------------------

local LABELS = {
	pf = "patch_e_forward", pr = "patch_e_right", pu = "patch_e_up", pyaw = "patch_e_yaw", ppitch = "patch_e_pitch", proll = "patch_e_roll", psize = "patch_e_size",
	sf = "patch_e_forward", sr = "patch_e_right", su = "patch_e_up", sx = "patch_e_radx", sy = "patch_e_rady", sw = "patch_e_width", spitch = "patch_e_pitch", sroll = "patch_e_roll",
}
local PAD_KEYS = { "pf", "pr", "pu", "pyaw", "ppitch", "proll", "psize" }
local STRAP_KEYS = { "sf", "sr", "su", "sx", "sy", "sw", "spitch", "sroll" }

local function Field(key)
	for _, f in ipairs(RMPG.PATCH_FIELDS) do
		if f[1] == key then return f end
	end
end

function RMPG.OpenPatchEditor()
	if IsValid(RMPG.PatchFrame_) then RMPG.PatchFrame_:Remove() end
	local me = LocalPlayer()
	local cfg = RMPG.PatchParse(CFG:GetString())
	local W, H = math.min(960, ScrW() - 40), math.min(660, ScrH() - 40)
	local LW = math.floor(W * 0.52)
	local f = vgui.Create("EditablePanel")
	RMPG.PatchFrame_ = f
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()
	f.Paint = function(s, w, h)
		RMPG.HoloBox(0, 0, w, h, BG, ACCENT)
		RMPG.HoloText(RMPG.T("patch_e_title"), "RMPG_Title", 20, 14, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(RMPG.T("patch_e_hint"), "RMPG_Small", 20, h - 24, MUTED)
	end
	f.Think = function(s)
		if input.IsKeyDown(KEY_ESCAPE) then
			gui.HideGameUI()
			s:Remove()
		end
	end

	local function Save(final)
		CFG:SetString(RMPG.PatchString(cfg))
		if final and Worn(me) then Send(RMPG.PATCH_A_CFG, function() net.WriteString(RMPG.PatchString(cfg)) end) end
	end

	-- the head
	local model = ClientsideModel(me:GetModel(), RENDERGROUP_OPAQUE)
	if not IsValid(model) then
		f:Remove()
		return
	end
	model:SetNoDraw(true)
	model:SetPos(vector_origin)
	model:SetAngles(angle_zero)
	model:SetSkin(me:GetSkin())
	for i = 0, me:GetNumBodyGroups() - 1 do model:SetBodygroup(i, me:GetBodygroup(i)) end
	model.GetPlayerColor = function() return me:GetPlayerColor() end
	local seq = model:LookupSequence("idle_all_01")
	if seq and seq >= 0 then model:ResetSequence(seq) end
	model:SetCycle(0)
	model:SetPlaybackRate(0)

	local which = "pad"
	local yaw, pitch, dist, fov = -28, -4, 34, 30
	local pv = vgui.Create("DPanel", f)
	pv:SetPos(20, 60)
	pv:SetSize(LW - 20, H - 96)
	pv:SetCursor("hand")
	pv.OnRemove = function() if IsValid(model) then model:Remove() end end

	local function Camera()
		model:SetupBones()
		local pos, ang = RMPG.PatchFrame(model)
		if not pos then pos, ang = Vector(0, 0, 66), angle_zero end
		-- the middle of the head, not the neck
		local center = LocalToWorld(Vector(1, 0, 3), angle_zero, pos, ang)
		local view = Angle(pitch, yaw, 0)
		local cp = center + view:Forward() * dist
		return cp, (center - cp):Angle(), pos, ang
	end

	pv.Paint = function(s, w, h)
		surface.SetDrawColor(BG.r, BG.g, BG.b, 245)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 90)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		local x, y = s:LocalToScreen(0, 0)
		local cp, ca = Camera()
		render.ClearDepth()
		render.SetScissorRect(x + 1, y + 1, x + w - 1, y + h - 1, true)
		cam.Start3D(cp, ca, fov, x, y, w, h, 1, 400)
			render.SuppressEngineLighting(true)
			render.SetLightingOrigin(vector_origin)
			render.ResetModelLighting(0.45, 0.45, 0.45)
			render.SetModelLighting(BOX_FRONT, 1, 1, 1)
			render.SetModelLighting(BOX_TOP, 0.9, 0.9, 0.9)
			model:DrawModel()
			DrawOn(model, cfg)
			render.SuppressEngineLighting(false)
		cam.End3D()
		render.SetScissorRect(0, 0, 0, 0, false)
	end
	pv.OnMousePressed = function(s, code)
		s.Drag = code == MOUSE_LEFT and "move" or (code == MOUSE_RIGHT and "orbit" or nil)
		s.LastX, s.LastY = input.GetCursorPos()
		s:MouseCapture(true)
	end
	pv.OnMouseReleased = function(s)
		if s.Drag == "move" then Save(true) end
		s.Drag = nil
		s:MouseCapture(false)
	end
	pv.OnMouseWheeled = function(s, d) dist = math.Clamp(dist - d * 3, 14, 80) end
	pv.Think = function(s)
		if not s.Drag then return end
		local mx, my = input.GetCursorPos()
		local dx, dy = mx - s.LastX, my - s.LastY
		s.LastX, s.LastY = mx, my
		if s.Drag == "orbit" then
			yaw = yaw - dx * 0.5
			pitch = math.Clamp(pitch + dy * 0.4, -60, 60)
			return
		end
		-- the mouse moves the piece in the plane of the view, in the head's own axes
		local _, ca, _, ha = Camera()
		local k = 2 * dist * math.tan(math.rad(fov / 2)) / s:GetTall()
		local d = ca:Right() * (dx * k) - ca:Up() * (dy * k)
		local a, b, c = "pf", "pr", "pu"
		if which == "strap" then a, b, c = "sf", "sr", "su" end
		for _, q in ipairs({ { a, ha:Forward() }, { b, ha:Right() }, { c, ha:Up() } }) do
			local fd = Field(q[1])
			cfg[q[1]] = math.Clamp(cfg[q[1]] + d:Dot(q[2]), fd[3], fd[4])
		end
		Save(false)
	end

	-- the settings: one page for the pad, one for the strap
	local side = vgui.Create("DPanel", f)
	side:SetPos(LW + 14, 60)
	side:SetSize(W - LW - 34, H - 96)
	side.Paint = function() end
	local pages = {}
	local function Page(id, keys)
		local sc = UI.Scroll(side)
		sc:Dock(FILL)
		sc:DockMargin(0, 8, 0, 8)
		for _, key in ipairs(keys) do
			local fd = Field(key)
			local sl = UI.Slider(sc, RMPG.T(LABELS[key]), fd[3], fd[4], 2, function() return cfg[key] end, function(v)
				cfg[key] = v
				Save(false)
			end, function() Save(true) end)
			sl:Dock(TOP)
			sl:DockMargin(0, 0, 8, 6)
		end
		pages[id] = sc
	end
	local tabs = UI.Segmented(side, RMPG.T("patch_e_what"), { { "pad", RMPG.T("patch_e_pad") }, { "strap", RMPG.T("patch_e_strap") } }, function() return which end, function(v)
		which = v
		for id, pg in pairs(pages) do pg:SetVisible(id == v) end
		side:InvalidateLayout()
	end)
	tabs:Dock(TOP)
	local bottom = vgui.Create("DPanel", side)
	bottom:Dock(BOTTOM)
	bottom:SetTall(44)
	bottom.Paint = function() end
	local done = UI.Button(bottom, RMPG.T("patch_e_done"), "accent", function()
		Save(true)
		f:Remove()
	end, "icon16/accept.png")
	done:Dock(RIGHT)
	done:SetWide(170)
	local reset = UI.Button(bottom, RMPG.T("patch_e_reset"), "tile", function()
		cfg = RMPG.PatchDefaults()
		Save(true)
	end, "icon16/arrow_undo.png")
	reset:Dock(LEFT)
	reset:SetWide(170)
	Page("pad", PAD_KEYS)
	Page("strap", STRAP_KEYS)
	pages.strap:SetVisible(false)
end

concommand.Add("rmpg_patch_editor", function() RMPG.OpenPatchEditor() end)

-- The colour of the interface, for the C menu and Utilities: each player's own
function RMPG.PatchColorUI(panel)
	panel:Help(RMPG.T("patch_color"))
	local mix = vgui.Create("DColorMixer", panel)
	mix:SetAlphaBar(false)
	mix:SetPalette(true)
	mix:SetWangs(true)
	mix:SetConVarR("rmpg_patch_r")
	mix:SetConVarG("rmpg_patch_g")
	mix:SetConVarB("rmpg_patch_b")
	mix:SetTall(180)
	panel:AddItem(mix)
	local reset = panel:Button(RMPG.T("patch_color_reset"))
	reset.DoClick = function()
		for _, cv in ipairs({ COL_R, COL_G, COL_B }) do cv:SetString(cv:GetDefault()) end
		mix:SetColor(Color(COL_R:GetDefault(), COL_G:GetDefault(), COL_B:GetDefault()))
	end
end
