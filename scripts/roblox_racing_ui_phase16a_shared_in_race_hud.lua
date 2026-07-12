-- Neo Tokyo Racers - Racing UI Phase 16A Shared In-Race HUD
-- Paste into Roblox Studio Command Bar in Edit mode.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 16A"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message) error("["..PHASE.."] "..tostring(message),2) end
local function log(message) print("["..PHASE.."] "..tostring(message)) end
local function ensure(parent,className,name) local item=parent:FindFirstChild(name) if item and not item:IsA(className) then item:Destroy() item=nil end if not item then item=Instance.new(className) item.Name=name item.Parent=parent end return item end
local function number(parent,name,value) local item=ensure(parent,"NumberValue",name) if item.Value==0 then item.Value=value end return item end
local function stringValue(parent,name,value) local item=ensure(parent,"StringValue",name) if item.Value=="" then item.Value=value or "" end return item end

local SOURCE = [====[
-- Neo Tokyo Racers - Shared In-Race Race / Time Trial HUD
-- NTR_RACING_UI_PHASE16A_SHARED_IN_RACE_HUD

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers") local shared=kit:WaitForChild("Shared")
local racingRemotes=shared:WaitForChild("Remotes"):WaitForChild("Racing") local raceEvent=racingRemotes:WaitForChild("RaceEvent") local raceRequest=racingRemotes:WaitForChild("RaceRequest")
local UI=require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents")) local C,L,T=UI.Colour,UI.Layout,UI.Type
local config=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing"):WaitForChild("InRace")
local racingConfig=kit.Config:WaitForChild("Racing")
local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end
local function timeText(seconds) seconds=tonumber(seconds) if not seconds or seconds<0 then return "--:--.---" end local m=math.floor(seconds/60) return string.format("%02d:%06.3f",m,seconds-m*60) end
local function asset(value) value=tostring(value or "") if value=="" then return "" end if string.find(value,"rbxassetid://",1,true) then return value end local id=string.match(value,"%d+") return id and "rbxassetid://"..id or value end
local function eventFolder(mode,eventId) local catalog=racingConfig:FindFirstChild(mode=="Race" and "RaceCatalog" or "TimeTrialCatalog") if not catalog then return nil end local direct=catalog:FindFirstChild(tostring(eventId or "")) if direct then return direct end for _,candidate in ipairs(catalog:GetChildren()) do if tostring(candidate:GetAttribute("EventId") or "")==tostring(eventId or "") then return candidate end end end
local function mapImage(mode,eventId) local event=eventFolder(mode,eventId) if not event then return "" end local value=event:GetAttribute("RaceHudMapImage") local child=event:FindFirstChild("RaceHudMapImage") if (value==nil or value=="") and child and child:IsA("StringValue") then value=child.Value end return asset(value) end
local function call(action,payload) local ok,result=pcall(function() return raceRequest:InvokeServer(action,payload or {}) end) return ok and type(result)=="table" and result or {} end

local old=playerGui:FindFirstChild("NTR_SharedInRaceHUD") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="NTR_SharedInRaceHUD" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=155 gui.Parent=playerGui
local canvas=Instance.new("Frame") canvas.Name="ReferenceCanvas" canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Visible=false canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local function updateScale() local camera=Workspace.CurrentCamera local v=camera and camera.ViewportSize or Vector2.new(1920,1080) scale.Scale=math.min(v.X/1920,v.Y/1080) end updateScale() if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
local suppressed={}
local function suppress(active) for _,name in ipairs({"NTR_RaceHud","NTR_RaceHud_Phase3","NTR_RaceCheckpointBadge_Phase5D","NTR_RaceQueue_Phase8"}) do local other=playerGui:FindFirstChild(name) if other and other:IsA("ScreenGui") then if active and suppressed[other]==nil then suppressed[other]=other.Enabled other.Enabled=false elseif not active and suppressed[other]~=nil then other.Enabled=suppressed[other] suppressed[other]=nil end end end end
local function panel(name,pos,size) return UI.Panel(canvas,{Name=name,Position=pos,Size=size,Color=C("PanelDeep"),Transparency=N("PanelTransparency",.16),StrokeColor=C("Outline"),StrokeTransparency=.16,Clips=true}) end
local left=panel("LapProgress",UDim2.fromOffset(N("EdgeX",30),N("EdgeY",30)),UDim2.fromOffset(N("ProgressWidth",178),N("ProgressHeight",92)))
local center=panel("PrimaryMetric",UDim2.new(.5,-N("MetricWidth",300)/2,0,N("EdgeY",30)),UDim2.fromOffset(N("MetricWidth",300),N("MetricHeight",92)))
local right=panel("SessionBoard",UDim2.new(1,-N("EdgeX",30)-N("BoardWidth",340),0,N("EdgeY",30)),UDim2.fromOffset(N("BoardWidth",340),N("BoardHeight",276)))
local map=panel("RaceMap",UDim2.new(0,N("EdgeX",30),1,-N("BottomY",30)-N("MapHeight",210)),UDim2.fromOffset(N("MapWidth",280),N("MapHeight",210))) map.BackgroundTransparency=1
local mapArt=Instance.new("ImageLabel") mapArt.Name="SimplifiedRaceMap" mapArt.BackgroundTransparency=1 mapArt.Position=UDim2.fromOffset(8,8) mapArt.Size=UDim2.new(1,-16,1,-16) mapArt.ScaleType=Enum.ScaleType.Fit mapArt.Parent=map
local lapHeading=UI.Label(left,{Text="LAP",Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,22),TextSize=12,Color=C("Muted"),Role="Heading"})
local lapValue=UI.Label(left,{Text="1 / 1",Position=UDim2.fromOffset(14,27),Size=UDim2.new(1,-28,1,-34),TextSize=32,Color=C("Text"),Role="Metric",XAlignment=Enum.TextXAlignment.Center})
local metricHeading=UI.Label(center,{Text="CURRENT LAP",Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,22),TextSize=12,Color=C("Muted"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
local metricValue=UI.Label(center,{Text="00:00.000",Position=UDim2.fromOffset(14,28),Size=UDim2.new(1,-28,1,-34),TextSize=32,Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Center})
local boardTitle=UI.Label(right,{Text="SESSION LAPS",Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,24),TextSize=14,Color=C("Telemetry"),Role="Heading"})
local boardBody=Instance.new("Frame") boardBody.BackgroundTransparency=1 boardBody.Position=UDim2.fromOffset(12,38) boardBody.Size=UDim2.new(1,-24,1,-50) boardBody.Parent=right
local avatarCache={}
local function avatar(parent,userId,pos,size) local image=Instance.new("ImageLabel") image.BackgroundColor3=C("PanelSoft") image.BackgroundTransparency=.15 image.BorderSizePixel=0 image.Position=pos image.Size=size image.ScaleType=Enum.ScaleType.Crop image.Parent=parent local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,5) corner.Parent=image userId=tonumber(userId) if not userId then return end if avatarCache[userId] then image.Image=avatarCache[userId] return end task.spawn(function() local ok,url=pcall(function() return Players:GetUserThumbnailAsync(userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100) end) if ok then avatarCache[userId]=url if image.Parent then image.Image=url end end end) end
local function clear(parent) for _,child in ipairs(parent:GetChildren()) do child:Destroy() end end
local active=nil
local function show(payload,mode) active=active or {} active.Mode=mode active.RunId=payload.RunId active.EventId=payload.EventId active.VehicleTier=payload.VehicleTier or active.VehicleTier active.CurrentLap=tonumber(payload.CurrentLap) or active.CurrentLap or 1 active.LapTarget=tonumber(payload.LapTarget) or active.LapTarget or 1 active.ParticipantCount=tonumber(payload.ParticipantCount) or active.ParticipantCount or 1 active.LapTimes=active.LapTimes or {} active.Positions=active.Positions or {} mapArt.Image=mapImage(mode,active.EventId) canvas.Visible=true suppress(true) end
local function hide(restoreLegacy) active=nil canvas.Visible=false if restoreLegacy~=false then suppress(false) end clear(boardBody) end
local function queryPB() if not (active and active.Mode=="TimeTrial" and active.VehicleTier) then return end local result=call("GetTimeTrialPersonalBest",{EventId=active.EventId,VehicleTier=active.VehicleTier}) active.PersonalBest=tonumber(result.BestSeconds or (result.Record and result.Record.BestSeconds)) end
local function renderTimeTrialBoard()
	clear(boardBody) boardTitle.Text="LAP TIMES"
	local pb=Instance.new("Frame") pb.BackgroundColor3=C("PanelSoft") pb.BackgroundTransparency=.55 pb.BorderSizePixel=0 pb.Size=UDim2.new(1,0,0,40) pb.Parent=boardBody
	UI.Label(pb,{Text="PERSONAL BEST",Position=UDim2.fromOffset(9,0),Size=UDim2.new(.5,-9,1,0),TextSize=11,Color=C("Outline"),Role="Heading"})
	UI.Label(pb,{Text=timeText(active and active.PersonalBest),Position=UDim2.new(.5,0,0,0),Size=UDim2.new(.5,-9,1,0),TextSize=15,Color=C("Outline"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	for index,lap in ipairs(active and active.LapTimes or {}) do local y=50+(index-1)*34 local row=Instance.new("Frame") row.BackgroundColor3=C("PanelSoft") row.BackgroundTransparency=index%2==0 and .55 or .75 row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,y) row.Size=UDim2.new(1,0,0,31) row.Parent=boardBody UI.Label(row,{Text=string.format("%02d",tonumber(lap.Lap) or index),Position=UDim2.fromOffset(9,0),Size=UDim2.new(.25,-9,1,0),TextSize=11,Color=C("Text"),Role="Heading"}) UI.Label(row,{Text=timeText(lap.Elapsed),Position=UDim2.new(.35,0,0,0),Size=UDim2.new(.65,-9,1,0),TextSize=15,Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Right}) end
end
local function renderRaceBoard()
	clear(boardBody) boardTitle.Text="LIVE POSITIONS"
	for index,entry in ipairs(active and active.Positions or {}) do if index>6 then break end local y=(index-1)*36 local row=Instance.new("Frame") local you=tonumber(entry.UserId)==player.UserId row.BackgroundColor3=you and C("PanelBlue") or C("PanelSoft") row.BackgroundTransparency=you and .25 or (index%2==0 and .58 or .75) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,y) row.Size=UDim2.new(1,0,0,33) row.Parent=boardBody UI.Label(row,{Text=tostring(entry.Place or index),Position=UDim2.fromOffset(8,0),Size=UDim2.fromOffset(28,33),TextSize=12,Color=you and C("Telemetry") or C("Text"),Role="Heading"}) avatar(row,entry.UserId,UDim2.fromOffset(38,3),UDim2.fromOffset(27,27)) UI.Label(row,{Text=string.upper(tostring(entry.Name or "PLAYER")),Position=UDim2.fromOffset(73,0),Size=UDim2.new(1,-82,1,0),TextSize=11,Color=you and C("Telemetry") or C("Text"),Role="Heading"}) end
end
local function refresh()
	if not active then return end
	local target=active.LapTarget==0 and "∞" or tostring(active.LapTarget or 1) lapHeading.Text=active.Mode=="Race" and "RACE LAP" or "LAP" lapValue.Text=tostring(active.CurrentLap or 1).." / "..target
	if active.Mode=="Race" then metricHeading.Text="POSITION" metricValue.Text=tostring(active.Place or "--").." / "..tostring(active.ParticipantCount or "--") renderRaceBoard() else metricHeading.Text="CURRENT LAP" renderTimeTrialBoard() end
end
raceEvent.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end local kind=tostring(payload.Type or "")
	if kind=="TimeTrialStaged" or kind=="TimeTrialCountdown" then show(payload,"TimeTrial") refresh()
	elseif kind=="TimeTrialStarted" then show(payload,"TimeTrial") active.Running=true active.LapLocalStart=os.clock() queryPB() refresh()
	elseif kind=="TimeTrialCheckpoint" then show(payload,"TimeTrial") refresh()
	elseif kind=="TimeTrialLapCompleted" then show(payload,"TimeTrial") active.LapTimes=payload.LapTimes or active.LapTimes table.insert(active.LapTimes,{Lap=payload.Lap,Elapsed=payload.Elapsed}) active.CurrentLap=payload.NextLap or payload.CurrentLap or active.CurrentLap active.LapLocalStart=os.clock() refresh()
	elseif kind=="TimeTrialReset" then if active then active.LapLocalStart=os.clock() end
	elseif kind=="RaceStaged" or kind=="RaceCountdown" then show(payload,"Race") refresh()
	elseif kind=="RaceStarted" then show(payload,"Race") active.Running=true refresh()
	elseif kind=="RaceCheckpoint" or kind=="RaceLapCompleted" then show(payload,"Race") refresh()
	elseif kind=="RacePositionUpdate" then if not active then show(payload,"Race") end active.Place=payload.Place or active.Place active.ParticipantCount=payload.ParticipantCount or active.ParticipantCount active.CurrentLap=payload.CurrentLap or active.CurrentLap active.LapTarget=payload.LapTarget or active.LapTarget active.Positions=payload.Positions or active.Positions refresh()
	elseif kind=="TimeTrialFinished" or kind=="RaceFinished" or kind=="RaceEnded" then hide(false)
	elseif kind=="TimeTrialEnded" or kind=="TimeTrialError" or kind=="RaceExitedToStart" then hide(true) end
end)
RunService.RenderStepped:Connect(function() if active and active.Mode=="TimeTrial" and active.Running and active.LapLocalStart then metricValue.Text=timeText(os.clock()-active.LapLocalStart) end end)
print("[NTR Racing UI Phase 16A] Shared in-race HUD active.")
]====]

