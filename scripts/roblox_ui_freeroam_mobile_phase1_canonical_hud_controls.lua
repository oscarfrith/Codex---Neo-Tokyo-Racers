-- Neo Tokyo Racers - Mobile Free-Roam UI Phase 1K Boost Plate And Exit Alignment
-- Run this whole file in the Roblox Studio Command Bar while in Edit mode.
--
-- Canonically installs two isolated touch-only owners:
--   Controllers.UI.MobileFreeRoamHudController_Active
--   Controllers.Runtime.MobileDriveControlsController_Active
--
-- It reuses Phase 4A map/theme/action contracts and MobileDriveInputState.
-- It does not patch driving physics, server gameplay, VFX, LOD, or the
-- register-limited NeoTokyoRacersClient bootstrap.

local PHASE = "NTR Mobile Free-Roam UI Phase 1K Boost Plate And Exit Alignment"
local MARKER = "NTR_MOBILE_FREEROAM_UI_PHASE1K_BOOST_PLATE_EXIT_ALIGNMENT"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message) print(("[%s] %s"):format(PHASE, tostring(message))) end
local function ensure(parent, className, name)
	local item = parent:FindFirstChild(name)
	if item then assert(item.ClassName == className, item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className); return item end
	item = Instance.new(className); item.Name = name; item.Parent = parent; return item
end
local function value(parent, className, name, default)
	local item = parent:FindFirstChild(name)
	if item then assert(item.ClassName == className, item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className); return item end
	item = Instance.new(className); item.Name = name; item.Value = default; item.Parent = parent; return item
