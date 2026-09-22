-- Generated bundles inject operations; this module never requires game code.
return function(bundle, mode, env)
    assert(mode == "AUDIT" or mode == "APPLY" or mode == "ROLLBACK", "Invalid mode")
    assert(env.placeId == bundle.place_id and env.isEdit, "Wrong place or mode")
    local targets, before, after = {}, true, true
    for i, op in ipairs(bundle.operations) do
        local target = env.resolve(op.path)
        assert(target.ClassName == op.class_name, "Class drift")
        targets[i] = target
        local value = env.read(target, op)
        before = before and value == op.before
        after = after and value == op.after
        if op.kind == "source" then
            assert(env.compile(op.before), "Before source does not compile")
            assert(env.compile(op.after), "After source does not compile")
        end
    end
    assert(before or after, "Unexpected or partially installed state; inspect before proceeding")
    if mode == "AUDIT" then return {state = after and "after" or "before", changed = 0} end
    local undo = mode == "ROLLBACK"
    if (undo and before) or (not undo and after) then return {state = undo and "before" or "after", changed = 0} end
    local from, to = undo and "after" or "before", undo and "before" or "after"
    local attempted = 0
    local ok, err = pcall(function()
        for i, op in ipairs(bundle.operations) do
            assert(env.read(targets[i], op) == op[from], "State changed during delivery")
            attempted = i
            env.write(targets[i], op, op[to])
        end
        for i, op in ipairs(bundle.operations) do
            assert(env.read(targets[i], op) == op[to], "Post-write audit failed")
        end
    end)
    if not ok then
        local failures = {}
        for i = attempted, 1, -1 do
            local op = bundle.operations[i]
            local restored, why = pcall(function()
                local current = env.read(targets[i], op)
                assert(current == op[to] or current == op[from], "Intervening edit; refusing overwrite")
                env.write(targets[i], op, op[from])
                assert(env.read(targets[i], op) == op[from], "Recovery verification failed")
            end)
            if not restored then table.insert(failures, tostring(why)) end
        end
        error(tostring(err) .. (#failures > 0 and ("; RECOVERY INCOMPLETE: " .. table.concat(failures, "; ")) or "; restored attempted changes"))
    end
    return {state = undo and "before" or "after", changed = #bundle.operations}
end
