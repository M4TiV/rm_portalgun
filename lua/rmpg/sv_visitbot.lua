-- Server: visitors as real players. When the server has a free slot (rmpg_clone_bots, not singleplayer) the copy is a
-- player bot, made the way the "bot" command makes one: it joins and leaves like a player, has its row in TAB, dies
-- like a player, and everything treats it as one. It is driven from StartCommand: it walks to the one it came for, and
-- either shoots them with a pistol or waves and leaves a present. sv_clones.lua decides when a visitor comes.
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)

function RMPG.VisitBots()
	local n = 0
	for _, p in ipairs(player.GetBots()) do
		if p.RMPG_Visit then n = n + 1 end
	end
	return n
end

function RMPG.CanVisitBot()
	return RMPG.CV.cloneBots:GetBool() and not game.SinglePlayer() and player.GetCount() < game.MaxPlayers()
end

-- A chat line in the language of the one it came for (the server has none of its own)
local function Line(bot, key)
	local v = bot.RMPG_Visit
	local t = v and v.target
	local ru = IsValid(t) and t:IsPlayer() and t:GetInfo("gmod_language") == "ru"
	bot:Say((ru and RMPG.Lang.ru or RMPG.Lang.en)[key] or key)
end

local function Dress(bot)
	local v = bot.RMPG_Visit
	local src = v.source
	if IsValid(src) and src:GetModel() then
		bot:SetModel(src:GetModel())
		bot:SetSkin(src:GetSkin())
		for i = 0, src:GetNumBodyGroups() - 1 do bot:SetBodygroup(i, src:GetBodygroup(i)) end
	end
	bot:SetPlayerColor(RMPG.PersonColor(src))
	bot:StripWeapons()
	if v.hostile then
		bot:Give("weapon_pistol")
		bot:GiveAmmo(150, "Pistol", true)
		bot:SelectWeapon("weapon_pistol")
	end
	bot:SetHealth(100)
	if v.spot then
		bot:SetPos(v.spot)
		bot:SetEyeAngles(Angle(0, v.yaw, 0))
		v.spot = nil
	end
end

-- Back through a portal, then "left the game"
local function Leave(bot)
	local v = bot.RMPG_Visit
	if not v or v.leaving then return end
	v.leaving = true
	local fwd = bot:GetForward()
	fwd.z = 0
	fwd:Normalize()
	local center, ang = RMPG.UprightPortal(bot:GetPos() + fwd * 30, -fwd)
	local p = RMPG.SpawnPortal(NULL, center, ang, RMPG.DEFAULT_COLOR, true)
	if IsValid(p) then timer.Simple(2, function() if IsValid(p) then p:Close() end end) end
	timer.Simple(0.6, function()
		if IsValid(bot) then bot:Kick("Disconnect by user.") end
	end)
end

-- Comes through a portal at spot (facing yaw) as a player bot named after source
function RMPG.SpawnVisitBot(target, source, hostile, spot, yaw)
	if hostile == nil then hostile = math.random() * 100 < RMPG.CV.cloneHostile:GetFloat() end
	local bot = player.CreateNextBot(RMPG.PersonName(source))
	if not IsValid(bot) then return false end
	bot.RMPG_Visit = {
		target = target, source = source, hostile = hostile, spot = spot, yaw = yaw,
		leaveAt = CurTime() + (hostile and 120 or 60), hello = CurTime() + 1,
	}
	timer.Simple(0.1, function() if IsValid(bot) then Dress(bot) end end)
	return true
end

-- The sandbox loadout and model come on spawn: put the copy's on after them
hook.Add("PlayerSpawn", "rmpg_visitbot", function(ply)
	if ply.RMPG_Visit then timer.Simple(0.1, function() if IsValid(ply) then Dress(ply) end end) end
end)

-- A dead visitor does not come back: a few seconds later it quits
hook.Add("PlayerDeathThink", "rmpg_visitbot", function(ply)
	if ply.RMPG_Visit then return false end
end)

hook.Add("PostPlayerDeath", "rmpg_visitbot", function(ply)
	if not ply.RMPG_Visit then return end
	timer.Simple(4, function()
		if IsValid(ply) then ply:Kick("Disconnect by user.") end
	end)
end)

-- A hostile copy hits as hard as the server says
hook.Add("EntityTakeDamage", "rmpg_visitbot", function(target, dmg)
	local a = dmg:GetAttacker()
	if IsValid(a) and a:IsPlayer() and a.RMPG_Visit and dmg:IsBulletDamage() then dmg:SetDamage(RMPG.CV.cloneDamage:GetFloat()) end
end)

