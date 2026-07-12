-- Neo Tokyo Racers - Racing Phase 3 Entry Menu, Vehicle Select, HUD
-- NTR_RACING_PHASE3_ENTRY_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local remotes = shared:WaitForChild("Remotes")
local racingRemotes = remotes:WaitForChild("Racing")
local raceRequest = racingRemotes:WaitForChild("RaceRequest")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local startRaceQueueEvent = script.Parent:WaitForChild("StartRaceQueueRequest")
-- NTR_RACING_PHASE8_ENTRY_QUEUE_PATCH
local garageInvoke = nil
local racingModules = shared:WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

print("[NTR Racing Phase 3 Client] booted " .. script:GetFullName())

local function getGarageInvoke()
	-- NTR_RACING_PHASE3C_CLIENT_EVENT_REPAIR
	if garageInvoke and garageInvoke.Parent then
		return garageInvoke
	end
	local garageRemotes = remotes:FindFirstChild("Garage") or remotes:WaitForChild("Garage", 5)
	if not garageRemotes then
		warn("[NTR Racing Phase 3 Client] Garage remotes missing; vehicle picker will wait until garage is ready.")
		return nil
	end
	garageInvoke = garageRemotes:FindFirstChild("GarageInvoke") or garageRemotes:WaitForChild("GarageInvoke", 5)
	if not garageInvoke then
		warn("[NTR Racing Phase 3 Client] GarageInvoke missing; vehicle picker cannot load yet.")
	end
	return garageInvoke
end

local touch = UserInputService.TouchEnabled
local state = {
	Entry = nil,
	Profile = nil,
	Catalog = nil,
	SelectedRow = nil,
	ActiveRun = nil,
	Visibility = nil,
	SelectedLapCount = nil,
}

local function themeFolder()
	local config = kit:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("Theme")
end

local function themeColor(name, fallback)
	local folder = themeFolder()
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("Color3Value") then
		return value.Value
	end
	return fallback
end

local theme = {
	Panel = themeColor("Panel", Color3.fromRGB(6, 10, 13)),
	Card = themeColor("Card", Color3.fromRGB(14, 20, 26)),
	CardHot = themeColor("CardHot", Color3.fromRGB(31, 52, 54)),
	Text = themeColor("Text", Color3.fromRGB(240, 255, 249)),
	Muted = themeColor("Muted", Color3.fromRGB(145, 170, 165)),
	Accent = themeColor("Accent", Color3.fromRGB(70, 255, 190)),
	Selected = themeColor("Selected", Color3.fromRGB(255, 68, 196)),
	Buy = themeColor("Buy", Color3.fromRGB(35, 200, 125)),
	Exit = themeColor("Exit", Color3.fromRGB(230, 74, 116)),
}

local function applyFont(label, bold)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 7)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or theme.Accent
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.25
	s.Parent = parent
	return s
end

local function label(parent, text, size, position, textSize, color, bold)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Text = text or ""
	item.TextColor3 = color or theme.Text
	item.TextSize = textSize or 13
	item.TextWrapped = true
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	applyFont(item, bold)
	item.Parent = parent
	return item
end

local function button(parent, text, size, position, color)
	local item = Instance.new("TextButton")
	item.AutoButtonColor = true
	item.BorderSizePixel = 0
	item.Size = size
	item.Position = position
	item.Text = text or ""
	item.TextColor3 = Color3.fromRGB(245, 255, 250)
	item.TextSize = touch and 11 or 13
	item.TextWrapped = true
	item.BackgroundColor3 = color or theme.Card
	applyFont(item, true)
	item.Parent = parent
	corner(item, 6)
	stroke(item, theme.Accent, 1, 0.45)
	return item
end

local function callGarage(action, payload)
	local invoke = getGarageInvoke()
	if not invoke then
		return { Success = false, Ok = false, Message = "Garage is still loading.", Error = "GarageInvoke missing" }
	end
	local ok, result = pcall(function()
		return invoke:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end

local function callRace(action, payload)
	local ok, result = pcall(function()
		return raceRequest:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
end

local function refreshProfile()
	local result = callGarage("GetInitial", {})
	state.Profile = result.Profile or result
	state.Catalog = result.Catalog or state.Catalog
	return state.Profile
end

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_RaceEntry"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 78
gui.Enabled = true
gui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.32
overlay.BorderSizePixel = 0
overlay.Size = UDim2.fromScale(1, 1)
overlay.Visible = false
overlay.Parent = gui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.52)
root.Size = touch and UDim2.new(0.94, 0, 0.76, 0) or UDim2.fromOffset(860, 560)
root.BackgroundColor3 = theme.Panel
root.BackgroundTransparency = 0.08
root.BorderSizePixel = 0
root.Visible = false
root.Parent = overlay
corner(root, 8)
stroke(root, theme.Accent, 1.5, 0.2)

local title = label(root, "RACE MENU", UDim2.new(1, -28, 0, 34), UDim2.fromOffset(14, 12), touch and 15 or 18, theme.Text, true)
local subtitle = label(root, "", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 45), touch and 10 or 12, theme.Muted, false)

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(14, 82)
content.Size = UDim2.new(1, -28, 1, -154)
content.Parent = root

local actionRail = Instance.new("Frame")
actionRail.Name = "ActionRail"
actionRail.BackgroundTransparency = 1
actionRail.Position = UDim2.new(0, 14, 1, -58)
actionRail.Size = UDim2.new(1, -28, 0, 44)
actionRail.Parent = root

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		child:Destroy()
	end
	for _, child in ipairs(actionRail:GetChildren()) do
		child:Destroy()
	end
end

local function setOpen(open)
	overlay.Visible = open
	root.Visible = open
end

local function statusText(text, good)
	subtitle.Text = text or ""
	subtitle.TextColor3 = good and theme.Accent or theme.Muted
end

