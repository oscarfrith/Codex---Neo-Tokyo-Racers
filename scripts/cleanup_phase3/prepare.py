"""Freeze Phase 2 mirror for Phase 3 review; no Studio writes."""
from pathlib import Path
import json,gzip,hashlib,re,collections,sys
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
def read(p):return p.read_text(encoding='utf-8')
def write(p,s):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8',newline='\n')
def dump(p,x):write(p,json.dumps(x,indent=2)+'\n')
def flatten(h):
    result=[];todo=list(h['hierarchy'])
    while todo:
        n=todo.pop();todo.extend(n.get('children',[]));result.append(n)
    return result
if __name__=='__main__':
    assert not (HERE/'baseline.json').exists(),'Frozen baseline already exists'
    manifest=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
    h=json.loads(read(ROOT/'roblox/studio_snapshot/hierarchy.json'))
    rows=[]
    for r in manifest:
        s=read(ROOT/r['file']);assert hashlib.sha256(s.encode()).hexdigest()==r['source_sha256']
        dest='before/'+r['file'].split('roblox/exported_scripts/')[1];write(HERE/dest,s)
        rows.append(dict(r,before_file=dest))
    dump(HERE/'baseline.json',rows)
    (HERE/'hierarchy-before.json.gz').write_bytes(gzip.compress(json.dumps(h).encode(),mtime=0))
    print('Frozen',len(rows),'sources;',h['generated_in_studio'],'(live parity still required)')
