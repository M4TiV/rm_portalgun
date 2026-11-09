-- Mr. Meeseeks pops in or out: a puff of round white-blue cartoon cloud that swirls outward and thins away
local PUFF = Material("rmpg/fx_smoke")

function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local k = math.max(data:GetScale(), 0.3)
	local em = ParticleEmitter(pos, false)
	if not em then return end

	-- round puffs right away
	for _ = 1, math.floor(24 * k) do
		local dir = VectorRand()
		dir.z = dir.z * 1.3
		dir:Normalize()
		local p = em:Add(PUFF, pos + dir * 12 * k)
		if p then
			p:SetVelocity(dir * math.Rand(60, 150) * k)
			p:SetAirResistance(170)
			p:SetDieTime(math.Rand(0.45, 0.85))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(14, 24) * k)
			p:SetEndSize(math.Rand(30, 48) * k)
			p:SetRoll(math.Rand(0, 360))
			p:SetRollDelta(math.Rand(-1.5, 1.5))
			local c = math.random(225, 255)
			p:SetColor(c - 20, c, 255)
		end
	end

	-- wisps spiralling outward
	local n = math.floor(18 * k)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local dir = Vector(math.cos(a), math.sin(a), math.Rand(-0.7, 0.9))
		local tang = Vector(-math.sin(a), math.cos(a), 0)
		local p = em:Add(PUFF, pos + dir * 28 * k)
		if p then
			p:SetVelocity((dir * 140 + tang * 130) * k)
			p:SetAirResistance(80)
			p:SetDieTime(math.Rand(0.7, 1.2))
			p:SetStartAlpha(230)
			p:SetEndAlpha(0)
			p:SetStartSize(9 * k)
			p:SetEndSize(2 * k)
			p:SetStartLength(34 * k)
			p:SetEndLength(8 * k)
			p:SetColor(225, 248, 255)
		end
	end

	local g = em:Add(RMPG.Mat.glow, pos)
	if g then
		g:SetDieTime(0.3)
		g:SetStartAlpha(220)
		g:SetEndAlpha(0)
		g:SetStartSize(60 * k)
		g:SetEndSize(140 * k)
		g:SetColor(170, 230, 255)
	end
	em:Finish()

	local dl = DynamicLight(math.random(8192, 16384))
	if dl then
		dl.pos = pos
		dl.r, dl.g, dl.b = 150, 220, 255
		dl.brightness = 2
		dl.decay = 900
		dl.size = 200 * k
		dl.dietime = CurTime() + 0.4
	end
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
