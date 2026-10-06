-- Canonical feature implementation; startup is owned by the composition root.
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleVFXController = {}
VehicleVFXController.__index = VehicleVFXController

local CONFIG_ROOT_NAME = "Editable"
local CONFIG_NAME = "STABILISER_VFX_DIRECTION_DoNotRename"

-- Exotic V2 effects (VFX rework). Tunables are attributes on
-- ReplicatedStorage.Config.Vehicles.StabiliserVFX; these are the fallbacks.
local Players = game:GetService("Players")

local V2_DEFAULTS = {
	ExoticVFXV2Enabled = true,
	ExoticV2BoostIntakeSeconds = 0.1,
	ExoticV2BoostHandoverSeconds = 0.6,
	ExoticV2BoostFadeSeconds = 0.6,
	ExoticV2BoostPulseHz = 10,
	ExoticV2MiniBoostScale = 0.7,
	ExoticV2PadBase = 0.55,
	ExoticV2PadSquashGain = 0.35,
	ExoticV2PadSpeedGain = 0.1,
	ExoticV2PadAirborne = 0.3,
	ExoticV2PadStandby = 0.25,
	ExoticV2DustBase = 0,
	ExoticV2DustSpeedGain = 0,
	ExoticV2DustSquashGain = 0,
	ExoticV2DustSpeedFullMph = 140,
	ExoticV2PreviewDust = 0,
	ExoticV2RemoteDust = 0,
	ExoticV2GroundRayStuds = 12,
	ExoticV2GroundFallbackStuds = 3,
	ExoticV2GroundPadGapStuds = 1.6,
	ExoticV2GroundTintMix = 0.55,
	ExoticV2GroundLightEnabled = true,
	ExoticV2SlipSparkMin = 0.12,
	ExoticV2SlipSparkSign = 1,
	ExoticV2ScrapeMin = 0.1,
	ExoticV2VapourMinMph = 150,
	-- Round 3: clean underglow instead of pad graphics and a dust ring.
	ExoticV2PadGraphic = 0,
	-- Round 4: hover jets under the engines (replace the round 3 underglow).
	ExoticV2HoverJet = 1,
	ExoticV2HoverJetBase = 0.6,
	ExoticV2HoverJetSquashGain = 0.4,
	ExoticV2HoverJetThrottleGain = 0.15,
	ExoticV2HoverJetLandGain = 0.6,
	ExoticV2HoverJetAirborne = 0.3,
	ExoticV2HoverJetStandby = 0.2,
	ExoticV2GroundGlow = 0.35,
	ExoticV2MistSpeedGain = 0.5,
	ExoticV2DriftThrustersOutside = true,
	ExoticV2ChargeIdle = 0.12,
}

local V2_SHARED_TEMPLATES = {
	HoverDust = "HoverDust_ExoticV2",
	BrakeSparks = "BrakeSparks_ExoticV2",
}
local V2_HOVER_TEMPLATE = "HoverDust_ExoticV2"
local V2_GROUND_TEMPLATE = "GroundFX_ExoticV2"
local V2_IMPACT_TEMPLATE = "BrakeSparks_ExoticV2"
local V2_TRAILS_TEMPLATE = "SpeedTrails_ExoticV2"
local V2_GROUND_SOCKET_NAME = "VFX_FeelGroundFX"
local V2_TRAILS_SOCKET_NAME = "VFX_FeelSpeedTrails"
local V2_UNDERGLOW_SOCKET_NAME = "VFX_FeelHoverJet"
local V2_HOVER_JET_TEMPLATE = "HoverJet_ExoticV2"
local V2_LAND_PULSE_TAU = 0.25
-- One hover jet under each engine, and nowhere else. Drop: studs below the
-- engine's jet socket (the belly of the pod). Inset: studs back along the pod
-- from its nozzle. Scale: beam width and particle size; rear engines are larger.
local V2_UNDERGLOW_UNITS = {
	Engine = { Template = V2_HOVER_JET_TEMPLATE, Drop = 0.75, Inset = 1.6, Scale = 1, RearScale = 1.2 },
}
local V2_CHANNEL_CEILING = 2
local V2_MOVER_CEILING = 1.5
local V2_FLASH_TAU = 0.07
local V2_GROUND_LIGHT_HEIGHT = 1.4

local v2Config = table.clone(V2_DEFAULTS)
local v2ConfigClock = -math.huge

local function refreshV2Config(now)
	if now - v2ConfigClock < 0.5 then return end
	v2ConfigClock = now
	local config = ReplicatedStorage:FindFirstChild("Config")
	local vehicles = config and config:FindFirstChild("Vehicles")
	local folder = vehicles and vehicles:FindFirstChild("StabiliserVFX")
	for name, fallback in pairs(V2_DEFAULTS) do
		local value = folder and folder:GetAttribute(name)
		if typeof(value) == typeof(fallback) and value == value and value ~= math.huge and value ~= -math.huge then
			v2Config[name] = value
		else
			v2Config[name] = fallback
		end
	end
end

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
	local kit = game:GetService("ReplicatedStorage")
	local editRoot = kit and game:GetService("ReplicatedStorage"):WaitForChild("Config"):FindFirstChild("Vehicles")
	return editRoot and game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):FindFirstChild("StabiliserVFX")
end

