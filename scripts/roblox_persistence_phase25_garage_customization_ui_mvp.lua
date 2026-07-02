-- NTR Persistence Phase 25 Garage Customization UI MVP
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Installs an isolated in-garage owner customization LocalScript.
--   It calls the Phase 24 GarageInteriorCustomizationInvoke remote and does
--   not patch the main dealership bootstrap.
--
-- Play mode, CLIENT Command Bar:
--   Smoke-checks self-visit, panel visibility, backend state, and return.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local TAG = "[NTR Persistence Phase 25 Garage Customization UI MVP]"

local function info(message)
	print(TAG .. " " .. tostring(message))
end

local function waitForPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current:WaitForChild(name)
	end
	return current
end

if RunService:IsRunning() then
	local player = Players.LocalPlayer
	assert(player, "Run this smoke from the CLIENT Command Bar during Play.")

	local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
	local garageInvoke = remotes:WaitForChild("GarageInvoke")
	local interiorInvoke = remotes:WaitForChild("GarageInteriorInvoke")
	local customizationInvoke = remotes:WaitForChild("GarageInteriorCustomizationInvoke")

	local initial = garageInvoke:InvokeServer("GetInitial", {})
	assert(type(initial) == "table" and initial.Profile ~= nil, "Garage GetInitial failed before Phase 25 smoke.")
	info("Garage GetInitial OK before UI smoke.")

	local setPublic = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Public" })
	assert(type(setPublic) == "table" and setPublic.Ok == true, "SetAccessMode Public failed: " .. tostring(setPublic and setPublic.Error))

	local visit = interiorInvoke:InvokeServer("VisitGarage", { OwnerUserId = player.UserId })
	assert(type(visit) == "table" and visit.Ok == true, "VisitGarage failed: " .. tostring(visit and visit.Error))
	info("VisitGarage OK. interior=" .. tostring(visit.InteriorId) .. " displayOk=" .. tostring(visit.DisplayOk))

	local gui = player:WaitForChild("PlayerGui"):WaitForChild("NTR_GarageInteriorCustomizationUI", 8)
	assert(gui and gui:IsA("ScreenGui"), "Garage customization UI did not appear in PlayerGui.")
	local panel = gui:WaitForChild("Panel", 4)
	local visibleDeadline = os.clock() + 8
	while panel and panel.Visible ~= true and os.clock() < visibleDeadline do
		task.wait(0.15)
	end
	assert(panel and panel.Visible == true, "Garage customization panel was not visible for the owner. inGarage=" .. tostring(player:GetAttribute("NTR_Phase21InPrivateGarage")) .. " visitingOwner=" .. tostring(player:GetAttribute("NTR_Phase23VisitingGarageOwnerUserId")) .. " localUserId=" .. tostring(player.UserId))
	assert(player:GetAttribute("NTR_Phase25GarageCustomizationUIReady") == true, "Phase 25 UI ready attribute was not set.")
	info("UI panel visible. screenGui=" .. gui.Name .. " panel=" .. panel.Name)

	local state = customizationInvoke:InvokeServer("GetCustomization", {})
	assert(type(state) == "table" and state.Ok == true, "GetCustomization failed: " .. tostring(state and state.Error))
	info("Customization backend OK. surfaces=" .. tostring(state.SurfaceCount) .. " decorations=" .. tostring(state.DecorationCount) .. " persisted=" .. tostring(state.Persisted))

	local returned = interiorInvoke:InvokeServer("ReturnToCity", { Smoke = true, Phase25 = true })
	assert(type(returned) == "table" and returned.Ok == true, "ReturnToCity failed: " .. tostring(returned and returned.Error))
	info("ReturnToCity OK. returnSource=" .. tostring(returned.ReturnSource))

	local setPrivate = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Private" })
	assert(type(setPrivate) == "table" and setPrivate.Ok == true, "SetAccessMode Private cleanup failed: " .. tostring(setPrivate and setPrivate.Error))
	info("Expected: owner-only in-garage customization panel appears and calls the Phase 24 backend without touching the dealership UI.")
	return
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " must be a " .. className)
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
assert(remotes:FindFirstChild("GarageInteriorCustomizationInvoke"), "Expected Phase 24 GarageInteriorCustomizationInvoke before Phase 25.")

local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = ensureChild(starterScripts, "Folder", "NeoTokyoRacersClient")
local controllers = ensureChild(clientRoot, "Folder", "Controllers")
local worldControllers = ensureChild(controllers, "Folder", "World")
local scriptObject = ensureChild(worldControllers, "LocalScript", "GarageInteriorCustomizationClient_Active")

