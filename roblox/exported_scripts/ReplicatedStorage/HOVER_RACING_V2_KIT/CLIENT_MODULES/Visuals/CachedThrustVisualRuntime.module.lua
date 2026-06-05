local Runtime = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LOCAL_PLAYER = Players.LocalPlayer
local KIT_NAME = "HOVER_RACING_V2_KIT"
local DEFAULT_THRUST = Color3.fromRGB(255, 255, 255)
local VISUAL_RATE = 1 / 30
local SCAN_RATE = 0.5
local UI_RATE = 0.2
local ORIENTATION_RATE = 1

local connection
local visualTimer = 0
local scanTimer = 0
local uiTimer = 0
local orientationTimer = 0
local tracked = setmetatable({}, { __mode = "k" })

-- V66_LEAK_SAFE_RUNTIME_MARKER
local function newWeakSet()
	return setmetatable({}, { __mode = "k" })
end

local controls
local controlsDisabled = false

local kit = ReplicatedStorage:WaitForChild(KIT_NAME)
local templates = kit:FindFirstChild("VFX_TEMPLATES")
local vfxControllerModule
pcall(function()
	vfxControllerModule = require(kit:WaitForChild("CLIENT_MODULES"):WaitForChild("VFX"):WaitForChild("VehicleVFXController"))
end)

local function lower(text)
	return string.lower(tostring(text or ""))
end

local function pathText(instance)
	local parts = {}
	local current = instance
	while current and current ~= Workspace do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return lower(table.concat(parts, "/"))
end

local function pathHas(instance, token)
	return string.find(pathText(instance), lower(token), 1, true) ~= nil
end

local function tableCount(t)
	local count = 0
	for _ in pairs(t) do
		count += 1
	end
	return count
end

local function isToggleable(object)
	return object:IsA("ParticleEmitter")
		or object:IsA("Beam")
		or object:IsA("Trail")
		or object:IsA("Fire")
		or object:IsA("Smoke")
		or object:IsA("Sparkles")
		or object:IsA("PointLight")
		or object:IsA("SpotLight")
		or object:IsA("SurfaceLight")
end

local function setEnabled(object, enabled)
	if isToggleable(object) and object.Enabled ~= enabled then
		object.Enabled = enabled
	end
end

local function colourObject(object, colour)
	if object:IsA("ParticleEmitter") then
		object.Color = ColorSequence.new(colour)
		object.LockedToPart = true
		object.VelocityInheritance = 0
	elseif object:IsA("Fire") then
		object.Color = colour
		object.SecondaryColor = colour
	elseif object:IsA("Smoke") then
		object.Color = colour
	elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
		object.Color = colour
	end
end

local function resolvePaintChannel(object)
	local current = object
	while current do
		if current.Name == "THRUST_COLOR_WhiteByDefault" then return "ThrustColor" end
		if current.Name == "NEON_OptionalLights" then return "Neon" end
		if current.Name == "PRIMARY_ReplaceWithPrimaryMeshes" then return "Primary" end
		if current.Name == "SECONDARY_ReplaceWithSecondaryMeshes" then return "Secondary" end
		if current.Name == "DETAIL_ReplaceWithDetailMeshes" then return "Detail" end
		current = current.Parent
	end
	current = object
	while current do
		local channel = current:GetAttribute("PaintChannel")
		if typeof(channel) == "string" and channel ~= "" then
			return channel
		end
		current = current.Parent
	end
	return nil
end

local function belongsToThrustModule(object)
	local text = pathText(object)
	return string.find(text, "engine", 1, true) ~= nil
		or string.find(text, "boost", 1, true) ~= nil
		or string.find(text, "stabiliser", 1, true) ~= nil
		or string.find(text, "stabilizer", 1, true) ~= nil
end

