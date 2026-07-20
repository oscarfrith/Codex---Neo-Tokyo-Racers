-- NTR_OWNED_GARAGE_LIGHTING_CATALOG_V1
local Catalog={Version=1}
local presets={
	{PresetId="MIDNIGHT_CYAN",DisplayName="Midnight Cyan",AssetName="StandardFixture",Price=0,SortOrder=10,DefaultOwned=true,PrimaryColor={30,210,225},AccentColor={224,58,178},Brightness=1.8,Range=30},
	{PresetId="SHOWROOM_WHITE",DisplayName="Showroom White",AssetName="StandardFixture",Price=5000,SortOrder=20,PrimaryColor={235,242,255},AccentColor={100,190,255},Brightness=2.2,Range=32},
	{PresetId="SAKURA_NIGHT",DisplayName="Sakura Night",AssetName="StandardFixture",Price=7500,SortOrder=30,PrimaryColor={245,80,190},AccentColor={120,70,255},Brightness=2,Range=30},
	{PresetId="AMBER_LOUNGE",DisplayName="Amber Lounge",AssetName="StandardFixture",Price=9000,SortOrder=40,PrimaryColor={255,160,70},AccentColor={255,80,45},Brightness=1.65,Range=28},
}
local levels={{Id="LOW",DisplayName="Low",Value=.65,SortOrder=10},{Id="BALANCED",DisplayName="Balanced",Value=1,SortOrder=20},{Id="HIGH",DisplayName="High",Value=1.3,SortOrder=30}}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
function Catalog.Presets() return clone(presets) end
function Catalog.ById(id) for _,item in ipairs(presets) do if item.PresetId==tostring(id or "") then return clone(item) end end end
function Catalog.Levels() return clone(levels) end
function Catalog.Level(value) value=tonumber(value) or 1; local best=levels[1]; for _,item in ipairs(levels) do if math.abs(item.Value-value)<math.abs(best.Value-value) then best=item end end; return clone(best) end
function Catalog.DecodeColor(value) return Color3.fromRGB(tonumber(value and value[1]) or 255,tonumber(value and value[2]) or 255,tonumber(value and value[3]) or 255) end
function Catalog.Normalize(value)
	value=type(value)=="table" and value or {}; value.OwnedPresets=type(value.OwnedPresets)=="table" and value.OwnedPresets or {}; for _,preset in ipairs(presets) do if preset.DefaultOwned then value.OwnedPresets[preset.PresetId]=true end end
	local selected=Catalog.ById(value.PresetId) or presets[1]; value.PresetId=selected.PresetId; value.Intensity=Catalog.Level(value.Intensity).Value; return value
end
function Catalog.Validate(value) value=Catalog.Normalize(value); if not (Catalog.ById(value.PresetId) and value.OwnedPresets[value.PresetId]) then return false,"Invalid or unowned lighting preset." end; return true end
function Catalog.ClientState(value) value=Catalog.Normalize(clone(value)); return {Version=Catalog.Version,Presets=Catalog.Presets(),Levels=Catalog.Levels(),OwnedPresets=clone(value.OwnedPresets),PresetId=value.PresetId,Intensity=value.Intensity} end
return Catalog
