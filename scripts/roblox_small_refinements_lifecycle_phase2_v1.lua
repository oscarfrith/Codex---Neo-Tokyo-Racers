-- Neo Tokyo Racers - Small Refinements: Lifecycle Phase 2 V1.3
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_1
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_2
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_3
-- Run once in the Roblox Studio Edit-mode Command Bar, then restart Play.
-- One guarded, transactional installer for garage entry, garage touch camera,
-- first-drive Controls sequencing, and presentation-audio release.

local MODE = "INSTALL" -- INSTALL or AUDIT
local V1_REVISION = "NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1"
local V1_1_REVISION = "NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_1"
local V1_2_REVISION = "NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_2"
local REVISION = "NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_3"
local PREFIX = "[NTR Small Refinements Lifecycle Phase 2 V1.3]"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object, parent:GetFullName() .. "." .. name .. " missing")
	if className then
		assert(object:IsA(className), object:GetFullName() .. " must be " .. className)
	end
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function countPlain(source, needle)
	local count, start = 0, 1
	while true do
		local first, last = string.find(source, needle, start, true)
		if not first then return count end
		count += 1
		start = last + 1
	end
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = need(kit, "Shared", "Folder")
local modules = need(shared, "Modules", "Folder")
local clientModules = need(need(modules, "Client", "Folder"), "Audio", "Folder")
local vehicleAudio = need(clientModules, "VehicleAudioController", "ModuleScript")
local contextAudio = need(clientModules, "ContextAudioController", "ModuleScript")

local clientRoot = need(
	need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"),
	"NeoTokyoRacersClient",
	"Folder"
)
local controllers = need(clientRoot, "Controllers", "Folder")
local uiControllers = need(controllers, "UI", "Folder")
local previewControllers = need(controllers, "Preview", "Folder")
local desktopHud = need(uiControllers, "DesktopFreeRoamHudController_Active", "LocalScript")
local onboarding = need(uiControllers, "OnboardingClient_Active", "LocalScript")
local previewCamera = need(previewControllers, "PreviewCameraController", "ModuleScript")

