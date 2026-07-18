-- Neo Tokyo Racers - Unified Race Flow: Countdown, Queue, Exit and Menu Ownership
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Run INSTALL, restart Play, verify on PC/mobile and with two players, then run SMOKE.

local MODE="INSTALL" -- INSTALL or SMOKE
local PHASE="NTR Unified Race Flow"
local MARKER="NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP"
local VISUAL_MARKER="NTR_RACING_FLOW_COUNTDOWN_VISUAL_V2"
local GUIDE_MARKER="NTR_RACING_FLOW_COUNTDOWN_GUIDE_GATE_V2"

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")

local function fail(message) error("["..PHASE.."] "..tostring(message),2) end
local function log(message) print("["..PHASE.."] "..tostring(message)) end
local function must(parent,name,className) local item=parent:FindFirstChild(name) if not item or (className and not item:IsA(className)) then fail("Missing "..parent:GetFullName().."."..name) end return item end
local function replaceOnce(source,anchor,replacement,label)
	if string.find(source,replacement,1,true) then return source end
	local first,last=string.find(source,anchor,1,true) if not first then fail("Missing "..label.." anchor. No source was changed; refresh the mirror before another repair.") end
	return string.sub(source,1,first-1)..replacement..string.sub(source,last+1)
end
local function replaceRange(source,startAnchor,endAnchor,replacement,label)
	local first=string.find(source,startAnchor,1,true) if not first then fail("Missing "..label.." start anchor") end
	local nextStart=string.find(source,endAnchor,first+#startAnchor,true) if not nextStart then fail("Missing "..label.." end anchor") end
	return string.sub(source,1,first-1)..replacement.."\n"..string.sub(source,nextStart)
end
local function value(parent,className,name,default)
	local item=parent:FindFirstChild(name)
	if not item then item=Instance.new(className) item.Name=name item.Value=default item.Parent=parent elseif not item:IsA(className) then fail(item:GetFullName().." must be "..className) end
	return item
end

local kit=must(ReplicatedStorage,"NeoTokyoRacers")
local racingConfig=must(must(kit,"Config"),"Racing")
local services=must(must(ServerScriptService,"NeoTokyoRacers"),"Services")
local serverRacing=must(services,"Racing")
local garage=must(services,"Garage")
local client=must(must(StarterPlayer,"StarterPlayerScripts"),"NeoTokyoRacersClient")
local controllers=must(client,"Controllers")
local racing=must(controllers,"Racing")

local timeTrial=must(serverRacing,"TimeTrialService_Active","Script")
local matchmaking=must(serverRacing,"RaceMatchmakingService_Active","Script")
local garageAction=must(garage,"GarageActionController_Shadow_Disabled","Script")
local session=must(racing,"RaceSessionPresentationController_Active","LocalScript")
local queueClient=must(racing,"RaceQueueClient_Active","LocalScript")
local results=must(racing,"RaceTimeTrialResultCoachClient_Active","LocalScript")
local browser=must(racing,"RaceBrowserClient_Active","LocalScript")
local entry=must(racing,"RaceEntryPresentationController_Active","LocalScript")
local routeGuide=must(racing,"RaceRouteGuideClient_Active","LocalScript")

local QUEUE_SOURCE=[==[
-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
-- Compact queue action/presentation owner. It never owns post-race results.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared=kit:WaitForChild("Shared")
local remotes=shared:WaitForChild("Remotes"):WaitForChild("Racing")
local request=remotes:WaitForChild("RaceQueueRequest")
local event=remotes:WaitForChild("RaceQueueEvent")
local startRequest=script.Parent:WaitForChild("StartRaceQueueRequest")
local UI=require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local C=UI.Colour
local config=kit.Config.Racing:WaitForChild("FlowUI")
local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end
local function call(action,payload) local ok,result=pcall(function() return request:InvokeServer(action,payload or {}) end) return ok and type(result)=="table" and result or {Ok=false,Success=false,Message=tostring(result or "Queue request failed.")} end
local function publish(open) local folder=script.Parent.Parent:FindFirstChild("UI") local signal=folder and folder:FindFirstChild("FreeRoamHudPresentationMode") if signal and signal:IsA("BindableEvent") then signal:Fire({Owner="RaceQueue",Active=open==true,KeepTelemetry=true}) end end
local function drivingHandoff() local folder=script.Parent.Parent:FindFirstChild("UI") local signal=folder and folder:FindFirstChild("FreeRoamVehicleSpawned") if signal and signal:IsA("BindableEvent") then signal:Fire() end end
local function stream(routeId,index) local world=Workspace:FindFirstChild("NeoTokyoRacersWorld") local routes=world and world:FindFirstChild("RaceRoutes") local route=routes and routes:FindFirstChild(tostring(routeId or "")) local gate=route and (route:FindFirstChild("Checkpoint"..tostring(index or 1),true) or route:FindFirstChild("FinishLine",true)) if gate and gate:IsA("BasePart") then pcall(function() player:RequestStreamAroundAsync(gate.Position,3) end) end end

local old=playerGui:FindFirstChild("NTR_RaceQueue_Phase8") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="NTR_RaceQueueBanner" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=190 gui.Parent=playerGui
local canvas=Instance.new("Frame") canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local function resize() local camera=Workspace.CurrentCamera local v=camera and camera.ViewportSize or Vector2.new(1920,1080) scale.Scale=math.min(v.X/1920,v.Y/1080) end resize() if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
local width=N("QueueBannerWidth",720) local height=N("QueueBannerHeight",86)
local panel=UI.Panel(canvas,{Name="QueueBanner",Position=UDim2.new(.5,-width/2,0,N("QueueBannerTop",24)),Size=UDim2.fromOffset(width,height),Color=C("PanelDeep"),Transparency=.10,StrokeColor=C("Outline"),StrokeTransparency=.05,Clips=true}) panel.Visible=false
local title=UI.Label(panel,{Text="RACE QUEUE",Position=UDim2.fromOffset(18,8),Size=UDim2.new(.42,-18,0,24),TextSize=15,Color=C("Text"),Role="Heading"})
local status=UI.Label(panel,{Text="WAITING FOR RACERS",Position=UDim2.fromOffset(18,36),Size=UDim2.new(.58,-18,0,30),TextSize=18,Color=C("Telemetry"),Role="Metric"})
local details=UI.Label(panel,{Text="0 / 0",Position=UDim2.new(.58,0,0,12),Size=UDim2.new(.22,-8,0,52),TextSize=14,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
local leave=UI.Button(panel,{Text="LEAVE",Position=UDim2.new(.80,0,0,14),Size=UDim2.new(.18,-14,0,56),Color=C("PanelDeep"),StrokeColor=C("Danger"),TextColor=C("Danger"),TextSize=13})
local queued=false
local currentEventName="RACE QUEUE"
local function hide() queued=false panel.Visible=false publish(false) end
local function show(payload,message) queued=true panel.Visible=true publish(true) if payload.DisplayName and tostring(payload.DisplayName)~="" then currentEventName=string.upper(tostring(payload.DisplayName)) end title.Text=currentEventName status.Text=string.upper(tostring(message or payload.Message or "WAITING FOR RACERS")) details.Text=tostring(payload.Count or 0).." / "..tostring(payload.MaxPlayers or 0).."\n"..tostring(payload.SecondsRemaining or 0).."s" end
startRequest.Event:Connect(function(payload) payload=type(payload)=="table" and payload or {} currentEventName=string.upper(tostring(payload.DisplayName or "RACE QUEUE")) player:SetAttribute("NTR_LastRacingEventId",tostring(payload.EventId or "")) player:SetAttribute("NTR_LastRacingVehicleId",tostring(payload.VehicleId or "")) show(payload,"JOINING QUEUE") local result=call("JoinQueue",{EventId=payload.EventId,VehicleId=payload.VehicleId}) if result.Ok~=true and result.Success~=true then status.Text=string.upper(tostring(result.Message or "QUEUE FAILED")) task.delay(2,function() if not player:GetAttribute("NTR_RaceQueueActive") then hide() end end) end end)
leave.Activated:Connect(function() if not queued then return end leave.Active=false status.Text="LEAVING QUEUE" local result=call("LeaveQueue",{}) leave.Active=true if result.Ok~=true and result.Success~=true then status.Text=string.upper(tostring(result.Message or "LEAVE FAILED")) end end)
event.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end local kind=tostring(payload.Type or "")
	if kind=="QueueJoined" or kind=="QueueUpdate" then show(payload)
	elseif kind=="QueueLeft" or kind=="RaceQueueError" then hide()
	elseif kind=="RaceStaged" then hide()
	elseif kind=="RaceStarted" then hide() task.defer(stream,payload.RouteId,payload.NextGateIndex or 1) task.defer(drivingHandoff) task.delay(.25,drivingHandoff)
	elseif kind=="RaceFinished" or kind=="RaceDNF" or kind=="RaceEnded" or kind=="RaceExitedToStart" then hide() end
end)
print("[NTR Unified Race Flow] Compact queue banner active.")
]==]

local COUNTDOWN_SOURCE=[==[
-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
-- NTR_RACING_FLOW_COUNTDOWN_VISUAL_V2
-- Shared responsive 5-to-GO countdown for Race and Time Trial.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local event=kit.Shared.Remotes.Racing:WaitForChild("RaceEvent")
local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents"))
local C=UI.Colour
local config=kit.Config.Racing:WaitForChild("FlowUI")
local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end
local old=playerGui:FindFirstChild("NTR_RaceCountdown") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="NTR_RaceCountdown" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=205 gui.Parent=playerGui
local canvas=Instance.new("Frame") canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local function resize() local camera=Workspace.CurrentCamera local v=camera and camera.ViewportSize or Vector2.new(1920,1080) scale.Scale=math.min(v.X/1920,v.Y/1080) end resize() if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
local size=N("CountdownCardSize",260)
local card=Instance.new("Frame") card.Name="CountdownCard" card.AnchorPoint=Vector2.new(.5,.5) card.Position=UDim2.fromScale(.5,.5) card.Size=UDim2.fromOffset(size,size) card.BackgroundColor3=C("PanelDeep") card.BackgroundTransparency=N("CountdownCardTransparency",.18) card.BorderSizePixel=0 card.ClipsDescendants=true card.Visible=false card.Parent=canvas
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,18) corner.Parent=card
local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C("PanelBlue")),ColorSequenceKeypoint.new(.52,C("PanelDeep")),ColorSequenceKeypoint.new(1,C("PanelSoft"))}) gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.52,.18),NumberSequenceKeypoint.new(1,.05)}) gradient.Rotation=N("CountdownGradientRotation",115) gradient.Parent=card
local heading=UI.Label(card,{Text="GET READY",Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,38),TextSize=18,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
local number=UI.Label(card,{Text="5",Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(1,1),TextSize=N("CountdownTextSize",130),Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Center}) number.TextXAlignment=Enum.TextXAlignment.Center number.TextYAlignment=Enum.TextYAlignment.Center
local token=0
local function hide() token+=1 card.Visible=false end
local function show(text,isGo) token+=1 local mine=token card.Visible=true heading.Text=isGo and "" or "GET READY" number.Text=text number.TextSize=isGo and N("GoTextSize",96) or N("CountdownTextSize",130) number.TextColor3=isGo and C("Telemetry") or C("Text") if isGo then task.delay(N("GoDuration",.85),function() if token==mine then card.Visible=false end end) end end
event.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end local kind=tostring(payload.Type or "")
	if kind=="TimeTrialStaged" or kind=="RaceStaged" then show(tostring(payload.Countdown or N("CountdownSeconds",5)),false)
	elseif kind=="TimeTrialCountdown" or kind=="RaceCountdown" then show(tostring(payload.Countdown or ""),false)
	elseif kind=="TimeTrialStarted" or kind=="RaceStarted" then show("GO!",true)
	elseif kind=="TimeTrialFinished" or kind=="TimeTrialEnded" or kind=="TimeTrialError" or kind=="RaceFinished" or kind=="RaceDNF" or kind=="RaceEnded" or kind=="RaceExitedToStart" then hide() end
end)
print("[NTR Unified Race Flow] Central countdown active.")
]==]

