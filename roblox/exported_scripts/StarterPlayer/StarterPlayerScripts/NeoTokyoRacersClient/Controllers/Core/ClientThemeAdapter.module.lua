-- Neo Tokyo Racers client theme adapter.
-- Phase A module. Reads Config.UI.Theme values into a plain theme table.

local ClientThemeAdapter = {}

ClientThemeAdapter.DefaultTheme = {
	Panel = Color3.fromRGB(5, 9, 7),
	PanelSoft = Color3.fromRGB(12, 20, 17),
	Card = Color3.fromRGB(24, 35, 42),
	CardHot = Color3.fromRGB(36, 118, 82),
	Text = Color3.fromRGB(218, 255, 231),
	Muted = Color3.fromRGB(145, 178, 160),
	Accent = Color3.fromRGB(172, 255, 197),
	Cash = Color3.fromRGB(255, 193, 50),
	Danger = Color3.fromRGB(175, 70, 68),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(175, 70, 68),
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

local function readThemeColor(themeFolder, name, fallback, alternateName)
	local item = themeFolder and (themeFolder:FindFirstChild(name) or (alternateName and themeFolder:FindFirstChild(alternateName)))
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local function readThemeNumber(themeFolder, name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function readThemeString(themeFolder, name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

function ClientThemeAdapter.Read(themeFolder)
	local default = ClientThemeAdapter.DefaultTheme
	return {
		Panel = readThemeColor(themeFolder, "Panel", default.Panel),
		PanelSoft = readThemeColor(themeFolder, "PanelSoft", default.PanelSoft),
		Card = readThemeColor(themeFolder, "Card", default.Card),
		CardHot = readThemeColor(themeFolder, "Selected", default.CardHot, "CardHot"),
		Text = readThemeColor(themeFolder, "Text", default.Text),
		Muted = readThemeColor(themeFolder, "Muted", default.Muted),
		Accent = readThemeColor(themeFolder, "Accent", default.Accent),
		Cash = readThemeColor(themeFolder, "Cash", default.Cash),
		Danger = readThemeColor(themeFolder, "Danger", default.Danger),
		Back = readThemeColor(themeFolder, "Back", default.Back, "BackButton"),
		Exit = readThemeColor(themeFolder, "Exit", default.Exit, "ExitButton"),
		Buy = readThemeColor(themeFolder, "Buy", default.Buy),
		Disabled = readThemeColor(themeFolder, "Disabled", default.Disabled),
		PanelTransparency = math.clamp(readThemeNumber(themeFolder, "PanelTransparency", default.PanelTransparency), 0, 1),
		ButtonTransparency = math.clamp(readThemeNumber(themeFolder, "ButtonTransparency", default.ButtonTransparency), 0, 1),
		PanelStrokeTransparency = math.clamp(readThemeNumber(themeFolder, "PanelStrokeTransparency", default.PanelStrokeTransparency), 0, 1),
		ButtonStrokeTransparency = math.clamp(readThemeNumber(themeFolder, "ButtonStrokeTransparency", default.ButtonStrokeTransparency), 0, 1),
		StrokeWidth = math.max(0, readThemeNumber(themeFolder, "StrokeWidth", default.StrokeWidth)),
		PanelCornerRadius = math.max(0, readThemeNumber(themeFolder, "PanelCornerRadius", default.PanelCornerRadius)),
		ButtonCornerRadius = math.max(0, readThemeNumber(themeFolder, "ButtonCornerRadius", default.ButtonCornerRadius)),
		FontFamily = readThemeString(themeFolder, "FontFamily", default.FontFamily),
	}
end

return ClientThemeAdapter
