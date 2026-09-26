"""Build P7: Core.CameraService plus DrivingCameraClient and CharacterSprintClient migrated to it (exact edits)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/architecture'))
from blob import find  # noqa: E402

CAP = 'roblox/captures/arch-p9-after/capture.json'
OUT = ROOT / 'scripts/architecture/p7/after'
OUT.mkdir(exist_ok=True)
REQ = 'local CameraService = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("CameraService"))\n'


def edit(path, reps):
    s = find(CAP, path).read_bytes().decode('utf8')
    for a, b in reps:
        assert s.count(a) == 1, (path, a[:80], s.count(a))
        s = s.replace(a, b)
    name = path.split('.')[-1]
    (OUT / f'{name}.lua').write_text(s, encoding='utf8', newline='\n')
    return {"kind": "source", "path": path.split('.'), "file": f"scripts/architecture/p7/after/{name}.lua"}


ops = [{"kind": "module", "path": ["ReplicatedStorage", "Modules", "Core", "CameraService"], "class": "ModuleScript", "file": "scripts/architecture/p7/CameraService.lua"}]
ops.append(edit('ReplicatedStorage.Modules.Game.Vehicles.DrivingCameraClient', [
    ('local Workspace = game:GetService("Workspace")\n', 'local Workspace = game:GetService("Workspace")\n' + REQ, ),
    ('\tdistance = math.clamp(distance, 0.5, 400)\n\tif distance >= player.CameraMaxZoomDistance then\n\t\tplayer.CameraMaxZoomDistance = distance\n\t\tplayer.CameraMinZoomDistance = distance\n\telse\n\t\tplayer.CameraMinZoomDistance = distance\n\t\tplayer.CameraMaxZoomDistance = distance\n\tend\nend',
     '\t-- CameraService owns the player zoom limits (priority 100 while driving).\n\tCameraService.SetZoomLimits("DrivingCamera", distance, distance, 100)\nend'),
    ('\tlocal player = Players.LocalPlayer\n\tif not player or previousMinZoom == nil or previousMaxZoom == nil then return end\n\tif previousMinZoom <= player.CameraMaxZoomDistance then\n\t\tplayer.CameraMinZoomDistance = previousMinZoom\n\t\tplayer.CameraMaxZoomDistance = previousMaxZoom\n\telse\n\t\tplayer.CameraMaxZoomDistance = previousMaxZoom\n\t\tplayer.CameraMinZoomDistance = previousMinZoom\n\tend\n\tzoomIsLocked = false',
     '\tCameraService.ClearZoomLimits("DrivingCamera")\n\tzoomIsLocked = false'),
    ('\tcam.FieldOfView = currentFov\n', '\tCameraService.SetFieldOfView("DrivingCamera", currentFov, 100)\n'),
    ('\t\t\tif previousFov then ownedCamera.FieldOfView = previousFov end\n', ''),
    ('\tsuspended = true\n\trestoreZoom()\n',
     '\tsuspended = true\n\trestoreZoom()\n\tCameraService.ClearFieldOfView("DrivingCamera") -- trailer tools own FOV while suspended\n'),
    ('\tfor _, connection in ipairs(connections) do connection:Disconnect() end\n\ttable.clear(connections)\n\trestoreZoom()\n',
     '\tfor _, connection in ipairs(connections) do connection:Disconnect() end\n\ttable.clear(connections)\n\trestoreZoom()\n\tCameraService.ClearFieldOfView("DrivingCamera")\n'),
]))
ops.append(edit('ReplicatedStorage.Modules.Game.Vehicles.CharacterSprintClient', [
    ('local Workspace = game:GetService("Workspace")\n', 'local Workspace = game:GetService("Workspace")\n' + REQ),
    ('local function tweenFov(targetFov)\n',
     '-- Sprint FOV is a CameraService request (priority 10) animated through a proxy value, so it can never\n'
     '-- capture or overwrite the driving camera FOV (priority 100).\n'
     'local fovProxy = Instance.new("NumberValue")\n'
     'fovProxy.Changed:Connect(function(value) CameraService.SetFieldOfView("Sprint", value, 10) end)\n'
     'local function tweenFov(targetFov, clearWhenDone)\n'
     '\tif clearWhenDone and (configValue("SprintFovEnabled", true) ~= true or not Workspace.CurrentCamera) then\n'
     '\t\tif activeTween then activeTween:Cancel(); activeTween = nil end\n'
     '\t\tCameraService.ClearFieldOfView("Sprint")\n'
     '\t\treturn\n'
     '\tend\n'),
    ('\tactiveTween = TweenService:Create(\n\t\tcamera,\n\t\tTweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),\n\t\t{ FieldOfView = targetFov }\n\t)\n\tactiveTween:Play()\n',
     '\tfovProxy.Value = camera.FieldOfView\n\tlocal tween = TweenService:Create(\n\t\tfovProxy,\n\t\tTweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),\n\t\t{ Value = targetFov }\n\t)\n'
     '\tactiveTween = tween\n\tif clearWhenDone then\n\t\ttween.Completed:Connect(function(playbackState)\n\t\t\tif playbackState == Enum.PlaybackState.Completed and activeTween == tween then CameraService.ClearFieldOfView("Sprint") end\n\t\tend)\n\tend\n\ttween:Play()\n'),
    ('\tif options.restoreFov ~= false and savedCameraFov then\n\t\ttweenFov(savedCameraFov)\n\tend\n',
     '\tif options.restoreFov ~= false and savedCameraFov then\n\t\ttweenFov(savedCameraFov, true)\n'
     '\telseif options.restoreFov == false then\n'
     '\t\tif activeTween then activeTween:Cancel(); activeTween = nil end\n'
     '\t\tCameraService.ClearFieldOfView("Sprint")\n\tend\n'),
]))
spec = {
    "task": "Architecture P7: CameraService FOV/zoom arbitration; driving camera and sprint migrated",
    "lane": "High-Risk",
    "contract": "Goal: one owner for camera field of view and player zoom limits. New ReplicatedStorage.Modules.Core.CameraService: keyed priority requests (highest wins, latest on ties), values validated (finite, FOV 1-120, zoom 0.5-400, min<=max, write order safe), values captured before the first request restored when all requests clear. DrivingCameraClient requests zoom lock and FOV at priority 100 and clears zoom and FOV on stop and suspend (trailer tools own FOV while suspended) instead of writing Player/Camera properties and restoring saved values; CharacterSprintClient animates a proxy NumberValue into a priority-10 FOV request and clears after its restore tween, on character reset (no restore) and when sprint FOV is disabled. Fixes the sprint/driving FOV capture conflict found in the audit and keeps CAM-02 finite guards centralised. Not changed (deferred, need rendered UI verification): CameraType/Subject claims (garage preview, dealership intro, race transition, owned garage touch guard, trailer tools), UI visibility arbiter, input action registry and single controls writer. Rollback: installer ROLLBACK.",
    "verification": "tooling (CameraService pure tests), installation, runtime (rendered Play): drive -> zoom 22/22 locked and FOV follows speed; exit -> zoom and FOV restored; sprint -> FOV 80 then back; sprint then sit -> driving FOV wins, restore correct; console clean",
    "operations": ops,
}
(ROOT / 'scripts/architecture/p7/spec.json').write_text(json.dumps(spec, indent=1), encoding='utf8')
print(len(ops), 'operations')
