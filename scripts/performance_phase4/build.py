"""Freeze Phase 3; generate one static preview projection and exact migration."""
from pathlib import Path
import copy,gzip,hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts/performance_phase3'))
from catalogue import flat,project
OLD=['ReplicatedStorage','Assets','Vehicles'];SERVER=['ServerStorage','Assets','Vehicles'];PREVIEW=['ReplicatedStorage','Assets','VehiclePreviews']
def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf8')
def checksum(s):return str(sum(i*b for i,b in enumerate(s.encode(),1))%1000000007)
def pruned(n):return any(x in ('VehiclePerformanceV2UpgradePaths','UpgradePaths') for x in n['path_parts'][3:])
def rewrite(v,src,dst):
    if isinstance(v,dict):
        if 'path_parts' in v and v['path_parts'][:len(src)]==src:
            v['path_parts']=dst+v['path_parts'][len(src):];v['path']='.'.join(v['path_parts'])
        for k,x in v.items():
            if k not in ('path_parts','path'):rewrite(x,src,dst)
    elif isinstance(v,list):
        for x in v:rewrite(x,src,dst)
def main():
    if not (HERE/'baseline.json').exists():
        rows=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf8'))
        dump(HERE/'baseline.json',rows)
        dump(HERE/'sources-before.json',{r['roblox_path']:(ROOT/r['file']).read_text(encoding='utf8') for r in rows})
        (HERE/'hierarchy-before.json.gz').write_bytes(gzip.compress((ROOT/'roblox/studio_snapshot/hierarchy.json').read_bytes(),mtime=0))
    rows=json.loads((HERE/'baseline.json').read_text());old=json.loads((HERE/'sources-before.json').read_text())
    h=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()));nodes=flat(h)
    assert not any(n['path_parts'] in (SERVER,PREVIEW) for n in nodes)
    tree=next(n for n in nodes if n['path_parts']==OLD)
    removed=[n for n in flat({'hierarchy':[tree]}) if pruned(n)]
    assert len(removed)==333 and all(n['class_name']=='Folder' for n in removed)
    pruneRoots=[n['path_parts'][3:] for n in removed if n['name'] in ('VehiclePerformanceV2UpgradePaths','UpgradePaths')]
    new=copy.deepcopy(old)
    servers=['GarageServer','OwnedGarageDisplay','OwnedGarageManagement']
    clients=['GarageUI','DesktopFreeRoamHudUI','MobileFreeRoamHudUI','RaceEntryPresentationClient']
    for p,s in old.items():
        name=p.split('.')[-1]
        if name in servers:
            pattern=r'game:GetService\("ReplicatedStorage"\):WaitForChild\("Assets"\)(?=:WaitForChild\("Vehicles"\)|\.Vehicles)'
            new[p],count=re.subn(pattern,'game:GetService("ServerStorage"):WaitForChild("Assets")',s)
            assert count>0,(name,count)
        if name in clients:
            pattern=r'(game:GetService\("ReplicatedStorage"\):WaitForChild\("Assets"\):(?:WaitForChild|FindFirstChild)\()"Vehicles"(\))'
            new[p],count=re.subn(pattern,r'\1"VehiclePreviews"\2',s);assert count>0,(name,count)
        if name=='PathResolver':
            before='return waitPath(root(), "Assets", "Vehicles", "Categories")'
            assert s.count(before)==1
            new[p]=s.replace(before,'if game:GetService("RunService"):IsServer() then return waitPath(game:GetService("ServerStorage"), "Assets", "Vehicles", "Categories") end\n\treturn waitPath(root(), "Assets", "VehiclePreviews", "Categories")')
    changed=[dict(path=p.split('.'),before=old[p],after=s) for p,s in new.items() if s!=old[p]]
    assert len(changed)==8
    fps=[]
    for r in rows:
        p=r['roblox_path'];assert hashlib.sha256(old[p].encode()).hexdigest()==r['source_sha256']
        fps.append(dict(path=r['path_parts'],className=r['class_name'],disabled=r['disabled'],beforeBytes=len(old[p].encode()),bytes=len(new[p].encode()),beforeChecksum=checksum(old[p]),checksum=checksum(new[p]),sha256=hashlib.sha256(new[p].encode()).hexdigest()))
    d=dict(sources=changed,fingerprints=fps,tree=tree,pruneRoots=pruneRoots,old=OLD,server=SERVER,preview=PREVIEW)
    dump(HERE/'payload.json',d)
    preview=copy.deepcopy(tree)
    def strip(n):
        n['children']=[c for c in n.get('children',[]) if not pruned(c)]
        for c in n['children']:strip(c)
    strip(preview);preview['name']='VehiclePreviews';rewrite(preview,OLD,PREVIEW)
    dump(HERE/'preview-expected.json',preview)
    report=dict(sourceChanges=[r['path'] for r in changed],originalInstances=len(flat({'hierarchy':[tree]})),previewInstances=len(flat({'hierarchy':[preview]})),omittedFolders=len(removed),omittedAttributes=sum(len(n['attributes']) for n in removed),originalsPreserved=True,meshTextureReduction=False)
    dump(HERE/'projection-report.json',report)
    encoded=json.dumps(d,separators=(',',':'),ensure_ascii=False);assert ']========]' not in encoded
    template=(HERE/'installer.lua').read_text(encoding='utf8')
    (ROOT/'scripts/roblox_performance_phase4_vehicle_previews.lua').write_text(template.replace('--[[PAYLOAD]]','[========['+encoded+']========]'),encoding='utf8')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
