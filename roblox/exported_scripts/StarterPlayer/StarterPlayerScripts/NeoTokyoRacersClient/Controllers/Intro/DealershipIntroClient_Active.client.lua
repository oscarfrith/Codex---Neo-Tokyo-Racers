-- Neo Tokyo Racers - Dealership Intro Client Active
-- Installed by scripts/roblox_dealership_intro_phase8_dynamic_arrow_tether_once.lua
--
-- Local-only intro helper:
--   - Reads Workspace.NeoTokyoRacersWorld.Dealership.Intro attributes.
--   - Shows the objective only until the player first reaches the desk.
--   - Creates a client-only dynamic arrow tether from the player to the desk.
--   - Persists objective completion through the Phase 8 server progress service.
--   - Keeps the Phase 7 leave-and-reenter desk gate for later garage opens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LOG_PREFIX = "[NTR Dealership Intro Client]"
local CLIENT_ROOT_NAME = "_NTR_ClientOnly"
local INTRO_PATH_NAME = "IntroPath"
local OBJECTIVE_GUI_NAME = "NTR_DealershipIntroObjective"
local COMPLETE_ATTRIBUTE = "NTRDealershipIntroObjectiveComplete"
local REMOTE_FOLDER_NAME = "DealershipIntro"
local GET_REMOTE_NAME = "GetDealershipIntroObjectiveComplete"
local COMPLETE_REMOTE_NAME = "CompleteDealershipIntroObjective"

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function log(message)
	print(LOG_PREFIX .. " " .. message)
end

local function warnOnceFactory()
	local warned = {}
	return function(key, message)
		if warned[key] then
			return
		end
		warned[key] = true
		warn(LOG_PREFIX .. " " .. message)
	end
end

local warnOnce = warnOnceFactory()

local function getAttribute(instance, name, fallback)
	local value = instance:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

local function waitForCharacterRoot()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart")
	while not root do
		character = player.Character or player.CharacterAdded:Wait()
		root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			warnOnce("missing-root", "Waiting for HumanoidRootPart before starting intro distance checks.")
		end
	end
	return character, root
end

local function waitForIntro()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local dealership = world:WaitForChild("Dealership")
	return dealership:WaitForChild("Intro")
end

