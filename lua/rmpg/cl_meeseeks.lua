-- Client: Mr. Meeseeks - the job window (E on your Meeseeks), the box HUD and markers for what they found
RMPG = RMPG or {}
local UI = RMPG.UI

local BG     = Color(3, 12, 20, 236)
local PANEL  = Color(6, 26, 40, 200)
local EDGE   = Color(100, 210, 255)
local EDGE_D = Color(40, 120, 170)
local TEXT   = Color(225, 246, 255)
local MUTED  = Color(130, 190, 215)
local RED    = Color(255, 64, 84)
local MR_DISMISS = 15

surface.CreateFont("RMPG_MrTitle", { font = "Trebuchet MS", size = 30, weight = 900, extended = true, antialias = true })
surface.CreateFont("RMPG_MrHead", { font = "Trebuchet MS", size = 22, weight = 900, extended = true, antialias = true })

-- Jobs in the window: id, language key, icon
local JOBS = {
	{ RMPG.MR_KILL, "mr_job_1", "icon16/gun.png" },
	{ RMPG.MR_FINDPROP, "mr_job_2", "icon16/box.png" },
	{ RMPG.MR_MAKE, "mr_job_3", "icon16/wrench.png" },
	{ RMPG.MR_FINDENT, "mr_job_4", "icon16/magnifier.png" },
	{ RMPG.MR_PROTECT, "mr_job_5", "icon16/shield.png" },
	{ RMPG.MR_GUARD, "mr_job_6", "icon16/flag_blue.png" },
	{ RMPG.MR_HEAL, "mr_job_7", "icon16/heart.png" },
	{ RMPG.MR_DISTRACT, "mr_job_8", "icon16/sound.png" },
}

-- Props he can make without typing a model path
local MAKE_PROPS = {
	"models/props_c17/oildrum001.mdl", "models/props_c17/oildrum001_explosive.mdl", "models/props_junk/wood_crate001a.mdl",
	"models/props_c17/furniturechair001a.mdl", "models/props_c17/furnituretable001a.mdl", "models/props_c17/furniturecouch001a.mdl",
	"models/props_interiors/bathtub01a.mdl", "models/props_junk/watermelon01.mdl", "models/props_junk/trafficcone001a.mdl",
	"models/props_c17/doll01.mdl", "models/props_lab/monitor01a.mdl", "models/props_junk/plasticcrate01a.mdl",
	"models/props_c17/concrete_barrier001a.mdl", "models/props_wasteland/kitchen_fridge001a.mdl", "models/props_c17/furniturewashingmachine001a.mdl",
	"models/props_junk/sawblade001a.mdl", "models/props_vehicles/carparts_tire01a.mdl", "models/props_junk/propane_tank001a.mdl",
	"models/props_c17/gravestone001a.mdl", "models/props_lab/huladoll.mdl", "models/props_c17/furnituredrawer001a.mdl",
	"models/props_junk/garbage_takeoutcarton001a.mdl", "models/props_c17/lockers001a.mdl", "models/props_junk/metal_paintcan001a.mdl",
}

local function Nice(class)
	local p = language.GetPhrase(class)
	if p and p ~= class and p ~= "" then return p end
	return class
end

