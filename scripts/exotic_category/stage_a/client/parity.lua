-- Exotic Stage A client: Piercer parity on live data (Edit mode).
-- Read-only: reads attributes and script Source, creates nothing, sets nothing, calls no remote and never calls require.
-- The resolver's calculation dependencies are loaded with loadstring into a private cache (not the game's module cache).
--
-- Call: parity(sources) -> { failures = n, results = { ... } }
--   sources.VehiclePerformanceResolver / sources.GarageVehiclePreviewProfile                 AFTER source text
--   sources.Before.VehiclePerformanceResolver / sources.Before.GarageVehiclePreviewProfile   BEFORE source text
-- Every Piercer cockpit and every Piercer module record is run through before and after; results must be exactly equal.
return function(sources)
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and (err and (": " .. tostring(err)) or "") or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local vehicles = ReplicatedStorage.Modules.Game.Vehicles
	local catalogueData = vehicles.VehicleCatalogData
	local allowed = {
		VehicleDefinition = true, VehicleCatalog = true, VehicleCatalogData = true, PerformanceCalculator = true, PerformanceDefinitions = true,
		PerformanceRuntime = true, PerformanceUpgradeRuntime = true, PerformanceDynamics = true, VehicleUpgradeDefinitions = true,
	}
	local cache = {}
	local function shimRequire(target)
		assert(typeof(target) == "Instance" and target:IsA("ModuleScript"), "unexpected require target")
		assert(target:IsDescendantOf(vehicles) and (allowed[target.Name] or target:IsDescendantOf(catalogueData)), "not a pure calculation module: " .. target:GetFullName())
		if cache[target] == nil then
			local fn = assert(loadstring(target.Source))
			setfenv(fn, setmetatable({ script = target, require = shimRequire }, { __index = getfenv(0) }))
			cache[target] = fn()
		end
		return cache[target]
	end
	local function load(source)
		local fn = assert(loadstring(assert(source, "source missing")))
		setfenv(fn, setmetatable({ require = shimRequire }, { __index = getfenv(0) }))
		return fn()
	end
	local function eq(a, b, where)
		if type(a) ~= "table" or type(b) ~= "table" then
			assert(a == b or (a ~= a and b ~= b), where .. ": " .. tostring(a) .. " ~= " .. tostring(b))
			return
		end
		for k, v in pairs(a) do eq(v, b[k], where .. "." .. tostring(k)) end
		for k in pairs(b) do assert(a[k] ~= nil, where .. "." .. tostring(k) .. " missing after") end
	end

	local before = assert(sources.Before, "sources.Before missing")
	local data = shimRequire(catalogueData)
	local cockpits = {}
	for _, category in ipairs(game:GetService("ServerStorage").Assets.Vehicles.Categories:GetChildren()) do
		if category:GetAttribute("CategoryId") == "bruiser" then
			for _, item in ipairs(category:GetDescendants()) do
				if item:IsA("Model") and item:GetAttribute("CockpitId") then table.insert(cockpits, item:GetAttributes()) end
			end
		end
	end
	table.sort(cockpits, function(a, b) return tostring(a.CockpitId) < tostring(b.CockpitId) end)

	test("dealership rating: every Piercer cockpit is exactly equal before and after", function()
		local R, RB = load(sources.VehiclePerformanceResolver), load(before.VehiclePerformanceResolver)
		assert(#cockpits >= 6, "Piercer cockpits found: " .. #cockpits)
		local summary = {}
		for _, cockpit in ipairs(cockpits) do
			local id = tostring(cockpit.CockpitId)
			-- As GarageUI calls it (catalogue cockpit), as ModuleRating calls it (generated record), and by id only.
			for form, argument in pairs({ catalogue = cockpit, record = data.Cockpits[id], idOnly = { CockpitId = id } }) do
				local now, nowMessage = R.Factory(nil, argument)
				local was, wasMessage = RB.Factory(nil, argument)
				assert(was ~= nil, id .. " " .. form .. " has no rating before: " .. tostring(wasMessage))
				eq(was, now, id .. " " .. form)
				eq(wasMessage, nowMessage, id .. " " .. form .. " message")
				local _, modules, bySlot = R.DefaultBuild(nil, argument)
				local slots = 0
				for _ in pairs(bySlot) do slots += 1 end
				assert(#modules == 4 and slots == 4, id .. " " .. form .. " default build is not four modules")
			end
			local overall = R.Factory(nil, cockpit).Overall
			table.insert(summary, id .. "=" .. tostring(overall.Tier) .. " " .. tostring(overall.PerformanceIndex))
		end
		return table.concat(summary, ", ")
	end)

	test("module rating: every Piercer module is exactly equal before and after", function()
		local R, RB = load(sources.VehiclePerformanceResolver), load(before.VehiclePerformanceResolver)
		local total, rated, upgraded = 0, 0, 0
		for id, record in pairs(data.Modules) do
			if record.CategoryId == "bruiser" then
				total += 1
				local now, was = R.ModuleRating(nil, { ModuleId = id }), RB.ModuleRating(nil, { ModuleId = id })
				assert(now == was, id .. ": " .. tostring(was) .. " ~= " .. tostring(now))
				if now > 0 then rated += 1 end
				local path = record.UpgradePaths and record.UpgradePaths[1]
				if path and path.PathId then
					local instance = { V2UpgradePoints = { [path.PathId] = 1 } }
					local nowUp, wasUp = R.ModuleRating(nil, { ModuleId = id }, instance), RB.ModuleRating(nil, { ModuleId = id }, instance)
					assert(nowUp == wasUp, id .. " upgraded: " .. tostring(wasUp) .. " ~= " .. tostring(nowUp))
					upgraded += 1
				end
			end
		end
		assert(total > 0 and rated > 0, "no Piercer modules rated")
		return total .. " modules, " .. rated .. " with a rating, " .. upgraded .. " also checked with one upgrade point"
	end)

	test("dealership preview: every Piercer cockpit gives exactly the same factory profile", function()
		local P, PB = load(sources.GarageVehiclePreviewProfile), load(before.GarageVehiclePreviewProfile)
		for _, cockpit in ipairs(cockpits) do
			local id = tostring(cockpit.CockpitId)
			local row = { CockpitId = id, CategoryId = "bruiser", Cockpit = cockpit }
			local state = { CategoryId = "bruiser", ShopMode = "Dealership" }
			local now, was = P.ForBrowser(state, row), PB.ForBrowser(state, row)
			eq(was, now, id)
			local slots = {}
			for slotId in pairs(now.InstalledModules) do table.insert(slots, slotId) end
			table.sort(slots)
			assert(table.concat(slots, ",") == "Boost,Engine1,Engine2,Stabilisers", id .. " slots: " .. table.concat(slots, ","))
		end
		return #cockpits .. " cockpits"
	end)

	return { failures = failures, results = results }
end
