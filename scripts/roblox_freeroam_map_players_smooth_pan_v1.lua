-- Neo Tokyo Racers - Free-Roam Map Players + Smooth Pan V1.1
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
--
-- INSTALL:
--   Leave MODE = "INSTALL", run once, and require both AUDIT PASS and
--   INSTALL PASS. Restart Play before testing.
--
-- AUDIT:
--   Change MODE to "AUDIT". This is read-only.
--
-- ROLLBACK:
--   Change MODE to "ROLLBACK". This returns to the confirmed installed V1
--   player-marker and relative-pan baseline.
--
-- This is client presentation only. It adds no remote, server loop, saved
-- state, direction tracking, player-name labels, Workspace scan, or extra
-- render connection. It reuses the two confirmed free-roam HUD render owners.
--
-- Exact source anchors intentionally abort before mutation if either live HUD
-- has drifted. A failed INSTALL restores every source/config/module change from
-- that run. Do not loosen a failed anchor without refreshing the Studio mirror.

local MODE = "INSTALL" -- INSTALL, AUDIT, or ROLLBACK
local PHASE = "NTR Free-Roam Map Players + Smooth Pan V1.1"
local REVISION_V1 = "NTR_FREEROAM_MAP_PLAYERS_SMOOTH_PAN_V1"
local REVISION = "NTR_FREEROAM_MAP_PLAYERS_SMOOTH_PAN_V1_1"
local MODULE_MARKER = "NTR_FREEROAM_MAP_PLAYER_MARKERS_MODULE_V1"
local MODULE_MARKER_V11 = "NTR_FREEROAM_MAP_PLAYER_MARKERS_MODULE_V1_1"
local DESKTOP_MARKER = "NTR_FREEROAM_MAP_PLAYERS_SMOOTH_PAN_DESKTOP_V1"
local DESKTOP_MARKER_V11 = "NTR_FREEROAM_MAP_PLAYERS_SMOOTH_PAN_DESKTOP_V1_1"
local MOBILE_MARKER = "NTR_FREEROAM_MAP_PLAYERS_SMOOTH_PAN_MOBILE_V1"
local MOBILE_MARKER_V11 = "NTR_FREEROAM_MAP_PLAYERS_SMOOTH_PAN_MOBILE_V1_1"

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. tostring(parent and parent:GetFullName() or "<nil>") .. "." .. tostring(name))
	end
	return item
end

local function countPlain(source, needle)
	local count = 0
	local cursor = 1
	while true do
		local first = string.find(source, needle, cursor, true)
		if not first then return count end
		count += 1
		cursor = first + #needle
	end
end

local function replaceOnce(source, anchor, replacement, label)
	local count = countPlain(source, anchor)
	if count ~= 1 then
		fail(label .. " anchor count expected 1, got " .. tostring(count)
			.. ". Refresh and inspect the live mirror; do not loosen this anchor.")
	end
	local first, last = string.find(source, anchor, 1, true)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local function insertBeforeOnce(source, anchor, insertion, label)
	return replaceOnce(source, anchor, insertion .. anchor, label)
end

local function compile(source, label)
	if #source > 180000 then fail(label .. " projected source exceeds 180,000 bytes.") end
	local chunk, problem = loadstring(source, "=" .. tostring(label))
	if not chunk then fail(label .. " compile failed: " .. tostring(problem)) end
end

