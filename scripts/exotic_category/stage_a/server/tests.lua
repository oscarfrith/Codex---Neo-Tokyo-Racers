-- Exotic category, Stage A, server tests. Studio Edit, pure: no DataModel change, no Play, no gameplay module require.
--
-- Usage (see run_tests.lua for a ready runner):
--   local run = loadstring(testsSource)()
--   local report = run(sources, options)   --> { failures = n, results = { "PASS ...", "FAIL ...: reason" } }
--   sources = { before = { <ScriptName> = <source text> }, after = { <ScriptName> = <source text> } }
--     ScriptName: GarageServer, GarageCatalogLookup, GarageCatalogService, GarageClientProfile, OwnedGarageDisplay,
--     VehicleBuildService, DriverSeatServer. "before" is the capture blob, "after" is after/<ScriptName>.lua.
--   options.liveCategoriesRoot (optional): the real ServerStorage.Assets.Vehicles.Categories folder. Adds read-only
--     old-versus-new parity tests on the live Piercer templates. Nothing is written to it.
--
-- How the code under test is reached:
--   * GarageCatalogLookup, GarageCatalogService and GarageClientProfile are ctx factories. Their real source is
--     loaded with loadstring and given fake dependencies.
--   * GarageServer, OwnedGarageDisplay, VehicleBuildService and DriverSeatServer keep the functions under test as
--     locals inside a start closure, so they cannot be called from outside without restructuring the scripts.
--     The tests cut the exact text of those functions out of the source by anchor lines and compile that text
--     with the surrounding upvalues supplied as an environment (fakes below). The logic that runs is the shipped
--     text, not a copy; only its dependencies are faked. Anchors are asserted, so a moved function fails loudly.
--   * Template instances are Lua-table fakes with the Instance methods the code uses (GetAttribute, GetChildren,
--     GetDescendants, FindFirstChild, IsA, Name, Parent). The optional live tests use the real folder, read-only.
return function(sources, options)
	options = options or {}
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local function eq(actual, expected, label)
		if actual ~= expected then error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
	end

	-- ------------------------------------------------------------------------------------------ helpers
	local function deepEqual(a, b, path)
		path = path or "root"
		if type(a) ~= type(b) then return false, path .. " type " .. type(a) .. " vs " .. type(b) end
		if type(a) ~= "table" then
			if a == b then return true end
			return false, path .. " " .. tostring(a) .. " vs " .. tostring(b)
		end
		for key, value in pairs(a) do
			local ok, where = deepEqual(value, b[key], path .. "." .. tostring(key))
			if not ok then return false, where end
		end
		for key in pairs(b) do
			if a[key] == nil then return false, path .. "." .. tostring(key) .. " missing on the left" end
		end
		return true
	end
	local function assertDeepEqual(a, b, label)
		local ok, where = deepEqual(a, b)
		if not ok then error((label or "tables") .. " differ at " .. tostring(where), 2) end
	end
	local function deepCopy(value)
		if type(value) ~= "table" then return value end
		local copy = {}
		for key, child in pairs(value) do copy[key] = deepCopy(child) end
		return copy
	end
	local function count(dictionary)
		local n = 0
		for _ in pairs(dictionary or {}) do n += 1 end
		return n
	end
	local function slice(source, startAnchor, endAnchor)
		local first = string.find(source, startAnchor, 1, true)
		assert(first, "start anchor missing: " .. startAnchor)
		assert(not string.find(source, startAnchor, first + 1, true), "start anchor not unique: " .. startAnchor)
		local last = string.find(source, endAnchor, first, true)
		assert(last, "end anchor missing: " .. endAnchor)
		return string.sub(source, first, last - 1)
	end
	local function runChunk(text, env, chunkName, parentEnv)
		local fn, err = loadstring(text, chunkName or "slice")
		assert(fn, "compile failed for " .. tostring(chunkName) .. ": " .. tostring(err))
		setfenv(fn, setmetatable(env, { __index = parentEnv or getfenv(0) }))
		return fn()
	end

	-- ---------------------------------------------------------------------------------- fake instances
	local function inst(className, name, attributes, children)
		local self = { ClassName = className, Name = name, Parent = nil }
		local attrs = attributes or {}
		local kids = {}
		function self:GetAttribute(key) return attrs[key] end
		function self:GetAttributes()
			local copy = {}
			for key, value in pairs(attrs) do copy[key] = value end
			return copy
		end
		function self:GetChildren() return table.clone(kids) end
		function self:GetDescendants()
			local list = {}
			local function walk(node)
				for _, child in ipairs(node:GetChildren()) do
					table.insert(list, child)
					walk(child)
				end
			end
			walk(self)
			return list
		end
		function self:FindFirstChild(childName, recursive)
			for _, child in ipairs(kids) do
				if child.Name == childName then return child end
			end
			if recursive then
				for _, child in ipairs(kids) do
					local found = child:FindFirstChild(childName, true)
					if found then return found end
				end
			end
			return nil
		end
		function self:WaitForChild(childName) return self:FindFirstChild(childName) end
		function self:IsA(class)
			if class == className or class == "Instance" then return true end
			if class == "BasePart" then return className == "Part" or className == "Seat" or className == "VehicleSeat" end
			if class == "ValueBase" then return className == "NumberValue" or className == "BoolValue" or className == "StringValue" end
			return false
		end
		-- Test-only helpers (not Instance API).
		function self:_set(key, value) attrs[key] = value end
		function self:_add(child, index)
			child.Parent = self
			if index then table.insert(kids, index, child) else table.insert(kids, child) end
			return child
		end
		for _, child in ipairs(children or {}) do self:_add(child) end
		return self
	end

	local function slotFolder(slotId, displayName, moduleType, allowedFolder, order, extra)
		local attributes = { SlotId = slotId, DisplayName = displayName, ModuleType = moduleType, AllowedModuleFolder = allowedFolder, Order = order, FixedSlot = true, CountLabel = displayName }
		for key, value in pairs(extra or {}) do attributes[key] = value end
		return inst("Folder", "SLOT_" .. slotId, attributes, { inst("Part", "Mount_DoNotRename", { TemplateRole = "FixedSlotMount" }) })
	end

	local function moduleModel(moduleId, attributes)
		attributes.ModuleId = moduleId
		attributes.V2Materialised = true
		return inst("Model", moduleId, attributes, { inst("Part", "ModuleRoot_DoNotRename") })
	end

	-- A Piercer-like category: the live attribute names and shapes, two families (01, 06) plus one accessory.
	local function piercerCategory()
		local function slots()
			return inst("Folder", "ModuleSlots", nil, {
				slotFolder("Boost", "Boost", "Boost", "Boost", 4),
				slotFolder("Engine1", "Front Engine", "Engine", "Engines", 1, { EnginePosition = "Front" }),
				slotFolder("Engine2", "Rear Engine", "Engine", "Engines_B", 2, { EnginePosition = "Rear" }),
				slotFolder("FrontBumper", "Front Bumper", "FrontBumper", "FrontBumpers", 5),
				slotFolder("RearBumper", "Rear Bumper", "RearBumper", "RearBumpers", 6),
				slotFolder("RearSpoiler", "Rear Spoiler", "RearSpoiler", "RearSpoilers", 7),
				slotFolder("SidePods", "Side Pods", "SidePods", "SidePods", 8),
				slotFolder("Stabilisers", "Stabilisers", "Stabilisers", "Stabilisers", 3),
			})
		end
		local function cockpit(n, displayName, price, tier)
			return inst("Model", "COCKPIT_BRUISER_" .. n, {
				CockpitId = "bruiser_" .. n, CategoryId = "bruiser", DisplayName = displayName, Price = price, Tier = tier, V2Materialised = true,
				DefaultBoostModuleId = "MODULE_BOOST_BRUISER_" .. n .. "_STANDARD",
				DefaultEngineBModuleId = "MODULE_ENGINE_B_BRUISER_" .. n .. "_STANDARD",
				DefaultEngineModuleId = "MODULE_ENGINE_BRUISER_" .. n .. "_STANDARD",
				DefaultFrontEngineModuleId = "MODULE_ENGINE_BRUISER_" .. n .. "_STANDARD",
				DefaultRearEngineModuleId = "MODULE_ENGINE_B_BRUISER_" .. n .. "_STANDARD",
				DefaultStabiliserModuleId = "MODULE_STABILISER_BRUISER_" .. n .. "_STANDARD",
				DefaultStabilisersModuleId = "MODULE_STABILISER_BRUISER_" .. n .. "_STANDARD",
				DefaultPrimaryColor = Color3.new(0, 0.5, 0.5),
			}, { inst("Folder", "INSTALLED_MODULES_Runtime"), slots(), inst("Part", "CockpitRoot_DoNotRename") })
		end
		local function family(n)
			local source = "bruiser_" .. n
			return {
				engine = moduleModel("MODULE_ENGINE_BRUISER_" .. n .. "_STANDARD", { CategoryId = "bruiser", ModuleType = "Engine", ModuleFolder = "Engines", EnginePosition = "Front", RearEngine = false, SourceCockpitId = source, Price = 0, PurchasePrice = 0, VariantName = "Standard", VariantOrder = 10, DisplayName = "Engine " .. n }),
				engineLight = moduleModel("MODULE_ENGINE_BRUISER_" .. n .. "_LIGHTWEIGHT", { CategoryId = "bruiser", ModuleType = "Engine", ModuleFolder = "Engines", EnginePosition = "Front", RearEngine = false, SourceCockpitId = source, Price = 0, VariantName = "Lightweight", VariantOrder = 20, DisplayName = "Light Engine " .. n }),
				engineB = moduleModel("MODULE_ENGINE_B_BRUISER_" .. n .. "_STANDARD", { CategoryId = "bruiser", ModuleType = "Engine", ModuleFolder = "Engines_B", EnginePosition = "Rear", RearEngine = true, SourceCockpitId = source, Price = 0, PurchasePrice = 0, VariantOrder = 10, DisplayName = "Rear Engine " .. n }),
				stabiliser = moduleModel("MODULE_STABILISER_BRUISER_" .. n .. "_STANDARD", { CategoryId = "bruiser", ModuleType = "Stabilisers", ModuleFolder = "Stabilisers", SourceCockpitId = source, Price = 0, PurchasePrice = 0, VariantOrder = 10, DisplayName = "Stabiliser " .. n }),
				boost = moduleModel("MODULE_BOOST_BRUISER_" .. n .. "_STANDARD", { CategoryId = "bruiser", ModuleType = "Boost", ModuleFolder = "Boost", SourceCockpitId = source, Price = 0, PurchasePrice = 0, VariantOrder = 10, DisplayName = "Boost " .. n }),
			}
		end
		local f1, f2, f6 = family("01"), family("02"), family("06")
		return inst("Folder", "PIERCER", { CategoryId = "bruiser", DisplayName = "Piercer", Description = "Heavy compact hover frames." }, {
			inst("Folder", "COCKPITS_ReplaceAssetsHere", nil, { cockpit("01", "Viper", 350000, "C"), cockpit("02", "Forge", 40000, "E"), cockpit("06", "Zenith", 10000000, "S") }),
			inst("Folder", "MODULES_InterchangeableWithinCategory", nil, {
				inst("Folder", "Engines", nil, { inst("Folder", "Bruiser_01", nil, { f1.engine, f1.engineLight }), inst("Folder", "Bruiser_02", nil, { f2.engine, f2.engineLight }), inst("Folder", "Bruiser_06", nil, { f6.engine, f6.engineLight }) }),
				inst("Folder", "Engines_B", nil, { f1.engineB, f2.engineB, f6.engineB }),
				inst("Folder", "Stabilisers", nil, { f1.stabiliser, f2.stabiliser, f6.stabiliser }),
				inst("Folder", "Boost", nil, { f1.boost, f2.boost, f6.boost }),
				inst("Folder", "SidePods", nil, { moduleModel("MODULE_SIDEPODS_LVL1", { CategoryId = "bruiser", ModuleType = "SidePods", ModuleFolder = "SidePods", Price = 6000, DisplayName = "Side Pods L1" }) }),
				inst("Folder", "FrontBumpers", nil, { moduleModel("MODULE_FRONTBUMPER_LVL1", { CategoryId = "bruiser", ModuleType = "FrontBumper", ModuleFolder = "FrontBumpers", Price = 5000, DisplayName = "Front Bumper L1" }) }),
			}),
			inst("Folder", "UPGRADES_InvisiblePerformance"),
		})
	end

	-- An Exotic-like category as INTERFACE.md describes it: ten slots with RailLabel, ten defaults, CardTitle on modules.
	local EXOTIC_SLOTS = {
		{ "Engine1", "Main Turbine", "Engine", "Engines", 1, { EnginePosition = "Front" } },
		{ "Engine2", "Side Engines", "Engine", "Engines_B", 2, { EnginePosition = "Rear" } },
		{ "Stabilisers", "Stabilisers", "Stabilisers", "Stabilisers", 3 },
		{ "Boost", "Afterburner", "Boost", "Boost", 4 },
		{ "FrontBumper", "Splitter", "FrontBumper", "FrontBumpers", 5 },
		{ "RearBumper", "Diffuser", "RearBumper", "RearBumpers", 6 },
		{ "RearSpoiler", "Wing", "RearSpoiler", "RearSpoilers", 7 },
		{ "SidePods", "Side Pods", "SidePods", "SidePods", 8 },
		{ "FrontBody", "Nose", "FrontBody", "FrontBodies", 9 },
		{ "RearBody", "Engine Deck", "RearBody", "RearBodies", 10 },
	}
	local EXOTIC_BODY = {
		FrontBody = "MODULE_FRONTBODY_EXOTIC_03", RearBody = "MODULE_REARBODY_EXOTIC_03", SidePods = "MODULE_SIDEPODS_EXOTIC_03",
		FrontBumper = "MODULE_FRONTBUMPER_EXOTIC_03", RearBumper = "MODULE_REARBUMPER_EXOTIC_03", RearSpoiler = "MODULE_REARSPOILER_EXOTIC_03",
	}
	local function exoticCategory()
		local slotList = {}
		for _, row in ipairs(EXOTIC_SLOTS) do
			local extra = { RailLabel = row[2] }
			for key, value in pairs(row[6] or {}) do extra[key] = value end
			table.insert(slotList, slotFolder(row[1], row[2], row[3], row[4], row[5], extra))
		end
		local cockpitAttributes = {
			CockpitId = "exotic_03", CategoryId = "exotic", DisplayName = "Wedge", Price = 440000, Tier = "C", V2Materialised = true,
			DefaultEngineModuleId = "MODULE_ENGINE_EXOTIC_03_STANDARD", DefaultFrontEngineModuleId = "MODULE_ENGINE_EXOTIC_03_STANDARD",
			DefaultRearEngineModuleId = "MODULE_ENGINE_B_EXOTIC_03_STANDARD", DefaultEngineBModuleId = "MODULE_ENGINE_B_EXOTIC_03_STANDARD",
			DefaultStabilisersModuleId = "MODULE_STABILISER_EXOTIC_03_STANDARD", DefaultStabiliserModuleId = "MODULE_STABILISER_EXOTIC_03_STANDARD",
			DefaultBoostModuleId = "MODULE_BOOST_EXOTIC_03_STANDARD",
			DriverSeatOffsetX = -1.8, DriverSeatOffsetY = 0.25, DriverSeatOffsetZ = 0.45,
			PassengerSeatOffsetX = 1.8, PassengerSeatOffsetY = 0.25, PassengerSeatOffsetZ = 0.45,
		}
		for slotId, moduleId in pairs(EXOTIC_BODY) do cockpitAttributes["Default" .. slotId .. "ModuleId"] = moduleId end
		local cockpit = inst("Model", "COCKPIT_EXOTIC_03", cockpitAttributes, { inst("Folder", "INSTALLED_MODULES_Runtime"), inst("Folder", "ModuleSlots", nil, slotList), inst("Part", "CockpitRoot_DoNotRename") })
		local function core(moduleId, moduleType, folder, extra)
			local attributes = { CategoryId = "exotic", ModuleType = moduleType, ModuleFolder = folder, SourceCockpitId = "exotic_03", Price = 0, PurchasePrice = 0, VariantName = "Standard", VariantOrder = 10, DisplayName = moduleId, CardTitle = "Card " .. moduleId }
			for key, value in pairs(extra or {}) do attributes[key] = value end
			return moduleModel(moduleId, attributes)
		end
		local function body(slotId, folder, price)
			return moduleModel(EXOTIC_BODY[slotId], { CategoryId = "exotic", ModuleType = slotId, ModuleFolder = folder, Price = price, DisplayName = "Body " .. slotId, CardTitle = "Body " .. slotId })
		end
		return inst("Folder", "EXOTIC", { CategoryId = "exotic", DisplayName = "Exotic", FeatureFlag = "VehicleClass_exotic" }, {
			inst("Folder", "COCKPITS_ReplaceAssetsHere", nil, { cockpit }),
			inst("Folder", "MODULES_InterchangeableWithinCategory", nil, {
				inst("Folder", "Engines", nil, { inst("Folder", "Exotic_03", nil, {
					core("MODULE_ENGINE_EXOTIC_03_STANDARD", "Engine", "Engines", { EnginePosition = "Front", RearEngine = false }),
					core("MODULE_ENGINE_EXOTIC_03_POWER", "Engine", "Engines", { EnginePosition = "Front", RearEngine = false, Price = 52800, PurchasePrice = 52800, VariantName = "Power", VariantOrder = 30 }),
					core("MODULE_ENGINE_EXOTIC_03_NOPRICE", "Engine", "Engines", { EnginePosition = "Front", RearEngine = false, VariantName = "Lightweight", VariantOrder = 20 }),
				}) }),
				inst("Folder", "Engines_B", nil, { inst("Folder", "Exotic_03", nil, { core("MODULE_ENGINE_B_EXOTIC_03_STANDARD", "Engine", "Engines_B", { EnginePosition = "Rear", RearEngine = true }) }) }),
				inst("Folder", "Stabilisers", nil, { inst("Folder", "Exotic_03", nil, { core("MODULE_STABILISER_EXOTIC_03_STANDARD", "Stabilisers", "Stabilisers") }) }),
				inst("Folder", "Boost", nil, { inst("Folder", "Exotic_03", nil, { core("MODULE_BOOST_EXOTIC_03_STANDARD", "Boost", "Boost") }) }),
				inst("Folder", "FrontBodies", nil, { body("FrontBody", "FrontBodies", 14000) }),
				inst("Folder", "RearBodies", nil, { body("RearBody", "RearBodies", 14000) }),
				inst("Folder", "SidePods", nil, { body("SidePods", "SidePods", 14000) }),
				inst("Folder", "FrontBumpers", nil, { body("FrontBumper", "FrontBumpers", 14000) }),
				inst("Folder", "RearBumpers", nil, { body("RearBumper", "RearBumpers", 14000) }),
				inst("Folder", "RearSpoilers", nil, { body("RearSpoiler", "RearSpoilers", 14000) }),
			}),
		}), cockpit
	end

	local function world(withExotic)
		local root = inst("Folder", "Categories", nil, { piercerCategory() })
		local exoticCockpit
		if withExotic then
			local exotic
			exotic, exoticCockpit = exoticCategory()
			root:_add(exotic)
		end
		return root, exoticCockpit
	end

	-- --------------------------------------------------------------------------------- GarageServer harness
	local SERVER_HELPERS_START = "\tlocal function garageServer_value(item, name)"
	local SERVER_HELPERS_END = "\tlocal normalizeProfile, getProfileServiceProfile, getProfile"
	local COLOURS_START = "\tlocal function findCockpitForDefaultColours(categoryId, cockpitId)"
	local COLOURS_END = "\tlocal function setLeaderstats(player, profile)"
	local PURCHASE_START = "\tlocal function generateId(prefix)"
	local PURCHASE_END = "\tlocal function syncLegacyFromCurrentVehicle(profile)"
	local SUMMARY_START = "\tlocal function cloneForSummary(value)"
	local SUMMARY_END = "\tlocal garageServer_catalog = require("

	local function ensureShape(profile) -- same normalisation as GarageModuleInventory.EnsureShape
		for _, key in ipairs({ "Vehicles", "OwnedCockpitInstances", "OwnedModuleInstances", "GarageDisplaySpaces", "OwnedCockpits", "OwnedModules", "InstalledModules", "ModuleUpgradeLevels", "ModuleColors", "NeonOwned" }) do
			profile[key] = typeof(profile[key]) == "table" and profile[key] or {}
		end
		for _, vehicle in pairs(profile.Vehicles) do
			if typeof(vehicle) == "table" then vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {} end
		end
		return true
	end

	local function newProfile(cash)
		local profile = { Cash = cash, CurrentCategory = "bruiser", CurrentCockpit = "bruiser_01", GarageCapacity = 2, CockpitColors = {}, ThrustColor = Color3.new(1, 1, 1), UpgradeLevels = {} }
		ensureShape(profile)
		return profile
	end

	-- Builds the purchase functions of one GarageServer source over one category tree.
	local function garage(version, categoriesRoot, flags)
		local serverSource, lookupSource = sources[version].GarageServer, sources[version].GarageCatalogLookup
		local h = { flagCalls = 0, ledger = {}, transactions = {}, warnings = {}, guid = 0, flags = flags or {} }
		local value, number, str, primitive = runChunk(slice(serverSource, SERVER_HELPERS_START, SERVER_HELPERS_END)
			.. "\nreturn garageServer_value, garageServer_number, garageServer_string, primitiveAttributes", {}, version .. ".GarageServer.helpers")
		h.garageServer_number, h.garageServer_string, h.primitiveAttributes = number, str, primitive
		local lookup = table.pack(assert(loadstring(lookupSource, version .. ".GarageCatalogLookup"))()({ categoriesRoot = categoriesRoot, garageServer_number = number, garageServer_string = str }))
		assert(lookup.n == 13, "GarageCatalogLookup must return 13 values")
		h.lookup = {
			slug = lookup[1], garageServer_categoryFolder = lookup[2], findCockpit = lookup[3], findModule = lookup[4], moduleSourceCockpitId = lookup[5],
			moduleVariantName = lookup[6], moduleVariantOrder = lookup[7], findSourceCockpit = lookup[8], modulePurchasePrice = lookup[9],
			moduleLockedMessage = lookup[10], moduleTypeFromText = lookup[11], moduleTypeForModel = lookup[12], moduleFitsSlot = lookup[13],
		}
		local env = {
			categoriesRoot = categoriesRoot, garageServer_number = number, garageServer_string = str,
			FeatureFlags = { IsEnabled = function(key, default)
				h.flagCalls += 1
				local state = h.flags[key]
				if state == nil then return default == true end
				return state == true
			end },
			MoneyService = { Debit = function(profile, amount, reason)
				profile.Cash -= amount
				table.insert(h.ledger, tostring(reason) .. ":" .. tostring(amount))
			end },
			httpService = { GenerateGUID = function()
				h.guid += 1
				return string.format("%012d-0000-0000", h.guid)
			end },
			os = { time = function() return 1000 end },
			profileGarageCapacity = function(profile) return profile.GarageCapacity or 2 end,
			cosmeticCatalog = { DefaultState = function() return { SchemaVersion = 1 } end },
			moduleInventory = { EnsureShape = ensureShape },
			moduleInstances = { CaptureAll = function() return true end, HydrateAll = function() return true end, Validate = function() return true end },
			moduleUpgrades = { GetLevels = function() return {} end },
			moduleTransactions = {
				BuyAndEquip = function(_, args)
					table.insert(h.transactions, { Template = args.Record.TemplateId, Price = args.Price, VehicleId = args.VehicleId, SlotId = args.SlotId, Source = args.Record.Source })
					return true, "Module purchased and equipped."
				end,
				Equip = function() return true, "Module instance equipped." end,
			},
			warn = function(message) table.insert(h.warnings, tostring(message)) end,
		}
		for key, fn in pairs(h.lookup) do env[key] = fn end
		env.applyDefaultCockpitColors = runChunk(slice(serverSource, COLOURS_START, COLOURS_END) .. "\nreturn applyDefaultCockpitColors", { categoriesRoot = categoriesRoot }, version .. ".GarageServer.colours")
		h.env = env
		local exported = runChunk(slice(serverSource, PURCHASE_START, PURCHASE_END) .. [[

return {
	buyCockpitInstance = buyCockpitInstance, buyModuleInstance = buyModuleInstance, coreSlotRequired = coreSlotRequired,
	defaultModuleIdsForCockpit = defaultModuleIdsForCockpit, defaultSlotModuleIdsForCockpit = defaultSlotModuleIdsForCockpit,
	cockpitDefaultsInstallable = cockpitDefaultsInstallable, categoryFlagEnabled = categoryFlagEnabled, categoryFolderOf = categoryFolderOf,
	instanceFits = instanceFits, coreModulesEquipped = coreModulesEquipped, defaultAlreadyGrantedForVehicle = defaultAlreadyGrantedForVehicle,
}]], env, version .. ".GarageServer.purchase")
		for key, fn in pairs(exported) do h[key] = fn end
		h.attach = env.attachDefaultModuleInstancesToCurrentVehicle
		assert(h.buyCockpitInstance and h.buyModuleInstance and h.coreSlotRequired and h.attach, "purchase functions not found in slice")
		return h
	end

	-- A stable view of a profile for old-versus-new comparison: module instance ids (random in production, and
	-- created in table iteration order) are replaced by vehicle.slot for installed instances.
	local function canonical(profile)
		local view = deepCopy(profile)
		local renamed = {}
		for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
			for slotId, instanceId in pairs(vehicle.InstalledModules or {}) do renamed[instanceId] = vehicleId .. "." .. slotId end
		end
		local instances, spare = {}, {}
		for instanceId, record in pairs(profile.OwnedModuleInstances or {}) do
			if renamed[instanceId] then instances[renamed[instanceId]] = deepCopy(record)
			else spare[tostring(record.TemplateId) .. "|" .. tostring(record.GrantedForVehicleId)] = (spare[tostring(record.TemplateId) .. "|" .. tostring(record.GrantedForVehicleId)] or 0) + 1 end
		end
		view.OwnedModuleInstances = instances
		view.SpareInstances = spare
		for vehicleId, vehicle in pairs(view.Vehicles or {}) do
			for slotId in pairs(vehicle.InstalledModules or {}) do vehicle.InstalledModules[slotId] = vehicleId .. "." .. slotId end
		end
		return view
	end

	-- The fixed Piercer action sequence compared between the old and the new source.
	local function piercerSequence(h, ids)
		local log = {}
		local profile = newProfile(1000000)
		local function step(label, ok, message) table.insert(log, label .. "=" .. tostring(ok) .. "|" .. tostring(message)) end
		step("buy01", h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "bruiser_01" }))
		local firstVehicle = profile.CurrentVehicleId
		step("unaffordable", h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "bruiser_06" }))
		step("unknownCockpit", h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "nope" }))
		step("noArgs", h.buyCockpitInstance(profile, nil))
		step("emptyCategory", h.buyCockpitInstance(profile, { CategoryId = "", CockpitId = "nope" }))
		step("moduleUnknown", h.buyModuleInstance(profile, { ModuleId = "MODULE_NOPE", VehicleId = firstVehicle, SlotId = "SidePods" }))
		step("moduleWrongSlot", h.buyModuleInstance(profile, { ModuleId = ids.sidePods, VehicleId = firstVehicle, SlotId = "Boost" }))
		step("moduleNoSlot", h.buyModuleInstance(profile, { ModuleId = ids.sidePods, VehicleId = firstVehicle, SlotId = "FrontBody" }))
		step("moduleNoVehicle", h.buyModuleInstance(profile, { ModuleId = ids.sidePods, VehicleId = "vehicle_missing", SlotId = "SidePods" }))
		step("moduleLocked", h.buyModuleInstance(profile, { ModuleId = ids.locked, VehicleId = firstVehicle, SlotId = "Engine1" }))
		step("moduleBuy", h.buyModuleInstance(profile, { ModuleId = ids.sidePods, VehicleId = firstVehicle, SlotId = "SidePods" }))
		step("moduleBuyDefaultVehicle", h.buyModuleInstance(profile, { ModuleId = ids.sidePods, SlotId = "SidePods" }))
		step("buy02", h.buyCockpitInstance(profile, { CockpitId = "bruiser_02" })) -- no CategoryId: uses CurrentCategory
		step("garageFull", h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "bruiser_01" }))
		-- Reselect the first vehicle the way selectVehicleInstance does, with one legacy slot emptied.
		profile.CurrentVehicleId = firstVehicle
		profile.CurrentCockpit = "bruiser_01"
		local before = count(profile.OwnedModuleInstances)
		h.attach(profile)
		step("attachNoChange", count(profile.OwnedModuleInstances) == before, "instances " .. count(profile.OwnedModuleInstances))
		profile.Vehicles[firstVehicle].InstalledModules.Engine2 = nil
		h.attach(profile)
		step("attachLegacyRegrant", count(profile.OwnedModuleInstances) == before + 1, "instances " .. count(profile.OwnedModuleInstances))
		for _, slotId in ipairs({ "Engine1", "Engine2", "Stabilisers", "Boost", "SidePods", "FrontBumper", "FrontBody", "RearBody" }) do
			step("core." .. slotId, h.coreSlotRequired(profile, firstVehicle, slotId), "")
		end
		profile.Vehicles[firstVehicle].InstalledModules.Engine2 = nil
		step("core.Engine1.alone", h.coreSlotRequired(profile, firstVehicle, "Engine1"), "")
		return { log = log, profile = canonical(profile), ledger = h.ledger, transactions = h.transactions, flagCalls = h.flagCalls, warnings = h.warnings }
	end
	local FAKE_IDS = { sidePods = "MODULE_SIDEPODS_LVL1", locked = "MODULE_ENGINE_BRUISER_06_LIGHTWEIGHT" }

	-- ==================================================================================== Piercer unchanged
	test("piercer: fixed action sequence gives the same replies, profile, debits and transactions (old vs new)", function()
		local old = piercerSequence(garage("before", (world(false))), FAKE_IDS)
		local new = piercerSequence(garage("after", (world(false))), FAKE_IDS)
		assertDeepEqual(old, new, "sequence")
		local expected = {
			"buy01=true|Cockpit instance purchased.", "unaffordable=false|Not enough cash.", "unknownCockpit=false|Cockpit not found.",
			"noArgs=false|Cockpit not found.", "emptyCategory=false|Cockpit not found.", "moduleUnknown=false|Module not found.",
			"moduleWrongSlot=false|That module does not fit this slot.", "moduleNoSlot=false|Slot not found on this cockpit.",
			"moduleNoVehicle=false|Vehicle instance not found.", "moduleLocked=false|Buy Zenith before buying this module family.",
			"moduleBuy=true|Module purchased and equipped.", "moduleBuyDefaultVehicle=true|Module purchased and equipped.",
			"buy02=true|Cockpit instance purchased.", "garageFull=false|Garage full. Buy more garage space to store more vehicles.",
		}
		for index, line in ipairs(expected) do eq(new.log[index], line, "step " .. index) end
		eq(new.flagCalls, 0, "FeatureFlags calls for Piercer")
		eq(#new.warnings, 0, "warnings")
	end)
	test("piercer: same sequence result when the EXOTIC folder also exists (flag off and flag on)", function()
		local old = piercerSequence(garage("before", (world(false))), FAKE_IDS)
		for _, state in ipairs({ false, true }) do
			local new = piercerSequence(garage("after", (world(true)), { VehicleClass_exotic = state }), FAKE_IDS)
			old.flagCalls = new.flagCalls
			assertDeepEqual(old, new, "sequence with flag " .. tostring(state))
			eq(new.flagCalls, 0, "FeatureFlags calls for Piercer actions")
		end
	end)
	test("defaults by slot: Piercer-like cockpit is the legacy four, unchanged; Exotic-like cockpit has ten", function()
		local root, exoticCockpit = world(true)
		local h = garage("after", root, { VehicleClass_exotic = true })
		for _, cockpitId in ipairs({ "bruiser_01", "bruiser_02", "bruiser_06" }) do
			local cockpit = h.lookup.findCockpit("bruiser", cockpitId)
			local legacy = h.defaultModuleIdsForCockpit(cockpit)
			local map, optional = h.defaultSlotModuleIdsForCockpit(cockpit)
			assertDeepEqual(map, { Engine1 = legacy.Engine, Engine2 = legacy.RearEngine, Stabilisers = legacy.Stabilisers, Boost = legacy.Boost }, cockpitId)
			eq(count(map), 4, cockpitId .. " entries")
			eq(count(optional), 0, cockpitId .. " optional slots")
			eq(map.Engine2, "MODULE_ENGINE_B_BRUISER_" .. string.sub(cockpitId, -2) .. "_STANDARD", "Engine2")
		end
		local map, optional = h.defaultSlotModuleIdsForCockpit(exoticCockpit)
		eq(count(map), 10, "exotic entries")
		eq(count(optional), 6, "exotic optional slots")
		for slotId, moduleId in pairs(EXOTIC_BODY) do
			eq(map[slotId], moduleId, slotId)
			eq(optional[slotId], true, slotId .. " optional")
		end
		eq(map.Engine1, "MODULE_ENGINE_EXOTIC_03_STANDARD", "Engine1")
		eq(map.Engine2, "MODULE_ENGINE_B_EXOTIC_03_STANDARD", "Engine2")
		eq(map.Stabilisers, "MODULE_STABILISER_EXOTIC_03_STANDARD", "Stabilisers")
		eq(map.Boost, "MODULE_BOOST_EXOTIC_03_STANDARD", "Boost")
		eq(optional.Engine1, nil, "legacy slot is never optional")
		local empty, emptyOptional = h.defaultSlotModuleIdsForCockpit(nil)
		eq(count(empty), 0, "nil cockpit entries")
		eq(count(emptyOptional), 0, "nil cockpit optional")
	end)

	-- ========================================================================================= Exotic buys
	test("flag off refuses buys: cockpit and module, with no debit and no profile change", function()
		local h = garage("after", (world(true)), { VehicleClass_exotic = false })
		local profile = newProfile(5000000)
		local snapshot = deepCopy(profile)
		local ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
		eq(ok, false); eq(message, "Vehicle unavailable.")
		assertDeepEqual(profile, snapshot, "profile after refused cockpit")
		eq(#h.ledger, 0, "debits")
		-- A flag that is not set at all is off (default false).
		h.flags = {}
		ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
		eq(ok, false); eq(message, "Vehicle unavailable.")
		-- Own an Exotic (bought while the flag was on), then turn the flag off: module buys are refused.
		h.flags = { VehicleClass_exotic = true }
		ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
		eq(ok, true); eq(message, "Cockpit instance purchased.")
		h.flags = { VehicleClass_exotic = false }
		local owned = deepCopy(profile)
		ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_ENGINE_EXOTIC_03_POWER", VehicleId = profile.CurrentVehicleId, SlotId = "Engine1" })
		eq(ok, false); eq(message, "Module unavailable.")
		ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_NOPE", VehicleId = profile.CurrentVehicleId, SlotId = "Engine1" })
		eq(ok, false); eq(message, "Module not found.")
		assertDeepEqual(profile, owned, "profile after refused module")
		eq(#h.transactions, 0, "module transactions")
		h.flags = { VehicleClass_exotic = true }
		ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_ENGINE_EXOTIC_03_POWER", VehicleId = profile.CurrentVehicleId, SlotId = "Engine1" })
		eq(ok, true)
		eq(h.transactions[1].Price, 52800, "module price")
	end)
	test("flag on: Exotic buy writes the cockpit's category, debits once and attaches ten defaults", function()
		local h = garage("after", (world(true)), { VehicleClass_exotic = true })
		local profile = newProfile(1000000)
		local ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
		eq(ok, true); eq(message, "Cockpit instance purchased.")
		eq(profile.Cash, 560000, "cash")
		assertDeepEqual(h.ledger, { "CockpitInstance:440000" }, "ledger")
		eq(profile.CurrentCategory, "exotic", "CurrentCategory")
		eq(profile.CurrentCockpit, "exotic_03", "CurrentCockpit")
		local vehicle = profile.Vehicles[profile.CurrentVehicleId]
		eq(vehicle.CategoryId, "exotic", "vehicle.CategoryId")
		eq(count(vehicle.InstalledModules), 10, "installed slots")
		eq(count(profile.OwnedModuleInstances), 10, "instances")
		eq(count(profile.InstalledModules), 10, "session InstalledModules")
		for slotId, instanceId in pairs(vehicle.InstalledModules) do
			local record = profile.OwnedModuleInstances[instanceId]
			eq(record.GrantedForVehicleId, profile.CurrentVehicleId, slotId .. " GrantedForVehicleId")
			eq(record.Source, "IncludedWithCockpit", slotId .. " Source")
			eq(profile.InstalledModules[slotId], record.TemplateId, slotId .. " session mirror")
			local keys = {}
			for key in pairs(record) do table.insert(keys, key) end
			table.sort(keys)
			eq(table.concat(keys, ","), "AcquiredAtUnix,AcquisitionKind,Colors,EquippedVehicleId,GrantedForVehicleId,NeonOwned,Source,TemplateId,UpgradeLevels", slotId .. " record fields (no new field)")
		end
		for slotId, moduleId in pairs(EXOTIC_BODY) do
			eq(profile.OwnedModuleInstances[vehicle.InstalledModules[slotId]].TemplateId, moduleId, slotId)
		end
		eq(h.coreModulesEquipped(profile), true, "coreModulesEquipped")
	end)
	test("category comes from the cockpit; a sent category must match it; unknown category is rejected", function()
		local h = garage("after", (world(true)), { VehicleClass_exotic = true })
		local profile = newProfile(5000000)
		local snapshot = deepCopy(profile)
		for _, args in ipairs({
			{ CategoryId = "zzz", CockpitId = "bruiser_02" },      -- old code bought this and saved CategoryId "zzz"
			{ CategoryId = "PIERCER", CockpitId = "bruiser_02" },  -- folder name is not the category id
			{ CategoryId = "bruiser", CockpitId = "exotic_03" },
			{ CategoryId = "exotic", CockpitId = "bruiser_01" },
			{ CockpitId = "exotic_03" },                           -- no category sent: looked up in CurrentCategory (bruiser)
		}) do
			local ok, message = h.buyCockpitInstance(profile, args)
			eq(ok, false, tostring(args.CategoryId) .. "/" .. args.CockpitId)
			eq(message, "Cockpit not found.", tostring(args.CategoryId) .. "/" .. args.CockpitId)
			assertDeepEqual(profile, snapshot, "profile after rejected request")
		end
		eq(#h.ledger, 0, "debits")
		-- No category sent and a stale session category that only resolves through the first-child fallback:
		-- the purchase works as before, and the vehicle is saved with the cockpit's own category.
		profile.CurrentCategory = "zzz"
		local ok = h.buyCockpitInstance(profile, { CockpitId = "bruiser_02" })
		eq(ok, true)
		eq(profile.Vehicles[profile.CurrentVehicleId].CategoryId, "bruiser", "saved category")
		eq(profile.CurrentCategory, "bruiser", "CurrentCategory")
	end)
	test("category of a cockpit without a CategoryId attribute comes from its category folder, never from the request", function()
		local h = garage("after", (world(true)), { VehicleClass_exotic = true })
		h.lookup.findCockpit("bruiser", "bruiser_02"):_set("CategoryId", nil)
		local profile = newProfile(5000000)
		profile.GarageCapacity = 5
		local snapshot = deepCopy(profile)
		for _, sent in ipairs({ "zzz", "PIERCER", "exotic" }) do -- "zzz" resolves to the first folder, "PIERCER" by folder name
			local ok, message = h.buyCockpitInstance(profile, { CategoryId = sent, CockpitId = "bruiser_02" })
			eq(ok, false, sent); eq(message, "Cockpit not found.", sent)
			assertDeepEqual(profile, snapshot, "profile after rejected request " .. sent)
		end
		eq(#h.ledger, 0, "debits")
		eq((h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "bruiser_02" })), true, "the folder's id is accepted")
		eq(profile.Vehicles[profile.CurrentVehicleId].CategoryId, "bruiser", "saved category"); eq(profile.CurrentCategory, "bruiser", "CurrentCategory")
		-- No category sent and a stale session string: the folder's id is written, not the session string.
		profile.CurrentCategory = "zzz"
		eq((h.buyCockpitInstance(profile, { CockpitId = "bruiser_02" })), true, "no category sent")
		eq(profile.Vehicles[profile.CurrentVehicleId].CategoryId, "bruiser", "saved category, stale session"); eq(profile.CurrentCategory, "bruiser")
		eq(count(profile.Vehicles[profile.CurrentVehicleId].InstalledModules), 4, "defaults attached")
		-- A folder without the attribute: the id is slug(folder name), the same rule the catalogue uses.
		local bareRoot = world(false)
		local hb = garage("after", bareRoot)
		bareRoot:FindFirstChild("PIERCER"):_set("CategoryId", nil)
		hb.lookup.findCockpit("piercer", "bruiser_02"):_set("CategoryId", nil)
		local bare = newProfile(5000000)
		local ok, message = hb.buyCockpitInstance(bare, { CategoryId = "bruiser", CockpitId = "bruiser_02" })
		eq(ok, false); eq(message, "Cockpit not found.", "request differs from the folder id")
		eq((hb.buyCockpitInstance(bare, { CategoryId = "piercer", CockpitId = "bruiser_02" })), true, "slug of the folder name")
		eq(bare.Vehicles[bare.CurrentVehicleId].CategoryId, "piercer", "saved category from the folder name")
	end)
	test("neon mirror: an Exotic bought after a vehicle with neon grants no neon; a Piercer buy is unchanged (old vs new)", function()
		local slots = { "Engine1", "Engine2", "Stabilisers", "Boost", "FrontBumper", "RearBumper", "RearSpoiler", "SidePods", "FrontBody", "RearBody" }
		local function profileWithNeon() -- the session mirror still holds the previously selected vehicle's neon
			local profile = newProfile(5000000)
			profile.GarageCapacity = 5
			for _, slotId in ipairs(slots) do profile.NeonOwned[slotId] = true end
			return profile
		end
		-- The neon rule of GarageModuleInstanceCustomization.CaptureSlot (its line 22), which the next CaptureAll applies
		-- to every installed instance. Copied here because that module is not one of the sources under test.
		local function captureNeon(profile)
			for slotId, instanceId in pairs(profile.Vehicles[profile.CurrentVehicleId].InstalledModules) do
				local instance = profile.OwnedModuleInstances[instanceId]
				if profile.NeonOwned and profile.NeonOwned[slotId] ~= nil then instance.NeonOwned = profile.NeonOwned[slotId] == true else instance.NeonOwned = instance.NeonOwned == true end
			end
		end
		local h = garage("after", (world(true)), { VehicleClass_exotic = true })
		local profile = profileWithNeon()
		eq((h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })), true)
		for _, slotId in ipairs(slots) do eq(profile.NeonOwned[slotId], false, "mirror " .. slotId) end
		captureNeon(profile)
		local vehicle = profile.Vehicles[profile.CurrentVehicleId]
		eq(count(vehicle.InstalledModules), 10, "installed slots")
		for slotId, instanceId in pairs(vehicle.InstalledModules) do eq(profile.OwnedModuleInstances[instanceId].NeonOwned, false, "instance " .. slotId) end
		-- Neon bought on the Exotic afterwards is not touched when attach grants nothing.
		profile.NeonOwned.SidePods = true
		h.attach(profile)
		eq(profile.NeonOwned.SidePods, true, "bought neon survives a reselect")
		-- A re-granted legacy slot on the Exotic starts without neon too.
		vehicle.InstalledModules.Engine2 = nil
		profile.NeonOwned.Engine2 = true
		h.attach(profile)
		eq(profile.NeonOwned.Engine2, false, "re-granted slot mirror")
		-- Piercer: the mirror is left exactly as the old source leaves it (legacy-slot inheritance is reported, not fixed).
		local views = {}
		for _, version in ipairs({ "before", "after" }) do
			local hp = garage(version, (world(false)))
			local piercerProfile = profileWithNeon()
			eq((hp.buyCockpitInstance(piercerProfile, { CategoryId = "bruiser", CockpitId = "bruiser_02" })), true, version)
			views[version] = canonical(piercerProfile)
		end
		assertDeepEqual(views.before, views.after, "Piercer buy with a neon mirror")
		for _, slotId in ipairs(slots) do eq(views.after.NeonOwned[slotId], true, "Piercer mirror " .. slotId) end
	end)
	test("failed cross-category buy leaves the session untouched (old code poisoned CurrentCategory)", function()
		for _, version in ipairs({ "before", "after" }) do
			local h = garage(version, (world(true)), { VehicleClass_exotic = true })
			local profile = newProfile(400000)
			eq((h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "bruiser_01" })), true, version .. " piercer buy")
			local snapshot = deepCopy(profile)
			local ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
			eq(ok, false); eq(message, "Not enough cash.")
			if version == "after" then
				assertDeepEqual(profile, snapshot, "profile after unaffordable Exotic")
				profile.GarageCapacity = 1
				profile.Cash = 9000000
				snapshot = deepCopy(profile)
				ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
				eq(ok, false); eq(message, "Garage full. Buy more garage space to store more vehicles.")
				assertDeepEqual(profile, snapshot, "profile after garage full")
			else
				eq(profile.CurrentCategory, "exotic", "old source wrote CurrentCategory before validating")
			end
		end
	end)
	test("default pre-check: a missing or unfit default refuses the buy before the debit; cash check still comes first", function()
		local cases = {
			{ "DefaultFrontBodyModuleId", "MODULE_MISSING" },                 -- template missing
			{ "DefaultFrontBodyModuleId", "MODULE_REARBODY_EXOTIC_03" },      -- wrong type for the slot
			{ "DefaultEngineModuleId", "MODULE_ENGINE_B_EXOTIC_03_STANDARD" },-- rear engine in Engine1
			{ "DefaultBoostModuleId", "MODULE_MISSING" },                     -- legacy slot default missing
			{ "DefaultSidePodsModuleId", "MODULE_SIDEPODS_LVL1" },            -- a Piercer module (other category)
		}
		for _, case in ipairs(cases) do
			local root, exoticCockpit = world(true)
			local h = garage("after", root, { VehicleClass_exotic = true })
			eq(h.cockpitDefaultsInstallable("exotic", exoticCockpit), true, "intact cockpit")
			exoticCockpit:_set(case[1], case[2])
			eq(h.cockpitDefaultsInstallable("exotic", exoticCockpit), false, case[1])
			local profile = newProfile(5000000)
			local snapshot = deepCopy(profile)
			local ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
			eq(ok, false, case[1]); eq(message, "Vehicle unavailable.", case[1])
			assertDeepEqual(profile, snapshot, "profile after refused buy " .. case[1])
			eq(#h.ledger, 0, "debits " .. case[1])
			profile.Cash = 10
			ok, message = h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
			eq(message, "Not enough cash.", "order " .. case[1])
		end
		-- A slot folder that is missing on the cockpit also refuses the buy.
		local root, exoticCockpit = world(true)
		local h = garage("after", root, { VehicleClass_exotic = true })
		exoticCockpit:FindFirstChild("ModuleSlots"):FindFirstChild("SLOT_Boost").Name = "SLOT_BoostRenamed"
		eq(h.cockpitDefaultsInstallable("exotic", exoticCockpit), false, "missing slot folder")
		-- A cockpit with no value for a legacy default is still sellable, as today (the slot is simply not granted).
		local pRoot = world(false)
		local hp = garage("after", pRoot)
		local viper = hp.lookup.findCockpit("bruiser", "bruiser_01")
		viper:_set("DefaultBoostModuleId", nil)
		eq(hp.cockpitDefaultsInstallable("bruiser", viper), true, "absent legacy default")
	end)
	test("grant-once guard: a new-slot default is not granted twice; legacy slots keep today's behaviour", function()
		local h = garage("after", (world(true)), { VehicleClass_exotic = true })
		local profile = newProfile(5000000)
		eq((h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })), true)
		local vehicleId = profile.CurrentVehicleId
		local vehicle = profile.Vehicles[vehicleId]
		h.attach(profile)
		eq(count(profile.OwnedModuleInstances), 10, "reselect grants nothing")
		-- The default side pods leave the vehicle (as a move to another vehicle does) but stay owned.
		local movedId = vehicle.InstalledModules.SidePods
		vehicle.InstalledModules.SidePods = nil
		profile.OwnedModuleInstances[movedId].EquippedVehicleId = "vehicle_other"
		profile.InstalledModules.SidePods = nil
		eq(h.defaultAlreadyGrantedForVehicle(profile, vehicleId, "MODULE_SIDEPODS_EXOTIC_03"), true, "guard sees the earlier grant")
		h.attach(profile)
		eq(count(profile.OwnedModuleInstances), 10, "no second free side pods")
		eq(vehicle.InstalledModules.SidePods, nil, "slot stays empty")
		eq(profile.InstalledModules.SidePods, nil, "session mirror not faked")
		-- Another module in a new slot: the mirror is not overwritten with the default id.
		vehicle.InstalledModules.FrontBumper = nil
		profile.InstalledModules.FrontBumper = "SOMETHING_ELSE"
		h.attach(profile)
		eq(profile.InstalledModules.FrontBumper, "SOMETHING_ELSE", "mirror untouched when nothing is granted")
		eq(count(profile.OwnedModuleInstances), 10, "still ten")
		-- Guard is per vehicle and per template.
		eq(h.defaultAlreadyGrantedForVehicle(profile, "vehicle_other", "MODULE_SIDEPODS_EXOTIC_03"), false, "other vehicle")
		eq(h.defaultAlreadyGrantedForVehicle(profile, vehicleId, "MODULE_NOPE"), false, "other template")
		eq(h.defaultAlreadyGrantedForVehicle({}, vehicleId, "MODULE_SIDEPODS_EXOTIC_03"), false, "no instance table")
		-- Legacy slot: unchanged (an emptied legacy slot is refilled, as before this change; reported, not fixed).
		vehicle.InstalledModules.Engine2 = nil
		h.attach(profile)
		eq(count(profile.OwnedModuleInstances), 11, "legacy slot refilled as today")
		-- A second Exotic gets its own ten.
		profile.GarageCapacity = 5
		eq((h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })), true)
		eq(count(profile.Vehicles[profile.CurrentVehicleId].InstalledModules), 10, "second vehicle slots")
		eq(count(profile.OwnedModuleInstances), 21, "instances after second buy")
	end)
	test("coreSlotRequired: FrontBody and RearBody are required only where the cockpit has the slot", function()
		local h = garage("after", (world(true)), { VehicleClass_exotic = true })
		local profile = newProfile(5000000)
		profile.GarageCapacity = 5
		h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "bruiser_02" })
		local piercerVehicle = profile.CurrentVehicleId
		h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
		local exoticVehicle = profile.CurrentVehicleId
		eq(h.coreSlotRequired(profile, exoticVehicle, "FrontBody"), true, "exotic FrontBody")
		eq(h.coreSlotRequired(profile, exoticVehicle, "RearBody"), true, "exotic RearBody")
		eq(h.coreSlotRequired(profile, exoticVehicle, "SidePods"), false, "exotic SidePods")
		eq(h.coreSlotRequired(profile, exoticVehicle, "Boost"), true, "exotic Boost")
		eq(h.coreSlotRequired(profile, piercerVehicle, "FrontBody"), false, "piercer FrontBody")
		eq(h.coreSlotRequired(profile, piercerVehicle, "RearBody"), false, "piercer RearBody")
		eq(h.coreSlotRequired(profile, "vehicle_missing", "FrontBody"), false, "unknown vehicle")
	end)
	test("buyModuleInstance resolves the module in the target vehicle's category", function()
		local h = garage("after", (world(true)), { VehicleClass_exotic = true })
		local profile = newProfile(5000000)
		profile.GarageCapacity = 5
		h.buyCockpitInstance(profile, { CategoryId = "exotic", CockpitId = "exotic_03" })
		local exoticVehicle = profile.CurrentVehicleId
		h.buyCockpitInstance(profile, { CategoryId = "bruiser", CockpitId = "bruiser_02" })
		local piercerVehicle = profile.CurrentVehicleId
		eq(profile.CurrentCategory, "bruiser", "session category")
		-- Session is on the Piercer; the target vehicle is the Exotic.
		local ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_ENGINE_EXOTIC_03_POWER", VehicleId = exoticVehicle, SlotId = "Engine1" })
		eq(ok, true, tostring(message))
		eq(h.transactions[1].Template, "MODULE_ENGINE_EXOTIC_03_POWER"); eq(h.transactions[1].VehicleId, exoticVehicle); eq(h.transactions[1].Price, 52800)
		-- An Exotic part cannot go on a Piercer, and a Piercer part cannot go on an Exotic.
		ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_FRONTBODY_EXOTIC_03", VehicleId = piercerVehicle, SlotId = "FrontBody" })
		eq(ok, false); eq(message, "Module not found.")
		ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_SIDEPODS_LVL1", VehicleId = exoticVehicle, SlotId = "SidePods" })
		eq(ok, false); eq(message, "Module not found.")
		-- Body parts are open to any Exotic owner; a family part needs its source cockpit.
		ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_REARBODY_EXOTIC_03", VehicleId = exoticVehicle, SlotId = "RearBody" })
		eq(ok, true, tostring(message)); eq(h.transactions[2].Price, 14000)
		ok, message = h.buyModuleInstance(profile, { ModuleId = "MODULE_REARBODY_EXOTIC_03", VehicleId = exoticVehicle, SlotId = "FrontBody" })
		eq(ok, false); eq(message, "That module does not fit this slot.")
		eq(#h.transactions, 2, "transactions")
	end)

	-- ================================================================================== GarageCatalogLookup
	test("lookup: source cockpit and fallback price use the module's own category; Piercer results unchanged", function()
		local root = world(true)
		local old, new = garage("before", root), garage("after", root)
		for _, module in ipairs(root:FindFirstChild("PIERCER"):FindFirstChild("MODULES_InterchangeableWithinCategory"):GetDescendants()) do
			if module:GetAttribute("ModuleId") then
				eq(new.lookup.modulePurchasePrice(module), old.lookup.modulePurchasePrice(module), module.Name .. " price")
				for _, profile in ipairs({ false, { CurrentCategory = "bruiser" } }) do
					local oldId, oldCockpit = old.lookup.findSourceCockpit(profile or nil, module)
					local newId, newCockpit = new.lookup.findSourceCockpit(profile or nil, module)
					eq(newId, oldId, module.Name .. " source id"); eq(newCockpit, oldCockpit, module.Name .. " source cockpit")
				end
				local profile = { CurrentCategory = "bruiser", OwnedCockpits = {}, OwnedCockpitInstances = {} }
				eq(new.lookup.moduleLockedMessage(profile, module), old.lookup.moduleLockedMessage(profile, module), module.Name .. " lock message")
			end
		end
		eq(new.lookup.modulePurchasePrice(new.lookup.findModule("bruiser", "MODULE_ENGINE_BRUISER_01_LIGHTWEIGHT")), 42000, "piercer 12 percent fallback")
		local noPrice = new.lookup.findModule("exotic", "MODULE_ENGINE_EXOTIC_03_NOPRICE")
		eq(new.lookup.modulePurchasePrice(noPrice), 52800, "exotic 12 percent of 440000")
		eq(old.lookup.modulePurchasePrice(noPrice), 1000, "old source priced it at the 1000 floor")
		local id, cockpit = new.lookup.findSourceCockpit(nil, noPrice)
		eq(id, "exotic_03"); eq(cockpit and cockpit:GetAttribute("DisplayName"), "Wedge", "source cockpit with nil profile")
		eq(select(2, old.lookup.findSourceCockpit(nil, noPrice)), nil, "old source could not find it")
		eq(new.lookup.moduleLockedMessage({ CurrentCategory = "bruiser", OwnedCockpits = {}, OwnedCockpitInstances = {} }, noPrice), "Buy Wedge before buying this module family.", "lock message")
		-- A module with no CategoryId attribute keeps today's lookup.
		local bare = inst("Model", "MODULE_BARE", { ModuleId = "MODULE_BARE", SourceCockpitId = "bruiser_06" })
		eq(new.lookup.modulePurchasePrice(bare), 1200000, "no attribute: bruiser fallback")
		eq(select(2, new.lookup.findSourceCockpit(nil, bare)):GetAttribute("CockpitId"), "bruiser_06", "no attribute: nil profile")
	end)

	-- ================================================================================= GarageCatalogService
	local function catalogContext(h, categoriesRoot)
		return {
			PREVIEW_POS = Vector3.new(1, 2, 3), categoriesRoot = categoriesRoot, categoryFlagEnabled = h.categoryFlagEnabled,
			cosmeticCatalog = { List = function() return { { CosmeticId = "Underglow" } } end },
			findSourceCockpit = h.lookup.findSourceCockpit, garageServer_number = h.garageServer_number, garageServer_string = h.garageServer_string,
			modulePurchasePrice = h.lookup.modulePurchasePrice, moduleSourceCockpitId = h.lookup.moduleSourceCockpitId,
			moduleTypeForModel = h.lookup.moduleTypeForModel, moduleTypeFromText = h.lookup.moduleTypeFromText,
			moduleUpgrades = { CatalogForModuleType = function() return {} end },
			moduleVariantName = h.lookup.moduleVariantName, moduleVariantOrder = h.lookup.moduleVariantOrder,
			primitiveAttributes = h.primitiveAttributes, slug = h.lookup.slug,
		}
	end
	local function catalogService(version, h, categoriesRoot)
		return assert(loadstring(sources[version].GarageCatalogService, version .. ".GarageCatalogService"))()(catalogContext(h, categoriesRoot))
	end
	local function hasKeyAnywhere(value, wanted)
		if type(value) ~= "table" then return false end
		for key, child in pairs(value) do
			if key == wanted or hasKeyAnywhere(child, wanted) then return true end
		end
		return false
	end
	test("catalogue: Piercer payload is identical old vs new and has no RailLabel or CardTitle key", function()
		local root = world(false)
		local oldCatalog = catalogService("before", garage("before", root), root)()
		local newService = catalogService("after", garage("after", root), root)
		local newCatalog, revision = newService()
		assertDeepEqual(oldCatalog, newCatalog, "catalogue")
		eq(#newCatalog.Categories, 1); eq(#newCatalog.Categories[1].Slots, 8); eq(#newCatalog.Categories[1].Cockpits, 3)
		eq(hasKeyAnywhere(newCatalog, "RailLabel"), false, "RailLabel key"); eq(hasKeyAnywhere(newCatalog, "CardTitle"), false, "CardTitle key")
		local again, sameRevision = newService()
		eq(again, newCatalog, "snapshot is cached"); eq(sameRevision, revision, "revision is stable")
		local none, knownRevision = newService(revision)
		eq(none, nil, "known revision gets no catalogue"); eq(knownRevision, revision)
	end)
	test("catalogue: flagged category is left out when off, present with RailLabel and CardTitle when on, rebuilt on a flip", function()
		local root = world(true)
		local h = garage("after", root, { VehicleClass_exotic = false })
		local service = catalogService("after", h, root)
		local off, offRevision = service()
		eq(#off.Categories, 1, "categories with flag off"); eq(off.Categories[1].CategoryId, "bruiser")
		local pureRoot = world(false)
		assertDeepEqual(off, catalogService("after", garage("after", pureRoot), pureRoot)(), "flag-off catalogue equals the Piercer-only catalogue")
		eq(select(1, service(offRevision)), nil, "known revision while unchanged")
		h.flags.VehicleClass_exotic = true
		local on, onRevision = service(offRevision)
		assert(on ~= nil and onRevision ~= offRevision, "a flip must issue a new revision and send the catalogue")
		eq(#on.Categories, 2, "categories with flag on")
		eq(on.Categories[1].CategoryId, "exotic", "sorted by display name"); eq(on.Categories[2].CategoryId, "bruiser")
		local exotic, piercer = on.Categories[1], on.Categories[2]
		eq(#exotic.Slots, 10, "exotic slots")
		for index, row in ipairs(EXOTIC_SLOTS) do
			eq(exotic.Slots[index].SlotId, row[1], "slot order " .. index); eq(exotic.Slots[index].RailLabel, row[2], "RailLabel " .. row[1])
		end
		for _, slot in ipairs(piercer.Slots) do eq(slot.RailLabel, nil, "piercer slot " .. slot.SlotId) end
		eq(exotic.Modules.FrontBody[1].CardTitle, "Body FrontBody", "CardTitle")
		eq(exotic.Modules.Engine[1].SourceCockpitDisplayName, "Wedge", "source cockpit display name")
		eq(hasKeyAnywhere(piercer, "CardTitle"), false, "piercer CardTitle"); eq(hasKeyAnywhere(piercer, "RailLabel"), false, "piercer RailLabel")
		assertDeepEqual(piercer, off.Categories[1], "piercer category is the same with Exotic on")
		eq(exotic.Cockpits[1].DefaultFrontBodyModuleId, "MODULE_FRONTBODY_EXOTIC_03", "cockpit attributes reach the client")
		eq(select(1, service(onRevision)), nil, "known revision after the flip")
		h.flags.VehicleClass_exotic = false
		local offAgain, offAgainRevision = service(onRevision)
		assert(offAgain ~= nil and offAgainRevision ~= onRevision, "flip back must rebuild")
		eq(#offAgain.Categories, 1, "categories after flip back")
	end)

	test("catalogue: without ctx.categoryFlagEnabled Piercer is unchanged, a flagged category stays hidden, one warning", function()
		local function service(categoriesRoot, withGate)
			local h = garage("after", categoriesRoot, { VehicleClass_exotic = true })
			local warnings = {}
			local chunk = assert(loadstring(sources.after.GarageCatalogService, "after.GarageCatalogService.gate"))
			setfenv(chunk, setmetatable({ warn = function(message) table.insert(warnings, tostring(message)) end }, { __index = getfenv(0) }))
			local ctx = catalogContext(h, categoriesRoot)
			if not withGate then ctx.categoryFlagEnabled = nil end
			return chunk()(ctx), warnings, h
		end
		local pureRoot = world(false)
		local noGate, warnings = service(pureRoot, false)
		assertDeepEqual(noGate(), catalogService("before", garage("before", pureRoot), pureRoot)(), "Piercer catalogue without the gate")
		eq(#warnings, 1, "one warning when the gate is missing")
		local mixedRoot = world(true)
		local mixed, _, h = service(mixedRoot, false)
		local catalogue, revision = mixed()
		eq(#catalogue.Categories, 1, "categories without the gate"); eq(catalogue.Categories[1].CategoryId, "bruiser")
		eq(select(1, mixed(revision)), nil, "known revision without the gate")
		eq(h.flagCalls, 0, "the default gate does not read FeatureFlags")
		local gated, gatedWarnings = service(mixedRoot, true)
		eq(#gated().Categories, 2, "categories with the gate and the flag on"); eq(#gatedWarnings, 0, "no warning with the gate")
	end)
	test("GarageServer passes its categoryFlagEnabled to GarageCatalogService, exactly once (GS11 wiring)", function()
		local wiring = "categoryFlagEnabled = categoryFlagEnabled, cosmeticCatalog = cosmeticCatalog"
		local source = sources.after.GarageServer
		local first = string.find(source, wiring, 1, true)
		assert(first, "wiring text missing")
		assert(not string.find(source, wiring, first + 1, true), "wiring text occurs more than once")
		local lineStart = string.find(source, SUMMARY_END, 1, true)
		local lineEnd = string.find(source, "\n", lineStart, true)
		local line = string.sub(source, lineStart, lineEnd)
		assert(string.find(line, 'WaitForChild("GarageCatalogService"))({', 1, true), "the anchored line is the GarageCatalogService require")
		assert(first > lineStart and first < lineEnd, "the gate is passed in the GarageCatalogService ctx")
		eq(string.find(sources.before.GarageServer, "categoryFlagEnabled", 1, true), nil, "the before source has no gate")
	end)

	-- ======================================================================= missing templates never throw
	local function summaries(version, categoriesRoot)
		local h = garage(version, categoriesRoot)
		local env = {
			ensureInstanceInventory = ensureShape,
			syncLegacyFromCurrentVehicle = function(profile)
				local vehicle = profile.Vehicles[profile.CurrentVehicleId]
				profile.CurrentCategory = vehicle.CategoryId
				profile.CurrentCockpit = profile.OwnedCockpitInstances[vehicle.CockpitInstanceId].TemplateId
				profile.InstalledModules = {}
				for slotId, instanceId in pairs(vehicle.InstalledModules or {}) do
					local instance = profile.OwnedModuleInstances[instanceId]
					if typeof(instance) == "table" and instance.TemplateId then profile.InstalledModules[slotId] = tostring(instance.TemplateId) end
				end
				return true
			end,
			moduleUpgrades = { CalculateProfile = function(_, _, _, cockpit) -- same assert as VehicleModuleUpgradeRuntime 106
				assert(cockpit and cockpit:GetAttribute("V2Materialised") == true, "Canonical V2 cockpit is not materialised")
				return { Overall = cockpit:GetAttribute("Price"), Headline = cockpit.Name }
			end },
		}
		local fn = runChunk(slice(sources[version].GarageServer, SUMMARY_START, SUMMARY_END) .. "\nreturn vehicleSummaries", env, version .. ".GarageServer.summaries", h.env)
		return fn, h
	end
	local function ownedProfile(withMissing)
		local profile = newProfile(0)
		profile.OwnedCockpitInstances = { cockpit_a = { TemplateId = "bruiser_02", VehicleId = "vehicle_a" }, cockpit_b = { TemplateId = "exotic_99", VehicleId = "vehicle_b" } }
		profile.Vehicles = { vehicle_a = { CategoryId = "bruiser", CockpitInstanceId = "cockpit_a", InstalledModules = {}, DisplayName = "bruiser_02" } }
		if withMissing then profile.Vehicles.vehicle_b = { CategoryId = "exotic", CockpitInstanceId = "cockpit_b", InstalledModules = {}, DisplayName = "exotic_99" } end
		profile.CurrentVehicleId = "vehicle_a"
		profile.CurrentCategory, profile.CurrentCockpit = "bruiser", "bruiser_02"
		return profile
	end
	test("vehicleSummaries: an owned vehicle with a missing cockpit template is skipped with one warning", function()
		local root = world(false)
		local oldFn = summaries("before", root)
		local newFn, h = summaries("after", root)
		assertDeepEqual(oldFn(ownedProfile(false)), newFn(ownedProfile(false)), "Piercer summaries old vs new")
		eq(#h.warnings, 0, "no warning for Piercer")
		eq(pcall(oldFn, ownedProfile(true)), false, "old source throws")
		local profile = ownedProfile(true)
		local result = newFn(profile)
		eq(result.vehicle_b, nil, "missing vehicle skipped"); eq(result.vehicle_a.CockpitId, "bruiser_02", "other vehicle kept")
		eq(profile.CurrentVehicleId, "vehicle_a", "selection restored"); eq(profile.CurrentCategory, "bruiser"); eq(profile.CurrentCockpit, "bruiser_02")
		newFn(profile)
		eq(#h.warnings, 1, "warned once")
		assert(string.find(h.warnings[1], "exotic/exotic_99", 1, true), "warning names the template: " .. h.warnings[1])
	end)
	test("vehicleSummaries: an installed module with a missing template is reported once; summaries and profile as the old source", function()
		local root = world(false)
		local oldFn = summaries("before", root)
		local newFn, h = summaries("after", root)
		local function profileWithModules(missing)
			local profile = ownedProfile(false)
			profile.OwnedModuleInstances = {
				module_a = { TemplateId = "MODULE_ENGINE_BRUISER_02_STANDARD", EquippedVehicleId = "vehicle_a" },
				module_b = { TemplateId = missing and "MODULE_GONE" or "MODULE_SIDEPODS_LVL1", EquippedVehicleId = "vehicle_a" },
			}
			profile.Vehicles.vehicle_a.InstalledModules = { Engine1 = "module_a", SidePods = "module_b" }
			return profile
		end
		for _, missing in ipairs({ false, true }) do
			local oldProfile, newProfileValue = profileWithModules(missing), profileWithModules(missing)
			local newResult = newFn(newProfileValue)
			assertDeepEqual(oldFn(oldProfile), newResult, "summaries old vs new, missing=" .. tostring(missing))
			assertDeepEqual(oldProfile, newProfileValue, "profile old vs new, missing=" .. tostring(missing))
			eq(newResult.vehicle_a.CockpitId, "bruiser_02", "vehicle is summarised")
			eq(#h.warnings, missing and 1 or 0, "warnings, missing=" .. tostring(missing))
		end
		newFn(profileWithModules(true))
		eq(#h.warnings, 1, "warned once per template")
		assert(string.find(h.warnings[1], "bruiser/MODULE_GONE", 1, true) and string.find(h.warnings[1], "SidePods", 1, true) and string.find(h.warnings[1], "vehicle_a", 1, true), "warning names the template, slot and vehicle: " .. h.warnings[1])
	end)
	test("profileForClient: a current cockpit without a template omits Performance and warns once; Piercer reply unchanged", function()
		local root = world(false)
		local function clientProfile(version)
			local h = garage(version, root)
			local warnings = {}
			local chunk = assert(loadstring(sources[version].GarageClientProfile, version .. ".GarageClientProfile"))
			setfenv(chunk, setmetatable({ warn = function(message) table.insert(warnings, tostring(message)) end }, { __index = getfenv(0) }))
			local _, profileForClient = chunk()({
				capacityUpgradePrice = function() return 1 end, findCockpit = h.lookup.findCockpit, findModule = h.lookup.findModule,
				garageServer_categoryFolder = h.lookup.garageServer_categoryFolder, garageServer_number = h.garageServer_number, garageServer_string = h.garageServer_string,
				maxGarageCapacity = function() return 10 end, moduleTypeForModel = h.lookup.moduleTypeForModel,
				moduleUpgrades = { GetLevels = function() return {} end, CalculateProfile = function(_, _, totals, cockpit)
					assert(cockpit and cockpit:GetAttribute("V2Materialised") == true, "Canonical V2 cockpit is not materialised")
					return { Overall = cockpit:GetAttribute("Price"), Totals = totals }
				end },
				nextGaragePropertyPrice = function() return 2 end, normalizeProfile = function(profile) return profile end,
				ownedCockpitCount = function() return 1 end, ownedGarageProperties = function() return {} end, profileGarageCapacity = function() return 2 end,
				vehicleCosmetics = { Ensure = function() end }, vehicleSummaries = function() return {} end,
			})
			return profileForClient, warnings
		end
		local oldFn = clientProfile("before")
		local newFn, warnings = clientProfile("after")
		local oldReply, newReply = oldFn(ownedProfile(false)), newFn(ownedProfile(false))
		assertDeepEqual(oldReply, newReply, "Piercer reply old vs new")
		eq(newReply.Performance.Overall, 40000, "Performance present"); eq(#warnings, 0, "no warning for Piercer")
		local broken = ownedProfile(false)
		broken.CurrentCategory, broken.CurrentCockpit = "exotic", "exotic_99"
		eq(pcall(oldFn, broken), false, "old source throws")
		local reply = newFn(broken)
		eq(reply.Performance, nil, "Performance omitted"); eq(type(reply.TotalStats), "table", "TotalStats still sent"); eq(reply.CurrentCockpit, "exotic_99")
		newFn(broken)
		eq(#warnings, 1, "warned once")
	end)

	-- ==================================================================================== OwnedGarageDisplay
	test("OwnedGarageDisplay.categoryFolder: CategoryId attribute first, then the folder name as before", function()
		local function categoryFolder(version, categoriesRoot)
			local chain
			chain = { WaitForChild = function(_, name) if name == "Categories" then return categoriesRoot end return chain end }
			return runChunk(slice(sources[version].OwnedGarageDisplay, "local function categoryFolder(categoryId)", "local function cockpitTemplate(categoryId,cockpitId)")
				.. "\nreturn categoryFolder", { categories = categoriesRoot, game = { GetService = function() return chain end } }, version .. ".OwnedGarageDisplay.categoryFolder")
		end
		local root = world(true)
		local old, new = categoryFolder("before", root), categoryFolder("after", root)
		for _, id in ipairs({ "bruiser", "BRUISER", "piercer", "PIERCER", "exotic", "EXOTIC", "zzz" }) do
			eq(new(id), old(id), "same folder for " .. id)
		end
		eq(new(nil), old(nil), "nil id"); eq(new("bruiser").Name, "PIERCER"); eq(new("exotic").Name, "EXOTIC"); eq(new(nil).Name, "PIERCER")
		-- With EXOTIC as the first child the old code sent every Piercer display car to the wrong category.
		local swapped = inst("Folder", "Categories")
		swapped:_add((exoticCategory()))
		swapped:_add(piercerCategory())
		eq(categoryFolder("before", swapped)("bruiser").Name, "EXOTIC", "old source depended on child order")
		eq(categoryFolder("after", swapped)("bruiser").Name, "PIERCER", "new source does not")
		-- An empty id matches no CategoryId attribute: a folder without the attribute is not picked, as before.
		local bare = inst("Folder", "Categories")
		bare:_add(piercerCategory())
		bare:_add(inst("Folder", "NOATTR"))
		local oldBare, newBare = categoryFolder("before", bare), categoryFolder("after", bare)
		eq(newBare("").Name, "PIERCER", "empty id uses the fallback"); eq(newBare(""), oldBare(""), "empty id, old vs new")
		eq(newBare("noattr").Name, "NOATTR", "folder name still matches"); eq(newBare("noattr"), oldBare("noattr"), "folder name, old vs new")
	end)

	-- ================================================================================================ seats
	local function numberValue(name, value)
		local item = inst("NumberValue", name)
		item.Value = value
		return item
	end
	test("DriverSeatServer.getOffset: cockpit attributes override per axis; without them the global config as before", function()
		local config = inst("Folder", "ReplicatedStorage", nil, { inst("Folder", "Config", nil, { inst("Folder", "Vehicles", nil, {
			inst("Folder", "DriverSeat", nil, { numberValue("LocalX", 0), numberValue("LocalY", 1), numberValue("LocalZ", 6) }) }) }) })
		local function getOffset(version)
			return runChunk(slice(sources[version].DriverSeatServer, "local function readValue(folder, name, fallback)", "local function showSeat()")
				.. "\nreturn getOffset", { game = { GetService = function() return config end } }, version .. ".DriverSeatServer.getOffset")
		end
		local old, new = getOffset("before"), getOffset("after")
		local piercerVehicle = inst("Model", "Player_FixedSlotHovercar", { CockpitId = "bruiser_01", CategoryId = "bruiser" })
		eq(old(), Vector3.new(0, 1, 6), "old global offset")
		eq(new(piercerVehicle), old(), "Piercer vehicle"); eq(new(nil), old(), "no vehicle")
		eq(new(inst("Model", "V", { DriverSeatOffsetX = -1.8, DriverSeatOffsetY = 0.25, DriverSeatOffsetZ = 0.45 })), Vector3.new(-1.8, 0.25, 0.45), "all three")
		eq(new(inst("Model", "V", { DriverSeatOffsetX = -1.8 })), Vector3.new(-1.8, 1, 6), "one axis")
		eq(new(inst("Model", "V", { DriverSeatOffsetX = "left", DriverSeatOffsetY = 0 / 0, DriverSeatOffsetZ = 0 })), Vector3.new(0, 1, 0), "wrong type and NaN fall back; zero is a value")
	end)
	test("VehicleBuildService.addPassengerSeat: cockpit attributes override per axis; without them the global config as before", function()
		local config = inst("Folder", "ReplicatedStorage", nil, { inst("Folder", "Config", nil, { inst("Folder", "Activities", nil, {
			inst("Folder", "Passengers", { SeatOffsetX = 0, SeatOffsetY = 1, SeatOffsetZ = 1.5 }) }) }) })
		local function addPassengerSeat(version)
			return runChunk(slice(sources[version].VehicleBuildService, "\tlocal function addPassengerSeat(vehicle, root)", "\tlocal function seatPlayer(player, vehicle, seat)")
				.. "\nreturn addPassengerSeat", { game = { GetService = function() return config end }, Instance = { new = function(className) return inst(className, className) end } }, version .. ".VehicleBuildService.addPassengerSeat")
		end
		local root = { CFrame = CFrame.new(10, 20, 30) }
		local function position(version, attributes) return addPassengerSeat(version)(inst("Model", "Vehicle", attributes), root).CFrame.Position end
		eq(position("before", {}), Vector3.new(10, 21, 31.5), "old global offset")
		eq(position("after", {}), position("before", {}), "Piercer vehicle")
		eq(position("after", { PassengerSeatOffsetX = 1.75, PassengerSeatOffsetY = 0.25, PassengerSeatOffsetZ = 0.5 }), Vector3.new(11.75, 20.25, 30.5), "all three")
		eq(position("after", { PassengerSeatOffsetX = 1.75 }), Vector3.new(11.75, 21, 31.5), "one axis")
		eq(position("after", { PassengerSeatOffsetX = 100, PassengerSeatOffsetY = "up", PassengerSeatOffsetZ = 0 / 0 }), Vector3.new(50, 21, 31.5), "clamp, wrong type and NaN")
		local seat = addPassengerSeat("after")(inst("Model", "Vehicle", {}), root)
		eq(seat.ClassName, "Seat", "stays a plain Seat"); eq(seat.Name, "PassengerSeat")
	end)

	-- ============================================================================= live Piercer, read-only
	local live = options.liveCategoriesRoot
	if live then
		local function firstModule(predicate)
			for _, category in ipairs(live:GetChildren()) do
				for _, item in ipairs(category:GetDescendants()) do
					if item:IsA("Model") and item:GetAttribute("ModuleId") and predicate(item) then return item:GetAttribute("ModuleId") end
				end
			end
			error("no live module matches")
		end
		local function piercerOnly() -- these parity tests describe the place before any other category exists
			for _, category in ipairs(live:GetChildren()) do
				if category:GetAttribute("FeatureFlag") ~= nil then return false end
			end
			return true
		end
		test("live: fixed Piercer action sequence, old vs new source on the real templates", function()
			local ids = {
				sidePods = "MODULE_SIDEPODS_LVL1",
				locked = firstModule(function(item) return item:GetAttribute("SourceCockpitId") == "bruiser_06" and item:GetAttribute("EnginePosition") == "Front" and item:GetAttribute("RetiredFromCatalog") ~= true end),
			}
			local old = piercerSequence(garage("before", live), ids)
			local new = piercerSequence(garage("after", live, {}), ids)
			old.flagCalls = new.flagCalls
			assertDeepEqual(old, new, "sequence")
			eq(new.flagCalls, 0, "FeatureFlags calls")
			eq(new.log[1], "buy01=true|Cockpit instance purchased."); eq(new.log[2], "unaffordable=false|Not enough cash."); eq(new.log[3], "unknownCockpit=false|Cockpit not found.")
			eq(new.log[10], "moduleLocked=false|Buy Zenith before buying this module family."); eq(new.log[11], "moduleBuy=true|Module purchased and equipped.")
			eq(new.log[13], "buy02=true|Cockpit instance purchased."); eq(new.log[14], "garageFull=false|Garage full. Buy more garage space to store more vehicles.")
		end)
		test("live: every Piercer cockpit keeps the legacy four defaults and passes the purchase pre-check", function()
			local h = garage("after", live, {})
			local cockpits = 0
			for _, category in ipairs(live:GetChildren()) do
				if category:GetAttribute("CategoryId") == "bruiser" then
					for _, cockpit in ipairs(category:GetDescendants()) do
						if cockpit:IsA("Model") and cockpit:GetAttribute("CockpitId") then
							cockpits += 1
							local legacy = h.defaultModuleIdsForCockpit(cockpit)
							local map, optional = h.defaultSlotModuleIdsForCockpit(cockpit)
							assertDeepEqual(map, { Engine1 = legacy.Engine, Engine2 = legacy.RearEngine, Stabilisers = legacy.Stabilisers, Boost = legacy.Boost }, cockpit.Name)
							eq(count(map), 4, cockpit.Name .. " entries"); eq(count(optional), 0, cockpit.Name .. " optional")
							eq(h.cockpitDefaultsInstallable("bruiser", cockpit), true, cockpit.Name .. " pre-check")
							eq(cockpit:GetAttribute("CategoryId"), "bruiser", cockpit.Name .. " CategoryId")
							eq(h.categoryFolderOf(cockpit), category, cockpit.Name .. " category folder")
							eq(h.categoryFlagEnabled(h.categoryFolderOf(cockpit)), true, cockpit.Name .. " flag gate")
						end
					end
				end
			end
			eq(cockpits, 6, "Piercer cockpits"); eq(h.flagCalls, 0, "FeatureFlags calls")
		end)
		test("live: every Piercer module has the same price, source cockpit and lock message old vs new", function()
			local old, new = garage("before", live), garage("after", live, {})
			local modules = 0
			for _, category in ipairs(live:GetChildren()) do
				if category:GetAttribute("CategoryId") == "bruiser" then
					for _, module in ipairs(category:GetDescendants()) do
						if module:IsA("Model") and module:GetAttribute("ModuleId") then
							modules += 1
							eq(new.lookup.modulePurchasePrice(module), old.lookup.modulePurchasePrice(module), module.Name .. " price")
							local oldId, oldCockpit = old.lookup.findSourceCockpit(nil, module)
							local newId, newCockpit = new.lookup.findSourceCockpit(nil, module)
							eq(newId, oldId, module.Name .. " source id"); eq(newCockpit, oldCockpit, module.Name .. " source cockpit")
							local profile = { CurrentCategory = "bruiser", OwnedCockpits = {}, OwnedCockpitInstances = {} }
							eq(new.lookup.moduleLockedMessage(profile, module), old.lookup.moduleLockedMessage(profile, module), module.Name .. " lock message")
							eq(new.categoryFlagEnabled(new.categoryFolderOf(module)), true, module.Name .. " flag gate")
						end
					end
				end
			end
			eq(modules, 116, "Piercer modules")
		end)
		test("live: catalogue built from the real templates is identical old vs new (upgrades and cosmetics faked alike)", function()
			assert(piercerOnly(), "skipped meaningfully only before a flagged category exists; a flagged category is present")
			local oldCatalog = catalogService("before", garage("before", live), live)()
			local newCatalog = catalogService("after", garage("after", live, {}), live)()
			assertDeepEqual(oldCatalog, newCatalog, "catalogue")
			eq(hasKeyAnywhere(newCatalog, "RailLabel"), false, "RailLabel key"); eq(hasKeyAnywhere(newCatalog, "CardTitle"), false, "CardTitle key")
			eq(#newCatalog.Categories, 1, "categories"); eq(#newCatalog.Categories[1].Cockpits, 6, "cockpits"); eq(#newCatalog.Categories[1].Slots, 8, "slots")
		end)
	end

	return { failures = failures, results = results }
end
