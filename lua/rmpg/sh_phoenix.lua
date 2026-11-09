-- Shared: Operation Phoenix body size. A body grown smaller (a child) gets a smaller model - and with it smaller
-- hitboxes - plus a smaller collision hull, lower eyes and a shorter step. The size is the player's RMPG_Scale
-- (1 = normal); the server sets it and every client applies the hull and the view the same way for prediction.
RMPG = RMPG or {}

local MINS, MAXS, DUCK = Vector(-16, -16, 0), Vector(16, 16, 72), Vector(16, 16, 36)
local EYES, EYES_DUCK, STEP = 64, 28, 18

function RMPG.ApplyBodyScale(ply, s)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	s = math.Clamp(tonumber(s) or 1, 0.3, 1)
	ply:SetModelScale(s, 0)
	if s >= 1 then
		ply:ResetHull()
	else
		ply:SetHull(MINS * s, MAXS * s)
		ply:SetHullDuck(MINS * s, DUCK * s)
	end
	ply:SetViewOffset(Vector(0, 0, EYES * s))
	ply:SetViewOffsetDucked(Vector(0, 0, EYES_DUCK * s))
	ply:SetStepSize(STEP * math.max(s, 0.6))
end

hook.Add("EntityNetworkedVarChanged", "rmpg_body_scale", function(ent, name, old, new)
	if name == "RMPG_Scale" and IsValid(ent) and ent:IsPlayer() then RMPG.ApplyBodyScale(ent, new) end
end)

if SERVER then
	function RMPG.SetBodyScale(ply, s)
		s = math.Clamp(tonumber(s) or 1, 0.3, 1)
		ply:SetNW2Float("RMPG_Scale", s)
		RMPG.ApplyBodyScale(ply, s)
	end

	-- a normal respawn gives a normal body (a Phoenix transfer sets the size again right after)
	hook.Add("PlayerSpawn", "rmpg_body_scale", function(ply)
		if ply:GetNW2Float("RMPG_Scale", 1) ~= 1 then RMPG.SetBodyScale(ply, 1) end
	end)
end
