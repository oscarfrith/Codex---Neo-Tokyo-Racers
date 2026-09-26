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
local settings=game.HttpService:JSONDecode([====[{"DurationSeconds": 720, "Latitude": 35, "Sunrise": 6, "Sunset": 18, "SkyName": "ContinuousSky", "RayFadeHours": 0.4, "Points": [{"Name": "NightEnd", "Preset": "ClearNight", "Anchor": "Sunrise", "OffsetHours": -4, "HoldHours": 0, "LightFadeStart": 0, "LightFadeEnd": 1, "ColourFadeStart": 0, "ColourFadeEnd": 1, "HazeFadeStart": 0, "HazeFadeEnd": 1, "GlareFadeStart": 0, "GlareFadeEnd": 1, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0, "PostFadeEnd": 1}, {"Name": "Dawn", "Preset": "FourAM", "Anchor": "Sunrise", "OffsetHours": -2.5, "HoldHours": 0.4, "LightFadeStart": 0, "LightFadeEnd": 1, "ColourFadeStart": 0, "ColourFadeEnd": 0.8, "HazeFadeStart": 0, "HazeFadeEnd": 1, "GlareFadeStart": 0, "GlareFadeEnd": 1, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0, "PostFadeEnd": 1}, {"Name": "Sunrise", "Preset": "SevenAM", "Anchor": "Sunrise", "OffsetHours": 0, "HoldHours": 0.16666666666666666, "LightFadeStart": 0.3, "LightFadeEnd": 1, "ColourFadeStart": 0.15, "ColourFadeEnd": 1, "HazeFadeStart": 0, "HazeFadeEnd": 0.7, "GlareFadeStart": 0, "GlareFadeEnd": 0.6, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0.2, "PostFadeEnd": 1}, {"Name": "DayStart", "Preset": "Day", "Anchor": "Sunrise", "OffsetHours": 3.5, "HoldHours": 0, "LightFadeStart": 0, "LightFadeEnd": 1, "ColourFadeStart": 0, "ColourFadeEnd": 1, "HazeFadeStart": 0, "HazeFadeEnd": 1, "GlareFadeStart": 0, "GlareFadeEnd": 1, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0, "PostFadeEnd": 1}, {"Name": "DayEnd", "Preset": "Day", "Anchor": "Sunset", "OffsetHours": -3.5, "HoldHours": 0, "LightFadeStart": 0, "LightFadeEnd": 0.7, "ColourFadeStart": 0, "ColourFadeEnd": 0.85, "HazeFadeStart": 0.3, "HazeFadeEnd": 1, "GlareFadeStart": 0.4, "GlareFadeEnd": 1, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0, "PostFadeEnd": 0.8}, {"Name": "Sunset", "Preset": "FivePM", "Anchor": "Sunset", "OffsetHours": 0, "HoldHours": 0.16666666666666666, "LightFadeStart": 0, "LightFadeEnd": 1, "ColourFadeStart": 0.2, "ColourFadeEnd": 1, "HazeFadeStart": 0, "HazeFadeEnd": 1, "GlareFadeStart": 0, "GlareFadeEnd": 1, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0, "PostFadeEnd": 1}, {"Name": "Dusk", "Preset": "EightPM", "Anchor": "Sunset", "OffsetHours": 2.5, "HoldHours": 0.4, "LightFadeStart": 0, "LightFadeEnd": 1, "ColourFadeStart": 0, "ColourFadeEnd": 1, "HazeFadeStart": 0, "HazeFadeEnd": 1, "GlareFadeStart": 0, "GlareFadeEnd": 1, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0, "PostFadeEnd": 1}, {"Name": "NightStart", "Preset": "ClearNight", "Anchor": "Sunset", "OffsetHours": 4, "HoldHours": 0, "LightFadeStart": 0, "LightFadeEnd": 1, "ColourFadeStart": 0, "ColourFadeEnd": 1, "HazeFadeStart": 0, "HazeFadeEnd": 1, "GlareFadeStart": 0, "GlareFadeEnd": 1, "DistanceFadeStart": 0, "DistanceFadeEnd": 1, "PostFadeStart": 0, "PostFadeEnd": 1}], "Presets": {"SevenAM": {"SunRays": {"Enabled": true, "Intensity": 0.2, "Spread": 0.9}, "DepthOfField": {"Enabled": false, "FarIntensity": 0.08399999886751175, "FocusDistance": 0.05000000074505806, "InFocusRadius": 10, "NearIntensity": 0.75}, "ColorCorrection": {"Enabled": true, "Saturation": 0.4000000059604645, "Contrast": 0.12, "TintColor": {"Type": "Color3", "R": 1.0, "G": 0.9215686274509803, "B": 0.9019607843137255}, "Brightness": 0.055}, "Atmosphere": {"Density": 0.2370000034570694, "Glare": 1, "Color": {"Type": "Color3", "R": 1.0, "G": 0.5686274509803921, "B": 0.39215686274509803}, "Decay": {"Type": "Color3", "R": 0.7058823529411765, "G": 0.49019607843137253, "B": 0.5490196078431373}, "Haze": 2.2, "Offset": 0}, "Lighting": {"ColorShift_Bottom": {"B": 0, "Type": "Color3", "G": 0, "R": 0}, "FogColor": {"B": 0.7529411911964417, "Type": "Color3", "G": 0.7529411911964417, "R": 0.7529411911964417}, "FogEnd": 100000, "EnvironmentDiffuseScale": 0.20100000500679016, "EnvironmentSpecularScale": 1, "ExposureCompensation": 0.15, "FogStart": 0, "Ambient": {"Type": "Color3", "R": 1.0, "G": 0.7058823529411765, "B": 0.6274509803921569}, "OutdoorAmbient": {"Type": "Color3", "R": 0.9411764705882353, "G": 0.6078431372549019, "B": 0.5490196078431373}, "ColorShift_Top": {"Type": "Color3", "R": 1.0, "G": 0.5686274509803921, "B": 0.39215686274509803}, "Brightness": 0.65, "ShadowSoftness": 0.20000000298023224, "GlobalShadows": true}, "Bloom": {"Threshold": 0.699999988079071, "Enabled": true, "Intensity": 0.550000011920929, "Size": 10}}, "Day": {"SunRays": {"Enabled": true, "Intensity": 0.07, "Spread": 0.9}, "DepthOfField": {"Enabled": false, "FarIntensity": 0.084, "FocusDistance": 0.05, "InFocusRadius": 10, "NearIntensity": 0.75}, "ColorCorrection": {"Enabled": true, "Saturation": 0.4000000059604645, "Contrast": 0, "TintColor": {"B": 1, "Type": "Color3", "G": 1, "R": 1}, "Brightness": 0.05000000074505806}, "Atmosphere": {"Density": 0.2199999988079071, "Glare": 0, "Color": {"B": 0.7803921699523926, "Type": "Color3", "G": 0.7803921699523926, "R": 0.7803921699523926}, "Decay": {"B": 0.4901960790157318, "Type": "Color3", "G": 0.43921568989753723, "R": 0.4156862795352936}, "Haze": 0, "Offset": 0.20000000298023224}, "Lighting": {"ColorShift_Bottom": {"B": 0, "Type": "Color3", "G": 0, "R": 0}, "FogColor": {"B": 0.7529411911964417, "Type": "Color3", "G": 0.7529411911964417, "R": 0.7529411911964417}, "FogEnd": 100000, "EnvironmentDiffuseScale": 0.47099998593330383, "EnvironmentSpecularScale": 1, "ExposureCompensation": 0.10000000149011612, "FogStart": 0, "Ambient": {"B": 1, "Type": "Color3", "G": 0.7333333492279053, "R": 0.4117647111415863}, "OutdoorAmbient": {"B": 0.9098039269447327, "Type": "Color3", "G": 0.8392156958580017, "R": 0.6117647290229797}, "ColorShift_Top": {"B": 0.8313725590705872, "Type": "Color3", "G": 0.9529411792755127, "R": 1}, "Brightness": 5.150000095367432, "ShadowSoftness": 0.20000000298023224, "GlobalShadows": true}, "Bloom": {"Threshold": 1.9040000438690186, "Enabled": true, "Intensity": 0.6499999761581421, "Size": 10}}, "ClearNight": {"SunRays": {"Enabled": true, "Intensity": 0, "Spread": 0.9}, "DepthOfField": {"Enabled": false, "FarIntensity": 0.08399999886751175, "FocusDistance": 0.05000000074505806, "InFocusRadius": 10, "NearIntensity": 0.75}, "ColorCorrection": {"Enabled": true, "Saturation": 0.20000000298023224, "Contrast": 0.30000001192092896, "TintColor": {"B": 1, "Type": "Color3", "G": 0.8196079134941101, "R": 0.7921569347381592}, "Brightness": 0.05000000074505806}, "Atmosphere": {"Density": 0.3070000112056732, "Glare": 0.45, "Color": {"B": 0.30980393290519714, "Type": "Color3", "G": 0.250980406999588, "R": 0.21568629145622253}, "Decay": {"B": 0.5333333611488342, "Type": "Color3", "G": 0.41960787773132324, "R": 0.4117647409439087}, "Haze": 4.090000152587891, "Offset": 0}, "Lighting": {"ColorShift_Bottom": {"B": 0.3529411852359772, "Type": "Color3", "G": 0.3529411852359772, "R": 0.3529411852359772}, "FogColor": {"B": 0.7529411911964417, "Type": "Color3", "G": 0.7529411911964417, "R": 0.7529411911964417}, "FogEnd": 100000, "EnvironmentDiffuseScale": 0, "EnvironmentSpecularScale": 0.23399999737739563, "ExposureCompensation": 0, "FogStart": 0, "Ambient": {"B": 0.7411764860153198, "Type": "Color3", "G": 0.5411764979362488, "R": 0.48235297203063965}, "OutdoorAmbient": {"B": 0.8862745761871338, "Type": "Color3", "G": 0.6549019813537598, "R": 0.6313725709915161}, "ColorShift_Top": {"B": 0.8313726186752319, "Type": "Color3", "G": 0.9490196704864502, "R": 1}, "Brightness": 2.7100000381469727, "ShadowSoftness": 0.20000000298023224, "GlobalShadows": true}, "Bloom": {"Threshold": 0.30000001192092896, "Enabled": true, "Intensity": 0.5, "Size": 16}}, "FivePM": {"SunRays": {"Enabled": true, "Intensity": 0.2, "Spread": 0.9}, "DepthOfField": {"Enabled": false, "FarIntensity": 0.08399999886751175, "FocusDistance": 0.05000000074505806, "InFocusRadius": 10, "NearIntensity": 0.75}, "ColorCorrection": {"Enabled": true, "Saturation": 0.4000000059604645, "Contrast": 0.12, "TintColor": {"Type": "Color3", "R": 1.0, "G": 0.9215686274509803, "B": 0.9019607843137255}, "Brightness": 0.055}, "Atmosphere": {"Density": 0.2669999897480011, "Glare": 1, "Color": {"Type": "Color3", "R": 1.0, "G": 0.5686274509803921, "B": 0.39215686274509803}, "Decay": {"Type": "Color3", "R": 0.7058823529411765, "G": 0.49019607843137253, "B": 0.5490196078431373}, "Haze": 2.2, "Offset": 0}, "Lighting": {"ColorShift_Bottom": {"B": 0, "Type": "Color3", "G": 0, "R": 0}, "FogColor": {"B": 0.7529411911964417, "Type": "Color3", "G": 0.7529411911964417, "R": 0.7529411911964417}, "FogEnd": 100000, "EnvironmentDiffuseScale": 0.20100000500679016, "EnvironmentSpecularScale": 1, "ExposureCompensation": 0.15, "FogStart": 0, "Ambient": {"Type": "Color3", "R": 1.0, "G": 0.7058823529411765, "B": 0.6274509803921569}, "OutdoorAmbient": {"Type": "Color3", "R": 0.9411764705882353, "G": 0.6078431372549019, "B": 0.5490196078431373}, "ColorShift_Top": {"Type": "Color3", "R": 1.0, "G": 0.5686274509803921, "B": 0.39215686274509803}, "Brightness": 0.65, "ShadowSoftness": 0.20000000298023224, "GlobalShadows": true}, "Bloom": {"Threshold": 0.699999988079071, "Enabled": true, "Intensity": 0.550000011920929, "Size": 10}}, "FourAM": {"SunRays": {"Enabled": true, "Intensity": 0, "Spread": 0.9}, "DepthOfField": {"Enabled": false, "FarIntensity": 0.08399999886751175, "FocusDistance": 0.05000000074505806, "InFocusRadius": 10, "NearIntensity": 0.75}, "ColorCorrection": {"Enabled": true, "Saturation": 0.20000000298023224, "Contrast": 0.20000000298023224, "TintColor": {"B": 1, "Type": "Color3", "G": 0.8509804606437683, "R": 0.988235354423523}, "Brightness": 0}, "Atmosphere": {"Density": 0.3070000112056732, "Glare": 1.5, "Color": {"Type": "Color3", "R": 0.5686274509803921, "G": 0.39215686274509803, "B": 0.6078431372549019}, "Decay": {"Type": "Color3", "R": 0.6470588235294118, "G": 0.5098039215686274, "B": 0.7254901960784313}, "Haze": 4.090000152587891, "Offset": 0}, "Lighting": {"ColorShift_Bottom": {"B": 0, "Type": "Color3", "G": 0, "R": 0}, "FogColor": {"B": 0.7529411911964417, "Type": "Color3", "G": 0.7529411911964417, "R": 0.7529411911964417}, "FogEnd": 100000, "EnvironmentDiffuseScale": 0, "EnvironmentSpecularScale": 0.23399999737739563, "ExposureCompensation": 0.10999999940395355, "FogStart": 0, "Ambient": {"B": 1, "Type": "Color3", "G": 0.5254902243614197, "R": 0.41960787773132324}, "OutdoorAmbient": {"B": 0.9098039865493774, "Type": "Color3", "G": 0.7019608020782471, "R": 0.8588235974311829}, "ColorShift_Top": {"B": 0.8313726186752319, "Type": "Color3", "G": 0.9490196704864502, "R": 1}, "Brightness": 2.4000000953674316, "ShadowSoftness": 0.20000000298023224, "GlobalShadows": true}, "Bloom": {"Threshold": 0.30000001192092896, "Enabled": true, "Intensity": 0.4000000059604645, "Size": 16}}, "EightPM": {"SunRays": {"Enabled": true, "Intensity": 0, "Spread": 0.9}, "DepthOfField": {"Enabled": false, "FarIntensity": 0.08399999886751175, "FocusDistance": 0.05000000074505806, "InFocusRadius": 10, "NearIntensity": 0.75}, "ColorCorrection": {"Enabled": true, "Saturation": 0.20000000298023224, "Contrast": 0.20000000298023224, "TintColor": {"B": 1, "Type": "Color3", "G": 0.8509804606437683, "R": 0.988235354423523}, "Brightness": 0}, "Atmosphere": {"Density": 0.3070000112056732, "Glare": 1.5, "Color": {"Type": "Color3", "R": 0.5686274509803921, "G": 0.39215686274509803, "B": 0.6078431372549019}, "Decay": {"Type": "Color3", "R": 0.6470588235294118, "G": 0.5098039215686274, "B": 0.7254901960784313}, "Haze": 4.090000152587891, "Offset": 0}, "Lighting": {"ColorShift_Bottom": {"B": 0, "Type": "Color3", "G": 0, "R": 0}, "FogColor": {"B": 0.7529411911964417, "Type": "Color3", "G": 0.7529411911964417, "R": 0.7529411911964417}, "FogEnd": 100000, "EnvironmentDiffuseScale": 0, "EnvironmentSpecularScale": 0.23399999737739563, "ExposureCompensation": 0.10999999940395355, "FogStart": 0, "Ambient": {"B": 1, "Type": "Color3", "G": 0.5254902243614197, "R": 0.41960787773132324}, "OutdoorAmbient": {"B": 0.9098039865493774, "Type": "Color3", "G": 0.7019608020782471, "R": 0.8588235974311829}, "ColorShift_Top": {"B": 0.8313726186752319, "Type": "Color3", "G": 0.9490196704864502, "R": 1}, "Brightness": 2.4000000953674316, "ShadowSoftness": 0.20000000298023224, "GlobalShadows": true}, "Bloom": {"Threshold": 0.30000001192092896, "Enabled": true, "Intensity": 0.4000000059604645, "Size": 16}}}}]====])
-- Pure chunks only: no gameplay-module require or environment writes.
local checks=0
local function check(ok,message) assert(ok,message); checks+=1 end
local function close(a,b,path)
    if type(a)=="table" then for k,v in pairs(a) do close(v,b[k],path.."."..k) end
    elseif typeof(a)=="Color3" then check((Vector3.new(a.R,a.G,a.B)-Vector3.new(b.R,b.G,b.B)).Magnitude<1e-6,path)
    elseif type(a)=="number" then check(math.abs(a-b)<1e-6,path)
    else check(a==b,path) end
