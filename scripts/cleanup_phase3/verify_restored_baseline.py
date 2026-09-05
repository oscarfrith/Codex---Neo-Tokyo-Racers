"""Read-only full export comparison after rolling Phase 3 back."""
from prepare import *

baseline = json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()))
current = json.loads(read(ROOT/'roblox/studio_snapshot/hierarchy.json'))
def records(h):
    return collections.Counter(json.dumps({k:v for k,v in n.items() if k not in ('children','script_id')}, sort_keys=True) for n in flatten(h))
before, after = records(baseline), records(current)
expected = {tuple(r['path_parts']):r['source_sha256'] for r in json.loads(read(HERE/'baseline.json'))}
actual = {tuple(r['path_parts']):r['source_sha256'] for r in json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))}
result = {'mirror':current['generated_in_studio'], 'source_sha256_parity':expected == actual, 'hierarchy_property_parity':before == after, 'missing_or_changed':sum((before-after).values()), 'added_or_changed':sum((after-before).values())}
dump(HERE/'restored-baseline-verification.json', result)
dump(HERE/'restored-baseline-differences.json', {'missing_or_changed':[json.loads(x) for x in (before-after).elements()], 'added_or_changed':[json.loads(x) for x in (after-before).elements()]})
print(json.dumps(result, indent=2))
assert expected == actual and before == after
