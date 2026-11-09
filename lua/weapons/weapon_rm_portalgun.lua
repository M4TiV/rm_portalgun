AddCSLuaFile()

SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("weapon_name") or "Portal Gun"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "Opens portals to anywhere on the map."
SWEP.Instructions = "LMB - portal, RMB - menu, R - swap flask, MMB - radial menu"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_portals" -- the spawn menu shows the portal guns first, the rest below
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Slot = 1
SWEP.SlotPos = 3
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false
SWEP.RenderGroup = RENDERGROUP_OPAQUE

SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/rmpg/portalgun_classic.mdl"
SWEP.ViewModelFOV = 56
SWEP.UseHands = true
SWEP.HoldType = "pistol"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local RELOAD_TIME = 1.6

function SWEP:SetupDataTables()
	self:NetworkVar("Int", 0, "Charges")
	self:NetworkVar("Int", 1, "Flasks")
	self:NetworkVar("Int", 2, "DestMode")
	self:NetworkVar("Int", 3, "Variant")
	self:NetworkVar("Bool", 0, "Core")
	self:NetworkVar("Float", 0, "FireTime")
	self:NetworkVar("Float", 1, "ReloadStart")
	self:NetworkVar("Float", 2, "ReloadEnd")
	self:NetworkVar("Float", 3, "EmptyTime")
	self:NetworkVar("Float", 4, "DeployTime")
	self:NetworkVar("Vector", 0, "FluidColor")
	self:NetworkVar("Vector", 1, "BodyColor") -- 0 0 0 = the model's own colour
	self:NetworkVar("String", 0, "DestLabel")
	self:NetworkVar("String", 1, "DestCode")
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	self:DrawShadow(false)
	if SERVER then
		self:SetCharges(RMPG.MaxCharges())
		self:SetFlasks(RMPG.CV.flasks:GetInt())
		self:SetFluidColor(RMPG.DEFAULT_COLOR)
		self:SetDestMode(RMPG.DEST_RANDOM)
		self:SetDestLabel("#dest_random")
		self:SetDestCode("???")
	end
end

-- Sounds from predicted code: the server plays them for everyone else, the owner's client for the owner
function SWEP:PredSound(snd, lvl, pitch)
	if CLIENT and (game.SinglePlayer() or not IsFirstTimePredicted()) then return end
	self:EmitSound(snd, lvl or 70, pitch or 100)
end

function SWEP:IsReloading()
	return self:GetReloadEnd() > 0
end

function SWEP:ReloadFraction()
	local e = self:GetReloadEnd()
	if e <= 0 then return nil end
	local s = self:GetReloadStart()
	return math.Clamp((CurTime() - s) / math.max(e - s, 0.01), 0, 1)
end

function SWEP:Deploy()
	self:SetDeployTime(CurTime())
	self:SetReloadEnd(0)
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetNextPrimaryFire(CurTime() + 0.5)
	self:PredSound(RMPG.SND.deploy, 55, 105)
	-- the flask gurgles quietly, an energy core crackles
	self:PredSound(self:GetCore() and RMPG.SND.coreHum or RMPG.SND.slosh, 45, math.random(95, 110))
	return true
end

function SWEP:Holster()
	self:SetReloadEnd(0)
	return true
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	if not IsValid(ply) or self:IsReloading() then return end

	if not self:GetCore() and self:GetCharges() <= 0 then
		self:SetNextPrimaryFire(CurTime() + 0.5)
		self:SetEmptyTime(CurTime())
		self:SendWeaponAnim(ACT_VM_DRYFIRE)
		self:PredSound(RMPG.SND.empty, 65)
		self:Reload()
		return
	end

	self:SetNextPrimaryFire(CurTime() + RMPG.CV.fireDelay:GetFloat())
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	ply:SetAnimation(PLAYER_ATTACK1)
	self:SetFireTime(CurTime())
	self:PredSound(RMPG.SND.fire, 75, math.random(96, 104))

	if SERVER then
		if RMPG.FireGun(ply, self) and not self:GetCore() then
			self:SetCharges(math.max(0, self:GetCharges() - 1))
		end
	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.35)
	if CLIENT then return end
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	if ply:KeyDown(IN_USE) then
		RMPG.ClosePortals(ply)
		RMPG.Notify(ply, "n_closed", nil, 0)
	else
		net.Start("rmpg_menu")
		net.Send(ply)
	end