local function classifyVFX(object)
	local text = pathText(object)
	if string.find(text, "engineoff_", 1, true) or string.find(text, "engineoff", 1, true) then return "EngineOff" end
	if string.find(text, "engineon_", 1, true) or string.find(text, "engineon", 1, true) then return "EngineOn" end
	if string.find(text, "booston_", 1, true) or string.find(text, "booston", 1, true) then return "BoostOn" end
	if string.find(text, "stabiliseron_", 1, true) or string.find(text, "stabilizeron_", 1, true) or string.find(text, "stabiliseron", 1, true) or string.find(text, "stabilizeron", 1, true) then return "StabiliserOn" end
	return nil
end

local function sideFromName(object)
	local text = pathText(object)
	if string.find(text, "left", 1, true) or string.find(text, "_l", 1, true) then return "Left" end
	if string.find(text, "right", 1, true) or string.find(text, "_r", 1, true) then return "Right" end
	return nil
end

local function worldPosition(object)
	if object:IsA("Attachment") then return object.WorldPosition end
	if object:IsA("BasePart") then return object.Position end
	local parent = object.Parent
	while parent do
		if parent:IsA("Attachment") then return parent.WorldPosition end
		if parent:IsA("BasePart") then return parent.Position end
		parent = parent.Parent
	end
	return nil
end

local function sideFromPosition(model, object)
	local root = model and (model.PrimaryPart or model:FindFirstChild("CockpitRoot_DoNotRename", true))
	local pos = root and worldPosition(object)
	if not (root and pos) then return nil end
	local localX = root.CFrame:PointToObjectSpace(pos).X
	if localX < -0.15 then return "Left" end
	if localX > 0.15 then return "Right" end
	return nil
end

local function getPreviewRoot()
	return Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
end

local function isPreviewModel(model)
	local preview = getPreviewRoot()
	return preview and (model == preview or model:IsDescendantOf(preview))
end

local function controlRootFor(model)
	local preview = getPreviewRoot()
	if preview and (model == preview or model:IsDescendantOf(preview)) then
		return preview
	end
	return model
end

local function readAttr(cache, name)
	local value = cache.Model:GetAttribute(name)
	if value ~= nil then return value end
	if cache.ControlRoot and cache.ControlRoot ~= cache.Model then
		return cache.ControlRoot:GetAttribute(name)
	end
	return nil
end

local function thrustColour(cache)
	local value = readAttr(cache, "ThrustColor")
	if typeof(value) == "Color3" then return value end
	return DEFAULT_THRUST
end

local function runtimeState(cache)
	local forcePreview = readAttr(cache, "ForceThrustPreview") == true
	local driveReady = readAttr(cache, "DriveReady") == true
	local preview = isPreviewModel(cache.Model)
	local driving = driveReady or forcePreview
	local accelerating = readAttr(cache, "Accelerating") == true
	local boosting = readAttr(cache, "Boosting") == true
	local driftLeft = readAttr(cache, "DriftingLeft") == true
	local driftRight = readAttr(cache, "DriftingRight") == true

	if preview and forcePreview then
		return {
			Driving = true,
			ForcePreview = true,
			Accelerating = true,
			Boosting = true,
			DriftLeft = true,
			DriftRight = true,
			AnyDrift = true,
		}
	end

	return {
		Driving = driving,
		ForcePreview = false,
		Accelerating = accelerating,
		Boosting = boosting,
		DriftLeft = driftLeft,
		DriftRight = driftRight,
		AnyDrift = driftLeft or driftRight,
	}
end

local function stateKey(state)
	return table.concat({
		state.Driving and "1" or "0",
		state.ForcePreview and "1" or "0",
		state.Accelerating and "1" or "0",
		state.Boosting and "1" or "0",
		state.DriftLeft and "1" or "0",
		state.DriftRight and "1" or "0",
	}, ":")
end

local function enabledFor(kind, side, state)
	if state.ForcePreview then return true end
	if kind == "EngineOff" then return state.Driving and not state.Accelerating end
	if kind == "EngineOn" then return state.Driving and state.Accelerating end
	if kind == "BoostOn" then return state.Driving and state.Boosting end
	if kind == "StabiliserOn" then
		if side == "Left" then return state.Driving and state.DriftLeft end
		if side == "Right" then return state.Driving and state.DriftRight end
		return state.Driving and state.AnyDrift
	end
	return nil
