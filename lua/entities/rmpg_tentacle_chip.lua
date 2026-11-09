AddCSLuaFile()

-- Tentacle chip: press E to implant it. A steel arm grows out of your back (rmpg/sh_tentacle.lua).
ENT.Type = "anim"
ENT.Base = "rmpg_shield_chip"
ENT.PrintName = "#rmpg.tentacle"
ENT.Author = "Rick Sanchez (C-137)"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.IconOverride = "entities/rmpg_tentacle_chip.png"
ENT.GlowColor = Color(150, 185, 235)

if SERVER then
	function ENT:Initialize()
		self.BaseClass.Initialize(self)
		self:SetColor(Color(176, 196, 222))
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not RMPG.ImplantTent(ply) then
			RMPG.Notify(ply, "n_evac_has", nil, 0)
			return
		end
		RMPG.Notify(ply, "n_tent_implanted", nil, 2)
		RMPG.ImplantHint(ply)
		self:Remove()
	end
end
