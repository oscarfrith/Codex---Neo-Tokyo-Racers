"""Freeze verified Phase 1 evidence and build one exact-source storage migration."""
from pathlib import Path
import gzip, hashlib, json, sys
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts/cleanup_phase2'))
from path_analysis import analyze, tokens

def dump(path,value): path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def flatten(h):
    out=[]; todo=list(h['hierarchy'])
    while todo:
        n=todo.pop();out.append(n);todo.extend(n.get('children',[]))
    return out
def checksum(s):return str(sum(i*b for i,b in enumerate(s.encode(),1))%1000000007)
def target(p,moves):
    for m in moves:
        if p[:len(m['before'])]==m['before']:return m['after']+p[len(m['before']):]
    return p

if __name__=='__main__':
    if not (HERE/'baseline.json').exists():
        rows=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf-8'))
        dump(HERE/'baseline.json',rows)
        (HERE/'hierarchy-before.json.gz').write_bytes(gzip.compress((ROOT/'roblox/studio_snapshot/hierarchy.json').read_bytes(),mtime=0))
        # Repository recovery only; no duplicate implementations inside Studio.
        dump(HERE/'sources-before.json',{r['roblox_path']:(ROOT/r['file']).read_text(encoding='utf-8') for r in rows})
    rows=json.loads((HERE/'baseline.json').read_text())
    old=json.loads((HERE/'sources-before.json').read_text())
    nodes=flatten(json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes())))
    candidates=json.loads((ROOT/'scripts/performance_phase1/dependency-report.json').read_text())['moveCandidates']
    moves=[{'before':r['from'].split('.'),'after':r['to'].split('.')} for r in candidates]
    changed=[]; fingerprints=[]; changes=[]
    for r in rows:
        source=old[r['roblox_path']]
        assert hashlib.sha256(source.encode()).hexdigest()==r['source_sha256']
        chains,_=analyze(source,r['path_parts']); edits=[]
        for start,end,path,steps in chains:
            if any(list(path[:len(m['before'])])==m['before'] for m in moves):
                # Replace only the service literal in a proven complete navigation chain.
                fragment=source[start:end]
                prefix='game:GetService("ReplicatedStorage")'
                assert fragment.startswith(prefix),(r['roblox_path'],fragment)
                edits.append((start+len('game:GetService("'),start+len('game:GetService("ReplicatedStorage'),'ServerStorage'))
        new=source
        for start,end,value in reversed(edits):new=new[:start]+value+new[end:]
        if new!=source:
            before_tokens=[t[0] for t in tokens(source)];after_tokens=[t[0] for t in tokens(new)]
            assert len(before_tokens)==len(after_tokens)
            pairs=[(a,b) for a,b in zip(before_tokens,after_tokens) if a!=b]
            assert len(pairs)==len(edits) and all(a=='"ReplicatedStorage"' and b=='"ServerStorage"' for a,b in pairs)
            changed.append({'path':r['path_parts'],'before':source,'after':new})
            changes.append({'path':r['roblox_path'],'serviceLiteralChanges':len(edits)})
        fingerprints.append({'beforePath':r['path_parts'],'path':target(r['path_parts'],moves),'class':r['class_name'],
                             'disabled':r['disabled'],'beforeChecksum':checksum(source),'checksum':checksum(new),
                             'beforeBytes':len(source.encode()),'bytes':len(new.encode()),
                             'sha256':hashlib.sha256(new.encode()).hexdigest()})
    assert len(changed)==6,changes
    created=[['ServerStorage','Modules','Game','Vehicles','Performance'],['ServerStorage','Config'],
             ['ServerStorage','Config','Player'],['ServerStorage','Config','Racing']]
    for p in created:assert not any(n['path_parts']==p for n in nodes),p
    moved=[{k:v for k,v in n.items() if k not in ('children','script_id')} for n in nodes if target(n['path_parts'],moves)!=n['path_parts']]
    assert len(moved)==14
    payload={'placeId':121304917315753,'moves':moves,'created':created,'sources':changed,'fingerprints':fingerprints,'movedRecords':moved}
    dump(HERE/'payload.json',payload);dump(HERE/'source-changes.json',changes)
    encoded=json.dumps(payload,separators=(',',':'),ensure_ascii=False)
    delimiter='========'
    assert ']'+delimiter+']' not in encoded
    template=(HERE/'installer.lua').read_text(encoding='utf-8')
    (ROOT/'scripts/roblox_performance_phase2_server_storage.lua').write_text(template.replace('--[[PAYLOAD]]','['+delimiter+'['+encoded+']'+delimiter+']'),encoding='utf-8')
    print(json.dumps({'changedSources':len(changed),'moves':len(moves),'movedInstances':len(moved),'newFolders':len(created),'changes':changes},indent=2))
