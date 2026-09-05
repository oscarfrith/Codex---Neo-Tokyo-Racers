-- Complete cleanup Phase 3. Edit Command Bar only; repository-backed transaction.
local MODE = "INSTALL" -- INSTALL / AUDIT / ROLLBACK
local Http=game:GetService("HttpService")
local D=Http:JSONDecode(--[[PAYLOAD]])
assert(game.PlaceId==D.placeId and not game:GetService("RunService"):IsRunning(),"Expected Space Racers v1 in Edit")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Invalid mode")
local function key(p)return table.concat(p,"\0") end
local function parentPath(p)local t=table.clone(p);table.remove(t);return t end
local function all(p)
 local found={game}
 for _,name in p do local nextFound={} for _,parent in found do for _,x in parent:GetChildren() do if x.Name==name then table.insert(nextFound,x) end end end found=nextFound end
 return found
end
local function resolve(p)local list=all(p);assert(#list<=1,"Ambiguous path: "..table.concat(p,"."));return list[1] end
local function value(v)
 if v.type=="string" or v.type=="number" or v.type=="boolean" then return v.value end
 if v.type=="Instance" then return resolve(v.path_parts) end
 if v.type=="nil" then return nil end
 if v.type=="Color3" then return Color3.new(v.r,v.g,v.b) end
 if v.type=="Vector3" then return Vector3.new(v.x,v.y,v.z) end
 if v.type=="CFrame" then return CFrame.new(table.unpack(v.components)) end
 error("Unsupported metadata type: "..tostring(v.type))
end
local function sameAttrs(x,expected)
 local a=x:GetAttributes()
 for k,v in expected do if a[k]~=value(v) then return false end;a[k]=nil end
 return next(a)==nil
end
local function sourceState(installed)
 local count=0 for _,x in game:GetDescendants() do if x:IsA("LuaSourceContainer") then count+=1 end end
 if count~=#D.sources then return false end
 for _,r in D.sources do local x=resolve(installed and r.path or r.beforePath)
  if not x or x.ClassName~=r.class or x.Source~=(installed and r.source or r.before) then return false end
  if x:IsA("BaseScript") and x.Disabled~=r.disabled then return false end
 end
 return true
end
local installed=sourceState(true);local baseline=sourceState(false)
assert(installed or baseline,"Source drift: refresh and inspect; do not force migration")
for _,r in D.sources do local fn,err=loadstring(r.source,"="..table.concat(r.path,"."));assert(fn,err) end
local CS=game:GetService("CollectionService")
local world=assert(workspace:FindFirstChild(installed and "World" or "NeoTokyoRacersWorld"))
local function inScope(x)return not x:IsDescendantOf(workspace) or x==world or x:IsDescendantOf(world) end
local function objectPath(x)local p={} repeat table.insert(p,1,x.Name);x=x.Parent until x==game;return p end
local permittedWip={}
for _,r in D.wipTags do local k=key(r.path).."|"..r.tag;permittedWip[k]=(permittedWip[k] or 0)+1 end
local function tagAudit(after)
 for old,new in D.tags do
  local counts={}
  for _,x in CS:GetTagged(after and new or old) do
   if not inScope(x) then local k=key(objectPath(x)).."|"..old;assert(permittedWip[k],"Unapproved WIP tag member");counts[k]=(counts[k] or 0)+1 end
  end
  for k,count in permittedWip do if string.sub(k,-#old-1)=="|"..old then assert(counts[k]==count,"WIP tag inventory changed") end end
  for _,x in CS:GetTagged(after and old or new) do if inScope(x) or permittedWip[key(objectPath(x)).."|"..old] then error("Tag collision or incomplete migration: "..x:GetFullName()) end end
 end
end
local function afterPath(p)
 local best,target=0,nil
 for _,m in D.moves do if #m.before>#p then continue end local match=true for i,v in m.before do if p[i]~=v then match=false;break end end
  if match and #m.before>best then best=#m.before;target=m.after end
 end
 if not target then return p end local result=table.clone(target);for i=best+1,#p do table.insert(result,p[i]) end;return result
end
local function attrsAfter(r)local a=table.clone(r.attributes);for _,c in r.changes do a[c.old]=nil;if c.new then a[c.new]=c.afterValue or c.value end end;return a end
local function metadataObjects(r,after)
 local expected=after and attrsAfter(r) or r.attributes;local result={}
 for _,x in all(after and afterPath(r.path) or r.path) do if x.ClassName==r.class and sameAttrs(x,expected) then table.insert(result,x) end end
 assert(#result==r.count,"Metadata drift: "..table.concat(r.path,"."));return result
end
local function audit(after)
 assert(sourceState(after),"Source verification failed")
 for _,m in D.moves do assert(resolve(after and m.after or m.before).ClassName==m.class,"Move class mismatch") end
 for _,r in D.metadata do metadataObjects(r,after) end
 if after then for _,r in D.retired do assert(not resolve(r.path_parts),"Retired path remains") end end
 tagAudit(after)
end
audit(installed)
if MODE=="AUDIT" then print("[Cleanup Phase 3] AUDIT PASS",installed and "installed" or "baseline",#D.sources);return end
if MODE=="INSTALL" and installed or MODE=="ROLLBACK" and baseline then print("[Cleanup Phase 3] already in requested state");return end
local sourceObjects={} for i,r in D.sources do sourceObjects[i]=assert(resolve(installed and r.path or r.beforePath)) end
local moveObjects={} for i,m in D.moves do moveObjects[i]=assert(resolve(installed and m.after or m.before)) end
local metaObjects={} for i,r in D.metadata do metaObjects[i]=metadataObjects(r,installed) end
local retiring={};local retiredObjects={}
if baseline then
 for _,r in D.retired do local x=assert(resolve(r.path_parts));assert(x.ClassName==r.class_name and sameAttrs(x,r.attributes),"Retired metadata drift");retiring[x]=r;retiredObjects[key(r.path_parts)]=x end
 for x in retiring do for _,child in x:GetChildren() do local moves=false for _,m in moveObjects do if child==m then moves=true;break end end assert(retiring[child] or moves,"Unreviewed retirement child: "..child:GetFullName()) end end
 for _,x in game:GetDescendants() do if x:IsA("ObjectValue") and x.Value and retiring[x.Value] and not retiring[x] then error("External reference to retired object") end end
 for _,r in D.created do assert(not resolve(r.path),"New folder collision") end
end
local originals={};local physical={};local wip={}
for _,x in game:GetDescendants() do
 originals[x]={parent=x.Parent,name=x.Name}
 if x:IsA("BasePart") then physical[x]={x.CFrame,x.Size,x.Color,x.Material,x.Transparency,x.Anchored,x.CanCollide,x.CanQuery,x.CanTouch,x.CollisionGroup}
 elseif x:IsA("Model") then physical[x]={x.PrimaryPart} end
 if x:IsDescendantOf(workspace) and not inScope(x) then wip[x]={parent=x.Parent,name=x.Name,attrs=x:GetAttributes(),tags=x:GetTags()} end
end
local undo,detached={},{}
local allowed={} for _,r in D.created do allowed[key(r.path)]=r.class end for _,r in D.retired do allowed[key(r.path_parts)]=r.class_name end
local function create(p,class)
 local x=resolve(p);if x then assert(x.ClassName==class);return x end
 assert(allowed[key(p)]==class and p[1]~="Workspace","Unapproved creation")
 local parent=resolve(parentPath(p)) or create(parentPath(p),"Folder")
 x=Instance.new(class);x.Name=p[#p];x.Parent=parent;table.insert(undo,function()x:Destroy()end);return x
end
local function move(x,p)
 local parent=resolve(parentPath(p)) or create(parentPath(p),"Folder");local existing=resolve(p);assert(not existing or existing==x,"Target collision")
 local oldParent,oldName=x.Parent,x.Name;table.insert(undo,function()x.Parent=oldParent;x.Name=oldName end);x.Name=p[#p];x.Parent=parent
end
local function attr(x,k,v)local old=x:GetAttribute(k);table.insert(undo,function()x:SetAttribute(k,old)end);x:SetAttribute(k,v)end
local function detach(x)
 assert(#x:GetChildren()==0 and not x:IsA("Model") and not x:IsA("BasePart"),"Protected/unreviewed deletion")
 local parent=x.Parent;table.insert(undo,function()x.Parent=parent end);x.Parent=nil;table.insert(detached,x)
end
local function physicalAudit()
 for x,p in physical do
  assert(x.Parent==originals[x].parent and x.Name==originals[x].name,"Physical identity/parent changed")
  if x:IsA("BasePart") then assert(x.CFrame==p[1] and x.Size==p[2] and x.Color==p[3] and x.Material==p[4] and x.Transparency==p[5] and x.Anchored==p[6] and x.CanCollide==p[7] and x.CanQuery==p[8] and x.CanTouch==p[9] and x.CollisionGroup==p[10],"Physical properties changed")
  else assert(x.PrimaryPart==p[1],"Model primary part changed") end
 end
 for x,p in wip do
  assert(x.Parent==p.parent and x.Name==p.name,"WIP hierarchy changed")
  local attrs=x:GetAttributes();for k,v in p.attrs do assert(attrs[k]==v,"WIP attribute changed");attrs[k]=nil end;assert(next(attrs)==nil,"WIP attribute added")
  local expected={} for _,tag in p.tags do local replacement=MODE=="INSTALL" and D.tags[tag] or nil;if MODE=="ROLLBACK" then for old,new in D.tags do if tag==new then replacement=old end end end;expected[replacement or tag]=true end
  for _,tag in x:GetTags() do assert(expected[tag],"WIP tag added");expected[tag]=nil end;assert(next(expected)==nil,"WIP tag removed")
 end
end
local ok,err=xpcall(function()
 if MODE=="ROLLBACK" then
  local rs=table.clone(D.retired);table.sort(rs,function(a,b)return #a.path_parts<#b.path_parts end)
  for _,r in rs do if resolve(parentPath(r.path_parts)) then local x=create(r.path_parts,r.class_name);for k,v in r.attributes do attr(x,k,value(v)) end end end
 end
 local order={} for i in D.moves do table.insert(order,i) end
 table.sort(order,function(a,b)return #(MODE=="INSTALL" and D.moves[a].after or D.moves[a].before)<#(MODE=="INSTALL" and D.moves[b].after or D.moves[b].before) end)
 for _,i in order do move(moveObjects[i],MODE=="INSTALL" and D.moves[i].after or D.moves[i].before) end
 for i,r in D.sources do local x=sourceObjects[i];local old=x.Source;table.insert(undo,function()x.Source=old end);x.Source=MODE=="INSTALL" and r.source or r.before end
 for i,r in D.metadata do for _,x in metaObjects[i] do for _,c in r.changes do if MODE=="INSTALL" then attr(x,c.old,nil);if c.new then attr(x,c.new,value(c.afterValue or c.value)) end else if c.new then attr(x,c.new,nil) end;attr(x,c.old,value(c.value)) end end end end
 for old,new in D.tags do local from,to=old,new;if MODE=="ROLLBACK" then from,to=new,old end
  for _,x in CS:GetTagged(from) do assert(inScope(x) or permittedWip[key(objectPath(x)).."|"..old],"Unapproved tag object");table.insert(undo,function()CS:RemoveTag(x,to);CS:AddTag(x,from)end);CS:AddTag(x,to);CS:RemoveTag(x,from) end
 end
 if MODE=="INSTALL" then
  local rs=table.clone(D.retired);table.sort(rs,function(a,b)return #a.path_parts>#b.path_parts end)
  for _,r in rs do detach(assert(retiredObjects[key(r.path_parts)],"Missing captured retirement object")) end
 else
  local restore=table.clone(D.retired);table.sort(restore,function(a,b)return #a.path_parts<#b.path_parts end)
  for _,r in restore do local x=create(r.path_parts,r.class_name);for k,v in r.attributes do attr(x,k,value(v)) end end
  for _,r in D.retired do local x=assert(resolve(r.path_parts));for k,v in r.properties do if k=="Value" then x.Value=value(v) end end end
  local rs=table.clone(D.created);table.sort(rs,function(a,b)return #a.path>#b.path end);for _,r in rs do local x=resolve(r.path);if x then detach(x) end end
 end
 audit(MODE=="INSTALL");physicalAudit()
end,debug.traceback)
if not ok then for i=#undo,1,-1 do local good,message=pcall(undo[i]);if not good then warn("Rollback journal:",message) end end;error(err) end
for _,x in detached do x:Destroy() end
print("[Cleanup Phase 3]",MODE,"PASS",#D.sources,"sources",#D.moves,"moves",#D.retired,"retirements; physical/WIP invariants passed")
