-- A happy pet worm: a few little hearts float up from it
local HEART = Material("rmpg/fx_heart")

function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local em = ParticleEmitter(pos, false)
	if em then
		for _ = 1, 6 do
			local p = em:Add(HEART, pos + VectorRand() * 8)
			if p then
				p:SetVelocity(Vector(math.Rand(-14, 14), math.Rand(-14, 14), math.Rand(30, 60)))
				p:SetGravity(Vector(0, 0, 12))
				p:SetDieTime(math.Rand(0.9, 1.5))
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(math.Rand(3, 5))
				p:SetEndSize(1.5)
				p:SetRoll(math.Rand(-0.4, 0.4))
			end
		end
		em:Finish()
	end
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
