-- Canonical feature implementation (docs/architecture/map-markers-contract.md, owner Agent F).
-- Shared renderer that draws MapMarkers into one map container. Icons are always upright:
-- on the rotating minimap they are placed with the map transform (MapMath.MinimapPoint, the same
-- maths as FreeRoamMapPlayerMarkers:Step) but never rotated. Instances are pooled; markers are
-- synced only after MapMarkers.Changed. Step is called by the host's existing render callback.
-- An empty icon id renders a round theme-coloured badge with a 1-2 letter glyph.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local uiModules = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI")
local MapMarkers = require(uiModules:WaitForChild("MapMarkers"))
local MapMath = require(uiModules:WaitForChild("MapMath"))

local Layer = {}
Layer.__index = Layer

local GLYPHS = {
	Dealership = "$", Garage = "G", Customisation = "C", Race = "R", TimeTrial = "TT",
	TaxiFare = "T", CourierPickup = "P", CourierDrop = "D", TaxiDrop = "D", Waypoint = "W",
	Player = "Y", OtherPlayer = "O", Duel = "VS", Job = "J",
}
local KIND_GLYPHS = { Place = "P", Race = "R", Job = "J", Waypoint = "W", Activity = "!", Player = "Y" }

-- Theme token per kind, with a few icon-specific tokens. Hosts pass their theme table.
local KIND_TOKENS = { Place = "ElectricBlue", Race = "Outline", Job = "Telemetry", Waypoint = "HighSpeed", Activity = "HighSpeed", Player = "Text" }
local ICON_TOKENS = { Garage = "Telemetry", Customisation = "OutlineSoft", Duel = "Danger", TimeTrial = "Telemetry", OtherPlayer = "Telemetry" }
local DEFAULT_THEME = {
	PanelDeep = Color3.fromRGB(9, 12, 16), Panel = Color3.fromRGB(15, 19, 24), Outline = Color3.fromRGB(244, 46, 151),
	OutlineSoft = Color3.fromRGB(214, 74, 175), Telemetry = Color3.fromRGB(43, 225, 218), ElectricBlue = Color3.fromRGB(25, 116, 255),
	HighSpeed = Color3.fromRGB(246, 83, 159), Danger = Color3.fromRGB(196, 57, 75), Text = Color3.fromRGB(246, 248, 252),
	Muted = Color3.fromRGB(163, 171, 184),
}

local function token(theme, name)
	local value = theme and theme[name]
	return typeof(value) == "Color3" and value or DEFAULT_THEME[name]
end

function Layer.Glyph(icon, kind)
	return GLYPHS[icon] or KIND_GLYPHS[kind] or "?"
end

function Layer.Colour(theme, kind, icon, override)
	if typeof(override) == "Color3" then return override end
	return token(theme, ICON_TOKENS[icon] or KIND_TOKENS[kind] or "Telemetry")
end

local function config()
	local ui = ReplicatedStorage:FindFirstChild("Config")
	ui = ui and ui:FindFirstChild("UI")
	return ui and ui:FindFirstChild("MapIconLayer")
end

local function number(folder, name, fallback, minimum, maximum)
	local value = MapMath.Finite(folder and folder:GetAttribute(name), fallback)
	return math.clamp(value, minimum, maximum)
end

-- One icon visual: transparent root, image, fallback badge + glyph, pulse scale.
local function build(parent, size, zIndex, font)
	local root = Instance.new("Frame")
	root.Name = "MapIcon"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(size, size)
	root.ZIndex = zIndex
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = UDim2.fromScale(1, 1)
	image.ZIndex = zIndex
	image.Parent = root
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	badge.Size = UDim2.fromScale(0.86, 0.86)
	badge.BorderSizePixel = 0
	badge.ZIndex = zIndex
	badge.Parent = root
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = badge
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.5
	stroke.Parent = badge
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.BorderSizePixel = 0
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = font or Enum.Font.Michroma
	glyph.TextScaled = true
	glyph.ZIndex = zIndex
	glyph.Parent = badge
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0.16, 0), UDim.new(0.16, 0)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0.2, 0), UDim.new(0.2, 0)
	padding.Parent = glyph
	local pulse = Instance.new("UIScale")
	pulse.Name = "Pulse"
	pulse.Parent = root
	root.Parent = parent
	return { Root = root, Image = image, Badge = badge, Stroke = stroke, Glyph = glyph, Pulse = pulse }
