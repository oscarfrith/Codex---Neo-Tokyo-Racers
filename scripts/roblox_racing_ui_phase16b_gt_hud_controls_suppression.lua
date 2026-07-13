-- Neo Tokyo Racers - Racing UI Phase 16B GT HUD / Controls / Suppression
-- Paste into Roblox Studio Command Bar in Edit mode after Phase 16A.

local MODE="INSTALL" -- INSTALL or SMOKE
local PHASE="NTR Racing UI Phase 16B"
local MARKER="NTR_RACING_UI_PHASE16B_GT_HUD_CONTROLS_SUPPRESSION"
local StarterPlayer=game:GetService("StarterPlayer")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local function fail(m) error("["..PHASE.."] "..tostring(m),2) end local function log(m) print("["..PHASE.."] "..tostring(m)) end
local function roots() local ss=StarterPlayer:WaitForChild("StarterPlayerScripts") local ntr=ss:WaitForChild("NeoTokyoRacersClient") local c=ntr:WaitForChild("Controllers") return c:WaitForChild("UI"),c:WaitForChild("Racing") end
local function replaceOnce(s,a,b,label) local i,j=string.find(s,a,1,true) if not i then fail("Could not find "..label.." anchor. Refresh the mirror before another repair.") end return string.sub(s,1,i-1)..b..string.sub(s,j+1) end
local function replaceFunction(s,name,nextName,replacement) local i=string.find(s,"local function "..name,1,true) local j=i and string.find(s,"local function "..nextName,i+1,true) if not(i and j) then fail("Could not find "..name.." boundaries") end return string.sub(s,1,i-1)..replacement.."\n\n"..string.sub(s,j) end

