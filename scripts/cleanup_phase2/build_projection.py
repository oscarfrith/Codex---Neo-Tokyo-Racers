"""Reviewable full-source projection. Frozen inputs and exact anchors only."""
from prepare import *
from path_analysis import rewrite, expression
import re

rows=json.loads(read(HERE/'baseline.json'))
by_path={r['roblox_path']:r for r in rows}
old_maps=sum((json.loads(read(ROOT/'scripts'/phase/'migration.json')) for phase in ('architecture_phase3','architecture_phase4')),[])
module_map={r['old']:r['new'] for r in old_maps}
contexts={r['new']:r['old'] for r in old_maps}
shared='ReplicatedStorage.NeoTokyoRacers.Shared.Modules.'
special={
 'Common.ConfigReader':'Core.ConfigReader', 'Core.PathResolver':'Core.PathResolver',
 'Common.UITheme':'Game.UI.ThemeValues','UI.UITheme':'Game.UI.UITheme',
 'Common.DriveTuning':'Game.Vehicles.DriveTuning','Common.VehicleData':'Game.Vehicles.VehicleData',
 'Common.VehicleDisplayNames':'Game.Vehicles.VehicleDisplayNames','Common.VehicleStatsCache':'Game.Vehicles.VehicleStatsCache',
 'Common.Audio.VehicleAudioStateContract':'Game.Audio.VehicleAudioStateContract',
 'UI.UIFactory':'Game.UI.ResponsiveUIFactory',
}
performance={
 'VehiclePerformanceCalculator':'PerformanceProjection',
 'VehiclePerformanceDefinitions':'PerformanceProjectionDefinitions',
 'VehiclePerformanceV2Calculator':'PerformanceCalculator',
 'VehiclePerformanceV2Definitions':'PerformanceDefinitions',
 'VehiclePerformanceV2DynamicsAdapter':'PerformanceDynamics',
 'VehiclePerformanceV2Runtime':'PerformanceRuntime',
 'VehiclePerformanceV2UpgradeRuntime':'PerformanceUpgradeRuntime',
 'VehiclePerformanceRuntime':'VehiclePerformance',
}
for row in rows:
    path=row['roblox_path']
    if not path.startswith(shared) or path in module_map: continue
    tail=path[len(shared):]
    if tail in special: target=special[tail]
    elif tail.startswith('Common.Performance.'):
        name=tail.split('.')[-1];target='Game.Vehicles.Performance.'+performance.get(name,name)
    elif tail.startswith('Data.'):
        name=tail.split('.')[-1]
        group='Player' if name in ('PlayerProfileSchema','LegacyGarageProfileMapper') else 'Vehicles' if name=='VehicleCosmeticCatalog' else 'Garage'
        target='Game.'+group+'.'+('GarageProfileProjection' if name=='LegacyGarageProfileMapper' else name)
    elif tail.startswith(('UI.','Racing.')):target='Game.'+tail
    else:raise AssertionError(tail)
    module_map[path]='ReplicatedStorage.Modules.'+target

runtime_map={
 'ServerScriptService.NeoTokyoRacers':'ServerStorage.Runtime',
 'ServerScriptService.NeoTokyoRacers.Services.Garage.GarageService_Active':'ServerStorage.Runtime.Garage',
 'ServerScriptService.NeoTokyoRacers.Services':'ServerStorage.Runtime',
 'ServerScriptService.NeoTokyoRacers.Services.Vehicle':'ServerStorage.Runtime.Vehicles',
 'ServerScriptService.NeoTokyoRacers.State.RuntimeProfiles':'ServerStorage.Runtime.Player.RuntimeProfiles',
 'ServerScriptService.NeoTokyoRacers.State':'ServerStorage.Runtime.Player',
 'StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers':'StarterPlayer.StarterPlayerScripts.Runtime',
 'StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient':'StarterPlayer.StarterPlayerScripts.Runtime',
 'StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro':'StarterPlayer.StarterPlayerScripts.Runtime.Dealership',
 'StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime':'StarterPlayer.StarterPlayerScripts.Runtime.Vehicles',
 'StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview':'StarterPlayer.StarterPlayerScripts.Runtime.Garage',
}
runtime_map['ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled.RaceVehicleSpawner']='ServerStorage.Runtime.Garage.RaceVehicleSpawner'
container_map={shared+k:'ReplicatedStorage.Modules.'+v for k,v in {
 'Common.Performance':'Game.Vehicles.Performance','Common.Audio':'Game.Audio',
 'Client.Audio':'Game.Audio','UI':'Game.UI','Racing':'Game.Racing',
}.items()}

mapping={tuple(k.split('.')):tuple(v.split('.')) for k,v in (container_map|runtime_map|module_map).items()}
projected={}; reports=[]
for row in rows:
    old=row['roblox_path']
    if old in contexts.values(): continue # forwarding adapters are retired
    source=read(HERE/row['before_file'])
    # The real module remains script. Resolve its old lexical paths before removing the rebinding.
    context=contexts.get(old,old) if re.search(r'^local script = ',source,re.M) else old
    source,edits,ambiguous=rewrite(source,context.split('.'),mapping)
    source=re.sub(r'^local script = [^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^-- Phase [34] (?:canonical helper|client-session feature|server feature)[^\n]*\n','-- Canonical feature implementation; startup is owned by the composition root.\n',source)
    target=module_map.get(old,old)
    if target in projected:
        def body(s): return '\n'.join(line for line in s.splitlines() if not line.startswith('--')).strip()
        assert body(projected[target])==body(source),target
        continue
    projected[target]=source
    reports.append({'source':old,'target':target,'replacements':[{'before':a,'after':b} for _,_,_,a,b in edits],'ambiguous_aliases':ambiguous})

from explicit_edits import apply
projected=apply(projected)
for path,source in projected.items():write(HERE/'projected'/('/'.join(path.split('.'))+'.lua'),source)
dump(HERE/'module-map.json',module_map)
dump(HERE/'runtime-map.json',runtime_map)
dump(HERE/'path-analysis.json',reports)
dump(HERE/'projection-index.json',list(projected))
print('Projected',len(projected),'canonical sources;',sum(len(r['replacements']) for r in reports),'resolved path expressions')
