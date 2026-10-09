-- Owns focus helpers, back/bumper/trigger bindings, tutorial marks and UI audio attributes for Pulse controls; owns no layout and no selected look.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Input. Requires: Metrics, Contracts.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Metrics = require(script.Parent.Metrics)
local Contracts = require(script.Parent.Contracts)

local Input = {}

local SELECTION_NAME = "PulseSelection"
local DEFAULT_PRIORITY = Enum.ContextActionPriority.High.Value

-- button -> its OnFocus connections, so a second Focusable call replaces them. Values never hold the button.
local focusConnections: { [GuiButton]: { RBXScriptConnection } } = setmetatable({}, { __mode = "k" }) :: any
-- mark key -> instances carrying it; an entry leaves when its instance is destroyed.
local marked: { [string]: { GuiObject } } = {}
-- Trapping groups that are entered, oldest first. Only the newest one pulls focus back.
local trapStack: { any } = {}
local actionCount = 0

local function isGuiButton(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("GuiButton")
end

function Input.Silence(instance: GuiObject)
	instance:SetAttribute("UIAudioHoverCue", "")
	instance:SetAttribute("UIAudioSuppressClick", true)
end

function Input.Focusable(button: GuiButton, opts: { OnFocus: ((focused: boolean) -> ())?, Decorative: boolean? }?)
	assert(isGuiButton(button), "[Pulse.Input] Focusable needs a GuiButton")
	local options = opts or {}
	local previous = focusConnections[button]
	if previous then
		for _, connection in ipairs(previous) do
			connection:Disconnect()
		end
	end

	button.Selectable = true
	local image = button.SelectionImageObject
	if not (image and image.Name == SELECTION_NAME) then
		-- Left unparented on purpose: the engine draws it only as this button's selection adornment.
		local blank = Instance.new("Frame")
		blank.Name = SELECTION_NAME
		blank.BackgroundTransparency = 1
		blank.BorderSizePixel = 0
		button.SelectionImageObject = blank
	end

	-- These two connections end with the button; Focusable has no scope to hand them to.
	local connections = {}
	local onFocus = options.OnFocus
	if onFocus then
		table.insert(connections, button.SelectionGained:Connect(function()
			onFocus(true)
		end))
		table.insert(connections, button.SelectionLost:Connect(function()
			onFocus(false)
		end))
	end
	focusConnections[button] = connections

	if options.Decorative == true then
		Input.Silence(button)
	end
end

function Input.ShouldEnterFocus(ctx: any): boolean
	if ctx.Input == "Gamepad" then
		return true
	end
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Keyboard or string.match(last.Name, "^Gamepad") ~= nil
end

local function canTakeFocus(button: GuiButton): boolean
	return button.Parent ~= nil and button.Selectable and button.Visible
end

local function displayOrderOf(object: Instance): number?
	local gui = object:FindFirstAncestorWhichIsA("ScreenGui")
	return gui and gui.DisplayOrder or nil
end

function Input.FocusGroup(scope: any, opts: { Trap: boolean? }?): any
	local trap = opts ~= nil and opts.Trap == true
	local entries: { { Button: GuiButton, Order: number, Index: number } } = {}
	local added = 0
	local entered = false
	local destroyed = false
	local saved: GuiObject? = nil
	local last: GuiButton? = nil
	local group = {}

	local function find(object: any): number?
		for index, entry in ipairs(entries) do
			if entry.Button == object then
				return index
			end
		end
		return nil
	end

	local function firstUsable(): GuiButton?
		local sorted = table.clone(entries)
		table.sort(sorted, function(a, b)
			if a.Order ~= b.Order then
				return a.Order < b.Order
			end
			return a.Index < b.Index
		end)
		for _, entry in ipairs(sorted) do
			if canTakeFocus(entry.Button) then
				return entry.Button
			end
		end
		return nil
	end

	local function leaveStack()
		local index = table.find(trapStack, group)
		if index then
			table.remove(trapStack, index)
		end
	end

	function group.Add(button: GuiButton, order: number?)
		assert(isGuiButton(button), "[Pulse.Input] FocusGroup.Add needs a GuiButton")
		if destroyed then
			return
		end
		local index = find(button)
		if index then
			if order ~= nil then
				entries[index].Order = order
			end
			return
		end
		added += 1
		table.insert(entries, { Button = button, Order = order or added, Index = added })
	end

	function group.Enter(preferred: GuiButton?)
		if destroyed then
			return
		end
		if not entered then
			entered = true
			if trap then
				saved = GuiService.SelectedObject
				table.insert(trapStack, group)
			end
		end
		local target = nil
		if preferred and find(preferred) and canTakeFocus(preferred) then
			target = preferred
		else
			target = firstUsable()
		end
		last = target
		-- A detached button cannot hold focus.
		if target and target:IsDescendantOf(game) and Input.ShouldEnterFocus(Metrics.Of(target)) then
			GuiService.SelectedObject = target
		end
	end

	function group.Leave()
		if not entered then
			return
		end
		entered = false
		if trap then
			leaveStack()
			local current = GuiService.SelectedObject
			if current == nil or find(current) then
				local back = saved
				if back and not back:IsDescendantOf(game) then
					back = nil
				end
				if current ~= back then
					GuiService.SelectedObject = back
				end
			end
		end
		saved = nil
		last = nil
	end

	function group.Destroy()
		if destroyed then
			return
		end
		group.Leave()
		destroyed = true
		table.clear(entries)
	end

	if trap then
		scope:connect(GuiService:GetPropertyChangedSignal("SelectedObject"), function()
			if not entered or trapStack[#trapStack] ~= group then
				return
			end
			local current = GuiService.SelectedObject
			if current == nil then
				return
			end
			if find(current) then
				last = current :: any
				return
			end
			local back = last
			if not (back and canTakeFocus(back)) then
				back = firstUsable()
			end
			if not back then
				return
			end
			-- A layer drawn above this one (a confirmation over a modal) may take focus.
			local theirs, mine = displayOrderOf(current), displayOrderOf(back)
			if theirs and mine and theirs > mine then
				return
			end
			GuiService.SelectedObject = back
		end)
	end
	scope:add(group.Destroy)
	return group
end

-- Binds keys under a unique Pulse action name and unbinds it when the scope ends.
local function bind(scope: any, purpose: string, priority: number?, keys: { Enum.KeyCode }, onBegin: (input: InputObject) -> ())
	actionCount += 1
	local name = "Pulse_" .. purpose .. "_" .. actionCount
	ContextActionService:BindActionAtPriority(name, function(_, state, input)
		if state == Enum.UserInputState.Begin then
			onBegin(input)
		end
		return Enum.ContextActionResult.Sink
	end, false, priority or DEFAULT_PRIORITY, table.unpack(keys))
	scope:add(function()
		ContextActionService:UnbindAction(name)
	end)
end

local function bindPair(scope: any, purpose: string, previousKey: Enum.KeyCode, nextKey: Enum.KeyCode, onPrev: () -> (), onNext: () -> ())
	assert(type(onPrev) == "function" and type(onNext) == "function", "[Pulse.Input] " .. purpose .. " needs two handlers")
	bind(scope, purpose, nil, { previousKey, nextKey }, function(input)
		-- Spawned so a handler that yields or errors cannot change what the action returns.
		if input.KeyCode == previousKey then
			task.spawn(onPrev)
		elseif input.KeyCode == nextKey then
			task.spawn(onNext)
		end
	end)
end

function Input.BindBack(scope: any, handler: () -> (), priority: number?)
	assert(type(handler) == "function", "[Pulse.Input] BindBack needs a handler")
	bind(scope, "Back", priority, { Enum.KeyCode.Escape, Enum.KeyCode.ButtonB }, function()
		task.spawn(handler)
	end)
end

function Input.BindBumpers(scope: any, onPrev: () -> (), onNext: () -> ())
	bindPair(scope, "Bumpers", Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, onPrev, onNext)
end

function Input.BindTriggers(scope: any, onPrev: () -> (), onNext: () -> ())
	bindPair(scope, "Triggers", Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2, onPrev, onNext)
end

local function markFor(key: any): any
	local mark = type(key) == "string" and Contracts.Marks[key] or nil
	if not mark then
		error("[Pulse.Input] unknown mark key '" .. tostring(key) .. "'", 3)
	end
	return mark
end

function Input.Mark(instance: GuiObject, key: string)
	assert(typeof(instance) == "Instance" and instance:IsA("GuiObject"), "[Pulse.Input] Mark needs a GuiObject")
	local mark = markFor(key)
	if mark.Text ~= nil then
		if not (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
			error("[Pulse.Input] mark '" .. key .. "' sets text and needs a text object, got " .. instance.ClassName, 2)
		end
		local textObject: any = instance
		textObject.Text = mark.Text
	end
	if mark.Name ~= nil then
		instance.Name = mark.Name
	end
	if mark.Attributes ~= nil then
		for name, value in pairs(mark.Attributes) do
			instance:SetAttribute(name, value)
		end
	end

	local list = marked[key]
	if not list then
		list = {}
		marked[key] = list
	end
	if table.find(list, instance) then
		return
	end
	table.insert(list, instance)
	instance.Destroying:Once(function()
		local index = table.find(list, instance)
		if index then
			table.remove(list, index)
		end
	end)
end

function Input.Marked(key: string): { GuiObject }
	markFor(key)
	local list = marked[key]
	return list and table.clone(list) or {}
end

return Input
