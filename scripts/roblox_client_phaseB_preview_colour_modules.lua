-- Neo Tokyo Racers - Main Client Extraction Phase B
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates staged preview and colour modules for the future extraction of
--   HOVER_RACING_V2_Client. This phase prepares preview vehicle building,
--   preview camera section logic, and shared HSB colour picker helpers without
--   changing live gameplay.
--
-- Safe effects:
--   - Creates/updates ModuleScripts under:
--     StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview
--     StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit, disable, enable, rename, move, or delete HOVER_RACING_V2_Client.
--   - Switch live preview building, live colour UI, live camera logic, or live menus.
--   - Change server actions, vehicle logic, driving, VFX runtime, mobile controls,
--     LOD, lighting, traffic, assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_client_phaseB_preview_colour_modules"
local PHASE8_SCRIPT_ID = "roblox_hierarchy_phase8_client_ui_controller_scaffold"
local PHASE_A_SCRIPT_ID = "roblox_client_phaseA_core_boundary_modules"

local function log(message)
	print("[NTR Client Phase B] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No changes applied.")
		end
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
end

local function canOverwrite(module)
	if module.Source == "" then
		return true
	end
	local createdBy = module:GetAttribute("CreatedBy")
	local status = module:GetAttribute("MigrationStatus")
	return createdBy == SCRIPT_ID
		or createdBy == PHASE8_SCRIPT_ID
		or status == "ScaffoldOnly"
		or status == "PhaseB_PreviewColourBoundary"
end

local function writeModule(parent, name, source, description)
	local module = parent:FindFirstChild(name)
	if module and not module:IsA("ModuleScript") then
		error("Existing " .. module:GetFullName() .. " is a " .. module.ClassName .. ", expected ModuleScript. No changes applied.")
	end
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Parent = parent
	end

	if not canOverwrite(module) then
		error("Target " .. module:GetFullName() .. " already exists and was not created by the scaffold or this phase. No changes applied.")
	end

	module.Source = source
	module:SetAttribute("CreatedBy", SCRIPT_ID)
	module:SetAttribute("MigrationStatus", "PhaseB_PreviewColourBoundary")
	module:SetAttribute("LiveEnabled", false)
	module:SetAttribute("Description", description or "")
	module:SetAttribute("LastUpdated", os.date("%Y-%m-%d %H:%M:%S"))
	return module
end

