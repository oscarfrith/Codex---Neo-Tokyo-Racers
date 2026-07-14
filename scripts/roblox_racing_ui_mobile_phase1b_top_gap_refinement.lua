-- Neo Tokyo Racers - Mobile Racing UI Phase 1B Top Gap Refinement
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Config-only: moves the scaled racing-menu shells closer to Roblox's top controls.

local PHASE = "NTR Mobile Racing UI Phase 1B"
local MARKER = "NTR_RACING_UI_MOBILE_PHASE1B_TOP_GAP_REFINEMENT"
local NEW_SAFE_TOP = 72

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	assert(item and (not className or item:IsA(className)), "[" .. PHASE .. "] Missing " .. (parent and parent:GetFullName() or "nil") .. "." .. name)
	return item
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = must(kit, "Shared", "Folder")
local uiModules = must(must(shared, "Modules", "Folder"), "UI", "Folder")
local layoutModule = must(uiModules, "RacingMobileScaledDesktopLayout", "ModuleScript")
assert(string.find(layoutModule.Source, "NTR_RACING_UI_MOBILE_SCALED_DESKTOP_LAYOUT_V1", 1, true), "[" .. PHASE .. "] Phase 1 shared layout module is not installed")

local controllers = must(must(must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder"), "Controllers", "Folder")
local racing = must(controllers, "Racing", "Folder")
for _, name in ipairs({ "RaceBrowserClient_Active", "RaceEntryPresentationController_Active", "RaceTimeTrialResultCoachClient_Active" }) do
	local owner = must(racing, name, "LocalScript")
	assert(string.find(owner.Source, "NTR_RACING_UI_MOBILE_PHASE1_SCALED_DESKTOP_TRIAL", 1, true), "[" .. PHASE .. "] " .. name .. " is missing the confirmed Phase 1 marker")
end

local config = must(must(must(must(kit, "Config", "Folder"), "UI", "Folder"), "Racing", "Folder"), "MobileScaledDesktop", "Folder")
local oldSafeTop = config:GetAttribute("SafeTop")
assert(type(oldSafeTop) == "number", "[" .. PHASE .. "] MobileScaledDesktop.SafeTop is missing or not numeric")
config:SetAttribute("SafeTop", NEW_SAFE_TOP)
config:SetAttribute("InstalledBy", MARKER)

print(("[%s] SafeTop changed from %s to %d px. No script source, gameplay, or PC layout was changed."):format(PHASE, tostring(oldSafeTop), NEW_SAFE_TOP))
