-- Pure tests for Kit.Layers (API.md section 13; API2 2.4). Uses Layers.Check and Layers.Stage only; Create is never called.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."
	local Metrics = env.Load(KIT .. "Metrics")
	local Contracts = env.Load(KIT .. "Contracts")

	local results = {}
	local function case(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(err) or nil })
	end

	-- The 19 slots of API2 2.4.
	local SLOTS = {
		"TopLeft", "TopLeftHud", "TopRight", "TopCentre", "TopCentreHud", "ActionBar", "HudStatus", "RightColumn",
		"SidePanel", "BottomRail", "RailButtons", "BottomRight", "BottomLeft", "BottomCentre", "Centre", "Minimap",
		"Gauge", "HudButtons", "PromptStack",
	}

	local function regular(width: number, height: number, touch: boolean?, chat: Vector2?): any
		return Metrics.Fixed({ Size = Vector2.new(width, height), TouchEnabled = touch == true,
			Input = if touch then "Touch" else "KeyboardAndMouse",
			TopBarHeight = 58, TopBarKeepOut = Vector2.new(208, 58), ChatKeepOut = chat })
	end
	local function compact(width: number, height: number, touch: boolean?): any
		return Metrics.Fixed({ Size = Vector2.new(width, height), TouchEnabled = touch ~= false,
			Input = if touch ~= false then "Touch" else "KeyboardAndMouse",
			TopBarHeight = 52, TopBarKeepOut = Vector2.new(120, 52) })
	end

	local function expectOffset(label: string, value: UDim2, x: number, y: number)
		assert(value.X.Scale == 0 and value.Y.Scale == 0, label .. " uses scale")
		assert(value.X.Offset == x and value.Y.Offset == y,
			string.format("%s is (%d, %d), expected (%d, %d)", label, value.X.Offset, value.Y.Offset, x, y))
	end

	-- Stages a frame and checks the root box and each listed slot: { x, y, anchorX?, anchorY?, width?, height? }.
	-- A slot listed without a size must be zero-size.
	local function expectStage(ctx: any, frame: string, box: { number }, slots: { [string]: { number } })
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, ctx, frame)
		expectOffset(frame .. " Root.Position", layer.Root.Position, box[1], 0)
		expectOffset(frame .. " Root.Size", layer.Root.Size, box[2], box[3])
		for slotName, want in pairs(slots) do
			local slot = layer.Slot(slotName)
			assert(slot.Name == "Slot" .. slotName, slotName .. " has the wrong name")
			assert(slot.Parent == layer.Root, slotName .. " is not under Root")
			expectOffset(frame .. " " .. slotName, slot.Position, want[1], want[2])
			if want[3] ~= nil then
				assert(slot.AnchorPoint == Vector2.new(want[3], want[4]),
					string.format("%s %s anchor is (%s, %s)", frame, slotName, tostring(slot.AnchorPoint.X), tostring(slot.AnchorPoint.Y)))
			end
			expectOffset(frame .. " " .. slotName .. " size", slot.Size, want[5] or 0, want[6] or 0)
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
		for _, name in ipairs({ "DriveHUD", "TouchGui", "DrivingSpeedEffect", "RaceHud", "GarageRoot", "Nope", "",
			"MobileFreeRoamHud_Phase1", "GarageEntranceStatus" }) do
			local ok, reason = M.Check(name)
			assert(ok == false and type(reason) == "string", "'" .. name .. "' was accepted")
		end
		assert(M.Check(nil :: any) == false and M.Check(12 :: any) == false, "a non-string was accepted")
	end)

	case("ladder holds the Phase 1 rows, no trap name and no shared number", function()
		assert(M.Order.SharedTopNotification == 1100, "SharedTopNotification")
		assert(M.Order.SharedConfirmationOverlay == 1250, "SharedConfirmationOverlay")
		assert(M.Order.PulseGallery == 1400, "PulseGallery")
		local phase1 = {
			CanonicalGarageGui = 40, OwnedGarageInteriorHUD = 58, RaceRouteGuide_Phase5 = 78, ActivityHud = 84,
			DesktopFreeRoamHud = 85, FullMap = 90, MobileDriveControls_Phase1 = 96, SharedInRaceHUD = 155,
			RaceBrowser = 170, OwnedGarageBrowser = 171, RaceEntryPresentation = 180, RaceQueueBanner = 190,
			RaceCountdown = 205, UnifiedRaceResults = 220, Onboarding = 990,
		}
		for name, order in pairs(phase1) do
			assert(M.Order[name] == order, name .. " moved to " .. tostring(M.Order[name]))
		end
		local seen = {}
		for name, order in pairs(M.Order) do
			assert(Contracts.Trap[name] == nil, name .. " is a trap name")
			assert(seen[order] == nil, name .. " shares " .. order .. " with " .. tostring(seen[order]))
			seen[order] = name
		end
	end)

	case("ladder additions of API2 2.4", function()
		local added = {
			SharedInRaceHUDScrim = 57, PulseWorldPrompts = 80, PulseEventCard = 81, DesktopFreeRoamHudLive = 86, ActivityHudLive = 87,
			FullMapScrim = 89, FullMapLive = 91, SharedInRaceHUDLive = 156, OwnedGarageBrowserScrim = 168,
			RaceBrowserScrim = 169, RaceEntryPresentationScrim = 179, UnifiedRaceResultsScrim = 219,
			CanonicalGarageGuiScrim = 39, CanonicalGarageGuiLive = 41, OwnedGarageInteriorHUDLive = 59,
			LoadingSafeContentScrim = 1000, LoadingSafeContent = 1001,
		}
		local count = 0
		for name, order in pairs(added) do
			assert(M.Order[name] == order, name .. " is " .. tostring(M.Order[name]) .. ", expected " .. order)
			count += 1
		end
		local total = 0
		for _ in pairs(M.Order) do
			total += 1
		end
		assert(total == 18 + count, "ladder has " .. total .. " rows")
		assert(M.Order.GarageEntranceStatus == nil and M.Order.MobileFreeRoamHud_Phase1 == nil, "a gui that is not created has a row")
		-- A scrim with no row of its own still has a free number one below its base.
		assert(M.Order.OnboardingScrim == nil and M.Order.Onboarding - 1 == 989, "Onboarding scrim")
		for name, order in pairs(M.Order) do
			assert(order ~= 989 or name == "OnboardingScrim", name .. " takes the Onboarding scrim number")
		end
	end)

	case("Stage slot positions at R1080, Hud, Standard", function()
		expectStage(regular(1920, 1080), "Hud", { 0, 1920, 1080 }, {
			TopLeft = { 40, 70, 0, 0 }, TopLeftHud = { 40, 70, 0, 0 }, TopRight = { 1880, 40, 1, 0 },
			TopCentre = { 960, 68, 0.5, 0 }, TopCentreHud = { 960, 40, 0.5, 0 }, ActionBar = { 1880, 116, 1, 0 },
			HudStatus = { 1880, 40, 1, 0 }, RightColumn = { 1880, 186, 1, 0, 480, 866 },
			SidePanel = { 0, 0, 0, 0, 600, 1080 }, BottomRail = { 40, 1052, 0, 1, 1880, 0 },
			RailButtons = { 1880, 780, 1, 1 }, BottomRight = { 1880, 1052, 1, 1 }, BottomLeft = { 40, 1052, 0, 1 },
			BottomCentre = { 960, 1052, 0.5, 1 }, Centre = { 960, 540, 0.5, 0.5 }, Minimap = { 58, 1000, 0, 1 },
			Gauge = { 1880, 1052, 1, 1 }, HudButtons = { 960, 1052, 0.5, 1 }, PromptStack = { 960, 750, 0.5, 1 },
		})
	end)

	case("Stage slot positions at R1080, Menu", function()
		expectStage(regular(1920, 1080), "Menu", { 0, 1920, 1080 }, {
			TopLeft = { 68, 70 }, TopRight = { 1852, 67, 1, 0 }, TopCentre = { 960, 68 }, TopCentreHud = { 960, 40 },
			HudStatus = { 1852, 67 }, RightColumn = { 1852, 152, 1, 0, 480, 898 },
			BottomRight = { 1852, 1050 }, BottomCentre = { 960, 1050 }, BottomLeft = { 68, 1050, 0, 1 },
			BottomRail = { 68, 1050, 0, 1, 1852, 0 }, RailButtons = { 1852, 778, 1, 1 },
			SidePanel = { 0, 0, 0, 0, 600, 1080 }, PromptStack = { 960, 750 },
		})
	end)

	case("Stage at R1080, Hud, TouchDrive: minimap top right, gauge centred, column under the minimap", function()
		expectStage(regular(1920, 1080, true), "Hud", { 0, 1920, 1080 }, {
			Minimap = { 1862, 186, 1, 0 }, Gauge = { 960, 1052, 0.5, 1 }, HudButtons = { 830, 1052, 1, 1 },
			RightColumn = { 1880, 555, 1, 0, 480, 497 }, HudStatus = { 1880, 40, 1, 0 }, TopRight = { 1880, 40, 1, 0 },
			ActionBar = { 1880, 116, 1, 0 }, TopLeft = { 40, 70 },
		})
		-- Only Hud moves its column for the minimap.
		expectStage(regular(1920, 1080, true), "Menu", { 0, 1920, 1080 }, { RightColumn = { 1852, 152, 1, 0, 480, 898 } })
	end)

	case("TopLeftHud starts under the chat window while it shows", function()
		expectStage(regular(1920, 1080, false, Vector2.new(483, 286)), "Hud", { 0, 1920, 1080 }, {
			TopLeftHud = { 40, 298, 0, 0 }, TopLeft = { 40, 70, 0, 0 },
		})
		-- A chat window shorter than the top bar changes nothing.
		expectStage(regular(1920, 1080, false, Vector2.new(483, 40)), "Hud", { 0, 1920, 1080 }, { TopLeftHud = { 40, 70 } })
	end)

	case("Stage slot positions at C844, Hud, TouchDrive", function()
		expectStage(compact(844, 390), "Hud", { 0, 844, 390 }, {
			TopLeft = { 12, 8, 0, 0 }, TopLeftHud = { 12, 64, 0, 0 }, TopRight = { 832, 8, 1, 0 },
			TopCentre = { 422, 62, 0.5, 0 }, TopCentreHud = { 422, 8, 0.5, 0 }, ActionBar = { 422, 8, 0.5, 0 },
			HudStatus = { 832, 116, 1, 0 }, RightColumn = { 832, 45, 1, 0, 176, 337 },
			SidePanel = { 832, 8, 1, 0, 232, 374 }, BottomRail = { 12, 382, 0, 1, 832, 0 },
			RailButtons = { 832, 308, 1, 1 }, BottomRight = { 832, 382, 1, 1 }, BottomLeft = { 12, 382, 0, 1 },
			BottomCentre = { 422, 382, 0.5, 1 }, Centre = { 422, 195, 0.5, 0.5 }, Minimap = { 824, 16, 1, 0 },
			Gauge = { 422, 382, 0.5, 1 }, HudButtons = { 366, 382, 1, 1 }, PromptStack = { 422, 270, 0.5, 1 },
		})
	end)

	case("Stage at C844, Hud, Standard: minimap bottom left with no label band, status top right", function()
		expectStage(compact(844, 390, false), "Hud", { 0, 844, 390 }, {
			Minimap = { 30, 382, 0, 1 }, HudStatus = { 832, 8, 1, 0 }, Gauge = { 832, 382, 1, 1 },
			HudButtons = { 422, 382, 0.5, 1 }, ActionBar = { 422, 8, 0.5, 0 },
		})
	end)

	case("Stage at C844, Menu is a centred 2:1 block with the Compact margins", function()
		expectStage(compact(844, 390), "Menu", { 32, 780, 390 }, {
			TopLeft = { 12, 8 }, TopRight = { 768, 8 }, TopCentre = { 390, 62 },
			BottomRight = { 768, 382 }, BottomCentre = { 390, 382 }, BottomRail = { 12, 382, 0, 1, 768, 0 },
			SidePanel = { 768, 8, 1, 0, 232, 374 },
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

	case("Scene uses the Menu margins and fills the safe area; Bare has no slots", function()
		expectStage(regular(1920, 1080), "Scene", { 0, 1920, 1080 }, {
			TopLeft = { 68, 70 }, BottomRight = { 1852, 1050 }, TopRight = { 1852, 67 }, RightColumn = { 1852, 152, 1, 0, 480, 898 },
		})
		expectStage(regular(3440, 1440), "Scene", { 0, 3440, 1440 }, {})
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, regular(1920, 1080), "Bare")
		expectOffset("Bare Root.Size", layer.Root.Size, 1920, 1080)
		assert(#layer.Root:GetChildren() == 0, "Bare has children")
		assert(pcall(layer.Slot, "TopLeft") == false, "Bare returned a slot")
		layer.Destroy()
	end)

	case("a staged layer has all nineteen slots, a Root named Root and no ScreenGui", function()
		local ctx = regular(1920, 1080)
		local parent = env.Detached("Frame")
		local layer = M.Stage(parent, ctx, "Hud")
		assert(layer.Gui == nil and layer.ScrimGui == nil and layer.ScrimRoot == nil, "a stage has a gui")
		assert(layer.Root.Name == "Root" and layer.Root.Parent == parent, "Root")
		assert(layer.Metrics == ctx, "Metrics is not the given context")
		assert(Metrics.Of(layer.Slot("TopLeft")) == ctx, "a slot does not resolve to the stage context")
		assert(#SLOTS == 19, "the test lists " .. #SLOTS .. " slots")
		for _, slotName in ipairs(SLOTS) do
			assert(layer.Root:FindFirstChild("Slot" .. slotName) == layer.Slot(slotName), slotName .. " is missing")
		end
		assert(#layer.Root:GetChildren() == #SLOTS, "unexpected children under Root")
		assert(layer.Slot("TopCentre").AnchorPoint == Vector2.new(0.5, 0), "TopCentre anchor")
		assert(layer.Slot("BottomRight").AnchorPoint == Vector2.new(1, 1), "BottomRight anchor")
		assert(pcall(layer.Slot, "Middle") == false, "an unknown slot was returned")
		assert(#parent:GetDescendants() == 1 + #SLOTS, "Stage made more than Root and slots")
		layer.Destroy()
	end)

	case("only RightColumn, SidePanel and BottomRail are sized; no slot sinks input or draws", function()
		local sized = { RightColumn = true, SidePanel = true, BottomRail = true }
		for _, ctx in ipairs({ regular(1920, 1080), regular(1280, 720, true), compact(844, 390), compact(568, 320, false) }) do
			for _, frame in ipairs({ "Hud", "Menu", "Scene" }) do
				local parent = env.Detached("Frame")
				local layer = M.Stage(parent, ctx, frame)
				for _, slotName in ipairs(SLOTS) do
					local slot = layer.Slot(slotName)
					local size = slot.Size
					assert(size.X.Scale == 0 and size.Y.Scale == 0, slotName .. " size uses scale")
					assert(size.X.Offset % 1 == 0 and size.Y.Offset % 1 == 0, slotName .. " size is not whole pixels")
					assert(slot.Position.X.Offset % 1 == 0 and slot.Position.Y.Offset % 1 == 0, slotName .. " is not on a whole pixel")
					assert(size.X.Offset >= 0 and size.Y.Offset >= 0, slotName .. " has a negative size")
					if sized[slotName] then
						assert(size.X.Offset > 0, slotName .. " has no width in " .. frame)
					else
						assert(size.X.Offset == 0 and size.Y.Offset == 0, slotName .. " is sized")
					end
					assert(slot.BackgroundTransparency == 1 and slot.Active == false, slotName .. " draws or sinks input")
				end
				layer.Destroy()
			end
		end
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
