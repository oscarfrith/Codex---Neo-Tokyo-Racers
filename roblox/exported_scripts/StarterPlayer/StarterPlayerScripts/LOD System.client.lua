print("LOD Script Running")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ROOT = workspace:WaitForChild("GeneratedCityBlocks")

local FAR_LOD5_SOURCE = ReplicatedStorage:FindFirstChild("FarLOD5")

local UPDATE_RATE = 0.5
local DEBUG_PRINTS = false

local DIST = {
	LOD1 = 200,
	LOD2 = 800,
	LOD3 = 1300,
	LOD4 = 2450,
	LOD5 = 5000,
}

local HYSTERESIS = 50
local FAR_LOD5_START = 2450
local FAR_LOD5_END = 5000

-- Special foliage band
local LOD4_FOLIAGE_MIN = 1275
local LOD4_FOLIAGE_MAX = 2000

local ActiveFarLOD5 = workspace:FindFirstChild("_ActiveFarLOD5")
if not ActiveFarLOD5 then
	ActiveFarLOD5 = Instance.new("Folder")
	ActiveFarLOD5.Name = "_ActiveFarLOD5"
	ActiveFarLOD5.Parent = workspace
end

local Blocks = {}
local OriginalProperties = {}

local function cacheOriginalProperties(obj)
	if OriginalProperties[obj] then return end

	if obj:IsA("BasePart") then
		OriginalProperties[obj] = {
			Transparency = obj.Transparency,
			CanCollide = obj.CanCollide,
			CanTouch = obj.CanTouch,
			CanQuery = obj.CanQuery,
			Anchored = obj.Anchored,
			CastShadow = obj.CastShadow,
			LocalTransparencyModifier = obj.LocalTransparencyModifier,
		}
	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		OriginalProperties[obj] = {
			Transparency = obj.Transparency,
		}
	elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
		OriginalProperties[obj] = {
			Enabled = obj.Enabled,
		}
	end
end

local function cacheFolderOriginalProperties(folder)
	if not folder then return end

	for _, obj in ipairs(folder:GetDescendants()) do
		cacheOriginalProperties(obj)
	end
end

local function isBlockModel(model)
	return model:IsA("Model") and model.Name:match("^Block_S%d+_R%d+_B%d+$")
end

local function setInstanceVisible(obj, visible)
	cacheOriginalProperties(obj)

	local original = OriginalProperties[obj]
	if not original then return end

	if obj:IsA("BasePart") then
		if visible then
			obj.Transparency = original.Transparency or 0
			obj.LocalTransparencyModifier = original.LocalTransparencyModifier or 0
			obj.CanCollide = original.CanCollide
			obj.CanTouch = original.CanTouch
			obj.CanQuery = original.CanQuery
			obj.Anchored = original.Anchored
			obj.CastShadow = original.CastShadow
		else
			obj.LocalTransparencyModifier = 1
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Anchored = true
			obj.CastShadow = false
		end

	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		obj.Transparency = visible and original.Transparency or 1

	elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
		obj.Enabled = visible and original.Enabled or false
	end
end

local function setLODVisible(folder, visible)
	if not folder then return end

	for _, obj in ipairs(folder:GetDescendants()) do
		setInstanceVisible(obj, visible)
	end
end

local function setupStreamingVisibilityWatcher(blockData, lodFolder, lodNumber)
	if not lodFolder then return end

	lodFolder.DescendantAdded:Connect(function(obj)
		cacheOriginalProperties(obj)

		local currentState = blockData.LastNearState
		local shouldShow =
			currentState ~= 0
			and lodNumber >= currentState
			and lodNumber <= 4

		setInstanceVisible(obj, shouldShow)
	end)
end

local function setupFoliageVisibilityWatcher(blockData)
	if not blockData.LOD4_Foliage then return end

	blockData.LOD4_Foliage.DescendantAdded:Connect(function(obj)
		cacheOriginalProperties(obj)
		setInstanceVisible(obj, blockData.LastFoliageVisible == true)
	end)
end

local function getNearLODState(dist)
	if dist <= DIST.LOD1 then
		return 1
	elseif dist <= DIST.LOD2 then
		return 2
	elseif dist <= DIST.LOD3 then
		return 3
	elseif dist < FAR_LOD5_START then
		return 4
	else
		return 0
	end
end

local function shouldNearLODBeVisible(lodNumber, state)
	if state == 0 then
		return false
	end

	return lodNumber >= state and lodNumber <= 4
end

local function applyNearLOD(blockData, state)
	if blockData.LastNearState == state then
		return
	end

	blockData.LastNearState = state

	for i = 1, 4 do
		local lodFolder = blockData.LODs["LOD" .. i]
		local visible = shouldNearLODBeVisible(i, state)
		setLODVisible(lodFolder, visible)
	end
