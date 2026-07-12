-- Neo Tokyo Racers - Racing UI Phase 9A Global Time Trial Leaderboard
-- Run from Roblox Studio Command Bar in Edit mode.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 9A Global Time Trial Leaderboard"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function ensure(parent, className, name)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA(className), item:GetFullName() .. " has wrong class") return item end
	item = Instance.new(className) item.Name = name item.Parent = parent return item
end

local function value(parent, className, name, default)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA(className), item:GetFullName() .. " has wrong class") return item end
	item = Instance.new(className) item.Name = name item.Value = default item.Parent = parent
	return item
end

local function replaceOnce(source, old, new, label)
	local first = string.find(source, old, 1, true)
	assert(first, "Missing " .. label .. " anchor; refresh the mirror before patching")
	assert(not string.find(source, old, first + #old, true), "Ambiguous " .. label .. " anchor")
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, first + #old)
end

local SERVICE_SOURCE = [====[
-- Neo Tokyo Racers - Global Time Trial Leaderboard Service
-- NTR_RACING_UI_PHASE9A_GLOBAL_LEADERBOARD_SERVICE

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("Racing"):WaitForChild("Leaderboards")
local bindings = script.Parent:WaitForChild("GlobalTimeTrialLeaderboardBindings")
local recordBinding = bindings:WaitForChild("RecordTimeTrialBest")
local readBinding = bindings:WaitForChild("GetTimeTrialLeaderboard")

local boardCache = {}
local metadataCache = {}
local requestTimes = {}

local function configValue(name, fallback)
	local item = config:FindFirstChild(name)
	return item and item.Value or fallback
end

local function enabled() return configValue("DataStoreEnabled", false) == true end
local function clean(value)
	value = string.lower(tostring(value or "")):gsub("[^%w_]", "_")
	return string.sub(value, 1, 28)
end
local function boardKey(eventId, tier) return clean(eventId) .. "_" .. clean(string.upper(tostring(tier or ""))) end
local function orderedStore(eventId, tier)
	return DataStoreService:GetOrderedDataStore(tostring(configValue("OrderedStorePrefix", "NTR_TT_Global_v1")) .. "_" .. boardKey(eventId, tier))
end
local function metadataStore() return DataStoreService:GetDataStore(tostring(configValue("MetadataStoreName", "NTR_TT_Global_Metadata_v1"))) end
local function metadataKey(eventId, tier, userId) return boardKey(eventId, tier) .. "::" .. tostring(userId) end

local function record(player, payload)
	payload = typeof(payload) == "table" and payload or {}
	if not enabled() then return { Ok = false, Available = false, Message = "Global leaderboard DataStore disabled." } end
	if not (player and player.UserId > 0) then return { Ok = false, Available = false, Message = "Production player required." } end
	local eventId, tier = tostring(payload.EventId or ""), string.upper(tostring(payload.VehicleTier or ""))
	local seconds = tonumber(payload.BestSeconds)
	if eventId == "" or tier == "" or not seconds or seconds <= 0 or seconds > 86400 then return { Ok = false, Message = "Invalid global PB payload." } end
	local milliseconds = math.floor(seconds * 1000 + 0.5)
	local ok, err = pcall(function()
		orderedStore(eventId, tier):UpdateAsync(tostring(player.UserId), function(previous)
			previous = tonumber(previous)
			return previous and math.min(previous, milliseconds) or milliseconds
		end)
		metadataStore():SetAsync(metadataKey(eventId, tier, player.UserId), {
			VehicleId = tostring(payload.VehicleId or ""), VehicleName = tostring(payload.VehicleName or ""), UpdatedUnix = os.time(),
		})
	end)
	if not ok then return { Ok = false, Available = true, Message = tostring(err) } end
	boardCache[boardKey(eventId, tier)] = nil
	metadataCache[metadataKey(eventId, tier, player.UserId)] = nil
	return { Ok = true, Available = true }
end

local function metadata(eventId, tier, userId)
	local key = metadataKey(eventId, tier, userId)
	if metadataCache[key] then return metadataCache[key] end
	local ok, result = pcall(function() return metadataStore():GetAsync(key) end)
	result = ok and typeof(result) == "table" and result or {}
	metadataCache[key] = result
	return result
end

local function read(player, payload)
	payload = typeof(payload) == "table" and payload or {}
	if not enabled() then return { Ok = false, Available = false, Entries = {}, Message = "Global leaderboard DataStore disabled." } end
	local now = os.clock()
	if player and now - (requestTimes[player] or 0) < math.max(1, tonumber(configValue("RequestCooldownSeconds", 3)) or 3) then
		return { Ok = false, Available = true, Entries = {}, Message = "Leaderboard request cooldown." }
	end
	if player then requestTimes[player] = now end
	local eventId, tier = tostring(payload.EventId or ""), string.upper(tostring(payload.VehicleTier or ""))
	local limit = math.clamp(math.floor(tonumber(payload.Limit) or 20), 1, 20)
	local cacheKey = boardKey(eventId, tier)
	local cached = boardCache[cacheKey]
	if cached and now - cached.At < math.max(10, tonumber(configValue("CacheSeconds", 60)) or 60) then return cached.Result end
	local ok, pages = pcall(function() return orderedStore(eventId, tier):GetSortedAsync(true, limit) end)
	if not ok then return { Ok = false, Available = true, Entries = {}, Message = tostring(pages) } end
	local entries = {}
	for rank, row in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(row.key)
		if userId then
			local username = "PLAYER " .. tostring(userId)
			pcall(function() username = Players:GetNameFromUserIdAsync(userId) end)
			local meta = metadata(eventId, tier, userId)
			table.insert(entries, { Rank = rank, UserId = userId, Username = username, DisplayName = username, BestSeconds = tonumber(row.value) / 1000, VehicleId = tostring(meta.VehicleId or ""), VehicleName = tostring(meta.VehicleName or "") })
		end
	end
	local result = { Ok = true, Available = true, EventId = eventId, VehicleTier = tier, Entries = entries }
	boardCache[cacheKey] = { At = now, Result = result }
	return result
end

recordBinding.OnInvoke = record
readBinding.OnInvoke = read
Players.PlayerRemoving:Connect(function(player) requestTimes[player] = nil end)
print("[NTR Racing UI Phase 9A] Global leaderboard service active; enabled=" .. tostring(enabled()))
]====]

local OLD_RECORD_HELPER = [====[local function recordPersistentPersonalBest(player, run, elapsed, medal)
	local binding = getPersonalBestBinding("RecordTimeTrialBest")
	if not binding then
		return nil
	end
	local ok, result = pcall(function()
		return binding:Invoke(player, {
			RunId = run.RunId,
			EventId = run.EventId,
			RouteId = run.RouteId,
			DisplayName = run.DisplayName,
			VehicleTier = run.VehicleTier,
			VehicleIndex = run.VehicleIndex,
			SelectedVehicleId = run.SelectedVehicleId,
			Elapsed = elapsed,
			Medal = medal,
		})
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Message = "Persistent PB service failed: " .. tostring(result) }
end
]====]

local NEW_RECORD_HELPER = [====[-- NTR_RACING_UI_PHASE9A_PB_TO_GLOBAL_BRIDGE
local function globalLeaderboardBinding(name)
	local folder = script.Parent:FindFirstChild("GlobalTimeTrialLeaderboardBindings")
	local binding = folder and folder:FindFirstChild(name)
	return binding and binding:IsA("BindableFunction") and binding or nil
end

local function recordPersistentPersonalBest(player, run, elapsed, medal)
	local binding = getPersonalBestBinding("RecordTimeTrialBest")
	if not binding then return nil end
	local ok, result = pcall(function()
		return binding:Invoke(player, { RunId = run.RunId, EventId = run.EventId, RouteId = run.RouteId, DisplayName = run.DisplayName, VehicleTier = run.VehicleTier, VehicleIndex = run.VehicleIndex, SelectedVehicleId = run.SelectedVehicleId, Elapsed = elapsed, Medal = medal })
	end)
	if ok and typeof(result) == "table" then
		if result.IsPersonalBest == true then
			local global = globalLeaderboardBinding("RecordTimeTrialBest")
			if global then task.spawn(function() pcall(function() global:Invoke(player, { EventId = run.EventId, VehicleTier = run.VehicleTier, BestSeconds = result.PersonalBestSeconds or elapsed, VehicleId = result.PersonalBestVehicleId or run.SelectedVehicleId, VehicleName = tostring(run.Vehicle and (run.Vehicle:GetAttribute("DisplayName") or run.Vehicle:GetAttribute("CockpitId") or run.Vehicle.Name) or "") }) end) end) end
		end
		return result
	end
	return { Ok = false, Message = "Persistent PB service failed: " .. tostring(result) }
end
]====]

local GLOBAL_ACTION = [====[
	elseif action == "GetTimeTrialLeaderboard" then
		-- NTR_RACING_UI_PHASE9A_GLOBAL_READ_ACTION
		local binding = globalLeaderboardBinding("GetTimeTrialLeaderboard")
		if not binding then return { Ok = false, Available = false, Entries = {}, Message = "Global leaderboard service unavailable." } end
		local ok, result = pcall(function() return binding:Invoke(player, payload) end)
		return ok and typeof(result) == "table" and result or { Ok = false, Available = false, Entries = {}, Message = tostring(result) }
]====]

local function paths()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing")
	return kit, services
end

local function install()
	local kit, services = paths()
	local config = ensure(kit.Config.Racing, "Folder", "Leaderboards")
	value(config, "BoolValue", "DataStoreEnabled", false)
	value(config, "StringValue", "OrderedStorePrefix", "NTR_TT_Global_v1")
	value(config, "StringValue", "MetadataStoreName", "NTR_TT_Global_Metadata_v1")
	value(config, "NumberValue", "CacheSeconds", 60)
	value(config, "NumberValue", "RequestCooldownSeconds", 3)
	local bindings = ensure(services, "Folder", "GlobalTimeTrialLeaderboardBindings")
	ensure(bindings, "BindableFunction", "RecordTimeTrialBest")
	ensure(bindings, "BindableFunction", "GetTimeTrialLeaderboard")
	local service = ensure(services, "Script", "GlobalTimeTrialLeaderboardService_Active")
	service.Source = SERVICE_SOURCE service.Enabled = true
	local timeTrial = services:WaitForChild("TimeTrialService_Active")
	local source = timeTrial.Source
	if not string.find(source, "NTR_RACING_UI_PHASE9A_PB_TO_GLOBAL_BRIDGE", 1, true) then source = replaceOnce(source, OLD_RECORD_HELPER, NEW_RECORD_HELPER, "PB-to-global bridge") end
	if not string.find(source, "NTR_RACING_UI_PHASE9A_GLOBAL_READ_ACTION", 1, true) then source = replaceOnce(source, '\telseif action == "StartStagedTimeTrial" then\n', GLOBAL_ACTION .. '\telseif action == "StartStagedTimeTrial" then\n', "global read action") end
	timeTrial.Source = source
	print("[" .. PHASE .. "] INSTALL complete. Leave DataStoreEnabled false for Studio-only testing; enable for published production verification.")
end

local function smoke()
	local kit, services = paths()
	assert(services:FindFirstChild("GlobalTimeTrialLeaderboardService_Active"), "Leaderboard service missing")
	assert(string.find(services.TimeTrialService_Active.Source, "NTR_RACING_UI_PHASE9A_PB_TO_GLOBAL_BRIDGE", 1, true), "PB bridge missing")
	assert(string.find(services.TimeTrialService_Active.Source, "NTR_RACING_UI_PHASE9A_GLOBAL_READ_ACTION", 1, true), "Read action missing")
	assert(kit.Config.Racing:FindFirstChild("Leaderboards"), "Leaderboard config missing")
	print("[" .. PHASE .. "] SMOKE PASS")
end

if MODE == "INSTALL" then install() smoke() elseif MODE == "SMOKE" then smoke() else error("Unknown MODE") end