end
local function appearance(target) target.Lighting.ClockTime=nil; target.SunRays.Intensity=nil; return target end
local function clone(v) if type(v)~="table" then return v end; local out={}; for k,x in pairs(v) do out[k]=clone(x) end; return out end
local authoredCycle=Cycle.build(presets,schedule,settings)
check(authoredCycle.total==720,"Twelve minute cycle")
local normalized=clone(settings); normalized.DurationSeconds=120
local cycle=Cycle.build(presets,schedule,normalized)
local anchors={{0,"ClearNight"},{3.5,"FourAM"},{6,"SevenAM"},{12,"Day"},{18,"FivePM"},{20.5,"EightPM"}}
for _,row in ipairs(anchors) do
    local expected=Cycle.preset(presets,row[2],35); expected.SkyName="ContinuousSky"
    for section,values in pairs(settings.Presets[row[2]]) do for key,value in pairs(values) do
        expected[section][key]=type(value)=="table" and Color3.new(value.R,value.G,value.B) or value
    end end
    local target=Cycle.sample(cycle,row[1]*5)
    close(appearance(expected),appearance(target),row[2])
    check(Cycle.previewClock(cycle,row[2])==row[1],"Preview "..row[2])
end
for _,hour in ipairs({3.5,6,18,20.5}) do
    local half=hour==6 or hour==18; half=half and .08 or .19
    close(appearance(Cycle.sample(cycle,(hour-half)*5)),appearance(Cycle.sample(cycle,(hour+half)*5)),"Full look hold")
