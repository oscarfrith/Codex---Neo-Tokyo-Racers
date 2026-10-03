-- Exotic category, catalogue split: read-only parity check. Run in Studio (Edit) BEFORE the Stage A install.
-- It proves that the generated index plus chunks evaluate to the same data as the legacy single module.
--
-- Usage:  local check = loadstring(<this file>)()   local result = check(sources)
-- sources = {
--   index = <index source>            (or indexUrl = "http://127.0.0.1:<port>/...")
--   chunks = { { name = "PIERCER_1", source = <chunk source> }, ... }   (or url = "http://127.0.0.1:<port>/..." per chunk)
--   legacy = <legacy source>          (optional; default is the live VehicleCatalogData.Source)
-- }
-- The result of catalogue_gen.lua has this shape, so check(generate()) works as it is.
-- After the Stage A install the live module is the index, so the default legacy source no longer exists:
-- pass sources.legacy (the before blob) for a later run. Without it the result is identical = false with the reason.
-- result = { identical = bool, cockpits = n, modules = n, revision = <hex>, firstDifference = <text or nil>,
--            (a split or legacy form that errors, for example a missing chunk, a duplicate id or a legacy source
--             that is not a single data module, gives identical = false and the reason in firstDifference)
--            legacyCockpits = n, legacyModules = n, legacyRevision = <hex>, legacyFrom = "live" | "supplied",
--            chunks = { names in require order } }
-- For MCP output use game:GetService("HttpService"):JSONEncode(result).
--
-- Nothing is required, written or cached. Sources run through loadstring with a private environment:
-- "script" is a fake whose WaitForChild returns fake chunk modules, and "require" loads those fakes.

