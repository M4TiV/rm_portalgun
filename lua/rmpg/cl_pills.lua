-- Client: the dramatic exit pills - a fading player (with his gun, and your own viewmodel and hands), golden
-- sparkles around him, a soft white haze for the one who leaves, and the RMB menu of where you turn up
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local GOLD = Color(255, 220, 150)

-- How much of the player is there: 1 normal, 0 gone (fading out, then back in after the move)
function RMPG.PillAlpha(ply)
	local fade = ply:GetNW2Float("RMPG_PillFade", 0)
	if fade == 0 then return 1 end
	local gone, back, t = ply:GetNW2Float("RMPG_PillGone", 0), ply:GetNW2Float("RMPG_PillBack", 0), CurTime()
	if t < fade or t >= back then return 1 end
	if t < gone then
		local a = 1 - (t - fade) / math.max(gone - fade, 0.01)
		-- the last moments flicker like an old film
		if a < 0.4 then a = a * (0.75 + 0.25 * math.sin(t * 47)) end
		return math.Clamp(a, 0, 1)
	end
	return math.Clamp((t - gone) / math.max(back - gone, 0.01), 0, 1)
end

-- See-through on this client only: the render mode and colour alpha, put back once the player is whole again
local function SetAlpha(e, a)
	if not IsValid(e) then return end
	if a >= 1 then
		if e.RMPG_PillMode then
			e:SetRenderMode(e.RMPG_PillMode)
			local c = e:GetColor()
			e:SetColor(Color(c.r, c.g, c.b, e.RMPG_PillA or 255))
			e.RMPG_PillMode, e.RMPG_PillA = nil, nil
		end
		return
	end
	if not e.RMPG_PillMode then
		e.RMPG_PillMode = e:GetRenderMode()
		e.RMPG_PillA = e:GetColor().a
		e:SetRenderMode(RENDERMODE_TRANSCOLOR)
	end
	local c = e:GetColor()
	e:SetColor(Color(c.r, c.g, c.b, math.floor(255 * a)))
end

local fading = {}
local nextSpark = 0
hook.Add("Think", "rmpg_pills", function()
	local spark = RealTime() >= nextSpark and RMPG.CL.particles:GetBool()
	if spark then nextSpark = RealTime() + 0.05 end
	for _, ply in ipairs(player.GetAll()) do
		local a = RMPG.PillAlpha(ply)
		if a < 1 or fading[ply] then
			fading[ply] = a < 1 or nil
			SetAlpha(ply, a)
			SetAlpha(ply:GetActiveWeapon(), a)
			if ply == LocalPlayer() then
				SetAlpha(ply:GetViewModel(), a)
				SetAlpha(ply:GetHands(), a)
			end
			if spark and a < 1 and a > 0.02 then
				local em = ParticleEmitter(ply:GetPos(), false)
				if em then
					for _ = 1, 3 do
						local p = em:Add(RMPG.Mat.glow, ply:GetPos() + Vector(math.Rand(-16, 16), math.Rand(-16, 16), math.Rand(4, ply:OBBMaxs().z)))
						if p then
							p:SetVelocity(UP * math.Rand(10, 40) + VectorRand() * 8)
							p:SetDieTime(math.Rand(0.6, 1.2))
							p:SetStartAlpha(220 * (1 - a * 0.5))
							p:SetEndAlpha(0)
							p:SetStartSize(math.Rand(1.5, 3.5))
							p:SetEndSize(0)
							p:SetColor(GOLD.r, GOLD.g, GOLD.b)
						end
					end
					em:Finish()
				end
			end
		end
	end
end)

-- The one who leaves: the world goes softly white as he fades
hook.Add("HUDPaint", "rmpg_pills", function()
	local me = LocalPlayer()
	if me:GetNW2Float("RMPG_PillFade", 0) == 0 or CurTime() >= me:GetNW2Float("RMPG_PillBack", 0) then return end
	local a = RMPG.PillAlpha(me)
	if a >= 1 then return end
	surface.SetDrawColor(255, 248, 235, 200 * (1 - a) ^ 2)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

-- RMB with the pills: where you turn up - one of your saved portal gun locations, or anywhere
local function SendDest(loc)
	net.Start("rmpg_pill_dest")
	net.WriteBool(loc ~= nil)
	if loc then
		net.WriteVector(RMPG.LocPos(loc))
		net.WriteFloat(loc.yaw or 0)
		net.WriteString(loc.name or "")
	end
	net.SendToServer()
	RMPG.AddNote(string.format(RMPG.T("pills_dest"), loc and loc.name or RMPG.T("dest_random")), 0)
end

net.Receive("rmpg_pill_menu", function()
	if #RMPG.Locations == 0 then
		-- nothing saved: no choice, a random spot
		SendDest(nil)
		RMPG.AddNote(RMPG.T("pills_no_locations"), 1)
		return
	end
	local m = DermaMenu()
	m:AddOption(RMPG.T("dest_random"), function() SendDest(nil) end):SetIcon("icon16/arrow_switch.png")
	m:AddSpacer()
	for _, loc in ipairs(RMPG.Locations) do
		m:AddOption((loc.code and (loc.code .. "  ·  ") or "") .. loc.name, function() SendDest(loc) end):SetIcon("icon16/map.png")
	end
	m:Open()
	m:SetPos(ScrW() / 2 - m:GetWide() / 2, ScrH() / 2 - m:GetTall() / 2)
end)
