-- Static preview projection; originals move intact, no geometry changes.
local MODE = "INSTALL" -- INSTALL / AUDIT / ROLLBACK
local D=game.HttpService:JSONDecode(--[[PAYLOAD]])
assert(game.PlaceId==121304917315753 and not game:GetService("RunService"):IsRunning(),"Expected Space Racers v1 in Edit")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK")
local function resolve(path)
 local x=game
 for _,name in path do local found=nil for _,c in x:GetChildren() do if c.Name==name then assert(not found,"Ambiguous path");found=c end end if not found then return nil end x=found end
 return x
end
local function checksum(s)local h=0 for i=1,#s do h=(h+string.byte(s,i)*i)%1000000007 end return tostring(h) end
local function sourceState(after)
 local count=0 for _,x in game:GetDescendants() do if x:IsA("LuaSourceContainer") then count+=1 end end
 if count~=#D.fingerprints then return false end
 for _,r in D.fingerprints do local x=resolve(r.path)
  if not x or x.ClassName~=r.className or (x:IsA("BaseScript") and x.Disabled~=r.disabled) then return false end
  if #x.Source~=(after and r.bytes or r.beforeBytes) or checksum(x.Source)~=(after and r.checksum or r.beforeChecksum) then return false end
 end
 for _,r in D.sources do if resolve(r.path).Source~=(after and r.after or r.before) then return false end end
 return true
end
local function expectedPath(path,prefix)
 local result=table.clone(path)
 if path[1]==D.old[1] and path[2]==D.old[2] and path[3]==D.old[3] then for i=1,3 do result[i]=prefix[i] end end
 return table.concat(result,".")
end
local function equal(v,e,prefix)
 if typeof(v)~=e.type then return false end
 if e.type=="nil" then return true end
 if e.value~=nil then return v==e.value end
 if e.type=="Color3" then return v.R==e.r and v.G==e.g and v.B==e.b end
 if e.type=="Vector3" then return v.X==e.x and v.Y==e.y and v.Z==e.z end
 if e.type=="CFrame" then local parts={v:GetComponents()} for i,n in e.components do if parts[i]~=n then return false end end return true end
 if e.type=="Instance" then return v:GetFullName()==expectedPath(e.path_parts,prefix) end
 return tostring(v)==e.text
end
local function pruned(r)return r.name=="VehiclePerformanceV2UpgradePaths" or r.name=="UpgradePaths" end
-- Match duplicate sibling names by full captured properties, not FindFirstChild order.
local function treeMatches(x,r,prefix,isPreview,isRoot)
 if x.Name~=(isRoot and isPreview and "VehiclePreviews" or r.name) or x.ClassName~=r.class_name then return false end
 local attrs=x:GetAttributes()
 for k,v in r.attributes do if not equal(attrs[k],v,prefix) then return false end attrs[k]=nil end
 if next(attrs) then return false end
 for k,v in r.properties do local ok,current=pcall(function()return x[k] end);if not ok or not equal(current,v,prefix) then return false end end
 local children=x:GetChildren()
 for _,c in r.children or {} do if not (isPreview and pruned(c)) then
  local match=nil for i,actual in children do if treeMatches(actual,c,prefix,isPreview,false) then match=i break end end
  if not match then return false end;table.remove(children,match)
 end end
 return #children==0
end
local function audit(after)
 assert(sourceState(after),"Source drift")
 local original=assert(resolve(after and D.server or D.old),"Canonical root missing")
 assert(not resolve(after and D.old or D.server),"Root collision")
 assert(treeMatches(original,D.tree,after and D.server or D.old,false,true),"Canonical captured content drift")
 if after then assert(treeMatches(assert(resolve(D.preview)),D.tree,D.preview,true,true),"Preview projection drift") else assert(not resolve(D.preview),"Preview collision") end
end
local baseline,installed=sourceState(false),sourceState(true)
assert(baseline or installed,"Source drift; refresh and inspect")
audit(installed)
for _,r in D.fingerprints do assert(loadstring(resolve(r.path).Source)) end
for _,r in D.sources do assert(loadstring(r.before));assert(loadstring(r.after)) end
if MODE=="AUDIT" then return {pass=true,state=installed and "installed" or "baseline"} end
local target=MODE=="INSTALL"
if installed==target then return {pass=true,alreadyApplied=true,mode=MODE} end
local original=assert(resolve(installed and D.server or D.old))
local undo={};local detached
local ok,err=xpcall(function()
 if target then
  local preview=assert(original:Clone(),"Template must be archivable")
  table.insert(undo,function()preview:Destroy()end)
  for _,path in D.pruneRoots do local x=preview for _,name in path do x=assert(x:FindFirstChild(name)) end assert(x:IsA("Folder"));for _,c in x:GetDescendants() do assert(c:IsA("Folder"),"Refuse to omit physical content") end x:Destroy() end
  preview.Name="VehiclePreviews";preview.Parent=game.ReplicatedStorage.Assets
 else
  detached=assert(resolve(D.preview));local p=detached.Parent;table.insert(undo,function()detached.Parent=p end);detached.Parent=nil
 end
 local previous=original.Parent;table.insert(undo,function()original.Parent=previous end)
 original.Parent=target and game.ServerStorage.Assets or game.ReplicatedStorage.Assets
 for _,r in D.sources do local x=resolve(r.path);local previousSource=x.Source;table.insert(undo,function()x.Source=previousSource end);x.Source=target and r.after or r.before end
 audit(target)
end,debug.traceback)
if not ok then for i=#undo,1,-1 do undo[i]() end;audit(installed);error(err) end
if detached then detached:Destroy() end
return {pass=true,mode=MODE,replicatedDescendants=#game.ReplicatedStorage:GetDescendants(),sources=#D.fingerprints,omittedPreviewFolders=333}
