-- Canonical feature implementation (docs/architecture/map-markers-contract.md, owner Agent F / map_ui).
-- Shared map tile renderer for both free-roam minimaps and the full map. The tile grid comes from
-- ReplicatedStorage.Config.UI.MapTiles (attribute GridSize = N, attributes "R<row>C<col>" = asset id,
-- rows top -> bottom, cols left -> right, R1C1 = top-left). When that folder is missing or incomplete
-- the four legacy Config.UI.DesktopFreeRoamHud.Assets tiles are used. Every grid fills the same canvas
-- (the same world extent) as the old 2x2 set, so the map calibration is unchanged.
-- Cull hides tiles outside a map-unit box so only the tiles on screen are drawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapMath = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("MapMath"))

local TileSet = {}
TileSet.__index = TileSet

local function folders()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	local grid = ui and ui:FindFirstChild("MapTiles")
	local hud = ui and ui:FindFirstChild("DesktopFreeRoamHud")
	return grid, hud and hud:FindFirstChild("Assets")
end

local function legacyValue(assets, name)
	local item = assets and assets:FindFirstChild(name)
	if item and item:IsA("ValueBase") then return item.Value end
	return assets and assets:GetAttribute(name) or nil
end

-- { Size, Ids = { [row] = { [col] = id } }, Complete, Source = "MapTiles" | "Legacy" }
function TileSet.Resolve()
	local grid, assets = folders()
	return MapMath.ResolveTiles(
		grid and function(name) return grid:GetAttribute(name) end or nil,
		function(name) return legacyValue(assets, name) end
	)
end

-- options: { Canvas = GuiObject, ZIndex = number?, Overlap = number? (canvas px added to inner edges, default 1) }
function TileSet.new(options)
	assert(type(options) == "table" and typeof(options.Canvas) == "Instance" and options.Canvas:IsA("GuiObject"), "MapTileSet needs a Canvas GuiObject")
	local self = setmetatable({}, TileSet)
	local info = TileSet.Resolve()
	self.Size, self.Source, self.Complete, self.Any = info.Size, info.Source, info.Complete, false
	self.Tiles = {}
	local n = info.Size
	-- A 1 px overlap on inner edges hides hairline seams between scale-positioned tiles.
	local overlap = math.clamp(tonumber(options.Overlap) or 1, 0, 4)
	for row = 1, n do
		for col = 1, n do
			local id = info.Ids[row][col]
			if id ~= "" then self.Any = true end
			local image = Instance.new("ImageLabel")
			image.Name = info.Source == "Legacy" and MapMath.LegacyTiles[row][col] or ("MapTileR" .. row .. "C" .. col)
			image.BackgroundTransparency = 1
			image.BorderSizePixel = 0
			image.Image = id
			image.ScaleType = Enum.ScaleType.Stretch
			image.Position = UDim2.fromScale((col - 1) / n, (row - 1) / n)
			image.Size = UDim2.new(1 / n, col < n and overlap or 0, 1 / n, row < n and overlap or 0)
			image.ZIndex = math.floor(tonumber(options.ZIndex) or 1)
			image.Parent = options.Canvas
			table.insert(self.Tiles, { Row = row, Col = col, Image = image })
		end
	end
	return self
end

-- Shows only the tiles that overlap the map-unit box [uMin, uMax] x [vMin, vMax].
function TileSet:Cull(uMin, uMax, vMin, vMax)
	for _, tile in ipairs(self.Tiles) do
		local show = MapMath.TileOverlaps(tile.Row, tile.Col, self.Size, uMin, uMax, vMin, vMax)
		if tile.Image.Visible ~= show then tile.Image.Visible = show end
	end
end

function TileSet:ShowAll()
	for _, tile in ipairs(self.Tiles) do
		if not tile.Image.Visible then tile.Image.Visible = true end
	end
end

function TileSet:Destroy()
	for _, tile in ipairs(self.Tiles) do tile.Image:Destroy() end
	table.clear(self.Tiles)
end

return TileSet
