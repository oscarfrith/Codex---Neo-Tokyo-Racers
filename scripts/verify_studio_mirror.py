"""Read-only integrity report; optionally compare against the Phase 1 frozen baseline."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verify(baseline=None):
    manifest = json.loads((ROOT / 'roblox/exported_scripts/manifest.json').read_text(encoding='utf-8'))
    other = json.loads((ROOT / 'roblox/studio_snapshot/source_manifest.json').read_text(encoding='utf-8'))
    checks = json.loads((ROOT / 'roblox/studio_snapshot/checksums.json').read_text(encoding='utf-8'))
    hierarchy = json.loads((ROOT / 'roblox/studio_snapshot/hierarchy.json').read_text(encoding='utf-8'))
    blockers, warnings = [], []
    if manifest != other: blockers.append('Source manifests disagree')
    if hierarchy.get('place_id') != 121304917315753: blockers.append('Wrong place')
    seen, fingerprints = set(), {}
    for row in manifest:
        name = row['roblox_path']
        if name in seen: blockers.append('Duplicate source: ' + name)
        seen.add(name)
        file = (ROOT / row['file']).resolve()
        if not file.is_relative_to((ROOT / 'roblox/exported_scripts').resolve()):
            blockers.append('Source path outside mirror: ' + name); continue
        # Git may check out CRLF; compare canonical UTF-8/LF script text.
        raw = file.read_text(encoding='utf-8').encode('utf-8')
        sha = hashlib.sha256(raw).hexdigest()
        checksum = str(sum(i*b for i, b in enumerate(raw, 1)) % 1000000007)
        if len(raw) != row['source_bytes'] or checksum != row['source_checksum']:
            blockers.append('Source mismatch: ' + name)
        if (raw.count(b'\n') + 1 if raw else 0) != row['source_lines']:
            blockers.append('Line count mismatch: ' + name)
        if row.get('source_sha256') and sha != row['source_sha256']:
            blockers.append('SHA-256 mismatch: ' + name)
        for key in ['source_checksum', 'source_bytes', 'source_lines', 'disabled', 'class_name', 'file', 'source_sha256']:
            if checks.get(name, {}).get(key) != row.get(key): blockers.append('Checksum manifest mismatch: ' + name + ':' + key)
        fingerprints[name] = dict(sha256=sha, disabled=row['disabled'], class_name=row['class_name'])
    if len(manifest) != hierarchy.get('script_count') or set(checks) != seen:
        blockers.append('Script count/set mismatch')
    nodes, properties = list(hierarchy['hierarchy']), 0
    source_nodes = {}
    while nodes:
        node = nodes.pop(); nodes.extend(node.get('children', []))
        properties += len(node.get('properties', {}))
        if node.get('script_id'):
            if node['path'] in source_nodes: blockers.append('Duplicate hierarchy source: ' + node['path'])
            source_nodes[node['path']] = node
    if set(source_nodes) != seen: blockers.append('Hierarchy source set mismatch')
    for row in manifest:
        node = source_nodes.get(row['roblox_path'], {})
        if any(node.get(key) != row.get(key) for key in ['source_checksum', 'disabled', 'class_name', 'source_lines']):
            blockers.append('Hierarchy source mismatch: ' + row['roblox_path'])
    if baseline:
        expected = json.loads(Path(baseline).read_text(encoding='utf-8'))['scripts']
        for name in sorted(set(expected) | set(fingerprints)):
            if expected.get(name) != fingerprints.get(name): blockers.append('Baseline changed: ' + name)
    if hierarchy.get('schema_revision', 2) < 3: warnings.append('Legacy snapshot lacks ordinary property coverage')
    diagnostics = hierarchy.get('diagnostics', {})
    errors = diagnostics.get('property_read_errors', [])
    if errors: warnings.append(f'{len(errors)} property reads unavailable; inspect diagnostics')
    duplicates = diagnostics.get('duplicate_paths', [])
    if duplicates: warnings.append(f'{len(duplicates)} duplicate non-source paths; avoid ambiguous path mutations')
    return dict(status='BLOCKER' if blockers else 'PASS', scripts=len(manifest), properties=properties,
                generated_in_studio=hierarchy.get('generated_in_studio'), blockers=blockers, warnings=warnings)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--baseline'); args = parser.parse_args()
    report = verify(args.baseline)
    print(json.dumps(report, indent=2))
    raise SystemExit(bool(report['blockers']))
