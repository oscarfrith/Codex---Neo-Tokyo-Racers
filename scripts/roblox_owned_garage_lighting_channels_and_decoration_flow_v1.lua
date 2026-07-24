-- Neo Tokyo Racers - Owned Garage lighting channels and Decoration Style flow V1
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Folder ancestry becomes the canonical colour-channel contract, legacy lighting
-- metadata is removed from canonical folders, and Decoration Style opens the
-- existing shared colour sliders directly.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Owned Garage Lighting Channels + Decoration Flow V1]"
local REVISION="NTR_OWNED_GARAGE_LIGHTING_CHANNELS_DECORATION_FLOW_V1"
local WORKSPACE_BASE="NTR_OWNED_GARAGE_MATERIAL_ICON_SIZE_V1"
local FINISH_BASE="NTR_OWNED_GARAGE_PHASE14_V1_LIGHTING_STATE_FOUNDATION"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do
		object=object and object:FindFirstChild(segment)
	end
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

local function replaceBetween(source,first,last,replacement,label)
	local firstCount=count(source,first)
	local lastCount=count(source,last)
	assert(firstCount==1 and lastCount==1,label.." boundary counts were "..firstCount.."/"..lastCount)
	local a=assert(source:find(first,1,true))
	local b=assert(source:find(last,a+#first,true))
	return source:sub(1,a-1)..replacement..source:sub(b)
end

local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"ReplicatedStorage.NeoTokyoRacers missing")
local uiRoot=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI controllers missing")
local garageRoot=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Server garage services missing")
local workspaceController=assert(uiRoot:FindFirstChild("OwnedGarageWorkspaceController"),"OwnedGarageWorkspaceController missing")
local finishRuntime=assert(garageRoot:FindFirstChild("OwnedGarageFinishRuntime"),"OwnedGarageFinishRuntime missing")
local assets=assert(find(ServerStorage,"NeoTokyoRacers.OwnedGarage.LightingAssets"),"Authoritative OwnedGarage LightingAssets missing")
local replacement=assert(find(kit,"Config.UI.GarageReplacement"),"GarageReplacement config missing")
local icons=assert(replacement:FindFirstChild("OwnedGarageIcons"),"OwnedGarageIcons missing")
local navigation=assert(icons:FindFirstChild("Navigation"),"OwnedGarageIcons.Navigation missing")
local saveIcon=navigation:GetAttribute("Save")
assert(type(saveIcon)=="string" and saveIcon~="","OwnedGarageIcons.Navigation Save attribute is missing or blank")

for _,container in ipairs({workspaceController,finishRuntime}) do
	assert(container:IsA("LuaSourceContainer"),container:GetFullName().." is not a source container")
	compile(container.Source,container.Name.."_Current")
end
assert(workspaceController.Source:find(WORKSPACE_BASE,1,true),"Fresh material-icon workspace baseline missing; refresh the mirror")
assert(finishRuntime.Source:find(FINISH_BASE,1,true),"Confirmed Phase 14 finish baseline missing; refresh the mirror")

local function projectFinish(source)
	if source:find(REVISION,1,true) then return source end
	source=replaceOnce(source,"-- "..FINISH_BASE.."\n","-- "..FINISH_BASE.."\n-- "..REVISION.."\n","finish revision")
	source=replaceOnce(
		source,
		'local function channelFor(part,root,legacy) local direct=tostring(part:GetAttribute("GarageColourChannel") or (legacy and part:GetAttribute("StructureChannel")) or ""); if known[direct] then return direct end; local object=part.Parent; while object and object~=root do if known[object.Name] and object.Parent and object.Parent.Name=="ColourSlots" then return object.Name end; object=object.Parent end end',
		[==[local function channelFor(object,root,legacy)
	local cursor=object
	while cursor and cursor~=root do
		if (cursor.Name=="Fixed" or cursor.Name=="Technical") and cursor.Parent==root then return nil end
		if known[cursor.Name] and cursor.Parent and cursor.Parent.Name=="ColourSlots" then return cursor.Name end
		cursor=cursor.Parent
	end
	local direct=tostring(object:GetAttribute("GarageColourChannel") or (legacy and object:GetAttribute("StructureChannel")) or "")
	if known[direct] then return direct end
end]==],
		"folder-first channel resolver"
	)
	source=replaceBetween(
		source,
		"local function inspect(asset,kind)",
		"local function root()",
		[==[local function inspect(asset,kind)
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
]==],
		"light-aware capability inspection"
	)
	return source
end

local function projectWorkspace(source)
	if source:find(REVISION,1,true) then return source end
	source=replaceOnce(source,"-- "..WORKSPACE_BASE.."\n","-- "..WORKSPACE_BASE.."\n-- "..REVISION.."\n","workspace revision")
	source=replaceOnce(
		source,
		"\tlocal function locationTabs()\n",
		[==[	local function beginDecorationStyle(anchor)
		selectedDecorationAnchor=anchor
		selectedDecorationItem=nil
		pendingDecorationColors=nil
		local decorations=state and state.Decorations or {}
		local all=anchor=="__ALL_DECORATIONS"
		local placement=not all and decorations.Placements and decorations.Placements[anchor]
		local placements={}
		if all then for _,entry in pairs(decorations.Placements or {}) do if entry then table.insert(placements,entry) end end else placements={placement} end
		local channels=all and union(placements,"ColourChannels") or (placement and placement.ColourChannels or {})
		if (all or placement) and #channels>0 then
			selectedChannel=first(channels,"Primary")
			if all then pendingDecorationColors=aggregate(placements,"Colors",channels) else pendingDecorationColors=copy(placement.Colors or {}) end
			page="StyleDecorationsColour"
		else
			page="StyleDecorations"
		end
	end
	local function locationTabs()
]==],
		"direct decoration style helper"
	)
	source=replaceOnce(
		source,
		'OnSelect=function() request("CancelDecorationPreview",{}); selectedDecorationAnchor="__ALL_DECORATIONS"; pendingDecorationColors=nil; page="StyleDecorations"; render(true) end',
		'OnSelect=function() request("CancelDecorationPreview",{}); beginDecorationStyle("__ALL_DECORATIONS"); render(true) end',
		"all decorations direct editor"
	)
	source=replaceOnce(
		source,
		'OnSelect=function() request("CancelDecorationPreview",{}); selectedDecorationAnchor=zone.SlotId; selectedDecorationItem=nil; pendingDecorationColors=nil; if styleMode then page="StyleDecorations" else page="BuildDecorations" end; render(true) end',
		'OnSelect=function() request("CancelDecorationPreview",{}); if styleMode then beginDecorationStyle(zone.SlotId) else selectedDecorationAnchor=zone.SlotId; selectedDecorationItem=nil; pendingDecorationColors=nil; page="BuildDecorations" end; render(true) end',
		"decoration location direct editor"
	)
	source=replaceOnce(
		source,
		'OnSelect=function() selectedDecorationItem=nil; pendingDecorationColors=nil; if build then local zones=state.Decorations and state.Decorations.Zones or {}; selectedDecorationAnchor=selectedDecorationAnchor or (zones[1] and zones[1].SlotId); page="BuildDecorations" else selectedDecorationAnchor="__ALL_DECORATIONS"; page="StyleDecorations" end; render(true) end',
		'OnSelect=function() selectedDecorationItem=nil; pendingDecorationColors=nil; if build then local zones=state.Decorations and state.Decorations.Zones or {}; selectedDecorationAnchor=selectedDecorationAnchor or (zones[1] and zones[1].SlotId); page="BuildDecorations" else beginDecorationStyle("__ALL_DECORATIONS") end; render(true) end',
		"decoration family direct editor"
	)
	source=replaceOnce(
		source,
		'if page=="StyleDecorationsColour" then page="StyleDecorations" else selectedDecorationAnchor="__ALL_DECORATIONS"; page="Style" end',
		'selectedDecorationAnchor="__ALL_DECORATIONS"; page="Style"',
		"decoration editor back route"
	)
	source=replaceOnce(
		source,
		'view.NextVisible=true; view.NextText="SAVE"; view.OnNext=function() operate("ConfigureLighting"',
		'view.NextVisible=true; view.NextText="SAVE"; view.NextIcon=namedIcon("NavigationSave"); view.OnNext=function() operate("ConfigureLighting"',
		"lighting save icon"
	)
	return source
end

local projectedFinish=projectFinish(finishRuntime.Source)
local projectedWorkspace=projectWorkspace(workspaceController.Source)
compile(projectedFinish,finishRuntime.Name.."_Projected")
compile(projectedWorkspace,workspaceController.Name.."_Projected")

assert(projectedFinish:find(REVISION,1,true),"Finish revision missing from projection")
assert(projectedFinish:find('cursor.Name=="Fixed" or cursor.Name=="Technical"',1,true),"Protected-folder rule missing")
assert(projectedFinish:find('object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight")',1,true),"Supported-light inspection missing")
assert(projectedWorkspace:find("beginDecorationStyle",1,true),"Direct Decoration Style routing missing")
assert(projectedWorkspace:find('view.NextIcon=namedIcon("NavigationSave"); view.OnNext=function() operate("ConfigureLighting"',1,true),"Lighting Save icon missing")

local canonicalBranches={Primary=true,Secondary=true,Detail=true,Neon=true,Fixed=true,Technical=true}
local metadataSnapshots={}
local optionCount=0
local legacyModelCount=0
local primaryObjects=0
local secondaryObjects=0
local fixedObjects=0
local technicalObjects=0

local function canonicalBranchFor(object,option)
	local cursor=object
	while cursor and cursor~=option do
		if (cursor.Name=="Fixed" or cursor.Name=="Technical") and cursor.Parent==option then return cursor.Name end
		if canonicalBranches[cursor.Name] and cursor.Parent and cursor.Parent.Name=="ColourSlots" and cursor.Parent.Parent==option then return cursor.Name end
		cursor=cursor.Parent
	end
end

for _,template in ipairs(assets:GetChildren()) do
	if template:IsA("Folder") or template:IsA("Model") then
		for _,option in ipairs(template:GetChildren()) do
			if option:IsA("Model") and option:FindFirstChild("ColourSlots") then
				optionCount+=1
				local colourSlots=assert(option:FindFirstChild("ColourSlots"),option:GetFullName()..".ColourSlots missing")
				assert(colourSlots:IsA("Folder"),colourSlots:GetFullName().." must be a Folder")
				for _,channel in ipairs({"Primary","Secondary"}) do
					local folder=assert(colourSlots:FindFirstChild(channel),colourSlots:GetFullName().."."..channel.." missing")
					assert(folder:IsA("Folder"),folder:GetFullName().." must be a Folder")
				end
				for _,protectedName in ipairs({"Fixed","Technical"}) do
					local folder=assert(option:FindFirstChild(protectedName),option:GetFullName().."."..protectedName.." missing")
					assert(folder:IsA("Folder"),folder:GetFullName().." must be a Folder")
				end
				for _,object in ipairs(option:GetDescendants()) do
					local branch=canonicalBranchFor(object,option)
					if branch then
						table.insert(metadataSnapshots,{
							Object=object,
							GarageColourChannel=object:GetAttribute("GarageColourChannel"),
							LightingChannel=object:GetAttribute("LightingChannel"),
						})
						if branch=="Primary" then primaryObjects+=1 elseif branch=="Secondary" then secondaryObjects+=1 elseif branch=="Fixed" then fixedObjects+=1 else technicalObjects+=1 end
					end
				end
			elseif option:IsA("Model") then
				legacyModelCount+=1
			end
		end
	end
end
assert(optionCount>0,"No authoritative lighting option models found")
assert(primaryObjects>0,"No Primary lighting content found")

local oldFinishSource=finishRuntime.Source
local oldWorkspaceSource=workspaceController.Source
local oldFinishRevision=finishRuntime:GetAttribute("OwnedGarageLightingChannelRevision")
local oldFinishRunId=finishRuntime:GetAttribute("OwnedGarageLightingChannelRunId")
local oldWorkspaceRevision=workspaceController:GetAttribute("OwnedGarageLightingChannelRevision")
local oldWorkspaceRunId=workspaceController:GetAttribute("OwnedGarageLightingChannelRunId")
local oldAssetsRevision=assets:GetAttribute("LightingChannelContractRevision")
local oldAssetsRunId=assets:GetAttribute("LightingChannelContractRunId")

local function restore()
	finishRuntime.Source=oldFinishSource
	workspaceController.Source=oldWorkspaceSource
	finishRuntime:SetAttribute("OwnedGarageLightingChannelRevision",oldFinishRevision)
	finishRuntime:SetAttribute("OwnedGarageLightingChannelRunId",oldFinishRunId)
	workspaceController:SetAttribute("OwnedGarageLightingChannelRevision",oldWorkspaceRevision)
	workspaceController:SetAttribute("OwnedGarageLightingChannelRunId",oldWorkspaceRunId)
	assets:SetAttribute("LightingChannelContractRevision",oldAssetsRevision)
	assets:SetAttribute("LightingChannelContractRunId",oldAssetsRunId)
	for _,snapshot in ipairs(metadataSnapshots) do
		snapshot.Object:SetAttribute("GarageColourChannel",snapshot.GarageColourChannel)
		snapshot.Object:SetAttribute("LightingChannel",snapshot.LightingChannel)
	end
end

local ok,problem=pcall(function()
	if finishRuntime.Source~=projectedFinish then finishRuntime.Source=projectedFinish end
	if workspaceController.Source~=projectedWorkspace then workspaceController.Source=projectedWorkspace end

	for _,snapshot in ipairs(metadataSnapshots) do
		snapshot.Object:SetAttribute("GarageColourChannel",nil)
		snapshot.Object:SetAttribute("LightingChannel",nil)
	end

	finishRuntime:SetAttribute("OwnedGarageLightingChannelRevision",REVISION)
	finishRuntime:SetAttribute("OwnedGarageLightingChannelRunId",RUN_ID)
	workspaceController:SetAttribute("OwnedGarageLightingChannelRevision",REVISION)
	workspaceController:SetAttribute("OwnedGarageLightingChannelRunId",RUN_ID)
	assets:SetAttribute("LightingChannelContractRevision",REVISION)
	assets:SetAttribute("LightingChannelContractRunId",RUN_ID)

	compile(finishRuntime.Source,finishRuntime.Name.."_Committed")
	compile(workspaceController.Source,workspaceController.Name.."_Committed")
	assert(finishRuntime.Source:find(REVISION,1,true),"Committed finish revision missing")
	assert(workspaceController.Source:find(REVISION,1,true),"Committed workspace revision missing")
	assert(finishRuntime:GetAttribute("OwnedGarageLightingChannelRevision")==REVISION,"Finish revision attribute did not persist")
	assert(workspaceController:GetAttribute("OwnedGarageLightingChannelRevision")==REVISION,"Workspace revision attribute did not persist")
	assert(assets:GetAttribute("LightingChannelContractRevision")==REVISION,"Lighting asset contract revision did not persist")
	local committedSaveIcon=navigation:GetAttribute("Save")
	assert(type(committedSaveIcon)=="string" and committedSaveIcon~="","OwnedGarageIcons.Navigation Save attribute became missing or blank")

	for _,snapshot in ipairs(metadataSnapshots) do
		assert(snapshot.Object:GetAttribute("GarageColourChannel")==nil,snapshot.Object:GetFullName().." still has GarageColourChannel")
		assert(snapshot.Object:GetAttribute("LightingChannel")==nil,snapshot.Object:GetFullName().." still has LightingChannel")
	end
end)

if not ok then
	pcall(restore)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sourceWrites="..tostring((oldFinishSource~=projectedFinish and 1 or 0)+(oldWorkspaceSource~=projectedWorkspace and 1 or 0)).." options="..optionCount.." legacyModelsIgnored="..legacyModelCount.." canonicalObjects="..#metadataSnapshots.." primary="..primaryObjects.." secondary="..secondaryObjects.." fixed="..fixedObjects.." technical="..technicalObjects.." runId="..RUN_ID)
print(TAG.." READY: restart Studio, then verify Fixed housings retain authored colours, populated channels recolour both neon parts and attached lights, empty Secondary is hidden, Decoration Style opens sliders directly, and Lighting SAVE shows its icon.")
