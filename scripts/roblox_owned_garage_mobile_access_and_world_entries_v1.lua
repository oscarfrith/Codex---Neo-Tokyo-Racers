-- Neo Tokyo Racers - Owned Garage mobile access HUD and world entries V1
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Scales the existing access/invite HUD as one unit on touch devices and adds
-- movable foot/drive-in entry markers that open the existing garage browser.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local Workspace=game:GetService("Workspace")

local TAG="[NTR Owned Garage Mobile Access + World Entries V1]"
local REVISION="NTR_OWNED_GARAGE_MOBILE_ACCESS_WORLD_ENTRIES_V1"
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
	assert(type(source)=="string","replaceOnce source must be a string for "..tostring(label))
	assert(type(needle)=="string","replaceOnce needle must be a string for "..tostring(label))
	assert(type(replacement)=="string","replaceOnce replacement must be a string for "..tostring(label))
	local matches=count(source,needle)
	assert(matches==1,tostring(label).." anchor count was "..tostring(matches).."; refresh and inspect the mirror instead of bypassing this guard")
	local a,b=source:find(needle,1,true)
	return source:sub(1,a-1)..replacement..source:sub(b+1)
end

local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"ReplicatedStorage.NeoTokyoRacers missing")
local settings=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")
local uiRoot=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI controllers missing")
local interior=assert(uiRoot:FindFirstChild("GarageInteriorModeController"),"GarageInteriorModeController missing")
local browser=assert(uiRoot:FindFirstChild("OwnedGarageBrowserController"),"OwnedGarageBrowserController missing")
assert(interior:IsA("LuaSourceContainer"),interior:GetFullName().." is not a source container")
assert(browser:IsA("LuaSourceContainer"),browser:GetFullName().." is not a source container")
compile(interior.Source,interior.Name.."_Current")
compile(browser.Source,browser.Name.."_Current")

