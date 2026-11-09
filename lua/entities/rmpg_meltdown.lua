AddCSLuaFile()

-- Portal gun self-destruct: charge-up flash above the gun, then a singularity that pulls in and vaporises everything
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg_meltdown"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local CHARGE = 3.2
local IMPLODE = 1.5
local UP = Vector(0, 0, 1)

local function VortexTime(core) return core and 7.5 or 5.5 end

function ENT:SetupDataTables()
	self:NetworkVar("Vector", 0, "FluidColor")
	self:NetworkVar("Vector", 1, "VortexPos")
	self:NetworkVar("Bool", 0, "Core")
	self:NetworkVar("Float", 0, "StartTime")
	self:NetworkVar("Float", 1, "Radius")
	self:NetworkVar("Float", 2, "GroundZ")
	self:NetworkVar("Entity", 0, "Instigator")
	self:NetworkVar("Int", 0, "Variant")
	self:NetworkVar("Vector", 2, "BodyColor")
end

-- 1 = charging, 2 = vortex, 3 = implosion; returns phase, fraction of the phase, time since start
function ENT:Phase()
	local t = CurTime() - self:GetStartTime()
	local vt = VortexTime(self:GetCore())
	if t < CHARGE then return 1, t / CHARGE, t end
	if t < CHARGE + vt then return 2, (t - CHARGE) / vt, t end
	return 3, math.Clamp((t - CHARGE - vt) / IMPLODE, 0, 1), t
end

function ENT:FluidCol()
	local c = self:GetFluidColor()
	if c.x + c.y + c.z < 1 then return RMPG.DEFAULT_COLOR end
	return c
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/plates/plate1x1.mdl")
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetNotSolid(true)
		self:DrawShadow(false)
		self:SetStartTime(CurTime())
		local meters = self:GetCore() and RMPG.CV.sdCore:GetFloat() or RMPG.CV.sdRadius:GetFloat()
		self:SetRadius(meters * RMPG.UNITS_PER_METER)
		local pos = self:GetPos()
		local up = util.TraceLine({ start = pos, endpos = pos + UP * 90, mask = MASK_SOLID_BRUSHONLY })
		self:SetVortexPos(pos + UP * math.max(20, up.Fraction * 90 - 18))
		local down = util.TraceLine({ start = pos, endpos = pos - UP * 2000, mask = MASK_SOLID_BRUSHONLY })
		self:SetGroundZ(down.HitPos.z)
		self:EmitSound(RMPG.SND.sdCharge, 95)
		self.NextBeep = CurTime()
		util.ScreenShake(pos, 2, 30, CHARGE, self:GetRadius() * 2)
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:Pullable(e)
		if not IsValid(e) or e == self or e:IsWorld() or e.RMPG_Vaporized then return false end
		local c = e:GetClass()
		if c == "rmpg_portal" or c == "rmpg_meltdown" then return false end
		if IsValid(e:GetParent()) then return false end
		if e:IsPlayer() then
			if not e:Alive() or e:InVehicle() or e:HasGodMode() then return false end
			if e == self:GetInstigator() and not RMPG.CV.sdOwner:GetBool() then return false end
			return true
		end
		if e:IsNPC() or e:IsNextBot() then return e:Health() > 0 end
		if e:IsWeapon() and IsValid(e:GetOwner()) then return false end
		if e:IsVehicle() then return false end
		if e:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
		return IsValid(e:GetPhysicsObject())
	end

	function ENT:Pull(frac)
		local center = self:GetVortexPos()
		local R = self:GetRadius()
		local strength = self:GetCore() and 1.8 or 1
		local ramp = math.Clamp(frac * 4, 0, 1)
		local killR = self:GetCore() and 60 or 42
		local dt = FrameTime()
		local inst = self:GetInstigator()
		for _, e in ipairs(ents.FindInSphere(center, R)) do
			if self:Pullable(e) then
				local d = center - e:WorldSpaceCenter()
				local dist = d:Length()
				if dist - math.min(e:BoundingRadius(), 60) < killR then
					RMPG.Vaporize(e, inst, self, center)
				else
					local dir = d / dist
					local k = 1 - dist / R
					local swirl = dir:Cross(UP) * 0.35
					local accel = (500 + 2600 * k * k) * strength * ramp
					if e:IsPlayer() then
						if e:GetVelocity():Dot(dir) < 900 then
							local add = (dir + swirl) * (accel * dt)
							if e:IsOnGround() then add.z = add.z + 120 end
							e:SetVelocity(add)
						end
					elseif e:IsNPC() or e:IsNextBot() then
						local step = (120 + 700 * k) * strength * ramp * dt
						e:SetPos(e:GetPos() + dir * math.min(step, dist))
					else
						for i = 0, e:GetPhysicsObjectCount() - 1 do
							local po = e:GetPhysicsObjectNum(i)
							if IsValid(po) and po:GetVelocity():Length() < 1600 then
								if not po:IsMotionEnabled() then po:EnableMotion(true) end
								po:Wake()
								local mass = po:GetMass()
								local pdir = (center - po:GetPos()):GetNormalized()
								po:ApplyForceCenter((pdir + swirl) * (accel * mass * dt) + UP * (600 * mass * dt))
							end
						end
					end
				end
			end
		end
	end

	function ENT:Implode()
		local center = self:GetVortexPos()
		local R = self:GetRadius()
		local inst = self:GetInstigator()
		local power = self:GetCore() and 1.8 or 1
		self:EmitSound(RMPG.SND.sdImplode, 120)
		self:EmitSound(RMPG.SND.sdBoom, 110)
		util.ScreenShake(center, 16, 60, 1.6, R * 4)
		for _, e in ipairs(ents.FindInSphere(center, R)) do
			if self:Pullable(e) then
				local c = e:WorldSpaceCenter()
				local dist = c:Distance(center)
				if dist < R * 0.45 then
					RMPG.Vaporize(e, inst, self, center)
				else
					local dir = (c - center):GetNormalized()
					local push = (1 - dist / R) * 900 * power
					if e:IsPlayer() then
						e:SetVelocity(dir * push + UP * 200)
					elseif not (e:IsNPC() or e:IsNextBot()) then
						local po = e:GetPhysicsObject()
						if IsValid(po) then po:ApplyForceCenter((dir * push + UP * 200) * po:GetMass()) end
					end
				end
			end
		end
	end

	function ENT:Think()
		local phase, frac = self:Phase()
		local now = CurTime()
		if phase == 1 then
			if now >= self.NextBeep then
				self:EmitSound(RMPG.SND.beep, 85, 90 + frac * 70)
				self.NextBeep = now + math.max(0.07, 0.45 - frac * 0.4)
			end
		elseif phase == 2 then
			if not self.VortexOn then
				self.VortexOn = true
				self:EmitSound(RMPG.SND.sdSuck, 100)
				self:EmitSound(RMPG.SND.sdLoop, 95)
				util.ScreenShake(self:GetVortexPos(), 6, 40, VortexTime(self:GetCore()), self:GetRadius() * 2.5)
			end
			self:Pull(frac)
		elseif not self.Imploded then
			self.Imploded = true
			self:StopSound(RMPG.SND.sdLoop)
			self:Implode()
			SafeRemoveEntityDelayed(self, IMPLODE + 0.5)
		end
		self:NextThink(now)
		return true
	end

	function ENT:OnRemove()
		self:StopSound(RMPG.SND.sdLoop)
		self:StopSound(RMPG.SND.sdCharge)
	end

	return
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------

