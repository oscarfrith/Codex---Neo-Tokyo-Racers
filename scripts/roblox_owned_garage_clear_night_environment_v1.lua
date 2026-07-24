-- Neo Tokyo Racers - Owned Garage ClearNight environment V1.2
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Repairs the isolated local presentation owner and hardens the existing
-- server drive-out and cached-interior prompt lifecycle boundaries. It does not
-- modify the global lighting cycle, garage fixture colours, vehicle ownership,
-- remotes, saved schema, or the configured interior unload delay.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Owned Garage ClearNight Environment V1.2]"
local BASE_REVISION="NTR_OWNED_GARAGE_CLEAR_NIGHT_ENVIRONMENT_V1"
local PREVIOUS_REVISION="NTR_OWNED_GARAGE_CLEAR_NIGHT_ENVIRONMENT_V1_1_TRANSITION_RESILIENCE"
local REVISION="NTR_OWNED_GARAGE_CLEAR_NIGHT_ENVIRONMENT_V1_2_PROMPT_LIFECYCLE"
local RUN_ID=HttpService:GenerateGUID(false)

local SOURCE=[==[
-- NTR_OWNED_GARAGE_CLEAR_NIGHT_ENVIRONMENT_V1_2_PROMPT_LIFECYCLE
-- Local presentation only: the server-owned city lighting cycle remains authoritative.
local Lighting=game:GetService("Lighting")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local player=Players.LocalPlayer
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
local shared=ReplicatedStorage:WaitForChild("Shared")
local presets=require(shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets"))
local skies=shared:WaitForChild("SkyPresets")

local EFFECT_SPECS={
	Atmosphere={"Atmosphere","Atmosphere"},
	ColorCorrection={"ColorCorrectionEffect","ColorCorrection"},
	Bloom={"BloomEffect","Bloom"},
	SunRays={"SunRaysEffect","SunRays"},
	DepthOfField={"DepthOfFieldEffect","DepthOfField"},
}

local effects={}
local inside=false
local generation=0
local lastCityPreset
local reapplyQueued=false
local queueInterior=function() end

local function configuredPreset()
	local name=settings:GetAttribute("InteriorEnvironmentPreset")
	return type(name)=="string" and name~="" and name or "ClearNight"
end

local function validPreset(name)
	return type(name)=="string" and type(presets[name])=="table"
end

local function getEffect(section)
	local cached=effects[section]
	if cached and cached.Parent==Lighting then return cached end
	local spec=EFFECT_SPECS[section]
	if not spec then return nil end
	local existing=Lighting:FindFirstChild(spec[2])
	if existing and existing.ClassName~=spec[1] then existing:Destroy(); existing=nil end
	if not existing then existing=Instance.new(spec[1]); existing.Name=spec[2]; existing.Parent=Lighting end
	effects[section]=existing
	return existing
end

local function applyProperties(instance,properties)
	for propertyName,value in pairs(properties or {}) do
		if instance==Lighting and propertyName=="Fogcolor" then propertyName="FogColor" end
		local ok,problem=pcall(function()
			if instance[propertyName]~=value then instance[propertyName]=value end
		end)
		if not ok then warn("[NTR Owned Garage Environment] Could not apply "..instance.Name.."."..propertyName..": "..tostring(problem)) end
	end
end

local function applySky(name)
	if type(name)~="string" or name=="" then return end
	local template=skies:FindFirstChild(name)
	if not (template and template:IsA("Sky")) then
		warn("[NTR Owned Garage Environment] Missing Sky preset: "..name)
		return
	end
	local active
	for _,child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") and child.Name=="ActiveSky" and child:GetAttribute("NTR_OwnedGarageSkyPreset")==name then active=child end
	end
	if active then
		for _,child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") and child~=active then child:Destroy() end end
		return
	end
	for _,child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end
	local clone=template:Clone(); clone.Name="ActiveSky"; clone:SetAttribute("NTR_OwnedGarageSkyPreset",name); clone.Parent=Lighting
end

local function applyPreset(name)
	local preset=validPreset(name) and presets[name] or nil
	if not preset then
		warn("[NTR Owned Garage Environment] Missing lighting preset: "..tostring(name))
		return false
	end
	local ok,problem=pcall(function()
		applyProperties(Lighting,preset.Lighting)
		for section in pairs(EFFECT_SPECS) do applyProperties(getEffect(section),preset[section]) end
		applySky(preset.SkyName)
	end)
	if not ok then warn("[NTR Owned Garage Environment] Preset application failed: "..tostring(problem)) end
	return ok
end

local function applyInterior(expectedGeneration)
	if expectedGeneration~=generation or not inside then return end
	if settings:GetAttribute("InteriorEnvironmentLightingEnabled")==false then return end
	applyPreset(configuredPreset())
end

queueInterior=function()
	if not inside then return end
	generation+=1
	if reapplyQueued then return end
	reapplyQueued=true
	task.delay(.05,function()
		reapplyQueued=false
		applyInterior(generation)
	end)
end

local function update()
	generation+=1
	local token=generation
	local physicallyInside=player:GetAttribute("NTR_OwnedGarageInside")==true
	local nextActive=physicallyInside and settings:GetAttribute("InteriorEnvironmentLightingEnabled")~=false
	if nextActive then
		local cityPreset=Lighting:GetAttribute("NTR_LightingPreset")
		if validPreset(cityPreset) then lastCityPreset=cityPreset end
		inside=true
		queueInterior()
	elseif inside then
		inside=false
		local cityPreset=Lighting:GetAttribute("NTR_LightingPreset")
		if validPreset(cityPreset) then lastCityPreset=cityPreset end
		local fallback=settings:GetAttribute("InteriorEnvironmentFallbackCityPreset")
		local restore=validPreset(lastCityPreset) and lastCityPreset or (validPreset(fallback) and fallback or "Day")
		task.defer(function()
			if token==generation and not inside then applyPreset(restore) end
		end)
	else
		inside=false
	end
end

Lighting:GetAttributeChangedSignal("NTR_LightingPreset"):Connect(function()
	local cityPreset=Lighting:GetAttribute("NTR_LightingPreset")
	if validPreset(cityPreset) then lastCityPreset=cityPreset end
	queueInterior()
end)

settings:GetAttributeChangedSignal("InteriorEnvironmentPreset"):Connect(function()
	queueInterior()
end)
settings:GetAttributeChangedSignal("InteriorEnvironmentLightingEnabled"):Connect(update)
player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(update)

update()
script:SetAttribute("OwnedGarageEnvironmentStarted",true)
print("[NTR Owned Garage] ClearNight interior environment owner active.")
]==]

local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local function countPlain(source,needle)
	local count=0
	local cursor=1
	while true do
		local first,last=source:find(needle,cursor,true)
		if not first then return count end
		count+=1
		cursor=last+1
	end
end

local function replaceBetween(source,firstMarker,lastMarker,replacement,label)
	assert(type(source)=="string",label.." source missing")
	assert(countPlain(source,firstMarker)==1,label.." first marker count changed")
	assert(countPlain(source,lastMarker)==1,label.." last marker count changed")
	local first=assert(source:find(firstMarker,1,true),label.." first marker missing")
	local last=assert(source:find(lastMarker,first+#firstMarker,true),label.." last marker missing")
	return source:sub(1,first-1)..replacement..source:sub(last)
end

compile(SOURCE,"OwnedGarageEnvironmentLightingController_Active_Projected")

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"ReplicatedStorage.NeoTokyoRacers missing")
local config=assert(kit:FindFirstChild("Config"),"NeoTokyoRacers.Config missing")
local runtime=assert(config:FindFirstChild("Runtime"),"NeoTokyoRacers.Config.Runtime missing")
local settings=assert(runtime:FindFirstChild("OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")
local shared=assert(ReplicatedStorage:FindFirstChild("Shared"),"ReplicatedStorage.Shared missing")
local presetFolder=assert(shared:FindFirstChild("LightingPresets"),"Shared.LightingPresets missing")
local presetModule=assert(presetFolder:FindFirstChild("LightingPresets"),"LightingPresets module missing")
local skyFolder=assert(shared:FindFirstChild("SkyPresets"),"Shared.SkyPresets missing")
assert(presetModule:IsA("ModuleScript"),presetModule:GetFullName().." must be a ModuleScript")
assert(skyFolder:FindFirstChild("ClearNightSky") and skyFolder.ClearNightSky:IsA("Sky"),"ClearNightSky missing")

local okPresets,presets=pcall(require,presetModule)
assert(okPresets and type(presets)=="table","LightingPresets could not be loaded: "..tostring(presets))
assert(type(presets.ClearNight)=="table","ClearNight lighting preset missing")
assert(type(presets.Day)=="table","Day fallback lighting preset missing")

local controllers=assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers"),
	"NeoTokyoRacersClient.Controllers missing"
)
local world=controllers:FindFirstChild("World")
assert(world and world:IsA("Folder"),"NeoTokyoRacersClient.Controllers.World missing")

local scriptName="OwnedGarageEnvironmentLightingController_Active"
local target=world:FindFirstChild(scriptName)
local created=false
if target then
	assert(target:IsA("LocalScript"),target:GetFullName().." must be a LocalScript")
	local existingRevision=target:GetAttribute("OwnedGarageEnvironmentRevision")
	assert(
		existingRevision==BASE_REVISION
			or existingRevision==PREVIOUS_REVISION
			or existingRevision==REVISION
			or target.Source:find(BASE_REVISION,1,true)
			or target.Source:find(PREVIOUS_REVISION,1,true)
			or target.Source:find(REVISION,1,true),
		target:GetFullName().." exists without the owned-garage environment contract"
	)
else
	target=Instance.new("LocalScript")
	target.Name=scriptName
	created=true
end

local garageServices=assert(
	ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage"),
	"ServerScriptService.NeoTokyoRacers.Services.Garage missing"
)
local management=assert(garageServices:FindFirstChild("OwnedGarageManagementRuntime"),"OwnedGarageManagementRuntime missing")
assert(management:IsA("ModuleScript"),management:GetFullName().." must be a ModuleScript")

local DRIVE_OUT_START="\tdriveOut=function(player,slotId)"
local DRIVE_OUT_END="\tlocal function managedOperation(player,profile,operation,args)"
local DRIVE_OUT_SOURCE=[==[	local function verifyDriveOutVehicle(player,vehicle,spawnCFrame)
		if not (typeof(vehicle)=="Instance" and vehicle:IsA("Model")) then return false,"Spawned vehicle reference is missing." end
		local timeout=math.clamp(tonumber(settings:GetAttribute("GarageDriveOutVerifySeconds")) or 2.5,.5,6)
		local tolerance=math.max(12,tonumber(settings:GetAttribute("GarageDriveOutVerifyDistanceStuds")) or 40)
		local deadline=os.clock()+timeout
		repeat
			local character=player.Character
			local humanoid=character and character:FindFirstChildOfClass("Humanoid")
			local root=characterRoot(player)
			local seat=humanoid and humanoid.SeatPart
			local vehiclePosition
			if vehicle.Parent then
				local ok,pivot=pcall(function() return vehicle:GetPivot() end)
				if ok then vehiclePosition=pivot.Position end
			end
			local seated=seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
			local characterNear=root and (root.Position-spawnCFrame.Position).Magnitude<=tolerance
			local vehicleNear=vehiclePosition and (vehiclePosition-spawnCFrame.Position).Magnitude<=tolerance
			if vehicle.Parent and seated and characterNear and vehicleNear then return true end
			task.wait(.05)
		until os.clock()>=deadline or not player.Parent
		return false,"Vehicle was created, but the exterior seat/position handoff could not be verified."
	end
	local function recoverDriveOut(player,session,before,result,vehicleId,vehicle,message)
		local hasVehicle=typeof(vehicle)=="Instance"
		local cleanup=hasVehicle and lifecycleCall("DespawnForGarage",player,{VehicleId=tostring(vehicleId),PreserveCharacterPosition=true,WaitForDetach=true,DetachTimeoutSeconds=settings:GetAttribute("GarageSeatDetachTimeoutSeconds")}) or {Success=true}
		if hasVehicle and vehicle.Parent then pcall(function() vehicle:Destroy() end) end
		local restored=compensate(player,before,result.Revision,"OwnedGarageDriveOutVerifiedRollback")
		task.wait()
		local interiorSpawn=session.Interior and session.Interior:FindFirstChild("CharacterSpawn",true)
		local returned,returnMessage=teleportCharacter(player,interiorSpawn and interiorSpawn.CFrame)
		session.Transition=nil
		setInside(player,session)
		applyPromptPolicy(session)
		local committed=getProfile:Invoke(player)
		if type(committed)=="table" then renderDisplays(player,committed,session) end
		local details=tostring(message or "Vehicle could not leave the garage.")
		if not cleanup.Success and hasVehicle then details=details.." Runtime cleanup used the verified fallback." end
		if not restored then details=details.." Display assignment recovery failed; retry after the profile refreshes." end
		if not returned then details=details.." Interior return also failed: "..tostring(returnMessage) end
		return {Success=false,Message=details,Recovered=restored and returned}
	end
	driveOut=function(player,slotId)
		-- NTR_OWNED_GARAGE_DRIVE_OUT_VERIFIED_COMPLETION_V1
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; session.Transition="DriveOut"; applyPromptPolicy(session); local property=profile.OwnedGarage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message="Display space is empty."} end
		local spawnCFrame,spawnMessage=exteriorCFrame(session.PropertyId,"VehicleExitSpawn"); if not spawnCFrame then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=spawnMessage} end
		local streamed,streamMessage=streamDestination(player,spawnCFrame.Position,{DestinationType="Exterior",ExteriorId=tostring((catalog.ById(session.PropertyId) or {}).ExteriorSpawnId or ""),MarkerName="VehicleExitSpawn"}); if not streamed then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=streamMessage} end
		local before=Profile.Snapshot(profile); local result=command(player,"Clear",{GarageId=session.PropertyId,SlotId=slotId},"OwnedGarageDriveOut",Profile.NewRequestId(),profile.OwnedGarage.Revision); if type(result)~="table" or not result.Success then session.Transition=nil; applyPromptPolicy(session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local spawned=lifecycleCall("SpawnFromGarage",player,{VehicleId=tostring(vehicleId),SpawnCFrame=spawnCFrame})
		if not spawned.Success then return recoverDriveOut(player,session,before,result,vehicleId,spawned.Vehicle,spawned.Message) end
		local verified,verifyMessage=verifyDriveOutVehicle(player,spawned.Vehicle,spawnCFrame)
		if not verified then return recoverDriveOut(player,session,before,result,vehicleId,spawned.Vehicle,verifyMessage) end
		sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}); return {Success=true,Message="Vehicle spawned from garage.",VehicleId=tostring(vehicleId),Revision=result.Revision}
	end
]==]

