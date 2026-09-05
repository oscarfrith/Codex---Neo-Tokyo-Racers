-- Complete cleanup Phase 1. Edit Command Bar; no gameplay source changes.
-- Repo-backed recovery only. Two originally dangling shortcuts restore as nil.
local MODE = "INSTALL" -- INSTALL / AUDIT / ROLLBACK
local D=game:GetService("HttpService"):JSONDecode(--[[PAYLOAD]])
assert(game.PlaceId==D.placeId and not game:GetService("RunService"):IsRunning(),"Expected Space Racers v1 Edit")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Invalid mode")
local function key(p) return table.concat(p,"\0") end
local function resolve(p)
    local x=game
    for _,name in ipairs(p) do
        local found
        for _,c in ipairs(x:GetChildren()) do if c.Name==name then assert(not found,"Ambiguous path: "..table.concat(p,"."));found=c end end
        if not found then return nil end;x=found
    end
    return x
end
local function parent(p) local t=table.clone(p);table.remove(t);return resolve(t) end
local function eq(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not eq(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function decode(v) if type(v)=="table" and v.enum then return Enum[v.enum:gsub("^Enum%.","")][v.name] end return v end
local allowed={Folder=true,ScreenGui=true,StringValue=true,ObjectValue=true}
local records={}
for _,r in ipairs(D.nodes) do
    assert(allowed[r.class] and r.path[1]~="Workspace","Protected removal")
    records[key(r.path)]=r
end
local function checkSources()
    for _,r in ipairs(D.sources) do
        local x=assert(resolve(r.path),"Source missing")
        assert(x.ClassName==r.className,"Source class changed")
        if x:IsA("BaseScript") then assert(x.Disabled==r.disabled,"Source enabled state changed") end
        local s=x.Source;local sum=0
        for i=1,#s do sum=(sum+i*s:byte(i))%1000000007 end
        assert(#s==r.bytes and sum==r.checksum,"Source drift: "..x:GetFullName())
        local fn,err=loadstring(s,"="..x:GetFullName());assert(fn,tostring(err))
    end
    local count=0 for _,x in ipairs(game:GetDescendants()) do if x:IsA("LuaSourceContainer") then count+=1 end end
    assert(count==#D.sources,"Unexpected source set")
end
local function inspect()
    local found=0;local selected={}
    for _,r in ipairs(D.nodes) do
        local x=resolve(r.path)
        if x then
            found+=1;selected[x]=true
            assert(not x:IsDescendantOf(game.Workspace),"Workspace protected")
            assert(x.ClassName==r.class and x.Archivable==r.archivable,"Identity changed")
            assert(eq(x:GetAttributes(),r.attributes),"Metadata changed: "..x:GetFullName())
            local a=x:GetTags();table.sort(a);local b=table.clone(r.tags);table.sort(b);assert(eq(a,b),"Tags changed")
            for k,v in pairs(r.properties) do assert(x[k]==decode(v),"Property changed: "..k) end
            if r.class=="StringValue" then assert(x.Value==r.value,"Report changed") end
            if r.class=="ObjectValue" then
                if r.detachedTarget then
                    assert(x.Value==nil or (not x.Value:IsDescendantOf(game) and x.Value.Name==r.detachedTarget.name and x.Value.ClassName==r.detachedTarget.class),"Dangling shortcut changed")
                else
                    local target=r.target and assert(resolve(r.target),"Shortcut target missing") or nil
                    assert(x.Value==target,"Shortcut changed")
                end
            end
        end
    end
    assert(found==0 or found==#D.nodes,"Partial migration; inspect before proceeding")
    local clean=found==0
    for x in pairs(selected) do for _,c in ipairs(x:GetChildren()) do assert(selected[c],"Unexpected/protected descendant") end end
    for _,x in ipairs(game:GetDescendants()) do if x:IsA("ObjectValue") and x.Value and selected[x.Value] and not selected[x] then error("External reference: "..x:GetFullName()) end end
    for _,a in ipairs(D.attributes) do
        local x=assert(resolve(a.path));assert(x:IsA("Folder") and not x:IsDescendantOf(game.Workspace),"Protected metadata owner")
        local value=x:GetAttribute(a.key)
        if clean then assert(value==nil,"Stamp remains") else assert(value==a.value,"Stamp drift") end
    end
    checkSources();return clean
end
local clean=inspect()
if MODE=="AUDIT" or (MODE=="INSTALL" and clean) or (MODE=="ROLLBACK" and not clean) then
    return "Phase 1 "..MODE.." PASS; state="..(clean and "clean" or "original").."; sources="..#D.sources
end
if MODE=="INSTALL" then
    local moved={}
    local ok,err=xpcall(function()
        for _,p in ipairs(D.roots) do local x=assert(resolve(p));table.insert(moved,{x=x,parent=x.Parent});x.Parent=nil end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,nil) end
        assert(inspect(),"Install audit failed")
    end,debug.traceback)
    if not ok then
        for _,r in ipairs(moved) do r.x.Parent=r.parent end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,a.value) end
        error("Install reverted: "..err)
    end
    for _,r in ipairs(moved) do r.x:Destroy() end
else
    for _,r in ipairs(D.nodes) do
        local p=table.clone(r.path);table.remove(p)
        assert(records[key(p)] or resolve(p),"Recovery parent missing")
        if r.target then assert(records[key(r.target)] or resolve(r.target),"Recovery target missing") end
    end
    local created={}
    local ok,err=xpcall(function()
        for _,r in ipairs(D.nodes) do
            local x=Instance.new(r.class);table.insert(created,x);x.Name=r.path[#r.path];x.Archivable=r.archivable
            local keys={} for k in pairs(r.properties) do table.insert(keys,k) end table.sort(keys)
            for _,k in ipairs(keys) do x[k]=decode(r.properties[k]) end
            for k,v in pairs(r.attributes) do x:SetAttribute(k,v) end
            for _,t in ipairs(r.tags) do x:AddTag(t) end
            if r.class=="StringValue" then x.Value=r.value end
            x.Parent=assert(parent(r.path))
        end
        for _,r in ipairs(D.nodes) do if r.class=="ObjectValue" then resolve(r.path).Value=r.target and resolve(r.target) or nil end end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,a.value) end
        assert(not inspect(),"Rollback audit failed")
    end,debug.traceback)
    if not ok then
        for i=#created,1,-1 do created[i]:Destroy() end
        for _,a in ipairs(D.attributes) do resolve(a.path):SetAttribute(a.key,nil) end
        error("Rollback cancelled: "..err)
    end
end
return "Phase 1 "..MODE.." PASS; objects="..#D.nodes.."; metadata="..#D.attributes
