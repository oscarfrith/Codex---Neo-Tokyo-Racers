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
