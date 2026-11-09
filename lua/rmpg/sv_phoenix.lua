-- Server: Operation Phoenix - taking DNA, moving a mind into a finished clone, the tank window and the blacklist
RMPG = RMPG or {}

util.AddNetworkString("rmpg_phx_menu")
util.AddNetworkString("rmpg_phx_action")
util.AddNetworkString("rmpg_phx_blacklist")

local UP = Vector(0, 0, 1)

local function Bodygroups(e)
	local s = ""
	for i = 0, math.min(e:GetNumBodyGroups() - 1, 31) do s = s .. string.char(48 + math.Clamp(e:GetBodygroup(i), 0, 74)) end
	return s
end

local function ApplyBodygroups(e, s)
	for i = 1, #(s or "") do e:SetBodygroup(i - 1, string.byte(s, i) - 48) end
end

function RMPG.PhxBlacklisted(model)
	model = string.lower(model or "")
	for part in string.gmatch(RMPG.CV.phxBlacklist:GetString(), "[^,]+") do
		part = string.Trim(string.lower(part))
		if part ~= "" and string.find(model, part, 1, true) then return true end
	end
	return false
end

-- DNA of a human ragdoll, or nil and the reason
function RMPG.PhxTakeDNA(e)
	if not IsValid(e) or e:GetClass() ~= "prop_ragdoll" or not e:LookupBone("ValveBiped.Bip01_Head1") then return nil, "n_phx_not_human" end
	if RMPG.PhxBlacklisted(e:GetModel()) then return nil, "n_phx_blacklisted" end
	return { model = e:GetModel(), skin = e:GetSkin(), bodygroups = Bodygroups(e), label = string.StripExtension(string.GetFileFromFilename(e:GetModel())) }
end

function RMPG.PhxOwnDNA(ply)
	return { model = ply:GetModel(), skin = ply:GetSkin(), bodygroups = Bodygroups(ply), label = ply:Nick(), owner = ply }
end

