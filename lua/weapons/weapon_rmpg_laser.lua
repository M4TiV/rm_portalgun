AddCSLuaFile()

-- Rick's laser gun: no ammo - it overheats instead. 18 shots in a row and it has to cool down for a couple of
-- seconds (it cools by itself between shots too). LMB fires as long as it is held. RMB is the other attack: hold it and it
-- builds up a charge like the Gauss gun, let go and a heavy beam goes through walls and bodies, bounces at a glancing
-- angle and throws you back; hold it too long and it overloads. First person uses the HL2 pistol hands with the pistol
-- hidden and our gun (models/rmpg/laser_gun.mdl, built on the hand bone) bonemerged onto the hand.
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("laser_name") or "Rick's Laser Gun"
SWEP.Author = "Rick Sanchez (C-137)"
SWEP.Purpose = "Pew pew. Mind the heat."
SWEP.Instructions = "LMB - fire, hold RMB - charge, let go - heavy shot"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.IconOverride = "entities/weapon_rmpg_laser.png"

SWEP.Slot = 1
SWEP.SlotPos = 8
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/rmpg/laser_gun.mdl"
SWEP.ViewModelFOV = 56
SWEP.UseHands = true
SWEP.HoldType = "pistol"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local DELAY = 0.16
local SEGMENTS = 5    -- how many pieces a charged beam can be: through walls, bodies and bounces
local COOL_RATE = 0.7 -- heat lost per second between bursts
local MUZZLE = Vector(14.4, -1.5, -4.12) -- the orange cup in the hand bone's space (models/rmpg/laser_gun.mdl)
local RED = Color(255, 60, 40)

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "Heat")      -- heat right after the last shot, 0..1
	self:NetworkVar("Float", 1, "LastShot")
	self:NetworkVar("Float", 2, "CoolUntil") -- overheated until then
	self:NetworkVar("Float", 3, "ChargeStart") -- charging since then, 0 = not charging
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW)
	return true
end

-- Where the shots start and go: the eyes, or in VR the gun's cup in the right hand along the barrel
function SWEP:AimRay()
	local ply = self:GetOwner()
	local pos, ang = RMPG.VRHand(ply)
	if pos then return LocalToWorld(MUZZLE, angle_zero, pos, ang), ang:Forward() end
	return ply:GetShootPos(), ply:GetAimVector()
end

-- How hot it is now (0..1): from the last shot it cools by itself; overheated it counts down to cold
function SWEP:CurHeat()
	local now = CurTime()
	local cool = self:GetCoolUntil()
	if now < cool then return math.Clamp((cool - now) / math.max(RMPG.CV.laserCool:GetFloat(), 0.1), 0, 1) end
	if cool > self:GetLastShot() then return 0 end
	return math.max(0, self:GetHeat() - math.max(0, now - self:GetLastShot() - 0.25) * COOL_RATE)
end

function SWEP:Overheated()
	return CurTime() < self:GetCoolUntil()
end

function SWEP:PredSound(snd, lvl, pitch)
	if CLIENT and (game.SinglePlayer() or not IsFirstTimePredicted()) then return end
	self:EmitSound(snd, lvl or 75, pitch or 100)
end

-- 0..1 how full the charge is
function SWEP:ChargeFrac()
	local s = self:GetChargeStart()
	if s <= 0 then return 0 end
	return math.Clamp((CurTime() - s) / math.max(RMPG.CV.laserChargeT:GetFloat(), 0.1), 0, 1)
end

function SWEP:StopChargeSound()
	if SERVER and self.ChargeLoop then self.ChargeLoop:Stop() end
end

-- The steam of an overheated gun: the file loops by itself, so it is a sound patch that is stopped when the gun is cool
-- again (played with EmitSound it never ended)
function SWEP:StopSteam()
	if SERVER and self.SteamLoop then self.SteamLoop:Stop() end
end

