-- Transport reuse only: profiles and command results are never cached here.
local Client={}
local cachedRemote,cachedRevision,cachedCatalog
local function clone(value)
 if type(value)~="table" then return value end
 local copy={} for k,v in pairs(value) do copy[k]=clone(v) end return copy
end
local function freeze(value)
 for _,v in pairs(value) do if type(v)=="table" then freeze(v) end end
 return table.freeze(value)
end
local function accept(remote,result,requestedRevision,requestedCatalog)
 if type(result)~="table" or result.Success~=true then return result,false end
 if result.CatalogProtocol~=1 or type(result.CatalogRevision)~="string" or #result.CatalogRevision>64 then
  return {Success=false,Message="Garage catalogue version unavailable. Please try again."},false
 end
 if type(result.Catalog)=="table" then
  cachedRemote=remote;cachedRevision=result.CatalogRevision;cachedCatalog=freeze(result.Catalog)
  result.Catalog=clone(cachedCatalog)
  return result,false
 end
 if requestedCatalog and requestedRevision==result.CatalogRevision then
  result.Catalog=clone(requestedCatalog)
  return result,false
 end
 return result,true
end
function Client.Fetch(remote,payload)
 local request=table.clone(payload or {})
 local revision,catalog
 if cachedRemote==remote then revision=cachedRevision;catalog=cachedCatalog end
 request.KnownCatalogRevision=revision
 local result,retry=accept(remote,remote:InvokeServer("GetInitial",request),revision,catalog)
 if not retry then return result end
 -- At most one read-only recovery request; never retry purchase/paint commands.
 request.KnownCatalogRevision=nil
 result,retry=accept(remote,remote:InvokeServer("GetInitial",request),nil,nil)
 if retry then return {Success=false,Message="Garage catalogue unavailable. Please try again."} end
 return result
end
return table.freeze(Client)
