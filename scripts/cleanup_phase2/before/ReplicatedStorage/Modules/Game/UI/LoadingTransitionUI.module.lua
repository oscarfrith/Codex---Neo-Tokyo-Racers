-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("LoadingTransitionController_Active")
-- NTR_LOADING_SYSTEM_PHASE1_CONTROLLER_V1
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local runtime = require(ReplicatedFirst:WaitForChild("NTRLoading"):WaitForChild("LoadingTransitionRuntime"))
local api = runtime.Start({ UIFolder = script.Parent })
local invoke = script.Parent:WaitForChild("LoadingTransitionInvoke")

invoke.OnInvoke = function(action, payload)
	local ok, a, b = pcall(function() return api:Handle(action, payload) end)
	if ok then return a, b end
	warn("[NTR Loading System Phase 1] " .. tostring(action) .. " failed: " .. tostring(a))
	return false, tostring(a)
end

script.Parent.LoadingPresentationState:SetAttribute("ControllerReady", true)
print("[NTR Loading System Phase 1] Runtime controller ready.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
