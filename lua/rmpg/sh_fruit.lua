-- Turning into a potato or a watermelon (W.I.P; the pickle is kept in dev/wip for now, RMPG.WIP_PICKLE).
-- Stab a fruit with the DNA syringe (LMB) and inject yourself (RMB):
-- you become that fruit with your own head, small, on its side. The view goes to third person, the fruit rolls as you
-- move and only hops a little, you cannot use weapons (like a prop in Prop Hunt). Hold E for a second to be yourself
-- again; dying does it too, and leaves the fruit lying there. The pickle and the potato are rmpg_fruit_* entities, the
-- watermelon is the game's own (models/props_junk/watermelon01.mdl).
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local MELON = "models/props_junk/watermelon01.mdl"

-- r: how high the fruit's middle is when it lies on the ground; hull: the player's box; scale: the player model (its
-- hitboxes shrink with it); face: where the head sits in the fruit's own space (p), which way the face looks (n) and
-- which way the top of the head points (t)
RMPG.FRUITS = {
	pickle = { r = 5.4, hull = 6, height = 11, scale = 0.16, class = "rmpg_fruit_pickle",
		face = { p = Vector(1.5, -4.9, 1.4), n = Vector(0, -1, 0.15), t = Vector(1, 0, 0) } },
	potato = { r = 5.8, hull = 6.5, height = 11, scale = 0.15, class = "rmpg_fruit_potato",
		face = { p = Vector(0.5, -5.9, 0.4), n = Vector(0, -1, 0.1), t = Vector(0, 0, 1) } },
	melon = { r = 6.2, hull = 7, height = 13, scale = 0.18, model = MELON,
		face = { p = Vector(0, -6.4, 0.5), n = Vector(0, -1, 0.1), t = Vector(0, 0, 1) } },
}
if not RMPG.WIP_PICKLE then RMPG.FRUITS.pickle = nil end

function RMPG.FruitOf(ply)
	return IsValid(ply) and ply:GetNW2String("RMPG_Fruit", "") or ""
end

-- What kind of fruit an entity is, if it is one
function RMPG.FruitKind(e)
	if not IsValid(e) then return end
	if e.RMPG_FruitKind then return e.RMPG_FruitKind end
	if e:GetModel() == MELON then return "melon" end
end

-- The body of a fruit (and back): small box, small model, slow, small hops. Runs on both sides, from the networked kind
local function Apply(ply, kind)
	local F = RMPG.FRUITS[kind]
	if F then
		if not ply.RMPG_FruitSave then
			ply.RMPG_FruitSave = { walk = ply:GetWalkSpeed(), run = ply:GetRunSpeed(), jump = ply:GetJumpPower() }
		end
		ply:SetModelScale(F.scale, 0)
		local mins, maxs = Vector(-F.hull, -F.hull, 0), Vector(F.hull, F.hull, F.height)
		ply:SetHull(mins, maxs)
		ply:SetHullDuck(mins, maxs)
		ply:SetViewOffset(UP * (F.height * 0.7))
		ply:SetViewOffsetDucked(UP * (F.height * 0.7))
		ply:SetStepSize(8)
		ply:SetWalkSpeed(120)
		ply:SetRunSpeed(170)
		ply:SetJumpPower(130)
	else
		local save = ply.RMPG_FruitSave
		ply.RMPG_FruitSave = nil
		if RMPG.ApplyBodyScale then RMPG.ApplyBodyScale(ply, ply:GetNW2Float("RMPG_Scale", 1)) end
		if save then
			ply:SetWalkSpeed(save.walk)
			ply:SetRunSpeed(save.run)
			ply:SetJumpPower(save.jump)
		end
	end
end

hook.Add("EntityNetworkedVarChanged", "rmpg_fruit", function(ent, name, old, new)
	if name == "RMPG_Fruit" and IsValid(ent) and ent:IsPlayer() then Apply(ent, new) end
end)

