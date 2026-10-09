-- engine.lua: the one installer engine of the UI restyle programme. Needs Hash (hash.lua) and Plan (plan.lua)
-- above it; build.py concatenates them. Engine.run(MODE, DATA, env) -> report table.
--
-- Everything the engine touches outside its own logic comes through env, so selftest.lua can run it against a
-- detached tree with fake files:
--   env.placeId, env.isEdit           where it is running
--   env.root(name) -> Instance?       resolves the first path element (a service in the real place)
--   env.fetch(file) -> string         repository file by path; errors when it cannot be read
--   env.loadChunk(text, name)         -> function | false, syntax error | nil, why no check is possible
--   env.getSource(node) / env.setSource(node, text)    direct .Source, as the lighting and hover_feel engines do
--   env.wait()                        task.wait between batches
--   env.waypoint(label)               ChangeHistoryService:SetWaypoint, as hover_feel does
--   env.jsonDecode(text)              only for the Classic verify result
--
-- Guarantees (decision rules are in plan.lua):
--   * Nothing is written unless the place and Edit mode are right, every op is in a known state, and every source
--     that will be written was fetched, matched its recorded fingerprint and compiled.
--   * One run writes one transaction: hierarchy (create, attribute, property) or sources. Never both.
--   * A failed write undoes every change of the run, in reverse order.
local Engine = {}
Engine.VERSION = 1
Engine.TEST_WINDOW_PATH = { "ReplicatedStorage", "Config", "Player", "Onboarding" }
local BATCH = 20

local function decode(value)
	if type(value) ~= "table" then
		return value
	end
	local kind = value.Type
	if kind == "Color3" then
		return Color3.new(value.R, value.G, value.B)
	end
	if kind == "Vector3" then
		return Vector3.new(value.X, value.Y, value.Z)
	end
	if kind == "Vector2" then
		return Vector2.new(value.X, value.Y)
	end
	if kind == "UDim" then
		return UDim.new(value.Scale, value.Offset)
	end
	if kind == "UDim2" then
		return UDim2.new(value.XScale, value.XOffset, value.YScale, value.YOffset)
	end
	error("unsupported value type " .. tostring(kind))
end

local function equal(a, b)
	if type(a) == "number" and type(b) == "number" then
		return a == b or math.abs(a - b) <= 1e-6 * math.max(1, math.abs(a), math.abs(b))
	end
	return typeof(a) == typeof(b) and a == b
end

local function matchOf(op, value)
	if equal(value, decode(op.after)) then
		return "after"
	end
	if equal(value, decode(op.before)) then
		return "before"
	end
	for _, was in ipairs(op.was or {}) do
		if equal(value, decode(was)) then
			return "prior"
		end
	end
	return "other"
end

-- Syntax check through loadstring. Edit has it; Play does not, and then the check is reported as not done.
function Engine.loadChunk(text, name)
	if type(loadstring) ~= "function" then
		return nil, "loadstring is unavailable"
	end
	local ok, chunk, err = pcall(loadstring, text, "=" .. tostring(name))
	if not ok then
		return nil, "loadstring is unavailable: " .. tostring(chunk)
	end
	if chunk == nil then
		return false, tostring(err)
	end
	return chunk
end

-- AUDIT hook: runs scripts/ui_restyle/classic/out_verify_classic.lua (read-only, returns one JSON string).
function Engine.classicVerify(file, env)
	local fetched, text = pcall(env.fetch, file)
	if not fetched or type(text) ~= "string" then
		return { ran = false, ok = false, error = "could not fetch " .. file .. ": " .. tostring(text) }
	end
	local chunk, err = env.loadChunk(text, "out_verify_classic")
	if not chunk then
		return { ran = false, ok = false, error = "could not load " .. file .. ": " .. tostring(err) }
	end
	local ran, result = pcall(chunk)
	if not ran then
		return { ran = false, ok = false, error = tostring(result) }
	end
	local decoded = result
	if type(result) == "string" and env.jsonDecode then
		local parsed, value = pcall(env.jsonDecode, result)
		if parsed then
			decoded = value
		end
	end
	if type(decoded) == "table" then
		return { ran = true, ok = decoded.ok == true, failures = decoded.failures, result = decoded }
	end
	return { ran = true, ok = false, error = "unexpected result", result = tostring(result) }
end

