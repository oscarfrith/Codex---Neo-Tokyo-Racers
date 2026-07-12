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
