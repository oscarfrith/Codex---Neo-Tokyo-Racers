-- Neo Tokyo Racers - Archive Disabled Legacy Scripts
-- Paste this whole script into the Roblox Studio Command Bar in Edit mode.
--
-- What this does:
-- - Moves disabled legacy HOVER_RACING scripts out of live script containers.
-- - Archives them under ServerStorage.NeoTokyoRacers_LegacyArchive.DisabledScripts.
-- - Preserves their original path as attributes.
-- - Writes a report to ReplicatedStorage.NTR_AUDIT_REPORTS.
--
-- What this does NOT do:
-- - It does not delete anything.
-- - It does not touch active scripts.
-- - It does not touch Workspace["Test + WIP Assets"].
-- - It does not touch TEMP_LightingPreview.

local MIGRATION_ID = "NTR_ArchiveDisabledLegacyScripts_2026_05_28"
local REPORT_FOLDER_NAME = "NTR_AUDIT_REPORTS"
local REPORT_VALUE_NAME = "ArchiveDisabledLegacyScripts_Report"

local serverScriptService = game:GetService("ServerScriptService")
local starterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local serverStorage = game:GetService("ServerStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")

local archiveRoot = serverStorage:FindFirstChild("NeoTokyoRacers_LegacyArchive")
if not archiveRoot then
	archiveRoot = Instance.new("Folder")
	archiveRoot.Name = "NeoTokyoRacers_LegacyArchive"
	archiveRoot.Parent = serverStorage
end

local disabledScriptsRoot = archiveRoot:FindFirstChild("DisabledScripts")
if not disabledScriptsRoot then
	disabledScriptsRoot = Instance.new("Folder")
	disabledScriptsRoot.Name = "DisabledScripts"
	disabledScriptsRoot.Parent = archiveRoot
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing then
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function safeName(name)
	return string.gsub(name, "[^%w_%- ]", "_")
end

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function isArchiveCandidate(scriptInstance)
	if not (scriptInstance:IsA("Script") or scriptInstance:IsA("LocalScript")) then
		return false, "not Script/LocalScript"
	end

	if not scriptInstance.Disabled then
		return false, "active script"
	end

	local path = scriptInstance:GetFullName()
	if startsWith(path, "Workspace.Test + WIP Assets.") then
		return false, "inside excluded Test + WIP Assets"
	end

	if scriptInstance.Name == "TEMP_LightingPreview" then
		return false, "intentional lighting preview tool"
	end

	if startsWith(scriptInstance.Name, "HOVER_RACING") then
		return true, "disabled legacy HOVER_RACING script"
	end

	return false, "not named HOVER_RACING*"
end

local function destinationFor(scriptInstance)
	local path = scriptInstance:GetFullName()
	local serviceName
	local serviceRoot

	if startsWith(path, "ServerScriptService.") then
		serviceName = "ServerScriptService"
		serviceRoot = ensureFolder(disabledScriptsRoot, serviceName)
	elseif startsWith(path, "StarterPlayer.StarterPlayerScripts.") then
		serviceName = "StarterPlayerScripts"
		serviceRoot = ensureFolder(disabledScriptsRoot, serviceName)
	else
		return nil
	end

	if not serviceRoot then
		return nil
	end

	local folderName = safeName(scriptInstance.Parent:GetFullName())
	local parentFolder = ensureFolder(serviceRoot, folderName)
	return parentFolder
end

local moved = {}
local skipped = {}

local scanRoots = {
	serverScriptService,
	starterPlayerScripts,
}

for _, root in ipairs(scanRoots) do
	for _, descendant in ipairs(root:GetDescendants()) do
		local okToArchive, reason = isArchiveCandidate(descendant)
		if okToArchive then
			local originalPath = descendant:GetFullName()
			local destination = destinationFor(descendant)
			if not destination then
				table.insert(skipped, originalPath .. " -- no destination folder")
			elseif destination:FindFirstChild(descendant.Name) then
				table.insert(skipped, originalPath .. " -- archive already has object named " .. descendant.Name)
			else
				descendant:SetAttribute("ArchivedBy", MIGRATION_ID)
				descendant:SetAttribute("OriginalPath", originalPath)
				descendant:SetAttribute("ArchiveReason", reason)
				descendant.Parent = destination
				table.insert(moved, originalPath .. " -> " .. destination:GetFullName() .. "." .. descendant.Name)
			end
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			if descendant.Disabled and startsWith(descendant.Name, "HOVER_RACING") then
				table.insert(skipped, descendant:GetFullName() .. " -- " .. reason)
			end
		end
	end
end

local reportLines = {
	"# Neo Tokyo Racers Disabled Legacy Script Archive Report",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"Archive target: `ServerStorage.NeoTokyoRacers_LegacyArchive.DisabledScripts`",
	"",
	"This script moved disabled legacy HOVER_RACING scripts only.",
	"It did not delete anything and did not touch active scripts, `TEMP_LightingPreview`, or `Workspace.Test + WIP Assets`.",
	"",
	"Moved count: " .. tostring(#moved),
	"Skipped count: " .. tostring(#skipped),
	"",
	"## Moved",
}

if #moved == 0 then
	table.insert(reportLines, "- None.")
else
	for _, line in ipairs(moved) do
		table.insert(reportLines, "- " .. line)
	end
end

table.insert(reportLines, "")
table.insert(reportLines, "## Skipped")
if #skipped == 0 then
	table.insert(reportLines, "- None.")
else
	for _, line in ipairs(skipped) do
		table.insert(reportLines, "- " .. line)
	end
end

table.insert(reportLines, "")
table.insert(reportLines, "## Play-Test Checklist")
table.insert(reportLines, "- Menus open normally.")
table.insert(reportLines, "- Cockpit/module purchase and customisation still work.")
table.insert(reportLines, "- Vehicle spawns and drives.")
table.insert(reportLines, "- Mobile HUD still appears on mobile and PC HUD does not flicker.")
table.insert(reportLines, "- Lighting preview still responds to its test keys.")

local reportFolder = replicatedStorage:FindFirstChild(REPORT_FOLDER_NAME)
if not reportFolder then
	reportFolder = Instance.new("Folder")
	reportFolder.Name = REPORT_FOLDER_NAME
	reportFolder.Parent = replicatedStorage
end

local reportValue = reportFolder:FindFirstChild(REPORT_VALUE_NAME)
if not reportValue then
	reportValue = Instance.new("StringValue")
	reportValue.Name = REPORT_VALUE_NAME
	reportValue.Parent = reportFolder
end
reportValue.Value = table.concat(reportLines, "\n")

print("[NTR Cleanup] Disabled legacy archive complete.")
print("[NTR Cleanup] Moved disabled scripts: " .. tostring(#moved))
print("[NTR Cleanup] Skipped: " .. tostring(#skipped))
print("[NTR Cleanup] Report written to ReplicatedStorage." .. REPORT_FOLDER_NAME .. "." .. REPORT_VALUE_NAME)
