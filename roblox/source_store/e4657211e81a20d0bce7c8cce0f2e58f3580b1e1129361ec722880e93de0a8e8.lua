-- Canonical feature implementation; startup is owned by the composition root (ServerBase).
-- World courier jobs (map-markers-contract "World jobs"). One standard job: a parcel waits at a kerb
-- pickup (the parcel crate is a client visual; the server holds the offer), the driver pulls up slowly and
-- picks it up, then delivers it to a far kerb drop. Faster pays more, crashes pay less. No variants, hubs
-- or chains. Registers the "Courier" activity kind and the Courier provider with JobBoard, which owns
-- offers, JobAccept, the trip engine and the payout (ActivityPayout.Pay, Reason JobPayout).
local ServerStorage = game:GetService("ServerStorage")

local CourierJob = {}

local KIND = "Courier"
local state = "idle"
local ActivityService, JobBoard, CourierRules, FeatureFlags
local parcelCounter = 0

local function config()
	local folder = ActivityService.Config(KIND)
	return CourierRules.ReadConfig(function(key) return folder and folder:GetAttribute(key) end)
end

local provider = {
	Reason = "JobPayout", -- replaced by CourierRules.REASON at start
	PayLabel = "Courier delivery",
	Boards = false,
}

function provider.ReadConfig()
	return config()
end

function provider.Enabled()
	local folder = ActivityService.Config(KIND)
	return FeatureFlags.IsEnabled("EnableCourier", true) and folder ~= nil and folder:GetAttribute("Enabled") ~= false
end

function provider.DecorateOffer(offer)
	parcelCounter += 1
	offer.Label = CourierRules.ParcelName(Random.new():NextInteger(1, 1000) + parcelCounter)
end

-- The parcel is loaded the moment the pickup is accepted.
function provider.OnAccept(_player, trip)
	JobBoard.StartDriving(trip)
end

function CourierJob.start()
	if state ~= "idle" then return end
	state = "starting"
	local ok, message = xpcall(function()
		local modules = ServerStorage:WaitForChild("Modules")
		local activities = modules:WaitForChild("Game"):WaitForChild("Activities")
		ActivityService = require(activities:WaitForChild("ActivityService"))
		JobBoard = require(activities:WaitForChild("JobBoard"))
		CourierRules = require(activities:WaitForChild("CourierRules"))
		FeatureFlags = require(modules:WaitForChild("Core"):WaitForChild("FeatureFlags"))
		provider.Reason = CourierRules.REASON

		ActivityService.Register(KIND, {
			Actions = {},
			OnCancel = function(player, record, reason) JobBoard.HandleCancel(player, record, reason) end,
			RequiresVehicle = true,
		})
		JobBoard.RegisterProvider(KIND, provider)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return CourierJob
