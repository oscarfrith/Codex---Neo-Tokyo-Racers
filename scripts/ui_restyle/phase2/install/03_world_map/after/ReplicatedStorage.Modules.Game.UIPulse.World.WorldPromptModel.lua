-- Owns the world prompt rules (family classification, who sees which banner, the banner state machine) and the event card's two read requests with their cache; not a GuiObject, a prompt's Enabled, a Triggered handler or the action a prompt performs.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.World.WorldPromptModel. Requires: none (everything arrives in deps).
local Model = {}
Model.__index = Model

-- Prompt name -> family (audit/followup-world-prompts.md; phase0/results/s1_spike11a_start.json).
local FAMILY = {
	RaceEntryPrompt = "RaceEntry",
	EnterVehiclePrompt = "EnterVehicle",
	DriveOutPrompt = "DriveOut",
	FootExitPrompt = "FootExit",
	ManageGaragePrompt = "ManageGarage",
	OwnedGarageDriveInEntryPrompt = "GarageDriveIn",
	OwnedGarageFootEntryPrompt = "GarageFootEntry",
	CanonicalDealership = "Entrance",
	CanonicalCustomisation = "Entrance",
	CanonicalDriveIn = "Entrance",
	PassengerRidePrompt = "PassengerRide",
	JobPrompt = "Job",
}
Model.Families = FAMILY

-- Every Presence kind except Race hides the banners (API2 5.4, PC 7.2).
Model.BlockingKinds = { "FullMenu", "Garage", "Results", "Map", "Modal", "SidePanel", "Loading" }

function Model.Classify(name: any): string?
	return type(name) == "string" and FAMILY[name] or nil
end

function Model.PresenceBlocked(presence: any): boolean
	if not presence then
		return false
	end
	for _, kind in Model.BlockingKinds do
		if presence.Any(kind) then
			return true
		end
	end
	return false
end

-- facts: { Blocked: boolean, LocalUserId: number, OwnerUserId: number?, Visitor: boolean }. Pure.
-- Hides what the engine's default UI shows wrongly: Enter on a car that is not yours, Drive Out and Manage Garage
-- for a visitor, and everything while a major surface is open.
function Model.Visible(family: string, facts: any): boolean
	if facts.Blocked then
		return false
	end
	if family == "EnterVehicle" then
		return facts.OwnerUserId ~= nil and facts.OwnerUserId == facts.LocalUserId
	end
	if family == "DriveOut" or family == "ManageGarage" then
		return facts.Visitor ~= true
	end
	return true
end

-- prompt: any table or instance with ActionText, ObjectText, KeyboardKeyCode, GamepadKeyCode, HoldDuration. Pure.
function Model.BannerProps(family: string, prompt: any): any
	local object = string.upper(tostring(prompt.ObjectText or ""))
	return {
		Action = string.upper(tostring(prompt.ActionText or "")),
		Object = object ~= "" and object or nil,
		Key = prompt.KeyboardKeyCode,
		PadKey = prompt.GamepadKeyCode,
		Main = family == "RaceEntry",
		Hold = (tonumber(prompt.HoldDuration) or 0) > 0,
	}
end

-- The banner state machine. Pure.
--   Pending     known, still drawn by the engine (found while showing, or its Style was put back); made ours on hide
--   Custom      Style = Custom, not showing
--   Shown       our banner is up
--   Suppressed  the engine says showing, a rule hides the banner
--   Failed      set back to Default for good; never touched again
-- event: "Track" | "TrackShowing" | "Shown" | "ShownDefault" | "Hidden" | "Refresh" | "Fail".
-- Returns the next state and an effect: "Custom" (set Style = Custom) | "Show" | "Hide" | "Default" | nil.
function Model.Next(current: string?, event: string, visible: boolean?): (string?, string?)
	if current == "Failed" then
		return "Failed", nil
	end
	if event == "Fail" then
		return "Failed", "Default"
	end
	if current == nil then
		if event == "Track" then
			return "Custom", "Custom"
		elseif event == "TrackShowing" then
			return "Pending", nil
		end
		return nil, nil
	end
	if event == "Shown" then
		-- "Shown" means the engine shows the prompt and its Style is Custom, so nothing else draws it: a Pending
		-- prompt (first seen while showing, already Custom) gets its banner too, never a Custom prompt with none.
		if current == "Custom" or current == "Pending" then
			if visible then
				return "Shown", "Show"
			end
			return "Suppressed", nil
		end
		return current, nil
	elseif event == "ShownDefault" then
		-- Someone put Default back; the engine is drawing it. Ours again once it hides.
		if current == "Shown" then
			return "Pending", "Hide"
		end
		return "Pending", nil
	elseif event == "Hidden" then
		if current == "Shown" then
			return "Custom", "Hide"
		elseif current == "Pending" then
			return "Custom", "Custom"
		end
		return "Custom", nil
	elseif event == "Refresh" then
		if current == "Shown" and not visible then
			return "Suppressed", "Hide"
		elseif current == "Suppressed" and visible then
			return "Shown", "Show"
		end
		return current, nil
	end
	return current, nil
end

-- RaceEntryPresentationClient 82-87, with the minutes padded as the preview shows them [seen r16a].
function Model.TimeText(seconds: any): string
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return "--:--.---"
	end
	local minutes = math.floor(seconds / 60)
	return string.format("%02d:%06.3f", minutes, seconds - minutes * 60)
end

