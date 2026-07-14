-- NTR_MOBILE_FREEROAM_UI_PHASE1N_SQUARE_PEDAL_LAYOUT
-- NTR_MOBILE_FREEROAM_UI_PHASE1M_CONTROL_SURFACE_OPACITY
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
local function visualKind(name)
	if name=="TurnLeft" or name=="TurnRight" or name=="DriftLeft" or name=="DriftRight" then return "Arrow" end
	if name=="Accelerator" or name=="Brake" then return "Pedal" end
	return "Default"
end
local function opacity(name,fallback) return math.clamp(tonumber(A(name,fallback)) or fallback,0,1) end
local function controlButton(name,imageName,fallback,rotation)
	local kind=visualKind(name); local cardOpacity=kind=="Arrow" and opacity("ArrowCardOpacity",.72) or kind=="Pedal" and opacity("PedalCardOpacity",0) or .88
	local b=new("TextButton",{Name=name,Text="",AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=1-cardOpacity,BorderSizePixel=0,ClipsDescendants=true,ZIndex=5},root); b:SetAttribute("NTRControlVisual",kind)
	corner(b,16); local s=nil
	if kind~="Arrow" and kind~="Pedal" then s=stroke(b,PINK,2,.05) end
	if kind=="Arrow" then new("UIGradient",{Name="CardGradient",Color=ColorSequence.new(SOFT,PANEL),Rotation=tonumber(A("ArrowCardGradientRotation",90)) or 90},b) end
	local image=asset(imageName); local imageOpacity=kind=="Arrow" and opacity("ArrowImageOpacity",.92) or kind=="Pedal" and opacity("PedalImageOpacity",.92) or 1
	if image~="" then new("ImageLabel",{Name="Art",BackgroundTransparency=1,BorderSizePixel=0,Image=image,ImageTransparency=1-imageOpacity,Rotation=rotation or 0,ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromScale(1,1),ZIndex=6},b)
	else local fallbackSize=(name=="Accelerator" or name=="Brake") and 10 or name=="Boost" and 9 or name:find("Drift") and 22 or 28; local t=label(b,"Fallback",fallback,UDim2.fromScale(1,1),UDim2.fromScale(0,0),fallbackSize,WHITE); t.TextWrapped=true; t.TextTransparency=1-imageOpacity; t.Rotation=rotation or 0 end
	allButtons[b]=s
	return b
end
local function pressed(b,on)
	local s=allButtons[b]
	if b.Name=="Boost" then b.BackgroundTransparency=1; if s then s.Transparency=1 end; return end
	local kind=tostring(b:GetAttribute("NTRControlVisual") or "Default")
	if kind=="Arrow" then
		local cardOpacity=math.clamp(opacity("ArrowCardOpacity",.72)+(on and opacity("ArrowPressedOpacityBoost",.12) or 0),0,1); b.BackgroundTransparency=1-cardOpacity
	elseif kind=="Pedal" then
		b.BackgroundTransparency=1-opacity("PedalCardOpacity",0)
	else
		b.BackgroundTransparency=on and 0 or .12; if s then s.Color=on and CYAN or PINK; s.Thickness=on and 3 or 2 end
	end
	local imageOpacity=kind=="Arrow" and opacity("ArrowImageOpacity",.92) or kind=="Pedal" and opacity("PedalImageOpacity",.92) or .92
	if on and (kind=="Arrow" or kind=="Pedal") then imageOpacity=math.clamp(imageOpacity+opacity("ControlPressedImageOpacityBoost",.08),0,1) end
	local art=b:FindFirstChild("Art"); if art then art.ImageTransparency=1-imageOpacity end
	local fallback=b:FindFirstChild("Fallback"); if fallback and (kind=="Arrow" or kind=="Pedal") then fallback.TextTransparency=1-imageOpacity end
end


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
	local pedalSize=math.max(44,math.floor(tonumber(A("PedalSize",104)) or 104)); local pedalBottom=math.max(0,math.floor(tonumber(A("PedalBottomOffset",10)) or 10)); local pedalRight=math.max(0,math.floor(tonumber(A("PedalRightOffset",10)) or 10)); local pedalGap=math.max(0,math.floor(tonumber(A("PedalGap",10)) or 10))
	accelerator.Position=UDim2.fromOffset(vp.X-pedalRight-pedalSize,vp.Y-pedalBottom-pedalSize); accelerator.Size=UDim2.fromOffset(pedalSize,pedalSize)
	brake.Position=UDim2.fromOffset(vp.X-pedalRight-pedalSize*2-pedalGap,vp.Y-pedalBottom-pedalSize); brake.Size=UDim2.fromOffset(pedalSize,pedalSize)
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
