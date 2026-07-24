-- Neo Tokyo Racers - Driving Hover Height Config Bridge V1
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Makes the existing HoverHeightStuds NumberValue authoritative for driven,
-- fallback and parked hover, plus the spawned vehicle diagnostic attribute.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Driving Hover Height Config V1]"
local REVISION="NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1"
local RUN_ID=HttpService:GenerateGUID(false)

local function countPlain(source,needle)
	local count,cursor=0,1
	while true do
		local first,last=source:find(needle,cursor,true)
		if not first then return count end
		count+=1
		cursor=last+1
	end
end

local function replaceOnce(source,needle,replacement,label)
	assert(type(source)=="string",label.." source missing")
	assert(countPlain(source,needle)==1,label.." anchor count changed")
	local first=assert(source:find(needle,1,true),label.." anchor missing")
	return source:sub(1,first-1)..replacement..source:sub(first+#needle)
end

local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local function snapshotAttributes(instance)
	local result={}
	for name,value in pairs(instance:GetAttributes()) do result[name]=value end
	return result
end

local function restoreAttributes(instance,snapshot)
	for name in pairs(instance:GetAttributes()) do if snapshot[name]==nil then instance:SetAttribute(name,nil) end end
	for name,value in pairs(snapshot) do instance:SetAttribute(name,value) end
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"ReplicatedStorage.NeoTokyoRacers missing")
local common=assert(kit:FindFirstChild("Shared") and kit.Shared:FindFirstChild("Modules") and kit.Shared.Modules:FindFirstChild("Common"),"Shared.Modules.Common missing")
local driveTuning=assert(common:FindFirstChild("DriveTuning"),"Shared.Modules.Common.DriveTuning missing")
assert(driveTuning:IsA("ModuleScript"),driveTuning:GetFullName().." must be a ModuleScript")
assert(driveTuning.Source:find("HoverHeightStuds",1,true),"DriveTuning HoverHeightStuds contract missing")

local drivingConfig=assert(
	kit:FindFirstChild("Config")
		and kit.Config:FindFirstChild("Editable")
		and kit.Config.Editable:FindFirstChild("01_GAME_BALANCE_Editable")
		and kit.Config.Editable["01_GAME_BALANCE_Editable"]:FindFirstChild("Driving"),
	"Editable.01_GAME_BALANCE_Editable.Driving missing"
)
local hoverValue=assert(drivingConfig:FindFirstChild("HoverHeightStuds"),"Driving.HoverHeightStuds missing")
assert(hoverValue:IsA("NumberValue"),hoverValue:GetFullName().." must be a NumberValue")
assert(typeof(hoverValue.Value)=="number","HoverHeightStuds value must be numeric")

local clientControllers=assert(
	kit.Shared.Modules:FindFirstChild("Client")
		and kit.Shared.Modules.Client:FindFirstChild("Controllers"),
	"Shared.Modules.Client.Controllers missing"
)
local driving=assert(clientControllers:FindFirstChild("DrivingControllerV47"),"DrivingControllerV47 missing")
local fallback=assert(clientControllers:FindFirstChild("DrivingFallbackController"),"DrivingFallbackController missing")
local parked=assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers:FindFirstChild("Runtime")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime:FindFirstChild("FreeRoamParkedHoverController_Active"),
	"FreeRoamParkedHoverController_Active missing"
)
local garageAction=assert(
	ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage")
		and ServerScriptService.NeoTokyoRacers.Services.Garage:FindFirstChild("GarageActionController_Shadow_Disabled"),
	"GarageActionController_Shadow_Disabled missing"
)

for _,instance in ipairs({driving,fallback}) do assert(instance:IsA("ModuleScript"),instance:GetFullName().." must be a ModuleScript") end
for _,instance in ipairs({parked,garageAction}) do assert(instance:IsA("LuaSourceContainer"),instance:GetFullName().." must contain source") end

local projected={}

projected.Driving=driving.Source
if not projected.Driving:find("NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1",1,true) then
	projected.Driving=replaceOnce(projected.Driving,
		'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
		'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal DriveTuning = require(ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("DriveTuning")) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1',
		"DrivingController DriveTuning require")
	projected.Driving=replaceOnce(projected.Driving,
		'local HOVER_HEIGHT = 3',
		'local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_VALUE_V1',
		"DrivingController hover height")
