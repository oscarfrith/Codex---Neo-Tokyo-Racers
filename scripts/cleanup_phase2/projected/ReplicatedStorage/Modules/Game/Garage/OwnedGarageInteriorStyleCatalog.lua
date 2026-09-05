-- NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1
-- NTR_OWNED_GARAGE_STRUCTURE_CATALOG_V2
-- NTR_OWNED_GARAGE_STRUCTURE_ASSET_CATALOG_V1
-- NTR_OWNED_GARAGE_SHARED_FINISH_STRUCTURE_V1
-- NTR_OWNED_GARAGE_PHASE13_V1_1_ATTRIBUTE_PLATFORM_STRUCTURE
-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS
local Catalog={Version=4,Channels={"Primary","Secondary","Detail","Neon"},MaterialChannels={"Primary","Secondary","Detail"}}
local sections={{Id="FrontWall",Name="Front Wall",Order=10},{Id="LeftWall",Name="Left Wall",Order=20},{Id="RightWall",Name="Right Wall",Order=30},{Id="BackWall",Name="Back Wall",Order=40},{Id="Floor",Name="Floor",Order=50},{Id="Ceiling",Name="Ceiling",Order=60}}
local presets={{Name="Midnight",Price=0},{Name="Graphite",Price=6000},{Name="Urban Concrete",Price=9000},{Name="Studio White",Price=12000}}
local materials={
	{Id="CONCRETE",DisplayName="Concrete",BaseMaterial="Asphalt",MaterialVariant="Asphalt New",SortOrder=10},
	{Id="METAL",DisplayName="Metal",BaseMaterial="Metal",SortOrder=20},
	{Id="WOOD",DisplayName="Wood",BaseMaterial="Wood",MaterialVariant="Plywood",SortOrder=30},
	{Id="PAINT",DisplayName="Paint",BaseMaterial="Plastic",SortOrder=40},
	{Id="TILES_A",DisplayName="Tiles A",BaseMaterial="CeramicTiles",SortOrder=50},
	{Id="TILES_B",DisplayName="Tiles B",BaseMaterial="CeramicTiles",MaterialVariant="Tiles Rectangular Horizontal (Small)",SortOrder=60},
	{Id="TILES_C",DisplayName="Tiles C",BaseMaterial="CeramicTiles",MaterialVariant="Tiles Rectangular Small",SortOrder=70},
	{Id="TILES_D",DisplayName="Tiles D",BaseMaterial="CeramicTiles",MaterialVariant="Tiles Rectangular Vertical (Small)",SortOrder=80},
	{Id="TILES_E",DisplayName="Tiles E",BaseMaterial="CeramicTiles",MaterialVariant="Tiles Square Large",SortOrder=90},
	{Id="TILES_F",DisplayName="Tiles F",BaseMaterial="CeramicTiles",MaterialVariant="Tiles Square Small",SortOrder=100},
}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
local function styleId(section,index) return string.upper(section).."_OPTION_"..index end
function Catalog.Sections() return clone(sections) end
function Catalog.Materials() return clone(materials) end
function Catalog.MaterialById(value) for _,item in ipairs(materials) do if item.Id==tostring(value or "") then return clone(item) end end end
function Catalog.IsMaterial(value) return Catalog.MaterialById(value)~=nil end
function Catalog.Styles(section) local r={}; for index,p in ipairs(presets) do table.insert(r,{SectionId=section,StyleId=styleId(section,index),AssetOption=string.format("Option%02d",index),DisplayName=p.Name,Price=p.Price,SortOrder=index,Default=index==1}) end; return r end
function Catalog.ById(section,id) for _,item in ipairs(Catalog.Styles(section)) do if item.StyleId==tostring(id or "") then return item end end end
function Catalog.EncodeColor(value) if typeof(value)=="Color3" then return {math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5)} end; if type(value)=="table" then return {math.clamp(math.floor((tonumber(value[1] or value.R) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[2] or value.G) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[3] or value.B) or 255)+.5),0,255)} end; return {255,255,255} end
function Catalog.DecodeColor(value) local c=Catalog.EncodeColor(value); return Color3.fromRGB(c[1],c[2],c[3]) end
local function sanitiseFinish(value)
	value=type(value)=="table" and value or {}; local result={Colors={},Materials={}}
	for channel,color in pairs(type(value.Colors)=="table" and value.Colors or {}) do if table.find(Catalog.Channels,channel) and color~=nil then result.Colors[channel]=Catalog.EncodeColor(color) end end
	for channel,materialId in pairs(type(value.Materials)=="table" and value.Materials or {}) do if table.find(Catalog.MaterialChannels,channel) and Catalog.IsMaterial(materialId) then result.Materials[channel]=tostring(materialId) end end
	return result
