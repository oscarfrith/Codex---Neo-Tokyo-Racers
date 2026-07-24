-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_RUNTIME_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("ContextAudioController"))
	controller.Start()
	return controller
end)

if not ok then
	warn("[NTR Audio Phase 2] Context runtime failed safely: " .. tostring(result))
end
