-- Neo Tokyo Racers - Dealership Intro Phase 3: Gate Garage Startup
-- Run in Roblox Studio Command Bar, Edit mode, after Phase 2.
--
-- Purpose:
--   Stops the active client bootstrap from auto-opening the dealership garage
--   on spawn, exposes a local BindableEvent hook, and updates the Phase 2
--   intro client to fire that hook when the player reaches the desk.
--
-- Safe design:
--   - Patches only:
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active
--   - Does not touch server purchase logic, driving, VFX, LOD, lighting,
--     traffic, mobile controls, or world markers.
--   - Does not create backup folders.
--   - Safe to rerun.

local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_dealership_intro_phase3_gate_garage_startup"
local BOOTSTRAP_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"
local INTRO_CLIENT_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active"

local GATE_BLOCK = [==[
-- NTR_DEALERSHIP_INTRO_PHASE3_GATE_BEGIN
local NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME = "OpenGarageFromIntro"
local NTR_dealershipIntroGarageOpened = false

local function NTR_openGarageFromDealershipIntro()
	if NTR_dealershipIntroGarageOpened then
		return
	end

	NTR_dealershipIntroGarageOpened = true
	task.defer(init)
end

task.spawn(function()
	local clientRoot = script.Parent
	local controllers = clientRoot and clientRoot:WaitForChild("Controllers", 10)
	local introFolder = controllers and controllers:WaitForChild("Intro", 10)
	if not introFolder then
		warn("[NTR Dealership Intro Phase 3] Could not install OpenGarageFromIntro hook; Controllers.Intro was not found.")
		return
	end

	local openEvent = introFolder:FindFirstChild(NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME)
	if openEvent and not openEvent:IsA("BindableEvent") then
		warn("[NTR Dealership Intro Phase 3] " .. openEvent:GetFullName() .. " exists but is " .. openEvent.ClassName .. ", expected BindableEvent.")
		return
	end

	if not openEvent then
		openEvent = Instance.new("BindableEvent")
		openEvent.Name = NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME
		openEvent.Parent = introFolder
	end

	openEvent.Event:Connect(NTR_openGarageFromDealershipIntro)
	script:SetAttribute("DealershipIntroGarageGateActive", true)
	print("[NTR Dealership Intro Phase 3] Garage startup is gated until OpenGarageFromIntro fires.")
end)
-- NTR_DEALERSHIP_INTRO_PHASE3_GATE_END
]==]

local OLD_INTRO_WARNING = [==[warnOnce("missing-open-hook", "Reached dealership desk, but no clean garage UI open function/event is exposed. Current mirrored flow keeps setupUI/showStage/buildPreview private inside StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled. TODO: expose a BindableEvent or small module API, then call it here.")]==]

local NEW_INTRO_OPEN = [==[local openEvent = script.Parent:FindFirstChild("OpenGarageFromIntro")
	if not openEvent then
		openEvent = script.Parent:WaitForChild("OpenGarageFromIntro", 5)
	end

	if openEvent and openEvent:IsA("BindableEvent") then
		log("Reached dealership desk. Opening garage through OpenGarageFromIntro.")
		openEvent:Fire()
	else
		warnOnce("missing-open-hook", "Reached dealership desk, but OpenGarageFromIntro BindableEvent was not found under " .. script.Parent:GetFullName() .. ". Run scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua again, then test in a fresh Play Solo session.")
	end]==]

local changed = {}
local skipped = {}
local SERVICES = {
	StarterPlayer = StarterPlayer,
}

