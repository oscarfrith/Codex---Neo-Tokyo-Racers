-- Owns the gallery fixtures for Kit.BigNumber; it does not own the gallery, any screen or any game data.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.BigNumber. Requires: BigNumber.
local BigNumber = require(script.Parent.Parent.Parent.Kit.BigNumber)

local function mount(parent, props, scope, _ctx)
	return BigNumber.New(parent, props, scope)
end

-- Example values only. One state per role, plus the punctuation, alignment and layout variants.
local numberItem = {
	Id = "BigNumber.New",
	Frame = "Bare",
	Slot = nil,
	Mount = mount,
	States = {
		{ Id = "Speed", Props = { Text = "142", Role = "Speed", MaxCells = 3, Align = "Centre" } },
		{ Id = "SpeedOneDigit", Props = { Text = "7", Role = "Speed", MaxCells = 3, Align = "Centre" } },
		{ Id = "SpeedZero", Props = { Text = "0", Role = "Speed", MaxCells = 3, Align = "Right" } },
		{ Id = "SpeedWidest", Props = { Text = "444", Role = "Speed", MaxCells = 3, Align = "Centre" } },
		{ Id = "HeroCash", Props = { Text = "$20,000", Role = "Hero", Colour = "Yellow", MaxCells = 10, Align = "Centre", Fixed = false } },
		{ Id = "HeroCashLongest", Props = { Text = "$3,613,709", Role = "Hero", Colour = "Yellow", MaxCells = 10, Align = "Centre", Fixed = false } },
		{ Id = "HeroXp", Props = { Text = "+120", Role = "Hero", Colour = "Pink", MaxCells = 6, Align = "Centre", Fixed = false } },
		{ Id = "HeroXpUnit", Props = { Text = "+120 XP", Role = "Hero", Colour = "Pink", MaxCells = 6, Align = "Left", Fixed = false } },
		{ Id = "Position", Props = { Text = "2/6", Role = "Position", MaxCells = 4, Align = "Left" } },
		{ Id = "PositionTwoDigits", Props = { Text = "12/12", Role = "Position", MaxCells = 5, Align = "Left" } },
		{ Id = "Timer", Props = { Text = "03:11.842", Role = "Timer", MaxCells = 9, Align = "Centre" } },
		{ Id = "TimerTight", Props = { Text = "03:11.842", Role = "Timer", MaxCells = 9, Align = "Centre", Tight = true } },
		{ Id = "TimerDelta", Props = { Text = "-1.8", Role = "Timer", Colour = "Cyan", MaxCells = 6, Align = "Right" } },
		{ Id = "Countdown", Props = { Text = "3", Role = "Countdown", MaxCells = 1, Align = "Centre" } },
		{ Id = "Rank", Props = { Text = "6", Role = "Rank", MaxCells = 3, Align = "Left" } },
		{ Id = "RankLongest", Props = { Text = "100", Role = "Rank", MaxCells = 3, Align = "Left" } },
		{ Id = "Small", Props = { Text = "64%", Role = "Small", Colour = "Cyan", MaxCells = 4, Align = "Left" } },
		{ Id = "SmallMultiplier", Props = { Text = "x2.5", Role = "Small", MaxCells = 4, Align = "Left", Fixed = false } },
		{ Id = "SmallShortForm", Props = { Text = "$1.4M", Role = "Small", Colour = "Yellow", MaxCells = 6, Align = "Left", Fixed = false } },
		{ Id = "UnitMph", Props = { Text = "231 MPH", Role = "Small", MaxCells = 5, Align = "Left" } },
		{ Id = "UnitKmh", Props = { Text = "372 KM/H", Role = "Small", MaxCells = 5, Align = "Left" } },
		{ Id = "Empty", Props = { Text = "", Role = "Speed", MaxCells = 3, Align = "Centre" } },
	},
}

return { numberItem }
