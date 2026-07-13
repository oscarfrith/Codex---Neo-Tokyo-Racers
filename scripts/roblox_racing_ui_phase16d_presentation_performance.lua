-- Neo Tokyo Racers - Racing UI Phase 16D Presentation Performance
-- Paste into Roblox Studio Command Bar in Edit mode after confirmed Phase 16C2.

local MODE="INSTALL" -- INSTALL or SMOKE
local PHASE="NTR Racing UI Phase 16D"
local MARKER="NTR_RACING_UI_PHASE16D_PRESENTATION_PERFORMANCE"
local StarterPlayer=game:GetService("StarterPlayer")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local function fail(message) error("["..PHASE.."] "..tostring(message),2) end
local function log(message) print("["..PHASE.."] "..tostring(message)) end
local function ensure(parent,className,name)
	local item=parent:FindFirstChild(name)
	if item and not item:IsA(className) then fail(item:GetFullName().." must be a "..className) end
	if not item then item=Instance.new(className) item.Name=name item.Parent=parent end
	return item
end
local function defaultValue(parent,className,name,value)
	local item=ensure(parent,className,name)
	if item:GetAttribute("NTRConfigured")~=true then item.Value=value item:SetAttribute("NTRConfigured",true) end
	return item
end
local function replaceOnce(source,anchor,replacement,label)
	local first,last=string.find(source,anchor,1,true)
	if not first then fail("Could not find "..label.." anchor. Refresh the Studio mirror before another source repair.") end
	return string.sub(source,1,first-1)..replacement..string.sub(source,last+1)