local function setupConfig()
	local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers") local ui=ensure(kit:WaitForChild("Config"),"Folder","UI") local racing=ensure(ui,"Folder","Racing") local folder=ensure(racing,"Folder","InRace")
	number(folder,"EdgeX",30) number(folder,"EdgeY",30) number(folder,"BottomY",30) number(folder,"PanelTransparency",.16)
	number(folder,"ProgressWidth",178) number(folder,"ProgressHeight",92) number(folder,"MetricWidth",300) number(folder,"MetricHeight",92)
	number(folder,"BoardWidth",340) number(folder,"BoardHeight",276) number(folder,"MapWidth",280) number(folder,"MapHeight",210)
	local rc=kit.Config:WaitForChild("Racing")
	for _,catalogName in ipairs({"RaceCatalog","TimeTrialCatalog"}) do local catalog=rc:FindFirstChild(catalogName) for _,event in ipairs(catalog and catalog:GetChildren() or {}) do if event:GetAttribute("RaceHudMapImage")==nil then event:SetAttribute("RaceHudMapImage","") end end end
end
local function folder() return StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing") end
local function install() setupConfig() local root=folder() local item=root:FindFirstChild("RaceSessionPresentationController_Active") or Instance.new("LocalScript") item.Name="RaceSessionPresentationController_Active" item.Source=SOURCE item.Enabled=true item.Parent=root log("Installed isolated shared in-race HUD controller and semantic config.") end
local function smoke() local item=folder():FindFirstChild("RaceSessionPresentationController_Active") assert(item and item.Enabled,"In-race HUD controller missing") assert(string.find(item.Source,"NTR_RACING_UI_PHASE16A_SHARED_IN_RACE_HUD",1,true),"HUD marker missing") local config=ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing:FindFirstChild("InRace") assert(config and config:FindFirstChild("MapWidth"),"InRace config missing") log("SMOKE PASS") end
if MODE=="INSTALL" then install() smoke() log("Install complete. Set each event RaceHudMapImage, restart Play, and test both modes.") elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE: "..tostring(MODE)) end
