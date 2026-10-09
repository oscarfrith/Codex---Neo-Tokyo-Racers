-- UI restyle probe: layout_lint (datamodel: Client, Play). READ-ONLY.
-- Lints the GuiObjects that are effectively visible right now under LocalPlayer.PlayerGui and
-- reports the screen / input environment. Creates nothing, requires nothing, no raycasts.
-- "Visible" = ScreenGui.Enabled, every ancestor GuiObject.Visible, and the rectangle intersects
-- its ScreenGui and every ClipsDescendants ancestor. Transparency does not hide an element here.
local ARGS = {
	label = "",
	guis = nil,            -- nil = every enabled ScreenGui; or {"DesktopFreeRoamHud", ...}
	detail = false,        -- true = up to 40 examples per rule instead of maxExamples
	maxExamples = 6,       -- examples kept per rule (whole run)
	minTextSize = 14,      -- rule: effective text size (TextSize x ancestor UIScale) below this
	minTarget = 48,        -- rule: active GuiButton smaller than this in either axis
	minGap = 8,            -- rule: adjacent sibling buttons closer than this
	pixelTolerance = 0.01, -- rule: AbsolutePosition / AbsoluteSize further than this from an integer
	opaqueThreshold = 0.5, -- cover: a frame counts when its effective transparency is <= this
	gridX = 64, gridY = 36, -- cover: sample grid over each ScreenGui's own rectangle
	maxSiblingButtons = 80, -- overlap: parents with more button children than this are skipped
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ probe = "layout_lint", ok = false, error = "PlayerGui not found (run on the Client datamodel in Play)" })
end

local function try(fn)
	local ok, value = pcall(fn)
	if ok then
		return value
	end
	return nil
end

local function v2(value)
	return value and { value.X, value.Y } or nil
end

-- Environment ---------------------------------------------------------------------------------
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(0, 0)
local env = {
	cameraViewport = v2(viewport),
	guiInsetTopLeft = nil, guiInsetBottomRight = nil,
	topbarInset = try(function()
		local rect = GuiService.TopbarInset
		return { rect.Min.X, rect.Min.Y, rect.Max.X, rect.Max.Y }
	end),
	screenResolution = try(function() return v2(GuiService:GetScreenResolution()) end),
	preferredTextSize = try(function() return tostring(GuiService.PreferredTextSize) end),
	preferredTransparency = try(function() return GuiService.PreferredTransparency end),
	reducedMotion = try(function() return GuiService.ReducedMotionEnabled end),
	touchEnabled = try(function() return UserInputService.TouchEnabled end),
	keyboardEnabled = try(function() return UserInputService.KeyboardEnabled end),
	mouseEnabled = try(function() return UserInputService.MouseEnabled end),
	gamepadEnabled = try(function() return UserInputService.GamepadEnabled end),
	preferredInput = try(function() return tostring(UserInputService.PreferredInput) end),
	lastInputType = try(function() return tostring(UserInputService:GetLastInputType()) end),
	starterScreenOrientation = try(function() return tostring(StarterGui.ScreenOrientation) end),
	currentScreenOrientation = try(function() return tostring(playerGui.CurrentScreenOrientation) end),
}
pcall(function()
	local topLeft, bottomRight = GuiService:GetGuiInset()
	env.guiInsetTopLeft = v2(topLeft)
	env.guiInsetBottomRight = v2(bottomRight)
end)

-- Helpers -------------------------------------------------------------------------------------
local tolerance = ARGS.pixelTolerance or 0.01
local function offInteger(value)
	return math.abs(value - math.floor(value + 0.5)) > tolerance
end

local function relativePath(item)
	local parts = {}
	local current = item
	while current and current ~= playerGui do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local exampleLimit = ARGS.detail and 40 or (ARGS.maxExamples or 6)
local examples = {}
local function example(rule, item, info)
	local list = examples[rule]
	if not list then
		list = {}
		examples[rule] = list
	end
	if #list < exampleLimit then
		info.path = relativePath(item)
		table.insert(list, info)
	end
end

local function round2(value)
	return math.floor(value * 100 + 0.5) / 100
end

local GRID_X = ARGS.gridX or 64
local GRID_Y = ARGS.gridY or 36

local function markGrid(grid, frame, x0, y0, x1, y1)
	-- A cell is covered when its centre lies inside the rectangle.
	local ix0 = math.max(0, math.ceil((x0 - frame.x) / frame.w * GRID_X - 0.5))
	local ix1 = math.min(GRID_X - 1, math.ceil((x1 - frame.x) / frame.w * GRID_X - 0.5) - 1)
	local iy0 = math.max(0, math.ceil((y0 - frame.y) / frame.h * GRID_Y - 0.5))
	local iy1 = math.min(GRID_Y - 1, math.ceil((y1 - frame.y) / frame.h * GRID_Y - 0.5) - 1)
	for iy = iy0, iy1 do
		local base = iy * GRID_X + 1
		for ix = ix0, ix1 do
			grid[base + ix] = true
		end
	end
