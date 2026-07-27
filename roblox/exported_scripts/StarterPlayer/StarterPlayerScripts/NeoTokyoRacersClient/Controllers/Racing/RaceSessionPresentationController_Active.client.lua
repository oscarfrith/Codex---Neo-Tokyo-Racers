-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1_1
-- NTR_RACING_PRESENTATION_LIFECYCLE_V1_4_ADAPTIVE_SAFE_EDGE_CANVAS
-- NTR_RACING_PRESENTATION_LIFECYCLE_V1_3_FULLSCREEN_EXIT
-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
-- NTR_RACING_UI_MOBILE_PHASE2_LARGE_SESSION_CONTROLS
-- NTR_RACING_UI_MOBILE_PHASE2_IN_RACE_HUD
-- Neo Tokyo Racers - Shared In-Race Race / Time Trial HUD
-- NTR_RACING_UI_PHASE16A_SHARED_IN_RACE_HUD
-- NTR_RACING_UI_PHASE16B_GT_HUD_CONTROLS_SUPPRESSION
-- NTR_RACING_UI_PHASE16B2_HUD_VISUAL_ALIGNMENT
-- NTR_RACING_UI_PHASE16B2A_ENDLOCAL_PARSE_REPAIR
-- NTR_RACING_UI_PHASE16C_CONFIG_DRIVEN_HUD_MAP
-- NTR_RACING_UI_PHASE16C2_MAP_OPACITY_EDGE_ALIGNMENT
-- NTR_RACING_UI_PHASE16D_PRESENTATION_PERFORMANCE

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers") local shared=kit:WaitForChild("Shared")
local racingRemotes=shared:WaitForChild("Remotes"):WaitForChild("Racing") local raceEvent=racingRemotes:WaitForChild("RaceEvent") local raceRequest=racingRemotes:WaitForChild("RaceRequest")
local UI=require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents")) local C,L,T=UI.Colour,UI.Layout,UI.Type
local config=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing"):WaitForChild("InRace")
local racingConfig=kit.Config:WaitForChild("Racing")
local performanceConfig=racingConfig:WaitForChild("PresentationPerformance")
local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end
local touch=UserInputService.TouchEnabled
local mobileConfig=config:FindFirstChild("Mobile")
local function MN(name,fallback) local item=mobileConfig and mobileConfig:FindFirstChild(name) return item and (item:IsA("NumberValue") or item:IsA("BoolValue")) and item.Value or fallback end
touch=touch and MN("Enabled",true)
local function HN(name,fallback) return touch and MN(name,fallback) or N(name,fallback) end
local function timeText(seconds) seconds=tonumber(seconds) if not seconds or seconds<0 then return "--:--.---" end local m=math.floor(seconds/60) return string.format("%02d:%06.3f",m,seconds-m*60) end
local function asset(value) value=tostring(value or "") if value=="" then return "" end if string.find(value,"rbxassetid://",1,true) then return value end local id=string.match(value,"%d+") return id and "rbxassetid://"..id or value end
local function eventFolder(mode,eventId) local catalog=racingConfig:FindFirstChild(mode=="Race" and "RaceCatalog" or "TimeTrialCatalog") if not catalog then return nil end local direct=catalog:FindFirstChild(tostring(eventId or "")) if direct then return direct end for _,candidate in ipairs(catalog:GetChildren()) do if tostring(candidate:GetAttribute("EventId") or "")==tostring(eventId or "") then return candidate end end end
local function mapImage(mode,eventId) local event=eventFolder(mode,eventId) if not event then return "" end local value=event:GetAttribute("RaceHudMapImage") local child=event:FindFirstChild("RaceHudMapImage") if (value==nil or value=="") and child and child:IsA("StringValue") then value=child.Value end return asset(value) end
local hudMapCatalog=racingConfig:WaitForChild("HudMapCatalog")
local freeRoamHudConfig=kit.Config.UI:WaitForChild("DesktopFreeRoamHud")
local freeRoamMapAssets=freeRoamHudConfig:WaitForChild("Assets")
local freeRoamMapLayout=freeRoamHudConfig:WaitForChild("Layout")
local function mapValue(folder,name,className,fallback)
	local item=folder and folder:FindFirstChild(name)
	if item and item:IsA(className) then return item.Value end
	return fallback
