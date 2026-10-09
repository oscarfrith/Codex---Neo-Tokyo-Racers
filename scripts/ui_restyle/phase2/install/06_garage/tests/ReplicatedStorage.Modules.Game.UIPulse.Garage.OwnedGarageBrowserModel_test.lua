-- Pure tests for Garage.OwnedGarageBrowserModel (API2 6.4). Every dependency is a fake table: no remote, bindable,
-- player, instance or yield. Each remote call is asserted as (action, payload keys) against Classic
-- UI.OwnedGarageBrowserUI and contract_b.json.
return function(M, _env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function keys(payload)
		local list = {}
		for key in pairs(payload or {}) do
			table.insert(list, tostring(key))
		end
		table.sort(list)
		return table.concat(list, ",")
	end

	-- A harness: fakes plus the logs the cases read. `deferred = true` queues spawned functions until run().
	local function harness(options)
		options = options or {}
		local h = { calls = {}, loads = {}, fires = {}, pushes = {}, replies = options.replies or {}, attributes = options.attributes or {}, queue = {}, reasons = {} }
		local generation = 0
		local function bindable(name)
			return {
				IsA = function(_, class)
					return class == "BindableEvent"
				end,
				Fire = function(_, ...)
					table.insert(h.fires, { name = name, args = { ... } })
				end,
			}
		end
		local bindables = { FreeRoamHudPresentationMode = bindable("FreeRoamHudPresentationMode"), ShowTopNotification = bindable("ShowTopNotification") }
		h.remote = {
			InvokeServer = function(_, action, payload)
				table.insert(h.calls, { action = action, payload = payload })
				local reply = h.replies[action]
				if type(reply) == "function" then
					return reply(payload)
				end
				return reply
			end,
		}
		h.push = {
			FireServer = function(_, payload)
				table.insert(h.pushes, payload)
			end,
		}
		h.loading = {
			Invoke = function(_, action, payload)
				table.insert(h.loads, { action = action, payload = payload })
				if action == "Begin" then
					generation += 1
					return generation
				end
				return nil
			end,
		}
		h.player = {
			Character = nil,
			GetAttribute = function(_, name)
				return h.attributes[name]
			end,
			RequestStreamAroundAsync = function() end,
		}
		h.model = M.new({
			Remotes = { OwnedGarageInvoke = h.remote, OwnedGarageEvent = h.push },
			Bindables = { LoadingTransitionInvoke = h.loading },
			RuntimeUi = {
				FindFirstChild = function(_, name)
					return bindables[name]
				end,
			},
			Player = h.player,
			Workspace = {
				FindFirstChild = function()
					return nil
				end,
			},
			Clock = function()
				return 0
			end,
			Wait = function() end,
			Spawn = function(body)
				if options.deferred then
					table.insert(h.queue, body)
				else
					body()
				end
			end,
			CanOpen = options.canOpen,
		})
		h.model.Changed:Connect(function(reason)
			table.insert(h.reasons, reason)
		end)
		function h.run()
			local queue = h.queue
			h.queue = {}
			for _, body in ipairs(queue) do
				body()
			end
		end
		function h.count(action)
			local total = 0
			for _, call in ipairs(h.calls) do
				if call.action == action then
					total += 1
				end
			end
			return total
		end
		function h.last(action)
			for index = #h.calls, 1, -1 do
				if h.calls[index].action == action then
					return h.calls[index]
				end
			end
			return nil
		end
		return h
	end

	local function stateReply(extra)
		local reply = {
			Success = true,
			ActiveGarageId = "kanda",
			Properties = {
				{ PropertyId = "shibuya", DisplayName = "Shibuya Loft", District = "Shibuya", Description = "Four bays.", Filled = 0, Capacity = 4 },
				{ PropertyId = "kanda", DisplayName = "Kanda Two-Bay", District = "Kanda", Description = "A two-bay starter garage.", Filled = 1, Capacity = 2, Image = "123" },
			},
		}
		for key, value in pairs(extra or {}) do
			reply[key] = value
		end
		return reply
	end

	case("initial snapshot: closed, Mine, no rows, the Classic enter text", function()
		local h = harness()
		local snapshot = h.model:Snapshot()
		expect(snapshot.Open == false and h.model:IsOpen() == false, "closed")
		expect(snapshot.Mode == "Mine" and snapshot.TabsVisible == false, "mine, no tabs")
		expect(#snapshot.Rows == 0, "no rows")
		expect(snapshot.Enter.Visible == true and snapshot.Enter.Text == "ENTER GARAGE", "enter text")
		expect(#h.calls == 0 and #h.fires == 0, "nothing sent at construction")
	end)

	case("open: presentation fire, loading status, GetState {}, rows and the active garage selected", function()
		local h = harness({ deferred = true, replies = { GetState = stateReply() } })
		h.model:Open()
		expect(h.model:IsOpen(), "open")
		expect(#h.fires == 1 and h.fires[1].name == "FreeRoamHudPresentationMode", "one presentation fire")
		local message = h.fires[1].args[1]
		expect(message.Owner == "OwnedGarageBrowser" and message.Active == true and message.KeepTelemetry == false, "presentation payload")
		expect(keys(message) == "Active,KeepTelemetry,Owner", "presentation keys")
		expect(h.model:Snapshot().Status.Text == "LOADING GARAGES..." and h.model:Snapshot().Status.Good == true, "loading status")
		expect(#h.calls == 0, "the request is spawned, not inline")
		h.run()
		expect(#h.calls == 1 and h.calls[1].action == "GetState" and keys(h.calls[1].payload) == "", "GetState {}")
		local snapshot = h.model:Snapshot()
		expect(#snapshot.Rows == 2, "two rows")
		expect(snapshot.Rows[1].Key == "Garage_shibuya" and snapshot.Rows[2].Key == "Garage_kanda", "row keys keep the Classic names")
		expect(snapshot.SelectedKey == "Garage_kanda" and snapshot.Rows[2].Selected == true and snapshot.Rows[1].Selected == false, "active garage selected")
		expect(snapshot.Detail.Title == "KANDA TWO-BAY" and snapshot.Detail.District == "KANDA", "detail upper-cased")
		expect(snapshot.Detail.Capacity == "1 / 2 DISPLAY SPACES", "Classic capacity text")
		expect(snapshot.Detail.Image == "123", "image passed through")
		expect(snapshot.Enter.Visible and snapshot.Enter.Enabled and snapshot.Enter.Text == "ENTER GARAGE", "enter")
		expect(snapshot.Status.Visible == false and snapshot.Status.Text == "", "status cleared")
	end)

	case("open with a property id selects it; an unknown id falls back to the first property", function()
		local h = harness({ replies = { GetState = stateReply() } })
		h.model:Open("shibuya")
		expect(h.model:Snapshot().SelectedKey == "Garage_shibuya", "requested property")
		h.model:Close()
		h.model:Open("nowhere")
		expect(h.model:Snapshot().SelectedKey == "Garage_shibuya", "first property")
	end)

	case("open: a failed or malformed reply shows the message and keeps the screen usable", function()
		local h = harness({ replies = { GetState = { Success = false, Message = "Try again." } } })
		h.model:Open()
		expect(h.model:Snapshot().Status.Text == "Try again." and h.model:Snapshot().Status.Good == false, "failure message")
		local g = harness({ replies = { GetState = "not a table" } })
		g.model:Open()
		expect(g.model:Snapshot().Status.Text == "Garage service unavailable.", "malformed reply")
		expect(g.model:IsOpen(), "still open, the view keeps its EXIT button")
		local e = harness({ replies = { GetState = { Success = true, Properties = "bad" } } })
		e.model:Open()
		expect(e.model:Snapshot().Detail.Title == "NO GARAGES" and e.model:Snapshot().Enter.Visible == false, "no garages")
	end)

	case("open: a reply that arrives after close is ignored", function()
		local h = harness({ deferred = true, replies = { GetState = stateReply() } })
		h.model:Open()
		h.model:Close()
		h.run()
		expect(#h.model:Snapshot().Rows == 0, "stale reply dropped")
		expect(h.model:IsOpen() == false, "closed")
	end)

	case("CanOpen false: nothing opens and nothing is sent", function()
		local h = harness({ canOpen = function()
			return false
		end, replies = { GetState = stateReply() } })
		h.model:Open()
		h.model:Toggle()
		expect(h.model:IsOpen() == false and #h.calls == 0 and #h.fires == 0, "closed and silent")
	end)

	case("close: fires the presentation release even when it was not open (Classic 86)", function()
		local h = harness()
		h.model:Close("Transition")
		expect(#h.fires == 1 and h.fires[1].args[1].Active == false and h.fires[1].args[1].Owner == "OwnedGarageBrowser", "release fire")
	end)

	case("select: a row press selects that property", function()
		local h = harness({ replies = { GetState = stateReply() } })
		h.model:Open()
		h.model:SelectKey("Garage_shibuya")
		local snapshot = h.model:Snapshot()
		expect(snapshot.SelectedKey == "Garage_shibuya" and snapshot.Detail.Title == "SHIBUYA LOFT", "selected")
		expect(snapshot.Detail.Facts[2].Value == "4 SPACES" and snapshot.Detail.Facts[3].Value == "0 / 4", "facts")
		h.model:SelectKey("Garage_missing")
		expect(h.model:Snapshot().SelectedKey == "Garage_shibuya", "unknown key ignored")
	end)

	case("enter: Begin, EnterSelectedGarage {PropertyId}, close, Complete with the generation", function()
		local h = harness({ replies = { GetState = stateReply(), EnterSelectedGarage = { Success = true } } })
		h.model:Open()
		h.model:Enter()
		local call = h.last("EnterSelectedGarage")
		expect(call and keys(call.payload) == "PropertyId" and call.payload.PropertyId == "kanda", "payload")
		expect(h.count("EnterSelectedGarage") == 1, "sent once")
		expect(#h.loads == 2, "two loading calls")
		expect(h.loads[1].action == "Begin" and h.loads[1].payload.Destination == "OwnedGarageInterior" and h.loads[1].payload.Status == "ENTERING OWNED GARAGE", "Begin")
		expect(h.loads[2].action == "Complete" and h.loads[2].payload.Generation == 1 and h.loads[2].payload.Status == "READY", "Complete")
		expect(h.model:IsOpen() == false and h.model:IsBusy() == false, "closed, not busy")
	end)

	case("enter while inside: ExitOnFoot {} with the returning texts", function()
		local h = harness({ replies = { GetState = stateReply({ InGarage = true }), ExitOnFoot = { Success = true } } })
		h.model:Open()
		expect(h.model:Snapshot().Enter.Text == "RETURN TO CITY", "button text")
		h.model:Enter()
		local call = h.last("ExitOnFoot")
		expect(call and keys(call.payload) == "", "ExitOnFoot {}")
		expect(h.count("EnterSelectedGarage") == 0, "no enter call")
		expect(h.loads[1].payload.Destination == "OwnedGarageExterior" and h.loads[1].payload.Status == "RETURNING TO CITY", "Begin")
	end)

	case("enter failure: Fail with the reason, message shown, still open, never retried", function()
		local h = harness({ replies = { GetState = stateReply(), EnterSelectedGarage = { Success = false, Message = "Garage is busy." } } })
		h.model:Open()
		h.model:Enter()
		expect(h.count("EnterSelectedGarage") == 1, "one attempt")
		expect(h.loads[2].action == "Fail" and h.loads[2].payload.Status == "RETURNING" and h.loads[2].payload.Reason == "Garage is busy.", "Fail")
		expect(keys(h.loads[2].payload) == "Generation,Reason,Status", "Fail keys")
		expect(h.model:Snapshot().Status.Text == "Garage is busy." and h.model:IsOpen(), "message and open")
	end)

	case("enter: one request in flight (busy), and nothing without a selection", function()
		local h
		h = harness({ replies = {
			GetState = stateReply(),
			EnterSelectedGarage = function()
				h.model:Enter()
				h.model:ChooseReplacement(1)
				h.model:SetMode("Visit")
				return { Success = true }
			end,
		} })
		h.model:Open()
		h.model:Enter()
		expect(h.count("EnterSelectedGarage") == 1, "re-entrant press ignored")
		local empty = harness({ replies = { GetState = { Success = true, Properties = {} } } })
		empty.model:Open()
		empty.model:Enter()
		expect(#empty.loads == 0 and empty.count("EnterSelectedGarage") == 0, "no selection, nothing sent")
	end)

	case("garage full: the choice is offered; a slot sends {PropertyId, ReplacementSlotId}; cancel sends nothing", function()
		local slots = { { SlotId = "Bay1", DisplayName = "Kestrel" }, { SlotId = "Bay2", VehicleId = "veh-2" } }
		local h = harness({ replies = {
			GetState = stateReply(),
			EnterSelectedGarage = function(payload)
				if payload.ReplacementSlotId then
					return { Success = true }
				end
				return { Success = false, NeedsReplacement = true, Message = "Garage full.", Slots = slots }
			end,
		} })
		h.model:Open()
		h.model:Enter()
		expect(h.loads[2].action == "Fail" and h.loads[2].payload.Status == "SELECT A DISPLAY SPACE", "Fail status")
		local replacement = h.model:Snapshot().Replacement
		expect(replacement and #replacement.Slots == 2, "two slots offered")
		h.model:CancelReplacement()
		expect(h.model:Snapshot().Replacement == nil and h.count("EnterSelectedGarage") == 1, "cancel is local")
		h.model:Enter()
		h.model:ChooseReplacement(2)
		local call = h.last("EnterSelectedGarage")
		expect(keys(call.payload) == "PropertyId,ReplacementSlotId", "payload keys")
		expect(call.payload.PropertyId == "kanda" and call.payload.ReplacementSlotId == "Bay2", "payload values")
		expect(h.model:IsOpen() == false and h.model:Snapshot().Replacement == nil, "closed")
		expect(h.loads[#h.loads].action == "Complete", "Complete")
		h.model:ChooseReplacement(1)
		expect(h.count("EnterSelectedGarage") == 3, "no choice, no call")
	end)

	case("tabs: hidden unless visits are enabled or a visit is active; Visit falls back to Mine", function()
		local h = harness({ replies = { GetState = stateReply() } })
		h.model:Open()
		expect(h.model:Snapshot().TabsVisible == false, "hidden")
		h.model:SetMode("Visit")
		expect(h.model:Snapshot().Mode == "Mine", "falls back at render")
		local v = harness({ replies = { GetState = stateReply({ VisitsEnabled = true }), GetVisitableGarages = { Success = true, Garages = {} } } })
		v.model:Open()
		expect(v.model:Snapshot().TabsVisible == true, "shown")
		v.model:SetMode("Bogus")
		expect(v.model:Snapshot().Mode == "Mine", "unknown mode ignored")
	end)

	case("visit: GetVisitableGarages {}, rows, VisitGarage {OwnerUserId}", function()
		local garages = {
			{ OwnerUserId = 11, OwnerName = "Aya", GarageName = "Aya's Loft", AccessMode = "Public", VisitorCount = 1, MaxVisitors = 6, CanVisit = true },
			{ OwnerUserId = 12, OwnerName = "Ben", GarageName = "Ben's Bay", AccessMode = "FriendsOnly", VisitorCount = 6, MaxVisitors = 6, CanVisit = false, Message = "FULL" },
		}
		local h = harness({ replies = {
			GetState = stateReply({ VisitsEnabled = true }),
			GetVisitableGarages = { Success = true, Garages = garages },
			VisitGarage = { Success = true },
		} })
		h.model:Open()
		h.model:SetMode("Visit")
		expect(keys(h.last("GetVisitableGarages").payload) == "", "GetVisitableGarages {}")
		local snapshot = h.model:Snapshot()
		expect(snapshot.Mode == "Visit" and #snapshot.Rows == 2 and snapshot.Rows[1].Key == "Visit_11", "rows")
		expect(snapshot.Rows[2].Muted == true and snapshot.Rows[1].Muted == false, "muted when it cannot be visited")
		expect(snapshot.Detail.Title == "AYA'S LOFT" and snapshot.Detail.District == "HOSTED BY AYA", "detail")
		expect(snapshot.Detail.Description == "Open to everyone in this server.", "access text")
		expect(snapshot.Enter.Text == "VISIT" and snapshot.Enter.Enabled == true, "VISIT")
		h.model:SelectKey("Visit_12")
		expect(h.model:Snapshot().Enter.Enabled == false and h.model:Snapshot().Enter.Text == "FULL", "cannot visit")
		h.model:Enter()
		expect(h.count("VisitGarage") == 0, "a garage that cannot be visited sends nothing")
		h.model:SelectKey("Visit_11")
		h.model:Enter()
		local call = h.last("VisitGarage")
		expect(call and keys(call.payload) == "OwnerUserId" and call.payload.OwnerUserId == 11, "VisitGarage payload")
		expect(h.loads[1].payload.Destination == "OwnedGarageInterior" and h.loads[1].payload.Status == "VISITING GARAGE", "Begin")
		expect(h.model:IsOpen() == false, "closed on success")
	end)

	case("visit: seated players cannot visit; leaving sends LeaveVisit {}", function()
		local garages = { { OwnerUserId = 11, OwnerName = "Aya", GarageName = "Aya's Loft", CanVisit = true } }
		local h = harness({ replies = { GetState = stateReply({ VisitsEnabled = true }), GetVisitableGarages = { Success = true, Garages = garages } } })
		h.player.Character = {
			FindFirstChildOfClass = function()
				return { SeatPart = {} }
			end,
		}
		h.model:Open()
		h.model:SetMode("Visit")
		expect(h.model:Snapshot().Enter.Text == "EXIT YOUR CAR TO VISIT" and h.model:Snapshot().Enter.Enabled == false, "seated")
		h.model:Enter()
		expect(h.count("VisitGarage") == 0, "nothing sent")

		local v = harness({ replies = { GetState = stateReply({ Visiting = { OwnerUserId = 11 } }), LeaveVisit = { Success = true } } })
		v.model:Open()
		expect(v.model:Snapshot().TabsVisible == true and v.model:Snapshot().Enter.Text == "LEAVE GARAGE", "leave offered")
		v.model:Enter()
		expect(keys(v.last("LeaveVisit").payload) == "", "LeaveVisit {}")
		expect(v.loads[1].payload.Destination == "OwnedGarageExterior" and v.loads[1].payload.Status == "RETURNING TO CITY", "Begin")
		expect(v.count("EnterSelectedGarage") == 0, "no enter call while visiting")
	end)

	case("prompts: an entry prompt opens that property; inside, exit prompts begin the loading screen once", function()
		local function prompt(name, attributes)
			return {
				Name = name,
				GetAttribute = function(_, key)
					return attributes and attributes[key]
				end,
			}
		end
		local h = harness({ replies = { GetState = stateReply() } })
		h.model:OnPromptTriggered(prompt("Enter", { OwnedGarageEntryPrompt = true, OwnedGaragePropertyId = "shibuya" }), h.player)
		expect(h.model:IsOpen() and h.model:Snapshot().SelectedKey == "Garage_shibuya", "opened on the property")
		h.model:OnPromptTriggered(prompt("Enter", { OwnedGarageEntryPrompt = true }), {})
		expect(h.count("GetState") == 1, "another player's trigger ignored")
		h.model:OnPromptTriggered(prompt("Other", {}), h.player)
		expect(h.count("GetState") == 1, "unrelated prompt ignored")

		local inside = harness({ attributes = { OwnedGarageInside = true } })
		inside.model:OnPromptTriggered(prompt("FootExitPrompt"), inside.player)
		inside.model:OnPromptTriggered(prompt("DriveOutPrompt"), inside.player)
		expect(#inside.loads == 1 and inside.loads[1].payload.Destination == "OwnedGarageExterior" and inside.loads[1].payload.Status == "RETURNING TO CITY", "one Begin")
		expect(#inside.calls == 0, "no remote call: the server owns the exit")
		inside.attributes.OwnedGarageInside = false
		inside.model:OnInsideChanged()
		expect(inside.loads[2].action == "Complete" and inside.loads[2].payload.Generation == 1 and inside.loads[2].payload.Reason == "Ready", "Complete")
		inside.model:OnInsideChanged()
		expect(#inside.loads == 2, "finished once")

		local visitor = harness({ attributes = { OwnedGarageInside = true, OwnedGarageVisitor = true } })
		visitor.model:OnPromptTriggered(prompt("DriveOutPrompt"), visitor.player)
		expect(#visitor.loads == 0, "a visitor cannot drive out")
		local owner = harness({ attributes = { OwnedGarageInside = true } })
		owner.model:OnPromptTriggered(prompt("DriveOutPrompt"), owner.player)
		expect(owner.loads[1].payload.Destination == "OwnedGarageDriveOut" and owner.loads[1].payload.Status == "PREPARING VEHICLE", "drive out")
		owner.model:OnPush({ Type = "DriveOutResult", Success = false, Message = "Blocked." })
		expect(owner.loads[2].action == "Fail" and owner.loads[2].payload.Status == "RETURNING" and owner.loads[2].payload.Reason == "Blocked.", "Fail")
	end)

	case("push: the stream request is acknowledged once with {Type, Token, Success, Message}", function()
		local h = harness()
		h.model:OnPush({ Type = "OwnedGarageStreamRequest", Token = "t-1", Position = "not a vector", TimeoutSeconds = 5 })
		expect(#h.pushes == 1, "one acknowledgement")
		local payload = h.pushes[1]
		expect(payload.Type == "OwnedGarageStreamReady" and payload.Token == "t-1" and payload.Success == false, "failed acknowledgement")
		expect(type(payload.Message) == "string" and payload.Message ~= "", "problem text")
		h.model:OnPush("junk")
		h.model:OnPush({ Type = "Unknown" })
		expect(#h.pushes == 1, "nothing else is sent")
	end)

	case("push: VisitEnded toasts the Classic text for 2.2 s and clears the visit; DriveOut closes", function()
		local h = harness({ replies = { GetState = stateReply({ Visiting = { OwnerUserId = 11 } }) } })
		h.model:Open()
		h.model:OnPush({ Type = "VisitEnded", Reason = "OwnerLeft" })
		local found = nil
		for _, fire in ipairs(h.fires) do
			if fire.name == "ShowTopNotification" then
				found = fire
			end
		end
		expect(found and found.args[1] == "The owner left the garage. Your visit ended." and found.args[2] == 2.2, "toast")
		expect(h.model:Snapshot().Enter.Text == "ENTER GARAGE" and h.model:Snapshot().TabsVisible == false, "visit cleared and rendered")
		h.model:OnPush({ Type = "DriveOut" })
		expect(h.model:IsOpen() == false, "closed")
	end)

	case("toggle: opens, then closes; one fetch per open; Changed carries its reasons", function()
		local h = harness({ replies = { GetState = stateReply() } })
		h.model:Toggle()
		h.model:Toggle()
		expect(h.model:IsOpen() == false, "toggle closes")
		expect(h.count("GetState") == 1, "one fetch per open")
		local reasons = table.concat(h.reasons, ",")
		expect(string.find(reasons, "render", 1, true) ~= nil and string.find(reasons, "close", 1, true) ~= nil, "Changed carries reasons")
	end)

	return results
end
