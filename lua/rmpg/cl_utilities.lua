-- Client: settings in the spawn menu, Q -> Utilities -> Rick and Morty.
-- Server settings are sliders that ask the server to change its convars (only a superadmin may; the server checks).
RMPG = RMPG or {}

local function SvSet(name, v)
	net.Start("rmpg_svset")
	net.WriteString(name)
	net.WriteString(tostring(v))
	net.SendToServer()
end

local function CanEdit()
	return IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin()
end

local function Group(name)
	if string.sub(name, 1, 10) == "rmpg_bomb_" then return "bomb" end
	if string.sub(name, 1, 12) == "rmpg_shield_" then return "shield" end
	if string.sub(name, 1, 8) == "rmpg_mr_" then return "meeseeks" end
	if string.sub(name, 1, 12) == "rmpg_freeze_" then return "freeze" end
	if string.sub(name, 1, 9) == "rmpg_phx_" then return "phx" end
	if string.sub(name, 1, 10) == "rmpg_pill_" then return "pill" end
	if string.sub(name, 1, 14) == "rmpg_neutrino_" then return "neutrino" end
	if string.sub(name, 1, 11) == "rmpg_laser_" then return "laser" end
	if string.sub(name, 1, 10) == "rmpg_worm_" then return "worm" end
	if string.sub(name, 1, 11) == "rmpg_clone_" then return "clone" end
	if string.sub(name, 1, 11) == "rmpg_patch_" then return "patch" end
	if string.sub(name, 1, 10) == "rmpg_evac_" then return "evac" end
	if string.sub(name, 1, 12) == "rmpg_implant" then return "implant" end
	if string.sub(name, 1, 13) == "rmpg_timestop" then return "timestop" end
	if string.sub(name, 1, 11) == "rmpg_drone_" then return "drone" end
	return "gun"
end

-- The control shows the server's value unless you are dragging it or a change is on its way
local function Busy(self)
	return (self.PendingUntil or 0) > RealTime() or (self.IsEditing and self:IsEditing())
end

local function ServerSlider(panel, def)
	local name, dec = def[1], def[5] or 0
	local cv = GetConVar(name)
	if not cv then return end
	local s = vgui.Create("DNumSlider", panel)
	s:SetText(RMPG.T("sv_" .. name))
	s:SetMinMax(def[3], def[4])
	s:SetDecimals(dec)
	s:SetDark(true)
	s:SetTooltip(cv:GetHelpText())
	s:SetValue(cv:GetFloat())
	s.OnValueChanged = function(self, v)
		if self.Syncing then return end
		self.PendingUntil = RealTime() + 1.5
		timer.Create("rmpg_util_" .. name, 0.4, 1, function() SvSet(name, math.Round(v, dec)) end)
	end
	local base = s.Think
	s.Think = function(self)
		if base then base(self) end
		if Busy(self) then return end
		local v = cv:GetFloat()
		if math.abs(self:GetValue() - v) > 10 ^ -(dec + 1) then
			self.Syncing = true
			self:SetValue(v)
			self.Syncing = false
		end
	end
	panel:AddItem(s)
	return s
end

local function ServerCheck(panel, def)
	local name = def[1]
	local cv = GetConVar(name)
	if not cv then return end
	local c = vgui.Create("DCheckBoxLabel", panel)
	c:SetText(RMPG.T("sv_" .. name))
	c:SetDark(true)
	c:SetTooltip(cv:GetHelpText())
	c:SetValue(cv:GetBool())
	c.OnChange = function(self, v)
		if self.Syncing then return end
		self.PendingUntil = RealTime() + 1.5
		SvSet(name, v and 1 or 0)
	end
	c.Think = function(self)
		if Busy(self) or self:GetChecked() == cv:GetBool() then return end
		self.Syncing = true
		self:SetValue(cv:GetBool())
		self.Syncing = false
	end
	panel:AddItem(c)
	return c
end