end
local function requireChild(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	assert(item, (parent and parent:GetFullName() or "nil") .. " is missing " .. name)
	if className then assert(item.ClassName == className, item:GetFullName() .. " must be " .. className) end
	return item
end

local kit = requireChild(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = requireChild(kit, "Shared", "Folder")
local configRoot = requireChild(kit, "Config", "Folder")
local uiConfigRoot = requireChild(configRoot, "UI", "Folder")
local desktopConfig = requireChild(uiConfigRoot, "DesktopFreeRoamHud", "Folder")
for _, name in ipairs({ "Colours", "Layout", "Assets", "Defaults", "Effects" }) do requireChild(desktopConfig, name, "Folder") end

local playerScripts = requireChild(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = requireChild(playerScripts, "NeoTokyoRacersClient", "Folder")
local controllers = requireChild(clientRoot, "Controllers", "Folder")
local runtime = requireChild(controllers, "Runtime", "Folder")
local ui = requireChild(controllers, "UI", "Folder")
local bootstrap = requireChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript")
local mobileOwner = requireChild(runtime, "MobileDriveControlsController_Active", "LocalScript")
local driveHudOwner = requireChild(runtime, "DriveHudController_Active", "LocalScript")
local navOwner = requireChild(ui, "FreeRoamNavController_Active", "LocalScript")
local exitOwner = requireChild(ui, "FreeRoamVehicleExitButton_Active", "LocalScript")
local desktopOwner = requireChild(ui, "DesktopFreeRoamHudController_Active", "LocalScript")
local inputState = requireChild(requireChild(requireChild(requireChild(shared, "Modules", "Folder"), "Client", "Folder"), "Controllers", "Folder"), "MobileDriveInputState", "ModuleScript")

for _, owner in ipairs({ mobileOwner, ui:FindFirstChild("MobileFreeRoamHudController_Active") }) do
	assert(owner and string.find(owner.Source, "NTR_MOBILE_FREEROAM_UI_PHASE1J_CARD_ART_DESPAWN_GRADIENT", 1, true), "Phase 1J mobile owner preflight failed; install Phase 1J or refresh its Studio mirror before Phase 1K")
end

for _, marker in ipairs({ "FreeRoamVehicleSpawned", "FreeRoamVehicleExited", "MobileDriveInputState" }) do
	assert(string.find(bootstrap.Source, marker, 1, true), "Bootstrap preflight missing " .. marker .. "; refresh mirror before installing")
end
for _, marker in ipairs({ "NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT", "MapTileTopLeft", "OpenRaceBrowser", "ExitVehicle" }) do
	assert(string.find(desktopOwner.Source, marker, 1, true), "Desktop Phase 4A preflight missing " .. marker)
end
for _, marker in ipairs({ "Throttle", "Steer", "Drift", "Boost", "SetSteering", "Reset" }) do
	assert(string.find(inputState.Source, marker, 1, true), "MobileDriveInputState preflight missing " .. marker)
end

local mobileConfig = ensure(uiConfigRoot, "Folder", "MobileFreeRoamHud")
local mobileAssets = ensure(mobileConfig, "Folder", "Assets")
value(mobileAssets, "StringValue", "TurnArrowImage", "")
value(mobileAssets, "StringValue", "DriftArrowImage", "")
value(mobileAssets, "StringValue", "AcceleratorImage", "")
value(mobileAssets, "StringValue", "BrakeImage", "")

local mobileDefaults = {
	DefaultControlMode = "Arrows", MinimapSize = 170, EdgeMargin = 14,
	NavButtonSize = 42, NavGap = 6, CashHeight = 34,
	ControlButtonSize = 70, PedalWidth = 78, PedalHeight = 96,
	ThumbstickSize = 150, TiltMaxDegrees = 28, TiltDeadzoneDegrees = 3,
	TiltSmoothing = 10, HudScale = 1, ArrowWidthMultiplier = 1.5,
	BoostIconScale = 1.05, BoostPlateScale = 0.84, BoostPlateGradientRotation = 45,
	TopClusterGap = 6, TelemetryBottomMargin = 2,
	CarMenuWidth = 430, CarMenuWidthRatio = 0.4, CarMenuTop = 84,
	CarMenuBottomMargin = 2, CarMenuCardGap = 5, CarMenuVisibleRows = 3,
	CarMenuCardAspect = 0.88, CarMenuCardTopSafePadding = 3,
	CarMenuCardBottomSafePadding = 3, CarMenuCardStrokeSafePadding = 5,
	CarMenuDespawnHeight = 20, CarMenuFooterGap = 3,
	CarMenuTargetCardWidth = 92, CarMenuPanelPadding = 5,
	CarMenuHeaderHeight = 36, CarMenuDropdownHeight = 28,
	CarMenuLeftMargin = 3, CarMenuMaxWidthRatio = 0.42,
	CarMenuVehicleImageYOffset = 0.13, CarMenuDespawnGradientTransparency = 0.72,
}
for name, default in pairs(mobileDefaults) do if mobileConfig:GetAttribute(name) == nil then mobileConfig:SetAttribute(name, default) end end
local phase1FUpgrades = {
	CarMenuTop = { 84, 82 }, CarMenuBottomMargin = { 12, 2 },
	CarMenuCardGap = { 8, 6 }, CarMenuVisibleRows = { 3, 2 },
	CarMenuCardTopSafePadding = { 8, 4 }, CarMenuCardBottomSafePadding = { 8, 4 },
	CarMenuDespawnHeight = { 32, 26 }, CarMenuFooterGap = { 8, 4 },
}
for name, pair in pairs(phase1FUpgrades) do local current=mobileConfig:GetAttribute(name); if current==nil or current==pair[1] then mobileConfig:SetAttribute(name,pair[2]) end end
local phase1GUpgrades = {
	CarMenuTargetCardWidth = { 180, 160 }, CarMenuPanelPadding = { 6, 5 },
	CarMenuHeaderHeight = { 72, 36 }, CarMenuDropdownHeight = { 36, 28 },
	CarMenuDespawnHeight = { 26, 20 }, CarMenuFooterGap = { 4, 3 },
	CarMenuCardGap = { 6, 5 }, CarMenuCardTopSafePadding = { 4, 3 },
	CarMenuCardBottomSafePadding = { 4, 3 },
}
for name, pair in pairs(phase1GUpgrades) do local current=mobileConfig:GetAttribute(name); if current==nil or current==pair[1] then mobileConfig:SetAttribute(name,pair[2]) end end
local phase1HUpgrades = {
	CarMenuTargetCardWidth = { 160, 108 },
}
for name, pair in pairs(phase1HUpgrades) do local current=mobileConfig:GetAttribute(name); if current==nil or current==pair[1] then mobileConfig:SetAttribute(name,pair[2]) end end
local phase1IUpgrades = {
	CarMenuTargetCardWidth = { 108, 92 }, CarMenuVisibleRows = { 2, 3 },
}
for name, pair in pairs(phase1IUpgrades) do local current=mobileConfig:GetAttribute(name); if current==nil or current==pair[1] then mobileConfig:SetAttribute(name,pair[2]) end end
local phase1KUpgrades = {
	BoostIconScale = { 1.5, 1.05 },
}
for name, pair in pairs(phase1KUpgrades) do local current=mobileConfig:GetAttribute(name); if current==nil or current==pair[1] then mobileConfig:SetAttribute(name,pair[2]) end end
mobileConfig:SetAttribute("InstalledBy", MARKER)

local sharedConfig = ensure(shared, "Folder", "Config")
local driveConfig = ensure(sharedConfig, "Folder", "MobileDriveControls_EditAttributes")
local driveDefaults = {
	SteeringDeadzone = 0, SteeringResponseExponent = 1, DriftEnterThreshold = 0.95,
	DriftExitThreshold = 0.88, ThumbstickInnerScale = 1.4,
	ThumbstickOuterRingScale = 1.35, TouchHitAreaMultiplier = 1.05,
}
for name, default in pairs(driveDefaults) do if driveConfig:GetAttribute(name) == nil then driveConfig:SetAttribute(name, default) end end

local CONTROLS_SOURCE = [====[
-- NTR_MOBILE_FREEROAM_UI_PHASE1K_BOOST_PLATE_EXIT_ALIGNMENT
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
if not UserInputService.TouchEnabled then return end

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("MobileFreeRoamHud")
local assets=config:WaitForChild("Assets")
local desktopAssets=kit.Config.UI:WaitForChild("DesktopFreeRoamHud"):WaitForChild("Assets")
local M=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("MobileDriveInputState"))

local PANEL=Color3.fromRGB(15,19,24)
local SOFT=Color3.fromRGB(24,29,36)
local PINK=Color3.fromRGB(244,46,151)
local CYAN=Color3.fromRGB(43,225,218)
local BLUE=Color3.fromRGB(25,116,255)
local WHITE=Color3.fromRGB(246,248,252)
local MUTED=Color3.fromRGB(163,171,184)
local FONT=Enum.Font.Michroma

local function A(name, fallback) local v=config:GetAttribute(name); if v==nil then return fallback end return v end
local function sourceAsset(folder,name) local v=folder:FindFirstChild(name); local s=tostring(v and v.Value or ""); if tonumber(s) then return "rbxassetid://"..s end return s end
local function asset(name) return sourceAsset(assets,name) end
local function new(class,props,parent) local x=Instance.new(class); for k,v in pairs(props or {}) do x[k]=v end x.Parent=parent; return x end
local function corner(parent,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 12)},parent) end
local function stroke(parent,color,width,transparency) return new("UIStroke",{Color=color,Thickness=width or 2,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent) end
local function label(parent,name,text,size,pos,textSize,color)
	return new("TextLabel",{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Size=size,Position=pos,Text=text,TextColor3=color or WHITE,TextSize=textSize or 12,Font=FONT,TextScaled=false,ZIndex=parent.ZIndex+2},parent)
end

local old=playerGui:FindFirstChild("NTR_MobileDriveControls_Phase1"); if old then old:Destroy() end
local gui=new("ScreenGui",{Name="NTR_MobileDriveControls_Phase1",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=96,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
local root=new("Frame",{Name="Root",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=1},gui)

local allButtons={}
local function controlButton(name,imageName,fallback,rotation)
	local b=new("TextButton",{Name=name,Text="",AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=0.12,BorderSizePixel=0,ClipsDescendants=true,ZIndex=5},root)
	corner(b,16); local s=stroke(b,PINK,2,0.05)
	local image=asset(imageName)
	if image~="" then new("ImageLabel",{Name="Art",BackgroundTransparency=1,BorderSizePixel=0,Image=image,Rotation=rotation or 0,ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromScale(1,1),ZIndex=6},b)
	else local fallbackSize=(name=="Accelerator" or name=="Brake") and 10 or name=="Boost" and 9 or name:find("Drift") and 22 or 28; local t=label(b,"Fallback",fallback,UDim2.fromScale(1,1),UDim2.fromScale(0,0),fallbackSize,WHITE); t.TextWrapped=true; t.Rotation=rotation or 0 end
	allButtons[b]=s
	return b
end
local function pressed(b,on) local s=allButtons[b]; if b.Name=="Boost" then b.BackgroundTransparency=1; if s then s.Transparency=1 end; return end; b.BackgroundTransparency=on and 0 or 0.12; if s then s.Color=on and CYAN or PINK; s.Thickness=on and 3 or 2 end local art=b:FindFirstChild("Art"); if art then art.ImageTransparency=on and 0 or 0.08 end end

local turnLeft=controlButton("TurnLeft","TurnArrowImage","<",0)
local turnRight=controlButton("TurnRight","TurnArrowImage",">",180)
local driftLeft=controlButton("DriftLeft","DriftArrowImage","<<",0)
local driftRight=controlButton("DriftRight","DriftArrowImage",">>",180)
local accelerator=controlButton("Accelerator","AcceleratorImage","ACCEL",0)
local brake=controlButton("Brake","BrakeImage","BRAKE",0)
local boost=controlButton("Boost","","",0)
local boostPlateScale=math.clamp(tonumber(A("BoostPlateScale",.84)) or .84,.5,1)
local boostPlate=new("Frame",{Name="BoostPlate",AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=CYAN,BackgroundTransparency=.04,BorderSizePixel=0,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(boostPlateScale,boostPlateScale),ZIndex=6},boost); corner(boostPlate,999); new("UIGradient",{Color=ColorSequence.new(BLUE,CYAN),Rotation=tonumber(A("BoostPlateGradientRotation",45)) or 45},boostPlate)
local boostIconScale=tonumber(A("BoostIconScale",1.05)) or 1.05
local boostArt=new("ImageLabel",{Name="BoostIcon",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Image=sourceAsset(desktopAssets,"BoostIcon"),ImageColor3=WHITE,Position=UDim2.fromScale(.5,.5),ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromOffset(32*boostIconScale,32*boostIconScale),ZIndex=7},boost)
local boostFallback=boost:FindFirstChild("Fallback"); boostFallback.Text="BOOST"; boostFallback.TextColor3=CYAN; boostFallback.TextXAlignment=Enum.TextXAlignment.Center; boostFallback.Visible=boostArt.Image==""

local thumbHit=new("TextButton",{Name="ThumbstickHit",Text="",AutoButtonColor=false,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4},root)
local thumbOuter=new("Frame",{Name="OuterDriftRing",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=PANEL,BackgroundTransparency=.36,BorderSizePixel=0,ZIndex=4},thumbHit); corner(thumbOuter,999); local outerStroke=stroke(thumbOuter,PINK,3,.08)
local thumbInner=new("Frame",{Name="InnerTurnRing",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=SOFT,BackgroundTransparency=.2,BorderSizePixel=0,ZIndex=5},thumbOuter); corner(thumbInner,999); stroke(thumbInner,CYAN,2,.12)
local thumbKnob=new("Frame",{Name="Knob",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundColor3=CYAN,BackgroundTransparency=.05,BorderSizePixel=0,ZIndex=7},thumbOuter); corner(thumbKnob,999); stroke(thumbKnob,WHITE,2,.12)
local thumbLabel=label(thumbOuter,"DriftLabel","DRIFT",UDim2.fromScale(.8,.18),UDim2.fromScale(.1,.77),9,PINK)

local tiltDrift=controlButton("TiltDrift","","DRIFT",0)
local tiltRecenter=controlButton("TiltRecenter","","RECENTER",0)
local tiltStatus=label(root,"TiltStatus","TILT STEERING",UDim2.fromOffset(180,20),UDim2.fromOffset(0,0),9,MUTED)

local buttonAction={[turnLeft]="TurnLeft",[turnRight]="TurnRight",[driftLeft]="DriftLeft",[driftRight]="DriftRight",[accelerator]="Accelerate",[brake]="Brake",[boost]="Boost",[tiltDrift]="TiltDrift"}
local activeInputs={}
local function refresh()
	if M.Refresh then M.Refresh() else
		local s=M.State; M.Throttle=(s.Accelerate and 1 or 0)-(s.Brake and 1 or 0); M.Steer=((s.TurnRight or s.DriftRight) and 1 or 0)-((s.TurnLeft or s.DriftLeft) and 1 or 0); M.Drift=s.DriftLeft or s.DriftRight; M.Boost=s.Boost
	end
end
local function setButton(b,on)
	local action=buttonAction[b]; if not action then return end
	if action=="TiltDrift" then M.AnalogDrift=on else M.State[action]=on end
	pressed(b,on); refresh()
end
for b in pairs(buttonAction) do
	b.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then activeInputs[input]=b; setButton(b,true) end end)
	b.InputEnded:Connect(function(input) if activeInputs[input]==b then activeInputs[input]=nil; setButton(b,false) end end)
end
UserInputService.InputEnded:Connect(function(input) local b=activeInputs[input]; if b then activeInputs[input]=nil; setButton(b,false) end end)

local activeThumb=nil
local thumbSteer=0
local thumbDrift=false
local function publishSteering(steer,drift) thumbSteer=steer; thumbDrift=drift; if M.SetSteering then M.SetSteering(steer,drift) else M.AnalogSteer=steer; M.AnalogDrift=drift; refresh() end end
local function updateThumb(position)
	local center=thumbOuter.AbsolutePosition+thumbOuter.AbsoluteSize*.5
	local delta=position-center
	local radius=math.max(thumbOuter.AbsoluteSize.X*.5-thumbKnob.AbsoluteSize.X*.45,1)
	local raw=math.clamp(delta.X/radius,-1,1)
	local enter=tonumber(kit.Shared.Config.MobileDriveControls_EditAttributes:GetAttribute("DriftEnterThreshold")) or .95
	local exit=tonumber(kit.Shared.Config.MobileDriveControls_EditAttributes:GetAttribute("DriftExitThreshold")) or .88
	if thumbDrift then thumbDrift=math.abs(raw)>=exit else thumbDrift=math.abs(raw)>=enter end
	thumbKnob.Position=UDim2.fromScale(.5+raw*.34,.5)
	thumbKnob.BackgroundColor3=thumbDrift and PINK or CYAN; outerStroke.Color=thumbDrift and CYAN or PINK
	publishSteering(raw,thumbDrift)
end
local function releaseThumb() activeThumb=nil; thumbKnob.Position=UDim2.fromScale(.5,.5); thumbKnob.BackgroundColor3=CYAN; outerStroke.Color=PINK; publishSteering(0,false) end
thumbHit.InputBegan:Connect(function(input) if activeThumb then return end; if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then activeThumb=input; updateThumb(input.Position) end end)
UserInputService.InputChanged:Connect(function(input) if input==activeThumb then updateThumb(input.Position) elseif activeThumb and activeThumb.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement then updateThumb(input.Position) end end)
UserInputService.InputEnded:Connect(function(input) if input==activeThumb then releaseThumb() end end)

local neutralRoll=0
local tiltTarget=0
local tiltCurrent=0
local latestRoll=0
local function normalizeAngle(x) while x>math.pi do x-=math.pi*2 end while x< -math.pi do x+=math.pi*2 end return x end
local function calibrate() neutralRoll=latestRoll; tiltTarget=0; tiltCurrent=0; tiltStatus.Text="TILT CALIBRATED" end
tiltRecenter.Activated:Connect(calibrate)
UserInputService.DeviceRotationChanged:Connect(function(_rotation,cf)
	local _,_,roll=cf:ToOrientation(); latestRoll=roll
	if tostring(player:GetAttribute("NTRMobileControlMode") or "")~="Tilt" then return end
	local degrees=math.deg(normalizeAngle(roll-neutralRoll)); local dead=tonumber(A("TiltDeadzoneDegrees",3)) or 3; local maximum=math.max(dead+1,tonumber(A("TiltMaxDegrees",28)) or 28)
	local sign=degrees<0 and -1 or 1; local mag=math.abs(degrees); tiltTarget=mag<=dead and 0 or sign*math.clamp((mag-dead)/(maximum-dead),0,1)
end)

local currentMode=""
local function clearInputs()
	for b in pairs(buttonAction) do pressed(b,false) end
	for key in pairs(M.State) do M.State[key]=false end
	M.AnalogDrift=false; releaseThumb(); refresh()
end
local function setMode(raw)
	local mode=tostring(raw or A("DefaultControlMode","Arrows")); if mode~="Arrows" and mode~="Thumbstick" and mode~="Tilt" then mode="Arrows" end
	if mode=="Tilt" and not UserInputService.GyroscopeEnabled then mode="Arrows"; player:SetAttribute("NTRMobileControlMode","Arrows") end
	if mode==currentMode then return end; clearInputs(); currentMode=mode
	local arrow=mode=="Arrows"; turnLeft.Visible=arrow; turnRight.Visible=arrow; driftLeft.Visible=arrow; driftRight.Visible=arrow
	thumbHit.Visible=mode=="Thumbstick"; tiltDrift.Visible=mode=="Tilt"; tiltRecenter.Visible=mode=="Tilt"; tiltStatus.Visible=mode=="Tilt"
	if mode=="Tilt" then local _,cf=UserInputService:GetDeviceRotation(); local _,_,roll=cf:ToOrientation(); latestRoll=roll; calibrate() end
end
player:GetAttributeChangedSignal("NTRMobileControlMode"):Connect(function() setMode(player:GetAttribute("NTRMobileControlMode")) end)
if not player:GetAttribute("NTRMobileControlMode") then player:SetAttribute("NTRMobileControlMode",A("DefaultControlMode","Arrows")) end
setMode(player:GetAttribute("NTRMobileControlMode"))

local lastSize=Vector2.zero
local function layout()
	local camera=workspace.CurrentCamera; local vp=camera and camera.ViewportSize or Vector2.new(1280,720); if vp==lastSize then return end; lastSize=vp
	local tiny=vp.Y<500; local margin=tiny and 10 or 16; local unit=math.floor(math.clamp(vp.Y*.118,tiny and 60 or 68,tiny and 76 or 90)); local gap=tiny and 7 or 10; local arrowW=math.floor(unit*(tonumber(A("ArrowWidthMultiplier",1.5)) or 1.5))
	local leftY=vp.Y-margin-unit*2-gap; local leftX=margin
	driftLeft.Position=UDim2.fromOffset(leftX,leftY); driftLeft.Size=UDim2.fromOffset(arrowW,unit)
	driftRight.Position=UDim2.fromOffset(leftX+arrowW+gap,leftY); driftRight.Size=UDim2.fromOffset(arrowW,unit)
	turnLeft.Position=UDim2.fromOffset(leftX,leftY+unit+gap); turnLeft.Size=UDim2.fromOffset(arrowW,unit)
	turnRight.Position=UDim2.fromOffset(leftX+arrowW+gap,leftY+unit+gap); turnRight.Size=UDim2.fromOffset(arrowW,unit)
	local boostHit=tiny and 44 or 52; local arrowClusterW=arrowW*2+gap; boost.Position=UDim2.fromOffset(leftX+math.floor((arrowClusterW-boostHit)/2),leftY-boostHit-(tiny and 8 or 12)); boost.Size=UDim2.fromOffset(boostHit,boostHit); boost.BackgroundTransparency=1; local boostStroke=allButtons[boost]; if boostStroke then boostStroke.Transparency=1 end
	local stick=math.floor(math.clamp(vp.Y*.265,132,188)); thumbHit.Position=UDim2.fromOffset(margin,vp.Y-margin-stick); thumbHit.Size=UDim2.fromOffset(stick,stick); thumbOuter.Size=UDim2.fromScale(1,1); thumbInner.Size=UDim2.fromScale(.73,.73); thumbKnob.Size=UDim2.fromScale(.28,.28)
	tiltDrift.Position=UDim2.fromOffset(margin,vp.Y-margin-unit); tiltDrift.Size=UDim2.fromOffset(unit*1.45,unit)
	tiltRecenter.Position=UDim2.fromOffset(margin,vp.Y-margin-unit*2-gap); tiltRecenter.Size=UDim2.fromOffset(unit*1.45,unit*.72); tiltStatus.Position=UDim2.fromOffset(margin,vp.Y-margin-unit*2-gap-22)
	local pedalH=math.floor(math.clamp(vp.Y*.205,96,134)); local pedalW=math.floor(pedalH*.78)
	accelerator.Position=UDim2.fromOffset(vp.X-margin-pedalW,vp.Y-margin-pedalH); accelerator.Size=UDim2.fromOffset(pedalW,pedalH)
	brake.Position=UDim2.fromOffset(vp.X-margin-pedalW*2-gap,vp.Y-margin-pedalH*.78); brake.Size=UDim2.fromOffset(pedalW,pedalH*.78)
end

local wasDriving=false
local wasMenuBlocked=false
RunService.RenderStepped:Connect(function(dt)
	layout(); local driving=M.IsDriving==true; local menuBlocked=player:GetAttribute("NTRMobileFreeRoamCarMenuOpen")==true; root.Visible=driving and not menuBlocked
	if menuBlocked then if not wasMenuBlocked then clearInputs() end; wasMenuBlocked=true; return end; wasMenuBlocked=false
	if not driving then if wasDriving then clearInputs() end; wasDriving=false; return end; wasDriving=true
	if currentMode=="Tilt" then local smoothing=math.max(0,tonumber(A("TiltSmoothing",10)) or 10); local alpha=1-math.exp(-smoothing*dt); tiltCurrent+=(tiltTarget-tiltCurrent)*alpha; publishSteering(tiltCurrent,M.AnalogDrift==true) end
end)
print("[NTR Mobile Free-Roam UI Phase 1K] Compact boost plate and touch controls active.")
]====]

local HUD_SOURCE = [====[
-- NTR_MOBILE_FREEROAM_UI_PHASE1K_BOOST_PLATE_EXIT_ALIGNMENT
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
if not UserInputService.TouchEnabled then return end

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("MobileFreeRoamHud")
local desktop=kit.Config.UI:WaitForChild("DesktopFreeRoamHud")
local colours=desktop:WaitForChild("Colours")
local desktopLayout=desktop:WaitForChild("Layout")
local desktopAssets=desktop:WaitForChild("Assets")
local desktopDefaults=desktop:WaitForChild("Defaults")
local desktopEffects=desktop:WaitForChild("Effects")
local remotes=kit:WaitForChild("Shared"):WaitForChild("Remotes")
local garage=remotes:WaitForChild("Garage")
local garageInvoke=garage:WaitForChild("GarageInvoke")
local interiorInvoke=garage:FindFirstChild("GarageInteriorInvoke")
local teleportInvoke=remotes:WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportInvoke")
local categories=kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local drive=require(kit.Shared.Modules.Client.Controllers:WaitForChild("MobileDriveInputState"))
local uiFolder=script.Parent

local FONT=Enum.Font.Michroma
local function read(folder,name,fallback) local v=folder and folder:FindFirstChild(name); if v and v:IsA("ValueBase") then return v.Value end local a=folder and folder:GetAttribute(name); if a~=nil then return a end return fallback end
local function B(folder,name,fallback) local value=read(folder,name,fallback); return value==true end
local function C(name,fallback) local value=read(colours,name,nil); return typeof(value)=="Color3" and value or fallback end
local function E(name,fallback) return tonumber(read(desktopEffects,name,fallback)) or fallback end
local PANEL=C("Panel",Color3.fromRGB(15,19,24)); local DEEP=C("PanelDeep",Color3.fromRGB(9,12,16)); local SOFT=C("PanelSoft",Color3.fromRGB(24,29,36)); local PINK=C("Outline",Color3.fromRGB(244,46,151)); local PINK_SOFT=C("OutlineSoft",Color3.fromRGB(214,74,175)); local CYAN=C("Telemetry",Color3.fromRGB(43,225,218)); local BLUE=C("ElectricBlue",Color3.fromRGB(25,116,255)); local WHITE=C("Text",Color3.fromRGB(246,248,252)); local MUTED=C("Muted",Color3.fromRGB(163,171,184)); local DANGER=C("Danger",Color3.fromRGB(196,57,75))
local function asset(folder,name) local s=tostring(read(folder,name,"") or ""); if tonumber(s) then return "rbxassetid://"..s end return s end
local function new(class,props,parent) local x=Instance.new(class); for k,v in pairs(props or {}) do x[k]=v end x.Parent=parent; return x end
local function corner(parent,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 10)},parent) end
local function stroke(parent,color,width,transparency) return new("UIStroke",{Color=color,Thickness=width or 2,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent) end
local function label(parent,name,text,size,pos,textSize,color,align)
	return new("TextLabel",{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Size=size,Position=pos,Text=text,TextColor3=color or WHITE,TextSize=textSize or 12,Font=FONT,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=parent.ZIndex+2},parent)
end
local function panel(parent,name,size,pos,z) local p=new("Frame",{Name=name,BackgroundColor3=DEEP,BackgroundTransparency=.14,BorderSizePixel=0,Size=size,Position=pos,ZIndex=z or 4},parent); corner(p,10); stroke(p,PINK,2,.08); return p end
local function button(parent,name,text,size,pos,accent)
	local b=new("TextButton",{Name=name,Text=text,TextColor3=WHITE,TextSize=11,Font=FONT,AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=.08,BorderSizePixel=0,Size=size,Position=pos,ZIndex=parent.ZIndex+2},parent); corner(b,8); stroke(b,accent or PINK,1.7,.04); return b
end
local function surfaceGradient(parent,topColor,bottomColor,rotation) return new("UIGradient",{Name="SurfaceGradient",Color=ColorSequence.new(topColor,bottomColor),Transparency=NumberSequence.new(E("GradientTransparency",.12)),Rotation=rotation or 90},parent) end
local function buttonGradient(parent)
	local strength=math.clamp(E("ButtonGradientStrength",.10),0,.35); local overlay=new("Frame",{Name="GradientOverlay",Active=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1-strength,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=parent.ZIndex},parent); corner(overlay,6); new("UIGradient",{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(95,95,95)),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.20),NumberSequenceKeypoint.new(.52,.70),NumberSequenceKeypoint.new(1,.28)}),Rotation=E("ButtonGradientRotation",90)},overlay); return overlay
