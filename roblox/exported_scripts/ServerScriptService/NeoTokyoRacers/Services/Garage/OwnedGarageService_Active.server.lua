-- NTR_OWNED_GARAGE_SERVICE_ACTIVE_V1
local runtime=require(script.Parent:WaitForChild("OwnedGarageManagementRuntime"))
local ok,message=runtime.Start()
assert(ok,"Owned garage management failed to start: "..tostring(message))
script:SetAttribute("OwnedGarageRuntimeStarted",true)
print("[NTR Owned Garage] Canonical server service active.")