end

local function style(item, icon, kind, colour, theme)
	local asset = MapMarkers.IconAsset(icon)
	local hasImage = asset ~= ""
	item.Image.Image = asset
	item.Image.Visible = hasImage
	item.Image.ImageColor3 = Color3.new(1, 1, 1)
	item.Badge.Visible = not hasImage
	item.Badge.BackgroundColor3 = colour
	item.Stroke.Color = token(theme, "PanelDeep")
	item.Glyph.Text = Layer.Glyph(icon, kind)
	item.Glyph.TextColor3 = token(theme, "Text")
end

-- Static icon for legends and lists (not registered, not stepped).
-- options: { Icon, Kind, Color, Size, Theme, Font, ZIndex }
function Layer.CreateIcon(parent, options)
	local item = build(parent, options.Size or 24, options.ZIndex or 1, options.Font)
	item.Root.AnchorPoint = Vector2.zero
	style(item, options.Icon, options.Kind, Layer.Colour(options.Theme, options.Kind, options.Icon, options.Color), options.Theme)
	return item.Root
end

-- options: { Container, Surface = "Minimap" | "FullMap", ZIndex, IconSize?, Mobile?, Theme?, Font? }
function Layer.new(options)
	assert(type(options) == "table" and options.Container and options.Container:IsA("GuiObject"), "MapIconLayer needs a Container GuiObject")
	local self = setmetatable({}, Layer)
	self.Surface = options.Surface == "FullMap" and "FullMap" or "Minimap"
	self.Theme = options.Theme or {}
	self.Font = options.Font
	self.Mobile = options.Mobile == true
	self.IconSizeOverride = options.IconSize
	self.ZIndex = math.floor(tonumber(options.ZIndex) or 1)
	self.Records, self.Pool, self.Hits = {}, {}, {}
	self.Dirty, self.Restyle = true, false
	self.Connections = {}

	local old = options.Container:FindFirstChild("MapIcons")
	if old then old:Destroy() end
	local overlay = Instance.new("Frame")
	overlay.Name = "MapIcons"
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = self.ZIndex
	overlay.Parent = options.Container
	self.Overlay = overlay

	self:_readConfig()
	table.insert(self.Connections, MapMarkers.Changed:Connect(function() self.Dirty = true end))
	table.insert(self.Connections, MapMarkers.IconsChanged:Connect(function() self.Restyle = true end))
	local folder = config()
	if folder then
		table.insert(self.Connections, folder.AttributeChanged:Connect(function()
			self:_readConfig()
			self.Restyle = true
		end))
	end
	return self
end

function Layer:_readConfig()
	local folder = config()
	local sizeName
	if self.Surface == "FullMap" then
		sizeName = self.Mobile and "TouchFullMapIconSize" or "FullMapIconSize"
	else
		sizeName = self.Mobile and "MobileMinimapIconSize" or "MinimapIconSize"
	end
	local fallback = ({ FullMapIconSize = 26, TouchFullMapIconSize = 32, MinimapIconSize = 18, MobileMinimapIconSize = 14 })[sizeName]
	self.IconSize = math.floor(tonumber(self.IconSizeOverride) or number(folder, sizeName, fallback, 6, 96))
	self.EdgeInset = number(folder, "EdgeInset", 11, 0, 64)
	self.Overscan = number(folder, "Overscan", 12, 0, 128)
	self.PulseSpeed = number(folder, "PulseSpeed", 4, 0, 20)
	self.PulseAmount = number(folder, "PulseAmount", 0.14, 0, 1)
	self.Enabled = not (folder and folder:GetAttribute(self.Surface .. "Enabled") == false)
end

function Layer:SetIconSize(size)
	self.IconSizeOverride = size
	self:_readConfig()
	self.Restyle = true
end

function Layer:_release(id)
	local record = self.Records[id]
	if not record then return end
	record.Item.Root.Visible = false
	table.insert(self.Pool, record.Item)
	self.Records[id] = nil
end

