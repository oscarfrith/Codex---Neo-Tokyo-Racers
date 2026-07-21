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
