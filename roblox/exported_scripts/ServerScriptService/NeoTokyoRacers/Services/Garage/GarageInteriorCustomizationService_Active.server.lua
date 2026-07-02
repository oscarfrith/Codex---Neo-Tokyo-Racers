-- NTR Persistence Phase 24 Garage Interior Customization Service

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local TAG = "[NTR Persistence Phase 24 GarageInteriorCustomizationService]"

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local garageRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local invoke = garageRemotes:WaitForChild("GarageInteriorCustomizationInvoke")

local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
local interiors = world:WaitForChild("Interiors")
local garageRoot = interiors:WaitForChild("GarageInstances")

local playerServices = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Player")
local profileBindings = playerServices:WaitForChild("ProfileServiceBindings")
local getProfileBinding = profileBindings:WaitForChild("GetProfile")
local markDirtyBinding = profileBindings:WaitForChild("MarkDirty")

local SURFACE_PARTS = {
	Floor = { "Floor" },
	BackWall = { "BackWall" },
	LeftWall = { "LeftWall" },
	RightWall = { "RightWall" },
	Walls = { "BackWall", "LeftWall", "RightWall" },
	CeilingLight = { "CeilingLight" },
	VehicleDisplayPad = { "VehicleDisplayPad" },
}

local VALID_DECORATIONS = {
	None = true,
	NeonSign = true,
	StorageCrate = true,
	ToolRack = true,
}

local ANCHOR_OFFSETS = {
	BackWallCenter = CFrame.new(0, 5.5, 26.15),
	FrontLeft = CFrame.new(-26, 1.25, -16),
	FrontRight = CFrame.new(26, 1.25, -16),
	LeftWallMid = CFrame.new(-39.25, 4, 4) * CFrame.Angles(0, math.rad(90), 0),
	RightWallMid = CFrame.new(39.25, 4, 4) * CFrame.Angles(0, math.rad(-90), 0),
}

local function findPlayerInServerByUserId(userId)
	userId = tonumber(userId)
	if not userId then
		return nil
	end
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == userId then
			return candidate
		end
	end
	return nil
end

local function ownerForRequest(player, payload)
	local requested = tonumber(payload and payload.OwnerUserId)
	if requested then
		return requested
	end
	local visiting = tonumber(player:GetAttribute("NTR_Phase23VisitingGarageOwnerUserId"))
	if visiting then
		return visiting
	end
	return player.UserId
end

local function findInterior(ownerUserId)
	local model = garageRoot:FindFirstChild("GarageInterior_" .. tostring(ownerUserId))
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function getProfile(player)
	local ok, profile = pcall(function()
		return getProfileBinding:Invoke(player)
	end)
	if ok and type(profile) == "table" then
		return profile
	end
	return nil
end

local function markDirty(player, reason)
	pcall(function()
		markDirtyBinding:Invoke(player, reason)
	end)
end

local function serializeColor(color)
	if typeof(color) ~= "Color3" then
		return { R = 21, G = 28, B = 36 }
	end
	return {
		R = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
		G = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
		B = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255),
	}
end

