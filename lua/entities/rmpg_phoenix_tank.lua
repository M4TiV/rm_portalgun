AddCSLuaFile()

-- Operation Phoenix tank: DNA injected into it grows a body - first raw meat, then skin covers it - floating limp in
-- green fluid behind clear glass; the finished body takes the chosen mind (by default whoever injected the DNA).
-- The DNA only waits in the tank until its size is chosen in the window, which starts the growth.
-- E opens its window. Enough damage breaks the glass: the fluid spills, the body falls out as a ragdoll, and nobody can
-- come back to life in a broken tank.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.tank"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "entities/rmpg_phoenix_tank.png"

local MODEL = "models/rmpg/phoenix_tank.mdl"
local FLOOR, TOP, R = 8.4, 104, 28 -- inside of the glass tube (models/rmpg/phoenix_tank.mdl)
local MID = (FLOOR + TOP) / 2
local UP = Vector(0, 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "State") -- 0 empty, 1 growing, 2 ready, 3 the DNA is in and waits for its size
	self:NetworkVar("Float", 0, "GrowStart")
	self:NetworkVar("Float", 1, "CloneScale") -- body size, 1 = normal
	self:NetworkVar("String", 0, "CloneModel")
	self:NetworkVar("String", 1, "CloneBodygroups")
	self:NetworkVar("String", 2, "CloneLabel")
	self:NetworkVar("Int", 1, "CloneSkin")
	self:NetworkVar("Entity", 0, "Mind")
	self:NetworkVar("Entity", 1, "Injector")
	self:NetworkVar("Bool", 0, "Auto")
	self:NetworkVar("Bool", 1, "Broken")
end

function ENT:Times()
	return RMPG.CV.phxFlesh:GetFloat(), RMPG.CV.phxSkin:GetFloat()
end

-- 0..1 through the whole growth, and the phase: 1 meat, 2 skin, 3 done
function ENT:Progress()
	if self:GetState() == 2 then return 1, 3 end
	if self:GetState() ~= 1 then return 0, 0 end
	local f, s = self:Times()
	local t = CurTime() - self:GetGrowStart()
	return math.Clamp(t / (f + s), 0, 1), t < f and 1 or 2
end

-- Seconds until the body is ready
function ENT:TimeLeft()
	if self:GetState() ~= 1 then return 0 end
	local f, s = self:Times()
	return math.max(self:GetGrowStart() + f + s - CurTime(), 0)
