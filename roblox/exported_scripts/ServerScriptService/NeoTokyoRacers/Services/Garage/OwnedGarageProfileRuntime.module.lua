-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V1
-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V2_NAMESPACED
-- NTR_OWNED_GARAGE_STRUCTURE_PROFILE_V1
-- NTR_OWNED_GARAGE_DECORATION_PROFILE_V1
-- NTR_OWNED_GARAGE_LIGHTING_PROFILE_V1
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_PROFILE_V1
-- NTR_OWNED_GARAGE_SHARED_FINISH_PROFILE_V1
-- NTR_OWNED_GARAGE_PHASE13_V1_1_ATTRIBUTE_PLATFORM_PROFILE
-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS
-- NTR_OWNED_GARAGE_PHASE14_V1_LIGHTING_STATE_FOUNDATION
-- NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
-- Resolve lazily so the module can be compiled before the catalog is installed.
local CatalogCache
local function Catalog()
	if not CatalogCache then
		local source=script:FindFirstChild("OwnedGaragePropertyCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGaragePropertyCatalog")
		CatalogCache=require(source)
	end
	return CatalogCache
end
local StyleCatalogCache
local function StyleCatalog()
	if not StyleCatalogCache then
		local source=script:FindFirstChild("OwnedGarageInteriorStyleCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")
		StyleCatalogCache=require(source)
	end
	return StyleCatalogCache
end
local DecorationCatalogCache
local function DecorationCatalog()
	if not DecorationCatalogCache then local source=script:FindFirstChild("OwnedGarageDecorationCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageDecorationCatalog"); DecorationCatalogCache=require(source) end
	return DecorationCatalogCache
end
local FinishRuntimeCache
local function FinishRuntime()
	if not FinishRuntimeCache then FinishRuntimeCache=require(script.Parent:WaitForChild("OwnedGarageFinishRuntime")) end
	return FinishRuntimeCache
end
local LightingCatalogCache
local function LightingCatalog()
	if not LightingCatalogCache then local source=script:FindFirstChild("OwnedGarageLightingCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageLightingCatalog"); LightingCatalogCache=require(source) end
	return LightingCatalogCache
end
local Runtime={SchemaVersion=3}

local function clone(value)
	if type(value)~="table" then return value end
	local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy
end
-- NTR_OWNED_GARAGE_PROFILE_IDENTITY_STABILITY_V1
local function reconcile(target,source)
	if target==source then return target end
	for key in pairs(target) do if source[key]==nil then target[key]=nil end end
	for key,sourceValue in pairs(source) do
		local targetValue=target[key]
		if type(targetValue)=="table" and type(sourceValue)=="table" then reconcile(targetValue,sourceValue) else target[key]=clone(sourceValue) end
	end
	return target
end
local function normalizeInvites(value)
	local result={}; local seen={}; for _,raw in pairs(type(value)=="table" and value or {}) do local id=math.floor(tonumber(raw) or 0); if id>0 and not seen[id] then seen[id]=true; table.insert(result,id) end end; table.sort(result); return result
end
local function defaultProperty(propertyId)
	local display={}; for _,slotId in ipairs(Catalog().SpaceIds(propertyId)) do display[slotId]=false end
	return {Owned=true,DisplaySpaces=display,AccessMode="Private",InvitedUserIds={},Customisation={SurfaceStyles=StyleCatalog().DefaultStyles(),Decorations={}}}
end
function Runtime.DefaultGarage()
	return {SchemaVersion=Runtime.SchemaVersion,Revision=0,TesterResetToken="",ActiveGarageId="STARTER_TWO_BAY",Properties={STARTER_TWO_BAY=defaultProperty("STARTER_TWO_BAY")}}
