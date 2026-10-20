-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
if not UserInputService.TouchEnabled then return end

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=game:GetService("ReplicatedStorage")
local config=game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("MobileFreeRoamHud")
local assets=game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("MobileFreeRoamHud"):WaitForChild("Assets")
local desktopAssets=game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud"):WaitForChild("Assets")
local M=require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("MobileDriveInputState"))

-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.TouchControlsClient: logic-identical fork of Vehicles.MobileDriveControlsClient. Requires: Layers, Tokens, FreeRoam.TouchControlsView, Core.ConnectionScope, Vehicles.MobileDriveInputState (kept line 20).
-- Replaced span 1 of 2 (Classic lines 22-103, the builders). It claims the surface, builds the look through TouchControlsView and gives the kept input, thumbstick, tilt and mode code the local names it reads. No input state is written in this span.
local pulse=script.Parent.Parent
local Layers=require(pulse.Kit.Layers)
Layers.Switch().Claim("TouchControls")
local Tokens=require(pulse.Kit.Tokens)
local TouchControlsView=require(script.Parent.TouchControlsView)
local scope=require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("ConnectionScope")).new()
local PINK=Tokens.Colour.Pink
local CYAN=Tokens.Colour.Cyan

local function A(name, fallback) local v=config:GetAttribute(name); if v==nil then return fallback end return v end

local layer=Layers.Create("MobileDriveControls_Phase1",{Frame="Bare"})
local view=TouchControlsView.Mount(layer,nil,scope)
-- Classic line 197 reads gui.Enabled and writes root.Visible. Under Pulse "the gui is enabled" is the layer root's Visible (API2 5.3); ScreenGui.Enabled is neither read nor written.
local gui=setmetatable({},{__index=function(_,key) if key=="Enabled" then return layer.Gui.Enabled and layer.Root.Visible end return layer.Gui[key] end})
local root=view.Root

local function visualKind(name)
	if name=="TurnLeft" or name=="TurnRight" or name=="DriftLeft" or name=="DriftRight" then return "Arrow" end
	if name=="Accelerator" or name=="Brake" then return "Pedal" end
	return "Default"
end
local function pressed(b,on) view.Pressed(b,on) end

local turnLeft=view.Buttons.TurnLeft
local turnRight=view.Buttons.TurnRight
local driftLeft=view.Buttons.DriftLeft
local driftRight=view.Buttons.DriftRight
local accelerator=view.Buttons.Accelerator
local brake=view.Buttons.Brake
local boost=view.Buttons.Boost
local tiltDrift=view.Buttons.TiltDrift
local tiltRecenter=view.Buttons.TiltRecenter
local thumbHit=view.ThumbHit
local thumbOuter=view.ThumbOuter
local thumbKnob=view.ThumbKnob
local outerStroke=view.OuterStroke
local tiltStatus=view.TiltStatus
-- The two instance attributes Classic sets on its controls (Classic 54 and 95), same names and values.
for name,b in pairs(view.Buttons) do b:SetAttribute("ControlVisual",visualKind(name)); b:SetAttribute("UIAudioSuppressClick",true) end
thumbHit:SetAttribute("UIAudioSuppressClick",true)

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
	local enter=tonumber(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):WaitForChild("MobileControls"):GetAttribute("DriftEnterThreshold")) or .95
	local exit=tonumber(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):WaitForChild("MobileControls"):GetAttribute("DriftExitThreshold")) or .88
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
	if tostring(player:GetAttribute("MobileControlMode") or "")~="Tilt" then return end
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
	if mode=="Tilt" and not UserInputService.GyroscopeEnabled then mode="Arrows"; player:SetAttribute("MobileControlMode","Arrows") end
	if mode==currentMode then return end; clearInputs(); currentMode=mode
	local arrow=mode=="Arrows"; turnLeft.Visible=arrow; turnRight.Visible=arrow; driftLeft.Visible=arrow; driftRight.Visible=arrow
	thumbHit.Visible=mode=="Thumbstick"; tiltDrift.Visible=mode=="Tilt"; tiltRecenter.Visible=mode=="Tilt"; tiltStatus.Visible=mode=="Tilt"
	if mode=="Tilt" then local _,cf=UserInputService:GetDeviceRotation(); local _,_,roll=cf:ToOrientation(); latestRoll=roll; calibrate() end
end
player:GetAttributeChangedSignal("MobileControlMode"):Connect(function() setMode(player:GetAttribute("MobileControlMode")) end)
if not player:GetAttribute("MobileControlMode") then player:SetAttribute("MobileControlMode",A("DefaultControlMode","Arrows")) end
setMode(player:GetAttribute("MobileControlMode"))

-- Pulse UI (phase2) fork: replaced span 2 of 2 (Classic lines 176-192, the layout). The kept render step calls layout() every frame (Classic 197); the view returns at once unless the size or scale changed, and the boost ring is written only when the whole percent changes.
local function layout() view.Layout(); view.SetBoostPercent(M.BoostPercent) end

local wasDriving=false
local wasMenuBlocked=false
RunService.RenderStepped:Connect(function(dt)
	layout(); local driving=M.IsDriving==true; local menuBlocked=player:GetAttribute("MobileFreeRoamCarMenuOpen")==true or player:GetAttribute("MobileMajorMenuOpen")==true or not gui.Enabled; root.Visible=driving and not menuBlocked
	if menuBlocked then if not wasMenuBlocked then clearInputs() end; wasMenuBlocked=true; return end; wasMenuBlocked=false
	if not driving then if wasDriving then clearInputs() end; wasDriving=false; return end; wasDriving=true
	if currentMode=="Tilt" then local smoothing=math.max(0,tonumber(A("TiltSmoothing",10)) or 10); local alpha=1-math.exp(-smoothing*dt); tiltCurrent+=(tiltTarget-tiltCurrent)*alpha; publishSteering(tiltCurrent,M.AnalogDrift==true) end
end)
print("[MobileDriveControlsClient] Compact boost plate and touch controls active.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
