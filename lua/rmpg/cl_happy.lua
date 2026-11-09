-- Client: the world through a brain worm. While there is a worm in your head everything is lovely, for you alone:
-- bright colours, explosions are smiling clouds, zombies are ordinary people, there is no blood and every bullet is a
-- rainbow. The textures of fire, blood and tracers are simply swapped while it lasts and put back when the worm is gone.
RMPG = RMPG or {}

local SMILE = Material("rmpg/fx_smile")
local STAR = Material("rmpg/fx_star")
local RAINBOW = Material("rmpg/fx_rainbow")
local UP = Vector(0, 0, 1)
local CLOUD_LIFE, SHOT_LIFE = 1.8, 0.45
local PEOPLE = {
	"models/player/group01/male_01.mdl", "models/player/group01/male_02.mdl", "models/player/group01/male_03.mdl", "models/player/group01/male_04.mdl",
	"models/player/group01/male_05.mdl", "models/player/group01/male_06.mdl", "models/player/group01/male_07.mdl", "models/player/group01/male_08.mdl",
	"models/player/group01/male_09.mdl", "models/player/group01/female_01.mdl", "models/player/group01/female_02.mdl", "models/player/group01/female_03.mdl",
}
local JOY = {
	["$pp_colour_addr"] = 0.02, ["$pp_colour_addg"] = 0.01, ["$pp_colour_addb"] = 0.03,
	["$pp_colour_brightness"] = 0.03, ["$pp_colour_contrast"] = 1.08, ["$pp_colour_colour"] = 1.8,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}
local VIOLENCE = { "violence_hblood", "violence_ablood", "violence_hgibs", "violence_agibs" }

-- material -> texture it wears in this world
local SWAPS = {}
local function Wear(tex, list)
	for _, m in ipairs(list) do SWAPS[m] = tex end
end
Wear("rmpg/fx_smile", { "effects/fire_cloud1", "effects/fire_cloud2", "rmpg/fx_flame1", "rmpg/fx_flame2",
	"particles/flamelet1", "particles/flamelet2", "particles/flamelet3", "particles/flamelet4", "particles/flamelet5" })
Wear("rmpg/fx_star", { "effects/fire_embers1", "effects/fire_embers2", "effects/fire_embers3" })
Wear("rmpg/fx_blank", { "sprites/zerogxplode", "effects/spark", "effects/gunshiptracer", "effects/blood", "effects/blood2", "effects/blood_core",
	"effects/blood_drop", "effects/blood_gore", "effects/blood_puff", "effects/blooddrop", "effects/bloodstream" })
-- blood decals multiply the wall: grey leaves it as it is
local function Decals(fmt, n)
	for i = 1, n do SWAPS[string.format(fmt, i)] = "rmpg/fx_blank_grey" end
end
Decals("decals/blood%d", 8)
Decals("decals/yblood%d", 6)
Decals("decals/flesh/blood%d", 5)
Decals("decals/bloodyflesh/blood%d", 5)

local active = false
local worn, oldViolence = {}, {}
local clouds, shots = {}, {}
local nextPeople = 0

local function Swap(on)
	for name, tex in pairs(SWAPS) do
		local m = Material(name)
		if not m:IsError() then
			if on then
				worn[name] = worn[name] or m:GetTexture("$basetexture")
				m:SetTexture("$basetexture", tex)
			elseif worn[name] then
				m:SetTexture("$basetexture", worn[name])
			end
		end
	end
end

local function Violence(on)
	for _, n in ipairs(VIOLENCE) do
		local cv = GetConVar(n)
		if cv then
			if on then oldViolence[n] = cv:GetString() end
			pcall(RunConsoleCommand, n, on and "0" or (oldViolence[n] or "1"))
		end
	end
end

---------------------------------------------------------------------------
-- Zombies are just people
---------------------------------------------------------------------------

