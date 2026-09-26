-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer client catalogue build, freeze and revisioned snapshot. Extracted verbatim from the GarageServer controller closure
-- (architecture P5); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local PREVIEW_POS = ctx.PREVIEW_POS
	local categoriesRoot = ctx.categoriesRoot
	local cosmeticCatalog = ctx.cosmeticCatalog
	local findSourceCockpit = ctx.findSourceCockpit
	local garageServer_number = ctx.garageServer_number
	local garageServer_string = ctx.garageServer_string
	local modulePurchasePrice = ctx.modulePurchasePrice
	local moduleSourceCockpitId = ctx.moduleSourceCockpitId
	local moduleTypeForModel = ctx.moduleTypeForModel
	local moduleTypeFromText = ctx.moduleTypeFromText
	local moduleUpgrades = ctx.moduleUpgrades
	local moduleVariantName = ctx.moduleVariantName
	local moduleVariantOrder = ctx.moduleVariantOrder
	local primitiveAttributes = ctx.primitiveAttributes
	local slug = ctx.slug
	local function defaultSlots(cockpit)
		local slots = {}
		local root = cockpit and cockpit:FindFirstChild("ModuleSlots", true)
		if root then
			for _, slot in ipairs(root:GetChildren()) do
				if slot:IsA("Folder") or slot:IsA("Model") or slot:IsA("BasePart") then
					local slotId = string.gsub(slot.Name, "^SLOT_", "")
					table.insert(slots, {
						SlotId = garageServer_string(slot, "SlotId", slotId),
						DisplayName = garageServer_string(slot, "DisplayName", slotId),
						ModuleType = garageServer_string(slot, "ModuleType", moduleTypeFromText(slotId)),
						AllowedModuleFolder = garageServer_string(slot, "AllowedModuleFolder", ""),
						EnginePosition = garageServer_string(slot, "EnginePosition", ""),
						Order = garageServer_number(slot, "Order", #slots + 1),
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

	local function nearestModuleFolder(root, item)
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

	local function moduleCatalogVisible(item)
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

	local function readModule(item, root)
		local moduleType = moduleTypeForModel(item, root)
		local moduleFolder = garageServer_string(item, "ModuleFolder", nearestModuleFolder(root, item))
		local enginePosition = garageServer_string(item, "EnginePosition", "")
		local rearEngine = item:GetAttribute("RearEngine") == true
		if enginePosition == "" then
			if rearEngine or moduleFolder == "Engines_B" or string.find(tostring(item:GetAttribute("ModuleId") or item.Name or ""), "ENGINE_B", 1, true) then
				enginePosition = "Rear"
			elseif moduleFolder == "Engines" then
				enginePosition = "Front"
			end
		end
		local neonAvailable=false
		local neonFolder=item:FindFirstChild("NEON_OptionalLights",true)
		if neonFolder then
			for _,descendant in ipairs(neonFolder:GetDescendants()) do
				if descendant:IsA("BasePart") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") or descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
					neonAvailable=true
					break
				end
			end
		end
		return {
			ModuleId = garageServer_string(item, "ModuleId", item.Name),
			DisplayName = garageServer_string(item, "DisplayName", garageServer_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = garageServer_string(item, "ModuleSlot", moduleType),
			ModuleFolder = moduleFolder,
			EnginePosition = enginePosition,
			RearEngine = rearEngine or enginePosition == "Rear",
			SourceCockpitId = moduleSourceCockpitId(item),
			SourceCockpitDisplayName = (select(2, findSourceCockpit(nil, item)) and garageServer_string(select(2, findSourceCockpit(nil, item)), "DisplayName", moduleSourceCockpitId(item))) or moduleSourceCockpitId(item),
			VariantName = moduleVariantName(item),
			VariantOrder = moduleVariantOrder(item),
			Price = modulePurchasePrice(item),
			NeonAvailable = neonAvailable,
			NeonPrice = math.max(0, garageServer_number(item, "NeonPrice", 5000)),
			Power = garageServer_number(item, "Power", 0),
			Weight = garageServer_number(item, "Weight", 0),
			TopSpeed = garageServer_number(item, "TopSpeed", 0),
			Acceleration = garageServer_number(item, "Acceleration", 0),
			Handling = garageServer_number(item, "Handling", 0),
			Drift = garageServer_number(item, "Drift", 0),
			Braking = garageServer_number(item, "Braking", 0),
			Boost = garageServer_number(item, "Boost", 0),
			BoostDuration = garageServer_number(item, "BoostDuration", 0),
			BoostRecharge = garageServer_number(item, "BoostRecharge", 0),
			BoostRechargeDelay = garageServer_number(item, "BoostRechargeDelay", 0),
			Upgrades = moduleUpgrades.CatalogForModuleType(moduleType, item),
		}
	end
	local function garageServer_buildCatalog()
		local catalog = {
			Categories = {},
			PaintPresets = {},
			VehicleCosmetics = cosmeticCatalog.List(),
			PreviewPosition = PREVIEW_POS,
		}
		local presetRoot = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
			and game:GetService("ReplicatedStorage"):WaitForChild("Config"):FindFirstChild("UI")
			and game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("UI"):FindFirstChild("PaintPresets")
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

		for _, categoryFolder in ipairs(categoriesRoot:GetChildren()) do
			if categoryFolder:IsA("Folder") or categoryFolder:IsA("Model") then
				local category = primitiveAttributes(categoryFolder)
				category.CategoryId = category.CategoryId or slug(categoryFolder.Name)
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
							local item = primitiveAttributes(cockpit)
							item.CockpitId = item.CockpitId or cockpit.Name
							item.DisplayName = item.DisplayName or cockpit.Name
							item.Price = garageServer_number(cockpit, "Price", 0)
							item.TopSpeed = garageServer_number(cockpit, "TopSpeed", garageServer_number(cockpit, "MaxSpeed", 126))
							item.Acceleration = garageServer_number(cockpit, "Acceleration", 42)
							item.Handling = garageServer_number(cockpit, "Handling", 48)
							item.Drift = garageServer_number(cockpit, "Drift", 46)
							item.Braking = garageServer_number(cockpit, "Braking", 44)
							item.Weight = garageServer_number(cockpit, "Weight", 118)
							item.Boost = garageServer_number(cockpit, "Boost", 0)
							table.insert(category.Cockpits, item)
						end
					end
				end
				category.Slots = defaultSlots(firstCockpit)

				local moduleRoot = categoryFolder:FindFirstChild("MODULES_InterchangeableWithinCategory")
				if moduleRoot then
					for _, module in ipairs(moduleRoot:GetDescendants()) do
						if module:IsA("Model") and module:GetAttribute("ModuleId") and moduleCatalogVisible(module) then
							local item = readModule(module, moduleRoot)
							category.Modules[item.ModuleType] = category.Modules[item.ModuleType] or {}
							table.insert(category.Modules[item.ModuleType], item)
						end
					end
				end
				local upgradeRoot = categoryFolder:FindFirstChild("UPGRADES_InvisiblePerformance")
				if upgradeRoot then
					for _, upgrade in ipairs(upgradeRoot:GetChildren()) do
						table.insert(category.Upgrades, primitiveAttributes(upgrade))
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

	local catalogueSnapshot
	local catalogueRevision=game:GetService("HttpService"):GenerateGUID(false)
	local function freezeCatalogue(value)
		for _,v in pairs(value) do if type(v)=="table" then freezeCatalogue(v) end end
		return table.freeze(value)
	end
	local function garageServer_catalog(knownRevision)
		if not catalogueSnapshot then catalogueSnapshot=freezeCatalogue(garageServer_buildCatalog()) end
		if knownRevision==catalogueRevision then return nil,catalogueRevision end
		return catalogueSnapshot,catalogueRevision
	end

	return garageServer_catalog
end