end
local function routeIdFor(mode,eventId)
	local event=eventFolder(mode,eventId)
	local value=event and (event:GetAttribute("RouteId") or event:GetAttribute("RaceRouteId"))
	local child=event and (event:FindFirstChild("RouteId") or event:FindFirstChild("RaceRouteId"))
	if (value==nil or value=="") and child and child:IsA("StringValue") then value=child.Value end
	return tostring(value and value~="" and value or eventId or "")
end
local function hudMapConfig(mode,eventId)
	return hudMapCatalog:FindFirstChild(routeIdFor(mode,eventId))
end
local function hudMapImage(mode,eventId)
	local folder=hudMapConfig(mode,eventId) local value=mapValue(folder,"Image","StringValue","")
	return value~="" and asset(value) or mapImage(mode,eventId)
end
local function mapSubject()
	local character=player.Character local humanoid=character and character:FindFirstChildOfClass("Humanoid") local seat=humanoid and humanoid.SeatPart
	if seat and seat:IsA("BasePart") then
		local vehicle=seat:FindFirstAncestorOfClass("Model")
		local root=vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true))
		if root and root:IsA("BasePart") then return root end
		return seat
	end
	local root=character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end
local function mapAnchor(folder,routeId)
	if not folder then return nil end
	if mapValue(folder,"UseConfiguredWorldAnchor","BoolValue",false) then
		return Vector3.new(mapValue(folder,"WorldAnchorX","NumberValue",0),0,mapValue(folder,"WorldAnchorZ","NumberValue",0))
	end
	local world=Workspace:FindFirstChild("NeoTokyoRacersWorld") local routes=world and world:FindFirstChild("RaceRoutes") local route=routes and routes:FindFirstChild(routeId)
	local name=mapValue(folder,"AnchorPartName","StringValue","FinishLine") local part=route and route:FindFirstChild(name,true)
	if part and part:IsA("BasePart") then return part.Position end
	return nil
end

local function call(action,payload) local ok,result=pcall(function() return raceRequest:InvokeServer(action,payload or {}) end) return ok and type(result)=="table" and result or {} end

local old=playerGui:FindFirstChild("NTR_SharedInRaceHUD") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="NTR_SharedInRaceHUD" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=155 gui.ZIndexBehavior=Enum.ZIndexBehavior.Global pcall(function() gui.ScreenInsets=Enum.ScreenInsets.None end) pcall(function() gui.ClipToDeviceSafeArea=false end) gui.Parent=playerGui
local canvas=Instance.new("Frame") canvas.Name="ReferenceCanvas" canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Visible=false canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local REFERENCE_VIEWPORT=Vector2.new(1920,1080)
local cameraViewportConnection=nil
local function safeViewportRect(viewport)
	local origin=Vector2.zero local size=viewport
	local ok,fullRect,deviceRect=pcall(function()
		return GuiService:GetInsetArea(Enum.ScreenInsets.None),GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
	end)
	if ok and fullRect and deviceRect then
		origin=deviceRect.Min-fullRect.Min
		size=deviceRect.Max-deviceRect.Min
	end
	origin=Vector2.new(math.clamp(origin.X,0,math.max(0,viewport.X-1)),math.clamp(origin.Y,0,math.max(0,viewport.Y-1)))
	size=Vector2.new(math.clamp(size.X,1,math.max(1,viewport.X-origin.X)),math.clamp(size.Y,1,math.max(1,viewport.Y-origin.Y)))
	return origin,size
end
local function updateScale()
	local camera=Workspace.CurrentCamera
	local viewport=camera and camera.ViewportSize or gui.AbsoluteSize
	if viewport.X<1 or viewport.Y<1 then viewport=REFERENCE_VIEWPORT end
	local origin,safeSize=safeViewportRect(viewport)
	local uniformScale=math.max(.01,math.min(safeSize.X/REFERENCE_VIEWPORT.X,safeSize.Y/REFERENCE_VIEWPORT.Y))
	scale.Scale=uniformScale
	canvas.Position=UDim2.fromOffset(origin.X+safeSize.X*.5,origin.Y+safeSize.Y*.5)
	canvas.Size=UDim2.fromOffset(safeSize.X/uniformScale,safeSize.Y/uniformScale)
end
local function bindCameraViewport()
	if cameraViewportConnection then cameraViewportConnection:Disconnect() cameraViewportConnection=nil end
	local camera=Workspace.CurrentCamera
	if camera then cameraViewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
	updateScale()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraViewport)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
