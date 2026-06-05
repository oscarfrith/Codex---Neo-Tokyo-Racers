-- Neo Tokyo Racers - Export Roblox Studio Scripts For GitHub
-- Paste this whole script into the Roblox Studio Command Bar.
--
-- What this does:
-- - Reads Script, LocalScript, and ModuleScript source from the main game services.
-- - Encodes source safely as base64 text.
-- - Writes chunked export text to ReplicatedStorage.NTR_GITHUB_SCRIPT_EXPORT.
--
-- What this does NOT do:
-- - It does not move, rename, disable, delete, clone, or edit any game object.
-- - It does not write to your local filesystem directly. Roblox Studio does not allow
--   normal command-bar scripts to write arbitrary repo files.
--
-- Default behaviour:
-- - Excludes Workspace["Test + WIP Assets"].
-- - Includes disabled legacy scripts, because GitHub is useful as a historical source backup.

local EXPORT_FOLDER_NAME = "NTR_GITHUB_SCRIPT_EXPORT"
local EXPORT_CHUNK_PREFIX = "ScriptExport_"
local CHUNK_LIMIT = 18000

local INCLUDE_DISABLED_SCRIPTS = true
local INCLUDE_TEST_WIP_ASSETS = false

local servicesToScan = {
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	game:GetService("StarterPlayer"),
	game:GetService("StarterGui"),
	game:GetService("Workspace"),
	game:GetService("ServerStorage"),
	game:GetService("Lighting"),
}

local base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function isExcludedPath(path)
	if not INCLUDE_TEST_WIP_ASSETS and startsWith(path, "Workspace.Test + WIP Assets.") then
		return true, "excluded Test + WIP Assets"
	end
	return false, ""
end

local function isScriptLike(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function getSource(scriptInstance)
	local ok, source = pcall(function()
		return scriptInstance.Source
	end)

	if ok and typeof(source) == "string" then
		return source
	end

	return ""
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

local function base64Encode(data)
	return ((data:gsub(".", function(character)
		local byte = character:byte()
		local bits = ""
		for index = 8, 1, -1 do
			local power = 2 ^ (index - 1)
			bits = bits .. ((byte % (power * 2) - byte % power > 0) and "1" or "0")
		end
		return bits
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
		if #bits < 6 then
			return ""
		end
		local value = 0
		for index = 1, 6 do
			if bits:sub(index, index) == "1" then
				value = value + 2 ^ (6 - index)
			end
		end
		return base64Alphabet:sub(value + 1, value + 1)
	end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

local function wrapText(text, width)
	local lines = {}
	width = width or 76
	for index = 1, #text, width do
		table.insert(lines, text:sub(index, index + width - 1))
	end
	return table.concat(lines, "\n")
end

local function getDisabledText(instance)
	if instance:IsA("Script") or instance:IsA("LocalScript") then
		return tostring(instance.Disabled)
	end
	return "false"
end

local foundScripts = {}
local skipped = {}

for _, service in ipairs(servicesToScan) do
	for _, instance in ipairs(service:GetDescendants()) do
		if isScriptLike(instance) then
			local path = instance:GetFullName()
			local excluded, reason = isExcludedPath(path)
			local disabled = (instance:IsA("Script") or instance:IsA("LocalScript")) and instance.Disabled

			if excluded then
				table.insert(skipped, path .. " -- " .. reason)
			elseif disabled and not INCLUDE_DISABLED_SCRIPTS then
				table.insert(skipped, path .. " -- disabled script export disabled")
			else
				table.insert(foundScripts, instance)
			end
		end
	end
end

table.sort(foundScripts, function(a, b)
	return a:GetFullName() < b:GetFullName()
end)
table.sort(skipped)

local exportLines = {
	"NTR_SCRIPT_EXPORT_V1",
	"GeneratedInStudio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"IncludeDisabledScripts: " .. tostring(INCLUDE_DISABLED_SCRIPTS),
	"IncludeTestWIPAssets: " .. tostring(INCLUDE_TEST_WIP_ASSETS),
	"ScriptCount: " .. tostring(#foundScripts),
	"SkippedCount: " .. tostring(#skipped),
	"",
}

for _, scriptInstance in ipairs(foundScripts) do
	local source = getSource(scriptInstance)
	table.insert(exportLines, "BEGIN_SCRIPT")
	table.insert(exportLines, "Path: " .. scriptInstance:GetFullName())
	table.insert(exportLines, "ClassName: " .. scriptInstance.ClassName)
	table.insert(exportLines, "Disabled: " .. getDisabledText(scriptInstance))
	table.insert(exportLines, "SourceLines: " .. tostring(countLines(source)))
	table.insert(exportLines, "SourceChecksum: " .. simpleChecksum(source))
	table.insert(exportLines, "SourceBase64Begin")
	table.insert(exportLines, wrapText(base64Encode(source), 76))
	table.insert(exportLines, "SourceBase64End")
	table.insert(exportLines, "END_SCRIPT")
	table.insert(exportLines, "")
end

table.insert(exportLines, "BEGIN_SKIPPED")
if #skipped == 0 then
	table.insert(exportLines, "None")
else
	for _, line in ipairs(skipped) do
		table.insert(exportLines, line)
	end
end
table.insert(exportLines, "END_SKIPPED")
table.insert(exportLines, "NTR_SCRIPT_EXPORT_END")

local exportText = table.concat(exportLines, "\n")

local replicatedStorage = game:GetService("ReplicatedStorage")
local exportFolder = replicatedStorage:FindFirstChild(EXPORT_FOLDER_NAME)
if not exportFolder then
	exportFolder = Instance.new("Folder")
	exportFolder.Name = EXPORT_FOLDER_NAME
	exportFolder.Parent = replicatedStorage
end

for _, child in ipairs(exportFolder:GetChildren()) do
	if child:IsA("StringValue") and startsWith(child.Name, EXPORT_CHUNK_PREFIX) then
		child:Destroy()
	end
end

local readme = exportFolder:FindFirstChild("README_HOW_TO_IMPORT")
if not readme then
	readme = Instance.new("StringValue")
	readme.Name = "README_HOW_TO_IMPORT"
	readme.Parent = exportFolder
end
readme.Value = table.concat({
	"Copy the values from ScriptExport_001, ScriptExport_002, etc. into:",
	"docs/studio-script-export-paste.txt",
	"",
	"Then run locally from the repo:",
	"python scripts/import_studio_script_export.py docs/studio-script-export-paste.txt",
	"",
	"The importer writes files into roblox/exported_scripts/."
}, "\n")

local chunkIndex = 1
local cursor = 1
while cursor <= #exportText do
	local chunk = exportText:sub(cursor, cursor + CHUNK_LIMIT - 1)
	local valueObject = Instance.new("StringValue")
	valueObject.Name = EXPORT_CHUNK_PREFIX .. string.format("%03d", chunkIndex)
	valueObject.Value = chunk
	valueObject.Parent = exportFolder

	cursor = cursor + CHUNK_LIMIT
	chunkIndex = chunkIndex + 1
end

print("[NTR GitHub Export] Script export complete.")
print("[NTR GitHub Export] Scripts exported: " .. tostring(#foundScripts))
print("[NTR GitHub Export] Skipped: " .. tostring(#skipped))
print("[NTR GitHub Export] Chunks written: " .. tostring(chunkIndex - 1))
print("[NTR GitHub Export] Folder: ReplicatedStorage." .. EXPORT_FOLDER_NAME)
