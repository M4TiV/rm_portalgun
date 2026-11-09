-- Disintegration by Rick Prime's bomb: the body breaks into black flakes and soot that blow away from the blast.
-- The flakes are scattered over the body's hitboxes, so they keep its silhouette for a moment.
local UP = Vector(0, 0, 1)
local FLAKES = { Material("rmpg/fx_chip") }
local SOOT = Material("rmpg/fx_smoke")

-- { pos, ang, mins, maxs, volume } for every hitbox (or the bounding box)
local function BodyBoxes(ent)
	local boxes = {}
	ent:SetupBones()
	local set = ent:GetHitboxSet() or 0
	for h = 0, (ent:GetHitBoxCount(set) or 0) - 1 do
		local bone = ent:GetHitBoxBone(h, set)
		local mins, maxs = ent:GetHitBoxBounds(h, set)
		local m = bone and ent:GetBoneMatrix(bone)
		if m and mins and maxs then
			local s = maxs - mins
			boxes[#boxes + 1] = { m:GetTranslation(), m:GetAngles(), mins, maxs, math.max(math.abs(s.x * s.y * s.z), 1) }
		end
	end
	if #boxes == 0 then
		local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
		local s = maxs - mins
		boxes[1] = { ent:GetPos(), ent:GetAngles(), mins, maxs, math.max(math.abs(s.x * s.y * s.z), 1) }
	end
	return boxes
end

function EFFECT:Init(data)
	local ent = data:GetEntity()
	local origin = data:GetStart()
	local center = data:GetOrigin()
	local boxes
	if IsValid(ent) then
		boxes = BodyBoxes(ent)
		if not ent:IsPlayer() then ent:SetNoDraw(true) end
	else
		local r = math.max(data:GetRadius(), 8) * 0.6
		boxes = { { center, angle_zero, Vector(-r, -r, -r), Vector(r, r, r), r * r * r * 8 } }
	end

	local total = 0
	for _, b in ipairs(boxes) do total = total + b[5] end
	local count = math.Clamp(math.floor(math.sqrt(total) * 0.8), 40, 220)
	if not RMPG.CL.particles:GetBool() then count = math.floor(count * 0.4) end

	local em = ParticleEmitter(center, false)
	if not em then return end
	for i = 1, count do
		-- pick a hitbox weighted by its volume, then a point inside it
		local pick, acc = boxes[1], math.Rand(0, total)
		for _, b in ipairs(boxes) do
			acc = acc - b[5]
			if acc <= 0 then pick = b break end
		end
		local mins, maxs = pick[3], pick[4]
		local lp = Vector(Lerp(math.random(), mins.x, maxs.x), Lerp(math.random(), mins.y, maxs.y), Lerp(math.random(), mins.z, maxs.z))
		local pos = LocalToWorld(lp, angle_zero, pick[1], pick[2])
		local away = pos - origin
		away.z = away.z * 0.5
		away:Normalize()

		local soot = i % 4 == 0
		local p = em:Add(soot and SOOT or FLAKES[math.random(#FLAKES)], pos)
		if p then
			p:SetVelocity(away * math.Rand(20, 140) + VectorRand() * 25 + UP * math.Rand(5, 50))
			p:SetGravity(away * math.Rand(160, 320) + UP * math.Rand(10, 60))
			p:SetAirResistance(45)
			p:SetRoll(math.Rand(0, 360))
			p:SetRollDelta(math.Rand(-6, 6))
			p:SetColor(12, 9, 14)
			p:SetStartAlpha(soot and 210 or 255)
			p:SetEndAlpha(0)
			if soot then
				p:SetDieTime(math.Rand(1.2, 2.4))
				p:SetStartSize(math.Rand(5, 11))
				p:SetEndSize(math.Rand(20, 34))
			else
				p:SetDieTime(math.Rand(0.9, 2.2))
				p:SetStartSize(math.Rand(1.6, 4.2))
				p:SetEndSize(0.3)
			end
		end
	end

	-- a few violet embers at the edges
	for _ = 1, math.floor(count / 8) do
		local p = em:Add(RMPG.Mat.spark, center + VectorRand() * 12)
		if p then
			local away = (center - origin):GetNormalized()
			p:SetVelocity(away * math.Rand(60, 220) + VectorRand() * 60)
			p:SetDieTime(math.Rand(0.4, 0.9))
			p:SetStartAlpha(255)
			p:SetEndAlpha(0)
			p:SetStartSize(math.Rand(2, 4))
			p:SetEndSize(0)
			p:SetColor(200, 120, 255)
			p:SetAirResistance(80)
		end
	end
	em:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
