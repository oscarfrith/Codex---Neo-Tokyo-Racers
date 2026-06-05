-- Neo Tokyo Racers - Phase 4B Traffic Service Shadow Copy
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Copies the current live traffic light controller into the new architecture
--   as a DISABLED shadow script for inspection and future migration.
--
-- Safe effects:
--   - Creates ServerScriptService.NeoTokyoRacers.Services.World.Traffic.
--   - Creates/updates a disabled Script named TrafficLightService_Shadow.
--   - Copies Source from ServerScriptService["Traffic Lights"].
--   - Adds ObjectValue references and migration notes.
--
-- Does NOT:
--   - Disable the current live Traffic Lights script.
--   - Enable the new shadow script.
--   - Change traffic light behaviour.
--   - Touch vehicle, UI, LOD, lighting, or Test + WIP Assets.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LIVE_TRAFFIC_NAME = "Traffic Lights"
local SHADOW_NAME = "TrafficLightService_Shadow"

local function log(message)
	print("[NTR Phase4B Traffic Shadow] " .. message)
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

local live = ServerScriptService:FindFirstChild(LIVE_TRAFFIC_NAME)
if not live or not live:IsA("Script") then
	error("Could not find live ServerScriptService." .. LIVE_TRAFFIC_NAME .. " Script. No changes applied.")
end

local rsRoot = folder(ReplicatedStorage, "NeoTokyoRacers")
local refs = folder(rsRoot, "LiveReferences")
objectValue(refs, "TrafficLights", live)

local sssRoot = folder(ServerScriptService, "NeoTokyoRacers")
local services = folder(sssRoot, "Services")
local worldServices = folder(services, "World")
local trafficFolder = folder(worldServices, "Traffic")

local shadow = trafficFolder:FindFirstChild(SHADOW_NAME)
if shadow and not shadow:IsA("Script") then
	shadow.Name = SHADOW_NAME .. "_OldNonScript"
	shadow = nil
end

if shadow and shadow.Disabled == false then
	error("Existing " .. SHADOW_NAME .. " is enabled. Refusing to overwrite an enabled script.")
end

if not shadow then
	shadow = Instance.new("Script")
	shadow.Name = SHADOW_NAME
	shadow.Disabled = true
	shadow.Parent = trafficFolder
end

shadow.Disabled = true
shadow.Source = live.Source
shadow:SetAttribute("MigrationStatus", "ShadowCopyOnly")
shadow:SetAttribute("CopiedFrom", "ServerScriptService." .. LIVE_TRAFFIC_NAME)
shadow:SetAttribute("CreatedBy", "roblox_hierarchy_phase4b_prepare_traffic_service_shadow")
shadow:SetAttribute("SafeToDeleteIfUnused", true)

objectValue(trafficFolder, "CurrentLiveTrafficLightsScript", live)
objectValue(trafficFolder, "ShadowTrafficLightService", shadow)
stringValue(trafficFolder, "README_MigrationNotes", table.concat({
	"This folder stages the future TrafficLightService location.",
	"TrafficLightService_Shadow is disabled and should stay disabled until a deliberate live-switch script is run.",
	"Current live traffic behaviour still comes from ServerScriptService.Traffic Lights.",
	"After testing, a later migration can disable the old script and enable a final TrafficLightService script.",
}, "\n"))

log("Created/refreshed disabled traffic service shadow copy.")
log("Current live traffic script is unchanged and still active in its original location.")
log("Next step after Studio inspection: play-test live traffic, then prepare a separate switch script only if the shadow copy matches.")
