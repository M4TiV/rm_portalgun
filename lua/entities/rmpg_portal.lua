AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Portal"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Partner")
	self:NetworkVar("Entity", 1, "OwnerPlayer")
	self:NetworkVar("Vector", 0, "PortalColor")
	self:NetworkVar("Float", 0, "Radius")
	self:NetworkVar("Float", 1, "OpenTime")
	self:NetworkVar("Float", 2, "CloseTime")
	self:NetworkVar("Bool", 0, "Freestanding")
	self:NetworkVar("Bool", 1, "Core")
end

function ENT:OpenScale()
	return RMPG.OpenScale(self:GetOpenTime(), self:GetCloseTime())
end

-- Things the portal reacts to (teleports on the server, reaches toward on the client)
local function IsVisitor(ent)
	if ent:IsPlayer() then return ent:Alive() end
	if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
	return ent:GetMoveType() == MOVETYPE_VPHYSICS
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/plates/plate1x1.mdl")
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetNotSolid(true)
		self:DrawShadow(false)
		if self:GetRadius() <= 0 then self:SetRadius(RMPG.Radius()) end
		self:SetOpenTime(CurTime())
		self:EmitSound(RMPG.SND.open, 80, math.random(96, 104))
	end

	function ENT:Close()
		if self:GetCloseTime() > 0 then return end
		self:SetCloseTime(CurTime())
		self:EmitSound(RMPG.SND.close, 75, math.random(96, 104))
		if self.RMPG_Chain then
			-- a link of a chain closes alone: the one before it now leads into the one after it
			RMPG.ChainRelink(self:GetOwnerPlayer())
			return
		end
		local p = self:GetPartner()
		if IsValid(p) then p:Close() end
	end

	function ENT:Think()
		local t = CurTime()
		if self:GetCloseTime() > 0 then
			if t > self:GetCloseTime() + RMPG.CLOSE_TIME then self:Remove() end
			self:NextThink(t)
			return true
		end
		if self.DieTime and t >= self.DieTime then self:Close() end

		local partner = self:GetPartner()
		if self.WasLinked and not IsValid(partner) and not self.RMPG_Chain then
			self:Close()
		elseif IsValid(partner) and partner:GetCloseTime() == 0 then
			local s = self:OpenScale()
			if s > 0.6 and partner:OpenScale() > 0.3 then self:Scan(partner, s) end
		end
		self:NextThink(t)
		return true
	end

	function ENT:Scan(partner, s)
		local center, ang = self:GetPos(), self:GetAngles()
		local f = ang:Forward()
		local half = self:GetRadius() * s
		local frame = RMPG.ShapeFrame(CurTime())
		local dt = math.max(FrameTime(), engine.TickInterval())
		for _, ent in ipairs(ents.FindInSphere(center, half + 220)) do
			if ent ~= self and RMPG.CanTeleport(ent) then
				-- look a couple of ticks ahead so fast movers (falling players!) are caught
				-- before they hit the surface and lose their speed or take fall damage
				local depth = (ent:WorldSpaceCenter() - center):Dot(f)
				local vn = ent:GetVelocity():Dot(f)
				local approach = (depth > 0 and -vn or vn)
				local extra = math.max(approach, 0) * dt * 2.5
				local radiusMul = 1
				if ent:IsPlayer() then
					extra = extra + 4
					radiusMul = 1.06
				end
				local touching = RMPG.TouchesPortal(ent, center, ang, half, frame, extra, radiusMul)
				if ent.RMPG_IgnorePortal == self then
					-- just came out of this portal: wait until it stepped away
					if not touching and CurTime() > (ent.RMPG_IgnoreUntil or 0) then ent.RMPG_IgnorePortal = nil end
				elseif touching then
					RMPG.Teleport(ent, self, partner)
				end
			end
		end
	end

	function ENT:OnRemove()
		local o = self:GetOwnerPlayer()
		if IsValid(o) and o.RMPG_PendingA == self then o.RMPG_PendingA = nil end
		if self.RMPG_Chain and IsValid(o) then
			timer.Simple(0, function() if IsValid(o) then RMPG.ChainRelink(o) end end)
		end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_PVS
	end
	return
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------

local BOUNDS = Vector(300, 300, 300)
local REACH = 150

function ENT:Initialize()
	self:SetRenderBounds(-BOUNDS, BOUNDS)
	self.NextSpark = 0
	self.NextBulge = 0
	self.Bulges = {}
	self.Smooth = {}
end

function ENT:Draw() end

function ENT:DrawTranslucent()
	local s = self:OpenScale()
	if s <= 0.01 then return end
	local t = CurTime()
	local alpha = 1
	if not IsValid(self:GetPartner()) then
		-- waiting for its exit (manual mode): unstable flicker
		alpha = 0.55 + 0.25 * math.sin(t * 17) + 0.2 * math.random()
	end
	local wob = 1 + 0.012 * math.sin(t * 3.1 + self:EntIndex())
	RMPG.DrawPortal(self:GetPos(), self:GetAngles(), self:GetRadius() * s * wob, self:GetPortalColor(),
		alpha, RMPG.ShapeFrame(t), self:GetCore(), self.Bulges, EyePos():Distance(self:GetPos()))
