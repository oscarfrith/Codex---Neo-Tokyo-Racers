-- Neo Tokyo Racers customisation screen controller.
-- Phase C module. Builds customisation target/action data without switching live UI.

local CustomisationUIController = {}

local controllersFolder = script.Parent.Parent
local coreFolder = controllersFolder:WaitForChild("Core")
local uiFolder = controllersFolder:WaitForChild("UI")
local CatalogClient = require(coreFolder:WaitForChild("CatalogClient"))
local ColourPickerController = require(uiFolder:WaitForChild("ColourPickerController"))

CustomisationUIController.Stage = "Customise"

local INVISIBLE_UPGRADES = {
	{ TargetId = "Brakes", DisplayName = "Brakes" },
	{ TargetId = "Converter", DisplayName = "Converter" },
	{ TargetId = "FuelSystem", DisplayName = "Fuel System" },
}

function CustomisationUIController.BuildTargets(state)
	local catalog = CatalogClient.new(state)
	local targets = {
		{ TargetId = "ALL", DisplayName = "Customise All", Kind = "All" },
		{ TargetId = "Cockpit", DisplayName = "Cockpit", Kind = "Cockpit" },
		{ TargetId = "THRUST_COLOR", DisplayName = "Thrust Color", Kind = "ThrustColor" },
	}

	for _, slot in ipairs(catalog:SortedSlots()) do
		if state.Profile and state.Profile.InstalledModules and state.Profile.InstalledModules[slot.SlotId] then
			table.insert(targets, {
				TargetId = slot.SlotId,
				DisplayName = CatalogClient.SlotDisplayName(slot.SlotId),
				Kind = "Module",
				ModuleId = state.Profile.InstalledModules[slot.SlotId],
			})
		end
	end

	for _, upgrade in ipairs(INVISIBLE_UPGRADES) do
		table.insert(targets, upgrade)
	end

	for _, target in ipairs(targets) do
		target.Selected = state.CustomizeTarget == target.TargetId
	end

	return targets
end

function CustomisationUIController.ChannelsForTarget(state, detectedChannels)
	if state.CustomizeTarget == "THRUST_COLOR" then
		return { "ThrustColor" }
	end
	if state.CustomizeTarget == "Cockpit" then
		return { "Primary", "Secondary", "Detail", "FrontLights", "RearLights" }
	end
	if state.CustomizeTarget == "ALL" then
		return { "Primary", "Secondary", "Detail", "Neon" }
	end
	return detectedChannels or { "Primary", "Secondary", "Detail", "Neon" }
end

function CustomisationUIController.BuildActions(state, selectedTarget)
	if selectedTarget == "THRUST_COLOR" then
		return {
			{ ActionId = "Colour", DisplayName = "COLOUR", Tone = "Grey" },
		}
	end
	if selectedTarget == "Cockpit" or selectedTarget == "ALL" then
		return {
			{ ActionId = "Colour", DisplayName = "COLOUR", Tone = "Grey" },
		}
	end
	return {
		{ ActionId = "Colour", DisplayName = "COLOUR", Tone = "Grey" },
		{ ActionId = "Cosmetics", DisplayName = "COSMETICS", Tone = "Grey" },
		{ ActionId = "Upgrade", DisplayName = "UPGRADE", Tone = "Green" },
	}
end

function CustomisationUIController.ApplyLocalColor(state, channel, color)
	if state.CustomizeTarget == "THRUST_COLOR" or channel == "ThrustColor" then
		if not state.Profile then state.Profile = {} end
		state.Profile.ThrustColor = color
		ColourPickerController.SyncStateFromColor(state, color)
		return
	end

	if state.CustomizeTarget == "Cockpit" or state.CustomizeTarget == "ALL" then
		if not state.Profile then state.Profile = {} end
		if not state.Profile.CockpitColors then state.Profile.CockpitColors = {} end
		state.Profile.CockpitColors[channel] = color
	else
		if not state.Profile then state.Profile = {} end
		if not state.Profile.ModuleColors then state.Profile.ModuleColors = {} end
		state.Profile.ModuleColors[state.CustomizeTarget] = state.Profile.ModuleColors[state.CustomizeTarget] or {}
		state.Profile.ModuleColors[state.CustomizeTarget][channel] = color
	end
	ColourPickerController.SyncStateFromColor(state, color)
end

function CustomisationUIController.BuildViewModel(state)
	local selectedTarget = state.CustomizeTarget or "ALL"
	return {
		Stage = CustomisationUIController.Stage,
		Title = "Customise",
		Subtitle = "Upgrade performance, change module colours, or unlock lights.",
		SelectedTarget = selectedTarget,
		Mode = state.CustomizeMode or "Overview",
		Targets = CustomisationUIController.BuildTargets(state),
		Actions = CustomisationUIController.BuildActions(state, selectedTarget),
		Channels = CustomisationUIController.ChannelsForTarget(state),
		Cash = state.Profile and state.Profile.Cash or 0,
		NextText = "START DRIVING",
	}
end

function CustomisationUIController.Render(context)
	local viewModel = CustomisationUIController.BuildViewModel(context.State)
	if context.Renderers and context.Renderers.Customisation then
		return context.Renderers.Customisation(viewModel, context)
	end
	return viewModel
end

return CustomisationUIController
