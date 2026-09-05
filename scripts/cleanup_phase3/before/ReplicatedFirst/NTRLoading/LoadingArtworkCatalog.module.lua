-- NTR_LOADING_SYSTEM_PHASE1_ARTWORK_CATALOG_V1_2
local Catalog = {}
local rng = Random.new()
local bags = {}

local function normalizedAssetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

local function supportsDestination(csv, destination)
	local requested = string.lower(tostring(destination or ""))
	for item in string.gmatch(tostring(csv or "*"), "[^,]+") do
		local value = string.lower((string.gsub(item, "^%s*(.-)%s*$", "%1")))
		if value == "*" or value == requested then return true end
	end
	return false
end

local function tileSet(item, layout)
	local columns = math.clamp(math.floor(tonumber(item:GetAttribute("Columns")) or 3), 1, 4)
	local rows = math.clamp(math.floor(tonumber(item:GetAttribute("Rows")) or 2), 1, 3)
	if layout == "Grid3x2" then columns, rows = 3, 2 end
	if layout ~= "Grid3x2" then return {}, columns, rows, false end
	local result = {}
	local complete = layout == "Grid3x2"
	local root = item:FindFirstChild("Tiles")
	for row = 1, rows do
		for column = 1, columns do
			local name = ("R%dC%d"):format(row, column)
			local tile = root and root:FindFirstChild(name)
			local imageAssetId = normalizedAssetId(tile and tile:GetAttribute("ImageAssetId"))
			if imageAssetId == "" then complete = false end
			table.insert(result, { Name = name, Row = row, Column = column, ImageAssetId = imageAssetId })
		end
	end
	return result, columns, rows, complete
end

local function entries(config, destination)
	local artworkRoot = config and config:FindFirstChild("Artworks")
	local result = {}
	for _, item in ipairs(artworkRoot and artworkRoot:GetChildren() or {}) do
		if item:IsA("Folder") and item:GetAttribute("Enabled") ~= false and supportsDestination(item:GetAttribute("Destinations"), destination) then
			local layout = tostring(item:GetAttribute("Layout") or "Single")
			local tiles, columns, rows, gridReady = tileSet(item, layout)
			table.insert(result, {
				ArtworkId = tostring(item:GetAttribute("ArtworkId") or item.Name),
				ImageAssetId = normalizedAssetId(item:GetAttribute("ImageAssetId")),
				Weight = math.max(0.01, tonumber(item:GetAttribute("Weight")) or 1),
				FocalPointX = math.clamp(tonumber(item:GetAttribute("FocalPointX")) or 0.5, 0, 1),
				FocalPointY = math.clamp(tonumber(item:GetAttribute("FocalPointY")) or 0.5, 0, 1),
				MotionPreset = tostring(item:GetAttribute("MotionPreset") or "SlowPanRight"),
				Layout = layout,
				Columns = columns,
				Rows = rows,
				AspectRatio = math.clamp(tonumber(item:GetAttribute("AspectRatio")) or (16 / 9), 0.5, 3),
				Tiles = tiles,
				GridReady = gridReady,
				StartScreenEligible = item:GetAttribute("StartScreenEligible") == true,
			})
		end
	end
	table.sort(result, function(a, b) return a.ArtworkId < b.ArtworkId end)
	return result
end

local function signature(items)
	local ids = {}
	for _, item in ipairs(items) do
		local tileIds = {}
		for _, tile in ipairs(item.Tiles or {}) do table.insert(tileIds, tile.ImageAssetId) end
		table.insert(ids, table.concat({ item.ArtworkId, tostring(item.Weight), item.Layout, table.concat(tileIds, ",") }, ":"))
	end
	return table.concat(ids, "|")
end

local function refill(destination, items, previousId)
	local weighted = {}
	for _, item in ipairs(items) do
		local key = rng:NextNumber() ^ (1 / item.Weight)
		table.insert(weighted, { Key = key, Entry = item })
	end
	table.sort(weighted, function(a, b) return a.Key > b.Key end)
	local bag = {}
	for _, item in ipairs(weighted) do table.insert(bag, item.Entry) end
	if #bag > 1 and bag[1].ArtworkId == previousId then bag[1], bag[2] = bag[2], bag[1] end
	bags[destination] = { Signature = signature(items), Entries = bag }
	return bags[destination]
end

function Catalog.Choose(config, destination, previousId)
	destination = tostring(destination or "Default")
	local available = entries(config, destination)
	if #available == 0 then
		return { ArtworkId = "FallbackBlack", ImageAssetId = "", Weight = 1, FocalPointX = 0.5, FocalPointY = 0.5, MotionPreset = "None", Layout = "Single", Columns = 1, Rows = 1, AspectRatio = 16 / 9, Tiles = {}, GridReady = false }
	end
	local bag = bags[destination]
	if not bag or bag.Signature ~= signature(available) or #bag.Entries == 0 then bag = refill(destination, available, previousId) end
	return table.remove(bag.Entries, 1)
end

function Catalog.List(config, destination)
	return entries(config, destination)
end

return Catalog
