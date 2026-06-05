-- Neo Tokyo Racers - Dealership Intro Phase 7: Exit Button + Reopen Gate
-- Run in Roblox Studio Command Bar, Edit mode, after Phase 6.
--
-- Purpose:
--   Adds an Exit button to the first dealership cockpit-buy menu and changes
--   the desk intro flow so the garage can reopen after the player exits,
--   but only after they leave the desk zone and walk back in.
--
-- Safe design:
--   - Patches only:
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active
--   - Does not touch server purchase/profile/cash logic, preview spawning,
--     final vehicle spawning, driving, VFX, LOD, lighting, traffic, or mobile controls.
--   - Does not create backup folders.
--   - Safe to rerun.

local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_dealership_intro_phase7_exit_button_reopen_gate"
local BOOTSTRAP_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"
local INTRO_CLIENT_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active"

local BOOTSTRAP_HELPER_ANCHOR = [==[local applyDealershipLayout
]==]

local BOOTSTRAP_HELPER_INSERT = [==[local applyDealershipLayout

-- NTR_DEALERSHIP_INTRO_PHASE7_EXIT_BEGIN
local NTR_DEALERSHIP_INTRO_CLOSE_EVENT_NAME = "GarageClosedFromDealershipExit"

local function NTR_phase7IntroFolder()
	local controllers = script.Parent and script.Parent:FindFirstChild("Controllers")
	return controllers and controllers:FindFirstChild("Intro")
end

local function NTR_phase7SignalDealershipExit()
	local introFolder = NTR_phase7IntroFolder()
	if not introFolder then
		warn("[NTR Dealership Intro Phase 7] Controllers.Intro was not found; exit close signal was not fired.")
		return
	end

	local closeEvent = introFolder:FindFirstChild(NTR_DEALERSHIP_INTRO_CLOSE_EVENT_NAME)
	if closeEvent and not closeEvent:IsA("BindableEvent") then
		warn("[NTR Dealership Intro Phase 7] " .. closeEvent:GetFullName() .. " exists but is " .. closeEvent.ClassName .. ", expected BindableEvent.")
		return
	end

	if not closeEvent then
		closeEvent = Instance.new("BindableEvent")
		closeEvent.Name = NTR_DEALERSHIP_INTRO_CLOSE_EVENT_NAME
		closeEvent.Parent = introFolder
	end

	closeEvent:Fire()
end
-- NTR_DEALERSHIP_INTRO_PHASE7_EXIT_END
]==]

local OLD_GATE_BLOCK = [==[-- NTR_DEALERSHIP_INTRO_PHASE3_GATE_BEGIN
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
-- NTR_DEALERSHIP_INTRO_PHASE3_GATE_END]==]

local NEW_GATE_BLOCK = [==[-- NTR_DEALERSHIP_INTRO_PHASE3_GATE_BEGIN
local NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME = "OpenGarageFromIntro"
local NTR_dealershipIntroGarageInitialized = false

local function NTR_openGarageFromDealershipIntro()
	if NTR_dealershipIntroGarageInitialized then
		if UI and UI.Gui then
			UI.Gui.Enabled = true
			if State then
				State.GarageCameraActive = false
				State.NoPreviewYet = true
				State.Phase5PreviewOrbitInitialized = false
			end
			if showStage then
				showStage("CockpitShop")
			else
				UI.CockpitShop.Visible = true
			end
			if renderCockpitShop then
				renderCockpitShop()
			end
		end
		return
	end

	NTR_dealershipIntroGarageInitialized = true
	task.defer(init)
end

task.spawn(function()
	local clientRoot = script.Parent
	local controllers = clientRoot and clientRoot:WaitForChild("Controllers", 10)
	local introFolder = controllers and controllers:WaitForChild("Intro", 10)
	if not introFolder then
		warn("[NTR Dealership Intro Phase 7] Could not install OpenGarageFromIntro hook; Controllers.Intro was not found.")
		return
	end

	local openEvent = introFolder:FindFirstChild(NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME)
	if openEvent and not openEvent:IsA("BindableEvent") then
		warn("[NTR Dealership Intro Phase 7] " .. openEvent:GetFullName() .. " exists but is " .. openEvent.ClassName .. ", expected BindableEvent.")
		return
	end

	if not openEvent then
		openEvent = Instance.new("BindableEvent")
		openEvent.Name = NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME
		openEvent.Parent = introFolder
	end

	openEvent.Event:Connect(NTR_openGarageFromDealershipIntro)
	script:SetAttribute("DealershipIntroGarageGateActive", true)
	script:SetAttribute("DealershipIntroPhase7ReopenGateActive", true)
	print("[NTR Dealership Intro Phase 7] Garage opens at desk and can reopen after exit once the player leaves and re-enters the desk zone.")
end)
-- NTR_DEALERSHIP_INTRO_PHASE3_GATE_END]==]

