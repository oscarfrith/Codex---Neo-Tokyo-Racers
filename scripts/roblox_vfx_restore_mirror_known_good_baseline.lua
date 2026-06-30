-- Neo Tokyo Racers - restore vehicle VFX scripts from the current Studio mirror baseline
-- Generated from roblox/exported_scripts after the mirror was confirmed to still hold
-- the known-good pre-VFX-patch baseline. This script intentionally touches only:
--   - ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.VFX.VehicleVFXController
--   - ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime
--   - StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active
--   - StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active
--   - guarded VFX-only snippets inside NeoTokyoRacersClient_Bootstrap_Shadow_Disabled, if those snippets match a prior VFX patch
--
-- Run in Studio edit mode with Play stopped. Then start a fresh Play session.

local LOG_PREFIX = "[NTR VFX Restore Mirror Baseline]"

local gameServices = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	StarterPlayer = game:GetService("StarterPlayer"),
}

local function log(message)
	print(LOG_PREFIX .. " " .. message)
end

local function warnLog(message)
	warn(LOG_PREFIX .. " " .. message)
end

local function resolvePath(pathParts)
	local current = gameServices[pathParts[1]]
	assert(current, LOG_PREFIX .. " Unknown root: " .. tostring(pathParts[1]))
	for index = 2, #pathParts do
		current = current:FindFirstChild(pathParts[index])
		assert(current, LOG_PREFIX .. " Missing path segment: " .. table.concat(pathParts, ".", 1, index))
	end
	return current
end

local function setSource(pathParts, expectedClass, source)
	local scriptObject = resolvePath(pathParts)
	assert(scriptObject:IsA(expectedClass), LOG_PREFIX .. " Expected " .. table.concat(pathParts, ".") .. " to be " .. expectedClass .. ", got " .. scriptObject.ClassName)
	if scriptObject.Source == source then
		log("Already matched mirror source: " .. table.concat(pathParts, "."))
		return false
	end
	scriptObject.Source = source
	log("Restored mirror source: " .. table.concat(pathParts, "."))
	return true
end

local function replaceSnippet(scriptObject, label, oldText, newText)
	local source = scriptObject.Source
	if string.find(source, newText, 1, true) then
		log("Bootstrap already has mirror VFX snippet: " .. label)
		return false
	end
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	if not startIndex then
		warnLog("Bootstrap VFX snippet not found, skipped: " .. label)
		return false
	end
	scriptObject.Source = string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
	log("Restored bootstrap VFX snippet: " .. label)
	return true
