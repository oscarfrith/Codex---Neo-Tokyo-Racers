-- NTR Persistence Phase 27 Garage Access UI MVP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local garageRemotes = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local interiorInvoke = garageRemotes:WaitForChild("GarageInteriorInvoke")

local THEME = {
	Panel = Color3.fromRGB(5, 9, 12),
	Card = Color3.fromRGB(24, 35, 42),
	CardHot = Color3.fromRGB(132, 25, 110),
	Buy = Color3.fromRGB(8, 145, 112),
	Back = Color3.fromRGB(24, 35, 42),
	Text = Color3.fromRGB(255, 210, 245),
	Muted = Color3.fromRGB(195, 150, 190),
	Good = Color3.fromRGB(120, 245, 160),
	Warn = Color3.fromRGB(255, 180, 105),
}

local gui
local toggleButton
local panel
local statusLabel
local summaryLabel
local userIdBox

local function readThemeColor(name, fallback, alternate)
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local themeFolder = kit and kit:FindFirstChild("Config") and kit.Config:FindFirstChild("UI") and kit.Config.UI:FindFirstChild("Theme")
	local item = themeFolder and (themeFolder:FindFirstChild(name) or (alternate and themeFolder:FindFirstChild(alternate)))
	if item and item:IsA("Color3Value") then
		return item.Value
	end
	return fallback
end

local function refreshTheme()
	THEME.Panel = readThemeColor("Panel", THEME.Panel)
	THEME.Card = readThemeColor("Card", THEME.Card)
	THEME.CardHot = readThemeColor("CardHot", THEME.CardHot)
	THEME.Buy = readThemeColor("Buy", THEME.Buy)
	THEME.Back = readThemeColor("Back", THEME.Back, "BackButton")
	THEME.Text = readThemeColor("Text", THEME.Text)
	THEME.Muted = readThemeColor("MutedText", THEME.Muted, "OwnedText")
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function stroke(parent, color)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.CardHot
	s.Thickness = 1
	s.Transparency = 0.15
	s.Parent = parent
	return s
end

local function setStatus(message, good)
	if not statusLabel then
		return
	end
	statusLabel.TextColor3 = good and THEME.Good or THEME.Warn
	statusLabel.Text = tostring(message or "")
end

local function callInterior(action, payload)
	local ok, result = pcall(function()
		return interiorInvoke:InvokeServer(action, payload or {})
	end)
	if not ok then
		return { Ok = false, Error = tostring(result) }
	end
	if type(result) ~= "table" then
		return { Ok = false, Error = "BadResult" }
	end
	return result
end

local function makeLabel(parent, name, text, size, position, fontSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.GothamBold
	label.TextSize = fontSize or 11
	label.TextColor3 = color or THEME.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, position, color, onClick)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or THEME.Card
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = UDim2.new(1, -20, 0, UserInputService.TouchEnabled and 38 or 34)
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextSize = 11
	button.TextColor3 = THEME.Text
	button.Parent = parent
	corner(button, 5)
	button.MouseButton1Click:Connect(function()
		local ok, err = pcall(onClick)
		if not ok then
			setStatus(err, false)
		end
	end)
	return button
end

local function updateSummary()
	if not summaryLabel then
		return
	end
	local inGarage = player:GetAttribute("NTR_Phase21InPrivateGarage") == true or tostring(player:GetAttribute("NTR_Phase21GarageInteriorId") or "") ~= ""
	local ownerUserId = tonumber(player:GetAttribute("NTR_Phase23VisitingGarageOwnerUserId")) or player.UserId
	local mode = tostring(player:GetAttribute("NTR_Phase23VisitAccessMode") or player:GetAttribute("NTR_Phase21GarageAccessMode") or "Private")
	summaryLabel.Text = (inGarage and "IN GARAGE" or "CITY") .. "  OWNER " .. tostring(ownerUserId) .. "  " .. string.upper(mode)
end

local function enterOwnGarage()
	local result = callInterior("VisitGarage", { OwnerUserId = player.UserId })
	if result.Ok then
		setStatus("ENTERED YOUR GARAGE", true)
	else
		setStatus("ENTER FAILED: " .. tostring(result.Error), false)
	end
	updateSummary()
end

local function setAccessMode(mode)
	local result = callInterior("SetAccessMode", { AccessMode = mode })
	if result.Ok then
		setStatus("ACCESS " .. tostring(result.AccessMode), true)
	else
		setStatus("ACCESS FAILED: " .. tostring(result.Error), false)
	end
	updateSummary()
end