local previewCameraSource = [=[
-- Neo Tokyo Racers preview camera controller.
-- Phase B module. Not live until HOVER_RACING_V2_Client is explicitly adapted.

local PreviewCameraController = {}

PreviewCameraController.DefaultFocus = Vector3.new(860, 104, -1749)
PreviewCameraController.DefaultYaw = math.rad(180)
PreviewCameraController.DefaultPitch = math.rad(-12)
PreviewCameraController.DefaultDistance = 24.3
PreviewCameraController.SectionDistance = 33

PreviewCameraController.YawBySlot = {
	FrontBumper = math.rad(180),
	RearBumper = math.rad(0),
	RearSpoiler = math.rad(0),
	Boost = math.rad(0),
	Engine1 = math.rad(135),
	Engine2 = math.rad(45),
	SidePods = math.rad(90),
	Stabilisers = math.rad(90),
}

function PreviewCameraController.WrapAngle(angle)
	return math.atan2(math.sin(angle), math.cos(angle))
end

function PreviewCameraController.LerpAngle(a, b, t)
	return a + PreviewCameraController.WrapAngle(b - a) * t
end

function PreviewCameraController.EnsureState(state)
	state.CameraFocus = state.CameraFocus or PreviewCameraController.DefaultFocus
	state.TargetFocus = state.TargetFocus or state.CameraFocus
	state.CameraYaw = state.CameraYaw or PreviewCameraController.DefaultYaw
	state.TargetYaw = state.TargetYaw or state.CameraYaw
	state.CameraPitch = state.CameraPitch or PreviewCameraController.DefaultPitch
	state.TargetPitch = state.TargetPitch or state.CameraPitch
	state.CameraDistance = state.CameraDistance or PreviewCameraController.DefaultDistance
	state.TargetDistance = state.TargetDistance or state.CameraDistance
	return state
end

function PreviewCameraController.SetPreviewFocus(state, focus)
	PreviewCameraController.EnsureState(state)
	state.TargetFocus = focus or state.TargetFocus
end

function PreviewCameraController.SetCameraSection(state, slotId)
	PreviewCameraController.EnsureState(state)
	state.TargetYaw = PreviewCameraController.YawBySlot[slotId] or PreviewCameraController.DefaultYaw
	state.TargetPitch = PreviewCameraController.DefaultPitch
	state.TargetDistance = PreviewCameraController.SectionDistance
end

function PreviewCameraController.Reset(state, focus)
	PreviewCameraController.EnsureState(state)
	state.TargetFocus = focus or state.TargetFocus or PreviewCameraController.DefaultFocus
	state.TargetYaw = PreviewCameraController.DefaultYaw
	state.TargetPitch = PreviewCameraController.DefaultPitch
	state.TargetDistance = PreviewCameraController.DefaultDistance
end

function PreviewCameraController.Update(context, dt)
	local state = context.State
	if not state or context.IsDriving == true or state.GarageCameraActive == false then
		return false
	end
	if context.Gui and context.Gui.Enabled == false then
		return false
	end

	local workspaceRef = context.Workspace or workspace
	local camera = context.Camera or workspaceRef.CurrentCamera
	if not camera then
		return false
	end

	PreviewCameraController.EnsureState(state)
	camera.CameraType = Enum.CameraType.Scriptable

	local t = math.clamp((dt or 0) * (context.LerpSpeed or 7), 0, 1)
	state.CameraFocus = state.CameraFocus:Lerp(state.TargetFocus, t)
	state.CameraYaw = PreviewCameraController.LerpAngle(state.CameraYaw, state.TargetYaw, t)
	state.CameraPitch += (state.TargetPitch - state.CameraPitch) * t
	state.CameraDistance += (state.TargetDistance - state.CameraDistance) * t

	local offset = CFrame.Angles(0, state.CameraYaw, 0)
		* CFrame.Angles(state.CameraPitch, 0, 0)
		* Vector3.new(0, 0, state.CameraDistance)

	camera.CFrame = CFrame.lookAt(state.CameraFocus + offset, state.CameraFocus)
	return true
end

return PreviewCameraController
]=]

