-- NTR_STUDIO_CASH_GRANT_CLIENT_V1
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then return end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("StudioCashGrant")
local remote = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Debug"):WaitForChild("StudioCashGrantRequest")
local ACTION = "NTR_StudioCashGrant"

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 2.5 })
	end)
end

local function bind()
	ContextActionService:UnbindAction(ACTION)
	if config:GetAttribute("Enabled") ~= true then return end
	local keyName = tostring(config:GetAttribute("KeyCode") or "Equals")
	local keyCode = Enum.KeyCode[keyName]
	if not keyCode then
		warn("[NTR Studio Cash Grant] Invalid KeyCode config: " .. keyName)
		return
	end
	ContextActionService:BindAction(ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		remote:FireServer()
		return Enum.ContextActionResult.Sink
	end, false, keyCode)
	print("[NTR Studio Cash Grant] Press " .. keyName .. " for $" .. tostring(config:GetAttribute("Amount") or 100000) .. ".")
end

remote.OnClientEvent:Connect(function(result)
	result = typeof(result) == "table" and result or {}
	notify(result.Success == true and "TEST CASH ADDED" or "TEST CASH FAILED", tostring(result.Message or "No response"))
end)

config:GetAttributeChangedSignal("Enabled"):Connect(bind)
config:GetAttributeChangedSignal("KeyCode"):Connect(bind)
bind()
