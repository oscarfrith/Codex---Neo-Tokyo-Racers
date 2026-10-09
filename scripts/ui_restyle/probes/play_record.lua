-- UI restyle probe: play_record (datamodel: Client, Play). READ-ONLY.
-- The Classic "Play record" of plan 1.8: for the current moment, one line per ScreenGui with a
-- stable hash of what it holds, plus ClientBase.StartupState and the console error set.
-- Save the returned JSON as <label>.<run>.json and compare runs with play_record_diff.py.
--
-- Hash: FNV-1a 32 (bit32 / exact double arithmetic) over a Merkle walk. Each instance hashes its
-- descriptor plus the SORTED hashes of its children, so child order does not matter.
--   hash    = every instance, shown or not
--   visHash = only instances that are effectively visible (ScreenGui.Enabled and ancestors Visible)
-- Descriptor fields: class, name, Visible, geometry, anchor, colours, transparencies, ZIndex,
-- rotation, text, font, TextSize, image; UIStroke / UICorner / UIGradient / UIScale / UIPadding /
-- UIListLayout / constraints contribute their main properties; everything else class and name.
-- Normalised: runs of digits in text become "#" (Cash, timers, speeds, ids), the local player's
-- name and display name become "<player>", the UserId in image URLs becomes "<uid>", geometry is
-- rounded to whole pixels, transparency to 2 places.
local ARGS = {
	label = "",            -- capture point, e.g. "03_driving_hud"
	run = "",              -- e.g. "a" / "b" for the two Phase 0 runs
	geometry = "absolute", -- "absolute" (AbsolutePosition/AbsoluteSize), "udim" (Size/Position), "both", "none"
	ignore = {
		guis = {},         -- ScreenGui names left out completely, e.g. {"DriveToEarnCashTelemetry"}
		names = {},        -- Lua patterns matched against instance Name; a match drops that whole subtree,
		                   -- e.g. {"^MapCanvas$", "^PlayerMarker$", "^Vehicle_", "^GaugeSegment"}
		fields = {},       -- descriptor fields dropped everywhere: any of "geometry", "colour",
		                   -- "transparency", "text", "font", "image", "visible", "zindex", "modifiers"
	},
	detail = nil,          -- nil, or { gui = "DesktopFreeRoamHud", root = "DesignRoot.LeftCluster", depth = 2,
	                       --           descriptors = false } : per-instance hashes under that root (root optional)
	maxDetail = 220,       -- cap on detail rows
	errors = true,         -- include the distinct console errors / warnings so far (LogService history)
	attributes = true,     -- include the Player's attributes (state flags used as "arrived" checks)
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ probe = "play_record", ok = false, error = "PlayerGui not found (run on the Client datamodel in Play)" })
end

-- FNV-1a 32 -----------------------------------------------------------------------------------
local PRIME = 16777619
local function fnv(text)
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, index))
		-- (hash * PRIME) mod 2^32 without leaving exact double range.
		local low = hash % 65536
		local high = (hash - low) / 65536
		hash = (low * PRIME + ((high * PRIME) % 65536) * 65536) % 4294967296
	end
	return hash
end

-- Normalisers ---------------------------------------------------------------------------------
local ignore = ARGS.ignore or {}
local dropField = {}
for _, field in ipairs(ignore.fields or {}) do
	dropField[field] = true
end
local ignoreGui = {}
for _, name in ipairs(ignore.guis or {}) do
	ignoreGui[name] = true
end
local ignoreNames = ignore.names or {}

local function escapePattern(text)
	return (string.gsub(text, "%p", "%%%0"))
end
local namePatterns = {}
if player.Name ~= "" then
	table.insert(namePatterns, escapePattern(player.Name))
end
if player.DisplayName ~= "" and player.DisplayName ~= player.Name then
	table.insert(namePatterns, escapePattern(player.DisplayName))
end
local userIdPattern = escapePattern(tostring(player.UserId))

local function normaliseText(text)
	for _, pattern in ipairs(namePatterns) do
		text = (string.gsub(text, pattern, "<player>"))
	end
	return (string.gsub(text, "%d[%d%.,:]*", "#"))
