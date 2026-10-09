--!strict
-- Single server gate for live-tunable features. Resolution order:
--   1. Studio only: ServerStorage.Config attribute "Flag_<Key>" (local testing override)
--   2. Creator Dashboard configs (ConfigService snapshot, refreshed in the background)
--   3. The caller's default
-- Reads never yield; the snapshot is fetched on a background thread and a fetch failure keeps defaults.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local FeatureFlags = {}
local snapshot: any = nil
local started = false
local REFRESH_SECONDS = 60
-- Per-snapshot memo: ConfigService logs a message for every lookup of an unset key, so each key is read at
-- most once per refresh (MISSING marks keys the dashboard does not define).
local MISSING = {}
local memo: { [string]: any } = {}

local function refresh()
	local ok, result = pcall(function()
		return game:GetService("ConfigService"):GetConfigAsync()
	end)
	if ok and result then snapshot = result; memo = {} end
end

local function ensureStarted()
	if started or not RunService:IsRunning() then return end
	started = true
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

function FeatureFlags.Get(key: string, default: any): any
	ensureStarted()
	if RunService:IsStudio() then
		local config = ServerStorage:FindFirstChild("Config")
		local override = config and config:GetAttribute("Flag_" .. key)
		if override ~= nil then return override end
	end
	if snapshot then
		local value = memo[key]
		if value == nil then
			local ok, result = pcall(function() return snapshot:GetValue(key) end)
			value = (ok and result ~= nil) and result or MISSING
			memo[key] = value
		end
		if value ~= MISSING then return value end
	end
	return default
end

function FeatureFlags.IsEnabled(key: string, default: boolean): boolean
	return FeatureFlags.Get(key, default) == true
end

return FeatureFlags