-- Shot at by someone: a friendly copy turns on them
hook.Add("PlayerHurt", "rmpg_visitbot", function(ply, attacker)
	local v = ply.RMPG_Visit
	if not v or not IsValid(attacker) or attacker == ply then return end
	if (attacker:IsPlayer() and not RMPG.IgnorePlayers()) or attacker.IsLambdaPlayer or attacker:IsNPC() then
		if not v.hostile then
			v.hostile = true
			ply:Give("weapon_pistol")
			ply:GiveAmmo(150, "Pistol", true)
			ply:SelectWeapon("weapon_pistol")
		end
		v.target = attacker
	end
end)

local function Gift(bot, t)
	local list = RMPG.CLONE_GIFTS
	local e = ents.Create(list[math.random(#list)])
	if not IsValid(e) then return end
	local dir = bot:GetPos() - t:GetPos()
	dir.z = 0
	dir:Normalize()
	local pos = t:GetPos() + dir * 50 + UP * 20
	e:SetPos(pos)
	e:Spawn()
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetScale(0.7)
	util.Effect("rmpg_meeseeks_poof", ed, true, true)
	bot:EmitSound(RMPG.SND.pickup, 70)
end

-- Forward towards where it looks; stuck: it jumps and steps aside for a moment
local function Walk(cmd, ply, v, run, now)
	cmd:SetForwardMove(run and ply:GetRunSpeed() or ply:GetWalkSpeed())
	if run then cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED)) end
	if ply:GetVelocity():Length2D() < 25 then
		v.stuck = v.stuck or now
		if now - v.stuck > 0.5 then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_JUMP))
			v.dodge = now + 0.6
			v.dodgeDir = math.random() < 0.5 and -1 or 1
			v.stuck = nil
		end
	else
		v.stuck = nil
	end
	if (v.dodge or 0) > now then cmd:SetSideMove(v.dodgeDir * ply:GetWalkSpeed()) end
end

hook.Add("StartCommand", "rmpg_visitbot", function(ply, cmd)
	local v = ply.RMPG_Visit
	if not v or not ply:Alive() or v.leaving then return end
	cmd:ClearMovement()
	cmd:ClearButtons()
	local now = CurTime()
	if v.hello and now >= v.hello then
		v.hello = nil
		Line(ply, v.hostile and "clone_hello_bad" or "clone_hello")
	end
	local t = v.target
	if now > v.leaveAt or not RMPG.PersonAlive(t) then
		if not RMPG.PersonAlive(t) then
			v.lost = v.lost or now
			if now - v.lost < 8 then return end
		end
		Line(ply, "clone_bye")
		Leave(ply)
		return
	end
	v.lost = nil
	local eye = ply:EyePos()
	local at = t:IsPlayer() and (t:EyePos() - UP * 10) or (t:WorldSpaceCenter() + UP * 8)
	local ang = (at - eye):Angle()
	local d = ply:GetPos():Distance(t:GetPos())
	local see = not util.TraceLine({ start = eye, endpos = at, filter = { ply, t }, mask = MASK_SHOT }).Hit
	if v.hostile and not (t:IsPlayer() and RMPG.IgnorePlayers()) then
		if d > 450 or not see then
			cmd:SetViewAngles(ang)
			Walk(cmd, ply, v, true, now)
		else
			ang.p = ang.p + math.Rand(-2, 2)
			ang.y = ang.y + math.Rand(-2.5, 2.5)
			cmd:SetViewAngles(ang)
			cmd:SetSideMove(math.sin(now * 1.3 + ply:EntIndex()) * ply:GetWalkSpeed())
			local w = ply:GetActiveWeapon()
			if IsValid(w) and w:Clip1() == 0 then
				cmd:SetButtons(IN_RELOAD)
			elseif now >= (v.nextShot or 0) then
				v.nextShot = now + math.Rand(0.35, 0.7)
				cmd:SetButtons(IN_ATTACK)
			end
		end
		return
	end
	cmd:SetViewAngles(ang)
	if not v.gifted then
		if d > 90 then
			Walk(cmd, ply, v, false, now)
		elseif not v.giftAt then
			v.giftAt = now + 0.8
			ply:DoAnimationEvent(PLAYERANIMEVENT_CUSTOM_GESTURE, ACT_GMOD_GESTURE_WAVE)
			ply:EmitSound(string.format(RMPG.SND.cloneHi, math.random(1, 2)), 70)
			Line(ply, "clone_gift")
		elseif now >= v.giftAt then
			Gift(ply, t)
			v.gifted = true
			v.leaveAt = math.min(v.leaveAt, now + 25)
		end
	elseif d > 180 then
		Walk(cmd, ply, v, false, now)
	end
end)