local function globalSettings(templates)
	local folder = templates and templates:FindFirstChild("00_GLOBAL_VFX_SETTINGS")
	return {
		DesktopParticleScale = readValue(folder, "DesktopParticleScale", 1),
		MobileParticleScale = readValue(folder, "MobileParticleScale", 0.55),
		UpdateRateHz = math.clamp(readValue(folder, "UpdateRateHz", 30), 8, 60),
		CullDistanceStuds = readValue(folder, "CullDistanceStuds", 260),
		MobileInitialAttachDelaySeconds = math.clamp(readValue(folder, "MobileInitialAttachDelaySeconds", 0.45), 0, 2),
		MaxRecommendedParticlesPerVehicle = readValue(folder, "MaxRecommendedParticlesPerVehicle", 0),
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
	-- Exotic V2 channels (set by updateV2) take precedence; nil for other vehicles.
	local channels = self.Channels
	if channels then
		local value = channels[group]
		if value ~= nil then return value end
	end
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
	part:SetAttribute("VFXRuntimeHost", true)
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

local JET_FLOOR_GROUPS = {
	EngineThrust = true,
	EngineJet = true,
	Boost = true,
	Drift = true,
	DriftLeft = true,
	DriftRight = true,
}

local BACKFIRE_BOOST_GROUPS = {
	Boost = true,
}

local BACKFIRE_ENGINE_GROUPS = {
	EngineThrust = true,
	EngineJet = true,
}

-- Puts back what a backfire flash changed on a light or beam.
local function restoreFlash(record)
	local saved = record.FlashRestore
	record.FlashRestore = nil
	local object = record.Object
	if not (saved and object) then return end
	pcall(function()
		if saved.Brightness then
			object.Brightness = saved.Brightness
		end
		if saved.Width0 then
			object.Width0 = saved.Width0
			object.Width1 = saved.Width1
		end
		object.Enabled = saved.Enabled
	end)
end

-- One-off bursts (VehicleVFXController:Burst) reuse the emitters of the
-- BrakeSparks and HoverDust templates, including their category variants.
local function burstKindFor(group, templateName)
	local lower = string.lower(tostring(templateName or ""))
	if group == "Brake" or string.find(lower, "brakespark", 1, true) then return "Sparks" end
	if group == "HoverDust" or string.find(lower, "hoverdust", 1, true) then return "Dust" end
	return nil
end

local function numberAttribute(instance, name)
	local value = instance:GetAttribute(name)
	if type(value) == "number" and value == value then return value end
	return nil
end

local function trackEffect(self, effect, templateName, settings, socketSide, isV2)
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

	local isEmitter = effect:IsA("ParticleEmitter")
	-- V2 templates may leave particles in the world (dust, embers, sparks, smoke).
	if isEmitter and not (isV2 and effect:GetAttribute("WorldSpace") == true) then
		effect.LockedToPart = true
		effect.VelocityInheritance = 0
	end

	local isLight = effect:IsA("PointLight") or effect:IsA("SpotLight") or effect:IsA("SurfaceLight")
	local burstKind = nil
	if isEmitter then
		local explicit = effect:GetAttribute("VFXBurst")
		if type(explicit) == "string" then
			burstKind = explicit ~= "None" and explicit or nil
		else
			burstKind = burstKindFor(group, templateName)
		end
	end
	local tintStart = isV2 and numberAttribute(effect, "TintStart") or nil
	local record = {
		Object = effect,
		Group = group,
		TemplateName = templateName,
		Settings = settings,
		CustomToggle = isCustomToggleTemplate(templateName),
		BurstKind = burstKind,
		-- Exotic V2 drive data (all nil on older templates).
		V2 = isV2 == true,
		IsLight = isLight,
		Seed = (#self.Items + 1) * 1.37,
		Flicker = isV2 and numberAttribute(effect, "Flicker") or nil,
		FlickerHz = isV2 and numberAttribute(effect, "FlickerHz") or 8,
		BurstCount = isEmitter and numberAttribute(effect, "BurstCount") or nil,
		BurstShare = isEmitter and numberAttribute(effect, "BurstShare") or nil,
		SpeedScaleMin = isEmitter and isV2 and numberAttribute(effect, "SpeedScaleMin") or nil,
		SpeedScaleMax = isEmitter and isV2 and numberAttribute(effect, "SpeedScaleMax") or nil,
		BaseSpeed = isEmitter and effect.Speed or nil,
		LastSpeedScale = 1,
		GlowMin = isV2 and (isEmitter or effect:IsA("Beam")) and numberAttribute(effect, "GlowMin") or nil,
		GlowMax = isV2 and (isEmitter or effect:IsA("Beam")) and numberAttribute(effect, "GlowMax") or nil,
		TintStart = tintStart,
		TintEnd = tintStart and (numberAttribute(effect, "TintEnd") or tintStart) or nil,
		GroundTint = isV2 and isEmitter and effect:GetAttribute("GroundTint") == true or nil,
		BaseColor = isV2 and effect.Color or nil,
		-- Authored values of custom-toggle effects; scaled only when the caller passes JetFloor.
		BaseRate = effect:IsA("ParticleEmitter") and effect.Rate or nil,
		BaseWidth0 = effect:IsA("Beam") and effect.Width0 or nil,
		BaseWidth1 = effect:IsA("Beam") and effect.Width1 or nil,
		BaseBrightness = isLight and effect.Brightness or nil,
		BaseRange = isLight and effect.Range or nil,
		JetScale = 1,
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

	if burstKind == "Backfire" then
		self.HasV2Backfire = true
	end

	effect.Enabled = false
	table.insert(self.Items, record)
end

-- Exotic V2: an Attachment with VFXGroup and ZMin/ZMax is a beam end whose Z
-- follows its channel, so the jet gets longer with thrust.
local function trackMover(self, attachment)
	local group = attachment:GetAttribute("VFXGroup")
	local zMin = numberAttribute(attachment, "ZMin")
	local zMax = numberAttribute(attachment, "ZMax")
	if type(group) ~= "string" or not (zMin and zMax) then return end
	table.insert(self.Movers, {
		Object = attachment,
		Group = group,
		ZMin = zMin,
		ZMax = zMax,
		Base = attachment.Position,
		Last = -1,
	})
end

local function attachWholeTemplate(self, socket, template, templateName)
	local settings = templateSettings(template)
	if self.IsMobile and not settings.EnabledOnMobile then return end
	local isV2 = template:GetAttribute("VFXVersion") == 2

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
		-- V2 "VehicleAlign" templates ignore the socket's rotation: +Z points out
		-- of that side of the car and +Y is the car's up (drift thrusters).
		local hostCFrame = socket.WorldCFrame
		local alignRoot = self.Root
		local hasRoot = alignRoot ~= nil and alignRoot:IsA("BasePart")
		local align = isV2 and template:GetAttribute("VehicleAlign") or nil
		if hasRoot and (align == "Left" or align == "Right") then
			local rootCFrame = alignRoot.CFrame
			local outward = align == "Left" and -rootCFrame.RightVector or rootCFrame.RightVector
			local up = rootCFrame.UpVector
			hostCFrame = CFrame.fromMatrix(socket.WorldPosition, up:Cross(outward), up, outward)
		end
		clone.CFrame = hostCFrame * relative
		local hostY = hasRoot and alignRoot.CFrame:PointToObjectSpace(clone.Position).Y or 0
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
				-- V2 detail tiers: lights and other desktop-only effects are not kept
				-- on mobile; "Full" effects are not kept on remote players' vehicles.
				if isV2 and ((self.IsMobile and descendant:GetAttribute("DesktopOnly") == true)
					or (self.Reduced and descendant:GetAttribute("VFXTier") == "Full")) then
					descendant:Destroy()
				else
					trackEffect(self, descendant, templateName, settings, socketSide, isV2)
				end
			elseif isV2 and descendant:IsA("Attachment") then
				trackMover(self, descendant)
				-- Kept on the ground by applyGroundSnaps. Only used in hosts whose
				-- up axis is the car's (runtime sockets and VehicleAlign templates).
				if descendant:GetAttribute("GroundSnap") == true then
					table.insert(self.GroundSnaps, {
						Object = descendant,
						Base = descendant.Position,
						HostY = hostY,
						Lift = numberAttribute(descendant, "GroundLift") or 0.1,
					})
					self.SnapY = nil
				end
			end
		end
	end

	if isV2 then
		self.HasV2 = true
		self.Channels = self.Channels or {}
		self.TintColour = nil
	end
end

-- Exotic V2: attaches one template to a runtime Attachment at the centre of the
-- root part (so positions inside the clone are root-local). Returns the cloned
-- host part, or nil when the template is missing or nothing was attached. The
-- Attachment and the clone are destroyed with the controller's other hosts.
local function attachRuntimeTemplate(self, socketName, templateName, position)
	local template = self.Templates and self.Templates:FindFirstChild(templateName)
	local root = self.Root
	if not (template and root and root.Parent and root:IsA("BasePart")) then return nil end

	local socket = Instance.new("Attachment")
	socket.Name = socketName
	if position then
		socket.Position = position
	end
	socket.Parent = root

	local firstHost = #self.CreatedHosts + 1
	attachWholeTemplate(self, socket, template, templateName)
	local host = self.CreatedHosts[firstHost]
	if not host then
		socket:Destroy()
		return nil
	end
	table.insert(self.CreatedHosts, socket)
	return host
end

local function isExoticId(value)
	return type(value) == "string" and string.find(string.lower(value), "exotic", 1, true) ~= nil
end

-- A socket's VFXTemplate "X_Exotic..." (and the shared HoverDust / BrakeSparks)
-- resolves to its V2 template when the vehicle is Exotic, the switch is on and
-- that template exists. Otherwise the name is returned unchanged.
local function resolveTemplateName(self, templateName)
	if not self.ExoticV2 or type(templateName) ~= "string" then return templateName end
	local candidate = V2_SHARED_TEMPLATES[templateName]
	if not candidate and string.find(templateName, "_Exotic", 1, true) and string.sub(templateName, -2) ~= "V2" then
		candidate = templateName .. "V2"
	end
	if candidate and self.Templates:FindFirstChild(candidate) then
		return candidate
	end
	return templateName
end

-- Root-local bounds of the vehicle, measured once: centre and half size.
local function vehicleBounds(self)
	if self.Bounds then return self.Bounds end
	local root = self.Root
	local vehicle = self.Vehicle
	local center = Vector3.new(0, 0, 0)
	local half = root.Size * 0.5
	if vehicle and vehicle.PrimaryPart == root then
		-- With a PrimaryPart the box is aligned to it, so it is root-aligned.
		local ok, boxCFrame, boxSize = pcall(function()
			return vehicle:GetBoundingBox()
		end)
		if ok and boxCFrame and boxSize then
			center = root.CFrame:PointToObjectSpace(boxCFrame.Position)
			half = boxSize * 0.5
		end
	elseif self.HoverExtent then
		half = Vector3.new(
			math.max(half.X, self.HoverExtent.X + 1.5),
			math.max(half.Y, 1.4),
			math.max(half.Z, self.HoverExtent.Z + 2)
		)
	end
	self.Bounds = { Center = center, Half = half }
	return self.Bounds
end

local function placeGroundFixed(self)
	self.GroundFixed = true
	local groundPoint = self.GroundPoint
	if groundPoint and groundPoint.Parent then
		groundPoint.CFrame = CFrame.new(self.GroundLocal)
	end
	local lightPoint = self.GroundLightPoint
	if lightPoint and lightPoint.Parent then
		lightPoint.Position = self.GroundLocal + Vector3.new(0, V2_GROUND_LIGHT_HEIGHT, 0)
	end
end

-- One ground-effects template per Exotic V2 vehicle, under the hover sockets.
local function attachGroundFX(self, hoverCentre)
	local host = attachRuntimeTemplate(self, V2_GROUND_SOCKET_NAME, V2_GROUND_TEMPLATE)
	if not host then return end
	self.GroundPoint = host:FindFirstChild("GroundPoint")
	self.GroundLightPoint = host:FindFirstChild("GroundLightPoint")
	self.GroundLocal = hoverCentre - Vector3.new(0, math.max(v2Config.ExoticV2GroundPadGapStuds, 0), 0)
	placeGroundFixed(self)
end

-- Which under-car unit a resolved V2 template gets (nil = none). Only kinds
-- listed in V2_UNDERGLOW_UNITS are attached: the engines.
local function underglowKind(templateName)
	if type(templateName) ~= "string" then return nil end
	if templateName == V2_HOVER_TEMPLATE then return "Hover" end
	if string.sub(templateName, -2) ~= "V2" then return nil end
	if string.find(templateName, "EngineJet", 1, true) then return "Engine" end
	if string.find(templateName, "BoostJet", 1, true) then return "Boost" end
	if string.find(templateName, "StabiliserJet", 1, true) then return "Stabiliser" end
	return nil
end

local function scaledSequence(sequence, scale)
	local keypoints = {}
	for index, keypoint in ipairs(sequence.Keypoints) do
		keypoints[index] = NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale)
	end
	return NumberSequence.new(keypoints)
end

-- Exotic V2 hover jets: one car-aligned unit under every engine jet socket.
-- units = { { Kind, Position (root-local socket position), Back (root-local jet
-- direction) }, ... }. Each unit is a runtime socket on the root, so it is
-- destroyed with the controller's other hosts.
local function attachUnderglowUnits(self, units)
	for _, unit in ipairs(units) do
		local spec = V2_UNDERGLOW_UNITS[unit.Kind]
		if spec and not (self.Reduced and spec.LocalOnly) then
			local back = Vector3.new(unit.Back.X, 0, unit.Back.Z)
			local position = unit.Position - Vector3.new(0, spec.Drop, 0)
			if back.Magnitude > 0.3 then
				position -= back.Unit * spec.Inset
			end
			local firstItem = #self.Items + 1
			local host = attachRuntimeTemplate(self, V2_UNDERGLOW_SOCKET_NAME, spec.Template, position)
			if host then
				local scale = spec.Scale
				if spec.RearScale and unit.Position.Z > 0 then
					scale = spec.RearScale
				end
				for index = firstItem, #self.Items do
					local record = self.Items[index]
					local object = record.Object
					if scale ~= 1 and object:IsA("ParticleEmitter") then
						object.Size = scaledSequence(object.Size, scale)
					elseif scale ~= 1 and object:IsA("Beam") then
						object.Width0 *= scale
						object.Width1 *= scale
						record.Width0Min *= scale
						record.Width0Max *= scale
						record.Width1Min *= scale
						record.Width1Max *= scale
					end
				end
			end
		end
	end
end

local function isRuntimeHostDescendant(instance)
	local current = instance
	while current do
		if current:GetAttribute("VFXRuntimeHost") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function attachVehicleSocketsOnce(self)
	if self.Destroyed or self.SocketAttachDone then return end
	self.SocketAttachDone = true

	local vehicle = self.Vehicle
	local templates = self.Templates
	if not vehicle or not vehicle.Parent or not templates then
		return
	end

	self.Root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true) or self.Root
	local root = self.Root

	-- Collect the sockets first. A vehicle is Exotic when its model says so
	-- (CategoryId / CockpitId) or any socket asks for an "_Exotic" template.
	local sockets = {}
	local templateNames = {}
	local exotic = isExoticId(vehicle:GetAttribute("CategoryId")) or isExoticId(vehicle:GetAttribute("CockpitId"))
	for _, socket in ipairs(vehicle:GetDescendants()) do
		if socket:IsA("Attachment")
			and not isRuntimeHostDescendant(socket)
			and (socket:GetAttribute("VFXSocket") == true or string.sub(socket.Name, 1, 4) == "VFX_") then
			local templateName = templateNameFromSocket(socket)
			if templateName then
				table.insert(sockets, socket)
				templateNames[#sockets] = templateName
				if type(templateName) == "string" and string.find(templateName, "_Exotic", 1, true) then
					exotic = true
				end
			end
		end
	end

	refreshV2Config(os.clock())
	self.ExoticV2 = exotic and v2Config.ExoticVFXV2Enabled == true

	local hoverSum = Vector3.new(0, 0, 0)
	local hoverCount = 0
	local hoverExtentX, hoverExtentZ = 0, 0
	local underglowUnits = {}
	for index, socket in ipairs(sockets) do
		local templateName = resolveTemplateName(self, templateNames[index])
		local template = templates:FindFirstChild(templateName)
		if template then
			attachWholeTemplate(self, socket, template, templateName)
			local unitKind = self.ExoticV2 and underglowKind(templateName) or nil
			if unitKind and root and root:IsA("BasePart") then
				table.insert(underglowUnits, {
					Kind = unitKind,
					Position = root.CFrame:PointToObjectSpace(socket.WorldPosition),
					Back = root.CFrame:VectorToObjectSpace(-socket.WorldCFrame.LookVector),
				})
			end
			if templateName == V2_HOVER_TEMPLATE and root and root:IsA("BasePart") then
				local localPosition = root.CFrame:PointToObjectSpace(socket.WorldPosition)
				hoverSum += localPosition
				hoverCount += 1
				hoverExtentX = math.max(hoverExtentX, math.abs(localPosition.X))
				hoverExtentZ = math.max(hoverExtentZ, math.abs(localPosition.Z))
			end
		end
	end

	-- Fixed ground height (root-local Y) for everything that is not the local
	-- driving car: below the hover sockets, or the fallback gap below the root.
	local padGap = math.max(v2Config.ExoticV2GroundPadGapStuds, 0)
	self.GroundSnapFixedY = hoverCount > 0 and (hoverSum.Y / hoverCount - padGap) or -v2Config.ExoticV2GroundFallbackStuds

	if hoverCount > 0 then
		self.HoverExtent = Vector3.new(hoverExtentX, 0, hoverExtentZ)
		attachGroundFX(self, hoverSum / hoverCount)
	end
	if #underglowUnits > 0 then
		attachUnderglowUnits(self, underglowUnits)
	end
end

local IMPACT_SPARK_SOCKET_NAME = "VFX_FeelImpactSparks"
local IMPACT_SPARK_TEMPLATE_NAME = "BrakeSparks"

-- Exotic V2: puts the trail attachment pairs on the rear upper corners and the
-- tail of the vehicle's bounds (rear is +Z).
local function placeSpeedTrails(self, host)
	local bounds = vehicleBounds(self)
	local center, half = bounds.Center, bounds.Half
	local function place(name, x, y, z)
		local attachment = host:FindFirstChild(name)
		if attachment and attachment:IsA("Attachment") then
			attachment.Position = center + Vector3.new(x, y, z)
		end
	end
	local cornerX = half.X * 0.9
	local cornerY = half.Y * 0.7
	local cornerZ = half.Z * 0.85
	place("VapourLeftA", -cornerX, cornerY, cornerZ)
	place("VapourLeftB", -cornerX, cornerY - 0.2, cornerZ)
	place("VapourRightA", cornerX, cornerY, cornerZ)
	place("VapourRightB", cornerX, cornerY - 0.2, cornerZ)
	place("TailA", -0.9, half.Y * 0.1, half.Z)
	place("TailB", 0.9, half.Y * 0.1, half.Z)
end

-- Exotic V2: moves the impact spark source to the side of the car that was hit.
-- x, z is the car-local direction toward the obstacle (+X right, -Z forward).
-- Without a direction it sits at the front-bottom, as before the rework.
function VehicleVFXController:SetImpactSide(x, z)
	local point = self.ImpactPoint
	if not (point and point.Parent and self.Root) then return end
	x = tonumber(x)
	z = tonumber(z)
	local key = (x and z) and (math.floor(x * 20 + 0.5) * 100 + math.floor(z * 20 + 0.5)) or -1e6
	if key == self.ImpactSideKey then return end
	self.ImpactSideKey = key

	local bounds = vehicleBounds(self)
	local half = bounds.Half
	local position, away
	if x and z and (x * x + z * z) > 0.01 then
		local direction = Vector3.new(x, 0, z).Unit
		local reachX = math.abs(direction.X) > 0.001 and half.X / math.abs(direction.X) or math.huge
		local reachZ = math.abs(direction.Z) > 0.001 and half.Z / math.abs(direction.Z) or math.huge
		position = bounds.Center + direction * math.min(reachX, reachZ) + Vector3.new(0, -0.5 * half.Y, 0)
		away = -direction
	else
		position = bounds.Center + Vector3.new(0, -half.Y, -half.Z)
		away = Vector3.new(0, 0, 1)
	end
	-- Front (-Z) of the attachment points away from the obstacle and a little up.
	point.CFrame = CFrame.lookAt(position, position + away + Vector3.new(0, 0.35, 0))
end

-- Burst-only spark source for a vehicle with no authored BrakeSparks socket.
-- The caller (VehicleVFXClient) asks for it only on the local driving vehicle.
-- One Attachment at the front-bottom of the PrimaryPart (forward is -Z) takes
-- the BrakeSparks template through the normal socket attach path, so mobile
-- settings, culling and Destroy are inherited. Its effects are never driven by
-- the Brake input. Returns true once resolved (attached or not needed/possible).
function VehicleVFXController:EnsureImpactSparks()
	if self.Destroyed then return true end
	if self.ImpactSparksResolved then return true end
	if not self.SocketAttachDone then return false end
	self.ImpactSparksResolved = true

	-- Exotic V2: a directional spark source (moved by SetImpactSide) and the
	-- speed trails. Both are local-car extras, so they are attached here.
	if self.ExoticV2 then
		local trailsHost = attachRuntimeTemplate(self, V2_TRAILS_SOCKET_NAME, V2_TRAILS_TEMPLATE)
		if trailsHost then
			placeSpeedTrails(self, trailsHost)
		end
		local sparksHost = attachRuntimeTemplate(self, IMPACT_SPARK_SOCKET_NAME, V2_IMPACT_TEMPLATE)
		if sparksHost then
			self.ImpactPoint = sparksHost:FindFirstChild("ImpactPoint")
			self:SetImpactSide(nil, nil)
			return true
		end
	end

	for _, record in ipairs(self.Items) do
		if record.BurstKind == "Sparks" then return true end
	end

	local vehicle = self.Vehicle
	local template = self.Templates and self.Templates:FindFirstChild(IMPACT_SPARK_TEMPLATE_NAME)
	local root = vehicle and vehicle.Parent and vehicle.PrimaryPart
	if not (template and root and root:IsA("BasePart")) then return true end

	local socket = Instance.new("Attachment")
	socket.Name = IMPACT_SPARK_SOCKET_NAME
	socket.Position = Vector3.new(0, -0.5 * root.Size.Y, -0.5 * root.Size.Z)
	socket.Parent = root

	local firstItem = #self.Items + 1
	attachWholeTemplate(self, socket, template, IMPACT_SPARK_TEMPLATE_NAME)
	if #self.Items < firstItem then
		socket:Destroy()
		return true
	end
	table.insert(self.CreatedHosts, socket)
	for index = firstItem, #self.Items do
		local record = self.Items[index]
		record.Group = "Manual"
		record.BurstKind = record.Object:IsA("ParticleEmitter") and "Sparks" or nil
	end
	return true
end

-- options (optional): { Reduced = true } for a remote player's vehicle, which
-- drops the Exotic V2 "Full" tier effects when its templates are attached.
function VehicleVFXController.Attach(vehicle, templates, isMobile, options)
	local self = setmetatable({
		Vehicle = vehicle,
		Templates = templates,
		IsMobile = isMobile == true,
		Reduced = type(options) == "table" and options.Reduced == true,
		Movers = {},
		GroundSnaps = {},
		V2 = {
			BoostOn = false,
			BoostTime = 0,
			BoostScale = 1,
			Ignited = false,
			Plume = 0,
			FadeFrom = 0,
			FadeTime = 0,
			Flash = 0,
			PopFlash = 0,
			PopTau = 0.05,
			PeakCharge = 0,
			LastBoostKind = "",
		},
		Items = {},
		CreatedHosts = {},
		Elapsed = 0,
		Globals = globalSettings(templates),
		Root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)),
		SocketAttachDone = false,
		Destroyed = false,
	}, VehicleVFXController)

	if not vehicle or not templates then
		return self
	end

	local delaySeconds = self.IsMobile and self.Globals.MobileInitialAttachDelaySeconds or 0
	if delaySeconds > 0 then
		task.delay(delaySeconds, function()
			attachVehicleSocketsOnce(self)
		end)
	else
		attachVehicleSocketsOnce(self)
	end

	return self
