-- Pure tests for Garage.GarageModals: the text builders (Classic strings, prices passed through, nothing worked
-- out), and the sync rules over a fake model with the confirmations hosted in a detached frame.
return function(M, env)
	local results = {}
	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function money(amount)
		return "$" .. tostring(amount)
	end

	case("property rows: owned rows are locked and carry no price", function()
		local rows = M._propertyRows({
			{ Id = "P1", DisplayName = "Kanda Lift Bay", Owned = true, PriceAmount = 50000 },
			{ Id = "P2", DisplayName = "Shibuya Twin Bay", Owned = false, PriceAmount = 125000 },
		}, money)
		expect(#rows == 2 and rows[1].Key == "P1" and rows[1].Title == "Kanda Lift Bay", "row 1")
		expect(rows[1].Right == "OWNED" and rows[1].Locked == true, "owned")
		expect(rows[2].Right == "BUY $125000" and rows[2].Locked == false, "for sale: the catalogue price")
		expect(#M._propertyRows(nil, money) == 0, "no rows")
	end)

	case("property rows: a purchase needs an activation; building or selecting rows calls nothing", function()
		local bought = {}
		local rows = M._propertyRows({
			{ Id = "P1", DisplayName = "Kanda Lift Bay", Owned = true, PriceAmount = 50000 },
			{ Id = "P2", DisplayName = "Shibuya Twin Bay", Owned = false, PriceAmount = 125000 },
			{ Id = "P3", DisplayName = "Ginza Loft", Owned = false, PriceAmount = 300000 },
		}, money, function(key)
			table.insert(bought, key)
		end)
		expect(#bought == 0, "building the rows buys nothing")
		expect(rows[1].OnActivated == nil, "an owned row has no action")
		expect(type(rows[2].OnActivated) == "function" and type(rows[3].OnActivated) == "function", "rows for sale act on activation")
		for _, row in ipairs(rows) do
			expect(row.OnSelected == nil, "no row acts on selection")
		end
		rows[3].OnActivated()
		rows[3].OnActivated()
		expect(table.concat(bought, ",") == "P3,P3", "each activation asks once, for its own row: " .. table.concat(bought, ","))
		expect(M._propertyRows({ { Id = "P2", DisplayName = "x", Owned = false, PriceAmount = 1 } }, money)[1].OnActivated == nil, "no buy function, no action")
	end)

	case("panel size: the tokens on Regular; inside the screen on Compact", function()
		local width, height = M._panelSize(false, Vector2.new(1920, 1080), 1, 12)
		expect(width == 650 and height == 448, "Regular: ConfirmWidth by StatPanelHeight")
		width, height = M._panelSize(true, Vector2.new(844, 390), 1, 12)
		expect(width == 650 and height == 366, "844x390: " .. width .. "x" .. height)
		width, height = M._panelSize(true, Vector2.new(568, 320), 0.85, 10)
		expect(width * 0.85 <= 568 - 20 and height * 0.85 <= 320 - 20, "568x320 fits: " .. width .. "x" .. height)
	end)

	case("confirm text: the Classic move question; the vehicle purchase shows the price and nothing derived from it", function()
		local move = M._confirmText({ Kind = "Move", VehicleName = "Zephyr" }, money)
		expect(move.Title == "MOVE EQUIPPED MODULE", "title")
		expect(move.Body == "Equipping this module will remove it from Zephyr. Would you like to continue?", "body")
		expect(move.CancelText == "NO" and move.ConfirmText == "YES", "NO and YES")
		local buy = M._confirmText({ Kind = "BuyVehicle", VehicleName = "Zephyr", PriceAmount = 150000 }, money)
		expect(buy.Title == "BUY ZEPHYR?" and buy.Body == "PRICE $150000", "title and body")
		expect(buy.CancelText == "CANCEL" and buy.ConfirmText == "BUY $150000", "buttons")
		expect(string.find(buy.Body, "AFTER", 1, true) == nil, "no cash-after line")
	end)

	local function fakeModel()
		local model = { Calls = {} }
		local modal = nil
		function model.Modal()
			return modal
		end
		function model.Set(value)
			modal = value
		end
		function model.CloseModal()
			table.insert(model.Calls, "Close")
			modal = nil
		end
		function model.ResolveModal(confirmed)
			table.insert(model.Calls, "Resolve:" .. tostring(confirmed))
			modal = nil
		end
		function model.BuyProperty(id)
			table.insert(model.Calls, "Buy:" .. tostring(id))
		end
		return model
	end

	local Metrics = env.Load(UIP .. "Kit.Metrics")

	local function mount()
		local ctx = Metrics.Fixed({ Size = Vector2.new(1920, 1080), TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) })
		local root = env.Detached("Frame")
		root.Size = UDim2.fromOffset(1920, 1080)
		Metrics.Bind(root, ctx)
		local scope = env.Scope()
		local model = fakeModel()
		local modals = M.Mount(root, model, scope, { Host = root })
		return modals, model, root, scope
	end

	case("nothing is built until a modal is first shown", function()
		local modals, _, root, scope = mount()
		modals.Sync()
		expect(#root:GetChildren() == 0, "no instance before the first modal")
		scope:destroy()
	end)

	case("panel: cash then properties reuse one CanonicalGarageModal; a model-side close is not echoed", function()
		local modals, model, root, scope = mount()
		model.Set({ Kind = "Cash" })
		modals.Sync()
		local panel = root:FindFirstChild("CanonicalGarageModal")
		expect(panel ~= nil and panel.Visible == true, "panel shows")
		model.Set({ Kind = "Properties", Rows = { { Id = "P2", DisplayName = "Shibuya Twin Bay", Owned = false, PriceAmount = 125000 } } })
		modals.Sync()
		local panels = 0
		for _, child in ipairs(root:GetChildren()) do
			if child.Name == "CanonicalGarageModal" then
				panels += 1
			end
		end
		expect(panels == 1 and panel.Visible == true, "one panel, still open")
		expect(#model.Calls == 0, "drawing the list buys nothing and closes nothing: " .. table.concat(model.Calls, ","))
		expect(panel.ZIndex == 100, "the panel draws over a page built after it")
		local rows = 0
		for _, instance in ipairs(panel:GetDescendants()) do
			if instance:IsA("GuiButton") and instance.Visible and instance.Name == "ListRow" then
				rows += 1
			end
		end
		expect(rows == 1, "one property row, got " .. rows)
		model.Set(nil)
		modals.Sync()
		expect(panel.Visible == false and #model.Calls == 0, "closed without telling the model")
		modals.Destroy()
		modals.Destroy()
		scope:destroy()
	end)

	case("confirmation: a model-side close cancels it without resolving", function()
		local modals, model, _, scope = mount()
		model.Set({ Kind = "Move", VehicleName = "Zephyr" })
		modals.Sync()
		model.Set(nil)
		modals.Sync()
		expect(#model.Calls == 0, "no ResolveModal for a close the model made: " .. table.concat(model.Calls, ","))
		scope:destroy()
	end)

	return results
end
