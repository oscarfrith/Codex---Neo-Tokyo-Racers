-- UI restyle probe: profile_fingerprint_saved (datamodel: Edit, NOT running). READ-ONLY.
-- OPTIONAL and needs Oscar's yes: it reads his saved data with DataStore GetAsync (three reads,
-- no writes, no session lease, no UpdateAsync). It is the only probe that can show the SAVED
-- profile is untouched by an agent session, because under the sandbox the in-memory profile is
-- not what is stored (see SANDBOX_NOTES.md). Run it before the first session and after the last.
-- Needs "Enable Studio Access to API Services"; every call is pcall-ed and failures are reported.
-- Keys and store names are read from the same config the services read:
--   profile   ServerStorage.Config.Player.Persistence@DataStoreName, key "player_<UserId>"   (ProfileServer 110-128)
--   PBs       ServerStorage.Config.Racing.PersonalBests.DataStoreName, key "player_<UserId>" (PersonalBestServer 110-124)
--   desk      Workspace.World.Dealership.Intro@DataStoreName, key "desk_objective_<UserId>"   (IntroProgressServer 91-116)
local ARGS = {
	label = "",
	userId = 0,        -- REQUIRED: the UserId whose saved data is fingerprinted
	detail = false,    -- true = list vehicle ids and PB keys
}

local PLACE_ID = 93959280828322

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

if game.PlaceId ~= PLACE_ID or RunService:IsRunning() then
	return HttpService:JSONEncode({ probe = "profile_fingerprint_saved", ok = false, error = "run on the Edit datamodel of place " .. PLACE_ID .. " with Play stopped", placeId = game.PlaceId })
end
local userId = tonumber(ARGS.userId) or 0
if userId <= 0 then
	return HttpService:JSONEncode({ probe = "profile_fingerprint_saved", ok = false, error = "set ARGS.userId" })
end

local function find(root, ...)
	local item = root
	for _, name in ipairs({ ... }) do
		item = item and item:FindFirstChild(name)
	end
	return item
end

local function fnv(text)
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, index))
		local low = hash % 65536
		local high = (hash - low) / 65536
		hash = (low * 16777619 + ((high * 16777619) % 65536) * 65536) % 4294967296
	end
	return hash
end

local function canonical(value, depth, out)
	local kind = typeof(value)
	if kind == "table" then
		if depth > 14 then
			table.insert(out, "<deep>")
			return
		end
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		table.insert(out, "{")
		for _, key in ipairs(keys) do
			table.insert(out, tostring(key))
			table.insert(out, "=")
			canonical(value[key], depth + 1, out)
			table.insert(out, ";")
		end
		table.insert(out, "}")
	elseif kind == "number" then
		table.insert(out, string.format("%.6g", value))
	else
		table.insert(out, tostring(value))
	end
end

local function hashOf(value)
	local out = {}
	canonical(value, 0, out)
	return fnv(table.concat(out))
end

local function countOf(value)
	local count = 0
	if type(value) == "table" then
		for _ in pairs(value) do
			count += 1
		end
	end
	return count
end

local function sortedKeys(value)
	local keys = {}
	if type(value) == "table" then
		for key in pairs(value) do
			table.insert(keys, tostring(key))
		end
	end
	table.sort(keys)
	return keys
end

local function read(storeName, key)
	local ok, value = pcall(function()
		return DataStoreService:GetDataStore(storeName):GetAsync(key)
	end)
	if ok then
		return true, value
	end
	return false, tostring(value)
end

local result = { probe = "profile_fingerprint_saved", ok = true, label = ARGS.label, userId = userId, unixTime = os.time() }

-- Profile ---------------------------------------------------------------------------------------
local persistence = find(ServerStorage, "Config", "Player", "Persistence")
local profileStoreName = tostring(persistence and persistence:GetAttribute("DataStoreName") or "NTR_PlayerProfiles_v1")
local profileEntry = { store = profileStoreName, key = "player_" .. userId }
if persistence then
	profileEntry.dataStoreEnabled = persistence:GetAttribute("DataStoreEnabled")
