-- UI restyle probe: profile_fingerprint_client (datamodel: Client, Play). READ-ONLY.
-- The client-side view of the profile: only what replicates to the player. Fires no remote
-- (GarageInvoke GetInitial would give more, but it is a remote and is not used here).
-- Weaker than profile_fingerprint_server.lua; use it when only the Client datamodel is at hand,
-- or beside the server one to confirm the HUD shows what the server holds.
local ARGS = {
	label = "",
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if not player then
	return HttpService:JSONEncode({ probe = "profile_fingerprint_client", ok = false, error = "no LocalPlayer (run on the Client datamodel in Play)" })
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

local result = { probe = "profile_fingerprint_client", ok = true, label = ARGS.label, player = player.Name, userId = player.UserId }

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

local attributes = {}
for name, value in pairs(player:GetAttributes()) do
	local kind = type(value)
	if kind == "boolean" or kind == "number" then
		attributes[name] = value
	elseif kind == "string" then
		attributes[name] = string.sub(value, 1, 64)
	end
end
result.playerAttributes = attributes
result.sandboxActive = attributes.StudioVehicleSandboxActive == true

-- Owned vehicle ids as the Classic HUD lists them: cards named "Vehicle_<VehicleId>" in the
-- car panel (DesktopFreeRoamHudUI 743-749). Present only once the HUD has built its list.
local vehicleIds = {}
local carPanelFound = false
pcall(function()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("DesktopFreeRoamHud")
	local designRoot = hud and hud:FindFirstChild("DesignRoot")
	local carPanel = designRoot and designRoot:FindFirstChild("CarPanel")
	if carPanel then
		carPanelFound = true
		for _, item in ipairs(carPanel:GetDescendants()) do
			local id = string.match(item.Name, "^Vehicle_(.+)$")
			if id and item:IsA("GuiObject") then
				table.insert(vehicleIds, id)
			end
		end
	end
end)
table.sort(vehicleIds)
result.hudCarPanelFound = carPanelFound
result.hudVehicleCount = #vehicleIds
result.hudVehicleIdsHash = fnv(table.concat(vehicleIds, ","))
if #vehicleIds <= 40 then
	result.hudVehicleIds = vehicleIds
end

local onboarding = nil
pcall(function()
	onboarding = ReplicatedStorage:FindFirstChild("Config"):FindFirstChild("Player"):FindFirstChild("Onboarding")
end)
if onboarding then
	result.onboardingConfig = {
		StudioVehicleSandboxEveryPlay = onboarding:GetAttribute("StudioVehicleSandboxEveryPlay"),
		StudioReplayEveryPlay = onboarding:GetAttribute("StudioReplayEveryPlay"),
		UIRestyleTestWindow = onboarding:GetAttribute("UIRestyleTestWindow"),
	}
end

local stable = table.concat({
	tostring(result.cash), tostring(attributes.Rank), tostring(attributes.XpIntoRank), tostring(attributes.OnboardingStage),
	tostring(attributes.DealershipIntroObjectiveComplete), tostring(result.hudVehicleCount), tostring(result.hudVehicleIdsHash),
}, "|")
result.fingerprint = fnv(stable)
result.fingerprintInputs = stable

result.notObservable = {
	"module instances, upgrades, paint, owned-garage contents, onboarding SeenPages and personal bests do not replicate; use profile_fingerprint_server.lua level 2",
	"hudVehicleIds is the HUD's own list: empty until the car panel has been built, and generated ids differ on every sandbox Play",
}

return HttpService:JSONEncode(result)