local function preflight()
	local targets={timeTrial,matchmaking,garageAction,session,results,browser,entry,queueClient}
	local marked=0
	for _,item in ipairs(targets) do if string.find(item.Source,MARKER,1,true) then marked+=1 end end
	local countdown=racing:FindFirstChild("RaceCountdownPresentationController_Active")
	local countdownMarked=countdown and countdown:IsA("LocalScript") and string.find(countdown.Source,MARKER,1,true)~=nil
	local visualV2=countdownMarked and string.find(countdown.Source,VISUAL_MARKER,1,true)~=nil
	local guideV2=string.find(routeGuide.Source,GUIDE_MARKER,1,true)~=nil
	if marked==#targets and countdownMarked and visualV2 and guideV2 then return nil,true end
	local cleanInstall=marked==0 and not countdownMarked and not guideV2
	local upgradeV1=marked==#targets and countdownMarked and not visualV2 and not guideV2
	if not cleanInstall and not upgradeV1 then fail("Partial unified race-flow install detected. Restore the immediately preceding Studio version before rerunning; no source was changed.") end
	local sources={}
	sources.routeGuide=replaceOnce(routeGuide.Source,[[	if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" or kind == "TimeTrialStarted" or kind == "RaceStaged" or kind == "RaceCountdown" or kind == "RaceStarted" then
		setActive(payload)
	elseif kind == "TimeTrialCheckpoint" or kind == "RaceCheckpoint" then]],[[	if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" or kind == "RaceStaged" or kind == "RaceCountdown" then
		clearActive() -- NTR_RACING_FLOW_COUNTDOWN_GUIDE_GATE_V2: hide checkpoint guidance until GO.
	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		setActive(payload)
	elseif kind == "TimeTrialCheckpoint" or kind == "RaceCheckpoint" then]],"route-guide countdown gate")
	if upgradeV1 then sources.upgradeOnly=true return sources,false end
	if not string.find(queueClient.Source,"NTR_RACING_PHASE8_QUEUE_CLIENT",1,true) then fail("Unknown queue client baseline") end
	sources.timeTrial=replaceOnce(timeTrial.Source,"local COUNTDOWN_SECONDS = 3",[[local flowUI=kit.Config.Racing:WaitForChild("FlowUI")
local countdownValue=flowUI:WaitForChild("CountdownSeconds")
local COUNTDOWN_SECONDS=math.max(1,math.floor(tonumber(countdownValue.Value) or 5))]],"time-trial countdown")
	sources.matchmaking=replaceOnce(matchmaking.Source,"local queue = queues[eventId]\n\tqueuedByPlayer[player] = nil","local queue = queues[eventId]\n\tqueuedByPlayer[player] = nil\n\tplayer:SetAttribute(\"NTR_RaceQueueActive\",false)","queue leave lock release")
	sources.matchmaking=replaceOnce(sources.matchmaking,"for _, player in ipairs(queue.Players) do\n\t\tqueuedByPlayer[player] = nil","for _, player in ipairs(queue.Players) do\n\t\tqueuedByPlayer[player] = nil\n\t\tplayer:SetAttribute(\"NTR_RaceQueueActive\",false)","queue start lock release")
	sources.matchmaking=replaceOnce(sources.matchmaking,"queuedByPlayer[player] = eventId\n\tfire(player, {","queuedByPlayer[player] = eventId\n\tplayer:SetAttribute(\"NTR_RaceQueueActive\",true)\n\tfire(player, {","queue join lock")
	sources.garage=replaceOnce(garageAction.Source,"V56_invoke.OnServerInvoke = function(player, action, args)\n\t\targs = typeof(args) == \"table\" and args or {}","V56_invoke.OnServerInvoke = function(player, action, args)\n\t\targs = typeof(args) == \"table\" and args or {}\n\t\tif player:GetAttribute(\"NTR_RaceQueueActive\")==true and (action==\"SelectVehicleInstance\" or action==\"SpawnOwnedVehicleFromFreeRoam\" or action==\"SpawnVehicle\" or action==\"DespawnVehicle\") then return {Ok=false,Success=false,Message=\"Leave the race queue before changing vehicles.\"} end","garage queue vehicle lock")
	sources.session=replaceOnce(session.Source,"elseif kind==\"TimeTrialReset\" then if active then active.LapLocalStart=os.clock() end","elseif kind==\"TimeTrialReset\" then refresh() -- "..MARKER..": preserve lap clock on checkpoint reset","shared reset timer")
	sources.results=replaceOnce(results.Source,[[footerButtons("EXIT TO START","TRY AGAIN",function() hide() fireDrivingExit() local result=invoke(raceRequest,"ExitFinishedTimeTrial",{}) if result.Ok~=true and result.Success~=true then invoke(raceRequest,"CancelTimeTrial",{}) end end]],[[footerButtons("EXIT TO START","TRY AGAIN",function() complete.Text="EXITING..." local result=invoke(raceRequest,"ExitFinishedTimeTrial",{}) if result.Ok==true or result.Success==true then fireDrivingExit() hide() else complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end end]],"time-trial result exit")
	sources.results=replaceOnce(sources.results,[[footerButtons("EXIT TO START","RACE AGAIN",function() hide() invoke(queueRequest,"ExitRaceToStart",{}) end]],[[footerButtons("EXIT TO START","RACE AGAIN",function() complete.Text="EXITING..." local result=invoke(queueRequest,"ExitRaceToStart",{}) if result.Ok==true or result.Success==true then hide() else complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end end]],"race result exit")
	sources.results=replaceOnce(sources.results,[[elseif kind=="TimeTrialEnded" and not overlay.Visible then show("TimeTrial",{DisplayName="TIME TRIAL",EventId=tostring(player:GetAttribute("NTR_LastRacingEventId") or payload.EventId or ""),SelectedVehicleId=tostring(player:GetAttribute("NTR_LastRacingVehicleId") or ""),LapTarget=tonumber(player:GetAttribute("NTR_LastRacingLapCount")) or 1,VehicleTier="--",FinishReason="Quit",RewardAmount=0,LapTimes={},CanRetry=true})]],[[elseif kind=="TimeTrialEnded" then hide() -- no fallback result reopen]],"time-trial fallback result")
	sources.results=replaceRange(sources.results,"local close=UI.Button(shell,","local divider=Instance.new(\"Frame\")","-- "..MARKER..": results exit is footer-only.","results header close")
	sources.browser=replaceRange(browser.Source,"local close = UI.Button(shell, {","local divider = Instance.new(\"Frame\")","-- "..MARKER..": browser exit is footer-only.","browser header close")
	sources.entry=replaceRange(entry.Source,"local close = UI.Button(shell, { Text =","local divider = Instance.new(\"Frame\")","-- "..MARKER..": entry exit/back is footer-only.","entry header close")
	return sources,false
end

local function ensureConfig()
	local flow=racingConfig:FindFirstChild("FlowUI") if not flow then flow=Instance.new("Folder") flow.Name="FlowUI" flow.Parent=racingConfig end
	value(flow,"NumberValue","CountdownSeconds",5).Value=5
	value(flow,"NumberValue","CountdownCardSize",260)
	value(flow,"NumberValue","CountdownTextSize",130)
	value(flow,"NumberValue","GoTextSize",96)
	value(flow,"NumberValue","GoDuration",.85)
	value(flow,"NumberValue","CountdownCardTransparency",.18)
	value(flow,"NumberValue","CountdownGradientRotation",115)
	value(flow,"NumberValue","QueueBannerWidth",720)
	value(flow,"NumberValue","QueueBannerHeight",86)
	value(flow,"NumberValue","QueueBannerTop",24)
	value(must(racingConfig,"Matchmaking"),"NumberValue","CountdownSeconds",5).Value=5
	return flow
end

local function install()
	local sources,already=preflight() ensureConfig()
	if already then log("Already installed; refreshed countdown configuration.") return end
	if sources.upgradeOnly then
		routeGuide.Source=sources.routeGuide
		local countdown=must(racing,"RaceCountdownPresentationController_Active","LocalScript") countdown.Source=COUNTDOWN_SOURCE countdown.Disabled=false
		log("Upgraded the existing unified race flow with the borderless gradient countdown, centred countdown text, and checkpoint-guide countdown gate.")
		return
	end
	timeTrial.Source="-- "..MARKER.."\n"..sources.timeTrial
	matchmaking.Source="-- "..MARKER.."\n"..sources.matchmaking
	garageAction.Source="-- "..MARKER.."\n"..sources.garage
	session.Source="-- "..MARKER.."\n"..sources.session
	results.Source="-- "..MARKER.."\n"..sources.results
	browser.Source="-- "..MARKER.."\n"..sources.browser
	entry.Source="-- "..MARKER.."\n"..sources.entry
	routeGuide.Source=sources.routeGuide
	queueClient.Source=QUEUE_SOURCE queueClient.Disabled=false
	local countdown=racing:FindFirstChild("RaceCountdownPresentationController_Active") if not countdown then countdown=Instance.new("LocalScript") countdown.Name="RaceCountdownPresentationController_Active" countdown.Parent=racing end countdown.Source=COUNTDOWN_SOURCE countdown.Disabled=false
	log("Installed unified borderless-gradient 5-to-GO countdown, countdown checkpoint-guide gate, compact queue banner, queue vehicle lock, footer-only exits, exclusive presentation, and cross-platform TT reset timer preservation.")
end

local function smoke()
	local flow=must(racingConfig,"FlowUI","Folder") if must(flow,"CountdownSeconds","NumberValue").Value~=5 then fail("CountdownSeconds must be 5") end
	for _,item in ipairs({timeTrial,matchmaking,garageAction,session,results,browser,entry,queueClient}) do if not string.find(item.Source,MARKER,1,true) then fail(item.Name.." marker missing") end end
	local countdown=must(racing,"RaceCountdownPresentationController_Active","LocalScript") if countdown.Disabled or not string.find(countdown.Source,MARKER,1,true) then fail("Countdown owner missing") end
	if not string.find(countdown.Source,VISUAL_MARKER,1,true) then fail("Countdown visual V2 missing") end
	if not string.find(routeGuide.Source,GUIDE_MARKER,1,true) then fail("Checkpoint guide is not gated during countdown") end
	if string.find(results.Source,"TimeTrialEnded\" and not overlay.Visible",1,true) then fail("Fallback result reopen remains") end
	if string.find(session.Source,"TimeTrialReset\" then if active then active.LapLocalStart=os.clock()",1,true) then fail("TT reset still restarts HUD clock") end
	if string.find(results.Source,"local close=UI.Button(shell,",1,true) or string.find(browser.Source,"local close = UI.Button(shell, {",1,true) or string.find(entry.Source,"local close = UI.Button(shell, { Text =",1,true) then fail("A racing header X remains") end
	if not string.find(matchmaking.Source,"player:SetAttribute(\"NTR_RaceQueueActive\",true)",1,true) or not string.find(garageAction.Source,"Leave the race queue before changing vehicles.",1,true) then fail("Queued vehicle lock is incomplete") end
	for _,name in ipairs({"RaceClient_Active","RaceSessionControlsClient_Active","RaceHudExitCleanupClient_Active"}) do if not must(racing,name,"LocalScript").Disabled then fail(name.." must remain retired") end end
	log("SMOKE PASS: borderless gradient countdown=5 with centred text, checkpoint guide gated until GO, queue banner/lock active, footer-only menu exits active, old result fallback removed, legacy owners retired, and TT reset preserves the shared PC/mobile lap timer.")
end

if MODE=="INSTALL" then install() elseif MODE=="SMOKE" then smoke() else fail("MODE must be INSTALL or SMOKE") end
