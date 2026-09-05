-- NTR_OWNED_GARAGE_LIGHTING_CATALOG_V1
-- NTR_OWNED_GARAGE_PHASE14_V1_LIGHTING_STATE_FOUNDATION
local Catalog={Version=2,ColourChannels={"Primary","Secondary"}}
local presets={
	{PresetId="MIDNIGHT_CYAN",DisplayName="Midnight Cyan",AssetName="LightingOption01",Price=0,SortOrder=10,DefaultOwned=true,Brightness=1.8,Range=30},
	{PresetId="SHOWROOM_WHITE",DisplayName="Showroom White",AssetName="LightingOption02",Price=5000,SortOrder=20,Brightness=2.2,Range=32},
	{PresetId="SAKURA_NIGHT",DisplayName="Sakura Night",AssetName="LightingOption03",Price=7500,SortOrder=30,Brightness=2,Range=30},
	{PresetId="AMBER_LOUNGE",DisplayName="Amber Lounge",AssetName="LightingOption04",Price=9000,SortOrder=40,Brightness=1.65,Range=28},
}
local levels={{Id="LOW",DisplayName="Low",Value=.65,SortOrder=10},{Id="BALANCED",DisplayName="Balanced",Value=1,SortOrder=20},{Id="HIGH",DisplayName="High",Value=1.3,SortOrder=30}}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
local function encode(value) if typeof(value)=="Color3" then return {math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5)} end; if type(value)=="table" then return {math.clamp(math.floor((tonumber(value[1] or value.R) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[2] or value.G) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[3] or value.B) or 255)+.5),0,255)} end; return {255,255,255} end
function Catalog.EncodeColor(value) return encode(value) end
function Catalog.DecodeColor(value) local c=encode(value); return Color3.fromRGB(c[1],c[2],c[3]) end
function Catalog.Presets() return clone(presets) end
function Catalog.ById(id) for _,item in ipairs(presets) do if item.PresetId==tostring(id or "") then return clone(item) end end end
function Catalog.Levels() return clone(levels) end
function Catalog.Level(value) value=tonumber(value) or 1; local best=levels[1]; for _,item in ipairs(levels) do if math.abs(item.Value-value)<math.abs(best.Value-value) then best=item end end; return clone(best) end
function Catalog.Normalize(value)
	value=type(value)=="table" and value or {}; value.OwnedPresets=type(value.OwnedPresets)=="table" and value.OwnedPresets or {}; value.Finishes=type(value.Finishes)=="table" and value.Finishes or {}
	for _,preset in ipairs(presets) do if preset.DefaultOwned then value.OwnedPresets[preset.PresetId]=true end; local finish=value.Finishes[preset.PresetId]; if type(finish)~="table" then finish={Colors={}}; value.Finishes[preset.PresetId]=finish end; finish.Colors=type(finish.Colors)=="table" and finish.Colors or {}; for channel,color in pairs(finish.Colors) do if channel~="Primary" and channel~="Secondary" then finish.Colors[channel]=nil else finish.Colors[channel]=encode(color) end end end
	local selected=Catalog.ById(value.PresetId) or presets[1]; value.PresetId=selected.PresetId; value.Intensity=Catalog.Level(value.Intensity).Value; return value
end
function Catalog.Finish(value,presetId) value=Catalog.Normalize(value); presetId=tostring(presetId or value.PresetId); value.Finishes[presetId]=type(value.Finishes[presetId])=="table" and value.Finishes[presetId] or {Colors={}}; value.Finishes[presetId].Colors=type(value.Finishes[presetId].Colors)=="table" and value.Finishes[presetId].Colors or {}; return value.Finishes[presetId] end
function Catalog.Validate(value) value=Catalog.Normalize(value); if not (Catalog.ById(value.PresetId) and value.OwnedPresets[value.PresetId]) then return false,"Invalid or unowned lighting preset." end; return true end
function Catalog.ClientState(value,capabilities)
	value=Catalog.Normalize(clone(value)); capabilities=type(capabilities)=="table" and capabilities or {}; local visible={}; local selected
	for _,preset in ipairs(presets) do local cap=capabilities[preset.PresetId]; if cap and cap.Available then local finish=Catalog.Finish(value,preset.PresetId); local colors={}; for _,channel in ipairs(cap.ColourChannels or {}) do colors[channel]=Catalog.DecodeColor(finish.Colors[channel] or (cap.DefaultColors and cap.DefaultColors[channel])) end; local row=clone(preset); row.ColourChannels=clone(cap.ColourChannels or {}); row.Colors=colors; table.insert(visible,row); if preset.PresetId==value.PresetId then selected=row end end end
	selected=selected or visible[1]; return {Version=Catalog.Version,Presets=visible,Levels=Catalog.Levels(),OwnedPresets=clone(value.OwnedPresets),PresetId=selected and selected.PresetId or value.PresetId,Intensity=value.Intensity,Selected=selected and clone(selected) or {ColourChannels={},Colors={}}}
end
return Catalog
