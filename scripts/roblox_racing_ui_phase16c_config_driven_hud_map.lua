-- Neo Tokyo Racers - Racing UI Phase 16C Config-Driven HUD Map
-- Paste into Roblox Studio Command Bar in Edit mode after confirmed Phase 16B2A.

local MODE="INSTALL" -- INSTALL or SMOKE
local PHASE="NTR Racing UI Phase 16C"
local MARKER="NTR_RACING_UI_PHASE16C_CONFIG_DRIVEN_HUD_MAP"
local StarterPlayer=game:GetService("StarterPlayer")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local function fail(message) error("["..PHASE.."] "..tostring(message),2) end
local function log(message) print("["..PHASE.."] "..tostring(message)) end
local function ensure(parent,className,name)
	local item=parent:FindFirstChild(name)
	if item and not item:IsA(className) then fail(item:GetFullName().." must be a "..className) end
	if not item then item=Instance.new(className) item.Name=name item.Parent=parent end
	return item
end
local function defaultValue(parent,className,name,value)
	local item=ensure(parent,className,name)
	if item:GetAttribute("NTRConfigured")~=true then item.Value=value item:SetAttribute("NTRConfigured",true) end
	return item
end
local function controller()
	local root=StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing")
	local item=root:FindFirstChild("RaceSessionPresentationController_Active")
	if not (item and item:IsA("LuaSourceContainer")) then fail("Missing RaceSessionPresentationController_Active") end
	return item
end
local function replaceOnce(source,anchor,replacement,label)
	local first,last=string.find(source,anchor,1,true)
	if not first then fail("Could not find "..label.." anchor. Refresh the Studio mirror before another source repair.") end
	return string.sub(source,1,first-1)..replacement..string.sub(source,last+1)
end

local MAP_HELPERS=[==[
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
	local name=mapValue(folder,"AnchorPartName","StringValue","Grid_01") local part=route and route:FindFirstChild(name,true)
	if part and part:IsA("BasePart") then return part.Position end
	return nil
end
]==]

local MAP_UI=[==[local playerMapMarker=Instance.new("ImageLabel") playerMapMarker.Name="PlayerMarker" playerMapMarker.AnchorPoint=Vector2.new(.5,.5) playerMapMarker.BackgroundTransparency=1 playerMapMarker.BorderSizePixel=0 playerMapMarker.Image=asset(mapValue(freeRoamMapAssets,"MapPlayerIcon","StringValue","")) playerMapMarker.ImageColor3=C("Text") playerMapMarker.ScaleType=Enum.ScaleType.Fit playerMapMarker.Size=UDim2.fromOffset(math.max(8,mapValue(freeRoamMapLayout,"MapPlayerIconSize","NumberValue",22)),math.max(8,mapValue(freeRoamMapLayout,"MapPlayerIconSize","NumberValue",22))) playerMapMarker.Position=UDim2.fromScale(.5,.5) playerMapMarker.ZIndex=20 playerMapMarker.Visible=false playerMapMarker.Parent=mapArt
local displayedMapMarkerPosition=nil local displayedMapMarkerHeading=nil]==]

