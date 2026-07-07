-- Neo Tokyo Racers - Racing Phase 3B Prompt Connection Repair
-- Repairs a silent Phase 3 issue where an existing NTR_RaceEntryPrompt can
-- survive without a live Triggered connection after the service source changes.
--
-- This is an exact-source repair against the isolated Racing service only.
-- It does not patch the main client bootstrap, garage server, driving, VFX, or UI.
--
-- Usage:
--   Run in Roblox Studio Command Bar in Edit mode, then restart Play.

local PHASE = "NTR Racing Phase 3B"

local ServerScriptService = game:GetService("ServerScriptService")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 0)
end

local serviceRoot = ServerScriptService:FindFirstChild("NeoTokyoRacers")
	and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
	and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Racing")
local scriptObject = serviceRoot and serviceRoot:FindFirstChild("TimeTrialService_Active")

if not (scriptObject and scriptObject:IsA("Script")) then
	fail("Could not find ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active. Run Phase 3 first.")
end

local source = scriptObject.Source
if source:find("NTR_RACING_PHASE3B_PROMPT_REPAIR", 1, true) then
	info("Phase 3B prompt repair already installed.")
	return
end

local oldEnsurePrompt = [[
local function ensurePrompt(zone)
	if not (zone and zone:IsA("BasePart")) then return end
	local oldPrompt = zone:FindFirstChild(OLD_PROMPT_NAME)
	if oldPrompt then
		oldPrompt:Destroy()
	end
	local mode = modeForZone(zone)
	local prompt = zone:FindFirstChild(PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 24
		prompt.RequiresLineOfSight = false
		prompt.Parent = zone
		prompt.Triggered:Connect(function(player)
			sendEntryMenu(player, zone)
		end)
	end
	prompt.ActionText = "Open Race Menu"
	prompt.ObjectText = mode == "Race" and "Race" or "Time Trial"
	prompt.Enabled = zone:GetAttribute("Enabled") ~= false
end
]]

local newEnsurePrompt = [[
local function ensurePrompt(zone, forceRecreate)
	-- NTR_RACING_PHASE3B_PROMPT_REPAIR
	if not (zone and zone:IsA("BasePart")) then return end
	local oldPrompt = zone:FindFirstChild(OLD_PROMPT_NAME)
	if oldPrompt then
		oldPrompt:Destroy()
	end
	local mode = modeForZone(zone)
	local prompt = zone:FindFirstChild(PROMPT_NAME)
	if prompt and forceRecreate == true then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 24
		prompt.RequiresLineOfSight = false
		prompt.Parent = zone
		prompt.Triggered:Connect(function(player)
			info("Race entry prompt triggered by " .. player.Name .. " at " .. zone:GetFullName())
			sendEntryMenu(player, zone)
		end)
	end
	prompt.ActionText = "Open Race Menu"
	prompt.ObjectText = mode == "Race" and "Race" or "Time Trial"
	prompt.Enabled = zone:GetAttribute("Enabled") ~= false
end
]]

local oldEnsureAll = [[
local function ensureAllPrompts()
	local routesRoot = RouteDefinition.GetRoutesRoot()
	if not routesRoot then return end
	for _, route in ipairs(routesRoot:GetChildren()) do
		local startZones = route:FindFirstChild("StartZones")
		if startZones then
			for _, zone in ipairs(startZones:GetChildren()) do
				ensurePrompt(zone)
			end
		end
	end
end
]]

local newEnsureAll = [[
local function ensureAllPrompts(forceRecreate)
	local routesRoot = RouteDefinition.GetRoutesRoot()
	if not routesRoot then return end
	for _, route in ipairs(routesRoot:GetChildren()) do
		local startZones = route:FindFirstChild("StartZones")
		if startZones then
			for _, zone in ipairs(startZones:GetChildren()) do
				ensurePrompt(zone, forceRecreate)
			end
		end
	end
end
]]

local oldStartup = [[
ensureAllPrompts()
task.spawn(function()
	while true do
		ensureAllPrompts()
		task.wait(3)
	end
end)
]]

local newStartup = [[
ensureAllPrompts(true)
task.spawn(function()
	while true do
		ensureAllPrompts(false)
		task.wait(3)
	end
end)
]]

local function replaceExact(haystack, needle, replacement, label)
	local startIndex, endIndex = haystack:find(needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another racing prompt repair.")
	end
	return haystack:sub(1, startIndex - 1) .. replacement .. haystack:sub(endIndex + 1)
end

source = replaceExact(source, oldEnsurePrompt, newEnsurePrompt, "ensurePrompt")
source = replaceExact(source, oldEnsureAll, newEnsureAll, "ensureAllPrompts")
source = replaceExact(source, oldStartup, newStartup, "startup ensureAllPrompts call")

scriptObject.Source = source
scriptObject.Disabled = false

info("Installed prompt connection repair on TimeTrialService_Active.")
info("Restart Play, drive into RaceStartZone or TimeTrialStartZone, then press E.")
info("When E is received, Output should show: Race entry prompt triggered by <player>.")
