-- Architecture programme installer engine. Generated bundles inject operations; never requires game code.
-- Operation kinds: source (existing script body), module (create/remove a new script), attribute (primitive).
return function(bundle, mode, env)
	assert(mode == "AUDIT" or mode == "APPLY" or mode == "ROLLBACK", "Invalid mode")
	assert(env.placeId == bundle.place_id and env.isEdit, "Wrong place or mode")
	local targets, before, after = {}, true, true
	for i, op in ipairs(bundle.operations) do
		local target = env.resolve(op)
		if target then assert(target.ClassName == op.class_name, "Class drift: " .. table.concat(op.path, ".")) end
		targets[i] = target
		local value = env.read(target, op)
		before = before and value == op.before
		after = after and value == op.after
		if op.kind == "source" or op.kind == "module" then
			for _, text in ipairs({ op.before, op.after }) do
				if text ~= nil then
					local compiled, err = env.compile(text)
					assert(compiled, "Source does not compile: " .. table.concat(op.path, ".") .. ": " .. tostring(err))
				end
			end
		end
	end
	assert(before or after, "Unexpected or partially installed state; inspect before proceeding")
	if mode == "AUDIT" then return { state = after and "after" or "before", changed = 0 } end
	local undo = mode == "ROLLBACK"
	if (undo and before) or (not undo and after) then return { state = undo and "before" or "after", changed = 0 } end
	local from, to = undo and "after" or "before", undo and "before" or "after"
	local order = {}
	for i = 1, #bundle.operations do order[i] = undo and (#bundle.operations - i + 1) or i end
	local attempted = 0
	local ok, err = pcall(function()
		for step, i in ipairs(order) do
			local op = bundle.operations[i]
			assert(env.read(targets[i], op) == op[from], "State changed during delivery")
			attempted = step
			targets[i] = env.write(targets[i], op, op[to])
		end
		for _, i in ipairs(order) do
			local op = bundle.operations[i]
			assert(env.read(targets[i], op) == op[to], "Post-write audit failed: " .. table.concat(op.path, "."))
		end
	end)
	if not ok then
		local failures = {}
		for step = attempted, 1, -1 do
			local i = order[step]
			local op = bundle.operations[i]
			local restored, why = pcall(function()
				local current = env.read(targets[i], op)
				assert(current == op[to] or current == op[from], "Intervening edit; refusing overwrite")
				targets[i] = env.write(targets[i], op, op[from])
				assert(env.read(targets[i], op) == op[from], "Recovery verification failed")
			end)
			if not restored then table.insert(failures, tostring(why)) end
		end
		error(tostring(err) .. (#failures > 0 and ("; RECOVERY INCOMPLETE: " .. table.concat(failures, "; ")) or "; restored attempted changes"))
	end
	return { state = undo and "before" or "after", changed = #bundle.operations }
end
