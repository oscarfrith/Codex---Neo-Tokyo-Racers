-- Owns the gallery fixtures for the touch drive controls and the activity HUD (the B half of the FreeRoam family); not the gallery, the HUD fixtures (Dev.Fixtures.FreeRoam), any real model, remote or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.FreeRoamActivity. Requires: Layers, FreeRoam.TouchControlsView, FreeRoam.ActivityHudView, FreeRoam.ActivityHudClient (for its pure theme only), Tokens, Text.
local Pulse = script.Parent.Parent.Parent
local Kit = Pulse.Kit
local Layers = require(Kit.Layers)
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)
local TouchControlsView = require(Pulse.FreeRoam.TouchControlsView)
local ActivityHudView = require(Pulse.FreeRoam.ActivityHudView)
local ActivityHudClient = require(Pulse.FreeRoam.ActivityHudClient)

-- The gallery mounts an item in a slot or at the stage centre; a view needs a whole layer, so each fixture builds
-- its own Layers.Stage over the gallery stage.
local function newStage(parent, ctx, frame, name)
	local stage = parent:FindFirstAncestor("Stage") or parent
	local host = Instance.new("Frame")
	host.Name = name
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromScale(1, 1)
	host.Parent = stage
	return host, Layers.Stage(host, ctx, frame)
end

-- Touch controls -------------------------------------------------------------------------------------------

local ARROWS = table.freeze({ "TurnLeft", "TurnRight", "DriftLeft", "DriftRight" })

local function mountTouch(parent, props, scope, ctx)
	local host, layer = newStage(parent, ctx, "Bare", "TouchControlsFixture")
	local view = TouchControlsView.Mount(layer, nil, scope)
	view.Root.Visible = true
	local destroyed = false

	local function apply(state)
		local mode = state.Mode or "Arrows"
		for _, name in ipairs(ARROWS) do
			view.Buttons[name].Visible = mode == "Arrows"
		end
		view.ThumbHit.Visible = mode == "Thumbstick"
		view.Buttons.TiltDrift.Visible = mode == "Tilt"
		view.Buttons.TiltRecenter.Visible = mode == "Tilt"
		view.TiltStatus.Visible = mode == "Tilt"
		view.TiltStatus.Text = state.Status or "TILT STEERING"
		for name, button in pairs(view.Buttons) do
			view.Pressed(button, state.Pressed ~= nil and table.find(state.Pressed, name) ~= nil)
		end
		view.SetBoostPercent(state.Boost or 100)
		view.Layout()
	end
	apply(props)

	local component = { Instance = host }
	function component.Set(patch)
		if not destroyed then
			apply(patch)
		end
	end
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		view.Destroy()
		layer.Destroy()
		host:Destroy()
	end
	return component
end

-- Activity HUD ---------------------------------------------------------------------------------------------

local function mountActivity(parent, props, scope, ctx)
	local host, layer = newStage(parent, ctx, "Hud", "ActivityHudFixture")
	local theme = ActivityHudClient._theme(Tokens, Text)
	local destroyed = false

	-- A fake model: the getters the view reads, canned state, no remote, no bindable, a frozen clock.
	local model = { Theme = theme }
	model.Clock = function()
		return model.Elapsed or 0
	end
	model.ServerNow = function()
		return 0
	end
	model.StripEntry = function()
		return model.StripValue
	end
	model.OfferState = function()
		return model.OfferValue
	end
	model.CountdownState = function()
		return model.CountdownValue
	end
	model.RankUpState = function()
		return model.RankValue
	end
	model.Cancel = function() end
	model.PressOffer = function() end
	model.CountdownEnded = function() end

	local view = ActivityHudView.Mount(layer, model, scope, layer)
	local duel = nil

	local function apply(state)
		model.StripValue = state.Strip and { Kind = "Fixture", Text = state.Strip, Colour = theme[state.StripColour or "Telemetry"] } or nil
		if state.Offer then
			local buttons = {}
			for index, option in ipairs(state.Offer.Buttons) do
				buttons[index] = { Text = option.Text, Accent = option.Accent and theme[option.Accent] or nil, Enabled = option.Enabled ~= false }
			end
			model.Elapsed = state.Offer.Elapsed or 0
			model.OfferValue = { Title = state.Offer.Title, Body = state.Offer.Body, Buttons = buttons, Timeout = state.Offer.Timeout, StartedAt = 0 }
		else
			model.OfferValue = nil
		end
		model.CountdownValue = state.Countdown and { GoAt = state.Countdown.Seconds, Label = state.Countdown.Label } or nil
		model.RankValue = state.Rank and { Text = "RANK " .. tostring(state.Rank), Cash = state.Cash or 0 } or nil
		view.Render()
		view._step()
		if state.Duel and not duel then
			duel = ActivityHudView.Button(layer.Slot("BottomCentre"), { Name = "DuelChallengeButton", Text = state.Duel }, scope)
			duel.AnchorPoint = layer.Slot("BottomCentre").AnchorPoint
		end
		if duel then
			duel.Visible = state.Duel ~= nil
			if state.Duel then
				duel.Text = state.Duel
			end
		end
	end
	apply(props)

	local component = { Instance = host }
	function component.Set(patch)
		if not destroyed then
			apply(patch)
		end
	end
	function component.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		view.Destroy()
		layer.Destroy()
		host:Destroy()
	end
	return component