local function tierColor(tier)
	tier = string.upper(tostring(tier or ""))
	if tier == "S" then return Color3.fromRGB(224, 78, 255) end
	if tier == "A" then return Color3.fromRGB(178, 92, 255) end
	if tier == "B" then return Color3.fromRGB(79, 139, 238) end
	if tier == "C" then return Color3.fromRGB(71, 195, 202) end
	if tier == "D" then return Color3.fromRGB(93, 202, 126) end
	if tier == "E" then return Color3.fromRGB(145, 162, 171) end
	return theme.Accent
end

local function cockpitIdForVehicle(profile, vehicle)
	if not vehicle then return "" end
	if vehicle.CockpitId then return tostring(vehicle.CockpitId) end
	local cockpitInstance = vehicle.CockpitInstanceId and profile and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	return cockpitInstance and tostring(cockpitInstance.TemplateId or "") or ""
end

local function catalogCockpit(cockpitId)
	for _, category in ipairs((state.Catalog and state.Catalog.Categories) or {}) do
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			if tostring(cockpit.CockpitId or cockpit.Id or "") == tostring(cockpitId) then
				return cockpit
			end
		end
	end
	return nil
end

local function cockpitName(cockpitId, cockpit)
	return tostring((cockpit and (cockpit.DisplayName or cockpit.Name)) or cockpitId or "Vehicle")
end

local function cockpitImage(cockpitId, cockpit)
	local image = cockpit and (cockpit.MenuImage or cockpit.Image or cockpit.Icon or cockpit.Thumbnail)
	if typeof(image) == "string" and image ~= "" then
		return image
	end
	local assets = kit:FindFirstChild("Assets")
	local vehicles = assets and assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	for _, category in ipairs(categories and categories:GetChildren() or {}) do
		local cockpitRoot = category:FindFirstChild("COCKPITS_ReplaceAssetsHere")
		for _, model in ipairs(cockpitRoot and cockpitRoot:GetChildren() or {}) do
			if model:IsA("Model") and (model.Name == cockpitId or tostring(model:GetAttribute("CockpitId") or "") == cockpitId) then
				local attr = model:GetAttribute("MenuImage")
				if typeof(attr) == "string" and attr ~= "" then return attr end
			end
		end
	end
	return ""
end

local function vehicleRatingParts(profile, vehicleId)
	local summary = profile and profile.VehicleSummaries and profile.VehicleSummaries[vehicleId]
	local overall = summary and summary.Overall or {}
	local tier = tostring(overall.Tier or "--")
	local index = tonumber(overall.PerformanceIndex)
	return tier, (index and tostring(math.floor(index)) or "---"), index or -math.huge
end

local function timeTrialEventIdForStart()
	-- NTR_RACING_PHASE3D_CLIENT_PAIRING
	local entry = state.Entry or {}
	local paired = tostring(entry.TimeTrialEventId or "")
	if paired ~= "" then
		return paired
	end
	local eventId = tostring(entry.EventId or "shifted_canal_sprint_tt")
	if eventId:sub(-5) == "_race" then
		return eventId:sub(1, -6) .. "_tt"
	end
	return eventId ~= "" and eventId or "shifted_canal_sprint_tt"
end


local function raceEventIdForStart()
	-- NTR_RACING_PHASE11B_RACE_EVENT_ID_PAIRING
	local entry = state.Entry or {}
	local paired = tostring(entry.RaceEventId or "")
	if paired ~= "" then
		return paired
	end
	local eventId = tostring(entry.EventId or "shifted_canal_sprint_race")
	if eventId:sub(-3) == "_tt" then
		return eventId:sub(1, -4) .. "_race"
	end
	return eventId ~= "" and eventId or "shifted_canal_sprint_race"
end

-- NTR_RACING_PHASE11N_PB_READOUT_CLIENT
local pbReadoutCache = {}

local function formatPBReadoutTime(seconds)
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return "--"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%06.3f", minutes, rest)
end

local function pbCacheKey(eventId, tier)
	return tostring(eventId or "") .. "::" .. string.upper(tostring(tier or ""))
end

local function timeTrialPBForTier(eventId, tier)
	eventId = tostring(eventId or "")
	tier = string.upper(tostring(tier or ""))
	local key = pbCacheKey(eventId, tier)
	if pbReadoutCache[key] ~= nil then
		return pbReadoutCache[key]
	end
	if eventId == "" or tier == "" or tier == "--" then
		pbReadoutCache[key] = { Ok = true, Found = false, Message = "No tier selected." }
		return pbReadoutCache[key]
	end
	local result = callRace("GetTimeTrialPersonalBest", {
		EventId = eventId,
		VehicleTier = tier,
	})
	if type(result) ~= "table" then
		result = { Ok = false, Found = false, Message = "PB lookup failed." }
	end
	pbReadoutCache[key] = result
	return result
end

local function pbReadoutText(result, compact)
	if type(result) ~= "table" then
		return compact and "PB --" or "Personal best: --"
	end
	local best = tonumber(result.BestSeconds or (result.Record and result.Record.BestSeconds))
	if result.Found == true and best then
		local medal = tostring(result.BestMedal or (result.Record and result.Record.BestMedal) or "")
		local suffix = medal ~= "" and (" / " .. string.upper(medal)) or ""
		return (compact and "PB " or "Personal best: ") .. formatPBReadoutTime(best) .. suffix
	end
	if result.Ok == false and result.Message and result.Message ~= "" then
		return compact and "PB unavailable" or tostring(result.Message)
	end
	return compact and "PB --" or "Personal best: --"
end

local function rememberPBFromResultPayload(payload)
	if type(payload) ~= "table" then
		return
	end
	local eventId = tostring(payload.EventId or "")
	local tier = string.upper(tostring(payload.VehicleTier or ""))
	if eventId == "" or tier == "" or tier == "--" then
		return
	end
	local best = tonumber(payload.PersonalBestSeconds)
	if not best then
		return
	end
	pbReadoutCache[pbCacheKey(eventId, tier)] = {
		Ok = true,
		Found = true,
		BestSeconds = best,
		BestMedal = tostring(payload.PersonalBestMedal or payload.Medal or "Finished"),
		EventId = eventId,
		VehicleTier = tier,
	}
