-- Pure calculation: no services, tasks, instances or gameplay startup.
local Cycle = {}
local DEFAULTS = {
    Atmosphere={Color=Color3.fromRGB(199,199,199),Decay=Color3.fromRGB(106,112,125),Density=.22,Glare=0,Haze=0,Offset=.2},
    Bloom={Enabled=true,Intensity=.65,Size=10,Threshold=1.904},
    ColorCorrection={Enabled=true,Brightness=.05,Contrast=0,Saturation=.4,TintColor=Color3.new(1,1,1)},
    DepthOfField={Enabled=false,FarIntensity=.084,FocusDistance=.05,InFocusRadius=10,NearIntensity=.75},
    SunRays={Enabled=false,Intensity=.05,Spread=.713},
}
function Cycle.finite(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for k,v in pairs(value) do result[k]=copy(v) end
    return result
end
local function overlay(target,values)
    for k,v in pairs(values or {}) do
        if type(v)=="table" then target[k]=target[k] or {}; overlay(target[k],v) else target[k]=v end
    end
    return target
end
function Cycle.preset(presets,name,latitude)
    assert(type(presets[name])=="table","Unknown lighting preset: "..tostring(name))
    local result=overlay(copy(DEFAULTS),presets[name])
    result.Lighting.GeographicLatitude=latitude
    return result
end
function Cycle.blend(a,b,alpha)
    local result={}
    for key,av in pairs(a) do
        local bv=b[key]
        if type(av)=="table" then result[key]=Cycle.blend(av,bv,alpha)
        elseif typeof(av)=="Color3" then result[key]=av:Lerp(bv,alpha)
        elseif type(av)=="number" then result[key]=av+(bv-av)*alpha
        else result[key]=av end
    end
    return result
end
local function harmonic(previous,nextSlope,previousDuration,nextDuration)
    local w1=2*nextDuration+previousDuration
    local w2=nextDuration+2*previousDuration
    return (w1+w2)/(w1/previous+w2/nextSlope)
end
function Cycle.build(presets,schedule,definition,base,latitude)
    assert(Cycle.finite(base) and base>=1 and base<=86400,"Invalid BaseDurationSeconds")
    assert(Cycle.finite(latitude) and latitude>=-90 and latitude<=90,"Invalid continuous latitude")
    assert(#schedule>=2,"Lighting schedule too short")
    local result={frames={},total=0,byName={}}
    for i,stage in ipairs(schedule) do
        local weight=stage.DurationWeight
        assert(Cycle.finite(weight) and weight>0,"Invalid stage duration")
        local clock=definition.ClockHours[stage.Preset]
        assert(Cycle.finite(clock),"Missing continuous clock: "..stage.Preset)
        assert(not result.byName[stage.Preset],"Duplicate stage")
        if i>1 then assert(clock>result.frames[i-1].clock,"Clock must move forwards") end
        local target=Cycle.preset(presets,stage.Preset,latitude)
        overlay(target,definition.Overrides[stage.Preset])
        target.Lighting.ClockTime=clock%24
        -- One stable outdoor sky; context owners may select original authored skies.
        target.SkyName="DaySky"
        local frame={name=stage.Preset,start=result.total,duration=base*weight,clock=clock,target=target}
        result.frames[i]=frame; result.byName[stage.Preset]=frame
        result.total+=frame.duration
    end
    local frames=result.frames; local n=#frames
    assert(frames[n].clock<frames[1].clock+24,"Cycle must span less than one day before wrap")
    for i,frame in ipairs(frames) do
        local following=frames[i%n+1]
        local nextClock=following.clock+(i==n and 24 or 0)
        frame.slope=(nextClock-frame.clock)/frame.duration
    end
    for i,frame in ipairs(frames) do
        local previous=frames[(i-2)%n+1]
        frame.tangent=harmonic(previous.slope,frame.slope,previous.duration,frame.duration)
    end
    return result
end
function Cycle.position(cycle,seconds)
    assert(Cycle.finite(seconds),"Invalid cycle position")
    local position=seconds%cycle.total
    for i,frame in ipairs(cycle.frames) do
        if position<frame.start+frame.duration then return i,(position-frame.start)/frame.duration,position end
    end
    return 1,0,0
end
function Cycle.sample(cycle,seconds)
    local i,u,position=Cycle.position(cycle,seconds)
    local a=cycle.frames[i]; local b=cycle.frames[i%#cycle.frames+1]
    local nextClock=b.clock+(i==#cycle.frames and 24 or 0)
    local u2,u3=u*u,u*u*u
    local clock=(2*u3-3*u2+1)*a.clock+(u3-2*u2+u)*a.duration*a.tangent
        +(-2*u3+3*u2)*nextClock+(u3-u2)*a.duration*b.tangent
    -- Shape-preserving Hermite clock and bounded smoothstep property blends.
    local target=Cycle.blend(a.target,b.target,u2*(3-2*u))
    target.Lighting.ClockTime=clock%24
    -- Residual glare below the horizon produces a bright fog pulse at dusk.
    -- Fade scattering before the horizon, independently of the palette blend.
    local sunHeight=math.clamp(math.sin((clock%24-6)*math.pi/12)/.25,0,1)
    target.Atmosphere.Glare*=sunHeight*sunHeight*(3-2*sunHeight)
    return target,{index=i,preset=a.name,alpha=u,position=position,clock=clock%24,unwrappedClock=clock,endsIn=a.duration*(1-u)}
end
function Cycle.isNight(clock,sunrise,sunset)
    return clock<sunrise or clock>=sunset
end
return Cycle
