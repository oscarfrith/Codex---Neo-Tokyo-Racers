"""Freeze reviewed cleanup records from the pre-cleanup mirror; build one installer."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
def read(p): return p.read_text(encoding='utf-8')
def write(p, text): p.write_text(text, encoding='utf-8', newline='\n')
def digest(nodes):
    rows = sorted(json.dumps(n, sort_keys=True, separators=(',', ':')) for n in nodes)
    return hashlib.sha256('\n'.join(rows).encode()).hexdigest()
def flatten(tree):
    result = []
    pending = list(tree)
    while pending:
        node = pending.pop()
        pending.extend(node.get('children', []))
        result.append({k:v for k,v in node.items() if k != 'children'})
    return result
def literal(text):
    eq = '===='
    while ']' + eq + ']' in text: eq += '='
    return '[' + eq + '[\n' + text + ']' + eq + ']'

baseline = HERE / 'baseline.json'
if not baseline.exists():
    data = json.loads(read(HERE / 'inventory.json'))
    hierarchy = json.loads(read(ROOT / 'roblox/studio_snapshot/hierarchy.json'))
    flat = flatten(hierarchy['hierarchy'])
    by_path = {tuple(n['path_parts']): n for n in flat}
    manifest = json.loads(read(ROOT / 'roblox/exported_scripts/manifest.json'))
    sources = {tuple(s['path_parts']): s for s in manifest}
    removed = {tuple(n['path']) for n in data['nodes']}
    for node in data['nodes']:
        old = by_path[tuple(node['path'])]
        assert old['class_name'] == node['class']
        node['attributes'] = {}
        for key, value in (old['attributes'] or {}).items():
            assert value['type'] in ('string', 'number', 'boolean'), (node['path'], key)
            node['attributes'][key] = value['value']
        if node['class'] == 'StringValue': node['value'] = old['properties']['Value']['value']
        if node['class'] == 'ObjectValue': node['target'] = old['properties']['Value'].get('path_parts', False)
        if tuple(node['path']) in sources: node['source'] = read(ROOT / sources[tuple(node['path'])]['file'])
    data['nodes'].sort(key=lambda n:(len(n['path']), n['path']))
    data['sources'] = [dict(path=s['path_parts'], className=s['class_name'], bytes=s['source_bytes'], checksum=int(s['source_checksum']), disabled=s['disabled'], sha256=s['source_sha256']) for s in manifest]
    data['mirrorBefore'] = hierarchy['generated_in_studio']
    data['beforeDigest'] = digest(flat)
    expected = [n for n in flat if tuple(n['path_parts']) not in removed]
    targets = {tuple(n['path_parts']):n for n in expected}
    for attribute in data['attributes']:
        target = targets[tuple(attribute['path'])]
        del target['attributes'][attribute['key']]
        if not target['attributes']: target['attributes'] = []
    data['expectedDigest'] = digest(expected)
    data['expectedNodeCount'] = len(expected)
    write(baseline, json.dumps(data, indent=2))
else:
    data = json.loads(read(baseline))
payload = json.dumps(data, separators=(',', ':'), ensure_ascii=False)
template = read(HERE / 'installer_template.lua')
write(ROOT / 'scripts/roblox_legacy_cleanup.lua', template.replace('--[[PAYLOAD]]', literal(payload)))
print(json.dumps({'nodes':len(data['nodes']), 'sourcesRemoved':sum('source' in n for n in data['nodes']), 'attributes':len(data['attributes']), 'before':data['mirrorBefore']}))