local interiorSource=interior.Source
if not interiorSource:find(REVISION,1,true) then
	interiorSource=replaceOnce(
		interiorSource,
		"-- NTR_OWNED_GARAGE_ICON_CONFIG_V1\n",
		"-- NTR_OWNED_GARAGE_ICON_CONFIG_V1\n-- "..REVISION.."\n",
		"interior revision"
	)
	interiorSource=replaceOnce(
		interiorSource,
		'local root=Instance.new("Frame"); root.Name="AccessControls"; root.BackgroundTransparency=1; root.Position=UDim2.fromOffset(18,18); root.Size=UDim2.fromOffset(330,48); root.Parent=gui',
		'local root=Instance.new("Frame"); root.Name="AccessControls"; root.BackgroundTransparency=1; root.Position=UDim2.fromOffset(18,18); root.Size=UDim2.fromOffset(330,48); root.Parent=gui\n\tlocal hudScale=Instance.new("UIScale"); hudScale.Name="ResponsiveScale"; hudScale.Scale=1; hudScale.Parent=root',
		"access HUD responsive scale"
	)
	interiorSource=replaceOnce(
		interiorSource,
		'local dropdown=Shared.AnchoredDropdown(root,{ZIndex=80,OnOpenChanged=function(target,isOpen) Shared.SetDropdownOpen(access,target==access and isOpen); Shared.SetDropdownOpen(invite,target==invite and isOpen) end}); local state; local busy=false; local refreshing=false; local cameraConnection',
		'local dropdown=Shared.AnchoredDropdown(root,{ZIndex=80,Scale=function() return hudScale.Scale end,OnOpenChanged=function(target,isOpen) Shared.SetDropdownOpen(access,target==access and isOpen); Shared.SetDropdownOpen(invite,target==invite and isOpen) end}); local state; local busy=false; local refreshing=false; local cameraConnection',
		"dropdown scale contract"
	)
	interiorSource=replaceOnce(
		interiorSource,
		'local function metrics() local touch=UserInputService.TouchEnabled; local rowHeight=access.AbsoluteSize.Y; if rowHeight<1 then rowHeight=number(touch and "InteriorHudTouchButtonHeight" or "InteriorHudButtonHeight",touch and 48 or 46) end; return {Gap=number("InteriorHudDropdownGap",5),RowGap=number("InteriorHudDropdownRowGap",5),RowHeight=rowHeight,MaxRows=number(touch and "InteriorHudTouchDropdownRows" or "InteriorHudDropdownRows",touch and 4 or 5),TextSize=touch and 11 or 10,DetailTextSize=touch and 9 or 8} end',
		'local function metrics() local touch=UserInputService.TouchEnabled; local scale=math.max(.01,hudScale.Scale); local rowHeight=access.AbsoluteSize.Y/scale; if rowHeight<1 then rowHeight=number(touch and "InteriorHudTouchButtonHeight" or "InteriorHudButtonHeight",touch and 48 or 46) end; return {Gap=number("InteriorHudDropdownGap",5),RowGap=number("InteriorHudDropdownRowGap",5),RowHeight=rowHeight,MaxRows=number(touch and "InteriorHudTouchDropdownRows" or "InteriorHudDropdownRows",touch and 4 or 5),TextSize=touch and 11 or 10,DetailTextSize=touch and 9 or 8} end',
		"dropdown logical metrics"
	)
	interiorSource=replaceOnce(
		interiorSource,
		'local camera=Workspace.CurrentCamera; local viewport=camera and camera.ViewportSize or Vector2.new(1280,720); local touch=UserInputService.TouchEnabled; local tiny=viewport.Y<500; local margin=math.max(8,number("InteriorHudMargin",tiny and 10 or 18));',
		'local camera=Workspace.CurrentCamera; local viewport=camera and camera.ViewportSize or Vector2.new(1280,720); local touch=UserInputService.TouchEnabled; local scale=1; if touch and settings:GetAttribute("InteriorHudTouchResponsiveScale")~=false then local referenceWidth=math.max(320,number("InteriorHudTouchReferenceWidth",800)); local referenceHeight=math.max(320,number("InteriorHudTouchReferenceHeight",600)); local minimum=math.clamp(number("InteriorHudTouchMinimumScale",.72),.5,1); local maximum=math.clamp(number("InteriorHudTouchMaximumScale",1),minimum,1); scale=math.clamp(math.min(viewport.X/referenceWidth,viewport.Y/referenceHeight),minimum,maximum) end; hudScale.Scale=scale; local logicalViewport=viewport/scale; local tiny=logicalViewport.Y<500; local margin=math.max(8,number("InteriorHudMargin",tiny and 10 or 18));',
		"touch scale calculation"
	)
	interiorSource=replaceOnce(
		interiorSource,
		'local available=math.max(220,viewport.X-margin*2-gap);',
		'local available=math.max(220,logicalViewport.X-margin*2-gap);',
		"logical available width"
	)
	interiorSource=replaceOnce(
		interiorSource,
		'local toastWidth=math.min(420,math.max(220,viewport.X-margin*2));',
		'local toastWidth=math.min(420,math.max(220,logicalViewport.X-margin*2));',
		"logical toast width"
	)
end

local browserSource=browser.Source
if not browserSource:find(REVISION,1,true) then
	browserSource=replaceOnce(
		browserSource,
		"-- NTR_OWNED_GARAGE_ICON_CONFIG_V1\n",
		"-- NTR_OWNED_GARAGE_ICON_CONFIG_V1\n-- "..REVISION.."\n",
		"browser revision"
	)
	browserSource=replaceOnce(
		browserSource,
		'local function open()\n\t\tgeneration+=1;',
		'local function open(propertyId)\n\t\tlocal requestedPropertyId=tostring(propertyId or ""); generation+=1;',
		"property-aware browser open"
	)
	browserSource=replaceOnce(
		browserSource,
		'state=result; selected=nil; for _,property in ipairs(state.Properties or {}) do if property.PropertyId==state.ActiveGarageId then selected=property; break end end; selected=selected or (state.Properties and state.Properties[1]);',
		'state=result; selected=nil; local desiredPropertyId=requestedPropertyId~="" and requestedPropertyId or tostring(state.ActiveGarageId or ""); for _,property in ipairs(state.Properties or {}) do if property.PropertyId==desiredPropertyId then selected=property; break end end; selected=selected or (state.Properties and state.Properties[1]);',
		"property-aware browser selection"
	)
	browserSource=replaceOnce(
		browserSource,
		'if player:GetAttribute("NTR_OwnedGarageInside")~=true or not prompt then return end\n\t\tif prompt.Name=="FootExitPrompt" then beginPhysicalLoading("OwnedGarageExterior","RETURNING TO CITY") elseif prompt.Name=="DriveOutPrompt" then beginPhysicalLoading("OwnedGarageDriveOut","PREPARING VEHICLE") end',
		'if not prompt then return end\n\t\tif player:GetAttribute("NTR_OwnedGarageInside")==true then\n\t\t\tif prompt.Name=="FootExitPrompt" then beginPhysicalLoading("OwnedGarageExterior","RETURNING TO CITY") elseif prompt.Name=="DriveOutPrompt" then beginPhysicalLoading("OwnedGarageDriveOut","PREPARING VEHICLE") end\n\t\telseif prompt:GetAttribute("OwnedGarageEntryPrompt")==true and not overlay.Visible then\n\t\t\topen(prompt:GetAttribute("OwnedGaragePropertyId"))\n\t\tend',
		"world entry prompt bridge"
	)
