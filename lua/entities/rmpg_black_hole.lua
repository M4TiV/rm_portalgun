AddCSLuaFile()

-- The black hole a neutrino bomb leaves behind: it swells, pulls in everything around (players can run against it),
-- tears apart whatever reaches the middle, and collapses after its time. Not spawnable on its own.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.black_hole"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local GROW, SHRINK = 1.5, 1.5
local CORE = 60 -- radius of the black middle at full size
local UP = Vector(0, 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Born")
	self:NetworkVar("Float", 1, "Life")
	self:NetworkVar("Float", 2, "PullRadius")
end

-- 0..1 how big it is: swelling, full, collapsing
function ENT:Size()
	local t = CurTime() - self:GetBorn()
	local life = self:GetLife()
	if t < GROW then return math.sin(t / GROW * math.pi / 2) end
	if t > life - SHRINK then return math.Clamp((life - t) / SHRINK, 0, 1) end
	return 1
end

if SERVER then
	local SKIP = { rmpg_portal = true, rmpg_black_hole = true, rmpg_meltdown = true }

	function ENT:Initialize()
		self:SetModel("models/hunter/misc/sphere025x025.mdl")
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetNotSolid(true)
		self:DrawShadow(false)
		self:SetBorn(CurTime())
		self.Loop = CreateSound(self, RMPG.SND.nbHole)
		self.Loop:PlayEx(1, 60)
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:Think()
		local now = CurTime()
		if now - self:GetBorn() >= self:GetLife() then
			self:Collapse()
			return
		end
		local k = self:Size()
		local R = self:GetPullRadius() * k
		local core = CORE * k + 10
		local center = self:GetPos()
		local dt = FrameTime()
		if self.Loop then self.Loop:ChangePitch(60 + 40 * k, 0) end
		for _, e in ipairs(ents.FindInSphere(center, R)) do
			if IsValid(e) and not e:IsWorld() and not SKIP[e:GetClass()] and not IsValid(e:GetParent()) and not e.RMPG_Vaporized
				and not (e:IsWeapon() and IsValid(e:GetOwner())) then
				local off = center - e:WorldSpaceCenter()
				local d = math.max(off:Length(), 1)
				local dir = off / d
				local near = 1 - d / R
				if d < core then
					if not e:IsPlayer() or (e:Alive() and not e:HasGodMode()) then RMPG.Disintegrate(e, self.Attacker, self, center) end
				elseif e:IsPlayer() then
					-- strong, but you can still sprint out at the edge
					if e:Alive() and e:GetVelocity():Dot(dir) < 500 then e:SetVelocity(dir * ((500 + 2200 * near * near) * dt)) end
				elseif e:IsNPC() or e:IsNextBot() then
					e:SetPos(e:GetPos() + dir * math.min((80 + 500 * near) * dt, d))
				elseif e:GetMoveType() == MOVETYPE_VPHYSICS then
					for i = 0, e:GetPhysicsObjectCount() - 1 do
						local po = e:GetPhysicsObjectNum(i)
						if IsValid(po) and po:IsMotionEnabled() then
							po:Wake()
							po:ApplyForceCenter(dir * ((800 + 3000 * near) * po:GetMass() * dt) + UP * (200 * po:GetMass() * dt))
						end
					end
				end
			end
		end
		self:NextThink(now)
		return true
	end

	function ENT:Collapse()
		if self.Gone then return end
		self.Gone = true
		local ed = EffectData()
		ed:SetOrigin(self:GetPos())
		ed:SetNormal(UP)
		ed:SetStart(Vector(190, 110, 255))
		ed:SetScale(3)
		util.Effect("rmpg_burst", ed, true, true)
		sound.Play(RMPG.SND.sdImplode, self:GetPos(), 100, 120)
		self:Remove()
	end

	function ENT:OnRemove()
		if self.Loop then self.Loop:Stop() end
	end

	return
end

---------------------------------------------------------------------------
-- Client: bent light around it, the black middle, a spinning orange-violet disk and matter falling in
---------------------------------------------------------------------------

local PINCH = Material("effects/strider_pinch_dudv")
local ORANGE = Color(255, 150, 60)
local VIOLET = Color(170, 90, 255)

function ENT:Initialize()
	self:SetRenderBounds(Vector(-600, -600, -600), Vector(600, 600, 600))
	self.NextBit = 0
end

function ENT:Draw() end

function ENT:DrawTranslucent()
	local k = self:Size()
	if k <= 0 then return end
	local pos = self:GetPos()
	local t = CurTime()
	local r = CORE * k
	-- light bending around it
	render.UpdateRefractTexture()
	render.SetMaterial(PINCH)
	render.DrawSprite(pos, r * 7, r * 7, color_white)
	-- the accretion disk, tilted and spinning, hot orange inside, violet outside
	local M = RMPG.Mat
	render.SetMaterial(M.beam)
	local tilt = Angle(18 + math.sin(t * 0.3) * 4, t * 40, 0)
	local f, rgt = tilt:Forward(), tilt:Right()
	local segs = 40
	for ring = 1, 3 do
		local rr = r * (1.4 + ring * 0.55)
		local col = ring == 1 and ORANGE or (ring == 2 and Color(230, 110, 170) or VIOLET)
		local prev
		for i = 0, segs do
			local a = i / segs * math.pi * 2 + t * (3.2 - ring * 0.6)
			local p = pos + (f * math.cos(a) + rgt * math.sin(a)) * rr
			if prev then render.DrawBeam(prev, p, r * (0.5 - ring * 0.1), 0, 1, Color(col.r, col.g, col.b, 200 - ring * 40)) end
			prev = p
		end
	end
	render.SetMaterial(M.glow)
	render.DrawSprite(pos, r * 5, r * 5, Color(VIOLET.r, VIOLET.g, VIOLET.b, 90 * k))
	render.DrawSprite(pos, r * 3, r * 3, Color(ORANGE.r, ORANGE.g, ORANGE.b, 120 * k))
	-- the black middle
	render.SetColorMaterial()
	render.DrawSphere(pos, r, 24, 24, Color(0, 0, 0, 255))
end

function ENT:Think()
	local k = self:Size()
	if k <= 0 then return end
	if RMPG.CL.particles:GetBool() and RealTime() >= self.NextBit then
		self.NextBit = RealTime() + 0.03
		-- matter streaming in from all around
		local em = ParticleEmitter(self:GetPos(), false)
		if em then
			local dir = VectorRand():GetNormalized()
			local dist = self:GetPullRadius() * 0.35 * k
			local p = em:Add(RMPG.Mat.glow, self:GetPos() + dir * dist)
			if p then
				local life = 0.8
				p:SetVelocity(-dir * (dist / life))
				p:SetDieTime(life)
				p:SetStartAlpha(0)
				p:SetEndAlpha(255)
				p:SetStartSize(math.Rand(6, 14))
				p:SetEndSize(1)
				local c = math.random() < 0.5 and ORANGE or VIOLET
				p:SetColor(c.r, c.g, c.b)
			end
			em:Finish()
		end
	end
	local dl = DynamicLight(self:EntIndex())
	if dl then
		dl.pos = self:GetPos()
		dl.r, dl.g, dl.b = VIOLET.r, VIOLET.g, VIOLET.b
		dl.brightness = 2 * k
		dl.size = 700 * k
		dl.decay = 2000
		dl.dietime = CurTime() + 0.2
	end
end
