-- Complete cleanup Phase 2: canonical code ownership. Edit Command Bar only.
-- Exact full-source preflight; no live text substitutions and no in-game backups.
local MODE = "INSTALL" -- INSTALL / AUDIT / ROLLBACK
local D = game:GetService("HttpService"):JSONDecode(--[[PAYLOAD]])
assert(game.PlaceId==D.placeId and not game:GetService("RunService"):IsRunning(),"Expected Space Racers v1 in Edit")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Unknown mode")
local function key(p) return table.concat(p,"\0") end
local function resolve(p)
    local current=game
    for _,name in ipairs(p) do
        local found
        for _,child in ipairs(current:GetChildren()) do
            if child.Name==name then assert(not found,"Ambiguous path: "..table.concat(p,"."));found=child end
        end
        if not found then return nil end
        current=found
    end
    return current
end
local function parentPath(p) local result=table.clone(p);table.remove(result);return result end
local function value(v)
    if v.type=="Instance" then return assert(resolve(v.path_parts),"Recovery reference target missing") end
    if v.type=="string" or v.type=="number" or v.type=="boolean" then return v.value end
    error("Unsupported recovery value: "..tostring(v.type))
end
local function attributesMatch(x,attrs)
    local current=x:GetAttributes()
    for k,v in pairs(attrs) do if current[k]~=value(v) then return false end;current[k]=nil end
    return next(current)==nil
end
local function sourceState(records)
    for _,r in ipairs(records) do
        local x=resolve(r.path)
        if not x or not x:IsA("LuaSourceContainer") or x.ClassName~=(r.class or r.className) or x.Source~=r.source then return false end
        if x:IsA("BaseScript") and r.disabled~=nil and x.Disabled~=r.disabled then return false end
    end
    return true
end
local installed=sourceState(D.sources)
local baseline=sourceState(D.beforeSources)
assert(installed or baseline,"Live source drift: refresh/inspect before changing this installer")
local function compile()
    for _,r in ipairs(D.sources) do
        local fn,err=loadstring(r.source,"="..table.concat(r.path,"."))
        assert(fn,err)
    end
