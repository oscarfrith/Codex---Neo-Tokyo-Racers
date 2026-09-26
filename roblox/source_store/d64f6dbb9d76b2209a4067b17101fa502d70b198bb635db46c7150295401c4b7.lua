-- Canonical feature implementation; startup is owned by the composition root.
-- Street Life activity HUD owner (docs/architecture/activities-contract.md). Owns the ActivityHud
-- ScreenGui: job strip, offer cards, countdown, world beacons, the JOBS panel (opened by the free-roam
-- HUD's JOBS button via PlayerScripts.Runtime.UI.OpenJobs) and the rank-up card. Mounts the feature
-- views in a fixed order and forwards ActivityEvent payloads to them. Presentation only.
local Client = {}
local state

function Client.start()
if state then assert(state == "ready", "Client startup already attempted: " .. tostring(state)); return end
state = "starting"
local ok, message = xpcall(function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
local UI = require(modules:WaitForChild("Game"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local Foundation = require(modules.Game.UI:WaitForChild("ResponsiveUIFoundation"))
local RouteGuide = require(modules.Game.UI:WaitForChild("RouteGuide"))
local activityModules = modules.Game:WaitForChild("Activities")
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Activities")
local invokeRemote = remotes:WaitForChild("ActivityInvoke")
local eventRemote = remotes:WaitForChild("ActivityEvent")
local uiFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FONT = Enum.Font.Michroma
local theme = { Font = FONT }
for name, fallback in pairs({
	Panel = Color3.fromRGB(15, 19, 24), PanelDeep = Color3.fromRGB(9, 12, 16), PanelSoft = Color3.fromRGB(24, 29, 36),
	PanelBlue = Color3.fromRGB(8, 42, 84), Outline = Color3.fromRGB(244, 46, 151), OutlineSoft = Color3.fromRGB(214, 74, 175),
	Telemetry = Color3.fromRGB(43, 225, 218), ElectricBlue = Color3.fromRGB(25, 116, 255), HighSpeed = Color3.fromRGB(246, 83, 159),
	Danger = Color3.fromRGB(196, 57, 75), Text = Color3.fromRGB(246, 248, 252), Muted = Color3.fromRGB(163, 171, 184), Disabled = Color3.fromRGB(81, 88, 99),
}) do
	local value = UI.Colour(name, fallback)
	theme[name] = typeof(value) == "Color3" and value or fallback
end

local function new(class, props, parent)
	local item = Instance.new(class)
	for key, value in pairs(props or {}) do item[key] = value end
	item.Parent = parent
	return item
end

local function event(name)
	local item = uiFolder:FindFirstChild(name)
	if not item then item = new("BindableEvent", { Name = name }, uiFolder) end
	return item
end
local openJobsEvent = event("OpenJobs")

local function toast(text, seconds)
	local notify = uiFolder:FindFirstChild("ShowTopNotification")
	if notify and notify:IsA("BindableEvent") then notify:Fire(tostring(text), seconds or 2.4) end
end

local function invoke(action, args)
	local okCall, reply = pcall(function() return invokeRemote:InvokeServer(action, args or {}) end)
	if not okCall then return { Ok = false, Message = "Connection problem. Try again." } end
	return type(reply) == "table" and reply or { Ok = reply == true }
end

-- ScreenGui and a design root scaled like the free-roam HUD (1920x1080 reference).
local gui = playerGui:FindFirstChild("ActivityHud")
if gui then gui:Destroy() end
gui = new("ScreenGui", { Name = "ActivityHud", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 84, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local root = new("Frame", { Name = "DesignRoot", BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
local rootScale = new("UIScale", {}, root)
local function layoutRoot()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local scale = isMobile and math.clamp(viewport.Y / 720, 0.55, 1) or math.clamp(math.min(viewport.X / 1920, viewport.Y / 1080), 0.72, 1.12)
	rootScale.Scale = scale
	root.Size = UDim2.fromOffset(viewport.X / scale, viewport.Y / scale)
end
layoutRoot()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutRoot) end

local function panel(parent, props)
	props = props or {}
	props.Color = props.Color or theme.PanelDeep
	props.Transparency = props.Transparency == nil and 0.12 or props.Transparency
	return UI.Panel(parent, props)
end

-- Job strip: one line at top centre; the newest Set wins, Clear removes that kind.
local stripEntries, stripOrder = {}, {}
local strip = panel(root, { Name = "JobStrip", Size = UDim2.fromOffset(isMobile and 460 or 560, 44), StrokeColor = theme.Telemetry, NoGlow = true })
strip.AnchorPoint = Vector2.new(0.5, 0)
strip.Position = UDim2.new(0.5, 0, 0, isMobile and 8 or 18)
strip.Visible = false
strip.ZIndex = 20
local stripLabel = UI.Label(strip, { Name = "Text", Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -72, 1, 0), TextSize = 13, Role = "Heading" })
stripLabel.ZIndex = 21
local stripCancel = UI.Button(strip, { Name = "Cancel", Text = "X", Size = UDim2.fromOffset(isMobile and 44 or 36, 30), Position = UDim2.new(1, isMobile and -50 or -44, 0.5, -15), Color = theme.Panel, StrokeColor = theme.Danger, TextSize = 12 })
stripCancel.ZIndex = 22
stripCancel.Activated:Connect(function()
	local reply = invoke("Cancel")
	if reply.Ok then toast("JOB CANCELLED") end
end)
local function renderStrip()
	local kind = stripOrder[#stripOrder]
	local entry = kind and stripEntries[kind]
	strip.Visible = entry ~= nil
	if entry then
		stripLabel.Text = entry.Text
		stripLabel.TextColor3 = entry.Colour or theme.Text
		local stroke = strip:FindFirstChild("Stroke")
		if stroke then stroke.Color = entry.Colour or theme.Telemetry end
	end
end
local Strip = {}
function Strip.Set(kind, text, colour)
	stripEntries[kind] = { Text = string.upper(tostring(text)), Colour = colour }
	local index = table.find(stripOrder, kind)
	if index then table.remove(stripOrder, index) end
	table.insert(stripOrder, kind)
	renderStrip()
end
function Strip.Clear(kind)
	stripEntries[kind] = nil
	local index = table.find(stripOrder, kind)
	if index then table.remove(stripOrder, index) end
	renderStrip()
end

-- Offer card (one at a time; a new offer replaces the old one).
local currentOffer
local function offer(spec)
	if currentOffer then currentOffer() end
	local buttons = spec.Buttons or {}
	local width = isMobile and 520 or 560
	local card = panel(root, { Name = "Offer", Size = UDim2.fromOffset(width, 170), StrokeColor = theme.Outline })
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, isMobile and -150 or -190)
	card.ZIndex = 30
	UI.Label(card, { Name = "Title", Text = string.upper(tostring(spec.Title or "")), Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 30), TextSize = 17, Role = "Heading" }).ZIndex = 31
	local body = UI.Label(card, { Name = "Body", Text = tostring(spec.Body or ""), Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 0, 50), TextSize = 12, Wrapped = true, Color = theme.Muted, YAlignment = Enum.TextYAlignment.Top })
	body.ZIndex = 31
	local closed = false
	local function close()
		if closed then return end
		closed = true
		if currentOffer == close then currentOffer = nil end
		card:Destroy()
	end
	local count = math.max(1, #buttons)
	local gap = 10
	local buttonWidth = math.floor((width - 40 - gap * (count - 1)) / count)
	for index, definition in ipairs(buttons) do
		local item = UI.Button(card, {
			Name = "Option" .. index, Text = string.upper(tostring(definition.Text or "")), Size = UDim2.fromOffset(buttonWidth, isMobile and 48 or 44),
			Position = UDim2.new(0, 20 + (index - 1) * (buttonWidth + gap), 1, isMobile and -62 or -58),
			Color = theme.Panel, StrokeColor = definition.Accent or theme.Outline, TextSize = 12,
		})
		item.ZIndex = 32
		if definition.Enabled == false then
			item.Active = false
			item.TextColor3 = theme.Disabled
		else
			item.Activated:Connect(function()
				close()
				if definition.OnClick then task.spawn(definition.OnClick) end
			end)
		end
	end
	if tonumber(spec.Timeout) and spec.Timeout > 0 then
		local track = new("Frame", { Name = "Timer", BackgroundColor3 = theme.PanelSoft, BorderSizePixel = 0, Position = UDim2.new(0, 20, 1, -8), Size = UDim2.new(1, -40, 0, 3), ZIndex = 31 }, card)
		local fill = new("Frame", { BackgroundColor3 = theme.Telemetry, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 32 }, track)
		TweenService:Create(fill, TweenInfo.new(spec.Timeout, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
		task.delay(spec.Timeout, close)
	end
	currentOffer = close
	return close
end

-- Countdown synced to server time.
local countdownCard
local function countdown(goAt, label)
	if countdownCard then countdownCard:Destroy() end
	local card = panel(root, { Name = "Countdown", Size = UDim2.fromOffset(220, 220), StrokeColor = theme.Outline, Transparency = 0.18 })
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.ZIndex = 40
	countdownCard = card
	local number = UI.Label(card, { Name = "Number", Text = "", Size = UDim2.new(1, 0, 0, 150), TextSize = 96, Role = "Metric", XAlignment = Enum.TextXAlignment.Center })
	number.ZIndex = 41
	UI.Label(card, { Name = "Label", Text = string.upper(tostring(label or "")), Position = UDim2.new(0, 0, 1, -56), Size = UDim2.new(1, 0, 0, 40), TextSize = 13, Color = theme.Muted, XAlignment = Enum.TextXAlignment.Center }).ZIndex = 41
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not card.Parent then connection:Disconnect() return end
		local remaining = goAt - workspace:GetServerTimeNow()
		if remaining > 0 then
			number.Text = tostring(math.ceil(remaining))
			number.TextColor3 = theme.Text
		elseif remaining > -0.9 then
			number.Text = "GO!"
			number.TextColor3 = theme.Telemetry
		else
			connection:Disconnect()
			card:Destroy()
			if countdownCard == card then countdownCard = nil end
		end
	end)
end

-- World beacons: client-only light pillars under the camera.
local beacons = {}
local function beacon(id, position, colour)
	if beacons[id] then beacons[id]:Destroy() end
	local pillar = new("Part", {
		Name = "ActivityBeacon_" .. tostring(id), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = colour or theme.Telemetry, Transparency = 0.45, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(260, 6, 6), CFrame = CFrame.new(position + Vector3.new(0, 130, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}, workspace.CurrentCamera)
	new("PointLight", { Color = colour or theme.Telemetry, Range = 40, Brightness = 2 }, pillar)
	beacons[id] = pillar
	return function()
		if beacons[id] == pillar then beacons[id] = nil end
		pillar:Destroy()
	end
end

-- JOBS panel: entries from views; Buttons may be a table or a function returning one (rebuilt on open).
local jobEntries = {}
local jobsModal = new("Frame", { Name = "JobsModal", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50 }, root)
local backdrop = new("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.32, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 50 }, jobsModal)
local shell = panel(jobsModal, { Name = "Shell", Size = UDim2.fromOffset(640, 480), StrokeColor = theme.Outline, Transparency = 0.06 })
shell.AnchorPoint = Vector2.new(0.5, 0.5)
shell.Position = UDim2.fromScale(0.5, 0.5)
shell.ZIndex = 51
UI.Label(shell, { Name = "Title", Text = "JOBS", Position = UDim2.fromOffset(24, 14), Size = UDim2.new(1, -48, 0, 40), TextSize = 22, Role = "Heading", XAlignment = Enum.TextXAlignment.Center }).ZIndex = 52
local rankLine = UI.Label(shell, { Name = "Rank", Text = "", Position = UDim2.fromOffset(24, 52), Size = UDim2.new(1, -48, 0, 20), TextSize = 11, Color = theme.Telemetry, XAlignment = Enum.TextXAlignment.Center })
rankLine.ZIndex = 52
local list = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 84), Size = UDim2.new(1, -48, 1, -160), CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = theme.Outline, ZIndex = 52 }, shell)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local closeJobs = UI.Button(shell, { Name = "Close", Text = "CLOSE", Size = UDim2.fromOffset(200, 46), Position = UDim2.new(0.5, -100, 1, -64), Color = theme.PanelBlue, StrokeColor = theme.Telemetry })
closeJobs.ZIndex = 53

local function renderJobs()
	for _, child in ipairs(list:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
	local rank = player:GetAttribute("Rank")
	rankLine.Text = rank and ("DRIVER RANK " .. tostring(rank)) or ""
	local ordered = {}
	for _, entry in pairs(jobEntries) do table.insert(ordered, entry) end
	table.sort(ordered, function(a, b) return (a.Order or 100) < (b.Order or 100) end)
	for index, entry in ipairs(ordered) do
		local row = panel(list, { Name = "Job_" .. tostring(entry.Id), Size = UDim2.new(1, -8, 0, 88), Color = theme.Panel, StrokeColor = theme.OutlineSoft, NoGlow = true })
		row.LayoutOrder = index
		row.ZIndex = 53
		UI.Label(row, { Name = "Title", Text = string.upper(tostring(entry.Title or entry.Id)), Position = UDim2.fromOffset(16, 10), Size = UDim2.new(0.5, 0, 0, 26), TextSize = 15, Role = "Heading" }).ZIndex = 54
		local subtitle = UI.Label(row, { Name = "Subtitle", Text = tostring(entry.Subtitle or ""), Position = UDim2.fromOffset(16, 38), Size = UDim2.new(0.52, 0, 0, 40), TextSize = 11, Wrapped = true, Color = theme.Muted, YAlignment = Enum.TextYAlignment.Top })
		subtitle.ZIndex = 54
		local buttons = type(entry.Buttons) == "function" and entry.Buttons() or entry.Buttons or {}
		local x = -12
		for b = #buttons, 1, -1 do
			local definition = buttons[b]
			local width = 132
			x -= width
			local item = UI.Button(row, { Name = "Button" .. b, Text = string.upper(tostring(definition.Text or "")), Size = UDim2.fromOffset(width, isMobile and 48 or 42), Position = UDim2.new(1, x, 0.5, isMobile and -24 or -21), Color = theme.PanelSoft, StrokeColor = definition.Accent or theme.Telemetry, TextSize = 11 })
			item.ZIndex = 55
			x -= 10
			if definition.Enabled == false then
				item.Active = false
				item.TextColor3 = theme.Disabled
			else
				item.Activated:Connect(function()
					jobsModal.Visible = false
					if definition.OnClick then task.spawn(definition.OnClick) end
				end)
			end
		end
	end
	if #ordered == 0 then
		UI.Label(list, { Name = "Empty", Text = "NO JOBS AVAILABLE YET", Size = UDim2.new(1, 0, 0, 60), TextSize = 13, Color = theme.Muted, XAlignment = Enum.TextXAlignment.Center }).ZIndex = 53
	end
end
local function setJobsOpen(open)
	jobsModal.Visible = open
	if open then renderJobs() end
end
backdrop.Activated:Connect(function() setJobsOpen(false) end)
closeJobs.Activated:Connect(function() setJobsOpen(false) end)
openJobsEvent.Event:Connect(function() setJobsOpen(not jobsModal.Visible) end)
local Jobs = {}
function Jobs.AddEntry(entry)
	assert(type(entry) == "table" and entry.Id, "Jobs entry needs an Id")
	jobEntries[entry.Id] = entry
	if jobsModal.Visible then renderJobs() end
end
function Jobs.Refresh()
	if jobsModal.Visible then renderJobs() end
end

-- Rank-up card; deferred while a race is presenting.
local function racing()
	if player:GetAttribute("RaceQueueActive") == true then return true end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local vehicle = seat and seat:FindFirstAncestorOfClass("Model")
	return vehicle ~= nil and (vehicle:GetAttribute("RaceParticipant") == true or vehicle:GetAttribute("RaceRunId") ~= nil)
end
local function rankUp(payload)
	task.spawn(function()
		local waited = 0
		while racing() and waited < 600 do task.wait(1); waited += 1 end
		local card = panel(root, { Name = "RankUp", Size = UDim2.fromOffset(420, 170), StrokeColor = theme.Outline, Transparency = 0.1 })
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.36)
		card.ZIndex = 45
		UI.Label(card, { Name = "Kicker", Text = "RANK UP", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 24), TextSize = 13, Color = theme.Telemetry, XAlignment = Enum.TextXAlignment.Center, Role = "Heading" }).ZIndex = 46
		UI.Label(card, { Name = "Rank", Text = "RANK " .. tostring(payload.Rank or ""), Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 64), TextSize = 44, XAlignment = Enum.TextXAlignment.Center, Role = "Metric" }).ZIndex = 46
		local cash = tonumber(payload.Cash) or 0
		UI.Label(card, { Name = "Reward", Text = cash > 0 and ("+" .. UI.FormatMoney(cash)) or "", Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 30), TextSize = 16, Color = theme.ElectricBlue, XAlignment = Enum.TextXAlignment.Center, Role = "Metric" }).ZIndex = 46
		local scale = new("UIScale", { Scale = 0.6 }, card)
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(3.5, function() card:Destroy() end)
	end)
end

local ctx = {
	Player = player,
	Invoke = invoke,
	Gui = gui,
	Root = root,
	IsMobile = isMobile,
	Theme = theme,
	RouteGuide = RouteGuide,
	Toast = toast,
	UI = {
		Button = UI.Button,
		Label = UI.Label,
		Strip = Strip,
		Offer = offer,
		Countdown = countdown,
		Beacon = beacon,
	},
	Jobs = Jobs,
}
Client.Context = ctx

local views = {}
for _, name in ipairs({ "CourierClientView", "PassengerClientView", "TaxiClientView", "DuelClientView" }) do
	local module = activityModules:FindFirstChild(name)
	if module then
		local loaded, view = pcall(require, module)
		if loaded and type(view) == "table" then
			local mounted, err = pcall(function() if view.Mount then view.Mount(ctx) end end)
			if mounted then table.insert(views, view) else warn("[ActivityClient] " .. name .. " mount failed: " .. tostring(err)) end
		else
			warn("[ActivityClient] " .. name .. " failed to load: " .. tostring(view))
		end
	end
end

eventRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Type == "Rank:Up" then rankUp(payload) end
	for _, view in ipairs(views) do
		if view.OnEvent then
			local handled, err = pcall(view.OnEvent, payload)
			if not handled then warn("[ActivityClient] view event failed: " .. tostring(err)) end
		end
	end
end)

print("[ActivityClient] Activity HUD active.")
end, debug.traceback)
state = ok and "ready" or "failed"
assert(ok, message)
end

return Client
