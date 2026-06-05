-- Neo Tokyo Racers - Active Script Audit
-- Paste this whole script into the Roblox Studio Command Bar.
--
-- What this does:
-- - Finds active Scripts and LocalScripts across the main services.
-- - Flags scripts outside approved Neo Tokyo Racers live roots.
-- - Highlights generic, temporary, WIP/test, and legacy scripts.
-- - Writes a readable report to ReplicatedStorage.NTR_AUDIT_REPORTS.
--
-- What this does NOT do:
-- - It does not disable, move, rename, delete, clone, or edit gameplay scripts.

local REPORT_FOLDER_NAME = "NTR_AUDIT_REPORTS"
local REPORT_NAME_PREFIX = "ActiveScriptAudit"
local REPORT_CHUNK_LIMIT = 18000

local servicesToScan = {
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	game:GetService("StarterPlayer"),
	game:GetService("StarterGui"),
	game:GetService("Workspace"),
	game:GetService("ServerStorage"),
	game:GetService("Lighting"),
}

local approvedExactPaths = {
	["ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server"] = true,
	["ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition"] = true,
	["ServerScriptService.Lighting.LightingController"] = true,
	["ServerScriptService.Traffic Lights"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V64_CachedThrustVisualRuntime"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls"] = true,
	["StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor"] = true,
	["StarterPlayer.StarterPlayerScripts.LOD System"] = true,
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = true,
}

local approvedPrefixPaths = {
	"ReplicatedStorage.HOVER_RACING_V2_KIT.",
	"ReplicatedStorage.NeoTokyoRacers.",
	"ServerScriptService.NeoTokyoRacers.",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.",
	"StarterGui.NeoTokyoRacersUI.",
	"Workspace.NeoTokyoRacersWorld.",
}

local knownExcludedPrefixPaths = {
	"Workspace.Test + WIP Assets.",
}

local intentionalTemporaryExactPaths = {
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = "intentional day/night lighting preview tool",
}

local function getPath(instance)
	return instance:GetFullName()
end

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function pathMatchesPrefix(path, prefixes)
	for _, prefix in ipairs(prefixes) do
		if startsWith(path, prefix) then
			return true
		end
	end
	return false
end

local function isApprovedPath(path)
	return approvedExactPaths[path] == true or pathMatchesPrefix(path, approvedPrefixPaths)
end

local function isKnownExcluded(path)
	return pathMatchesPrefix(path, knownExcludedPrefixPaths)
end

local function getIntentionalTemporaryReason(path)
	return intentionalTemporaryExactPaths[path]
end

local function hasSuspiciousName(instance)
	local name = instance.Name
	if name == "LocalScript" or name == "Script" then
		return true, "generic script name"
	end
	if string.find(string.lower(name), "temp", 1, true) then
		return true, "TEMP name"
	end
	if string.find(string.lower(name), "test", 1, true) then
		return true, "test name"
	end
	if string.find(string.lower(name), "wip", 1, true) then
		return true, "WIP name"
	end
	return false, ""
end

local function lineFor(instance, note)
	local disabled = ""
	if instance:IsA("Script") or instance:IsA("LocalScript") then
		disabled = " Disabled=" .. tostring(instance.Disabled)
	end
	return "- " .. getPath(instance) .. " <" .. instance.ClassName .. ">" .. disabled .. (note and note ~= "" and (" -- " .. note) or "")
end

local activeApproved = {}
local activeUnexpected = {}
local activeKnownExcluded = {}
local activeIntentionalTemporary = {}
local disabledLegacy = {}
local moduleScripts = {}
local suspiciousNames = {}

for _, service in ipairs(servicesToScan) do
	for _, instance in ipairs(service:GetDescendants()) do
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			local path = getPath(instance)
			local suspicious, reason = hasSuspiciousName(instance)
			local intentionalTemporaryReason = getIntentionalTemporaryReason(path)
			if intentionalTemporaryReason then
				table.insert(activeIntentionalTemporary, lineFor(instance, intentionalTemporaryReason))
			elseif suspicious then
				table.insert(suspiciousNames, lineFor(instance, reason))
			end

			if instance.Disabled then
				table.insert(disabledLegacy, lineFor(instance, "disabled"))
			elseif isKnownExcluded(path) then
				table.insert(activeKnownExcluded, lineFor(instance, "active inside excluded Test/WIP area"))
			elseif isApprovedPath(path) then
				table.insert(activeApproved, lineFor(instance, "approved current live script"))
			else
				table.insert(activeUnexpected, lineFor(instance, "active outside approved roots"))
			end
		elseif instance:IsA("ModuleScript") then
			local path = getPath(instance)
			if not isApprovedPath(path) and not isKnownExcluded(path) then
				table.insert(moduleScripts, lineFor(instance, "ModuleScript outside approved roots"))
			end
		end
	end
