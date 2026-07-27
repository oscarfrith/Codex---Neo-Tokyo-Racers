-- NTR_DRIVE_TO_EARN_CASH_SERVICE_V1_1
-- Canonical server distance/reward owner. No client-authored distance, speed,
-- multiplier, reward, tier, price or maximum-speed value is accepted.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local ServerScriptService=game:GetService("ServerScriptService")
local Workspace=game:GetService("Workspace")

local REVISION="NTR_DRIVE_TO_EARN_CASH_V1_1"
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("DriveToEarnCash_EditAttributes")
local serverRoot=ServerScriptService:WaitForChild("NeoTokyoRacers")
local services=serverRoot:WaitForChild("Services")
local profileBindings=services:WaitForChild("Player"):WaitForChild("ProfileServiceBindings")
local executeEconomy=profileBindings:WaitForChild("ExecuteEconomyCommand")
local world=Workspace:WaitForChild("NeoTokyoRacersWorld")
local vehiclesRoot=world:WaitForChild("Runtime"):WaitForChild("PlayerVehicles")

local states={}
local shuttingDown=false
local totalSamples=0
local totalCommands=0
local totalGrantCommands=0
local activeLoopGeneration=0
local REASONS={
	"BaselineReset","PlayerLifecycle","ProfileNotLoaded","NoCharacter","Unseated",
	"NotRuntimeVehicle","VehicleMissing","OwnershipMismatch","VehicleIdentityMismatch",
	"VehicleNotOwned","VehicleNotCurrent","NotDriveReady","FrozenOrStaging","Parked","ExitCoasting",
	"TeleportOrTransition","GarageTransition","LoadingTransition","SessionChanged",
	"VehicleLifecycleChanged","SampleGap","Stationary","VerticalJump",
	"ImplausibleSegment","HourlyCap","CashCommandRejected","Busy",
}

local function number(name,fallback,minimum,maximum)
	local value=tonumber(config:GetAttribute(name)) or fallback
	if minimum~=nil then value=math.max(minimum,value) end
	if maximum~=nil then value=math.min(maximum,value) end
	return value
end

local function enabled()
	return config:GetAttribute("Enabled")~=false
end

local function newBuckets()
	return {}
end

local function bucketAdd(buckets,now,bucketSeconds,windowSeconds,amount)
	local slot=math.floor(now/bucketSeconds)
	buckets[slot]=(buckets[slot] or 0)+amount
	local minimumSlot=math.floor((now-windowSeconds)/bucketSeconds)-1
	for key in pairs(buckets) do if key<minimumSlot then buckets[key]=nil end end
end

local function bucketSum(buckets,now,bucketSeconds,windowSeconds)
	local minimumSlot=math.floor((now-windowSeconds)/bucketSeconds)
	local total=0
	for slot,value in pairs(buckets) do
		if slot>=minimumSlot then total+=value else buckets[slot]=nil end
	end
	return total
end

local function newState(player)
	local rejected={}
	for _,reason in ipairs(REASONS) do rejected[reason]=0 end
	return {
		Player=player,
		Generation=0,
		CreatedClock=os.clock(),
		BaselinePosition=nil,
		BaselineClock=nil,
		Vehicle=nil,
		VehicleId="",
		SessionGeneration=nil,
		SessionId="",
		RunId="",
		AccumulatedCash=0,
		AcceptedStuds=0,
		GrantedCash=0,
		Rejected=rejected,
		CapBuckets=newBuckets(),
		ProjectionBuckets=newBuckets(),
		LastTelemetryClock=0,
		LastGrantClock=0,
		LastReason="BaselineReset",
		LastVehicleIdentity="",
		LastSessionIdentity="",
		GrantSequence=0,
	}
end

local function stateFor(player)
	local state=states[player]
	if not state then state=newState(player) states[player]=state end
	return state
end

local function rootPart(vehicle)
	if not vehicle then return nil end
	local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
	return root and root:IsA("BasePart") and root or nil
end

local function vehicleFromSeat(seat)
	local current=seat
	while current and current~=vehiclesRoot do
		if current:IsA("Model") and current.Parent==vehiclesRoot then return current end
		current=current.Parent
	end
	return nil
end

