-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
-- NTR_RACING_UI_MOBILE_PHASE1_SCALED_DESKTOP_TRIAL
-- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
-- Neo Tokyo Racers - Unified Race / Time Trial Results Presentation
-- NTR_RACING_UI_PHASE11_UNIFIED_RESULTS_PRESENTATION

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local touchDevice = UserInputService.TouchEnabled
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local racingRemotes = shared:WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local resultUIModules = shared:WaitForChild("Modules"):WaitForChild("UI")
local UI = require(resultUIModules:WaitForChild("RacingUIComponents"))
local MobileScaledDesktop = require(resultUIModules:WaitForChild("RacingMobileScaledDesktopLayout"))
local scaledDesktop = MobileScaledDesktop.IsEnabled(touchDevice)
local touch = touchDevice and not scaledDesktop
local C, L, T = UI.Colour, UI.Layout, UI.Type

local gui, overlay, shell, body, footer, title, complete
local lastResult, lastPositions, activeMode
local suppressed = {}
local medalCells = { Platinum = Vector2.new(0, 0), Gold = Vector2.new(1, 0), Silver = Vector2.new(0, 1), Bronze = Vector2.new(1, 1) }

local function invoke(remote, action, payload)
	local ok, result = pcall(function() return remote:InvokeServer(action, payload or {}) end)
	return ok and type(result) == "table" and result or { Ok = false, Success = false, Message = tostring(result) }
end
local function timeText(seconds)
	seconds = tonumber(seconds)
	if not seconds or seconds <= 0 then return "--:--.---" end
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%06.3f", minutes, seconds - minutes * 60)
end
local function money(value)
	local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
	local changed repeat text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2") until changed == 0
	return "$" .. text
end
local function clear(parent) for _, child in ipairs(parent:GetChildren()) do child:Destroy() end end
local function panel(parent, name, position, size)
	return UI.Panel(parent, { Name = name, Position = position, Size = size, Color = C("PanelDeep"), Transparency = 0.05, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
end
local function heading(parent, text, position, size)
	return UI.Label(parent, { Text = text, Position = position, Size = size, TextSize = touch and 10 or 14, Color = C("Telemetry"), Role = "Heading" })
end
local function medalIcon(parent, medal, position, size)
	local atlas = UI.Asset(UI.AssetValue("MedalAtlas", ""))
	if atlas == "" or not medalCells[medal] then return end
	local icon = Instance.new("ImageLabel") icon.BackgroundTransparency = 1 icon.Position = position icon.Size = size icon.Image = atlas
	local cellSize = tonumber(UI.AssetValue("MedalAtlasCellSize", "512")) or 512 local cell = medalCells[medal]
	icon.ImageRectOffset = Vector2.new(cell.X * cellSize, cell.Y * cellSize) icon.ImageRectSize = Vector2.new(cellSize, cellSize) icon.ScaleType = Enum.ScaleType.Fit icon.Parent = parent
end
-- NTR_RACING_UI_PHASE13_RESULTS_VISUAL_HIERARCHY
local avatarCache = {}
local function avatar(parent, userId, position, size)
	local image = Instance.new("ImageLabel")
	image.Name = "PlayerHeadshot"
	image.BackgroundColor3 = C("PanelSoft")
	image.BackgroundTransparency = 0.15
	image.BorderSizePixel = 0
	image.Position = position
	image.Size = size
	image.ScaleType = Enum.ScaleType.Crop
	image.Parent = parent
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, touch and 4 or 6) corner.Parent = image
	userId = tonumber(userId)
	if not userId or userId <= 0 then return image end
	if avatarCache[userId] then image.Image = avatarCache[userId] return image end
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and type(content) == "string" then
			avatarCache[userId] = content
			if image.Parent then image.Image = content end
		end
	end)
	return image
end

local function publishPresentation(open)
	local folder=script.Parent.Parent:FindFirstChild("UI")
	local event=folder and folder:FindFirstChild("FreeRoamHudPresentationMode")
	if event and event:IsA("BindableEvent") then event:Fire({Owner="RaceResults",Active=open==true,KeepTelemetry=false}) end
