-- UI restyle probe: instance_census (datamodel: Client, Play). READ-ONLY.
-- Counts what is under each ScreenGui of LocalPlayer.PlayerGui. Creates nothing, requires nothing.
local ARGS = {
	label = "",        -- free text copied into the result
	guis = nil,        -- nil = every LayerCollector under PlayerGui; or {"DesktopFreeRoamHud", ...}
	detail = false,    -- true adds per-gui subtree counts (children down to `depth`)
	depth = 2,         -- subtree depth for detail
	root = nil,        -- optional "Gui.Child.Sub" path: census that subtree only (as one entry)
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ probe = "instance_census", ok = false, error = "PlayerGui not found (run on the Client datamodel in Play)" })
end

local function resolve(path)
	local item = playerGui
	for part in string.gmatch(path, "[^%.]+") do
		item = item and item:FindFirstChild(part)
	end
	return item
end

local function sortedKeys(map)
	local keys = {}
	for key in pairs(map) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		if type(a) == "number" and type(b) == "number" then
			return a < b
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function fontKey(item)
	local ok, value = pcall(function()
		local face = item.FontFace
		local family = string.match(face.Family, "([^/]+)%.json$") or face.Family
		local key = family .. "-" .. face.Weight.Name
		if face.Style ~= Enum.FontStyle.Normal then
			key = key .. "-" .. face.Style.Name
		end
		return key
	end)
	return ok and value or "?"
end

local function isShadowLike(item)
	local name = string.lower(item.Name)
	return string.find(name, "shadow", 1, true) ~= nil or string.find(name, "glow", 1, true) ~= nil
end

local function newTally()
	return {
		count = 0, visible = 0, byClass = {}, strokes = 0, gradients = 0, corners = 0,
		canvasGroups = 0, shadowLike = 0, textSizes = {}, fonts = {}, textScaledVisible = 0,
		visibleText = 0, guiObjects = 0, visibleGuiObjects = 0,
	}
end

