"""Public projection. Author attributes remain the single source; never hand-edit data."""
import hashlib,json,re
ROOT_PATH=['ReplicatedStorage','Assets','Vehicles','Categories']
RAW='TopSpeed EngineOutput Weight LateralGrip SteeringResponse HoverStability DriftControl DriftGrip DriftChargeRate BrakingForce BoostForce BoostDuration BoostRecharge BoostRechargeDelay BoostEfficiency Drag Downforce'.split()
PUBLIC=set(RAW)|{'PerformanceDelta_'+x for x in RAW}|set('CockpitId ModuleId CategoryId DisplayName MenuImage CockpitImage ThumbnailImage ImageId Image PreviewImage ModuleSlot ModuleType ModuleFolder EnginePosition RearEngine UpgradePointCapacity MaxPointsPerPath RetiredFromCatalog CatalogVisible HiddenFromCatalog CatalogPublishReady Price PurchasePrice NeonPrice OwnedByDefault Upgradable VariantName VariantOrder SourceCockpitId SourceCockpitDisplayName StandardAudioProfileId DefaultFrontEngineModuleId DefaultEngineModuleId DefaultRearEngineModuleId DefaultEngineBModuleId DefaultStabilisersModuleId DefaultStabiliserModuleId DefaultBoostModuleId DefaultPrimaryColor DefaultSecondaryColor DefaultDetailColor DefaultNeonColor DefaultFrontLightsColor DefaultRearLightsColor'.split())|{'Point'+str(i)+'CostGuide' for i in range(1,7)}
PATH_KEYS={'PathId','DisplayName','MaxPoints'}|{'DeltaFraction_'+x for x in RAW}|{'DeltaFlat_'+x for x in RAW}|{'Point'+str(i)+'CostGuide' for i in range(1,7)}
# Opt-in names (Exotic category, 2026-10-02). Absent on every earlier model, so earlier records are unchanged.
# scripts/exotic_category/catalogue/catalogue_gen.lua carries the same list; change both together.
OPT_IN='DefaultFrontBodyModuleId DefaultRearBodyModuleId DefaultSidePodsModuleId DefaultFrontBumperModuleId DefaultRearBumperModuleId DefaultRearSpoilerModuleId RatingReferenceCockpitId'.split()
assert not set(OPT_IN)&PUBLIC;PUBLIC|=set(OPT_IN)
DATA_PATH=['ReplicatedStorage','Modules','Game','Vehicles','VehicleCatalogData']
CHUNK_FILL=150000;SOURCE_LIMIT=190000
INDEX_HEADER='-- GENERATED public catalogue index; edit canonical model attributes, regenerate, then restart Play.\n'
CHUNK_HEADER='-- GENERATED public catalogue chunk; edit canonical model attributes, regenerate, then restart Play.\n'
FREEZE='local function freeze(t) for _,v in pairs(t) do if type(v)=="table" then freeze(v) end end return table.freeze(t) end\nreturn freeze(data)\n'
MERGE='\tlocal chunk=require(script:WaitForChild(name))\n\tfor _,kind in {"Cockpits","Modules"} do\n\t\tfor id,record in pairs(chunk[kind]) do\n\t\t\tassert(data[kind][id]==nil,"Duplicate catalogue id "..tostring(id).." in "..name)\n\t\t\tdata[kind][id]=record\n\t\tend\n\tend\nend\n'
def flat(h):
    out=[];todo=list(h['hierarchy'])
    while todo:
        n=todo.pop();out.append(n);todo.extend(n.get('children',[]))
    return out
def lua(value):
    if isinstance(value,dict):
        if value.get('type')=='Color3':return 'Color3.new(%r,%r,%r)'%(value['r'],value['g'],value['b'])
        return '{'+','.join('['+json.dumps(k)+']='+lua(v) for k,v in sorted(value.items()))+'}'
    if isinstance(value,list):return '{'+','.join(map(lua,value))+'}'
    if isinstance(value,bool):return 'true' if value else 'false'
    if value is None:return 'nil'
    return json.dumps(value,ensure_ascii=True)
def attrs(node,keys):
    return {k:(v['value'] if 'value' in v else v) for k,v in (node.get('attributes') or {}).items() if k in keys}
