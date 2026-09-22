-- One Edit-mode delivery; repository recovery only. No physical assets moved.
local MODE = "INSTALL" -- INSTALL / AUDIT / ROLLBACK
assert(game.PlaceId==121304917315753 and not game:GetService("RunService"):IsRunning(),"Expected Space Racers v1 in Edit")
local D=game.HttpService:JSONDecode(--[[PAYLOAD]])
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Invalid mode")
local function resolve(path)
 local x=game
 for _,name in path do local found=nil for _,child in x:GetChildren() do if child.Name==name then assert(not found,"Ambiguous path");found=child end end if not found then return nil end;x=found end
 return x
end
local function parent(path)local p=table.clone(path);table.remove(p);return assert(resolve(p)) end
local function checksum(s)local h=0 for i=1,#s do h=(h+string.byte(s,i)*i)%1000000007 end return tostring(h) end
local function value(v)
 if v.type=="Color3" then return Color3.new(v.r,v.g,v.b) end
 assert(v.type=="string" or v.type=="number" or v.type=="boolean","Unsupported authoring value "..v.type)
 return v.value
end
local function attributes(x,expected)
 local a=x:GetAttributes()
 for k,v in expected do assert(a[k]==value(v),"Authoring drift: "..x:GetFullName().."."..k);a[k]=nil end
 assert(next(a)==nil,"Unexpected authoring attribute")
end
local function childCheck(r)
 local x=assert(resolve(r.path_parts),"Authoring child missing")
 assert(x.ClassName==r.class_name);attributes(x,r.attributes)
 for k,v in r.properties do assert(x[k]==value(v),"Authoring property changed") end
 assert(#x:GetChildren()==#r.children,"Authoring children changed")
 for _,c in r.children do childCheck(c) end
end
local indexed=0
for _,x in game.ReplicatedStorage.Assets.Vehicles.Categories:GetDescendants() do if x:IsA("Model") and (x:GetAttribute("CockpitId") or x:GetAttribute("ModuleId")) then indexed+=1 end end
assert(indexed==#D.authoring,"Catalogue identity inventory changed; regenerate projection")
for _,r in D.authoring do local x=assert(resolve(r.path));attributes(x,r.attributes);for _,c in r.children do childCheck(c) end end
local function state(after)
 local count=0 for _,x in game:GetDescendants() do if x:IsA("LuaSourceContainer") then count+=1 end end
 if count~=#D.fingerprints+(after and #D.new or 0) then return false end
 for _,r in D.fingerprints do
  local x=resolve(r.path)
  if not x or x.ClassName~=r.class or (x:IsA("BaseScript") and x.Disabled~=r.disabled) then return false end
  if #x.Source~=(after and r.bytes or r.beforeBytes) or checksum(x.Source)~=(after and r.checksum or r.beforeChecksum) then return false end
 end
 for _,r in D.sources do if resolve(r.path).Source~=(after and r.after or r.before) then return false end end
 for _,r in D.new do local x=resolve(r.path)
  if after then if not x or not x:IsA("ModuleScript") or x.Source~=r.source or #x:GetChildren()>0 or next(x:GetAttributes()) then return false end
  elseif x then return false end
 end
 return true
end
local before,after=state(false),state(true)
assert(before or after,"Source drift/collision; refresh and inspect")
for _,r in D.fingerprints do assert(loadstring(resolve(r.path).Source)) end
for _,r in D.sources do for _,s in {r.before,r.after} do local fn,err=loadstring(s);assert(fn,err) end end
for _,r in D.new do local fn,err=loadstring(r.source);assert(fn,err) end
if MODE=="AUDIT" then return {pass=true,state=after and "installed" or "baseline",revision=D.revision} end
local target=MODE=="INSTALL"
if target==after then return {pass=true,alreadyApplied=true,mode=MODE} end
local undo,removed={},{}
local ok,err=xpcall(function()
 if target then for _,r in D.new do local x=Instance.new("ModuleScript");x.Name=r.path[#r.path];x.Source=r.source;x.Parent=parent(r.path);table.insert(undo,function() x:Destroy() end) end end
 for _,r in D.sources do local x=resolve(r.path);local source=x.Source;table.insert(undo,function() x.Source=source end);x.Source=target and r.after or r.before end
 if not target then for _,r in D.new do local x=resolve(r.path);local p=x.Parent;table.insert(undo,function() x.Parent=p end);table.insert(removed,x);x.Parent=nil end end
 assert(state(target),"Post-mutation verification failed")
end,debug.traceback)
if not ok then for i=#undo,1,-1 do undo[i]() end;assert(state(after),"Recovery failed");error(err) end
for _,x in removed do x:Destroy() end
return {pass=true,mode=MODE,changedSources=#D.sources,newModules=#D.new,revision=D.revision}