end
local function setSuppressed(open)
	if not touch then publishPresentation(open) return end
	local other=playerGui:FindFirstChild("NTR_RaceQueue_Phase8") if other and other~=gui then if open and suppressed[other]==nil then suppressed[other]=other.Enabled other.Enabled=false elseif not open and suppressed[other]~=nil then other.Enabled=suppressed[other] suppressed[other]=nil end end
end
local function fireDrivingExit()
	local root = script.Parent.Parent local uiFolder = root and root:FindFirstChild("UI") local event = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleExited")
	if event and event:IsA("BindableEvent") then event:Fire() end
end
local function hide()
	overlay.Visible = false activeMode = nil lastResult = nil setSuppressed(false)
end

local function tableHeader(parent, labels)
	local header = Instance.new("Frame") header.BackgroundColor3 = C("PanelSoft") header.BackgroundTransparency = 0.35 header.BorderSizePixel = 0 header.Position = UDim2.fromOffset(10, touch and 34 or 42) header.Size = UDim2.new(1, -20, 0, touch and 24 or 28) header.Parent = parent
	for _, item in ipairs(labels) do UI.Label(header, { Text = item[1], Position = UDim2.new(item[2], 6, 0, 0), Size = UDim2.new(item[3], -12, 1, 0), TextSize = touch and 7 or 9, Color = C("Muted"), Role = "Heading" }) end
	return touch and 62 or 70
end
local function scrolling(parent, y)
	local list = Instance.new("ScrollingFrame") list.BackgroundTransparency = 1 list.BorderSizePixel = 0 list.Position = UDim2.fromOffset(10, y) list.Size = UDim2.new(1, -20, 1, -(y + 10)) list.ScrollBarThickness = touch and 3 or 5 list.AutomaticCanvasSize = Enum.AutomaticSize.Y list.CanvasSize = UDim2.fromOffset(0, 0) list.Parent = parent return list
end
local function footerButtons(leftText, rightText, leftAction, rightAction)
	clear(footer) local gap = touch and 10 or L("Gap", 16) local textSize = touch and 9 or 13
	local left = UI.Button(footer, { Text = leftText, Size = UDim2.new(0.5, -gap / 2, 1, 0), StrokeColor = C("Outline"), TextSize = textSize })
	local right = UI.Button(footer, { Text = rightText, Position = UDim2.new(0.5, gap / 2, 0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), Color = C("PanelBlue"), StrokeColor = C("Telemetry"), FocusColor = C("Telemetry"), TextSize = textSize })
	left.MouseButton1Click:Connect(leftAction) right.MouseButton1Click:Connect(rightAction)
end