local services = need(need(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder")
local garageServices = need(services, "Garage", "Folder")
local management = need(garageServices, "OwnedGarageManagementRuntime", "ModuleScript")
local settings = need(need(need(kit, "Config", "Folder"), "Runtime", "Folder"), "OwnedGarage_EditAttributes", "Folder")

local targets = {
	OwnedGarageManagementRuntime = management,
	PreviewCameraController = previewCamera,
	DesktopFreeRoamHudController = desktopHud,
	OnboardingClient = onboarding,
	VehicleAudioController = vehicleAudio,
	ContextAudioController = contextAudio,
}

for label, object in pairs(targets) do
	assert(object:IsA("LuaSourceContainer"), label .. " must be a LuaSourceContainer")
end

local function v1InstalledEverywhere()
	for _, object in pairs(targets) do
		if countPlain(object.Source, "-- " .. V1_REVISION .. "\n") ~= 1 then return false end
	end
	return true
end

local function v1_1Installed()
	return v1InstalledEverywhere() and countPlain(onboarding.Source, "-- " .. V1_1_REVISION .. "\n") == 1
end

local function v1_2Installed()
	return v1_1Installed() and countPlain(onboarding.Source, "-- " .. V1_2_REVISION .. "\n") == 1
end

local function installedCurrent()
	return v1_2Installed() and countPlain(onboarding.Source, "-- " .. REVISION .. "\n") == 1
end

local function audit()
	for label, object in pairs(targets) do
		assert(countPlain(object.Source, "-- " .. V1_REVISION .. "\n") == 1, label .. " V1 marker missing or duplicated")
		compile(label, object.Source)
	end
	assert(countPlain(onboarding.Source, "-- " .. V1_1_REVISION .. "\n") == 1, "Onboarding V1.1 marker missing or duplicated")
	assert(countPlain(onboarding.Source, "-- " .. V1_2_REVISION .. "\n") == 1, "Onboarding V1.2 marker missing or duplicated")
	assert(countPlain(onboarding.Source, "-- " .. REVISION .. "\n") == 1, "Onboarding V1.3 marker missing or duplicated")
	assert(settings:GetAttribute("DriveInSpeedGateEnabled") == false, "DriveInSpeedGateEnabled must be false")
	assert(string.find(management.Source, 'settings:GetAttribute("DriveInSpeedGateEnabled")==true', 1, true), "garage speed-gate opt-in missing")
	assert(string.find(previewCamera.Source, "ownedGarageWalking", 1, true), "garage walking touch guard missing")
	assert(string.find(desktopHud.Source, 'player:SetAttribute("NTR_DrivingControlsOpen"', 1, true), "Controls visibility publication missing")
	assert(string.find(desktopHud.Source, 'player:SetAttribute("NTR_FirstDrivePresentationPending",false)', 1, true), "first-drive release missing")
	assert(string.find(onboarding.Source, 'player:SetAttribute("NTR_FirstDrivePresentationPending",true)', 1, true), "first-drive gate acquisition missing")
	assert(string.find(onboarding.Source, "onboardingPresentationBlocked", 1, true), "unified onboarding presentation blocker missing")
	assert(string.find(onboarding.Source, "firstDriveSpawnPending", 1, true), "pre-loading first-drive handoff missing")
	assert(string.find(onboarding.Source, "objectiveComplete(1) and state.SeenPages.GarageShortcut==true", 1, true), "Objective 2 garage-shortcut unlock missing")
	assert(string.find(onboarding.Source, "return state.SeenPages.RaceShortcut==true and not objectiveComplete(3)", 1, true), "Objective 3 race-shortcut unlock missing")
	assert(string.find(onboarding.Source, "state.SeenPages.GarageShortcut==true and named(\"Race\")", 1, true), "Race shortcut garage-prompt acknowledgement gate missing")
	assert(string.find(vehicleAudio.Source, 'localPlayer:GetAttribute("NTR_FirstDrivePresentationPending")==true', 1, true), "vehicle-audio gate missing")
	assert(string.find(contextAudio.Source, 'player:GetAttribute("NTR_FirstDrivePresentationPending") == true', 1, true), "context-audio gate missing")
	print(PREFIX .. " AUDIT PASS | Race prompt follows Garage prompt Next | Race prompt Next immediately unlocks Objective 3")
end

if MODE == "AUDIT" then
	assert(installedCurrent(), "Phase 2 V1.3 is not fully installed")
	audit()
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

if installedCurrent() then
	audit()
	print(PREFIX .. " already installed; no changes made.")
	return
end
local v1Installed = v1InstalledEverywhere()
local v1_1InstalledAlready = v1_1Installed()
local v1_2InstalledAlready = v1_2Installed()
if not v1Installed then
	for label, object in pairs(targets) do
		assert(countPlain(object.Source, "-- " .. V1_REVISION .. "\n") == 0, "Partial V1 installation detected at " .. label .. "; refresh the live mirror before retrying")
	end
end
if not v1_1InstalledAlready then
	assert(countPlain(onboarding.Source, "-- " .. V1_1_REVISION .. "\n") == 0, "Partial V1.1 installation detected; refresh the live mirror before retrying")
end
if not v1_2InstalledAlready then
	assert(countPlain(onboarding.Source, "-- " .. V1_2_REVISION .. "\n") == 0, "Partial V1.2 installation detected; refresh the live mirror before retrying")
end
assert(countPlain(onboarding.Source, "-- " .. REVISION .. "\n") == 0, "Partial V1.3 installation detected; refresh the live mirror before retrying")

assert(string.find(management.Source, "NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1", 1, true), "Unknown owned-garage management baseline")
assert(string.find(previewCamera.Source, "NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V4_SESSION_SCOPED", 1, true), "Unknown preview-camera baseline")
assert(string.find(desktopHud.Source, "NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1", 1, true), "Confirmed Phase 1 desktop HUD baseline missing")
assert(string.find(onboarding.Source, "NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES", 1, true), "Confirmed onboarding V1.13 baseline missing")
assert(string.find(vehicleAudio.Source, "NTR_AUDIO_VEHICLE_CLIENT_V5_CONFIRMED_LOCAL_IGNITION", 1, true), "Confirmed vehicle-audio baseline missing")
assert(string.find(contextAudio.Source, "NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CONTROLLER_V1", 1, true), "Confirmed context-audio baseline missing")

local projected = {}

if v1Installed then
	for label, object in pairs(targets) do projected[label] = object.Source end
else
projected.OwnedGarageManagementRuntime = replaceOnce(
	management.Source,
	"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1",
	"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1\n-- " .. V1_REVISION,
	"owned-garage management marker"
)
projected.OwnedGarageManagementRuntime = replaceOnce(
	projected.OwnedGarageManagementRuntime,
	'if tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end',
	'if settings:GetAttribute("DriveInSpeedGateEnabled")==true and tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end',
	"owned-garage drive-in speed gate"
)

projected.PreviewCameraController = replaceOnce(
	previewCamera.Source,
	"-- NTR_GARAGE_CAMERA_VFX_REFINEMENT_V1_1",
	"-- NTR_GARAGE_CAMERA_VFX_REFINEMENT_V1_1\n-- " .. V1_REVISION,
	"preview-camera marker"
)
projected.PreviewCameraController = replaceOnce(
	projected.PreviewCameraController,
	'local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")',
	'local localPlayer=Players.LocalPlayer\nlocal playerGui=localPlayer:WaitForChild("PlayerGui")',
	"preview-camera local player"
)
projected.PreviewCameraController = replaceOnce(
	projected.PreviewCameraController,
	[=[function PreviewCameraController.BindInput(context)
	PreviewCameraController.UnbindInput(); local state=context.State; local dragging=false; local dragInput,lastPointer; local pinchScale
	local function active() return state and state.GarageCameraActive~=false and (not context.IsActive or context.IsActive()) end]=],
	[=[function PreviewCameraController.BindInput(context)
	PreviewCameraController.UnbindInput(); local state=context.State; local dragging=false; local dragInput,lastPointer; local pinchScale
	local function ownedGarageWalking()
		return UserInputService.TouchEnabled
			and localPlayer:GetAttribute("NTR_OwnedGarageInside")==true
			and playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")~=true
	end
	local function active() return not ownedGarageWalking() and state and state.GarageCameraActive~=false and (not context.IsActive or context.IsActive()) end]=],
	"owned-garage walking camera guard"
)
projected.PreviewCameraController = replaceOnce(
	projected.PreviewCameraController,
	'if not active() then return end; if input.UserInputType==Enum.UserInputType.MouseWheel',
	'if not active() then dragging=false; dragInput=nil; lastPointer=nil; pinchScale=nil; return end; if input.UserInputType==Enum.UserInputType.MouseWheel',
	"preview-camera inactive drag release"
)

projected.DesktopFreeRoamHudController = replaceOnce(
	desktopHud.Source,
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1",
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1\n-- " .. V1_REVISION,
	"desktop HUD marker"
)
projected.DesktopFreeRoamHudController = replaceOnce(
	projected.DesktopFreeRoamHudController,
	'local RunService = game:GetService("RunService")',
	'local RunService = game:GetService("RunService")\nlocal TweenService = game:GetService("TweenService")',
	"desktop HUD TweenService"
)
projected.DesktopFreeRoamHudController = replaceOnce(
	projected.DesktopFreeRoamHudController,
	'local mobileDriveInputState = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("MobileDriveInputState"))',
	'local mobileDriveInputState = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("MobileDriveInputState"))\nlocal GameplayInputGate = require(kit.Shared.Modules.Client:WaitForChild("Input"):WaitForChild("GameplayInputGate"))',
	"desktop Controls gameplay input gate"
)
projected.DesktopFreeRoamHudController = replaceOnce(
	projected.DesktopFreeRoamHudController,
	[=[local activeModal
local selectedCategory]=],
	[=[local activeModal
local controlsDoneButton
local onboardingControlsReveal = false
local controlsFadeGeneration = 0
local controlsInputToken
local selectedCategory]=],
	"desktop Controls presentation state"
)
projected.DesktopFreeRoamHudController = replaceOnce(
	projected.DesktopFreeRoamHudController,
	[=[local function closeModal()
	activeModal = nil
	modalLayer.Visible = false
	for _, item in pairs(modalPanels) do item.Visible = false end
end

local function openModal(name)
	closeChoiceList()
	activeModal = name
	modalLayer.Visible = true
	for key, item in pairs(modalPanels) do item.Visible = key == name end
end]=],
	[=[local function finishModalClose()
	local closingControls = activeModal == "Controls"
	activeModal = nil
	modalLayer.Visible = false
	for _, item in pairs(modalPanels) do item.Visible = false end
	if closingControls then player:SetAttribute("NTR_DrivingControlsOpen",false) end
	if controlsInputToken then GameplayInputGate.Release(controlsInputToken,true); controlsInputToken=nil end
	onboardingControlsReveal = false
	if controlsDoneButton then controlsDoneButton.Text="DONE"; controlsDoneButton.Active=true end
	if modalBackdrop then modalBackdrop.BackgroundTransparency=L("ModalDimTransparency",0.32) end
end

local function closeModal()
	if activeModal=="Controls" and onboardingControlsReveal then return end
	controlsFadeGeneration += 1
	finishModalClose()
end

local function completeControls()
	if activeModal~="Controls" then return end
	if not onboardingControlsReveal then closeModal(); return end
	controlsFadeGeneration += 1
	local generation=controlsFadeGeneration
	local controls=modalPanels.Controls
	if controls then controls.Visible=false end
	if controlsDoneButton then controlsDoneButton.Active=false end
	local tween=TweenService:Create(modalBackdrop,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=1})
	tween:Play()
	tween.Completed:Once(function()
		if generation~=controlsFadeGeneration then return end
		player:SetAttribute("NTR_FirstDrivePresentationPending",false)
		finishModalClose()
	end)
end

local function openModal(name)
	closeChoiceList()
	controlsFadeGeneration += 1
	activeModal = name
	modalLayer.Visible = true
	for key, item in pairs(modalPanels) do item.Visible = key == name end
	player:SetAttribute("NTR_DrivingControlsOpen",name=="Controls")
	modalBackdrop.BackgroundTransparency=(name=="Controls" and onboardingControlsReveal) and 0 or L("ModalDimTransparency",0.32)
	if controlsDoneButton then controlsDoneButton.Text=(name=="Controls" and onboardingControlsReveal) and "NEXT" or "DONE"; controlsDoneButton.Active=true end
end]=],
	"desktop Controls lifecycle"
)
projected.DesktopFreeRoamHudController = replaceOnce(
	projected.DesktopFreeRoamHudController,
	[=[	local doneControls = button(controls, "Done", "DONE", UDim2.fromOffset(240, 48), UDim2.fromOffset(330, 480), C("PanelBlue"), C("Telemetry"))
	doneControls.Activated:Connect(closeModal)]=],
	[=[	controlsDoneButton = button(controls, "Done", "DONE", UDim2.fromOffset(240, 48), UDim2.fromOffset(330, 480), C("PanelBlue"), C("Telemetry"))
	controlsDoneButton.Activated:Connect(completeControls)]=],
	"Controls Next action"
)
projected.DesktopFreeRoamHudController = replaceOnce(
	projected.DesktopFreeRoamHudController,
	[=[	local onboardingControls=script.Parent:WaitForChild("OpenDrivingControlsFromOnboarding")
	onboardingControls.Event:Connect(function() openModal("Controls") end) -- NTR_DESKTOP_ONBOARDING_CONTROLS_POPUP_V1]=],
	[=[	local onboardingControls=script.Parent:WaitForChild("OpenDrivingControlsFromOnboarding")
	onboardingControls.Event:Connect(function(options)
		onboardingControlsReveal=type(options)=="table" and options.FirstDrive==true
		if onboardingControlsReveal then
			player:SetAttribute("NTR_FirstDrivePresentationPending",true)
			if not controlsInputToken then controlsInputToken=GameplayInputGate.Acquire("FirstDriveControls","V1") end
		end
		openModal("Controls")
	end) -- NTR_DESKTOP_ONBOARDING_CONTROLS_POPUP_V1]=],
	"onboarding Controls request"
)

projected.OnboardingClient = replaceOnce(
	onboarding.Source,
	"-- NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES",
	"-- NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES\n-- " .. V1_REVISION,
	"onboarding marker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[local function controlsOpen()
	local screen=playerGui:FindFirstChild("NTR_DesktopFreeRoamHud")]=],
	[=[local function controlsOpen()
	if player:GetAttribute("NTR_DrivingControlsOpen")==true then return true end
	local screen=playerGui:FindFirstChild("NTR_DesktopFreeRoamHud")]=],
	"explicit Controls open state"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[		if event and event:IsA("BindableEvent") then
			pcControlsAwaitClose=true; state.SeenPages.PCDriving=true; event:Fire(); task.spawn(markSeen,"PCDriving"); return
		end]=],
	[=[		if event and event:IsA("BindableEvent") then
			player:SetAttribute("NTR_FirstDrivePresentationPending",true)
			pcControlsAwaitClose=true; state.SeenPages.PCDriving=true; event:Fire({FirstDrive=true}); task.spawn(markSeen,"PCDriving"); return
		end
		player:SetAttribute("NTR_FirstDrivePresentationPending",false)]=],
	"first-drive Controls gate acquisition"
)