-- Put away, dropped, removed or its owner dead: every sound of the gun stops at once
local SOUNDS = { "laserFire", "laserBig", "laserDry", "laserOverheat", "laserCharge", "beep" }
function SWEP:StopAllSounds()
	self:StopChargeSound()
	self:StopSteam()
	self.CoolSoundAt = nil
	for _, k in ipairs(SOUNDS) do
		if RMPG.SND[k] then self:StopSound(RMPG.SND[k]) end
	end
	for i = 1, 3 do self:StopSound(string.format(RMPG.SND.laserZap, i)) end
end

function SWEP:Overheat(now)
	-- too hot: it has to cool down
	self:SetCoolUntil(now + RMPG.CV.laserCool:GetFloat())
	self:SetNextPrimaryFire(now + RMPG.CV.laserCool:GetFloat())
	self:SetNextSecondaryFire(now + RMPG.CV.laserCool:GetFloat())
	if SERVER then
		self.SteamLoop = self.SteamLoop or CreateSound(self, RMPG.SND.laserOverheat)
		self.SteamLoop:Stop()
		self.SteamLoop:PlayEx(0.55, 110)
	end
	self.CoolSoundAt = now + RMPG.CV.laserCool:GetFloat()
	timer.Simple(0.15, function()
		if IsValid(self) and IsValid(self:GetOwner()) and self:GetOwner():GetActiveWeapon() == self then self:SendWeaponAnim(ACT_VM_RELOAD) end
	end)
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	if not IsValid(ply) or self:GetChargeStart() > 0 then return end
	if self:Overheated() then
		self:SetNextPrimaryFire(CurTime() + 0.3)
		self:PredSound(RMPG.SND.laserDry, 60, 110)
		return
	end
	self:SetNextPrimaryFire(CurTime() + DELAY)
	local now = CurTime()
	local heat = self:CurHeat() + 1 / math.max(RMPG.CV.laserShots:GetInt(), 1)
	self:SetHeat(math.min(heat, 1))
	self:SetLastShot(now)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	ply:SetAnimation(PLAYER_ATTACK1)
	self:PredSound(RMPG.SND.laserFire, 75, math.random(135, 150))

	local spread = 0.012
	local src, dir = self:AimRay()
	ply:LagCompensation(true)
	ply:FireBullets({
		Num = 1, Src = src, Dir = dir, Spread = Vector(spread, spread, 0),
		Tracer = 0, Force = 2, Damage = RMPG.CV.laserDamage:GetFloat(), AmmoType = "Pistol",
		Callback = function(att, tr, dmg)
			dmg:SetDamageType(bit.bor(DMG_ENERGYBEAM, DMG_BULLET))
			if SERVER and tr.HitWorld then util.Decal("FadingScorch", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal) end
			if CLIENT and not IsFirstTimePredicted() then return end
			local ed = EffectData()
			ed:SetOrigin(tr.HitPos)
			ed:SetNormal(tr.HitNormal)
			ed:SetEntity(self)
			ed:SetStart(src)
			util.Effect("rmpg_laser", ed)
		end,
	})
	ply:LagCompensation(false)
	if not ply:IsNPC() and (not CLIENT or IsFirstTimePredicted()) then
		ply:ViewPunch(Angle(-0.8, math.Rand(-0.3, 0.3), 0))
	end

	if heat >= 1 then self:Overheat(now) end
end

-- RMB down: the charge starts; letting go fires it (SWEP:Charging)
function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.2)
	if self:GetChargeStart() > 0 then return end
	if self:Overheated() then
		self:PredSound(RMPG.SND.laserDry, 60, 110)
		return
	end
	self:SetChargeStart(CurTime())
	if SERVER then
		self.ChargeLoop = self.ChargeLoop or CreateSound(self, RMPG.SND.laserCharge)
		self.ChargeLoop:PlayEx(0.6, 70)
		self.ChargeLoop:ChangePitch(190, RMPG.CV.laserChargeT:GetFloat())
	end
end