local function transitionReason(player)
	if player:GetAttribute("NTR_RaceBrowserTeleporting")==true
		or player:GetAttribute("NTR_FreeRoamHudTeleporting")==true then
		return "TeleportOrTransition"
	end
	if player:GetAttribute("NTR_GarageSessionActive")==true
		or player:GetAttribute("NTR_DriveInCustomisationActive")==true
		or player:GetAttribute("NTR_OwnedGarageInside")==true
		or player:GetAttribute("NTR_Phase21InPrivateGarage")==true then
		return "GarageTransition"
	end
	-- These are denial-only presentation/lifecycle guards. They never establish
	-- positive eligibility and therefore cannot author a payable sample.
	if player:GetAttribute("NTR_StartScreenActive")==true then return "LoadingTransition" end
	return nil
end

local function resolve(player)
	if player.Parent~=Players then return nil,"PlayerLifecycle" end
	if player:GetAttribute("NTR_ProfileServiceLoaded")~=true then return nil,"ProfileNotLoaded" end
	local transition=transitionReason(player)
	if transition then return nil,transition end
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil,"NoCharacter" end
	local seat=humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat.Occupant==humanoid) then return nil,"Unseated" end
	local vehicle=vehicleFromSeat(seat)
	if not vehicle then return nil,"NotRuntimeVehicle" end
	local root=rootPart(vehicle)
	if not root or not root.Parent then return nil,"VehicleMissing" end
	if tonumber(vehicle:GetAttribute("OwnerUserId"))~=player.UserId
		or tonumber(vehicle:GetAttribute("DriverUserId"))~=player.UserId then
		return nil,"OwnershipMismatch"
	end
	local vehicleId=tostring(vehicle:GetAttribute("OwnedVehicleId") or "")
	if vehicleId=="" then return nil,"VehicleIdentityMismatch" end
	if vehicle:GetAttribute("DriveReady")~=true then return nil,"NotDriveReady" end
	if vehicle:GetAttribute("NTR_RaceFrozen")==true or root.Anchored then return nil,"FrozenOrStaging" end
	if vehicle:GetAttribute("ParkedShowcase")==true or vehicle:GetAttribute("NTR_ParkedFixed")==true then return nil,"Parked" end
	if vehicle:GetAttribute("NTR_ExitCoasting")==true then return nil,"ExitCoasting" end
	if vehicle:GetAttribute("NTR_RaceBrowserTeleportDespawn")==true
		or vehicle:GetAttribute("NTR_FreeRoamHudTeleportDespawn")==true then
		return nil,"TeleportOrTransition"
	end
	return {
		Player=player, Character=character, Humanoid=humanoid, Seat=seat,
		Vehicle=vehicle, Root=root, VehicleId=vehicleId,
		SessionGeneration=player:GetAttribute("NTR_ProfileSessionGeneration"),
		SessionId=tostring(player:GetAttribute("NTR_ProfileSessionId") or ""),
		RunId=tostring(vehicle:GetAttribute("NTR_RaceRunId") or ""),
	}
end

local function sameContext(a,b)
	return a and b
		and a.Player==b.Player and a.Character==b.Character and a.Humanoid==b.Humanoid
		and a.Seat==b.Seat and a.Vehicle==b.Vehicle and a.Root==b.Root
		and a.VehicleId==b.VehicleId and a.SessionGeneration==b.SessionGeneration
		and a.SessionId==b.SessionId and a.RunId==b.RunId
end

local function distanceFromBaseline(state,context)
	if not (state.BaselinePosition and context and context.Root and context.Root.Parent) then return 0 end
	local delta=context.Root.Position-state.BaselinePosition
	return Vector3.new(delta.X,0,delta.Z).Magnitude
end

local function reject(state,reason,studs,resetBaseline)
	reason=tostring(reason or "CashCommandRejected")
	state.Rejected[reason]=(state.Rejected[reason] or 0)+math.max(0,tonumber(studs) or 0)
	state.LastReason=reason
	if resetBaseline then
		state.Generation+=1
		state.BaselinePosition=nil
		state.BaselineClock=nil
		state.Vehicle=nil
		state.VehicleId=""
		state.RunId=""
	end
end

local function resetToContext(state,context,now,reason)
	reject(state,reason or "BaselineReset",0,true)
	state.BaselinePosition=context.Root.Position
	state.BaselineClock=now
	state.Vehicle=context.Vehicle
	state.VehicleId=context.VehicleId
	state.SessionGeneration=context.SessionGeneration
	state.SessionId=context.SessionId
	state.RunId=context.RunId
	state.LastVehicleIdentity=context.VehicleId.."|"..context.Vehicle:GetFullName().."|"..context.RunId
	state.LastSessionIdentity=tostring(context.SessionGeneration).."|"..context.SessionId