end

function VehicleVFXController:Visible()
	if not self.Root or not self.Root.Parent then return false end
	local camera = Workspace.CurrentCamera
	if not camera then return true end
	return (camera.CFrame.Position - self.Root.Position).Magnitude <= self.Globals.CullDistanceStuds
end


local function isThrustFireObject(object)
	local lower = string.lower(object.Name)
	return string.find(lower, "booston_fire", 1, true)
		or string.find(lower, "engineoff_fire", 1, true)
		or string.find(lower, "engineon_fire", 1, true)
		or string.find(lower, "stabiliseron_fire", 1, true)
		or string.find(lower, "stabilizeron_fire", 1, true)
end

local function applyThrustFireColour(object, color)
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

-- ---------------------------------------------------------------------------
-- Exotic V2 drive. Everything below runs only for a controller that attached
-- at least one V2 template (self.HasV2); other vehicles never reach it.
-- ---------------------------------------------------------------------------

local function tintedSequence(base, target, mixStart, mixEnd)
	local keypoints = {}
	for index, keypoint in ipairs(base.Keypoints) do
		local mix = math.clamp(mixStart + (mixEnd - mixStart) * keypoint.Time, 0, 1)
		keypoints[index] = ColorSequenceKeypoint.new(keypoint.Time, keypoint.Value:Lerp(target, mix))
	end
	return ColorSequence.new(keypoints)
