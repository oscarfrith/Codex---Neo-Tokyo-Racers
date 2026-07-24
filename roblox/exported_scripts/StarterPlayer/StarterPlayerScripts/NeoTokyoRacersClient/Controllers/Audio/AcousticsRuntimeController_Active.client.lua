-- NTR_AUDIO_SYSTEM_PHASE3_ACOUSTICS_RUNTIME_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("AcousticsController"))
	controller.Start()
	return controller
end)

if not ok then warn("[NTR Audio Phase 3] Acoustics runtime failed safely: " .. tostring(result)) end