end
function Runtime.Ensure(profile,reset)
	assert(type(profile)=="table","Profile table required")
	if reset==true or type(profile.OwnedGarage)~="table" or tonumber(profile.OwnedGarage.SchemaVersion)~=Runtime.SchemaVersion then
		local replacement=Runtime.DefaultGarage()
		if type(profile.OwnedGarage)=="table" then reconcile(profile.OwnedGarage,replacement) else profile.OwnedGarage=replacement end
	end
	local garage=profile.OwnedGarage; garage.Properties=type(garage.Properties)=="table" and garage.Properties or {}; garage.Revision=math.max(0,math.floor(tonumber(garage.Revision) or 0)); garage.TesterResetToken=tostring(garage.TesterResetToken or "")
	for _,definition in ipairs(Catalog().List()) do
		local property=garage.Properties[definition.PropertyId]
		if definition.Starter and type(property)~="table" then property=defaultProperty(definition.PropertyId); garage.Properties[definition.PropertyId]=property end
		if type(property)=="table" then
			property.Owned=property.Owned==true; property.DisplaySpaces=type(property.DisplaySpaces)=="table" and property.DisplaySpaces or {}; property.InvitedUserIds=normalizeInvites(property.InvitedUserIds); property.Customisation=type(property.Customisation)=="table" and property.Customisation or {SurfaceStyles={},Decorations={}}
			property.Customisation.SurfaceStyles=type(property.Customisation.SurfaceStyles)=="table" and property.Customisation.SurfaceStyles or {}; property.Customisation.Decorations=DecorationCatalog().Normalize(property.Customisation.Decorations,definition.DecorationSlots); property.Customisation.Lighting=LightingCatalog().Normalize(property.Customisation.Lighting); property.Customisation.Structure=StyleCatalog().NormalizeStructure(property.Customisation.Structure,definition.StructureSections)
			if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then property.AccessMode="Private" end
			for _,slotId in ipairs(definition.DisplaySpaceIds) do if property.DisplaySpaces[slotId]==nil then property.DisplaySpaces[slotId]=false end end
			for slotId in pairs(property.DisplaySpaces) do if not Catalog().IsSpace(definition.PropertyId,slotId) then property.DisplaySpaces[slotId]=nil end end
		end
	end
	if not (garage.Properties[garage.ActiveGarageId] and garage.Properties[garage.ActiveGarageId].Owned) then garage.ActiveGarageId="STARTER_TWO_BAY" end
	return garage
end
function Runtime.Validate(profile)
	local garage=Runtime.Ensure(profile,false); local vehicles=type(profile.Vehicles)=="table" and profile.Vehicles or {}; local seen={}
	for garageId,property in pairs(garage.Properties) do
		if property.Owned then
			if not Catalog().ById(garageId) then return false,"Unknown property "..tostring(garageId) end
			if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then return false,"Invalid access mode: "..tostring(property.AccessMode) end; local inviteSeen={}; for _,userId in ipairs(property.InvitedUserIds or {}) do if userId<=0 or inviteSeen[userId] then return false,"Invalid or duplicate garage invitation." end; inviteSeen[userId]=true end
			local definition=Catalog().ById(garageId); local lightingValid,lightingMessage=LightingCatalog().Validate(property.Customisation.Lighting); if not lightingValid then return false,lightingMessage end; local decorationValid,decorationMessage=DecorationCatalog().Validate(property.Customisation.Decorations,definition and definition.DecorationSlots or {}); if not decorationValid then return false,decorationMessage end; local structureValid,structureMessage=StyleCatalog().ValidateStructure(property.Customisation.Structure,definition and definition.StructureSections or {}); if not structureValid then return false,structureMessage end
			for slotId,vehicleId in pairs(property.DisplaySpaces) do
				if not Catalog().IsSpace(garageId,slotId) then return false,"Unknown display space "..garageId.."/"..slotId end
				if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then
					vehicleId=tostring(vehicleId); if not vehicles[vehicleId] then return false,"Display vehicle missing: "..vehicleId end
					if seen[vehicleId] then return false,"Vehicle displayed twice: "..vehicleId end; seen[vehicleId]=garageId.."/"..slotId
				end
			end
		end
	end
	return true,{Displayed=seen,Revision=garage.Revision}
end
function Runtime.Snapshot(profile) return clone(Runtime.Ensure(profile,false)) end
function Runtime.Restore(profile,snapshot) local garage=Runtime.Ensure(profile,false); reconcile(garage,clone(snapshot)) end
function Runtime.State(profile)
	local garage=Runtime.Ensure(profile,false); local state=clone(garage); state.SchemaVersion=Runtime.SchemaVersion; return state
