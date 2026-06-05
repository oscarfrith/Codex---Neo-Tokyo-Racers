-- Neo Tokyo Racers garage navigation controller.
-- Phase C module. Encodes next/back stage routing without switching live UI.

local NavigationController = {}

NavigationController.StageOrder = {
	CockpitShop = "CockpitPaint",
	CockpitPaint = "ModuleShop",
	ModuleShop = "Customise",
	Customise = "SpawnVehicle",
}

NavigationController.BackOrder = {
	CockpitPaint = "CockpitShop",
	ModuleShop = "CockpitPaint",
	Customise = "ModuleShop",
}

NavigationController.NextLabels = {
	CockpitShop = "SELECT",
	CockpitPaint = "NEXT",
	ModuleShop = "CUSTOMISE MODULES",
	Customise = "START DRIVING",
}

function NavigationController.NextStage(stage)
	return NavigationController.StageOrder[stage]
end

function NavigationController.BackStage(stage)
	return NavigationController.BackOrder[stage]
end

function NavigationController.NextLabel(stage)
	return NavigationController.NextLabels[stage] or "NEXT"
end

function NavigationController.BuildViewModel(state)
	return {
		Stage = state.Stage,
		NextTarget = NavigationController.NextStage(state.Stage),
		BackTarget = NavigationController.BackStage(state.Stage),
		NextText = NavigationController.NextLabel(state.Stage),
		BackVisible = NavigationController.BackStage(state.Stage) ~= nil,
	}
end

return NavigationController