end
local function replaceRange(source,startAnchor,endAnchor,replacement,label)
	local first=string.find(source,startAnchor,1,true)
	if not first then fail("Could not find "..label.." start anchor. Refresh the Studio mirror before another source repair.") end
	local nextStart=string.find(source,endAnchor,first+#startAnchor,true)
	if not nextStart then fail("Could not find "..label.." end anchor. Refresh the Studio mirror before another source repair.") end
	return string.sub(source,1,first-1)..replacement.."\n"..string.sub(source,nextStart)
end
local function controllers()
	local root=StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers")
	local racing=root:WaitForChild("Racing") local ui=root:WaitForChild("UI")
	local session=racing:FindFirstChild("RaceSessionPresentationController_Active")
	local assets=racing:FindFirstChild("RaceSessionAssetsClient_Active")
	local freeRoam=ui:FindFirstChild("DesktopFreeRoamHudController_Active")
	for name,item in pairs({RaceSessionPresentationController_Active=session,RaceSessionAssetsClient_Active=assets,DesktopFreeRoamHudController_Active=freeRoam}) do
		if not (item and item:IsA("LuaSourceContainer")) then fail("Missing "..name) end
	end
	return session,assets,freeRoam
end

local ARROW_SOURCE=[==[
-- NTR_RACING_PHASE11L_ARROW_VISUAL_PROXY_SYNC_V2_TRANSPARENCY_RESTORE
-- NTR_RACING_UI_PHASE16D_PRESENTATION_PERFORMANCE

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local player=Players.LocalPlayer
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingConfig=kit:WaitForChild("Config"):WaitForChild("Racing")
local performanceConfig=racingConfig:WaitForChild("PresentationPerformance")
local racingRemotes=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent=racingRemotes:WaitForChild("RaceEvent")

local sessionsByRunId={}
local localRuns={}
local routeCaches={}
local visibleSegments={}
local activeSignature=nil
local lastApplyClock=0

local function numberValue(name,fallback)
	local item=performanceConfig:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end
local function worldRoot() return Workspace:FindFirstChild("NeoTokyoRacersWorld") end
local function raceRoutesRoot() local world=worldRoot() return world and world:FindFirstChild("RaceRoutes") end
local function raceInstancesRoot() local world=worldRoot() return world and world:FindFirstChild("RaceInstances") end

local function parseSegmentFolder(folder)
	if not (folder and folder:IsA("Folder")) then return nil end
	local from=tonumber(folder:GetAttribute("SegmentFrom"))
	local to=folder:GetAttribute("SegmentTo")
	local key=tostring(folder:GetAttribute("SegmentKey") or folder.Name)
	if from==nil then
		local a,b=string.match(folder.Name,"^Checkpoint(%d+)%-(%d+)$")
		if a then from=tonumber(a) to=tonumber(b) key="Checkpoint"..a.."-"..b else
			a=string.match(folder.Name,"^Checkpoint(%d+)%-Finish$")
			if a then from=tonumber(a) to="Finish" key="Checkpoint"..a.."-Finish" end
		end
	end
	if from==nil then return nil end
	if tonumber(to)~=nil then to=tonumber(to) end
	return {Folder=folder,From=from,To=to,Key=key,Parts=nil,Visible=nil}
end

local function segmentParts(segment)
	if segment.Parts then return segment.Parts end
	local parts={}
	for _,item in ipairs(segment.Folder:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(parts,{Part=item,Original=tonumber(item:GetAttribute("NTR_ArrowOriginalTransparency")) or item.Transparency})
		end
	end
	segment.Parts=parts
	return parts
end

local function setSegmentVisible(segment,visible)
	if segment.Visible==visible then return end
	segment.Visible=visible
	for _,record in ipairs(segmentParts(segment)) do
		local item=record.Part
		if item.Parent then
			item.LocalTransparencyModifier=visible and 0 or 1
			if visible then item.Transparency=record.Original end
			item.CanCollide=false item.CanTouch=false item.CanQuery=false
		end
	end
end

local function routeCache(routeFolder)
	local cached=routeCaches[routeFolder]
	if cached then return cached end
	local arrowRoot=routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	cached={ArrowRoot=arrowRoot,ByIndex={},ByKey={},MaxFrom=0,Wraps=false,Behind=1,Ahead=1}
	if arrowRoot then
		cached.Behind=tonumber(arrowRoot:GetAttribute("SegmentWindowBehind")) or 1
		cached.Ahead=tonumber(arrowRoot:GetAttribute("SegmentWindowAhead")) or 1
		for _,child in ipairs(arrowRoot:GetChildren()) do
			local segment=parseSegmentFolder(child)
			if segment and child:GetAttribute("Enabled")~=false then
				cached.ByIndex[segment.From]=segment cached.ByKey[segment.Key]=segment
				if segment.From>cached.MaxFrom then cached.MaxFrom=segment.From end
				if segment.To==0 then cached.Wraps=true end
			end
		end
	end
	routeCaches[routeFolder]=cached
	return cached
end

local function desiredSegments(cached,segmentIndex)
	local desired={}
	local current=math.floor(tonumber(segmentIndex) or 0)
	for offset=-cached.Behind,cached.Ahead do
		local index=current+offset
		if cached.Wraps and cached.MaxFrom>0 then index=((index%(cached.MaxFrom+1))+(cached.MaxFrom+1))%(cached.MaxFrom+1) end
		local segment=cached.ByIndex[index]
		if segment then desired[segment]=true end
	end
	return desired
end

local function clearVisible()
	for segment in pairs(visibleSegments) do setSegmentVisible(segment,false) end
	table.clear(visibleSegments)
end

local function hideAllOnce()
	local routes=raceRoutesRoot()
	for _,routeFolder in ipairs(routes and routes:GetChildren() or {}) do
		local cached=routeCache(routeFolder)
		for _,segment in pairs(cached.ByKey) do setSegmentVisible(segment,false) end
		for _,item in ipairs(cached.ArrowRoot and cached.ArrowRoot:GetChildren() or {}) do
			if item:IsA("BasePart") then item.LocalTransparencyModifier=1 item.CanCollide=false item.CanTouch=false item.CanQuery=false end
		end
	end
end

local function participantSet(list)
	local set={}
	for _,userId in ipairs(list or {}) do local numeric=tonumber(userId) if numeric~=nil then set[numeric]=true end end
	return set
end
local function updateVisibilitySession(payload)
	local runId=tostring(payload.RunId or "") if runId=="" then return end
	if payload.Active==true then sessionsByRunId[runId]={RunId=runId,Participants=participantSet(payload.Participants or {})}
	else sessionsByRunId[runId]=nil localRuns[runId]=nil end
end
local function localIsParticipant(runId)
	local session=sessionsByRunId[tostring(runId or "")]
	return (session and session.Participants and session.Participants[player.UserId]==true) or localRuns[tostring(runId or "")]~=nil
end
local function bestLocalRun()
	for runId,state in pairs(localRuns) do if localIsParticipant(runId) then return runId,state end end
	return nil,nil
end
local function proxyFolderForRun(runId)
	local instances=raceInstancesRoot() local runFolder=instances and instances:FindFirstChild(tostring(runId or ""))
	local assets=runFolder and runFolder:FindFirstChild("SessionAssets")
	return assets and assets:FindFirstChild("ArrowBarrierProxies")
end
local function proxySegmentForRun(runId)
	local proxies=proxyFolderForRun(runId)
	local text=tostring(proxies and proxies:GetAttribute("ParticipantSegments") or "")
	local localUser=tostring(player.UserId)
	for userId,segment in string.gmatch(text,"([^:,]+):([^,]+)") do
		if tostring(userId)==localUser then local numeric=tonumber(segment) if numeric~=nil then return math.max(0,math.floor(numeric)) end end
	end
	return nil
end

local function apply(force)
	local runId,state=bestLocalRun()
	if not (runId and state and state.RouteId and state.RouteId~="") then
		if activeSignature~=nil or next(visibleSegments)~=nil then clearVisible() activeSignature=nil end
		return
	end
	local segmentIndex=proxySegmentForRun(runId)
	if segmentIndex==nil then segmentIndex=state.CurrentSegment or 0 end
	segmentIndex=math.max(0,math.floor(tonumber(segmentIndex) or 0))
	local signature=tostring(runId).."|"..tostring(state.RouteId).."|"..tostring(segmentIndex)
	if not force and signature==activeSignature then return end
	local routes=raceRoutesRoot() local routeFolder=routes and routes:FindFirstChild(state.RouteId)
	local cached=routeFolder and routeCache(routeFolder)
	if not (cached and cached.ArrowRoot) then clearVisible() activeSignature=signature return end
	local desired=desiredSegments(cached,segmentIndex)
	for segment in pairs(visibleSegments) do
		if not desired[segment] then setSegmentVisible(segment,false) visibleSegments[segment]=nil end
	end
	for segment in pairs(desired) do
		if not visibleSegments[segment] then setSegmentVisible(segment,true) visibleSegments[segment]=true end
	end
	state.LastAppliedSegment=segmentIndex activeSignature=signature
end

local function updateLocalRunFromPayload(payload)
	local runId=tostring(payload.RunId or "") if runId=="" then return end
	localRuns[runId]=localRuns[runId] or {RunId=runId,CurrentSegment=0}
	localRuns[runId].RouteId=tostring(payload.RouteId or localRuns[runId].RouteId or "")
	localRuns[runId].CurrentSegment=math.max(0,(tonumber(payload.NextGateIndex) or 1)-1)
end
local function removeLocalRun(runId) runId=tostring(runId or "") if runId~="" then localRuns[runId]=nil end end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload)~="table" then return end
	local kind=tostring(payload.Type or "")
	if kind=="RaceVisibilityUpdate" then updateVisibilitySession(payload) apply(false) return end
	if kind=="TimeTrialStaged" or kind=="TimeTrialStarted" or kind=="TimeTrialCheckpoint" or kind=="TimeTrialLapCompleted" or kind=="TimeTrialReset"
		or kind=="RaceStaged" or kind=="RaceStarted" or kind=="RaceCheckpoint" or kind=="RaceReset" then
		updateLocalRunFromPayload(payload) apply(false)
	elseif kind=="TimeTrialEnded" or kind=="TimeTrialFinished" or kind=="RaceFinished" or kind=="RaceEnded" or kind=="RaceDNF" or kind=="RaceExitedToStart" then
		removeLocalRun(payload.RunId) apply(false)
	end
end)

task.spawn(function()
	while true do
		local interval=math.max(.1,numberValue("ArrowProxyPollSeconds",.2))
		if next(localRuns)~=nil and os.clock()-lastApplyClock>=interval then lastApplyClock=os.clock() apply(false) end
		task.wait(math.min(interval,.2))
	end
end)

task.defer(hideAllOnce)
print("[NTR Racing Phase 16D] Incremental arrow visibility active.")
]==]