-- A fruit has no hands
hook.Add("StartCommand", "rmpg_fruit", function(ply, cmd)
	if RMPG.FruitOf(ply) ~= "" then cmd:RemoveKey(bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD, IN_ZOOM)) end
end)

if SERVER then
	function RMPG.FruitBecome(ply, kind)
		if not RMPG.FRUITS[kind] or not ply:Alive() or ply:InVehicle() then return false end
		if RMPG.BootsSet then RMPG.BootsSet(ply, false) end
		ply:SetNW2String("RMPG_Fruit", kind)
		Apply(ply, kind)
		ply:DrawWorldModel(false)
		ply:DrawViewModel(false)
		ply.RMPG_FruitHold = nil
		ply:EmitSound(RMPG.SND.fruitPop, 75, math.random(95, 110))
		local ed = EffectData()
		ed:SetOrigin(ply:WorldSpaceCenter())
		ed:SetScale(4)
		util.Effect("BloodImpact", ed, true, true)
		RMPG.Notify(ply, "n_fruit_on", { "#fruit_" .. kind }, 2)
		RMPG.Notify(ply, "n_wip", nil, 3)
		return true
	end

	function RMPG.FruitEnd(ply, quiet)
		if RMPG.FruitOf(ply) == "" then return end
		ply:SetNW2String("RMPG_Fruit", "")
		Apply(ply, "")
		ply:DrawWorldModel(true)
		ply:DrawViewModel(true)
		ply.RMPG_FruitHold = nil
		if not quiet then ply:EmitSound(RMPG.SND.fruitPop, 75, 80) end
	end

	-- What is left of a fruit that died: the fruit itself, lying there
	local function Leftover(ply, kind)
		local F = RMPG.FRUITS[kind]
		local e = ents.Create(F.class or "prop_physics")
		if not IsValid(e) then return end
		if F.model then e:SetModel(F.model) end
		e:SetPos(ply:GetPos() + UP * (F.r + 2))
		e:SetAngles(Angle(0, ply:EyeAngles().y + 90, 0))
		e:Spawn()
		local po = e:GetPhysicsObject()
		if IsValid(po) then po:SetVelocity(ply:GetVelocity() + UP * 80) end
		SafeRemoveEntityDelayed(e, 120)
	end

	hook.Add("DoPlayerDeath", "rmpg_fruit", function(ply)
		local kind = RMPG.FruitOf(ply)
		if kind == "" then return end
		ply:SetNW2Float("RMPG_Vapor", CurTime()) -- no tiny corpse, the fruit stays instead
		Leftover(ply, kind)
	end)
	hook.Add("PostPlayerDeath", "rmpg_fruit", function(ply) RMPG.FruitEnd(ply, true) end)
	hook.Add("PlayerSpawn", "rmpg_fruit", function(ply) RMPG.FruitEnd(ply, true) end)
	hook.Add("PlayerEnteredVehicle", "rmpg_fruit", function(ply) RMPG.FruitEnd(ply) end)

	-- Holding E for a second: back to yourself
	hook.Add("Think", "rmpg_fruit", function()
		local now = CurTime()
		for _, ply in ipairs(player.GetAll()) do
			if RMPG.FruitOf(ply) ~= "" then
				if ply:KeyDown(IN_USE) then
					ply.RMPG_FruitHold = ply.RMPG_FruitHold or now
					if now - ply.RMPG_FruitHold >= 1 then RMPG.FruitEnd(ply) end
				else
					ply.RMPG_FruitHold = nil
				end
			end
		end
	end)

	concommand.Add("rmpg_unfruit", function(ply) if IsValid(ply) then RMPG.FruitEnd(ply) end end)
	return
end

---------------------------------------------------------------------------
-- Client: the fruit instead of the body, rolling as it goes, your head small on its side, the camera behind it
---------------------------------------------------------------------------

local rolls, heads, melons = {}, {}, {}
local HEAD = "ValveBiped.Bip01_Head1"

function RMPG.FruitName(kind)
	return RMPG.T("fruit_" .. kind)
end

