-- Neo Tokyo Racers - Racing UI Phase 1F Shared Display Name
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Adds SharedMenuDisplayName to each RaceCatalog event, seeded from its current
-- DisplayName, and installs an isolated server synchronizer. The Race Catalog
-- attribute becomes the single menu-facing name for the matching race event,
-- time-trial event, and route folder.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 1F Shared Display Name"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local function serviceSource()
	return [====[
-- Neo Tokyo Racers - Racing Shared Display Name Service
-- NTR_RACING_UI_PHASE1F_SHARED_DISPLAY_NAME_OWNER

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local racing = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("Racing")
local raceCatalog = racing:WaitForChild("RaceCatalog")
local timeTrialCatalog = racing:WaitForChild("TimeTrialCatalog")
local routes = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("RaceRoutes")

local connected = {}

local function textAttribute(instance, name)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "string" and value or ""
end

local function setIfDifferent(instance, name, value)
	if instance and instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

local function matchingTimeTrials(routeId, fallbackName)
	local result = {}
	for _, event in ipairs(timeTrialCatalog:GetChildren()) do
		if event:IsA("Folder") or event:IsA("Configuration") then
			if textAttribute(event, "RouteId") == routeId or (routeId == "" and event.Name == fallbackName) then
				table.insert(result, event)
			end
		end
	end
	return result
end

local function syncEvent(event)
	if not (event and (event:IsA("Folder") or event:IsA("Configuration"))) then return end
	local sharedName = textAttribute(event, "SharedMenuDisplayName")
	if sharedName == "" then
		sharedName = textAttribute(event, "DisplayName")
	end
	if sharedName == "" then
		sharedName = event.Name
	end
	local routeId = textAttribute(event, "RouteId")

	setIfDifferent(event, "DisplayName", sharedName)
	for _, timeTrial in ipairs(matchingTimeTrials(routeId, event.Name)) do
		setIfDifferent(timeTrial, "DisplayName", sharedName)
		setIfDifferent(timeTrial, "SharedMenuDisplayName", sharedName)
	end
	local route = routeId ~= "" and routes:FindFirstChild(routeId) or routes:FindFirstChild(event.Name)
	if route then
		setIfDifferent(route, "DisplayName", sharedName)
	end
end

local function connectEvent(event)
	if connected[event] then return end
	connected[event] = true
	event:GetAttributeChangedSignal("SharedMenuDisplayName"):Connect(function()
		syncEvent(event)
	end)
	syncEvent(event)
end

for _, event in ipairs(raceCatalog:GetChildren()) do
	connectEvent(event)
end
raceCatalog.ChildAdded:Connect(function(event)
	task.defer(connectEvent, event)
end)
raceCatalog.ChildRemoved:Connect(function(event)
	connected[event] = nil
end)

print("[NTR Racing UI Phase 1F] SharedMenuDisplayName synchronizer active.")
]====]
end

local function paths()
	local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local racing = ntr:WaitForChild("Config"):WaitForChild("Racing")
	local raceCatalog = racing:WaitForChild("RaceCatalog")
	local timeTrialCatalog = racing:WaitForChild("TimeTrialCatalog")
	local routes = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("RaceRoutes")
	local serverRoot = ServerScriptService:WaitForChild("NeoTokyoRacers")
	local services = serverRoot:WaitForChild("Services")
	local racingServices = services:WaitForChild("Racing")
	return raceCatalog, timeTrialCatalog, routes, racingServices
end

local function textAttribute(instance, name)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "string" and value or ""
end

local function findTimeTrials(timeTrialCatalog, routeId, fallbackName)
	local result = {}
	for _, event in ipairs(timeTrialCatalog:GetChildren()) do
		if event:IsA("Folder") or event:IsA("Configuration") then
			if textAttribute(event, "RouteId") == routeId or (routeId == "" and event.Name == fallbackName) then
				table.insert(result, event)
			end
		end
	end
	return result