end

local LONG_NAME = "MAXIMILIANA_THE_NEON_RIDER_2009"

return {
	{
		Id = "FreeRoam.TouchControls",
		Frame = "Bare",
		States = {
			{ Id = "Arrows", Props = { Mode = "Arrows", Boost = 100 } },
			{ Id = "ArrowsHeld", Props = { Mode = "Arrows", Pressed = { "Accelerator", "TurnRight", "Boost" }, Boost = 64 } },
			{ Id = "DriftAndBrake", Props = { Mode = "Arrows", Pressed = { "DriftLeft", "Brake" }, Boost = 0 } },
			{ Id = "Thumbstick", Props = { Mode = "Thumbstick", Boost = 37 } },
			{ Id = "Tilt", Props = { Mode = "Tilt", Boost = 100 } },
			{ Id = "TiltCalibrated", Props = { Mode = "Tilt", Status = "TILT CALIBRATED", Pressed = { "TiltDrift" }, Boost = 100 } },
		},
		Mount = mountTouch,
	},
	{
		Id = "FreeRoam.ActivityHud",
		Frame = "Hud",
		States = {
			{ Id = "Empty", Props = {} },
			{ Id = "StripTaxi", Props = { Strip = "TAXI · 1.2 MI TO GO · ~$1,240" } },
			{ Id = "StripDuel", Props = { Strip = "DUEL VS NEONRIDER · $5,000", StripColour = "HighSpeed" } },
			{ Id = "StripLongest", Props = { Strip = "RIDING WITH " .. LONG_NAME .. " · JUMP TO EXIT" } },
			{ Id = "OfferDuel", Props = { Offer = {
				Title = "DUEL CHALLENGE", Body = "NEONRIDER challenges you to a street duel for $5,000. Winner takes $10,000.", Timeout = 15, Elapsed = 6,
				Buttons = { { Text = "ACCEPT", Accent = "Telemetry" }, { Text = "DECLINE" } },
			} } },
			{ Id = "OfferStakes", Props = { Offer = {
				Title = "STREET DUEL", Body = "Race " .. LONG_NAME .. " to a finish across the city. Winner takes both stakes.", Timeout = 15, Elapsed = 1,
				Buttons = { { Text = "FREE" }, { Text = "$1,000", Accent = "HighSpeed" }, { Text = "$5,000", Accent = "HighSpeed" }, { Text = "CANCEL" } },
			} } },
			{ Id = "OfferDisabled", Props = { Offer = {
				Title = "STREET DUEL", Body = "Race NEONRIDER to a finish across the city. Cash stakes unlock at Driver Rank 3.",
				Buttons = { { Text = "FREE" }, { Text = "$5,000", Accent = "HighSpeed", Enabled = false }, { Text = "CANCEL" } },
			} } },
			{ Id = "Countdown3", Props = { Countdown = { Seconds = 3, Label = "DUEL" }, Strip = "DUEL VS NEONRIDER · XP", StripColour = "HighSpeed" } },
			{ Id = "CountdownGo", Props = { Countdown = { Seconds = 0, Label = "DUEL" } } },
			{ Id = "RankUp", Props = { Rank = 7, Cash = 5000 } },
			{ Id = "RankUpNoCash", Props = { Rank = 12 } },
			{ Id = "DuelButton", Props = { Duel = "CHALLENGE NEONRIDER" } },
			{ Id = "DuelButtonLongest", Props = { Duel = "CHALLENGE " .. LONG_NAME } },
		},
		Mount = mountActivity,
	},
}
