-- One Phase 4 migration/recovery entry point. Edit mode only; never publish here.
local MODE="INSTALL" -- INSTALL | AUDIT | ROLLBACK
assert(game.PlaceId==121304917315753,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Unknown mode")
local records={{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AcousticsController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
AcousticsController]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.AcousticsClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("AcousticsClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("AcousticsController")
]====],suffix=[====[
]====],before=826893167,beforeBytes=10217,after=1671687872,afterBytes=10496},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AudioBusController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
AudioBusController]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.AudioBusClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("AudioBusClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("AudioBusController")
]====],suffix=[====[
]====],before=3189954660,beforeBytes=2262,after=2402226249,afterBytes=2540},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AudioMixController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
AudioMixController]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.AudioMixClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("AudioMixClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("AudioMixController")
]====],suffix=[====[
]====],before=1296208406,beforeBytes=3589,after=1623511149,afterBytes=3867},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.ContextAudioCatalog]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
ContextAudioCatalog]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.ContextAudioCatalog]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("ContextAudioCatalog"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("ContextAudioCatalog")
]====],suffix=[====[
]====],before=327501999,beforeBytes=3223,after=1050074534,afterBytes=3502},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.ContextAudioController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
ContextAudioController]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.ContextAudioClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("ContextAudioClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("ContextAudioController")
]====],suffix=[====[
]====],before=3964329918,beforeBytes=11330,after=4290284006,afterBytes=11612},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.PresentationAudioBridge]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
PresentationAudioBridge]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.PresentationAudioBridge]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("PresentationAudioBridge"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("PresentationAudioBridge")
]====],suffix=[====[
]====],before=252710473,beforeBytes=1746,after=587686911,afterBytes=2029},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.PresentationAudioCatalog]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
PresentationAudioCatalog]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.PresentationAudioCatalog]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("PresentationAudioCatalog"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("PresentationAudioCatalog")
]====],suffix=[====[
]====],before=3194260676,beforeBytes=2790,after=2482431218,afterBytes=3074},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.PresentationAudioController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
PresentationAudioController]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.PresentationAudioClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("PresentationAudioClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("PresentationAudioController")
]====],suffix=[====[
]====],before=3207508786,beforeBytes=16105,after=838202959,afterBytes=16392},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.VehicleAudioCatalog]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
VehicleAudioCatalog]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.VehicleAudioCatalog]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("VehicleAudioCatalog"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("VehicleAudioCatalog")
]====],suffix=[====[
]====],before=2139210854,beforeBytes=3532,after=674542642,afterBytes=3811},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.VehicleAudioController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Audio]====],[====[
VehicleAudioController]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.VehicleAudioClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("VehicleAudioClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio"):WaitForChild("VehicleAudioController")
]====],suffix=[====[
]====],before=2114030125,beforeBytes=40359,after=491837992,afterBytes=40641},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingCameraController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Controllers]====],[====[
DrivingCameraController]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.DrivingCameraClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DrivingCameraClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("DrivingCameraController")
]====],suffix=[====[
]====],before=823940869,beforeBytes=12611,after=1281792595,afterBytes=12900},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingControllerV47]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Controllers]====],[====[
DrivingControllerV47]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.DrivingClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DrivingClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("DrivingControllerV47")
]====],suffix=[====[
]====],before=2122672619,beforeBytes=54973,after=2439729013,afterBytes=55259},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingFallbackController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Controllers]====],[====[
DrivingFallbackController]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.DrivingFallbackClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DrivingFallbackClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("DrivingFallbackController")
]====],suffix=[====[
]====],before=1194630429,beforeBytes=16664,after=3675283698,afterBytes=16955},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.MobileDriveInputState]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Controllers]====],[====[
MobileDriveInputState]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.MobileDriveInputState]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("MobileDriveInputState"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("MobileDriveInputState")
]====],suffix=[====[
]====],before=3753693513,beforeBytes=1845,after=304767710,afterBytes=2132},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.ReentryThrottle]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Controllers]====],[====[
ReentryThrottle]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.ReentryThrottle]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("ReentryThrottle"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("ReentryThrottle")
]====],suffix=[====[
]====],before=2916923244,beforeBytes=484,after=3478647261,afterBytes=765},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.VehicleDynamicsModel]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Controllers]====],[====[
VehicleDynamicsModel]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleDynamics"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("VehicleDynamicsModel")
]====],suffix=[====[
]====],before=1531370105,beforeBytes=18786,after=1849978652,afterBytes=19072},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Input.GameplayInputGate]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Input]====],[====[
GameplayInputGate]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.GameplayInputGate]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("GameplayInputGate"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Input"):WaitForChild("GameplayInputGate")
]====],suffix=[====[
]====],before=3227798206,beforeBytes=4097,after=1750423782,afterBytes=4374},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.UI.UIFactory]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
UI]====],[====[
UIFactory]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.UIFactory]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("UIFactory"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("UIFactory")
]====],suffix=[====[
]====],before=3066647218,beforeBytes=2156,after=1193268711,afterBytes=2422},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.UI.UIPool]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
UI]====],[====[
UIPool]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.UIPool]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("UIPool"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UI"):WaitForChild("UIPool")
]====],suffix=[====[
]====],before=217656668,beforeBytes=1848,after=3836964231,afterBytes=2111},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.VFX.VehicleVFXController]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
VFX]====],[====[
VehicleVFXController]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.LegacyVehicleVFXClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("LegacyVehicleVFXClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("VFX"):WaitForChild("VehicleVFXController")
]====],suffix=[====[
]====],before=1620890836,beforeBytes=18491,after=1414795087,afterBytes=18769},{old=[====[
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime]====],parts={[====[
ReplicatedStorage]====],[====[
NeoTokyoRacers]====],[====[
Shared]====],[====[
Modules]====],[====[
Client]====],[====[
Visuals]====],[====[
CachedThrustVisualRuntime]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.VehicleVFXClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleVFXClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Visuals"):WaitForChild("CachedThrustVisualRuntime")
]====],suffix=[====[
]====],before=670736100,beforeBytes=24083,after=2583820228,afterBytes=24370},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.AcousticsRuntimeController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Audio]====],[====[
AcousticsRuntimeController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.AcousticsRuntimeClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("AcousticsRuntimeClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Audio"):WaitForChild("AcousticsRuntimeController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3390322960,beforeBytes=453,after=603065653,afterBytes=1076},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.AudioRuntimeController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Audio]====],[====[
AudioRuntimeController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.AudioRuntimeClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("AudioRuntimeClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Audio"):WaitForChild("AudioRuntimeController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2789827296,beforeBytes=444,after=3388256831,afterBytes=1063},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.ContextAudioRuntimeController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Audio]====],[====[
ContextAudioRuntimeController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.ContextAudioRuntimeClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("ContextAudioRuntimeClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Audio"):WaitForChild("ContextAudioRuntimeController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1295106184,beforeBytes=453,after=1750521152,afterBytes=1079},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.PresentationAudioRuntimeController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Audio]====],[====[
PresentationAudioRuntimeController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Audio.PresentationAudioRuntimeClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("PresentationAudioRuntimeClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Audio"):WaitForChild("PresentationAudioRuntimeController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=109450410,beforeBytes=453,after=3779224219,afterBytes=1084},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.CatalogClient]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Core]====],[====[
CatalogClient]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.CatalogClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("CatalogClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Core"):WaitForChild("CatalogClient")
]====],suffix=[====[
]====],before=1748390724,beforeBytes=2824,after=3564735895,afterBytes=3092},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientState]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Core]====],[====[
ClientState]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.GarageState]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageState"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Core"):WaitForChild("ClientState")
]====],suffix=[====[
]====],before=1204665088,beforeBytes=1604,after=3407925073,afterBytes=1870},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientThemeAdapter]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Core]====],[====[
ClientThemeAdapter]====]},new=[====[
ReplicatedStorage.Modules.Core.ClientThemeAdapter]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("ClientThemeAdapter"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Core"):WaitForChild("ClientThemeAdapter")
]====],suffix=[====[
]====],before=1671276301,beforeBytes=3525,after=3754084207,afterBytes=3798},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.GarageApiClient]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Core]====],[====[
GarageApiClient]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.GarageApiClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageApiClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Core"):WaitForChild("GarageApiClient")
]====],suffix=[====[
]====],before=2451472837,beforeBytes=1007,after=1072853100,afterBytes=1277},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.PaintClient]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Core]====],[====[
PaintClient]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.PaintClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("PaintClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Core"):WaitForChild("PaintClient")
]====],suffix=[====[
]====],before=3337919348,beforeBytes=4589,after=3485892230,afterBytes=4855},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Debug.DriveToEarnCashTelemetry_StudioOnly]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Debug]====],[====[
DriveToEarnCashTelemetry_StudioOnly]====]},new=[====[
ReplicatedStorage.Modules.Game.Development.DriveToEarnCashTelemetryClient]====],class=[====[
LocalScript]====],edits={{[====[

while gui.Parent do
	update()
	task.wait(0.25)
end
]====],[====[

task.spawn(function()
while gui.Parent do
	update()
	task.wait(0.25)
end

end)
]====]}},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("DriveToEarnCashTelemetryClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Debug"):WaitForChild("DriveToEarnCashTelemetry_StudioOnly")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3969338710,beforeBytes=3424,after=1925990718,afterBytes=4077},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Debug.StudioCashGrantClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Debug]====],[====[
StudioCashGrantClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Development.StudioCashGrantClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("StudioCashGrantClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Debug"):WaitForChild("StudioCashGrantClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1859792780,beforeBytes=1981,after=1350212246,afterBytes=2599},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Intro]====],[====[
DealershipIntroClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Dealership.DealershipIntroClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Dealership"):WaitForChild("DealershipIntroClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Intro"):WaitForChild("DealershipIntroClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2244635907,beforeBytes=25363,after=2076748528,afterBytes=25981},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.GarageEntranceController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Intro]====],[====[
GarageEntranceController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Dealership.GarageEntranceClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Dealership"):WaitForChild("GarageEntranceClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Intro"):WaitForChild("GarageEntranceController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3144854469,beforeBytes=8021,after=4235850315,afterBytes=8642},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.GaragePreviewPresentationController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Preview]====],[====[
GaragePreviewPresentationController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.GaragePreviewPresentationClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GaragePreviewPresentationClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Preview"):WaitForChild("GaragePreviewPresentationController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2412241168,beforeBytes=10615,after=3240183276,afterBytes=11249},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Preview]====],[====[
ThrustPreviewController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.ThrustPreviewClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("ThrustPreviewClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Preview"):WaitForChild("ThrustPreviewController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=4072146084,beforeBytes=7920,after=3829937575,afterBytes=8542},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.GarageModuleInstancePreviewAdapter]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Preview]====],[====[
GarageModuleInstancePreviewAdapter]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.GarageModuleInstancePreviewAdapter]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageModuleInstancePreviewAdapter"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Preview"):WaitForChild("GarageModuleInstancePreviewAdapter")
]====],suffix=[====[
]====],before=3030095531,beforeBytes=5627,after=1953575750,afterBytes=5919},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.GarageVehiclePreviewProfile]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Preview]====],[====[
GarageVehiclePreviewProfile]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.GarageVehiclePreviewProfile]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageVehiclePreviewProfile"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Preview"):WaitForChild("GarageVehiclePreviewProfile")
]====],suffix=[====[
]====],before=2067329466,beforeBytes=4222,after=650186214,afterBytes=4507},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewCameraController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Preview]====],[====[
PreviewCameraController]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.PreviewCameraClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("PreviewCameraClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Preview"):WaitForChild("PreviewCameraController")
]====],suffix=[====[
]====],before=3021712445,beforeBytes=8486,after=280519910,afterBytes=8767},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewVehicleController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Preview]====],[====[
PreviewVehicleController]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.PreviewVehicleClient]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("PreviewVehicleClient"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Preview"):WaitForChild("PreviewVehicleController")
]====],suffix=[====[
]====],before=3800802622,beforeBytes=10252,after=788138194,afterBytes=10534},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceBrowserClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceBrowserClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceBrowserClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceBrowserClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceBrowserClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2666393547,beforeBytes=22127,after=1290447672,afterBytes=22742},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceCountdownPresentationController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceCountdownPresentationController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceCountdownPresentationClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceCountdownPresentationClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceCountdownPresentationController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3219406517,beforeBytes=5051,after=987943054,afterBytes=5684},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceEntryMenuClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceEntryMenuClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceEntryMenuClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceEntryMenuClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=4095163398,beforeBytes=5443,after=3738013130,afterBytes=6060},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryPresentationController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceEntryPresentationController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceEntryPresentationClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceEntryPresentationClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceEntryPresentationController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1982788500,beforeBytes=57403,after=3588986380,afterBytes=58032},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceLifecyclePresentationController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceLifecyclePresentationController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceLifecyclePresentationClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceLifecyclePresentationClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceLifecyclePresentationController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2902077123,beforeBytes=10244,after=3640373933,afterBytes=10877},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceParticipantVisibilityClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceParticipantVisibilityClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceParticipantVisibilityClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceParticipantVisibilityClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3058672279,beforeBytes=5853,after=3660297063,afterBytes=6482},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceQueueClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceQueueClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceQueueClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceQueueClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceQueueClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=223217882,beforeBytes=6273,after=2023889086,afterBytes=6886},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceRouteGuideClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceRouteGuideClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceRouteGuideClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceRouteGuideClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceRouteGuideClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1911618788,beforeBytes=17028,after=1637590686,afterBytes=17646},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionAssetsClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceSessionAssetsClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceSessionAssetsClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceSessionAssetsClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceSessionAssetsClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=623837168,beforeBytes=11885,after=847334316,afterBytes=12506},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceSessionPresentationController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceSessionPresentationController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceSessionPresentationClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceSessionPresentationClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceSessionPresentationController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2466921246,beforeBytes=32279,after=2091004210,afterBytes=32910},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTimeTrialResultCoachClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceTimeTrialResultCoachClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceTimeTrialResultCoachClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceTimeTrialResultCoachClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceTimeTrialResultCoachClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=730066260,beforeBytes=22335,after=2077480163,afterBytes=22963},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceTransitionClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Racing]====],[====[
RaceTransitionClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Racing.RaceTransitionClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceTransitionClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):WaitForChild("RaceTransitionClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1209733472,beforeBytes=15020,after=1046362428,afterBytes=15638},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.CharacterSprintController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Runtime]====],[====[
CharacterSprintController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.CharacterSprintClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("CharacterSprintClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Runtime"):WaitForChild("CharacterSprintController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1737750443,beforeBytes=8703,after=285755567,afterBytes=9327},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Runtime]====],[====[
DriveHudController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.DriveHudClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DriveHudClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Runtime"):WaitForChild("DriveHudController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3547144714,beforeBytes=134,after=4270475922,afterBytes=751},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.FreeRoamParkedHoverController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Runtime]====],[====[
FreeRoamParkedHoverController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.FreeRoamParkedHoverClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("FreeRoamParkedHoverClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Runtime"):WaitForChild("FreeRoamParkedHoverController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1806802201,beforeBytes=8723,after=2144214178,afterBytes=9351},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Runtime]====],[====[
MobileDriveControlsController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.MobileDriveControlsClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("MobileDriveControlsClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Runtime"):WaitForChild("MobileDriveControlsController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3805433178,beforeBytes=17332,after=982093051,afterBytes=17960},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
Runtime]====],[====[
RuntimeVFXController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.Vehicles.RuntimeVFXClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("RuntimeVFXClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Runtime"):WaitForChild("RuntimeVFXController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2241854362,beforeBytes=521,after=2735977177,afterBytes=1140},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
DesktopFreeRoamHudController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.DesktopFreeRoamHudUI]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHudUI"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHudController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=315127831,beforeBytes=63330,after=1555148126,afterBytes=63952},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamNavController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
FreeRoamNavController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.FreeRoamNavUI]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("FreeRoamNavUI"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("FreeRoamNavController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3547144714,beforeBytes=134,after=1146650869,afterBytes=749},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamVehicleExitButton_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
FreeRoamVehicleExitButton_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.FreeRoamVehicleExitButtonClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("FreeRoamVehicleExitButtonClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("FreeRoamVehicleExitButton_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3547144714,beforeBytes=134,after=1372139026,afterBytes=753},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.LoadingTransitionController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
LoadingTransitionController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.LoadingTransitionUI]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("LoadingTransitionUI"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("LoadingTransitionController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2016326021,beforeBytes=746,after=2542490931,afterBytes=1367},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
MobileFreeRoamHudController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.MobileFreeRoamHudUI]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("MobileFreeRoamHudUI"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("MobileFreeRoamHudController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=10033756,beforeBytes=46687,after=1340845481,afterBytes=47308},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OnboardingClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
OnboardingClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.OnboardingClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("OnboardingClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("OnboardingClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1969523698,beforeBytes=53755,after=4133150385,afterBytes=54365},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
OwnedGarageClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.OwnedGarageClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("OwnedGarageClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("OwnedGarageClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1896514486,beforeBytes=602,after=2168886862,afterBytes=1213},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.SharedTopNotificationController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
SharedTopNotificationController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.SharedTopNotificationUI]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("SharedTopNotificationUI"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("SharedTopNotificationController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3581610090,beforeBytes=689,after=2536369756,afterBytes=1314},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CockpitPaintUIController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
CockpitPaintUIController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.CockpitPaintUIUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("CockpitPaintUIUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("CockpitPaintUIController")
]====],suffix=[====[
]====],before=1737635505,beforeBytes=1659,after=2458409620,afterBytes=1936},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ColourPickerController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
ColourPickerController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.ColourPickerUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("ColourPickerUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("ColourPickerController")
]====],suffix=[====[
]====],before=2111930614,beforeBytes=8825,after=1073446248,afterBytes=9100},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CustomisationUIController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
CustomisationUIController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.CustomisationUIUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("CustomisationUIUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("CustomisationUIController")
]====],suffix=[====[
]====],before=813474687,beforeBytes=4599,after=131400871,afterBytes=4877},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DealershipUIController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
DealershipUIController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.DealershipUIUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("DealershipUIUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("DealershipUIController")
]====],suffix=[====[
]====],before=3407796949,beforeBytes=2931,after=503040118,afterBytes=3206},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamMapPlayerMarkers]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
FreeRoamMapPlayerMarkers]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.FreeRoamMapPlayerMarkers]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("FreeRoamMapPlayerMarkers"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("FreeRoamMapPlayerMarkers")
]====],suffix=[====[
]====],before=3154619915,beforeBytes=13941,after=2815926584,afterBytes=14218},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageBrowserController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
GarageBrowserController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.GarageBrowserUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("GarageBrowserUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GarageBrowserController")
]====],suffix=[====[
]====],before=2257806553,beforeBytes=22244,after=1623245406,afterBytes=22520},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageInteriorModeController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
GarageInteriorModeController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.GarageInteriorModeUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("GarageInteriorModeUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GarageInteriorModeController")
]====],suffix=[====[
]====],before=214653148,beforeBytes=24112,after=3153588394,afterBytes=24393},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageInteriorTransitionController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
GarageInteriorTransitionController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.GarageInteriorTransitionUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("GarageInteriorTransitionUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GarageInteriorTransitionController")
]====],suffix=[====[
]====],before=222217892,beforeBytes=1245,after=4276716104,afterBytes=1532},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageModuleCardViewModel]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
GarageModuleCardViewModel]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("GarageModuleCardViewModel"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GarageModuleCardViewModel")
]====],suffix=[====[
]====],before=3895104185,beforeBytes=3515,after=1010303096,afterBytes=3793},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GaragePropertyMenuController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
GaragePropertyMenuController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.GaragePropertyMenuUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("GaragePropertyMenuUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GaragePropertyMenuController")
]====],suffix=[====[
]====],before=1628462890,beforeBytes=6596,after=1555169463,afterBytes=6877},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageReplacementComponents]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
GarageReplacementComponents]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.GarageComponents]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("GarageComponents"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GarageReplacementComponents")
]====],suffix=[====[
]====],before=2974082212,beforeBytes=50496,after=1051082053,afterBytes=50776},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageWorkspaceController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
GarageWorkspaceController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.GarageWorkspaceUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("GarageWorkspaceUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GarageWorkspaceController")
]====],suffix=[====[
]====],before=3278640377,beforeBytes=50147,after=1177900993,afterBytes=50425},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ModuleShopUIController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
ModuleShopUIController]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.GarageUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("ModuleShopUIController")
]====],suffix=[====[
]====],before=2351493361,beforeBytes=58077,after=2122379647,afterBytes=58352},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.NavigationController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
NavigationController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.NavigationUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("NavigationUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("NavigationController")
]====],suffix=[====[
]====],before=882642138,beforeBytes=1270,after=2997639950,afterBytes=1543},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OnboardingGuideTrailRenderer]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
OnboardingGuideTrailRenderer]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.OnboardingGuideTrailRenderer]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("OnboardingGuideTrailRenderer"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("OnboardingGuideTrailRenderer")
]====],suffix=[====[
]====],before=326219947,beforeBytes=10513,after=697642735,afterBytes=10794},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageBrowserController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
OwnedGarageBrowserController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.OwnedGarageBrowserUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("OwnedGarageBrowserUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("OwnedGarageBrowserController")
]====],suffix=[====[
]====],before=1255853111,beforeBytes=19489,after=3735338443,afterBytes=19770},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageWorkspaceController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
OwnedGarageWorkspaceController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.OwnedGarageWorkspaceUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("OwnedGarageWorkspaceUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("OwnedGarageWorkspaceController")
]====],suffix=[====[
]====],before=3677139426,beforeBytes=45769,after=2890225763,afterBytes=46052},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.StatsPanelController]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
UI]====],[====[
StatsPanelController]====]},new=[====[
ReplicatedStorage.Modules.Game.UI.StatsPanelUI]====],class=[====[
ModuleScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("StatsPanelUI"))
]====],prefix=[====[
-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("StatsPanelController")
]====],suffix=[====[
]====],before=2645758247,beforeBytes=1315,after=1487616004,afterBytes=1588},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
World]====],[====[
LODClient_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.World.LODClient]====],class=[====[
LocalScript]====],edits={{[====[

while true do
	task.wait(UPDATE_RATE)

	local character = player.Character
	if not character then continue end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then continue end

	local playerPos = rootPart.Position

	for _, blockData in ipairs(Blocks) do
		local centerPos = getBlockCenterPosition(blockData)

		local dx = playerPos.X - centerPos.X
		local dz = playerPos.Z - centerPos.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		local nearState = getNearLODState(dist)

		if DEBUG_PRINTS then
			print(
				blockData.Model.Name,
				"Distance:", math.floor(dist),
				"NearState:", nearState,
				"LOD4_Foliage:", shouldShowLOD4Foliage(dist)
			)
		end

		applyNearLOD(blockData, nearState)

		local foliageVisible = shouldShowLOD4Foliage(dist)
		applyLOD4Foliage(blockData, foliageVisible)

		local farVisible = shouldShowFarLOD5(dist, blockData.LastFarVisible)
		applyFarLOD5(blockData, farVisible)
	end
end]====],[====[

task.spawn(function()
while true do
	task.wait(UPDATE_RATE)

	local character = player.Character
	if not character then continue end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then continue end

	local playerPos = rootPart.Position

	for _, blockData in ipairs(Blocks) do
		local centerPos = getBlockCenterPosition(blockData)

		local dx = playerPos.X - centerPos.X
		local dz = playerPos.Z - centerPos.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		local nearState = getNearLODState(dist)

		if DEBUG_PRINTS then
			print(
				blockData.Model.Name,
				"Distance:", math.floor(dist),
				"NearState:", nearState,
				"LOD4_Foliage:", shouldShowLOD4Foliage(dist)
			)
		end

		applyNearLOD(blockData, nearState)

		local foliageVisible = shouldShowLOD4Foliage(dist)
		applyLOD4Foliage(blockData, foliageVisible)

		local farVisible = shouldShowFarLOD5(dist, blockData.LastFarVisible)
		applyFarLOD5(blockData, farVisible)
	end
end
end)
]====]}},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("LODClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World"):WaitForChild("LODClient_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=2923948190,beforeBytes=8871,after=2228165896,afterBytes=9505},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.NightLamppostLightController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
World]====],[====[
NightLamppostLightController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.World.NightLamppostLightClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("NightLamppostLightClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World"):WaitForChild("NightLamppostLightController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1034785722,beforeBytes=1549,after=4196873789,afterBytes=2174},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.OwnedGarageEnvironmentLightingController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
World]====],[====[
OwnedGarageEnvironmentLightingController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.World.OwnedGarageEnvironmentLightingClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("OwnedGarageEnvironmentLightingClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World"):WaitForChild("OwnedGarageEnvironmentLightingController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3605152358,beforeBytes=5634,after=2549429402,afterBytes=6271},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.WindowMaterialController_Active]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
Controllers]====],[====[
World]====],[====[
WindowMaterialController_Active]====]},new=[====[
ReplicatedStorage.Modules.Game.World.WindowMaterialClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("WindowMaterialClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World"):WaitForChild("WindowMaterialController_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3644459034,beforeBytes=1860,after=2668261202,afterBytes=2481},{old=[====[
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
NeoTokyoRacersClient]====],[====[
NeoTokyoRacersClient_Bootstrap_Shadow_Disabled]====]},new=[====[
ReplicatedStorage.Modules.Game.Garage.GarageClient]====],class=[====[
LocalScript]====],edits={{[====[
local DefaultTheme = {
	Panel = Color3.fromRGB(5, 9, 7),
	PanelSoft = Color3.fromRGB(12, 20, 17),
	Card = Color3.fromRGB(24, 35, 42),
	CardHot = Color3.fromRGB(36, 118, 82),
	Text = Color3.fromRGB(218, 255, 231),
	Muted = Color3.fromRGB(145, 178, 160),
	Accent = Color3.fromRGB(172, 255, 197),
	Cash = Color3.fromRGB(255, 193, 50),
	Danger = Color3.fromRGB(175, 70, 68),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),
	Disabled = Color3.fromRGB(62, 72, 73),
	PanelTransparency = 0.12,
	ButtonTransparency = 0.08,
	PanelStrokeTransparency = 0.2,
	ButtonStrokeTransparency = 0.62,
	StrokeWidth = 1,
	PanelCornerRadius = 5,
	ButtonCornerRadius = 4,
	FontFamily = "rbxasset://fonts/families/Michroma.json",
}

local Theme = {}

local function readThemeColor(name, fallback, alternateName)
	local item = themeFolder and (themeFolder:FindFirstChild(name) or (alternateName and themeFolder:FindFirstChild(alternateName)))
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local function readThemeNumber(name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function readThemeString(name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

local function refreshThemeFromValues()
	Theme.Panel = readThemeColor("Panel", DefaultTheme.Panel)
	Theme.PanelSoft = readThemeColor("PanelSoft", DefaultTheme.PanelSoft)
	Theme.Card = readThemeColor("Card", DefaultTheme.Card)
	Theme.CardHot = readThemeColor("Selected", DefaultTheme.CardHot, "CardHot")
	Theme.Text = readThemeColor("Text", DefaultTheme.Text)
	Theme.Muted = readThemeColor("Muted", DefaultTheme.Muted)
	Theme.Accent = readThemeColor("Accent", DefaultTheme.Accent)
	Theme.Cash = readThemeColor("Cash", DefaultTheme.Cash)
	Theme.Danger = readThemeColor("Danger", DefaultTheme.Danger)
	Theme.Back = readThemeColor("Back", DefaultTheme.Back, "BackButton")
	Theme.Exit = readThemeColor("Exit", DefaultTheme.Exit, "ExitButton")
	Theme.Buy = readThemeColor("Buy", DefaultTheme.Buy)
	Theme.Disabled = readThemeColor("Disabled", DefaultTheme.Disabled)
	Theme.PanelTransparency = math.clamp(readThemeNumber("PanelTransparency", DefaultTheme.PanelTransparency), 0, 1)
	Theme.ButtonTransparency = math.clamp(readThemeNumber("ButtonTransparency", DefaultTheme.ButtonTransparency), 0, 1)
	Theme.PanelStrokeTransparency = math.clamp(readThemeNumber("PanelStrokeTransparency", DefaultTheme.PanelStrokeTransparency), 0, 1)
	Theme.ButtonStrokeTransparency = math.clamp(readThemeNumber("ButtonStrokeTransparency", DefaultTheme.ButtonStrokeTransparency), 0, 1)
	Theme.StrokeWidth = math.max(0, readThemeNumber("StrokeWidth", DefaultTheme.StrokeWidth))
	Theme.PanelCornerRadius = math.max(0, readThemeNumber("PanelCornerRadius", DefaultTheme.PanelCornerRadius))
	Theme.ButtonCornerRadius = math.max(0, readThemeNumber("ButtonCornerRadius", DefaultTheme.ButtonCornerRadius))
	Theme.FontFamily = readThemeString("FontFamily", DefaultTheme.FontFamily)
end
]====],[====[
local Theme = {}
local function refreshThemeFromValues()
	for key,value in pairs(require(game:GetService("ReplicatedStorage").Modules.Core.ClientThemeAdapter).Read(themeFolder)) do Theme[key]=value end
end
]====]},{[====[
Theme.FontFamily or DefaultTheme.FontFamily]====],[====[
Theme.FontFamily or require(game:GetService("ReplicatedStorage").Modules.Core.ClientThemeAdapter).DefaultTheme.FontFamily]====]},{[====[
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if not reentryProbe:ShouldRun(now) then return end
	if isDriving or now < reentryCooldown then return end
	if UI.Gui and UI.Gui.Enabled then return end
	local character = player.Character
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoidRoot or not humanoid or humanoid.Sit then return end
	local vehicle = getPlayerVehicle()
	local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	local targetPart = (seat and seat:IsA("BasePart")) and seat or root
	if not targetPart then return end
	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_PROMPT_ONLY_REENTRY
	if false and (humanoidRoot.Position - targetPart.Position).Magnitude <= 6.5 then
		reentryCooldown = now + 1.25
		reentryProbe:Cooldown(1.25)
		local result = callServer("ReEnterVehicle", {})
		if result.Success then
			task.defer(startDriving)
		end
	end
end)

]====],[====[
-- Prompt-only re-entry: retired disabled proximity polling.

]====]},{[====[
local function setupCameraInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or isDriving then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
			State.Dragging = true
			State.LastPointer = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
			State.Dragging = false
			State.LastPointer = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if isDriving then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			return
		elseif State.Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if State.LastPointer then
				local delta = input.Position - State.LastPointer
				State.TargetYaw -= delta.X * 0.006
				State.TargetPitch = math.clamp(State.TargetPitch - delta.Y * 0.004, math.rad(-45), math.rad(10))
			end
			State.LastPointer = input.Position
		end
	end)
	RunService.RenderStepped:Connect(updateCamera)
end

]====],[====[
local function setupCameraInput()
	require(game:GetService("ReplicatedStorage").Modules.Game.Garage.PreviewInputClient).bind(State,function() return isDriving end,updateCamera,script)
end

]====]}},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageClient"))
]====],prefix=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=450704684,beforeBytes=187523,after=3157260481,afterBytes=183152},{old=[====[
StarterPlayer.StarterPlayerScripts.LocalScript]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
LocalScript]====]},new=[====[
ReplicatedStorage.Modules.Game.Development.TrailerVehicleCameraClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("TrailerVehicleCameraClient"))
]====],prefix=[=====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
local config=game:GetService("ReplicatedStorage").NeoTokyoRacers.Config.Development.ClientTools
if not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,[====[
TrailerVehicleCameraEnabled]====]) then return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("LocalScript")
]=====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1930213474,beforeBytes=4758,after=754418388,afterBytes=5569},{old=[====[
StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
TEMP_LightingPreview]====]},new=[====[
ReplicatedStorage.Modules.Game.Development.LightingPreviewClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("LightingPreviewClient"))
]====],prefix=[=====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
local config=game:GetService("ReplicatedStorage").NeoTokyoRacers.Config.Development.ClientTools
if not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,[====[
LightingPreviewEnabled]====]) then return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("TEMP_LightingPreview")
]=====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=3593240143,beforeBytes=2707,after=2561747798,afterBytes=3522},{old=[====[
StarterPlayer.StarterPlayerScripts.TrailerMode.client.lua]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
TrailerMode.client.lua]====]},new=[====[
ReplicatedStorage.Modules.Game.Development.TrailerModeClient]====],class=[====[
LocalScript]====],edits={},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("TrailerModeClient"))
]====],prefix=[=====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
local config=game:GetService("ReplicatedStorage").NeoTokyoRacers.Config.Development.ClientTools
if not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,[====[
TrailerModeEnabled]====]) then return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("TrailerMode.client.lua")
]=====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=1417940066,beforeBytes=1678,after=1740609699,afterBytes=2491},{old=[====[
StarterPlayer.StarterPlayerScripts.TrailerShot01Camera]====],parts={[====[
StarterPlayer]====],[====[
StarterPlayerScripts]====],[====[
TrailerShot01Camera]====]},new=[====[
ReplicatedStorage.Modules.Game.Development.TrailerShotClient]====],class=[====[
LocalScript]====],edits={{[====[
local shotFolder = workspace:WaitForChild("TrailerShots"):WaitForChild("Shot01_StraightRoadPan")]====],[====[
local shots=workspace:FindFirstChild("TrailerShots")
local shotFolder=shots and shots:FindFirstChild("Shot01_StraightRoadPan")
assert(shotFolder,"TrailerShotEnabled requires Workspace.TrailerShots.Shot01_StraightRoadPan")]====]},{[====[
local cameraA = shotFolder:WaitForChild("Camera_A")]====],[====[
local cameraA = assert(shotFolder:FindFirstChild("Camera_A"),"Missing trailer marker Camera_A")
assert(cameraA:IsA("BasePart"),"Trailer marker must be a BasePart")]====]},{[====[
local cameraB = shotFolder:WaitForChild("Camera_B")]====],[====[
local cameraB = assert(shotFolder:FindFirstChild("Camera_B"),"Missing trailer marker Camera_B")
assert(cameraB:IsA("BasePart"),"Trailer marker must be a BasePart")]====]},{[====[
local lookAtTarget = shotFolder:WaitForChild("LookAt_Target")]====],[====[
local lookAtTarget = assert(shotFolder:FindFirstChild("LookAt_Target"),"Missing trailer marker LookAt_Target")
assert(lookAtTarget:IsA("BasePart"),"Trailer marker must be a BasePart")]====]}},adapter=[====[
-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.
return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("TrailerShotClient"))
]====],prefix=[=====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
local config=game:GetService("ReplicatedStorage").NeoTokyoRacers.Config.Development.ClientTools
if not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,[====[
TrailerShotEnabled]====]) then return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("TrailerShot01Camera")
]=====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====],before=868677116,beforeBytes=2225,after=3471830572,afterBytes=3506}}
local extras={{path=[====[
StarterPlayer.StarterPlayerScripts.ClientBase]====],class=[====[
LocalScript]====],source=[=====[
-- Explicit client composition root. No descendant auto-discovery or gameplay state.
local RS=game:GetService("ReplicatedStorage")
local lifecycle=require(RS:WaitForChild("Modules").Core.ClientLifecycle)
local config=RS.NeoTokyoRacers.Config.Development.ClientTools
local entries={{name=[====[
AcousticsRuntimeClient]====],path=[====[
ReplicatedStorage.Modules.Game.Audio.AcousticsRuntimeClient]====],dependencies={}},{name=[====[
AudioRuntimeClient]====],path=[====[
ReplicatedStorage.Modules.Game.Audio.AudioRuntimeClient]====],dependencies={}},{name=[====[
ContextAudioRuntimeClient]====],path=[====[
ReplicatedStorage.Modules.Game.Audio.ContextAudioRuntimeClient]====],dependencies={}},{name=[====[
PresentationAudioRuntimeClient]====],path=[====[
ReplicatedStorage.Modules.Game.Audio.PresentationAudioRuntimeClient]====],dependencies={}},{name=[====[
DriveToEarnCashTelemetryClient]====],path=[====[
ReplicatedStorage.Modules.Game.Development.DriveToEarnCashTelemetryClient]====],dependencies={}},{name=[====[
StudioCashGrantClient]====],path=[====[
ReplicatedStorage.Modules.Game.Development.StudioCashGrantClient]====],dependencies={}},{name=[====[
DealershipIntroClient]====],path=[====[
ReplicatedStorage.Modules.Game.Dealership.DealershipIntroClient]====],dependencies={[====[
GarageClient]====]}},{name=[====[
GarageEntranceClient]====],path=[====[
ReplicatedStorage.Modules.Game.Dealership.GarageEntranceClient]====],dependencies={[====[
LoadingTransitionUI]====],[====[
GarageClient]====]}},{name=[====[
GaragePreviewPresentationClient]====],path=[====[
ReplicatedStorage.Modules.Game.Garage.GaragePreviewPresentationClient]====],dependencies={}},{name=[====[
ThrustPreviewClient]====],path=[====[
ReplicatedStorage.Modules.Game.Garage.ThrustPreviewClient]====],dependencies={}},{name=[====[
RaceBrowserClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceBrowserClient]====],dependencies={}},{name=[====[
RaceCountdownPresentationClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceCountdownPresentationClient]====],dependencies={}},{name=[====[
RaceEntryMenuClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceEntryMenuClient]====],dependencies={}},{name=[====[
RaceEntryPresentationClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceEntryPresentationClient]====],dependencies={[====[
LoadingTransitionUI]====]}},{name=[====[
RaceLifecyclePresentationClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceLifecyclePresentationClient]====],dependencies={}},{name=[====[
RaceParticipantVisibilityClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceParticipantVisibilityClient]====],dependencies={}},{name=[====[
RaceQueueClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceQueueClient]====],dependencies={}},{name=[====[
RaceRouteGuideClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceRouteGuideClient]====],dependencies={}},{name=[====[
RaceSessionAssetsClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceSessionAssetsClient]====],dependencies={}},{name=[====[
RaceSessionPresentationClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceSessionPresentationClient]====],dependencies={}},{name=[====[
RaceTimeTrialResultCoachClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceTimeTrialResultCoachClient]====],dependencies={}},{name=[====[
RaceTransitionClient]====],path=[====[
ReplicatedStorage.Modules.Game.Racing.RaceTransitionClient]====],dependencies={}},{name=[====[
CharacterSprintClient]====],path=[====[
ReplicatedStorage.Modules.Game.Vehicles.CharacterSprintClient]====],dependencies={}},{name=[====[
DriveHudClient]====],path=[====[
ReplicatedStorage.Modules.Game.Vehicles.DriveHudClient]====],dependencies={}},{name=[====[
FreeRoamParkedHoverClient]====],path=[====[
ReplicatedStorage.Modules.Game.Vehicles.FreeRoamParkedHoverClient]====],dependencies={}},{name=[====[
MobileDriveControlsClient]====],path=[====[
ReplicatedStorage.Modules.Game.Vehicles.MobileDriveControlsClient]====],dependencies={}},{name=[====[
RuntimeVFXClient]====],path=[====[
ReplicatedStorage.Modules.Game.Vehicles.RuntimeVFXClient]====],dependencies={}},{name=[====[
DesktopFreeRoamHudUI]====],path=[====[
ReplicatedStorage.Modules.Game.UI.DesktopFreeRoamHudUI]====],dependencies={}},{name=[====[
FreeRoamNavUI]====],path=[====[
ReplicatedStorage.Modules.Game.UI.FreeRoamNavUI]====],dependencies={}},{name=[====[
FreeRoamVehicleExitButtonClient]====],path=[====[
ReplicatedStorage.Modules.Game.UI.FreeRoamVehicleExitButtonClient]====],dependencies={}},{name=[====[
LoadingTransitionUI]====],path=[====[
ReplicatedStorage.Modules.Game.UI.LoadingTransitionUI]====],dependencies={}},{name=[====[
MobileFreeRoamHudUI]====],path=[====[
ReplicatedStorage.Modules.Game.UI.MobileFreeRoamHudUI]====],dependencies={}},{name=[====[
OnboardingClient]====],path=[====[
ReplicatedStorage.Modules.Game.UI.OnboardingClient]====],dependencies={}},{name=[====[
OwnedGarageClient]====],path=[====[
ReplicatedStorage.Modules.Game.UI.OwnedGarageClient]====],dependencies={[====[
LoadingTransitionUI]====]}},{name=[====[
SharedTopNotificationUI]====],path=[====[
ReplicatedStorage.Modules.Game.UI.SharedTopNotificationUI]====],dependencies={}},{name=[====[
LODClient]====],path=[====[
ReplicatedStorage.Modules.Game.World.LODClient]====],dependencies={}},{name=[====[
NightLamppostLightClient]====],path=[====[
ReplicatedStorage.Modules.Game.World.NightLamppostLightClient]====],dependencies={}},{name=[====[
OwnedGarageEnvironmentLightingClient]====],path=[====[
ReplicatedStorage.Modules.Game.World.OwnedGarageEnvironmentLightingClient]====],dependencies={}},{name=[====[
WindowMaterialClient]====],path=[====[
ReplicatedStorage.Modules.Game.World.WindowMaterialClient]====],dependencies={}},{name=[====[
GarageClient]====],path=[====[
ReplicatedStorage.Modules.Game.Garage.GarageClient]====],dependencies={[====[
LoadingTransitionUI]====],[====[
SharedTopNotificationUI]====]}},{name=[====[
TrailerVehicleCameraClient]====],path=[====[
ReplicatedStorage.Modules.Game.Development.TrailerVehicleCameraClient]====],dependencies={},tool=[====[
TrailerVehicleCameraEnabled]====]},{name=[====[
LightingPreviewClient]====],path=[====[
ReplicatedStorage.Modules.Game.Development.LightingPreviewClient]====],dependencies={},tool=[====[
LightingPreviewEnabled]====]},{name=[====[
TrailerModeClient]====],path=[====[
ReplicatedStorage.Modules.Game.Development.TrailerModeClient]====],dependencies={},tool=[====[
TrailerModeEnabled]====]},{name=[====[
TrailerShotClient]====],path=[====[
ReplicatedStorage.Modules.Game.Development.TrailerShotClient]====],dependencies={},tool=[====[
TrailerShotEnabled]====]}}
local state=Instance.new("Folder"); state.Name="StartupState"; state.Parent=script
lifecycle.start(entries,function(entry)
	local item=game
	for part in entry.path:gmatch("[^%.]+") do item=item:WaitForChild(part) end
	return require(item)
end,function(name,status,message)
	state:SetAttribute(name,status)
	if message then warn("[ClientBase] "..name.." "..status..": "..message) end
end,function(flag) return lifecycle.tool_enabled(game:GetService("RunService"):IsStudio(),config,flag) end)
]=====]},{path=[====[
ReplicatedStorage.Modules.Core.ClientLifecycle]====],class=[====[
ModuleScript]====],source=[====[
-- Owns explicit client-session startup, not gameplay state. No individual feature hot reload.
local Lifecycle = {}
function Lifecycle.validate(entries)
	local index, visiting, visited = {}, {}, {}
	for _,entry in ipairs(entries) do assert(not index[entry.name],"Duplicate client "..entry.name); index[entry.name]=entry end
	local function visit(name)
		assert(index[name],"Missing dependency "..name)
		assert(not visiting[name],"Dependency cycle at "..name)
		if visited[name] then return end
		visiting[name]=true
		for _,dependency in ipairs(index[name].dependencies or {}) do visit(dependency) end
		visiting[name]=nil; visited[name]=true
	end
	for name in pairs(index) do visit(name) end
	return index
end
function Lifecycle.tool_enabled(is_studio, config, flag)
	return is_studio == true and config ~= nil and config:GetAttribute(flag) == true
end
function Lifecycle.start(entries, resolve, emit, enabled)
	Lifecycle.validate(entries)
	local states={}
	local function set(name,status,message)
		states[name]={status=status,message=message}
		if emit then emit(name,status,message) end
	end
	for _,entry in ipairs(entries) do set(entry.name,"pending") end
	for _,entry in ipairs(entries) do task.spawn(function()
		if entry.tool and not (enabled and enabled(entry.tool)) then set(entry.name,"skipped"); return end
		local deadline=os.clock()+30
		for _,dependency in ipairs(entry.dependencies or {}) do
			while states[dependency].status=="pending" or states[dependency].status=="starting" do
				if os.clock()>=deadline then set(entry.name,"blocked","Dependency timeout: "..dependency); return end
				task.wait(0.05)
			end
			if states[dependency].status~="ready" then set(entry.name,"blocked","Dependency failed: "..dependency); return end
		end
		set(entry.name,"starting")
		local ok,message=xpcall(function()
			local feature=resolve(entry)
			assert(type(feature)=="table" and type(feature.start)=="function","Client start missing")
			feature.start()
		end,debug.traceback)
		set(entry.name,ok and "ready" or "failed",not ok and tostring(message) or nil)
	end) end
	return states
end
return Lifecycle
]====]},{path=[====[
ReplicatedStorage.Modules.Core.ConnectionScope]====],class=[====[
ModuleScript]====],source=[====[
-- Owns subscriptions for one explicit binding. destroy is repeat-safe.
local Scope={}
Scope.__index=Scope
function Scope.new() return setmetatable({connections={},destroyed=false},Scope) end
function Scope:connect(signal,callback)
	assert(not self.destroyed,"Cannot bind a destroyed scope")
	local connection=signal:Connect(callback)
	table.insert(self.connections,connection)
	return connection
end
function Scope:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
end
return Scope
]====]},{path=[====[
ReplicatedStorage.Modules.Game.Garage.PreviewInputClient]====],class=[====[
ModuleScript]====],source=[====[
-- Owns preview input subscriptions only; host owns preview state and camera rendering.
local Scope=require(game:GetService("ReplicatedStorage").Modules.Core.ConnectionScope)
local Client={}
local active
function Client.destroy()
	if active then active:destroy(); active=nil end
end
function Client.bind(state,is_driving,update_camera,owner)
	Client.destroy()
	local scope=Scope.new(); active=scope
	local inputService=game:GetService("UserInputService")
	scope:connect(inputService.InputBegan,function(input,processed)
		if processed or is_driving() then return end
		if input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.Touch then
			state.Dragging=true; state.LastPointer=input.Position
		end
	end)
	scope:connect(inputService.InputEnded,function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.Touch then
			state.Dragging=false; state.LastPointer=nil
		end
	end)
	scope:connect(inputService.InputChanged,function(input)
		if is_driving() then return end
		if input.UserInputType==Enum.UserInputType.MouseWheel then return
		elseif state.Dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
			if state.LastPointer then
				local delta=input.Position-state.LastPointer
				state.TargetYaw-=delta.X*0.006
				state.TargetPitch=math.clamp(state.TargetPitch-delta.Y*0.004,math.rad(-45),math.rad(10))
			end
			state.LastPointer=input.Position
		end
	end)
	scope:connect(game:GetService("RunService").RenderStepped,update_camera)
	if owner then scope:connect(owner.Destroying,function() Client.destroy() end) end
	return scope
end
return Client
]====]},{path=[====[
ReplicatedStorage.NeoTokyoRacers.Config.Development.ClientTools]====],class=[====[
Configuration]====],attributes={TrailerVehicleCameraEnabled=false,LightingPreviewEnabled=false,TrailerModeEnabled=false,TrailerShotEnabled=false}}}
local pathParts={}
for _,r in ipairs(records) do pathParts[r.old]=r.parts end
local function split(path) return pathParts[path] or string.split(path,".") end
local function find(path)
	local item=game
	for _,part in ipairs(split(path)) do
		local found
		for _,child in ipairs(item:GetChildren()) do if child.Name==part then assert(not found,"Ambiguous path "..path); found=child end end
		if not found then return nil end
		item=found
	end
	return item
