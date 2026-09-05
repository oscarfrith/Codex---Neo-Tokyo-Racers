-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("World"):WaitForChild("Traffic"):WaitForChild("TrafficLightService")
local CollectionService = game:GetService("CollectionService")

local CYCLE_TIME = 36
local UPDATE_RATE = 0.2

local TRAFFIC_LIGHT_TAG = "TrafficLight"

local function setMaterial(part, isOn)
	if part and part:IsA("BasePart") then
		part.Material = isOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

task.spawn(function()
while true do
	local t = os.clock() % CYCLE_TIME

	local redOn = false
	local orangeOn = false
	local greenOn = false

	if t < 12 then
		redOn = true
	elseif t < 15 then
		redOn = true
		orangeOn = true
	elseif t < 30 then
		greenOn = true
	else
		orangeOn = true
	end

	for _, model in ipairs(CollectionService:GetTagged(TRAFFIC_LIGHT_TAG)) do
		if model:IsDescendantOf(workspace) and model:IsA("Model") then
			local red = model:FindFirstChild("traffic light light red", true)
			local orange = model:FindFirstChild("traffic light light orange", true)
			local green = model:FindFirstChild("traffic light neon green", true)

			setMaterial(red, redOn)
			setMaterial(orange, orangeOn)
			setMaterial(green, greenOn)
		end
	end

	task.wait(UPDATE_RATE)
end
end)

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