end

local function addToSet(set, object)
	if object and object.Parent then
		set[object] = true
	end
end

local function scanOne(cache, object)
	if not (object and object.Parent) then return end
	if cache.Known[object] then return end

	local useful = false

	if object:IsA("BasePart") then
		if resolvePaintChannel(object) == "ThrustColor" and belongsToThrustModule(object) then
			addToSet(cache.ThrustParts, object)
			useful = true
		end
		if pathHas(object, "templatehost_invisible") or object:GetAttribute("TemplateRole") == "VFXHost" then
			addToSet(cache.InvisibleHosts, object)
			useful = true
		end
	end

	local kind = classifyVFX(object)
	if kind and isToggleable(object) then
		local side = sideFromName(object) or sideFromPosition(cache.Model, object)
		cache.VFXObjects[object] = {
			Kind = kind,
			Side = side,
		}
		useful = true
		if object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
			addToSet(cache.ColourObjects, object)
		end
	elseif kind and (object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight")) then
		addToSet(cache.ColourObjects, object)
		useful = true
	end

	if useful then
		cache.Known[object] = true
	end
end


local function scanTree(cache, root)
	scanOne(cache, root)
	for _, descendant in ipairs(root:GetDescendants()) do
		scanOne(cache, descendant)
	end
end

local function forgetObject(cache, object)
	cache.Known[object] = nil
	cache.ThrustParts[object] = nil
	cache.ColourObjects[object] = nil
	cache.InvisibleHosts[object] = nil
	cache.VFXObjects[object] = nil
end

local function forgetTree(cache, root)
	forgetObject(cache, root)
	local ok, descendants = pcall(function()
		return root and root:GetDescendants() or {}
	end)
	if ok then
		for _, descendant in ipairs(descendants) do
			forgetObject(cache, descendant)
		end
	end
end

local function cleanupDead(cache)
	for object in pairs(cache.Known) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.Known[object] = nil
		end
	end
	for object in pairs(cache.ThrustParts) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.ThrustParts[object] = nil
		end
	end
	for object in pairs(cache.ColourObjects) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.ColourObjects[object] = nil
		end
	end
	for object in pairs(cache.InvisibleHosts) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.InvisibleHosts[object] = nil
		end
	end
	for object in pairs(cache.VFXObjects) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.VFXObjects[object] = nil
		end
	end
end


local function applyColour(cache, colour)
	for part in pairs(cache.ThrustParts) do
		if part.Parent then
			if part.Color ~= colour then part.Color = colour end
			if part.Material ~= Enum.Material.Neon then part.Material = Enum.Material.Neon end
			if part.Transparency ~= 0 then part.Transparency = 0 end
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	for object in pairs(cache.ColourObjects) do
		if object.Parent then
			colourObject(object, colour)
		end
	end
	for part in pairs(cache.InvisibleHosts) do
		if part.Parent then
			part.Transparency = 1
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
end

local function attachTemplateController(cache)
	if cache.Controller or not (vfxControllerModule and templates) then return end
	if typeof(vfxControllerModule) ~= "table" or typeof(vfxControllerModule.Attach) ~= "function" then return end
	local ok, controller = pcall(function()
		return vfxControllerModule.Attach(cache.Model, templates, UserInputService.TouchEnabled)
	end)
	if ok and controller then
		cache.Controller = controller
		scanTree(cache, cache.Model)
	end
end

local function updateTemplateController(cache, state, dt)
	if not cache.Controller or typeof(cache.Controller.Update) ~= "function" then return end
	local throttle = state.Accelerating and 1 or 0
	local boost = state.Boosting and 1 or 0
	local drift = state.AnyDrift and 1 or 0
	if state.ForcePreview then
		throttle = 1
		boost = 1
		drift = 1
	end
	pcall(function()
		cache.Controller:Update(dt, {
			Throttle = throttle,
			Boost = boost,
			Drift = drift,
			DriftLeft = state.DriftLeft and 1 or 0,
			DriftRight = state.DriftRight and 1 or 0,
			HoverDust = state.Driving and 0.45 or 0,
			Brake = 0,
		})
	end)
end

local function applyVFXState(cache, state)
	local key = stateKey(state)
	if cache.LastStateKey == key then return end
	cache.LastStateKey = key
	for object, meta in pairs(cache.VFXObjects) do
		if object.Parent then
			local enabled = enabledFor(meta.Kind, meta.Side, state)
			if enabled ~= nil then
				setEnabled(object, enabled)
			end
		end
	end
end

local function updateCache(cache, dt)
	if not cache.Model.Parent then return false end
	attachTemplateController(cache)
	local state = runtimeState(cache)
	updateTemplateController(cache, state, dt)
	local colour = thrustColour(cache)
	if cache.LastColour ~= colour or cache.NeedsColour then
		cache.LastColour = colour
		cache.NeedsColour = false
		applyColour(cache, colour)
	else
		for part in pairs(cache.ThrustParts) do
			if part.Parent and (part.Transparency ~= 0 or part.Material ~= Enum.Material.Neon) then
				part.Color = colour
				part.Material = Enum.Material.Neon
				part.Transparency = 0
			end
		end
	end
	applyVFXState(cache, state)
	return true
end

local function destroyCache(cache)
	for _, item in ipairs(cache.Connections) do
		item:Disconnect()
	end
	if cache.Controller and typeof(cache.Controller.Destroy) == "function" then
		pcall(function() cache.Controller:Destroy() end)
	end
	cache.Controller = nil
	cache.Known = newWeakSet()
	cache.ThrustParts = newWeakSet()
	cache.ColourObjects = newWeakSet()
	cache.VFXObjects = newWeakSet()
	cache.InvisibleHosts = newWeakSet()
	tracked[cache.Model] = nil
end


local function trackModel(model)
	if not model or not model:IsA("Model") then return end
	local existing = tracked[model]
	local controlRoot = controlRootFor(model)
	if existing then
		existing.ControlRoot = controlRoot
		return
	end

	local cache = {
		Model = model,
		ControlRoot = controlRoot,
		Known = newWeakSet(),
		ThrustParts = newWeakSet(),
		ColourObjects = newWeakSet(),
		VFXObjects = newWeakSet(),
		InvisibleHosts = newWeakSet(),
		Connections = {},
		NeedsColour = true,
		LastColour = nil,
		LastStateKey = nil,
		Controller = nil,
	}
	tracked[model] = cache
	scanTree(cache, model)

	table.insert(cache.Connections, model.DescendantAdded:Connect(function(descendant)
		scanTree(cache, descendant)
		cache.NeedsColour = true
		cache.LastStateKey = nil
	end))
	table.insert(cache.Connections, model.DescendantRemoving:Connect(function(descendant)
		forgetTree(cache, descendant)
		cache.NeedsColour = true
		cache.LastStateKey = nil
	end))
	table.insert(cache.Connections, model.Destroying:Connect(function()
		destroyCache(cache)
	end))

	if controlRoot then
		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("ThrustColor"):Connect(function()
			cache.NeedsColour = true
		end))
		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("ForceThrustPreview"):Connect(function()
			cache.LastStateKey = nil
		end))
	end
	table.insert(cache.Connections, model:GetAttributeChangedSignal("ThrustColor"):Connect(function()
		cache.NeedsColour = true
	end))
	for _, attr in ipairs({ "DriveReady", "Accelerating", "Boosting", "DriftingLeft", "DriftingRight" }) do
		table.insert(cache.Connections, model:GetAttributeChangedSignal(attr):Connect(function()
			cache.LastStateKey = nil
		end))
	end

	updateCache(cache, 0)
