AddCSLuaFile()

-- The vat of fake acid: the same vat as rmpg_acid_vat, but whoever jumps in only seems to die (see there)
ENT.Type = "anim"
ENT.Base = "rmpg_acid_vat"
ENT.PrintName = "#rmpg.acid_vat_fake"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "entities/rmpg_acid_vat_fake.png"
ENT.Fake = true

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local e = ents.Create(class)
		e:SetPos(tr.HitPos + tr.HitNormal * 1)
		e:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
		e:Spawn()
		e:Activate()
		return e
	end
end
