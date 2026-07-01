-- Neo Tokyo Racers - Persistence Phase 10 source audit
-- Run from Roblox Studio Command Bar in Edit mode or Play mode.

local StarterPlayer = game:GetService("StarterPlayer")

local bootstrap = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
	and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap and bootstrap:IsA("LocalScript"), "Missing active client bootstrap LocalScript.")

local source = bootstrap.Source
local function mustContain(marker)
	assert(source:find(marker, 1, true), "Missing Phase 10 source marker/text: " .. marker)
end

mustContain("NTR_PERSISTENCE_PHASE10_GARAGE_UI_LAYOUT_MODAL")
mustContain("GaragePropertyModalBackdrop")
mustContain("NTRPersistencePhase9.SetGaragePropertyShopVisible")
mustContain("UI.GarageCapacityPanel.Position = UDim2.fromOffset(margin, garageBottomY)")
mustContain("UI.CashPanel.Position = UDim2.fromOffset(margin, cashBottomY)")

assert(bootstrap:GetAttribute("PersistencePhase10GarageUILayoutModal") == true, "Bootstrap attribute PersistencePhase10GarageUILayoutModal was not set.")

print("[NTR Persistence Phase 10 Audit] PASS: layout/modal source patch is installed.")
