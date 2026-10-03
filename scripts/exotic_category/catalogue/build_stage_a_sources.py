"""Stage A after-files for the catalogue split, from the before capture. Read-only on Studio; writes only out/.

out/VehicleCatalogData.lua is the index; out/<CHUNK>.lua is one file per chunk child (PIERCER_1, ...).
out/manifest.json lists them in require order (index first): name, path_parts, class_name, file, chars, sha256.
out/summary.json holds the revision, the counts and the before blob this was checked against.
Running this file brings out/ up to date. test_chunks.py checks out/ against render() and does not rewrite it.

The Stage A installer writes what catalogue_gen.lua returns in Studio. These files are the expected result:
the generator's sha256 values must equal the ones in manifest.json.
"""
from pathlib import Path
import copy,hashlib,json,re,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];OUT=HERE/'out'
CAPTURE=ROOT/'roblox/captures/exotic-before/capture.json'
sys.path.insert(0,str(ROOT/'scripts'));sys.path.insert(0,str(ROOT/'scripts/performance_phase3'))
from catalogue import flat,project,chunk_sources,DATA_PATH
from studio_capture import load
SERVER=['ServerStorage','Assets','Vehicles'];OLD=['ReplicatedStorage','Assets','Vehicles']
def sha(text):return hashlib.sha256(text.encode('utf8')).hexdigest()
def authoring(h):
    """The server authoring tree of a capture, at the path project() reads."""
    tree=copy.deepcopy(next(n for n in flat(h) if n['path_parts']==SERVER))
    for n in flat({'hierarchy':[tree]}):n['path_parts']=OLD+n['path_parts'][len(SERVER):];n['path']='.'.join(n['path_parts'])
    return {'hierarchy':[tree]}
def generate(capture=CAPTURE):
    h=load(capture)
    data,legacy,_=project(authoring(h))
    return h,data,legacy,chunk_sources(data)
def render(generated=None):
    """(manifest rows, summary, {file name in out/: bytes}) for the before capture. Writes nothing."""
    h,data,legacy,sources=generated or generate()
    rows=[r for r in h['manifest'] if r['path_parts'][:len(DATA_PATH)]==DATA_PATH]
    assert len(rows)==1 and rows[0]['path_parts']==DATA_PATH,'Before capture must hold the single legacy module'
    before=(ROOT/rows[0]['file']).read_bytes()
    assert before==legacy.encode('utf8'),'Before blob is not the generated legacy source; the capture is stale'
    manifest=[];files={}
    for i,(name,text) in enumerate(sources):
        # chunk_sources() has refused text the Luau generator refuses; '\r' would not survive a text-mode round trip.
        assert re.fullmatch('[A-Za-z0-9_]+',name) and name not in ('manifest','summary'),name
        assert '\r' not in text,name
        files[name+'.lua']=text.encode('utf8')
        manifest.append(dict(name=name,path_parts=DATA_PATH+([] if i==0 else [name]),class_name='ModuleScript',file=(OUT/(name+'.lua')).relative_to(ROOT).as_posix(),chars=len(text),sha256=sha(text)))
    summary=dict(capture=CAPTURE.relative_to(ROOT).as_posix(),captureSha256=h['content_sha256'],placeId=h['place_id'],revision=data['Revision'],cockpits=len(data['Cockpits']),modules=len(data['Modules']),
                 before=dict(path_parts=DATA_PATH,file=rows[0]['file'],chars=len(legacy),sha256=rows[0]['source_sha256']),
                 chunks=[r['name'] for r in manifest[1:]],totalChars=sum(r['chars'] for r in manifest))
    files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode('utf8')
    files['summary.json']=(json.dumps(summary,indent=2)+'\n').encode('utf8')
    return manifest,summary,files
def stale(files):
    """How out/ on disk differs from render()'s files: a list of problems, empty when out/ is current.
    Only a stray .lua file counts as extra (it would read as a chunk)."""
    found={p.name for p in OUT.iterdir() if p.is_file() and (p.suffix=='.lua' or p.name in files)} if OUT.is_dir() else set()
    problems=['missing '+n for n in sorted(files.keys()-found)]+['extra '+n for n in sorted(found-files.keys())]
    return problems+['differs '+n for n in sorted(files.keys()&found) if (OUT/n).read_bytes()!=files[n]]
def write():
    """Bring out/ up to date and return (manifest rows, summary). A file that is already current is left alone."""
    manifest,summary,files=render()
    OUT.mkdir(exist_ok=True)
    for problem in stale(files):
        state,name=problem.split(' ',1)
        if state=='extra':(OUT/name).unlink()
        else:(OUT/name).write_bytes(files[name])
    assert not stale(files)
    return manifest,summary
if __name__=='__main__':
    manifest,summary=write()
    print(json.dumps(dict(summary,sources=[dict(name=r['name'],chars=r['chars'],sha256=r['sha256']) for r in manifest]),indent=2))
