-- Neo Tokyo Racers - Canonical garage responsive Phase 0 audit
-- READ ONLY. This script does not change Instances, Attributes, or source code.
--
-- Run the same script in either context:
--   1. Edit Command Bar: audits ownership/source contracts and simulates the
--      supported desktop, tablet, and phone viewports.
--   2. Play Client Command Bar, with a canonical garage page open: audits the
--      actual visible geometry, scaling, clipping, overlaps, and touch targets.

local RunService = game:GetService("RunService")

local MODE = "AUTO" -- AUTO, STATIC, or RUNTIME
if MODE == "AUTO" then
	MODE = RunService:IsRunning() and "RUNTIME" or "STATIC"
end

local PREFIX = "[NTR Garage Responsive Phase 0]"
local counts = {PASS = 0, WARN = 0, BLOCKER = 0}

local function report(level, message)
	counts[level] += 1
	print(string.format("%s %s %s", PREFIX, level, message))
end

local function finish()
	print(string.format(
		"%s RESULT mode=%s pass=%d warn=%d blocker=%d",
		PREFIX,
		MODE,
		counts.PASS,
		counts.WARN,
		counts.BLOCKER
	))
	if counts.BLOCKER == 0 then
		print(PREFIX .. " GATE PASS: responsive implementation may be prepared from this live baseline.")
	else
		print(PREFIX .. " GATE BLOCKED: keep the desktop baseline unchanged and resolve the reported responsive contracts first.")
	end
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function getPath(root, path)
	local cursor = root
	for segment in string.gmatch(path, "[^.]+") do
		cursor = cursor and cursor:FindFirstChild(segment)
	end
	return cursor
end

