-- Owns the owned-garage touch camera guard (which touches hold the walking camera inside an owned garage); not the interior HUD, the desk or any ScreenGui.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.TouchCameraGuard. Requires: Garage.OwnedGarageWorkspaceUI. Logic-identical fork of UI.GarageInteriorModeUI 48-270 (API2 5.7); started by Garage.GarageInteriorHud.
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local UserInputService=game:GetService("UserInputService"); local RunService=game:GetService("RunService"); local Workspace=game:GetService("Workspace"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local settings=game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Garage"):WaitForChild("Interior")
	local function number(name,fallback) local value=settings:GetAttribute(name); return typeof(value)=="number" and value or fallback end
