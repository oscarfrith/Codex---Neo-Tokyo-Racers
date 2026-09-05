"""Build reviewed Phase 3 projection from the immutable Phase 2 baseline."""
from prepare import *
sys.path.insert(0,str(ROOT/'scripts/cleanup_phase2'))
from path_analysis import rewrite,tokens,literal,analyze
H=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()))
nodes=flatten(H); rows=json.loads(read(HERE/'baseline.json'))
before={r['roblox_path']:read(HERE/r['before_file']) for r in rows}
index={tuple(n['path_parts']):n for n in nodes}
def tup(p):return tuple(p.split('.'))
K='ReplicatedStorage.NeoTokyoRacers';C=K+'.Config';S=K+'.Shared.Config'
moves={}
def move(a,b):assert tup(a) in index,a;moves[a]=b
move('Workspace.NeoTokyoRacersWorld','Workspace.World')
move('ReplicatedFirst.NTRLoading','ReplicatedFirst.Loading')
move(K+'.Assets','ReplicatedStorage.Assets')
move(K+'.Shared.Remotes','ReplicatedStorage.Remotes')
for name in ('Audio','Development','Racing','UI'):move(C+'.'+name,'ReplicatedStorage.Config.'+name)
runtime={'WorldLOD':'World.LOD','DRIVING_MECHANICS_EditAttributes':'Vehicles.Driving','DriveInCustomisation':'Garage.DriveIn','DriveToEarnCash_EditAttributes':'Vehicles.DriveRewards','DrivingCamera_Default_EditAttributes':'Vehicles.Camera','DrivingCamera_EditAttributes':'Vehicles.CameraAuthoring','FreeRoamHudTeleport':'World.FreeRoamTeleport','FreeRoamVehicleSpawn':'Vehicles.Spawn','Onboarding_EditAttributes':'Player.Onboarding','OwnedGarage_EditAttributes':'Garage.Interior','StudioCashGrant':'Development.CashGrant','VehicleDynamics_EditAttributes':'Vehicles.Dynamics'}
for name,dest in runtime.items():move(C+'.Runtime.'+name,'ReplicatedStorage.Config.'+dest)
shared={'CharacterMovement_EditAttributes':'Player.Movement','MobileDriveControls_EditAttributes':'Vehicles.MobileControls','Persistence_EditAttributes':'Player.Persistence','VehiclePerformanceV2_EditAttributes':'Vehicles.Performance','VehiclePerformance_EditAttributes':'Vehicles.PerformanceReference','UI':'UIReference','Vehicle':'Vehicles.Reference'}
for name,dest in shared.items():move(S+'.'+name,'ReplicatedStorage.Config.'+dest)
move(C+'.Editable.01_GAME_BALANCE_Editable','ReplicatedStorage.Config.Vehicles.Authoring')
move(C+'.Editable.DRIVER_SEAT_POSITION_DoNotRename','ReplicatedStorage.Config.Vehicles.DriverSeat')
move(C+'.Editable.STABILISER_VFX_DIRECTION_DoNotRename','ReplicatedStorage.Config.Vehicles.StabiliserVFX')
move(C+'.Editable.02_IMPORTANT_LINKS_DoNotRename','ReplicatedStorage.Config.Development.AuthoringReferences')
move(C+'.Editable.03_READ_ME','ReplicatedStorage.Config.Development.AuthoringNotes')
move('ServerStorage.NeoTokyoRacers.OwnedGarage','ServerStorage.Assets.Garage')
move('ServerStorage.NeoTokyoRacers.Racing','ServerStorage.Assets.Racing')
move('ReplicatedStorage.Shared.LightingCycleConfig','ReplicatedStorage.Config.World.Lighting')
move('ReplicatedStorage.Shared.SkyPresets','ReplicatedStorage.Assets.World.Skies')
move('ReplicatedStorage.Shared.LightingCycleConfig.LightingCycleSchedule','ReplicatedStorage.Modules.Game.World.LightingSchedule')
move('ReplicatedStorage.Shared.LightingPresets.LightingPresets','ReplicatedStorage.Modules.Game.World.LightingPresets')
external={'NTRSessionToken','NTRSessionLeaseUntil','NTR_PlayerProfiles_v1','NTR_DealershipIntro_v1','NTR_TimeTrialPersonalBests_v1','NTR_TT_Global_v1','NTR_TT_Global_Metadata_v1'}
name_map={'NeoTokyoRacersWorld':'World','NTRLoading':'Loading','NTRCategoryId':'SourceCategoryId','LegacyGarageProfileBridgeBindings':'GarageProfileProjectionBindings','LegacyVehicleVFXClient':'VehiclePreviewVFXClient','NTR_DefaultVehicleCameraV6':'VehicleCamera','NTR_DefaultVehicleCameraInitialFramingV6':'VehicleCameraInitialFraming','HOVER_RACING_V75_CameraAssist':'DrivingCameraAssist','HOVER_RACING_V2_V47_Reset':'VehicleReset','HOVER_RACING_V2_BlockJumpWhileDriving':'BlockJumpWhileDriving','HOVER_RACING_V2_DriveHUD':'DriveHUD','HOVER_RACING_V2_GarageUI':'GarageUI','HOVER_RACING_V2_LOCAL_PREVIEW':'LocalVehiclePreview','NTR_GARAGE_PHASE1_EXISTING_INSTANCE_CANONICAL_APPLICATION_V3':'GarageApplication','NTR_DRIVE_TO_EARN_CASH_V1_1':'DriveRewards','NTR_OnboardingV1':'Onboarding','_NTR_ClientOnly':'ClientOnly','FIXED_MODULE_SLOTS_DoNotRename':'ModuleSlots','VFX_ATTACHMENTS_DoNotRename':'VFXAttachments'}
for n in nodes:
    name=n['name']
    if name.startswith('NTR_') or name.startswith('NTR') and len(name)>3 and name[3].isupper():name_map.setdefault(name,re.sub(r'^NTR_?','',name))