-- The beam of a charged shot lands: a small burst that spares the one who fired
local function Burst(self, ply, pos, radius, damage)
	for _, e in ipairs(ents.FindInSphere(pos, radius)) do
		if e ~= ply and e ~= self and (e:IsPlayer() or e:IsNPC() or e:IsNextBot() or IsValid(e:GetPhysicsObject())) then
			local c = e:WorldSpaceCenter()
			if not util.TraceLine({ start = pos, endpos = c, mask = MASK_SOLID_BRUSHONLY }).Hit then
				local d = DamageInfo()
				d:SetDamage(damage * (1 - math.min(pos:Distance(c) / radius, 1) * 0.6))
				d:SetDamageType(bit.bor(DMG_ENERGYBEAM, DMG_BLAST))
				d:SetAttacker(ply)
				d:SetInflictor(self)
				d:SetDamagePosition(pos)
				d:SetDamageForce((c - pos):GetNormalized() * damage * 300)
				e:TakeDamageInfo(d)
			end
		end
	end
end

-- One straight piece of a charged beam: the bullet, the picture, the burst. Returns the trace.
local function Piece(self, ply, src, dir, damage, k, first, ignore)
	local filter = { ply, ignore }
	local tr = util.TraceLine({ start = src, endpos = src + dir * 32768, filter = filter, mask = MASK_SHOT })
	ply:FireBullets({
		Num = 1, Src = src, Dir = dir, Spread = vector_origin, IgnoreEntity = ignore,
		Tracer = 0, Force = 6 + 30 * k, Damage = damage, AmmoType = "Pistol",
		Callback = function(att, t, dmg)
			dmg:SetDamageType(bit.bor(DMG_ENERGYBEAM, DMG_BULLET))
			if t.HitWorld then util.Decal("Scorch", t.HitPos + t.HitNormal, t.HitPos - t.HitNormal) end
		end,
	})
	local ed = EffectData()
	ed:SetOrigin(tr.HitPos)
	ed:SetNormal(tr.HitNormal)
	ed:SetEntity(first and self or NULL)
	ed:SetStart(src)
	ed:SetMagnitude(math.max(k, 0.01))
	util.Effect("rmpg_laser", ed, true, true)
	if tr.Hit and not tr.HitSky then Burst(self, ply, tr.HitPos, 24 + 56 * k, damage * 0.3) end
	return tr
end

-- From the gun on: bodies are passed through, walls are punched if thin enough, a glancing hit bounces (like the Gauss gun)
local function ChargedBeam(self, ply, k)
	local src, dir = self:AimRay()
	local d0, d1 = RMPG.CV.laserDamage:GetFloat(), RMPG.CV.laserChargeD:GetFloat()
	local damage = Lerp(k, d0, math.max(d0, d1))
	local pierce = RMPG.CV.laserPierce:GetBool()
	local ignore
	ply:LagCompensation(true)
	for n = 1, SEGMENTS do
		local tr = Piece(self, ply, src, dir, damage, k, n == 1, ignore)
		if not pierce or not tr.Hit or tr.HitSky or k < 0.25 then break end
		ignore = nil
		if IsValid(tr.Entity) and not tr.HitWorld then
			-- through whatever it was
			ignore = tr.Entity
			src = tr.HitPos
			damage = damage * 0.7
		else
			local along = dir:Dot(tr.HitNormal)
			if along > -0.5 then
				-- a glancing hit: off the wall it goes
				dir = dir - tr.HitNormal * (2 * along)
				src = tr.HitPos + tr.HitNormal
				damage = damage * (1 + along)
			else
				-- straight on: through it, if it ends soon enough
				local reach = 8 + 56 * k
				local inside = util.TraceLine({ start = tr.HitPos + dir, endpos = tr.HitPos + dir * reach, mask = MASK_SOLID_BRUSHONLY })
				if inside.AllSolid then break end
				local thick = inside.StartSolid and reach * inside.FractionLeftSolid or 0
				src = tr.HitPos + dir * (thick + 2)
				damage = damage * (1 - thick / (reach * 2))
				Burst(self, ply, src, 24 + 56 * k, damage * 0.3)
			end
		end
		if damage < 5 then break end
	end
	ply:LagCompensation(false)
end

