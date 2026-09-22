"""Freeze current verified mirror and build exact, token-checked source cleanup."""
from pathlib import Path
import json, gzip, hashlib, re, sys, collections
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts/cleanup_phase2'))
from path_analysis import TOKEN,tokens,literal
def write(p,s):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8',newline='\n')
def dump(p,x):write(p,json.dumps(x,indent=2)+'\n')
manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text())
if not (HERE/'baseline.json').exists():
    dump(HERE/'baseline.json',manifest)
    (HERE/'hierarchy-before.json.gz').write_bytes(gzip.compress((ROOT/'roblox/studio_snapshot/hierarchy.json').read_bytes(),mtime=0))
    for r in manifest:write(HERE/'before'/r['file'].split('roblox/exported_scripts/')[1],(ROOT/r['file']).read_text(encoding='utf-8'))
rows=json.loads((HERE/'baseline.json').read_text());payload=[];report=[]
for r in rows:
    s=(HERE/'before'/r['file'].split('roblox/exported_scripts/')[1]).read_text(encoding='utf-8')
    assert hashlib.sha256(s.encode()).hexdigest()==r['source_sha256']
    ts=tokens(s); identifiers={t for t,_,_ in ts if re.fullmatch(r'[A-Za-z_]\w*',t)}
    mapping={};edits=[];logs={}
    if r['path_parts'][0]!='Workspace':
        owner=r['path_parts'][-1];prefix=owner[0].lower()+owner[1:]
        for name in sorted(identifiers):
            if re.match(r'^[vV]\d+[A-Za-z]?_',name):
                stem=re.sub(r'^[vV]\d+[A-Za-z]?_','',name)
                overrides={'V80_countDictionary':'countOwnedEntries','V84_countDictionary':'countGarageEntries','V87_countDictionary':'countSavedEntries'}
                dest=overrides.get(name,stem[0].lower()+stem[1:] if not stem.isupper() else stem)
                if dest in identifiers or dest in mapping.values():dest=prefix+'_'+stem
                assert dest not in identifiers and dest not in mapping.values(),(owner,name,dest)
                # Reflective string access would require a separately reviewed contract.
                assert not any(literal(t)==name for t,_,_ in ts),(owner,'reflective identifier',name)
                mapping[name]=dest
        if 'ntr' in identifiers:
            assert 'replicatedStorageRoot' not in identifiers
            assert not any(literal(t)=='ntr' for t,_,_ in ts)
            mapping['ntr']='replicatedStorageRoot'
        for old,new in {'neoTokyo':'replicatedStorageRoot','phase1Global':'globalAudioConfig'}.items():
            if old in identifiers:
                assert new not in identifiers and new not in mapping.values()
                mapping[old]=new
        for i,(t,a,b) in enumerate(ts):
            if t in mapping:edits.append((a,b,mapping[t]))
            elif literal(t) is not None:
                v=literal(t)
                if re.match(r'^\[[^\]]*(?:Phase|Legacy|V\d|NTR|Hover Racing)[^\]]*\]',v):
                    new=re.sub(r'^\[[^\]]*\]','['+owner+']',v)
                    replacement=t[0]+new+t[-1];edits.append((a,b,replacement));logs[a]=replacement
                elif owner=='ProfileCompatibilityServer' and v=='LegacyGarageProfileBridge':
                    replacement=t[0]+'GarageProfileProjection'+t[-1];edits.append((a,b,replacement));logs[a]=replacement
                elif owner=='DriverSeatServer' and v=='Hover Racing driver seat position keeper running.':
                    replacement=t[0]+'[DriverSeatServer] Driver seat position keeper running.'+t[-1];edits.append((a,b,replacement));logs[a]=replacement
        for m in TOKEN.finditer(s):
            text=m.group()
            if not text.startswith('--'):continue
            # Remove historical patch stamps, not meaningful explanatory comments.
            if re.fullmatch(r'--\s*(?:NTR_|HOVER_RACING_|V\d)[A-Za-z0-9_ .:-]*',text):
                edits.append((m.start(),m.end(),''))
            elif 'Disabled switch candidate generated from the current V56 action block.' in text:
                edits.append((m.start(),m.end(),'-- Canonical garage action owner.'))
    out=s
    for a,b,t in sorted(edits,reverse=True):out=out[:a]+t+out[b:]
    expected=[mapping.get(t,logs.get(a,t)) for t,a,b in ts]
    assert [t for t,_,_ in tokens(out)]==expected,('unexpected executable change',r['roblox_path'])
    row={'path':r['path_parts'],'class':r['class_name'],'disabled':r.get('disabled',False),'before':s,'after':out}
    payload.append(row)
    if out!=s:report.append({'path':r['roblox_path'],'identifiers':mapping,'diagnostic_strings':len(logs),'edits':len(edits)})
dump(HERE/'payload.json',{'placeId':121304917315753,'sources':payload})
dump(HERE/'source-change-report.json',report)
template=(HERE/'installer.lua').read_text(encoding='utf-8')
data=json.dumps({'placeId':121304917315753,'sources':payload},separators=(',',':'))
assert ']========]' not in data
write(ROOT/'scripts/roblox_cleanup_phase4_finalise.lua',template.replace('--[[PAYLOAD]]','[========['+data+']========]'))
print('Sources:',len(payload),'changed:',len(report),'identifiers:',sum(len(r['identifiers']) for r in report))
