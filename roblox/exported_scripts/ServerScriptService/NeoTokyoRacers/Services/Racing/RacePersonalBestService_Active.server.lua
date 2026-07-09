-- Neo Tokyo Racers - Racing Personal Best Service
-- NTR_RACING_PHASE11M_PERSONAL_BEST_SERVICE

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "NTR Racing Phase 11M PB Service"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder.")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureBindableFunction(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("BindableFunction") then
		item:Destroy()
		item = nil
	end
	if not item then
		item = Instance.new("BindableFunction")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function ensureValue(parent, className, name, value)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA(className) then
		item:Destroy()
		item = nil
	end
	if not item then
		item = Instance.new(className)
		item.Name = name
		item.Value = value
		item.Parent = parent
	end
	return item
end

local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local configRoot = ensureFolder(ntr:WaitForChild("Config"):WaitForChild("Racing"), "PersonalBests")
ensureValue(configRoot, "BoolValue", "DataStoreEnabled", false)
ensureValue(configRoot, "StringValue", "DataStoreName", "NTR_TimeTrialPersonalBests_v1")
ensureValue(configRoot, "NumberValue", "SaveDebounceSeconds", 6)

local serverRoot = ServerScriptService:WaitForChild("NeoTokyoRacers")
local racingServices = ensureFolder(ensureFolder(serverRoot, "Services"), "Racing")
local bindings = ensureFolder(racingServices, "RacePersonalBestBindings")
local recordBinding = ensureBindableFunction(bindings, "RecordTimeTrialBest")
local getBinding = ensureBindableFunction(bindings, "GetTimeTrialBest")
local saveBinding = ensureBindableFunction(bindings, "SavePlayer")

local sessions = {}
local shuttingDown = false

local function boolValue(name, fallback)
	local item = configRoot:FindFirstChild(name)
	if item and item:IsA("BoolValue") then
		return item.Value
	end
	return fallback
end

local function stringValue(name, fallback)
	local item = configRoot:FindFirstChild(name)
	if item and item:IsA("StringValue") then
		return item.Value
	end
	return fallback
end

local function numberValue(name, fallback)
	local item = configRoot:FindFirstChild(name)
	if item and item:IsA("NumberValue") then
		return item.Value
	end
	return fallback
end

local function dataStoreEnabled()
	return boolValue("DataStoreEnabled", false) == true
end

local function dataStoreName()
	return tostring(stringValue("DataStoreName", "NTR_TimeTrialPersonalBests_v1"))
end

local function saveDebounceSeconds()
	return math.max(0, tonumber(numberValue("SaveDebounceSeconds", 6)) or 6)
end

local function playerKey(player)
	return "player_" .. tostring(player.UserId)
end

local function getStore()
	return DataStoreService:GetDataStore(dataStoreName())
end

local function recordKey(eventId, tier)
	return tostring(eventId or "") .. "::" .. string.upper(tostring(tier or ""))
end

local function cleanRecord(record)
	if typeof(record) ~= "table" then return nil end
	local best = tonumber(record.BestSeconds)
	if not best or best <= 0 or best > 86400 then
		return nil
	end
	return {
		BestSeconds = best,
		BestMedal = tostring(record.BestMedal or record.Medal or "Finished"),
		BestVehicleId = tostring(record.BestVehicleId or ""),
		BestVehicleTier = tostring(record.BestVehicleTier or ""),
		BestVehicleIndex = tonumber(record.BestVehicleIndex) or 0,
		EventId = tostring(record.EventId or ""),
		RouteId = tostring(record.RouteId or ""),
		DisplayName = tostring(record.DisplayName or ""),
		UpdatedUnix = tonumber(record.UpdatedUnix) or os.time(),
	}
end

local function cleanRecords(data)
	local source = typeof(data) == "table" and (data.Records or data) or {}
	local records = {}
	for key, record in pairs(source) do
		if typeof(key) == "string" then
			local clean = cleanRecord(record)
			if clean then
				records[key] = clean
			end
		end
	end
	return records
end

local function sessionFor(player)
	if not player then return nil end
	local session = sessions[player]
	if not session then
		session = {
			Records = {},
			Loaded = false,
			Dirty = false,
			LastSaveAttempt = 0,
			LastSaveUnix = 0,
			LastError = "",
		}
		sessions[player] = session
	end
	return session
end