end
local function ownedRows()
	local profile = refreshProfile() or {}
	local rows = {}
	for vehicleId, vehicle in pairs((profile and profile.Vehicles) or {}) do
		local cockpitId = cockpitIdForVehicle(profile, vehicle)
		if cockpitId ~= "" then
			local cockpit = catalogCockpit(cockpitId)
			local tier, ratingIndex, sortRating = vehicleRatingParts(profile, vehicleId)
			table.insert(rows, {
				VehicleId = tostring(vehicleId),
				CockpitId = cockpitId,
				Cockpit = cockpit,
				Name = cockpitName(cockpitId, cockpit),
				Image = cockpitImage(cockpitId, cockpit),
				Tier = tier,
				RatingIndex = ratingIndex,
				SortRating = sortRating,
				Selected = tostring(vehicleId) == tostring(profile and profile.CurrentVehicleId or ""),
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.SortRating ~= b.SortRating then
			return a.SortRating > b.SortRating
		end
		if a.Name == b.Name then
			return a.VehicleId < b.VehicleId
		end
		return a.Name < b.Name
	end)
	return rows
end

local function placeholder(parent, text)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(10, 15, 20)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 6)
	stroke(frame, theme.Selected, 1, 0.4)
	local t = label(frame, text, UDim2.new(1, -16, 1, -16), UDim2.fromOffset(8, 8), touch and 11 or 13, theme.Muted, true)
	t.TextXAlignment = Enum.TextXAlignment.Center
	return frame
end

local function imageOrPlaceholder(parent, image, text)
	local holder = placeholder(parent, text)
	if typeof(image) == "string" and image ~= "" then
		local imageLabel = Instance.new("ImageLabel")
		imageLabel.BackgroundTransparency = 1
		imageLabel.BorderSizePixel = 0
		imageLabel.Size = UDim2.new(1, -10, 1, -10)
		imageLabel.Position = UDim2.fromOffset(5, 5)
		imageLabel.ScaleType = Enum.ScaleType.Fit
		imageLabel.Image = image
		imageLabel.Parent = holder
	end
	return holder
end

local function lapLabel(count)
	count = tonumber(count)
	if count == 0 then
		return "INFINITE"
	end
	return tostring(math.clamp(math.floor(count or 1), 1, 10)) .. " LAP"
end

local function lapSettings()
	local summary = state.Entry and state.Entry.Summary or {}
	local minLap = math.clamp(math.floor(tonumber(summary.MinLapCount) or 1), 1, 10)
	local maxLap = math.clamp(math.floor(tonumber(summary.MaxLapCount) or 10), minLap, 10)
	local defaultLap = math.clamp(math.floor(tonumber(summary.DefaultLapCount or summary.Laps) or 1), minLap, maxLap)
	return {
		RouteType = tostring(summary.RouteType or "Circuit"),
		Min = minLap,
		Max = maxLap,
		Default = defaultLap,
		AllowInfinite = summary.AllowInfiniteLaps ~= false,
	}
end

local function makeLapSelector(parent, position)
	-- NTR_RACING_PHASE9A_LAP_SELECTOR
	local settings = lapSettings()
	state.SelectedLapCount = settings.Default
	if settings.RouteType == "PointToPoint" then
		state.SelectedLapCount = 1
	end

	local wrap = Instance.new("Frame")
	wrap.Name = "LapSelector"
	wrap.BackgroundColor3 = theme.Card
	wrap.BackgroundTransparency = 0.1
	wrap.BorderSizePixel = 0
	wrap.Position = position or UDim2.fromOffset(0, 160)
	wrap.Size = UDim2.new(1, 0, 0, touch and 82 or 92)
	wrap.Parent = parent
	corner(wrap, 6)
	stroke(wrap, theme.Accent, 1, 0.48)

	local title = label(wrap, settings.RouteType == "PointToPoint" and "POINT TO POINT" or "TIME TRIAL LAPS", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 6), touch and 9 or 11, theme.Accent, true)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local selected = label(wrap, lapLabel(state.SelectedLapCount), UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 27), touch and 12 or 14, theme.Text, true)
	selected.TextXAlignment = Enum.TextXAlignment.Center

	if settings.RouteType == "PointToPoint" then
		local note = label(wrap, "This route finishes once.", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 54), touch and 9 or 10, theme.Muted, false)
		note.TextXAlignment = Enum.TextXAlignment.Center
		return wrap
	end

	local minus = button(wrap, "-", UDim2.fromOffset(42, 30), UDim2.new(0, 8, 1, -36), theme.Panel)
	local plus = button(wrap, "+", UDim2.fromOffset(42, 30), UDim2.new(1, -50, 1, -36), theme.Panel)
	local infinite = button(wrap, "INFINITE", UDim2.new(1, -116, 0, 30), UDim2.new(0, 58, 1, -36), theme.Card)
	infinite.Visible = settings.AllowInfinite

	local function refresh()
		selected.Text = lapLabel(state.SelectedLapCount)
		infinite.BackgroundColor3 = state.SelectedLapCount == 0 and theme.CardHot or theme.Card
	end

	minus.MouseButton1Click:Connect(function()
		if state.SelectedLapCount == 0 then
			state.SelectedLapCount = settings.Max
		else
			state.SelectedLapCount = math.max(settings.Min, (tonumber(state.SelectedLapCount) or settings.Default) - 1)
		end
		refresh()
	end)
	plus.MouseButton1Click:Connect(function()
		state.SelectedLapCount = math.min(settings.Max, (tonumber(state.SelectedLapCount) or settings.Default) + 1)
		refresh()
	end)
	infinite.MouseButton1Click:Connect(function()
		state.SelectedLapCount = 0
		refresh()
	end)
	refresh()
	return wrap
end

local showEntry

