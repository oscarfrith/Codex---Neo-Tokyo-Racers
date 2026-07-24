-- NTR_OWNED_GARAGE_FINISH_RUNTIME_V1
-- NTR_OWNED_GARAGE_PHASE13_V1_1_ATTRIBUTE_PLATFORM_FINISH
-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS
-- NTR_OWNED_GARAGE_PHASE13_V1_4_SUBMISSION_HARDENING
-- NTR_OWNED_GARAGE_PHASE14_V1_LIGHTING_STATE_FOUNDATION
-- NTR_OWNED_GARAGE_LIGHTING_CHANNELS_DECORATION_FLOW_V1
local MaterialService=game:GetService("MaterialService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Runtime={Version=2,ColourChannels={"Primary","Secondary","Detail","Neon"},MaterialChannels={"Primary","Secondary","Detail"}}
local known={Primary=true,Secondary=true,Detail=true,Neon=true}; local cache=setmetatable({},{__mode="k"}); local materialCache={}; local StyleCatalogCache
local function StyleCatalog() if not StyleCatalogCache then StyleCatalogCache=require(ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")) end; return StyleCatalogCache end
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
local function encode(value) if typeof(value)=="Color3" then return {math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5)} end; if type(value)=="table" then return {math.clamp(math.floor((tonumber(value[1] or value.R) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[2] or value.G) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[3] or value.B) or 255)+.5),0,255)} end; return {255,255,255} end
local function decode(value) local c=encode(value); return Color3.fromRGB(c[1],c[2],c[3]) end
local function channelFor(object,root,legacy)
	local cursor=object
	while cursor and cursor~=root do
		if (cursor.Name=="Fixed" or cursor.Name=="Technical") and cursor.Parent==root then return nil end
		if known[cursor.Name] and cursor.Parent and cursor.Parent.Name=="ColourSlots" then return cursor.Name end
		cursor=cursor.Parent
	end
	local direct=tostring(object:GetAttribute("GarageColourChannel") or (legacy and object:GetAttribute("StructureChannel")) or "")
	if known[direct] then return direct end
end
local function resolveMaterial(materialId)
	materialId=tostring(materialId or ""); if materialCache[materialId]~=nil then return materialCache[materialId] or nil end; local definition=StyleCatalog().MaterialById(materialId); if not definition then materialCache[materialId]=false; return nil end
	local base=Enum.Material[definition.BaseMaterial]; local variant=""
	if definition.MaterialVariant then
		local found; for _,child in ipairs(MaterialService:GetChildren()) do if child:IsA("MaterialVariant") and child.Name==definition.MaterialVariant then found=child; break end end
		if not found then for _,candidate in ipairs(Enum.Material:GetEnumItems()) do local ok,result=pcall(MaterialService.GetMaterialVariant,MaterialService,candidate,definition.MaterialVariant); if ok and result then found=result; break end end end
		if not found then materialCache[materialId]=false; return nil end; base=found.BaseMaterial; variant=definition.MaterialVariant
	end
	if not base then materialCache[materialId]=false; return nil end; local result={Id=materialId,BaseMaterial=base,MaterialVariant=variant}; materialCache[materialId]=result; return result
end
local function materialIdFor(part)
	local variant=tostring(part.MaterialVariant or ""); for _,definition in ipairs(StyleCatalog().Materials()) do local resolved=resolveMaterial(definition.Id); if resolved and ((variant~="" and variant==resolved.MaterialVariant) or (variant=="" and resolved.MaterialVariant=="" and part.Material==resolved.BaseMaterial)) then return definition.Id end end
