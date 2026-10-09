-- Pure tests for Garage.GarageRoutes: the navigation data (tabs, marks, saved page ids, Back steps, sources) and
-- the slot artwork rows against fake config folders.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("tabs: three, in order, with the Classic card and page ids", function()
		expect(#M.Tabs == 3, "three tabs")
		local wanted = {
			{ "Parts", "Add", "Card.AddModules", "Page.AddModules", "AddModules" },
			{ "Upgrades", "Upgrade", "Card.UpgradeModules", "Page.UpgradeModules", "UpgradeModules" },
			{ "Paint", "Paint", "Card.PaintShop", "Page.PaintShop", "PaintShop" },
		}
		for index, row in ipairs(wanted) do
			local tab = M.Tabs[index]
			expect(tab.Id == row[1] and tab.Workshop == row[2] and tab.Card == row[3] and tab.PageMark == row[4] and tab.TutorialPageId == row[5], "tab " .. index)
			expect(M.Tab(row[1]) == tab, "lookup " .. row[1])
		end
		expect(M.HomeMark == "Page.CustomisationHome" and M.Tab(M.HubTab) ~= nil, "hub")
		expect(M.Tab("Nope") == nil, "unknown tab")
	end)

	case("marks: every mark key the routes name exists in the generated contract", function()
		local ok, Contracts = pcall(env.Load, "ReplicatedStorage.Modules.Game.UIPulse.Kit.Contracts")
		expect(ok and type(Contracts) == "table", "Kit.Contracts loads")
		expect(Contracts.Marks[M.HomeMark] ~= nil, M.HomeMark)
		for _, tab in ipairs(M.Tabs) do
			expect(Contracts.Marks[tab.Card] ~= nil, tab.Card)
			expect(Contracts.Marks[tab.PageMark] ~= nil, tab.PageMark)
			expect(Contracts.Marks[tab.PageMark].Attributes.TutorialPageId == tab.TutorialPageId, tab.PageMark .. " page id")
		end
		for _, key in ipairs({ "Text.Dealership", "Categories", "Stats", "Capacity", "VehicleScroller", "TutorialCardScroller", "UpgradeBudget", "Card" }) do
			expect(Contracts.Marks[key] ~= nil, key)
		end
		expect(Contracts.Marks["Text.Dealership"].Text == M.Text.DealershipTitle, "the title text is the mark's text")
	end)

	case("sources: Classic ModuleOptionMode values behind Shop and Owned", function()
		expect(#M.Sources == 2 and M.Sources[1].Id == "Buy" and M.Sources[2].Id == "Owned", "ids")
		expect(M.SourceDefault.Slot == "Buy" and M.SourceDefault.Detour == "OwnedIfAny", "defaults")
	end)

	case("back: every step is one the model implements; only the slot list has no destination", function()
		local known = { OptionsToSources = true, SourcesBack = true, Hub = true, PaintOverview = true }
		local unavailable = 0
		for key, route in pairs(M.Back) do
			expect(#route.Steps >= 1, key .. " has steps")
			for _, step in ipairs(route.Steps) do
				expect(known[step] == true, key .. ": unknown step " .. tostring(step))
			end
			if not route.Available then
				unavailable += 1
				expect(key == "Parts.Slots", key .. " should be available")
			end
		end
		expect(unavailable == 1, "exactly one page without a Back destination")
		expect(table.concat(M.Back["Parts.Options"].Steps, ",") == "OptionsToSources,SourcesBack", "list back runs both Classic steps")
	end)

	case("page keys and pages", function()
		expect(M.PageKey({ Stage = "Customise", CustomizeMode = "Colour", CustomizeTarget = "Engine1" }, "ALL") == "Paint.Colour.Area", "the drawn target wins")
		expect(M.PageKey({ Stage = "Customise", CustomizeMode = "Colour" }) == "Paint.Colour.Area", "no target is ALL")
		expect(M.PageKey({ Stage = "Hub" }) == nil and M.PageKey({ Stage = "Closed" }) == nil, "no key")
		expect(M.PageFor({ Stage = "Build" }) == "Parts" and M.PageFor({ Stage = "Customise", CustomizeMode = "Upgrades" }) == "Upgrades", "pages")
		expect(M.PageFor({ Stage = "Closed" }) == "Closed" and M.TabFor({ Stage = "Browser" }) == nil, "closed")
	end)

	local function folder(attributes)
		return {
			GetAttribute = function(_, name)
				return attributes[name]
			end,
		}
	end

	local function root(folders)
		return {
			FindFirstChild = function(_, name)
				return folders[name]
			end,
		}
	end

	case("artwork: fallback rows without config, in sort order", function()
		local build = M.ArtworkForPage(nil, "Build", "exotic")
		expect(#build == 10 and build[1].TargetId == "Engine1" and build[#build].TargetId == "RearSpoiler", "ten slots, engine first, spoiler last")
		local customise = M.ArtworkForPage(nil, "Customise", "exotic")
		expect(#customise == 13 and customise[1].TargetId == "ALL" and customise[2].TargetId == "Cockpit" and customise[3].TargetId == "THRUST_COLOR", "paint targets first")
		expect(build[1].Image == "" and build[1].DisplayName == "Front Engine", "fallback fields")
	end)

	case("artwork: config folders override order, image per category, hidden per category", function()
		local config = root({
			FrontBody = folder({ SortOrder = 32, Image = "rbxassetid://1", Image_exotic = "rbxassetid://2" }),
			RearBody = folder({ SortOrder = 34, DisplayName = "Tail" }),
			SidePods = folder({ Hidden_exotic = true }),
			Boost = folder({ ShowInBuild = false }),
		})
		local build = M.ArtworkForPage(config, "Build", "exotic")
		expect(build[1].TargetId == "FrontBody" and build[2].TargetId == "RearBody" and build[3].TargetId == "Engine1", "order from config")
		expect(build[1].Image == "rbxassetid://2" and build[2].DisplayName == "Tail", "category image and display name")
		for _, item in ipairs(build) do
			expect(item.TargetId ~= "SidePods" and item.TargetId ~= "Boost", item.TargetId .. " should be left out")
		end
		local other = M.ArtworkForPage(config, "Build", "muscle")
		expect(other[1].Image == "rbxassetid://1", "plain image for another category")
		local seen = false
		for _, item in ipairs(other) do
			seen = seen or item.TargetId == "SidePods"
		end
		expect(seen, "hidden only for the named category")
	end)

	case("text: the strings other code compares or tests read are the Classic ones", function()
		expect(M.Text.DealershipTitle == "DEALERSHIP", "DEALERSHIP")
		expect(M.Text.DriveBlocked == "Equip one engine, stabilisers, and boost before driving.", "drive line")
		expect(M.Text.Busy == "Please wait." and M.Text.NoReply == "Garage server did not respond.", "adapter lines")
		expect(M.Text.OwnVehicleReason == "OWN A VEHICLE TO CUSTOMISE", "server reason")
		expect(M.Loading.DestinationDrive == "FreeRoamDrive" and M.Loading.DestinationExit == "DealershipExterior"
			and M.Loading.DestinationDriveIn == "DriveInCustomisation", "loading destinations")
	end)

	return results
end
