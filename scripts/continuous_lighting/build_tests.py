from pathlib import Path
import sys, json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import studio_capture as c
here=Path(__file__).resolve().parent
baseline=c.load(c.ROOT/'roblox/captures/continuous-lighting-before/capture.json')
rows={r['roblox_path']:r for r in baseline['manifest']}
def before(name):return (c.ROOT/rows['ReplicatedStorage.Modules.Game.World.'+name]['file']).read_text(encoding='utf8')
chunks={'Cycle':(here/'LightingCycle.lua').read_text(),'presets':before('LightingPresets'),'schedule':before('LightingSchedule')}
text='-- Generated pure numerical checks. No game module require or property writes.\n'
for name,source in chunks.items():text+='local '+name+'=(function()\n'+source+'\nend)()\n'
pure_prefix=text
tuning=json.loads((here/'tuning.json').read_text())
settings=dict(DurationSeconds=tuning['ContinuousCycleDurationSeconds'],Latitude=35,Sunrise=6,Sunset=18,SkyName=tuning['ContinuousSkyName'],RayFadeHours=tuning['ContinuousRayFadeHours'],Points=tuning['Points'],Presets=json.loads((here/'palette.json').read_text()))
text+='local settings=game.HttpService:JSONDecode([====['+json.dumps(settings)+']====])\n'
text+=(here/'test_cycle.lua').read_text()
(here/'run_tests.lua').write_text(text,encoding='utf8',newline='\n')
(here/'run_observe_continuity.lua').write_text(pure_prefix+(here/'observe_continuity.lua').read_text(encoding='utf8'),encoding='utf8',newline='\n')
print('Built pure numerical test chunk')
