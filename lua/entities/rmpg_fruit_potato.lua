AddCSLuaFile()

-- A potato: stab it with the DNA syringe, inject yourself, and you are a potato (rmpg/sh_fruit.lua)
ENT.Type = "anim"
ENT.Base = "rmpg_fruit"
ENT.PrintName = "#rmpg.fruit_potato"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.IconOverride = "entities/rmpg_fruit_potato.png"
ENT.RMPG_FruitKind = "potato"

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
end
