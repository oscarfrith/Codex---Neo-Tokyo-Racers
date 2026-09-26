-- Phase 4 pure MoneyService tests (plain tables only).
return function(source)
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local M = assert(loadstring(source))()
	test("debit matches legacy subtraction", function()
		local p = { Cash = 1000 }
		assert(M.Debit(p, 250, "Test") == 750 and p.Cash == 750)
		local q = { Cash = "1000" }
		assert(M.Debit(q, 1000, "Test") == 0 and q.Cash == 0)
		local r = {}
		assert(M.Debit(r, 0, "Free") == 0)
	end)
	test("invalid amounts never change balance", function()
		for _, bad in ipairs({ 0 / 0, -5, math.huge }) do
			local p = { Cash = 500 }
			assert(not pcall(M.Debit, p, bad, "Bad"), tostring(bad))
			assert(p.Cash == 500)
		end
	end)
	test("insufficient funds errors without change", function()
		local p = { Cash = 10 }
		assert(not pcall(M.Debit, p, 11, "TooMuch")) ; assert(p.Cash == 10)
		assert(M.CanAfford(p, 10) and not M.CanAfford(p, 11) and not M.CanAfford(p, 0 / 0))
	end)
	test("non-finite balance refused", function()
		local p = { Cash = 0 / 0 }
		assert(not pcall(M.Debit, p, 1, "X"))
	end)
	test("refund and bounded ledger", function()
		local p = { Cash = 100 }
		M.Debit(p, 40, "A"); M.Refund(p, 40, "A")
		assert(p.Cash == 100)
		for i = 1, 70 do M.Debit({ Cash = 1 }, 1, "L") end
		assert(#M.RecentLedger() == 50)
	end)
	return { failures = failures, results = results }
end
