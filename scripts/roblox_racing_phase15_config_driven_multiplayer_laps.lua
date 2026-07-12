-- Neo Tokyo Racers - Racing Phase 15 Config-Driven Multiplayer Laps
-- Paste into Roblox Studio Command Bar in Edit mode.
--
-- Makes RaceCatalog.<Event>.Laps authoritative for circuit multiplayer races.
-- Preserves Phase 8H reset, Phase 11D finish cleanup, placement/reward ownership,
-- Phase 12 result snapshots, matchmaking, and the register-limited bootstrap.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing Phase 15"
local MARKER = "NTR_RACING_PHASE15_CONFIG_DRIVEN_MULTIPLAYER_LAPS"
local ServerScriptService = game:GetService("ServerScriptService")

local function fail(message) error("[" .. PHASE .. "] " .. tostring(message), 2) end
local function log(message) print("[" .. PHASE .. "] " .. tostring(message)) end
local function service()
	local ntr=ServerScriptService:FindFirstChild("NeoTokyoRacers") local services=ntr and ntr:FindFirstChild("Services") local racing=services and services:FindFirstChild("Racing")
	local item=racing and racing:FindFirstChild("RaceMatchmakingService_Active")
	if not (item and item:IsA("LuaSourceContainer")) then fail("Missing active RaceMatchmakingService_Active") end
	return item
end
local function replaceOnce(source,oldText,newText,label)
	local first,last=string.find(source,oldText,1,true) if not first then fail("Could not find "..label.." anchor. Refresh the mirror before another repair.") end
	return string.sub(source,1,first-1)..newText..string.sub(source,last+1)
end
local function replaceFunction(source,name,nextName,replacement)
	local first=string.find(source,"local function "..name,1,true) local nextAt=first and string.find(source,"local function "..nextName,first+1,true)
	if not (first and nextAt) then fail("Could not find "..name.." function boundaries") end
	return string.sub(source,1,first-1)..replacement.."\n\n"..string.sub(source,nextAt)
end
local function replaceAll(source,oldText,newText)
	local count,cursor,pieces=0,1,{}
	while true do
		local first,last=string.find(source,oldText,cursor,true)
		if not first then table.insert(pieces,string.sub(source,cursor)) break end
		table.insert(pieces,string.sub(source,cursor,first-1)) table.insert(pieces,newText) count+=1 cursor=last+1
	end
	return table.concat(pieces),count
end

local SORTED = [==[local function sortedPlacements(race)
	-- NTR_RACING_PHASE15_CONFIG_DRIVEN_MULTIPLAYER_LAPS
	local list = {}
	for _, entry in ipairs(race.Participants or {}) do table.insert(list, entry) end
	table.sort(list, function(a, b)
		if (a.Finished == true) ~= (b.Finished == true) then return a.Finished == true end
		if a.FinishPlace and b.FinishPlace then return a.FinishPlace < b.FinishPlace end
		local aLaps = tonumber(a.CompletedLapCount) or 0 local bLaps = tonumber(b.CompletedLapCount) or 0
		if aLaps ~= bLaps then return aLaps > bLaps end
		local aGate = tonumber(a.NextGateIndex) or 1 local bGate = tonumber(b.NextGateIndex) or 1
		if aGate ~= bGate then return aGate > bGate end
		return (tonumber(a.LastProgressElapsed) or 0) < (tonumber(b.LastProgressElapsed) or 0)
	end)
	return list
end]==]

local BROADCAST = [==[local function broadcastPositions(race)
	local placements = sortedPlacements(race)
	local payloadPositions = {}
	for index, entry in ipairs(placements) do
		entry.CurrentPlace = index
		table.insert(payloadPositions, {
			UserId = entry.Player.UserId,
			Name = entry.Player.DisplayName or entry.Player.Name,
			Place = index,
			Finished = entry.Finished == true,
			NextGateIndex = entry.NextGateIndex,
			CurrentLap = entry.CurrentLap or 1,
			CompletedLapCount = entry.CompletedLapCount or 0,
			LapTarget = race.LapTarget or 1,
			FinishElapsed = tonumber(entry.FinishElapsed),
			VehicleId = tostring(entry.SelectedVehicleId or ""),
			VehicleName = tostring(entry.VehicleDisplayName or entry.SelectedVehicleId or ""), -- NTR_RACING_UI_PHASE12_RESULT_SNAPSHOT_BRIDGE
		})
	end
	for _, entry in ipairs(race.Participants or {}) do
		fire(entry.Player, {
			Type = "RacePositionUpdate", RunId = race.RunId, Place = entry.CurrentPlace or 1,
			ParticipantCount = #race.Participants, CurrentLap = entry.CurrentLap or 1,
			CompletedLapCount = entry.CompletedLapCount or 0, LapTarget = race.LapTarget or 1,
			Positions = payloadPositions,
		})
		fireRace(entry.Player, {
			Type = "RacePositionUpdate", RunId = race.RunId, Place = entry.CurrentPlace or 1,
			ParticipantCount = #race.Participants, CurrentLap = entry.CurrentLap or 1,
			CompletedLapCount = entry.CompletedLapCount or 0, LapTarget = race.LapTarget or 1,
			Positions = payloadPositions,
		})
	end
end]==]