local function getIntroConfig(intro, deskTrigger)
	local activationDistance = getAttribute(intro, "DeskActivationDistance", 5)
	if deskTrigger and deskTrigger:GetAttribute("ActivationDistance") ~= nil then
		activationDistance = deskTrigger:GetAttribute("ActivationDistance")
	end

	return {
		Enabled = getAttribute(intro, "Enabled", true),
		DeskActivationDistance = tonumber(activationDistance) or 5,
		AutoOpenGarageAtDesk = getAttribute(intro, "AutoOpenGarageAtDesk", true),
		ShowObjectiveText = getAttribute(intro, "ShowObjectiveText", true),
		IntroObjectiveText = tostring(getAttribute(intro, "IntroObjectiveText", "Go to the dealership desk")),
		CameraIntroEnabled = getAttribute(intro, "CameraIntroEnabled", true),
		CameraIntroDuration = tonumber(getAttribute(intro, "CameraIntroDuration", 1.25)) or 1.25,
		PersistIntroObjectiveCompletion = getAttribute(intro, "PersistIntroObjectiveCompletion", true),
		DynamicArrowTetherEnabled = getAttribute(intro, "DynamicArrowTetherEnabled", true),
		DynamicArrowTetherSpacing = math.max(2, tonumber(getAttribute(intro, "DynamicArrowTetherSpacing", 9)) or 9),
		DynamicArrowTetherMaxArrows = math.clamp(math.floor(tonumber(getAttribute(intro, "DynamicArrowTetherMaxArrows", 18)) or 18), 1, 40),
		DynamicArrowTetherMinDistance = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherMinDistance", 4)) or 4),
		DynamicArrowTetherStartOffset = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherStartOffset", 4)) or 4),
		DynamicArrowTetherEndOffset = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherEndOffset", 3)) or 3),
		DynamicArrowTetherHeightOffset = tonumber(getAttribute(intro, "DynamicArrowTetherHeightOffset", getAttribute(intro, "PathArrowHeightOffset", 1.8))) or 1.8,
		DynamicArrowTetherArrowScale = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherArrowScale", 1)) or 1, 0.45, 2.25),
		DynamicArrowTetherShaftEnabled = getAttribute(intro, "DynamicArrowTetherShaftEnabled", true),
		DynamicArrowTetherShaftLength = math.max(0.4, tonumber(getAttribute(intro, "DynamicArrowTetherShaftLength", 2.6)) or 2.6),
		DynamicArrowTetherShaftWidth = math.max(0.05, tonumber(getAttribute(intro, "DynamicArrowTetherShaftWidth", 0.42)) or 0.42),
		DynamicArrowTetherHeadLength = math.max(0.25, tonumber(getAttribute(intro, "DynamicArrowTetherHeadLength", 1.05)) or 1.05),
		DynamicArrowTetherHeadWidth = math.max(0.05, tonumber(getAttribute(intro, "DynamicArrowTetherHeadWidth", 0.36)) or 0.36),
		DynamicArrowTetherArrowTransparency = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherArrowTransparency", 0.12)) or 0.12, 0, 1),
		DynamicArrowTetherPulseSpeed = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherPulseSpeed", 2)) or 2),
		DynamicArrowTetherColor = getAttribute(intro, "DynamicArrowTetherColor", Color3.fromRGB(172, 255, 197)),
		DynamicArrowTetherHeadColor = getAttribute(intro, "DynamicArrowTetherHeadColor", Color3.fromRGB(255, 120, 210)),
		DynamicArrowTetherBeamEnabled = getAttribute(intro, "DynamicArrowTetherBeamEnabled", true),
		DynamicArrowTetherBeamColor = getAttribute(intro, "DynamicArrowTetherBeamColor", Color3.fromRGB(102, 255, 214)),
		DynamicArrowTetherBeamWidth = math.max(0.1, tonumber(getAttribute(intro, "DynamicArrowTetherBeamWidth", 3.5)) or 3.5),
		DynamicArrowTetherBeamTransparency = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherBeamTransparency", 0.58)) or 0.58, 0, 1),
		DynamicArrowTetherBeamCoreWidth = math.max(0.05, tonumber(getAttribute(intro, "DynamicArrowTetherBeamCoreWidth", 0.8)) or 0.8),
		DynamicArrowTetherBeamCoreTransparency = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherBeamCoreTransparency", 0.25)) or 0.25, 0, 1),
		Debug = getAttribute(intro, "Debug", false),
	}
end

local function debugPrint(config, message)
	if config.Debug then
		log(message)
	end
end

local function clearObjectiveGui()
	local playerGui = player:FindFirstChild("PlayerGui")
	local existing = playerGui and playerGui:FindFirstChild(OBJECTIVE_GUI_NAME)
	if existing then
		existing:Destroy()
	end
end

local function createObjectiveGui(config)
	clearObjectiveGui()
	if not config.ShowObjectiveText then
		return nil
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = OBJECTIVE_GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 18
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "ObjectiveRoot"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 18)
	root.Size = UDim2.new(0, 360, 0, 46)
	root.BackgroundColor3 = Color3.fromRGB(5, 9, 7)
	root.BackgroundTransparency = 0.18
	root.BorderSizePixel = 0
	root.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(172, 255, 197)
	stroke.Thickness = 1
	stroke.Transparency = 0.28
	stroke.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "ObjectiveText"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 5)
	label.Size = UDim2.new(1, -24, 1, -10)
	label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	label.Text = config.IntroObjectiveText
	label.TextColor3 = Color3.fromRGB(218, 255, 231)
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = root

	local camera = Workspace.CurrentCamera
	local function updateScale()
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.78, 1)
	end

	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	return gui
end

local function clearPathArrows()
	local clientRoot = Workspace:FindFirstChild(CLIENT_ROOT_NAME)
	local introPath = clientRoot and clientRoot:FindFirstChild(INTRO_PATH_NAME)
	if introPath then
		introPath:Destroy()
	end
end