def project(h):
    out={'SchemaVersion':1,'Cockpits':{},'Modules':{}};source_records=[]
    for node in flat(h):
        if node['path_parts'][:4]!=ROOT_PATH or node['class_name']!='Model':continue
        a=attrs(node,PUBLIC)
        ids=[k for k in ('CockpitId','ModuleId') if k in a]
        if not ids:continue
        assert len(ids)==1,node['path']
        field=ids[0];key=str(a[field]);index=out['Cockpits' if field=='CockpitId' else 'Modules']
        assert key and key not in index,('duplicate id',key,node['path'])
        a['Name']=node['name'];a['IsVehicleDefinition']=True;a['TemplatePath']=node['path_parts'][4:]
        children={n['name']:n for n in node.get('children',[])}
        for image in ('MenuImage','CockpitImage','ThumbnailImage','ImageId','Image'):
            c=children.get(image)
            if c and c['class_name']=='StringValue':a[image+'ChildValue']=c['properties']['Value']['value']
        root=children.get('VehiclePerformanceV2UpgradePaths') or children.get('UpgradePaths')
        paths=[];names=set();pathids=set()
        for p in root.get('children',[]) if root else []:
            if p['class_name']!='Folder':continue
            v=attrs(p,PATH_KEYS);v['Name']=p['name'];pid=str(v.get('PathId',p['name']))
            assert p['name'] not in names and pid not in pathids,('duplicate upgrade path',node['path'])
            names.add(p['name']);pathids.add(pid);paths.append(v)
        a['UpgradePaths']=sorted(paths,key=lambda x:str(x.get('PathId',x['Name'])))
        index[key]=a
        # Exact authoring attributes/upgrade subtree used by preflight and regeneration checks.
        source_records.append({'path':node['path_parts'],'attributes':node['attributes'],
                               'children':[c for c in node.get('children',[]) if c['name'] in ('VehiclePerformanceV2UpgradePaths','UpgradePaths','MenuImage','CockpitImage','ThumbnailImage','ImageId','Image')]})
    assert out['Cockpits'] and out['Modules']
    for c in out['Cockpits'].values():
        for key,value in c.items():
            if key.startswith('Default') and key.endswith('ModuleId'):assert str(value) in out['Modules'],(c['Name'],key,value)
    out['Revision']=hashlib.sha256(json.dumps(out,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    source='-- GENERATED public catalogue; edit canonical model attributes, regenerate, then restart Play.\nlocal data='+lua(out)+'\nlocal function freeze(t) for _,v in pairs(t) do if type(v)=="table" then freeze(v) end end return table.freeze(t) end\nreturn freeze(data)\n'
    return out,source,source_records
def luau_safe(value,where=None):
    """Refuse a string or number that catalogue_gen.lua refuses (its jstr and num), or that Luau would print differently.

    Strings: ASCII, and no control character that json.dumps writes as \\uXXXX (Luau does not read that form), no DEL.
    Numbers: zero or 0.0001 <= |v| < 2^53, never in exponent form. A float with a whole value (5.0, -0.0) prints as
    5.0 here and as 5 in Luau; captured whole numbers are ints, so such a float is refused.
    """
    if isinstance(value,bool):return
    if isinstance(value,str):
        assert value.isascii() and not any((ord(c)<32 and c not in '\n\r\t\b\f') or ord(c)==127 for c in value),('text is not safe in the public catalogue',where,value)
    elif isinstance(value,(int,float)):
        assert (value==0 or 0.0001<=abs(value)<2**53) and not (isinstance(value,float) and value.is_integer()) and 'e' not in json.dumps(value),('number is not safe in the public catalogue',where,value)
    else:raise AssertionError(('unsupported public value',where,value))
def luau_safe_record(kind,key,record):
    """Refuse a projected record that catalogue_gen.lua refuses: every key and value, Color3 parts, TemplatePath, UpgradePaths."""
    def scalar(v,where):
        if isinstance(v,dict):
            assert v.get('type')=='Color3' and set(v)=={'b','g','r','text','type'} and isinstance(v['text'],str) and not any(isinstance(v[c],(bool,str)) for c in 'rgb'),('unsupported public value',where,v)
            for c in ('r','g','b','text'):luau_safe(v[c],where+(c,))
        else:luau_safe(v,where)
    field='CockpitId' if kind=='Cockpits' else 'ModuleId'
    assert isinstance(record.get(field),str) and record[field]==key,(field+' must be a string',key,record.get(field))
    luau_safe(key,(kind,))
    for k,v in record.items():
        where=(key,k);luau_safe(k,where)
        if k=='TemplatePath':
            assert isinstance(v,list) and v and all(isinstance(x,str) for x in v),('TemplatePath',key,v)
            for x in v:luau_safe(x,where)
        elif k=='UpgradePaths':
            assert isinstance(v,list) and all(isinstance(p,dict) for p in v),('UpgradePaths',key)
            for p in v:
                assert isinstance(p.get('PathId',p['Name']),str),('PathId must be a string',key,p['Name'])
                for pk,pv in p.items():luau_safe(pk,where+(p['Name'],));scalar(pv,where+(p['Name'],pk))
        else:scalar(v,where)
def chunk_sources(data):
    """Split form of project()'s data: [(module name, source)], the index first, then its chunk children in require order.

    Chunks group records by category folder (TemplatePath[0]): cockpits then modules, sorted by id, greedy fill to
    CHUNK_FILL characters. Record text is exactly the single-module text. Revision is project()'s, over the merged data.
    Data that catalogue_gen.lua refuses is refused here too, so every source this returns can be generated in Studio.
    """
    for kind in ('Cockpits','Modules'):
        for key,record in data[kind].items():luau_safe_record(kind,key,record)
    for m in data['Modules'].values():
        if 'RatingReferenceCockpitId' in m:assert str(m['RatingReferenceCockpitId']) in data['Cockpits'],(m['Name'],'RatingReferenceCockpitId',m['RatingReferenceCockpitId'])
    groups={}
    for kind in ('Cockpits','Modules'):
        for key,record in sorted(data[kind].items()):
            groups.setdefault(record['TemplatePath'][0],[]).append((kind,'['+json.dumps(key)+']='+lua(record)))
    chunks=[]
    for folder in sorted(groups):
        packs=[];size=0
        for kind,text in groups[folder]:
            if not packs or size+len(text)+1>CHUNK_FILL:packs.append({'Cockpits':[],'Modules':[]});size=0
            packs[-1][kind].append(text);size+=len(text)+1
        for i,pack in enumerate(packs,1):
            chunks.append((folder+'_'+str(i),CHUNK_HEADER+'return {["Cockpits"]={'+','.join(pack['Cockpits'])+'},["Modules"]={'+','.join(pack['Modules'])+'}}\n'))
    names=[name for name,_ in chunks]
    assert len(set(names))==len(names),('duplicate chunk name',names)
    index=INDEX_HEADER+'local data='+lua({'Cockpits':{},'Modules':{},'Revision':data['Revision'],'SchemaVersion':data['SchemaVersion']})+'\nfor _,name in {'+','.join(json.dumps(n) for n in names)+'} do\n'+MERGE+FREEZE
    result=[(DATA_PATH[-1],index)]+chunks
    for name,source in result:assert len(source)<SOURCE_LIMIT,('source too long',name,len(source))
    return result
def source_form(data,source,manifest,read):
    """Which generated form a manifest holds: ('legacy',[]) for the single module, ('split',[]) for the index plus
    exactly its chunk children, else (None,problems). read(row) returns a manifest row's source text."""
    rows=[r for r in manifest if r['path_parts'][:len(DATA_PATH)]==DATA_PATH]
    found={tuple(r['path_parts'][len(DATA_PATH):]):r for r in rows}
    if len(found)!=len(rows) or () not in found:return None,['VehicleCatalogData missing or duplicated']
    if len(rows)==1 and found[()]['class_name']=='ModuleScript' and read(found[()])==source:return 'legacy',[]
    expected={(() if i==0 else (name,)):text for i,(name,text) in enumerate(chunk_sources(data))}
    problems=['missing '+'.'.join(DATA_PATH+list(k)) for k in sorted(expected.keys()-found.keys())]
    problems+=['extra '+'.'.join(DATA_PATH+list(k)) for k in sorted(found.keys()-expected.keys())]
    for k in sorted(expected.keys()&found.keys()):
        if found[k]['class_name']!='ModuleScript':problems.append('not a ModuleScript '+'.'.join(DATA_PATH+list(k)))
        elif read(found[k])!=expected[k]:problems.append('stale '+'.'.join(DATA_PATH+list(k)))
    # A lone module that is not the current index either is most likely a stale legacy module, not a half-installed split.
    if len(rows)==1 and read(found[()])!=expected[()]:problems.insert(0,'single module is neither the current legacy source nor a current index (stale legacy form?)')
    return (None,problems) if problems else ('split',[])
