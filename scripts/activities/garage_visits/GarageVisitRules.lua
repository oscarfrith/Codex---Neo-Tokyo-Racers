-- Pure admission rules for same-server garage visits (ServerStorage.Modules.Game.Garage.GarageVisitRules).
-- No services, instances or game-module requires: OwnedGarageManagement builds the plain state tables and
-- owns every side effect (friend lookups, teleports, attributes). Tests load this file with loadstring.
--
-- ownerState   = { UserId, Online, Inside, PropertyId, AccessMode, InvitedUserIds = {userId...}, VisitorCount }
--   Inside means the owner has a live session in their own garage, is fully inside and not mid-transition.
-- visitorState = { UserId, FriendOf = {[ownerUserId] = true}, Driving, Racing, Busy, InOwnGarage,
--                  VisitingOwnerUserId }
-- settings     = { Enabled, MaxVisitorsPerGarage }
local Rules = {}

Rules.AccessModes = { "Private", "FriendsOnly", "InviteOnly", "Public" }
local VALID_MODE = { Private = true, FriendsOnly = true, InviteOnly = true, Public = true }
local DEFAULT_MAX, MAX_MAX = 8, 24

Rules.Messages = {
	Disabled = "Garage visits are not available right now.",
	InvalidOwner = "That garage could not be found.",
	Self = "You cannot visit your own garage.",
	OwnerOffline = "That player is no longer in this server.",
	OwnerNotInside = "The owner is not inside their garage.",
	Private = "That garage is private.",
	NotFriend = "Only the owner's friends can visit.",
	NotInvited = "You have not been invited to that garage.",
	AlreadyHere = "You are already visiting this garage.",
	AlreadyVisiting = "Leave the garage you are visiting first.",
	Driving = "Exit your car to visit.",
	Racing = "Finish your race before visiting.",
	Busy = "Finish your current activity before visiting.",
	InOwnGarage = "Leave your garage before visiting.",
	Full = "That garage is full.",
}

function Rules.Message(reason)
	return Rules.Messages[tostring(reason or "")] or "You cannot visit that garage."
end

function Rules.NormalizeMode(mode)
	mode = tostring(mode or "")
	return VALID_MODE[mode] and mode or "Private"
end

function Rules.NormalizeSettings(settings)
	settings = type(settings) == "table" and settings or {}
	local max = tonumber(settings.MaxVisitorsPerGarage)
	if not max or max ~= max then max = DEFAULT_MAX end
	return { Enabled = settings.Enabled == true, MaxVisitorsPerGarage = math.clamp(math.floor(max), 0, MAX_MAX) }
end

-- True when the owner must be asked whether the visitor is a friend (the only admission input that yields).
function Rules.NeedsFriendCheck(ownerState)
	return type(ownerState) == "table" and Rules.NormalizeMode(ownerState.AccessMode) == "FriendsOnly"
end

function Rules.IsInvited(ownerState, visitorUserId)
	visitorUserId = tonumber(visitorUserId)
	if not visitorUserId then return false end
	for _, id in ipairs(type(ownerState) == "table" and type(ownerState.InvitedUserIds) == "table" and ownerState.InvitedUserIds or {}) do
		if tonumber(id) == visitorUserId then return true end
	end
	return false
end

-- Access-mode decision only (no capacity, presence or busy checks).
function Rules.Admits(ownerState, visitorState)
	local mode = Rules.NormalizeMode(ownerState and ownerState.AccessMode)
	if mode == "Public" then return true, "Public" end
	if mode == "FriendsOnly" then
		local friends = type(visitorState) == "table" and type(visitorState.FriendOf) == "table" and visitorState.FriendOf or {}
		if friends[tonumber(ownerState.UserId)] == true then return true, "FriendsOnly" end
		return false, "NotFriend"
	end
	if mode == "InviteOnly" then
		if Rules.IsInvited(ownerState, visitorState and visitorState.UserId) then return true, "InviteOnly" end
		return false, "NotInvited"
	end
	return false, "Private"
end

local function presence(ownerState, visitorState, settings)
	if not settings.Enabled then return false, "Disabled" end
	if type(ownerState) ~= "table" or not tonumber(ownerState.UserId) or type(visitorState) ~= "table" or not tonumber(visitorState.UserId) then return false, "InvalidOwner" end
	if tonumber(ownerState.UserId) == tonumber(visitorState.UserId) then return false, "Self" end
	if ownerState.Online ~= true then return false, "OwnerOffline" end
	if ownerState.Inside ~= true then return false, "OwnerNotInside" end
	return true
