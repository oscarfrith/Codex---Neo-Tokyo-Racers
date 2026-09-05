-- Edit this ordered table to change stage order, relative duration, or visual flags.
-- BaseDurationSeconds lives on the parent LightingCycleConfig Folder.
return {
	{Preset = "SevenAM",    DisplayName = "7 AM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "TenAM",      DisplayName = "10 AM",  DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "Day",        DisplayName = "Day",    DurationWeight = 2, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "ThreePM",    DisplayName = "3 PM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "FivePM",     DisplayName = "5 PM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "EightPM",    DisplayName = "8 PM",   DurationWeight = 1, StreetLightsOn = true,  WindowMode = "Night"},
	{Preset = "ClearNight", DisplayName = "Night",  DurationWeight = 2, StreetLightsOn = true,  WindowMode = "Night"},
	{Preset = "FourAM",     DisplayName = "4 AM",   DurationWeight = 1, StreetLightsOn = true,  WindowMode = "Night"},
}
