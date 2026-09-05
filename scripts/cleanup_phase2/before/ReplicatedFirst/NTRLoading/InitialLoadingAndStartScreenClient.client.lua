-- NTR_LOADING_SYSTEM_PHASE5_INITIAL_START_SCREEN_V1_2_CONFIGURED_BUTTON_POSITION
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local packageFolder = script.Parent
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")

if config:GetAttribute("StartScreenEnabled") == false then
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	return
end

local clientRoot = playerScripts:WaitForChild("NeoTokyoRacersClient")
local uiFolder = clientRoot:WaitForChild("Controllers"):WaitForChild("UI")
local Runtime = require(packageFolder:WaitForChild("LoadingTransitionRuntime"))
local UI = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local api = Runtime.Start({ UIFolder = uiFolder })

local startedAt = os.clock()
local originalTimeout = config:GetAttribute("TimeoutSeconds")
local eligibility = {}
local artworkRoot = config:FindFirstChild("Artworks")
for _, artwork in ipairs(artworkRoot and artworkRoot:GetChildren() or {}) do
	if artwork:IsA("Folder") and artwork:GetAttribute("StartScreenEligible") ~= true then
		local enabled = artwork:GetAttribute("Enabled")
		eligibility[artwork] = { Had = enabled ~= nil, Value = enabled }
		artwork:SetAttribute("Enabled", false)
	end
end
config:SetAttribute("TimeoutSeconds", 86400)
local beginOk, generation = pcall(function()
	return api:Handle("Begin", { Destination = "StartScreen", Status = "LOADING NEO TOKYO", StartScreen = true })
end)
config:SetAttribute("TimeoutSeconds", originalTimeout)
for artwork, snapshot in pairs(eligibility) do
	if artwork and artwork.Parent then
		if snapshot.Had then artwork:SetAttribute("Enabled", snapshot.Value)
		else artwork:SetAttribute("Enabled", nil) end
	end
end
if not beginOk or not generation then
	warn("[NTR Loading System Phase 5] Initial loading could not begin; restoring Roblox loading ownership.")
	return
end

player:SetAttribute("NTR_StartScreenActive", true)
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function progress(value, status)
	api:Handle("Progress", { Generation = generation, Progress = value, Status = status })
end

progress(0.18, "LOADING WORLD")
local deadline = os.clock() + math.max(5, tonumber(config:GetAttribute("StartScreenLoadTimeoutSeconds")) or 20)
local loaded = game:IsLoaded()
local worldReady = Workspace:FindFirstChild("NeoTokyoRacersWorld") ~= nil
local characterReady = player.Character and player.Character:FindFirstChild("HumanoidRootPart") ~= nil
while os.clock() < deadline and not (loaded and worldReady and characterReady) do
	loaded = loaded or game:IsLoaded()
	worldReady = worldReady or Workspace:FindFirstChild("NeoTokyoRacersWorld") ~= nil
	characterReady = characterReady or (player.Character and player.Character:FindFirstChild("HumanoidRootPart") ~= nil)
	local elapsed = 1 - math.clamp((deadline - os.clock()) / math.max(5, tonumber(config:GetAttribute("StartScreenLoadTimeoutSeconds")) or 20), 0, 1)
	progress(0.18 + elapsed * 0.72, loaded and "PREPARING CITY" or "LOADING WORLD")
	task.wait(0.05)
end

if not (loaded and worldReady and characterReady) then
	warn(("[NTR Loading System Phase 5] Bounded initial readiness reached deadline loaded=%s world=%s character=%s"):format(tostring(loaded), tostring(worldReady), tostring(characterReady)))
end
progress(0.96, "FINALISING")

local safeGui = playerGui:WaitForChild("NTR_LoadingSafeContent", 5)
local safeRoot = safeGui and safeGui:FindFirstChild("SafeRoot")
if not safeRoot then
	warn("[NTR Loading System Phase 5] Loading safe content was unavailable; releasing to gameplay.")
	player:SetAttribute("NTR_StartScreenActive", false)
	api:Handle("Complete", { Generation = generation, Status = "READY" })
	return
end