bindCameraViewport()
local suppressed={}
local legacyHudNames={NTR_RaceHud=true,NTR_RaceHud_Phase3=true,NTR_RaceCheckpointBadge_Phase5D=true,NTR_RaceQueue_Phase8=true,NTR_RaceSessionControls_Phase8D=true}
local function suppress(active)
	if not (touch and active) then return end
	for name in pairs(legacyHudNames) do
		local other=playerGui:FindFirstChild(name)
		if other and other:IsA("ScreenGui") then other.Enabled=false end
	end
end -- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
local function panel(name,pos,size) return UI.Panel(canvas,{Name=name,Position=pos,Size=size,Color=C("PanelDeep"),Transparency=N("PanelTransparency",.16),StrokeColor=C("Outline"),StrokeTransparency=.16,Clips=true}) end
local function borderless(object) object.BackgroundTransparency=1 for _,child in ipairs(object:GetChildren()) do if child:IsA("UIStroke") then child.Transparency=1 end end return object end
local function metricCard(object)
	object.BackgroundColor3=C("PanelSoft") object.BackgroundTransparency=N("MetricCardTransparency",.34)
	for _,child in ipairs(object:GetChildren()) do if child:IsA("UIStroke") then child.Transparency=1 elseif child:IsA("UIGradient") then child:Destroy() end end
	local corner=object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner") UI.SetCorner(corner,N("MetricCardCornerRadius",9)) corner.Parent=object
	local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new(C("PanelSoft"),C("PanelDeep")) gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(1,.28)}) gradient.Rotation=90 gradient.Parent=object
	return object
end
local function dataRow(parent,y,height)
	local row=Instance.new("Frame") row.BackgroundColor3=C("PanelSoft") row.BackgroundTransparency=N("DataRowTransparency",.42) row.BorderSizePixel=0 row.Position=UDim2.fromOffset(0,y) row.Size=UDim2.new(1,0,0,height) row.Parent=parent
	UI.Corner(row,N("DataRowCornerRadius",7))
	local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new(C("PanelSoft"),C("PanelDeep")) gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.03),NumberSequenceKeypoint.new(1,.22)}) gradient.Rotation=90 gradient.Parent=row return row
end
local function placementColor(place)
	place=tonumber(place) local name=place==1 and "FirstPlaceColor" or place==2 and "SecondPlaceColor" or place==3 and "ThirdPlaceColor" or nil
	local item=name and config:FindFirstChild(name) if item and item:IsA("Color3Value") then return item.Value end
	if place==1 then return Color3.fromRGB(255,190,45) elseif place==2 then return Color3.fromRGB(205,215,225) elseif place==3 then return Color3.fromRGB(205,125,65) end return C("Text")