local function visitTypedGarage()
	local typed = tonumber(userIdBox and userIdBox.Text)
	if not typed then
		setStatus("ENTER OWNER USER ID", false)
		return
	end
	local result = callInterior("VisitGarage", { OwnerUserId = typed })
	if result.Ok then
		setStatus("VISITING " .. tostring(result.OwnerUserId), true)
	else
		setStatus("VISIT FAILED: " .. tostring(result.Error), false)
	end
	updateSummary()
end

local function returnToCity()
	local result = callInterior("ReturnToCity", { Source = "GarageAccessUI" })
	if result.Ok then
		setStatus("RETURNED TO CITY", true)
	else
		setStatus("RETURN FAILED: " .. tostring(result.Error), false)
	end
	updateSummary()
end

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	refreshTheme()
	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_GarageAccessUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = true
	gui.Parent = player:WaitForChild("PlayerGui")

	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "GarageToggle"
	toggleButton.AnchorPoint = Vector2.new(1, 0)
	toggleButton.Position = UDim2.new(1, -16, 0, 78)
	toggleButton.Size = UDim2.fromOffset(116, 34)
	toggleButton.BackgroundColor3 = THEME.CardHot
	toggleButton.BackgroundTransparency = 0.05
	toggleButton.BorderSizePixel = 0
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Text = "GARAGE"
	toggleButton.TextSize = 11
	toggleButton.TextColor3 = THEME.Text
	toggleButton.Parent = gui
	corner(toggleButton, 5)
	stroke(toggleButton, THEME.CardHot)

	panel = Instance.new("Frame")
	panel.Name = "AccessPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 118)
	panel.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 246 or 224, 300)
	panel.BackgroundColor3 = THEME.Panel
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 7)
	stroke(panel, THEME.CardHot)

	makeLabel(panel, "Title", "GARAGE ACCESS", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 10), 13, THEME.Text)
	summaryLabel = makeLabel(panel, "Summary", "CITY  OWNER " .. tostring(player.UserId) .. "  PRIVATE", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 34), 10, THEME.Muted)

	makeButton(panel, "EnterMine", "ENTER MINE", UDim2.fromOffset(10, 72), THEME.Buy, enterOwnGarage)
	makeButton(panel, "SetPublic", "SET PUBLIC", UDim2.fromOffset(10, 112), THEME.CardHot, function()
		setAccessMode("Public")
	end)
	makeButton(panel, "SetPrivate", "SET PRIVATE", UDim2.fromOffset(10, 152), THEME.Back, function()
		setAccessMode("Private")
	end)

	userIdBox = Instance.new("TextBox")
	userIdBox.Name = "OwnerUserId"
	userIdBox.BackgroundColor3 = THEME.Card
	userIdBox.BackgroundTransparency = 0.08
	userIdBox.BorderSizePixel = 0
	userIdBox.ClearTextOnFocus = false
	userIdBox.Position = UDim2.fromOffset(10, 192)
	userIdBox.Size = UDim2.new(1, -20, 0, UserInputService.TouchEnabled and 38 or 34)
	userIdBox.Font = Enum.Font.GothamBold
	userIdBox.PlaceholderText = "OWNER USER ID"
	userIdBox.Text = tostring(player.UserId)
	userIdBox.TextSize = 11
	userIdBox.TextColor3 = THEME.Text
	userIdBox.PlaceholderColor3 = THEME.Muted
	userIdBox.Parent = panel
	corner(userIdBox, 5)

	makeButton(panel, "VisitUserId", "VISIT USER ID", UDim2.fromOffset(10, 232), THEME.Buy, visitTypedGarage)
	makeButton(panel, "ReturnCity", "RETURN CITY", UDim2.fromOffset(10, 260), THEME.Back, returnToCity)

	statusLabel = makeLabel(panel, "Status", "READY", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 1, -28), 10, THEME.Good)

	toggleButton.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		updateSummary()
	end)

	player:SetAttribute("NTR_Phase27GarageAccessUIReady", true)
	updateSummary()
end

ensureGui()

player:GetAttributeChangedSignal("NTR_Phase21InPrivateGarage"):Connect(updateSummary)
player:GetAttributeChangedSignal("NTR_Phase21GarageInteriorId"):Connect(updateSummary)
player:GetAttributeChangedSignal("NTR_Phase23VisitingGarageOwnerUserId"):Connect(updateSummary)
player:GetAttributeChangedSignal("NTR_Phase23VisitAccessMode"):Connect(updateSummary)
player:GetAttributeChangedSignal("NTR_Phase21GarageAccessMode"):Connect(updateSummary)

task.spawn(function()
	while true do
		task.wait(2)
		updateSummary()
	end
end)
