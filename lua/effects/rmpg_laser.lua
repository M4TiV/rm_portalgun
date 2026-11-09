-- A shot of Rick's laser gun: a bright red bolt that streaks from the gun's cup to where it hits, a glowing core
-- along the way, and sparks with a small glow where it lands. A charged shot (Magnitude above 0) is a solid beam that fades.
local SPARK = Material("effects/spark")
local RED = Color(255, 50, 30)
local LIFE = 0.14
-- The clock of the shot. Not CurTime(): the shooter's own shot is made while the client predicts, where CurTime() runs
-- ahead by the ping. The shot then started "in the future": the bolt was drawn backwards out of the gun (towards the
-- camera) and lived longer, so several of them hung in a fan.
local Now = UnPredictedCurTime

function EFFECT:Init(data)
	local wep = data:GetEntity()
	local big = data:GetMagnitude() -- 0 for a normal shot, up to 1 for a full charge
	self.Big = big
	self.Life = LIFE + 0.45 * big
	self.Stop = data:GetOrigin()
	self.Wep = IsValid(wep) and wep.MuzzlePos and wep or nil
	self.Start = self.Wep and self.Wep:MuzzlePos() or data:GetStart()
	self.Normal = data:GetNormal()
	self.Die = Now() + self.Life
	self.Len = self.Start:Distance(self.Stop)
	self:SetRenderBoundsWS(self.Start, self.Stop, Vector(128, 128, 128))
	-- sparks where it hits
	local em = ParticleEmitter(self.Stop, false)
	if em then
		for _ = 1, 10 + math.floor(30 * big) do
			local p = em:Add(SPARK, self.Stop)
			if p then
				p:SetVelocity((self.Normal + VectorRand() * 0.8):GetNormalized() * math.Rand(80, 220))
				p:SetGravity(Vector(0, 0, -500))
				p:SetCollide(true)
				p:SetBounce(0.3)
				p:SetDieTime(math.Rand(0.25, 0.5))
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(1.5)
				p:SetEndSize(0)
				p:SetStartLength(6)
				p:SetEndLength(1)
				p:SetColor(255, 140, 90)
			end
		end
		local g = em:Add(RMPG.Mat.glow, self.Stop + self.Normal * 2)
		if g then
			g:SetDieTime(0.25)
			g:SetStartAlpha(255)
			g:SetEndAlpha(0)
			g:SetStartSize(14 + 40 * big)
			g:SetEndSize(4)
			g:SetColor(RED.r, RED.g, RED.b)
		end
		em:Finish()
	end
	-- a small, short light where it lands: a big bright one turned whole walls white
	if RMPG.LightBudget(2) then
		local dl = DynamicLight(IsValid(wep) and wep:EntIndex() + 4000 or math.random(20000, 24000))
		if dl then
			dl.pos = self.Stop + self.Normal * 4
			dl.r, dl.g, dl.b = RED.r, RED.g, RED.b
			dl.brightness = 0.7 + 0.5 * big
			dl.size = 40 + 50 * big
			dl.decay = 700
			dl.dietime = CurTime() + 0.08 + 0.08 * big
		end
	end
end

function EFFECT:Think()
	return Now() < self.Die
end

function EFFECT:Render()
	-- where the cup is now: only here is the view known for certain, and the gun moves with the view
	if IsValid(self.Wep) then
		self.Start = self.Wep:MuzzlePos()
		self.Len = self.Start:Distance(self.Stop)
	end
	local k = math.Clamp(1 - (self.Die - Now()) / self.Life, 0, 1) -- 0 -> 1 over the life of the shot
	if self.Big > 0 then
		local f = 1 - k
		local w = (6 + 22 * self.Big) * (0.4 + 0.6 * f)
		render.SetMaterial(RMPG.Mat.beam)
		render.DrawBeam(self.Start, self.Stop, w, 0, self.Len / 96, Color(RED.r, RED.g, RED.b, 255 * f))
		render.DrawBeam(self.Start, self.Stop, w * 0.35, 0, 1, Color(255, 235, 225, 255 * f))
		render.SetMaterial(RMPG.Mat.glow)
		render.DrawSprite(self.Stop, w * 3, w * 3, Color(255, 120, 90, 255 * f))
		return
	end
	local dir = (self.Stop - self.Start):GetNormalized()
	-- the bolt: it shoots out of the cup, stays joined to it for a moment and then runs out along the line
	local head = math.min(k * 3, 1)
	local tail = math.max((k - 0.4) / 0.6, 0)
	local a = self.Start + dir * (self.Len * tail)
	local b = self.Start + dir * (self.Len * head)
	render.SetMaterial(RMPG.Mat.beam)
	render.DrawBeam(a, b, 6, 0, 1, Color(RED.r, RED.g, RED.b, 220 * (1 - k * 0.5)))
	render.DrawBeam(a, b, 2, 0, 1, Color(255, 230, 220, 255 * (1 - k * 0.5)))
	render.SetMaterial(RMPG.Mat.glow)
	render.DrawSprite(b, 10, 10, Color(255, 120, 90, 255 * (1 - k)))
end