local MAP_RUNTIME=[==[local hudMapState={Enabled=false,Subject=nil,NextSubjectResolve=0}
local mapOpacityValue=config:FindFirstChild("MapOpacity")
if mapOpacityValue and mapOpacityValue:IsA("NumberValue") then
	mapOpacityValue.Changed:Connect(function(value) mapArt.ImageTransparency=1-math.clamp(tonumber(value) or .78,0,1) end)
end
local function resetHudMapMarker()
	displayedMapMarkerPosition=nil displayedMapMarkerHeading=nil playerMapMarker.Visible=false
end
local function clearHudMapState()
	hudMapState={Enabled=false,Subject=nil,NextSubjectResolve=0}
	resetHudMapMarker()
end
local function prepareHudMapSession(mode,eventId)
	local folder=hudMapConfig(mode,eventId)
	local routeId=routeIdFor(mode,eventId)
	local imageWidth=math.max(1,mapValue(folder,"ImageWidthPixels","NumberValue",1024))
	local imageHeight=math.max(1,mapValue(folder,"ImageHeightPixels","NumberValue",1024))
	local radians=math.rad(mapValue(folder,"MapRotationDegrees","NumberValue",0))
	hudMapState={
		Enabled=folder~=nil and mapValue(folder,"Enabled","BoolValue",false),Folder=folder,Mode=mode,EventId=tostring(eventId or ""),RouteId=routeId,
		Anchor=mapAnchor(folder,routeId),ImageWidth=imageWidth,ImageHeight=imageHeight,StudsPerPixel=math.max(.0001,mapValue(folder,"StudsPerPixel","NumberValue",1)),
		Radians=radians,Cos=math.cos(radians),Sin=math.sin(radians),FlipX=mapValue(folder,"FlipX","BoolValue",false),FlipY=mapValue(folder,"FlipY","BoolValue",false),
		StartPixelX=mapValue(folder,"StartPixelX","NumberValue",imageWidth*.5),StartPixelY=mapValue(folder,"StartPixelY","NumberValue",imageHeight*.5),
		Clamp=mapValue(folder,"ClampMarkersToMap","BoolValue",true),Smoothing=math.max(0,mapValue(folder,"Smoothing","NumberValue",12)),
		MarkerRotationOffset=mapValue(folder,"MarkerRotationOffsetDegrees","NumberValue",0),PlayerMarkerScale=math.max(.1,mapValue(folder,"PlayerMarkerScale","NumberValue",1)),
		Subject=mapSubject(),NextSubjectResolve=0,
	}
	mapArt.ImageTransparency=1-math.clamp(N("MapOpacity",.78),0,1)
end
local function updateHudMapMarker(dt)
	if not active then resetHudMapMarker() return end
	if hudMapState.Mode~=active.Mode or hudMapState.EventId~=tostring(active.EventId or "") then prepareHudMapSession(active.Mode,active.EventId) end
	local state=hudMapState
	if not (state.Enabled and state.Anchor) then resetHudMapMarker() return end
	local subject=state.Subject
	if not (subject and subject.Parent and subject:IsA("BasePart")) then
		if os.clock()<state.NextSubjectResolve then resetHudMapMarker() return end
		state.NextSubjectResolve=os.clock()+math.max(.1,mapValue(performanceConfig,"HudMapSubjectResolveSeconds","NumberValue",.5))
		state.Subject=mapSubject() subject=state.Subject
	end
	if not subject then resetHudMapMarker() return end
	local delta=subject.Position-state.Anchor
	local mappedX=delta.X*state.Cos-delta.Z*state.Sin local mappedY=delta.X*state.Sin+delta.Z*state.Cos
	if state.FlipX then mappedX=-mappedX end if state.FlipY then mappedY=-mappedY end
	local x=(state.StartPixelX+mappedX/state.StudsPerPixel)/state.ImageWidth
	local y=(state.StartPixelY+mappedY/state.StudsPerPixel)/state.ImageHeight
	local rendered=mapArt.AbsoluteSize
	if rendered.X>0 and rendered.Y>0 then
		local frameAspect=rendered.X/rendered.Y local imageAspect=state.ImageWidth/state.ImageHeight
		if imageAspect>frameAspect then local heightFraction=frameAspect/imageAspect y=(1-heightFraction)*.5+y*heightFraction else local widthFraction=imageAspect/frameAspect x=(1-widthFraction)*.5+x*widthFraction end
	end
	if state.Clamp then x=math.clamp(x,0,1) y=math.clamp(y,0,1) end
	local targetPosition=Vector2.new(x,y) local look=subject.CFrame.LookVector
	local lookX=look.X*state.Cos-look.Z*state.Sin local lookY=look.X*state.Sin+look.Z*state.Cos
	if state.FlipX then lookX=-lookX end if state.FlipY then lookY=-lookY end
	local targetHeading=math.deg(math.atan2(lookX,-lookY))+state.MarkerRotationOffset
	local alpha=state.Smoothing<=0 and 1 or math.clamp((dt or 1/60)*state.Smoothing,0,1)
	displayedMapMarkerPosition=displayedMapMarkerPosition and displayedMapMarkerPosition:Lerp(targetPosition,alpha) or targetPosition
	if displayedMapMarkerHeading==nil then displayedMapMarkerHeading=targetHeading end
	local headingDelta=(targetHeading-displayedMapMarkerHeading+180)%360-180 displayedMapMarkerHeading+=headingDelta*alpha
	local baseSize=math.max(8,mapValue(freeRoamMapLayout,"MapPlayerIconSize","NumberValue",22)) local size=baseSize*state.PlayerMarkerScale
	playerMapMarker.Size=UDim2.fromOffset(size,size) playerMapMarker.Position=UDim2.fromScale(displayedMapMarkerPosition.X,displayedMapMarkerPosition.Y)
	playerMapMarker.Rotation=displayedMapMarkerHeading playerMapMarker.Visible=mapArt.Image~=""
end]==]

