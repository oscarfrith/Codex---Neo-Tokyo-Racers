-- Inert until explicitly called with AUDIT, APPLY, STEPPED, CONTINUOUS or ROLLBACK.
return function(mode)
    assert(game.PlaceId==bundle.placeId and not game:GetService("RunService"):IsRunning(),"Wrong place/mode")
    assert(({AUDIT=true,APPLY=true,STEPPED=true,CONTINUOUS=true,ROLLBACK=true})[mode],"Invalid operation")
    local function resolve(path,optional)
        local current=game
        for i,name in ipairs(path) do
            local found
            for _,child in ipairs(current:GetChildren()) do
                if child.Name==name then assert(not found,"Ambiguous path: "..table.concat(path,".")); found=child end
            end
            if not found and optional and i==#path then return nil end
            assert(found,"Missing path: "..table.concat(path,".")); current=found
        end
        return current
    end
    for _,guard in ipairs(bundle.guards) do assert(resolve(guard.path).Source==guard.source,"Lighting definition drift") end
    local function same(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~="table" then return a==b end
        for k,v in pairs(a) do if not same(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    local function inspectTree(instance,spec)
        assert(instance.ClassName==spec.class_name,"Tree class drift")
        assert(#game.CollectionService:GetTags(instance)==0,"New tree acquired tags")
        local result={name=instance.Name,class_name=instance.ClassName,attributes=instance:GetAttributes(),properties={},children={}}
        for key in pairs(spec.properties) do result.properties[key]=instance[key] end
        local children=instance:GetChildren()
        assert(#children==#spec.children,"New tree acquired/lost contents")
        for _,childSpec in ipairs(spec.children) do
            local child
            for _,candidate in ipairs(children) do if candidate.Name==childSpec.name then assert(not child,"Duplicate tree child"); child=candidate end end
            assert(child,"Missing tree child")
            result.children[#result.children+1]=inspectTree(child,childSpec)
        end
        return result
    end
    local function makeTree(spec)
        local instance=Instance.new(spec.class_name)
        local ok,err=pcall(function()
            instance.Name=spec.name
            for key,value in pairs(spec.attributes) do instance:SetAttribute(key,value) end
            for key,value in pairs(spec.properties) do instance[key]=value end
            for _,child in ipairs(spec.children) do makeTree(child).Parent=instance end
        end)
        if not ok then instance:Destroy(); error(err) end
        return instance
    end
    local function current(op)
        local target=resolve(op.path,op.kind=="create" or op.kind=="tree")
        if not target then return nil end
        assert(target.ClassName==op.class_name,"Class drift")
        if op.kind=="attribute" then return target:GetAttribute(op.key) end
        if op.kind=="property" then return target[op.key] end
        if op.kind=="tree" then return inspectTree(target,op.after) end
        if op.kind=="create" then
            assert(#target:GetChildren()==0 and next(target:GetAttributes())==nil,"New module acquired unrelated contents")
        end
        return target.Source
    end
    local function equals(op,value,wanted)
        if op.key=="CycleMode" and wanted=="Stepped" then return value=="Stepped" or value=="Continuous" end
        return same(value,wanted)
    end
    local before,after=true,true
    for _,op in ipairs(bundle.operations) do
        for _,text in ipairs(op.kind=="source" and {op.before,op.after} or op.kind=="create" and {op.after} or {}) do
            local compiled,err=loadstring(text); assert(compiled,err)
        end
        local value=current(op)
        before=before and same(value,op.before)
        after=after and equals(op,value,op.after)
    end
    assert(before or after,"Unexpected drift/partial installation; no changes made")
    if mode=="AUDIT" then return {state=after and "installed" or "before",changed=0,beforeCapture=bundle.beforeCapture} end
    local config=game.ReplicatedStorage.Config.World.Lighting
    if mode=="STEPPED" or mode=="CONTINUOUS" then
        assert(after,"Install before selecting mode")
        local value=mode=="STEPPED" and "Stepped" or "Continuous"
        config:SetAttribute("CycleMode",value)
        return {state="installed",mode=value,restartRequired=true}
    end
    local undo=mode=="ROLLBACK"
    if (undo and before) or (not undo and after) then return {state=undo and "before" or "installed",changed=0} end
    local snapshots={}
    for i,op in ipairs(bundle.operations) do snapshots[i]={value=current(op)} end
    local function assign(op,value)
        local target=resolve(op.path,op.kind=="create" or op.kind=="tree")
        if op.kind=="tree" then
            if value==nil then
                if target then assert(same(current(op),op.after),"Refusing to remove edited tree"); target:Destroy() end
            else
                assert(not target,"Tree already exists")
                local parentPath=table.clone(op.path); table.remove(parentPath)
                local tree=makeTree(value); tree.Parent=resolve(parentPath)
            end
        elseif op.kind=="create" then
            if value==nil then
                if target then assert(current(op)==op.after,"Refusing to remove edited new module"); target:Destroy() end
            else
                if not target then
                    local parentPath=table.clone(op.path);local name=table.remove(parentPath)
                    target=Instance.new(op.class_name); target.Name=name; target.Source=value; target.Parent=resolve(parentPath)
                else target.Source=value end
            end
        elseif op.kind=="source" then target.Source=value
        elseif op.kind=="property" then target[op.key]=value
        else target:SetAttribute(op.key,value) end
    end
    local attempted={}
    local ok,problem=xpcall(function()
        for step=1,#bundle.operations do
            local i=undo and (#bundle.operations-step+1) or step
            local op=bundle.operations[i]
            assert(same(current(op),snapshots[i].value),"State changed during transaction")
            table.insert(attempted,i)
            local value
            if undo then value=op.before else value=op.after end
            assign(op,value)
        end
        for _,op in ipairs(bundle.operations) do
            local value;if undo then value=op.before else value=op.after end
            assert(same(current(op),value),"Post-write audit failed")
        end
    end,debug.traceback)
    if not ok then
        local errors={}
        for index=#attempted,1,-1 do
            local i=attempted[index];local op=bundle.operations[i]
            local restored,err=pcall(function()
                local value=current(op)
                assert(same(value,op.before) or equals(op,value,op.after) or same(value,snapshots[i].value),"Intervening edit during recovery")
                if not same(value,snapshots[i].value) then assign(op,snapshots[i].value) end
                assert(same(current(op),snapshots[i].value),"Recovery audit failed")
            end)
            if not restored then table.insert(errors,tostring(err)) end
        end
        error(tostring(problem)..(#errors>0 and (" RECOVERY INCOMPLETE: "..table.concat(errors,"; ")) or " Attempted changes restored."))
    end
    return {state=undo and "before" or "installed",changed=#bundle.operations,beforeCapture=bundle.beforeCapture}
end
