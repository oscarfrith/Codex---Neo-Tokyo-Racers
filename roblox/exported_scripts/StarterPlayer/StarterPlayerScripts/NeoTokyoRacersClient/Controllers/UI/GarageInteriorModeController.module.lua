-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui")
	local function publish() playerGui:SetAttribute("NTR_OwnedGarageInteriorMode",player:GetAttribute("NTR_OwnedGarageInside")==true) end
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(publish); publish(); started=true
	print("[NTR Owned Garage] Interior HUD policy active."); return true,"Started"
end
return Controller