local function renderTimeTrial(payload)
	clear(body) title.Text = string.upper(tostring(payload.DisplayName or "TIME TRIAL")) complete.Text = payload.FinishReason == "Quit" and "TIME TRIAL ENDED" or "TIME TRIAL COMPLETE"
	local gap = touch and 10 or L("Gap", 16) local leftW = 0.5
	local left = Instance.new("Frame") left.BackgroundTransparency = 1 left.Size = UDim2.new(leftW, -gap / 2, 1, 0) left.Parent = body
	local right = panel(body, "GlobalTop20", UDim2.new(leftW, gap / 2, 0, 0), UDim2.new(1-leftW, -gap/2, 1, 0))
	local resultH = touch and 142 or 188 local result = panel(left, "YourResult", UDim2.fromOffset(0,0), UDim2.new(1,0,0,resultH)) heading(result,"YOUR RESULT",UDim2.fromOffset(14,6),UDim2.new(1,-28,0,24))
	local medal = tostring(payload.Medal or "Finished") local iconSize = touch and 82 or 116 medalIcon(result, medal, UDim2.fromOffset(14, touch and 34 or 42), UDim2.fromOffset(iconSize,iconSize))
	UI.Label(result,{Text=string.upper(medal),Position=UDim2.fromOffset(touch and 108 or 148,touch and 34 or 42),Size=UDim2.new(1,touch and -122 or -162,0,30),TextSize=touch and 19 or 28,Color=C("Text"),Role="Heading"})
	UI.Label(result,{Text="PRIZE  "..money(payload.RewardAmount),Position=UDim2.fromOffset(touch and 108 or 148,touch and 66 or 80),Size=UDim2.new(1,touch and -122 or -162,0,28),TextSize=touch and 13 or 18,Color=C("Telemetry"),Role="Metric"})
	UI.Label(result,{Text="BEST LAP  "..timeText(payload.BestLapSeconds or payload.Elapsed),Position=UDim2.fromOffset(touch and 108 or 148,touch and 94 or 112),Size=UDim2.new(1,touch and -122 or -162,0,28),TextSize=touch and 12 or 17,Color=C("Telemetry"),Role="Metric"})
	UI.Label(result,{Text=payload.IsPersonalBest and "NEW PERSONAL BEST" or "",Position=UDim2.fromOffset(touch and 108 or 148,touch and 120 or 144),Size=UDim2.new(1,touch and -122 or -162,0,24),TextSize=touch and 8 or 11,Color=C("Telemetry"),Role="Heading"})
	local laps = panel(left,"SessionLaps",UDim2.fromOffset(0,resultH+gap),UDim2.new(1,0,1,-(resultH+gap))) heading(laps,"SESSION LAPS",UDim2.fromOffset(14,6),UDim2.new(1,-28,0,24))
	local list = scrolling(laps,touch and 38 or 46) local rowH=touch and 38 or 44
	for index, lap in ipairs(payload.LapTimes or {}) do local row=Instance.new("Frame") row.BackgroundColor3=C("PanelSoft") row.BackgroundTransparency=tonumber(lap.Lap)==tonumber(payload.BestLapIndex) and 0.35 or (index%2==0 and 0.65 or 1) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,(index-1)*rowH) row.Size=UDim2.new(1,-6,0,rowH) row.Parent=list UI.Label(row,{Text=string.format("%02d",tonumber(lap.Lap) or index),Position=UDim2.fromOffset(8,0),Size=UDim2.new(.2,0,1,0),TextSize=touch and 11 or 14,Color=C("Text"),Role="Heading"}) UI.Label(row,{Text=timeText(lap.Elapsed),Position=UDim2.new(.25,0,0,0),Size=UDim2.new(.5,0,1,0),TextSize=touch and 13 or 17,Color=C("Text"),Role="Metric"}) if tonumber(lap.Lap)==tonumber(payload.BestLapIndex) then UI.Label(row,{Text="BEST",Position=UDim2.new(.78,0,0,0),Size=UDim2.new(.2,-8,1,0),TextSize=touch and 10 or 13,Color=C("Telemetry"),Role="Heading",XAlignment=Enum.TextXAlignment.Right}) end end
	heading(right,"GLOBAL TOP 20 — TIER "..tostring(payload.VehicleTier or "--"),UDim2.fromOffset(14,6),UDim2.new(1,-28,0,26))
	local y=tableHeader(right,{{"POS",0,.12},{"PLAYER",.12,.43},{"TIME",.55,.25},{"VEHICLE",.80,.20}}) local board=scrolling(right,y)
	local global=invoke(raceRequest,"GetTimeTrialLeaderboard",{EventId=payload.EventId,VehicleTier=payload.VehicleTier,Limit=20}) local entries=type(global.Entries)=="table" and global.Entries or {}
	if #entries==0 then UI.Label(board,{Text=global.Ok and "NO GLOBAL RECORDS YET" or "GLOBAL RANKINGS UNAVAILABLE",Size=UDim2.new(1,-10,0,60),TextSize=touch and 10 or 13,Color=C("Muted"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) end
	local rowH=touch and 28 or 34 for index,entry in ipairs(entries) do local row=Instance.new("Frame") local you=tonumber(entry.UserId)==player.UserId row.BackgroundColor3=you and C("PanelBlue") or C("PanelSoft") row.BackgroundTransparency=you and .35 or (index%2==0 and .65 or 1) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,(index-1)*rowH) row.Size=UDim2.new(1,-6,0,rowH) row.Parent=board local values={{tostring(entry.Rank or index),0,.12},{string.upper(tostring(entry.DisplayName or entry.Username or "PLAYER")),.12,.43},{timeText(entry.BestSeconds),.55,.25},{string.upper(tostring(entry.VehicleName or entry.VehicleId or "--")),.80,.20}} for _,v in ipairs(values) do UI.Label(row,{Text=v[1],Position=UDim2.new(v[2],6,0,0),Size=UDim2.new(v[3],-12,1,0),TextSize=touch and 8 or 10,Color=you and C("Telemetry") or C("Text"),Role="Heading"}) end end
	footerButtons("EXIT TO START","TRY AGAIN",function() complete.Text="EXITING..." local result=invoke(raceRequest,"ExitFinishedTimeTrial",{}) if result.Ok==true or result.Success==true then fireDrivingExit() hide() else complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end end,function() local result=invoke(raceRequest,"StartStagedTimeTrial",{EventId=payload.EventId,VehicleId=payload.SelectedVehicleId,LapCount=payload.LapTarget}) if result.Ok==true or result.Success==true then hide() end end)
