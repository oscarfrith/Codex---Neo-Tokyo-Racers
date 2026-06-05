-- Neo Tokyo Racers - Export Full Studio Snapshot For GitHub
-- Paste this whole script into the Roblox Studio Command Bar.
--
-- Best workflow:
-- - Run scripts/receive_studio_full_snapshot_export.py locally first.
-- - Run this script in Studio.
-- - Studio will try to send the export to the local receiver automatically.
--
-- Fallback workflow:
-- - If local HTTP is unavailable, this writes chunked StringValues to
--   ReplicatedStorage.NTR_STUDIO_FULL_EXPORT_V2 for manual copying.
--
-- What this does:
-- - Captures a hierarchy snapshot for the main game services.
-- - Exports all Script, LocalScript, and ModuleScript sources from those services.
-- - Records useful metadata: ClassName, path parts, Disabled state, attributes,
--   source line counts, simple checksums, and source byte counts.
--
-- What this does NOT do:
-- - It does not move, rename, disable, delete, clone, or edit gameplay objects.
-- - It only replaces its own export StringValues/folder in ReplicatedStorage.

local EXPORT_FOLDER_NAME = "NTR_STUDIO_FULL_EXPORT_V2"
local EXPORT_CHUNK_PREFIX = "StudioExport_"
local CHUNK_LIMIT = 18000
local TRY_LOCAL_HTTP_RECEIVER = true
local LOCAL_RECEIVER_URL = "http://127.0.0.1:8765/ntr-studio-export"

local INCLUDE_DISABLED_SCRIPTS = true
local INCLUDE_TEST_WIP_ASSETS = true

local HttpService = game:GetService("HttpService")

local serviceNamesToScan = {
	"ReplicatedStorage",
	"ServerScriptService",
	"StarterPlayer",
	"StarterGui",
	"Workspace",
	"ServerStorage",
	"Lighting",
}

local base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function isExporterPath(path)
	return path == "ReplicatedStorage." .. EXPORT_FOLDER_NAME or startsWith(path, "ReplicatedStorage." .. EXPORT_FOLDER_NAME .. ".")
end

local function isExcludedPath(path)
	if isExporterPath(path) then
		return true, "export folder"
	end
	if not INCLUDE_TEST_WIP_ASSETS and startsWith(path, "Workspace.Test + WIP Assets") then
		return true, "excluded Test + WIP Assets"
	end
	return false, ""
end

