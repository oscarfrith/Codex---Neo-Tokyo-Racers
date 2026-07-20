-- NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1
-- NTR_OWNED_GARAGE_STRUCTURE_CATALOG_V2
-- NTR_OWNED_GARAGE_STRUCTURE_ASSET_CATALOG_V1
local Catalog={Version=2,Channels={"Primary","Secondary","Detail"}}
local sections={{Id="FrontWall",Name="Front Wall",Order=10},{Id="LeftWall",Name="Left Wall",Order=20},{Id="RightWall",Name="Right Wall",Order=30},{Id="BackWall",Name="Back Wall",Order=40},{Id="Floor",Name="Floor",Order=50},{Id="Ceiling",Name="Ceiling",Order=60}}
local presets={
	{Name="Midnight",Price=0,Material="Metal",Colors={Primary={18,23,31},Secondary={38,45,58},Detail={26,210,220}}},
	{Name="Graphite",Price=6000,Material="Metal",Colors={Primary={48,54,64},Secondary={75,81,92},Detail={224,58,178}}},
	{Name="Urban Concrete",Price=9000,Material="Concrete",Colors={Primary={76,79,84},Secondary={112,115,120},Detail={255,156,54}}},
	{Name="Studio White",Price=12000,Material="SmoothPlastic",Colors={Primary={170,176,184},Secondary={105,112,123},Detail={50,190,255}}},
}
local allowed={Metal=true,Concrete=true,SmoothPlastic=true,DiamondPlate=true,WoodPlanks=true,Marble=true}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
local function styleId(section,index) return string.upper(section).."_OPTION_"..index end
function Catalog.Sections() return clone(sections) end
function Catalog.Materials() local r={}; for id in pairs(allowed) do table.insert(r,id) end; table.sort(r); return r end
function Catalog.Styles(section) local r={}; for index,p in ipairs(presets) do table.insert(r,{SectionId=section,StyleId=styleId(section,index),AssetOption=string.format("Option%02d",index),DisplayName=p.Name,Price=p.Price,SortOrder=index,Default=index==1,Colors=clone(p.Colors),Materials={Primary=p.Material,Secondary=p.Material,Detail="Metal"}}) end; return r end
function Catalog.ById(section,id) for _,item in ipairs(Catalog.Styles(section)) do if item.StyleId==tostring(id or "") then return item end end end
function Catalog.EncodeColor(value) if typeof(value)=="Color3" then return {math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5)} end; if type(value)=="table" then return {math.clamp(tonumber(value[1] or value.R) or 255,0,255),math.clamp(tonumber(value[2] or value.G) or 255,0,255),math.clamp(tonumber(value[3] or value.B) or 255,0,255)} end; return {255,255,255} end
function Catalog.DecodeColor(value) local c=Catalog.EncodeColor(value); return Color3.fromRGB(c[1],c[2],c[3]) end
function Catalog.NormalizeStructure(value,sectionIds)
	value=type(value)=="table" and value or {}; value.Sections=type(value.Sections)=="table" and value.Sections or {}; value.OwnedStyles=type(value.OwnedStyles)=="table" and value.OwnedStyles or {}
	for _,section in ipairs(sectionIds or {}) do local first=Catalog.Styles(section)[1]; value.OwnedStyles[first.StyleId]=true; local item=type(value.Sections[section])=="table" and value.Sections[section] or {}; local selected=Catalog.ById(section,item.StyleId) or first; item.StyleId=selected.StyleId; item.Colors=type(item.Colors)=="table" and item.Colors or {}; item.Materials=type(item.Materials)=="table" and item.Materials or {}; for _,channel in ipairs(Catalog.Channels) do item.Colors[channel]=Catalog.EncodeColor(item.Colors[channel] or selected.Colors[channel]); local material=tostring(item.Materials[channel] or selected.Materials[channel]); item.Materials[channel]=allowed[material] and material or selected.Materials[channel] end; value.Sections[section]=item end
	return value
end
function Catalog.ValidateStructure(value,sectionIds) value=Catalog.NormalizeStructure(value,sectionIds); for _,section in ipairs(sectionIds or {}) do local item=value.Sections[section]; if not (Catalog.ById(section,item.StyleId) and value.OwnedStyles[item.StyleId]) then return false,"Invalid or unowned structure style." end; for _,channel in ipairs(Catalog.Channels) do if not allowed[item.Materials[channel]] then return false,"Invalid structure material." end end end; return true end
function Catalog.ClientState(value,sectionIds) value=Catalog.NormalizeStructure(clone(value),sectionIds); local result={Sections=Catalog.Sections(),Styles={},Selected=value.Sections,OwnedStyles=clone(value.OwnedStyles),Materials=Catalog.Materials(),Channels=clone(Catalog.Channels)}; for _,section in ipairs(sectionIds or {}) do result.Styles[section]=Catalog.Styles(section); for _,channel in ipairs(Catalog.Channels) do result.Selected[section].Colors[channel]=Catalog.DecodeColor(result.Selected[section].Colors[channel]) end end; return result end
-- Legacy staged API remains readable until all historical callers retire.
function Catalog.List() local r={}; for _,section in ipairs(sections) do for _,item in ipairs(Catalog.Styles(section.Id)) do table.insert(r,item) end end; return r end
function Catalog.DefaultStyles() return {} end
function Catalog.IsValid() return false end
function Catalog.ByIdLegacy() return nil end
return Catalog