-- The nearest free tank to pos (the player's own first)
function RMPG.PhxFreeTank(ply, pos, r)
	local best, bd
	for _, t in ipairs(ents.FindByClass(RMPG.TANK)) do
		if t:GetState() == 0 and not t:GetBroken() then
			local d = t:GetPos():DistToSqr(pos) - (t:GetCreator() == ply and 1e7 or 0)
			if t:GetPos():DistToSqr(pos) < r * r and (not bd or d < bd) then best, bd = t, d end
		end
	end
	return best
end

-- Moves ply's mind into the finished body in tank: a living player leaves his old body behind as a ragdoll
function RMPG.PhxTransfer(tank, ply)
	if not IsValid(tank) or tank:GetState() ~= 2 or tank:GetBroken() or not IsValid(ply) then return false end
	if ply:Alive() then
		local rag = ents.Create("prop_ragdoll")
		if IsValid(rag) then
			rag:SetModel(ply:GetModel())
			rag:SetSkin(ply:GetSkin())
			ApplyBodygroups(rag, Bodygroups(ply))
			rag:SetPos(ply:GetPos())
			rag:SetAngles(Angle(0, ply:EyeAngles().y, 0))
			rag:Spawn()
			for i = 0, rag:GetPhysicsObjectCount() - 1 do
				local po = rag:GetPhysicsObjectNum(i)
				local m = ply:GetBoneMatrix(rag:TranslatePhysBoneToBone(i))
				if IsValid(po) and m then
					po:SetPos(m:GetTranslation())
					po:SetAngles(m:GetAngles())
				end
			end
			undo.Create("Ragdoll")
				undo.AddEntity(rag)
				undo.SetPlayer(ply)
			undo.Finish()
		end
	else
		ply:Spawn()
	end
	local model, skin, bg = tank:GetCloneModel(), tank:GetCloneSkin(), tank:GetCloneBodygroups()
	local scale = tank:GetCloneScale()
	local pos = tank:GetPos() + tank:GetForward() * 44 + UP * 4
	local yaw = tank:GetAngles().y
	tank:Empty()
	-- after the spawn hooks have set the usual player model
	timer.Simple(0, function()
		if not IsValid(ply) or not ply:Alive() then return end
		ply:SetPos(pos)
		ply:SetEyeAngles(Angle(0, yaw, 0))
		ply:SetModel(model)
		ply:SetSkin(skin)
		ApplyBodygroups(ply, bg)
		RMPG.SetBodyScale(ply, scale)
		ply:SetHealth(ply:GetMaxHealth())
		ply:SetupHands()
		ply:EmitSound(RMPG.SND.phxTransfer, 75, 120)
		net.Start("rmpg_tpflash")
		net.WriteVector(Vector(80, 255, 140))
		net.Send(ply)
		RMPG.Notify(ply, "n_phx_reborn", nil, 2)
	end)
	return true
end

-- A ready body takes its mind back when that player dies
hook.Add("PlayerDeath", "rmpg_phoenix", function(ply)
	for _, t in ipairs(ents.FindByClass(RMPG.TANK)) do
		if t:GetState() == 2 and t:GetMind() == ply and t:GetAuto() and not t:GetBroken() then
			timer.Simple(2.5, function()
				if IsValid(ply) and not ply:Alive() and IsValid(t) and t:GetMind() == ply then RMPG.PhxTransfer(t, ply) end
			end)
			return
		end
	end
end)

local function CanControl(ply, tank)
	return IsValid(tank) and tank:GetClass() == RMPG.TANK and tank:GetPos():Distance(ply:GetPos()) < 400
		and (tank:GetInjector() == ply or tank:GetMind() == ply or tank:GetCreator() == ply or ply:IsAdmin())
end

net.Receive("rmpg_phx_action", function(_, ply)
	if (ply.RMPG_PhxNet or 0) > CurTime() then return end
	ply.RMPG_PhxNet = CurTime() + 0.2
	local tank = net.ReadEntity()
	local action = net.ReadString()
	if not CanControl(ply, tank) then return end
	if action == "mind" then
		local p = Entity(net.ReadUInt(16))
		if not IsValid(p) or not p:IsPlayer() then return end
		-- any player's mind, or (when the server says so) only your own
		if p ~= ply and not RMPG.CV.phxAnyMind:GetBool() and not ply:IsAdmin() then
			RMPG.Notify(ply, "n_phx_own_mind", nil, 1)
			return
		end
		tank:SetMind(p)
	elseif action == "scale" then
		-- once the body grows its size is settled
		if tank:GetState() == 0 or tank:GetState() == 3 then
			tank:SetCloneScale(math.Clamp(net.ReadFloat(), RMPG.CV.phxMinScale:GetFloat(), 1))
		end
	elseif action == "start" then
		if tank:Begin() then RMPG.Notify(ply, "n_phx_started", nil, 2) end
	elseif action == "repair" then
		tank:Repair()
	elseif action == "auto" then
		tank:SetAuto(net.ReadBool())
	elseif action == "transfer" then
		if tank:GetState() ~= 2 then
			RMPG.Notify(ply, "n_phx_not_ready", nil, 1)
		elseif IsValid(tank:GetMind()) then
			RMPG.PhxTransfer(tank, tank:GetMind())
		end
	elseif action == "drain" then
		tank:Empty()
	end
end)

net.Receive("rmpg_phx_blacklist", function(_, ply)
	if not ply:IsSuperAdmin() then
		RMPG.Notify(ply, "n_noaccess", nil, 1)
		return
	end
	local list = string.gsub(string.sub(net.ReadString(), 1, 2000), "[\"';]", "")
	RunConsoleCommand("rmpg_phx_blacklist", list)
end)

function RMPG.PhxOpenMenu(ply, tank)
	net.Start("rmpg_phx_menu")
	net.WriteEntity(tank)
	net.Send(ply)
end
