-- Neo Tokyo Racers - Main Client Extraction Phase D
-- Run in Roblox Studio Command Bar, Edit mode, then Play fresh.
--
-- Purpose:
--   Moves the remaining live main client owner into the new architecture using
--   the same tested source as HOVER_RACING_V2_Client. This is an owner-location
--   switch, not an internal rewrite.
--
-- Modes:
--   MODE = "SHADOW"   -> create/update disabled shadow client only.
--   MODE = "SWITCH"   -> enable shadow client and disable HOVER_RACING_V2_Client.
--   MODE = "ROLLBACK" -> re-enable HOVER_RACING_V2_Client and disable shadow client.
--
-- Recommended use:
--   1. Run MODE = "SHADOW" in Edit mode.
--   2. If report passes, change MODE to "SWITCH" and run again.
--   3. Start a fresh Play test.
--   4. If anything breaks, run MODE = "ROLLBACK".
--
-- Safe effects:
--   - Reads HOVER_RACING_V2_Client.Source.
--   - Creates/updates one disabled shadow LocalScript under:
--     StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient
--   - In SWITCH/ROLLBACK mode, toggles Disabled on only these two LocalScripts:
--       StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Rewrite the main client internals.
--   - Delete, move, or rename the legacy client.
--   - Switch to the staged Phase A-C modules yet.
--   - Touch server actions, driving internals, VFX runtime, mobile controls,
--     LOD, lighting, traffic, assets, or Workspace.Test + WIP Assets.

local MODE = "SHADOW" -- SHADOW first. Change to SWITCH after the shadow report passes. Use ROLLBACK if needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_client_phaseD_main_client_owner_switch"
local SHADOW_NAME = "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"
local LEGACY_NAME = "HOVER_RACING_V2_Client"

local function log(message)
	print("[NTR Client Phase D] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No changes applied.")
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

local function findPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local function simpleHash(text)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function assertSourceLooksLikeMainClient(source)
	local required = {
		"local function init",
		"local function startDriving",
		"renderDealershipPanel",
		"renderCockpitPaint",
		"renderModuleShop",
		"renderCustomise",
		"GarageInvoke",
		"[V75] V47-style driving controller",
	}
	local missing = {}
	for _, needle in ipairs(required) do
		if not string.find(source, needle, 1, true) then
			table.insert(missing, needle)
		end
	end
	if #missing > 0 then
		error("Legacy client source is missing expected markers: " .. table.concat(missing, ", ") .. ". No changes applied.")
	end
end

local function canOverwriteShadow(scriptObject)
	if scriptObject.Source == "" then
		return true
	end
	local createdBy = scriptObject:GetAttribute("CreatedBy")
	local status = scriptObject:GetAttribute("MigrationStatus")
	return createdBy == SCRIPT_ID or status == "PhaseD_MainClientShadow"
end

MODE = string.upper(tostring(MODE or ""))
if MODE ~= "SHADOW" and MODE ~= "SWITCH" and MODE ~= "ROLLBACK" then
	error("MODE must be SHADOW, SWITCH, or ROLLBACK. No changes applied.")
end

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local legacyClient = starterPlayerScripts:FindFirstChild(LEGACY_NAME)
if not legacyClient or not legacyClient:IsA("LocalScript") then
	error("Could not find StarterPlayer.StarterPlayerScripts." .. LEGACY_NAME .. ". No changes applied.")
end

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local shadowClient = clientRoot:FindFirstChild(SHADOW_NAME)
if shadowClient and not shadowClient:IsA("LocalScript") then
	error("Existing " .. shadowClient:GetFullName() .. " is a " .. shadowClient.ClassName .. ", expected LocalScript. No changes applied.")
end
if not shadowClient then
	shadowClient = Instance.new("LocalScript")
	shadowClient.Name = SHADOW_NAME
	shadowClient.Disabled = true
	shadowClient.Parent = clientRoot
end

local legacySource = legacyClient.Source
assertSourceLooksLikeMainClient(legacySource)
local legacyHash = simpleHash(legacySource)

if MODE == "SHADOW" or MODE == "SWITCH" then
	if not canOverwriteShadow(shadowClient) then
		error("Shadow client already exists and was not created by Phase D. No changes applied.")
	end

	shadowClient.Disabled = true
	shadowClient.Source = legacySource
	shadowClient:SetAttribute("CreatedBy", SCRIPT_ID)
	shadowClient:SetAttribute("MigrationStatus", "PhaseD_MainClientShadow")
	shadowClient:SetAttribute("LiveEnabled", false)
	shadowClient:SetAttribute("SourceHash", legacyHash)
	shadowClient:SetAttribute("SourceScriptPath", legacyClient:GetFullName())
	shadowClient:SetAttribute("DoNotEnableWithLegacyClient", true)