end
compile()
if MODE=="AUDIT" then
    print("[Cleanup Phase 2] AUDIT PASS",installed and "installed" or "baseline",#D.sources,"sources compile")
    return
end
if MODE=="INSTALL" and installed then print("[Cleanup Phase 2] already installed; sources verified");return end
if MODE=="ROLLBACK" and baseline then
    for _,r in ipairs(D.retired) do
        if r.node.class_name=="ObjectValue" then
            local x=assert(resolve(r.node.path_parts));local target=value(r.node.properties.Value)
            assert(x.Value==nil or x.Value==target,"Recovery reference was independently changed")
            x.Value=target
        end
    end
    print("[Cleanup Phase 2] baseline sources and recovery references verified");return
end
local beforeByPath={}
for _,r in ipairs(D.beforeSources) do beforeByPath[key(r.path)]=r end
local retiredSet={}
for _,r in ipairs(D.retired) do
    if baseline then
        local x=assert(resolve(r.node.path_parts),"Retired object missing")
        assert(x.ClassName==r.node.class_name and attributesMatch(x,r.node.attributes),"Retired metadata drift: "..x:GetFullName())
        for k,v in pairs(r.node.properties) do if k=="Value" then assert(x[k]==value(v),"Retired value drift: "..x:GetFullName()) end end
        retiredSet[x]=true
    end
end
if baseline then
    local moving={}
    for _,r in ipairs(D.sources) do if key(r.path)~=key(r.from) then moving[assert(resolve(r.from))]=true end end
    for x in pairs(retiredSet) do for _,child in ipairs(x:GetChildren()) do assert(retiredSet[child] or moving[child],"Unreviewed child: "..child:GetFullName()) end end
    for _,x in ipairs(game:GetDescendants()) do
        if x:IsA("ObjectValue") and not retiredSet[x] and x.Value and retiredSet[x.Value] then
            error("External reference needs an explicit owner: "..x:GetFullName())
        end
    end
end
local count=0 for _,x in ipairs(game:GetDescendants()) do if x:IsA("LuaSourceContainer") then count+=1 end end
assert(count==(baseline and D.beforeCount or D.sourceCount),"Unexpected source set")
for _,r in ipairs(D.created) do
    local x=resolve(r.path)
    assert(not baseline or not x,"Target collision: "..table.concat(r.path,"."))
    assert(not x or x.ClassName==r.class,"Target class changed")
    assert(r.path[1]~="Workspace","Cannot create Workspace content")
end

-- Identity/placement/appearance guards cover every physical object, including excluded Workspace WIP.
local protected={}
for _,x in ipairs(game:GetDescendants()) do
    if x:IsA("BasePart") then
        protected[x]={x.Parent,x.Name,x.CFrame,x.Size,x.Color,x.Material,x.Transparency,x.Anchored,x.CanCollide,x.CanQuery,x.CanTouch}
    elseif x:IsA("Model") then protected[x]={x.Parent,x.Name,x.PrimaryPart}
    end
end
local workspaceObjects={}
for _,x in ipairs(workspace:GetDescendants()) do workspaceObjects[x]={x.Parent,x.Name,x:GetAttributes()} end
local function physicalAudit()
    for x,p in pairs(protected) do
        assert(x.Parent==p[1] and x.Name==p[2],"Physical identity/parent changed")
        if x:IsA("BasePart") then assert(x.CFrame==p[3] and x.Size==p[4] and x.Color==p[5] and x.Material==p[6] and x.Transparency==p[7] and x.Anchored==p[8] and x.CanCollide==p[9] and x.CanQuery==p[10] and x.CanTouch==p[11],"Physical properties changed")
        else assert(x.PrimaryPart==p[3],"Model primary part changed") end
    end
    local found=0
    for _,x in ipairs(workspace:GetDescendants()) do
        local p=assert(workspaceObjects[x],"Workspace object added");found+=1
        assert(x.Parent==p[1] and x.Name==p[2],"Workspace hierarchy changed")
        local a=x:GetAttributes()
        for k,v in pairs(p[3]) do assert(a[k]==v,"Workspace attribute changed");a[k]=nil end
        assert(next(a)==nil,"Workspace attribute added")
    end
    local expected=0 for _ in pairs(workspaceObjects) do expected+=1 end
    assert(found==expected,"Workspace object removed")
end
local undo,detached={},{}
local createdAllowed={} for _,r in ipairs(D.created) do createdAllowed[key(r.path)]=r.class end
for _,r in ipairs(D.retired) do createdAllowed[key(r.node.path_parts)]=r.node.class_name end
local function create(path,class)
    local x=resolve(path)
    if x then assert(x.ClassName==class,"Class collision");return x end
    assert(path[1]~="Workspace" and createdAllowed[key(path)]==class,"Unapproved creation: "..table.concat(path,"."))
    local pp=parentPath(path);local parent=resolve(pp)
    if not parent then parent=create(pp,"Folder") end
    x=Instance.new(class);x.Name=path[#path];x.Parent=parent
    table.insert(undo,function() x:Destroy() end)
    return x
end
local function move(x,path)
    assert(not x:IsDescendantOf(workspace) and path[1]~="Workspace","Workspace move prohibited")
    local oldParent,oldName=x.Parent,x.Name
    local pp=parentPath(path);local parent=resolve(pp) or create(pp,"Folder")
    local collision=resolve(path);assert(not collision or collision==x,"Move collision")
    table.insert(undo,function() x.Name=oldName;x.Parent=oldParent end)
    x.Name=path[#path];x.Parent=parent
end
local function detach(x)
    assert(not x:IsDescendantOf(workspace) and not x:IsA("Model") and not x:IsA("BasePart"),"Protected deletion")
    assert(#x:GetChildren()==0,"Deletion would remove unreviewed descendants: "..x:GetFullName())
    local oldParent=x.Parent
    table.insert(undo,function() x.Parent=oldParent end)
    x.Parent=nil;table.insert(detached,x)
end
local function writeSource(x,source)
    if x.Source==source then return end
    local old=x.Source;table.insert(undo,function() x.Source=old end);x.Source=source
end
local function setAttribute(x,k,v)
    local old=x:GetAttribute(k);table.insert(undo,function() x:SetAttribute(k,old) end);x:SetAttribute(k,v)
end
local function restoreMetadata(x,n)
    for k,v in pairs(n.attributes) do setAttribute(x,k,value(v)) end
    for k,v in pairs(n.properties) do
        if k=="Value" and v.type~="Instance" and v.type~="instance" then
            local old=x[k];table.insert(undo,function() x[k]=old end);x[k]=value(v)
        end
    end
end
local function installedAudit()
    assert(sourceState(D.sources),"Installed source mismatch")
    for _,r in ipairs(D.sources) do assert(resolve(r.path).ClassName==r.class,"Installed source class mismatch") end
    for _,r in ipairs(D.retired) do assert(not resolve(r.node.path_parts),"Retired path survived") end
    for _,r in ipairs(D.containers) do assert(resolve(r.path).ClassName==r.class,"Runtime endpoint missing") end
    local root=game.ReplicatedStorage.NeoTokyoRacers
    for k,v in pairs(D.configAttributes) do assert(root:GetAttribute(k)==nil and game.ReplicatedStorage.Config.Garage:GetAttribute(k)==value(v),"Config value mismatch") end
end
local ok,message=xpcall(function()
    if MODE=="INSTALL" then
        -- Move existing endpoints first, preserving identity and their effective initial state.
        for _,r in ipairs(D.retired) do if r.move then move(assert(resolve(r.node.path_parts)),r.move) end end
        for _,r in ipairs(D.containers) do create(r.path,r.class) end
        for _,r in ipairs(D.sources) do
            local x=resolve(r.from)
            if key(r.from)~=key(r.path) then move(assert(x),r.path) end
            x=x or create(r.path,r.class);writeSource(x,r.source)
        end
        local config=create({"ReplicatedStorage","Config","Garage"},"Folder")
        for k,v in pairs(D.configAttributes) do setAttribute(config,k,value(v));setAttribute(game.ReplicatedStorage.NeoTokyoRacers,k,nil) end
        local records=table.clone(D.retired);table.sort(records,function(a,b) return #a.node.path_parts>#b.node.path_parts end)
        for _,r in ipairs(records) do if not r.move then detach(assert(resolve(r.node.path_parts))) end end
        installedAudit()
    else
        -- Restore repository records; recovery objects are the original architecture, never a backup tree.
        local records=table.clone(D.retired);table.sort(records,function(a,b) return #a.node.path_parts<#b.node.path_parts end)
        for _,r in ipairs(records) do
            local n=r.node;local x
            if r.move then x=assert(resolve(r.move));move(x,n.path_parts) else x=create(n.path_parts,n.class_name) end
            restoreMetadata(x,n)
        end
        for _,r in ipairs(D.sources) do if key(r.from)~=key(r.path) then move(assert(resolve(r.path)),r.from) end end
        for _,r in ipairs(D.beforeSources) do writeSource(assert(resolve(r.path)),r.source) end
        for _,r in ipairs(D.retired) do
            if r.node.class_name=="ObjectValue" then
                local x=assert(resolve(r.node.path_parts));local old=x.Value
                table.insert(undo,function() x.Value=old end);x.Value=value(r.node.properties.Value)
            end
        end
        for k,v in pairs(D.configAttributes) do setAttribute(game.ReplicatedStorage.NeoTokyoRacers,k,value(v)) end
        local recordsCreated=table.clone(D.created);table.sort(recordsCreated,function(a,b) return #a.path>#b.path end)
        for _,r in ipairs(recordsCreated) do local x=resolve(r.path);if x then detach(x) end end
        assert(sourceState(D.beforeSources),"Rollback source mismatch")
    end
    physicalAudit()
end,debug.traceback)
if not ok then
    for i=#undo,1,-1 do local restored,err=pcall(undo[i]);if not restored then warn("[Cleanup Phase 2] recovery error: "..tostring(err)) end end
    error("Phase 2 transaction failed and was reversed: "..tostring(message))
end
for _,x in ipairs(detached) do x:Destroy() end
print("[Cleanup Phase 2] "..MODE.." PASS; physical/Workspace invariants PASS; sources="..tostring(MODE=="INSTALL" and D.sourceCount or D.beforeCount))