end
function Runtime.Assign(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local slotId=tostring(args.SlotId or ""); local vehicleId=tostring(args.VehicleId or "")
	local property=garage.Properties[garageId]; if not (property and property.Owned) then return false,"Garage is not owned." end
	if not Catalog().IsSpace(garageId,slotId) then return false,"Display space is invalid." end
	if not (type(profile.Vehicles)=="table" and profile.Vehicles[vehicleId]) then return false,"Vehicle is not owned." end
	for _,other in pairs(garage.Properties) do for otherSlot,assigned in pairs(other.DisplaySpaces or {}) do if tostring(assigned or "")==vehicleId then other.DisplaySpaces[otherSlot]=false end end end
	property.DisplaySpaces[slotId]=vehicleId; garage.Revision+=1
	local valid,message=Runtime.Validate(profile); if not valid then return false,message end
	return true,"Display assignment updated."
end
function Runtime.Clear(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local slotId=tostring(args.SlotId or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned and Catalog().IsSpace(garageId,slotId)) then return false,"Display space is invalid." end
	property.DisplaySpaces[slotId]=false; garage.Revision+=1; return true,"Display space cleared."
end
function Runtime.SetActive(profile,garageId)
	local garage=Runtime.Ensure(profile,false); garageId=tostring(garageId or ""); if not (garage.Properties[garageId] and garage.Properties[garageId].Owned) then return false,"Garage is not owned." end
	garage.ActiveGarageId=garageId; garage.Revision+=1; return true,"Active garage updated."
end
function Runtime.SetSurfaceStyle(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local surfaceGroup=tostring(args.SurfaceGroup or ""); local styleId=tostring(args.StyleId or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned) then return false,"Garage is not owned." end
	if not StyleCatalog().IsValid(surfaceGroup,styleId) then return false,"Interior style is invalid." end
	property.Customisation.SurfaceStyles[surfaceGroup]=styleId; garage.Revision+=1; return true,"Interior style updated."
end
function Runtime.SetAccessMode(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local accessMode=tostring(args.AccessMode or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned) then return false,"Garage is not owned." end
	if accessMode~="Private" and accessMode~="FriendsOnly" and accessMode~="InviteOnly" and accessMode~="Public" then return false,"Access mode is invalid." end
	property.AccessMode=accessMode; garage.Revision+=1; return true,"Access mode updated."
end
function Runtime.SetInvitation(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local targetUserId=math.floor(tonumber(args.TargetUserId) or 0); local ownerUserId=math.floor(tonumber(args.OwnerUserId) or 0); local action=tostring(args.Action or "")
	if not (property and property.Owned) then return false,"Garage is not owned." end; if targetUserId<=0 or targetUserId==ownerUserId then return false,"Invitation target is invalid." end; property.InvitedUserIds=normalizeInvites(property.InvitedUserIds); local index; for i,userId in ipairs(property.InvitedUserIds) do if userId==targetUserId then index=i end end
	local limit=math.clamp(math.floor(tonumber(args.MaxInvites) or 20),1,100)
	if action=="Invite" then if index then return false,"Player is already invited." end; if #property.InvitedUserIds>=limit then return false,"Garage invitation limit reached." end; table.insert(property.InvitedUserIds,targetUserId); table.sort(property.InvitedUserIds)
	elseif action=="Revoke" then if not index then return false,"Player is not invited." end; table.remove(property.InvitedUserIds,index)
	else return false,"Unknown invitation action." end
	garage.Revision+=1; return true,action=="Invite" and "Player invited." or "Invitation revoked."
end
function Runtime.ConfigureStructure(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local definition=Catalog().ById(garageId); local section=tostring(args.SectionId or ""); local action=tostring(args.Action or "")
	if not (property and property.Owned and definition) then return false,"Garage is not owned." end
	local structureState=StyleCatalog().NormalizeStructure(property.Customisation.Structure,definition.StructureSections); property.Customisation.Structure=structureState
	if action=="SetFinishAll" then
		local colors=type(args.Colors)=="table" and args.Colors or {}; local materials=type(args.Materials)=="table" and args.Materials or {}; if next(colors)==nil and next(materials)==nil then return false,"Choose a colour or material before saving." end; local draft=clone(structureState); local affected=0
		for _,targetSection in ipairs(definition.StructureSections or {}) do local selected=draft.Sections[targetSection]; local style=selected and StyleCatalog().ById(targetSection,selected.StyleId); local asset=style and FinishRuntime().StructureAsset(definition.TemplateId,targetSection,style.AssetOption); local capability=asset and FinishRuntime().Inspect(asset,"Structure"); if capability then local targetColors={}; local targetMaterials={}; for channel,value in pairs(colors) do if table.find(capability.ColourChannels or {},channel) then targetColors[channel]=value end end; for channel,value in pairs(materials) do if table.find(capability.MaterialChannels or {},channel) then targetMaterials[channel]=value end end; if next(targetColors) or next(targetMaterials) then local valid,message=FinishRuntime().ValidateStructureFinish(definition.TemplateId,targetSection,style.AssetOption,targetColors,targetMaterials); if not valid then return false,message end; for channel,value in pairs(targetColors) do selected.Colors[channel]=StyleCatalog().EncodeColor(value) end; for channel,value in pairs(targetMaterials) do selected.Materials[channel]=tostring(value) end; StyleCatalog().StoreFinish(draft,targetSection,selected); affected+=1 end end end
		if affected==0 then return false,"No equipped structure supports this finish." end; property.Customisation.Structure=draft; garage.Revision+=1; return true,"Structure finishes updated."
	end
	local validSection=false; for _,id in ipairs(definition.StructureSections or {}) do if id==section then validSection=true end end; if not validSection then return false,"Structure section is invalid." end; local selected=structureState.Sections[section]
	if action=="Purchase" then local style=StyleCatalog().ById(section,args.StyleId); if not style then return false,"Structure style is invalid." end; if structureState.OwnedStyles[style.StyleId] then return false,"Structure style is already owned." end; local cost=math.max(0,math.floor(tonumber(style.Price) or 0)); if (tonumber(profile.Cash) or 0)<cost then return false,"Not enough cash." end; profile.Cash=(tonumber(profile.Cash) or 0)-cost; structureState.OwnedStyles[style.StyleId]=true; selected=StyleCatalog().SelectStyle(structureState,section,style.StyleId)
	elseif action=="Equip" then local style=StyleCatalog().ById(section,args.StyleId); if not (style and structureState.OwnedStyles[style.StyleId]) then return false,"Purchase this structure style first." end; selected=StyleCatalog().SelectStyle(structureState,section,style.StyleId)
	elseif action=="SetFinish" then local style=StyleCatalog().ById(section,selected.StyleId); local colors=type(args.Colors)=="table" and args.Colors or {}; local materials=type(args.Materials)=="table" and args.Materials or {}; local valid,message=FinishRuntime().ValidateStructureFinish(definition.TemplateId,section,style and style.AssetOption,colors,materials); if not valid then return false,message end; for channel,value in pairs(colors) do selected.Colors[channel]=StyleCatalog().EncodeColor(value) end; for channel,value in pairs(materials) do selected.Materials[channel]=tostring(value) end; StyleCatalog().StoreFinish(structureState,section,selected)
	elseif action=="SetColour" then local style=StyleCatalog().ById(section,selected.StyleId); local colors={[tostring(args.Channel or "")]=args.Color}; local valid,message=FinishRuntime().ValidateStructureFinish(definition.TemplateId,section,style and style.AssetOption,colors,{}); if not valid then return false,message end; for channel,value in pairs(colors) do selected.Colors[channel]=StyleCatalog().EncodeColor(value) end; StyleCatalog().StoreFinish(structureState,section,selected)
	elseif action=="SetMaterial" then local style=StyleCatalog().ById(section,selected.StyleId); local materials={[tostring(args.Channel or "")]=tostring(args.Material or "")}; local valid,message=FinishRuntime().ValidateStructureFinish(definition.TemplateId,section,style and style.AssetOption,{},materials); if not valid then return false,message end; for channel,value in pairs(materials) do selected.Materials[channel]=value end; StyleCatalog().StoreFinish(structureState,section,selected)
	else return false,"Unknown structure action." end; garage.Revision+=1; return true,"Structure updated."
end
function Runtime.ConfigureDecoration(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local definition=Catalog().ById(garageId); local action=tostring(args.Action or ""); local slotId=tostring(args.SlotId or args.AnchorId or ""); local itemId=tostring(args.ItemId or "")
	if not (property and property.Owned and definition) then return false,"Garage is not owned." end; local decorations=DecorationCatalog().Normalize(property.Customisation.Decorations,definition.DecorationSlots); property.Customisation.Decorations=decorations
	if action=="SetFinishAll" then local colors=type(args.Colors)=="table" and args.Colors or {}; if next(colors)==nil then return false,"Choose a colour before saving." end; local draft=clone(decorations); local affected=0; for _,slotDefinition in ipairs(definition.DecorationSlots or {}) do local targetSlot=tostring(slotDefinition.SlotId or ""); local placement=draft.Placements[targetSlot]; local item=placement and DecorationCatalog().ById(placement.ItemId); local asset=item and FinishRuntime().DecorationAsset(definition.TemplateId,targetSlot,item.AssetName,item.AssetGroupId or slotDefinition.AssetGroupId); local capability=asset and FinishRuntime().Inspect(asset,"Decoration"); if capability then local targetColors={}; for channel,value in pairs(colors) do if table.find(capability.ColourChannels or {},channel) then targetColors[channel]=value end end; if next(targetColors) then local valid,message=FinishRuntime().ValidateDecorationFinish(definition.TemplateId,item,targetColors); if not valid then return false,message end; for channel,value in pairs(targetColors) do placement.Colors[channel]=DecorationCatalog().EncodeColor(value) end; affected+=1 end end end; if affected==0 then return false,"No installed decoration supports this colour." end; property.Customisation.Decorations=draft; garage.Revision+=1; return true,"Decoration colours updated." end
	local slot=DecorationCatalog().ZoneById(slotId,definition.DecorationSlots); if not slot then return false,"Decoration zone is invalid." end
	if action=="Purchase" or action=="Place" then local item=DecorationCatalog().ById(itemId); if not (item and item.ZoneId==slotId) then return false,"Decoration is not compatible with this zone." end; if not FinishRuntime().IsDecorationAvailable(definition.TemplateId,item) then return false,"Decoration asset is not populated or enabled." end; if action=="Purchase" then if decorations.OwnedItems[itemId] then return false,"Decoration is already owned." end; local cost=math.max(0,math.floor(tonumber(item.Price) or 0)); if (tonumber(profile.Cash) or 0)<cost then return false,"Not enough cash." end; profile.Cash=(tonumber(profile.Cash) or 0)-cost; decorations.OwnedItems[itemId]=true elseif not decorations.OwnedItems[itemId] then return false,"Purchase this decoration first." end; decorations.Placements[slotId]=DecorationCatalog().NewPlacement(itemId)
	elseif action=="Clear" then if slot.Required then return false,"This fixture is required for the garage." end; decorations.Placements[slotId]=nil
	elseif action=="SetFinish" then local placement=decorations.Placements[slotId]; local item=placement and DecorationCatalog().ById(placement.ItemId); if not item then return false,"Place a decoration before customising it." end; local colors=type(args.Colors)=="table" and args.Colors or {}; local valid,message=FinishRuntime().ValidateDecorationFinish(definition.TemplateId,item,colors); if not valid then return false,message end; for channel,value in pairs(colors) do placement.Colors[channel]=DecorationCatalog().EncodeColor(value) end
	else return false,"Unknown decoration action." end; garage.Revision+=1; return true,action=="Clear" and "Decoration removed." or "Decoration updated."
end
function Runtime.ConfigureLighting(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local definition=Catalog().ById(garageId); local action=tostring(args.Action or "")
	if not (property and property.Owned and definition) then return false,"Garage is not owned." end; local lighting=LightingCatalog().Normalize(property.Customisation.Lighting); property.Customisation.Lighting=lighting
	if action=="Purchase" then local preset=LightingCatalog().ById(args.PresetId); if not preset or not FinishRuntime().IsLightingAvailable(definition.TemplateId,preset) then return false,"Lighting option is not available." end; if lighting.OwnedPresets[preset.PresetId] then return false,"Lighting preset is already owned." end; local cost=math.max(0,math.floor(tonumber(preset.Price) or 0)); if (tonumber(profile.Cash) or 0)<cost then return false,"Not enough cash." end; profile.Cash=(tonumber(profile.Cash) or 0)-cost; lighting.OwnedPresets[preset.PresetId]=true; lighting.PresetId=preset.PresetId
	elseif action=="Equip" then local preset=LightingCatalog().ById(args.PresetId); if not (preset and lighting.OwnedPresets[preset.PresetId] and FinishRuntime().IsLightingAvailable(definition.TemplateId,preset)) then return false,"Purchase this lighting option first." end; lighting.PresetId=preset.PresetId
	elseif action=="SetFinish" then local preset=LightingCatalog().ById(args.PresetId or lighting.PresetId); local colors=type(args.Colors)=="table" and args.Colors or {}; if not (preset and preset.PresetId==lighting.PresetId) then return false,"Equip this lighting option before styling it." end; local valid,message=FinishRuntime().ValidateLightingFinish(definition.TemplateId,preset,colors); if not valid then return false,message end; local finish=LightingCatalog().Finish(lighting,preset.PresetId); for channel,value in pairs(colors) do finish.Colors[channel]=LightingCatalog().EncodeColor(value) end
	elseif action=="SetIntensity" then lighting.Intensity=LightingCatalog().Level(args.Intensity).Value
	else return false,"Unknown lighting action." end
	garage.Revision+=1; return true,"Garage lighting updated."
end
function Runtime.NewRequestId() return HttpService:GenerateGUID(false) end
return Runtime
