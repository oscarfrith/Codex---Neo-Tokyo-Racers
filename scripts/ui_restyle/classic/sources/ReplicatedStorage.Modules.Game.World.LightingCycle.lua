-- Pure solar motion and authored-look evaluation. No services, tasks or instances.
local Cycle={}
local DEFAULTS={
    Atmosphere={Color=Color3.fromRGB(199,199,199),Decay=Color3.fromRGB(106,112,125),Density=.22,Glare=0,Haze=0,Offset=.2},
    Bloom={Enabled=true,Intensity=.65,Size=10,Threshold=1.904},
    ColorCorrection={Enabled=true,Brightness=.05,Contrast=0,Saturation=.4,TintColor=Color3.new(1,1,1)},
    DepthOfField={Enabled=false,FarIntensity=.084,FocusDistance=.05,InFocusRadius=10,NearIntensity=.75},
    SunRays={Enabled=false,Intensity=.05,Spread=.713},
    -- Cover 0 draws nothing, so looks without a Clouds section are unchanged.
    Clouds={Enabled=true,Cover=0,Density=.3,Color=Color3.new(1,1,1)},
}
local BLACK=Color3.new(0,0,0)
local VEIL_HAZE=5
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
-- Roblox: sun direction = (-sin H cos phi, cos H cos phi, sin phi), H=(ClockTime-12)*15 deg, phi=latitude-23.5 deg.
-- Returns the SkyboxOrientation yaw that puts art baked at azimuth 0 (-Z) under the sun.
local function sunYaw(clock,latitude)
    local H=math.rad((clock-12)*15); local phi=math.rad(latitude-23.5)
    return math.deg(math.atan2(math.sin(H)*math.cos(phi),-math.sin(phi)))
end
local function clockDistance(a,b) local d=math.abs(a-b)%24; return math.min(d,24-d) end
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
    cycle.latitude=settings.Latitude; cycle.skyName=settings.SkyName
    cycle.followSun=settings.SkyFollowsSun==true
    assert(not cycle.followSun or settings.Sunset-settings.Sunrise>2,"ContinuousSkyFollowsSun needs more than two daylight hours")
    if settings.NightSkyName~=nil then
        local first,last,veil=settings.NightSkyStart,settings.NightSkyEnd,settings.NightSkyVeilHours
        assert(type(settings.NightSkyName)=="string" and settings.NightSkyName~="","Invalid ContinuousNightSkyName")
        assert(Cycle.finite(first) and Cycle.finite(last) and first>settings.Sunset and first<24 and last>=0 and last<settings.Sunrise,"Night sky must start after sunset and end before sunrise")
        assert(Cycle.finite(veil) and veil>=0 and veil<=math.min(first-settings.Sunset,settings.Sunrise-last),"NightSkyVeilHours must fit between the horizon and the sky change")
        -- The same haze colour is much brighter under the day-for-night sun than under the real night before it,
        -- so each side of the change has its own colour; tune the pair until the two sides match on screen.
        local function veilColour(value)
            if value==nil then return BLACK end
            assert(type(value)=="table" and value.Type=="Color3","Night sky veil colours must be Color3")
            for _,component in ipairs({value.R,value.G,value.B}) do assert(Cycle.finite(component) and component>=0 and component<=1,"Invalid night sky veil colour") end
            return Color3.new(value.R,value.G,value.B)
        end
        cycle.night={name=settings.NightSkyName,first=first,last=last,veil=veil,before=veilColour(settings.NightSkyVeilColorBefore),after=veilColour(settings.NightSkyVeilColorAfter)}
    end
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
    -- Night art: Roblox dims any skybox while the sun is down, so the night sky is shown day-for-night. The engine
    -- clock moves twelve hours, which puts the sun where the moon was (same light direction); the night template
    -- draws that sun as the moon. info.clock stays the game clock. The art cannot cross-fade, so the change happens
    -- behind a veil: haze up and one flat colour, no key light, sky fill and reflections dipped.
    local night=cycle.night
    local nightSky,veil=false,0
    if night then
        nightSky=(clock-night.first)%24<(night.last-night.first)%24
        if nightSky then target.Lighting.ClockTime=(clock+12)%24 end
        if night.veil>0 then veil=1-smooth(math.min(clockDistance(clock,night.first),clockDistance(clock,night.last))/night.veil) end
        if veil>0 then
            local light,air=target.Lighting,target.Atmosphere
            light.Brightness*=1-veil
            light.EnvironmentDiffuseScale*=1-.9*veil; light.EnvironmentSpecularScale*=1-.9*veil
            local tint=nightSky and night.after or night.before
            air.Color=air.Color:Lerp(tint,veil); air.Decay=air.Decay:Lerp(tint,veil)
            air.Glare*=1-veil; air.Haze+=math.max(0,VEIL_HAZE-air.Haze)*veil
            target.Clouds.Color=target.Clouds.Color:Lerp(BLACK,veil)
        end
    end
    target.SkyName=nightSky and night.name or cycle.skyName
    target.SkyYaw=nil
    if cycle.followSun and not nightSky then target.SkyYaw=Cycle.skyYaw(cycle,clock) end
    local preset=weight<.5 and a.preset or b.preset
    return target,{sky=target.SkyName,veil=veil,clock=clock,preset=preset,index=cycle.indices[preset],from=a.preset,to=b.preset,weight=weight,weights=weights,rayWeight=rayWeight,endsIn=(a.distance-elapsed)*cycle.total/24}
end
-- Day art keeps its baked glow at the sunrise side until an hour after sunrise, turns once through the midday
-- sun's side, and sits at the sunset side from an hour before sunset. Following the sun exactly would spin the
-- sky at noon, when the sun is nearly overhead.
function Cycle.skyYaw(cycle,clock)
    local rise,set=sunYaw(cycle.sunrise,cycle.latitude),sunYaw(cycle.sunset,cycle.latitude)
    local first,last=cycle.sunrise+1,cycle.sunset-1
    if clock<=first then return rise end
    if clock>=last then return set end
    local turn=(set-rise+180)%360-180
    return rise+turn*smooth((clock-first)/(last-first))
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
