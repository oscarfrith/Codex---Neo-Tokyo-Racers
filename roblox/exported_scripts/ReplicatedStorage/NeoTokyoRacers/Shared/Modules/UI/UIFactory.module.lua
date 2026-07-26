local UITheme = require(script.Parent:WaitForChild("UITheme"))
local Foundation = require(script.Parent:WaitForChild("ResponsiveUIFoundation"))

local UIFactory = {}

function UIFactory.Font(theme)
	local ok, fontFace = pcall(function()
		return Font.new((theme and theme.FontFamily) or UITheme.Default.FontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
	return ok and fontFace or Font.fromEnum(Enum.Font.GothamBold)
end

function UIFactory.Corner(parent, radius)
	return Foundation.Corner(parent, radius or 4)
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

-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
UIFactory.FormatMoney=Foundation.FormatCompactMoney
UIFactory.StyleMetric=Foundation.StyleMetric
UIFactory.StrokeWidth=Foundation.StrokeWidth
UIFactory.StyleStroke=Foundation.StyleStroke
UIFactory.ApplyBevel=Foundation.ApplyBevel

return UIFactory