function ENT:Initialize()
	self.Seed = math.random(1000)
	self.NextP = 0
end

function ENT:Draw() end

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

function ENT:DrawTranslucent()
	local phase, frac, t = self:Phase()
	local col = self:FluidCol()
	local r, g, b = col.x, col.y, col.z
	local now = CurTime()
	local base = self:GetPos()
	local vpos = self:GetVortexPos()
	local R = self:GetRadius()
	local core = self:GetCore()
	local ground = Vector(base.x, base.y, self:GetGroundZ() + 2)
	local M = RMPG.Mat

	-- the gun: rises, shakes, spins faster and faster, then gets swallowed
	local gunPos, gunScale = base + UP * 18 * math.min(1, t / CHARGE) ^ 2, 0.6
	if phase == 2 then
		gunPos = LerpVector(math.Clamp(frac * 3, 0, 1), base + UP * 18, vpos)
		gunScale = 0.6 * (1 - math.Clamp(frac * 2.5, 0, 1))
	elseif phase == 3 then
		gunScale = 0
	end
	if gunScale > 0.02 then
		local shake = phase == 1 and frac * 1.5 or 2
		gunPos = gunPos + VectorRand() * shake
		local ang = Angle(math.sin(now * 13) * 8 * frac, self:GetAngles().y + t * t * 40, math.cos(now * 11) * 8 * frac)
		local st = {
			variant = self:GetVariant(), color = col, level = 0.55 + 0.45 * math.sin(now * 10), core = core,
			body = self:GetBodyColor():LengthSqr() > 0 and self:GetBodyColor() or nil,
			fire = 0.3 + 0.5 * frac, time = now, outline = RMPG.CL.outline:GetBool(), light = 1, glow = true, detail = 1,
			display = { big = phase == 1 and string.format("%.1f", math.max(CHARGE - t, 0)) or "----", small = "----", blink = true, warn = true },
		}
		RMPG.Model.DrawGun(RMPG.Model.CenteredFrame(gunPos, ang, gunScale, st.variant), st)
		RMPG.ResetTints()
	end

	render.SetMaterial(M.glow)
	if phase == 1 then
		-- the flash rising above the gun: a soft pillar of light growing upward
		local h = 20 + 170 * frac * frac
		local flick = 0.8 + 0.2 * math.sin(now * 40)
		for i = 0, 9 do
			local f = i / 9
			local p = gunPos + UP * (h * f)
			local sz = (18 + 60 * frac) * (1 - f * 0.55) * flick
			render.DrawSprite(p, sz, sz, Color(r, g, b, 140 * (1 - f * 0.6)))
		end
		render.DrawSprite(gunPos + UP * h, 40 + 140 * frac, 40 + 140 * frac, Color(r, g, b, 255))
		render.DrawSprite(gunPos + UP * h, 15 + 50 * frac, 15 + 50 * frac, Color(255, 255, 255, 230))
		render.DrawSprite(gunPos, 30 + 80 * frac, 30 + 80 * frac, Color(255, 255, 255, 160 * frac))
		render.SetMaterial(M.beam)
		render.DrawBeam(gunPos, gunPos + UP * h, (4 + 10 * frac) * flick, 0, 1, Color(255, 255, 255, 220))
		-- crackling around the gun
		for _ = 1, math.floor(1 + frac * 4) do
			Arc(gunPos, gunPos + VectorRand():GetNormalized() * (20 + 40 * frac), 2, Color(r, g, b, 255), 5, 6)
		end
		-- danger zone on the ground
		local pr = (now * 0.8) % 1
		RMPG.DrawGlowDisc(ground, UP, R, r * 0.4, g * 0.4, b * 0.4, 90 * frac)
		RMPG.DrawRing(ground, UP, R, r, g, b, 160 * frac)
		RMPG.DrawRing(ground, UP, R * pr, r, g, b, 220 * (1 - pr) * frac)
	elseif phase == 2 then
		local grow = math.Clamp(frac * 5, 0, 1)
		local shrink = 1 - math.Clamp((frac - 0.9) * 10, 0, 1)
		local size = math.min(R * 0.28, 160) * grow * shrink * (1 + 0.05 * math.sin(now * 7))
		render.DrawSprite(vpos, size * 4, size * 4, Color(r, g, b, 110))
		local ang = (EyePos() - vpos):Angle()
		ang:RotateAroundAxis(ang:Forward(), now * 160)
		RMPG.DrawPortal(vpos, ang, size, col, 1, RMPG.ShapeFrame(now), core)
		render.SetMaterial(M.glow)
		render.DrawSprite(vpos, size * 0.8, size * 0.8, Color(255, 255, 255, 230))
		RMPG.DrawGlowDisc(Vector(vpos.x, vpos.y, ground.z), UP, R, r * 0.35, g * 0.35, b * 0.35, 120)
		RMPG.DrawRing(Vector(vpos.x, vpos.y, ground.z), UP, R * (0.98 + 0.02 * math.sin(now * 8)), r, g, b, 200)
		local pr = 1 - (now * 1.4) % 1
		RMPG.DrawRing(Vector(vpos.x, vpos.y, ground.z + 1), UP, R * pr, r, g, b, 160 * (1 - pr))

		-- matter streaking into the singularity
		render.SetMaterial(M.beam)
		for i = 1, (core and 40 or 26) do
			local seed = i * 13.37 + self.Seed
			local ph = (now * (0.9 + (i % 5) * 0.15) + i * 0.618) % 1
			local a = now * 1.5 + ph * 2.5 + seed
			local dz = math.sin(seed * 0.7) * 0.6
			local dir = Vector(math.cos(a), math.sin(a), dz):GetNormalized()
			local dist = R * (1 - ph)
			render.DrawBeam(vpos + dir * dist, vpos + dir * math.max(dist - 30 - R * 0.1, 0), 4, 0, 1, Color(r, g, b, 230 * ph))
		end
		-- lightning to the ground
		local n = core and 3 or 2
		for k = 1, n do
			local seed = math.floor(now * 12) + k * 17 + self.Seed
			local a = util.SharedRandom("rmpg_sd", 0, math.pi * 2, seed)
			local dist = R * util.SharedRandom("rmpg_sd2", 0.3, 0.9, seed)
			local hit = Vector(vpos.x + math.cos(a) * dist, vpos.y + math.sin(a) * dist, ground.z)
			Arc(vpos, hit, 3, Color(r, g, b, 255), 8, 18)
			Arc(vpos, hit, 1.2, Color(255, 255, 255, 255), 8, 12)
		end
	else
		local fl = 1 - frac
		render.DrawSprite(vpos, R * 3 * (0.3 + frac), R * 3 * (0.3 + frac), Color(r, g, b, 255 * fl))
		render.DrawSprite(vpos, R * (0.6 + frac), R * (0.6 + frac), Color(255, 255, 255, 255 * fl * fl))
		RMPG.DrawGlowDisc(Vector(vpos.x, vpos.y, ground.z + 1), UP, R * (0.3 + 1.7 * frac), r * 0.5, g * 0.5, b * 0.5, 200 * fl)
		RMPG.DrawRing(Vector(vpos.x, vpos.y, ground.z + 1), UP, R * (0.2 + 1.8 * frac), r, g, b, 255 * fl)
		RMPG.DrawRing(Vector(vpos.x, vpos.y, ground.z + 1), UP, R * (0.1 + 1.2 * frac), 255, 255, 255, 180 * fl)
		local _, ax, ay = RMPG.PortalAxes((EyePos() - vpos):Angle())
		render.SetMaterial(M.ring)
		local rs = R * (0.1 + 1.4 * frac)
		RMPG.DrawQuad(vpos, ax, ay, rs, rs, 0, 0, 1, 1, r, g, b, 220 * fl)
		RMPG.DrawQuad(vpos, ax, ay, rs * 0.7, rs * 0.7, 0, 0, 1, 1, 255, 255, 255, 150 * fl)
	end
