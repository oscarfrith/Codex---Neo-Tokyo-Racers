-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageService_Active")
-- NTR_OWNED_GARAGE_SERVICE_ACTIVE_V1
local runtime=require(script.Parent:WaitForChild("OwnedGarageManagementRuntime"))
local ok,message=runtime.Start()
assert(ok,"Owned garage management failed to start: "..tostring(message))
script:SetAttribute("OwnedGarageRuntimeStarted",true)
print("[NTR Owned Garage] Canonical server service active.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