local OLD_LAYOUT = [==[	local statsH = math.min(520, math.max(1, bottomY - topY))

	if UI.CategoryPanel then]==]

local NEW_LAYOUT = [==[	local exitPanelH = BOTTOM_HEIGHT
	local exitTopY = bottomY - exitPanelH
	local statsH = math.min(520, math.max(1, exitTopY - gap - topY))

	if UI.CategoryPanel then]==]

local OLD_LAYOUT_STATS = [==[	if UI.StatsPanel and State.Stage == "CockpitShop" then
		UI.StatsPanel.AnchorPoint = Vector2.new(1, 0)
		UI.StatsPanel.Position = UDim2.fromOffset(vw - margin, topY)
		UI.StatsPanel.Size = UDim2.fromOffset(rightW, statsH)
	end
	if UI.CockpitGridLayout then]==]

local NEW_LAYOUT_STATS = [==[	if UI.StatsPanel and State.Stage == "CockpitShop" then
		UI.StatsPanel.AnchorPoint = Vector2.new(1, 0)
		UI.StatsPanel.Position = UDim2.fromOffset(vw - margin, topY)
		UI.StatsPanel.Size = UDim2.fromOffset(rightW, statsH)
	end
	if UI.DealershipExitPanel then
		UI.DealershipExitPanel.AnchorPoint = Vector2.new(1, 1)
		UI.DealershipExitPanel.Position = UDim2.fromOffset(vw - margin, bottomY)
		UI.DealershipExitPanel.Size = UDim2.fromOffset(rightW, exitPanelH)
	end
	if UI.DealershipExitButton then
		UI.DealershipExitButton.Size = UDim2.new(1, -18, 0, UserInputService.TouchEnabled and 48 or 42)
		UI.DealershipExitButton.Position = UDim2.new(0, 9, 0.5, UserInputService.TouchEnabled and -24 or -21)
	end
	if UI.CockpitGridLayout then]==]

local OLD_UPDATE_NAV = [==[local function updateNav()
	local showNav = State.Stage ~= "CockpitShop"
	UI.NextPanel.Visible = showNav]==]

local NEW_UPDATE_NAV = [==[local function updateNav()
	local showNav = State.Stage ~= "CockpitShop"
	UI.NextPanel.Visible = showNav
	if UI.DealershipExitPanel then
		UI.DealershipExitPanel.Visible = State.Stage == "CockpitShop"
	end]==]

local OLD_EXIT_UI_ANCHOR = [==[	UI.NextPanel = panel(gui, "NextPinnedBottomRight", UDim2.fromOffset(178, BOTTOM_HEIGHT), UDim2.new(1, -18, 1, -BOTTOM_MARGIN), Vector2.new(1, 1))
	UI.Next = button(UI.NextPanel, "Next", UDim2.new(1, -18, 0, 42), UDim2.fromOffset(9, 9), Theme.Buy)
	UI.Back = button(UI.NextPanel, "Back", UDim2.new(1, -18, 0, 38), UDim2.fromOffset(9, 58), Theme.Card)
	local centerPanelSize = UDim2.new(1, -420, 0, BOTTOM_HEIGHT)]==]

