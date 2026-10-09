-- Owns the gallery fixtures of the WorldMap family (full map, event card, prompt banners) over fake models; not the gallery, the real models, a remote or a player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.WorldMap. Requires: Metrics, Layers, Overlay, Map.MapCanvas, WorldMap.FullMapView, World.EventCardView, World.WorldPromptModel (pure rules only).
local Pulse = script.Parent.Parent.Parent
local Kit = Pulse.Kit
local Metrics = require(Kit.Metrics)
local Layers = require(Kit.Layers)
local Overlay = require(Kit.Overlay)
local MapCanvas = require(Pulse.Map.MapCanvas)
local FullMapView = require(Pulse.WorldMap.FullMapView)
local EventCardView = require(Pulse.World.EventCardView)
local PromptRules = require(Pulse.World.WorldPromptModel)

local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(handler)
		local connection = {}
		handlers[connection] = handler
		function connection:Disconnect()
			handlers[connection] = nil
		end
		return connection
	end
	function signal:Fire(...)
		for _, handler in table.clone(handlers) do
			handler(...)
		end
	end
	return signal
end

-- A stage of the preset's size with its own slots, whatever the gallery hands in as parent.
local function stage(parent, ctx, frame)
	local holder = Instance.new("Frame")
	holder.Name = "WorldMapStage"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(ctx.Size.X, ctx.Size.Y)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Parent = parent
	Metrics.Bind(holder, ctx)
	return holder, Layers.Stage(holder, ctx, frame)
end

local function component(holder, onSet, onDestroy)
	local destroyed = false
	local result = { Instance = holder }
	function result.Set(patch)
		if not destroyed and onSet then
			onSet(patch)
		end
	end
	function result.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if onDestroy then
			onDestroy()
		end
		holder:Destroy()
	end
	return result
end

-- Full map ------------------------------------------------------------------------------------------------------
local ALL_ICONS = { "Waypoint", "Dealership", "Garage", "Customisation", "Race", "TimeTrial", "TaxiFare", "CourierPickup", "CourierDrop", "TaxiDrop", "Duel", "Job" }
local LABELS = {
	Dealership = "DEALERSHIP", Garage = "MY GARAGE", Customisation = "CUSTOMISATION", Race = "RACE", TimeTrial = "TIME TRIAL",
	TaxiFare = "TAXI FARE", CourierPickup = "COURIER PICKUP", CourierDrop = "COURIER DROP-OFF", TaxiDrop = "TAXI DROP-OFF",
	Duel = "STREET DUEL", Job = "JOB", Waypoint = "WAYPOINT",
}

local function fakeMapModel(props)
	local model = {
		Changed = newSignal(),
		View = { W = 1, H = 1, Short = 1, Centre = Vector2.new(0.5, 0.5) },
		SubjectRoot = nil,
		State = props,
	}
	function model:IsOpen() return true end
	function model:LegendOpen() return self.State.Legend ~= false end
	function model:District() return self.State.District or "" end
	function model:HasWaypoint() return self.State.Waypoint == true end
	function model:HintMode() return self.State.Gamepad and "Gamepad" or "Pointer" end
	function model:Heading() return nil end
	function model:SetViewSize(w, h)
		self.View.W, self.View.H = math.max(1, w), math.max(1, h)
		self.View.Short = math.min(self.View.W, self.View.H)
		self.View.Centre = Vector2.new(self.View.W * 0.5, self.View.H * 0.5)
	end
	function model:LegendEntries()
		local entries = { { Icon = "Player", Kind = "Player", Label = "YOU" } }
		if self.State.Others then
			table.insert(entries, { Icon = "OtherPlayer", Kind = "Player", Label = "OTHER DRIVERS" })
		end
		for _, icon in self.State.Icons or {} do
			table.insert(entries, { Icon = icon, Kind = "Place", Label = LABELS[icon] or string.upper(icon) })
		end
		return entries
	end
	function model:ToggleLegend()
		self.State.Legend = not self:LegendOpen()
		self.Changed:Fire("Legend")
	end
	function model:ZoomStep() end
	function model:CentreOnPlayer() end
	function model:ShowAll() end
	function model:Close() end
	function model:ClearWaypoint()
		self.State.Waypoint = false
		self.Changed:Fire("Legend")
	end
	return model
