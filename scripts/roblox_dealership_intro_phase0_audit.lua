-- Neo Tokyo Racers - Dealership Intro Phase 0 Audit
-- Run in Roblox Studio Command Bar, Edit mode or Play mode.
--
-- Purpose:
--   Read-only audit for planning the dealership intro/startup change.
--
-- Safe effects:
--   - Prints a clear report to Output only.
--
-- Does NOT:
--   - Create, delete, move, clone, rename, enable, disable, or edit anything.
--   - Change UI, driving, VFX, server actions, assets, Workspace, or scripts.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CLIENT_ROOT_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient"
local GARAGE_ROOT_PATH = "ServerScriptService.NeoTokyoRacers.Services.Garage"

local CLIENT_KEYWORDS = {
	"OpenGarage",
	"Garage",
	"Preview",
	"CreatePreview",
	"GarageCameraActive",
	"CockpitShop",
	"GetInitial",
	"InvokeServer",
}

local SERVER_KEYWORDS = {
	"BuyCockpit",
	"PurchaseCockpit",
	"Cockpit",
	"Price",
	"OwnedCockpits",
	"GarageInvoke",
}

local LEGACY_NAMES = {
	"HOVER_RACING_V2_Client",
	"HOVER_RACING_V2_Server",
	"HOVER_RACING_V2_KIT",
}

local PLANNED_OBJECT_PATHS = {
	"Workspace.NeoTokyoRacersWorld.Dealership.Intro.Spawn.IntroSpawnPoint",
	"Workspace.NeoTokyoRacersWorld.Dealership.Intro.Desk.GarageDeskTrigger",
	"Workspace.NeoTokyoRacersWorld.Dealership.Intro.Camera.DealershipLookCameraPoint",
	"Workspace.NeoTokyoRacersWorld.Dealership.Intro.Camera.GaragePreviewCameraPoint",
	"Workspace.NeoTokyoRacersWorld.Dealership.Intro.Preview.VehiclePreviewPoint",
	"Workspace.NeoTokyoRacersWorld.Dealership.Intro.Path.PathNode_01",
}

local SERVICE_BY_NAME = {
	StarterPlayer = StarterPlayer,
	ServerScriptService = ServerScriptService,
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
}

local report = {}

local function line(text)
	table.insert(report, text)
end

local function fullName(instance)
	if not instance then
		return "(nil)"
	end
	return instance:GetFullName()
end

local function existsPath(path)
	local firstToken = string.match(path, "^[^%.]+")
	local current = SERVICE_BY_NAME[firstToken]
	if not current then
		return false, nil
	end

	local skipFirst = true
	for token in string.gmatch(path, "[^%.]+") do
		if skipFirst then
			skipFirst = false
		else
			current = current:FindFirstChild(token)
			if not current then
				return false, nil
			end
		end
	end

	return true, current
end

