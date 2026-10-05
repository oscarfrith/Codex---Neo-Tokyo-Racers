-- Exotic V2 vehicle VFX templates (hover feel, VFX rework).
--
-- Returns function(textures) -> { Folder, ... }. Every Folder is an unparented
-- template for ReplicatedStorage.Assets.VFX.VehicleTemplates. Pure instance
-- construction: no requires, no services, no yields.
--
-- `textures` maps a texture name to an "rbxassetid://..." string. Any name may be
-- missing; the effect then uses a texture the existing templates already use and
-- drops its flipbook layout, so it still shows.
--
-- Conventions the driver (VehiclePreviewVFXClient) reads:
--   Folder/Settings            MobileScale (NumberValue), EnabledOnMobile (BoolValue)
--   Part TemplateHost_Invisible  one host part per template; +Z is "out of the jet"
--   VFXGroup (string)          the input channel that drives the effect
--   RateMin/RateMax, Width0Min/Max, Width1Min/Max, BrightnessMin/Max, RangeMin/Max
--                              value at channel 0 and at channel 1 (existing convention)
--   GlowMin/GlowMax            ParticleEmitter.Brightness / Beam.Brightness at 0 and 1
--   SpeedScaleMin/Max          multiplier on the authored Speed range at 0 and 1
--   ZMin/ZMax (on an Attachment, with VFXGroup)  the attachment's Z at 0 and 1 (beam length)
--   Flicker, FlickerHz         fraction of the drive removed by noise, and its rate
--   TintStart/TintEnd          blend toward the vehicle's thrust colour at the start and
--                              end of the colour sequence (0 = authored, 1 = thrust colour)
--   WorldSpace = true          particles stay in the world (not locked to the car)
--   VFXBurst (string)          burst kind for ParticleEmitter:Emit; "None" = never burst
--   BurstCount                 particles at burst strength 1 (kinds fired by strength)
--   BurstShare                 weight when a counted burst is split between emitters
--   VFXTier = "Full"           dropped on remote players' vehicles
--   DesktopOnly = true         dropped on mobile
--   GroundTint = true          colour follows the ground under the car
--
-- Effect names must never contain "engineon", "engineoff", "booston" or
-- "stabiliseron": VehicleVFXClient toggles and recolours anything so named.

-- ---------------------------------------------------------------------------
-- Tuning constants
-- ---------------------------------------------------------------------------

local MOBILE_SCALE_JET = 0.7
local MOBILE_SCALE_HOVER = 0.6
local MOBILE_SCALE_SPARKS = 0.6

-- Engine jet (four per car). Existing Exotic jet: 5 studs long, about 1.3 wide.
local ENGINE_CORE_LENGTH_MIN = 1.4
local ENGINE_CORE_LENGTH_MAX = 4.6
local ENGINE_FLAME_LENGTH_MIN = 2.0
local ENGINE_FLAME_LENGTH_MAX = 5.4
local ENGINE_SHEATH_LENGTH_MIN = 2.6
local ENGINE_SHEATH_LENGTH_MAX = 6.4
local ENGINE_FLAME_RATE = 36
local ENGINE_IDLE_RATE = 14
local ENGINE_EMBER_RATE = 8
local ENGINE_LIGHT_BRIGHTNESS = 2.2
local ENGINE_LIGHT_RANGE = 11

-- Boost jet (two or three per car). Existing Exotic boost: 7 studs long, 1.8 wide.
local BOOST_CORE_LENGTH_MIN = 2.5
local BOOST_CORE_LENGTH_MAX = 6.0
local BOOST_FLAME_LENGTH_MIN = 3.0
local BOOST_FLAME_LENGTH_MAX = 7.0
local BOOST_FLAME_RATE = 52
local BOOST_EMBER_RATE = 36
local BOOST_ARC_RATE = 18
local BOOST_SMOKE_RATE = 14
local BOOST_INTAKE_RATE = 90
local BOOST_LIGHT_BRIGHTNESS = 3
local BOOST_LIGHT_RANGE = 14
local BOOST_IGNITE_FIREBALLS = 3
local BOOST_IGNITE_EMBERS = 14
local BACKFIRE_PUFFS = 2
local BACKFIRE_SPARKS = 7
local BACKFIRE_TONGUES = 5

-- Stabiliser jet (four per car). Existing: 1.5 studs long, 1 wide.
local STAB_LENGTH_MIN = 0.7
local STAB_LENGTH_MAX = 2.0
local STAB_FLAME_RATE = 30
local STAB_SPARK_RATE = 45
local STAB_CHARGE_GLOW_RATE = 16
local STAB_CHARGE_ARC_RATE = 12
local STAB_RELEASE_ARCS = 4

-- Hover pad (five per car) and ground effects (one per car).
local PAD_SIZE = 3.0
local PAD_TIGHT_SIZE = 2.0
local PAD_COLUMN_LENGTH = 1.5
local PAD_DISC_RATE = 10
local GROUND_DUST_RATE = 70
local GROUND_MIST_RATE = 16
local GROUND_GLOW_SIZE = 12
local GROUND_LIGHT_BRIGHTNESS = 2.6
local GROUND_LIGHT_RANGE = 18

-- Impact and scrape sparks (one runtime source on the local car).
local SCRAPE_SPARK_RATE = 70

-- Speed trails (local car).
local VAPOUR_LIFETIME = 0.35
local TAIL_RIBBON_LIFETIME = 0.55

-- Fallback textures: ids already used by the live templates.
local FALLBACK_FIRE = "rbxassetid://5077876271"
local FALLBACK_BEAM = "rbxassetid://7216853129"
local FALLBACK_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FALLBACK_SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local TEXTURE_FALLBACKS = {
	fire_loop = FALLBACK_FIRE,
	fireball_burst = FALLBACK_FIRE,
	smoke_puff = FALLBACK_SMOKE,
	dust_wisp = FALLBACK_SMOKE,
	arc_flipbook = FALLBACK_SPARK,
	shock_ring = FALLBACK_FIRE,
	glow_soft = FALLBACK_FIRE,
	hover_pad = FALLBACK_FIRE,
	spark_streak = FALLBACK_SPARK,
	ember = FALLBACK_SPARK,
	jet_core = FALLBACK_BEAM,
	shock_diamonds = FALLBACK_BEAM,
	heat_streak = FALLBACK_BEAM,
	energy_ribbon = FALLBACK_BEAM,
}

-- Flipbook grid of each sheet. Only applied when the real texture is present.
local FLIPBOOK_LAYOUTS = {
	fire_loop = Enum.ParticleFlipbookLayout.Grid8x8,
	fireball_burst = Enum.ParticleFlipbookLayout.Grid8x8,
	smoke_puff = Enum.ParticleFlipbookLayout.Grid8x8,
	dust_wisp = Enum.ParticleFlipbookLayout.Grid4x4,
	arc_flipbook = Enum.ParticleFlipbookLayout.Grid4x4,
}

