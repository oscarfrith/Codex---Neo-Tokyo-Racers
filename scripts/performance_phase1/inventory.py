"""Read-only mirror analysis; writes only this phase's report, never game sources.

Conservative path/literal evidence, not a Luau compiler or proof of non-use.
Reuses the existing path analyser; long-bracket startup literals are read separately.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'scripts/cleanup_phase2'))
from path_analysis import analyze, tokens


def run():
    manifest = json.loads((ROOT / 'roblox/exported_scripts/manifest.json').read_text(encoding='utf-8'))
    hierarchy = json.loads((ROOT / 'roblox/studio_snapshot/hierarchy.json').read_text(encoding='utf-8'))
    nodes = []

    def walk(node):
        nodes.append(node)
        for child in node.get('children', []):
            walk(child)

    for node in hierarchy['hierarchy']:
        walk(node)
    evidence = {}
    hotspots = []
    for row in manifest:
        source = (ROOT / row['file']).read_text(encoding='utf-8')
        assert hashlib.sha256(source.encode()).hexdigest() == row['source_sha256'], row['file']
        chains, aliases = analyze(source, row['path_parts'])
        literals = []
        for token, start, end in tokens(source):
            if token.startswith(('"', "'")):
                value = token[1:-1]
            else:
                match = re.fullmatch(r'\[(=*)\[(.*?)\]\1\]', token, re.S)
                if not match:
                    continue
                value = match[2].strip()
            literals.append(value)
        evidence[row['roblox_path']] = {
            'paths': sorted({'.'.join(c[2]) for c in chains}),
            'literals': sorted(set(literals)),
            'ambiguousAliases': sorted(k for k, v in aliases.items() if len(v) > 1),
        }
        for number, line in enumerate(source.splitlines(), 1):
            if any(x in line for x in ('GetDescendants()', 'FireAllClients(', 'PreloadAsync(', 'RenderStepped:Connect', 'Heartbeat:Connect')):
                hotspots.append({'source': row['roblox_path'], 'line': number, 'code': line.strip()[:350], 'status': 'review candidate, not measured hotspot'})

    def refs(path):
        name = path.rsplit('.', 1)[-1]
        found = []
        for owner, data in evidence.items():
            if owner == path:
                continue
            direct = [p for p in data['paths'] if p == path or p.startswith(path + '.')]
            literals = [v for v in data['literals'] if v == name or v == path or v.startswith(path + '.')]
            if direct or literals:
                found.append({'source': owner, 'resolvedPaths': direct, 'literalCandidates': literals,
                              'note': 'Literal-only references require manual classification; comments excluded.'})
        return found

    moves = [
        'ReplicatedStorage.Modules.Game.Player.PlayerProfileSchema',
        'ReplicatedStorage.Modules.Game.Player.GarageProfileProjection',
        'ReplicatedStorage.Modules.Game.Vehicles.Performance.VehiclePerformance',
        'ReplicatedStorage.Config.Player.Persistence',
        'ReplicatedStorage.Config.Racing.PersonalBests',
        'ReplicatedStorage.Config.Racing.Leaderboards',
    ]
    move_report = []
    for path in moves:
        subtree = [n for n in nodes if n['path'] == path or n['path'].startswith(path + '.')]
        move_report.append({'from': path, 'to': path.replace('ReplicatedStorage.', 'ServerStorage.', 1),
                            'records': len(subtree), 'attributes': sum(len(n.get('attributes', {})) for n in subtree),
                            'sourceBytes': sum(r['source_bytes'] for r in manifest if r['roblox_path'] == path),
                            'references': refs(path), 'status': 'candidate only; no move authorised by this report'})
    config = []
    for node in nodes:
        if node['path'].startswith('ReplicatedStorage.Config.') and len(node['path_parts']) == 4:
            config.append({'path': node['path'], 'attributes': node.get('attributes', {}), 'references': refs(node['path'])})
    module_paths = {r['roblox_path'] for r in manifest if r['class_name'] == 'ModuleScript'}
    graph = {}
    for owner, data in evidence.items():
        # Conservative dependency edges: navigation is not necessarily a require.
        paths = data['paths'] + data['literals']
        graph[owner] = sorted(p for p in module_paths if p != owner and any(v == p or v.startswith(p + '.') for v in paths))
    reachable = set()
    pending = [r['roblox_path'] for r in manifest if r['class_name'] == 'LocalScript']
    while pending:
        owner = pending.pop()
        if owner not in reachable:
            reachable.add(owner)
            pending.extend(graph.get(owner, []))
    report = {'mirror': hierarchy['generated_in_studio'], 'sources': len(manifest), 'nodes': len(nodes),
              'limitations': ['Conservative syntactic path and literal report; dynamic aliases/reflection need manual inspection.',
                              'Source bytes and node counts are not network bytes, memory savings or FPS.',
                              'No zero-reference result authorises deletion.'],
              'moveCandidates': move_report, 'configConsumers': config, 'sourceEvidence': evidence,
              'conservativeModuleEdges': graph, 'staticClientReachable': sorted(reachable),
              'potentialHotspots': hotspots}
    (HERE / 'dependency-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'sources': len(manifest), 'nodes': len(nodes), 'moveCandidates': len(moves),
                      'configGroups': len(config), 'output': str(HERE / 'dependency-report.json')}, indent=2))


if __name__ == '__main__':
    run()
