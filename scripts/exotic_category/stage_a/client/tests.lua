-- Exotic Stage A client tests. Pure: sources are loaded with loadstring and run against fakes (setfenv).
-- No game mutation, no require of a gameplay module, no remote call.
--
-- Call: tests(sources) -> { failures = n, results = { "PASS ..." | "FAIL ..." } }
--   sources.<Name>         AFTER source text of: GarageModuleCardViewModel, GarageVehiclePreviewProfile,
--                          VehiclePerformanceResolver, PreviewCameraClient, GarageWorkspaceUI, GarageUI, GarageBrowserUI.
--   sources.Before.<Name>  optional BEFORE source text of the same scripts (the exotic-before blobs, or the live
--                          Source read before APPLY). When given, Piercer results are compared before against after.
return function(sources)
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local before = sources.Before or {}

	local function eq(a, b, where)
		where = where or "value"
		if type(a) ~= "table" or type(b) ~= "table" then
			assert(a == b, where .. ": " .. tostring(a) .. " ~= " .. tostring(b))
			return
		end
		for k, v in pairs(a) do eq(v, b[k], where .. "." .. tostring(k)) end
		for k in pairs(b) do assert(a[k] ~= nil, where .. "." .. tostring(k) .. " missing on the left") end
	end
	local function count(t) local n = 0; for _ in pairs(t) do n += 1 end; return n end
	local function keys(t) local list = {}; for k in pairs(t) do table.insert(list, tostring(k)) end; table.sort(list); return table.concat(list, ",") end

	-- Fake instance tree: any child, WaitForChild or FindFirstChild returns a named node; overrides replace a node by name.
	local function fakeTree(overrides)
		local names = {}
		local function node(name)
			if overrides and overrides[name] ~= nil then return overrides[name] end
			local children = {}
			local item = {}
			names[item] = name
			local function child(_, childName)
				local found = children[childName]
				if found == nil then found = node(childName); children[childName] = found end
				return found
			end
			return setmetatable(item, { __index = function(_, key)
				if key == "WaitForChild" or key == "FindFirstChild" or key == "GetService" then return child end
				if key == "GetAttribute" then return function() return nil end end
				if key == "IsA" then return function() return false end end
				return child(nil, key)
			end })
		end
		return node("game"), names
	end
	local function load(source, modules, overrides)
		local fn = assert(loadstring(assert(source, "source missing")))
		local fakeGame, names = fakeTree(overrides)
		local env = { game = fakeGame, script = fakeGame, require = function(target)
			local module = modules and modules[names[target] or ""]
			return assert(module, "unexpected require: " .. tostring(names[target]))
		end }
		setfenv(fn, setmetatable(env, { __index = getfenv(0) }))
		return fn()
	end

	-- Catalogue-shaped test data (ids and attribute names as live; numbers are test values).
	local function piercerCockpit(n)
		local id = string.format("%02d", n)
		return {
			CockpitId = "bruiser_" .. id, CategoryId = "bruiser", DisplayName = "Piercer " .. id, Price = 1000 * n, Score = n,
			DefaultEngineModuleId = "MODULE_ENGINE_BRUISER_" .. id .. "_STANDARD",
			DefaultFrontEngineModuleId = "MODULE_ENGINE_BRUISER_" .. id .. "_STANDARD",
			DefaultRearEngineModuleId = "MODULE_ENGINE_B_BRUISER_" .. id .. "_STANDARD",
			DefaultEngineBModuleId = "MODULE_ENGINE_B_BRUISER_" .. id .. "_STANDARD",
			DefaultStabilisersModuleId = "MODULE_STABILISER_BRUISER_" .. id .. "_STANDARD",
			DefaultStabiliserModuleId = "MODULE_STABILISER_BRUISER_" .. id .. "_STANDARD",
			DefaultBoostModuleId = "MODULE_BOOST_BRUISER_" .. id .. "_STANDARD",
			DefaultPrimaryColor = Color3.fromRGB(10, 20, 30), DefaultSecondaryColor = Color3.fromRGB(40, 50, 60),
			StandardAudioProfileId = "GENERIC_STANDARD_AUDIO", V2Materialised = true,
		}
	end
	local bodyDefaults = {
		FrontBody = "MODULE_FRONTBODY_EXOTIC_03", RearBody = "MODULE_REARBODY_EXOTIC_03", SidePods = "MODULE_SIDEPODS_EXOTIC_03",
		FrontBumper = "MODULE_FRONTBUMPER_EXOTIC_03", RearBumper = "MODULE_REARBUMPER_EXOTIC_03", RearSpoiler = "MODULE_REARSPOILER_EXOTIC_03",
	}
	local function exoticCockpit()
		local cockpit = {
			CockpitId = "exotic_03", CategoryId = "exotic", DisplayName = "Wedge", Price = 440000, Score = 1000,
			DefaultEngineModuleId = "MODULE_ENGINE_EXOTIC_03_STANDARD", DefaultFrontEngineModuleId = "MODULE_ENGINE_EXOTIC_03_STANDARD",
			DefaultRearEngineModuleId = "MODULE_ENGINE_B_EXOTIC_03_STANDARD", DefaultEngineBModuleId = "MODULE_ENGINE_B_EXOTIC_03_STANDARD",
			DefaultStabilisersModuleId = "MODULE_STABILISER_EXOTIC_03_STANDARD", DefaultStabiliserModuleId = "MODULE_STABILISER_EXOTIC_03_STANDARD",
			DefaultBoostModuleId = "MODULE_BOOST_EXOTIC_03_STANDARD",
			DefaultPrimaryColor = Color3.fromRGB(200, 20, 30),
		}
		for slotId, moduleId in pairs(bodyDefaults) do cockpit["Default" .. slotId .. "ModuleId"] = moduleId end
		return cockpit
	end
	local legacySlots = "Boost,Engine1,Engine2,Stabilisers"
	local tenSlots = "Boost,Engine1,Engine2,FrontBody,FrontBumper,RearBody,RearBumper,RearSpoiler,SidePods,Stabilisers"

	---------------------------------------------------------------------------------------------------------------
	-- GarageModuleCardViewModel
	---------------------------------------------------------------------------------------------------------------
	local sourceNames = { bruiser_01 = "Piercer Viper", bruiser_02 = "Piercer Forge", exotic_01 = "Exotic Spider", exotic_03 = "Exotic Wedge" }
	local sourceRatings = { bruiser_01 = 525, bruiser_02 = 202, exotic_01 = 220, exotic_03 = 540 }
	local function shopContext(modules, owned)
		return {
			Modules = modules,
			IsLocked = function(m) local source = tostring(m.SourceCockpitId or ""); return source ~= "" and not owned[source] end,
			SourceVehicleName = function(m) return sourceNames[tostring(m.SourceCockpitId or "")] or ((m.CategoryName or "Piercer") .. " Vehicle") end,
			SourceRating = function(m) return sourceRatings[tostring(m.SourceCockpitId or "")] or 0 end,
			OwnedCount = function(id) return id == "MODULE_ENGINE_BRUISER_01_STANDARD" and 2 or 0 end,
			Rating = function(m) return m.TestRating or 0 end,
		}
	end
	local function piercerModules()
		local list = {}
		for _, family in ipairs({ "02", "01" }) do
			for index, variant in ipairs({ "Power", "Standard", "Lightweight" }) do
				table.insert(list, {
					ModuleId = "MODULE_ENGINE_BRUISER_" .. family .. "_" .. string.upper(variant), DisplayName = "Engine " .. variant,
					ModuleType = "Engine", ModuleFolder = "Engines", SourceCockpitId = "bruiser_" .. family, VariantName = variant,
					VariantOrder = index * 10, Price = variant == "Standard" and 0 or 4800, TestRating = 300 + index,
				})
			end
		end
		-- Accessories: the server derives "Level n" for LVL ids; the card has always shown "Standard".
		table.insert(list, { ModuleId = "MODULE_FRONTBUMPER_LVL2", DisplayName = "Front Bumper Lvl 2", ModuleType = "FrontBumper", SourceCockpitId = "", VariantName = "Level 2", VariantOrder = 102, Price = 12000, TestRating = 530 })
		table.insert(list, { ModuleId = "MODULE_FRONTBUMPER_LVL1", DisplayName = "Front Bumper Lvl 1", ModuleType = "FrontBumper", SourceCockpitId = "", VariantName = "Level 1", VariantOrder = 101, Price = 6500, TestRating = 528 })
		return list
	end
	local rowFields = { "Id", "State", "Status", "Variant", "VehicleName", "Rating", "SourceRating", "Locked", "Price", "OwnerVehicleId" }
	local function sameRows(a, b)
		assert(#a == #b, "row count " .. #a .. " ~= " .. #b)
		for index, row in ipairs(a) do
			for _, field in ipairs(rowFields) do eq(row[field], b[index][field], "row " .. index .. "." .. field) end
			assert(row.Module == b[index].Module and row.Item == b[index].Item, "row " .. index .. " module or item")
		end
	end
	local VM = load(sources.GarageModuleCardViewModel)
	local VMBefore = before.GarageModuleCardViewModel and load(before.GarageModuleCardViewModel)

	test("cards: Piercer shop rows keep order, text and fields", function()
		local modules = piercerModules()
		local rows = VM.Shop(shopContext(modules, { bruiser_02 = true }))
		local order = {}
		for _, row in ipairs(rows) do table.insert(order, row.Id) end
		eq(order, {
			"MODULE_FRONTBUMPER_LVL1", "MODULE_FRONTBUMPER_LVL2",
			"MODULE_ENGINE_BRUISER_02_STANDARD", "MODULE_ENGINE_BRUISER_02_LIGHTWEIGHT", "MODULE_ENGINE_BRUISER_02_POWER",
			"MODULE_ENGINE_BRUISER_01_STANDARD", "MODULE_ENGINE_BRUISER_01_LIGHTWEIGHT", "MODULE_ENGINE_BRUISER_01_POWER",
		}, "order")
		eq({ rows[1].VehicleName, rows[1].Variant, rows[1].Status, rows[1].State }, { "Piercer Vehicle", "Standard", "OWNED x0", "Shop" }, "accessory")
		eq({ rows[5].VehicleName, rows[5].Variant, rows[5].Price, rows[5].Rating }, { "Piercer Forge", "Power", 4800, 301 }, "family")
		eq({ rows[6].State, rows[6].Status, rows[6].Locked }, { "Locked", "BUY PIERCER VIPER TO UNLOCK", true }, "locked")
		for index, row in ipairs(rows) do
			assert(row.Title == row.VehicleName, "row " .. index .. " title is not today's title")
			assert(row.Tag == row.Variant, "row " .. index .. " tag is not today's tag")
		end
		if VMBefore then sameRows(rows, VMBefore.Shop(shopContext(modules, { bruiser_02 = true }))) end
		-- The variant of a module without a CardTitle is found exactly as before, name search included.
		local odd = {
			{ ModuleId = "A", DisplayName = "Power Bumper", VariantName = "Level 1" }, { ModuleId = "B", DisplayName = "Lightweight Pods", VariantName = "" },
			{ ModuleId = "MODULE_POWER_X" }, { ModuleId = "C", DisplayName = "Plain", VariantName = "Wedge" }, { ModuleId = "D", DisplayName = "Lightweight Power", CardTitle = "" },
		}
		eq({ VM.Variant(odd[1]), VM.Variant(odd[2]), VM.Variant(odd[3]), VM.Variant(odd[4]), VM.Variant(odd[5]), VM.Variant(nil) }, { "Power", "Lightweight", "Power", "Standard", "Lightweight", "Standard" }, "variant")
		if VMBefore then
			for index, module in ipairs(odd) do eq(VM.Variant(module), VMBefore.Variant(module), "variant parity " .. index) end
			for _, module in ipairs(modules) do eq(VM.Variant(module), VMBefore.Variant(module), "variant parity " .. module.ModuleId) end
		end
	end)

	local ownedInstances = {
		I1 = { TemplateId = "MODULE_ENGINE_BRUISER_01_STANDARD", EquippedVehicleId = "V1" },
		I2 = { TemplateId = "MODULE_ENGINE_BRUISER_01_POWER" },
		I3 = { TemplateId = "MODULE_ENGINE_BRUISER_02_LIGHTWEIGHT", EquippedVehicleId = "V2" },
		I4 = { TemplateId = "MODULE_ENGINE_BRUISER_01_POWER", EquippedVehicleId = "V1" },
		I5 = { TemplateId = "MODULE_FRONTBUMPER_LVL1" },
		I6 = { TemplateId = "NOT_IN_CATEGORY" },
	}
	local function ownedContext(resolve)
		return {
			Instances = ownedInstances,
			Slot = { SlotId = "Engine1", ModuleType = "Engine" },
			ResolveModule = resolve,
			Fits = function(m, s) return m.ModuleType == s.ModuleType end,
			CurrentVehicleId = "V1", InstalledInstanceId = "I1",
			VehicleName = function(id) return id == "V2" and "Forge" or "Viper" end,
			SourceVehicleName = function(m) return sourceNames[tostring(m.SourceCockpitId or "")] or "Piercer Vehicle" end,
			Rating = function(m) return m.TestRating or 0 end,
		}
	end
	test("cards: Piercer owned rows keep order, text and fields", function()
		local byId = {}
		for _, m in ipairs(piercerModules()) do byId[m.ModuleId] = m end
		local rows = VM.Owned(ownedContext(function(id) return byId[id] end))
		local order = {}
		for _, row in ipairs(rows) do table.insert(order, row.Id .. ":" .. row.State .. ":" .. row.Status) end
		eq(order, { "I1:Equipped:EQUIPPED", "I2:Available:AVAILABLE", "I4:Available:AVAILABLE", "I3:InUse:IN USE BY FORGE" }, "order")
		for index, row in ipairs(rows) do
			assert(row.Title == row.VehicleName and row.Tag == row.Variant, "row " .. index .. " text changed")
		end
		if VMBefore then sameRows(rows, VMBefore.Owned(ownedContext(function(id) return byId[id] end))) end
	end)

	test("cards: CardTitle is the title when present; tags read sensibly", function()
		local modules = {
			{ ModuleId = "MODULE_ENGINE_EXOTIC_03_POWER", DisplayName = "Mono Turbine", CardTitle = "Mono Turbine", ModuleType = "Engine", SourceCockpitId = "exotic_03", VariantName = "Power", Price = 52800, CategoryName = "Exotic" },
			{ ModuleId = "MODULE_ENGINE_EXOTIC_03_STANDARD", DisplayName = "Mono Turbine", CardTitle = "Mono Turbine", ModuleType = "Engine", SourceCockpitId = "exotic_03", VariantName = "Standard", Price = 0, CategoryName = "Exotic" },
			{ ModuleId = "MODULE_ENGINE_EXOTIC_01_LIGHTWEIGHT", DisplayName = "Twin Spool", CardTitle = "Twin Spool", ModuleType = "Engine", SourceCockpitId = "exotic_01", VariantName = "Lightweight", Price = 6000, CategoryName = "Exotic" },
			-- Body parts: no source cockpit. The server sends a derived "Standard" unless the model has a VariantName.
			{ ModuleId = "MODULE_FRONTBODY_EXOTIC_01", DisplayName = "Shovel Nose", CardTitle = "Shovel Nose", ModuleType = "FrontBody", SourceCockpitId = "", VariantName = "Standard", Price = 8000, CategoryName = "Exotic" },
			{ ModuleId = "MODULE_FRONTBODY_EXOTIC_02", DisplayName = "Power Dome", CardTitle = "Power Dome", ModuleType = "FrontBody", SourceCockpitId = "", VariantName = "Standard", Price = 11000, CategoryName = "Exotic" },
			{ ModuleId = "MODULE_FRONTBODY_EXOTIC_03", DisplayName = "Droplet Nose", CardTitle = "Droplet Nose", ModuleType = "FrontBody", SourceCockpitId = "", VariantName = "Wedge", Price = 14000, CategoryName = "Exotic" },
			{ ModuleId = "MODULE_FRONTBODY_LVL2", DisplayName = "Needle Nose", CardTitle = "Needle Nose", ModuleType = "FrontBody", SourceCockpitId = "", VariantName = "Level 2", Price = 18000, CategoryName = "Exotic" },
			{ ModuleId = "MODULE_FRONTBODY_PLAIN", DisplayName = "Plain Nose", CardTitle = "", ModuleType = "FrontBody", SourceCockpitId = "", VariantName = "Wedge", Price = 100, CategoryName = "Exotic" },
			-- A kit name as the tag, and no variant at all, on parts whose names contain "power" or "lightweight".
			{ ModuleId = "MODULE_FRONTBODY_EXOTIC_04", DisplayName = "Power Scoop", CardTitle = "Power Scoop", ModuleType = "FrontBody", SourceCockpitId = "", VariantName = "Track", Price = 18000, CategoryName = "Exotic" },
			{ ModuleId = "MODULE_FRONTBODY_EXOTIC_05", DisplayName = "Lightweight Beak", CardTitle = "Lightweight Beak", ModuleType = "FrontBody", SourceCockpitId = "", VariantName = "", Price = 23000, CategoryName = "Exotic" },
		}
		local rows = VM.Shop(shopContext(modules, { exotic_03 = true }))
		local byId = {}
		for _, row in ipairs(rows) do byId[row.Id] = row end
		assert(#rows == #modules, "row count")
		eq({ byId.MODULE_ENGINE_EXOTIC_03_POWER.Title, byId.MODULE_ENGINE_EXOTIC_03_POWER.Tag }, { "Mono Turbine", "Power" }, "core power")
		eq({ byId.MODULE_ENGINE_EXOTIC_03_STANDARD.Title, byId.MODULE_ENGINE_EXOTIC_03_STANDARD.Tag }, { "Mono Turbine", "Standard" }, "core standard")
		eq({ byId.MODULE_FRONTBODY_EXOTIC_01.Title, byId.MODULE_FRONTBODY_EXOTIC_01.Tag }, { "Shovel Nose", "Standard" }, "body")
		-- A title containing "power" must not make a body part read as the Power variant.
		eq({ byId.MODULE_FRONTBODY_EXOTIC_02.Title, byId.MODULE_FRONTBODY_EXOTIC_02.Tag }, { "Power Dome", "Standard" }, "body named power")
		eq({ byId.MODULE_FRONTBODY_EXOTIC_03.Title, byId.MODULE_FRONTBODY_EXOTIC_03.Tag }, { "Droplet Nose", "Wedge" }, "body with a kit name")
		eq({ byId.MODULE_FRONTBODY_LVL2.Title, byId.MODULE_FRONTBODY_LVL2.Tag }, { "Needle Nose", "Standard" }, "never Level n")
		-- The tag and the sort key of a titled module never come from a search of its name.
		eq({ byId.MODULE_FRONTBODY_EXOTIC_02.Variant, byId.MODULE_FRONTBODY_EXOTIC_03.Variant }, { "Standard", "Standard" }, "sort key of a titled body part")
		eq({ byId.MODULE_FRONTBODY_EXOTIC_04.Title, byId.MODULE_FRONTBODY_EXOTIC_04.Tag, byId.MODULE_FRONTBODY_EXOTIC_04.Variant }, { "Power Scoop", "Track", "Standard" }, "kit tag on a part named power")
		eq({ byId.MODULE_FRONTBODY_EXOTIC_05.Title, byId.MODULE_FRONTBODY_EXOTIC_05.Tag, byId.MODULE_FRONTBODY_EXOTIC_05.Variant }, { "Lightweight Beak", "Standard", "Standard" }, "no variant on a part named lightweight")
		eq({ byId.MODULE_ENGINE_EXOTIC_03_POWER.Variant, byId.MODULE_ENGINE_EXOTIC_01_LIGHTWEIGHT.Variant }, { "Power", "Lightweight" }, "core sort keys")
		-- No CardTitle: today's title and today's tag, whatever VariantName says.
		eq({ byId.MODULE_FRONTBODY_PLAIN.Title, byId.MODULE_FRONTBODY_PLAIN.Tag }, { "Exotic Vehicle", "Standard" }, "no CardTitle")
		-- The lock line and the sort keys still use the source vehicle.
		local locked = byId.MODULE_ENGINE_EXOTIC_01_LIGHTWEIGHT
		eq({ locked.Status, locked.VehicleName, locked.Title, locked.Variant }, { "BUY EXOTIC SPIDER TO UNLOCK", "Exotic Spider", "Twin Spool", "Lightweight" }, "locked")
		assert(rows[#rows] == locked, "locked rows sort last")
		for _, row in ipairs(rows) do
			assert(row.Variant == "Standard" or row.Variant == "Lightweight" or row.Variant == "Power", "sort key variant changed: " .. tostring(row.Variant))
		end
	end)

	---------------------------------------------------------------------------------------------------------------
	-- GarageVehiclePreviewProfile (dealership preview modules)
	---------------------------------------------------------------------------------------------------------------
	local Profiles = load(sources.GarageVehiclePreviewProfile)
	local ProfilesBefore = before.GarageVehiclePreviewProfile and load(before.GarageVehiclePreviewProfile)
	local function factory(module, cockpit)
		return module.Factory({ CategoryId = cockpit.CategoryId }, { CockpitId = cockpit.CockpitId, CategoryId = cockpit.CategoryId, Cockpit = cockpit, Performance = { Overall = { PerformanceIndex = 1 } } })
	end

	test("preview: Piercer default modules are the same four", function()
		for n = 1, 6 do
			local cockpit = piercerCockpit(n)
			local id = string.format("%02d", n)
			local profile = factory(Profiles, cockpit)
			eq(profile.InstalledModules, {
				Engine1 = "MODULE_ENGINE_BRUISER_" .. id .. "_STANDARD", Engine2 = "MODULE_ENGINE_B_BRUISER_" .. id .. "_STANDARD",
				Stabilisers = "MODULE_STABILISER_BRUISER_" .. id .. "_STANDARD", Boost = "MODULE_BOOST_BRUISER_" .. id .. "_STANDARD",
			}, "installed")
			assert(keys(profile.ModuleColors) == legacySlots, "module colours " .. keys(profile.ModuleColors))
			if ProfilesBefore then eq(profile, factory(ProfilesBefore, cockpit), "factory profile") end
		end
		-- Legacy fallbacks: one engine id feeds both engine slots; a missing default leaves the slot out.
		local sparse = { CockpitId = "x", DefaultEngineModuleId = "E", DefaultStabiliserModuleId = "S" }
		eq(factory(Profiles, sparse).InstalledModules, { Engine1 = "E", Engine2 = "E", Stabilisers = "S" }, "sparse")
		if ProfilesBefore then eq(factory(Profiles, sparse), factory(ProfilesBefore, sparse), "sparse profile") end
		eq(factory(Profiles, {}).InstalledModules, {}, "empty cockpit")
	end)

	test("preview: Exotic default modules are all ten", function()
		local profile = factory(Profiles, exoticCockpit())
		assert(keys(profile.InstalledModules) == tenSlots, keys(profile.InstalledModules))
		assert(keys(profile.ModuleColors) == tenSlots, keys(profile.ModuleColors))
		for slotId, moduleId in pairs(bodyDefaults) do assert(profile.InstalledModules[slotId] == moduleId, slotId) end
		eq({ profile.InstalledModules.Engine1, profile.InstalledModules.Engine2 }, { "MODULE_ENGINE_EXOTIC_03_STANDARD", "MODULE_ENGINE_B_EXOTIC_03_STANDARD" }, "engines")
		eq({ profile.CurrentCategory, profile.CurrentCockpit, profile.PreviewKind }, { "exotic", "exotic_03", "Factory" }, "identity")
	end)

	test("preview: legacy names never make extra slots; empty optional defaults are skipped", function()
		local cockpit = exoticCockpit()
		cockpit.DefaultEngine1ModuleId = "IGNORED"; cockpit.DefaultEngine2ModuleId = "IGNORED"
		cockpit.DefaultSidePodsModuleId = ""; cockpit.DefaultModuleId = "IGNORED"; cockpit.DefaultNeonColor = Color3.new(1, 1, 1)
		local installed = factory(Profiles, cockpit).InstalledModules
		assert(keys(installed) == "Boost,Engine1,Engine2,FrontBody,FrontBumper,RearBody,RearBumper,RearSpoiler,Stabilisers", keys(installed))
		assert(installed.Engine1 == "MODULE_ENGINE_EXOTIC_03_STANDARD" and installed.Engine2 == "MODULE_ENGINE_B_EXOTIC_03_STANDARD", "legacy engines overridden")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- VehiclePerformanceResolver (dealership rating defaults, module rating reference)
	---------------------------------------------------------------------------------------------------------------
	local function catalogueData()
		local data = { Cockpits = {}, Modules = {} }
		local function module(id, fields)
			local record = { ModuleId = id, Name = id, IsVehicleDefinition = true, Score = 1 }
			for k, v in pairs(fields or {}) do record[k] = v end
			data.Modules[id] = record
		end
		for n = 1, 2 do
			local cockpit = piercerCockpit(n); cockpit.Name = "COCKPIT_BRUISER_0" .. n; cockpit.IsVehicleDefinition = true
			data.Cockpits[cockpit.CockpitId] = cockpit
			local id = "0" .. n
			module("MODULE_ENGINE_BRUISER_" .. id .. "_STANDARD", { ModuleType = "Engine", ModuleSlot = "Engine", ModuleFolder = "Engines", EnginePosition = "Front", RearEngine = false })
			module("MODULE_ENGINE_BRUISER_" .. id .. "_POWER", { ModuleType = "Engine", ModuleSlot = "Engine", ModuleFolder = "Engines", EnginePosition = "Front", RearEngine = false, Score = 7 })
			module("MODULE_ENGINE_B_BRUISER_" .. id .. "_STANDARD", { ModuleType = "Engine", ModuleSlot = "Engine", ModuleFolder = "Engines_B", EnginePosition = "Rear", RearEngine = true })
			module("MODULE_STABILISER_BRUISER_" .. id .. "_STANDARD", { ModuleType = "Stabilisers", ModuleSlot = "Stabilisers", ModuleFolder = "Stabilisers" })
			module("MODULE_BOOST_BRUISER_" .. id .. "_STANDARD", { ModuleType = "Boost", ModuleSlot = "Boost", ModuleFolder = "Boost" })
		end
		module("MODULE_FRONTBUMPER_LVL1", { ModuleType = "FrontBumper", ModuleSlot = "FrontBumper", ModuleFolder = "FrontBumpers", Score = 3 })
		local exotic = exoticCockpit(); exotic.Name = "COCKPIT_EXOTIC_03"; exotic.IsVehicleDefinition = true
		data.Cockpits.exotic_03 = exotic
		local reference = { RatingReferenceCockpitId = "exotic_03" }
		local function exoticModule(id, fields) for k, v in pairs(reference) do fields[k] = v end; module(id, fields) end
		exoticModule("MODULE_ENGINE_EXOTIC_03_STANDARD", { ModuleType = "Engine", ModuleSlot = "Engine", ModuleFolder = "Engines", EnginePosition = "Front", RearEngine = false })
		exoticModule("MODULE_ENGINE_B_EXOTIC_03_STANDARD", { ModuleType = "Engine", ModuleSlot = "Engine", ModuleFolder = "Engines_B", EnginePosition = "Rear", RearEngine = true })
		exoticModule("MODULE_ENGINE_B_EXOTIC_01_POWER", { ModuleType = "Engine", ModuleSlot = "Engine", ModuleFolder = "Engines_B", EnginePosition = "Rear", RearEngine = true, Score = 9 })
		exoticModule("MODULE_STABILISER_EXOTIC_03_STANDARD", { ModuleType = "Stabilisers", ModuleSlot = "Stabilisers", ModuleFolder = "Stabilisers" })
		exoticModule("MODULE_BOOST_EXOTIC_03_STANDARD", { ModuleType = "Boost", ModuleSlot = "Boost", ModuleFolder = "Boost" })
		for slotId, moduleId in pairs(bodyDefaults) do exoticModule(moduleId, { ModuleType = slotId, ModuleSlot = slotId }) end
		exoticModule("MODULE_FRONTBODY_EXOTIC_01", { ModuleType = "FrontBody", ModuleSlot = "FrontBody", ModuleFolder = "FrontBodies", Score = 5 })
		module("MODULE_REARBODY_RETIRED", { ModuleType = "RearBody", ModuleSlot = "RearBody", RetiredFromCatalog = true })
		module("MODULE_BAD_REFERENCE", { ModuleType = "FrontBody", ModuleSlot = "FrontBody", RatingReferenceCockpitId = "exotic_99" })
		return data
	end
	local function resolver(source)
		local data = catalogueData()
		local calls = {}
		local Catalog = {}
		function Catalog.Get(attribute, id, includeRetired)
			local index = attribute == "CockpitId" and data.Cockpits or attribute == "ModuleId" and data.Modules
			local record = index and index[tostring(id or "")]
			if record and (includeRetired or record.RetiredFromCatalog ~= true) then return record end
		end
		function Catalog.Resolve(attribute, value)
			if typeof(value) == "table" then return Catalog.Get(attribute, value[attribute], value.IsVehicleDefinition == true) end
			return Catalog.Get(attribute, value)
		end
		local modules = {
			VehicleDefinition = { Attribute = function(item, name) return item and item[name] end },
			VehicleCatalog = Catalog,
			PerformanceCalculator = { CloneRaw = function(raw) return raw end, AddRaw = function() end, Calculate = function(raw) return { Raw = raw, Overall = {} } end },
			PerformanceRuntime = { CalculateComponents = function(cockpit, list, allocations)
				local ids, score = {}, cockpit.Score or 0
				for _, item in ipairs(list) do table.insert(ids, item.ModuleId); score += item.Score or 0 end
				local result = { Cockpit = cockpit.CockpitId, Modules = ids, Allocations = allocations, Overall = { PerformanceIndex = score } }
				table.insert(calls, result)
				return result
			end },
			PerformanceUpgradeRuntime = { ApplyToModuleRaw = function() return {} end },
		}
		return load(source, modules), data, calls
	end
	local function ids(list) local out = {}; for _, item in ipairs(list) do table.insert(out, item.ModuleId) end; return out end

	test("rating: Piercer default build is the same four, in the same order", function()
		local R, data = resolver(sources.VehiclePerformanceResolver)
		local RB, dataBefore
		if before.VehiclePerformanceResolver then RB, dataBefore = resolver(before.VehiclePerformanceResolver) end
		for n = 1, 2 do
			-- Called as GarageUI calls it (server catalogue cockpit) and as ModuleRating calls it (generated record).
			for _, argument in ipairs({ piercerCockpit(n), data.Cockpits["bruiser_0" .. n], { CockpitId = "bruiser_0" .. n } }) do
				local template, modules, bySlot = R.DefaultBuild(nil, argument)
				assert(template == data.Cockpits["bruiser_0" .. n], "template")
				assert(#modules == 4 and keys(bySlot) == legacySlots, "defaults: " .. #modules .. " / " .. keys(bySlot))
				for slotId, expected in pairs({ Engine1 = "MODULE_ENGINE_BRUISER_0" .. n .. "_STANDARD", Engine2 = "MODULE_ENGINE_B_BRUISER_0" .. n .. "_STANDARD", Stabilisers = "MODULE_STABILISER_BRUISER_0" .. n .. "_STANDARD", Boost = "MODULE_BOOST_BRUISER_0" .. n .. "_STANDARD" }) do
					assert(bySlot[slotId].ModuleId == expected, slotId)
				end
				eq(R.Factory(nil, argument).Overall.PerformanceIndex, n + 4, "factory rating")
				if RB then
					local beforeArgument = argument == data.Cockpits["bruiser_0" .. n] and dataBefore.Cockpits["bruiser_0" .. n] or argument
					local _, modulesBefore = RB.DefaultBuild(nil, beforeArgument)
					eq(ids(modules), ids(modulesBefore), "module order")
					eq(R.Factory(nil, argument).Modules, RB.Factory(nil, beforeArgument).Modules, "factory order")
				end
			end
		end
	end)

	test("rating: a missing legacy default still fails with today's message", function()
		local R = resolver(sources.VehiclePerformanceResolver)
		local broken = piercerCockpit(1); broken.DefaultBoostModuleId = "MODULE_BOOST_MISSING"
		local template, modules, message = R.DefaultBuild(nil, broken)
		assert(template == nil and modules == nil and message == "Boost default not found: MODULE_BOOST_MISSING", tostring(message))
		local _, _, unknown = R.DefaultBuild(nil, { CockpitId = "nope" })
		assert(unknown == "Cockpit template not found", tostring(unknown))
		if before.VehiclePerformanceResolver then
			local RB = resolver(before.VehiclePerformanceResolver)
			eq({ RB.DefaultBuild(nil, broken) }, { R.DefaultBuild(nil, broken) }, "failure parity")
		end
	end)

	test("rating: Exotic default build is all ten", function()
		local R, data = resolver(sources.VehiclePerformanceResolver)
		for _, argument in ipairs({ exoticCockpit(), data.Cockpits.exotic_03, { CockpitId = "exotic_03" } }) do
			local template, modules, bySlot = R.DefaultBuild(nil, argument)
			assert(template == data.Cockpits.exotic_03, "template")
			assert(#modules == 10 and keys(bySlot) == tenSlots, "defaults: " .. #modules .. " / " .. keys(bySlot))
			for slotId, moduleId in pairs(bodyDefaults) do assert(bySlot[slotId].ModuleId == moduleId, slotId) end
			-- Optional defaults follow the four legacy ones in a fixed (sorted) order.
			local list = ids(modules)
			eq({ list[5], list[6], list[7], list[8], list[9], list[10] }, { bodyDefaults.FrontBody, bodyDefaults.FrontBumper, bodyDefaults.RearBody, bodyDefaults.RearBumper, bodyDefaults.RearSpoiler, bodyDefaults.SidePods }, "optional order")
			eq(R.Factory(nil, argument).Overall.PerformanceIndex, 1010, "factory rating")
		end
	end)

	test("rating: optional defaults are optional", function()
		local R = resolver(sources.VehiclePerformanceResolver)
		local cockpit = exoticCockpit()
		cockpit.DefaultSidePodsModuleId = "MODULE_SIDEPODS_MISSING"      -- not in the catalogue: skipped
		cockpit.DefaultRearBodyModuleId = "MODULE_REARBODY_RETIRED"      -- retired: skipped
		cockpit.DefaultFrontBumperModuleId = ""                          -- empty here: the generated record supplies it
		cockpit.DefaultEngine1ModuleId = "MODULE_ENGINE_BRUISER_01_POWER" -- legacy slot: ignored
		local template, modules, bySlot = R.DefaultBuild(nil, cockpit)
		assert(template ~= nil, "optional default must not fail the build")
		assert(#modules == 8 and keys(bySlot) == "Boost,Engine1,Engine2,FrontBody,FrontBumper,RearBumper,RearSpoiler,Stabilisers", #modules .. " / " .. keys(bySlot))
		assert(bySlot.Engine1.ModuleId == "MODULE_ENGINE_EXOTIC_03_STANDARD" and bySlot.FrontBumper.ModuleId == bodyDefaults.FrontBumper, "values")
	end)

	test("rating: module reference is bruiser_01 unless the module names one", function()
		local R, _, calls = resolver(sources.VehiclePerformanceResolver)
		-- Piercer engine: swapped into the bruiser_01 build.
		assert(R.ModuleRating(nil, { ModuleId = "MODULE_ENGINE_BRUISER_02_POWER" }) == 1 + 7 + 3, "piercer engine rating")
		local call = calls[#calls]
		assert(call.Cockpit == "bruiser_01" and #call.Modules == 4, "piercer reference")
		assert(table.find(call.Modules, "MODULE_ENGINE_BRUISER_02_POWER") and not table.find(call.Modules, "MODULE_ENGINE_BRUISER_01_STANDARD"), "piercer swap")
		-- Piercer accessory: appended to the bruiser_01 build.
		assert(R.ModuleRating(nil, { ModuleId = "MODULE_FRONTBUMPER_LVL1" }) == 1 + 4 + 3, "piercer accessory rating")
		call = calls[#calls]
		assert(call.Cockpit == "bruiser_01" and #call.Modules == 5 and call.Modules[5] == "MODULE_FRONTBUMPER_LVL1", "piercer append")
		-- Exotic body part: swapped into the ten-module exotic_03 build.
		assert(R.ModuleRating(nil, { ModuleId = "MODULE_FRONTBODY_EXOTIC_01" }) == 1000 + 9 + 5, "exotic body rating")
		call = calls[#calls]
		assert(call.Cockpit == "exotic_03" and #call.Modules == 10, "exotic reference")
		assert(table.find(call.Modules, "MODULE_FRONTBODY_EXOTIC_01") and not table.find(call.Modules, bodyDefaults.FrontBody), "exotic body swap")
		-- Exotic rear engine: replaces the reference Engine2 only.
		assert(R.ModuleRating(nil, { ModuleId = "MODULE_ENGINE_B_EXOTIC_01_POWER" }) == 1000 + 9 + 9, "exotic engine rating")
		call = calls[#calls]
		assert(call.Cockpit == "exotic_03" and #call.Modules == 10 and not table.find(call.Modules, "MODULE_ENGINE_B_EXOTIC_03_STANDARD") and table.find(call.Modules, "MODULE_ENGINE_EXOTIC_03_STANDARD"), "exotic engine swap")
		-- A named reference that is not in the catalogue rates 0 (badge hidden), as an unknown reference does today.
		assert(R.ModuleRating(nil, { ModuleId = "MODULE_BAD_REFERENCE" }) == 0, "bad reference")
		assert(R.ModuleRating(nil, { ModuleId = "NOT_A_MODULE" }) == 0, "unknown module")
		if before.VehiclePerformanceResolver then
			local RB, _, callsBefore = resolver(before.VehiclePerformanceResolver)
			for _, id in ipairs({ "MODULE_ENGINE_BRUISER_02_POWER", "MODULE_ENGINE_B_BRUISER_02_STANDARD", "MODULE_STABILISER_BRUISER_01_STANDARD", "MODULE_FRONTBUMPER_LVL1" }) do
				R.ClearCache(); RB.ClearCache()
				eq(R.ModuleRating(nil, { ModuleId = id }, { V2UpgradePoints = { A = 1 } }), RB.ModuleRating(nil, { ModuleId = id }, { V2UpgradePoints = { A = 1 } }), id)
				eq(calls[#calls].Modules, callsBefore[#callsBefore].Modules, id .. " module order")
				eq(calls[#calls].Cockpit, callsBefore[#callsBefore].Cockpit, id .. " reference")
			end
		end
	end)

	---------------------------------------------------------------------------------------------------------------
	-- PreviewCameraClient (slot to view map)
	---------------------------------------------------------------------------------------------------------------
	test("camera: new slots have views; the eleven existing entries are unchanged", function()
		local Camera = load(sources.PreviewCameraClient)
		local expected = { ALL = "Front45", Cockpit = "Front45", THRUST_COLOR = "Front45", Engine1 = "Front45", Stabilisers = "Side", SidePods = "Side", Engine2 = "Rear45", RearSpoiler = "Rear45", Boost = "Rear", RearBumper = "Rear", FrontBumper = "Front" }
		if before.PreviewCameraClient then eq(load(before.PreviewCameraClient).ViewBySection, expected, "before map") end
		expected.FrontBody = "Front"; expected.RearBody = "Rear45"
		eq(Camera.ViewBySection, expected, "view map")
		for _, view in pairs(Camera.ViewBySection) do assert(Camera.YawAttributeByView[view] and Camera.YawFallbackByView[view], "view without yaw: " .. view) end
	end)

	---------------------------------------------------------------------------------------------------------------
	-- GarageWorkspaceUI artwork rows, filtered the way GarageUI filters them (a row shows only for a slot the category has)
	---------------------------------------------------------------------------------------------------------------
	local liveArtwork = {
		All = { DisplayName = "All", Image = "rbxassetid://81870436149298", ShowInBuild = false, ShowInCustomise = true, SortOrder = 10, TargetId = "ALL" },
		Cockpit = { DisplayName = "Cockpit", Image = "rbxassetid://113886075743589", ShowInBuild = false, ShowInCustomise = true, SortOrder = 20, TargetId = "Cockpit" },
		ThrustColour = { DisplayName = "Thrust Colour", Image = "rbxassetid://116894552982899", ShowInBuild = false, ShowInCustomise = true, SortOrder = 30, TargetId = "THRUST_COLOR" },
		FrontEngine = { DisplayName = "Front Engine", Image = "rbxassetid://75624529535039", ShowInBuild = true, ShowInCustomise = true, SortOrder = 40, TargetId = "Engine1" },
		RearEngine = { DisplayName = "Rear Engine", Image = "rbxassetid://100594986362095", ShowInBuild = true, ShowInCustomise = true, SortOrder = 50, TargetId = "Engine2" },
		Stabilisers = { DisplayName = "Stabilisers", Image = "rbxassetid://102447215741079", ShowInBuild = true, ShowInCustomise = true, SortOrder = 60, TargetId = "Stabilisers" },
		Boost = { DisplayName = "Boost", Image = "rbxassetid://87508389212440", ShowInBuild = true, ShowInCustomise = true, SortOrder = 70, TargetId = "Boost" },
		FrontBumper = { DisplayName = "Front Bumper", Image = "rbxassetid://76594522686468", ShowInBuild = true, ShowInCustomise = true, SortOrder = 80, TargetId = "FrontBumper" },
		RearBumper = { DisplayName = "Rear Bumper", Image = "rbxassetid://136042248946525", ShowInBuild = true, ShowInCustomise = true, SortOrder = 90, TargetId = "RearBumper" },
		SidePods = { DisplayName = "Side Pods", Image = "rbxassetid://131991855282079", ShowInBuild = true, ShowInCustomise = true, SortOrder = 100, TargetId = "SidePods" },
		Spoiler = { DisplayName = "Spoiler", Image = "rbxassetid://136022300099023", ShowInBuild = true, ShowInCustomise = true, SortOrder = 110, TargetId = "RearSpoiler" },
	}
	local newArtwork = {
		FrontBody = { DisplayName = "Front Body", Image = "rbxassetid://76594522686468", ShowInBuild = true, ShowInCustomise = true, SortOrder = 72, TargetId = "FrontBody" },
		RearBody = { DisplayName = "Rear Body", Image = "rbxassetid://136042248946525", ShowInBuild = true, ShowInCustomise = true, SortOrder = 74, TargetId = "RearBody" },
	}
	local function workspaceUI(source, folders)
		local artworkRoot = { FindFirstChild = function(_, name)
			local attributes = folders and folders[name]
			return attributes and { GetAttribute = function(_, key) return attributes[key] end, IsA = function(_, class) return class == "Folder" end } or nil
		end }
		return load(source, { RacingUIComponents = {}, GarageComponents = { HeaderTextSizes = function() return 20, 12 end } }, { ModuleArtwork = artworkRoot })
	end
	local piercerSlots = { Engine1 = true, Engine2 = true, Stabilisers = true, Boost = true, FrontBumper = true, RearBumper = true, RearSpoiler = true, SidePods = true }
	local exoticSlots = table.clone(piercerSlots); exoticSlots.FrontBody = true; exoticSlots.RearBody = true
	local function cards(ui, page, slotSet)
		local out = {}
		for _, art in ipairs(ui:ArtworkDefinitions(page)) do
			local special = page == "Customise" and (art.TargetId == "ALL" or art.TargetId == "Cockpit" or art.TargetId == "THRUST_COLOR")
			if special or slotSet[art.TargetId] then table.insert(out, art.TargetId .. "=" .. art.DisplayName .. "|" .. art.Image) end
		end
		return out
	end
	local function labels(list) local out = {}; for _, text in ipairs(list) do table.insert(out, (string.gsub(text, "|.*$", ""))) end; return out end

	test("slots: a Piercer garage shows the same eight cards, labels and order", function()
		local both = {}
		for name, attributes in pairs(liveArtwork) do both[name] = attributes end
		for name, attributes in pairs(newArtwork) do both[name] = attributes end
		-- With the two config folders, with only today's eleven, and with no config at all.
		for label, folders in pairs({ installed = both, codeOnly = liveArtwork, noConfig = false }) do
			local ui = workspaceUI(sources.GarageWorkspaceUI, folders or nil)
			eq(labels(cards(ui, "Build", piercerSlots)), { "Engine1=Front Engine", "Engine2=Rear Engine", "Stabilisers=Stabilisers", "Boost=Boost", "FrontBumper=Front Bumper", "RearBumper=Rear Bumper", "SidePods=Side Pods", "RearSpoiler=Spoiler" }, label .. " build")
			eq(labels(cards(ui, "Customise", piercerSlots)), { "ALL=All", "Cockpit=Cockpit", "THRUST_COLOR=Thrust Colour", "Engine1=Front Engine", "Engine2=Rear Engine", "Stabilisers=Stabilisers", "Boost=Boost", "FrontBumper=Front Bumper", "RearBumper=Rear Bumper", "SidePods=Side Pods", "RearSpoiler=Spoiler" }, label .. " paint")
			if before.GarageWorkspaceUI then
				local foldersBefore = liveArtwork -- "installed" adds only the two new folders, which the before source never reads
				if folders == false then foldersBefore = nil end
				local uiBefore = workspaceUI(before.GarageWorkspaceUI, foldersBefore)
				eq(cards(ui, "Build", piercerSlots), cards(uiBefore, "Build", piercerSlots), label .. " build parity")
				eq(cards(ui, "Customise", piercerSlots), cards(uiBefore, "Customise", piercerSlots), label .. " paint parity")
				for _, key in ipairs({ "Engine1", "FrontEngine", "Spoiler", "RearSpoiler", "ALL", "Owned", "MODULE_FRONTBUMPER_LVL1" }) do
					eq(ui:ResolveImage(key), uiBefore:ResolveImage(key), label .. " image " .. key)
				end
			end
		end
	end)

	test("slots: a ten-slot category shows ten cards; the two new rows sit after Boost", function()
		local both = table.clone(liveArtwork)
		for name, attributes in pairs(newArtwork) do both[name] = attributes end
		local ui = workspaceUI(sources.GarageWorkspaceUI, both)
		eq(labels(cards(ui, "Build", exoticSlots)), { "Engine1=Front Engine", "Engine2=Rear Engine", "Stabilisers=Stabilisers", "Boost=Boost", "FrontBody=Front Body", "RearBody=Rear Body", "FrontBumper=Front Bumper", "RearBumper=Rear Bumper", "SidePods=Side Pods", "RearSpoiler=Spoiler" }, "build")
		assert(#cards(ui, "Customise", exoticSlots) == 13, "paint targets")
		eq({ ui:ResolveImage("FrontBody"), ui:ResolveImage("RearBody") }, { "rbxassetid://76594522686468", "rbxassetid://136042248946525" }, "images")
		-- Code installed before the config folders: rows still exist, with a blank image.
		local bare = workspaceUI(sources.GarageWorkspaceUI, liveArtwork)
		eq(labels(cards(bare, "Build", exoticSlots)), labels(cards(ui, "Build", exoticSlots)), "rows without config")
		eq({ bare:ResolveImage("FrontBody"), bare:ResolveImage("RearBody") }, { "", "" }, "blank images")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- GarageUI: compile check and the exact slot label line it ships
	---------------------------------------------------------------------------------------------------------------
	test("labels: GarageUI compiles and uses RailLabel when the slot has one", function()
		local source = assert(sources.GarageUI, "source missing")
		assert(loadstring(source))
		local line = assert(string.match(source, "\n(local function slotLabel%(s,art%)[^\n]*)\n"), "slotLabel line missing")
		local slotLabel = assert(loadstring(line .. "\nreturn slotLabel"))()
		local art = { DisplayName = "Front Engine" }
		assert(slotLabel({ SlotId = "Engine1" }, art) == "Front Engine", "Piercer slot (no RailLabel)")
		assert(slotLabel({ SlotId = "Engine1", RailLabel = "" }, art) == "Front Engine", "empty RailLabel")
		assert(slotLabel(nil, { DisplayName = "All" }) == "All", "non-slot paint target")
		assert(slotLabel({ SlotId = "Engine1", RailLabel = "Main Turbine" }, art) == "Main Turbine", "Exotic slot")
		local _, uses = string.gsub(source, "slotLabel%(", "")
		assert(uses == 4, "expected the definition and three uses, found " .. uses)
		assert(not string.find(source, "DisplayName=art.DisplayName", 1, true) and not string.find(source, "Text=art.DisplayName", 1, true), "a slot label still bypasses RailLabel")
		assert(select(2, string.gsub(source, "VehicleName=row%.Title,Variant=row%.Tag,", "")) == 2, "module cards must use row.Title and row.Tag")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- GarageUI: which categories are listed. The shipped category helper lines are extracted and run against a fake State.
	---------------------------------------------------------------------------------------------------------------
	local function categoryHelpers(source, state)
		local block = assert(string.match(assert(source, "source missing"), "\n(local function allCategories%(%).-\nlocal function browserCategory%(%)[^\n]*)\n"), "category helper lines missing")
		local fn = assert(loadstring("local State=...\n" .. block .. "\nreturn {all=allCategories,current=currentCategory,combined=combinedCategory,browser=browserCategory,listed=listedCategories}"))
		return fn(state)
	end
	local function categoryIds(list) local out = {}; for _, c in ipairs(list) do table.insert(out, tostring(c.CategoryId)) end; return table.concat(out, ",") end
	local function combinedIds(category)
		local out = {}
		for _, c in ipairs(category.Cockpits) do table.insert(out, tostring(c.CockpitId) .. "@" .. tostring(c.SourceCategoryId)) end
		return table.concat(out, ",")
	end
	local function piercerCategory()
		return { CategoryId = "bruiser", DisplayName = "Piercer", Cockpits = { piercerCockpit(1), piercerCockpit(2) }, Slots = { { SlotId = "Engine1", Order = 1 } }, Modules = {} }
	end
	local function exoticCategory(purchaseDisabled)
		local slotList = {}
		for index, slotId in ipairs(string.split(tenSlots, ",")) do table.insert(slotList, { SlotId = slotId, Order = index }) end
		return { CategoryId = "exotic", DisplayName = "Exotic", FeatureFlag = "VehicleClass_exotic", PurchaseDisabled = purchaseDisabled, Cockpits = { exoticCockpit() }, Slots = slotList, Modules = {} }
	end
	local piercerOwner = { Vehicles = { V1 = { CockpitInstanceId = "C1", CategoryId = "bruiser" } }, OwnedCockpitInstances = { C1 = { TemplateId = "bruiser_01" } } }
	local exoticOwner = {
		Vehicles = { V1 = { CockpitInstanceId = "C1", CategoryId = "bruiser" }, V9 = { CockpitInstanceId = "C9", CategoryId = "exotic" }, V7 = { CockpitInstanceId = "GONE" }, V8 = {} },
		OwnedCockpitInstances = { C1 = { TemplateId = "bruiser_01" }, C9 = { TemplateId = "exotic_03" }, C5 = { TemplateId = "" } },
	}

	test("categories: a Piercer-only catalogue is listed and combined exactly as before", function()
		local piercer = piercerCategory()
		local catalog = { Categories = { piercer } }
		for _, mode in ipairs({ "Dealership", "Customisation" }) do
			for _, profile in ipairs({ piercerOwner, { Vehicles = {} }, {} }) do
				for _, categoryId in ipairs({ "bruiser", "unknown" }) do
					for _, browseAll in ipairs({ true, false }) do
						local state = { ShopMode = mode, Catalog = catalog, Profile = profile, CategoryId = categoryId, BrowseAll = browseAll }
						local where = mode .. "/" .. categoryId .. "/" .. tostring(browseAll)
						local now = categoryHelpers(sources.GarageUI, state)
						assert(categoryIds(now.listed()) == "bruiser" and now.listed()[1] == piercer, where .. " listed")
						assert(now.current() == piercer, where .. " current")
						assert(combinedIds(now.combined()) == "bruiser_01@bruiser,bruiser_02@bruiser", where .. " combined " .. combinedIds(now.combined()))
						local shown = now.browser()
						if browseAll then assert(shown.CategoryId == "__ALL" and combinedIds(shown) == "bruiser_01@bruiser,bruiser_02@bruiser", where .. " browser all")
						else assert(shown == piercer, where .. " browser category") end
						if before.GarageUI then
							local was = categoryHelpers(before.GarageUI, state)
							assert(was.listed == nil, "the before source has no listedCategories")
							eq(was.combined(), now.combined(), where .. " combined parity")
							assert(was.current() == now.current(), where .. " current parity")
							if browseAll then eq(was.browser(), shown, where .. " browser parity") else assert(was.browser() == shown, where .. " browser parity") end
						end
					end
				end
			end
		end
		-- No catalogue yet: nothing listed, nothing thrown, same values as before.
		local emptyState = { ShopMode = "Dealership", BrowseAll = false }
		local empty = categoryHelpers(sources.GarageUI, emptyState)
		assert(#empty.listed() == 0 and empty.current() == nil and empty.browser() == nil and #empty.combined().Cockpits == 0, "empty catalogue")
		if before.GarageUI then assert(categoryHelpers(before.GarageUI, emptyState).browser() == nil, "empty catalogue parity") end
	end)

	test("categories: two categories on sale are both listed in both modes", function()
		local catalog = { Categories = { exoticCategory(nil), piercerCategory() } }
		for _, mode in ipairs({ "Dealership", "Customisation" }) do
			for _, profile in ipairs({ piercerOwner, exoticOwner }) do
				local now = categoryHelpers(sources.GarageUI, { ShopMode = mode, Catalog = catalog, Profile = profile, CategoryId = "exotic", BrowseAll = true })
				assert(categoryIds(now.listed()) == "exotic,bruiser", mode .. " listed " .. categoryIds(now.listed()))
				assert(combinedIds(now.combined()) == "exotic_03@exotic,bruiser_01@bruiser,bruiser_02@bruiser", mode .. " combined")
				assert(now.current().CategoryId == "exotic" and #now.current().Slots == 10, mode .. " current")
			end
		end
		-- PurchaseDisabled=false is the same as absent.
		local off = categoryHelpers(sources.GarageUI, { ShopMode = "Dealership", Catalog = { Categories = { exoticCategory(false), piercerCategory() } }, Profile = piercerOwner, BrowseAll = true })
		assert(categoryIds(off.listed()) == "exotic,bruiser", "PurchaseDisabled=false")
	end)

	test("categories: a PurchaseDisabled category is never sold and stays usable for its owner", function()
		local exotic, piercer = exoticCategory(true), piercerCategory()
		local catalog = { Categories = { exotic, piercer } }
		local function helpers(mode, profile, categoryId, browseAll)
			return categoryHelpers(sources.GarageUI, { ShopMode = mode, Catalog = catalog, Profile = profile, CategoryId = categoryId, BrowseAll = browseAll })
		end
		-- Dealership: left out for everyone, owner included; a stale Exotic selection falls back to the combined list.
		for _, profile in ipairs({ piercerOwner, exoticOwner, {} }) do
			local now = helpers("Dealership", profile, "exotic", true)
			assert(categoryIds(now.listed()) == "bruiser", "dealership listed " .. categoryIds(now.listed()))
			assert(combinedIds(now.combined()) == "bruiser_01@bruiser,bruiser_02@bruiser", "dealership combined")
			local stale = helpers("Dealership", profile, "exotic", false).browser()
			assert(stale.CategoryId == "__ALL" and combinedIds(stale) == "bruiser_01@bruiser,bruiser_02@bruiser", "dealership never browses the disabled category")
			assert(helpers("Dealership", profile, "bruiser", false).browser() == piercer, "dealership Piercer tab")
		end
		-- Customisation, player without an Exotic vehicle: not listed, so no button and no rows.
		for _, profile in ipairs({ piercerOwner, {}, { Vehicles = { V7 = { CockpitInstanceId = "GONE" } }, OwnedCockpitInstances = { C9 = { TemplateId = "exotic_03" } } } }) do
			local now = helpers("Customisation", profile, "bruiser", true)
			assert(categoryIds(now.listed()) == "bruiser", "non-owner listed " .. categoryIds(now.listed()))
			assert(combinedIds(now.combined()) == "bruiser_01@bruiser,bruiser_02@bruiser", "non-owner combined")
		end
		-- Customisation, owner: listed, in the ALL rows, and the current category resolves to the Exotic one (ten slots).
		local owner = helpers("Customisation", exoticOwner, "exotic", true)
		assert(categoryIds(owner.listed()) == "exotic,bruiser", "owner listed " .. categoryIds(owner.listed()))
		assert(combinedIds(owner.combined()) == "exotic_03@exotic,bruiser_01@bruiser,bruiser_02@bruiser", "owner combined")
		assert(owner.current() == exotic and #owner.current().Slots == 10, "owner current category")
		assert(helpers("Customisation", exoticOwner, "exotic", false).browser() == exotic, "owner Exotic tab")
		-- Outside the browser the current category is the vehicle's own in either mode (slots, modules, upgrades, paint).
		assert(helpers("Dealership", exoticOwner, "exotic", true).current() == exotic, "current category does not depend on the listing")
	end)

	test("categories: the browser takes its category buttons from GarageUI", function()
		local ui, browserSource = assert(sources.GarageUI, "GarageUI missing"), assert(sources.GarageBrowserUI, "GarageBrowserUI missing")
		assert(loadstring(browserSource), "GarageBrowserUI does not compile")
		assert(select(2, string.gsub(ui, "Category=browserCategory%(%),Categories=listedCategories%(%),", "")) == 1, "GarageUI must pass Categories to the browser")
		local expression = "context.Categories or (context.State.Catalog and context.State.Catalog.Categories) or {}"
		local line = "for _,c in ipairs(" .. expression .. ") do table.insert(categories,c) end"
		local first = string.find(browserSource, line, 1, true)
		assert(first and not string.find(browserSource, line, first + 1, true), "browser category source")
		assert(not string.find(browserSource, "ipairs((context.State.Catalog and context.State.Catalog.Categories) or {})", 1, true), "the browser still reads the whole catalogue")
		-- The shipped expression: the passed list wins; absent, the whole catalogue as before.
		local pick = assert(loadstring("local context=...\nreturn " .. expression))
		local all, listed = { "exotic", "bruiser" }, { "bruiser" }
		assert(pick({ Categories = listed, State = { Catalog = { Categories = all } } }) == listed, "passed list")
		assert(pick({ State = { Catalog = { Categories = all } } }) == all, "no list passed")
		assert(#pick({ State = {} }) == 0, "no catalogue")
		if before.GarageBrowserUI then
			-- The only difference between the two browser sources is this one expression.
			local head = string.sub(browserSource, 1, first - 1)
			local tail = string.sub(browserSource, first + #line)
			local restored = head .. "for _,c in ipairs((context.State.Catalog and context.State.Catalog.Categories) or {}) do table.insert(categories,c) end" .. tail
			assert(restored == before.GarageBrowserUI, "GarageBrowserUI differs from before by more than the category source")
		end
	end)

	test("sources: every after source compiles and is ASCII", function()
		for _, name in ipairs({ "GarageModuleCardViewModel", "GarageVehiclePreviewProfile", "VehiclePerformanceResolver", "PreviewCameraClient", "GarageWorkspaceUI", "GarageUI", "GarageBrowserUI" }) do
			local source = assert(sources[name], name .. " missing")
			assert(loadstring(source), name .. " does not compile")
			assert(not string.find(source, "[\128-\255]"), name .. " has non-ASCII bytes")
			assert(#source < 190000, name .. " is too long")
		end
	end)

	return { failures = failures, results = results }
end