end
local function addFacetPattern(parent)
	local pattern=new("Frame",{Name="FacetPattern",BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Size=UDim2.fromScale(1,1),ZIndex=parent.ZIndex},parent); for i=1,3 do new("Frame",{Name="Facet"..i,BackgroundColor3=PINK_SOFT,BackgroundTransparency=math.clamp(E("PatternTransparency",.94)+i*.012,0,1),BorderSizePixel=0,Position=UDim2.new(-.15+i*.28,0,.12+i*.18,0),Size=UDim2.new(.52,0,0,2),Rotation=-18,ZIndex=parent.ZIndex},pattern) end; return pattern
end
local function carNeutralSurface(parent,name,size,pos,z)
	local item=new("Frame",{Name=name,BackgroundColor3=SOFT,BackgroundTransparency=E("DropdownTransparency",.06),BorderSizePixel=0,ClipsDescendants=true,Size=size,Position=pos,ZIndex=z or 30},parent); corner(item,7); surfaceGradient(item,SOFT,PANEL,90); return item
end
local function styleCarButton(item,accent,thickness,withGlow)
	local line=item:FindFirstChildOfClass("UIStroke"); if line then line.Color=accent or PINK; line.Thickness=thickness or 1.4; line.Transparency=.08 end; buttonGradient(item); if withGlow then local glow=stroke(item,accent or PINK,4,E("GlowTransparency",.82)); glow.Name="GlowStroke" end; return item
