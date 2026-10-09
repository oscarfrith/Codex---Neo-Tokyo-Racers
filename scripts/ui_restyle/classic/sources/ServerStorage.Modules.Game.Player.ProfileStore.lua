-- Canonical feature implementation; startup is owned by the composition root.
-- Pure transport helper: no profile ownership, global loops or DataStore lookup.
local ProfileStore = {}
ProfileStore.__index = ProfileStore
local TOKEN, UNTIL = "NTRSessionToken", "NTRSessionLeaseUntil"

function ProfileStore.new(store, options)
	options = options or {}
	return setmetatable({store=store, now=options.now or os.time, clock=options.clock or os.clock,
		wait=options.wait or task.wait, lease=options.lease or 180, attempts=options.attempts or 3}, ProfileStore)
end

function ProfileStore:update(key, transform, valid)
	local lastError = "Cancelled"
	for attempt = 1, self.attempts do
		if valid and not valid() then return false, "Cancelled" end
		local rejection
		local ok, value, info = pcall(function()
			return self.store:UpdateAsync(key, function(old, keyInfo)
				rejection = nil -- UpdateAsync may rerun this callback after a conflict.
				if valid and not valid() then rejection="Cancelled"; return nil end
				local metadata = keyInfo and table.clone(keyInfo:GetMetadata()) or {}
				local users = keyInfo and keyInfo:GetUserIds() or {}
				local nextValue, reason = transform(old, metadata)
				if nextValue == nil then rejection=reason or "Rejected"; return nil end
				return nextValue, users, metadata
			end)
		end)
		if ok then
			if rejection or value == nil then return false, rejection or "Rejected" end
			return true, value, info
		end
		lastError = tostring(value)
		if attempt < self.attempts then self.wait(attempt) end
	end
	return false, lastError
end

function ProfileStore:acquire(key, token, defaultData, valid)
	return self:update(key, function(old, metadata)
		if old ~= nil and type(old) ~= "table" then return nil, "InvalidStoredProfile" end
		if metadata[TOKEN] and metadata[TOKEN] ~= token and (tonumber(metadata[UNTIL]) or 0) > self.now() then
			return nil, "SessionLocked"
		end
		metadata[TOKEN], metadata[UNTIL] = token, self.now() + self.lease
		return old or defaultData
	end, valid)
end

function ProfileStore:write(key, token, data, release, valid)
	return self:update(key, function(old, metadata)
		if metadata[TOKEN] ~= token or (tonumber(metadata[UNTIL]) or 0) <= self.now() then
			return nil, "SessionLost"
		end
		if release then metadata[TOKEN], metadata[UNTIL] = nil, nil
		else metadata[UNTIL] = self.now() + self.lease end
		return data or old
	end, valid)
end

-- Serialises snapshot capture AND writes. No queued stale snapshots or unbounded waiters.
function ProfileStore:save(session, encode, release, deadline)
	if session.Released then return true, "Already closed" end
	if session.Saving then return false, "Busy" end
	session.Saving = true
	local revision = session.Revision or 0
	local ok, result, detail = pcall(function()
		if session.NoSave then return true, "Save suppressed" end
		local data = encode(session.Profile)
		local success, value, info = self:write(session.Key, session.SessionId, data, release, function()
			return not session.Released and (not deadline or self.clock() < deadline)
		end)
		if success and not release then
			local metadata = info and info:GetMetadata()
			session.LeaseUntil = metadata and metadata[UNTIL] or 0
		end
		return success, success and "Saved" or value
	end)
	session.Saving = false
	local success = ok and result == true
	if success then
		session.Dirty = (session.Revision or 0) ~= revision
		session.LastSaveUnix = self.now()
		session.LastError = ""
		if release then session.Released = true end
	else session.LastError = tostring(ok and detail or result) end
	return success, success and detail or session.LastError
end

return ProfileStore