local function restoreAttributes(instance, snapshot)
	for name in pairs(instance:GetAttributes()) do
		if snapshot[name] == nil then instance:SetAttribute(name, nil) end
	end
	for name, value in pairs(snapshot) do instance:SetAttribute(name, value) end
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local configRoot = must(kit, "Config", "Folder")
local uiConfig = must(configRoot, "UI", "Folder")
local starterScripts = must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = must(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = must(clientRoot, "Controllers", "Folder")
local uiControllers = must(controllers, "UI", "Folder")
local desktop = must(uiControllers, "DesktopFreeRoamHudController_Active", "LocalScript")
local mobile = must(uiControllers, "MobileFreeRoamHudController_Active", "LocalScript")
if desktop.Disabled or mobile.Disabled then
	fail("Both confirmed free-roam HUD owners must remain enabled.")
end

local CONFIG_NAME = "FreeRoamMapPlayerMarkers"
local MODULE_NAME = "FreeRoamMapPlayerMarkers"
local CONFIG_DEFAULTS = {
	Enabled = true,
	OtherPlayerMarkerScale = 0.65,
	MinimumMarkerSizePixels = 8,
	MaximumMarkerSizePixels = 16,
	MaximumOtherPlayers = 14,
	MarkerResponse = 14,
	MapPanResponse = 12,
	MapPanSubpixelFactor = 4,
	EdgeOverscanPixels = 8,
	PositionEpsilonPixels = 0.01,
	UseRelativeCanvasTransform = true,
	OtherPlayerIcon = "",
	MarkerColor = Color3.fromRGB(54, 224, 255),
	MarkerStrokeColor = Color3.fromRGB(236, 255, 255),
	MarkerBackgroundTransparency = 0.08,
	MarkerStrokeTransparency = 0.14,
	MarkerStrokeThickness = 1,
}

local MODULE_SOURCE_V1 = [==[
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

local function isFreeRoamEligible(otherPlayer)
	return otherPlayer:GetAttribute("NTR_GarageSessionActive") ~= true
		and otherPlayer:GetAttribute("NTR_OwnedGarageInside") ~= true
		and otherPlayer:GetAttribute("NTR_RaceSessionActive") ~= true
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

function Module:_bindCharacter(record, character)
	disconnectList(record.CharacterConnections)
	record.Character = character
	record.Root = character and character:FindFirstChild("HumanoidRootPart") or nil
	record.Displayed = nil
	record.LastAssigned = nil
	record.Marker.Visible = false
	if not character then return end
	table.insert(record.CharacterConnections, character.ChildAdded:Connect(function(child)
		if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			record.Root = child
			record.Displayed = nil
			record.LastAssigned = nil
		end
	end))
	table.insert(record.CharacterConnections, character.ChildRemoved:Connect(function(child)
		if child == record.Root then
			record.Root = nil
			record.Displayed = nil
			record.LastAssigned = nil
			record.Marker.Visible = false
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
	}
	self.Records[otherPlayer] = record
	self:_styleMarker(record)
	local function updateEligibility()
		record.Eligible = isFreeRoamEligible(otherPlayer)
		if not record.Eligible then
			record.Marker.Visible = false
			record.Displayed = nil
			record.LastAssigned = nil
		end
	end
	for _, attributeName in ipairs({
		"NTR_GarageSessionActive",
		"NTR_OwnedGarageInside",
		"NTR_RaceSessionActive",
	}) do
		table.insert(record.PlayerConnections, otherPlayer:GetAttributeChangedSignal(attributeName):Connect(updateEligibility))
	end
	table.insert(record.PlayerConnections, otherPlayer.CharacterAdded:Connect(function(character)
		self:_bindCharacter(record, character)
	end))
	updateEligibility()
	self:_bindCharacter(record, otherPlayer.Character)
end

function Module:_removePlayer(otherPlayer)
	local record = self.Records[otherPlayer]
	if not record then return end
	disconnectList(record.PlayerConnections)
	disconnectList(record.CharacterConnections)
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
]==]

local MODULE_ELIGIBILITY_V1 = [==[
local function isFreeRoamEligible(otherPlayer)
	return otherPlayer:GetAttribute("NTR_GarageSessionActive") ~= true
		and otherPlayer:GetAttribute("NTR_OwnedGarageInside") ~= true
		and otherPlayer:GetAttribute("NTR_RaceSessionActive") ~= true
end
]==]

local MODULE_ELIGIBILITY_V11 = [==[
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
]==]

local MODULE_BIND_CHARACTER_V1 = [==[
function Module:_bindCharacter(record, character)
	disconnectList(record.CharacterConnections)
	record.Character = character
	record.Root = character and character:FindFirstChild("HumanoidRootPart") or nil
	record.Displayed = nil
	record.LastAssigned = nil
	record.Marker.Visible = false
	if not character then return end
	table.insert(record.CharacterConnections, character.ChildAdded:Connect(function(child)
		if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			record.Root = child
			record.Displayed = nil
			record.LastAssigned = nil
		end
	end))
	table.insert(record.CharacterConnections, character.ChildRemoved:Connect(function(child)
		if child == record.Root then
			record.Root = nil
			record.Displayed = nil
			record.LastAssigned = nil
			record.Marker.Visible = false
		end
	end))
end
]==]

local MODULE_BIND_CHARACTER_V11 = [==[
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
]==]

local MODULE_RECORD_V1 = [==[
		PlayerConnections = {},
		CharacterConnections = {},
	}
	self.Records[otherPlayer] = record
	self:_styleMarker(record)
	local function updateEligibility()
		record.Eligible = isFreeRoamEligible(otherPlayer)
		if not record.Eligible then
			record.Marker.Visible = false
			record.Displayed = nil
			record.LastAssigned = nil
		end
	end
	for _, attributeName in ipairs({
		"NTR_GarageSessionActive",
		"NTR_OwnedGarageInside",
		"NTR_RaceSessionActive",
	}) do
		table.insert(record.PlayerConnections, otherPlayer:GetAttributeChangedSignal(attributeName):Connect(updateEligibility))
	end
]==]

local MODULE_RECORD_V11 = [==[
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
]==]

local MODULE_RECORD_UPDATE_V1 = [==[
	updateEligibility()
	self:_bindCharacter(record, otherPlayer.Character)
]==]

local MODULE_RECORD_UPDATE_V11 = [==[
	self:_updateEligibility(record)
	self:_bindCharacter(record, otherPlayer.Character)
]==]

local MODULE_REMOVE_V1 = [==[
	disconnectList(record.PlayerConnections)
	disconnectList(record.CharacterConnections)
	if record.Marker then record.Marker:Destroy() end
]==]

local MODULE_REMOVE_V11 = [==[
	disconnectList(record.PlayerConnections)
	disconnectList(record.CharacterConnections)
	disconnectList(record.VehicleConnections)
	if record.Marker then record.Marker:Destroy() end
]==]

local function moduleV11ShapeComplete(source)
	return countPlain(source, MODULE_MARKER_V11) == 1
		and countPlain(source, MODULE_ELIGIBILITY_V11) == 1
		and countPlain(source, MODULE_BIND_CHARACTER_V11) == 1
		and countPlain(source, MODULE_RECORD_V11) == 1
		and countPlain(source, MODULE_RECORD_UPDATE_V11) == 1
		and countPlain(source, MODULE_REMOVE_V11) == 1
end

local function upgradeModuleV11(source)
	if countPlain(source, MODULE_MARKER_V11) == 1 then
		if not moduleV11ShapeComplete(source) then fail("Shared module contains a partial or drifted V1.1 installation.") end
		return source
	end
	if countPlain(source, MODULE_MARKER) ~= 1 then fail("Shared module is not the confirmed V1 baseline.") end
	source = replaceOnce(source, "-- " .. MODULE_MARKER .. "\n",
		"-- " .. MODULE_MARKER_V11 .. "\n-- " .. MODULE_MARKER .. "\n", "Module V1.1 marker")
	source = replaceOnce(source, MODULE_ELIGIBILITY_V1, MODULE_ELIGIBILITY_V11, "Module vehicle eligibility")
	source = replaceOnce(source, MODULE_BIND_CHARACTER_V1, MODULE_BIND_CHARACTER_V11, "Module seated vehicle lifecycle")
	source = replaceOnce(source, MODULE_RECORD_V1, MODULE_RECORD_V11, "Module record lifecycle")
	source = replaceOnce(source, MODULE_RECORD_UPDATE_V1, MODULE_RECORD_UPDATE_V11, "Module initial eligibility")
	source = replaceOnce(source, MODULE_REMOVE_V1, MODULE_REMOVE_V11, "Module vehicle cleanup")
	return source
end

local function rollbackModuleV11(source)
	if countPlain(source, MODULE_MARKER_V11) == 0 then return source end
	if not moduleV11ShapeComplete(source) then fail("Shared module V1.1 source drifted; exact rollback refused.") end
	source = replaceOnce(source, MODULE_REMOVE_V11, MODULE_REMOVE_V1, "Rollback module vehicle cleanup")
	source = replaceOnce(source, MODULE_RECORD_UPDATE_V11, MODULE_RECORD_UPDATE_V1, "Rollback module initial eligibility")
	source = replaceOnce(source, MODULE_RECORD_V11, MODULE_RECORD_V1, "Rollback module record lifecycle")
	source = replaceOnce(source, MODULE_BIND_CHARACTER_V11, MODULE_BIND_CHARACTER_V1, "Rollback module seated vehicle lifecycle")
	source = replaceOnce(source, MODULE_ELIGIBILITY_V11, MODULE_ELIGIBILITY_V1, "Rollback module vehicle eligibility")
	source = replaceOnce(source, "-- " .. MODULE_MARKER_V11 .. "\n", "", "Rollback module V1.1 marker")
	return source
end

local MODULE_SOURCE_V11 = upgradeModuleV11(MODULE_SOURCE_V1)

local DESKTOP_MARKER_INSERT = "-- " .. DESKTOP_MARKER .. "\n"
local MOBILE_MARKER_INSERT = "-- " .. MOBILE_MARKER .. "\n"

local DESKTOP_DECLARATION_OLD = [==[
local displayedMapPosition
local displayedPlayerHeading
local bottomActions
]==]

local DESKTOP_DECLARATION_NEW = [==[
local displayedMapPosition
local displayedPlayerHeading
local mapPlayerMarkers
local bottomActions
]==]

local DESKTOP_MARKER_CREATE_OLD = [==[
	playerMarker = new("ImageLabel", { Name = "PlayerMarker", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Image = asset("MapPlayerIcon"), ImageColor3 = C("Text"), ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(markerSize, markerSize), ZIndex = 15 }, minimap)
]==]

local DESKTOP_MARKER_CREATE_NEW = [==[
	playerMarker = new("ImageLabel", { Name = "PlayerMarker", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Image = asset("MapPlayerIcon"), ImageColor3 = C("Text"), ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(markerSize, markerSize), ZIndex = 15 }, minimap)
	mapPlayerMarkers = require(script.Parent:WaitForChild("FreeRoamMapPlayerMarkers")).new({
		Container = minimap,
		Config = kit.Config.UI:WaitForChild("FreeRoamMapPlayerMarkers"),
		ZIndex = 13,
	})
]==]

local DESKTOP_PAN_OLD = [==[
			local canvasSize = fullMapStuds * uiPerStud
			mapCanvas.Size = UDim2.fromOffset(canvasSize, canvasSize)
			local position = mapSubject.Position
			local dx = position.X - L("MapWorldCenterX", 0)
			local dz = position.Z - L("MapWorldCenterZ", 0)
			if B(defaults, "MapFlipX", false) then dx = -dx end
			if B(defaults, "MapFlipZ", false) then dz = -dz end
			local coordinateRadians = math.rad(L("MapCoordinateRotationDegrees", 90))
			local mappedX = dx * math.cos(coordinateRadians) - dz * math.sin(coordinateRadians)
			local mappedZ = dx * math.sin(coordinateRadians) + dz * math.cos(coordinateRadians)
			local look = mapSubject.CFrame.LookVector
			local lookX, lookZ = look.X, look.Z
			if B(defaults, "MapFlipX", false) then lookX = -lookX end
			if B(defaults, "MapFlipZ", false) then lookZ = -lookZ end
			local mappedLookX = lookX * math.cos(coordinateRadians) - lookZ * math.sin(coordinateRadians)
			local mappedLookZ = lookX * math.sin(coordinateRadians) + lookZ * math.cos(coordinateRadians)
			local targetHeading = math.deg(math.atan2(mappedLookX, -mappedLookZ)) + L("MapRotationOffsetDegrees", 0)
			local targetPosition = Vector2.new(mapSize * 0.5, mapSize * 0.5) - Vector2.new(mappedX * uiPerStud, mappedZ * uiPerStud)
			local smoothing = math.max(0, L("MapSmoothing", 10))
			local alpha = smoothing <= 0 and 1 or math.clamp((dt or 1 / 60) * smoothing, 0, 1)
			displayedMapPosition = displayedMapPosition and displayedMapPosition:Lerp(targetPosition, alpha) or targetPosition
			if displayedPlayerHeading == nil then displayedPlayerHeading = targetHeading end
			local headingDelta = (targetHeading - displayedPlayerHeading + 180) % 360 - 180
			displayedPlayerHeading += headingDelta * alpha
			mapCanvas.Position = UDim2.fromOffset(displayedMapPosition.X, displayedMapPosition.Y)
			mapCanvas.Rotation = 0
			playerMarker.Rotation = B(defaults, "MapPlayerIconRotates", true) and displayedPlayerHeading or 0
]==]

local DESKTOP_PAN_NEW = [==[
			local canvasSize = fullMapStuds * uiPerStud
			local useRelativeCanvas = mapPlayerMarkers.Config:GetAttribute("UseRelativeCanvasTransform") ~= false
			if useRelativeCanvas then
				mapCanvas.Size = UDim2.fromScale(canvasSize / mapSize, canvasSize / mapSize)
			else
				mapCanvas.Size = UDim2.fromOffset(canvasSize, canvasSize)
			end
			local position = mapSubject.Position
			local dx = position.X - L("MapWorldCenterX", 0)
			local dz = position.Z - L("MapWorldCenterZ", 0)
			local flipX = B(defaults, "MapFlipX", false)
			local flipZ = B(defaults, "MapFlipZ", false)
			if flipX then dx = -dx end
			if flipZ then dz = -dz end
			local coordinateRadians = math.rad(L("MapCoordinateRotationDegrees", 90))
			local coordinateCosine = math.cos(coordinateRadians)
			local coordinateSine = math.sin(coordinateRadians)
			local mappedX = dx * coordinateCosine - dz * coordinateSine
			local mappedZ = dx * coordinateSine + dz * coordinateCosine
			local look = mapSubject.CFrame.LookVector
			local lookX, lookZ = look.X, look.Z
			if flipX then lookX = -lookX end
			if flipZ then lookZ = -lookZ end
			local mappedLookX = lookX * coordinateCosine - lookZ * coordinateSine
			local mappedLookZ = lookX * coordinateSine + lookZ * coordinateCosine
			local targetHeading = math.deg(math.atan2(mappedLookX, -mappedLookZ)) + L("MapRotationOffsetDegrees", 0)
			local targetPosition = Vector2.new(mapSize * 0.5, mapSize * 0.5) - Vector2.new(mappedX * uiPerStud, mappedZ * uiPerStud)
			local response = math.max(0, tonumber(mapPlayerMarkers.Config:GetAttribute("MapPanResponse")) or L("MapSmoothing", 10))
			local alpha = response <= 0 and 1 or 1 - math.exp(-response * math.max(0, dt or 1 / 60))
			displayedMapPosition = displayedMapPosition and displayedMapPosition:Lerp(targetPosition, alpha) or targetPosition
			if displayedPlayerHeading == nil then displayedPlayerHeading = targetHeading end
			local headingDelta = (targetHeading - displayedPlayerHeading + 180) % 360 - 180
			displayedPlayerHeading += headingDelta * alpha
			if useRelativeCanvas then
				mapCanvas.Position = UDim2.fromScale(displayedMapPosition.X / mapSize, displayedMapPosition.Y / mapSize)
			else
				mapCanvas.Position = UDim2.fromOffset(displayedMapPosition.X, displayedMapPosition.Y)
			end
			mapCanvas.Rotation = 0
			playerMarker.Rotation = B(defaults, "MapPlayerIconRotates", true) and displayedPlayerHeading or 0
			mapPlayerMarkers:Step(dt, {
				MapVisible = minimap.Visible and leftCluster.Visible and gui.Enabled,
				LocalWorldPosition = position,
				MapSize = mapSize,
				VisibleStuds = visibleStuds,
				CoordinateRadians = coordinateRadians,
				CoordinateCosine = coordinateCosine,
				CoordinateSine = coordinateSine,
				FlipX = flipX,
				FlipZ = flipZ,
				LocalMarkerSize = math.max(8, L("MapPlayerIconSize", 22)),
			})
		else
			mapPlayerMarkers:SetVisible(false)
]==]

local DESKTOP_OUTER_CLOSE_OLD = [==[
		end

	end
	if not driving then displayedBoostAlpha = 1 end
]==]

local DESKTOP_OUTER_CLOSE_NEW = [==[
		end
	else
		mapPlayerMarkers:SetVisible(false)
	end
	if not driving then displayedBoostAlpha = 1 end
]==]

local MOBILE_MARKER_CREATE_OLD = [==[
local north=new("ImageLabel",{Name="North",AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"MapNorthArrow"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(22,22),ZIndex=9},mapFrame)
]==]

local MOBILE_MARKER_CREATE_NEW = [==[
local mapPlayerMarkers=require(script.Parent:WaitForChild("FreeRoamMapPlayerMarkers")).new({
	Container=mapFrame,
	Config=kit.Config.UI:WaitForChild("FreeRoamMapPlayerMarkers"),
	ZIndex=7,
})
local north=new("ImageLabel",{Name="North",AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"MapNorthArrow"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(22,22),ZIndex=9},mapFrame)
]==]

local MOBILE_PAN_OLD = [==[
	local s=subject(); if s then local position=s.Position; local mapSize=mapFrame.AbsoluteSize.X; local mapPixels=math.max(1,tonumber(read(desktopLayout,"MapPixels",2048))); local calPixels=math.max(1,tonumber(read(desktopLayout,"MapCalibrationPixels",207))); local calStuds=math.max(1,tonumber(read(desktopLayout,"MapCalibrationStuds",2850))); local fullStuds=mapPixels*calStuds/calPixels; local visible=math.max(100,tonumber(read(desktopLayout,"MapVisibleStuds",2850))); local uiPerStud=mapSize/visible; local canvasSize=fullStuds*uiPerStud; mapCanvas.Size=UDim2.fromOffset(canvasSize,canvasSize); local dx=position.X-tonumber(read(desktopLayout,"MapWorldCenterX",0)); local dz=position.Z-tonumber(read(desktopLayout,"MapWorldCenterZ",0)); if B(desktopDefaults,"MapFlipX",false) then dx=-dx end; if B(desktopDefaults,"MapFlipZ",false) then dz=-dz end; local angle=math.rad(tonumber(read(desktopLayout,"MapCoordinateRotationDegrees",90))); local mx=dx*math.cos(angle)-dz*math.sin(angle); local mz=dx*math.sin(angle)+dz*math.cos(angle); local target=Vector2.new(mapSize*.5,mapSize*.5)-Vector2.new(mx*uiPerStud,mz*uiPerStud); displayedPos=displayedPos and displayedPos:Lerp(target,1-math.exp(-10*dt)) or target; mapCanvas.Position=UDim2.fromOffset(displayedPos.X,displayedPos.Y); mapCanvas.Rotation=0; local look=s.CFrame.LookVector; local lookX,lookZ=look.X,look.Z; if B(desktopDefaults,"MapFlipX",false) then lookX=-lookX end; if B(desktopDefaults,"MapFlipZ",false) then lookZ=-lookZ end; local lx=lookX*math.cos(angle)-lookZ*math.sin(angle); local lz=lookX*math.sin(angle)+lookZ*math.cos(angle); local heading=math.deg(math.atan2(lx,-lz))+tonumber(read(desktopLayout,"MapRotationOffsetDegrees",0)); local diff=(heading-displayedHeading+180)%360-180; displayedHeading+=diff*(1-math.exp(-10*dt)); playerMarker.Rotation=B(desktopDefaults,"MapPlayerIconRotates",true) and displayedHeading or 0 end
]==]

local MOBILE_PAN_NEW = [==[
	local s=subject()
	if s then
		local position=s.Position
		local mapSize=mapFrame.AbsoluteSize.X
		local mapPixels=math.max(1,tonumber(read(desktopLayout,"MapPixels",2048)))
		local calPixels=math.max(1,tonumber(read(desktopLayout,"MapCalibrationPixels",207)))
		local calStuds=math.max(1,tonumber(read(desktopLayout,"MapCalibrationStuds",2850)))
		local fullStuds=mapPixels*calStuds/calPixels
		local visible=math.max(100,tonumber(read(desktopLayout,"MapVisibleStuds",2850)))
		local uiPerStud=mapSize/visible
		local canvasSize=fullStuds*uiPerStud
		local useRelativeCanvas=mapPlayerMarkers.Config:GetAttribute("UseRelativeCanvasTransform")~=false
		if useRelativeCanvas then mapCanvas.Size=UDim2.fromScale(canvasSize/mapSize,canvasSize/mapSize)
		else mapCanvas.Size=UDim2.fromOffset(canvasSize,canvasSize) end
		local dx=position.X-tonumber(read(desktopLayout,"MapWorldCenterX",0))
		local dz=position.Z-tonumber(read(desktopLayout,"MapWorldCenterZ",0))
		local flipX=B(desktopDefaults,"MapFlipX",false)
		local flipZ=B(desktopDefaults,"MapFlipZ",false)
		if flipX then dx=-dx end
		if flipZ then dz=-dz end
		local angle=math.rad(tonumber(read(desktopLayout,"MapCoordinateRotationDegrees",90)))
		local cosine=math.cos(angle)
		local sine=math.sin(angle)
		local mx=dx*cosine-dz*sine
		local mz=dx*sine+dz*cosine
		local target=Vector2.new(mapSize*.5,mapSize*.5)-Vector2.new(mx*uiPerStud,mz*uiPerStud)
		local response=math.max(0,tonumber(mapPlayerMarkers.Config:GetAttribute("MapPanResponse")) or 12)
		local alpha=response<=0 and 1 or 1-math.exp(-response*math.max(0,dt or 1/60))
		displayedPos=displayedPos and displayedPos:Lerp(target,alpha) or target
		if useRelativeCanvas then mapCanvas.Position=UDim2.fromScale(displayedPos.X/mapSize,displayedPos.Y/mapSize)
		else mapCanvas.Position=UDim2.fromOffset(displayedPos.X,displayedPos.Y) end
		mapCanvas.Rotation=0
		local look=s.CFrame.LookVector
		local lookX,lookZ=look.X,look.Z
		if flipX then lookX=-lookX end
		if flipZ then lookZ=-lookZ end
		local lx=lookX*cosine-lookZ*sine
		local lz=lookX*sine+lookZ*cosine
		local heading=math.deg(math.atan2(lx,-lz))+tonumber(read(desktopLayout,"MapRotationOffsetDegrees",0))
		local diff=(heading-displayedHeading+180)%360-180
		displayedHeading+=diff*alpha
		playerMarker.Rotation=B(desktopDefaults,"MapPlayerIconRotates",true) and displayedHeading or 0
		mapPlayerMarkers:Step(dt,{
			MapVisible=mapFrame.Visible and gui.Enabled,
			LocalWorldPosition=position,
			MapSize=mapSize,
			VisibleStuds=visible,
			CoordinateRadians=angle,
			CoordinateCosine=cosine,
			CoordinateSine=sine,
			FlipX=flipX,
			FlipZ=flipZ,
			LocalMarkerSize=18,
		})
	else
		mapPlayerMarkers:SetVisible(false)
	end
]==]

local DESKTOP_MARKER_V11_INSERT = "-- " .. DESKTOP_MARKER_V11 .. "\n"
local MOBILE_MARKER_V11_INSERT = "-- " .. MOBILE_MARKER_V11 .. "\n"

local DESKTOP_CARRIER_DECLARATION_V1 = [==[
local minimap
local mapCanvas
]==]

local DESKTOP_CARRIER_DECLARATION_V11 = [==[
local minimap
local mapPanCarrier
local mapPanCarrierScale
local mapCanvas
]==]

local DESKTOP_CARRIER_CREATE_V1 = [==[
	corner(minimap, 9)
	mapCanvas = new("Frame", { Name = "MapCanvas", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(mapSize * 0.5, mapSize * 0.5), Size = UDim2.fromOffset(mapSize, mapSize), ZIndex = 9 }, minimap)
]==]

local DESKTOP_CARRIER_CREATE_V11 = [==[
	corner(minimap, 9)
	mapPanCarrier = new("Frame", { Name = "MapPanCarrier", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0), Size = UDim2.fromOffset(mapSize, mapSize), ZIndex = 9 }, minimap)
	mapPanCarrierScale = new("UIScale", { Scale = 1 }, mapPanCarrier)
	mapCanvas = new("Frame", { Name = "MapCanvas", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(mapSize * 0.5, mapSize * 0.5), Size = UDim2.fromOffset(mapSize, mapSize), ZIndex = 9 }, mapPanCarrier)
]==]

