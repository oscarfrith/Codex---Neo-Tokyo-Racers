-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Audio"):WaitForChild("AcousticsRuntimeController_Active")
-- NTR_AUDIO_SYSTEM_PHASE3_ACOUSTICS_RUNTIME_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("AcousticsController"))
	controller.Start()
	return controller
end)

if not ok then warn("[NTR Audio Phase 3] Acoustics runtime failed safely: " .. tostring(result)) end

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
