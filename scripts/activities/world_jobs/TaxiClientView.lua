-- Canonical feature implementation; mounted by ActivityClient (no startup of its own).
-- World taxi fares client view (map-markers-contract "World jobs"). Registers the Taxi kind with the
-- shared JobClient (offer markers, "Give ride" prompt, strip, route, TaxiDrop marker, JOBS entry) and
-- forwards Taxi:* events to it. Presentation only; the fare NPCs are server rigs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local activities = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Activities")
local JobClient = require(activities:WaitForChild("JobClient"))
local JobRules = require(activities:WaitForChild("JobRules"))

local KIND = "Taxi"
local View = {}

function View.Mount(ctx)
	JobClient.Mount(ctx)
	JobClient.RegisterKind({
		Kind = KIND,
		Title = "TAXI FARE",
		Nearest = "NEAREST TAXI FARE",
		Icon = "TaxiFare",
		DropIcon = "TaxiDrop",
		ActionText = "Give ride",
		DropLabel = "DROP-OFF",
		StripTitle = "TAXI",
		BoardingText = "TAXI · YOUR FARE IS GETTING IN...",
		Colour = ctx.Theme.Telemetry,
		Order = 20,
		DoneTitle = "FARE COMPLETE",
		FailTitle = "FARE LOST: ",
		CancelTitle = "FARE CANCELLED: ",
		StartedText = function(payload)
			return "FARE ON BOARD · " .. JobRules.Miles(payload.Distance) .. " TRIP · FASTER PAYS MORE, CRASHES COST"
		end,
	})
end

function View.OnEvent(payload)
	if type(payload) ~= "table" or type(payload.Type) ~= "string" then return end
	if string.sub(payload.Type, 1, #KIND + 1) == KIND .. ":" then JobClient.OnEvent(KIND, payload) end
end

return View
