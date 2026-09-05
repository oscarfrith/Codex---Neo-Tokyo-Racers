-- Canonical feature implementation; startup is owned by the composition root.
-- NTR_OWNED_GARAGE_TRANSITION_CONTROLLER_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local player=Players.LocalPlayer; local ui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")
	local Browser=require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("OwnedGarageBrowserUI")); local Workspace=require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("OwnedGarageWorkspaceUI")); local presentation=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):WaitForChild("FreeRoamHudPresentationMode")
	local function closeOwned() Browser.Close("Transition"); Workspace.Close("Transition") end
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(function() if player:GetAttribute("NTR_OwnedGarageInside")~=true then closeOwned() end end)
	player.CharacterAdded:Connect(function() task.defer(function() if player:GetAttribute("NTR_OwnedGarageInside")~=true then closeOwned() end end) end)
	presentation.Event:Connect(function(message) if typeof(message)~="table" or message.Active~=true then return end; local owner=tostring(message.Owner or ""); if owner~="OwnedGarageBrowser" and owner~="OwnedGarageWorkspace" then closeOwned() end end)
	started=true; print("[NTR Owned Garage] Transition cleanup active."); return true,"Started"
end
return Controller
