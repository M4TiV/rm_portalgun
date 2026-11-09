-- Server: Rick's dramatic exit pills. A few seconds after you swallow one you start to fade - the Hollywood way
-- of leaving at the climax of a story - until you are gone; then you are at the saved location chosen with RMB
-- (or anywhere at random when there is none) and fade back in there.
-- The clients draw the fading from three times on the player: RMPG_PillFade (it starts), RMPG_PillGone (fully
-- gone: the moment you are moved) and RMPG_PillBack (fully back).
RMPG = RMPG or {}

util.AddNetworkString("rmpg_pill_menu")
util.AddNetworkString("rmpg_pill_dest")

local UP = Vector(0, 0, 1)
local BACK = 1.2 -- seconds of fading back in

local function Clear(ply)
	timer.Remove("rmpg_pill_" .. ply:EntIndex())
	ply.RMPG_PillDest = nil
	for _, k in ipairs({ "RMPG_PillFade", "RMPG_PillGone", "RMPG_PillBack" }) do
		if ply:GetNW2Float(k, 0) ~= 0 then ply:SetNW2Float(k, 0) end
	end
end

function RMPG.PillStart(ply, wep)
	if not IsValid(ply) or not ply:Alive() or ply:GetNW2Float("RMPG_PillBack", 0) > CurTime() then return false end
	local now = CurTime()
	local delay, fade = RMPG.CV.pillDelay:GetFloat(), RMPG.CV.pillFade:GetFloat()
	ply.RMPG_PillDest = IsValid(wep) and wep:GetHasDest() and { pos = wep:GetDestPos(), yaw = wep:GetDestYaw() } or nil
	ply:SetNW2Float("RMPG_PillFade", now + delay)
	ply:SetNW2Float("RMPG_PillGone", now + delay + fade)
	ply:SetNW2Float("RMPG_PillBack", now + delay + fade + BACK)
	local id = "rmpg_pill_" .. ply:EntIndex()
	timer.Create(id, delay, 1, function()
		if not IsValid(ply) or not ply:Alive() then return end
		ply:EmitSound(RMPG.SND.pillFade, 70, 105)
		timer.Create(id, fade, 1, function() RMPG.PillVanish(ply) end)
	end)
	return true
end

-- Fully faded: off to the chosen location, or a random spot
function RMPG.PillVanish(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	local dest = ply.RMPG_PillDest
	ply.RMPG_PillDest = nil
	local pos, yaw
	if dest and util.IsInWorld(dest.pos + UP * 36) then
		pos, yaw = dest.pos, dest.yaw
	else
		local g, fwd = RMPG.RandomSpot(ply)
		pos, yaw = g, isvector(fwd) and fwd:Angle().y or nil
	end
	if not pos then return end
	if ply:InVehicle() then ply:ExitVehicle() end
	sound.Play(RMPG.SND.pillGone, ply:GetPos() + UP * 40, 70, 115)
	ply:SetPos(pos + UP * 2)
	ply:SetVelocity(-ply:GetVelocity())
	if yaw then ply:SetEyeAngles(Angle(0, yaw, 0)) end
	ply.RMPG_LastTP = CurTime() -- no fall damage on arrival (sv_portals.lua)
	sound.Play(RMPG.SND.pillGone, pos + UP * 40, 70, 90)
end

hook.Add("PlayerDeath", "rmpg_pills", Clear)
hook.Add("PlayerSpawn", "rmpg_pills", Clear)

-- The location picked in the RMB menu (sent by the client, where the saved locations live)
net.Receive("rmpg_pill_dest", function(_, ply)
	if (ply.RMPG_PillNet or 0) > CurTime() then return end
	ply.RMPG_PillNet = CurTime() + 0.2
	-- the pills in hand (a bottle or one pill), else the bottle
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or (wep:GetClass() ~= RMPG.PILLS and wep:GetClass() ~= RMPG.PILL) then wep = ply:GetWeapon(RMPG.PILLS) end
	if not IsValid(wep) then return end
	local has = net.ReadBool()
	if not has then
		wep:SetHasDest(false)
		wep:SetDestName("")
		return
	end
	local pos, yaw, name = net.ReadVector(), net.ReadFloat(), string.sub(net.ReadString(), 1, 64)
	if not util.IsInWorld(pos + UP * 36) then return end
	wep:SetHasDest(true)
	wep:SetDestPos(pos)
	wep:SetDestYaw(yaw)
	wep:SetDestName(name)
end)