for s in before.values():
    for t,a,b in tokens(s):
        v=literal(t)
        if v and re.fullmatch(r'NTR_?[A-Za-z0-9_.]*',v) and v not in external:name_map.setdefault(v,re.sub(r'^NTR_?','',v))
        if t.startswith('NTR_') and re.fullmatch(r'\w+',t):name_map.setdefault(t,t[4:])
for n in nodes:
    for k in n.get('attributes',{}) if isinstance(n.get('attributes'),dict) else []:
        if k.startswith('NTR') and k not in external:name_map.setdefault(k,re.sub(r'^NTR_?','',k))
for x in external:name_map.pop(x,None)
for n in nodes:
    p=n['path_parts'];name=n['name']
    if name in name_map and n['class_name'] in ('Folder','SoundGroup','ReverbSoundEffect','ModuleScript','ScreenGui','BillboardGui') and (p[0]!='Workspace' or p[:2]==['Workspace','NeoTokyoRacersWorld']):
        if p[:2]==['ServerStorage','Archive'] or p[:3]==['ServerStorage','NeoTokyoRacers','VehiclePerformanceV2_Staging']:continue
        if n['path'] not in moves:move(n['path'],'.'.join(p[:-1]+[name_map[name]]))
# Compose child destinations through ancestor moves once, from the longest matching prefix.
def destination(parts):
    for old,new in sorted(moves.items(),key=lambda kv:-len(tup(kv[0]))):
        old=tup(old)
        if tuple(parts[:len(old)])==old:return tup(new)+tuple(parts[len(old):])
    return tuple(parts)
for old,new in list(moves.items()):
    pp=tup(new);parent=destination(pp[:-1]);moves[old]='.'.join(parent+(pp[-1],))
mapping={tup(a):tup(b) for a,b in moves.items()}
# Removed structural shells can be collapsed while resolving intermediate source aliases.
for old,new in {K:'ReplicatedStorage',K+'.Shared':'ReplicatedStorage',C:'ReplicatedStorage.Config',S:'ReplicatedStorage.Config',C+'.Runtime':'ReplicatedStorage.Config',C+'.Editable':'ReplicatedStorage.Config.Vehicles','ReplicatedStorage.Shared':'ReplicatedStorage','ReplicatedStorage.Shared.LightingPresets':'ReplicatedStorage.Modules.Game.World'}.items():mapping[tup(old)]=tup(new)
projections={};reports=[]
for row in rows:
    path=row['roblox_path'];src=before[path]
    if path.startswith('Workspace.') and not path.startswith('Workspace.NeoTokyoRacersWorld.'):
        projections[path]=src;continue
    src,edits,ambiguous=rewrite(src,row['path_parts'],mapping)
    # Exact token replacements keep external persistence contracts and prose substrings intact.
    replacements=[]
    for t,a,b in tokens(src):
        v=literal(t)
        if v in name_map:replacements.append((a,b,t[0]+name_map[v]+t[-1]))
        elif t in name_map and re.fullmatch(r'\w+',t):replacements.append((a,b,name_map[t]))
        elif v and v.startswith('[NTR '):replacements.append((a,b,t[0]+v.replace('[NTR ','[',1)+t[-1]))
    for a,b,v in reversed(replacements):src=src[:a]+v+src[b:]
    # Remove obsolete standalone patch-stamp comments; preserve substantive comments.
    src=re.sub(r'^\s*-- (?:NTR_|HOVER_RACING_)[A-Z0-9_]+\s*\n','',src,flags=re.M)
    projections['.'.join(destination(row['path_parts']))]=src
    reports.append({'source':path,'target':'.'.join(destination(row['path_parts'])),'paths':len(edits),'names':len(replacements),'ambiguous':ambiguous})
from source_edits import apply
projections=apply(projections)
for p,s in projections.items():write(HERE/'projected'/('/'.join(p.split('.'))+'.lua'),s)
dump(HERE/'projection-index.json',list(projections));dump(HERE/'path-map.json',moves);dump(HERE/'name-map.json',name_map);dump(HERE/'projection-report.json',reports)
left=[]
for p,s in projections.items():
    if p.startswith('Workspace.'):continue
    for t,a,b in tokens(s):
        v=literal(t)
        if (v is not None and v not in external and re.search(r'NeoTokyoRacers|HOVER_RACING|\bNTR',v)) or t=='NeoTokyoRacers':left.append({'path':p,'line':s.count('\n',0,a)+1,'token':t})
dump(HERE/'unresolved-source-names.json',left)
print('Projected',len(projections),'sources;',len(moves),'moves;',len(name_map),'name contracts;',len(left),'remaining branded tokens')