projected.VehicleAudioController = replaceOnce(
	vehicleAudio.Source,
	"-- NTR_AUDIO_VEHICLE_CLIENT_V5_CONFIRMED_LOCAL_IGNITION",
	"-- NTR_AUDIO_VEHICLE_CLIENT_V5_CONFIRMED_LOCAL_IGNITION\n-- " .. V1_REVISION,
	"vehicle-audio marker"
)
projected.VehicleAudioController = replaceOnce(
	projected.VehicleAudioController,
	'return state ~= nil and state:GetAttribute("Active") == true',
	'return (state ~= nil and state:GetAttribute("Active") == true)\n\t\tor localPlayer:GetAttribute("NTR_FirstDrivePresentationPending")==true',
	"vehicle-audio presentation hold"
)
projected.VehicleAudioController = replaceOnce(
	projected.VehicleAudioController,
	[=[	if holdLocalEngineLoopsForIgnition(state) then
		idleTarget, engineLowTarget, engineHighTarget, coastTarget = 0, 0, 0, 0
	end]=],
	[=[	if holdLocalEngineLoopsForIgnition(state) or (state.LocalDriver and localPlayer:GetAttribute("NTR_FirstDrivePresentationPending")==true) then
		idleTarget, engineLowTarget, engineHighTarget, coastTarget = 0, 0, 0, 0
	end]=],
	"local engine-loop presentation hold"
)
projected.VehicleAudioController = replaceOnce(
	projected.VehicleAudioController,
	[=[	setTarget(graph, "Acceleration", exitedPresentation and 0 or (accelerating and gains.Acceleration * mix or 0))
	setTarget(graph, "Coast", coastTarget)
	setTarget(graph, "DriftLoop", exitedPresentation and 0 or (drifting and gains.DriftLoop * driftGainMultiplier * mix or 0))
	setTarget(graph, "BoostLoop", exitedPresentation and 0 or (boosting and gains.BoostLoop * mix or 0))
	setTarget(graph, "DriverWind", state.LocalDriver and gains.DriverWind * rangeAlpha(speedMph, Catalog.GlobalNumber("WindStartMph", 18), Catalog.GlobalNumber("WindFullGainMph", 128)) * mix or 0)]=],
	[=[	local firstDriveHeld=state.LocalDriver and localPlayer:GetAttribute("NTR_FirstDrivePresentationPending")==true
	setTarget(graph, "Acceleration", firstDriveHeld and 0 or (exitedPresentation and 0 or (accelerating and gains.Acceleration * mix or 0)))
	setTarget(graph, "Coast", coastTarget)
	setTarget(graph, "DriftLoop", firstDriveHeld and 0 or (exitedPresentation and 0 or (drifting and gains.DriftLoop * driftGainMultiplier * mix or 0)))
	setTarget(graph, "BoostLoop", firstDriveHeld and 0 or (exitedPresentation and 0 or (boosting and gains.BoostLoop * mix or 0)))
	setTarget(graph, "DriverWind", firstDriveHeld and 0 or (state.LocalDriver and gains.DriverWind * rangeAlpha(speedMph, Catalog.GlobalNumber("WindStartMph", 18), Catalog.GlobalNumber("WindFullGainMph", 128)) * mix or 0))]=],
	"remaining local vehicle-loop presentation holds"
)