end

local function normaliseImage(image)
	return (string.gsub(image, userIdPattern, "<uid>"))
end

local function hex(color)
	return string.format("%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function whole(value)
	if value ~= value or value == math.huge or value == -math.huge then
		return "x"
	end
	return string.format("%d", math.floor(value + 0.5))
end

local function udim2(value)
	return string.format("%.3f,%s,%.3f,%s", value.X.Scale, whole(value.X.Offset), value.Y.Scale, whole(value.Y.Offset))
end

local function fontOf(item)
	local ok, value = pcall(function()
		local face = item.FontFace
		return face.Family .. "/" .. face.Weight.Name .. "/" .. face.Style.Name
	end)
	return ok and value or "?"
end

local geometryMode = ARGS.geometry or "absolute"

local function describe(item)
	local parts = { item.ClassName, item.Name }
	if item:IsA("GuiObject") then
		if not dropField.visible then
			table.insert(parts, item.Visible and "V1" or "V0")
		end
		if not dropField.geometry and geometryMode ~= "none" then
			if geometryMode == "absolute" or geometryMode == "both" then
				local position, size = item.AbsolutePosition, item.AbsoluteSize
				table.insert(parts, whole(position.X) .. "," .. whole(position.Y) .. "," .. whole(size.X) .. "," .. whole(size.Y))
			end
			if geometryMode == "udim" or geometryMode == "both" then
				table.insert(parts, udim2(item.Position) .. ";" .. udim2(item.Size))
			end
			table.insert(parts, string.format("a%.2f,%.2f r%s", item.AnchorPoint.X, item.AnchorPoint.Y, whole(item.Rotation)))
		end
		if not dropField.colour then
			table.insert(parts, "bg" .. hex(item.BackgroundColor3))
		end
		if not dropField.transparency then
			table.insert(parts, string.format("bt%.2f", item.BackgroundTransparency))
		end
		if not dropField.zindex then
			table.insert(parts, "z" .. tostring(item.ZIndex))
		end
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			if not dropField.text then
				table.insert(parts, "t=" .. normaliseText(item.Text))
			end
			if not dropField.font then
				table.insert(parts, fontOf(item) .. "/" .. tostring(item.TextSize) .. (item.TextScaled and "/scaled" or "") .. (item.TextWrapped and "/wrap" or "") .. "/" .. item.TextXAlignment.Name)
			end
			if not dropField.colour then
				table.insert(parts, "tc" .. hex(item.TextColor3))
			end
			if not dropField.transparency then
				table.insert(parts, string.format("tt%.2f", item.TextTransparency))
			end
		elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
			if not dropField.image then
				table.insert(parts, "i=" .. normaliseImage(item.Image) .. "/" .. item.ScaleType.Name)
			end
			if not dropField.colour then
				table.insert(parts, "ic" .. hex(item.ImageColor3))
			end
			if not dropField.transparency then
				table.insert(parts, string.format("it%.2f", item.ImageTransparency))
			end
		end
		if item:IsA("CanvasGroup") and not dropField.transparency then
			table.insert(parts, string.format("gt%.2f", item.GroupTransparency))
		end
	elseif not dropField.modifiers then
		if item:IsA("UIStroke") then
			table.insert(parts, string.format("%s/%.2f/%.2f/%s", hex(item.Color), item.Thickness, item.Transparency, item.ApplyStrokeMode.Name))
		elseif item:IsA("UICorner") then
			table.insert(parts, string.format("%.3f,%d", item.CornerRadius.Scale, item.CornerRadius.Offset))
		elseif item:IsA("UIGradient") then
			local keypoints = item.Color.Keypoints
			table.insert(parts, string.format("%s/%s/%s/%d", whole(item.Rotation), hex(keypoints[1].Value), hex(keypoints[#keypoints].Value), #keypoints))
		elseif item:IsA("UIScale") then
			table.insert(parts, string.format("%.3f", item.Scale))
		elseif item:IsA("UIPadding") then
			table.insert(parts, string.format("%.3f,%d/%.3f,%d/%.3f,%d/%.3f,%d",
				item.PaddingLeft.Scale, item.PaddingLeft.Offset, item.PaddingRight.Scale, item.PaddingRight.Offset,
				item.PaddingTop.Scale, item.PaddingTop.Offset, item.PaddingBottom.Scale, item.PaddingBottom.Offset))
		elseif item:IsA("UIListLayout") then
			table.insert(parts, string.format("%s/%.3f,%d/%s", item.FillDirection.Name, item.Padding.Scale, item.Padding.Offset, item.SortOrder.Name))
		elseif item:IsA("UIAspectRatioConstraint") then
			table.insert(parts, string.format("%.3f", item.AspectRatio))
		elseif item:IsA("UITextSizeConstraint") then
			table.insert(parts, string.format("%d/%d", item.MinTextSize, item.MaxTextSize))
		elseif item:IsA("UISizeConstraint") then
			table.insert(parts, tostring(item.MinSize.X) .. "," .. tostring(item.MinSize.Y) .. "/" .. tostring(item.MaxSize.X) .. "," .. tostring(item.MaxSize.Y))
		end
	end
	return table.concat(parts, "|")
end

-- Walk ----------------------------------------------------------------------------------------
local detail = type(ARGS.detail) == "table" and ARGS.detail or nil
local detailRows = {}
local detailTruncated = false
local maxDetail = ARGS.maxDetail or 220

local function ignoredName(name)
	for _, pattern in ipairs(ignoreNames) do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end

-- Returns hashAll, hashVisible (nil when the node is not shown), countAll, countVisible.
-- path / detailDepth are only maintained inside the detail gui (nil elsewhere).
local function visit(stats, item, shown, path, detailDepth)
	local descriptor = describe(item)
	local allHashes = {}
	local visibleHashes = {}
	local countAll, countVisible = 1, shown and 1 or 0
	local seen = nil
	if path then
		seen = {}
	end
	for _, child in ipairs(item:GetChildren()) do
		if ignoredName(child.Name) then
			stats.ignored += 1
		else
			local childShown = shown
			if child:IsA("GuiObject") then
				childShown = shown and child.Visible
			end
			local childPath, childDepth = nil, nil
			if path then
				local index = (seen[child.Name] or 0) + 1
				seen[child.Name] = index
				local segment = index > 1 and (child.Name .. "#" .. index) or child.Name
				childPath = path == "" and segment or (path .. "." .. segment)
				if detailDepth and detailDepth > 0 then
					childDepth = detailDepth
				elseif detail and detail.root and detail.root ~= "" and childPath == detail.root then
					childDepth = (detail.depth or 2) + 1 -- the root row itself, then `depth` levels below it
				end
			end
			local hashAll, hashVisible, childAll, childVisible = visit(stats, child, childShown, childPath, childDepth and childDepth - 1 or nil)
			table.insert(allHashes, hashAll)
			if hashVisible then
				table.insert(visibleHashes, hashVisible)
			end
			countAll += childAll
			countVisible += childVisible
			if childDepth then
				if #detailRows < maxDetail then
					local row = { p = childPath, c = child.ClassName, h = hashAll, v = hashVisible, n = childAll }
					if detail.descriptors then
						row.d = string.sub(describe(child), 1, 260)
					end
					table.insert(detailRows, row)
				else
					detailTruncated = true
				end
			end
		end
	end
	table.sort(allHashes)
	local hashAll = fnv(descriptor .. "{" .. table.concat(allHashes, ",") .. "}")
	local hashVisible = nil
	if shown then
		table.sort(visibleHashes)
		hashVisible = fnv(descriptor .. "{" .. table.concat(visibleHashes, ",") .. "}")
	end
	return hashAll, hashVisible, countAll, countVisible
end

local camera = workspace.CurrentCamera
local result = {
	probe = "play_record", ok = true, version = 1, label = ARGS.label, run = ARGS.run,
	geometry = geometryMode, ignore = { guis = ignore.guis or {}, names = ignoreNames, fields = ignore.fields or {} },
	viewport = camera and { camera.ViewportSize.X, camera.ViewportSize.Y } or nil,
	guis = {}, skippedGuis = {}, other = {},
}

local combined = {}
for _, gui in ipairs(playerGui:GetChildren()) do
	if not gui:IsA("LayerCollector") then
		table.insert(result.other, gui.ClassName .. ":" .. gui.Name)
	elseif ignoreGui[gui.Name] then
		table.insert(result.skippedGuis, gui.Name)
	else
		local stats = { ignored = 0 }
		local isDetail = detail ~= nil and detail.gui == gui.Name
		local rootDepth = nil
		if isDetail and (detail.root == nil or detail.root == "") then
			rootDepth = detail.depth or 2
		end
		local hashAll, hashVisible, countAll, countVisible = visit(stats, gui, gui.Enabled, isDetail and "" or nil, rootDepth)
		local entry = {
			name = gui.Name, class = gui.ClassName, enabled = gui.Enabled,
			displayOrder = gui:IsA("ScreenGui") and gui.DisplayOrder or nil,
			count = #gui:GetDescendants(), hashed = countAll - 1, visible = math.max(0, countVisible - 1),
			hash = hashAll, visHash = hashVisible, ignoredSubtrees = stats.ignored,
		}
		table.insert(result.guis, entry)
		table.insert(combined, gui.Name .. ":" .. tostring(hashAll))
	end
end
table.sort(result.guis, function(a, b)
	if a.name == b.name then
		return a.hash < b.hash
	end
	return a.name < b.name
end)
table.sort(result.skippedGuis)
table.sort(combined)
result.hash = fnv(table.concat(combined, ";"))

if detail then
	table.sort(detailRows, function(a, b)
		return a.p < b.p
	end)
	result.detail = { gui = detail.gui, root = detail.root, depth = detail.depth or 2, rows = detailRows, truncated = detailTruncated }
end

-- ClientBase.StartupState: a Folder under the ClientBase script; one attribute per entry, value = status.
local startup = { found = false, statuses = {}, counts = {} }
pcall(function()
	local playerScripts = player:FindFirstChildOfClass("PlayerScripts")
	local clientBase = playerScripts and playerScripts:FindFirstChild("ClientBase")
	local folder = clientBase and clientBase:FindFirstChild("StartupState")
	if folder then
		startup.found = true
		for name, status in pairs(folder:GetAttributes()) do
			local text = tostring(status)
			startup.statuses[name] = text
			startup.counts[text] = (startup.counts[text] or 0) + 1
		end
	end
end)
result.startupState = startup

if ARGS.attributes then
	local attributes = {}
	pcall(function()
		for name, value in pairs(player:GetAttributes()) do
			local kind = type(value)
			if kind == "boolean" or kind == "number" then
				attributes[name] = value
			elseif kind == "string" then
				attributes[name] = string.sub(value, 1, 48)
			end
		end
	end)
	result.playerAttributes = attributes
	local guiAttributes = {}
	pcall(function()
		for name, value in pairs(playerGui:GetAttributes()) do
			if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then
				guiAttributes[name] = type(value) == "string" and string.sub(value, 1, 48) or value
			end
		end
	end)
	result.playerGuiAttributes = guiAttributes
end

if ARGS.errors then
	local errors = {}
	local order = {}
	local okHistory = pcall(function()
		for _, entry in ipairs(game:GetService("LogService"):GetLogHistory()) do
			local kind = entry.messageType
			if kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning then
				local key = (kind == Enum.MessageType.MessageError and "E " or "W ") .. string.sub(normaliseText(tostring(entry.message)), 1, 150)
				if not errors[key] then
					errors[key] = 0
					table.insert(order, key)
				end
				errors[key] += 1
			end
		end
	end)
	local list = {}
	for index = 1, math.min(#order, 30) do
		list[index] = { order[index], errors[order[index]] }
	end
	result.console = { available = okHistory, distinct = #order, messages = list, truncated = #order > 30 }
end

return HttpService:JSONEncode(result)
