-- The Phoenix tank breaks: glass shards fly out of the whole tube and the green fluid splashes over the floor
local UP = Vector(0, 0, 1)
local SHARDS = { Material("effects/fleck_glass1"), Material("effects/fleck_glass2"), Material("effects/fleck_glass3") }
local DROP = Material("effects/splash2")
local MIST = Material("rmpg/fx_smoke")

function EFFECT:Init(data)
	local center = data:GetOrigin()
	local tank = data:GetEntity()
	local r = math.max(data:GetRadius(), 20)
	local base = IsValid(tank) and tank:GetPos() or center - UP * 50
	local em = ParticleEmitter(center, false)
	if not em then return end
	local many = RMPG.CL.particles:GetBool()
	-- glass from all over the tube
	for _ = 1, many and 160 or 70 do
		local a = math.Rand(0, math.pi * 2)
		local dir = Vector(math.cos(a), math.sin(a), 0)
		local pos = base + dir * r + UP * math.Rand(10, 115)
		local p = em:Add(SHARDS[math.random(#SHARDS)], pos)
		if p then
			p:SetVelocity(dir * math.Rand(80, 260) + UP * math.Rand(-20, 120))
			p:SetGravity(Vector(0, 0, -600))
			p:SetCollide(true)
			p:SetBounce(0.3)
			p:SetAirResistance(8)
			p:SetDieTime(math.Rand(1.5, 3))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(1.5, 4))
			p:SetEndSize(1)
			p:SetRoll(math.Rand(0, 360))
			p:SetRollDelta(math.Rand(-10, 10))
			p:SetColor(210, 255, 235)
		end
	end
	-- the fluid gushes out and runs over the floor
	for _ = 1, many and 90 or 40 do
		local a = math.Rand(0, math.pi * 2)
		local dir = Vector(math.cos(a), math.sin(a), 0)
		local p = em:Add(DROP, base + dir * r * 0.8 + UP * math.Rand(10, 90))
		if p then
			p:SetVelocity(dir * math.Rand(60, 220) + UP * math.Rand(0, 80))
			p:SetGravity(Vector(0, 0, -500))
			p:SetCollide(true)
			p:SetBounce(0.1)
			p:SetDieTime(math.Rand(0.8, 1.6))
			p:SetStartAlpha(200)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(4, 9))
			p:SetEndSize(math.Rand(10, 18))
			p:SetRoll(math.Rand(0, 360))
			p:SetColor(80, 230, 140)
		end
	end
	for _ = 1, 12 do
		local p = em:Add(MIST, base + VectorRand() * r * 0.6 + UP * 20)
		if p then
			p:SetVelocity(VectorRand() * 40 + UP * 20)
			p:SetDieTime(math.Rand(1.5, 2.5))
			p:SetStartAlpha(70)
			p:SetEndAlpha(0)
			p:SetStartSize(20)
			p:SetEndSize(60)
			p:SetColor(120, 240, 170)
			p:SetRoll(math.Rand(0, 360))
		end
	end
	em:Finish()
end

function EFFECT:Think() return false end
function EFFECT:Render() end
