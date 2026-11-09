-- A normal shot of the Akira laser (RMPG.ArmShot in rmpg/sv_implants.lua): a thick yellow bolt from the open hand to
-- where it hit, a flash and yellow sparks there and a small short light
local SPARK = Material("effects/spark")
local LIFE = 0.16

function EFFECT:Init(data)
	local ply = data:GetEntity()
	self.Ply = IsValid(ply) and ply or nil
	self.Stop = data:GetOrigin()
	self.Normal = data:GetNormal()
	self.Start = (self.Ply and RMPG.ArmStart) and RMPG.ArmStart(self.Ply) or data:GetStart()
	self.Die = UnPredictedCurTime() + LIFE
	self:SetRenderBoundsWS(self.Start, self.Stop, Vector(64, 64, 64))
	local em = ParticleEmitter(self.Stop, false)
	if em then
		for _ = 1, RMPG.CL.particles:GetBool() and 16 or 6 do
			local p = em:Add(SPARK, self.Stop)
			if p then
				p:SetVelocity((self.Normal + VectorRand() * 0.8):GetNormalized() * math.Rand(90, 260))
				p:SetGravity(Vector(0, 0, -500))
				p:SetCollide(true)
				p:SetBounce(0.3)
				p:SetDieTime(math.Rand(0.25, 0.55))
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(1.8)
				p:SetEndSize(0)
				p:SetStartLength(7)
				p:SetEndLength(1)
				p:SetColor(255, 214, 90)
			end
		end
		em:Finish()
	end
	if RMPG.LightBudget(2) then
		local dl = DynamicLight(IsValid(ply) and ply:EntIndex() + 6000 or math.random(24000, 28000))
		if dl then
			dl.pos = self.Stop + self.Normal * 6
			dl.r, dl.g, dl.b = 255, 200, 70
			dl.brightness = 1.2
			dl.size = 90
			dl.decay = 800
			dl.dietime = CurTime() + 0.12
		end
	end
end

function EFFECT:Think()
	return UnPredictedCurTime() < self.Die
end

function EFFECT:Render()
	-- the hand moves with the view, which is known for certain only here
	if self.Ply and RMPG.ArmStart then self.Start = RMPG.ArmStart(self.Ply) end
	local k = math.Clamp((self.Die - UnPredictedCurTime()) / LIFE, 0, 1)
	local M = RMPG.Mat
	render.SetMaterial(M.beam)
	render.DrawBeam(self.Start, self.Stop, 4 + 14 * k, 0, 1, Color(255, 196, 50, 255 * k))
	render.DrawBeam(self.Start, self.Stop, 2 + 5 * k, 0, 1, Color(255, 250, 225, 255 * k))
	render.SetMaterial(M.glow)
	render.DrawSprite(self.Start, 34 * k + 8, 34 * k + 8, Color(255, 230, 140, 255 * k))
	render.DrawSprite(self.Stop, 56 * k + 10, 56 * k + 10, Color(255, 210, 90, 255 * k))
end
