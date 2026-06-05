-- Neo Tokyo Racers - Character Sprint Controller Install
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Installs a small on-foot sprint LocalScript and removes the earlier broken
--   NTR_CharacterSprintDefaults script if present.
--
-- Safe design:
--   - Does not edit hovercar driving, drift, boost, camera assist, UI, VFX, or server scripts.
--   - Does not use ContextActionService for Shift, so it does not consume the drift key.
--   - Sprint only runs while the character is not seated in a VehicleSeat.
--   - Mobile auto-sprint reads Roblox's standard PlayerModule move vector instead of
--     private thumbstick UI internals.
--   - Uses ReplicatedStorage.NeoTokyoRacers.Shared.Config.CharacterMovement_EditAttributes
--     for speed, FOV, key, and animation tuning.
--
-- Modes:
--   INSTALL  - install/update the sprint controller and config.
--   ROLLBACK - remove the sprint controller and restore StarterPlayer.CharacterWalkSpeed.

local MODE = "INSTALL"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_character_sprint_controller_install"
local CLIENT_ROOT_NAME = "NeoTokyoRacersClient"
local CONTROLLERS_NAME = "Controllers"
local RUNTIME_NAME = "Runtime"
local SPRINT_SCRIPT_NAME = "CharacterSprintController_Active"
local OLD_BROKEN_SCRIPT_NAME = "NTR_CharacterSprintDefaults"

local CONFIG_ROOT_NAME = "NeoTokyoRacers"
local SHARED_NAME = "Shared"
local CONFIG_NAME = "Config"
local CHARACTER_CONFIG_NAME = "CharacterMovement_EditAttributes"

local DEFAULTS = {
	Enabled = true,
	AnimationId = "rbxassetid://10862419793",
	NormalWalkSpeed = 16,
	SprintWalkSpeed = 32,
	SprintFovEnabled = true,
	SprintFieldOfView = 80,
	FovTweenSeconds = 0.35,
	SprintKey = "LeftShift",
	MinimumMoveSpeedForAnimation = 1,
	MobileAutoSprintEnabled = true,
	MobileSprintMoveThreshold = 0.85,
	Debug = false,
}

local function log(message)
	print("[NTR Character Sprint] " .. message)
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then
		folder.Name = folder.Name .. "_OldNonFolder"
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureLocalScript(parent, name)
	local scriptObject = parent:FindFirstChild(name)
	if scriptObject and not scriptObject:IsA("LocalScript") then
		scriptObject.Name = scriptObject.Name .. "_OldNonLocalScript"
		scriptObject = nil
	end
	if not scriptObject then
		scriptObject = Instance.new("LocalScript")
		scriptObject.Name = name
		scriptObject.Parent = parent
	end
	return scriptObject
end

local function findStarterCharacterScripts()
	return StarterPlayer:FindFirstChild("StarterCharacterScripts")
end

local function removeOldBrokenScript()
	local starterCharacterScripts = findStarterCharacterScripts()
	if not starterCharacterScripts then
		return false
	end

	local oldScript = starterCharacterScripts:FindFirstChild(OLD_BROKEN_SCRIPT_NAME)
	if oldScript then
		oldScript:Destroy()
		return true
	end

	return false
end

local function installConfig()
	local root = ensureFolder(ReplicatedStorage, CONFIG_ROOT_NAME)
	local shared = ensureFolder(root, SHARED_NAME)
	local configRoot = ensureFolder(shared, CONFIG_NAME)
	local characterConfig = ensureFolder(configRoot, CHARACTER_CONFIG_NAME)

	for key, value in pairs(DEFAULTS) do
		if characterConfig:GetAttribute(key) == nil then
			characterConfig:SetAttribute(key, value)
		end
	end

	return characterConfig
end