local previewVehicleSource = [=[
-- Neo Tokyo Racers preview vehicle controller.
-- Phase B module. Not live until HOVER_RACING_V2_Client is explicitly adapted.

local PreviewVehicleController = {}

local controllersFolder = script.Parent.Parent
local coreFolder = controllersFolder:WaitForChild("Core")
local PaintClient = require(coreFolder:WaitForChild("PaintClient"))

PreviewVehicleController.ClientRootName = "_NTR_ClientOnly"
PreviewVehicleController.PreviewFolderName = "VehiclePreview"
PreviewVehicleController.LegacyPreviewFolderName = "HOVER_RACING_V2_LOCAL_PREVIEW"

function PreviewVehicleController.FindTemplateByAttribute(root, attr, value)
	if not root or value == nil then
		return nil
	end
	for _, item in ipairs(root:GetDescendants()) do
		if item:GetAttribute(attr) == value then
			return item
		end
	end
	return nil
end

function PreviewVehicleController.GetPreviewRoot(workspaceRef, previewState)
	workspaceRef = workspaceRef or workspace
	previewState = previewState or {}
	if previewState.Root and previewState.Root.Parent then
		return previewState.Root
	end

	local clientRoot = workspaceRef:FindFirstChild(PreviewVehicleController.ClientRootName)
	if not clientRoot then
		clientRoot = Instance.new("Folder")
		clientRoot.Name = PreviewVehicleController.ClientRootName
		clientRoot.Parent = workspaceRef
	end

	local legacy = workspaceRef:FindFirstChild(PreviewVehicleController.LegacyPreviewFolderName)
	if legacy then
		legacy:Destroy()
	end

	local existing = clientRoot:FindFirstChild(PreviewVehicleController.PreviewFolderName)
	if existing then
		previewState.Root = existing
		return existing
	end

	local root = Instance.new("Folder")
	root.Name = PreviewVehicleController.PreviewFolderName
	root.Parent = clientRoot
	previewState.Root = root
	return root
end

function PreviewVehicleController.ClearRoot(root)
	if root then
		root:ClearAllChildren()
	end
end

function PreviewVehicleController.GetSlotMount(vehicle, slotId)
	local root = vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
	local slot = root and root:FindFirstChild("SLOT_" .. tostring(slotId))
	return slot and slot:FindFirstChild("Mount_DoNotRename")
end

function PreviewVehicleController.PivotModuleToSlot(moduleClone, mount)
	local root = moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename", true)
	if root then
		moduleClone.PrimaryPart = root
	end

	local moduleAttachment = moduleClone:FindFirstChild("MountAttachment", true)
	local mountAttachment = mount and mount:FindFirstChild("MountAttachment")
	if moduleAttachment and mountAttachment then
		moduleClone:PivotTo(mountAttachment.WorldCFrame * moduleAttachment.CFrame:Inverse())
	elseif mount then
		moduleClone:PivotTo(mount.CFrame)
	end
end

function PreviewVehicleController.ModuleColors(profile, slotId)
	profile = profile or {}
	local cockpitColors = profile.CockpitColors or {}
	local moduleSet = profile.ModuleColors and profile.ModuleColors[slotId] or {}
	return PaintClient.ModuleColors(profile, slotId, cockpitColors, moduleSet)
end

function PreviewVehicleController.ClearPreviewModules(state)
	state.PreviewModules = {}
	state.SelectedModuleId = nil
end

function PreviewVehicleController.Build(context)
	local state = context.State
	if not state then
		return nil, "State missing"
	end

	local categoriesRoot = context.CategoriesRoot
	if not categoriesRoot then
		return nil, "Categories root missing"
	end

	local preview = context.Preview or {}
	local root = PreviewVehicleController.GetPreviewRoot(context.Workspace, preview)
	PreviewVehicleController.ClearRoot(root)

	local cockpitId = state.SelectedCockpit or (state.Profile and state.Profile.CurrentCockpit) or "bruiser_01"
	local template = PreviewVehicleController.FindTemplateByAttribute(categoriesRoot, "CockpitId", cockpitId)
	if not template then
		return nil, "Cockpit template not found: " .. tostring(cockpitId)
	end

	local vehicle = template:Clone()
	vehicle.Name = "LOCAL_PREVIEW_" .. tostring(cockpitId)
	vehicle.Parent = root
	preview.Vehicle = vehicle

	local primary = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	if primary then
		vehicle.PrimaryPart = primary
	end

	local previewPosition = state.Catalog and state.Catalog.PreviewPosition or Vector3.new(860, 104, -1749)
	vehicle:PivotTo(CFrame.new(previewPosition))
	state.TargetFocus = previewPosition

	local cockpitColors = {}
	for key, value in pairs((state.Profile and state.Profile.CockpitColors) or {}) do
		cockpitColors[key] = value
	end
	cockpitColors.FrontLights = cockpitColors.FrontLights or Color3.fromRGB(252, 250, 255)
	cockpitColors.RearLights = cockpitColors.RearLights or Color3.fromRGB(255, 116, 116)
	PaintClient.ApplyColors(vehicle, cockpitColors, true, { Profile = state.Profile })

	local thrustColor = (state.Profile and state.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255)
	root:SetAttribute("ThrustColor", thrustColor)
	root:SetAttribute("ForceThrustPreview", state.ThrustPreviewActive == true)
	vehicle:SetAttribute("ThrustColor", thrustColor)

	local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder")
	installedRoot.Name = "INSTALLED_MODULES_Runtime"
	installedRoot.Parent = vehicle
	installedRoot:ClearAllChildren()

	local modulesToShow = {}
	for slotId, moduleId in pairs((state.Profile and state.Profile.InstalledModules) or {}) do
		modulesToShow[slotId] = moduleId
	end
	for slotId, moduleId in pairs(state.PreviewModules or {}) do
		modulesToShow[slotId] = moduleId
	end

	for slotId, moduleId in pairs(modulesToShow) do
		local moduleTemplate = PreviewVehicleController.FindTemplateByAttribute(categoriesRoot, "ModuleId", moduleId)
		local mount = PreviewVehicleController.GetSlotMount(vehicle, slotId)
		if moduleTemplate and mount then
			local clone = moduleTemplate:Clone()
			clone.Name = "PREVIEW_" .. tostring(slotId) .. "_" .. moduleTemplate.Name
			clone.Parent = installedRoot
			PreviewVehicleController.PivotModuleToSlot(clone, mount)

			local neonOwned = (state.Profile and state.Profile.NeonOwned) or {}
			local previewNeon = state.PreviewNeonSlot == slotId
			PaintClient.ApplyColors(
				clone,
				PreviewVehicleController.ModuleColors(state.Profile, slotId),
				neonOwned[slotId] == true or previewNeon,
				{ Profile = state.Profile }
			)
		end
	end

	return vehicle, nil
end

return PreviewVehicleController
]=]

