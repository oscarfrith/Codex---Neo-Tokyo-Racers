-- Neo Tokyo Racers - Vehicle Phase AI: Remove Cockpit Light Systems
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Removes the car cockpit light experiments from Phases S through AH so
--   driving can return to the stable baseline while the light design is paused.
--
-- Safe scope:
--   - Deletes known cockpit-light helper LocalScripts.
--   - Deletes client-only cockpit-light rig folders if they exist in Edit mode.
--   - Deletes cockpit light template folders, root SpotLight attachments,
--     SpotLights, Beam visuals, projector artifacts, and lens parts created by
--     the cockpit light phases.
--   - Clears obsolete cockpit-light attributes from surviving cockpit roots.
--   - Writes a concise report.
--
-- Does NOT:
--   - Change driving, camera, garage, LOD, traffic, lighting presets, thrust VFX,
--     or ordinary cosmetic neon systems.
--   - Touch Workspace.Test + WIP Assets.
--   - Create backup folders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_vehicle_phaseAI_remove_cockpit_light_systems"
local NTR_NAME = "NeoTokyoRacers"

local HELPER_SCRIPT_NAMES = {
	CockpitLightSmoother = true,
	CockpitLightSmoother_Active = true,
	CockpitStableBeamLights_Active = true,
	CockpitLightBeamRuntime_Active = true,
	CockpitLightInterferenceProbe_Active = true,
	CockpitLightLocalProjector_Active = true,
	CockpitLightRootWeldProjector_Active = true,
	CockpitLightWeldAudit_Active = true,
	CockpitLightRenderHost_Active = true,
	CockpitLightPredictiveProjector_Active = true,
	CockpitLightStableBeams_Active = true,
}

local CLIENT_RIG_FOLDER_NAMES = {
	NeoTokyoRacers_ClientCockpitLightRig = true,
	_NTR_LocalCockpitLightProjectors = true,
	_NTR_LocalCockpitRootWeldLights = true,
	_NTR_PhaseAF_CockpitLightRenderHosts = true,
	_NTR_PhaseAG_PredictiveCockpitLights = true,
}

local EXACT_ARTIFACT_NAMES = {
	CockpitLightTemplates = true,
	COCKPIT_LIGHTS_EditHere = true,
	FRONT_SPOTLIGHTS_EditHere = true,
	REAR_SPOTLIGHTS_EditHere = true,
	NTR_CockpitFrontSpotLight_Attachment = true,
	NTR_CockpitRearSpotLight_Attachment = true,
	NTR_CockpitFrontSpotLight = true,
	NTR_CockpitRearSpotLight = true,
	PhaseAH_Front_BeamStart = true,
	PhaseAH_Front_BeamEnd = true,
	PhaseAH_Front_StableBeam = true,
	PhaseAH_Front_NearSpotLight = true,
	PhaseAH_Rear_BeamStart = true,
	PhaseAH_Rear_BeamEnd = true,
	PhaseAH_Rear_StableBeam = true,
	PhaseAH_Rear_NearSpotLight = true,
	PhaseAB_CockpitLightLensRootWeld = true,
}

local LIGHT_ATTRIBUTES = {
	NTRCockpitLightSystem = true,
	RootCockpitSpotLight = true,
	RootCockpitSpotLightAttachment = true,
	StableCockpitLightBeam = true,
	StableBeamLength = true,
	CockpitLightRole = true,
	ClientSmootherDesiredEnabled = true,
	LocalProjectorDesiredEnabled = true,
	RootWeldProjectorDesiredEnabled = true,
	PhaseAH_PreviousEnabled = true,
	PhaseAB_PreviousAnchored = true,
}