local function showVehicleSelect(mode)
	clearContent()
	state.SelectedRow = nil
	title.Text = mode == "Race" and "CHOOSE RACE VEHICLE" or "CHOOSE TIME TRIAL VEHICLE"
	statusText("Pick one of your owned vehicles. The server will validate it before staging.", true)

	local rows = ownedRows()
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.Parent = content

	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.CellSize = touch and UDim2.fromOffset(146, 184) or UDim2.fromOffset(182, 222)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	if #rows == 0 then
		local empty = label(scroll, "No owned vehicles found yet.", UDim2.fromOffset(420, 40), UDim2.fromOffset(0, 0), 14, theme.Muted, true)
		empty.LayoutOrder = 1
	end

	local function redrawSelection()
		for _, card in ipairs(scroll:GetChildren()) do
			if card:IsA("TextButton") then
				local selected = state.SelectedRow and card:GetAttribute("VehicleId") == state.SelectedRow.VehicleId
				card.BackgroundColor3 = selected and theme.CardHot or theme.Card
				local s = card:FindFirstChildOfClass("UIStroke")
				if s then
					s.Color = selected and theme.Selected or theme.Accent
					s.Transparency = selected and 0.05 or 0.35
				end
			end
		end
	end

	for index, row in ipairs(rows) do
		local card = Instance.new("TextButton")
		card.Name = "Vehicle_" .. row.VehicleId
		card.LayoutOrder = index
		card.Text = ""
		card.AutoButtonColor = true
		card.BorderSizePixel = 0
		card.BackgroundColor3 = row.Selected and theme.CardHot or theme.Card
		card:SetAttribute("VehicleId", row.VehicleId)
		card:SetAttribute("CockpitId", row.CockpitId)
		card.Parent = scroll
		corner(card, 6)
		stroke(card, row.Selected and theme.Selected or theme.Accent, 1.2, row.Selected and 0.05 or 0.35)

		local imageBox = Instance.new("Frame")
		imageBox.BackgroundColor3 = Color3.fromRGB(8, 12, 17)
		imageBox.BorderSizePixel = 0
		imageBox.Position = UDim2.fromOffset(10, 10)
		imageBox.Size = UDim2.new(1, -20, 0, touch and 104 or 136)
		imageBox.Parent = card
		corner(imageBox, 5)
		if row.Image ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.new(1, -8, 1, -8)
			img.Position = UDim2.fromOffset(4, 4)
			img.ScaleType = Enum.ScaleType.Fit
			img.Image = row.Image
			img.Parent = imageBox
		else
			local p = label(imageBox, "NO IMAGE", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 11, theme.Muted, true)
			p.TextXAlignment = Enum.TextXAlignment.Center
		end

		local badge = Instance.new("Frame")
		badge.BackgroundColor3 = tierColor(row.Tier)
		badge.BorderSizePixel = 0
		badge.Position = UDim2.new(1, touch and -74 or -86, 0, 16)
		badge.Size = touch and UDim2.fromOffset(58, 18) or UDim2.fromOffset(70, 22)
		badge.Parent = card
		corner(badge, 4)
		local badgeText = label(badge, row.Tier .. " " .. row.RatingIndex, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 8 or 9, Color3.fromRGB(255, 255, 255), true)
		badgeText.TextXAlignment = Enum.TextXAlignment.Center

		label(card, row.Name, UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, touch and 120 or 154), touch and 10 or 12, theme.Text, true)
		label(card, row.CockpitId, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, touch and 150 or 184), touch and 8 or 9, theme.Muted, false)
		local pbText = ""
		if mode == "TimeTrial" then
			pbText = pbReadoutText(timeTrialPBForTier(timeTrialEventIdForStart(), row.Tier), true)
		end
		local pbLabel = label(card, pbText, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, touch and 166 or 204), touch and 8 or 9, theme.Accent, true)
		pbLabel.TextXAlignment = Enum.TextXAlignment.Left

		card.MouseButton1Click:Connect(function()
			state.SelectedRow = row
			redrawSelection()
			if mode == "TimeTrial" then
				statusText("Selected " .. row.Name .. " (" .. row.Tier .. " " .. row.RatingIndex .. ")  " .. pbReadoutText(timeTrialPBForTier(timeTrialEventIdForStart(), row.Tier), false), true)
			else
				statusText("Selected " .. row.Name .. " (" .. row.Tier .. " " .. row.RatingIndex .. ")", true)
			end
		end)
		if row.Selected and not state.SelectedRow then
			state.SelectedRow = row
		end
	end
	redrawSelection()
	if mode == "TimeTrial" and state.SelectedRow then
		statusText("Selected " .. state.SelectedRow.Name .. " (" .. state.SelectedRow.Tier .. " " .. state.SelectedRow.RatingIndex .. ")  " .. pbReadoutText(timeTrialPBForTier(timeTrialEventIdForStart(), state.SelectedRow.Tier), false), true)
	end

	local back = button(actionRail, "BACK", UDim2.new(0.25, -8, 1, 0), UDim2.fromScale(0, 0), theme.Card)
	local start = button(actionRail, mode == "Race" and "START RACE" or "START TIME TRIAL", UDim2.new(0.5, -8, 1, 0), UDim2.new(0.25, 4, 0, 0), theme.Buy)
	local exit = button(actionRail, "EXIT", UDim2.new(0.25, -8, 1, 0), UDim2.new(0.75, 8, 0, 0), theme.Exit)

	back.MouseButton1Click:Connect(function()
		if state.Entry then
			showEntry({ Type = "OpenRaceEntry", EventId = state.Entry.EventId, Mode = mode, Summary = state.Entry.Summary })
		end
	end)
	exit.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	start.MouseButton1Click:Connect(function()
		local row = state.SelectedRow
		if not row then
			statusText("Choose a vehicle first.", false)
			return
		end
		if mode == "Race" then
			local raceEventId = raceEventIdForStart()
			local eventCheck = callRace("GetEntryDetails", {
				EventId = raceEventId,
				Mode = "Race",
			})
			if eventCheck.Ok ~= true and eventCheck.Success ~= true then
				statusText(eventCheck.Message or "Race event is not available.", false)
				return
			end
			statusText("Joining race queue. Your selected vehicle will spawn on the grid.", true)
			-- NTR_RACING_PHASE11C_CLIENT_RACE_NO_SPAWN
			-- NTR_RACING_PHASE8C_NO_PRE_STAGE_HANDOFF
			-- Do not fire the free-roam driving handoff before Racing teleports/freezes the car.
			-- TimeTrialStarted/RaceStarted fire the handoff at GO, matching the cleaner retry path.
			task.wait(0.35)
			startRaceQueueEvent:Fire({
				EventId = raceEventId,
				VehicleId = row.VehicleId,
				CockpitId = row.CockpitId,
				DisplayName = state.Entry and state.Entry.Summary and state.Entry.Summary.DisplayName,
			})
			setOpen(false)
			return
		end
		local timeTrialEventId = timeTrialEventIdForStart()
		local eventCheck = callRace("GetEntryDetails", {
			EventId = timeTrialEventId,
			Mode = "TimeTrial",
		})
		if eventCheck.Ok ~= true and eventCheck.Success ~= true then
			statusText(eventCheck.Message or "Time trial event is not available.", false)
			return
		end
		statusText("Staging selected vehicle at the start line.", true)
		-- NTR_RACING_PHASE11C_CLIENT_TT_NO_SPAWN
		-- NTR_RACING_PHASE8C_NO_PRE_STAGE_HANDOFF
		-- Do not fire the free-roam driving handoff before Racing teleports/freezes the car.
		-- TimeTrialStarted/RaceStarted fire the handoff at GO, matching the cleaner retry path.
		task.wait(0.35)
		statusText("Staging at start line...", true)
		local startResult = callRace("StartStagedTimeTrial", {
			EventId = timeTrialEventId,
			VehicleId = row.VehicleId,
			LapCount = state.SelectedLapCount or 1,
		})
		if startResult.Ok ~= true and startResult.Success ~= true then
			statusText(startResult.Message or "Could not start time trial.", false)
			return
		end
		setOpen(false)
	end)
