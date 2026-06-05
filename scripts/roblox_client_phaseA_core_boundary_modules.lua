-- Neo Tokyo Racers - Main Client Extraction Phase A
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates the Core client boundary modules for the future extraction of
--   HOVER_RACING_V2_Client. This phase stages shared state/API/catalog/theme/
--   paint logic in the new architecture without changing live gameplay.
--
-- Safe effects:
--   - Creates/updates ModuleScripts under:
--     StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit, disable, enable, rename, move, or delete HOVER_RACING_V2_Client.
--   - Replace live UI rendering, preview building, driving handoff, or camera logic.
--   - Change server actions, vehicle logic, VFX, mobile controls, LOD, lighting,
--     traffic, assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_client_phaseA_core_boundary_modules"

local function log(message)
	print("[NTR Client Phase A] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No changes applied.")
		end
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
end

local function writeModule(parent, name, source)
	local module = parent:FindFirstChild(name)
	if module and not module:IsA("ModuleScript") then
		error("Existing " .. module:GetFullName() .. " is a " .. module.ClassName .. ", expected ModuleScript. No changes applied.")
	end
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Parent = parent
	end

	local createdBy = module:GetAttribute("CreatedBy")
	if module.Source ~= "" and createdBy ~= SCRIPT_ID then
		error("Target " .. module:GetFullName() .. " already exists and was not created by this phase. No changes applied.")
	end

	module.Source = source
	module:SetAttribute("CreatedBy", SCRIPT_ID)
	module:SetAttribute("MigrationStatus", "PhaseA_CoreBoundary")
	module:SetAttribute("LiveEnabled", false)
	module:SetAttribute("LastUpdated", os.date("%Y-%m-%d %H:%M:%S"))
	return module
end

local clientStateSource = [=[
-- Neo Tokyo Racers client state boundary.
-- Phase A module. Not live until HOVER_RACING_V2_Client is explicitly adapted.

local ClientState = {}

ClientState.DefaultState = {
	Stage = "CockpitShop",
	ModuleMode = "Slots",
	CustomizeMode = "Overview",
	Catalog = nil,
	Profile = nil,
	CategoryId = "bruiser",
	SelectedCockpit = "bruiser_01",
	SelectedSlot = nil,
	SelectedModuleId = nil,
	CustomizeTarget = "ALL",
	ColorChannel = "Primary",
	Hue = 0.52,
	Saturation = 0.9,
	Brightness = 0.9,
	PreviewModules = {},
	GarageCameraActive = true,
	CameraFocus = Vector3.new(860, 104, -1749),
	TargetFocus = Vector3.new(860, 104, -1749),
	CameraYaw = math.rad(180),
	TargetYaw = math.rad(180),
	CameraPitch = math.rad(-12),
	TargetPitch = math.rad(-12),
	CameraDistance = 24.3,
	TargetDistance = 24.3,
	Dragging = false,
	LastPointer = nil,
}

local function cloneValue(value)
	if typeof(value) == "table" then
		local copy = {}
		for key, child in pairs(value) do
			copy[key] = cloneValue(child)
		end
		return copy
	end
	return value
end

function ClientState.CloneArray(list)
	local copy = {}
	for i, value in ipairs(list or {}) do
		copy[i] = value
	end
	return copy
end

function ClientState.Create(initial)
	local state = cloneValue(ClientState.DefaultState)
	for key, value in pairs(initial or {}) do
		state[key] = value
	end
	return state
end

function ClientState.ResetPreviewSelection(state)
	state.PreviewModules = {}
	state.SelectedModuleId = nil
end

function ClientState.ApplyProfile(state, profile)
	if profile ~= nil then
		state.Profile = profile
	end
	return state
end

return ClientState
]=]

local garageApiClientSource = [=[
-- Neo Tokyo Racers garage API client boundary.
-- Phase A module. Wraps GarageInvoke response handling without changing response shape.

local GarageApiClient = {}
GarageApiClient.__index = GarageApiClient

function GarageApiClient.new(remoteFunction, state)
	return setmetatable({
		Remote = remoteFunction,
		State = state,
		LastError = nil,
	}, GarageApiClient)
end

function GarageApiClient:Call(action, args)
	if not self.Remote then
		self.LastError = "Garage remote missing."
		return { Success = false, Message = self.LastError }
	end

	local ok, result = pcall(function()
		return self.Remote:InvokeServer(action, args or {})
	end)

	if ok and typeof(result) == "table" then
		if result.Profile and self.State then
			self.State.Profile = result.Profile
		end
		self.LastError = nil
		return result
	end

	self.LastError = ok and "Garage server returned an invalid response." or tostring(result)
	return { Success = false, Message = "Garage server did not respond." }
end

return GarageApiClient
]=]

