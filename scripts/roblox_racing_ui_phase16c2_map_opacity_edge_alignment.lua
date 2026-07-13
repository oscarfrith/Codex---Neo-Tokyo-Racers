-- Neo Tokyo Racers - Racing UI Phase 16C2 Map Opacity / Edge Alignment
-- Paste into Roblox Studio Command Bar in Edit mode after Phase 16C1.

local MODE="INSTALL" -- INSTALL or SMOKE
local PHASE="NTR Racing UI Phase 16C2"
local MARKER="NTR_RACING_UI_PHASE16C2_MAP_OPACITY_EDGE_ALIGNMENT"
local StarterPlayer=game:GetService("StarterPlayer")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local function fail(message) error("["..PHASE.."] "..tostring(message),2) end
local function log(message) print("["..PHASE.."] "..tostring(message)) end
local function controller()
	local item=StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):FindFirstChild("RaceSessionPresentationController_Active")
	if not (item and item:IsA("LuaSourceContainer")) then fail("Missing RaceSessionPresentationController_Active") end
	return item
end
local function replaceOnce(source,anchor,replacement,label)
	local first,last=string.find(source,anchor,1,true)
	if not first then fail("Could not find "..label.." anchor. Refresh the Studio mirror before another source repair.") end
	return string.sub(source,1,first-1)..replacement..string.sub(source,last+1)
end
local function number(parent,name,value,force)
	local item=parent:FindFirstChild(name)
	if item and not item:IsA("NumberValue") then fail(item:GetFullName().." must be a NumberValue") end
	if not item then item=Instance.new("NumberValue") item.Name=name item.Value=value item.Parent=parent elseif force then item.Value=value end
	return item
end

local function setupConfig()
	local folder=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing"):WaitForChild("InRace")
	-- Square source + square frame removes ScaleType.Fit side letterboxing.
	number(folder,"MapWidth",420,true)
	number(folder,"MapHeight",420,true)
	number(folder,"MapOffsetX",16,true)
	number(folder,"MapOffsetY",16,true)
	number(folder,"MapInnerPadding",0,true)
	number(folder,"MapOpacity",.78,false)
	return folder
end

local function patchController()
	local item=controller() local source=item.Source
	if string.find(source,MARKER,1,true) then log("Phase 16C2 controller already installed") return end
	if not string.find(source,"NTR_RACING_UI_PHASE16C_CONFIG_DRIVEN_HUD_MAP",1,true) then fail("Confirmed Phase 16C marker missing") end
	source=replaceOnce(source,"-- NTR_RACING_UI_PHASE16C_CONFIG_DRIVEN_HUD_MAP","-- NTR_RACING_UI_PHASE16C_CONFIG_DRIVEN_HUD_MAP\n-- "..MARKER,"Phase 16C2 marker")
	local old='local mapArt=Instance.new("ImageLabel") mapArt.Name="SimplifiedRaceMap" mapArt.BackgroundTransparency=1 mapArt.Position=UDim2.fromOffset(8,8) mapArt.Size=UDim2.new(1,-16,1,-16) mapArt.ScaleType=Enum.ScaleType.Fit mapArt.Parent=map'
	local new='local mapPadding=math.max(0,N("MapInnerPadding",0))\nlocal mapArt=Instance.new("ImageLabel") mapArt.Name="SimplifiedRaceMap" mapArt.BackgroundTransparency=1 mapArt.ImageTransparency=1-math.clamp(N("MapOpacity",.78),0,1) mapArt.Position=UDim2.fromOffset(mapPadding,mapPadding) mapArt.Size=UDim2.new(1,-mapPadding*2,1,-mapPadding*2) mapArt.ScaleType=Enum.ScaleType.Fit mapArt.Parent=map'
	source=replaceOnce(source,old,new,"map image geometry")
	source=replaceOnce(source,'playerMapMarker.Size=UDim2.fromOffset(size,size) playerMapMarker.Position=UDim2.fromScale(displayedMapMarkerPosition.X,displayedMapMarkerPosition.Y) playerMapMarker.Rotation=displayedMapMarkerHeading playerMapMarker.Visible=mapArt.Image~=""','mapArt.ImageTransparency=1-math.clamp(N("MapOpacity",.78),0,1) playerMapMarker.Size=UDim2.fromOffset(size,size) playerMapMarker.Position=UDim2.fromScale(displayedMapMarkerPosition.X,displayedMapMarkerPosition.Y) playerMapMarker.Rotation=displayedMapMarkerHeading playerMapMarker.Visible=mapArt.Image~=""',"live opacity")
	if string.find(source,"endlocal ",1,true) then fail("Generated source contains malformed endlocal boundary") end
	item.Source=source
	log("Installed square edge-aligned map and live MapOpacity control")
end

local function smoke()
	local folder=ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.InRace
	assert(folder.MapWidth.Value==420 and folder.MapHeight.Value==420,"Square map geometry missing")
	assert(folder.MapOffsetX.Value==16 and folder.MapOffsetY.Value==16,"Edge buffer missing")
	assert(folder:FindFirstChild("MapOpacity") and folder:FindFirstChild("MapInnerPadding"),"Map controls missing")
	local source=controller().Source
	assert(string.find(source,MARKER,1,true),"Phase 16C2 marker missing")
	assert(string.find(source,'N("MapOpacity",.78)',1,true),"Map opacity binding missing")
	assert(not string.find(source,"endlocal ",1,true),"Malformed source boundary detected")
	log("SMOKE PASS")
end

if MODE=="INSTALL" then setupConfig() patchController() smoke() log("Install complete. Restart Play; MapOpacity uses 0=invisible and 1=opaque.") elseif MODE=="SMOKE" then smoke() else fail("Unknown MODE: "..tostring(MODE)) end
