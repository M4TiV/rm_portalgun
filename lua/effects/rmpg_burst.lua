-- Burst of coloured sparks where something comes out of a portal (or a shot lands)
function EFFECT:Init(data)
	local pos = data:GetOrigin()
	local n = data:GetNormal()
	local col = data:GetStart()
	if col.x + col.y + col.z < 1 then col = RMPG.DEFAULT_COLOR end
	local scale = math.max(data:GetScale(), 0.3)

	local dl = DynamicLight(math.random(8192, 16384))
	if dl then
		dl.pos = pos + n * 8
		dl.r, dl.g, dl.b = col.x, col.y, col.z
		dl.brightness = 3
		dl.decay = 1200
		dl.size = 220 * scale
		dl.dietime = CurTime() + 0.4
	end

	if not RMPG.CL.particles:GetBool() then return end
	local em = ParticleEmitter(pos, false)
	if not em then return end
	for _ = 1, math.floor(28 * scale) do
		local p = em:Add(RMPG.Mat.spark, pos)
		if p then
			local v = (n * math.Rand(0.3, 1.2) + VectorRand() * 0.8):GetNormalized() * math.Rand(80, 280) * scale
			p:SetVelocity(v)
			p:SetDieTime(math.Rand(0.35, 0.8))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(2, 5) * scale)
			p:SetEndSize(0)
			p:SetColor(math.min(255, col.x + 50), math.min(255, col.y + 50), math.min(255, col.z + 50))
			p:SetAirResistance(120)
			p:SetGravity(Vector(0, 0, -150))
			p:SetStartLength(14 * scale)
			p:SetEndLength(2)
		end
	end
	local glow = em:Add(RMPG.Mat.glow, pos + n * 4)
	if glow then
		glow:SetDieTime(0.35)
		glow:SetStartAlpha(220)
		glow:SetEndAlpha(0)
		glow:SetStartSize(40 * scale)
		glow:SetEndSize(90 * scale)
		glow:SetColor(col.x, col.y, col.z)
	end
	em:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