end
local function inspect(asset,kind)
	local cached=cache[asset]; if cached and cached.Kind==kind then return clone(cached) end
	local colours={}; local materials={}; local defaults={}; local defaultMaterials={}; local mixedColours={}; local mixedMaterials={}; local partCount=0
	local function sampleColour(channel,value)
		if not channel then return end
		colours[channel]=true
		local encoded=encode(value)
		if defaults[channel] and (defaults[channel][1]~=encoded[1] or defaults[channel][2]~=encoded[2] or defaults[channel][3]~=encoded[3]) then mixedColours[channel]=true else defaults[channel]=defaults[channel] or encoded end
	end
	for _,object in ipairs(asset:GetDescendants()) do
		if object:IsA("BasePart") then
			partCount+=1
			local channel=channelFor(object,asset,kind=="Structure")
			if channel then
				sampleColour(channel,object.Color)
				if kind=="Structure" and channel~="Neon" and object:GetAttribute("GarageMaterialLocked")~=true then
					materials[channel]=true
					local materialId=materialIdFor(object)
					if defaultMaterials[channel] and materialId and defaultMaterials[channel]~=materialId then mixedMaterials[channel]=true elseif materialId then defaultMaterials[channel]=defaultMaterials[channel] or materialId end
				end
			end
		elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
			local channel=channelFor(object,asset,false)
			if channel then
				colours[channel]=true
				if defaults[channel]==nil then defaults[channel]=encode(object.Color) end
			end
		end
	end
	local result={Kind=kind,ColourChannels={},MaterialChannels={},DefaultColors=defaults,DefaultMaterials=defaultMaterials,MixedColourChannels=mixedColours,MixedMaterialChannels=mixedMaterials,PartCount=partCount,Available=partCount>0 and asset:GetAttribute("Available")~=false}
	for _,channel in ipairs(Runtime.ColourChannels) do if colours[channel] then table.insert(result.ColourChannels,channel) end end
	for _,channel in ipairs(Runtime.MaterialChannels) do if materials[channel] then table.insert(result.MaterialChannels,channel) end end
	cache[asset]=clone(result)
	return result
end
local function root() local n=ServerStorage:FindFirstChild("NeoTokyoRacers"); return n and n:FindFirstChild("OwnedGarage") end
function Runtime.StructureAsset(templateId,sectionId,assetName) local r=root(); r=r and r:FindFirstChild("StructureAssets"); r=r and r:FindFirstChild(tostring(templateId or "")); r=r and r:FindFirstChild(tostring(sectionId or "")); local asset=r and r:FindFirstChild(tostring(assetName or "")); return asset and asset:IsA("Model") and asset or nil end
function Runtime.DecorationAsset(templateId,slotId,assetName,assetGroupId) local r=root(); r=r and r:FindFirstChild("DecorationAssets"); r=r and r:FindFirstChild(tostring(templateId or "")); r=r and r:FindFirstChild(tostring(assetGroupId or slotId or "")); local asset=r and r:FindFirstChild(tostring(assetName or "")); return asset and asset:IsA("Model") and asset or nil end
function Runtime.LightingAsset(templateId,assetName) local r=root(); r=r and r:FindFirstChild("LightingAssets"); r=r and r:FindFirstChild(tostring(templateId or "")); local asset=r and r:FindFirstChild(tostring(assetName or "")); return asset and asset:IsA("Model") and asset or nil end
function Runtime.LightingCapabilities(templateId,lightingCatalog) local result={}; for _,preset in ipairs(lightingCatalog.Presets()) do local asset=Runtime.LightingAsset(templateId,preset.AssetName); if asset then result[preset.PresetId]=inspect(asset,"Lighting") end end; return result end
function Runtime.IsLightingAvailable(templateId,preset) local asset=preset and Runtime.LightingAsset(templateId,preset.AssetName); return asset~=nil and inspect(asset,"Lighting").Available==true end
function Runtime.ValidateLightingFinish(templateId,preset,colors) local asset=preset and Runtime.LightingAsset(templateId,preset.AssetName); if not asset then return false,"Lighting asset is missing." end; local cap=inspect(asset,"Lighting"); if not cap.Available then return false,"Lighting option is not populated or enabled." end; for channel in pairs(type(colors)=="table" and colors or {}) do local supported=false; for _,candidate in ipairs(cap.ColourChannels or {}) do if candidate==channel then supported=true end end; if not supported then return false,"Colour channel is not available for this lighting option." end end; return true,cap end
function Runtime.MaterialCapabilities(styleCatalog)
 local result={}; for _,definition in ipairs(styleCatalog.Materials()) do result[definition.Id]=resolveMaterial(definition.Id)~=nil end; return result end
