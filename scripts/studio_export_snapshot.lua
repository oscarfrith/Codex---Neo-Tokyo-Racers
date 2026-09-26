-- Roblox - Export Full Studio Snapshot For GitHub
-- Paste this whole script into the Roblox Studio Command Bar.
--
-- Best workflow:
-- - Run scripts/receive_studio_snapshot.py locally first.
-- - Run this script in Studio.
-- - Studio sends the export to the local receiver in HTTP chunks under Roblox's 1024 KB post limit.
--
-- Receiver-only export: failure stops without creating Studio objects or dumps.
--
-- What this does:
-- - Captures a hierarchy snapshot for the main game services.
-- - Exports all Script, LocalScript, and ModuleScript sources from those services.
-- - Records useful metadata: ClassName, path parts, Disabled state, attributes,
--   source line counts, simple checksums, source byte counts and scoped properties.
--
-- What this does NOT do:
-- - It does not move, rename, disable, delete, clone, or edit gameplay objects.
-- - All exports are read-only in Studio; there is no instance-writing fallback.

local HISTORICAL_EXPORT_FOLDER_NAME = "NTR_STUDIO_FULL_EXPORT_V2" -- Read-only exclusion for historical dumps, never created.
local EXPECTED_PLACE_ID = 71491191583884 -- Space Racers v2 (current target since 2026-09-26; v1 was 121304917315753)
local LOCAL_RECEIVER_CHUNK_URL = "http://127.0.0.1:8765/studio-snapshot-chunk"
local HTTP_CHUNK_LIMIT = 180000 -- Headroom for JSON escaping inside the transport envelope.

local INCLUDE_DISABLED_SCRIPTS = true
local INCLUDE_TEST_WIP_ASSETS = true

local HttpService = game:GetService("HttpService")
assert(game.PlaceId == EXPECTED_PLACE_ID, "BLOCKER: wrong place; select Space Racers v2")
assert(not game:GetService("RunService"):IsRunning(), "BLOCKER: export the Edit datamodel")
local diagnostics = { property_read_errors = {}, duplicate_paths = {} }
local pathCounts = {}

local serviceNamesToScan = {
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"StarterPlayer",
	"StarterGui",
	"SoundService",
	"Workspace",
	"ServerStorage",
	"Lighting",
}

local base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function isExporterPath(path)
	return path == "ReplicatedStorage." .. HISTORICAL_EXPORT_FOLDER_NAME or startsWith(path, "ReplicatedStorage." .. HISTORICAL_EXPORT_FOLDER_NAME .. ".")
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
	error("BLOCKER: cannot read source " .. scriptInstance:GetFullName() .. ": " .. tostring(source))
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
	if valueType == "CFrame" then
		return { type = valueType, components = { value:GetComponents() } }
	end
	if valueType == "Instance" then
		return { type = valueType, path = value:GetFullName(), path_parts = getPathParts(value) }
	end
	if valueType == "nil" then return { type = "nil" } end
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
		error("BLOCKER: cannot read attributes " .. instance:GetFullName())
	end
	for key, value in pairs(rawAttributes) do
		attributes[key] = serialiseValue(value)
	end
	return attributes
end

-- Explicit coverage, not a place backup. Unsupported/version-specific properties are reported.
local propertySchema = {
	BasePart = { "CFrame", "Size", "Anchored", "CanCollide", "CanTouch", "CanQuery", "CollisionGroup", "Transparency", "CastShadow", "Material", "Color" },
	Model = { "PrimaryPart", "ModelStreamingMode" },
	ValueBase = { "Value" },
	BaseScript = { "Enabled", "RunContext" },
	GuiObject = { "Position", "Size", "AnchorPoint", "Visible", "ZIndex", "BackgroundTransparency" },
	ScreenGui = { "Enabled", "ResetOnSpawn", "IgnoreGuiInset", "DisplayOrder" },
	Light = { "Enabled", "Brightness", "Color", "Shadows" },
	SurfaceLight = { "Range", "Angle", "Face" },
	PointLight = { "Range" },
	SpotLight = { "Range", "Angle", "Face" },
	ProximityPrompt = { "Enabled", "MaxActivationDistance", "HoldDuration", "RequiresLineOfSight" },
	Workspace = { "StreamingEnabled", "Gravity" },
	StarterGui = { "ScreenOrientation" },
	Lighting = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient" },
}

local function getProperties(instance)
	local properties = {}
	for className, names in pairs(propertySchema) do
		if instance:IsA(className) then
			for _, name in ipairs(names) do
				-- RunContext is not available on LocalScript in every Studio version.
				if name == "RunContext" and not instance:IsA("Script") then continue end
				local ok, value = pcall(function() return instance[name] end)
				if ok then properties[name] = serialiseValue(value)
				else table.insert(diagnostics.property_read_errors, { path = instance:GetFullName(), property = name, error = tostring(value) }) end
			end
		end
	end
	return properties
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
	pathCounts[fullPath] = (pathCounts[fullPath] or 0) + 1

	local node = {
		name = instance.Name,
		class_name = instance.ClassName,
		path = fullPath,
		path_parts = getPathParts(instance),
		attributes = getAttributes(instance),
		properties = getProperties(instance),
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
	format = "STUDIO_SNAPSHOT_V1",
	schema_revision = 3,
	property_schema = propertySchema,
	diagnostics = diagnostics,
	export_mode = "Edit",
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

for path, count in pairs(pathCounts) do
	if count > 1 then table.insert(diagnostics.duplicate_paths, { path = path, count = count }) end
end
table.sort(diagnostics.duplicate_paths, function(a, b) return a.path < b.path end)

local exportText = "STUDIO_SNAPSHOT_V1\n" .. HttpService:JSONEncode(payload) .. "\nSTUDIO_SNAPSHOT_END\n"

local function sendToLocalReceiverInChunks(text)
	local chunks = {}
	local start = 1
	while start <= #text do
		local last = math.min(#text, start + HTTP_CHUNK_LIMIT - 1)
		-- Do not split a UTF-8 codepoint between JSON transport strings.
		while last < #text and string.byte(text, last + 1) >= 128 and string.byte(text, last + 1) < 192 do last -= 1 end
		table.insert(chunks, text:sub(start, last))
		start = last + 1
	end
	local total = #chunks
	local exportId = tostring(game.PlaceId) .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
	local finalResponse = ""

	for index = 1, total do
		local chunk = chunks[index]
		local body = HttpService:JSONEncode({
			export_id = exportId,
			index = index,
			total = total,
			data = chunk,
		})
		local response = HttpService:PostAsync(LOCAL_RECEIVER_CHUNK_URL, body, Enum.HttpContentType.ApplicationJson, false)
		finalResponse = tostring(response)
		if index == total or index % 25 == 0 then print("[NTR Studio Export V2] Sent HTTP chunk " .. tostring(index) .. " of " .. tostring(total)) end
	end

	return finalResponse, total
end

local ok, response = pcall(sendToLocalReceiverInChunks, exportText)
assert(ok, "BLOCKER: receiver unavailable or import failed; no Studio objects changed. " .. tostring(response))
print("[NTR Studio Export V2] PASS: read-only HTTP export; scripts=" .. #scriptRecords .. "; schema=3; propertyWarnings=" .. #diagnostics.property_read_errors .. "; duplicatePaths=" .. #diagnostics.duplicate_paths)
