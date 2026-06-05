local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("HOVER_RACING_V2_KIT")
local ConfigReader = require(script.Parent:WaitForChild("ConfigReader"))

local UITheme = {}
UITheme.Folder = kit:WaitForChild("UI_THEME_DoNotRename")

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
	FontFamily = "rbxasset://fonts/families/Michroma.json",
}

function UITheme.Read()
	local folder = UITheme.Folder
	local defaults = UITheme.Default
	return {
		Panel = ConfigReader.Color(folder, "Panel", defaults.Panel),
		PanelSoft = ConfigReader.Color(folder, "PanelSoft", defaults.PanelSoft),
		Card = ConfigReader.Color(folder, "Card", defaults.Card),
		Selected = ConfigReader.Color(folder, "Selected", defaults.Selected),
		Text = ConfigReader.Color(folder, "Text", defaults.Text),
		Muted = ConfigReader.Color(folder, "Muted", defaults.Muted),
		Accent = ConfigReader.Color(folder, "Accent", defaults.Accent),
		Cash = ConfigReader.Color(folder, "Cash", defaults.Cash),
		Danger = ConfigReader.Color(folder, "Danger", defaults.Danger),
		Buy = ConfigReader.Color(folder, "Buy", defaults.Buy),
		Disabled = ConfigReader.Color(folder, "Disabled", defaults.Disabled),
		PanelTransparency = ConfigReader.Number(folder, "PanelTransparency", 0.12, 0, 1),
		ButtonTransparency = ConfigReader.Number(folder, "ButtonTransparency", 0.08, 0, 1),
		PanelStrokeTransparency = ConfigReader.Number(folder, "PanelStrokeTransparency", 0.2, 0, 1),
		ButtonStrokeTransparency = ConfigReader.Number(folder, "ButtonStrokeTransparency", 0.62, 0, 1),
		StrokeWidth = ConfigReader.Number(folder, "StrokeWidth", 1, 0),
		PanelCornerRadius = ConfigReader.Number(folder, "PanelCornerRadius", 5, 0),
		ButtonCornerRadius = ConfigReader.Number(folder, "ButtonCornerRadius", 4, 0),
		FontFamily = ConfigReader.String(folder, "FontFamily", defaults.FontFamily),
	}
end

return UITheme
