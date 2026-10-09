-- Pure tests for Garage.GarageScreenView: the pure display helpers, then every fixture state mounted on a detached
-- stage at R1080 and C844 over the fake model. No error, within the instance ceiling, a second Render changes
-- nothing, a selection creates and destroys nothing, the names other scripts read are present, and no ScreenGui
-- exists. Needs kit v2 in the harness source set.
return function(M, env)
	local results = {}
	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
	local BUDGET = 240 -- programme contract 5.2, garage page (everything under the stage, the status strip included)
	local PAINT_BUDGET = 320 -- the colour controls with their 26 preset swatches; see NOTES_a.md (budget question)

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function money(amount, compact)
		return (compact and "~$" or "$") .. tostring(amount)
	end

	------------------------------------------------------------------------------------------------------------
	-- Pure helpers.
	------------------------------------------------------------------------------------------------------------
	case("tile props: price is the model's amount through the money formatter; text prices pass through", function()
		local props = M._tileProps({ Key = "a", Kind = "Vehicle", Title = "Zephyr", Tier = "D", Rating = 390, PriceAmount = 150000, Status = "Unaffordable", Card = true }, false, money)
		expect(props.Price == "$150000" and props.Tier == "D" and props.Rating == 390 and props.Status == "Unaffordable", "vehicle")
		expect(props.MarkKey == "Card" and props.State == "Default" and props.Icon == "car", "mark, state, icon")
		expect(M._tileProps({ Key = "a", Title = "x", PriceAmount = 5 }, true, money).Price == "~$5", "compact form")
		local maxed = M._tileProps({ Key = "u", Kind = "Upgrade", Title = "Intake", PriceText = "MAX LEVEL", Selected = true }, false, money)
		expect(maxed.Price == "MAX LEVEL" and maxed.State == "Selected", "text price")
		local module = M._tileProps({ Key = "m", Kind = "Module", Title = "Spine", Sub = "AVAILABLE", Rating = 316 }, false, money)
		expect(module.Rating == nil and string.find(module.Sub, "316", 1, true) ~= nil, "a module rating joins the status line")
		expect(M._tileProps({ Key = "s", Title = "Slot", Image = "" }, false, money).Image == nil, "empty image is no image")
		expect(M._tileProps({ Key = "s", Title = "Slot", ChipRightKind = "Tick" }, false, money).ChipRightKind == nil, "no chip, no chip kind")
	end)

	case("tile props: only keys the kit tile takes", function()
		local allowed = { Key = true, Title = true, Sub = true, State = true, Status = true, ChipLeft = true, ChipRight = true,
			ChipRightKind = true, Price = true, Image = true, Icon = true, Tier = true, Rating = true, Selectable = true, MarkKey = true }
		local props = M._tileProps({ Key = "k", Kind = "Module", Title = "t", Sub = "s", ChipLeft = "a", ChipRight = "b", ChipRightKind = "Pink",
			PriceAmount = 1, Image = "rbxassetid://1", Tier = "A", Rating = 2, Selectable = true, Card = true, RowState = "Shop",
			Action = { Text = "Buy" }, SlotId = "Engine1", Selected = true }, false, money)
		for key in pairs(props) do
			expect(allowed[key] == true, "unexpected key " .. tostring(key))
		end
	end)

	case("count, action text, signature", function()
		local items = { { Key = "a" }, { Key = "b" }, { Key = "c" } }
		expect(M._count(items, "b") == "2/3" and M._count(items, nil) == "3" and M._count({}, nil) == nil, "count")
		expect(M._actionText({ Text = "Buy", Amount = 3000 }, money) == "Buy $3000", "purchase text carries the amount")
		expect(M._actionText({ Text = "Equip" }, money) == "Equip", "no amount, no price")
		local one = M._signature({ M._tileProps({ Key = "a", Title = "x", PriceAmount = 1 }, false, money) })
		local two = M._signature({ M._tileProps({ Key = "a", Title = "x", PriceAmount = 2 }, false, money) })
		local same = M._signature({ M._tileProps({ Key = "a", Title = "x", PriceAmount = 1, Selected = true }, false, money) })
		expect(one ~= two and one == same, "signature follows what is drawn, not the selection")
	end)

	case("buttons: order, main button, disabled idle action", function()
		local function ids(list)
			local parts = {}
			for _, spec in ipairs(list) do
				table.insert(parts, spec.Id .. ":" .. spec.Variant .. (spec.Disabled and ":off" or ""))
			end
			return table.concat(parts, " ")
		end
		local dealership = { Id = "Dealership", Mode = "Dealership", Items = {}, Buttons = { Exit = { Visible = true } } }
		expect(ids(M._buttons(dealership, money)) == "Exit:Default Action:Buy:off", "dealership idle: " .. ids(M._buttons(dealership, money)))
		dealership.Action = { Text = "Buy", Amount = 5, Kind = "Buy" }
		expect(ids(M._buttons(dealership, money)) == "Exit:Default Action:Buy", "dealership selected")
		local slots = { Id = "Parts", Items = {}, Buttons = { Back = { Visible = true, Disabled = true }, Drive = { Visible = true } } }
		expect(ids(M._buttons(slots, money)) == "Back:Default:off Drive:Main", "slot list: Drive is the main button")
		local shop = { Id = "Parts", Items = {}, Source = { Selected = "Owned" }, Buttons = { Back = { Visible = true }, Drive = { Visible = true } } }
		expect(ids(M._buttons(shop, money)) == "Back:Default Drive:Default Action:Main:off", "owned list idle")
		local post = { Id = "PostPaint", Items = {}, Action = { Text = "Customise", Kind = "Main", IsNext = true }, Buttons = { Back = { Visible = false }, Drive = { Visible = false } } }
		expect(ids(M._buttons(post, money)) == "Action:Main", "post-purchase paint")
		local colour = { Id = "Paint", Items = {}, Paint = {}, Buttons = { Back = { Visible = true }, Drive = { Visible = true } } }
		expect(ids(M._buttons(colour, money)) == "Back:Default Drive:Main", "colour page has no action")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Mounted.
	------------------------------------------------------------------------------------------------------------
	local Metrics = env.Load(UIP .. "Kit.Metrics")
	local fixtures = env.Load(UIP .. "Dev.Fixtures.Garage")

	local PRESETS = {
		R1080 = function()
			return Metrics.Fixed({ Size = Vector2.new(1920, 1080), TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) })
		end,
		C844 = function()
			return Metrics.Fixed({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch", TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52) })
		end,
	}

	local function mount(preset, item, state)
		local ctx = PRESETS[preset]()
		local parent = env.Detached("Frame")
		parent.Size = UDim2.fromOffset(ctx.Size.X, ctx.Size.Y)
		Metrics.Bind(parent, ctx)
		local scope = env.Scope()
		local component = item.Mount(parent, table.clone(state.Props), scope, ctx)
		return component, parent, scope
	end

	local WATCHED = { "Visible", "Position", "Size", "AnchorPoint", "Text", "Image", "BackgroundTransparency", "ImageTransparency", "TextTransparency", "Active", "Name" }
	local function snapshot(root)
		local list = {}
		for _, instance in ipairs(root:GetDescendants()) do
			local record = { Instance = instance }
			for _, property in ipairs(WATCHED) do
				local ok, value = pcall(function()
					return (instance :: any)[property]
				end)
				if ok then
					record[property] = value
				end
			end
			table.insert(list, record)
		end
		return list
	end

	local function sameInstances(before, after)
		if #before ~= #after then
			return false, "descendants " .. #before .. " -> " .. #after
		end
		local seen = {}
		for _, record in ipairs(before) do
			seen[record.Instance] = true
		end
		for _, record in ipairs(after) do
			if not seen[record.Instance] then
				return false, "new instance " .. record.Instance:GetFullName()
			end
		end
		return true, nil
	end

	local function sameProperties(before, after)
		local byInstance = {}
		for _, record in ipairs(before) do
			byInstance[record.Instance] = record
		end
		for _, record in ipairs(after) do
			local old = byInstance[record.Instance]
			if old then
				for _, property in ipairs(WATCHED) do
					if old[property] ~= record[property] then
						return false, record.Instance:GetFullName() .. "." .. property
					end
				end
			end
		end
		return true, nil
	end

	local function find(root, name)
		for _, instance in ipairs(root:GetDescendants()) do
			if instance.Name == name then
				return instance
			end
		end
		return nil
	end

	local function isPaint(state)
		return string.find(state.Props.Page, "Paint", 1, true) ~= nil and state.Props.Page ~= "PaintOverview" and state.Props.Page ~= "PaintUnavailable"
	end

	for _, preset in ipairs({ "R1080", "C844" }) do
		for _, item in ipairs(fixtures) do
			for _, state in ipairs(item.States) do
				local label = preset .. " " .. item.Id .. "/" .. state.Id
				case(label .. ": mounts, within the ceiling, no ScreenGui, a second render writes nothing", function()
					local component, parent, scope = mount(preset, item, state)
					local count = #parent:GetDescendants()
					local ceiling = isPaint(state) and PAINT_BUDGET or BUDGET
					expect(state.Props.Modal ~= nil or count <= ceiling, "instances " .. count .. " over " .. ceiling)
					expect(parent:FindFirstChildWhichIsA("ScreenGui", true) == nil, "a ScreenGui was created")
					local before = snapshot(parent)
					component.View.Render("render")
					local after = snapshot(parent)
					local okInstances, why = sameInstances(before, after)
					expect(okInstances, "second render: " .. tostring(why))
					local okProperties, which = sameProperties(before, after)
					expect(okProperties, "second render wrote " .. tostring(which))
					scope:destroy()
				end)
			end
		end
	end

	local function itemById(id)
		for _, item in ipairs(fixtures) do
			if item.Id == id then
				return item
			end
		end
		error("no fixture item " .. id)
	end

	for _, preset in ipairs({ "R1080", "C844" }) do
		case(preset .. " dealership: reserved names and marks", function()
			local item = itemById("Garage.Dealership")
			local component, parent, scope = mount(preset, item, item.States[1])
			local browser = find(parent, "CanonicalGarageBrowser")
			expect(browser ~= nil and browser.Visible == true and browser.Active == false, "CanonicalGarageBrowser shows and does not block orbit")
			expect(find(parent, "CanonicalGarageWorkspace") == nil, "the customise page is not built while the dealership shows")
			for _, name in ipairs({ "Categories", "Stats", "Capacity", "VehicleScroller" }) do
				local target = find(browser, name)
				expect(target ~= nil and target:IsA("GuiObject"), name .. " under the dealership page")
			end
			local titles, buttons = 0, 0
			for _, instance in ipairs(browser:GetDescendants()) do
				if instance:IsA("TextLabel") and string.upper(instance.Text) == "DEALERSHIP" then
					titles += 1
				elseif instance:IsA("TextButton") and string.upper(instance.Text) == "DEALERSHIP" then
					buttons += 1
				end
			end
			expect(titles >= 1 and buttons == 0, "the text DEALERSHIP on a label and on no button")
			local cards = 0
			for _, instance in ipairs(find(browser, "VehicleScroller"):GetDescendants()) do
				if instance:IsA("GuiButton") and instance:GetAttribute("CanonicalGarageCard") == true then
					cards += 1
				end
			end
			expect(cards >= 6, "vehicle tiles are tutorial cards, got " .. cards)
			scope:destroy()
			expect(component ~= nil, "mounted")
		end)

		case(preset .. " customise: tabs carry the card ids, the body the page id; a tab change re-marks it", function()
			local item = itemById("Garage.Parts")
			local component, parent, scope = mount(preset, item, item.States[1])
			local workspace = find(parent, "CanonicalGarageWorkspace")
			expect(workspace ~= nil and workspace.Visible == true, "CanonicalGarageWorkspace shows")
			local wanted = { AddModules = false, UpgradeModules = false, PaintShop = false }
			local home, body = nil, nil
			for _, instance in ipairs(workspace:GetDescendants()) do
				local id = instance:GetAttribute("CanonicalGarageCardId")
				if id ~= nil and wanted[id] ~= nil and instance:IsA("GuiButton") and instance:GetAttribute("CanonicalGarageCard") == true then
					wanted[id] = true
				end
				if instance:GetAttribute("TutorialWorkspace") == true then
					if instance:GetAttribute("TutorialPageId") == "CustomisationHome" then
						home = instance
					elseif instance:GetAttribute("TutorialPageId") == "AddModules" then
						body = instance
					end
				end
			end
			expect(wanted.AddModules and wanted.UpgradeModules and wanted.PaintShop, "three tab buttons with the Classic card ids")
			expect(home ~= nil and body ~= nil, "tab bar is CustomisationHome, body is AddModules")
			expect(find(body, "TutorialCardScroller") ~= nil, "TutorialCardScroller under the page body")
			component.Model.SetPage("Upgrades")
			expect(body:GetAttribute("TutorialPageId") == "UpgradeModules", "body re-marked for the Upgrades tab")
			expect(find(body, "Categories") ~= nil and find(body, "UpgradeBudget") ~= nil, "Categories and UpgradeBudget under the body")
			component.Model.SetPage("PaintColour")
			expect(body:GetAttribute("TutorialPageId") == "PaintShop" and find(body, "Categories") ~= nil, "paint page")
			component.Model.SetPage("PostPaint")
			expect(body.Visible == false, "post-purchase paint shows no tutorial page")
			scope:destroy()
		end)

		case(preset .. " selection: nothing is created or destroyed", function()
			for _, pick in ipairs({ { "Garage.Dealership", 1, "C:aurora" }, { "Garage.Parts", 2, "M:sp1" }, { "Garage.Upgrades", 1, "u3" }, { "Garage.Paint", 3, "Paint" } }) do
				local item = itemById(pick[1])
				local component, parent, scope = mount(preset, item, item.States[pick[2]])
				local before = snapshot(parent)
				component.Model.SelectItem(pick[3])
				component.Model.SelectItem(pick[3])
				local okInstances, why = sameInstances(before, snapshot(parent))
				expect(okInstances, pick[1] .. ": " .. tostring(why))
				scope:destroy()
			end
		end)

		case(preset .. " page change: the other page is released, the layer follows the model", function()
			local item = itemById("Garage.Dealership")
			local component, parent, scope = mount(preset, item, item.States[1])
			component.Model.SetPage("PartsSlots")
			expect(find(parent, "CanonicalGarageBrowser") == nil and find(parent, "CanonicalGarageWorkspace") ~= nil, "one page at a time")
			component.Model.SetPage("Dealership")
			expect(find(parent, "CanonicalGarageBrowser") ~= nil and find(parent, "CanonicalGarageWorkspace") == nil, "and back")
			scope:destroy()
		end)
	end

	case("modals: the panel is CanonicalGarageModal; closing it tells the model once", function()
		local item = itemById("Garage.Modal.Properties")
		local component, parent, scope = mount("R1080", item, item.States[1])
		local modal = find(parent, "CanonicalGarageModal")
		expect(modal ~= nil and modal.Visible == true, "CanonicalGarageModal shows")
		component.Model.SetModal(nil)
		expect(modal.Visible == false, "hidden when the model has no modal")
		local closes = 0
		for _, call in ipairs(component.Model.Calls) do
			if call == "CloseModal" then
				closes += 1
			end
		end
		expect(closes == 0, "a close that came from the model is not sent back to it")
		scope:destroy()
	end)

	return results
end