end

local function syncEditState(raceCatalog, timeTrialCatalog, routes)
	local synced = 0
	for _, event in ipairs(raceCatalog:GetChildren()) do
		if event:IsA("Folder") or event:IsA("Configuration") then
			local sharedName = textAttribute(event, "SharedMenuDisplayName")
			if sharedName == "" then
				sharedName = textAttribute(event, "DisplayName")
				if sharedName == "" then sharedName = event.Name end
				event:SetAttribute("SharedMenuDisplayName", sharedName)
			end
			local routeId = textAttribute(event, "RouteId")
			event:SetAttribute("DisplayName", sharedName)
			for _, timeTrial in ipairs(findTimeTrials(timeTrialCatalog, routeId, event.Name)) do
				timeTrial:SetAttribute("DisplayName", sharedName)
				timeTrial:SetAttribute("SharedMenuDisplayName", sharedName)
			end
			local route = routeId ~= "" and routes:FindFirstChild(routeId) or routes:FindFirstChild(event.Name)
			if route then route:SetAttribute("DisplayName", sharedName) end
			synced += 1
			print(string.format("[%s] Synced route=%s name=%s", PHASE, routeId ~= "" and routeId or event.Name, sharedName))
		end
	end
	assert(synced > 0, "No RaceCatalog events were found to synchronize")
end

local function smoke()
	local raceCatalog, timeTrialCatalog, routes, racingServices = paths()
	local service = racingServices:FindFirstChild("RaceDisplayNameService_Active")
	assert(service and service:IsA("Script") and service.Enabled, "RaceDisplayNameService_Active missing or disabled")
	assert(string.find(service.Source, "NTR_RACING_UI_PHASE1F_SHARED_DISPLAY_NAME_OWNER", 1, true), "Phase 1F service marker missing")
	for _, event in ipairs(raceCatalog:GetChildren()) do
		if event:IsA("Folder") or event:IsA("Configuration") then
			local sharedName = textAttribute(event, "SharedMenuDisplayName")
			assert(sharedName ~= "", event:GetFullName() .. " has no SharedMenuDisplayName")
			assert(textAttribute(event, "DisplayName") == sharedName, event:GetFullName() .. " DisplayName is not synchronized")
			local routeId = textAttribute(event, "RouteId")
			for _, timeTrial in ipairs(findTimeTrials(timeTrialCatalog, routeId, event.Name)) do
				assert(textAttribute(timeTrial, "DisplayName") == sharedName, timeTrial:GetFullName() .. " DisplayName mismatch")
			end
			local route = routeId ~= "" and routes:FindFirstChild(routeId) or routes:FindFirstChild(event.Name)
			assert(route, "Route folder missing for " .. event:GetFullName())
			assert(textAttribute(route, "DisplayName") == sharedName, route:GetFullName() .. " DisplayName mismatch")
		end
	end
	print("[" .. PHASE .. "] SMOKE PASS RaceCatalog SharedMenuDisplayName owns matching Race, Time Trial, and route names.")
end

local function install()
	local raceCatalog, timeTrialCatalog, routes, racingServices = paths()
	syncEditState(raceCatalog, timeTrialCatalog, routes)
	local service = racingServices:FindFirstChild("RaceDisplayNameService_Active")
	if service then
		assert(service:IsA("Script"), service:GetFullName() .. " has unexpected class " .. service.ClassName)
	else
		service = Instance.new("Script")
		service.Name = "RaceDisplayNameService_Active"
		service.Parent = racingServices
	end
	service.Source = serviceSource()
	service.Enabled = true
	print("[" .. PHASE .. "] INSTALL complete. Edit SharedMenuDisplayName on the RaceCatalog event to rename every matching Racing menu.")
	smoke()
end

if MODE == "INSTALL" then
	install()
elseif MODE == "SMOKE" then
	smoke()
else
	error("Unknown MODE: " .. tostring(MODE))
end

