-- Neo Tokyo Racers - Persistence Phase 11
-- Shows the Garage Spaces box only while choosing cockpits.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 10.
-- This is a guarded exact-source patch against the active client bootstrap.

local StarterPlayer = game:GetService("StarterPlayer")

local function assertChild(parent, name)
	local child = parent:FindFirstChild(name)
	assert(child, "Missing " .. parent:GetFullName() .. "." .. name)
	return child
end

local scriptsFolder = assertChild(StarterPlayer, "StarterPlayerScripts")
local clientRoot = assertChild(scriptsFolder, "NeoTokyoRacersClient")
local bootstrap = assertChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(source:find("NTR_PERSISTENCE_PHASE10_GARAGE_UI_LAYOUT_MODAL", 1, true), "Run Phase 10 layout/modal patch before Phase 11.")
assert(not source:find("NTR_PERSISTENCE_PHASE11_GARAGE_SPACES_COCKPIT_ONLY", 1, true), "Persistence Phase 11 cockpit-only garage spaces patch is already installed.")

local function replaceOnce(haystack, needle, replacement, label)
	local found = haystack:find(needle, 1, true)
	assert(found, "Phase 11 preflight failed. Could not find source anchor: " .. label)
	local updated, count = haystack:gsub(needle:gsub("([^%w])", "%%%1"), replacement, 1)
	assert(count == 1, "Phase 11 preflight failed. Anchor was not unique: " .. label)
	return updated
end

local renderAnchor = [=[local function NTR_phase8RenderGarageCapacityPanel()
	if not UI.GarageCapacityPanel then return end
	local ownedCount, capacity, maxCapacity = NTR_phase8GarageCapacitySummary()]=]

local renderReplacement = [=[local function NTR_phase8RenderGarageCapacityPanel()
	if not UI.GarageCapacityPanel then return end
	-- NTR_PERSISTENCE_PHASE11_GARAGE_SPACES_COCKPIT_ONLY
	local showGarageSpaces = State.Stage == "CockpitShop"
	UI.GarageCapacityPanel.Visible = showGarageSpaces
	if not showGarageSpaces then
		if NTRPersistencePhase9 and NTRPersistencePhase9.SetGaragePropertyShopVisible then
			NTRPersistencePhase9.SetGaragePropertyShopVisible(false)
		end
		return
	end
	local ownedCount, capacity, maxCapacity = NTR_phase8GarageCapacitySummary()]=]

source = replaceOnce(source, renderAnchor, renderReplacement, "garage spaces render visibility guard")

local showStageAnchor = [=[	UI.Customise.Visible = stage == "Customise"
	updateNav()
	renderStatsPanel()
	buildPreview()
end]=]

local showStageReplacement = [=[	UI.Customise.Visible = stage == "Customise"
	NTR_phase8RenderGarageCapacityPanel()
	updateNav()
	renderStatsPanel()
	buildPreview()
end]=]

source = replaceOnce(source, showStageAnchor, showStageReplacement, "showStage garage spaces refresh")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase11GarageSpacesCockpitOnly", true)

print("[NTR Persistence Phase 11] PASS: Garage Spaces is now visible only during CockpitShop.")
print("[NTR Persistence Phase 11] Next: run scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_audit.lua, then Play and run scripts/roblox_persistence_phase11_garage_spaces_cockpit_only_client_smoke.lua from the CLIENT Command Bar.")
