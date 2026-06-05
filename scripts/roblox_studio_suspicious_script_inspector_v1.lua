-- Neo Tokyo Racers - Suspicious Script Inspector
-- Paste this whole script into the Roblox Studio Command Bar.
--
-- Run after:
-- scripts/roblox_studio_active_script_audit_v1.lua
--
-- What this does:
-- - Reads active scripts outside the approved/current live roots.
-- - Reads generic/TEMP/test/WIP active scripts.
-- - Captures line counts, a simple source fingerprint, service usage, and a source preview.
-- - Writes a report to ReplicatedStorage.NTR_AUDIT_REPORTS.
--
-- What this does NOT do:
-- - It does not disable, move, rename, delete, clone, or edit gameplay scripts.

local REPORT_FOLDER_NAME = "NTR_AUDIT_REPORTS"
local REPORT_NAME_PREFIX = "SuspiciousScriptInspector"
local REPORT_CHUNK_LIMIT = 18000
local MAX_PREVIEW_LINES = 80

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
	local lowerName = string.lower(name)
	if name == "LocalScript" or name == "Script" then
		return true, "generic script name"
	end
	if string.find(lowerName, "temp", 1, true) then
		return true, "TEMP name"
	end
	if string.find(lowerName, "test", 1, true) then
		return true, "test name"
	end
	if string.find(lowerName, "wip", 1, true) then
		return true, "WIP name"
	end
	return false, ""
end

local function getSource(scriptInstance)
	local ok, source = pcall(function()
		return scriptInstance.Source
	end)

	if ok and typeof(source) == "string" then
		return source, nil
	end

	return "", "Could not read Source property in this context."
end

local function countLines(source)
	if source == "" then
		return 0
	end

	local _, newlineCount = string.gsub(source, "\n", "")
	return newlineCount + 1
end

local function simpleChecksum(source)
	local checksum = 0
	for index = 1, #source do
		checksum = (checksum + (string.byte(source, index) or 0) * index) % 1000000007
	end
	return tostring(checksum)
end

local function previewSource(source)
	local lines = {}
	local lineCount = 0

	for line in string.gmatch(source .. "\n", "(.-)\n") do
		lineCount = lineCount + 1
		if lineCount > MAX_PREVIEW_LINES then
			table.insert(lines, "-- Preview truncated at " .. tostring(MAX_PREVIEW_LINES) .. " lines.")
			break
		end
		table.insert(lines, string.format("%03d | %s", lineCount, line))
	end

	if #lines == 0 then
		return "(empty source)"
	end

	return table.concat(lines, "\n")
end

local function findKeywords(source)
	local checks = {
		{"UserInputService", "UserInputService"},
		{"ContextActionService", "ContextActionService"},
		{"RunService", "RunService"},
		{"Players", "Players"},
		{"ReplicatedStorage", "ReplicatedStorage"},
		{"print(", "print"},
		{"warn(", "warn"},
		{"Gamepad", "Gamepad"},
		{"Last input type", "Last input type"},
		{"MouseMovement", "MouseMovement"},
		{"Touch", "Touch"},
		{"Keyboard", "Keyboard"},
		{"RemoteEvent", "RemoteEvent"},
		{"RemoteFunction", "RemoteFunction"},
		{":FireServer", "FireServer"},
		{":InvokeServer", "InvokeServer"},
		{"Humanoid", "Humanoid"},
		{"Camera", "Camera"},
	}

	local found = {}
	for _, check in ipairs(checks) do
		if string.find(source, check[1], 1, true) then
			table.insert(found, check[2])
		end
	end

	if #found == 0 then
		return "none detected"
	end

	return table.concat(found, ", ")
end