end

local function mountMap(parent, props, scope, ctx)
	local holder, layer = stage(parent, ctx, "Menu")
	local model = fakeMapModel(table.clone(props))
	local view = FullMapView.Mount(layer, model, scope)
	-- One still frame of the real map image, when the place has its calibration and tiles. Never required for the fixture.
	pcall(function()
		local calibration = MapCanvas.Calibration()
		view.Step({
			Calibration = calibration, CentreX = calibration.CenterX, CentreZ = calibration.CenterZ, VisibleStuds = 5000,
			RotationDegrees = 0, Size = ctx.Size, Round = false, FullMap = true,
		}, nil)
	end)
	return component(holder, function(patch)
		for key, value in patch do
			model.State[key] = value
		end
		model.Changed:Fire("Legend")
		model.Changed:Fire("Input")
	end, view.Destroy)
end

-- Event card ----------------------------------------------------------------------------------------------------
local function mountCard(parent, props, scope, ctx)
	local holder, layer = stage(parent, ctx, "Hud")
	local card = EventCardView.Mount(layer, {}, scope)
	local function apply(state)
		card.Show({ EventId = state.EventId, Mode = state.Mode, RouteId = state.RouteId, Tier = state.Tier, Rating = state.Rating })
		if state.Summary or state.Best then
			card.Update(PromptRules.EventKey(state.EventId, state.Mode), { Summary = state.Summary, Best = { [state.Tier or ""] = state.Best } })
		end
	end
	local current = table.clone(props)
	apply(current)
	return component(holder, function(patch)
		for key, value in patch do
			current[key] = value
		end
		apply(current)
	end, card.Destroy)
end

local SHOWROOM = { DisplayName = "Showroom Loop", RouteDisplayName = "Showroom Loop", DefaultLapCount = 3, CheckpointCount = 17, BaseReward = 10000 }
local LONG = { DisplayName = "Shifted Canal Sprint Championship Qualifier", DefaultLapCount = 10, CheckpointCount = 128, BaseReward = 123456789 }

-- Prompt banners ------------------------------------------------------------------------------------------------
local function prompt(name, action, object, key, pad, hold)
	return { Name = name, ActionText = action, ObjectText = object, KeyboardKeyCode = key or Enum.KeyCode.E,
		GamepadKeyCode = pad or Enum.KeyCode.ButtonX, HoldDuration = hold or 0 }
end

local FAMILY_PROMPTS = {
	prompt("RaceEntryPrompt", "Join Race", "Race"),
	prompt("RaceEntryPrompt", "Start Time Trial", "Time Trial"),
	prompt("EnterVehiclePrompt", "Enter", "Vehicle"),
	prompt("DriveOutPrompt", "Drive Out", "Seraph"),
	prompt("FootExitPrompt", "Exit Garage", "Garage Door"),
	prompt("ManageGaragePrompt", "Manage Garage", "Garage Desk"),
	prompt("OwnedGarageDriveInEntryPrompt", "DRIVE INTO GARAGE", "KANDA TWO-BAY"),
	prompt("OwnedGarageFootEntryPrompt", "OPEN GARAGE", "KANDA TWO-BAY"),
	prompt("CanonicalDealership", "Enter", "Dealership"),
	prompt("PassengerRidePrompt", "RIDE", "NeonRider", Enum.KeyCode.F, Enum.KeyCode.ButtonY),
	prompt("JobPrompt", "Give ride", "Taxi fare · 1.2 mi trip · ~$1,234"),
}

