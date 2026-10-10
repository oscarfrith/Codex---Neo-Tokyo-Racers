-- UI restyle tool: set_style (datamodel: Edit, NOT running). WRITES attributes. CONTRACT 7.5 and 7.6.
-- Guarded switch of the session style for the integrator's Play tests. It edits up to three attributes:
--   ReplicatedStorage.Config.UI @UIStyle                               always (modes pulse and classic)
--   ReplicatedStorage.Config.UI @UIStyleDevFamilies                    only when ARGS.devFamilies is a string
--   ReplicatedStorage.Config.Development.ClientTools @PulseGalleryEnabled   only when ARGS.gallery is a boolean
-- and one marker attribute, ReplicatedStorage.Config.UI @UIStyleSetPrior: JSON of the three values found before the
-- first change (each recorded as present or absent). Mode restore puts all three back exactly and removes the marker.
-- While the marker exists the Classic verify reports it as an added attribute on purpose: restore before any
-- installer AUDIT, APPLY, ROLLBACK, handoff or save.
local ARGS = {
	mode = "status",    -- "status" | "pulse" | "classic" | "restore"
	devFamilies = nil,  -- pulse / classic only: string to write to UIStyleDevFamilies (U11 uses "Nope"); nil leaves it
	gallery = nil,      -- pulse / classic only: boolean to write to PulseGalleryEnabled (U8 uses true); nil leaves it
	note = "",          -- stored in the marker
}

local PLACE_ID = 103397770260610
local MARKER = "UIStyleSetPrior"
local STYLE_VALUES = { pulse = "Pulse", classic = "Classic" }

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local function reply(data)
	data.tool = "set_style"
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
local ui = config and config:FindFirstChild("UI")
local development = config and config:FindFirstChild("Development")
local clientTools = development and development:FindFirstChild("ClientTools")
if not ui or not clientTools then
	return reply({ ok = false, error = "ReplicatedStorage.Config.UI or Config.Development.ClientTools not found" })
end

-- The three values this tool may change, in a fixed order. kind is the only type each may hold.
local TARGETS = {
	{ key = "UIStyle", instance = ui, kind = "string" },
	{ key = "UIStyleDevFamilies", instance = ui, kind = "string" },
	{ key = "PulseGalleryEnabled", instance = clientTools, kind = "boolean" },
}

local function snapshot()
	local out = {}
	for _, target in ipairs(TARGETS) do
		local value = target.instance:GetAttribute(target.key)
		out[target.key] = { present = value ~= nil, value = value }
	end
	return out
end

local function readMarker()
	local raw = ui:GetAttribute(MARKER)
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

local modules = ReplicatedStorage:FindFirstChild("Modules")
local gameModules = modules and modules:FindFirstChild("Game")
local uiPulse = gameModules and gameModules:FindFirstChild("UIPulse")
local installed = {
	latch = ReplicatedFirst:FindFirstChild("UIStyleSwitch") ~= nil,
	routes = uiPulse ~= nil and uiPulse:FindFirstChild("Routes") ~= nil,
}

local marker, markerError = readMarker()
local current = snapshot()
local mode = ARGS.mode

if mode == "status" then
	return reply({
		ok = true, switched = marker ~= nil or markerError ~= nil, markerError = markerError, marker = marker,
		current = current, installed = installed,
	})
end