local DESKTOP_CANVAS_SIZE_V1 = [==[
			local useRelativeCanvas = mapPlayerMarkers.Config:GetAttribute("UseRelativeCanvasTransform") ~= false
			if useRelativeCanvas then
				mapCanvas.Size = UDim2.fromScale(canvasSize / mapSize, canvasSize / mapSize)
			else
				mapCanvas.Size = UDim2.fromOffset(canvasSize, canvasSize)
			end
]==]

local DESKTOP_CANVAS_SIZE_V11 = [==[
			local useRelativeCanvas = mapPlayerMarkers.Config:GetAttribute("UseRelativeCanvasTransform") ~= false
			local subpixelFactor = math.clamp(math.floor((tonumber(mapPlayerMarkers.Config:GetAttribute("MapPanSubpixelFactor")) or 4) + 0.5), 1, 4)
			local carrierSize = UDim2.fromOffset(mapSize * subpixelFactor, mapSize * subpixelFactor)
			if mapPanCarrier.Size ~= carrierSize then mapPanCarrier.Size = carrierSize end
			local carrierScale = 1 / subpixelFactor
			if mapPanCarrierScale.Scale ~= carrierScale then mapPanCarrierScale.Scale = carrierScale end
			local targetCanvasSize
			if subpixelFactor > 1 then
				targetCanvasSize = UDim2.fromOffset(math.floor(canvasSize * subpixelFactor + 0.5), math.floor(canvasSize * subpixelFactor + 0.5))
			elseif useRelativeCanvas then
				targetCanvasSize = UDim2.fromScale(canvasSize / mapSize, canvasSize / mapSize)
			else
				targetCanvasSize = UDim2.fromOffset(canvasSize, canvasSize)
			end
			if mapCanvas.Size ~= targetCanvasSize then mapCanvas.Size = targetCanvasSize end
]==]

