-- NTR_OWNED_GARAGE_CLIENT_ACTIVE_V1
local order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController"}
for _,name in ipairs(order) do local controller=require(script.Parent:WaitForChild(name)); local ok,message=controller.Start(); assert(ok,"Owned garage client failed: "..name.." / "..tostring(message)) end
script:SetAttribute("OwnedGarageClientStarted",true)
print("[NTR Owned Garage] Canonical client active.")