end
function Catalog.NormalizeStructure(value,sectionIds)
	value=type(value)=="table" and value or {}; value.Sections=type(value.Sections)=="table" and value.Sections or {}; value.OwnedStyles=type(value.OwnedStyles)=="table" and value.OwnedStyles or {}; value.Finishes=type(value.Finishes)=="table" and value.Finishes or {}
	for _,section in ipairs(sectionIds or {}) do
		local first=Catalog.Styles(section)[1]; value.OwnedStyles[first.StyleId]=true; local existing=type(value.Sections[section])=="table" and value.Sections[section] or {}; local selected=Catalog.ById(section,existing.StyleId) or first
		if Catalog.ById(section,existing.StyleId) and value.Finishes[selected.StyleId]==nil then value.Finishes[selected.StyleId]=sanitiseFinish(existing) end
		local finish=sanitiseFinish(value.Finishes[selected.StyleId]); value.Finishes[selected.StyleId]=clone(finish); value.Sections[section]={StyleId=selected.StyleId,Colors=clone(finish.Colors),Materials=clone(finish.Materials)}
	end
	return value
end
function Catalog.StoreFinish(value,section,item)
	value=Catalog.NormalizeStructure(value,{section}); item=type(item)=="table" and item or value.Sections[section]; local style=Catalog.ById(section,item.StyleId); if not style then return false end; local finish=sanitiseFinish(item); value.Finishes[style.StyleId]=clone(finish); value.Sections[section]={StyleId=style.StyleId,Colors=clone(finish.Colors),Materials=clone(finish.Materials)}; return true
end
function Catalog.SelectStyle(value,section,styleId)
	value=Catalog.NormalizeStructure(value,{section}); Catalog.StoreFinish(value,section,value.Sections[section]); local style=Catalog.ById(section,styleId); if not style then return nil end; local finish=sanitiseFinish(value.Finishes[style.StyleId]); value.Finishes[style.StyleId]=clone(finish); value.Sections[section]={StyleId=style.StyleId,Colors=clone(finish.Colors),Materials=clone(finish.Materials)}; return value.Sections[section]
end
function Catalog.ValidateStructure(value,sectionIds)
	value=Catalog.NormalizeStructure(value,sectionIds); for _,section in ipairs(sectionIds or {}) do local item=value.Sections[section]; if not (Catalog.ById(section,item.StyleId) and value.OwnedStyles[item.StyleId]) then return false,"Invalid or unowned structure style." end; for _,materialId in pairs(item.Materials or {}) do if not Catalog.IsMaterial(materialId) then return false,"Invalid structure material." end end end; return true
end
function Catalog.ClientState(value,sectionIds,capabilities)
	value=Catalog.NormalizeStructure(clone(value),sectionIds); capabilities=type(capabilities)=="table" and capabilities or {}; local availableMaterials={}; for _,item in ipairs(materials) do if capabilities.__Materials and capabilities.__Materials[item.Id]==true then table.insert(availableMaterials,clone(item)) end end
	local result={Sections=Catalog.Sections(),Styles={},Selected=value.Sections,OwnedStyles=clone(value.OwnedStyles),Materials=availableMaterials,Channels=clone(Catalog.Channels),MaterialChannels=clone(Catalog.MaterialChannels)}
	for _,section in ipairs(sectionIds or {}) do
		result.Styles[section]=Catalog.Styles(section); for _,style in ipairs(result.Styles[section]) do local cap=capabilities[style.StyleId] or {}; style.ColourChannels=clone(cap.ColourChannels or {}); style.MaterialChannels=clone(cap.MaterialChannels or {}) end
		local selected=result.Selected[section]; local cap=capabilities[selected.StyleId] or {}; selected.ColourChannels=clone(cap.ColourChannels or {}); selected.MaterialChannels=clone(cap.MaterialChannels or {}); local colors={}; local selectedMaterials={}
		for _,channel in ipairs(selected.ColourChannels) do local raw=selected.Colors[channel] or (cap.DefaultColors and cap.DefaultColors[channel]); if raw~=nil then colors[channel]=Catalog.DecodeColor(raw) end end
		for _,channel in ipairs(selected.MaterialChannels) do selectedMaterials[channel]=selected.Materials[channel] or (cap.DefaultMaterials and cap.DefaultMaterials[channel]) end
		selected.Colors=colors; selected.Materials=selectedMaterials
	end
	return result
end
function Catalog.List() local r={}; for _,section in ipairs(sections) do for _,item in ipairs(Catalog.Styles(section.Id)) do table.insert(r,item) end end; return r end
function Catalog.DefaultStyles() return {} end
function Catalog.IsValid() return false end
return Catalog
