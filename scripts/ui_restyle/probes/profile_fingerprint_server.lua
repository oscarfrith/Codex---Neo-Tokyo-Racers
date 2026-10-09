-- UI restyle probe: profile_fingerprint_server (datamodel: Server, Play). READ-ONLY.
-- A before/after fingerprint of one player's profile for agent test sessions (plan section 10).
-- Level 1 (always): only reads what the running game already publishes on the server:
--   leaderstats, Player attributes, ServerStorage.Runtime.Player.RuntimeProfiles.<UserId>
--   (ProfileServer.updateRuntimeMarker, lines 156-176), persistence / PB / leaderboard config,
--   the sandbox attributes, spawned vehicles, ServerBase.StartupState.
-- Level 2 (ARGS.invokeBindings = true, off by default): additionally INVOKES two existing
--   read-only BindableFunctions of the running services. No module is required and no remote
--   is fired:
--     ProfileServiceBindings.GetProfile      -> Compatibility.persistent(session.Profile), a shallow
--                                               copy (ProfileServer 460-463); the Bindable copies it again
--     RacePersonalBestBindings.GetTimeTrialBest -> reads the PB session (PersonalBestServer 276-290)
--   GetSummary is deliberately NOT called (it runs schema.Normalize on the live profile).
-- Never writes attributes, never calls MarkDirty / SaveNow / Record*.
local ARGS = {
	label = "",            -- e.g. "before session 3"
	userName = nil,        -- nil = the first player in the server
	invokeBindings = false, -- true = level 2 (owned vehicle ids, module counts, section hashes, PBs)
	pbKeys = {},           -- level 2: { {EventId = "shifted_canal_sprint_tt", VehicleTier = "E"}, ... }
	detail = false,        -- true = list every vehicle id / per-vehicle table counts (level 2)
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsServer() or not RunService:IsRunning() then
	return HttpService:JSONEncode({ probe = "profile_fingerprint_server", ok = false, error = "run on the Server datamodel during Play" })
end

local player = nil
for _, candidate in ipairs(Players:GetPlayers()) do
	if ARGS.userName == nil or candidate.Name == ARGS.userName then
		player = candidate
		break
	end
end
if not player then
	return HttpService:JSONEncode({ probe = "profile_fingerprint_server", ok = false, error = "player not found" })
end

local function find(root, ...)
	local item = root
	for _, name in ipairs({ ... }) do
		item = item and item:FindFirstChild(name)
	end
	return item
end

local function scalarAttributes(item, limit)
	local out = {}
	if not item then
		return out
	end
	local names = {}
	for name in pairs(item:GetAttributes()) do
		table.insert(names, name)
	end
	table.sort(names)
	for index, name in ipairs(names) do
		if limit and index > limit then
			break
		end
		local value = item:GetAttribute(name)
		local kind = type(value)
		if kind == "boolean" or kind == "number" then
			out[name] = value
		elseif kind == "string" then
			out[name] = string.sub(value, 1, 64)
		else
			out[name] = "<" .. typeof(value) .. ">"
		end
	end
	return out
end

local function valueChildren(item)
	local out = {}
	if not item then
		return out
	end
	for _, child in ipairs(item:GetChildren()) do
		if child:IsA("ValueBase") then
			local value = child.Value
			local kind = type(value)
			out[child.Name] = (kind == "boolean" or kind == "number" or kind == "string") and value or tostring(value)
		end
	end
	return out
end

-- FNV-1a 32 with exact double arithmetic.
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

-- Canonical text of a value: sorted keys, %.6g numbers, Color3 as hex.
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
	elseif kind == "Color3" then
		table.insert(out, string.format("#%02x%02x%02x", math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5)))
	elseif kind == "string" or kind == "boolean" or kind == "nil" then
		table.insert(out, tostring(value))
	else
		table.insert(out, "<" .. kind .. ">")
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

local result = {
	probe = "profile_fingerprint_server", ok = true, label = ARGS.label, level = ARGS.invokeBindings and 2 or 1,
	player = player.Name, userId = player.UserId, isStudio = RunService:IsStudio(), unixTime = os.time(),
}

-- Level 1 -------------------------------------------------------------------------------------
local leaderstats = {}
local stats = player:FindFirstChild("leaderstats")
if stats then
	for _, child in ipairs(stats:GetChildren()) do
		if child:IsA("ValueBase") then
			leaderstats[child.Name] = child.Value
		end
	end