end

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 2)
		e:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
		e:Spawn()
		e:Activate()
		local po = e:GetPhysicsObject()
		if IsValid(po) then po:EnableMotion(false) end
		return e
	end

	function ENT:Initialize()
		self:SetModel(MODEL)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetAuto(RMPG.CV.phxAuto:GetBool())
		self:SetCloneScale(1)
		self.HP = RMPG.CV.phxTankHP:GetFloat()
		local po = self:GetPhysicsObject()
		if IsValid(po) then po:Wake() end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	-- dna = { model, skin, bodygroups, label, owner = player whose own DNA it is }. It waits for the size (ENT:Begin).
	function ENT:LoadDNA(dna, injector)
		if self:GetState() ~= 0 or self:GetBroken() then return false end
		self:SetCloneModel(dna.model)
		self:SetCloneSkin(dna.skin or 0)
		self:SetCloneBodygroups(dna.bodygroups or "")
		self:SetCloneLabel(dna.label or "")
		self:SetInjector(injector)
		self:SetMind(IsValid(dna.owner) and dna.owner or injector)
		self:SetAuto(RMPG.CV.phxAuto:GetBool())
		self:SetState(3)
		return true
	end

	-- The size is chosen: the body starts to grow
	function ENT:Begin()
		if self:GetState() ~= 3 or self:GetBroken() then return false end
		self:SetGrowStart(CurTime())
		self:SetState(1)
		self.Loop = self.Loop or CreateSound(self, RMPG.SND.phxLoop)
		self.Loop:PlayEx(0.5, 90)
		self.NextSquish = CurTime()
		return true
	end

	function ENT:Empty()
		self:SetState(0)
		self:SetCloneModel("")
		self:SetMind(NULL)
		if self.Loop then self.Loop:Stop() end
	end

	function ENT:Think()
		if self:GetState() == 1 then
			local now = CurTime()
			local f, s = self:Times()
			if now < self:GetGrowStart() + f and now >= self.NextSquish then
				self.NextSquish = now + math.Rand(0.6, 1.4)
				self:EmitSound(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), 60, math.random(80, 110))
			end
			if now >= self:GetGrowStart() + f + s then
				self:SetState(2)
				self:EmitSound(RMPG.SND.phxReady, 75)
				for _, p in ipairs({ self:GetInjector(), self:GetMind() }) do
					if IsValid(p) then RMPG.Notify(p, "n_phx_ready", nil, 2) end
				end
			end
		end
		self:NextThink(CurTime() + 0.2)
		return true
	end

	function ENT:Use(ply)
		if IsValid(ply) and ply:IsPlayer() then RMPG.PhxOpenMenu(ply, self) end
	end

	---------------------------------------------------------------------------
	-- Breaking the glass
	---------------------------------------------------------------------------

	-- The body inside falls out as a ragdoll: raw meat if the skin had not started, the finished body otherwise
	function ENT:SpillBody(attacker)
		local model = self:GetCloneModel()
		if self:GetState() == 0 or self:GetState() == 3 or model == "" or not util.IsValidRagdoll(model) then return end
		local _, phase = self:Progress()
		local rag = ents.Create("prop_ragdoll")
		if not IsValid(rag) then return end
		rag:SetModel(model)
		rag:SetSkin(self:GetCloneSkin())
		local bg = self:GetCloneBodygroups()
		for i = 1, #bg do rag:SetBodygroup(i - 1, string.byte(bg, i) - 48) end
		rag:SetPos(self:LocalToWorld(Vector(0, 0, FLOOR + 14)))
		rag:SetAngles(self:GetAngles())
		rag:Spawn()
		rag:Activate()
		if phase == 1 then rag:SetMaterial("models/flesh") end
		local push = self:GetForward() * 140 + UP * 60
		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local po = rag:GetPhysicsObjectNum(i)
			if IsValid(po) then
				po:SetVelocity(push + VectorRand() * 30)
				po:Wake()
			end
		end
		local owner = IsValid(self:GetInjector()) and self:GetInjector() or (IsValid(attacker) and attacker:IsPlayer() and attacker or nil)
		if owner then
			undo.Create("Ragdoll")
				undo.AddEntity(rag)
				undo.SetPlayer(owner)
			undo.Finish()
		end
	end

	function ENT:Shatter(attacker)
		if self:GetBroken() then return end
		self:SpillBody(attacker)
		self:Empty()
		self:SetBroken(true)
		-- only the base stays solid, so the body is not stuck inside the old tube
		self:PhysicsInitBox(Vector(-36, -36, 0), Vector(36, 36, FLOOR))
		local po = self:GetPhysicsObject()
		if IsValid(po) then po:EnableMotion(false) end
		local c = self:LocalToWorld(Vector(0, 0, MID))
		sound.Play(string.format(RMPG.SND.shatter, math.random(1, 3)), c, 90, math.random(90, 105))
		sound.Play(RMPG.SND.phxSpill, c, 80, 95)
		local ed = EffectData()
		ed:SetOrigin(c)
		ed:SetEntity(self)
		ed:SetRadius(R)
		util.Effect("rmpg_phx_spill", ed, true, true)
	end

	function ENT:Repair()
		if not self:GetBroken() then return end
		self:SetBroken(false)
		self.HP = RMPG.CV.phxTankHP:GetFloat()
		self:PhysicsInit(SOLID_VPHYSICS)
		local po = self:GetPhysicsObject()
		if IsValid(po) then po:EnableMotion(false) end
		self:EmitSound("buttons/lever7.wav", 70)
	end

	function ENT:OnTakeDamage(dmg)
		if self:GetBroken() then return end
		self.HP = (self.HP or 150) - dmg:GetDamage()
		if self.HP <= 0 then
			self:Shatter(dmg:GetAttacker())
		elseif (self.NextClink or 0) < CurTime() then
			self.NextClink = CurTime() + 0.15
			self:EmitSound(string.format(RMPG.SND.freezeDone, math.random(1, 4)), 70, math.random(95, 110))
		end
	end

	function ENT:OnRemove()
		if self.Loop then self.Loop:Stop() end
	end

	return
end

---------------------------------------------------------------------------
-- Client: the body floating inside, the fluid, bubbles and the progress above the tank
---------------------------------------------------------------------------

local FLESH = Material("models/flesh")
local GREEN = Color(90, 255, 160)
local FLUID = Color(60, 210, 130)