end

-- Thrust colour: energy effects follow it fully, fire keeps its colours with a
-- tint at the core (TintStart / TintEnd on each effect). Applied on change only.
local function applyV2Tint(self, thrust)
	for _, record in ipairs(self.Items) do
		local object = record.Object
		if record.TintStart and object and object.Parent then
			if record.IsLight then
				object.Color = record.BaseColor:Lerp(thrust, math.clamp(record.TintStart, 0, 1))
			else
				object.Color = tintedSequence(record.BaseColor, thrust, record.TintStart, record.TintEnd)
			end
		end
	end
end

-- Dust takes some of the colour of the surface under the car.
local function updateGroundTint(self, result)
	local instance = result.Instance
	local colour = nil
	if instance:IsA("Terrain") then
		local ok, value = pcall(function()
			return instance:GetMaterialColor(result.Material)
		end)
		if ok then colour = value end
	elseif instance:IsA("BasePart") then
		colour = instance.Color
	end
	if typeof(colour) ~= "Color3" then return end

	local key = math.floor(colour.R * 31 + 0.5) * 1024 + math.floor(colour.G * 31 + 0.5) * 32 + math.floor(colour.B * 31 + 0.5)
	if key == self.GroundTintKey then return end
	self.GroundTintKey = key

	local mix = math.clamp(v2Config.ExoticV2GroundTintMix, 0, 1)
	for _, record in ipairs(self.Items) do
		local object = record.Object
		if record.GroundTint and object and object.Parent then
			object.Color = tintedSequence(record.BaseColor, colour, mix, mix)
		end
	end
