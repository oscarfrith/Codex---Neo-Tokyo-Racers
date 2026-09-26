"""P6: extract the vehicle build / spawn / lifecycle ranges of GarageServer verbatim into factory modules
(bridges stay inside their owning range, so names, creation order and startup point are unchanged) and
release two per-player caches on PlayerRemoving."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/architecture'))
from blob import find  # noqa: E402
from luadeps import analyse, uses_outside, toplevel_by_indent  # noqa: E402

CAP = 'roblox/captures/arch-p5-after/capture.json'
GS = 'ServerStorage.Modules.Game.Garage.GarageServer'
UPG = 'ReplicatedStorage.Modules.Game.Vehicles.Performance.VehicleModuleUpgradeRuntime'
OUT = ROOT / 'scripts/architecture/p6/after'
OUT.mkdir(exist_ok=True)
text = find(CAP, GS).read_bytes().decode('utf8')
assert '\r' not in text
lines = text.split('\n')

RANGES = [
    ('VehicleBuildService', 856, 1128, 'vehicle paint, welding, driver seat and vehicle build/seat'),
    ('VehicleSpawnService', 1129, 1414, 'free-roam road spawn and race vehicle spawn, including the RaceVehicleSpawner bridge'),
    ('VehicleLifecycleService', 1415, 1602, 'exit/park/coast/despawn/re-enter and the OwnedGarageVehicleLifecycleBridge'),
]
EXTRA = {  # appended new code (declared behaviour change), with extra ctx names it needs
    'VehicleSpawnService': (['Players'], [
        '\t-- Release the per-player free-roam spawn cooldown when the player leaves (architecture P6).',
        '\tPlayers.PlayerRemoving:Connect(function(player) lastFreeRoamSpawnByUserId[player.UserId] = nil end)',
    ]),
}
REQUIRE = 'require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("{name}"))'

decl = {}
for number, line in enumerate(lines, 1):
    m = re.match(r'^\t?local\s+(?:function\s+(\w+)|([\w\s,]+?)\s*(?:=|$))', line)
    if m:
        for nm in ([m.group(1)] if m.group(1) else [x.strip() for x in m.group(2).split(',')]):
            decl.setdefault(nm, number)

plan, ops, report = [], [], []
for name, a, b, purpose in RANGES:
    _, free, _, _ = analyse(text, a, b)
    extra_ctx, extra_code = EXTRA.get(name, ([], []))
    free = sorted(set(free) | set(extra_ctx))
    assert all(0 < decl.get(f, 0) < a for f in free), (name, [f for f in free if not 0 < decl.get(f, 0) < a])
    top = toplevel_by_indent(text, a, b)
    refs, assigned_outside = uses_outside(text, a, b, set(top))
    assert not assigned_outside, (name, assigned_outside)
    exports = [t for t in top if t in refs]
    module = ['-- Canonical feature implementation; startup is owned by the composition root.',
              f'-- GarageServer {purpose}. Extracted verbatim from the GarageServer controller closure',
              '-- (architecture P6); dependencies arrive through ctx and the same locals are returned in order.',
              'return function(ctx)']
    module += [f'\tlocal {f} = ctx.{f}' for f in free]
    module += lines[a - 1:b]
    module += extra_code
    module += ['\treturn ' + ', '.join(exports), 'end', '']
    (OUT / f'{name}.lua').write_text('\n'.join(module), encoding='utf8', newline='\n')
    ops.append({"kind": "module", "path": ["ServerStorage", "Modules", "Game", "Garage", name], "class": "ModuleScript", "file": f"scripts/architecture/p6/after/{name}.lua"})
    ctx = '{' + ', '.join(f'{f} = {f}' for f in free) + '}'
    plan.append((a, b, ['\tlocal ' + ', '.join(exports) + ' = ' + REQUIRE.format(name=name) + '(' + ctx + ')']))
    report.append(f'{name}: lines {a}-{b} free={len(free)} exports={exports}')

new_lines = list(lines)
for a, b, replacement in sorted(plan, reverse=True):
    new_lines[a - 1:b] = replacement
(OUT / 'GarageServer.lua').write_text('\n'.join(new_lines), encoding='utf8', newline='\n')
ops.append({"kind": "source", "path": GS.split('.'), "file": "scripts/architecture/p6/after/GarageServer.lua"})

upg = find(CAP, UPG).read_bytes().decode('utf8')
anchor = 'local profiles = {}\n'
assert upg.count(anchor) == 1
upg = upg.replace(anchor, anchor + '-- Release cached profiles when a player leaves so a rejoin never reuses a stale session table (architecture P6).\n'
                  'if game:GetService("RunService"):IsServer() then\n'
                  '\tgame:GetService("Players").PlayerRemoving:Connect(function(player) profiles[player.UserId] = nil end)\n'
                  'end\n')
(OUT / 'VehicleModuleUpgradeRuntime.lua').write_text(upg, encoding='utf8', newline='\n')
ops.append({"kind": "source", "path": UPG.split('.'), "file": "scripts/architecture/p6/after/VehicleModuleUpgradeRuntime.lua"})

spec = {
    "task": "Architecture P6: GarageServer split II (vehicle build, spawn, lifecycle) + per-player cache release",
    "lane": "High-Risk",
    "contract": "Goal: move the vehicle build (856-1128), spawn (1129-1414, includes the RaceVehicleSpawner bridge and its startup call) and lifecycle (1415-1602, includes OwnedGarageVehicleLifecycleBridge) ranges of GarageServer verbatim into factory modules VehicleBuildService, VehicleSpawnService and VehicleLifecycleService under ServerStorage.Modules.Game.Garage, rebinding the same exports at the same positions so bridge names, creation order and startup point are unchanged. Owners: VehicleSpawn/Lifecycle keep the PlayerVehicles attribute contract exactly as before. Declared behaviour changes: lastFreeRoamSpawnByUserId and VehicleModuleUpgradeRuntime's profiles cache are cleared on PlayerRemoving (server only), so memory is released and a same-server rejoin cannot reuse a stale profile table. Not changed: VehicleAccessServer's own enter logic (separate owner; consolidation deferred). Preserved: all replies, messages, network ownership, parking/coasting, race spawn validation. Rollback: installer ROLLBACK.",
    "verification": "installation (AUDIT compile, APPLY/ROLLBACK/APPLY), api golden replies (P5 18-step sequence incl. spawn/exit/re-enter/despawn) identical, race spawn via time trial, owned garage enter/exit (lifecycle bridge), errors, cleanup (spawn cycles)",
    "operations": ops,
}
(ROOT / 'scripts/architecture/p6/spec.json').write_text(json.dumps(spec, indent=1), encoding='utf8')
print('\n'.join(report))
print('GarageServer lines', len(lines), '->', len(new_lines))