end

local shadowHash = shadowClient:GetAttribute("SourceHash")
if typeof(shadowHash) ~= "string" or shadowHash == "" then
	error("Shadow client is missing SourceHash. Run MODE = SHADOW first. No changes applied.")
end
if shadowHash ~= legacyHash then
	error("Shadow SourceHash " .. tostring(shadowHash) .. " does not match current legacy hash " .. tostring(legacyHash) .. ". Run MODE = SHADOW first. No changes applied.")
end

local beforeLegacyDisabled = legacyClient.Disabled
local beforeShadowDisabled = shadowClient.Disabled

if MODE == "SWITCH" then
	shadowClient.Disabled = false
	legacyClient.Disabled = true
	shadowClient:SetAttribute("LiveEnabled", true)
	shadowClient:SetAttribute("MainClientOwner", true)
	legacyClient:SetAttribute("LiveEnabled", false)
	legacyClient:SetAttribute("MainClientOwner", false)
elseif MODE == "ROLLBACK" then
	legacyClient.Disabled = false
	shadowClient.Disabled = true
	legacyClient:SetAttribute("LiveEnabled", true)
	legacyClient:SetAttribute("MainClientOwner", true)
	shadowClient:SetAttribute("LiveEnabled", false)
	shadowClient:SetAttribute("MainClientOwner", false)
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Main Client Phase D Owner Switch")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Mode: " .. MODE)
line("- Legacy client: " .. legacyClient:GetFullName())
line("- Shadow client: " .. shadowClient:GetFullName())
line("- Source hash: " .. legacyHash)
line("- Legacy disabled before: " .. tostring(beforeLegacyDisabled))
line("- Shadow disabled before: " .. tostring(beforeShadowDisabled))
line("- Legacy disabled after: " .. tostring(legacyClient.Disabled))
line("- Shadow disabled after: " .. tostring(shadowClient.Disabled))
line("- Internal client logic rewritten: false")
line("- Phase A-C module switch performed: false")
line("")
line("## Result")
line("")
if MODE == "SHADOW" then
	line("Status: Shadow client created/updated and remains disabled. Change MODE to SWITCH when ready.")
elseif MODE == "SWITCH" then
	line("Status: Main client ownership switched to the new architecture location. Start a fresh Play test now.")
else
	line("Status: Rollback applied. Legacy HOVER_RACING_V2_Client is active again.")
end
line("")
line("## Required Test")
line("")
if MODE == "SWITCH" then
	line("1. Stop Play if currently running.")
	line("2. Start a fresh Play test.")
	line("3. Confirm Output still shows the V75 driving controller active.")
	line("4. Test dealership, cockpit paint, module shop, customisation, spawn, driving, exit/re-enter.")
	line("5. Test mobile controls if available.")
	line("6. If anything fails, rerun this script with MODE = ROLLBACK.")
elseif MODE == "SHADOW" then
	line("Run again with MODE = SWITCH only after this report looks correct.")
else
	line("Start a fresh Play test and confirm the legacy client is active and working again.")
end
line("")
line("## Safety Notes")
line("")
line("- This phase moves ownership by copying the tested legacy source, not by rewriting it.")
line("- The staged Phase A-C modules remain available for later internal extraction.")
line("- Do not delete the disabled legacy client after SWITCH; keep it as rollback until Phase E passes.")

local reportValue = reportsFolder:FindFirstChild("MainClientPhaseD_OwnerSwitchReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "MainClientPhaseD_OwnerSwitchReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "MainClientPhaseD_OwnerSwitchReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("Mode", MODE)
reportValue:SetAttribute("SourceHash", legacyHash)
reportValue:SetAttribute("LegacyDisabled", legacyClient.Disabled)
reportValue:SetAttribute("ShadowDisabled", shadowClient.Disabled)

log("Mode " .. MODE .. " complete.")
log("Legacy disabled: " .. tostring(legacyClient.Disabled) .. "; shadow disabled: " .. tostring(shadowClient.Disabled))
log("Report saved to " .. reportValue:GetFullName())
print(reportValue.Value)
