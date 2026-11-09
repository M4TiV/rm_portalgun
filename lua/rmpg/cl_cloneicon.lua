-- Client: the reality clone's icon in the spawn menu is you: your current model, skin and colour, drawn live
RMPG = RMPG or {}

local CLASS = "rmpg_clone"
local model

-- A copy of the local player's look, kept up to date
local function Copy()
	local me = LocalPlayer()
	if not IsValid(me) then return end
	local path = me:GetModel()
	if not IsValid(model) or model:GetModel() ~= path then
		if IsValid(model) then model:Remove() end
		model = ClientsideModel(path, RENDERGROUP_OPAQUE)
		if not IsValid(model) then return end
		model:SetNoDraw(true)
		model:SetPos(vector_origin)
		model:SetAngles(Angle(0, 0, 0))
		local seq = model:LookupSequence("idle_all_01")
		if seq and seq >= 0 then model:ResetSequence(seq) end
		model:SetCycle(0)
		model:SetPlaybackRate(0)
		model.GetPlayerColor = function() return IsValid(LocalPlayer()) and LocalPlayer():GetPlayerColor() or Vector(1, 1, 1) end
	end
	model:SetSkin(me:GetSkin())
	for i = 0, me:GetNumBodyGroups() - 1 do model:SetBodygroup(i, me:GetBodygroup(i)) end
	return model
end

-- The part of a panel that scroll areas leave visible
local function Clip(panel)
	local x0, y0 = panel:LocalToScreen(0, 0)
	local x1, y1 = x0 + panel:GetWide(), y0 + panel:GetTall()
	local p = panel:GetParent()
	while IsValid(p) do
		local px, py = p:LocalToScreen(0, 0)
		x0, y0 = math.max(x0, px), math.max(y0, py)
		x1, y1 = math.min(x1, px + p:GetWide()), math.min(y1, py + p:GetTall())
		p = p:GetParent()
	end
	return x0, y0, x1, y1
end

-- ContentIcon paints its picture through Image:PaintAt, so that is what is replaced
local function PaintYou(image, x, y, w, h)
	local icon = image:GetParent()
	local e = Copy()
	if not IsValid(e) or not IsValid(icon) then return end
	local sx, sy = icon:LocalToScreen(x, y)
	local cx0, cy0, cx1, cy1 = Clip(icon)
	if cx1 <= cx0 or cy1 <= cy0 then return end
	render.ClearDepth()
	render.SetScissorRect(cx0, cy0, cx1, cy1, true)
	cam.Start3D(Vector(124, 38, 50), Angle(6, 197, 0), 34, sx, sy, w, h, 5, 400)
		render.SuppressEngineLighting(true)
		render.SetLightingOrigin(vector_origin)
		render.ResetModelLighting(0.5, 0.5, 0.5)
		render.SetModelLighting(BOX_FRONT, 1, 1, 1)
		render.SetModelLighting(BOX_TOP, 1, 1, 1)
		e:DrawModel()
		render.SuppressEngineLighting(false)
	cam.End3D()
	render.SetScissorRect(0, 0, 0, 0, false)
end

local function Dress(kind)
	local old = spawnmenu.GetContentType(kind)
	spawnmenu.AddContentType(kind, function(container, obj)
		local icon = old(container, obj)
		if IsValid(icon) and obj.spawnname == CLASS then icon.Image.PaintAt = PaintYou end
		return icon
	end)
end

hook.Add("OnGamemodeLoaded", "rmpg_clone_icon", function()
	if not spawnmenu or not spawnmenu.GetContentType then return end
	Dress("npc")
end)
