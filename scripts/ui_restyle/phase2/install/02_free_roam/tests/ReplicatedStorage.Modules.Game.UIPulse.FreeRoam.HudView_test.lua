-- Tests for FreeRoam.HudView: the pure helpers, then every gallery state of the family mounted on a detached stage at
-- R1080 and C844 over the fake model (API2 6.4): no error, inside the budget, a second Render and a sort change
-- create and destroy nothing. Needs kit v2 and the fixtures module; nothing is parented into the game tree.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
	local HUD_BUDGET = { Regular = 260, Compact = 220 } -- PC 5.2
	local MODAL_BUDGET = 120 -- PC 5.2, per modal or panel

	case("gauge size per class and arrangement", function()
		local space = { GaugeSize = 403, GaugeTouchSize = 240, CompactGauge = 92 }
		expect(M._gaugeSize(space, "Regular", "Standard") == 403, "Regular")
		expect(M._gaugeSize(space, "Regular", "TouchDrive") == 240, "Regular touch")
		expect(M._gaugeSize(space, "Compact", "TouchDrive") == 92, "Compact")
	end)

	case("status patch: vehicle known, unknown tier, no vehicle", function()
		local patch, key = M._statusPatch({ Tier = "S", Rating = 939.6 }, { Visible = true, Rank = 6 })
		expect(patch.Mode == "Vehicle" and patch.Tier == "S" and patch.Rating == 939 and patch.Rank == nil and key == "S|939", "vehicle; the rank stays on the minimap")
		patch, key = M._statusPatch(nil, { Visible = true, Rank = 6 })
		expect(patch.Mode == "CashOnly" and key == "", "no vehicle")
		patch = M._statusPatch({ Tier = "?", Rating = 1 }, { Visible = false, Rank = 1 })
		expect(patch.Mode == "CashOnly", "unknown tier")
	end)

	case("live cover: any modal hides the gauge and minimap; the vehicles panel does on Compact only", function()
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = false }, true) == false, "nothing open, Compact")
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = false }, false) == false, "nothing open, Regular")
		expect(M._liveCovered({ ActiveModal = "Settings", CarPanelOpen = false }, true) == true, "modal, Compact")
		expect(M._liveCovered({ ActiveModal = "Cash", CarPanelOpen = false }, false) == true, "modal, Regular")
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = true }, true) == true, "vehicles panel, Compact")
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = true }, false) == false, "vehicles panel, Regular: the gauge stays")
	end)

	case("row placement: a right-anchored row ends at its slot, a centred row straddles it", function()
		local width, x, y = M._rowPlace({ 80, 80, 80, 80, 80 }, 64, 8, 1, 0)
		expect(width == 432 and x == -432 and y == 0, "action bar: five tiles end at the slot")
		width, x, y = M._rowPlace({ 201, 240 }, 56, 10, 0.5, 1)
		expect(width == 451 and x == -226 and y == -56, "bottom buttons: centred, on the slot's bottom edge")
		width, x, y = M._rowPlace({}, 0, 8, 1, 1)
		expect(width == 0 and x == 0 and y == 0, "an empty row")
	end)

	local function mountAll(presetName, size, touch)
		local loaded, Metrics, items = pcall(function()
			return env.Load(UIP .. "Kit.Metrics"), env.Load(UIP .. "Dev.Fixtures.FreeRoam")
		end)
		if not loaded then
			case(presetName .. " / fixtures load", function() error(tostring(Metrics)) end)
			return
		end
		for _, item in ipairs(items) do
			for _, stateSpec in ipairs(item.States) do
				case(string.format("%s / %s / %s", presetName, item.Id, stateSpec.Id), function()
					local stage = env.Detached("Frame")
					stage.Name = "Stage"
					stage.Size = UDim2.fromOffset(size.X, size.Y)
					local ctx = Metrics.Fixed({ Size = size, TouchEnabled = touch, Input = touch and "Touch" or "KeyboardAndMouse" })
					Metrics.Bind(stage, ctx)
					local scope = env.Scope()
					local component = item.Mount(stage, stateSpec.Props, scope, ctx)
					local count = #stage:GetDescendants()
					local budget = HUD_BUDGET[ctx.Class]
					if stateSpec.Props.Modal or stateSpec.Props.CarPanel then budget += MODAL_BUDGET end
					expect(count <= budget, string.format("%d instances, budget %d", count, budget))

					local added, removed = 0, 0
					local addedConnection = stage.DescendantAdded:Connect(function() added += 1 end)
					local removedConnection = stage.DescendantRemoving:Connect(function() removed += 1 end)
					component.View.Render("Again")
					component.View.Render("Again")
					if stateSpec.Props.CarPanel then
						component.Model.SelectSort("A-Z")
						component.Model.SelectSort("RATING")
					end
					addedConnection:Disconnect()
					removedConnection:Disconnect()
					expect(added == 0 and removed == 0, string.format("churn: %d added, %d removed", added, removed))

					local state = component.Model.GetState()
					expect(component.Model.IsMinimapShowing() == (state.ShowMinimap and not state.Hidden), "minimap flag")
					component.Destroy()
					component.Destroy()
					scope:destroy()
				end)
			end
		end
	end

	mountAll("R1080", Vector2.new(1920, 1080), false)
	mountAll("C844", Vector2.new(844, 390), true)

	return results
end
