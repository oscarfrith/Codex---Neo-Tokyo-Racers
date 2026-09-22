-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then return end

local kit = game:GetService("ReplicatedStorage")
local config = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Development"):WaitForChild("CashGrant")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Debug"):WaitForChild("StudioCashGrantRequest")
local ACTION = "StudioCashGrant"

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
		warn("[Studio Cash Grant] Invalid KeyCode config: " .. keyName)
		return
	end
	ContextActionService:BindAction(ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		remote:FireServer()
		return Enum.ContextActionResult.Sink
	end, false, keyCode)
	print("[Studio Cash Grant] Press " .. keyName .. " for $" .. tostring(config:GetAttribute("Amount") or 100000) .. ".")
end

remote.OnClientEvent:Connect(function(result)
	result = typeof(result) == "table" and result or {}
	notify(result.Success == true and "TEST CASH ADDED" or "TEST CASH FAILED", tostring(result.Message or "No response"))
end)

config:GetAttributeChangedSignal("Enabled"):Connect(bind)
config:GetAttributeChangedSignal("KeyCode"):Connect(bind)
bind()

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