local function ensureClientPathFolder()
	local clientRoot = Workspace:FindFirstChild(CLIENT_ROOT_NAME)
	if not clientRoot then
		clientRoot = Instance.new("Folder")
		clientRoot.Name = CLIENT_ROOT_NAME
		clientRoot.Parent = Workspace
	end

	local introPath = clientRoot:FindFirstChild(INTRO_PATH_NAME)
	if introPath then
		introPath:Destroy()
	end

	introPath = Instance.new("Folder")
	introPath.Name = INTRO_PATH_NAME
	introPath.Parent = clientRoot
	return introPath
end

local function makeArrowPart(parent, name, size, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.12
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeBeamAnchor(parent, name)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = parent

	local attachment = Instance.new("Attachment")
	attachment.Name = "Attachment"
	attachment.Parent = part

	return part, attachment
end

local function createTetherBeam(parent, config)
	if not config.DynamicArrowTetherBeamEnabled then
		return nil
	end

	local beamFolder = Instance.new("Folder")
	beamFolder.Name = "DynamicBeam"
	beamFolder.Parent = parent

	local startPart, startAttachment = makeBeamAnchor(beamFolder, "BeamStart")
	local endPart, endAttachment = makeBeamAnchor(beamFolder, "BeamEnd")

	local aura = Instance.new("Beam")
	aura.Name = "AuraBeam"
	aura.Attachment0 = startAttachment
	aura.Attachment1 = endAttachment
	aura.Color = ColorSequence.new(config.DynamicArrowTetherBeamColor)
	aura.Transparency = NumberSequence.new(config.DynamicArrowTetherBeamTransparency)
	aura.Width0 = config.DynamicArrowTetherBeamWidth
	aura.Width1 = config.DynamicArrowTetherBeamWidth
	aura.LightEmission = 1
	aura.Brightness = 1.8
	aura.FaceCamera = true
	aura.Segments = 16
	aura.Enabled = false
	aura.Parent = beamFolder

	local core = Instance.new("Beam")
	core.Name = "CoreBeam"
	core.Attachment0 = startAttachment
	core.Attachment1 = endAttachment
	core.Color = ColorSequence.new(config.DynamicArrowTetherColor)
	core.Transparency = NumberSequence.new(config.DynamicArrowTetherBeamCoreTransparency)
	core.Width0 = config.DynamicArrowTetherBeamCoreWidth
	core.Width1 = config.DynamicArrowTetherBeamCoreWidth
	core.LightEmission = 1
	core.Brightness = 2.2
	core.FaceCamera = true
	core.Segments = 16
	core.Enabled = false
	core.Parent = beamFolder

	return {
		StartPart = startPart,
		EndPart = endPart,
		Aura = aura,
		Core = core,
	}
end

local function setBeamVisible(beam, visible)
	if not beam then
		return
	end

	beam.Aura.Enabled = visible
	beam.Core.Enabled = visible
end

local function updateBeam(beam, startPosition, endPosition)
	if not beam then
		return
	end

	beam.StartPart.CFrame = CFrame.new(startPosition)
	beam.EndPart.CFrame = CFrame.new(endPosition)
end

local function createArrowModel(parent, index, config)
	local scale = config.DynamicArrowTetherArrowScale
	local arrow = Instance.new("Model")
	arrow.Name = string.format("DynamicArrow_%02d", index)
	arrow.Parent = parent

	local shaft = makeArrowPart(arrow, "Shaft", Vector3.new(config.DynamicArrowTetherShaftWidth, 0.16, config.DynamicArrowTetherShaftLength) * scale, config.DynamicArrowTetherColor)
	local left = makeArrowPart(arrow, "HeadLeft", Vector3.new(config.DynamicArrowTetherHeadWidth, 0.16, config.DynamicArrowTetherHeadLength) * scale, config.DynamicArrowTetherHeadColor)
	local right = makeArrowPart(arrow, "HeadRight", Vector3.new(config.DynamicArrowTetherHeadWidth, 0.16, config.DynamicArrowTetherHeadLength) * scale, config.DynamicArrowTetherHeadColor)
	return {
		Model = arrow,
		Shaft = shaft,
		Left = left,
		Right = right,
		Transparency = config.DynamicArrowTetherArrowTransparency,
		ShaftEnabled = config.DynamicArrowTetherShaftEnabled,
	}
end

local function setArrowVisible(arrow, visible)
	local transparency = visible and arrow.Transparency or 1
	arrow.Shaft.Transparency = arrow.ShaftEnabled and transparency or 1
	arrow.Left.Transparency = transparency
	arrow.Right.Transparency = transparency
end

local function updateArrow(arrow, center, flatDirection, config, pulseOffset)
	local scale = config.DynamicArrowTetherArrowScale
	local shaftForward = config.DynamicArrowTetherShaftLength * 0.48 * scale
	local headForward = (config.DynamicArrowTetherShaftLength * 0.78 + config.DynamicArrowTetherHeadLength * 0.45) * scale
	local headSide = config.DynamicArrowTetherHeadWidth * 0.95 * scale
	local cframe = CFrame.lookAt(center, center + flatDirection)
	local rightVector = cframe.RightVector
	local pulse = config.DynamicArrowTetherPulseSpeed > 0 and (0.08 * math.sin(os.clock() * config.DynamicArrowTetherPulseSpeed + pulseOffset)) or 0
	local lift = Vector3.new(0, pulse, 0)

	arrow.Shaft.CFrame = cframe + lift
	arrow.Left.CFrame = CFrame.lookAt(center + lift + flatDirection * shaftForward - rightVector * headSide, center + lift + flatDirection * headForward)
	arrow.Right.CFrame = CFrame.lookAt(center + lift + flatDirection * shaftForward + rightVector * headSide, center + lift + flatDirection * headForward)
end

local function createDynamicTether(root, deskTrigger, config)
	clearPathArrows()
	if not config.DynamicArrowTetherEnabled then
		return nil
	end

	local folder = ensureClientPathFolder()
	local beam = createTetherBeam(folder, config)
	local arrows = {}
	for index = 1, config.DynamicArrowTetherMaxArrows do
		arrows[index] = createArrowModel(folder, index, config)
		setArrowVisible(arrows[index], false)
	end

	local active = true
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not active or not root.Parent or not deskTrigger.Parent then
			return
		end

		local rawStart = root.Position
		local rawEnd = deskTrigger.Position
		local delta = rawEnd - rawStart
		local flatDelta = Vector3.new(delta.X, 0, delta.Z)
		local distance = flatDelta.Magnitude

		if distance <= config.DynamicArrowTetherMinDistance then
			setBeamVisible(beam, false)
			for _, arrow in ipairs(arrows) do
				setArrowVisible(arrow, false)
			end
			return
		end

		local direction = flatDelta.Unit
		local usableDistance = math.max(0, distance - config.DynamicArrowTetherStartOffset - config.DynamicArrowTetherEndOffset)
		local arrowCount = math.clamp(math.floor(usableDistance / config.DynamicArrowTetherSpacing), 1, config.DynamicArrowTetherMaxArrows)
		local beamStart = rawStart + direction * config.DynamicArrowTetherStartOffset + Vector3.new(0, config.DynamicArrowTetherHeightOffset, 0)
		local beamEnd = rawEnd - direction * config.DynamicArrowTetherEndOffset + Vector3.new(0, config.DynamicArrowTetherHeightOffset, 0)
		updateBeam(beam, beamStart, beamEnd)
		setBeamVisible(beam, true)

		for index, arrow in ipairs(arrows) do
			if index <= arrowCount then
				local t = index / (arrowCount + 1)
				local travel = config.DynamicArrowTetherStartOffset + usableDistance * t
				local center = rawStart + direction * travel + Vector3.new(0, config.DynamicArrowTetherHeightOffset, 0)
				updateArrow(arrow, center, direction, config, index * 0.55)
				setArrowVisible(arrow, true)
			else
				setArrowVisible(arrow, false)
			end
		end
	end)

	return {
		Folder = folder,
		Stop = function()
			active = false
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if folder then
				folder:Destroy()
			end
		end,
	}