local catalogClientSource = [=[
-- Neo Tokyo Racers catalog lookup boundary.
-- Phase A module. Mirrors HOVER_RACING_V2_Client catalog helper behaviour.

local CatalogClient = {}
CatalogClient.__index = CatalogClient

local function cloneArray(list)
	local copy = {}
	for i, value in ipairs(list or {}) do
		copy[i] = value
	end
	return copy
end

function CatalogClient.new(state)
	return setmetatable({
		State = state,
	}, CatalogClient)
end

function CatalogClient:GetCategory(categoryId)
	local state = self.State or {}
	local wanted = categoryId or state.CategoryId
	for _, category in ipairs((state.Catalog and state.Catalog.Categories) or {}) do
		if category.CategoryId == wanted then
			return category
		end
	end
	return nil
end

function CatalogClient:SortedSlots(categoryId)
	local category = self:GetCategory(categoryId)
	local slots = cloneArray(category and category.Slots)
	table.sort(slots, function(a, b)
		return (a.Order or 99) < (b.Order or 99)
	end)
	return slots
end

function CatalogClient:GetSlot(slotId)
	for _, slot in ipairs(self:SortedSlots()) do
		if slot.SlotId == slotId then
			return slot
		end
	end
	return nil
end

function CatalogClient:GetCockpit(cockpitId)
	local category = self:GetCategory()
	for _, cockpit in ipairs((category and category.Cockpits) or {}) do
		if cockpit.CockpitId == cockpitId then
			return cockpit
		end
	end
	return nil
end

function CatalogClient:GetModule(moduleId)
	local category = self:GetCategory()
	for _, list in pairs((category and category.Modules) or {}) do
		for _, module in ipairs(list) do
			if module.ModuleId == moduleId then
				return module
			end
		end
	end
	return nil
end

function CatalogClient:ModulesForSlot(slotId)
	local state = self.State or {}
	local slot = self:GetSlot(slotId)
	local category = self:GetCategory()
	local result = {}
	if not slot or not category then
		return result
	end

	local list = (category.Modules and category.Modules[slot.ModuleType]) or {}
	for _, module in ipairs(list) do
		if not slot.AllowedModuleFolder or slot.AllowedModuleFolder == "" or module.ModuleFolder == slot.AllowedModuleFolder then
			table.insert(result, module)
		end
	end

	local owned = (state.Profile and state.Profile.OwnedModules) or {}
	table.sort(result, function(a, b)
		local aOwned = owned[a.ModuleId] == true
		local bOwned = owned[b.ModuleId] == true
		if aOwned ~= bOwned then
			return not aOwned
		end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)

	return result
end

function CatalogClient.SlotDisplayName(slot)
	local slotId = typeof(slot) == "table" and slot.SlotId or tostring(slot or "")
	if slotId == "Engine1" then return "Front Engine" end
	if slotId == "Engine2" then return "Rear Engine" end
	if typeof(slot) == "table" then return slot.DisplayName or slot.SlotId end
	return slotId
end

return CatalogClient
]=]

