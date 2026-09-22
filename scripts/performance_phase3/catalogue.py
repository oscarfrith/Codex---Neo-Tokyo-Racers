"""Public projection. Author attributes remain the single source; never hand-edit data."""
import hashlib,json,re
ROOT_PATH=['ReplicatedStorage','Assets','Vehicles','Categories']
RAW='TopSpeed EngineOutput Weight LateralGrip SteeringResponse HoverStability DriftControl DriftGrip DriftChargeRate BrakingForce BoostForce BoostDuration BoostRecharge BoostRechargeDelay BoostEfficiency Drag Downforce'.split()
PUBLIC=set(RAW)|{'PerformanceDelta_'+x for x in RAW}|set('CockpitId ModuleId CategoryId DisplayName MenuImage CockpitImage ThumbnailImage ImageId Image PreviewImage ModuleSlot ModuleType ModuleFolder EnginePosition RearEngine UpgradePointCapacity MaxPointsPerPath RetiredFromCatalog CatalogVisible HiddenFromCatalog CatalogPublishReady Price PurchasePrice NeonPrice OwnedByDefault Upgradable VariantName VariantOrder SourceCockpitId SourceCockpitDisplayName StandardAudioProfileId DefaultFrontEngineModuleId DefaultEngineModuleId DefaultRearEngineModuleId DefaultEngineBModuleId DefaultStabilisersModuleId DefaultStabiliserModuleId DefaultBoostModuleId DefaultPrimaryColor DefaultSecondaryColor DefaultDetailColor DefaultNeonColor DefaultFrontLightsColor DefaultRearLightsColor'.split())|{'Point'+str(i)+'CostGuide' for i in range(1,7)}
PATH_KEYS={'PathId','DisplayName','MaxPoints'}|{'DeltaFraction_'+x for x in RAW}|{'DeltaFlat_'+x for x in RAW}|{'Point'+str(i)+'CostGuide' for i in range(1,7)}
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