local DESKTOP_CANVAS_POSITION_V1 = [==[
			if useRelativeCanvas then
				mapCanvas.Position = UDim2.fromScale(displayedMapPosition.X / mapSize, displayedMapPosition.Y / mapSize)
			else
				mapCanvas.Position = UDim2.fromOffset(displayedMapPosition.X, displayedMapPosition.Y)
			end
]==]

local DESKTOP_CANVAS_POSITION_V11 = [==[
			if subpixelFactor > 1 then
				mapCanvas.Position = UDim2.fromOffset(
					math.floor(displayedMapPosition.X * subpixelFactor + 0.5),
					math.floor(displayedMapPosition.Y * subpixelFactor + 0.5)
				)
			elseif useRelativeCanvas then
				mapCanvas.Position = UDim2.fromScale(displayedMapPosition.X / mapSize, displayedMapPosition.Y / mapSize)
			else
				mapCanvas.Position = UDim2.fromOffset(displayedMapPosition.X, displayedMapPosition.Y)
			end
]==]

local MOBILE_CARRIER_CREATE_V1 = [==[
local mapFrame=new("Frame",{Name="Minimap",BackgroundColor3=DEEP,BackgroundTransparency=.28,BorderSizePixel=0,Size=UDim2.fromOffset(170,170),Position=UDim2.fromOffset(0,0),ClipsDescendants=true,ZIndex=5},root); corner(mapFrame,9)
local mapCanvas=new("Frame",{Name="MapCanvas",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(170,170),ZIndex=6},mapFrame)
]==]

