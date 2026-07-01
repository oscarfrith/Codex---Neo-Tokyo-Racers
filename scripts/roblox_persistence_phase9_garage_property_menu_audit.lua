-- Neo Tokyo Racers - Persistence Phase 9 source audit
-- Run from Roblox Studio Command Bar in Edit mode or Play mode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
assert(kit, "Missing ReplicatedStorage.NeoTokyoRacers.")

local catalog = kit:FindFirstChild("Shared")
	and kit.Shared:FindFirstChild("Modules")
	and kit.Shared.Modules:FindFirstChild("Data")
	and kit.Shared.Modules.Data:FindFirstChild("GaragePropertyCatalog")
assert(catalog and catalog:IsA("ModuleScript"), "Missing GaragePropertyCatalog ModuleScript.")

local ok, catalogModule = pcall(require, catalog)
assert(ok, "GaragePropertyCatalog did not require successfully.")
assert(type(catalogModule.List) == "function", "GaragePropertyCatalog.List is missing.")
assert(#catalogModule.List() >= 1, "GaragePropertyCatalog has no properties.")

local bootstrap = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
	and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap and bootstrap:IsA("LocalScript"), "Missing active client bootstrap LocalScript.")

local source = bootstrap.Source
local function mustContain(marker)
	assert(source:find(marker, 1, true), "Missing Phase 9 source marker/text: " .. marker)
end

mustContain("NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN")
mustContain("GaragePropertyShopPopup")
mustContain("BUY MORE")
mustContain("PropertyId")

assert(
	source:find("NTR_phase9OpenGaragePropertyShop", 1, true)
		or source:find("NTRPersistencePhase9.OpenGaragePropertyShop", 1, true),
	"Missing Phase 9 garage property shop opener."
)

assert(bootstrap:GetAttribute("PersistencePhase9GaragePropertyMenu") == true, "Bootstrap attribute PersistencePhase9GaragePropertyMenu was not set.")
assert(catalog:GetAttribute("PersistencePhase9GaragePropertyCatalog") == true, "GaragePropertyCatalog attribute was not set.")

print("[NTR Persistence Phase 9 Audit] PASS: garage property menu source patch and catalogue are installed.")
