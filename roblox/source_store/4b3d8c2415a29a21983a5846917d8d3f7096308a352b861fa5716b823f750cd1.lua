-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local order={"OwnedGarageBrowserUI","OwnedGarageWorkspaceUI","GarageInteriorModeUI","GarageInteriorTransitionUI"}
for _,name in ipairs(order) do local controller=require(game:GetService("ReplicatedStorage").Modules.Game.UI:WaitForChild(name)); local ok,message=controller.Start(); assert(ok,"Owned garage client failed: "..name.." / "..tostring(message)) end
game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):SetAttribute("OwnedGarageClientStarted",true)
print("[Owned Garage] Canonical client active.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
