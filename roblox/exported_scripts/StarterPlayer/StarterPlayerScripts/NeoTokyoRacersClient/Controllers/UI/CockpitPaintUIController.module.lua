-- Neo Tokyo Racers cockpit paint screen controller.
-- Phase C module. Coordinates cockpit colour channels and staged colour picker calls.

local CockpitPaintUIController = {}

local controllersFolder = script.Parent.Parent
local uiFolder = controllersFolder:WaitForChild("UI")
local ColourPickerController = require(uiFolder:WaitForChild("ColourPickerController"))

CockpitPaintUIController.Stage = "CockpitPaint"
CockpitPaintUIController.DefaultChannels = { "Primary", "Secondary", "Detail" }

function CockpitPaintUIController.BuildViewModel(state)
	local cockpitColors = (state.Profile and state.Profile.CockpitColors) or {}
	return {
		Stage = CockpitPaintUIController.Stage,
		Title = "Paint Cockpit",
		Subtitle = "Choose primary, secondary, and detail colours.",
		Channels = CockpitPaintUIController.DefaultChannels,
		SelectedChannel = state.ColorChannel or "Primary",
		CurrentColor = cockpitColors[state.ColorChannel or "Primary"] or Color3.fromRGB(255, 255, 255),
		Cash = state.Profile and state.Profile.Cash or 0,
	}
end

function CockpitPaintUIController.ApplyLocalColor(state, channel, color)
	if not state.Profile then
		state.Profile = {}
	end
	if not state.Profile.CockpitColors then
		state.Profile.CockpitColors = {}
	end
	state.Profile.CockpitColors[channel] = color
	ColourPickerController.SyncStateFromColor(state, color)
end

function CockpitPaintUIController.Render(context)
	local viewModel = CockpitPaintUIController.BuildViewModel(context.State)
	if context.Renderers and context.Renderers.CockpitPaint then
		return context.Renderers.CockpitPaint(viewModel, context)
	end
	return viewModel
end

return CockpitPaintUIController