local colourPickerSource = [=[
-- Neo Tokyo Racers shared colour picker controller.
-- Phase B module. Pure helpers are safe now; Render is staged for later client adoption.

local ColourPickerController = {}

ColourPickerController.DefaultChannels = { "Primary", "Secondary", "Detail" }

function ColourPickerController.ToHSV(color)
	local ok, h, s, v = pcall(function()
		return color:ToHSV()
	end)
	if ok then
		return h, s, v
	end
	return Color3.toHSV(color)
end

function ColourPickerController.SyncStateFromColor(state, color)
	local h, s, v = ColourPickerController.ToHSV(color)
	state.Hue = h
	state.Saturation = s
	state.Brightness = v
	return h, s, v
end

function ColourPickerController.ColorFromState(state)
	return Color3.fromHSV(state.Hue or 0, state.Saturation or 0, state.Brightness or 1)
end

function ColourPickerController.ChannelTitle(channel)
	if channel == "Neon" then return "Neon" end
	if channel == "ThrustColor" then return "Thrust" end
	if channel == "FrontLights" then return "Front Lights" end
	if channel == "RearLights" then return "Rear Lights" end
	return tostring(channel)
end

function ColourPickerController.ResolveBaseColors(state)
	state = state or {}
	if state.ColorChannel == "ThrustColor" then
		return {
			ThrustColor = (state.Profile and state.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255),
		}
	end

	if state.Stage == "Customise"
		and state.CustomizeTarget
		and state.CustomizeTarget ~= "ALL"
		and state.CustomizeTarget ~= "Cockpit"
		and state.CustomizeTarget ~= "THRUST_COLOR"
	then
		local moduleColorSet = state.Profile
			and state.Profile.ModuleColors
			and state.Profile.ModuleColors[state.CustomizeTarget]
		if moduleColorSet then
			return moduleColorSet
		end
	end

	return (state.Profile and state.Profile.CockpitColors) or {}
end

function ColourPickerController.ApplyHueGradient(gradient)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
		ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
		ColorSequenceKeypoint.new(0.34, Color3.fromHSV(0.34, 1, 1)),
		ColorSequenceKeypoint.new(0.51, Color3.fromHSV(0.51, 1, 1)),
		ColorSequenceKeypoint.new(0.68, Color3.fromHSV(0.68, 1, 1)),
		ColorSequenceKeypoint.new(0.85, Color3.fromHSV(0.85, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
	})
end

function ColourPickerController.ApplySaturationGradient(gradient, hue)
	gradient.Color = ColorSequence.new(Color3.fromHSV(hue or 0, 0, 1), Color3.fromHSV(hue or 0, 1, 1))
end

function ColourPickerController.ApplyBrightnessGradient(gradient, hue, saturation)
	gradient.Color = ColorSequence.new(
		Color3.fromRGB(0, 0, 0),
		Color3.fromHSV(hue or 0, math.max(saturation or 0, 0.06), 1)
	)
end

function ColourPickerController.RefreshGradients(state, hueGradient, saturationGradient, brightnessGradient)
	if hueGradient then
		ColourPickerController.ApplyHueGradient(hueGradient)
	end
	if saturationGradient then
		ColourPickerController.ApplySaturationGradient(saturationGradient, state.Hue)
	end
	if brightnessGradient then
		ColourPickerController.ApplyBrightnessGradient(brightnessGradient, state.Hue, state.Saturation)
	end
end

local function defaultShortName(name)
	if name == "Hue" then return "H" end
	if name == "Saturation" then return "S" end
	if name == "Brightness" then return "B" end
	return name
end

function ColourPickerController.MakeSlider(context, name, y, value, update)
	local helpers = context.Helpers
	local parent = context.Parent
	local theme = context.Theme
	local userInputService = context.UserInputService
	local connections = context.Connections

	local short = defaultShortName(name)
	helpers.Label(parent, short, UDim2.fromOffset(18, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)

	local track = helpers.New("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -72, 0, 15),
		Position = UDim2.fromOffset(24, y + 3),
		BorderSizePixel = 0,
	}, parent)
	helpers.Corner(track, 5)
	helpers.Stroke(track, theme.Accent, 0.35, 1)

	local gradient = helpers.New("UIGradient", {}, track)
	local knob = helpers.New("Frame", {
		BackgroundColor3 = theme.Accent,
		Size = UDim2.fromOffset(11, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		BorderSizePixel = 0,
	}, track)
	helpers.Corner(knob, 4)

	local valueLabel = helpers.Label(
		parent,
		short == "H" and tostring(math.floor(value * 360)) or (tostring(math.floor(value * 100)) .. "%"),
		UDim2.fromOffset(42, 20),
		UDim2.new(1, -42, 0, y),
		10,
		Enum.TextXAlignment.Left
	)

	local dragging = false
	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		valueLabel.Text = short == "H" and tostring(math.floor(rel * 360)) or (tostring(math.floor(rel * 100)) .. "%")
		update(rel)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local move = userInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)

	if connections then
		table.insert(connections, move)
	end

	return gradient
end

function ColourPickerController.Render(context)
	local state = context.State
	local parent = context.Parent
	local helpers = context.Helpers
	local channels = context.Channels or ColourPickerController.DefaultChannels
	local applyCallback = context.ApplyCallback

	helpers.Clear(parent)
	if not table.find(channels, state.ColorChannel) then
		state.ColorChannel = channels[1]
	end

	local baseColors = ColourPickerController.ResolveBaseColors(state)
	local current = baseColors[state.ColorChannel] or Color3.fromRGB(255, 255, 255)
	ColourPickerController.SyncStateFromColor(state, current)

	if context.ChannelFloat then
		helpers.Clear(context.ChannelFloat)
		context.ChannelFloat.Visible = true
		for _, channel in ipairs(channels) do
			local button = helpers.Button(
				context.ChannelFloat,
				ColourPickerController.ChannelTitle(channel),
				UDim2.fromOffset(126, 30),
				UDim2.fromScale(0, 0),
				state.ColorChannel == channel and context.Theme.CardHot or context.Theme.Card
			)
			button.MouseButton1Click:Connect(function()
				state.ColorChannel = channel
				ColourPickerController.Render(context)
			end)
		end
	end

	local swatchPanel = helpers.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(214, 78),
		Position = UDim2.fromOffset(6, 10),
	}, parent)

	for i, preset in ipairs((state.Catalog and state.Catalog.PaintPresets) or {}) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local swatch = helpers.New("TextButton", {
			Text = "",
			BackgroundColor3 = preset.Color,
			Size = UDim2.fromOffset(35, 26),
			Position = UDim2.fromOffset(col * 44, row * 34),
			BorderSizePixel = 0,
		}, swatchPanel)
		helpers.Corner(swatch, 4)
		helpers.Stroke(swatch, context.Theme.Accent, 0.2, 1)
		swatch.MouseButton1Click:Connect(function()
			ColourPickerController.SyncStateFromColor(state, preset.Color)
			applyCallback(state.ColorChannel, preset.Color)
			ColourPickerController.Render(context)
		end)
	end

	local sliderPanel = helpers.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -236, 1, -8),
		Position = UDim2.fromOffset(226, 5),
	}, parent)

	local sliderContext = table.clone(context)
	sliderContext.Parent = sliderPanel

	local hueGradient
	local saturationGradient
	local brightnessGradient

	local function refresh()
		ColourPickerController.RefreshGradients(state, hueGradient, saturationGradient, brightnessGradient)
	end

	hueGradient = ColourPickerController.MakeSlider(sliderContext, "H", 5, state.Hue, function(value)
		state.Hue = value
		refresh()
		applyCallback(state.ColorChannel, ColourPickerController.ColorFromState(state))
	end)

	saturationGradient = ColourPickerController.MakeSlider(sliderContext, "S", 34, state.Saturation, function(value)
		state.Saturation = value
		refresh()
		applyCallback(state.ColorChannel, ColourPickerController.ColorFromState(state))
	end)

	brightnessGradient = ColourPickerController.MakeSlider(sliderContext, "B", 63, state.Brightness, function(value)
		state.Brightness = value
		refresh()
		applyCallback(state.ColorChannel, ColourPickerController.ColorFromState(state))
	end)

	refresh()
