-- Neo Tokyo Racers - Racing Phase 11U Time Trial HUD Exit Cleanup
-- Run in Roblox Studio Command Bar, Edit mode, then restart Play.
--
-- Installs a tiny isolated local cleanup client. It does not patch the
-- confirmed RaceEntryMenuClient_Active or Phase 11T result coach.
--
-- Scope:
--   Creates/replaces only RaceHudExitCleanupClient_Active.
--   V2 hides only the old top session HUD panel, never result/medal UI.
--   No rewards, route guide, arrows, VFX, matchmaking, driving, bootstrap,
--   or source-text replacement.

local PHASE = "NTR Racing Phase 11U"

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		fail(item:GetFullName() .. " must be a Folder.")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureClientFolder()
	local starterPlayer = game:GetService("StarterPlayer")
	local scripts = starterPlayer:WaitForChild("StarterPlayerScripts")
	local root = ensureFolder(scripts, "NeoTokyoRacersClient")
	local controllers = ensureFolder(root, "Controllers")
	return ensureFolder(controllers, "Racing")
end

local CLIENT_SOURCE = [==[
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
]==]

local folder = ensureClientFolder()
local scriptObject = folder:FindFirstChild("RaceHudExitCleanupClient_Active")
if scriptObject and not scriptObject:IsA("LocalScript") then
	fail(scriptObject:GetFullName() .. " must be a LocalScript or removed.")
end
if not scriptObject then
	scriptObject = Instance.new("LocalScript")
	scriptObject.Name = "RaceHudExitCleanupClient_Active"
	scriptObject.Parent = folder
end
scriptObject.Source = CLIENT_SOURCE
scriptObject.Disabled = false

print("[" .. PHASE .. "] Installed RaceHudExitCleanupClient_Active V2.")
print("[" .. PHASE .. "] Restart Play, finish a time trial, confirm medal/result UI appears, press EXIT TO START, and confirm only the old top timer card disappears.")
