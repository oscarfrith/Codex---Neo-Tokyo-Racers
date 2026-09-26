"""Build P9 retirement: remove dead remotes, the legacy DriveInCustomisationSession event, an unused path helper
and client-unused legacy garage actions (exact single-occurrence edits)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/architecture'))
from blob import find  # noqa: E402

CAP = 'roblox/captures/arch-p8-after/capture.json'
OUT = ROOT / 'scripts/architecture/p9/after'
OUT.mkdir(exist_ok=True)


def edit(path, reps):
    s = find(CAP, path).read_bytes().decode('utf8')
    for a, b in reps:
        assert s.count(a) == 1, (path, a[:80], s.count(a))
        s = s.replace(a, b)
    name = path.split('.')[-1]
    (OUT / f'{name}.lua').write_text(s, encoding='utf8', newline='\n')
    return {"kind": "source", "path": path.split('.'), "file": f"scripts/architecture/p9/after/{name}.lua"}


ops = []
for name, cls in [('GaragePush', 'RemoteEvent'), ('GarageInteriorTransition', 'RemoteEvent'),
                  ('GarageInteriorCustomizationInvoke', 'RemoteFunction'), ('GarageInteriorInvoke', 'RemoteFunction')]:
    ops.append({"kind": "remove_instance", "path": ["ReplicatedStorage", "Remotes", "Garage", name], "class": cls})

session = find(CAP, 'ServerStorage.Modules.Game.Garage.GarageSessionServer').read_bytes().decode('utf8')
legacy_line = next(l for l in session.split('\n') if 'legacy.OnServerEvent:Connect' in l) + '\n'
ops.append(edit('ServerStorage.Modules.Game.Garage.GarageSessionServer', [
    ('local legacy = uiRemotes:FindFirstChild("DriveInCustomisationSession") or Instance.new("RemoteEvent")\n'
     'legacy.Name = "DriveInCustomisationSession"; legacy.Parent = uiRemotes\n', ''),
    (legacy_line, ''),
]))
ops.append(edit('ReplicatedStorage.Modules.Core.PathResolver', [
    ('function PathResolver.GarageRemotes()\n\treturn waitPath(root(), "Remotes", "Garage")\nend\n\n', ''),
]))
ops.append(edit('ServerStorage.Modules.Game.Garage.GarageRequestGuard', [
    ('"EnsureCustomisationAccess GetInitial SelectVehicleInstance BuyCockpitInstance BuyModuleInstance EquipModuleInstance BuyGarageProperty UpgradeGarageCapacity BuyCockpit BuyVehicleCosmetic SetVehicleCosmeticColor SetAllNeonColor SetCockpitColor BuyModule SetModuleColor UpgradeModule Upgrade BuyNeon SetThrustColor DespawnVehicle ExitVehicle ReEnterVehicle SpawnOwnedVehicleFromFreeRoam SpawnVehicle"',
     '"EnsureCustomisationAccess GetInitial SelectVehicleInstance BuyCockpitInstance BuyModuleInstance EquipModuleInstance BuyGarageProperty BuyVehicleCosmetic SetVehicleCosmeticColor SetAllNeonColor SetCockpitColor SetModuleColor UpgradeModule Upgrade BuyNeon DespawnVehicle ExitVehicle SpawnOwnedVehicleFromFreeRoam SpawnVehicle"'),
    ('local colours = {SetVehicleCosmeticColor=true,SetAllNeonColor=true,SetCockpitColor=true,SetModuleColor=true,SetThrustColor=true}',
     '-- Retired (architecture P9, no client caller): BuyCockpit, BuyModule, SetThrustColor, ReEnterVehicle, UpgradeGarageCapacity.\n'
     'local colours = {SetVehicleCosmeticColor=true,SetAllNeonColor=true,SetCockpitColor=true,SetModuleColor=true}'),
]))
spec = {
    "task": "Architecture P9: retire dead remotes, legacy session event, unused helper and client-unused legacy garage actions",
    "lane": "High-Risk",
    "contract": "Goal: remove verified-dead surface. Evidence: static reference scan of all 184 inventoried sources (no InvokeServer/FireServer/handler for GaragePush, GarageInteriorTransition, GarageInteriorCustomizationInvoke; GarageInteriorInvoke only looked up with FindFirstChild into an unused HUD local, nil-safe); P2 Net counters recorded no client use of DriveInCustomisationSession or the retired actions in any test session; no client source sends BuyCockpit, BuyModule, SetThrustColor, ReEnterVehicle or UpgradeGarageCapacity. Changes: 4 authored remotes deleted (no children/attributes/tags; installer recreates them exactly on rollback); GarageSessionServer no longer creates or listens to DriveInCustomisationSession; PathResolver.GarageRemotes removed; GarageRequestGuard allowlist drops the 5 legacy actions (requests now get the standard 'Unknown garage action.'; server branches become unreachable and are left for a later cleanup). Not retired: ThrustPreviewClient (found live: garage thrust preview and touch-control owner), unused bindables (used by tooling/installers; separate decision), duplicate Ok/Success reply fields. Rollback: installer ROLLBACK.",
    "verification": "installation (AUDIT/APPLY/ROLLBACK/APPLY), startup (all features ready), api (live actions unchanged via P5 golden; retired action rejected), errors",
    "operations": ops,
}
(ROOT / 'scripts/architecture/p9/spec.json').write_text(json.dumps(spec, indent=1), encoding='utf8')
print(len(ops), 'operations')
