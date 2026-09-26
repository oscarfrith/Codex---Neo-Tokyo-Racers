-- Read-only Edit export of the minimap road mask for the route-guide graph generator.
-- Loads the four configured minimap tiles into in-memory EditableImages, classifies
-- road pixels (opaque, brightness >= threshold) and posts per-row run-length data to
-- the loopback receiver (scripts/route_guide/mask_receiver.py). No instances are created
-- in the DataModel and nothing in the place is changed.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local assets = game:GetService("ReplicatedStorage").Config.UI.DesktopFreeRoamHud.Assets
local THRESHOLD = 112
local TILE_ORDER = { { "MapTileTopLeft", 0, 0 }, { "MapTileTopRight", 1, 0 }, { "MapTileBottomLeft", 0, 1 }, { "MapTileBottomRight", 1, 1 } }

local tileSize
local rows = {} -- rows[y] = { x0, len, x1, len, ... } in full-image pixels
for _, entry in ipairs(TILE_ORDER) do
	local id = tostring(assets[entry[1]].Value)
	local image = AssetService:CreateEditableImageAsync(Content.fromUri(id))
	local size = image.Size
	tileSize = tileSize or size
	assert(size == tileSize, "Tiles must share one size")
	local pixels = image:ReadPixelsBuffer(Vector2.zero, size)
	image:Destroy()
	local offsetX, offsetY = entry[2] * size.X, entry[3] * size.Y
	for y = 0, size.Y - 1 do
		local runStart = nil
		local row = rows[offsetY + y] or {}
		for x = 0, size.X do
			local isRoad = false
			if x < size.X then
				local o = (y * size.X + x) * 4
				if buffer.readu8(pixels, o + 3) >= 128 then
					local brightness = (buffer.readu8(pixels, o) + buffer.readu8(pixels, o + 1) + buffer.readu8(pixels, o + 2)) / 3
					isRoad = brightness >= THRESHOLD
				end
			end
			if isRoad and not runStart then
				runStart = x
			elseif not isRoad and runStart then
				table.insert(row, offsetX + runStart)
				table.insert(row, x - runStart)
				runStart = nil
			end
		end
		rows[offsetY + y] = row
	end
end

local height = tileSize.Y * 2
local encodedRows = table.create(height)
for y = 0, height - 1 do
	-- Tiles are read left then right, so each row's runs are already in x order.
	encodedRows[y + 1] = table.concat(rows[y] or {}, ",")
end
local payload = HttpService:JSONEncode({
	width = tileSize.X * 2,
	height = height,
	threshold = THRESHOLD,
	tiles = {
		assets.MapTileTopLeft.Value, assets.MapTileTopRight.Value,
		assets.MapTileBottomLeft.Value, assets.MapTileBottomRight.Value,
	},
	rows = encodedRows,
})
local token = HttpService:GenerateGUID(false)
local CHUNK = 200000
local total = math.ceil(#payload / CHUNK)
for index = 1, total do
	local part = string.sub(payload, (index - 1) * CHUNK + 1, index * CHUNK)
	HttpService:PostAsync("http://127.0.0.1:8768/mask", HttpService:JSONEncode({ token = token, index = index, total = total, data = part }))
end
return string.format("Road mask sent: %dx%d, %d chars in %d chunks. No game objects changed.", tileSize.X * 2, height, #payload, total)