-- Palettes (RGB 0..255).
local WHITE = { 255, 255, 255 }
local FIRE_CORE = { 255, 244, 214 }
local FIRE_MID = { 255, 170, 60 }
local FIRE_EDGE = { 230, 70, 20 }
local FIRE_DARK = { 90, 22, 10 }
local SPARK_HOT = { 255, 236, 170 }
local SPARK_COOL = { 255, 120, 40 }
local SMOKE_LIGHT = { 120, 116, 112 }
local SMOKE_DARK = { 46, 44, 44 }
local DUST_LIGHT = { 200, 192, 172 }
local DUST_DARK = { 128, 120, 104 }

return function(textures)
	textures = textures or {}

	-- -----------------------------------------------------------------------
	-- Value helpers
	-- -----------------------------------------------------------------------

	local function rgb(triple)
		return Color3.fromRGB(triple[1], triple[2], triple[3])
	end

	-- colours({ {0, FIRE_CORE}, {0.4, FIRE_MID}, {1, FIRE_DARK} })
	local function colours(points)
		local keypoints = {}
		for index, point in ipairs(points) do
			keypoints[index] = ColorSequenceKeypoint.new(point[1], rgb(point[2]))
		end
		return ColorSequence.new(keypoints)
	end

	-- numbers({ {0, 1}, {0.5, 2}, {1, 0} })
	local function numbers(points)
		local keypoints = {}
		for index, point in ipairs(points) do
			keypoints[index] = NumberSequenceKeypoint.new(point[1], point[2])
		end
		return NumberSequence.new(keypoints)
	end

	local function textureId(name)
		local id = textures[name]
		if type(id) == "string" and id ~= "" then
			return id, true
		end
		return TEXTURE_FALLBACKS[name] or FALLBACK_FIRE, false
	end

	local function setAttributes(instance, attributes)
		if not attributes then return end
		for key, value in pairs(attributes) do
			instance:SetAttribute(key, value)
		end
	end

	-- -----------------------------------------------------------------------
	-- Instance helpers
	-- -----------------------------------------------------------------------

	local function newTemplate(name, description, mobileScale)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder:SetAttribute("VFXTemplate", true)
		folder:SetAttribute("VFXVersion", 2)
		folder:SetAttribute("InstalledBy", "hover_feel/vfx_exotic_v2")
		folder:SetAttribute("Description", description)

		local settings = Instance.new("Folder")
		settings.Name = "Settings"
		settings.Parent = folder

		local mobile = Instance.new("NumberValue")
		mobile.Name = "MobileScale"
		mobile.Value = mobileScale
		mobile.Parent = settings

		local enabledOnMobile = Instance.new("BoolValue")
		enabledOnMobile.Name = "EnabledOnMobile"
		enabledOnMobile.Value = true
		enabledOnMobile.Parent = settings

		local host = Instance.new("Part")
		host.Name = "TemplateHost_Invisible"
		host.Size = Vector3.new(1, 1, 1)
		host.Anchored = true
		host.CanCollide = false
		host.CanTouch = false
		host.CanQuery = false
		host.CastShadow = false
		host.Massless = true
		host.Transparency = 1
		host.CFrame = CFrame.new()
		host.Parent = folder

		return folder, host
	end

	local function newAttachment(host, name, position, attributes)
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = position
		setAttributes(attachment, attributes)
		attachment.Parent = host
		return attachment
	end

	-- A particle emitter. `texture` is a texture name; `flipbook` is nil or
	-- { Mode = Enum.ParticleFlipbookMode.X, Framerate = NumberRange, StartRandom = bool }.
	local function newEmitter(parent, name, texture, flipbook, properties, attributes)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = name
		emitter.Enabled = false
		emitter.Rate = 0
		emitter.LightInfluence = 0
		emitter.LightEmission = 1
		emitter.LockedToPart = true
		emitter.VelocityInheritance = 0
		emitter.Drag = 0
		emitter.Acceleration = Vector3.new(0, 0, 0)
		emitter.EmissionDirection = Enum.NormalId.Back
		emitter.SpreadAngle = Vector2.new(0, 0)
		emitter.Rotation = NumberRange.new(0, 0)
		emitter.RotSpeed = NumberRange.new(0, 0)
		emitter.Orientation = Enum.ParticleOrientation.FacingCamera

		local id, isReal = textureId(texture)
		emitter.Texture = id
		local layout = FLIPBOOK_LAYOUTS[texture]
		if isReal and layout and flipbook then
			emitter.FlipbookLayout = layout
			emitter.FlipbookMode = flipbook.Mode
			if flipbook.Framerate then
				emitter.FlipbookFramerate = flipbook.Framerate
			end
			emitter.FlipbookStartRandom = flipbook.StartRandom == true
		end

		for key, value in pairs(properties) do
			emitter[key] = value
		end
		setAttributes(emitter, attributes)
		emitter.Parent = parent
		return emitter
	end

	-- A beam between two attachments of the same host. Tileable textures wrap
	-- along the beam, so a longer jet shows more texture instead of stretching it.
	local function newBeam(from, to, name, texture, properties, attributes)
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Enabled = false
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.FaceCamera = true
		beam.LightInfluence = 0
		beam.LightEmission = 1
		beam.Segments = 4
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.Texture = (textureId(texture))
		for key, value in pairs(properties) do
			beam[key] = value
		end
		setAttributes(beam, attributes)
		beam.Parent = from
		return beam
	end

	local function newLight(parent, name, properties, attributes)
		local light = Instance.new("PointLight")
		light.Name = name
		light.Enabled = false
		light.Shadows = false
		light.Color = rgb(FIRE_MID)
		for key, value in pairs(properties) do
			light[key] = value
		end
		setAttributes(light, attributes)
		light.Parent = parent
		return light
	end

	local function newTrail(host, from, to, name, texture, properties, attributes)
		local trail = Instance.new("Trail")
		trail.Name = name
		trail.Enabled = false
		trail.Attachment0 = from
		trail.Attachment1 = to
		trail.FaceCamera = true
		trail.LightInfluence = 0
		trail.LightEmission = 1
		trail.MinLength = 0.1
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Texture = (textureId(texture))
		for key, value in pairs(properties) do
			trail[key] = value
		end
		setAttributes(trail, attributes)
		trail.Parent = host
		return trail
	end

	-- Shared flipbook settings.
	local FLAME_LOOP = { Mode = Enum.ParticleFlipbookMode.Loop, Framerate = NumberRange.new(24, 30), StartRandom = true }
	local ONE_SHOT = { Mode = Enum.ParticleFlipbookMode.OneShot, StartRandom = false }
	local DUST_LOOP = { Mode = Enum.ParticleFlipbookMode.Loop, Framerate = NumberRange.new(10, 16), StartRandom = true }
	local ARC_RANDOM = { Mode = Enum.ParticleFlipbookMode.Random, Framerate = NumberRange.new(18, 26), StartRandom = true }

	local FIRE_COLOURS = colours({ { 0, FIRE_CORE }, { 0.3, FIRE_MID }, { 0.7, FIRE_EDGE }, { 1, FIRE_DARK } })
	local SPARK_COLOURS = colours({ { 0, SPARK_HOT }, { 1, SPARK_COOL } })
	local SMOKE_COLOURS = colours({ { 0, SMOKE_LIGHT }, { 1, SMOKE_DARK } })
	local DUST_COLOURS = colours({ { 0, DUST_LIGHT }, { 1, DUST_DARK } })
	local WHITE_COLOURS = colours({ { 0, WHITE }, { 1, WHITE } })

	-- -----------------------------------------------------------------------
	-- EngineJet_ExoticV2
	-- Hot core with shock diamonds whose length follows thrust, a flipbook flame
	-- body, a soft heat sheath, an ion rim in the thrust colour, a faint idle
	-- flicker and a light that breathes with thrust.
	-- -----------------------------------------------------------------------
	local function buildEngineJet()
		local folder, host = newTemplate(
			"EngineJet_ExoticV2",
			"Exotic V2 engine jet: core, shock diamonds, flame body, heat sheath, ion rim, idle flicker, light.",
			MOBILE_SCALE_JET
		)

		local nozzle = newAttachment(host, "Nozzle", Vector3.new(0, 0, -0.3))
		local coreEnd = newAttachment(host, "CoreEnd", Vector3.new(0, 0, ENGINE_CORE_LENGTH_MAX), {
			VFXGroup = "EngineThrust",
			ZMin = ENGINE_CORE_LENGTH_MIN,
			ZMax = ENGINE_CORE_LENGTH_MAX,
		})
		local flameEnd = newAttachment(host, "FlameEnd", Vector3.new(0, 0, ENGINE_FLAME_LENGTH_MAX), {
			VFXGroup = "EngineThrust",
			ZMin = ENGINE_FLAME_LENGTH_MIN,
			ZMax = ENGINE_FLAME_LENGTH_MAX,
		})
		local sheathEnd = newAttachment(host, "SheathEnd", Vector3.new(0, 0, ENGINE_SHEATH_LENGTH_MAX), {
			VFXGroup = "EngineThrust",
			ZMin = ENGINE_SHEATH_LENGTH_MIN,
			ZMax = ENGINE_SHEATH_LENGTH_MAX,
		})

		newBeam(nozzle, coreEnd, "JetCore", "jet_core", {
			Width0 = 0.55,
			Width1 = 0.1,
			Brightness = 3,
			TextureLength = 3,
			TextureSpeed = 6,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0.05 }, { 0.7, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "EngineThrust",
			Width0Min = 0.24,
			Width0Max = 0.55,
			Width1Min = 0.05,
			Width1Max = 0.1,
			GlowMin = 1.5,
			GlowMax = 3.5,
			TintStart = 0.3,
			TintEnd = 0.85,
			Flicker = 0.08,
			FlickerHz = 19,
		})

		newBeam(nozzle, flameEnd, "ShockDiamonds", "shock_diamonds", {
			Width0 = 0.95,
			Width1 = 0.4,
			Brightness = 2,
			TextureLength = 1.6,
			TextureSpeed = 0.35,
			Color = colours({ { 0, FIRE_CORE }, { 1, FIRE_MID } }),
			Transparency = numbers({ { 0, 0.35 }, { 0.6, 0.55 }, { 1, 1 } }),
		}, {
			VFXGroup = "EngineThrust",
			Width0Min = 0.45,
			Width0Max = 0.95,
			Width1Min = 0.2,
			Width1Max = 0.4,
			TintStart = 0.25,
			TintEnd = 0.6,
		})

		newBeam(nozzle, sheathEnd, "HeatSheath", "heat_streak", {
			Width0 = 1.5,
			Width1 = 0.9,
			Brightness = 1,
			LightEmission = 0.7,
			TextureLength = 2.4,
			TextureSpeed = 4,
			Color = colours({ { 0, FIRE_MID }, { 1, FIRE_EDGE } }),
			Transparency = numbers({ { 0, 0.8 }, { 0.3, 0.72 }, { 1, 1 } }),
		}, {
			VFXGroup = "EngineThrust",
			VFXTier = "Full",
			Width0Min = 0.8,
			Width0Max = 1.5,
			Width1Min = 0.5,
			Width1Max = 0.9,
			TintStart = 0.1,
			TintEnd = 0.35,
			Flicker = 0.2,
			FlickerHz = 11,
		})

		newBeam(nozzle, flameEnd, "IonRim", "energy_ribbon", {
			Width0 = 1.25,
			Width1 = 0.5,
			Brightness = 2,
			TextureLength = 2,
			TextureSpeed = 9,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0.5 }, { 0.5, 0.7 }, { 1, 1 } }),
		}, {
			VFXGroup = "EngineThrust",
			Width0Min = 0.7,
			Width0Max = 1.25,
			Width1Min = 0.3,
			Width1Max = 0.5,
			TintStart = 1,
			TintEnd = 1,
		})

		newEmitter(nozzle, "FlameBody", "fire_loop", FLAME_LOOP, {
			Rate = ENGINE_FLAME_RATE,
			Lifetime = NumberRange.new(0.16, 0.24),
			Speed = NumberRange.new(15, 21),
			SpreadAngle = Vector2.new(3, 3),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Brightness = 2,
			LightEmission = 0.9,
			Color = FIRE_COLOURS,
			Size = numbers({ { 0, 0.7 }, { 0.3, 1.15 }, { 1, 0.45 } }),
			Transparency = numbers({ { 0, 0.35 }, { 0.2, 0.15 }, { 0.7, 0.5 }, { 1, 1 } }),
		}, {
			VFXGroup = "EngineThrust",
			VFXBurst = "None",
			RateMin = 10,
			RateMax = ENGINE_FLAME_RATE,
			SpeedScaleMin = 0.45,
			SpeedScaleMax = 1,
			TintStart = 0.45,
			TintEnd = 0,
		})

		newEmitter(nozzle, "IdleFlicker", "fire_loop", FLAME_LOOP, {
			Rate = ENGINE_IDLE_RATE,
			Lifetime = NumberRange.new(0.1, 0.16),
			Speed = NumberRange.new(4, 7),
			SpreadAngle = Vector2.new(6, 6),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Brightness = 1.4,
			Color = FIRE_COLOURS,
			Size = numbers({ { 0, 0.3 }, { 0.4, 0.55 }, { 1, 0.1 } }),
			Transparency = numbers({ { 0, 0.5 }, { 0.3, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2Idle",
			VFXBurst = "None",
			RateMin = 0,
			RateMax = ENGINE_IDLE_RATE,
			TintStart = 0.55,
			TintEnd = 0.1,
			Flicker = 0.5,
			FlickerHz = 9,
		})

		newEmitter(nozzle, "NozzleGlow", "glow_soft", nil, {
			Rate = 12,
			Lifetime = NumberRange.new(0.1, 0.14),
			Speed = NumberRange.new(0.2, 0.4),
			Brightness = 1.5,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 0.9 }, { 1, 1.2 } }),
			Transparency = numbers({ { 0, 0.55 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2Idle",
			VFXBurst = "None",
			RateMin = 0,
			RateMax = 12,
			GlowMin = 0.6,
			GlowMax = 1.5,
			TintStart = 1,
			TintEnd = 1,
			Flicker = 0.25,
			FlickerHz = 6,
		})

		newEmitter(nozzle, "Embers", "ember", nil, {
			Rate = ENGINE_EMBER_RATE,
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(18, 30),
			SpreadAngle = Vector2.new(9, 9),
			Drag = 1.2,
			Acceleration = Vector3.new(0, -8, 0),
			LockedToPart = false,
			Brightness = 2,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.1 }, { 1, 0.03 } }),
			Transparency = numbers({ { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "EngineThrust",
			VFXBurst = "None",
			VFXTier = "Full",
			WorldSpace = true,
			RateMin = 0,
			RateMax = ENGINE_EMBER_RATE,
		})

		newLight(nozzle, "ThrustLight", {
			Brightness = ENGINE_LIGHT_BRIGHTNESS,
			Range = ENGINE_LIGHT_RANGE,
		}, {
			VFXGroup = "EngineThrust",
			VFXTier = "Full",
			DesktopOnly = true,
			BrightnessMin = 0.3,
			BrightnessMax = ENGINE_LIGHT_BRIGHTNESS,
			RangeMin = 5,
			RangeMax = ENGINE_LIGHT_RANGE,
			TintStart = 0.6,
			Flicker = 0.15,
			FlickerHz = 3,
		})

		return folder
	end

	-- -----------------------------------------------------------------------
	-- BoostJet_ExoticV2
	-- Sustained plume (core, diamonds, sheath, flame, embers, arcs, light) and the
	-- one-shot pieces of the ignition sequence, the sputter-out smoke, and the
	-- backfire puffs fired on exhaust pops. The driver times the sequence.
	-- -----------------------------------------------------------------------
	local function buildBoostJet()
		local folder, host = newTemplate(
			"BoostJet_ExoticV2",
			"Exotic V2 boost jet: ignition sequence, sustained plume with arcs, sputter-out, backfire.",
			MOBILE_SCALE_JET
		)

		local nozzle = newAttachment(host, "Nozzle", Vector3.new(0, 0, -0.4))
		local intakePoint = newAttachment(host, "IntakePoint", Vector3.new(0, 0, 2.6))
		local coreEnd = newAttachment(host, "CoreEnd", Vector3.new(0, 0, BOOST_CORE_LENGTH_MAX), {
			VFXGroup = "V2BoostPlume",
			ZMin = BOOST_CORE_LENGTH_MIN,
			ZMax = BOOST_CORE_LENGTH_MAX,
		})
		local flameEnd = newAttachment(host, "FlameEnd", Vector3.new(0, 0, BOOST_FLAME_LENGTH_MAX), {
			VFXGroup = "V2BoostPlume",
			ZMin = BOOST_FLAME_LENGTH_MIN,
			ZMax = BOOST_FLAME_LENGTH_MAX,
		})

		-- Sustained plume ------------------------------------------------------
		newBeam(nozzle, coreEnd, "PlumeCore", "jet_core", {
			Width0 = 0.95,
			Width1 = 0.2,
			Brightness = 4,
			TextureLength = 4,
			TextureSpeed = 9,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0 }, { 0.75, 0.25 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2BoostPlume",
			Width0Min = 0.4,
			Width0Max = 0.95,
			Width1Min = 0.08,
			Width1Max = 0.2,
			GlowMin = 2,
			GlowMax = 4.5,
			TintStart = 0.3,
			TintEnd = 0.85,
			Flicker = 0.1,
			FlickerHz = 23,
		})

		newBeam(nozzle, flameEnd, "PlumeDiamonds", "shock_diamonds", {
			Width0 = 1.5,
			Width1 = 0.6,
			Brightness = 2.5,
			TextureLength = 2.1,
			TextureSpeed = 0.5,
			Color = colours({ { 0, FIRE_CORE }, { 1, FIRE_MID } }),
			Transparency = numbers({ { 0, 0.25 }, { 0.65, 0.5 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2BoostPlume",
			Width0Min = 0.7,
			Width0Max = 1.5,
			Width1Min = 0.3,
			Width1Max = 0.6,
			TintStart = 0.25,
			TintEnd = 0.6,
		})

		newBeam(nozzle, flameEnd, "PlumeSheath", "heat_streak", {
			Width0 = 2.3,
			Width1 = 1.3,
			Brightness = 1,
			LightEmission = 0.7,
			TextureLength = 3,
			TextureSpeed = 6,
			Color = colours({ { 0, FIRE_MID }, { 1, FIRE_EDGE } }),
			Transparency = numbers({ { 0, 0.75 }, { 0.3, 0.68 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2BoostPlume",
			VFXTier = "Full",
			Width0Min = 1.2,
			Width0Max = 2.3,
			Width1Min = 0.7,
			Width1Max = 1.3,
			TintStart = 0.1,
			TintEnd = 0.4,
			Flicker = 0.25,
			FlickerHz = 13,
		})

		newEmitter(nozzle, "PlumeFlame", "fire_loop", FLAME_LOOP, {
			Rate = BOOST_FLAME_RATE,
			Lifetime = NumberRange.new(0.18, 0.28),
			Speed = NumberRange.new(27, 36),
			SpreadAngle = Vector2.new(4, 4),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Brightness = 2.6,
			LightEmission = 0.9,
			Color = FIRE_COLOURS,
			Size = numbers({ { 0, 1.0 }, { 0.3, 1.8 }, { 1, 0.7 } }),
			Transparency = numbers({ { 0, 0.3 }, { 0.2, 0.1 }, { 0.7, 0.45 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2BoostPlume",
			VFXBurst = "None",
			RateMin = 12,
			RateMax = BOOST_FLAME_RATE,
			SpeedScaleMin = 0.4,
			SpeedScaleMax = 1,
			TintStart = 0.45,
			TintEnd = 0,
		})

		newEmitter(nozzle, "PlumeEmbers", "ember", nil, {
			Rate = BOOST_EMBER_RATE,
			Lifetime = NumberRange.new(0.4, 0.9),
			Speed = NumberRange.new(25, 45),
			SpreadAngle = Vector2.new(12, 12),
			Drag = 2,
			Acceleration = Vector3.new(0, -10, 0),
			LockedToPart = false,
			Brightness = 2.5,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.13 }, { 1, 0.03 } }),
			Transparency = numbers({ { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2BoostPlume",
			VFXBurst = "None",
			VFXTier = "Full",
			WorldSpace = true,
			RateMin = 0,
			RateMax = BOOST_EMBER_RATE,
		})

		newEmitter(nozzle, "NozzleArcs", "arc_flipbook", ARC_RANDOM, {
			Rate = BOOST_ARC_RATE,
			Lifetime = NumberRange.new(0.06, 0.12),
			Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			Brightness = 3,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 1.3 }, { 1, 1.9 } }),
			Transparency = numbers({ { 0, 0.1 }, { 0.6, 0.2 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2BoostArcs",
			VFXBurst = "None",
			VFXTier = "Full",
			RateMin = 0,
			RateMax = BOOST_ARC_RATE,
			TintStart = 0.85,
			TintEnd = 1,
		})

		newLight(nozzle, "PlumeLight", {
			Brightness = BOOST_LIGHT_BRIGHTNESS,
			Range = BOOST_LIGHT_RANGE,
		}, {
			VFXGroup = "V2BoostLight",
			VFXTier = "Full",
			DesktopOnly = true,
			BrightnessMin = 0,
			BrightnessMax = BOOST_LIGHT_BRIGHTNESS,
			RangeMin = 8,
			RangeMax = BOOST_LIGHT_RANGE,
			TintStart = 0.5,
		})

		-- Ignition sequence ----------------------------------------------------
		-- Intake (0 to 100 ms): streaks rushing into the nozzle from behind it.
		newEmitter(intakePoint, "IntakeDraw", "glow_soft", nil, {
			Rate = BOOST_INTAKE_RATE,
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = NumberRange.new(0.09, 0.11),
			Speed = NumberRange.new(24, 30),
			SpreadAngle = Vector2.new(28, 28),
			Brightness = 2,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 0.3 }, { 1, 0.05 } }),
			Transparency = numbers({ { 0, 0.6 }, { 0.5, 0.1 }, { 1, 0.6 } }),
		}, {
			VFXGroup = "V2BoostIntake",
			VFXTier = "Full",
			VFXBurst = "None",
			RateMin = 0,
			RateMax = BOOST_INTAKE_RATE,
			TintStart = 1,
			TintEnd = 1,
		})

		-- Flash moment (100 ms): fireball, shock ring, ember spray.
		newEmitter(nozzle, "IgniteFireball", "fireball_burst", ONE_SHOT, {
			Lifetime = NumberRange.new(0.45, 0.6),
			Speed = NumberRange.new(6, 12),
			SpreadAngle = Vector2.new(14, 14),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
			Brightness = 3,
			LightEmission = 0.85,
			Color = colours({ { 0, FIRE_CORE }, { 0.35, FIRE_MID }, { 0.7, FIRE_EDGE }, { 1, SMOKE_DARK } }),
			Size = numbers({ { 0, 1.8 }, { 0.3, 3.4 }, { 1, 4.4 } }),
			Transparency = numbers({ { 0, 0.1 }, { 0.5, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "BoostIgnite",
			BurstCount = BOOST_IGNITE_FIREBALLS,
			TintStart = 0.35,
			TintEnd = 0,
		})

		newEmitter(nozzle, "IgniteRing", "shock_ring", nil, {
			Lifetime = NumberRange.new(0.22, 0.28),
			Speed = NumberRange.new(3, 3),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Brightness = 3,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 0.6 }, { 0.4, 3.8 }, { 1, 5.6 } }),
			Transparency = numbers({ { 0, 0.05 }, { 0.5, 0.4 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "BoostIgnite",
			BurstCount = 1,
			TintStart = 0.6,
			TintEnd = 0.9,
		})

		newEmitter(nozzle, "IgniteEmbers", "ember", nil, {
			Lifetime = NumberRange.new(0.35, 0.8),
			Speed = NumberRange.new(30, 60),
			SpreadAngle = Vector2.new(28, 28),
			Drag = 2.5,
			Acceleration = Vector3.new(0, -14, 0),
			LockedToPart = false,
			Brightness = 3,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.16 }, { 1, 0.03 } }),
			Transparency = numbers({ { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "BoostIgnite",
			VFXTier = "Full",
			WorldSpace = true,
			BurstCount = BOOST_IGNITE_EMBERS,
		})

		-- Sputter-out (after the boost ends): a little smoke left behind.
		newEmitter(nozzle, "SputterSmoke", "smoke_puff", ONE_SHOT, {
			Rate = BOOST_SMOKE_RATE,
			Lifetime = NumberRange.new(0.7, 1.1),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(16, 16),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-25, 25),
			Drag = 3,
			Acceleration = Vector3.new(0, 3, 0),
			LockedToPart = false,
			LightEmission = 0,
			LightInfluence = 1,
			Brightness = 1,
			Color = SMOKE_COLOURS,
			Size = numbers({ { 0, 1.1 }, { 1, 3.2 } }),
			Transparency = numbers({ { 0, 0.6 }, { 0.4, 0.72 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2BoostSmoke",
			VFXBurst = "None",
			VFXTier = "Full",
			WorldSpace = true,
			RateMin = 0,
			RateMax = BOOST_SMOKE_RATE,
		})

		-- Backfire (exhaust pops and bangs) -----------------------------------
		newEmitter(nozzle, "BackfirePuff", "fireball_burst", ONE_SHOT, {
			Lifetime = NumberRange.new(0.22, 0.32),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(10, 10),
			Rotation = NumberRange.new(0, 360),
			Brightness = 3,
			LightEmission = 0.9,
			Color = colours({ { 0, FIRE_CORE }, { 0.4, FIRE_MID }, { 0.8, FIRE_EDGE }, { 1, SMOKE_DARK } }),
			Size = numbers({ { 0, 0.8 }, { 0.4, 1.7 }, { 1, 2.1 } }),
			Transparency = numbers({ { 0, 0.1 }, { 0.6, 0.35 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXTier = "Full",
			VFXBurst = "Backfire",
			BurstCount = BACKFIRE_PUFFS,
			TintStart = 0.3,
			TintEnd = 0,
		})

		newEmitter(nozzle, "BackfireSparks", "spark_streak", nil, {
			Lifetime = NumberRange.new(0.15, 0.3),
			Speed = NumberRange.new(30, 55),
			SpreadAngle = Vector2.new(22, 22),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Drag = 2,
			Acceleration = Vector3.new(0, -30, 0),
			LockedToPart = false,
			Brightness = 3,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.4 }, { 1, 0.1 } }),
			Transparency = numbers({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXTier = "Full",
			VFXBurst = "Backfire",
			WorldSpace = true,
			BurstCount = BACKFIRE_SPARKS,
		})

		newEmitter(nozzle, "BackfireTongue", "fire_loop", FLAME_LOOP, {
			Lifetime = NumberRange.new(0.12, 0.18),
			Speed = NumberRange.new(20, 28),
			SpreadAngle = Vector2.new(5, 5),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Brightness = 3,
			Color = FIRE_COLOURS,
			Size = numbers({ { 0, 1.1 }, { 0.3, 2.0 }, { 1, 0.6 } }),
			Transparency = numbers({ { 0, 0.2 }, { 0.6, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXTier = "Full",
			VFXBurst = "BackfireBang",
			BurstCount = BACKFIRE_TONGUES,
			TintStart = 0.4,
			TintEnd = 0,
		})

		return folder
	end

	-- -----------------------------------------------------------------------
	-- StabiliserJet_ExoticLeftV2 / RightV2
	-- A short hard side thrust with a flame body, slide sparks, and a charge glow
	-- with arcs that builds with the drift charge and bursts on the mini-boost.
	-- The two sides differ only in their channels.
	-- -----------------------------------------------------------------------
	local function buildStabiliserJet(side)
		local folder, host = newTemplate(
			"StabiliserJet_Exotic" .. side .. "V2",
			"Exotic V2 stabiliser jet (" .. side .. "): side thrust, slide sparks, drift charge glow and arcs.",
			MOBILE_SCALE_JET
		)
		local driftGroup = "Drift" .. side
		local sparkGroup = "V2SlipSparks" .. side

		local nozzle = newAttachment(host, "Nozzle", Vector3.new(0, 0, -0.3))
		local thrustEnd = newAttachment(host, "ThrustEnd", Vector3.new(0, 0, STAB_LENGTH_MAX), {
			VFXGroup = driftGroup,
			ZMin = STAB_LENGTH_MIN,
			ZMax = STAB_LENGTH_MAX,
		})

		newBeam(nozzle, thrustEnd, "ThrustCore", "jet_core", {
			Width0 = 0.6,
			Width1 = 0.12,
			Brightness = 3.5,
			TextureLength = 1.5,
			TextureSpeed = 8,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0.05 }, { 0.7, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = driftGroup,
			Width0Min = 0.3,
			Width0Max = 0.6,
			Width1Min = 0.06,
			Width1Max = 0.12,
			TintStart = 0.3,
			TintEnd = 0.85,
			Flicker = 0.15,
			FlickerHz = 21,
		})

		newBeam(nozzle, thrustEnd, "ThrustRim", "energy_ribbon", {
			Width0 = 1.0,
			Width1 = 0.4,
			Brightness = 2,
			TextureLength = 1.2,
			TextureSpeed = 10,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0.45 }, { 0.5, 0.65 }, { 1, 1 } }),
		}, {
			VFXGroup = driftGroup,
			Width0Min = 0.5,
			Width0Max = 1.0,
			Width1Min = 0.2,
			Width1Max = 0.4,
			TintStart = 1,
			TintEnd = 1,
		})

		newEmitter(nozzle, "ThrustFlame", "fire_loop", FLAME_LOOP, {
			Rate = STAB_FLAME_RATE,
			Lifetime = NumberRange.new(0.1, 0.14),
			Speed = NumberRange.new(11, 15),
			SpreadAngle = Vector2.new(5, 5),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Brightness = 2,
			LightEmission = 0.9,
			Color = FIRE_COLOURS,
			Size = numbers({ { 0, 0.4 }, { 0.3, 0.8 }, { 1, 0.3 } }),
			Transparency = numbers({ { 0, 0.3 }, { 0.2, 0.15 }, { 0.7, 0.5 }, { 1, 1 } }),
		}, {
			VFXGroup = driftGroup,
			VFXBurst = "None",
			RateMin = 8,
			RateMax = STAB_FLAME_RATE,
			SpeedScaleMin = 0.5,
			SpeedScaleMax = 1,
			TintStart = 0.45,
			TintEnd = 0,
		})

		newEmitter(nozzle, "SlideSparks", "spark_streak", nil, {
			Rate = STAB_SPARK_RATE,
			Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(12, 26),
			SpreadAngle = Vector2.new(30, 30),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Drag = 1.5,
			Acceleration = Vector3.new(0, -60, 0),
			LockedToPart = false,
			Brightness = 3,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.35 }, { 1, 0.08 } }),
			Transparency = numbers({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
		}, {
			VFXGroup = sparkGroup,
			VFXTier = "Full",
			VFXBurst = "None",
			WorldSpace = true,
			RateMin = 0,
			RateMax = STAB_SPARK_RATE,
		})

		newEmitter(nozzle, "ChargeGlow", "glow_soft", nil, {
			Rate = STAB_CHARGE_GLOW_RATE,
			Lifetime = NumberRange.new(0.14, 0.18),
			Speed = NumberRange.new(0.2, 0.5),
			Brightness = 2,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 0.8 }, { 1, 1.4 } }),
			Transparency = numbers({ { 0, 0.5 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2DriftCharge",
			VFXTier = "Full",
			VFXBurst = "None",
			RateMin = 4,
			RateMax = STAB_CHARGE_GLOW_RATE,
			GlowMin = 0.6,
			GlowMax = 3,
			TintStart = 1,
			TintEnd = 1,
			Flicker = 0.2,
			FlickerHz = 12,
		})

		newEmitter(nozzle, "ChargeArcs", "arc_flipbook", ARC_RANDOM, {
			Rate = STAB_CHARGE_ARC_RATE,
			Lifetime = NumberRange.new(0.06, 0.1),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			Brightness = 3,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 0.7 }, { 1, 1.2 } }),
			Transparency = numbers({ { 0, 0.1 }, { 0.6, 0.2 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2DriftChargeArcs",
			VFXBurst = "None",
			VFXTier = "Full",
			RateMin = 0,
			RateMax = STAB_CHARGE_ARC_RATE,
			TintStart = 0.85,
			TintEnd = 1,
		})

		newEmitter(nozzle, "ReleaseArcs", "arc_flipbook", ARC_RANDOM, {
			Lifetime = NumberRange.new(0.1, 0.18),
			Speed = NumberRange.new(2, 6),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			Brightness = 4,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 1.2 }, { 1, 2.4 } }),
			Transparency = numbers({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXTier = "Full",
			VFXBurst = "DriftRelease",
			BurstCount = STAB_RELEASE_ARCS,
			TintStart = 0.85,
			TintEnd = 1,
		})

		newEmitter(nozzle, "ReleaseRing", "shock_ring", nil, {
			Lifetime = NumberRange.new(0.18, 0.24),
			Speed = NumberRange.new(2, 2),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Brightness = 3,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 0.4 }, { 1, 3.2 } }),
			Transparency = numbers({ { 0, 0.1 }, { 0.5, 0.45 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXTier = "Full",
			VFXBurst = "DriftRelease",
			BurstCount = 1,
			TintStart = 0.8,
			TintEnd = 1,
		})

		return folder
	end

	-- -----------------------------------------------------------------------
	-- HoverDust_ExoticV2 (the five hover sockets under the cockpit)
	-- A repulsor pad: a flat pad graphic facing the ground, a tighter brighter
	-- pad that appears as the hover compresses, a soft glow and a short column
	-- of light toward the ground. The dust itself is in GroundFX_ExoticV2.
	-- -----------------------------------------------------------------------
	local function buildHoverPad()
		local folder, host = newTemplate(
			"HoverDust_ExoticV2",
			"Exotic V2 hover pad: repulsor disc, squash pad, glow and light column under each hover socket.",
			MOBILE_SCALE_HOVER
		)

		local padPoint = newAttachment(host, "PadPoint", Vector3.new(0, -0.1, 0))
		local columnEnd = newAttachment(host, "ColumnEnd", Vector3.new(0, -PAD_COLUMN_LENGTH, 0))

		-- Flat discs: particles move slowly straight down and lie perpendicular
		-- to that motion, so they read as a disc projected at the ground.
		newEmitter(padPoint, "PadDisc", "hover_pad", nil, {
			Rate = PAD_DISC_RATE,
			EmissionDirection = Enum.NormalId.Bottom,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Lifetime = NumberRange.new(0.28, 0.34),
			Speed = NumberRange.new(0.05, 0.05),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(30, 50),
			Brightness = 2,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, PAD_SIZE * 0.92 }, { 1, PAD_SIZE } }),
			Transparency = numbers({ { 0, 1 }, { 0.25, 0.45 }, { 0.75, 0.45 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2HoverPad",
			VFXBurst = "None",
			RateMin = 4,
			RateMax = PAD_DISC_RATE,
			GlowMin = 0.8,
			GlowMax = 2.6,
			TintStart = 0.9,
			TintEnd = 1,
			Flicker = 0.14,
			FlickerHz = 7,
		})

		newEmitter(padPoint, "PadTight", "hover_pad", nil, {
			Rate = 8,
			EmissionDirection = Enum.NormalId.Bottom,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Lifetime = NumberRange.new(0.2, 0.26),
			Speed = NumberRange.new(0.05, 0.05),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, -60),
			Brightness = 3,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, PAD_TIGHT_SIZE }, { 1, PAD_TIGHT_SIZE * 0.85 } }),
			Transparency = numbers({ { 0, 1 }, { 0.25, 0.25 }, { 0.75, 0.25 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2HoverTight",
			VFXBurst = "None",
			RateMin = 3,
			RateMax = 8,
			GlowMin = 1.5,
			GlowMax = 5,
			TintStart = 0.7,
			TintEnd = 1,
		})

		newEmitter(padPoint, "PadGlow", "glow_soft", nil, {
			Rate = 6,
			EmissionDirection = Enum.NormalId.Bottom,
			Lifetime = NumberRange.new(0.2, 0.26),
			Speed = NumberRange.new(0.4, 0.8),
			Brightness = 1.5,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 1.5 }, { 1, 2.1 } }),
			Transparency = numbers({ { 0, 0.7 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2HoverPad",
			VFXBurst = "None",
			RateMin = 3,
			RateMax = 6,
			GlowMin = 0.6,
			GlowMax = 2,
			TintStart = 1,
			TintEnd = 1,
		})

		newBeam(padPoint, columnEnd, "PadColumn", "heat_streak", {
			Width0 = 1.1,
			Width1 = 2.0,
			Brightness = 1.5,
			TextureLength = 1.5,
			TextureSpeed = 2.5,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0.7 }, { 0.6, 0.85 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2HoverPad",
			VFXTier = "Full",
			Width0Min = 0.7,
			Width0Max = 1.1,
			Width1Min = 1.4,
			Width1Max = 2.0,
			GlowMin = 0.6,
			GlowMax = 2,
			TintStart = 1,
			TintEnd = 1,
			Flicker = 0.2,
			FlickerHz = 8,
		})

		return folder
	end

	-- -----------------------------------------------------------------------
	-- GroundFX_ExoticV2 (one per car, attached by the driver at the root)
	-- The driver moves GroundPoint and GroundLightPoint onto the ground under the
	-- car: a ring of dust thrown outward along the ground, a low mist, a glow
	-- pool, one light, and the landing burst.
	-- -----------------------------------------------------------------------
	local function buildGroundFX()
		local folder, host = newTemplate(
			"GroundFX_ExoticV2",
			"Exotic V2 ground effects: downwash dust ring, mist, glow pool, ground light, landing burst.",
			MOBILE_SCALE_HOVER
		)

		local groundPoint = newAttachment(host, "GroundPoint", Vector3.new(0, -3, 0))
		local lightPoint = newAttachment(host, "GroundLightPoint", Vector3.new(0, -1.6, 0))

		-- Emission along +X with a full yaw spread: a flat ring in the ground plane.
		local RING_SPREAD = Vector2.new(4, 180)

		newEmitter(groundPoint, "DustRing", "dust_wisp", DUST_LOOP, {
			Rate = GROUND_DUST_RATE,
			EmissionDirection = Enum.NormalId.Right,
			SpreadAngle = RING_SPREAD,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(14, 24),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
			Drag = 4,
			Acceleration = Vector3.new(0, 2.5, 0),
			LockedToPart = false,
			LightEmission = 0,
			LightInfluence = 1,
			Brightness = 1,
			Color = DUST_COLOURS,
			Size = numbers({ { 0, 1.2 }, { 0.5, 2.6 }, { 1, 3.6 } }),
			Transparency = numbers({ { 0, 0.6 }, { 0.5, 0.75 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2GroundDust",
			VFXBurst = "None",
			WorldSpace = true,
			GroundTint = true,
			RateMin = 0,
			RateMax = GROUND_DUST_RATE,
			SpeedScaleMin = 0.55,
			SpeedScaleMax = 1,
		})

		newEmitter(groundPoint, "GroundMist", "smoke_puff", ONE_SHOT, {
			Rate = GROUND_MIST_RATE,
			EmissionDirection = Enum.NormalId.Right,
			SpreadAngle = RING_SPREAD,
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(4, 9),
			Rotation = NumberRange.new(0, 360),
			Drag = 3,
			LockedToPart = false,
			LightEmission = 0,
			LightInfluence = 1,
			Brightness = 1,
			Color = DUST_COLOURS,
			Size = numbers({ { 0, 2.2 }, { 1, 5.5 } }),
			Transparency = numbers({ { 0, 0.82 }, { 0.5, 0.88 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2GroundDust",
			VFXBurst = "None",
			VFXTier = "Full",
			WorldSpace = true,
			GroundTint = true,
			RateMin = 0,
			RateMax = GROUND_MIST_RATE,
		})

		-- Flat glow pool on the ground; visible without the light (mobile, remote).
		newEmitter(groundPoint, "GroundGlow", "glow_soft", nil, {
			Rate = 5,
			EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Lifetime = NumberRange.new(0.3, 0.36),
			Speed = NumberRange.new(0.05, 0.05),
			Brightness = 1.5,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, GROUND_GLOW_SIZE }, { 1, GROUND_GLOW_SIZE } }),
			Transparency = numbers({ { 0, 1 }, { 0.3, 0.82 }, { 0.7, 0.82 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2GroundGlow",
			VFXBurst = "None",
			RateMin = 3,
			RateMax = 5,
			GlowMin = 0.5,
			GlowMax = 2,
			TintStart = 1,
			TintEnd = 1,
			Flicker = 0.12,
			FlickerHz = 5,
		})

		newLight(lightPoint, "GroundLight", {
			Brightness = GROUND_LIGHT_BRIGHTNESS,
			Range = GROUND_LIGHT_RANGE,
			Color = rgb(WHITE),
		}, {
			VFXGroup = "V2GroundLight",
			VFXTier = "Full",
			DesktopOnly = true,
			BrightnessMin = 0.5,
			BrightnessMax = GROUND_LIGHT_BRIGHTNESS,
			RangeMin = 12,
			RangeMax = GROUND_LIGHT_RANGE,
			TintStart = 1,
			Flicker = 0.1,
			FlickerHz = 5,
		})

		-- Landing burst (existing "Dust" burst, counted by the caller).
		newEmitter(groundPoint, "LandDust", "dust_wisp", DUST_LOOP, {
			EmissionDirection = Enum.NormalId.Right,
			SpreadAngle = RING_SPREAD,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(22, 36),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
			Drag = 4.5,
			Acceleration = Vector3.new(0, 4, 0),
			LockedToPart = false,
			LightEmission = 0,
			LightInfluence = 1,
			Brightness = 1,
			Color = DUST_COLOURS,
			Size = numbers({ { 0, 1.8 }, { 0.5, 3.8 }, { 1, 5.2 } }),
			Transparency = numbers({ { 0, 0.5 }, { 0.5, 0.7 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "Dust",
			BurstShare = 1,
			WorldSpace = true,
			GroundTint = true,
		})

		newEmitter(groundPoint, "LandRing", "shock_ring", nil, {
			EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Lifetime = NumberRange.new(0.28, 0.34),
			Speed = NumberRange.new(0.2, 0.2),
			Brightness = 2.5,
			Color = WHITE_COLOURS,
			Size = numbers({ { 0, 2 }, { 0.4, 7 }, { 1, 10 } }),
			Transparency = numbers({ { 0, 0.2 }, { 0.5, 0.55 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "Dust",
			BurstShare = 0.08,
			TintStart = 0.6,
			TintEnd = 1,
		})

		return folder
	end

	-- -----------------------------------------------------------------------
	-- BrakeSparks_ExoticV2 (impact and scrape sparks)
	-- The driver attaches one on the local car and moves ImpactPoint to the side
	-- that was hit. Bursts on an impact, a continuous stream while scraping.
	-- -----------------------------------------------------------------------
	local function buildImpactSparks()
		local folder, host = newTemplate(
			"BrakeSparks_ExoticV2",
			"Exotic V2 impact sparks: directional spark burst with embers and smoke chips, scrape stream.",
			MOBILE_SCALE_SPARKS
		)

		-- The driver points ImpactPoint's Front (-Z) away from the wall.
		local impactPoint = newAttachment(host, "ImpactPoint", Vector3.new(0, 0, 0))

		newEmitter(impactPoint, "ImpactSparks", "spark_streak", nil, {
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = NumberRange.new(0.25, 0.55),
			Speed = NumberRange.new(35, 70),
			SpreadAngle = Vector2.new(55, 55),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Drag = 1.5,
			Acceleration = Vector3.new(0, -70, 0),
			LockedToPart = false,
			Brightness = 4,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.5 }, { 1, 0.12 } }),
			Transparency = numbers({ { 0, 0 }, { 0.75, 0.15 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "Sparks",
			BurstShare = 1,
			WorldSpace = true,
		})

		newEmitter(impactPoint, "ImpactEmbers", "ember", nil, {
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = NumberRange.new(0.5, 1.0),
			Speed = NumberRange.new(12, 30),
			SpreadAngle = Vector2.new(70, 70),
			Drag = 2,
			Acceleration = Vector3.new(0, -45, 0),
			LockedToPart = false,
			Brightness = 3,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.14 }, { 1, 0.04 } }),
			Transparency = numbers({ { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "Sparks",
			BurstShare = 0.45,
			WorldSpace = true,
		})

		newEmitter(impactPoint, "ImpactSmoke", "smoke_puff", ONE_SHOT, {
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(5, 12),
			SpreadAngle = Vector2.new(50, 50),
			Rotation = NumberRange.new(0, 360),
			Drag = 3,
			LockedToPart = false,
			LightEmission = 0,
			LightInfluence = 1,
			Brightness = 1,
			Color = SMOKE_COLOURS,
			Size = numbers({ { 0, 0.8 }, { 1, 2.6 } }),
			Transparency = numbers({ { 0, 0.55 }, { 0.5, 0.75 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "Sparks",
			BurstShare = 0.12,
			WorldSpace = true,
		})

		newEmitter(impactPoint, "ImpactFlash", "glow_soft", nil, {
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = NumberRange.new(0.07, 0.1),
			Speed = NumberRange.new(0.5, 1),
			Brightness = 4,
			Color = colours({ { 0, SPARK_HOT }, { 1, SPARK_COOL } }),
			Size = numbers({ { 0, 2.2 }, { 1, 3.4 } }),
			Transparency = numbers({ { 0, 0.2 }, { 1, 1 } }),
		}, {
			VFXGroup = "Manual",
			VFXBurst = "Sparks",
			BurstShare = 0.05,
		})

		newEmitter(impactPoint, "ScrapeSparks", "spark_streak", nil, {
			Rate = SCRAPE_SPARK_RATE,
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = NumberRange.new(0.2, 0.45),
			Speed = NumberRange.new(20, 45),
			SpreadAngle = Vector2.new(40, 40),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Drag = 1.5,
			Acceleration = Vector3.new(0, -60, 0),
			LockedToPart = false,
			Brightness = 3.5,
			Color = SPARK_COLOURS,
			Size = numbers({ { 0, 0.4 }, { 1, 0.1 } }),
			Transparency = numbers({ { 0, 0 }, { 0.75, 0.15 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2Scrape",
			VFXBurst = "None",
			WorldSpace = true,
			RateMin = 12,
			RateMax = SCRAPE_SPARK_RATE,
		})

		newEmitter(impactPoint, "ScrapeGlow", "glow_soft", nil, {
			Rate = 14,
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = NumberRange.new(0.08, 0.12),
			Speed = NumberRange.new(0.2, 0.5),
			Brightness = 3,
			Color = colours({ { 0, SPARK_HOT }, { 1, SPARK_COOL } }),
			Size = numbers({ { 0, 1.0 }, { 1, 1.6 } }),
			Transparency = numbers({ { 0, 0.4 }, { 1, 1 } }),
		}, {
			VFXGroup = "V2Scrape",
			VFXBurst = "None",
			RateMin = 4,
			RateMax = 14,
			Flicker = 0.4,
			FlickerHz = 17,
		})

		return folder
	end

	-- -----------------------------------------------------------------------
	-- SpeedTrails_ExoticV2 (local car; the driver places the attachment pairs
	-- on the rear upper corners and the tail of the car's bounds)
	-- -----------------------------------------------------------------------
	local function buildSpeedTrails()
		local folder, host = newTemplate(
			"SpeedTrails_ExoticV2",
			"Exotic V2 speed trails: two vapour trails above 150 mph and a tail ribbon during boost.",
			1
		)

		local leftA = newAttachment(host, "VapourLeftA", Vector3.new(-3, 1.0, 7))
		local leftB = newAttachment(host, "VapourLeftB", Vector3.new(-3, 0.8, 7))
		local rightA = newAttachment(host, "VapourRightA", Vector3.new(3, 1.0, 7))
		local rightB = newAttachment(host, "VapourRightB", Vector3.new(3, 0.8, 7))
		local tailA = newAttachment(host, "TailA", Vector3.new(-0.9, 0.3, 8))
		local tailB = newAttachment(host, "TailB", Vector3.new(0.9, 0.3, 8))

		local vapourProperties = {
			Lifetime = VAPOUR_LIFETIME,
			Brightness = 1.2,
			LightEmission = 0.6,
			TextureLength = 4,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0.55 }, { 0.5, 0.8 }, { 1, 1 } }),
			WidthScale = numbers({ { 0, 1 }, { 1, 0.2 } }),
		}
		local vapourAttributes = { VFXGroup = "V2Vapour", TintStart = 0.15, TintEnd = 0.3 }
		newTrail(host, leftA, leftB, "VapourLeft", "energy_ribbon", vapourProperties, vapourAttributes)
		newTrail(host, rightA, rightB, "VapourRight", "energy_ribbon", vapourProperties, vapourAttributes)

		newTrail(host, tailA, tailB, "TailRibbon", "energy_ribbon", {
			Lifetime = TAIL_RIBBON_LIFETIME,
			Brightness = 2.5,
			TextureLength = 6,
			Color = WHITE_COLOURS,
			Transparency = numbers({ { 0, 0.25 }, { 0.6, 0.6 }, { 1, 1 } }),
			WidthScale = numbers({ { 0, 1 }, { 1, 0.35 } }),
		}, {
			VFXGroup = "V2TailRibbon",
			TintStart = 1,
			TintEnd = 1,
		})

		return folder
	end

	return {
		buildEngineJet(),
		buildBoostJet(),
		buildStabiliserJet("Left"),
		buildStabiliserJet("Right"),
		buildHoverPad(),
		buildGroundFX(),
		buildImpactSparks(),
		buildSpeedTrails(),
	}
end
