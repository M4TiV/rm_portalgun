AddCSLuaFile()

-- Rick Prime's bomb. E links it to your detonator (the lenses light up), the detonator's LMB starts a
-- three second countdown: blinking and beeping, then it pulls in what is close, disintegrates everything
-- within ~2.75 m and throws the rest back with a violet flash.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.bomb"
ENT.Author = "Rick Prime"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "entities/rmpg_prime_bomb.png"

local MODEL = "models/rmpg/prime_bomb.mdl"
local SCALE = 1.2               -- model units -> world units
local RADIUS = 14               -- physics sphere
local AFTER = 2.2               -- the blast is drawn this long before the entity goes away
local UP = Vector(0, 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Linker")
	self:NetworkVar("Bool", 0, "Armed")
	self:NetworkVar("Bool", 1, "Exploded")
	self:NetworkVar("Float", 0, "FuseStart")
	self:NetworkVar("Float", 1, "BlastTime") -- 0 = not triggered
end

function ENT:IsLinked()
	return self:GetArmed() and IsValid(self:GetLinker())
end

-- 0 = off, 1 = linked, 2 = counting down, 3 = exploded; plus the fraction of the countdown
function ENT:State()
	if self:GetExploded() then return 3, 1 end
	local bt = self:GetBlastTime()
	if bt > 0 then
		local s = self:GetFuseStart()
		return 2, math.Clamp((CurTime() - s) / math.max(bt - s, 0.01), 0, 1)
	end
	return self:IsLinked() and 1 or 0, 0
end

function ENT:Radii()
	local U = RMPG.UNITS_PER_METER
	local kill = RMPG.CV.bombKill:GetFloat() * U
	return kill, RMPG.CV.bombPull:GetFloat() * U, math.max(RMPG.CV.bombBlast:GetFloat() * U, kill)
end

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * (RADIUS + 2))
		e:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
		e:Spawn()
		e:Activate()
		return e
	end

	function ENT:Initialize()
		if util.IsValidModel(MODEL) then
			self:SetModel(MODEL)
			self:PhysicsInit(SOLID_VPHYSICS)
		else
			self:SetModel("models/combine_helicopter/helicopter_bomb01.mdl")
			self:PhysicsInitSphere(RADIUS, "metal")
			self:SetCollisionBounds(Vector(-RADIUS, -RADIUS, -RADIUS), Vector(RADIUS, RADIUS, RADIUS))
		end
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)
		local po = self:GetPhysicsObject()
		if IsValid(po) then
			po:SetMass(60)
			po:Wake()
		end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	-- E: link to your detonator, or switch a linked bomb off
	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() or self:GetBlastTime() > 0 then return end
		if self:IsLinked() then
			self:SetArmed(false)
			self:SetLinker(NULL)
			self:EmitSound(RMPG.SND.bombDisarm, 70)
			RMPG.Notify(ply, "n_bomb_disarmed", nil, 0)
			return
		end
		self:SetArmed(true)
		self:SetLinker(ply)
		self:EmitSound(RMPG.SND.bombArm, 75)
		self.NextIdle = CurTime() + 1.5
		if IsValid(ply:GetWeapon(RMPG.DETONATOR)) then
			RMPG.Notify(ply, "n_bomb_linked", { RMPG.CV.bombTimer:GetFloat() }, 2)
		else
			RMPG.Notify(ply, "n_bomb_linked_nodet", nil, 2)
		end
	end

	function ENT:Trigger(fuse)
		if self:GetBlastTime() > 0 or self:GetExploded() then return end
		local now = CurTime()
		fuse = fuse or RMPG.CV.bombTimer:GetFloat()
		self:SetFuseStart(now)
		self:SetBlastTime(now + fuse)
		self.NextBlip = now
		self:EmitSound(RMPG.SND.bombSiren, 95)
		util.ScreenShake(self:GetPos(), 1.5, 20, fuse, 600)
	end

	-- Stopped in time (the eyepatch can do that from afar)
	function ENT:Defuse(ply)
		self:SetBlastTime(0)
		self:SetFuseStart(0)
		self.PullSnd, self.PreSnd = nil, nil
		self:StopSound(RMPG.SND.bombSiren)
		self:StopSound(RMPG.SND.sdSuck)
		self:StopSound(RMPG.SND.bombPre)
		self:EmitSound(RMPG.SND.bombDisarm, 75)
		RMPG.Notify(ply, "n_nb_defused", nil, 0)
	end

	-- A nearby blast sets it off too
	function ENT:OnTakeDamage(dmg)
		if dmg:IsDamageType(DMG_BLAST) and dmg:GetDamage() > 30 then self:Trigger(0.4) end
	end

	function ENT:Think()
		local now = CurTime()
		if self:GetExploded() then return end
		local bt = self:GetBlastTime()
		if bt <= 0 then
			-- a linked bomb chirps now and then
			if self:IsLinked() and now >= (self.NextIdle or 0) then
				self.NextIdle = now + 2.5
				self:EmitSound(RMPG.SND.bombBlip, 55, 80)
			end
			self:NextThink(now + 0.2)
			return true
		end

		local _, frac = self:State()
		if now >= self.NextBlip then
			self:EmitSound(RMPG.SND.bombBlip, 85, 95 + frac * 90)
			self.NextBlip = now + math.max(0.055, 0.42 * (1 - frac) ^ 1.6)
		end
		if not self.PullSnd and frac > 0.3 then
			self.PullSnd = true
			self:EmitSound(RMPG.SND.sdSuck, 90, 125)
		end
		if not self.PreSnd and bt - now < 0.9 then
			self.PreSnd = true
			self:EmitSound(RMPG.SND.bombPre, 95)
		end
		if frac > 0.3 then
			local _, pullR = self:Radii()
			RMPG.BombPull(self, self:WorldSpaceCenter(), pullR, (frac - 0.3) / 0.7)
		end
		if now >= bt then
			self:Explode()
			return
		end
		self:NextThink(now)
		return true
	end

	function ENT:Explode()
		if self:GetExploded() then return end
		self:SetExploded(true)
		local center = self:WorldSpaceCenter()
		local killR, _, blastR = self:Radii()
		local linker = self:GetLinker()
		self:StopSound(RMPG.SND.bombSiren)
		self:StopSound(RMPG.SND.sdSuck)
		self:EmitSound(RMPG.SND.bombBoom, 140)
		self:EmitSound(RMPG.SND.bombBass, 140, 80)
		util.ScreenShake(center, 20, 80, 1.5, blastR * 2.5)
		local po = self:GetPhysicsObject()
		if IsValid(po) then po:EnableMotion(false) end
		self:SetNotSolid(true)
		RMPG.BombBlast(self, center, killR, blastR, IsValid(linker) and linker or self)
		SafeRemoveEntityDelayed(self, AFTER)
	end

	function ENT:OnRemove()
		self:StopSound(RMPG.SND.bombSiren)
		self:StopSound(RMPG.SND.sdSuck)
	end

	return
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------

