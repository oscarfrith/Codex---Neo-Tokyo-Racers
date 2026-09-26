-- Pure tests for GarageVisitRules (Edit; source loaded over loopback, no game module require, no instances).
local Http = game:GetService("HttpService")
local base = "http://127.0.0.1:8767/activities/garage_visits/"
local Rules = assert(loadstring(Http:GetAsync(base .. "GarageVisitRules.lua")))()
local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local OWNER, VISITOR = 1001, 2002
local ON = { Enabled = true, MaxVisitorsPerGarage = 8 }

local function owner(mode, presence, extra)
	local state = { UserId = OWNER, Online = presence ~= "offline", Inside = presence == "inside", PropertyId = "STARTER_TWO_BAY",
		AccessMode = mode, InvitedUserIds = {}, VisitorCount = 0, OwnerName = "Owner", GarageName = "Starter Two-Bay" }
	for key, value in pairs(extra or {}) do state[key] = value end
	return state
end
local function visitor(relation, extra)
	local state = { UserId = VISITOR, FriendOf = {} }
	if relation == "friend" then state.FriendOf[OWNER] = true end
	for key, value in pairs(extra or {}) do state[key] = value end
	return state
end
local function withInvite(ownerState, relation)
	if relation == "invited" then ownerState.InvitedUserIds = { VISITOR } end
	return ownerState
end

-- Full matrix: 4 modes x friend/invited/stranger x owner inside/outside/offline.
local expectedInside = {
	Public = { friend = true, invited = true, stranger = true },
	FriendsOnly = { friend = true, invited = "NotFriend", stranger = "NotFriend" },
	InviteOnly = { friend = "NotInvited", invited = true, stranger = "NotInvited" },
	Private = { friend = "Private", invited = "Private", stranger = "Private" },
}
for _, mode in ipairs(Rules.AccessModes) do
	for _, relation in ipairs({ "friend", "invited", "stranger" }) do
		for _, presence in ipairs({ "inside", "outside", "offline" }) do
			local ok, reason = Rules.CanVisit(withInvite(owner(mode, presence), relation), visitor(relation), ON)
			local want = presence == "offline" and "OwnerOffline" or (presence == "outside" and "OwnerNotInside" or expectedInside[mode][relation])
			local pass = (want == true and ok == true) or (want ~= true and ok == false and reason == want)
			check(string.format("matrix %s/%s/%s", mode, relation, presence), pass, tostring(ok) .. ":" .. tostring(reason))
		end
	end
end

-- Gates, self-visit, capacity.
check("disabled blocks everything", select(2, Rules.CanVisit(owner("Public", "inside"), visitor("friend"), { Enabled = false })) == "Disabled")
check("missing settings = disabled", select(2, Rules.CanVisit(owner("Public", "inside"), visitor("friend"), nil)) == "Disabled")
check("self-visit rejected", select(2, Rules.CanVisit(owner("Public", "inside"), { UserId = OWNER, FriendOf = {} }, ON)) == "Self")
check("missing owner id rejected", select(2, Rules.CanVisit({ Online = true, Inside = true, AccessMode = "Public" }, visitor(), ON)) == "InvalidOwner")
check("capacity 7/8 admits", Rules.CanVisit(owner("Public", "inside", { VisitorCount = 7 }), visitor(), ON) == true)
check("capacity 8/8 full", select(2, Rules.CanVisit(owner("Public", "inside", { VisitorCount = 8 }), visitor(), ON)) == "Full")
check("capacity 0 max is full", select(2, Rules.CanVisit(owner("Public", "inside"), visitor(), { Enabled = true, MaxVisitorsPerGarage = 0 })) == "Full")
check("default max is 8", Rules.NormalizeSettings({ Enabled = true }).MaxVisitorsPerGarage == 8)
check("max clamps to 24", Rules.NormalizeSettings({ Enabled = true, MaxVisitorsPerGarage = 500 }).MaxVisitorsPerGarage == 24)
check("NaN max falls back", Rules.NormalizeSettings({ Enabled = true, MaxVisitorsPerGarage = 0 / 0 }).MaxVisitorsPerGarage == 8)

-- Busy visitor (on foot only, one place at a time).
local busyCases = {
	{ "driving", { Driving = true }, "Driving" },
	{ "racing", { Racing = true }, "Racing" },
	{ "in own garage", { InOwnGarage = true }, "InOwnGarage" },
	{ "visiting another garage", { VisitingOwnerUserId = 3003 }, "AlreadyVisiting" },
	{ "already visiting this garage", { VisitingOwnerUserId = OWNER }, "AlreadyHere" },
	{ "other activity", { Busy = true }, "Busy" },
}
for _, case in ipairs(busyCases) do
	local ok, reason = Rules.CanVisit(owner("Public", "inside"), visitor("stranger", case[2]), ON)
	check("busy visitor: " .. case[1], ok == false and reason == case[3], tostring(reason))
end
check("access denial wins over busy (private stays hidden)", select(2, Rules.CanVisit(owner("Private", "inside"), visitor("stranger", { Driving = true }), ON)) == "Private")
check("full reported after busy", select(2, Rules.CanVisit(owner("Public", "inside", { VisitorCount = 8 }), visitor("stranger", { Driving = true }), ON)) == "Driving")

