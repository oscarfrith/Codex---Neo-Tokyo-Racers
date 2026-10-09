-- plan.lua: decision logic of the UI restyle installer engine. Pure: no instances, no services.
-- Line-for-line mirror of plan.py (read its header for the data shapes). selftest.lua replays vectors made by
-- plan.py against this file, so change both together.
local Plan = {}
Plan.TRANSACTIONS = { "hierarchy", "sources" }
local HIERARCHY_KINDS = { create = true, attribute = true, property = true }
local MODES = { AUDIT = true, APPLY = true, ROLLBACK = true }

local function contains(list, value)
	for _, item in ipairs(list or {}) do
		if item == value then
			return true
		end
	end
	return false
end

function Plan.transactionOf(op)
	if op.kind == "source" then
		return "sources"
	end
	if HIERARCHY_KINDS[op.kind] then
		return "hierarchy"
	end
	return ""
end

-- -> state, reason. parentState is the state of the create op that makes this op's parent, or "".
function Plan.classify(op, obs, parentState)
	if obs.ambiguous then
		return "blocked", "ambiguous path: two instances share a name"
	end
	local kind = op.kind
	if kind == "source" then
		if not obs.exists then
			return "blocked", "script is missing"
		end
		if obs.className ~= op.class then
			return "blocked", "class is " .. tostring(obs.className) .. ", expected " .. tostring(op.class)
		end
		if obs.fp == op.after then
			return "after", ""
		end
		if obs.fp == op.before then
			return "before", ""
		end
		if contains(op.prior, obs.fp) then
			return "prior", ""
		end
		return "blocked", "source matches no recorded hash (" .. tostring(obs.fp) .. ")"
	end
	if kind == "create" then
		if not obs.exists then
			if obs.parentExists or parentState == "before" then
				return "before", ""
			end
			return "blocked", "parent is missing"
		end
		if obs.className ~= op.class then
			return "blocked", "exists as " .. tostring(obs.className) .. ", expected " .. tostring(op.class)
		end
		if obs.mark ~= op.mark then
			return "blocked", "exists and was not created by this installer (install mark absent or different)"
		end
		if op.after == nil then
			return "after", ""
		end
		if obs.fp == op.after then
			return "after", ""
		end
		if contains(op.prior, obs.fp) then
			return "prior", ""
		end
		return "blocked", "created script was edited since install (" .. tostring(obs.fp) .. ")"
	end
	if kind == "attribute" or kind == "property" then
		if not obs.exists then
			return "blocked", "target instance is missing"
		end
		local match = obs.match
		if match == "after" or match == "before" or match == "prior" then
			return match, ""
		end
		return "blocked", "value was edited since it was recorded"
	end
	return "blocked", "unknown op kind"
end

-- Why ROLLBACK must refuse this op even though its state is known, or "".
function Plan.rollbackBlock(op, obs, state)
	if op.kind == "create" and (state == "after" or state == "prior") then
		local foreign = obs.foreignChildren or {}
		if #foreign > 0 then
			return "has children this installer did not create: " .. table.concat(foreign, ", ")
		end
	end
	return ""
end

-- -> { [id] = { state, reason, rollback } }. A create op's parent op always comes earlier in ops.
function Plan.classifyAll(ops, observations)
	local results = {}
	for _, op in ipairs(ops) do
		local obs = observations[op.id]
		local parent = results[op.parentOp or ""]
		local parentState = ""
		if parent then
			parentState = parent.state
		end
		local state, reason = Plan.classify(op, obs, parentState)
		results[op.id] = { state = state, reason = reason, rollback = Plan.rollbackBlock(op, obs, state) }
	end
	return results
end

function Plan.transactionState(name, ops, results)
	local count, blocked, after, before = 0, 0, 0, 0
	for _, op in ipairs(ops) do
		if Plan.transactionOf(op) == name then
			local state = results[op.id].state
			count += 1
			if state == "blocked" then
				blocked += 1
			elseif state == "after" then
				after += 1
			elseif state == "before" then
				before += 1
			end
		end
	end
	if count == 0 then
		return "empty"
	end
	if blocked > 0 then
		return "blocked"
	end
	if after == count then
		return "after"
	end
	if before == count then
		return "before"
	end
	return "mixed"
end

function Plan.actionFor(mode, op, state)
	local kind = op.kind
	if mode == "APPLY" then
		if kind == "source" then
			return "write"
		end
		if kind == "create" then
			if state == "before" then
				return "create"
			end
			return "rewrite"
		end
		return "set"
	end
	if kind == "source" then
		return "restore"
	end
	if kind == "create" then
		return "remove"
	end
	return "reset"
end

-- One run writes at most ONE transaction.
-- APPLY order: hierarchy, then sources. ROLLBACK order: sources, then hierarchy (ops in reverse).
-- gate: placeOk, isEdit, testWindow ("" or why the sandbox test window counts as open), notInstallable.
-- -> { blockers = {...}, states = { [name] = state }, transaction = name or "", actions = { { id, action } }, write }
function Plan.decide(mode, ops, results, gate)
	local blockers = {}
	if not MODES[mode] then
		table.insert(blockers, "unknown mode " .. tostring(mode))
	end
	if not gate.placeOk then
		table.insert(blockers, "wrong place")
	end
	if not gate.isEdit then
		table.insert(blockers, "Studio is not in Edit mode")
	end
	if mode ~= "AUDIT" and gate.notInstallable then
		table.insert(blockers, "this phase is marked not installable")
	end
	if mode == "APPLY" and (gate.testWindow or "") ~= "" then
		table.insert(blockers, "sandbox test window is open: " .. gate.testWindow)
	end
	for _, op in ipairs(ops) do
		local txn = Plan.transactionOf(op)
		if txn == "" or (op.transaction or txn) ~= txn then
			table.insert(blockers, op.id .. ": refusing to mix transactions (" .. tostring(op.kind) .. " op declared in " .. tostring(op.transaction or "?") .. ")")
		end
		local result = results[op.id]
		if result.state == "blocked" then
			table.insert(blockers, op.id .. ": " .. result.reason)
		elseif mode == "ROLLBACK" and result.rollback ~= "" then
			table.insert(blockers, op.id .. ": " .. result.rollback)
		end
	end
	local states = {}
	for _, name in ipairs(Plan.TRANSACTIONS) do
		states[name] = Plan.transactionState(name, ops, results)
	end
	local want = "after"
	local order, ordered = {}, {}
	if mode == "ROLLBACK" then
		want = "before"
		for i = #Plan.TRANSACTIONS, 1, -1 do
			table.insert(order, Plan.TRANSACTIONS[i])
		end
		for i = #ops, 1, -1 do
			table.insert(ordered, ops[i])
		end
	else
		for _, name in ipairs(Plan.TRANSACTIONS) do
			table.insert(order, name)
		end
		for _, op in ipairs(ops) do
			table.insert(ordered, op)
		end
	end
	local transaction, actions = "", {}
	if mode == "APPLY" or mode == "ROLLBACK" then
		for _, name in ipairs(order) do
			local pending = 0
			for _, op in ipairs(ordered) do
				local state = results[op.id].state
				if Plan.transactionOf(op) == name and state ~= want then
					pending += 1
					if state ~= "blocked" then
						table.insert(actions, { id = op.id, action = Plan.actionFor(mode, op, state) })
					end
				end
			end
			if pending > 0 then
				transaction = name
				break
			end
		end
	end
	return { blockers = blockers, states = states, transaction = transaction, actions = actions, write = #blockers == 0 and #actions > 0 }
end
