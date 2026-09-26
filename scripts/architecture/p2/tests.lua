-- Phase 2 tests (Studio Edit, no game mutation): Core.Net behaviour and old/new GarageRequestGuard equivalence.
return function(sources)
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local Net = assert(loadstring(sources.Net))()
	local function loadGuard(text)
		text = text:gsub('require%(game:GetService%("ServerStorage"%):WaitForChild%("Modules"%):WaitForChild%("Core"%):WaitForChild%("Net"%)%)', "__NET")
		local fn = assert(loadstring(text))
		local env = setmetatable({ __NET = Net }, { __index = getfenv(0) })
		setfenv(fn, env)
		return fn()
	end
	local OldGuard, NewGuard = loadGuard(sources.OldGuard), loadGuard(sources.NewGuard)
	local p1, p2 = {}, {}

	test("guard equivalence across validation, rate, busy and failure paths", function()
		local t = 0
		local clock = function() return t end
		local old, new = OldGuard.new(clock), NewGuard.new(clock)
		local cases = {
			{ "Nope", nil }, { 5, nil }, { "GetInitial", "x" }, { "GetInitial", { KnownCatalogRevision = string.rep("a", 65) } },
			{ "SpawnVehicle", { KnownCatalogRevision = "r" } }, { "SelectVehicleInstance", { VehicleId = 5 } },
			{ "SelectVehicleInstance", { VehicleId = string.rep("x", 241) } }, { "BuyModule", { AllowReassign = "yes" } },
			{ "SetCockpitColor", { Color = Color3.new(0 / 0, 0, 0) } }, { "SetCockpitColor", { Color = "red" } },
			{ "SetCockpitColor", { Color = Color3.new(0.2, 0.3, 0.4), Channel = "Primary" } }, { "BuyNeon", { Weird = 1 } },
			{ "GetInitial", { KnownCatalogRevision = "abc" } },
		}
		local big = {}; for i = 1, 21 do big["VehicleId" .. i] = "x" end
		table.insert(cases, { "GetInitial", big })
		local function same(a, b)
			if type(a) ~= type(b) then return false end
			if type(a) ~= "table" then return a == b end
			for k, v in pairs(a) do if not same(v, b[k]) then return false end end
			for k in pairs(b) do if a[k] == nil then return false end end
			return true
		end
		for i, case in ipairs(cases) do
			local a = old.run(p1, case[1], case[2], function() return { Success = true, Echo = i } end)
			local b = new.run(p2, case[1], case[2], function() return { Success = true, Echo = i } end)
			assert(same(a, b), "case " .. i .. " differs: " .. tostring(a.Message) .. " vs " .. tostring(b.Message))
		end
		-- drain tokens: cost 6 from capacity 120 at frozen time
		for i = 1, 30 do
			local a = old.run(p1, "SpawnVehicle", nil, function() return { Success = true } end)
			local b = new.run(p2, "SpawnVehicle", nil, function() return { Success = true } end)
			assert(same(a, b), "rate step " .. i .. " differs")
		end
		t = 10
		-- busy: nested call during callback
		local innerA, innerB
		old.run(p1, "SpawnVehicle", nil, function() innerA = old.run(p1, "GetInitial", nil, function() return {} end); return {} end)
		new.run(p2, "SpawnVehicle", nil, function() innerB = new.run(p2, "GetInitial", nil, function() return {} end); return {} end)
		assert(same(innerA, innerB) and innerA.Message:find("already running"), "busy differs")
		-- failure isolation
		local fa = old.run(p1, "SpawnVehicle", nil, function() error("x") end)
		local fb = new.run(p2, "SpawnVehicle", nil, function() error("x") end)
		assert(same(fa, fb), "failure differs")
		-- forget resets
		old.forget(p1); new.forget(p2)
	end)

	test("invoke table reply: normalises twins, rejects unknown, insane and spam", function()
		local handler = Net.invoke({ name = "T1", actions = { Go = true }, capacity = 3, refill = 0 }, function(_, action, payload)
			return { Success = true, Got = payload and payload.n }
		end)
		local r = handler(p1, "Go", { n = 2 })
		assert(r.Success == true and r.Ok == true and r.Got == 2)
		local u = handler(p1, "Bad", nil); assert(u.Ok == false and u.Success == false and u.Message == "Unknown request.")
		local nan = handler(p1, "Go", { n = 0 / 0 }); assert(nan.Success == false and nan.Message == "Invalid request.")
		handler(p1, "Go", nil); handler(p1, "Go", nil) -- rejected calls above spent no tokens; this empties capacity 3
		local spam = handler(p1, "Go", nil); assert(spam.Success == false and spam.Message:find("wait"))
	end)
	test("invoke keeps existing Ok-only and extra return values", function()
		local handler = Net.invoke({ name = "T2", actions = { Go = true } }, function() return { Ok = true, Queued = false }, "extra" end)
		local r, extra = handler(p1, "Go")
		assert(r.Ok == true and r.Success == true and r.Queued == false and extra == "extra")
	end)
	test("invoke boolean reply and handler errors", function()
		local b = Net.invoke({ name = "T3", withAction = false, reply = "boolean", capacity = 1, refill = 0 }, function() return true end)
		assert(b(p1) == true); assert(b(p1) == false)
		local e = Net.invoke({ name = "T4", actions = { Go = true } }, function() error("boom") end)
		local r = e(p1, "Go"); assert(r.Success == false and r.Message == "Request unavailable. Please try again.")
	end)
	test("event drops insane and spam, passes valid", function()
		local seen = 0
		local ev = Net.event({ name = "T5", capacity = 2, refill = 0 }, function(_, a) seen += a end)
		ev(p1, 1); ev(p1, 0 / 0); ev(p1, 2); ev(p1, 4)
		assert(seen == 3, "seen " .. seen)
		local depth = { { { { { 1 } } } } }
		local ev2 = Net.event({ name = "T6" }, function() seen = -1 end)
		ev2(p1, depth); assert(seen == 3)
	end)
	test("per-remote isolation and counters", function()
		local a = Net.invoke({ name = "T7", actions = { Go = true }, capacity = 1, refill = 0 }, function() return { Success = true } end)
		local b = Net.invoke({ name = "T8", actions = { Go = true }, capacity = 1, refill = 0 }, function() return { Success = true } end)
		assert(a(p2, "Go").Success and b(p2, "Go").Success)
		local stats = Net.Stats()
		assert(stats["T7.Go"].calls >= 1 and stats["T1.?"].rejected >= 1)
	end)
	test("unknown actions cannot grow counters", function()
		local h = Net.invoke({ name = "T9", actions = { Go = true } }, function() return {} end)
		for i = 1, 200 do h(p1, "junk" .. i, nil); h(p1, "junk" .. i, { 0 / 0 }) end
		h(p1, 42, nil)
		local rows = 0
		for key in pairs(Net.Stats()) do if key:sub(1, 3) == "T9." then rows += 1 end end
		assert(rows == 1 and Net.Stats()["T9.?"].rejected == 401, "rows " .. rows)
	end)
	test("long strings up to 8 KB accepted", function()
		assert(Net.IsSane({ Detail = string.rep("e", 5000) }) and not Net.IsSane(string.rep("e", 9000)))
	end)
	return { failures = failures, results = results }
end
