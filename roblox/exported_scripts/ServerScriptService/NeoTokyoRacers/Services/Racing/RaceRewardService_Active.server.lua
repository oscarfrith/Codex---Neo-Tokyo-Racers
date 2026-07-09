-- Neo Tokyo Racers - Racing Phase 11A Reward Service
-- NTR_RACING_PHASE11A_REWARD_SERVICE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "NTR Racing Phase 11A Rewards"
local MEDAL_RANK = {
	Finished = 0,
	Bronze = 1,
	Silver = 2,
	Gold = 3,
	Platinum = 4,
}

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingConfig = kit:WaitForChild("Config"):WaitForChild("Racing")
local rewardsRoot = racingConfig:WaitForChild("Rewards")
local timeTrialRewards = rewardsRoot:WaitForChild("TimeTrial")
local raceRewards = rewardsRoot:WaitForChild("Race")

local racingRoot = script.Parent
local bindings = racingRoot:FindFirstChild("RaceRewardBindings") or Instance.new("Folder")
bindings.Name = "RaceRewardBindings"
bindings.Parent = racingRoot

local timeTrialGrantBinding = bindings:FindFirstChild("GrantTimeTrialReward") or Instance.new("BindableFunction")
timeTrialGrantBinding.Name = "GrantTimeTrialReward"
timeTrialGrantBinding.Parent = bindings

local raceGrantBinding = bindings:FindFirstChild("GrantRaceReward") or Instance.new("BindableFunction")
raceGrantBinding.Name = "GrantRaceReward"
raceGrantBinding.Parent = bindings

local claimedRunIds = {}

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function numberAttr(folder, name, fallback)
	local value = tonumber(folder and folder:GetAttribute(name))
	if value == nil then return fallback end
	return value
end

local function boolAttr(folder, name, fallback)
	local value = folder and folder:GetAttribute(name)
	if value == nil then return fallback end
	return value == true
end

local function roundCash(amount, quantum)
	amount = tonumber(amount) or 0
	quantum = tonumber(quantum) or 0
	if quantum <= 0 then
		return math.floor(amount + 0.5)
	end
	return math.floor((amount / quantum) + 0.5) * quantum
end

local function medalRank(medal)
	return MEDAL_RANK[tostring(medal or "Finished")] or 0
end

local function catalogEvent(catalogName, eventId)
	local catalog = racingConfig:FindFirstChild(catalogName)
	local direct = catalog and catalog:FindFirstChild(tostring(eventId or ""))
	if direct then return direct end
	for _, candidate in ipairs(catalog and catalog:GetChildren() or {}) do
		if tostring(candidate:GetAttribute("EventId") or "") == tostring(eventId or "") then
			return candidate
		end
	end
	return nil
end

local function timeTrialEventFolder(eventId)
	return catalogEvent("TimeTrialCatalog", eventId)
end

local function raceEventFolder(eventId)
	return catalogEvent("RaceCatalog", eventId)
end

local function eventNumber(folder, name, fallback)
	local value = folder and tonumber(folder:GetAttribute(name))
	if value == nil then return fallback end
	return value
end

local function medalMultiplier(medal)
	local name = tostring(medal or "Finished")
	if name == "Platinum" then return numberAttr(timeTrialRewards, "PlatinumRewardMultiplier", 1.3) end
	if name == "Gold" then return numberAttr(timeTrialRewards, "GoldRewardMultiplier", 1.0) end
	if name == "Silver" then return numberAttr(timeTrialRewards, "SilverRewardMultiplier", 0.75) end
	if name == "Bronze" then return numberAttr(timeTrialRewards, "BronzeRewardMultiplier", 0.55) end
	return numberAttr(timeTrialRewards, "FinishedRewardMultiplier", 0)
end

local function tierMultiplier(tier)
	tier = string.upper(tostring(tier or "E"))
	return numberAttr(timeTrialRewards, "TierMultiplier_" .. tier, 1)
end

local function raceMedalForPlace(place)
	place = tonumber(place) or 0
	if place > 0 and place <= numberAttr(raceRewards, "GoldPlaceMax", 1) then return "Gold" end
	if place > 0 and place <= numberAttr(raceRewards, "SilverPlaceMax", 2) then return "Silver" end
	if place > 0 and place <= numberAttr(raceRewards, "BronzePlaceMax", 3) then return "Bronze" end
	return "Finished"