function SWEP:FireCharged()
	local ply = self:GetOwner()
	local k = self:ChargeFrac()
	local now = CurTime()
	self:SetChargeStart(0)
	self:StopChargeSound()
	self:SetNextPrimaryFire(now + 0.35 + 0.35 * k)
	self:SetNextSecondaryFire(now + 0.35 + 0.35 * k)
	local heat = math.min(self:CurHeat() + 0.2 + 0.5 * k, 1)
	self:SetHeat(heat)
	self:SetLastShot(now)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	ply:SetAnimation(PLAYER_ATTACK1)
	self:PredSound(RMPG.SND.laserFire, 85, 100 - 35 * k)
	self:PredSound(RMPG.SND.laserBig, 75 + 10 * k, 130 - 30 * k)
	if not CLIENT or IsFirstTimePredicted() then ply:ViewPunch(Angle(-2 - 9 * k, math.Rand(-1, 1), 0)) end
	if SERVER then
		ChargedBeam(self, ply, k)
		-- the push: aimed at the floor it is a jump
		ply:SetVelocity(ply:GetAimVector() * -(RMPG.CV.laserKick:GetFloat() * k))
	end
	if heat >= 1 then self:Overheat(now) end
end

function SWEP:Overload()
	local ply = self:GetOwner()
	local now = CurTime()
	self:SetChargeStart(0)
	self:StopChargeSound()
	self:SetHeat(1)
	self:SetLastShot(now)
	self:Overheat(now)
	ply:ViewPunch(Angle(-6, math.Rand(-4, 4), math.Rand(-4, 4)))
	if CLIENT then return end
	ply:EmitSound(string.format(RMPG.SND.laserZap, math.random(1, 3)), 80, 90)
	local ed = EffectData()
	ed:SetOrigin(ply:GetShootPos() + ply:GetAimVector() * 16)
	util.Effect("StunstickImpact", ed, true, true)
	local d = DamageInfo()
	d:SetDamage(RMPG.CV.laserOverDmg:GetFloat())
	d:SetDamageType(DMG_SHOCK)
	d:SetAttacker(ply)
	d:SetInflictor(self)
	d:SetDamagePosition(ply:GetShootPos())
	ply:TakeDamageInfo(d)
	RMPG.Notify(ply, "n_laser_overload", nil, 1)
end

-- Runs on both sides: while the charge builds up, letting go of RMB fires it
function SWEP:Charging()
	local ply = self:GetOwner()
	if not IsValid(ply) or not ply:IsPlayer() or self:GetChargeStart() <= 0 then return end
	if not ply:KeyDown(IN_ATTACK2) then
		self:FireCharged()
		return
	end
	local now = CurTime()
	self:SetLastShot(now) -- it does not cool while it is charging
	self:SetNextPrimaryFire(now + 0.1)
	local over = RMPG.CV.laserOverload:GetFloat()
	if over > 0 and now >= self:GetChargeStart() + RMPG.CV.laserChargeT:GetFloat() + over then self:Overload() end
end

function SWEP:Think()
	self:Charging()
	if self.CoolSoundAt and CurTime() >= self.CoolSoundAt then
		self.CoolSoundAt = nil
		self:StopSteam()
		self:PredSound(RMPG.SND.beep, 60, 130)
	end
end

if SERVER then
	-- Switching away or dying drops the charge, and nothing of the gun goes on sounding
	function SWEP:Holster()
		self:SetChargeStart(0)
		self:StopAllSounds()
		return true
	end

	function SWEP:OnRemove()
		self:StopAllSounds()
	end

	function SWEP:OnDrop()
		self:Holster()
	end

	function SWEP:OwnerChanged()
		self:StopAllSounds()
	end

	hook.Add("PlayerDeath", "rmpg_laser_quiet", function(ply)
		for _, w in ipairs(ply:GetWeapons()) do
			if IsValid(w) and w:GetClass() == "weapon_rmpg_laser" then w:StopAllSounds() end
		end
	end)

	return
end

---------------------------------------------------------------------------
-- Client: our gun on the hands, the glowing hot cup, steam and the heat bar
---------------------------------------------------------------------------