local MAP_RUNTIME=[==[local function resetHudMapMarker()
	displayedMapMarkerPosition=nil displayedMapMarkerHeading=nil playerMapMarker.Visible=false
end
local function updateHudMapMarker(dt)
	if not active then resetHudMapMarker() return end
	local folder=hudMapConfig(active.Mode,active.EventId)
	if not (folder and mapValue(folder,"Enabled","BoolValue",false)) then resetHudMapMarker() return end
	local subject=mapSubject() local routeId=routeIdFor(active.Mode,active.EventId) local anchor=mapAnchor(folder,routeId)
	if not (subject and anchor) then resetHudMapMarker() return end
	local imageWidth=math.max(1,mapValue(folder,"ImageWidthPixels","NumberValue",1024)) local imageHeight=math.max(1,mapValue(folder,"ImageHeightPixels","NumberValue",1024))
	local studsPerPixel=math.max(.0001,mapValue(folder,"StudsPerPixel","NumberValue",1)) local radians=math.rad(mapValue(folder,"MapRotationDegrees","NumberValue",0))
	local delta=subject.Position-anchor local mappedX=delta.X*math.cos(radians)-delta.Z*math.sin(radians) local mappedY=delta.X*math.sin(radians)+delta.Z*math.cos(radians)
	if mapValue(folder,"FlipX","BoolValue",false) then mappedX=-mappedX end if mapValue(folder,"FlipY","BoolValue",false) then mappedY=-mappedY end
	local sourceX=mapValue(folder,"StartPixelX","NumberValue",imageWidth*.5)+mappedX/studsPerPixel local sourceY=mapValue(folder,"StartPixelY","NumberValue",imageHeight*.5)+mappedY/studsPerPixel
	local x=sourceX/imageWidth local y=sourceY/imageHeight
	local rendered=mapArt.AbsoluteSize if rendered.X>0 and rendered.Y>0 then
		local frameAspect=rendered.X/rendered.Y local imageAspect=imageWidth/imageHeight
		if imageAspect>frameAspect then local heightFraction=frameAspect/imageAspect y=(1-heightFraction)*.5+y*heightFraction else local widthFraction=imageAspect/frameAspect x=(1-widthFraction)*.5+x*widthFraction end
	end
	if mapValue(folder,"ClampMarkersToMap","BoolValue",true) then x=math.clamp(x,0,1) y=math.clamp(y,0,1) end
	local targetPosition=Vector2.new(x,y) local look=subject.CFrame.LookVector local lookX=look.X*math.cos(radians)-look.Z*math.sin(radians) local lookY=look.X*math.sin(radians)+look.Z*math.cos(radians)
	if mapValue(folder,"FlipX","BoolValue",false) then lookX=-lookX end if mapValue(folder,"FlipY","BoolValue",false) then lookY=-lookY end
	local targetHeading=math.deg(math.atan2(lookX,-lookY))+mapValue(folder,"MarkerRotationOffsetDegrees","NumberValue",0) local smoothing=math.max(0,mapValue(folder,"Smoothing","NumberValue",12)) local alpha=smoothing<=0 and 1 or math.clamp((dt or 1/60)*smoothing,0,1)
	displayedMapMarkerPosition=displayedMapMarkerPosition and displayedMapMarkerPosition:Lerp(targetPosition,alpha) or targetPosition
	if displayedMapMarkerHeading==nil then displayedMapMarkerHeading=targetHeading end local headingDelta=(targetHeading-displayedMapMarkerHeading+180)%360-180 displayedMapMarkerHeading+=headingDelta*alpha
	local baseSize=math.max(8,mapValue(freeRoamMapLayout,"MapPlayerIconSize","NumberValue",22)) local size=baseSize*math.max(.1,mapValue(folder,"PlayerMarkerScale","NumberValue",1))
	playerMapMarker.Size=UDim2.fromOffset(size,size) playerMapMarker.Position=UDim2.fromScale(displayedMapMarkerPosition.X,displayedMapMarkerPosition.Y) playerMapMarker.Rotation=displayedMapMarkerHeading playerMapMarker.Visible=mapArt.Image~=""
end]==]

local function setupConfig()
	local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers") local racing=kit:WaitForChild("Config"):WaitForChild("Racing")
	local catalog=ensure(racing,"Folder","HudMapCatalog") local seen={}
	for _,catalogName in ipairs({"RaceCatalog","TimeTrialCatalog"}) do
		local events=racing:FindFirstChild(catalogName)
		for _,event in ipairs(events and events:GetChildren() or {}) do
			local routeId=tostring(event:GetAttribute("RouteId") or event:GetAttribute("RaceRouteId") or event.Name)
			if routeId~="" and not seen[routeId] then
				seen[routeId]=true local folder=ensure(catalog,"Folder",routeId)
				local existingImage=tostring(event:GetAttribute("RaceHudMapImage") or "") local imageChild=event:FindFirstChild("RaceHudMapImage")
				if existingImage=="" and imageChild and imageChild:IsA("StringValue") then existingImage=imageChild.Value end
				defaultValue(folder,"StringValue","Image",existingImage)
				defaultValue(folder,"BoolValue","Enabled",false)
				defaultValue(folder,"NumberValue","ImageWidthPixels",1024)
				defaultValue(folder,"NumberValue","ImageHeightPixels",1024)
				defaultValue(folder,"NumberValue","StartPixelX",512)
				defaultValue(folder,"NumberValue","StartPixelY",512)
				defaultValue(folder,"NumberValue","StudsPerPixel",1)
				defaultValue(folder,"NumberValue","MapRotationDegrees",0)
				defaultValue(folder,"BoolValue","FlipX",false)
				defaultValue(folder,"BoolValue","FlipY",false)
				defaultValue(folder,"BoolValue","ClampMarkersToMap",true)
				defaultValue(folder,"NumberValue","Smoothing",12)
				defaultValue(folder,"NumberValue","PlayerMarkerScale",1)
				defaultValue(folder,"NumberValue","MarkerRotationOffsetDegrees",0)
				defaultValue(folder,"StringValue","AnchorPartName","Grid_01")
				defaultValue(folder,"BoolValue","UseConfiguredWorldAnchor",false)
				defaultValue(folder,"NumberValue","WorldAnchorX",0)
				defaultValue(folder,"NumberValue","WorldAnchorZ",0)
				defaultValue(folder,"BoolValue","ShowOtherPlayers",false)
				defaultValue(folder,"NumberValue","OtherPlayerMarkerScale",.72)
			elseif routeId~="" then
				local folder=catalog:FindFirstChild(routeId) local image=folder and folder:FindFirstChild("Image")
				local existingImage=tostring(event:GetAttribute("RaceHudMapImage") or "") local imageChild=event:FindFirstChild("RaceHudMapImage")
				if existingImage=="" and imageChild and imageChild:IsA("StringValue") then existingImage=imageChild.Value end
				if image and image:IsA("StringValue") and image.Value=="" and existingImage~="" then image.Value=existingImage end
			end
		end
	end
	return catalog
