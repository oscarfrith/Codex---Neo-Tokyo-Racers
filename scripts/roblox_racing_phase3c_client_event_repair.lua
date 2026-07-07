-- Neo Tokyo Racers - Racing Phase 3C Client Event Repair
-- Repairs/diagnoses the case where the server prompt fires but the race menu
-- never opens on the client.
--
-- This is an exact-source repair against the isolated RaceEntryMenuClient only,
-- plus a tiny client probe LocalScript. It does not patch the main bootstrap,
-- garage server, driving, VFX, dealership, or customisation UI.
--
-- Usage:
--   Run in Roblox Studio Command Bar in Edit mode, then restart Play.

local PHASE = "NTR Racing Phase 3C"

local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 0)
end

local playerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
local racingFolder = controllers and controllers:FindFirstChild("Racing")
local raceClient = racingFolder and racingFolder:FindFirstChild("RaceEntryMenuClient_Active")

if not (raceClient and raceClient:IsA("LocalScript")) then
	fail("Could not find StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceEntryMenuClient_Active. Run Racing Phase 3 first.")
end

local source = raceClient.Source
if source:find("NTR_RACING_PHASE3C_CLIENT_EVENT_REPAIR", 1, true) then
	info("RaceEntryMenuClient_Active already has Phase 3C repair.")
else
	local oldHeader = [[
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local garageInvoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
local racingModules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))
]]

	local newHeader = [[
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local remotes = shared:WaitForChild("Remotes")
local racingRemotes = remotes:WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local garageInvoke = nil
local racingModules = shared:WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

print("[NTR Racing Phase 3 Client] booted " .. script:GetFullName())

local function getGarageInvoke()
	-- NTR_RACING_PHASE3C_CLIENT_EVENT_REPAIR
	if garageInvoke and garageInvoke.Parent then
		return garageInvoke
	end
	local garageRemotes = remotes:FindFirstChild("Garage") or remotes:WaitForChild("Garage", 5)
	if not garageRemotes then
		warn("[NTR Racing Phase 3 Client] Garage remotes missing; vehicle picker will wait until garage is ready.")
		return nil
	end
	garageInvoke = garageRemotes:FindFirstChild("GarageInvoke") or garageRemotes:WaitForChild("GarageInvoke", 5)
	if not garageInvoke then
		warn("[NTR Racing Phase 3 Client] GarageInvoke missing; vehicle picker cannot load yet.")
	end
	return garageInvoke
end
]]

	local oldCallGarage = [[
local function callGarage(action, payload)
	local ok, result = pcall(function()
		return garageInvoke:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end
]]

	local newCallGarage = [[
local function callGarage(action, payload)
	local invoke = getGarageInvoke()
	if not invoke then
		return { Success = false, Ok = false, Message = "Garage is still loading.", Error = "GarageInvoke missing" }
	end
	local ok, result = pcall(function()
		return invoke:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end
]]

	local oldOpen = [[
	if kind == "OpenRaceEntry" then
		showEntry(payload)
	elseif kind == "TimeTrialError" then
]]

	local newOpen = [[
	print("[NTR Racing Phase 3 Client] received event " .. tostring(kind))
	if kind == "OpenRaceEntry" then
		local ok, err = pcall(function()
			showEntry(payload)
		end)
		if not ok then
			warn("[NTR Racing Phase 3 Client] showEntry failed: " .. tostring(err))
		end
	elseif kind == "TimeTrialError" then
]]

	local function replaceExact(haystack, needle, replacement, label)
		local startIndex, endIndex = haystack:find(needle, 1, true)
		if not startIndex then
			fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another racing client repair.")
		end
		return haystack:sub(1, startIndex - 1) .. replacement .. haystack:sub(endIndex + 1)
	end

	source = replaceExact(source, oldHeader, newHeader, "client header/remotes")
	source = replaceExact(source, oldCallGarage, newCallGarage, "callGarage")
	source = replaceExact(source, oldOpen, newOpen, "OpenRaceEntry handler")
	raceClient.Source = source
	raceClient.Disabled = false
	info("Patched RaceEntryMenuClient_Active with safer startup and event logging.")
end

local probeSource = [[
-- Neo Tokyo Racers - Racing Phase 3C Event Probe
-- NTR_RACING_PHASE3C_SIGNAL_PROBE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local raceEvent = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceEvent")

print("[NTR Racing Phase 3C Probe] active " .. script:GetFullName())

local function showProbeMessage(message)
	local existing = playerGui:FindFirstChild("NTR_RaceEntryProbe")
	if existing then existing:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "NTR_RaceEntryProbe"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 84)
	panel.Size = UDim2.fromOffset(520, 90)
	panel.BackgroundColor3 = Color3.fromRGB(9, 13, 18)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 80, 196)
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = panel

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.BorderSizePixel = 0
	text.Position = UDim2.fromOffset(14, 10)
	text.Size = UDim2.new(1, -28, 1, -20)
	text.Text = message
	text.TextColor3 = Color3.fromRGB(235, 255, 248)
	text.TextSize = 14
	text.TextWrapped = true
	text.Font = Enum.Font.GothamBold
	text.Parent = panel

	task.delay(4, function()
		if gui.Parent then gui:Destroy() end
	end)
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.Type ~= "OpenRaceEntry" then return end
	print("[NTR Racing Phase 3C Probe] OpenRaceEntry received for " .. tostring(payload.EventId))
	task.delay(0.5, function()
		local menu = playerGui:FindFirstChild("NTR_RaceEntry")
		local overlay = menu and menu:FindFirstChild("Overlay")
		if not (overlay and overlay.Visible) then
			warn("[NTR Racing Phase 3C Probe] RaceEvent reached client, but main race menu did not become visible.")
			showProbeMessage("Race signal reached this client, but the main race menu did not open. Copy the client Output lines that start with [NTR Racing Phase 3 Client].")
		end
	end)
end)
]]

local probe = playerScripts:FindFirstChild("RaceEntrySignalProbe_Active")
if probe and not probe:IsA("LocalScript") then
	probe:Destroy()
	probe = nil
end
if not probe then
	probe = Instance.new("LocalScript")
	probe.Name = "RaceEntrySignalProbe_Active"
	probe.Parent = playerScripts
end
probe.Source = probeSource
probe.Disabled = false

info("Installed RaceEntrySignalProbe_Active under StarterPlayerScripts.")
info("Restart Play, press E in the race zone, then check client Output for Phase 3 Client / Phase 3C Probe lines.")
