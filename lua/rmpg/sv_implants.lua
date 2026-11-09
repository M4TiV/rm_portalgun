-- Server: implants. Damage goes through a player's implants in the order they chose in the C menu, each may stop it, and
-- what gets past them all reaches the player. The energy shield is in sv_shield.lua; this file also has the emergency
-- evacuation: when a bullet or a blast is about to hit, the body falls apart into a hologram and reassembles a metre or
-- two away. It takes rmpg_evac_charges hits, then needs rmpg_evac_regen seconds to come back.
RMPG = RMPG or {}
RMPG.ImplantHandlers = RMPG.ImplantHandlers or {}

util.AddNetworkString("rmpg_evac_fx")

local UP = Vector(0, 0, 1)
local KNOWN = { "shield", "evac" }

local function Order(ply)
	local str = ply:GetInfo("rmpg_implant_order")
	if ply.RMPG_OrderStr == str and ply.RMPG_Order then return ply.RMPG_Order end
	local out, seen = {}, {}
	for id in string.gmatch(str or "", "[^,]+") do
		if RMPG.ImplantHandlers[id] and not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	for _, id in ipairs(KNOWN) do
		if not seen[id] then out[#out + 1] = id end
	end
	ply.RMPG_OrderStr, ply.RMPG_Order = str, out
	return out
end

hook.Add("EntityTakeDamage", "rmpg_implants", function(ply, dmg)
	if not ply:IsPlayer() or not ply:Alive() then return end
	for _, id in ipairs(Order(ply)) do
		local fn = RMPG.ImplantHandlers[id]
		if fn and fn(ply, dmg) then return true end
	end
	-- what got past them: Rick Prime's chip shows the wounds, and undoes a death now and then (sv_prime.lua)
	if RMPG.PrimeDamage and RMPG.PrimeDamage(ply, dmg) then return true end
end)

---------------------------------------------------------------------------
-- Emergency evacuation
---------------------------------------------------------------------------

function RMPG.HasEvac(ply)
	return ply:GetNW2Bool("RMPG_Evac", false)
end

function RMPG.ImplantEvac(ply)
	if RMPG.HasEvac(ply) then return false end
	ply:SetNW2Bool("RMPG_Evac", true)
	ply:SetNW2Int("RMPG_EvacLeft", RMPG.CV.evacCharges:GetInt())
	ply:SetNW2Float("RMPG_EvacBack", 0)
	ply:EmitSound(RMPG.SND.shieldImplant, 70, 130)
	return true
end

function RMPG.RemoveEvac(ply)
	ply:SetNW2Bool("RMPG_Evac", false)
	ply:SetNW2Float("RMPG_EvacBack", 0)
end

-- Somewhere to reassemble: to the side of the shot (or away from the blast), with a floor under it
local function Spot(ply, dirs)
	local up = RMPG.BootsOn(ply) and RMPG.BootsUp(ply) or UP
	local from = ply:GetPos() + up * 2
	local mins, maxs = ply:OBBMins(), ply:OBBMaxs()
	local lo, hi = RMPG.CV.evacMin:GetFloat(), RMPG.CV.evacMax:GetFloat()
	-- in a tight spot a shorter jump will do
	for _, k in ipairs({ 1, 0.55, 0.3 }) do
		for _, d in ipairs(dirs) do
			local to = from + d * math.Rand(lo, math.max(lo, hi)) * k
			local tr = util.TraceHull({ start = from, endpos = to, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = ply })
			if not tr.StartSolid and tr.Fraction > 0.5 then
				local down = util.TraceHull({ start = tr.HitPos, endpos = tr.HitPos - up * 140, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = ply })
				if down.Hit and not down.StartSolid then return down.HitPos + up * 1 end
			end
		end
	end
end

-- Which way the danger comes from
local function ShotDir(ply, dmg)
	local src = dmg:GetAttacker()
	if not IsValid(src) or src == ply then src = dmg:GetInflictor() end
	local d = ply:WorldSpaceCenter() - (IsValid(src) and src:WorldSpaceCenter() or dmg:GetDamagePosition())
	if d:LengthSqr() < 1 then d = ply:GetForward() end
	return d:GetNormalized()
end

local function FX(ply, from)
	net.Start("rmpg_evac_fx")
	net.WriteEntity(ply)
	net.WriteVector(from)
	net.WriteVector(ply:GetPos())
	net.SendPVS(from)
end

RMPG.ImplantHandlers.evac = function(ply, dmg)
	if not RMPG.HasEvac(ply) or ply:InVehicle() or ply:GetNW2Float("RMPG_EvacBack", 0) > 0 then return end
	local blast = dmg:IsExplosionDamage()
	local shot = dmg:IsBulletDamage() or dmg:IsDamageType(DMG_BUCKSHOT) or dmg:IsDamageType(DMG_ENERGYBEAM) or dmg:IsDamageType(DMG_PLASMA)
		or dmg:IsDamageType(DMG_SNIPER) or dmg:IsDamageType(DMG_AIRBOAT)
	if (blast and not RMPG.CV.evacBlast:GetBool()) or not (blast or shot) then return end
	local inf = dmg:GetInflictor()
	if RMPG.IsBomb(inf) or ply.RMPG_Vaporized then return end -- nothing escapes a bomb or disintegration
	local left = ply:GetNW2Int("RMPG_EvacLeft", 0)
	local cost = blast and RMPG.CV.evacBlastCost:GetInt() or 1
	if left <= 0 then return end

	-- a burst does not make you jump every bullet: for a moment after a jump you are simply not where they land
	local now = CurTime()
	if now - (ply.RMPG_EvacAt or 0) >= 0.14 then
		local up = RMPG.BootsOn(ply) and RMPG.BootsUp(ply) or UP
		local d = ShotDir(ply, dmg)
		local side = d:Cross(up)
		if side:LengthSqr() < 0.01 then side = ply:GetRight() end
		side:Normalize()
		if math.random() < 0.5 then side = -side end
		local back = (d - up * d:Dot(up)):GetNormalized()
		local spot = blast and Spot(ply, { back, (back + side):GetNormalized(), (back - side):GetNormalized(), side, -side })
			or Spot(ply, { side, -side, (side + back):GetNormalized(), (back - side):GetNormalized(), back })
		if not spot then return end -- nowhere to go: the next implant has to deal with it
		local from = ply:GetPos()
		ply:SetPos(spot)
		ply.RMPG_EvacAt = now
		ply:EmitSound(string.format(RMPG.SND.evacJump, math.random(1, 3)), 70, math.random(120, 140))
		FX(ply, from)
	end

	left = math.max(left - cost, 0)
	ply:SetNW2Int("RMPG_EvacLeft", left)
	if left == 0 then
		ply:SetNW2Float("RMPG_EvacBack", now + RMPG.CV.evacRegen:GetFloat())
		ply:EmitSound(RMPG.SND.bootsOff, 70, 80)
		RMPG.Notify(ply, "n_evac_out", nil, 1)
	end
	return true
end

hook.Add("Think", "rmpg_evac_regen", function()
	local now = CurTime()
	if (RMPG.EvacNextThink or 0) > now then return end
	RMPG.EvacNextThink = now + 0.25
	for _, ply in ipairs(player.GetAll()) do
		local back = ply:GetNW2Float("RMPG_EvacBack", 0)
		if back > 0 and now >= back then
			ply:SetNW2Float("RMPG_EvacBack", 0)
			ply:SetNW2Int("RMPG_EvacLeft", RMPG.CV.evacCharges:GetInt())
			ply:EmitSound(RMPG.SND.bootsOn, 65, 130)
			RMPG.Notify(ply, "n_evac_ready", nil, 2)
		end
	end
end)

hook.Add("PostPlayerDeath", "rmpg_evac", function(ply)
	if not RMPG.CV.evacKeep:GetBool() then RMPG.RemoveEvac(ply) end
end)

hook.Add("PlayerSpawn", "rmpg_evac", function(ply)
	if RMPG.HasEvac(ply) then
		ply:SetNW2Int("RMPG_EvacLeft", RMPG.CV.evacCharges:GetInt())
		ply:SetNW2Float("RMPG_EvacBack", 0)
	end
end)

---------------------------------------------------------------------------
-- The weapon implants and the combat mode. There is one switch: while it is on everything you have implanted works at
-- once, each on its own button from the Implants tab, whatever you are holding
---------------------------------------------------------------------------

util.AddNetworkString("rmpg_implant")

function RMPG.HasArm(ply)
	return ply:GetNW2Bool("RMPG_Arm", false)
end

function RMPG.ImplantArm(ply)
	if RMPG.HasArm(ply) then return false end
	ply:SetNW2Bool("RMPG_Arm", true)
	ply:SetNW2Float("RMPG_ArmBack", 0)
	ply:EmitSound(RMPG.SND.shieldImplant, 70, 90)
	return true
end

-- Everything in the beam goes; it stops only at the world
local function Burn(ply)
	local src, dir = ply:GetShootPos(), ply:GetAimVector()
	local tr = util.TraceLine({ start = src, endpos = src + dir * RMPG.CV.armRange:GetFloat(), mask = MASK_SOLID_BRUSHONLY })
	local r = RMPG.CV.armRadius:GetFloat()
	local box = Vector(r, r, r)
	local pvp = RMPG.CV.armPvP:GetBool()
	local hand = ply:GetWeapon(RMPG.ARM)
	for _, e in ipairs(ents.FindAlongRay(src, tr.HitPos, -box, box)) do
		if e ~= ply and RMPG.BombTarget(e, hand) and (pvp or not e:IsPlayer()) then
			local c = e:WorldSpaceCenter()
			local along = (c - src):Dot(dir)
			if along > 0 and (src + dir * along):Distance(c) <= r + e:BoundingRadius() * 0.5 then
				RMPG.Disintegrate(e, ply, hand, tr.HitPos)
			end
		end
	end
	if tr.Hit and not tr.HitSky then util.Decal("Scorch", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal) end
	util.ScreenShake(src, 3, 8, 0.3, 500)
end

-- Only one-shot sounds here: the "loop" file does not loop at all, so a sound patch of it died halfway and hung
-- The hand goes down and you hold what you held before
local function HandDown(ply)
	ply:SetNW2Bool("RMPG_ArmHand", false)
	ply.RMPG_ArmHandUntil = nil
	local back = ply.RMPG_ArmBackTo
	ply.RMPG_ArmBackTo = nil
	if ply:HasWeapon(RMPG.ARM) then ply:StripWeapon(RMPG.ARM) end
	if ply:Alive() and back and ply:HasWeapon(back) then ply:SelectWeapon(back) end
end

-- The open hand comes up (it is a weapon of its own while it is up)
local function HandUp(ply)
	if not ply.RMPG_ArmBackTo then
		local cur = ply:GetActiveWeapon()
		ply.RMPG_ArmBackTo = IsValid(cur) and cur:GetClass() ~= RMPG.ARM and cur:GetClass() or nil
	end
	if not ply:HasWeapon(RMPG.ARM) then ply:Give(RMPG.ARM) end
	ply:SelectWeapon(RMPG.ARM)
end

local function ArmEnd(ply)
	ply:SetNW2Bool("RMPG_ArmOn", false)
	ply:StopSound(RMPG.SND.armStart)
	ply:StopSound(RMPG.SND.armLoop)
	if ply:Alive() then ply:EmitSound(RMPG.SND.armStop, 80, 110) end
	HandDown(ply)
end

-- The normal shot: out of the open hand like a gun, and each hit takes rmpg_implant_laser_shot percent of the target's
-- full health (three shots and most things are down). The big burst that burns everything is on its own button.
function RMPG.ArmShot(ply)
	if not RMPG.HasArm(ply) or not ply:Alive() or ply:InVehicle() or ply:GetNW2Bool("RMPG_ArmOn", false) then return end
	local now = CurTime()
	if (ply.RMPG_ArmShotNext or 0) > now then return end
	ply.RMPG_ArmShotNext = now + RMPG.CV.armShotDelay:GetFloat()
	HandUp(ply)
	ply:SetNW2Bool("RMPG_ArmHand", true)
	ply.RMPG_ArmHandUntil = now + 1.6
	local src, dir = ply:GetShootPos(), ply:GetAimVector()
	ply:LagCompensation(true)
	local tr = util.TraceLine({ start = src, endpos = src + dir * RMPG.CV.armRange:GetFloat(), filter = ply, mask = MASK_SHOT })
	ply:LagCompensation(false)
	local e = tr.Entity
	if IsValid(e) and (RMPG.CV.armPvP:GetBool() or not e:IsPlayer()) then
		local max = e:GetMaxHealth()
		if not max or max <= 0 then max = 100 end
		local d = DamageInfo()
		d:SetDamage(math.max(10, max * RMPG.CV.armShotPct:GetFloat() / 100))
		d:SetDamageType(DMG_ENERGYBEAM)
		d:SetAttacker(ply)
		local hand = ply:GetWeapon(RMPG.ARM)
		d:SetInflictor(IsValid(hand) and hand or ply)
		d:SetDamagePosition(tr.HitPos)
		d:SetDamageForce(dir * 16000)
		e:TakeDamageInfo(d)
	end
	if tr.HitWorld and not tr.HitSky then util.Decal("FadingScorch", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal) end
	local ed = EffectData()
	ed:SetEntity(ply)
	ed:SetStart(src)
	ed:SetOrigin(tr.HitPos)
	ed:SetNormal(tr.HitNormal)
	util.Effect("rmpg_akira_bolt", ed, true, true)
	ply:EmitSound(string.format(RMPG.SND.armShot, math.random(1, 2)), 80, math.random(118, 128))
	ply:EmitSound(string.format(RMPG.SND.armShotZap, math.random(1, 3)), 70, math.random(130, 150))
	ply:ViewPunch(Angle(-1.5, math.Rand(-0.6, 0.6), 0))
end

-- One press, one burst: the hand comes up for as long as it burns, then goes back to what you were holding
function RMPG.ArmFire(ply)
	if not RMPG.HasArm(ply) or not ply:Alive() or ply:InVehicle() or ply:GetNW2Bool("RMPG_ArmOn", false) then return end
	local now = CurTime()
	if ply:GetNW2Float("RMPG_ArmBack", 0) > now then return end
	HandUp(ply)
	ply:SetNW2Bool("RMPG_ArmHand", false)
	ply.RMPG_ArmHandUntil = nil
	local len = RMPG.CV.armTime:GetFloat()
	ply.RMPG_ArmEnd = now + len
	ply.RMPG_ArmLoop = 0
	ply:SetNW2Float("RMPG_ArmT", now)
	ply:SetNW2Float("RMPG_ArmBack", now + len + RMPG.CV.armCool:GetFloat())
	ply:SetNW2Bool("RMPG_ArmOn", true)
	ply:EmitSound(RMPG.SND.armStart, 90, 100)
	util.ScreenShake(ply:GetPos(), 8, 20, 0.7, 500)
end

local function CombatOff(ply)
	if ply:GetNW2Bool("RMPG_Combat", false) and RMPG.HasTent(ply) then ply:EmitSound(RMPG.SND.tentFold, 65, 85) end
	ply:SetNW2Bool("RMPG_Combat", false)
	if ply:GetNW2Bool("RMPG_ArmOn", false) then ArmEnd(ply) elseif ply.RMPG_ArmHandUntil then HandDown(ply) end
	if RMPG.TentMode(ply) ~= RMPG.TENT_CATCH then RMPG.TentRelease(ply) end
end

function RMPG.RemoveArm(ply)
	ply:SetNW2Bool("RMPG_Arm", false)
	CombatOff(ply)
end

-- The first implant: where the combat mode is
function RMPG.ImplantHint(ply)
	if ply.RMPG_ImplantHinted then return end
	ply.RMPG_ImplantHinted = true
	RMPG.Notify(ply, "n_impl_combat", nil, 3)
end

local function HasAny(ply)
	return RMPG.HasShield(ply) or RMPG.HasEvac(ply) or RMPG.HasArm(ply) or RMPG.HasTent(ply) or RMPG.HasPrime(ply)
end

net.Receive("rmpg_implant", function(_, ply)
	local a = net.ReadUInt(RMPG.IMPL_BITS)
	if a == RMPG.IMPL_ON then
		if HasAny(ply) and ply:Alive() and not ply:GetNW2Bool("RMPG_Combat", false) then
			ply:SetNW2Bool("RMPG_Combat", true)
			if RMPG.HasTent(ply) then ply:EmitSound(RMPG.SND.tentDeploy, 65, 85) end
		end
		return
	elseif a == RMPG.IMPL_OFF then
		CombatOff(ply)
		return
	elseif a == RMPG.IMPL_CLONE then -- Rick Prime's bodies work without combat mode
		RMPG.PrimeClone(ply)
		return
	elseif a == RMPG.IMPL_SWAP then
		RMPG.PrimeSwap(ply)
		return
	end
	local down = a ~= RMPG.IMPL_HOOK or net.ReadBool()
	if down and not ply:GetNW2Bool("RMPG_Combat", false) then
		RMPG.Notify(ply, "n_impl_need_combat", nil, 0)
	elseif a == RMPG.IMPL_FIRE then
		RMPG.ArmShot(ply)
	elseif a == RMPG.IMPL_POWER then
		RMPG.ArmFire(ply)
	elseif a == RMPG.IMPL_GRAB then
		RMPG.TentGrab(ply)
	elseif a == RMPG.IMPL_HOOK then
		RMPG.TentHook(ply, down)
	end
end)

-- Ten times a second: the burst burns and ends, and the arm is ready again
hook.Add("Think", "rmpg_arm_regen", function()
	local now = CurTime()
	if (RMPG.ArmNextThink or 0) > now then return end
	RMPG.ArmNextThink = now + 0.1
	for _, ply in ipairs(player.GetAll()) do
		if ply:GetNW2Bool("RMPG_ArmOn", false) then
			if now >= (ply.RMPG_ArmEnd or 0) or not ply:Alive() then
				ArmEnd(ply)
			else
				if now >= (ply.RMPG_ArmLoop or 0) then
					ply.RMPG_ArmLoop = now + 2.5
					ply:EmitSound(RMPG.SND.armLoop, 85, 120, 0.9)
				end
				Burn(ply)
			end
		elseif ply.RMPG_ArmHandUntil and (now >= ply.RMPG_ArmHandUntil or not ply:Alive()) then
			HandDown(ply)
		elseif RMPG.HasArm(ply) then
			local back = ply:GetNW2Float("RMPG_ArmBack", 0)
			if back > 0 and now >= back then
				ply:SetNW2Float("RMPG_ArmBack", 0)
				RMPG.Notify(ply, "n_arm_ready", nil, 2)
			end
		end
	end
end)

hook.Add("PostPlayerDeath", "rmpg_arm", function(ply)
	CombatOff(ply)
	ply:SetNW2Float("RMPG_ArmBack", 0)
	if not RMPG.CV.armKeep:GetBool() then RMPG.RemoveArm(ply) end
end)

concommand.Add("rmpg_arm_remove", function(ply)
	if IsValid(ply) and RMPG.HasArm(ply) then
		RMPG.RemoveArm(ply)
		RMPG.Notify(ply, "n_evac_removed", nil, 0)
	end
end)

---------------------------------------------------------------------------
-- Taking an implant out: the chip comes out of the body (with a little blood) and lies in front of you, ready for
-- anyone to implant again. The Implants tab has a button for each; rmpg_implant_out <id> does the same.
---------------------------------------------------------------------------

util.AddNetworkString("rmpg_implant_out")

local CHIPS = {
	shield = { function(p) return RMPG.HasShield(p) end, function(p) RMPG.RemoveShield(p) end, "rmpg_shield_chip" },
	evac = { function(p) return RMPG.HasEvac(p) end, function(p) RMPG.RemoveEvac(p) end, "rmpg_evac_chip" },
	arm = { function(p) return RMPG.HasArm(p) end, function(p) RMPG.RemoveArm(p) end, "rmpg_arm_chip" },
	tent = { function(p) return RMPG.HasTent(p) end, function(p) RMPG.RemoveTent(p) end, "rmpg_tentacle_chip" },
	prime = { function(p) return RMPG.HasPrime(p) end, function(p) RMPG.RemovePrime(p) end, "rmpg_prime_chip" },
}

function RMPG.ExtractImplant(ply, id)
	local c = CHIPS[id]
	if not c or not IsValid(ply) or not ply:Alive() then return false end
	if not c[1](ply) then
		RMPG.Notify(ply, "impl_no_chip", nil, 1)
		return false
	end
	c[2](ply)
	local f = ply:GetAimVector()
	f.z = 0
	if f:LengthSqr() < 0.01 then f = ply:GetForward() end
	f:Normalize()
	local chip = ents.Create(c[3])
	if IsValid(chip) then
		local from = ply:GetShootPos() - Vector(0, 0, 12)
		local tr = util.TraceHull({ start = from, endpos = from + f * 26, mins = Vector(-5, -5, -2), maxs = Vector(5, 5, 2), filter = ply, mask = MASK_SOLID })
		chip:SetPos(tr.HitPos)
		chip:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		chip:Spawn()
		chip:Activate()
		local po = chip:GetPhysicsObject()
		if IsValid(po) then
			po:SetVelocity(f * 90 + Vector(0, 0, 70) + ply:GetVelocity())
			po:AddAngleVelocity(VectorRand() * 200)
		end
	end
	ply:EmitSound(string.format(RMPG.SND.implantOut, math.random(1, 4)), 70, math.random(95, 110))
	ply:EmitSound(RMPG.SND.shieldImplant, 60, 60)
	local ed = EffectData()
	ed:SetOrigin(ply:WorldSpaceCenter() + f * 8)
	ed:SetNormal(f)
	ed:SetScale(3)
	util.Effect("BloodImpact", ed, true, true)
	RMPG.Notify(ply, "n_impl_out", nil, 2)
	return true
end

net.Receive("rmpg_implant_out", function(_, ply)
	if (ply.RMPG_ImplOutT or 0) > CurTime() then return end
	ply.RMPG_ImplOutT = CurTime() + 0.5
	RMPG.ExtractImplant(ply, string.sub(net.ReadString(), 1, 12))
end)

concommand.Add("rmpg_implant_out", function(ply, _, args)
	if IsValid(ply) then RMPG.ExtractImplant(ply, args[1] or "") end
end)

concommand.Add("rmpg_evac_remove", function(ply)
	if IsValid(ply) and RMPG.HasEvac(ply) then
		RMPG.RemoveEvac(ply)
		RMPG.Notify(ply, "n_evac_removed", nil, 0)
	end
end)
