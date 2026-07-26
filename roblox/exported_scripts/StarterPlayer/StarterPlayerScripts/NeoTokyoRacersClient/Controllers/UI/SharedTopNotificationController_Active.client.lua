-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local event=script.Parent:FindFirstChild("ShowTopNotification") or Instance.new("BindableEvent")
event.Name="ShowTopNotification"; event.Parent=script.Parent
local old=playerGui:FindFirstChild("NTR_SharedTopNotification")
if old then old:Destroy() end
local gui=Instance.new("ScreenGui"); gui.Name="NTR_SharedTopNotification"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=1100; gui.Parent=playerGui
local label=Instance.new("TextLabel"); label.Name="Message"; label.AnchorPoint=Vector2.new(.5,0); label.Position=UDim2.new(.5,0,0,18); label.Size=UDim2.new(1,-32,0,48); label.BackgroundColor3=Color3.fromRGB(9,12,16); label.BackgroundTransparency=.06; label.TextColor3=Color3.fromRGB(255,255,255); label.FontFace=Font.new("rbxasset://fonts/families/Michroma.json"); label.TextSize=14; label.TextWrapped=true; label.Visible=false; label.Parent=gui
local size=Instance.new("UISizeConstraint"); size.MaxSize=Vector2.new(620,48); size.MinSize=Vector2.new(260,48); size.Parent=label
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,5); corner.Parent=label
local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(236,92,168); stroke.Thickness=1; stroke.Parent=label
local serial=0
event.Event:Connect(function(message)
	serial+=1; local mine=serial
	label.Text=string.upper(tostring(message or "")); label.Visible=label.Text~=""
	task.delay(2.5,function() if mine==serial and label.Parent then label.Visible=false end end)
end)