function Engine.run(MODE, DATA, env)
	local MARK = DATA.markAttribute
	local ops = DATA.ops
	local report = {
		engine = Engine.VERSION, phase = DATA.phase, mode = MODE, ok = false, wrote = 0, transaction = "",
		blockers = {}, warnings = {}, transactions = {}, next = "",
	}
	local function blocker(text)
		table.insert(report.blockers, text)
	end
	local function warning(text)
		table.insert(report.warnings, text)
	end
	local byId, marks = {}, {}
	for _, op in ipairs(ops) do
		byId[op.id] = op
		if op.mark then
			marks[op.mark] = true
		end
	end

	local function childNamed(parent, name)
		local found, count = nil, 0
		for _, child in ipairs(parent:GetChildren()) do
			if child.Name == name then
				found = found or child
				count += 1
			end
		end
		return found, count
	end
	-- Walks path[1..last]. -> instance, "ok" | nil, "missing" | nil, "ambiguous"
	local function resolve(path, last)
		local node = env.root(path[1])
		if not node then
			return nil, "missing"
		end
		for i = 2, last do
			local child, count = childNamed(node, path[i])
			if count > 1 then
				return nil, "ambiguous"
			end
			if not child then
				return nil, "missing"
			end
			node = child
		end
		return node, "ok"
	end

	-- -> observation (plan.py header), instance, parent (create only), raw value (attribute and property only)
	local function observe(op)
		local obs = {}
		if op.kind == "create" then
			local parent, status = resolve(op.path, #op.path - 1)
			if status == "ambiguous" then
				obs.ambiguous = true
				return obs
			end
			obs.parentExists = parent ~= nil
			obs.exists = false
			if not parent then
				return obs
			end
			local node, count = childNamed(parent, op.path[#op.path])
			if count > 1 then
				obs.ambiguous = true
				return obs
			end
			if not node then
				return obs, nil, parent
			end
			obs.exists = true
			obs.className = node.ClassName
			local mark = node:GetAttribute(MARK)
			if type(mark) == "string" then
				obs.mark = mark
			end
			if op.after ~= nil and node:IsA("LuaSourceContainer") then
				obs.fp = Hash.fingerprint(env.getSource(node))
			end
			obs.foreignChildren = {}
			for _, child in ipairs(node:GetChildren()) do
				local childMark = child:GetAttribute(MARK)
				if type(childMark) ~= "string" or not marks[childMark] then
					table.insert(obs.foreignChildren, child.Name)
				end
			end
			table.sort(obs.foreignChildren)
			local tuned = {}
			for key, value in pairs(op.attributes or {}) do
				if not equal(node:GetAttribute(key), decode(value)) then
					table.insert(tuned, key)
				end
			end
			table.sort(tuned)
			obs.tuned = table.concat(tuned, ", ")
			return obs, node, parent
		end
		local node, status = resolve(op.path, #op.path)
		if status == "ambiguous" then
			obs.ambiguous = true
			return obs
		end
		obs.exists = node ~= nil
		if not node then
			return obs
		end
		obs.className = node.ClassName
		if op.kind == "source" then
			if node:IsA("LuaSourceContainer") then
				obs.fp = Hash.fingerprint(env.getSource(node))
			end
			return obs, node
		end
		local value
		if op.kind == "attribute" then
			value = node:GetAttribute(op.key)
		else
			local readable, read = pcall(function()
				return node[op.key]
			end)
			if not readable then
				obs.match = "other"
				obs.now = "unreadable property"
				return obs, node
			end
			value = read
		end
		obs.match = matchOf(op, value)
		obs.now = tostring(value)
		return obs, node, nil, value
	end
	local function observeAll()
		local observations, raw = {}, {}
		for _, op in ipairs(ops) do
			local obs, _, _, value = observe(op)
			observations[op.id] = obs
			raw[op.id] = value
		end
		return observations, raw
	end

	-- "" when closed. APPLY refuses while the sandbox test window is open (or cannot be checked).
	local function testWindow()
		local folder = resolve(Engine.TEST_WINDOW_PATH, #Engine.TEST_WINDOW_PATH)
		if not folder then
			return table.concat(Engine.TEST_WINDOW_PATH, ".") .. " was not found, so the window cannot be checked"
		end
		if folder:GetAttribute("StudioVehicleSandboxEveryPlay") == true then
			return "StudioVehicleSandboxEveryPlay is true"
		end
		if folder:GetAttribute("UIRestyleTestWindow") ~= nil then
			return "UIRestyleTestWindow marker is set"
		end
		return ""
	end

	local served, texts = {}, {}
	-- Fetch, fingerprint and compile one recorded source. which = "after" | "before".
	-- -> text or nil, "ok" | "unchecked" | "unavailable" | "mismatch" | "syntax", detail
	local function load(op, which)
		local fetched, text = pcall(env.fetch, DATA.base .. op.file[which])
		if not fetched or type(text) ~= "string" then
			return nil, "unavailable", tostring(text)
		end
		if Hash.fingerprint(text) ~= op[which] then
			return nil, "mismatch", ""
		end
		local chunk, err = env.loadChunk(text, op.id)
		if chunk == false then
			return nil, "syntax", tostring(err)
		end
		if chunk == nil then
			return text, "unchecked", tostring(err)
		end
		return text, "ok", ""
	end

	local function fill(results, observations, states)
		report.transactions = {}
		for _, name in ipairs(Plan.TRANSACTIONS) do
			report.transactions[name] = { state = states[name], ops = {} }
		end
		for _, op in ipairs(ops) do
			local result, obs = results[op.id], observations[op.id]
			local bucket = report.transactions[Plan.transactionOf(op)] or report.transactions.hierarchy
			local state = result.state
			if state == "blocked" then
				state = "BLOCKED"
			end
			table.insert(bucket.ops, {
				id = op.id, kind = op.kind, path = table.concat(op.path, "."), key = op.key or "",
				state = state, reason = result.reason, rollback = result.rollback,
				served = served[op.id] or "", now = obs.now or obs.fp or "", tuned = obs.tuned or "",
			})
		end
	end
	local function preview(decision)
		return { transaction = decision.transaction, ops = #decision.actions, blockers = decision.blockers }
	end

	local observations, raw = observeAll()
	local results = Plan.classifyAll(ops, observations)
	local gate = {
		placeOk = env.placeId == DATA.placeId,
		isEdit = env.isEdit == true,
		testWindow = testWindow(),
		notInstallable = DATA.installable == false,
	}

	if MODE == "AUDIT" then
		local decision = Plan.decide("AUDIT", ops, results, gate)
		for _, text in ipairs(decision.blockers) do
			blocker(text)
		end
		for _, op in ipairs(ops) do
			local state = results[op.id].state
			if op.file and op.file.after and state ~= "after" and state ~= "blocked" then
				local _, status, detail = load(op, "after")
				served[op.id] = status
				if status == "mismatch" then
					blocker(op.id .. ": the served after-source does not match its recorded hash")
				elseif status == "syntax" then
					blocker(op.id .. ": the after-source does not compile: " .. detail)
				elseif status == "unavailable" then
					warning(op.id .. ": the after-source could not be fetched (" .. detail .. ")")
				elseif status == "unchecked" then
					warning(op.id .. ": syntax not checked (" .. detail .. ")")
				end
			end
		end
		local apply = Plan.decide("APPLY", ops, results, gate)
		local rollback = Plan.decide("ROLLBACK", ops, results, gate)
		report.apply = preview(apply)
		report.rollback = preview(rollback)
		if gate.testWindow ~= "" then
			warning("APPLY would refuse: sandbox test window is open: " .. gate.testWindow)
		end
		if DATA.classicVerify then
			local classic = Engine.classicVerify(DATA.classicVerify, env)
			report.classicVerify = classic
			if not classic.ran then
				warning("Classic verify did not run: " .. tostring(classic.error))
			elseif not classic.ok then
				blocker("Classic verify reports failures: " .. tostring(classic.failures))
			end
		end
		fill(results, observations, decision.states)
		report.ok = #report.blockers == 0
		if apply.transaction ~= "" then
			report.next = "APPLY would write the " .. apply.transaction .. " transaction (" .. #apply.actions .. " ops)."
		else
			report.next = "APPLY has nothing to write."
		end
		return report
	end

	local decision = Plan.decide(MODE, ops, results, gate)
	for _, text in ipairs(decision.blockers) do
		blocker(text)
	end
	report.transaction = decision.transaction
	local want, which = "after", "after"
	if MODE == "ROLLBACK" then
		want, which = "before", "before"
	end
	if decision.write then
		for _, item in ipairs(decision.actions) do
			local op = byId[item.id]
			local action = item.action
			if action == "write" or action == "rewrite" or action == "restore" or (action == "create" and op.after ~= nil) then
				local text, status, detail = load(op, which)
				served[op.id] = status
				if text == nil then
					blocker(op.id .. ": the " .. which .. "-source is " .. status .. " " .. detail)
				else
					texts[op.id] = text
					if status == "unchecked" then
						warning(op.id .. ": syntax not checked (" .. detail .. ")")
					end
				end
			end
		end
		if #report.blockers == 0 then
			-- Fetching yields, so read the place again and require that nothing moved.
			local observationsNow, rawNow = observeAll()
			local resultsNow = Plan.classifyAll(ops, observationsNow)
			for _, op in ipairs(ops) do
				if resultsNow[op.id].state ~= results[op.id].state or observationsNow[op.id].fp ~= observations[op.id].fp then
					blocker(op.id .. ": changed while sources were being fetched")
				end
			end
			observations, raw, results = observationsNow, rawNow, resultsNow
		end
	end
	if #report.blockers > 0 or not decision.write then
		fill(results, observations, decision.states)
		report.ok = #report.blockers == 0
		if report.ok then
			report.next = "Nothing to write: every op is already " .. want .. "."
		else
			report.next = "Blocked. Nothing was written."
		end
		return report
	end

	local journal, removed = {}, {}
	local function perform(op, action)
		if Plan.transactionOf(op) ~= decision.transaction then
			error(op.id .. ": refusing to mix transactions")
		end
		local obs, node, parent, value = observe(op)
		local target = op.after
		if MODE == "ROLLBACK" then
			target = op.before
		end
		if action == "create" then
			if obs.exists or parent == nil then
				error(op.id .. ": target changed during the run")
			end
			local made = Instance.new(op.class)
			table.insert(journal, function()
				made:Destroy()
			end)
			made.Name = op.path[#op.path]
			if op.after ~= nil then
				env.setSource(made, texts[op.id])
			end
			for key, propertyValue in pairs(op.properties or {}) do
				made[key] = decode(propertyValue)
			end
			for key, attributeValue in pairs(op.attributes or {}) do
				made:SetAttribute(key, decode(attributeValue))
			end
			made:SetAttribute(MARK, op.mark)
			made.Parent = parent
		elseif node == nil then
			error(op.id .. ": target disappeared during the run")
		elseif action == "write" or action == "rewrite" or action == "restore" then
			local old = env.getSource(node)
			if Hash.fingerprint(old) ~= observations[op.id].fp then
				error(op.id .. ": source changed during the run")
			end
			table.insert(journal, function()
				env.setSource(node, old)
			end)
			env.setSource(node, texts[op.id])
		elseif action == "remove" then
			local was = node.Parent
			table.insert(journal, function()
				node.Parent = was
			end)
			table.insert(removed, node)
			node.Parent = nil
		elseif op.kind == "attribute" then
			if not equal(value, raw[op.id]) then
				error(op.id .. ": value changed during the run")
			end
			table.insert(journal, function()
				node:SetAttribute(op.key, value)
			end)
			node:SetAttribute(op.key, decode(target))
		elseif op.kind == "property" then
			table.insert(journal, function()
				node[op.key] = value
			end)
			node[op.key] = decode(target)
		else
			error(op.id .. ": unknown action " .. tostring(action))
		end
	end

	local label = "ui_restyle " .. tostring(DATA.phase) .. " " .. MODE .. " " .. decision.transaction
	if not pcall(env.waypoint, label .. " before") then
		warning("ChangeHistoryService waypoint failed (before)")
	end
	local wrote = 0
	local ok, problem = pcall(function()
		for index, item in ipairs(decision.actions) do
			local op = byId[item.id]
			perform(op, item.action)
			wrote += 1
			if op.kind == "source" or index % BATCH == 0 then
				env.wait()
			end
		end
		local check = Plan.classifyAll(ops, (observeAll()))
		for _, op in ipairs(ops) do
			if Plan.transactionOf(op) == decision.transaction and check[op.id].state ~= want then
				error(op.id .. ": post-write check found " .. check[op.id].state .. " " .. check[op.id].reason)
			end
		end
	end)
	if ok then
		-- Removed instances were only unparented until the whole transaction verified.
		for _, node in ipairs(removed) do
			pcall(function()
				node:Destroy()
			end)
		end
		report.wrote = wrote
		if not pcall(env.waypoint, label .. " after") then
			warning("ChangeHistoryService waypoint failed (after)")
		end
	else
		local errors = {}
		for i = #journal, 1, -1 do
			local undone, err = pcall(journal[i])
			if not undone then
				table.insert(errors, tostring(err))
			end
		end
		report.restored = #errors == 0
		if #errors == 0 then
			blocker("write failed and every change of this run was undone: " .. tostring(problem))
		else
			blocker("write failed and RECOVERY IS INCOMPLETE (" .. table.concat(errors, "; ") .. "): " .. tostring(problem))
		end
	end

	local finalObservations = observeAll()
	local finalResults = Plan.classifyAll(ops, finalObservations)
	local after = Plan.decide(MODE, ops, finalResults, gate)
	fill(finalResults, finalObservations, after.states)
	report.ok = ok
	if not ok then
		report.next = "Failed. Run AUDIT before anything else."
	elseif after.transaction ~= "" then
		report.next = "Wrote the " .. decision.transaction .. " transaction. Run AUDIT, then " .. MODE .. " again for the " .. after.transaction .. " transaction."
	else
		report.next = "Complete: every op is " .. want .. "."
	end
	return report
end