local LENS_OFF = Vector(0.36, 0.07, 0.11)
local LENS_DIM = Vector(0.62, 0.12, 0.2)
local LENS_ON = Vector(1, 0.3, 0.52)
local LIT_ON = 0.5   -- above this the lenses count as lit: skin 1 and the glow dots
local PINK = Color(255, 70, 130)
local VIOLET = Color(190, 110, 255)

function ENT:Initialize()
	self.Seed = math.random(1000)
	self.NextP = 0
	self:SetRenderBounds(Vector(-40, -40, -40), Vector(40, 40, 40))
end

-- How lit the lenses are right now (0..1): a slow breath when linked, a blink that speeds up while counting down
function ENT:Lit()
	local state, frac = self:State()
	if state == 0 then return 0 end
	if state == 1 then return 0.3 + 0.25 * math.sin(CurTime() * 3) end
	if state == 3 then return 1 end
	local T = self:GetBlastTime() - self:GetFuseStart()
	local t = frac * T
	-- the blink frequency climbs from 2 to 16 Hz; phase is its integral
	local phase = 2 * t + 14 * T * frac ^ 3 / 3
	return (phase % 1) < 0.5 and 1 or 0.15
end

function ENT:Frame()
	return RMPG.Model.FrameFromAngle(self:GetPos(), self:GetAngles(), SCALE)