function Layer:_sync()
	self.Dirty = false
	local flag = self.Surface
	local all = MapMarkers.All()
	for id in pairs(self.Records) do
		local marker = all[id]
		if not marker or marker[flag] == false then self:_release(id) end
	end
	for id, marker in pairs(all) do
		if marker[flag] ~= false then
			local record = self.Records[id]
			if not record then
				local item = table.remove(self.Pool) or build(self.Overlay, self.IconSize, self.ZIndex + 1, self.Font)
				item.Root.Name = "Icon_" .. id
				record = { Item = item }
				self.Records[id] = record
			end
			if record.Marker ~= marker then
				record.Marker = marker
				record.Styled = false
			end
		end
	end
end

function Layer:_style(record)
	local marker, item = record.Marker, record.Item
	style(item, marker.Icon, marker.Kind, Layer.Colour(self.Theme, marker.Kind, marker.Icon, marker.Color), self.Theme)
	local z = self.ZIndex + 1 + math.clamp(math.floor(marker.Priority), 0, 60)
	for _, object in ipairs({ item.Root, item.Image, item.Badge, item.Glyph }) do object.ZIndex = z end
	item.Root.Size = UDim2.fromOffset(self.IconSize, self.IconSize)
	if not marker.Pulse then item.Pulse.Scale = 1 end
	record.Styled = true
end

function Layer:SetVisible(visible)
	visible = visible == true
	if self.Overlay.Visible ~= visible then self.Overlay.Visible = visible end
	if not visible then table.clear(self.Hits) end
end

-- state (minimap, same table the HUD passes to FreeRoamMapPlayerMarkers:Step):
--   { MapVisible, LocalWorldPosition, MapSize, VisibleStuds, CoordinateCosine, CoordinateSine, FlipX, FlipZ, MapRotationDegrees }
-- state (full map): { MapVisible, Size = Vector2 (container px), Project = function(Vector3) -> (x, y) }
function Layer:Step(_dt, state)
	if not self.Enabled or type(state) ~= "table" or state.MapVisible ~= true then
		self:SetVisible(false)
		return
	end
	local width, height, project
	if type(state.Project) == "function" and typeof(state.Size) == "Vector2" then
		width, height, project = state.Size.X, state.Size.Y, state.Project
	else
		local here, size, visible = state.LocalWorldPosition, tonumber(state.MapSize), tonumber(state.VisibleStuds)
		if typeof(here) ~= "Vector3" or not size or size <= 0 or not visible or visible <= 0 then
			self:SetVisible(false)
			return
		end
		local cal = { Cos = tonumber(state.CoordinateCosine) or 0, Sin = tonumber(state.CoordinateSine) or 1, FlipX = state.FlipX == true, FlipZ = state.FlipZ == true }
		local uiPerStud, rotation = size / visible, tonumber(state.MapRotationDegrees) or 0
		width, height = size, size
		project = function(position)
			return MapMath.MinimapPoint(cal, position.X - here.X, position.Z - here.Z, uiPerStud, rotation, size)
		end
	end
	if width <= 0 or height <= 0 then
		self:SetVisible(false)
		return
	end
	self:SetVisible(true)
	if self.Dirty then self:_sync() end
	local restyle = self.Restyle
	self.Restyle = false
	local pulse = 1 + self.PulseAmount * (0.5 + 0.5 * math.sin(os.clock() * self.PulseSpeed))
	table.clear(self.Hits)
	for id, record in pairs(self.Records) do
		if restyle or not record.Styled then self:_style(record) end
		local marker, root = record.Marker, record.Item.Root
		local x, y = project(marker.Position)
		local shown = x == x and y == y
		if shown and not MapMath.Inside(x, y, width, height, self.Overscan) then
			if marker.EdgeClamp then
				x, y = MapMath.ClampToRect(x, y, width, height, self.EdgeInset)
			else
				shown = false
			end
		end
		if root.Visible ~= shown then root.Visible = shown end
		if shown then
			local position = UDim2.fromScale(x / width, y / height)
			if root.Position ~= position then root.Position = position end
			if marker.Pulse then record.Item.Pulse.Scale = pulse end
			table.insert(self.Hits, { Id = id, X = x, Y = y, Priority = marker.Priority })
		end
	end
end

-- Container-local pixel point -> id of the nearest drawn marker within radius, or nil.
function Layer:HitTest(x, y, radius)
	return MapMath.PickNearest(self.Hits, x, y, radius or self.IconSize * 0.75)
end

function Layer:Destroy()
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	table.clear(self.Connections)
	self.Overlay:Destroy()
	table.clear(self.Records)
	table.clear(self.Pool)
end

return Layer
