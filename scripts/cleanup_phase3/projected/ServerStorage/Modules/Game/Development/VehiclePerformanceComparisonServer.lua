-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = game:GetService("ReplicatedStorage")
local config = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):WaitForChild("Performance")
local runtime = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("Performance"):WaitForChild("PerformanceRuntime"))
local pending = setmetatable({}, { __mode = "k" })

local function evaluate(vehicle)
	if config:GetAttribute("ShadowComparisonEnabled") ~= true then return end
	if not vehicle:IsA("Model") or not vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime") then return end
	local ok, result = pcall(runtime.CalculateRuntimeVehicle, vehicle)
	if ok then runtime.WriteShadow(vehicle, result) else warn("[V2 Shadow] " .. vehicle:GetFullName() .. ": " .. tostring(result)) end
end

local function schedule(vehicle)
	if pending[vehicle] then return end
	pending[vehicle] = true
	task.delay(0.2, function()
		pending[vehicle] = nil
		if vehicle.Parent then evaluate(vehicle) end
	end)
end

local function consider(item)
	local folder
	if item.Name == "RAW_PERFORMANCE_Runtime" and item:IsA("Folder") then folder = item
	elseif item.Parent and item.Parent.Name == "RAW_PERFORMANCE_Runtime" and item.Parent:IsA("Folder") then folder = item.Parent end
	if folder and folder.Parent and folder.Parent:IsA("Model") then schedule(folder.Parent) end
end

Workspace.DescendantAdded:Connect(consider)
print("[Vehicle Performance V2 Phase 7] Shadow comparison service active; live V1 rating/physics remain authoritative.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
