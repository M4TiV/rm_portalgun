-- Client: Operation Phoenix - the tank window (E on a tank: the body growing, its size, whose mind moves in) and
-- the model blacklist editor in the spawn menu
RMPG = RMPG or {}
local UI = RMPG.UI

local BG = Color(3, 16, 11, 236)
local EDGE = Color(90, 255, 160)
local TEXT = Color(225, 255, 236)
local MUTED = Color(130, 200, 160)
local MEAT = Color(230, 80, 90)
local RED = Color(255, 90, 90)
local FLESH = Material("models/flesh")

local function Send(tank, action, write)
	net.Start("rmpg_phx_action")
	net.WriteEntity(tank)
	net.WriteString(action)
	if write then write() end
	net.SendToServer()
end

local function PhaseText(tank)
	if tank:GetBroken() then return RMPG.T("phx_broken") end
	if tank:GetState() == 0 then return RMPG.T("phx_empty") end
	if tank:GetState() == 3 then return RMPG.T("phx_wait") end
	local _, phase = tank:Progress()
	return phase == 1 and RMPG.T("phx_flesh") or (phase == 2 and RMPG.T("phx_skin") or RMPG.T("phx_ready"))
end

-- May this player pick someone else's mind (the server setting, or an admin)?
local function AnyMind()
	return RMPG.CV.phxAnyMind:GetBool() or LocalPlayer():IsAdmin()
end