local function isScriptLike(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function getPathParts(instance)
	local parts = {}
	local cursor = instance
	while cursor and cursor ~= game do
		table.insert(parts, 1, cursor.Name)
		cursor = cursor.Parent
	end
	return parts
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

local function serialiseValue(value)
	local valueType = typeof(value)
	if valueType == "string" or valueType == "number" or valueType == "boolean" then
		return { type = valueType, value = value }
	end
	if valueType == "Color3" then
		return { type = valueType, r = value.R, g = value.G, b = value.B, text = tostring(value) }
	end
	if valueType == "Vector2" then
		return { type = valueType, x = value.X, y = value.Y, text = tostring(value) }
	end
	if valueType == "Vector3" then
		return { type = valueType, x = value.X, y = value.Y, z = value.Z, text = tostring(value) }
	end
	if valueType == "UDim" then
		return { type = valueType, scale = value.Scale, offset = value.Offset, text = tostring(value) }
	end
	if valueType == "UDim2" then
		return {
			type = valueType,
			xScale = value.X.Scale,
			xOffset = value.X.Offset,
			yScale = value.Y.Scale,
			yOffset = value.Y.Offset,
			text = tostring(value),
		}
	end
	if valueType == "BrickColor" then
		return { type = valueType, name = value.Name, number = value.Number, text = tostring(value) }
	end
	if valueType == "NumberRange" then
		return { type = valueType, min = value.Min, max = value.Max, text = tostring(value) }
	end
	if valueType == "NumberSequence" or valueType == "ColorSequence" or valueType == "EnumItem" then
		return { type = valueType, text = tostring(value) }
	end
	return { type = valueType, text = tostring(value) }
end

local function getAttributes(instance)
	local attributes = {}
	local ok, rawAttributes = pcall(function()
		return instance:GetAttributes()
	end)
	if not ok then
		return attributes
	end
	for key, value in pairs(rawAttributes) do
		attributes[key] = serialiseValue(value)
	end
	return attributes
end

local function getDisabled(instance)
	if instance:IsA("Script") or instance:IsA("LocalScript") then
		return instance.Disabled
	end
	return false
end

local scriptRecords = {}
local skipped = {}

local function makeNode(instance)
	local fullPath = instance:GetFullName()
	local excluded, reason = isExcludedPath(fullPath)
	if excluded then
		table.insert(skipped, { path = fullPath, reason = reason })
		return nil
	end

	local node = {
		name = instance.Name,
		class_name = instance.ClassName,
		path = fullPath,
		path_parts = getPathParts(instance),
		attributes = getAttributes(instance),
		children = {},
	}

	if isScriptLike(instance) then
		local disabled = getDisabled(instance)
		if disabled and not INCLUDE_DISABLED_SCRIPTS then
			table.insert(skipped, { path = fullPath, reason = "disabled script export disabled" })
		else
			local source = getSource(instance)
			local scriptRecord = {
				id = "script_" .. string.format("%04d", #scriptRecords + 1),
				name = instance.Name,
				class_name = instance.ClassName,
				path = fullPath,
				path_parts = getPathParts(instance),
				disabled = disabled,
				attributes = node.attributes,
				source_lines = countLines(source),
				source_bytes = #source,
				source_checksum = simpleChecksum(source),
				source_base64 = base64Encode(source),
			}
			table.insert(scriptRecords, scriptRecord)
			node.script_id = scriptRecord.id
			node.disabled = disabled
			node.source_lines = scriptRecord.source_lines
			node.source_checksum = scriptRecord.source_checksum
		end
	end

	local children = instance:GetChildren()
	table.sort(children, function(a, b)
		if a.ClassName == b.ClassName then
			return a.Name < b.Name
		end
		return a.ClassName < b.ClassName
	end)

	for _, child in ipairs(children) do
		local childNode = makeNode(child)
		if childNode then
			table.insert(node.children, childNode)
		end
	end

	return node
end

local services = {}
for _, serviceName in ipairs(serviceNamesToScan) do
	local service = game:GetService(serviceName)
	local node = makeNode(service)
	if node then
		table.insert(services, node)
	end
end

table.sort(skipped, function(a, b)
	return a.path < b.path
end)

local payload = {
	format = "NTR_STUDIO_FULL_EXPORT_V2",
	generated_in_studio = os.date("%Y-%m-%d %H:%M:%S"),
	place_id = game.PlaceId,
	job_id = game.JobId,
	include_disabled_scripts = INCLUDE_DISABLED_SCRIPTS,
	include_test_wip_assets = INCLUDE_TEST_WIP_ASSETS,
	services_scanned = serviceNamesToScan,
	script_count = #scriptRecords,
	skipped_count = #skipped,
	hierarchy = services,
	scripts = scriptRecords,
	skipped = skipped,
}

local exportText = "NTR_STUDIO_FULL_EXPORT_V2\n" .. HttpService:JSONEncode(payload) .. "\nNTR_STUDIO_FULL_EXPORT_END\n"

local sentToReceiver = false
local receiverMessage = ""
if TRY_LOCAL_HTTP_RECEIVER then
	local ok, response = pcall(function()
		return HttpService:PostAsync(LOCAL_RECEIVER_URL, exportText, Enum.HttpContentType.TextPlain, false)
	end)
	if ok then
		sentToReceiver = true
		receiverMessage = tostring(response)
	else
		receiverMessage = tostring(response)
	end
end

local replicatedStorage = game:GetService("ReplicatedStorage")
local exportFolder = replicatedStorage:FindFirstChild(EXPORT_FOLDER_NAME)
if not exportFolder then
	exportFolder = Instance.new("Folder")
	exportFolder.Name = EXPORT_FOLDER_NAME
	exportFolder.Parent = replicatedStorage
end

for _, child in ipairs(exportFolder:GetChildren()) do
	if child:IsA("StringValue") then
		child:Destroy()
	end
end

local readme = Instance.new("StringValue")
readme.Name = "README_HOW_TO_IMPORT"

if sentToReceiver then
	readme.Value = table.concat({
		"Export was sent to the local receiver successfully.",
		"You do not need to copy StudioExport chunks for this run.",
		"Check PowerShell for the import result.",
		"",
		"Receiver response:",
		receiverMessage,
	}, "\n")
	readme.Parent = exportFolder
else
	readme.Value = table.concat({
		"Local receiver was not used or did not respond, so chunk fallback was created.",
		"Common fix: run python scripts/receive_studio_full_snapshot_export.py first and enable Studio HTTP requests.",
		"",
		"Copy StudioExport_001, StudioExport_002, StudioExport_003, etc. in order.",
		"Paste the values into docs/studio-full-export-paste.txt on your computer.",
		"Then run from the repo folder:",
		"python scripts/import_studio_full_snapshot_export.py docs/studio-full-export-paste.txt",
		"",
		"Local receiver error:",
		receiverMessage,
	}, "\n")
	readme.Parent = exportFolder

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

	print("[NTR Studio Export V2] Chunks written: " .. tostring(chunkIndex - 1))
end

print("[NTR Studio Export V2] Export complete.")
print("[NTR Studio Export V2] Scripts exported: " .. tostring(#scriptRecords))
print("[NTR Studio Export V2] Skipped entries: " .. tostring(#skipped))
if sentToReceiver then
	print("[NTR Studio Export V2] Sent to local receiver: " .. LOCAL_RECEIVER_URL)
else
	print("[NTR Studio Export V2] Local receiver unavailable; copy fallback chunks from ReplicatedStorage." .. EXPORT_FOLDER_NAME)
	print("[NTR Studio Export V2] Receiver error: " .. receiverMessage)
end
