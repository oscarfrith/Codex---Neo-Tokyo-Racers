-- Neo Tokyo Racers - PC Free-Roam UI Phase 2A Runtime Layout Diagnostic
-- Run in the Roblox Studio Command Bar from a Play client.
--
-- READ ONLY: this script does not create, edit, move, or destroy instances.
-- For the most complete report, open MY VEHICLES once, enter a vehicle, then
-- run this script. Run it once more on foot to verify the driving-only controls.

local PHASE = "NTR PC Free-Roam UI Phase 2A Runtime Layout Diagnostic"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local passCount = 0
local warnCount = 0
local failCount = 0

local function line(kind, message)
	print(string.format("[%s] %-4s %s", PHASE, kind, tostring(message)))
end

local function pass(message)
	passCount += 1
	line("PASS", message)
end

local function warn(message)
	warnCount += 1
	line("WARN", message)
end

local function fail(message)
	failCount += 1
	line("FAIL", message)
end

local function fmtVector(value)
	return string.format("(%.1f, %.1f)", value.X, value.Y)
end

local function fmtGui(item)
	return string.format(
		"%s pos=%s size=%s visible=%s",
		item:GetFullName(),
		fmtVector(item.AbsolutePosition),
		fmtVector(item.AbsoluteSize),
		tostring(item.Visible)
	)
end

