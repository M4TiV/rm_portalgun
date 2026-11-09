AddCSLuaFile()

-- A fruit to stab with the DNA syringe (rmpg/sh_fruit.lua): the potato is rmpg_fruit_potato, this entity with its
-- own kind (the pickle, rmpg_fruit_pickle, is kept in dev/wip for now). Drawn from RMPG.FruitParts (cl_model_parts.lua); its
-- collision is a convex hull round the same shape.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Fruit"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = false
ENT.RMPG_FruitKind = "potato"

-- half sizes of the shape along its own axes (X is its long side)
local SIZE = { pickle = Vector(12.5, 5.3, 5.3), potato = Vector(8.6, 6.3, 5.5) }

local function Hull(kind)
	local s = SIZE[kind] or SIZE.pickle
	local pts = {}
	for j = 0, 6 do
		local lat = -math.pi / 2 + math.pi * j / 6
		for i = 0, 11 do
			local lon = i / 12 * math.pi * 2
			pts[#pts + 1] = Vector(s.x * math.cos(lat) * math.cos(lon), s.y * math.cos(lat) * math.sin(lon), s.z * math.sin(lat))
		end
	end
	return pts
end

function ENT:Initialize()
	if SERVER then self:SetModel("models/rmpg/worm_seg.mdl") end -- no hitbox: traces meet the hull below
	self:PhysicsInitConvex(Hull(self.RMPG_FruitKind))
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:EnableCustomCollisions(true)
	local po = self:GetPhysicsObject()
	if IsValid(po) then
		po:SetMass(3)
		po:SetMaterial(self.RMPG_FruitKind == "potato" and "dirt" or "watermelon")
		po:Wake()
	end
	if CLIENT then
		local s = SIZE[self.RMPG_FruitKind] or SIZE.pickle
		self:SetRenderBounds(-s - Vector(2, 2, 2), s + Vector(2, 2, 2))
	end
end

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 8)
		e:SetAngles(Angle(0, ply:EyeAngles().y, 0))
		e:Spawn()
		e:Activate()
		return e
	end
	return
end

function ENT:Draw()
	local g = RMPG.FruitGroup and RMPG.FruitGroup(self.RMPG_FruitKind)
	if not g then return end
	local c = render.GetLightColor(self:GetPos())
	local light = math.Clamp(math.max(c.x, c.y, c.z) * 1.8 + 0.25, 0.35, 1)
	RMPG.Model.DrawGroup(RMPG.Model.FrameFromAngle(self:GetPos(), self:GetAngles(), 1), g, light, RMPG.CL.outline:GetBool())
	-- still being made: it says so over it
	local pos = self:GetPos() + Vector(0, 0, 14)
	if EyePos():DistToSqr(pos) < 700 * 700 then
		local ang = (EyePos() - pos):Angle()
		ang:RotateAroundAxis(ang:Up(), 90)
		ang:RotateAroundAxis(ang:Forward(), 90)
		cam.Start3D2D(pos, ang, 0.08)
			draw.SimpleTextOutlined("W.I.P", "RMPG_Head", 0, 0, Color(255, 200, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		cam.End3D2D()
	end
end
