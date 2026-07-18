-- NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP
-- NTR_RACING_FLOW_COUNTDOWN_VISUAL_V2
-- Shared responsive 5-to-GO countdown for Race and Time Trial.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local event=kit.Shared.Remotes.Racing:WaitForChild("RaceEvent")
local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents"))
local C=UI.Colour
local config=kit.Config.Racing:WaitForChild("FlowUI")
local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end
local old=playerGui:FindFirstChild("NTR_RaceCountdown") if old then old:Destroy() end
local gui=Instance.new("ScreenGui") gui.Name="NTR_RaceCountdown" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=205 gui.Parent=playerGui
local canvas=Instance.new("Frame") canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local function resize() local camera=Workspace.CurrentCamera local v=camera and camera.ViewportSize or Vector2.new(1920,1080) scale.Scale=math.min(v.X/1920,v.Y/1080) end resize() if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
local size=N("CountdownCardSize",260)
local card=Instance.new("Frame") card.Name="CountdownCard" card.AnchorPoint=Vector2.new(.5,.5) card.Position=UDim2.fromScale(.5,.5) card.Size=UDim2.fromOffset(size,size) card.BackgroundColor3=C("PanelDeep") card.BackgroundTransparency=N("CountdownCardTransparency",.18) card.BorderSizePixel=0 card.ClipsDescendants=true card.Visible=false card.Parent=canvas
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,18) corner.Parent=card
local gradient=Instance.new("UIGradient") gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C("PanelBlue")),ColorSequenceKeypoint.new(.52,C("PanelDeep")),ColorSequenceKeypoint.new(1,C("PanelSoft"))}) gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.52,.18),NumberSequenceKeypoint.new(1,.05)}) gradient.Rotation=N("CountdownGradientRotation",115) gradient.Parent=card
local heading=UI.Label(card,{Text="GET READY",Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,38),TextSize=18,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center})
local number=UI.Label(card,{Text="5",Position=UDim2.fromScale(0,0),Size=UDim2.fromScale(1,1),TextSize=N("CountdownTextSize",130),Color=C("Telemetry"),Role="Metric",XAlignment=Enum.TextXAlignment.Center}) number.TextXAlignment=Enum.TextXAlignment.Center number.TextYAlignment=Enum.TextYAlignment.Center
local token=0
local function hide() token+=1 card.Visible=false end
local function show(text,isGo) token+=1 local mine=token card.Visible=true heading.Text=isGo and "" or "GET READY" number.Text=text number.TextSize=isGo and N("GoTextSize",96) or N("CountdownTextSize",130) number.TextColor3=isGo and C("Telemetry") or C("Text") if isGo then task.delay(N("GoDuration",.85),function() if token==mine then card.Visible=false end end) end end
event.OnClientEvent:Connect(function(payload)
	if type(payload)~="table" then return end local kind=tostring(payload.Type or "")
	if kind=="TimeTrialStaged" or kind=="RaceStaged" then show(tostring(payload.Countdown or N("CountdownSeconds",5)),false)
	elseif kind=="TimeTrialCountdown" or kind=="RaceCountdown" then show(tostring(payload.Countdown or ""),false)
	elseif kind=="TimeTrialStarted" or kind=="RaceStarted" then show("GO!",true)
	elseif kind=="TimeTrialFinished" or kind=="TimeTrialEnded" or kind=="TimeTrialError" or kind=="RaceFinished" or kind=="RaceDNF" or kind=="RaceEnded" or kind=="RaceExitedToStart" then hide() end
end)
print("[NTR Unified Race Flow] Central countdown active.")