end

-- Puts the ground effects on the ground. Local driving car: one downward
-- raycast per visual update. Every other vehicle (parked, remote, preview):
-- a fixed offset below the hover sockets, no raycast. Returns 0..1, how much
-- ground there is to show effects on.
local function applyGroundSnaps(self, groundY)
	if self.SnapY and math.abs(groundY - self.SnapY) < 0.04 then return end
	self.SnapY = groundY
	for _, snap in ipairs(self.GroundSnaps) do
		local object = snap.Object
		if object.Parent then
			local base = snap.Base
			object.Position = Vector3.new(base.X, groundY + snap.Lift - snap.HostY, base.Z)
		end
	end
end

local function updateGround(self, feel, now, visible)
	local groundPoint = self.GroundPoint
	local fixedY = self.GroundSnapFixedY or -3
	if not (groundPoint and groundPoint.Parent) then
		applyGroundSnaps(self, fixedY)
		return 1
	end
	local root = self.Root
	if not (feel and feel.Local == true and visible and root and root.Parent) then
		if not self.GroundFixed then
			placeGroundFixed(self)
		end
		applyGroundSnaps(self, fixedY)
		return 1
	end
	self.GroundFixed = false

	local params = self.RayParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		params.RespectCanCollide = true
		self.RayParams = params
		self.RayFilterClock = -math.huge
	end
	if now - self.RayFilterClock > 1 then
		self.RayFilterClock = now
		-- The whole vehicles folder: another car under this one is not ground.
		local filter = { self.Vehicle, self.Vehicle.Parent }
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(filter, player.Character)
			end
		end
		params.FilterDescendantsInstances = filter
	end

	local rayLength = math.max(v2Config.ExoticV2GroundRayStuds, 1)
	local fallback = math.clamp(v2Config.ExoticV2GroundFallbackStuds, 0, rayLength)
	local origin = root.Position
	local result = Workspace:Raycast(origin, Vector3.new(0, -rayLength, 0), params)

	local position, up, presence
	if result then
		up = result.Normal
		position = result.Position + up * 0.12
		-- Fade the ground effects out as the car climbs away from the ground.
		local gap = origin.Y - result.Position.Y
		local fadeStart = fallback * 1.6
		presence = math.clamp(1 - (gap - fadeStart) / math.max(rayLength - fadeStart, 0.5), 0, 1)
		updateGroundTint(self, result)
	else
		up = Vector3.new(0, 1, 0)
		position = origin - up * fallback
		presence = feel.Grounded == false and 0 or 1
	end

	local right = root.CFrame.RightVector
	right = right - up * right:Dot(up)
	if right.Magnitude < 0.01 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	groundPoint.WorldCFrame = CFrame.fromMatrix(position, right, up)
	local lightPoint = self.GroundLightPoint
	if lightPoint and lightPoint.Parent then
		lightPoint.WorldPosition = position + up * V2_GROUND_LIGHT_HEIGHT
	end
	-- Pools and ground sparks share this one ground height (root-local).
	applyGroundSnaps(self, root.CFrame:PointToObjectSpace(position).Y)
	return presence
end

-- Fires the burst emitters of one kind (BurstCount particles each at scale 1).
local function emitV2Burst(self, kind, scale)
	local quality = self.IsMobile and self.Globals.MobileParticleScale or self.Globals.DesktopParticleScale
	quality = tonumber(quality) or 1
	local cap = tonumber(self.Globals.MaxRecommendedParticlesPerVehicle) or 0
	local emitted = 0
	for _, record in ipairs(self.Items) do
		local object = record.Object
		if record.BurstKind == kind and record.BurstCount and object and object.Parent then
			local amount = record.BurstCount * scale * quality
			if self.IsMobile then
				amount *= record.Settings.MobileScale
			end
			amount = math.max(1, math.floor(amount + 0.5))
			if cap > 0 and emitted + amount > cap then break end
			object:Emit(amount)
			emitted += amount
		end
	end
	return emitted
end