if mode == "pulse" or mode == "classic" then
	if markerError ~= nil then
		return reply({ ok = false, error = "marker is unreadable; restore by hand and remove the marker attribute", markerError = markerError, raw = tostring(ui:GetAttribute(MARKER)), current = current })
	end
	if ARGS.devFamilies ~= nil and type(ARGS.devFamilies) ~= "string" then
		return reply({ ok = false, error = "ARGS.devFamilies must be a string or nil" })
	end
	if ARGS.gallery ~= nil and type(ARGS.gallery) ~= "boolean" then
		return reply({ ok = false, error = "ARGS.gallery must be a boolean or nil" })
	end
	for _, target in ipairs(TARGETS) do
		local entry = current[target.key]
		if entry.present and type(entry.value) ~= target.kind then
			return reply({ ok = false, error = target.key .. " is not a " .. target.kind .. "; refusing to touch it", current = current })
		end
	end
	if mode == "pulse" and not (installed.latch and installed.routes) then
		-- CONTRACT 4, invariant 7: Pulse with no Routes module hangs start-up. Refuse instead.
		return reply({ ok = false, error = "Phase 1 is not installed (UIStyleSwitch or UIPulse.Routes missing); Pulse refused", installed = installed, current = current })
	end
	local wanted = { UIStyle = STYLE_VALUES[mode] }
	if ARGS.devFamilies ~= nil then
		wanted.UIStyleDevFamilies = ARGS.devFamilies
	end
	if ARGS.gallery ~= nil then
		wanted.PulseGalleryEnabled = ARGS.gallery
	end
	local record = marker
	if record == nil then
		-- First change: record what was there. A later pulse or classic call keeps this record.
		record = { prior = current, note = tostring(ARGS.note or ""), setUnix = os.time() }
		-- Marker first: if anything below fails the switch still reads as made and can be restored.
		ui:SetAttribute(MARKER, HttpService:JSONEncode(record))
		if readMarker() == nil then
			return reply({ ok = false, error = "marker could not be written; nothing was changed", current = current })
		end
	end
	for _, target in ipairs(TARGETS) do
		if wanted[target.key] ~= nil then
			target.instance:SetAttribute(target.key, wanted[target.key])
		end
	end
	local after = snapshot()
	local verified = true
	for _, target in ipairs(TARGETS) do
		local key = target.key
		if wanted[key] ~= nil then
			verified = verified and after[key].value == wanted[key]
		else
			verified = verified and after[key].present == current[key].present and after[key].value == current[key].value
		end
	end
	return reply({
		ok = verified, error = (not verified) and "verification failed after the change; run mode restore" or nil,
		before = current, after = after, marker = record, installed = installed,
		reminder = "The place is now modified. Run mode restore before any installer run, handoff or save.",
	})
end

if mode == "restore" then
	if markerError ~= nil then
		return reply({ ok = false, error = "marker is unreadable; restore by hand and remove the marker attribute", markerError = markerError, raw = tostring(ui:GetAttribute(MARKER)), current = current })
	end
	if marker == nil then
		return reply({ ok = false, error = "nothing to restore (no marker)", current = current })
	end
	local prior = marker.prior
	for _, target in ipairs(TARGETS) do
		local entry = prior[target.key]
		if type(entry) ~= "table" then
			return reply({ ok = false, error = "marker has no prior value for " .. target.key, marker = marker, current = current })
		end
		if entry.present and type(entry.value) ~= target.kind then
			return reply({ ok = false, error = "prior value for " .. target.key .. " is not a " .. target.kind, marker = marker, current = current })
		end
	end
	for _, target in ipairs(TARGETS) do
		local entry = prior[target.key]
		if entry.present then
			target.instance:SetAttribute(target.key, entry.value)
		else
			target.instance:SetAttribute(target.key, nil)
		end
	end
	local after = snapshot()
	local verified = true
	for _, target in ipairs(TARGETS) do
		local entry = prior[target.key]
		local wantedValue = nil
		if entry.present then
			wantedValue = entry.value
		end
		if after[target.key].present ~= (entry.present == true) or after[target.key].value ~= wantedValue then
			verified = false
		end
	end
	if not verified then
		-- Keep the marker so the switch still reads as made.
		return reply({ ok = false, error = "restore did not verify; marker kept", before = current, after = after, marker = marker })
	end
	ui:SetAttribute(MARKER, nil)
	local markerGone = ui:GetAttribute(MARKER) == nil
	return reply({
		ok = markerGone, error = (not markerGone) and "marker could not be removed" or nil,
		before = current, after = after, restored = prior, setUnix = marker.setUnix, note = marker.note,
	})
end

return reply({ ok = false, error = "unknown mode (use status, pulse, classic or restore)" })
