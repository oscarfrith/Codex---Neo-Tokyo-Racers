-- Neo Tokyo Racers - Shared Racing UI Components
-- NTR_RACING_UI_PHASE1_SHARED_COMPONENTS

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = {}

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing")
local colours = config:WaitForChild("Colours")
local layout = config:WaitForChild("Layout")
local typography = config:WaitForChild("Typography")
local assets = config:WaitForChild("Assets")

local function read(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("ValueBase") then return item.Value end
	return fallback
end

function Components.Colour(name, fallback)
	return read(colours, name, fallback or Color3.new(1, 1, 1))
end

function Components.Layout(name, fallback)
	return read(layout, name, fallback or 0)
end

function Components.Type(name, fallback)
	return read(typography, name, fallback or 12)
end

function Components.AssetValue(name, fallback)
	return read(assets, name, fallback or "")
end

function Components.Asset(value)
	local text = tostring(value or "")
	if text == "" then return "" end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then return text end
	if tonumber(text) then return "rbxassetid://" .. text end
	return text
end

function Components.Font(object, role)
	local bold = role == "Heading" or role == "Button" or role == "Metric"
	object.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	local family = read(typography, "FontFamily", "rbxasset://fonts/families/Michroma.json")
	if family ~= "" then
		pcall(function()
			object.FontFace = Font.new(family, bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
		end)
	end
end

function Components.Corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Components.Layout("CornerRadius", 5))
	corner.Parent = parent
	return corner
end

function Components.Stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Components.Colour("Outline")
	stroke.Thickness = thickness or Components.Layout("StrokeWidth", 1.5)
	stroke.Transparency = transparency == nil and 0.18 or transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Components.Label(parent, properties)
	properties = properties or {}
	local item = Instance.new("TextLabel")
	item.Name = properties.Name or "Label"
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Position = properties.Position or UDim2.fromOffset(0, 0)
	item.Size = properties.Size or UDim2.fromScale(1, 1)
	item.Text = tostring(properties.Text or "")
	item.TextColor3 = properties.Color or Components.Colour("Text")
	item.TextSize = properties.TextSize or Components.Type("Body", 14)
	item.TextWrapped = properties.Wrapped == true
	item.TextTruncate = properties.Truncate or Enum.TextTruncate.AtEnd
	item.TextXAlignment = properties.XAlignment or Enum.TextXAlignment.Left
	item.TextYAlignment = properties.YAlignment or Enum.TextYAlignment.Center
	Components.Font(item, properties.Role or "Body")
	item.Parent = parent
	return item
end

function Components.Panel(parent, properties)
	properties = properties or {}
	local item = Instance.new("Frame")
	item.Name = properties.Name or "Panel"
	item.BorderSizePixel = 0
	item.BackgroundColor3 = properties.Color or Components.Colour("Panel")
	item.BackgroundTransparency = properties.Transparency == nil and Components.Layout("PanelTransparency", 0.08) or properties.Transparency
	item.Position = properties.Position or UDim2.fromOffset(0, 0)
	item.Size = properties.Size or UDim2.fromScale(1, 1)
	item.ClipsDescendants = properties.Clips == true
	item.Parent = parent
	Components.Corner(item, properties.Radius)
	if properties.NoStroke ~= true then
		local borderColor = properties.StrokeColor or Components.Colour("Outline")
		local stroke = Components.Stroke(item, borderColor, properties.StrokeWidth, properties.StrokeTransparency)
		stroke.Name = "Stroke"
		if properties.NoGlow ~= true then
			local glow = Components.Stroke(item, borderColor, properties.GlowWidth or 4, properties.GlowTransparency == nil and 0.82 or properties.GlowTransparency)
			glow.Name = "GlowStroke"
		end
	end
	return item
end

function Components.Button(parent, properties)
	properties = properties or {}
	local item = Instance.new("TextButton")
	item.Name = properties.Name or "Button"
	item.AutoButtonColor = false
	item.BorderSizePixel = 0
	item.BackgroundColor3 = properties.Color or Components.Colour("PanelSoft")
	item.BackgroundTransparency = properties.Transparency == nil and 0.08 or properties.Transparency
	item.Position = properties.Position or UDim2.fromOffset(0, 0)
	item.Size = properties.Size or UDim2.fromOffset(160, 48)
	item.Text = tostring(properties.Text or "")
	item.TextColor3 = properties.TextColor or Components.Colour("Text")
	item.TextSize = properties.TextSize or Components.Type("Button", 14)
	item.ZIndex = properties.ZIndex or parent.ZIndex + 2
	Components.Font(item, "Button")
	item.Parent = parent
	Components.Corner(item, properties.Radius)
	local overlay = Instance.new("Frame")
	overlay.Name = "GradientOverlay"
	overlay.Active = false
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = 0.9
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = item.ZIndex
	overlay.Parent = item
	Components.Corner(overlay, properties.Radius)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "NeutralOverlay"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 95, 95))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.52, 0.7),
		NumberSequenceKeypoint.new(1, 0.28),
	})
	gradient.Parent = overlay
	local normal = properties.StrokeColor or Components.Colour("Outline")
	local focus = properties.FocusColor or Components.Colour("Telemetry")
	local stroke = Components.Stroke(item, normal, properties.StrokeWidth, properties.StrokeTransparency)
	stroke.Name = "Stroke"
	local glow = Components.Stroke(item, normal, 4, 0.82)
	glow.Name = "GlowStroke"
	item.MouseEnter:Connect(function()
		if item.Active then
			item.BackgroundColor3 = properties.FocusFill or Components.Colour("PanelSoft")
			stroke.Color = focus
			glow.Color = focus
			stroke.Transparency = 0.02
			glow.Transparency = 0.7
		end
	end)
	item.MouseLeave:Connect(function()
		item.BackgroundColor3 = properties.Color or Components.Colour("PanelSoft")
		stroke.Color = normal
		glow.Color = normal
		stroke.Transparency = properties.StrokeTransparency == nil and 0.12 or properties.StrokeTransparency
		glow.Transparency = 0.82
	end)
	return item, stroke
end

-- NTR_RACING_UI_SHARED_RESPONSIVE_SCALE_V1
function Components.AttachResponsiveScale(shell)
	local scale = shell:FindFirstChild("ResponsiveScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "ResponsiveScale"
		scale.Parent = shell
	end
	local function resize()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local edgeX = math.max(48, viewport.X * Components.Layout("DesktopEdgeBufferXRatio", 0.10))
		local edgeY = math.max(48, viewport.Y * Components.Layout("DesktopEdgeBufferYRatio", 0.08))
		local fitX = (viewport.X - edgeX * 2) / Components.Layout("ShellWidth", 1200)
		local fitY = (viewport.Y - edgeY * 2) / Components.Layout("ShellHeight", 720)
		scale.Scale = math.clamp(math.min(fitX, fitY), Components.Layout("ResponsiveScaleMin", 0.55), Components.Layout("ScaleMax", 1.15))
	end
	resize()
	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	return scale
end

return Components
