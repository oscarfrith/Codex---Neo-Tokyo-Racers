-- Neo Tokyo Racers - Vehicle Phase AO module upgrade UI
-- Run in Edit mode from the Roblox Studio Command Bar.
--
-- Fragile patch warning:
-- This script uses guarded exact source replacement against the refreshed
-- Phase AN client bootstrap. It performs exactly one Script.Source write.
-- Do not weaken an exact-match assertion if the live source has changed.

local StarterPlayer = game:GetService("StarterPlayer")

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local source = bootstrap.Source
local marker = "-- NTR_VEHICLE_PHASE_AO_MODULE_UPGRADE_UI"
if string.find(source, marker, 1, true) then
	print("[NTR Vehicle Phase AO] Module upgrade UI is already installed.")
	return
end

local replacements = {}

local function queueReplace(labelText, oldText, newText)
	local firstStart, firstEnd = string.find(source, oldText, 1, true)
	assert(firstStart, labelText .. " expected exactly 1 match, found 0")
	assert(
		not string.find(source, oldText, firstEnd + 1, true),
		labelText .. " expected exactly 1 match, found more than 1"
	)
	table.insert(replacements, {
		Label = labelText,
		Old = oldText,
		New = newText,
	})
end

local helperAnchor = [[local function renderStatsOnly(parent, stats, baseStats)
]]

local helperBlock = [[-- NTR_VEHICLE_PHASE_AO_MODULE_UPGRADE_UI
NTRVehiclePhaseAO = {}

function NTRVehiclePhaseAO.performanceModules()
	if NTRVehiclePhaseAO.Calculator then
		return NTRVehiclePhaseAO.Definitions, NTRVehiclePhaseAO.Calculator
	end
	local performance = kit
		:WaitForChild("Shared")
		:WaitForChild("Modules")
		:WaitForChild("Common")
		:WaitForChild("Performance")
	NTRVehiclePhaseAO.Definitions = require(performance:WaitForChild("VehiclePerformanceDefinitions"))
	NTRVehiclePhaseAO.Calculator = require(performance:WaitForChild("VehiclePerformanceCalculator"))
	return NTRVehiclePhaseAO.Definitions, NTRVehiclePhaseAO.Calculator
end

function NTRVehiclePhaseAO.installedModule()
	local slotId = State.CustomizeTarget
	local installed = State.Profile and State.Profile.InstalledModules
	local moduleId = installed and installed[slotId]
	return slotId, moduleId, moduleId and getModule(moduleId)
end

function NTRVehiclePhaseAO.moduleLevel(moduleId, upgradeId)
	local allLevels = State.Profile and State.Profile.ModuleUpgradeLevels
	local moduleLevels = allLevels and allLevels[moduleId]
	return math.max(0, math.floor(tonumber(moduleLevels and moduleLevels[upgradeId]) or 0))
end

function NTRVehiclePhaseAO.upgradeForId(module, upgradeId)
	for _, upgrade in ipairs((module and module.Upgrades) or {}) do
		if upgrade.UpgradeId == upgradeId then
			return upgrade
		end
	end
end

function NTRVehiclePhaseAO.previewPerformance(basePerformance, module, upgradeId)
	if not (basePerformance and basePerformance.Raw and module and upgradeId) then
		return basePerformance
	end
	local upgrade = NTRVehiclePhaseAO.upgradeForId(module, upgradeId)
	if not upgrade then return basePerformance end
	local _, Calculator = NTRVehiclePhaseAO.performanceModules()
	local raw = Calculator.CloneRaw(basePerformance.Raw)
	Calculator.AddRaw(raw, upgrade.EffectsPerLevel or {}, 1)
	return Calculator.Calculate(raw)
end

function NTRVehiclePhaseAO.tierColor(tier)
	return ({
		E = Color3.fromRGB(132, 142, 145),
		D = Color3.fromRGB(105, 190, 129),
		C = Color3.fromRGB(74, 204, 211),
		B = Color3.fromRGB(82, 137, 235),
		A = Color3.fromRGB(244, 188, 65),
		S = Color3.fromRGB(236, 92, 168),
	})[tier] or Theme.Accent
end

function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)
	label(parent, name, UDim2.new(0.43, 0, 0, 18), UDim2.fromOffset(0, y), 9, Enum.TextXAlignment.Left)
	local bar = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(39, 48, 49),
		BorderSizePixel = 0,
		Size = UDim2.new(0.54, 0, 0, 10),
		Position = UDim2.new(0.45, 0, 0, y + 4),
	}, parent)
	corner(bar, 3)
	local amount = math.clamp((tonumber(value) or 0) / 100, 0, 1)
	local baseAmount = math.clamp((tonumber(baseValue) or tonumber(value) or 0) / 100, 0, 1)
	local fill = new("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.min(amount, baseAmount), 1),
	}, bar)
	corner(fill, 3)
	if amount > baseAmount + 0.002 then
		local delta = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(84, 255, 126),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(baseAmount, 0),
			Size = UDim2.fromScale(amount - baseAmount, 1),
		}, bar)
		corner(delta, 3)
	elseif amount < baseAmount - 0.002 then
		local delta = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(230, 64, 74),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(amount, 0),
			Size = UDim2.fromScale(baseAmount - amount, 1),
		}, bar)
		corner(delta, 3)
	else
		fill.Size = UDim2.fromScale(amount, 1)
	end
	label(bar, tostring(math.floor((tonumber(value) or 0) + 0.5)), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 8, Enum.TextXAlignment.Center)