local FINISH = [==[local function finishEntry(race, entry)
	-- NTR_RACING_PHASE11D_FINISH_BOUNDARY
	if entry.Finished then return end
	entry.Finished = true entry.DNF = false entry.FinishElapsed = now() - race.StartClock entry.FinishPlace = race.NextFinishPlace race.NextFinishPlace += 1
	local finishVehicle = entry.Vehicle
	finishedReturnByPlayer[entry.Player] = { RunId=race.RunId, EventId=race.EventId, RouteId=race.RouteId, Target=returnCFrameForRoute(race.Route,"Race") }
	callSessionAssetService("RemoveParticipant", { RunId=race.RunId, UserId=entry.Player and entry.Player.UserId, Player=entry.Player, Vehicle=finishVehicle })
	fireActiveRaceVisibility(race)
	local rewardResult = callRaceRewardService("GrantRaceReward", { Player=entry.Player, RunId=race.RunId, EventId=race.EventId, RouteId=race.RouteId, Place=entry.FinishPlace, ParticipantCount=#race.Participants, Elapsed=entry.FinishElapsed }) or {}
	local payload = {
		Type="RaceFinished", RunId=race.RunId, EventId=race.EventId, RouteId=race.RouteId, DisplayName=race.DisplayName,
		Place=entry.FinishPlace, ParticipantCount=#race.Participants, Elapsed=entry.FinishElapsed,
		GateCount=race.GateCount, NextGateIndex=race.GateCount, CurrentLap=entry.CurrentLap or race.LapTarget or 1,
		CompletedLapCount=entry.CompletedLapCount or race.LapTarget or 1, LapTarget=race.LapTarget or 1,
		LapTimes=entry.LapTimes or {}, BestLapSeconds=entry.BestLapSeconds, BestLapIndex=entry.BestLapIndex,
		RaceMedal=rewardResult.Medal, RewardGranted=rewardResult.Granted==true, RewardAmount=tonumber(rewardResult.Amount) or 0,
		RewardMessage=tostring(rewardResult.Message or ""), SelectedVehicleId=tostring(entry.SelectedVehicleId or ""),
	}
	fire(entry.Player,payload) fireRace(entry.Player,payload) -- preserves Phase 12 presentation payload ownership
	task.delay(.45,function() if finishVehicle and finishVehicle.Parent and entry.Vehicle==finishVehicle then destroyVehicleAfterUnseat(entry.Player,finishVehicle) entry.Vehicle=nil end end)
	broadcastPositions(race)
	if allFinished(race) then task.delay(5,function() cleanupRace(race,"Finished") end) end
end]==]

local ADVANCE = [==[local function advanceCheckpoint(race, entry, touchedPart)
	if not (race and race.State=="Running" and entry and entry.Finished~=true) then return end
	local gate=RouteDefinition.GetGate(race.Route,entry.NextGateIndex) if not (gate and gate.Part==touchedPart) then return end
	local clock=now() if clock-(entry.LastTouchClock or 0)<.12 then return end
	entry.LastTouchClock=clock entry.LastProgressElapsed=clock-race.StartClock
	if gate.IsFinish then
		local lapElapsed=clock-(entry.LapStartedClock or race.StartClock or clock)
		entry.CompletedLapCount=(entry.CompletedLapCount or 0)+1 entry.LapTimes=entry.LapTimes or {}
		table.insert(entry.LapTimes,{Lap=entry.CompletedLapCount,Elapsed=lapElapsed})
		if not entry.BestLapSeconds or lapElapsed<entry.BestLapSeconds then entry.BestLapSeconds=lapElapsed entry.BestLapIndex=entry.CompletedLapCount end
		entry.LastCompletedGateIndex=gate.Index
		if entry.CompletedLapCount>=(race.LapTarget or 1) then finishEntry(race,entry) return end
		entry.CurrentLap=entry.CompletedLapCount+1 entry.LapStartedClock=clock entry.NextGateIndex=1
		callSessionAssetService("UpdateParticipantSegment",{RunId=race.RunId,UserId=entry.Player.UserId,CurrentSegment=0})
		local payload={Type="RaceLapCompleted",RunId=race.RunId,EventId=race.EventId,RouteId=race.RouteId,Lap=entry.CompletedLapCount,CurrentLap=entry.CurrentLap,LapTarget=race.LapTarget or 1,LapElapsed=lapElapsed,LapTimes=entry.LapTimes,BestLapSeconds=entry.BestLapSeconds,BestLapIndex=entry.BestLapIndex,NextGateIndex=1,GateCount=race.GateCount}
		fire(entry.Player,payload) fireRace(entry.Player,payload) broadcastPositions(race) return
	end
	entry.LastCompletedGateIndex=entry.NextGateIndex entry.NextGateIndex+=1
	callSessionAssetService("ApplyParticipants",{RunId=race.RunId,Participants={{Player=entry.Player,Vehicle=entry.Vehicle}}}) -- NTR_RACING_PHASE11E_CHECKPOINT_COLLISION_REAPPLY
	callSessionAssetService("UpdateParticipantSegment",{RunId=race.RunId,UserId=entry.Player.UserId,CurrentSegment=math.max(0,(tonumber(entry.NextGateIndex) or 1)-1)})
	local payload={Type="RaceCheckpoint",RunId=race.RunId,EventId=race.EventId,RouteId=race.RouteId,NextGateIndex=entry.NextGateIndex,GateCount=race.GateCount,CheckpointIndex=gate.Index,Elapsed=entry.LastProgressElapsed,LapElapsed=clock-(entry.LapStartedClock or race.StartClock or clock),CurrentLap=entry.CurrentLap or 1,LapTarget=race.LapTarget or 1}
	fire(entry.Player,payload) fireRace(entry.Player,payload) broadcastPositions(race)
end]==]

local function install()
	local item=service() local source=item.Source
	if string.find(source,MARKER,1,true) then log("Config-driven multiplayer laps already installed.") return end
	source=replaceFunction(source,"sortedPlacements(race)","broadcastPositions(race)",SORTED)
	source=replaceFunction(source,"broadcastPositions(race)","allFinished(race)",BROADCAST)
	source=replaceFunction(source,"finishEntry(race, entry)","advanceCheckpoint(race, entry, touchedPart)",FINISH)
	source=replaceFunction(source,"advanceCheckpoint(race, entry, touchedPart)","connectRouteTouches(route)",ADVANCE)
	source=replaceOnce(source,[=[				LastProgressElapsed = 0,]=],[=[				LastProgressElapsed = 0,
				CurrentLap = 1,
				CompletedLapCount = 0,
				LapTimes = {},]=],"participant lap state")
	local gateLine=[=[		GateCount = RouteDefinition.GetGateCount(queue.Route),]=]
	source=replaceOnce(source,gateLine,gateLine..[=[
		RouteType = tostring(queue.Summary.RouteType or queue.Route.RouteType or "Circuit"),
		LapTarget = tostring(queue.Summary.RouteType or queue.Route.RouteType or "Circuit") == "PointToPoint" and 1 or math.clamp(math.floor(tonumber(queue.Summary.Laps or queue.Summary.DefaultLapCount) or 1), 1, 99),]=],"race lap target")
	local clockLine=[=[		race.StartClock = now()]=]
	source=replaceOnce(source,clockLine,clockLine..[=[
		for _, entry in ipairs(participants) do entry.LapStartedClock = race.StartClock end]=],"lap start clock")
	local raceStart=string.find(source,"\tlocal race = {",1,true) if not raceStart then fail("Could not find race session table") end
	local prefix,suffix=string.sub(source,1,raceStart-1),string.sub(source,raceStart)
	local count
	suffix,count=replaceAll(suffix,"NextGateIndex = 1,","NextGateIndex = 1, CurrentLap = 1, LapTarget = race.LapTarget,")
	source=prefix..suffix
	if count<2 then fail("Expected at least two staged/started payload anchors, found "..tostring(count)) end
	item.Source=source log("Installed multiplayer lap lifecycle; updated "..tostring(count).." session payloads.")
end
local function smoke()
	local source=service().Source
	for _,needle in ipairs({MARKER,"RaceLapCompleted","LapTarget = race.LapTarget","CompletedLapCount","BestLapSeconds"}) do assert(string.find(source,needle,1,true),"Missing "..needle) end
	log("SMOKE PASS")
end
if MODE=="INSTALL" then install() smoke() log("Install complete. Restart Play and test Laps=1, 2, and 3.") elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE: "..tostring(MODE)) end