local NEW_EXIT_UI_BLOCK = [==[	UI.NextPanel = panel(gui, "NextPinnedBottomRight", UDim2.fromOffset(178, BOTTOM_HEIGHT), UDim2.new(1, -18, 1, -BOTTOM_MARGIN), Vector2.new(1, 1))
	UI.Next = button(UI.NextPanel, "Next", UDim2.new(1, -18, 0, 42), UDim2.fromOffset(9, 9), Theme.Buy)
	UI.Back = button(UI.NextPanel, "Back", UDim2.new(1, -18, 0, 38), UDim2.fromOffset(9, 58), Theme.Card)
	UI.DealershipExitPanel = panel(UI.CockpitShop or gui, "DealershipExitPinnedBottomRight", UDim2.fromOffset(270, BOTTOM_HEIGHT), UDim2.new(1, -18, 1, -BOTTOM_MARGIN), Vector2.new(1, 1))
	UI.DealershipExitPanel.Visible = true
	UI.DealershipExitButton = button(UI.DealershipExitPanel, "Exit", UDim2.new(1, -18, 0, 42), UDim2.new(0, 9, 0.5, -21), Theme.Danger)
	local centerPanelSize = UDim2.new(1, -420, 0, BOTTOM_HEIGHT)]==]

local OLD_COCKPIT_SHOP_CREATE = [==[	UI.CockpitShop = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	UI.CategoryPanel = panel(UI.CockpitShop, "Categories", UDim2.fromOffset(190, 560), UDim2.fromOffset(24, 112), Vector2.zero)]==]

local NEW_COCKPIT_SHOP_CREATE = [==[	UI.CockpitShop = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	if UI.DealershipExitPanel then
		UI.DealershipExitPanel.Parent = UI.CockpitShop
	end
	UI.CategoryPanel = panel(UI.CockpitShop, "Categories", UDim2.fromOffset(190, 560), UDim2.fromOffset(24, 112), Vector2.zero)]==]

