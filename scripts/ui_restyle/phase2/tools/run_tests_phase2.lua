-- Pulse wave-2 Edit-mode test harness (API1 section 13, API2 6.4, CONTRACT.md steps 2 and 3). Run in Studio Edit
-- (execute_luau, or through loadstring with an options table); it returns ONE JSON string:
--   { ok, unit, compileErrors = {{file, error}}, results = {{module, name, ok, detail}}, summary, tokens }
--
-- Set ARGS.unit to the install folder name (install/<NN>_<unit>). The harness first fetches that unit's
-- test_manifest.json (written by tools/assemble.py) from the local bridge (tools/serve.py, 127.0.0.1:8796), then
-- every source and test the manifest lists: the installed-or-pending Pulse sources (the latest of phase1/after, the
-- kit and earlier units), this unit's after-sources, and the shared Classic modules a Pulse module may require.
--
-- EVERY source is compiled with loadstring (compile check). A module with a _test.lua file is loaded and tested.
-- Modules under test get a fake `script` and a fake `require` wired between the FETCHED texts only: nothing in the
-- place is ever required (AGENTS: no gameplay module require) and nothing is written to the DataModel.
local ARGS = {
	unit = "00_kit", -- install folder name: 00_kit, 01_race_menu, 02_free_roam, ...
	scope = "unit+kit", -- which tests run: "unit" | "unit+kit" (this unit, the kit and Phase 1) | "all"
	only = nil, -- optional: a string; only test files whose instance path contains it run
	failuresOnly = false, -- true: `results` holds only the failed rows (the summary still counts all); for long runs
	origin = "http://127.0.0.1:8796/",
	install = "scripts/ui_restyle/phase2/install/",
	manifest = nil, -- optional: repo path of a manifest, instead of <install><unit>/test_manifest.json
}

local HttpService = game:GetService("HttpService")

local options = ...
if type(options) == "table" then
	for key, value in pairs(options) do
		ARGS[key] = value
	end
end

local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
local MAX_CHARS = 150000

local baseEnvironment = getfenv()
local results = {}
local compileErrors = {}