local function requireChild(parent, name, className)
	if not parent then
		fail("Cannot find " .. name .. " because its parent is missing")
		return nil
	end
	local item = parent:FindFirstChild(name)
	if not item then
		fail("Missing " .. parent:GetFullName() .. "." .. name)
		return nil
	end
	if className and not item:IsA(className) then
		fail(item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
		return nil
	end
	pass("Found " .. item:GetFullName())
	return item
end

local function isActuallyVisible(item)
	local cursor = item
	while cursor do
		if cursor:IsA("GuiObject") and not cursor.Visible then
			return false
		end
		if cursor:IsA("ScreenGui") and not cursor.Enabled then
			return false
		end
		cursor = cursor.Parent
	end
	return true
end

local function centre(item)
	return item.AbsolutePosition + item.AbsoluteSize * 0.5
end

local function right(item)
	return item.AbsolutePosition.X + item.AbsoluteSize.X
end

local function bottom(item)
	return item.AbsolutePosition.Y + item.AbsoluteSize.Y
end

local function overlaps(a, b)
	return a.AbsolutePosition.X < right(b)
		and right(a) > b.AbsolutePosition.X
		and a.AbsolutePosition.Y < bottom(b)
		and bottom(a) > b.AbsolutePosition.Y
end

local function readNumber(folder, name)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or nil
end

line("INFO", "Starting read-only runtime inspection")
line("INFO", string.format("context client=%s server=%s running=%s", tostring(RunService:IsClient()), tostring(RunService:IsServer()), tostring(RunService:IsRunning())))

local player = Players.LocalPlayer
if not player then
	fail("Players.LocalPlayer is unavailable. Start Play, switch Command Bar to Client, and rerun.")
	line("DONE", string.format("pass=%d warn=%d fail=%d", passCount, warnCount, failCount))
	return
end

local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
line("STATE", string.format("input touch=%s keyboard=%s mouse=%s gamepad=%s", tostring(UserInputService.TouchEnabled), tostring(UserInputService.KeyboardEnabled), tostring(UserInputService.MouseEnabled), tostring(UserInputService.GamepadEnabled)))
local screen = playerGui and playerGui:FindFirstChild("NTR_DesktopFreeRoamHud")
if not screen then
	fail("NTR_DesktopFreeRoamHud is not present. Wait for the UI to load and rerun.")
	line("DONE", string.format("pass=%d warn=%d fail=%d", passCount, warnCount, failCount))
	return
end
pass("Found runtime ScreenGui " .. screen:GetFullName())
line("STATE", string.format("screenEnabled=%s ignoreGuiInset=%s desktopInputEligible=%s suppressedByMajorMenu=%s", tostring(screen.Enabled), tostring(screen.IgnoreGuiInset), tostring(screen:GetAttribute("DesktopInputEligible")), tostring(screen:GetAttribute("SuppressedByMajorMenu"))))
if screen.Enabled then pass("Desktop HUD ScreenGui is enabled") else warn("Desktop HUD ScreenGui is disabled in free roam; inspect suppression attributes") end

local root = requireChild(screen, "DesignRoot", "GuiObject")
local rootScale = root and root:FindFirstChildOfClass("UIScale")
if rootScale then
	pass(string.format("DesignRoot UIScale is %.4f", rootScale.Scale))
else
	fail("DesignRoot has no UIScale")
end

local camera = Workspace.CurrentCamera
if camera then
	line("DATA", "viewport=" .. fmtVector(camera.ViewportSize))
else
	warn("Workspace.CurrentCamera is unavailable")
end
if root then
	line("DATA", fmtGui(root))
end

local neoTokyo = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
local configRoot = neoTokyo and neoTokyo:FindFirstChild("Config")
local uiRoot = configRoot and configRoot:FindFirstChild("UI")
local hudConfig = uiRoot and uiRoot:FindFirstChild("DesktopFreeRoamHud")
local layoutConfig = hudConfig and hudConfig:FindFirstChild("Layout")
if layoutConfig then
	local valueCount = 0
	for _, child in ipairs(hudConfig:GetDescendants()) do
		if child:IsA("ValueBase") then valueCount += 1 end
	end
	pass(string.format("Found DesktopFreeRoamHud config with %d editable values", valueCount))
	line("DATA", string.format(
		"config CashWidth=%s MinimapSize=%s ActionButtonSize=%s CarPanelWidth=%s",
		tostring(readNumber(layoutConfig, "CashWidth")),
		tostring(readNumber(layoutConfig, "MinimapSize")),
		tostring(readNumber(layoutConfig, "ActionButtonSize")),
		tostring(readNumber(layoutConfig, "CarPanelWidth"))
	))
else
	fail("Missing ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud.Layout")
end

-- Top-right navigation ------------------------------------------------------
local actionBar = requireChild(root, "ActionBar", "GuiObject")
if actionBar then
	line("DATA", fmtGui(actionBar))
	local viewport = camera and camera.ViewportSize or Vector2.new(math.huge, math.huge)
	local insetTopLeft = select(1, GuiService:GetGuiInset())
	local normalizedTop = actionBar.AbsolutePosition.Y + (screen.IgnoreGuiInset and insetTopLeft.Y or 0)
	local normalizedBottom = bottom(actionBar) + (screen.IgnoreGuiInset and insetTopLeft.Y or 0)
	line("DATA", string.format("action normalizedY=(%.1f, %.1f) guiInsetTop=%.1f", normalizedTop, normalizedBottom, insetTopLeft.Y))
	if normalizedTop >= 0 and normalizedBottom <= viewport.Y then
		pass("Action bar fits inside the vertical viewport")
	else
		warn("Action bar extends outside the vertical viewport; inspect ScreenGui inset handling")
	end
	local car = requireChild(actionBar, "Car", "GuiButton")
	local normalButton
	for _, name in ipairs({ "Garage", "Race", "Dealership", "Settings" }) do
		local item = requireChild(actionBar, name, "GuiButton")
		if item then
			normalButton = normalButton or item
			line("DATA", fmtGui(item))
		end
	end
	if car and normalButton then
		line("DATA", fmtGui(car))
		if car.AbsoluteSize.X >= normalButton.AbsoluteSize.X * 1.8 then
			pass("Car action is double width")
		else
			warn(string.format("Car action is not double width: car=%.1f normal=%.1f", car.AbsoluteSize.X, normalButton.AbsoluteSize.X))
		end
		local icon = car:FindFirstChild("Icon") or car:FindFirstChild("Fallback")
		if icon and icon:IsA("GuiObject") then
			local delta = centre(icon) - centre(car)
			if math.abs(delta.X) <= 2 and math.abs(delta.Y) <= 2 then
				pass("Car icon is centred")
			else
				warn("Car icon centre offset=" .. fmtVector(delta))
			end
		else
			warn("Car action has no measurable Icon/Fallback child")
		end
	end
end

-- Bottom-left HUD -----------------------------------------------------------
local leftCluster = requireChild(root, "LeftCluster", "GuiObject")
local money = leftCluster and requireChild(leftCluster, "Money", "GuiObject")
local minimap = leftCluster and requireChild(leftCluster, "Minimap", "GuiObject")
if money and minimap then
	line("DATA", fmtGui(money))
	line("DATA", fmtGui(minimap))
	local widthDelta = math.abs(money.AbsoluteSize.X - minimap.AbsoluteSize.X)
	if widthDelta <= 1 then
		pass("Money and minimap widths match")
	else
		warn(string.format("Money/minimap width mismatch is %.1f px", widthDelta))
	end
	local amount = requireChild(money, "Amount", "TextLabel")
	if amount then
		line("DATA", string.format("cash TextSize=%d Font=%s transparency=%.2f colour=%s", amount.TextSize, amount.Font.Name, amount.TextTransparency, tostring(amount.TextColor3)))
		if amount.TextSize >= 18 and amount.TextTransparency <= 0.1 then
			pass("Cash metric has strong text visibility")
		else
			warn("Cash metric should use the larger CashMetric typography role")
		end
	end
	local gradient = minimap:FindFirstChild("PreviewFeather")
	local edgeCount = 0
	for _, name in ipairs({ "EdgeLeft", "EdgeRight", "EdgeTop", "EdgeBottom" }) do
		local edge = minimap:FindFirstChild(name)
		if edge and edge:IsA("GuiObject") and edge:FindFirstChildOfClass("UIGradient") then edgeCount += 1 end
	end
	if edgeCount == 4 then
		pass("Minimap uses four child-safe gradient edge overlays")
	elseif gradient and gradient:IsA("UIGradient") then
		warn("PreviewFeather is attached to the minimap frame; it cannot fade child roads. Use edge overlays/vignette assets.")
	else
		warn("Minimap has no named edge-feather treatment")
	end
end

-- Driving-only actions -----------------------------------------------------
local bottomActions = requireChild(root, "BottomActions", "GuiObject")
local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
local driving = humanoid and humanoid.SeatPart ~= nil or false
line("STATE", "driving=" .. tostring(driving) .. " seat=" .. tostring(humanoid and humanoid.SeatPart))
if bottomActions then
	local controls = requireChild(bottomActions, "Controls", "GuiButton")
	local exit = requireChild(bottomActions, "Exit", "GuiButton")
	if controls then
		line("DATA", fmtGui(controls) .. " actualVisible=" .. tostring(isActuallyVisible(controls)))
		if isActuallyVisible(controls) == driving then
			pass("Controls button visibility matches driving state")
		else
			warn("Controls must be visible only while driving")
		end
	end
	if exit then
		line("DATA", fmtGui(exit) .. " actualVisible=" .. tostring(isActuallyVisible(exit)))
		if isActuallyVisible(exit) == driving then pass("Exit visibility matches driving state") else warn("Exit visibility does not match driving state") end
	end
end

-- Vehicle drawer -----------------------------------------------------------
local carPanel = requireChild(root, "CarPanel", "GuiObject")
if carPanel then
	line("DATA", fmtGui(carPanel) .. " actualVisible=" .. tostring(isActuallyVisible(carPanel)))
	local title = requireChild(carPanel, "Title", "TextLabel")
	local category = requireChild(carPanel, "Category", "TextButton")
	local sort = requireChild(carPanel, "Sort", "TextButton")
	local grid = requireChild(carPanel, "VehicleGrid", "ScrollingFrame")
	if title then line("DATA", string.format("car title TextSize=%d Font=%s", title.TextSize, title.Font.Name)) end
	if category then line("DATA", string.format("category TextSize=%d %s", category.TextSize, fmtGui(category))) end
	if sort then line("DATA", string.format("sort TextSize=%d %s", sort.TextSize, fmtGui(sort))) end
	if category and sort and math.min(category.TextSize, sort.TextSize) < 12 then
		warn("Dropdown text is below the recommended ControlLabel size")
	end
	if grid then
		line("DATA", fmtGui(grid) .. " canvas=" .. fmtVector(grid.AbsoluteCanvasSize))
		local gridLayout = grid:FindFirstChildOfClass("UIGridLayout")
		if gridLayout then
			line("DATA", string.format("grid cell=%s padding=%s content=%s align=%s", tostring(gridLayout.CellSize), tostring(gridLayout.CellPadding), fmtVector(gridLayout.AbsoluteContentSize), gridLayout.HorizontalAlignment.Name))
			if gridLayout.HorizontalAlignment == Enum.HorizontalAlignment.Center then pass("Vehicle grid is centred") else warn("Vehicle grid is left-aligned instead of centred") end
		else
			fail("VehicleGrid has no UIGridLayout")
		end
		if category and sort then
			local filterBottom = math.max(bottom(category), bottom(sort))
			local gap = grid.AbsolutePosition.Y - filterBottom
			line("DATA", string.format("dropdown-to-grid gap=%.1f px", gap))
			if gap >= 16 then pass("Vehicle grid clears dropdown header") else warn("Vehicle grid needs a separate header/content boundary; current gap is too small") end
		end

		local cards = {}
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then table.insert(cards, child) end
		end
		table.sort(cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		if #cards == 0 then
			warn("VehicleGrid has no cards. Open MY VEHICLES once and rerun.")
		else
			for index = 1, math.min(3, #cards) do
				local card = cards[index]
				line("DATA", "card " .. tostring(index) .. " " .. fmtGui(card))
				if overlaps(card, category) or overlaps(card, sort) then warn(card.Name .. " overlaps the dropdown header") end
				if card.AbsolutePosition.X < grid.AbsolutePosition.X - 1 or right(card) > right(grid) + 1 then warn(card.Name .. " is horizontally clipped by VehicleGrid") end
				for _, descendant in ipairs(card:GetDescendants()) do
					if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
						if descendant.Name == "Name" or descendant.Name == "Badge" or descendant.Name == "Tier" or descendant.Name == "Rating" then
							line("DATA", string.format("%s TextSize=%d Font=%s", descendant:GetFullName(), descendant.TextSize, descendant.Font.Name))
						end
					end
				end
			end
			if category and sort and cards[1] and cards[2] then
				local leftDelta = math.abs(cards[1].AbsolutePosition.X - category.AbsolutePosition.X)
				local rightDelta = math.abs(right(cards[2]) - right(sort))
				line("DATA", string.format("card/dropdown edge deltas left=%.1f right=%.1f", leftDelta, rightDelta))
				if leftDelta <= 2 and rightDelta <= 2 then pass("Vehicle-card outer edges align with dropdowns") else warn("Vehicle-card outer edges do not align with dropdowns") end
			end
		end
	end
end

-- Speed / boost telemetry --------------------------------------------------
local telemetry = requireChild(root, "Telemetry", "GuiObject")
if telemetry then
	line("DATA", fmtGui(telemetry) .. " actualVisible=" .. tostring(isActuallyVisible(telemetry)))
	local mph = requireChild(telemetry, "Mph", "TextLabel")
	local unit = requireChild(telemetry, "Unit", "TextLabel")
	if mph then
		line("DATA", string.format("mph TextSize=%d bounds=%s", mph.TextSize, fmtGui(mph)))
		if mph.TextSize >= 58 then pass("Speed metric meets display-size target") else warn("Speed metric is too small; use the Metric typography role") end
	end
	if unit then
		line("DATA", string.format("unit TextSize=%d bounds=%s", unit.TextSize, fmtGui(unit)))
		if unit.TextSize >= 14 then pass("MPH unit meets label-size target") else warn("MPH unit is too small") end
	end
	local segments = {}
	for index = 1, 40 do
		local segment = telemetry:FindFirstChild("GaugeSegment" .. index)
		if segment and segment:IsA("GuiObject") then table.insert(segments, segment) end
	end
	if #segments >= 2 then
		pass("Found " .. tostring(#segments) .. " gauge segments")
		local first = segments[1]
		local last = segments[#segments]
		line("DATA", string.format("segment1 centre=%s rotation=%.1f", fmtVector(centre(first)), first.Rotation))
		line("DATA", string.format("segment%d centre=%s rotation=%.1f", #segments, fmtVector(centre(last)), last.Rotation))
		if centre(first).Y > centre(last).Y then
			pass("Gauge activation order starts at the bottom")
		else
			warn("Gauge activation order starts at the top; reverse/rebuild the segment sequence")
		end
		local viewport = camera and camera.ViewportSize or Vector2.new(math.huge, math.huge)
		local clipped = false
		for _, segment in ipairs(segments) do
			local angle = math.rad(segment.Rotation)
			local halfW = segment.AbsoluteSize.X * 0.5
			local halfH = segment.AbsoluteSize.Y * 0.5
			local extentX = math.abs(math.cos(angle)) * halfW + math.abs(math.sin(angle)) * halfH
			local extentY = math.abs(math.sin(angle)) * halfW + math.abs(math.cos(angle)) * halfH
			local c = centre(segment)
			if c.X - extentX < 0 or c.X + extentX > viewport.X or c.Y - extentY < 0 or c.Y + extentY > viewport.Y then
				clipped = true
			end
		end
		if clipped then warn("One or more rotated gauge segments extend beyond the viewport") else pass("Gauge segments fit inside the viewport") end
	else
		fail("Telemetry has fewer than two gauge segments")
	end
end

-- Modal typography and centring -------------------------------------------
local modalLayer = requireChild(root, "ModalLayer", "GuiObject")
if modalLayer then
	local teleport = modalLayer:FindFirstChild("Teleport")
	local cash = modalLayer:FindFirstChild("Cash")
	if teleport and teleport:IsA("GuiObject") then
		local title = teleport:FindFirstChild("Title")
		local message = teleport:FindFirstChild("Message")
		if title and title:IsA("TextLabel") and message and message:IsA("TextLabel") then
			line("DATA", string.format("teleport titleFont=%s messageFont=%s", title.Font.Name, message.Font.Name))
			if title.Font == message.Font then pass("Teleport typography uses one font family") else warn("Teleport description font differs from the UI font family") end
		end
	end
	if cash and cash:IsA("GuiObject") then
		local secure = cash:FindFirstChild("Secure")
		if secure and secure:IsA("TextLabel") then
			local deltaX = centre(secure).X - centre(cash).X
			line("DATA", string.format("cash secure centre deltaX=%.1f px", deltaX))
			if math.abs(deltaX) <= 2 then pass("Cash secure footer is centred") else warn("Cash secure footer is not centred in its panel") end
		else
			warn("Cash modal has no Secure footer label")
		end
	end
end

line("DONE", string.format("pass=%d warn=%d fail=%d", passCount, warnCount, failCount))
if failCount == 0 then
	line("NEXT", "Copy the complete Output into Codex. Warnings are measurements for Phase 2B, not install failures.")
else
	line("NEXT", "Resolve missing runtime objects/context before generating Phase 2B.")
end
