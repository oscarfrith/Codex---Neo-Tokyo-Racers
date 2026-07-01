-- Neo Tokyo Racers legacy garage profile bridge.
-- Persistence Phase 3. Server-only conversion bindables for future garage profile bridge phases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "LegacyGarageProfileBridge"

local function log(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureBindableFunction(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("BindableFunction") then
		error(item:GetFullName() .. " must be a BindableFunction")
	end
	if not item then
		item = Instance.new("BindableFunction")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local dataModules = ntr:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data")
local schema = require(dataModules:WaitForChild("PlayerProfileSchema"))
local mapper = require(dataModules:WaitForChild("LegacyGarageProfileMapper"))

local serverRoot = ServerScriptService:WaitForChild("NeoTokyoRacers")
local services = ensureFolder(serverRoot, "Services")
local playerServices = ensureFolder(services, "Player")
local bindings = ensureFolder(playerServices, "LegacyGarageProfileBridgeBindings")

local convertBinding = ensureBindableFunction(bindings, "ConvertLegacyProfile")
local summarizeBinding = ensureBindableFunction(bindings, "SummarizeLegacyProfile")

convertBinding.OnInvoke = function(legacyProfile, options)
	return mapper.Convert(legacyProfile, schema, options)
end

summarizeBinding.OnInvoke = function(legacyProfile, options)
	return mapper.SummarizeConversion(legacyProfile, schema, options)
end

log("Legacy garage profile mapper bridge active. No live garage actions are patched.")