end

function showEntry(payload)
	clearContent()
	local summary = payload.Summary or {}
	state.Entry = {
		EventId = payload.EventId or summary.EventId or "shifted_canal_sprint_tt",
		RaceEventId = payload.RaceEventId, -- NTR_RACING_PHASE11B_STATE_RACE_EVENT_ID
		TimeTrialEventId = payload.TimeTrialEventId,
		Mode = payload.Mode or summary.Mode or "TimeTrial",
		Summary = summary,
	}
	-- NTR_RACING_UI_PHASE2_ENTRY_PRESENTATION_BRIDGE
	local presentationRequest = script.Parent:FindFirstChild("RaceEntryPresentationRequest")
	if presentationRequest and presentationRequest:IsA("BindableEvent") then
		setOpen(false)
		gui.Enabled = false -- NTR_RACING_UI_PHASE2_V3_LEGACY_GUI_SUPPRESSION
		presentationRequest:Fire(payload)
		return
	end
	title.Text = tostring(summary.DisplayName or "RACE MENU")
	statusText(payload.Message or "Review the track, then choose a mode.", true)

	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0.48, -8, 1, 0)
	left.Parent = content
	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0.48, 8, 0, 0)
	right.Size = UDim2.new(0.52, -8, 1, 0)
	right.Parent = content

	local track = imageOrPlaceholder(left, summary.TrackImage, "TRACK IMAGE")
	track.Size = UDim2.new(1, 0, 0.55, -6)
	track.Position = UDim2.fromScale(0, 0)
	local map = imageOrPlaceholder(left, summary.MapImage, "TRACK MAP")
	map.Size = UDim2.new(1, 0, 0.45, -6)
	map.Position = UDim2.new(0, 0, 0.55, 6)

	label(right, tostring(summary.RouteDisplayName or summary.RouteId or "Route"), UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), touch and 14 or 18, theme.Text, true)
	label(right, "Recommended tier: " .. tostring(summary.RecommendedTier or "--"), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 42), touch and 11 or 13, theme.Accent, true)
	label(right, "Allowed tiers: " .. tostring(summary.AllowedVehicleTiers or "All"), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 72), touch and 10 or 12, theme.Muted, false)
	label(right, "Checkpoints: " .. tostring(summary.CheckpointCount or 0) .. "   Route gates: " .. tostring(summary.GateCount or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 102), touch and 10 or 12, theme.Muted, false)
	label(right, "Base reward: $" .. tostring(summary.BaseReward or 0), UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 132), touch and 10 or 12, theme.Muted, false)
	makeLapSelector(right, UDim2.fromOffset(0, 164))
	label(right, "Time trials are solo. Circuit sessions use your best completed lap for medals and one payout when the session ends, so Infinite is for practice without per-lap cash farming.", UDim2.new(1, 0, 0, 116), UDim2.fromOffset(0, 266), touch and 10 or 12, theme.Text, false)

	local startRace = button(actionRail, "START RACE", UDim2.new(0.333, -8, 1, 0), UDim2.fromScale(0, 0), theme.Card)
	local startTT = button(actionRail, "START TIME TRIAL", UDim2.new(0.334, -8, 1, 0), UDim2.new(0.333, 4, 0, 0), theme.Buy)
	local exit = button(actionRail, "EXIT", UDim2.new(0.333, -8, 1, 0), UDim2.new(0.667, 8, 0, 0), theme.Exit)

	startRace.MouseButton1Click:Connect(function()
		showVehicleSelect("Race")
	end)
	startTT.MouseButton1Click:Connect(function()
		showVehicleSelect("TimeTrial")
	end)
	exit.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	setOpen(true)
end

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

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "NTR_RaceHud_Phase3"
hudGui.IgnoreGuiInset = true
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 76
hudGui.Enabled = true
hudGui.Parent = playerGui

local hud = Instance.new("Frame")
hud.Name = "Panel"
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0, 68)
hud.Size = UDim2.fromOffset(380, 98)
hud.BackgroundColor3 = theme.Panel
hud.BackgroundTransparency = 0.12
hud.BorderSizePixel = 0
hud.Visible = false
hud.Parent = hudGui
corner(hud, 7)
stroke(hud, theme.Accent, 1.5, 0.22)

