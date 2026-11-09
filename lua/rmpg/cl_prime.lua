-- Client: Rick Prime's chip (sv_prime.lua). Its bodies and the ragdolls made from a body (sv_gore.lua) get the colour of
-- the clothes; the blood goes from a body whose wounds closed; during a fake death the camera watches your ragdoll.
RMPG = RMPG or {}

-- The player colour proxy asks the entity itself
hook.Add("EntityNetworkedVarChanged", "rmpg_prime_colour", function(e, name, old, new)
	if name == "RMPG_PlyColor" and isvector(new) then
		e.GetPlayerColor = function() return new end
	elseif name == "RMPG_PrimeClean" and IsValid(e) then
		e:RemoveAllDecals()
	end
end)

-- Lying there "dead": the camera a little behind and above the ragdoll, looking at it
hook.Add("CalcView", "rmpg_prime_fake", function(ply, pos, ang, fov)
	local rag = ply:GetNW2Entity("RMPG_PrimeRag", NULL)
	if not IsValid(rag) then return end
	local c = rag:GetPos() + Vector(0, 0, 8)
	local want = c - ang:Forward() * 90 + Vector(0, 0, 36)
	local tr = util.TraceHull({ start = c, endpos = want, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4), filter = { rag, ply }, mask = MASK_SOLID_BRUSHONLY })
	return { origin = tr.HitPos, angles = (c - tr.HitPos):Angle(), fov = fov, drawviewer = false }
end)

hook.Add("HUDPaint", "rmpg_prime_fake", function()
	local me = LocalPlayer()
	if not IsValid(me) or not IsValid(me:GetNW2Entity("RMPG_PrimeRag", NULL)) then return end
	surface.SetDrawColor(120, 0, 0, 70)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	draw.SimpleTextOutlined(RMPG.T("prime_fake"), "RMPG_Head", ScrW() / 2, ScrH() * 0.78, Color(255, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
end)
