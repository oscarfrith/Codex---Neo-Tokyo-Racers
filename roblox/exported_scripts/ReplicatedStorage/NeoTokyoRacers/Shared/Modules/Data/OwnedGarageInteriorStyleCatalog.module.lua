-- NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1
local Catalog={}
local styles={
	{StyleId="FLOOR_MIDNIGHT",SurfaceGroup="Floor",DisplayName="Midnight Metal",Color=Color3.fromRGB(18,23,31),Material="Metal",SortOrder=10,Default=true},
	{StyleId="FLOOR_GRAPHITE",SurfaceGroup="Floor",DisplayName="Graphite",Color=Color3.fromRGB(48,54,64),Material="Metal",SortOrder=11},
	{StyleId="FLOOR_CLEAN",SurfaceGroup="Floor",DisplayName="Clean Composite",Color=Color3.fromRGB(115,122,132),Material="SmoothPlastic",SortOrder=12},
	{StyleId="WALL_MIDNIGHT",SurfaceGroup="Walls",DisplayName="Midnight Walls",Color=Color3.fromRGB(27,34,45),Material="Metal",SortOrder=20,Default=true},
	{StyleId="WALL_CONCRETE",SurfaceGroup="Walls",DisplayName="Urban Concrete",Color=Color3.fromRGB(76,79,84),Material="Concrete",SortOrder=21},
	{StyleId="WALL_WHITE",SurfaceGroup="Walls",DisplayName="Studio White",Color=Color3.fromRGB(170,176,184),Material="SmoothPlastic",SortOrder=22},
	{StyleId="ROOF_DARK",SurfaceGroup="Roof",DisplayName="Dark Roof",Color=Color3.fromRGB(12,16,23),Material="Metal",SortOrder=30,Default=true},
	{StyleId="ROOF_GRAPHITE",SurfaceGroup="Roof",DisplayName="Graphite Roof",Color=Color3.fromRGB(50,56,67),Material="Metal",SortOrder=31},
	{StyleId="PAD_CYAN",SurfaceGroup="DisplayPads",DisplayName="Cyan Display Pads",Color=Color3.fromRGB(24,61,74),Material="Metal",SortOrder=40,Default=true},
	{StyleId="PAD_MAGENTA",SurfaceGroup="DisplayPads",DisplayName="Magenta Display Pads",Color=Color3.fromRGB(82,28,66),Material="Metal",SortOrder=41},
	{StyleId="PAD_GUNMETAL",SurfaceGroup="DisplayPads",DisplayName="Gunmetal Display Pads",Color=Color3.fromRGB(42,47,55),Material="Metal",SortOrder=42},
	{StyleId="DOOR_STEEL",SurfaceGroup="Doors",DisplayName="Steel Door",Color=Color3.fromRGB(44,54,70),Material="Metal",SortOrder=50,Default=true},
	{StyleId="DOOR_RED",SurfaceGroup="Doors",DisplayName="Signal Red Door",Color=Color3.fromRGB(126,42,52),Material="Metal",SortOrder=51},
}
local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
function Catalog.List() local result=clone(styles); table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Catalog.ById(styleId) for _,style in ipairs(styles) do if style.StyleId==tostring(styleId or "") then return clone(style) end end end
function Catalog.ForSurface(group) local result={}; for _,style in ipairs(styles) do if style.SurfaceGroup==tostring(group or "") then table.insert(result,clone(style)) end end; table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Catalog.DefaultStyles() local result={}; for _,style in ipairs(styles) do if style.Default then result[style.SurfaceGroup]=style.StyleId end end; return result end
function Catalog.IsValid(group,styleId) local style=Catalog.ById(styleId); return style~=nil and style.SurfaceGroup==tostring(group or "") end
return Catalog
