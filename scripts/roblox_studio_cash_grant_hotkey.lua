-- Neo Tokyo Racers - Studio cash grant hotkey
-- Run in Roblox Studio Command Bar in Edit mode, then restart Play.
-- Press = to grant the configured Studio test account $100,000.
-- This helper is hard-disabled outside Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before installing the Studio cash grant hotkey")

local PREFIX = "[NTR Studio Cash Grant]"
local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item then assert(item:IsA("Folder"), item:GetFullName() .. " must be a Folder"); return item end
	item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

local function ensureSource(parent, className, name, source)
	local item = parent:FindFirstChild(name)
	if item then assert(item.ClassName == className, item:GetFullName() .. " must be a " .. className)
	else item = Instance.new(className); item.Name = name; item.Parent = parent end
	item.Source = source
	item.Disabled = false
	return item
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local runtimeConfig = ensureFolder(kit:WaitForChild("Config"), "Runtime")
local config = ensureFolder(runtimeConfig, "StudioCashGrant")
config:SetAttribute("Enabled", true)
config:SetAttribute("Amount", 100000)
config:SetAttribute("KeyCode", "Equals")
config:SetAttribute("AllowedUserName", "LucidityStudios")
config:SetAttribute("CooldownSeconds", 0.5)
config:SetAttribute("StudioOnly", true)
config:SetAttribute("InstalledVersion", "NTR_STUDIO_CASH_GRANT_V1")

local sharedRemotes = ensureFolder(kit:WaitForChild("Shared"), "Remotes")
local debugRemotes = ensureFolder(sharedRemotes, "Debug")
local remote = debugRemotes:FindFirstChild("StudioCashGrantRequest")
if remote then assert(remote:IsA("RemoteEvent"), remote:GetFullName() .. " must be a RemoteEvent")
else remote = Instance.new("RemoteEvent"); remote.Name = "StudioCashGrantRequest"; remote.Parent = debugRemotes end

local serverSource = [==[
-- NTR_STUDIO_CASH_GRANT_SERVER_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("StudioCashGrant")
local remote = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Debug"):WaitForChild("StudioCashGrantRequest")
local lastGrant = {}

local function reply(player, success, message, cash)
	remote:FireClient(player, { Success = success, Message = message, Cash = cash })
end

remote.OnServerEvent:Connect(function(player)
	-- This is intentionally not configurable: published/live servers can never grant cash.
	if not RunService:IsStudio() then return end
	if config:GetAttribute("StudioOnly") ~= true or config:GetAttribute("Enabled") ~= true then
		reply(player, false, "Studio cash grant is disabled.")
		return
	end
	local allowedName = tostring(config:GetAttribute("AllowedUserName") or "")
	if allowedName ~= "" and player.Name ~= allowedName then
		reply(player, false, "This Studio cash key is not enabled for " .. player.Name .. ".")
		return
	end
	local now = os.clock()
	local cooldown = math.max(0.1, tonumber(config:GetAttribute("CooldownSeconds")) or 0.5)
	if now - (lastGrant[player.UserId] or 0) < cooldown then return end
	lastGrant[player.UserId] = now

	local amount = math.max(1, math.floor(tonumber(config:GetAttribute("Amount")) or 100000))
	local services = ServerScriptService:FindFirstChild("NeoTokyoRacers") and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
	local garage = services and services:FindFirstChild("Garage")
	local bindings = garage and garage:FindFirstChild("GarageProfileMutationBindings")
	local grantCash = bindings and bindings:FindFirstChild("GrantCash")
	if not (grantCash and grantCash:IsA("BindableFunction")) then
		reply(player, false, "Garage cash bridge is not ready yet. Try again in a moment.")
		return
	end

	local ok, result = pcall(function()
		return grantCash:Invoke("GrantCash", {
			Player = player,
			Amount = amount,
			Reason = "StudioCashGrantHotkey",
			RunId = "STUDIO_DEBUG",
			EventId = "STUDIO_CASH_GRANT",
		})
	end)
	if not ok or typeof(result) ~= "table" or result.Success ~= true then
		reply(player, false, "Cash grant failed: " .. tostring(ok and result and result.Message or result))
		return
	end
	player:SetAttribute("NTR_LastStudioCashGrant", amount)
	print(string.format("[NTR Studio Cash Grant] Granted %s $%d; balance=$%d", player.Name, amount, tonumber(result.Cash) or 0))
	reply(player, true, "+$" .. tostring(amount) .. " test cash", result.Cash)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastGrant[player.UserId] = nil
end)

print("[NTR Studio Cash Grant] Server ready; live servers remain hard-disabled.")
]==]

local clientSource = [==[
-- NTR_STUDIO_CASH_GRANT_CLIENT_V1
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then return end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("StudioCashGrant")
local remote = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Debug"):WaitForChild("StudioCashGrantRequest")
local ACTION = "NTR_StudioCashGrant"

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 2.5 })
	end)
end

local function bind()
	ContextActionService:UnbindAction(ACTION)
	if config:GetAttribute("Enabled") ~= true then return end
	local keyName = tostring(config:GetAttribute("KeyCode") or "Equals")
	local keyCode = Enum.KeyCode[keyName]
	if not keyCode then
		warn("[NTR Studio Cash Grant] Invalid KeyCode config: " .. keyName)
		return
	end
	ContextActionService:BindAction(ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		remote:FireServer()
		return Enum.ContextActionResult.Sink
	end, false, keyCode)
	print("[NTR Studio Cash Grant] Press " .. keyName .. " for $" .. tostring(config:GetAttribute("Amount") or 100000) .. ".")
end

remote.OnClientEvent:Connect(function(result)
	result = typeof(result) == "table" and result or {}
	notify(result.Success == true and "TEST CASH ADDED" or "TEST CASH FAILED", tostring(result.Message or "No response"))
end)

config:GetAttributeChangedSignal("Enabled"):Connect(bind)
config:GetAttributeChangedSignal("KeyCode"):Connect(bind)
bind()
]==]

local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local debugServices = ensureFolder(services, "Debug")
local server = ensureSource(debugServices, "Script", "StudioCashGrantService_Active", serverSource)

local clientRoot = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient")
local controllers = ensureFolder(clientRoot, "Controllers")
local debugControllers = ensureFolder(controllers, "Debug")
local client = ensureSource(debugControllers, "LocalScript", "StudioCashGrantClient_Active", clientSource)

assert(string.find(server.Source, "NTR_STUDIO_CASH_GRANT_SERVER_V1", 1, true), "Server marker missing")
assert(string.find(server.Source, "if not RunService:IsStudio() then return end", 1, true), "Server Studio-only guard missing")
assert(string.find(client.Source, "NTR_STUDIO_CASH_GRANT_CLIENT_V1", 1, true), "Client marker missing")
assert(config:GetAttribute("Amount") == 100000 and config:GetAttribute("KeyCode") == "Equals", "Config values are incorrect")

print(PREFIX .. " PASS - Installed isolated Studio-only server/client helper.")
print(PREFIX .. " PASS - Amount=$100000, key='=', allowed account=LucidityStudios.")
print(PREFIX .. " PASS - Uses the existing authoritative garage cash/persistence bridge.")
print(PREFIX .. " INSTALL COMPLETE - Restart Play, wait for the garage profile to load, then press '='.")

