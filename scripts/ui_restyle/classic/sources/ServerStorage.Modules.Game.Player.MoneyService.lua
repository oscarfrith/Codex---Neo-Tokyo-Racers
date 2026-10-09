--!strict
-- Single debit point for spending Cash on the authoritative in-session profile table. Callers keep their
-- own affordability messages and transaction order; Debit refuses invalid amounts (NaN, negative, infinite)
-- or insufficient funds by erroring, so a bad price can never corrupt or inflate a balance. Credits stay
-- with Player.EconomyServer (idempotent commands). This module never saves: ProfileServer owns persistence.
local MoneyService = {}
local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Signal"))
-- Fired after every successful debit: (profile, amount, reason, newBalance). Used by analytics.
MoneyService.Debited = Signal.new()

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function balance(profile: any): number
	local cash = tonumber(profile.Cash) or 0
	if not finite(cash) then error("[MoneyService] profile Cash is not finite") end
	return cash
end

-- Bounded recent ledger for low-cost diagnostics (no player data beyond reason/amount/time).
local ledger: { any } = {}
local LEDGER_LIMIT = 50

function MoneyService.Balance(profile: any): number
	return balance(profile)
end

function MoneyService.CanAfford(profile: any, amount: number): boolean
	return finite(amount) and amount >= 0 and balance(profile) >= amount
end

-- Deducts amount; returns the new balance. Errors (never partially applies) on invalid input.
function MoneyService.Debit(profile: any, amount: number, reason: string): number
	assert(type(profile) == "table", "[MoneyService] profile required")
	assert(type(reason) == "string" and reason ~= "", "[MoneyService] reason required")
	if not finite(amount) or amount < 0 then error("[MoneyService] invalid debit amount for " .. reason .. ": " .. tostring(amount)) end
	local cash = balance(profile)
	if cash < amount then error("[MoneyService] insufficient funds for " .. reason) end
	profile.Cash = cash - amount
	table.insert(ledger, { Reason = reason, Amount = amount, At = os.time() })
	if #ledger > LEDGER_LIMIT then table.remove(ledger, 1) end
	MoneyService.Debited:Fire(profile, amount, reason, profile.Cash)
	return profile.Cash
end

-- Returns cash taken by a Debit whose surrounding transaction failed before commit.
function MoneyService.Refund(profile: any, amount: number, reason: string): number
	if not finite(amount) or amount < 0 then error("[MoneyService] invalid refund amount for " .. tostring(reason)) end
	profile.Cash = balance(profile) + amount
	return profile.Cash
end

function MoneyService.RecentLedger(): { any }
	return table.clone(ledger)
end

return MoneyService
