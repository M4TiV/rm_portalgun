-- Server: the neutrino bomb's blast. Everything near the middle is torn apart, the shock wave hurts and throws
-- everything out to rmpg_neutrino_radius (half a map by default), a black hole may open where the bomb was, and
-- the thrown-up ground comes down as burning meteorites. The clients draw the flash and the pieces (cl_neutrino.lua).
RMPG = RMPG or {}

util.AddNetworkString("rmpg_nb_pad")
util.AddNetworkString("rmpg_nb_codes")

-- The two codes of a bomb, for this player's chat only
function RMPG.NbSendCodes(ply, bomb)
	net.Start("rmpg_nb_codes")
	net.WriteString(bomb.StartCode)
	net.WriteString(bomb.StopCode)
	net.Send(ply)
end

-- The keypad: the start code with a time, or while it counts down the stop code. Five wrong codes lock it for a while.
net.Receive("rmpg_nb_pad", function(_, ply)
	local e, code, seconds, show = net.ReadEntity(), net.ReadString(), net.ReadUInt(12), net.ReadBool()
	if not IsValid(e) or e:GetClass() ~= RMPG.NEUTRINO or e:GetExploded() then return end
	if ply:GetPos():DistToSqr(e:GetPos()) > 330 * 330 then return end
	if show then
		if ply == e.CodeOwner or ply:IsAdmin() then
			RMPG.NbSendCodes(ply, e)
		else
			RMPG.Notify(ply, "n_nb_not_yours", nil, 1)
		end
		return
	end
	local now = CurTime()
	if (e.PadLock or 0) > now then
		RMPG.Notify(ply, "n_nb_locked", { math.ceil(e.PadLock - now) }, 1)
		return
	end
	local counting = e:GetBlastTime() > 0
	if code ~= (counting and e.StopCode or e.StartCode) then
		e.PadTries = (e.PadTries or 0) + 1
		e:EmitSound(RMPG.SND.laserDry, 70, 70)
		if e.PadTries >= 5 then
			e.PadTries = 0
			e.PadLock = now + 20
			RMPG.Notify(ply, "n_nb_locked", { 20 }, 1)
		else
			RMPG.Notify(ply, "n_nb_wrong", nil, 1)
		end
		return
	end
	e.PadTries = 0
	if counting then
		e:Defuse(ply)
	else
		e:Trigger(math.Clamp(seconds, 3, 3600), ply)
	end
end)

util.AddNetworkString("rmpg_neutrino")

local UP = Vector(0, 0, 1)
local SKIP = { rmpg_portal = true, rmpg_meltdown = true, rmpg_black_hole = true }
local MAX_TORN = 40 -- disintegration clouds at most; the rest near the middle just goes

local function Target(e, bomb)
	if not IsValid(e) or e == bomb or e:IsWorld() or e.RMPG_Vaporized or SKIP[e:GetClass()] then return false end
	if IsValid(e:GetParent()) then return false end
	if e.RMPG_Bombable then return true end
	if e:IsPlayer() then return e:Alive() and not e:HasGodMode() end
	if e:IsNPC() or e:IsNextBot() then return e:Health() > 0 end
	if e:IsWeapon() and IsValid(e:GetOwner()) then return false end
	if e:IsVehicle() then return true end
	return e:GetMoveType() == MOVETYPE_VPHYSICS and IsValid(e:GetPhysicsObject())
end

local function Push(e, dir, k)
	if e:IsPlayer() then
		e:SetVelocity(dir * (1100 * k) + UP * (450 * k))
	elseif e:IsNPC() or e:IsNextBot() then
		e:SetVelocity(dir * (700 * k) + UP * (300 * k))
	else
		for i = 0, e:GetPhysicsObjectCount() - 1 do
			local po = e:GetPhysicsObjectNum(i)
			if IsValid(po) and po:IsMotionEnabled() then
				po:Wake()
				po:ApplyForceCenter((dir * 2200 + UP * 900) * (po:GetMass() * k))
			end
		end
	end
end

function RMPG.NeutrinoBlast(bomb, attacker)
	local center = bomb:WorldSpaceCenter()
	local U = RMPG.UNITS_PER_METER
	local R = RMPG.CV.nbRadius:GetFloat() * U
	local kill = math.min(RMPG.CV.nbKill:GetFloat() * U, R)
	local meteors = RMPG.CV.nbMeteors:GetBool()
	attacker = IsValid(attacker) and attacker or bomb
	local seed = math.random(1, 2147483646)

	net.Start("rmpg_neutrino")
	net.WriteVector(center)
	net.WriteFloat(R)
	net.WriteUInt(seed, 31)
	net.WriteBool(meteors)
	net.Broadcast()
	util.ScreenShake(center, 30, 6, 5, R * 1.6)

	-- torn apart near the middle, hurt and thrown away further out (a neutrino blast goes through walls)
	local torn = 0
	for _, e in ipairs(ents.FindInSphere(center, R)) do
		if Target(e, bomb) then
			local off = e:WorldSpaceCenter() - center
			local d = off:Length()
			if d <= kill then
				if torn < MAX_TORN or e:IsPlayer() or e:IsNPC() or e:IsNextBot() then
					torn = torn + 1
					RMPG.Disintegrate(e, attacker, bomb, center)
				else
					e:Remove()
				end
			else
				local k = 1 - (d - kill) / math.max(R - kill, 1)
				local dir = d > 1 and off / d or UP
				local dmg = DamageInfo()
				dmg:SetDamage(RMPG.CV.nbDamage:GetFloat() * k ^ 1.5)
				dmg:SetDamageType(DMG_BLAST)
				dmg:SetAttacker(attacker)
				dmg:SetInflictor(bomb)
				dmg:SetDamagePosition(center)
				dmg:SetDamageForce(dir * (60000 * k))
				e:TakeDamageInfo(dmg)
				if IsValid(e) then Push(e, dir, k) end
			end
		end
	end

	-- scorched ground around the middle
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = center + Vector(math.cos(a), math.sin(a), 0) * (i == 0 and 0 or math.Rand(60, kill * 0.6))
		util.Decal("Scorch", p + UP * 40, p - UP * 200)
	end

	local life = RMPG.CV.nbHole:GetFloat()
	if life > 0 then
		local h = ents.Create("rmpg_black_hole")
		if IsValid(h) then
			h:SetPos(center + UP * 24)
			h:SetLife(life)
			h:SetPullRadius(RMPG.CV.nbHoleRadius:GetFloat() * U)
			h.Attacker = attacker
			h:Spawn()
		end
	end

	-- the same pieces the clients see: each burning fragment hurts where it lands
	if meteors then
		for _, c in ipairs(RMPG.NeutrinoPieces(seed, center, R)) do
			for _, f in ipairs(c.frags) do
				if f.at then
					timer.Simple(c.delay + c.split + f.land, function()
						local w = game.GetWorld()
						util.BlastDamage(w, w, f.at + UP * 10, 170, 45)
						util.Decal("Scorch", f.at + UP * 20, f.at - UP * 40)
					end)
				end
			end
		end
	end
end