end
local left=metricCard(panel("LapProgress",touch and UDim2.fromOffset(MN("ProgressOffsetX",30),MN("ProgressOffsetY",150)) or UDim2.fromOffset(N("ProgressOffsetX",30),N("ProgressOffsetY",105)),touch and UDim2.fromOffset(MN("ProgressWidth",150),MN("ProgressHeight",78)) or UDim2.fromOffset(N("ProgressWidth",178),N("ProgressHeight",92))))
local center=metricCard(panel("PrimaryMetric",UDim2.new(.5,-HN("MetricWidth",touch and 260 or 300)/2,0,touch and MN("MetricOffsetY",28) or N("EdgeY",30)),UDim2.fromOffset(HN("MetricWidth",touch and 260 or 300),HN("MetricHeight",touch and 80 or 92))))
local right=borderless(panel("SessionBoard",UDim2.new(1,-HN("BoardOffsetX",touch and 24 or 30)-HN("BoardWidth",touch and 330 or 380),0,HN("BoardOffsetY",touch and 30 or 38)),UDim2.fromOffset(HN("BoardWidth",touch and 330 or 380),HN("BoardHeight",touch and 280 or 300))))
local map=borderless(panel("RaceMap",UDim2.new(0,N("MapOffsetX",30),1,-N("MapOffsetY",30)-N("MapHeight",210)),UDim2.fromOffset(N("MapWidth",280),N("MapHeight",210))))
map.Visible=not touch
local mapPadding=math.max(0,N("MapInnerPadding",0))
local mapArt=Instance.new("ImageLabel") mapArt.Name="SimplifiedRaceMap" mapArt.BackgroundTransparency=1 mapArt.ImageTransparency=1-math.clamp(N("MapOpacity",.78),0,1) mapArt.Position=UDim2.fromOffset(mapPadding,mapPadding) mapArt.Size=UDim2.new(1,-mapPadding*2,1,-mapPadding*2) mapArt.ScaleType=Enum.ScaleType.Fit mapArt.Parent=map
local playerMapMarker=Instance.new("ImageLabel") playerMapMarker.Name="PlayerMarker" playerMapMarker.AnchorPoint=Vector2.new(.5,.5) playerMapMarker.BackgroundTransparency=1 playerMapMarker.BorderSizePixel=0 playerMapMarker.Image=asset(mapValue(freeRoamMapAssets,"MapPlayerIcon","StringValue","")) playerMapMarker.ImageColor3=C("Text") playerMapMarker.ScaleType=Enum.ScaleType.Fit playerMapMarker.Size=UDim2.fromOffset(math.max(8,mapValue(freeRoamMapLayout,"MapPlayerIconSize","NumberValue",22)),math.max(8,mapValue(freeRoamMapLayout,"MapPlayerIconSize","NumberValue",22))) playerMapMarker.Position=UDim2.fromScale(.5,.5) playerMapMarker.ZIndex=20 playerMapMarker.Visible=false playerMapMarker.Parent=mapArt
local displayedMapMarkerPosition=nil local displayedMapMarkerHeading=nil
local lapHeading=UI.Label(left,{Text="LAP",Position=UDim2.fromOffset(0,6),Size=UDim2.new(1,0,0,26),TextSize=HN("MetricHeadingSize",15),Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
local lapValue=UI.Label(left,{Text="1 / 1",Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,1,-34),TextSize=HN("MetricValueSize",36),Color=C("Text"),Role="Metric",XAlignment=Enum.TextXAlignment.Center})
local metricHeading=UI.Label(center,{Text="CURRENT LAP",Position=UDim2.fromOffset(0,6),Size=UDim2.new(1,0,0,26),TextSize=HN("MetricHeadingSize",15),Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
local metricValue=UI.Label(center,{Text="00:00.000",Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,1,-34),TextSize=HN("MetricValueSize",36),Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Center})
local boardTitle=UI.Label(right,{Text="",Size=UDim2.fromOffset(0,0),TextSize=1,Color=C("Telemetry"),Role="Heading"}) boardTitle.Visible=false
local boardBody=Instance.new("Frame") boardBody.BackgroundTransparency=1 boardBody.Position=UDim2.fromOffset(0,0) boardBody.Size=UDim2.fromScale(1,1) boardBody.Parent=right
local active=nil
local queueRequest=racingRemotes:WaitForChild("RaceQueueRequest")
local transitionRequest=script.Parent:FindFirstChild("RaceTransitionRequest")
local uiFolder=script.Parent.Parent:FindFirstChild("UI") local freeRoamMode=uiFolder and uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
local function presentationMode(enabled) if freeRoamMode and freeRoamMode:IsA("BindableEvent") then freeRoamMode:Fire({Owner="RaceSession",Active=enabled==true,KeepTelemetry=true}) end end
local controls=Instance.new("Frame") controls.Name="SessionControls" controls.BackgroundTransparency=1 controls.AnchorPoint=Vector2.new(.5,1) controls.Position=UDim2.new(.5,0,1,-N("BottomY",30)) controls.Size=UDim2.fromOffset(360,38) controls.Parent=canvas
local resetButton=UI.Button(controls,{Text="RESET",Position=UDim2.fromOffset(10,3),Size=UDim2.fromOffset(150,32),Color=C("PanelDeep"),StrokeColor=C("OutlineSoft"),TextSize=13}) resetButton.BackgroundTransparency=.48 resetButton.TextTransparency=.12
local exitButton=UI.Button(controls,{Text="EXIT",Position=UDim2.fromOffset(180,3),Size=UDim2.fromOffset(170,32),Color=C("PanelDeep"),StrokeColor=C("OutlineSoft"),TextSize=13}) exitButton.BackgroundTransparency=.48 exitButton.TextTransparency=.12
if touch then
	local buttonWidth=MN("SessionButtonWidth",126) local buttonHeight=MN("SessionButtonHeight",48) local buttonGap=MN("SessionButtonGap",6) local buttonTextSize=MN("SessionButtonTextSize",15)
	controls.Position=UDim2.new(0,MN("SessionControlsCenterX",760),1,-MN("SessionControlsBottomOffset",24))
	controls.Size=UDim2.fromOffset(buttonWidth,buttonHeight*2+buttonGap)
	resetButton.Position=UDim2.fromOffset(0,0) resetButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) resetButton.TextSize=buttonTextSize
	exitButton.Position=UDim2.fromOffset(0,buttonHeight+buttonGap) exitButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) exitButton.TextSize=buttonTextSize
