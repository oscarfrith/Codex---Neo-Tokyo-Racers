"""P5: mechanically extract verified-safe GarageServer ranges into factory modules and add the profile
transaction snapshot/restore (ECON-01). Bodies are moved byte-for-byte; the analyser proves each range
has no assigned free variables, no stale exports and no late dependencies."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/architecture'))
from blob import find  # noqa: E402
from luadeps import analyse, uses_outside, toplevel_by_indent, lex, ASSIGN_OPS  # noqa: E402

CAP = 'roblox/captures/arch-p4-after/capture.json'
GS = 'ServerStorage.Modules.Game.Garage.GarageServer'
OUT = ROOT / 'scripts/architecture/p5/after'
OUT.mkdir(exist_ok=True)
text = find(CAP, GS).read_bytes().decode('utf8')
assert '\r' not in text
lines = text.split('\n')

RANGES = [  # (module name, first line, last line, excluded lines kept in GarageServer, purpose)
    ('GarageProfileView', 94, 286, (), 'garage profile defaults, normalisation and hydration'),
    ('GarageCapacity', 307, 515, (), 'garage capacity, owned garage properties and property/capacity purchases'),
    ('GarageCatalogLookup', 716, 911, (752,), 'cockpit/module template lookup, module metadata, pricing and slot fit'),
    ('GarageCatalogService', 1448, 1664, (), 'client catalogue build, freeze and revisioned snapshot'),
    ('GarageClientProfile', 1665, 1757, (), 'vehicle total stats and the client profile projection'),
]
TX_ACTIONS = 'BuyCockpitInstance BuyModuleInstance EquipModuleInstance BuyGarageProperty UpgradeGarageCapacity BuyCockpit BuyVehicleCosmetic BuyModule UpgradeModule Upgrade BuyNeon SelectVehicleInstance'.split()

TX_CODE = '''
	-- ECON-01: per-request transaction for purchase/ownership actions. A failed or rejected request restores
	-- only the top-level profile keys that changed, preserving the profile table identity ProfileServer needs.
	local function transactionClone(value, seen)
		if type(value) ~= "table" then return value end
		seen = seen or {}
		if seen[value] then return seen[value] end
		local copy = {}
		seen[value] = copy
		for key, child in pairs(value) do copy[key] = transactionClone(child, seen) end
		return copy
	end
	local function transactionEqual(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for key, value in pairs(a) do if not transactionEqual(value, b[key]) then return false end end
		for key in pairs(b) do if a[key] == nil then return false end end
		return true
	end
	local function snapshotProfile(profile)
		local snapshot = {}
		for key, value in pairs(profile) do
			if key ~= "_Player" then snapshot[key] = transactionClone(value) end
		end
		return snapshot
	end
	local function restoreProfile(profile, snapshot)
		local restored = 0
		for key, value in pairs(snapshot) do
			if not transactionEqual(profile[key], value) then profile[key] = transactionClone(value); restored += 1 end
		end
		for key in pairs(profile) do
			if key ~= "_Player" and snapshot[key] == nil then profile[key] = nil; restored += 1 end
		end
		return restored
	end
'''

REQUIRE = 'require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("{name}"))'

decl_line = {}
for number, line in enumerate(lines, 1):
    m = re.match(r'^\s*local\s+(?:function\s+(\w+)|([\w\s,]+?)\s*(?:=|$))', line)
    if m:
        for nm in ([m.group(1)] if m.group(1) else [x.strip() for x in m.group(2).split(',')]):
            decl_line.setdefault(nm, number)

toks = lex(text)


def assigned_at(name):
    out = []
    for i, (k, v, l) in enumerate(toks):
        if k == 'name' and v == name:
            prev = toks[i - 1][1] if i else ''
            nxt = toks[i + 1][1] if i + 1 < len(toks) else ''
            if prev not in ('.', ':', 'local', 'function') and nxt in ASSIGN_OPS:
                out.append(l)
    return out


plan, ops, report = [], [], []
for name, a, b, keep, purpose in RANGES:
    _, free, assigned_free, _ = analyse(text, a, b)
    free = sorted(f for f in free if f != 'STARTING_CASH') + (['STARTING_CASH'] if 'STARTING_CASH' in free else [])
    top = [t for t in toplevel_by_indent(text, a, b) if decl_line.get(t) not in keep]
    refs, _ = uses_outside(text, a, b, set(top))
    exports = [t for t in top if t in refs]
    real_assigned = [f for f in assigned_free if any(not re.search(r'[{,]\s*\w+\s*=', lines[l - 1]) for l in assigned_at(f) if a <= l <= b)]
    assert not real_assigned, (name, real_assigned)
    assert all(decl_line.get(f, 0) < a for f in free), (name, [f for f in free if decl_line.get(f, 0) >= a])
    assert not [e for e in exports if any(a <= l <= b for l in assigned_at(e))], name
    assert not [f for f in free if any(l > b for l in assigned_at(f))], name
    body = [lines[n - 1] for n in range(a, b + 1) if n not in keep]
    all_exports = exports
    module = ['-- Canonical feature implementation; startup is owned by the composition root.',
              f'-- GarageServer {purpose}. Extracted verbatim from the GarageServer controller closure',
              '-- (architecture P5); dependencies arrive through ctx and the same locals are returned in order.',
              'return function(ctx)']
    module += [f'\tlocal {f} = ctx.{f}' for f in free]
    module += body
    module += ['\treturn ' + ', '.join(all_exports), 'end', '']
    (OUT / f'{name}.lua').write_text('\n'.join(module), encoding='utf8', newline='\n')
    ops.append({"kind": "module", "path": ["ServerStorage", "Modules", "Game", "Garage", name], "class": "ModuleScript", "file": f"scripts/architecture/p5/after/{name}.lua"})
    kept = [lines[n - 1] for n in keep]
    ctx = '{' + ', '.join(f'{f} = {f}' for f in free) + '}'
    replacement = kept + ['\tlocal ' + ', '.join(all_exports) + ' = ' + REQUIRE.format(name=name) + '(' + ctx + ')']
    plan.append((a, b, replacement))
    report.append(f'{name}: lines {a}-{b} ({b - a + 1}) free={len(free)} exports={len(all_exports)}')

new_lines = list(lines)
for a, b, replacement in sorted(plan, reverse=True):
    new_lines[a - 1:b] = replacement
gs = '\n'.join(new_lines)


def rep(src, old, new):
    assert src.count(old) == 1, old
    return src.replace(old, new)


(OUT / 'GarageServer.lua').write_text(gs, encoding='utf8', newline='\n')
ops.append({"kind": "source", "path": GS.split('.'), "file": "scripts/architecture/p5/after/GarageServer.lua"})

spec = {
    "task": "Architecture P5: GarageServer split I (profile view, capacity, catalogue lookup/service, client profile)",
    "lane": "High-Risk",
    "contract": "Goal: reduce the GarageServer closure by moving five analyser-verified ranges verbatim into factory ModuleScripts under ServerStorage.Modules.Game.Garage (GarageProfileView, GarageCapacity, GarageCatalogLookup, GarageCatalogService, GarageClientProfile). Each module receives only its read-only free variables through ctx and returns the same locals, which GarageServer rebinds under identical names at the same position, so call order and semantics are unchanged. Proven per range: no free variable assigned inside, no export reassigned inside, no dependency reassigned later, all dependencies declared earlier; forward-declared attachDefaultModuleInstancesToCurrentVehicle stays in GarageServer. ECON-01 (money kept after an internal failure that follows a debit) is intentionally NOT changed: a safe fix needs per-path atomic transactions (reviewed designs could mint cash or grant free items) and stays open. Preserved: remote, actions, replies, messages, dirty flags, persistence commit, catalogue revision semantics. No saved-data or schema change. Rollback: installer ROLLBACK (removes the 5 modules, restores GarageServer).",
    "verification": "tooling (range analysis asserts), installation (AUDIT compile, APPLY/ROLLBACK/APPLY), api golden replies for a fixed action sequence before vs after (ids normalised), catalogue revision/size equal, garage UI purchase, errors",
    "operations": ops,
}
(ROOT / 'scripts/architecture/p5/spec.json').write_text(json.dumps(spec, indent=1), encoding='utf8')
print('\n'.join(report))
print('GarageServer lines', len(lines), '->', gs.count('\n') + 1)