-- Limbs drifting in the fluid: bone, swing (degrees), speed (Hz), phase
local SWAY = {
	{ "ValveBiped.Bip01_Head1", Angle(4, 7, 5), 0.13, 0 },
	{ "ValveBiped.Bip01_Spine2", Angle(3, 3, 2), 0.1, 1.3 },
	{ "ValveBiped.Bip01_L_UpperArm", Angle(5, 9, 7), 0.11, 2 },
	{ "ValveBiped.Bip01_R_UpperArm", Angle(-5, -9, -7), 0.12, 2.7 },
	{ "ValveBiped.Bip01_L_Forearm", Angle(0, 12, 4), 0.16, 3.1 },
	{ "ValveBiped.Bip01_R_Forearm", Angle(0, 12, -4), 0.15, 4.2 },
	{ "ValveBiped.Bip01_L_Hand", Angle(6, 10, 0), 0.2, 5 },
	{ "ValveBiped.Bip01_R_Hand", Angle(-6, 10, 0), 0.19, 5.6 },
	{ "ValveBiped.Bip01_L_Thigh", Angle(3, 6, 4), 0.09, 6.1 },
	{ "ValveBiped.Bip01_R_Thigh", Angle(-3, 6, -4), 0.1, 6.9 },
	{ "ValveBiped.Bip01_L_Calf", Angle(0, 10, 0), 0.14, 7.4 },
	{ "ValveBiped.Bip01_R_Calf", Angle(0, 10, 0), 0.13, 8.2 },
	{ "ValveBiped.Bip01_L_Foot", Angle(0, 12, 0), 0.17, 9 },
	{ "ValveBiped.Bip01_R_Foot", Angle(0, 12, 0), 0.18, 9.5 },
}

function ENT:Initialize()
	self:SetRenderBounds(Vector(-40, -40, 0), Vector(40, 40, 150))
	self.NextBubble = 0
end