end

projected.Fallback=fallback.Source
if not projected.Fallback:find("NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1",1,true) then
	projected.Fallback=replaceOnce(projected.Fallback,
		'local Workspace = game:GetService("Workspace")',
		'local Workspace = game:GetService("Workspace")\nlocal ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal DriveTuning = require(ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("DriveTuning")) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1',
		"Fallback DriveTuning require")
	projected.Fallback=replaceOnce(projected.Fallback,
		'local HOVER_HEIGHT = 3',
		'local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_VALUE_V1',
		"Fallback hover height")
end

projected.Parked=parked.Source
if not projected.Parked:find("NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1",1,true) then
	projected.Parked=replaceOnce(projected.Parked,
		'local Workspace = game:GetService("Workspace")',
		'local Workspace = game:GetService("Workspace")\nlocal ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal DriveTuning = require(ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("DriveTuning")) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1',
		"Parked hover DriveTuning require")
	projected.Parked=replaceOnce(projected.Parked,
		'local HOVER_HEIGHT = 3',
		'local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_VALUE_V1',
		"Parked hover height")
end

projected.Server=garageAction.Source
if not projected.Server:find("NTR_DRIVING_HOVER_HEIGHT_CONFIG_ATTRIBUTE_V1",1,true) then
	projected.Server=replaceOnce(projected.Server,
		'vehicle:SetAttribute("HoverHeight", 3)',
		'vehicle:SetAttribute("HoverHeight", math.clamp(require(V56_kit.Shared.Modules.Common:WaitForChild("DriveTuning")).Read().HoverHeightStuds, 0.5, 8)) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_ATTRIBUTE_V1',
		"Spawned vehicle hover-height attribute")
end

for name,source in pairs(projected) do compile(source,name.."_Projected") end

local sources={
	[driving]=driving.Source,
	[fallback]=fallback.Source,
	[parked]=parked.Source,
	[garageAction]=garageAction.Source,
}
local sourceAttributes={}
for instance in pairs(sources) do sourceAttributes[instance]=snapshotAttributes(instance) end
local valueAttributes=snapshotAttributes(hoverValue)

local ok,problem=pcall(function()
	hoverValue:SetAttribute("Minimum",0.5)
	hoverValue:SetAttribute("Maximum",8)
	hoverValue:SetAttribute("Units","studs")
	hoverValue:SetAttribute("Description","Target vehicle root clearance above detected ground. Applied when Play starts; restart Play after editing.")
	hoverValue:SetAttribute("ConfigOwner","DriveTuning")
	hoverValue:SetAttribute("Revision",REVISION)

	for instance,source in pairs({
		[driving]=projected.Driving,
		[fallback]=projected.Fallback,
		[parked]=projected.Parked,
		[garageAction]=projected.Server,
	}) do
		instance.Source=source
		instance:SetAttribute("HoverHeightConfigRevision",REVISION)
		compile(instance.Source,instance.Name.."_Committed")
	end

	assert(driving.Source:find("DriveTuning.Read().HoverHeightStuds",1,true),"Driving owner bridge missing")
	assert(fallback.Source:find("DriveTuning.Read().HoverHeightStuds",1,true),"Fallback owner bridge missing")
	assert(parked.Source:find("DriveTuning.Read().HoverHeightStuds",1,true),"Parked owner bridge missing")
	assert(garageAction.Source:find("NTR_DRIVING_HOVER_HEIGHT_CONFIG_ATTRIBUTE_V1",1,true),"Server diagnostic bridge missing")
	assert(hoverValue:GetAttribute("Minimum")==0.5 and hoverValue:GetAttribute("Maximum")==8,"HoverHeightStuds metadata missing")
end)

if not ok then
	pcall(function()
		for instance,source in pairs(sources) do
			if instance.Parent then instance.Source=source; restoreAttributes(instance,sourceAttributes[instance]) end
		end
		if hoverValue.Parent then restoreAttributes(hoverValue,valueAttributes) end
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS revision="..REVISION.." value="..tostring(hoverValue.Value).." range=0.5-8 owners=driven/fallback/parked/serverAttribute runId="..RUN_ID)
print(TAG.." READY: restart Studio/Play, compare driven and parked height, test slopes/ramps/reset/exit/re-entry, then tune Driving.HoverHeightStuds and restart Play.")
