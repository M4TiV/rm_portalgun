-- Server: Rick Prime's chip.
--   Wounds: 2.5 seconds after the last hit health comes back to full within about a second, and the blood is gone
--   from the body.
--   A hit that would kill (down to 1 health or less, a blast too) is a fake death: you fall as a ragdoll, lie there a
--   moment, get up laughing with rmpg_implant_prime_hp health and rmpg_implant_prime_armor armour, and the chip needs
--   rmpg_implant_prime_cool seconds before it can do it again. Meanwhile a lethal hit moves you into your nearest body.
--   Bodies: you make bodies of yourself (rmpg_prime_body) and move your mind into one. They follow you and shoot whoever
--   hurt you or one of them (remembered here) and NPCs that hate you.
-- Torn limbs are left out until version 1.0 (the old code is in dev/wip/lua/rmpg/sv_prime_with_regen.lua).
-- The fake death's camera and the clean body are in cl_prime.lua.
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local HEAL_DELAY = 2.5 -- seconds after the last hit before the wounds close
local FAKE_TIME = 3    -- seconds lying as a ragdoll

function RMPG.HasPrime(ply)
	return ply:GetNW2Bool("RMPG_Prime", false)
end

local function Bodies(ply)
	local list = ply.RMPG_Bodies or {}
	ply.RMPG_Bodies = list
	for i = #list, 1, -1 do
		if not IsValid(list[i]) then table.remove(list, i) end
	end
	return list
end

function RMPG.ImplantPrime(ply)
	if RMPG.HasPrime(ply) then return false end
	ply:SetNW2Bool("RMPG_Prime", true)
	ply:SetNW2Float("RMPG_PrimeBack", 0)
	ply:EmitSound(RMPG.SND.shieldImplant, 70, 70)
	return true
end

local function Flash(pos)
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetNormal(UP)
	ed:SetScale(10)
	util.Effect("BloodImpact", ed, true, true)
	ed:SetMagnitude(2)
	ed:SetRadius(6)
	util.Effect("Sparks", ed, true, true)
end

-- The wounds are gone: the blood on the model too (on every client, cl_prime.lua)
local function Clean(ply)
	ply:RemoveAllDecals()
	ply:SetNW2Float("RMPG_PrimeClean", CurTime())
end

---------------------------------------------------------------------------
-- The fake death
---------------------------------------------------------------------------

local function Hide(ply, on)
	ply:SetNoDraw(on)
	ply:SetNotSolid(on)
	ply:DrawWorldModel(not on)
	ply:DrawViewModel(not on)
	ply:Freeze(on)
	if on then ply:AddFlags(FL_NOTARGET) else ply:RemoveFlags(FL_NOTARGET) end
end