projected.ContextAudioController = replaceOnce(
	contextAudio.Source,
	"-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CONTROLLER_V1",
	"-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CONTROLLER_V1\n-- " .. V1_REVISION,
	"context-audio marker"
)
projected.ContextAudioController = replaceOnce(
	projected.ContextAudioController,
	[=[local function refresh()
	if not enabled() then]=],
	[=[local function refresh()
	if player:GetAttribute("NTR_FirstDrivePresentationPending") == true then
		if currentContextId ~= nil then stopAll(0.08) end
		return
	end
	if not enabled() then]=],
	"context-audio presentation hold"
)
projected.ContextAudioController = replaceOnce(
	projected.ContextAudioController,
	'{ "NTR_OwnedGarageInside", "NTR_GarageSessionActive", "NTR_GarageSessionMode" }',
	'{ "NTR_OwnedGarageInside", "NTR_GarageSessionActive", "NTR_GarageSessionMode", "NTR_FirstDrivePresentationPending" }',
	"context-audio gate listener"
)
end

if not v1_1InstalledAlready then
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"-- " .. V1_REVISION,
	"-- " .. V1_REVISION .. "\n-- " .. V1_1_REVISION,
	"Phase 2 V1.1 onboarding marker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[local function loadingActive()
	return player:GetAttribute("NTR_StartScreenActive")==true or loadingState:GetAttribute("Active")==true
