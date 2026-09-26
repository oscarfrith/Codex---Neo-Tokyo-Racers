"""Build P8 after-sources and installer spec (exact single-occurrence edits)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/architecture'))
from blob import find  # noqa: E402

CAP = 'roblox/captures/arch-p6-after/capture.json'
OUT = ROOT / 'scripts/architecture/p8/after'
OUT.mkdir(exist_ok=True)


def edit(path, reps):
    s = find(CAP, path).read_bytes().decode('utf8')
    for a, b in reps:
        assert s.count(a) == 1, (path, a)
        s = s.replace(a, b)
    name = path.split('.')[-1]
    (OUT / f'{name}.lua').write_text(s, encoding='utf8', newline='\n')
    return {"kind": "source", "path": path.split('.'), "file": f"scripts/architecture/p8/after/{name}.lua"}


ops = [
    {"kind": "module", "path": ["ServerStorage", "Modules", "Core", "FeatureFlags"], "class": "ModuleScript", "file": "scripts/architecture/p8/FeatureFlags.lua"},
    {"kind": "module", "path": ["ServerStorage", "Modules", "Game", "Player", "AnalyticsServer"], "class": "ModuleScript", "file": "scripts/architecture/p8/AnalyticsServer.lua"},
    {"kind": "module", "path": ["ServerStorage", "Modules", "Game", "Player", "ReceiptProcessor"], "class": "ModuleScript", "file": "scripts/architecture/p8/ReceiptProcessor.lua"},
]
ops.append(edit('ServerStorage.Modules.Game.Player.MoneyService', [
    ('local MoneyService = {}\n',
     'local MoneyService = {}\n'
     'local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Signal"))\n'
     '-- Fired after every successful debit: (profile, amount, reason, newBalance). Used by analytics.\n'
     'MoneyService.Debited = Signal.new()\n'),
    ('\tif #ledger > LEDGER_LIMIT then table.remove(ledger, 1) end\n',
     '\tif #ledger > LEDGER_LIMIT then table.remove(ledger, 1) end\n\tMoneyService.Debited:Fire(profile, amount, reason, profile.Cash)\n'),
]))
ops.append(edit('ServerStorage.Modules.Game.Racing.RaceIntegrity', [
    ('function RaceIntegrity.mode(): string\n\tlocal folder = settings()\n\tlocal value = folder and folder:GetAttribute("RaceIntegrityMode")\n',
     'local FeatureFlags = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("FeatureFlags"))\n\n'
     '-- A valid Creator Dashboard config "RaceIntegrityMode" (Off/Log/Enforce) overrides the attribute, so Enforce\n'
     '-- can be switched live; any other dashboard value is ignored and the attribute applies.\n'
     'function RaceIntegrity.mode(): string\n\tlocal folder = settings()\n'
     '\tlocal flag = FeatureFlags.Get("RaceIntegrityMode", nil)\n'
     '\tif flag == "Off" or flag == "Log" or flag == "Enforce" then return flag end\n'
     '\tlocal value = folder and folder:GetAttribute("RaceIntegrityMode")\n'),
]))
ops.append(edit('ServerStorage.Modules.Game.Player.OnboardingServer', [
    ('progress.Event:Connect(function(player,progressId)\n\tif player and player.Parent==Players then run(player,"RecordProgress",{ProgressId=progressId}) end\nend)',
     'local analytics=require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("AnalyticsServer"))\n'
     'progress.Event:Connect(function(player,progressId)\n\tif player and player.Parent==Players then\n'
     '\t\tlocal recorded=run(player,"RecordProgress",{ProgressId=progressId})\n'
     '\t\tif type(recorded)=="table" and recorded.Changed then analytics.OnboardingStep(player,progressId) end\n'
     '\tend\nend)'),
]))
ops.append(edit('ServerScriptService.ServerBase', [
    ('TrafficLightServer]====],path=[====[\nServerStorage.Modules.Game.World.TrafficLightServer]====],dependencies={}},\n}',
     'TrafficLightServer]====],path=[====[\nServerStorage.Modules.Game.World.TrafficLightServer]====],dependencies={}},\n'
     '{name=[====[\nAnalyticsServer]====],path=[====[\nServerStorage.Modules.Game.Player.AnalyticsServer]====],dependencies={[====[\nProfileServer]====]}},\n}'),
]))
spec = {
    "task": "Architecture P8: live-ops (FeatureFlags, AnalyticsServer registry, ReceiptProcessor template)",
    "lane": "High-Risk",
    "contract": "Goal: live-tunable flags, analytics and a safe receipt template without new remotes or saved-data changes. FeatureFlags (ServerStorage.Modules.Core): non-yielding Get/IsEnabled resolving Studio Flag_<key> attribute override, then Creator Dashboard ConfigService snapshot (background refresh, failures keep defaults), then default. First consumer: RaceIntegrity mode (dashboard RaceIntegrityMode overrides the attribute). AnalyticsServer (new ServerBase entry, depends on ProfileServer): registry of reported events; economy sinks via new MoneyService.Debited signal (only when profile._Player is a live player), sources via existing EconomyCashCommitted, onboarding funnel only when OnboardingServer newly records a milestone (Changed=true); all pcall-guarded and gated by AnalyticsEnabled (default on). ReceiptProcessor: inert, idempotent save-first template (per-PurchaseId in-flight lock; grant and record applied together; failed save keeps the single in-memory grant and retries only the save; never grants twice or claws back) for future developer products; prerequisite before binding: persist and bound PurchaseHistory. Deferred: server restart countdown (needs a client UI and a new remote). Preserved: all balances, replies, persistence. Rollback: installer ROLLBACK.",
    "verification": "tooling (ReceiptProcessor + FeatureFlags tests), installation, startup (AnalyticsServer ready), api (purchase emits sink without errors; race mode unchanged), errors",
    "operations": ops,
}
(ROOT / 'scripts/architecture/p8/spec.json').write_text(json.dumps(spec, indent=1), encoding='utf8')
print(len(ops), 'operations')