-- Up again where the ragdoll lies: room for the body near its middle
local function GetUp(ply)
	local st = ply.RMPG_PrimeFake
	ply.RMPG_PrimeFake = nil
	ply:SetNW2Entity("RMPG_PrimeRag", NULL)
	if not IsValid(ply) then return end
	Hide(ply, false)
	if not st.god then ply:GodDisable() end
	if not ply:Alive() then
		SafeRemoveEntity(st.rag)
		return
	end
	local rag = st.rag
	if IsValid(rag) then
		local po = rag:GetPhysicsObject()
		local mid = IsValid(po) and po:GetPos() or rag:GetPos()
		local mins, maxs = ply:GetHull()
		for _, dz in ipairs({ 4, 20, 36, -10, 52 }) do
			local p = mid + UP * dz
			local ground = util.TraceLine({ start = p, endpos = p - UP * 80, mask = MASK_PLAYERSOLID, filter = { ply, rag } })
			local at = ground.Hit and ground.HitPos + UP * 1 or p
			if not util.TraceHull({ start = at, endpos = at, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = { ply, rag } }).Hit then
				ply:SetPos(at)
				break
			end
		end
		rag:Remove()
	end
	ply:SetHealth(RMPG.CV.primeHP:GetInt())
	ply:SetArmor(RMPG.CV.primeArmor:GetInt())
	Clean(ply)
	ply:ScreenFade(SCREENFADE.IN, Color(255, 40, 40, 140), 0.8, 0)
	ply:EmitSound(RMPG.SND.primeLaugh[math.random(#RMPG.SND.primeLaugh)], 80, math.random(96, 104))
	ply:EmitSound(RMPG.SND.primeRevive, 75, 110)
	Flash(ply:WorldSpaceCenter())
	RMPG.Notify(ply, "n_prime_revive", nil, 2)
end

local function FakeDeath(ply, dmg, now)
	local force = dmg:GetDamageForce()
	local push = force:IsZero() and VectorRand() * 120 or force:GetNormalized() * math.min(force:Length() / 60, 700)
	local rag = RMPG.RagdollOf(ply, ply:GetVelocity() + push + UP * 80)
	ply:SetNW2Float("RMPG_PrimeBack", now + RMPG.CV.primeCool:GetFloat())
	ply.RMPG_PrimeFake = { rag = rag, god = ply:HasGodMode(), up = now + FAKE_TIME }
	ply:SetNW2Entity("RMPG_PrimeRag", IsValid(rag) and rag or NULL)
	ply:GodEnable()
	Hide(ply, true)
	ply:EmitSound(string.format(RMPG.SND.primeTear, math.random(2, 4)), 80, math.random(90, 105))
	Flash(ply:WorldSpaceCenter())
end

-- Moves your mind into one of your bodies (the next one, or body): you stand where it stood, it stands where you were.
-- dmg: you were about to die, and the body you leave takes that hit
function RMPG.PrimeSwap(ply, body, dmg)
	if not RMPG.HasPrime(ply) or not ply:Alive() or ply:InVehicle() or ply.RMPG_PrimeFake then return false end
	local list = Bodies(ply)
	if not IsValid(body) then
		if #list == 0 then
			RMPG.Notify(ply, "n_prime_nobody", nil, 1)
			return false
		end
		ply.RMPG_SwapNext = (ply.RMPG_SwapNext or 0) % #list + 1
		body = list[ply.RMPG_SwapNext]
	end
	local pPos, pYaw, pHP = ply:GetPos(), ply:EyeAngles().y, ply:Health()
	local bPos, bYaw, bHP = body:GetPos(), body:GetAngles().y, body:Health()
	ply:SetPos(bPos)
	ply:SetEyeAngles(Angle(0, bYaw, 0))
	ply:SetVelocity(-ply:GetVelocity())
	ply:SetHealth(math.max(bHP, 1))
	body:SetPos(pPos)
	body:SetAngles(Angle(0, pYaw, 0))
	body:SetHealth(math.max(pHP, 1))
	ply:ScreenFade(SCREENFADE.IN, Color(120, 255, 160, 120), 0.5, 0)
	ply:EmitSound(RMPG.SND.primeSwap, 75, 125)
	body:EmitSound(RMPG.SND.primeSwap, 70, 125)
	if dmg then
		local att, inf, kind = dmg:GetAttacker(), dmg:GetInflictor(), dmg:GetDamageType()
		timer.Simple(0, function()
			if not IsValid(body) then return end
			local d = DamageInfo()
			d:SetDamage(body:Health() + 100)
			d:SetDamageType(kind)
			d:SetAttacker(IsValid(att) and att or body)
			d:SetInflictor(IsValid(inf) and inf or body)
			body:TakeDamageInfo(d)
		end)
		RMPG.Notify(ply, "n_prime_mind", nil, 2)
	end
	return true
end

-- A body of yourself, a little in front of you and facing you
function RMPG.PrimeClone(ply)
	if not RMPG.HasPrime(ply) or not ply:Alive() or ply:InVehicle() or ply.RMPG_PrimeFake then return end
	local list = Bodies(ply)
	if #list >= RMPG.CV.primeClones:GetInt() then
		RMPG.Notify(ply, "n_prime_max", nil, 1)
		return
	end
	local f = ply:GetForward()
	f.z = 0
	f:Normalize()
	local from = ply:GetPos() + UP * 4
	local tr = util.TraceHull({ start = from, endpos = from + f * 64, mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72), filter = ply, mask = MASK_PLAYERSOLID })
	if tr.Hit then
		RMPG.Notify(ply, "n_prime_room", nil, 1)
		return
	end
	local b = ents.Create("rmpg_prime_body")
	if not IsValid(b) then return end
	b:SetModel(ply:GetModel())
	b:SetSkin(ply:GetSkin())
	for i = 0, ply:GetNumBodyGroups() - 1 do b:SetBodygroup(i, ply:GetBodygroup(i)) end
	b:SetBodyColor(ply:GetPlayerColor())
	b:SetMind(ply)
	b:SetPos(tr.HitPos - UP * 4)
	b:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	b:Spawn()
	b:Activate()
	list[#list + 1] = b
	Flash(b:WorldSpaceCenter())
	b:EmitSound(RMPG.SND.primeSwap, 70, 90)
end

-- The last word on damage, after the shield and the evacuation (sv_implants.lua). True: the hit does not land
function RMPG.PrimeDamage(ply, dmg)
	-- disintegration takes the body away whole, there is nothing to get up or move out of
	if not RMPG.HasPrime(ply) or ply.RMPG_Vaporized then return end
	if ply.RMPG_PrimeFake then return true end -- "dead" already
	local now = CurTime()
	ply.RMPG_PrimeHurt = now
	if dmg:GetDamage() < ply:Health() - 1 then return end
	-- down to 1 health or less: a fake death if the chip is ready, otherwise into the nearest body
	if ply:GetNW2Float("RMPG_PrimeBack", 0) <= now then
		FakeDeath(ply, dmg, now)
		return true
	end
	local best, bd
	for _, b in ipairs(Bodies(ply)) do
		local d = b:GetPos():DistToSqr(ply:GetPos())
		if not bd or d < bd then best, bd = b, d end
	end
	if best and RMPG.PrimeSwap(ply, best, dmg) then return true end
end

function RMPG.RemovePrime(ply)
	if not RMPG.HasPrime(ply) then return end
	ply:SetNW2Bool("RMPG_Prime", false)
	if ply.RMPG_PrimeFake then GetUp(ply) end
	for _, b in ipairs(Bodies(ply)) do b:Remove() end
end

-- Ten times a second: the fake dead get up, the wounded heal, the chip charges
hook.Add("Think", "rmpg_prime", function()
	local now = CurTime()
	if now < (RMPG.PrimeNextThink or 0) then return end
	RMPG.PrimeNextThink = now + 0.1
	for _, ply in ipairs(player.GetAll()) do
		local st = ply.RMPG_PrimeFake
		if st then
			if now >= st.up or not ply:Alive() then GetUp(ply) end
		elseif RMPG.HasPrime(ply) and ply:Alive() then
			local hp, max = ply:Health(), ply:GetMaxHealth()
			if hp < max and now - (ply.RMPG_PrimeHurt or 0) >= HEAL_DELAY then
				if not ply.RMPG_PrimeHealing then
					ply.RMPG_PrimeHealing = true
					Clean(ply)
				end
				ply:SetHealth(math.min(max, hp + math.max(math.ceil(max * 0.09), RMPG.CV.primeRegen:GetFloat() * 0.1)))
			elseif hp >= max or now - (ply.RMPG_PrimeHurt or 0) < HEAL_DELAY then
				ply.RMPG_PrimeHealing = nil
			end
			local back = ply:GetNW2Float("RMPG_PrimeBack", 0)
			if back > 0 and now >= back then
				ply:SetNW2Float("RMPG_PrimeBack", 0)
				RMPG.Notify(ply, "n_prime_ready", nil, 2)
			end
		end
	end
end)

-- Who hurt you or one of your bodies: your bodies go after them. Your bodies never hurt you or each other.
hook.Add("EntityTakeDamage", "rmpg_prime_guard", function(victim, dmg)
	local a = dmg:GetAttacker()
	if not IsValid(a) or a == victim then return end
	local m = victim:IsPlayer() and victim or (victim:GetClass() == "rmpg_prime_body" and victim:GetMind())
	if not IsValid(m) then return end
	if a:GetClass() == "rmpg_prime_body" and a:GetMind() == m then return true end
	if a == m or not (a:IsPlayer() or a:IsNPC() or a:IsNextBot()) then return end
	if not m.RMPG_Bodies or #m.RMPG_Bodies == 0 then return end
	m.RMPG_PrimeFoe, m.RMPG_PrimeFoeT = a, CurTime()
end)

hook.Add("PostPlayerDeath", "rmpg_prime", function(ply)
	if ply.RMPG_PrimeFake then GetUp(ply) end
	if not RMPG.CV.primeKeep:GetBool() then RMPG.RemovePrime(ply) end
end)

hook.Add("PlayerDisconnected", "rmpg_prime", function(ply)
	if ply.RMPG_PrimeFake and IsValid(ply.RMPG_PrimeFake.rag) then ply.RMPG_PrimeFake.rag:Remove() end
	for _, b in ipairs(Bodies(ply)) do b:Remove() end
end)

concommand.Add("rmpg_prime_remove", function(ply)
	if IsValid(ply) and RMPG.HasPrime(ply) then
		RMPG.RemovePrime(ply)
		RMPG.Notify(ply, "n_evac_removed", nil, 0)
	end
end)