local DISCONNECT_PROMPTS_START="\tlocal function disconnectPrompts(interior)"
local DISCONNECT_PROMPTS_END="\tlocal function scheduleUnload(interior,player)"
local DISCONNECT_PROMPTS_SOURCE=[==[	local function disconnectPrompts(interior)
		for _,connection in pairs(promptConnections[interior] or {}) do
			if typeof(connection)=="RBXScriptConnection" then connection:Disconnect() end
		end
		promptConnections[interior]=nil
	end
	local function bindPrompt(interior,prompt,callback)
		if not (interior and prompt and prompt:IsA("ProximityPrompt") and type(callback)=="function") then return false end
		local registry=promptConnections[interior]
		if not registry then registry={}; promptConnections[interior]=registry end
		local previous=registry[prompt]
		if typeof(previous)=="RBXScriptConnection" then previous:Disconnect() end
		registry[prompt]=prompt.Triggered:Connect(callback)
		return true
	end
]==]

local RENDER_DISPLAYS_START="\tlocal function renderDisplays(player,profile,session)"
local RENDER_DISPLAYS_END="\tlocal function configurePrompts(player,profile,session)"
local RENDER_DISPLAYS_SOURCE=[==[	local function renderDisplays(player,profile,session)
		-- NTR_OWNED_GARAGE_PROMPT_REGISTRY_V1
		local property=profile.OwnedGarage.Properties[session.PropertyId]
		local markers=session.Interior:FindFirstChild("DisplaySpaceMarkers")
		if not markers then return false,"Display markers missing." end
		local definition=catalog.ById(session.PropertyId)
		for _,slotId in ipairs(definition and definition.DisplaySpaceIds or {}) do
			local boundSlotId=tostring(slotId)
			Display.Clear(session.Interior,boundSlotId)
			local marker=markers:FindFirstChild(boundSlotId)
			if not marker then return false,"Display marker missing: "..boundSlotId end
			local prompt=marker:FindFirstChild("DriveOutPrompt")
			if not prompt then
				prompt=Instance.new("ProximityPrompt")
				prompt.Name="DriveOutPrompt"
				prompt.Parent=marker
			end
			if not prompt:IsA("ProximityPrompt") then return false,"Drive-out prompt contract invalid: "..boundSlotId end
			prompt.ActionText="Drive Out"
			prompt.KeyboardKeyCode=Enum.KeyCode.E
			prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
			prompt.HoldDuration=0
			prompt.MaxActivationDistance=12
			prompt.RequiresLineOfSight=false
			prompt.ClickablePrompt=true
			bindPrompt(session.Interior,prompt,function(triggeringPlayer)
				if triggeringPlayer==player then
					local result=driveOut(player,boundSlotId)
					push:FireClient(player,{Type="DriveOutResult",Success=result.Success==true,Message=result.Message})
				end
			end)
			local vehicleId=property.DisplaySpaces[boundSlotId]
			local available=vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~=""
			prompt:SetAttribute("OwnedGarageAvailable",available)
			prompt.ObjectText=available and vehicleName(profile,vehicleId) or "Empty Display Space"
			if available then
				local model,message=Display.Build(profile,tostring(vehicleId),marker,session.Interior)
				if not model then return false,message end
			end
		end
		applyPromptPolicy(session)
		return true
	end
]==]