scriptObject.Source = [=[-- NTR Persistence Phase 25 Garage Customization UI MVP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local garageRemotes = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local customizationInvoke = garageRemotes:WaitForChild("GarageInteriorCustomizationInvoke")

local THEME = {
	Panel = Color3.fromRGB(5, 9, 12),
	Card = Color3.fromRGB(24, 35, 42),
	CardHot = Color3.fromRGB(132, 25, 110),
	Buy = Color3.fromRGB(8, 145, 112),
	Text = Color3.fromRGB(255, 210, 245),
	Muted = Color3.fromRGB(195, 150, 190),
	Good = Color3.fromRGB(120, 245, 160),
	Warn = Color3.fromRGB(255, 180, 105),
}

local gui
local panel
local statusLabel
local summaryLabel

local surfacePresets = {
	{
		Text = "FLOOR GRAPHITE",
		Action = "SetSurfaceStyle",
		Payload = { SurfaceId = "Floor", Color = Color3.fromRGB(21, 28, 36), Material = "Metal" },
	},
	{
		Text = "FLOOR BLUE",
		Action = "SetSurfaceStyle",
		Payload = { SurfaceId = "Floor", Color = Color3.fromRGB(20, 44, 62), Material = "Metal" },
	},
	{
		Text = "WALLS SLATE",
		Action = "SetSurfaceStyle",
		Payload = { SurfaceId = "Walls", Color = Color3.fromRGB(30, 38, 52), Material = "Metal" },
	},
	{
		Text = "WALLS CONCRETE",
		Action = "SetSurfaceStyle",
		Payload = { SurfaceId = "Walls", Color = Color3.fromRGB(44, 48, 54), Material = "Concrete" },
	},
}

local decorPresets = {
	{
		Text = "NEON SIGN",
		Action = "SetDecorationAnchor",
		Payload = { AnchorId = "BackWallCenter", DecorationId = "NeonSign" },
	},
	{
		Text = "TOOL RACK",
		Action = "SetDecorationAnchor",
		Payload = { AnchorId = "LeftWallMid", DecorationId = "ToolRack" },
	},
	{
		Text = "STORAGE CRATE",
		Action = "SetDecorationAnchor",
		Payload = { AnchorId = "FrontRight", DecorationId = "StorageCrate" },
	},
	{
		Text = "CLEAR SIGN",
		Action = "SetDecorationAnchor",
		Payload = { AnchorId = "BackWallCenter", DecorationId = "None" },
	},
}

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

local function makeLabel(parent, name, text, size, position, fontSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.GothamBold
	label.TextSize = fontSize or 12
	label.TextColor3 = color or THEME.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

local function invokeCustomization(action, payload)
	local ok, result = pcall(function()
		return customizationInvoke:InvokeServer(action, payload or {})
	end)
	if not ok then
		return { Ok = false, Error = tostring(result) }
	end
	if type(result) ~= "table" then
		return { Ok = false, Error = "BadResult" }
	end
	return result
end

local function refreshSummary()
	if not summaryLabel then
		return
	end
	local result = invokeCustomization("GetCustomization", {})
	if result.Ok then
		summaryLabel.Text = "SURFACES " .. tostring(result.SurfaceCount or 0) .. "  DECOR " .. tostring(result.DecorationCount or 0)
	else
		summaryLabel.Text = "CUSTOMIZATION UNAVAILABLE"
	end
end

local function setStatus(message, good)
	if not statusLabel then
		return
	end
	statusLabel.TextColor3 = good and THEME.Good or THEME.Warn
	statusLabel.Text = tostring(message or "")
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

local function runPreset(preset)
	local result = invokeCustomization(preset.Action, preset.Payload)
	if result.Ok then
		setStatus(preset.Text .. " OK", true)
	else
		setStatus(preset.Text .. " FAILED: " .. tostring(result.Error), false)
	end
	refreshSummary()
end

local function ensureGui()
	if gui and gui.Parent then
		return
	end
	refreshTheme()

	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_GarageInteriorCustomizationUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = true
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 246 or 224, 386)
	panel.BackgroundColor3 = THEME.Panel
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 7)
	stroke(panel, THEME.CardHot)

	makeLabel(panel, "Title", "GARAGE CUSTOMISE", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 10), 13, THEME.Text)
	summaryLabel = makeLabel(panel, "Summary", "SURFACES 0  DECOR 0", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 34), 10, THEME.Muted)
	makeLabel(panel, "SurfacesTitle", "SURFACES", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 62), 10, THEME.Muted)

	local y = 84
	for index, preset in ipairs(surfacePresets) do
		makeButton(panel, "Surface" .. tostring(index), preset.Text, UDim2.fromOffset(10, y), THEME.Card, function()
			runPreset(preset)
		end)
		y += UserInputService.TouchEnabled and 42 or 38
	end

	makeLabel(panel, "DecorTitle", "DECOR", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, y + 5), 10, THEME.Muted)
	y += 27
	for index, preset in ipairs(decorPresets) do
		makeButton(panel, "Decor" .. tostring(index), preset.Text, UDim2.fromOffset(10, y), index == 1 and THEME.Buy or THEME.Card, function()
			runPreset(preset)
		end)
		y += UserInputService.TouchEnabled and 42 or 38
	end

	statusLabel = makeLabel(panel, "Status", "ENTER YOUR GARAGE TO CUSTOMISE", UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 1, -34), 10, THEME.Muted)
	player:SetAttribute("NTR_Phase25GarageCustomizationUIReady", true)
end

local function updateVisibility()
	ensureGui()
	local inGarage = player:GetAttribute("NTR_Phase21InPrivateGarage") == true or tostring(player:GetAttribute("NTR_Phase21GarageInteriorId") or "") ~= ""
	local ownerUserId = tonumber(player:GetAttribute("NTR_Phase23VisitingGarageOwnerUserId")) or player.UserId
	local show = inGarage and ownerUserId == player.UserId
	panel.Visible = show
	if show then
		refreshSummary()
		setStatus("READY", true)
	end
end

ensureGui()
updateVisibility()

player:GetAttributeChangedSignal("NTR_Phase21InPrivateGarage"):Connect(updateVisibility)
player:GetAttributeChangedSignal("NTR_Phase23VisitingGarageOwnerUserId"):Connect(updateVisibility)

task.spawn(function()
	for _ = 1, 40 do
		task.wait(0.15)
		updateVisibility()
	end
	while true do
		task.wait(2)
		updateVisibility()
		if panel and panel.Visible then
			refreshSummary()
		end
	end
end)
]=]

scriptObject.Disabled = false
scriptObject:SetAttribute("PersistencePhase25GarageCustomizationUIMVP", true)

info("PASS: installed isolated GarageInteriorCustomizationClient_Active. Restart Play, then run this same script from the CLIENT Command Bar for the smoke test.")