local function setupConfig()
	local racing=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("Racing")
	local folder=ensure(racing,"Folder","PresentationPerformance")
	defaultValue(folder,"NumberValue","ArrowProxyPollSeconds",.2)
	defaultValue(folder,"NumberValue","HudMapSubjectResolveSeconds",.5)
	defaultValue(folder,"BoolValue","PauseFreeRoamMapDuringRace",true)
	defaultValue(folder,"BoolValue","PauseFreeRoamProfileDuringRace",true)
	return folder
end

local function requireAnchor(source,anchor,label)
	if not string.find(source,anchor,1,true) then fail("Preflight could not find "..label..". No controller sources were changed; refresh the Studio mirror before another repair.") end
end
local function preflight(session,assets,freeRoam)
	if not string.find(assets.Source,MARKER,1,true) then
		requireAnchor(assets.Source,"NTR_RACING_PHASE11L_ARROW_VISUAL_PROXY_SYNC_V2_TRANSPARENCY_RESTORE","confirmed Phase 11L arrow owner marker")
	end
	if not string.find(freeRoam.Source,MARKER,1,true) then
		requireAnchor(freeRoam.Source,"NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE","free-roam racing presentation bridge")
		requireAnchor(freeRoam.Source,'local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud")',"free-roam config")
		requireAnchor(freeRoam.Source,'\tlocal character = player.Character\n\tlocal characterRoot = character and character:FindFirstChild("HumanoidRootPart")',"free-roam minimap start")
		requireAnchor(freeRoam.Source,'\tif not driving then displayedBoostAlpha = 1 end',"free-roam minimap end")
		requireAnchor(freeRoam.Source,'if not profileReadPending and os.clock() - lastProfileRead >= L("ProfileRefreshSeconds", 2) then',"free-roam profile poll")
	end
	if not string.find(session.Source,MARKER,1,true) then
		requireAnchor(session.Source,"NTR_RACING_UI_PHASE16C2_MAP_OPACITY_EDGE_ALIGNMENT","confirmed Phase 16C2 marker")
		requireAnchor(session.Source,"local function resetHudMapMarker()","HUD map runtime start")
		requireAnchor(session.Source,"local function show(payload,mode)","HUD map runtime end")
		requireAnchor(session.Source,'mapArt.Image=hudMapImage(mode,active.EventId) resetHudMapMarker() canvas.Visible=true',"session cache preparation")
		requireAnchor(session.Source,'local function hide(restoreLegacy) active=nil canvas.Visible=false',"session cache cleanup")
	end