end

return ColourPickerController
]=]

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local coreControllers = folder(controllers, "Core")
local previewControllers = folder(controllers, "Preview")
local uiControllers = folder(controllers, "UI")

local requiredPhaseA = {
	"ClientState",
	"GarageApiClient",
	"CatalogClient",
	"ClientThemeAdapter",
	"PaintClient",
}

local phaseAIssues = {}
for _, moduleName in ipairs(requiredPhaseA) do
	local module = coreControllers:FindFirstChild(moduleName)
	if not module or not module:IsA("ModuleScript") then
		table.insert(phaseAIssues, "Missing Phase A module: " .. moduleName)
	elseif module:GetAttribute("CreatedBy") ~= PHASE_A_SCRIPT_ID then
		table.insert(phaseAIssues, "Phase A module has unexpected CreatedBy: " .. module:GetFullName())
	end
end

if #phaseAIssues > 0 then
	error("Phase A modules are not ready. Run/test Phase A first. Issues: " .. table.concat(phaseAIssues, "; "))
end

local cameraModule = writeModule(previewControllers, "PreviewCameraController", previewCameraSource, "Future preview camera orbit and module-section focus controller.")
local vehicleModule = writeModule(previewControllers, "PreviewVehicleController", previewVehicleSource, "Future local garage preview vehicle builder/controller.")
local colourModule = writeModule(uiControllers, "ColourPickerController", colourPickerSource, "Future shared HSB/default colour picker controller.")

