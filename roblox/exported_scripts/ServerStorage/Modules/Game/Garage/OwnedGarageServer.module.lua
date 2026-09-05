-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local runtime=require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageManagement"))
local ok,message=runtime.Start()
assert(ok,"Owned garage management failed to start: "..tostring(message))
script:SetAttribute("OwnedGarageRuntimeStarted",true)
print("[Owned Garage] Canonical server service active.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