end

local function invokeEconomy(player,command)
	totalCommands+=1
	local ok,result=pcall(function() return executeEconomy:Invoke(player,command) end)
	if not ok then
		warn("[NTR Drive-To-Earn] ProfileService command error player="..player.Name.." error="..tostring(result))
		return {Ok=false,Success=false,RejectionReason="CashCommandRejected",Message=tostring(result)}
	end
	return typeof(result)=="table" and result
		or {Ok=false,Success=false,RejectionReason="CashCommandRejected",Message="Invalid command result."}
end

local function commandFor(context,action,amount,commandId)
	return {
		Version=1,
		Action=action,
		Amount=amount,
		Reason="DriveToEarnCash",
		ExpectedSessionGeneration=context.SessionGeneration,
		ExpectedSessionId=context.SessionId,
		Vehicle=context.Vehicle,
		VehicleId=context.VehicleId,
		RunId=context.RunId,
		CommandId=commandId,
	}
end

local function rejectionSummary(state)
	local rows={}
	for _,reason in ipairs(REASONS) do
		local value=state.Rejected[reason] or 0
		if value>0 then table.insert(rows,reason.."="..string.format("%.1f",value)) end
	end
	return #rows>0 and table.concat(rows,", ") or "none"
end

local function publishTelemetry(state,now,force)
	if not RunService:IsStudio() or config:GetAttribute("StudioTelemetryEnabled")~=true then return end
	local interval=number("TelemetryRefreshSeconds",2,0.5,30)
	if not force and now-state.LastTelemetryClock<interval then return end
	state.LastTelemetryClock=now
	local player=state.Player
	if player.Parent~=Players then return end
	local capWindow=number("CeilingWindowSeconds",3600,60,86400)
	local capBucket=number("CeilingBucketSeconds",60,1,capWindow)
	local cap=number("HourlyCashCeiling",35000,0,10000000)
	local capUsed=bucketSum(state.CapBuckets,now,capBucket,capWindow)
	local projectionWindow=number("ProjectionWindowSeconds",600,30,3600)
	local projectionBucket=number("ProjectionBucketSeconds",10,1,projectionWindow)
	local projectedStuds=bucketSum(state.ProjectionBuckets,now,projectionBucket,projectionWindow)
	local projectionElapsed=math.max(1,math.min(projectionWindow,now-state.CreatedClock))
	local projectedHourly=projectedStuds*number("CashPerAcceptedStud",0.10,0,10)*3600/projectionElapsed
	local currentElapsed=math.max(1,math.min(capWindow,now-state.CreatedClock))
	local currentHourly=capUsed*3600/currentElapsed
	player:SetAttribute("NTR_DriveCashTelemetryRevision",REVISION)
	player:SetAttribute("NTR_DriveCashAcceptedStuds",math.floor(state.AcceptedStuds*10+0.5)/10)
	player:SetAttribute("NTR_DriveCashRejectedStudsByReason",string.sub(rejectionSummary(state),1,900))
	player:SetAttribute("NTR_DriveCashAccumulatedUngranted",math.floor(state.AccumulatedCash*1000+0.5)/1000)
	player:SetAttribute("NTR_DriveCashGranted",state.GrantedCash)
	player:SetAttribute("NTR_DriveCashCurrentHourly",math.floor(currentHourly+0.5))
	player:SetAttribute("NTR_DriveCashProjectedHourly",math.floor(projectedHourly+0.5))
	player:SetAttribute("NTR_DriveCashCapUsage",cap>0 and math.floor((capUsed/cap)*1000+0.5)/10 or 0)
	player:SetAttribute("NTR_DriveCashCapUsed",capUsed)
	player:SetAttribute("NTR_DriveCashVehicleIdentity",string.sub(state.LastVehicleIdentity,1,240))
	player:SetAttribute("NTR_DriveCashSessionIdentity",string.sub(state.LastSessionIdentity,1,240))
	player:SetAttribute("NTR_DriveCashLastReason",state.LastReason)
end