local CONFIGURE_PROMPTS_START="\tlocal function configurePrompts(player,profile,session)"
local CONFIGURE_PROMPTS_END="\tlocal function ensureSession(player,profile,propertyId)"
local CONFIGURE_PROMPTS_SOURCE=[==[	local function configurePrompts(player,profile,session)
		-- NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_FOOT_EXIT_RESULT_V1
		local foot=session.Interior:FindFirstChild("FootExitPrompt",true)
		if foot then
			foot.HoldDuration=0
			foot:SetAttribute("OwnedGarageAvailable",true)
			bindPrompt(session.Interior,foot,function(triggeringPlayer)
				if triggeringPlayer==player then
					local result=exitOnFoot(player)
					push:FireClient(player,{Type="FootExitResult",Success=result.Success==true,Message=result.Message})
				end
			end)
		end
		local desk=session.Interior:FindFirstChild("ManageGaragePrompt",true)
		if desk then
			desk.HoldDuration=0
			desk:SetAttribute("OwnedGarageAvailable",true)
			bindPrompt(session.Interior,desk,function(triggeringPlayer)
				if triggeringPlayer==player then
					push:FireClient(player,{Type="OpenManagement",PropertyId=session.PropertyId})
				end
			end)
		end
		return renderDisplays(player,profile,session)
	end
]==]