end

function SWEP:Reload()
	if self:IsReloading() or self:GetCore() then return end
	if self:GetCharges() >= RMPG.MaxCharges() then return end
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	if not RMPG.CV.infinite:GetBool() and self:GetFlasks() <= 0 then
		if SERVER and (self.RMPG_NextNoFlask or 0) < CurTime() then
			self.RMPG_NextNoFlask = CurTime() + 2
			RMPG.Notify(ply, "n_no_flasks", nil, 1)
		end
		return
	end
	local t = CurTime()
	self:SetReloadStart(t)
	self:SetReloadEnd(t + RELOAD_TIME)
	self:SetNextPrimaryFire(t + RELOAD_TIME)
	ply:SetAnimation(PLAYER_RELOAD)
	self:PredSound(RMPG.SND.reloadOut, 70)
	self.RMPG_InSnd = false
end

SWEP.StartReload = SWEP.Reload

function SWEP:Think()
	local e = self:GetReloadEnd()
	if e <= 0 then return end
	local t = CurTime()
	if not self.RMPG_InSnd and t >= self:GetReloadStart() + RELOAD_TIME * 0.55 then
		self.RMPG_InSnd = true
		self:PredSound(RMPG.SND.reloadIn, 70)
	end
	if t >= e then
		self:SetReloadEnd(0)
		if SERVER then
			self:SetCharges(RMPG.MaxCharges())
			if not RMPG.CV.infinite:GetBool() then self:SetFlasks(math.max(0, self:GetFlasks() - 1)) end
		end
	end
end

if SERVER then
	function SWEP:Equip(owner)
		if not IsValid(owner) or not owner:IsPlayer() then return end
		local c = owner.RMPG_Color or Vector(owner:GetInfoNum("rmpg_fluid_r", 84), owner:GetInfoNum("rmpg_fluid_g", 255), owner:GetInfoNum("rmpg_fluid_b", 64))
		self:SetFluidColor(c)
		self:SetVariant(math.Clamp(math.floor(owner.RMPG_Variant or owner:GetInfoNum("rmpg_model", 0)), 0, RMPG.GUN_COUNT - 1))
		local custom = owner.RMPG_BodyCustom
		if custom == nil then custom = owner:GetInfoNum("rmpg_body_custom", 0) == 1 end
		if custom then
			self:SetBodyColor(owner.RMPG_Body or Vector(math.Clamp(owner:GetInfoNum("rmpg_body_r", 236), 1, 255),
				math.Clamp(owner:GetInfoNum("rmpg_body_g", 196), 1, 255), math.Clamp(owner:GetInfoNum("rmpg_body_b", 44), 1, 255)))
		else
			self:SetBodyColor(vector_origin)
		end
		RMPG.ApplyDestLabel(owner, self)
	end

	function SWEP:InstallCore()
		self:SetCore(true)
		self:SetReloadEnd(0)
		self:SetCharges(RMPG.MaxCharges())
		self:EmitSound(RMPG.SND.coreIn, 75)
		RMPG.Notify(self:GetOwner(), "n_core_installed", nil, 2)
	end

	-- Quick Portal from its key bind: exit where you aim, entrance right next to you
	function SWEP:FireQuick()
		local ply = self:GetOwner()
		if not IsValid(ply) or self:IsReloading() or CurTime() < self:GetNextPrimaryFire() then return end
		if not self:GetCore() and self:GetCharges() <= 0 then
			self:SetNextPrimaryFire(CurTime() + 0.5)
			self:EmitSound(RMPG.SND.empty, 65)
			return
		end
		self:SetNextPrimaryFire(CurTime() + RMPG.CV.fireDelay:GetFloat())
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		ply:SetAnimation(PLAYER_ATTACK1)
		self:SetFireTime(CurTime())
		self:EmitSound(RMPG.SND.fire, 75, math.random(96, 104))
		if RMPG.FireGun(ply, self, true) and not self:GetCore() then
			self:SetCharges(math.max(0, self:GetCharges() - 1))
		end
	end

	return
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------

local INVIS = CreateMaterial("rmpg_invisible", "UnlitGeneric", {
	["$translucent"] = 1,
	["$alpha"] = 0,
	["$vertexalpha"] = 1,
})