local themeAdapterSource = [=[
-- Neo Tokyo Racers client theme adapter.
-- Phase A module. Reads UI_THEME_DoNotRename values into a plain theme table.

local ClientThemeAdapter = {}

ClientThemeAdapter.DefaultTheme = {
	Panel = Color3.fromRGB(5, 9, 7),
	PanelSoft = Color3.fromRGB(12, 20, 17),
	Card = Color3.fromRGB(24, 35, 42),
	CardHot = Color3.fromRGB(36, 118, 82),
	Text = Color3.fromRGB(218, 255, 231),
	Muted = Color3.fromRGB(145, 178, 160),
	Accent = Color3.fromRGB(172, 255, 197),
	Cash = Color3.fromRGB(255, 193, 50),
	Danger = Color3.fromRGB(175, 70, 68),
	Buy = Color3.fromRGB(8, 145, 112),
	Disabled = Color3.fromRGB(62, 72, 73),
	PanelTransparency = 0.12,
	ButtonTransparency = 0.08,
	PanelStrokeTransparency = 0.2,
	ButtonStrokeTransparency = 0.62,
	StrokeWidth = 1,
	PanelCornerRadius = 5,
	ButtonCornerRadius = 4,
	FontFamily = "rbxasset://fonts/families/Michroma.json",
}

local function readThemeColor(themeFolder, name, fallback, alternateName)
	local item = themeFolder and (themeFolder:FindFirstChild(name) or (alternateName and themeFolder:FindFirstChild(alternateName)))
	return item and item:IsA("Color3Value") and item.Value or fallback
end

local function readThemeNumber(themeFolder, name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function readThemeString(themeFolder, name, fallback)
	local item = themeFolder and themeFolder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

function ClientThemeAdapter.Read(themeFolder)
	local default = ClientThemeAdapter.DefaultTheme
	return {
		Panel = readThemeColor(themeFolder, "Panel", default.Panel),
		PanelSoft = readThemeColor(themeFolder, "PanelSoft", default.PanelSoft),
		Card = readThemeColor(themeFolder, "Card", default.Card),
		CardHot = readThemeColor(themeFolder, "Selected", default.CardHot, "CardHot"),
		Text = readThemeColor(themeFolder, "Text", default.Text),
		Muted = readThemeColor(themeFolder, "Muted", default.Muted),
		Accent = readThemeColor(themeFolder, "Accent", default.Accent),
		Cash = readThemeColor(themeFolder, "Cash", default.Cash),
		Danger = readThemeColor(themeFolder, "Danger", default.Danger),
		Buy = readThemeColor(themeFolder, "Buy", default.Buy),
		Disabled = readThemeColor(themeFolder, "Disabled", default.Disabled),
		PanelTransparency = math.clamp(readThemeNumber(themeFolder, "PanelTransparency", default.PanelTransparency), 0, 1),
		ButtonTransparency = math.clamp(readThemeNumber(themeFolder, "ButtonTransparency", default.ButtonTransparency), 0, 1),
		PanelStrokeTransparency = math.clamp(readThemeNumber(themeFolder, "PanelStrokeTransparency", default.PanelStrokeTransparency), 0, 1),
		ButtonStrokeTransparency = math.clamp(readThemeNumber(themeFolder, "ButtonStrokeTransparency", default.ButtonStrokeTransparency), 0, 1),
		StrokeWidth = math.max(0, readThemeNumber(themeFolder, "StrokeWidth", default.StrokeWidth)),
		PanelCornerRadius = math.max(0, readThemeNumber(themeFolder, "PanelCornerRadius", default.PanelCornerRadius)),
		ButtonCornerRadius = math.max(0, readThemeNumber(themeFolder, "ButtonCornerRadius", default.ButtonCornerRadius)),
		FontFamily = readThemeString(themeFolder, "FontFamily", default.FontFamily),
	}
end

return ClientThemeAdapter
]=]

local paintClientSource = [=[
-- Neo Tokyo Racers paint/channel utility boundary.
-- Phase A module. Mirrors current client paint channel rules.

local PaintClient = {}

PaintClient.ChannelFolders = {
	PRIMARY_ReplaceWithPrimaryMeshes = "Primary",
	SECONDARY_ReplaceWithSecondaryMeshes = "Secondary",
	DETAIL_ReplaceWithDetailMeshes = "Detail",
	NEON_OptionalLights = "Neon",
	THRUST_COLOR_WhiteByDefault = "ThrustColor",
}

function PaintClient.ResolvePaintChannel(part)
	local current = part
	while current do
		local folderChannel = PaintClient.ChannelFolders[current.Name]
		if folderChannel then
			return folderChannel
		end
		current = current.Parent
	end

	current = part
	while current do
		local attr = current:GetAttribute("PaintChannel")
		if typeof(attr) == "string" and attr ~= "" then
			return attr
		end
		current = current.Parent
	end

	current = part
	while current do
		local lower = string.lower(current.Name)
		if string.find(lower, "thrust_color", 1, true) then return "ThrustColor" end
		if string.find(lower, "primary", 1, true) then return "Primary" end
		if string.find(lower, "secondary", 1, true) then return "Secondary" end
		if string.find(lower, "detail", 1, true) then return "Detail" end
		if string.find(lower, "neon", 1, true) then return "Neon" end
		current = current.Parent
	end

	return nil
end

function PaintClient.IsChannelMatch(part, channel)
	return PaintClient.ResolvePaintChannel(part) == channel
end

function PaintClient.PathHas(object, text)
	text = string.lower(text)
	local current = object
	while current do
		if string.find(string.lower(current.Name), text, 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

function PaintClient.ModuleColors(profile, slotId)
	profile = profile or {}
	local cockpitColors = profile.CockpitColors or {}
	local moduleSet = profile.ModuleColors and profile.ModuleColors[slotId] or {}
	return {
		Primary = moduleSet.Primary or cockpitColors.Primary or Color3.fromRGB(18, 202, 224),
		Secondary = moduleSet.Secondary or cockpitColors.Secondary or Color3.fromRGB(252, 250, 255),
		Detail = moduleSet.Detail or cockpitColors.Detail or Color3.fromRGB(38, 47, 55),
		Neon = moduleSet.Neon or Color3.fromRGB(255, 255, 255),
		ThrustColor = profile.ThrustColor or moduleSet.ThrustColor or Color3.fromRGB(255, 255, 255),
	}
end

function PaintClient.ApplyColors(model, colors, neonVisible, options)
	colors = colors or {}
	options = options or {}

	local profile = options.Profile or {}
	local frontLight = colors.FrontLights or Color3.fromRGB(252, 250, 255)
	local rearLight = colors.RearLights or Color3.fromRGB(255, 116, 116)
	local neonColor = colors.Neon or Color3.fromRGB(255, 255, 255)
	local thrustColor = colors.ThrustColor or profile.ThrustColor or Color3.fromRGB(255, 255, 255)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part:GetAttribute("TemplateRole") == "FixedSlotMount" then
				part.Transparency = 1
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			elseif PaintClient.IsChannelMatch(part, "ThrustColor") then
				part.Color = thrustColor
				part.Material = Enum.Material.Neon
				part.Transparency = 0
			elseif PaintClient.IsChannelMatch(part, "Neon") then
				local lightColor = neonColor
				if PaintClient.PathHas(part, "cockpit") then
					if PaintClient.PathHas(part, "front") then
						lightColor = frontLight
					elseif PaintClient.PathHas(part, "rear") or PaintClient.PathHas(part, "back") then
						lightColor = rearLight
					end
				end
				part.Color = lightColor
				part.Material = Enum.Material.Neon
				part.Transparency = neonVisible and 0 or 1
			elseif PaintClient.IsChannelMatch(part, "Primary") then
				part.Color = colors.Primary or part.Color
			elseif PaintClient.IsChannelMatch(part, "Secondary") then
				part.Color = colors.Secondary or part.Color
			elseif PaintClient.IsChannelMatch(part, "Detail") then
				part.Color = colors.Detail or part.Color
			end

			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
end

return PaintClient
]=]

local starterPlayerScripts = child(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local core = folder(controllers, "Core")

local modules = {
	ClientState = writeModule(core, "ClientState", clientStateSource),
	GarageApiClient = writeModule(core, "GarageApiClient", garageApiClientSource),
	CatalogClient = writeModule(core, "CatalogClient", catalogClientSource),
	ClientThemeAdapter = writeModule(core, "ClientThemeAdapter", themeAdapterSource),
	PaintClient = writeModule(core, "PaintClient", paintClientSource),
}

local checks = {}
local function check(name, ok, detail)
	table.insert(checks, {
		Name = name,
		Ok = ok,
		Detail = detail or "",
	})
end

local okState, ClientState = pcall(require, modules.ClientState)
check("ClientState requires", okState and typeof(ClientState) == "table", tostring(ClientState))
if okState and typeof(ClientState) == "table" then
	local state = ClientState.Create()
	check("ClientState.Create default category", state.CategoryId == "bruiser", tostring(state.CategoryId))
	check("ClientState.ResetPreviewSelection exists", typeof(ClientState.ResetPreviewSelection) == "function", typeof(ClientState.ResetPreviewSelection))
end

local okApi, GarageApiClient = pcall(require, modules.GarageApiClient)
check("GarageApiClient requires", okApi and typeof(GarageApiClient) == "table", tostring(GarageApiClient))
check("GarageApiClient.new exists", okApi and typeof(GarageApiClient.new) == "function", okApi and typeof(GarageApiClient.new) or "missing")

local okCatalog, CatalogClient = pcall(require, modules.CatalogClient)
check("CatalogClient requires", okCatalog and typeof(CatalogClient) == "table", tostring(CatalogClient))
if okCatalog and okState and typeof(ClientState) == "table" then
	local state = ClientState.Create({
		Catalog = {
			Categories = {
				{
					CategoryId = "bruiser",
					Slots = {
						{ SlotId = "Engine2", Order = 2, ModuleType = "Engine" },
						{ SlotId = "Engine1", Order = 1, ModuleType = "Engine" },
					},
					Cockpits = {
						{ CockpitId = "bruiser_01", DisplayName = "Bruiser Origin" },
					},
					Modules = {
						Engine = {
							{ ModuleId = "engine_a", DisplayName = "Engine A" },
						},
					},
				},
			},
		},
	})
	local catalog = CatalogClient.new(state)
	local slots = catalog:SortedSlots()
	check("CatalogClient sorted slot order", slots[1] and slots[1].SlotId == "Engine1", slots[1] and slots[1].SlotId or "nil")
	check("CatalogClient slot display name", CatalogClient.SlotDisplayName("Engine2") == "Rear Engine", CatalogClient.SlotDisplayName("Engine2"))
end

local okTheme, ClientThemeAdapter = pcall(require, modules.ClientThemeAdapter)
check("ClientThemeAdapter requires", okTheme and typeof(ClientThemeAdapter) == "table", tostring(ClientThemeAdapter))
if okTheme and typeof(ClientThemeAdapter) == "table" then
	local theme = ClientThemeAdapter.Read(nil)
	check("ClientThemeAdapter default accent", typeof(theme.Accent) == "Color3", typeof(theme.Accent))
end

local okPaint, PaintClient = pcall(require, modules.PaintClient)
check("PaintClient requires", okPaint and typeof(PaintClient) == "table", tostring(PaintClient))
if okPaint and typeof(PaintClient) == "table" then
	check("PaintClient.ResolvePaintChannel exists", typeof(PaintClient.ResolvePaintChannel) == "function", typeof(PaintClient.ResolvePaintChannel))
	local colors = PaintClient.ModuleColors({ ThrustColor = Color3.fromRGB(255, 255, 255) }, "Engine1")
	check("PaintClient.ModuleColors thrust default", typeof(colors.ThrustColor) == "Color3", typeof(colors.ThrustColor))
end

local passCount = 0
for _, item in ipairs(checks) do
	if item.Ok then
		passCount += 1
	end
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")
local reportValue = reportsFolder:FindFirstChild("MainClientPhaseA_CoreBoundaryReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "MainClientPhaseA_CoreBoundaryReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "MainClientPhaseA_CoreBoundaryReport"
	reportValue.Parent = reportsFolder
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Main Client Extraction Phase A - Core Boundary Modules")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("This phase created core client boundary modules without changing live HOVER_RACING_V2_Client behaviour.")
line("")
line("## Modules")
line("")
for name, module in pairs(modules) do
	line("- " .. name .. ": `" .. module:GetFullName() .. "`")
end
line("")
line("## Checks")
line("")
for _, item in ipairs(checks) do
	line("- " .. (item.Ok and "PASS" or "FAIL") .. ": " .. item.Name .. (item.Detail ~= "" and (" - " .. item.Detail) or ""))
end
line("")
line("## Summary")
line("")
line("- Passed checks: " .. tostring(passCount) .. " / " .. tostring(#checks))
line("- Live client edited: false")
line("- Live behaviour changed: false")
line("- Ready for Phase B only if all checks pass and normal Play testing still works.")

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("PassedChecks", passCount)
reportValue:SetAttribute("TotalChecks", #checks)
reportValue:SetAttribute("LiveClientEdited", false)

log("Created Phase A core modules under " .. core:GetFullName())
log("Checks passed: " .. tostring(passCount) .. " / " .. tostring(#checks))
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