end
close(appearance(Cycle.sample(cycle,9.5*5)),appearance(Cycle.sample(cycle,14.5*5)),"Day hold")
close(appearance(Cycle.sample(cycle,22*5)),appearance(Cycle.sample(cycle,2*5)),"Night hold across midnight")
for _,hour in ipairs({6,18}) do
    close(appearance(Cycle.sample(cycle,(hour-1/12+1e-5)*5)),appearance(Cycle.sample(cycle,(hour+1/12-1e-5)*5)),"Five-second production hold spanning horizon")
end
-- The targeted palette changes must not silently alter the remaining original artwork.
for name,values in pairs(settings.Presets) do
    local original=Cycle.preset(presets,name,35)
    for section,props in pairs(values) do for key,value in pairs(props) do
        local allowed=section=="SunRays" or ((name=="FivePM" or name=="SevenAM") and
            ((section=="Atmosphere" and ({Color=true,Decay=true,Haze=true,Glare=true})[key]) or
            (section=="Lighting" and ({Brightness=true,ExposureCompensation=true,Ambient=true,OutdoorAmbient=true,ColorShift_Top=true})[key]) or
            (section=="ColorCorrection" and ({TintColor=true,Brightness=true,Contrast=true})[key]))) or
            ((name=="FourAM" or name=="EightPM") and section=="Atmosphere" and (key=="Color" or key=="Decay" or key=="Glare")) or
            (name=="ClearNight" and section=="Atmosphere" and key=="Glare")
        if not allowed then close(type(value)=="table" and Color3.new(value.R,value.G,value.B) or value,original[section][key],"Unchanged artwork "..name..section..key) end
    end end