-- World units per model unit for each unit of the stock pistol's "hand to muzzle" distance:
-- keeps the gun about as long as the pistol it replaces
local SIZE = 0.052

-- First-person placement from the settings (defaults are the tuned factory position)
local function Calib()
	local cv = RMPG.CL
	return {
		scale = cv.vmScale:GetFloat(), pitch = cv.vmPitch:GetFloat(), yaw = cv.vmYaw:GetFloat(), roll = cv.vmRoll:GetFloat(),
		ox = cv.vmX:GetFloat(), oy = cv.vmY:GetFloat(), oz = cv.vmZ:GetFloat(),
	}
end

-- The middle of the fist in the right hand bone's space, and the gun in it: along the fingers' bone, its top away from Z
local HAND_FIST, HAND_ANG = Vector(2.6, -1.5, -0.64), Angle(0, 0, 180)

-- Frame that puts the variant's grip (V.grip) at palm with the gun turned to ang
local function GripFrame(palm, ang, V, s)
	local F, L, U = ang:Forward(), -ang:Right(), ang:Up()
	local G = V.grip
	return { O = palm - F * (G.x * s) - L * (G.y * s) - U * (G.z * s), F = F, L = L, U = U, s = s }
end

function SWEP:ModelVariant()
	return RMPG.Model.Variant(self:GetVariant())
end

function SWEP:DisplayLevel()
	local fn = FrameNumber()
	if self.RMPG_LvlFrame == fn then return self.RMPG_Lvl end
	self.RMPG_LvlFrame = fn
	local max = math.max(RMPG.MaxCharges(), 1)
	local cur = self:GetCore() and 1 or self:GetCharges() / max
	local rf = self:ReloadFraction()
	local target = cur
	if rf then
		if rf >= 0.5 then
			target = 1
			if not self.RMPG_Swapped then
				-- the new flask arrives full
				self.RMPG_Swapped = true
				self.RMPG_Lvl, self.RMPG_LvlV = 1, 0
			end
		end
	else
		self.RMPG_Swapped = false
	end
	local dt = math.min(FrameTime(), 0.05)
	self.RMPG_Lvl = self.RMPG_Lvl or target
	self.RMPG_LvlV = self.RMPG_LvlV or 0
	-- spring: the fluid drops and wobbles a little after every shot
	local acc = (target - self.RMPG_Lvl) * 55 - self.RMPG_LvlV * 6.5
	self.RMPG_LvlV = self.RMPG_LvlV + acc * dt
	self.RMPG_Lvl = math.Clamp(self.RMPG_Lvl + self.RMPG_LvlV * dt, 0, 1.03)
	return self.RMPG_Lvl
end

function SWEP:DialAngle()
	local code = self:GetDestCode()
	if self.RMPG_LastCode ~= code then
		self.RMPG_LastCode = code
		self.RMPG_DialTarget = (self.RMPG_DialTarget or 0) + 135
	end
	self.RMPG_Dial = Lerp(math.min(FrameTime() * 7, 1), self.RMPG_Dial or 0, self.RMPG_DialTarget or 0)
	return self.RMPG_Dial
end

-- Text for the red seven-segment display (only characters a 7-segment display can show)
function SWEP:DisplayContent()
	local d = self.RMPG_Disp or {}
	self.RMPG_Disp = d
	d.blink, d.warn, d.bar = false, false, nil
	local since = CurTime() - self:GetDeployTime()
	local rf = self:ReloadFraction()
	local max = math.max(RMPG.MaxCharges(), 1)
	local code = self:GetDestCode()
	if code == "" then code = "C-137" end
	if since >= 0 and since < 0.7 then
		d.big = "boot"
		d.small = ""
		d.bar = since / 0.7
	elseif rf then
		d.big = "FILL"
		d.small = ""
		d.blink = true
		d.bar = rf
	elseif not self:GetCore() and self:GetCharges() <= 0 then
		d.big = code
		d.small = "00"
		d.blink = true
		d.warn = true
		d.bar = 0
	else
		d.big = code
		if self:GetCore() then
			d.small = "CorE"
		else
			d.small = string.format("%02d", self:GetCharges())
			d.bar = self:GetCharges() / max
		end
	end
	return d
end