end

local function gridPercent(grid)
	local covered = 0
	for index = 1, GRID_X * GRID_Y do
		if grid[index] then
			covered += 1
		end
	end
	return round2(covered / (GRID_X * GRID_Y) * 100)
end

-- Walk ----------------------------------------------------------------------------------------
local minGap = ARGS.minGap or 8
local minTarget = ARGS.minTarget or 48
local minTextSize = ARGS.minTextSize or 14
local threshold = ARGS.opaqueThreshold or 0.5

local function lintSiblings(report, buttons)
	if #buttons < 2 then
		return
	end
	if #buttons > (ARGS.maxSiblingButtons or 80) then
		report.siblingGroupsSkipped += 1
		return
	end
	for i = 1, #buttons - 1 do
		local a = buttons[i]
		for j = i + 1, #buttons do
			local b = buttons[j]
			local dx = math.max(a.x0 - b.x1, b.x0 - a.x1)
			local dy = math.max(a.y0 - b.y1, b.y0 - a.y1)
			if dx < -0.5 and dy < -0.5 then
				report.overlappingButtons += 1
				example("overlappingButtons", a.item, { other = b.item.Name, overlap = { round2(-dx), round2(-dy) } })
			elseif math.max(dx, dy) < minGap and math.min(dx, dy) < -0.5 then
				report.closeButtons += 1
				example("closeButtons", a.item, { other = b.item.Name, gap = round2(math.max(dx, dy)) })
			end
		end
	end
end

