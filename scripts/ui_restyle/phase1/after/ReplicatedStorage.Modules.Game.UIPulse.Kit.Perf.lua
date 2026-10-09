-- Owns the only frame binding in Pulse and the debug counters; owns no layout, no view state and no per-frame work of its own.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Perf. Requires: none.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Perf = {}

local warned = {}
local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.Perf] " .. message)
end

-- Read once, FindFirstChild only: Studio and Config.UI.Pulse@PerfDebug.
local function readEnabled(): boolean
	if not RunService:IsStudio() then
		return false
	end
	local config = ReplicatedStorage:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	local pulse = ui and ui:FindFirstChild("Pulse")
	return pulse ~= nil and pulse:GetAttribute("PerfDebug") == true
end

Perf.Enabled = readEnabled()

-- The step runs on RenderStepped only while layerRoot.Visible is true; the property signal connects and
-- disconnects it. A step error is reported once per name and does not stop later frames.
function Perf.Bind(name: string, layerRoot: GuiObject, step: (dt: number) -> ()): { Disconnect: () -> () }
	assert(type(name) == "string" and name ~= "", "[Pulse.Perf] Bind needs a name")
	assert(typeof(layerRoot) == "Instance" and layerRoot:IsA("GuiObject"), "[Pulse.Perf] Bind needs a GuiObject layer root")
	assert(type(step) == "function", "[Pulse.Perf] Bind needs a step function")

	local label = "Pulse." .. name
	local closed = false
	local stepConnection, visibleConnection, destroyingConnection

	local function onFrame(dt)
		debug.profilebegin(label)
		local ok, message = pcall(step, dt)
		debug.profileend()
		if not ok then
			warnOnce(label .. " step failed: " .. tostring(message))
		end
	end

	local function sync()
		local want = not closed and layerRoot.Visible
		if want and not stepConnection then
			stepConnection = RunService.RenderStepped:Connect(onFrame)
		elseif not want and stepConnection then
			stepConnection:Disconnect()
			stepConnection = nil
		end
	end

	local handle = {}
	function handle.Disconnect()
		if closed then
			return
		end
		closed = true
		sync()
		if visibleConnection then
			visibleConnection:Disconnect()
			visibleConnection = nil
		end
		if destroyingConnection then
			destroyingConnection:Disconnect()
			destroyingConnection = nil
		end
	end

	visibleConnection = layerRoot:GetPropertyChangedSignal("Visible"):Connect(sync)
	destroyingConnection = layerRoot.Destroying:Connect(handle.Disconnect)
	sync()
	return handle
end

local totals = {} -- attribute name -> running total since the session began
local attributeNames = {} -- counter -> attribute name
local dirty = false
local publisher
local folder

local function attributeName(counter)
	local name = attributeNames[counter]
	if not name then
		name = string.sub((string.gsub(tostring(counter), "[^%w_]", "_")), 1, 100)
		attributeNames[counter] = name
	end
	return name
end

local function perfFolder()
	if folder and folder.Parent then
		return folder
	end
	local player = Players.LocalPlayer
	local playerScripts = player and player:FindFirstChildOfClass("PlayerScripts")
	if not playerScripts then
		return nil
	end
	local existing = playerScripts:FindFirstChild("PulsePerf")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "PulsePerf"
		folder.Parent = playerScripts
	end
	return folder
end

-- Started by the first Count while enabled. Once a second, and only when a counter moved.
local function publish()
	while true do
		task.wait(1)
		if dirty then
			local target = perfFolder()
			if target then
				dirty = false
				for name, total in totals do
					target:SetAttribute(name, total)
				end
			end
		end
	end
end

function Perf.Count(counter: string, n: number?)
	if not Perf.Enabled then
		return
	end
	local name = attributeName(counter)
	totals[name] = (totals[name] or 0) + (n or 1)
	dirty = true
	if not publisher then
		publisher = task.spawn(publish)
	end
end

return Perf