end

local function patchController()
	local item=controller() local source=item.Source
	if string.find(source,MARKER,1,true) then log("Phase 16C controller already installed") return end
	if not string.find(source,"NTR_RACING_UI_PHASE16B2_HUD_VISUAL_ALIGNMENT",1,true) then fail("Confirmed Phase 16B2 marker missing") end
	if not string.find(source,"NTR_RACING_UI_PHASE16B2A_ENDLOCAL_PARSE_REPAIR",1,true) then fail("Phase 16B2A parse repair marker missing") end
	source=replaceOnce(source,"-- NTR_RACING_UI_PHASE16B2A_ENDLOCAL_PARSE_REPAIR","-- NTR_RACING_UI_PHASE16B2A_ENDLOCAL_PARSE_REPAIR\n-- "..MARKER,"Phase 16C marker")
	source=replaceOnce(source,"local function call(action,payload)",MAP_HELPERS.."\nlocal function call(action,payload)","map helper insertion")
	local uiAnchor="local mapArt=Instance.new(\"ImageLabel\") mapArt.Name=\"SimplifiedRaceMap\" mapArt.BackgroundTransparency=1 mapArt.Position=UDim2.fromOffset(8,8) mapArt.Size=UDim2.new(1,-16,1,-16) mapArt.ScaleType=Enum.ScaleType.Fit mapArt.Parent=map"
	source=replaceOnce(source,uiAnchor,uiAnchor.."\n"..MAP_UI,"map UI")
	source=replaceOnce(source,"local function show(payload,mode)",MAP_RUNTIME.."\nlocal function show(payload,mode)","map runtime")
	source=replaceOnce(source,"mapArt.Image=mapImage(mode,active.EventId) canvas.Visible=true","mapArt.Image=hudMapImage(mode,active.EventId) resetHudMapMarker() canvas.Visible=true","session map reset")
	local renderAnchor="RunService.RenderStepped:Connect(function() if active and active.Mode==\"TimeTrial\" and active.Running and active.LapLocalStart then metricValue.Text=timeText(os.clock()-active.LapLocalStart) end end)"
	source=replaceOnce(source,renderAnchor,"RunService.RenderStepped:Connect(function(dt) updateHudMapMarker(dt) if active and active.Mode==\"TimeTrial\" and active.Running and active.LapLocalStart then metricValue.Text=timeText(os.clock()-active.LapLocalStart) end end)","render update")
	if string.find(source,"endlocal ",1,true) then fail("Generated source contains malformed endlocal boundary") end
	item.Source=source
	log("Installed fixed-map local player marker and config-driven calibration")
end

local function smoke()
	local catalog=ReplicatedStorage.NeoTokyoRacers.Config.Racing:FindFirstChild("HudMapCatalog")
	assert(catalog,"HudMapCatalog missing")
	local source=controller().Source
	assert(string.find(source,MARKER,1,true),"Phase 16C marker missing")
	assert(string.find(source,"updateHudMapMarker(dt)",1,true),"HUD map runtime missing")
	assert(not string.find(source,"endlocal ",1,true),"Malformed source boundary detected")
	log("SMOKE PASS - configure a route folder, then set Enabled=true")
end

if MODE=="INSTALL" then setupConfig() patchController() smoke() log("Install complete. Restart Play after entering map calibration values.") elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE: "..tostring(MODE)) end