-- Computes this update's V2 channels (self.Channels) from the state table.
-- Inputs every caller sends: Throttle, Boost, Drift, DriftLeft, DriftRight,
-- HoverDust. Optional: Powered, Hidden, Preview, NoLights, ThrustColor, and
-- Feel = { Local, Hover, SpeedMph, Slip, DriftCharge, BoostKind, Scrape,
-- Grounded, ImpactX, ImpactZ } for the local driving vehicle.
local function updateV2(self, dt, state, now, visible)
	refreshV2Config(now)
	local config = v2Config
	local channels = self.Channels
	local v2 = self.V2
	local feel = type(state.Feel) == "table" and state.Feel or nil
	local hidden = state.Hidden == true
	local powered = state.Powered ~= false and not hidden
	local throttle = math.clamp(tonumber(state.Throttle) or 0, 0, 1)
	local boostOn = not hidden and (tonumber(state.Boost) or 0) > 0.05
	local drifting = math.max(tonumber(state.Drift) or 0, tonumber(state.DriftLeft) or 0, tonumber(state.DriftRight) or 0) > 0.05

	-- Thrust colour ------------------------------------------------------------
	local thrust = state.ThrustColor
	if typeof(thrust) ~= "Color3" then
		thrust = self.Vehicle and self.Vehicle:GetAttribute("ThrustColor")
	end
	if typeof(thrust) ~= "Color3" then
		thrust = Color3.new(1, 1, 1)
	end
	if thrust ~= self.TintColour then
		self.TintColour = thrust
		applyV2Tint(self, thrust)
	end

	-- Boost sequence -----------------------------------------------------------
	-- 0 .. intake: intake streaks, engines dim. At intake: flash, ring, fireball.
	-- intake .. handover: plume overshoots and settles, arcs and the pulsing
	-- light fade in. Boost end: the plume shrinks and sputters out with smoke.
	v2.Flash *= math.exp(-dt / V2_FLASH_TAU)
	if v2.Flash < 0.01 then v2.Flash = 0 end
	v2.PopFlash *= math.exp(-dt / math.max(v2.PopTau, 0.01))
	if v2.PopFlash < 0.01 then v2.PopFlash = 0 end

	if boostOn and not v2.BoostOn then
		v2.BoostOn = true
		v2.BoostTime = 0
		v2.Ignited = false
		v2.BoostScale = (feel and feel.BoostKind == "Mini") and math.clamp(config.ExoticV2MiniBoostScale, 0.2, 1) or 1
	elseif not boostOn and v2.BoostOn then
		v2.BoostOn = false
		v2.FadeTime = 0
		v2.FadeFrom = v2.Ignited and v2.Plume or 0
	end

	local intake, plume, light, arcs, smoke = 0, 0, 0, 0, 0
	local intakeSeconds = math.max(config.ExoticV2BoostIntakeSeconds, 0)
	if v2.BoostOn then
		v2.BoostTime += dt
		local scale = v2.BoostScale
		if v2.BoostTime < intakeSeconds then
			intake = 1
		else
			if not v2.Ignited then
				v2.Ignited = true
				v2.Flash = 2 * scale
				if visible then
					emitV2Burst(self, "BoostIgnite", scale)
				end
			end
			local sinceIgnition = v2.BoostTime - intakeSeconds
			local handover = math.max(config.ExoticV2BoostHandoverSeconds - intakeSeconds, 0.05)
			local settle = math.clamp(sinceIgnition / handover, 0, 1)
			local sustain = 0.6 + 0.4 * scale
			plume = sustain * (1 + 0.3 * (1 - settle) * (1 - settle))
			arcs = settle * scale
			light = sustain * settle * (0.7 + 0.3 * math.sin(sinceIgnition * 2 * math.pi * config.ExoticV2BoostPulseHz))
		end
		v2.Plume = plume
	elseif v2.FadeFrom > 0 then
		v2.FadeTime += dt
		local fade = v2.FadeTime / math.max(config.ExoticV2BoostFadeSeconds, 0.05)
		if fade < 1 then
			local sputter = 0.55 + 0.45 * math.clamp(0.5 + 1.6 * math.noise(now * 14, 3.1), 0, 1)
			plume = v2.FadeFrom * (1 - fade) * sputter
			smoke = math.sin(math.pi * fade)
			light = plume * 0.5
		else
			v2.FadeFrom = 0
		end
	end

	channels.EngineThrust = throttle * (intake > 0 and 0.6 or 1)
	channels.V2Idle = powered and 1 or 0
	channels.V2BoostIntake = intake
	channels.V2BoostPlume = plume
	channels.V2BoostArcs = arcs
	channels.V2BoostSmoke = smoke
	channels.V2BoostLight = math.min(light + v2.Flash + v2.PopFlash, V2_CHANNEL_CEILING)
	channels.V2TailRibbon = (feel and feel.Local == true and v2.BoostOn and v2.Ignited) and 1 or 0

	-- Drift: slide sparks, charge glow and arcs, release burst -----------------
	local grounded = not (feel and feel.Grounded == false)
	local charge = feel and math.clamp(tonumber(feel.DriftCharge) or 0, 0, 1) or 0
	if not feel and state.Preview == true and drifting then
		charge = 0.6
	end
	local slip = feel and (tonumber(feel.Slip) or 0) or 0
	local slipLevel = 0
	if drifting and grounded and not hidden then
		slipLevel = math.clamp((math.abs(slip) - config.ExoticV2SlipSparkMin) / 0.4, 0, 1)
	end
	local slipToRight = slip * config.ExoticV2SlipSparkSign > 0
	channels.V2SlipSparksLeft = slipToRight and 0 or slipLevel
	channels.V2SlipSparksRight = slipToRight and slipLevel or 0
	-- Dim while drifting at no charge, obvious by half, arcs from half to full.
	local chargeLevel = 0
	if not hidden and (drifting or charge > 0.04) then
		chargeLevel = math.max(math.clamp(config.ExoticV2ChargeIdle, 0, 1), charge)
	end
	channels.V2DriftCharge = chargeLevel
	channels.V2DriftChargeArcs = hidden and 0 or math.clamp((charge - 0.5) / 0.5, 0, 1)

	-- Drift thrusters. DriftingLeft means drifting while steering left. With
	-- ExoticV2DriftThrustersOutside the units on the outside of the turn fire
	-- (right side for a left drift): thrusting outward, they push the car into
	-- the turn. Front and rear units of a side share one template, so both fire.
	local thrustLeft = hidden and 0 or math.clamp(tonumber(state.DriftLeft) or 0, 0, 1)
	local thrustRight = hidden and 0 or math.clamp(tonumber(state.DriftRight) or 0, 0, 1)
	if config.ExoticV2DriftThrustersOutside then
		thrustLeft, thrustRight = thrustRight, thrustLeft
	end
	channels.DriftLeft = thrustLeft
	channels.DriftRight = thrustRight
	local leftOn = thrustLeft > 0.05
	local rightOn = thrustRight > 0.05
	if visible then
		if leftOn and not v2.ThrustLeftOn then
			emitV2Burst(self, "DriftStartLeft", 1)
		end
		if rightOn and not v2.ThrustRightOn then
			emitV2Burst(self, "DriftStartRight", 1)
		end
	end
	v2.ThrustLeftOn = leftOn
	v2.ThrustRightOn = rightOn

	if charge > v2.PeakCharge then
		v2.PeakCharge = charge
	end
	local boostKind = feel and feel.BoostKind or ""
	if boostKind == "Mini" and v2.LastBoostKind ~= "Mini" then
		if visible and not hidden then
			emitV2Burst(self, "DriftRelease", math.clamp(v2.PeakCharge, 0.4, 1))
		end
		v2.PeakCharge = 0
	end
	v2.LastBoostKind = boostKind
	v2.PeakCharge = math.max(0, v2.PeakCharge - dt)
	if charge > v2.PeakCharge then
		v2.PeakCharge = charge
	end

	-- Hover pads and ground effects --------------------------------------------
	local squash = feel and math.clamp(tonumber(feel.Hover) or 0, 0, 1) or 0
	local speedMph = feel and (tonumber(feel.SpeedMph) or 0) or 0
	local speedAlpha = math.clamp(speedMph / math.max(config.ExoticV2DustSpeedFullMph, 1), 0, 1)

	local pad
	if hidden then
		pad = 0
	elseif not powered then
		pad = config.ExoticV2PadStandby
	elseif grounded then
		pad = math.clamp(config.ExoticV2PadBase + config.ExoticV2PadSquashGain * squash + config.ExoticV2PadSpeedGain * speedAlpha, 0, 1)
	else
		pad = config.ExoticV2PadAirborne
	end
	-- A little instability at speed, on top of each effect's own flicker.
	pad *= 1 - 0.15 * speedAlpha * math.clamp(0.5 + math.noise(now * 13, 9.7), 0, 1)
	if self.Reduced then
		pad *= 0.6
	end

	local presence = updateGround(self, feel, now, visible)

	local dust
	if hidden or not powered or not grounded then
		dust = 0
	elseif feel then
		dust = math.clamp(config.ExoticV2DustBase + config.ExoticV2DustSpeedGain * speedAlpha + config.ExoticV2DustSquashGain * squash, 0, 1)
	elseif state.Preview == true then
		dust = config.ExoticV2PreviewDust
	else
		dust = (tonumber(state.HoverDust) or 0) > 0.05 and config.ExoticV2RemoteDust or 0
	end

	local mist = 0
	if feel and powered and grounded then
		mist = math.clamp(config.ExoticV2MistSpeedGain * speedAlpha, 0, 1)
	end

	-- Hover jets under the engines: on whenever the car is powered (they hold it
	-- up). Stronger with hover squash, a little with throttle, and for a moment
	-- after a landing; a low pilot flame when parked; dimmer in the air, where
	-- the jet lengthens (its end stays on the ground) and fades with the gap.
	v2.LandPulse = (v2.LandPulse or 0) * math.exp(-dt / V2_LAND_PULSE_TAU)
	if v2.LandPulse < 0.01 then v2.LandPulse = 0 end
	local hoverJet
	if hidden then
		hoverJet = 0
	elseif not powered then
		hoverJet = config.ExoticV2HoverJetStandby
	elseif grounded then
		hoverJet = config.ExoticV2HoverJetBase
			+ config.ExoticV2HoverJetSquashGain * squash
			+ config.ExoticV2HoverJetThrottleGain * throttle
			+ config.ExoticV2HoverJetLandGain * v2.LandPulse
	else
		hoverJet = config.ExoticV2HoverJetAirborne * presence
	end
	hoverJet = math.clamp(hoverJet * math.max(config.ExoticV2HoverJet, 0), 0, V2_MOVER_CEILING)
	if self.Reduced then
		hoverJet *= 0.8
	end

	-- The pad graphics and the large glow pool are scaled by config (pad
	-- graphics off by default).
	local padGraphic = math.max(config.ExoticV2PadGraphic, 0)

	channels.V2HoverPad = pad * padGraphic
	channels.V2HoverTight = (powered and grounded) and squash * padGraphic or 0
	channels.V2HoverJet = hoverJet
	channels.V2HoverSplash = grounded and hoverJet * presence or 0
	channels.V2GroundDust = dust * presence
	channels.V2GroundMist = mist * presence
	channels.V2GroundGlow = pad * presence * math.max(config.ExoticV2GroundGlow, 0)
	channels.V2GroundLight = config.ExoticV2GroundLightEnabled and pad * presence or 0

	-- Scrape sparks and speed trails (local driving vehicle) -------------------
	local scrape = feel and (tonumber(feel.Scrape) or 0) or 0
	if not hidden and scrape > config.ExoticV2ScrapeMin then
		channels.V2Scrape = math.clamp(scrape, 0, 1)
		self:SetImpactSide(feel.ImpactX, feel.ImpactZ)
	else
		channels.V2Scrape = 0
	end
	channels.V2Vapour = (feel and feel.Local == true and not hidden and speedMph >= config.ExoticV2VapourMinMph) and 1 or 0