local managementSource=management.Source
assert(managementSource:find("NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS",1,true),"Verified transition baseline missing")
local projectedManagement
if managementSource:find("NTR_OWNED_GARAGE_DRIVE_OUT_VERIFIED_COMPLETION_V1",1,true) then
	projectedManagement=managementSource
else
	projectedManagement=replaceBetween(managementSource,DRIVE_OUT_START,DRIVE_OUT_END,DRIVE_OUT_SOURCE,"OwnedGarageManagementRuntime drive-out")
end
if not projectedManagement:find("NTR_OWNED_GARAGE_PROMPT_REGISTRY_V1",1,true) then
	projectedManagement=replaceBetween(projectedManagement,DISCONNECT_PROMPTS_START,DISCONNECT_PROMPTS_END,DISCONNECT_PROMPTS_SOURCE,"OwnedGarageManagementRuntime prompt registry")
	projectedManagement=replaceBetween(projectedManagement,RENDER_DISPLAYS_START,RENDER_DISPLAYS_END,RENDER_DISPLAYS_SOURCE,"OwnedGarageManagementRuntime display prompts")
	projectedManagement=replaceBetween(projectedManagement,CONFIGURE_PROMPTS_START,CONFIGURE_PROMPTS_END,CONFIGURE_PROMPTS_SOURCE,"OwnedGarageManagementRuntime shared prompts")
