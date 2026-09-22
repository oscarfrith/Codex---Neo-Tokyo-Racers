"""Read-only freshness of both generated outputs against server authoring."""
from build import ROOT,HERE,OLD,SERVER,PREVIEW,rewrite,pruned,flat,project
import collections,copy,json
def clean(n):return {k:copy.deepcopy(v) for k,v in n.items() if k not in ('children','script_id')}
def serial(n):return json.dumps(n,sort_keys=True,separators=(',',':'))
def check(h):
    nodes=flat(h);tree=next(n for n in nodes if n['path_parts']==SERVER)
    authoring=copy.deepcopy(tree);rewrite(authoring,SERVER,OLD)
    data,source,_=project({'hierarchy':[authoring]})
    manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf8'))
    row=next(r for r in manifest if r['path_parts']==['ReplicatedStorage','Modules','Game','Vehicles','VehicleCatalogData'])
    assert source==(ROOT/row['file']).read_text(encoding='utf8'),'Public catalogue stale; regenerate from server authoring'
    expected=[]
    for n in flat({'hierarchy':[tree]}):
        if pruned(n):continue
        r=clean(n);rewrite(r,SERVER,PREVIEW)
        if r['path_parts']==PREVIEW:r['name']='VehiclePreviews'
        expected.append(r)
    actual=[clean(n) for n in nodes if n['path_parts'][:3]==PREVIEW]
    assert collections.Counter(map(serial,expected))==collections.Counter(map(serial,actual)),'Preview projection stale; regenerate from server authoring'
    return dict(publicCatalogueFresh=True,previewProjectionFresh=True,revision=data['Revision'],previewInstances=len(actual))
if __name__=='__main__':
    print(json.dumps(check(json.loads((ROOT/'roblox/studio_snapshot/hierarchy.json').read_text(encoding='utf8'))),indent=2))
