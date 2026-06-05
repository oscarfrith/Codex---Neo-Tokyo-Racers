-- Neo Tokyo Racers Config Registry
-- Added by Phase 3 config migration.
--
-- Current live scripts still read the legacy HOVER_RACING_V2 config paths.
-- This registry documents the live authoritative config and generated mirror locations.

local ConfigRegistry = {}

ConfigRegistry.Version = "Phase3_2026_05_28"
ConfigRegistry.LiveLegacyConfigStillAuthoritative = true

ConfigRegistry.Configs = {
	DrivingMechanics = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_MECHANICS_EditAttributes",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving.DrivingMechanics_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving",
		description = "Primary editable driving attributes.",
	},
	HoverWobble = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.HOVER_WOBBLE_EditAttributes",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving.HoverWobble_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Driving",
		description = "Low-speed hover wobble tuning.",
	},
	DrivingCameraAssist = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG.DRIVING_CAMERA_ASSIST_EditAttributes",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Camera.DrivingCameraAssist_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Camera",
		description = "Camera FOV, height, distance, acceleration/boost camera feel.",
	},
	UITheme = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI.UITheme_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI",
		description = "Current UI theme values.",
	},
	PaintPresets = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI.PaintPresets_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI",
		description = "Default colour swatches / paint presets.",
	},
	GameBalance = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.01_GAME_BALANCE_Editable",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Economy.GameBalance_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Economy",
		description = "Economy, module prices, and broad gameplay balance values.",
	},
	DriverSeatPosition = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.DRIVER_SEAT_POSITION_DoNotRename",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Vehicles.DriverSeatPosition_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.Vehicles",
		description = "Driver seat/cockpit position tuning.",
	},
	StabiliserVFXDirection = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST.STABILISER_VFX_DIRECTION_DoNotRename",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.VFX.StabiliserVFXDirection_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.VFX",
		description = "Left/right stabiliser VFX direction markers.",
	},
	LightingPresets = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.Shared.LightingPresets",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting.LightingPresets_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting",
		description = "Day/night lighting preset modules.",
	},
	SkyPresets = {
		status = "LiveLegacyAuthoritative",
		livePath = "ReplicatedStorage.Shared.SkyPresets",
		mirrorPath = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting.SkyPresets_Mirror",
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting",
		description = "Skybox preset storage.",
	},
	FarLOD5 = {
		status = "LiveLegacyAuthoritativeReferenceOnly",
		livePath = "ReplicatedStorage.FarLOD5",
		mirrorPath = nil,
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.LOD",
		description = "FarLOD5 asset root. Referenced only, not mirrored.",
	},
	GeneratedCityBlocks = {
		status = "LiveLegacyAuthoritativeReferenceOnly",
		livePath = "Workspace.GeneratedCityBlocks",
		mirrorPath = nil,
		targetFolder = "ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.LOD",
		description = "Generated city block root. Referenced only, not mirrored.",
	},
}

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = game:GetService("StarterPlayer"),
	StarterGui = game:GetService("StarterGui"),
	Workspace = game:GetService("Workspace"),
	Lighting = game:GetService("Lighting"),
	ServerStorage = game:GetService("ServerStorage"),
}

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

local function resolvePath(path)
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local parts = splitPath(path)
	local current = services[parts[1]]
	if not current then
		return nil
	end

	for index = 2, #parts do
		current = current:FindFirstChild(parts[index])
		if not current then
			return nil
		end
	end

	return current
end

function ConfigRegistry.Get(configKey)
	return ConfigRegistry.Configs[configKey]
end

function ConfigRegistry.List()
	local keys = {}
	for key in pairs(ConfigRegistry.Configs) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function ConfigRegistry.ResolveLive(configKey)
	local config = ConfigRegistry.Configs[configKey]
	if not config then
		return nil
	end
	return resolvePath(config.livePath)
end

function ConfigRegistry.ResolveMirror(configKey)
	local config = ConfigRegistry.Configs[configKey]
	if not config or not config.mirrorPath then
		return nil
	end
	return resolvePath(config.mirrorPath)
end

function ConfigRegistry.ResolveTargetFolder(configKey)
	local config = ConfigRegistry.Configs[configKey]
	if not config then
		return nil
	end
	return resolvePath(config.targetFolder)
end

return ConfigRegistry