end
compile(projectedManagement,"OwnedGarageManagementRuntime_Projected")

local defaults={
	InteriorEnvironmentLightingEnabled=true,
	InteriorEnvironmentPreset="ClearNight",
	InteriorEnvironmentFallbackCityPreset="Day",
	GarageDriveOutVerifySeconds=2.5,
	GarageDriveOutVerifyDistanceStuds=40,
}
local oldAttributes={}
for name in pairs(defaults) do
	local value=settings:GetAttribute(name)
	oldAttributes[name]={Present=value~=nil,Value=value}
end
local oldSource=target.Source
local oldParent=target.Parent
local oldRevision=target:GetAttribute("OwnedGarageEnvironmentRevision")
local oldRunId=target:GetAttribute("OwnedGarageEnvironmentRunId")
local oldManagementSource=management.Source

local ok,problem=pcall(function()
	for name,value in pairs(defaults) do if settings:GetAttribute(name)==nil then settings:SetAttribute(name,value) end end
	assert(type(settings:GetAttribute("InteriorEnvironmentLightingEnabled"))=="boolean","InteriorEnvironmentLightingEnabled must be boolean")
	local selected=settings:GetAttribute("InteriorEnvironmentPreset")
	assert(type(selected)=="string" and type(presets[selected])=="table","InteriorEnvironmentPreset must name a valid lighting preset")
	local fallback=settings:GetAttribute("InteriorEnvironmentFallbackCityPreset")
	assert(type(fallback)=="string" and type(presets[fallback])=="table","InteriorEnvironmentFallbackCityPreset must name a valid lighting preset")

	target.Source=SOURCE
	target:SetAttribute("OwnedGarageEnvironmentRevision",REVISION)
	target:SetAttribute("OwnedGarageEnvironmentRunId",RUN_ID)
	target.Parent=world
	management.Source=projectedManagement

	assert(target.Parent==world,"Environment controller hierarchy did not persist")
	assert(target.Source:find(REVISION,1,true),"Environment controller source revision did not persist")
	assert(management.Source:find("NTR_OWNED_GARAGE_DRIVE_OUT_VERIFIED_COMPLETION_V1",1,true),"Verified drive-out source did not persist")
	assert(management.Source:find("NTR_OWNED_GARAGE_PROMPT_REGISTRY_V1",1,true),"Prompt registry source did not persist")
	compile(target.Source,scriptName.."_Committed")
	compile(management.Source,"OwnedGarageManagementRuntime_Committed")
end)

if not ok then
	pcall(function()
		for name,snapshot in pairs(oldAttributes) do
			if snapshot.Present then settings:SetAttribute(name,snapshot.Value) else settings:SetAttribute(name,nil) end
		end
		if created then
			target:Destroy()
		else
			target.Source=oldSource
			target:SetAttribute("OwnedGarageEnvironmentRevision",oldRevision)
			target:SetAttribute("OwnedGarageEnvironmentRunId",oldRunId)
			target.Parent=oldParent
		end
		management.Source=oldManagementSource
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS preset="..tostring(settings:GetAttribute("InteriorEnvironmentPreset")).." driveOutVerify="..tostring(settings:GetAttribute("GarageDriveOutVerifySeconds")).."s promptRegistry=exactly-once runId="..RUN_ID)
print(TAG.." READY: restart Play and test immediate cached re-entry plus delayed re-entry. Exit from both vehicle slots, then confirm foot exit and the management desk still respond once per activation.")
