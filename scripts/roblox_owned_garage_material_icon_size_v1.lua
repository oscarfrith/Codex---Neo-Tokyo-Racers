-- Neo Tokyo Racers - Owned Garage material icon sizing V1
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Adds one isolated material-card artwork zoom config without changing card geometry.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Owned Garage Material Icon Size V1]"
local BASE="NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW"
local REVISION="NTR_OWNED_GARAGE_MATERIAL_ICON_SIZE_V1"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end
local function count(source,needle)
	local result,cursor=0,1
	while true do
		local a,b=source:find(needle,cursor,true)
		if not a then return result end
		result+=1
		cursor=b+1
	end
end
local function replaceOnce(source,needle,replacement,label)
	local matches=count(source,needle)
	assert(matches==1,label.." anchor count was "..matches)
	local a,b=source:find(needle,1,true)
	return source:sub(1,a-1)..replacement..source:sub(b+1)
end
local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local replacement=assert(find(kit,"Config.UI.GarageReplacement"),"GarageReplacement config missing")
local icons=assert(replacement:FindFirstChild("OwnedGarageIcons"),"OwnedGarageIcons missing")
local sizing=assert(icons:FindFirstChild("Sizing"),"OwnedGarageIcons.Sizing missing")
assert(sizing:IsA("Folder"),sizing:GetFullName().." must be a Folder")

local uiRoot=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI controllers missing")
local owned=assert(uiRoot:FindFirstChild("OwnedGarageWorkspaceController"),"OwnedGarageWorkspaceController missing")
assert(owned:IsA("LuaSourceContainer"),owned:GetFullName().." is not a source container")
compile(owned.Source,owned.Name.."_Current")
assert(owned.Source:find(BASE,1,true),"Confirmed Style UX V1 marker missing; refresh the mirror before repairing this installer")

local source=owned.Source
if not source:find(REVISION,1,true) then
	source=replaceOnce(source,"-- "..BASE.."\n","-- "..BASE.."\n-- "..REVISION.."\n","revision")
	source=replaceOnce(
		source,
		'local function locationIconZoom(name) return math.clamp(tonumber(iconSizing:GetAttribute(name)) or categoryCardImageZoom()*2,.2,1.5) end',
		'local function locationIconZoom(name) return math.clamp(tonumber(iconSizing:GetAttribute(name)) or categoryCardImageZoom()*2,.2,1.5) end\n\tlocal function materialIconZoom() return math.clamp(tonumber(iconSizing:GetAttribute("MaterialImageZoom")) or 1,.2,1.5) end',
		"material zoom resolver"
	)
	source=replaceOnce(
		source,
		'Image=scopedIcon("Materials",materialId,"ActionMaterial"),Footer=selected and "SELECTED" or ""',
		'Image=scopedIcon("Materials",materialId,"ActionMaterial"),ImageZoom=materialIconZoom(),Footer=selected and "SELECTED" or ""',
		"material card artwork zoom"
	)
end

compile(source,owned.Name.."_Projected")
assert(source:find('ImageZoom=materialIconZoom()',1,true),"Material cards did not receive the isolated zoom")

local oldSource=owned.Source
local oldRevision=owned:GetAttribute("OwnedGarageMaterialIconSizeRevision")
local oldRunId=owned:GetAttribute("OwnedGarageMaterialIconSizeRunId")
local oldZoom=sizing:GetAttribute("MaterialImageZoom")
local oldContractVersion=icons:GetAttribute("ContractVersion")
local oldIconsRevision=icons:GetAttribute("Revision")
local oldInstallRunId=icons:GetAttribute("InstallRunId")

local ok,problem=pcall(function()
	if sizing:GetAttribute("MaterialImageZoom")==nil then sizing:SetAttribute("MaterialImageZoom",1) end
	local zoom=sizing:GetAttribute("MaterialImageZoom")
	assert(type(zoom)=="number" and zoom>=.2 and zoom<=1.5,"Sizing.MaterialImageZoom must be a number from 0.2 to 1.5")

	if owned.Source~=source then owned.Source=source end
	owned:SetAttribute("OwnedGarageMaterialIconSizeRevision",REVISION)
	owned:SetAttribute("OwnedGarageMaterialIconSizeRunId",RUN_ID)
	icons:SetAttribute("ContractVersion",math.max(4,tonumber(oldContractVersion) or 0))
	icons:SetAttribute("Revision",REVISION)
	icons:SetAttribute("InstallRunId",RUN_ID)

	assert(owned.Source:find(REVISION,1,true),"Source revision did not persist")
	assert(sizing:GetAttribute("MaterialImageZoom")==zoom,"MaterialImageZoom did not persist")
	compile(owned.Source,owned.Name.."_Committed")
end)

if not ok then
	pcall(function()
		owned.Source=oldSource
		owned:SetAttribute("OwnedGarageMaterialIconSizeRevision",oldRevision)
		owned:SetAttribute("OwnedGarageMaterialIconSizeRunId",oldRunId)
		sizing:SetAttribute("MaterialImageZoom",oldZoom)
		icons:SetAttribute("ContractVersion",oldContractVersion)
		icons:SetAttribute("Revision",oldIconsRevision)
		icons:SetAttribute("InstallRunId",oldInstallRunId)
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sourceWrite="..tostring(oldSource~=source).." MaterialImageZoom="..tostring(sizing:GetAttribute("MaterialImageZoom")).." cardGeometryChanged=false runId="..RUN_ID)
print(TAG.." READY: restart Play and tune ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.OwnedGarageIcons.Sizing.MaterialImageZoom from 0.2 to 1.5.")