local hudTitle = label(hud, "TIME TRIAL", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 8), 13, theme.Text, true)
local hudTimer = label(hud, "0.000", UDim2.new(0.5, -12, 0, 30), UDim2.fromOffset(12, 34), 24, theme.Accent, true)
local hudProgress = label(hud, "CHECKPOINT 1/1", UDim2.new(0.5, -12, 0, 22), UDim2.new(0.5, 0, 0, 39), 12, theme.Text, true)
hudProgress.TextXAlignment = Enum.TextXAlignment.Right
local hudStatus = label(hud, "", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 70), 11, theme.Muted, false)

local markerRoot = Workspace:FindFirstChild("_NTR_ClientOnly")
if not markerRoot then
	markerRoot = Instance.new("Folder")
	markerRoot.Name = "_NTR_ClientOnly"
	markerRoot.Parent = Workspace
end

local marker = nil
local markerGui = nil
local ticker = nil

local function formatTime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	return string.format("%.3f", seconds)
end

local function clearMarker()
	if marker then marker:Destroy(); marker = nil end
	if markerGui then markerGui:Destroy(); markerGui = nil end
end

local function ensureMarker(part, isFinish)
	-- NTR_RACING_PHASE5B_OLD_MARKER_DISABLED
	-- Phase 5's RaceRouteGuideClient_Active now owns checkpoint visuals.
	-- Keep this function as a cleanup hook so any existing old marker is removed.
	clearMarker()
	return
end

local function fireDrivingHandoff()
	-- NTR_RACING_PHASE3E_CLIENT_HANDOFF
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local spawnedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleSpawned")
	if spawnedEvent and spawnedEvent:IsA("BindableEvent") then
		spawnedEvent:Fire()
	end
end
local function fireDrivingExitHandoff()
	-- NTR_RACING_PHASE11Q_TT_EXIT_DRIVING_HANDOFF
	local clientRoot = script.Parent.Parent
	local uiFolder = clientRoot and clientRoot:FindFirstChild("UI")
	local exitedEvent = uiFolder and uiFolder:FindFirstChild("FreeRoamVehicleExited")
	if exitedEvent and exitedEvent:IsA("BindableEvent") then
		exitedEvent:Fire()
	end
end

local routeForActive

local function requestStreamAroundActiveRoute()
	local route = routeForActive()
	local gate = route and RouteDefinition.GetGate(route, state.ActiveRun and state.ActiveRun.NextGateIndex or 1)
	local part = gate and gate.Part
	if part then
		pcall(function()
			Workspace:RequestStreamAroundAsync(part.Position)
		end)
	end
end

function routeForActive()
	if not state.ActiveRun then return nil end
	local route, routeError = RouteDefinition.GetRouteDefinition(state.ActiveRun.RouteId)
	if not route then
		warn("[NTR Racing Phase 3 Client] " .. tostring(routeError))
	end
	return route
end

local function updateNextGate()
	local route = routeForActive()
	local gate = route and RouteDefinition.GetGate(route, state.ActiveRun.NextGateIndex or 1)
	if gate then
		ensureMarker(gate.Part, gate.IsFinish)
		local gateLabel = gate.IsFinish and "FINISH" or "CHECKPOINT"
		hudProgress.Text = string.format("%s %d/%d", gateLabel, state.ActiveRun.NextGateIndex or 1, state.ActiveRun.GateCount or 1)
	else
		clearMarker()
	end
end

local function startTicker()
	if ticker then ticker:Disconnect(); ticker = nil end
	ticker = RunService.Heartbeat:Connect(function()
		if not state.ActiveRun or not state.ActiveRun.StartLocalClock then return end
		hudTimer.Text = formatTime(os.clock() - state.ActiveRun.StartLocalClock)
	end)
end

local function stopTicker()
	if ticker then ticker:Disconnect(); ticker = nil end
end

local function showHudError(message)
	hud.Visible = true
	hudTitle.Text = "RACING"
	hudTimer.Text = "--"
	hudProgress.Text = ""
	hudStatus.Text = tostring(message or "Race unavailable.")
	task.delay(2.2, function()
		if not state.ActiveRun then
			hud.Visible = false
			hudStatus.Text = ""
		end
	end)
end

-- NTR_RACING_PHASE4_CLIENT_RESULTS
local resultGui = Instance.new("ScreenGui")
resultGui.Name = "NTR_RaceResults_Phase4"
resultGui.IgnoreGuiInset = true
resultGui.ResetOnSpawn = false
resultGui.DisplayOrder = 86
resultGui.Enabled = true
resultGui.Parent = playerGui

local resultPanel = Instance.new("Frame")
resultPanel.Name = "Panel"
resultPanel.AnchorPoint = Vector2.new(0.5, 0.5)
resultPanel.Position = UDim2.fromScale(0.5, 0.5)
resultPanel.Size = touch and UDim2.new(0.92, 0, 0, 390) or UDim2.fromOffset(560, 390)
resultPanel.BackgroundColor3 = theme.Panel
resultPanel.BackgroundTransparency = 0.06
resultPanel.BorderSizePixel = 0
resultPanel.Visible = false
resultPanel.Parent = resultGui
corner(resultPanel, 7)
stroke(resultPanel, theme.Selected, 1.6, 0.14)