local checks = {}
local function check(name, fn)
	local ok, result = pcall(fn)
	table.insert(checks, {
		Name = name,
		Passed = ok and result ~= false,
		Detail = ok and tostring(result == nil and "ok" or result) or tostring(result),
	})
end

check("PreviewCameraController require + section state", function()
	local controller = require(cameraModule)
	local state = {}
	controller.SetCameraSection(state, "Engine1")
	if typeof(state.TargetYaw) ~= "number" then
		return false
	end
	if math.abs(state.TargetYaw - math.rad(135)) > 0.001 then
		return false
	end
	return "ok"
end)

check("PreviewVehicleController require + API shape", function()
	local controller = require(vehicleModule)
	if typeof(controller.Build) ~= "function" then
		return false
	end
	if typeof(controller.PivotModuleToSlot) ~= "function" then
		return false
	end
	if typeof(controller.ModuleColors) ~= "function" then
		return false
	end
	return "ok"
end)

check("ColourPickerController require + HSV shape", function()
	local controller = require(colourModule)
	local state = {}
	controller.SyncStateFromColor(state, Color3.fromRGB(255, 0, 0))
	local color = controller.ColorFromState(state)
	if typeof(color) ~= "Color3" then
		return false
	end
	if controller.ChannelTitle("ThrustColor") ~= "Thrust" then
		return false
	end
	return "ok"
end)

local passed = 0
for _, item in ipairs(checks) do
	if item.Passed then
		passed += 1
	end
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Main Client Phase B Report")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Preview and colour modules were staged. Live `HOVER_RACING_V2_Client` was not edited.")
line("")
line("## Summary")
line("")
line("- Live client edited: false")
line("- Live behaviour changed: false")
line("- Phase A modules present: true")
line("- Modules written: 3")
line("- Passed checks: " .. tostring(passed) .. " / " .. tostring(#checks))
line("")
line("## Modules")
line("")
line("- " .. cameraModule:GetFullName())
line("- " .. vehicleModule:GetFullName())
line("- " .. colourModule:GetFullName())
line("")
line("## Checks")
line("")
for _, item in ipairs(checks) do
	line("- " .. item.Name .. ": " .. (item.Passed and "passed" or "failed") .. " (" .. item.Detail .. ")")
end
line("")
line("## Safety")
line("")
line("- The staged modules are not active owners yet.")
line("- The main client still owns live preview building, colour picker rendering, and garage camera update.")
line("- Phase C should only begin after a normal Play test confirms the current garage/customisation flow still works.")

local reportValue = reportsFolder:FindFirstChild("MainClientPhaseB_PreviewColourReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "MainClientPhaseB_PreviewColourReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "MainClientPhaseB_PreviewColourReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("LiveClientEdited", false)
reportValue:SetAttribute("LiveBehaviourChanged", false)
reportValue:SetAttribute("PassedChecks", passed)
reportValue:SetAttribute("TotalChecks", #checks)

log("Phase B modules staged.")
log("Checks passed: " .. tostring(passed) .. " / " .. tostring(#checks))
log("Report saved to " .. reportValue:GetFullName())
print(reportValue.Value)
