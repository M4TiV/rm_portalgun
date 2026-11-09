-- Something touched the acid of a vat (rmpg_acid_vat): green bubbles and a puff of green steam
local SMOKE = Material("rmpg/fx_smoke")

function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local em = ParticleEmitter(pos, false)
	if not em then return end
	local many = RMPG.CL.particles:GetBool()
	for _ = 1, many and 14 or 5 do
		local p = em:Add(RMPG.Mat.glow, pos + VectorRand() * 10)
		if p then
			p:SetVelocity(Vector(0, 0, math.Rand(30, 90)) + VectorRand() * 30)
			p:SetGravity(Vector(0, 0, -120))
			p:SetDieTime(math.Rand(0.4, 0.9))
			p:SetStartAlpha(220)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(2, 5))
			p:SetEndSize(0)
			p:SetColor(150, 255, 110)
		end
	end
	for _ = 1, many and 5 or 2 do
		local p = em:Add(SMOKE, pos + VectorRand() * 8)
		if p then
			p:SetVelocity(Vector(0, 0, math.Rand(20, 50)) + VectorRand() * 10)
			p:SetDieTime(math.Rand(1, 1.8))
			p:SetStartAlpha(90)
			p:SetEndAlpha(0)
			p:SetStartSize(8)
			p:SetEndSize(30)
			p:SetRoll(math.Rand(0, 360))
			p:SetColor(140, 230, 110)
		end
	end
	em:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