local function hasPlain(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local function sourceOf(instance)
	local ok, source = pcall(function()
		return instance.Source
	end)
	return ok and source or nil
end

local function staticAudit()
	local StarterPlayer = game:GetService("StarterPlayer")
	local clientRoot = getPath(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient")
	if not clientRoot then
		report("BLOCKER", "NeoTokyoRacersClient is missing from StarterPlayerScripts.")
		finish()
		return
	end

	local uiRoot = getPath(clientRoot, "Controllers.UI")
	local shared = uiRoot and uiRoot:FindFirstChild("GarageReplacementComponents")
	local browser = uiRoot and uiRoot:FindFirstChild("GarageBrowserController")
	local workspace = uiRoot and uiRoot:FindFirstChild("GarageWorkspaceController")
	local experience = uiRoot and uiRoot:FindFirstChild("GarageExperienceController_Active")

	local required = {
		{"shared GarageReplacementComponents", shared},
		{"GarageBrowserController", browser},
		{"GarageWorkspaceController", workspace},
		{"GarageExperienceController_Active", experience},
	}
	for _, item in ipairs(required) do
		if item[2] then
			report("PASS", item[1] .. " exists in the canonical UI controller root.")
		else
			report("BLOCKER", item[1] .. " is missing; do not build a responsive layer over an incomplete owner graph.")
		end
	end
	if not (shared and browser and workspace) then
		finish()
		return
	end

	local sharedSource = sourceOf(shared)
	local browserSource = sourceOf(browser)
	local workspaceSource = sourceOf(workspace)
	local experienceSource = experience and sourceOf(experience) or ""
	if not (sharedSource and browserSource and workspaceSource) then
		report("BLOCKER", "Studio did not expose one or more canonical sources in this context; rerun from the Edit Command Bar.")
		finish()
		return
	end

	if hasPlain(sharedSource, "function M.LayoutGarageShell") then
		report("PASS", "Browser and workspace have a reusable shared shell layout owner.")
	else
		report("BLOCKER", "Shared LayoutGarageShell contract is missing.")
	end
	if hasPlain(browserSource, "Shared.LayoutGarageShell") and hasPlain(workspaceSource, "Shared.LayoutGarageShell") then
		report("PASS", "Browser and workspace both call the same shared shell layout.")
	else
		report("BLOCKER", "Browser/workspace do not both consume Shared.LayoutGarageShell.")
	end
	if hasPlain(sharedSource, "CanonicalGarageGui") and hasPlain(sharedSource, "CanonicalScale") then
		report("PASS", "Canonical garage uses one host and one shared UIScale owner.")
	else
		report("BLOCKER", "Canonical host/UIScale ownership marker is missing.")
	end
	if hasPlain(browserSource, "ViewportSize") and hasPlain(workspaceSource, "ViewportSize") then
		report("PASS", "Both canonical pages relayout when the camera viewport changes.")
	else
		report("BLOCKER", "A canonical page lacks a ViewportSize relayout listener.")
	end
	if hasPlain(browserSource, "ScrollingFrame") and hasPlain(workspaceSource, "ScrollingFrame") then
		report("PASS", "Vehicle/module rails retain native scrolling ownership for touch swipes.")
	else
		report("WARN", "One page has no explicit ScrollingFrame marker; verify swipe ownership before mobile install.")
	end

	local hasSafeArea = hasPlain(sharedSource, "DeviceSafeInsets")
		or hasPlain(sharedSource, "ScreenInsets")
		or hasPlain(sharedSource, "GetGuiInset")
		or hasPlain(browserSource, "DeviceSafeInsets")
		or hasPlain(workspaceSource, "DeviceSafeInsets")
	if hasSafeArea then
		report("PASS", "Canonical garage already has an explicit safe-area contract.")
	else
		report("BLOCKER", "No canonical safe-area/inset contract exists while CanonicalGarageGui ignores the Roblox inset.")
	end

	if hasPlain(experienceSource, "NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE") then
		report("PASS", "Confirmed transient preview lifecycle marker is present in the live app controller.")
	else
		report("WARN", "Transient preview lifecycle marker was not found; confirm the latest working app controller before a responsive installer.")
	end
	if hasPlain(workspaceSource, "NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING")
		or hasPlain(experienceSource, "NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING") then
		report("PASS", "Path-local upgrade pricing marker remains present.")
	else
		report("WARN", "Path-local pricing marker was not visible in the canonical client sources.")
	end

	local config = getPath(game:GetService("ReplicatedStorage"), "NeoTokyoRacers.Config.UI.GarageReplacement")
	local function configNumber(name, fallback)
		local value = config and config:GetAttribute(name)
		return type(value) == "number" and value or fallback
	end

	local baseWidth = configNumber("BaseWidth", 1600)
	local baseHeight = configNumber("BaseHeight", 900)
	local maxScale = configNumber("MaxScale", 1.02)
	local desktopMinimum = configNumber("DesktopMinScale", 0.68)
	local touchMinimum = configNumber("MobileMinScale", 0.42)
	local margin = 18
	local gap = 14
	local headerWidth = 420
	local headerHeight = 62
	local categoryWidth = configNumber("ModuleCategoryRailWidth", 238)
	local statsWidth = configNumber("StatsWidth", 354)
	local carouselHeight = 166
	local categoryClearance = configNumber("CategoryCarouselClearance", 82)
	local visualActionHeight = 30
	local moduleTextSize = 13

	print(string.format(
		"%s CONFIG base=%dx%d desktopMin=%.3f touchMin=%.3f max=%.3f statsW=%.0f categoryW=%.0f",
		PREFIX,
		baseWidth,
		baseHeight,
		desktopMinimum,
		touchMinimum,
		maxScale,
		statsWidth,
		categoryWidth
	))

	local profiles = {
		{name = "Desktop 1920x1080", width = 1920, height = 1080, touch = false},
		{name = "Laptop 1366x768", width = 1366, height = 768, touch = false},
		{name = "Tablet 1280x800", width = 1280, height = 800, touch = true},
		{name = "Tablet 1024x768", width = 1024, height = 768, touch = true},
		{name = "Phone 915x412", width = 915, height = 412, touch = true},
		{name = "Phone 844x390", width = 844, height = 390, touch = true},
		{name = "Phone 740x360", width = 740, height = 360, touch = true},
		{name = "Small phone 667x375", width = 667, height = 375, touch = true},
	}

	for _, profile in ipairs(profiles) do
		local fitScale = math.min(profile.width / baseWidth, profile.height / baseHeight)
		local minimum = profile.touch and touchMinimum or desktopMinimum
		local scale = clamp(fitScale, minimum, maxScale)
		local virtualWidth = profile.width / scale
		local virtualHeight = profile.height / scale
		local carouselTop = virtualHeight - margin - carouselHeight
		local headerLeft = (virtualWidth - headerWidth) * 0.5
		local headerRight = headerLeft + headerWidth
		local categoryRight = margin + categoryWidth
		local statsLeft = virtualWidth - margin - statsWidth
		local categoryBottom = 72 + math.max(170, carouselTop - 72 - categoryClearance)
		local shellGapLeft = headerLeft - categoryRight
		local shellGapRight = statsLeft - headerRight
		local forcedOverflow = scale > fitScale + 0.0005
		local shellFits = shellGapLeft >= gap and shellGapRight >= gap and categoryBottom <= carouselTop - 1

		print(string.format(
			"%s PROFILE %s fit=%.3f applied=%.3f virtual=%.1fx%.1f actionPx=%.1f textPx=%.1f",
			PREFIX,
			profile.name,
			fitScale,
			scale,
			virtualWidth,
			virtualHeight,
			visualActionHeight * scale,
			moduleTextSize * scale
		))

		if shellFits then
			report("PASS", profile.name .. " keeps header, left rail, right rail, and carousel separated in the shared shell model.")
		else
			report("BLOCKER", profile.name .. " produces a shell overlap before safe-area padding is applied.")
		end
		if forcedOverflow then
			report("BLOCKER", profile.name .. " is forced above its fit scale by the current minimum and can clip the canonical canvas.")
		end
		if profile.touch and visualActionHeight * scale < 44 then
			report("BLOCKER", profile.name .. " scales essential 30px actions below a 44px touch target; invisible hit-target padding is required.")
		end
		if profile.touch and moduleTextSize * scale < 10 then
			report("WARN", profile.name .. " scales 13px module copy below 10px; preserve layout but add a touch readability floor.")
		end
	end

	report("PASS", "Static audit made no changes. Responsive work can remain one shared tree with profile-driven scaling and hit targets.")
	finish()
end

local function rectanglesOverlap(a, b)
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

local function rectOf(object)
	local position = object.AbsolutePosition
	local size = object.AbsoluteSize
	return {x = position.X, y = position.Y, w = size.X, h = size.Y}
end

local function runtimeAudit()
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = Players.LocalPlayer
	if not player then
		report("BLOCKER", "Runtime audit must be run from the Play Client Command Bar.")
		finish()
		return
	end

	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new()
	local gui = player:FindFirstChildOfClass("PlayerGui") and player.PlayerGui:FindFirstChild("CanonicalGarageGui")
	local canvas = gui and gui:FindFirstChild("CanonicalCanvas")
	local scale = canvas and canvas:FindFirstChild("CanonicalScale")
	print(string.format(
		"%s RUNTIME viewport=%dx%d touch=%s insetIgnored=%s scale=%s",
		PREFIX,
		viewport.X,
		viewport.Y,
		tostring(UserInputService.TouchEnabled),
		tostring(gui and gui.IgnoreGuiInset),
		tostring(scale and scale.Scale)
	))

	if not (gui and canvas and scale) then
		report("BLOCKER", "CanonicalGarageGui/CanonicalCanvas/CanonicalScale is not active.")
		finish()
		return
	end

	local visibleRoots = {}
	for _, child in ipairs(canvas:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			table.insert(visibleRoots, child)
		end
	end
	if #visibleRoots ~= 1 then
		report("BLOCKER", string.format("Expected exactly one visible canonical page root, found %d.", #visibleRoots))
		finish()
		return
	end
	local root = visibleRoots[1]
	report("PASS", "Single visible canonical presentation root: " .. root:GetFullName())

	local targets = {"Header", "Categories", "Right", "Carousel", "Previous", "Next", "Back", "Continue", "Exit", "UpgradeBudget"}
	local visibleTargets = {}
	for _, name in ipairs(targets) do
		local object = root:FindFirstChild(name, true)
		if object and object:IsA("GuiObject") and object.Visible then
			visibleTargets[name] = object
			local rect = rectOf(object)
			print(string.format("%s RECT %s x=%.1f y=%.1f w=%.1f h=%.1f", PREFIX, name, rect.x, rect.y, rect.w, rect.h))
			if rect.x < -1 or rect.y < -1 or rect.x + rect.w > viewport.X + 1 or rect.y + rect.h > viewport.Y + 1 then
				report("BLOCKER", name .. " extends beyond the physical viewport.")
			else
				report("PASS", name .. " is inside the physical viewport.")
			end
		end
	end

	local overlapPairs = {
		{"Header", "Categories"},
		{"Header", "Right"},
		{"Categories", "Carousel"},
		{"Right", "Carousel"},
		{"UpgradeBudget", "Carousel"},
	}
	for _, pair in ipairs(overlapPairs) do
		local first = visibleTargets[pair[1]]
		local second = visibleTargets[pair[2]]
		if first and second then
			if rectanglesOverlap(rectOf(first), rectOf(second)) then
				report("BLOCKER", pair[1] .. " overlaps " .. pair[2] .. ".")
			else
				report("PASS", pair[1] .. " is separated from " .. pair[2] .. ".")
			end
		end
	end

	local popup = root:FindFirstChild("CardActionPopup", true)
	if popup and popup:IsA("GuiObject") and popup.Visible then
		local popupRect = rectOf(popup)
		print(string.format("%s RECT CardActionPopup x=%.1f y=%.1f w=%.1f h=%.1f", PREFIX, popupRect.x, popupRect.y, popupRect.w, popupRect.h))
		if visibleTargets.UpgradeBudget and rectanglesOverlap(popupRect, rectOf(visibleTargets.UpgradeBudget)) then
			report("BLOCKER", "Card action popup overlaps the upgrade budget strip.")
		else
			report("PASS", "Visible card action popup does not overlap the upgrade budget strip.")
		end
	end

	local smallestButton
	local smallestArea = math.huge
	local visibleButtonCount = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Visible and descendant.Active then
			visibleButtonCount += 1
			local size = descendant.AbsoluteSize
			local area = size.X * size.Y
			if area < smallestArea then
				smallestArea = area
				smallestButton = descendant
			end
		end
	end
	if smallestButton then
		local size = smallestButton.AbsoluteSize
		print(string.format("%s TOUCH smallest=%s size=%.1fx%.1f visibleButtons=%d", PREFIX, smallestButton:GetFullName(), size.X, size.Y, visibleButtonCount))
		if UserInputService.TouchEnabled and (size.X < 44 or size.Y < 44) then
			report("BLOCKER", "At least one active touch control is below 44x44 physical pixels.")
		else
			report("PASS", "Visible active control geometry meets the runtime target check.")
		end
	else
		report("WARN", "No visible active GuiButtons were found under the page root.")
	end

	local topLeft, bottomRight = GuiService:GetGuiInset()
	print(string.format(
		"%s INSET topLeft=(%.1f,%.1f) bottomRight=(%.1f,%.1f)",
		PREFIX,
		topLeft.X,
		topLeft.Y,
		bottomRight.X,
		bottomRight.Y
	))
	if gui.IgnoreGuiInset and topLeft.Magnitude > 0 then
		report("WARN", "The canonical ScreenGui ignores a non-zero Roblox inset; the responsive owner must apply an explicit safe-area offset.")
	else
		report("PASS", "No unresolved Roblox inset was detected for this runtime viewport.")
	end

	report("PASS", "Runtime audit made no changes.")
	finish()
end

if MODE == "STATIC" then
	staticAudit()
elseif MODE == "RUNTIME" then
	runtimeAudit()
else
	error(PREFIX .. " MODE must be AUTO, STATIC, or RUNTIME")
end
