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