local function classify(instance, source)
	local path = instance:GetFullName()
	local suspiciousName, suspiciousReason = hasSuspiciousName(instance)

	if not isApprovedPath(path) and not isKnownExcluded(path) and not instance.Disabled then
		return "Unexpected active script outside approved roots"
	end

	if suspiciousName and not instance.Disabled then
		if string.find(source, "Last input type", 1, true) or string.find(source, "Gamepad enabled", 1, true) then
			return "Likely input/debug logger"
		end
		return "Suspicious active name: " .. suspiciousReason
	end

	if isKnownExcluded(path) and not instance.Disabled then
		return "Active script inside excluded Test/WIP area"
	end

	local intentionalTemporaryReason = getIntentionalTemporaryReason(path)
	if intentionalTemporaryReason and not instance.Disabled then
		return "Intentional temporary tool: " .. intentionalTemporaryReason
	end

	return "Context only"
end

local targets = {}

for _, service in ipairs(servicesToScan) do
	for _, instance in ipairs(service:GetDescendants()) do
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			local path = instance:GetFullName()
			local intentionalTemporaryReason = getIntentionalTemporaryReason(path)
			local suspiciousName = hasSuspiciousName(instance)
			local unexpectedActive = not instance.Disabled and not isApprovedPath(path) and not isKnownExcluded(path)
			local activeExcluded = not instance.Disabled and isKnownExcluded(path)
			local shouldInspect = not intentionalTemporaryReason and (unexpectedActive or activeExcluded or (not instance.Disabled and suspiciousName))

			if shouldInspect then
				table.insert(targets, instance)
			end
		end
	end
end

table.sort(targets, function(a, b)
	return a:GetFullName() < b:GetFullName()
end)

local reportLines = {
	"# Neo Tokyo Racers Suspicious Script Inspector",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"Purpose: inspect active scripts that were unexpected, generic, temporary, test/WIP, or in excluded areas.",
	"",
	"Read-only inspector: no scripts were moved, renamed, disabled, deleted, cloned, or edited.",
	"",
	"Scripts inspected: " .. tostring(#targets),
}

for index, scriptInstance in ipairs(targets) do
	local source, sourceError = getSource(scriptInstance)
	local path = scriptInstance:GetFullName()
	local sourceLines = countLines(source)
	local checksum = simpleChecksum(source)
	local classification = classify(scriptInstance, source)
	local keywords = findKeywords(source)

	table.insert(reportLines, "")
	table.insert(reportLines, "## " .. tostring(index) .. ". " .. path)
	table.insert(reportLines, "")
	table.insert(reportLines, "- Class: `" .. scriptInstance.ClassName .. "`")
	table.insert(reportLines, "- Disabled: `" .. tostring(scriptInstance.Disabled) .. "`")
	table.insert(reportLines, "- Classification: `" .. classification .. "`")
	table.insert(reportLines, "- Source lines: `" .. tostring(sourceLines) .. "`")
	table.insert(reportLines, "- Source checksum: `" .. checksum .. "`")
	table.insert(reportLines, "- Keyword hints: `" .. keywords .. "`")
	if sourceError then
		table.insert(reportLines, "- Source read warning: `" .. sourceError .. "`")
	end
	table.insert(reportLines, "")
	table.insert(reportLines, "```lua")
	table.insert(reportLines, previewSource(source))
	table.insert(reportLines, "```")
end

if #targets == 0 then
	table.insert(reportLines, "")
	table.insert(reportLines, "No suspicious active scripts were found.")
end

table.insert(reportLines, "")
table.insert(reportLines, "## Suggested Next Step")
table.insert(reportLines, "")
table.insert(reportLines, "- If the two generic LocalScripts are only printing input/debug messages, rename or disable them in a separate small cleanup step.")
table.insert(reportLines, "- If they affect controller detection or camera/input behaviour, move them into a named diagnostics/controller location instead.")
table.insert(reportLines, "- `TEMP_LightingPreview` is intentionally excluded from suspicious-script inspection because it is the day/night lighting preview tool.")

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

print("[NTR Inspector] Suspicious script inspection complete.")
print("[NTR Inspector] Scripts inspected: " .. tostring(#targets))
print("[NTR Inspector] Report written to ReplicatedStorage." .. REPORT_FOLDER_NAME)