local INVIS = CreateMaterial("rmpg_invisible_laser", "UnlitGeneric", {
	["$translucent"] = 1,
	["$alpha"] = 0,
	["$vertexalpha"] = 1,
})
local STEAM = Material("rmpg/fx_smoke")

function SWEP:VMGun(vm)
	local g = self.VMGunEnt
	if not IsValid(g) then
		g = ClientsideModel(self.WorldModel, RENDERGROUP_OPAQUE)
		if not IsValid(g) then return end
		g:SetNoDraw(true)
		g:AddEffects(EF_BONEMERGE)
		self.VMGunEnt = g
	end
	if g:GetParent() ~= vm then
		g:SetParent(vm)
		g:AddEffects(EF_BONEMERGE)
	end
	return g
end

function SWEP:OnRemove()
	if IsValid(self.VMGunEnt) then self.VMGunEnt:Remove() end
	self:StopAllSounds()
end

function SWEP:Holster()
	if IsValid(self.VMGunEnt) then self.VMGunEnt:Remove() end
	self:SetChargeStart(0)
	self:StopAllSounds()
	return true
end

-- A little further from the eye, so the gun does not fill the view
function SWEP:GetViewModelPosition(pos, ang)
	return pos + ang:Forward() * 3, ang
end

function SWEP:PreDrawViewModel(vm)
	-- hide the pistol, keep the animated hands
	render.ModelMaterialOverride(INVIS)
end

-- Where the shot leaves the gun: the cup of our gun on the viewmodel in first person, on the hand otherwise
function SWEP:MuzzlePos()
	local ply = self:GetOwner()
	if not IsValid(ply) then return self:GetPos() end
	-- the viewmodel only when the camera really is at your eyes: with a third-person addon the viewmodel's cup turned
	-- into a point in front of the camera, and the beam ran from there across the screen
	if RMPG.FirstPerson(ply) then
		local vm = ply:GetViewModel()
		local b = IsValid(vm) and vm:LookupBone("ValveBiped.Bip01_R_Hand")
		local m = b and vm:GetBoneMatrix(b)
		if m then return RMPG.VMToWorld(LocalToWorld(MUZZLE, angle_zero, m:GetTranslation(), m:GetAngles()), self.ViewModelFOV) end
		return ply:GetShootPos() + ply:GetAimVector() * 24 - ply:EyeAngles():Up() * 4
	end
	local vp, va = RMPG.VRHand(ply)
	if vp then return LocalToWorld(MUZZLE, angle_zero, vp, va) end
	local b = ply:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = b and ply:GetBoneMatrix(b)
	if m then return LocalToWorld(MUZZLE, angle_zero, m:GetTranslation(), m:GetAngles()) end
	return ply:GetShootPos()
end

local function HotCup(self, pos, scale)
	local heat = self:CurHeat()
	local charge = self:ChargeFrac()
	local charging = self:GetChargeStart() > 0
	local t = CurTime() - self:GetLastShot()
	local flash = (t < 0.06 and not charging) and 1 or 0
	if heat <= 0.05 and flash == 0 and not charging then return end
	render.SetMaterial(RMPG.Mat.glow)
	local s = (4 + 10 * heat + 14 * flash) * scale
	render.DrawSprite(pos, s, s, Color(255, 90 + 120 * (1 - heat), 50, 120 + 135 * math.max(heat, flash)))
	if charging then
		-- the charge gathers in the cup and trembles more and more
		local pulse = 1 + math.sin(CurTime() * (14 + 26 * charge)) * 0.14 * charge
		local b = (6 + 34 * charge) * pulse * scale
		render.DrawSprite(pos, b, b, Color(255, 70, 40, 90 + 165 * charge))
		render.DrawSprite(pos, b * 0.45, b * 0.45, Color(255, 235, 220, 120 + 135 * charge))
	end
end

function SWEP:PostDrawViewModel(vm)
	render.ModelMaterialOverride()
	local g = self:VMGun(vm)
	if IsValid(g) then g:DrawModel() end
	local b = vm:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = b and vm:GetBoneMatrix(b)
	if m then HotCup(self, LocalToWorld(MUZZLE, angle_zero, m:GetTranslation(), m:GetAngles()), 0.4) end
