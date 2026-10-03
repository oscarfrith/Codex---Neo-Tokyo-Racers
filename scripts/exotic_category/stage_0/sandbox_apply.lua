-- Generated delivery: review spec and before/after capture. No live text replacement.
local run=(function()
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

end)()
local bundle={["\112\108\097\099\101\095\105\100"]=133417340424236,["\099\097\112\116\117\114\101\095\115\104\097\050\053\054"]="\101\055\048\097\048\054\098\052\097\102\055\050\098\101\099\101\102\102\101\097\052\049\099\100\056\054\102\099\053\098\056\054\055\050\099\050\100\098\099\056\055\098\056\057\057\055\101\054\056\101\053\099\054\102\056\049\055\049\056\097\052\097\056\055",["\116\097\115\107"]="\101\120\111\116\105\099\045\099\097\116\101\103\111\114\121\045\115\116\097\103\101\048\045\115\097\110\100\098\111\120\045\111\110",["\108\097\110\101"]="\070\097\115\116",["\111\112\101\114\097\116\105\111\110\115"]={{["\107\105\110\100"]="\097\116\116\114\105\098\117\116\101",["\112\097\116\104"]={"\082\101\112\108\105\099\097\116\101\100\083\116\111\114\097\103\101","\067\111\110\102\105\103","\080\108\097\121\101\114","\079\110\098\111\097\114\100\105\110\103"},["\099\108\097\115\115\095\110\097\109\101"]="\070\111\108\100\101\114",["\107\101\121"]="\083\116\117\100\105\111\086\101\104\105\099\108\101\083\097\110\100\098\111\120\069\118\101\114\121\080\108\097\121",["\098\101\102\111\114\101"]=false,["\097\102\116\101\114"]=true}}}
local env = {
    placeId=game.PlaceId, isEdit=not game:GetService("RunService"):IsRunning(),
    resolve=function(path)
        local current=game
        for _, name in ipairs(path) do
            local found=nil
            for _, child in ipairs(current:GetChildren()) do
                if child.Name==name then assert(not found,"Ambiguous path"); found=child end
            end
            assert(found,"Missing path"); current=found
        end
        return current
    end,
    compile=function(source) return loadstring(source) end,
    read=function(target,op) if op.kind=="source" then return target.Source end return target:GetAttribute(op.key) end,
    write=function(target,op,value) if op.kind=="source" then target.Source=value else target:SetAttribute(op.key,value) end end,
}
return run(bundle, "\065\080\080\076\089", env)