-- Helpers.
check("invalid mode normalises to Private", Rules.NormalizeMode("Everyone") == "Private" and Rules.NormalizeMode(nil) == "Private")
check("unknown mode denies", select(2, Rules.CanVisit(owner("Everyone", "inside"), visitor("friend"), ON)) == "Private")
check("invite ids compare numerically", Rules.IsInvited({ InvitedUserIds = { tostring(VISITOR) } }, VISITOR) and not Rules.IsInvited({ InvitedUserIds = { 5 } }, VISITOR))
check("friend check only for FriendsOnly", Rules.NeedsFriendCheck(owner("FriendsOnly", "inside")) and not Rules.NeedsFriendCheck(owner("Public", "inside")))
check("every reason has a message", (function()
	for _, reason in ipairs({ "Disabled", "Self", "OwnerOffline", "OwnerNotInside", "Private", "NotFriend", "NotInvited", "Full", "Driving", "Racing", "Busy", "InOwnGarage", "AlreadyVisiting", "AlreadyHere" }) do
		if Rules.Message(reason) == Rules.Message("__unknown__") then return false end
	end
	return true
end)())

-- Revalidation (access change / invite revoke) ignores capacity and busy flags.
check("still admitted when full", Rules.StillAdmitted(owner("Public", "inside", { VisitorCount = 8 }), visitor(), ON) == true)
check("revoked invite ejects", select(2, Rules.StillAdmitted(owner("InviteOnly", "inside"), visitor("stranger"), ON)) == "NotInvited")
check("switch to Private ejects", select(2, Rules.StillAdmitted(owner("Private", "inside"), visitor("friend"), ON)) == "Private")
check("switch to FriendsOnly keeps friend", Rules.StillAdmitted(owner("FriendsOnly", "inside"), visitor("friend"), ON) == true)
check("owner outside ejects", select(2, Rules.StillAdmitted(owner("Public", "outside"), visitor(), ON)) == "OwnerNotInside")

-- Second admission pass (server re-runs CanVisit on a rebuilt owner state after its yields, reusing the friend result).
local firstVisitor = visitor("friend")
check("first pass admits friend", Rules.CanVisit(owner("FriendsOnly", "inside"), firstVisitor, ON) == true)
check("second pass sees switch to Private", select(2, Rules.CanVisit(owner("Private", "inside"), firstVisitor, ON)) == "Private")
check("second pass sees revoked invite", select(2, Rules.CanVisit(owner("InviteOnly", "inside"), visitor("stranger"), ON)) == "NotInvited")
check("second pass sees capacity filled meanwhile", select(2, Rules.CanVisit(owner("FriendsOnly", "inside", { VisitorCount = 8 }), firstVisitor, ON)) == "Full")
check("second pass sees owner left", select(2, Rules.CanVisit(owner("FriendsOnly", "outside"), firstVisitor, ON)) == "OwnerNotInside")

-- Visitable list.
local owners = {
	owner("Public", "inside", { UserId = 11, OwnerName = "zed", VisitorCount = 8 }),
	owner("Public", "inside", { UserId = 12, OwnerName = "Amy" }),
	owner("Private", "inside", { UserId = 13, OwnerName = "Hidden" }),
	owner("FriendsOnly", "inside", { UserId = 14, OwnerName = "Bob" }),
	owner("FriendsOnly", "inside", { UserId = 15, OwnerName = "Cat" }),
	owner("InviteOnly", "inside", { UserId = 16, OwnerName = "Dan", InvitedUserIds = { VISITOR } }),
	owner("Public", "outside", { UserId = 17, OwnerName = "Away" }),
	owner("Public", "inside", { UserId = VISITOR, OwnerName = "Me" }),
}
local me = visitor("stranger"); me.FriendOf[14] = true
local rows = Rules.BuildVisitableList(owners, me, ON)
local names = {}
for _, row in ipairs(rows) do table.insert(names, row.OwnerName .. (row.CanVisit and "+" or "-")) end
check("list hides private/not-friend/outside/self", #rows == 4, table.concat(names, ","))
check("list order: admissible by name, then full", table.concat(names, ",") == "Amy+,Bob+,Dan+,zed-", table.concat(names, ","))
check("full row carries reason", rows[4] and rows[4].Reason == "Full" and rows[4].Message ~= "" and rows[4].MaxVisitors == 8)
local driving = Rules.BuildVisitableList(owners, visitor("stranger", { Driving = true }), ON)
check("driving visitor still sees rows, disabled", #driving >= 2 and driving[1].CanVisit == false and driving[1].Reason == "Driving")
check("disabled list is empty", #Rules.BuildVisitableList(owners, me, { Enabled = false }) == 0)
local here = Rules.BuildVisitableList(owners, visitor("stranger", { VisitingOwnerUserId = 12 }), ON)
local hereRow; for _, row in ipairs(here) do if row.OwnerUserId == 12 then hereRow = row end end
check("current visit flagged", hereRow and hereRow.Visiting == true and hereRow.CanVisit == false)

-- Slots and spawn offsets.
check("next slot fills gaps", Rules.NextSlot({ [1] = true, [3] = true }) == 2 and Rules.NextSlot({}) == 1)
local seen, distinct = {}, true
for slot = 1, 8 do
	local dx, dz = Rules.SpawnOffset(slot)
	local key = string.format("%.2f,%.2f", dx, dz)
	if seen[key] then distinct = false end
	seen[key] = true
	if math.abs(math.sqrt(dx * dx + dz * dz) - 3.5) > 1e-6 then distinct = false end
end
check("8 visitor offsets distinct on 3.5 stud ring", distinct)
local dx9, dz9 = Rules.SpawnOffset(9)
check("slot 9 uses wider ring", math.abs(math.sqrt(dx9 * dx9 + dz9 * dz9) - 7) < 1e-6)

print(string.format("[GarageVisitRules tests] %d checks, %d failures", #results, failures))
for _, line in ipairs(results) do if line:sub(1, 4) == "FAIL" then warn(line) end end
return { failures = failures, results = results }
