-- P8 pure tests: ReceiptProcessor idempotency/save-first and FeatureFlags default resolution (no game mutation).
return function(sources)
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local RP = assert(loadstring(sources.ReceiptProcessor))()
	local player = {}
	local function setup(saveResult)
		local profile = { Cash = 0 }
		local process = RP.new({
			getPlayer = function(id) return id == 1 and player or nil end,
			getProfile = function() return profile end,
			saveNow = function() return saveResult() end,
			grants = { [99] = function(p) p.Cash += 100; return true end },
		})
		return profile, process
	end
	local Granted, NotYet = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
	test("grants once and is idempotent on retry", function()
		local profile, process = setup(function() return true end)
		assert(process({ PlayerId = 1, PurchaseId = "a", ProductId = 99 }) == Granted)
		assert(process({ PlayerId = 1, PurchaseId = "a", ProductId = 99 }) == Granted)
		assert(profile.Cash == 100)
	end)
	test("failed save keeps single grant; retry only re-saves", function()
		local ok = false
		local profile, process = setup(function() return ok end)
		assert(process({ PlayerId = 1, PurchaseId = "b", ProductId = 99 }) == NotYet)
		assert(profile.Cash == 100 and profile.PurchaseHistory.b.Saved == false)
		ok = true
		assert(process({ PlayerId = 1, PurchaseId = "b", ProductId = 99 }) == Granted)
		assert(profile.Cash == 100 and profile.PurchaseHistory.b.Saved == true)
	end)
	test("concurrent duplicate while saving is not processed", function()
		local release = false
		local profile, process = setup(function() while not release do task.wait() end return true end)
		local first
		task.spawn(function() first = process({ PlayerId = 1, PurchaseId = "c", ProductId = 99 }) end)
		task.wait()
		assert(process({ PlayerId = 1, PurchaseId = "c", ProductId = 99 }) == NotYet)
		release = true
		repeat task.wait() until first ~= nil
		assert(first == Granted and profile.Cash == 100)
	end)
	test("absent player / unknown product -> not processed", function()
		local profile, process = setup(function() return true end)
		assert(process({ PlayerId = 2, PurchaseId = "d", ProductId = 99 }) == NotYet)
		assert(process({ PlayerId = 1, PurchaseId = "e", ProductId = 5 }) == NotYet)
		assert(profile.Cash == 0)
	end)
	test("save that throws is pending, not lost or doubled", function()
		local profile, process = setup(function() error("datastore down") end)
		assert(process({ PlayerId = 1, PurchaseId = "f", ProductId = 99 }) == NotYet and profile.Cash == 100)
	end)
	test("feature flags return default without snapshot in Edit", function()
		local FF = assert(loadstring(sources.FeatureFlags))()
		assert(FF.Get("DefinitelyUnsetFlagKey", "dflt") == "dflt")
		assert(FF.IsEnabled("DefinitelyUnsetFlagKey", true) == true and FF.IsEnabled("DefinitelyUnsetFlagKey", false) == false)
	end)
	return { failures = failures, results = results }
end