local function isRunnableScript(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript")
end

local function isScriptOrModule(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function isActiveScriptOrModule(instance)
	if instance:IsA("ModuleScript") then
		return true
	end
	if isRunnableScript(instance) then
		return not instance.Disabled
	end
	return false
end

local function stateLabel(instance)
	if not instance then
		return "missing"
	end
	if instance:IsA("ModuleScript") then
		return "module"
	end
	if isRunnableScript(instance) then
		return instance.Disabled and "disabled" or "enabled"
	end
	return instance.ClassName
end

local function sourceText(instance)
	if not isScriptOrModule(instance) then
		return nil, "not script/module"
	end

	local ok, source = pcall(function()
		return instance.Source
	end)

	if ok then
		return source or "", nil
	end

	return nil, tostring(source)
end

local function collectActiveScriptsAndModules(root)
	local items = {}

	if not root then
		return items
	end

	if isScriptOrModule(root) and isActiveScriptOrModule(root) then
		table.insert(items, root)
	end

	for _, instance in ipairs(root:GetDescendants()) do
		if isScriptOrModule(instance) and isActiveScriptOrModule(instance) then
			table.insert(items, instance)
		end
	end

	table.sort(items, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	return items
end

local function collectByName(name)
	local matches = {}

	for _, root in ipairs({ StarterPlayer, ServerScriptService, ReplicatedStorage, Workspace }) do
		if root.Name == name then
			table.insert(matches, root)
		end

		for _, instance in ipairs(root:GetDescendants()) do
			if instance.Name == name then
				table.insert(matches, instance)
			end
		end
	end

	table.sort(matches, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	return matches
end

local function searchKeywords(instances, keywords)
	local results = {}

	for _, instance in ipairs(instances) do
		local source, err = sourceText(instance)
		local hits = {}

		if source then
			for _, keyword in ipairs(keywords) do
				local count = 0
				local firstLine = nil
				local lineNumber = 0

				for sourceLine in string.gmatch(source .. "\n", "([^\n]*)\n") do
					lineNumber += 1
					if string.find(sourceLine, keyword, 1, true) then
						count += 1
						if not firstLine then
							firstLine = lineNumber
						end
					end
				end

				if count > 0 then
					table.insert(hits, {
						keyword = keyword,
						count = count,
						firstLine = firstLine,
					})
				end
			end
		end

		if #hits > 0 or err then
			table.insert(results, {
				instance = instance,
				hits = hits,
				sourceError = err,
			})
		end
	end

	table.sort(results, function(a, b)
		local aScore = 0
		local bScore = 0

		for _, hit in ipairs(a.hits) do
			aScore += hit.count
		end
		for _, hit in ipairs(b.hits) do
			bScore += hit.count
		end

		if aScore == bScore then
			return a.instance:GetFullName() < b.instance:GetFullName()
		end

		return aScore > bScore
	end)

	return results
end

local function hitSummary(result)
	if result.sourceError then
		return "Source read failed: " .. result.sourceError
	end

	local parts = {}
	for _, hit in ipairs(result.hits) do
		table.insert(parts, hit.keyword .. "=" .. tostring(hit.count) .. " (first line " .. tostring(hit.firstLine) .. ")")
	end

	return table.concat(parts, "; ")
end

local function listSection(title, items, emptyText)
	line("## " .. title)
	line("")
	if #items == 0 then
		line("- " .. (emptyText or "None."))
	else
		for _, item in ipairs(items) do
			line("- " .. item)
		end
	end
	line("")
end

local clientRootExists, clientRoot = existsPath(CLIENT_ROOT_PATH)
local garageRootExists, garageRoot = existsPath(GARAGE_ROOT_PATH)

local activeClientItems = collectActiveScriptsAndModules(clientRoot)
local activeGarageItems = collectActiveScriptsAndModules(garageRoot)

local clientHits = searchKeywords(activeClientItems, CLIENT_KEYWORDS)
local serverHits = searchKeywords(activeGarageItems, SERVER_KEYWORDS)

local worldExists = select(1, existsPath("Workspace.NeoTokyoRacersWorld"))
local introExists = select(1, existsPath("Workspace.NeoTokyoRacersWorld.Dealership.Intro"))

local missingMarkers = {}
local presentMarkers = {}
for _, path in ipairs(PLANNED_OBJECT_PATHS) do
	local exists, instance = existsPath(path)
	if exists then
		table.insert(presentMarkers, path .. " -> " .. instance.ClassName)
	else
		table.insert(missingMarkers, path)
	end
end

local activeLegacy = {}
local inactiveOrNonRunnableLegacy = {}
local missingLegacy = {}

for _, name in ipairs(LEGACY_NAMES) do
	local matches = collectByName(name)

	if #matches == 0 then
		table.insert(missingLegacy, name)
	else
		for _, instance in ipairs(matches) do
			if isRunnableScript(instance) and not instance.Disabled then
				table.insert(activeLegacy, fullName(instance) .. " -> enabled " .. instance.ClassName)
			else
				table.insert(inactiveOrNonRunnableLegacy, fullName(instance) .. " -> " .. stateLabel(instance))
			end
		end
	end
end

local relevantClientScripts = {}
for _, result in ipairs(clientHits) do
	table.insert(relevantClientScripts, result.instance:GetFullName())
end

local relevantServerScripts = {}
for _, result in ipairs(serverHits) do
	table.insert(relevantServerScripts, result.instance:GetFullName())
end

local previewGateLikelyNeeded = false
for _, result in ipairs(clientHits) do
	local path = result.instance:GetFullName()
	local summary = hitSummary(result)
	if string.find(summary, "OpenGarage", 1, true)
		or string.find(summary, "CreatePreview", 1, true)
		or string.find(summary, "GarageCameraActive", 1, true)
		or string.find(summary, "GetInitial", 1, true)
		or string.find(summary, "InvokeServer", 1, true)
		or string.find(path, "Preview", 1, true)
		or string.find(path, "Garage", 1, true)
	then
		previewGateLikelyNeeded = true
	end
end

line("# Neo Tokyo Racers Dealership Intro Phase 0 Audit")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only audit. This script only reads Explorer state and script Source, then prints this report. It did not create, delete, move, clone, rename, enable, disable, or edit anything.")
line("")

line("## Summary")
line("")
line("- Client root exists: " .. tostring(clientRootExists))
line("- Active client scripts/modules under root: " .. tostring(#activeClientItems))
line("- Garage server root exists: " .. tostring(garageRootExists))
line("- Active garage server scripts/modules under root: " .. tostring(#activeGarageItems))
line("- Active legacy script matches: " .. tostring(#activeLegacy))
line("- World root exists: " .. tostring(worldExists))
line("- Planned intro root exists: " .. tostring(introExists))
line("- Planned marker objects present: " .. tostring(#presentMarkers) .. " / " .. tostring(#PLANNED_OBJECT_PATHS))
line("- Client startup/preview keyword matches: " .. tostring(#clientHits))
line("- Server cockpit purchase keyword matches: " .. tostring(#serverHits))
line("")

line("## 1. Active Client Bootstrap/Controller Paths")
line("")
line("Root: " .. CLIENT_ROOT_PATH .. " -> " .. (clientRootExists and stateLabel(clientRoot) or "missing"))
if #activeClientItems == 0 then
	line("- None found under the client root.")
else
	for _, instance in ipairs(activeClientItems) do
		line("- " .. fullName(instance) .. " -> " .. stateLabel(instance))
	end
end
line("")

line("## 2. Active Garage Server Controller Paths")
line("")
line("Root: " .. GARAGE_ROOT_PATH .. " -> " .. (garageRootExists and stateLabel(garageRoot) or "missing"))
if #activeGarageItems == 0 then
	line("- None found under the garage server root.")
else
	for _, instance in ipairs(activeGarageItems) do
		line("- " .. fullName(instance) .. " -> " .. stateLabel(instance))
	end
end
line("")

listSection("3. Old Legacy Active Scripts Still Existing/Enabled", activeLegacy, "No enabled legacy script matches found.")
listSection("3a. Old Legacy Matches Missing", missingLegacy, "None missing from the search list.")
listSection("3b. Old Legacy Matches Present But Not Active Runnable Scripts", inactiveOrNonRunnableLegacy, "None.")

line("## 4. World Path")
line("")
line("- Workspace.NeoTokyoRacersWorld -> " .. (worldExists and "exists" or "missing"))
line("")

line("## 5. Planned Intro Path")
line("")
line("- Workspace.NeoTokyoRacersWorld.Dealership.Intro -> " .. (introExists and "exists" or "missing"))
line("")

listSection("6. Planned Objects Present", presentMarkers, "None of the planned marker objects were found.")
listSection("6a. Planned Objects Missing", missingMarkers, "No planned marker objects are missing.")

line("## 7. Active Client Keyword Search")
line("")
if #clientHits == 0 then
	line("- No keyword matches found in active client scripts/modules.")
else
	for _, result in ipairs(clientHits) do
		line("- " .. result.instance:GetFullName() .. " -> " .. hitSummary(result))
	end
end
line("")

line("## 8. Server Garage Keyword Search")
line("")
if #serverHits == 0 then
	line("- No keyword matches found in active garage server scripts/modules.")
else
	for _, result in ipairs(serverHits) do
		line("- " .. result.instance:GetFullName() .. " -> " .. hitSummary(result))
	end
end
line("")

line("## 9. Recommendations")
line("")
if #missingMarkers > 0 then
	line("- Markers need setup: YES. Missing " .. tostring(#missingMarkers) .. " planned intro marker object(s).")
else
	line("- Markers need setup: NO. All planned intro marker objects were found.")
end

if previewGateLikelyNeeded then
	line("- Preview gate patch likely needed: YES. Active client startup/garage/preview code has relevant keyword matches.")
else
	line("- Preview gate patch likely needed: UNCLEAR/LOW from this keyword scan. No strong active client startup/preview matches were found.")
end

if #relevantClientScripts > 0 then
	line("- Most relevant client scripts/modules for next phase:")
	for _, path in ipairs(relevantClientScripts) do
		line("  - " .. path)
	end
else
	line("- Most relevant client scripts/modules for next phase: none found by keyword scan.")
end

if #relevantServerScripts > 0 then
	line("- Most relevant server garage scripts/modules for next phase:")
	for _, path in ipairs(relevantServerScripts) do
		line("  - " .. path)
	end
else
	line("- Most relevant server garage scripts/modules for next phase: none found by keyword scan.")
end

if #activeLegacy > 0 then
	line("- Legacy cleanup risk: review enabled legacy matches before any intro/startup patch.")
else
	line("- Legacy cleanup risk: no enabled legacy matches found for the requested legacy names.")
end

line("")
line("## Paste Back Guidance")
line("")
line("Paste this full report back into the Codex/ChatGPT thread before the next phase.")

print(table.concat(report, "\n"))
