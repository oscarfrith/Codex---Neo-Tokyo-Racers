-- Space Racers: reviewed legacy retirement. Run in Edit Command Bar only.
-- Modes: INSTALL (default), AUDIT (read-only), ROLLBACK (restore frozen records).
-- No text replacements, physical-object changes, publishing or in-place backups.
local MODE = "INSTALL"
local H = game:GetService("HttpService")
local D = H:JSONDecode(--[[PAYLOAD]])
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before cleanup")
assert(game.PlaceId == D.placeId, "Wrong place")
assert(MODE == "INSTALL" or MODE == "AUDIT" or MODE == "ROLLBACK", "Invalid mode")
local function key(path) return table.concat(path, "\0") end
local function resolve(path)
    local current = game
    for _, name in ipairs(path) do
        local found
        for _, child in ipairs(current:GetChildren()) do
            if child.Name == name then assert(not found, "Ambiguous path: " .. table.concat(path,".")); found=child end
        end
        if not found then return nil end
        current=found
    end
    return current
end
local function parent(path)
    local p=table.clone(path);table.remove(p);return resolve(p)
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local allowed={Folder=true,ModuleScript=true,Script=true,LocalScript=true,StringValue=true,ObjectValue=true}
local records={}
for _,r in ipairs(D.nodes) do
    assert(allowed[r.class],"Unapproved class")
    records[key(r.path)]=r
end
local function compile(source,label)
    local fn,err=loadstring(source,"="..label)
    assert(fn,"Compile failed: "..label..": "..tostring(err))
end
local function sources(clean)
    local wanted=0
    for _,r in ipairs(D.sources) do
        if not (clean and records[key(r.path)]) then
            wanted+=1
            local x=assert(resolve(r.path),"Missing source: "..table.concat(r.path,"."))
            assert(x.ClassName==r.className,"Source class changed")
            if x:IsA("BaseScript") then assert(x.Disabled==r.disabled,"Enabled state changed") end
            local s=x.Source; local sum=0
            for i=1,#s do sum=(sum+i*string.byte(s,i))%1000000007 end
            assert(#s==r.bytes and sum==r.checksum,"Source changed: "..x:GetFullName())
            compile(s,x:GetFullName())
        end
    end
    local count=0 for _,x in ipairs(game:GetDescendants()) do if x:IsA("LuaSourceContainer") then count+=1 end end
    assert(count==wanted,"Unexpected source set")
    return count
end
local function inspect()
    local present=0;local selected={}
    for _,r in ipairs(D.nodes) do
        local x=resolve(r.path)
        if x then
            present+=1;selected[x]=true
            assert(x.ClassName==r.class and x.Archivable==r.archivable,"Object identity changed")
            assert(equal(x:GetAttributes(),r.attributes),"Attributes changed: "..x:GetFullName())
            local tags=x:GetTags();table.sort(tags);local old=table.clone(r.tags);table.sort(old)
            assert(equal(tags,old),"Tags changed")
            if r.source then assert(x.Source==r.source,"Retired source changed") end
            if r.disabled~=nil then assert(x.Disabled==r.disabled and x.RunContext.Name==r.runContext,"Execution state changed") end
            if r.class=="StringValue" then assert(x.Value==r.value,"Report content changed") end
            if r.class=="ObjectValue" then
                local target=r.target and assert(resolve(r.target),"Reference target missing") or nil
                assert(x.Value==target,"Object reference changed")
            end
        end
    end
    assert(present==0 or present==#D.nodes,"Partial cleanup state; inspect before proceeding")
    local clean=present==0
    for x in pairs(selected) do for _,child in ipairs(x:GetChildren()) do assert(selected[child],"Unexpected/protected descendant: "..child:GetFullName()) end end
    for _,x in ipairs(game:GetDescendants()) do
        if x:IsA("ObjectValue") and x.Value and selected[x.Value] and not selected[x] then error("External reference: "..x:GetFullName()) end
    end
    for _,a in ipairs(D.attributes) do
        local x=assert(resolve(a.path),"Attribute owner missing")
        assert(x:IsA("LuaSourceContainer"),"Attribute owner is not code")
        local expected=not clean and a.value or nil
        assert(x:GetAttribute(a.key)==expected,"Patch stamp changed: "..a.key)
    end
    return clean,sources(clean)
end
local clean,count=inspect()
if MODE=="AUDIT" or (MODE=="INSTALL" and clean) or (MODE=="ROLLBACK" and not clean) then
    print("Legacy cleanup "..MODE.." PASS; state="..(clean and "clean" or "original").."; sources="..count)
    return
end
if MODE=="INSTALL" then
    local detached={}
    local ok,err=xpcall(function()
        for _,p in ipairs(D.roots) do
            local x=assert(resolve(p));table.insert(detached,{object=x,parent=x.Parent});x.Parent=nil
        end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,nil) end
        local state=inspect();assert(state,"Install audit failed")
    end,debug.traceback)
    if not ok then
        for _,r in ipairs(detached) do r.object.Parent=r.parent end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,a.value) end
        error("Cleanup reverted: "..err)
    end
    for _,r in ipairs(detached) do r.object:Destroy() end
else
    -- All preflights occur before creation. Exact recovery records are repository-backed.
    for _,r in ipairs(D.nodes) do
        local p=table.clone(r.path);table.remove(p)
        assert(records[key(p)] or resolve(p),"Restore parent missing")
        if r.target then assert(records[key(r.target)] or resolve(r.target),"Restore reference missing") end
        if r.source then compile(r.source,table.concat(r.path,".")) end
    end
    local created={}
    local ok,err=xpcall(function()
        for _,r in ipairs(D.nodes) do
            local x=Instance.new(r.class);table.insert(created,x)
            x.Name=r.path[#r.path];x.Archivable=r.archivable
            if x:IsA("BaseScript") then x.Disabled=true;x.RunContext=Enum.RunContext[r.runContext] end
            if r.source then x.Source=r.source end
            if r.class=="StringValue" then x.Value=r.value end
            for k,v in pairs(r.attributes) do x:SetAttribute(k,v) end
            for _,tag in ipairs(r.tags) do x:AddTag(tag) end
            x.Parent=assert(parent(r.path))
        end
        for _,r in ipairs(D.nodes) do
            local x=resolve(r.path)
            if r.class=="ObjectValue" then x.Value=r.target and resolve(r.target) or nil end
            if r.disabled~=nil then x.Disabled=r.disabled end
        end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,a.value) end
        local state=inspect();assert(not state,"Rollback audit failed")
    end,debug.traceback)
    if not ok then
        for i=#created,1,-1 do created[i]:Destroy() end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,nil) end
        error("Rollback cancelled: "..err)
    end
end
print("Legacy cleanup "..MODE.." PASS; objects="..#D.nodes.."; patch attributes="..#D.attributes)