local resultTitle = label(resultPanel, "TIME TRIAL COMPLETE", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 12), touch and 14 or 18, theme.Text, true)
resultTitle.TextXAlignment = Enum.TextXAlignment.Center
local resultMedal = label(resultPanel, "FINISHED", UDim2.new(1, -28, 0, 48), UDim2.fromOffset(14, 48), touch and 24 or 34, theme.Accent, true)
resultMedal.TextXAlignment = Enum.TextXAlignment.Center
local resultTime = label(resultPanel, "0.000", UDim2.new(1, -28, 0, 36), UDim2.fromOffset(14, 98), touch and 18 or 26, theme.Text, true)
resultTime.TextXAlignment = Enum.TextXAlignment.Center
local resultBest = label(resultPanel, "", UDim2.new(1, -36, 0, 36), UDim2.fromOffset(18, 140), touch and 11 or 13, theme.Accent, true)
resultBest.TextXAlignment = Enum.TextXAlignment.Center
local resultNext = label(resultPanel, "", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 178), touch and 11 or 13, theme.Muted, false)
resultNext.TextXAlignment = Enum.TextXAlignment.Center
-- NTR_RACING_PHASE6_REWARD_RESULT_UI
local resultReward = label(resultPanel, "", UDim2.new(1, -36, 0, 28), UDim2.fromOffset(18, 218), touch and 12 or 14, theme.Accent, true)
resultReward.TextXAlignment = Enum.TextXAlignment.Center
local resultSplits = label(resultPanel, "", UDim2.new(1, -36, 0, 58), UDim2.fromOffset(18, 252), touch and 10 or 12, theme.Text, false)
resultSplits.TextYAlignment = Enum.TextYAlignment.Top

local resultRetry = button(resultPanel, "RETRY", UDim2.new(0.5, -18, 0, 46), UDim2.new(0, 14, 1, -60), theme.Buy)
local resultExit = button(resultPanel, "EXIT", UDim2.new(0.5, -18, 0, 46), UDim2.new(0.5, 4, 1, -60), theme.Exit)
local lastFinishedRun = nil

local function medalColor(medal)
	medal = tostring(medal or "")
	if medal == "Platinum" then
		return Color3.fromRGB(185, 240, 255)
	elseif medal == "Gold" then
		return Color3.fromRGB(255, 220, 85)
	elseif medal == "Silver" then
		return Color3.fromRGB(210, 225, 235)
	elseif medal == "Bronze" then
		return Color3.fromRGB(220, 142, 76)
	end
	return theme.Accent
end

local function medalLabel(medal)
	medal = tostring(medal or "Finished")
	if medal == "Finished" or medal == "" then
		return "FINISHED"
	end
	return string.upper(medal)
end

local function splitSummary(splits)
	local list = {}
	for _, split in ipairs(splits or {}) do
		if #list >= 4 then
			break
		end
		table.insert(list, "CP " .. tostring(split.CheckpointIndex or "?") .. "  " .. formatTime(split.Elapsed))
	end
	if #list == 0 then
		return "Splits will appear after the first checkpoint."
	end
	return table.concat(list, "\n")
end

local function hideResult()
	resultPanel.Visible = false
	lastFinishedRun = nil
end

local function showResult(payload)
	lastFinishedRun = payload
	local medal = tostring(payload.Medal or "Finished")
	if tostring(payload.FinishReason or "") == "Quit" then
		resultTitle.Text = tostring(payload.DisplayName or "TIME TRIAL SESSION")
	elseif tostring(payload.RouteType or "") == "Circuit" and tonumber(payload.CompletedLapCount) and tonumber(payload.CompletedLapCount) > 1 then
		resultTitle.Text = tostring(payload.DisplayName or "BEST LAP")
	else
		resultTitle.Text = tostring(payload.DisplayName or "TIME TRIAL COMPLETE")
	end
	resultMedal.Text = medalLabel(medal)
	resultMedal.TextColor3 = medalColor(medal)
	resultTime.Text = formatTime(payload.Elapsed)
	local best = tonumber(payload.PersonalBestSeconds)
	if payload.IsPersonalBest == true then
		resultBest.Text = "NEW PERSONAL BEST  " .. formatTime(best or payload.Elapsed)
	elseif best then
		resultBest.Text = "PERSONAL BEST  " .. formatTime(best)
	else
		resultBest.Text = "PERSONAL BEST  --"
	end
	if payload.NextMedalName and payload.NextMedalSeconds then
		resultNext.Text = "Next medal: " .. tostring(payload.NextMedalName) .. " at " .. formatTime(payload.NextMedalSeconds) .. "  (" .. formatTime(math.abs(tonumber(payload.NextMedalDelta) or 0)) .. " faster)"
	elseif medal == "Platinum" then
		resultNext.Text = "Platinum target cleared."
	else
		resultNext.Text = "No medal targets configured for this tier yet."
	end
	local rewardAmount = tonumber(payload.RewardAmount) or 0
	if payload.RewardGranted == true and rewardAmount > 0 then
		resultReward.Text = "REWARD  $" .. tostring(math.floor(rewardAmount + 0.5))
	elseif payload.RewardMessage and payload.RewardMessage ~= "" then
		resultReward.Text = tostring(payload.RewardMessage)
	else
		resultReward.Text = "No cash reward this run."
	end
	if payload.LapTimes and #payload.LapTimes > 0 then
		local laps = {}
		for _, lap in ipairs(payload.LapTimes) do
			if #laps >= 4 then break end
			table.insert(laps, "LAP " .. tostring(lap.Lap or "?") .. "  " .. formatTime(lap.Elapsed))
		end
		resultSplits.Text = table.concat(laps, "\n")
	else
		resultSplits.Text = splitSummary(payload.Splits)
	end
	resultRetry.Visible = payload.CanRetry ~= false
	resultPanel.Visible = true
end

resultRetry.MouseButton1Click:Connect(function()
	local run = lastFinishedRun
	if not run then
		return
	end
	hideResult()
	hud.Visible = true
	hudTitle.Text = tostring(run.DisplayName or "TIME TRIAL")
	hudTimer.Text = "--"
	hudProgress.Text = "RESTAGING"
	hudStatus.Text = "Retrying..."
	local result = callRace("StartStagedTimeTrial", {
		EventId = run.EventId,
		VehicleId = run.SelectedVehicleId,
	})
	if result.Ok ~= true and result.Success ~= true then
		hudStatus.Text = tostring(result.Message or "Could not retry.")
		resultPanel.Visible = true
		lastFinishedRun = run
	end
end)