hook.Add("PrePlayerDraw", "rmpg_fruit", function(ply)
	if RMPG.FruitOf(ply) ~= "" then return true end
end)

-- Which way the fruit lies and how far it has rolled: its long side across the way it goes
local function Pose(ply, F)
	local st = rolls[ply]
	if not st then
		st = { yaw = ply:EyeAngles().y, roll = 0, t = RealTime() }
		rolls[ply] = st
	end
	local now = RealTime()
	local dt = math.min(now - st.t, 0.1)
	st.t = now
	local v = ply:GetVelocity()
	v.z = 0
	local sp = v:Length()
	if sp > 4 then
		st.yaw = math.ApproachAngle(st.yaw, v:Angle().y, dt * 540)
		st.roll = (st.roll + sp * dt / F.r * 57.2958) % 360
	end
	local ang = Angle(0, st.yaw + 90, 0)
	ang:RotateAroundAxis(ang:Forward(), st.roll)
	return ply:GetPos() + UP * F.r, ang
end

-- The head bone and everything on it go where the face is; the rest of the body shrinks to nothing inside the head
local function SetHead(e, n)
	local m = e.RMPG_HeadM
	local hb = e.RMPG_HeadBone
	if not m or not hb then return end
	local orig = e:GetBoneMatrix(hb)
	if not orig then return end
	local inv = orig:GetInverseTR()
	local gone = Matrix()
	gone:SetTranslation(m:GetTranslation())
	gone:Scale(Vector(0.001, 0.001, 0.001))
	local set = {}
	for i = 0, n - 1 do
		if e.RMPG_OnHead[i] then
			local b = e:GetBoneMatrix(i)
			if b then set[i] = m * inv * b end
		else
			set[i] = gone
		end
	end
	for i, mat in pairs(set) do e:SetBoneMatrix(i, mat) end
end

local function HeadModel(ply)
	local e = heads[ply]
	if IsValid(e) and e.RMPG_Model == ply:GetModel() then return e end
	if IsValid(e) then e:Remove() end
	e = ClientsideModel(ply:GetModel(), RENDERGROUP_OPAQUE)
	if not IsValid(e) then return end
	e:SetNoDraw(true)
	e.RMPG_Model = ply:GetModel()
	e:SetSkin(ply:GetSkin())
	for i = 0, ply:GetNumBodyGroups() - 1 do e:SetBodygroup(i, ply:GetBodygroup(i)) end
	e.RMPG_HeadBone = e:LookupBone(HEAD)
	-- the head and the bones that hang off it (eyes, hair, a hat)
	local on = {}
	if e.RMPG_HeadBone then
		on[e.RMPG_HeadBone] = true
		for i = 0, e:GetBoneCount() - 1 do
			local p = e:GetBoneParent(i)
			if p and p >= 0 and on[p] then on[i] = true end
		end
	end
	e.RMPG_OnHead = on
	e.GetPlayerColor = function() return IsValid(ply) and ply:GetPlayerColor() or Vector(1, 1, 1) end
	e:AddCallback("BuildBonePositions", SetHead)
	heads[ply] = e
	return e
end

local function FruitGroup(kind)
	RMPG.FruitGroups = RMPG.FruitGroups or {}
	local g = RMPG.FruitGroups[kind]
	if not g and RMPG.FruitParts[kind] then
		g = RMPG.Model.PartsGroup(RMPG.FruitParts[kind], 0.15)
		RMPG.FruitGroups[kind] = g
	end
	return g
end
RMPG.FruitGroup = FruitGroup

local function LightAt(pos)
	local c = render.GetLightColor(pos)
	return math.Clamp(math.max(c.x, c.y, c.z) * 1.8 + 0.25, 0.35, 1)
end