end

function ENT:Draw()
	if self:GetExploded() then return end
	if self:GetModel() == MODEL then
		-- models/rmpg/prime_bomb.mdl: skin 0 dark lenses, skin 1 lit
		self:SetSkin(self:Lit() > LIT_ON and 1 or 0)
		self:DrawModel()
		return
	end
	if not RMPG.Model then return end
	local lit = self:Lit()
	local lens = self:State() == 0 and LENS_OFF or LerpVector(lit, LENS_DIM, LENS_ON)
	local l = render.GetLightColor(self:GetPos())
	RMPG.Model.DrawBomb(self:Frame(), {
		lens = lens,
		light = math.Clamp(math.max(l.x, l.y, l.z) * 1.8 + 0.25, 0.35, 1),
		outline = RMPG.CL.outline:GetBool(),
	})
	RMPG.ResetTints()
end

-- Jagged electric arc between two points
local function Arc(a, b, width, col, segs, jitter)
	local prev = a
	for i = 1, segs do
		local f = i / segs
		local p = LerpVector(f, a, b)
		if i < segs then p = p + VectorRand() * jitter * math.sin(f * math.pi) end
		render.DrawBeam(prev, p, width, 0, 1, col)
		prev = p
	end
end

function ENT:GroundPos(center)
	local tr = util.TraceLine({ start = center, endpos = center - UP * 400, mask = MASK_SOLID_BRUSHONLY })
	return tr.HitPos + UP * 1.5
end

function ENT:DrawTranslucent()
	local state, frac = self:State()
	local M = RMPG.Mat
	local center = self:WorldSpaceCenter()
	local now = CurTime()

	if state == 3 then
		self:DrawBlast(center, now - self:GetBlastTime())
		return
	end
	if state == 0 then return end

	-- glowing lenses facing the camera, only while the lenses are lit (dark lenses get no dots)
	local lit = self:Lit()
	render.SetMaterial(M.glow)
	if lit > LIT_ON then
		local fr = self:Frame()
		local eye = EyePos()
		local sz = (state == 2 and 9 or 6) * (0.4 + 0.6 * lit)
		for i = 1, #RMPG.Model.BOMB_SOCKETS do
			local p = RMPG.Model.BombLens(fr, i)
			if (p - center):Dot(eye - p) > 0 then
				render.DrawSprite(p, sz, sz, Color(PINK.r, PINK.g, PINK.b, 200 * lit))
			end
		end
	end
	if state ~= 2 then return end

	-- countdown: the aura swells, violet crackle at the end; the ground just catches the bomb's blinking light.
	-- The aura and the ground glow are its light, so they go dark together with the lenses
	local killR, pullR = self:Radii()
	local on = lit > LIT_ON and lit or 0
	local aura = 40 + 60 * frac
	render.DrawSprite(center, aura * 2, aura * 2, Color(PINK.r, PINK.g, PINK.b, (60 + 120 * frac) * on))
	render.DrawSprite(center, aura, aura, Color(255, 220, 255, 90 * frac * on))
	local ground = self:GroundPos(center)
	local fade = math.Clamp(1 - (center.z - ground.z) / 300, 0, 1)
	local glow = (0.35 + 0.65 * frac) * fade
	RMPG.DrawGlowDisc(ground, UP, math.max(pullR, killR) * 1.5, VIOLET.r, VIOLET.g, VIOLET.b, 36 * on * glow)
	RMPG.DrawGlowDisc(ground, UP, killR * 1.4, PINK.r, PINK.g, PINK.b, 68 * on * glow)
	if frac > 0.6 then
		render.SetMaterial(M.beam)
		for _ = 1, math.floor(1 + (frac - 0.6) * 10) do
			Arc(center, center + VectorRand():GetNormalized() * (RADIUS + 10 + 30 * frac), 2, VIOLET, 5, 5)
		end
	end
