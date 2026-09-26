-- Read-only Edit export of the four minimap tiles as raw RGBA (base64) for offline map-art work.
-- Loads each configured tile into an in-memory EditableImage and posts it to the loopback receiver
-- (scripts/map_art/tile_receiver.py). Creates no DataModel instances and changes nothing in the place.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local assets = game:GetService("ReplicatedStorage").Config.UI.DesktopFreeRoamHud.Assets

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, 64 do lookup[i - 1] = string.sub(ALPHABET, i, i) end

local function base64(buf)
	local length = buffer.len(buf)
	local parts = table.create(math.ceil(length / 3))
	for i = 0, length - 1, 3 do
		local a = buffer.readu8(buf, i)
		local b = i + 1 < length and buffer.readu8(buf, i + 1) or 0
		local c = i + 2 < length and buffer.readu8(buf, i + 2) or 0
		local n = a * 65536 + b * 256 + c
		local chunk = lookup[bit32.rshift(n, 18) % 64] .. lookup[bit32.rshift(n, 12) % 64]
			.. (i + 1 < length and lookup[bit32.rshift(n, 6) % 64] or "=")
			.. (i + 2 < length and lookup[n % 64] or "=")
		parts[#parts + 1] = chunk
	end
	return table.concat(parts)
end

local sent = {}
for _, name in ipairs({ "MapTileTopLeft", "MapTileTopRight", "MapTileBottomLeft", "MapTileBottomRight" }) do
	local id = tostring(assets[name].Value)
	local image = AssetService:CreateEditableImageAsync(Content.fromUri(id))
	local size = image.Size
	local pixels = image:ReadPixelsBuffer(Vector2.zero, size)
	image:Destroy()
	local encoded = base64(pixels)
	local token = HttpService:GenerateGUID(false)
	local chunk = 200000
	local total = math.ceil(#encoded / chunk)
	for index = 1, total do
		HttpService:PostAsync("http://127.0.0.1:8769/tile", HttpService:JSONEncode({
			token = token, name = name, asset = id, width = size.X, height = size.Y,
			index = index, total = total, data = string.sub(encoded, (index - 1) * chunk + 1, index * chunk),
		}))
	end
	table.insert(sent, name .. " " .. size.X .. "x" .. size.Y .. " (" .. total .. " chunks)")
end
return "Tiles sent: " .. table.concat(sent, ", ") .. ". No game objects changed."