end
local modalBackdrop=Instance.new("Frame") modalBackdrop.Name="ExitConfirmationFullScreenBackdrop" modalBackdrop.Active=true modalBackdrop.BackgroundColor3=Color3.new(0,0,0) modalBackdrop.BackgroundTransparency=.34 modalBackdrop.BorderSizePixel=0 modalBackdrop.Position=UDim2.fromScale(0,0) modalBackdrop.Size=UDim2.fromScale(1,1) modalBackdrop.Visible=false modalBackdrop.ZIndex=90 modalBackdrop.Parent=gui
local modalShade=Instance.new("Frame") modalShade.Name="ExitConfirmationShade" modalShade.BackgroundTransparency=1 modalShade.BorderSizePixel=0 modalShade.Size=UDim2.fromScale(1,1) modalShade.Visible=false modalShade.ZIndex=100 modalShade.Parent=canvas
local confirmationLayout=require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ResponsiveUIFoundation")).ConfirmationLayout()
local modal=UI.Panel(modalShade,{Name="ExitConfirmation",Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(confirmationLayout.PanelWidth,confirmationLayout.PanelHeight),Color=C("PanelDeep"),Transparency=.04,StrokeColor=C("Outline"),StrokeTransparency=.02}) modal.AnchorPoint=Vector2.new(.5,.5) modal.Position=UDim2.fromScale(.5,.5) modal.Size=UDim2.fromOffset(confirmationLayout.PanelWidth,confirmationLayout.PanelHeight) modal.ZIndex=101
local modalTitle=UI.Label(modal,{Text="EXIT RACE?",Position=confirmationLayout.TitlePosition,Size=confirmationLayout.TitleSize,TextSize=confirmationLayout.TitleTextSize,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalTitle.ZIndex=102
local modalCopy=UI.Label(modal,{Text="CURRENT PROGRESS WILL BE LOST.",Position=confirmationLayout.BodyPosition,Size=confirmationLayout.BodySize,TextSize=confirmationLayout.BodyTextSize,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalCopy.ZIndex=102
local noButton=UI.Button(modal,{Text="NO",Position=confirmationLayout.CancelPosition,Size=confirmationLayout.ButtonSize,Color=C("PanelDeep"),StrokeColor=C("Outline"),TextSize=confirmationLayout.ButtonTextSize}) noButton.ZIndex=103
local yesButton=UI.Button(modal,{Text="YES",Position=confirmationLayout.ConfirmPosition,Size=confirmationLayout.ButtonSize,Color=C("PanelBlue"),StrokeColor=C("Telemetry"),TextSize=confirmationLayout.ButtonTextSize}) yesButton.ZIndex=103
local function setExitModalVisible(visible)
	visible=visible==true
	modalBackdrop.Visible=visible
	modalShade.Visible=visible
end
local busy=false
local function transition(step,payload) if transitionRequest and transitionRequest:IsA("BindableEvent") then payload=payload or {} payload.Step=step transitionRequest:Fire(payload) end end
local function invokeSession(kind)
	if busy or not active then return end busy=true setExitModalVisible(false) transition("FadeOut",{Reason=kind,Label=kind=="Reset" and "RESETTING" or "EXITING"}) task.wait(.25)
	local remote=active.Mode=="Race" and queueRequest or raceRequest local action=active.Mode=="Race" and (kind=="Reset" and "ResetToLastCheckpoint" or "ExitRaceToStart") or (kind=="Reset" and "ResetActiveTimeTrial" or "ExitActiveTimeTrial")
	local ok,result=pcall(function() return remote:InvokeServer(action,{RunId=active.RunId,EventId=active.EventId}) end) local success=ok and type(result)=="table" and (result.Ok==true or result.Success==true)
	transition("RestoreCamera",{Reason=kind}) transition("FadeIn",{Reason=kind,Delay=success and .3 or .08,Success=success}) -- NTR_LOADING_SYSTEM_PHASE4_ACTIVE_RACE_EXIT_V1
	if kind=="Reset" then resetButton.Text=success and "RESET DONE" or "RESET FAILED" task.delay(1.1,function() if resetButton.Parent then resetButton.Text="RESET" end busy=false end) else if not success then exitButton.Text="EXIT FAILED" task.delay(1.2,function() if exitButton.Parent then exitButton.Text="EXIT" end busy=false end) end end
end
resetButton.Activated:Connect(function() invokeSession("Reset") end)
exitButton.Activated:Connect(function() if not active then return end modalTitle.Text=active.Mode=="Race" and "EXIT RACE?" or "EXIT TIME TRIAL?" setExitModalVisible(true) end)
noButton.Activated:Connect(function() setExitModalVisible(false) end) yesButton.Activated:Connect(function() invokeSession("Exit") end)

local avatarCache={}
local function avatar(parent,userId,pos,size) local image=Instance.new("ImageLabel") image.BackgroundColor3=C("PanelSoft") image.BackgroundTransparency=.15 image.BorderSizePixel=0 image.Position=pos image.Size=size image.ScaleType=Enum.ScaleType.Crop image.Parent=parent UI.Corner(image,5) userId=tonumber(userId) if not userId then return end if avatarCache[userId] then image.Image=avatarCache[userId] return end task.spawn(function() local ok,url=pcall(function() return Players:GetUserThumbnailAsync(userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100) end) if ok then avatarCache[userId]=url if image.Parent then image.Image=url end end end) end
local function clear(parent) for _,child in ipairs(parent:GetChildren()) do child:Destroy() end end
local hudMapState={Enabled=false,Subject=nil,NextSubjectResolve=0}
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
	if touch then resetHudMapMarker() return end
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
end
local function show(payload,mode) active=active or {} active.Mode=mode active.RunId=payload.RunId active.EventId=payload.EventId active.VehicleTier=payload.VehicleTier or active.VehicleTier active.CurrentLap=tonumber(payload.CurrentLap) or active.CurrentLap or 1 active.LapTarget=tonumber(payload.LapTarget) or active.LapTarget or 1 active.ParticipantCount=tonumber(payload.ParticipantCount) or active.ParticipantCount or 1 active.LapTimes=active.LapTimes or {} active.Positions=active.Positions or {} prepareHudMapSession(mode,active.EventId) mapArt.Image=touch and "" or hudMapImage(mode,active.EventId) resetHudMapMarker() canvas.Visible=true suppress(true) presentationMode(true) end
local function hide(_restoreLegacy) active=nil clearHudMapState() canvas.Visible=false setExitModalVisible(false) busy=false suppress(false) presentationMode(false) clear(boardBody) end
local function queryPB() if not (active and active.Mode=="TimeTrial" and active.VehicleTier) then return end local result=call("GetTimeTrialPersonalBest",{EventId=active.EventId,VehicleTier=active.VehicleTier}) active.PersonalBest=tonumber(result.BestSeconds or (result.Record and result.Record.BestSeconds)) end
local function renderTimeTrialBoard()
	clear(boardBody)
	local rowH=HN("DataRowHeight",42) local gap=HN("DataRowGap",5)
	local pb=dataRow(boardBody,0,rowH)
	UI.Label(pb,{Text="PERSONAL BEST",Position=UDim2.fromOffset(10,0),Size=UDim2.new(.56,-10,1,0),TextSize=HN("DataRowTextSize",16),Color=C("Outline"),Role="Heading"})
	UI.Label(pb,{Text=timeText(active and active.PersonalBest),Position=UDim2.new(.56,0,0,0),Size=UDim2.new(.44,-10,1,0),TextSize=HN("DataRowMetricSize",18),Color=C("Outline"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	for index,lap in ipairs(active and active.LapTimes or {}) do
		local row=dataRow(boardBody,rowH+gap+(index-1)*(rowH+gap),rowH)
		UI.Label(row,{Text=string.format("%02d",tonumber(lap.Lap) or index),Position=UDim2.fromOffset(10,0),Size=UDim2.new(.24,-10,1,0),TextSize=HN("DataRowTextSize",16),Color=C("Text"),Role="Heading"})
		UI.Label(row,{Text=timeText(lap.Elapsed),Position=UDim2.new(.34,0,0,0),Size=UDim2.new(.66,-10,1,0),TextSize=HN("DataRowMetricSize",18),Color=C("Text"),Role="Metric",XAlignment=Enum.TextXAlignment.Right})
	end
end

local function renderRaceBoard()
	clear(boardBody)
	local rowH=HN("DataRowHeight",42) local gap=HN("DataRowGap",5)
	for index,entry in ipairs(active and active.Positions or {}) do
		if index>6 then break end local row=dataRow(boardBody,(index-1)*(rowH+gap),rowH) local you=tonumber(entry.UserId)==player.UserId
		if you then row.BackgroundColor3=C("PanelBlue") row.BackgroundTransparency=N("LocalRowTransparency",.24) end
		local place=tonumber(entry.Place) or index
		UI.Label(row,{Text=tostring(place),Position=UDim2.fromOffset(8,0),Size=UDim2.fromOffset(30,rowH),TextSize=HN("DataRowTextSize",16),Color=placementColor(place),Role="Heading"})
		local avatarSize=HN("BoardAvatarSize",30) avatar(row,entry.UserId,UDim2.fromOffset(40,(rowH-avatarSize)/2),UDim2.fromOffset(avatarSize,avatarSize))
		UI.Label(row,{Text=string.upper(tostring(entry.Name or "PLAYER")),Position=UDim2.fromOffset(50+avatarSize,0),Size=UDim2.new(1,-(60+avatarSize),1,0),TextSize=HN("DataRowTextSize",16),Color=you and C("Telemetry") or C("Text"),Role="Heading"})
	end
end

local function refresh()
	if not active then return end
	local target=active.LapTarget==0 and "∞" or tostring(active.LapTarget or 1) lapHeading.Text=active.Mode=="Race" and "RACE LAP" or "LAP" lapValue.Text=tostring(active.CurrentLap or 1).." / "..target
	if active.Mode=="Race" then metricHeading.Text="POSITION" metricValue.Text=tostring(active.Place or "--").." / "..tostring(active.ParticipantCount or "--") metricValue.TextColor3=placementColor(active.Place) renderRaceBoard() else metricHeading.Text="CURRENT LAP" metricValue.TextColor3=C("Telemetry") renderTimeTrialBoard() end
end
raceEvent.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end local kind=tostring(payload.Type or "")
	if kind=="TimeTrialStaged" or kind=="TimeTrialCountdown" then show(payload,"TimeTrial") refresh()
	elseif kind=="TimeTrialStarted" then show(payload,"TimeTrial") active.Running=true active.LapLocalStart=os.clock() queryPB() refresh()
	elseif kind=="TimeTrialCheckpoint" then show(payload,"TimeTrial") refresh()
	elseif kind=="TimeTrialLapCompleted" then show(payload,"TimeTrial") active.LapTimes=payload.LapTimes or active.LapTimes table.insert(active.LapTimes,{Lap=payload.Lap,Elapsed=payload.Elapsed}) active.CurrentLap=payload.NextLap or payload.CurrentLap or active.CurrentLap active.LapLocalStart=os.clock() refresh()
	elseif kind=="TimeTrialReset" then refresh() -- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP: preserve lap clock on checkpoint reset
	elseif kind=="RaceStaged" or kind=="RaceCountdown" then show(payload,"Race") refresh()
	elseif kind=="RaceStarted" then show(payload,"Race") active.Running=true refresh()
	elseif kind=="RaceCheckpoint" or kind=="RaceLapCompleted" then show(payload,"Race") refresh()
	elseif kind=="RacePositionUpdate" then if not active then show(payload,"Race") end active.Place=payload.Place or active.Place active.ParticipantCount=payload.ParticipantCount or active.ParticipantCount active.CurrentLap=payload.CurrentLap or active.CurrentLap active.LapTarget=payload.LapTarget or active.LapTarget active.Positions=payload.Positions or active.Positions refresh()
	elseif kind=="TimeTrialFinished" or kind=="RaceFinished" or kind=="RaceEnded" then hide(false)
	elseif kind=="TimeTrialEnded" or kind=="TimeTrialError" or kind=="RaceExitedToStart" then hide(true) end
end)
RunService.RenderStepped:Connect(function(dt) if not active then return end updateHudMapMarker(dt) if active.Mode=="TimeTrial" and active.Running and active.LapLocalStart then metricValue.Text=timeText(os.clock()-active.LapLocalStart) end end)
print("[NTR Racing UI Phase 16A] Shared in-race HUD active.")
