-- Neo Tokyo Racers - Racing UI Phase 16B2 HUD Visual Alignment
-- Paste into Roblox Studio Command Bar in Edit mode after Phase 16B.

local MODE="INSTALL" -- INSTALL or SMOKE
local PHASE="NTR Racing UI Phase 16B2"
local MARKER="NTR_RACING_UI_PHASE16B2_HUD_VISUAL_ALIGNMENT"
local StarterPlayer=game:GetService("StarterPlayer") local ReplicatedStorage=game:GetService("ReplicatedStorage")
local function fail(m) error("["..PHASE.."] "..tostring(m),2) end local function log(m) print("["..PHASE.."] "..tostring(m)) end
local function controller() local ss=StarterPlayer:WaitForChild("StarterPlayerScripts") local root=ss:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing") local item=root:FindFirstChild("RaceSessionPresentationController_Active") if not item then fail("Missing RaceSessionPresentationController_Active") end return item end
local function replaceOnce(s,a,b,label) local i,j=string.find(s,a,1,true) if not i then fail("Could not find "..label.." anchor. Refresh the mirror before another repair.") end return string.sub(s,1,i-1)..b..string.sub(s,j+1) end
local function replaceFunction(s,name,nextName,replacement) local i=string.find(s,"local function "..name,1,true) local j=i and string.find(s,"local function "..nextName,i+1,true) if not(i and j) then fail("Could not find "..name.." boundaries") end return string.sub(s,1,i-1)..replacement.."\n\n"..string.sub(s,j) end