local function shortName(path)
	if string.sub(path, 1, #UIP) == UIP then
		return string.sub(path, #UIP + 1)
	end
	return path
end

local function record(path, name, ok, detail)
	table.insert(results, { module = shortName(path), name = name, ok = ok == true, detail = detail })
end

local function finish(extra)
	local failed = 0
	for _, row in ipairs(results) do
		if not row.ok then
			failed += 1
		end
	end
	local shown = results
	if ARGS.failuresOnly then
		shown = {}
		for _, row in ipairs(results) do
			if not row.ok then
				table.insert(shown, row)
			end
		end
	end
	local out = {
		ok = failed == 0 and #compileErrors == 0,
		unit = ARGS.unit,
		summary = { rows = #results, failed = failed, compileErrors = #compileErrors },
		results = shown,
		compileErrors = compileErrors,
	}
	for key, value in pairs(extra or {}) do
		if key == "summary" then
			for name, number in pairs(value) do
				out.summary[name] = number
			end
		else
			out[key] = value
		end
	end
	return HttpService:JSONEncode(out)
end

local function fetch(repoPath)
	local ok, body = pcall(function()
		return HttpService:GetAsync(ARGS.origin .. repoPath .. "?t=" .. tostring(os.clock()), true)
	end)
	if ok and type(body) == "string" then
		return body, nil
	end
	return nil, tostring(body)
end

-- 1. The manifest, then every file, so nothing yields while modules and tests run. ---------------------------------
local manifestPath = ARGS.manifest or (ARGS.install .. ARGS.unit .. "/test_manifest.json")
local manifestText, manifestProblem = fetch(manifestPath)
if not manifestText then
	record("harness", "manifest", false, "cannot fetch " .. manifestPath .. ": " .. tostring(manifestProblem) .. " (is tools/serve.py running, and has assemble.py built this unit?)")
	return finish()
end
local okManifest, manifest = pcall(function()
	return HttpService:JSONDecode(manifestText)
end)
if not okManifest or type(manifest) ~= "table" or type(manifest.sources) ~= "table" then
	record("harness", "manifest", false, manifestPath .. " is not a test manifest")
	return finish()
end

local LATCH_PATH = manifest.latchPath or "ReplicatedFirst.UIStyleSwitch"
local LAYERS_PATH = manifest.layersPath or (UIP .. "Kit.Layers")
local TOKENS_PATH = manifest.tokensPath or (UIP .. "Kit.Tokens")
local SCOPE_PATH = manifest.scopePath or "ReplicatedStorage.Modules.Core.ConnectionScope"

local sources = {} -- instance path -> source (Pulse sources and edited Classic scripts)
local sourceOrder = {} -- manifest order (dependency order)
local sourceUnit = {} -- instance path -> the unit that supplies it
local classicSources = {} -- instance path -> source of a shared Classic module (classic/sources, read-only record)
local testSources = {} -- instance path -> test source
local testOrder = {}

for _, entry in ipairs(manifest.sources) do
	local text, problem = fetch(entry.file)
	if text then
		sources[entry.path] = text
		sourceUnit[entry.path] = entry.unit
		table.insert(sourceOrder, entry.path)
	else
		record(entry.path, "fetch", false, tostring(entry.file) .. ": " .. tostring(problem))
	end
end
for _, entry in ipairs(manifest.classic or {}) do
	local text = fetch(entry.file)
	if text then
		classicSources[entry.path] = text
	else
		record(entry.path, "fetch shared Classic module", false, tostring(entry.file))
	end
end
if classicSources[SCOPE_PATH] == nil and sources[SCOPE_PATH] == nil then
	classicSources[SCOPE_PATH] = fetch("scripts/ui_restyle/classic/sources/" .. SCOPE_PATH .. ".lua")
end

local function inScope(entry)
	if type(ARGS.only) == "string" and not string.find(entry.path, ARGS.only, 1, true) then
		return false
	end
	if ARGS.scope == "all" then
		return true
	elseif ARGS.scope == "unit" then
		return entry.unit == manifest.unit
	end
	return entry.unit == manifest.unit or entry.unit == "phase1" or entry.unit == "00_kit"
end
local skippedTests = 0
for _, entry in ipairs(manifest.tests or {}) do
	if inScope(entry) then
		local text, problem = fetch(entry.file)
		if text then
			testSources[entry.path] = text
			table.insert(testOrder, entry.path)
		else
			record(entry.path, "fetch test", false, tostring(entry.file) .. ": " .. tostring(problem))
		end
	else
		skippedTests += 1
	end
end

local function textOf(path)
	return sources[path] or classicSources[path]
end

-- 2. Compile every source. ----------------------------------------------------------------------------------------
for _, path in ipairs(sourceOrder) do
	local text = sources[path]
	local chunk, problem = loadstring(text, path)
	record(path, "compile", chunk ~= nil, if chunk then nil else tostring(problem))
	if not chunk then
		table.insert(compileErrors, { file = path .. ".lua", unit = sourceUnit[path], error = tostring(problem) })
	end
	local formatProblem = nil
	if #text > MAX_CHARS then
		formatProblem = #text .. " characters; the limit is " .. MAX_CHARS
	elseif string.find(text, "\r", 1, true) then
		formatProblem = "contains CR; sources are LF only"
	end
	if formatProblem then
		record(path, "size and line ends", false, formatProblem)
	end
end

-- 3. Fakes. -------------------------------------------------------------------------------------------------------
-- Runs fn in its own coroutine: a traceback on error, and a failure (not a wait) if it yields.
local function runGuarded(label, fn, ...)
	local arguments = table.pack(...)
	local thread = coroutine.create(function()
		return xpcall(fn, debug.traceback, table.unpack(arguments, 1, arguments.n))
	end)
	local resumed, ok, result = coroutine.resume(thread)
	if coroutine.status(thread) ~= "dead" then
		pcall(task.cancel, thread)
		return false, label .. " yielded; nothing under test may yield (API1 section 13)"
	end
	if not resumed then
		return false, tostring(ok)
	end
	if not ok then
		return false, tostring(result)
	end
	return true, result
end

-- Stands in for ReplicatedFirst.UIStyleSwitch (API1 section 4). `DevFamilies` may be set by a test.
local function fakeSwitch(style)
	local switch = { Style = style, Reason = "attribute:" .. tostring(style), DevFamilies = nil }
	local committed, families, claims = false, {}, {}
	function switch.Active(family)
		if switch.Style ~= "Pulse" then
			return false
		end
		if switch.DevFamilies and not table.find(switch.DevFamilies, family) then
			return false
		end
		return not committed or table.find(families, family) ~= nil
	end
	function switch.Commit(report)
		assert(not committed, "FakeSwitch.Commit called twice")
		assert(type(report) == "table" and type(report.Families) == "table", "FakeSwitch.Commit needs {Families}")
		committed = true
		families = table.clone(report.Families)
	end
	function switch.Claim(surface)
		assert(switch.Style == "Pulse", "FakeSwitch.Claim: style is not Pulse")
		assert(committed, "FakeSwitch.Claim: not committed")
		assert(not table.find(claims, surface), "FakeSwitch.Claim: already claimed " .. tostring(surface))
		table.insert(claims, surface)
	end
	function switch.Downgrade(reason)
		assert(#claims == 0, "FakeSwitch.Downgrade after a Claim")
		switch.Style = "Classic"
		switch.Reason = "downgraded:" .. tostring(reason)
	end
	function switch.Report()
		return {
			Style = switch.Style,
			Reason = switch.Reason,
			Committed = committed,
			Families = table.clone(families),
			Claims = table.clone(claims),
			DevFamilies = switch.DevFamilies,
		}
	end
	return switch
end

-- One world per test file: its own module cache, script handles and fake latch.
local function newWorld()
	local world = { modules = {}, loading = {}, leaks = {}, detached = {}, notes = {} }
	local handles, handlePath, attributes = {}, {}, {}
	world.switch = fakeSwitch("Pulse")

	local function exists(path)
		if textOf(path) ~= nil then
			return true
		end
		local prefix = path .. "."
		for known in pairs(sources) do
			if string.sub(known, 1, #prefix) == prefix then
				return true
			end
		end
		for known in pairs(classicSources) do
			if string.sub(known, 1, #prefix) == prefix then
				return true
			end
		end
		return false
	end

	local handle
	local methods = {}
	function methods.FindFirstChild(self, name)
		local path = handlePath[self] .. "." .. tostring(name)
		return if exists(path) then handle(path) else nil
	end
	function methods.WaitForChild(self, name)
		local child = methods.FindFirstChild(self, name)
		if not child then
			error("harness: " .. tostring(name) .. " is not a fetched child of " .. handlePath[self], 2)
		end
		return child
	end
	function methods.GetChildren(self)
		local prefix = handlePath[self] .. "."
		local seen, children = {}, {}
		for _, known in ipairs(sourceOrder) do
			if string.sub(known, 1, #prefix) == prefix then
				local name = string.match(string.sub(known, #prefix + 1), "^[^%.]+")
				if name and not seen[name] then
					seen[name] = true
					table.insert(children, handle(prefix .. name))
				end
			end
		end
		table.sort(children, function(a, b)
			return handlePath[a] < handlePath[b]
		end)
		return children
	end
	function methods.GetFullName(self)
		return handlePath[self]
	end
	function methods.IsA(self, className)
		local own = if textOf(handlePath[self]) ~= nil then "ModuleScript" else "Folder"
		return className == own or className == "Instance" or (own == "ModuleScript" and className == "LuaSourceContainer")
	end
	function methods.GetAttribute(self, name)
		return attributes[self][name]
	end
	function methods.SetAttribute(self, name, value)
		attributes[self][name] = value -- kept in the handle; the latch writes its report here
	end
	function methods.GetAttributes(self)
		return table.clone(attributes[self])
	end

	-- A table that answers like the ModuleScript or Folder at `path`; children are the fetched sources.
	handle = function(path)
		local existing = handles[path]
		if existing then
			return existing
		end
		local name = string.match(path, "([^%.]+)$")
		local parentPath = string.match(path, "^(.*)%.[^%.]+$")
		local proxy = setmetatable({}, {
			__index = function(_, key)
				if key == "Name" then
					return name
				elseif key == "Parent" then
					return if parentPath then handle(parentPath) else nil
				elseif key == "ClassName" then
					return if textOf(path) ~= nil then "ModuleScript" else "Folder"
				end
				local method = methods[key]
				if method then
					return method
				end
				local childPath = path .. "." .. tostring(key)
				if exists(childPath) then
					return handle(childPath)
				end
				error(tostring(key) .. " is not a valid member of " .. path .. " (harness handle)", 2)
			end,
			__newindex = function(_, key)
				error("harness handle is read-only: " .. path .. "." .. tostring(key), 2)
			end,
			__tostring = function()
				return path
			end,
		})
		handles[path] = proxy
		handlePath[proxy] = path
		attributes[proxy] = {}
		return proxy
	end

	function world.environment(path, scriptHandle)
		return setmetatable({ script = scriptHandle, require = world.require }, {
			__index = baseEnvironment,
			__newindex = function(self, key, value)
				table.insert(world.leaks, path .. " wrote global " .. tostring(key))
				rawset(self, key, value)
			end,
		})
	end

	function world.load(path)
		local cached = world.modules[path]
		if cached ~= nil then
			return cached
		end
		if world.loading[path] then
			error("harness: dependency cycle at " .. path, 0)
		end
		local source = textOf(path)
		if type(source) ~= "string" then
			error("harness: no fetched source for " .. tostring(path), 0)
		end
		local chunk, problem = loadstring(source, path)
		if not chunk then
			error("harness: compile error in " .. path .. ": " .. tostring(problem), 0)
		end
		setfenv(chunk, world.environment(path, handle(path)))
		world.loading[path] = true
		local ok, result = runGuarded("require of " .. path, chunk)
		world.loading[path] = nil
		if not ok then
			error("harness: " .. path .. " failed to load: " .. tostring(result), 0)
		end
		if result == nil then
			error("harness: " .. path .. " returned nil", 0)
		end
		if path == LAYERS_PATH and type(result) == "table" then
			-- API1 section 13: Layers.Switch is replaced by the fake latch.
			local replaced = pcall(function()
				result.Switch = function()
					return world.switch
				end
			end)
			if not replaced then
				table.insert(world.notes, "Layers.Switch could not be replaced (frozen module table)")
			end
		end
		world.modules[path] = result
		return result
	end

	-- Accepts a harness handle, or a real ModuleScript whose full name is a fetched path (a Pulse source of the
	-- chain or a listed shared Classic module). Either way the module comes from repo text, never from the place.
	function world.require(target)
		local path = if target ~= nil then handlePath[target] else nil
		if not path and typeof(target) == "Instance" then
			local full = target:GetFullName()
			if textOf(full) ~= nil then
				path = full
			else
				error("harness: require of a game instance refused: " .. full, 2)
			end
		end
		if not path then
			error("harness: require of a " .. typeof(target) .. " refused", 2)
		end
		return world.load(path)
	end

	function world.cleanup()
		for _, instance in ipairs(world.detached) do
			pcall(function()
				instance:Destroy()
			end)
		end
		world.detached = {}
	end

	return world
end

-- 4. Run the test files. ------------------------------------------------------------------------------------------
local function runTestFile(path, testSource)
	local world = newWorld()
	local env = {
		Load = function(instancePath)
			return world.load(instancePath)
		end,
		FakeSwitch = fakeSwitch,
		Detached = function(className)
			local instance = Instance.new(className)
			table.insert(world.detached, instance)
			return instance
		end,
		-- A real Core.ConnectionScope (from the Classic source record) for constructor tests.
		Scope = function()
			return world.load(SCOPE_PATH).new()
		end,
	}
	local function done()
		world.cleanup()
		for _, note in ipairs(world.notes) do
			record(path, "harness", false, note)
		end
		record(path, "no globals written", #world.leaks == 0, if #world.leaks > 0 then table.concat(world.leaks, "; ") else nil)
	end

	local okLoad, M = pcall(world.load, path)
	if not okLoad then
		record(path, "load", false, tostring(M))
		return done()
	end
	record(path, "load", true, nil)

	local chunk, problem = loadstring(testSource, path .. "_test")
	if not chunk then
		record(path, "test compile", false, tostring(problem))
		table.insert(compileErrors, { file = path .. "_test.lua", error = tostring(problem) })
		return done()
	end
	setfenv(chunk, world.environment(path .. "_test", nil))
	local okChunk, testFunction = runGuarded("test file", chunk)
	if not okChunk or type(testFunction) ~= "function" then
		record(path, "test file", false, if okChunk then "the test file must return one function" else tostring(testFunction))
		return done()
	end
	local okRun, cases = runGuarded("test function", testFunction, M, env)
	if not okRun or type(cases) ~= "table" then
		record(path, "test run", false, if okRun then "the test function must return a list of cases" else tostring(cases))
		return done()
	end
	if #cases == 0 then
		record(path, "test run", false, "the test returned no cases")
	end
	for position, case in ipairs(cases) do
		if type(case) == "table" then
			local detail = if case.detail ~= nil then tostring(case.detail) else nil
			record(path, tostring(case.name or position), case.ok == true, detail)
		else
			record(path, tostring(position), false, "case is not a table")
		end
	end
	return done()
end

local function keysOf(container)
	local keys = {}
	for key in pairs(container) do
		keys[key] = true
	end
	return keys
end

local sharedBefore, globalBefore = keysOf(shared), keysOf(_G)
local added = {}
local watch = game.DescendantAdded:Connect(function(instance)
	local ok, name = pcall(function()
		return instance:GetFullName()
	end)
	table.insert(added, if ok then name else "?")
end)

local testedCount = 0
for _, path in ipairs(testOrder) do
	if sources[path] ~= nil then
		testedCount += 1
		runTestFile(path, testSources[path])
	else
		record(path, "test file", false, "the test has no fetched source")
	end
end
for _, path in ipairs(manifest.requiredTests or {}) do
	if not testSources[path] and (type(ARGS.only) ~= "string" or string.find(path, ARGS.only, 1, true)) then
		record(path, "test file", false, "no pure test for a module this unit creates or changes (API2 6.4)")
	end
end

-- 5. Token dump for tools/tokens_from_dump.py: Tokens.Flatten(Tokens.Defaults), typed (as Phase 1). -----------------
local tokens = nil
if sources[TOKENS_PATH] then
	local world = newWorld()
	local ok, flat = pcall(function()
		local Tokens = world.load(TOKENS_PATH)
		local out = {}
		for name, value in pairs(Tokens.Flatten(Tokens.Defaults)) do
			if typeof(value) == "Color3" then
				local r, g, b = math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255)
				out[name] = { Type = "Color3", Value = { r, g, b } }
			else
				out[name] = { Type = typeof(value), Value = value }
			end
		end
		return out
	end)
	world.cleanup()
	if ok then
		tokens = flat
	else
		record(TOKENS_PATH, "token dump", false, tostring(flat))
	end
end

-- 6. Side-effect checks. ------------------------------------------------------------------------------------------
task.wait() -- lets deferred DescendantAdded events arrive before the watch is removed
watch:Disconnect()
record("harness", "nothing parented to the game tree", #added == 0, if #added > 0 then table.concat(added, "; ", 1, math.min(#added, 10)) else nil)
local leaked = {}
for key in pairs(shared) do
	if not sharedBefore[key] then
		table.insert(leaked, "shared." .. tostring(key))
	end
end
for key in pairs(_G) do
	if not globalBefore[key] then
		table.insert(leaked, "_G." .. tostring(key))
	end
end
record("harness", "nothing left in shared or _G", #leaked == 0, if #leaked > 0 then table.concat(leaked, "; ") else nil)

return finish({
	summary = { sources = #sourceOrder, testFiles = testedCount, testsOutOfScope = skippedTests },
	tokens = tokens,
})