end

local function racePlacementMultiplier(medal)
	local name = tostring(medal or "Finished")
	if name == "Gold" then return numberAttr(raceRewards, "GoldRewardMultiplier", 1.0) end
	if name == "Silver" then return numberAttr(raceRewards, "SilverRewardMultiplier", 0.85) end
	if name == "Bronze" then return numberAttr(raceRewards, "BronzeRewardMultiplier", 0.65) end
	return numberAttr(raceRewards, "DNFRewardMultiplier", 0)
end

local function profileBindings()
	local playerServices = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Player")
	local bindingsFolder = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
	local getProfile = bindingsFolder and bindingsFolder:FindFirstChild("GetProfile")
	local importProfileSnapshot = bindingsFolder and bindingsFolder:FindFirstChild("ImportProfileSnapshot")
	if getProfile and getProfile:IsA("BindableFunction") and importProfileSnapshot and importProfileSnapshot:IsA("BindableFunction") then
		return {
			GetProfile = getProfile,
			ImportProfileSnapshot = importProfileSnapshot,
		}
	end
	return nil
end

local function profileFor(player)
	local bindingsData = profileBindings()
	if not bindingsData then return nil end
	local ok, profile = pcall(function()
		return bindingsData.GetProfile:Invoke(player)
	end)
	if ok and typeof(profile) == "table" then return profile end
	return nil
end

local function persistProfile(player, profile, reason)
	local bindingsData = profileBindings()
	if not bindingsData or typeof(profile) ~= "table" then return false end
	local ok, importOk = pcall(function()
		return bindingsData.ImportProfileSnapshot:Invoke(player, profile, tostring(reason or "RaceReward"), true)
	end)
	return ok and importOk == true
end

local function garageCashGrantBinding()
	local garage = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage")
	local bindingsFolder = garage and garage:FindFirstChild("GarageProfileMutationBindings")
	local grant = bindingsFolder and bindingsFolder:FindFirstChild("GrantCash")
	return grant and grant:IsA("BindableFunction") and grant or nil
end

local function bestBucket(profile, eventId, tier)
	profile.Racing = typeof(profile.Racing) == "table" and profile.Racing or {}
	profile.Racing.TimeTrialBest = typeof(profile.Racing.TimeTrialBest) == "table" and profile.Racing.TimeTrialBest or {}
	local eventKey = tostring(eventId or "")
	local tierKey = string.upper(tostring(tier or ""))
	profile.Racing.TimeTrialBest[eventKey] = typeof(profile.Racing.TimeTrialBest[eventKey]) == "table" and profile.Racing.TimeTrialBest[eventKey] or {}
	profile.Racing.TimeTrialBest[eventKey][tierKey] = typeof(profile.Racing.TimeTrialBest[eventKey][tierKey]) == "table" and profile.Racing.TimeTrialBest[eventKey][tierKey] or {}
	return profile.Racing.TimeTrialBest[eventKey][tierKey]
end

local function recordBest(player, eventId, tier, medal, elapsed, vehicleId)
	local profile = profileFor(player)
	if typeof(profile) ~= "table" then return nil end
	local bucket = bestBucket(profile, eventId, tier)
	if medalRank(medal) > medalRank(bucket.BestMedal) or bucket.BestSeconds == nil or elapsed < (tonumber(bucket.BestSeconds) or math.huge) then
		bucket.BestSeconds = elapsed
		bucket.BestMedal = medal
		bucket.BestVehicleId = tostring(vehicleId or "")
		bucket.BestVehicleTier = string.upper(tostring(tier or ""))
		bucket.UpdatedUnix = os.time()
		persistProfile(player, profile, "RaceRewardBest:" .. tostring(eventId or ""))
	end
	return bucket
end