end

compile(interiorSource,interior.Name.."_Projected")
compile(browserSource,browser.Name.."_Projected")
assert(interiorSource:find('Scale=function() return hudScale.Scale end',1,true),"Dropdown scale bridge was not projected")
assert(browserSource:find('prompt:GetAttribute("OwnedGarageEntryPrompt")==true',1,true),"World entry prompt bridge was not projected")
assert(browserSource:find('desiredPropertyId=requestedPropertyId~=""',1,true),"Property-aware browser selection was not projected")

local world=assert(Workspace:FindFirstChild("NeoTokyoRacersWorld"),"Workspace.NeoTokyoRacersWorld missing")
local exteriors=assert(world:FindFirstChild("OwnedGarageExteriors"),"Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors missing")
local exterior=assert(exteriors:FindFirstChild("STARTER_TWO_BAY"),"OwnedGarageExteriors.STARTER_TWO_BAY missing")
local footExit=assert(exterior:FindFirstChild("FootExitSpawn"),"STARTER_TWO_BAY.FootExitSpawn missing")
local vehicleExit=assert(exterior:FindFirstChild("VehicleExitSpawn"),"STARTER_TWO_BAY.VehicleExitSpawn missing")
assert(footExit:IsA("BasePart"),footExit:GetFullName().." must be a BasePart")
assert(vehicleExit:IsA("BasePart"),vehicleExit:GetFullName().." must be a BasePart")

local attributeDefaults={
	InteriorHudTouchResponsiveScale=true,
	InteriorHudTouchReferenceWidth=800,
	InteriorHudTouchReferenceHeight=600,
	InteriorHudTouchMinimumScale=.72,
	InteriorHudTouchMaximumScale=1,
}
local oldAttributes={}
for name in pairs(attributeDefaults) do oldAttributes[name]=settings:GetAttribute(name) end

local oldInteriorSource=interior.Source
local oldBrowserSource=browser.Source
local oldInteriorRevision=interior:GetAttribute("OwnedGarageMobileAccessRevision")
local oldInteriorRunId=interior:GetAttribute("OwnedGarageMobileAccessRunId")
local oldBrowserRevision=browser:GetAttribute("OwnedGarageWorldEntryRevision")
local oldBrowserRunId=browser:GetAttribute("OwnedGarageWorldEntryRunId")
local created={}

local function makeEntry(name,sourcePart,offset,size,mode,actionText,distance)
	local part=exterior:FindFirstChild(name)
	if not part then
		part=Instance.new("Part")
		part.Name=name
		part.Anchored=true
		part.CanCollide=false
		part.CanTouch=false
		part.CanQuery=true
		part.CastShadow=false
		part.Transparency=1
		part.Size=size
		part.CFrame=sourcePart.CFrame*offset
		part.Parent=exterior
		table.insert(created,part)
	end
	assert(part:IsA("BasePart"),part:GetFullName().." must be a BasePart")
	part:SetAttribute("OwnedGarageMarkerRole",mode.."Entry")
	part:SetAttribute("OwnedGaragePropertyId","STARTER_TWO_BAY")
	part:SetAttribute("OwnedGarageMovableEntrance",true)
	local prompt=part:FindFirstChild("OwnedGarage"..mode.."EntryPrompt")
	if not prompt then
		prompt=Instance.new("ProximityPrompt")
		prompt.Name="OwnedGarage"..mode.."EntryPrompt"
		prompt.Parent=part
	end
	assert(prompt:IsA("ProximityPrompt"),prompt:GetFullName().." must be a ProximityPrompt")
	prompt.ActionText=actionText
	prompt.ObjectText="KANDA TWO-BAY"
	prompt.KeyboardKeyCode=Enum.KeyCode.E
	prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
	prompt.HoldDuration=0
	prompt.MaxActivationDistance=distance
	prompt.RequiresLineOfSight=false
	prompt.ClickablePrompt=true
	prompt:SetAttribute("OwnedGarageEntryPrompt",true)
	prompt:SetAttribute("OwnedGarageEntryMode",mode)
	prompt:SetAttribute("OwnedGaragePropertyId","STARTER_TWO_BAY")
	return part,prompt
