from pathlib import Path
import gzip,hashlib,json,re,sys
from catalogue import project,flat
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts/cleanup_phase2'))
from path_analysis import tokens
def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf8')
def checksum(s):return str(sum(i*b for i,b in enumerate(s.encode(),1))%1000000007)
def replace(s,a,b):
    assert s.count(a)==1,('anchor count',s.count(a),a[:120]);return s.replace(a,b,1)
def function_block(s,start,end,new):
    a=s.index(start);b=s.index(end,a);return replace(s,s[a:b],new+'\n')
def attributes(s):
    ts=tokens(s);edits=[]
    for i in range(len(ts)-4):
        if re.fullmatch(r'[A-Za-z_]\w*',ts[i][0]) and [x[0] for x in ts[i+1:i+4]]==[':','GetAttribute','(']:
            depth=1;j=i+4
            while depth:
                if ts[j][0]=='(':depth+=1
                if ts[j][0]==')':depth-=1
                j+=1
            arg=s[ts[i+3][2]:ts[j-1][1]]
            edits.append((ts[i][1],ts[j-1][2],'Definition.Attribute('+ts[i][0]+','+arg+')'))
    for a,b,new in reversed(edits):s=s[:a]+new+s[b:]
    return s
def main():
    if not (HERE/'baseline.json').exists():
        rows=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf8'))
        dump(HERE/'baseline.json',rows)
        dump(HERE/'sources-before.json',{r['roblox_path']:(ROOT/r['file']).read_text(encoding='utf8') for r in rows})
        (HERE/'hierarchy-before.json.gz').write_bytes(gzip.compress((ROOT/'roblox/studio_snapshot/hierarchy.json').read_bytes(),mtime=0))
    rows=json.loads((HERE/'baseline.json').read_text());before=json.loads((HERE/'sources-before.json').read_text())
    h=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()))
    data,data_source,authoring=project(h)
    prefix='ReplicatedStorage.Modules.Game.Vehicles.';perf=prefix+'Performance.'
    definition='local Definition=require(game:GetService("ReplicatedStorage").Modules.Game.Vehicles.VehicleDefinition)\n'
    catalog='local Catalog=require(game:GetService("ReplicatedStorage").Modules.Game.Vehicles.VehicleCatalog)\n'
    template_index='local TemplateIndex=require(game:GetService("ReplicatedStorage").Modules.Game.Vehicles.VehicleTemplateIndex)\n'
    after=dict(before)
    s=attributes(before[perf+'PerformanceRuntime']);after[perf+'PerformanceRuntime']=definition+s
    s=attributes(before[perf+'PerformanceUpgradeRuntime'])
    s=function_block(s,'local function pathsRoot(module)','function Runtime.NormalizeAllocation', '''local function sortedPaths(module)
 local result=Definition.Paths(module)
 table.sort(result,function(a,b) return tostring(Definition.Attribute(a,"PathId") or a.Name)<tostring(Definition.Attribute(b,"PathId") or b.Name) end)
 return result
end
''')
    s=replace(s,'local id = tostring(pathId); local root = pathsRoot(module); local path = root and root:FindFirstChild(id)','local id = tostring(pathId); local path = Definition.Path(module,id)')
    s=replace(s,'local root = pathsRoot(module)\n\tlocal path = root and root:FindFirstChild(tostring(pathId))','local path = Definition.Path(module,tostring(pathId))')
    after[perf+'PerformanceUpgradeRuntime']=definition+s
    s=attributes(before[perf+'VehiclePerformanceResolver'])
    s=function_block(s,'local function findTemplate(root,attribute,id)','local function first(value,names)', '''local function findTemplate(_root,attribute,id)
 return Catalog.Get(attribute,id)
end
''')
    s=replace(s,'function Resolver.FindCockpit(root,cockpit) if typeof(cockpit)=="Instance" then return cockpit end; return findTemplate(root,"CockpitId",idOf(cockpit,"CockpitId")) end','function Resolver.FindCockpit(_root,cockpit) return Catalog.Resolve("CockpitId",cockpit) end')
    s=replace(s,'function Resolver.FindModule(root,module) if typeof(module)=="Instance" then return module end; return findTemplate(root,"ModuleId",idOf(module,"ModuleId")) end','function Resolver.FindModule(_root,module) return Catalog.Resolve("ModuleId",module) end')
    after[perf+'VehiclePerformanceResolver']=definition+catalog+s
    p='ReplicatedStorage.Modules.Game.Garage.GarageModuleInstancePreviewAdapter'
    s=function_block(before[p],'function Adapter.FindTemplate(categoriesRoot,moduleId)','function Adapter.Installed', '''function Adapter.FindTemplate(categoriesRoot,moduleId)
 return TemplateIndex.Find(categoriesRoot,"ModuleId",moduleId)
end
''');after[p]=template_index+s
    p='ReplicatedStorage.Modules.Game.Garage.PreviewVehicleClient'
    line=next(x for x in before[p].splitlines() if x.startswith('function PreviewVehicleController.FindTemplateByAttribute('))
    after[p]=template_index+replace(before[p],line,'function PreviewVehicleController.FindTemplateByAttribute(root,attr,value) return TemplateIndex.Find(root,attr,value) end')
    p='ReplicatedStorage.Modules.Game.Garage.GarageUI'
    line=next(x for x in before[p].splitlines() if x.startswith('local function cockpitImage(c)'))
    new='''local function cockpitImage(c)
 local keys={"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}
 for _,k in ipairs(keys) do local v=imageValue(c and c[k]);if v~="" then return v end end
 local record=Catalog.Get("CockpitId",c and c.CockpitId,true)
 if record then for _,k in ipairs(keys) do local v=imageValue(record[k]);if v~="" then return v end;v=imageValue(record[k.."ChildValue"]);if v~="" then return v end end end
 return ""
end'''
    s=replace(before[p],line,new)
    s=replace(s,'template and template:GetAttribute("UpgradePointCapacity")','template and template.UpgradePointCapacity')
    after[p]=catalog+s
    new_sources={prefix+'VehicleCatalogData':data_source}
    for name in ['VehicleDefinition','VehicleCatalog','VehicleTemplateIndex']:new_sources[prefix+name]=(HERE/(name+'.lua')).read_text(encoding='utf8')
    assert not set(new_sources)&set(before)
    changed=[{'path':p.split('.'),'before':before[p],'after':s} for p,s in after.items() if s!=before[p]]
    assert len(changed)==6
    fps=[]
    for r in rows:
        p=r['roblox_path'];assert hashlib.sha256(before[p].encode()).hexdigest()==r['source_sha256']
        fps.append({'path':r['path_parts'],'class':r['class_name'],'disabled':r['disabled'],'beforeChecksum':checksum(before[p]),'checksum':checksum(after[p]),'beforeBytes':len(before[p].encode()),'bytes':len(after[p].encode()),'sha256':hashlib.sha256(after[p].encode()).hexdigest()})
    new=[{'path':p.split('.'),'source':s,'sha256':hashlib.sha256(s.encode()).hexdigest()} for p,s in new_sources.items()]
    d={'sources':changed,'new':new,'fingerprints':fps,'authoring':authoring,'revision':data['Revision']}
    dump(HERE/'payload.json',d);dump(HERE/'catalogue.json',data)
    dump(HERE/'projection-report.json',{'revision':data['Revision'],'cockpits':len(data['Cockpits']),'modules':len(data['Modules']),'dataSourceBytes':len(data_source.encode()),'changedSources':[p['path'] for p in changed]})
    encoded=json.dumps(d,ensure_ascii=False,separators=(',',':'));assert ']========]' not in encoded
    template=(HERE/'installer.lua').read_text(encoding='utf8')
    (ROOT/'scripts/roblox_performance_phase3_catalogue.lua').write_text(template.replace('--[[PAYLOAD]]','[========['+encoded+']========]'),encoding='utf8')
    print((HERE/'projection-report.json').read_text())
if __name__=='__main__':main()