local function processPlayer(player,now)
	totalSamples+=1
	local state=stateFor(player)
	local context,reason=resolve(player)
	if not context then
		reject(state,reason,0,true)
		publishTelemetry(state,now,false)
		return
	end

	local validation=invokeEconomy(player,commandFor(context,"ValidateDriveSample"))
	-- BindableFunction:Invoke is a yield boundary. Revalidate every lifecycle owner.
	local current,currentReason=resolve(player)
	if not sameContext(context,current) then
		reject(state,currentReason or "VehicleLifecycleChanged",distanceFromBaseline(state,current),true)
		publishTelemetry(state,now,false)
		return
	end
	if validation.Success~=true then
		reject(state,validation.RejectionReason or "CashCommandRejected",distanceFromBaseline(state,current),true)
		publishTelemetry(state,now,false)
		return
	end

	if state.Vehicle~=current.Vehicle or state.VehicleId~=current.VehicleId
		or state.SessionGeneration~=current.SessionGeneration or state.SessionId~=current.SessionId
		or state.RunId~=current.RunId or not state.BaselinePosition then
		resetToContext(state,current,now,"BaselineReset")
		publishTelemetry(state,now,false)
		return
	end

	local previousPosition=state.BaselinePosition
	local previousClock=state.BaselineClock or now
	local position=current.Root.Position
	local elapsed=now-previousClock
	state.BaselinePosition=position
	state.BaselineClock=now
	local delta=position-previousPosition
	local horizontal=Vector3.new(delta.X,0,delta.Z).Magnitude
	local vertical=math.abs(delta.Y)
	if elapsed<=0 or elapsed>number("MaximumSampleGapSeconds",2,0.25,10) then
		reject(state,"SampleGap",horizontal,true)
		publishTelemetry(state,now,false)
		return
	end
	if horizontal<number("MinimumAcceptedSegmentStuds",1,0,20) then
		reject(state,"Stationary",horizontal,false)
		publishTelemetry(state,now,false)
		return
	end
	local maxVertical=number("MaximumVerticalDeltaStuds",30,1,500)
	local maxRatio=number("MaximumVerticalToHorizontalRatio",1,0.1,10)
	if vertical>maxVertical or vertical/math.max(horizontal,0.001)>maxRatio then
		reject(state,"VerticalJump",horizontal,true)
		publishTelemetry(state,now,false)
		return
	end
	local maximumSegment=number("MaximumAcceptedSpeedStudsPerSecond",540,10,2000)*elapsed
		+ number("SegmentToleranceStuds",12,0,200)
	if horizontal>maximumSegment then
		reject(state,"ImplausibleSegment",horizontal,true)
		publishTelemetry(state,now,false)
		return
	end

	state.AcceptedStuds+=horizontal
	state.LastReason="Accepted"
	local projectionWindow=number("ProjectionWindowSeconds",600,30,3600)
	local projectionBucket=number("ProjectionBucketSeconds",10,1,projectionWindow)
	bucketAdd(state.ProjectionBuckets,now,projectionBucket,projectionWindow,horizontal)
	state.AccumulatedCash+=horizontal*number("CashPerAcceptedStud",0.10,0,10)

	local batch=math.max(1,math.floor(number("VisibleGrantBatchCash",1,1,10000)))
	local desired=math.floor(state.AccumulatedCash/batch)*batch
	local grantInterval=number("MinimumGrantIntervalSeconds",0.5,0.5,5)
	if desired>0 and now-state.LastGrantClock>=grantInterval then
		-- A $1 batch changes the visibility threshold, not the command count:
		-- all payable whole Cash is coalesced into at most one command per interval.
		state.LastGrantClock=now
		local capWindow=number("CeilingWindowSeconds",3600,60,86400)
		local capBucket=number("CeilingBucketSeconds",60,1,capWindow)
		local cap=math.max(0,math.floor(number("HourlyCashCeiling",35000,0,10000000)))
		local capUsed=bucketSum(state.CapBuckets,now,capBucket,capWindow)
		local maximumCommand=math.max(1,math.floor(number("MaximumDriveGrantPerCommand",1000,1,100000)))
		local available=math.max(0,cap-capUsed)
		local grant=math.min(desired,available,maximumCommand)
		grant=math.floor(grant/batch)*batch
		if grant<=0 then
			reject(state,"HourlyCap",0,false)
			state.AccumulatedCash=math.min(state.AccumulatedCash,batch-0.001)
		else
			state.AccumulatedCash-=grant
			state.GrantSequence+=1
			local commandId=table.concat({
				"Drive",tostring(current.SessionGeneration),current.SessionId,current.VehicleId,
				tostring(state.Generation),tostring(state.GrantSequence),
			},":")
			totalGrantCommands+=1
			local result=invokeEconomy(player,commandFor(current,"GrantDriveCash",grant,commandId))
			-- The commit call is another yield boundary. Revalidate before retaining
			-- a movement baseline, regardless of whether the commit succeeded.
			local after,afterReason=resolve(player)
			if result.Success==true then
				local committed=math.max(0,math.floor(tonumber(result.Amount) or 0))
				state.GrantedCash+=committed
				bucketAdd(state.CapBuckets,now,capBucket,capWindow,committed)
			else
				state.AccumulatedCash=math.min(state.AccumulatedCash+grant,batch-0.001)
				reject(state,result.RejectionReason or "CashCommandRejected",0,false)
			end
			if not sameContext(current,after) then
				reject(state,afterReason or "VehicleLifecycleChanged",0,true)
			end
		end
	end
	publishTelemetry(state,now,false)