local function DrawFruit(ply, kind)
	local F = RMPG.FRUITS[kind]
	local center, ang = Pose(ply, F)
	if F.model then
		local m = melons[ply]
		if not IsValid(m) then
			m = ClientsideModel(F.model, RENDERGROUP_OPAQUE)
			if not IsValid(m) then return end
			m:SetNoDraw(true)
			melons[ply] = m
		end
		m:SetPos(center)
		m:SetAngles(ang)
		m:SetupBones()
		m:DrawModel()
	else
		local g = FruitGroup(kind)
		if not g then return end
		RMPG.Model.DrawGroup(RMPG.Model.FrameFromAngle(center, ang, 1), g, LightAt(center), RMPG.CL.outline:GetBool())
	end
	-- the head on its side
	local e = HeadModel(ply)
	if not IsValid(e) then return end
	local f = F.face
	local P = LocalToWorld(f.p, angle_zero, center, ang)
	local n = Vector(f.n)
	n:Normalize()
	n:Rotate(ang)
	local t = Vector(f.t)
	t:Rotate(ang)
	t = (t - n * t:Dot(n)):GetNormalized()
	local s = 0.55
	local m = Matrix()
	m:SetAngles(t:AngleEx(t:Cross(-n)))
	m:SetTranslation(P - n * (1.6 * s) - t * (3.4 * s))
	m:Scale(Vector(s, s, s))
	e.RMPG_HeadM = m
	e:SetPos(P)
	e:InvalidateBoneCache()
	e:DrawModel()
end

hook.Add("PostDrawOpaqueRenderables", "rmpg_fruit", function(depth, sky)
	if depth or sky then return end
	for _, ply in ipairs(player.GetAll()) do
		local kind = RMPG.FruitOf(ply)
		if kind ~= "" and ply:Alive() and not ply:IsDormant() then DrawFruit(ply, kind) end
	end
end)

-- Clean up what belonged to players who are no fruit any more
hook.Add("Think", "rmpg_fruit_clean", function()
	for _, list in ipairs({ heads, melons }) do
		for ply, e in pairs(list) do
			if not IsValid(ply) or RMPG.FruitOf(ply) == "" then
				if IsValid(e) then e:Remove() end
				list[ply] = nil
				rolls[ply] = nil
			end
		end
	end
end)

-- Third person, the camera behind and above the fruit
hook.Add("CalcView", "rmpg_fruit", function(ply, pos, ang, fov)
	local kind = RMPG.FruitOf(ply)
	if kind == "" or not ply:Alive() or ply:GetViewEntity() ~= ply then return end
	local F = RMPG.FRUITS[kind]
	local target = ply:GetPos() + UP * (F.r + 6)
	local want = target - ang:Forward() * 70 + UP * 8
	local tr = util.TraceHull({ start = target, endpos = want, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4), filter = ply, mask = MASK_SOLID_BRUSHONLY })
	return { origin = tr.HitPos, angles = ang, fov = fov, drawviewer = false }
end)

hook.Add("HUDPaint", "rmpg_fruit", function()
	local me = LocalPlayer()
	if not IsValid(me) or RMPG.FruitOf(me) == "" or not RMPG.CL.hud:GetBool() then return end
	local w, h = 380, 54
	local x, y = ScrW() / 2 - w / 2, ScrH() - h - 30
	RMPG.HoloBox(x, y, w, h, Color(10, 30, 8, 215), Color(140, 230, 90))
	RMPG.HoloText(RMPG.T("fruit_hud", RMPG.FruitName(RMPG.FruitOf(me))), "RMPG_BodyB", x + 14, y + 8, Color(230, 255, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(RMPG.T("fruit_hud_hint"), "RMPG_Small", x + 14, y + 32, Color(180, 230, 160))
	if me:KeyDown(IN_USE) then
		me.RMPG_FruitHoldC = me.RMPG_FruitHoldC or CurTime()
		local k = math.Clamp((CurTime() - me.RMPG_FruitHoldC) / 1, 0, 1)
		surface.SetDrawColor(140, 230, 90)
		surface.DrawRect(x + 4, y + h - 6, (w - 8) * k, 3)
	else
		me.RMPG_FruitHoldC = nil
	end
end)
