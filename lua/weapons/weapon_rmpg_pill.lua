AddCSLuaFile()

-- One dramatic exit pill (weapon_rmpg_pills is the bottle of 25): the pill in your fingers, LMB eats it - the same
-- fading exit - and then it is gone. RMB picks where you turn up.
SWEP.Base = "weapon_rmpg_pills"
SWEP.PrintName = CLIENT and RMPG and RMPG.T and RMPG.T("pill_name") or "Dramatic Exit Pill"
SWEP.Instructions = "LMB - eat the pill, RMB - where you turn up"
SWEP.Category = "Rick and Morty"
SWEP.SubCategory = "rmpg.sub_gadgets"
SWEP.Spawnable = true
SWEP.IconOverride = "entities/weapon_rmpg_pill.png"
SWEP.SlotPos = 9
SWEP.WorldModel = "models/rmpg/pill.mdl"

SWEP.Single = true
SWEP.EatLen = 0.9
SWEP.Swallow = 0.6