-- 0..1: how far the gun is tipped toward you while the dome is being swapped
function SWEP:ReloadTilt()
	local rf = self:ReloadFraction()
	if not rf then return 0 end
	local a = math.Clamp(rf / 0.15, 0, 1)
	local b = math.Clamp((1 - rf) / 0.15, 0, 1)
	return math.min(a * a * (3 - 2 * a), b * b * (3 - 2 * b))
end

function SWEP:FluidColor()
	local c = self:GetFluidColor()
	if c.x + c.y + c.z < 1 then return RMPG.DEFAULT_COLOR end
	return c
end

function SWEP:ClientState()
	local st = self.RMPG_St or {}
	self.RMPG_St = st
	local t = CurTime()
	st.time = t
	st.variant = self:GetVariant()
	st.color = self:FluidColor()
	local bc = self:GetBodyColor()
	st.body = (bc.x + bc.y + bc.z > 0) and bc or nil
	st.core = self:GetCore()
	st.level = self:DisplayLevel()
	st.fire = math.Clamp(1 - (t - self:GetFireTime()) / 0.35, 0, 1)
	st.reload = self:ReloadFraction()
	st.dial = self:DialAngle()
	st.outline = RMPG.CL.outline:GetBool()
	st.display = self:DisplayContent()
	st.glow = true
	st.detail = 1
	st.slosh = nil
	return st
end

local function LightAt(pos, minimum)
	local c = render.GetLightColor(pos)
	local l = math.max(c.x, c.y, c.z) * 1.8 + 0.2
	return math.Clamp(l, minimum or 0.3, 1)
end

-- Liquid surface lags behind when you turn
function SWEP:SloshVM()
	local ea = EyeAngles()
	local dt = math.max(FrameTime(), 0.001)
	local last = self.RMPG_LastEA or ea
	self.RMPG_LastEA = ea
	local dy = math.AngleDifference(ea.y, last.y) / dt
	local dp = math.AngleDifference(ea.p, last.p) / dt
	local sx, sy = self.RMPG_SlX or 0, self.RMPG_SlY or 0
	local vx, vy = self.RMPG_SlVX or 0, self.RMPG_SlVY or 0
	local tx, ty = math.Clamp(dy * 0.0007, -0.4, 0.4), math.Clamp(dp * 0.0007, -0.4, 0.4)
	vx = vx + ((tx - sx) * 70 - vx * 7) * dt
	vy = vy + ((ty - sy) * 70 - vy * 7) * dt
	sx, sy = sx + vx * dt, sy + vy * dt
	self.RMPG_SlX, self.RMPG_SlY, self.RMPG_SlVX, self.RMPG_SlVY = sx, sy, vx, vy
	local R, F = ea:Right(), ea:Forward()
	F.z = 0
	return R * sx + F * sy
end

-- Fallback view model placement (no hands): fixed to the camera with procedural animation
function SWEP:CameraFrame()
	local ply = self:GetOwner()
	local V = self:ModelVariant()
	local ep, ea = EyePos(), EyeAngles()
	local t = CurTime()
	local ang = Angle(ea.p, ea.y, ea.r)
	local off = Vector(15, -6.5, V.cam.z) -- forward, left, up

	local since = t - self:GetDeployTime()
	if since >= 0 and since < 0.5 then
		local k = 1 - (since / 0.5)
		k = k * k
		off.z = off.z - 7 * k
		ang:RotateAroundAxis(ang:Right(), -35 * k)
	end
	local kick = math.exp(-math.max(t - self:GetFireTime(), 0) * 12)
	if t - self:GetFireTime() < 1 then
		off.x = off.x - 1.4 * kick
		ang:RotateAroundAxis(ang:Right(), 9 * kick)
	end
	local w = self:ReloadTilt()
	if w > 0 then
		ang:RotateAroundAxis(ang:Forward(), -20 * w)
		ang:RotateAroundAxis(ang:Right(), 14 * w)
		ang:RotateAroundAxis(ang:Up(), 12 * w)
		off.z = off.z + 1 * w
	end
	local et = t - self:GetEmptyTime()
	if et < 0.3 then ang:RotateAroundAxis(ang:Up(), math.sin(et * 60) * 2 * (1 - et / 0.3)) end

	local speed = IsValid(ply) and ply:GetVelocity():Length2D() or 0
	local bob = math.Clamp(speed / 220, 0, 1.4)
	off.y = off.y + math.sin(t * 8.5) * 0.35 * bob
	off.z = off.z + math.abs(math.cos(t * 8.5)) * 0.4 * bob
	if IsValid(ply) and ply:IsSprinting() and speed > 60 then
		self.RMPG_Sprint = Lerp(FrameTime() * 8, self.RMPG_Sprint or 0, 1)
	else
		self.RMPG_Sprint = Lerp(FrameTime() * 8, self.RMPG_Sprint or 0, 0)
	end
	local sp = self.RMPG_Sprint
	ang:RotateAroundAxis(ang:Up(), 22 * sp)
	ang:RotateAroundAxis(ang:Right(), -14 * sp)
	off.z = off.z - 2 * sp
	ang:RotateAroundAxis(ang:Up(), 4) -- point slightly toward the crosshair

	local pos = ep + ea:Forward() * off.x - ea:Right() * off.y + ea:Up() * off.z
	return RMPG.Model.FrameFromAngle(pos, ang, V.cam.scale)
