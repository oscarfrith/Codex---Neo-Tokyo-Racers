-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
-- Neo Tokyo Racers - Racing Shared Display Name Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local racing = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Racing")
local raceCatalog = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Racing"):WaitForChild("RaceCatalog")
local timeTrialCatalog = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Racing"):WaitForChild("TimeTrialCatalog")
local routes = game:GetService("Workspace"):WaitForChild("World"):WaitForChild("RaceRoutes")

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

print("[RaceDisplayNameServer] SharedMenuDisplayName synchronizer active.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
