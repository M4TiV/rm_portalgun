AddCSLuaFile()

-- Laser arm chip: press E to implant it. In combat mode the arm fires Evil Morty's laser (rmpg/sv_implants.lua).
ENT.Type = "anim"
ENT.Base = "rmpg_shield_chip"
ENT.PrintName = "#rmpg.arm"
ENT.Author = "Evil Morty"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.IconOverride = "entities/rmpg_arm_chip.png"
ENT.GlowColor = Color(255, 210, 70)

if SERVER then
	function ENT:Initialize()
		self.BaseClass.Initialize(self)
		self:SetColor(Color(255, 214, 90))
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not RMPG.ImplantArm(ply) then
			RMPG.Notify(ply, "n_evac_has", nil, 0)
			return
		end
		RMPG.Notify(ply, "n_arm_implanted", nil, 2)
		RMPG.ImplantHint(ply)
		self:Remove()
	end
end