end
local previous
for tick=0,1200 do
    local second=tick/10
    local target,info=Cycle.sample(cycle,second)
    if previous then check(math.abs((info.clock-previous)%24-.02)<1e-8,"Uniform solar movement") end
    previous=info.clock
    check(info.preset~="TenAM" and info.preset~="ThreePM","Removed daytime look stages")
    for section,values in pairs(target) do if type(values)=="table" then for key,value in pairs(values) do
        if type(value)=="number" then check(Cycle.finite(value),section..key)
        elseif typeof(value)=="Color3" then check(value.R>=0 and value.R<=1 and value.G>=0 and value.G<=1 and value.B>=0 and value.B<=1,"Colour gamut") end
    end end end
    check(target.Atmosphere.Density>=0 and target.Atmosphere.Density<=1,"Valid density")
    check(target.SunRays.Enabled==true and target.SunRays.Intensity>=0 and target.SunRays.Intensity<=.2,"Stable rays flag / bounded intensity")
    if info.clock<5.6 or info.clock>18.4 then check(target.SunRays.Intensity==0,"No deep-night rays") end
    for _,w in pairs(info.weights) do check(w>=0 and w<=1,"Bounded group curve") end
end
for _,point in ipairs(cycle.points) do
    for _,hour in ipairs({point.hour-point.halfHold,point.hour,point.hour+point.halfHold}) do
        local a=Cycle.sample(cycle,hour*5-1e-5)
        local b=Cycle.sample(cycle,hour*5+1e-5)
        close(appearance(a),appearance(b),"Continuous milestone/hold boundary")
    end
