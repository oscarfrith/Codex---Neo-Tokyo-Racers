-- Neo Tokyo Racers - Phase 6 World Services Migration
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Performs the first live architecture switch for a small isolated system:
--   traffic lights. Also stages lighting and LOD into the new architecture as
--   disabled shadow copies for later migration.
--
-- Live change:
--   - Enables ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService
--   - Disables ServerScriptService["Traffic Lights"]
--
-- Shadow-only changes:
--   - Copies LightingController into LightingService_Shadow, disabled.
--   - Copies LOD System into LODClient_Shadow, disabled.
--
-- Does NOT:
--   - Touch vehicle, garage, customisation, driving, VFX, or mobile controls.
--   - Touch Workspace.Test + WIP Assets.
--   - Create backup scripts.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function log(message)
	print("[NTR Phase6 World] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No further changes applied.")
		end
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
end

local function objectValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("ObjectValue") then
		if item then
			item.Name = name .. "_OldNonObjectValue"
		end
		item = Instance.new("ObjectValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function stringValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("StringValue") then
		if item then
			item.Name = name .. "_OldNonStringValue"
		end
		item = Instance.new("StringValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function assertScript(instance, label, expectedClass)
	expectedClass = expectedClass or "Script"
	if not instance or not instance:IsA(expectedClass) then
		error("Missing " .. label .. " (" .. expectedClass .. "). No further changes applied.")
	end
	return instance
end

local rsRoot = folder(ReplicatedStorage, "NeoTokyoRacers")
local refs = folder(rsRoot, "LiveReferences")
local migration = folder(rsRoot, "MigrationNotes")

local sssRoot = folder(ServerScriptService, "NeoTokyoRacers")
local services = folder(sssRoot, "Services")
local worldServices = folder(services, "World")
local trafficFolder = folder(worldServices, "Traffic")
local lightingFolder = folder(worldServices, "Lighting")

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local worldControllers = folder(controllers, "World")

local liveTraffic = assertScript(ServerScriptService:FindFirstChild("Traffic Lights"), "ServerScriptService.Traffic Lights", "Script")
local liveLighting = findPath(ServerScriptService, { "Lighting", "LightingController" })
local existingLightingShadow = lightingFolder:FindFirstChild("LightingService_Shadow")
if existingLightingShadow and not existingLightingShadow:IsA("Script") then
	error("LightingService_Shadow exists but is not a Script. No changes applied.")
end

local liveLOD = starterPlayerScripts:FindFirstChild("LOD System")
local existingLODShadow = worldControllers:FindFirstChild("LODClient_Shadow")
if existingLODShadow and not existingLODShadow:IsA("LocalScript") then
	error("LODClient_Shadow exists but is not a LocalScript. No changes applied.")
end

local shadowTraffic = trafficFolder:FindFirstChild("TrafficLightService_Shadow")
if shadowTraffic and not shadowTraffic:IsA("Script") then
	error("TrafficLightService_Shadow exists but is not a Script. No changes applied.")
end

local trafficSource = liveTraffic.Source
if shadowTraffic and shadowTraffic.Source ~= "" then
	trafficSource = shadowTraffic.Source
end

local finalTraffic = trafficFolder:FindFirstChild("TrafficLightService")
if finalTraffic and not finalTraffic:IsA("Script") then
	error("TrafficLightService exists but is not a Script. No changes applied.")
end
if not finalTraffic then
	finalTraffic = Instance.new("Script")
	finalTraffic.Name = "TrafficLightService"
	finalTraffic.Disabled = true
	finalTraffic.Parent = trafficFolder
end

finalTraffic.Source = trafficSource
finalTraffic:SetAttribute("MigrationStatus", "Live")
finalTraffic:SetAttribute("MigratedFrom", "ServerScriptService.Traffic Lights")
finalTraffic:SetAttribute("MigratedBy", "roblox_hierarchy_phase6_world_services_migration")

finalTraffic.Disabled = false
liveTraffic.Disabled = true
liveTraffic:SetAttribute("MigrationStatus", "DisabledAfterPhase6")
liveTraffic:SetAttribute("ReplacedBy", finalTraffic:GetFullName())

objectValue(refs, "TrafficLightService", finalTraffic)
objectValue(refs, "PreviousTrafficLightsScript", liveTraffic)
objectValue(trafficFolder, "CurrentLiveTrafficLightService", finalTraffic)
objectValue(trafficFolder, "PreviousTrafficLightsScript", liveTraffic)

if liveLighting and liveLighting:IsA("Script") then
	local lightingShadow = lightingFolder:FindFirstChild("LightingService_Shadow")
	if not lightingShadow then
		lightingShadow = Instance.new("Script")
		lightingShadow.Name = "LightingService_Shadow"
		lightingShadow.Disabled = true
		lightingShadow.Parent = lightingFolder
	end
	lightingShadow.Disabled = true
	lightingShadow.Source = liveLighting.Source
	lightingShadow:SetAttribute("MigrationStatus", "ShadowCopyOnly")
	lightingShadow:SetAttribute("CopiedFrom", liveLighting:GetFullName())
	lightingShadow:SetAttribute("DoNotEnableUntilPhase7OrLater", true)
	objectValue(refs, "LightingController", liveLighting)
	objectValue(refs, "LightingServiceShadow", lightingShadow)
	objectValue(lightingFolder, "CurrentLiveLightingController", liveLighting)
	objectValue(lightingFolder, "ShadowLightingService", lightingShadow)
else
	log("LightingController not found; skipped lighting shadow.")
end

if liveLOD and liveLOD:IsA("LocalScript") then
	local lodShadow = worldControllers:FindFirstChild("LODClient_Shadow")
	if not lodShadow then
		lodShadow = Instance.new("LocalScript")
		lodShadow.Name = "LODClient_Shadow"
		lodShadow.Disabled = true
		lodShadow.Parent = worldControllers
	end
	lodShadow.Disabled = true
	lodShadow.Source = liveLOD.Source
	lodShadow:SetAttribute("MigrationStatus", "ShadowCopyOnly")
	lodShadow:SetAttribute("CopiedFrom", liveLOD:GetFullName())
	lodShadow:SetAttribute("DoNotEnableUntilPhase7OrLater", true)
	objectValue(refs, "LODClient", liveLOD)
	objectValue(refs, "LODClientShadow", lodShadow)
	objectValue(worldControllers, "CurrentLiveLODClient", liveLOD)
	objectValue(worldControllers, "ShadowLODClient", lodShadow)
else
	log("LOD System LocalScript not found; skipped LOD shadow.")
end

stringValue(migration, "05_Phase6_WorldServices", table.concat({
	"Phase 6 migrated traffic lights to ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService.",
	"The previous ServerScriptService.Traffic Lights script was disabled.",
	"LightingService_Shadow and LODClient_Shadow are staged only and remain disabled.",
	"If traffic lights fail, manually disable TrafficLightService and re-enable ServerScriptService.Traffic Lights, then inspect source parity.",
	"Vehicle, customisation, driving, UI, VFX, and Test + WIP Assets were not touched.",
}, "\n"))

log("Traffic lights now run from the new TrafficLightService location.")
log("Old ServerScriptService.Traffic Lights script has been disabled.")
log("Lighting and LOD shadow copies were staged where available.")
log("Play-test traffic lights, day/night preview, LOD visibility, and normal vehicle flow.")
