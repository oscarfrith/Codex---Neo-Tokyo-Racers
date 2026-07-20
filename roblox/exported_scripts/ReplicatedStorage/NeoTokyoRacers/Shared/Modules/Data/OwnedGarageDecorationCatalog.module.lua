-- NTR_OWNED_GARAGE_DECORATION_CATALOG_V1
local Catalog={Version=1}
local categories={
	{CategoryId="Plants",DisplayName="PLANTS",IconKey="Leaf",SortOrder=10},
	{CategoryId="Paintings",DisplayName="PAINTINGS",IconKey="Image",SortOrder=20},
	{CategoryId="Furniture",DisplayName="FURNITURE",IconKey="Chair",SortOrder=30},
	{CategoryId="Lighting",DisplayName="LIGHTING",IconKey="Light",SortOrder=40},
	{CategoryId="Storage",DisplayName="STORAGE",IconKey="Box",SortOrder=50},
	{CategoryId="Signs",DisplayName="SIGNS",IconKey="Sign",SortOrder=60},
}
local items={
	{ItemId="PLANT_NEON_FERN",CategoryId="Plants",AssetName="NeonFern",DisplayName="Neon Fern",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="PLANT_TALL_PALM",CategoryId="Plants",AssetName="TallPalm",DisplayName="Tall Palm",Price=3500,SortOrder=20},
	{ItemId="PAINTING_CITY_GRID",CategoryId="Paintings",AssetName="CityGrid",DisplayName="City Grid",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="PAINTING_NIGHT_RUN",CategoryId="Paintings",AssetName="NightRun",DisplayName="Night Run",Price=4500,SortOrder=20},
	{ItemId="FURNITURE_LOW_BENCH",CategoryId="Furniture",AssetName="LowBench",DisplayName="Low Bench",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="FURNITURE_LOUNGE_CHAIR",CategoryId="Furniture",AssetName="LoungeChair",DisplayName="Lounge Chair",Price=6000,SortOrder=20},
	{ItemId="LIGHTING_FLOOR_LAMP",CategoryId="Lighting",AssetName="FloorLamp",DisplayName="Floor Lamp",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="LIGHTING_NEON_TOTEM",CategoryId="Lighting",AssetName="NeonTotem",DisplayName="Neon Totem",Price=7000,SortOrder=20},
	{ItemId="STORAGE_TOOL_CRATE",CategoryId="Storage",AssetName="ToolCrate",DisplayName="Tool Crate",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="STORAGE_PARTS_LOCKER",CategoryId="Storage",AssetName="PartsLocker",DisplayName="Parts Locker",Price=5000,SortOrder=20},
	{ItemId="SIGN_KANDA",CategoryId="Signs",AssetName="KandaSign",DisplayName="Kanda Sign",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="SIGN_RACER_CREW",CategoryId="Signs",AssetName="RacerCrew",DisplayName="Racer Crew",Price=5500,SortOrder=20},
}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
function Catalog.Categories() return clone(categories) end
function Catalog.Items(categoryId) local r={}; for _,item in ipairs(items) do if not categoryId or item.CategoryId==tostring(categoryId) then table.insert(r,clone(item)) end end; table.sort(r,function(a,b) if a.SortOrder~=b.SortOrder then return a.SortOrder<b.SortOrder end return a.ItemId<b.ItemId end); return r end
function Catalog.ById(itemId) for _,item in ipairs(items) do if item.ItemId==tostring(itemId or "") then return clone(item) end end end
function Catalog.IsAnchor(anchorId,anchorIds) for _,id in ipairs(anchorIds or {}) do if id==tostring(anchorId or "") then return true end end; return false end
function Catalog.Normalize(value,anchorIds)
	value=type(value)=="table" and value or {}; value.OwnedItems=type(value.OwnedItems)=="table" and value.OwnedItems or {}; value.Placements=type(value.Placements)=="table" and value.Placements or {}
	for _,item in ipairs(items) do if item.DefaultOwned then value.OwnedItems[item.ItemId]=true end end
	for anchorId,itemId in pairs(value.Placements) do if not Catalog.IsAnchor(anchorId,anchorIds) or not Catalog.ById(itemId) then value.Placements[anchorId]=nil end end
	return value
end
function Catalog.Validate(value,anchorIds) value=Catalog.Normalize(value,anchorIds); for anchorId,itemId in pairs(value.Placements) do if not (Catalog.IsAnchor(anchorId,anchorIds) and Catalog.ById(itemId) and value.OwnedItems[itemId]) then return false,"Invalid decoration placement." end end; return true end
function Catalog.ClientState(value,anchorIds)
	value=Catalog.Normalize(clone(value),anchorIds); local byCategory={}; for _,category in ipairs(categories) do byCategory[category.CategoryId]=Catalog.Items(category.CategoryId) end
	local anchorList={}; for index,anchorId in ipairs(anchorIds or {}) do table.insert(anchorList,{AnchorId=anchorId,DisplayName="DISPLAY POSITION "..index,SortOrder=index}) end
	return {Version=Catalog.Version,Categories=Catalog.Categories(),ItemsByCategory=byCategory,Anchors=anchorList,OwnedItems=clone(value.OwnedItems),Placements=clone(value.Placements)}
end
return Catalog