end
local production=clone(settings); production.DurationSeconds=900
local slow=Cycle.build(presets,schedule,production)
close(Cycle.sample(cycle,87.45),Cycle.sample(slow,87.45*7.5),"Duration scaling")
close(Cycle.sample(cycle,87.45),Cycle.sample(authoredCycle,87.45*6),"Twelve-minute scaling")
for _,index in ipairs({3,6}) do
    check(math.abs(authoredCycle.points[index].halfHold*2*authoredCycle.total/24-5)<1e-8,"Warm hold lasts five real seconds")
end
close(Cycle.sample(cycle,87.45),Cycle.sample(cycle,87.45+120*1000),"Shared epoch late-join equivalence")
local function rejects(edit,message) local bad=clone(settings); edit(bad); check(not pcall(Cycle.build,presets,schedule,bad),message) end
rejects(function(s) s.DurationSeconds=0 end,"Reject duration")
rejects(function(s) s.Points[6].HoldHours=10 end,"Reject overlapping holds")
rejects(function(s) s.Points[1].Anchor="Evening" end,"Reject unknown anchor")
rejects(function(s) s.Presets.Day.Atmosphere.Density="foggy" end,"Reject wrong type")
rejects(function(s) s.Presets.Day.Atmosphere.Color.R=2 end,"Reject invalid colour")
rejects(function(s) s.Presets.Day.Lighting.ClockTime=12 end,"Reject look clock writer")
rejects(function(s) s.Presets.Day.SunRays.Enabled=false end,"Reject discrete effect flash")
rejects(function(s) s.Points[5].LightFadeStart=.7 end,"Reject empty fade")
rejects(function(s) s.Points[5].HazeFadeStart=-.1 end,"Reject negative fade start")
rejects(function(s) s.Points[5].GlareFadeEnd=1.1 end,"Reject fade end past milestone")
rejects(function(s) s.Points[5].ColourFadeEnd=0/0 end,"Reject nonfinite fade")
rejects(function(s) s.Points[5].PostFadeEnd=nil end,"Reject deleted fade")
rejects(function(s) s.RayFadeHours=0 end,"Reject ray gate zero division")
rejects(function(s) s.Presets.Day.SunRays.Intensity=2 end,"Reject ray intensity outside bounds")
-- Curve intervals, not separate timers: all their start/end seams are continuous.
for _,point in ipairs(cycle.points) do for _,range in pairs(point.fades) do for _,edge in ipairs(range) do
        local hour=point.hour+point.halfHold+edge*(point.distance-point.halfHold-cycle.points[table.find(cycle.points,point)%#cycle.points+1].halfHold)
        close(appearance(Cycle.sample(cycle,hour*5-1e-8)),appearance(Cycle.sample(cycle,hour*5+1e-8)),"Fade seam")
end end end
for step=1,99 do
    local u=step/100
    local daylightSpan=18-1/12-14.5
    local _,ei=Cycle.sample(cycle,(14.5+daylightSpan*u)*5)
    local _,mi=Cycle.sample(cycle,(9.5-daylightSpan*u)*5)
    for _,group in ipairs(Cycle.fadeGroups) do check(math.abs(ei.weights[group]+mi.weights[group]-1)<1e-8,"Mirrored morning "..group) end
    local twilightSpan=20.3-(18+1/12)
    local evening=Cycle.sample(cycle,(18+1/12+twilightSpan*u)*5)
    local morning=Cycle.sample(cycle,(6-1/12-twilightSpan*u)*5)
    close(evening.Atmosphere.Color,morning.Atmosphere.Color,"Reversed red-pink-purple colour path")
    close(evening.Atmosphere.Decay,morning.Atmosphere.Decay,"Reversed opposite horizon colour path")
end
local shoulder,info=Cycle.sample(cycle,(14.5+(18-1/12-14.5)*5/9)*5)
check(info.weights.Light>info.weights.Colour and info.weights.Colour>info.weights.Haze and info.weights.Haze>info.weights.Glare,"Daylight drops before strong scattering")
check(shoulder.Lighting.Brightness<1.2 and shoulder.Atmosphere.Haze<.75 and shoulder.Atmosphere.Glare<.2,"Regression: avoid simultaneous bright daylight and strong scattering")
for _,hour in ipairs({6-1/12,5.95,6,6.05,6+1/12,18-1/12,17.95,18,18.05,18+1/12}) do
    local t=Cycle.sample(cycle,hour*5)
    check(t.Atmosphere.Color.R>.99 and t.Atmosphere.Color.G>.55 and t.Atmosphere.Color.B<.4,"Red-orange before and after horizon")
end
check(math.abs(Cycle.sample(cycle,12*5).SunRays.Intensity-.07)<1e-8,"Stronger daytime rays")
check(Cycle.sample(cycle,17*5).SunRays.Intensity>.19,"Stronger golden hour rays")
for _,hour in ipairs({6,18}) do check(math.abs(Cycle.sample(cycle,hour*5).SunRays.Intensity-.2)<1e-8,"Full peak rays at horizon") end
for _,hour in ipairs({5.6,6,18,18.4}) do
    local a=Cycle.sample(cycle,hour*5-1e-5).SunRays.Intensity
    local b=Cycle.sample(cycle,hour*5+1e-5).SunRays.Intensity
    check(math.abs(a-b)<1e-8,"Continuous outer twilight ray envelope")
end
for i=0,100 do
    local offset=i/100*.4
    local a,ai=Cycle.sample(cycle,(6-offset)*5)
    local b,bi=Cycle.sample(cycle,(18+offset)*5)
    check(math.abs(ai.rayWeight-bi.rayWeight)<1e-10,"Mirrored outside-horizon rays")
end
check(Cycle.isNight(5.999,6,18) and not Cycle.isNight(6,6,18),"Sunrise switch")
check(not Cycle.isNight(17.999,6,18) and Cycle.isNight(18,6,18),"Sunset switch")
return game.HttpService:JSONEncode({pass=true,checks=checks,samples=1201,cycleSeconds=720,normalizedTestSeconds=120,fullPresets=6,holdBoundaries=24,curveGroups=6,rayHorizonPeak=true,rayNightGate=true,mirroredMorning=true})
