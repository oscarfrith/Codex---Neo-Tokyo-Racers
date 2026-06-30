-- Neo Tokyo Racers - shared UI theme Back/Exit colours + intro objective theme bridge
-- Run this in Roblox Studio Command Bar.
--
-- This is a guarded source patch. It relies on exact snippets in the active
-- dealership bootstrap, intro client, and shared UI theme modules. If any
-- source has drifted, it aborts before saving partial script changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local LOG_PREFIX = "[NTR UI Theme]"

local function log(message)
	print(LOG_PREFIX .. " " .. message)
end

local function requireChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(child, LOG_PREFIX .. " Missing " .. parent:GetFullName() .. "." .. name)
	if className then
		assert(child:IsA(className), LOG_PREFIX .. " " .. child:GetFullName() .. " must be a " .. className .. ", got " .. child.ClassName)
	end
	return child
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder then
		assert(folder:IsA("Folder"), LOG_PREFIX .. " " .. folder:GetFullName() .. " must be a Folder")
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureColor(themeFolder, name, value)
	local item = themeFolder:FindFirstChild(name)
	if item then
		assert(item:IsA("Color3Value"), LOG_PREFIX .. " " .. item:GetFullName() .. " must be a Color3Value")
		return false
	end
	item = Instance.new("Color3Value")
	item.Name = name
	item.Value = value
	item.Parent = themeFolder
	return true
end

local function ensureString(parent, name, value)
	local item = parent:FindFirstChild(name)
	if item then
		assert(item:IsA("StringValue"), LOG_PREFIX .. " " .. item:GetFullName() .. " must be a StringValue")
		item.Value = value
		return false
	end
	item = Instance.new("StringValue")
	item.Name = name
	item.Value = value
	item.Parent = parent
	return true
end

local function replaceOnce(source, oldText, newText, label)
	if string.find(source, newText, 1, true) then
		return source, false
	end

	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, LOG_PREFIX .. " Could not find expected source block: " .. label)
	return source:sub(1, startIndex - 1) .. newText .. source:sub(endIndex + 1), true
end

local function patchModule(moduleScript, patches)
	local source = moduleScript.Source
	local changed = false
	for _, patch in ipairs(patches) do
		local patched
		source, patched = replaceOnce(source, patch.old, patch.new, moduleScript:GetFullName() .. " / " .. patch.label)
		changed = changed or patched
	end
	if changed then
		moduleScript.Source = source
	end
	return changed
end