end

function VehicleVFXController:Update(dt, state)
	self.Elapsed += dt
	local interval = 1 / self.Globals.UpdateRateHz
	if self.Elapsed < interval then return end
	local stepSeconds = self.Elapsed
	self.Elapsed = 0

	state = state or {}
	local visible = self:Visible()
	local quality = self.IsMobile and self.Globals.MobileParticleScale or self.Globals.DesktopParticleScale
	local thrustColor = (self.Vehicle and self.Vehicle:GetAttribute("ThrustColor")) or Color3.fromRGB(255, 255, 255)
	-- Optional continuous drive. Without these two fields every input is clamped
	-- to 0..1 and custom-toggle templates stay at their authored values.
	local jetFloor = math.clamp(tonumber(state.JetFloor) or 1, 0, 1)
	local boostCeiling = math.clamp(tonumber(state.BoostCeiling) or 1, 1, 2)

	local now = os.clock()
	local flashUntil = self.FlashUntil or 0
	-- Previews switch lights off when several are shown at once (set by the caller).
	local noLights = state.NoLights == true

	if self.HasV2 then
		-- A failure here must not stop the rest of the vehicle's effects.
		local ok, message = pcall(updateV2, self, stepSeconds, state, now, visible)
		if not ok then
			-- Do not leave the plume, pads or lights held at their last level.
			for key in pairs(self.Channels) do
				-- Engine and drift channels fall back to the plain inputs instead.
				local passThrough = key == "EngineThrust" or key == "DriftLeft" or key == "DriftRight"
				self.Channels[key] = (not passThrough) and 0 or nil
			end
			if not self.V2Warned then
				self.V2Warned = true
				warn("[VehicleVFX] Exotic V2 update failed: " .. tostring(message))
			end
		end
	end

	for _, record in ipairs(self.Items) do
		local object = record.Object
		if object and object.Parent then
			if record.FlashRestore then
				-- A backfire flash owns this effect until it ends; then the saved
				-- values are restored and the normal drive resumes on this tick.
				if now < flashUntil then continue end
				restoreFlash(record)
			end
			if isThrustFireObject(object) then
				applyThrustFireColour(object, thrustColor)
			end
			local ceiling = record.Group == "Boost" and boostCeiling or (record.V2 and V2_CHANNEL_CEILING or 1)
			local drive = visible and math.clamp(intensityForGroup(self, record.Group, state), 0, ceiling) or 0
			if noLights and record.V2 and record.IsLight then
				drive = 0
			end
			local intensity = drive
			if self.IsMobile then
				intensity *= record.Settings.MobileScale
			end

			local active = intensity > 0.05
			object.Enabled = active

			if active and record.CustomToggle then
				local jetScale = drive >= 1 and drive or (jetFloor + (1 - jetFloor) * drive)
				if math.abs(jetScale - record.JetScale) > 0.01 then
					record.JetScale = jetScale
					if record.BaseRate then
						object.Rate = record.BaseRate * jetScale
					elseif record.BaseWidth0 then
						object.Width0 = record.BaseWidth0 * jetScale
						object.Width1 = record.BaseWidth1 * jetScale
					elseif record.BaseBrightness then
						object.Brightness = record.BaseBrightness * jetScale
						object.Range = record.BaseRange * jetScale
					end
				end
			end

			if active and not record.CustomToggle then
				-- Category variants (EngineJet_Exotic and so on) scale from their
				-- RateMin/Width0Min, which default to 0. With JetFloor passed, a jet
				-- group that is on never drops below the floor.
				local shaped = drive
				if jetFloor < 1 and drive < 1 and JET_FLOOR_GROUPS[record.Group] then
					shaped = jetFloor + (1 - jetFloor) * drive
					intensity = shaped
					if self.IsMobile then
						intensity *= record.Settings.MobileScale
					end
				end
				if record.V2 then
					-- Exotic V2 extras, all optional per effect: flicker, flame
					-- length through particle speed, and emitter / beam brightness.
					if record.Flicker then
						intensity *= 1 - record.Flicker * math.clamp(0.5 + math.noise(now * record.FlickerHz, record.Seed), 0, 1)
					end
					if record.SpeedScaleMax and record.SpeedScaleMin and record.BaseSpeed then
						local speedScale = record.SpeedScaleMin + (record.SpeedScaleMax - record.SpeedScaleMin) * math.min(shaped, V2_MOVER_CEILING)
						if math.abs(speedScale - record.LastSpeedScale) > 0.03 then
							record.LastSpeedScale = speedScale
							object.Speed = NumberRange.new(record.BaseSpeed.Min * speedScale, record.BaseSpeed.Max * speedScale)
						end
					end
					if record.GlowMax and record.GlowMin then
						local glow = record.GlowMin + (record.GlowMax - record.GlowMin) * intensity
						if math.abs(glow - (record.LastGlow or -1)) > 0.02 then
							record.LastGlow = glow
							object.Brightness = glow
						end
					end
				end
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

	-- Exotic V2 beam ends: jet length follows the channel (empty on other vehicles).
	for _, mover in ipairs(self.Movers) do
		local object = mover.Object
		if object and object.Parent then
			local value = visible and math.clamp(intensityForGroup(self, mover.Group, state), 0, V2_MOVER_CEILING) or 0
			if jetFloor < 1 and value > 0.05 and value < 1 and JET_FLOOR_GROUPS[mover.Group] then
				value = jetFloor + (1 - jetFloor) * value
			end
			if math.abs(value - mover.Last) > 0.01 then
				mover.Last = value
				local base = mover.Base
				object.Position = Vector3.new(base.X, base.Y, mover.ZMin + (mover.ZMax - mover.ZMin) * value)
			end
		end
	end
