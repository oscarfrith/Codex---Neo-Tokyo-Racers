-- Neo Tokyo Racers - Phase 7 Shared UI Helpers Promotion
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates final-named shared UI helper ModuleScripts and mirrors editable UI
--   theme values into the new NeoTokyoRacers config path.
--
-- Safe effects:
--   - Creates/updates ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI modules.
--   - Creates/updates ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI.Theme values.
--   - Adds references and migration notes.
--
-- Does NOT:
--   - Edit or require HOVER_RACING_V2_Client.
--   - Switch live UI behaviour.
--   - Touch driving, VFX, LOD, lighting, traffic, server actions, or assets.
--   - Touch Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_hierarchy_phase7_shared_ui_helpers_promote"

local function log(message)
	print("[NTR Phase7 UI Helpers] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No further changes applied.")
		end
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
end

local function objectValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("ObjectValue") then
		if item then
			item.Name = name .. "_OldNonObjectValue"
		end
		item = Instance.new("ObjectValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function stringValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("StringValue") then
		if item then
			item.Name = name .. "_OldNonStringValue"
		end
		item = Instance.new("StringValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function ensureValue(parent, className, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA(className) then
		if item then
			item.Name = name .. "_OldNon" .. className
		end
		item = Instance.new(className)
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function readColor(folderObject, name, fallback, alternate)
	local item = folderObject and (folderObject:FindFirstChild(name) or (alternate and folderObject:FindFirstChild(alternate)))
	if item and item:IsA("Color3Value") then
		return item.Value
	end
	return fallback
end

local function readNumber(folderObject, name, fallback)
	local item = folderObject and folderObject:FindFirstChild(name)
	if item and item:IsA("NumberValue") then
		return item.Value
	end
	return fallback
end

local function readString(folderObject, name, fallback)
	local item = folderObject and folderObject:FindFirstChild(name)
	if item and item:IsA("StringValue") then
		return item.Value
	end
	return fallback
end

local rsRoot = folder(ReplicatedStorage, "NeoTokyoRacers")
local shared = folder(rsRoot, "Shared")
local sharedModules = folder(shared, "Modules")
local sharedUI = folder(sharedModules, "UI")
local sharedConfig = folder(shared, "Config")
local uiConfig = folder(sharedConfig, "UI")
local themeConfig = folder(uiConfig, "Theme")
local references = folder(rsRoot, "LiveReferences")
local migration = folder(rsRoot, "MigrationNotes")

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
folder(controllers, "UI")

local uiRoot = child(StarterGui, "ScreenGui", "NeoTokyoRacersUI")
uiRoot.ResetOnSpawn = false
uiRoot.IgnoreGuiInset = true
uiRoot.Enabled = false
folder(uiRoot, "Components")
folder(uiRoot, "Screens")
folder(uiRoot, "Templates")

local kit = ReplicatedStorage:FindFirstChild("HOVER_RACING_V2_KIT")
local oldTheme = kit and kit:FindFirstChild("UI_THEME_DoNotRename")
if oldTheme then
	objectValue(references, "LiveUIThemeFolder", oldTheme)
end

local defaults = {
	Panel = Color3.fromRGB(5, 9, 7),
	PanelSoft = Color3.fromRGB(12, 20, 17),
	Card = Color3.fromRGB(24, 35, 42),
	Selected = Color3.fromRGB(36, 118, 82),
	Text = Color3.fromRGB(218, 255, 231),
	Muted = Color3.fromRGB(145, 178, 160),
	Accent = Color3.fromRGB(172, 255, 197),
	Cash = Color3.fromRGB(255, 193, 50),
	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),
	Disabled = Color3.fromRGB(62, 72, 73),
	PanelTransparency = 0.12,
	ButtonTransparency = 0.08,
	PanelStrokeTransparency = 0.2,
	ButtonStrokeTransparency = 0.62,
	StrokeWidth = 1,
	PanelCornerRadius = 5,
	ButtonCornerRadius = 4,
	FontFamily = "rbxasset://fonts/families/Michroma.json",
}

for _, name in ipairs({ "Panel", "PanelSoft", "Card", "Selected", "Text", "Muted", "Accent", "Cash", "Danger", "Buy", "Disabled" }) do
	ensureValue(themeConfig, "Color3Value", name, readColor(oldTheme, name, defaults[name], name == "Selected" and "CardHot" or nil))
end

for _, name in ipairs({ "PanelTransparency", "ButtonTransparency", "PanelStrokeTransparency", "ButtonStrokeTransparency", "StrokeWidth", "PanelCornerRadius", "ButtonCornerRadius" }) do
	ensureValue(themeConfig, "NumberValue", name, readNumber(oldTheme, name, defaults[name]))
end

ensureValue(themeConfig, "StringValue", "FontFamily", readString(oldTheme, "FontFamily", defaults.FontFamily))

local function writeModule(name, source)
	local module = sharedUI:FindFirstChild(name)
	if module and not module:IsA("ModuleScript") then
		error("Existing " .. module:GetFullName() .. " is not a ModuleScript. No module overwritten.")
	end
	if module and module.Source ~= "" and module:GetAttribute("CreatedBy") ~= SCRIPT_ID then
		log("Skipped existing manually-created module: " .. module:GetFullName())
		return module
	end
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Parent = sharedUI
	end
	module.Source = source
	module:SetAttribute("MigrationStatus", "PreparedForFutureUse")
	module:SetAttribute("CreatedBy", SCRIPT_ID)
	module:SetAttribute("DoNotSwitchLiveUIAutomatically", true)
	return module
end

local uiThemeSource = [=[
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = {}

UITheme.Default = {
	Panel = Color3.fromRGB(5, 9, 7),
	PanelSoft = Color3.fromRGB(12, 20, 17),
	Card = Color3.fromRGB(24, 35, 42),
	Selected = Color3.fromRGB(36, 118, 82),
	Text = Color3.fromRGB(218, 255, 231),
	Muted = Color3.fromRGB(145, 178, 160),
	Accent = Color3.fromRGB(172, 255, 197),
	Cash = Color3.fromRGB(255, 193, 50),
	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),
	Disabled = Color3.fromRGB(62, 72, 73),
	PanelTransparency = 0.12,
	ButtonTransparency = 0.08,
	PanelStrokeTransparency = 0.2,
	ButtonStrokeTransparency = 0.62,
	StrokeWidth = 1,
	PanelCornerRadius = 5,
	ButtonCornerRadius = 4,
	FontFamily = "rbxasset://fonts/families/Michroma.json",
}

local function findThemeFolder()
	local ntr = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local shared = ntr and ntr:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	local theme = ui and ui:FindFirstChild("Theme")
	if theme then
		return theme
	end

	local kit = ReplicatedStorage:FindFirstChild("HOVER_RACING_V2_KIT")
	return kit and kit:FindFirstChild("UI_THEME_DoNotRename")
end

local function color(folder, name, fallback, alternateName)
	local item = folder and (folder:FindFirstChild(name) or (alternateName and folder:FindFirstChild(alternateName)))
	if item and item:IsA("Color3Value") then
		return item.Value
	end
	return fallback
end

local function number(folder, name, fallback, minimum, maximum)
	local item = folder and folder:FindFirstChild(name)
	local value = item and item:IsA("NumberValue") and item.Value or fallback
	if minimum then value = math.max(minimum, value) end
	if maximum then value = math.min(maximum, value) end
	return value
end

local function text(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("StringValue") then
		return item.Value
	end
	return fallback
end

function UITheme.Read()
	local folder = findThemeFolder()
	local defaults = UITheme.Default
	return {
		Panel = color(folder, "Panel", defaults.Panel),
		PanelSoft = color(folder, "PanelSoft", defaults.PanelSoft),
		Card = color(folder, "Card", defaults.Card),
		Selected = color(folder, "Selected", defaults.Selected, "CardHot"),
		Text = color(folder, "Text", defaults.Text),
		Muted = color(folder, "Muted", defaults.Muted),
		Accent = color(folder, "Accent", defaults.Accent),
		Cash = color(folder, "Cash", defaults.Cash),
		Danger = color(folder, "Danger", defaults.Danger),
		Buy = color(folder, "Buy", defaults.Buy),
		Disabled = color(folder, "Disabled", defaults.Disabled),
		PanelTransparency = number(folder, "PanelTransparency", defaults.PanelTransparency, 0, 1),
		ButtonTransparency = number(folder, "ButtonTransparency", defaults.ButtonTransparency, 0, 1),
		PanelStrokeTransparency = number(folder, "PanelStrokeTransparency", defaults.PanelStrokeTransparency, 0, 1),
		ButtonStrokeTransparency = number(folder, "ButtonStrokeTransparency", defaults.ButtonStrokeTransparency, 0, 1),
		StrokeWidth = number(folder, "StrokeWidth", defaults.StrokeWidth, 0),
		PanelCornerRadius = number(folder, "PanelCornerRadius", defaults.PanelCornerRadius, 0),
		ButtonCornerRadius = number(folder, "ButtonCornerRadius", defaults.ButtonCornerRadius, 0),
		FontFamily = text(folder, "FontFamily", defaults.FontFamily),
	}
end

return UITheme
]=]

local uiPoolSource = [=[
local UIPool = {}
local Pool = {}
Pool.__index = Pool

function UIPool.new(container)
	return setmetatable({
		Container = container,
		Items = {},
		Connections = {},
		Active = 0,
	}, Pool)
end

function Pool:SetContainer(container)
	self.Container = container
end

function Pool:_disconnect(item)
	local list = self.Connections[item]
	if not list then return end
	for _, connection in ipairs(list) do
		if connection then connection:Disconnect() end
	end
	self.Connections[item] = nil
end

function Pool:Begin()
	self.Active = 0
	for _, item in ipairs(self.Items) do
		self:_disconnect(item)
		if item then
			item.Visible = false
			item.Parent = nil
		end
	end
end

function Pool:Acquire(factory)
	self.Active += 1
	local item = self.Items[self.Active]
	if not item then
		item = factory()
		self.Items[self.Active] = item
	end
	if item then
		item.Parent = self.Container
		item.Visible = true
		self:_disconnect(item)
	end
	return item
end

function Pool:Next(factory)
	return self:Acquire(factory)
end

function Pool:Connect(item, signal, callback)
	if not item or not signal or typeof(callback) ~= "function" then return nil end
	local connection = signal:Connect(callback)
	local list = self.Connections[item]
	if not list then
		list = {}
		self.Connections[item] = list
	end
	table.insert(list, connection)
	return connection
end

function Pool:End()
	for index = self.Active + 1, #self.Items do
		local item = self.Items[index]
		if item then
			self:_disconnect(item)
			item.Visible = false
			item.Parent = nil
		end
	end
end

function Pool:HideUnused()
	self:End()
end

function Pool:Destroy()
	for _, item in ipairs(self.Items) do
		self:_disconnect(item)
		if item then item:Destroy() end
	end
	table.clear(self.Items)
	table.clear(self.Connections)
	self.Active = 0
end

function Pool:Clear()
	self:Destroy()
end

return UIPool
]=]

local uiFactorySource = [=[
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local UIFactory = {}

function UIFactory.Font(theme)
	local ok, fontFace = pcall(function()
		return Font.new((theme and theme.FontFamily) or UITheme.Default.FontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
	return ok and fontFace or Font.fromEnum(Enum.Font.GothamBold)
end

function UIFactory.Corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 4)
	corner.Parent = parent
	return corner
end

function UIFactory.Stroke(parent, colour, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Transparency = transparency or 0
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

function UIFactory.Panel(parent, name, size, position, anchorPoint)
	local theme = UITheme.Read()
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = theme.Panel
	frame.BackgroundTransparency = theme.PanelTransparency
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchorPoint or Vector2.zero
	frame.Parent = parent

	UIFactory.Corner(frame, theme.PanelCornerRadius)
	UIFactory.Stroke(frame, theme.Accent, theme.PanelStrokeTransparency, theme.StrokeWidth)
	return frame
end

function UIFactory.Label(parent, text, size, position, textSize, align)
	local theme = UITheme.Read()
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = size
	label.Position = position or UDim2.fromScale(0, 0)
	label.FontFace = UIFactory.Font(theme)
	label.Text = text or ""
	label.TextColor3 = theme.Text
	label.TextSize = textSize or 12
	label.TextWrapped = true
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

function UIFactory.Button(parent, text, size, position, colour)
	local theme = UITheme.Read()
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = colour or theme.Card
	button.BackgroundTransparency = theme.ButtonTransparency
	button.BorderSizePixel = 0
	button.Size = size
	button.Position = position or UDim2.fromScale(0, 0)
	button.FontFace = UIFactory.Font(theme)
	button.Text = string.upper(text or "")
	button.TextColor3 = theme.Text
	button.TextSize = 11
	button.TextWrapped = true
	button.Parent = parent

	UIFactory.Corner(button, theme.ButtonCornerRadius)
	UIFactory.Stroke(button, theme.Accent, theme.ButtonStrokeTransparency, theme.StrokeWidth)
	return button
end

function UIFactory.ClearDynamic(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:GetAttribute("PooledDynamic") or child:GetAttribute("GeneratedUI") then
			child:Destroy()
		end
	end
end

return UIFactory
]=]

local responsiveLayoutSource = [=[
local ResponsiveLayout = {}

function ResponsiveLayout.ScaleForViewport(viewport, baseWidth, baseHeight, minScale, maxScale)
	baseWidth = baseWidth or 1600
	baseHeight = baseHeight or 900
	minScale = minScale or 0.68
	maxScale = maxScale or 1.02
	return math.clamp(math.min(viewport.X / baseWidth, viewport.Y / baseHeight), minScale, maxScale)
end

function ResponsiveLayout.BottomBands(viewport, scale, options)
	options = options or {}
	scale = math.max(scale or 1, 0.1)
	local vw = viewport.X / scale
	local vh = viewport.Y / scale
	local margin = options.Margin or 18
	local gap = options.Gap or 16
	local bottomHeight = options.BottomHeight or 108
	local leftWidth = options.LeftWidth or 190
	local rightWidth = options.RightWidth or 178

	local bottomY = vh - margin
	local left = {
		Size = UDim2.fromOffset(leftWidth, bottomHeight),
		Position = UDim2.fromOffset(margin, bottomY),
		AnchorPoint = Vector2.new(0, 1),
	}
	local right = {
		Size = UDim2.fromOffset(rightWidth, bottomHeight),
		Position = UDim2.fromOffset(vw - margin, bottomY),
		AnchorPoint = Vector2.new(1, 1),
	}
	local centerX = margin + leftWidth + gap
	local centerW = math.max(1, vw - margin - rightWidth - gap - centerX)
	local center = {
		Size = UDim2.fromOffset(centerW, bottomHeight),
		Position = UDim2.fromOffset(centerX, bottomY),
		AnchorPoint = Vector2.new(0, 1),
	}
	return left, center, right
end

return ResponsiveLayout
]=]

local colourUtilsSource = [=[
local ColourUtils = {}

function ColourUtils.ToHSV(color)
	local h, s, v = color:ToHSV()
	return h, s, v
end

function ColourUtils.FromHSV(h, s, v)
	return Color3.fromHSV(math.clamp(h or 0, 0, 1), math.clamp(s or 0, 0, 1), math.clamp(v or 0, 0, 1))
end

function ColourUtils.Sequence(color)
	return ColorSequence.new(color)
end

function ColourUtils.Lerp(a, b, alpha)
	return a:Lerp(b, math.clamp(alpha or 0, 0, 1))
end

return ColourUtils
]=]

local arrowScrollerSource = [=[
local RunService = game:GetService("RunService")
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local ArrowScroller = {}

function ArrowScroller.Attach(parent, scroller, axis, step)
	local theme = UITheme.Read()
	axis = axis or "X"
	step = step or 240

	local back = UIFactory.Button(parent, axis == "X" and "<" or "^", UDim2.fromOffset(24, 42), UDim2.fromScale(0, 0.5), theme.Panel)
	local forward = UIFactory.Button(parent, axis == "X" and ">" or "v", UDim2.fromOffset(24, 42), UDim2.fromScale(1, 0.5), theme.Panel)
	back.AnchorPoint = Vector2.new(0, 0.5)
	forward.AnchorPoint = Vector2.new(1, 0.5)
	back.ZIndex = (parent.ZIndex or 1) + 5
	forward.ZIndex = back.ZIndex

	local function maxCanvas()
		if axis == "X" then
			return math.max(0, scroller.AbsoluteCanvasSize.X - scroller.AbsoluteWindowSize.X)
		end
		return math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
	end

	local function update()
		local max = maxCanvas()
		local current = axis == "X" and scroller.CanvasPosition.X or scroller.CanvasPosition.Y
		back.Visible = current > 1
		forward.Visible = current < max - 1
	end

	local function scroll(direction)
		local current = scroller.CanvasPosition
		local max = maxCanvas()
		if axis == "X" then
			scroller.CanvasPosition = Vector2.new(math.clamp(current.X + direction * step, 0, max), current.Y)
		else
			scroller.CanvasPosition = Vector2.new(current.X, math.clamp(current.Y + direction * step, 0, max))
		end
		update()
	end

	local connections = {
		back.MouseButton1Click:Connect(function() scroll(-1) end),
		forward.MouseButton1Click:Connect(function() scroll(1) end),
		scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(update),
		scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update),
		scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(update),
		RunService.RenderStepped:Connect(update),
	}
	update()

	return {
		Back = back,
		Forward = forward,
		Destroy = function()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			back:Destroy()
			forward:Destroy()
		end,
	}
end

return ArrowScroller
]=]

local statBarsSource = [=[
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local StatBars = {}

function StatBars.Render(parent, stats, baseStats, order)
	local theme = UITheme.Read()
	order = order or { "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost" }
	local y = 0
	for _, name in ipairs(order) do
		local value = stats and stats[name] or 0
		local base = baseStats and baseStats[name]
		UIFactory.Label(parent, name, UDim2.new(0, 112, 0, 22), UDim2.fromOffset(0, y), 11)
		local back = Instance.new("Frame")
		back.Name = name .. "Bar"
		back.BorderSizePixel = 0
		back.BackgroundColor3 = Color3.fromRGB(45, 58, 56)
		back.Size = UDim2.new(1, -126, 0, 10)
		back.Position = UDim2.fromOffset(118, y + 6)
		back.Parent = parent
		UIFactory.Corner(back, 3)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = theme.Accent
		fill.Size = UDim2.fromScale(math.clamp(value / 160, 0, 1), 1)
		fill.Parent = back
		UIFactory.Corner(fill, 3)

		if typeof(base) == "number" and base ~= value then
			local delta = Instance.new("Frame")
			delta.Name = "PreviewDelta"
			delta.BorderSizePixel = 0
			delta.BackgroundColor3 = value > base and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(220, 70, 70)
			local baseScale = math.clamp(base / 160, 0, 1)
			local valueScale = math.clamp(value / 160, 0, 1)
			delta.Position = UDim2.fromScale(math.min(baseScale, valueScale), 0)
			delta.Size = UDim2.fromScale(math.abs(valueScale - baseScale), 1)
			delta.Parent = back
			UIFactory.Corner(delta, 3)
		end
		y += 25
	end
	return y
end

return StatBars
]=]

local modules = {
	UITheme = writeModule("UITheme", uiThemeSource),
	UIPool = writeModule("UIPool", uiPoolSource),
	UIFactory = writeModule("UIFactory", uiFactorySource),
	ResponsiveLayout = writeModule("ResponsiveLayout", responsiveLayoutSource),
	ColourUtils = writeModule("ColourUtils", colourUtilsSource),
	ArrowScroller = writeModule("ArrowScroller", arrowScrollerSource),
	StatBars = writeModule("StatBars", statBarsSource),
}

for name, module in pairs(modules) do
	objectValue(sharedUI, name .. "_Module", module)
	objectValue(references, "SharedUI_" .. name, module)
end

stringValue(uiConfig, "README_Phase7_UIConfig", table.concat({
	"Phase 7 promoted shared UI helper modules into final names.",
	"Theme values are mirrored here from HOVER_RACING_V2_KIT.UI_THEME_DoNotRename.",
	"The current live UI still uses the old HOVER_RACING_V2_Client and old theme folder.",
	"Phase 8 should switch one UI surface at a time to these helpers.",
}, "\n"))

stringValue(sharedUI, "README_Phase7_Modules", table.concat({
	"Prepared final shared UI modules for future UI extraction.",
	"These modules are not live until a client controller requires them.",
	"Do not delete UITheme_Shadow, UIPool_Shadow, or UIFactory_Shadow until Phase 8 confirms final modules are used.",
}, "\n"))

stringValue(migration, "06_Phase7_SharedUIHelpers", table.concat({
	"Phase 7 created final shared UI helper modules and mirrored UI theme config.",
	"No live UI behaviour was switched.",
	"Next: Phase 8 can extract dealership/colour/module/customisation UI in larger chunks.",
}, "\n"))

log("Promoted final shared UI helper modules.")
log("Mirrored editable UI theme config into NeoTokyoRacers.Shared.Config.UI.Theme.")
log("No live UI scripts or gameplay systems were changed.")