end
result.leaderstats = leaderstats
result.cash = leaderstats.Cash

local attributes = scalarAttributes(player)
result.playerAttributes = attributes
result.sandboxActive = attributes.StudioVehicleSandboxActive == true
result.profileLoaded = attributes.ProfileServiceLoaded == true

local marker = find(ServerStorage, "Runtime", "Player", "RuntimeProfiles", tostring(player.UserId))
result.runtimeProfileMarker = marker and scalarAttributes(marker) or nil

result.config = {
	persistence = scalarAttributes(find(ServerStorage, "Config", "Player", "Persistence")),
	personalBests = valueChildren(find(ServerStorage, "Config", "Racing", "PersonalBests")),
	leaderboards = valueChildren(find(ServerStorage, "Config", "Racing", "Leaderboards")),
	startingCash = ReplicatedStorage:GetAttribute("StartingCash"),
}
local onboarding = find(ReplicatedStorage, "Config", "Player", "Onboarding")
if onboarding then
	result.config.onboarding = {
		StudioVehicleSandboxEveryPlay = onboarding:GetAttribute("StudioVehicleSandboxEveryPlay"),
		StudioReplayEveryPlay = onboarding:GetAttribute("StudioReplayEveryPlay"),
		StudioVehicleSandboxCash = onboarding:GetAttribute("StudioVehicleSandboxCash"),
		UIRestyleTestWindow = onboarding:GetAttribute("UIRestyleTestWindow"),
	}
end

local vehicles = {}
local vehicleFolder = find(workspace, "World", "Runtime", "PlayerVehicles")
if vehicleFolder then
	for _, model in ipairs(vehicleFolder:GetChildren()) do
		if tonumber(model:GetAttribute("OwnerUserId")) == player.UserId then
			table.insert(vehicles, { name = model.Name, attributes = scalarAttributes(model, ARGS.detail and 40 or 14) })
		end
	end
end
result.spawnedVehicles = vehicles

local startup = { found = false, counts = {}, notReady = {} }
local startupFolder = find(ServerScriptService, "ServerBase", "StartupState")
if startupFolder then
	startup.found = true
	for name, status in pairs(startupFolder:GetAttributes()) do
		local text = tostring(status)
		startup.counts[text] = (startup.counts[text] or 0) + 1
		if text ~= "ready" then
			startup.notReady[name] = text
		end
	end
end
result.serverStartupState = startup