local function ServerPanel(panel, group)
	panel:ClearControls()
	panel:Help(RMPG.T("cfg_" .. group .. "_help"))
	local edit = CanEdit()
	if not edit then
		local l = panel:Help(RMPG.T("cfg_admin_only"))
		l:SetTextColor(Color(200, 40, 40))
	end
	local defs = {}
	for _, d in ipairs(RMPG.SERVER_SETTINGS) do
		if Group(d[1]) == group then
			defs[#defs + 1] = d
			local ctl = d[2] == "bool" and ServerCheck(panel, d) or ServerSlider(panel, d)
			if ctl and not edit then
				ctl:SetMouseInputEnabled(false)
				ctl:SetAlpha(130)
			end
		end
	end
	local reset = panel:Button(RMPG.T("cfg_reset"))
	reset.DoClick = function()
		-- one request at a time: the server rate-limits setting changes
		for i, d in ipairs(defs) do
			timer.Simple(i * 0.1, function()
				local cv = GetConVar(d[1])
				if cv then SvSet(d[1], cv:GetDefault()) end
			end)
		end
	end
	reset:SetEnabled(edit)
end

local function ClientPanel(panel)
	panel:ClearControls()
	panel:Help(RMPG.T("purpose"))
	panel:Button(RMPG.T("menu_title"), "rmpg_menu", "home")
	panel:Button(RMPG.T("tab_binds"), "rmpg_menu", "binds")
	local lang = panel:ComboBox(RMPG.T("set_language"), "rmpg_lang")
	lang:AddChoice(RMPG.T("lang_auto"), "auto")
	lang:AddChoice(RMPG.T("lang_ru"), "ru")
	lang:AddChoice(RMPG.T("lang_en"), "en")
	panel:CheckBox(RMPG.T("set_vertical"), "rmpg_vertical_front")
	panel:CheckBox(RMPG.T("set_preview"), "rmpg_preview")
	panel:CheckBox(RMPG.T("set_hands"), "rmpg_hands")
	panel:CheckBox(RMPG.T("set_outline"), "rmpg_toon_outline")
	panel:CheckBox(RMPG.T("set_hud"), "rmpg_hud")
	panel:CheckBox(RMPG.T("set_particles"), "rmpg_particles")
	panel:CheckBox(RMPG.T("set_uisounds"), "rmpg_ui_sounds")
end

-- also used by the C menu window (cl_desktop.lua)
RMPG.ServerSettingsPanel = ServerPanel
RMPG.ClientSettingsPanel = ClientPanel
RMPG.CanEditServer = CanEdit

hook.Add("AddToolMenuCategories", "rmpg_toolmenu", function()
	spawnmenu.AddToolCategory("Utilities", "Rick and Morty", "Rick and Morty")
end)

hook.Add("PopulateToolMenu", "rmpg_toolmenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_options", RMPG.T("cfg_client"), "", "", ClientPanel)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_gun", RMPG.T("cfg_gun"), "", "", function(p) ServerPanel(p, "gun") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_bomb", RMPG.T("cfg_bomb"), "", "", function(p) ServerPanel(p, "bomb") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_shield", RMPG.T("cfg_shield"), "", "", function(p) ServerPanel(p, "shield") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_meeseeks", RMPG.T("cfg_meeseeks"), "", "", function(p)
		ServerPanel(p, "meeseeks")
		RMPG.MeeseeksBlacklistUI(p, CanEdit())
	end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_phx", RMPG.T("cfg_phx"), "", "", function(p)
		ServerPanel(p, "phx")
		if RMPG.PhoenixBlacklistUI then RMPG.PhoenixBlacklistUI(p, CanEdit()) end
	end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_pill", RMPG.T("cfg_pill"), "", "", function(p) ServerPanel(p, "pill") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_neutrino", RMPG.T("cfg_neutrino"), "", "", function(p) ServerPanel(p, "neutrino") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_laser", RMPG.T("cfg_laser"), "", "", function(p) ServerPanel(p, "laser") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_worm", RMPG.T("cfg_worm"), "", "", function(p) ServerPanel(p, "worm") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_clone", RMPG.T("cfg_clone"), "", "", function(p) ServerPanel(p, "clone") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_evac", RMPG.T("cfg_evac"), "", "", function(p) ServerPanel(p, "evac") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_implant", RMPG.T("cfg_implant"), "", "", function(p) ServerPanel(p, "implant") end)
	if RMPG.WIP_TIMESTOP then
		spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_timestop", RMPG.T("cfg_timestop"), "", "", function(p) ServerPanel(p, "timestop") end)
	end
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_patch", RMPG.T("cfg_patch"), "", "", function(p)
		p:Button(RMPG.T("patch_e_title"), "rmpg_patch_editor")
		p:Button(RMPG.T("patch_rec_title"), "rmpg_patch_recbind")
		ServerPanel(p, "patch")
		RMPG.PatchColorUI(p)
	end)
	if not RMPG.WIP then return end
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_freeze", RMPG.T("cfg_freeze"), "", "", function(p) ServerPanel(p, "freeze") end)
	spawnmenu.AddToolMenuOption("Utilities", "Rick and Morty", "rmpg_cfg_drone", RMPG.T("cfg_drone"), "", "", function(p) ServerPanel(p, "drone") end)
end)