end

-- The surface stretches toward anything standing close in front of it
function ENT:UpdateBulges(half, s, step)
	local pos, ang = self:GetPos(), self:GetAngles()
	local f, ax, ay = RMPG.PortalAxes(ang)
	local found = {}
	for _, ent in ipairs(ents.FindInSphere(pos, half + REACH)) do
		if ent ~= self and IsValid(ent) and not ent:IsWeapon() and ent:GetClass() ~= "rmpg_portal" and IsVisitor(ent) then
			local d = ent:WorldSpaceCenter() - pos
			local depth = d:Dot(f)
			local px, py = d:Dot(ax), d:Dot(ay)
			if math.abs(depth) < REACH and px * px + py * py < (half * 1.5) ^ 2 then
				local k = (1 - math.abs(depth) / REACH) ^ 1.5
				local str = math.min(22 * k * s, math.abs(depth) * 0.7)
				found[ent] = { math.Clamp(px, -half, half), math.Clamp(py, -half, half), depth >= 0 and str or -str }
			end
		end
	end
	-- ease in / out so the bulge grows and settles smoothly
	local dt = math.min(step * 6, 1)
	for ent, b in pairs(found) do
		local sm = self.Smooth[ent]
		if not sm then sm = { b[1], b[2], 0 } self.Smooth[ent] = sm end
		sm[1], sm[2] = Lerp(math.min(dt * 2, 1), sm[1], b[1]), Lerp(math.min(dt * 2, 1), sm[2], b[2])
		sm[3] = Lerp(dt, sm[3], b[3])
	end
	local list = {}
	for ent, sm in pairs(self.Smooth) do
		if not found[ent] then
			sm[3] = Lerp(dt, sm[3], 0)
			if math.abs(sm[3]) < 0.05 or not IsValid(ent) then self.Smooth[ent] = nil end
		end
		if self.Smooth[ent] then list[#list + 1] = { sm[1], sm[2], sm[3], half * 0.42 + 8 } end
	end
	table.sort(list, function(a, b) return math.abs(a[3]) > math.abs(b[3]) end)
	for i = #list, 4, -1 do list[i] = nil end
	self.Bulges = list
end

function ENT:Think()
	local s = self:OpenScale()
	if s <= 0.05 then return end
	local t = CurTime()
	local pos, ang = self:GetPos(), self:GetAngles()
	local dist = EyePos():Distance(pos)
	local f, ax, ay = RMPG.PortalAxes(ang)
	local half = self:GetRadius() * s

	-- only nearby portals react to visitors, and not every frame
	if dist < 1000 then
		if t >= self.NextBulge then
			local step = t - (self.LastBulge or t)
			self.LastBulge = t
			self.NextBulge = t + 0.04
			self:UpdateBulges(half, s, math.max(step, 0.04))
		end
	elseif #self.Bulges > 0 then
		self.Bulges = {}
		self.Smooth = {}
	end

	if not RMPG.CL.particles:GetBool() or dist > 1800 then return end
	local col = self:GetPortalColor()

	if RMPG.LightBudget(3) then
		local dl = DynamicLight(self:EntIndex())
		if dl then
			dl.pos = pos + f * 24
			dl.r, dl.g, dl.b = col.x, col.y, col.z
			dl.brightness = self:GetCore() and 2.5 or 1.6
			dl.decay = 1000
			dl.size = half * 3.5
			dl.dietime = t + 0.15
		end
	end

	if t < self.NextSpark then return end
	self.NextSpark = t + (dist < 600 and 0.06 or 0.15)
	self.Emitter = self.Emitter or ParticleEmitter(pos, false)
	if not self.Emitter then return end
	self.Emitter:SetPos(pos)
	local frame = RMPG.ShapeFrame(t)
	local th = math.random() * math.pi * 2
	local r = half * RMPG.ShapeRadius(frame, th)
	local out = ax * math.cos(th) + ay * math.sin(th)
	local p = self.Emitter:Add(RMPG.Mat.spark, pos + out * r + f * 2)
	if p then
		p:SetVelocity(out * math.Rand(10, 40) + f * math.Rand(5, 25))
		p:SetDieTime(math.Rand(0.4, 0.8))
		p:SetStartAlpha(255)
		p:SetEndAlpha(0)
		p:SetStartSize(math.Rand(3, 6))
		p:SetEndSize(0)
		p:SetColor(math.min(255, col.x + 60), math.min(255, col.y + 60), math.min(255, col.z + 60))
		p:SetAirResistance(30)
	end
end

function ENT:OnRemove()
	if self.Emitter then self.Emitter:Finish() self.Emitter = nil end
end