local function recordRaceFinish(player, payload)
	local profile = profileFor(player)
	if typeof(profile) ~= "table" then return end
	profile.Racing = typeof(profile.Racing) == "table" and profile.Racing or {}
	profile.Racing.RaceFinishes = typeof(profile.Racing.RaceFinishes) == "table" and profile.Racing.RaceFinishes or {}
	local eventKey = tostring(payload.EventId or "")
	local bucket = typeof(profile.Racing.RaceFinishes[eventKey]) == "table" and profile.Racing.RaceFinishes[eventKey] or {}
	profile.Racing.RaceFinishes[eventKey] = bucket
	local place = tonumber(payload.Place) or 0
	local elapsed = tonumber(payload.Elapsed) or 0
	bucket.FinishCount = (tonumber(bucket.FinishCount) or 0) + 1
	if place > 0 and (bucket.BestPlace == nil or place < (tonumber(bucket.BestPlace) or math.huge)) then
		bucket.BestPlace = place
		bucket.BestPlaceElapsed = elapsed
	end
	if elapsed > 0 and (bucket.BestSeconds == nil or elapsed < (tonumber(bucket.BestSeconds) or math.huge)) then
		bucket.BestSeconds = elapsed
		bucket.BestSecondsPlace = place
	end
	bucket.LastPlace = place
	bucket.LastMedal = tostring(payload.Medal or "Finished")
	bucket.UpdatedUnix = os.time()
	persistProfile(player, profile, "RaceFinish:" .. eventKey)
end

local function calculateTimeTrialAmount(profile, payload)
	local eventId = tostring(payload.EventId or "")
	local tier = string.upper(tostring(payload.VehicleTier or "E"))
	local medal = tostring(payload.Medal or "Finished")
	local baseReward = eventNumber(timeTrialEventFolder(eventId), "BaseReward", numberAttr(timeTrialRewards, "BaseRewardDefault", 500))
	local amount = baseReward * medalMultiplier(medal) * tierMultiplier(tier)
	local bucket = bestBucket(profile, eventId, tier)
	local previousRank = medalRank(bucket.BestMedal)
	local currentRank = medalRank(medal)
	if currentRank <= previousRank then
		amount *= numberAttr(timeTrialRewards, "RepeatRewardMultiplier", 0.35)
	elseif previousRank > 0 then
		amount *= numberAttr(timeTrialRewards, "MedalUpgradeRewardMultiplier", 1.0)
	end
	if medal == "Platinum" and previousRank < medalRank("Platinum") then
		amount += numberAttr(timeTrialRewards, "FirstPlatinumBonus", 250)
	end
	local rounded = roundCash(amount, numberAttr(timeTrialRewards, "RewardRoundToNearest", 250))
	return math.clamp(rounded, numberAttr(timeTrialRewards, "MinReward", 0), numberAttr(timeTrialRewards, "MaxReward", 10000)), previousRank, currentRank
end

local function calculateRaceAmount(payload)
	local eventId = tostring(payload.EventId or "")
	local medal = tostring(payload.Medal or raceMedalForPlace(payload.Place))
	local baseReward = eventNumber(raceEventFolder(eventId), "BaseReward", numberAttr(raceRewards, "BaseRewardDefault", 750))
	local amount = baseReward * racePlacementMultiplier(medal)
	local rounded = roundCash(amount, numberAttr(raceRewards, "RewardRoundToNearest", 250))
	return math.clamp(rounded, numberAttr(raceRewards, "MinReward", 0), numberAttr(raceRewards, "MaxReward", 10000))
end

local function grantCash(player, amount, reason, metadata)
	local grant = garageCashGrantBinding()
	if not grant then
		return false, nil, "Garage cash bridge is unavailable."
	end
	metadata = typeof(metadata) == "table" and metadata or {}
	metadata.Player = player
	metadata.Amount = amount
	metadata.Reason = reason
	local ok, result = pcall(function()
		return grant:Invoke("GrantCash", metadata)
	end)
	if not ok or typeof(result) ~= "table" or result.Ok ~= true then
		return false, result, "Cash grant failed: " .. tostring(result and result.Message or result)
	end
	return true, result, nil
end

