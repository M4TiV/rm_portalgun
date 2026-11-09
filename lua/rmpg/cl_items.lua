-- Client: what the small items share: our own model in the HL2 SLAM hands, on the hand in third person, and the list of
-- every model of the addon in the spawn menu (Spawnlists -> Rick and Morty)
RMPG = RMPG or {}

local INVIS = CreateMaterial("rmpg_invisible_items", "UnlitGeneric", {
	["$translucent"] = 1,
	["$alpha"] = 0,
	["$vertexalpha"] = 1,
})
-- All of these are in the space of the Detonator bone of c_slam.mdl, so they move with the hand (it is the LEFT hand:
-- dev/tools/slam_hand.py gives where its fingers are, hand_preview.py draws the fit). The bone's Z runs from the wrist
-- along the thing in the fist, its Y towards the thumb, its X towards the palm.
local DET_POS = Vector(9.49, 64.64, 21.68)
local DET_ANG = Vector(0, 0, 1):AngleEx(Vector(0, 1, 0))  -- antenna ahead, the button under the thumb
local SYR_POS = Vector(9.55, 65, 25.9)                    -- the thumb rest in the fist, the barrel ahead of it
local SYR_ANG = Vector(0, 0, 1):AngleEx(Vector(-1, 0, 0)) -- needle ahead: this line goes through the crosshair
local SYR_SCALE = 0.7
local SYR_GRIP = 4.2                                      -- how far behind the model's middle the fist is
local STAB = 0.55                                         -- seconds of the whole move of a syringe
local PLU_POS = Vector(9.6, 64.8, 23.7)                   -- the fist round the bottom of the body, the rest of it out ahead
local PLU_F, PLU_U = Vector(0, 1, 0), Vector(0, 0, 1)     -- seen from the side: the tinsel to the left, the dangling bit to the right
local NECK_POS = Vector(9.7, 60.98, 19.28)                -- or by the neck: the body hangs below the fist, its face to you
local NECK_F, NECK_U = Vector(0.976, -0.163, 0.163), Vector(0, 0.707, 0.707)
local PLU_SCALE = 0.52

-- These show our model instead of the detonator the hands were made for
local HELD = {
	weapon_rmpg_dna_syringe = true,
	weapon_rmpg_worm_syringe = true,
	weapon_rmpg_detonator = true,
	weapon_rmpg_plumbus = true,
	weapon_rmpg_akira = true,
	weapon_rmpg_timestop = true,
}

local function Smooth(x)
	x = math.Clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function RMPG.HideSlam()
	render.ModelMaterialOverride(INVIS)
end

hook.Add("PreDrawPlayerHands", "rmpg_item_hands", function(hands, vm, ply, wep)
	if IsValid(wep) and HELD[wep:GetClass()] then render.ModelMaterialOverride() end
end)

-- The weapon's own model as a clientside copy for the view, freed with the weapon
local function Copy(self)
	if not IsValid(self.HandProp) then
		self.HandProp = ClientsideModel(self.WorldModel, RENDERGROUP_OPAQUE)
		if not IsValid(self.HandProp) then return end
		self.HandProp:SetNoDraw(true)
		self:CallOnRemove("rmpg_hand_prop", function(w)
			if IsValid(w.HandProp) then w.HandProp:Remove() end
		end)
	end
	return self.HandProp
end

-- Where a thing placed in the Detonator bone's space is right now, or nil
local function InHand(vm, lp, la)
	local bone = vm:LookupBone("Detonator")
	local m = bone and vm:GetBoneMatrix(bone)
	if not m then return end
	return LocalToWorld(lp, la, m:GetTranslation(), m:GetAngles())
end

local function Put(e, pos, ang, skin, scale)
	e:SetPos(pos)
	e:SetAngles(ang)
	e:SetSkin(skin or 0)
	e:SetModelScale(scale or 1, 0)
	e:SetupBones()
	e:DrawModel()
end

-- How far through its move a syringe is: 0..1 and back, and whether it is going into yourself
local function Stab(self)
	local t = CurTime() - self:GetStabTime()
	if self:GetStabTime() <= 0 or t < 0 or t >= STAB then return 0, false end
	return t < 0.3 and Smooth(t / 0.16) or 1 - Smooth((t - 0.3) / (STAB - 0.3)), self:GetStabSelf()
end

-- LMB: the whole hand jabs forward
function RMPG.SyringeShift(self, pos, ang)
	local k, own = Stab(self)
	if k <= 0 or own then return pos, ang end
	return pos + ang:Forward() * (9 * k) + ang:Up() * (1.5 * k), ang