end]=],
	[=[local function loadingActive()
	return player:GetAttribute("NTR_StartScreenActive")==true or loadingState:GetAttribute("Active")==true
end
local function onboardingPresentationBlocked()
	return loadingActive()
		or player:GetAttribute("NTR_FirstDrivePresentationPending")==true
		or player:GetAttribute("NTR_DrivingControlsOpen")==true
end]=],
	"unified onboarding presentation blocker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"if loadingActive() or not (activePage and activeObjects) then hideOverlay(); return end",
	"if onboardingPresentationBlocked() or not (activePage and activeObjects) then hideOverlay(); return end",
	"pinned tutorial blocker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"if generation~=layoutGeneration or loadingActive() or not (activePage and activeObjects) then return end",
	"if generation~=layoutGeneration or onboardingPresentationBlocked() or not (activePage and activeObjects) then return end",
	"tutorial layout blocker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"local scheduleResolve\nlocal advance",
	"local scheduleResolve\nlocal advance\nlocal syncObjectives",
	"objective reconciliation forward declaration"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"if generation~=resolveGeneration or loadingActive() or not activePage then return end",
	"if generation~=resolveGeneration or onboardingPresentationBlocked() or not activePage then return end",
	"tutorial target-resolution blocker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[		local done=activePage; state.SeenPages[done]=true; activePage=nil; activeIndex=nil; activeRoot=nil; activeObjects=nil; resolveGeneration+=1; disconnectTargets(); hideOverlay(); print("[NTR Tutorial] complete "..done); task.spawn(markSeen,done)]=],
	[=[		local done=activePage; state.SeenPages[done]=true; activePage=nil; activeIndex=nil; activeRoot=nil; activeObjects=nil; resolveGeneration+=1; disconnectTargets(); hideOverlay(); print("[NTR Tutorial] complete "..done); task.defer(function() if syncObjectives then syncObjectives() end end); task.spawn(markSeen,done)]=],
	"immediate shortcut objective reconciliation"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[ RaceShortcut=function() local object=state.SeenPages.GarageShortcut==true and named("Race"); return object and scopeRoot(object) end,]=],
	[=[ RaceShortcut=function() local object=state.Completed.GarageManagementEntered==true and named("Race"); return object and scopeRoot(object) end,]=],
	"Race shortcut waits for Objective 2 completion"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[local function objectiveDesired(index)
	if index==1 then return not objectiveComplete(1) end
	return objectiveComplete(1) and not objectiveComplete(index)
end]=],
	[=[local function objectiveDesired(index)
	if index==1 then return not objectiveComplete(1) end
	if index==2 then return objectiveComplete(1) and state.SeenPages.GarageShortcut==true and not objectiveComplete(2) end
	return objectiveComplete(2) and state.SeenPages.RaceShortcut==true and not objectiveComplete(3)
end]=],
	"ordered objective unlock contract"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"local function syncObjectives()",
	"syncObjectives=function()",
	"forward-declared objective reconciliation"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"objectiveLayer.Visible=stateReady and #objectiveOrder()>0 and not loadingActive() and not majorMenuOpen() and (not activePage or shortcutPrompt)",
	"objectiveLayer.Visible=stateReady and #objectiveOrder()>0 and not onboardingPresentationBlocked() and not majorMenuOpen() and (not activePage or shortcutPrompt)",
	"objective-layer presentation blocker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"if loadingActive() then guideTrail:Clear(); return end",
	"if onboardingPresentationBlocked() then guideTrail:Clear(); return end",
	"guide-trail presentation blocker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[local pcControlsAwaitClose=false
