-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer cockpit/module template lookup, module metadata, pricing and slot fit. Extracted verbatim from the GarageServer controller closure
-- (architecture P5); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local categoriesRoot = ctx.categoriesRoot
	local garageServer_number = ctx.garageServer_number
	local garageServer_string = ctx.garageServer_string
	local function slug(name)
		name = string.lower(tostring(name or ""))
		name = string.gsub(name, "%s+", "_")
		name = string.gsub(name, "[^%w_]", "")
		return name
	end

	local function garageServer_categoryFolder(categoryId)
		for _, category in ipairs(categoriesRoot:GetChildren()) do
			if category:GetAttribute("CategoryId") == categoryId
				or category.Name == categoryId
				or string.lower(category.Name) == string.lower(tostring(categoryId)) then
				return category
			end
		end
		return categoriesRoot:GetChildren()[1]
	end

	local function findByAttribute(root, attr, value)
		if not root then return nil end
		for _, item in ipairs(root:GetDescendants()) do
			if item:GetAttribute(attr) == value then return item end
		end
	end

	local function findCockpit(categoryId, cockpitId)
		local category = garageServer_categoryFolder(categoryId)
		local root = category and (category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS"))
		return findByAttribute(root or category, "CockpitId", cockpitId)
	end

	local function findModule(categoryId, moduleId)
		local category = garageServer_categoryFolder(categoryId)
		local root = category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
		return findByAttribute(root, "ModuleId", moduleId)
	end

	local function moduleSourceCockpitId(module)
		if not module then return nil end
		local explicit = module:GetAttribute("SourceCockpitId")
		if explicit ~= nil and tostring(explicit) ~= "" then
			return tostring(explicit)
		end
		local item = module.Parent
		while item and item ~= categoriesRoot do
			local name = tostring(item.Name or "")
			local numberText = string.match(name, "^Bruiser[_%s%-]*(%d+)$") or string.match(name, "BRUISER[_%s%-]*(%d+)")
			if numberText then
				return "bruiser_" .. string.format("%02d", tonumber(numberText) or 0)
			end
			item = item.Parent
		end
		local moduleId = tostring(module:GetAttribute("ModuleId") or module.Name or "")
		local numberText = string.match(moduleId, "BRUISER_(%d+)")
		if numberText then
			return "bruiser_" .. string.format("%02d", tonumber(numberText) or 0)
		end
		return nil
	end

	local function moduleVariantName(module)
		local explicit = module and module:GetAttribute("VariantName")
		if explicit ~= nil and tostring(explicit) ~= "" then
			return tostring(explicit)
		end
		local text = string.upper(tostring(module and (module:GetAttribute("ModuleId") or module.Name) or ""))
		if string.find(text, "LIGHTWEIGHT", 1, true) then return "Lightweight" end
		if string.find(text, "POWER", 1, true) then return "Power" end
		local level = string.match(text, "LVL(%d+)") or string.match(text, "LEVEL(%d+)")
		if level then return "Level " .. tostring(level) end
		if string.find(text, "STANDARD", 1, true) then return "Standard" end
		return "Standard"
	end

	local function moduleVariantOrder(module)
		local explicit = module and tonumber(module:GetAttribute("VariantOrder"))
		if explicit then return explicit end
		local variant = string.lower(moduleVariantName(module))
		if variant == "standard" then return 10 end
		if variant == "lightweight" then return 20 end
		if variant == "power" then return 30 end
		local level = tonumber(string.match(variant, "(%d+)"))
		if level then return 100 + level end
		return 999
	end

	local function findSourceCockpit(profile, module)
		local sourceCockpitId = moduleSourceCockpitId(module)
		if not sourceCockpitId then return nil, nil end
		return sourceCockpitId, findCockpit(profile and profile.CurrentCategory or "bruiser", sourceCockpitId)
	end

	local function playerOwnsSourceCockpit(profile, module)
		local sourceCockpitId = moduleSourceCockpitId(module)
		if not sourceCockpitId then return true, nil end
		if profile and profile.OwnedCockpits and profile.OwnedCockpits[sourceCockpitId] == true then
			return true, sourceCockpitId
		end
		for _, instance in pairs((profile and profile.OwnedCockpitInstances) or {}) do
			if tostring(instance.TemplateId or "") == sourceCockpitId then
				return true, sourceCockpitId
			end
		end
		return false, sourceCockpitId
	end

	local function modulePurchasePrice(module)
		if not module then return 0 end
		local explicit = tonumber(module:GetAttribute("ExtraCopyPrice") or module:GetAttribute("ModuleCopyPrice") or module:GetAttribute("PurchasePrice"))
		if explicit and explicit > 0 then
			return math.floor(explicit)
		end
		local price = garageServer_number(module, "Price", 0)
		if price > 0 then return price end
		local sourceCockpitId = moduleSourceCockpitId(module)
		local cockpit = sourceCockpitId and findCockpit("bruiser", sourceCockpitId)
		local cockpitPrice = cockpit and garageServer_number(cockpit, "Price", 0) or 0
		return math.max(1000, math.floor(cockpitPrice * 0.12))
	end

	local function moduleLockedMessage(profile, module)
		local ownsSource, sourceCockpitId = playerOwnsSourceCockpit(profile, module)
		if ownsSource then return nil end
		local cockpit = sourceCockpitId and findCockpit(profile.CurrentCategory, sourceCockpitId)
		local cockpitName = cockpit and garageServer_string(cockpit, "DisplayName", sourceCockpitId) or sourceCockpitId or "the source cockpit"
		return "Buy " .. cockpitName .. " before buying this module family."
	end
	local function moduleEnginePosition(moduleModel)
		if not moduleModel then return "" end
		local explicit = tostring(moduleModel:GetAttribute("EnginePosition") or "")
		if explicit == "Front" or explicit == "Rear" then
			return explicit
		end
		local moduleFolder = garageServer_string(moduleModel, "ModuleFolder", "")
		local moduleId = tostring(moduleModel:GetAttribute("ModuleId") or moduleModel.Name or "")
		local displayName = string.lower(tostring(moduleModel:GetAttribute("DisplayName") or moduleModel.Name or ""))
		if moduleModel:GetAttribute("RearEngine") == true then
			return "Rear"
		end
		if moduleFolder == "Engines_B" then
			return "Rear"
		end
		if string.find(moduleId, "ENGINE_B", 1, true) ~= nil then
			return "Rear"
		end
		if string.find(displayName, "rear", 1, true) ~= nil then
			return "Rear"
		end
		if moduleFolder == "Engines" then
			return "Front"
		end
		return ""
	end
	local function moduleTypeFromText(text)
		text = string.lower(tostring(text or ""))
		if string.find(text, "engine", 1, true) then return "Engine" end
		if string.find(text, "boost", 1, true) then return "Boost" end
		if string.find(text, "stabiliser", 1, true) or string.find(text, "stabilizer", 1, true) then return "Stabilisers" end
		if string.find(text, "front", 1, true) and string.find(text, "bumper", 1, true) then return "FrontBumper" end
		if string.find(text, "rear", 1, true) and string.find(text, "bumper", 1, true) then return "RearBumper" end
		if string.find(text, "spoiler", 1, true) then return "RearSpoiler" end
		if string.find(text, "side", 1, true) then return "SidePods" end
		return "Misc"
	end

	local function moduleTypeForModel(module, root)
		if not module then return "Misc" end
		local attr = module:GetAttribute("ModuleType")
		if typeof(attr) == "string" and attr ~= "" then
			return attr
		end
		local text = module.Name
		local parent = module.Parent
		while parent and parent ~= root do
			text ..= " " .. parent.Name
			parent = parent.Parent
		end
		return moduleTypeFromText(text)
	end

	local function moduleFitsSlot(moduleModel, slotId, allowedModuleFolder)
		if not moduleModel then return false end
		local moduleFolder = garageServer_string(moduleModel, "ModuleFolder", "")
		local enginePosition = moduleEnginePosition(moduleModel)
		if slotId == "Engine1" then
			return enginePosition ~= "Rear"
		end
		if slotId == "Engine2" then
			return enginePosition == "Rear"
		end
		if allowedModuleFolder and allowedModuleFolder ~= "" then
			return moduleFolder == allowedModuleFolder
		end
		return true
	end
	return slug, garageServer_categoryFolder, findCockpit, findModule, moduleSourceCockpitId, moduleVariantName, moduleVariantOrder, findSourceCockpit, modulePurchasePrice, moduleLockedMessage, moduleTypeFromText, moduleTypeForModel, moduleFitsSlot
end
