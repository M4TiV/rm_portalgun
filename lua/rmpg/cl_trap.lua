-- Client: streaks of the portal's colour running into a portal trap (rmpg/sv_trap.lua), so it is clear it is hungry.
-- They start close to it: it takes only what touches it.
RMPG = RMPG or {}

local STREAKS = 16

hook.Add("PostDrawTranslucentRenderables", "rmpg_trap", function(depth, sky)
	if depth or sky then return end
	local now = CurTime()
	local mat = false
	for _, p in ipairs(ents.FindByClass("rmpg_portal")) do
		if p:GetNW2Bool("RMPG_Trap", false) and p:GetCloseTime() == 0 then
			if not mat then
				render.SetMaterial(RMPG.Mat.beam)
				mat = true
			end
			local f, ax, ay = RMPG.PortalAxes(p:GetAngles())
			local c = p:GetPortalColor()
			local radius = p:GetRadius() * 2.2
			local center = p:GetPos()
			for i = 1, STREAKS do
				local k = (now * 0.9 + i * 0.618) % 1
				local a = i / STREAKS * math.pi * 2 + now * 0.6
				local dir = ax * math.cos(a) + ay * math.sin(a)
				local r0 = radius * (1 - k)
				local from = center + dir * r0 + f * (r0 * 0.35)
				local to = center + dir * (r0 * 0.55) + f * (r0 * 0.15)
				render.DrawBeam(from, to, 4 + 6 * k, 0, 1, Color(c.x, c.y, c.z, 200 * k))
			end
		end
	end
end)
