-- Neo Tokyo Racers - Racing UI Phase 2 Time Trial Startup
-- Run from Roblox Studio Command Bar in Edit mode.
--
-- Installs one isolated RaceEntryPresentationController_Active and a tiny,
-- verified two-event bridge in the confirmed RaceEntryMenuClient_Active.
-- Legacy entry state, vehicle validation, staging, countdown, HUD, PB ownership,
-- rewards, reset, finish lifecycle, and matchmaking remain unchanged.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 2 Time Trial Startup"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function ensure(parent, className, name)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA(className), item:GetFullName() .. " has wrong class") return item end
	item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end

local function ensureValue(parent, className, name, default)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA(className), item:GetFullName() .. " has wrong class") return item end
	item = Instance.new(className)
	item.Name = name
	item.Value = default
	item.Parent = parent
	return item
end

local function controllerSource()
	return [====[
-- Neo Tokyo Racers - Racing UI Phase 2 Time Trial Startup Presentation
-- NTR_RACING_UI_PHASE2_TIME_TRIAL_STARTUP_PRESENTATION
-- NTR_RACING_UI_PHASE2_V4_EQUAL_COLUMNS_COMPACT_TARGETS
-- NTR_RACING_UI_PHASE2_V5_PB_VEHICLE_BONUS_RESPONSIVE_BUFFER
-- NTR_RACING_UI_PHASE2_V5_1_OPTIONAL_COPY_FALLBACK
-- NTR_RACING_UI_PHASE2_V6_PB_TRIPTYCH_TIER_STATES_SHARED_SCALE
-- NTR_RACING_UI_PHASE2_V7_RACE_FORMAT_PRIZES_RECORD
-- NTR_RACING_UI_PHASE2_V7_1_PERSISTENT_SELECTED_TABS
-- NTR_RACING_UI_PHASE2_V8_MAP_HERO_VERTICAL_TARGETS
-- NTR_RACING_UI_PHASE2_V8_1_FLAT_COLUMNS_CENTERED_LAPS
-- NTR_RACING_UI_PHASE2_V9_RECORDS_NAVIGATION_POLISH
-- NTR_RACING_UI_PHASE2_V10_RACING_VEHICLE_PICKER

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local touch = UserInputService.TouchEnabled
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local remotes = shared:WaitForChild("Remotes")
local racingRemotes = remotes:WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local garageInvoke = remotes:WaitForChild("Garage"):WaitForChild("GarageInvoke")
local racingModules = shared:WaitForChild("Modules"):WaitForChild("Racing")
local RaceConfigReader = require(racingModules:WaitForChild("RaceConfigReader"))
local UI = require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local racingUIConfig = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing")
local copyConfig = racingUIConfig:FindFirstChild("Copy")
local racingConfig = kit:WaitForChild("Config"):WaitForChild("Racing")
local rewardsConfig = racingConfig:FindFirstChild("Rewards")
local raceRewards = rewardsConfig and rewardsConfig:FindFirstChild("Race")

local requestEvent = script.Parent:WaitForChild("RaceEntryPresentationRequest")
local legacyAction = script.Parent:WaitForChild("RaceEntryLegacyAction")
local tiers = { "E", "D", "C", "B", "A", "S" }
local tierColors = {
	E = Color3.fromRGB(145, 162, 171), D = Color3.fromRGB(93, 202, 126),
	C = Color3.fromRGB(71, 195, 202), B = Color3.fromRGB(79, 139, 238),
	A = Color3.fromRGB(178, 92, 255), S = Color3.fromRGB(224, 78, 255),
}
local medalCells = {
	Platinum = Vector2.new(0, 0), Gold = Vector2.new(1, 0),
	Silver = Vector2.new(0, 1), Bronze = Vector2.new(1, 1),
}

local C = function(name) return UI.Colour(name) end
local L = function(name, fallback) return UI.Layout(name, fallback) end
local T = function(name, fallback) return UI.Type(name, fallback) end

local payload
local summary
local selectedMode = "TimeTrial"
local selectedTier = "E"
local selectedLap = 1
local currentPage = "Setup"
local selectedVehicleId = ""
local vehicleCategory = "ALL"
local vehicleSort = "RATING"
local ownedTiers = {}
local garageProfile, garageCatalog
local gui, overlay, shell, content, footer, status
local timeTrialTab, raceTab
local headerTitle
local suppressed = {}
local suppressHeartbeat, suppressAdded

local function call(remote, action, data)
	local ok, result = pcall(function() return remote:InvokeServer(action, data or {}) end)
	if ok and type(result) == "table" then return result end
	return { Ok = false, Success = false, Message = tostring(result) }
end

local function asset(value)
	return UI.Asset(value)
end

local function money(value)
	local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
	local changed
	repeat
		text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return "$" .. text
end

local function timeText(seconds)
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then return "--:--.---" end
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%06.3f", minutes, seconds - minutes * 60)
end

local function numberAttribute(parent, name, fallback)
	local value = parent and tonumber(parent:GetAttribute(name))
	return value == nil and fallback or value
end

local function roundedRacePrize(baseReward, medal)
	local multiplier = numberAttribute(raceRewards, medal .. "RewardMultiplier", medal == "Gold" and 1 or medal == "Silver" and 0.85 or 0.65)
	local nearest = math.max(1, numberAttribute(raceRewards, "RewardRoundToNearest", 250))
	local amount = math.floor(((tonumber(baseReward) or 0) * multiplier) / nearest + 0.5) * nearest
	return math.clamp(amount, numberAttribute(raceRewards, "MinReward", 0), numberAttribute(raceRewards, "MaxReward", 10000))
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do child:Destroy() end
end

local function gradient(parent)
	local layer = Instance.new("Frame")
	layer.Name = "GradientOverlay"
	layer.Active = false
	layer.BackgroundColor3 = Color3.new(1, 1, 1)
	layer.BackgroundTransparency = 0.9
	layer.BorderSizePixel = 0
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = parent.ZIndex
	layer.Parent = parent
	UI.Corner(layer, L("CornerRadius", 5))
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 95, 95))
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.52, 0.7), NumberSequenceKeypoint.new(1, 0.28) })
	g.Parent = layer
end

local function imagePanel(parent, image, placeholder, position, size)
	local panel = UI.Panel(parent, { Position = position, Size = size, Color = C("PanelDeep"), Transparency = 0.05, StrokeColor = C("Outline"), StrokeTransparency = 0.18, Clips = true })
	image = asset(image)
	if image ~= "" then
		local picture = Instance.new("ImageLabel")
		picture.BackgroundTransparency = 1
		picture.Position = UDim2.fromOffset(3, 3)
		picture.Size = UDim2.new(1, -6, 1, -6)
		picture.Image = image
		picture.ScaleType = Enum.ScaleType.Crop
		picture.Parent = panel
		UI.Corner(picture, L("CornerRadius", 5))
	else
		local label = UI.Label(panel, { Text = placeholder, Size = UDim2.fromScale(1, 1), Color = C("Muted"), TextSize = T("Caption", 11), Role = "Heading", XAlignment = Enum.TextXAlignment.Center })
		label.TextTransparency = 0.25
	end
	return panel
end

local function mapTitleOverlay(panel, title, subtitle)
	local shade = Instance.new("Frame")
	shade.Name = "MapTitleShade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.32
	shade.BorderSizePixel = 0
	shade.Size = UDim2.new(1, 0, 0, touch and 54 or 76)
	shade.ZIndex = panel.ZIndex + 3
	shade.Parent = panel
	UI.Corner(shade, L("CornerRadius", 5))
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = shade
	UI.Label(shade, { Text = title, Position = UDim2.fromOffset(touch and 12 or 18, touch and 3 or 6), Size = UDim2.new(1, touch and -24 or -36, 0, touch and 28 or 38), TextSize = touch and 18 or 30, Color = C("Text"), Role = "Heading" }).ZIndex = shade.ZIndex + 1
	UI.Label(shade, { Text = subtitle, Position = UDim2.fromOffset(touch and 12 or 18, touch and 28 or 39), Size = UDim2.new(1, touch and -24 or -36, 0, touch and 18 or 24), TextSize = touch and 8 or 11, Color = C("Muted"), Role = "Heading" }).ZIndex = shade.ZIndex + 1
end

local function medalIcon(parent, medal, position, size)
	local atlas = asset(UI.AssetValue("MedalAtlas", ""))
	if atlas == "" then return nil end
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Position = position
	icon.Size = size
	icon.Image = atlas
	local cell = medalCells[medal] or Vector2.new(0, 0)
	local cellSize = math.max(1, tonumber(UI.AssetValue("MedalAtlasCellSize", "512")) or 512)
	icon.ImageRectOffset = Vector2.new(cell.X * cellSize, cell.Y * cellSize)
	icon.ImageRectSize = Vector2.new(cellSize, cellSize)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent
	return icon
end

local raceIconCells = {
	Checkpoints = { Cell = Vector2.new(1, 1), X = -0.9, Y = -5.0 },
	Players = { Cell = Vector2.new(2, 1), X = 1.2, Y = -5.8 },
}

local function raceDetailIcon(parent, name, position, size)
	local atlas = asset(UI.AssetValue("RacingIconAtlas", ""))
	local spec = raceIconCells[name]
	if atlas == "" or not spec then return nil end
	local cellSize = math.max(1, tonumber(UI.AssetValue("RacingIconCellSize", "256")) or 256)
	local renderSize = math.max(1, size.X.Offset)
	local opticalScale = renderSize / 33
	local icon = Instance.new("ImageLabel")
	icon.Name = name .. "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = position + UDim2.fromOffset(spec.X * opticalScale, spec.Y * opticalScale)
	icon.Size = size
	icon.Image = atlas
	icon.ImageRectOffset = Vector2.new(spec.Cell.X * cellSize, spec.Cell.Y * cellSize)
	icon.ImageRectSize = Vector2.new(cellSize, cellSize)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent
	return icon
end

