-- Neo Tokyo Racers - Persistence Phase 12 source audit
-- Run from Roblox Studio Command Bar in Edit mode after the Phase 12 installer.

local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function assertChild(parent, name)
	local child = parent:FindFirstChild(name)
	assert(child, "Missing " .. parent:GetFullName() .. "." .. name)
	return child
end

local scriptsFolder = assertChild(StarterPlayer, "StarterPlayerScripts")
local clientRoot = assertChild(scriptsFolder, "NeoTokyoRacersClient")
local bootstrap = assertChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
local moduleScript = assertChild(assertChild(assertChild(clientRoot, "Controllers"), "UI"), "GaragePropertyMenuController")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")
assert(moduleScript:IsA("ModuleScript"), "Expected GaragePropertyMenuController to be a ModuleScript.")

local source = bootstrap.Source
assert(source:find("NTR_PERSISTENCE_PHASE12_GARAGE_MENU_CONTROLLER", 1, true), "Phase 12 marker is missing from the active client bootstrap.")
assert(source:find("script.Parent:WaitForChild(\"Controllers\"):WaitForChild(\"UI\"):WaitForChild(\"GaragePropertyMenuController\")", 1, true), "Bootstrap does not require the garage property menu controller.")
assert(source:find("NTR_PERSISTENCE_PHASE10_GARAGE_UI_LAYOUT_MODAL", 1, true), "Phase 10 layout/modal marker is missing.")
assert(source:find("NTR_PERSISTENCE_PHASE11_GARAGE_SPACES_COCKPIT_ONLY", 1, true), "Phase 11 cockpit-only visibility marker is missing.")
assert(not source:find("function NTRPersistencePhase9.GarageCardThumbnail", 1, true), "Old Phase 9 thumbnail renderer is still in the bootstrap.")
assert(not source:find("function NTRPersistencePhase9.GarageProperties", 1, true), "Old Phase 9 property list renderer is still in the bootstrap.")

local kit = assertChild(ReplicatedStorage, "NeoTokyoRacers")
assertChild(assertChild(assertChild(assertChild(kit, "Shared"), "Modules"), "Data"), "GaragePropertyCatalog")

local ok, controller = pcall(require, moduleScript)
assert(ok, "GaragePropertyMenuController failed to require: " .. tostring(controller))
assert(type(controller.Render) == "function", "GaragePropertyMenuController.Render is missing.")
assert(type(controller.ListProperties) == "function", "GaragePropertyMenuController.ListProperties is missing.")

local properties = controller.ListProperties({ kit = kit })
assert(type(properties) == "table" and #properties >= 1, "GaragePropertyMenuController.ListProperties returned no properties.")

print("[NTR Persistence Phase 12 Audit] PASS: GaragePropertyMenuController exists and requires successfully.")
print("[NTR Persistence Phase 12 Audit] PASS: Active client bootstrap delegates the garage property menu render to the controller.")
print("[NTR Persistence Phase 12 Audit] PASS: Phase 10 modal and Phase 11 cockpit-only visibility markers are still present.")