end

-- Full admission decision for a new visit. Returns ok, reason.
function Rules.CanVisit(ownerState, visitorState, settings)
	settings = Rules.NormalizeSettings(settings)
	local present, why = presence(ownerState, visitorState, settings)
	if not present then return false, why end
	local admitted, accessReason = Rules.Admits(ownerState, visitorState)
	if not admitted then return false, accessReason end
	if tonumber(visitorState.VisitingOwnerUserId) == tonumber(ownerState.UserId) then return false, "AlreadyHere" end
	if visitorState.Driving == true then return false, "Driving" end
	if visitorState.Racing == true then return false, "Racing" end
	if visitorState.InOwnGarage == true then return false, "InOwnGarage" end
	if visitorState.VisitingOwnerUserId ~= nil then return false, "AlreadyVisiting" end
	if visitorState.Busy == true then return false, "Busy" end
	if (tonumber(ownerState.VisitorCount) or 0) >= settings.MaxVisitorsPerGarage then return false, "Full" end
	return true, accessReason
end

-- Revalidation of an existing visit (after an access change or invite revoke). Capacity and the visitor's
-- own busy flags are not re-checked: they only gate entry.
function Rules.StillAdmitted(ownerState, visitorState, settings)
	settings = Rules.NormalizeSettings(settings)
	local present, why = presence(ownerState, visitorState, settings)
	if not present then return false, why end
	return Rules.Admits(ownerState, visitorState)
end

-- Reasons that still show a garage in the VISIT list (disabled). Access denials, presence failures and
-- self are hidden so private garages are never revealed.
local LISTED = { AlreadyHere = true, AlreadyVisiting = true, Driving = true, Racing = true, InOwnGarage = true, Busy = true, Full = true }

-- owners: array of ownerState plus display fields (OwnerName, GarageName, District, Image).
function Rules.BuildVisitableList(owners, visitorState, settings)
	settings = Rules.NormalizeSettings(settings)
	local rows = {}
	if not settings.Enabled then return rows end
	for _, owner in ipairs(type(owners) == "table" and owners or {}) do
		local ok, reason = Rules.CanVisit(owner, visitorState, settings)
		if ok or LISTED[reason] then
			table.insert(rows, {
				OwnerUserId = tonumber(owner.UserId), OwnerName = tostring(owner.OwnerName or ("User " .. tostring(owner.UserId))),
				PropertyId = tostring(owner.PropertyId or ""), GarageName = tostring(owner.GarageName or owner.PropertyId or "Garage"),
				District = tostring(owner.District or ""), Image = tostring(owner.Image or ""),
				AccessMode = Rules.NormalizeMode(owner.AccessMode), VisitorCount = math.max(0, math.floor(tonumber(owner.VisitorCount) or 0)),
				MaxVisitors = settings.MaxVisitorsPerGarage, CanVisit = ok, Reason = ok and "" or reason,
				Message = ok and "" or Rules.Message(reason), Visiting = reason == "AlreadyHere",
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.CanVisit ~= b.CanVisit then return a.CanVisit end
		local an, bn = string.lower(a.OwnerName), string.lower(b.OwnerName)
		if an ~= bn then return an < bn end
		return a.OwnerUserId < b.OwnerUserId
	end)
	return rows
end

-- Lowest free visitor slot (1-based) given a set {[slot] = true}.
function Rules.NextSlot(used)
	used = type(used) == "table" and used or {}
	local slot = 1
	while used[slot] do slot += 1 end
	return slot
end

-- Horizontal offset (studs) for a visitor slot so visitors do not stack on CharacterSpawn or the exit spawn.
-- Slot 1..8 form a ring of radius `radius` (default 3.5); later slots use a wider ring.
function Rules.SpawnOffset(slot, radius)
	slot = math.max(1, math.floor(tonumber(slot) or 1))
	radius = tonumber(radius) or 3.5
	local ring = math.floor((slot - 1) / 8)
	local angle = ((slot - 1) % 8) * (math.pi / 4) + ring * (math.pi / 8)
	local r = radius * (1 + ring)
	return math.cos(angle) * r, math.sin(angle) * r
end

return Rules
