-- Server: what a player with a brain worm in the head needs to know to see the world their way (rmpg/cl_happy.lua): every
-- bullet, for its rainbow, and every explosion, for its smiling cloud
RMPG = RMPG or {}

util.AddNetworkString("rmpg_happy")

local function Seers()
	local t = {}
	for _, ply in ipairs(player.GetHumans()) do
		if ply:GetNW2Float("RMPG_Wormed", 0) > 0 then t[#t + 1] = ply end
	end
	return t
end

hook.Add("PostEntityFireBullets", "rmpg_happy", function(ent, data)
	local list = Seers()
	local tr = data.Trace
	if #list == 0 or not tr then return end
	net.Start("rmpg_happy", true)
	net.WriteBool(false)
	net.WriteVector(tr.StartPos)
	net.WriteVector(tr.HitPos)
	net.Send(list)
end)

local function Boom(pos)
	local list = Seers()
	if #list == 0 then return end
	net.Start("rmpg_happy", true)
	net.WriteBool(true)
	net.WriteVector(pos)
	net.Send(list)
end

hook.Add("EntityEmitSound", "rmpg_happy", function(t)
	local n = string.lower(t.SoundName or "")
	if string.find(n, "explo", 1, true) then
		local pos = t.Pos or (IsValid(t.Entity) and t.Entity:GetPos())
		if pos then Boom(pos) end
	end
end)

hook.Add("EntityTakeDamage", "rmpg_happy", function(ent, dmg)
	if not dmg:IsExplosionDamage() then return end
	local src = dmg:GetInflictor()
	Boom(IsValid(src) and not src:IsPlayer() and src:GetPos() or dmg:GetDamagePosition())
end)