end

local function shouldShowLOD4Foliage(dist)
	return dist >= LOD4_FOLIAGE_MIN and dist <= LOD4_FOLIAGE_MAX
end

local function applyLOD4Foliage(blockData, visible)
	if blockData.LastFoliageVisible == visible then
		return
	end

	blockData.LastFoliageVisible = visible
	setLODVisible(blockData.LOD4_Foliage, visible)
end

local function shouldShowFarLOD5(dist, wasVisible)
	if wasVisible then
		return dist >= FAR_LOD5_START - HYSTERESIS and dist <= FAR_LOD5_END + HYSTERESIS
	end

	return dist >= FAR_LOD5_START and dist <= FAR_LOD5_END
end

local function applyFarLOD5(blockData, visible)
	if blockData.LastFarVisible == visible then
		return
	end

	blockData.LastFarVisible = visible

	if not FAR_LOD5_SOURCE then
		return
	end

	if visible then
		if not blockData.FarLOD5Clone then
			local source = FAR_LOD5_SOURCE:FindFirstChild(blockData.Model.Name .. "_LOD5")

			if source then
				local clone = source:Clone()
				clone.Name = blockData.Model.Name .. "_LOD5"
				clone.Parent = ActiveFarLOD5
				blockData.FarLOD5Clone = clone
			else
				warn("Missing FarLOD5 proxy:", blockData.Model.Name .. "_LOD5")
			end
		else
			blockData.FarLOD5Clone.Parent = ActiveFarLOD5
		end
	else
		if blockData.FarLOD5Clone then
			blockData.FarLOD5Clone.Parent = nil
		end
	end
end

local function getBlockCenterPosition(blockData)
	if blockData.CenterPart and blockData.CenterPart.Parent then
		return blockData.CenterPart.Position
	end

	if blockData.RootPart and blockData.RootPart.Parent then
		return blockData.RootPart.Position
	end

	return blockData.Model:GetPivot().Position
end

local function registerBlocks()
	for _, block in ipairs(ROOT:GetDescendants()) do
		if isBlockModel(block) then
			local lodRoot = block:FindFirstChild("LOD")
			local centerPart = block:FindFirstChild("CenterPart", true)
			local rootPart = block:FindFirstChild("Root", true)

			if not lodRoot then
				warn("Block missing LOD folder:", block.Name)
				continue
			end

			local blockData = {
				Model = block,
				CenterPart = centerPart,
				RootPart = rootPart,
				LODRoot = lodRoot,

				LODs = {
					LOD1 = lodRoot:FindFirstChild("LOD1"),
					LOD2 = lodRoot:FindFirstChild("LOD2"),
					LOD3 = lodRoot:FindFirstChild("LOD3"),
					LOD4 = lodRoot:FindFirstChild("LOD4"),
				},

				LOD4_Foliage = lodRoot:FindFirstChild("LOD4_Foliage"),

				LastNearState = -1,
				LastFoliageVisible = nil,
				LastFarVisible = false,
				FarLOD5Clone = nil,
			}

			for i = 1, 4 do
				local lodFolder = blockData.LODs["LOD" .. i]

				if lodFolder then
					cacheFolderOriginalProperties(lodFolder)
					setupStreamingVisibilityWatcher(blockData, lodFolder, i)
				else
					warn(block.Name .. " missing LOD" .. i)
				end
			end

			if blockData.LOD4_Foliage then
				cacheFolderOriginalProperties(blockData.LOD4_Foliage)
				setupFoliageVisibilityWatcher(blockData)
			else
				warn(block.Name .. " missing LOD4_Foliage")
			end

			table.insert(Blocks, blockData)
		end
	end

	print("Registered blocks:", #Blocks)
end

registerBlocks()

while true do
	task.wait(UPDATE_RATE)

	local character = player.Character
	if not character then continue end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then continue end

	local playerPos = rootPart.Position

	for _, blockData in ipairs(Blocks) do
		local centerPos = getBlockCenterPosition(blockData)

		local dx = playerPos.X - centerPos.X
		local dz = playerPos.Z - centerPos.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		local nearState = getNearLODState(dist)

		if DEBUG_PRINTS then
			print(
				blockData.Model.Name,
				"Distance:", math.floor(dist),
				"NearState:", nearState,
				"LOD4_Foliage:", shouldShowLOD4Foliage(dist)
			)
		end

		applyNearLOD(blockData, nearState)

		local foliageVisible = shouldShowLOD4Foliage(dist)
		applyLOD4Foliage(blockData, foliageVisible)

		local farVisible = shouldShowFarLOD5(dist, blockData.LastFarVisible)
		applyFarLOD5(blockData, farVisible)
	end
end