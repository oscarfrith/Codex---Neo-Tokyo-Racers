-- NTR Persistence Phase 21 Private Garage Interior MVP client helper

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local garageRemotes = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local transition = garageRemotes:WaitForChild("GarageInteriorTransition")

local gui
local shade
local label

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_GarageInteriorTransition"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	label = Instance.new("TextLabel")
	label.Name = "LoadingLabel"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(420, 44)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 190, 240)
	label.TextScaled = true
	label.Text = "Loading"
	label.Parent = shade
end

local function fadeTo(transparency, duration)
	ensureGui()
	gui.Enabled = true
	local tween = TweenService:Create(shade, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = transparency,
	})
	tween:Play()
	tween.Completed:Wait()
	if transparency >= 1 then
		gui.Enabled = false
	end
end

transition.OnClientEvent:Connect(function(payload)
	payload = typeof(payload) == "table" and payload or {}
	local step = tostring(payload.Step or "")
	label = label or nil
	ensureGui()
	label.Text = tostring(payload.Label or "Loading")

	if step == "FadeOut" then
		fadeTo(0, 0.16)
	elseif step == "Stream" then
		local ok = true
		local streamError = ""
		if typeof(payload.Position) == "Vector3" then
			-- NTR_PERSISTENCE_PHASE22_STREAM_DIAGNOSTIC
			local success, err = pcall(function()
				Workspace:RequestStreamAroundAsync(payload.Position)
			end)
			ok = success == true
			if not success then
				streamError = tostring(err or "")
			end
		end
		player:SetAttribute("NTR_Phase21LastStreamOk", ok == true)
		player:SetAttribute("NTR_Phase21LastStreamError", streamError)
		task.wait(0.15)
		fadeTo(1, 0.22)
	else
		fadeTo(1, 0.16)
	end
end)

player:SetAttribute("NTR_Phase21GarageInteriorClientReady", true)
