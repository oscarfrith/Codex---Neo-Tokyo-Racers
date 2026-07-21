-- NTR_LOADING_SYSTEM_PHASE1_GAMEPLAY_INPUT_GATE_V1
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Gate = {}
local player = Players.LocalPlayer
local tokens = {}
local nextToken = 0
local pendingNeutral = false
local neutralGeneration = 0
local controls = nil

local watchedKeys = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
}
local watchedGamepad = {
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonB] = true,
	[Enum.KeyCode.ButtonL2] = true,
	[Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.ButtonY] = true,
}

local function mobileState()
	local parent = script.Parent and script.Parent.Parent
	local controllers = parent and parent:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("MobileDriveInputState")
	if not (module and module:IsA("ModuleScript")) then return nil end
	local ok, value = pcall(require, module)
	return ok and type(value) == "table" and value or nil
end

local function resetMobile()
	local state = mobileState()
	if state and type(state.Reset) == "function" then pcall(state.Reset) end
end

local function resolveControls()
	if controls then return controls end
	local playerScripts = player and player:FindFirstChild("PlayerScripts")
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then return nil end
	local ok, module = pcall(require, playerModule)
	if not ok or type(module) ~= "table" or type(module.GetControls) ~= "function" then return nil end
	local got, result = pcall(function() return module:GetControls() end)
	if got then controls = result end
	return controls
end

local function disableControls()
	resetMobile()
	local current = resolveControls()
	if current and type(current.Disable) == "function" then pcall(function() current:Disable() end) end
end

local function enableControls()
	resetMobile()
	local current = resolveControls()
	if current and type(current.Enable) == "function" then pcall(function() current:Enable() end) end
end

local function tokenCount()
	local count = 0
	for _ in pairs(tokens) do count += 1 end
	return count
end

local function inputsNeutral()
	for _, key in ipairs(watchedKeys) do
		if UserInputService:IsKeyDown(key) then return false end
	end
	for _, input in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if watchedGamepad[input.KeyCode] and input.Position.Z > 0.12 then return false end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.12 then return false end
	end
	return true
end

local function finishNeutralWait(generation)
	if generation ~= neutralGeneration or tokenCount() > 0 then return end
	pendingNeutral = false
	enableControls()
end

local function beginNeutralWait()
	neutralGeneration += 1
	local generation = neutralGeneration
	pendingNeutral = true
	task.spawn(function()
		local deadline = os.clock() + 5
		repeat
			if generation ~= neutralGeneration or tokenCount() > 0 then return end
			if inputsNeutral() then finishNeutralWait(generation) return end
			task.wait(0.05)
		until os.clock() >= deadline
		finishNeutralWait(generation)
	end)
end

function Gate.Acquire(owner, generation)
	nextToken += 1
	local token = ("%s:%s:%d"):format(tostring(owner or "Unknown"), tostring(generation or "0"), nextToken)
	tokens[token] = true
	neutralGeneration += 1
	pendingNeutral = false
	disableControls()
	return token
end

function Gate.Release(token, requireNeutral)
	if token then tokens[token] = nil end
	resetMobile()
	if tokenCount() > 0 then return false end
	if requireNeutral ~= false and not inputsNeutral() then
		beginNeutralWait()
	else
		pendingNeutral = false
		enableControls()
	end
	return true
end

function Gate.IsLocked()
	return tokenCount() > 0 or pendingNeutral
end

function Gate.ResetMobileState()
	resetMobile()
end

function Gate.ActiveCount()
	return tokenCount()
end

return Gate