end

local function playCameraIntro(intro, config)
	if not config.CameraIntroEnabled then
		return
	end

	local cameraFolder = intro:FindFirstChild("Camera")
	local cameraPoint = cameraFolder and cameraFolder:FindFirstChild("DealershipLookCameraPoint")
	if not cameraPoint or not cameraPoint:IsA("BasePart") then
		warnOnce("missing-camera-point", "CameraIntroEnabled is true, but DealershipLookCameraPoint was not found as a BasePart.")
		return
	end

	local deskTrigger = intro:FindFirstChild("Desk") and intro.Desk:FindFirstChild("GarageDeskTrigger")
	local lookPosition = deskTrigger and deskTrigger:IsA("BasePart") and deskTrigger.Position or (cameraPoint.Position + cameraPoint.CFrame.LookVector * 20)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local originalType = camera.CameraType
	local originalSubject = camera.CameraSubject
	local originalCFrame = camera.CFrame
	local duration = math.clamp(config.CameraIntroDuration, 0.1, 5)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPoint.Position, lookPosition)
	camera:SetAttribute("NTRDealershipIntroCameraActive", true)

	local targetCFrame = CFrame.lookAt(cameraPoint.Position, lookPosition)
	local tween = TweenService:Create(camera, TweenInfo.new(math.min(duration, 1.25), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = targetCFrame,
	})
	tween:Play()

	task.delay(duration, function()
		if camera:GetAttribute("NTRDealershipIntroCameraActive") == true then
			camera:SetAttribute("NTRDealershipIntroCameraActive", false)
			camera.CameraType = originalType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or originalType
			camera.CameraSubject = originalSubject
			if camera.CameraType == Enum.CameraType.Custom and originalSubject == nil then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraSubject = humanoid
				end
			elseif camera.CameraType ~= Enum.CameraType.Custom then
				camera.CFrame = originalCFrame
			end
		end
	end)
