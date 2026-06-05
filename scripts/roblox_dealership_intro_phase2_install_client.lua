-- Neo Tokyo Racers - Dealership Intro Phase 2: Install Client
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Installs an isolated LocalScript at:
--     StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active
--
-- Safe design:
--   - Creates/reuses only the Intro controller folder and target LocalScript.
--   - Does not edit the active bootstrap, garage server, driving, VFX, LOD,
--     lighting, traffic, mobile controls, or purchase logic.
--   - Does not create backup folders.
--
-- Important integration note:
--   Phase 3 exposes the local OpenGarageFromIntro BindableEvent in the active
--   bootstrap. If Phase 3 has not run yet, the intro client prints a clear
--   warning at the desk instead of faking a garage open call.

local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_dealership_intro_phase2_install_client"
local TARGET_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active"

local DEALERSHIP_INTRO_CLIENT_SOURCE = [===[
-- Neo Tokyo Racers - Dealership Intro Client Active
-- Installed by scripts/roblox_dealership_intro_phase2_install_client.lua
--
-- Local-only intro helper:
--   - Reads Workspace.NeoTokyoRacersWorld.Dealership.Intro attributes.
--   - Shows a compact objective UI.
--   - Creates local-only path arrows under Workspace._NTR_ClientOnly.IntroPath.
--   - Watches distance to Intro.Desk.GarageDeskTrigger.
--   - Does not spawn preview vehicles or change server purchase logic.
--
-- Integration:
--   Phase 3 exposes a local OpenGarageFromIntro BindableEvent in the active
--   bootstrap. If the event is missing, this client prints a clear warning.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LOG_PREFIX = "[NTR Dealership Intro Client]"
local CLIENT_ROOT_NAME = "_NTR_ClientOnly"
local INTRO_PATH_NAME = "IntroPath"
local OBJECTIVE_GUI_NAME = "NTR_DealershipIntroObjective"

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
		ShowPathArrows = getAttribute(intro, "ShowPathArrows", true),
		ShowObjectiveText = getAttribute(intro, "ShowObjectiveText", true),
		IntroObjectiveText = tostring(getAttribute(intro, "IntroObjectiveText", "Go to the dealership desk")),
		DeskPromptText = tostring(getAttribute(intro, "DeskPromptText", "Open Garage")),
		CameraIntroEnabled = getAttribute(intro, "CameraIntroEnabled", true),
		CameraIntroDuration = tonumber(getAttribute(intro, "CameraIntroDuration", 1.25)) or 1.25,
		PathArrowHeightOffset = tonumber(getAttribute(intro, "PathArrowHeightOffset", 2)) or 2,
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

local function sortedPathNodes(intro)
	local pathFolder = intro:FindFirstChild("Path")
	local nodes = {}
	if not pathFolder then
		return nodes
	end

	for _, child in ipairs(pathFolder:GetChildren()) do
		if child:IsA("BasePart") and string.match(child.Name, "^PathNode_%d+$") then
			table.insert(nodes, child)
		end
	end

	table.sort(nodes, function(a, b)
		return a.Name < b.Name
	end)

	return nodes
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
	part.Transparency = 0.16
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createArrow(parent, index, fromPosition, toPosition, heightOffset)
	local direction = toPosition - fromPosition
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.1 then
		flatDirection = Vector3.new(0, 0, -1)
	end
	flatDirection = flatDirection.Unit

	local center = fromPosition + Vector3.new(0, heightOffset, 0)
	local arrow = Instance.new("Model")
	arrow.Name = string.format("Arrow_%02d", index)
	arrow.Parent = parent

	local shaft = makeArrowPart(arrow, "Shaft", Vector3.new(0.45, 0.18, 3.2), Color3.fromRGB(172, 255, 197))
	shaft.CFrame = CFrame.lookAt(center, center + flatDirection)

	local left = makeArrowPart(arrow, "HeadLeft", Vector3.new(0.42, 0.18, 1.35), Color3.fromRGB(255, 120, 210))
	left.CFrame = CFrame.lookAt(center + flatDirection * 1.55 - shaft.CFrame.RightVector * 0.42, center + flatDirection * 2.35)

	local right = makeArrowPart(arrow, "HeadRight", Vector3.new(0.42, 0.18, 1.35), Color3.fromRGB(255, 120, 210))
	right.CFrame = CFrame.lookAt(center + flatDirection * 1.55 + shaft.CFrame.RightVector * 0.42, center + flatDirection * 2.35)
end

local function createPathArrows(intro, config)
	clearPathArrows()
	if not config.ShowPathArrows then
		return nil
	end

	local nodes = sortedPathNodes(intro)
	if #nodes == 0 then
		warnOnce("missing-path-nodes", "No PathNode_## marker parts found under Intro.Path; objective will show without path arrows.")
		return nil
	end

	local folder = ensureClientPathFolder()
	for index, node in ipairs(nodes) do
		local nextNode = nodes[index + 1]
		local toPosition = nextNode and nextNode.Position or node.Position + (index > 1 and (node.Position - nodes[index - 1].Position) or Vector3.new(0, 0, -1))
		createArrow(folder, index, node.Position, toPosition, config.PathArrowHeightOffset)
	end

	return folder
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
		warnOnce("missing-open-hook", "Reached dealership desk, but OpenGarageFromIntro BindableEvent was not found under " .. script.Parent:GetFullName() .. ". Run scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua, then test in a fresh Play Solo session.")
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	local garageGui = playerGui and playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	if garageGui and garageGui.Enabled then
		warnOnce("garage-already-visible", "Garage UI is already visible. This likely means current startup still auto-opens/builds garage before the intro desk gate.")
	end
end

local function cleanup(objectiveGui)
	if objectiveGui then
		objectiveGui.Enabled = false
	end
	clearPathArrows()
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

	local objectiveGui = createObjectiveGui(config)
	createPathArrows(intro, config)
	playCameraIntro(intro, config)

	local opened = false
	while not opened do
		if not root.Parent then
			_, root = waitForCharacterRoot()
		end

		local distance = (root.Position - deskTrigger.Position).Magnitude
		if distance <= config.DeskActivationDistance then
			opened = true
			cleanup(objectiveGui)
			tryOpenGarage(config)
			break
		end

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
]===]

