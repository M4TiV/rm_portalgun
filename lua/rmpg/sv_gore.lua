-- Server: tearing bodies apart, for the Rick Prime chip (a blast tears off an arm or a leg) and the portal trap (what it
-- pulls in comes apart on the way). A torn limb is a second ragdoll of the same model in the same pose with everything
-- but that limb shrunk to nothing, and the body gets that limb shrunk away. Ragdolls take bone scale bone by bone, so
-- every bone of the limb is set on the body and every other bone on the piece.
RMPG = RMPG or {}

-- The bone and everything below it (bones always come after their parent)
function RMPG.BoneChain(e, root)
	local chain = { [root] = true }
	for b = root + 1, e:GetBoneCount() - 1 do
		local p = e:GetBoneParent(b)
		if p and p >= 0 and chain[p] then chain[b] = true end
	end
	return chain
end

local function Copy(src, rag)
	rag:SetModel(src:GetModel())
	rag:SetSkin(src:GetSkin())
	for _, bg in ipairs(src:GetBodyGroups() or {}) do rag:SetBodygroup(bg.id, src:GetBodygroup(bg.id)) end
	rag:SetPos(src:GetPos())
	rag:SetAngles(Angle(0, src:GetAngles().y, 0))
	rag:Spawn()
	rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	local col = src:GetNW2Vector("RMPG_PlyColor", nil)
	if src:IsPlayer() then col = src:GetPlayerColor() elseif RMPG.PersonColor and src.IsLambdaPlayer then col = RMPG.PersonColor(src) end
	if col then rag:SetNW2Vector("RMPG_PlyColor", col) end -- cl_prime.lua gives the ragdoll the colour of the clothes
end

-- Puts every part of rag where it is on src: a living thing by its bones, a ragdoll by its physics
local function Pose(src, rag, vel)
	local isRag = src:GetClass() == "prop_ragdoll"
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local po = rag:GetPhysicsObjectNum(i)
		if IsValid(po) then
			if isRag then
				local from = src:GetPhysicsObjectNum(i)
				if IsValid(from) then
					po:SetPos(from:GetPos())
					po:SetAngles(from:GetAngles())
					po:SetVelocity(from:GetVelocity() + (vel or vector_origin))
				end
			else
				local bone = rag:TranslatePhysBoneToBone(i)
				local m = bone and src:GetBoneMatrix(bone)
				if m then
					po:SetPos(m:GetTranslation())
					po:SetAngles(m:GetAngles())
				end
				po:SetVelocity(vel or src:GetVelocity())
			end
		end
	end
end

-- A ragdoll of a living thing, in the pose it is in now
function RMPG.RagdollOf(e, vel)
	local model = e:GetModel()
	if not model or not util.IsValidRagdoll(model) then return end
	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end
	Copy(e, rag)
	Pose(e, rag, vel)
	return rag
end

local function Blood(pos, dir)
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetNormal(dir)
	ed:SetScale(6)
	util.Effect("BloodImpact", ed, true, true)
	util.Decal("Blood", pos, pos - Vector(0, 0, 120))
end

-- Only the limb (a key of RMPG.LIMBS) of src, as a ragdoll of its own, thrown with push. src keeps it: TearLimb takes it
-- off a ragdoll, and the Rick Prime chip hides it on a player itself.
function RMPG.LimbPiece(src, limb, push)
	local model = src:GetModel()
	if not model or not util.IsValidRagdoll(model) then return end
	local root = src:LookupBone(RMPG.LIMBS[limb])
	if not root then return end
	local piece = ents.Create("prop_ragdoll")
	if not IsValid(piece) then return end
	Copy(src, piece)
	Pose(src, piece, src:GetClass() == "prop_ragdoll" and vector_origin or nil)
	local chain = RMPG.BoneChain(piece, root)
	for b = 0, piece:GetBoneCount() - 1 do
		if not chain[b] then piece:ManipulateBoneScale(b, vector_origin) end
	end
	-- what is not the limb is still there to hold the joints together: no weight and nothing to bump into
	for i = 0, piece:GetPhysicsObjectCount() - 1 do
		local po = piece:GetPhysicsObjectNum(i)
		if IsValid(po) then
			if chain[piece:TranslatePhysBoneToBone(i)] then
				po:SetVelocity(po:GetVelocity() + push)
				po:AddAngleVelocity(VectorRand() * 400)
			else
				po:EnableCollisions(false)
				po:SetMass(1)
			end
		end
	end
	piece.RMPG_Limb = limb
	local pos = src:GetBonePosition(root) or src:WorldSpaceCenter()
	Blood(pos, push:GetNormalized())
	return piece
end

-- Tears a limb off a ragdoll: the body loses it and the piece flies off. Returns the piece
function RMPG.TearLimb(rag, limb, push)
	local root = rag:LookupBone(RMPG.LIMBS[limb])
	if not root then return end
	local piece = RMPG.LimbPiece(rag, limb, push)
	if not IsValid(piece) then return end
	for b in pairs(RMPG.BoneChain(rag, root)) do rag:ManipulateBoneScale(b, vector_origin) end
	return piece
end
