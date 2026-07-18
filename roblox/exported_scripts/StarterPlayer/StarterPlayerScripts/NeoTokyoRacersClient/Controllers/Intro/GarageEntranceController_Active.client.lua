-- Neo Tokyo Racers - canonical native garage entrance owner
-- NTR_GARAGE_NATIVE_ENTRANCE_PROMPTS_V1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local request = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("GarageSessionRequest")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageExperience")

local function colour(name, fallback)
	local value = config:FindFirstChild(name)
	return value and value:IsA("Color3Value") and value.Value or fallback
end

local function number(name, fallback)
	local value = config:FindFirstChild(name)
	return value and value:IsA("NumberValue") and value.Value or fallback
end

local function entranceDefinitions()
	local dealership = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("Dealership")
	local intro = dealership:WaitForChild("Intro")
	local customisation = dealership:WaitForChild("Customisation")
	return {
		{
			Mode = "Dealership",
			Part = intro:WaitForChild("Desk"):WaitForChild("GarageDeskTrigger"),
			Event = "OpenGarageFromIntro",
			ObjectText = "Dealership",
		},
		{
			Mode = "Customisation",
			Part = customisation:WaitForChild("CustomisationDeskTrigger"),
			Event = "OpenOwnedCockpitCustomisation",
			ObjectText = "Customisation",
		},
		{
			Mode = "DriveIn",
			Part = customisation:WaitForChild("DriveInCustomisationTrigger"),
			Event = "OpenDrivingVehicleCustomisation",
			ObjectText = "Customisation",
		},
	}
end

local function drivingOwnVehicle()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat then return false end
	local vehicle = seat:FindFirstAncestorOfClass("Model")
	return vehicle ~= nil and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId
end

local oldStatusGui = player:WaitForChild("PlayerGui"):FindFirstChild("NTR_GarageEntranceStatus")
if oldStatusGui then oldStatusGui:Destroy() end

-- The native prompt owns all normal input presentation. This small UI is only
-- used for actionable errors after a trigger has been activated.
local statusGui = Instance.new("ScreenGui")
statusGui.Name = "NTR_GarageEntranceStatus"
statusGui.ResetOnSpawn = false
statusGui.IgnoreGuiInset = true
statusGui.DisplayOrder = 90
statusGui.Parent = player.PlayerGui

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.new(0.5, 0, 1, -28)
status.Size = UDim2.fromOffset(420, 42)
status.BackgroundColor3 = colour("PanelDeep", Color3.fromRGB(9, 12, 16))
status.BackgroundTransparency = 0.08
status.TextColor3 = colour("Text", Color3.new(1, 1, 1))
status.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
status.TextSize = 13
status.Visible = false
status.Parent = statusGui
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 4)
local statusStroke = Instance.new("UIStroke", status)
statusStroke.Color = colour("Structure", Color3.fromRGB(236, 92, 168))
statusStroke.Thickness = 1

local statusSerial = 0
local function flash(text)
	statusSerial += 1
	local serial = statusSerial
	status.Text = text
	status.Visible = true
	task.delay(2, function()
		if statusSerial == serial then status.Visible = false end
	end)
end

local entries = {}
local busy = false

local function garageIsActive()
	return player:GetAttribute("NTR_GarageEntryMode") ~= nil
end

local function refreshPromptAvailability()
	local active = garageIsActive()
	for _, entry in ipairs(entries) do
		local enabled = not active
		if entry.Definition.Mode == "DriveIn" then
			enabled = enabled and drivingOwnVehicle()
		end
		entry.Prompt.Enabled = enabled
	end
end

for _, definition in ipairs(entranceDefinitions()) do
	assert(definition.Part:IsA("BasePart"), definition.Part:GetFullName() .. " must be a BasePart")

	-- Retire both the old custom prompt and any duplicate from an interrupted
	-- client session before creating this controller's single native owner.
	local previous = definition.Part:FindFirstChild("NTRCanonical" .. definition.Mode)
	if previous then previous:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NTRCanonical" .. definition.Mode
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.ActionText = "Enter"
	prompt.ObjectText = definition.ObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = number("PromptDistance", 14)
	prompt.RequiresLineOfSight = false
	prompt.Parent = definition.Part

	table.insert(entries, { Definition = definition, Prompt = prompt })

	prompt.Triggered:Connect(function()
		if busy or garageIsActive() then return end
		if definition.Mode == "DriveIn" and not drivingOwnVehicle() then
			flash("Drive your owned vehicle into the bay first.")
			refreshPromptAvailability()
			return
		end

		busy = true
		local ok, result = pcall(function()
			return request:InvokeServer("Begin", { Mode = definition.Mode })
		end)
		if not ok or not result or result.Success ~= true then
			busy = false
			flash((result and result.Message) or "Could not enter garage.")
			refreshPromptAvailability()
			return
		end

		player:SetAttribute("NTR_GarageEntryMode", definition.Mode)
		refreshPromptAvailability()
		local event = script.Parent:FindFirstChild(definition.Event) or script.Parent:WaitForChild(definition.Event, 5)
		if event and event:IsA("BindableEvent") then
			event:Fire()
		else
			request:InvokeServer("End", { ReturnToEntry = true })
			player:SetAttribute("NTR_GarageEntryMode", nil)
			flash("Garage UI handoff is unavailable.")
		end
		busy = false
		refreshPromptAvailability()
	end)
end

player:GetAttributeChangedSignal("NTR_GarageEntryMode"):Connect(refreshPromptAvailability)
player.CharacterAdded:Connect(function()
	task.defer(refreshPromptAvailability)
end)

refreshPromptAvailability()

-- Drive-in eligibility can change without an attribute signal when the local
-- humanoid sits or stands, so only that prompt receives this low-frequency sync.
task.spawn(function()
	while script.Parent do
		task.wait(0.25)
		refreshPromptAvailability()
	end
end)