local function log(message)
	print("[NTR Dealership Intro Phase 3] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function resolvePath(path)
	local firstToken = string.match(path, "^[^%.]+")
	local current = SERVICES[firstToken]
	if not current then
		return nil
	end

	local skipFirst = true
	for token in string.gmatch(path, "[^%.]+") do
		if skipFirst then
			skipFirst = false
		else
			current = current:FindFirstChild(token)
			if not current then
				return nil
			end
		end
	end
	return current
end

local function sourceOf(instance)
	local ok, source = pcall(function()
		return instance.Source
	end)
	if ok and typeof(source) == "string" then
		return source
	end
	return nil
end

local function replaceOncePlain(source, old, new)
	local startIndex, endIndex = string.find(source, old, 1, true)
	if not startIndex then
		return source, 0
	end

	local patched = string.sub(source, 1, startIndex - 1) .. new .. string.sub(source, endIndex + 1)
	return patched, 1
end

local function patchBootstrap(bootstrap)
	if not bootstrap or not bootstrap:IsA("LocalScript") then
		error("Active bootstrap was not found as a LocalScript at " .. BOOTSTRAP_PATH .. ". No changes applied.")
	end

	local source = sourceOf(bootstrap)
	if not source then
		error("Could not read Source for " .. safeFullName(bootstrap) .. ". No changes applied.")
	end

	if string.find(source, "NTR_DEALERSHIP_INTRO_PHASE3_GATE_BEGIN", 1, true) then
		table.insert(skipped, safeFullName(bootstrap) .. " already has Phase 3 gate block")
		return
	end

	if not string.find(source, "local function init", 1, true) then
		error("Bootstrap source does not contain `local function init`. Paste the current source/audit back into Codex.")
	end

	local patched, count = replaceOncePlain(source, "task.defer(init)", GATE_BLOCK)
	if count ~= 1 then
		error("Bootstrap source did not contain exactly the expected `task.defer(init)` startup call. Paste the current source/audit back into Codex.")
	end

	bootstrap.Source = patched
	bootstrap:SetAttribute("DealershipIntroPhase3PatchedBy", SCRIPT_ID)
	bootstrap:SetAttribute("DealershipIntroPhase3PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
	table.insert(changed, safeFullName(bootstrap) .. " -> replaced auto task.defer(init) with OpenGarageFromIntro gate")
end

local function patchIntroClient(introClient)
	if not introClient or not introClient:IsA("LocalScript") then
		error("Intro client was not found as a LocalScript at " .. INTRO_CLIENT_PATH .. ". Run Phase 2 first.")
	end

	local source = sourceOf(introClient)
	if not source then
		error("Could not read Source for " .. safeFullName(introClient) .. ". No changes applied.")
	end

	if string.find(source, "Opening garage through OpenGarageFromIntro", 1, true) then
		table.insert(skipped, safeFullName(introClient) .. " already fires OpenGarageFromIntro")
		return
	end

	local patched, count = replaceOncePlain(source, OLD_INTRO_WARNING, NEW_INTRO_OPEN)
	if count ~= 1 then
		error("Intro client source did not contain the Phase 2 missing-open-hook warning shape. Reinstall Phase 2, then rerun Phase 3.")
	end

	introClient.Source = patched
	introClient:SetAttribute("DealershipIntroPhase3PatchedBy", SCRIPT_ID)
	introClient:SetAttribute("DealershipIntroPhase3PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
	table.insert(changed, safeFullName(introClient) .. " -> fires OpenGarageFromIntro at desk")
end

local bootstrap = resolvePath(BOOTSTRAP_PATH)
local introClient = resolvePath(INTRO_CLIENT_PATH)

patchBootstrap(bootstrap)
patchIntroClient(introClient)

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 3 Gate Garage Startup")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Bootstrap target: " .. BOOTSTRAP_PATH)
line("- Intro client target: " .. INTRO_CLIENT_PATH)
line("- Changes applied: " .. tostring(#changed))
line("- Skipped as already patched: " .. tostring(#skipped))
line("")

line("## Changes")
line("")
if #changed == 0 then
	line("- None.")
else
	for _, item in ipairs(changed) do
		line("- " .. item)
	end
end
line("")

line("## Skipped")
line("")
if #skipped == 0 then
	line("- None.")
else
	for _, item in ipairs(skipped) do
		line("- " .. item)
	end
end
line("")

line("## Play Test")
line("")
line("1. Start a fresh Play Solo session.")
line("2. The full dealership garage menu should not open immediately on spawn.")
line("3. The small intro objective/path should appear.")
line("4. Walk to GarageDeskTrigger.")
line("5. The intro objective/path should clear and the garage menu should open once.")
line("6. Paste any `[NTR Dealership Intro Phase 3]` or `[NTR Dealership Intro Client]` output back into Codex.")

log("Phase 3 gate complete. Changes applied: " .. tostring(#changed) .. "; skipped: " .. tostring(#skipped))
print(table.concat(report, "\n"))