end

local function EaseOut(x) x = math.Clamp(x, 0, 1) return 1 - (1 - x) ^ 3 end

-- The violet-white flash with light rays (file 04), a shock ring on the ground and a fading glow
function ENT:DrawBlast(center, te)
	local M = RMPG.Mat
	local killR, _, blastR = self:Radii()
	local grow = EaseOut(te / 0.25)
	local fade = math.Clamp(1 - (te - 0.15) / 1.5, 0, 1)
	if fade <= 0 then return end
	render.SetMaterial(M.glow)
	render.DrawSprite(center, blastR * 3 * grow, blastR * 3 * grow, Color(VIOLET.r, VIOLET.g, VIOLET.b, 255 * fade))
	render.DrawSprite(center, blastR * 1.6 * grow, blastR * 1.6 * grow, Color(255, 170, 230, 255 * fade))
	render.DrawSprite(center, blastR * 0.7, blastR * 0.7, Color(255, 255, 255, 255 * fade ^ 0.6))

	-- light rays bursting out of the centre
	render.SetMaterial(M.beam)
	for i = 1, 40 do
		local a = util.SharedRandom("rmpg_bomb_ray", 0, math.pi * 2, self.Seed + i)
		local z = util.SharedRandom("rmpg_bomb_rayz", -0.25, 0.9, self.Seed + i)
		local dir = Vector(math.cos(a), math.sin(a), z):GetNormalized()
		local len = blastR * util.SharedRandom("rmpg_bomb_rayl", 0.6, 1.5, self.Seed + i) * EaseOut(te / 0.35)
		local w = util.SharedRandom("rmpg_bomb_rayw", 14, 46, self.Seed + i) * fade
		local col = (i % 3 == 0) and Color(255, 255, 255, 230 * fade) or ((i % 3 == 1) and Color(255, 120, 210, 255 * fade) or Color(VIOLET.r, VIOLET.g, VIOLET.b, 255 * fade))
		render.DrawBeam(center, center + dir * len, w, 0, 1, col)
	end

	local ground = self:GroundPos(center)
	local ring = EaseOut(te / 0.7)
	local rf = math.Clamp(1 - te / 0.9, 0, 1)
	RMPG.DrawGlowDisc(ground, UP, blastR * ring * 1.3, 150, 80, 220, 170 * rf)
	RMPG.DrawGlowDisc(ground, UP, killR * 1.6 * EaseOut(te / 0.2), 255, 220, 255, 200 * rf)
	RMPG.DrawRing(ground, UP, blastR * ring, VIOLET.r, VIOLET.g, VIOLET.b, 90 * rf)
	local _, ax, ay = RMPG.PortalAxes((EyePos() - center):Angle())
	render.SetMaterial(M.ring)
	local rs = blastR * (0.2 + 1.1 * ring)
	RMPG.DrawQuad(center, ax, ay, rs, rs, 0, 0, 1, 1, PINK.r, PINK.g, PINK.b, 220 * rf)
	RMPG.DrawQuad(center, ax, ay, rs * 0.6, rs * 0.6, 0, 0, 1, 1, 255, 255, 255, 160 * rf)
end

