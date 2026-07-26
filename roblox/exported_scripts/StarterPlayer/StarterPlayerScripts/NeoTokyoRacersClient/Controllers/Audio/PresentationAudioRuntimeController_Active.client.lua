-- NTR_PRESENTATION_AUDIO_RUNTIME_CLIENT_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioController"))
	controller.Start()
	return controller
end)

if not ok then
	warn("[NTR Presentation Audio] Runtime failed safely: " .. tostring(result))
end