end

table.sort(activeApproved)
table.sort(activeUnexpected)
table.sort(activeKnownExcluded)
table.sort(activeIntentionalTemporary)
table.sort(disabledLegacy)
table.sort(moduleScripts)
table.sort(suspiciousNames)

local function section(title, lines)
	local output = {}
	table.insert(output, "")
	table.insert(output, "## " .. title .. " (" .. tostring(#lines) .. ")")
	if #lines == 0 then
		table.insert(output, "- None found.")
	else
		for _, line in ipairs(lines) do
			table.insert(output, line)
		end
	end
	return table.concat(output, "\n")
end

local reportLines = {
	"# Neo Tokyo Racers Active Script Audit",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"Purpose: identify scripts that are active but not part of the approved/current Neo Tokyo Racers live roots.",
	"",
	"Read-only audit: no scripts were moved, renamed, disabled, deleted, cloned, or edited.",
	"",
	"Approved active script count: " .. tostring(#activeApproved),
	"Unexpected active script count: " .. tostring(#activeUnexpected),
	"Active scripts inside excluded Test/WIP area: " .. tostring(#activeKnownExcluded),
	"Intentional temporary active tool count: " .. tostring(#activeIntentionalTemporary),
	"Disabled script count: " .. tostring(#disabledLegacy),
	"ModuleScripts outside approved roots: " .. tostring(#moduleScripts),
	"Suspicious/generic names: " .. tostring(#suspiciousNames),
	section("Unexpected Active Scripts To Review First", activeUnexpected),
	section("Active Scripts Inside Excluded Test + WIP Assets", activeKnownExcluded),
	section("Intentional Temporary Active Tools", activeIntentionalTemporary),
	section("Approved Active Current Live Scripts", activeApproved),
	section("Generic / TEMP / Test / WIP Script Names", suspiciousNames),
	section("Disabled Legacy Scripts", disabledLegacy),
	section("ModuleScripts Outside Approved Roots", moduleScripts),
	"",
	"## Suggested Next Step",
	"- If unexpected active scripts are found, inspect them before deleting or disabling anything.",
	"- `TEMP_LightingPreview` is intentionally kept as a day/night lighting preview tool.",
	"- The most likely cleanup candidates are generic active LocalScripts and active scripts inside Workspace.Test + WIP Assets.",
	"- Do not touch Test + WIP Assets unless you intentionally decide to isolate that folder.",
}

local report = table.concat(reportLines, "\n")

local replicatedStorage = game:GetService("ReplicatedStorage")
local reportFolder = replicatedStorage:FindFirstChild(REPORT_FOLDER_NAME)
if not reportFolder then
	reportFolder = Instance.new("Folder")
	reportFolder.Name = REPORT_FOLDER_NAME
	reportFolder.Parent = replicatedStorage
end

for _, child in ipairs(reportFolder:GetChildren()) do
	if child:IsA("StringValue") and startsWith(child.Name, REPORT_NAME_PREFIX .. "_") then
		child:Destroy()
	end
end

local chunkIndex = 1
local cursor = 1
while cursor <= #report do
	local chunk = string.sub(report, cursor, cursor + REPORT_CHUNK_LIMIT - 1)
	local value = Instance.new("StringValue")
	value.Name = REPORT_NAME_PREFIX .. "_" .. string.format("%03d", chunkIndex)
	value.Value = chunk
	value.Parent = reportFolder
	cursor = cursor + REPORT_CHUNK_LIMIT
	chunkIndex = chunkIndex + 1
end

print("[NTR Audit] Active script audit complete.")
print("[NTR Audit] Unexpected active scripts: " .. tostring(#activeUnexpected))
print("[NTR Audit] Active scripts inside Test + WIP Assets: " .. tostring(#activeKnownExcluded))
print("[NTR Audit] Report written to ReplicatedStorage." .. REPORT_FOLDER_NAME)