local function log(message)
	print("[NTR Vehicle Phase AI] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function underTestWip(instance)
	return string.find(safeFullName(instance), "Test %+ WIP Assets") ~= nil
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error(("Existing %s is %s, expected %s. No changes applied."):format(
				safeFullName(existing),
				existing.ClassName,
				className
			))
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

local function addUnique(list, seen, instance)
	if instance and instance.Parent and not seen[instance] then
		seen[instance] = true
		table.insert(list, instance)
	end
end

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function pathContains(instance, token)
	return string.find(safeFullName(instance), token, 1, true) ~= nil
end

local function hasCockpitLightAttribute(instance)
	for attributeName in pairs(LIGHT_ATTRIBUTES) do
		if instance:GetAttribute(attributeName) ~= nil then
			return true
		end
	end
	return false
end

local function isGeneratedProjectorArtifact(instance)
	local name = instance.Name
	return startsWith(name, "ClientSmoothedCockpitLightCarrier")
		or startsWith(name, "LocalProjector_")
		or startsWith(name, "RootWeldProjector_")
		or startsWith(name, "RootWeldProjectorWeld")
		or string.find(name, "_LocalProjector", 1, true) ~= nil
		or string.find(name, "_RootWeldProjector", 1, true) ~= nil
end

local function isCockpitLightArtifact(instance)
	if underTestWip(instance) then
		return false
	end

	if EXACT_ARTIFACT_NAMES[instance.Name] then
		return true
	end

	if instance:GetAttribute("TemplateRole") == "CockpitSpotLightLens" then
		return true
	end

	if hasCockpitLightAttribute(instance)
		and (
			instance:IsA("Attachment")
			or instance:IsA("SpotLight")
			or instance:IsA("PointLight")
			or instance:IsA("SurfaceLight")
			or instance:IsA("Beam")
			or instance:IsA("WeldConstraint")
		)
	then
		return true
	end

	if pathContains(instance, "COCKPIT_LIGHTS_EditHere") or pathContains(instance, "CockpitLightTemplates") then
		return true
	end

	if isGeneratedProjectorArtifact(instance) then
		return true
	end

	return false
end

local function clearLightAttributes(instance, changed)
	for attributeName in pairs(LIGHT_ATTRIBUTES) do
		if instance:GetAttribute(attributeName) ~= nil then
			instance:SetAttribute(attributeName, nil)
			table.insert(changed, safeFullName(instance) .. " attr " .. attributeName)
		end
	end

	if instance:GetAttribute("TemplateRole") == "CockpitSpotLightLens" then
		instance:SetAttribute("TemplateRole", nil)
		table.insert(changed, safeFullName(instance) .. " attr TemplateRole")
	end
end

local function collectDescendants(root, results)
	if not root then
		return
	end
	for _, instance in ipairs(root:GetDescendants()) do
		table.insert(results, instance)
	end
end

local ntr = ReplicatedStorage:FindFirstChild(NTR_NAME)
if not ntr or not ntr:IsA("Folder") then
	error("ReplicatedStorage.NeoTokyoRacers was not found. Run Phase K before Phase AI.")
end

local toDestroy = {}
local destroySeen = {}
local clearedAttributes = {}

local all = {}
collectDescendants(StarterPlayer, all)
collectDescendants(ReplicatedStorage, all)
collectDescendants(Workspace, all)

for _, instance in ipairs(all) do
	if not underTestWip(instance) then
		if instance:IsA("LocalScript") and HELPER_SCRIPT_NAMES[instance.Name] then
			addUnique(toDestroy, destroySeen, instance)
		elseif instance:IsA("Folder") and CLIENT_RIG_FOLDER_NAMES[instance.Name] then
			addUnique(toDestroy, destroySeen, instance)
		elseif isCockpitLightArtifact(instance) then
			addUnique(toDestroy, destroySeen, instance)
		elseif hasCockpitLightAttribute(instance) or instance:GetAttribute("TemplateRole") == "CockpitSpotLightLens" then
			clearLightAttributes(instance, clearedAttributes)
		end
	end
end

table.sort(toDestroy, function(a, b)
	return #safeFullName(a) > #safeFullName(b)
end)

local destroyed = {}
for _, instance in ipairs(toDestroy) do
	if instance.Parent then
		table.insert(destroyed, safeFullName(instance) .. " <" .. instance.ClassName .. ">")
		instance:Destroy()
	end
end

table.sort(destroyed)
table.sort(clearedAttributes)

local compatibility = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibility, "MigrationReports")
local report = reportsRoot:FindFirstChild("PhaseAI_CockpitLightSystemRemoval")
if report and not report:IsA("StringValue") then
	report.Name = "PhaseAI_CockpitLightSystemRemoval_OldNonStringValue"
	report = nil
end
if not report then
	report = Instance.new("StringValue")
	report.Name = "PhaseAI_CockpitLightSystemRemoval"
	report.Parent = reportsRoot
end

local reportLines = {
	"# Neo Tokyo Racers Vehicle Phase AI Cockpit Light System Removal",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Destroyed cockpit-light artifacts: " .. tostring(#destroyed),
	"- Cleared cockpit-light attributes on survivors: " .. tostring(#clearedAttributes),
	"- Workspace.Test + WIP Assets excluded: true",
	"- Driving/camera/VFX/UI systems changed: false",
	"",
	"## Destroyed",
	"",
}

if #destroyed == 0 then
	table.insert(reportLines, "- None.")
else
	for _, item in ipairs(destroyed) do
		table.insert(reportLines, "- " .. item)
	end
end

table.insert(reportLines, "")
table.insert(reportLines, "## Attributes Cleared")
table.insert(reportLines, "")

if #clearedAttributes == 0 then
	table.insert(reportLines, "- None.")
else
	for _, item in ipairs(clearedAttributes) do
		table.insert(reportLines, "- " .. item)
	end
end

report.Value = table.concat(reportLines, "\n")
report:SetAttribute("CreatedBy", SCRIPT_ID)
report:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))

log("Cockpit light system removal complete.")
log("Destroyed artifacts: " .. tostring(#destroyed) .. "; cleared attributes: " .. tostring(#clearedAttributes))
log("Report: " .. safeFullName(report))
print(report.Value)
