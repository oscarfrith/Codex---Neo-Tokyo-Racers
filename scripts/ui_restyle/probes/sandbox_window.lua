-- UI restyle tool: sandbox_window (datamodel: Edit, NOT running). The only probe file that WRITES.
-- Guarded open / close of the agent test window (plan section 10). It edits two attributes on
-- ReplicatedStorage.Config.Player.Onboarding and one marker attribute on the same folder:
--   StudioVehicleSandboxEveryPlay  read by ProfileServer.studioVehicleSandboxConfig (lines 179-185)
--   StudioReplayEveryPlay          read by OnboardingServer.run (line 42)
--   UIRestyleTestWindow            marker: JSON of the values found at open time
-- Oscar turned the sandbox off on purpose: opening the window needs his yes for the session.
-- An installer APPLY and a handoff must refuse while the marker exists (mode "status" tells them).
-- What the sandbox does and does not protect is in SANDBOX_NOTES.md. Read it first.
local ARGS = {
	mode = "status",   -- "open" | "close" | "status"
	replay = false,    -- open only: also set StudioReplayEveryPlay = true (onboarding tests only)
	note = "",         -- open only: who / why, stored in the marker
}

local PLACE_ID = 103397770260610
local MARKER = "UIRestyleTestWindow"
local SANDBOX = "StudioVehicleSandboxEveryPlay"
local REPLAY = "StudioReplayEveryPlay"

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function reply(data)
	data.tool = "sandbox_window"
	data.mode = ARGS.mode
	return HttpService:JSONEncode(data)
end

if game.PlaceId ~= PLACE_ID then
	return reply({ ok = false, error = "wrong place", placeId = game.PlaceId, expected = PLACE_ID })
end
if not RunService:IsStudio() then
	return reply({ ok = false, error = "not Studio" })
end
-- IsEdit is the direct test; if this context may not call it, "not running" is the fallback.
local isEdit = not RunService:IsRunning()
pcall(function()
	isEdit = RunService:IsEdit()
end)
if RunService:IsRunning() or not isEdit then
	return reply({ ok = false, error = "must run on the Edit datamodel with Play stopped", isRunning = RunService:IsRunning(), isEdit = isEdit })
end

local config = ReplicatedStorage:FindFirstChild("Config")
local playerConfig = config and config:FindFirstChild("Player")
local onboarding = playerConfig and playerConfig:FindFirstChild("Onboarding")
if not onboarding then
	return reply({ ok = false, error = "ReplicatedStorage.Config.Player.Onboarding not found" })
end

local function snapshot()
	return {
		[SANDBOX] = { present = onboarding:GetAttribute(SANDBOX) ~= nil, value = onboarding:GetAttribute(SANDBOX) },
		[REPLAY] = { present = onboarding:GetAttribute(REPLAY) ~= nil, value = onboarding:GetAttribute(REPLAY) },
	}
end

local function readMarker()
	local raw = onboarding:GetAttribute(MARKER)
	if raw == nil then
		return nil, nil
	end
	if type(raw) ~= "string" then
		return nil, "marker is not a string"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" or type(data.prior) ~= "table" then
		return nil, "marker does not decode"
	end
	return data, nil
end

local marker, markerError = readMarker()
local current = snapshot()
local mode = ARGS.mode

if mode == "status" then
	return reply({
		ok = true, open = marker ~= nil or markerError ~= nil, markerError = markerError, marker = marker, current = current,
		sandboxCash = onboarding:GetAttribute("StudioVehicleSandboxCash"),
	})
end

if mode == "open" then
	if marker ~= nil or markerError ~= nil then
		return reply({ ok = false, error = "window is already open (close it first)", markerError = markerError, marker = marker, current = current })
	end
	for name, entry in pairs(current) do
		if entry.present and type(entry.value) ~= "boolean" then
			return reply({ ok = false, error = name .. " is not a boolean; refusing to touch it", current = current })
		end
	end
	local record = { prior = current, replay = ARGS.replay == true, note = tostring(ARGS.note or ""), openedUnix = os.time() }
	local encoded = HttpService:JSONEncode(record)
	-- Marker first: if anything below fails the window still reads as open and can be closed.
	onboarding:SetAttribute(MARKER, encoded)
	onboarding:SetAttribute(SANDBOX, true)
	if ARGS.replay == true then
		onboarding:SetAttribute(REPLAY, true)
	end
	local after = snapshot()
	local verified = after[SANDBOX].value == true
		and (ARGS.replay ~= true or after[REPLAY].value == true)
		and (ARGS.replay == true or (after[REPLAY].present == current[REPLAY].present and after[REPLAY].value == current[REPLAY].value))
		and onboarding:GetAttribute(MARKER) == encoded
	return reply({
		ok = verified, error = (not verified) and "verification failed after open; run mode close" or nil,
		before = current, after = after, marker = record,
		reminder = "Save nothing you do not mean to keep: the place is now modified. Close the window before any installer APPLY, handoff, save-and-reopen audit or publish.",
	})
end

if mode == "close" then
	if markerError ~= nil then
		return reply({ ok = false, error = "marker is unreadable; restore by hand and remove the marker attribute", markerError = markerError, raw = tostring(onboarding:GetAttribute(MARKER)), current = current })
	end
	if marker == nil then
		return reply({ ok = false, error = "window is not open", current = current })
	end
	local prior = marker.prior
	for _, name in ipairs({ SANDBOX, REPLAY }) do
		local entry = prior[name]
		if type(entry) ~= "table" then
			return reply({ ok = false, error = "marker has no prior value for " .. name, marker = marker, current = current })
		end
		if entry.present and type(entry.value) ~= "boolean" then
			return reply({ ok = false, error = "prior value for " .. name .. " is not a boolean", marker = marker, current = current })
		end
	end
	for _, name in ipairs({ SANDBOX, REPLAY }) do
		local entry = prior[name]
		if entry.present then
			onboarding:SetAttribute(name, entry.value)
		else
			onboarding:SetAttribute(name, nil)
		end
	end
	local after = snapshot()
	local verified = true
	for _, name in ipairs({ SANDBOX, REPLAY }) do
		local entry = prior[name]
		local wantedValue = nil
		if entry.present then
			wantedValue = entry.value
		end
		if after[name].present ~= (entry.present == true) or after[name].value ~= wantedValue then
			verified = false
		end
	end
	if not verified then
		-- Keep the marker so the window still reads as open.
		return reply({ ok = false, error = "restore did not verify; marker kept", before = current, after = after, marker = marker })
	end
	onboarding:SetAttribute(MARKER, nil)
	local markerGone = onboarding:GetAttribute(MARKER) == nil
	return reply({
		ok = markerGone, error = (not markerGone) and "marker could not be removed" or nil,
		before = current, after = after, restored = prior, openedUnix = marker.openedUnix, note = marker.note,
	})
end

return reply({ ok = false, error = "unknown mode (use open, close or status)" })