end

-- A syringe in the hand, needle at the crosshair. RMB: it turns round in the fist, into yourself.
function RMPG.DrawSyringeVM(self, vm, skin)
	render.ModelMaterialOverride()
	local e = Copy(self)
	local pos, ang = InHand(vm, SYR_POS, SYR_ANG)
	if not pos or not IsValid(e) then return end
	local k, own = Stab(self)
	if own then
		local grip = pos - ang:Forward() * SYR_GRIP
		ang:RotateAroundAxis(EyeAngles():Up(), 150 * k)
		pos = grip + ang:Forward() * SYR_GRIP
	end
	Put(e, pos, ang, skin, SYR_SCALE)
end

-- The remote in the fist, where the HL2 one is, so it follows every move of the hand
function RMPG.DrawDetonatorVM(self, vm)
	render.ModelMaterialOverride()
	local e = Copy(self)
	local pos, ang = InHand(vm, DET_POS, DET_ANG)
	if pos and IsValid(e) then Put(e, pos, ang) end
end

-- The plumbus in the fist; a squeeze squashes it and it wobbles back
function RMPG.DrawPlumbusVM(self, vm)
	render.ModelMaterialOverride()
	local e = Copy(self)
	-- changing grip, it turns over in the hand
	local rt = RealTime()
	local dt = math.min(rt - (self.GripT or rt), 0.1)
	self.GripT = rt
	self.Grip = math.Approach(self.Grip or 0, self:GetNeckGrip() and 1 or 0, dt * 5)
	local g = self.Grip * self.Grip * (3 - 2 * self.Grip)
	local ang = LerpVector(g, PLU_F, NECK_F):GetNormalized():AngleEx(LerpVector(g, PLU_U, NECK_U):GetNormalized())
	local pos
	pos, ang = InHand(vm, LerpVector(g, PLU_POS, NECK_POS), ang)
	if not pos or not IsValid(e) then return end
	local t = CurTime() - self:GetSqueezed()
	local k = self:GetSqueezed() > 0 and t < 0.8 and math.exp(-5 * t) * math.cos(t * 20) or 0
	local m = Matrix()
	m:Scale(Vector(1 + 0.16 * k, 1 - 0.3 * k, 1 - 0.1 * k))
	e:EnableMatrix("RenderMultiply", m)
	Put(e, pos, ang, 0, PLU_SCALE)
end

-- On the hand in third person, on the ground as it is
function RMPG.DrawHeld(self, skin, lift)
	self:SetSkin(skin or 0)
	local owner = self:GetOwner()
	local bone = IsValid(owner) and owner:LookupBone("ValveBiped.Bip01_R_Hand")
	local m = bone and owner:GetBoneMatrix(bone)
	if not m then
		self:DrawModel()
		return
	end
	-- like the laser gun: along the fingers, in the fist, the top away from the bone's Z
	local ang = m:GetAngles()
	ang:RotateAroundAxis(ang:Forward(), 180)
	self:SetRenderOrigin(m:GetTranslation() + m:GetForward() * 3.2 + m:GetRight() * 1.5 - m:GetUp() * 2.2 - ang:Up() * (lift or 0))
	self:SetRenderAngles(ang)
	self:DrawModel()
	self:SetRenderOrigin()
	self:SetRenderAngles()
end

hook.Add("PopulatePropMenu", "rmpg_props", function()
	local function Header(key)
		return { type = "header", text = RMPG.T(key) }
	end
	local function Add(list, models)
		for _, m in ipairs(models) do
			if util.IsValidModel("models/rmpg/" .. m .. ".mdl") then
				list[#list + 1] = { type = "model", model = "models/rmpg/" .. m .. ".mdl" }
			end
		end
	end
	local list = {}
	list[#list + 1] = Header("props_gadgets")
	Add(list, { "portalgun_classic", "portalgun_prime", "laser_gun", "fluid_flask", "energy_core", "eyepatch", "grav_boots_prop", "meeseeks_box", "shield_chip" })
	list[#list + 1] = Header("props_medical")
	Add(list, { "dna_syringe", "worm_syringe", "pill_bottle", "pill", "phoenix_tank", "plumbus", "worm_chunk", "worm_egg", "worm_nest" })
	list[#list + 1] = Header("props_bombs")
	Add(list, { "prime_bomb", "neutrino_bomb", "detonator", "rock_a", "rock_b" })
	spawnmenu.AddPropCategory("rmpg_props", "Rick and Morty", list, "icon16/bomb.png")
end)
