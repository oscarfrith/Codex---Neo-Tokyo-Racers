-- Persistence Phase 17 cockpit paint stage scope repair.
--
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- This repairs a regression from the module popup card-anchor patch where
-- showStage() could call NTR_hideModulePopup() before that helper was in scope.
-- The symptom is selecting/buying a cockpit leaves the dealership UI visible
-- instead of advancing to Paint Cockpit.
--
-- The fix keeps popup cleanup, but makes showStage() hide the popup inline so
-- cockpit selection, Paint Cockpit, Module Shop, and Customise stage changes
-- do not depend on helper declaration order.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Cockpit Paint Stage Scope Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another cockpit paint scope patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another cockpit paint scope patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "local function showStage(stage)"), "Expected showStage in active client bootstrap.")

local brokenShowStageHeader = [=[local function showStage(stage)
	NTR_hideModulePopup()
	State.Stage = stage]=]

local fixedShowStageHeader = [=[local function showStage(stage)
	if UI and UI.ModulePopup then
		UI.ModulePopup.Visible = false
	end
	State.Stage = stage]=]

local changed = false
if findPlain(source, brokenShowStageHeader) then
	source, changed = replaceOnce(source, brokenShowStageHeader, fixedShowStageHeader, "showStage popup cleanup scope")
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17CockpitPaintStageScopeRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "local function showStage(stage)"), "showStage is missing after patch.")
assert(not findPlain(finalSource, brokenShowStageHeader), "showStage still calls NTR_hideModulePopup before helper scope.")
assert(findPlain(finalSource, "UI.ModulePopup.Visible = false"), "Inline module popup cleanup was not installed.")

if changed then
	info("PASS: showStage now hides ModulePopup inline instead of calling a later-scoped helper.")
else
	info("PASS: showStage did not contain the known broken NTR_hideModulePopup call; no source change was needed.")
end
info("Next: restart Play, select/buy a cockpit, and confirm the Paint Cockpit menu appears.")
