-- Neo Tokyo Racers stats panel controller.
-- Phase C module. Builds stat bar data and preview deltas for future UI screens.

local StatsPanelController = {}

StatsPanelController.StatOrder = {
	"TopSpeed",
	"Acceleration",
	"Handling",
	"Drift",
	"Braking",
	"Weight",
	"Boost",
}

function StatsPanelController.Normalise(stat, value)
	local divisor = stat == "Weight" and 180 or 180
	return math.clamp((value or 0) / divisor, 0, 1)
end

function StatsPanelController.BuildRows(stats, baseStats)
	stats = stats or {}
	baseStats = baseStats or stats
	local rows = {}
	for _, stat in ipairs(StatsPanelController.StatOrder) do
		local value = stats[stat] or 0
		local baseValue = baseStats[stat] or value
		local amount = StatsPanelController.Normalise(stat, value)
		local baseAmount = StatsPanelController.Normalise(stat, baseValue)
		table.insert(rows, {
			Stat = stat,
			Value = value,
			BaseValue = baseValue,
			Amount = amount,
			BaseAmount = baseAmount,
			Delta = value - baseValue,
			DeltaTone = value > baseValue and "Positive" or (value < baseValue and "Negative" or "None"),
		})
	end
	return rows
end

function StatsPanelController.BuildViewModel(stats, baseStats)
	return {
		Title = "Vehicle Stats",
		Rows = StatsPanelController.BuildRows(stats, baseStats),
	}
end

return StatsPanelController
