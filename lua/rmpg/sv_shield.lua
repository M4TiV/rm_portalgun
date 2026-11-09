-- Server: the energy shield implanted from a chip.
-- It soaks up damage: a rocket takes up to 40 %, a crossbow bolt 30 %, anything else in proportion to the damage,
-- and a hit as big as the capacity (250 by default) always cracks it. After a hit it recharges once a pause has
-- passed (bigger hit = longer pause); a cracked shield is gone for 1.5 minutes. Rick Prime's bomb goes straight through.
-- All of these numbers are server settings (rmpg_shield_*).
RMPG = RMPG or {}

util.AddNetworkString("rmpg_shield_fx")

RMPG.ImplantHandlers = RMPG.ImplantHandlers or {}

local UP = Vector(0, 0, 1)
local BOLTS = { crossbow_bolt = true, weapon_crossbow = true } -- a fixed percent per hit
local ROCKETS = { rpg_missile = true, weapon_rpg = true }       -- at most a percent per hit
local PASS = bit.bor(DMG_FALL, DMG_DROWN, DMG_POISON, DMG_RADIATION, DMG_NERVEGAS, DMG_DROWNRECOVER, DMG_PARALYZE)
local ZAPS = { 1, 2, 3, 5, 6, 7, 8, 9 }

function RMPG.HasShield(ply)
	return ply:GetNW2Bool("RMPG_Shield", false)
end

local function FX(ply, kind, dir, k)
	net.Start("rmpg_shield_fx")
	net.WriteEntity(ply)
	net.WriteUInt(kind, 2)
	net.WriteNormal(dir)
	net.WriteUInt(math.Clamp(math.floor(k), 0, 100), 7)
	net.SendPVS(ply:WorldSpaceCenter())
end

function RMPG.ImplantShield(ply)
	if RMPG.HasShield(ply) then return false end
	ply:SetNW2Bool("RMPG_Shield", true)
	ply:SetNW2Float("RMPG_ShieldPct", 100)
	ply:SetNW2Float("RMPG_ShieldBack", 0)
	ply.RMPG_ShieldRegenAt = 0
	ply:EmitSound(RMPG.SND.shieldImplant, 70)
	ply:EmitSound(RMPG.SND.shieldUp, 65, 120)
	FX(ply, RMPG.SHIELD_UP, UP, 100)
	return true
end

function RMPG.RemoveShield(ply)
	ply:SetNW2Bool("RMPG_Shield", false)
	ply:SetNW2Float("RMPG_ShieldBack", 0)
end

function RMPG.BreakShield(ply, dir)
	if ply:GetNW2Float("RMPG_ShieldBack", 0) > 0 then return end
	local wait = RMPG.CV.shieldRecover:GetFloat()
	ply:SetNW2Float("RMPG_ShieldPct", 0)
	ply:SetNW2Float("RMPG_ShieldBack", CurTime() + wait)
	ply:EmitSound(string.format(RMPG.SND.shieldBreak, math.random(1, 3)), 80)
	ply:EmitSound(RMPG.SND.shieldBreak2, 75, 120)
	FX(ply, RMPG.SHIELD_BREAK, dir or UP, 100)
	RMPG.Notify(ply, "n_shield_broken", { string.format("%d:%02d", math.floor(wait / 60), math.floor(wait % 60)) }, 1)
end

-- Direction from the player's middle toward where the damage came from
local function HitDir(ply, dmg)
	local c = ply:WorldSpaceCenter()
	local p = dmg:GetDamagePosition()
	if p:IsZero() then
		local src = dmg:GetInflictor()
		if not IsValid(src) or src == ply then src = dmg:GetAttacker() end
		p = IsValid(src) and src:WorldSpaceCenter() or (c + ply:GetForward() * 10)
	end
	local d = p - c
	if d:LengthSqr() < 1 then d = ply:GetForward() end
	d:Normalize()
	return d
end

-- Hitscan weapons report the shooter as the inflictor; use the weapon in their hands instead
local function SourceClass(dmg)
	local inf = dmg:GetInflictor()
	local cls = IsValid(inf) and inf:GetClass() or ""
	if cls == "player" or cls == "" or (IsValid(inf) and inf:IsNPC()) then
		local att = dmg:GetAttacker()
		local w = IsValid(att) and att.GetActiveWeapon and att:GetActiveWeapon()
		if IsValid(w) then return w:GetClass() end
	end
	return cls
