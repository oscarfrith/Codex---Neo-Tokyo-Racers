-- Canonical feature implementation; startup is owned by the composition root.
-- Analytics registry and sender. The registry below is the only list of events the game reports, so it
-- also serves as the allowlist if a client-originated event is ever added (through Core.Net).
--   Economy: sinks from Player.MoneyService.Debited, sources from EconomyCashCommitted (credits owner).
--   Onboarding: OnboardingServer calls Service.OnboardingStep only when a milestone is newly recorded.
-- All calls are pcall-guarded and gated by FeatureFlags "AnalyticsEnabled" (default on).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Service = {}
local state

Service.Events = {
	Onboarding = { FirstVehiclePurchased = 1, FirstVehicleDriven = 2, GarageManagementEntered = 3, FirstEventEntered = 4 },
	Currency = "Cash",
}

local FeatureFlagsCache
local function enabled()
	FeatureFlagsCache = FeatureFlagsCache or require(ServerStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("FeatureFlags"))
	return FeatureFlagsCache.IsEnabled("AnalyticsEnabled", true)
end
local function send(label, fn)
	if not enabled() then return end
	local sent, err = pcall(fn)
	if not sent then warn("[Analytics] " .. label .. " failed: " .. tostring(err)) end
end
local function livePlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

-- Called by OnboardingServer after RecordProgress reports a newly completed milestone.
function Service.OnboardingStep(player, progressId)
	local step = Service.Events.Onboarding[tostring(progressId)]
	if not (step and livePlayer(player)) then return end
	send("onboarding", function()
		game:GetService("AnalyticsService"):LogOnboardingFunnelStepEvent(player, step, tostring(progressId))
	end)
end

function Service.start()
	if state then assert(state == "ready", "Service already starting or failed"); return end
	state = "starting"
	local ok, message = xpcall(function()
		local AnalyticsService = game:GetService("AnalyticsService")
		local function wait(parent, name)
			return assert(parent:WaitForChild(name, 30), "[Analytics] missing " .. name)
		end
		local MoneyService = require(wait(wait(wait(wait(ServerStorage, "Modules"), "Game"), "Player"), "MoneyService"))
		local bindings = wait(wait(wait(ServerStorage, "Runtime"), "Player"), "ProfileServiceBindings")
		local committed = wait(bindings, "EconomyCashCommitted")
		local function sku(text) return string.sub(tostring(text or "Unknown"):gsub("[^%w_]", "_"), 1, 50) end

		MoneyService.Debited:Connect(function(profile, amount, reason, balance)
			local player = type(profile) == "table" and profile._Player
			if not livePlayer(player) or not (tonumber(amount) and amount > 0) then return end
			send("sink", function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, Service.Events.Currency,
					math.floor(amount), math.floor(balance), Enum.AnalyticsEconomyTransactionType.Shop.Name, sku(reason))
			end)
		end)

		committed.Event:Connect(function(player, newCash, details)
			if not livePlayer(player) or type(details) ~= "table" then return end
			local amount = math.floor(tonumber(details.Amount) or 0)
			if amount <= 0 then return end
			send("source", function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, Service.Events.Currency,
					amount, math.floor(tonumber(newCash) or 0), Enum.AnalyticsEconomyTransactionType.Gameplay.Name, sku(details.Reason))
			end)
		end)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return Service
