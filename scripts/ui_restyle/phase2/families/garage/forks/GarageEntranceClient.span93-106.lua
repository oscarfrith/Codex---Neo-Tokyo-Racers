local function flash(text)
	local notification=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime").UI:FindFirstChild("ShowTopNotification")
	if notification and notification:IsA("BindableEvent") then notification:Fire(text) end
end
