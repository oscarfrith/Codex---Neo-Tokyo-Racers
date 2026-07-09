-- Neo Tokyo Racers - RaceConfigReader
-- NTR_RACING_PHASE3_CONFIG_READER

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RouteDefinition = require(script.Parent:WaitForChild("RaceRouteDefinition"))

local Reader = {}

local function kit()
	return ReplicatedStorage:WaitForChild("NeoTokyoRacers")
end

local function racingConfig()
	return kit():WaitForChild("Config"):WaitForChild("Racing")
end

local function stringAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "string" and value or fallback
end

local function numberAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

local function findInCatalog(catalogName, eventId)
	local catalog = racingConfig():FindFirstChild(catalogName)
	local event = catalog and catalog:FindFirstChild(tostring(eventId or ""))
	if not event then
		for _, candidate in ipairs(catalog and catalog:GetChildren() or {}) do
			if stringAttribute(candidate, "EventId", "") == tostring(eventId or "") then
				event = candidate
				break
			end
		end
	end
	return event
end

function Reader.GetTimeTrialEvent(eventId)
	local event = findInCatalog("TimeTrialCatalog", eventId)
	if not event then
		return nil, "Time trial event not found: " .. tostring(eventId)
	end
	return event
end

function Reader.GetRaceEvent(eventId)
	local event = findInCatalog("RaceCatalog", eventId)
	if not event then
		return nil, "Race event not found: " .. tostring(eventId)
	end
	return event
end

function Reader.GetEvent(mode, eventId)
	if tostring(mode or "TimeTrial") == "Race" then
		return Reader.GetRaceEvent(eventId)
	end
	return Reader.GetTimeTrialEvent(eventId)
end

function Reader.GetRouteForEvent(eventId, mode)
	local event, eventError = Reader.GetEvent(mode or "TimeTrial", eventId)
	if not event then
		return nil, eventError
	end
	local routeId = stringAttribute(event, "RouteId", "")
	if routeId == "" then
		return nil, "Event has no RouteId: " .. tostring(eventId)
	end
	return RouteDefinition.GetRouteDefinition(routeId)
end

-- NTR_RACING_PHASE9A_CONFIG_READER
function Reader.GetEventSummary(eventId, mode)
	local event, eventError = Reader.GetEvent(mode or "TimeTrial", eventId)
	if not event then
		return nil, eventError
	end
	local routeId = stringAttribute(event, "RouteId", "")
	local route = routeId ~= "" and RouteDefinition.GetRouteDefinition(routeId) or nil
	local media = route and route.Media or {}
	local defaultLapCount = numberAttribute(event, "DefaultLapCount", numberAttribute(event, "Laps", 1))
	local minLapCount = numberAttribute(event, "MinLapCount", 1)
	local maxLapCount = numberAttribute(event, "MaxLapCount", 10)
	if maxLapCount < minLapCount then
		maxLapCount = minLapCount
	end
	return {
		EventId = stringAttribute(event, "EventId", tostring(eventId)),
		DisplayName = stringAttribute(event, "DisplayName", event.Name),
		Mode = stringAttribute(event, "Mode", mode or "TimeTrial"),
		RouteId = routeId,
		RouteDisplayName = route and route.DisplayName or routeId,
		RouteType = route and route.RouteType or stringAttribute(event, "RouteType", "Circuit"),
		AllowedVehicleTiers = stringAttribute(event, "AllowedVehicleTiers", "E,D,C,B,A,S"),
		RecommendedTier = stringAttribute(event, "RecommendedTier", "D"),
		BaseReward = numberAttribute(event, "BaseReward", 0),
		Laps = defaultLapCount,
		DefaultLapCount = defaultLapCount,
		MinLapCount = minLapCount,
		MaxLapCount = maxLapCount,
		AllowInfiniteLaps = event:GetAttribute("AllowInfiniteLaps") ~= false,
		MinPlayers = numberAttribute(event, "MinPlayers", 1),
		MaxPlayers = numberAttribute(event, "MaxPlayers", 1),
		TrackImage = stringAttribute(event, "TrackImage", media.TrackImage or ""),
		MapImage = stringAttribute(event, "MapImage", media.MapImage or ""),
		CheckpointCount = route and route.ValidationSummary.CheckpointCount or 0,
		GateCount = route and RouteDefinition.GetGateCount(route) or 0,
		ArrowCount = route and #(route.ArrowMarkers or {}) or 0,
	}
end


function Reader.GetTimeTrialMedals(eventId, tier)
	local event = Reader.GetTimeTrialEvent(eventId)
	if not event then
		return {}
	end
	tier = string.upper(tostring(tier or "D"))
	return {
		Bronze = numberAttribute(event, tier .. "_BronzeSeconds", numberAttribute(event, "BronzeSeconds", 0)),
		Silver = numberAttribute(event, tier .. "_SilverSeconds", numberAttribute(event, "SilverSeconds", 0)),
		Gold = numberAttribute(event, tier .. "_GoldSeconds", numberAttribute(event, "GoldSeconds", 0)),
		Platinum = numberAttribute(event, tier .. "_PlatinumSeconds", numberAttribute(event, "PlatinumSeconds", 0)),
	}
end

return Reader