-- Level 2 -------------------------------------------------------------------------------------
if ARGS.invokeBindings then
	local level2 = {}
	local getProfile = find(ServerStorage, "Runtime", "Player", "ProfileServiceBindings", "GetProfile")
	if getProfile and getProfile:IsA("BindableFunction") then
		local ok, profile = pcall(function()
			return getProfile:Invoke(player)
		end)
		if ok and type(profile) == "table" then
			level2.profileFound = true
			level2.cash = profile.Cash
			level2.currentVehicleId = profile.CurrentVehicleId
			level2.schemaVersion = profile.SchemaVersion
			local okSections, sectionError = pcall(function()
				local sections = {}
				local names = {}
				for key in pairs(profile) do
					table.insert(names, tostring(key))
				end
				table.sort(names)
				for _, key in ipairs(names) do
					local value = profile[key]
					sections[key] = { hash = hashOf(value), count = type(value) == "table" and countOf(value) or nil }
				end
				level2.sections = sections
				level2.profileHash = hashOf(profile)
			end)
			if not okSections then
				level2.sectionError = tostring(sectionError)
			end
			pcall(function()
				local ids = {}
				for id in pairs(type(profile.Vehicles) == "table" and profile.Vehicles or {}) do
					table.insert(ids, tostring(id))
				end
				table.sort(ids)
				level2.vehicleCount = #ids
				level2.vehicleIdsHash = fnv(table.concat(ids, ","))
				level2.cockpitInstanceCount = countOf(profile.OwnedCockpitInstances)
				level2.moduleInstanceCount = countOf(profile.OwnedModuleInstances)
				level2.decorationKindCount = countOf(profile.OwnedDecorations)
				level2.garageCapacity = type(profile.Garage) == "table" and profile.Garage.Capacity or nil
				level2.garagePropertyCount = type(profile.Garage) == "table" and countOf(profile.Garage.OwnedGarageProperties) or nil
				level2.progression = type(profile.Progression) == "table" and { Rank = profile.Progression.Rank, Xp = profile.Progression.Xp, LifetimeXp = profile.Progression.LifetimeXp } or nil
				if type(profile.Onboarding) == "table" then
					local completed, seen = {}, {}
					for key, value in pairs(type(profile.Onboarding.Completed) == "table" and profile.Onboarding.Completed or {}) do
						if value == true then
							table.insert(completed, tostring(key))
						end
					end
					for key, value in pairs(type(profile.Onboarding.SeenPages) == "table" and profile.Onboarding.SeenPages or {}) do
						if value == true then
							table.insert(seen, tostring(key))
						end
					end
					table.sort(completed)
					table.sort(seen)
					level2.onboarding = { completed = completed, seenPages = seen }
				end
				if ARGS.detail then
					local list = {}
					for index, id in ipairs(ids) do
						if index > 60 then
							level2.vehiclesTruncated = true
							break
						end
						local vehicle = profile.Vehicles[id]
						local row = { id = id, hash = hashOf(vehicle), tables = {} }
						if type(vehicle) == "table" then
							for key, value in pairs(vehicle) do
								if type(value) == "table" then
									row.tables[tostring(key)] = countOf(value)
								end
							end
						end
						table.insert(list, row)
					end
					level2.vehicles = list
				end
			end)
		else
			level2.profileFound = false
			level2.profileError = ok and "GetProfile returned no table (profile not loaded?)" or tostring(profile)
		end
	else
		level2.profileError = "ProfileServiceBindings.GetProfile not found"
	end

	local getBest = find(ServerStorage, "Runtime", "Racing", "RacePersonalBestBindings", "GetTimeTrialBest")
	local bests = {}
	if getBest and getBest:IsA("BindableFunction") then
		for index, key in ipairs(ARGS.pbKeys or {}) do
			if index > 40 then
				break
			end
			local ok, reply = pcall(function()
				return getBest:Invoke(player, { EventId = key.EventId, VehicleTier = key.VehicleTier })
			end)
			if ok and type(reply) == "table" then
				table.insert(bests, { key = reply.Key, found = reply.Found == true, bestSeconds = reply.BestSeconds, medal = reply.BestMedal, dataStoreEnabled = reply.DataStoreEnabled })
			else
				table.insert(bests, { key = tostring(key.EventId) .. "::" .. tostring(key.VehicleTier), error = tostring(reply) })
			end
		end
	else
		level2.personalBestError = "RacePersonalBestBindings.GetTimeTrialBest not found"
	end
	level2.personalBests = bests
	result.level2 = level2
end

-- One number to compare before / after. Volatile session fields are left out on purpose.
local stable = {
	cash = result.cash,
	marker = marker and {
		VehicleCount = marker:GetAttribute("VehicleCount"), ModuleInstanceCount = marker:GetAttribute("ModuleInstanceCount"),
		GarageCapacity = marker:GetAttribute("GarageCapacity"), SchemaVersion = marker:GetAttribute("SchemaVersion"),
	} or nil,
	rank = attributes.Rank, xpIntoRank = attributes.XpIntoRank, onboardingStage = attributes.OnboardingStage,
	deskObjective = attributes.DealershipIntroObjectiveComplete,
	profileHash = result.level2 and result.level2.profileHash or nil,
	personalBests = result.level2 and result.level2.personalBests or nil,
}
result.fingerprint = hashOf(stable)
result.fingerprintInputs = stable

result.notObservable = {
	"Level 1 cannot see owned vehicle ids, per-vehicle modules, paint, owned-garage contents or onboarding SeenPages: only counts on the runtime marker",
	"Personal bests are published nowhere; level 2 reads only the event/tier keys listed in ARGS.pbKeys",
	"What is in the DataStores themselves (saved profile, saved PBs, desk objective, global leaderboard) is never read: this is the in-memory session, which under the sandbox is NOT what is saved",
	"Dirty / LastSaveUnix on the runtime marker refresh only when the profile is next marked dirty or saved",
}

return HttpService:JSONEncode(result)