local sprintClientSource = [=[
-- Neo Tokyo Racers - Character Sprint Controller
-- Installed by scripts/roblox_character_sprint_controller_install.lua.
-- On-foot only. Shift remains available to the vehicle drift controller while seated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PLAYER = Players.LocalPlayer
local CONFIG_PATH = { "NeoTokyoRacers", "Shared", "Config", "CharacterMovement_EditAttributes" }

local character = nil
local humanoid = nil
local animator = nil
local controls = nil
local sprintTrack = nil
local sprinting = false
local shiftHeld = false
local mobileAutoSprint = false
local savedCameraFov = nil
local activeTween = nil
local runningConnection = nil
local seatedConnection = nil
local diedConnection = nil
local heartbeatConnection = nil

local function findConfig()
	local current = ReplicatedStorage
	for _, name in ipairs(CONFIG_PATH) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function findControls()
	if controls then
		return controls
	end

	local playerScripts = PLAYER:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end

	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then
		return nil
	end

	local ok, module = pcall(require, playerModule)
	if not ok or not module or typeof(module.GetControls) ~= "function" then
		return nil
	end

	local okControls, result = pcall(function()
		return module:GetControls()
	end)
	if okControls then
		controls = result
	end

	return controls
end

local function configValue(name, fallback)
	local config = findConfig()
	if not config then
		return fallback
	end
	local value = config:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

local function debugLog(message)
	if configValue("Debug", false) == true then
		print("[NTR Character Sprint] " .. message)
	end
end

local function sprintKeyCode()
	local keyName = configValue("SprintKey", "LeftShift")
	local keyCode = Enum.KeyCode[keyName]
	return keyCode or Enum.KeyCode.LeftShift
end

local function isVehicleSeated()
	return humanoid
		and humanoid.SeatPart
		and humanoid.SeatPart:IsA("VehicleSeat")
end

local function mobileAutoSprintEnabled()
	return UserInputService.TouchEnabled == true
		and configValue("MobileAutoSprintEnabled", true) == true
end

local function moveInputMagnitude()
	local currentControls = findControls()
	if currentControls and typeof(currentControls.GetMoveVector) == "function" then
		local ok, moveVector = pcall(function()
			return currentControls:GetMoveVector()
		end)
		if ok and typeof(moveVector) == "Vector3" then
			return math.clamp(moveVector.Magnitude, 0, 1)
		end
	end

	return humanoid and math.clamp(humanoid.MoveDirection.Magnitude, 0, 1) or 0
end

local function shouldSprint()
	return shiftHeld or mobileAutoSprint
end

local updateSprintState = nil

local function tweenFov(targetFov)
	if configValue("SprintFovEnabled", true) ~= true then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	local duration = tonumber(configValue("FovTweenSeconds", 0.35)) or 0.35
	activeTween = TweenService:Create(
		camera,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ FieldOfView = targetFov }
	)
	activeTween:Play()
end

local function stopSprint(options)
	options = options or {}
	sprinting = false

	if sprintTrack and sprintTrack.IsPlaying then
		sprintTrack:Stop(0.15)
	end

	if humanoid and not isVehicleSeated() then
		humanoid.WalkSpeed = tonumber(configValue("NormalWalkSpeed", 16)) or 16
	end

	if options.restoreFov ~= false and savedCameraFov then
		tweenFov(savedCameraFov)
	end
	savedCameraFov = nil
end

local function startSprint()
	if sprinting then
		return
	end
	if configValue("Enabled", true) ~= true then
		return
	end
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if isVehicleSeated() then
		return
	end

	sprinting = true
	humanoid.WalkSpeed = tonumber(configValue("SprintWalkSpeed", 32)) or 32

	local camera = Workspace.CurrentCamera
	if camera and not savedCameraFov then
		savedCameraFov = camera.FieldOfView
	end

	tweenFov(tonumber(configValue("SprintFieldOfView", 80)) or 80)
end

updateSprintState = function()
	if shouldSprint() then
		startSprint()
	else
		stopSprint({ restoreFov = true })
	end
end

local function refreshTrack()
	if not humanoid then
		return
	end

	animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animationId = tostring(configValue("AnimationId", ""))
	if animationId == "" or animationId == "rbxassetid://0" then
		debugLog("No sprint AnimationId set; sprint speed still works, animation skipped.")
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = "NTR_SprintAnimation"
	animation.AnimationId = animationId

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if ok and trackOrError then
		sprintTrack = trackOrError
		sprintTrack.Priority = Enum.AnimationPriority.Movement
	else
		warn("[NTR Character Sprint] Could not load sprint animation: " .. tostring(trackOrError))
	end
end

local function updateAnimation(moveSpeed)
	if not sprinting or not sprintTrack or isVehicleSeated() then
		if sprintTrack and sprintTrack.IsPlaying then
			sprintTrack:Stop(0.15)
		end
		return
	end

	local minimumSpeed = tonumber(configValue("MinimumMoveSpeedForAnimation", 1)) or 1
	if moveSpeed >= minimumSpeed then
		if not sprintTrack.IsPlaying then
			sprintTrack:Play(0.15)
		end
	else
		if sprintTrack.IsPlaying then
			sprintTrack:Stop(0.15)
		end
	end
end

local function disconnectCharacterSignals()
	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end
	if seatedConnection then
		seatedConnection:Disconnect()
		seatedConnection = nil
	end
	if diedConnection then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function updateMobileAutoSprint()
	if not mobileAutoSprintEnabled() or not humanoid or humanoid.Health <= 0 or isVehicleSeated() then
		if mobileAutoSprint then
			mobileAutoSprint = false
			updateSprintState()
		end
		return
	end

	local threshold = math.clamp(tonumber(configValue("MobileSprintMoveThreshold", 0.85)) or 0.85, 0, 1)
	local movingHard = moveInputMagnitude() >= threshold
	if movingHard ~= mobileAutoSprint then
		mobileAutoSprint = movingHard
		updateSprintState()
	end
end

local function attachCharacter(newCharacter)
	disconnectCharacterSignals()
	mobileAutoSprint = false
	stopSprint({ restoreFov = false })

	character = newCharacter
	humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = tonumber(configValue("NormalWalkSpeed", 16)) or 16
	refreshTrack()

	runningConnection = humanoid.Running:Connect(updateAnimation)
	seatedConnection = humanoid.Seated:Connect(function(isSeated, seat)
		if isSeated and seat and seat:IsA("VehicleSeat") then
			mobileAutoSprint = false
			stopSprint({ restoreFov = true })
		elseif shouldSprint() then
			updateSprintState()
		end
	end)
	diedConnection = humanoid.Died:Connect(function()
		mobileAutoSprint = false
		stopSprint({ restoreFov = true })
	end)
	heartbeatConnection = RunService.Heartbeat:Connect(updateMobileAutoSprint)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == sprintKeyCode() then
		shiftHeld = true
		updateSprintState()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == sprintKeyCode() then
		shiftHeld = false
		updateSprintState()
	end
end)