local function pollPages()
	if loadingActive() or activePage then return end
	if pcControlsAwaitClose then
		if controlsOpen() then return end
		pcControlsAwaitClose=false
	end
	local drivenVehicle=activelyDriving()
	local raceDriving=drivenVehicle and (drivenVehicle:GetAttribute("NTR_RaceParticipant")==true or drivenVehicle:GetAttribute("NTR_RaceRunId")~=nil)
	if not UserInputService.TouchEnabled and state.Stage>=2 and state.SeenPages.PCDriving~=true and drivenVehicle and not raceDriving then -- NTR_ONBOARDING_FREE_ROAM_CONTROLS_ONLY_V1
		local event=script.Parent:FindFirstChild("OpenDrivingControlsFromOnboarding")
		if event and event:IsA("BindableEvent") then
			player:SetAttribute("NTR_FirstDrivePresentationPending",true)
			pcControlsAwaitClose=true; state.SeenPages.PCDriving=true; event:Fire({FirstDrive=true}); task.spawn(markSeen,"PCDriving"); return
		end
		player:SetAttribute("NTR_FirstDrivePresentationPending",false)
	end
	for _,pageId in ipairs(pageOrder) do local signal=pageSignals[pageId]
		if state.SeenPages[pageId]~=true then local ok,result=pcall(signal); if ok and result then beginPage(pageId,result); return end end
	end