end
local function call(action,payload) local ok,result=pcall(function() return garageInvoke:InvokeServer(action,payload or {}) end); if ok and typeof(result)=="table" then return result end return {Success=false,Message=tostring(result)} end
local function fire(name,payload) local event=uiFolder:FindFirstChild(name); if event and event:IsA("BindableEvent") then event:Fire(payload); return true end return false end

local old=playerGui:FindFirstChild("NTR_MobileFreeRoamHud_Phase1"); if old then old:Destroy() end
local gui=new("ScreenGui",{Name="NTR_MobileFreeRoamHud_Phase1",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=88,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
local root=new("Frame",{Name="Root",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=1},gui)
local legacyItemConnections=setmetatable({},{__mode="k"})
local legacyDescendantConnection=nil
local legacyHudWatched=nil
local legacyVisualNames={MobileDriveControls=true,DriveHUD=true,DriveMenu=true}
local function hideExactLegacyVisual(item)
	if not (item and item:IsA("GuiObject") and legacyVisualNames[item.Name]) then return end
	item.Visible=false
	if not legacyItemConnections[item] then legacyItemConnections[item]=item:GetPropertyChangedSignal("Visible"):Connect(function() if item.Parent and item.Visible then item.Visible=false end end) end
end
local function suppressExactLegacyHud()
	local legacy=playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	if not (legacy and legacy:IsA("ScreenGui")) then return end
	for _,item in ipairs(legacy:GetDescendants()) do hideExactLegacyVisual(item) end
	if legacy~=legacyHudWatched then if legacyDescendantConnection then legacyDescendantConnection:Disconnect() end; legacyHudWatched=legacy; legacyDescendantConnection=legacy.DescendantAdded:Connect(function(item) task.defer(function() hideExactLegacyVisual(item) end) end) end
end
playerGui.ChildAdded:Connect(function(child) if child.Name=="HOVER_RACING_V2_DriveHUD" then task.defer(suppressExactLegacyHud) end end)
suppressExactLegacyHud()
local toast=label(root,"Toast","",UDim2.fromOffset(420,34),UDim2.fromScale(.5,.12),12,WHITE,Enum.TextXAlignment.Center); toast.AnchorPoint=Vector2.new(.5,0); toast.BackgroundColor3=DEEP; toast.BackgroundTransparency=.15; toast.Visible=false; corner(toast,8); stroke(toast,PINK,1.5,.1)
local function showToast(text,positive) toast.Text=tostring(text); toast.TextColor3=positive and CYAN or WHITE; toast.Visible=true; local stamp=os.clock(); toast:SetAttribute("Stamp",stamp); task.delay(2.2,function() if toast.Parent and toast:GetAttribute("Stamp")==stamp then toast.Visible=false end end) end

local mapFrame=new("Frame",{Name="Minimap",BackgroundColor3=DEEP,BackgroundTransparency=.28,BorderSizePixel=0,Size=UDim2.fromOffset(170,170),Position=UDim2.fromOffset(0,0),ClipsDescendants=true,ZIndex=5},root); corner(mapFrame,9)
local mapCanvas=new("Frame",{Name="MapCanvas",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(170,170),ZIndex=6},mapFrame)
local tileNames={"MapTileTopLeft","MapTileTopRight","MapTileBottomLeft","MapTileBottomRight"}; local tilePos={UDim2.fromScale(0,0),UDim2.fromScale(.5,0),UDim2.fromScale(0,.5),UDim2.fromScale(.5,.5)}
local anyTile=false
for i,name in ipairs(tileNames) do local image=asset(desktopAssets,name); if image~="" then anyTile=true end; new("ImageLabel",{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Image=image,ScaleType=Enum.ScaleType.Stretch,Position=tilePos[i],Size=UDim2.fromScale(.5,.5),ZIndex=6},mapCanvas) end
local mapMissing=label(mapFrame,"Missing",anyTile and "" or "ADD MAP TILE IDS",UDim2.fromScale(1,.2),UDim2.fromScale(0,.4),9,MUTED,Enum.TextXAlignment.Center)
local playerMarker=new("ImageLabel",{Name="PlayerMarker",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"MapPlayerIcon"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(18,18),ZIndex=9},mapFrame)
if playerMarker.Image=="" then playerMarker:Destroy(); playerMarker=label(mapFrame,"PlayerMarker","▲",UDim2.fromOffset(24,24),UDim2.fromScale(.5,.5),18,CYAN,Enum.TextXAlignment.Center); playerMarker.AnchorPoint=Vector2.new(.5,.5) end
local north=new("ImageLabel",{Name="North",AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"MapNorthArrow"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(22,22),ZIndex=9},mapFrame)
if north.Image=="" then north:Destroy(); north=label(mapFrame,"North","N",UDim2.fromOffset(22,22),UDim2.new(1,-28,0,6),10,PINK,Enum.TextXAlignment.Center) end
local function edgeFade(name,position,size,rotation)
	local edge=new("Frame",{Name=name,BackgroundColor3=DEEP,BackgroundTransparency=0,BorderSizePixel=0,Position=position,Size=size,ZIndex=8},mapFrame)
	new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,1)}),Rotation=rotation},edge)
end
edgeFade("EdgeLeft",UDim2.fromScale(0,0),UDim2.new(.2,0,1,0),0)
edgeFade("EdgeRight",UDim2.new(.8,0,0,0),UDim2.new(.2,0,1,0),180)
edgeFade("EdgeTop",UDim2.fromScale(0,0),UDim2.new(1,0,.2,0),90)
edgeFade("EdgeBottom",UDim2.new(0,0,.8,0),UDim2.new(1,0,.2,0),-90)

local cash=panel(root,"Cash",UDim2.fromOffset(170,34),UDim2.fromOffset(0,0),5); cash.BackgroundColor3=Color3.fromRGB(8,42,84); cash.ClipsDescendants=true; local cashText=label(cash,"Value","$0",UDim2.new(1,-52,1,0),UDim2.fromOffset(6,0),14,WHITE); cashText.TextWrapped=false; cashText.TextScaled=true; cashText.TextTruncate=Enum.TextTruncate.None; new("UITextSizeConstraint",{MinTextSize=5,MaxTextSize=14},cashText); local cashPlus=button(cash,"Plus","+",UDim2.fromOffset(28,26),UDim2.new(1,-32,.5,-13),BLUE); cashPlus.TextSize=18

