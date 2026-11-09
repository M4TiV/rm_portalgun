-- Client: the neutrino bomb's keypad. Whoever spawned the bomb is told its two codes in chat, nobody else: the start code
-- with a time set here starts the countdown, the stop code ends it.
RMPG = RMPG or {}
local UI = RMPG.UI

local BG = Color(16, 12, 8, 240)
local EDGE = Color(255, 150, 60)
local TEXT = Color(255, 236, 214)
local MUTED = Color(214, 170, 130)
local SCREEN = Color(10, 24, 16, 255)
local LCD = Color(120, 255, 150)
local MAX_DIGITS = 4

net.Receive("rmpg_nb_codes", function()
	local start, stop = net.ReadString(), net.ReadString()
	chat.AddText(EDGE, RMPG.T("nb_codes_title"))
	chat.AddText(color_white, RMPG.T("nb_code_start") .. " ", LCD, start)
	chat.AddText(color_white, RMPG.T("nb_code_stop") .. " ", Color(255, 110, 90), stop)
end)

function RMPG.OpenBombPad(bomb)
	if IsValid(RMPG.BombPad) then RMPG.BombPad:Remove() end
	if not IsValid(bomb) then return end
	local code = ""
	local seconds = RMPG.CV.nbTimer:GetInt()
	local W, H = 340, 560
	local f = vgui.Create("EditablePanel")
	RMPG.BombPad = f
	f:SetSize(W, H)
	f:Center()
	f:MakePopup()

	local function Armed() return IsValid(bomb) and bomb:GetBlastTime() > 0 end
	local function Key(d)
		if #code < MAX_DIGITS then
			code = code .. d
			surface.PlaySound(RMPG.SND.uiHover)
		end
	end
	local function Send(show)
		net.Start("rmpg_nb_pad")
		net.WriteEntity(bomb)
		net.WriteString(code)
		net.WriteUInt(math.Clamp(seconds, 3, 3600), 12)
		net.WriteBool(show or false)
		net.SendToServer()
		code = ""
	end

	f.Paint = function(s, w, h)
		RMPG.HoloBox(0, 0, w, h, BG, EDGE)
		RMPG.HoloText(RMPG.T("nb_pad_title"), "RMPG_Head", 18, 14, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		local armed = Armed()
		draw.SimpleText(RMPG.T(armed and "nb_pad_stop" or "nb_pad_start"), "RMPG_Small", 18, 42, MUTED)
		surface.SetDrawColor(SCREEN)
		surface.DrawRect(18, 64, w - 36, 64)
		local shown = string.rep("*", #code) .. string.rep("_", MAX_DIGITS - #code)
		draw.SimpleText(shown, "RMPG_MonoBig", w / 2, 96, LCD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		if armed then
			draw.SimpleText(string.format("%.1f", math.max(bomb:GetBlastTime() - CurTime(), 0)), "RMPG_Mono", w / 2, H - 118, Color(255, 90, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	f.Think = function(s)
		if not IsValid(bomb) or bomb:GetExploded() or LocalPlayer():GetPos():DistToSqr(bomb:GetPos()) > 300 * 300 or input.IsKeyDown(KEY_ESCAPE) then
			if input.IsKeyDown(KEY_ESCAPE) then gui.HideGameUI() end
			s:Remove()
			return
		end
		-- the number row and the numpad work too
		for d = 0, 9 do
			for _, k in ipairs({ KEY_0 + d, KEY_PAD_0 + d }) do
				local held = input.IsKeyDown(k)
				if held and not s["k" .. k] then Key(tostring(d)) end
				s["k" .. k] = held
			end
		end
	end

	local close = UI.Button(f, "X", "dark", function() f:Remove() end)
	close:SetPos(W - 46, 10)
	close:SetSize(34, 30)

	-- the keys
	local rows = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "<" }
	local bw, bh, gap = 92, 52, 8
	for i, t in ipairs(rows) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local b = UI.Button(f, t, "dark", function()
			if t == "C" then
				code = ""
			elseif t == "<" then
				code = string.sub(code, 1, -2)
			else
				Key(t)
			end
		end)
		b:SetPos(18 + col * (bw + gap), 140 + row * (bh + gap))
		b:SetSize(bw, bh)
	end

	-- the time before the blast (the countdown already running has its own)
	local time = UI.Slider(f, RMPG.T("nb_pad_time"), 5, 600, 0, function() return seconds end, function(v) seconds = v end)
	time:SetPos(18, 382)
	time:SetSize(W - 36, 58)
	time.Think2 = time.Think
	time.Think = function(s)
		s:SetVisible(not Armed())
		if s.Think2 then s.Think2(s) end
	end

	local ok = UI.Button(f, RMPG.T("nb_pad_ok"), "accent", function() Send(false) end, "icon16/accept.png")
	ok:SetPos(18, 450)
	ok:SetSize(W - 36, 44)
	local show = UI.Button(f, RMPG.T("nb_pad_show"), "dark", function() Send(true) end, "icon16/information.png")
	show:SetPos(18, 502)
	show:SetSize(W - 36, 38)
end

net.Receive("rmpg_nb_pad", function()
	RMPG.OpenBombPad(net.ReadEntity())
end)