local MOBILE_CARRIER_CREATE_V11 = [==[
local mapFrame=new("Frame",{Name="Minimap",BackgroundColor3=DEEP,BackgroundTransparency=.28,BorderSizePixel=0,Size=UDim2.fromOffset(170,170),Position=UDim2.fromOffset(0,0),ClipsDescendants=true,ZIndex=5},root); corner(mapFrame,9)
local mapPanCarrier=new("Frame",{Name="MapPanCarrier",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromScale(0,0),Size=UDim2.fromOffset(170,170),ZIndex=6},mapFrame)
local mapPanCarrierScale=new("UIScale",{Scale=1},mapPanCarrier)
local mapCanvas=new("Frame",{Name="MapCanvas",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(170,170),ZIndex=6},mapPanCarrier)
]==]

local MOBILE_CANVAS_SIZE_V1 = [==[
		local useRelativeCanvas=mapPlayerMarkers.Config:GetAttribute("UseRelativeCanvasTransform")~=false
		if useRelativeCanvas then mapCanvas.Size=UDim2.fromScale(canvasSize/mapSize,canvasSize/mapSize)
		else mapCanvas.Size=UDim2.fromOffset(canvasSize,canvasSize) end
]==]

local MOBILE_CANVAS_SIZE_V11 = [==[
		local useRelativeCanvas=mapPlayerMarkers.Config:GetAttribute("UseRelativeCanvasTransform")~=false
		local subpixelFactor=math.clamp(math.floor((tonumber(mapPlayerMarkers.Config:GetAttribute("MapPanSubpixelFactor")) or 4)+.5),1,4)
		local carrierSize=UDim2.fromOffset(mapSize*subpixelFactor,mapSize*subpixelFactor)
		if mapPanCarrier.Size~=carrierSize then mapPanCarrier.Size=carrierSize end
		local carrierScale=1/subpixelFactor
		if mapPanCarrierScale.Scale~=carrierScale then mapPanCarrierScale.Scale=carrierScale end
		local targetCanvasSize
		if subpixelFactor>1 then targetCanvasSize=UDim2.fromOffset(math.floor(canvasSize*subpixelFactor+.5),math.floor(canvasSize*subpixelFactor+.5))
		elseif useRelativeCanvas then targetCanvasSize=UDim2.fromScale(canvasSize/mapSize,canvasSize/mapSize)
		else targetCanvasSize=UDim2.fromOffset(canvasSize,canvasSize) end
		if mapCanvas.Size~=targetCanvasSize then mapCanvas.Size=targetCanvasSize end
]==]

local MOBILE_CANVAS_POSITION_V1 = [==[
		if useRelativeCanvas then mapCanvas.Position=UDim2.fromScale(displayedPos.X/mapSize,displayedPos.Y/mapSize)
		else mapCanvas.Position=UDim2.fromOffset(displayedPos.X,displayedPos.Y) end
]==]

local MOBILE_CANVAS_POSITION_V11 = [==[
		if subpixelFactor>1 then mapCanvas.Position=UDim2.fromOffset(math.floor(displayedPos.X*subpixelFactor+.5),math.floor(displayedPos.Y*subpixelFactor+.5))
		elseif useRelativeCanvas then mapCanvas.Position=UDim2.fromScale(displayedPos.X/mapSize,displayedPos.Y/mapSize)
		else mapCanvas.Position=UDim2.fromOffset(displayedPos.X,displayedPos.Y) end
]==]

local function desktopShapeComplete(source)
	return countPlain(source, DESKTOP_MARKER) == 1
		and countPlain(source, DESKTOP_DECLARATION_NEW) == 1
		and countPlain(source, DESKTOP_MARKER_CREATE_NEW) == 1
		and countPlain(source, DESKTOP_PAN_NEW) == 1
		and countPlain(source, DESKTOP_OUTER_CLOSE_NEW) == 1
end

local function mobileShapeComplete(source)
	return countPlain(source, MOBILE_MARKER) == 1
		and countPlain(source, MOBILE_MARKER_CREATE_NEW) == 1
		and countPlain(source, MOBILE_PAN_NEW) == 1
end

