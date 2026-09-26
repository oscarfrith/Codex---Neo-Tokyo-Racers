local presets=(function()
local LightingPresets = {
	ClearNight = {
		Atmosphere = {
			Color = Color3.new(0.21568629145622253, 0.25098040699958801, 0.30980393290519714),
			Decay = Color3.new(0.41176474094390869, 0.41960787773132324, 0.53333336114883423),
			Density = 0.3070000112056732,
			Glare = 6.860000133514404,
			Haze = 4.090000152587891,
			Offset = 0,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.5,
			Size = 16,
			Threshold = 0.30000001192092896,
		},
		ColorCorrection = {
			Brightness = 0.05000000074505806,
			Contrast = 0.30000001192092896,
			Enabled = true,
			Saturation = 0.20000000298023224,
			TintColor = Color3.new(0.79215693473815918, 0.81960791349411011, 1),
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0.08399999886751175,
			FocusDistance = 0.05000000074505806,
			InFocusRadius = 10,
			NearIntensity = 0.75,
		},
		Lighting = {
			Ambient = Color3.new(0.48235297203063965, 0.54117649793624878, 0.74117648601531982),
			Brightness = 2.7100000381469727,
			ClockTime = 0,
			ColorShift_Bottom = Color3.new(0.35294118523597717, 0.35294118523597717, 0.35294118523597717),
			ColorShift_Top = Color3.new(1, 0.9490196704864502, 0.83137261867523193),
			EnvironmentDiffuseScale = 0,
			EnvironmentSpecularScale = 0.23399999737739563,
			ExposureCompensation = 0,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.63137257099151611, 0.65490198135375977, 0.88627457618713379),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "ClearNightSky",
		SunRays = {
			Enabled = false,
			Intensity = 0.05000000074505806,
			Spread = 0.7129999995231628,
		},
	},
	Day = {
		Atmosphere = {
			Color = Color3.new(0.78039216995239258, 0.78039216995239258, 0.78039216995239258),
			Decay = Color3.new(0.41568627953529358, 0.43921568989753723, 0.49019607901573181),
			Density = 0.2199999988079071,
			Glare = 0,
			Haze = 0,
			Offset = 0.20000000298023224,
		},
		Bloom = {
			Intensity = 0.6499999761581421,
			Size = 10,
			Threshold = 1.9040000438690186,
		},
		ColorCorrection = {
			Brightness = 0.05000000074505806,
			Contrast = 0,
			Saturation = 0.4000000059604645,
			TintColor = Color3.new(1, 1, 1),
		},
		Lighting = {
			Ambient = Color3.new(0.4117647111415863, 0.73333334922790527, 1),
			Brightness = 5.150000095367432,
			ClockTime = 12,
			ColorShift_Bottom = Color3.new(0, 0, 0),
			ColorShift_Top = Color3.new(1, 0.9529411792755127, 0.83137255907058716),
			EnvironmentDiffuseScale = 0.47099998593330383,
			EnvironmentSpecularScale = 1,
			ExposureCompensation = 0.10000000149011612,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.61176472902297974, 0.83921569585800171, 0.90980392694473267),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "DaySky",
	},
	EightPM = {
		Atmosphere = {
			Color = Color3.new(0.31764706969261169, 0.29803922772407532, 0.43921571969985962),
			Decay = Color3.new(0.58431375026702881, 0.5215686559677124, 0.76078438758850098),
			Density = 0.3070000112056732,
			Glare = 6.860000133514404,
			Haze = 4.090000152587891,
			Offset = 0,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.4000000059604645,
			Size = 16,
			Threshold = 0.30000001192092896,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.20000000298023224,
			Enabled = true,
			Saturation = 0.20000000298023224,
			TintColor = Color3.new(0.98823535442352295, 0.85098046064376831, 1),
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0.08399999886751175,
			FocusDistance = 0.05000000074505806,
			InFocusRadius = 10,
			NearIntensity = 0.75,
		},
		Lighting = {
			Ambient = Color3.new(0.41960787773132324, 0.52549022436141968, 1),
			Brightness = 2.4000000953674316,
			ClockTime = 23.5,
			ColorShift_Bottom = Color3.new(0, 0, 0),
			ColorShift_Top = Color3.new(1, 0.9490196704864502, 0.83137261867523193),
			EnvironmentDiffuseScale = 0,
			EnvironmentSpecularScale = 0.23399999737739563,
			ExposureCompensation = 0.10999999940395355,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.85882359743118286, 0.70196080207824707, 0.90980398654937744),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "EightPMSky",
		SunRays = {
			Enabled = false,
			Intensity = 0.05000000074505806,
			Spread = 0.7129999995231628,
		},
	},
	FivePM = {
		Atmosphere = {
			Color = Color3.new(0.43921571969985962, 0.35686275362968445, 0.32549020648002625),
			Decay = Color3.new(0.86666673421859741, 0.70588237047195435, 0.64313727617263794),
			Density = 0.2669999897480011,
			Glare = 6.900000095367432,
			Haze = 5.400000095367432,
			Offset = 0,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.550000011920929,
			Size = 10,
			Threshold = 0.699999988079071,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.20000000298023224,
			Enabled = true,
			Saturation = 0.4000000059604645,
			TintColor = Color3.new(0.88235300779342651, 0.94509810209274292, 1),
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0.08399999886751175,
			FocusDistance = 0.05000000074505806,
			InFocusRadius = 10,
			NearIntensity = 0.75,
		},
		Lighting = {
			Ambient = Color3.new(1, 0.94509804248809814, 0.91764706373214722),
			Brightness = 0.1899999976158142,
			ClockTime = 14.699999809265137,
			ColorShift_Bottom = Color3.new(0, 0, 0),
			ColorShift_Top = Color3.new(0.4901961088180542, 0.46666669845581055, 0.40784317255020142),
			EnvironmentDiffuseScale = 0.20100000500679016,
			EnvironmentSpecularScale = 1,
			ExposureCompensation = -0.44999998807907104,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.90980398654937744, 0.84705889225006104, 0.81176477670669556),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "FivePMSky",
		SunRays = {
			Enabled = false,
			Intensity = 0.05000000074505806,
			Spread = 0.7129999995231628,
		},
	},
	FourAM = {
		Atmosphere = {
			Color = Color3.new(0.31764706969261169, 0.29803922772407532, 0.43921571969985962),
			Decay = Color3.new(0.58431375026702881, 0.5215686559677124, 0.76078438758850098),
			Density = 0.3070000112056732,
			Glare = 6.860000133514404,
			Haze = 4.090000152587891,
			Offset = 0,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.4000000059604645,
			Size = 16,
			Threshold = 0.30000001192092896,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.20000000298023224,
			Enabled = true,
			Saturation = 0.20000000298023224,
			TintColor = Color3.new(0.98823535442352295, 0.85098046064376831, 1),
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0.08399999886751175,
			FocusDistance = 0.05000000074505806,
			InFocusRadius = 10,
			NearIntensity = 0.75,
		},
		Lighting = {
			Ambient = Color3.new(0.41960787773132324, 0.52549022436141968, 1),
			Brightness = 2.4000000953674316,
			ClockTime = 0.5,
			ColorShift_Bottom = Color3.new(0, 0, 0),
			ColorShift_Top = Color3.new(1, 0.9490196704864502, 0.83137261867523193),
			EnvironmentDiffuseScale = 0,
			EnvironmentSpecularScale = 0.23399999737739563,
			ExposureCompensation = 0.10999999940395355,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.85882359743118286, 0.70196080207824707, 0.90980398654937744),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "FourAMSky",
		SunRays = {
			Enabled = false,
			Intensity = 0.05000000074505806,
			Spread = 0.7129999995231628,
		},
	},
	SevenAM = {
		Atmosphere = {
			Color = Color3.new(0.43921571969985962, 0.35686275362968445, 0.32549020648002625),
			Decay = Color3.new(0.86666673421859741, 0.70588237047195435, 0.64313727617263794),
			Density = 0.2370000034570694,
			Glare = 6.900000095367432,
			Haze = 5.400000095367432,
			Offset = 0,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.550000011920929,
			Size = 10,
			Threshold = 0.699999988079071,
		},
		ColorCorrection = {
			Brightness = 0,
			Contrast = 0.20000000298023224,
			Enabled = true,
			Saturation = 0.4000000059604645,
			TintColor = Color3.new(0.88235300779342651, 0.94509810209274292, 1),
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0.08399999886751175,
			FocusDistance = 0.05000000074505806,
			InFocusRadius = 10,
			NearIntensity = 0.75,
		},
		Lighting = {
			Ambient = Color3.new(1, 0.94509804248809814, 0.91764706373214722),
			Brightness = 0.2199999988079071,
			ClockTime = 9.399999618530273,
			ColorShift_Bottom = Color3.new(0, 0, 0),
			ColorShift_Top = Color3.new(0.4901961088180542, 0.46666669845581055, 0.40784317255020142),
			EnvironmentDiffuseScale = 0.20100000500679016,
			EnvironmentSpecularScale = 1,
			ExposureCompensation = -0.44999998807907104,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.90980398654937744, 0.84705889225006104, 0.81176477670669556),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "SevenAMSky",
		SunRays = {
			Enabled = false,
			Intensity = 0.05000000074505806,
			Spread = 0.7129999995231628,
		},
	},
	TenAM = {
		Atmosphere = {
			Color = Color3.new(0.83137261867523193, 0.83137261867523193, 0.7450980544090271),
			Decay = Color3.new(0.4901961088180542, 0.45490199327468872, 0.32941177487373352),
			Density = 0.2540000081062317,
			Glare = 2.0999999046325684,
			Haze = 2.059999942779541,
			Offset = 0,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.3499999940395355,
			Size = 10,
			Threshold = 1.4110000133514404,
		},
		ColorCorrection = {
			Brightness = 0.05000000074505806,
			Contrast = 0.20000000298023224,
			Enabled = true,
			Saturation = 0.4000000059604645,
			TintColor = Color3.new(1, 1, 1),
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0.08399999886751175,
			FocusDistance = 0.05000000074505806,
			InFocusRadius = 10,
			NearIntensity = 0.75,
		},
		Lighting = {
			Ambient = Color3.new(0.88235300779342651, 1, 0.93725496530532837),
			Brightness = 3,
			ClockTime = 10,
			ColorShift_Bottom = Color3.new(0, 0, 0),
			ColorShift_Top = Color3.new(0.94509810209274292, 1, 0.87843143939971924),
			EnvironmentDiffuseScale = 0.46700000762939453,
			EnvironmentSpecularScale = 1,
			ExposureCompensation = 0.10000000149011612,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.81960791349411011, 0.90980398654937744, 0.80392163991928101),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "TenAMSky",
		SunRays = {
			Enabled = false,
			Intensity = 0.05000000074505806,
			Spread = 0.7129999995231628,
		},
	},
	ThreePM = {
		Atmosphere = {
			Color = Color3.new(0.83137261867523193, 0.83137261867523193, 0.7450980544090271),
			Decay = Color3.new(0.4901961088180542, 0.45490199327468872, 0.32941177487373352),
			Density = 0.2540000081062317,
			Glare = 2.0999999046325684,
			Haze = 2.059999942779541,
			Offset = 0,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.3499999940395355,
			Size = 10,
			Threshold = 1.4110000133514404,
		},
		ColorCorrection = {
			Brightness = 0.05000000074505806,
			Contrast = 0.20000000298023224,
			Enabled = true,
			Saturation = 0.4000000059604645,
			TintColor = Color3.new(1, 1, 1),
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0.08399999886751175,
			FocusDistance = 0.05000000074505806,
			InFocusRadius = 10,
			NearIntensity = 0.75,
		},
		Lighting = {
			Ambient = Color3.new(0.88235300779342651, 1, 0.93725496530532837),
			Brightness = 3,
			ClockTime = 14.5,
			ColorShift_Bottom = Color3.new(0, 0, 0),
			ColorShift_Top = Color3.new(0.94509810209274292, 1, 0.87843143939971924),
			EnvironmentDiffuseScale = 0.46700000762939453,
			EnvironmentSpecularScale = 1,
			ExposureCompensation = 0.10000000149011612,
			FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
			FogEnd = 100000,
			FogStart = 0,
			GlobalShadows = true,
			OutdoorAmbient = Color3.new(0.81960791349411011, 0.90980398654937744, 0.80392163991928101),
			ShadowSoftness = 0.20000000298023224,
		},
		SkyName = "ThreePMSky",
		SunRays = {
			Enabled = false,
			Intensity = 0.05000000074505806,
			Spread = 0.7129999995231628,
		},
	},
}

return LightingPresets

end)()
local schedule=(function()
-- Edit this ordered table to change stage order, relative duration, or visual flags.
-- BaseDurationSeconds lives on the parent LightingCycleConfig Folder.
return {
	{Preset = "SevenAM",    DisplayName = "7 AM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "TenAM",      DisplayName = "10 AM",  DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "Day",        DisplayName = "Day",    DurationWeight = 2, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "ThreePM",    DisplayName = "3 PM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "FivePM",     DisplayName = "5 PM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "EightPM",    DisplayName = "8 PM",   DurationWeight = 1, StreetLightsOn = true,  WindowMode = "Night"},
	{Preset = "ClearNight", DisplayName = "Night",  DurationWeight = 2, StreetLightsOn = true,  WindowMode = "Night"},
	{Preset = "FourAM",     DisplayName = "4 AM",   DurationWeight = 1, StreetLightsOn = true,  WindowMode = "Night"},
}

end)()

local L=game.Lighting;local C=game.ReplicatedStorage.Config.World.Lighting
assert(C:GetAttribute("CycleMode")=="Stepped")
local auto,manual=C:GetAttribute("AutoCycleEnabled"),C:GetAttribute("ManualStage")
local rows={}
local function equal(a,b) if type(a)=="number" then return math.abs(a-b)<1e-5 end return a==b end
local ok,err=xpcall(function()
 C:SetAttribute("AutoCycleEnabled",false)
 for _,stage in ipairs(schedule) do
 C:SetAttribute("ManualStage",stage.Preset);task.wait(1.15)
 local misses={}
 for group,properties in pairs(presets[stage.Preset]) do
 if type(properties)=="table" then
 local instance=group=="Lighting" and L or L:FindFirstChild(group)
 for k,v in pairs(properties) do if not instance or not equal(instance[k],v) then table.insert(misses,group.."."..k) end end
 end end
 local sky=game.ReplicatedStorage.Assets.World.Skies[presets[stage.Preset].SkyName]
 for _,k in ipairs({"SkyboxOrientation","SunAngularSize","MoonAngularSize","StarCount","SkyboxBk","SkyboxUp"}) do
 if L.ActiveSky[k]~=sky[k] then table.insert(misses,"Sky."..k) end end
 table.insert(rows,{stage=stage.Preset,pass=#misses==0,misses=misses,latitude=L.GeographicLatitude})
 assert(#misses==0,"Stepped preset mismatch")
 end
end,debug.traceback)
C:SetAttribute("ManualStage",manual);C:SetAttribute("AutoCycleEnabled",auto)
return game.HttpService:JSONEncode({kind="stepped-runtime-regression",pass=ok,error=not ok and err or nil,rows=rows})
