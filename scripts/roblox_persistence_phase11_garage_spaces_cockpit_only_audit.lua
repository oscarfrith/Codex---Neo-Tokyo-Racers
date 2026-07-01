-- Neo Tokyo Racers - Persistence Phase 11 source audit
-- Run from Roblox Studio Command Bar in Edit mode or Play mode.

local StarterPlayer = game:GetService("StarterPlayer")

local bootstrap = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
	and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap and bootstrap:IsA("LocalScript"), "Missing active client bootstrap LocalScript.")

local source = bootstrap.Source
local function mustContain(marker)
	assert(source:find(marker, 1, true), "Missing Phase 11 source marker/text: " .. marker)
end

mustContain("NTR_PERSISTENCE_PHASE11_GARAGE_SPACES_COCKPIT_ONLY")
mustContain("local showGarageSpaces = State.Stage == \"CockpitShop\"")
mustContain("UI.GarageCapacityPanel.Visible = showGarageSpaces")
mustContain("NTR_phase8RenderGarageCapacityPanel()")

assert(bootstrap:GetAttribute("PersistencePhase11GarageSpacesCockpitOnly") == true, "Bootstrap attribute PersistencePhase11GarageSpacesCockpitOnly was not set.")

print("[NTR Persistence Phase 11 Audit] PASS: Garage Spaces visibility is gated to CockpitShop in source.")