end]=],
	[=[local pcControlsAwaitClose=false
local firstDriveSpawnPending=false
local firstDriveSpawnDirect=false
local firstDriveRequestInFlight=false
local function tryBeginFirstDriveControls(allowSpawnSignal)
	if UserInputService.TouchEnabled or not stateReady or state.Stage<2 or state.SeenPages.PCDriving==true or firstDriveRequestInFlight then return false end
	local drivenVehicle=activelyDriving()
	local raceDriving=drivenVehicle and (drivenVehicle:GetAttribute("NTR_RaceParticipant")==true or drivenVehicle:GetAttribute("NTR_RaceRunId")~=nil)
	if raceDriving or (not drivenVehicle and not allowSpawnSignal) then return false end
	local event=script.Parent:FindFirstChild("OpenDrivingControlsFromOnboarding")
	if not (event and event:IsA("BindableEvent")) then
		firstDriveSpawnPending=false
		player:SetAttribute("NTR_FirstDrivePresentationPending",false)
		return false
	end
	player:SetAttribute("NTR_FirstDrivePresentationPending",true)
	firstDriveRequestInFlight=true
	pcControlsAwaitClose=true
	state.SeenPages.PCDriving=true
	event:Fire({FirstDrive=true})
	task.spawn(markSeen,"PCDriving")
	return true
end
local function pollPages()
	if firstDriveSpawnPending and tryBeginFirstDriveControls(firstDriveSpawnDirect) then firstDriveSpawnPending=false; firstDriveSpawnDirect=false; return end
	if onboardingPresentationBlocked() then return end
	if pcControlsAwaitClose then
		pcControlsAwaitClose=false
		firstDriveRequestInFlight=false
	end
	if activePage then return end
	if tryBeginFirstDriveControls() then return end
	for _,pageId in ipairs(pageOrder) do local signal=pageSignals[pageId]
		if state.SeenPages[pageId]~=true then local ok,result=pcall(signal); if ok and result then beginPage(pageId,result); return end end
	end
end
local freeRoamVehicleSpawned=script.Parent:WaitForChild("FreeRoamVehicleSpawned")
freeRoamVehicleSpawned.Event:Connect(function()
	if UserInputService.TouchEnabled or state.SeenPages.PCDriving==true then return end
	firstDriveSpawnPending=true
	firstDriveSpawnDirect=loadingActive() and tostring(loadingState:GetAttribute("Destination") or "")=="FreeRoamDrive"
	if tryBeginFirstDriveControls(firstDriveSpawnDirect) then firstDriveSpawnPending=false; firstDriveSpawnDirect=false end
end)]=],
	"pre-loading first-drive Controls handoff"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[local function accept(newState)
	if type(newState)=="table" and newState.Success then state=newState; stateReady=true end
	applyLocks(); syncObjectives(); refreshObjective()
end]=],
	[=[local function accept(newState)
	if type(newState)=="table" and newState.Success then state=newState; stateReady=true end
	if firstDriveSpawnPending and tryBeginFirstDriveControls(firstDriveSpawnDirect) then firstDriveSpawnPending=false; firstDriveSpawnDirect=false end
	applyLocks(); syncObjectives(); refreshObjective()
end]=],
	"state-ready first-drive handoff"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[		if generation~=gateGeneration or loadingActive() then return end
		gui.Enabled=true
		if activePage then scheduleResolve() else refreshObjective(); pollPages() end]=],
	[=[		if generation~=gateGeneration or loadingActive() then return end
		gui.Enabled=true
		if onboardingPresentationBlocked() then hideOverlay(); objectiveLayer.Visible=false; return end
		if activePage then scheduleResolve() else refreshObjective(); pollPages() end]=],
	"loading-release onboarding handoff"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[player:GetAttributeChangedSignal("NTR_StartScreenActive"):Connect(refreshLoadingGate)
loadingState:GetAttributeChangedSignal("Active"):Connect(refreshLoadingGate)]=],
	[=[player:GetAttributeChangedSignal("NTR_StartScreenActive"):Connect(refreshLoadingGate)
player:GetAttributeChangedSignal("NTR_FirstDrivePresentationPending"):Connect(refreshLoadingGate)
player:GetAttributeChangedSignal("NTR_DrivingControlsOpen"):Connect(refreshLoadingGate)
loadingState:GetAttributeChangedSignal("Active"):Connect(refreshLoadingGate)]=],
	"explicit first-drive completion resume"
)
end