end

local function clearTelemetry(player)
	for _,name in ipairs({
		"NTR_DriveCashTelemetryRevision","NTR_DriveCashAcceptedStuds",
		"NTR_DriveCashRejectedStudsByReason","NTR_DriveCashAccumulatedUngranted",
		"NTR_DriveCashGranted","NTR_DriveCashCurrentHourly",
		"NTR_DriveCashProjectedHourly","NTR_DriveCashCapUsage","NTR_DriveCashCapUsed",
		"NTR_DriveCashVehicleIdentity","NTR_DriveCashSessionIdentity","NTR_DriveCashLastReason",
	}) do player:SetAttribute(name,nil) end
end

Players.PlayerRemoving:Connect(function(player)
	states[player]=nil
end)

script:SetAttribute("Revision",REVISION)
script:SetAttribute("Authority","ServerDistance/ProfileServiceCash")
script:SetAttribute("NoClientPayableInputs",true)
script:SetAttribute("RuntimeAuditStatus","Starting")
activeLoopGeneration+=1
local loopGeneration=activeLoopGeneration
task.spawn(function()
	local nextAudit=os.clock()+number("RuntimeAuditIntervalSeconds",30,5,600)
	while not shuttingDown and loopGeneration==activeLoopGeneration do
		task.wait(number("SampleIntervalSeconds",0.5,0.1,5))
		local now=os.clock()
		if enabled() then
			for _,player in ipairs(Players:GetPlayers()) do processPlayer(player,now) end
		else
			for player,state in pairs(states) do
				reject(state,"LoadingTransition",0,true)
				publishTelemetry(state,now,false)
			end
		end
		if RunService:IsStudio() and now>=nextAudit then
			local count=0
			for _ in pairs(states) do count+=1 end
			script:SetAttribute("RuntimeAuditStatus","PASS")
			script:SetAttribute("ActivePlayerStates",count)
			script:SetAttribute("TotalSamples",totalSamples)
			script:SetAttribute("TotalProfileCommands",totalCommands)
			script:SetAttribute("TotalGrantCommands",totalGrantCommands)
			print(string.format(
				"[NTR Drive-To-Earn Runtime Audit] PASS players=%d samples=%d commands=%d grants=%d rate=%.4f batch=%d grantMaxHz=%.2f cap=%d/%ds noRemotes=true",
				count,totalSamples,totalCommands,totalGrantCommands,number("CashPerAcceptedStud",0.10,0,10),
				math.floor(number("VisibleGrantBatchCash",1,1,10000)),
				1/number("MinimumGrantIntervalSeconds",0.5,0.5,5),
				math.floor(number("HourlyCashCeiling",35000,0,10000000)),
				math.floor(number("CeilingWindowSeconds",3600,60,86400))))
			nextAudit=now+number("RuntimeAuditIntervalSeconds",30,5,600)
		end
	end
end)

game:BindToClose(function()
	shuttingDown=true
	activeLoopGeneration+=1
end)

if not RunService:IsStudio() then
	for _,player in ipairs(Players:GetPlayers()) do clearTelemetry(player) end
end
print("[NTR Drive-To-Earn] Service active; server-owned distance, ProfileService Cash command, rolling cap, and Studio-only telemetry ready.")
