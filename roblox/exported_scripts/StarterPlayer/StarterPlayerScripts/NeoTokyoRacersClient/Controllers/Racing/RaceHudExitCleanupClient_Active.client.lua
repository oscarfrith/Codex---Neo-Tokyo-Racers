-- Neo Tokyo Racers - Racing Phase 11U Time Trial HUD Exit Cleanup
-- NTR_RACING_PHASE11U_TT_HUD_EXIT_CLEANUP_V2_HUD_ONLY

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = root:WaitForChild("Shared")
local remotes = shared:WaitForChild("Remotes")
local racingRemotes = remotes:WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")

local cleanupToken = 0

local function hideOldTopHud()
	local hudGui = playerGui:FindFirstChild("NTR_RaceHud_Phase3")
	local panel = hudGui and hudGui:FindFirstChild("Panel")
	if panel and panel:IsA("GuiObject") then
		panel.Visible = false
	end
end

local function restoreResultFallbacks()
	for _, name in ipairs({ "NTR_RaceResults_Phase4", "NTR_TimeTrialResultCoach" }) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = true
		end
	end
end

local function scheduleCleanup(reason)
	cleanupToken += 1
	local token = cleanupToken
	restoreResultFallbacks()
	hideOldTopHud()
	for _, delaySeconds in ipairs({ 0.03, 0.12, 0.35, 0.8 }) do
		task.delay(delaySeconds, function()
			if cleanupToken == token then
				restoreResultFallbacks()
				hideOldTopHud()
			end
		end)
	end
	print("[NTR Racing Phase 11U Client] Hid old top race HUD only. reason=" .. tostring(reason or ""))
end

local function cleanupForPayload(payload)
	if type(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	if kind == "TimeTrialFinished"
		or kind == "TimeTrialEnded"
		or kind == "TimeTrialError"
		or kind == "RaceExitedToStart"
		or kind == "RaceEnded"
		or kind == "RaceDNF"
		or kind == "RaceQueueError" then
		scheduleCleanup(kind)
	end
end

raceEvent.OnClientEvent:Connect(cleanupForPayload)
queueEvent.OnClientEvent:Connect(cleanupForPayload)

task.defer(function()
	local clientRoot = script.Parent and script.Parent.Parent and script.Parent.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local exitedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleExited")
	if exitedEvent and exitedEvent:IsA("BindableEvent") then
		exitedEvent.Event:Connect(function()
			scheduleCleanup("FreeRoamVehicleExited")
		end)
	end
end)

print("[NTR Racing Phase 11U Client] Time-trial HUD exit cleanup active.")