local function tallyOne(tally, item, visible)
	tally.count += 1
	local class = item.ClassName
	tally.byClass[class] = (tally.byClass[class] or 0) + 1
	if class == "UIStroke" then
		tally.strokes += 1
	elseif class == "UIGradient" then
		tally.gradients += 1
	elseif class == "UICorner" then
		tally.corners += 1
	elseif class == "CanvasGroup" then
		tally.canvasGroups += 1
	end
	if isShadowLike(item) then
		tally.shadowLike += 1
	end
	if visible then
		tally.visible += 1
	end
	if item:IsA("GuiObject") then
		tally.guiObjects += 1
		if visible then
			tally.visibleGuiObjects += 1
			if (item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")) and item.Text ~= "" and item.TextTransparency < 1 then
				tally.visibleText += 1
				if item.TextScaled then
					tally.textScaledVisible += 1
				else
					tally.textSizes[item.TextSize] = (tally.textSizes[item.TextSize] or 0) + 1
				end
				local key = fontKey(item)
				tally.fonts[key] = (tally.fonts[key] or 0) + 1
			end
		end
	end
end

-- parentVisible is the effective visibility of the parent chain (ScreenGui.Enabled and every GuiObject.Visible).
local function walk(tally, item, parentVisible)
	for _, child in ipairs(item:GetChildren()) do
		local visible = parentVisible
		if child:IsA("GuiObject") then
			visible = parentVisible and child.Visible
		end
		tallyOne(tally, child, visible)
		walk(tally, child, visible)
	end
end

local function effectiveVisible(item)
	local current = item
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("LayerCollector") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return true
end

local function finish(tally)
	local sizes = {}
	for _, size in ipairs(sortedKeys(tally.textSizes)) do
		table.insert(sizes, { size, tally.textSizes[size] })
	end
	local fonts = {}
	for _, key in ipairs(sortedKeys(tally.fonts)) do
		table.insert(fonts, { key, tally.fonts[key] })
	end
	tally.textSizes = sizes
	tally.distinctTextSizes = #sizes
	tally.fonts = fonts
	return tally
end

local function subtrees(item, parentVisible, depth, prefix, out)
	for _, child in ipairs(item:GetChildren()) do
		local visible = parentVisible
		if child:IsA("GuiObject") then
			visible = parentVisible and child.Visible
		end
		local tally = newTally()
		tallyOne(tally, child, visible)
		walk(tally, child, visible)
		local path = prefix .. child.Name
		if tally.count > 1 or child:IsA("GuiObject") then
			table.insert(out, { path = path, class = child.ClassName, count = tally.count, visible = tally.visible, shown = visible })
		end
		if depth > 1 then
			subtrees(child, visible, depth - 1, path .. ".", out)
		end
	end
end

local result = {
	probe = "instance_census", ok = true, label = ARGS.label, clock = os.clock(),
	guis = {}, other = {},
	totals = { guis = 0, enabledGuis = 0, count = 0, visible = 0, strokes = 0, gradients = 0, corners = 0, canvasGroups = 0, shadowLike = 0 },
}

local wanted = nil
if ARGS.guis then
	wanted = {}
	for _, name in ipairs(ARGS.guis) do
		wanted[name] = true
	end
end

local allSizes = {}
local allFonts = {}

local function addEntry(name, item, visibleAtRoot, extra)
	local tally = newTally()
	walk(tally, item, visibleAtRoot)
	for size, n in pairs(tally.textSizes) do
		allSizes[size] = (allSizes[size] or 0) + n
	end
	for key, n in pairs(tally.fonts) do
		allFonts[key] = (allFonts[key] or 0) + n
	end
	finish(tally)
	tally.name = name
	tally.class = item.ClassName
	for key, value in pairs(extra or {}) do
		tally[key] = value
	end
	if ARGS.detail then
		local list = {}
		subtrees(item, visibleAtRoot, math.max(1, ARGS.depth or 2), "", list)
		table.sort(list, function(a, b) return a.count > b.count end)
		while #list > 60 do
			table.remove(list)
			tally.subtreesTruncated = true
		end
		tally.subtrees = list
	end
	local totals = result.totals
	totals.count += tally.count
	totals.visible += tally.visible
	totals.strokes += tally.strokes
	totals.gradients += tally.gradients
	totals.corners += tally.corners
	totals.canvasGroups += tally.canvasGroups
	totals.shadowLike += tally.shadowLike
	table.insert(result.guis, tally)
end

if ARGS.root then
	local item = resolve(ARGS.root)
	if not item then
		return HttpService:JSONEncode({ probe = "instance_census", ok = false, error = "root not found: " .. tostring(ARGS.root) })
	end
	addEntry(ARGS.root, item, effectiveVisible(item), { isRoot = true })
else
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("LayerCollector") then
			if not wanted or wanted[child.Name] then
				result.totals.guis += 1
				if child.Enabled then
					result.totals.enabledGuis += 1
				end
				local extra = { enabled = child.Enabled }
				if child:IsA("ScreenGui") then
					extra.displayOrder = child.DisplayOrder
					extra.ignoreGuiInset = child.IgnoreGuiInset
					extra.resetOnSpawn = child.ResetOnSpawn
				end
				addEntry(child.Name, child, child.Enabled, extra)
			end
		else
			table.insert(result.other, { name = child.Name, class = child.ClassName, count = #child:GetDescendants() })
		end
	end
end

table.sort(result.guis, function(a, b)
	if a.name == b.name then
		return a.count > b.count
	end
	return a.name < b.name
end)

local sizeList = {}
for _, size in ipairs(sortedKeys(allSizes)) do
	table.insert(sizeList, { size, allSizes[size] })
end
local fontList = {}
for _, key in ipairs(sortedKeys(allFonts)) do
	table.insert(fontList, { key, allFonts[key] })
end
result.totals.visibleTextSizes = sizeList
result.totals.distinctVisibleTextSizes = #sizeList
result.totals.visibleFonts = fontList

return HttpService:JSONEncode(result)
