-- Pure tests for Kit.Input (API.md section 13). Detached instances only; focus is never moved.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local ContextActionService = game:GetService("ContextActionService")
	local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."
	local Metrics = env.Load(KIT .. "Metrics")
	local Contracts = env.Load(KIT .. "Contracts")

	local results = {}
	local function case(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(err) or nil })
	end

	-- Stands in for Core.ConnectionScope: same three methods, released in reverse order.
	local function fakeScope(): any
		local items = {}
		local scope = { Items = items }
		function scope:connect(signal, callback)
			local connection = signal:Connect(callback)
			table.insert(items, connection)
			return connection
		end
		function scope:add(item)
			table.insert(items, item)
			return item
		end
		function scope:destroy()
			for index = #items, 1, -1 do
				local item = items[index]
				if typeof(item) == "RBXScriptConnection" then
					item:Disconnect()
				elseif type(item) == "function" then
					item()
				end
			end
			table.clear(items)
		end
		return scope
	end

	local function pulseActions(): { string }
		local names = {}
		for name in pairs(ContextActionService:GetAllBoundActionInfo()) do
			if string.match(name, "^Pulse_") then
				table.insert(names, name)
			end
		end
		return names
	end

	case("Silence writes the two audio attributes", function()
		local frame = env.Detached("Frame")
		M.Silence(frame)
		assert(frame:GetAttribute("UIAudioHoverCue") == "", "UIAudioHoverCue")
		assert(frame:GetAttribute("UIAudioSuppressClick") == true, "UIAudioSuppressClick")
	end)

	case("Focusable makes the button selectable with a blank selection image", function()
		local button = env.Detached("TextButton")
		button.Selectable = false
		M.Focusable(button)
		assert(button.Selectable == true, "not selectable")
		local image = button.SelectionImageObject
		assert(image and image:IsA("Frame") and image.BackgroundTransparency == 1, "selection image is not a blank frame")
		assert(image.Parent == nil and #image:GetChildren() == 0, "selection image is parented or has children")
		assert(#button:GetChildren() == 0, "Focusable added a child")
		assert(button:GetAttribute("UIAudioSuppressClick") == nil, "a normal button was silenced")
		M.Focusable(button, { OnFocus = function() end })
		assert(button.SelectionImageObject == image, "a second call replaced the selection image")
	end)

	case("Focusable holds its focus record strongly, and a second call keeps one record", function()
		local button = env.Detached("TextButton")
		assert(M._holdsFocusRecord(button) == false, "a record exists before Focusable")
		M.Focusable(button, { OnFocus = function() end })
		assert(M._holdsFocusRecord(button) == true, "no record after Focusable")
		M.Focusable(button)
		assert(M._holdsFocusRecord(button) == true, "the record was lost by a second call")
	end)

	case("Focusable Decorative also silences; a non-button errors", function()
		local button = env.Detached("ImageButton")
		M.Focusable(button, { Decorative = true })
		assert(button:GetAttribute("UIAudioHoverCue") == "" and button:GetAttribute("UIAudioSuppressClick") == true, "not silenced")
		assert(pcall(M.Focusable, env.Detached("Frame")) == false, "a Frame was accepted")
	end)

	case("ShouldEnterFocus is true for a gamepad context", function()
		local ctx = Metrics.Fixed({ Size = Vector2.new(1920, 1080), TouchEnabled = false, Input = "Gamepad" })
		assert(M.ShouldEnterFocus(ctx) == true, "gamepad did not enter focus")
		local other = Metrics.Fixed({ Size = Vector2.new(1920, 1080), TouchEnabled = false, Input = "KeyboardAndMouse" })
		assert(type(M.ShouldEnterFocus(other)) == "boolean", "not a boolean")
	end)

	case("keyboard, mouse and touch clear engine focus; a gamepad keeps it", function()
		local button = env.Detached("TextButton")
		assert(M._clearsFocus(Enum.UserInputType.Keyboard, button) == true, "keyboard kept focus")
		assert(M._clearsFocus(Enum.UserInputType.MouseMovement, button) == true, "mouse kept focus")
		assert(M._clearsFocus(Enum.UserInputType.Touch, button) == true, "touch kept focus")
		assert(M._clearsFocus(Enum.UserInputType.Gamepad1, button) == false, "gamepad lost focus")
		assert(M._clearsFocus(Enum.UserInputType.Keyboard, nil) == false, "nothing to clear")
	end)

	case("Mark applies a legacy name and registers the instance once", function()
		local button = env.Detached("TextButton")
		button.Name = "PulseButton"
		M.Mark(button, "Car")
		M.Mark(button, "Car")
		assert(button.Name == "Car", "name not applied")
		assert(button:GetAttribute("PulseMark") == "Car", "PulseMark attribute not written")
		local list = M.Marked("Car")
		local count = 0
		for _, instance in ipairs(list) do
			if instance == button then
				count += 1
			end
		end
		assert(count == 1, "registered " .. count .. " times")
		table.clear(list)
		assert(table.find(M.Marked("Car"), button) ~= nil, "Marked handed out its own list")
	end)

	case("Mark applies attributes and text", function()
		local card = env.Detached("ImageButton")
		card.Name = "Tile"
		M.Mark(card, "Card.AddModules")
		assert(card.Name == "Tile", "an attribute mark renamed the instance")
		assert(card:GetAttribute("CanonicalGarageCard") == true, "CanonicalGarageCard")
		assert(card:GetAttribute("CanonicalGarageCardId") == "AddModules", "CanonicalGarageCardId")
		assert(card:GetAttribute("PulseMark") == "Card.AddModules", "PulseMark on an attribute mark")
		local page = env.Detached("Frame")
		M.Mark(page, "Page.PaintShop")
		assert(page:GetAttribute("TutorialWorkspace") == true and page:GetAttribute("TutorialPageId") == "PaintShop", "page mark")
		local label = env.Detached("TextLabel")
		M.Mark(label, "Text.TimeTrial")
		assert(label.Text == "TIME TRIAL", "text not applied")
		assert(pcall(M.Mark, env.Detached("Frame"), "Text.Race") == false, "a text mark on a Frame was accepted")
	end)

	case("every generated mark key can be applied", function()
		for key, mark in pairs(Contracts.Marks) do
			local instance = env.Detached(mark.Text and "TextLabel" or "TextButton")
			M.Mark(instance, key)
			assert(table.find(M.Marked(key), instance) ~= nil, key .. " was not registered")
			if mark.Name then
				assert(instance.Name == mark.Name, key .. " name")
			end
		end
	end)

	case("an unknown mark key errors in Mark and in Marked", function()
		local frame = env.Detached("Frame")
		frame.Name = "Untouched"
		assert(pcall(M.Mark, frame, "NoSuchKey") == false, "Mark accepted an unknown key")
		assert(frame.Name == "Untouched", "a failed Mark changed the instance")
		assert(frame:GetAttribute("PulseMark") == nil, "a failed Mark wrote PulseMark")
		assert(pcall(M.Marked, "NoSuchKey") == false, "Marked accepted an unknown key")
		assert(pcall(M.Mark, "not an instance", "Car") == false, "Mark accepted a string")
	end)

	case("FocusGroup adds, enters, leaves and is released by its scope", function()
		local scope = fakeScope()
		local group = M.FocusGroup(scope)
		assert(#scope.Items == 1, "a plain group should add one cleanup to the scope")
		local first, second = env.Detached("TextButton"), env.Detached("TextButton")
		group.Add(second, 2)
		group.Add(first, 1)
		group.Add(first)
		assert(pcall(group.Add, env.Detached("Frame")) == false, "Add accepted a Frame")
		group.Enter(second)
		group.Enter()
		group.Leave()
		group.Leave()
		scope:destroy()
		group.Destroy()
		group.Enter(first)
	end)

	case("a trapping FocusGroup connects through the scope and disconnects with it", function()
		local scope = fakeScope()
		local group = M.FocusGroup(scope, { Trap = true })
		local connection = nil
		for _, item in ipairs(scope.Items) do
			if typeof(item) == "RBXScriptConnection" then
				connection = item
			end
		end
		assert(connection ~= nil, "the trap did not connect through the scope")
		group.Add(env.Detached("TextButton"))
		group.Enter()
		group.Leave()
		scope:destroy()
		assert(connection.Connected == false, "the trap connection outlived the scope")
	end)

	case("BindBack, BindBumpers and BindTriggers use Pulse_ action names and unbind with the scope", function()
		local before = #pulseActions()
		local scope = fakeScope()
		M.BindBack(scope, function() end)
		M.BindBack(scope, function() end, 10000)
		M.BindBumpers(scope, function() end, function() end)
		M.BindTriggers(scope, function() end, function() end)
		local names = pulseActions()
		scope:destroy()
		assert(#names == before + 4, "expected 4 new Pulse actions, found " .. (#names - before))
		for _, name in ipairs(names) do
			assert(string.match(name, "^Pulse_%a+_%d+$") ~= nil, "bad action name " .. name)
		end
		assert(#pulseActions() == before, "actions were left bound")
		assert(pcall(M.BindBack, fakeScope(), nil) == false, "BindBack accepted no handler")
	end)

	-- API2 2.10 -----------------------------------------------------------------------------------------------
	case("FocusGroup.Remove takes a button out; unknown buttons and repeats are ignored", function()
		local scope = fakeScope()
		local group = M.FocusGroup(scope)
		assert(type(group.Remove) == "function", "Remove missing")
		local first, second = env.Detached("TextButton"), env.Detached("TextButton")
		group.Add(first, 1)
		group.Add(second, 2)
		group.Remove(first)
		group.Remove(first)
		group.Remove(env.Detached("TextButton"))
		group.Enter(first)
		group.Leave()
		group.Add(first, 1)
		group.Remove(second)
		scope:destroy()
		group.Remove(first)
	end)

	case("BindAction uses the name as given and unbinds with the scope", function()
		local name = "PulseTestClassicActionName"
		assert(ContextActionService:GetAllBoundActionInfo()[name] == nil, "the test name is already bound")
		local scope = fakeScope()
		local calls = 0
		M.BindAction(scope, name, function(_, state)
			-- The engine calls the handler once with Cancel when the action is unbound; that is not input.
			if state ~= Enum.UserInputState.Cancel then
				calls += 1
			end
			return Enum.ContextActionResult.Pass
		end, 2000, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
		local info = ContextActionService:GetAllBoundActionInfo()[name]
		scope:destroy()
		assert(info ~= nil, "not bound under the given name")
		assert(ContextActionService:GetAllBoundActionInfo()[name] == nil, "left bound after the scope ended")
		assert(calls == 0, "the handler ran without input")
		assert(pcall(M.BindAction, fakeScope(), "", function() end, nil, Enum.KeyCode.M) == false, "empty name accepted")
		assert(pcall(M.BindAction, fakeScope(), name, nil, nil, Enum.KeyCode.M) == false, "no handler accepted")
		assert(pcall(M.BindAction, fakeScope(), name, function() end, nil) == false, "no key accepted")
		assert(ContextActionService:GetAllBoundActionInfo()[name] == nil, "a refused call left an action bound")
	end)

	return results
end