local function desktopV11ShapeComplete(source)
	return countPlain(source, DESKTOP_MARKER_INSERT) == 1
		and countPlain(source, DESKTOP_MARKER_V11_INSERT) == 1
		and countPlain(source, DESKTOP_DECLARATION_NEW) == 1
		and countPlain(source, DESKTOP_MARKER_CREATE_NEW) == 1
		and countPlain(source, DESKTOP_OUTER_CLOSE_NEW) == 1
		and countPlain(source, DESKTOP_CARRIER_DECLARATION_V11) == 1
		and countPlain(source, DESKTOP_CARRIER_CREATE_V11) == 1
		and countPlain(source, DESKTOP_CANVAS_SIZE_V11) == 1
		and countPlain(source, DESKTOP_CANVAS_POSITION_V11) == 1
end

local function mobileV11ShapeComplete(source)
	return countPlain(source, MOBILE_MARKER_INSERT) == 1
		and countPlain(source, MOBILE_MARKER_V11_INSERT) == 1
		and countPlain(source, MOBILE_MARKER_CREATE_NEW) == 1
		and countPlain(source, MOBILE_CARRIER_CREATE_V11) == 1
		and countPlain(source, MOBILE_CANVAS_SIZE_V11) == 1
		and countPlain(source, MOBILE_CANVAS_POSITION_V11) == 1
end

local function upgradeDesktopV11(source)
	if countPlain(source, DESKTOP_MARKER_V11) == 1 then
		if not desktopV11ShapeComplete(source) then fail("Desktop contains a partial or drifted V1.1 installation.") end
		return source
	end
	if not desktopShapeComplete(source) then fail("Desktop is not the confirmed V1 baseline.") end
	source = insertBeforeOnce(source, DESKTOP_MARKER_INSERT, DESKTOP_MARKER_V11_INSERT, "Desktop V1.1 marker")
	source = replaceOnce(source, DESKTOP_CARRIER_DECLARATION_V1, DESKTOP_CARRIER_DECLARATION_V11, "Desktop subpixel carrier declaration")
	source = replaceOnce(source, DESKTOP_CARRIER_CREATE_V1, DESKTOP_CARRIER_CREATE_V11, "Desktop subpixel carrier construction")
	source = replaceOnce(source, DESKTOP_CANVAS_SIZE_V1, DESKTOP_CANVAS_SIZE_V11, "Desktop logical canvas size")
	source = replaceOnce(source, DESKTOP_CANVAS_POSITION_V1, DESKTOP_CANVAS_POSITION_V11, "Desktop logical canvas position")
	return source
end

local function upgradeMobileV11(source)
	if countPlain(source, MOBILE_MARKER_V11) == 1 then
		if not mobileV11ShapeComplete(source) then fail("Mobile contains a partial or drifted V1.1 installation.") end
		return source
	end
	if not mobileShapeComplete(source) then fail("Mobile is not the confirmed V1 baseline.") end
	source = insertBeforeOnce(source, MOBILE_MARKER_INSERT, MOBILE_MARKER_V11_INSERT, "Mobile V1.1 marker")
	source = replaceOnce(source, MOBILE_CARRIER_CREATE_V1, MOBILE_CARRIER_CREATE_V11, "Mobile subpixel carrier construction")
	source = replaceOnce(source, MOBILE_CANVAS_SIZE_V1, MOBILE_CANVAS_SIZE_V11, "Mobile logical canvas size")
	source = replaceOnce(source, MOBILE_CANVAS_POSITION_V1, MOBILE_CANVAS_POSITION_V11, "Mobile logical canvas position")
	return source
end

local function rollbackDesktopV11(source)
	if countPlain(source, DESKTOP_MARKER_V11) == 0 then return source end
	if not desktopV11ShapeComplete(source) then fail("Desktop V1.1 source drifted; exact rollback refused.") end
	source = replaceOnce(source, DESKTOP_CANVAS_POSITION_V11, DESKTOP_CANVAS_POSITION_V1, "Rollback desktop logical position")
	source = replaceOnce(source, DESKTOP_CANVAS_SIZE_V11, DESKTOP_CANVAS_SIZE_V1, "Rollback desktop logical size")
	source = replaceOnce(source, DESKTOP_CARRIER_CREATE_V11, DESKTOP_CARRIER_CREATE_V1, "Rollback desktop carrier")
	source = replaceOnce(source, DESKTOP_CARRIER_DECLARATION_V11, DESKTOP_CARRIER_DECLARATION_V1, "Rollback desktop carrier declaration")
	source = replaceOnce(source, DESKTOP_MARKER_V11_INSERT, "", "Rollback desktop V1.1 marker")
	return source
end

local function rollbackMobileV11(source)
	if countPlain(source, MOBILE_MARKER_V11) == 0 then return source end
	if not mobileV11ShapeComplete(source) then fail("Mobile V1.1 source drifted; exact rollback refused.") end
	source = replaceOnce(source, MOBILE_CANVAS_POSITION_V11, MOBILE_CANVAS_POSITION_V1, "Rollback mobile logical position")
	source = replaceOnce(source, MOBILE_CANVAS_SIZE_V11, MOBILE_CANVAS_SIZE_V1, "Rollback mobile logical size")
	source = replaceOnce(source, MOBILE_CARRIER_CREATE_V11, MOBILE_CARRIER_CREATE_V1, "Rollback mobile carrier")
	source = replaceOnce(source, MOBILE_MARKER_V11_INSERT, "", "Rollback mobile V1.1 marker")
	return source
end

local function installDesktop(source)
	local markerCount = countPlain(source, DESKTOP_MARKER)
	if markerCount == 1 then
		if not desktopShapeComplete(source) then
			fail("Desktop contains a partial or drifted V1 installation. Refresh/inspect before repair.")
		end
		return source
	elseif markerCount ~= 0 then
		fail("Desktop contains an unexpected V1 marker count.")
	end
	source = insertBeforeOnce(source, "-- NTR_FREEROAM_CASH_SMOOTHING_DESKTOP_V1\n",
		DESKTOP_MARKER_INSERT, "Desktop V1 marker")
	source = replaceOnce(source, DESKTOP_DECLARATION_OLD, DESKTOP_DECLARATION_NEW, "Desktop marker declaration")
	source = replaceOnce(source, DESKTOP_MARKER_CREATE_OLD, DESKTOP_MARKER_CREATE_NEW, "Desktop marker construction")
	source = replaceOnce(source, DESKTOP_PAN_OLD, DESKTOP_PAN_NEW, "Desktop pan projection")
	source = replaceOnce(source, DESKTOP_OUTER_CLOSE_OLD, DESKTOP_OUTER_CLOSE_NEW, "Desktop hidden marker cleanup")
	return source
end

local function installMobile(source)
	local markerCount = countPlain(source, MOBILE_MARKER)
	if markerCount == 1 then
		if not mobileShapeComplete(source) then
			fail("Mobile contains a partial or drifted V1 installation. Refresh/inspect before repair.")
		end
		return source
	elseif markerCount ~= 0 then
		fail("Mobile contains an unexpected V1 marker count.")
	end
	source = insertBeforeOnce(source, "-- NTR_FREEROAM_CASH_SMOOTHING_MOBILE_V1\n",
		MOBILE_MARKER_INSERT, "Mobile V1 marker")
	source = replaceOnce(source, MOBILE_MARKER_CREATE_OLD, MOBILE_MARKER_CREATE_NEW, "Mobile marker construction")
	source = replaceOnce(source, MOBILE_PAN_OLD, MOBILE_PAN_NEW, "Mobile pan projection")
	return source
