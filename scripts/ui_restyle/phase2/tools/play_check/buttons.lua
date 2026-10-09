-- Pulse Play check: buttons. CLIENT side, READ-ONLY. Run during Play as the source of an unparented ModuleScript
-- (no loadstring). It requires no game module, fires no remote, writes nothing and creates no instance.
-- Lists the visible GuiButtons under one ScreenGui so the UI can be driven with mouse input. Returns ONE JSON string:
--   { ok, gui, inset = {x, y}, viewport = {x, y}, buttons = [{name, path, class, text, marks, centre = {x, y},
--     mouse = {x, y}, size = {x, y}, zIndex, active, selectable}] }
-- centre is in AbsolutePosition space. mouse = centre + the top-left GuiInset, the space of
-- UserInputService:GetMouseLocation() and of injected mouse input. Check `mouse` against a capture once per session.
local ARGS = {
	gui = "RaceBrowser", -- ScreenGui name under PlayerGui
	includeHidden = false, -- true also lists buttons that are not effectively visible (visible = false in the row)
	nameContains = nil, -- optional filter on the button name or text
	max = 200,
}

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local function reply(data)
	data.check = "buttons"
	data.gui = ARGS.gui
	return HttpService:JSONEncode(data)
end

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return reply({ ok = false, error = "PlayerGui not found" })
end
local matches = {}
for _, child in ipairs(playerGui:GetChildren()) do
	if child:IsA("ScreenGui") and child.Name == ARGS.gui then
		table.insert(matches, child)
	end
end
if #matches == 0 then
	local names = {}
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return reply({ ok = false, error = "no ScreenGui with that name", screenGuis = names })
end
local gui = matches[1]

local function plain(value)
	local kind = typeof(value)
	if kind == "string" or kind == "number" or kind == "boolean" then
		return value
	end
	return tostring(value)
end

-- Visible when the ScreenGui is enabled, every GuiObject from the button up to it is Visible, and it has a size.
local function effectivelyVisible(object)
	if object.AbsoluteSize.X <= 0 or object.AbsoluteSize.Y <= 0 then
		return false
	end
	local current = object
	while current and current ~= gui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current == gui and gui.Enabled
end

local function textOf(button)
	if button:IsA("TextButton") and button.Text ~= "" then
		return button.Text
	end
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Text ~= "" and descendant.Visible then
			return descendant.Text
		end
	end
	return ""
end

local function relativePath(object)
	local parts = {}
	local current = object
	while current and current ~= gui do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local insetTopLeft = GuiService:GetGuiInset()
local camera = workspace.CurrentCamera
local viewport = if camera then camera.ViewportSize else Vector2.zero
local buttons, total, truncated = {}, 0, false
for _, descendant in ipairs(gui:GetDescendants()) do
	if descendant:IsA("GuiButton") then
		local visible = effectivelyVisible(descendant)
		local text = textOf(descendant)
		local wanted = visible or ARGS.includeHidden
		if wanted and type(ARGS.nameContains) == "string" then
			wanted = string.find(descendant.Name, ARGS.nameContains, 1, true) ~= nil or string.find(text, ARGS.nameContains, 1, true) ~= nil
		end
		if wanted then
			total += 1
			if #buttons < ARGS.max then
				local marks = {}
				for name, value in pairs(descendant:GetAttributes()) do
					marks[name] = plain(value)
				end
				local position, size = descendant.AbsolutePosition, descendant.AbsoluteSize
				local centreX, centreY = position.X + size.X / 2, position.Y + size.Y / 2
				table.insert(buttons, {
					name = descendant.Name,
					path = relativePath(descendant),
					class = descendant.ClassName,
					text = string.sub(text, 1, 80),
					marks = marks,
					visible = visible,
					centre = { x = math.round(centreX), y = math.round(centreY) },
					mouse = { x = math.round(centreX + insetTopLeft.X), y = math.round(centreY + insetTopLeft.Y) },
					size = { x = math.round(size.X), y = math.round(size.Y) },
					onScreen = centreX >= 0 and centreY >= -insetTopLeft.Y and centreX <= viewport.X and centreY <= viewport.Y,
					zIndex = descendant.ZIndex,
					active = descendant.Active,
					interactable = descendant.Interactable,
					selectable = descendant.Selectable,
				})
			else
				truncated = true
			end
		end
	end
end
table.sort(buttons, function(a, b)
	if a.centre.y ~= b.centre.y then
		return a.centre.y < b.centre.y
	end
	return a.centre.x < b.centre.x
end)

local root = gui:FindFirstChild("Root")
return reply({
	ok = true,
	duplicates = #matches,
	uiStyle = plain(gui:GetAttribute("UIStyle")),
	enabled = gui.Enabled,
	rootVisible = if root and root:IsA("GuiObject") then root.Visible else nil,
	displayOrder = gui.DisplayOrder,
	ignoreGuiInset = gui.IgnoreGuiInset,
	inset = { x = insetTopLeft.X, y = insetTopLeft.Y },
	viewport = { x = viewport.X, y = viewport.Y },
	count = total,
	truncated = truncated,
	buttons = buttons,
})
