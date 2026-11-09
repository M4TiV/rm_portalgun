-- Client: a neutrino blast - the violet-orange flash (on the screen too), the fireball and the shock ring, the
-- smoke column, and the ground thrown into the sky: big chunks that break apart high up and come down as small
-- burning meteorites (the same pieces the server uses, from sh_neutrino.lua)
RMPG = RMPG or {}

local UP = Vector(0, 0, 1)
local ORANGE = Color(255, 150, 60)
local VIOLET = Color(180, 100, 255)
local FLAME = { Material("rmpg/fx_flame1"), Material("rmpg/fx_flame2") }
local SMOKE = Material("rmpg/fx_smoke")
local DIRT = Material("rmpg/fx_chip")
local SOUND_SPEED = 18000 -- units per second

local blasts = {}

local function Model(path, size)
	local m = ClientsideModel(path, RENDERGROUP_OPAQUE)
	if not IsValid(m) then return end
	m:SetModelScale(size, 0)
	return m
end

local function Burst(pos, many)
	if not RMPG.CL.particles:GetBool() then many = false end
	local em = ParticleEmitter(pos, false)
	if not em then return end
	for _ = 1, many and 14 or 6 do
		local p = em:Add(FLAME[math.random(#FLAME)], pos + VectorRand() * 10)
		if p then
			p:SetVelocity(VectorRand() * 120 + UP * 90)
			p:SetDieTime(math.Rand(0.4, 0.8))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(14, 26))
			p:SetEndSize(math.Rand(30, 50))
			p:SetRoll(math.Rand(0, 360))
			p:SetColor(255, 200, 150)
		end
	end
	for _ = 1, many and 10 or 4 do
		local p = em:Add(DIRT, pos + VectorRand() * 6)
		if p then
			p:SetVelocity(VectorRand() * 200 + UP * 260)
			p:SetGravity(Vector(0, 0, -600))
			p:SetCollide(true)
			p:SetDieTime(math.Rand(1, 1.8))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(2, 4))
			p:SetEndSize(1)
			p:SetRoll(math.Rand(0, 360))
			p:SetColor(90, 70, 55)
		end
	end
	local p = em:Add(SMOKE, pos + UP * 20)
	if p then
		p:SetVelocity(UP * 40)
		p:SetDieTime(math.Rand(2.5, 4))
		p:SetStartAlpha(160)
		p:SetEndAlpha(0)
		p:SetStartSize(40)
		p:SetEndSize(140)
		p:SetRoll(math.Rand(0, 360))
		p:SetColor(60, 50, 50)
	end
	em:Finish()
end

net.Receive("rmpg_neutrino", function()
	local pos, R, seed, meteors = net.ReadVector(), net.ReadFloat(), net.ReadUInt(31), net.ReadBool()
	local b = { pos = pos, R = R, t0 = CurTime(), chunks = {}, frags = {} }
	if meteors then
		for _, c in ipairs(RMPG.NeutrinoPieces(seed, pos, R)) do b.chunks[#b.chunks + 1] = { c = c } end
	end
	local tr = util.TraceLine({ start = pos, endpos = pos - UP * 400, mask = MASK_SOLID_BRUSHONLY })
	b.ground = tr.Hit and tr.HitPos + UP * 2 or pos
	local d = EyePos():Distance(pos)
	b.flash = math.Clamp(1.25 - d / (R * 2), 0, 1)
	blasts[#blasts + 1] = b
	-- the sound arrives a little later far away
	if d < R * 3 then
		local vol = math.Clamp(1.1 - d / (R * 3), 0.25, 1)
		timer.Simple(d / SOUND_SPEED, function()
			sound.Play(RMPG.SND.nbBoom, EyePos(), 75, 85, vol)
			sound.Play(RMPG.SND.nbBoom2, EyePos(), 75, 100, vol)
			util.ScreenShake(EyePos(), 8 * vol, 5, 3, 100)
		end)
	end
end)

---------------------------------------------------------------------------
-- Pieces in flight
---------------------------------------------------------------------------

local nextTrail = 0
hook.Add("Think", "rmpg_neutrino", function()
	if #blasts == 0 then return end
	local now = CurTime()
	local trail = RealTime() >= nextTrail and RMPG.CL.particles:GetBool()
	if trail then nextTrail = RealTime() + 0.08 end
	for bi = #blasts, 1, -1 do
		local b = blasts[bi]
		local t = now - b.t0
		local busy = t < 6
		for _, ch in ipairs(b.chunks) do
			local c = ch.c
			local ft = t - c.delay
			if ft >= 0 and not ch.done then
				busy = true
				if not ch.m then
					ch.m = Model(c.model, c.size)
					Burst(c.from, true)
				end
				if ft >= c.split then
					-- breaks apart high up: burning fragments
					ch.done = true
					if IsValid(ch.m) then ch.m:Remove() end
					Burst(c.splitPos, true)
					for _, f in ipairs(c.frags) do
						b.frags[#b.frags + 1] = { f = f, from = c.splitPos, t0 = b.t0 + c.delay + c.split, m = Model(f.model, f.size) }
					end
				elseif IsValid(ch.m) then
					ch.m:SetPos(RMPG.NeutrinoAt(c.from, c.vel, ft))
					ch.m:SetAngles(c.spin * ft)
				end
			end
		end
		for fi = #b.frags, 1, -1 do
			local fr = b.frags[fi]
			local f = fr.f
			local ft = now - fr.t0
			busy = true
			if ft >= f.land then
				if IsValid(fr.m) then fr.m:Remove() end
				if f.at then
					Burst(f.at, false)
					if fi % 3 == 0 then sound.Play(string.format(RMPG.SND.nbMeteor, math.random(3, 5)), f.at, 85, math.random(90, 115), 0.7) end
				end
				table.remove(b.frags, fi)
			else
				local p = RMPG.NeutrinoAt(fr.from, f.vel, ft)
				fr.pos = p
				if IsValid(fr.m) then
					fr.m:SetPos(p)
					fr.m:SetAngles(f.spin * ft)
				end
				if trail then
					local em = ParticleEmitter(p, false)
					if em then
						local q = em:Add(FLAME[math.random(#FLAME)], p)
						if q then
							q:SetVelocity(VectorRand() * 10)
							q:SetDieTime(0.35)
							q:SetStartAlpha(255)
							q:SetEndAlpha(0)
							q:SetStartSize(10)
							q:SetEndSize(2)
							q:SetRoll(math.Rand(0, 360))
							q:SetColor(255, 190, 120)
						end
						local s = em:Add(SMOKE, p)
						if s then
							s:SetDieTime(1.2)
							s:SetStartAlpha(90)
							s:SetEndAlpha(0)
							s:SetStartSize(6)
							s:SetEndSize(26)
							s:SetRoll(math.Rand(0, 360))
							s:SetColor(50, 45, 45)
						end
						em:Finish()
					end
				end
			end
		end
		if t < 4 then
			local dl = DynamicLight(90000 + bi)
			if dl then
				local k = math.Clamp(t / 1.5, 0, 1)
				dl.pos = b.pos + UP * 80
				dl.r, dl.g, dl.b = Lerp(k, ORANGE.r, VIOLET.r), Lerp(k, ORANGE.g, VIOLET.g), Lerp(k, ORANGE.b, VIOLET.b)
				dl.brightness = 6 * (1 - t / 4)
				dl.size = b.R * 0.7
				dl.decay = 1000
				dl.dietime = now + 0.2
			end
		end
		-- the smoke column over the middle
		if trail and t < 5 then
			local em = ParticleEmitter(b.pos, false)
			if em then
				local s = em:Add(SMOKE, b.ground + VectorRand() * 80 + UP * math.Rand(0, 200))
				if s then
					s:SetVelocity(UP * math.Rand(200, 420) + VectorRand() * 40)
					s:SetDieTime(math.Rand(4, 6))
					s:SetStartAlpha(140)
					s:SetEndAlpha(0)
					s:SetStartSize(120)
					s:SetEndSize(420)
					s:SetRoll(math.Rand(0, 360))
					local v = math.random() < 0.5
					s:SetColor(v and 90 or 110, v and 60 or 70, v and 120 or 60)
				end
				em:Finish()
			end
		end
		if not busy then
			for _, ch in ipairs(b.chunks) do if IsValid(ch.m) then ch.m:Remove() end end
			table.remove(blasts, bi)
		end
	end
end)

---------------------------------------------------------------------------
-- The fireball, the shock ring and the glow of the meteorites
---------------------------------------------------------------------------

local function Ease(x) x = math.Clamp(x, 0, 1) return 1 - (1 - x) ^ 3 end

hook.Add("PostDrawTranslucentRenderables", "rmpg_neutrino", function(depth, sky)
	if depth or sky or #blasts == 0 then return end
	local now = CurTime()
	local M = RMPG.Mat
	for _, b in ipairs(blasts) do
		local t = now - b.t0
		if t < 4 then
			local fade = 1 - t / 4
			local k = math.Clamp(t / 1.2, 0, 1)
			local s = b.R * (0.08 + 0.35 * Ease(t / 1.2))
			render.SetMaterial(M.glow)
			render.DrawSprite(b.pos, s * 2.2, s * 2.2, Color(VIOLET.r, VIOLET.g, VIOLET.b, 255 * fade))
			render.DrawSprite(b.pos, s * 1.3, s * 1.3, Color(ORANGE.r, ORANGE.g, ORANGE.b, 255 * fade))
			render.DrawSprite(b.pos, s * 0.5, s * 0.5, Color(255, 245, 230, 255 * fade * (1 - k * 0.6)))
			RMPG.DrawGlowDisc(b.ground, UP, b.R * Ease(t / 2), ORANGE.r, ORANGE.g, ORANGE.b, 70 * fade)
			RMPG.DrawGlowDisc(b.ground, UP, b.R * 0.8 * Ease(t / 2.6), VIOLET.r, VIOLET.g, VIOLET.b, 60 * fade)
		end
		render.SetMaterial(M.glow)
		for _, fr in ipairs(b.frags) do
			if fr.pos then render.DrawSprite(fr.pos, 28, 28, Color(255, 150, 70, 230)) end
		end
	end
end)

-- The flash on the screen: blinding white-orange first, fading through violet
hook.Add("HUDPaint", "rmpg_neutrino", function()
	if #blasts == 0 then return end
	local now = CurTime()
	for _, b in ipairs(blasts) do
		local t = now - b.t0
		if b.flash > 0 and t < 3 then
			local k = math.Clamp(t / 3, 0, 1)
			local a = b.flash * (t < 0.15 and 1 or (1 - k) ^ 2)
			local c = t < 0.15 and Color(255, 240, 220) or Color(Lerp(k, 255, VIOLET.r), Lerp(k, 170, VIOLET.g), Lerp(k, 90, VIOLET.b))
			surface.SetDrawColor(c.r, c.g, c.b, 255 * a)
			surface.DrawRect(0, 0, ScrW(), ScrH())
		end
	end
end)
