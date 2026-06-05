local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleVFXController = {}
VehicleVFXController.__index = VehicleVFXController

local KIT_NAME = "HOVER_RACING_V2_KIT"
local CONFIG_ROOT_NAME = "00_EDIT_ME_FIRST"
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
	local editRoot = kit and kit:FindFirstChild(CONFIG_ROOT_NAME)
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
