-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Foundation=require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("ResponsiveUIFoundation"))
local event=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):FindFirstChild("ShowTopNotification") or Instance.new("BindableEvent")
event.Name="ShowTopNotification"
event.Parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")
local controller=Foundation.CreateTopNotificationController(playerGui)
event.Event:Connect(function(message,duration)
	controller.Show(message,duration)
end)

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