end
do
	local ok, data = read(profileStoreName, profileEntry.key)
	profileEntry.readOk = ok
	if not ok then
		profileEntry.error = data
	elseif type(data) ~= "table" then
		profileEntry.exists = data ~= nil
	else
		profileEntry.exists = true
		profileEntry.hash = hashOf(data)
		profileEntry.cash = data.Cash
		profileEntry.currentVehicleId = data.CurrentVehicleId
		profileEntry.vehicleCount = countOf(data.Vehicles)
		profileEntry.vehicleIdsHash = fnv(table.concat(sortedKeys(data.Vehicles), ","))
		profileEntry.cockpitInstanceCount = countOf(data.OwnedCockpitInstances)
		profileEntry.moduleInstanceCount = countOf(data.OwnedModuleInstances)
		local sections = {}
		for _, key in ipairs(sortedKeys(data)) do
			local value = data[key]
			sections[key] = { hash = hashOf(value), count = type(value) == "table" and countOf(value) or nil }
		end
		profileEntry.sections = sections
		if ARGS.detail then
			profileEntry.vehicleIds = sortedKeys(data.Vehicles)
		end
	end
end
result.profile = profileEntry

-- Personal bests --------------------------------------------------------------------------------
local pbConfig = find(ServerStorage, "Config", "Racing", "PersonalBests")
local pbNameValue = pbConfig and pbConfig:FindFirstChild("DataStoreName")
local pbEnabledValue = pbConfig and pbConfig:FindFirstChild("DataStoreEnabled")
local pbStoreName = pbNameValue and pbNameValue:IsA("StringValue") and pbNameValue.Value or "NTR_TimeTrialPersonalBests_v1"
local pbEntry = { store = pbStoreName, key = "player_" .. userId }
if pbEnabledValue and pbEnabledValue:IsA("BoolValue") then
	pbEntry.dataStoreEnabled = pbEnabledValue.Value
end
do
	local ok, data = read(pbStoreName, pbEntry.key)
	pbEntry.readOk = ok
	if not ok then
		pbEntry.error = data
	elseif type(data) ~= "table" then
		pbEntry.exists = data ~= nil
	else
		pbEntry.exists = true
		local records = type(data.Records) == "table" and data.Records or data
		-- UpdatedUnix at the top level is rewritten on every save; hash the records only.
		pbEntry.recordsHash = hashOf(records)
		pbEntry.recordCount = countOf(records)
		pbEntry.updatedUnix = data.UpdatedUnix
		if ARGS.detail then
			local rows = {}
			for _, key in ipairs(sortedKeys(records)) do
				local record = records[key]
				table.insert(rows, { key = key, bestSeconds = type(record) == "table" and record.BestSeconds or nil, updatedUnix = type(record) == "table" and record.UpdatedUnix or nil })
			end
			pbEntry.records = rows
		end
	end
end
result.personalBests = pbEntry

-- Dealership desk objective ---------------------------------------------------------------------
local intro = find(workspace, "World", "Dealership", "Intro")
local introStoreName = tostring(intro and intro:GetAttribute("DataStoreName") or "NTR_DealershipIntro_v1")
local introEntry = { store = introStoreName, key = "desk_objective_" .. userId, introFolderFound = intro ~= nil }
do
	local ok, data = read(introStoreName, introEntry.key)
	introEntry.readOk = ok
	if ok then
		introEntry.value = data == true
		introEntry.exists = data ~= nil
	else
		introEntry.error = data
	end
end
result.deskObjective = introEntry

result.fingerprint = fnv(table.concat({
	tostring(profileEntry.readOk), tostring(profileEntry.hash), tostring(pbEntry.readOk), tostring(pbEntry.recordsHash),
	tostring(introEntry.readOk), tostring(introEntry.value),
}, "|"))
result.notRead = {
	"global leaderboard ordered stores (one per event and tier) and their metadata store",
	"Duel stake markers",
}

return HttpService:JSONEncode(result)