local TT_BOARD=[==[local function renderTimeTrialBoard()
	clear(boardBody)
	local rowH=N("DataRowHeight",42) local gap=N("DataRowGap",5)
	local pb=dataRow(boardBody,0,rowH)
	UI.Label(pb,{Text="PERSONAL BEST",Position=UDim2.fromOffset(10,0),Size=UDim2.new(.56,-10,1,0),TextSize=N("DataRowTextSize",16),Color=C("Outline"),Role="Heading"})
	UI.Label(pb,{Text=timeText(active and active.PersonalBest),Position=UDim2.new(.56,0,0,0),Size=UDim2.new(.44,-10,1,0),TextSize=N("DataRowMetricSize",18),Color=C("Outline"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	for index,lap in ipairs(active and active.LapTimes or {}) do
		local row=dataRow(boardBody,rowH+gap+(index-1)*(rowH+gap),rowH)
		UI.Label(row,{Text=string.format("%02d",tonumber(lap.Lap) or index),Position=UDim2.fromOffset(10,0),Size=UDim2.new(.24,-10,1,0),TextSize=N("DataRowTextSize",16),Color=C("Text"),Role="Heading"})
		UI.Label(row,{Text=timeText(lap.Elapsed),Position=UDim2.new(.34,0,0,0),Size=UDim2.new(.66,-10,1,0),TextSize=N("DataRowMetricSize",18),Color=C("Text"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	end
end]==]
local RACE_BOARD=[==[local function renderRaceBoard()
	clear(boardBody)
	local rowH=N("DataRowHeight",42) local gap=N("DataRowGap",5)
	for index,entry in ipairs(active and active.Positions or {}) do
		if index>6 then break end local row=dataRow(boardBody,(index-1)*(rowH+gap),rowH) local you=tonumber(entry.UserId)==player.UserId
		if you then row.BackgroundColor3=C("PanelBlue") row.BackgroundTransparency=N("LocalRowTransparency",.24) end
		local place=tonumber(entry.Place) or index
		UI.Label(row,{Text=tostring(place),Position=UDim2.fromOffset(8,0),Size=UDim2.fromOffset(30,rowH),TextSize=N("DataRowTextSize",16),Color=placementColor(place),Role="Heading"})
		local avatarSize=N("BoardAvatarSize",30) avatar(row,entry.UserId,UDim2.fromOffset(40,(rowH-avatarSize)/2),UDim2.fromOffset(avatarSize,avatarSize))
		UI.Label(row,{Text=string.upper(tostring(entry.Name or "PLAYER")),Position=UDim2.fromOffset(50+avatarSize,0),Size=UDim2.new(1,-(60+avatarSize),1,0),TextSize=N("DataRowTextSize",16),Color=you and C("Telemetry") or C("Text"),Role="Heading"})
	end
end]==]

local function setupConfig()
	local folder=ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing:WaitForChild("InRace")
	local values={MetricCardTransparency=.34,MetricCardCornerRadius=9,MetricHeadingSize=15,MetricValueSize=36,DataRowHeight=42,DataRowGap=5,DataRowTransparency=.42,DataRowCornerRadius=7,DataRowTextSize=16,DataRowMetricSize=18,LocalRowTransparency=.24}
	for name,value in pairs(values) do local item=folder:FindFirstChild(name) or Instance.new("NumberValue") item.Name=name if item.Parent==nil then item.Value=value item.Parent=folder end end
	local colors={FirstPlaceColor=Color3.fromRGB(255,190,45),SecondPlaceColor=Color3.fromRGB(205,215,225),ThirdPlaceColor=Color3.fromRGB(205,125,65)}
	for name,value in pairs(colors) do local item=folder:FindFirstChild(name) or Instance.new("Color3Value") item.Name=name if item.Parent==nil then item.Value=value item.Parent=folder end end
end
local function install()
	setupConfig() local item=controller() local s=item.Source
	if string.find(s,MARKER,1,true) then log("Phase 16B2 already installed") return end
	if not string.find(s,"NTR_RACING_UI_PHASE16B_GT_HUD_CONTROLS_SUPPRESSION",1,true) then fail("Phase 16B marker missing; install Phase 16B first") end
	s=replaceOnce(s,"-- NTR_RACING_UI_PHASE16B_GT_HUD_CONTROLS_SUPPRESSION","-- NTR_RACING_UI_PHASE16B_GT_HUD_CONTROLS_SUPPRESSION\n-- "..MARKER,"Phase 16B2 marker")
	local helperAnchor="local function borderless(object) object.BackgroundTransparency=1 for _,child in ipairs(object:GetChildren()) do if child:IsA(\"UIStroke\") then child.Transparency=1 end end return object end"
	local helpers=helperAnchor..[==[
local function metricCard(object)
	object.BackgroundColor3=C("PanelSoft") object.BackgroundTransparency=N("MetricCardTransparency",.34)
	for _,child in ipairs(object:GetChildren()) do if child:IsA("UIStroke") then child.Transparency=1 elseif child:IsA("UIGradient") then child:Destroy() end end
	local corner=object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner") corner.CornerRadius=UDim.new(0,N("MetricCardCornerRadius",9)) corner.Parent=object
	local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new(C("PanelSoft"),C("PanelDeep")) gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(1,.28)}) gradient.Rotation=90 gradient.Parent=object
	return object
end
local function dataRow(parent,y,height)
	local row=Instance.new("Frame") row.BackgroundColor3=C("PanelSoft") row.BackgroundTransparency=N("DataRowTransparency",.42) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,y) row.Size=UDim2.new(1,0,0,height) row.Parent=parent
	local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,N("DataRowCornerRadius",7)) corner.Parent=row
	local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new(C("PanelSoft"),C("PanelDeep")) gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.03),NumberSequenceKeypoint.new(1,.22)}) gradient.Rotation=90 gradient.Parent=row return row
end
local function placementColor(place)
	place=tonumber(place) local name=place==1 and "FirstPlaceColor" or place==2 and "SecondPlaceColor" or place==3 and "ThirdPlaceColor" or nil
	local item=name and config:FindFirstChild(name) if item and item:IsA("Color3Value") then return item.Value end
	if place==1 then return Color3.fromRGB(255,190,45) elseif place==2 then return Color3.fromRGB(205,215,225) elseif place==3 then return Color3.fromRGB(205,125,65) end return C("Text")
end]==]
	s=replaceOnce(s,helperAnchor,helpers,"shared metric/data components")
	s=replaceOnce(s,"local left=borderless(panel(\"LapProgress\",UDim2.fromOffset(N(\"ProgressOffsetX\",30),N(\"ProgressOffsetY\",105)),UDim2.fromOffset(N(\"ProgressWidth\",178),N(\"ProgressHeight\",92))))","local left=metricCard(panel(\"LapProgress\",UDim2.fromOffset(N(\"ProgressOffsetX\",30),N(\"ProgressOffsetY\",105)),UDim2.fromOffset(N(\"ProgressWidth\",178),N(\"ProgressHeight\",92))))","lap metric card")
	s=replaceOnce(s,"local center=panel(\"PrimaryMetric\",UDim2.new(.5,-N(\"MetricWidth\",300)/2,0,N(\"EdgeY\",30)),UDim2.fromOffset(N(\"MetricWidth\",300),N(\"MetricHeight\",92)))","local center=metricCard(panel(\"PrimaryMetric\",UDim2.new(.5,-N(\"MetricWidth\",300)/2,0,N(\"EdgeY\",30)),UDim2.fromOffset(N(\"MetricWidth\",300),N(\"MetricHeight\",92))))","centre metric card")
	s=replaceOnce(s,"local lapHeading=UI.Label(left,{Text=\"LAP\",Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,22),TextSize=12,Color=C(\"Muted\"),Role=\"Heading\"})","local lapHeading=UI.Label(left,{Text=\"LAP\",Position=UDim2.fromOffset(0,6),Size=UDim2.new(1,0,0,26),TextSize=N(\"MetricHeadingSize\",15),Color=C(\"Text\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Center})","lap heading")
	s=replaceOnce(s,"local lapValue=UI.Label(left,{Text=\"1 / 1\",Position=UDim2.fromOffset(14,27),Size=UDim2.new(1,-28,1,-34),TextSize=32,Color=C(\"Text\"),Role=\"Metric\",XAlignment=Enum.TextXAlignment.Center})","local lapValue=UI.Label(left,{Text=\"1 / 1\",Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,1,-34),TextSize=N(\"MetricValueSize\",36),Color=C(\"Text\"),Role=\"Metric\",XAlignment=Enum.TextXAlignment.Center})","lap value")
	s=replaceOnce(s,"local metricHeading=UI.Label(center,{Text=\"CURRENT LAP\",Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,22),TextSize=12,Color=C(\"Muted\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Center})","local metricHeading=UI.Label(center,{Text=\"CURRENT LAP\",Position=UDim2.fromOffset(0,6),Size=UDim2.new(1,0,0,26),TextSize=N(\"MetricHeadingSize\",15),Color=C(\"Text\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Center})","metric heading")
	s=replaceOnce(s,"local metricValue=UI.Label(center,{Text=\"00:00.000\",Position=UDim2.fromOffset(14,28),Size=UDim2.new(1,-28,1,-34),TextSize=32,Color=C(\"Telemetry\"),Role=\"Metric\",XAlignment=Enum.TextXAlignment.Center})","local metricValue=UI.Label(center,{Text=\"00:00.000\",Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,1,-34),TextSize=N(\"MetricValueSize\",36),Color=C(\"Telemetry\"),Role=\"Metric\",XAlignment=Enum.TextXAlignment.Center})","metric value")
	s=replaceOnce(s,"local boardTitle=UI.Label(right,{Text=\"SESSION LAPS\",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,30),TextSize=N(\"BoardHeadingSize\",18),Color=C(\"Telemetry\"),Role=\"Heading\"})\nlocal boardBody=Instance.new(\"Frame\") boardBody.BackgroundTransparency=1 boardBody.Position=UDim2.fromOffset(0,38) boardBody.Size=UDim2.new(1,0,1,-38) boardBody.Parent=right","local boardTitle=UI.Label(right,{Text=\"\",Size=UDim2.fromOffset(0,0),TextSize=1,Color=C(\"Telemetry\"),Role=\"Heading\"}) boardTitle.Visible=false\nlocal boardBody=Instance.new(\"Frame\") boardBody.BackgroundTransparency=1 boardBody.Position=UDim2.fromOffset(0,0) boardBody.Size=UDim2.fromScale(1,1) boardBody.Parent=right","remove board heading")
	s=replaceFunction(s,"renderTimeTrialBoard()","renderRaceBoard()",TT_BOARD)
	s=replaceFunction(s,"renderRaceBoard()","refresh()",RACE_BOARD)
	s=replaceOnce(s,"if active.Mode==\"Race\" then metricHeading.Text=\"POSITION\" metricValue.Text=tostring(active.Place or \"--\")..\" / \"..tostring(active.ParticipantCount or \"--\") renderRaceBoard() else metricHeading.Text=\"CURRENT LAP\" renderTimeTrialBoard() end","if active.Mode==\"Race\" then metricHeading.Text=\"POSITION\" metricValue.Text=tostring(active.Place or \"--\")..\" / \"..tostring(active.ParticipantCount or \"--\") metricValue.TextColor3=placementColor(active.Place) renderRaceBoard() else metricHeading.Text=\"CURRENT LAP\" metricValue.TextColor3=C(\"Telemetry\") renderTimeTrialBoard() end","live placement colour")
	s=replaceOnce(s,"local controls=Instance.new(\"Frame\") controls.Name=\"SessionControls\" controls.BackgroundTransparency=1 controls.AnchorPoint=Vector2.new(.5,1) controls.Position=UDim2.new(.5,0,1,-N(\"BottomY\",30)) controls.Size=UDim2.fromOffset(360,44) controls.Parent=canvas\nlocal resetButton=UI.Button(controls,{Text=\"RESET\",Size=UDim2.new(.5,-6,1,0),Color=C(\"PanelDeep\"),StrokeColor=C(\"Outline\"),TextSize=13})\nlocal exitButton=UI.Button(controls,{Text=\"EXIT\",Position=UDim2.new(.5,6,0,0),Size=UDim2.new(.5,-6,1,0),Color=C(\"PanelDeep\"),StrokeColor=C(\"Danger\"),TextColor=C(\"Danger\"),TextSize=13})","local controls=Instance.new(\"Frame\") controls.Name=\"SessionControls\" controls.BackgroundTransparency=1 controls.AnchorPoint=Vector2.new(.5,1) controls.Position=UDim2.new(.5,0,1,-N(\"BottomY\",30)) controls.Size=UDim2.fromOffset(360,38) controls.Parent=canvas\nlocal resetButton=UI.Button(controls,{Text=\"RESET\",Position=UDim2.fromOffset(10,3),Size=UDim2.fromOffset(150,32),Color=C(\"PanelDeep\"),StrokeColor=C(\"OutlineSoft\"),TextSize=13}) resetButton.BackgroundTransparency=.48 resetButton.TextTransparency=.12\nlocal exitButton=UI.Button(controls,{Text=\"EXIT\",Position=UDim2.fromOffset(180,3),Size=UDim2.fromOffset(170,32),Color=C(\"PanelDeep\"),StrokeColor=C(\"OutlineSoft\"),TextSize=13}) exitButton.BackgroundTransparency=.48 exitButton.TextTransparency=.12","free-roam control geometry")
	s=replaceOnce(s,"local modal=UI.Panel(modalShade,{Name=\"ExitConfirmation\",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(650,252),Color=C(\"PanelDeep\"),Transparency=.04,StrokeColor=C(\"Outline\"),StrokeTransparency=.02}) modal.ZIndex=101","local modal=UI.Panel(modalShade,{Name=\"ExitConfirmation\",Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(650,270),Color=C(\"PanelDeep\"),Transparency=.04,StrokeColor=C(\"Outline\"),StrokeTransparency=.02}) modal.AnchorPoint=Vector2.new(.5,.5) modal.Position=UDim2.fromScale(.5,.5) modal.Size=UDim2.fromOffset(650,270) modal.ZIndex=101","centred dealership modal")
	s=replaceOnce(s,"local modalTitle=UI.Label(modal,{Text=\"EXIT RACE?\",Position=UDim2.fromOffset(24,18),Size=UDim2.new(1,-48,0,38),TextSize=22,Color=C(\"Text\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Center})","local modalTitle=UI.Label(modal,{Text=\"EXIT RACE?\",Position=UDim2.fromOffset(20,8),Size=UDim2.new(1,-40,0,54),TextSize=22,Color=C(\"Text\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Center})","modal title")
	s=replaceOnce(s,"local modalCopy=UI.Label(modal,{Text=\"CURRENT PROGRESS WILL BE LOST.\",Position=UDim2.fromOffset(24,70),Size=UDim2.new(1,-48,0,48),TextSize=13,Color=C(\"Muted\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Center})","local modalCopy=UI.Label(modal,{Text=\"CURRENT PROGRESS WILL BE LOST.\",Position=UDim2.fromOffset(20,88),Size=UDim2.new(1,-40,0,44),TextSize=15,Color=C(\"Text\"),Role=\"Heading\",XAlignment=Enum.TextXAlignment.Center})","modal message")
	s=replaceOnce(s,"local noButton=UI.Button(modal,{Text=\"NO\",Position=UDim2.fromOffset(30,168),Size=UDim2.fromOffset(270,54),Color=C(\"PanelDeep\"),StrokeColor=C(\"Outline\"),TextSize=13})","local noButton=UI.Button(modal,{Text=\"NO\",Position=UDim2.fromOffset(30,182),Size=UDim2.fromOffset(270,54),Color=C(\"PanelDeep\"),StrokeColor=C(\"Outline\"),TextSize=13})","modal no button")
	s=replaceOnce(s,"local yesButton=UI.Button(modal,{Text=\"YES, EXIT\",Position=UDim2.fromOffset(350,168),Size=UDim2.fromOffset(270,54),Color=C(\"PanelDeep\"),StrokeColor=C(\"Danger\"),TextColor=C(\"Danger\"),TextSize=13})","local yesButton=UI.Button(modal,{Text=\"YES\",Position=UDim2.fromOffset(350,182),Size=UDim2.fromOffset(270,54),Color=C(\"PanelBlue\"),StrokeColor=C(\"Telemetry\"),TextSize=13})","modal yes button")
	s=string.gsub(s,"endlocal ","end\nlocal ") -- keep generated function boundaries parse-safe
	item.Source=s log("Installed exact modal/buttons and homogeneous gradient HUD components")
end
local function smoke() local s=controller().Source assert(string.find(s,MARKER,1,true),"16B2 marker missing") assert(string.find(s,"modal.AnchorPoint=Vector2.new(.5,.5)",1,true),"Explicit modal centring missing") assert(string.find(s,"local function dataRow",1,true),"Shared data row missing") assert(string.find(s,"metricValue.TextColor3=placementColor",1,true),"Placement colour missing") log("SMOKE PASS") end
if MODE=="INSTALL" then install() smoke() log("Install complete. Restart Play and verify both modes plus NO/YES modal actions.") elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE") end