if not v1_2InstalledAlready then
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"-- " .. V1_1_REVISION,
	"-- " .. V1_1_REVISION .. "\n-- " .. V1_2_REVISION,
	"Phase 2 V1.2 onboarding marker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	[=[ RaceShortcut=function() local object=state.Completed.GarageManagementEntered==true and named("Race"); return object and scopeRoot(object) end,]=],
	[=[ RaceShortcut=function() local object=state.SeenPages.GarageShortcut==true and named("Race"); return object and scopeRoot(object) end,]=],
	"Race shortcut follows Garage prompt acknowledgement"
)
end

projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"-- " .. V1_2_REVISION,
	"-- " .. V1_2_REVISION .. "\n-- " .. REVISION,
	"Phase 2 V1.3 onboarding marker"
)
projected.OnboardingClient = replaceOnce(
	projected.OnboardingClient,
	"return objectiveComplete(2) and state.SeenPages.RaceShortcut==true and not objectiveComplete(3)",
	"return state.SeenPages.RaceShortcut==true and not objectiveComplete(3)",
	"Objective 3 follows Race prompt acknowledgement"
)

for label, source in pairs(projected) do
	assert(countPlain(source, "-- " .. V1_REVISION .. "\n") == 1, label .. " projected V1 marker missing or duplicated")
	compile(label, source)
end
assert(countPlain(projected.OnboardingClient, "-- " .. V1_1_REVISION .. "\n") == 1, "Projected onboarding V1.1 marker missing or duplicated")
assert(countPlain(projected.OnboardingClient, "-- " .. V1_2_REVISION .. "\n") == 1, "Projected onboarding V1.2 marker missing or duplicated")
assert(countPlain(projected.OnboardingClient, "-- " .. REVISION .. "\n") == 1, "Projected onboarding V1.3 marker missing or duplicated")

local originals = {}
for label, object in pairs(targets) do originals[label] = object.Source end
local oldSpeedGate = settings:GetAttribute("DriveInSpeedGateEnabled")
local changedLabels = {}

local ok, problem = pcall(function()
	for label, object in pairs(targets) do
		if object.Source ~= projected[label] then
			table.insert(changedLabels, label)
			object.Source = projected[label]
		end
	end
	settings:SetAttribute("DriveInSpeedGateEnabled", false)
	audit()
end)

if not ok then
	for _, label in ipairs(changedLabels) do targets[label].Source = originals[label] end
	settings:SetAttribute("DriveInSpeedGateEnabled", oldSpeedGate)
	error(PREFIX .. " INSTALL ROLLBACK: " .. tostring(problem))
end

print(PREFIX .. " INSTALL PASS | restart Play, verify Race prompt Next immediately adds Objective 3 alongside Objective 2, then refresh the complete Studio mirror.")