local function Wrap(text, font, width)
	surface.SetFont(font)
	local lines, cur = {}, ""
	for word in string.gmatch(text, "%S+") do
		local test = cur == "" and word or (cur .. " " .. word)
		if surface.GetTextSize(test) > width and cur ~= "" then
			lines[#lines + 1] = cur
			cur = word
		else
			cur = test
		end
	end
	if cur ~= "" then lines[#lines + 1] = cur end
	return lines
end

-- A list of selectable rows; returns the scroll panel
local function RowList(parent, rows, sel, key)
	local sc = UI.Scroll(parent)
	sc:Dock(FILL)
	local buttons = {}
	for _, r in ipairs(rows) do
		local b = UI.Button(sc, r.text, "dark", function(btn)
			sel[key] = r.value
			for _, o in ipairs(buttons) do o.Kind = "dark" end
			btn.Kind = "accent"
		end, r.icon)
		b:Dock(TOP)
		b:DockMargin(0, 0, 8, 6)
		b:SetTall(38)
		buttons[#buttons + 1] = b
		if sel[key] ~= nil and sel[key] == r.value then b.Kind = "accent" end
	end
	if #rows == 0 then
		local e = vgui.Create("DLabel", sc)
		e:Dock(TOP)
		e:SetTall(40)
		e:SetFont("RMPG_Body")
		e:SetTextColor(MUTED)
		e:SetText(RMPG.T("mr_none"))
	end
	return sc
end

-- A grid of model icons; picking one stores its model
local function IconGrid(parent, models, sel, key, counts)
	local sc = UI.Scroll(parent)
	sc:Dock(FILL)
	local layout = vgui.Create("DIconLayout", sc)
	layout:Dock(TOP)
	layout:SetSpaceX(6)
	layout:SetSpaceY(6)
	for i, m in ipairs(models) do
		local icon = layout:Add("SpawnIcon")
		icon:SetSize(72, 72)
		icon:SetModel(m)
		icon:SetTooltip(m .. (counts and ("  ×" .. counts[i]) or ""))
		icon.DoClick = function()
			sel[key] = m
			surface.PlaySound(RMPG.SND.uiClick)
		end
		icon.PaintOver = function(s, w, h)
			if sel[key] == m then
				surface.SetDrawColor(EDGE)
				surface.DrawOutlinedRect(0, 0, w, h, 3)
			end
			if counts then draw.SimpleTextOutlined("×" .. counts[i], "RMPG_SmallB", w - 4, h - 3, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black) end
		end
	end
	if #models == 0 then
		local e = vgui.Create("DLabel", sc)
		e:Dock(TOP)
		e:SetTall(40)
		e:SetFont("RMPG_Body")
		e:SetTextColor(MUTED)
		e:SetText(RMPG.T("mr_none"))
	end
	return sc
end

local function AimedModel()
	local e = LocalPlayer():GetEyeTrace().Entity
	if IsValid(e) and string.find(e:GetClass(), "^prop_physics") then return e:GetModel() end
end

-- Content of the right side for each job; fills sel with what to send
local BUILD = {}

BUILD[RMPG.MR_KILL] = function(p, sel, data)
	local rows = { { text = RMPG.T("mr_nearest_enemy"), value = 0, icon = "icon16/exclamation.png" } }
	for _, t in ipairs(data.targets) do
		local name = t.player and t.name or Nice(t.name)
		rows[#rows + 1] = {
			text = string.format("%s   ·   %s   ·   HP %d", name, RMPG.T("meters", math.floor(t.dist / RMPG.UNITS_PER_METER)), math.max(t.hp, 0)),
			value = t.idx, icon = t.player and "icon16/user_red.png" or "icon16/bug.png",
		}
	end
	sel.target = sel.target or 0
	RowList(p, rows, sel, "target")
end

BUILD[RMPG.MR_FINDPROP] = function(p, sel, data)
	local bar = vgui.Create("DPanel", p)
	bar:Dock(TOP)
	bar:SetTall(40)
	bar:DockMargin(0, 0, 0, 8)
	bar.Paint = function() end
	local b = UI.Button(bar, RMPG.T("mr_aim_prop"), "tile", function()
		local m = AimedModel()
		if m then sel.model = m else RMPG.AddNote(RMPG.T("mr_aim_none"), 1) end
	end, "icon16/eye.png")
	b:Dock(LEFT)
	b:SetWide(300)
	local models, counts = {}, {}
	for _, pr in ipairs(data.props) do
		models[#models + 1] = pr.model
		counts[#counts + 1] = pr.count
	end
	IconGrid(p, models, sel, "model", counts)
end

local function Title(name, class)
	name = name or class
	if string.sub(name, 1, 1) == "#" then name = language.GetPhrase(string.sub(name, 2)) end
	return name
end

-- What can be picked of one kind (1 weapons, 2 entities, 3 NPCs), without what the server has banned
local function Makeable(kind)
	local admin = LocalPlayer():IsAdmin()
	local all = {}
	if kind == 1 then
		for class, w in pairs(list.Get("Weapon")) do
			if ((w.Spawnable and not w.AdminOnly) or admin) and not RMPG.MrBanned(1, class) then
				all[#all + 1] = { text = Title(w.PrintName, class) .. "   ·   " .. (w.Category or ""), value = class, icon = "icon16/bomb.png" }
			end
		end
	elseif kind == 2 then
		for class, w in pairs(list.Get("SpawnableEntities")) do
			if (not w.AdminOnly or admin) and not RMPG.MrBanned(2, class) then
				all[#all + 1] = { text = Title(w.PrintName, class) .. "   ·   " .. (w.Category or ""), value = class, icon = "icon16/brick_add.png" }
			end
		end
	else
		for class, w in pairs(list.Get("NPC")) do
			if (not w.AdminOnly or admin) and not RMPG.MrBanned(3, class) and not RMPG.MrBanned(3, w.Class) then
				all[#all + 1] = { text = Title(w.Name, class) .. "   ·   " .. (w.Category or ""), value = class, icon = "icon16/user_red.png" }
			end
		end
	end
	table.sort(all, function(x, y) return x.text < y.text end)
	return all
end

local function Line(body, text, col)
	local l = vgui.Create("DLabel", body)
	l:Dock(TOP)
	l:SetTall(24)
	l:SetFont("RMPG_Small")
	l:SetTextColor(col)
	l:SetText(text)
end

BUILD[RMPG.MR_MAKE] = function(p, sel, data)
	sel.kind = sel.kind or 0
	local tabs = vgui.Create("DPanel", p)
	tabs:Dock(TOP)
	tabs:SetTall(40)
	tabs:DockMargin(0, 0, 0, 8)
	tabs.Paint = function() end
	local body = vgui.Create("DPanel", p)
	body:Dock(FILL)
	body.Paint = function() end
	local buttons = {}
	local OFF = { [1] = { RMPG.CV.mrWeapons, "n_mr_no_weapons" }, [2] = { RMPG.CV.mrMakeEnts, "n_mr_no_ents" }, [3] = { RMPG.CV.mrMakeNPCs, "n_mr_no_npcs" } }
	local function Show(kind)
		sel.kind = kind
		sel.value = nil
		for k, b in pairs(buttons) do b.Kind = k == kind and "accent" or "tile" end
		body:Clear()
		if kind == 0 then
			local row = vgui.Create("DPanel", body)
			row:Dock(TOP)
			row:SetTall(38)
			row:DockMargin(0, 0, 0, 8)
			row.Paint = function() end
			local entry = UI.Entry(row, RMPG.T("mr_model_ph"))
			local aim = UI.Button(row, RMPG.T("mr_copy_aim"), "tile", function()
				local m = AimedModel()
				if m then entry:SetValue(m) sel.value = m else RMPG.AddNote(RMPG.T("mr_aim_none"), 1) end
			end, "icon16/eye.png")
			aim:Dock(RIGHT)
			aim:SetWide(230)
			aim:DockMargin(8, 0, 0, 0)
			entry:Dock(FILL)
			entry:SetUpdateOnType(true)
			entry.OnValueChange = function(s, v) if v ~= "" then sel.value = string.Trim(v) end end
			local allowed = {}
			for _, m in ipairs(MAKE_PROPS) do
				if not RMPG.MrBanned(0, m) then allowed[#allowed + 1] = m end
			end
			IconGrid(body, allowed, sel, "value")
			return
		end
		if not OFF[kind][1]:GetBool() then
			Line(body, RMPG.T(OFF[kind][2]), RED)
			return
		end
		if kind == 3 then Line(body, RMPG.T("mr_npcs_note"), Color(255, 200, 90)) end
		local search = UI.Entry(body, RMPG.T("mr_search_ph"))
		search:Dock(TOP)
		search:SetTall(38)
		search:DockMargin(0, 0, 0, 8)
		local holder = vgui.Create("DPanel", body)
		holder:Dock(FILL)
		holder.Paint = function() end
		local all = Makeable(kind)
		local function Fill()
			holder:Clear()
			local q = string.lower(search:GetValue() or "")
			local rows = {}
			for _, r in ipairs(all) do
				if q == "" or string.find(string.lower(r.text .. r.value), q, 1, true) then rows[#rows + 1] = r end
				if #rows >= 80 then break end
			end
			RowList(holder, rows, sel, "value")
		end
		search:SetUpdateOnType(true)
		search.OnValueChange = Fill
		Fill()
	end
	for i, t in ipairs({ { 0, "mr_props", "icon16/brick.png" }, { 1, "mr_weapons", "icon16/bomb.png" }, { 2, "mr_ents", "icon16/brick_add.png" }, { 3, "mr_npcs", "icon16/user_red.png" } }) do
		local b = UI.Button(tabs, RMPG.T(t[2]), t[1] == 0 and "accent" or "tile", function() Show(t[1]) end, t[3])
		b:Dock(LEFT)
		b:SetWide(146)
		if i > 1 then b:DockMargin(8, 0, 0, 0) end
		buttons[t[1]] = b
	end
	Show(0)
end

BUILD[RMPG.MR_FINDENT] = function(p, sel, data)
	local rows = {}
	for _, c in ipairs(data.classes) do
		rows[#rows + 1] = { text = string.format("%s   ·   %s   ×%d", Nice(c.class), c.class, c.count), value = c.class, icon = "icon16/find.png" }
	end
	RowList(p, rows, sel, "class")
end

BUILD[RMPG.MR_PROTECT] = function(p, sel, data)
	local me = LocalPlayer()
	local rows = { { text = RMPG.T("mr_me"), value = me:EntIndex(), icon = "icon16/user.png" } }
	for _, ply in ipairs(player.GetAll()) do
		if ply ~= me then rows[#rows + 1] = { text = ply:Nick(), value = ply:EntIndex(), icon = "icon16/user_green.png" } end
	end
	sel.target = sel.target or me:EntIndex()
	RowList(p, rows, sel, "target")
end

BUILD[RMPG.MR_GUARD] = function(p, sel, data)
	sel.aim = sel.aim or 0
	RowList(p, {
		{ text = RMPG.T("mr_here"), value = 0, icon = "icon16/user.png" },
		{ text = RMPG.T("mr_aim"), value = 1, icon = "icon16/eye.png" },
	}, sel, "aim")
end

BUILD[RMPG.MR_HEAL] = function() end
BUILD[RMPG.MR_DISTRACT] = function() end

-- What to send for the chosen job; nil when something still has to be picked
local function Payload(job, sel)
	if job == RMPG.MR_KILL then
		return function() net.WriteUInt(sel.target or 0, 16) end
	elseif job == RMPG.MR_FINDPROP then
		if not sel.model then return end
		return function() net.WriteString(sel.model) end
	elseif job == RMPG.MR_MAKE then
		if not sel.value or sel.value == "" then return end
		return function() net.WriteUInt(sel.kind or 0, 2) net.WriteString(sel.value) end
	elseif job == RMPG.MR_FINDENT then
		if not sel.class then return end
		return function() net.WriteString(sel.class) end
	elseif job == RMPG.MR_PROTECT then
		return function() net.WriteUInt(sel.target or LocalPlayer():EntIndex(), 16) end
	elseif job == RMPG.MR_GUARD then
		return function() net.WriteUInt(sel.aim or 0, 1) end
	end
	return function() end
end

local function Send(mr, job, write)
	net.Start("rmpg_mr_task")
	net.WriteEntity(mr)
	net.WriteUInt(job, 4)
	if write then write() end
	net.SendToServer()
end

function RMPG.OpenMeeseeksMenu(mr, data)
	if IsValid(RMPG.MrFrame) then RMPG.MrFrame:Remove() end
	local W, H = math.min(940, ScrW() - 40), math.min(600, ScrH() - 40)
	local f = vgui.Create("EditablePanel")
	RMPG.MrFrame = f
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()
	f.Paint = function(s, w, h)
		surface.SetMaterial(RMPG.Mat.glow2D)
		surface.SetDrawColor(60, 180, 255, 30)
		surface.DrawTexturedRect(-w * 0.2, -h * 0.3, w * 1.4, h * 1.6)
		RMPG.HoloBox(0, 0, w, h, BG, EDGE)
		RMPG.HoloText(RMPG.T("mr_title"), "RMPG_MrTitle", 22, 16, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(RMPG.T("mr_sub"), "RMPG_Body", 24, 50, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	f.Think = function(s)
		if not IsValid(mr) or LocalPlayer():GetPos():DistToSqr(mr:GetPos()) > 500 * 500 or input.IsKeyDown(KEY_ESCAPE) then
			if input.IsKeyDown(KEY_ESCAPE) then gui.HideGameUI() end
			s:Remove()
		end
	end
	f.OnRemove = function() if RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiClose) end end
	if RMPG.CL.uisounds:GetBool() then surface.PlaySound(RMPG.SND.uiOpen) end

	local close = UI.Button(f, "", "dark", function() f:Remove() end, "icon16/cross.png")
	close:SetPos(W - 56, 16)
	close:SetSize(40, 36)

	local sel = { job = RMPG.MR_KILL }
	local left = vgui.Create("DPanel", f)
	left:SetPos(16, 84)
	left:SetSize(250, H - 84 - 76)
	left.Paint = function() end
	local right = vgui.Create("DPanel", f)
	right:SetPos(280, 84)
	right:SetSize(W - 296, H - 84 - 76)
	right.Paint = function(s, w, h)
		RMPG.HoloBox(0, 0, w, h, PANEL, EDGE_D)
		local name = RMPG.T("mr_job_" .. sel.job)
		RMPG.HoloText(name, "RMPG_MrHead", 16, 12, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		for i, l in ipairs(Wrap(RMPG.T("mr_job_" .. sel.job .. "_desc"), "RMPG_Small", w - 32)) do
			draw.SimpleText(l, "RMPG_Small", 16, 42 + (i - 1) * 16, MUTED)
		end
	end
	local content = vgui.Create("DPanel", right)
	content:Dock(FILL)
	content:DockMargin(14, 82, 6, 12)
	content.Paint = function() end

	local jobButtons = {}
	local function Pick(id)
		sel = { job = id }
		for _, b in ipairs(jobButtons) do b.Kind = b.JobId == id and "accent" or "tile" end
		content:Clear()
		BUILD[id](content, sel, data)
	end
	for _, j in ipairs(JOBS) do
		local b = UI.Button(left, RMPG.T(j[2]), "tile", function() Pick(j[1]) end, j[3])
		b.JobId = j[1]
		b:SetEnabled(not RMPG.MrJobOff(j[1]))
		b:Dock(TOP)
		b:DockMargin(0, 0, 0, 6)
		b:SetTall(math.floor((left:GetTall() - 6 * #JOBS) / #JOBS))
		jobButtons[#jobButtons + 1] = b
	end

	local go = UI.Button(f, RMPG.T("mr_go"), "accent", function()
		local write = Payload(sel.job, sel)
		if not write then
			RMPG.AddNote(RMPG.T("mr_pick_first"), 1)
			return
		end
		Send(mr, sel.job, write)
		f:Remove()
	end, "icon16/accept.png")
	go:SetPos(W - 16 - 260, H - 60)
	go:SetSize(260, 44)
	local bye = UI.Button(f, RMPG.T("mr_dismiss"), "danger", function()
		Send(mr, MR_DISMISS)
		f:Remove()
	end, "icon16/weather_clouds.png")
	bye:SetPos(16, H - 60)
	bye:SetSize(250, 44)

	local first = RMPG.MR_KILL
	for _, j in ipairs(JOBS) do
		if not RMPG.MrJobOff(j[1]) then
			first = j[1]
			break
		end
	end
	Pick(first)
end

-- The settings: what the server forbids Meeseeks (C menu and Utilities)
local BAN_LISTS = { { 0, "mrBanProps", "mr_ban_props" }, { 1, "mrBanWeapons", "mr_ban_weapons" }, { 2, "mrBanEnts", "mr_ban_ents" }, { 3, "mrBanNPCs", "mr_ban_npcs" } }

local function SendBan(which, value)
	net.Start("rmpg_mr_ban")
	net.WriteUInt(which, 3)
	net.WriteString(value)
	net.SendToServer()
end

function RMPG.MeeseeksBlacklistUI(panel, canEdit)
	panel:Help(RMPG.T("mr_ban_title"))
	panel:ControlHelp(RMPG.T("mr_ban_jobs"))
	local off = {}
	for part in string.gmatch(RMPG.CV.mrBanJobs:GetString(), "[^,]+") do
		if tonumber(part) then off[tonumber(part)] = true end
	end
	for _, j in ipairs(JOBS) do
		local c = vgui.Create("DCheckBoxLabel", panel)
		c:SetText(RMPG.T(j[2]))
		c:SetDark(true)
		c:SetValue(not off[j[1]])
		c.OnChange = function(s, v)
			off[j[1]] = not v or nil
			local ids = {}
			for id in pairs(off) do ids[#ids + 1] = tostring(id) end
			SendBan(4, table.concat(ids, ","))
		end
		panel:AddItem(c)
		if not canEdit then
			c:SetMouseInputEnabled(false)
			c:SetAlpha(130)
		end
	end
	panel:ControlHelp(RMPG.T("mr_ban_hint"))
	for _, l in ipairs(BAN_LISTS) do
		panel:Help(RMPG.T(l[3]))
		local entry = vgui.Create("DTextEntry", panel)
		entry:SetTall(54)
		entry:SetMultiline(true)
		entry:SetValue(RMPG.CV[l[2]]:GetString())
		entry:SetEnabled(canEdit)
		panel:AddItem(entry)
		local aim = panel:Button(RMPG.T("mr_ban_aim"))
		aim.DoClick = function()
			local e = LocalPlayer():GetEyeTrace().Entity
			if not IsValid(e) then return end
			local what = l[1] == 0 and e:GetModel() or e:GetClass()
			if not what then return end
			local v = string.Trim(entry:GetValue())
			entry:SetValue((v ~= "" and (v .. ", ") or "") .. what)
		end
		aim:SetEnabled(canEdit)
		local save = panel:Button(RMPG.T("mr_ban_save"))
		save.DoClick = function()
			SendBan(l[1], (string.gsub(entry:GetValue(), "[\r\n]+", ",")))
		end
		save:SetEnabled(canEdit)
	end
end

net.Receive("rmpg_mr_menu", function()
	local mr = net.ReadEntity()
	local data = { targets = {}, props = {}, classes = {} }
	for i = 1, net.ReadUInt(6) do
		data.targets[i] = { idx = net.ReadUInt(16), name = net.ReadString(), dist = net.ReadFloat(), hp = net.ReadInt(17), player = net.ReadBool() }
	end
	for i = 1, net.ReadUInt(6) do
		data.props[i] = { model = net.ReadString(), count = net.ReadUInt(10) }
	end
	for i = 1, net.ReadUInt(6) do
		data.classes[i] = { class = net.ReadString(), count = net.ReadUInt(10) }
	end
	if IsValid(mr) then RMPG.OpenMeeseeksMenu(mr, data) end
end)

---------------------------------------------------------------------------
-- HUD: your Meeseeks (while holding the box) and markers for what they found
---------------------------------------------------------------------------

function RMPG.MyMeeseeks()
	local me = LocalPlayer()
	local list = {}
	for _, m in ipairs(ents.FindByClass(RMPG.MEESEEKS)) do
		if m.GetMaster and m:GetMaster() == me then list[#list + 1] = m end
	end
	return list
end

local function JobText(m)
	local t = m:GetTask()
	if m:GetFrenzy() then return RMPG.T("mr_hud_frenzy") end
	if t == 0 then return RMPG.T("mr_hud_waiting") end
	local info = m:GetTaskInfo()
	if info ~= "" then info = Nice(info) end
	return RMPG.T("mr_job_" .. t) .. (info ~= "" and (": " .. info) or "")
end

function RMPG.DrawMeeseeksHUD()
	if not RMPG.CL.hud:GetBool() then return end
	local list = RMPG.MyMeeseeks()
	local now = RealTime()
	local rows = math.max(#list, 1)
	local w, h = 360, 70 + rows * 24
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	surface.SetMaterial(RMPG.Mat.glow2D)
	surface.SetDrawColor(60, 180, 255, 26)
	surface.DrawTexturedRect(x - 80, y - 80, 300, 300)
	RMPG.HoloBox(x, y, w, h, Color(3, 12, 20, 215), EDGE)
	RMPG.HoloText(RMPG.T("mr_hud_title"), "RMPG_SmallB", x + 16, y + 12, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	RMPG.HoloText(#list .. " / " .. RMPG.CV.mrMax:GetInt(), "RMPG_Head", x + w - 16, y + 8, TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	if #list == 0 then
		draw.SimpleText(RMPG.T("mr_hud_none"), "RMPG_Small", x + 16, y + 40, MUTED)
	end
	for i, m in ipairs(list) do
		local ty = y + 36 + (i - 1) * 24
		local frenzy = m:GetFrenzy()
		local col = frenzy and Color(RED.r, RED.g, RED.b, 150 + 105 * math.abs(math.sin(now * 8))) or (m:GetTask() == 0 and MUTED or TEXT)
		surface.SetDrawColor(frenzy and RED or EDGE)
		surface.DrawRect(x + 16, ty + 6, 6, 6)
		local txt = JobText(m)
		if #txt > 44 then txt = string.sub(txt, 1, 43) .. "…" end
		draw.SimpleText(txt, "RMPG_Small", x + 30, ty, col)
	end
	draw.SimpleText(RMPG.T("mr_hud_hint"), "RMPG_Small", x + 16, y + h - 22, MUTED)
end

local function Marker(pos, text, col)
	local sp = pos:ToScreen()
	if not sp.visible then return end
	local x, y = math.floor(sp.x), math.floor(sp.y)
	surface.SetDrawColor(col)
	surface.DrawLine(x - 9, y, x, y - 9) surface.DrawLine(x, y - 9, x + 9, y)
	surface.DrawLine(x + 9, y, x, y + 9) surface.DrawLine(x, y + 9, x - 9, y)
	RMPG.HoloText(text, "RMPG_SmallB", x, y - 14, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end

hook.Add("HUDPaint", "rmpg_meeseeks", function()
	local me = LocalPlayer()
	for _, m in ipairs(RMPG.MyMeeseeks()) do
		local found = m:GetFound()
		if IsValid(found) then
			local d = math.floor(me:GetPos():Distance(found:GetPos()) / RMPG.UNITS_PER_METER)
			Marker(found:WorldSpaceCenter() + Vector(0, 0, 20), Nice(found:GetClass()) .. " · " .. RMPG.T("meters", d), EDGE)
		end
		if m:GetFrenzy() then
			Marker(m:WorldSpaceCenter() + Vector(0, 0, 60), RMPG.T("mr_hud_frenzy"), RED)
		end
	end
end)
