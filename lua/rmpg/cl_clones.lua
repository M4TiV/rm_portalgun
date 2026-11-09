-- Client: visitors from other dimensions look like players who just joined - chat lines with their name (the
-- "joined / left the game" lines come from the game itself, sent by the server), a row in the default TAB scoreboard (the copied player's avatar, name, kills, deaths
-- and ping) and their name when you look at them
RMPG = RMPG or {}
RMPG.FakePlayers = RMPG.FakePlayers or {} -- id -> { name, source, team, kills, deaths, dead, ping, panel }

local EV_JOIN, EV_LEAVE, EV_DIE, EV_FRAG, EV_SAY = 1, 2, 3, 4, 5

local function TeamColor(f)
	return team.GetColor(f.team or TEAM_UNASSIGNED)
end

net.Receive("rmpg_clone_ev", function()
	local ev, id = net.ReadUInt(3), net.ReadUInt(16)
	local fakes = RMPG.FakePlayers
	if ev == EV_JOIN then
		local f = { name = net.ReadString(), source = net.ReadEntity(), team = net.ReadUInt(16) }
		f.kills, f.deaths, f.ping = net.ReadUInt(12), net.ReadUInt(12), math.random(35, 95)
		fakes[id] = f
		return
	end
	local f = fakes[id]
	if not f then return end
	if ev == EV_LEAVE then
		if IsValid(f.panel) then f.panel:Remove() end
		fakes[id] = nil
	elseif ev == EV_DIE then
		f.deaths = f.deaths + 1
		f.dead = true
	elseif ev == EV_FRAG then
		f.kills = f.kills + 1
	elseif ev == EV_SAY then
		chat.AddText(TeamColor(f), f.name, color_white, ": " .. RMPG.T(net.ReadString()))
	end
end)

---------------------------------------------------------------------------
-- TAB: rows that look like the default scoreboard's player rows
---------------------------------------------------------------------------

local GREY = Color(93, 93, 93)

local FAKE_LINE = {
	Init = function(self)
		self.AvatarButton = self:Add("DButton")
		self.AvatarButton:Dock(LEFT)
		self.AvatarButton:SetSize(32, 32)
		self.AvatarButton:SetText("")
		self.AvatarButton.Paint = function() end
		self.Avatar = vgui.Create("AvatarImage", self.AvatarButton)
		self.Avatar:SetSize(32, 32)
		self.Avatar:SetMouseInputEnabled(false)
		self.Name = self:Add("DLabel")
		self.Name:Dock(FILL)
		self.Name:SetFont("ScoreboardDefault")
		self.Name:SetTextColor(GREY)
		self.Name:DockMargin(8, 0, 0, 0)
		self.Mute = self:Add("DImageButton")
		self.Mute:SetSize(32, 32)
		self.Mute:Dock(RIGHT)
		self.Mute:SetImage("icon32/unmuted.png")
		for _, k in ipairs({ "Ping", "Deaths", "Kills" }) do
			local l = self:Add("DLabel")
			l:Dock(RIGHT)
			l:SetWidth(50)
			l:SetFont("ScoreboardDefault")
			l:SetTextColor(GREY)
			l:SetContentAlignment(5)
			self[k] = l
		end
		self:Dock(TOP)
		self:DockPadding(3, 3, 3, 3)
		self:SetHeight(32 + 3 * 2)
		self:DockMargin(2, 0, 2, 2)
	end,
	Setup = function(self, f)
		self.Fake = f
		if IsValid(f.source) then self.Avatar:SetPlayer(f.source, 32) end
		self.AvatarButton.DoClick = function() if IsValid(f.source) then f.source:ShowProfile() end end
		self:Think()
	end,
	Think = function(self)
		local f = self.Fake
		if not f then return end
		self.Name:SetText(f.name)
		self.Kills:SetText(f.kills)
		self.Deaths:SetText(f.deaths)
		-- a ping that wanders a bit, like a real one
		if (self.NextPing or 0) < RealTime() then
			self.NextPing = RealTime() + 2
			f.ping = math.Clamp(f.ping + math.random(-6, 6), 20, 140)
		end
		self.Ping:SetText(f.ping)
		self:SetZPos(f.kills * -50 + f.deaths + 300)
	end,
	Paint = function(self, w, h)
		local f = self.Fake
		draw.RoundedBox(4, 0, 0, w, h, f and f.dead and Color(230, 200, 200, 255) or Color(230, 230, 230, 255))
	end,
}
FAKE_LINE = vgui.RegisterTable(FAKE_LINE, "DPanel")

-- Put the rows into the default scoreboard (servers with their own scoreboard do not show them)
hook.Add("Think", "rmpg_clone_tab", function()
	local sb = g_Scoreboard
	if not IsValid(sb) or not sb:IsVisible() or not IsValid(sb.Scores) then return end
	for _, f in pairs(RMPG.FakePlayers) do
		if not IsValid(f.panel) then
			f.panel = vgui.CreateFromTable(FAKE_LINE)
			f.panel:Setup(f)
			sb.Scores:AddItem(f.panel)
		end
	end
end)

---------------------------------------------------------------------------
-- Their name when you look at them, the way players' names show
---------------------------------------------------------------------------

hook.Add("HUDPaint", "rmpg_clone_targetid", function()
	local tr = LocalPlayer():GetEyeTrace()
	local e = tr.Entity
	if not IsValid(e) or e:GetClass() ~= "rmpg_clone" or tr.HitPos:DistToSqr(EyePos()) > 1500 * 1500 then return end
	local f = RMPG.FakePlayers[e:GetCloneID()]
	local col = f and TeamColor(f) or Color(255, 255, 100)
	local x, y = ScrW() / 2, ScrH() / 2 + 30
	local name = e:GetCloneName()
	draw.SimpleText(name, "TargetID", x + 1, y + 1, Color(0, 0, 0, 120), TEXT_ALIGN_CENTER)
	draw.SimpleText(name, "TargetID", x + 2, y + 2, Color(0, 0, 0, 50), TEXT_ALIGN_CENTER)
	draw.SimpleText(name, "TargetID", x, y, col, TEXT_ALIGN_CENTER)
	local hp = math.max(math.floor(e:Health() / math.max(e:GetMaxHealth(), 1) * 100), 0) .. "%"
	draw.SimpleText(hp, "TargetIDSmall", x + 1, y + 26, Color(0, 0, 0, 120), TEXT_ALIGN_CENTER)
	draw.SimpleText(hp, "TargetIDSmall", x, y + 25, col, TEXT_ALIGN_CENTER)
end)