end

local function renderRace(payload)
	clear(body) title.Text=string.upper(tostring(payload.DisplayName or "RACE")) complete.Text="RACE COMPLETE"
	local gap=touch and 10 or L("Gap",16) local leftW=.5
	local left=Instance.new("Frame") left.BackgroundTransparency=1 left.Size=UDim2.new(leftW,-gap/2,1,0) left.Parent=body
	local right=panel(body,"RaceResults",UDim2.new(leftW,gap/2,0,0),UDim2.new(1-leftW,-gap/2,1,0))
	local resultH=touch and 190 or 252
	local result=panel(left,"YourResult",UDim2.fromOffset(0,0),UDim2.new(1,0,0,resultH))
	heading(result,"YOUR RESULT",UDim2.fromOffset(18,8),UDim2.new(1,-36,0,26))
	local place=tonumber(payload.Place) local suffix=place==1 and "ST" or place==2 and "ND" or place==3 and "RD" or "TH"
	UI.Label(result,{Text=(place and tostring(place)..suffix or "--").." PLACE",Position=UDim2.fromOffset(20,touch and 40 or 48),Size=UDim2.new(1,touch and -124 or -164,0,touch and 52 or 72),TextSize=touch and 34 or 52,Color=place==1 and C("Telemetry") or C("Text"),Role="Metric"})
	local podiumMedal=place==1 and "Gold" or place==2 and "Silver" or place==3 and "Bronze" or nil
	if podiumMedal then medalIcon(result,podiumMedal,UDim2.new(1,touch and -104 or -138,0,touch and 38 or 42),UDim2.fromOffset(touch and 82 or 112,touch and 82 or 112)) end
	UI.Label(result,{Text="PRIZE",Position=UDim2.fromOffset(22,touch and 100 or 126),Size=UDim2.fromOffset(140,20),TextSize=touch and 9 or 11,Color=C("Muted"),Role="Heading"})
	UI.Label(result,{Text=money(payload.RewardAmount),Position=UDim2.fromOffset(22,touch and 118 or 146),Size=UDim2.new(.46,-22,0,touch and 30 or 38),TextSize=touch and 19 or 28,Color=C("Telemetry"),Role="Metric"})
	UI.Label(result,{Text="FINISH TIME",Position=UDim2.new(.49,0,0,touch and 100 or 126),Size=UDim2.new(.46,-22,0,20),TextSize=touch and 9 or 11,Color=C("Muted"),Role="Heading"})
	UI.Label(result,{Text=timeText(payload.Elapsed),Position=UDim2.new(.49,0,0,touch and 118 or 146),Size=UDim2.new(.48,-22,0,touch and 30 or 38),TextSize=touch and 19 or 28,Color=C("Telemetry"),Role="Metric"})
	local highlights=panel(left,"RaceHighlights",UDim2.fromOffset(0,resultH+gap),UDim2.new(1,0,1,-(resultH+gap)))
	heading(highlights,"RACE HIGHLIGHTS",UDim2.fromOffset(18,8),UDim2.new(1,-36,0,26))
	local highlightText=UI.Label(highlights,{Text="FASTEST LAP",Position=UDim2.fromOffset(touch and 58 or 72,touch and 38 or 48),Size=UDim2.new(.52,-72,0,touch and 30 or 38),TextSize=touch and 12 or 16,Color=C("Text"),Role="Heading"})
	UI.Label(highlights,{Text="--",Position=UDim2.new(.65,0,0,touch and 38 or 48),Size=UDim2.new(.31,-18,0,touch and 30 or 38),TextSize=touch and 14 or 20,Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	local divider=Instance.new("Frame") divider.BorderSizePixel=0 divider.BackgroundColor3=C("Outline") divider.BackgroundTransparency=.65 divider.Position=UDim2.new(0,18,.5,0) divider.Size=UDim2.new(1,-36,0,1) divider.Parent=highlights
	UI.Label(highlights,{Text="HIGHEST SPEED",Position=UDim2.fromOffset(touch and 58 or 72,touch and 94 or 112),Size=UDim2.new(.52,-72,0,touch and 30 or 38),TextSize=touch and 12 or 16,Color=C("Text"),Role="Heading"})
	UI.Label(highlights,{Text="--",Position=UDim2.new(.65,0,0,touch and 94 or 112),Size=UDim2.new(.31,-18,0,touch and 30 or 38),TextSize=touch and 14 or 20,Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	local silhouetteSize=touch and 32 or 40
	local function silhouette(y) local f=Instance.new("Frame") f.BackgroundColor3=C("PanelSoft") f.BackgroundTransparency=.15 f.BorderSizePixel=0 f.Position=UDim2.fromOffset(18,y) f.Size=UDim2.fromOffset(silhouetteSize,silhouetteSize) f.Parent=highlights local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,6) c.Parent=f end
	silhouette(touch and 34 or 42) silhouette(touch and 90 or 106)
	heading(right,"RACE RESULTS",UDim2.fromOffset(14,6),UDim2.new(1,-28,0,26))
	local y=tableHeader(right,{{"POS",0,.11},{"PLAYER",.11,.44},{"FINISH TIME",.55,.25},{"VEHICLE",.80,.20}}) local list=scrolling(right,y)
	local positions=lastPositions or payload.Positions or {} local rowH=touch and 38 or 46
	for index,entry in ipairs(positions) do
		local row=Instance.new("Frame") local you=tonumber(entry.UserId)==player.UserId
		row.BackgroundColor3=you and C("PanelBlue") or C("PanelSoft") row.BackgroundTransparency=you and .30 or (index%2==0 and .58 or .82) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,(index-1)*rowH) row.Size=UDim2.new(1,-6,0,rowH-2) row.Parent=list
		local elapsed=tonumber(entry.FinishElapsed) or (you and tonumber(payload.Elapsed)) local finish=elapsed and timeText(elapsed) or (entry.Finished and "FINISHED" or "RACING") local vehicle=string.upper(tostring(entry.VehicleName or entry.VehicleId or "--"))
		UI.Label(row,{Text=tostring(entry.Place or index),Position=UDim2.fromOffset(6,0),Size=UDim2.new(.10,-6,1,0),TextSize=touch and 10 or 13,Color=index<=3 and C("Telemetry") or C("Text"),Role="Heading"})
		local avatarSize=touch and 28 or 34 avatar(row,entry.UserId,UDim2.new(.11,5,.5,-avatarSize/2),UDim2.fromOffset(avatarSize,avatarSize))
		UI.Label(row,{Text=string.upper(tostring(entry.Name or "PLAYER")),Position=UDim2.new(.11,avatarSize+12,0,0),Size=UDim2.new(.44,-(avatarSize+16),1,0),TextSize=touch and 9 or 12,Color=you and C("Telemetry") or C("Text"),Role="Heading"})
		UI.Label(row,{Text=finish,Position=UDim2.new(.55,6,0,0),Size=UDim2.new(.25,-12,1,0),TextSize=touch and 9 or 12,Color=you and C("Telemetry") or C("Text"),Role="Heading"})
		UI.Label(row,{Text=vehicle,Position=UDim2.new(.80,6,0,0),Size=UDim2.new(.20,-12,1,0),TextSize=touch and 8 or 10,Color=you and C("Telemetry") or C("Text"),Role="Heading"})
	end
	footerButtons("EXIT TO START","RACE AGAIN",function() complete.Text="EXITING..." local result=invoke(queueRequest,"ExitRaceToStart",{}) if result.Ok==true or result.Success==true then hide() else complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end end,function() local eventId=tostring(player:GetAttribute("NTR_LastRacingEventId") or payload.EventId or "") local vehicleId=tostring(player:GetAttribute("NTR_LastRacingVehicleId") or "") local root=script.Parent local start=root:FindFirstChild("StartRaceQueueRequest") if start and start:IsA("BindableEvent") and eventId~="" and vehicleId~="" then hide() start:Fire({EventId=eventId,VehicleId=vehicleId,DisplayName=payload.DisplayName}) end end)
end

local function show(mode,payload)
	lastResult=payload activeMode=mode setSuppressed(true) overlay.Visible=true
	if mode=="Race" then renderRace(payload) else renderTimeTrial(payload) end
end

local function build()
	gui=Instance.new("ScreenGui") gui.Name="NTR_UnifiedRaceResults" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=220 gui.Parent=playerGui
	overlay=Instance.new("Frame") overlay.BackgroundColor3=Color3.new(0,0,0) overlay.BackgroundTransparency=.32 overlay.BorderSizePixel=0 overlay.Size=UDim2.fromScale(1,1) overlay.Visible=false overlay.Parent=gui
	shell=UI.Panel(overlay,{Color=C("PanelDeep"),Transparency=L("PanelTransparency",.08),StrokeColor=C("Outline"),StrokeWidth=L("ShellStrokeWidth",2),StrokeTransparency=.02,Clips=true}) shell.AnchorPoint=Vector2.new(.5,.5) shell.Position=UDim2.fromScale(.5,.5)
	if scaledDesktop then MobileScaledDesktop.Attach(shell) elseif touch then shell.Size=UDim2.new(1,-16,1,-16) else shell.Size=UDim2.fromOffset(L("ShellWidth",1200),L("ShellHeight",720)) UI.AttachResponsiveScale(shell) end
	local headerH=touch and 44 or L("HeaderHeight",64) title=UI.Label(shell,{Text="RESULTS",Position=UDim2.fromOffset(touch and 12 or 24,0),Size=UDim2.new(.42,0,0,headerH),TextSize=touch and 14 or T("Heading",22),Role="Heading"}) complete=UI.Label(shell,{Text="COMPLETE",Position=UDim2.new(.38,0,0,0),Size=UDim2.new(.32,0,0,headerH),TextSize=touch and 10 or 14,Color=C("Telemetry"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
	-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP: results exit is footer-only.
local divider=Instance.new("Frame") divider.BorderSizePixel=0 divider.BackgroundColor3=C("Outline") divider.BackgroundTransparency=.5 divider.Position=UDim2.fromOffset(0,headerH) divider.Size=UDim2.new(1,0,0,1) divider.Parent=shell
	local pad=touch and 12 or L("OuterPadding",24) local footerH=touch and 40 or 48 local footerGap=touch and 10 or L("Gap",16)
	body=Instance.new("Frame") body.BackgroundTransparency=1 body.Position=UDim2.fromOffset(pad,headerH+pad) body.Size=UDim2.new(1,-pad*2,1,-(headerH+pad*2+footerH+footerGap)) body.Parent=shell
	footer=Instance.new("Frame") footer.BackgroundTransparency=1 footer.Position=UDim2.new(0,pad,1,-(pad+footerH)) footer.Size=UDim2.new(1,-pad*2,0,footerH) footer.Parent=shell
end

raceEvent.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end local kind=tostring(payload.Type or "")
	if kind=="RacePositionUpdate" then lastPositions=payload.Positions or lastPositions if activeMode=="Race" and lastResult then renderRace(lastResult) end
	elseif kind=="RaceFinished" then show("Race",payload)
	elseif kind=="TimeTrialFinished" then show("TimeTrial",payload)
	elseif kind=="TimeTrialEnded" then hide() -- no fallback result reopen
	elseif kind=="RaceStaged" or kind=="RaceStarted" or kind=="TimeTrialStaged" or kind=="TimeTrialStarted" or kind=="RaceExitedToStart" then hide() end
end)

build()
print("[NTR Racing UI Phase 11] Unified Results presentation active.")