function RMPG.OpenPhoenixMenu(tank)
	if IsValid(RMPG.PhxFrame) then RMPG.PhxFrame:Remove() end
	local W, H = math.min(780, ScrW() - 40), math.min(600, ScrH() - 40)
	local LW = math.floor(W * 0.4) -- the left column: the body and its growth
	local f = vgui.Create("EditablePanel")
	RMPG.PhxFrame = f
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()
	f.Paint = function(s, w, h)
		RMPG.HoloBox(0, 0, w, h, BG, EDGE)
		RMPG.HoloText(RMPG.T("phx_title"), "RMPG_Title", 20, 14, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		if not IsValid(tank) then return end
		-- the body
		surface.SetDrawColor(6, 30, 20, 230)
		surface.DrawRect(20, 64, LW - 20, H - 238)
		surface.SetDrawColor(EDGE.r, EDGE.g, EDGE.b, 80)
		surface.DrawOutlinedRect(20, 64, LW - 20, H - 238, 1)
		local state = tank:GetState()
		if tank:GetBroken() or state == 0 then
			draw.DrawText(tank:GetBroken() and RMPG.T("phx_broken_hint") or RMPG.T("phx_empty_hint"), "RMPG_Body", 20 + (LW - 20) / 2, 64 + (H - 238) / 2 - 20,
				tank:GetBroken() and RED or MUTED, TEXT_ALIGN_CENTER)
		end
		-- growth
		local p, phase = tank:Progress()
		local y = H - 164
		RMPG.HoloText(PhaseText(tank), "RMPG_BodyB", 22, y, tank:GetBroken() and RED or TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		if state > 0 then
			draw.SimpleText(tank:GetCloneLabel(), "RMPG_Small", LW, y + 28, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		end
		if state == 1 or state == 2 then
			surface.SetDrawColor(10, 40, 26, 230)
			surface.DrawRect(22, y + 28, LW - 22, 16)
			surface.SetDrawColor(phase == 1 and MEAT or EDGE)
			surface.DrawRect(22, y + 28, (LW - 22) * p, 16)
			local left = tank:TimeLeft()
			draw.SimpleText(math.floor(p * 100) .. "%", "RMPG_SmallB", 22, y + 48, MUTED)
			if left > 0 then draw.SimpleText(string.format(RMPG.T("phx_left"), math.ceil(left)), "RMPG_SmallB", LW, y + 48, MUTED, TEXT_ALIGN_RIGHT) end
		end
		-- size and mind
		local x = LW + 24
		draw.SimpleText(RMPG.T("phx_size_hint"), "RMPG_Small", x, 128, MUTED)
		RMPG.HoloText(RMPG.T("phx_mind"), "RMPG_SmallB", x, 158, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(AnyMind() and RMPG.T("phx_mind_hint") or RMPG.T("phx_mind_own"), "RMPG_Small", x, 176, MUTED)
	end
	f.Think = function(s)
		if not IsValid(tank) or LocalPlayer():GetPos():DistToSqr(tank:GetPos()) > 450 * 450 or input.IsKeyDown(KEY_ESCAPE) then
			if input.IsKeyDown(KEY_ESCAPE) then gui.HideGameUI() end
			s:Remove()
		end
	end

	local close = UI.Button(f, "", "dark", function() f:Remove() end, "icon16/cross.png")
	close:SetPos(W - 56, 14)
	close:SetSize(40, 36)

	-- the body as it grows (meat first, then skin), at its size
	local pv = vgui.Create("DModelPanel", f)
	pv:SetPos(22, 66)
	pv:SetSize(LW - 24, H - 242)
	pv:SetFOV(30)
	pv:SetCamPos(Vector(150, 0, 44))
	pv:SetLookAt(Vector(0, 0, 36))
	pv.Model = ""
	pv.Think = function(s)
		local model = IsValid(tank) and not tank:GetBroken() and tank:GetState() > 0 and tank:GetCloneModel() or ""
		if model == s.Model then return end
		s.Model = model
		if model == "" then
			if IsValid(s.Entity) then s.Entity:Remove() end
			s.Entity = nil
			return
		end
		s:SetModel(model)
		local ent = s:GetEntity()
		if not IsValid(ent) then return end
		ent:SetSkin(tank:GetCloneSkin())
		local bg = tank:GetCloneBodygroups()
		for i = 1, #bg do ent:SetBodygroup(i - 1, string.byte(bg, i) - 48) end
		local seq = ent:LookupSequence("idle_all_01")
		if not seq or seq < 0 then seq = ent:SelectWeightedSequence(ACT_IDLE) end
		if seq and seq >= 0 then ent:ResetSequence(seq) end
	end
	pv.LayoutEntity = function(s, ent)
		if not IsValid(tank) then return end
		ent:SetAngles(Angle(0, (RealTime() * 25) % 360, 0))
		local grow = tank:Growth()
		ent:SetModelScale(grow * math.Clamp(tank:GetCloneScale(), 0.3, 1))
		s:RunAnimation()
	end
	pv.PreDrawModel = function(s, ent)
		if not IsValid(tank) then return false end
		local _, skin = tank:Growth()
		if skin <= 0 then render.MaterialOverride(FLESH) end
	end
	pv.PostDrawModel = function(s, ent)
		render.MaterialOverride()
		if not IsValid(tank) then return end
		local _, skin = tank:Growth()
		if skin > 0 and skin < 1 then
			render.MaterialOverride(FLESH)
			render.SetBlend(1 - skin)
			ent:DrawModel()
			render.SetBlend(1)
			render.MaterialOverride()
		end
	end

	-- body size: 100% is the usual body, less is a child
	local x = LW + 22
	local minScale = math.floor(RMPG.CV.phxMinScale:GetFloat() * 100)
	local size = UI.Slider(f, RMPG.T("phx_size"), minScale, 100, 0,
		function() return IsValid(tank) and math.Round(tank:GetCloneScale() * 100) or 100 end, nil,
		function(v) Send(tank, "scale", function() net.WriteFloat(v / 100) end) end)
	size:SetPos(x, 64)
	size:SetSize(W - x - 20, 58)
	-- it is chosen before the body starts to grow
	size.Think2 = size.Think
	size.Think = function(s)
		local open = IsValid(tank) and (tank:GetState() == 0 or tank:GetState() == 3)
		s:SetMouseInputEnabled(open)
		s:SetAlpha(open and 255 or 110)
		if s.Think2 then s.Think2(s) end
	end

	-- whose mind moves in
	local list = UI.Scroll(f)
	list:SetPos(x, 198)
	list:SetSize(W - x - 20, H - 198 - 136)
	local buttons = {}
	for _, ply in ipairs(player.GetAll()) do
		if AnyMind() or ply == LocalPlayer() then
			local b = UI.Button(list, ply:Nick(), "dark", function(btn)
				Send(tank, "mind", function() net.WriteUInt(ply:EntIndex(), 16) end)
				for _, o in ipairs(buttons) do o.Kind = "dark" end
				btn.Kind = "accent"
			end, ply == LocalPlayer() and "icon16/user.png" or "icon16/user_green.png")
			b:Dock(TOP)
			b:DockMargin(0, 0, 8, 6)
			b:SetTall(36)
			if tank:GetMind() == ply then b.Kind = "accent" end
			buttons[#buttons + 1] = b
		end
	end

	local auto = UI.Toggle(f, RMPG.T("phx_auto"), nil, function() return IsValid(tank) and tank:GetAuto() end, function(v)
		Send(tank, "auto", function() net.WriteBool(v) end)
	end)
	auto:SetPos(x, H - 126)
	auto:SetSize(W - x - 20, 46)

	local go = UI.Button(f, RMPG.T("phx_transfer"), "accent", function()
		Send(tank, "transfer")
		f:Remove()
	end, "icon16/user_go.png")
	go:SetPos(W - 20 - 260, H - 66)
	go:SetSize(260, 46)
	local start = UI.Button(f, RMPG.T("phx_start"), "accent", function() Send(tank, "start") end, "icon16/control_play_blue.png")
	start:SetPos(W - 20 - 260, H - 66)
	start:SetSize(260, 46)
	local drain = UI.Button(f, RMPG.T("phx_drain"), "danger", function()
		Send(tank, "drain")
		f:Remove()
	end, "icon16/bin.png")
	drain:SetPos(20, H - 66)
	drain:SetSize(200, 46)
	local repair = UI.Button(f, RMPG.T("phx_repair"), "dark", function() Send(tank, "repair") end, "icon16/wrench.png")
	repair:SetPos(232, H - 66)
	repair:SetSize(200, 46)

	-- from the window: a hidden panel gets no Think of its own, so it could never come back
	local base = f.Think
	f.Think = function(s)
		base(s)
		local waiting = IsValid(tank) and tank:GetState() == 3 and not tank:GetBroken()
		start:SetVisible(waiting)
		go:SetVisible(not waiting)
		repair:SetVisible(IsValid(tank) and tank:GetBroken())
	end
end

net.Receive("rmpg_phx_menu", function()
	local tank = net.ReadEntity()
	if IsValid(tank) then RMPG.OpenPhoenixMenu(tank) end
end)

-- Spawn menu (Utilities -> Server: Operation Phoenix): the model blacklist
function RMPG.PhoenixBlacklistUI(panel, canEdit)
	panel:Help(RMPG.T("phx_blacklist"))
	panel:ControlHelp(RMPG.T("phx_blacklist_hint"))
	local entry = vgui.Create("DTextEntry", panel)
	entry:SetTall(80)
	entry:SetMultiline(true)
	entry:SetValue(RMPG.CV.phxBlacklist:GetString())
	entry:SetEnabled(canEdit)
	panel:AddItem(entry)
	local aim = panel:Button(RMPG.T("phx_blacklist_aim"))
	aim.DoClick = function()
		local e = LocalPlayer():GetEyeTrace().Entity
		if not IsValid(e) or not e:GetModel() then return end
		local v = string.Trim(entry:GetValue())
		entry:SetValue((v ~= "" and (v .. ", ") or "") .. e:GetModel())
	end
	aim:SetEnabled(canEdit)
	local save = panel:Button(RMPG.T("phx_blacklist_save"))
	save.DoClick = function()
		net.Start("rmpg_phx_blacklist")
		net.WriteString(string.gsub(entry:GetValue(), "[\r\n]+", ","))
		net.SendToServer()
	end
	save:SetEnabled(canEdit)
end