local function DrawPerson(npc)
	local h = npc.RMPG_Person
	if not IsValid(h) then
		h = ClientsideModel(PEOPLE[npc:EntIndex() % #PEOPLE + 1], RENDERGROUP_OPAQUE)
		if not IsValid(h) then return end
		h:SetNoDraw(true)
		npc.RMPG_Person = h
		npc:CallOnRemove("rmpg_person", function() if IsValid(h) then h:Remove() end end)
	end
	local pos = npc:GetPos()
	local t = RealTime()
	local dt = t - (npc.RMPG_LastT or 0)
	if dt > 0.1 then
		npc.RMPG_Speed = npc.RMPG_LastP and (pos - npc.RMPG_LastP):Length2D() / dt or 0
		npc.RMPG_LastP, npc.RMPG_LastT = pos, t
	end
	local speed = npc.RMPG_Speed or 0
	local seq = h:LookupSequence(speed > 170 and "run_all_01" or (speed > 8 and "walk_all" or "idle_all_01"))
	if seq and seq >= 0 and h:GetSequence() ~= seq then h:ResetSequence(seq) end
	h:SetCycle((t * 0.9 + npc:EntIndex() * 0.13) % 1)
	h:SetPoseParameter("move_x", speed > 8 and 1 or 0)
	h:SetPoseParameter("move_y", 0)
	h:SetPos(pos)
	h:SetAngles(Angle(0, npc:GetAngles().y, 0))
	h:InvalidateBoneCache()
	h:SetupBones()
	h:DrawModel()
end

local function IsZombie(e)
	local m = e:GetModel()
	return m and string.find(string.lower(m), "zombie", 1, true) ~= nil
end

local function People()
	for _, e in ipairs(ents.FindByClass("npc_*")) do
		if not e.RMPG_Human and IsZombie(e) then
			e.RMPG_Human = true
			e.RenderOverride = DrawPerson
		end
	end
end

local function Unpeople()
	for _, e in ipairs(ents.GetAll()) do
		if e.RMPG_Human then
			e.RMPG_Human = nil
			e.RenderOverride = nil
			if IsValid(e.RMPG_Person) then e.RMPG_Person:Remove() end
		end
	end
end

---------------------------------------------------------------------------
-- Clouds, confetti and rainbows
---------------------------------------------------------------------------

local function Confetti(pos, n)
	local em = ParticleEmitter(pos, false)
	if not em then return end
	for _ = 1, n do
		local p = em:Add(STAR, pos + VectorRand() * 12)
		if p then
			local c = HSVToColor(math.Rand(0, 360), 0.7, 1)
			p:SetVelocity(VectorRand() * 180 + UP * 160)
			p:SetGravity(Vector(0, 0, -260))
			p:SetDieTime(math.Rand(0.8, 1.5))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(4, 9))
			p:SetEndSize(1)
			p:SetRoll(math.Rand(0, 360))
			p:SetRollDelta(math.Rand(-4, 4))
			p:SetColor(c.r, c.g, c.b)
		end
	end
	em:Finish()
end

-- An explosion: a big smiling cloud. The same blast is reported from several sides, once is enough.
local function Cloud(pos)
	local now = CurTime()
	for _, c in ipairs(clouds) do
		if now - c.t < 0.3 and c.pos:DistToSqr(pos) < 250 * 250 then return end
	end
	clouds[#clouds + 1] = { pos = pos + UP * 30, t = now, size = 230 }
	sound.Play("garrysmod/balloon_pop_cute.wav", pos, 85, math.random(85, 115))
	Confetti(pos + UP * 30, 18)
end

net.Receive("rmpg_happy", function()
	if not active then return end
	if net.ReadBool() then
		Cloud(net.ReadVector())
	else
		local a, b = net.ReadVector(), net.ReadVector()
		shots[#shots + 1] = { a = a, b = b, t = CurTime(), tile = a:Distance(b) / 256 }
	end
end)

-- Explosions the client makes itself get the same treatment, and they go "pop" instead of "boom"
hook.Add("EntityEmitSound", "rmpg_happy", function(t)
	if not active then return end
	local n = string.lower(t.SoundName or "")
	if string.find(n, "explo", 1, true) then
		local pos = t.Pos or (IsValid(t.Entity) and t.Entity:GetPos())
		if pos then Cloud(pos) end
		return false
	end
end)

hook.Add("CreateClientsideRagdoll", "rmpg_happy", function(ent, rag)
	if not active or not IsValid(ent) or not ent.RMPG_Human then return end
	rag:SetNoDraw(true)
	SafeRemoveEntityDelayed(rag, 0.1)
	Confetti(ent:WorldSpaceCenter(), 30)
end)

hook.Add("PostDrawTranslucentRenderables", "rmpg_happy", function(depth, sky)
	if depth or sky or not active then return end
	local now = CurTime()
	render.SetMaterial(SMILE)
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		local k = (now - c.t) / CLOUD_LIFE
		if k >= 1 then
			table.remove(clouds, i)
		else
			local s = c.size * (0.45 + 0.55 * math.min(k * 7, 1)) * (1 + 0.25 * k)
			local a = 255 * math.Clamp((1 - k) * 3, 0, 1)
			render.DrawSprite(c.pos + UP * (50 * k), s, s, Color(255, 255, 255, a))
		end
	end
	render.SetMaterial(RAINBOW)
	for i = #shots, 1, -1 do
		local s = shots[i]
		local k = (now - s.t) / SHOT_LIFE
		if k >= 1 then
			table.remove(shots, i)
		else
			render.DrawBeam(s.a, s.b, 7 + 3 * k, 0, s.tile, Color(255, 255, 255, 255 * (1 - k)))
		end
	end
end)

hook.Add("RenderScreenspaceEffects", "rmpg_happy", function()
	if active then DrawColorModify(JOY) end
end)

hook.Add("Think", "rmpg_happy", function()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local want = me:GetNW2Float("RMPG_Wormed", 0) > 0
	if want ~= active then
		active = want
		Swap(want)
		Violence(want)
		if not want then
			Unpeople()
			clouds, shots = {}, {}
		end
	end
	if active and RealTime() >= nextPeople then
		nextPeople = RealTime() + 0.5
		People()
	end
end)
