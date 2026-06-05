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

	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	return kit and kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Theme")
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
