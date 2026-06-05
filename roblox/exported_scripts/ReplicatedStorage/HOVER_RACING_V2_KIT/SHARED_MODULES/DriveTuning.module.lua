local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("HOVER_RACING_V2_KIT")
local ConfigReader = require(kit:WaitForChild("SHARED_MODULES"):WaitForChild("ConfigReader"))

local DriveTuning = {}
DriveTuning.Folder = kit:WaitForChild("00_EDIT_ME_FIRST"):WaitForChild("01_GAME_BALANCE_Editable"):WaitForChild("Driving")

function DriveTuning.Read()
	local folder = DriveTuning.Folder
	return {
		HoverHeightStuds = ConfigReader.Number(folder, "HoverHeightStuds", 3, 0),
		TopSpeedMPH = ConfigReader.Number(folder, "TopSpeedMPH", 150, 1),
		ReverseLimitMPH = ConfigReader.Number(folder, "ReverseLimitMPH", 28, 0),
		AccelerationScale = ConfigReader.Number(folder, "AccelerationScale", 3.1, 0),
		BrakingScale = ConfigReader.Number(folder, "BrakingScale", 1.1, 0),
		BoostDurationSeconds = ConfigReader.Number(folder, "BoostDurationSeconds", 2, 0),
		BoostRechargeSeconds = ConfigReader.Number(folder, "BoostRechargeSeconds", 9, 0),
		BankingDegrees = ConfigReader.Number(folder, "BankingDegrees", 6, 0),
		GroundSensorLengthStuds = ConfigReader.Number(folder, "GroundSensorLengthStuds", 16, 1),
	}
end

return DriveTuning