end

local function rollbackDesktop(source)
	if countPlain(source, DESKTOP_MARKER) == 0 then return source end
	if not desktopShapeComplete(source) then
		fail("Desktop V1 source drifted; exact rollback refused.")
	end
	source = replaceOnce(source, DESKTOP_OUTER_CLOSE_NEW, DESKTOP_OUTER_CLOSE_OLD, "Rollback desktop hidden cleanup")
	source = replaceOnce(source, DESKTOP_PAN_NEW, DESKTOP_PAN_OLD, "Rollback desktop pan")
	source = replaceOnce(source, DESKTOP_MARKER_CREATE_NEW, DESKTOP_MARKER_CREATE_OLD, "Rollback desktop marker construction")
	source = replaceOnce(source, DESKTOP_DECLARATION_NEW, DESKTOP_DECLARATION_OLD, "Rollback desktop declaration")
	source = replaceOnce(source, DESKTOP_MARKER_INSERT, "", "Rollback desktop marker")
	return source
end

local function rollbackMobile(source)
	if countPlain(source, MOBILE_MARKER) == 0 then return source end
	if not mobileShapeComplete(source) then
		fail("Mobile V1 source drifted; exact rollback refused.")
	end
	source = replaceOnce(source, MOBILE_PAN_NEW, MOBILE_PAN_OLD, "Rollback mobile pan")
	source = replaceOnce(source, MOBILE_MARKER_CREATE_NEW, MOBILE_MARKER_CREATE_OLD, "Rollback mobile marker construction")
	source = replaceOnce(source, MOBILE_MARKER_INSERT, "", "Rollback mobile marker")
	return source
end

local function featureConfig()
	local folder = uiConfig:FindFirstChild(CONFIG_NAME)
	if folder and not folder:IsA("Folder") then fail(folder:GetFullName() .. " must be a Folder.") end
	return folder
end

local function featureModule()
	local module = uiControllers:FindFirstChild(MODULE_NAME)
	if module and not module:IsA("ModuleScript") then fail(module:GetFullName() .. " must be a ModuleScript.") end
	return module
end