local function readOwnedTiers()
	ownedTiers = {}
	local result = call(garageInvoke, "GetInitial", {})
	garageProfile = result.Profile or result
	garageCatalog = result.Catalog or garageCatalog
	for _, vehicleSummary in pairs((garageProfile and garageProfile.VehicleSummaries) or {}) do
		local overall = vehicleSummary and vehicleSummary.Overall or {}
		local tier = string.upper(tostring(overall.Tier or ""))
		if tier ~= "" then ownedTiers[tier] = true end
	end
	selectedTier = "E"
	for index = #tiers, 1, -1 do
		if ownedTiers[tiers[index]] then selectedTier = tiers[index] break end
	end
end

local function vehiclePresentationForId(vehicleId)
	vehicleId = tostring(vehicleId or "")
	if vehicleId == "" or not garageProfile then return "", "VEHICLE" end
	local vehicle = garageProfile.Vehicles and (garageProfile.Vehicles[vehicleId] or garageProfile.Vehicles[tonumber(vehicleId)])
	if not vehicle then return "", "VEHICLE" end
	local cockpitId = tostring(vehicle.CockpitId or "")
	if cockpitId == "" and vehicle.CockpitInstanceId then
		local instance = garageProfile.OwnedCockpitInstances and garageProfile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		cockpitId = tostring(instance and instance.TemplateId or "")
	end
	for _, category in ipairs((garageCatalog and garageCatalog.Categories) or {}) do
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			if tostring(cockpit.CockpitId or cockpit.Id or "") == cockpitId then
				local image = cockpit.MenuImage or cockpit.Image or cockpit.Icon or cockpit.Thumbnail
				local name = tostring(cockpit.DisplayName or cockpit.Name or cockpitId or "VEHICLE")
				if typeof(image) == "string" and image ~= "" then return image, name end
				return "", name
			end
		end
	end
	local assets = kit:FindFirstChild("Assets")
	local vehicles = assets and assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	for _, category in ipairs(categories and categories:GetChildren() or {}) do
		local cockpitRoot = category:FindFirstChild("COCKPITS_ReplaceAssetsHere")
		for _, model in ipairs(cockpitRoot and cockpitRoot:GetChildren() or {}) do
			if model:IsA("Model") and (model.Name == cockpitId or tostring(model:GetAttribute("CockpitId") or "") == cockpitId) then
				local image = model:GetAttribute("MenuImage")
				if typeof(image) == "string" and image ~= "" then return image, tostring(model:GetAttribute("DisplayName") or model.Name) end
			end
		end
	end
	return "", cockpitId ~= "" and cockpitId or "VEHICLE"
end

local function racingVehicleRows()
	local rows = {}
	for vehicleId, vehicle in pairs((garageProfile and garageProfile.Vehicles) or {}) do
		local summaryData = garageProfile.VehicleSummaries and (garageProfile.VehicleSummaries[vehicleId] or garageProfile.VehicleSummaries[tostring(vehicleId)])
		local overall = summaryData and summaryData.Overall or {}
		local tier = string.upper(tostring(overall.Tier or "--"))
		if selectedMode == "Race" or tier == selectedTier then
			local image, name = vehiclePresentationForId(vehicleId)
			local cockpitId = tostring(vehicle.CockpitId or "")
			if cockpitId == "" and vehicle.CockpitInstanceId then
				local instance = garageProfile.OwnedCockpitInstances and garageProfile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
				cockpitId = tostring(instance and instance.TemplateId or "")
			end
			local category = "OTHER"
			for _, categoryData in ipairs((garageCatalog and garageCatalog.Categories) or {}) do
				for _, cockpit in ipairs(categoryData.Cockpits or {}) do
					if tostring(cockpit.CockpitId or cockpit.Id or "") == cockpitId then category = string.upper(tostring(categoryData.DisplayName or categoryData.Name or categoryData.Id or "OTHER")) break end
				end
			end
			table.insert(rows, { VehicleId = tostring(vehicleId), CockpitId = cockpitId, Name = name, Image = image, Tier = tier, Rating = tonumber(overall.PerformanceIndex) or 0, Category = category })
		end
	end
	table.sort(rows, function(a, b)
		if vehicleSort == "NAME" then return a.Name == b.Name and a.VehicleId < b.VehicleId or a.Name < b.Name end
		if vehicleSort == "CLASS" and a.Tier ~= b.Tier then return (table.find(tiers, a.Tier) or 0) > (table.find(tiers, b.Tier) or 0) end
		if a.Rating ~= b.Rating then return a.Rating > b.Rating end
		return a.Name < b.Name
	end)
	return rows
end

local function copyValue(name, fallback)
	local value = copyConfig and copyConfig:FindFirstChild(name)
	return value and value:IsA("StringValue") and value.Value or fallback
end

local function pairedEventId(mode)
	if mode == "Race" then
		local paired = tostring(payload and payload.RaceEventId or "")
		if paired ~= "" then return paired end
		local id = tostring(payload and payload.EventId or summary.EventId or "")
		return id:sub(-3) == "_tt" and (id:sub(1, -4) .. "_race") or id
	end
	local paired = tostring(payload and payload.TimeTrialEventId or "")
	if paired ~= "" then return paired end
	local id = tostring(payload and payload.EventId or summary.EventId or "")
	return id:sub(-5) == "_race" and (id:sub(1, -6) .. "_tt") or id
end

local function browserMedia(field)
	-- Match the Race Browser's media precedence: Race Catalog first, then
	-- Time Trial Catalog, then the payload summary/route fallback.
	for _, mode in ipairs({ "Race", "TimeTrial" }) do
		local eventId = pairedEventId(mode)
		local ok, eventSummary = pcall(function()
			return RaceConfigReader.GetEventSummary(eventId, mode)
		end)
		local value = ok and eventSummary and tostring(eventSummary[field] or "") or ""
		if value ~= "" then return value end
	end
	return tostring(summary[field] or "")
end

local function lapBounds()
	local minLap = math.clamp(math.floor(tonumber(summary.MinLapCount) or 1), 1, 10)
	local maxLap = math.clamp(math.floor(tonumber(summary.MaxLapCount) or 10), minLap, 10)
	return minLap, maxLap
end

local function modeSummary(mode)
	local eventId = pairedEventId(mode)
	local ok, result = pcall(function() return RaceConfigReader.GetEventSummary(eventId, mode) end)
	return ok and type(result) == "table" and result or summary
end

local function raceCatalogAttribute(name)
	local catalog = racingConfig:FindFirstChild("RaceCatalog")
	local event = catalog and catalog:FindFirstChild(pairedEventId("Race"))
	return event and event:GetAttribute(name)
end

local function suppressOthers(open)
	if open then
		table.clear(suppressed)
		local function suppress(item)
			if item:IsA("ScreenGui") and item ~= gui then
				if suppressed[item] == nil then suppressed[item] = item.Enabled end
				item.Enabled = false
			end
		end
		for _, item in ipairs(playerGui:GetChildren()) do suppress(item) end
		suppressAdded = playerGui.ChildAdded:Connect(suppress)
		suppressHeartbeat = RunService.Heartbeat:Connect(function()
			for item in pairs(suppressed) do if item.Parent and item.Enabled then item.Enabled = false end end
		end)
	else
		if suppressHeartbeat then suppressHeartbeat:Disconnect() suppressHeartbeat = nil end
		if suppressAdded then suppressAdded:Disconnect() suppressAdded = nil end
		for item, enabled in pairs(suppressed) do if item.Parent then item.Enabled = enabled end end
		table.clear(suppressed)
	end
end

local function setOpen(open)
	suppressOthers(open)
	overlay.Visible = open
end

local render

local function updateTabs()
	if not timeTrialTab or not raceTab then return end
	local function set(button, selected)
		button.BackgroundColor3 = selected and C("PanelBlue") or C("PanelSoft")
		local stroke = button:FindFirstChild("Stroke")
		local glow = button:FindFirstChild("GlowStroke")
		if stroke then stroke.Color = selected and C("Telemetry") or C("Outline") end
		if glow then glow.Color = selected and C("Telemetry") or C("Outline") end
	end
	set(timeTrialTab, selectedMode == "TimeTrial")
	set(raceTab, selectedMode == "Race")
end

local function renderTierRail(parent, readOnly)
	local gap = touch and 6 or 8
	local widthScale = 1 / #tiers
	for index, tier in ipairs(tiers) do
		local locked = not ownedTiers[tier]
		local chosen = tier == selectedTier
		local button = UI.Button(parent, {
			Name = "Tier" .. tier, Text = readOnly and tier or (locked and (tier .. "  LOCKED") or tier),
			Position = UDim2.new((index - 1) * widthScale, index == 1 and 0 or gap / 2, 0, 0),
			Size = UDim2.new(widthScale, index == 1 and -gap / 2 or -gap, 1, 0),
			Color = chosen and tierColors[tier] or C("PanelSoft"),
			Transparency = chosen and 0.3 or 0.08,
			StrokeColor = readOnly and (chosen and tierColors[tier] or C("Disabled")) or tierColors[tier],
			FocusColor = readOnly and (chosen and tierColors[tier] or C("Disabled")) or tierColors[tier], TextColor = chosen and C("Text") or ((readOnly or locked) and C("Disabled") or C("Text")),
			TextSize = touch and 10 or T("Body", 14),
		})
		if readOnly then button.Active = false button.Selectable = false else button.MouseButton1Click:Connect(function() selectedTier = tier render() end) end
	end
end

