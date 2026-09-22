-- Edit Command Bar: exact storage migration; no asset/config-value/gameplay changes.
local MODE = "INSTALL" -- INSTALL / AUDIT / ROLLBACK
local D=game:GetService("HttpService"):JSONDecode(--[[PAYLOAD]])
assert(game.PlaceId==D.placeId and not game:GetService("RunService"):IsRunning(),"Expected Space Racers v1 in Edit")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Invalid mode")
local function resolve(path)
 local x=game
 for _,name in path do
  local found=nil
  for _,child in x:GetChildren() do if child.Name==name then assert(not found,"Ambiguous path: "..table.concat(path,"."));found=child end end
  if not found then return nil end;x=found
 end
 return x
end
local function parent(path)local p=table.clone(path);table.remove(p);return assert(resolve(p),"Parent missing") end
local function target(path)
 for _,m in D.moves do
  local match=#path>=#m.before
  for i,v in m.before do if path[i]~=v then match=false end end
  if match then local p=table.clone(m.after);for i=#m.before+1,#path do table.insert(p,path[i]) end;return p end
 end
 return path
end
local function checksum(s)local h=0 for i=1,#s do h=(h+string.byte(s,i)*i)%1000000007 end return tostring(h) end
local function value(v)
 assert(v.type=="string" or v.type=="number" or v.type=="boolean","Unsupported moved metadata: "..v.type)
 return v.value
end
local function sourceState(after)
 for _,r in D.fingerprints do
  local x=resolve(after and r.path or r.beforePath)
  if not x or x.ClassName~=r.class or (x:IsA("BaseScript") and x.Disabled~=r.disabled) then return false end
  if #x.Source~=(after and r.bytes or r.beforeBytes) or checksum(x.Source)~=(after and r.checksum or r.beforeChecksum) then return false end
 end
 for _,r in D.sources do local x=resolve(r.path);if not x or x.Source~=(after and r.after or r.before) then return false end end
 return true
end
local sourceCount=0 for _,x in game:GetDescendants() do if x:IsA("LuaSourceContainer") then sourceCount+=1 end end
assert(sourceCount==#D.fingerprints,"Unexpected source inventory")
local baseline,installed=sourceState(false),sourceState(true)
assert(baseline or installed,"Source/path drift; refresh and inspect, do not force")
local function audit(after)
 assert(sourceState(after),"Source audit failed")
 for _,m in D.moves do
  assert(resolve(after and m.after or m.before),"Moved root missing")
  assert(not resolve(after and m.before or m.after),"Old/destination path collision")
 end
 for _,p in D.created do local x=resolve(p);assert(after and x and x:IsA("Folder") or not after and not x,"Container state differs") end
 for _,r in D.movedRecords do
  local x=assert(resolve(after and target(r.path_parts) or r.path_parts))
  assert(x.ClassName==r.class_name,"Moved class differs")
  local attrs=x:GetAttributes()
  for k,v in r.attributes do assert(attrs[k]==value(v),"Moved attribute differs: "..k);attrs[k]=nil end
  assert(next(attrs)==nil,"Unexpected moved attribute")
  for k,v in r.properties do assert(x[k]==value(v),"Moved property differs: "..k) end
 end
end
audit(installed)
for _,r in D.fingerprints do local x=assert(resolve(installed and r.path or r.beforePath));assert(loadstring(x.Source,"="..x:GetFullName())) end
for _,r in D.sources do for _,s in {r.before,r.after} do local fn,err=loadstring(s);assert(fn,err) end end
if MODE=="AUDIT" then return {pass=true,state=installed and "installed" or "baseline",sources=sourceCount} end
local after=MODE=="INSTALL"
if installed==after then return {pass=true,mode=MODE,alreadyApplied=true} end
local roots={} for i,m in D.moves do roots[i]=assert(resolve(installed and m.after or m.before)) end
local changed={} for i,r in D.sources do changed[i]=assert(resolve(r.path)) end
-- Hold references and original source only in this call; no game backup objects.
local undo={};local function remember(fn)table.insert(undo,fn) end
local originals={}
for _,x in game:GetDescendants() do originals[x]={parent=x.Parent,name=x.Name} end
local moving={} for _,x in roots do moving[x]=true end
local added={};local removed={}
local ok,err=xpcall(function()
 if after then
  for _,p in D.created do
   local x=Instance.new("Folder");x.Name=p[#p];x.Parent=parent(p);added[x]=true
   remember(function() x:Destroy() end)
  end
 end
 for i,m in D.moves do local x=roots[i];local oldParent=x.Parent;remember(function() x.Parent=oldParent end);x.Parent=parent(after and m.after or m.before) end
 for i,r in D.sources do local x=changed[i];local old=x.Source;remember(function() x.Source=old end);x.Source=after and r.after or r.before end
 if not after then
  for i=#D.created,1,-1 do local x=assert(resolve(D.created[i]));assert(#x:GetChildren()==0 and next(x:GetAttributes())==nil,"Container acquired content; rollback stopped")
   local oldParent=x.Parent;remember(function() x.Parent=oldParent end);removed[x]=true;x.Parent=nil
  end
 end
 audit(after)
 for x,r in originals do
  assert(x.Name==r.name,"Unexpected rename")
  if not moving[x] and not removed[x] then assert(x.Parent==r.parent,"Unexpected hierarchy change") end
 end
 for _,x in game:GetDescendants() do assert(originals[x] or added[x],"Unexpected instance creation") end
end,debug.traceback)
if not ok then for i=#undo,1,-1 do undo[i]() end;audit(installed);error(err) end
for x in removed do x:Destroy() end
return {pass=true,mode=MODE,movedRoots=6,movedInstances=14,changedSources=#D.sources,replicatedDescendants=#game.ReplicatedStorage:GetDescendants()}