end

-- Exotic V2 backfire: fireball puffs and sparks from the boost jets, a flame
-- tongue on a bang, and a flash through the V2BoostLight channel.
local function v2Backfire(self, count, flashSeconds, strength)
	strength = math.clamp(tonumber(strength) or 0.5, 0, 1)
	-- count is the caller's configured particle total (crackle 4..8, bang 14..24);
	-- 12 is the count at which each emitter fires its authored BurstCount.
	local scale = math.clamp((tonumber(count) or 6) / 12, 0.25, 2)
	local emitted = emitV2Burst(self, "Backfire", scale)
	if strength >= 0.8 then
		emitted += emitV2Burst(self, "BackfireBang", scale)
	end
	local v2 = self.V2
	v2.PopFlash = math.max(v2.PopFlash, 0.5 + 1.2 * strength)
	v2.PopTau = math.clamp((tonumber(flashSeconds) or 0.08) * 0.6, 0.03, 0.3)
	return emitted
end

-- One-off burst on this vehicle's existing emitters. kind is "Sparks"
-- (BrakeSparks template) or "Dust" (HoverDust template); count is the desktop
-- particle total, shared between the matching emitters. Returns the number emitted.
function VehicleVFXController:Burst(kind, count)
	if self.Destroyed or not self:Visible() then return 0 end
	count = tonumber(count) or 0
	if count ~= count or count <= 0 then return 0 end
	if kind == "Dust" and self.HasV2 then
		-- Exotic V2: a landing also surges the hover jets (count is 6..28).
		self.V2.LandPulse = math.clamp(count / 28, 0.3, 1)
	end

	local quality = self.IsMobile and self.Globals.MobileParticleScale or self.Globals.DesktopParticleScale
	local total = count * (tonumber(quality) or 1)
	local cap = tonumber(self.Globals.MaxRecommendedParticlesPerVehicle) or 0
	if cap > 0 then
		total = math.min(total, cap)
	end

	-- Each emitter takes an equal share unless it carries a BurstShare weight (V2).
	local emitters = 0
	for _, record in ipairs(self.Items) do
		if record.BurstKind == kind and record.Object and record.Object.Parent then
			emitters += record.BurstShare or 1
		end
	end
	if emitters <= 0 then return 0 end

	local emitted = 0
	for _, record in ipairs(self.Items) do
		local object = record.Object
		if record.BurstKind == kind and object and object.Parent then
			local share = total * (record.BurstShare or 1) / emitters
			if self.IsMobile then
				share *= record.Settings.MobileScale
			end
			local amount = math.floor(share + 0.5)
			if amount >= 1 then
				object:Emit(amount)
				emitted += amount
			end
		end
	end
	return emitted
end

-- Backfire: a short fireball from the rear jets on an exhaust pop or bang.
-- Emits from the Boost-group emitters already attached (engine-jet emitters
-- when the vehicle has no boost emitters) and flashes the Boost-group lights
-- and beams (engine-jet ones when there are none) for flashSeconds, then
-- restores them. Creates nothing; does nothing when there is nothing to use.
-- count is the desktop particle total. Returns the number of particles emitted.
-- strength (optional, 0..1) is the pop strength; Exotic V2 vehicles use it.
function VehicleVFXController:Backfire(count, flashSeconds, flashGain, strength)
	if self.Destroyed or not self:Visible() then return 0 end
	if self.HasV2Backfire then
		return v2Backfire(self, count, flashSeconds, strength)
	end
	count = tonumber(count) or 0
	if count ~= count or count < 0 then count = 0 end

	local boostEmitters, engineEmitters, boostFlashers, engineFlashers = 0, 0, 0, 0
	for _, record in ipairs(self.Items) do
		local object = record.Object
		if object and object.Parent then
			local boostGroup = BACKFIRE_BOOST_GROUPS[record.Group]
			local engineGroup = BACKFIRE_ENGINE_GROUPS[record.Group]
			if boostGroup or engineGroup then
				if object:IsA("ParticleEmitter") then
					if boostGroup then boostEmitters += 1 else engineEmitters += 1 end
				elseif record.BaseBrightness or record.BaseWidth0 then
					if boostGroup then boostFlashers += 1 else engineFlashers += 1 end
				end
			end
		end
	end

	local emitGroups = (boostEmitters > 0 and BACKFIRE_BOOST_GROUPS) or (engineEmitters > 0 and BACKFIRE_ENGINE_GROUPS) or nil
	local emitters = boostEmitters > 0 and boostEmitters or engineEmitters
	local flashGroups = (boostFlashers > 0 and BACKFIRE_BOOST_GROUPS) or (engineFlashers > 0 and BACKFIRE_ENGINE_GROUPS) or nil

	local emitted = 0
	if emitGroups and count > 0 then
		local quality = self.IsMobile and self.Globals.MobileParticleScale or self.Globals.DesktopParticleScale
		local total = count * (tonumber(quality) or 1)
		local cap = tonumber(self.Globals.MaxRecommendedParticlesPerVehicle) or 0
		if cap > 0 then
			total = math.min(total, cap)
		end
		for _, record in ipairs(self.Items) do
			local object = record.Object
			if emitGroups[record.Group] and object and object.Parent and object:IsA("ParticleEmitter") then
				local share = total / emitters
				if self.IsMobile then
					share *= record.Settings.MobileScale
				end
				local amount = math.floor(share + 0.5)
				if amount >= 1 then
					object:Emit(amount)
					emitted += amount
				end
			end
		end
	end

	flashSeconds = math.clamp(tonumber(flashSeconds) or 0, 0, 0.5)
	if flashGroups and flashSeconds > 0 then
		local gain = math.clamp(tonumber(flashGain) or 1, 1, 4)
		self.FlashUntil = math.max(self.FlashUntil or 0, os.clock() + flashSeconds)
		for _, record in ipairs(self.Items) do
			local object = record.Object
			if flashGroups[record.Group] and object and object.Parent and (record.BaseBrightness or record.BaseWidth0) then
				if not record.FlashRestore then
					record.FlashRestore = {
						Enabled = object.Enabled,
						Brightness = record.BaseBrightness and object.Brightness or nil,
						Width0 = record.BaseWidth0 and object.Width0 or nil,
						Width1 = record.BaseWidth0 and object.Width1 or nil,
					}
				end
				if record.BaseBrightness then
					object.Brightness = record.BaseBrightness * gain
				else
					object.Width0 = record.BaseWidth0 * gain
					object.Width1 = record.BaseWidth1 * gain
				end
				object.Enabled = true
			end
		end
	end

	return emitted
end

function VehicleVFXController:Destroy()
	self.Destroyed = true
	for _, record in ipairs(self.Items) do
		if record.FlashRestore then
			restoreFlash(record)
		end
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
	self.Movers = {}
	self.GroundSnaps = {}
	self.GroundPoint = nil
	self.GroundLightPoint = nil
	self.ImpactPoint = nil
end

return VehicleVFXController