end

-- Distance from the wrist to the stock pistol's muzzle, measured once (sets the gun's size)
function SWEP:PistolLength(vm, handPos)
	if not self.RMPG_PistolLen then
		local att = vm:LookupAttachment("muzzle")
		local a = att and att > 0 and vm:GetAttachment(att)
		self.RMPG_PistolLen = a and math.Clamp((a.Pos - handPos):Length(), 5, 14) or 8.5
	end
	return self.RMPG_PistolLen
end

-- First person with hands: the gun looks where the camera looks, like any view model, and sits in
-- the palm. The stock pistol's hand animations still move it: the hand position is followed directly
-- and the hand's rotation is applied as the change from its idle pose, so the arm model's bone axes
-- never decide which way the gun points.
function SWEP:HandsFrame(vm)
	local bone = vm:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = bone and vm:GetBoneMatrix(bone)
	if not m then return nil end
	local ep, ea = EyePos(), EyeAngles()
	local relPos, relAng = WorldToLocal(m:GetTranslation(), m:GetAngles(), ep, ea)

	-- Rest pose of the hand: whenever an animation has played to its end the pistol is back in the
	-- resting pose, so that frame is remembered. Until the first one finishes the gun simply follows
	-- the camera; afterwards draw / shot / reload motion is the hand's turn away from the rest pose.
	local nowM = Matrix()
	nowM:SetAngles(relAng)
	if vm:GetCycle() >= 0.98 then self.RMPG_RestInv = nowM:GetInverseTR() end
	local D = self.RMPG_RestInv and (nowM * self.RMPG_RestInv) or Matrix()

	local V = self:ModelVariant()
	local cal = Calib()
	local w = self:ReloadTilt()
	local base = Matrix()
	-- straight ahead, a touch toward the crosshair; tipped toward you while the dome is swapped
	base:SetAngles(Angle(cal.pitch - 14 * w, 3 + cal.yaw + 12 * w, cal.roll - 20 * w))
	local _, gunAng = LocalToWorld(vector_origin, (D * base):GetAngles(), ep, ea)
	-- the fist is a little in front of the wrist, and turns with the hand
	local palmCam = relPos + D * Vector(V.palm.ahead + cal.ox * 0.4, cal.oy * 0.4, V.palm.up + cal.oz * 0.4 + 0.6 * w)
	local palm = LocalToWorld(palmCam, angle_zero, ep, ea)
	local s = SIZE * self:PistolLength(vm, m:GetTranslation()) * cal.scale * (V.size or 1)
	return GripFrame(palm, gunAng, V, s)
end

-- No muzzle flashes, shell casings or sounds from the hidden stock pistol animations
function SWEP:FireAnimationEvent()
	return true
end

function SWEP:PreDrawViewModel(vm)
	-- hide the stock pistol, keep the animated hands
	render.ModelMaterialOverride(INVIS)
end

