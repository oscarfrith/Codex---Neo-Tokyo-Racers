"""Builds step4/after/*.lua from the step 2 sources (the live ones) by exact, single-occurrence anchor edits.
Change: the veil over the sky change takes a colour for each side instead of always going black."""
from pathlib import Path
HERE = Path(__file__).resolve().parent
SRC = HERE.parent / 'step2' / 'after'
(HERE / 'after').mkdir(exist_ok=True)
def edit(name, pairs):
    text = (SRC / name).read_bytes().decode('utf8')
    for old, new in pairs:
        assert text.count(old) == 1, (name, old[:60], text.count(old))
        text = text.replace(old, new)
    (HERE / 'after' / name).write_bytes(text.encode('utf8'))

edit('LightingCycleDefinition.lua', [
("local Definition={}\n",
 "local Definition={}\n"
 "local function colour(value) return typeof(value)==\"Color3\" and {Type=\"Color3\",R=value.R,G=value.G,B=value.B} or value end\n"),
("        NightSkyVeilHours=config:GetAttribute(\"NightSkyVeilHours\"),\n",
 "        NightSkyVeilHours=config:GetAttribute(\"NightSkyVeilHours\"),\n"
 "        -- Haze colour at the sky change, seen under the old sky and under the night sky (absent: black).\n"
 "        NightSkyVeilColorBefore=colour(config:GetAttribute(\"NightSkyVeilColorBefore\")),\n"
 "        NightSkyVeilColorAfter=colour(config:GetAttribute(\"NightSkyVeilColorAfter\")),\n"),
])

edit('LightingCycle.lua', [
("        cycle.night={name=settings.NightSkyName,first=first,last=last,veil=veil}\n",
 "        -- The same haze colour is much brighter under the day-for-night sun than under the real night before it,\n"
 "        -- so each side of the change has its own colour; tune the pair until the two sides match on screen.\n"
 "        local function veilColour(value)\n"
 "            if value==nil then return BLACK end\n"
 "            assert(type(value)==\"table\" and value.Type==\"Color3\",\"Night sky veil colours must be Color3\")\n"
 "            for _,component in ipairs({value.R,value.G,value.B}) do assert(Cycle.finite(component) and component>=0 and component<=1,\"Invalid night sky veil colour\") end\n"
 "            return Color3.new(value.R,value.G,value.B)\n"
 "        end\n"
 "        cycle.night={name=settings.NightSkyName,first=first,last=last,veil=veil,before=veilColour(settings.NightSkyVeilColorBefore),after=veilColour(settings.NightSkyVeilColorAfter)}\n"),
("    -- behind a veil: haze up and black, no key light, sky fill and reflections dipped.\n",
 "    -- behind a veil: haze up and one flat colour, no key light, sky fill and reflections dipped.\n"),
("            air.Color=air.Color:Lerp(BLACK,veil); air.Decay=air.Decay:Lerp(BLACK,veil)\n",
 "            local tint=nightSky and night.after or night.before\n"
 "            air.Color=air.Color:Lerp(tint,veil); air.Decay=air.Decay:Lerp(tint,veil)\n"),
])
print('ok')