local TT_BOARD=[==[local function renderTimeTrialBoard()
	clear(boardBody) boardTitle.Text="LAP TIMES"
	local pb=Instance.new("Frame") pb.BackgroundTransparency=1 pb.BorderSizePixel=0 pb.Size=UDim2.new(1,0,0,46) pb.Parent=boardBody
	UI.Label(pb,{Text="PERSONAL BEST",Position=UDim2.fromOffset(0,0),Size=UDim2.new(.56,0,1,0),TextSize=N("BoardTextSize",16),Color=C("Outline"),Role="Heading"})
	UI.Label(pb,{Text=timeText(active and active.PersonalBest),Position=UDim2.new(.56,0,0,0),Size=UDim2.new(.44,0,1,0),TextSize=N("BoardMetricSize",18),Color=C("Outline"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	for index,lap in ipairs(active and active.LapTimes or {}) do
		local rowH=N("BoardRowHeight",39) local y=58+(index-1)*rowH local row=Instance.new("Frame") row.BackgroundColor3=C("PanelDeep") row.BackgroundTransparency=index%2==0 and .48 or .64 row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,y) row.Size=UDim2.new(1,0,0,rowH-3) row.Parent=boardBody
		UI.Label(row,{Text=string.format("%02d",tonumber(lap.Lap) or index),Position=UDim2.fromOffset(8,0),Size=UDim2.new(.24,-8,1,0),TextSize=N("BoardTextSize",16),Color=C("Text"),Role="Heading"})
		UI.Label(row,{Text=timeText(lap.Elapsed),Position=UDim2.new(.34,0,0,0),Size=UDim2.new(.66,-8,1,0),TextSize=N("BoardMetricSize",18),Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	end
end]==]
local RACE_BOARD=[==[local function renderRaceBoard()
	clear(boardBody) boardTitle.Text="LIVE POSITIONS"
	for index,entry in ipairs(active and active.Positions or {}) do
		if index>6 then break end local rowH=N("BoardRowHeight",39) local y=(index-1)*rowH local row=Instance.new("Frame") local you=tonumber(entry.UserId)==player.UserId
		row.BackgroundColor3=you and C("PanelBlue") or C("PanelDeep") row.BackgroundTransparency=you and .18 or (index%2==0 and .48 or .64) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,y) row.Size=UDim2.new(1,0,0,rowH-3) row.Parent=boardBody
		local placeColor=index==1 and Color3.fromRGB(255,190,45) or index==2 and Color3.fromRGB(205,215,225) or index==3 and Color3.fromRGB(205,125,65) or (you and C("Telemetry") or C("Text"))
		UI.Label(row,{Text=tostring(entry.Place or index),Position=UDim2.fromOffset(6,0),Size=UDim2.fromOffset(30,rowH-3),TextSize=N("BoardTextSize",16),Color=placeColor,Role="Heading"})
		local avatarSize=N("BoardAvatarSize",30) avatar(row,entry.UserId,UDim2.fromOffset(38,(rowH-3-avatarSize)/2),UDim2.fromOffset(avatarSize,avatarSize))
		UI.Label(row,{Text=string.upper(tostring(entry.Name or "PLAYER")),Position=UDim2.fromOffset(48+avatarSize,0),Size=UDim2.new(1,-(56+avatarSize),1,0),TextSize=N("BoardTextSize",16),Color=you and C("Telemetry") or C("Text"),Role="Heading"})
	end
end]==]

local CONTROLS=[==[
local active=nil
local queueRequest=racingRemotes:WaitForChild("RaceQueueRequest")
local transitionRequest=script.Parent:FindFirstChild("RaceTransitionRequest")
local uiFolder=script.Parent.Parent:FindFirstChild("UI") local freeRoamMode=uiFolder and uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
local function presentationMode(enabled) if freeRoamMode and freeRoamMode:IsA("BindableEvent") then freeRoamMode:Fire(enabled and "Racing" or "FreeRoam") end end
local controls=Instance.new("Frame") controls.Name="SessionControls" controls.BackgroundTransparency=1 controls.AnchorPoint=Vector2.new(.5,1) controls.Position=UDim2.new(.5,0,1,-N("BottomY",30)) controls.Size=UDim2.fromOffset(360,44) controls.Parent=canvas
local resetButton=UI.Button(controls,{Text="RESET",Size=UDim2.new(.5,-6,1,0),Color=C("PanelDeep"),StrokeColor=C("Outline"),TextSize=13})
local exitButton=UI.Button(controls,{Text="EXIT",Position=UDim2.new(.5,6,0,0),Size=UDim2.new(.5,-6,1,0),Color=C("PanelDeep"),StrokeColor=C("Danger"),TextColor=C("Danger"),TextSize=13})
local modalShade=Instance.new("Frame") modalShade.Name="ExitConfirmationShade" modalShade.BackgroundColor3=Color3.new(0,0,0) modalShade.BackgroundTransparency=.34 modalShade.BorderSizePixel=0 modalShade.Size=UDim2.fromScale(1,1) modalShade.Visible=false modalShade.ZIndex=100 modalShade.Parent=canvas
local modal=UI.Panel(modalShade,{Name="ExitConfirmation",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(650,252),Color=C("PanelDeep"),Transparency=.04,StrokeColor=C("Outline"),StrokeTransparency=.02}) modal.ZIndex=101
local modalTitle=UI.Label(modal,{Text="EXIT RACE?",Position=UDim2.fromOffset(24,18),Size=UDim2.new(1,-48,0,38),TextSize=22,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalTitle.ZIndex=102
local modalCopy=UI.Label(modal,{Text="CURRENT PROGRESS WILL BE LOST.",Position=UDim2.fromOffset(24,70),Size=UDim2.new(1,-48,0,48),TextSize=13,Color=C("Muted"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalCopy.ZIndex=102
local noButton=UI.Button(modal,{Text="NO",Position=UDim2.fromOffset(30,168),Size=UDim2.fromOffset(270,54),Color=C("PanelDeep"),StrokeColor=C("Outline"),TextSize=13}) noButton.ZIndex=103
local yesButton=UI.Button(modal,{Text="YES, EXIT",Position=UDim2.fromOffset(350,168),Size=UDim2.fromOffset(270,54),Color=C("PanelDeep"),StrokeColor=C("Danger"),TextColor=C("Danger"),TextSize=13}) yesButton.ZIndex=103
local busy=false
local function transition(step,payload) if transitionRequest and transitionRequest:IsA("BindableEvent") then payload=payload or {} payload.Step=step transitionRequest:Fire(payload) end end
local function invokeSession(kind)
	if busy or not active then return end busy=true modalShade.Visible=false transition("FadeOut",{Reason=kind,Label=kind=="Reset" and "RESETTING" or "EXITING"}) task.wait(.25)
	local remote=active.Mode=="Race" and queueRequest or raceRequest local action=active.Mode=="Race" and (kind=="Reset" and "ResetToLastCheckpoint" or "ExitRaceToStart") or (kind=="Reset" and "ResetActiveTimeTrial" or "ExitActiveTimeTrial")
	local ok,result=pcall(function() return remote:InvokeServer(action,{RunId=active.RunId,EventId=active.EventId}) end) local success=ok and type(result)=="table" and (result.Ok==true or result.Success==true)
	transition("RestoreCamera",{Reason=kind}) transition("FadeIn",{Reason=kind,Delay=success and .3 or .08})
	if kind=="Reset" then resetButton.Text=success and "RESET DONE" or "RESET FAILED" task.delay(1.1,function() if resetButton.Parent then resetButton.Text="RESET" end busy=false end) else if not success then exitButton.Text="EXIT FAILED" task.delay(1.2,function() if exitButton.Parent then exitButton.Text="EXIT" end busy=false end) end end
end
resetButton.Activated:Connect(function() invokeSession("Reset") end)
exitButton.Activated:Connect(function() if not active then return end modalTitle.Text=active.Mode=="Race" and "EXIT RACE?" or "EXIT TIME TRIAL?" modalShade.Visible=true end)
noButton.Activated:Connect(function() modalShade.Visible=false end) yesButton.Activated:Connect(function() invokeSession("Exit") end)
]==]

local function patchFreeRoam(uiRoot)
	local item=uiRoot:FindFirstChild("DesktopFreeRoamHudController_Active") if not item then fail("Missing DesktopFreeRoamHudController_Active") end local s=item.Source
	if string.find(s,"NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE",1,true) then log("Free-roam presentation bridge already installed") return end
	s=replaceOnce(s,"local activeModal","local racingPresentationActive = false -- NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE\nlocal activeModal","free-roam presentation state")
	s=replaceOnce(s,"\tbottomActions.Visible = driving\n\tcontrolsButton.Visible = driving\n\texitButton.Visible = driving\n\ttelemetry.Visible = driving","\tactionBar.Visible = not racingPresentationActive\n\tif racingPresentationActive then carPanel.Visible = false end\n\tleftCluster.Visible = not racingPresentationActive and not carPanel.Visible\n\tbottomActions.Visible = driving and not racingPresentationActive\n\tcontrolsButton.Visible = driving and not racingPresentationActive\n\texitButton.Visible = driving and not racingPresentationActive\n\ttelemetry.Visible = driving","free-roam runtime visibility")
	local anchor="pcall(function() RunService:UnbindFromRenderStep(\"NTR_PCFreeRoamHudPhase1\") end)"
	local bridge=[==[local presentationEvent=script.Parent:FindFirstChild("FreeRoamHudPresentationMode")
if presentationEvent and presentationEvent:IsA("BindableEvent") then
	presentationEvent.Event:Connect(function(mode)
		racingPresentationActive=tostring(mode)=="Racing"
		if racingPresentationActive then carPanel.Visible=false closeChoiceList() closeModal() end
	end)
end

]==]
	s=replaceOnce(s,anchor,bridge..anchor,"free-roam bridge listener") item.Source=s log("Installed selective free-roam Racing presentation bridge")
end
local function patchRacing(racingRoot)
	local item=racingRoot:FindFirstChild("RaceSessionPresentationController_Active") if not item then fail("Missing Phase 16A RaceSessionPresentationController_Active") end local s=item.Source
	if string.find(s,MARKER,1,true) then log("GT HUD refinement already installed") return end
	s=replaceOnce(s,"-- NTR_RACING_UI_PHASE16A_SHARED_IN_RACE_HUD","-- NTR_RACING_UI_PHASE16A_SHARED_IN_RACE_HUD\n-- "..MARKER,"Phase 16B marker")
	s=replaceOnce(s,[=[local function suppress(active) for _,name in ipairs({"NTR_RaceHud","NTR_RaceHud_Phase3","NTR_RaceCheckpointBadge_Phase5D","NTR_RaceQueue_Phase8"})]=],[=[local function suppress(active) for _,name in ipairs({"NTR_RaceHud","NTR_RaceHud_Phase3","NTR_RaceCheckpointBadge_Phase5D","NTR_RaceQueue_Phase8","NTR_RaceSessionControls_Phase8D"})]=],"legacy suppression list")
	s=replaceOnce(s,"local function panel(name,pos,size) return UI.Panel(canvas,{Name=name,Position=pos,Size=size,Color=C(\"PanelDeep\"),Transparency=N(\"PanelTransparency\",.16),StrokeColor=C(\"Outline\"),StrokeTransparency=.16,Clips=true}) end","local function panel(name,pos,size) return UI.Panel(canvas,{Name=name,Position=pos,Size=size,Color=C(\"PanelDeep\"),Transparency=N(\"PanelTransparency\",.16),StrokeColor=C(\"Outline\"),StrokeTransparency=.16,Clips=true}) end\nlocal function borderless(object) object.BackgroundTransparency=1 for _,child in ipairs(object:GetChildren()) do if child:IsA(\"UIStroke\") then child.Transparency=1 end end return object end","borderless helper")
	s=replaceOnce(s,"local left=panel(\"LapProgress\",UDim2.fromOffset(N(\"EdgeX\",30),N(\"EdgeY\",30)),UDim2.fromOffset(N(\"ProgressWidth\",178),N(\"ProgressHeight\",92)))","local left=borderless(panel(\"LapProgress\",UDim2.fromOffset(N(\"ProgressOffsetX\",30),N(\"ProgressOffsetY\",105)),UDim2.fromOffset(N(\"ProgressWidth\",178),N(\"ProgressHeight\",92))))","lap position")
	s=replaceOnce(s,"local right=panel(\"SessionBoard\",UDim2.new(1,-N(\"EdgeX\",30)-N(\"BoardWidth\",340),0,N(\"EdgeY\",30)),UDim2.fromOffset(N(\"BoardWidth\",340),N(\"BoardHeight\",276)))","local right=borderless(panel(\"SessionBoard\",UDim2.new(1,-N(\"BoardOffsetX\",30)-N(\"BoardWidth\",380),0,N(\"BoardOffsetY\",38)),UDim2.fromOffset(N(\"BoardWidth\",380),N(\"BoardHeight\",300))))","GT board container")
	s=replaceOnce(s,"local map=panel(\"RaceMap\",UDim2.new(0,N(\"EdgeX\",30),1,-N(\"BottomY\",30)-N(\"MapHeight\",210)),UDim2.fromOffset(N(\"MapWidth\",280),N(\"MapHeight\",210))) map.BackgroundTransparency=1","local map=borderless(panel(\"RaceMap\",UDim2.new(0,N(\"MapOffsetX\",30),1,-N(\"MapOffsetY\",30)-N(\"MapHeight\",210)),UDim2.fromOffset(N(\"MapWidth\",280),N(\"MapHeight\",210))))","borderless map")
	s=replaceOnce(s,"local boardTitle=UI.Label(right,{Text=\"SESSION LAPS\",Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,24),TextSize=14,Color=C(\"Telemetry\"),Role=\"Heading\"})\nlocal boardBody=Instance.new(\"Frame\") boardBody.BackgroundTransparency=1 boardBody.Position=UDim2.fromOffset(12,38) boardBody.Size=UDim2.new(1,-24,1,-50) boardBody.Parent=right","local boardTitle=UI.Label(right,{Text=\"SESSION LAPS\",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,30),TextSize=N(\"BoardHeadingSize\",18),Color=C(\"Telemetry\"),Role=\"Heading\"})\nlocal boardBody=Instance.new(\"Frame\") boardBody.BackgroundTransparency=1 boardBody.Position=UDim2.fromOffset(0,38) boardBody.Size=UDim2.new(1,0,1,-38) boardBody.Parent=right\n"..CONTROLS,"GT board and controls")
	s=replaceOnce(s,"local active=nil\nlocal function show(payload,mode)","local function show(payload,mode)","shared active session scope")
	s=replaceFunction(s,"renderTimeTrialBoard()","renderRaceBoard()",TT_BOARD)
	s=replaceFunction(s,"renderRaceBoard()","refresh()",RACE_BOARD)
	s=replaceOnce(s,"canvas.Visible=true suppress(true) end","canvas.Visible=true suppress(true) presentationMode(true) end","presentation activation")
	s=replaceOnce(s,"local function hide(restoreLegacy) active=nil canvas.Visible=false if restoreLegacy~=false then suppress(false) end clear(boardBody) end","local function hide(restoreLegacy) active=nil canvas.Visible=false modalShade.Visible=false busy=false if restoreLegacy~=false then suppress(false) presentationMode(false) end clear(boardBody) end","presentation restore")
	item.Source=s log("Installed GT-style HUD, shared controls, exit modal and complete UI suppression")
end
local function setupConfig()
	local folder=ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing:WaitForChild("InRace")
	local values={ProgressOffsetX=30,ProgressOffsetY=105,BoardOffsetX=30,BoardOffsetY=38,BoardWidth=380,BoardHeight=300,BoardRowHeight=39,BoardHeadingSize=18,BoardTextSize=16,BoardMetricSize=18,BoardAvatarSize=30,MapOffsetX=30,MapOffsetY=30}
	for name,value in pairs(values) do local item=folder:FindFirstChild(name) or Instance.new("NumberValue") item.Name=name if item.Parent==nil then item.Value=value item.Parent=folder end end
end
local function install() local ui,racing=roots() local bridge=ui:FindFirstChild("FreeRoamHudPresentationMode") or Instance.new("BindableEvent") bridge.Name="FreeRoamHudPresentationMode" bridge.Parent=ui setupConfig() patchFreeRoam(ui) patchRacing(racing) end
local function smoke() local ui,racing=roots() local free=ui:FindFirstChild("DesktopFreeRoamHudController_Active") local hud=racing:FindFirstChild("RaceSessionPresentationController_Active") assert(ui:FindFirstChild("FreeRoamHudPresentationMode"),"Presentation event missing") assert(free and string.find(free.Source,"NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE",1,true),"Free-roam bridge missing") assert(hud and string.find(hud.Source,MARKER,1,true),"Phase 16B HUD marker missing") assert(string.find(hud.Source,"ExitConfirmationShade",1,true),"Exit modal missing") log("SMOKE PASS") end
if MODE=="INSTALL" then install() smoke() log("Install complete. Restart Play and test Race and Time Trial visibility, Reset, NO and YES EXIT.") elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE") end