end


local function runtimeVehicles()
	local world = Workspace:FindFirstChild("HOVER_RACING_V2_WORLD")
	local vehiclesRoot = world and world:FindFirstChild("PLAYER_VEHICLES_Runtime")
	if not vehiclesRoot then return end
	for _, child in ipairs(vehiclesRoot:GetChildren()) do
		if child:IsA("Model") then
			trackModel(child)
		end
	end
end

local function previewVehicles()
	local preview = getPreviewRoot()
	if not preview then return end
	if preview:IsA("Model") then
		trackModel(preview)
		return
	end
	for _, child in ipairs(preview:GetChildren()) do
		if child:IsA("Model") then
			trackModel(child)
		end
	end
end

local function scanCandidates()
	runtimeVehicles()
	previewVehicles()
	for model, cache in pairs(tracked) do
		if not model.Parent then
			destroyCache(cache)
		else
			cleanupDead(cache)
		end
	end
end

local function playerVehicle()
	local world = Workspace:FindFirstChild("HOVER_RACING_V2_WORLD")
	local vehiclesRoot = world and world:FindFirstChild("PLAYER_VEHICLES_Runtime")
	if not vehiclesRoot then return nil end
	for _, vehicle in ipairs(vehiclesRoot:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == LOCAL_PLAYER.UserId then
			return vehicle
		end
	end
	return nil
end

local function garageOpen()
	local gui = LOCAL_PLAYER:FindFirstChild("PlayerGui") and LOCAL_PLAYER.PlayerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui.Enabled == true
end

local function driveOpen()
	local gui = LOCAL_PLAYER:FindFirstChild("PlayerGui") and LOCAL_PLAYER.PlayerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	return gui and gui.Enabled == true
end

local function setRobloxTouchControls(enabled)
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = enabled
	end
	if controls then
		if enabled and controlsDisabled then
			controlsDisabled = false
			pcall(function() controls:Enable() end)
		elseif not enabled and not controlsDisabled then
			controlsDisabled = true
			pcall(function() controls:Disable() end)
		end
	end
end

local function updateCameraAndTouchControls()
	-- V72_CAMERA_NUDGE_DISABLED
	-- DrivingControllerV47 owns the driving camera now. Keep only the
	-- mobile touch-control visibility behavior from the visual runtime.
	if UserInputService.TouchEnabled then
		setRobloxTouchControls(not garageOpen() and not driveOpen())
	end
end


local function requestLandscape()
	if not UserInputService.TouchEnabled then return end
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
	if playerGui then
		pcall(function() playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
	end
end

local function initControls()
	task.defer(function()
		local scripts = LOCAL_PLAYER:WaitForChild("PlayerScripts", 10)
		local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
		if not playerModule then return end
		local ok, module = pcall(require, playerModule)
		if ok and module and module.GetControls then
			controls = module:GetControls()
		end
	end)
end

function Runtime.Start()
	if connection then return end
	initControls()
	scanCandidates()
	requestLandscape()
	connection = RunService.RenderStepped:Connect(function(dt)
		visualTimer += dt
		scanTimer += dt
		uiTimer += dt
		orientationTimer += dt

		if scanTimer >= SCAN_RATE then
			scanTimer = 0
			scanCandidates()
		end

		if visualTimer >= VISUAL_RATE then
			local stepDt = visualTimer
			visualTimer = 0
			for _, cache in pairs(tracked) do
				if not updateCache(cache, stepDt) then
					destroyCache(cache)
				end
			end
		end

		if uiTimer >= UI_RATE then
			uiTimer = 0
			updateCameraAndTouchControls()
		end

		if orientationTimer >= ORIENTATION_RATE then
			orientationTimer = 0
			requestLandscape()
		end
	end)
end

function Runtime.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, cache in pairs(tracked) do
		destroyCache(cache)
	end
	tracked = {}
end

function Runtime.DebugCounts()
	local vehicles = 0
	local thrustParts = 0
	local vfxObjects = 0
	for _, cache in pairs(tracked) do
		vehicles += 1
		thrustParts += tableCount(cache.ThrustParts)
		vfxObjects += tableCount(cache.VFXObjects)
	end
	return {
		Vehicles = vehicles,
		ThrustParts = thrustParts,
		VFXObjects = vfxObjects,
		TemplatesAttached = templates ~= nil and vfxControllerModule ~= nil,
	}
end

return Runtime
