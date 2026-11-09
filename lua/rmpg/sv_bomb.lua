-- Server: Rick Prime's bomb - the detonator, the pull during the countdown, disintegration and the blast wave
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local SKIP = { rmpg_portal = true, rmpg_meltdown = true }

-- Anything the bomb can affect: players, NPCs, vehicles and loose physics objects (not map brushes or doors)
local function Target(e, bomb)
	if not IsValid(e) or e == bomb or e:IsWorld() or e.RMPG_Vaporized or SKIP[e:GetClass()] then return false end
	if IsValid(e:GetParent()) then return false end
	if e.RMPG_Bombable then return true end
	if e:IsPlayer() then return e:Alive() and not e:HasGodMode() end
	if e:IsNPC() or e:IsNextBot() then return e:Health() > 0 end
	if e:IsWeapon() and IsValid(e:GetOwner()) then return false end
	if e:IsVehicle() then return true end
	if e:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
	return IsValid(e:GetPhysicsObject())
end

RMPG.BombTarget = Target

-- Bombs a detonator works with: Rick Prime's and the neutrino bomb
local function LinkedBombs(ply)
	local list = {}
	for _, class in ipairs({ RMPG.BOMB, RMPG.NEUTRINO }) do
		for _, b in ipairs(ents.FindByClass(class)) do
			if b:IsLinked() and b:GetLinker() == ply and b:GetBlastTime() <= 0 then list[#list + 1] = b end
		end
	end
	return list
end

-- LMB on the detonator: every bomb linked to this player starts counting down
function RMPG.DetonateBombs(ply)
	local list = LinkedBombs(ply)
	for _, b in ipairs(list) do b:Trigger() end
	return #list
end

function RMPG.UnlinkBombs(ply)
	local list = LinkedBombs(ply)
	for _, b in ipairs(list) do
		b:SetArmed(false)
		b:SetLinker(NULL)
	end
	return #list
end

-- Countdown: things within the pull radius get dragged toward the bomb (k = 0..1 ramps the strength up)
function RMPG.BombPull(bomb, center, R, k)
	if R <= 0 then return end
	local dt = FrameTime()
	for _, e in ipairs(ents.FindInSphere(center, R)) do
		if Target(e, bomb) and not e:IsVehicle() and e:GetClass() ~= RMPG.BOMB then
			local d = center - e:WorldSpaceCenter()
			local dist = math.max(d:Length(), 1)
			local dir = d / dist
			local near = 1 - dist / R
			local accel = (900 + 1600 * near * near) * k
			if e:IsPlayer() then
				-- strong enough to drag you, weak enough to sprint out of
				if e:GetVelocity():Dot(dir) < 320 then e:SetVelocity(dir * (accel * dt)) end
			elseif e:IsNPC() or e:IsNextBot() then
				e:SetPos(e:GetPos() + dir * math.min((60 + 240 * near) * k * dt, dist))
			else
				for i = 0, e:GetPhysicsObjectCount() - 1 do
					local po = e:GetPhysicsObjectNum(i)
					if IsValid(po) and po:IsMotionEnabled() and po:GetVelocity():Length() < 900 then
						po:Wake()
						local mass = po:GetMass()
						po:ApplyForceCenter((center - po:GetPos()):GetNormalized() * (accel * mass * dt) + UP * (300 * mass * dt))
					end
				end
			end
		end
	end
end

-- A bomb leaves nothing of a body, so nothing that lived in it or was built into it goes on: no worm comes out of it, no
-- chip is left in it
local BOMBS = { rmpg_prime_bomb = true, rmpg_neutrino_bomb = true, rmpg_black_hole = true }

function RMPG.IsBomb(e)
	return IsValid(e) and BOMBS[e:GetClass()] == true
end

function RMPG.WipeBody(e)
	if not IsValid(e) then return end
	if RMPG.WormWipe then RMPG.WormWipe(e) end
	if e:IsPlayer() then
		RMPG.RemoveShield(e)
		RMPG.RemoveEvac(e)
		RMPG.RemoveArm(e)
		RMPG.RemoveTent(e)
		RMPG.RemovePrime(e)
	end
end

-- Remove a corpse or entity in a cloud of black flakes (the flakes are built on the client from the body)
function RMPG.Disintegrate(e, attacker, inflictor, origin)
	if not IsValid(e) or e.RMPG_Vaporized then return end
	if e:IsPlayer() and (e:HasGodMode() or not e:Alive()) then return end
	attacker = IsValid(attacker) and attacker or game.GetWorld()
	inflictor = IsValid(inflictor) and inflictor or attacker

	if e:IsVehicle() then
		local driver = e.GetDriver and e:GetDriver()
		if IsValid(driver) then
			driver:ExitVehicle()
			RMPG.Disintegrate(driver, attacker, inflictor, origin)
		end
	end

	e.RMPG_Vaporized = true
	e:SetNW2Float("RMPG_Vapor", CurTime())
	local ed = EffectData()
	ed:SetEntity(e)
	ed:SetOrigin(e:WorldSpaceCenter())
	ed:SetStart(origin)
	ed:SetRadius(math.min(e:BoundingRadius(), 200))
	util.Effect("rmpg_disintegrate", ed, true, true)
	e:EmitSound(string.format(RMPG.SND.disint, math.random(1, 4)), 80, math.random(90, 110))

	-- give the clients a moment to read the body's shape, then it is gone. The implants know (RMPG_Vaporized): no
	-- evacuation jump and no Rick Prime revival from a body that is not there any more
	timer.Simple(0.05, function()
		if not IsValid(e) then return end
		if e:IsPlayer() or e:IsNPC() or e:IsNextBot() then
			local isPlayer = e:IsPlayer()
			if isPlayer then timer.Simple(1, function() if IsValid(e) then e.RMPG_Vaporized = nil end end) end
			local dmg = DamageInfo()
			dmg:SetDamage(e:Health() + (isPlayer and e:Armor() or 0) + 1000)
			dmg:SetDamageType(DMG_ENERGYBEAM)
			dmg:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
			dmg:SetInflictor(IsValid(inflictor) and inflictor or game.GetWorld())
			dmg:SetDamagePosition(origin or e:WorldSpaceCenter())
			e:TakeDamageInfo(dmg)
			if not IsValid(e) then return end
			if isPlayer then
				if e:Alive() then e:Kill() end
			elseif e.IsLambdaPlayer then
				-- a Lambda player dies and comes back by itself; removed, its own timers would go on calling a NULL entity
				e.RMPG_Vaporized = nil
			elseif e:Health() > 0 then
				e:Remove()
			end
		else
			e:Remove()
		end
	end)
end

-- No corpse is left behind (server-side ragdolls; client ragdolls are hidden in cl_hud)
hook.Add("CreateEntityRagdoll", "rmpg_disintegrated", function(owner, rag)
	if IsValid(owner) and CurTime() - owner:GetNW2Float("RMPG_Vapor", -100) < 1 then
		rag:SetNoDraw(true)
		SafeRemoveEntityDelayed(rag, 0)
	end
end)

-- The blast: disintegrate inside killR, 40 % -> 30 % of max health (rmpg_bomb_damage_near / _far) and a strong push out to blastR
function RMPG.BombBlast(bomb, center, killR, blastR, attacker)
	local fiveM = 5 * RMPG.UNITS_PER_METER
	local near, far = RMPG.CV.bombNear:GetFloat() / 100, RMPG.CV.bombFar:GetFloat() / 100
	for _, e in ipairs(ents.FindInSphere(center, blastR)) do
		if Target(e, bomb) then
			local c = e:WorldSpaceCenter()
			local dist = math.max(c:Distance(center) - math.min(e:BoundingRadius() * 0.5, 40), 0)
			if e:GetClass() == RMPG.BOMB then
				e:Trigger(math.Rand(0.25, 0.55))
			elseif dist <= killR then
				RMPG.Disintegrate(e, attacker, bomb, center)
			else
				local dir = c - center
				dir:Normalize()
				local far = math.Clamp((dist - killR) / math.max(blastR - killR, 1), 0, 1)
				local pct = dist <= fiveM and near or Lerp(math.Clamp((dist - fiveM) / math.max(blastR - fiveM, 1), 0, 1), near, far)
				local open = not util.TraceLine({ start = center, endpos = c, mask = MASK_SOLID_BRUSHONLY }).Hit
				if not open then pct = pct * 0.5 end
				local push = Lerp(far, 1100, 380) * (open and 1 or 0.4)

				if e:IsPlayer() or e:IsNPC() or e:IsNextBot() then
					local dmg = DamageInfo()
					dmg:SetDamage(math.ceil(math.max(e:GetMaxHealth(), 1) * pct))
					dmg:SetDamageType(DMG_BLAST)
					dmg:SetAttacker(attacker)
					dmg:SetInflictor(bomb)
					dmg:SetDamagePosition(center)
					dmg:SetDamageForce(dir * push * 80)
					e:TakeDamageInfo(dmg)
					if IsValid(e) then
						local kick = dir * push + UP * Lerp(far, 380, 200)
						if e:IsPlayer() then e:SetVelocity(kick) else e:SetVelocity(kick * 0.6) end
					end
				else
					for i = 0, e:GetPhysicsObjectCount() - 1 do
						local po = e:GetPhysicsObjectNum(i)
						if IsValid(po) and po:IsMotionEnabled() then
							po:Wake()
							po:ApplyForceCenter((dir * push + UP * 250) * po:GetMass())
						end
					end
				end
			end
		end
	end
end
