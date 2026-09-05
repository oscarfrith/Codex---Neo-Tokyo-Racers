-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("SharedTopNotificationController_Active")
-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Foundation=require(kit.Shared.Modules.UI:WaitForChild("ResponsiveUIFoundation"))
local event=script.Parent:FindFirstChild("ShowTopNotification") or Instance.new("BindableEvent")
event.Name="ShowTopNotification"
event.Parent=script.Parent
local controller=Foundation.CreateTopNotificationController(playerGui)
event.Event:Connect(function(message,duration)
	controller.Show(message,duration)
end)

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