local function loadPlayer(player)
	local session = sessionFor(player)
	if session.Loaded then
		return true
	end
	session.Loaded = true
	player:SetAttribute("NTR_TimeTrialPBLoaded", true)
	player:SetAttribute("NTR_TimeTrialPBDataStoreEnabled", dataStoreEnabled())

	if not dataStoreEnabled() then
		info("Loaded session-only PB cache for " .. player.Name)
		return true
	end
	if tonumber(player.UserId) == nil or player.UserId <= 0 then
		session.LastError = "DataStore skipped for non-production UserId."
		player:SetAttribute("NTR_TimeTrialPBLastError", session.LastError)
		warnLine(session.LastError .. " player=" .. player.Name .. " userId=" .. tostring(player.UserId))
		return false
	end

	local ok, result = pcall(function()
		return getStore():GetAsync(playerKey(player))
	end)
	if ok then
		session.Records = cleanRecords(result)
		info("Loaded " .. tostring(#(result and result.Records or {})) .. " raw PB records for " .. player.Name)
		return true
	end
	session.LastError = "Load failed: " .. tostring(result)
	player:SetAttribute("NTR_TimeTrialPBLastError", session.LastError)
	warnLine(session.LastError)
	return false
end

local function encodedRecords(session)
	local records = {}
	for key, record in pairs(session and session.Records or {}) do
		local clean = cleanRecord(record)
		if clean then
			records[key] = clean
		end
	end
	return {
		Version = 1,
		UpdatedUnix = os.time(),
		Records = records,
	}
end

local function savePlayer(player, force)
	local session = sessionFor(player)
	if not session then
		return false, "No PB session."
	end
	if not session.Dirty and force ~= true then
		return true, "No PB changes."
	end
	local now = os.clock()
	if force ~= true and now - (session.LastSaveAttempt or 0) < saveDebounceSeconds() then
		return true, "PB save debounce active."
	end
	session.LastSaveAttempt = now

	if not dataStoreEnabled() then
		session.LastSaveUnix = os.time()
		session.LastError = "DataStore disabled; PB session-only."
		player:SetAttribute("NTR_TimeTrialPBLastSaveUnix", session.LastSaveUnix)
		player:SetAttribute("NTR_TimeTrialPBLastError", session.LastError)
		return true, session.LastError
	end
	if tonumber(player.UserId) == nil or player.UserId <= 0 then
		session.LastError = "DataStore skipped for non-production UserId."
		player:SetAttribute("NTR_TimeTrialPBLastError", session.LastError)
		return false, session.LastError
	end

	local encoded = encodedRecords(session)
	local ok, result = pcall(function()
		return getStore():UpdateAsync(playerKey(player), function()
			return encoded
		end)
	end)
	if ok then
		session.Dirty = false
		session.LastSaveUnix = os.time()
		session.LastError = ""
		player:SetAttribute("NTR_TimeTrialPBLastSaveUnix", session.LastSaveUnix)
		player:SetAttribute("NTR_TimeTrialPBLastError", "")
		return true, "Saved PBs."
	end
	session.LastError = "Save failed: " .. tostring(result)
	player:SetAttribute("NTR_TimeTrialPBLastError", session.LastError)
	warnLine(session.LastError)
	return false, session.LastError
end

local function getBest(player, payload)
	loadPlayer(player)
	local session = sessionFor(player)
	local key = recordKey(payload and payload.EventId, payload and payload.VehicleTier)
	local record = cleanRecord(session.Records[key])
	return {
		Ok = true,
		Found = record ~= nil,
		Key = key,
		Record = record,
		BestSeconds = record and record.BestSeconds or nil,
		BestMedal = record and record.BestMedal or nil,
		DataStoreEnabled = dataStoreEnabled(),
	}
end

local function recordBest(player, payload)
	payload = typeof(payload) == "table" and payload or {}
	loadPlayer(player)
	local session = sessionFor(player)
	local key = recordKey(payload.EventId, payload.VehicleTier)
	if key == "::" then
		return { Ok = false, Message = "Missing event/tier for PB." }
	end
	local elapsed = tonumber(payload.Elapsed)
	if not elapsed or elapsed <= 0 or elapsed > 86400 then
		return { Ok = false, Message = "Invalid time-trial elapsed for PB." }
	end

	local previous = cleanRecord(session.Records[key])
	local previousBest = previous and previous.BestSeconds or nil
	local isPersonalBest = previousBest == nil or elapsed < previousBest
	if isPersonalBest then
		session.Records[key] = {
			BestSeconds = elapsed,
			BestMedal = tostring(payload.Medal or "Finished"),
			BestVehicleId = tostring(payload.SelectedVehicleId or ""),
			BestVehicleTier = tostring(payload.VehicleTier or ""),
			BestVehicleIndex = tonumber(payload.VehicleIndex) or 0,
			EventId = tostring(payload.EventId or ""),
			RouteId = tostring(payload.RouteId or ""),
			DisplayName = tostring(payload.DisplayName or ""),
			UpdatedUnix = os.time(),
		}
		session.Dirty = true
		task.spawn(function()
			if not shuttingDown and player and player.Parent then
				savePlayer(player, false)
			end
		end)
	end

	local current = cleanRecord(session.Records[key]) or previous
	return {
		Ok = true,
		Key = key,
		IsPersonalBest = isPersonalBest,
		PreviousBestSeconds = previousBest,
		PersonalBestSeconds = current and current.BestSeconds or elapsed,
		PersonalBestMedal = current and current.BestMedal or tostring(payload.Medal or "Finished"),
		PersonalBestVehicleId = current and current.BestVehicleId or tostring(payload.SelectedVehicleId or ""),
		DataStoreEnabled = dataStoreEnabled(),
		Message = isPersonalBest and "New persistent personal best." or "Existing personal best kept.",
	}
end

recordBinding.OnInvoke = function(player, payload)
	if not (player and player:IsA("Player")) then
		return { Ok = false, Message = "Player missing." }
	end
	local ok, result = pcall(function()
		return recordBest(player, payload)
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Message = "PB record failed: " .. tostring(result) }
end

getBinding.OnInvoke = function(player, payload)
	if not (player and player:IsA("Player")) then
		return { Ok = false, Message = "Player missing." }
	end
	local ok, result = pcall(function()
		return getBest(player, payload)
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Message = "PB get failed: " .. tostring(result) }
end

saveBinding.OnInvoke = function(player, force)
	if not (player and player:IsA("Player")) then
		return { Ok = false, Message = "Player missing." }
	end
	local ok, message = savePlayer(player, force == true)
	return { Ok = ok == true, Success = ok == true, Message = message }
end

Players.PlayerAdded:Connect(function(player)
	task.defer(loadPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player, true)
	sessions[player] = nil
end)

game:BindToClose(function()
	shuttingDown = true
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player, true)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(loadPlayer, player)
end

info("Personal best service active. DataStoreEnabled=" .. tostring(dataStoreEnabled()))
