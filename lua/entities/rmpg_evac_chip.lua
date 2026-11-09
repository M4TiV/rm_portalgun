AddCSLuaFile()

-- Emergency evacuation chip: press E to implant it. Bullets and blasts then find you gone (rmpg/sv_implants.lua).
ENT.Type = "anim"
ENT.Base = "rmpg_shield_chip"
ENT.PrintName = "#rmpg.evac"
ENT.Author = "Evil Morty"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.IconOverride = "entities/rmpg_evac_chip.png"
ENT.GlowColor = Color(190, 110, 255)

if SERVER then
	function ENT:Initialize()
		self.BaseClass.Initialize(self)
		self:SetColor(Color(190, 120, 255))
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not RMPG.ImplantEvac(ply) then
			RMPG.Notify(ply, "n_evac_has", nil, 0)
			return
		end
		RMPG.Notify(ply, "n_evac_implanted", nil, 2)
		RMPG.ImplantHint(ply)
		self:Remove()
	end
end
