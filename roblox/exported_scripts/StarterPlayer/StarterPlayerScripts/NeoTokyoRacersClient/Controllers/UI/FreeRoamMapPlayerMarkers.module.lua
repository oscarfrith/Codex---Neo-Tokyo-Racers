-- NTR_FREEROAM_MAP_PLAYER_MARKERS_MODULE_V1_1
-- NTR_FREEROAM_MAP_PLAYER_MARKERS_MODULE_V1
-- Shared, client-only free-roam minimap markers.
-- Marker lifecycle is event-driven. Step is called only by the existing HUD
-- render owners and performs no Workspace scan, remote call, or direction work.

local Players = game:GetService("Players")

local Module = {}
Module.__index = Module

local CONFIG_NAMES = {
	"Enabled",
	"OtherPlayerMarkerScale",
	"MinimumMarkerSizePixels",
	"MaximumMarkerSizePixels",
	"MaximumOtherPlayers",
	"MarkerResponse",
	"EdgeOverscanPixels",
	"PositionEpsilonPixels",
	"OtherPlayerIcon",
	"MarkerColor",
	"MarkerStrokeColor",
	"MarkerBackgroundTransparency",
	"MarkerStrokeTransparency",
	"MarkerStrokeThickness",
}

local function numberAttribute(config, name, fallback)
	local value = tonumber(config:GetAttribute(name))
	if value == nil then return fallback end
	return value
end

local function colorAttribute(config, name, fallback)
	local value = config:GetAttribute(name)
	if typeof(value) == "Color3" then return value end
	return fallback
end

local function normalizeAsset(value)
	local text = tostring(value or "")
	if text == "" then return "" end
	if string.match(text, "^%d+$") then return "rbxassetid://" .. text end
	return text
end

local function disconnectList(list)
	for _, connection in ipairs(list) do
		connection:Disconnect()
	end
	table.clear(list)
end

local RACE_VEHICLE_ATTRIBUTES = {
	"NTR_RaceParticipant",
	"NTR_RaceRunId",
	"NTR_RaceMode",
	"NTR_RaceFinishedPendingExit",
}

local function playerAllowsMarker(otherPlayer)
	return otherPlayer:GetAttribute("NTR_GarageSessionActive") ~= true
		and otherPlayer:GetAttribute("NTR_OwnedGarageInside") ~= true
		and otherPlayer:GetAttribute("NTR_RaceSessionActive") ~= true
end

local function vehicleIsInRace(vehicle)
	if not vehicle then return false end
	if vehicle:GetAttribute("NTR_RaceParticipant") == true then return true end
	if vehicle:GetAttribute("NTR_RaceRunId") ~= nil then return true end
	if vehicle:GetAttribute("NTR_RaceFinishedPendingExit") == true then return true end
	local mode = tostring(vehicle:GetAttribute("NTR_RaceMode") or "")
	return mode ~= ""
end

local function ownedVehicleFromSeat(otherPlayer, seatPart)
	if not (seatPart and seatPart:IsA("BasePart")) then return nil end
	local current = seatPart
	while current and current ~= workspace do
		if current:IsA("Model") and tonumber(current:GetAttribute("OwnerUserId")) == otherPlayer.UserId then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Module.new(options)
	assert(type(options) == "table", "FreeRoamMapPlayerMarkers options required")
	assert(options.Container and options.Container:IsA("GuiObject"), "Container GuiObject required")
	assert(options.Config and options.Config:IsA("Folder"), "Config Folder required")

	local self = setmetatable({}, Module)
	self.Container = options.Container
	self.Config = options.Config
	self.LocalPlayer = Players.LocalPlayer
	self.ZIndex = math.floor(tonumber(options.ZIndex) or 1)
	self.Records = {}
	self.Connections = {}

	local oldOverlay = self.Container:FindFirstChild("OtherPlayerMarkers")
	if oldOverlay then oldOverlay:Destroy() end
	local overlay = Instance.new("Frame")
	overlay.Name = "OtherPlayerMarkers"
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ClipsDescendants = true
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = self.ZIndex
	overlay.Parent = self.Container
	self.Overlay = overlay

	self:_readConfig()
	for _, name in ipairs(CONFIG_NAMES) do
		table.insert(self.Connections, self.Config:GetAttributeChangedSignal(name):Connect(function()
			self:_readConfig()
		end))
	end
	table.insert(self.Connections, Players.PlayerAdded:Connect(function(otherPlayer)
		self:_addPlayer(otherPlayer)
	end))
	table.insert(self.Connections, Players.PlayerRemoving:Connect(function(otherPlayer)
		self:_removePlayer(otherPlayer)
		self:_fillCapacity()
	end))
	self:_fillCapacity()
	return self
end

