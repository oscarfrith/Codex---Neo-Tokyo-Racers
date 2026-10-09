-- Pure tests for Kit.Contracts (API.md section 13). Reads the generated tables only.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local results = {}
	local function case(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(err) or nil })
	end

	-- Programme contract 2.3, "Reserved names kept", typed here on purpose: the generator must reproduce it.
	local PROGRAMME_RESERVED = {
		"DesktopFreeRoamHud", "DesignRoot", "ModalLayer", "Controls", "CarPanel", "Minimap",
		"MobileDriveControls_Phase1", "DriftLeft", "DriftRight", "Boost", "ActivityHud",
		"RaceBrowser", "CardContent", "TeleportToStart", "RaceEntryPresentation",
		"TierE", "TierD", "TierC", "TierB", "TierA", "TierS",
		"LapSelector", "PrizeSummary", "MedalTargets", "RaceFormat",
		"CanonicalGarageGui", "CanonicalCanvas", "CanonicalGarageBrowser", "CanonicalGarageWorkspace",
		"OwnedGarageBrowser", "AccessControls", "SharedTopNotification", "SharedConfirmationOverlay",
		"LoadingSafeContent", "SafeRoot", "Status", "ProgressTrack", "ProgressFill",
	}

	case("every table of API section 9 exists", function()
		for _, field in ipairs({ "Reserved", "Trap", "TrapDescendants", "LockedButtonNames", "Marks", "PlayerAttributes", "Source" }) do
			assert(type(M[field]) == "table", field .. " is missing")
		end
	end)

	case("programme reserved names are all present", function()
		local missing = {}
		for _, name in ipairs(PROGRAMME_RESERVED) do
			if M.Reserved[name] ~= true then
				table.insert(missing, name)
			end
		end
		assert(#missing == 0, "missing: " .. table.concat(missing, ", "))
	end)

	case("no name is both reserved and trap", function()
		for name in pairs(M.Reserved) do
			assert(M.Trap[name] == nil, name .. " is reserved and a trap")
			assert(M.TrapDescendants[name] == nil, name .. " is reserved and a trap descendant")
		end
		for name in pairs(M.Trap) do
			assert(M.TrapDescendants[name] == nil, name .. " is in both trap sets")
		end
	end)

	case("trap sets hold the named traps and the kill list", function()
		for _, name in ipairs({ "DriveHUD", "TouchGui", "DrivingSpeedEffect", "RaceHud", "RaceEntry", "RaceResults_Phase4" }) do
			assert(M.Trap[name] == true, name .. " is not a trap")
		end
		for _, name in ipairs({ "GarageRoot", "DealershipRoot", "CustomisationRoot", "CustomizationRoot" }) do
			assert(M.TrapDescendants[name] == true, name .. " is not a trap descendant")
		end
	end)

	case("sets hold only true under string keys", function()
		for _, field in ipairs({ "Reserved", "Trap", "TrapDescendants", "LockedButtonNames" }) do
			local count = 0
			for name, value in pairs(M[field]) do
				assert(type(name) == "string" and name ~= "" and value == true, field .. " has a bad entry")
				count += 1
			end
			assert(count > 0, field .. " is empty")
		end
	end)

	case("locked button names are Car, Race and Garage, each with a name mark", function()
		local count = 0
		for _ in pairs(M.LockedButtonNames) do
			count += 1
		end
		assert(count == 3, "expected 3 locked names, got " .. count)
		for _, name in ipairs({ "Car", "Race", "Garage" }) do
			assert(M.LockedButtonNames[name] == true, name .. " is not locked")
			assert(M.Marks[name] and M.Marks[name].Name == name, name .. " has no name mark")
		end
	end)

	case("every mark carries a name, a text or attributes of the right type", function()
		for key, mark in pairs(M.Marks) do
			assert(type(key) == "string" and type(mark) == "table", "bad mark entry")
			assert(mark.Name ~= nil or mark.Text ~= nil or mark.Attributes ~= nil, key .. " is empty")
			assert(mark.Name == nil or type(mark.Name) == "string", key .. ".Name")
			assert(mark.Text == nil or type(mark.Text) == "string", key .. ".Text")
			assert(mark.Attributes == nil or type(mark.Attributes) == "table", key .. ".Attributes")
			if mark.Name then
				assert(M.Reserved[mark.Name] == true, "mark name " .. mark.Name .. " is not reserved")
				assert(M.Trap[mark.Name] == nil and M.TrapDescendants[mark.Name] == nil, key .. " marks a trap name")
			end
		end
	end)

	case("card, page and text marks match what Classic onboarding compares", function()
		local card = M.Marks["Card.AddModules"]
		assert(card and card.Attributes.CanonicalGarageCard == true, "Card.AddModules flag")
		assert(card.Attributes.CanonicalGarageCardId == "AddModules", "Card.AddModules id")
		assert(M.Marks.Card and M.Marks.Card.Attributes.CanonicalGarageCard == true, "Card")
		local page = M.Marks["Page.CustomisationHome"]
		assert(page and page.Attributes.TutorialWorkspace == true, "Page flag")
		assert(page.Attributes.TutorialPageId == "CustomisationHome", "Page id")
		assert(M.Marks["Text.TimeTrial"].Text == "TIME TRIAL", "Text.TimeTrial")
		assert(M.Marks["Text.Race"].Text == "RACE", "Text.Race")
		assert(M.Marks["Text.Dealership"].Text == "DEALERSHIP", "Text.Dealership")
	end)

	case("player attributes map names to a type word", function()
		local allowed = { boolean = true, number = true, string = true, unknown = true, mixed = true }
		for name, kind in pairs(M.PlayerAttributes) do
			assert(type(name) == "string" and allowed[kind] == true, tostring(name) .. " has type " .. tostring(kind))
		end
		assert(M.PlayerAttributes.MobileMajorMenuOpen == "boolean", "MobileMajorMenuOpen")
		assert(M.PlayerAttributes.MobileFreeRoamCarMenuOpen == "boolean", "MobileFreeRoamCarMenuOpen")
		assert(M.PlayerAttributes.MobileControlMode == "string", "MobileControlMode")
	end)

	case("source names the generator and fingerprints every input", function()
		assert(type(M.Source.Generator) == "string" and M.Source.Generator ~= "", "Generator")
		for _, file in ipairs({ "_reserved_names.json", "_onboarding_targets.json", "_player_attributes.json", "_screenguis.json" }) do
			local fingerprint = M.Source.Inputs[file]
			assert(type(fingerprint) == "string" and string.match(fingerprint, "^sha256:%x+$") ~= nil, file .. " fingerprint")
		end
	end)

	case("tables are frozen", function()
		assert(table.isfrozen(M.Reserved) and table.isfrozen(M.Trap) and table.isfrozen(M.Marks), "not frozen")
		assert(table.isfrozen(M.Marks.Car), "mark not frozen")
	end)

	return results
end
