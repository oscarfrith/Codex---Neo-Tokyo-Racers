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
