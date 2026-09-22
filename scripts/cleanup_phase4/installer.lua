-- Phase 4: exact-source cleanup only. No hierarchy/property/asset mutations.
local MODE = "INSTALL" -- INSTALL / AUDIT / ROLLBACK
assert(game.PlaceId==121304917315753 and not game:GetService("RunService"):IsRunning(),"Expected Space Racers v1 in Edit")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Invalid mode")
local data=game:GetService("HttpService"):JSONDecode(--[[PAYLOAD]])
local objects={}
local function resolve(path)
 local x=game
 for _,name in path do
  local match=nil
  for _,child in x:GetChildren() do if child.Name==name then assert(not match,"Ambiguous source path");match=child end end
  x=assert(match,"Missing source: "..table.concat(path,"."))
 end
 return x
end
local count=0 for _,x in game:GetDescendants() do if x:IsA("LuaSourceContainer") then count+=1 end end
assert(count==#data.sources,"Source inventory drift")
local before,after=true,true
for i,r in data.sources do
 local x=resolve(r.path);objects[i]=x
 assert(x.ClassName==r.class and (not x:IsA("BaseScript") or x.Disabled==r.disabled),"Source class/enabled drift")
 before=before and x.Source==r.before;after=after and x.Source==r.after
 for _,s in {r.before,r.after} do local fn,err=loadstring(s,"="..table.concat(r.path,"."));assert(fn,err) end
end
assert(before or after,"Source drift: inspect the current mirror; never force the installer")
if MODE=="AUDIT" then return {pass=true,state=after and "installed" or "baseline",sources=count} end
local target=MODE=="INSTALL" and "after" or "before"
local prior={};local changed=0
local ok,err=xpcall(function()
 for i,r in data.sources do
  local x=objects[i];prior[i]=x.Source
  if x.Source~=r[target] then x.Source=r[target];changed+=1 end
 end
 for i,r in data.sources do assert(objects[i].Source==r[target],"Post-write source mismatch") end
end,debug.traceback)
if not ok then
 for i,s in prior do objects[i].Source=s end
 error(err)
end
return {pass=true,mode=MODE,sources=count,changed=changed}
