-- GENERATED public catalogue index; edit canonical model attributes, regenerate, then restart Play.
local data={["Cockpits"]={},["Modules"]={},["Revision"]="37f47fadff3d352d2bcc97399369f46044dd022e1d2e1661bcb28d642f5b986f",["SchemaVersion"]=1}
for _,name in {"EXOTIC_1","EXOTIC_2","PIERCER_1","PIERCER_2"} do
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