local status = safeRoot:FindFirstChild("Status")
local track = safeRoot:FindFirstChild("ProgressTrack")
local minimum = math.max(0.1, tonumber(config:GetAttribute("MinimumVisibleSeconds")) or 1.5)
local completion = math.max(0.05, tonumber(config:GetAttribute("CompletionFillSeconds")) or 0.2)
local remaining = math.max(0, minimum - completion - (os.clock() - startedAt))
if remaining > 0 then task.wait(remaining) end
if status then status.Text = "READY" end
local completionOverlay = nil
if track then
	local fill = track:FindFirstChild("ProgressFill")
	if fill and fill:IsA("Frame") then
		local overlay = fill:Clone()
		overlay.Name = "StartScreenCompletionFill"
		overlay.Size = fill.Size
		overlay.ZIndex = fill.ZIndex + 1
		overlay.Parent = track
		completionOverlay = overlay
		local tween = TweenService:Create(overlay, TweenInfo.new(completion, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) })
		tween:Play()
		tween.Completed:Wait()
	end
end
task.wait(math.max(0, tonumber(config:GetAttribute("ReadyHoldSeconds")) or 0.06))
if status then status.Visible = false end
if track then track.Visible = false end

local menu = Instance.new("Frame")
menu.Name = "StartScreenActions"
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.BackgroundTransparency = 1
menu.BorderSizePixel = 0
menu.Position = UDim2.fromScale(0.5, 0.82)
menu.Size = UDim2.fromOffset(560, 52)
menu.ZIndex = 40
menu.Parent = safeRoot

local actions = Instance.new("Frame")
actions.Name = "Buttons"
actions.AnchorPoint = Vector2.new(0.5, 0.5)
actions.BackgroundTransparency = 1
actions.BorderSizePixel = 0
actions.Position = UDim2.fromScale(0.5, 0.5)
actions.Size = UDim2.fromOffset(560, 52)
actions.ZIndex = 41
actions.Parent = menu
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 16)
list.Parent = actions

local play = UI.Button(actions, {
	Name = "Play",
	Text = "",
	Size = UDim2.fromOffset(270, 52),
	Color = UI.Colour("PanelBlue"),
	StrokeColor = UI.Colour("Telemetry"),
	FocusColor = UI.Colour("Telemetry"),
	ZIndex = 43,
})
local shop = UI.Button(actions, {
	Name = "Shop",
	Text = "",
	Size = UDim2.fromOffset(270, 52),
	Color = UI.Colour("PanelSoft"),
	StrokeColor = UI.Colour("ElectricBlue"),
	FocusColor = UI.Colour("Telemetry"),
	ZIndex = 43,
})
play.LayoutOrder = 1
shop.LayoutOrder = 2
list.SortOrder = Enum.SortOrder.LayoutOrder

local playDefaultText = tostring(config:GetAttribute("StartScreenPlayText") or "PLAY")
local shopDefaultText = tostring(config:GetAttribute("StartScreenShopText") or "SHOP")

local function decorateButton(button, labelText, iconAssetId)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromOffset(0, 26)
	content.ZIndex = button.ZIndex + 2
	content.Parent = button

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = content

	local asset = UI.Asset(iconAssetId)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = asset
	icon.LayoutOrder = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(22, 22)
	icon.Visible = asset ~= ""
	icon.ZIndex = content.ZIndex
	icon.Parent = content

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, 26)
	label.Text = labelText
	label.TextColor3 = UI.Colour("Text")
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = content.ZIndex
	UI.Font(label, "Button")
	label.Parent = content
	return icon, label, contentLayout
end

-- Optional LoadingSystem String attributes; blank/absent IDs intentionally collapse icon space.
local playIcon, playLabel, playContentLayout = decorateButton(play, playDefaultText, config:GetAttribute("StartScreenPlayIconAssetId"))
local shopIcon, shopLabel, shopContentLayout = decorateButton(shop, shopDefaultText, config:GetAttribute("StartScreenShopIconAssetId"))

local function setButtonMetrics(width, height, iconSize, textSize)
	play.Size = UDim2.fromOffset(width, height)
	shop.Size = UDim2.fromOffset(width, height)
	playIcon.Size = UDim2.fromOffset(iconSize, iconSize)
	shopIcon.Size = UDim2.fromOffset(iconSize, iconSize)
	playLabel.TextSize = textSize
	shopLabel.TextSize = textSize
	local padding = iconSize <= 18 and 6 or 8
	playContentLayout.Padding = UDim.new(0, padding)
	shopContentLayout.Padding = UDim.new(0, padding)
