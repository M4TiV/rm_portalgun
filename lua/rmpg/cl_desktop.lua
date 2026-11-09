-- Client: the C menu window (hold C, the Rick and Morty icon at the top left) - every setting of the addon on tabs,
-- like Q -> Utilities, plus the friends list (trusted players) that drones, Meeseeks and shared locations use
RMPG = RMPG or {}
local UI = RMPG.UI

local GROUPS = {
	{ "gun", "cfg_gun", "icon16/wand.png" },
	{ "bomb", "cfg_bomb", "icon16/bomb.png" },
	{ "shield", "cfg_shield", "icon16/shield.png" },
	{ "meeseeks", "cfg_meeseeks", "icon16/user.png" },
	{ "phx", "cfg_phx", "icon16/heart.png" },
	{ "pill", "cfg_pill", "icon16/pill.png" },
	{ "neutrino", "cfg_neutrino", "icon16/weather_lightning.png" },
	{ "laser", "cfg_laser", "icon16/gun.png" },
	{ "worm", "cfg_worm", "icon16/bug.png" },
	{ "clone", "cfg_clone", "icon16/group.png" },
	{ "patch", "cfg_patch", "icon16/eye.png" },
	{ "evac", "cfg_evac", "icon16/transmit_blue.png" },
	{ "implant", "cfg_implant", "icon16/lightning.png" },
}
if RMPG.WIP_TIMESTOP then table.insert(GROUPS, { "timestop", "cfg_timestop", "icon16/time.png" }) end
if RMPG.WIP then
	table.insert(GROUPS, { "freeze", "cfg_freeze", "icon16/weather_snow.png" })
	table.insert(GROUPS, { "drone", "cfg_drone", "icon16/transmit.png" })
end

-- A settings tab: the same control panel the spawn menu uses
local function SettingsTab(sheet, title, icon, build)
	local scroll = vgui.Create("DScrollPanel", sheet)
	local cp = vgui.Create(vgui.GetControlTable("ControlPanel") and "ControlPanel" or "DForm", scroll)
	cp:Dock(TOP)
	cp:DockMargin(4, 4, 4, 4)
	if not cp.ClearControls then cp.ClearControls = cp.Clear end
	if cp.SetLabel then cp:SetLabel(title) end
	build(cp)
	sheet:AddSheet(title, scroll, icon)
end

local function FriendsTab(sheet)
	local p = vgui.Create("DPanel", sheet)
	p.Paint = function(s, w, h)
		surface.SetDrawColor(3, 12, 10, 235)
		surface.DrawRect(0, 0, w, h)
	end
	local hint = vgui.Create("DLabel", p)
	hint:Dock(TOP)
	hint:DockMargin(10, 8, 10, 6)
	hint:SetWrap(true)
	hint:SetAutoStretchVertical(true)
	hint:SetFont("RMPG_Body")
	hint:SetTextColor(Color(180, 230, 200))
	hint:SetText(RMPG.T("desk_friends_hint"))
	local sc = UI.Scroll(p)
	sc:Dock(FILL)
	sc:DockMargin(10, 0, 4, 10)

	local function Refresh()
		sc:Clear()
		UI.Header(sc, RMPG.T("desk_online")):Dock(TOP)
		local me = LocalPlayer()
		local seen = {}
		for _, ply in ipairs(player.GetAll()) do
			if ply ~= me then
				seen[RMPG.PlayerKey(ply)] = true
				local on = RMPG.IsTrusted(ply)
				local b = UI.Button(sc, ply:Nick() .. "   ·   " .. RMPG.T(on and "desk_remove" or "desk_add"), on and "accent" or "dark", function()
					RMPG.SetTrusted(ply, not RMPG.IsTrusted(ply))
					timer.Simple(0, Refresh)
				end, on and "icon16/star.png" or "icon16/user_add.png")
				b:Dock(TOP)
				b:DockMargin(0, 0, 8, 6)
				b:SetTall(36)
			end
		end
		UI.Header(sc, RMPG.T("desk_saved")):Dock(TOP)
		for key, nick in SortedPairsByValue(RMPG.Trusted) do
			local b = UI.Button(sc, nick .. (seen[key] and "" or ("   ·   " .. RMPG.T("desk_offline"))) .. "   ·   " .. RMPG.T("desk_remove"), "dark", function()
				RMPG.UntrustKey(key)
				timer.Simple(0, Refresh)
			end, "icon16/cross.png")
			b:Dock(TOP)
			b:DockMargin(0, 0, 8, 6)
			b:SetTall(36)
		end
	end
	Refresh()
	sheet:AddSheet(RMPG.T("desk_friends"), p, "icon16/group.png")
end

local function Build(window)
	window:SetTitle(RMPG.T("desk_title") .. "   v" .. RMPG.VERSION)
	local sheet = vgui.Create("DPropertySheet", window)
	sheet:Dock(FILL)
	if RMPG.WikiTab then RMPG.WikiTab(sheet) end -- first: what everything is and how it works
	SettingsTab(sheet, RMPG.T("cfg_client"), "icon16/user_gray.png", RMPG.ClientSettingsPanel)
	FriendsTab(sheet)
	RMPG.ImplantsTab(sheet)
	for _, g in ipairs(GROUPS) do
		SettingsTab(sheet, RMPG.T(g[2]), g[3], function(cp)
			RMPG.ServerSettingsPanel(cp, g[1])
			if g[1] == "phx" and RMPG.PhoenixBlacklistUI then RMPG.PhoenixBlacklistUI(cp, RMPG.CanEditServer()) end
			if g[1] == "meeseeks" then RMPG.MeeseeksBlacklistUI(cp, RMPG.CanEditServer()) end
			if g[1] == "patch" then RMPG.PatchColorUI(cp) end
		end)
	end
end

list.Set("DesktopWindows", "RMPGSettings", {
	title = "Rick and Morty",
	icon = "entities/weapon_rm_portalgun.png",
	width = 780,
	height = 620,
	onewindow = true,
	init = function(icon, window) Build(window) end,
})
