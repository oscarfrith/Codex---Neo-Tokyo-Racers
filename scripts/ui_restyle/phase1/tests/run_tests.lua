-- Pulse Phase 1 Edit-mode test harness (API.md section 13, CONTRACT E3). Run in Studio Edit through loadstring;
-- it returns one JSON string. Optional argument: {origin = string?, after = string?, tests = string?}.
--
-- Every source is fetched from the local bridge as text and compiled with loadstring. Modules under test get a
-- fake `script` and a fake `require`, so the kit modules loaded here are SEPARATE TEST INSTANCES: nothing in the
-- place is required (AGENTS: no gameplay module require) and nothing is written to the DataModel.
local HttpService = game:GetService("HttpService")

local options = ...
if type(options) ~= "table" then
	options = {}
end
local ORIGIN = options.origin or "http://127.0.0.1:8796/"
local AFTER = options.after or "scripts/ui_restyle/phase1/after/"
local TESTS = options.tests or "scripts/ui_restyle/phase1/tests/"
local CLASSIC = "scripts/ui_restyle/classic/sources/"

local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
local LATCH_PATH = "ReplicatedFirst.UIStyleSwitch"
local LAYERS_PATH = UIP .. "Kit.Layers"
local TOKENS_PATH = UIP .. "Kit.Tokens"
local SCOPE_PATH = "ReplicatedStorage.Modules.Core.ConnectionScope"
-- Core modules API.md section 1 lets owners and the gallery require; loaded from the Classic source record.
local CORE_ALLOWED = { [SCOPE_PATH] = true, ["ReplicatedStorage.Modules.Core.ConfigReader"] = true }
local MAX_CHARS = 150000

-- CONTRACT section 2: the 20 ModuleScripts, plus the ClientBase after-source (compile only).
local DECLARED = {
	LATCH_PATH,
	UIP .. "Routes",
	UIP .. "Kit.Tokens",
	UIP .. "Kit.Metrics",
	UIP .. "Kit.Perf",
	UIP .. "Kit.Layers",
	UIP .. "Kit.Input",
	UIP .. "Kit.Contracts",
	UIP .. "Kit.Text",
	UIP .. "Kit.Surface",
	UIP .. "Kit.Controls",
	UIP .. "Kit.Collections",
	UIP .. "Kit.Overlay",
	UIP .. "Toasts.ToastClient",
	UIP .. "Dev.Gallery",
	UIP .. "Dev.Fixtures.Text",
	UIP .. "Dev.Fixtures.Surface",
	UIP .. "Dev.Fixtures.Controls",
	UIP .. "Dev.Fixtures.Collections",
	UIP .. "Dev.Fixtures.Overlay",
	"StarterPlayer.StarterPlayerScripts.ClientBase",
}
-- API.md section 13: modules that must have a test file.
local REQUIRED_TESTS = {
	LATCH_PATH,
	UIP .. "Routes",
	UIP .. "Kit.Tokens",
	UIP .. "Kit.Metrics",
	UIP .. "Kit.Text",
	UIP .. "Kit.Layers",
	UIP .. "Kit.Contracts",
	UIP .. "Kit.Surface",
	UIP .. "Kit.Controls",
	UIP .. "Kit.Collections",
	UIP .. "Kit.Overlay",
	UIP .. "Kit.Perf",
}

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

local function fetch(repoPath)
	local ok, body = pcall(function()
		return HttpService:GetAsync(ORIGIN .. repoPath .. "?t=" .. tostring(os.clock()), true)
	end)
	if ok and type(body) == "string" then
		return body, nil
	end
	return nil, tostring(body)
end

-- The bridge is a plain file server: a folder URL answers with an HTML listing.
local function listLua(folder)
	local body = fetch(folder)
	local names = {}
	if body then
		for href in string.gmatch(body, 'href="([^"]+)"') do
			local name = string.gsub(href, "%%(%x%x)", function(hex)
				return string.char(tonumber(hex, 16))
			end)
			if string.sub(name, -4) == ".lua" and not string.find(name, "/", 1, true) then
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	return names, body ~= nil
end

-- 1. Fetch everything first, so nothing yields while modules and tests run. -----------------------------------
local sources = {} -- instance path -> source
local sourceOrder = {}
local testSources = {} -- instance path -> test source
local coreSources = {}

local function addSource(path, text)
	if sources[path] == nil then
		table.insert(sourceOrder, path)
	end
	sources[path] = text
end

local afterNames, afterListed = listLua(AFTER)
for _, name in ipairs(afterNames) do
	local path = string.sub(name, 1, -5)
	local text, problem = fetch(AFTER .. name)
	if text then
		addSource(path, text)
	else
		record(path, "fetch", false, problem)
	end
end
for _, path in ipairs(DECLARED) do
	if sources[path] == nil then
		local text, problem = fetch(AFTER .. path .. ".lua")
		if text then
			addSource(path, text)
		else
			record(path, "fetch", false, "declared source missing from " .. AFTER .. ": " .. tostring(problem))
		end
	end
end
table.sort(sourceOrder)

local testNames = listLua(TESTS)
for _, name in ipairs(testNames) do
	if string.sub(name, -9) == "_test.lua" then
		local path = string.sub(name, 1, -10)
		local text, problem = fetch(TESTS .. name)
		if text then
			testSources[path] = text
		else
			record(path, "fetch test", false, problem)
		end
	end
end
for _, path in ipairs(sourceOrder) do
	if testSources[path] == nil and #testNames == 0 then
		testSources[path] = fetch(TESTS .. path .. "_test.lua") -- no listing: ask for each file
	end
