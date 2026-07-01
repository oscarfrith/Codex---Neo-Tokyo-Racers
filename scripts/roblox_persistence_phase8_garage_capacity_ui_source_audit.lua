-- Neo Tokyo Racers - Persistence Phase 8 source audit
-- Run from Roblox Studio Command Bar in Edit mode or Play mode.

local StarterPlayer = game:GetService("StarterPlayer")

local scriptsFolder = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(scriptsFolder, "Missing StarterPlayer.StarterPlayerScripts.")

local clientRoot = scriptsFolder:FindFirstChild("NeoTokyoRacersClient")
assert(clientRoot, "Missing StarterPlayerScripts.NeoTokyoRacersClient.")

local bootstrap = clientRoot:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap and bootstrap:IsA("LocalScript"), "Missing active client bootstrap LocalScript.")

local source = bootstrap.Source
local function mustContain(marker)
	assert(source:find(marker, 1, true), "Missing Phase 8 source marker/text: " .. marker)
end

mustContain("NTR_PERSISTENCE_PHASE8_CAPACITY_UI_BEGIN")
mustContain("NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_BEGIN")
mustContain("UpgradeGarageCapacity")
mustContain("GarageCapacityPinnedLeft")
mustContain("NTR_phase8RenderGarageCapacityPanel()")

assert(bootstrap:GetAttribute("PersistencePhase8CapacityUI") == true, "Bootstrap attribute PersistencePhase8CapacityUI was not set.")

print("[NTR Persistence Phase 8 Audit] PASS: garage capacity UI source patch is installed on the active client bootstrap.")