function Module:_readConfig()
	self.Enabled = self.Config:GetAttribute("Enabled") ~= false
	self.MarkerScale = math.clamp(numberAttribute(self.Config, "OtherPlayerMarkerScale", 0.65), 0.25, 0.9)
	self.MinimumSize = math.max(4, numberAttribute(self.Config, "MinimumMarkerSizePixels", 8))
	self.MaximumSize = math.max(self.MinimumSize, numberAttribute(self.Config, "MaximumMarkerSizePixels", 16))
	self.MaximumPlayers = math.clamp(math.floor(numberAttribute(self.Config, "MaximumOtherPlayers", 14) + 0.5), 1, 50)
	self.Response = math.max(0, numberAttribute(self.Config, "MarkerResponse", 14))
	self.Overscan = math.max(0, numberAttribute(self.Config, "EdgeOverscanPixels", 8))
	self.PositionEpsilon = math.max(0, numberAttribute(self.Config, "PositionEpsilonPixels", 0.01))
	self.Icon = normalizeAsset(self.Config:GetAttribute("OtherPlayerIcon"))
	self.Color = colorAttribute(self.Config, "MarkerColor", Color3.fromRGB(54, 224, 255))
	self.StrokeColor = colorAttribute(self.Config, "MarkerStrokeColor", Color3.fromRGB(236, 255, 255))
	self.BackgroundTransparency = math.clamp(numberAttribute(self.Config, "MarkerBackgroundTransparency", 0.08), 0, 1)
	self.StrokeTransparency = math.clamp(numberAttribute(self.Config, "MarkerStrokeTransparency", 0.14), 0, 1)
	self.StrokeThickness = math.max(0, numberAttribute(self.Config, "MarkerStrokeThickness", 1))
	for _, record in pairs(self.Records) do
		self:_styleMarker(record)
	end
end

function Module:_styleMarker(record)
	local marker = record.Marker
	if not marker then return end
	marker.Image = self.Icon
	marker.ImageColor3 = self.Color
	marker.BackgroundColor3 = self.Color
	marker.BackgroundTransparency = self.Icon ~= "" and 1 or self.BackgroundTransparency
	record.Stroke.Color = self.StrokeColor
	record.Stroke.Transparency = self.Icon ~= "" and 1 or self.StrokeTransparency
	record.Stroke.Thickness = self.StrokeThickness
end

function Module:_recordCount()
	local count = 0
	for _ in pairs(self.Records) do count += 1 end
	return count
end

function Module:_updateEligibility(record)
	record.Eligible = playerAllowsMarker(record.Player) and not vehicleIsInRace(record.Vehicle)
	if record.Eligible then return end
	record.Marker.Visible = false
	record.Displayed = nil
	record.LastAssigned = nil
end

function Module:_bindVehicle(record, vehicle)
	if record.Vehicle == vehicle then
		self:_updateEligibility(record)
		return
	end
	disconnectList(record.VehicleConnections)
	record.Vehicle = vehicle
	if vehicle then
		for _, attributeName in ipairs(RACE_VEHICLE_ATTRIBUTES) do
			table.insert(record.VehicleConnections, vehicle:GetAttributeChangedSignal(attributeName):Connect(function()
				self:_updateEligibility(record)
			end))
		end
		table.insert(record.VehicleConnections, vehicle.AncestryChanged:Connect(function(_, parent)
			if parent == nil and record.Vehicle == vehicle then
				self:_bindVehicle(record, nil)
			end
		end))
	end
	self:_updateEligibility(record)
end

function Module:_refreshSeatedVehicle(record)
	local seatPart = record.Humanoid and record.Humanoid.SeatPart or nil
	self:_bindVehicle(record, ownedVehicleFromSeat(record.Player, seatPart))
end

function Module:_bindCharacter(record, character)
	disconnectList(record.CharacterConnections)
	self:_bindVehicle(record, nil)
	record.Character = character
	record.Root = character and character:FindFirstChild("HumanoidRootPart") or nil
	record.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
	record.Displayed = nil
	record.LastAssigned = nil
	record.Marker.Visible = false
	if not character then return end
	local function bindHumanoid(humanoid)
		record.Humanoid = humanoid
		table.insert(record.CharacterConnections, humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			self:_refreshSeatedVehicle(record)
		end))
		self:_refreshSeatedVehicle(record)
	end
	if record.Humanoid then bindHumanoid(record.Humanoid) end
	table.insert(record.CharacterConnections, character.ChildAdded:Connect(function(child)
		if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			record.Root = child
			record.Displayed = nil
			record.LastAssigned = nil
		elseif child:IsA("Humanoid") and record.Humanoid == nil then
			bindHumanoid(child)
		end
	end))
	table.insert(record.CharacterConnections, character.ChildRemoved:Connect(function(child)
		if child == record.Root then
			record.Root = nil
			record.Displayed = nil
			record.LastAssigned = nil
			record.Marker.Visible = false
		elseif child == record.Humanoid then
			record.Humanoid = nil
			self:_bindVehicle(record, nil)
		end
	end))
end

