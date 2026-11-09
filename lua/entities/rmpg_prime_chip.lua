AddCSLuaFile()

-- Rick Prime's chip: press E to implant it. Wounds heal, a lethal hit is undone now and then, and you can make bodies of
-- yourself to move your mind into (rmpg/sv_prime.lua).
ENT.Type = "anim"
ENT.Base = "rmpg_shield_chip"
ENT.PrintName = "#rmpg.prime"
ENT.Author = "Rick Prime"
ENT.Category = "Rick and Morty"
ENT.Spawnable = true
ENT.IconOverride = "entities/rmpg_prime_chip.png"
ENT.GlowColor = Color(225, 40, 50)

if SERVER then
	function ENT:Initialize()
		self.BaseClass.Initialize(self)
		self:SetColor(Color(200, 60, 70))
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if not RMPG.ImplantPrime(ply) then
			RMPG.Notify(ply, "n_evac_has", nil, 0)
			return
		end
		RMPG.Notify(ply, "n_prime_implanted3", nil, 2)
		self:Remove()
	end
end
