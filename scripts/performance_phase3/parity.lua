-- Edit-only isolated pure-module evaluation; never require gameplay modules in MCP.
assert(game.PlaceId==121304917315753 and not game:GetService("RunService"):IsRunning())
local Http=game:GetService("HttpService")
local before=Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8776/performance_phase3/sources-before.json"))
local D=Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8776/performance_phase3/payload.json"))
local after=table.clone(before)
for _,r in D.sources do after[table.concat(r.path,".")]=r.after end
for _,r in D.new do after[table.concat(r.path,".")]=r.source end
local prefix="ReplicatedStorage.Modules.Game.Vehicles."
local allowed={PerformanceDefinitions=true,PerformanceCalculator=true,PerformanceRuntime=true,PerformanceUpgradeRuntime=true,PerformanceDynamics=true,VehicleUpgradeDefinitions=true,VehiclePerformanceResolver=true,VehicleDefinition=true,VehicleCatalog=true,VehicleCatalogData=true,VehicleTemplateIndex=true}
local function resolve(path)local x=game for name in path:gmatch("[^.]+") do x=assert(x:FindFirstChild(name),path) end return x end
local function loader(sources)
 local cache={}
 local function load(module)
  local path=module:GetFullName();assert(allowed[module.Name] and path:sub(1,#prefix)==prefix,"Disallowed test require: "..path)
  if cache[path] then return cache[path] end
  local fn=assert(loadstring(assert(sources[path],path),"="..path))
  setfenv(fn,setmetatable({script=module,require=load},{__index=getfenv()}))
  cache[path]=fn();return cache[path]
 end
 return function(name)return load(resolve(prefix..name)) end
end
local old,new=loader(before),loader(after)
local a=old("Performance.VehiclePerformanceResolver");local b=new("Performance.VehiclePerformanceResolver")
local ua=old("Performance.PerformanceUpgradeRuntime");local ub=new("Performance.PerformanceUpgradeRuntime")
local ra=old("Performance.PerformanceRuntime");local rb=new("Performance.PerformanceRuntime")
local data=new("VehicleCatalogData");local catalog=new("VehicleCatalog");local index=new("VehicleTemplateIndex")
local root=game.ReplicatedStorage.Assets.Vehicles.Categories
local checks=0
local function same(x,y,path)
 assert(typeof(x)==typeof(y),"Type mismatch "..path)
 if typeof(x)=="number" then assert(x==y or math.abs(x-y)<=1e-9*math.max(1,math.abs(x),math.abs(y)),"Number mismatch "..path)
 elseif typeof(x)=="table" then for k,v in pairs(x) do same(v,y[k],path.."."..tostring(k)) end for k in pairs(y) do assert(x[k]~=nil,"Extra key "..path.."."..tostring(k)) end
 else assert(x==y,"Mismatch "..path) end
 checks+=1
end
local cockpitCount,moduleCount,allocations=0,0,0
for id,record in pairs(data.Cockpits) do
 local physical=index.Find(root,"CockpitId",id);assert(physical and physical:GetAttribute("CockpitId")==id)
 if record.RetiredFromCatalog~=true then
  same(a.Factory(root,{CockpitId=id}),b.Factory(nil,{CockpitId=id}),"Factory."..id)
  local _,_,slots=a.DefaultBuild(root,{CockpitId=id})
  local profile={CurrentCockpit=id,InstalledModules={},CurrentVehicleId="test",Vehicles={test={InstalledModules={}}},OwnedModuleInstances={}}
  for slot,model in slots do
   local mid=model:GetAttribute("ModuleId")
   profile.InstalledModules[slot]=mid
   profile.Vehicles.test.InstalledModules[slot]=slot
   profile.OwnedModuleInstances[slot]={TemplateId=mid,V2UpgradePoints={}}
  end
  same(a.Profile(root,profile),b.Profile(nil,profile),"Profile."..id)
  for slot,model in slots do
   local mid=model:GetAttribute("ModuleId");local instance=profile.OwnedModuleInstances[slot]
   same({a.Selected(root,profile,slot,{ModuleId=mid},instance)},{b.Selected(nil,profile,slot,{ModuleId=mid},instance)},"Selected."..id..slot)
   for _,path in data.Modules[mid].UpgradePaths do
    same({a.UpgradePreview(root,profile,slot,{ModuleId=mid},instance,path.Name)},{b.UpgradePreview(nil,profile,slot,{ModuleId=mid},instance,path.Name)},"UpgradePreview."..id..slot)
   end
  end
  cockpitCount+=1
 end
end
for id,record in pairs(data.Modules) do
 local physical=index.Find(root,"ModuleId",id);assert(physical and physical:GetAttribute("ModuleId")==id)
 local paths=record.UpgradePaths;moduleCount+=1
 local function check(allocation)
  allocations+=1
  same({ua.NormalizeAllocation(physical,allocation)},{ub.NormalizeAllocation(record,allocation)},"allocation."..id)
  same(ua.ApplyToModuleRaw(physical,allocation),ub.ApplyToModuleRaw(record,allocation),"raw."..id)
  same(ua.Catalog(physical,allocation),ub.Catalog(record,allocation),"paths."..id)
  same(ra.CatalogPreview(physical,allocation),rb.CatalogPreview(record,allocation),"catalog."..id)
  for _,p in paths do
   local pid=tostring(p.PathId or p.Name)
   same(ua.NextPointCost(physical,allocation,pid),ub.NextPointCost(record,allocation,pid),"cost."..id)
   local ok1,result1=ua.PreviewPoint(physical,allocation,pid);local ok2,result2=ub.PreviewPoint(record,allocation,pid)
   same(ok1,ok2,"previewOk");same(result1,result2,"preview."..id)
  end
 end
 local function enumerate(i,t)
  if i>#paths then check(t);return end
  local p=paths[i];local idp=tostring(p.PathId or p.Name)
  for v=0,math.max(0,math.floor(tonumber(p.MaxPoints) or 3)) do t[idp]=v;enumerate(i+1,t) end
  t[idp]=nil
 end
 enumerate(1,{})
 check({InvalidPath=99})
 if record.RetiredFromCatalog~=true then same(a.ModuleRating(root,{ModuleId=id}),b.ModuleRating(nil,{ModuleId=id}),"rating."..id) end
end
assert(catalog.Get("ModuleId","missing")==nil and index.Find(root,"ModuleId","missing")==nil)
assert(table.isfrozen(data) and table.isfrozen(data.Modules))
return Http:JSONEncode({pass=true,cockpits=cockpitCount,modules=moduleCount,allocationCases=allocations,comparisons=checks,revision=data.Revision,noGameplayRequire=true})