end
setSource({ "ReplicatedStorage", "NeoTokyoRacers", "Shared", "Modules", "Client", "VFX", "VehicleVFXController" }, "ModuleScript", [====[
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleVFXController = {}
VehicleVFXController.__index = VehicleVFXController

local KIT_NAME = "NeoTokyoRacers"
local CONFIG_ROOT_NAME = "Editable"
local CONFIG_NAME = "STABILISER_VFX_DIRECTION_DoNotRename"

local function readValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if not item then return fallback end
	local ok, value = pcall(function()
		return item.Value
	end)
	if ok then return value end
	return fallback
end

local function directionConfig()
	local kit = ReplicatedStorage:FindFirstChild(KIT_NAME)
	local editRoot = kit and kit:WaitForChild("Config"):FindFirstChild(CONFIG_ROOT_NAME)
	return editRoot and editRoot:FindFirstChild(CONFIG_NAME)
end

local function globalSettings(templates)
	local folder = templates and templates:FindFirstChild("00_GLOBAL_VFX_SETTINGS")
	return {
		DesktopParticleScale = readValue(folder, "DesktopParticleScale", 1),
		MobileParticleScale = readValue(folder, "MobileParticleScale", 0.55),
		UpdateRateHz = math.clamp(readValue(folder, "UpdateRateHz", 30), 8, 60),
		CullDistanceStuds = readValue(folder, "CullDistanceStuds", 260),
	}
end

local function templateSettings(template)
	local settings = template and template:FindFirstChild("Settings")
	return {
		MobileScale = readValue(settings, "MobileScale", 0.7),
		EnabledOnMobile = readValue(settings, "EnabledOnMobile", true),
	}
end

local function templateNameFromSocket(socket)
	local explicit = socket:GetAttribute("VFXTemplate")
	if explicit then return explicit end
	local lower = string.lower(socket.Name)
	if string.find(lower, "hoverdust", 1, true) then return "HoverDust" end
	if string.find(lower, "enginejet", 1, true) then return "EngineJet" end
	if string.find(lower, "boostjet", 1, true) then return "BoostJet" end
	if string.find(lower, "stabiliserjet", 1, true) or string.find(lower, "stabilizerjet", 1, true) then return "StabiliserJet" end
	if string.find(lower, "brakespark", 1, true) then return "BrakeSparks" end
	return nil
end

local function stabiliserSideFromSocket(socket)
	if not socket then return nil end
	local lower = string.lower(socket.Name)
	if string.find(lower, "left", 1, true) or string.find(lower, "port", 1, true) then
		return "Left"
	end
	if string.find(lower, "right", 1, true) or string.find(lower, "starboard", 1, true) then
		return "Right"
	end

	local ok, x = pcall(function()
		return socket.Position.X
	end)
	if ok then
		if x < -0.05 then return "Left" end
		if x > 0.05 then return "Right" end
	end

	return nil
end

local function defaultGroupForTemplate(templateName)
	if templateName == "EngineJet" then return "EngineThrust" end
	if templateName == "BoostJet" then return "Boost" end
	if templateName == "StabiliserJet" then return "Drift" end
	if templateName == "HoverDust" then return "HoverDust" end
	if templateName == "BrakeSparks" then return "Brake" end
	return "Manual"
end

local function effectGroup(effect, templateName)
	local attr = effect:GetAttribute("VFXGroup")
	if type(attr) == "string" and attr ~= "" then
		return attr
	end

	local lower = string.lower(effect.Name)
	if string.find(lower, "engineoff", 1, true) then return "EngineIdle" end
	if string.find(lower, "engineon", 1, true) then return "EngineThrust" end
	if string.find(lower, "booston", 1, true) then return "Boost" end
	if string.find(lower, "stabiliseron", 1, true) or string.find(lower, "stabilizeron", 1, true) then return "Drift" end
	if string.find(lower, "boost", 1, true) then return "Boost" end
	if string.find(lower, "stabiliser", 1, true) or string.find(lower, "stabilizer", 1, true) then return "Drift" end
	if string.find(lower, "hoverdust", 1, true) or string.find(lower, "dust", 1, true) then return "HoverDust" end
	if string.find(lower, "brake", 1, true) or string.find(lower, "spark", 1, true) then return "Brake" end
	return defaultGroupForTemplate(templateName)
end

local function keyboardSteer()
	local steer = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		steer -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		steer += 1
	end
	return steer
end

local function gamepadSteer()
	local ok, states = pcall(function()
		return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	end)
	if not ok then return 0 end
	for _, inputObject in ipairs(states) do
		if inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then
			return inputObject.Position.X
		end
	end
	return 0
end

local function yawSteer(root)
	if not root then return 0 end
	local ok, value = pcall(function()
		return root.AssemblyAngularVelocity:Dot(root.CFrame.UpVector)
	end)
	if not ok then return 0 end
	return value
end

local function inferredDriftSide(self, state)
	local drift = state.Drift or 0
	if drift <= 0.05 then return "None" end

	local config = directionConfig()
	local directionSign = math.sign(readValue(config, "DirectionSign", 1))
	if directionSign == 0 then directionSign = 1 end
	local inputDeadzone = math.max(readValue(config, "InputDeadzone", 0.08), 0.01)
	local yawDeadzone = math.max(readValue(config, "YawDeadzone", 0.08), 0.01)

	local input = keyboardSteer()
	if math.abs(input) <= inputDeadzone then
		input = gamepadSteer()
	end
	if math.abs(input) > inputDeadzone then
		input *= directionSign
		return input < 0 and "Left" or "Right"
	end

	local yaw = yawSteer(self.Root) * directionSign
	if math.abs(yaw) > yawDeadzone then
		-- If this feels reversed on your vehicle, flip DirectionSign to -1.
		return yaw > 0 and "Left" or "Right"
	end

	return "None"
end

local function intensityForGroup(self, group, state)
	if group == "EngineIdle" then
		return (state.Throttle or 0) > 0.05 and 0 or 1
	end
	if group == "EngineThrust" then return state.Throttle or 0 end
	if group == "EngineJet" then return state.Throttle or 0 end
	if group == "Boost" then return state.Boost or 0 end
	if group == "Drift" then return state.Drift or 0 end
	if group == "DriftLeft" then
		if state.DriftLeft ~= nil then return state.DriftLeft end
		return inferredDriftSide(self, state) == "Left" and (state.Drift or 0) or 0
	end
	if group == "DriftRight" then
		if state.DriftRight ~= nil then return state.DriftRight end
		return inferredDriftSide(self, state) == "Right" and (state.Drift or 0) or 0
	end
	if group == "HoverDust" then return state.HoverDust or 0 end
	if group == "Brake" then return state.Brake or 0 end
	return 0
end

local function isToggleable(instance)
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
end

local function isCustomToggleTemplate(templateName)
	return templateName == "EngineJet" or templateName == "BoostJet" or templateName == "StabiliserJet"
end

local function isPartInsidePart(part, template)
	local parent = part.Parent
	while parent and parent ~= template do
		if parent:IsA("BasePart") then
			return true
		end
		parent = parent.Parent
	end
	return false
end

local function topLevelTemplateParts(template)
	local parts = {}
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("BasePart") and not isPartInsidePart(descendant, template) then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function prepRuntimeHost(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Transparency = 1
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.CastShadow = false
			descendant.Transparency = 1
		end
	end
end

local function weldNestedParts(rootPart)
	for _, descendant in ipairs(rootPart:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "VFX_NestedRuntimeWeld"
			weld.Part0 = rootPart
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

local function tokenFromName(name)
	local lower = string.lower(name or "")
	if string.find(lower, "short", 1, true) then return "short" end
	if string.find(lower, "mid", 1, true) then return "mid" end
	if string.find(lower, "long", 1, true) then return "long" end
	return nil
end

local function attachmentDistance(a, b)
	local ok, distance = pcall(function()
		return (a.WorldPosition - b.WorldPosition).Magnitude
	end)
	if ok then return distance end
	return (a.Position - b.Position).Magnitude
end

local function bestBeamEnd(root, origin, token)
	local best = nil
	local bestScore = math.huge
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant ~= origin then
			local lower = string.lower(descendant.Name)
			local score = attachmentDistance(origin, descendant)
			if string.find(lower, "beamend", 1, true) then score -= 1000 end
			if token and string.find(lower, token, 1, true) then score -= 500 end
			if score < bestScore then
				bestScore = score
				best = descendant
			end
		end
	end
	return best
end

local function repairBeamAttachments(root)
	for _, beam in ipairs(root:GetDescendants()) do
		if beam:IsA("Beam") then
			local origin = beam.Attachment0
			if not origin and beam.Parent and beam.Parent:IsA("Attachment") then
				origin = beam.Parent
				beam.Attachment0 = origin
			end

			if origin and (not beam.Attachment1 or beam.Attachment1 == origin) then
				local token = tokenFromName(beam.Name) or tokenFromName(origin.Name)
				local endAttachment = bestBeamEnd(root, origin, token)
				if endAttachment then
					beam.Attachment1 = endAttachment
				end
			end
		end
	end
end

local function trackEffect(self, effect, templateName, settings, socketSide)
	local group = effectGroup(effect, templateName)
	if templateName == "StabiliserJet" then
		if socketSide == "Left" then
			group = "DriftLeft"
		elseif socketSide == "Right" then
			group = "DriftRight"
		else
			group = "Drift"
		end
	end

	if effect:IsA("ParticleEmitter") then
		effect.LockedToPart = true
		effect.VelocityInheritance = 0
	end

	local record = {
		Object = effect,
		Group = group,
		TemplateName = templateName,
		Settings = settings,
		CustomToggle = isCustomToggleTemplate(templateName),
		RateMin = effect:IsA("ParticleEmitter") and (effect:GetAttribute("RateMin") or 0) or nil,
		RateMax = effect:IsA("ParticleEmitter") and (effect:GetAttribute("RateMax") or effect.Rate) or nil,
		Width0Min = effect:IsA("Beam") and (effect:GetAttribute("Width0Min") or 0) or nil,
		Width0Max = effect:IsA("Beam") and (effect:GetAttribute("Width0Max") or effect.Width0) or nil,
		Width1Min = effect:IsA("Beam") and (effect:GetAttribute("Width1Min") or 0) or nil,
		Width1Max = effect:IsA("Beam") and (effect:GetAttribute("Width1Max") or effect.Width1) or nil,
		BrightnessMin = (effect:IsA("PointLight") or effect:IsA("SpotLight") or effect:IsA("SurfaceLight")) and (effect:GetAttribute("BrightnessMin") or 0) or nil,
		BrightnessMax = (effect:IsA("PointLight") or effect:IsA("SpotLight") or effect:IsA("SurfaceLight")) and (effect:GetAttribute("BrightnessMax") or effect.Brightness) or nil,
		RangeMin = (effect:IsA("PointLight") or effect:IsA("SpotLight") or effect:IsA("SurfaceLight")) and (effect:GetAttribute("RangeMin") or 0) or nil,
		RangeMax = (effect:IsA("PointLight") or effect:IsA("SpotLight") or effect:IsA("SurfaceLight")) and (effect:GetAttribute("RangeMax") or effect.Range) or nil,
	}

	effect.Enabled = false
	table.insert(self.Items, record)
end

local function attachWholeTemplate(self, socket, template, templateName)
	local settings = templateSettings(template)
	if self.IsMobile and not settings.EnabledOnMobile then return end

	local socketSide = templateName == "StabiliserJet" and stabiliserSideFromSocket(socket) or nil
	local parts = topLevelTemplateParts(template)
	if #parts == 0 then return end

	local reference = template:FindFirstChild("TemplateHost_Invisible", true)
	if not (reference and reference:IsA("BasePart")) then
		reference = parts[1]
	end

	local parentPart = socket.Parent
	if not (parentPart and parentPart:IsA("BasePart")) then return end

	for _, templatePart in ipairs(parts) do
		local relative = reference.CFrame:ToObjectSpace(templatePart.CFrame)
		local clone = templatePart:Clone()
		clone.Name = socket.Name .. "_" .. templatePart.Name .. "_Runtime"
		prepRuntimeHost(clone)
		clone.CFrame = socket.WorldCFrame * relative
		clone.Parent = parentPart
		weldNestedParts(clone)

		local weld = Instance.new("WeldConstraint")
		weld.Name = "VFX_RuntimeWeld"
		weld.Part0 = parentPart
		weld.Part1 = clone
		weld.Parent = clone

		repairBeamAttachments(clone)
		table.insert(self.CreatedHosts, clone)

		for _, descendant in ipairs(clone:GetDescendants()) do
			if isToggleable(descendant) then
				trackEffect(self, descendant, templateName, settings, socketSide)
			end
		end
	end
end

function VehicleVFXController.Attach(vehicle, templates, isMobile)
	local self = setmetatable({
		Vehicle = vehicle,
		Templates = templates,
		IsMobile = isMobile == true,
		Items = {},
		CreatedHosts = {},
		Elapsed = 0,
		Globals = globalSettings(templates),
		Root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)),
	}, VehicleVFXController)

	if not vehicle or not templates then
		return self
	end

	for _, socket in ipairs(vehicle:GetDescendants()) do
		if socket:IsA("Attachment") and (socket:GetAttribute("VFXSocket") == true or string.sub(socket.Name, 1, 4) == "VFX_") then
			local templateName = templateNameFromSocket(socket)
			local template = templateName and templates:FindFirstChild(templateName)
			if template then
				attachWholeTemplate(self, socket, template, templateName)
			end
		end
	end

	return self
end

function VehicleVFXController:Visible()
	if not self.Root or not self.Root.Parent then return false end
	local camera = Workspace.CurrentCamera
	if not camera then return true end
	return (camera.CFrame.Position - self.Root.Position).Magnitude <= self.Globals.CullDistanceStuds
end


local function V39_IsThrustFireObject(object)
	local lower = string.lower(object.Name)
	return string.find(lower, "booston_fire", 1, true)
		or string.find(lower, "engineoff_fire", 1, true)
		or string.find(lower, "engineon_fire", 1, true)
		or string.find(lower, "stabiliseron_fire", 1, true)
		or string.find(lower, "stabilizeron_fire", 1, true)
end

local function V39_ApplyThrustFireColour(object, color)
	if not object or not color then return end
	if object:IsA("ParticleEmitter") then
		object.Color = ColorSequence.new(color)
	elseif object:IsA("Fire") then
		object.Color = color
		object.SecondaryColor = color
	elseif object:IsA("Smoke") then
		object.Color = color
	elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
		object.Color = color
	end
end

function VehicleVFXController:Update(dt, state)
	self.Elapsed += dt
	local interval = 1 / self.Globals.UpdateRateHz
	if self.Elapsed < interval then return end
	self.Elapsed = 0

	state = state or {}
	local visible = self:Visible()
	local quality = self.IsMobile and self.Globals.MobileParticleScale or self.Globals.DesktopParticleScale
	local thrustColor = (self.Vehicle and self.Vehicle:GetAttribute("ThrustColor")) or Color3.fromRGB(255, 255, 255)

	for _, record in ipairs(self.Items) do
		local object = record.Object
		if object and object.Parent then
			if V39_IsThrustFireObject(object) then
				V39_ApplyThrustFireColour(object, thrustColor)
			end
			local intensity = visible and math.clamp(intensityForGroup(self, record.Group, state), 0, 1) or 0
			if self.IsMobile then
				intensity *= record.Settings.MobileScale
			end

			local active = intensity > 0.05
			object.Enabled = active

			if active and not record.CustomToggle then
				if object:IsA("ParticleEmitter") and record.RateMax then
					object.Rate = (record.RateMin + (record.RateMax - record.RateMin) * intensity) * quality
				elseif object:IsA("Beam") then
					if record.Width0Max then object.Width0 = record.Width0Min + (record.Width0Max - record.Width0Min) * intensity end
					if record.Width1Max then object.Width1 = record.Width1Min + (record.Width1Max - record.Width1Min) * intensity end
				elseif (object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight")) then
					if record.BrightnessMax then object.Brightness = record.BrightnessMin + (record.BrightnessMax - record.BrightnessMin) * intensity end
					if record.RangeMax then object.Range = record.RangeMin + (record.RangeMax - record.RangeMin) * intensity end
				end
			end
		end
	end
end

function VehicleVFXController:Destroy()
	for _, record in ipairs(self.Items) do
		if record.Object then
			record.Object.Enabled = false
		end
	end
	for _, host in ipairs(self.CreatedHosts) do
		if host then
			host:Destroy()
		end
	end
	self.Items = {}
	self.CreatedHosts = {}
end

return VehicleVFXController

]====])

setSource({ "ReplicatedStorage", "NeoTokyoRacers", "Shared", "Modules", "Client", "Visuals", "CachedThrustVisualRuntime" }, "ModuleScript", [====[
local Runtime = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local LOCAL_PLAYER = Players.LocalPlayer
local KIT_NAME = "NeoTokyoRacers"
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
local templates = kit:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("VehicleTemplates")
local vfxControllerModule
pcall(function()
	vfxControllerModule = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("VFX"):WaitForChild("VehicleVFXController"))
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
	local clientOnlyRoot = Workspace:FindFirstChild("_NTR_ClientOnly")
	local dealershipPreview = clientOnlyRoot and clientOnlyRoot:FindFirstChild("VehiclePreview")
	if dealershipPreview then
		return dealershipPreview
	end
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
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local vehiclesRoot = world and (world and world:FindFirstChild("Runtime") and world.Runtime:FindFirstChild("PlayerVehicles"))
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
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local vehiclesRoot = world and (world and world:FindFirstChild("Runtime") and world.Runtime:FindFirstChild("PlayerVehicles"))
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

]====])

setSource({ "StarterPlayer", "StarterPlayerScripts", "NeoTokyoRacersClient", "Controllers", "Runtime", "RuntimeVFXController_Active" }, "LocalScript", [====[
local ok, runtime = pcall(function()
	return require(game:GetService("ReplicatedStorage")
		:WaitForChild("NeoTokyoRacers")
		:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client")
		:WaitForChild("Visuals")
		:WaitForChild("CachedThrustVisualRuntime"))
end)

if ok and typeof(runtime) == "table" and typeof(runtime.Start) == "function" then
	runtime.Start()
	print("[V64] Cached thrust visual runtime active.")
else
	warn("[V64] Cached thrust visual runtime failed to start: " .. tostring(runtime))
end

]====])

setSource({ "StarterPlayer", "StarterPlayerScripts", "NeoTokyoRacersClient", "Controllers", "Preview", "ThrustPreviewController_Active" }, "LocalScript", [====[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local templates = kit:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("VehicleTemplates")
local controllerModule
pcall(function()
	controllerModule = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("VFX"):WaitForChild("VehicleVFXController"))
end)

local previewController
local previewVehicle
local lastPass = 0
local controls
local controlsDisabled = false

task.defer(function()
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
	if not playerModule then return end
	local ok, module = pcall(require, playerModule)
	if ok and module and module.GetControls then
		controls = module:GetControls()
	end
end)

local function requestLandscape()
	pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
	pcall(function() playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
end

local function garageOpen()
	local gui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui.Enabled
end

local function driveOpen()
	local hud = playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	return hud and hud.Enabled
end

local function setRobloxTouchControls(enabled)
	local touchGui = playerGui:FindFirstChild("TouchGui")
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

local function getPlayerVehicle()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local root = world and (world and world:FindFirstChild("Runtime") and world.Runtime:FindFirstChild("PlayerVehicles"))
	if not root then return nil end
	for _, vehicle in ipairs(root:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == player.UserId then
			return vehicle
		end
	end
end

local function getPreviewRoot()
	local clientOnlyRoot = Workspace:FindFirstChild("_NTR_ClientOnly")
	local dealershipPreview = clientOnlyRoot and clientOnlyRoot:FindFirstChild("VehiclePreview")
	if dealershipPreview then
		return dealershipPreview
	end
	return Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
end

local function getPreviewVehicle(root)
	if not root then return nil end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Model") then return child end
	end
end

local function hasChannel(object, channel)
	local current = object
	while current do
		if current:GetAttribute("PaintChannel") == channel then return true end
		if channel == "ThrustColor" and string.find(string.lower(current.Name), "thrust_color", 1, true) then return true end
		current = current.Parent
	end
	return false
end

local function isThrustFire(object)
	local lower = string.lower(object.Name)
	return string.find(lower, "booston_fire", 1, true)
		or string.find(lower, "engineoff_fire", 1, true)
		or string.find(lower, "engineon_fire", 1, true)
		or string.find(lower, "stabiliseron_fire", 1, true)
		or string.find(lower, "stabilizeron_fire", 1, true)
end

local function applyFireColour(object, color)
	if object:IsA("ParticleEmitter") then
		object.Color = ColorSequence.new(color)
	elseif object:IsA("Fire") then
		object.Color = color
		object.SecondaryColor = color
	elseif object:IsA("Smoke") then
		object.Color = color
	elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
		object.Color = color
	end
end

local function applyThrustOnly(root, color, forceEnabled)
	if not root then return end
	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA("BasePart") and hasChannel(object, "ThrustColor") then
			object.Color = color
			object.Material = Enum.Material.Neon
			object.Transparency = 0
		elseif isThrustFire(object) then
			applyFireColour(object, color)
			if forceEnabled ~= nil then
				pcall(function() object.Enabled = forceEnabled end)
			end
		end
	end
end

local function updatePreviewVFX(root, dt)
	local force = root and root:GetAttribute("ForceThrustPreview") == true
	local vehicle = force and getPreviewVehicle(root) or nil
	if not force or not vehicle or not controllerModule or not templates then
		if previewController then
			previewController:Destroy()
			previewController = nil
			previewVehicle = nil
		end
		return
	end
	local thrust = root:GetAttribute("ThrustColor") or Color3.fromRGB(255, 255, 255)
	vehicle:SetAttribute("ThrustColor", thrust)
	if previewVehicle ~= vehicle then
		if previewController then previewController:Destroy() end
		previewVehicle = vehicle
		previewController = controllerModule.Attach(vehicle, templates, UserInputService.TouchEnabled)
	end
	if previewController then
		previewController:Update(dt, {
			Throttle = 1,
			Boost = 1,
			Drift = 1,
			DriftLeft = 1,
			DriftRight = 1,
			HoverDust = 0,
			Brake = 0,
		})
	end
end

local function forceDriveCamera()
	if not driveOpen() then return end
	local vehicle = getPlayerVehicle()
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	local camera = Workspace.CurrentCamera
	if camera and seat and seat:IsA("VehicleSeat") then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = seat
	end
end

requestLandscape()
RunService.RenderStepped:Connect(function(dt)
	requestLandscape()
	if UserInputService.TouchEnabled then
		setRobloxTouchControls(not garageOpen() and not driveOpen())
	end
	forceDriveCamera()

	local now = os.clock()
	if now - lastPass < 0.05 then return end
	lastPass = now

	local preview = getPreviewRoot()
	if preview then
		local thrust = preview:GetAttribute("ThrustColor") or Color3.fromRGB(255, 255, 255)
		local force = preview:GetAttribute("ForceThrustPreview") == true
		updatePreviewVFX(preview, dt)
		applyThrustOnly(preview, thrust, force and true or nil)
	end

	local vehicle = getPlayerVehicle()
	if vehicle then
		local thrust = vehicle:GetAttribute("ThrustColor") or Color3.fromRGB(255, 255, 255)
		applyThrustOnly(vehicle, thrust, nil)
	end
end)

]====])

local bootstrap = resolvePath({ "StarterPlayer", "StarterPlayerScripts", "NeoTokyoRacersClient", "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled" })
assert(bootstrap:IsA("LocalScript"), LOG_PREFIX .. " Expected bootstrap to be a LocalScript")

replaceSnippet(bootstrap, "legacy stop restores direct vehicleVFX destroy",[====[
	if currentVehicle then
		currentVehicle:SetAttribute("DriveReady", false)
		currentVehicle:SetAttribute("Accelerating", false)
		currentVehicle:SetAttribute("Boosting", false)
		currentVehicle:SetAttribute("DriftingLeft", false)
		currentVehicle:SetAttribute("DriftingRight", false)
	end
	vehicleVFX = nil
	controls = nil
	currentVehicle = nil
	cachedDriveStats = nil
	setJumpLocked(false)
]====],
[====[
	if vehicleVFX then vehicleVFX:Destroy(); vehicleVFX = nil end
	controls = nil
	currentVehicle = nil
	cachedDriveStats = nil
	setJumpLocked(false)
]====])

replaceSnippet(bootstrap, "legacy start restores direct VehicleVFXController attach",
[====[
	if vehicleVFX then vehicleVFX:Destroy(); vehicleVFX = nil end
	currentVehicle:SetAttribute("DriveReady", true)
	currentVehicle:SetAttribute("Accelerating", false)
	currentVehicle:SetAttribute("Boosting", false)
	currentVehicle:SetAttribute("DriftingLeft", false)
	currentVehicle:SetAttribute("DriftingRight", false)
	-- CachedThrustVisualRuntime is the single VehicleVFXController/template-host owner.
]====],
[====[
	if vehicleVFX then vehicleVFX:Destroy() end
	local vfxModule = (typeof(V22Modules) == "table" and V22Modules.VehicleVFXController) or VehicleVFXController
	vehicleVFX = vfxModule.Attach(currentVehicle, kit:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("VehicleTemplates"), UserInputService.TouchEnabled)
]====])

replaceSnippet(bootstrap, "legacy heartbeat restores direct vehicleVFX update",
[====[
		currentVehicle:SetAttribute("Accelerating", throttle > 0.05)
		currentVehicle:SetAttribute("Boosting", (boostHeld and boostPower > 0 and boost > 0) or miniBoostTimer > 0)
		currentVehicle:SetAttribute("DriftingLeft", drifting and steeringInput < -0.05)
		currentVehicle:SetAttribute("DriftingRight", drifting and steeringInput > 0.05)
]====],
[====[
		if vehicleVFX then
			vehicleVFX:Update(dt, {
				Throttle = math.clamp(throttle, 0, 1),
				Boost = (boostHeld and boostPower > 0 and boost > 0) and 1 or 0,
				Drift = driftBlend,
				HoverDust = grounded and math.clamp(0.18 + speedMph / 95, 0, 1) or 0,
				Brake = throttle < -0.2 and math.clamp(speedMph / 80, 0, 1) or 0,
			})
		end
]====])

log("Restore complete. Stop any current Play session, then start a fresh Play test.")
log("Expected baseline: VFX toggles normally again; original mobile intermittent-missing issue may return until a separate narrow delayed-attach fix is added.")