function SWEP:PostDrawViewModel(vm)
	render.ModelMaterialOverride()
	if not RMPG.Model then return end
	-- VRMod puts the viewmodel in the hand in the world: there the gun is drawn in the hand, as other players see it
	if RMPG.VRHand(LocalPlayer()) then
		local wf = self:WorldFrame()
		local st = self:ClientState()
		st.light = LightAt(wf.O, 0.4)
		RMPG.Model.DrawGun(wf, st)
		RMPG.ResetTints()
		self.RMPG_WorldTip = RMPG.Model.ToWorld(wf, self:ModelVariant().tip)
		return
	end
	local fr
	if RMPG.CL.hands:GetBool() then fr = self:HandsFrame(vm) end
	self.RMPG_UsingHands = fr ~= nil
	fr = fr or self:CameraFrame()
	if not fr then return end
	local st = self:ClientState()
	st.light = LightAt(EyePos(), 0.5)
	st.slosh = self:SloshVM()
	RMPG.Model.DrawGun(fr, st)
	RMPG.ResetTints()
	RMPG.VMTip = RMPG.VMToWorld(RMPG.Model.ToWorld(fr, self:ModelVariant().tip), self.ViewModelFOV)
	RMPG.VMTipTime = CurTime()
end

hook.Add("PreDrawPlayerHands", "rmpg_hands", function(hands, vm, ply, wep)
	if IsValid(wep) and wep:GetClass() == "weapon_rm_portalgun" then
		render.ModelMaterialOverride()
		if not RMPG.CL.hands:GetBool() or wep.RMPG_UsingHands == false then return true end
	end
end)

function SWEP:WorldFrame()
	local owner = self:GetOwner()
	local V = self:ModelVariant()
	-- VRMod: in the right hand of the player in VR, whatever their model's bones are doing
	local vp, va = RMPG.VRHand(owner)
	if vp then
		local pos, ang = LocalToWorld(HAND_FIST, HAND_ANG, vp, va)
		ang:RotateAroundAxis(ang:Right(), V.handTilt or 0)
		return GripFrame(pos, ang, V, 0.42 * (V.size or 1))
	end
	if IsValid(owner) then
		local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
		local m = bone and owner:GetBoneMatrix(bone)
		if m then
			-- third person: the grip in the fist, whatever the hand is doing (dev/tools/gun_preview.py draws the fit)
			local pos, ang = LocalToWorld(HAND_FIST, HAND_ANG, m:GetTranslation(), m:GetAngles())
			ang:RotateAroundAxis(ang:Right(), V.handTilt or 0)
			return GripFrame(pos, ang, V, 0.42 * (V.size or 1))
		end
	end
	-- dropped on the ground: drawn exactly over the physics of models/rmpg/portalgun_classic.mdl
	return RMPG.Model.FrameFromAngle(self:GetPos(), self:GetAngles(), 0.45 * (V.size or 1))
end

function SWEP:DrawWorldModel()
	if not RMPG.Model then self:DrawModel() return end
	local fr = self:WorldFrame()
	local st = self:ClientState()
	local dist = EyePos():DistToSqr(fr.O)
	st.light = LightAt(fr.O, 0.25)
	if dist > 250 * 250 then st.display = nil end
	st.outline = st.outline and dist < 500 * 500
	st.detail = dist < 400 * 400 and 1 or 0
	RMPG.Model.DrawGun(fr, st)
	RMPG.ResetTints()
	self.RMPG_WorldTip = RMPG.Model.ToWorld(fr, self:ModelVariant().tip)
end

function SWEP:DrawHUD()
	if RMPG.DrawGunHUD then RMPG.DrawGunHUD(self) end
end

function SWEP:DoDrawCrosshair(x, y)
	if RMPG.DrawCrosshair then return RMPG.DrawCrosshair(self, x, y) end
end

-- Weapon selection: the animated icon (30 frames, 8 per row in a 2048 x 1024 sheet)
local ICON_ANIM = Material("rmpg/icon_anim.png", "smooth")
function SWEP:DrawWeaponSelection(x, y, w, h, alpha)
	local size = math.min(w, h) * 0.95
	local i = math.floor(RealTime() * 10) % 30
	local u0, v0 = (i % 8) * 0.125, math.floor(i / 8) * 0.25
	surface.SetMaterial(ICON_ANIM)
	surface.SetDrawColor(255, 255, 255, alpha)
	surface.DrawTexturedRectUV(x + w / 2 - size / 2, y + h / 2 - size / 2, size, size, u0, v0, u0 + 0.125, v0 + 0.25)
end

function SWEP:TipPosition()
	local owner = self:GetOwner()
	if RMPG.FirstPerson(owner) and RMPG.VMTip and CurTime() - (RMPG.VMTipTime or 0) < 0.5 then
		return RMPG.VMTip
	end
	return self.RMPG_WorldTip or (IsValid(owner) and owner:GetShootPos()) or self:GetPos()
end
