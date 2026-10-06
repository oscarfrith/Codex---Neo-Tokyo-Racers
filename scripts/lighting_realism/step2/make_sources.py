"""Builds after/*.lua from before/*.lua by exact, single-occurrence anchor edits."""
from pathlib import Path
HERE = Path(__file__).resolve().parent
def edit(name, pairs):
    text = (HERE / 'before' / name).read_bytes().decode('utf8')
    for old, new in pairs:
        assert text.count(old) == 1, (name, old[:60], text.count(old))
        text = text.replace(old, new)
    (HERE / 'after' / name).write_bytes(text.encode('utf8'))

edit('LightingCycleDefinition.lua', [(
"        ManualClockTime=config:GetAttribute(\"ContinuousManualClockTime\"),\n",
"        ManualClockTime=config:GetAttribute(\"ContinuousManualClockTime\"),\n"
"        -- Optional night sky art (absent: one sky all day, as before).\n"
"        NightSkyName=config:GetAttribute(\"ContinuousNightSkyName\"),\n"
"        NightSkyStart=config:GetAttribute(\"NightSkyStartClockTime\"),NightSkyEnd=config:GetAttribute(\"NightSkyEndClockTime\"),\n"
"        NightSkyVeilHours=config:GetAttribute(\"NightSkyVeilHours\"),\n"
"        SkyFollowsSun=config:GetAttribute(\"ContinuousSkyFollowsSun\")==true,\n")])

edit('LightingServer.lua', [(
"        assert(sky and sky:IsA(\"Sky\"),\"ContinuousSkyName must name an existing sky template\")\n",
"        assert(sky and sky:IsA(\"Sky\"),\"ContinuousSkyName must name an existing sky template\")\n"
"        if candidate.NightSkyName~=nil then\n"
"            local nightSky=skyPresets:FindFirstChild(candidate.NightSkyName)\n"
"            assert(nightSky and nightSky:IsA(\"Sky\"),\"ContinuousNightSkyName must name an existing sky template\")\n"
"        end\n")])

