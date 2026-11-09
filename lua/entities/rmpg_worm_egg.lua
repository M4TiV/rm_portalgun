AddCSLuaFile()

-- Eggs a worm colony lays in what its workers bring home (rmpg_worm_nest): they swell, burst and a small worm crawls out.
-- The thing they were laid in is used up with the last of them. They can be shot.
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "#rmpg.worm_egg"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.RMPG_Bombable = true

local MODEL = "models/rmpg/worm_egg.mdl"
local UP = Vector(0, 0, 1)

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "LaidAt")
	self:NetworkVar("Float", 1, "HatchAt")
end

if SERVER then
	function ENT:Initialize()
		self:SetModel(MODEL)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionBounds(Vector(-5, -5, 0), Vector(5, 5, 8))
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self.HP = 30
		local now = CurTime()
		self:SetLaidAt(now)
		self:SetHatchAt(now + RMPG.CV.wormEggTime:GetFloat() * math.Rand(0.8, 1.2))
	end

	local function Splat(pos, n)
		local ed = EffectData()
		ed:SetOrigin(pos)
		ed:SetColor(0)
		for _ = 1, n do util.Effect("BloodImpact", ed, true, true) end
		sound.Play(string.format(RMPG.SND.phxFlesh, math.random(1, 4)), pos, 70, 130)
	end

	-- This egg is gone: the last one takes what it was laid in with it
	function ENT:Done()
		local it = self.Item
		if IsValid(it) and it.RMPG_Eggs then
			it.RMPG_Eggs = it.RMPG_Eggs - 1
			if it.RMPG_Eggs <= 0 then
				Splat(it:WorldSpaceCenter(), 3)
				it:Remove()
			end
		end
		self:Remove()
	end

	function ENT:Think()
		local now = CurTime()
		if RMPG.TimeStopped then
			self:SetHatchAt(self:GetHatchAt() + 0.5)
		elseif now >= self:GetHatchAt() then
			local nest = self.Nest
			if IsValid(nest) and not nest:HasRoom() then
				-- the lair is full: it waits
				self:SetHatchAt(now + 10)
			else
				local pos = self:GetPos()
				local w = ents.Create(RMPG.WORM)
				if IsValid(w) then
					w.StartSize = 0.06
					if IsValid(nest) then
						w.Colony = nest
						nest:Hatched()
					end
					w:SetPos(pos + UP * 8)
					w:Spawn()
					w:Activate()
				end
				Splat(pos, 2)
				self:Done()
				return
			end
		end
		self:NextThink(now + 0.5)
		return true
	end

	function ENT:OnTakeDamage(dmg)
		self.HP = self.HP - dmg:GetDamage()
		if self.HP > 0 or self.Dead then return end
		self.Dead = true
		Splat(self:GetPos(), 2)
		self:Done()
	end

	return
end

-- They swell as they ripen, and throb faster towards the end
function ENT:Draw(flags)
	local laid, at = self:GetLaidAt(), self:GetHatchAt()
	local k = math.Clamp((CurTime() - laid) / math.max(at - laid, 1), 0, 1)
	local s = 0.7 + 0.5 * k + math.sin(CurTime() * (2 + 8 * k)) * 0.05
	local m = Matrix()
	m:Scale(Vector(s, s, s))
	self:EnableMatrix("RenderMultiply", m)
	self:DrawModel(flags)
end
