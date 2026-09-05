-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
-- NTR_AUDIO_SYSTEM_PHASE1_RUNTIME_CLIENT_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("VehicleAudioClient"))
	controller.Start()
	return controller
end)

if not ok then
	warn("[NTR Audio Phase 1] Runtime failed safely: " .. tostring(result))
end

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