end

local function getProgressRemotes()
	local neoTokyo = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local shared = neoTokyo and neoTokyo:FindFirstChild("Shared")
	local remotes = shared and shared:FindFirstChild("Remotes")
	local folder = remotes and remotes:FindFirstChild(REMOTE_FOLDER_NAME)
	local getComplete = folder and folder:FindFirstChild(GET_REMOTE_NAME)
	local complete = folder and folder:FindFirstChild(COMPLETE_REMOTE_NAME)

	if getComplete and not getComplete:IsA("RemoteFunction") then
		getComplete = nil
	end
	if complete and not complete:IsA("RemoteEvent") then
		complete = nil
	end

	return getComplete, complete
end

local function isObjectiveComplete(config)
	if not config.PersistIntroObjectiveCompletion then
		return false
	end

	if player:GetAttribute(COMPLETE_ATTRIBUTE) == true then
		return true
	end

	local getComplete = nil
	local started = os.clock()
	while os.clock() - started < 6 and not getComplete do
		getComplete = select(1, getProgressRemotes())
		if not getComplete then
			task.wait(0.1)
		end
	end

	if not getComplete then
		warnOnce("missing-progress-get", "Phase 8 progress RemoteFunction was not found; objective completion cannot persist in this Play session.")
		return false
	end

	local ok, complete = pcall(function()
		return getComplete:InvokeServer()
	end)
	if ok and complete == true then
		player:SetAttribute(COMPLETE_ATTRIBUTE, true)
		return true
	end

	if not ok then
		warnOnce("progress-get-failed", "Could not read persisted intro completion: " .. tostring(complete))
	end

	return false
end

local function markObjectiveComplete(config)
	if player:GetAttribute(COMPLETE_ATTRIBUTE) == true then
		return
	end

	player:SetAttribute(COMPLETE_ATTRIBUTE, true)
	if not config.PersistIntroObjectiveCompletion then
		return
	end

	local _, completeRemote = getProgressRemotes()
	if completeRemote then
		completeRemote:FireServer()
	else
		warnOnce("missing-progress-complete", "Phase 8 completion RemoteEvent was not found; objective is hidden for this session only.")
	end
end