local nav=new("Frame",{Name="Navigation",BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},root)
local navButtons={}
local function navButton(name,iconName,fallback)
	local b=button(nav,name,"",UDim2.fromOffset(42,42),UDim2.fromOffset(0,0),PINK); local image=asset(desktopAssets,iconName)
	if image~="" then new("ImageLabel",{Name="Icon",BackgroundTransparency=1,BorderSizePixel=0,Image=image,ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.fromScale(.17,.17),Size=UDim2.fromScale(.66,.66),ZIndex=b.ZIndex+1},b) else label(b,"Fallback",fallback,UDim2.fromScale(1,1),UDim2.fromScale(0,0),8,WHITE,Enum.TextXAlignment.Center) end
	navButtons[name]=b; return b
end
local carButton=navButton("Car","CarIcon","CAR"); local garageButton=navButton("Garage","GarageIcon","HOME"); local raceButton=navButton("Race","RaceIcon","RACE"); local shopButton=navButton("Dealership","DealershipIcon","SHOP"); local settingsButton=navButton("Settings","SettingsIcon","SET")

local telemetry=new("Frame",{Name="Telemetry",AnchorPoint=Vector2.new(.5,1),BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(420,190),ZIndex=4,Visible=false},root)
local telemetryScale=new("UIScale",{Scale=.72},telemetry)
local boostIconBox=new("Frame",{Name="BoostIconContainer",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(303,145),Size=UDim2.fromOffset(34,34),ZIndex=5},telemetry)
local boostIcon=new("ImageLabel",{Name="BoostIcon",BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"BoostIcon"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromScale(1,1),ZIndex=6},boostIconBox)
local boostFallback=label(boostIconBox,"Fallback","⚡",UDim2.fromScale(1,1),UDim2.fromScale(0,0),20,CYAN,Enum.TextXAlignment.Center); boostFallback.Visible=boostIcon.Image==""
local boostTrack=new("Frame",{Name="BoostTrack",BackgroundColor3=SOFT,BorderSizePixel=0,Position=UDim2.fromOffset(311,42),Size=UDim2.fromOffset(18,96),ClipsDescendants=true,ZIndex=5},telemetry); corner(boostTrack,7)
local boostFill=new("Frame",{Name="BoostFill",AnchorPoint=Vector2.new(0,1),BackgroundColor3=CYAN,BorderSizePixel=0,Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,1),ZIndex=6},boostTrack); corner(boostFill,6); new("UIGradient",{Color=ColorSequence.new(BLUE,CYAN),Rotation=-90},boostFill)
local speedText=label(telemetry,"Speed","0",UDim2.fromOffset(190,78),UDim2.fromOffset(105,66),64,WHITE,Enum.TextXAlignment.Center); speedText.TextStrokeColor3=CYAN; speedText.TextStrokeTransparency=.8
local unitText=label(telemetry,"Unit","MPH",UDim2.fromOffset(190,28),UDim2.fromOffset(105,137),15,WHITE,Enum.TextXAlignment.Center)
local gauge={}; for i=1,16 do local alpha=(i-1)/15; local normalized=(alpha-.5)*2; local x=122+alpha*156; local y=18+normalized*normalized*18; local g=new("Frame",{Name="GaugeSegment"..i,BackgroundColor3=Color3.fromRGB(81,88,99),BackgroundTransparency=.42,BorderSizePixel=0,Position=UDim2.fromOffset(x-4,y),Size=UDim2.fromOffset(8,23),Rotation=normalized*10,ZIndex=5},telemetry); corner(g,3); table.insert(gauge,g) end
local exitButton=button(telemetry,"ExitVehicle","EXIT",UDim2.fromOffset(76,30),UDim2.fromOffset(24,111),PINK); exitButton.Visible=false; exitButton.TextSize=9; exitButton.BackgroundTransparency=.48

local carDismiss=new("TextButton",{Name="CarMenuOutsideTap",Text="",AutoButtonColor=false,Active=true,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=18},root)
local carPanel=panel(root,"CarPanel",UDim2.fromOffset(335,620),UDim2.fromOffset(3,84),21); carPanel.Visible=false; local carPanelStroke=carPanel:FindFirstChildOfClass("UIStroke"); if carPanelStroke then carPanelStroke:Destroy() end; surfaceGradient(carPanel,SOFT,DEEP,110); addFacetPattern(carPanel)
local function carDropdown(name)
	local b=button(carPanel,name,"",UDim2.fromOffset(158,28),UDim2.fromOffset(0,0),PINK)
	styleCarButton(b,PINK_SOFT,1.4,true)
	label(b,"Value","",UDim2.new(1,-30,1,0),UDim2.fromOffset(7,0),8,WHITE)
	label(b,"Chevron","v",UDim2.fromOffset(18,18),UDim2.new(1,-21,.5,-9),8,CYAN,Enum.TextXAlignment.Center)
	return b
end
local carCategory=carDropdown("Category")
local carSort=carDropdown("Sort")
local carScroll=new("ScrollingFrame",{Name="VehicleGrid",BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=4,ScrollBarImageColor3=CYAN,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=23},carPanel)
local carContent=new("Frame",{Name="Content",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(0,0),ZIndex=23},carScroll)
local carGrid=new("UIGridLayout",{CellPadding=UDim2.fromOffset(8,8),CellSize=UDim2.fromOffset(170,150),FillDirection=Enum.FillDirection.Horizontal,FillDirectionMaxCells=2,HorizontalAlignment=Enum.HorizontalAlignment.Left,SortOrder=Enum.SortOrder.LayoutOrder},carContent)
local carDespawn=button(carPanel,"Despawn","DESPAWN",UDim2.new(1,-10,0,20),UDim2.new(0,5,1,-22),DANGER); carDespawn.BackgroundColor3=DANGER; carDespawn.TextSize=7; local carDespawnStroke=carDespawn:FindFirstChildOfClass("UIStroke"); if carDespawnStroke then carDespawnStroke:Destroy() end; local carDespawnGradient=buttonGradient(carDespawn); carDespawnGradient.BackgroundTransparency=math.clamp(tonumber(read(config,"CarMenuDespawnGradientTransparency",.72)),0,1)
local carChoice=nil
local carChoiceAnchor=nil
local carMenuOpen=false
local carBusy=false
player:SetAttribute("NTRMobileFreeRoamCarMenuOpen",false)

local shade=new("TextButton",{Name="Shade",Text="",AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.35,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=20},root)
local modal=panel(root,"Modal",UDim2.fromOffset(620,360),UDim2.fromScale(.5,.5),22); modal.AnchorPoint=Vector2.new(.5,.5); modal.Visible=false
local modalTitle=label(modal,"Title","",UDim2.new(1,-32,0,44),UDim2.fromOffset(16,8),18,WHITE)
local modalBody=new("Frame",{Name="Body",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(14,56),Size=UDim2.new(1,-28,1,-70),ZIndex=23},modal)
local function clear(parent) for _,x in ipairs(parent:GetChildren()) do if not x:IsA("UIListLayout") and not x:IsA("UIPadding") then x:Destroy() end end end
local function closeModal() shade.Visible=false; modal.Visible=false; clear(modalBody) end
shade.Activated:Connect(closeModal)
local function openModal(title) clear(modalBody); modalTitle.Text=title; shade.Visible=true; modal.Visible=true end

