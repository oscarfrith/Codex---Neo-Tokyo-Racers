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
local function blend(a,b,t)
    if t<=0 then return copy(a) elseif t>=1 then return copy(b) end
    local out={}
    for k,av in pairs(a) do
        local bv=b[k]
        if type(av)=="table" then out[k]=blend(av,bv,t)
        elseif typeof(av)=="Color3" then out[k]=av:Lerp(bv,t)
        elseif type(av)=="number" then out[k]=av+(bv-av)*t
        else out[k]=av end
    end
    return out
end
function Cycle.build(presets,schedule,settings)
    assert(Cycle.finite(settings.DurationSeconds) and settings.DurationSeconds>=24 and settings.DurationSeconds<=86400,"ContinuousCycleDurationSeconds must be 24..86400")
    assert(Cycle.finite(settings.Latitude) and settings.Latitude>=-90 and settings.Latitude<=90,"Invalid continuous latitude")
    assert(Cycle.finite(settings.Sunrise) and Cycle.finite(settings.Sunset) and settings.Sunrise>=0 and settings.Sunrise<settings.Sunset and settings.Sunset<24,"Invalid sunrise/sunset")
    assert(type(settings.SkyName)=="string" and settings.SkyName~="","Missing ContinuousSkyName")
    assert(type(settings.Points)=="table" and #settings.Points>=2 and #settings.Points<=32,"Use 2..32 look milestones")
    local cycle={total=settings.DurationSeconds,points={},byName={},indices={}}
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
        local point={name=row.Name,preset=row.Preset,hour=(anchor+row.OffsetHours)%24,halfHold=row.HoldHours/2,target=target}
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
    local weight=u*u*(3-2*u)
    local target=blend(a.target,b.target,weight)
    target.Lighting.ClockTime=clock
    local preset=weight<.5 and a.preset or b.preset
    return target,{clock=clock,preset=preset,index=cycle.indices[preset],from=a.preset,to=b.preset,weight=weight,endsIn=(a.distance-elapsed)*cycle.total/24}
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