return function(sources)
	assert(type(sources) == "table", "sources table expected")
	local HttpService = game:GetService("HttpService")
	local function text(value, url, what)
		if value == nil and url ~= nil then
			assert(type(url) == "string" and (string.find(url, "^http://127%.0%.0%.1[:/]") or string.find(url, "^http://localhost[:/]")), "Only loopback URLs are read: " .. tostring(url))
			value = HttpService:GetAsync(url, true)
		end
		assert(type(value) == "string" and value ~= "", "Missing source: " .. what)
		return value
	end
	local function compile(source, what)
		local fn, problem = loadstring(source, "=" .. what)
		assert(fn, what .. " does not compile: " .. tostring(problem))
		return fn
	end

	local globals = getfenv()
	local function noRequire() error("require is not available to this source") end
	local function sandbox(scriptValue, requireValue)
		return setmetatable({ require = requireValue }, { __index = function(_, key)
			if key == "script" then return scriptValue end
			return globals[key]
		end })
	end

	-- Legacy single module: plain data, no script or require use. A legacy side that cannot be evaluated is a
	-- failed check with the reason, not a crash (for example a run after the Stage A install).
	local legacySource, legacyFrom = sources.legacy, "supplied"
	local legacyOk, legacy
	if legacySource == nil then
		legacyFrom = "live"
		local live = game:GetService("ReplicatedStorage").Modules.Game.Vehicles.VehicleCatalogData
		if #live:GetChildren() > 0 then
			legacyOk, legacy = false, "live VehicleCatalogData already has children, so it is the split index and not the legacy module; pass sources.legacy (the before blob) to compare"
		else
			legacySource = live.Source
		end
	end
	if legacyOk == nil then
		legacyOk, legacy = pcall(function()
			local legacyFn = compile(text(legacySource, nil, "legacy"), "legacy")
			setfenv(legacyFn, sandbox(nil, noRequire))
			return legacyFn()
		end)
		if not legacyOk then
			local hint = legacyFrom == "live" and "already the split index? pass sources.legacy" or "sources.legacy must be the legacy single module"
			legacy = "the " .. legacyFrom .. " legacy source did not evaluate as a single data module (" .. hint .. "): " .. tostring(legacy)
		end
	end

	-- Split form: fake children, fake require, the real index text.
	local modules, order = {}, {}
	for position, chunk in ipairs(sources.chunks or {}) do
		assert(type(chunk) == "table" and type(chunk.name) == "string", "chunk " .. position .. " needs a name")
		assert(not modules[chunk.name], "Two chunks named " .. chunk.name)
		modules[chunk.name] = { Name = chunk.name, ClassName = "ModuleScript", source = text(chunk.source, chunk.url, chunk.name), loaded = false }
	end
	local fakeScript = { Name = "VehicleCatalogData", ClassName = "ModuleScript" }
	function fakeScript.WaitForChild(self, name)
		assert(self == fakeScript, "WaitForChild must be called on script")
		local module = modules[name]
		if not module then error("Index waits for a chunk that was not supplied: " .. tostring(name), 0) end
		return module
	end
	fakeScript.FindFirstChild = function(self, name) return modules[name] end
	local function fakeRequire(module)
		assert(type(module) == "table" and modules[module.Name] == module, "require of something that is not a supplied chunk")
		if not module.loaded then
			local fn = compile(module.source, module.Name)
			setfenv(fn, sandbox(module, noRequire))
			module.value = fn()
			module.loaded = true
			table.insert(order, module.Name)
		end
		return module.value
	end
	local indexSource = text(sources.index, sources.indexUrl, "index")
	local splitOk, split = pcall(function()
		local indexFn = compile(indexSource, "index")
		setfenv(indexFn, sandbox(fakeScript, fakeRequire))
		return indexFn()
	end)

	-- Deep comparison, keys in sorted order so the first difference is stable.
	local function describe(v)
		local t = typeof(v)
		if t == "table" then return "table" end
		return t .. " " .. tostring(v)
	end
	local firstDifference = nil
	local function differ(path, why)
		if firstDifference == nil then firstDifference = (path == "" and "(whole data)" or path) .. ": " .. why end
		return false
	end
	local function same(a, b, path)
		if typeof(a) ~= typeof(b) then return differ(path, "legacy=" .. describe(a) .. " split=" .. describe(b)) end
		if type(a) ~= "table" then
			if a ~= b then return differ(path, "legacy=" .. describe(a) .. " split=" .. describe(b)) end
			return true
		end
		if table.isfrozen(a) ~= table.isfrozen(b) then return differ(path, "frozen legacy=" .. tostring(table.isfrozen(a)) .. " split=" .. tostring(table.isfrozen(b))) end
		local keys, seen = {}, {}
		for k in pairs(a) do seen[k] = true; table.insert(keys, k) end
		for k in pairs(b) do if not seen[k] then seen[k] = true; table.insert(keys, k) end end
		table.sort(keys, function(x, y)
			if type(x) == type(y) then return x < y end
			return type(x) == "number"
		end)
		for _, k in ipairs(keys) do
			local child = path == "" and tostring(k) or (path .. "." .. tostring(k))
			if a[k] == nil then return differ(child, "legacy=nil split=" .. describe(b[k])) end
			if b[k] == nil then return differ(child, "legacy=" .. describe(a[k]) .. " split=nil") end
			if not same(a[k], b[k], child) then return false end
		end
		return true
	end
	local function count(t)
		local n = 0
		if type(t) == "table" then for _ in pairs(t) do n += 1 end end
		return n
	end
	local identical
	if not legacyOk then
		identical = differ("legacy form failed", legacy)
		legacy = nil
	end
	if not splitOk then
		-- A missing chunk, a duplicate id or a source that does not compile is a failed check, not a crash.
		identical = differ("split form failed", tostring(split))
		split = nil
	end
	if legacyOk and splitOk then identical = same(legacy, split, "") end
	if identical then
		for name, module in pairs(modules) do
			if not module.loaded then identical = differ(name, "chunk supplied but never required by the index") end
		end
	end
	return {
		identical = identical,
		cockpits = count(type(split) == "table" and split.Cockpits),
		modules = count(type(split) == "table" and split.Modules),
		revision = type(split) == "table" and split.Revision or nil,
		firstDifference = firstDifference,
		legacyCockpits = count(type(legacy) == "table" and legacy.Cockpits),
		legacyModules = count(type(legacy) == "table" and legacy.Modules),
		legacyRevision = type(legacy) == "table" and legacy.Revision or nil,
		legacyFrom = legacyFrom,
		chunks = order,
	}
end
