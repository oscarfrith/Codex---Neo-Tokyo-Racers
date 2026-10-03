-- GENERATED public catalogue index; edit canonical model attributes, regenerate, then restart Play.
local data={["Cockpits"]={},["Modules"]={},["Revision"]="469d9bd81944a3d71a127ea1d5e702720b75f55524391cb27008e05e8fc2cf0e",["SchemaVersion"]=1}
for _,name in {"PIERCER_1","PIERCER_2"} do
	local chunk=require(script:WaitForChild(name))
	for _,kind in {"Cockpits","Modules"} do
		for id,record in pairs(chunk[kind]) do
			assert(data[kind][id]==nil,"Duplicate catalogue id "..tostring(id).." in "..name)
			data[kind][id]=record
		end
	end
end
local function freeze(t) for _,v in pairs(t) do if type(v)=="table" then freeze(v) end end return table.freeze(t) end
return freeze(data)
