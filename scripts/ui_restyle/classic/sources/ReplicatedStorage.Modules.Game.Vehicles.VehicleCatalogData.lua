-- GENERATED public catalogue index; edit canonical model attributes, regenerate, then restart Play.
local data={["Cockpits"]={},["Modules"]={},["Revision"]="1100fd98a61a0a2effc9cabef25c3f6574d1838f1a15d16ae8024f85f692c43c",["SchemaVersion"]=1}
for _,name in {"EXOTIC_1","EXOTIC_2","EXOTIC_3","MUSCLE_1","MUSCLE_2","MUSCLE_3","PIERCER_1","PIERCER_2"} do
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
