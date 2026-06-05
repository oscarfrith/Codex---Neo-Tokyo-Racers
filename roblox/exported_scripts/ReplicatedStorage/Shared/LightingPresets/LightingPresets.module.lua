local LightingPresets = {}

LightingPresets.Day = {
	SkyName = "DaySky",
	
	Lighting = {
		ClockTime = 12,
		Brightness = 5.150000095367432,
		Ambient = Color3.fromRGB(105, 187, 255),
		OutdoorAmbient = Color3.fromRGB(156, 214, 232),
		ColorShift_Top = Color3.fromRGB(255, 243, 212),
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 0.47099998593330383,
		EnvironmentSpecularScale = 1,
		ExposureCompensation = 0.10000000149011612,
		ShadowSoftness = 0.20000000298023224,
		GlobalShadows = true,
	},

	Atmosphere = {
		Density = 0.2199999988079071,
		Offset = 0.20000000298023224,
		Color = Color3.fromRGB(199, 199, 199),
		Decay = Color3.fromRGB(106, 112, 125),
		Glare = 0,
		Haze = 0,
	},

	ColorCorrection = {
		Brightness = 0.05000000074505806,
		Contrast = 0,
		Saturation = 0.4000000059604645,
		TintColor = Color3.fromRGB(255, 255, 255),
	},

	Bloom = {
		Intensity = 0.6499999761581421,
		Size = 10,
		Threshold = 1.9040000438690186,
	},
}

LightingPresets.ClearNight = {
	SkyName = "ClearNightSky",

	Lighting = {
		ClockTime = 12.1,
		Brightness = 0.23999999463558197,
		Ambient = Color3.fromRGB(65, 78, 125),
		OutdoorAmbient = Color3.fromRGB(123, 125, 163),
		ColorShift_Top = Color3.fromRGB(162, 176, 255),
		ColorShift_Bottom = Color3.fromRGB(67, 54, 83),
		EnvironmentDiffuseScale = 0.3230000138282776,
		EnvironmentSpecularScale = 1,
		ExposureCompensation = .8,
		ShadowSoftness = 0.44999998807907104,
		GlobalShadows = true,
	},

	Atmosphere = {
		Density = 0.2680000066757202,
		Offset = 0.20499999821186066,
		Color = Color3.fromRGB(141, 148, 170),
		Decay = Color3.fromRGB(60, 58, 86),
		Glare = 1.340000033378601,
		Haze = 2.440000057220459,
	},

	ColorCorrection = {
		Brightness = 0.4000000059604645,
		Contrast = 1,
		Saturation = 0.10000000149011612,
		TintColor = Color3.fromRGB(195, 195, 195),
		Enabled = true,
	},

	Bloom = {
		Intensity = 0.65,
		Size = 1,
		Threshold = 1.8,
		Enabled = true,
	},

	SunRays = {
		Intensity = 0.05000000074505806,
		Spread = 0.7129999995231628,
		Enabled = false,
	},

	DepthOfField = {
		FarIntensity = 0.08399999886751175,
		FocusDistance = 0.05000000074505806,
		InFocusRadius = 10,
		NearIntensity = 0.75,
		Enabled = false,
	},
}

return LightingPresets