resultExit.MouseButton1Click:Connect(function()
	-- NTR_RACING_PHASE11K_RESULT_EXIT_ACTION
	hideResult()
	fireDrivingExitHandoff()
	stopTicker()
	clearMarker()
	state.ActiveRun = nil
	hud.Visible = false
	local result = callRace("ExitFinishedTimeTrial", {})
	if result.Ok ~= true and result.Success ~= true then
		callRace("CancelTimeTrial", {})
	end
end)

local function toSet(list)
	local set = {}
	for _, userId in ipairs(list or {}) do
		set[tonumber(userId)] = true
	end
	return set
end

local function setModelHidden(model, hidden)
	for _, descendant in ipairs(model and model:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function applyVisibility()
	local visibility = state.Visibility
	if not (visibility and visibility.Active) then
		for _, other in ipairs(Players:GetPlayers()) do
			if other.Character then setModelHidden(other.Character, false) end
		end
		local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
		local runtime = world and world:FindFirstChild("Runtime")
		local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
		for _, vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do
			setModelHidden(vehicle, false)
		end
		return
	end
	local participants = toSet(visibility.Participants)
	local localIsParticipant = participants[player.UserId] == true
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			local otherIsParticipant = participants[other.UserId] == true
			setModelHidden(other.Character, localIsParticipant and not otherIsParticipant or (not localIsParticipant and otherIsParticipant))
		end
	end
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	for _, vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do
		local owner = tonumber(vehicle:GetAttribute("OwnerUserId"))
		local vehicleIsParticipant = owner and participants[owner] == true
		setModelHidden(vehicle, localIsParticipant and not vehicleIsParticipant or (not localIsParticipant and vehicleIsParticipant))
	end
end

-- NTR_RACING_PHASE11L_ENTRY_MENU_LEGACY_VIS_DISABLED
-- Visibility is owned by RaceParticipantVisibilityClient_Active.
-- Keep the old helper definitions inert so this menu client cannot fight the
-- multi-session VFX/name-tag gate when races and time trials overlap.

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	print("[NTR Racing Phase 3 Client] received event " .. tostring(kind))
	if kind == "OpenRaceEntry" then
		local ok, err = pcall(function()
			showEntry(payload)
		end)
		if not ok then
			warn("[NTR Racing Phase 3 Client] showEntry failed: " .. tostring(err))
		end
	elseif kind == "TimeTrialError" then
		showHudError(payload.Message)
	elseif kind == "TimeTrialStaged" then
		hideResult()
		state.ActiveRun = {
			RunId = payload.RunId,
			EventId = payload.EventId,
			RouteId = payload.RouteId,
			DisplayName = payload.DisplayName,
			NextGateIndex = payload.NextGateIndex or 1,
			GateCount = payload.GateCount or 1,
		}
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = tostring(payload.Countdown or 3)
		hudStatus.Text = "STAGED"
		updateNextGate()
	elseif kind == "TimeTrialCountdown" then
		state.ActiveRun = state.ActiveRun or {}
		state.ActiveRun.RunId = payload.RunId
		state.ActiveRun.EventId = payload.EventId
		state.ActiveRun.RouteId = payload.RouteId
		state.ActiveRun.DisplayName = payload.DisplayName
		state.ActiveRun.NextGateIndex = payload.NextGateIndex or 1
		state.ActiveRun.GateCount = payload.GateCount or 1
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = tostring(payload.Countdown or 3)
		hudStatus.Text = "GET READY"
		updateNextGate()
	elseif kind == "TimeTrialStarted" then
		hideResult()
		state.ActiveRun = state.ActiveRun or {}
		state.ActiveRun.RunId = payload.RunId
		state.ActiveRun.EventId = payload.EventId
		state.ActiveRun.RouteId = payload.RouteId
		state.ActiveRun.DisplayName = payload.DisplayName
		state.ActiveRun.NextGateIndex = payload.NextGateIndex or 1
		state.ActiveRun.GateCount = payload.GateCount or 1
		state.ActiveRun.StartLocalClock = os.clock()
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudStatus.Text = "GO"
		updateNextGate()
		task.defer(requestStreamAroundActiveRoute)
		task.defer(fireDrivingHandoff)
		task.delay(0.25, fireDrivingHandoff)
		startTicker()
	elseif kind == "TimeTrialLapCompleted" then
		if not state.ActiveRun then return end
		state.ActiveRun.NextGateIndex = 1
		state.ActiveRun.GateCount = payload.GateCount or state.ActiveRun.GateCount
		state.ActiveRun.StartLocalClock = os.clock()
		hudStatus.Text = "BEST LAP " .. formatTime(payload.BestLapSeconds or payload.Elapsed)
		hudTimer.Text = "0.000"
		updateNextGate()
	elseif kind == "TimeTrialCheckpoint" then
		if not state.ActiveRun then return end
		state.ActiveRun.NextGateIndex = payload.NextGateIndex or state.ActiveRun.NextGateIndex
		state.ActiveRun.GateCount = payload.GateCount or state.ActiveRun.GateCount
		hudStatus.Text = "CHECKPOINT " .. tostring(payload.CheckpointIndex or "")
		updateNextGate()
	elseif kind == "TimeTrialFinished" then
		rememberPBFromResultPayload(payload)
		fireDrivingExitHandoff()
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = true
		hudTitle.Text = tostring(payload.DisplayName or "TIME TRIAL")
		hudTimer.Text = formatTime(payload.Elapsed)
		hudProgress.Text = "FINISHED"
		hudStatus.Text = tostring(payload.Message or "Finished")
		showResult(payload)
	elseif kind == "TimeTrialEnded" then
		hideResult()
		fireDrivingExitHandoff()
		stopTicker()
		clearMarker()
		state.ActiveRun = nil
		hud.Visible = false
	elseif kind == "RaceVisibilityUpdate" then
		-- NTR_RACING_PHASE11L_ENTRY_MENU_LEGACY_VIS_DISABLED
		-- Dedicated RaceParticipantVisibilityClient_Active owns session hiding.
	end
end)

print("[NTR Racing Phase 3 Client] Race entry menu/HUD active.")
