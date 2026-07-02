-- Persistence Phase 17 garage server catalog repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if the line-1445 audit says:
--
--   WARNING: missing V56_catalog definition
--
-- GetInitial returns Catalog = V56_catalog(), so losing this helper makes the
-- dealership/garage UI fail before the Phase 17 smoke can inspect modules.
-- This repair restores the compact catalog helper family before
-- V56_totalStats/V56_profileForClient.

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 17 Garage Server Catalog Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local source = garage.Source
assert(findPlain(source, "Catalog = V56_catalog()"), "Expected GetInitial to call V56_catalog().")
assert(findPlain(source, "local function V56_profileForClient(profile)"), "Expected V56_profileForClient anchor.")

if findPlain(source, "local function V56_catalog()") then
	garage:SetAttribute("PersistencePhase17CatalogRepair", "AlreadyPresent")
	info("PASS: V56_catalog already exists; no source change was needed.")
else
	local insertAt = findPlain(source, "\n\tlocal function V56_totalStats(profile)\n")
	if not insertAt then
		insertAt = findPlain(source, "\n\tlocal function V56_profileForClient(profile)\n")
	end
	assert(insertAt, "Could not find V56_totalStats or V56_profileForClient insertion anchor.")

	local catalogBlock = [=[

	-- NTR_PERSISTENCE_PHASE17_CATALOG_REPAIR
	local function V56_defaultSlots(cockpit)
		local slots = {}
		local root = cockpit and cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
		if root then
			for _, slot in ipairs(root:GetChildren()) do
				if slot:IsA("Folder") or slot:IsA("Model") or slot:IsA("BasePart") then
					local slotId = string.gsub(slot.Name, "^SLOT_", "")
					table.insert(slots, {
						SlotId = V56_string(slot, "SlotId", slotId),
						DisplayName = V56_string(slot, "DisplayName", slotId),
						ModuleType = V56_string(slot, "ModuleType", V56_moduleTypeFromText(slotId)),
						AllowedModuleFolder = V56_string(slot, "AllowedModuleFolder", ""),
						EnginePosition = V56_string(slot, "EnginePosition", ""),
						Order = V56_number(slot, "Order", #slots + 1),
					})
				end
			end
		end
		if #slots == 0 then
			slots = {
				{ SlotId = "Engine1", DisplayName = "Front Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines", EnginePosition = "Front", Order = 1 },
				{ SlotId = "Engine2", DisplayName = "Rear Engine", ModuleType = "Engine", AllowedModuleFolder = "Engines_B", EnginePosition = "Rear", Order = 2 },
				{ SlotId = "Stabilisers", DisplayName = "Stabilisers", ModuleType = "Stabilisers", Order = 3 },
				{ SlotId = "Boost", DisplayName = "Boost", ModuleType = "Boost", Order = 4 },
				{ SlotId = "FrontBumper", DisplayName = "Front Bumper", ModuleType = "FrontBumper", Order = 5 },
				{ SlotId = "RearBumper", DisplayName = "Rear Bumper", ModuleType = "RearBumper", Order = 6 },
				{ SlotId = "RearSpoiler", DisplayName = "Rear Spoiler", ModuleType = "RearSpoiler", Order = 7 },
				{ SlotId = "SidePods", DisplayName = "Side Pods", ModuleType = "SidePods", Order = 8 },
			}
		end
		table.sort(slots, function(a, b)
			return (tonumber(a.Order) or 99) < (tonumber(b.Order) or 99)
		end)
		return slots
	end

	local function V56_nearestModuleFolder(root, item)
		local current = item and item.Parent
		local best = ""
		while current and current ~= root do
			if current:IsA("Folder") then
				best = current.Name
			end
			current = current.Parent
		end
		return best
	end

	local function V56_moduleCatalogVisible(item)
		if item:GetAttribute("RetiredFromCatalog") == true then
			return false
		end
		if item:GetAttribute("HiddenFromCatalog") == true then
			return false
		end
		if item:GetAttribute("CatalogVisible") == false then
			return false
		end
		return true
	end

	local function V56_readModule(item, root)
		local moduleType = V56_moduleTypeForModel(item, root)
		local moduleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item))
		local enginePosition = V56_string(item, "EnginePosition", "")
		local rearEngine = item:GetAttribute("RearEngine") == true
		if enginePosition == "" then
			if rearEngine or moduleFolder == "Engines_B" or string.find(tostring(item:GetAttribute("ModuleId") or item.Name or ""), "ENGINE_B", 1, true) then
				enginePosition = "Rear"
			elseif moduleFolder == "Engines" then
				enginePosition = "Front"
			end
		end
		return {
			ModuleId = V56_string(item, "ModuleId", item.Name),
			DisplayName = V56_string(item, "DisplayName", V56_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = V56_string(item, "ModuleSlot", moduleType),
			ModuleFolder = moduleFolder,
			EnginePosition = enginePosition,
			RearEngine = rearEngine or enginePosition == "Rear",
			SourceCockpitId = V85_moduleSourceCockpitId(item),
			SourceCockpitDisplayName = (select(2, V85_findSourceCockpit(nil, item)) and V56_string(select(2, V85_findSourceCockpit(nil, item)), "DisplayName", V85_moduleSourceCockpitId(item))) or V85_moduleSourceCockpitId(item),
			VariantName = V85_moduleVariantName(item),
			VariantOrder = V85_moduleVariantOrder(item),
			Price = V85_modulePurchasePrice(item),
			Power = V56_number(item, "Power", 0),
			Weight = V56_number(item, "Weight", 0),
			TopSpeed = V56_number(item, "TopSpeed", 0),
			Acceleration = V56_number(item, "Acceleration", 0),
			Handling = V56_number(item, "Handling", 0),
			Drift = V56_number(item, "Drift", 0),
			Braking = V56_number(item, "Braking", 0),
			Boost = V56_number(item, "Boost", 0),
			BoostDuration = V56_number(item, "BoostDuration", 0),
			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			BoostRechargeDelay = V56_number(item, "BoostRechargeDelay", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),
		}
	end

	local function V56_catalog()
		local catalog = {
			Categories = {},
			PaintPresets = {},
			PreviewPosition = V56_PREVIEW_POS,
		}
		local presetRoot = V56_kit:FindFirstChild("Config")
			and V56_kit.Config:FindFirstChild("UI")
			and V56_kit.Config.UI:FindFirstChild("PaintPresets")
		if presetRoot then
			for _, preset in ipairs(presetRoot:GetChildren()) do
				if preset:IsA("Color3Value") then
					table.insert(catalog.PaintPresets, { Name = preset.Name, Color = preset.Value })
				end
			end
		end
		if #catalog.PaintPresets == 0 then
			catalog.PaintPresets = {
				{ Name = "Cyan", Color = Color3.fromRGB(0, 205, 230) },
				{ Name = "White", Color = Color3.fromRGB(252, 250, 255) },
				{ Name = "Graphite", Color = Color3.fromRGB(38, 44, 50) },
				{ Name = "Lime", Color = Color3.fromRGB(172, 255, 197) },
				{ Name = "Red", Color = Color3.fromRGB(225, 56, 70) },
				{ Name = "Amber", Color = Color3.fromRGB(255, 187, 45) },
				{ Name = "Violet", Color = Color3.fromRGB(160, 90, 255) },
				{ Name = "Bone", Color = Color3.fromRGB(235, 247, 204) },
			}
		end

		for _, categoryFolder in ipairs(V56_categoriesRoot:GetChildren()) do
			if categoryFolder:IsA("Folder") or categoryFolder:IsA("Model") then
				local category = V56_primitiveAttributes(categoryFolder)
				category.CategoryId = category.CategoryId or V56_slug(categoryFolder.Name)
				category.DisplayName = category.DisplayName or categoryFolder.Name
				category.Cockpits = {}
				category.Slots = {}
				category.Modules = {}
				category.Upgrades = {}

				local cockpitRoot = categoryFolder:FindFirstChild("COCKPITS_ReplaceAssetsHere") or categoryFolder:FindFirstChild("Cockpits") or categoryFolder:FindFirstChild("COCKPITS")
				local firstCockpit
				if cockpitRoot then
					for _, cockpit in ipairs(cockpitRoot:GetDescendants()) do
						if cockpit:IsA("Model") and cockpit:GetAttribute("CockpitId") then
							firstCockpit = firstCockpit or cockpit
							local item = V56_primitiveAttributes(cockpit)
							item.CockpitId = item.CockpitId or cockpit.Name
							item.DisplayName = item.DisplayName or cockpit.Name
							item.Price = V56_number(cockpit, "Price", 0)
							item.TopSpeed = V56_number(cockpit, "TopSpeed", V56_number(cockpit, "MaxSpeed", 126))
							item.Acceleration = V56_number(cockpit, "Acceleration", 42)
							item.Handling = V56_number(cockpit, "Handling", 48)
							item.Drift = V56_number(cockpit, "Drift", 46)
							item.Braking = V56_number(cockpit, "Braking", 44)
							item.Weight = V56_number(cockpit, "Weight", 118)
							item.Boost = V56_number(cockpit, "Boost", 0)
							table.insert(category.Cockpits, item)
						end
					end
				end
				category.Slots = V56_defaultSlots(firstCockpit)

				local moduleRoot = categoryFolder:FindFirstChild("MODULES_InterchangeableWithinCategory")
				if moduleRoot then
					for _, module in ipairs(moduleRoot:GetDescendants()) do
						if module:IsA("Model") and module:GetAttribute("ModuleId") and V56_moduleCatalogVisible(module) then
							local item = V56_readModule(module, moduleRoot)
							category.Modules[item.ModuleType] = category.Modules[item.ModuleType] or {}
							table.insert(category.Modules[item.ModuleType], item)
						end
					end
				end
				local upgradeRoot = categoryFolder:FindFirstChild("UPGRADES_InvisiblePerformance")
				if upgradeRoot then
					for _, upgrade in ipairs(upgradeRoot:GetChildren()) do
						table.insert(category.Upgrades, V56_primitiveAttributes(upgrade))
					end
				end
				table.sort(category.Cockpits, function(a, b)
					return tostring(a.DisplayName) < tostring(b.DisplayName)
				end)
				if #category.Cockpits > 0 then
					table.insert(catalog.Categories, category)
				end
			end
		end
		table.sort(catalog.Categories, function(a, b)
			return tostring(a.DisplayName) < tostring(b.DisplayName)
		end)
		return catalog
	end
]=]

	source = string.sub(source, 1, insertAt - 1) .. catalogBlock .. string.sub(source, insertAt)
	garage.Source = source
	garage:SetAttribute("PersistencePhase17CatalogRepair", true)
end

local finalSource = garage.Source
assert(findPlain(finalSource, "local function V56_catalog()"), "V56_catalog is still missing after repair.")
assert(findPlain(finalSource, "local function V56_readModule(item, root)"), "V56_readModule is still missing after repair.")
assert(findPlain(finalSource, "local function V56_defaultSlots(cockpit)"), "V56_defaultSlots is still missing after repair.")
assert(findPlain(finalSource, "local function V56_profileForClient(profile)"), "V56_profileForClient missing after repair.")

info("PASS: V56_catalog and its helper family are present.")
info("Next: stop Play, start a fresh Play session, then rerun scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
