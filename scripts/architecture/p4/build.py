"""Build P4 after-sources: route every Cash debit through Player.MoneyService (exact single-occurrence edits)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/architecture'))
from blob import find  # noqa: E402

CAP = 'roblox/captures/arch-p3-after/capture.json'
OUT = ROOT / 'scripts/architecture/p4/after'
OUT.mkdir(exist_ok=True)
PATH = 'game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("MoneyService")'
REQ = 'local MoneyService = require(' + PATH + ')\n'
LAZY = 'require(' + PATH + ')'


def edit(path, reps):
    s = find(CAP, path).read_bytes().decode('utf8')
    for a, b, n in reps:
        assert s.count(a) == n, (path, a, s.count(a))
        s = s.replace(a, b)
    name = path.split('.')[-1]
    (OUT / f'{name}.lua').write_bytes(s.encode('utf8'))
    return {"kind": "source", "path": path.split('.'), "file": f"scripts/architecture/p4/after/{name}.lua"}


ops = [{"kind": "module", "path": ["ServerStorage", "Modules", "Game", "Player", "MoneyService"], "class": "ModuleScript", "file": "scripts/architecture/p4/MoneyService.lua"}]
ops.append(edit('ServerStorage.Modules.Game.Garage.GarageServer', [
    ('\tlocal ProfileServer = require(game.ServerStorage.Modules.Game.Player.ProfileServer)\n',
     '\tlocal ProfileServer = require(game.ServerStorage.Modules.Game.Player.ProfileServer)\n\t' + REQ, 1),
    ('\t\tprofile.Cash -= price\n\t\townedGarageProperties(profile)[propertyId] = {',
     '\t\tMoneyService.Debit(profile, price, "GarageProperty")\n\t\townedGarageProperties(profile)[propertyId] = {', 1),
    ('\t\tprofile.Cash -= price\n\t\tprofile.CurrentCockpit = cockpitId\n',
     '\t\tMoneyService.Debit(profile, price, "CockpitInstance")\n\t\tprofile.CurrentCockpit = cockpitId\n', 1),
    ('\t\t\t\t\t\t\tprofile.Cash -= price\n\t\t\t\t\t\t\tprofile.OwnedCockpits[cockpitId] = true',
     '\t\t\t\t\t\t\tMoneyService.Debit(profile, price, "LegacyCockpit")\n\t\t\t\t\t\t\tprofile.OwnedCockpits[cockpitId] = true', 1),
    ('\t\t\t\t\t\t\tprofile.Cash -= price\n\t\t\t\t\t\t\tprofile.OwnedModules[moduleId] = true',
     '\t\t\t\t\t\t\tMoneyService.Debit(profile, price, "LegacyModule")\n\t\t\t\t\t\t\tprofile.OwnedModules[moduleId] = true', 1),
    ('else profile.Cash -= price; profile.UpgradeLevels[upgradeId] = level + 1;',
     'else MoneyService.Debit(profile, price, "LegacyUpgrade"); profile.UpgradeLevels[upgradeId] = level + 1;', 1),
    ('\t\t\t\t\t\t\tprofile.Cash -= price\n\t\t\t\t\t\t\tprofile.NeonOwned[slotId] = true',
     '\t\t\t\t\t\t\tMoneyService.Debit(profile, price, "Neon")\n\t\t\t\t\t\t\tprofile.NeonOwned[slotId] = true', 1),
]))
ops.append(edit('ServerStorage.Modules.Game.Garage.GarageModuleTransaction', [
    ('profile.Cash=(tonumber(profile.Cash) or 0)-price', LAZY + '.Debit(profile,price,"ModuleInstance")', 1),
]))
ops.append(edit('ServerStorage.Modules.Game.Garage.VehicleCosmeticServer', [
    ('\tprofile.Cash=(tonumber(profile.Cash) or 0)-price\n', '\t' + LAZY + '.Debit(profile,price,"VehicleCosmetic")\n', 1),
]))
ops.append(edit('ServerStorage.Modules.Game.Garage.OwnedGarageProfile', [
    ('profile.Cash=(tonumber(profile.Cash) or 0)-cost', LAZY + '.Debit(profile,cost,"OwnedGarageCustomisation")', 3),
]))
ops.append(edit('ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceUpgradeRuntime', [
    # Shared module; the purchase path only runs on the server, so require lazily there.
    ('\tprofile.Cash -= cost\n', '\t' + LAZY + '.Debit(profile, cost, "ModuleUpgrade")\n', 1),
]))

spec = {
    "task": "Architecture P4: MoneyService single debit point",
    "lane": "High-Risk",
    "contract": "Goal: every Cash debit goes through ServerStorage.Modules.Game.Player.MoneyService.Debit. Sites: GarageServer (garage property, cockpit instance, legacy cockpit/module/upgrade, neon), GarageModuleTransaction (module instance), VehicleCosmeticServer, OwnedGarageProfile (3 customisation purchases), PerformanceUpgradeRuntime (module upgrade). Each site keeps its own affordability check, message and transaction order; for valid prices the resulting balance is identical. New invariant: invalid (NaN/negative/infinite) prices or insufficient funds raise inside the existing pcall-protected request instead of corrupting or inflating Cash. Credits (EconomyServer grants, the VehicleModuleUpgradeRuntime V2 migration refund) unchanged. No save/schema/remote/UI change; MoneyService never saves.",
    "verification": "tooling (MoneyService tests), installation, api (sandbox purchases for each site: cash delta equals price, insufficient funds message unchanged), garage (UI purchase), errors",
    "operations": ops,
}
(ROOT / 'scripts/architecture/p4/spec.json').write_text(json.dumps(spec, indent=1), encoding='utf8')
print(len(ops), 'operations')
