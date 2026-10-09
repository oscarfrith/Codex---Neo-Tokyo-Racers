-- Pure tests for ReplicatedFirst.UIStyleSwitch (API.md 4 and 13). No yield, no instance, nothing parented.
-- M is the latch module table; M._resolve is the pure decision and M._new builds a separate latch for a test.
return function(M, env)
	local results = {}
	local function case(name, body)
		local ok, detail = pcall(body)
		results[#results + 1] = { name = name, ok = ok, detail = (not ok) and tostring(detail) or nil }
	end
	local function expect(condition, message)
		if not condition then
			error(message or "expectation failed", 0)
		end
	end
	local function fails(body, ...)
		local ok = pcall(body, ...)
		return not ok
	end
	local function latch(raw, devRaw, isStudio)
		local published = {}
		local switch = M._new(raw, devRaw, isStudio, function(name, value)
			published[name] = value
		end)
		return switch, published
	end
	local function same(list, expected)
		if type(list) ~= "table" or #list ~= #expected then
			return false
		end
		for index, value in ipairs(expected) do
			if list[index] ~= value then
				return false
			end
		end
		return true
	end

	case("resolve: Pulse", function()
		local style, reason, dev = M._resolve("Pulse", nil, true)
		expect(style == "Pulse" and reason == "attribute:Pulse" and dev == nil, tostring(style) .. " " .. tostring(reason))
	end)
	case("resolve: Classic", function()
		local style, reason = M._resolve("Classic", "", false)
		expect(style == "Classic" and reason == "attribute:Classic", tostring(style) .. " " .. tostring(reason))
	end)
	case("resolve: absent", function()
		local style, reason = M._resolve(nil, nil, false)
		expect(style == "Classic" and reason == "attribute:absent", tostring(style) .. " " .. tostring(reason))
	end)
	case("resolve: a non-string or unknown value is Classic, invalid", function()
		for _, raw in ipairs({ 1, true, false, "pulse", "PULSE", "", " Pulse", {} }) do
			local style, reason = M._resolve(raw, nil, true)
			expect(style == "Classic" and reason == "attribute:invalid", "raw " .. tostring(raw) .. " gave " .. tostring(style) .. " " .. tostring(reason))
		end
	end)
	case("resolve: dev list is honoured in Studio only", function()
		local _, _, inStudio = M._resolve("Pulse", "Toasts, Nope ,,", true)
		expect(same(inStudio, { "Toasts", "Nope" }), "Studio list wrong")
		local _, _, outside = M._resolve("Pulse", "Toasts,Nope", false)
		expect(outside == nil, "dev list honoured outside Studio")
		local _, _, unknownStudio = M._resolve("Pulse", "Toasts", nil)
		expect(unknownStudio == nil, "dev list honoured when isStudio is not true")
	end)
	case("resolve: an empty or non-string dev value means no limit", function()
		for _, devRaw in ipairs({ "", "  ", ",", 5, true }) do
			local _, _, dev = M._resolve("Pulse", devRaw, true)
			expect(dev == nil, "dev value " .. tostring(devRaw) .. " gave a list")
		end
	end)

	case("Classic is absolute", function()
		local switch, published = latch("Classic", "Toasts", true)
		expect(switch.Style == "Classic" and switch.Reason == "attribute:Classic", "style")
		expect(switch.Active("Toasts") == false, "Active is true under Classic")
		expect(fails(switch.Commit, { Families = { "Toasts" } }), "Commit allowed under Classic")
		expect(fails(switch.Claim, "Toasts"), "Claim allowed under Classic")
		local report = switch.Report()
		expect(report.Style == "Classic" and report.Committed == false and #report.Claims == 0 and #report.Families == 0, "report")
		expect(published.UIStyleResolved == "Classic" and published.UIStyleReason == "attribute:Classic", "published style")
		expect(published.UIStyleCommitted == false and published.UIStyleClaims == "", "published commit or claims")
	end)
	case("absent and invalid values behave as Classic", function()
		for _, raw in ipairs({ "Nope", 3 }) do
			local switch = latch(raw, nil, true)
			expect(switch.Style == "Classic" and switch.Active("Toasts") == false and fails(switch.Claim, "Toasts"), "raw " .. tostring(raw))
		end
		local absent = latch(nil, nil, true)
		expect(absent.Style == "Classic" and absent.Reason == "attribute:absent" and absent.Active("Toasts") == false, "absent")
	end)
	case("Pulse: Active before and after Commit; Claim rules", function()
		local switch, published = latch("Pulse", nil, false)
		expect(switch.Active("Toasts") == true and switch.Active("Hud") == true, "Active before Commit")
		expect(switch.Active(nil) == false and switch.Active(5) == false, "Active accepts a non-string")
		expect(fails(switch.Claim, "Toasts"), "Claim allowed before Commit")
		switch.Commit({ Families = { "Toasts" } })
		expect(switch.Active("Toasts") == true and switch.Active("Hud") == false, "Active after Commit")
		expect(fails(switch.Commit, { Families = { "Toasts" } }), "second Commit allowed")
		switch.Claim("Toasts")
		expect(fails(switch.Claim, "Toasts"), "second Claim of one surface allowed")
		expect(fails(switch.Claim, ""), "empty surface allowed")
		switch.Claim("Gallery")
		expect(fails(switch.Downgrade, "late"), "Downgrade allowed after a Claim")
		expect(switch.Style == "Pulse", "style changed by a refused Downgrade")
		local report = switch.Report()
		expect(report.Committed == true and same(report.Families, { "Toasts" }) and same(report.Claims, { "Toasts", "Gallery" }), "report")
		expect(report.DevFamilies == nil, "dev list reported without one")
		expect(published.UIStyleResolved == "Pulse" and published.UIStyleCommitted == true and published.UIStyleClaims == "Toasts,Gallery", "published")
	end)
	case("Commit refuses a bad report", function()
		expect(fails(latch("Pulse", nil, false).Commit, nil), "nil report")
		expect(fails(latch("Pulse", nil, false).Commit, {}), "no Families")
		expect(fails(latch("Pulse", nil, false).Commit, { Families = { 1 } }), "non-string family")
		expect(fails(latch("Pulse", nil, false).Commit, { Families = { "Toasts", "Toasts" } }), "duplicate family")
		local empty = latch("Pulse", nil, false)
		empty.Commit({ Families = {} })
		expect(empty.Active("Toasts") == false and empty.Report().Committed == true, "empty commit")
	end)
	case("Downgrade is one-way and gives Classic", function()
		local switch, published = latch("Pulse", nil, true)
		switch.Downgrade("Routes: boom")
		expect(switch.Style == "Classic" and switch.Reason == "downgraded:Routes: boom", tostring(switch.Reason))
		expect(switch.Active("Toasts") == false, "Active after Downgrade")
		expect(fails(switch.Commit, { Families = { "Toasts" } }), "Commit after Downgrade")
		expect(fails(switch.Claim, "Toasts"), "Claim after Downgrade")
		expect(published.UIStyleResolved == "Classic" and published.UIStyleReason == "downgraded:Routes: boom", "published")
		local committed = latch("Pulse", nil, true)
		committed.Commit({ Families = { "Toasts" } })
		committed.Downgrade("after commit")
		expect(committed.Style == "Classic" and committed.Active("Toasts") == false and fails(committed.Claim, "Toasts"), "downgrade after Commit")
	end)
	case("dev list limits Active in Studio and is ignored outside", function()
		local studio = latch("Pulse", "Toasts", true)
		expect(studio.Active("Toasts") == true and studio.Active("Hud") == false, "Studio dev list")
		expect(same(studio.Report().DevFamilies, { "Toasts" }), "reported dev list")
		expect(fails(studio.Commit, { Families = { "Hud" } }), "Commit of a family outside the dev list")
		local live = latch("Pulse", "Toasts", false)
		expect(live.Active("Toasts") == true and live.Active("Hud") == true and live.Report().DevFamilies == nil, "outside Studio")
		local unknown = latch("Pulse", "Nope", true)
		expect(unknown.Style == "Pulse" and unknown.Active("Toasts") == false, "unknown dev family")
	end)
	case("Report returns copies", function()
		local switch = latch("Pulse", "Toasts", true)
		switch.Commit({ Families = { "Toasts" } })
		local report = switch.Report()
		report.Families[1] = "Changed"
		report.DevFamilies[1] = "Changed"
		table.insert(report.Claims, "Fake")
		local again = switch.Report()
		expect(same(again.Families, { "Toasts" }) and same(again.DevFamilies, { "Toasts" }) and #again.Claims == 0, "Report exposes internal tables")
		expect(switch.Active("Toasts") == true, "Active changed through a report")
	end)
	case("the module itself is a latch with the documented members", function()
		for _, name in ipairs({ "Active", "Commit", "Claim", "Downgrade", "Report", "_resolve", "_new" }) do
			expect(type(M[name]) == "function", name .. " missing")
		end
		expect(M.Style == "Classic" or M.Style == "Pulse", "Style")
		expect(type(M.Reason) == "string", "Reason")
	end)
	return results
end
