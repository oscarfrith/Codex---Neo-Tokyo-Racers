-- Neo Tokyo Racers - Persistence Phase 9 register-limit repair audit
-- Run from Roblox Studio Command Bar in Edit mode or Play mode.

local StarterPlayer = game:GetService("StarterPlayer")

local bootstrap = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
	and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap and bootstrap:IsA("LocalScript"), "Missing active client bootstrap LocalScript.")

local source = bootstrap.Source
assert(source:find("NTR_PERSISTENCE_PHASE9_REGISTER_REPAIR", 1, true), "Phase 9 register-limit repair marker is missing.")
assert(source:find("NTRPersistencePhase9.OpenGaragePropertyShop", 1, true), "Repaired Phase 9 opener is missing.")
assert(source:find("NTRPersistencePhase9.RenderGaragePropertyShop", 1, true), "Repaired Phase 9 renderer is missing.")
assert(not source:find("local function NTR_phase9", 1, true), "Old Phase 9 top-level local helper functions are still present.")
assert(bootstrap:GetAttribute("PersistencePhase9RegisterLimitRepair") == true, "Repair attribute was not set on the bootstrap.")

print("[NTR Persistence Phase 9 Register Repair Audit] PASS: Phase 9 UI helpers are table-owned and should not consume extra top-level local registers.")
