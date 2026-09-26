-- Phase 3 pure tests: RaceIntegrity with an injected fake settings folder (no game mutation).
return function(source)
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local attributes = {}
	local folder = { GetAttribute = function(_, key) return attributes[key] end }
	local config = { FindFirstChild = function(_, name) return name == "Racing" and folder or nil end }
	local storage = { FindFirstChild = function(_, name) return name == "Config" and config or nil end }
	local dynamicsAttributes = {}
	local accel = { GetAttribute = function(_, key) return dynamicsAttributes[key] end }
	local dynamics = { GetChildren = function() return { accel } end }
	local vehicles = { FindFirstChild = function(_, n) return n == "Dynamics" and dynamics or nil end }
	local rsConfig = { FindFirstChild = function(_, n) return n == "Vehicles" and vehicles or nil end }
	local replicated = { FindFirstChild = function(_, n) return n == "Config" and rsConfig or nil end }
	local fakeGame = { GetService = function(_, name) return name == "ServerStorage" and storage or replicated end }
	local fn = assert(loadstring(source))
	setfenv(fn, setmetatable({ game = fakeGame }, { __index = getfenv(0) }))
	local RI = fn()
	local function gate(x, size) return { Position = Vector3.new(x, 0, 0), Size = Vector3.new(size or 0, 0, 0) } end
	local warnings = 0

	test("pure segment rule", function()
		assert(RI.segmentAllowed(100, 1, 200, 0))
		assert(not RI.segmentAllowed(300, 1, 200, 0))
		assert(RI.segmentAllowed(10, 0, 200, 24) and not RI.segmentAllowed(30, 0, 200, 24))
	end)
	test("off mode never flags", function()
		attributes = {}
		local run = {}; RI.begin(run, Vector3.zero, 0)
		assert(RI.gate(run, gate(100000), 0.1, "t") and RI.accepted(run))
	end)
	test("log mode flags teleport but accepts", function()
		attributes = { RaceIntegrityMode = "Log", RaceIntegrityMaxSpeedMph = 400, RaceIntegrityToleranceStuds = 24 }
		local run = {}; RI.begin(run, Vector3.zero, 0)
		assert(RI.gate(run, gate(500), 2, "ok"))          -- 250 studs/s < 640
		assert(not RI.gate(run, gate(5500), 2.5, "tp"))   -- 5000 studs in 0.5 s
		assert(run.Integrity.Violations == 1 and RI.accepted(run))
	end)
	test("enforce withholds only flagged runs", function()
		attributes = { RaceIntegrityMode = "Enforce", RaceIntegrityMaxSpeedMph = 400, RaceIntegrityToleranceStuds = 24 }
		local good, bad = {}, {}
		RI.begin(good, Vector3.zero, 0); RI.begin(bad, Vector3.zero, 0)
		RI.gate(good, gate(600), 1.5, "g"); RI.gate(good, gate(1200), 3, "g")
		RI.gate(bad, gate(3000), 0.2, "b")
		assert(RI.accepted(good) and not RI.accepted(bad))
	end)
	test("gate size widens tolerance; no start position skips first check", function()
		attributes = { RaceIntegrityMode = "Enforce", RaceIntegrityMaxSpeedMph = 400, RaceIntegrityToleranceStuds = 0 }
		local run = {}; RI.begin(run, nil, 0)
		assert(RI.gate(run, gate(9999, 80), 0, "first"))
		assert(RI.gate(run, gate(9999 + 70, 80), 0, "inside gate width")) -- 70 <= 0.5*(80+80)
		assert(RI.accepted(run))
	end)
	test("invalid config falls back", function()
		attributes = { RaceIntegrityMode = "Enforce", RaceIntegrityMaxSpeedMph = 0 / 0, RaceIntegrityToleranceStuds = "x" }
		local run = {}; RI.begin(run, Vector3.zero, 0)
		assert(RI.gate(run, gate(600), 1, "fallback 400mph+24"))
		attributes = { RaceIntegrityMode = "Bogus" }
		assert(RI.mode() == "Off")
	end)
	test("limit follows driving caps (cached)", function()
		attributes = { RaceIntegrityMode = "Enforce", RaceIntegrityMaxSpeedMph = 400 }
		assert(RI.limitMph() == 400, tostring(RI.limitMph()))
		assert(RI.segmentAllowed(640 * 1.35 + 24, 1 + 0.35, 640, 24))
	end)
	test("un-begun subject is always accepted", function()
		attributes = { RaceIntegrityMode = "Enforce" }
		local run = {}
		assert(RI.gate(run, gate(1e6), 0, "x") and RI.accepted(run))
	end)
	return { failures = failures, results = results }
end
