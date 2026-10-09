-- selftest_body.lua: the cases of selftest.lua (build.py --selftest puts CASES, hash.lua, plan.lua and engine.lua
-- above this). Everything runs against Instance.new trees that are never parented to the DataModel, with a fake
-- root resolver and fake files. The only service used is HttpService, for JSON.
local HttpService = game:GetService("HttpService")
local summary = { passed = 0, failed = 0, skipped = 0, cases = {} }
local function case(name, fn)
	local ok, result = pcall(fn)
	local status, detail = "passed", ""
	if not ok then
		status, detail = "failed", tostring(result)
	elseif result == "skipped" then
		status = "skipped"
	end
	summary[status] += 1
	table.insert(summary.cases, { name = name, status = status, detail = detail })
end
local function expect(condition, message)
	if not condition then
		error(message, 0)
	end
end
local function same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not same(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local BEFORE = "return { version = 1 }\n"
local MIDDLE = "return { version = 1.5 }\n"
local AFTER = "return { version = 2 }\n"
local BEFORE2 = "return { second = 1 }\n"
local AFTER2 = "return { second = 2 }\n"
local PROBE_OLD = "return { probe = false }\n"
local PROBE = "return { probe = true }\n"
local BROKEN = "return {{{\n"
local MARK = "UIRestyleInstall"
local UI = { "ReplicatedStorage", "Modules", "Game", "UI" }
local PULSE = { "ReplicatedStorage", "Modules", "Game", "UIPulse" }

local function make(class, name, parent)
	local node = Instance.new(class)
	node.Name = name
	node.Parent = parent
	return node
end
-- A detached copy of the parts of the place the engine reads. Nothing here is parented to game.
local function newWorld()
	local world = {}
	world.RS = make("Folder", "ReplicatedStorage", nil)
	local config = make("Folder", "Config", world.RS)
	world.onboarding = make("Folder", "Onboarding", make("Folder", "Player", config))
	world.onboarding:SetAttribute("StudioVehicleSandboxEveryPlay", false)
	world.ui = make("Folder", "UI", config)
	world.ui:SetAttribute("Tint", Color3.new(0.5, 0.25, 1))
	world.label = make("StringValue", "Label", world.ui)
	world.label.Value = "a"
	world.gameFolder = make("Folder", "Game", make("Folder", "Modules", world.RS))
	world.modules = make("Folder", "UI", world.gameFolder)
	world.existing = make("ModuleScript", "Existing", world.modules)
	world.existing.Source = BEFORE
	world.second = make("ModuleScript", "Second", world.modules)
	world.second.Source = BEFORE2
	return world
end
local function newFiles()
	return {
		["t/after/Probe.lua"] = PROBE,
		["t/before/Existing.lua"] = BEFORE, ["t/after/Existing.lua"] = AFTER,
		["t/before/Second.lua"] = BEFORE2, ["t/after/Second.lua"] = AFTER2,
	}
end
local function newData()
	local fp = Hash.fingerprint
	return {
		phase = "selftest", placeId = 1, base = "t/", markAttribute = MARK, installable = true,
		ops = {
			{ id = "kit", kind = "create", transaction = "hierarchy", class = "Folder", path = PULSE, mark = "selftest:kit", attributes = { Note = "made by selftest", Scale = 1.5 } },
			{ id = "style", kind = "attribute", transaction = "hierarchy", path = { "ReplicatedStorage", "Config", "UI" }, key = "Style", after = "Pulse", was = { "Draft" } },
			{ id = "tint", kind = "attribute", transaction = "hierarchy", path = { "ReplicatedStorage", "Config", "UI" }, key = "Tint", before = { Type = "Color3", R = 0.5, G = 0.25, B = 1 }, after = { Type = "Color3", R = 0, G = 0.5, B = 1 } },
			{ id = "label", kind = "property", transaction = "hierarchy", path = { "ReplicatedStorage", "Config", "UI", "Label" }, key = "Value", before = "a", after = "b" },
			{ id = "probe", kind = "create", transaction = "hierarchy", class = "ModuleScript", path = { "ReplicatedStorage", "Modules", "Game", "UIPulse", "Probe" }, mark = "selftest:probe", parentOp = "kit", after = fp(PROBE), prior = { fp(PROBE_OLD) }, file = { after = "after/Probe.lua" } },
			{ id = "existing", kind = "source", transaction = "sources", class = "ModuleScript", path = { "ReplicatedStorage", "Modules", "Game", "UI", "Existing" }, before = fp(BEFORE), after = fp(AFTER), prior = { fp(MIDDLE) }, file = { before = "before/Existing.lua", after = "after/Existing.lua" } },
			{ id = "second", kind = "source", transaction = "sources", class = "ModuleScript", path = { "ReplicatedStorage", "Modules", "Game", "UI", "Second" }, before = fp(BEFORE2), after = fp(AFTER2), prior = {}, file = { before = "before/Second.lua", after = "after/Second.lua" } },
		},
	}
end
-- One engine run. options: files, data, placeId, isEdit, setSource. -> report, counters
local function run(mode, world, options)
	options = options or {}
	local files = options.files or newFiles()
	local counters = { fetches = 0, waits = 0, waypoints = 0, writes = 0 }
	local env = {
		placeId = options.placeId or 1,
		isEdit = options.isEdit ~= false,
		root = function(name)
			if name == "ReplicatedStorage" then
				return world.RS
			end
			return nil
		end,
		fetch = function(file)
			counters.fetches += 1
			local text = files[file]
			if text == nil then
				error("no such file " .. file)
			end
			return text
		end,
		loadChunk = Engine.loadChunk,
		getSource = function(node)
			return node.Source
		end,
		setSource = function(node, text)
			counters.writes += 1
			if options.setSource then
				options.setSource(node, text, counters.writes)
			else
				node.Source = text
			end
		end,
		wait = function()
			counters.waits += 1
		end,
		waypoint = function()
			counters.waypoints += 1
		end,
		jsonDecode = function(text)
			return HttpService:JSONDecode(text)
		end,
	}
	return Engine.run(mode, options.data or newData(), env), counters
end
local function opRow(report, id)
	for _, name in ipairs(Plan.TRANSACTIONS) do
		for _, row in ipairs(report.transactions[name].ops) do
			if row.id == id then
				return row
			end
		end
	end
	error("no row for " .. id, 0)
end
local function pulse(world)
	return world.gameFolder:FindFirstChild("UIPulse")
end
-- Runs APPLY twice (hierarchy, then sources) and checks both worked.
local function install(world)
	local first = run("APPLY", world)
	expect(first.ok and first.transaction == "hierarchy", "first APPLY: " .. table.concat(first.blockers, " | "))
	local second = run("APPLY", world)
	expect(second.ok and second.transaction == "sources", "second APPLY: " .. table.concat(second.blockers, " | "))
end
local function untouched(world)
	return pulse(world) == nil and world.ui:GetAttribute("Style") == nil and world.ui:GetAttribute("Tint") == Color3.new(0.5, 0.25, 1)
		and world.label.Value == "a" and world.existing.Source == BEFORE and world.second.Source == BEFORE2
end
local canCompile = Engine.loadChunk("return 1", "probe") ~= nil

case("hash.lua matches plan.py fingerprints", function()
	for index, vector in ipairs(CASES.hashes) do
		local got = Hash.fingerprint(vector.text)
		expect(got == vector.fp, "hash vector " .. index .. ": " .. got .. " is not " .. vector.fp)
	end
end)

case("plan.lua matches plan.py on every decision vector", function()
	local order = {}
	for index, op in ipairs(CASES.ops) do
		order[index] = op.id
	end
	for _, v in ipairs(CASES.cases) do
		local ops = CASES.ops
		if v.x then
			ops = CASES.mixedOps
		end
		local observations = {}
		for id, variant in pairs(v.w) do
			observations[id] = CASES.variants[id][variant]
		end
		local results = Plan.classifyAll(ops, observations)
		for index, id in ipairs(order) do
			local want, got = v.r[index], results[id]
			expect(got.state == want[1] and got.reason == want[2] and got.rollback == want[3],
				v.n .. ": " .. id .. " gave " .. got.state .. " / " .. got.reason .. " / " .. got.rollback)
		end
		local decision = Plan.decide(v.m, ops, results, CASES.gates[v.g])
		expect(same(decision.blockers, v.b), v.n .. ": blockers differ: " .. table.concat(decision.blockers, " | "))
		expect(decision.states.hierarchy == v.s[1] and decision.states.sources == v.s[2], v.n .. ": transaction states differ")
		expect(decision.transaction == v.t, v.n .. ": transaction is " .. decision.transaction)
		expect(decision.write == v.ok, v.n .. ": write flag differs")
		expect(#decision.actions == #v.a, v.n .. ": action count differs")
		for index, action in ipairs(decision.actions) do
			expect(action.id == v.a[index][1] and action.action == v.a[index][2], v.n .. ": action " .. index .. " differs")
		end
	end
end)

case("AUDIT on the before state writes nothing and reports each transaction", function()
	local world = newWorld()
	local report, counters = run("AUDIT", world)
	expect(report.ok, "blocked: " .. table.concat(report.blockers, " | "))
	expect(report.transactions.hierarchy.state == "before" and report.transactions.sources.state == "before", "transaction states")
	expect(#report.transactions.hierarchy.ops == 5 and #report.transactions.sources.ops == 2, "op rows")
	expect(report.apply.transaction == "hierarchy" and report.apply.ops == 5, "apply preview")
	expect(report.rollback.transaction == "" and report.rollback.ops == 0, "rollback preview")
	expect(counters.writes == 0 and counters.waypoints == 0 and untouched(world), "AUDIT wrote something")
	expect(opRow(report, "existing").served == (canCompile and "ok" or "unchecked"), "served status " .. opRow(report, "existing").served)
end)

case("APPLY writes the hierarchy transaction only", function()
	local world = newWorld()
	local report, counters = run("APPLY", world)
	expect(report.ok and report.transaction == "hierarchy" and report.wrote == 5, "report: " .. table.concat(report.blockers, " | "))
	local kit = pulse(world)
	expect(kit ~= nil and kit.ClassName == "Folder" and kit:GetAttribute(MARK) == "selftest:kit", "kit folder")
	expect(kit:GetAttribute("Note") == "made by selftest" and kit:GetAttribute("Scale") == 1.5, "kit attributes")
	local probe = kit:FindFirstChild("Probe")
	expect(probe ~= nil and probe.ClassName == "ModuleScript" and probe.Source == PROBE and probe:GetAttribute(MARK) == "selftest:probe", "probe module")
	expect(world.ui:GetAttribute("Style") == "Pulse" and world.ui:GetAttribute("Tint") == Color3.new(0, 0.5, 1) and world.label.Value == "b", "config values")
	expect(world.existing.Source == BEFORE and world.second.Source == BEFORE2, "a source was written in the hierarchy run")
	expect(report.transactions.hierarchy.state == "after" and report.transactions.sources.state == "before", "states after the run")
	expect(counters.waypoints == 2, "waypoints " .. counters.waypoints)
end)

case("second APPLY writes sources, third writes nothing", function()
	local world = newWorld()
	install(world)
	expect(world.existing.Source == AFTER and world.second.Source == AFTER2, "sources not written")
	local third, counters = run("APPLY", world)
	expect(third.ok and third.wrote == 0 and counters.writes == 0 and counters.waypoints == 0, "third APPLY wrote")
	local audit = run("AUDIT", world)
	expect(audit.ok and audit.transactions.hierarchy.state == "after" and audit.transactions.sources.state == "after", "AUDIT after install")
	expect(audit.apply.transaction == "" and audit.rollback.transaction == "sources", "previews after install")
end)

case("the engine waits between source writes", function()
	local world = newWorld()
	run("APPLY", world)
	local _, counters = run("APPLY", world)
	expect(counters.waits == 2, "waits " .. counters.waits)
end)

case("ROLLBACK undoes sources first, then the hierarchy", function()
	local world = newWorld()
	install(world)
	local kit = pulse(world)
	local first = run("ROLLBACK", world)
	expect(first.ok and first.transaction == "sources" and first.wrote == 2, "first ROLLBACK: " .. table.concat(first.blockers, " | "))
	expect(world.existing.Source == BEFORE and world.second.Source == BEFORE2 and pulse(world) == kit, "first ROLLBACK state")
	local second = run("ROLLBACK", world)
	expect(second.ok and second.transaction == "hierarchy" and second.wrote == 5, "second ROLLBACK: " .. table.concat(second.blockers, " | "))
	expect(untouched(world), "place is not back to the before state")
	expect(kit.Parent == nil, "created folder still parented")
	local third = run("ROLLBACK", world)
	expect(third.ok and third.wrote == 0, "third ROLLBACK wrote")
	install(world)
	expect(pulse(world) ~= nil and world.existing.Source == AFTER, "APPLY after ROLLBACK")
end)

case("an unknown source hash blocks the whole run", function()
	local world = newWorld()
	world.second.Source = "return 'edited by hand'\n"
	local audit = run("AUDIT", world)
	expect(not audit.ok and opRow(audit, "second").state == "BLOCKED", "AUDIT did not block")
	expect(audit.transactions.sources.state == "blocked" and audit.transactions.hierarchy.state == "before", "transaction states")
	local report, counters = run("APPLY", world)
	expect(not report.ok and report.wrote == 0 and counters.writes == 0, "APPLY wrote")
	expect(pulse(world) == nil and world.ui:GetAttribute("Style") == nil, "hierarchy written although a source is unknown")
end)

case("a prior source hash is accepted and rewritten", function()
	local world = newWorld()
	world.existing.Source = MIDDLE
	local audit = run("AUDIT", world)
	expect(audit.ok and opRow(audit, "existing").state == "prior", "AUDIT state " .. opRow(audit, "existing").state)
	install(world)
	expect(world.existing.Source == AFTER, "prior source not replaced")
end)

case("a prior created module is rewritten in the hierarchy run", function()
	local world = newWorld()
	install(world)
	pulse(world).Probe.Source = PROBE_OLD
	local report = run("APPLY", world)
	expect(report.ok and report.transaction == "hierarchy" and report.wrote == 1 and pulse(world).Probe.Source == PROBE, "probe not rewritten")
end)

case("an instance without the install mark blocks create", function()
	local world = newWorld()
	make("Folder", "UIPulse", world.gameFolder)
	local report = run("APPLY", world)
	expect(not report.ok and opRow(report, "kit").state == "BLOCKED" and report.wrote == 0, "unmarked folder accepted")
	expect(world.ui:GetAttribute("Style") == nil, "attribute written although create is blocked")
end)

case("an edited created module blocks APPLY and ROLLBACK", function()
	local world = newWorld()
	install(world)
	pulse(world).Probe.Source = "return 'tuned'\n"
	local apply = run("APPLY", world)
	local rollback, counters = run("ROLLBACK", world)
	expect(not apply.ok and not rollback.ok and counters.writes == 0, "edited module not blocked")
	expect(world.existing.Source == AFTER, "ROLLBACK wrote a source although the run was blocked")
end)

case("ROLLBACK refuses when a created instance has children it did not create", function()
	local world = newWorld()
	install(world)
	make("Folder", "Stray", pulse(world))
	local audit = run("AUDIT", world)
	expect(audit.ok and opRow(audit, "kit").rollback:find("Stray", 1, true) ~= nil, "AUDIT does not name the child")
	local report, counters = run("ROLLBACK", world)
	expect(not report.ok and report.wrote == 0 and counters.writes == 0, "ROLLBACK ran")
	expect(world.existing.Source == AFTER and pulse(world) ~= nil, "something was rolled back")
end)

case("ROLLBACK refuses when an attribute was edited since", function()
	local world = newWorld()
	install(world)
	world.ui:SetAttribute("Style", "SomethingElse")
	local report = run("ROLLBACK", world)
	expect(not report.ok and opRow(report, "style").state == "BLOCKED" and world.existing.Source == AFTER, "edited attribute not refused")
end)

case("an earlier value of this delivery (was) is replaced by APPLY", function()
	local world = newWorld()
	world.ui:SetAttribute("Style", "Draft")
	local audit = run("AUDIT", world)
	expect(opRow(audit, "style").state == "prior", "state " .. opRow(audit, "style").state)
	local report = run("APPLY", world)
	expect(report.ok and world.ui:GetAttribute("Style") == "Pulse", "was value not replaced")
end)

case("a served source that does not match its hash blocks before any write", function()
	local world = newWorld()
	local files = newFiles()
	files["t/after/Probe.lua"] = PROBE .. "-- changed on disk\n"
	local audit = run("AUDIT", world, { files = files })
	expect(not audit.ok and opRow(audit, "probe").served == "mismatch", "AUDIT served status")
	local report, counters = run("APPLY", world, { files = files })
	expect(not report.ok and counters.writes == 0 and untouched(world), "APPLY wrote")
end)

case("a source that cannot be fetched blocks APPLY and only warns in AUDIT", function()
	local world = newWorld()
	local files = newFiles()
	files["t/after/Probe.lua"] = nil
	local audit = run("AUDIT", world, { files = files })
	expect(audit.ok and #audit.warnings > 0 and opRow(audit, "probe").served == "unavailable", "AUDIT")
	local report = run("APPLY", world, { files = files })
	expect(not report.ok and untouched(world), "APPLY wrote")
end)

case("an after-source with a syntax error blocks (needs loadstring)", function()
	if not canCompile then
		return "skipped"
	end
	local world = newWorld()
	run("APPLY", world)
	local files = newFiles()
	files["t/after/Second.lua"] = BROKEN
	local data = newData()
	data.ops[7].after = Hash.fingerprint(BROKEN)
	local report, counters = run("APPLY", world, { files = files, data = data })
	expect(not report.ok and counters.writes == 0 and world.existing.Source == BEFORE, "syntax error not blocked")
end)

case("a failure while writing sources restores the sources already written", function()
	local world = newWorld()
	run("APPLY", world)
	local report = run("APPLY", world, { setSource = function(node, text, call)
		if call == 2 then
			error("injected failure")
		end
		node.Source = text
	end })
	expect(not report.ok and report.restored == true and report.wrote == 0, "report")
	expect(world.existing.Source == BEFORE and world.second.Source == BEFORE2, "sources not restored")
	expect(report.transactions.sources.state == "before", "state after recovery")
end)

case("a failure while writing the hierarchy removes created instances and restores values", function()
	local world = newWorld()
	local report = run("APPLY", world, { setSource = function()
		error("injected failure")
	end })
	expect(not report.ok and report.restored == true, "report")
	expect(untouched(world), "hierarchy not restored")
end)

case("a write that does not take effect fails the post-write check and is undone", function()
	local world = newWorld()
	run("APPLY", world)
	local report = run("APPLY", world, { setSource = function(node, text, call)
		if call ~= 2 then
			node.Source = text
		end
	end })
	expect(not report.ok and world.existing.Source == BEFORE and world.second.Source == BEFORE2, "silent write accepted")
end)

case("APPLY refuses while the sandbox test window is open", function()
	local world = newWorld()
	world.onboarding:SetAttribute("StudioVehicleSandboxEveryPlay", true)
	local audit = run("AUDIT", world)
	expect(audit.ok and #audit.warnings > 0 and #audit.apply.blockers == 1, "AUDIT does not warn")
	local report = run("APPLY", world)
	expect(not report.ok and untouched(world), "APPLY ran with the sandbox on")
	world.onboarding:SetAttribute("StudioVehicleSandboxEveryPlay", false)
	world.onboarding:SetAttribute("UIRestyleTestWindow", "open")
	report = run("APPLY", world)
	expect(not report.ok and untouched(world), "APPLY ran with the marker set")
	world.onboarding.Parent = nil
	report = run("APPLY", world)
	expect(not report.ok and untouched(world), "APPLY ran although the window cannot be checked")
end)

case("ROLLBACK is allowed while the test window is open", function()
	local world = newWorld()
	install(world)
	world.onboarding:SetAttribute("UIRestyleTestWindow", "open")
	local report = run("ROLLBACK", world)
	expect(report.ok and report.transaction == "sources", "ROLLBACK refused")
end)

case("wrong place or not Edit blocks every mode", function()
	local world = newWorld()
	for _, options in ipairs({ { placeId = 2 }, { isEdit = false } }) do
		for _, mode in ipairs({ "AUDIT", "APPLY", "ROLLBACK" }) do
			local report, counters = run(mode, world, options)
			expect(not report.ok and counters.writes == 0 and untouched(world), mode .. " was not blocked")
		end
	end
end)

case("an op declared in the wrong transaction is refused", function()
	local world = newWorld()
	local data = newData()
	data.ops[6].transaction = "hierarchy"
	local report = run("APPLY", world, { data = data })
	expect(not report.ok and untouched(world), "mixed spec accepted")
end)

case("a phase marked not installable can be audited but not applied", function()
	local world = newWorld()
	local data = newData()
	data.installable = false
	expect(run("AUDIT", world, { data = data }).ok, "AUDIT blocked")
	expect(not run("APPLY", world, { data = data }).ok and untouched(world), "APPLY ran")
end)

case("two instances with one name make the path ambiguous", function()
	local world = newWorld()
	make("ModuleScript", "Existing", world.modules)
	local report = run("APPLY", world)
	expect(not report.ok and opRow(report, "existing").state == "BLOCKED" and pulse(world) == nil, "ambiguous path accepted")
end)

case("the Classic verify hook runs a fetched read-only script (needs loadstring)", function()
	if not canCompile then
		return "skipped"
	end
	local world = newWorld()
	local files = newFiles()
	local data = newData()
	data.classicVerify = "classic/verify.lua"
	files["classic/verify.lua"] = 'return \'{"ok":true,"failures":0}\'\n'
	local good = run("AUDIT", world, { files = files, data = data })
	expect(good.ok and good.classicVerify.ran and good.classicVerify.ok, "passing verify")
	files["classic/verify.lua"] = 'return \'{"ok":false,"failures":3}\'\n'
	local bad = run("AUDIT", world, { files = files, data = data })
	expect(not bad.ok and bad.classicVerify.failures == 3, "failing verify did not block AUDIT")
	files["classic/verify.lua"] = nil
	local absent = run("AUDIT", world, { files = files, data = data })
	expect(absent.ok and absent.classicVerify.ran == false and #absent.warnings > 0, "missing verify")
end)

case("the report encodes to JSON", function()
	local world = newWorld()
	local text = HttpService:JSONEncode((run("AUDIT", world)))
	expect(type(text) == "string" and #text > 100, "no JSON")
end)

case("the fake tree never reached the DataModel", function()
	local world = newWorld()
	install(world)
	expect(world.RS.Parent == nil and not world.RS:IsDescendantOf(game), "the test tree is parented")
end)

return HttpService:JSONEncode(summary)