local function mountBanners(parent, props, scope, _ctx)
	local stack = Overlay.PromptStack(parent, {}, scope)
	local function apply(list)
		for index = 1, #FAMILY_PROMPTS + 1 do
			stack.Hide("Fixture" .. tostring(index))
		end
		for index, item in list do
			local family = PromptRules.Classify(item.Name) or "Entrance"
			stack.Show("Fixture" .. tostring(index), PromptRules.BannerProps(family, item))
		end
	end
	apply(props.Prompts)
	local result = { Instance = stack.Instance }
	function result.Set(patch)
		if patch.Prompts then
			apply(patch.Prompts)
		end
	end
	function result.Destroy()
		stack.Destroy()
	end
	return result
end

local bannerStates = {
	{ Id = "RaceStartAndRide", Props = { Prompts = { FAMILY_PROMPTS[2], FAMILY_PROMPTS[10] } } },
	{ Id = "LongestJob", Props = { Prompts = { FAMILY_PROMPTS[11], FAMILY_PROMPTS[7], FAMILY_PROMPTS[6] } } },
	{ Id = "Hold", Props = { Prompts = { prompt("FootExitPrompt", "Exit Garage", "Garage Door", nil, nil, 0.5) } } },
	{ Id = "None", Props = { Prompts = {} } },
}
for index, item in FAMILY_PROMPTS do
	table.insert(bannerStates, { Id = "Family" .. tostring(index) .. item.Name, Props = { Prompts = { item } } })
end

return {
	{
		Id = "WorldMap.FullMap",
		Frame = "Menu",
		States = {
			{ Id = "Open", Props = { District = "AKANE DISTRICT", Legend = true, Waypoint = true, Others = true, Icons = ALL_ICONS } },
			{ Id = "LegendClosed", Props = { District = "AKANE DISTRICT", Legend = false, Waypoint = false, Icons = ALL_ICONS } },
			{ Id = "Gamepad", Props = { District = "AKANE DISTRICT", Legend = true, Gamepad = true, Waypoint = true, Icons = ALL_ICONS } },
			{ Id = "Empty", Props = { District = "", Legend = true, Waypoint = false, Icons = {} } },
			{ Id = "UnknownIcon", Props = { District = "A VERY LONG DISTRICT NAME FOR THE TITLE LINE", Legend = true, Waypoint = true, Icons = { "Race", "SomethingNew" } } },
		},
		Mount = mountMap,
	},
	{
		Id = "World.EventCard",
		Frame = "Hud",
		States = {
			{ Id = "TimeTrial", Props = { EventId = "showroom_loop_tt", Mode = "TimeTrial", RouteId = "ShowroomLoop", Tier = "S", Rating = 939, Summary = SHOWROOM, Best = 63.275 } },
			{ Id = "Race", Props = { EventId = "showroom_loop_race", Mode = "Race", RouteId = "ShowroomLoop", Tier = "S", Rating = 939, Summary = SHOWROOM } },
			{ Id = "Loading", Props = { EventId = "showroom_loop_tt", Mode = "TimeTrial", RouteId = "ShowroomLoop", Tier = "S", Rating = 939 } },
			{ Id = "NoBest", Props = { EventId = "showroom_loop_tt", Mode = "TimeTrial", RouteId = "ShowroomLoop", Tier = "D", Rating = 310, Summary = SHOWROOM, Best = 0 } },
			{ Id = "OnFoot", Props = { EventId = "showroom_loop_tt", Mode = "TimeTrial", RouteId = "ShowroomLoop", Tier = "", Summary = SHOWROOM } },
			{ Id = "Longest", Props = { EventId = "shifted_canal_sprint_tt", Mode = "TimeTrial", RouteId = "ShiftedCanalSprint", Tier = "S", Rating = 999, Summary = LONG, Best = 5999.999 } },
		},
		Mount = mountCard,
	},
	{
		Id = "World.PromptBanners",
		Frame = "Hud",
		Slot = "PromptStack",
		States = bannerStates,
		Mount = mountBanners,
	},
}
