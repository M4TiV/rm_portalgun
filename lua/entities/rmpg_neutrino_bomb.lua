AddCSLuaFile()

-- Neutrino bomb (file 01). E starts the countdown (E again stops it); holding the detonator, E links it instead and
-- the detonator's LMB starts every linked bomb. At zero: a violet-orange flash over half the map, a black hole
-- where it stood and the ground thrown up into the sky that comes down as burning meteorites (sv_neutrino.lua).
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.neutrino"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "entities/rmpg_neutrino_bomb.png"

local MODEL = "models/rmpg/neutrino_bomb.mdl"
local BUTTON = Vector(15.1, -6.5, 4.8) -- the red button (models/rmpg/neutrino_bomb.mdl)
local PLATE = Vector(0, 0, 16)        -- the top of the red warning plate
local UP = Vector(0, 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Linker")
	self:NetworkVar("Entity", 1, "Activator")
	self:NetworkVar("Bool", 0, "Armed")
	self:NetworkVar("Bool", 1, "Exploded")
	self:NetworkVar("Float", 0, "FuseStart")
	self:NetworkVar("Float", 1, "BlastTime") -- 0 = not counting
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

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 16)
		e:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
		e.CodeOwner = ply
		e:Spawn()
		e:Activate()
		RMPG.NbSendCodes(ply, e)
		return e
	end

	function ENT:Initialize()
		self:SetModel(MODEL)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		-- two different four-digit codes: one starts the countdown, the other stops it
		self.StartCode = string.format("%04d", math.random(0, 9999))
		repeat self.StopCode = string.format("%04d", math.random(0, 9999)) until self.StopCode ~= self.StartCode
		local po = self:GetPhysicsObject()
		if IsValid(po) then
			po:SetMass(120)
			po:Wake()
		end
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() or self:GetExploded() then return end
		local w = ply:GetActiveWeapon()
		if self:GetBlastTime() <= 0 and IsValid(w) and w:GetClass() == RMPG.DETONATOR then
			if ply ~= self.CodeOwner and not ply:IsAdmin() then
				RMPG.Notify(ply, "n_nb_not_yours", nil, 1)
				return
			end
			-- holding the detonator: link to it, or unlink
			if self:IsLinked() then
				self:SetArmed(false)
				self:SetLinker(NULL)
				self:EmitSound(RMPG.SND.bombDisarm, 70)
				RMPG.Notify(ply, "n_bomb_disarmed", nil, 0)
			else
				self:SetArmed(true)
				self:SetLinker(ply)
				self:EmitSound(RMPG.SND.bombArm, 75)
				RMPG.Notify(ply, "n_nb_linked", nil, 2)
			end
			return
		end
		-- anything else is done on its keypad, with the codes
		net.Start("rmpg_nb_pad")
		net.WriteEntity(self)
		net.Send(ply)
	end

	function ENT:Trigger(fuse, who)
		if self:GetBlastTime() > 0 or self:GetExploded() then return end
		local now = CurTime()
		fuse = fuse or RMPG.CV.nbTimer:GetFloat()
		who = IsValid(who) and who or self:GetLinker()
		self:SetActivator(who)
		self:SetFuseStart(now)
		self:SetBlastTime(now + fuse)
		self.NextBeep = now
		self:EmitSound(RMPG.SND.bombArm, 80)
		if IsValid(who) then RMPG.Notify(who, "n_nb_armed", { math.ceil(fuse) }, 3) end
	end

	function ENT:Defuse(ply)
		self:SetBlastTime(0)
		self:SetFuseStart(0)
		self:EmitSound(RMPG.SND.bombDisarm, 75)
		if self.Siren then self.Siren:Stop() self.Siren = nil end
		RMPG.Notify(ply, "n_nb_defused", nil, 0)
	end

	-- A big blast nearby sets it off too, sooner
	function ENT:OnTakeDamage(dmg)
		if dmg:IsDamageType(DMG_BLAST) and dmg:GetDamage() > 80 then self:Trigger(3, dmg:GetAttacker()) end
	end

	function ENT:Think()
		local bt = self:GetBlastTime()
		if bt > 0 and not self:GetExploded() then
			local now = CurTime()
			local _, frac = self:State()
			if now >= self.NextBeep then
				-- beeping faster and faster
				self.NextBeep = now + Lerp(frac, 1, 0.12)
				self:EmitSound(RMPG.SND.beep, 80, 90 + frac * 60)
			end
			if bt - now < 3.2 and not self.Siren then
				self.Siren = CreateSound(self, RMPG.SND.nbSiren)
				self.Siren:PlayEx(1, 100)
				util.ScreenShake(self:GetPos(), 4, 30, 3.2, 3000)
			end
			if now >= bt then self:Explode() end
		end
		self:NextThink(CurTime())
		return true
	end

	function ENT:Explode()
		if self:GetExploded() then return end
		self:SetExploded(true)
		if self.Siren then self.Siren:Stop() self.Siren = nil end
		RMPG.NeutrinoBlast(self, self:GetActivator())
		self:SetNoDraw(true)
		self:SetNotSolid(true)
		SafeRemoveEntityDelayed(self, 0.1)
	end

	function ENT:OnRemove()
		if self.Siren then self.Siren:Stop() end
	end

	return
end

---------------------------------------------------------------------------
-- Client: the blinking button, the countdown on the warning plate
---------------------------------------------------------------------------

local RED = Color(255, 40, 30)
surface.CreateFont("RMPG_NeutrinoDigits", { font = "Consolas", size = 64, weight = 900, antialias = true })

-- 0..1 how lit the button is right now
function ENT:Blink()
	local state, frac = self:State()
	if state == 0 or state == 3 then return 0 end
	if state == 1 then return 0.25 + 0.25 * math.sin(CurTime() * 3) end
	local rate = Lerp(frac, 1, 8)
	return (CurTime() - self:GetFuseStart()) * rate % 1 < 0.5 and 1 or 0.15
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:DrawTranslucent()
	local state = self:State()
	if state == 0 or state == 3 then return end
	local lit = self:Blink()
	render.SetMaterial(RMPG.Mat.glow)
	local b = self:LocalToWorld(BUTTON)
	render.DrawSprite(b, 10 + 14 * lit, 10 + 14 * lit, Color(RED.r, RED.g, RED.b, 60 + 190 * lit))
	if state ~= 2 then return end
	-- seconds left on the warning plate
	local left = math.max(self:GetBlastTime() - CurTime(), 0)
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ang:Up(), 90)
	cam.Start3D2D(self:LocalToWorld(PLATE + Vector(0, 0, 0.1)), ang, 0.06)
		draw.RoundedBox(6, -60, -36, 120, 72, Color(10, 0, 0, 220))
		draw.SimpleText(string.format(left < 10 and "%.1f" or "%d", left), "RMPG_NeutrinoDigits", 0, 0, Color(255, 60 + 120 * lit, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end

function ENT:Think()
	local state = self:State()
	if state ~= 2 then return end
	local dl = DynamicLight(self:EntIndex())
	if dl then
		local lit = self:Blink()
		dl.pos = self:LocalToWorld(BUTTON) + UP * 4
		dl.r, dl.g, dl.b = RED.r, RED.g, RED.b
		dl.brightness = lit > 0.5 and 2 or 0
		dl.size = lit > 0.5 and 220 or 0
		dl.decay = 4000
		dl.dietime = CurTime() + 0.1
	end
end
