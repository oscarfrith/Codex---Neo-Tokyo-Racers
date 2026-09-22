-- Appended to the existing export serializer by studio_capture.py; never installed in game.
local function unique(parts)
 local at=game
 for _,name in parts do
  local found=nil
  for _,child in at:GetChildren() do if child.Name==name then assert(not found,"Ambiguous requested path");found=child end end
  if not found then return nil end
  at=found
 end
 return at
end
local trees,missing={},{}
for className,names in pairs(request.properties or {}) do
 propertySchema[className]=propertySchema[className] or {}
 for _,name in names do if not table.find(propertySchema[className],name) then table.insert(propertySchema[className],name) end end
end
for _,parts in request.roots do
 local obj=unique(parts)
 if obj then table.insert(trees,makeNode(obj)) else table.insert(missing,parts) end
end
-- A complete source inventory is deliberately small compared with full world properties.
-- Read full text for exact local SHA256; the transport checksum is not a security hash.
scriptRecords={}
local sourceNodes={}
for _,name in serviceNamesToScan do
 for _,obj in game:GetService(name):GetDescendants() do
  if isScriptLike(obj) then
   assert(not isExcludedPath(obj:GetFullName()),"Excluded source requires explicit full audit")
   table.insert(sourceNodes,makeNode(obj,true))
  end
 end
end
-- Associate hierarchy script IDs with the complete inventory's IDs.
local ids={}
for _,r in scriptRecords do assert(not ids[r.path],"Ambiguous script path");ids[r.path]=r.id end
local function relink(n)
 if n.script_id then n.script_id=assert(ids[n.path]) end
 for _,c in n.children do relink(c) end
end
for _,n in trees do relink(n) end
assert(#diagnostics.property_read_errors==0,"Property coverage incomplete; inspect with full exporter")
local payload={format="SPACE_RACERS_SCOPED_CAPTURE",schema_revision=1,place_id=game.PlaceId,
 export_mode="Edit",generated_in_studio=os.date("!%Y-%m-%d %H:%M:%S UTC"),
 request=request,services_scanned=serviceNamesToScan,include_disabled_scripts=true,
 property_schema=propertySchema,diagnostics=diagnostics,hierarchy=trees,missing_roots=missing,
 source_nodes=sourceNodes,scripts=scriptRecords,script_count=#scriptRecords}
local text=HttpService:JSONEncode(payload)
local chunks={};local first=1
while first<=#text do
 local last=math.min(#text,first+179999)
 while last<#text and string.byte(text,last+1)>=128 and string.byte(text,last+1)<192 do last-=1 end
 table.insert(chunks,text:sub(first,last));first=last+1
end
assert(#chunks<=256,"Capture too large; narrow roots")
for i,chunk in chunks do
 local response=HttpService:PostAsync("http://127.0.0.1:8766/chunk",HttpService:JSONEncode({token=request.token,index=i,total=#chunks,data=chunk}),Enum.HttpContentType.ApplicationJson,false)
 assert(response=="OK","Capture receiver rejected data")
end
return "Read-only scoped capture sent; "..#scriptRecords.." sources, "..#trees.." roots. No game objects changed."
