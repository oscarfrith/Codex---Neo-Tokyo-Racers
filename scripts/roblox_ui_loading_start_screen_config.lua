-- Neo Tokyo Racers - Loading/Start Screen Config V2
-- Config-only companion transaction for the canonical loading installer.
-- Run once in Roblox Studio Command Bar while in Edit mode, before running
-- scripts/roblox_ui_loading_and_start_screen_system.lua.

local MODE = "INSTALL" -- INSTALL or AUDIT

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
assert(not RunService:IsRunning(), "Run this config installer in Studio Edit mode.")

local config = assert(
	ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
		and ReplicatedStorage.NeoTokyoRacers:FindFirstChild("Config")
		and ReplicatedStorage.NeoTokyoRacers.Config:FindFirstChild("UI")
		and ReplicatedStorage.NeoTokyoRacers.Config.UI:FindFirstChild("LoadingSystem"),
	"ReplicatedStorage.NeoTokyoRacers.Config.UI.LoadingSystem missing"
)
assert(config:IsA("Folder"), "LoadingSystem must be a Folder")

local defaults = {
	StartScreenPlayIconAssetId = "",
	StartScreenShopIconAssetId = "",
	GridPreloadAttempts = 2,
	GridPreloadRetrySeconds = 0.25,
	GridPromotionWaitSeconds = 3,
	StartScreenButtonYScaleDesktop = 0.82,
	StartScreenButtonYScaleLandscapePhone = 0.84,
	StartScreenButtonYScalePortrait = 0.80,
}

local expectedTypes = {
	StartScreenPlayIconAssetId = "string",
	StartScreenShopIconAssetId = "string",
	GridPreloadAttempts = "number",
	GridPreloadRetrySeconds = "number",
	GridPromotionWaitSeconds = "number",
	StartScreenButtonYScaleDesktop = "number",
	StartScreenButtonYScaleLandscapePhone = "number",
	StartScreenButtonYScalePortrait = "number",
}

local function audit()
	for name, expectedType in pairs(expectedTypes) do
		local value = config:GetAttribute(name)
		assert(value ~= nil, name .. " missing")
		assert(typeof(value) == expectedType, name .. " must be " .. expectedType)
	end
	assert(config:GetAttribute("GridPreloadAttempts") >= 1, "GridPreloadAttempts must be at least 1")
	assert(config:GetAttribute("GridPreloadRetrySeconds") >= 0, "GridPreloadRetrySeconds must be non-negative")
	assert(config:GetAttribute("GridPromotionWaitSeconds") >= 0.25, "GridPromotionWaitSeconds must be at least 0.25")
	for _, name in ipairs({ "StartScreenButtonYScaleDesktop", "StartScreenButtonYScaleLandscapePhone", "StartScreenButtonYScalePortrait" }) do
		local value = config:GetAttribute(name)
		assert(value >= 0.5 and value <= 0.95, name .. " must be between 0.5 and 0.95")
	end
end

if MODE == "AUDIT" then
	audit()
	print("[NTR Loading Config] AUDIT PASS: icon, grid-promotion and responsive button-position attributes are present. No Studio objects changed.")
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local added = {}
local ok, problem = xpcall(function()
	for name, defaultValue in pairs(defaults) do
		local current = config:GetAttribute(name)
		if current == nil then
			config:SetAttribute(name, defaultValue)
			table.insert(added, name)
		else
			assert(typeof(current) == expectedTypes[name], name .. " has incompatible type")
		end
	end
	audit()
end, debug.traceback)

if not ok then
	for _, name in ipairs(added) do
		pcall(function() config:SetAttribute(name, nil) end)
	end
	error("[NTR Loading Config] rolled back: " .. tostring(problem), 0)
end

print("[NTR Loading Config] PASS: icon, grid-promotion and responsive start-button position attributes installed without changing existing values.")
print("Set StartScreenPlayIconAssetId and StartScreenShopIconAssetId to numeric IDs or rbxassetid:// values when ready.")
print("Start-button Y defaults: Desktop=0.82, LandscapePhone=0.84, Portrait=0.80. Higher values move the buttons down.")