end

-- One link of the implant chain (sv_implants.lua): true when the shield stopped the hit
RMPG.ImplantHandlers.shield = function(ply, dmg)
	if not RMPG.HasShield(ply) then return end
	if bit.band(dmg:GetDamageType(), PASS) ~= 0 then return end
	local amount = dmg:GetDamage()
	if amount <= 0 then return end
	local inf = dmg:GetInflictor()
	-- no shield survives a bomb
	if RMPG.IsBomb(inf) then
		RMPG.BreakShield(ply, HitDir(ply, dmg))
		return
	end
	if ply:GetNW2Float("RMPG_ShieldBack", 0) > 0 then return end

	local CV = RMPG.CV
	local cap = math.max(CV.shieldCap:GetFloat(), 1)
	local perPoint = 100 / cap -- percent of the shield per point of damage
	local cls = SourceClass(dmg)
	local loss = amount * perPoint
	if BOLTS[cls] then loss = CV.shieldBolt:GetFloat() end
	if ROCKETS[cls] then loss = math.min(CV.shieldRocket:GetFloat(), loss) end
	local pct = ply:GetNW2Float("RMPG_ShieldPct", 100)
	local dir = HitDir(ply, dmg)

	if amount >= cap or loss >= pct then
		-- what the shield could not hold goes through
		local over = math.min((loss - pct) / perPoint, amount)
		RMPG.BreakShield(ply, dir)
		if over > 0 then
			dmg:SetDamage(over)
			return
		end
		return true
	end

	ply:SetNW2Float("RMPG_ShieldPct", pct - loss)
	ply.RMPG_ShieldRegenAt = CurTime() + CV.shieldDelay:GetFloat() + loss * 0.12 -- the harder the hit, the longer before it recharges
	ply:EmitSound(string.format(RMPG.SND.shieldHit, math.random(1, 2)), 75, math.random(95, 112))
	if loss >= 15 then ply:EmitSound(string.format(RMPG.SND.shieldZap, ZAPS[math.random(#ZAPS)]), 75) end
	FX(ply, RMPG.SHIELD_HIT, dir, 20 + loss * 2)
	return true
end

hook.Add("Think", "rmpg_shield_regen", function()
	local now = CurTime()
	if (RMPG.ShieldNextThink or 0) > now then return end
	RMPG.ShieldNextThink = now + 0.1
	local step = RMPG.CV.shieldRegen:GetFloat() * 0.1
	for _, ply in ipairs(player.GetAll()) do
		if RMPG.HasShield(ply) and ply:Alive() then
			local back = ply:GetNW2Float("RMPG_ShieldBack", 0)
			if back > 0 then
				if now >= back then
					ply:SetNW2Float("RMPG_ShieldBack", 0)
					ply:SetNW2Float("RMPG_ShieldPct", 100)
					ply:EmitSound(RMPG.SND.shieldUp, 70)
					FX(ply, RMPG.SHIELD_UP, UP, 100)
					RMPG.Notify(ply, "n_shield_up", nil, 2)
				end
			else
				local pct = ply:GetNW2Float("RMPG_ShieldPct", 100)
				if pct < 100 and step > 0 and now >= (ply.RMPG_ShieldRegenAt or 0) then
					ply:SetNW2Float("RMPG_ShieldPct", math.min(100, pct + step))
				end
			end
		end
	end
end)

-- The implant is lost on death unless the server keeps it; a kept shield comes back fresh
hook.Add("PostPlayerDeath", "rmpg_shield", function(ply)
	if not RMPG.CV.shieldKeep:GetBool() then RMPG.RemoveShield(ply) end
end)

hook.Add("PlayerSpawn", "rmpg_shield", function(ply)
	if RMPG.HasShield(ply) then
		ply:SetNW2Float("RMPG_ShieldPct", 100)
		ply:SetNW2Float("RMPG_ShieldBack", 0)
	end
end)

concommand.Add("rmpg_shield_remove", function(ply)
	if IsValid(ply) and RMPG.HasShield(ply) then
		RMPG.RemoveShield(ply)
		RMPG.Notify(ply, "n_shield_removed", nil, 0)
	end
end)
