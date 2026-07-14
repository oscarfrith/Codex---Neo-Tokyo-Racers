-- NTR_RACING_UI_PHASE16F_STREAMING_SAFE_ARROWS
-- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
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

local function applyPart(record,visible)
	local item=record.Part
	if not item.Parent then return end
	item.LocalTransparencyModifier=visible and 0 or 1
	if visible then item.Transparency=record.Original end
	item.CanCollide=false item.CanTouch=false item.CanQuery=false
end

local function registerSegmentPart(segment,item)
	if not item:IsA("BasePart") or segment.PartSet[item] then return end
	segment.PartSet[item]=true
	local record={Part=item,Original=tonumber(item:GetAttribute("NTR_ArrowOriginalTransparency")) or 0}
	table.insert(segment.Parts,record)
	applyPart(record,segment.Visible==true)
end

local function segmentParts(segment)
	if segment.Parts then return segment.Parts end
	segment.Parts={}
	segment.PartSet=setmetatable({},{__mode="k"})
	for _,item in ipairs(segment.Folder:GetDescendants()) do registerSegmentPart(segment,item) end
	segment.DescendantAdded=segment.Folder.DescendantAdded:Connect(function(item)
		registerSegmentPart(segment,item)
	end)
	return segment.Parts
end

local function setSegmentVisible(segment,visible)
	segment.Visible=visible
	for _,record in ipairs(segmentParts(segment)) do applyPart(record,visible) end
end


local function routeCache(routeFolder)
	local cached=routeCaches[routeFolder]
	if cached and cached.ArrowRoot and cached.ArrowRoot.Parent then return cached end
	local arrowRoot=routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	if not arrowRoot then routeCaches[routeFolder]=nil return nil end
	cached={ArrowRoot=arrowRoot,ByIndex={},ByKey={},MaxFrom=0,Wraps=false,Behind=tonumber(arrowRoot:GetAttribute("SegmentWindowBehind")) or 1,Ahead=tonumber(arrowRoot:GetAttribute("SegmentWindowAhead")) or 1}
	local function registerSegment(child)
		local segment=parseSegmentFolder(child)
		if not segment or child:GetAttribute("Enabled")==false then return end
		cached.ByIndex[segment.From]=segment cached.ByKey[segment.Key]=segment
		if segment.From>cached.MaxFrom then cached.MaxFrom=segment.From end
		if segment.To==0 then cached.Wraps=true end
		segmentParts(segment)
	end
	for _,child in ipairs(arrowRoot:GetChildren()) do registerSegment(child) end
	cached.ChildAdded=arrowRoot.ChildAdded:Connect(function(child)
		registerSegment(child)
		activeSignature=nil
	end)
	cached.ChildRemoved=arrowRoot.ChildRemoved:Connect(function()
		routeCaches[routeFolder]=nil
		activeSignature=nil
	end)
	routeCaches[routeFolder]=cached
	return cached
end

local function normalizedRouteId(value)
	return string.lower((tostring(value or ""):gsub("[^%w]","")))
end

local function findRouteFolder(routes,routeId)
	if not routes then return nil end
	local exact=routes:FindFirstChild(tostring(routeId or ""))
	if exact then return exact end
	local wanted=normalizedRouteId(routeId)
	if wanted=="" then return nil end
	for _,candidate in ipairs(routes:GetChildren()) do
		if normalizedRouteId(candidate.Name)==wanted or normalizedRouteId(candidate:GetAttribute("RouteId"))==wanted then return candidate end
	end
	return nil
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
		if cached then
			for _,segment in pairs(cached.ByKey) do setSegmentVisible(segment,false) end
			for _,item in ipairs(cached.ArrowRoot:GetChildren()) do
				if item:IsA("BasePart") then item.LocalTransparencyModifier=1 item.CanCollide=false item.CanTouch=false item.CanQuery=false end
			end
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
	local routes=raceRoutesRoot() local routeFolder=findRouteFolder(routes,state.RouteId)
	local cached=routeFolder and routeCache(routeFolder)
	if not (cached and cached.ArrowRoot) then clearVisible() activeSignature=nil return end
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