local function audit()
	local blockers = {}
	local warnings = {}
	local function requireCheck(condition, message) if not condition then table.insert(blockers, message) end end
	local function warnCheck(condition, message) if not condition then table.insert(warnings, message) end end
	local config = featureConfig()
	local module = featureModule()

	requireCheck(config ~= nil, "Shared map-player config is missing.")
	requireCheck(module ~= nil, "Shared map-player module is missing.")
	requireCheck(desktopV11ShapeComplete(desktop.Source), "Desktop V1.1 source shape is incomplete.")
	requireCheck(mobileV11ShapeComplete(mobile.Source), "Mobile V1.1 source shape is incomplete.")
	if config then
		requireCheck(config:GetAttribute("Revision") == REVISION, "Config revision is missing.")
		for name in pairs(CONFIG_DEFAULTS) do
			requireCheck(config:GetAttribute(name) ~= nil, "Config attribute " .. name .. " is missing.")
		end
		requireCheck(math.abs((tonumber(config:GetAttribute("OtherPlayerMarkerScale")) or 0) - 0.65) < 0.001,
			"OtherPlayerMarkerScale is not the approved 0.65 ratio.")
		local subpixelFactor = tonumber(config:GetAttribute("MapPanSubpixelFactor")) or 0
		requireCheck(subpixelFactor >= 1 and subpixelFactor <= 4,
			"MapPanSubpixelFactor must remain within 1..4.")
		warnCheck(subpixelFactor == 4,
			"MapPanSubpixelFactor is using its supported fallback instead of the approved factor 4.")
		warnCheck(config:GetAttribute("UseRelativeCanvasTransform") == true,
			"Relative canvas transform fallback is disabled.")
		requireCheck((tonumber(config:GetAttribute("MaximumOtherPlayers")) or 0) <= 14,
			"MaximumOtherPlayers exceeds the approved 15-player budget.")
		warnCheck(tostring(config:GetAttribute("OtherPlayerIcon") or "") ~= "",
			"OtherPlayerIcon is empty; the lightweight circular Frame/UIStroke fallback will be used.")
	end
	if module then
		requireCheck(moduleV11ShapeComplete(module.Source), "Shared marker module V1.1 source shape is incomplete.")
		requireCheck(module:GetAttribute("Revision") == REVISION, "Shared marker module revision is missing.")
		requireCheck(string.find(module.Source, "Players.PlayerAdded", 1, true) ~= nil,
			"Event-driven PlayerAdded registration is missing.")
		requireCheck(string.find(module.Source, "Players.PlayerRemoving", 1, true) ~= nil,
			"Event-driven PlayerRemoving cleanup is missing.")
		requireCheck(string.find(module.Source, 'GetPropertyChangedSignal("SeatPart")', 1, true) ~= nil
			and string.find(module.Source, "NTR_RaceParticipant", 1, true) ~= nil
			and string.find(module.Source, "NTR_RaceRunId", 1, true) ~= nil
			and string.find(module.Source, "NTR_RaceMode", 1, true) ~= nil
			and string.find(module.Source, "NTR_RaceFinishedPendingExit", 1, true) ~= nil,
			"Event-driven seated race-vehicle filtering is missing.")
		requireCheck(string.find(module.Source, "GetDescendants", 1, true) == nil,
			"Shared marker module must not scan descendants.")
		requireCheck(string.find(module.Source, "RemoteEvent", 1, true) == nil
			and string.find(module.Source, "RemoteFunction", 1, true) == nil
			and string.find(module.Source, "FireServer", 1, true) == nil,
			"Shared marker module must remain client-only with no remote.")
		requireCheck(string.find(module.Source, "RenderStepped", 1, true) == nil
			and string.find(module.Source, "BindToRenderStep", 1, true) == nil,
			"Shared marker module must reuse the existing HUD render owners.")
	end
	requireCheck(desktop:GetAttribute("FreeRoamMapPlayersRevision") == REVISION,
		"Desktop controller revision is missing.")
	requireCheck(mobile:GetAttribute("FreeRoamMapPlayersRevision") == REVISION,
		"Mobile controller revision is missing.")
	requireCheck(string.find(desktop.Source, "local carrierScale = 1 / subpixelFactor", 1, true) ~= nil
		and string.find(desktop.Source, "displayedMapPosition.X * subpixelFactor", 1, true) ~= nil,
		"Desktop four-times logical pan carrier is missing.")
	requireCheck(string.find(mobile.Source, "local carrierScale=1/subpixelFactor", 1, true) ~= nil
		and string.find(mobile.Source, "displayedPos.X*subpixelFactor", 1, true) ~= nil,
		"Mobile four-times logical pan carrier is missing.")
	requireCheck(string.find(desktop.Source, "1 - math.exp(-response", 1, true) ~= nil,
		"Desktop frame-rate-independent pan smoothing is missing.")
	requireCheck(string.find(mobile.Source, "1-math.exp(-response", 1, true) ~= nil,
		"Mobile frame-rate-independent pan smoothing is missing.")
	requireCheck(string.find(desktop.Source, "mapCanvas.Rotation = 0", 1, true) ~= nil
		and string.find(mobile.Source, "mapCanvas.Rotation=0", 1, true) ~= nil,
		"North-up map rotation contract is missing.")

	if #blockers > 0 then
		for _, message in ipairs(blockers) do warn("[" .. PHASE .. "] BLOCKER " .. message) end
		fail("AUDIT FAIL blockers=" .. #blockers .. " warnings=" .. #warnings)
	end
	for _, message in ipairs(warnings) do warn("[" .. PHASE .. "] WARN " .. message) end
	log(string.format(
		"AUDIT PASS clientOnly=true desktop=true mobile=true markerScale=%.2f panResponse=%.1f subpixelFactor=%d raceVehicleFilter=true maxOtherPlayers=%d warnings=%d",
		tonumber(config:GetAttribute("OtherPlayerMarkerScale")) or 0,
		tonumber(config:GetAttribute("MapPanResponse")) or 0,
		math.floor(tonumber(config:GetAttribute("MapPanSubpixelFactor")) or 0),
		math.floor(tonumber(config:GetAttribute("MaximumOtherPlayers")) or 0),
		#warnings))
end

local function rollback()
	local config = featureConfig()
	local existingModuleForRollback = featureModule()
	if config and config:GetAttribute("Revision") == REVISION_V1
		and existingModuleForRollback and existingModuleForRollback:GetAttribute("Revision") == REVISION_V1
		and desktop:GetAttribute("FreeRoamMapPlayersRevision") == REVISION_V1
		and mobile:GetAttribute("FreeRoamMapPlayersRevision") == REVISION_V1 then
		log("ROLLBACK PASS. Confirmed V1 baseline is already restored.")
		return
	end
	if not config or not existingModuleForRollback then
		fail("V1.1 rollback requires its shared config and module; rollback refused.")
	end
	if desktop:GetAttribute("FreeRoamMapPlayersRevision") ~= REVISION
		or mobile:GetAttribute("FreeRoamMapPlayersRevision") ~= REVISION then
		fail("A HUD revision is unknown; rollback refused.")
	end
	local projectedDesktop = rollbackDesktopV11(desktop.Source)
	local projectedMobile = rollbackMobileV11(mobile.Source)
	local module = featureModule()
	local projectedModule = module and rollbackModuleV11(module.Source) or nil
	compile(projectedDesktop, "Desktop free-roam rollback")
	compile(projectedMobile, "Mobile free-roam rollback")
	if projectedModule then compile(projectedModule, "FreeRoamMapPlayerMarkers rollback") end

	if config and config:GetAttribute("Revision") ~= REVISION then
		fail("Shared config has an unknown revision; rollback refused.")
	end
	if module and module:GetAttribute("Revision") ~= REVISION then
		fail("Shared module has an unknown revision; rollback refused.")
	end

	desktop.Source = projectedDesktop
	mobile.Source = projectedMobile
	desktop:SetAttribute("FreeRoamMapPlayersRevision", REVISION_V1)
	mobile:SetAttribute("FreeRoamMapPlayersRevision", REVISION_V1)
	if module then
		module.Source = projectedModule
		module:SetAttribute("Revision", REVISION_V1)
	end
	if config then
		config:SetAttribute("MapPanSubpixelFactor", nil)
		config:SetAttribute("Revision", REVISION_V1)
	end
	ChangeHistoryService:SetWaypoint(PHASE .. " rollback")
	log("ROLLBACK PASS. Restored the confirmed V1 player markers and relative-pan baseline.")
end

if MODE == "AUDIT" then
	audit()
	return
elseif MODE == "ROLLBACK" then
	rollback()
	return
elseif MODE ~= "INSTALL" then
	fail("Unknown MODE " .. tostring(MODE))
end

local existingConfig = featureConfig()
if existingConfig and existingConfig:GetAttribute("Revision") ~= REVISION
	and existingConfig:GetAttribute("Revision") ~= REVISION_V1 then
	fail("A different " .. CONFIG_NAME .. " owner already exists.")
end
local existingModule = featureModule()
if existingModule and existingModule:GetAttribute("Revision") ~= REVISION
	and existingModule:GetAttribute("Revision") ~= REVISION_V1 then
	fail("A different " .. MODULE_NAME .. " owner already exists.")
end

local desktopV1Source = countPlain(desktop.Source, DESKTOP_MARKER_V11) == 1
	and desktop.Source or installDesktop(desktop.Source)
local mobileV1Source = countPlain(mobile.Source, MOBILE_MARKER_V11) == 1
	and mobile.Source or installMobile(mobile.Source)
local projectedDesktop = upgradeDesktopV11(desktopV1Source)
local projectedMobile = upgradeMobileV11(mobileV1Source)
local projectedModule = existingModule and upgradeModuleV11(existingModule.Source) or MODULE_SOURCE_V11
compile(projectedModule, "FreeRoamMapPlayerMarkers projected")
compile(projectedDesktop, "Desktop free-roam projected")
compile(projectedMobile, "Mobile free-roam projected")

local snapshot = {
	DesktopSource = desktop.Source,
	MobileSource = mobile.Source,
	DesktopAttributes = desktop:GetAttributes(),
	MobileAttributes = mobile:GetAttributes(),
	ConfigExisted = existingConfig ~= nil,
	ConfigAttributes = existingConfig and existingConfig:GetAttributes() or nil,
	ModuleExisted = existingModule ~= nil,
	ModuleSource = existingModule and existingModule.Source or nil,
	ModuleAttributes = existingModule and existingModule:GetAttributes() or nil,
}

local ok, problem = pcall(function()
	local config = existingConfig
	if not config then
		config = Instance.new("Folder")
		config.Name = CONFIG_NAME
		config.Parent = uiConfig
	end
	for name, value in pairs(CONFIG_DEFAULTS) do
		if config:GetAttribute(name) == nil then config:SetAttribute(name, value) end
	end
	config:SetAttribute("Revision", REVISION)

	local module = existingModule
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = MODULE_NAME
		module.Parent = uiControllers
	end
	module.Source = projectedModule
	module:SetAttribute("Revision", REVISION)

	desktop.Source = projectedDesktop
	mobile.Source = projectedMobile
	desktop:SetAttribute("FreeRoamMapPlayersRevision", REVISION)
	mobile:SetAttribute("FreeRoamMapPlayersRevision", REVISION)
	audit()
end)

if not ok then
	desktop.Source = snapshot.DesktopSource
	mobile.Source = snapshot.MobileSource
	restoreAttributes(desktop, snapshot.DesktopAttributes)
	restoreAttributes(mobile, snapshot.MobileAttributes)

	local config = featureConfig()
	if snapshot.ConfigExisted then
		if not config then
			config = Instance.new("Folder")
			config.Name = CONFIG_NAME
			config.Parent = uiConfig
		end
		restoreAttributes(config, snapshot.ConfigAttributes)
	elseif config then
		config:Destroy()
	end

	local module = featureModule()
	if snapshot.ModuleExisted then
		if not module then
			module = Instance.new("ModuleScript")
			module.Name = MODULE_NAME
			module.Parent = uiControllers
		end
		module.Source = snapshot.ModuleSource
		restoreAttributes(module, snapshot.ModuleAttributes)
	elseif module then
		module:Destroy()
	end
	fail("INSTALL ROLLED BACK: " .. tostring(problem))
end

ChangeHistoryService:SetWaypoint(PHASE .. " install")
log("INSTALL PASS. Restart Play; test slow/fast pan, 2-player markers, race/TT suppression, streaming edges, and landscape mobile.")
