-- Neo Tokyo Racers - Architecture Phase L: Final HOVER_RACING_V2_KIT Removal
-- Run in Roblox Studio Command Bar, Edit mode, after Phase K has run and been play-tested.
--
-- Purpose:
--   Proves the old ReplicatedStorage.HOVER_RACING_V2_KIT root is no longer
--   referenced by live sources or ObjectValues, then deletes it entirely.
--
-- Destructive effect:
--   - Destroys ReplicatedStorage.HOVER_RACING_V2_KIT if it still exists.
--
-- Guard rails:
--   - Requires NeoTokyoRacers Phase K migration markers / report.
--   - Requires expected new NeoTokyoRacers migrated folders.
--   - Aborts if any source still contains HOVER_RACING_V2_KIT.
--   - Aborts if any ObjectValue still points into the old kit.
--   - Does not touch Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_architecture_phaseL_final_hover_kit_removal"
local LEGACY_KIT_NAME = "HOVER_RACING_V2_KIT"
local NTR_NAME = "NeoTokyoRacers"

local function log(message)
	print("[NTR Phase L] " .. message)
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
			error(("Existing %s is %s, expected %s."):format(safeFullName(existing), existing.ClassName, className))
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

local function waitPath(parent, path)
	local current = parent
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function isSourceObject(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function sourceOf(instance)
	local ok, result = pcall(function()
		return instance.Source
	end)
	if ok and typeof(result) == "string" then
		return result
	end
	return nil
end

local sourceRoots = {
	ReplicatedStorage,
	ServerScriptService,
	ServerStorage,
	StarterGui,
	StarterPlayer,
	Workspace,
}

local function collectLegacySourceHits()
	local hits = {}
	for _, root in ipairs(sourceRoots) do
		for _, instance in ipairs(root:GetDescendants()) do
			if isSourceObject(instance) and not underTestWip(instance) then
				local source = sourceOf(instance)
				if source and string.find(source, LEGACY_KIT_NAME, 1, true) then
					table.insert(hits, safeFullName(instance))
				end
			end
		end
	end
	table.sort(hits)
	return hits
end

local function collectLegacyObjectValueHits(legacyKit)
	local hits = {}
	if not legacyKit then
		return hits
	end

	for _, root in ipairs(sourceRoots) do
		for _, instance in ipairs(root:GetDescendants()) do
			if instance:IsA("ObjectValue") and not underTestWip(instance) then
				local value = instance.Value
				if value and (value == legacyKit or value:IsDescendantOf(legacyKit)) then
					table.insert(hits, safeFullName(instance) .. " -> " .. safeFullName(value))
				end
			end
		end
	end

	table.sort(hits)
	return hits
end

local ntr = ReplicatedStorage:FindFirstChild(NTR_NAME)
if not ntr or not ntr:IsA("Folder") then
	error("ReplicatedStorage.NeoTokyoRacers was not found. Run Phase K first.")
end

local compatibility = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibility, "MigrationReports")
local phaseKReport = reportsRoot:FindFirstChild("PhaseK_HoverKitMigration")

if ntr:GetAttribute("PhaseKMigrationApplied") ~= true and not phaseKReport then
	error("Phase K migration marker/report was not found. Run and test Phase K before Phase L.")
end

local expectedPaths = {
	{ "Assets", "Vehicles", "Categories" },
	{ "Assets", "VFX", "VehicleTemplates" },
	{ "Config", "UI", "Theme" },
	{ "Config", "UI", "PaintPresets" },
	{ "Shared", "Modules", "Client" },
	{ "Shared", "Modules", "Common" },
	{ "Shared", "Remotes", "Garage" },
}

local missing = {}
for _, path in ipairs(expectedPaths) do
	if not waitPath(ntr, path) then
		table.insert(missing, "NeoTokyoRacers." .. table.concat(path, "."))
	end
end

if #missing > 0 then
	error("Phase L stopped because migrated target folders are missing:\n- " .. table.concat(missing, "\n- "))
end

local legacySourceHits = collectLegacySourceHits()
if #legacySourceHits > 0 then
	error("Phase L stopped because source still references " .. LEGACY_KIT_NAME .. ":\n- " .. table.concat(legacySourceHits, "\n- "))
end

local legacyKit = ReplicatedStorage:FindFirstChild(LEGACY_KIT_NAME)
local objectValueHits = collectLegacyObjectValueHits(legacyKit)
if #objectValueHits > 0 then
	error("Phase L stopped because ObjectValues still point into the old kit:\n- " .. table.concat(objectValueHits, "\n- "))
end

local legacyDescendantCount = 0
local legacyChildCount = 0
local deletedLegacyKit = false

if legacyKit then
	if not legacyKit:IsA("Folder") then
		error("ReplicatedStorage." .. LEGACY_KIT_NAME .. " exists but is " .. legacyKit.ClassName .. ", expected Folder.")
	end

	legacyChildCount = #legacyKit:GetChildren()
	legacyDescendantCount = #legacyKit:GetDescendants()
	legacyKit:Destroy()
	deletedLegacyKit = true
end

local postDeleteKit = ReplicatedStorage:FindFirstChild(LEGACY_KIT_NAME)
if postDeleteKit then
	error("Phase L tried to delete " .. LEGACY_KIT_NAME .. ", but it still exists.")
end

local reportLines = {
	"# Neo Tokyo Racers Phase L Final Hover Kit Removal",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Phase K marker/report found: true",
	"- Missing migrated folders: " .. tostring(#missing),
	"- Legacy source references: " .. tostring(#legacySourceHits),
	"- Legacy ObjectValue references: " .. tostring(#objectValueHits),
	"- Legacy kit existed before delete: " .. tostring(legacyKit ~= nil),
	"- Legacy kit direct children deleted: " .. tostring(legacyChildCount),
	"- Legacy kit descendants deleted: " .. tostring(legacyDescendantCount),
	"- Legacy kit deleted: " .. tostring(deletedLegacyKit),
	"- Legacy kit exists after delete: false",
	"",
	"## Result",
	"",
	"- ReplicatedStorage." .. LEGACY_KIT_NAME .. " is gone.",
}

local report = reportsRoot:FindFirstChild("PhaseL_FinalHoverKitRemoval")
if report and not report:IsA("StringValue") then
	report.Name = "PhaseL_FinalHoverKitRemoval_OldNonStringValue"
	report = nil
end
if not report then
	report = Instance.new("StringValue")
	report.Name = "PhaseL_FinalHoverKitRemoval"
	report.Parent = reportsRoot
end

report.Value = table.concat(reportLines, "\n")
report:SetAttribute("CreatedBy", SCRIPT_ID)
report:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))

log("Final legacy kit removal complete.")
log("Deleted old kit: " .. tostring(deletedLegacyKit) .. "; descendants deleted: " .. tostring(legacyDescendantCount))
log("Report: " .. safeFullName(report))
print(report.Value)
