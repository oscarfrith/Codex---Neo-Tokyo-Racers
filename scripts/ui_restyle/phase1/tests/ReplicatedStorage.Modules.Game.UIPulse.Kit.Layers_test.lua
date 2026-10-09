-- Pure tests for Kit.Layers (API.md section 13). Uses Layers.Check and Layers.Stage only; Create is never called.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."
	local Metrics = env.Load(KIT .. "Metrics")
	local Contracts = env.Load(KIT .. "Contracts")

	local results = {}
	local function case(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(err) or nil })
	end

	local function regular(width: number, height: number): any
		return Metrics.Fixed({ Size = Vector2.new(width, height), TouchEnabled = false, Input = "KeyboardAndMouse",
			TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58) })
	end
	local function compact(width: number, height: number): any
		return Metrics.Fixed({ Size = Vector2.new(width, height), TouchEnabled = true, Input = "Touch",
			TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52) })
	end

	local function expectOffset(label: string, value: UDim2, x: number, y: number)
		assert(value.X.Scale == 0 and value.Y.Scale == 0, label .. " uses scale")
		assert(value.X.Offset == x and value.Y.Offset == y,
			string.format("%s is (%d, %d), expected (%d, %d)", label, value.X.Offset, value.Y.Offset, x, y))
	end

	-- Stages a frame and checks the root box and each listed slot position.
	local function expectStage(ctx: any, frame: string, box: { number }, slots: { [string]: { number } })
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, ctx, frame)
		expectOffset(frame .. " Root.Position", layer.Root.Position, box[1], 0)
		expectOffset(frame .. " Root.Size", layer.Root.Size, box[2], box[3])
		for slotName, position in pairs(slots) do
			local slot = layer.Slot(slotName)
			assert(slot.Name == "Slot" .. slotName, slotName .. " has the wrong name")
			assert(slot.Parent == layer.Root, slotName .. " is not under Root")
			expectOffset(slotName .. " size", slot.Size, 0, 0)
			expectOffset(frame .. " " .. slotName, slot.Position, position[1], position[2])
		end
		layer.Destroy()
	end

	case("Check accepts every ladder name", function()
		for name in pairs(M.Order) do
			local ok, reason = M.Check(name)
			assert(ok == true and reason == nil, name .. ": " .. tostring(reason))
		end
	end)

	case("Check refuses trap names, unknown names and non-strings", function()
		for name in pairs(Contracts.Trap) do
			assert(M.Check(name) == false, name .. " was accepted")
		end
		for name in pairs(Contracts.TrapDescendants) do
			assert(M.Check(name) == false, name .. " was accepted")
		end
		for _, name in ipairs({ "DriveHUD", "TouchGui", "DrivingSpeedEffect", "RaceHud", "GarageRoot", "Nope", "" }) do
			local ok, reason = M.Check(name)
			assert(ok == false and type(reason) == "string", "'" .. name .. "' was accepted")
		end
		assert(M.Check(nil :: any) == false and M.Check(12 :: any) == false, "a non-string was accepted")
	end)

	case("ladder holds the Phase 1 rows, no trap name and no shared number", function()
		assert(M.Order.SharedTopNotification == 1100, "SharedTopNotification")
		assert(M.Order.SharedConfirmationOverlay == 1250, "SharedConfirmationOverlay")
		assert(M.Order.PulseGallery == 1400, "PulseGallery")
		local seen = {}
		for name, order in pairs(M.Order) do
			assert(Contracts.Trap[name] == nil, name .. " is a trap name")
			assert(seen[order] == nil, name .. " shares " .. order .. " with " .. tostring(seen[order]))
			seen[order] = name
		end
	end)

	case("Stage slot positions at R1080, Hud", function()
		expectStage(regular(1920, 1080), "Hud", { 0, 1920, 1080 }, {
			TopLeft = { 40, 70 }, TopRight = { 1880, 40 }, TopCentre = { 960, 68 },
			BottomRight = { 1880, 1052 }, BottomCentre = { 960, 1052 }, BottomRail = { 40, 1052 },
		})
	end)

	case("Stage slot positions at R1080, Menu", function()
		expectStage(regular(1920, 1080), "Menu", { 0, 1920, 1080 }, {
			TopLeft = { 68, 70 }, TopRight = { 1852, 40 }, TopCentre = { 960, 68 },
			BottomRight = { 1852, 1050 }, BottomCentre = { 960, 1050 }, BottomRail = { 68, 1050 },
		})
	end)

	case("Stage slot positions at C844, Hud", function()
		expectStage(compact(844, 390), "Hud", { 0, 844, 390 }, {
			TopLeft = { 40, 64 }, TopRight = { 804, 40 }, TopCentre = { 422, 62 },
			BottomRight = { 804, 362 }, BottomCentre = { 422, 362 }, BottomRail = { 40, 362 },
		})
	end)

	case("Stage at C844, Menu is a centred 2:1 block", function()
		expectStage(compact(844, 390), "Menu", { 32, 780, 390 }, {
			TopLeft = { 68, 64 }, TopRight = { 712, 40 }, TopCentre = { 390, 62 },
			BottomRight = { 712, 360 }, BottomCentre = { 390, 360 },
		})
	end)

	case("Hud stays inside a centred 21:9 box on an ultrawide", function()
		local ctx = regular(3440, 1440)
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, ctx, "Hud")
		expectOffset("Root.Position", layer.Root.Position, 40, 0)
		expectOffset("Root.Size", layer.Root.Size, 3360, 1440)
		local side = ctx.Px(40)
		expectOffset("TopRight", layer.Slot("TopRight").Position, 3360 - side, side)
		layer.Destroy()
	end)

	case("Scene and Bare fill the safe area; Bare has no slots", function()
		expectStage(regular(1920, 1080), "Scene", { 0, 1920, 1080 }, { TopLeft = { 40, 70 }, BottomRight = { 1880, 1052 } })
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, regular(1920, 1080), "Bare")
		expectOffset("Bare Root.Size", layer.Root.Size, 1920, 1080)
		assert(#layer.Root:GetChildren() == 0, "Bare has children")
		assert(pcall(layer.Slot, "TopLeft") == false, "Bare returned a slot")
		layer.Destroy()
	end)

	case("a staged layer has all eight slots, a Root named Root and no ScreenGui", function()
		local ctx = regular(1920, 1080)
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, ctx, "Hud")
		assert(layer.Gui == nil and layer.ScrimGui == nil and layer.ScrimRoot == nil, "a stage has a gui")
		assert(layer.Root.Name == "Root" and layer.Root.Parent == parent, "Root")
		assert(layer.Metrics == ctx, "Metrics is not the given context")
		assert(Metrics.Of(layer.Slot("TopLeft")) == ctx, "a slot does not resolve to the stage context")
		local names = { "TopLeft", "TopRight", "TopCentre", "RightColumn", "BottomRail", "BottomRight", "BottomCentre", "PromptStack" }
		for _, slotName in ipairs(names) do
			assert(layer.Root:FindFirstChild("Slot" .. slotName) == layer.Slot(slotName), slotName .. " is missing")
		end
		assert(#layer.Root:GetChildren() == #names, "unexpected children under Root")
		assert(layer.Slot("TopCentre").AnchorPoint == Vector2.new(0.5, 0), "TopCentre anchor")
		assert(layer.Slot("BottomRight").AnchorPoint == Vector2.new(1, 1), "BottomRight anchor")
		assert(pcall(layer.Slot, "Middle") == false, "an unknown slot was returned")
		assert(#parent:GetDescendants() == 1 + #names, "Stage made more than Root and slots")
		layer.Destroy()
	end)

	case("SetVisible writes Root.Visible; Destroy empties the parent and is repeat-safe", function()
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, regular(1920, 1080), "Menu")
		layer.SetVisible(false)
		assert(layer.Root.Visible == false, "Root still visible")
		layer.SetVisible(true)
		assert(layer.Root.Visible == true, "Root still hidden")
		layer.Destroy()
		layer.Destroy()
		assert(#parent:GetChildren() == 0, "Destroy left children")
	end)

	case("Stage refuses an unknown frame and a non-GuiObject parent", function()
		local parent = env.Detached("Frame")
		assert(pcall(M.Stage, parent, regular(1920, 1080), "Sideways") == false, "unknown frame accepted")
		assert(#parent:GetChildren() == 0, "a failed Stage left an instance")
		assert(pcall(M.Stage, env.Detached("Folder"), regular(1920, 1080), "Hud") == false, "Folder parent accepted")
	end)

	return results
end