function ENT:Think()
	local state, frac = self:State()
	local center = self:WorldSpaceCenter()
	local _, pullR, blastR = self:Radii()
	if state == 3 then
		local bb = Vector(blastR * 1.6, blastR * 1.6, blastR * 1.6)
		self:SetRenderBounds(-bb, bb)
	elseif state == 2 then
		local bb = Vector(pullR + 40, pullR + 40, 60)
		self:SetRenderBounds(-bb, bb)
	end

	if state >= 1 then
		local dl = DynamicLight(self:EntIndex())
		if dl then
			local lit = self:Lit()
			dl.pos = center
			if state == 3 then
				local fade = math.Clamp(1 - (CurTime() - self:GetBlastTime()) / 1.6, 0, 1)
				dl.r, dl.g, dl.b = VIOLET.r, VIOLET.g, VIOLET.b
				dl.brightness = 9 * fade
				dl.size = blastR * 2.5
			elseif lit > LIT_ON then
				dl.r, dl.g, dl.b = PINK.r, PINK.g, PINK.b
				dl.brightness = (state == 2 and 2.5 or 0.6) * lit
				dl.size = state == 2 and 220 + 200 * frac or 90
			else
				-- dark lenses cast no light: put the light out at once instead of letting it fade
				dl.brightness = 0
				dl.size = 0
			end
			dl.decay = 2000
			dl.dietime = CurTime() + 0.15
		end
	end

	if state == 3 and not self.Flashed then
		self.Flashed = true
		local d = EyePos():Distance(center)
		local k = math.Clamp(1.35 - d / (blastR * 2.4), 0, 1)
		if k > 0 then
			local tr = util.TraceLine({ start = EyePos(), endpos = center, mask = MASK_SOLID_BRUSHONLY })
			if tr.Hit then k = k * 0.35 end
			RMPG.BombFlash(center, k)
		end
		self:Burst(center, blastR)
	end

	if not RMPG.CL.particles:GetBool() or state ~= 2 or frac < 0.3 or CurTime() < self.NextP then return end
	-- dust and sparks streaking into the bomb while it pulls
	self.NextP = CurTime() + 0.03
	self.Emitter = self.Emitter or ParticleEmitter(center, false)
	if not self.Emitter then return end
	for _ = 1, 3 do
		local dir = VectorRand()
		dir.z = math.abs(dir.z) * 0.4
		dir:Normalize()
		local p0 = center + dir * (pullR * math.Rand(0.5, 1))
		local pt = self.Emitter:Add(RMPG.Mat.spark, p0)
		if pt then
			pt:SetVelocity((center - p0) * 2.2)
			pt:SetDieTime(0.45)
			pt:SetStartAlpha(0)
			pt:SetEndAlpha(255)
			pt:SetStartSize(math.Rand(2, 5))
			pt:SetEndSize(0.5)
			pt:SetColor(VIOLET.r, VIOLET.g, VIOLET.b)
			pt:SetStartLength(20)
			pt:SetEndLength(4)
		end
	end
end

-- Sparks thrown out by the blast
function ENT:Burst(pos, R)
	if not RMPG.CL.particles:GetBool() then return end
	local em = ParticleEmitter(pos, false)
	if not em then return end
	for i = 1, 110 do
		local p = em:Add(RMPG.Mat.spark, pos)
		if p then
			local dir = VectorRand():GetNormalized()
			dir.z = math.abs(dir.z) * 0.7 + 0.05
			p:SetVelocity(dir * math.Rand(R * 0.9, R * 2.6))
			p:SetDieTime(math.Rand(0.5, 1.3))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(4, 10))
			p:SetEndSize(0)
			local c = (i % 3 == 0) and color_white or ((i % 3 == 1) and PINK or VIOLET)
			p:SetColor(c.r, c.g, c.b)
			p:SetAirResistance(90)
			p:SetStartLength(50)
			p:SetEndLength(5)
		end
	end
	em:Finish()
end

function ENT:OnRemove()
	if self.Emitter then self.Emitter:Finish() self.Emitter = nil end
end

killicon.AddAlias("rmpg_prime_bomb", "prop_combine_ball")
