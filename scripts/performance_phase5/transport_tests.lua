-- Isolated transport/guard tests: no gameplay require, remote or saved-data writes.
local H=game.HttpService
local D=H:JSONDecode(H:GetAsync("http://127.0.0.1:8776/performance_phase5/payload.json"))
local function fresh()return assert(loadstring(D.new[1].source))()end
local function full(revision,cash)return {Success=true,CatalogProtocol=1,CatalogRevision=revision,Catalog={Categories={{Name="Original",Price=100}}},Profile={Cash=cash}}end
local checks=0
local function expect(value)assert(value);checks+=1 end
local client=fresh();local calls=0
local remote={InvokeServer=function(_,action,payload)
 expect(action=="GetInitial");calls+=1
 if calls==1 then expect(payload.KnownCatalogRevision==nil);return full("A",10) end
 expect(payload.KnownCatalogRevision=="A");return {Success=true,CatalogProtocol=1,CatalogRevision="A",Profile={Cash=20}}
end}
local payload={};local one=client.Fetch(remote,payload);one.Catalog.Categories[1].Name="Mutated";one.Profile.Cash=-1
local two=client.Fetch(remote,payload)
expect(two.Profile.Cash==20 and two.Catalog.Categories[1].Name=="Original");expect(payload.KnownCatalogRevision==nil)
local other={InvokeServer=function(_,_,p)expect(p.KnownCatalogRevision==nil);return full("B",30)end}
expect(client.Fetch(other,{}).Profile.Cash==30)
local retries=0;client=fresh()
local recovery={InvokeServer=function(_,_,p)retries+=1;expect(p.KnownCatalogRevision==nil);if retries==1 then return {Success=true,CatalogProtocol=1,CatalogRevision="missing",Profile={}} end return full("recovered",40)end}
expect(client.Fetch(recovery,{}).Profile.Cash==40 and retries==2)
local failures=0
expect(fresh().Fetch({InvokeServer=function()failures+=1;return {Success=false,Message="Rate limited"}end},{}).Success==false and failures==1)
failures=0
expect(fresh().Fetch({InvokeServer=function()failures+=1;return {Success=true,CatalogProtocol=1,CatalogRevision="bad",Profile={}}end},{}).Success==false and failures==2)
expect(not pcall(function()fresh().Fetch({InvokeServer=function()error("network unavailable")end},{})end))
local guardSource for _,r in D.sources do if r.path[#r.path]=="GarageRequestGuard" then guardSource=r.after end end
local Guard=assert(loadstring(guardSource))();local clock=0;local g=Guard.new(function()return clock end);local player={}
expect(g.check(player,"GetInitial",{KnownCatalogRevision="A"})==true)
expect(g.check(player,"GetInitial",{KnownCatalogRevision={}})==false)
expect(g.check(player,"GetInitial",{KnownCatalogRevision=string.rep("a",65)})==false)
expect(g.check(player,"BuyCockpitInstance",{KnownCatalogRevision="A"})==false)
expect(g.check(player,"GetInitial",{Extra=true})==false)
local allowed=0 for _=1,30 do if g.check(player,"GetInitial",{}) then allowed+=1 end end expect(allowed<30)
clock=10;expect(g.check(player,"GetInitial",{})==true);g.forget(player)
return H:JSONEncode({pass=true,checks=checks,cacheIsolation=true,freshProfiles=true,boundedReadRecovery=true,guardLimits=true})
