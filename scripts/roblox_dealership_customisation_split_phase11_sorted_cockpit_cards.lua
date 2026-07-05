-- Neo Tokyo Racers - Dealership / Customisation Split Phase 11
-- Sorted cockpit/category card order.
--
-- This is a guarded source patch against the active client bootstrap. It expects
-- the dealership/customisation split Phase 9+ card renderer shape, and is meant
-- to be run after the user-confirmed Phase 10 layout polish. If an anchor is
-- missing, refresh the Studio mirror before creating another patch.

local PHASE = "NTR Dealership/Customisation Phase 11 Sorted Cockpit Cards"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE11_SORTED_COCKPIT_CARDS"
local PHASE10_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE10_RESPONSIVE_LAYOUT_POLISH"
local PHASE9_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE9_BADGE_OVERLAY_TIGHT_CARDS"

local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. message)
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function escapePattern(text)
	return text:gsub("([^%w])", "%%%1")
end

local function replaceOnce(source, old, new, label)
	local nextSource, count = string.gsub(source, escapePattern(old), new, 1)
	assert(count == 1, "Could not replace " .. label)
	return nextSource
end

local function activeBootstrap()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local scriptObject = root:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	assert(scriptObject:IsA("LocalScript"), "Active bootstrap path is not a LocalScript.")
	return scriptObject
end

local bootstrap = activeBootstrap()
local source = bootstrap.Source

if findPlain(source, MARKER) then
	info("Phase 11 marker already present; no source changes needed.")
	return
end

assert(findPlain(source, PHASE10_MARKER) or findPlain(source, PHASE9_MARKER), "Expected Phase 10 or Phase 9 marker before applying Phase 11.")
assert(findPlain(source, "renderCockpitShop = function()"), "Could not find renderCockpitShop.")

if findPlain(source, PHASE10_MARKER) then
	source = replaceOnce(source, "-- " .. PHASE10_MARKER, "-- " .. PHASE10_MARKER .. "\n-- " .. MARKER, "Phase 11 marker after Phase 10 marker")
else
	source = replaceOnce(source, "-- " .. PHASE9_MARKER, "-- " .. PHASE9_MARKER .. "\n-- " .. MARKER, "Phase 11 marker after Phase 9 marker")
end

local categoryLoopOld = [=[
	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
		local b = pooledButton(categoryPool, category.DisplayName or category.CategoryId, UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), category.CategoryId == State.CategoryId and Theme.CardHot or Theme.Card)
]=]

local categoryLoopNew = [=[
	local sortedCategories = {}
	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
		table.insert(sortedCategories, category)
	end
	table.sort(sortedCategories, function(a, b)
		local aName = tostring((a and (a.DisplayName or a.CategoryId)) or "")
		local bName = tostring((b and (b.DisplayName or b.CategoryId)) or "")
		if aName == bName then
			return tostring((a and a.CategoryId) or "") < tostring((b and b.CategoryId) or "")
		end
		return aName < bName
	end)

	for _, category in ipairs(sortedCategories) do
		local b = pooledButton(categoryPool, category.DisplayName or category.CategoryId, UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), category.CategoryId == State.CategoryId and Theme.CardHot or Theme.Card)
]=]

source = replaceOnce(source, categoryLoopOld, categoryLoopNew, "alphabetical category menu sort")

local ownedRowsSortOld = [=[
		table.sort(rows, function(a, b)
			local aName = tostring((a.Cockpit and a.Cockpit.DisplayName) or a.CockpitId or "")
			local bName = tostring((b.Cockpit and b.Cockpit.DisplayName) or b.CockpitId or "")
			if aName == bName then return tostring(a.VehicleId) < tostring(b.VehicleId) end
			return aName < bName
		end)
]=]

local ownedRowsSortNew = [=[
		table.sort(rows, function(a, b)
			local aSummary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[a.VehicleId]
			local bSummary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[b.VehicleId]
			local aRating = tonumber(aSummary and aSummary.Overall and aSummary.Overall.PerformanceIndex) or -math.huge
			local bRating = tonumber(bSummary and bSummary.Overall and bSummary.Overall.PerformanceIndex) or -math.huge
			if aRating ~= bRating then
				return aRating > bRating
			end
			local aName = tostring((a.Cockpit and a.Cockpit.DisplayName) or a.CockpitId or "")
			local bName = tostring((b.Cockpit and b.Cockpit.DisplayName) or b.CockpitId or "")
			if aName == bName then
				return tostring(a.VehicleId) < tostring(b.VehicleId)
			end
			return aName < bName
		end)
]=]

source = replaceOnce(source, ownedRowsSortOld, ownedRowsSortNew, "customisation owned cockpit rating sort")

local dealershipLoopOld = [=[
	else
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			local card = pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)
]=]

local dealershipLoopNew = [=[
	else
		local sortedCockpits = {}
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			table.insert(sortedCockpits, cockpit)
		end
		table.sort(sortedCockpits, function(a, b)
			local aPrice = tonumber(a and a.Price) or math.huge
			local bPrice = tonumber(b and b.Price) or math.huge
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end
			local aName = tostring((a and (a.DisplayName or a.CockpitId)) or "")
			local bName = tostring((b and (b.DisplayName or b.CockpitId)) or "")
			if aName == bName then
				return tostring((a and a.CockpitId) or "") < tostring((b and b.CockpitId) or "")
			end
			return aName < bName
		end)

		for _, cockpit in ipairs(sortedCockpits) do
			local card = pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)
]=]

source = replaceOnce(source, dealershipLoopOld, dealershipLoopNew, "dealership cockpit price sort")

assert(findPlain(source, MARKER), "Phase 11 marker was not installed.")
assert(findPlain(source, "for _, category in ipairs(sortedCategories) do"), "Sorted category loop was not installed.")
assert(findPlain(source, "return aRating > bRating"), "Owned cockpit rating sort was not installed.")
assert(findPlain(source, "for _, cockpit in ipairs(sortedCockpits) do"), "Sorted cockpit loop was not installed.")

bootstrap.Source = source

info("Installed Phase 11 sorting.")
info("Dealership cockpits now render cheapest to most expensive, left-to-right/top-to-bottom.")
info("Customisation owned cockpits now render highest rating to lowest rating, left-to-right/top-to-bottom.")
info("Categories now render alphabetically by display name, with category id as the tie-breaker.")
info("Restart Play, open dealership and customisation, then refresh the Studio mirror after verification.")