end

local function patchArrowController(item)
	if string.find(item.Source,MARKER,1,true) then log("Incremental arrow controller already installed") return end
	if not string.find(item.Source,"NTR_RACING_PHASE11L_ARROW_VISUAL_PROXY_SYNC_V2_TRANSPARENCY_RESTORE",1,true) then fail("Confirmed Phase 11L arrow owner marker missing") end
	item.Source=ARROW_SOURCE
	log("Replaced periodic full arrow traversal with cached incremental visibility")
end

local function patchFreeRoamController(item)
	local source=item.Source
	if string.find(source,MARKER,1,true) then log("Free-roam performance bridge already installed") return end
	if not string.find(source,"NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE",1,true) then fail("Confirmed free-roam racing presentation bridge missing") end
	source=replaceOnce(source,"-- NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT","-- NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT\n-- "..MARKER,"free-roam phase marker")
	source=replaceOnce(source,'local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud")','local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud")\nlocal racingPerformanceConfig = kit:WaitForChild("Config"):WaitForChild("Racing"):WaitForChild("PresentationPerformance")',"performance config")
	local mapStart='\tlocal character = player.Character\n\tlocal characterRoot = character and character:FindFirstChild("HumanoidRootPart")'
	local mapEnd='\tif not driving then displayedBoostAlpha = 1 end'
	local first=string.find(source,mapStart,1,true) local last=first and string.find(source,mapEnd,first+#mapStart,true)
	if not (first and last) then fail("Could not find bounded free-roam minimap runtime. Refresh the Studio mirror before another source repair.") end
	local oldMap=string.sub(source,first,last-1)
	local wrapped='\tif not (racingPresentationActive and readValue(racingPerformanceConfig, "PauseFreeRoamMapDuringRace", true) == true) then\n'..string.gsub(oldMap,'^\t','\t\t'):gsub('\n\t','\n\t\t')..'\n\tend\n'
	source=string.sub(source,1,first-1)..wrapped..string.sub(source,last)
	source=replaceOnce(source,'if not profileReadPending and os.clock() - lastProfileRead >= L("ProfileRefreshSeconds", 2) then','if not (racingPresentationActive and readValue(racingPerformanceConfig, "PauseFreeRoamProfileDuringRace", true) == true) and not profileReadPending and os.clock() - lastProfileRead >= L("ProfileRefreshSeconds", 2) then',"profile polling gate")
	if string.find(source,"endlocal ",1,true) then fail("Free-roam patch produced malformed endlocal boundary") end
	item.Source=source
	log("Paused hidden free-roam minimap and profile polling during race presentation")
end

local function patchSessionController(item)
	local source=item.Source
	if string.find(source,MARKER,1,true) then log("Cached session map already installed") return end
	if not string.find(source,"NTR_RACING_UI_PHASE16C2_MAP_OPACITY_EDGE_ALIGNMENT",1,true) then fail("Confirmed Phase 16C2 marker missing. Install/confirm Phase 16C2 first.") end
	source=replaceOnce(source,"-- NTR_RACING_UI_PHASE16C2_MAP_OPACITY_EDGE_ALIGNMENT","-- NTR_RACING_UI_PHASE16C2_MAP_OPACITY_EDGE_ALIGNMENT\n-- "..MARKER,"session phase marker")
	source=replaceOnce(source,'local racingConfig=kit.Config.Racing','local racingConfig=kit.Config.Racing\nlocal performanceConfig=racingConfig:WaitForChild("PresentationPerformance")',"session performance config")
	source=replaceRange(source,"local function resetHudMapMarker()","local function show(payload,mode)",MAP_RUNTIME,"HUD map runtime")
	source=replaceOnce(source,'mapArt.Image=hudMapImage(mode,active.EventId) resetHudMapMarker() canvas.Visible=true','prepareHudMapSession(mode,active.EventId) mapArt.Image=hudMapImage(mode,active.EventId) resetHudMapMarker() canvas.Visible=true',"session cache preparation")
	source=replaceOnce(source,'local function hide(restoreLegacy) active=nil canvas.Visible=false','local function hide(restoreLegacy) active=nil clearHudMapState() canvas.Visible=false',"session cache cleanup")
	if string.find(source,"endlocal ",1,true) then fail("Session patch produced malformed endlocal boundary") end
	item.Source=source
	log("Cached HUD map configuration, anchor, trigonometry, and vehicle subject")
end

local function smoke()
	local folder=ReplicatedStorage.NeoTokyoRacers.Config.Racing:FindFirstChild("PresentationPerformance")
	assert(folder and folder:FindFirstChild("ArrowProxyPollSeconds"),"Performance config missing")
	local session,assets,freeRoam=controllers()
	for name,item in pairs({Session=session,Assets=assets,FreeRoam=freeRoam}) do
		assert(string.find(item.Source,MARKER,1,true),name.." Phase 16D marker missing")
		assert(not string.find(item.Source,"endlocal ",1,true),name.." malformed endlocal boundary")
	end
	assert(string.find(assets.Source,"if not force and signature==activeSignature then return end",1,true),"Incremental arrow guard missing")
	assert(not string.find(assets.Source,"local function hideAll()",1,true),"Legacy repeating hideAll owner remains")
	assert(string.find(freeRoam.Source,"PauseFreeRoamProfileDuringRace",1,true),"Free-roam profile gate missing")
	assert(string.find(session.Source,"prepareHudMapSession",1,true),"HUD map session cache missing")
	log("SMOKE PASS")
end

if MODE=="INSTALL" then
	local session,assets,freeRoam=controllers()
	preflight(session,assets,freeRoam)
	setupConfig()
	patchArrowController(assets)
	patchFreeRoamController(freeRoam)
	patchSessionController(session)
	smoke()
	log("Install complete. Restart Play before testing.")
elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE: "..tostring(MODE)) end
