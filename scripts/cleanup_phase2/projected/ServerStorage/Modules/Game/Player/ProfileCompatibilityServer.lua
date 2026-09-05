-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
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
local schema = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("PlayerProfileSchema"))
local mapper = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("GarageProfileProjection"))

local serverRoot = game:GetService("ServerStorage"):WaitForChild("Runtime")
local services = game:GetService("ServerStorage"):WaitForChild("Runtime")
local playerServices = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player")
local bindings = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Player"):WaitForChild("LegacyGarageProfileBridgeBindings")

local convertBinding = ensureBindableFunction(bindings, "ConvertLegacyProfile")
local summarizeBinding = ensureBindableFunction(bindings, "SummarizeLegacyProfile")

convertBinding.OnInvoke = function(legacyProfile, options)
	return mapper.Convert(legacyProfile, schema, options)
end

summarizeBinding.OnInvoke = function(legacyProfile, options)
	return mapper.SummarizeConversion(legacyProfile, schema, options)
end

log("Legacy garage profile mapper bridge active. No live garage actions are patched.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