edit('LightingCycle.lua', [
("    SunRays={Enabled=false,Intensity=.05,Spread=.713},\n}\n",
 "    SunRays={Enabled=false,Intensity=.05,Spread=.713},\n"
 "    -- Cover 0 draws nothing, so looks without a Clouds section are unchanged.\n"
 "    Clouds={Enabled=true,Cover=0,Density=.3,Color=Color3.new(1,1,1)},\n}\n"
 "local BLACK=Color3.new(0,0,0)\n"
 "local VEIL_HAZE=5\n"),
("local function groupFor(section,key,value)\n",
 "-- Roblox: sun direction = (-sin H cos phi, cos H cos phi, sin phi), H=(ClockTime-12)*15 deg, phi=latitude-23.5 deg.\n"
 "-- Returns the SkyboxOrientation yaw that puts art baked at azimuth 0 (-Z) under the sun.\n"
 "local function sunYaw(clock,latitude)\n"
 "    local H=math.rad((clock-12)*15); local phi=math.rad(latitude-23.5)\n"
 "    return math.deg(math.atan2(math.sin(H)*math.cos(phi),-math.sin(phi)))\n"
 "end\n"
 "local function clockDistance(a,b) local d=math.abs(a-b)%24; return math.min(d,24-d) end\n"
 "local function groupFor(section,key,value)\n"),
("    for i,stage in ipairs(schedule) do cycle.indices[stage.Preset]=i end\n",
 "    for i,stage in ipairs(schedule) do cycle.indices[stage.Preset]=i end\n"
 "    cycle.latitude=settings.Latitude; cycle.skyName=settings.SkyName\n"
 "    cycle.followSun=settings.SkyFollowsSun==true\n"
 "    assert(not cycle.followSun or settings.Sunset-settings.Sunrise>2,\"ContinuousSkyFollowsSun needs more than two daylight hours\")\n"
 "    if settings.NightSkyName~=nil then\n"
 "        local first,last,veil=settings.NightSkyStart,settings.NightSkyEnd,settings.NightSkyVeilHours\n"
 "        assert(type(settings.NightSkyName)==\"string\" and settings.NightSkyName~=\"\",\"Invalid ContinuousNightSkyName\")\n"
 "        assert(Cycle.finite(first) and Cycle.finite(last) and first>settings.Sunset and first<24 and last>=0 and last<settings.Sunrise,\"Night sky must start after sunset and end before sunrise\")\n"
 "        assert(Cycle.finite(veil) and veil>=0 and veil<=math.min(first-settings.Sunset,settings.Sunrise-last),\"NightSkyVeilHours must fit between the horizon and the sky change\")\n"
 "        cycle.night={name=settings.NightSkyName,first=first,last=last,veil=veil}\n"
 "    end\n"),
("    target.SunRays.Intensity*=rayWeight\n",
 "    target.SunRays.Intensity*=rayWeight\n"
 "    -- Night art: Roblox dims any skybox while the sun is down, so the night sky is shown day-for-night. The engine\n"
 "    -- clock moves twelve hours, which puts the sun where the moon was (same light direction); the night template\n"
 "    -- draws that sun as the moon. info.clock stays the game clock. The art cannot cross-fade, so the change happens\n"
 "    -- behind a veil: haze up and black, no key light, sky fill and reflections dipped.\n"
 "    local night=cycle.night\n"
 "    local nightSky,veil=false,0\n"
 "    if night then\n"
 "        nightSky=(clock-night.first)%24<(night.last-night.first)%24\n"
 "        if nightSky then target.Lighting.ClockTime=(clock+12)%24 end\n"
 "        if night.veil>0 then veil=1-smooth(math.min(clockDistance(clock,night.first),clockDistance(clock,night.last))/night.veil) end\n"
 "        if veil>0 then\n"
 "            local light,air=target.Lighting,target.Atmosphere\n"
 "            light.Brightness*=1-veil\n"
 "            light.EnvironmentDiffuseScale*=1-.9*veil; light.EnvironmentSpecularScale*=1-.9*veil\n"
 "            air.Color=air.Color:Lerp(BLACK,veil); air.Decay=air.Decay:Lerp(BLACK,veil)\n"
 "            air.Glare*=1-veil; air.Haze+=math.max(0,VEIL_HAZE-air.Haze)*veil\n"
 "            target.Clouds.Color=target.Clouds.Color:Lerp(BLACK,veil)\n"
 "        end\n"
 "    end\n"
 "    target.SkyName=nightSky and night.name or cycle.skyName\n"
 "    target.SkyYaw=nil\n"
 "    if cycle.followSun and not nightSky then target.SkyYaw=Cycle.skyYaw(cycle,clock) end\n"),
("    return target,{clock=clock,preset=preset,",
 "    return target,{sky=target.SkyName,veil=veil,clock=clock,preset=preset,"),
("function Cycle.previewClock(cycle,preset)\n",
 "-- Day art keeps its baked glow at the sunrise side until an hour after sunrise, turns once through the midday\n"
 "-- sun's side, and sits at the sunset side from an hour before sunset. Following the sun exactly would spin the\n"
 "-- sky at noon, when the sun is nearly overhead.\n"
 "function Cycle.skyYaw(cycle,clock)\n"
 "    local rise,set=sunYaw(cycle.sunrise,cycle.latitude),sunYaw(cycle.sunset,cycle.latitude)\n"
 "    local first,last=cycle.sunrise+1,cycle.sunset-1\n"
 "    if clock<=first then return rise end\n"
 "    if clock>=last then return set end\n"
 "    local turn=(set-rise+180)%360-180\n"
 "    return rise+turn*smooth((clock-first)/(last-first))\n"
 "end\n"
 "function Cycle.previewClock(cycle,preset)\n"),
])

edit('LightingClient.lua', [
("    local activeSky=Lighting:FindFirstChild(\"ActiveSky\")\n",
 "    -- Client-local dynamic clouds; a look's Clouds section drives them (Cover 0 = none).\n"
 "    local clouds=workspace.Terrain:FindFirstChildOfClass(\"Clouds\")\n"
 "    if not clouds then clouds=Instance.new(\"Clouds\"); clouds.Name=\"Clouds\"; clouds.Cover=0; clouds.Parent=workspace.Terrain end\n"
 "    local activeSky=Lighting:FindFirstChild(\"ActiveSky\")\n"),
("            skyName=target.SkyName\n        end\n",
 "            skyName=target.SkyName\n        end\n"
 "        if target.Clouds then properties(clouds,target.Clouds) end\n"
 "        if target.SkyYaw then\n"
 "            local orientation=Vector3.new(0,math.round(target.SkyYaw*10)/10,0)\n"
 "            if activeSky.SkyboxOrientation~=orientation then activeSky.SkyboxOrientation=orientation end\n"
 "        end\n"),
("    local state,cycle\n",
 "    -- The sky art changes at dusk and dawn; load every template up front so the change never shows a blank sky.\n"
 "    task.spawn(function() pcall(function() game:GetService(\"ContentProvider\"):PreloadAsync(skies:GetChildren()) end) end)\n"
 "    local state,cycle\n"),
])
print('ok')