end

function NTRVehiclePhaseAO.formatRaw(variableName, value)
	local Definitions = NTRVehiclePhaseAO.performanceModules()
	local definition = Definitions.GetNormalization(variableName)
	local places = tonumber(definition.DecimalPlaces) or 0
	local formatted = places > 0 and string.format("%." .. tostring(places) .. "f", value or 0)
		or tostring(math.floor((value or 0) + 0.5))
	local unit = tostring(definition.Unit or "")
	return formatted .. (unit ~= "" and (" " .. unit) or "")
end

function NTRVehiclePhaseAO.contextRows(module)
	local Definitions = NTRVehiclePhaseAO.performanceModules()
	local rawSet = {}
	for _, upgrade in ipairs((module and module.Upgrades) or {}) do
		for variableName in pairs(upgrade.EffectsPerLevel or {}) do
			rawSet[variableName] = true
		end
	end
	local rawRows = {}
	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		if rawSet[variableName] then
			table.insert(rawRows, variableName)
		end
	end
	local headlineScores = {}
	for _, headlineName in ipairs(Definitions.HeadlineOrder) do
		local score = 0
		for variableName, weight in pairs(Definitions.GetHeadlineWeights(headlineName)) do
			if rawSet[variableName] and typeof(weight) == "number" then
				score += weight
			end
		end
		if score > 0 then
			table.insert(headlineScores, { Name = headlineName, Score = score })
		end
	end
	table.sort(headlineScores, function(a, b)
		if a.Score == b.Score then return a.Name < b.Name end
		return a.Score > b.Score
	end)
	return headlineScores, rawRows
end