local kit = requireChild(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = ensureFolder(kit, "Config")
local configUI = ensureFolder(config, "UI")
local liveTheme = ensureFolder(configUI, "Theme")

local shared = ensureFolder(kit, "Shared")
local sharedConfig = ensureFolder(shared, "Config")
local sharedConfigUI = ensureFolder(sharedConfig, "UI")
local sharedTheme = ensureFolder(sharedConfigUI, "Theme")

local backDefault = Color3.fromRGB(24, 35, 42)
local exitDefault = Color3.fromRGB(175, 70, 68)

for _, themeFolder in ipairs({ liveTheme, sharedTheme }) do
	ensureColor(themeFolder, "Back", backDefault)
	ensureColor(themeFolder, "Exit", exitDefault)
	ensureString(themeFolder.Parent, "README_BackExitColors", "Edit Theme.Back for Back buttons and Theme.Exit for Exit/close buttons. Intro objective UI reads the same theme values as the dealership UI.")
end

local modules = requireChild(shared, "Modules", "Folder")
local modulesUI = requireChild(modules, "UI", "Folder")
local sharedUITheme = requireChild(modulesUI, "UITheme", "ModuleScript")

patchModule(sharedUITheme, {
	{
		label = "prefer live theme folder",
		old = [[local function findThemeFolder()
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
end]],
		new = [[local function findThemeFolder()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local config = kit and kit:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	local liveTheme = ui and ui:FindFirstChild("Theme")
	if liveTheme then
		return liveTheme
	end

	local shared = kit and kit:FindFirstChild("Shared")
	local sharedConfig = shared and shared:FindFirstChild("Config")
	local sharedUI = sharedConfig and sharedConfig:FindFirstChild("UI")
	local sharedTheme = sharedUI and sharedUI:FindFirstChild("Theme")
	if sharedTheme then
		return sharedTheme
	end

	return kit and kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Theme")
end]],
	},
	{
		label = "default Back/Exit colours",
		old = [[	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
		new = [[	Danger = Color3.fromRGB(175, 70, 68),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
	},
	{
		label = "read Back/Exit colours",
		old = [[		Danger = color(folder, "Danger", defaults.Danger),
		Buy = color(folder, "Buy", defaults.Buy),]],
		new = [[		Danger = color(folder, "Danger", defaults.Danger),
		Back = color(folder, "Back", defaults.Back, "BackButton"),
		Exit = color(folder, "Exit", defaults.Exit, "ExitButton"),
		Buy = color(folder, "Buy", defaults.Buy),]],
	},
})

local commonModules = modules:FindFirstChild("Common")
local commonUITheme = commonModules and commonModules:FindFirstChild("UITheme")
if commonUITheme and commonUITheme:IsA("ModuleScript") then
	patchModule(commonUITheme, {
		{
			label = "common default Back/Exit colours",
			old = [[	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
			new = [[	Danger = Color3.fromRGB(175, 70, 68),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
		},
		{
			label = "common read Back/Exit colours",
			old = [[		Danger = ConfigReader.Color(folder, "Danger", defaults.Danger),
		Buy = ConfigReader.Color(folder, "Buy", defaults.Buy),]],
			new = [[		Danger = ConfigReader.Color(folder, "Danger", defaults.Danger),
		Back = ConfigReader.Color(folder, "Back", defaults.Back),
		Exit = ConfigReader.Color(folder, "Exit", defaults.Exit),
		Buy = ConfigReader.Color(folder, "Buy", defaults.Buy),]],
		},
	})
end

local starterPlayerScripts = requireChild(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = requireChild(starterPlayerScripts, "NeoTokyoRacersClient", "Folder")
local bootstrap = requireChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript")

patchModule(bootstrap, {
	{
		label = "bootstrap default Back/Exit colours",
		old = [[	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
		new = [[	Danger = Color3.fromRGB(175, 70, 68),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
	},
	{
		label = "bootstrap read Back/Exit colours",
		old = [[	Theme.Danger = readThemeColor("Danger", DefaultTheme.Danger)
	Theme.Buy = readThemeColor("Buy", DefaultTheme.Buy)]],
		new = [[	Theme.Danger = readThemeColor("Danger", DefaultTheme.Danger)
	Theme.Back = readThemeColor("Back", DefaultTheme.Back, "BackButton")
	Theme.Exit = readThemeColor("Exit", DefaultTheme.Exit, "ExitButton")
	Theme.Buy = readThemeColor("Buy", DefaultTheme.Buy)]],
	},
	{
		label = "driving exit button colour",
		old = [[	local exit = button(driveMenu, "Exit", UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), Theme.Danger)]],
		new = [[	local exit = button(driveMenu, "Exit", UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), Theme.Exit)]],
	},
	{
		label = "dealership back button colour",
		old = [[	UI.Back = button(UI.NextPanel, "Back", UDim2.new(1, -18, 0, 38), UDim2.fromOffset(9, 58), Theme.Card)]],
		new = [[	UI.Back = button(UI.NextPanel, "Back", UDim2.new(1, -18, 0, 38), UDim2.fromOffset(9, 58), Theme.Back)]],
	},
	{
		label = "dealership exit button colour",
		old = [[	UI.DealershipExitButton = button(UI.DealershipExitPanel, "Exit", UDim2.new(1, -18, 0, 42), UDim2.new(0, 9, 0.5, -21), Theme.Danger)]],
		new = [[	UI.DealershipExitButton = button(UI.DealershipExitPanel, "Exit", UDim2.new(1, -18, 0, 42), UDim2.new(0, 9, 0.5, -21), Theme.Exit)]],
	},
	{
		label = "cash shop close button colour",
		old = [[	local closeCash = button(UI.CashShop, "X", UDim2.fromOffset(34, 30), UDim2.new(1, -36, 0, 2), Theme.Danger)]],
		new = [[	local closeCash = button(UI.CashShop, "X", UDim2.fromOffset(34, 30), UDim2.new(1, -36, 0, 2), Theme.Exit)]],
	},
})

local controllers = requireChild(clientRoot, "Controllers", "Folder")
local coreControllers = controllers:FindFirstChild("Core")
local clientThemeAdapter = coreControllers and coreControllers:FindFirstChild("ClientThemeAdapter")
if clientThemeAdapter and clientThemeAdapter:IsA("ModuleScript") then
	patchModule(clientThemeAdapter, {
		{
			label = "adapter default Back/Exit colours",
			old = [[	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
			new = [[	Danger = Color3.fromRGB(175, 70, 68),
	Back = Color3.fromRGB(24, 35, 42),
	Exit = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),]],
		},
		{
			label = "adapter read Back/Exit colours",
			old = [[		Danger = readThemeColor(themeFolder, "Danger", default.Danger),
		Buy = readThemeColor(themeFolder, "Buy", default.Buy),]],
			new = [[		Danger = readThemeColor(themeFolder, "Danger", default.Danger),
		Back = readThemeColor(themeFolder, "Back", default.Back, "BackButton"),
		Exit = readThemeColor(themeFolder, "Exit", default.Exit, "ExitButton"),
		Buy = readThemeColor(themeFolder, "Buy", default.Buy),]],
		},
	})
end

local introFolder = requireChild(controllers, "Intro", "Folder")
local introClient = requireChild(introFolder, "DealershipIntroClient_Active", "LocalScript")

patchModule(introClient, {
	{
		label = "intro theme reader",
		old = [[local player = Players.LocalPlayer or Players.PlayerAdded:Wait()]],
		new = [[local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function readUITheme()
	local fallback = {
		Panel = Color3.fromRGB(5, 9, 7),
		Text = Color3.fromRGB(218, 255, 231),
		Accent = Color3.fromRGB(172, 255, 197),
		PanelTransparency = 0.12,
		PanelStrokeTransparency = 0.2,
		StrokeWidth = 1,
		PanelCornerRadius = 5,
		FontFamily = "rbxasset://fonts/families/Michroma.json",
	}

	local ok, theme = pcall(function()
		local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
		local module = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("UITheme")
		return require(module).Read()
	end)

	if ok and type(theme) == "table" then
		for key, value in pairs(fallback) do
			if theme[key] == nil then
				theme[key] = value
			end
		end
		return theme
	end

	return fallback
end]],
	},
	{
		label = "intro theme local",
		old = [[	if not config.ShowObjectiveText then
		return nil
	end

	local playerGui = player:WaitForChild("PlayerGui")]],
		new = [[	if not config.ShowObjectiveText then
		return nil
	end

	local theme = readUITheme()
	local playerGui = player:WaitForChild("PlayerGui")]],
	},
	{
		label = "intro panel background",
		old = [[	root.BackgroundColor3 = Color3.fromRGB(5, 9, 7)
	root.BackgroundTransparency = 0.18]],
		new = [[	root.BackgroundColor3 = theme.Panel
	root.BackgroundTransparency = theme.PanelTransparency]],
	},
	{
		label = "intro panel radius",
		old = [[	corner.CornerRadius = UDim.new(0, 6)]],
		new = [[	corner.CornerRadius = UDim.new(0, theme.PanelCornerRadius)]],
	},
	{
		label = "intro panel stroke",
		old = [[	stroke.Color = Color3.fromRGB(172, 255, 197)
	stroke.Thickness = 1
	stroke.Transparency = 0.28]],
		new = [[	stroke.Color = theme.Accent
	stroke.Thickness = theme.StrokeWidth
	stroke.Transparency = theme.PanelStrokeTransparency]],
	},
	{
		label = "intro objective font",
		old = [[	label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")]],
		new = [[	label.FontFace = Font.new(theme.FontFamily)]],
	},
	{
		label = "intro objective text colour",
		old = [[	label.TextColor3 = Color3.fromRGB(218, 255, 231)]],
		new = [[	label.TextColor3 = theme.Text]],
	},
})

log("Installed shared Back/Exit theme values and patched dealership/intro UI to use the shared theme.")
log("Tune colours at ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme.Back and .Exit. The mirrored Shared.Config.UI.Theme values were also added for shared UI modules.")