end
local function hash(source) local n=0 for i=1,#source do n=(n*31+source:byte(i))%4294967296 end return n end
local function replace(source,a,b)
	local i,j=source:find(a,1,true)
	assert(i and not source:find(a,j+1,true),"Source anchor mismatch")
	return source:sub(1,i-1)..b..source:sub(j+1)
end
local function compile(source,path) local f,e=loadstring(source,"="..path); assert(f,e) end
local installed=find("StarterPlayer.StarterPlayerScripts.ClientBase")~=nil
-- Stage and compile every projected source before changing any instance.
for _,r in ipairs(records) do
	r.item=assert(find(r.old),"Missing "..r.old)
	assert(#r.item:GetChildren()==0,"Unexpected children; inspect "..r.old)
	if installed then
		assert(r.item:IsA("ModuleScript") and r.item.Source==r.adapter,"Adapter changed "..r.old)
		r.canonical=assert(find(r.new),"Missing "..r.new)
		assert(r.canonical:IsA("ModuleScript") and #r.canonical:GetChildren()==0,"Unexpected canonical shape")
		r.target=r.canonical.Source
		assert(#r.target==r.afterBytes and hash(r.target)==r.after,"Canonical source changed "..r.new)
		assert(r.target:sub(1,#r.prefix)==r.prefix,"Prefix changed")
		r.original=r.target:sub(#r.prefix+1,#r.target-#r.suffix)
		for i=#r.edits,1,-1 do local pair=r.edits[i]; r.original=replace(r.original,pair[2],pair[1]) end
	else
		assert(r.item.ClassName==r.class,"Class mismatch "..r.old)
		if r.item:IsA("BaseScript") then assert(not r.item.Disabled,"Disabled baseline "..r.old) end
		assert(not find(r.new),"Destination occupied "..r.new)
		r.original=r.item.Source
		r.target=r.original
		for _,pair in ipairs(r.edits) do r.target=replace(r.target,pair[1],pair[2]) end
		r.target=r.prefix..r.target..r.suffix
	end
	assert(hash(r.original)==r.before and #r.original==r.beforeBytes,"Baseline changed "..r.old)
	assert(hash(r.target)==r.after and #r.target==r.afterBytes,"Projected source mismatch "..r.new)
	compile(r.original,r.old); compile(r.target,r.new); compile(r.adapter,r.old)
end
for _,e in ipairs(extras) do
	e.item=find(e.path)
	assert((e.item~=nil)==installed,"Mixed extra installation "..e.path)
	if installed then assert(e.item.ClassName==e.class and (not e.source or e.item.Source==e.source) and #e.item:GetChildren()==0,"Extra changed "..e.path) end
	if e.source then compile(e.source,e.path) end
	if installed and e.attributes then for k,v in pairs(e.attributes) do assert(e.item:GetAttribute(k)==v,"Tool config changed; restore defaults before migration "..k) end end
end
if MODE=="AUDIT" then return "PASS Phase 4 "..(installed and "installed" or "baseline") end
if MODE=="INSTALL" and installed or MODE=="ROLLBACK" and not installed then return "PASS Phase 4 already in requested state" end
local created,changed,detached={}, {}, {}
local function parentFor(path)
	local parts=table.clone(split(path)); local name=table.remove(parts)
	local parent=game
	for _,part in ipairs(parts) do
		local nextItem=parent:FindFirstChild(part)
		if not nextItem then
			nextItem=Instance.new("Folder"); nextItem.Name=part
			nextItem:SetAttribute("NTRArchitecturePhase4Folder",true)
			table.insert(created,nextItem); nextItem.Parent=parent
		end
		parent=nextItem
	end
	return parent,name
end
local function make(path,class,source,attrs)
	local parent,name=parentFor(path)
	assert(not parent:FindFirstChild(name),"Occupied "..path)
	local item=Instance.new(class); table.insert(created,item)
	item.Name=name; if source then item.Source=source end
	for k,v in pairs(attrs or {}) do item:SetAttribute(k,v) end
	item.Parent=parent
	return item
end
local function detach(item)
	table.insert(detached,{item=item,parent=item.Parent})
	item.Parent=nil
end
local function assign(item,source)
	table.insert(changed,{item=item,source=item.Source}); item.Source=source
end
local ok,message=xpcall(function()
	if MODE=="INSTALL" then
		for _,r in ipairs(records) do make(r.new,"ModuleScript",r.target) end
		for _,e in ipairs(extras) do make(e.path,e.class,e.source,e.attributes) end
		for _,r in ipairs(records) do
			if r.class=="LocalScript" then
				local attrs=r.item:GetAttributes(); detach(r.item); make(r.old,"ModuleScript",r.adapter,attrs)
			else assign(r.item,r.adapter) end
		end
		for _,r in ipairs(records) do assert(find(r.old).Source==r.adapter and find(r.new).Source==r.target,"Post-install mismatch") end
	else
		for _,r in ipairs(records) do
			if r.class=="LocalScript" then
				local attrs=r.item:GetAttributes(); detach(r.item); make(r.old,"LocalScript",r.original,attrs)
			else assign(r.item,r.original) end
			detach(r.canonical)
		end
		for _,e in ipairs(extras) do detach(e.item) end
		for _,r in ipairs(records) do assert(find(r.old).Source==r.original,"Post-rollback mismatch") end
	end
end,debug.traceback)
if not ok then
	for _,c in ipairs(changed) do c.item.Source=c.source end
	for i=#created,1,-1 do created[i]:Destroy() end
	for _,d in ipairs(detached) do d.item.Parent=d.parent end
	error("Phase 4 restored previous state: "..tostring(message))
end
for _,d in ipairs(detached) do d.item:Destroy() end
if MODE=="ROLLBACK" then
	local folders={}
	for _,item in ipairs(game:GetDescendants()) do if item:IsA("Folder") and item:GetAttribute("NTRArchitecturePhase4Folder")==true then table.insert(folders,item) end end
	for i=#folders,1,-1 do if #folders[i]:GetChildren()==0 then folders[i]:Destroy() end end
end
return "PASS Phase 4 "..MODE.."; verify a fresh Play session"