local OLD_NEXT_CLICK_ANCHOR = [==[	UI.Next.MouseButton1Click:Connect(function()]==]

local NEW_EXIT_CLICK_BLOCK = [==[	UI.DealershipExitButton.MouseButton1Click:Connect(function()
		closeGarage()
		NTR_phase7SignalDealershipExit()
	end)

	UI.Next.MouseButton1Click:Connect(function()]==]

local OLD_INTRO_RUN = [==[local function run()
	local _, root = waitForCharacterRoot()
	local intro = waitForIntro()
	local deskFolder = intro:WaitForChild("Desk")
	local deskTrigger = deskFolder:WaitForChild("GarageDeskTrigger")

	if not deskTrigger:IsA("BasePart") then
		warnOnce("bad-desk-trigger", "Intro.Desk.GarageDeskTrigger is not a BasePart; intro client cannot run distance checks.")
		return
	end

	local config = getIntroConfig(intro, deskTrigger)
	if not config.Enabled then
		log("Intro.Enabled is false; dealership intro client is idle.")
		return
	end

	debugPrint(config, "Intro enabled. Activation distance: " .. tostring(config.DeskActivationDistance))

	local objectiveGui = createObjectiveGui(config)
	createPathArrows(intro, config)
	playCameraIntro(intro, config)

	local opened = false
	while not opened do
		if not root.Parent then
			_, root = waitForCharacterRoot()
		end

		local distance = (root.Position - deskTrigger.Position).Magnitude
		if distance <= config.DeskActivationDistance then
			opened = true
			cleanup(objectiveGui)
			tryOpenGarage(config)
			break
		end

		task.wait(0.15)
	end
end]==]

local NEW_INTRO_RUN = [==[local function run()
	local _, root = waitForCharacterRoot()
	local intro = waitForIntro()
	local deskFolder = intro:WaitForChild("Desk")
	local deskTrigger = deskFolder:WaitForChild("GarageDeskTrigger")

	if not deskTrigger:IsA("BasePart") then
		warnOnce("bad-desk-trigger", "Intro.Desk.GarageDeskTrigger is not a BasePart; intro client cannot run distance checks.")
		return
	end

	local config = getIntroConfig(intro, deskTrigger)
	if not config.Enabled then
		log("Intro.Enabled is false; dealership intro client is idle.")
		return
	end

	debugPrint(config, "Intro enabled. Activation distance: " .. tostring(config.DeskActivationDistance))

	local objectiveGui = createObjectiveGui(config)
	createPathArrows(intro, config)
	playCameraIntro(intro, config)

	local closeEvent = script.Parent:FindFirstChild("GarageClosedFromDealershipExit")
	if closeEvent and not closeEvent:IsA("BindableEvent") then
		warnOnce("bad-close-hook", "GarageClosedFromDealershipExit exists but is " .. closeEvent.ClassName .. ", expected BindableEvent. Reopen gating will not arm.")
		closeEvent = nil
	end
	if not closeEvent then
		closeEvent = Instance.new("BindableEvent")
		closeEvent.Name = "GarageClosedFromDealershipExit"
		closeEvent.Parent = script.Parent
	end

	local dismissedUntilLeave = false
	local wasInsideZone = false
	local reopenDistance = math.max(config.DeskActivationDistance + 3, config.DeskActivationDistance * 1.75)

	local function onExited()
		dismissedUntilLeave = true
		wasInsideZone = true
		log("Dealership menu exited. Walk away from the desk, then re-enter the zone to reopen it.")
	end

	closeEvent.Event:Connect(onExited)

	while true do
		if not root.Parent then
			_, root = waitForCharacterRoot()
		end

		local distance = (root.Position - deskTrigger.Position).Magnitude
		local insideZone = distance <= config.DeskActivationDistance

		if dismissedUntilLeave and distance >= reopenDistance then
			dismissedUntilLeave = false
			wasInsideZone = false
			log("Dealership desk reopen gate reset. Re-enter the desk zone to reopen the menu.")
		end

		if insideZone and not wasInsideZone and not dismissedUntilLeave then
			cleanup(objectiveGui)
			tryOpenGarage(config)
		end

		wasInsideZone = insideZone
		task.wait(0.15)
	end
end]==]

local SERVICES = {
	StarterPlayer = StarterPlayer,
}

local changed = {}
local skipped = {}

local function log(message)
	print("[NTR Dealership Intro Phase 7] " .. message)
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
	if not current then return nil end
	local skipFirst = true
	for token in string.gmatch(path, "[^%.]+") do
		if skipFirst then
			skipFirst = false
		else
			current = current:FindFirstChild(token)
			if not current then return nil end
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

local function countPlain(text, pattern)
	local count = 0
	local startAt = 1
	while true do
		local startIndex, endIndex = string.find(text, pattern, startAt, true)
		if not startIndex then break end
		count += 1
		startAt = endIndex + 1
	end
	return count
end

local function replaceOncePlain(text, old, new)
	local startIndex, endIndex = string.find(text, old, 1, true)
	if not startIndex then
		return text, 0
	end
	return string.sub(text, 1, startIndex - 1) .. new .. string.sub(text, endIndex + 1), 1
end

local function patchSource(instance, patchList)
	local source = sourceOf(instance)
	if not source then
		error("Could not read Source for " .. safeFullName(instance) .. ". No changes applied.")
	end

	if string.find(source, "NTR_DEALERSHIP_INTRO_PHASE7_EXIT_BEGIN", 1, true)
		or string.find(source, "DealershipIntroPhase7ReopenGateActive", 1, true) then
		table.insert(skipped, safeFullName(instance) .. " already contains Phase 7 bootstrap patch")
		return
	end

	for _, patch in ipairs(patchList) do
		if countPlain(source, patch.old) ~= 1 then
			error("Phase 7 preflight failed for `" .. patch.name .. "` in " .. safeFullName(instance) .. ". Expected exactly 1 match. No changes applied. Paste this output back into Codex.")
		end
	end

	for _, patch in ipairs(patchList) do
		local patched, count = replaceOncePlain(source, patch.old, patch.new)
		if count ~= 1 then
			error("Unexpected patch failure for `" .. patch.name .. "`. No changes applied.")
		end
		source = patched
		table.insert(changed, safeFullName(instance) .. " -> " .. patch.name)
	end

	instance.Source = source
	instance:SetAttribute("DealershipIntroPhase7PatchedBy", SCRIPT_ID)
	instance:SetAttribute("DealershipIntroPhase7PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
end

local function patchIntroClient(introClient)
	local source = sourceOf(introClient)
	if not source then
		error("Could not read Source for " .. safeFullName(introClient) .. ". No changes applied.")
	end

	if string.find(source, "dismissedUntilLeave", 1, true) then
		table.insert(skipped, safeFullName(introClient) .. " already contains Phase 7 reopen gate")
		return
	end

	if countPlain(source, OLD_INTRO_RUN) ~= 1 then
		error("Phase 7 preflight failed for intro client run loop. Expected exactly 1 Phase 2/3 run shape. No changes applied. Paste this output back into Codex.")
	end

	local patched, count = replaceOncePlain(source, OLD_INTRO_RUN, NEW_INTRO_RUN)
	if count ~= 1 then
		error("Unexpected patch failure replacing intro client run loop. No changes applied.")
	end

	introClient.Source = patched
	introClient:SetAttribute("DealershipIntroPhase7PatchedBy", SCRIPT_ID)
	introClient:SetAttribute("DealershipIntroPhase7PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
	table.insert(changed, safeFullName(introClient) .. " -> replaced one-shot desk open with leave-and-reenter loop")
end

local bootstrap = resolvePath(BOOTSTRAP_PATH)
if not bootstrap or not bootstrap:IsA("LocalScript") then
	error("Active bootstrap was not found as a LocalScript at " .. BOOTSTRAP_PATH .. ". No changes applied.")
end

local introClient = resolvePath(INTRO_CLIENT_PATH)
if not introClient or not introClient:IsA("LocalScript") then
	error("Intro client was not found as a LocalScript at " .. INTRO_CLIENT_PATH .. ". Run Phase 2/3 first.")
end

patchSource(bootstrap, {
	{ name = "Add Phase 7 exit helper event", old = BOOTSTRAP_HELPER_ANCHOR, new = BOOTSTRAP_HELPER_INSERT },
	{ name = "Allow OpenGarageFromIntro to reopen existing UI", old = OLD_GATE_BLOCK, new = NEW_GATE_BLOCK },
	{ name = "Reserve bottom-right row below stats for exit button", old = OLD_LAYOUT, new = NEW_LAYOUT },
	{ name = "Lay out exit panel aligned to stats right and cash bottom", old = OLD_LAYOUT_STATS, new = NEW_LAYOUT_STATS },
	{ name = "Show exit panel only on cockpit shop stage", old = OLD_UPDATE_NAV, new = NEW_UPDATE_NAV },
	{ name = "Create dealership exit UI", old = OLD_EXIT_UI_ANCHOR, new = NEW_EXIT_UI_BLOCK },
	{ name = "Parent exit UI under cockpit shop", old = OLD_COCKPIT_SHOP_CREATE, new = NEW_COCKPIT_SHOP_CREATE },
	{ name = "Wire exit button to close garage and arm reopen gate", old = OLD_NEXT_CLICK_ANCHOR, new = NEW_EXIT_CLICK_BLOCK },
})

patchIntroClient(introClient)

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 7 Exit Button + Reopen Gate")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Bootstrap target: " .. BOOTSTRAP_PATH)
line("- Intro client target: " .. INTRO_CLIENT_PATH)
line("- Changes applied: " .. tostring(#changed))
line("- Skipped: " .. tostring(#skipped))
line("- Server purchase/profile/cash logic touched: false")
line("- Preview/final vehicle spawn touched: false")
line("")

line("## Changes")
line("")
if #changed == 0 then
	line("- None.")
else
	for _, item in ipairs(changed) do line("- " .. item) end
end
line("")

line("## Skipped")
line("")
if #skipped == 0 then
	line("- None.")
else
	for _, item in ipairs(skipped) do line("- " .. item) end
end
line("")

line("## Play Test")
line("")
line("1. Start a fresh Play Solo session.")
line("2. Walk to GarageDeskTrigger to open the first dealership cockpit menu.")
line("3. Confirm the Exit button appears bottom-right, aligned with the stats panel right edge and cash panel bottom edge.")
line("4. Test PC and mobile view sizes; stats, cockpit grid, cash, and Exit should not overlap.")
line("5. Click Exit. The menu should close and stay closed while standing in the desk zone.")
line("6. Walk away from the desk by a few studs, then walk back in. The first dealership menu should reopen.")
line("7. Paste any `[NTR Dealership Intro Phase 7]` or `[NTR Dealership Intro Client]` output back into Codex.")

log("Phase 7 complete. Changes applied: " .. tostring(#changed) .. "; skipped: " .. tostring(#skipped))
print(table.concat(report, "\n"))