local function colorFromPayload(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "table" then
		local r = tonumber(value.R or value.r or value[1]) or 21
		local g = tonumber(value.G or value.g or value[2]) or 28
		local b = tonumber(value.B or value.b or value[3]) or 36
		if r <= 1 and g <= 1 and b <= 1 then
			return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
		end
		return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
	end
	return Color3.fromRGB(21, 28, 36)
end

local function materialFromPayload(value)
	local name = tostring(value or "SmoothPlastic")
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	if ok and material then
		return material, name
	end
	return Enum.Material.SmoothPlastic, "SmoothPlastic"
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function setPartDefaults(part)
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function ensureAnchor(model, anchorId)
	local base = model.PrimaryPart or model:FindFirstChild("Floor")
	if not base or not base:IsA("BasePart") then
		return nil
	end
	local offsets = ANCHOR_OFFSETS[anchorId]
	if not offsets then
		return nil
	end
	local folder = ensureFolder(model, "DecorationAnchors_Runtime")
	local anchor = folder:FindFirstChild("Anchor_" .. anchorId)
	if anchor and not anchor:IsA("BasePart") then
		anchor:Destroy()
		anchor = nil
	end
	if not anchor then
		anchor = Instance.new("Part")
		anchor.Name = "Anchor_" .. anchorId
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Transparency = 1
		anchor.Parent = folder
	end
	setPartDefaults(anchor)
	anchor.CFrame = base.CFrame * offsets
	anchor:SetAttribute("AnchorId", anchorId)
	return anchor
end

local function ensureAllAnchors(model)
	for anchorId in pairs(ANCHOR_OFFSETS) do
		ensureAnchor(model, anchorId)
	end
end

local function storeSurfaceOnModel(model, surfaceId, color, materialName)
	model:SetAttribute("Surface_" .. surfaceId .. "_Color", color)
	model:SetAttribute("Surface_" .. surfaceId .. "_Material", materialName)
	model:SetAttribute("PersistencePhase24GarageSurfacesDecorMVP", true)
end

local function storeDecorationOnModel(model, anchorId, decorationId)
	model:SetAttribute("Decoration_" .. anchorId, decorationId)
	model:SetAttribute("PersistencePhase24GarageSurfacesDecorMVP", true)
end

local function ensureProfileCustomization(ownerPlayer)
	local profile = getProfile(ownerPlayer)
	if not profile then
		return nil
	end
	profile.Garage = profile.Garage or {}
	profile.Garage.Customisation = profile.Garage.Customisation or {}
	profile.Garage.Customisation.SurfaceStyles = profile.Garage.Customisation.SurfaceStyles or {}
	profile.Garage.Customisation.Decorations = profile.Garage.Customisation.Decorations or {}
	return profile.Garage.Customisation
end

local buildDecoration

local function applyProfileCustomization(ownerPlayer, model)
	local data = ensureProfileCustomization(ownerPlayer)
	if not data then
		return false
	end
	for surfaceId, style in pairs(data.SurfaceStyles or {}) do
		if type(style) == "table" then
			local parts = SURFACE_PARTS[surfaceId]
			if parts then
				local color = colorFromPayload(style.Color)
				local material, materialName = materialFromPayload(style.Material)
				for _, partName in ipairs(parts) do
					local part = model:FindFirstChild(partName, true)
					if part and part:IsA("BasePart") then
						part.Color = color
						part.Material = material
					end
				end
				storeSurfaceOnModel(model, surfaceId, color, materialName)
			end
		end
	end
	for anchorId, decorationId in pairs(data.Decorations or {}) do
		decorationId = tostring(decorationId)
		if VALID_DECORATIONS[decorationId] then
			local anchor = ensureAnchor(model, anchorId)
			if anchor then
				local folder = ensureFolder(model, "Decorations_Runtime")
				local holder = folder:FindFirstChild(anchorId)
				if holder and not holder:IsA("Model") then
					holder:Destroy()
					holder = nil
				end
				if not holder then
					holder = Instance.new("Model")
					holder.Name = anchorId
					holder.Parent = folder
				end
				holder:SetAttribute("AnchorId", anchorId)
				holder:SetAttribute("DecorationId", decorationId)
				buildDecoration(anchor, decorationId, holder)
				storeDecorationOnModel(model, anchorId, decorationId)
			end
		end
	end
	return true
end

local function setSurfaceStyle(player, payload)
	local ownerUserId = ownerForRequest(player, payload)
	local ownerPlayer = findPlayerInServerByUserId(ownerUserId)
	if not ownerPlayer then
		return { Ok = false, Error = "OwnerNotInServer" }
	end
	if player.UserId ~= ownerUserId then
		return { Ok = false, Error = "OnlyOwnerCanCustomize" }
	end
	local model = findInterior(ownerUserId)
	if not model then
		return { Ok = false, Error = "EnterGarageFirst" }
	end
	local surfaceId = tostring(payload and payload.SurfaceId or "Floor")
	local partNames = SURFACE_PARTS[surfaceId]
	if not partNames then
		return { Ok = false, Error = "InvalidSurfaceId" }
	end
	local color = colorFromPayload(payload and payload.Color)
	local material, materialName = materialFromPayload(payload and payload.Material)
	local changed = 0
	for _, partName in ipairs(partNames) do
		local part = model:FindFirstChild(partName, true)
		if part and part:IsA("BasePart") then
			part.Color = color
			part.Material = material
			changed += 1
		end
	end
	storeSurfaceOnModel(model, surfaceId, color, materialName)
	local data = ensureProfileCustomization(ownerPlayer)
	local persisted = false
	if data then
		data.SurfaceStyles[surfaceId] = {
			Color = serializeColor(color),
			Material = materialName,
		}
		markDirty(ownerPlayer, "Phase24GarageSurfaceStyle")
		persisted = true
	end
	return {
		Ok = true,
		OwnerUserId = ownerUserId,
		SurfaceId = surfaceId,
		SurfaceCount = changed,
		Material = materialName,
		Persisted = persisted,
	}
end

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

local function addPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	setPartDefaults(part)
	part.Parent = parent
	return part
end

function buildDecoration(anchor, decorationId, holder)
	clearChildren(holder)
	if decorationId == "None" then
		return
	end
	if decorationId == "NeonSign" then
		addPart(holder, "NeonSignPanel", Vector3.new(10, 2.2, 0.35), anchor.CFrame, Color3.fromRGB(210, 50, 190), Enum.Material.Neon)
		addPart(holder, "NeonSignCore", Vector3.new(7.5, 0.45, 0.45), anchor.CFrame * CFrame.new(0, 0, -0.25), Color3.fromRGB(120, 245, 255), Enum.Material.Neon)
	elseif decorationId == "StorageCrate" then
		addPart(holder, "StorageCrate", Vector3.new(4, 3, 4), anchor.CFrame * CFrame.new(0, 1.25, 0), Color3.fromRGB(72, 82, 92), Enum.Material.Metal)
	elseif decorationId == "ToolRack" then
		addPart(holder, "ToolRackPanel", Vector3.new(7, 3, 0.25), anchor.CFrame, Color3.fromRGB(48, 56, 64), Enum.Material.Metal)
		addPart(holder, "ToolRackStrip", Vector3.new(6.2, 0.25, 0.35), anchor.CFrame * CFrame.new(0, 0.8, -0.2), Color3.fromRGB(120, 245, 255), Enum.Material.Neon)
	end
end

local function setDecorationAnchor(player, payload)
	local ownerUserId = ownerForRequest(player, payload)
	local ownerPlayer = findPlayerInServerByUserId(ownerUserId)
	if not ownerPlayer then
		return { Ok = false, Error = "OwnerNotInServer" }
	end
	if player.UserId ~= ownerUserId then
		return { Ok = false, Error = "OnlyOwnerCanCustomize" }
	end
	local model = findInterior(ownerUserId)
	if not model then
		return { Ok = false, Error = "EnterGarageFirst" }
	end
	local anchorId = tostring(payload and payload.AnchorId or "BackWallCenter")
	local decorationId = tostring(payload and payload.DecorationId or "None")
	if not VALID_DECORATIONS[decorationId] then
		return { Ok = false, Error = "InvalidDecorationId" }
	end
	local anchor = ensureAnchor(model, anchorId)
	if not anchor then
		return { Ok = false, Error = "InvalidAnchorId" }
	end
	local folder = ensureFolder(model, "Decorations_Runtime")
	local holder = folder:FindFirstChild(anchorId)
	if holder and not holder:IsA("Model") then
		holder:Destroy()
		holder = nil
	end
	if not holder then
		holder = Instance.new("Model")
		holder.Name = anchorId
		holder.Parent = folder
	end
	holder:SetAttribute("AnchorId", anchorId)
	holder:SetAttribute("DecorationId", decorationId)
	buildDecoration(anchor, decorationId, holder)
	storeDecorationOnModel(model, anchorId, decorationId)
	local data = ensureProfileCustomization(ownerPlayer)
	local persisted = false
	if data then
		data.Decorations[anchorId] = decorationId
		markDirty(ownerPlayer, "Phase24GarageDecoration")
		persisted = true
	end
	return {
		Ok = true,
		OwnerUserId = ownerUserId,
		AnchorId = anchorId,
		DecorationId = decorationId,
		Persisted = persisted,
	}
end

local function countModelCustomization(model)
	local surfaceSeen = {}
	local decorationSeen = {}
	for key, value in pairs(model:GetAttributes()) do
		local surfaceId = string.match(key, "^Surface_(.+)_Material$")
		if surfaceId and value ~= nil then
			surfaceSeen[surfaceId] = true
		end
		local anchorId = string.match(key, "^Decoration_(.+)$")
		if anchorId and tostring(value or "None") ~= "None" then
			decorationSeen[anchorId] = true
		end
	end
	local surfaceCount = 0
	for _ in pairs(surfaceSeen) do
		surfaceCount += 1
	end
	local decorationCount = 0
	for _ in pairs(decorationSeen) do
		decorationCount += 1
	end
	return surfaceCount, decorationCount
end

local function getCustomization(player, payload)
	local ownerUserId = ownerForRequest(player, payload)
	local ownerPlayer = findPlayerInServerByUserId(ownerUserId)
	if not ownerPlayer then
		return { Ok = false, Error = "OwnerNotInServer" }
	end
	local model = findInterior(ownerUserId)
	if not model then
		return { Ok = false, Error = "EnterGarageFirst" }
	end
	ensureAllAnchors(model)
	local persisted = applyProfileCustomization(ownerPlayer, model)
	local surfaceCount, decorationCount = countModelCustomization(model)
	local data = ensureProfileCustomization(ownerPlayer)
	if data then
		local profileSurfaceCount = 0
		for _ in pairs(data.SurfaceStyles or {}) do
			profileSurfaceCount += 1
		end
		local profileDecorationCount = 0
		for _ in pairs(data.Decorations or {}) do
			profileDecorationCount += 1
		end
		surfaceCount = math.max(surfaceCount, profileSurfaceCount)
		decorationCount = math.max(decorationCount, profileDecorationCount)
	end
	return {
		Ok = true,
		OwnerUserId = ownerUserId,
		InteriorId = model.Name,
		SurfaceCount = surfaceCount,
		DecorationCount = decorationCount,
		Persisted = persisted,
	}
end

invoke.OnServerInvoke = function(player, action, payload)
	if action == "SetSurfaceStyle" then
		return setSurfaceStyle(player, payload)
	elseif action == "SetDecorationAnchor" then
		return setDecorationAnchor(player, payload)
	elseif action == "GetCustomization" then
		return getCustomization(player, payload)
	end
	return { Ok = false, Error = "UnknownAction", Action = tostring(action) }
end

print(TAG .. " ready.")
