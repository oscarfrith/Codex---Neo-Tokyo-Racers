-- Generated pure numerical checks. No game module require or property writes.
local Cycle=(function()
-- Pure solar motion and authored-look evaluation. No services, tasks or instances.
local Cycle={}
local DEFAULTS={
    Atmosphere={Color=Color3.fromRGB(199,199,199),Decay=Color3.fromRGB(106,112,125),Density=.22,Glare=0,Haze=0,Offset=.2},
    Bloom={Enabled=true,Intensity=.65,Size=10,Threshold=1.904},
    ColorCorrection={Enabled=true,Brightness=.05,Contrast=0,Saturation=.4,TintColor=Color3.new(1,1,1)},
    DepthOfField={Enabled=false,FarIntensity=.084,FocusDistance=.05,InFocusRadius=10,NearIntensity=.75},
    SunRays={Enabled=false,Intensity=.05,Spread=.713},
}
function Cycle.finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function copy(v)
    if type(v)~="table" then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local function overlay(a,b)
    for k,v in pairs(b) do
        if type(v)=="table" then a[k]=a[k] or {}; overlay(a[k],v) else a[k]=v end
    end
    return a
end
function Cycle.preset(presets,name,latitude)
    assert(type(presets[name])=="table","Unknown lighting preset: "..tostring(name))
    local target=overlay(copy(DEFAULTS),presets[name])
    target.Lighting.GeographicLatitude=latitude
    return target
end
local function compatible(a,b,path)
    for k,av in pairs(a) do
        local bv=b[k]; local key=path.."."..k
        assert(typeof(av)==typeof(bv),"Incompatible look property "..key)
        if type(av)=="table" then compatible(av,bv,key)
        elseif type(av)=="number" then assert(Cycle.finite(av) and Cycle.finite(bv),"Nonfinite "..key)
        elseif typeof(av)=="Color3" then
            for _,v in ipairs({av.R,av.G,av.B,bv.R,bv.G,bv.B}) do assert(Cycle.finite(v) and v>=0 and v<=1,"Invalid colour "..key) end
        else assert(av==bv,"Discrete property must be common across looks: "..key) end
    end
    for k in pairs(b) do assert(a[k]~=nil,"Incomplete look property "..path.."."..k) end
end
Cycle.fadeGroups={"Light","Colour","Haze","Glare","Distance","Post"}
local function smooth(u) u=math.clamp(u,0,1); return u*u*(3-2*u) end
local function groupFor(section,key,value)
    if section=="Atmosphere" then
        if key=="Haze" or key=="Glare" then return key end
        if key=="Density" or key=="Offset" then return "Distance" end
    end
    if typeof(value)=="Color3" then return "Colour" end
    if section=="Lighting" then return "Light" end
    return "Post"
end
local function blend(a,b,weights,section)
    local out={}
    for k,av in pairs(a) do
        local bv=b[k]
        if type(av)=="table" then out[k]=blend(av,bv,weights,k)
        else
            local t=weights[groupFor(section,k,av)]
            if typeof(av)=="Color3" then out[k]=av:Lerp(bv,t)
            elseif type(av)=="number" then out[k]=av+(bv-av)*t
            else out[k]=av end
        end
    end
    return out
end
function Cycle.build(presets,schedule,settings)
    assert(Cycle.finite(settings.DurationSeconds) and settings.DurationSeconds>=24 and settings.DurationSeconds<=86400,"ContinuousCycleDurationSeconds must be 24..86400")
    assert(Cycle.finite(settings.Latitude) and settings.Latitude>=-90 and settings.Latitude<=90,"Invalid continuous latitude")
    assert(Cycle.finite(settings.Sunrise) and Cycle.finite(settings.Sunset) and settings.Sunrise>=0 and settings.Sunrise<settings.Sunset and settings.Sunset<24,"Invalid sunrise/sunset")
    assert(type(settings.SkyName)=="string" and settings.SkyName~="","Missing ContinuousSkyName")
    assert(type(settings.Points)=="table" and #settings.Points>=2 and #settings.Points<=32,"Use 2..32 look milestones")
    assert(Cycle.finite(settings.RayFadeHours) and settings.RayFadeHours>0 and settings.RayFadeHours<=(24-settings.Sunset+settings.Sunrise)/2,"ContinuousRayFadeHours must be positive and fit the night interval")
    local cycle={total=settings.DurationSeconds,points={},byName={},indices={},sunrise=settings.Sunrise,sunset=settings.Sunset,rayFadeHours=settings.RayFadeHours}
    for i,stage in ipairs(schedule) do cycle.indices[stage.Preset]=i end
    local anchors={Midnight=0,Sunrise=settings.Sunrise,Sunset=settings.Sunset}
    local names={}
    for _,row in ipairs(settings.Points) do
        assert(type(row.Name)=="string" and not names[row.Name],"Duplicate milestone name"); names[row.Name]=true
        local anchor=anchors[row.Anchor]; assert(anchor~=nil,"Anchor must be Midnight, Sunrise or Sunset")
        assert(Cycle.finite(row.OffsetHours) and math.abs(row.OffsetHours)<=24,"Invalid OffsetHours")
        assert(Cycle.finite(row.HoldHours) and row.HoldHours>=0 and row.HoldHours<24,"Invalid HoldHours")
        assert(cycle.indices[row.Preset],"Preset must retain an existing schedule identity")
        local target=Cycle.preset(presets,row.Preset,settings.Latitude)
        local authored=settings.Presets and settings.Presets[row.Preset]
        assert(type(authored)=="table","Missing editable continuous preset: "..row.Preset)
        for section,properties in pairs(authored) do
            assert(type(target[section])=="table" and type(properties)=="table","Unknown preset section: "..tostring(section))
            for key,value in pairs(properties) do
                assert(key~="ClockTime" and key~="TimeOfDay" and key~="GeographicLatitude","Solar properties belong to cycle settings")
                local expected=target[section][key]
                assert(expected~=nil,"Unknown lighting property: "..section.."."..key)
                if typeof(expected)=="Color3" then
                    assert(type(value)=="table" and value.Type=="Color3","Expected Color3 attribute: "..key)
                    for _,component in ipairs({value.R,value.G,value.B}) do assert(Cycle.finite(component) and component>=0 and component<=1,"Invalid colour: "..key) end
                    assert(value.R~=nil and value.G~=nil and value.B~=nil,"Incomplete colour")
                    value=Color3.new(value.R,value.G,value.B)
                end
                assert(typeof(value)==typeof(expected),"Wrong attribute type: "..section.."."..key)
                target[section][key]=value
            end
        end
        target.Lighting.ClockTime=0; target.SkyName=settings.SkyName
        assert(target.SunRays.Intensity>=0 and target.SunRays.Intensity<=1 and target.SunRays.Spread>=0 and target.SunRays.Spread<=1,"SunRays intensity/spread must be 0..1")
        local fades={}
        for _,group in ipairs(Cycle.fadeGroups) do
            local first,last=row[group.."FadeStart"],row[group.."FadeEnd"]
            assert(Cycle.finite(first) and Cycle.finite(last) and first>=0 and first<last and last<=1,"Invalid "..group.."FadeStart/End on "..row.Name..": require 0 <= start < end <= 1")
            fades[group]={first,last}
        end
        local point={name=row.Name,preset=row.Preset,hour=(anchor+row.OffsetHours)%24,halfHold=row.HoldHours/2,target=target,fades=fades}
        cycle.points[#cycle.points+1]=point
        cycle.byName[row.Preset]=cycle.byName[row.Preset] or {}; table.insert(cycle.byName[row.Preset],point)
    end
    table.sort(cycle.points,function(a,b) return a.hour<b.hour end)
    for i,a in ipairs(cycle.points) do
        local b=cycle.points[i%#cycle.points+1]
        a.distance=(b.hour-a.hour)%24
        assert(a.distance>0 and a.halfHold+b.halfHold<a.distance,"Duplicate or overlapping milestone holds: "..a.name.." / "..b.name)
        compatible(a.target,b.target,"Look")
    end
    return cycle
end
function Cycle.sample(cycle,seconds)
    assert(Cycle.finite(seconds),"Invalid cycle position")
    local clock=(seconds%cycle.total)/cycle.total*24
    local index=#cycle.points
    for i,a in ipairs(cycle.points) do if a.hour<=clock then index=i else break end end
    local a=cycle.points[index]; local b=cycle.points[index%#cycle.points+1]
    local elapsed=(clock-a.hour)%24
    local u=math.clamp((elapsed-a.halfHold)/(a.distance-a.halfHold-b.halfHold),0,1)
    local weight=smooth(u)
    local weights={}
    for group,range in pairs(a.fades) do weights[group]=smooth((u-range[1])/(range[2]-range[1])) end
    local target=blend(a.target,b.target,weights)
    target.Lighting.ClockTime=clock
    -- Preserve full rays through both horizons, then fade in the adjacent twilight.
    -- Apply only to outdoor samples; original interior/context targets bypass this gate.
    local solar=(clock-cycle.sunrise)%24
    local daylight=cycle.sunset-cycle.sunrise
    local rayWeight=1
    if solar>daylight then
        rayWeight=math.max(1-smooth((solar-daylight)/cycle.rayFadeHours),1-smooth((24-solar)/cycle.rayFadeHours))
    end
    target.SunRays.Intensity*=rayWeight
    local preset=weight<.5 and a.preset or b.preset
    return target,{clock=clock,preset=preset,index=cycle.indices[preset],from=a.preset,to=b.preset,weight=weight,weights=weights,rayWeight=rayWeight,endsIn=(a.distance-elapsed)*cycle.total/24}
end
function Cycle.previewClock(cycle,preset)
    local points=cycle.byName[preset]; assert(points,"Preset is not in the continuous timeline")
    if #points==2 then
        local a,b=points[1].hour,points[2].hour
        local clock=(a+((b-a+12)%24-12)/2)%24
        local _,info=Cycle.sample(cycle,clock/24*cycle.total)
        if info.from==preset and info.to==preset then return clock end
    end
    return points[1].hour
end
function Cycle.isNight(clock,sunrise,sunset) return clock<sunrise or clock>=sunset end
return Cycle

end)()
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
-- Bounded read-only observer in normally started Client; pure Cycle/data chunks are prepended.
local p=game.Players.LocalPlayer
assert(p:GetAttribute("StudioVehicleSandboxActive") and p:GetAttribute("StartScreenActive")==false)
local L=game.Lighting;local runtime=p.PlayerScripts.Runtime.World
local settings=game.HttpService:JSONDecode(L:GetAttribute("LightingCycleState"))
local cycle=Cycle.build(presets,schedule,settings)
local result={done=false,samples=0,maxError={},maxSteps={},contexts={},clockJumps=0,wraps=0,errors={},switches={}}
_G.LightingContinuityObservation=result
task.spawn(function()
 local start=os.clock();local previous;local previousTime;local previousNight
 repeat
  game.RunService.Heartbeat:Wait()
  local now=os.clock();local clock=L.ClockTime
  local target=Cycle.sample(cycle,clock/24*cycle.total)
  local current={clock=clock}
  for section,values in pairs(target) do if type(values)=="table" then
   local instance=section=="Lighting" and L or L:FindFirstChild(section)
   for key,wanted in pairs(values) do
    if key~="ClockTime" and (typeof(wanted)=="Color3" or type(wanted)=="number") then
     local actual=instance[key];local id=section.."."..key
     local err=typeof(wanted)=="Color3" and math.max(math.abs(wanted.R-actual.R),math.abs(wanted.G-actual.G),math.abs(wanted.B-actual.B)) or math.abs(wanted-actual)
     result.maxError[id]=math.max(result.maxError[id] or 0,err)
     current[id]=actual
     if previous then
      local old=previous[id]
      local step=typeof(actual)=="Color3" and math.max(math.abs(actual.R-old.R),math.abs(actual.G-old.G),math.abs(actual.B-old.B)) or math.abs(actual-old)
      if not result.maxSteps[id] or step>result.maxSteps[id].delta then result.maxSteps[id]={delta=step,clock=clock,dt=now-previousTime} end
     end
    end
   end
  end end
  if previous then
   local dc=(clock-previous.clock)%24
   if clock<previous.clock-12 then result.wraps+=1 end
   if dc>(now-previousTime)*24/cycle.total+.02 then result.clockJumps+=1 end
  end
  local night=L:GetAttribute("StreetLightsOn")
  if previousNight~=nil and night~=previousNight then table.insert(result.switches,{clock=clock,night=night}) end
  result.contexts[runtime:GetAttribute("LightingContext") or "nil"]=true
  for _,err in ipairs({L:GetAttribute("LightingCycleError") or "",runtime:GetAttribute("LightingRenderError") or ""}) do if err~="" then result.errors[err]=true end end
  previous=current;previousTime=now;previousNight=night;result.samples+=1
 until now-start>=122
 result.elapsed=os.clock()-start; result.done=true
end)
return "Continuity observation started: actual renderer values versus pure targets over 122 seconds."
