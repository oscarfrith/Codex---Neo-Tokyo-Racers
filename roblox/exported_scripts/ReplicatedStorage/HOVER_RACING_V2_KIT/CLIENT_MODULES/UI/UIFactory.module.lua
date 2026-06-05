local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("HOVER_RACING_V2_KIT"):WaitForChild("SHARED_MODULES"):WaitForChild("UITheme"))

local UIFactory = {}

function UIFactory.Font(theme)
	local ok, fontFace = pcall(function()
		return Font.new((theme and theme.FontFamily) or UITheme.Default.FontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
	return ok and fontFace or Font.fromEnum(Enum.Font.GothamBold)
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

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, theme.PanelCornerRadius)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Accent
	stroke.Transparency = theme.PanelStrokeTransparency
	stroke.Thickness = theme.StrokeWidth
	stroke.Parent = frame

	return frame
end

function UIFactory.Button(parent, text, size, position, color)
	local theme = UITheme.Read()
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or theme.Card
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

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, theme.ButtonCornerRadius)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Accent
	stroke.Transparency = theme.ButtonStrokeTransparency
	stroke.Thickness = theme.StrokeWidth
	stroke.Parent = button

	return button
end

return UIFactory