function Runtime.StructureCapabilities(templateId,styleCatalog,sections) local result={__Materials=Runtime.MaterialCapabilities(styleCatalog)}; for _,section in ipairs(sections or {}) do for _,style in ipairs(styleCatalog.Styles(section)) do local asset=Runtime.StructureAsset(templateId,section,style.AssetOption); if asset then result[style.StyleId]=inspect(asset,"Structure") end end end; return result end
function Runtime.DecorationCapabilities(templateId,decorationCatalog) local result={}; for _,item in ipairs(decorationCatalog.Items()) do local asset=Runtime.DecorationAsset(templateId,item.ZoneId,item.AssetName,item.AssetGroupId); if asset then result[item.ItemId]=inspect(asset,"Decoration") end end; return result end
function Runtime.IsDecorationAvailable(templateId,item) local asset=item and Runtime.DecorationAsset(templateId,item.ZoneId,item.AssetName,item.AssetGroupId); return asset~=nil and inspect(asset,"Decoration").Available==true end
local function contains(list,value) for _,candidate in ipairs(list or {}) do if candidate==value then return true end end; return false end
function Runtime.ValidateStructureFinish(templateId,sectionId,assetName,colors,materials) local asset=Runtime.StructureAsset(templateId,sectionId,assetName); if not asset then return false,"Structure finish asset is missing." end; local cap=inspect(asset,"Structure"); for channel in pairs(type(colors)=="table" and colors or {}) do if not contains(cap.ColourChannels,channel) then return false,"Colour channel is not available for this structure." end end; for channel,materialId in pairs(type(materials)=="table" and materials or {}) do if channel=="Neon" or not contains(cap.MaterialChannels,channel) or not StyleCatalog().IsMaterial(materialId) or not resolveMaterial(materialId) then return false,"Material channel or material is not available for this structure." end end; return true,cap end
function Runtime.ValidateDecorationFinish(templateId,item,colors) local asset=item and Runtime.DecorationAsset(templateId,item.ZoneId,item.AssetName,item.AssetGroupId); if not asset then return false,"Decoration finish asset is missing." end; local cap=inspect(asset,"Decoration"); if not cap.Available then return false,"Decoration asset is not populated or enabled." end; for channel in pairs(type(colors)=="table" and colors or {}) do if not contains(cap.ColourChannels,channel) then return false,"Colour channel is not available for this decoration." end end; return true,cap end
function Runtime.Apply(model,kind,appearance)
	appearance=type(appearance)=="table" and appearance or {}; local colors=type(appearance.Colors)=="table" and appearance.Colors or {}; local materials=type(appearance.Materials)=="table" and appearance.Materials or {}
	for _,object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then local channel=channelFor(object,model,kind=="Structure"); if channel and colors[channel]~=nil then object.Color=decode(colors[channel]) end; if kind=="Structure" and channel and channel~="Neon" and object:GetAttribute("GarageMaterialLocked")~=true and materials[channel]~=nil then local resolved=resolveMaterial(materials[channel]); if resolved then object.Material=resolved.BaseMaterial; object.MaterialVariant=resolved.MaterialVariant end end
		elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then local channel=channelFor(object,model,false); if channel and colors[channel]~=nil then object.Color=decode(colors[channel]) elseif object:GetAttribute("FollowNeonColor")==true and colors.Neon~=nil then object.Color=decode(colors.Neon) end end
	end; return true
end
function Runtime.CloneAt(asset,anchor,kind,appearance,name) if not (asset and asset:IsA("Model") and anchor and anchor:IsA("BasePart")) then return nil,"Finish asset or slot is missing." end; local model=asset:Clone(); model.Name=tostring(name or asset.Name); for _,object in ipairs(model:GetDescendants()) do if object:IsA("LuaSourceContainer") or object:IsA("ProximityPrompt") or object:IsA("Seat") or object:IsA("VehicleSeat") then object:Destroy() elseif object:IsA("BasePart") then object.CFrame=anchor.CFrame*object.CFrame; object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false end end; Runtime.Apply(model,kind,appearance); return model end
function Runtime.Inspect(asset,kind) return inspect(asset,kind) end
function Runtime.ResolveMaterial(materialId) return clone(resolveMaterial(materialId)) end
function Runtime.ClearCache() cache=setmetatable({},{__mode="k"}); materialCache={} end
return Runtime
