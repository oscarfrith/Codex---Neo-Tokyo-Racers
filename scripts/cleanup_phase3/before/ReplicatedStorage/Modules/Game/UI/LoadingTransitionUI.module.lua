-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
-- NTR_LOADING_SYSTEM_PHASE1_CONTROLLER_V1
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local runtime = require(ReplicatedFirst:WaitForChild("NTRLoading"):WaitForChild("LoadingTransitionRuntime"))
local api = runtime.Start({ UIFolder = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI") })
local invoke = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):WaitForChild("LoadingTransitionInvoke")

invoke.OnInvoke = function(action, payload)
	local ok, a, b = pcall(function() return api:Handle(action, payload) end)
	if ok then return a, b end
	warn("[NTR Loading System Phase 1] " .. tostring(action) .. " failed: " .. tostring(a))
	return false, tostring(a)
end

game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):WaitForChild("LoadingPresentationState"):SetAttribute("ControllerReady", true)
print("[NTR Loading System Phase 1] Runtime controller ready.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
