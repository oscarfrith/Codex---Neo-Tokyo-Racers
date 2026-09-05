"""Package exact source, hierarchy and metadata preconditions for one installer."""
from build import *
counts=collections.Counter(tuple(n['path_parts']) for n in nodes)
# These obsolete reference/config trees have no current projected-path consumers.
retire_roots=[S+'.VehiclePerformance_EditAttributes',S+'.UI',S+'.Vehicle',C+'.Runtime.DrivingCamera_EditAttributes',C+'.Editable.02_IMPORTANT_LINKS_DoNotRename',C+'.Editable.03_READ_ME',C+'.UI.README_BackExitColors',C+'.UI.CockpitMenuCards',C+'.UI.FreeRoamNav']
shells=[K,K+'.Shared',S,C,C+'.Runtime',C+'.Editable','ReplicatedStorage.Shared','ReplicatedStorage.Shared.LightingPresets']
retired=[]
for n in nodes:
    p=n['path'];root=next((r for r in retire_roots if p==r or p.startswith(r+'.')),None)
    if root or p in shells:
        assert n['class_name'] in ('Folder','NumberValue','BoolValue','StringValue','Color3Value','ObjectValue','Vector3Value'),(p,n['class_name'])
        retired.append({k:v for k,v in n.items() if k not in ('children','script_id')})
retired_paths={tuple(n['path_parts']) for n in retired}
moves={a:b for a,b in moves.items() if tup(a) not in retired_paths}
for a in moves:assert counts[tup(a)]==1,('ambiguous move',a)
creates={}
remaining={destination(n['path_parts']):n for n in nodes if tuple(n['path_parts']) not in retired_paths}
for a,b in moves.items():
    pp=tup(b)[:-1]
    while len(pp)>1:
        if pp not in remaining:creates[pp]='Folder'
        pp=pp[:-1]
metadata=[];all_sources='\n'.join(before.values())
preserved=[]
for n in nodes:
    p=n['path_parts'];attrs=n.get('attributes',{})
    if not isinstance(attrs,dict) or tuple(p) in retired_paths:continue
    if p[0]=='Workspace' and p[:2]!=['Workspace','NeoTokyoRacersWorld']:continue
    if p[:2]==['ServerStorage','Archive'] or p[:3]==['ServerStorage','NeoTokyoRacers','VehiclePerformanceV2_Staging']:continue
    changes=[]
    for k,v in attrs.items():
        obsolete=bool(re.search(r'Phase|Revision|Installed|Migrated|CreatedBy|CreatedOrUpdatedBy|LegacyName|RunId|Patch|SourceSheet|TemplateFromOrganizer|ContainsLiveReferencesOnly|DefaultModulesNote|AssetReplacementNote|CurrentLiveConfig|MirrorsAreReference|MigrationStatus',k)) and k not in all_sources
        if obsolete:changes.append({'old':k,'new':None,'value':v});continue
        if k in name_map:
            nk=name_map[k];assert nk not in attrs,(n['path'],k,nk)
            changes.append({'old':k,'new':nk,'value':v})
        elif v.get('type')=='string' and v.get('value') in name_map:
            changes.append({'old':k,'new':k,'value':v,'afterValue':dict(v,value=name_map[v['value']])})
    if changes:metadata.append({'path':p,'class':n['class_name'],'attributes':attrs,'changes':changes})
# Equivalent duplicate paths receive one grouped operation with an exact count guard.
groups={}
for r in metadata:
    key=json.dumps(r,sort_keys=True);groups.setdefault(key,dict(r,count=0))['count']+=1
metadata=list(groups.values())
sources=[]
for r in rows:
    p='.'.join(destination(r['path_parts']));s=projections[p]
    sources.append({'beforePath':r['path_parts'],'path':list(destination(r['path_parts'])),'class':r['class_name'],'disabled':r.get('disabled',False),'before':before[r['roblox_path']],'source':s})
for n in retired:
    # Do not retire a host with an external ObjectValue pointing at it.
    for other in nodes:
        if tuple(other['path_parts']) in retired_paths:continue
        v=other.get('properties',{});v=v.get('Value') if isinstance(v,dict) else None
        assert not(v and v.get('type')=='Instance' and tuple(v['path_parts'])==tuple(n['path_parts'])),('external retirement reference',other['path'])
tags={x:x.removeprefix('NTR_') for x in ['NTR_WindowMaterial','NTR_NightLamppostLight','NTR_RaceCheckpoint','NTR_DriveCustomisationZone','NTR_RoadSpawnPoint','NTR_RaceStartZone','NTR_TimeTrialStartZone','NTR_RaceFinishLine','NTR_AudioContextZone']}
payload={'placeId':121304917315753,'sources':sources,'moves':[{'before':list(tup(a)),'after':list(tup(b)),'class':index[tup(a)]['class_name']} for a,b in moves.items()], 'retired':retired,'created':[{'path':list(p),'class':c} for p,c in sorted(creates.items(),key=lambda x:len(x[0]))],'metadata':metadata,'tags':tags,'wipTags':json.loads(read(HERE/'wip-lighting-tags.json'))}
dump(HERE/'payload.json',payload)
template=read(HERE/'installer.lua');blob=json.dumps(payload,separators=(',',':'),ensure_ascii=False)
delimiter='='*8;assert ']'+delimiter+']' not in blob
write(ROOT/'scripts/roblox_cleanup_phase3_generic_naming.lua',template.replace('--[[PAYLOAD]]','['+delimiter+'['+blob+']'+delimiter+']'))
print('Packaged',len(sources),'sources',len(moves),'moves',len(retired),'retirements',len(metadata),'metadata groups',len(creates),'new folders')
