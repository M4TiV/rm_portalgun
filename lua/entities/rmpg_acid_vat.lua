AddCSLuaFile()

-- A vat of acid, from the episode with the fake one. The real acid eats whatever goes in: the living burn down to a
-- skeleton that floats up to the top, props shrink away in a hiss. The fake vat (rmpg_acid_vat_fake, the same vat) only
-- looks like it: whoever jumps in "dies" for everyone to see - a scream, a skeleton floats up out of the BONES hatch at
-- the bottom, the chat says so - and is in fact hiding at the bottom, unseen and left alone by NPCs, until they climb out.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.acid_vat"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "entities/rmpg_acid_vat.png"
ENT.Fake = false

local R_OUT, R_IN, H, LEVEL = 45, 40, 34.6, 29
local SKELETON = "models/player/skeleton.mdl"
local UP = Vector(0, 0, 1)

-- The tub's collision: the floor and the wall in sixteen pieces, so you can jump in and stand inside
local function Hulls()
	local floor = {}
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local c, s = math.cos(a), math.sin(a)
		floor[#floor + 1] = Vector(c * R_OUT, s * R_OUT, 0)
		floor[#floor + 1] = Vector(c * R_OUT, s * R_OUT, 2.6)
	end
	local hulls = { floor }
	for i = 0, 15 do
		local piece = {}
		for _, a in ipairs({ i / 16 * math.pi * 2, (i + 1) / 16 * math.pi * 2 }) do
			for _, r in ipairs({ R_IN, R_OUT }) do
				piece[#piece + 1] = Vector(math.cos(a) * r, math.sin(a) * r, 0)
				piece[#piece + 1] = Vector(math.cos(a) * r, math.sin(a) * r, H)
			end
		end
		hulls[#hulls + 1] = piece
	end
	return hulls
end

-- Is this point inside the acid?
function ENT:InAcid(pos)
	local lp = self:WorldToLocal(pos)
	return lp.z > 1 and lp.z < LEVEL and lp.x * lp.x + lp.y * lp.y < (R_IN - 3) ^ 2
end

function ENT:Initialize()
	if SERVER then self:SetModel("models/hunter/plates/plate1x1.mdl") end
	-- the same collision on both sides, so walking into it is predicted right
	self:PhysicsInitMultiConvex(Hulls())
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:EnableCustomCollisions(true)
	local po = self:GetPhysicsObject()
	if IsValid(po) then
		po:SetMass(1500)
		po:SetMaterial("metal")
		po:EnableMotion(false)
	end
	if CLIENT then
		self:SetRenderBounds(Vector(-R_OUT - 4, -R_OUT - 4, -2), Vector(R_OUT + 4, R_OUT + 4, H + 30))
		self.Bubbles = {}
		return
	end
	self.Hidden = {}
	self.Bones = {}
	self.NextSoak = {}
	self.NextGurgle = 0
end

if SERVER then
	util.AddNetworkString("rmpg_acid_fake")

	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 1)
		e:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
		e:Spawn()
		e:Activate()
		return e
	end

	local SKIP = { rmpg_acid_vat = true, rmpg_acid_vat_fake = true, predicted_viewmodel = true, gmod_hands = true, physgun_beam = true,
		rmpg_portal = true, rmpg_boots_body = true }

	local function Living(e)
		if e:IsPlayer() then return e:Alive() end
		if e.IsLambdaPlayer then return RMPG.PersonAlive and RMPG.PersonAlive(e) end
		return (e:IsNPC() or e:IsNextBot()) and e:Health() > 0
	end

	local function Snd(name, a, b)
		return string.format(RMPG.SND[name], math.random(a, b))
	end

	local function Fizz(vat, pos)
		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetEntity(vat)
		util.Effect("rmpg_acid_fizz", ed, true, true)
		vat:EmitSound(Snd("acidSizzle", 1, 4), 75, math.random(95, 110))
	end

	-- A skeleton: in the pose of the body it was, or straight out of the hatch; it floats up to just under the top
	local function Skeleton(src, pos, ang)
		if not util.IsValidModel(SKELETON) then return end
		local rag = ents.Create("prop_ragdoll")
		if not IsValid(rag) then return end
		rag:SetModel(SKELETON)
		rag:SetPos(pos)
		rag:SetAngles(ang or angle_zero)
		rag:Spawn()
		rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		rag.RMPG_Acid = true -- the acid has had it already
		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local po = rag:GetPhysicsObjectNum(i)
			if IsValid(po) then
				if IsValid(src) then
					local b = src:LookupBone(rag:GetBoneName(rag:TranslatePhysBoneToBone(i)) or "")
					local m = b and src:GetBoneMatrix(b)
					if m then
						po:SetPos(m:GetTranslation())
						po:SetAngles(m:GetAngles())
					end
				end
				po:EnableGravity(false)
				po:SetDamping(2, 2)
				po:SetVelocity(UP * 40 + VectorRand() * 20)
				po:Wake()
			end
		end
		SafeRemoveEntityDelayed(rag, 90)
		return rag
	end

	-- The real acid
	function ENT:Soak(e, now)
		if Living(e) then
			if (self.NextSoak[e] or 0) > now then return end
			self.NextSoak[e] = now + 0.25
			local amount = e:IsPlayer() and 20 or 34
			local pos = e:GetPos()
			local lethal = amount >= e:Health()
			-- what dies in it leaves only bones: the usual corpse is hidden (cl_hud.lua, sv_bomb.lua)
			if lethal then e:SetNW2Float("RMPG_Vapor", now) end
			local d = DamageInfo()
			d:SetDamage(amount)
			d:SetDamageType(DMG_ACID)
			local att = self:GetCreator()
			d:SetAttacker(IsValid(att) and att or self)
			d:SetInflictor(self)
			d:SetDamagePosition(pos)
			e:TakeDamageInfo(d)
			Fizz(self, pos)
			local alive = IsValid(e) and (e:IsPlayer() and e:Alive() or (not e:IsPlayer() and e:Health() > 0 and not (e.IsLambdaPlayer and e.GetIsDead and e:GetIsDead())))
			if alive then
				if lethal then e:SetNW2Float("RMPG_Vapor", -100) end
				if e:IsPlayer() then e:EmitSound(Snd("acidPain", 1, 3), 75, math.random(95, 110)) end
				return
			end
			local rag = Skeleton(IsValid(e) and e or nil, pos + UP * 4, Angle(0, IsValid(e) and e:GetAngles().y or 0, 0))
			if IsValid(rag) then self.Bones[rag] = now end
			if IsValid(e) and not e:IsPlayer() and not e.IsLambdaPlayer and e:Health() > 0 then e:Remove() end
		elseif not e.RMPG_Acid and e:GetMoveType() == MOVETYPE_VPHYSICS then
			-- a prop, or a corpse, shrinks away in a hiss
			e.RMPG_Acid = true
			Fizz(self, e:WorldSpaceCenter())
			e:SetModelScale(0.05, 2.5)
			SafeRemoveEntityDelayed(e, 2.6)
		end
	end

	-- The fake acid: a scream, bones out of the hatch and a line in the chat, while the one who jumped in hides
	function ENT:FakeSoak(e, now)
		if not e:IsPlayer() or not e:Alive() or self.Hidden[e] then return end
		self.Hidden[e] = true
		e:SetNoDraw(true)
		e:DrawWorldModel(false)
		e:AddFlags(FL_NOTARGET)
		e:SetNW2Bool("RMPG_FakeAcid", true)
		e:EmitSound(Snd("acidPain", 1, 3), 85, 90)
		self:EmitSound(Snd("acidSplash", 1, 3), 80, 100)
		Fizz(self, e:GetPos())
		local rag = Skeleton(nil, self:LocalToWorld(Vector(0, 0, 8)), Angle(0, math.random(0, 359), 0))
		if IsValid(rag) then self.Bones[rag] = now end
		net.Start("rmpg_acid_fake")
		net.WriteEntity(e)
		net.Broadcast()
	end

	function ENT:Unhide(ply)
		self.Hidden[ply] = nil
		if not IsValid(ply) then return end
		ply:SetNoDraw(false)
		ply:DrawWorldModel(true)
		ply:RemoveFlags(FL_NOTARGET)
		ply:SetNW2Bool("RMPG_FakeAcid", false)
	end

	-- Bones stay just under the top for a while, then sink
	function ENT:Float(now)
		local top = self:LocalToWorld(Vector(0, 0, LEVEL - 3)).z
		for rag, t in pairs(self.Bones) do
			if not IsValid(rag) then
				self.Bones[rag] = nil
			else
				local sink = now - t > 20
				for i = 0, rag:GetPhysicsObjectCount() - 1 do
					local po = rag:GetPhysicsObjectNum(i)
					if IsValid(po) then
						if sink then
							po:EnableGravity(true)
						else
							local v = po:GetVelocity()
							po:SetVelocity(Vector(v.x * 0.9, v.y * 0.9, Lerp(0.3, v.z, (top - po:GetPos().z) * 3)))
						end
					end
				end
				if sink then self.Bones[rag] = nil end
			end
		end
	end

	function ENT:Think()
		local now = CurTime()
		local here = {}
		for _, e in ipairs(ents.FindInSphere(self:LocalToWorld(Vector(0, 0, LEVEL * 0.5)), R_OUT + 20)) do
			if IsValid(e) and not SKIP[e:GetClass()] and not IsValid(e:GetParent()) and not e:IsWeapon() then
				local p = (e:IsPlayer() or e:IsNPC() or e:IsNextBot()) and (e:GetPos() + UP * 8) or e:WorldSpaceCenter()
				if self:InAcid(p) then
					here[e] = true
					if self.Fake then self:FakeSoak(e, now) else self:Soak(e, now) end
				end
			end
		end
		for ply in pairs(self.Hidden) do
			if not here[ply] or not IsValid(ply) or not ply:Alive() then self:Unhide(ply) end
		end
		self:Float(now)
		if now >= self.NextGurgle then
			self.NextGurgle = now + math.Rand(2, 5)
			self:EmitSound(Snd("acidGurgle", 2, 8), 60, math.random(90, 110))
		end
		self:NextThink(now + 0.1)
		return true
	end

	function ENT:OnRemove()
		for ply in pairs(self.Hidden or {}) do self:Unhide(ply) end
	end

	return
end

---------------------------------------------------------------------------
-- Client: the tub, the glowing acid with its bubbles, the ACID sign, and in the fake one the BONES hatch
---------------------------------------------------------------------------

local G, GL
local function Groups()
	if not G then
		G = RMPG.Model.PartsGroup(RMPG.VatParts, 0.4)
		GL = RMPG.Model.PartsGroup({ { "lathe", { 0, 0, LEVEL }, "z", { { 0, R_IN, true }, { 0, 0, true } }, 40, "white", "liquid" } })
	end
	return G, GL
end

local ACID = Color(110, 255, 70)
local STEAM = Material("rmpg/fx_smoke")

local function LightAt(pos)
	local c = render.GetLightColor(pos)
	return math.Clamp(math.max(c.x, c.y, c.z) * 1.8 + 0.25, 0.35, 1)
end

function ENT:Frame()
	return RMPG.Model.FrameFromAngle(self:GetPos(), self:GetAngles(), 1)
end

function ENT:Draw()
	local g = Groups()
	local fr = self:Frame()
	RMPG.Model.DrawGroup(fr, g, LightAt(self:GetPos() + self:GetUp() * 20), RMPG.CL.outline:GetBool())
	-- the sign on its side: yellow, black stripes, ACID
	local spos = self:LocalToWorld(Vector(R_OUT + 0.15, 0, 18))
	local sa = self:LocalToWorldAngles(Angle(0, 90, 90))
	cam.Start3D2D(spos, sa, 0.1)
		draw.RoundedBox(8, -110, -50, 220, 100, Color(20, 20, 20))
		draw.RoundedBox(6, -104, -44, 208, 88, Color(250, 214, 40))
		draw.SimpleText(RMPG.T("acid_sign"), "RMPG_Big", 0, -4, Color(20, 20, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		for k = -3, 3 do
			surface.SetDrawColor(20, 20, 20)
			surface.DrawRect(k * 30 - 6, 30, 14, 8)
		end
	cam.End3D2D()
	if self.Fake then
		-- the BONES hatch at the bottom, seen through the acid
		local hpos = self:LocalToWorld(Vector(0, 0, 2.75))
		cam.Start3D2D(hpos, self:LocalToWorldAngles(Angle(0, 90, 0)), 0.1)
			draw.RoundedBox(10, -150, -110, 300, 220, Color(40, 46, 40))
			draw.RoundedBox(8, -140, -100, 280, 200, Color(60, 68, 60))
			draw.SimpleText("BONES", "RMPG_Big", 0, -10, Color(20, 24, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			surface.SetDrawColor(30, 34, 30)
			surface.DrawRect(-50, 50, 100, 12)
		cam.End3D2D()
	end
end

function ENT:DrawTranslucent()
	local _, gl = Groups()
	local fr = self:Frame()
	local t = CurTime()
	local M = RMPG.Mat
	local pulse = 0.9 + 0.1 * math.sin(t * 2.3 + self:EntIndex())
	M.liquid:SetVector("$color", Vector(0.42 * pulse, 1 * pulse, 0.26 * pulse))
	RMPG.Model.DrawGroupLayer(fr, gl, "liquid", M.liquid)
	M.liquid:SetVector("$color", Vector(1, 1, 1))
	-- bubbles coming up and popping, a soft glow over the top
	render.SetMaterial(M.glow)
	local top = self:LocalToWorld(Vector(0, 0, LEVEL + 0.3))
	render.DrawSprite(top + self:GetUp() * 6, R_IN * 2.4, R_IN * 1.2, Color(ACID.r, ACID.g, ACID.b, 40))
	for i = 1, 14 do
		local ph = (t * (0.35 + i * 0.03) + i * 0.618) % 1
		local a = i * 2.39996 + t * 0.2
		local r = R_IN * 0.85 * math.sqrt((i * 0.37) % 1)
		local p = self:LocalToWorld(Vector(math.cos(a) * r, math.sin(a) * r, LEVEL + 0.4))
		local s = 2 + 5 * math.sin(ph * math.pi)
		render.DrawSprite(p, s, s, Color(190, 255, 160, 200 * (1 - ph)))
	end
	if (self.NextSteam or 0) < t and RMPG.CL.particles:GetBool() and EyePos():DistToSqr(top) < 1200 * 1200 then
		self.NextSteam = t + 0.25
		local em = ParticleEmitter(top, false)
		if em then
			local a = math.random() * math.pi * 2
			local r = math.random() * R_IN * 0.8
			local p = em:Add(STEAM, self:LocalToWorld(Vector(math.cos(a) * r, math.sin(a) * r, LEVEL + 1)))
			if p then
				p:SetVelocity(self:GetUp() * math.Rand(10, 25))
				p:SetDieTime(math.Rand(1.5, 2.5))
				p:SetStartAlpha(50)
				p:SetEndAlpha(0)
				p:SetStartSize(6)
				p:SetEndSize(22)
				p:SetColor(150, 255, 120)
			end
			em:Finish()
		end
	end
end

-- Hiding in the fake acid: the world is green and you breathe through a tube. The breathing file loops by itself:
-- played every few seconds with surface.PlaySound it piled up and never stopped, so it is one sound that is stopped
local breath
hook.Add("Think", "rmpg_fake_acid_breath", function()
	local me = LocalPlayer()
	local on = IsValid(me) and me:Alive() and me:GetNW2Bool("RMPG_FakeAcid", false)
	if on and not breath then
		breath = CreateSound(me, RMPG.SND.acidBreath)
		breath:PlayEx(0.45, 100)
	elseif not on and breath then
		breath:Stop()
		breath = nil
	end
end)

hook.Add("HUDPaint", "rmpg_fake_acid", function()
	local me = LocalPlayer()
	if not IsValid(me) or not me:GetNW2Bool("RMPG_FakeAcid", false) then return end
	surface.SetDrawColor(70, 210, 50, 150)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	draw.SimpleTextOutlined(RMPG.T("acid_fake_hide"), "RMPG_BodyB", ScrW() / 2, ScrH() * 0.8, Color(225, 255, 215), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
end)

net.Receive("rmpg_acid_fake", function()
	local p = net.ReadEntity()
	if IsValid(p) then chat.AddText(Color(130, 255, 110), RMPG.T("acid_fake_chat", p:Nick())) end
end)