function NTRVehiclePhaseAO.renderStats(parent, legacyStats)
	clear(parent)
	local _, Calculator = NTRVehiclePhaseAO.performanceModules()
	local basePerformance = State.Profile and State.Profile.Performance
	if State.Stage == "CockpitShop" or not (basePerformance and basePerformance.Overall) then
		basePerformance = Calculator.CalculateLegacy(legacyStats or {})
	end
	local _, _, module = NTRVehiclePhaseAO.installedModule()
	local preview = NTRVehiclePhaseAO.previewPerformance(basePerformance, module, State.PreviewUpgradeId)
	local overall = preview and preview.Overall or {}
	local baseOverall = basePerformance and basePerformance.Overall or overall
	local tier = tostring(overall.Tier or baseOverall.Tier or "E")
	local index = math.floor(tonumber(overall.PerformanceIndex or baseOverall.PerformanceIndex) or 100)

	local header = new("Frame", {
		BackgroundColor3 = NTRVehiclePhaseAO.tierColor(tier),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 42),
	}, parent)
	corner(header, 4)
	label(header, tier, UDim2.fromOffset(46, 42), UDim2.fromOffset(4, 0), 25, Enum.TextXAlignment.Center)
	label(header, tostring(index), UDim2.fromOffset(72, 42), UDim2.fromOffset(48, 0), 17, Enum.TextXAlignment.Left)
	label(header, "PERFORMANCE", UDim2.new(1, -124, 1, 0), UDim2.fromOffset(120, 0), 8, Enum.TextXAlignment.Right)

	local contextual = State.Stage == "Customise"
		and State.CustomizeTarget ~= "ALL"
		and State.CustomizeTarget ~= "Cockpit"
		and State.CustomizeTarget ~= "THRUST_COLOR"
		and module ~= nil
	local y = 49
	if contextual then
		local headlineRows, rawRows = NTRVehiclePhaseAO.contextRows(module)
		for indexRow = 1, math.min(2, #headlineRows) do
			local headlineName = headlineRows[indexRow].Name
			NTRVehiclePhaseAO.drawBar(
				parent,
				headlineName,
				preview.Headline[headlineName],
				basePerformance.Headline[headlineName],
				y
			)
			y += 24
		end
		local Definitions = NTRVehiclePhaseAO.performanceModules()
		for indexRow = 1, math.min(5, #rawRows) do
			local variableName = rawRows[indexRow]
			local definition = Definitions.GetNormalization(variableName)
			local currentValue = preview.Raw[variableName] or 0
			local baseValue = basePerformance.Raw[variableName] or currentValue
			local text = NTRVehiclePhaseAO.formatRaw(variableName, currentValue)
			if math.abs(currentValue - baseValue) > 0.0001 then
				text = NTRVehiclePhaseAO.formatRaw(variableName, baseValue) .. " > " .. text
			end
			label(parent, definition.DisplayName or variableName, UDim2.new(0.55, 0, 0, 18), UDim2.fromOffset(0, y), 8, Enum.TextXAlignment.Left)
			local valueLabel = label(parent, text, UDim2.new(0.45, 0, 0, 18), UDim2.new(0.55, 0, 0, y), 8, Enum.TextXAlignment.Right)
			if currentValue ~= baseValue then
				local beneficial = definition.LowerIsBetter == true
					and currentValue < baseValue
					or definition.LowerIsBetter ~= true and currentValue > baseValue
				valueLabel.TextColor3 = beneficial and Color3.fromRGB(84, 255, 126) or Color3.fromRGB(230, 90, 98)
			end
			y += 20
		end
	else
		local Definitions = NTRVehiclePhaseAO.performanceModules()
		for _, headlineName in ipairs(Definitions.HeadlineOrder) do
			NTRVehiclePhaseAO.drawBar(
				parent,
				headlineName,
				preview.Headline[headlineName],
				basePerformance.Headline[headlineName],
				y
			)
			y += 28
		end
	end
end

function NTRVehiclePhaseAO.effectSummary(upgrade)
	local Definitions = NTRVehiclePhaseAO.performanceModules()
	local parts = {}
	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		local amount = upgrade.EffectsPerLevel and upgrade.EffectsPerLevel[variableName]
		if typeof(amount) == "number" and amount ~= 0 then
			local definition = Definitions.GetNormalization(variableName)
			local sign = amount > 0 and "+" or ""
			table.insert(parts, (definition.DisplayName or variableName) .. " " .. sign .. tostring(amount))
		end
	end
	return table.concat(parts, "  |  ")
end

function NTRVehiclePhaseAO.renderModuleUpgrades(parent, refreshScreen, refreshStats)
	clear(parent)
	UI.ColorChannelFloat.Visible = false
	local slotId, moduleId, module = NTRVehiclePhaseAO.installedModule()
	local upgrades = (module and module.Upgrades) or {}
	if not module or #upgrades == 0 then
		label(parent, "No upgrades are available for this module.", UDim2.new(1, 0, 0, 34), UDim2.fromOffset(6, 10), 11, Enum.TextXAlignment.Left)
		return
	end

	local scroller = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = UserInputService.TouchEnabled and 5 or 3,
		ScrollBarImageColor3 = Theme.Accent,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, scroller)

	for cardIndex, upgrade in ipairs(upgrades) do
		local level = NTRVehiclePhaseAO.moduleLevel(moduleId, upgrade.UpgradeId)
		local maxLevel = tonumber(upgrade.MaxLevel) or 3
		local isMax = level >= maxLevel
		local price = math.floor((tonumber(upgrade.BasePrice) or 0) * ((tonumber(upgrade.PriceMultiplier) or 1) ^ level))
		local selected = State.PreviewUpgradeId == upgrade.UpgradeId
		local card = button(
			scroller,
			"",
			UDim2.fromOffset(UserInputService.TouchEnabled and 206 or 220, 78),
			UDim2.fromScale(0, 0),
			isMax and Theme.Disabled or (selected and Theme.CardHot or Theme.Card)
		)
		card.LayoutOrder = cardIndex
		label(card, upgrade.DisplayName or upgrade.UpgradeId, UDim2.new(1, -12, 0, 24), UDim2.fromOffset(6, 4), 10, Enum.TextXAlignment.Left)
		local levelText = "LVL " .. tostring(level) .. "/" .. tostring(maxLevel)
		if not isMax then levelText ..= "   $" .. tostring(price) end
		local levelLabel = label(card, levelText, UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 27), 8, Enum.TextXAlignment.Left)
		levelLabel.TextColor3 = isMax and Theme.Accent or Theme.Cash
		label(card, NTRVehiclePhaseAO.effectSummary(upgrade), UDim2.new(1, -12, 0, 30), UDim2.fromOffset(6, 44), 7, Enum.TextXAlignment.Left)

		if not isMax then
			card.MouseButton1Click:Connect(function()
				State.PreviewUpgradeId = upgrade.UpgradeId
				refreshStats()
				clear(UI.CosmeticPopup)
				UI.CosmeticPopup.Visible = true
				local popupX = math.clamp(
					card.AbsolutePosition.X - UI.CustomisePanel.AbsolutePosition.X + 38,
					0,
					math.max(0, UI.CustomisePanel.AbsoluteSize.X - 126)
				)
				UI.CosmeticPopup.Position = UDim2.fromOffset(popupX, -32)
				local buy = button(UI.CosmeticPopup, "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Danger)
				buy.MouseButton1Click:Connect(function()
					local result = callServer("UpgradeModule", {
						SlotId = slotId,
						ModuleId = moduleId,
						UpgradeId = upgrade.UpgradeId,
					})
					UI.Subtitle.Text = result.Message or ""
					if result.Success then
						State.PreviewUpgradeId = nil
						UI.CosmeticPopup.Visible = false
						refreshScreen()
					else
						refreshStats()
					end
				end)
			end)
		end
	end
end

local function renderStatsOnly(parent, stats, baseStats)
]]