end

function ENT:Think()
	local R = self:GetRadius()
	if R > 0 then
		local bb = Vector(R * 1.9, R * 1.9, R * 1.9)
		self:SetRenderBounds(-bb, bb)
	end
	local phase, frac = self:Phase()
	local col = self:FluidCol()
	local vpos = self:GetVortexPos()

	local dl = DynamicLight(self:EntIndex())
	if dl then
		dl.pos = phase == 1 and (self:GetPos() + UP * 40) or vpos
		dl.r, dl.g, dl.b = col.x, col.y, col.z
		dl.brightness = phase == 1 and (1 + 3 * frac) or (phase == 2 and 5 or 8 * (1 - frac))
		dl.decay = 2000
		dl.size = phase == 1 and 300 + 400 * frac or R * 2.2
		dl.dietime = CurTime() + 0.2
	end

	if phase == 3 and not self.Flashed then
		self.Flashed = true
		local d = EyePos():Distance(vpos)
		local k = math.Clamp(1.4 - d / (R * 3), 0, 1)
		if k > 0 and RMPG.ScreenFlash then RMPG.ScreenFlash(col, k, 1.2) end
		self:Burst(vpos, col, R)
	end

	if not RMPG.CL.particles:GetBool() or CurTime() < self.NextP then return end
	self.NextP = CurTime() + 0.03
	self.Emitter = self.Emitter or ParticleEmitter(vpos, false)
	if not self.Emitter then return end
	if phase == 1 then
		-- sparks rising with the flash
		local p = self.Emitter:Add(RMPG.Mat.spark, self:GetPos() + VectorRand() * 8)
		if p then
			p:SetVelocity(UP * math.Rand(120, 260) * (0.4 + frac) + VectorRand() * 30)
			p:SetDieTime(math.Rand(0.4, 0.9))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(2, 4))
			p:SetEndSize(0)
			p:SetColor(col.x, col.y, col.z)
			p:SetStartLength(14)
			p:SetEndLength(2)
		end
	elseif phase == 2 then
		for _ = 1, 4 do
			local p0 = vpos + VectorRand():GetNormalized() * (R * math.Rand(0.4, 1))
			local pt = self.Emitter:Add(RMPG.Mat.spark, p0)
			if pt then
				local inward = (vpos - p0)
				pt:SetVelocity(inward * 1.6 + inward:Cross(UP) * 0.8)
				pt:SetDieTime(0.6)
				pt:SetStartAlpha(0)
				pt:SetEndAlpha(255)
				pt:SetStartSize(math.Rand(2, 6))
				pt:SetEndSize(0.5)
				pt:SetColor(col.x, col.y, col.z)
				pt:SetStartLength(24)
				pt:SetEndLength(4)
			end
		end
	end
end

-- Final burst of sparks flying out of the implosion
function ENT:Burst(pos, col, R)
	if not RMPG.CL.particles:GetBool() then return end
	local em = ParticleEmitter(pos, false)
	if not em then return end
	for _ = 1, 90 do
		local p = em:Add(RMPG.Mat.spark, pos)
		if p then
			p:SetVelocity(VectorRand():GetNormalized() * math.Rand(R * 0.8, R * 2.4))
			p:SetDieTime(math.Rand(0.6, 1.4))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(3, 8))
			p:SetEndSize(0)
			p:SetColor(math.min(255, col.x + 80), math.min(255, col.y + 80), math.min(255, col.z + 80))
			p:SetAirResistance(80)
			p:SetStartLength(40)
			p:SetEndLength(4)
		end
	end
	em:Finish()
end

function ENT:OnRemove()
	if self.Emitter then self.Emitter:Finish() self.Emitter = nil end
end

killicon.AddAlias("rmpg_meltdown", "prop_combine_ball")
