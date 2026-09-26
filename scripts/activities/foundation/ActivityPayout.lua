-- Canonical feature implementation; used by activity services (no startup of its own).
-- The only Cash/XP path for Street Life activities. Grants go through EconomyServer GrantCash with a
-- unique CommandId (idempotent within the session); spends go through MoneyService.Debit after the
-- caller has finished all validation. Job payouts share a rolling hourly ceiling per player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local modules = ServerStorage:WaitForChild("Modules")
local ProfileServer = require(modules:WaitForChild("Game"):WaitForChild("Player"):WaitForChild("ProfileServer"))
local MoneyService = require(modules.Game.Player:WaitForChild("MoneyService"))
local ProgressionService = require(modules.Game:WaitForChild("Activities"):WaitForChild("ProgressionService"))

local coreConfig = ReplicatedStorage:WaitForChild("Config"):WaitForChild("Activities"):WaitForChild("Core")

local Payout = {}

local REASONS = { JobPayout = true, TaxiFare = true, DuelPot = true, DuelRefund = true }
local CEILING_WINDOW = 3600
local ledger = {} -- [player] = { { Time, Amount } }
local paid = {} -- [player] = { [CommandId] = result }
local executeEconomy

local function economy()
	if not executeEconomy then
		executeEconomy = ServerStorage:WaitForChild("Runtime"):WaitForChild("Player"):WaitForChild("ProfileServiceBindings"):WaitForChild("ExecuteEconomyCommand")
	end
	return executeEconomy
end

local function ceilingRemaining(player)
	local ceiling = math.max(0, tonumber(coreConfig:GetAttribute("JobHourlyCashCeiling")) or 40000)
	local now = os.clock()
	local rows, used = ledger[player] or {}, 0
	for i = #rows, 1, -1 do
		if now - rows[i].Time > CEILING_WINDOW then table.remove(rows, i) else used += rows[i].Amount end
	end
	ledger[player] = rows
	return math.max(0, ceiling - used)
end

local function syncLeaderstats(player, cash)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Cash")
	if value and value:IsA("ValueBase") then value.Value = cash end
end

-- spec: { Cash, Xp, Reason, CommandId, Label, JobCeiling }. May yield (economy command). Idempotent per CommandId.
function Payout.Pay(player, spec)
	assert(type(spec) == "table" and REASONS[spec.Reason], "ActivityPayout.Pay needs an allowed Reason")
	assert(type(spec.CommandId) == "string" and spec.CommandId ~= "" and #spec.CommandId <= 200, "ActivityPayout.Pay needs a CommandId")
	if typeof(player) ~= "Instance" or player.Parent ~= Players then return { Ok = false, Cash = 0, Xp = 0, Capped = false, Message = "Player left." } end
	paid[player] = paid[player] or {}
	if paid[player][spec.CommandId] then return paid[player][spec.CommandId] end
	local result = { Ok = true, Cash = 0, Xp = 0, Capped = false }
	paid[player][spec.CommandId] = result
	local cash = math.max(0, math.floor(tonumber(spec.Cash) or 0))
	local reservation
	if cash > 0 and spec.JobCeiling then
		local remaining = ceilingRemaining(player)
		if cash > remaining then cash, result.Capped = remaining, true end
		-- Reserve before the yielding grant so concurrent payouts cannot both pass the ceiling (session-scoped).
		reservation = { Time = os.clock(), Amount = cash }
		table.insert(ledger[player], reservation)
	end
	if cash > 0 then
		local granted = false
		for attempt = 1, 4 do
			local ok, reply = pcall(function()
				return economy():Invoke(player, { Version = 1, Action = "GrantCash", Amount = cash, Reason = spec.Reason, CommandId = spec.CommandId })
			end)
			if ok and type(reply) == "table" and (reply.Ok or reply.Success) then
				result.Cash = tonumber(reply.Amount) or cash
				granted = true
				break
			end
			local busy = ok and type(reply) == "table" and reply.RejectionReason == "Busy"
			if not busy or attempt == 4 then
				result.Ok = false
				result.Message = ok and type(reply) == "table" and tostring(reply.RejectionReason or reply.Message) or tostring(reply)
				break
			end
			task.wait(0.2 * attempt)
			if player.Parent ~= Players then result.Ok = false; result.Message = "Player left."; break end
		end
		if reservation then reservation.Amount = granted and result.Cash or 0 end
		if not granted then
			if paid[player] then paid[player][spec.CommandId] = nil end -- allow a retry with the same CommandId
			warn("[ActivityPayout] " .. spec.CommandId .. " cash not granted: " .. tostring(result.Message))
			return result -- no XP without the Cash, so a retry pays both
		end
	end
	local xp = math.max(0, math.floor(tonumber(spec.Xp) or 0))
	if xp > 0 then
		local applied = ProgressionService.AddXp(player, xp, spec.Reason, spec.CommandId .. ":xp")
		result.Xp = applied.AlreadyApplied and 0 or xp
	end
	return result
end

function Payout.CanAfford(player, amount)
	local profile = ProfileServer.get_profile(player)
	return profile ~= nil and MoneyService.CanAfford(profile, math.max(0, tonumber(amount) or 0))
end

-- Validate everything before calling. Does not yield.
function Payout.Debit(player, amount, reason)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return true end
	local profile = ProfileServer.get_profile(player)
	if not profile then return false, "Profile is not loaded." end
	local ok, err = pcall(MoneyService.Debit, profile, amount, tostring(reason))
	if not ok then return false, tostring(err) end
	ProfileServer.mark_dirty(player, profile, "ActivityDebit:" .. tostring(reason))
	syncLeaderstats(player, profile.Cash)
	return true
end

Players.PlayerRemoving:Connect(function(player)
	ledger[player] = nil
	paid[player] = nil
end)

return Payout