local function segmented(parent,y,titleText,options,selected,onPick,disabled)
	label(parent,titleText.."Label",titleText,UDim2.new(1,-20,0,20),UDim2.fromOffset(10,y),10,WHITE)
	local gap=6; local width=math.floor((parent.AbsoluteSize.X-20-gap*(#options-1))/#options)
	for i,option in ipairs(options) do local active=option==selected; local b=button(parent,titleText..option,option,UDim2.fromOffset(width,34),UDim2.fromOffset(10+(i-1)*(width+gap),y+22),active and CYAN or PINK); b.BackgroundColor3=active and Color3.fromRGB(8,42,84) or PANEL; if disabled and disabled[option] then b.TextColor3=MUTED; b.Active=false else b.Activated:Connect(function() onPick(option) end) end end
end

local function showSettings()
	openModal("SETTINGS")
	local selected=tostring(player:GetAttribute("NTRMobileControlMode") or read(config,"DefaultControlMode","Arrows"))
	segmented(modalBody,0,"MOBILE CONTROLS",{"Arrows","Thumbstick","Tilt"},selected,function(option) player:SetAttribute("NTRMobileControlMode",option); showSettings() end,{Tilt=not UserInputService.GyroscopeEnabled})
	label(modalBody,"TopHint",UserInputService.GyroscopeEnabled and "Tilt includes DRIFT and RECENTER controls." or "Tilt unavailable: this device has no gyroscope.",UDim2.new(1,-20,0,22),UDim2.fromOffset(10,59),9,MUTED)
	segmented(modalBody,88,"GRAPHICS",{"LOW","MEDIUM","HIGH"},"HIGH",function() end)
	segmented(modalBody,154,"UI SCALE",{"85%","100%","115%"},"100%",function() end)
	segmented(modalBody,220,"SPEED UNIT",{"MPH","KPH"},"MPH",function() end)
	local done=button(modalBody,"Done","DONE",UDim2.fromOffset(150,38),UDim2.new(1,-160,1,-42),CYAN); done.Activated:Connect(closeModal)
end

local function showCash()
	openModal("GET CASH"); label(modalBody,"Message","Cash products are not enabled yet.",UDim2.new(1,-20,0,60),UDim2.fromOffset(10,50),13,WHITE,Enum.TextXAlignment.Center); local done=button(modalBody,"Done","CLOSE",UDim2.fromOffset(150,40),UDim2.new(.5,-75,1,-55),PINK); done.Activated:Connect(closeModal)
end
cashPlus.Activated:Connect(showCash)

local function showTeleport()
	openModal("TELEPORT TO DEALERSHIP?"); label(modalBody,"Message","Your current vehicle will be despawned.",UDim2.new(1,-20,0,60),UDim2.fromOffset(10,46),12,WHITE,Enum.TextXAlignment.Center)
	local no=button(modalBody,"No","NO",UDim2.fromOffset(180,44),UDim2.new(.5,-190,1,-58),PINK); local yes=button(modalBody,"Yes","YES",UDim2.fromOffset(180,44),UDim2.new(.5,10,1,-58),CYAN)
	no.Activated:Connect(closeModal); yes.Activated:Connect(function() closeModal(); local ok,result=pcall(function() return teleportInvoke:InvokeServer("TeleportToDealership") end); if ok and typeof(result)=="table" and result.Success then fire("FreeRoamVehicleExited"); showToast(result.Message or "TELEPORTED",true) else showToast(typeof(result)=="table" and (result.Message or result.Error) or "TELEPORT FAILED",false) end end)
end

local profileCache=nil
local lastProfile=0
local function profile(force) if profileCache and not force and os.clock()-lastProfile<2 then return profileCache end; local r=call("GetInitial",{}); profileCache=r.Profile or r; lastProfile=os.clock(); return profileCache or {} end
local function cockpitModel(id) local target=string.lower(tostring(id or "")); if target=="" then return nil end; for _,x in ipairs(categories:GetDescendants()) do if x:IsA("Model") then local xid=string.lower(tostring(x:GetAttribute("CockpitId") or x:GetAttribute("TemplateId") or x.Name)); if xid==target or string.gsub(xid,"^cockpit_","")==target or string.find(xid,target,1,true) then return x end end end end
local function vehicleCategory(vehicle,cockpitId) local explicit=tostring(vehicle and (vehicle.CategoryId or vehicle.Category) or ""); if explicit~="" then return string.upper(explicit) end; return string.upper(string.match(tostring(cockpitId or ""),"^([^_]+)") or "OTHER") end
local function tierColor(tier) return ({E=Color3.fromRGB(132,142,145),D=Color3.fromRGB(105,190,129),C=Color3.fromRGB(74,204,211),B=Color3.fromRGB(82,137,235),A=Color3.fromRGB(244,188,65),S=Color3.fromRGB(236,92,168)})[string.upper(tostring(tier or ""))] or PINK end
local function vehicleRows()
	local p=profile(false); local rows={}
	for vehicleId,v in pairs(p.Vehicles or {}) do local cockpitId=tostring(v.CockpitId or ""); if cockpitId=="" and v.CockpitInstanceId and p.OwnedCockpitInstances then local inst=p.OwnedCockpitInstances[v.CockpitInstanceId]; cockpitId=tostring(inst and inst.TemplateId or "") end; local model=cockpitModel(cockpitId); local summary=p.VehicleSummaries and p.VehicleSummaries[vehicleId]; local overall=summary and summary.Overall or {}; local image=tostring(model and (model:GetAttribute("MenuImage") or model:GetAttribute("CockpitImage")) or ""); if tonumber(image) then image="rbxassetid://"..image end; table.insert(rows,{VehicleId=tostring(vehicleId),CockpitId=cockpitId,Category=vehicleCategory(v,cockpitId),Name=string.upper(string.gsub(tostring(model and model:GetAttribute("DisplayName") or cockpitId or "VEHICLE"),"_"," ")),Image=image,Tier=tostring(overall.Tier or "E"),Rating=tonumber(overall.PerformanceIndex) or 0,Price=tonumber(model and model:GetAttribute("Price")) or 0,Selected=tostring(p.CurrentVehicleId or "")==tostring(vehicleId)}) end
	return rows
end
local selectedCategory="ALL"
local selectedSort="RATING"
local renderCars
local function closeCarChoice() if carChoice then carChoice:Destroy(); carChoice=nil end; carChoiceAnchor=nil end
local function setCarMenuOpen(open)
	carMenuOpen=open==true; closeCarChoice(); carDismiss.Visible=carMenuOpen; carPanel.Visible=carMenuOpen; player:SetAttribute("NTRMobileFreeRoamCarMenuOpen",carMenuOpen)
	if carMenuOpen then closeModal(); renderCars() end
end
local function showCarChoices(anchor,options,onPick)
	if carChoice and carChoiceAnchor==anchor then closeCarChoice(); return end; closeCarChoice(); carChoiceAnchor=anchor; local height=#options*31+8; carChoice=carNeutralSurface(carPanel,"ChoiceList",UDim2.fromOffset(anchor.AbsoluteSize.X,height),UDim2.fromOffset(anchor.Position.X.Offset,anchor.Position.Y.Offset+anchor.AbsoluteSize.Y+4),32)
	for i,option in ipairs(options) do local item=new("TextButton",{Name="Choice"..i,AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=.12,BorderSizePixel=0,Size=UDim2.new(1,-8,0,27),Position=UDim2.fromOffset(4,4+(i-1)*31),Text=option,TextColor3=WHITE,TextSize=9,Font=FONT,ZIndex=34},carChoice); corner(item,5); buttonGradient(item); item.Activated:Connect(function() closeCarChoice(); onPick(option) end) end
end
local function makeCarCard(row,order)
	local card=button(carContent,"Vehicle"..order,"",UDim2.fromOffset(92,80),UDim2.fromOffset(0,0),row.Selected and CYAN or PINK); card.LayoutOrder=order; card.BackgroundColor3=row.Selected and Color3.fromRGB(8,42,84) or PANEL; styleCarButton(card,row.Selected and CYAN or PINK,row.Selected and 1.3 or .8,true)
	local imageY=math.clamp(tonumber(read(config,"CarMenuVehicleImageYOffset",.13)),0,.3); if row.Image~="" then new("ImageLabel",{Name="Image",BackgroundTransparency=1,BorderSizePixel=0,Image=row.Image,ScaleType=Enum.ScaleType.Fit,Position=UDim2.new(.07,0,imageY,0),Size=UDim2.new(.86,0,.59,0),ZIndex=card.ZIndex+1},card) else label(card,"Fallback","HOVERCAR",UDim2.new(1,-6,.57,0),UDim2.new(0,3,imageY+.02,0),5,MUTED,Enum.TextXAlignment.Center) end
	local badge=label(card,"Badge",row.Tier.."  "..math.floor(row.Rating),UDim2.new(.46,0,0,12),UDim2.new(.52,0,0,3),5,WHITE,Enum.TextXAlignment.Center); badge.BackgroundColor3=tierColor(row.Tier); badge.BackgroundTransparency=.04; corner(badge,3)
	local name=label(card,"Name",row.Name,UDim2.new(1,-6,.21,0),UDim2.new(0,3,.75,0),5,WHITE,Enum.TextXAlignment.Center); name.TextWrapped=false; name.TextScaled=true; name.TextTruncate=Enum.TextTruncate.None; new("UITextSizeConstraint",{MinTextSize=4,MaxTextSize=6},name)
	card.Activated:Connect(function() if carBusy then return end; carBusy=true; showToast("SPAWNING VEHICLE...",true); local r=call("SpawnOwnedVehicleFromFreeRoam",{VehicleId=row.VehicleId,CockpitId=row.CockpitId}); if r.Success then profileCache=r.Profile or profileCache; lastProfile=0; fire("FreeRoamVehicleSpawned"); setCarMenuOpen(false); showToast("VEHICLE SPAWNED",true) else showToast(r.Message or r.Error or "SPAWN FAILED",false) end; carBusy=false end)
end
renderCars=function()
	for _,item in ipairs(carContent:GetChildren()) do if item~=carGrid then item:Destroy() end end
	local rows=vehicleRows(); local categoriesSet={ALL=true}; for _,row in ipairs(rows) do categoriesSet[row.Category]=true end
	local filtered={}; for _,row in ipairs(rows) do if selectedCategory=="ALL" or row.Category==selectedCategory then table.insert(filtered,row) end end
	table.sort(filtered,function(a,b) if selectedSort=="PRICE" and a.Price~=b.Price then return a.Price<b.Price elseif selectedSort=="A-Z" and a.Name~=b.Name then return a.Name<b.Name elseif selectedSort=="RATING" and a.Rating~=b.Rating then return a.Rating>b.Rating end return a.Name<b.Name end)
	local buy=button(carContent,"BuyMore","",UDim2.fromOffset(92,80),UDim2.fromOffset(0,0),PINK); buy.LayoutOrder=1; styleCarButton(buy,PINK,.8,true); label(buy,"Plus","+",UDim2.new(1,0,.54,0),UDim2.fromScale(0,.08),14,CYAN,Enum.TextXAlignment.Center); local buyName=label(buy,"Name","BUY MORE",UDim2.new(1,-6,.21,0),UDim2.new(0,3,.75,0),5,WHITE,Enum.TextXAlignment.Center); buyName.TextScaled=true; new("UITextSizeConstraint",{MinTextSize=4,MaxTextSize=6},buyName); buy.Activated:Connect(function() setCarMenuOpen(false); showTeleport() end)
	for i,row in ipairs(filtered) do makeCarCard(row,i+1) end
	local categoryOptions={}; for name in pairs(categoriesSet) do table.insert(categoryOptions,name) end; table.sort(categoryOptions,function(a,b) if a==b then return false elseif a=="ALL" then return true elseif b=="ALL" then return false end return a<b end); carCategory:SetAttribute("Options",table.concat(categoryOptions,"|")); local categoryValue=carCategory:FindFirstChild("Value"); local sortValue=carSort:FindFirstChild("Value"); if categoryValue then categoryValue.Text=selectedCategory end; if sortValue then sortValue.Text=selectedSort end
	task.defer(function() if carGrid.Parent then local topSafe=tonumber(read(config,"CarMenuCardTopSafePadding",3)); local bottomSafe=tonumber(read(config,"CarMenuCardBottomSafePadding",3)); local h=carGrid.AbsoluteContentSize.Y; carContent.Size=UDim2.new(1,0,0,h); carScroll.CanvasSize=UDim2.fromOffset(0,topSafe+h+bottomSafe) end end)
end

carDismiss.Activated:Connect(function() setCarMenuOpen(false) end)
carCategory.Activated:Connect(function() showCarChoices(carCategory,string.split(tostring(carCategory:GetAttribute("Options") or "ALL"),"|"),function(option) selectedCategory=option; renderCars() end) end)
carSort.Activated:Connect(function() showCarChoices(carSort,{"RATING","PRICE","A-Z"},function(option) selectedSort=option; renderCars() end) end)
carDespawn.Activated:Connect(function() if carBusy then return end; carBusy=true; fire("FreeRoamVehicleExited"); local r=call("DespawnVehicle",{}); setCarMenuOpen(false); showToast(r.Success==false and (r.Message or "DESPAWN FAILED") or "VEHICLE DESPAWNED",r.Success~=false); carBusy=false end)
carButton.Activated:Connect(function() setCarMenuOpen(true) end)
settingsButton.Activated:Connect(showSettings)
shopButton.Activated:Connect(showTeleport)
raceButton.Activated:Connect(function() if not fire("OpenRaceBrowser") then showToast("RACE BROWSER NOT READY",false) end end)
garageButton.Activated:Connect(function() if not interiorInvoke then showToast("GARAGE SERVICE NOT READY",false); return end; local ok,r=pcall(function() return interiorInvoke:InvokeServer("VisitGarage",{OwnerUserId=player.UserId}) end); showToast(ok and r and r.Ok and "ENTERED GARAGE" or "GARAGE ENTRY FAILED",ok and r and r.Ok==true) end)
exitButton.Activated:Connect(function() fire("FreeRoamVehicleExited"); local r=call("ExitVehicle",{}); showToast(r.Success==false and (r.Message or "EXIT FAILED") or "VEHICLE PARKED",r.Success~=false) end)

local presentationOwners={}
local presentation=uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
if presentation and presentation:IsA("BindableEvent") then presentation.Event:Connect(function(message) if typeof(message)=="table" then local owner=tostring(message.Owner or "Racing"); presentationOwners[owner]=message.Active==true and true or nil else presentationOwners.Racing=tostring(message)=="Racing" and true or nil end end) end
local function majorMenu() local g=playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI"); return g and g.Enabled end
local function subject() local c=player.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); local seat=h and h.SeatPart; return seat or (c and c:FindFirstChild("HumanoidRootPart")) end
local displayedPos=nil; local displayedHeading=0; local displayedBoost=1; local lastSize=Vector2.zero; local nextProfile=0
local function layout()
	local camera=workspace.CurrentCamera; local vp=camera and camera.ViewportSize or Vector2.new(1280,720); if vp==lastSize then return end; lastSize=vp
	local tiny=vp.Y<500; local margin=tiny and 10 or tonumber(read(config,"EdgeMargin",14)); local mapSize=math.floor(math.clamp(vp.Y*.27,tiny and 128 or 145,tiny and 160 or tonumber(read(config,"MinimapSize",180))))
	local navSize=tiny and 34 or tonumber(read(config,"NavButtonSize",42)); local navGap=tiny and 4 or tonumber(read(config,"NavGap",6)); local carWidth=navSize*2+navGap; local navWidth=carWidth+navSize*4+navGap*4; local mapX=vp.X-margin-mapSize; local clusterGap=tiny and 4 or tonumber(read(config,"TopClusterGap",6)); nav.Position=UDim2.fromOffset(mapX-clusterGap-navWidth,margin); nav.Size=UDim2.fromOffset(navWidth,navSize)
	local x=0; carButton.Position=UDim2.fromOffset(x,0); carButton.Size=UDim2.fromOffset(carWidth,navSize); x+=carWidth+navGap
	for _,name in ipairs({"Garage","Race","Dealership","Settings"}) do local b=navButtons[name]; b.Position=UDim2.fromOffset(x,0); b.Size=UDim2.fromOffset(navSize,navSize); x+=navSize+navGap end
	mapFrame.Position=UDim2.fromOffset(mapX,margin); mapFrame.Size=UDim2.fromOffset(mapSize,mapSize); cash.Position=UDim2.fromOffset(mapX,margin+mapSize+clusterGap); cash.Size=UDim2.fromOffset(mapSize,tiny and 30 or tonumber(read(config,"CashHeight",34)))
	local telemetryScaleValue=tiny and .62 or .72; local telemetryBottom=tonumber(read(config,"TelemetryBottomMargin",2)); telemetryScale.Scale=telemetryScaleValue; telemetry.Position=UDim2.fromOffset(vp.X*.5,vp.Y-telemetryBottom); local steeringBottomMargin=tiny and 10 or 16; local exitHeight=30; local exitY=math.floor(190+(telemetryBottom-steeringBottomMargin)/telemetryScaleValue-exitHeight+.5); exitButton.Position=UDim2.fromOffset(24,exitY)
	local carTop=tiny and 68 or tonumber(read(config,"CarMenuTop",82)); local carBottom=math.max(0,tonumber(read(config,"CarMenuBottomMargin",2))); local carH=math.max(260,vp.Y-carTop-carBottom); local panelPad=math.max(3,tonumber(read(config,"CarMenuPanelPadding",5))); local cardGap=math.max(2,tonumber(read(config,"CarMenuCardGap",5))); local topSafe=math.max(0,tonumber(read(config,"CarMenuCardTopSafePadding",3))); local bottomSafe=math.max(0,tonumber(read(config,"CarMenuCardBottomSafePadding",3))); local strokeSafe=math.max(0,tonumber(read(config,"CarMenuCardStrokeSafePadding",5))); local visibleRows=math.max(1,math.floor(tonumber(read(config,"CarMenuVisibleRows",3))+.5)); local aspect=math.max(.4,tonumber(read(config,"CarMenuCardAspect",.88))); local targetCardW=math.max(64,tonumber(read(config,"CarMenuTargetCardWidth",92))); local despawnH=math.max(18,tonumber(read(config,"CarMenuDespawnHeight",20))); local footerGap=math.max(2,tonumber(read(config,"CarMenuFooterGap",3))); local footerBottom=math.max(2,math.floor(panelPad*.5)); local scrollY=math.max(30,tonumber(read(config,"CarMenuHeaderHeight",36))); local despawnY=carH-footerBottom-despawnH; local scrollBottom=despawnY-footerGap; local scrollH=math.max(60,scrollBottom-scrollY)
	local heightFit=math.max(24,math.floor((scrollH-topSafe-bottomSafe-cardGap*(visibleRows-1))/visibleRows)); local maxPanelW=math.max(180,math.floor(vp.X*math.clamp(tonumber(read(config,"CarMenuMaxWidthRatio",.42)),.25,.6))); local viewportCardFit=math.floor((maxPanelW-panelPad*2-cardGap)/2); local cardW=math.max(64,math.min(targetCardW,viewportCardFit,math.floor(heightFit/aspect))); local cardH=math.max(24,math.floor(cardW*aspect)); local carW=panelPad*2+cardW*2+cardGap; local leftMargin=math.max(0,tonumber(read(config,"CarMenuLeftMargin",3))); carPanel.Position=UDim2.fromOffset(leftMargin,carTop); carPanel.Size=UDim2.fromOffset(carW,carH)
	local dropdownH=math.max(24,tonumber(read(config,"CarMenuDropdownHeight",28))); local fieldGap=math.max(3,cardGap-2); local fieldW=math.floor((carW-panelPad*2-fieldGap)/2); local dropdownY=4; carCategory.Position=UDim2.fromOffset(panelPad,dropdownY); carCategory.Size=UDim2.fromOffset(fieldW,dropdownH); carSort.Position=UDim2.fromOffset(panelPad+fieldW+fieldGap,dropdownY); carSort.Size=UDim2.fromOffset(fieldW,dropdownH)
	carScroll.Position=UDim2.fromOffset(panelPad-strokeSafe,scrollY); carScroll.Size=UDim2.fromOffset(carW-(panelPad-strokeSafe)*2,scrollH); carContent.Position=UDim2.fromOffset(0,topSafe); carContent.Size=UDim2.new(1,0,0,carContent.Size.Y.Offset); carGrid.HorizontalAlignment=Enum.HorizontalAlignment.Center; carGrid.CellPadding=UDim2.fromOffset(cardGap,cardGap); carGrid.CellSize=UDim2.fromOffset(cardW,cardH); carDespawn.Position=UDim2.fromOffset(panelPad,despawnY); carDespawn.Size=UDim2.new(1,-panelPad*2,0,despawnH)
	local modalW=math.floor(math.clamp(vp.X*.72,430,720)); local modalH=math.floor(math.clamp(vp.Y*.72,300,470)); modal.Size=UDim2.fromOffset(modalW,modalH)
end

RunService.RenderStepped:Connect(function(dt)
	suppressExactLegacyHud(); layout(); local hidden=next(presentationOwners)~=nil or majorMenu(); if hidden and carMenuOpen then setCarMenuOpen(false) end; gui.Enabled=not hidden; if hidden then return end
	local driving=drive.IsDriving==true; telemetry.Visible=driving and not carMenuOpen; exitButton.Visible=driving and not carMenuOpen
	local s=subject(); if s then local position=s.Position; local mapSize=mapFrame.AbsoluteSize.X; local mapPixels=math.max(1,tonumber(read(desktopLayout,"MapPixels",2048))); local calPixels=math.max(1,tonumber(read(desktopLayout,"MapCalibrationPixels",207))); local calStuds=math.max(1,tonumber(read(desktopLayout,"MapCalibrationStuds",2850))); local fullStuds=mapPixels*calStuds/calPixels; local visible=math.max(100,tonumber(read(desktopLayout,"MapVisibleStuds",2850))); local uiPerStud=mapSize/visible; local canvasSize=fullStuds*uiPerStud; mapCanvas.Size=UDim2.fromOffset(canvasSize,canvasSize); local dx=position.X-tonumber(read(desktopLayout,"MapWorldCenterX",0)); local dz=position.Z-tonumber(read(desktopLayout,"MapWorldCenterZ",0)); if B(desktopDefaults,"MapFlipX",false) then dx=-dx end; if B(desktopDefaults,"MapFlipZ",false) then dz=-dz end; local angle=math.rad(tonumber(read(desktopLayout,"MapCoordinateRotationDegrees",90))); local mx=dx*math.cos(angle)-dz*math.sin(angle); local mz=dx*math.sin(angle)+dz*math.cos(angle); local target=Vector2.new(mapSize*.5,mapSize*.5)-Vector2.new(mx*uiPerStud,mz*uiPerStud); displayedPos=displayedPos and displayedPos:Lerp(target,1-math.exp(-10*dt)) or target; mapCanvas.Position=UDim2.fromOffset(displayedPos.X,displayedPos.Y); mapCanvas.Rotation=0; local look=s.CFrame.LookVector; local lookX,lookZ=look.X,look.Z; if B(desktopDefaults,"MapFlipX",false) then lookX=-lookX end; if B(desktopDefaults,"MapFlipZ",false) then lookZ=-lookZ end; local lx=lookX*math.cos(angle)-lookZ*math.sin(angle); local lz=lookX*math.sin(angle)+lookZ*math.cos(angle); local heading=math.deg(math.atan2(lx,-lz))+tonumber(read(desktopLayout,"MapRotationOffsetDegrees",0)); local diff=(heading-displayedHeading+180)%360-180; displayedHeading+=diff*(1-math.exp(-10*dt)); playerMarker.Rotation=B(desktopDefaults,"MapPlayerIconRotates",true) and displayedHeading or 0 end
	if driving then local speed=math.max(0,tonumber(drive.SpeedMph) or 0); speedText.Text=tostring(math.floor(speed+.5)); local target=math.clamp((tonumber(drive.BoostPercent) or 100)/100,0,1); displayedBoost+=(target-displayedBoost)*(1-math.exp(-14*dt)); boostFill.Size=UDim2.fromScale(1,displayedBoost); local gaugeMax=math.max(1,tonumber(read(desktopLayout,"SpeedGaugeMaxMph",260)) or 260); local active=math.floor(math.clamp(speed/gaugeMax,0,1)*#gauge+.5); for i,g in ipairs(gauge) do g.BackgroundColor3=i<=active and (i>#gauge*.82 and PINK or CYAN) or Color3.fromRGB(81,88,99); g.BackgroundTransparency=i<=active and 0 or .42 end end
	if os.clock()>=nextProfile then nextProfile=os.clock()+3; task.defer(function() local p=profile(false); cashText.Text="$"..tostring(math.floor(tonumber(p.Cash) or 0)) end) end
end)
print("[NTR Mobile Free-Roam UI Phase 1K] Compact boost plate and steering-bottom-aligned Exit active.")
]====]

local NOOP_SOURCE = "-- " .. MARKER .. "\n-- Superseded by the canonical isolated mobile HUD/control owners.\nreturn"

mobileOwner.Source = CONTROLS_SOURCE
mobileOwner.Disabled = false
mobileOwner:SetAttribute("MobileControlsVersion", "ArrowsThumbstickTiltPhase1K")
mobileOwner:SetAttribute("LastUpdatedBy", MARKER)

local mobileHud = ui:FindFirstChild("MobileFreeRoamHudController_Active")
if mobileHud then assert(mobileHud:IsA("LocalScript"), mobileHud:GetFullName() .. " must be a LocalScript") else mobileHud = Instance.new("LocalScript"); mobileHud.Name = "MobileFreeRoamHudController_Active"; mobileHud.Parent = ui end
mobileHud.Source = HUD_SOURCE
mobileHud.Disabled = false
mobileHud:SetAttribute("MobileHudVersion", "Phase1KBoostPlateExitAlignment")
mobileHud:SetAttribute("LastUpdatedBy", MARKER)

-- Phase 16E left these as compatibility loaders. The canonical owners above now
-- own their responsibilities, so leave clear no-op sources instead of requiring
-- legacy modules that may no longer exist in the refreshed mirror.
driveHudOwner.Source = NOOP_SOURCE
navOwner.Source = NOOP_SOURCE
exitOwner.Source = NOOP_SOURCE
driveHudOwner.Disabled = false
navOwner.Disabled = false
exitOwner.Disabled = false

assert(string.find(mobileOwner.Source, MARKER, 1, true), "mobile controls marker missing after write")
assert(string.find(mobileHud.Source, MARKER, 1, true), "mobile HUD marker missing after write")
for _, expected in ipairs({ "HOVER_RACING_V2_DriveHUD", "CarMenuOutsideTap", "NTRMobileFreeRoamCarMenuOpen", "desktopEffects", "buttonGradient", "carNeutralSurface", "CarMenuTargetCardWidth", "CarMenuVisibleRows", "CarMenuPanelPadding", "CarMenuHeaderHeight", "CarMenuDropdownHeight", "CarMenuDespawnHeight", "CarMenuLeftMargin", "CarMenuVehicleImageYOffset", "CarMenuDespawnGradientTransparency", "panelPad*2+cardW*2+cardGap", "carChoiceAnchor==anchor", "UITextSizeConstraint", "TextScaled=true", "carPanelStroke:Destroy()", "carDespawnGradient=buttonGradient(carDespawn)", "cash.ClipsDescendants=true", "MinTextSize=5,MaxTextSize=14", "UDim2.fromOffset(92,80)" }) do
	assert(string.find(mobileHud.Source, expected, 1, true), "Phase 1K HUD smoke missing " .. expected)
end
for _, retired in ipairs({ "carTitle=label", '"FieldLabel"', "carPanelGlow=stroke", "styleCarButton(carDespawn" }) do
	assert(string.find(mobileHud.Source, retired, 1, true) == nil, "Phase 1K HUD still contains retired chrome " .. retired)
end
for _, expected in ipairs({ "vp.Y*.118", "ArrowWidthMultiplier", "arrowClusterW", "sourceAsset(desktopAssets,\"BoostIcon\")", "NTRMobileFreeRoamCarMenuOpen", "clearInputs()", "BoostPlate", "BoostPlateScale", "BoostPlateGradientRotation", "ColorSequence.new(BLUE,CYAN)", "BoostIconScale\",1.05" }) do
	assert(string.find(mobileOwner.Source, expected, 1, true), "Phase 1K controls smoke missing " .. expected)
end
for _, expected in ipairs({ "telemetryScaleValue", "steeringBottomMargin", "exitY=math.floor", "exitButton.Position=UDim2.fromOffset(24,exitY)" }) do assert(string.find(mobileHud.Source, expected, 1, true), "Phase 1K Exit alignment smoke missing " .. expected) end
assert(string.find(bootstrap.Source, MARKER, 1, true) == nil, "bootstrap was unexpectedly modified")

info("Installed canonical Phase 1K touch HUD, compact circular boost plate, steering-bottom-aligned Exit, and Arrows / Thumbstick / Tilt controls.")
info("The boost touch target stays 44/52px for usability; only the icon shrinks to 1.05x and sits on an 84% circular blue-to-cyan gradient plate.")
info("Exit now derives its Y position from telemetry scale and the steering cluster bottom margin, so their bottom edges align on tiny and standard landscape screens.")
info("The solver now reserves three complete card rows. Target cards are 92x80 and can shrink further on short landscape screens.")
info("Vehicle artwork now starts at 13% card height instead of 8%, while badges and names keep their approved positions.")
info("Despawn retains its background-only gradient overlay at 0.72 transparency, with no border or glow restored.")
info("Rating badges, names, fallback text, card strokes, and Buy More content scale with the smaller cards.")
info("Vehicle names self-fit on one line between 4px and 6px so BRUISER FORGE and PIERCER VIPER remain complete on phone screens.")
info("Cash now reserves the Plus-button area, scales from 14px down to 5px, and clips at the cash card boundary as a final overflow guard.")
info("MY VEHICLES and the CATEGORY / SORT field labels are removed; the shorter dropdowns now occupy the top row.")
info("The outer panel border/glow and Despawn border/glow are removed while their approved surface gradients remain.")
info("The panel width is derived from two 92px target cards, compact padding, and one gap.")
info("Tapping the currently open Category or Sort field now closes its choice list; tapping the other field switches lists.")
info("A transparent outside-tap layer leaves the top HUD visible but blocks its actions; driving controls clear and hide until the menu closes.")
info("Default is Arrows. Mobile Settings exposes the three modes at the top.")
info("Upload the four PNGs under assets/ui/icons/mobile_controls, then set the four StringValues under Config.UI.MobileFreeRoamHud.Assets.")
info("Play-test in Device Emulator and on a real gyroscope device, then refresh the Studio mirror.")