-- The event card's texts. facts: { EventId, Mode, RouteId }; summary: the GetEntryDetails Summary or nil. Pure.
-- compact (optional): the format line drops the mode when it has laps or checkpoints to show; a phone's banner
-- already names it ("START TIME TRIAL") and the line must fit a narrow card.
function Model.CardText(facts: any, summary: any, compact: boolean?): any
	local mode = facts.Mode == "Race" and "RACE" or "TIME TRIAL"
	if type(summary) ~= "table" then
		local name = tostring(facts.RouteId or "")
		return { Title = string.upper(name ~= "" and name or tostring(facts.EventId or "")), Sub = mode, Prize = nil }
	end
	local parts = { mode }
	local laps = tonumber(summary.DefaultLapCount or summary.Laps)
	if laps and laps > 0 then
		table.insert(parts, tostring(laps) .. (laps == 1 and " LAP" or " LAPS"))
	end
	local checkpoints = tonumber(summary.CheckpointCount)
	if checkpoints and checkpoints > 0 then
		table.insert(parts, tostring(checkpoints) .. (checkpoints == 1 and " CHECKPOINT" or " CHECKPOINTS"))
	end
	if compact and #parts > 1 then
		table.remove(parts, 1)
	end
	local prize = tonumber(summary.BaseReward)
	return {
		Title = string.upper(tostring(summary.DisplayName or summary.RouteDisplayName or facts.EventId or "")),
		Sub = table.concat(parts, " · "),
		Prize = prize and prize > 0 and prize or nil,
	}
end

function Model.EventKey(eventId: any, mode: any): string
	return tostring(eventId) .. "|" .. tostring(mode)
end

-- deps: Presence, LocalUserId (number), Facts (function(prompt, family) -> { OwnerUserId?, Visitor }),
-- RaceRequest (function() -> RemoteFunction?), Spawn (task.spawn).
function Model.new(deps)
	local self = setmetatable({}, Model)
	self.Deps = deps
	-- prompt -> { State, Family, Id }. Strong keys: a weak key lets the record of a prompt nothing else in Luau
	-- holds (the server-made race start prompt) be collected while the instance lives, which lost its Custom state
	-- and left it without a banner. The owner calls Forget when a prompt goes.
	self.Records = {}
	self.NextId = 0
	self.Events = {} -- EventKey -> { Summary, Best = { [tier] = seconds }, Busy }
	return self
end

function Model:Record(prompt)
	return self.Records[prompt]
end

function Model:visible(prompt, record): boolean
	local facts = self.Deps.Facts(prompt, record.Family) or {}
	facts.Blocked = Model.PresenceBlocked(self.Deps.Presence)
	facts.LocalUserId = self.Deps.LocalUserId
	return Model.Visible(record.Family, facts)
end

-- Applies one event to one prompt; returns the effect (see Next) and the record.
function Model:Apply(prompt, event: string): (string?, any)
	local record = self.Records[prompt]
	if not record then
		local family = Model.Classify(prompt.Name)
		if not family or (event ~= "Track" and event ~= "TrackShowing") then
			return nil, nil
		end
		self.NextId += 1
		record = { State = nil, Family = family, Id = "Prompt" .. tostring(self.NextId) }
		self.Records[prompt] = record
	end
	local visible = nil
	if event == "Shown" or event == "Refresh" then
		visible = self:visible(prompt, record)
	end
	local nextState, effect = Model.Next(record.State, event, visible)
	record.State = nextState
	return effect, record
end

-- Re-evaluates every prompt the engine is showing (Presence or the visitor flag changed).
-- Returns { { Prompt, Record, Effect } } for the ones that flip.
function Model:Refresh(): { any }
	local changes = {}
	for prompt, record in self.Records do
		if record.State == "Shown" or record.State == "Suppressed" then
			local effect = self:Apply(prompt, "Refresh")
			if effect then
				table.insert(changes, { Prompt = prompt, Record = record, Effect = effect })
			end
		end
	end
	return changes
end

function Model:Forget(prompt)
	self.Records[prompt] = nil
end

-- The one remote call site of this owner. Both actions are existing, rate-limited reads; a reply is an untrusted shape.
function Model:call(remote, action: string, payload: any): any
	local ok, reply = pcall(function()
		return remote:InvokeServer(action, payload)
	end)
	if ok and type(reply) == "table" then
		return reply
	end
	return nil
end

-- Called once per show of a race start prompt. onUpdate(entry) runs at once with whatever is cached, and again
-- when the requests return. Details are cached per event and mode for the session; the personal best is read
-- once per show (it changes after a run) and its last value is shown meanwhile. Requests run one after the other.
function Model:FetchEvent(eventId: string, mode: string, tier: string?, onUpdate: (any) -> ())
	local key = Model.EventKey(eventId, mode)
	local entry = self.Events[key]
	if not entry then
		entry = { Summary = nil, Best = {}, Busy = false }
		self.Events[key] = entry
	end
	onUpdate(entry)
	local needDetails = entry.Summary == nil
	local needBest = mode == "TimeTrial" and type(tier) == "string" and tier ~= ""
	if entry.Busy or not (needDetails or needBest) then
		return
	end
	entry.Busy = true
	self.Deps.Spawn(function()
		local remote = self.Deps.RaceRequest()
		if remote then
			if needDetails then
				local reply = self:call(remote, "GetEntryDetails", { EventId = eventId, Mode = mode })
				if reply and reply.Ok == true and type(reply.Summary) == "table" then
					entry.Summary = reply.Summary
				end
			end
			if needBest then
				local reply = self:call(remote, "GetTimeTrialPersonalBest", { EventId = eventId, VehicleTier = tier })
				if reply then
					local record = type(reply.Record) == "table" and reply.Record or nil
					entry.Best[tier] = tonumber(reply.BestSeconds or (record and record.BestSeconds)) or 0
				end
			end
		end
		entry.Busy = false
		onUpdate(entry)
	end)
end

return Model
