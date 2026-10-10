-- Owns the full map state (open, pan, zoom, pointers, waypoint, legend rows, the FullMapOpen attribute, the input-gate token); not a single GuiObject, the map layers or the input bindings.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.WorldMap.FullMapModel. Requires: none (every service, shared module and handle arrives in deps).
local Model = {}
Model.__index = Model

-- FullMapUI 449-450.
Model.Blocking = { "GarageSessionActive", "OwnedGarageInside", "RaceSessionActive", "RaceQueueActive", "DrivingControlsOpen",
	"FirstDrivePresentationPending", "MobileMajorMenuOpen", "MobileFreeRoamCarMenuOpen" }

-- FullMapUI 296-301.
Model.KeyLabels = {
	Dealership = "DEALERSHIP", Garage = "MY GARAGE", Customisation = "CUSTOMISATION", Race = "RACE", TimeTrial = "TIME TRIAL",
	TaxiFare = "TAXI FARE", CourierPickup = "COURIER PICKUP", CourierDrop = "COURIER DROP-OFF", TaxiDrop = "TAXI DROP-OFF",
	Duel = "STREET DUEL", Job = "JOB", Waypoint = "WAYPOINT",
}
Model.KeyOrder = { "Waypoint", "Dealership", "Garage", "Customisation", "Race", "TimeTrial", "TaxiFare", "CourierPickup", "CourierDrop", "TaxiDrop", "Duel", "Job" }

local WAYPOINT = "Waypoint"
local LEGEND_SETTLE = 0.25 -- FullMapUI 842
local STICK_DEADZONE = 0.15 -- FullMapUI 784

