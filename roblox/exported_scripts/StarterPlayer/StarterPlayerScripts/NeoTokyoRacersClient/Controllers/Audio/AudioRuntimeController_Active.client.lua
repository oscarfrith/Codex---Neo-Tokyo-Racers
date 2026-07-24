-- NTR_AUDIO_SYSTEM_PHASE1_RUNTIME_CLIENT_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("VehicleAudioController"))
	controller.Start()
	return controller
end)

if not ok then
	warn("[NTR Audio Phase 1] Runtime failed safely: " .. tostring(result))
end
