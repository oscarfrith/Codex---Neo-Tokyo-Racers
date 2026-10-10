-- Pure tests for Kit.Overlay. No yield, nothing parented into the game tree, every component destroyed before return.
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
	local Text = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Text")

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

	local REGULAR = Vector2.new(1920, 1080)
	local COMPACT = Vector2.new(844, 390)

	------------------------------------------------------------------------------------------------------------------
	-- Toast: pure logic
	------------------------------------------------------------------------------------------------------------------

	case("toast text: upper-cased tostring, nil and false are empty", function()
		expect(M._toastText("Route set") == "ROUTE SET", "upper")
		expect(M._toastText(nil) == "", "nil")
		expect(M._toastText(false) == "", "false")
		expect(M._toastText("") == "", "empty")
		expect(M._toastText(12) == "12", "number")
		expect(M._toastText(true) == "TRUE", "true")
	end)

	case("toast duration: default 2.5, clamped 0.5 to 10", function()
		expect(M._toastDuration(nil) == 2.5, "nil")
		expect(M._toastDuration("abc") == 2.5, "non-number")
		expect(M._toastDuration(2.2) == 2.2, "2.2")
		expect(M._toastDuration("3") == 3, "numeric string")
		expect(M._toastDuration(0) == 0.5, "low")
		expect(M._toastDuration(-4) == 0.5, "negative")
		expect(M._toastDuration(0.5) == 0.5, "low edge")
		expect(M._toastDuration(10) == 10, "high edge")
		expect(M._toastDuration(99) == 10, "high")
	end)

	case("toast pick: duplicate, free, oldest", function()
		local cards = {
			{ Showing = false, Text = "", Serial = 0 },
			{ Showing = false, Text = "", Serial = 0 },
			{ Showing = false, Text = "", Serial = 0 },
		}
		local index, kind = M._toastPick(cards, "A")
		expect(index == 1 and kind == "Free", "first free card")
		cards[1] = { Showing = true, Text = "A", Serial = 1 }
		index, kind = M._toastPick(cards, "A")
		expect(index == 1 and kind == "Duplicate", "same text on a showing card")
		index, kind = M._toastPick(cards, "B")
		expect(index == 2 and kind == "Free", "second free card")
		cards[2] = { Showing = true, Text = "B", Serial = 2 }
		cards[3] = { Showing = true, Text = "C", Serial = 3 }
		index, kind = M._toastPick(cards, "D")
		expect(index == 1 and kind == "Oldest", "oldest reused when full")
		cards[1] = { Showing = true, Text = "D", Serial = 4 }
		index, kind = M._toastPick(cards, "E")
		expect(index == 2 and kind == "Oldest", "next oldest")
		index, kind = M._toastPick(cards, "C")
		expect(index == 3 and kind == "Duplicate", "duplicate wins over oldest")
		cards[2].Showing = false
		index, kind = M._toastPick(cards, "B")
		expect(index == 2 and kind == "Free", "an expired card's text is not a duplicate")
		cards[3].Showing = false
		index, kind = M._toastPick(cards, "Z")
		expect(index == 2 and kind == "Free", "least recently used free card first")
	end)

	------------------------------------------------------------------------------------------------------------------
	-- Toast: component
	------------------------------------------------------------------------------------------------------------------

	local function toastOn(size, touch, props)
		local parent = stage(size, touch)
		local scope = newScope()
		local toast = M.Toast(parent, props or {}, scope)
		table.insert(cleanups, toast.Destroy)
		return toast, parent, scope
	end

	case("toast: builds Stack and a pool of three cards on a detached parent", function()
		local toast, parent = toastOn(REGULAR, false)
		expect(#parent:GetChildren() == 1, "one root under the parent")
		expect(toast.Instance.Name == "Stack" and toast.Instance.Parent == parent, "root is Stack")
		for index = 1, 3 do
			local card = toast.Instance:FindFirstChild("Card" .. index)
			expect(card ~= nil, "Card" .. index .. " exists")
			expect(card.Visible == false, "Card" .. index .. " starts hidden")
			expect(card:FindFirstChild("Text") ~= nil, "Card" .. index .. " has Text")
		end
		expect(toast.Instance:FindFirstChild("Card4") == nil, "no fourth card")
		expect(toast.Count() == 0, "count 0")
		expect(#toast.Instance:GetDescendants() <= 11, "budget: 11 descendants or fewer")
		local size = toast.Instance.Size
		expect(size.X.Scale == 0 and size.X.Offset == 820, "stack is 820 px wide at 1080")
	end)

	case("toast: compact stack is 280 wide and even", function()
		local toast = toastOn(COMPACT, true)
		expect(toast.Instance.Size.X.Offset == 280, "280 at 844x390")
	end)

	case("toast: queue, duplicate suppression and max cards", function()
		local toast = toastOn(REGULAR, false)
		local before = #toast.Instance:GetDescendants()
		toast.Show("", 2)
		toast.Show(nil, 2)
		expect(toast.Count() == 0, "empty ignored")
		toast.Show("route set", 10)
		expect(toast.Count() == 1, "one")
		toast.Show("ROUTE SET", 10)
		toast.Show("Route Set")
		expect(toast.Count() == 1, "duplicate does not add a card")
		toast.Show("b", 10)
		toast.Show("c", 10)
		expect(toast.Count() == 3, "three")
		toast.Show("d", 10)
		toast.Show("e", 10)
		expect(toast.Count() == 3, "never more than three")
		expect(#toast.Instance:GetDescendants() == before, "no instance created or destroyed by Show")
	end)

	case("toast: MaxCards prop and Set", function()
		local toast = toastOn(REGULAR, false, { MaxCards = 1 })
		expect(toast.Instance:FindFirstChild("Card2") == nil, "one card")
		toast.Show("a", 10)
		toast.Show("b", 10)
		expect(toast.Count() == 1, "max one")
		toast.Set({ MaxCards = 2 })
		expect(toast.Instance:FindFirstChild("Card2") ~= nil, "pool grew")
		toast.Show("c", 10)
		expect(toast.Count() == 2, "two")
		toast.Set({ MaxCards = 1 })
		expect(toast.Instance:FindFirstChild("Card2") == nil, "pool shrank")
	end)

	case("toast: Set unchanged writes nothing, unknown key errors, Destroy is repeat-safe", function()
		local toast, parent = toastOn(REGULAR, false, { Name = "Stack", LayoutOrder = 3, Visible = true })
		local root = toast.Instance
		local snapshot = { root.Name, root.LayoutOrder, root.Visible, root.Size, root.Position, #root:GetDescendants() }
		toast.Set({ Name = "Stack", LayoutOrder = 3, Visible = true })
		local after = { root.Name, root.LayoutOrder, root.Visible, root.Size, root.Position, #root:GetDescendants() }
		for index = 1, #snapshot do expect(snapshot[index] == after[index], "property " .. index .. " changed") end
		toast.Set({ Visible = false })
		expect(root.Visible == false, "Visible written")
		expect(not pcall(toast.Set, { Colour = "Pink" }), "unknown key must error")
		expect(not pcall(M.Toast, parent, { Nope = 1 }, newScope()), "unknown prop must error")
		toast.Show("pending", 10)
		toast.Destroy()
		toast.Destroy()
		expect(#parent:GetChildren() == 0, "parent empty after Destroy")
		toast.Show("after destroy", 1)
		expect(toast.Count() == 0, "Show after Destroy is ignored")
	end)

	case("toast: destroying the scope destroys the component", function()
		local toast, parent, scope = toastOn(REGULAR, false)
		toast.Show("a", 10)
		scope:destroy()
		expect(#parent:GetChildren() == 0, "parent empty after scope destroy")
	end)

	-- A cold font without a yield in the test: Text.Measure parks the toast's measuring thread until Arrive, and the
	-- display timer is a recorder. Call before toastOn, so the component is destroyed before both are put back.
	local function coldFont()
		local realMeasure, realDelay = Text.Measure, M._toastDelay
		local cold = { Pending = {}, Timers = {} }
		Text.Measure = function()
			table.insert(cold.Pending, coroutine.running())
			return coroutine.yield()
		end
		M._toastDelay = function(seconds, callback)
			table.insert(cold.Timers, { Seconds = seconds, Fire = callback })
			return task.spawn(function() coroutine.yield() end)
		end
		function cold.Arrive(bounds)
			local thread = table.remove(cold.Pending, 1)
			if not thread then error("no measure is pending", 2) end
			local resumed, problem = coroutine.resume(thread, bounds)
			if not resumed then error("the measuring thread failed: " .. tostring(problem), 2) end
		end
		table.insert(cleanups, function()
			Text.Measure = realMeasure
			M._toastDelay = realDelay
		end)
		return cold
	end

	local BOUNDS = Vector2.new(200, 30)

	case("toast: the display timer starts when the card becomes visible, not before the measure", function()
		local cold = coldFont()
		local toast = toastOn(REGULAR, false)
		local card = toast.Instance:FindFirstChild("Card1")
		local label = card:FindFirstChild("Text")
		toast.Show("route set", 4)
		expect(#cold.Pending == 1, "one measure waiting")
		expect(toast.Count() == 1, "counted while it waits")
		expect(card.Visible == false and label.Text == "", "hidden and empty until measured")
		expect(#cold.Timers == 0, "no timer before the card is visible")
		toast.Show("Route Set", 6)
		expect(#cold.Pending == 1 and #cold.Timers == 0 and toast.Count() == 1, "a duplicate while waiting adds nothing")
		cold.Arrive(BOUNDS)
		expect(card.Visible == true and label.Text == "ROUTE SET", "visible with its text once measured")
		expect(#cold.Timers == 1, "one timer, started at the reveal")
		expect(cold.Timers[1].Seconds == 6, "the timer runs for the latest duration asked")
		toast.Show("route set", 3)
		expect(#cold.Pending == 0 and #cold.Timers == 2, "a duplicate of a visible card restarts its timer at once")
		expect(cold.Timers[2].Seconds == 3, "restart duration")
		toast.Relayout()
		expect(#cold.Pending == 1, "a relayout measures the showing card again")
		cold.Arrive(BOUNDS)
		expect(#cold.Timers == 2, "a second measure does not restart the timer")
		cold.Timers[2].Fire()
		expect(toast.Count() == 0, "the timer's end hides the card")
	end)

	case("toast: a measure that fails still shows the card and starts its timer", function()
		local cold = coldFont()
		Text.Measure = function() error("no face") end
		local toast = toastOn(REGULAR, false)
		toast.Show("a", 5)
		local card = toast.Instance:FindFirstChild("Card1")
		expect(card.Visible == true and card:FindFirstChild("Text").Text == "A", "shown at full width")
		expect(#cold.Timers == 1 and cold.Timers[1].Seconds == 5, "timer started")
	end)

	case("toast: a hidden pooled card carries no text", function()
		local cold = coldFont()
		local toast = toastOn(REGULAR, false, { MaxCards = 1 })
		local card = toast.Instance:FindFirstChild("Card1")
		local label = card:FindFirstChild("Text")
		expect(card.Visible == false and label.Text == "", "an unused card is hidden and empty")
		toast.Show("first", 5)
		cold.Arrive(BOUNDS)
		expect(card.Visible == true and label.Text == "FIRST", "shown")
		toast.Show("second", 5)
		expect(card.Visible == false and label.Text == "", "a reused card is hidden and empty until its new text is measured")
		expect(#cold.Timers == 1, "the replaced message's timer is not restarted")
		cold.Arrive(BOUNDS)
		expect(card.Visible == true and label.Text == "SECOND", "shown with the new text")
		expect(#cold.Timers == 2, "the new message's timer starts at its reveal")
	end)

	------------------------------------------------------------------------------------------------------------------
	-- Confirm (Host mode: no ScreenGui)
	------------------------------------------------------------------------------------------------------------------

	local function confirmOn(options)
		local host = stage(REGULAR, false)
		local calls = { Confirm = 0, Cancel = 0 }
		options = options or {}
		options.Host = host
		options.OnConfirm = function() calls.Confirm += 1 end
		options.OnCancel = function() calls.Cancel += 1 end
		local handle = M.Confirm(host, options)
		table.insert(cleanups, handle.Cancel)
		return handle, host, calls
	end

	case("confirm: builds inside Host with the Classic names", function()
		local handle, host = confirmOn({ Title = "Move this part?", Body = "Body text." })
		expect(handle.Root.Name == "SharedConfirmation" and handle.Root.Parent == host, "Root is the shade in Host mode")
		expect(handle.Root:IsA("GuiObject") and handle.Root.Active == true, "shade blocks input")
		expect(type(handle.Cancel) == "function" and type(handle.Confirm) == "function", "Cancel and Confirm")
		expect(type(handle.Relayout) == "function", "Relayout")
		local panel = handle.Root:FindFirstChild("Panel")
		expect(panel ~= nil and panel.Size.X.Offset == 650, "panel 650 wide at 1080")
		local no = handle.Root:FindFirstChild("No", true)
		local yes = handle.Root:FindFirstChild("Yes", true)
		expect(no ~= nil and yes ~= nil, "No and Yes exist")
		expect(no:IsA("GuiButton") and yes:IsA("GuiButton"), "buttons")
		expect(no.Selectable and yes.Selectable, "both selectable")
		expect(no.NextSelectionRight == yes and yes.NextSelectionLeft == no, "NO left of YES")
		expect(no.LayoutOrder < yes.LayoutOrder, "NO first in the row")
		local body = handle.Root:FindFirstChild("Body", true)
		expect(body ~= nil and body.Text == "Body text." and body.TextWrapped, "body text, wrapped")
		expect(body.AutomaticSize == Enum.AutomaticSize.Y, "body auto-height")
		handle.Relayout()
	end)

	case("confirm: cancel closes once", function()
		local handle, host, calls = confirmOn()
		handle.Cancel()
		expect(calls.Cancel == 1 and calls.Confirm == 0, "one cancel")
		expect(#host:GetChildren() == 0, "host empty after close")
		handle.Cancel()
		handle.Confirm()
		handle.Relayout()
		expect(calls.Cancel == 1 and calls.Confirm == 0, "no second callback")
	end)

	case("confirm: confirm closes once", function()
		local handle, host, calls = confirmOn({ CancelText = "KEEP", ConfirmText = "EXIT" })
		handle.Confirm()
		expect(calls.Confirm == 1 and calls.Cancel == 0, "one confirm")
		handle.Confirm()
		handle.Cancel()
		expect(calls.Confirm == 1 and calls.Cancel == 0, "no second callback")
		expect(#host:GetChildren() == 0, "host empty after close")
	end)

	case("confirm: destroyed by someone else cancels at most once", function()
		local handle, host, calls = confirmOn()
		handle.Root:Destroy()
		handle.Cancel()
		handle.Confirm()
		expect(calls.Cancel == 1 and calls.Confirm == 0, "exactly one cancel")
		expect(#host:GetChildren() == 0, "host empty")
	end)

	case("confirm: a second confirmation in the same host cancels the first", function()
		local first, host, calls = confirmOn()
		local second = M.Confirm(host, { Host = host })
		table.insert(cleanups, second.Cancel)
		expect(calls.Cancel == 1, "first cancelled once")
		expect(#host:GetChildren() == 1, "one shade")
		first.Confirm()
		expect(calls.Confirm == 0, "first cannot confirm afterwards")
		second.Cancel()
		expect(#host:GetChildren() == 0, "host empty")
	end)

	case("confirm: argument checks", function()
		expect(not pcall(M.Confirm, nil, {}), "nil root errors")
		local detached = env.Detached("Frame")
		expect(not pcall(M.Confirm, detached, {}), "root outside PlayerGui without Host errors")
		expect(not pcall(M.Confirm, detached, { Host = "x" }), "Host must be a GuiObject")
	end)

	------------------------------------------------------------------------------------------------------------------
	-- Modal
	------------------------------------------------------------------------------------------------------------------

	case("modal: nothing built until Open; Open and Close", function()
		local parent = stage(REGULAR, false)
		local scope = newScope()
		local builds, closes = 0, 0
		local modal = M.Modal(parent, {
			Title = "Settings", Width = 650, Height = 400,
			Build = function(content, buildScope)
				builds += 1
				expect(content:IsA("Frame"), "content is a Frame")
				expect(type(buildScope) == "table" and type(buildScope.connect) == "function", "a scope is passed")
			end,
			OnClose = function() closes += 1 end,
		}, scope)
		table.insert(cleanups, modal.Destroy)
		expect(#parent:GetChildren() == 1, "one root")
		expect(modal.Instance.Name == "Modal" and #modal.Instance:GetChildren() == 0, "nothing built before Open")
		expect(modal.Instance.Visible == false and modal.IsOpen() == false, "closed")
		expect(modal.Content == nil, "no Content before Open")
		modal.Close()
		expect(closes == 0, "Close while closed does nothing")
		modal.Open()
		expect(modal.IsOpen() and modal.Instance.Visible, "open")
		expect(builds == 1 and modal.Content ~= nil and modal.Content:IsA("Frame"), "built once, Content set")
		modal.Open()
		expect(builds == 1, "second Open does not rebuild")
		modal.Close()
		expect(not modal.IsOpen() and modal.Instance.Visible == false and closes == 1, "closed once")
		modal.Close()
		expect(closes == 1, "OnClose once")
		modal.Open()
		expect(builds == 1 and modal.IsOpen(), "reopened without a rebuild")
		modal.Destroy()
		expect(closes == 1, "Destroy does not call OnClose")
		modal.Destroy()
		expect(#parent:GetChildren() == 0, "parent empty after Destroy")
	end)

	case("modal: Set unchanged writes nothing, unknown key errors", function()
		local parent = stage(COMPACT, true)
		local scope = newScope()
		local modal = M.Modal(parent, { Title = "Get Cash", Width = 480 }, scope)
		table.insert(cleanups, modal.Destroy)
		local root = modal.Instance
		local snapshot = { root.Name, root.LayoutOrder, root.Visible, #root:GetDescendants() }
		modal.Set({ Title = "Get Cash", Width = 480, Name = "Modal" })
		local after = { root.Name, root.LayoutOrder, root.Visible, #root:GetDescendants() }
		for index = 1, #snapshot do expect(snapshot[index] == after[index], "property " .. index .. " changed") end
		expect(not pcall(modal.Set, { Colour = "Pink" }), "unknown key must error")
		expect(not pcall(M.Modal, parent, { Title = "No width" }, scope), "Width is required")
		modal.Open()
		modal.Set({ Title = "Cash" })
		scope:destroy()
		expect(#parent:GetChildren() == 0, "parent empty after scope destroy")
	end)

	------------------------------------------------------------------------------------------------------------------
	-- Phase 2 (API2 2.11, 3.7). Everything above is the Phase 1 file, unchanged.
	------------------------------------------------------------------------------------------------------------------

	local Tokens = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens")
	local Presence = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Presence")
	local REGULAR_SMALL = Vector2.new(1280, 720)

	local function stageFor(size, input)
		local frame = env.Detached("Frame")
		Metrics.Bind(frame, Metrics.Fixed({ Size = size, TouchEnabled = input == "Touch", Input = input }))
		return frame
	end

	-- Descendants plus the root, without the text size locks the budgets leave out (API2 3).
	local function budgetOf(root)
		local total = 1
		for _, item in ipairs(root:GetDescendants()) do
			if not item:IsA("UITextSizeConstraint") then total += 1 end
		end
		return total
	end

	------------------------------------------------------------------------------------------------------------------
	-- Toast kinds
	------------------------------------------------------------------------------------------------------------------

	case("toast message: string and table forms", function()
		local text, kind, icon = M._toastMessage("Route set")
		expect(text == "ROUTE SET" and kind == "Neutral" and icon == nil, "a string is Neutral with no icon")
		text, kind, icon = M._toastMessage({ Text = "Fare paid", Kind = "Good", Icon = "coin" })
		expect(text == "FARE PAID" and kind == "Good" and icon == "coin", "table form")
		text, kind, icon = M._toastMessage({ Text = "No", Kind = "Bad" })
		expect(text == "NO" and kind == "Bad" and icon == nil, "Bad without icon")
		text, kind, icon = M._toastMessage({ Text = "x", Kind = "Purple", Icon = "" })
		expect(kind == "Neutral" and icon == nil, "unknown kind is Neutral; empty icon is none")
		text = M._toastMessage({})
		expect(text == "", "a table without Text is empty")
		text, kind = M._toastMessage(nil)
		expect(text == "" and kind == "Neutral", "nil")
	end)

	case("toast kinds: Good has a Cyan edge, Bad a Danger edge, a string a White edge", function()
		local toast = toastOn(REGULAR, false)
		local before = #toast.Instance:GetDescendants()
		toast.Show({ Text = "good", Kind = "Good" }, 10)
		toast.Show({ Text = "bad", Kind = "Bad" }, 10)
		toast.Show("plain", 10)
		expect(toast.Count() == 3, "three showing")
		local function edge(index) return toast.Instance:FindFirstChild("Card" .. index):FindFirstChild("Edge") end
		expect(edge(1).BackgroundColor3 == Tokens.Colour.Cyan, "Good edge")
		expect(edge(2).BackgroundColor3 == Tokens.Colour.Danger, "Bad edge")
		expect(edge(3).BackgroundColor3 == Tokens.Colour.White, "Neutral edge")
		expect(#toast.Instance:GetDescendants() == before, "a kind creates no instance")
		toast.Show({ Text = "", Kind = "Bad" }, 10)
		toast.Show({ Kind = "Bad" }, 10)
		expect(toast.Count() == 3, "empty table messages are ignored")
		toast.Show({ Text = "good", Kind = "Bad" }, 10)
		expect(toast.Count() == 3 and edge(1).BackgroundColor3 == Tokens.Colour.Danger, "a duplicate takes the new kind")
		toast.Show("fourth", 10)
		expect(edge(1).BackgroundColor3 == Tokens.Colour.White, "a reused card returns to the Neutral edge")
	end)

	case("toast icon: built on first use, reused, hidden for a message without one", function()
		local toast = toastOn(REGULAR, false, { MaxCards = 1 })
		local card = toast.Instance:FindFirstChild("Card1")
		expect(card:FindFirstChild("Icon") == nil, "no icon until a message asks")
		toast.Show({ Text = "first", Icon = "info" }, 10)
		local icon = card:FindFirstChild("Icon")
		expect(icon ~= nil and icon.Visible, "icon built and shown")
		local count = #card:GetDescendants()
		toast.Show({ Text = "second", Icon = "warning", Kind = "Bad" }, 10)
		expect(card:FindFirstChild("Icon") == icon and #card:GetDescendants() == count, "the icon is reused")
		toast.Show("third", 10)
		expect(icon.Visible == false and #card:GetDescendants() == count, "hidden, not destroyed, for a plain message")
		toast.Show({ Text = "fourth", Icon = "not_a_glyph" }, 10)
		expect(toast.Count() == 1 and icon.Visible == false, "an unknown icon name still shows the toast")
		toast.Destroy()
	end)

	------------------------------------------------------------------------------------------------------------------
	-- Confirm and Modal additions
	------------------------------------------------------------------------------------------------------------------

	case("confirm: the title carries the title mark", function()
		local handle = confirmOn({ Title = "Move this part?" })
		local row = handle.Root:FindFirstChild("TitleRow", true)
		expect(row ~= nil and row:FindFirstChild("Mark") ~= nil, "Mark in the title row")
		local title = row:FindFirstChild("Title")
		expect(title ~= nil and title.Position.X.Offset > 0, "the title starts after the mark")
	end)

	local function modalOn(size, input, props)
		local parent = stageFor(size, input)
		local scope = newScope()
		local modal = M.Modal(parent, props, scope)
		table.insert(cleanups, modal.Destroy)
		return modal, parent, scope
	end

	case("modal: Open registers Presence and Close releases it", function()
		local modal = modalOn(REGULAR, "KeyboardAndMouse", { Name = "TestSettings", Title = "Settings", Width = 650 })
		expect(not Presence.Is("TestSettings"), "not open before Open")
		modal.Open()
		expect(Presence.Is("TestSettings") and Presence.Any("Modal"), "kind Modal while open")
		modal.Open()
		modal.Close()
		expect(not Presence.Is("TestSettings"), "released at Close")
		modal.Open()
		modal.Destroy()
		expect(not Presence.Is("TestSettings"), "released at Destroy")
	end)

	case("modal: footer buttons, close button, title mark, budget", function()
		local pressed = 0
		local modal = modalOn(REGULAR, "KeyboardAndMouse", { Title = "Settings", Width = 650, Height = 400,
			CloseButton = true,
			Buttons = { Buttons = {
				{ Id = "Back", Text = "BACK", OnActivated = function() pressed += 1 end },
				{ Id = "Apply", Variant = "Main", Text = "APPLY", OnActivated = function() pressed += 1 end },
			} } })
		expect(#modal.Instance:GetChildren() == 0, "nothing built before Open")
		modal.Open()
		local root = modal.Instance
		local footer = root:FindFirstChild("Footer", true)
		expect(footer ~= nil, "Footer row built")
		expect(footer.AnchorPoint == Vector2.new(1, 1), "footer on the bottom-right")
		expect(root:FindFirstChild("CloseButton", true) ~= nil, "CloseButton built")
		expect(root:FindFirstChild("Mark", true) ~= nil, "title mark built")
		expect(root:FindFirstChild("Scrim") ~= nil, "a centred modal dims by default")
		local body = modal.Content
		expect(body.Size.Y.Scale == 1 and body.Size.Y.Offset < 0, "the body stops above the footer")
		expect(budgetOf(root) <= 120, "at most 120 instances")
		local count = #root:GetDescendants()
		modal.Set({ CloseButton = true })
		expect(#root:GetDescendants() == count, "an unchanged Set builds nothing")
		modal.Set({ Buttons = false })
		expect(root:FindFirstChild("Footer", true) == nil, "Buttons = false removes the footer")
	end)

	case("modal: a bare list of buttons is accepted", function()
		local modal = modalOn(REGULAR, "KeyboardAndMouse", { Title = "Settings", Width = 650,
			Buttons = { { Id = "Close", Text = "CLOSE" } } })
		modal.Open()
		expect(modal.Instance:FindFirstChild("Footer", true) ~= nil, "Footer row built")
	end)

	case("modal: Scrim kinds", function()
		local menu = modalOn(REGULAR, "KeyboardAndMouse", { Title = "A", Width = 650, Scrim = "Menu" })
		menu.Open()
		local scrim = menu.Instance:FindFirstChild("Scrim")
		expect(scrim ~= nil and scrim:FindFirstChildOfClass("UIGradient") ~= nil, "Menu scrim is the gradient")
		expect(menu.Instance.Active == true, "a dimmed scene takes clicks")
		local none = modalOn(REGULAR, "KeyboardAndMouse", { Title = "B", Width = 650, Scrim = "None" })
		none.Open()
		expect(none.Instance:FindFirstChild("Scrim") == nil, "no scrim")
		expect(none.Instance.Active == false, "without a scrim the scene stays clickable")
		local parent = stageFor(REGULAR, "KeyboardAndMouse")
		expect(not pcall(M.Modal, parent, { Title = "C", Width = 650, Scrim = "Dark" }, newScope()), "unknown Scrim errors")
		expect(not pcall(M.Modal, parent, { Title = "C", Width = 650, Side = "Top" }, newScope()), "unknown Side errors")
		expect(not pcall(menu.Set, { Scrim = "None" }), "Scrim is fixed at construction")
		expect(not pcall(menu.Set, { Side = "Left" }), "Side is fixed at construction")
		menu.Set({ Scrim = "Menu", Side = "Centre" })
	end)

	case("modal: a side panel fills its parent, has no scrim, needs no Width and is Presence kind SidePanel", function()
		for _, spec in ipairs({ { REGULAR, "KeyboardAndMouse", "Left" }, { COMPACT, "Touch", "Right" } }) do
			local modal = modalOn(spec[1], spec[2], { Name = "TestCarPanel", Title = "Your cars", Side = spec[3],
				CloseButton = true })
			modal.Open()
			local root = modal.Instance
			expect(root:FindFirstChild("Scrim") == nil, "no scrim")
			expect(root.Active == true, "the panel area takes clicks")
			local panel = root:FindFirstChild("Panel")
			expect(panel ~= nil and panel.Size.X.Scale == 1 and panel.Size.Y.Scale == 1, "the panel fills the slot")
			expect(panel.Position == UDim2.fromOffset(0, 0), "the panel is not centred")
			expect(Presence.Is("TestCarPanel") and Presence.Any("SidePanel"), "kind SidePanel while open")
			expect(modal.Content.AutomaticSize == Enum.AutomaticSize.None, "the body fills the panel")
			modal.Close()
			expect(not Presence.Is("TestCarPanel"), "released")
			modal.Destroy()
		end
	end)

	------------------------------------------------------------------------------------------------------------------
	-- PromptBanner: pure
	------------------------------------------------------------------------------------------------------------------

	case("prompt cap: key cap on keyboard, glyph on gamepad, nothing on touch", function()
		local E, X, Y = Enum.KeyCode.E, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY
		local kind, value = M._promptCap("KeyboardAndMouse", E, X)
		expect(kind == "Key" and value == "E", "keyboard shows the key")
		kind, value = M._promptCap("Gamepad", E, X)
		expect(kind == "Pad" and value == "pad_x", "gamepad shows the pad glyph")
		kind, value = M._promptCap("Gamepad", E, Y)
		expect(kind == "Pad" and value == "pad_y", "ButtonY")
		kind, value = M._promptCap("Gamepad", E, Enum.KeyCode.ButtonR1)
		expect(value == "pad_rb", "bumper")
		kind, value = M._promptCap("Gamepad", E, Enum.KeyCode.Thumbstick1)
		expect(kind == "Pad" and value == "keycap_blank", "an unmapped pad key is a blank cap")
		kind, value = M._promptCap("Touch", E, X)
		expect(kind == "None" and value == nil, "touch has no cap")
		kind = M._promptCap("KeyboardAndMouse", nil, X)
		expect(kind == "None", "no key, no cap")
		kind = M._promptCap("KeyboardAndMouse", false, X)
		expect(kind == "None", "a cleared key, no cap")
		kind = M._promptCap("Gamepad", E, false)
		expect(kind == "None", "no pad key, no glyph")
		kind, value = M._promptCap("KeyboardAndMouse", Enum.KeyCode.One, nil)
		expect(value == "1", "digit keys show the digit")
		kind, value = M._promptCap("KeyboardAndMouse", Enum.KeyCode.F, nil)
		expect(value == "F", "F")
		kind, value = M._promptCap("KeyboardAndMouse", Enum.KeyCode.Tab, nil)
		expect(value == "TAB", "a longer name is three capitals")
	end)

	case("prompt size: PromptWidth by ButtonHeight, PromptHeight for Main, 48 or more on touch", function()
		local space = Tokens.Space
		local regular = Metrics.Fixed({ Size = REGULAR, Input = "KeyboardAndMouse" })
		local width, height = M._promptSize(regular, false)
		expect(width == space.PromptWidth - space.PromptWidth % 2 and height == space.ButtonHeight, "Regular at 1080")
		width, height = M._promptSize(regular, true)
		expect(height == space.PromptHeight, "Main is PromptHeight")
		local small = Metrics.Fixed({ Size = REGULAR_SMALL, Input = "KeyboardAndMouse" })
		width, height = M._promptSize(small, false)
		expect(height == small.Px(space.ButtonHeight) and height < space.TouchMin, "720p keyboard banner is scaled")
		local smallTouch = Metrics.Fixed({ Size = REGULAR_SMALL, TouchEnabled = true, Input = "Touch" })
		width, height = M._promptSize(smallTouch, false)
		expect(height >= space.TouchMin, "720p touch banner is at least 48")
		local compact = Metrics.Fixed({ Size = COMPACT, TouchEnabled = true, Input = "Touch" })
		width, height = M._promptSize(compact, false)
		expect(width == space.CompactPromptWidth and height >= space.TouchMin, "Compact 300 wide, 48 or more high")
		local _, mainHeight = M._promptSize(compact, true)
		expect(mainHeight > height, "Compact Main is taller")
		local tiny = Metrics.Fixed({ Size = Vector2.new(568, 320), TouchEnabled = true, Input = "Touch" })
		width, height = M._promptSize(tiny, false)
		expect(width <= 568 and width % 2 == 0 and height >= space.TouchMin, "568x320 fits and stays 48 high")
	end)

	------------------------------------------------------------------------------------------------------------------
	-- PromptBanner: component
	------------------------------------------------------------------------------------------------------------------

	local function bannerOn(size, input, props)
		local parent = stageFor(size, input)
		local scope = newScope()
		local banner = M.PromptBanner(parent, props, scope)
		table.insert(cleanups, banner.Destroy)
		return banner, parent, scope
	end

	local JOIN = { Action = "Join race", Object = "Race", Key = Enum.KeyCode.E, PadKey = Enum.KeyCode.ButtonX }

	case("prompt banner, keyboard: slate strip with hairlines and a key cap; not clickable", function()
		local presses = 0
		local props = table.clone(JOIN)
		props.OnPress = function() presses += 1 end
		local banner, parent = bannerOn(REGULAR, "KeyboardAndMouse", props)
		local root = banner.Instance
		expect(#parent:GetChildren() == 1 and root.Parent == parent, "one root")
		expect(root:IsA("TextButton") and root.Text == "", "root is a TextButton without text")
		expect(root.Active == false and root.Selectable == false, "not clickable, not selectable")
		expect(root.Size == UDim2.fromOffset(Tokens.Space.PromptWidth, Tokens.Space.ButtonHeight), "590 x 64 at 1080")
		expect(root.BackgroundColor3 == Tokens.Colour.Slate, "slate")
		expect(root:FindFirstChild("KeyCap") ~= nil, "key cap")
		expect(root:FindFirstChild("HairTop").Visible and root:FindFirstChild("HairBottom").Visible, "hairlines")
		local action, object = root:FindFirstChild("Action"), root:FindFirstChild("Object")
		expect(action:IsA("TextLabel") and action.Text == "JOIN RACE", "action upper-cased")
		expect(object:IsA("TextLabel") and object.Text == "RACE" and object.Visible, "object upper-cased")
		expect(action.TextColor3 == Tokens.Colour.White, "white action")
		expect(action.TextSize > object.TextSize, "the action is the larger role")
		expect(budgetOf(root) <= 9, "budget 9, got " .. budgetOf(root))
		expect(banner._press() == false and presses == 0, "a keyboard banner takes no press")
	end)

	case("prompt banner, gamepad: a pad glyph cell; Main is taller", function()
		local props = table.clone(JOIN)
		props.Main = true
		local banner = bannerOn(REGULAR, "Gamepad", props)
		local root = banner.Instance
		expect(root:FindFirstChild("KeyCap") ~= nil, "glyph cell")
		expect(root.Active == false, "not clickable")
		expect(root.Size.Y.Offset == Tokens.Space.PromptHeight, "Main height")
		expect(budgetOf(root) <= 9, "budget 9")
		local noPad = bannerOn(REGULAR, "Gamepad", { Action = "Enter", Key = Enum.KeyCode.E })
		expect(noPad.Instance:FindFirstChild("KeyCap") == nil, "no PadKey, no glyph")
		expect(noPad.Instance:FindFirstChild("Object").Visible == false, "no object, label hidden")
	end)

	case("prompt banner, touch: the banner is the button, 48 or more high, no key cap", function()
		for _, size in ipairs({ COMPACT, REGULAR, REGULAR_SMALL }) do
			local presses, releases = 0, 0
			local props = table.clone(JOIN)
			props.OnPress = function() presses += 1 end
			props.OnRelease = function() releases += 1 end
			local banner = bannerOn(size, "Touch", props)
			local root = banner.Instance
			expect(root:IsA("TextButton") and root.Active == true, "an active TextButton")
			expect(root.Size.Y.Offset >= Tokens.Space.TouchMin, "at least 48 high, got " .. root.Size.Y.Offset)
			expect(root:FindFirstChild("KeyCap") == nil, "no key cap")
			if size == COMPACT then
				-- Mobile pass (A13): slim on a phone. The root is a clear hit box; the plate is drawn inside it.
				local plate = root:FindFirstChild("Plate")
				expect(root.BackgroundTransparency == 1, "the phone hit box is not clear")
				expect(plate ~= nil and plate.Visible and plate.BackgroundColor3 == Tokens.Colour.Slate, "slate plate")
				expect(plate.Size.Y.Offset == Tokens.Space.CompactButtonDrawn and plate.Size.Y.Offset < root.Size.Y.Offset, "the plate is drawn 36 high in the hit box")
				expect(plate.Position.Y.Offset * 2 + plate.Size.Y.Offset == root.Size.Y.Offset, "the plate is not centred")
				expect(plate:FindFirstChild("Edge") ~= nil and plate.Edge.BackgroundColor3 == Tokens.Colour.Cyan, "cyan tap edge")
				expect(plate:FindFirstChild("HairTop") ~= nil and plate.HairTop.Visible, "hairlines on the plate")
				expect(plate:FindFirstChild("Progress") ~= nil, "the hold line is on the plate")
				expect(root:FindFirstChild("Action").TextColor3 == Tokens.Colour.White, "light text")
				expect(root.Size.X.Offset <= Tokens.Space.CompactPromptWidth and root.Size.X.Offset >= Tokens.Space.CompactTileMinWidth * 2, "hugging width out of range: " .. root.Size.X.Offset)
			else
				expect(root.BackgroundColor3 == Tokens.Colour.White and root.BackgroundTransparency == 0, "white fill")
				expect(root:FindFirstChild("Action").TextColor3 == Tokens.Colour.Ink, "ink text")
				expect(root:FindFirstChild("HairTop").Visible == false, "no hairlines on the white fill")
				expect(root:FindFirstChild("Plate") == nil, "a tablet banner has no plate")
			end
			expect(budgetOf(root) <= 9, "budget 9")
			expect(banner._press() == true and presses == 1, "press calls OnPress")
			expect(banner._press() == false and presses == 1, "a second press while held is ignored")
			banner._release()
			banner._release()
			expect(releases == 1, "release calls OnRelease once")
			banner._press()
			banner.Set({ Visible = false })
			expect(releases == 2, "hiding a held banner releases it")
			expect(banner._press() == false and presses == 2, "a hidden banner takes no press")
			banner.Set({ Visible = true })
			banner._press()
			banner.Destroy()
			expect(releases == 3, "destroying a held banner releases it")
			banner._release()
			expect(releases == 3, "nothing after Destroy")
		end
	end)

	case("prompt banner: SetProgress fills the base line of a hold prompt only", function()
		local props = table.clone(JOIN)
		props.Hold = true
		local banner = bannerOn(REGULAR, "KeyboardAndMouse", props)
		local bar = banner.Instance:FindFirstChild("Progress")
		expect(bar ~= nil and bar.Visible == false, "empty at first")
		expect(bar.BackgroundColor3 == Tokens.Colour.Cyan, "cyan")
		banner.SetProgress(0.5)
		expect(bar.Visible and bar.Size.X.Offset == Tokens.Space.PromptWidth / 2, "half")
		banner.SetProgress(7)
		expect(bar.Size.X.Offset == Tokens.Space.PromptWidth, "clamped to full")
		banner.SetProgress(0 / 0)
		expect(bar.Visible == false, "not a number is empty")
		banner.SetProgress(0.5)
		banner.Set({ Hold = false })
		expect(bar.Visible == false, "no line when the prompt is not a hold")
	end)

	case("prompt banner: Set unchanged writes nothing, a patch can clear a value, unknown key errors, Destroy", function()
		local banner, parent, scope = bannerOn(REGULAR, "KeyboardAndMouse", table.clone(JOIN))
		local root = banner.Instance
		local cap = root:FindFirstChild("KeyCap")
		local snapshot = { root.Name, root.Size, root.Visible, root.Active, #root:GetDescendants() }
		banner.Set({ Action = "Join race", Object = "Race", Key = Enum.KeyCode.E, Main = false })
		local after = { root.Name, root.Size, root.Visible, root.Active, #root:GetDescendants() }
		for index = 1, #snapshot do expect(snapshot[index] == after[index], "property " .. index .. " changed") end
		expect(root:FindFirstChild("KeyCap") == cap, "the cap is not rebuilt")
		banner.Set({ Action = "Ride", Object = "" })
		expect(root:FindFirstChild("Action").Text == "RIDE", "action patched")
		expect(root:FindFirstChild("Object").Visible == false, "object cleared")
		expect(root:FindFirstChild("KeyCap") == cap, "a text change keeps the cap")
		banner.Set({ Key = Enum.KeyCode.F })
		expect(root:FindFirstChild("KeyCap") ~= nil and root:FindFirstChild("KeyCap") ~= cap, "a new key rebuilds the cap")
		banner.Set({ Key = false })
		expect(root:FindFirstChild("KeyCap") == nil, "Key = false removes the cap")
		expect(not pcall(banner.Set, { Colour = "Pink" }), "unknown key must error")
		expect(not pcall(M.PromptBanner, parent, { Nope = 1 }, newScope()), "unknown prop must error")
		scope:destroy()
		expect(#parent:GetChildren() == 0, "parent empty after scope destroy")
		banner.Destroy()
		banner.Set({ Action = "after" })
		banner.SetProgress(1)
	end)

	------------------------------------------------------------------------------------------------------------------
	-- PromptStack
	------------------------------------------------------------------------------------------------------------------

	case("prompt stack: the newest three ids are shown", function()
		local shown = M._promptShown({ "a", "b", "c", "d" }, 3)
		expect(shown.a == nil and shown.b and shown.c and shown.d, "oldest dropped")
		shown = M._promptShown({ "a" }, 3)
		expect(shown.a == true, "one")
		expect(next(M._promptShown({}, 3)) == nil, "none")
		local patch = M._promptPatch({ Action = "Enter" })
		expect(patch.Action == "Enter" and patch.Object == "" and patch.Key == false and patch.Main == false
			and patch.OnPress == false, "a Show patch carries every default")
	end)

	case("prompt stack: keyed pool, update in place, at most three shown, newest at the bottom", function()
		local parent = stageFor(REGULAR, "KeyboardAndMouse")
		local scope = newScope()
		local stack = M.PromptStack(parent, {}, scope)
		table.insert(cleanups, stack.Destroy)
		local root = stack.Instance
		expect(root.Name == "PromptStack" and root.AnchorPoint == Vector2.new(0.5, 1), "on the slot's bottom-centre anchor")
		expect(root.Size.X.Offset == Tokens.Space.PromptWidth, "as wide as a banner")
		expect(stack.Count() == 0, "empty")
		local a = stack.Show("a", { Action = "Join race", Object = "Race", Key = Enum.KeyCode.E })
		local b = stack.Show("b", { Action = "Ride", Object = "Neonrider", Key = Enum.KeyCode.F })
		expect(stack.Count() == 2 and a.Instance.Visible and b.Instance.Visible, "two shown")
		expect(b.Instance.LayoutOrder > a.Instance.LayoutOrder, "newest at the bottom")
		local built = #root:GetDescendants()
		local again = stack.Show("a", { Action = "Start time trial", Object = "Time trial", Key = Enum.KeyCode.E })
		expect(again == a and #root:GetDescendants() == built, "an existing id updates in place")
		expect(a.Instance:FindFirstChild("Action").Text == "START TIME TRIAL", "new text")
		expect(stack.Count() == 2, "still two")
		local c = stack.Show("c", { Action = "C" })
		local d = stack.Show("d", { Action = "D" })
		expect(stack.Count() == 3, "never more than three shown")
		expect(a.Instance.Visible == false and b.Instance.Visible and c.Instance.Visible and d.Instance.Visible,
			"the oldest waits")
		stack.Hide("d")
		expect(stack.Count() == 3 and a.Instance.Visible and d.Instance.Visible == false, "the waiting banner returns")
		local grown = #root:GetDescendants()
		local e = stack.Show("e", { Action = "E" })
		expect(e == d, "a hidden banner is reused")
		expect(e.Instance:FindFirstChild("Action").Text == "E" and e.Instance:FindFirstChild("KeyCap") == nil,
			"the reused banner carries only the new prompt")
		expect(#root:GetDescendants() == grown, "reuse creates nothing")
		stack.Hide("missing")
		stack.Hide("a")
		stack.Hide("b")
		stack.Hide("c")
		stack.Hide("e")
		expect(stack.Count() == 0, "empty again")
		expect(not pcall(stack.Show, "", {}), "an id is required")
		expect(not pcall(stack.Show, "x", { Visible = false }), "unknown Show key errors")
		expect(not pcall(stack.Set, { Colour = "Pink" }), "unknown key must error")
		stack.Destroy()
		stack.Destroy()
		expect(#parent:GetChildren() == 0, "parent empty after Destroy")
		expect(stack.Show("late", { Action = "Late" }) == nil, "Show after Destroy does nothing")
	end)

	case("prompt stack: hiding a held touch banner releases it", function()
		local parent = stageFor(COMPACT, "Touch")
		local stack = M.PromptStack(parent, {}, newScope())
		table.insert(cleanups, stack.Destroy)
		local releases = 0
		local banner = stack.Show("ride", { Action = "Give ride", Hold = true, OnRelease = function() releases += 1 end })
		expect(banner._press() == true, "pressed")
		stack.Hide("ride")
		expect(releases == 1, "released once at Hide")
		banner._release()
		expect(releases == 1, "and not again")
	end)

	return results
end
