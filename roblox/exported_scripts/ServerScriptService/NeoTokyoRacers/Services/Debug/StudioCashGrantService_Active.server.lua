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
