-- NTR_OWNED_GARAGE_CLIENT_ACTIVE_V1
-- NTR_OWNED_GARAGE_PHASE8_INTERIOR_HUD_START
-- NTR_OWNED_GARAGE_PHASE8_EXISTING_INTERIOR_MODE_OWNER_V1_4
local order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController"}
for _,name in ipairs(order) do local controller=require(script.Parent:WaitForChild(name)); local ok,message=controller.Start(); assert(ok,"Owned garage client failed: "..name.." / "..tostring(message)) end
script:SetAttribute("OwnedGarageClientStarted",true)
print("[NTR Owned Garage] Canonical client active.")