-- The floating body: the model's ragdoll pose (a limp body), measured once so it fits inside the glass
function ENT:Clone()
	local model = self:GetCloneModel()
	if self:GetState() == 0 or self:GetState() == 3 or model == "" or self:GetBroken() then
		if IsValid(self.CloneEnt) then self.CloneEnt:Remove() end
		return
	end
	local c = self.CloneEnt
	if IsValid(c) and c:GetModel() == model then return c end
	if IsValid(c) then c:Remove() end
	c = ClientsideModel(model, RENDERGROUP_OPAQUE)
	if not IsValid(c) then return end
	c:SetNoDraw(true)
	c:SetSkin(self:GetCloneSkin())
	local bg = self:GetCloneBodygroups()
	for i = 1, #bg do c:SetBodygroup(i - 1, string.byte(bg, i) - 48) end
	local seq = c:SelectWeightedSequence(ACT_DIERAGDOLL)
	if not seq or seq < 0 then seq = c:LookupSequence("ragdoll") end
	if not seq or seq < 0 then seq = c:LookupSequence("idle_all_01") end
	if seq and seq >= 0 then
		c:ResetSequence(seq)
		c:SetCycle(0)
		c:SetPlaybackRate(0)
	end
	-- size of the pose around its middle
	c:SetPos(vector_origin)
	c:SetAngles(angle_zero)
	c:SetupBones()
	local mins, maxs = Vector(1e4, 1e4, 1e4), Vector(-1e4, -1e4, -1e4)
	for i = 0, c:GetBoneCount() - 1 do
		local m = c:GetBoneMatrix(i)
		if m then
			local p = m:GetTranslation()
			mins = Vector(math.min(mins.x, p.x), math.min(mins.y, p.y), math.min(mins.z, p.z))
			maxs = Vector(math.max(maxs.x, p.x), math.max(maxs.y, p.y), math.max(maxs.z, p.z))
		end
	end
	if maxs.z > mins.z then
		c.Mid = (mins + maxs) / 2
		local reach = math.max(maxs.x - c.Mid.x, maxs.y - c.Mid.y, c.Mid.x - mins.x, c.Mid.y - mins.y) + 4
		local tall = maxs.z - mins.z + 10
		c.Fit = math.min(1, (R - 3) / math.max(reach, 1), (TOP - FLOOR - 6) / tall)
	else
		c.Mid, c.Fit = Vector(0, 0, 36), 0.9
	end
	c.Bones = {}
	for _, s in ipairs(SWAY) do
		local b = c:LookupBone(s[1])
		if b then c.Bones[#c.Bones + 1] = { b, s[2], s[3], s[4] } end
	end
	self.CloneEnt = c
	return c
end

-- How much of the body has grown (0.25 -> 1 while it is meat) and how much skin covers it
function ENT:Growth()
	local p, phase = self:Progress()
	local f, s = self:Times()
	local t = CurTime() - self:GetGrowStart()
	if phase == 1 then return Lerp(math.Clamp(t / f, 0, 1), 0.25, 1), 0 end
	if phase == 2 then return 1, math.Clamp((t - f) / s, 0, 1) end
	return 1, 1
end

function ENT:Draw()
	self:DrawModel()
	local c = self:Clone()
	if not IsValid(c) then return end
	local grow, skin = self:Growth()
	local t = CurTime() + self:EntIndex() * 3.7
	local s = grow * c.Fit * math.Clamp(self:GetCloneScale(), 0.3, 1)
	-- drifting slowly in the middle of the tube
	local center = self:LocalToWorld(Vector(math.sin(t * 0.31) * 1.5, math.cos(t * 0.27) * 1.5, MID + math.sin(t * 0.8) * 2.5))
	local ang = self:LocalToWorldAngles(Angle(math.sin(t * 0.37) * 4, math.sin(t * 0.17) * 25, math.sin(t * 0.29) * 5))
	local off = c.Mid * s
	off:Rotate(ang)
	c:SetPos(center - off)
	c:SetAngles(ang)
	c:SetModelScale(s)
	for _, b in ipairs(c.Bones) do
		local k = math.sin((t * b[3] + b[4]) * math.pi * 2)
		c:ManipulateBoneAngles(b[1], b[2] * k)
	end
	c:SetupBones()
	if skin <= 0 then
		render.MaterialOverride(FLESH)
		c:DrawModel()
		render.MaterialOverride()
		return
	end
	c:DrawModel()
	if skin < 1 then
		-- the meat fades as the skin covers it
		render.MaterialOverride(FLESH)
		render.SetBlend(1 - skin)
		c:DrawModel()
		render.SetBlend(1)
		render.MaterialOverride()
	end
end

-- The fluid and the glass are built once and only placed every frame: rebuilding them vertex by vertex in Lua is what
-- made a standing tank lag. Both are shared by all tanks.
local GLASS_SEGS, FLUID_SEGS = 40, 24
local GLASS = { { FLOOR, R + 0.4 }, { TOP, R + 0.4 } }
for i = 1, 8 do
	local a = math.pi / 2 * i / 8
	GLASS[#GLASS + 1] = { TOP + 16 * math.sin(a), (R + 0.4) * math.cos(a) }
end

local function Paint(c)
	return c[1], c[2], c[3], c[4]
end

local function Quad(out, a, b, c, d)
	for _, v in ipairs({ a, b, c, a, c, d }) do out[#out + 1] = v end
end

-- The tube and its dome as seen from +X: faint in the middle, brighter towards the edges you look along (like real
-- glass), with a light streak down one side. Turned to face the eye, so the edges stay at the edges.
local glassMesh
local function GlassMesh()
	if glassMesh then return glassMesh end
	local out = {}
	local function V(a, z, r)
		local n = Vector(math.cos(a) * r, math.sin(a) * r, z - math.min(z, TOP)):GetNormalized()
		local i = a / (math.pi * 2) * GLASS_SEGS
		local streak = (i >= 5 and i <= 7) and 50 or 0
		local alpha = math.min(16 + 110 * (1 - math.abs(n.x)) ^ 3 + streak, 200)
		return { Vector(math.cos(a) * r, math.sin(a) * r, z), n, { 205, 255, 235, alpha } }
	end
	for k = 1, #GLASS - 1 do
		local z0, r0, z1, r1 = GLASS[k][1], GLASS[k][2], GLASS[k + 1][1], GLASS[k + 1][2]
		for i = 0, GLASS_SEGS - 1 do
			local a0, a1 = i / GLASS_SEGS * math.pi * 2, (i + 1) / GLASS_SEGS * math.pi * 2
			Quad(out, V(a0, z0, r0), V(a1, z0, r0), V(a1, z1, r1), V(a0, z1, r1))
		end
	end
	glassMesh = RMPG.Model.BuildMeshes(out, RMPG.Mat.glass, Paint)
	return glassMesh
end

-- The green fluid, one unit tall (a matrix stretches it to its level): a translucent column with a surface on top
local fluidMesh
local function FluidMesh()
	if fluidMesh then return fluidMesh end
	local out = {}
	local r = R - 0.6
	local WALL, TOP_FACE = { FLUID.r, FLUID.g, FLUID.b, 34 }, { FLUID.r, FLUID.g, FLUID.b, 70 }
	local function V(a, z, col)
		return { Vector(math.cos(a) * r, math.sin(a) * r, z), Vector(math.cos(a), math.sin(a), 0), col }
	end
	local mid = { Vector(0, 0, 1), Vector(0, 0, 1), TOP_FACE }
	for i = 0, FLUID_SEGS - 1 do
		local a0, a1 = i / FLUID_SEGS * math.pi * 2, (i + 1) / FLUID_SEGS * math.pi * 2
		Quad(out, V(a0, 0, WALL), V(a1, 0, WALL), V(a1, 1, WALL), V(a0, 1, WALL))
		out[#out + 1] = mid
		out[#out + 1] = V(a0, 1, TOP_FACE)
		out[#out + 1] = V(a1, 1, TOP_FACE)
	end
	fluidMesh = RMPG.Model.BuildMeshes(out, RMPG.Mat.glass, Paint)
	return fluidMesh
end

local function DrawMeshes(m, list)
	render.SetMaterial(RMPG.Mat.glass)
	cam.PushModelMatrix(m)
	for i = 1, #list do list[i]:Draw() end
	cam.PopModelMatrix()
end

local function Fluid(self, level)
	local m = Matrix()
	m:SetTranslation(self:LocalToWorld(Vector(0, 0, FLOOR)))
	m:SetAngles(self:GetAngles())
	m:Scale(Vector(1, 1, (TOP - 4 - FLOOR) * level))
	DrawMeshes(m, FluidMesh())
end

local function Glass(self)
	local eye = self:WorldToLocal(EyePos())
	local m = Matrix()
	m:SetTranslation(self:GetPos())
	m:SetAngles(self:LocalToWorldAngles(Angle(0, math.deg(math.atan2(eye.y, eye.x)), 0)))
	DrawMeshes(m, GlassMesh())
end

function ENT:DrawTranslucent(flags)
	local state = self:GetState()
	if state > 0 and not self:GetBroken() then
		-- the tank fills up when the DNA goes in
		Fluid(self, state == 3 and 0.06 or math.Clamp((CurTime() - self:GetGrowStart()) / 2, 0.05, 1))
	end
	if not self:GetBroken() then Glass(self) end
	local pos = self:LocalToWorld(Vector(0, 0, 142))
	if EyePos():DistToSqr(pos) > 900 * 900 then return end
	local ang = EyeAngles()
	ang:RotateAroundAxis(ang:Up(), -90)
	ang:RotateAroundAxis(ang:Forward(), 90)
	local p, phase = self:Progress()
	local text
	if self:GetBroken() then
		text = RMPG.T("phx_broken")
	elseif state == 0 then
		text = RMPG.T("tank_name")
	elseif state == 3 then
		text = RMPG.T("phx_wait")
	else
		text = (phase == 1 and RMPG.T("phx_flesh") or (phase == 2 and RMPG.T("phx_skin") or RMPG.T("phx_ready"))) .. "  " .. math.floor(p * 100) .. "%"
	end
	cam.Start3D2D(pos, ang, 0.1)
		RMPG.HoloBox(-170, -40, 340, 80, Color(3, 18, 12, 210), self:GetBroken() and Color(255, 90, 90) or GREEN)
		RMPG.HoloText(text, "RMPG_Head", 0, -14, Color(225, 255, 236), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		if state == 1 or state == 2 then
			surface.SetDrawColor(10, 40, 26, 230)
			surface.DrawRect(-150, 10, 300, 14)
			surface.SetDrawColor(phase == 1 and Color(230, 80, 90) or GREEN)
			surface.DrawRect(-150, 10, 300 * p, 14)
		end
	cam.End3D2D()
end

function ENT:Think()
	local state = self:GetState()
	if state == 0 or state == 3 or self:GetBroken() or CurTime() < self.NextBubble or not RMPG.CL.particles:GetBool() then return end
	self.NextBubble = CurTime() + 0.12
	local em = ParticleEmitter(self:GetPos(), false)
	if not em then return end
	local a, r = math.Rand(0, math.pi * 2), math.Rand(4, R - 4)
	local p = em:Add(RMPG.Mat.glow, self:LocalToWorld(Vector(math.cos(a) * r, math.sin(a) * r, FLOOR + 2)))
	if p then
		p:SetVelocity(UP * math.Rand(30, 60))
		p:SetDieTime(math.Rand(1.6, 2.6))
		p:SetStartAlpha(180)
		p:SetEndAlpha(0)
		p:SetStartSize(math.Rand(1, 2.5))
		p:SetEndSize(2.5)
		p:SetColor(GREEN.r, GREEN.g, GREEN.b)
	end
	em:Finish()
	local dl = DynamicLight(self:EntIndex())
	if dl then
		dl.pos = self:LocalToWorld(Vector(0, 0, MID))
		dl.r, dl.g, dl.b = GREEN.r, GREEN.g, GREEN.b
		dl.brightness = 0.8
		dl.decay = 1000
		dl.size = 200
		dl.dietime = CurTime() + 0.3
	end
end

function ENT:OnRemove()
	if IsValid(self.CloneEnt) then self.CloneEnt:Remove() end
end
