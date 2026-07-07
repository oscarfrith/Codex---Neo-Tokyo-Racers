-- Neo Tokyo Racers - Racing Phase 6 Time Trial Rewards Pack
-- Installs a guarded reward service, a tiny garage cash bridge, and finish-payload UI reward text.
--
-- Important: this script intentionally does not read or edit Config.Racing.RouteGuide.
-- Fragile areas: this patches source anchors in TimeTrialService_Active,
-- RaceEntryMenuClient_Active, and the large GarageActionController_Shadow_Disabled.
-- If any anchor is missing, stop and refresh the Studio mirror before another repair.

local MODE = "INSTALL" -- INSTALL or AUDIT
local PHASE = "NTR Racing Phase 6"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		fail(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureScript(parent, className, name, source, disabled)
	local item = parent:FindFirstChild(name)
	if item and item.ClassName ~= className then
		fail(item:GetFullName() .. " must be a " .. className)
	end
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Parent = parent
	end
	item.Source = source
	if item:IsA("Script") or item:IsA("LocalScript") then
		item.Disabled = disabled == true
	end
	return item
end

local function replaceExact(source, oldText, newText, label)
	if not string.find(source, oldText, 1, true) then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another Racing Phase 6 repair.")
	end
	return string.gsub(source, oldText:gsub("([^%w])", "%%%1"), newText, 1)
end

local function insertAfter(source, anchor, insertText, label)
	if string.find(source, insertText, 1, true) then
		return source, false
	end
	local startIndex, endIndex = string.find(source, anchor, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another Racing Phase 6 repair.")
	end
	return string.sub(source, 1, endIndex) .. insertText .. string.sub(source, endIndex + 1), true
end

local REWARD_SERVICE_SOURCE = [==[
-- Neo Tokyo Racers - Racing Phase 6 Reward Service
-- NTR_RACING_PHASE6_REWARD_SERVICE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "NTR Racing Phase 6 Rewards"
local MEDAL_RANK = {
	Finished = 0,
	Bronze = 1,
	Silver = 2,
	Gold = 3,
	Platinum = 4,
}

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingConfig = kit:WaitForChild("Config"):WaitForChild("Racing")
local rewardsConfig = racingConfig:WaitForChild("Rewards")

local racingRoot = script.Parent
local bindings = racingRoot:FindFirstChild("RaceRewardBindings") or Instance.new("Folder")
bindings.Name = "RaceRewardBindings"
bindings.Parent = racingRoot

local grantBinding = bindings:FindFirstChild("GrantTimeTrialReward") or Instance.new("BindableFunction")
grantBinding.Name = "GrantTimeTrialReward"
grantBinding.Parent = bindings

local claimedRunIds = {}

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function configNumber(name, fallback)
	local value = tonumber(rewardsConfig:GetAttribute(name))
	if value == nil then
		return fallback
	end
	return value
end

local function configBool(name, fallback)
	local value = rewardsConfig:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value == true
end

local function medalRank(medal)
	return MEDAL_RANK[tostring(medal or "Finished")] or 0
end

local function eventFolder(eventId)
	local catalog = racingConfig:FindFirstChild("TimeTrialCatalog")
	return catalog and catalog:FindFirstChild(tostring(eventId or ""))
end

local function eventNumber(eventId, name, fallback)
	local folder = eventFolder(eventId)
	local value = folder and tonumber(folder:GetAttribute(name))
	if value == nil then
		return fallback
	end
	return value
end

local function medalMultiplier(medal)
	local name = tostring(medal or "Finished")
	if name == "Platinum" then return configNumber("PlatinumRewardMultiplier", 1.3) end
	if name == "Gold" then return configNumber("GoldRewardMultiplier", 1.0) end
	if name == "Silver" then return configNumber("SilverRewardMultiplier", 0.75) end
	if name == "Bronze" then return configNumber("BronzeRewardMultiplier", 0.55) end
	return configNumber("FinishedRewardMultiplier", 0)
end

local function tierMultiplier(tier)
	tier = string.upper(tostring(tier or "E"))
	return configNumber("TierMultiplier_" .. tier, 1)
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
	local bindings = profileBindings()
	if not bindings then
		return nil
	end
	local ok, profile = pcall(function()
		return bindings.GetProfile:Invoke(player)
	end)
	if ok and typeof(profile) == "table" then
		return profile
	end
	return nil
end

local function persistProfile(player, profile, reason)
	local bindings = profileBindings()
	if not bindings or typeof(profile) ~= "table" then
		return false
	end
	local ok, importOk = pcall(function()
		return bindings.ImportProfileSnapshot:Invoke(player, profile, tostring(reason or "RaceReward"), true)
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
	if typeof(profile) ~= "table" then
		return nil
	end
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

local function calculateAmount(profile, payload)
	local eventId = tostring(payload.EventId or "")
	local tier = string.upper(tostring(payload.VehicleTier or "E"))
	local medal = tostring(payload.Medal or "Finished")
	local baseReward = eventNumber(eventId, "BaseReward", configNumber("BaseRewardDefault", 500))
	local amount = baseReward * medalMultiplier(medal) * tierMultiplier(tier)

	local bucket = bestBucket(profile, eventId, tier)
	local previousRank = medalRank(bucket.BestMedal)
	local currentRank = medalRank(medal)
	if currentRank <= previousRank then
		amount *= configNumber("RepeatRewardMultiplier", 0.35)
	elseif previousRank > 0 then
		amount *= configNumber("MedalUpgradeRewardMultiplier", 1.0)
	end

	if medal == "Platinum" and previousRank < medalRank("Platinum") then
		amount += configNumber("FirstPlatinumBonus", 250)
	end

	local minReward = configNumber("MinReward", 0)
	local maxReward = configNumber("MaxReward", 10000)
	return math.clamp(math.floor(amount + 0.5), minReward, maxReward), previousRank, currentRank, bucket
end

grantBinding.OnInvoke = function(action, payload)
	if action ~= "GrantTimeTrialReward" then
		return { Ok = false, Granted = false, Amount = 0, Message = "Unknown reward action." }
	end
	payload = typeof(payload) == "table" and payload or {}
	local player = payload.Player
	if not player then
		return { Ok = false, Granted = false, Amount = 0, Message = "Missing player." }
	end
	local runId = tostring(payload.RunId or "")
	if runId == "" then
		return { Ok = false, Granted = false, Amount = 0, Message = "Missing run id." }
	end
	if claimedRunIds[runId] then
		return { Ok = true, Granted = false, Amount = 0, Message = "Reward already claimed for this run.", AlreadyClaimed = true }
	end
	claimedRunIds[runId] = true

	if not configBool("EnableCashRewards", true) then
		return { Ok = true, Granted = false, Amount = 0, Message = "Race rewards are disabled." }
	end

	local profile = profileFor(player)
	if typeof(profile) ~= "table" then
		return { Ok = false, Granted = false, Amount = 0, Message = "Profile is not loaded." }
	end

	local amount, previousRank, currentRank = calculateAmount(profile, payload)
	local eventId = tostring(payload.EventId or "")
	local tier = string.upper(tostring(payload.VehicleTier or ""))
	local medal = tostring(payload.Medal or "Finished")
	local elapsed = tonumber(payload.Elapsed) or 0

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

	local grant = garageCashGrantBinding()
	if not grant then
		return { Ok = false, Granted = false, Amount = 0, Message = "Garage cash bridge is unavailable." }
	end

	local ok, result = pcall(function()
		return grant:Invoke("GrantCash", {
			Player = player,
			Amount = amount,
			Reason = "TimeTrialReward",
			RunId = runId,
			EventId = eventId,
			VehicleTier = tier,
			Medal = medal,
		})
	end)
	if not ok or typeof(result) ~= "table" or result.Ok ~= true then
		return { Ok = false, Granted = false, Amount = 0, Message = "Cash grant failed: " .. tostring(result and result.Message or result) }
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

info("Reward service active.")
]==]

local TIME_TRIAL_REWARD_HELPERS = [==[

-- NTR_RACING_PHASE6_REWARD_HELPERS
local function getRaceRewardBinding()
	local serverRoot = game:GetService("ServerScriptService"):FindFirstChild("NeoTokyoRacers")
	local services = serverRoot and serverRoot:FindFirstChild("Services")
	local racing = services and services:FindFirstChild("Racing")
	local bindings = racing and racing:FindFirstChild("RaceRewardBindings")
	local grant = bindings and bindings:FindFirstChild("GrantTimeTrialReward")
	if grant and grant:IsA("BindableFunction") then
		return grant
	end
	return nil
end

local function grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)
	local grant = getRaceRewardBinding()
	if not grant then
		return { Ok = false, Granted = false, Amount = 0, Message = "Reward service unavailable." }
	end
	local ok, result = pcall(function()
		return grant:Invoke("GrantTimeTrialReward", {
			Player = player,
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			DisplayName = run.DisplayName,
			VehicleTier = run.VehicleTier,
			VehicleIndex = run.VehicleIndex,
			SelectedVehicleId = run.SelectedVehicleId,
			Elapsed = elapsed,
			Medal = medal,
			IsPersonalBest = isPersonalBest == true,
		})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Granted = false, Amount = 0, Message = "Reward grant failed: " .. tostring(result) }
end
]==]

local GARAGE_CASH_BRIDGE = [==[

	-- NTR_RACING_PHASE6_GARAGE_CASH_BRIDGE
	local V91_RaceRewardBridgeReady = false
	local function V91_ensureRaceRewardCashBridge()
		if V91_RaceRewardBridgeReady then
			return
		end
		local bindings = script.Parent:FindFirstChild("GarageProfileMutationBindings")
		if not bindings then
			bindings = Instance.new("Folder")
			bindings.Name = "GarageProfileMutationBindings"
			bindings.Parent = script.Parent
		end
		local grantCash = bindings:FindFirstChild("GrantCash")
		if not grantCash then
			grantCash = Instance.new("BindableFunction")
			grantCash.Name = "GrantCash"
			grantCash.Parent = bindings
		end
		grantCash.OnInvoke = function(action, payload)
			if action ~= "GrantCash" then
				return { Ok = false, Success = false, Message = "Unknown garage mutation action." }
			end
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			local amount = math.floor((tonumber(payload.Amount) or 0) + 0.5)
			if not player or amount <= 0 then
				return { Ok = false, Success = false, Message = "Missing player or positive amount." }
			end
			local profile = V56_getProfile(player)
			profile.Cash = math.max(0, math.floor((tonumber(profile.Cash) or 0) + amount))
			V56_setLeaderstats(player, profile)
			V80_mirrorLegacyProfileToPersistence(player, profile, tostring(payload.Reason or "RaceRewardGrant"), true)
			player:SetAttribute("NTR_LastRaceRewardAmount", amount)
			player:SetAttribute("NTR_LastRaceRewardRunId", tostring(payload.RunId or ""))
			player:SetAttribute("NTR_LastRaceRewardEventId", tostring(payload.EventId or ""))
			return { Ok = true, Success = true, Amount = amount, Cash = profile.Cash }
		end
		V91_RaceRewardBridgeReady = true
	end
	V91_ensureRaceRewardCashBridge()
]==]

local function getKit()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	if not kit then
		fail("Missing ReplicatedStorage.NeoTokyoRacers")
	end
	return kit
end

local function getRacingServerRoot()
	local root = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Racing")
	if not root then
		fail("Missing ServerScriptService.NeoTokyoRacers.Services.Racing. Run Racing Phase 3 first.")
	end
	return root
end

local function getTimeTrialService()
	local service = getRacingServerRoot():FindFirstChild("TimeTrialService_Active")
	if not service then
		fail("Missing TimeTrialService_Active. Run Racing Phase 4 first.")
	end
	return service
end

local function getRaceEntryClient()
	local controllers = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	local client = racing and racing:FindFirstChild("RaceEntryMenuClient_Active")
	if not client then
		fail("Missing RaceEntryMenuClient_Active. Run Racing Phase 4 first.")
	end
	return client
end

local function getGarageController()
	local garage = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage")
	local scriptObject = garage and garage:FindFirstChild("GarageActionController_Shadow_Disabled")
	if not scriptObject then
		fail("Missing GarageActionController_Shadow_Disabled. Refresh the Studio mirror before installing rewards.")
	end
	return scriptObject
end

local function ensureRewardsConfig()
	local kit = getKit()
	local config = ensureFolder(kit, "Config")
	local racing = ensureFolder(config, "Racing")
	local rewards = ensureFolder(racing, "Rewards")
	local defaults = {
		EnableCashRewards = true,
		BaseRewardDefault = 500,
		FinishedRewardMultiplier = 0,
		BronzeRewardMultiplier = 0.55,
		SilverRewardMultiplier = 0.75,
		GoldRewardMultiplier = 1.0,
		PlatinumRewardMultiplier = 1.3,
		RepeatRewardMultiplier = 0.35,
		MedalUpgradeRewardMultiplier = 1.0,
		FirstPlatinumBonus = 250,
		MinReward = 0,
		MaxReward = 10000,
		TierMultiplier_E = 1.0,
		TierMultiplier_D = 1.15,
		TierMultiplier_C = 1.35,
		TierMultiplier_B = 1.6,
		TierMultiplier_A = 1.9,
		TierMultiplier_S = 2.25,
	}
	for name, value in pairs(defaults) do
		if rewards:GetAttribute(name) == nil then
			rewards:SetAttribute(name, value)
		end
	end
	return rewards
end

local function installRewardService()
	local root = getRacingServerRoot()
	ensureScript(root, "Script", "RaceRewardService_Active", REWARD_SERVICE_SOURCE, false)
	info("Installed RaceRewardService_Active.")
end

local function patchGarageCashBridge()
	local scriptObject = getGarageController()
	local source = scriptObject.Source
	if string.find(source, "NTR_RACING_PHASE6_GARAGE_CASH_BRIDGE", 1, true) then
		info("Garage cash bridge already installed.")
		return
	end
	local anchor = [==[
	local function V56_setLeaderstats(player, profile)
		local stats = player:FindFirstChild("leaderstats")
		if not stats then
			stats = Instance.new("Folder")
			stats.Name = "leaderstats"
			stats.Parent = player
		end
		local cash = stats:FindFirstChild("Cash")
		if not cash then
			cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Parent = stats
		end
		cash.Value = math.floor(profile.Cash or 0)
	end
]==]
	local replacement = anchor .. GARAGE_CASH_BRIDGE
	scriptObject.Source = replaceExact(source, anchor, replacement, "V56_setLeaderstats cash bridge")
	info("Patched GarageActionController_Shadow_Disabled with server-only race reward cash bridge.")
end

local function patchTimeTrialService()
	local service = getTimeTrialService()
	local source = service.Source
	if not string.find(source, "NTR_RACING_PHASE4_RESULTS_PACK", 1, true) then
		fail("TimeTrialService_Active does not include Phase 4 results. Run Phase 4 first.")
	end
	local changed = false
	source, changed = insertAfter(source, "local RaceConfigReader = require(racingModules:WaitForChild(\"RaceConfigReader\"))", TIME_TRIAL_REWARD_HELPERS, "RaceConfigReader require")
	if changed then
		info("Inserted reward helper functions into TimeTrialService_Active.")
	end
	if not string.find(source, "local reward = grantTimeTrialReward", 1, true) then
		local old = [==[
	if isPersonalBest then
		bucket.BestSeconds = elapsed
		bucket.BestMedal = medal
		bucket.BestVehicleId = run.SelectedVehicleId
		bucket.BestVehicleTier = run.VehicleTier
		bucket.UpdatedClock = os.clock()
	end

	fire(player, {
]==]
		local new = [==[
	if isPersonalBest then
		bucket.BestSeconds = elapsed
		bucket.BestMedal = medal
		bucket.BestVehicleId = run.SelectedVehicleId
		bucket.BestVehicleTier = run.VehicleTier
		bucket.UpdatedClock = os.clock()
	end

	local reward = grantTimeTrialReward(player, run, elapsed, medal, isPersonalBest)

	fire(player, {
]==]
		source = replaceExact(source, old, new, "finishRun reward call")
	end
	if not string.find(source, "RewardGranted = reward.Granted", 1, true) then
		local oldPayload = [==[
		CanRetry = true,
		Message = isPersonalBest and "New personal best!" or "Finished.",
]==]
		local newPayload = [==[
		CanRetry = true,
		RewardGranted = reward.Granted == true,
		RewardAmount = tonumber(reward.Amount) or 0,
		RewardCash = reward.Cash,
		RewardMessage = reward.Message,
		Message = (reward.Granted == true and ("New personal best!  $" .. tostring(reward.Amount or 0) .. " earned")) or (isPersonalBest and "New personal best!" or tostring(reward.Message or "Finished.")),
]==]
		source = replaceExact(source, oldPayload, newPayload, "finish payload reward fields")
	end
	service.Source = source
	info("Patched TimeTrialService_Active with reward grant payloads.")
end

local function patchRaceResultUi()
	local client = getRaceEntryClient()
	local source = client.Source
	if string.find(source, "NTR_RACING_PHASE6_REWARD_RESULT_UI", 1, true) then
		info("Race result UI reward line already installed.")
		return
	end
	local oldLabels = [==[
local resultNext = label(resultPanel, "", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 178), touch and 11 or 13, theme.Muted, false)
resultNext.TextXAlignment = Enum.TextXAlignment.Center
local resultSplits = label(resultPanel, "", UDim2.new(1, -36, 0, 82), UDim2.fromOffset(18, 226), touch and 10 or 12, theme.Text, false)
resultSplits.TextYAlignment = Enum.TextYAlignment.Top
]==]
	local newLabels = [==[
local resultNext = label(resultPanel, "", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 178), touch and 11 or 13, theme.Muted, false)
resultNext.TextXAlignment = Enum.TextXAlignment.Center
-- NTR_RACING_PHASE6_REWARD_RESULT_UI
local resultReward = label(resultPanel, "", UDim2.new(1, -36, 0, 28), UDim2.fromOffset(18, 218), touch and 12 or 14, theme.Accent, true)
resultReward.TextXAlignment = Enum.TextXAlignment.Center
local resultSplits = label(resultPanel, "", UDim2.new(1, -36, 0, 58), UDim2.fromOffset(18, 252), touch and 10 or 12, theme.Text, false)
resultSplits.TextYAlignment = Enum.TextYAlignment.Top
]==]
	source = replaceExact(source, oldLabels, newLabels, "result reward label")
	local oldShow = [==[
	resultSplits.Text = splitSummary(payload.Splits)
	resultRetry.Visible = payload.CanRetry ~= false
	resultPanel.Visible = true
end
]==]
	local newShow = [==[
	local rewardAmount = tonumber(payload.RewardAmount) or 0
	if payload.RewardGranted == true and rewardAmount > 0 then
		resultReward.Text = "REWARD  $" .. tostring(math.floor(rewardAmount + 0.5))
	elseif payload.RewardMessage and payload.RewardMessage ~= "" then
		resultReward.Text = tostring(payload.RewardMessage)
	else
		resultReward.Text = "No cash reward this run."
	end
	resultSplits.Text = splitSummary(payload.Splits)
	resultRetry.Visible = payload.CanRetry ~= false
	resultPanel.Visible = true
end
]==]
	source = replaceExact(source, oldShow, newShow, "showResult reward text")
	client.Source = source
	info("Patched RaceEntryMenuClient_Active result panel with reward text.")
end

local function audit()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local racingConfig = kit and kit:FindFirstChild("Config") and kit.Config:FindFirstChild("Racing")
	local routeGuide = racingConfig and racingConfig:FindFirstChild("RouteGuide")
	local rewards = racingConfig and racingConfig:FindFirstChild("Rewards")
	local racingRoot = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Racing")
	local garage = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage")
	info("Audit:")
	info("  Rewards config=" .. tostring(rewards ~= nil))
	info("  RouteGuide config untouched/present=" .. tostring(routeGuide ~= nil))
	info("  RaceRewardService_Active=" .. tostring(racingRoot and racingRoot:FindFirstChild("RaceRewardService_Active") ~= nil))
	info("  RaceRewardBindings=" .. tostring(racingRoot and racingRoot:FindFirstChild("RaceRewardBindings") ~= nil))
	info("  GarageProfileMutationBindings=" .. tostring(garage and garage:FindFirstChild("GarageProfileMutationBindings") ~= nil))
	info("  TimeTrialService Phase6=" .. tostring(getTimeTrialService().Source:find("NTR_RACING_PHASE6_REWARD_HELPERS", 1, true) ~= nil))
	info("  Result UI Phase6=" .. tostring(getRaceEntryClient().Source:find("NTR_RACING_PHASE6_REWARD_RESULT_UI", 1, true) ~= nil))
end

if MODE == "AUDIT" then
	audit()
else
	ensureRewardsConfig()
	patchGarageCashBridge()
	installRewardService()
	patchTimeTrialService()
	patchRaceResultUi()
	audit()
	info("Install complete. Restart Play before testing.")
end