end

local function positionMenu(attributeName, fallback, menuHeight)
	local requested = math.clamp(tonumber(config:GetAttribute(attributeName)) or fallback, 0.5, 0.95)
	local safeHeight = math.max(1, safeRoot.AbsoluteSize.Y)
	local maximum = math.max(0.5, 1 - ((menuHeight * 0.5 + 8) / safeHeight))
	menu.Position = UDim2.fromScale(0.5, math.min(requested, maximum))
end

local function updateLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local portrait = viewport.Y > viewport.X
	local phone = UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) <= 700
	if phone and portrait then
		menu.Size = UDim2.fromOffset(190, 90)
		actions.Size = UDim2.fromOffset(190, 90)
		list.FillDirection = Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, 10)
		setButtonMetrics(190, 40, 17, 12)
		positionMenu("StartScreenButtonYScalePortrait", 0.80, 90)
	elseif phone then
		menu.Size = UDim2.fromOffset(388, 40)
		actions.Size = UDim2.fromOffset(388, 40)
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 12)
		setButtonMetrics(188, 40, 17, 12)
		positionMenu("StartScreenButtonYScaleLandscapePhone", 0.84, 40)
	elseif viewport.X < 800 or portrait then
		menu.Size = UDim2.fromOffset(240, 108)
		actions.Size = UDim2.fromOffset(240, 108)
		list.FillDirection = Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, 12)
		setButtonMetrics(240, 48, 20, 13)
		positionMenu("StartScreenButtonYScalePortrait", 0.80, 108)
	else
		menu.Size = UDim2.fromOffset(560, 52)
		actions.Size = UDim2.fromOffset(560, 52)
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 16)
		setButtonMetrics(270, 52, 22, 14)
		positionMenu("StartScreenButtonYScaleDesktop", 0.82, 52)
	end
end
updateLayout()
local camera = Workspace.CurrentCamera
local layoutConnections = {}
if camera then table.insert(layoutConnections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)) end
table.insert(layoutConnections, safeRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
for _, attributeName in ipairs({ "StartScreenButtonYScaleDesktop", "StartScreenButtonYScaleLandscapePhone", "StartScreenButtonYScalePortrait" }) do
	table.insert(layoutConnections, config:GetAttributeChangedSignal(attributeName):Connect(updateLayout))
end

local busy = false
local function setBusy(active, target, text)
	busy = active == true
	play.Active = not busy
	shop.Active = not busy
	playLabel.Text = playDefaultText
	shopLabel.Text = shopDefaultText
	if target == "Play" and text then playLabel.Text = tostring(text)
	elseif target == "Shop" and text then shopLabel.Text = tostring(text) end
end

local function release(success, reason)
	for _, connection in ipairs(layoutConnections) do connection:Disconnect() end
	table.clear(layoutConnections)
	if menu then menu.Visible = false end
	player:SetAttribute("NTR_StartScreenActive", false)
	local action = success and "Complete" or "Fail"
	api:Handle(action, { Generation = generation, Status = success and "READY" or "RETURNING", Reason = reason })
	if status then status.Visible = true end
	if track then track.Visible = true end
	if completionOverlay then completionOverlay:Destroy(); completionOverlay = nil end
	if menu then menu:Destroy(); menu = nil end
end

play.Activated:Connect(function()
	if busy then return end
	setBusy(true, "Play", "ENTERING")
	release(true, "Play")
end)

shop.Activated:Connect(function()
	if busy then return end
	setBusy(true, "Shop", "TRAVELLING")
	local remote = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportInvoke")
	local ok, result = pcall(function() return remote:InvokeServer("TeleportToDealership") end)
	if ok and typeof(result) == "table" and result.Success == true then
		local exited = uiFolder:FindFirstChild("FreeRoamVehicleExited")
		if exited and exited:IsA("BindableEvent") then exited:Fire() end
		release(true, "Shop")
	else
		local reason = typeof(result) == "table" and (result.Message or result.Error) or tostring(result or "DEALERSHIP TELEPORT FAILED")
		warn("[NTR Loading System Phase 5] SHOP failed: " .. tostring(reason))
		setBusy(false, "Shop", "SHOP - TRY AGAIN")
	end
end)

print("[NTR Loading System Phase 5] Compact icon Play/Shop start screen ready.")