function Module:_addPlayer(otherPlayer)
	if otherPlayer == self.LocalPlayer or otherPlayer.Parent ~= Players or self.Records[otherPlayer] then return end
	if self:_recordCount() >= self.MaximumPlayers then return end

	local marker = Instance.new("ImageLabel")
	marker.Name = "Player_" .. tostring(otherPlayer.UserId)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.BackgroundTransparency = 1
	marker.BorderSizePixel = 0
	marker.ScaleType = Enum.ScaleType.Fit
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.Size = UDim2.fromOffset(self.MinimumSize, self.MinimumSize)
	marker.Visible = false
	marker.ZIndex = self.ZIndex
	marker.Parent = self.Overlay

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = marker
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = marker

	local record = {
		Player = otherPlayer,
		Marker = marker,
		Stroke = stroke,
		PlayerConnections = {},
		CharacterConnections = {},
		VehicleConnections = {},
	}
	self.Records[otherPlayer] = record
	self:_styleMarker(record)
	for _, attributeName in ipairs({
		"NTR_GarageSessionActive",
		"NTR_OwnedGarageInside",
		"NTR_RaceSessionActive",
	}) do
		table.insert(record.PlayerConnections, otherPlayer:GetAttributeChangedSignal(attributeName):Connect(function()
			self:_updateEligibility(record)
		end))
	end
	table.insert(record.PlayerConnections, otherPlayer.CharacterAdded:Connect(function(character)
		self:_bindCharacter(record, character)
	end))
	self:_updateEligibility(record)
	self:_bindCharacter(record, otherPlayer.Character)
end

function Module:_removePlayer(otherPlayer)
	local record = self.Records[otherPlayer]
	if not record then return end
	disconnectList(record.PlayerConnections)
	disconnectList(record.CharacterConnections)
	disconnectList(record.VehicleConnections)
	if record.Marker then record.Marker:Destroy() end
	self.Records[otherPlayer] = nil
end

function Module:_fillCapacity()
	if not self.Enabled then return end
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if self:_recordCount() >= self.MaximumPlayers then break end
		self:_addPlayer(otherPlayer)
	end
end

function Module:SetVisible(visible)
	if self.Overlay then self.Overlay.Visible = visible == true end
	if visible == true then return end
	for _, record in pairs(self.Records) do
		record.Marker.Visible = false
		record.Displayed = nil
		record.LastAssigned = nil
	end
end

function Module:Step(dt, state)
	if not self.Enabled or type(state) ~= "table" or state.MapVisible ~= true then
		self:SetVisible(false)
		return
	end
	local localPosition = state.LocalWorldPosition
	local mapSize = tonumber(state.MapSize)
	local visibleStuds = tonumber(state.VisibleStuds)
	if typeof(localPosition) ~= "Vector3" or not mapSize or mapSize <= 0 or not visibleStuds or visibleStuds <= 0 then
		self:SetVisible(false)
		return
	end

	self.Overlay.Visible = true
	local uiPerStud = mapSize / visibleStuds
	local half = mapSize * 0.5
	local edge = half + self.Overscan
	local radians = tonumber(state.CoordinateRadians) or 0
	local cosine = tonumber(state.CoordinateCosine) or math.cos(radians)
	local sine = tonumber(state.CoordinateSine) or math.sin(radians)
	local flipX = state.FlipX == true
	local flipZ = state.FlipZ == true
	local referenceSize = math.max(1, tonumber(state.LocalMarkerSize) or 1)
	local markerSize = math.clamp(math.floor(referenceSize * self.MarkerScale + 0.5), self.MinimumSize, self.MaximumSize)
	local alpha = self.Response <= 0 and 1 or 1 - math.exp(-self.Response * math.max(0, tonumber(dt) or 1 / 60))

	for _, record in pairs(self.Records) do
		local root = record.Root
		if record.Eligible ~= true or not (root and root:IsA("BasePart") and root.Parent == record.Character
			and record.Character and record.Character.Parent ~= nil) then
			record.Marker.Visible = false
			record.Displayed = nil
			record.LastAssigned = nil
			continue
		end

		local delta = root.Position - localPosition
		local dx = flipX and -delta.X or delta.X
		local dz = flipZ and -delta.Z or delta.Z
		local mappedX = dx * cosine - dz * sine
		local mappedZ = dx * sine + dz * cosine
		local target = Vector2.new(half + mappedX * uiPerStud, half + mappedZ * uiPerStud)
		if math.abs(target.X - half) > edge or math.abs(target.Y - half) > edge then
			record.Marker.Visible = false
			record.Displayed = nil
			record.LastAssigned = nil
			continue
		end

		record.Displayed = record.Displayed and record.Displayed:Lerp(target, alpha) or target
		record.Marker.Visible = true
		if record.Marker.Size.X.Offset ~= markerSize or record.Marker.Size.Y.Offset ~= markerSize then
			record.Marker.Size = UDim2.fromOffset(markerSize, markerSize)
		end
		if not record.LastAssigned or (record.Displayed - record.LastAssigned).Magnitude >= self.PositionEpsilon then
			record.Marker.Position = UDim2.fromScale(record.Displayed.X / mapSize, record.Displayed.Y / mapSize)
			record.LastAssigned = record.Displayed
		end
	end
end

function Module:Destroy()
	local players = {}
	for otherPlayer in pairs(self.Records) do table.insert(players, otherPlayer) end
	for _, otherPlayer in ipairs(players) do
		self:_removePlayer(otherPlayer)
	end
	disconnectList(self.Connections)
	if self.Overlay then self.Overlay:Destroy() end
end

return Module