PLAYER.CharacterAdded:Connect(attachCharacter)
if PLAYER.Character then
	attachCharacter(PLAYER.Character)
end
]=]

local function install()
	local removedOld = removeOldBrokenScript()
	local config = installConfig()
	local starterScripts = ensureFolder(StarterPlayer, "StarterPlayerScripts")
	local clientRoot = ensureFolder(starterScripts, CLIENT_ROOT_NAME)
	local controllers = ensureFolder(clientRoot, CONTROLLERS_NAME)
	local runtime = ensureFolder(controllers, RUNTIME_NAME)
	local sprintScript = ensureLocalScript(runtime, SPRINT_SCRIPT_NAME)

	sprintScript.Source = sprintClientSource
	sprintScript.Disabled = false
	StarterPlayer.CharacterWalkSpeed = DEFAULTS.NormalWalkSpeed

	log("Installed " .. sprintScript:GetFullName())
	log("Config: " .. config:GetFullName())
	if removedOld then
		log("Removed old broken " .. OLD_BROKEN_SCRIPT_NAME .. " script.")
	end
	log("Sprint uses " .. tostring(config:GetAttribute("SprintKey")) .. " only while on foot; vehicle Shift drift is left untouched.")
	log("Mobile auto-sprint is " .. tostring(config:GetAttribute("MobileAutoSprintEnabled")) .. " at move-vector threshold " .. tostring(config:GetAttribute("MobileSprintMoveThreshold")) .. ".")
end

local function rollback()
	local removedOld = removeOldBrokenScript()
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local sprintScript = starterScripts
		and starterScripts:FindFirstChild(CLIENT_ROOT_NAME)
		and starterScripts[CLIENT_ROOT_NAME]:FindFirstChild(CONTROLLERS_NAME)
		and starterScripts[CLIENT_ROOT_NAME][CONTROLLERS_NAME]:FindFirstChild(RUNTIME_NAME)
		and starterScripts[CLIENT_ROOT_NAME][CONTROLLERS_NAME][RUNTIME_NAME]:FindFirstChild(SPRINT_SCRIPT_NAME)

	if sprintScript then
		sprintScript:Destroy()
		log("Removed " .. SPRINT_SCRIPT_NAME .. ".")
	end

	StarterPlayer.CharacterWalkSpeed = DEFAULTS.NormalWalkSpeed
	if removedOld then
		log("Removed old broken " .. OLD_BROKEN_SCRIPT_NAME .. " script.")
	end
	log("Rollback complete. New Play sessions use normal walk speed again.")
end

if MODE == "INSTALL" then
	install()
elseif MODE == "ROLLBACK" then
	rollback()
else
	error("[" .. SCRIPT_ID .. "] Unknown MODE: " .. tostring(MODE))
end
