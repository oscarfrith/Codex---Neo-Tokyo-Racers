-- Pure tests for Kit.Minimap. No yield, nothing parented into the game tree, every component destroyed before return.
return function(M, env)
	local results = {}
	local cleanups = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		for index = #cleanups, 1, -1 do pcall(cleanups[index]) end
		table.clear(cleanups)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local Metrics = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics")
	local Tokens = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens")
	local Sprites = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Sprites")

	local REGULAR = Vector2.new(1920, 1080)
	local COMPACT = Vector2.new(844, 390)
	local RANK = Sprites.Rings.Rank

	local function stage(size, touch)
		local frame = env.Detached("Frame")
		Metrics.Bind(frame, Metrics.Fixed({ Size = size, TouchEnabled = touch == true,
			Input = if touch then "Touch" else "KeyboardAndMouse" }))
		return frame
	end

	-- The Core.ConnectionScope shape, without requiring a module from the place.
	local function newScope()
		local items = {}
		local scope = {}
		function scope.connect(_, signal, callback)
			local connection = signal:Connect(callback)
			table.insert(items, connection)
			return connection
		end
		function scope.add(_, item)
			table.insert(items, item)
			return item
		end
		function scope.task(self, callback, ...)
			return self:add(task.spawn(callback, ...))
		end
		function scope.destroy(_)
			for index = #items, 1, -1 do
				local item = items[index]
				local kind = typeof(item)
				if kind == "RBXScriptConnection" then item:Disconnect()
				elseif kind == "Instance" then item:Destroy()
				elseif kind == "function" then pcall(item)
				elseif kind == "thread" then
					if coroutine.status(item) ~= "dead" then pcall(task.cancel, item) end
				elseif kind == "table" then
					local method = item.destroy or item.Destroy or item.Disconnect
					if method then pcall(method, item) end
				end
			end
			table.clear(items)
		end
		table.insert(cleanups, function() scope:destroy() end)
		return scope
	end

	local function minimapOn(size, touch, props)
		local parent = stage(size, touch)
		local scope = newScope()
		local minimap = M.New(parent, props or {}, scope)
		table.insert(cleanups, minimap.Destroy)
		return minimap, parent, scope
	end

	-- Descendants plus the root, without Content's children and the text size locks (API2 3.3).
	local function budgetOf(minimap)
		local total = 1
		for _, item in ipairs(minimap.Instance:GetDescendants()) do
			if not item:IsA("UITextSizeConstraint") and not item:IsDescendantOf(minimap.Content) then total += 1 end
		end
		return total
	end

	-- A mask at `rotation` shows the angles (rotation + 90, rotation + 270).
	local function shows(rotation, theta)
		return math.cos(math.rad(theta - rotation)) < -1e-9
	end

	------------------------------------------------------------------------------------------------------------------
	-- Pure maths
	------------------------------------------------------------------------------------------------------------------

	case("rank arc: Regular runs 90 degrees from 9 o'clock, Compact from 165 to 285", function()
		local start, sweep = M._rankArc("Regular")
		expect(start == RANK.StartDeg and sweep == RANK.SweepRegular, "Regular")
		expect(start == 180 and sweep == 90, "Regular values")
		start, sweep = M._rankArc("Compact")
		expect(start == 165 and sweep == 120, "Compact values")
	end)

	case("rank reveal: mask rotations, quantised to half a degree", function()
		local left, right, degrees = M._sweep(180, 90, 0)
		expect(left == 200 and right == -20 and degrees == 0, "empty: parked")
		left, right, degrees = M._sweep(180, 90, 0.5)
		expect(left == 180 + 45 + 90 and right == -20 and degrees == 45, "half of the Regular arc")
		left, right = M._sweep(180, 90, 1)
		expect(left == 380 and right == -20, "the Regular arc ends at 12 o'clock: left full, right never used")
		left, right, degrees = M._sweep(165, 120, 1)
		expect(left == 380 and right == 15 and degrees == 120, "the Compact arc ends 15 degrees past 12 o'clock")
		left, right = M._sweep(165, 120, 0.875)
		expect(left == 380 and right == -20, "exactly at 12 o'clock the right window is still empty")
		left, right, degrees = M._sweep(180, 90, 0.4267)
		expect(degrees == 38.5 and left == 180 + 38.5 + 90, "38.4 degrees is written as 38.5")
		left, right, degrees = M._sweep(180, 90, 0 / 0)
		expect(degrees == 0, "not a number is empty")
		for step = 0, 400 do
			local l, r = M._sweep(165, 120, step / 400)
			expect((l * 2) % 1 == 0 and (r * 2) % 1 == 0, "half-degree values at " .. step)
		end
	end)

	case("rank reveal: the windows light exactly the arc up to the fill angle", function()
		-- Regular: one window, the top-left quarter (180..270). Compact: left window from 165, right window the
		-- top-right quarter.
		for _, arc in ipairs({ { 180, 90 }, { 165, 120 } }) do
			local start, sweep = arc[1], arc[2]
			for step = 0, 24 do
				local left, right, degrees = M._sweep(start, sweep, step / 24)
				local fill = start + degrees
				local theta = start + 0.3
				while theta < 360 do
					local lit
					if theta < 270 then lit = shows(left, theta) else lit = shows(right, theta) end
					local want = theta < fill
					expect(lit == want, string.format("arc from %d, fraction %d/24: angle %.2f should be %s", start, step,
						theta, if want then "lit" else "dark"))
					theta += 1.25
				end
			end
		end
	end)

	case("heading and arrow: quantised to half a degree in 0..360", function()
		expect(M._quantise(12.26) == 12.5 and M._quantise(12.24) == 12, "rounded")
		expect(M._quantise(359.9) == 0 and M._quantise(360) == 0, "wraps to 0")
		expect(M._quantise(-90) == 270, "negative wraps")
		expect(M._quantise(0 / 0) == 0 and M._quantise(nil) == 0, "not a number")
	end)

	case("north marker: on the rim, map north turned by the map rotation", function()
		local x, y = M._northOffset(0, 100)
		expect(x == 0 and y == -100, "no rotation: north is up")
		x, y = M._northOffset(90, 100)
		expect(x == 100 and y == 0, "a quarter turn clockwise: north is right")
		x, y = M._northOffset(180, 100)
		expect(x == 0 and y == 100, "half a turn: north is down")
		x, y = M._northOffset(270, 100)
		expect(x == -100 and y == 0, "three quarters: north is left")
	end)

	------------------------------------------------------------------------------------------------------------------
	-- Component
	------------------------------------------------------------------------------------------------------------------

	local function countClass(root, className)
		local count = 0
		for _, item in ipairs(root:GetDescendants()) do
			if item.ClassName == className then count += 1 end
		end
		return count
	end

	case("minimap, Regular: a round frame named Minimap, within budget", function()
		local minimap, parent = minimapOn(REGULAR, false, { Label = "Akane District" })
		local root = minimap.Instance
		expect(#parent:GetChildren() == 1 and root.Parent == parent, "one root")
		expect(root:IsA("TextButton") and root.Name == "Minimap" and root.Text == "", "a TextButton named Minimap")
		expect(root.Selectable == false and root.Active == false, "not a focus stop; not clickable without OnActivated")
		local side = Tokens.Space.MinimapSize - Tokens.Space.MinimapSize % 2
		expect(root.Size == UDim2.fromOffset(side, side), "the circle's box, an even MinimapSize at 1080")

		local content = minimap.Content
		expect(content:IsA("Frame") and content.Name == "Content" and content.ClipsDescendants, "Content is a clipping Frame")
		expect(countClass(root, "CanvasGroup") == 1, "exactly one CanvasGroup")
		local round = root:FindFirstChild("Round")
		expect(round ~= nil and round:IsA("CanvasGroup") and content.Parent == round, "Content sits in the round clip")
		expect(round.Size == UDim2.fromOffset(side, side), "the clip is the circle's box")
		local corner = round:FindFirstChildOfClass("UICorner")
		expect(corner ~= nil and corner.CornerRadius == UDim.new(0.5, 0), "a full-radius corner makes the circle")
		expect(round:FindFirstChild("Vignette") ~= nil, "the vignette is clipped with the content")
		expect(minimap.Overlay:IsA("Frame") and minimap.Overlay.Parent == root and not minimap.Overlay.ClipsDescendants,
			"Overlay is unclipped, on the root")
		expect(minimap.Overlay.ZIndex > round.ZIndex, "Overlay draws above the clip and its vignette")

		for _, name in ipairs({ "Ring", "RankLeft", "RankNumber", "RankLabel", "North", "Arrow", "Label", "Overlay" }) do
			expect(root:FindFirstChild(name) ~= nil, name .. " exists")
		end
		expect(root:FindFirstChild("RankRight") == nil, "the Regular arc needs no right window")
		expect(root:FindFirstChild("RankBadge") == nil, "no badge on Regular")
		local ringSide = root.Ring.Size.X.Offset
		expect(ringSide % 2 == 0 and math.abs(ringSide - side * Sprites.Rings.Minimap.FrameScale) <= 1, "ring frame scale")
		expect(root.Ring.Position == UDim2.fromOffset(side / 2, side / 2), "ring on the map centre")

		local rankLeft = root.RankLeft
		expect(rankLeft.ClipsDescendants, "the rank window clips")
		expect(rankLeft:FindFirstChild("RankTrack") ~= nil and rankLeft:FindFirstChild("RankFill") ~= nil, "track and fill")
		expect(rankLeft.RankTrack.ImageTransparency == 1 - Tokens.Opacity.Panel, "track at the panel opacity")
		local rankSide = rankLeft.RankFill.Size.X.Offset
		expect(rankLeft.Size == UDim2.fromOffset(rankSide / 2, rankSide / 2), "Regular: the top-left quarter of the rank frame")
		expect(rankLeft.Position.X.Offset == (side - rankSide) / 2, "the rank frame shares the map centre")
		expect(rankLeft.RankFill:FindFirstChild("Mask") ~= nil and rankLeft.RankTrack:FindFirstChild("Mask") == nil,
			"only the fill is masked in the left window")

		expect(root.Label.Text == "AKANE DISTRICT" and root.Label.Visible, "label upper-cased, shown under the frame")
		expect(root.Label.Position.Y.Offset >= side, "the label is in the band below the frame")
		expect(budgetOf(minimap) <= 30, "budget 30, got " .. budgetOf(minimap))
	end)

	case("minimap, Compact: default size, badge, arc past 12 o'clock, no label band", function()
		local minimap = minimapOn(COMPACT, true, { Label = "Akane District" })
		local root = minimap.Instance
		expect(root.Size == UDim2.fromOffset(Tokens.Space.CompactMinimap, Tokens.Space.CompactMinimap), "CompactMinimap")
		expect(root:FindFirstChild("RankBadge") ~= nil and root:FindFirstChild("RankLabel") == nil, "badge, no caption")
		local right = root:FindFirstChild("RankRight")
		expect(right ~= nil and right.ClipsDescendants and right.Visible, "right window for the arc past 12 o'clock")
		local _, trackEnd = M._sweep(165, 120, 1)
		expect(right.RankTrack.Mask.Rotation == trackEnd, "the track ends where the sweep ends")
		expect(right.RankFill.Mask.Rotation == -20, "the fill starts empty")
		local rankLeft = root.RankLeft
		expect(rankLeft.Size.Y.Offset > rankLeft.Size.X.Offset, "the left window reaches below 9 o'clock to the arc's start")
		expect(root.RankBadge.Position == root.RankNumber.Position, "the number sits on the badge")
		expect(root.RankBadge.Position.X.Offset < 0, "the badge is on the arc, left of the frame")
		expect(root.Label.Visible == false, "no label band on Compact")
		expect(budgetOf(minimap) <= 30, "budget 30, got " .. budgetOf(minimap))
		minimap.SetRank(6, 1)
		local left, fillRight = M._sweep(165, 120, 1)
		expect(rankLeft.RankFill.Mask.Rotation == left and right.RankFill.Mask.Rotation == fillRight, "full on both windows")
	end)

	case("minimap: in a slot the root takes the slot's anchor", function()
		local slot = stage(REGULAR, false)
		slot.Name = "SlotMinimap"
		slot.AnchorPoint = Vector2.new(0, 1)
		local minimap = M.New(slot, {}, newScope())
		table.insert(cleanups, minimap.Destroy)
		expect(minimap.Instance.AnchorPoint == Vector2.new(0, 1), "bottom-left anchor copied")
	end)

	case("minimap: setters write on change only", function()
		local minimap = minimapOn(REGULAR, false)
		local root = minimap.Instance
		expect(minimap._writes() == 0, "no writes at build")
		minimap.SetRank(0, 0)
		minimap.SetHeading(0)
		minimap.SetArrow(0)
		expect(minimap._writes() == 0, "the build values write nothing")

		minimap.SetRank(6, 0.42)
		local first = minimap._writes()
		expect(first == 2, "the number and one mask, got " .. first)
		local left = M._sweep(180, 90, 0.42)
		expect(root.RankLeft.RankFill.Mask.Rotation == left, "fill mask at 42%")
		minimap.SetRank(6, 0.42)
		minimap.SetRank(6.2, 0.4201)
		expect(minimap._writes() == first, "the same rank and half degree write nothing")
		minimap.SetRank(7, 0.42)
		expect(minimap._writes() == first + 1, "a new rank is one write")

		local before = minimap._writes()
		local north = root.North.Position
		minimap.SetHeading(180)
		expect(minimap._writes() == before + 1 and root.North.Position ~= north, "the north marker moves")
		local side = root.Size.X.Offset
		expect(root.North.Position == UDim2.fromOffset(side / 2, side), "half a turn puts north at the bottom of the rim")
		minimap.SetHeading(180.1)
		minimap.SetHeading(-180)
		minimap.SetHeading(540)
		expect(minimap._writes() == before + 1, "the same half degree, in any turn, writes nothing")

		before = minimap._writes()
		minimap.SetArrow(45)
		expect(minimap._writes() == before + 1 and root.Arrow.Rotation == 45, "arrow turned")
		minimap.SetArrow(45.2)
		minimap.SetArrow(405)
		expect(minimap._writes() == before + 1, "the same half degree writes nothing")
		minimap.SetArrow(45.3)
		expect(root.Arrow.Rotation == 45.5, "half-degree steps")
	end)

	case("minimap: SetRound keeps Content and moves it between the round clip and the root", function()
		local minimap = minimapOn(REGULAR, false)
		local root = minimap.Instance
		local content = minimap.Content
		local child = env.Detached("Frame")
		child.Name = "MapCanvas"
		child.Parent = content
		minimap.SetRound(false)
		expect(minimap.Content == content and content.Parent == root, "the same Content, now a plain clipping frame on the root")
		expect(content.ClipsDescendants == true and child.Parent == content, "still clipping, children kept")
		expect(root.Round.Visible == false and root:FindFirstChild("Vignette") ~= nil, "round clip hidden, vignette moved")
		minimap.SetRound(true)
		expect(content.Parent == root.Round and root.Round.Visible and child.Parent == content, "back in the round clip")
		expect(countClass(root, "CanvasGroup") == 1, "still one CanvasGroup")
		child.Parent = nil
	end)

	case("minimap: Round = false builds no CanvasGroup and no corner on the content", function()
		local minimap = minimapOn(REGULAR, false, { Round = false })
		local root = minimap.Instance
		expect(countClass(root, "CanvasGroup") == 0, "no CanvasGroup")
		expect(minimap.Content.Parent == root and minimap.Content.ClipsDescendants, "a plain clipping frame")
		minimap.Set({ Round = true })
		expect(countClass(root, "CanvasGroup") == 1 and minimap.Content.Parent == root.Round, "built when asked")
	end)

	case("minimap: label, rank visibility and OnActivated", function()
		local calls = 0
		local minimap = minimapOn(REGULAR, false, { OnActivated = function() calls += 1 end })
		local root = minimap.Instance
		expect(root.Active == true, "clickable with OnActivated")
		expect(root.Label.Visible == false, "no label text, no label")
		minimap.SetLabel("Kanda two-bay")
		expect(root.Label.Text == "KANDA TWO-BAY" and root.Label.Visible, "SetLabel")
		minimap.SetLabel("")
		expect(root.Label.Visible == false, "an empty label hides")
		minimap.SetRank(128, 0.5)
		minimap.Set({ ShowRank = false })
		expect(root.RankLeft.Visible == false and root.RankNumber.Visible == false and root.RankLabel.Visible == false,
			"rank arc, number and caption hidden")
		minimap.Set({ ShowRank = true })
		expect(root.RankLeft.Visible and root.RankNumber.Visible and root.RankLabel.Visible, "shown again")
		minimap.Set({ OnActivated = false })
		expect(root.Active == false, "OnActivated = false makes the frame inert")
		expect(calls == 0, "nothing called without a click")
	end)

	case("minimap: Set unchanged writes nothing, unknown key errors, Destroy is repeat-safe", function()
		local minimap, parent = minimapOn(REGULAR, false, { Name = "Minimap", LayoutOrder = 4, Label = "Akane" })
		local root = minimap.Instance
		local snapshot = { root.Name, root.LayoutOrder, root.Visible, root.Size, root.Position, #root:GetDescendants(),
			root.Label.Text, minimap._writes() }
		minimap.Set({ Name = "Minimap", LayoutOrder = 4, Label = "Akane", Round = true, ShowRank = true, Visible = true })
		local after = { root.Name, root.LayoutOrder, root.Visible, root.Size, root.Position, #root:GetDescendants(),
			root.Label.Text, minimap._writes() }
		for index = 1, #snapshot do expect(snapshot[index] == after[index], "property " .. index .. " changed") end
		minimap.Set({ Visible = false })
		expect(root.Visible == false, "Visible written")
		minimap.Set({ Size = Tokens.Space.GaugeTouchSize })
		expect(root.Size.X.Offset == Tokens.Space.GaugeTouchSize, "Size relays out")
		expect(not pcall(minimap.Set, { Colour = "Pink" }), "unknown key must error")
		expect(not pcall(minimap.Set, { Size = 0 }), "a bad size must error")
		expect(not pcall(M.New, parent, { Nope = 1 }, newScope()), "unknown prop must error")
		local content = minimap.Content
		minimap.Destroy()
		minimap.Destroy()
		expect(#parent:GetChildren() == 0 and content.Parent == nil, "parent empty after Destroy")
		minimap.SetRank(3, 0.5)
		minimap.SetHeading(90)
		minimap.SetArrow(90)
		minimap.SetLabel("after")
		minimap.SetRound(false)
	end)

	case("minimap: destroying the scope destroys the component", function()
		local minimap, parent, scope = minimapOn(COMPACT, true)
		minimap.SetRank(2, 0.3)
		scope:destroy()
		expect(#parent:GetChildren() == 0, "parent empty after scope destroy")
	end)

	case("minimap: builds with every asset empty", function()
		local real = Tokens.Asset
		local stubbed = pcall(function() Tokens.Asset = function() return nil end end)
		if not stubbed then return end -- a frozen Tokens table cannot be stubbed; the gallery covers the empty state
		table.insert(cleanups, function() Tokens.Asset = real end)
		local minimap = minimapOn(REGULAR, false)
		local root = minimap.Instance
		expect(root.Ring.Image == "" and root.Arrow.Image == "", "no image, no error")
		expect(root.Size.X.Offset == Tokens.Space.MinimapSize - Tokens.Space.MinimapSize % 2, "the size does not change")
		minimap.SetRank(4, 0.5)
		minimap.SetHeading(33)
	end)

	return results
end
