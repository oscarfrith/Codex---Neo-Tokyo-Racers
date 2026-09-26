"""Build P3 after-sources (exact single-occurrence edits) and the installer spec."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/architecture'))
from blob import find  # noqa: E402

CAP = 'roblox/captures/arch-p2-after/capture.json'
OUT = ROOT / 'scripts/architecture/p3/after'
OUT.mkdir(exist_ok=True)
REQ = 'local RaceIntegrity = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceIntegrity"))\n'
REJECT_TT = '{ Granted = false, Amount = 0, Message = "Run not counted: checkpoint timing check failed." }'
REJECT_RACE = '{ Granted = false, Amount = 0, Message = "Race not counted: checkpoint timing check failed." }'


def edit(path, reps, name):
    s = find(CAP, path).read_bytes().decode('utf8')
    for a, b in reps:
        assert s.count(a) == 1, (path, a, s.count(a))
        s = s.replace(a, b)
    (OUT / f'{name}.lua').write_bytes(s.encode('utf8'))


edit('ServerStorage.Modules.Game.Racing.TimeTrialServer', [
    ('local function grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)\n',
     REQ + 'local function grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)\n'),
    ('\t\tlive.StartClock = os.clock()\n',
     '\t\tlive.StartClock = os.clock()\n\t\tRaceIntegrity.begin(live, live.Vehicle and live.Vehicle.PrimaryPart and live.Vehicle.PrimaryPart.Position, live.StartClock)\n'),
    ('\trun.LastTouchClock = now\n',
     '\trun.LastTouchClock = now\n\tRaceIntegrity.gate(run, gate.Part, now, player.Name .. " " .. tostring(run.EventId) .. " gate " .. tostring(gate.Index))\n'),
    ('\tlocal isPersonalBest = previousBest == nil or elapsed < previousBest\n',
     '\tlocal integrityAccepted = RaceIntegrity.accepted(run)\n\tlocal isPersonalBest = integrityAccepted and (previousBest == nil or elapsed < previousBest)\n'),
    ('\tlocal persistentBest = recordPersistentPersonalBest(player, run, elapsed, medal)\n',
     '\tlocal persistentBest = integrityAccepted and recordPersistentPersonalBest(player, run, elapsed, medal) or nil\n'),
    ('\tlocal reward = grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)\n',
     '\tlocal reward = integrityAccepted and grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest) or ' + REJECT_TT + '\n'),
    ('\t\tRewardMessage = reward.Message,\n',
     '\t\tRewardMessage = reward.Message,\n\t\tIntegrityRejected = not integrityAccepted,\n'),
], 'TimeTrialServer')

edit('ServerStorage.Modules.Game.Racing.MatchmakingServer', [
    ('local function finishEntry(race, entry)\n', REQ + 'local function finishEntry(race, entry)\n'),
    ('for _, entry in ipairs(participants) do entry.LapStartedClock = race.StartClock end',
     'for _, entry in ipairs(participants) do entry.LapStartedClock = race.StartClock RaceIntegrity.begin(entry, entry.Vehicle and entry.Vehicle.PrimaryPart and entry.Vehicle.PrimaryPart.Position, race.StartClock) end'),
    ('entry.LastTouchClock=clock entry.LastProgressElapsed=clock-race.StartClock\n',
     'entry.LastTouchClock=clock entry.LastProgressElapsed=clock-race.StartClock\n\tRaceIntegrity.gate(entry, gate.Part, clock, tostring(entry.Player and entry.Player.Name) .. " " .. tostring(race.EventId) .. " gate " .. tostring(gate.Index))\n'),
    ('local rewardResult = callRaceRewardService("GrantRaceReward",',
     'local rewardResult = not RaceIntegrity.accepted(entry) and ' + REJECT_RACE + ' or callRaceRewardService("GrantRaceReward",'),
], 'MatchmakingServer')

attr = lambda key, value: {"kind": "attribute", "path": ["ServerStorage", "Config", "Racing"], "class": "Folder", "key": key, "value": value, "before": None}
spec = {
    "task": "Architecture P3: RACE-01 server-side race integrity",
    "lane": "High-Risk",
    "contract": "Goal: detect implausible checkpoint segments (teleports/impossible speed) in time trials and matchmaking races and, in Enforce mode, withhold cash reward, personal best and global leaderboard submission for flagged runs while still letting the run finish. Owner: new ServerStorage.Modules.Game.Racing.RaceIntegrity (pure check + per-run state); TimeTrialServer and MatchmakingServer call it at run start, each accepted gate and finish. Server-only config attributes on ServerStorage.Config.Racing: RaceIntegrityMode Off|Log|Enforce (installed as Log), RaceIntegrityMaxSpeedMph 400 (> 320 mph absolute vehicle safety cap), RaceIntegrityToleranceStuds 24 (+ half of both gate sizes), RaceIntegrityJitterSeconds 0.35 (replication/hitch allowance); effective limit = max(RaceIntegrityMaxSpeedMph, 1.25 x highest Config.Vehicles.Dynamics AbsoluteTopSpeedSafetyMph/PhysicalTopSpeedMaxMph). Invariant: straight-line gate-to-gate distance <= limit*(elapsed+jitter) + tolerance for any legitimate run; resets return to the last gate (TimeTrial after a lap wrap: grid 1, ~14 studs from the finish on current routes) so stay plausible. One violation withholds the whole session result (accepted product rule). Preserved: gate order/debounce, splits, lap logic, results payload (adds IntegrityRejected), rewards for accepted runs. No client, remote, saved-data schema or UI change. Rollback: ROLLBACK, or set mode Off instantly.",
    "verification": "tooling (pure segment tests), installation, race (driven time trial with resets), api (simulated teleport between gates in sandbox), errors",
    "operations": [
        {"kind": "module", "path": ["ServerStorage", "Modules", "Game", "Racing", "RaceIntegrity"], "class": "ModuleScript", "file": "scripts/architecture/p3/RaceIntegrity.lua"},
        {"kind": "source", "path": ["ServerStorage", "Modules", "Game", "Racing", "TimeTrialServer"], "file": "scripts/architecture/p3/after/TimeTrialServer.lua"},
        {"kind": "source", "path": ["ServerStorage", "Modules", "Game", "Racing", "MatchmakingServer"], "file": "scripts/architecture/p3/after/MatchmakingServer.lua"},
        attr("RaceIntegrityMode", "Log"), attr("RaceIntegrityMaxSpeedMph", 400), attr("RaceIntegrityToleranceStuds", 24), attr("RaceIntegrityJitterSeconds", 0.35),
    ],
}
(ROOT / 'scripts/architecture/p3/spec.json').write_text(json.dumps(spec, indent=1), encoding='utf8')
print('ok')