-- name -> { fallback, minimum, maximum } (the Config.UI.FullMap numbers the model uses; FullMapUI's own defaults).
local NUMBERS = {
	BoundsMarginStuds = { 600, 0, 20000 }, PanMinX = { -5192 }, PanMaxX = { 4310 }, PanMinZ = { -7161 }, PanMaxZ = { 10857 },
	OpenVisibleStuds = { 5000, 100, 100000 }, MinVisibleStuds = { 500, 50, 100000 }, MaxVisibleStuds = { 40000, 100, 200000 },
	ZoomStep = { 1.25, 1.01, 4 }, MobileLegendMinViewport = { 760, 0, 5000 }, DragThresholdPixels = { 8, 1, 64 },
	WaypointY = { 101, -1000, 5000 }, KeyboardPanSpeed = { 0.9, 0, 10 }, GamepadPanSpeed = { 1, 0, 10 }, CentreResponse = { 12, 0, 60 },
}
local FLAGS = { Enabled = true, RememberZoom = true, LegendOpen = true, LockGameplayInput = true }

local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(handler)
		local connection = { Connected = true }
		handlers[connection] = handler
		function connection:Disconnect()
			connection.Connected = false
			handlers[connection] = nil
		end
		return connection
	end
	function signal:Fire(...)
		local list = {}
		for _, handler in handlers do
			table.insert(list, handler)
		end
		for _, handler in list do
			handler(...)
		end
	end
	return signal
end

-- deps: Player, PlayerGui, RouteGuide, MapMarkers, MapMath, InputGate, Presence, Calibration (function),
-- Config (function(name) -> raw value), Subject (function() -> root part?, owned vehicle?), PlayerCount (function),
-- IsCompact (function), Delay (task.delay), RotationOffset (number).
function Model.new(deps)
	local self = setmetatable({}, Model)
	self.Deps = deps
	self.Math = deps.MapMath
	self.Changed = newSignal()
	self.IsOpenNow = false
	self.Cal = deps.Calibration()
	self.C = {}
	self:ReadConfig()
	self.Pan = Vector2.new(0.5, 0.5)
	self.PanTarget = nil
	self.VisibleStuds = self.C.OpenVisibleStuds
	self.RememberedStuds = nil
	self.View = { W = 1, H = 1, Short = 1, Centre = Vector2.new(0.5, 0.5) }
	self.ViewSize = Vector2.new(1, 1)
	self.Bounds = self:ReadBounds()
	self.LegendOpenNow = true
	self.LegendPending = false
	self.InputToken = nil
	self.ReleasePresence = nil
	self.Stick = Vector2.zero
	self.UsingGamepad = false
	self.Pointers, self.Pinch, self.MultiTouch = {}, nil, false
	self.PresentationOwners = {}
	self.SubjectRoot, self.SubjectVehicle = nil, nil
	deps.Player:SetAttribute("FullMapOpen", false) -- FullMapUI 848
	return self
end

-- Read at construction and on every open, never in the frame step (FullMapUI 70-78 read each value at use).
function Model:ReadConfig()
	local read, math2 = self.Deps.Config, self.Math
	for name, spec in NUMBERS do
		local value = math2.Finite(read(name), spec[1])
		self.C[name] = math.clamp(value, spec[2] or -math.huge, spec[3] or math.huge)
	end
	for name, fallback in FLAGS do
		local value = read(name)
		self.C[name] = if type(value) == "boolean" then value else fallback
	end
	self.C.DistrictName = string.upper(tostring(read("DistrictName") or ""))
end

-- FullMapUI 182-186.
function Model:ReadBounds()
	local c = self.C
	local margin = c.BoundsMarginStuds
	return self.Math.BoundsToUnits(self.Cal, c.PanMinX - margin, c.PanMaxX + margin, c.PanMinZ - margin, c.PanMaxZ + margin)
end

function Model:IsOpen(): boolean
	return self.IsOpenNow
end
function Model:LegendOpen(): boolean
	return self.LegendOpenNow
end
function Model:District(): string
	return self.C.DistrictName
end
function Model:HasWaypoint(): boolean
	return self.Deps.MapMarkers.Get(WAYPOINT) ~= nil
end
function Model:HintMode(): string
	return self.UsingGamepad and "Gamepad" or "Pointer"
end

-- FullMapUI 205-241.
function Model:Side(): number
	return self.Math.CanvasSide(self.Cal.FullStuds, self.View.Short, self.VisibleStuds)
end
function Model:StudLimits(): (number, number)
	local minimum = self.C.MinVisibleStuds
	local maximum = math.max(minimum, self.C.MaxVisibleStuds)
	if self.Bounds then
		maximum = math.max(minimum, math.min(maximum, self.Math.FitStudsForBounds(self.Cal, self.Bounds, self.View.W, self.View.H)))
	end
	return minimum, maximum
end
function Model:ClampView()
	local minimum, maximum = self:StudLimits()
	self.VisibleStuds = self.Math.ClampVisibleStuds(self.VisibleStuds, minimum, maximum)
	local side = self:Side()
	self.Pan = self.Math.ClampPan(self.Pan, side, self.View.W, self.View.H, self.Bounds)
	if self.PanTarget then
		self.PanTarget = self.Math.ClampPan(self.PanTarget, side, self.View.W, self.View.H, self.Bounds)
	end
end
function Model:ZoomTo(studs: number, anchor: Vector2?)
	local minimum, maximum = self:StudLimits()
	studs = self.Math.ClampVisibleStuds(studs, minimum, maximum)
	local before = self:Side()
	self.VisibleStuds = studs
	local after = self:Side()
	local point = anchor or self.View.Centre
	self.Pan = self.Math.ZoomAbout(self.Pan, before, after, point, self.View.Centre)
	if point ~= self.View.Centre then
		self.PanTarget = nil
	end
	self:ClampView()
end
function Model:ZoomStep(steps: number, anchor: Vector2?)
	self:ZoomTo(self.VisibleStuds / (self.C.ZoomStep ^ steps), anchor)
end
function Model:ShowAll()
	local _, maximum = self:StudLimits()
	self:ZoomTo(maximum)
	local bounds = self.Bounds
	self.PanTarget = Vector2.new((bounds.UMin + bounds.UMax) * 0.5, (bounds.VMin + bounds.VMax) * 0.5)
	self:ClampView()
end

-- The map view's size in pixels (FullMapUI 436-442).
function Model:SetViewSize(w: number, h: number)
	local view = self.View
	view.W, view.H = math.max(1, w), math.max(1, h)
	view.Short = math.max(1, math.min(view.W, view.H))
	view.Centre = Vector2.new(view.W * 0.5, view.H * 0.5)
	self.ViewSize = Vector2.new(view.W, view.H)
	self.Bounds = self:ReadBounds()
	self:ClampView()
end
function Model:InsideView(point: Vector2): boolean
	return point.X >= 0 and point.Y >= 0 and point.X <= self.View.W and point.Y <= self.View.H
end

-- Subject (FullMapUI 243-263). The walk itself is deps.Subject; it runs on events, and the step reads the cache.
function Model:RefreshSubject()
	self.SubjectRoot, self.SubjectVehicle = self.Deps.Subject()
	return self.SubjectRoot, self.SubjectVehicle
end
function Model:PlayerUnit(): Vector2?
	local root = self.SubjectRoot
	if not root or root.Parent == nil then
		return nil
	end
	local position = root.Position
	local u, v = self.Math.WorldToUnit(self.Cal, position.X, position.Z)
	return Vector2.new(u, v)
end
function Model:CentreOnPlayer()
	self.PanTarget = self:PlayerUnit()
end
-- Screen heading of the player arrow (FullMapUI 813-814), nil when the look vector is vertical.
function Model:Heading(lookX: number, lookZ: number): number?
	local heading = self.Math.Heading(self.Cal, lookX, lookZ)
	return heading and heading + (self.Deps.RotationOffset or 0) or nil
end

-- Waypoint (FullMapUI 265-293): the same RouteGuide and MapMarkers calls, in the same order.
function Model:SetWaypoint(position: Vector3, labelText: string?)
	local deps = self.Deps
	deps.RouteGuide.Clear("Player")
	deps.RouteGuide.SetDestination(WAYPOINT, position, { Label = labelText or "WAYPOINT", Priority = 5 })
	deps.MapMarkers.Set(WAYPOINT, { Position = position, Icon = "Waypoint", Label = labelText or "WAYPOINT", Kind = "Waypoint", Priority = 50, EdgeClamp = true })
	self:MarkLegendDirty()
end
function Model:ClearWaypoint()
	self.Deps.RouteGuide.Clear(WAYPOINT)
	self.Deps.MapMarkers.Remove(WAYPOINT)
	self:MarkLegendDirty()
end
function Model:OnRouteChanged(active)
	local deps = self.Deps
	if active == nil then
		if deps.MapMarkers.Get(WAYPOINT) then
			deps.MapMarkers.Remove(WAYPOINT)
		end
		self:MarkLegendDirty()
	elseif active.Source == "Player" and deps.MapMarkers.Get(WAYPOINT) then
		deps.RouteGuide.Clear(WAYPOINT)
		deps.MapMarkers.Remove(WAYPOINT)
		self:MarkLegendDirty()
	end
end
function Model:OnArrived(destination)
	if destination and destination.Source == WAYPOINT then
		self.Deps.MapMarkers.Remove(WAYPOINT)
		self:MarkLegendDirty()
	end
end

-- Legend rows (FullMapUI 303-324). The view owns the arrow image, so no Image field is carried.
function Model:LegendEntries(): { any }
	local entries = { { Icon = "Player", Kind = "Player", Label = "YOU" } }
	if self.Deps.PlayerCount() > 1 then
		table.insert(entries, { Icon = "OtherPlayer", Kind = "Player", Label = "OTHER DRIVERS" })
	end
	local present = {}
	for _, marker in self.Deps.MapMarkers.All() do
		if marker.FullMap ~= false and marker.Icon ~= "" and present[marker.Icon] == nil then
			present[marker.Icon] = marker.Kind
		end
	end
	for _, icon in Model.KeyOrder do
		if present[icon] then
			table.insert(entries, { Icon = icon, Kind = present[icon], Label = Model.KeyLabels[icon] })
			present[icon] = nil
		end
	end
	local extra = {}
	for icon, kind in present do
		table.insert(extra, { Icon = icon, Kind = kind, Label = string.upper(icon) })
	end
	table.sort(extra, function(a, b)
		return a.Icon < b.Icon
	end)
	for _, entry in extra do
		table.insert(entries, entry)
	end
	return entries
end

-- One legend refresh at most every 0.25 s while open (FullMapUI 842-845 polled a dirty flag in the render step).
function Model:MarkLegendDirty()
	if not self.IsOpenNow or self.LegendPending then
		return
	end
	self.LegendPending = true
	self.Deps.Delay(LEGEND_SETTLE, function()
		self.LegendPending = false
		if self.IsOpenNow then
			self.Changed:Fire("Legend")
		end
	end)
end
function Model:ToggleLegend()
	self.LegendOpenNow = not self.LegendOpenNow
	self.Changed:Fire("Legend")
end

-- FullMapUI 451-461. Event time only: it reads attributes.
function Model:Blocked(): boolean
	local deps = self.Deps
	if not self.C.Enabled then
		return true
	end
	for _, name in Model.Blocking do
		if deps.Player:GetAttribute(name) == true then
			return true
		end
	end
	if deps.PlayerGui:GetAttribute("OwnedGarageManagementOpen") == true then
		return true
	end
	if next(self.PresentationOwners) ~= nil then
		return true
	end
	local _, vehicle = self:RefreshSubject()
	if vehicle and (vehicle:GetAttribute("RaceParticipant") == true or vehicle:GetAttribute("RaceRunId") ~= nil) then
		return true
	end
	return false
end
-- The Classic render step called blocked() every frame (773); the client calls this from attribute signals.
function Model:CloseIfBlocked()
	if self.IsOpenNow and self:Blocked() then
		self:Close()
	end
end

-- FullMapUI 507-537.
function Model:Open(): boolean
	if self.IsOpenNow then
		return true
	end
	self:ReadConfig()
	if self:Blocked() then
		return false
	end
	local deps, c = self.Deps, self.C
	self.IsOpenNow = true
	self.Cal = deps.Calibration()
	self.VisibleStuds = (c.RememberZoom and self.RememberedStuds) or c.OpenVisibleStuds
	-- A Compact screen (a phone) always opens with the legend closed, so the map is never covered until the player
	-- asks for the key (mobile pass 2026-10-10). Classic closed it only under MobileLegendMinViewport (760 px), which
	-- an 844-wide phone passes; that attribute no longer changes anything under Pulse.
	self.LegendOpenNow = c.LegendOpen and not deps.IsCompact()
	self.Bounds = self:ReadBounds()
	self:ClampView()
	self.Pan = self:PlayerUnit() or Vector2.new(0.5, 0.5)
	self.PanTarget = nil
	self:ClampView()
	deps.Player:SetAttribute("FullMapOpen", true)
	if c.LockGameplayInput and not self.InputToken then
		self.InputToken = deps.InputGate.Acquire("FullMap", "V1")
	end
	if deps.Presence and not self.ReleasePresence then
		self.ReleasePresence = deps.Presence.Open("FullMap", "Map")
	end
	self.Changed:Fire("Open")
	return true
end

-- FullMapUI 481-505.
function Model:Close()
	if not self.IsOpenNow then
		return
	end
	local deps = self.Deps
	self.IsOpenNow = false
	table.clear(self.Pointers)
	self.Pinch, self.MultiTouch, self.Stick = nil, false, Vector2.zero
	if self.C.RememberZoom then
		self.RememberedStuds = self.VisibleStuds
	end
	if self.InputToken then
		deps.InputGate.Release(self.InputToken, true)
		self.InputToken = nil
	end
	deps.Player:SetAttribute("FullMapOpen", false)
	if self.ReleasePresence then
		self.ReleasePresence()
		self.ReleasePresence = nil
	end
	self.Changed:Fire("Close")
end

-- FullMapUI 539-543. minimapShowing is the HUD owner's answer (API2 5.4).
function Model:Toggle(minimapShowing: boolean): boolean
	if self.IsOpenNow then
		self:Close()
		return false
	end
	if not minimapShowing then
		return false
	end
	return self:Open()
end

-- Presentation owners (FullMapUI 753-760).
function Model:SetPresentation(payload)
	local owners = self.PresentationOwners
	if typeof(payload) == "table" then
		owners[tostring(payload.Owner or "Racing")] = payload.Active == true or nil
	else
		owners.Racing = tostring(payload) == "Racing" or nil
	end
	if next(owners) ~= nil then
		self:Close()
	end
end

function Model:SetUsingGamepad(gamepad: boolean)
	gamepad = gamepad == true
	if gamepad ~= self.UsingGamepad then
		self.UsingGamepad = gamepad
		self.Changed:Fire("Input")
	end
end
function Model:SetStick(x: number, y: number)
	self.Stick = Vector2.new(x, y)
end

-- The tap rule (FullMapUI 560-577). hitId is the icon layer's answer for the same point.
function Model:Tap(point: Vector2, hitId: string?)
	if not self:InsideView(point) then
		return
	end
	local deps = self.Deps
	local marker = hitId and deps.MapMarkers.Get(hitId)
	if hitId == WAYPOINT then
		self:ClearWaypoint()
		return
	end
	local y = self.C.WaypointY
	if marker and (marker.Kind == "Place" or marker.Kind == "Race" or marker.Kind == "Job") then
		self:SetWaypoint(Vector3.new(marker.Position.X, y, marker.Position.Z), string.upper(marker.Label))
		return
	end
	local unit = self.Math.ScreenToUnit(self.Pan, point, self.View.Centre, self:Side())
	local x, z = self.Math.UnitToWorld(self.Cal, unit.X, unit.Y)
	self:SetWaypoint(Vector3.new(x, y, z), "WAYPOINT")
end

-- Pointers (FullMapUI 579-665). key is "Mouse" or the touch InputObject; points are map-view pixels.
function Model:PointerCount(): number
	local count = 0
	for _ in self.Pointers do
		count += 1
	end
	return count
end
function Model:BeginPinch()
	local a, b
	for _, pointer in self.Pointers do
		if not a then
			a = pointer
		elseif not b then
			b = pointer
		end
	end
	if not (a and b) then
		self.Pinch = nil
		return
	end
	local mid = (a.Last + b.Last) * 0.5
	self.Pinch = { A = a, B = b, Distance = math.max(1, (a.Last - b.Last).Magnitude), Studs = self.VisibleStuds,
		Unit = self.Math.ScreenToUnit(self.Pan, mid, self.View.Centre, self:Side()) }
end
function Model:PointerBegan(key: any, point: Vector2)
	if not self.IsOpenNow then
		return
	end
	self.Pointers[key] = { Start = point, Last = point, Moved = false }
	self.PanTarget = nil
	if self:PointerCount() >= 2 then
		self.MultiTouch = true
		self:BeginPinch()
	end
end
function Model:PointerMoved(key: any, point: Vector2)
	local pointer = self.Pointers[key]
	if not pointer or not self.IsOpenNow then
		return
	end
	local delta = point - pointer.Last
	pointer.Last = point
	if not pointer.Moved and (point - pointer.Start).Magnitude >= self.C.DragThresholdPixels then
		pointer.Moved = true
	end
	local pinch = self.Pinch
	if pinch and (pinch.A == pointer or pinch.B == pointer) then
		local distance = math.max(1, (pinch.A.Last - pinch.B.Last).Magnitude)
		local minimum, maximum = self:StudLimits()
		self.VisibleStuds = self.Math.ClampVisibleStuds(pinch.Studs * pinch.Distance / distance, minimum, maximum)
		local mid = (pinch.A.Last + pinch.B.Last) * 0.5
		self.Pan = pinch.Unit - (mid - self.View.Centre) / self:Side()
		self:ClampView()
	elseif pointer.Moved and self:PointerCount() == 1 then
		self.Pan -= delta / self:Side()
		self.PanTarget = nil
		self:ClampView()
	end
end
-- Returns the point to tap, or nil (a drag, a pinch, or a closed map).
function Model:PointerEnded(key: any): Vector2?
	local pointer = self.Pointers[key]
	if not pointer then
		return nil
	end
	self.Pointers[key] = nil
	local pinch = self.Pinch
	if pinch and (pinch.A == pointer or pinch.B == pointer) then
		self.Pinch = nil
		for _, other in self.Pointers do
			other.Moved = true
		end
	end
	local tap = if self.IsOpenNow and not pointer.Moved and not self.MultiTouch then pointer.Start else nil
	if self:PointerCount() == 0 then
		self.MultiTouch = false
	end
	return tap
end

-- The model part of the render step (FullMapUI 774-792). moveX, moveY: the key pan direction (-1..1).
-- Perf.Bind-safe: arithmetic on cached values only.
function Model:Step(dt: number, moveX: number, moveY: number)
	if not self.IsOpenNow then
		return
	end
	local c = self.C
	local move = Vector2.new(moveX, moveY) * c.KeyboardPanSpeed
	local stick = self.Stick
	if stick.Magnitude > STICK_DEADZONE then
		move += Vector2.new(stick.X, -stick.Y) * c.GamepadPanSpeed
	end
	local side = self:Side()
	if move.Magnitude > 0 then
		self.Pan += move * dt * self.View.Short / side
		self.PanTarget = nil
	elseif self.PanTarget then
		self.Pan = self.Math.Approach(self.Pan, self.PanTarget, c.CentreResponse, dt)
		if (self.Pan - self.PanTarget).Magnitude * side < 0.5 then
			self.Pan, self.PanTarget = self.PanTarget, nil
		end
	end
	self:ClampView()
end

-- Fills the shared MapView table in place (API2 5.4). Perf.Bind-safe.
function Model:FillView(view: any): any
	local x, z = self.Math.UnitToWorld(self.Cal, self.Pan.X, self.Pan.Y)
	view.Calibration = self.Cal
	view.CentreX, view.CentreZ = x, z
	view.VisibleStuds = self.VisibleStuds
	view.RotationDegrees = 0
	view.Size = self.ViewSize
	view.Round = false
	view.FullMap = true
	return view
end

return Model