end

local ok,problem=pcall(function()
	for name,value in pairs(attributeDefaults) do
		if settings:GetAttribute(name)==nil then settings:SetAttribute(name,value) end
	end
	assert(type(settings:GetAttribute("InteriorHudTouchResponsiveScale"))=="boolean","InteriorHudTouchResponsiveScale must be boolean")
	assert(type(settings:GetAttribute("InteriorHudTouchReferenceWidth"))=="number","InteriorHudTouchReferenceWidth must be numeric")
	assert(type(settings:GetAttribute("InteriorHudTouchReferenceHeight"))=="number","InteriorHudTouchReferenceHeight must be numeric")
	assert(type(settings:GetAttribute("InteriorHudTouchMinimumScale"))=="number","InteriorHudTouchMinimumScale must be numeric")
	assert(type(settings:GetAttribute("InteriorHudTouchMaximumScale"))=="number","InteriorHudTouchMaximumScale must be numeric")

	local footPart,footPrompt=makeEntry("FootEntrance",footExit,CFrame.new(0,0,-8),Vector3.new(7,6,7),"Foot","OPEN GARAGE",12)
	local drivePart,drivePrompt=makeEntry("DriveInEntrance",vehicleExit,CFrame.new(0,0,-18),Vector3.new(18,8,14),"DriveIn","DRIVE INTO GARAGE",20)

	if interior.Source~=interiorSource then interior.Source=interiorSource end
	if browser.Source~=browserSource then browser.Source=browserSource end
	interior:SetAttribute("OwnedGarageMobileAccessRevision",REVISION)
	interior:SetAttribute("OwnedGarageMobileAccessRunId",RUN_ID)
	browser:SetAttribute("OwnedGarageWorldEntryRevision",REVISION)
	browser:SetAttribute("OwnedGarageWorldEntryRunId",RUN_ID)

	assert(footPart.Parent==exterior and drivePart.Parent==exterior,"Entry marker hierarchy did not persist")
	assert(footPrompt:GetAttribute("OwnedGarageEntryPrompt")==true,"Foot entry prompt contract missing")
	assert(drivePrompt:GetAttribute("OwnedGarageEntryPrompt")==true,"Drive-in entry prompt contract missing")
	assert(interior.Source:find(REVISION,1,true),"Interior source revision did not persist")
	assert(browser.Source:find(REVISION,1,true),"Browser source revision did not persist")
	compile(interior.Source,interior.Name.."_Committed")
	compile(browser.Source,browser.Name.."_Committed")
end)

if not ok then
	pcall(function()
		interior.Source=oldInteriorSource
		browser.Source=oldBrowserSource
		interior:SetAttribute("OwnedGarageMobileAccessRevision",oldInteriorRevision)
		interior:SetAttribute("OwnedGarageMobileAccessRunId",oldInteriorRunId)
		browser:SetAttribute("OwnedGarageWorldEntryRevision",oldBrowserRevision)
		browser:SetAttribute("OwnedGarageWorldEntryRunId",oldBrowserRunId)
		for name,value in pairs(oldAttributes) do settings:SetAttribute(name,value) end
		for _,object in ipairs(created) do if object.Parent then object:Destroy() end end
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS revision="..REVISION.." runId="..RUN_ID)
print(TAG.." MOBILE CONFIG: ReplicatedStorage.NeoTokyoRacers.Config.Runtime.OwnedGarage_EditAttributes")
print(TAG.." FOOT ENTRY: Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.STARTER_TWO_BAY.FootEntrance")
print(TAG.." DRIVE-IN ENTRY: Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.STARTER_TWO_BAY.DriveInEntrance")
print(TAG.." READY: restart Play, test both prompts, then use Device Emulator to test access/invite dropdown scaling.")
