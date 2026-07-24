-- Neo Tokyo Racers - Owned Garage Phase 13 V1.4 committed-state audit
-- Read-only. Run in Studio Edit mode after restarting Studio following V1.4 installation.
-- Production verification is intentionally authoritative-ServerStorage-only.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this audit in Roblox Studio Edit mode.")

local MaterialService=game:GetService("MaterialService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Owned Garage Phase 13 V1.4 Audit]"
local BASE="NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS"
local REVISION="NTR_OWNED_GARAGE_PHASE13_V1_4_SUBMISSION_HARDENING"
local DISTRICT_BASE=Vector3.new(7000,3200,0)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end

local function compile(object)
	local fn,problem=loadstring(object.Source,"="..object.Name)
	assert(fn,object:GetFullName().." compile failed: "..tostring(problem))
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data modules missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Owned garage UI root missing")
local finish=assert(garage:FindFirstChild("OwnedGarageFinishRuntime"),"OwnedGarageFinishRuntime missing")

local v13Contracts={
	assert(data:FindFirstChild("OwnedGaragePropertyCatalog")),
	assert(data:FindFirstChild("OwnedGarageInteriorStyleCatalog")),
	assert(data:FindFirstChild("OwnedGarageDecorationCatalog")),
	finish,
	assert(garage:FindFirstChild("OwnedGarageProfileRuntime")),
	assert(garage:FindFirstChild("OwnedGarageManagementRuntime")),
	assert(ui:FindFirstChild("GarageWorkspaceController")),
	assert(ui:FindFirstChild("OwnedGarageWorkspaceController")),
}
for _,object in ipairs(v13Contracts) do assert(object.Source:find(BASE,1,true),object:GetFullName().." V1.3 source contract missing"); compile(object) end
assert(finish.Source:find(REVISION,1,true),"Finish runtime V1.4 marker missing")
assert(finish:GetAttribute("OwnedGarageRevision")==REVISION,"Finish runtime V1.4 revision attribute missing")
assert(not finish.Source:find("object.CastShadow=false",1,true),"Finish runtime still forces placed asset shadows off")

local historicalContracts={
	{assert(garage:FindFirstChild("OwnedGarageManagementRuntime")),"NTR_OWNED_GARAGE_PHASE13_V1_2_STREAMING_HANDSHAKE"},
	{assert(garage:FindFirstChild("OwnedGarageInteriorRuntime")),"NTR_OWNED_GARAGE_PHASE13_V1_2_COLLISION_CONTRACT"},
	{assert(ui:FindFirstChild("OwnedGarageBrowserController")),"NTR_OWNED_GARAGE_PHASE13_V1_2_STREAMING_CLIENT"},
}
for _,contract in ipairs(historicalContracts) do assert(contract[1].Source:find(contract[2],1,true),contract[1]:GetFullName().." source contract missing: "..contract[2]); compile(contract[1]) end

assert(config:GetAttribute("OwnedGarageRevision")==REVISION,"Config V1.4 revision not committed")
assert(config:GetAttribute("TemplateContractVersion")==2,"Template contract is not 2")
assert(config:GetAttribute("DefinitionVersion")==6,"Definition version is not 6")
assert(config:GetAttribute("StateApiVersion")==6 and config:GetAttribute("StateSchemaVersion")==4,"State API/schema contract invalid")
assert(config:GetAttribute("FinishContractVersion")==2 and config:GetAttribute("CollisionContractVersion")==1,"Finish/collision contract invalid")
assert(config:GetAttribute("InteriorDistrictContractVersion")==1,"Interior district contract missing")
assert(config:GetAttribute("AssetShadowPolicy")=="Authored","Asset shadow policy is not Authored")
assert(config:GetAttribute("InteriorBasePosition")==DISTRICT_BASE,"Interior district base invalid")
assert(config:GetAttribute("GridColumns")==4,"Interior grid columns invalid")
assert(config:GetAttribute("GridSpacingX")==512 and config:GetAttribute("GridSpacingZ")==512,"Interior grid spacing invalid")
assert(tonumber(config:GetAttribute("MaxActiveInteriorsPerServer"))<=24,"Active interior budget exceeds confirmed cap")
assert(tonumber(config:GetAttribute("GarageStreamTimeoutSeconds"))==8,"Garage stream timeout changed")

local storageRoot=assert(find(ServerStorage,"NeoTokyoRacers.OwnedGarage"),"Authoritative OwnedGarage root missing")
local template=assert(find(storageRoot,"Templates.StarterTwoBay"),"Authoritative StarterTwoBay template missing")
local structureRoot=assert(find(storageRoot,"StructureAssets.StarterTwoBay"),"Authoritative structure assets missing")
local decorationRoot=assert(find(storageRoot,"DecorationAssets.StarterTwoBay"),"Authoritative decoration assets missing")
assert(template:GetAttribute("OwnedGarageTemplateVersion")==2,"Authoritative template version invalid")
assert(template:FindFirstChild("TemplateOrigin",true),"Authoritative TemplateOrigin missing")
for _,object in ipairs(template:GetDescendants()) do
	if object:IsA("BasePart") and (object.Name:sub(1,11)=="DisplayPad_" or object.Name:sub(1,15)=="DisplayPadNeon_") then assert(object:GetAttribute("SurfaceGroup")=="DisplayPads",object:GetFullName().." display-pad SurfaceGroup missing") end
end

local collision=assert(template:FindFirstChild("CollisionShell"),"Authoritative CollisionShell missing")
assert(collision:IsA("Model") and tonumber(collision:GetAttribute("CollisionContractVersion"))==1,"Authoritative CollisionShell contract invalid")
local collisionParts=0; local collisionFloorParts=0
for _,part in ipairs(collision:GetDescendants()) do
	if part:IsA("BasePart") then
		assert(part.Anchored and part.CanCollide and not part.CanTouch and part.Transparency==1,part:GetFullName().." collision properties invalid")
		assert(part:GetAttribute("GarageCollisionPart")==true and part:GetAttribute("GarageFinishProtected")==true,part:GetFullName().." collision metadata invalid")
		assert(part:GetAttribute("GarageColourChannel")==nil and part:GetAttribute("SurfaceGroup")==nil,part:GetFullName().." collision part participates in customisation")
		collisionParts+=1; if part:GetAttribute("GarageCollisionSourceSection")=="Floor" then collisionFloorParts+=1 end
	end
end
assert(collisionParts>0 and collisionFloorParts>0,"Authoritative CollisionShell has no protected floor")

local channels={Primary=true,Secondary=true,Detail=true,Neon=true}
local function hierarchyChannel(object,asset)
	local cursor=object.Parent
	while cursor and cursor~=asset do
		if cursor.Parent and cursor.Parent.Name=="ColourSlots" and channels[cursor.Name] then return cursor.Name end
		cursor=cursor.Parent
	end
end

local function auditAssets(root,kind)
	local assets=0; local parts=0; local shadowCasters=0
	for _,owner in ipairs(root:GetChildren()) do
		if owner:IsA("Folder") then
			for _,asset in ipairs(owner:GetChildren()) do
				if asset:IsA("Model") then
					assets+=1
					assert(asset:GetAttribute("EditableTemplate")==true,asset:GetFullName().." editable flag missing")
					assert(asset:GetAttribute("FinishContractVersion")==1,asset:GetFullName().." finish contract invalid")
					assert(asset:GetAttribute("AssetKind")==kind,asset:GetFullName().." AssetKind invalid")
					assert(asset:GetAttribute("TemplateId")=="StarterTwoBay",asset:GetFullName().." TemplateId invalid")
					assert(asset:GetAttribute(kind=="Structure" and "SectionId" or "SlotId")==owner.Name,asset:GetFullName().." owner id invalid")
					assert(asset:FindFirstChild("ColourSlots") and asset:FindFirstChild("Fixed") and asset:FindFirstChild("Technical"),asset:GetFullName().." finish folders missing")
					for _,object in ipairs(asset:GetDescendants()) do
						if object:IsA("BasePart") then
							parts+=1; if object.CastShadow then shadowCasters+=1 end
							local channel=hierarchyChannel(object,asset)
							if channel then assert(object:GetAttribute("GarageColourChannel")==channel,object:GetFullName().." channel metadata invalid") else assert(object:GetAttribute("GarageFinishProtected")==true,object:GetFullName().." protection metadata invalid") end
						end
					end
				end
			end
		end
	end
	return assets,parts,shadowCasters
end

local structureAssets,structureParts,structureShadowCasters=auditAssets(structureRoot,"Structure")
local decorationAssets,decorationParts,decorationShadowCasters=auditAssets(decorationRoot,"Decoration")
assert(structureAssets>0 and decorationAssets>0,"Authoritative finish assets are empty")
assert(structureShadowCasters+decorationShadowCasters>0,"No authoritative structure/decoration part has authored CastShadow enabled")

local platformGroup=assert(decorationRoot:FindFirstChild("DisplayPlatforms"),"Authoritative DisplayPlatforms missing")
local starterPlatformParts=0
for index=1,3 do
	local asset=assert(platformGroup:FindFirstChild(string.format("PlatformOption%02d",index)),platformGroup:GetFullName().." platform option missing")
	assert(asset:IsA("Model") and asset:GetAttribute("GaragePlacementMode")=="TemplateOrigin",asset:GetFullName().." placement contract invalid")
	local partCount=0; for _,object in ipairs(asset:GetDescendants()) do if object:IsA("BasePart") then partCount+=1 end end
	if index==1 then assert(asset:GetAttribute("Available")==true and partCount>0,asset:GetFullName().." starter platform unavailable"); starterPlatformParts=partCount elseif partCount==0 then assert(asset:GetAttribute("Available")==false,asset:GetFullName().." empty platform must remain unavailable") end
end

local variantNames={"Asphalt New","Plywood","Tiles Rectangular Horizontal (Small)","Tiles Rectangular Small","Tiles Rectangular Vertical (Small)","Tiles Square Large","Tiles Square Small"}
local function materialVariant(name) for _,child in ipairs(MaterialService:GetChildren()) do if child:IsA("MaterialVariant") and child.Name==name then return child end end; for _,baseMaterial in ipairs(Enum.Material:GetEnumItems()) do local ok,result=pcall(MaterialService.GetMaterialVariant,MaterialService,baseMaterial,name); if ok and result then return result end end end
for _,name in ipairs(variantNames) do assert(materialVariant(name),"MaterialVariant missing: "..name) end

assert(data.OwnedGaragePropertyCatalog.Source:find('StarterItemId="PLATFORM_OPTION_01"',1,true),"Starter platform definition missing")
assert(data.OwnedGarageDecorationCatalog.Source:find("StarterLoadoutVersion=1",1,true),"Starter loadout version missing")
assert(data.OwnedGarageInteriorStyleCatalog.Source:find('DisplayName="Tiles F"',1,true),"Material registry incomplete")
assert(garage.OwnedGarageProfileRuntime.Source:find("SchemaVersion=3",1,true),"Owned garage profile schema is not 3")
assert(garage.OwnedGarageManagementRuntime.Source:find("object.Shadows=false",1,true),"Dynamic garage light shadows are no longer bounded off")

print(TAG.." COMMITTED STATE PASS sourceWrites=0 authority=ServerStorage sourceContracts=11 shadowPolicy=Authored authoredShadowCasters="..(structureShadowCasters+decorationShadowCasters).." districtBase="..tostring(DISTRICT_BASE).." grid=4x512x512 collisionParts="..collisionParts.." starterPlatformParts="..starterPlatformParts.." structure="..structureAssets.."/"..structureParts.." decoration="..decorationAssets.."/"..decorationParts)
print(TAG.." READY: verify authored geometry shadows, two-player garage isolation, mobile performance and all four entry/exit paths.")