local created = {}
local reused = {}
local changed = {}

local function log(message)
	print("[NTR Dealership Intro Phase 2] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(("Existing %s is %s, expected Folder. No changes applied."):format(
				safeFullName(existing),
				existing.ClassName
			))
		end
		table.insert(reused, safeFullName(existing) .. " -> Folder")
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	table.insert(created, safeFullName(folder) .. " -> Folder")
	return folder
end

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = ensureFolder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = ensureFolder(clientRoot, "Controllers")
local introFolder = ensureFolder(controllers, "Intro")

local localScript = introFolder:FindFirstChild("DealershipIntroClient_Active")
if localScript then
	if not localScript:IsA("LocalScript") then
		error(("Existing %s is %s, expected LocalScript. No changes applied to it."):format(
			safeFullName(localScript),
			localScript.ClassName
		))
	end
	table.insert(reused, safeFullName(localScript) .. " -> LocalScript")
else
	localScript = Instance.new("LocalScript")
	localScript.Name = "DealershipIntroClient_Active"
	localScript.Parent = introFolder
	table.insert(created, safeFullName(localScript) .. " -> LocalScript")
end

if localScript.Source ~= DEALERSHIP_INTRO_CLIENT_SOURCE then
	localScript.Source = DEALERSHIP_INTRO_CLIENT_SOURCE
	table.insert(changed, safeFullName(localScript) .. ".Source")
end

if localScript.Disabled then
	localScript.Disabled = false
	table.insert(changed, safeFullName(localScript) .. ".Disabled = false")
end

localScript:SetAttribute("InstalledBy", SCRIPT_ID)
localScript:SetAttribute("InstalledAt", os.date("%Y-%m-%d %H:%M:%S"))
localScript:SetAttribute("GarageOpenIntegration", "Uses local OpenGarageFromIntro BindableEvent installed by Phase 3")

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 2 Install Client")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Target: " .. TARGET_PATH)
line("- Installed LocalScript: " .. safeFullName(localScript))
line("- Created objects: " .. tostring(#created))
line("- Reused objects: " .. tostring(#reused))
line("- Changed fields: " .. tostring(#changed))
line("- Garage open integration: uses OpenGarageFromIntro BindableEvent after Phase 3 is installed.")
line("")

line("## Created")
line("")
if #created == 0 then
	line("- None.")
else
	for _, item in ipairs(created) do
		line("- " .. item)
	end
end
line("")

line("## Reused")
line("")
if #reused == 0 then
	line("- None.")
else
	for _, item in ipairs(reused) do
		line("- " .. item)
	end
end
line("")

line("## Changed")
line("")
if #changed == 0 then
	line("- None.")
else
	for _, item in ipairs(changed) do
		line("- " .. item)
	end
end
line("")

line("## Play Test")
line("")
line("1. Start Play Solo.")
line("2. Confirm the small objective UI appears.")
line("3. Confirm local-only arrows appear under Workspace._NTR_ClientOnly.IntroPath in the client view.")
line("4. Walk to Workspace.NeoTokyoRacersWorld.Dealership.Intro.Desk.GarageDeskTrigger.")
line("5. Confirm the objective and arrows disappear.")
line("6. Paste any [NTR Dealership Intro Client] warning output back into Codex.")

log("Installed intro client at " .. safeFullName(localScript))
log("Garage open integration expects Phase 3 OpenGarageFromIntro hook.")
print(table.concat(report, "\n"))
