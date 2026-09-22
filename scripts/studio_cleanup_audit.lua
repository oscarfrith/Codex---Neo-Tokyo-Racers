-- Read-only Edit/runtime inspection. No require, writes, fixtures or auto-cleanup.
assert(game.PlaceId==121304917315753,"Wrong place")
local errors,findings,exceptions={},{},{}
local function resolve(parts)
 local x=game
 for _,part in parts do x=x and x:FindFirstChild(part) end
 return x
end
for _,parts in {{"Workspace","World"},{"ReplicatedStorage","Modules","Core"},{"ReplicatedStorage","Modules","Game"},{"ReplicatedStorage","Assets"},{"ReplicatedStorage","Remotes"},{"ReplicatedStorage","Config"},{"ServerStorage","Modules"},{"ServerStorage","Assets"}} do
 if not resolve(parts) then table.insert(errors,"Missing canonical root: "..table.concat(parts,".")) end
end
local function branded(s)return s:find("NTR_",1,true) or s:find("NeoTokyoRacers",1,true) or s:find("HOVER_RACING",1,true) end
local world=workspace:FindFirstChild("World")
local staging=resolve({"ServerStorage","NeoTokyoRacers","VehiclePerformanceV2_Staging"})
local archive=resolve({"ServerStorage","Archive"})
local scripts,compiled,emptyFolders=0,0,0
local sourceText={}
for _,x in game:GetDescendants() do
 local protected=x==staging or (staging and x:IsDescendantOf(staging)) or x==archive or (archive and x:IsDescendantOf(archive))
 local excluded=x:IsDescendantOf(workspace) and not (world and (x==world or x:IsDescendantOf(world)))
 if protected then
  if x==staging or x==archive then table.insert(exceptions,{kind="protected_assets_pending_decision",path=x:GetFullName()}) end
 elseif not excluded then
  if branded(x.Name) then
   if x==game.ServerStorage:FindFirstChild("NeoTokyoRacers") and staging then table.insert(exceptions,{kind="protected_staging_host",path=x:GetFullName()})
   else table.insert(errors,"Branded instance: "..x:GetFullName()) end
  end
  for k in x:GetAttributes() do
   if branded(k) then table.insert(findings,{kind="attribute_review",path=x:GetFullName(),key=k}) end
  end
  if x:IsA("Folder") and #x:GetChildren()==0 then emptyFolders+=1 end
  if x:IsA("ObjectValue") and not x.Value then table.insert(findings,{kind="nil_object_reference_review",path=x:GetFullName()}) end
 end
 if x:IsA("LuaSourceContainer") then
  scripts+=1
  local ok,s=pcall(function()return x.Source end)
  if ok then
   local fn,err=loadstring(s,"="..x:GetFullName())
   if fn then compiled+=1 else table.insert(errors,tostring(err)) end
   if not protected and not excluded then sourceText[x:GetFullName()]=s end
  else table.insert(findings,{kind="source_unavailable",path=x:GetFullName()}) end
 end
end
local contentOwners={}
for path,s in sourceText do
 local existing=contentOwners[s]
 if existing then table.insert(findings,{kind="identical_source_review",paths={existing,path}}) else contentOwners[s]=path end
 if s:find('local script =',1,true) then table.insert(findings,{kind="script_rebinding_review",path=path}) end
end
for _,tag in game:GetService("CollectionService"):GetAllTags() do
 if branded(tag) then
  for _,x in game:GetService("CollectionService"):GetTagged(tag) do
   if x==world or (world and x:IsDescendantOf(world)) then table.insert(errors,"Branded World tag: "..tag.." at "..x:GetFullName()) end
  end
 end
end
-- Empty containers and nil optional references are findings, never deletion evidence.
return {pass=#errors==0,errors=errors,findings=findings,exceptions=exceptions,sources=scripts,compiled=compiled,emptyFolders=emptyFolders,mode=game:GetService("RunService"):IsRunning() and "runtime" or "edit",runtimeGate="Inspect normal ServerBase/ClientBase StartupState; never require gameplay modules here."}
