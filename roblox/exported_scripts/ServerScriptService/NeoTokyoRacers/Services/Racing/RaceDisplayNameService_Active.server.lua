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
