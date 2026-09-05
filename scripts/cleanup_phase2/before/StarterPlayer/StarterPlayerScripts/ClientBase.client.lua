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