timeTrialGrantBinding.OnInvoke = function(action, payload)
	if action ~= "GrantTimeTrialReward" then
		return { Ok = false, Granted = false, Amount = 0, Message = "Unknown reward action." }
	end
	payload = typeof(payload) == "table" and payload or {}
	local player = payload.Player
	if not player then return { Ok = false, Granted = false, Amount = 0, Message = "Missing player." } end
	local runId = tostring(payload.RunId or "")
	if runId == "" then return { Ok = false, Granted = false, Amount = 0, Message = "Missing run id." } end
	local claimKey = "TT:" .. runId
	if claimedRunIds[claimKey] then
		return { Ok = true, Granted = false, Amount = 0, Message = "Reward already claimed for this run.", AlreadyClaimed = true }
	end
	claimedRunIds[claimKey] = true
	if not boolAttr(timeTrialRewards, "EnableCashRewards", true) then
		return { Ok = true, Granted = false, Amount = 0, Message = "Time-trial rewards are disabled." }
	end
	local profile = profileFor(player)
	if typeof(profile) ~= "table" then
		return { Ok = false, Granted = false, Amount = 0, Message = "Profile is not loaded." }
	end
	local eventId = tostring(payload.EventId or "")
	local tier = string.upper(tostring(payload.VehicleTier or ""))
	local medal = tostring(payload.Medal or "Finished")
	local elapsed = tonumber(payload.Elapsed) or 0
	local amount = calculateTimeTrialAmount(profile, payload)
	if amount <= 0 then
		local bucket = recordBest(player, eventId, tier, medal, elapsed, payload.SelectedVehicleId)
		return {
			Ok = true,
			Granted = false,
			Amount = 0,
			Message = "Finish recorded. Beat a medal target for cash rewards.",
			PreviousBestMedal = bucket and bucket.BestMedal or medal,
		}
	end
	local granted, result, errorMessage = grantCash(player, amount, "TimeTrialReward", {
		RunId = runId,
		EventId = eventId,
		VehicleTier = tier,
		Medal = medal,
	})
	if not granted then
		return { Ok = false, Granted = false, Amount = 0, Message = errorMessage }
	end
	local bucket = recordBest(player, eventId, tier, medal, elapsed, payload.SelectedVehicleId)
	info(player.Name .. " earned $" .. tostring(amount) .. " for " .. eventId .. " medal=" .. medal .. " tier=" .. tier)
	return {
		Ok = true,
		Granted = true,
		Amount = amount,
		Cash = result.Cash,
		Message = "Reward $" .. tostring(amount),
		PreviousBestMedal = bucket and bucket.BestMedal or medal,
	}
end

raceGrantBinding.OnInvoke = function(action, payload)
	if action ~= "GrantRaceReward" then
		return { Ok = false, Granted = false, Amount = 0, Message = "Unknown reward action." }
	end
	payload = typeof(payload) == "table" and payload or {}
	local player = payload.Player
	if not player then return { Ok = false, Granted = false, Amount = 0, Message = "Missing player." } end
	local runId = tostring(payload.RunId or "")
	if runId == "" then return { Ok = false, Granted = false, Amount = 0, Message = "Missing run id." } end
	local claimKey = "Race:" .. runId .. ":" .. tostring(player.UserId)
	if claimedRunIds[claimKey] then
		return { Ok = true, Granted = false, Amount = 0, Message = "Race reward already claimed.", AlreadyClaimed = true }
	end
	claimedRunIds[claimKey] = true
	local medal = raceMedalForPlace(payload.Place)
	payload.Medal = medal
	recordRaceFinish(player, payload)
	if not boolAttr(raceRewards, "EnableCashRewards", true) then
		return { Ok = true, Granted = false, Amount = 0, Medal = medal, Message = "Race rewards are disabled." }
	end
	local amount = calculateRaceAmount(payload)
	if amount <= 0 then
		return { Ok = true, Granted = false, Amount = 0, Medal = medal, Message = "No cash reward for this placement." }
	end
	local granted, result, errorMessage = grantCash(player, amount, "RaceReward", {
		RunId = runId,
		EventId = tostring(payload.EventId or ""),
		Place = tonumber(payload.Place) or 0,
		ParticipantCount = tonumber(payload.ParticipantCount) or 0,
		Medal = medal,
	})
	if not granted then
		return { Ok = false, Granted = false, Amount = 0, Medal = medal, Message = errorMessage }
	end
	info(player.Name .. " earned $" .. tostring(amount) .. " for race " .. tostring(payload.EventId or "") .. " place=" .. tostring(payload.Place) .. " medal=" .. medal)
	return {
		Ok = true,
		Granted = true,
		Amount = amount,
		Cash = result.Cash,
		Medal = medal,
		Message = "Reward $" .. tostring(amount),
	}
end

info("Reward service active. Time trials and race placement rewards use global reward config without changing config values.")