local function walk(report, frame, item, visible, alpha, scale, clip)
	local buttons = nil
	for _, child in ipairs(item:GetChildren()) do
		if child:IsA("GuiObject") then
			local childVisible = visible and child.Visible
			local position = child.AbsolutePosition
			local size = child.AbsoluteSize
			local x0, y0 = position.X, position.Y
			local x1, y1 = x0 + size.X, y0 + size.Y
			local childAlpha = alpha
			if child:IsA("CanvasGroup") then
				childAlpha = alpha * (1 - child.GroupTransparency)
			end
			local childScale = scale
			local uiScale = child:FindFirstChildOfClass("UIScale")
			if uiScale then
				childScale = scale * uiScale.Scale
			end
			-- Clipped rectangle (what can actually be seen).
			local cx0, cy0, cx1, cy1 = math.max(x0, clip.x0), math.max(y0, clip.y0), math.min(x1, clip.x1), math.min(y1, clip.y1)
			local onScreen = cx1 > cx0 and cy1 > cy0
			if childVisible and not onScreen and size.X > 0 and size.Y > 0 then
				report.clippedOrOffscreen += 1
			end
			if childVisible and onScreen then
				report.visibleGuiObjects += 1
				-- Rule: whole pixels.
				if offInteger(x0) or offInteger(y0) or offInteger(size.X) or offInteger(size.Y) then
					report.nonInteger += 1
					example("nonInteger", child, { pos = { x0, y0 }, size = { size.X, size.Y } })
				end
				-- Rules: text.
				if (child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox")) and child.Text ~= "" and child.TextTransparency < 1 then
					report.visibleText += 1
					if child.TextScaled then
						report.textScaled += 1
						example("textScaled", child, { boundsY = round2(child.TextBounds.Y) })
					else
						local effective = child.TextSize * childScale
						if not report.minTextSize or effective < report.minTextSize then
							report.minTextSize = round2(effective)
						end
						if effective < minTextSize - 0.01 then
							report.smallText += 1
							example("smallText", child, { textSize = child.TextSize, effective = round2(effective), text = string.sub(child.Text, 1, 24) })
						end
					end
					if not child.TextFits then
						report.textOverflow += 1
						example("textOverflow", child, { size = { size.X, size.Y }, textSize = child.TextSize, text = string.sub(child.Text, 1, 24) })
					end
				end
				-- Rules: touch targets.
				if child:IsA("GuiButton") and child.Active then
					local interactable = true
					pcall(function()
						interactable = child.Interactable
					end)
					if interactable then
						report.activeButtons += 1
						if size.X < minTarget - 0.01 or size.Y < minTarget - 0.01 then
							report.smallTargets += 1
							example("smallTargets", child, { size = { round2(size.X), round2(size.Y) } })
						end
						buttons = buttons or {}
						table.insert(buttons, { item = child, x0 = x0, y0 = y0, x1 = x1, y1 = y1 })
					end
				end
				-- Rule: hairlines.
				for _, modifier in ipairs(child:GetChildren()) do
					if modifier:IsA("UIStroke") and modifier.Enabled and offInteger(modifier.Thickness * childScale) then
						report.fractionalStrokes += 1
						example("fractionalStrokes", child, { thickness = modifier.Thickness, scale = round2(childScale) })
					end
				end
				-- Cover.
				local background = (1 - child.BackgroundTransparency) * childAlpha
				local image = 0
				if (child:IsA("ImageLabel") or child:IsA("ImageButton")) and child.Image ~= "" then
					image = (1 - child.ImageTransparency) * childAlpha
				end
				local opacity = math.max(background, image)
				local area = (cx1 - cx0) * (cy1 - cy0)
				local full = area >= 0.9 * frame.w * frame.h
				if full and opacity > 0.02 then
					report.fullScreenLayers += 1
					if opacity < 0.98 then
						report.translucentFullScreenLayers += 1
					end
					example("fullScreenLayers", child, { opacity = round2(opacity), class = child.ClassName })
				end
				if opacity >= 1 - threshold then
					markGrid(report.gridAll, frame, cx0, cy0, cx1, cy1)
					if not full then
						markGrid(report.gridPanels, frame, cx0, cy0, cx1, cy1)
					end
				end
			end
			local childClip = clip
			if child.ClipsDescendants then
				childClip = { x0 = cx0, y0 = cy0, x1 = math.max(cx0, cx1), y1 = math.max(cy0, cy1) }
			end
			walk(report, frame, child, childVisible, childAlpha, childScale, childClip)
		elseif not child:IsA("UIBase") then
			-- Folders and similar containers: pass the state straight through.
			walk(report, frame, child, visible, alpha, scale, clip)
		end
	end
	if buttons then
		lintSiblings(report, buttons)
	end
end

local wanted = nil
if ARGS.guis then
	wanted = {}
	for _, name in ipairs(ARGS.guis) do
		wanted[name] = true
	end
end

local result = {
	probe = "layout_lint", ok = true, label = ARGS.label, env = env, guis = {}, disabled = {},
	rules = { minTextSize = minTextSize, minTarget = minTarget, minGap = minGap, pixelTolerance = tolerance, opaqueThreshold = threshold, grid = { GRID_X, GRID_Y } },
	totals = {},
}

local countKeys = {
	"visibleGuiObjects", "visibleText", "nonInteger", "smallText", "textScaled", "textOverflow",
	"activeButtons", "smallTargets", "overlappingButtons", "closeButtons", "fractionalStrokes",
	"fullScreenLayers", "translucentFullScreenLayers", "clippedOrOffscreen", "siblingGroupsSkipped",
}
for _, key in ipairs(countKeys) do
	result.totals[key] = 0
end

for _, gui in ipairs(playerGui:GetChildren()) do
	if gui:IsA("ScreenGui") and (not wanted or wanted[gui.Name]) then
		if not gui.Enabled then
			table.insert(result.disabled, gui.Name)
		else
			local position = gui.AbsolutePosition
			local size = gui.AbsoluteSize
			local frame = { x = position.X, y = position.Y, w = size.X, h = size.Y }
			if frame.w <= 0 or frame.h <= 0 then
				frame = { x = 0, y = 0, w = math.max(1, viewport.X), h = math.max(1, viewport.Y) }
			end
			local report = { gridAll = {}, gridPanels = {} }
			for _, key in ipairs(countKeys) do
				report[key] = 0
			end
			local uiScale = gui:FindFirstChildOfClass("UIScale")
			walk(report, frame, gui, true, 1, uiScale and uiScale.Scale or 1, { x0 = frame.x, y0 = frame.y, x1 = frame.x + frame.w, y1 = frame.y + frame.h })
			local entry = {
				name = gui.Name, displayOrder = gui.DisplayOrder, ignoreGuiInset = gui.IgnoreGuiInset,
				screenInsets = try(function() return tostring(gui.ScreenInsets) end),
				clipToDeviceSafeArea = try(function() return gui.ClipToDeviceSafeArea end),
				safeAreaCompatibility = try(function() return tostring(gui.SafeAreaCompatibility) end),
				absPos = { position.X, position.Y }, absSize = { size.X, size.Y },
				coverPct = gridPercent(report.gridAll), panelCoverPct = gridPercent(report.gridPanels),
				minTextSize = report.minTextSize,
			}
			for _, key in ipairs(countKeys) do
				entry[key] = report[key]
				result.totals[key] += report[key]
			end
			if viewport.X > 0 and viewport.Y > 0 then
				-- Same cover figures expressed against the whole camera viewport.
				local share = (frame.w * frame.h) / (viewport.X * viewport.Y)
				entry.panelCoverPctOfViewport = round2(entry.panelCoverPct * share)
			end
			table.insert(result.guis, entry)
		end
	end
end

table.sort(result.guis, function(a, b)
	if a.displayOrder == b.displayOrder then
		return a.name < b.name
	end
	return a.displayOrder < b.displayOrder
end)

result.examples = examples
result.touchRulesApply = env.touchEnabled == true
result.notes = {
	"coverPct counts every opaque-ish rectangle; panelCoverPct leaves out rectangles covering 90% or more of the ScreenGui (shades, backdrops)",
	"smallTargets, closeButtons and overlappingButtons are computed on every device; they are budget failures only when touchRulesApply is true",
	"TextScaled text has no fixed size: it is listed under textScaled and left out of smallText",
}

return HttpService:JSONEncode(result)