end
for path in pairs(CORE_ALLOWED) do
	coreSources[path] = fetch(CLASSIC .. path .. ".lua")
end

-- 2. Compile every after-source. --------------------------------------------------------------------------------
for _, path in ipairs(sourceOrder) do
	local text = sources[path]
	local chunk, problem = loadstring(text, path)
	record(path, "compile", chunk ~= nil, if chunk then nil else tostring(problem))
	if not chunk then
		table.insert(compileErrors, { file = path .. ".lua", error = tostring(problem) })
	end
	local formatProblem = nil
	if #text > MAX_CHARS then
		formatProblem = #text .. " characters; the limit is " .. MAX_CHARS
	elseif string.find(text, "\r", 1, true) then
		formatProblem = "contains CR; sources are LF only"
	end
	record(path, "size and line ends", formatProblem == nil, formatProblem)
end

-- 3. Fakes. -----------------------------------------------------------------------------------------------------
-- Runs fn in its own coroutine: a traceback on error, and a failure (not a wait) if it yields.
local function runGuarded(label, fn, ...)
	local arguments = table.pack(...)
	local thread = coroutine.create(function()
		return xpcall(fn, debug.traceback, table.unpack(arguments, 1, arguments.n))
	end)
	local resumed, ok, result = coroutine.resume(thread)
	if coroutine.status(thread) ~= "dead" then
		pcall(task.cancel, thread)
		return false, label .. " yielded; nothing under test may yield (API.md section 13)"
	end
	if not resumed then
		return false, tostring(ok)
	end
	if not ok then
		return false, tostring(result)
	end
	return true, result
end

-- Stands in for ReplicatedFirst.UIStyleSwitch (API.md section 4). `DevFamilies` may be set by a test.
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
		if sources[path] ~= nil then
			return true
		end
		local prefix = path .. "."
		for known in pairs(sources) do
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
			error("harness: " .. tostring(name) .. " is not a Phase 1 child of " .. handlePath[self], 2)
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
		return children
	end
	function methods.GetFullName(self)
		return handlePath[self]
	end
	function methods.IsA(self, className)
		local own = if sources[handlePath[self]] ~= nil then "ModuleScript" else "Folder"
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
					return if sources[path] ~= nil then "ModuleScript" else "Folder"
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
		local source = sources[path] or coreSources[path]
		if type(source) ~= "string" then
			error("harness: no Phase 1 source for " .. tostring(path), 0)
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
			-- API.md section 13: Layers.Switch is replaced by the fake latch.
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

	-- Accepts a harness handle, or a real ModuleScript whose full name is a Phase 1 path or an allowed Core
	-- module; either way the module comes from repo text, never from the place.
	function world.require(target)
		local path = if target ~= nil then handlePath[target] else nil
		if not path and typeof(target) == "Instance" then
			local full = target:GetFullName()
			if sources[full] ~= nil or CORE_ALLOWED[full] then
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

-- 4. Run the test files. ----------------------------------------------------------------------------------------
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
		-- Extra to API.md: a real Core.ConnectionScope (from the Classic source record) for constructor tests.
		Scope = function()
			return world.load(SCOPE_PATH).new()
		end,
	}
	local function finish()
		world.cleanup()
		for _, note in ipairs(world.notes) do
			record(path, "harness", false, note)
		end
		record(path, "no globals written", #world.leaks == 0, if #world.leaks > 0 then table.concat(world.leaks, "; ") else nil)
	end

	local okLoad, M = pcall(world.load, path)
	if not okLoad then
		record(path, "load", false, tostring(M))
		return finish()
	end
	record(path, "load", true, nil)

	local chunk, problem = loadstring(testSource, path .. "_test")
	if not chunk then
		record(path, "test compile", false, tostring(problem))
		return finish()
	end
	setfenv(chunk, world.environment(path .. "_test", nil))
	local okChunk, testFunction = runGuarded("test file", chunk)
	if not okChunk or type(testFunction) ~= "function" then
		record(path, "test file", false, if okChunk then "the test file must return one function" else tostring(testFunction))
		return finish()
	end
	local okRun, cases = runGuarded("test function", testFunction, M, env)
	if not okRun or type(cases) ~= "table" then
		record(path, "test run", false, if okRun then "the test function must return a list of cases" else tostring(cases))
		return finish()
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
	return finish()
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
for _, path in ipairs(sourceOrder) do
	local testSource = testSources[path]
	if testSource then
		testedCount += 1
		runTestFile(path, testSource)
	end
end
for _, path in ipairs(REQUIRED_TESTS) do
	if not testSources[path] then
		record(path, "test file", false, "missing " .. TESTS .. path .. "_test.lua")
	end
end
for path in pairs(testSources) do
	if sources[path] == nil then
		record(path, "test file", false, "test has no after-source")
	end
end

-- 5. Token dump for build.py (CONTRACT section 3 and E6): Tokens.Flatten(Tokens.Defaults), typed. ----------------
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

-- 6. Side-effect checks. ----------------------------------------------------------------------------------------
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
record("harness", "source listing", afterListed, if afterListed then nil else "no folder listing from the bridge; used the declared list only")

local failed = 0
for _, row in ipairs(results) do
	if not row.ok then
		failed += 1
	end
end
return HttpService:JSONEncode({
	ok = failed == 0,
	summary = { rows = #results, failed = failed, sources = #sourceOrder, testFiles = testedCount },
	results = results,
	compileErrors = compileErrors,
	tokens = tokens,
})
