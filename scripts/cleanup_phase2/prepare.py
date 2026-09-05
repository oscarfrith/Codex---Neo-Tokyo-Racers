"""Freeze the confirmed mirror and generate reviewable cleanup projections. Never edits Studio."""
from pathlib import Path
import json, hashlib, gzip

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

def read(path):
    if not path.exists() and path.with_suffix(path.suffix+'.gz').exists():
        with gzip.open(path.with_suffix(path.suffix+'.gz'), 'rt', encoding='utf-8') as stream:
            return stream.read()
    return path.read_text(encoding='utf-8')
def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='\n')
def dump(path, value): write(path, json.dumps(value, indent=2)+'\n')
def hash32(text):
    value=0
    for byte in text.encode(): value=(value*31+byte)%4294967296
    return value

if __name__ == '__main__':
    assert not (HERE/'baseline.json').exists(), 'Baseline is immutable; use the existing evidence'
    manifest=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
    hierarchy=json.loads(read(ROOT/'roblox/studio_snapshot/hierarchy.json'))
    rows=[]
    for row in manifest:
        source=read(ROOT/row['file'])
        file='before/'+row['file'].split('roblox/exported_scripts/')[1]
        write(HERE/file,source)
        rows.append(dict(row, before_file=file, hash32=hash32(source)))
    dump(HERE/'baseline.json',rows)
    dump(HERE/'hierarchy-before.json',hierarchy)
    print('Frozen',len(rows),'sources from',hierarchy['generated_in_studio'])
