"""Build P2 after-sources: wrap each remote handler with Core.Net via one exact single-occurrence line edit."""
import json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'scripts/architecture'))
from blob import find
CAP = 'roblox/captures/arch-p1-after/capture.json'
OUT = ROOT/'scripts/architecture/p2/after'
OUT.mkdir(exist_ok=True)
NET = 'local Net=require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Net"));'

def acts(s): return '{' + ','.join(f'{a}=true' for a in s.split()) + '}'

def inv(target, handler, spec):
    # `target = function(args)` -> guarded forward to an unchanged local handler; closing `end` untouched.
    return lambda old: old.replace(f'{target}=function(', f'{NET} local {handler}; {target}=Net.invoke({spec},function(...) return {handler}(...) end); {handler}=function(', 1) if f'{target}=function(' in old else old.replace(f'{target} = function(', f'{NET} local {handler}; {target} = Net.invoke({spec}, function(...) return {handler}(...) end); {handler} = function(', 1)

def evt(target, handler, spec):
    # `target:Connect(function(args) ... end)` -> `...handler = (function(args) ... end)` closes with the original `end)`.
    return lambda old: old.replace(f'{target}:Connect(function(', f'{NET} local {handler}; {target}:Connect(Net.event({spec}, function(...) return {handler}(...) end)); {handler} = (function(', 1)

EDITS = {
 'ServerStorage.Modules.Game.Player.OnboardingServer': [('invoke.OnServerInvoke=function(player,action,data)', inv('invoke.OnServerInvoke','handleOnboardingInvoke', '{name="OnboardingInvoke",actions='+acts('GetState MarkSeen')+',capacity=30,refill=10,messages={unknown="Unsupported onboarding request."}}'))],
 'ServerStorage.Modules.Game.Garage.GarageSessionServer': [
   ('request.OnServerInvoke = function(player, action, payload)', inv('request.OnServerInvoke','handleGarageSessionRequest','{name="GarageSessionRequest",actions='+acts('Begin End State')+',capacity=20,refill=5,messages={unknown="Unknown garage session action."}}')),
   ('legacy.OnServerEvent:Connect(function(player, locked)', evt('legacy.OnServerEvent','handleLegacySession','{name="DriveInCustomisationSession",capacity=10,refill=2}'))],
 'ServerStorage.Modules.Game.World.FreeRoamTeleportServer': [('invoke.OnServerInvoke = function(player, action)', inv('invoke.OnServerInvoke','handleFreeRoamTeleport','{name="FreeRoamHudTeleportInvoke",actions='+acts('TeleportToDealership')+',capacity=10,refill=2,messages={unknown="Unknown teleport action."}}'))],
 'ServerStorage.Modules.Game.Racing.RaceTeleportServer': [('invoke.OnServerInvoke = function(player, action, payload)', inv('invoke.OnServerInvoke','handleRaceBrowserTeleport','{name="RaceBrowserTeleportInvoke",actions='+acts('TeleportToRaceStart')+',capacity=10,refill=2,messages={unknown="Unknown race browser teleport action."}}'))],
 'ServerStorage.Modules.Game.Dealership.IntroProgressServer': [
   ('getCompleteRemote.OnServerInvoke = function(player)', inv('getCompleteRemote.OnServerInvoke','handleIntroGetComplete','{name="GetDealershipIntroObjective",withAction=false,reply="boolean",capacity=20,refill=5}')),
   ('completeRemote.OnServerEvent:Connect(function(player)', evt('completeRemote.OnServerEvent','handleIntroComplete','{name="CompleteDealershipIntroObjective",capacity=10,refill=2}'))],
 'ServerStorage.Modules.Game.Development.StudioCashGrantServer': [('remote.OnServerEvent:Connect(function(player)', evt('remote.OnServerEvent','handleStudioCashGrant','{name="StudioCashGrantRequest",capacity=10,refill=2}'))],
 'ServerStorage.Modules.Game.Audio.VehicleAudioServer': [('remote.OnServerEvent:Connect(function(player, vehicle, payload)', evt('remote.OnServerEvent','handleVehicleAudioState','{name="VehicleAudioState",capacity=120,refill=60}'))],
 'ServerStorage.Modules.Game.Garage.OwnedGarageManagement': [
   ('push.OnServerEvent:Connect(function(player,message)', evt('push.OnServerEvent','handleOwnedGaragePush','{name="OwnedGarageEvent",capacity=30,refill=10}')),
   ('invoke.OnServerInvoke=function(player,action,args)', inv('invoke.OnServerInvoke','handleOwnedGarageInvoke','{name="OwnedGarageInvoke",actions='+acts('GetState GetManagementState SetManagementOpen PreviewDisplay CancelDisplayPreview PreviewStructure PreviewStructureFinish PreviewStructureFinishAll CancelStructurePreview PreviewDecoration PreviewDecorationFinish PreviewDecorationFinishAll CancelDecorationPreview PreviewLighting CancelLightingPreview CancelAllPreviews EnterSelectedGarage EnterOnFoot EnterWithVehicle ExitOnFoot DriveOut AssignDisplay ClearDisplay SetInteriorStyle ConfigureStructure ConfigureDecoration ConfigureLighting SetInvitation SetAccessMode')+',capacity=60,refill=30,messages={unknown="Unknown owned garage action."}}'))],
 'ServerStorage.Modules.Game.Racing.MatchmakingServer': [('queueRequest.OnServerInvoke = function(player, action, payload)', inv('queueRequest.OnServerInvoke','handleRaceQueueRequest','{name="RaceQueueRequest",actions='+acts('AcknowledgeStagingReady JoinQueue LeaveQueue GetQueueStatus ResetToLastCheckpoint ExitRaceToStart')+',capacity=60,refill=20,messages={unknown="Unknown queue action."}}'))],
 'ServerStorage.Modules.Game.Racing.TimeTrialServer': [('raceRequest.OnServerInvoke = function(player, action, payload)', inv('raceRequest.OnServerInvoke','handleRaceRequest','{name="RaceRequest",actions='+acts('AcknowledgeStagingReady GetEntryDetails GetTimeTrialPersonalBest GetTimeTrialLeaderboard StartStagedTimeTrial StartTimeTrial CancelTimeTrial ExitFinishedTimeTrial ResetActiveTimeTrial ExitActiveTimeTrial GetRouteSummary')+',capacity=60,refill=20,messages={unknown="Unknown racing action."}}'))],
}
ops=[{"kind":"module","path":["ServerStorage","Modules","Core","Net"],"class":"ModuleScript","file":"scripts/architecture/p2/Net.lua"},
     {"kind":"source","path":["ServerStorage","Modules","Game","Garage","GarageRequestGuard"],"file":"scripts/architecture/p2/GarageRequestGuard.lua"}]
for path, edits in EDITS.items():
    src = find(CAP, path).read_bytes().decode('utf8')
    for anchor, fn in edits:
        n = src.count(anchor)
        assert n == 1, f'{path}: anchor count {n}: {anchor}'
        new = fn(src)
        assert new != src and new.count('Net.') >= 1, f'{path}: edit failed'
        src = new
    name = path.split('.')[-1]
    (OUT/f'{name}.lua').write_bytes(src.encode('utf8'))
    ops.append({"kind":"source","path":path.split('.'),"file":f"scripts/architecture/p2/after/{name}.lua"})
spec=json.loads((ROOT/'scripts/architecture/p2/spec.base.json').read_text())
spec['operations']=ops
(ROOT/'scripts/architecture/p2/spec.json').write_text(json.dumps(spec,indent=1))
print(len(ops),'operations')