local function renderRaceSetup()
	local race = modeSummary("Race")
	local gap = touch and 10 or L("Gap", 16)
	local laps = math.max(1, math.floor(tonumber(race.Laps or race.DefaultLapCount) or 1))
	local minPlayers = math.max(1, math.floor(tonumber(race.MinPlayers) or 2))
	local maxPlayers = math.max(minPlayers, math.floor(tonumber(race.MaxPlayers) or 6))
	local checkpoints = math.max(0, math.floor(tonumber(race.CheckpointCount or summary.CheckpointCount) or 0))
	local lengthMiles = tonumber(raceCatalogAttribute("TrackLengthMiles") or race.TrackLengthMiles or summary.TrackLengthMiles)
	if lengthMiles and lengthMiles <= 0 then lengthMiles = nil end
	local baseReward = tonumber(race.BaseReward or summary.BaseReward) or 0

	local strip = UI.Panel(content, { Name = "RaceInformationStrip", Size = UDim2.new(1, 0, 0, touch and 42 or 52), Color = C("Panel"), Transparency = 0.04, StrokeColor = C("OutlineSoft"), StrokeTransparency = 0.35 })
	gradient(strip)
	local facts = {
		"OPEN CATEGORY",
		"CIRCUIT  •  " .. tostring(laps) .. " LAPS",
		lengthMiles and string.format("TRACK LENGTH  •  %.2f MI", lengthMiles) or "TRACK LENGTH  •  -- MI",
		tostring(minPlayers) .. "–" .. tostring(maxPlayers) .. " PLAYERS",
	}
	for index, text in ipairs(facts) do
		UI.Label(strip, { Text = text, Position = UDim2.new((index - 1) * 0.25, 0, 0, 0), Size = UDim2.new(0.25, 0, 1, 0), TextSize = touch and 8 or 12, Color = index == 1 and C("Telemetry") or C("Text"), Role = "Heading", XAlignment = Enum.TextXAlignment.Center })
	end

	local bodyY = touch and 52 or 68
	local columnWidth = 0.5
	local left = Instance.new("Frame")
	left.Name = "RaceLeftColumn"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(0, bodyY)
	left.Size = UDim2.new(columnWidth, -gap / 2, 1, -bodyY)
	left.Parent = content
	local raceMap = imagePanel(left, browserMedia("MapImage"), "TRACK MAP", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	mapTitleOverlay(raceMap, "MULTIPLAYER RACE", string.upper(tostring(race.DisplayName or summary.DisplayName or "RACE")))

	local right = Instance.new("Frame")
	right.Name = "RaceRightColumn"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(columnWidth, gap / 2, 0, bodyY)
	right.Size = UDim2.new(columnWidth, -gap / 2, 1, -bodyY)
	right.Parent = content
	local format = UI.Panel(right, { Name = "RaceFormat", Size = UDim2.new(1, 0, 0, touch and 70 or 88), Color = C("Panel"), Transparency = 0.04, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	gradient(format)
	UI.Label(format, { Text = "RACE FORMAT", Position = UDim2.fromOffset(16, 7), Size = UDim2.new(1, -32, 0, 22), TextSize = touch and 9 or 13, Color = C("Telemetry"), Role = "Heading" })
	UI.Label(format, { Text = tostring(laps) .. (laps == 1 and " LAP" or " LAPS"), Position = UDim2.fromOffset(16, touch and 27 or 30), Size = UDim2.new(1, -32, 1, touch and -31 or -34), TextSize = touch and 20 or 30, Color = C("Telemetry"), Role = "Metric" })

	local prizeY = (touch and 70 or 88) + gap
	local statsH = touch and 62 or 76
	local prizes = UI.Panel(right, { Name = "PlacementPrizes", Position = UDim2.fromOffset(0, prizeY), Size = UDim2.new(1, 0, 1, -(prizeY + gap + statsH)), Color = C("Panel"), Transparency = 0.04, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	gradient(prizes)
	UI.Label(prizes, { Text = "PLACEMENT PRIZES", Position = UDim2.fromOffset(16, 7), Size = UDim2.new(1, -32, 0, 24), TextSize = touch and 10 or 16, Color = C("Telemetry"), Role = "Heading" })
	local placements = { { "Gold", "1ST" }, { "Silver", "2ND" }, { "Bronze", "3RD" } }
	for index, placement in ipairs(placements) do
		local rowH = touch and 42 or 54
		local y = (touch and 32 or 38) + (index - 1) * (rowH + (touch and 4 or 6))
		local row = UI.Panel(prizes, { Name = placement[2], Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, rowH), Color = C("PanelDeep"), Transparency = 0.08, StrokeColor = C("OutlineSoft"), StrokeTransparency = 0.5 })
		local iconSize = touch and 34 or 44
		medalIcon(row, placement[1], UDim2.fromOffset(10, (rowH - iconSize) / 2), UDim2.fromOffset(iconSize, iconSize))
		UI.Label(row, { Text = placement[2], Position = UDim2.fromOffset(touch and 52 or 66, 0), Size = UDim2.new(0.28, 0, 1, 0), TextSize = touch and 15 or 22, Color = C("Text"), Role = "Heading" })
		UI.Label(row, { Text = money(roundedRacePrize(baseReward, placement[1])), Position = UDim2.new(0.50, 0, 0, 0), Size = UDim2.new(0.46, -12, 1, 0), TextSize = touch and 15 or 22, Color = C("Telemetry"), Role = "Metric", XAlignment = Enum.TextXAlignment.Right })
	end

	local stats = Instance.new("Frame")
	stats.Name = "RaceStats"
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.new(0, 0, 1, -statsH)
	stats.Size = UDim2.new(1, 0, 0, statsH)
	stats.Parent = right
	local statData = { { "Checkpoints", "CHECKPOINTS", tostring(checkpoints) }, { "Players", "MAX PLAYERS", tostring(maxPlayers) } }
	for index, stat in ipairs(statData) do
		local panel = UI.Panel(stats, { Position = UDim2.new((index - 1) * 0.5, index == 1 and 0 or gap / 2, 0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), Color = C("Panel"), Transparency = 0.04, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
		gradient(panel)
		local iconSize = touch and 28 or 38
		local icon = raceDetailIcon(panel, stat[1], UDim2.fromOffset(touch and 12 or 16, (statsH - iconSize) / 2), UDim2.fromOffset(iconSize, iconSize))
		if icon then icon.ZIndex = panel.ZIndex + 2 end
		UI.Label(panel, { Text = stat[2], Position = UDim2.fromOffset(touch and 48 or 62, 7), Size = UDim2.new(1, touch and -54 or -70, 0, 22), TextSize = touch and 8 or 11, Color = C("Text"), Role = "Heading" })
		UI.Label(panel, { Text = stat[3], Position = UDim2.fromOffset(touch and 48 or 62, touch and 24 or 28), Size = UDim2.new(1, touch and -54 or -70, 1, touch and -28 or -34), TextSize = touch and 16 or 22, Color = C("Telemetry"), Role = "Metric" })
	end

	local footerTextSize = touch and 9 or 13
	local exit = UI.Button(footer, { Text = "EXIT", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), StrokeColor = C("Outline"), TextSize = footerTextSize })
	local choose = UI.Button(footer, { Text = "CHOOSE VEHICLE", Position = UDim2.new(0.5, gap / 2, 0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), Color = C("PanelBlue"), StrokeColor = C("Telemetry"), FocusColor = C("Telemetry"), TextSize = footerTextSize })
	exit.MouseButton1Click:Connect(function() setOpen(false) legacyAction:Fire("Close") end)
	choose.MouseButton1Click:Connect(function()
		selectedLap = laps
		selectedVehicleId = ""
		vehicleCategory = "ALL"
		currentPage = "Vehicles"
		render()
	end)
end

local function renderRecordsPage()
	local gap = touch and 10 or L("Gap", 16)
	local tierRail = Instance.new("Frame")
	tierRail.BackgroundTransparency = 1
	tierRail.Size = UDim2.new(1, 0, 0, touch and 42 or 52)
	tierRail.Parent = content
	renderTierRail(tierRail, true)

	local bodyY = touch and 52 or 68
	local columnWidth = 0.5
	local left = Instance.new("Frame")
	left.Name = "RecordsLeftColumn"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(0, bodyY)
	left.Size = UDim2.new(columnWidth, -gap / 2, 1, -bodyY)
	left.Parent = content
	local right = Instance.new("Frame")
	right.Name = "RecordsRightColumn"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(columnWidth, gap / 2, 0, bodyY)
	right.Size = UDim2.new(columnWidth, -gap / 2, 1, -bodyY)
	right.Parent = content

	local eventId = pairedEventId("TimeTrial")
	local medals = RaceConfigReader.GetTimeTrialMedals(eventId, selectedTier) or {}
	local pb = call(raceRequest, "GetTimeTrialPersonalBest", { EventId = eventId, VehicleTier = selectedTier })
	local pbSeconds = tonumber(pb.BestSeconds or (pb.Record and pb.Record.BestSeconds))
	local pbMedal = tostring(pb.BestMedal or (pb.Record and pb.Record.BestMedal) or "--")
	local pbVehicleId = tostring(pb.BestVehicleId or (pb.Record and pb.Record.BestVehicleId) or "")
	local _, pbVehicleName = vehiclePresentationForId(pbVehicleId)
	local globalResult = call(raceRequest, "GetTimeTrialLeaderboard", { EventId = eventId, VehicleTier = selectedTier, Limit = 20 })
	local leader = type(globalResult.Entries) == "table" and globalResult.Entries[1] or nil

	local worldH = touch and 92 or 122
	local world = UI.Panel(left, { Name = "WorldRecord", Size = UDim2.new(1, 0, 0, worldH), Color = C("PanelDeep"), Transparency = 0.06, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	UI.Label(world, { Text = "WORLD RECORD", Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 24), TextSize = touch and 10 or 14, Color = C("Telemetry"), Role = "Heading" })
	local avatar = UI.Panel(world, { Position = UDim2.fromOffset(14, touch and 30 or 34), Size = UDim2.fromOffset(touch and 48 or 66, touch and 48 or 66), Color = C("PanelSoft"), Transparency = 0.12, StrokeColor = C("Outline"), StrokeTransparency = 0.35 })
	UI.Label(avatar, { Text = "?", Size = UDim2.fromScale(1, 1), TextSize = touch and 20 or 28, Color = C("Muted"), Role = "Metric", XAlignment = Enum.TextXAlignment.Center })
	UI.Label(world, { Text = leader and string.upper(tostring(leader.DisplayName or leader.Username or "WORLD RECORD")) or "NO RECORD SET", Position = UDim2.fromOffset(touch and 76 or 96, touch and 29 or 35), Size = UDim2.new(1, touch and -88 or -110, 0, 24), TextSize = touch and 9 or 12, Color = C("Text"), Role = "Heading" })
	UI.Label(world, { Text = leader and timeText(leader.BestSeconds) or "--:--.---", Position = UDim2.fromOffset(touch and 76 or 96, touch and 50 or 59), Size = UDim2.new(1, touch and -88 or -110, 0, touch and 28 or 38), TextSize = touch and 18 or 27, Color = C("Telemetry"), Role = "Metric" })

	local targetsY = worldH + gap
	local targetsH = touch and 156 or 202
	local targets = UI.Panel(left, { Name = "RecordMedalTargets", Position = UDim2.fromOffset(0, targetsY), Size = UDim2.new(1, 0, 0, targetsH), Color = C("PanelDeep"), Transparency = 0.06, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	UI.Label(targets, { Text = "MEDAL TARGETS", Position = UDim2.fromOffset(14, 5), Size = UDim2.new(1, -28, 0, 24), TextSize = touch and 10 or 14, Color = C("Telemetry"), Role = "Heading" })
	for index, name in ipairs({ "Platinum", "Gold", "Silver", "Bronze" }) do
		local rowH = (targetsH - (touch and 28 or 32)) / 4
		local row = Instance.new("Frame")
		row.BackgroundColor3 = C("PanelSoft")
		row.BackgroundTransparency = index % 2 == 0 and 0.56 or 1
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(8, (touch and 26 or 30) + (index - 1) * rowH)
		row.Size = UDim2.new(1, -16, 0, rowH)
		row.Parent = targets
		local iconSize = touch and 24 or 32
		local icon = medalIcon(row, name, UDim2.new(0, 8, 0.5, 0), UDim2.fromOffset(iconSize, iconSize))
		if icon then icon.AnchorPoint = Vector2.new(0, 0.5) end
		UI.Label(row, { Text = string.upper(name), Position = UDim2.fromOffset(touch and 40 or 50, 0), Size = UDim2.new(0.46, 0, 1, 0), TextSize = touch and 9 or 12, Color = C("Text"), Role = "Heading" })
		UI.Label(row, { Text = timeText(medals[name]), Position = UDim2.new(0.56, 0, 0, 0), Size = UDim2.new(0.44, -12, 1, 0), TextSize = touch and 10 or 13, Color = C("Text"), Role = "Metric", XAlignment = Enum.TextXAlignment.Right })
	end

	local yourY = targetsY + targetsH + gap
	local your = UI.Panel(left, { Name = "YourRecord", Position = UDim2.fromOffset(0, yourY), Size = UDim2.new(1, 0, 1, -yourY), Color = C("PanelDeep"), Transparency = 0.06, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	UI.Label(your, { Text = "YOUR RECORD", Position = UDim2.fromOffset(14, 5), Size = UDim2.new(1, -28, 0, 24), TextSize = touch and 10 or 14, Color = C("Telemetry"), Role = "Heading" })
	local yourMedalSize = touch and 48 or 66
	if pbSeconds and medalCells[pbMedal] then medalIcon(your, pbMedal, UDim2.fromOffset(16, touch and 30 or 34), UDim2.fromOffset(yourMedalSize, yourMedalSize)) end
	UI.Label(your, { Text = pbSeconds and timeText(pbSeconds) or "--:--.---", Position = UDim2.fromOffset(touch and 80 or 104, touch and 29 or 35), Size = UDim2.new(1, touch and -92 or -118, 0, touch and 30 or 38), TextSize = touch and 18 or 26, Color = C("Telemetry"), Role = "Metric" })
	UI.Label(your, { Text = string.upper(pbSeconds and pbVehicleName or "NO VEHICLE RECORD"), Position = UDim2.fromOffset(touch and 80 or 104, touch and 55 or 67), Size = UDim2.new(1, touch and -92 or -118, 0, 22), TextSize = touch and 8 or 11, Color = C("Text"), Role = "Heading" })

	local board = UI.Panel(right, { Name = "GlobalTop20", Size = UDim2.fromScale(1, 1), Color = C("PanelDeep"), Transparency = 0.06, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	UI.Label(board, { Text = "GLOBAL TOP 20", Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 26), TextSize = touch and 11 or 16, Color = C("Telemetry"), Role = "Heading" })
	local header = Instance.new("Frame") header.BackgroundColor3 = C("PanelSoft") header.BackgroundTransparency = 0.35 header.BorderSizePixel = 0 header.Position = UDim2.fromOffset(10, touch and 34 or 40) header.Size = UDim2.new(1, -20, 0, touch and 25 or 30) header.Parent = board
	local columns = { { "POS", 0, 0.12 }, { "PLAYER", 0.12, 0.43 }, { "VEHICLE", 0.55, 0.25 }, { "TIME", 0.80, 0.20 } }
	for _, column in ipairs(columns) do UI.Label(header, { Text = column[1], Position = UDim2.new(column[2], 6, 0, 0), Size = UDim2.new(column[3], -12, 1, 0), TextSize = touch and 8 or 10, Color = C("Muted"), Role = "Heading" }) end
	local list = Instance.new("ScrollingFrame")
	list.Name = "LeaderboardRows"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(10, touch and 65 or 72)
	list.Size = UDim2.new(1, -20, 1, touch and -75 or -82)
	list.ScrollBarThickness = touch and 3 or 5
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = board
	local entries = type(globalResult.Entries) == "table" and globalResult.Entries or {}
	if globalResult.Ok == true and #entries > 0 then
		local rowH = touch and 28 or 34
		for index, entry in ipairs(entries) do
			local row = Instance.new("Frame")
			row.Name = "Rank" .. tostring(entry.Rank or index)
			row.BackgroundColor3 = tonumber(entry.UserId) == player.UserId and C("PanelBlue") or C("PanelSoft")
			row.BackgroundTransparency = tonumber(entry.UserId) == player.UserId and 0.35 or (index % 2 == 0 and 0.62 or 1)
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(0, (index - 1) * rowH)
			row.Size = UDim2.new(1, -6, 0, rowH)
			row.Parent = list
			local values = {
				{ tostring(entry.Rank or index), 0, 0.12, C("Text") },
				{ string.upper(tostring(entry.DisplayName or entry.Username or ("PLAYER " .. tostring(entry.UserId or "")))), 0.12, 0.43, tonumber(entry.UserId) == player.UserId and C("Telemetry") or C("Text") },
				{ string.upper(tostring(entry.VehicleName or entry.VehicleId or "--")), 0.55, 0.25, C("Muted") },
				{ timeText(entry.BestSeconds), 0.80, 0.20, C("Telemetry") },
			}
			for _, value in ipairs(values) do UI.Label(row, { Text = value[1], Position = UDim2.new(value[2], 6, 0, 0), Size = UDim2.new(value[3], -12, 1, 0), TextSize = touch and 8 or 10, Color = value[4], Role = "Heading" }) end
		end
	else
		UI.Label(list, { Text = globalResult.Ok == true and "NO GLOBAL RECORDS YET" or "GLOBAL RANKINGS UNAVAILABLE\n\nYour personal record is still shown on the left.", Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 1, -40), TextSize = touch and 10 or 13, Color = C("Muted"), Role = "Heading", Wrapped = true, XAlignment = Enum.TextXAlignment.Center })
	end

	local footerTextSize = touch and 9 or 13
	local back = UI.Button(footer, { Text = "BACK", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), StrokeColor = C("Outline"), TextSize = footerTextSize })
	local chooseText = ownedTiers[selectedTier] and "CHOOSE VEHICLE" or ("OWN A " .. selectedTier .. " CLASS VEHICLE TO ENTER")
	local choose = UI.Button(footer, { Text = chooseText, Position = UDim2.new(0.5, gap / 2, 0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), Color = C("PanelBlue"), StrokeColor = C("Telemetry"), FocusColor = C("Telemetry"), TextColor = ownedTiers[selectedTier] and C("Text") or C("Disabled"), TextSize = footerTextSize })
	choose.Active = ownedTiers[selectedTier] == true
	back.MouseButton1Click:Connect(function() currentPage = "Setup" render() end)
	choose.MouseButton1Click:Connect(function()
		if not ownedTiers[selectedTier] then return end
		selectedVehicleId = ""
		vehicleCategory = "ALL"
		currentPage = "Vehicles"
		render()
	end)
end

local function renderVehiclePage()
	local gap = touch and 10 or L("Gap", 16)
	local allRows = racingVehicleRows()
	local categories, seen = { "ALL" }, { ALL = true }
	for _, row in ipairs(allRows) do if not seen[row.Category] then seen[row.Category] = true table.insert(categories, row.Category) end end
	table.sort(categories, function(a, b) if a == b then return false elseif a == "ALL" then return true elseif b == "ALL" then return false end return a < b end)
	if not seen[vehicleCategory] then vehicleCategory = "ALL" end
	local rows = {}
	for _, row in ipairs(allRows) do if vehicleCategory == "ALL" or row.Category == vehicleCategory then table.insert(rows, row) end end
	local selectedExists = false
	for _, row in ipairs(rows) do if row.VehicleId == selectedVehicleId then selectedExists = true break end end
	if not selectedExists then selectedVehicleId = rows[1] and rows[1].VehicleId or "" end

	local contextH = touch and 36 or 44
	local context = UI.Panel(content, { Name = "VehicleContext", Size = UDim2.new(1, 0, 0, contextH), Color = C("Panel"), Transparency = 0.05, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	UI.Label(context, { Text = selectedMode == "Race" and "OPEN CATEGORY" or (selectedTier .. " CLASS VEHICLES"), Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.34, 0, 1, 0), TextSize = touch and 10 or 14, Color = C("Telemetry"), Role = "Heading" })
	UI.Label(context, { Text = string.upper(tostring(summary.DisplayName or "RACE EVENT")) .. "  •  " .. tostring(selectedLap) .. (selectedLap == 1 and " LAP" or " LAPS"), Position = UDim2.new(0.34, 0, 0, 0), Size = UDim2.new(0.66, -14, 1, 0), TextSize = touch and 8 or 11, Color = C("Muted"), Role = "Heading", XAlignment = Enum.TextXAlignment.Right })

	local filterY = contextH + gap
	local filterH = touch and 48 or 60
	local filterBar = Instance.new("Frame") filterBar.BackgroundTransparency = 1 filterBar.Position = UDim2.fromOffset(0, filterY) filterBar.Size = UDim2.new(1, 0, 0, filterH) filterBar.Parent = content
	local function dropdown(name, labelText, options, current, xScale, callback)
		local holder = Instance.new("Frame") holder.Name = name holder.BackgroundTransparency = 1 holder.Position = UDim2.new(xScale, xScale == 0 and 0 or gap / 2, 0, 0) holder.Size = UDim2.new(0.5, -gap / 2, 0, filterH) holder.ZIndex = 30 holder.Parent = filterBar
		local button = UI.Button(holder, { Text = "", Size = UDim2.fromScale(1, 1), StrokeColor = C("Outline"), FocusColor = C("Telemetry"), ZIndex = 31 })
		UI.Label(button, { Text = labelText, Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -24, 0, 20), TextSize = touch and 7 or 9, Color = C("Muted"), Role = "Heading" }).ZIndex = 34
		UI.Label(button, { Text = current .. "  ˅", Position = UDim2.fromOffset(12, touch and 18 or 22), Size = UDim2.new(1, -24, 1, touch and -20 or -24), TextSize = touch and 10 or 13, Color = C("Text"), Role = "Heading" }).ZIndex = 34
		local list
		button.MouseButton1Click:Connect(function()
			if list then list:Destroy() list = nil return end
			list = UI.Panel(holder, { Name = "Options", Position = UDim2.new(0, 0, 1, 4), Size = UDim2.fromOffset(holder.AbsoluteSize.X, #options * (touch and 32 or 38)), Color = C("PanelSoft"), Transparency = 0.02, NoStroke = true })
			list.ZIndex = 80
			for index, option in ipairs(options) do
				local optionButton = UI.Button(list, { Text = option, Position = UDim2.fromOffset(0, (index - 1) * (touch and 32 or 38)), Size = UDim2.new(1, 0, 0, touch and 32 or 38), Color = option == current and C("PanelBlue") or C("PanelSoft"), NoGlow = true, StrokeTransparency = 1, ZIndex = 82, TextSize = touch and 9 or 11 })
				optionButton.MouseButton1Click:Connect(function() callback(option) end)
			end
		end)
	end
	dropdown("Category", "CATEGORY", categories, vehicleCategory, 0, function(value) vehicleCategory = value selectedVehicleId = "" render() end)
	dropdown("Sort", "SORT BY", { "RATING", "NAME", "CLASS" }, vehicleSort, 0.5, function(value) vehicleSort = value selectedVehicleId = "" render() end)

	local gridY = filterY + filterH + gap
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "VehicleGrid" grid.BackgroundTransparency = 1 grid.BorderSizePixel = 0 grid.Position = UDim2.fromOffset(0, gridY) grid.Size = UDim2.new(1, 0, 1, -gridY) grid.ScrollBarThickness = touch and 3 or 6 grid.AutomaticCanvasSize = Enum.AutomaticSize.Y grid.CanvasSize = UDim2.fromOffset(0, 0) grid.Parent = content
	local gridSafe = touch and 5 or 8 local gridPadding = Instance.new("UIPadding") gridPadding.Name = "CardEdgeSafePadding" gridPadding.PaddingTop = UDim.new(0, gridSafe) gridPadding.PaddingLeft = UDim.new(0, gridSafe) gridPadding.PaddingRight = UDim.new(0, gridSafe) gridPadding.PaddingBottom = UDim.new(0, gridSafe) gridPadding.Parent = grid -- NTR_RACING_UI_PHASE14_VEHICLE_GRID_SAFE_PADDING
	local layout = Instance.new("UIGridLayout") layout.CellPadding = UDim2.fromOffset(gap, gap) layout.CellSize = touch and UDim2.new(0.5, -gap / 2, 0, 150) or UDim2.new(0.25, -gap * 0.75, 0, 190) layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Parent = grid
	if #rows == 0 then UI.Label(grid, { Text = selectedMode == "Race" and "NO OWNED VEHICLES" or ("NO OWNED " .. selectedTier .. " CLASS VEHICLES"), Size = UDim2.fromOffset(500, 50), TextSize = touch and 11 or 15, Color = C("Muted"), Role = "Heading" }) end
	for index, row in ipairs(rows) do
		local selected = row.VehicleId == selectedVehicleId
		local card = UI.Button(grid, { Name = "Vehicle_" .. row.VehicleId, Text = "", Color = selected and C("PanelBlue") or C("PanelDeep"), StrokeColor = selected and C("Telemetry") or C("Outline"), FocusColor = C("Telemetry"), StrokeTransparency = selected and 0.02 or 0.18 })
		card.LayoutOrder = index
		local image = Instance.new("ImageLabel") image.BackgroundTransparency = 1 image.Position = UDim2.fromOffset(8, 8) image.Size = UDim2.new(1, -16, 1, touch and -48 or -56) image.Image = asset(row.Image) image.ScaleType = Enum.ScaleType.Fit image.ZIndex = card.ZIndex + 2 image.Parent = card
		local badge = UI.Panel(card, { Position = UDim2.new(1, touch and -76 or -92, 0, 10), Size = UDim2.fromOffset(touch and 66 or 80, touch and 22 or 26), Color = tierColors[row.Tier] or C("PanelSoft"), Transparency = 0.12, StrokeColor = tierColors[row.Tier] or C("Outline"), StrokeTransparency = 0.15 }) badge.ZIndex = card.ZIndex + 4
		UI.Label(badge, { Text = row.Tier .. "  " .. tostring(math.floor(row.Rating)), Size = UDim2.fromScale(1, 1), TextSize = touch and 8 or 10, Color = C("Text"), Role = "Heading", XAlignment = Enum.TextXAlignment.Center }).ZIndex = badge.ZIndex + 1
		UI.Label(card, { Text = string.upper(row.Name), Position = UDim2.new(0, 10, 1, touch and -40 or -48), Size = UDim2.new(1, -20, 0, touch and 32 or 40), TextSize = touch and 9 or 12, Color = C("Text"), Role = "Heading", XAlignment = Enum.TextXAlignment.Center }).ZIndex = card.ZIndex + 3
		card.MouseButton1Click:Connect(function() selectedVehicleId = row.VehicleId render() end)
	end

	local footerTextSize = touch and 9 or 13
	local back = UI.Button(footer, { Text = "BACK", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), StrokeColor = C("Outline"), TextSize = footerTextSize })
	local actionText = selectedMode == "Race" and "JOIN RACE" or "START TIME TRIAL"
	local start = UI.Button(footer, { Text = selectedVehicleId ~= "" and actionText or "SELECT A VEHICLE", Position = UDim2.new(0.5, gap / 2, 0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), Color = C("PanelBlue"), StrokeColor = C("Telemetry"), FocusColor = C("Telemetry"), TextColor = selectedVehicleId ~= "" and C("Text") or C("Disabled"), TextSize = footerTextSize })
	start.Active = selectedVehicleId ~= ""
	back.MouseButton1Click:Connect(function() currentPage = selectedMode == "Race" and "Setup" or "Records" render() end)
	start.MouseButton1Click:Connect(function()
		if selectedVehicleId == "" then return end
		player:SetAttribute("NTR_LastRacingVehicleId", selectedVehicleId)
		player:SetAttribute("NTR_LastRacingEventId", pairedEventId(selectedMode))
		player:SetAttribute("NTR_LastRacingMode", selectedMode)
		player:SetAttribute("NTR_LastRacingLapCount", selectedLap)
		setOpen(false)
		legacyAction:Fire("StartSelectedVehicle", { Mode = selectedMode, EventId = pairedEventId(selectedMode), VehicleId = selectedVehicleId, Tier = selectedTier, LapCount = selectedLap })
	end)
end

local function renderSetup()
	clear(content)
	clear(footer)
	if currentPage == "Records" then
		renderRecordsPage()
		return
	end
	if currentPage == "Vehicles" then
		renderVehiclePage()
		return
	end
	if selectedMode == "Race" then
		renderRaceSetup()
		return
	end
	local gap = touch and 10 or L("Gap", 16)
	local tierRail = Instance.new("Frame")
	tierRail.BackgroundTransparency = 1
	tierRail.Size = UDim2.new(1, 0, 0, touch and 42 or 52)
	tierRail.Parent = content
	renderTierRail(tierRail)

	local bodyY = touch and 52 or 68
	local columnWidth = 0.5
	local leftColumn = Instance.new("Frame")
	leftColumn.Name = "TimeTrialMapColumn"
	leftColumn.BackgroundTransparency = 1
	leftColumn.Position = UDim2.fromOffset(0, bodyY)
	leftColumn.Size = UDim2.new(columnWidth, -gap / 2, 1, -bodyY)
	leftColumn.Parent = content
	local map = imagePanel(leftColumn, browserMedia("MapImage"), "TRACK MAP", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	map.Name = "TrackMap"
	mapTitleOverlay(map, "TIME TRIAL", string.upper(tostring(summary.DisplayName or "TIME TRIAL")))
	local lapPanel = UI.Panel(leftColumn, { Name = "LapSelector", Position = UDim2.new(0.19, 0, 1, touch and -72 or -100), Size = UDim2.new(0.62, 0, 0, touch and 62 or 84), Color = C("PanelDeep"), Transparency = 0.16, StrokeColor = C("Telemetry"), StrokeTransparency = 0.35 })
	lapPanel.ZIndex = map.ZIndex + 5
	gradient(lapPanel)
	local controlWidth = touch and 250 or 320
	local controlHeight = touch and 38 or 44
	local controlGap = touch and 10 or 16
	local buttonSize = touch and 38 or 44
	local controls = Instance.new("Frame")
	controls.Name = "LapControlRow"
	controls.AnchorPoint = Vector2.new(0.5, 0.5)
	controls.BackgroundTransparency = 1
	controls.Position = UDim2.fromScale(0.5, 0.5)
	controls.Size = UDim2.fromOffset(controlWidth, controlHeight)
	controls.ZIndex = lapPanel.ZIndex + 2
	controls.Parent = lapPanel
	local textWidth = controlWidth - buttonSize * 2 - controlGap * 2
	local minus = UI.Button(controls, { Text = "−", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(buttonSize, buttonSize), StrokeColor = C("Outline") })
	local lapText = UI.Label(controls, { Text = tostring(selectedLap) .. (selectedLap == 1 and " LAP" or " LAPS"), Position = UDim2.fromOffset(buttonSize + controlGap, 0), Size = UDim2.fromOffset(textWidth, controlHeight), TextSize = touch and 14 or 22, Color = C("Telemetry"), Role = "Metric", XAlignment = Enum.TextXAlignment.Center })
	lapText.ZIndex = controls.ZIndex + 2
	local plus = UI.Button(controls, { Text = "+", Position = UDim2.fromOffset(buttonSize + controlGap + textWidth + controlGap, 0), Size = UDim2.fromOffset(buttonSize, buttonSize), StrokeColor = C("Outline") })
	local minLap, maxLap = lapBounds()
	minus.MouseButton1Click:Connect(function() selectedLap = math.max(minLap, selectedLap - 1) lapText.Text = tostring(selectedLap) .. (selectedLap == 1 and " LAP" or " LAPS") end)
	plus.MouseButton1Click:Connect(function() selectedLap = math.min(maxLap, selectedLap + 1) lapText.Text = tostring(selectedLap) .. (selectedLap == 1 and " LAP" or " LAPS") end)

	local right = Instance.new("Frame")
	right.Name = "TimeTrialRightColumn"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(columnWidth, gap / 2, 0, bodyY)
	right.Size = UDim2.new(columnWidth, -gap / 2, 1, -bodyY)
	right.Parent = content
	local summaryHeight = touch and 88 or 112
	local summaryPanel = UI.Panel(right, { Name = "PrizeSummary", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, summaryHeight), Color = C("PanelDeep"), Transparency = 0.06, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	local summaryInset = touch and 10 or 15
	local summaryItemHeight = touch and 54 or 82
	local tierBadge = UI.Panel(summaryPanel, { Position = UDim2.fromOffset(summaryInset, summaryInset), Size = UDim2.fromOffset(touch and 54 or 82, summaryItemHeight), Color = tierColors[selectedTier], Transparency = 0.12, StrokeColor = tierColors[selectedTier], StrokeTransparency = 0.05 })
	UI.Label(tierBadge, { Text = selectedTier, Size = UDim2.fromScale(1, 1), TextSize = touch and 24 or 34, Role = "Metric", XAlignment = Enum.TextXAlignment.Center })
	local bonusWidth = touch and 82 or 104
	local prizeLeft = touch and 76 or 108
	local prizeWidthOffset = -(prizeLeft + bonusWidth)
	UI.Label(summaryPanel, { Text = selectedMode == "TimeTrial" and "PLATINUM PRIZE" or "RACE PRIZE", Position = UDim2.fromOffset(prizeLeft, touch and 10 or 18), Size = UDim2.new(1, prizeWidthOffset, 0, 24), TextSize = touch and 9 or 13, Color = C("Text"), Role = "Heading", XAlignment = Enum.TextXAlignment.Center })
	UI.Label(summaryPanel, { Text = money(summary.BaseReward or 0), Position = UDim2.fromOffset(prizeLeft, touch and 34 or 46), Size = UDim2.new(1, prizeWidthOffset, 0, touch and 28 or 44), TextSize = touch and 14 or 27, Color = C("Telemetry"), Role = "Metric", XAlignment = Enum.TextXAlignment.Center })
	local bonus = UI.Panel(summaryPanel, { Name = "DailyBonus", Position = UDim2.new(1, -(bonusWidth + summaryInset), 0, summaryInset), Size = UDim2.fromOffset(bonusWidth, summaryItemHeight), Color = C("PanelSoft"), Transparency = 0.08, StrokeColor = C("Telemetry"), StrokeTransparency = 0.48 })
	UI.Label(bonus, { Text = "DAILY BONUS", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 20), TextSize = touch and 7 or 9, Color = C("Muted"), Role = "Heading", XAlignment = Enum.TextXAlignment.Center })
	UI.Label(bonus, { Text = copyValue("DailyBonusDisplay", "2X"), Position = UDim2.fromOffset(4, touch and 21 or 24), Size = UDim2.new(1, -8, 1, touch and -25 or -28), TextSize = touch and 14 or 22, Color = C("Telemetry"), Role = "Metric", XAlignment = Enum.TextXAlignment.Center })

	local eventId = pairedEventId("TimeTrial")
	local medals = RaceConfigReader.GetTimeTrialMedals(eventId, selectedTier) or {}
	local pb = call(raceRequest, "GetTimeTrialPersonalBest", { EventId = eventId, VehicleTier = selectedTier })
	local pbSeconds = tonumber(pb.BestSeconds or (pb.Record and pb.Record.BestSeconds))
	local pbMedal = tostring(pb.BestMedal or (pb.Record and pb.Record.BestMedal) or "--")
	local pbVehicleId = tostring(pb.BestVehicleId or (pb.Record and pb.Record.BestVehicleId) or "")
	local _, pbVehicleName = vehiclePresentationForId(pbVehicleId)
	local pbY = summaryHeight + gap
	local pbHeight = touch and 90 or 112
	local pbPanel = UI.Panel(right, { Name = "PersonalBest", Position = UDim2.fromOffset(0, pbY), Size = UDim2.new(1, 0, 0, pbHeight), Color = C("PanelDeep"), Transparency = 0.08, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	local zone = 0.34
	local pbMedalSize = touch and 62 or 80
	if pbSeconds and medalCells[pbMedal] then
		medalIcon(pbPanel, pbMedal, UDim2.new(zone * 0.5, -pbMedalSize / 2, 0, touch and 2 or 0), UDim2.fromOffset(pbMedalSize, pbMedalSize))
	end
	local captionY = touch and 68 or 86
	local captionSize = touch and 8 or 12
	UI.Label(pbPanel, { Text = string.upper(pbSeconds and pbMedal or "--"), Position = UDim2.new(0, 4, 0, captionY), Size = UDim2.new(zone, -8, 0, 22), TextSize = captionSize, Color = C("Text"), Role = "Heading", XAlignment = Enum.TextXAlignment.Center })
	UI.Label(pbPanel, { Text = pbSeconds and timeText(pbSeconds) or "--:--.---", Position = UDim2.new(zone, 4, 0, touch and 20 or 28), Size = UDim2.new(1 - zone, -8, 0, touch and 40 or 48), TextSize = touch and 17 or 26, Color = C("Telemetry"), Role = "Metric", XAlignment = Enum.TextXAlignment.Center })
	UI.Label(pbPanel, { Text = "YOUR BEST  •  " .. string.upper(pbSeconds and pbVehicleName or "NO VEHICLE RECORD"), Position = UDim2.new(zone, 4, 0, captionY), Size = UDim2.new(1 - zone, -8, 0, 22), TextSize = captionSize, Color = C("Text"), Role = "Heading", XAlignment = Enum.TextXAlignment.Center })

	local targetsY = pbY + pbHeight + gap
	local targets = UI.Panel(right, { Name = "MedalTargets", Position = UDim2.fromOffset(0, targetsY), Size = UDim2.new(1, 0, 1, -targetsY), Color = C("PanelDeep"), Transparency = 0.08, StrokeColor = C("Outline"), StrokeTransparency = 0.18 })
	local names = { "Platinum", "Gold", "Silver", "Bronze" }
	for index, name in ipairs(names) do
		local row = Instance.new("Frame")
		row.Name = name .. "Target"
		row.BackgroundColor3 = C("PanelSoft")
		row.BackgroundTransparency = index % 2 == 0 and 0.56 or 1
		row.BorderSizePixel = 0
		row.Position = UDim2.new(0, 8, (index - 1) * 0.25, 0)
		row.Size = UDim2.new(1, -16, 0.25, 0)
		row.Parent = targets
		local iconSize = touch and 28 or 36
		local icon = medalIcon(row, name, UDim2.new(0, 8, 0.5, 0), UDim2.fromOffset(iconSize, iconSize))
		if icon then icon.AnchorPoint = Vector2.new(0, 0.5) end
		local nameColor = name == "Gold" and Color3.fromRGB(255, 205, 55) or name == "Bronze" and Color3.fromRGB(220, 132, 75) or C("Text")
		UI.Label(row, { Text = string.upper(name), Position = UDim2.fromOffset(touch and 44 or 54, 0), Size = UDim2.new(0.46, 0, 1, 0), TextSize = touch and 10 or 14, Color = nameColor, Role = "Heading" })
		UI.Label(row, { Text = timeText(medals[name]), Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.45, -12, 1, 0), TextSize = touch and 11 or 15, Color = C("Text"), Role = "Metric", XAlignment = Enum.TextXAlignment.Right })
	end

	local footerTextSize = touch and 9 or 13
	local exit = UI.Button(footer, { Text = "EXIT", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), StrokeColor = C("Outline"), TextSize = footerTextSize })
	local chooseText = ownedTiers[selectedTier] and "NEXT" or ("OWN A " .. selectedTier .. " CLASS VEHICLE TO ENTER")
	local choose = UI.Button(footer, { Text = chooseText, Position = UDim2.new(0.5, gap / 2, 0, 0), Size = UDim2.new(0.5, -gap / 2, 1, 0), Color = C("PanelBlue"), StrokeColor = C("Telemetry"), FocusColor = C("Telemetry"), TextColor = ownedTiers[selectedTier] and C("Text") or C("Disabled"), TextSize = footerTextSize })
	choose.Active = ownedTiers[selectedTier] == true
	exit.MouseButton1Click:Connect(function() setOpen(false) legacyAction:Fire("Close") end)
	choose.MouseButton1Click:Connect(function()
		if not ownedTiers[selectedTier] then return end
		currentPage = "Records"
		render()
	end)
end

function render()
	if not summary then return end
	if headerTitle then
		headerTitle.Text = currentPage == "Vehicles" and (selectedMode == "Race" and "CHOOSE RACE VEHICLE" or "CHOOSE TIME TRIAL VEHICLE") or string.upper(tostring(summary.DisplayName or "RACE ENTRY"))
	end
	updateTabs()
	renderSetup()
end

local function buildGui()
	local old = playerGui:FindFirstChild("NTR_RaceEntryPresentation")
	if old then old:Destroy() end
	gui = Instance.new("ScreenGui")
	gui.Name = "NTR_RaceEntryPresentation"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 180
	gui.Parent = playerGui
	overlay = Instance.new("Frame")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.38
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.Parent = gui
	shell = UI.Panel(overlay, { Color = C("PanelDeep"), Transparency = L("PanelTransparency", 0.08), StrokeColor = C("Outline"), StrokeWidth = L("ShellStrokeWidth", 2), StrokeTransparency = 0.02, Clips = true })
	shell.AnchorPoint = Vector2.new(0.5, 0.5)
	shell.Position = UDim2.fromScale(0.5, 0.5)
	shell.Size = touch and UDim2.new(1, -16, 1, -16) or UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))
	if not touch then
		UI.AttachResponsiveScale(shell)
	end
	local headerH = touch and 44 or L("HeaderHeight", 64)
	headerTitle = UI.Label(shell, { Text = "RACE ENTRY", Position = UDim2.fromOffset(touch and 12 or 24, 0), Size = UDim2.new(0.35, 0, 0, headerH), TextSize = touch and 14 or T("Heading", 22), Role = "Heading" })
	local tabWidth = touch and 116 or 160
	local tabGap = touch and 10 or L("Gap", 16)
	timeTrialTab = UI.Button(shell, { Text = "TIME TRIAL", Position = UDim2.new(0.5, -(tabWidth + tabGap / 2), 0, touch and 5 or 8), Size = UDim2.fromOffset(tabWidth, headerH - (touch and 10 or 16)), Color = C("PanelSoft"), StrokeColor = C("Outline"), FocusColor = C("Telemetry") })
	raceTab = UI.Button(shell, { Text = "RACE", Position = UDim2.new(0.5, tabGap / 2, 0, touch and 5 or 8), Size = UDim2.fromOffset(tabWidth, headerH - (touch and 10 or 16)), Color = C("PanelSoft"), StrokeColor = C("Outline"), FocusColor = C("Telemetry") })
	-- RacingUIComponents.Button intentionally restores its construction colour
	-- after hover. Reassert only the currently selected tab after that shared
	-- callback runs, keeping unrelated button hover behaviour unchanged.
	local function preserveSelectedTab(button, mode)
		local function refreshAfterSharedHover()
			if selectedMode == mode then task.defer(updateTabs) end
		end
		button.MouseEnter:Connect(refreshAfterSharedHover)
		button.MouseLeave:Connect(refreshAfterSharedHover)
	end
	preserveSelectedTab(timeTrialTab, "TimeTrial")
	preserveSelectedTab(raceTab, "Race")
	timeTrialTab.MouseButton1Click:Connect(function() selectedMode = "TimeTrial" currentPage = "Setup" render() end)
	raceTab.MouseButton1Click:Connect(function() selectedMode = "Race" currentPage = "Setup" render() end)
	local close = UI.Button(shell, { Text = "×", Position = UDim2.new(1, touch and -48 or -64, 0, 0), Size = UDim2.fromOffset(touch and 48 or 64, headerH), Color = C("PanelDeep"), StrokeColor = C("Danger"), FocusColor = C("Danger"), TextColor = C("Danger"), TextSize = touch and 24 or 30, StrokeTransparency = 1 })
	close.MouseButton1Click:Connect(function() setOpen(false) legacyAction:Fire("Close") end)
	local divider = Instance.new("Frame") divider.BorderSizePixel = 0 divider.BackgroundColor3 = C("Outline") divider.BackgroundTransparency = 0.5 divider.Position = UDim2.fromOffset(0, headerH) divider.Size = UDim2.new(1, 0, 0, 1) divider.Parent = shell
	local pad = touch and 12 or L("OuterPadding", 24)
	local footerH = touch and 40 or 48
	local contentFooterGap = touch and 10 or L("Gap", 16)
	content = Instance.new("Frame") content.BackgroundTransparency = 1 content.Position = UDim2.fromOffset(pad, headerH + pad) content.Size = UDim2.new(1, -pad * 2, 1, -(headerH + pad * 2 + footerH + contentFooterGap)) content.Parent = shell
	footer = Instance.new("Frame") footer.BackgroundTransparency = 1 footer.Position = UDim2.new(0, pad, 1, -(pad + footerH)) footer.Size = UDim2.new(1, -pad * 2, 0, footerH) footer.Parent = shell
end

requestEvent.Event:Connect(function(entryPayload)
	payload = entryPayload or {}
	summary = payload.Summary or {}
	-- Entry always begins on the primary Time Trial page; Race remains one tab away.
	selectedMode = "TimeTrial"
	currentPage = "Setup"
	local minLap, maxLap = lapBounds()
	selectedLap = math.clamp(math.floor(tonumber(summary.DefaultLapCount or summary.Laps) or 1), minLap, maxLap)
	-- Hide every background interface before profile/PB server lookups can yield.
	setOpen(true)
	readOwnedTiers()
	render()
end)

buildGui()
print("[NTR Racing UI Phase 2] Time Trial startup presentation active.")
]====]
end

local function paths()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local racing = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing")
	return kit, racing
end

local OPEN_BRIDGE = [==[
	-- NTR_RACING_UI_PHASE2_ENTRY_PRESENTATION_BRIDGE
	local presentationRequest = script.Parent:FindFirstChild("RaceEntryPresentationRequest")
	if presentationRequest and presentationRequest:IsA("BindableEvent") then
		setOpen(false)
		gui.Enabled = false -- NTR_RACING_UI_PHASE2_V3_LEGACY_GUI_SUPPRESSION
		presentationRequest:Fire(payload)
		return
	end
]==]

local ACTION_BRIDGE = [==[
-- NTR_RACING_UI_PHASE2_ENTRY_ACTION_BRIDGE
local presentationAction = script.Parent:FindFirstChild("RaceEntryLegacyAction")
if presentationAction and presentationAction:IsA("BindableEvent") then
	presentationAction.Event:Connect(function(action, data)
		data = type(data) == "table" and data or {}
		if action == "ChooseVehicle" then
			gui.Enabled = true
			state.SelectedLapCount = tonumber(data.LapCount) or state.SelectedLapCount or 1
			showVehicleSelect(tostring(data.Mode) == "Race" and "Race" or "TimeTrial")
			setOpen(true)
		elseif action == "StartSelectedVehicle" then
			-- NTR_RACING_UI_PHASE2_V10_DIRECT_START_BRIDGE
			local mode = tostring(data.Mode) == "Race" and "Race" or "TimeTrial"
			local selected
			for _, row in ipairs(ownedRows()) do if tostring(row.VehicleId) == tostring(data.VehicleId or "") then selected = row break end end
			if not selected then warn("[NTR Racing UI V10] Selected vehicle is no longer owned.") return end
			state.SelectedRow = selected
			state.SelectedLapCount = tonumber(data.LapCount) or state.SelectedLapCount or 1
			local spawn = callGarage("SpawnOwnedVehicleFromFreeRoam", { VehicleId = selected.VehicleId, CockpitId = selected.CockpitId })
			if spawn.Success ~= true and spawn.Ok ~= true then
				local selectResult = callGarage("SelectVehicleInstance", { VehicleId = selected.VehicleId, CockpitId = selected.CockpitId })
				if selectResult.Success ~= true and selectResult.Ok ~= true then warn("[NTR Racing UI V10] " .. tostring(selectResult.Message or spawn.Message or "Vehicle selection failed.")) return end
				spawn = callGarage("SpawnVehicle", {})
				if spawn.Success ~= true and spawn.Ok ~= true then warn("[NTR Racing UI V10] " .. tostring(spawn.Message or "Vehicle spawn failed.")) return end
			end
			local clientRoot = script.Parent.Parent
			local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
			local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
			if spawnedEvent and spawnedEvent:IsA("BindableEvent") then spawnedEvent:Fire() end
			task.wait(0.35)
			if mode == "Race" then
				startRaceQueueEvent:Fire({ EventId = tostring(data.EventId or (state.Entry and state.Entry.EventId) or "shifted_canal_sprint_race"), VehicleId = selected.VehicleId, CockpitId = selected.CockpitId, DisplayName = state.Entry and state.Entry.Summary and state.Entry.Summary.DisplayName })
			else
				local result = callRace("StartStagedTimeTrial", { EventId = tostring(data.EventId or timeTrialEventIdForStart()), VehicleId = selected.VehicleId, LapCount = state.SelectedLapCount })
				if result.Ok ~= true and result.Success ~= true then warn("[NTR Racing UI V10] " .. tostring(result.Message or "Time trial start failed.")) return end
			end
			setOpen(false)
		elseif action == "Close" then
			gui.Enabled = true
			setOpen(false)
		end
	end)
end

]==]

local function insertBeforePlain(source, anchor, insertion, label)
	local first = string.find(source, anchor, 1, true)
	assert(first, "Could not find " .. label .. " anchor in the refreshed entry source")
	local second = string.find(source, anchor, first + #anchor, true)
	assert(not second, "Found more than one " .. label .. " anchor; stop and inspect the refreshed mirror")
	return string.sub(source, 1, first - 1) .. insertion .. string.sub(source, first)
end

local function replacePlainUnique(source, oldText, newText, label)
	local first = string.find(source, oldText, 1, true)
	assert(first, "Could not find " .. label .. " repair anchor in the installed entry bridge")
	local second = string.find(source, oldText, first + #oldText, true)
	assert(not second, "Found more than one " .. label .. " repair anchor; stop and inspect the refreshed mirror")
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local function patchedLegacySource(source)
	if string.find(source, "NTR_RACING_UI_PHASE2_ENTRY_PRESENTATION_BRIDGE", 1, true) then
		if not string.find(source, "NTR_RACING_UI_PHASE2_V3_LEGACY_GUI_SUPPRESSION", 1, true) then
			source = replacePlainUnique(
				source,
				'\t\tsetOpen(false)\n\t\tpresentationRequest:Fire(payload)\n',
				'\t\tsetOpen(false)\n\t\tgui.Enabled = false -- NTR_RACING_UI_PHASE2_V3_LEGACY_GUI_SUPPRESSION\n\t\tpresentationRequest:Fire(payload)\n',
				"legacy GUI suppression"
			)
			source = replacePlainUnique(source, '\t\tif action == "ChooseVehicle" then\n', '\t\tif action == "ChooseVehicle" then\n\t\t\tgui.Enabled = true\n', "choose-vehicle GUI restore")
			 source = replacePlainUnique(source, '\t\telseif action == "Close" then\n', '\t\telseif action == "Close" then\n\t\t\tgui.Enabled = true\n', "close GUI restore")
		end
		if not string.find(source, "NTR_RACING_UI_PHASE2_V10_DIRECT_START_BRIDGE", 1, true) then
			local startAt = assert(string.find(ACTION_BRIDGE, '\t\telseif action == "StartSelectedVehicle" then\n', 1, true), "V10 action template start missing")
			local closeAt = assert(string.find(ACTION_BRIDGE, '\t\telseif action == "Close" then\n', startAt, true), "V10 action template end missing")
			local insertion = string.sub(ACTION_BRIDGE, startAt, closeAt - 1)
			source = replacePlainUnique(source, '\t\telseif action == "Close" then\n\t\t\tgui.Enabled = true\n', insertion .. '\t\telseif action == "Close" then\n\t\t\tgui.Enabled = true\n', "V10 direct-start bridge")
		end
		return source
	end
	assert(string.find(source, "NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF", 1, true), "Confirmed Phase 11Q entry marker missing")
	assert(string.find(source, "NTR_RACING_PHASE11L_ENTRY_MENU_LEGACY_VIS_DISABLED", 1, true), "Confirmed Phase 11L entry marker missing")
	local openAnchor = '\ttitle.Text = tostring(summary.DisplayName or "RACE MENU")\n'
	source = insertBeforePlain(source, openAnchor, OPEN_BRIDGE, "entry presentation")
	local actionAnchor = 'local hudGui = Instance.new("ScreenGui")\n'
	source = insertBeforePlain(source, actionAnchor, ACTION_BRIDGE, "entry action")
	return source
end

local SHARED_SCALE_FUNCTION = [==[
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

]==]

local OLD_BROWSER_SCALE = [==[
	local shellScale
	if touch then
		shell.Size = UDim2.new(1, -16, 1, -16)
	else
		shell.Size = UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))
		shellScale = Instance.new("UIScale")
		shellScale.Parent = shell
		local camera = workspace.CurrentCamera
		local function resize()
			local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
			local scale = math.min((viewport.X - 48) / L("ShellWidth", 1200), (viewport.Y - 48) / L("ShellHeight", 720))
			shellScale.Scale = math.clamp(scale, L("ScaleMin", 0.72), L("ScaleMax", 1.15))
		end
		resize()
		if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	end
]==]

local NEW_BROWSER_SCALE = [==[
	-- NTR_RACING_UI_BROWSER_SHARED_RESPONSIVE_SCALE_V1
	if touch then
		shell.Size = UDim2.new(1, -16, 1, -16)
	else
		shell.Size = UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))
		UI.AttachResponsiveScale(shell)
	end
]==]

local function installSharedResponsiveScale(kit, racing)
	local components = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents")
	if not string.find(components.Source, "NTR_RACING_UI_SHARED_RESPONSIVE_SCALE_V1", 1, true) then
		components.Source = insertBeforePlain(components.Source, "return Components\n", SHARED_SCALE_FUNCTION, "shared responsive-scale return")
	end
	local browser = racing:FindFirstChild("RaceBrowserClient_Active")
	assert(browser and browser:IsA("LocalScript"), "RaceBrowserClient_Active missing")
	if not string.find(browser.Source, "NTR_RACING_UI_BROWSER_SHARED_RESPONSIVE_SCALE_V1", 1, true) then
		browser.Source = replacePlainUnique(browser.Source, OLD_BROWSER_SCALE, NEW_BROWSER_SCALE, "Race Browser responsive scale")
	end
end

local function installConfig(kit)
	local racingUI = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing")
	local assets = racingUI:WaitForChild("Assets")
	local layout = racingUI:WaitForChild("Layout")
	local copy = ensure(racingUI, "Folder", "Copy")
	ensureValue(assets, "StringValue", "MedalAtlas", "")
	local size = ensureValue(assets, "NumberValue", "MedalAtlasSize", 1024) size.Value = 1024
	local cell = ensureValue(assets, "NumberValue", "MedalAtlasCellSize", 512) cell.Value = 512
	ensureValue(copy, "StringValue", "DailyBonusDisplay", "2X")
	ensureValue(layout, "NumberValue", "DesktopEdgeBufferXRatio", 0.10)
	ensureValue(layout, "NumberValue", "DesktopEdgeBufferYRatio", 0.08)
	ensureValue(layout, "NumberValue", "ResponsiveScaleMin", 0.55)
	local raceCatalog = kit.Config.Racing:FindFirstChild("RaceCatalog")
	for _, event in ipairs(raceCatalog and raceCatalog:GetChildren() or {}) do
		if event:GetAttribute("TrackLengthMiles") == nil then event:SetAttribute("TrackLengthMiles", 0) end
	end
end

local function smoke()
	local kit, racing = paths()
	local controller = racing:FindFirstChild("RaceEntryPresentationController_Active")
	assert(controller and controller:IsA("LocalScript") and controller.Enabled, "Presentation controller missing or disabled")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_TIME_TRIAL_STARTUP_PRESENTATION", 1, true), "Presentation marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V4_EQUAL_COLUMNS_COMPACT_TARGETS", 1, true), "V4 layout marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V5_PB_VEHICLE_BONUS_RESPONSIVE_BUFFER", 1, true), "V5 presentation marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V5_1_OPTIONAL_COPY_FALLBACK", 1, true), "V5.1 optional-copy marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V6_PB_TRIPTYCH_TIER_STATES_SHARED_SCALE", 1, true), "V6 presentation marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V7_RACE_FORMAT_PRIZES_RECORD", 1, true), "V7 Race presentation marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V7_1_PERSISTENT_SELECTED_TABS", 1, true), "V7.1 persistent-tab marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V8_MAP_HERO_VERTICAL_TARGETS", 1, true), "V8 map-hero marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V8_1_FLAT_COLUMNS_CENTERED_LAPS", 1, true), "V8.1 flat-column marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V9_RECORDS_NAVIGATION_POLISH", 1, true), "V9 records marker missing")
	assert(string.find(controller.Source, "NTR_RACING_UI_PHASE2_V10_RACING_VEHICLE_PICKER", 1, true), "V10 vehicle-picker marker missing")
	local components = kit.Shared.Modules.UI:FindFirstChild("RacingUIComponents")
	assert(components and string.find(components.Source, "NTR_RACING_UI_SHARED_RESPONSIVE_SCALE_V1", 1, true), "Shared responsive-scale helper missing")
	local browser = racing:FindFirstChild("RaceBrowserClient_Active")
	assert(browser and string.find(browser.Source, "NTR_RACING_UI_BROWSER_SHARED_RESPONSIVE_SCALE_V1", 1, true), "Race Browser shared-scale marker missing")
	local legacy = racing:FindFirstChild("RaceEntryMenuClient_Active")
	assert(legacy and string.find(legacy.Source, "NTR_RACING_UI_PHASE2_ENTRY_PRESENTATION_BRIDGE", 1, true), "Legacy presentation bridge missing")
	assert(string.find(legacy.Source, "NTR_RACING_UI_PHASE2_ENTRY_ACTION_BRIDGE", 1, true), "Legacy action bridge missing")
	assert(string.find(legacy.Source, "NTR_RACING_UI_PHASE2_V3_LEGACY_GUI_SUPPRESSION", 1, true), "Legacy GUI suppression marker missing")
	assert(string.find(legacy.Source, "NTR_RACING_UI_PHASE2_V10_DIRECT_START_BRIDGE", 1, true), "V10 direct-start bridge missing")
	assert(racing:FindFirstChild("RaceEntryPresentationRequest"), "Presentation request event missing")
	assert(racing:FindFirstChild("RaceEntryLegacyAction"), "Legacy action event missing")
	assert(kit.Config.UI.Racing.Assets:FindFirstChild("MedalAtlas"), "Medal atlas config missing")
	assert(kit.Config.UI.Racing:FindFirstChild("Copy"), "Racing UI Copy config missing")
	print("[" .. PHASE .. "] SMOKE PASS isolated presentation, verified legacy bridge, and medal config are present.")
end

local function install()
	local kit, racing = paths()
	installConfig(kit)
	installSharedResponsiveScale(kit, racing)
	ensure(racing, "BindableEvent", "RaceEntryPresentationRequest")
	ensure(racing, "BindableEvent", "RaceEntryLegacyAction")
	local legacy = racing:FindFirstChild("RaceEntryMenuClient_Active")
	assert(legacy and legacy:IsA("LocalScript"), "RaceEntryMenuClient_Active missing")
	local patched = patchedLegacySource(legacy.Source)
	local controller = ensure(racing, "LocalScript", "RaceEntryPresentationController_Active")
	controller.Source = controllerSource()
	controller.Enabled = true
	legacy.Source = patched
	legacy.Enabled = true
	print("[" .. PHASE .. "] INSTALL V10 complete. Read-only Records tier context and the racing vehicle picker are active.")
	smoke()
end

if MODE == "INSTALL" then install() elseif MODE == "SMOKE" then smoke() else error("Unknown MODE") end
