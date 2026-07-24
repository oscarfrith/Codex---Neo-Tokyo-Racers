-- Neo Tokyo Racers - Owned Garage Phase 13 V1.4 submission hardening
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Canonical upgrade from the confirmed V1.3 authored-default/material baseline.
-- Production authority is ServerStorage only. This installer never reads an editing copy.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")

local TAG="[NTR Owned Garage Phase 13 V1.4]"
local BASE="NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS"
local REVISION="NTR_OWNED_GARAGE_PHASE13_V1_4_SUBMISSION_HARDENING"
local RUN_ID=HttpService:GenerateGUID(false)
local DISTRICT_BASE=Vector3.new(7000,3200,0)
local GRID_COLUMNS=4
local GRID_SPACING_X=512
local GRID_SPACING_Z=512

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end

local function compileSource(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local function replaceOnce(source,needle,replacement,label)
	local startAt,finishAt=source:find(needle,1,true)
	assert(startAt,label.." anchor missing")
	assert(not source:find(needle,finishAt+1,true),label.." anchor is not unique")
	return source:sub(1,startAt-1)..replacement..source:sub(finishAt+1)
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local finish=assert(garage:FindFirstChild("OwnedGarageFinishRuntime"),"OwnedGarageFinishRuntime missing")
assert(finish:IsA("LuaSourceContainer"),"OwnedGarageFinishRuntime is not a source container")
assert(finish.Source:find(BASE,1,true),"Confirmed V1.3 finish marker missing")
compileSource(finish.Source,finish.Name)

local installedRevision=config:GetAttribute("OwnedGarageRevision")
assert(installedRevision==BASE or installedRevision==REVISION,"Expected confirmed V1.3/V1.4 revision, got "..tostring(installedRevision))

-- Authoritative hierarchy preflight. Editing/scratch libraries are deliberately irrelevant.
local storageRoot=assert(find(ServerStorage,"NeoTokyoRacers.OwnedGarage"),"Authoritative OwnedGarage root missing")
local template=assert(find(storageRoot,"Templates.StarterTwoBay"),"Authoritative StarterTwoBay template missing")
local structureRoot=assert(find(storageRoot,"StructureAssets.StarterTwoBay"),"Authoritative structure assets missing")
local decorationRoot=assert(find(storageRoot,"DecorationAssets.StarterTwoBay"),"Authoritative decoration assets missing")
assert(template:GetAttribute("OwnedGarageTemplateVersion")==2,"Authoritative template contract is not V2")
assert(template:FindFirstChild("TemplateOrigin",true),"Authoritative TemplateOrigin missing")

local collision=assert(template:FindFirstChild("CollisionShell"),"Authoritative CollisionShell missing")
assert(collision:IsA("Model") and tonumber(collision:GetAttribute("CollisionContractVersion"))==1,"Authoritative CollisionShell contract invalid")
local collisionParts=0
for _,part in ipairs(collision:GetDescendants()) do
	if part:IsA("BasePart") then
		assert(part.Anchored and part.CanCollide and not part.CanTouch and part.Transparency==1,part:GetFullName().." collision properties invalid")
		assert(part:GetAttribute("GarageCollisionPart")==true and part:GetAttribute("GarageFinishProtected")==true,part:GetFullName().." collision metadata invalid")
		collisionParts+=1
	end
end
assert(collisionParts>0,"Authoritative CollisionShell has no parts")

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
assert(structureShadowCasters+decorationShadowCasters>0,"No authoritative structure/decoration part has CastShadow enabled; enable it on the major authored geometry before installing")

local platformGroup=assert(decorationRoot:FindFirstChild("DisplayPlatforms"),"Authoritative DisplayPlatforms missing")
local starterPlatform=assert(platformGroup:FindFirstChild("PlatformOption01"),"Authoritative PlatformOption01 missing")
local starterPlatformParts=0
for _,object in ipairs(starterPlatform:GetDescendants()) do if object:IsA("BasePart") then starterPlatformParts+=1 end end
assert(starterPlatform:IsA("Model") and starterPlatform:GetAttribute("Available")==true and starterPlatformParts>0,"Authoritative PlatformOption01 must be populated and available")
assert(starterPlatform:GetAttribute("GaragePlacementMode")=="TemplateOrigin","Authoritative PlatformOption01 placement mode invalid")

local marker="-- "..REVISION.."\n"
local sourceInstalled=finish.Source:find(REVISION,1,true)~=nil
local projected=finish.Source
if not sourceInstalled then
	projected=replaceOnce(projected,"-- "..BASE.."\n","-- "..BASE.."\n"..marker,"V1.4 marker")
	projected=replaceOnce(projected,"; object.CastShadow=false","","forced asset shadow disable")
end
assert(projected:find(REVISION,1,true),"Projected V1.4 marker missing")
assert(not projected:find("object.CastShadow=false",1,true),"Forced asset shadow disable remains")
compileSource(projected,finish.Name.."_Projected")

local sourceSnapshot=finish.Source
local attributeSnapshots={}
local function setTrackedAttribute(object,name,value)
	local objectSnapshot=attributeSnapshots[object]
	if not objectSnapshot then objectSnapshot={}; attributeSnapshots[object]=objectSnapshot end
	if not objectSnapshot[name] then objectSnapshot[name]={Value=object:GetAttribute(name)} end
	object:SetAttribute(name,value)
end
local function restoreAttributes()
	for object,attributes in pairs(attributeSnapshots) do for name,snapshot in pairs(attributes) do pcall(function() object:SetAttribute(name,snapshot.Value) end) end end
end

local ok,problem=pcall(function()
	if not sourceInstalled then finish.Source=projected end
	assert(finish.Source:find(REVISION,1,true),"V1.4 source marker did not persist")
	assert(not finish.Source:find("object.CastShadow=false",1,true),"Authored shadow policy did not persist")
	compileSource(finish.Source,finish.Name)

	setTrackedAttribute(finish,"OwnedGarageRevision",REVISION)
	setTrackedAttribute(finish,"OwnedGarageInstallRunId",RUN_ID)
	setTrackedAttribute(config,"OwnedGarageRevision",REVISION)
	setTrackedAttribute(config,"OwnedGarageInstallRunId",RUN_ID)
	setTrackedAttribute(config,"InteriorDistrictContractVersion",1)
	setTrackedAttribute(config,"AssetShadowPolicy","Authored")
	setTrackedAttribute(config,"InteriorBasePosition",DISTRICT_BASE)
	setTrackedAttribute(config,"GridColumns",GRID_COLUMNS)
	setTrackedAttribute(config,"GridSpacingX",GRID_SPACING_X)
	setTrackedAttribute(config,"GridSpacingZ",GRID_SPACING_Z)

	assert(config:GetAttribute("InteriorBasePosition")==DISTRICT_BASE,"Interior district base did not persist")
	assert(config:GetAttribute("GridColumns")==GRID_COLUMNS,"Interior grid columns did not persist")
	assert(config:GetAttribute("GridSpacingX")==GRID_SPACING_X and config:GetAttribute("GridSpacingZ")==GRID_SPACING_Z,"Interior grid spacing did not persist")
	assert(config:GetAttribute("AssetShadowPolicy")=="Authored","Asset shadow policy did not persist")
end)
if not ok then
	pcall(function() finish.Source=sourceSnapshot end)
	restoreAttributes()
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sourceWrites="..(sourceInstalled and "0" or "1").." authority=ServerStorage shadowPolicy=Authored districtBase="..tostring(DISTRICT_BASE).." grid=4x512x512 revision="..REVISION.." runId="..RUN_ID)
print(TAG.." ASSET AUDIT structure="..structureAssets.."/"..structureParts.." decoration="..decorationAssets.."/"..decorationParts.." authoredShadowCasters="..(structureShadowCasters+decorationShadowCasters).." collisionParts="..collisionParts.." starterPlatformParts="..starterPlatformParts)
print(TAG.." NOTE: dynamic Light.Shadows remains unchanged/off; this revision preserves only each placed BasePart's authored CastShadow property.")