end

hook.Add("PreDrawPlayerHands", "rmpg_laser_hands", function(hands, vm, ply, wep)
	if IsValid(wep) and wep:GetClass() == "weapon_rmpg_laser" then render.ModelMaterialOverride() end
end)

function SWEP:DrawWorldModel()
	self:DrawModel()
	if IsValid(self:GetOwner()) then
		render.SetMaterial(RMPG.Mat.glow)
		HotCup(self, self:MuzzlePos(), 1)
	end
end

-- Steam off the cup while it cools down
function SWEP:Think()
	self:Charging()
	if self.CoolSoundAt and CurTime() >= self.CoolSoundAt then self.CoolSoundAt = nil end
	if not self:Overheated() or (self.NextSteam or 0) > RealTime() or not RMPG.CL.particles:GetBool() then return end
	self.NextSteam = RealTime() + 0.06
	local pos = self:MuzzlePos()
	local em = ParticleEmitter(pos, false)
	if not em then return end
	local p = em:Add(STEAM, pos)
	if p then
		p:SetVelocity(Vector(0, 0, 30) + VectorRand() * 10)
		p:SetDieTime(0.9)
		p:SetStartAlpha(90)
		p:SetEndAlpha(0)
		p:SetStartSize(1.5)
		p:SetEndSize(8)
		p:SetRoll(math.Rand(0, 360))
		p:SetColor(235, 240, 245)
	end
	em:Finish()
end

function SWEP:DrawHUD()
	if not RMPG.CL.hud:GetBool() then return end
	local w, h = 260, 64
	local x, y = ScrW() - w - 28, ScrH() - h - 28
	local heat = self:CurHeat()
	local hot = self:Overheated()
	local col = hot and RED or Color(Lerp(heat, 120, 255), Lerp(heat, 220, 120), Lerp(heat, 255, 60))
	RMPG.HoloBox(x, y, w, h, Color(14, 10, 8, 215), col)
	RMPG.HoloText(hot and RMPG.T("laser_overheat") or RMPG.T("laser_heat"), "RMPG_SmallB", x + 14, y + 10, hot and RED or Color(220, 200, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	RMPG.HoloText(math.floor(heat * 100) .. "%", "RMPG_Head", x + w - 14, y + 6, Color(255, 240, 225), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	local segs, bx, by = 18, x + 14, y + 34
	local bw = (w - 28) / segs
	for k = 0, segs - 1 do
		local on = (k + 0.5) / segs <= heat
		surface.SetDrawColor(on and Color(Lerp(k / segs, 120, 255), Lerp(k / segs, 220, 60), Lerp(k / segs, 255, 40)) or Color(40, 26, 20, 230))
		surface.DrawRect(bx + k * bw, by, bw - 3, 12)
	end
	if self:GetChargeStart() > 0 then
		-- the charge, right under the crosshair where it is watched
		local charge = self:ChargeFrac()
		local cw, cx, cy = 220, ScrW() / 2 - 110, ScrH() * 0.6
		local full = charge >= 1
		draw.SimpleText(RMPG.T("laser_charge") .. "  " .. math.floor(charge * 100) .. "%", "RMPG_SmallB", ScrW() / 2, cy - 12, full and RED or Color(255, 220, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(40, 16, 12, 220)
		surface.DrawRect(cx, cy, cw, 10)
		surface.SetDrawColor(full and math.sin(RealTime() * 18) > 0 and color_white or RED)
		surface.DrawRect(cx, cy, cw * charge, 10)
	end
	if hot and math.sin(RealTime() * 12) > 0 then
		draw.SimpleText(RMPG.T("laser_cooling"), "RMPG_BodyB", ScrW() / 2, ScrH() * 0.62, RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function SWEP:DrawWeaponSelection(x, y, w, h, a)
	self.IconMat = self.IconMat or Material(self.IconOverride, "smooth")
	local s = math.min(w, h) * 0.85
	surface.SetMaterial(self.IconMat)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawTexturedRect(x + w / 2 - s / 2, y + h / 2 - s / 2, s, s)
end