local function tryOpenGarage(config)
	if not config.AutoOpenGarageAtDesk then
		log("Reached desk. AutoOpenGarageAtDesk is false, so no garage open call was attempted.")
		return
	end

	local openEvent = script.Parent:FindFirstChild("OpenGarageFromIntro")
	if not openEvent then
		openEvent = script.Parent:WaitForChild("OpenGarageFromIntro", 5)
	end

	if openEvent and openEvent:IsA("BindableEvent") then
		log("Reached dealership desk. Opening garage through OpenGarageFromIntro.")
		openEvent:Fire()
	else
		warnOnce("missing-open-hook", "Reached dealership desk, but OpenGarageFromIntro BindableEvent was not found under " .. script.Parent:GetFullName() .. ". Run scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua and scripts/roblox_dealership_intro_phase7_exit_button_reopen_gate.lua, then test in a fresh Play Solo session.")
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	local garageGui = playerGui and playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	if garageGui and garageGui.Enabled then
		warnOnce("garage-already-visible", "Garage UI is already visible. This likely means current startup still auto-opens/builds garage before the intro desk gate.")
	end
end

local function cleanup(objectiveGui, tether)
	if objectiveGui then
		objectiveGui.Enabled = false
	end
	if tether then
		tether.Stop()
	else
		clearPathArrows()
	end
end

local function run()
	local _, root = waitForCharacterRoot()
	local intro = waitForIntro()
	local deskFolder = intro:WaitForChild("Desk")
	local deskTrigger = deskFolder:WaitForChild("GarageDeskTrigger")

	if not deskTrigger:IsA("BasePart") then
		warnOnce("bad-desk-trigger", "Intro.Desk.GarageDeskTrigger is not a BasePart; intro client cannot run distance checks.")
		return
	end

	local config = getIntroConfig(intro, deskTrigger)
	if not config.Enabled then
		log("Intro.Enabled is false; dealership intro client is idle.")
		return
	end

	debugPrint(config, "Intro enabled. Activation distance: " .. tostring(config.DeskActivationDistance))

	local objectiveComplete = isObjectiveComplete(config)
	local objectiveGui = nil
	local tether = nil

	if not objectiveComplete then
		objectiveGui = createObjectiveGui(config)
		tether = createDynamicTether(root, deskTrigger, config)
		playCameraIntro(intro, config)
	else
		clearObjectiveGui()
		clearPathArrows()
		debugPrint(config, "Desk objective already complete; objective UI and tether are hidden.")
	end

	local closeEvent = script.Parent:FindFirstChild("GarageClosedFromDealershipExit")
	if closeEvent and not closeEvent:IsA("BindableEvent") then
		warnOnce("bad-close-hook", "GarageClosedFromDealershipExit exists but is " .. closeEvent.ClassName .. ", expected BindableEvent. Reopen gating will not arm.")
		closeEvent = nil
	end
	if not closeEvent then
		closeEvent = Instance.new("BindableEvent")
		closeEvent.Name = "GarageClosedFromDealershipExit"
		closeEvent.Parent = script.Parent
	end

	local dismissedUntilLeave = false
	local wasInsideZone = false
	local reopenDistance = math.max(config.DeskActivationDistance + 3, config.DeskActivationDistance * 1.75)

	local function onExited()
		dismissedUntilLeave = true
		wasInsideZone = true
		log("Dealership menu exited. Walk away from the desk, then re-enter the zone to reopen it.")
	end

	closeEvent.Event:Connect(onExited)

	while true do
		if not root.Parent then
			_, root = waitForCharacterRoot()
			if tether then
				tether.Stop()
				tether = createDynamicTether(root, deskTrigger, config)
			end
		end

		local distance = (root.Position - deskTrigger.Position).Magnitude
		local insideZone = distance <= config.DeskActivationDistance

		if dismissedUntilLeave and distance >= reopenDistance then
			dismissedUntilLeave = false
			wasInsideZone = false
			log("Dealership desk reopen gate reset. Re-enter the desk zone to reopen the menu.")
		end

		if insideZone and not wasInsideZone and not dismissedUntilLeave then
			if not objectiveComplete then
				objectiveComplete = true
				cleanup(objectiveGui, tether)
				objectiveGui = nil
				tether = nil
				markObjectiveComplete(config)
			end

			tryOpenGarage(config)
		end

		wasInsideZone = insideZone
		task.wait(0.15)
	end
end

task.spawn(function()
	local ok, err = pcall(run)
	if not ok then
		warn(LOG_PREFIX .. " Failed: " .. tostring(err))
		clearObjectiveGui()
		clearPathArrows()
	end
end)