queueReplace("Phase AO helper insertion", helperAnchor, helperBlock)

queueReplace(
	"Phase AO stats panel renderer",
	[[		local stats, baseStats = currentStats()
		renderStatsOnly(UI.StatsPanel, stats, baseStats)
]],
	[[		local stats = currentStats()
		NTRVehiclePhaseAO.renderStats(UI.StatsPanel, stats)
	]]
)

queueReplace(
	"Phase AO dealership stats renderer",
	[[	renderStatsOnly(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
]],
	[[	NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
]]
)

queueReplace(
	"Phase AO legacy left upgrade targets",
	[[
	for _, upgrade in ipairs({ "Brakes", "Converter", "FuelSystem" }) do
		local display = upgrade == "FuelSystem" and "Fuel System" or upgrade
		local b = button(UI.CustomiseList, display, UDim2.new(1, 0, 0, 42), UDim2.fromScale(0, 0), State.CustomizeTarget == upgrade and Theme.CardHot or Theme.Card)
		b.MouseButton1Click:Connect(function()
			State.CustomizeTarget = upgrade
			State.CustomizeMode = "Upgrade"
			setCameraSection(nil)
			renderCustomise()
		end)
	end
]],
	[[
	-- Phase AO: performance upgrades now live on each installed module.
]]
)

queueReplace(
	"Phase AO preview reset",
	[[	if State.CustomizeMode ~= "Upgrade" then State.PreviewUpgradeId = nil end
]],
	[[	if State.CustomizeMode ~= "ModuleUpgrades" then State.PreviewUpgradeId = nil end
]]
)

queueReplace(
	"Phase AO legacy vehicle upgrade branch",
	[[	if target == "Brakes" or target == "Converter" or target == "FuelSystem" then
		local levels = (State.Profile and State.Profile.UpgradeLevels) or {}
		local level = levels[target] or 0
		local upgradeInfo = getUpgrade(target) or {}
		local price = (upgradeInfo.PricePerLevel or 0) * (level + 1)
		local upgrade = button(UI.CustomiseContent, "UPGRADE (LVL " .. tostring(level + 1) .. ")", UDim2.fromOffset(190, 72), UDim2.fromOffset(6, 8), Theme.Buy)
		label(upgrade, "$" .. tostring(price), UDim2.new(1, -10, 0, 18), UDim2.fromOffset(5, 46), 11, Enum.TextXAlignment.Center).TextColor3 = Theme.Cash
		upgrade.MouseButton1Click:Connect(function()
			State.PreviewUpgradeId = target
			renderStatsPanel()
			clear(UI.CosmeticPopup)
			UI.CosmeticPopup.Visible = true
			UI.CosmeticPopup.Position = UDim2.fromOffset(34, -32)
			local buy = button(UI.CosmeticPopup, "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Danger)
			buy.MouseButton1Click:Connect(function()
				local result = callServer("Upgrade", { UpgradeId = target })
				UI.Subtitle.Text = result.Message or ""
				State.PreviewUpgradeId = nil
				UI.CosmeticPopup.Visible = false
				renderStatsPanel()
				renderCustomise()
				buildPreview()
			end)
		end)
		return
	end

]],
	""
)

queueReplace(
	"Phase AO module upgrade mode",
	[[	if State.CustomizeMode == "Cosmetics" then
		renderCosmetics()
		return
	end

]],
	[[	if State.CustomizeMode == "Cosmetics" then
		renderCosmetics()
		return
	end
	if State.CustomizeMode == "ModuleUpgrades" then
		NTRVehiclePhaseAO.renderModuleUpgrades(
			UI.CustomiseContent,
			function() renderCustomise() end,
			function() renderStatsPanel() end
		)
		return
	end

]]
)

queueReplace(
	"Phase AO module overview buttons",
	[[		local cosmetics = button(UI.CustomiseContent, "Cosmetics", UDim2.fromOffset(170, 72), UDim2.fromOffset(188, 8), Theme.Card)
		local upgrade = button(UI.CustomiseContent, "UPGRADE (LVL 1)", UDim2.fromOffset(190, 72), UDim2.fromOffset(370, 8), Theme.Buy)
		cosmetics.MouseButton1Click:Connect(function()
			State.CustomizeMode = "Cosmetics"
			renderCustomise()
		end)
		upgrade.MouseButton1Click:Connect(function()
			State.PreviewUpgradeId = target
			renderStatsPanel()
			clear(UI.CosmeticPopup)
			UI.CosmeticPopup.Visible = true
			UI.CosmeticPopup.Position = UDim2.fromOffset(396, -32)
			local buy = button(UI.CosmeticPopup, "Buy", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Theme.Danger)
			buy.MouseButton1Click:Connect(function()
				UI.Subtitle.Text = "Visible module upgrades are ready to expand with per-module upgrade rules."
				State.PreviewUpgradeId = nil
				UI.CosmeticPopup.Visible = false
			end)
		end)
]],
	[[		local cosmetics = button(UI.CustomiseContent, "Cosmetics", UDim2.fromOffset(170, 72), UDim2.fromOffset(188, 8), Theme.Card)
		local upgrades = button(UI.CustomiseContent, "Performance", UDim2.fromOffset(190, 72), UDim2.fromOffset(370, 8), Theme.Buy)
		cosmetics.MouseButton1Click:Connect(function()
			State.CustomizeMode = "Cosmetics"
			renderCustomise()
		end)
		upgrades.MouseButton1Click:Connect(function()
			State.CustomizeMode = "ModuleUpgrades"
			State.PreviewUpgradeId = nil
			renderCustomise()
		end)
]]
)

queueReplace(
	"Phase AO customisation subtitle",
	[[	showTop("Customise", "Upgrade performance, change colours, or unlock lights.")
]],
	[[	showTop("Customise", "Tune installed modules, change colours, or unlock lights.")
]]
)

queueReplace(
	"Phase AO back navigation",
	[[			if (State.CustomizeMode == "Colour" and State.CustomizeTarget ~= "ALL") or State.CustomizeMode == "Cosmetics" then
]],
	[[			if (State.CustomizeMode == "Colour" and State.CustomizeTarget ~= "ALL") or State.CustomizeMode == "Cosmetics" or State.CustomizeMode == "ModuleUpgrades" then
]]
)

local patched = source
for _, replacement in ipairs(replacements) do
	local startIndex, endIndex = string.find(patched, replacement.Old, 1, true)
	assert(startIndex, replacement.Label .. " disappeared during patch assembly")
	patched = string.sub(patched, 1, startIndex - 1)
		.. replacement.New
		.. string.sub(patched, endIndex + 1)
end

assert(string.find(patched, marker, 1, true), "Phase AO marker was not assembled")
assert(not string.find(patched, 'for _, upgrade in ipairs({ "Brakes", "Converter", "FuelSystem" })', 1, true), "Legacy left upgrade targets remain")
assert(not string.find(patched, "Visible module upgrades are ready to expand", 1, true), "Generic upgrade placeholder remains")
assert(string.find(patched, 'callServer("UpgradeModule"', 1, true), "UpgradeModule action is missing")

bootstrap.Source = patched
bootstrap:SetAttribute("VehicleUpgradeUIPhase", "AO")

print("[NTR Vehicle Phase AO] Installed module-specific upgrade cards and purchase flow.")
print("[NTR Vehicle Phase AO] Replaced the stats panel with tier/index, headline stats, and module-context variables.")
print("[NTR Vehicle Phase AO] Removed visible Brakes, Converter, Fuel System, and generic upgrade controls.")
print("[NTR Vehicle Phase AO] The installer performed exactly one client Source write.")
