--[[
	Neo Tokyo Racers - Studio Inventory Report V1
	Paste into Roblox Studio Command Bar in Edit mode.

	This script inspects the current Explorer hierarchy and creates report chunks at:
	ReplicatedStorage.NTR_INVENTORY_REPORTS

	It does not move, rename, or delete game systems. The only instance it creates is
	the report folder/StringValues so the report is easy to copy back into Codex.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REPORT_FOLDER_NAME = "NTR_INVENTORY_REPORTS"
local REPORT_PREFIX = "Inventory_"
local MAX_DEPTH_GENERAL = 5
local MAX_DEPTH_IMPORTANT = 12
local MAX_NODES_PER_TREE = 3500
local CHUNK_SIZE = 180000

local importantNamePatterns = {
	"neo",
	"tokyo",
	"racer",
	"racing",
	"hover",
	"vehicle",
	"garage",
	"drive",
	"driving",
	"cockpit",
	"module",
	"bruiser",
	"vfx",
	"boost",
	"engine",
	"stabil",
	"race",
	"checkpoint",
	"city",
	"generated",
	"lod",
	"far",
	"traffic",
	"light",
	"config",
	"remote",
	"client",
	"server",
	"runtime",
	"seat",
	"spawn",
	"ui",
}

local importantClasses = {
	Folder = true,
	Model = true,
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	ScreenGui = true,
	Frame = true,
	TextButton = true,
	TextLabel = true,
	ImageButton = true,
	ImageLabel = true,
	Configuration = true,
	NumberValue = true,
	StringValue = true,
	BoolValue = true,
	Color3Value = true,
	ObjectValue = true,
	Attachment = true,
	Beam = true,
	ParticleEmitter = true,
	Trail = true,
	Fire = true,
	Smoke = true,
	Seat = true,
	VehicleSeat = true,
	SpawnLocation = true,
	Sky = true,
	Atmosphere = true,
	BloomEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	SunRaysEffect = true,
}

local rootServices = {
	"ReplicatedStorage",
	"ServerScriptService",
	"StarterPlayer",
	"StarterGui",
	"Workspace",
	"ServerStorage",
	"Lighting",
	"SoundService",
	"Teams",
}

local lines = {}
local classCounts = {}
local warnings = {}

local function add(line)
	table.insert(lines, line or "")
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	if ok then
		return result
	end
	return instance.Name
end

local function sortedChildren(instance)
	local children = instance:GetChildren()
	table.sort(children, function(a, b)
		if a.ClassName == b.ClassName then
			return a.Name < b.Name
		end
		return a.ClassName < b.ClassName
	end)
	return children
end

local function lowerContainsAny(name)
	local lower = string.lower(name)
	for _, pattern in ipairs(importantNamePatterns) do
		if string.find(lower, pattern, 1, true) then
			return true
		end
	end
	return false
end

local function isImportant(instance)
	if importantClasses[instance.ClassName] then
		return true
	end
	if lowerContainsAny(instance.Name) then
		return true
	end
	return false
end

local function buildVisibleSet(root)
	local visible = {
		[root] = true,
	}
	for _, descendant in ipairs(root:GetDescendants()) do
		if isImportant(descendant) then
			local current = descendant
			while current and current ~= root.Parent do
				visible[current] = true
				if current == root then
					break
				end
				current = current.Parent
			end
		end
	end
	return visible
end

local function valueToText(value)
	local valueType = typeof(value)
	if valueType == "Color3" then
		return ("Color3(%d,%d,%d)"):format(math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
	elseif valueType == "Vector3" then
		return ("Vector3(%.3f, %.3f, %.3f)"):format(value.X, value.Y, value.Z)
	elseif valueType == "CFrame" then
		local position = value.Position
		return ("CFrame(pos %.3f, %.3f, %.3f)"):format(position.X, position.Y, position.Z)
	elseif valueType == "BrickColor" then
		return tostring(value)
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType == "Instance" then
		return safeFullName(value)
	end
	return tostring(value)
end

local function attributesText(instance)
	local ok, attrs = pcall(function()
		return instance:GetAttributes()
	end)
	if not ok or not attrs then
		return ""
	end
	local keys = {}
	for key in pairs(attrs) do
		table.insert(keys, key)
	end
	table.sort(keys)
	if #keys == 0 then
		return ""
	end
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. valueToText(attrs[key]))
	end
	return " attrs{" .. table.concat(parts, ", ") .. "}"
end

local function tagsText(instance)
	local ok, tags = pcall(function()
		return CollectionService:GetTags(instance)
	end)
	if not ok or #tags == 0 then
		return ""
	end
	table.sort(tags)
	return " tags{" .. table.concat(tags, ", ") .. "}"
end

local function scriptMeta(instance)
	if not (instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")) then
		return ""
	end
	local parts = {}
	if instance:IsA("Script") or instance:IsA("LocalScript") then
		table.insert(parts, "Disabled=" .. tostring(instance.Disabled))
	end
	if instance:IsA("Script") then
		local okRunContext, runContext = pcall(function()
			return instance.RunContext
		end)
		if okRunContext then
			table.insert(parts, "RunContext=" .. tostring(runContext))
		end
	end
	local okSource, source = pcall(function()
		return instance.Source
	end)
	if okSource and type(source) == "string" then
		local _, newlineCount = string.gsub(source, "\n", "\n")
		table.insert(parts, "Lines=" .. tostring(newlineCount + 1))
	else
		table.insert(parts, "Source=unavailable")
	end
	if #parts == 0 then
		return ""
	end
	return " [" .. table.concat(parts, ", ") .. "]"
end

local function objectSummary(instance)
	local childCount = #instance:GetChildren()
	local summary = instance.Name .. " <" .. instance.ClassName .. ">"
	if childCount > 0 then
		summary = summary .. " children=" .. childCount
	end
	return summary .. scriptMeta(instance) .. attributesText(instance) .. tagsText(instance)
end

local function collectClassCounts(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		classCounts[descendant.ClassName] = (classCounts[descendant.ClassName] or 0) + 1
	end
	classCounts[root.ClassName] = (classCounts[root.ClassName] or 0) + 1
end

local function writeTree(root, title, maxDepth, importantOnly)
	add("")
	add("## " .. title)
	add("")
	local count = 0
	local visibleSet = importantOnly and buildVisibleSet(root) or nil
	local function visit(instance, depth)
		if count >= MAX_NODES_PER_TREE then
			add(("... stopped after %d nodes for this tree"):format(MAX_NODES_PER_TREE))
			return
		end
		if depth > maxDepth then
			return
		end
		if visibleSet and not visibleSet[instance] then
			return
		end
		count += 1
		add(string.rep("  ", depth) .. "- " .. objectSummary(instance))
		for _, child in ipairs(sortedChildren(instance)) do
			visit(child, depth + 1)
		end
	end
	visit(root, 0)
	add("")
	add(("Tree nodes listed: %d"):format(count))
end

local function writeImportantObjects(root)
	add("")
	add("## Important Object Paths: " .. root.Name)
	add("")
	local matches = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if isImportant(descendant) then
			table.insert(matches, descendant)
		end
	end
	table.sort(matches, function(a, b)
		return safeFullName(a) < safeFullName(b)
	end)
	for _, instance in ipairs(matches) do
		add("- " .. safeFullName(instance) .. " <" .. instance.ClassName .. ">" .. scriptMeta(instance) .. attributesText(instance) .. tagsText(instance))
	end
	if #matches == 0 then
		add("- None found")
	end
end

local function writeScriptsAndRemotes()
	add("")
	add("## Scripts, Modules, Remotes, Bindables")
	add("")
	local matches = {}
	for _, serviceName in ipairs(rootServices) do
		local ok, service = pcall(function()
			return game:GetService(serviceName)
		end)
		if ok and service then
			for _, descendant in ipairs(service:GetDescendants()) do
				if descendant:IsA("Script")
					or descendant:IsA("LocalScript")
					or descendant:IsA("ModuleScript")
					or descendant:IsA("RemoteEvent")
					or descendant:IsA("RemoteFunction")
					or descendant:IsA("BindableEvent")
					or descendant:IsA("BindableFunction") then
					table.insert(matches, descendant)
				end
			end
		end
	end
	table.sort(matches, function(a, b)
		return safeFullName(a) < safeFullName(b)
	end)
	for _, instance in ipairs(matches) do
		add("- " .. safeFullName(instance) .. " <" .. instance.ClassName .. ">" .. scriptMeta(instance) .. attributesText(instance))
	end
	if #matches == 0 then
		add("- None found")
	end
end

local function writeVehicleAssets()
	add("")
	add("## Vehicle / Module Asset Scan")
	add("")
	local matches = {}
	for _, rootName in ipairs({ "ReplicatedStorage", "ServerStorage", "Workspace" }) do
		local root = game:GetService(rootName)
		for _, descendant in ipairs(root:GetDescendants()) do
			local lowerName = string.lower(descendant.Name)
			local moduleType = descendant:GetAttribute("ModuleType")
			local moduleId = descendant:GetAttribute("ModuleId")
			if moduleType ~= nil or moduleId ~= nil
				or string.find(lowerName, "cockpit", 1, true)
				or string.find(lowerName, "module", 1, true)
				or string.find(lowerName, "bruiser", 1, true)
				or string.find(lowerName, "engine", 1, true)
				or string.find(lowerName, "boost", 1, true)
				or string.find(lowerName, "stabil", 1, true) then
				table.insert(matches, descendant)
			end
		end
	end
	table.sort(matches, function(a, b)
		return safeFullName(a) < safeFullName(b)
	end)
	for _, instance in ipairs(matches) do
		add("- " .. safeFullName(instance) .. " <" .. instance.ClassName .. ">" .. attributesText(instance))
	end
	if #matches == 0 then
		add("- None found")
	end
end

local function writeLighting()
	add("")
	add("## Lighting Snapshot")
	add("")
	local Lighting = game:GetService("Lighting")
	local props = {
		"ClockTime",
		"Brightness",
		"Ambient",
		"OutdoorAmbient",
		"EnvironmentDiffuseScale",
		"EnvironmentSpecularScale",
		"ExposureCompensation",
		"ShadowSoftness",
		"GlobalShadows",
	}
	for _, prop in ipairs(props) do
		local ok, value = pcall(function()
			return Lighting[prop]
		end)
		if ok then
			add(("- Lighting.%s = %s"):format(prop, valueToText(value)))
		end
	end
	for _, child in ipairs(sortedChildren(Lighting)) do
		add("- " .. objectSummary(child))
	end
end

local function writeClassCounts()
	add("")
	add("## Class Counts")
	add("")
	local keys = {}
	for key in pairs(classCounts) do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		add(("- %s: %d"):format(key, classCounts[key]))
	end
end

local function clearOldReports(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if string.sub(child.Name, 1, #REPORT_PREFIX) == REPORT_PREFIX then
			child:Destroy()
		end
	end
end

local function writeReportInstances(reportText)
	local folder = ReplicatedStorage:FindFirstChild(REPORT_FOLDER_NAME)
	if folder and not folder:IsA("Folder") then
		folder.Name = folder.Name .. "_OldNonFolder"
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REPORT_FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	clearOldReports(folder)

	local index = 1
	for startIndex = 1, #reportText, CHUNK_SIZE do
		local value = Instance.new("StringValue")
		value.Name = REPORT_PREFIX .. string.format("%03d", index)
		value.Value = string.sub(reportText, startIndex, startIndex + CHUNK_SIZE - 1)
		value.Parent = folder
		index += 1
	end

	return folder, index - 1
end

local function printChunks(reportText)
	local outputChunkSize = 30000
	for startIndex = 1, #reportText, outputChunkSize do
		print(string.sub(reportText, startIndex, startIndex + outputChunkSize - 1))
	end
end

add("# Neo Tokyo Racers Studio Inventory Report")
add("")
add("Generated at: " .. os.date("%Y-%m-%d %H:%M:%S"))
add("Place name: " .. game.Name)
add("JobId: " .. tostring(game.JobId))
add("")
add("Notes:")
add("- This is an inspection report for architecture planning.")
add("- It does not move, rename, or delete game systems.")
add("- Report chunks are stored in ReplicatedStorage." .. REPORT_FOLDER_NAME .. ".")

for _, serviceName in ipairs(rootServices) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		collectClassCounts(service)
	else
		table.insert(warnings, "Could not access service: " .. serviceName)
	end
end

add("")
add("## Top-Level Service Children")
for _, serviceName in ipairs(rootServices) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		add("")
		add("### " .. serviceName)
		for _, child in ipairs(sortedChildren(service)) do
			add("- " .. objectSummary(child))
		end
	end
end

local serviceDepths = {
	ReplicatedStorage = MAX_DEPTH_IMPORTANT,
	ServerScriptService = MAX_DEPTH_IMPORTANT,
	StarterPlayer = MAX_DEPTH_IMPORTANT,
	StarterGui = MAX_DEPTH_IMPORTANT,
	ServerStorage = MAX_DEPTH_GENERAL,
	Workspace = MAX_DEPTH_GENERAL,
	Lighting = MAX_DEPTH_IMPORTANT,
	SoundService = MAX_DEPTH_GENERAL,
	Teams = MAX_DEPTH_GENERAL,
}

for _, serviceName in ipairs(rootServices) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		local importantOnly = serviceName == "Workspace"
		writeTree(service, "Hierarchy: " .. serviceName, serviceDepths[serviceName] or MAX_DEPTH_GENERAL, importantOnly)
	end
end

writeScriptsAndRemotes()
writeVehicleAssets()
writeLighting()

for _, serviceName in ipairs(rootServices) do
	local ok, service = pcall(function()
		return game:GetService(serviceName)
	end)
	if ok and service then
		writeImportantObjects(service)
	end
end

writeClassCounts()

if #warnings > 0 then
	add("")
	add("## Warnings")
	for _, warning in ipairs(warnings) do
		add("- " .. warning)
	end
end

local reportText = table.concat(lines, "\n")
local reportFolder, chunkCount = writeReportInstances(reportText)

printChunks(reportText)
print(("Neo Tokyo Racers inventory report complete. Created %d chunk(s) at %s."):format(chunkCount, reportFolder:GetFullName()))
print("Paste the report chunk values back into Codex, or select the StringValues in Explorer and copy their Value fields.")
