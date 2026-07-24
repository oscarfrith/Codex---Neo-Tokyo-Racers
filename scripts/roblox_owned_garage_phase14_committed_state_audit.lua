-- Neo Tokyo Racers - Owned Garage Phase 14 V2.2 committed-state audit
-- Run in Roblox Studio Edit mode after a full Studio restart. Read-only.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this audit in Roblox Studio Edit mode.")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Owned Garage Phase 14 V2.2 Audit]"
local FOUNDATION="NTR_OWNED_GARAGE_PHASE14_V1_LIGHTING_STATE_FOUNDATION"
local REVISION="NTR_OWNED_GARAGE_PHASE14_V2_2_RESPONSIVE_NAVIGATION_CLOSURE"
local function find(root,path) local object=root; for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end; return object end
local function compile(source,name) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local dependencies={
	(assert(find(kit,"Shared.Modules.Data.OwnedGarageLightingCatalog"),"Lighting catalog missing")),
	(assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage.OwnedGarageFinishRuntime"),"Finish runtime missing")),
	(assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage.OwnedGarageProfileRuntime"),"Profile runtime missing")),
	(assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage.OwnedGarageManagementRuntime"),"Management runtime missing")),
}
for _,container in ipairs(dependencies) do assert(container:IsA("LuaSourceContainer"),container:GetFullName().." is not a source container"); local text=container.Source; assert(text:find(FOUNDATION,1,true),container.Name.." Phase 14 foundation marker missing"); compile(text,container.Name) end

local client=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageWorkspaceController"),"Workspace controller missing")
local clientSource=client.Source; assert(clientSource:find(REVISION,1,true),"Workspace V2.2 marker missing"); compile(clientSource,client.Name)
local sharedWorkspace=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageWorkspaceController"),"Shared workspace controller missing")
local sharedSource=sharedWorkspace.Source; assert(sharedSource:find("Shared.ModuleCategoryCard",1,true) and sharedSource:find("ScrollMemory.Category",1,true),"Shared card/scroll renderer contract missing"); compile(sharedSource,sharedWorkspace.Name)

local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
assert(config:GetAttribute("OwnedGarageRevision")==REVISION,"Committed revision attribute missing")
assert(config:GetAttribute("LightingContractVersion")==2,"Lighting contract version missing")
assert(config:GetAttribute("LightingPlacementMode")=="TemplateOrigin","Lighting placement mode missing")
assert(config:GetAttribute("LightingDynamicShadows")==false,"Dynamic lighting shadow policy invalid")
assert(config:GetAttribute("OwnedGarageManagementFlowVersion")==2,"Management flow version missing")
assert(config:GetAttribute("OwnedGarageManagementModes")=="DisplayCars,BuildGarage,StyleGarage","Management modes contract missing")
assert(config:GetAttribute("OwnedGarageCategoryCardImageZoom")==.5,"Shared category-card image zoom missing")
assert(config:GetAttribute("OwnedGarageNavigationContractVersion")==3,"Responsive navigation contract missing")

local root=assert(find(ServerStorage,"NeoTokyoRacers.OwnedGarage.LightingAssets.StarterTwoBay"),"Lighting asset root missing")
local totalParts=0; local totalLights=0
for index=1,4 do
	local name=string.format("LightingOption%02d",index); local model=assert(root:FindFirstChild(name),name.." missing")
	assert(model:IsA("Model") and model:GetAttribute("Available")==true,name.." is unavailable")
	assert(model:GetAttribute("AssetKind")=="Lighting" and model:GetAttribute("TemplateId")=="StarterTwoBay",name.." identity invalid")
	assert(model:GetAttribute("GaragePlacementMode")=="TemplateOrigin" and model:GetAttribute("FinishContractVersion")==1,name.." placement/finish contract invalid")
	local colours=assert(model:FindFirstChild("ColourSlots"),name.." ColourSlots missing"); assert(colours:FindFirstChild("Primary") and colours:FindFirstChild("Secondary"),name.." channels missing"); assert(model:FindFirstChild("Fixed") and model:FindFirstChild("Technical"),name.." fixed/technical folders missing")
	local parts=0
	for _,object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then local channel=tostring(object:GetAttribute("GarageColourChannel") or ""); assert(channel=="Primary" or channel=="Secondary",object:GetFullName().." channel invalid"); assert(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery,object:GetFullName().." runtime-safe properties invalid"); parts+=1
		elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then totalLights+=1 end
	end
	assert(parts>0,name.." has no fixture geometry"); totalParts+=parts
end

local management=dependencies[4].Source
assert(management:find("session.LightingPreview.PresetId==preset.PresetId",1,true),"Lighting preview merge contract missing")
assert(management:find("finishRuntime.LightingCapabilities",1,true),"Lighting capabilities projection missing")
for _,contract in ipairs({"Display Cars","Build Garage","Style Garage","BuildStructure","BuildDecorations","BuildLighting","StyleStructureColour","StyleStructureMaterial","StyleDecorationsColour","StyleLighting"}) do assert(clientSource:find(contract,1,true),"Workspace route/label missing: "..contract) end
assert(clientSource:find("local function railScrollKey()",1,true),"Stable rail-key helper missing")
assert(clientSource:find('return "OwnedGarageRail:Structure"',1,true),"Structure rail-memory key missing")
assert(clientSource:find('return "OwnedGarageRail:Decorations"',1,true),"Decoration rail-memory key missing")
assert(clientSource:find("CategoryScrollKey=railScrollKey()",1,true),"Stable rail-key consumer missing")
assert(clientSource:find('DisplayName="Install Asset"',1,true) and clientSource:find('Footer="OPEN BUILD GARAGE"',1,true),"Empty Style location route missing")
assert(clientSource:find("local function categoryCardImageZoom()",1,true) and clientSource:find("card.ImageZoom=sharedZoom",1,true),"Shared category-card parity missing")
assert(clientSource:find('"BuildStructure",nil,nil,"STRUCTURE PURCHASED AND EQUIPPED"',1,true),"Build structure auto-equip contract missing")
assert(clientSource:find('"BuildDecorations",nil,nil,"DECORATION PURCHASED AND EQUIPPED"',1,true),"Build decoration auto-equip contract missing")
assert(clientSource:find('"BuildLighting",nil,nil,"LIGHTING PURCHASED AND EQUIPPED"',1,true),"Build lighting auto-equip contract missing")
assert(clientSource:find('"StyleLighting",nil,nil,"LIGHTING COLOURS SAVED"',1,true),"Style Lighting SAVE-stay contract missing")
assert(clientSource:find("Colors=subset(pendingStructureColors,colourChannels)",1,true),"Complete structure draft missing")
assert(clientSource:find("Colors=subset(pendingDecorationColors,channels)",1,true),"Complete decoration draft missing")

print(TAG.." COMMITTED STATE PASS sourceWrites=1 dependencies=4 options=4 parts="..totalParts.." lights="..totalLights.." modes=3 singleRail=true stableRailScroll=true emptyStyleRoute=true revision="..REVISION)
print(TAG.." READY FOR PLAY: verify long Structure/Decoration rails keep position across nested pages, empty Style decoration locations route to Build, and desktop/mobile Back/Exit remain correct.")
