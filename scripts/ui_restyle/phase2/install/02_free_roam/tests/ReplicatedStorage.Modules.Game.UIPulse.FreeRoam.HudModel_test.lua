-- Pure tests for FreeRoam.HudModel: every rule and every remote call site, over fake deps. No instance, no yield.
-- Classic line references: D = DesktopFreeRoamHudUI, M = MobileFreeRoamHudUI.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	-- Fakes ------------------------------------------------------------------------------------------------------
	local function node(name, className, attributes, children)
		local item = { Name = name, ClassName = className, Attributes = attributes or {}, Children = children or {} }
		for _, child in ipairs(item.Children) do child.Parent = item end
		function item:IsA(class) return class == self.ClassName end
		function item:GetAttribute(key) return self.Attributes[key] end
		function item:SetAttribute(key, value)
			self.Attributes[key] = value
			if self.Writes then table.insert(self.Writes, { key, value }) end
		end
		function item:GetChildren() return self.Children end
		function item:GetDescendants()
			local out = {}
			local function walk(parent)
				for _, child in ipairs(parent.Children) do
					table.insert(out, child)
					walk(child)
				end
			end
			walk(self)
			return out
		end
		function item:FindFirstChild(wanted)
			for _, child in ipairs(self.Children) do
				if child.Name == wanted then return child end
			end
			return nil
		end
		function item:FindFirstChildOfClass(class)
			for _, child in ipairs(self.Children) do
				if child.ClassName == class then return child end
			end
			return nil
		end
		return item
	end

	local function categories()
		return node("Categories", "Folder", {}, {
			node("EXOTIC", "Folder", { DisplayName = "exotic" }, {
				node("Cockpit_Seraph", "Model", { CockpitId = "cockpit_seraph", DisplayName = "seraph_gt", MenuImage = "123", Price = 900 }),
				node("Endura", "Model", { TemplateId = "Endura", CockpitImage = "rbxassetid://9", Price = 300 }),
			}),
			node("PIERCER", "Folder", {}, {
				node("Kestrel", "Model", { Price = 500 }),
			}),
		})
	end

	local function profile()
		return {
			CurrentVehicleId = "v2",
			OwnedCockpitInstances = { inst1 = { TemplateId = "kestrel" } },
			Vehicles = {
				v1 = { CockpitId = "seraph" },
				v2 = { CockpitId = "Endura" },
				v3 = { CockpitInstanceId = "inst1", CategoryId = "bruiser" },
				v4 = { CockpitId = "unknown_thing", Category = "bruiser" },
			},
			VehicleSummaries = {
				v1 = { Overall = { PerformanceIndex = 939, Tier = "S" } },
				v2 = { Overall = { PerformanceIndex = 675.8, Tier = "B" } },
				v3 = { Overall = { PerformanceIndex = 512, Tier = "C" } },
			},
		}
	end

	local function harness(options)
		options = options or {}
		local h = { Calls = {}, Fires = {}, Toasts = {}, Loading = {}, Delays = {}, Confirms = {}, Gate = {}, Now = 100, Reasons = {} }
		h.Player = node("Player", "Player", options.Attributes or {})
		h.Player.UserId = 7
		h.Player.Writes = {}
		h.PlayerGui = node("PlayerGui", "PlayerGui", {})
		local function remote(name)
			local item = {}
			function item:InvokeServer(...)
				local arguments = table.pack(...)
				table.insert(h.Calls, { Remote = name, Action = arguments[1], Payload = arguments[2], Count = arguments.n })
				local reply = h.Replies and h.Replies[arguments[1]]
				if type(reply) == "function" then return reply(arguments[2]) end
				return reply
			end
			return item
		end
		local function event(name)
			local item = node(name, "BindableEvent")
			function item:Fire(...)
				table.insert(h.Fires, { Name = name, Count = select("#", ...) })
			end
			return item
		end
		h.Folder = node("UI", "Folder", {}, options.NoEvents and {} or {
			event("FreeRoamVehicleSpawned"), event("FreeRoamVehicleExited"), event("OpenRaceBrowser"), event("OpenOwnedGarageBrowser"),
		})
		h.Activity = remote("ActivityInvoke")
		h.FetchCount = 0
		h.Profile = profile()
		h.Replies = {}
		local garage = remote("GarageInvoke")
		h.Model = M.new({
			Player = h.Player,
			PlayerGui = h.PlayerGui,
			Remotes = { GarageInvoke = garage, TeleportInvoke = remote("FreeRoamHudTeleportInvoke") },
			FindActivityInvoke = function() return not options.NoActivity and h.Activity or nil end,
			Bindables = {
				Folder = h.Folder,
				ShowTopNotification = { Fire = function(_, text, seconds) table.insert(h.Toasts, { text, seconds }) end },
				LoadingTransitionInvoke = { Invoke = function(_, action, payload)
					table.insert(h.Loading, { Action = action, Payload = payload })
					return action == "Begin" and 41 or nil
				end },
			},
			Catalog = { Fetch = function(remoteArgument, payload)
				expect(remoteArgument == garage, "Fetch gets the garage remote (D353)")
				expect(type(payload) == "table" and next(payload) == nil, "Fetch payload is {} (D353)")
				h.FetchCount += 1
				return { Profile = h.Profile }
			end },
			CategoriesRoot = categories(),
			InputGate = {
				Acquire = function(owner, generation)
					table.insert(h.Gate, { "Acquire", owner, generation })
					return "token"
				end,
				Release = function(token, neutral) table.insert(h.Gate, { "Release", token, neutral }) end,
			},
			Confirm = function(confirmOptions) table.insert(h.Confirms, confirmOptions) end,
			OpenFullMap = function() return options.MapOpens == true end,
			Config = { ProfileRefreshSeconds = 2, PauseFreeRoamMapDuringRace = true, DefaultControlMode = "Arrows" },
			TouchEnabled = options.Touch == true,
			GyroscopeEnabled = options.Gyro == true,
			Clock = function() return h.Now end,
			Spawn = function(body, ...) body(...) end,
			Delay = function(seconds, body) table.insert(h.Delays, { seconds, body }) end,
		})
		h.Model.Changed:Connect(function(reason) table.insert(h.Reasons, reason) end)
		function h.LastToast() return h.Toasts[#h.Toasts] and h.Toasts[#h.Toasts][1] end
		function h.Wrote(key, value)
			for _, write in ipairs(h.Player.Writes) do
				if write[1] == key and write[2] == value then return true end
			end
			return false
		end
		function h.Seat()
			local seat = node("DriverSeat", "VehicleSeat")
			node("Vehicle", "Model", { OwnerUserId = 7 }, { seat })
			local humanoid = node("Humanoid", "Humanoid")
			humanoid.SeatPart = seat
			humanoid.Sit = true
			h.Player.Character = node("Character", "Model", {}, { humanoid })
			return humanoid
		end
		return h
	end

	local function keys(payload)
		local list = {}
		for key in pairs(payload or {}) do table.insert(list, key) end
		table.sort(list)
		return table.concat(list, ",")
	end

	-- Pure rules -------------------------------------------------------------------------------------------------
	case("readValue copies D121-124, including the false-gives-fallback rule", function()
		local folder = node("Folder", "Folder", {}, { node("A", "IntValue"), node("B", "BoolValue") })
		folder.Children[1].Value = 5
		folder.Children[2].Value = false
		expect(M._readValue(folder, "A", 1) == 5, "value")
		expect(M._readValue(folder, "B", true) == true, "false yields the fallback, as Classic")
		expect(M._readValue(folder, "Missing", 9) == 9, "missing")
		expect(M._readValue(nil, "A", 3) == 3, "nil folder")
	end)

	case("presentation owners: table and legacy string messages (D1339-1344)", function()
		local owners = {}
		M._applyPresentation(owners, { Owner = "RaceSession", Active = true, KeepTelemetry = true })
		local racing, telemetryOnly = M._presentation(owners)
		expect(racing and telemetryOnly, "telemetry only")
		M._applyPresentation(owners, { Owner = "RaceBrowser", Active = true, KeepTelemetry = false })
		racing, telemetryOnly = M._presentation(owners)
		expect(racing and not telemetryOnly, "a non-telemetry owner hides everything")
		M._applyPresentation(owners, { Owner = "RaceBrowser", Active = false })
		M._applyPresentation(owners, { Owner = "RaceSession", Active = false })
		expect(not M._presentation(owners), "released")
		M._applyPresentation(owners, "Racing")
		racing, telemetryOnly = M._presentation(owners)
		expect(racing and telemetryOnly, "legacy string")
		M._applyPresentation(owners, "FreeRoam")
		expect(not M._presentation(owners), "legacy release")
		M._applyPresentation(owners, { Active = true })
		expect(owners.Racing ~= nil and owners.Racing.KeepTelemetry == false, "owner defaults to Racing")
	end)

	case("rank view (D919-924)", function()
		local none = M._rankView(nil, nil, nil)
		expect(none.Visible == false and none.Rank == 1 and none.Fraction == 1 and none.Text == "MAX", "no rank")
		local some = M._rankView(6, 250, 1000)
		expect(some.Visible and some.Rank == 6 and some.Fraction == 0.25 and some.Text == "250 / 1000 XP", "rank 6")
		expect(M._rankView(2, 5000, 1000).Fraction == 1, "clamped")
	end)

	case("passenger labels map to the Classic payload values (D612)", function()
		expect(M._accessFromLabel("FRIENDS") == "Friends", "Friends")
		expect(M._accessFromLabel("ANYONE") == "Anyone", "Anyone")
		expect(M._accessFromLabel("NOBODY") == "Nobody", "Nobody")
		expect(M._accessFromLabel("EVERYONE") == nil, "unknown label")
	end)

	case("CURRENT follows the player's vehicle in the world, not the profile id alone", function()
		local mine = node("Vehicle", "Model", { OwnerUserId = 7, OwnedVehicleId = "v2" })
		local other = node("Vehicle", "Model", { OwnerUserId = 8, OwnedVehicleId = "v1" })
		local out, id = M._vehicleOut({ node("Loose", "Folder", { OwnerUserId = 7 }), other, mine }, 7)
		expect(out == true and id == "v2", "the player's own model")
		out, id = M._vehicleOut({ other }, 7)
		expect(out == false and id == "", "someone else's vehicle is not mine")
		expect(M._vehicleOut({ node("Vehicle", "Model", {}) }, nil) == false, "no user id matches nothing")
		expect(select(2, M._vehicleOut({ node("Vehicle", "Model", { OwnerUserId = "7" }) }, 7)) == "", "an unlabelled vehicle")

		local rows = { { VehicleId = "v1", Selected = true }, { VehicleId = "v2", Selected = false } }
		expect(M._markCurrent(rows, false, "") == true and not rows[1].Selected and not rows[2].Selected, "no vehicle out: no CURRENT (teleport, despawn)")
		expect(M._markCurrent(rows, false, "") == false, "nothing changed the second time")
		expect(M._markCurrent(rows, true, "v2") and rows[2].Selected and not rows[1].Selected, "the vehicle that is out")
		expect(M._markCurrent(rows, true, "") and rows[1].Selected and not rows[2].Selected, "unlabelled vehicle: the profile's id")
	end)

	case("the row that was CURRENT still spawns after its vehicle is gone", function()
		local h = harness()
		h.Model.ToggleCarPanel()
		local current
		for _, row in ipairs(h.Model.GetState().Rows) do
			if row.Selected then current = row.VehicleId end
		end
		h.Replies.SpawnOwnedVehicleFromFreeRoam = { Success = false }
		h.Model.SpawnVehicle(current or "v1")
		h.Model.SpawnVehicle(current or "v1")
		expect(#h.Calls == 2 and h.Calls[2].Action == "SpawnOwnedVehicleFromFreeRoam", "every press asks, as a Classic card does (D746)")
	end)

	case("rows from the profile (D663-690)", function()
		local root = categories()
		local rows = M._rowsFromProfile(profile(), M._cockpitIndex(root), root, M._categoryIndex(root))
		local byId = {}
		for _, row in ipairs(rows) do byId[row.VehicleId] = row end
		expect(#rows == 4, "four rows")
		local v1 = byId.v1
		expect(v1.Name == "SERAPH GT" and v1.Category == "EXOTIC" and v1.Image == "rbxassetid://123", "v1 name, category, image")
		expect(v1.Tier == "S" and v1.Rating == 939 and v1.Price == 900 and v1.Selected == false, "v1 numbers")
		local v2 = byId.v2
		expect(v2.Name == "ENDURA" and v2.Image == "rbxassetid://9" and v2.Selected == true and v2.Rating == 675.8, "v2")
		local v3 = byId.v3
		expect(v3.CockpitId == "kestrel" and v3.Category == "PIERCER" and v3.Name == "KESTREL", "v3 through the cockpit instance")
		local v4 = byId.v4
		expect(v4.Name == "UNKNOWN THING" and v4.Tier == "E" and v4.Rating == 0 and v4.Price == 0 and v4.Image == "", "v4 fallbacks")
		expect(v4.Category == "PIERCER", "bruiser is the legacy id of PIERCER")
		expect(#M._rowsFromProfile(nil, {}, nil, M._categoryIndex(nil)) == 0, "no profile")
	end)

	case("category name fallbacks (VehicleDisplayNames 45-58)", function()
		local root = categories()
		local index = M._categoryIndex(root)
		expect(M._categoryName(root, index, "", "seraph") == "Exotic", "by cockpit, DisplayName title-cased")
		expect(M._categoryName(root, index, "piercer", "") == "Piercer", "by category id")
		expect(M._categoryName(root, index, "street_class", "") == "Street Class", "unknown id is title-cased")
		expect(M._categoryName(root, index, nil, "") == "Other", "nothing known")
	end)

	case("filter, sort and category options (D759-774, D786-788)", function()
		local rows = {
			{ Name = "B", Category = "X", Rating = 5, Price = 30 },
			{ Name = "A", Category = "Y", Rating = 5, Price = 10 },
			{ Name = "C", Category = "X", Rating = 9, Price = 20 },
		}
		local function names(list)
			local out = {}
			for _, row in ipairs(list) do table.insert(out, row.Name) end
			return table.concat(out)
		end
		expect(names(M._sortRows(table.clone(rows), "RATING")) == "CAB", "rating high first, then name")
		expect(names(M._sortRows(table.clone(rows), "PRICE")) == "ACB", "price low first")
		expect(names(M._sortRows(table.clone(rows), "A-Z")) == "ABC", "name")
		expect(names(M._filterRows(rows, "X")) == "BC", "category filter")
		expect(#M._filterRows(rows, "ALL") == 3, "ALL")
		expect(table.concat(M._categoryOptions(rows), "|") == "ALL|X|Y", "ALL first, then sorted")
	end)

	-- Start ------------------------------------------------------------------------------------------------------
	case("start: touch writes the two attributes false (M168, M187); non-touch writes nothing", function()
		local touch = harness({ Touch = true })
		expect(touch.Wrote("MobileFreeRoamCarMenuOpen", false) and touch.Wrote("MobileMajorMenuOpen", false), "touch start writes")
		local desktop = harness()
		expect(#desktop.Player.Writes == 0, "no attribute written at start on a non-touch device")
		expect(#desktop.Calls == 0 and desktop.FetchCount == 0, "no remote call at start")
	end)

	-- Visibility rules -------------------------------------------------------------------------------------------
	case("what hides the HUD (D1113-1142)", function()
		local h = harness()
		local state = h.Model.GetState()
		expect(not state.Hidden and state.ShowMinimap and state.ShowActionBar and state.MapLive, "plain free roam")
		for _, name in ipairs({ "FullMapOpen", "GarageSessionActive" }) do
			h.Player.Attributes[name] = true
			h.Model.AttributeChanged(name)
			expect(state.Hidden, name .. " hides")
			h.Player.Attributes[name] = nil
			h.Model.AttributeChanged(name)
			expect(not state.Hidden, name .. " released")
		end
		h.PlayerGui.Attributes.OwnedGarageManagementOpen = true
		h.Model.AttributeChanged("OwnedGarageManagementOpen")
		expect(state.Hidden, "management hides")
		h.PlayerGui.Attributes.OwnedGarageManagementOpen = nil
		h.Player.Attributes.OwnedGarageInside = true
		h.Model.AttributeChanged("OwnedGarageInside")
		expect(not state.Hidden and not state.ShowMainActions and not state.ShowMinimap and not state.MapLive, "inside an owned garage")
		h.Player.Attributes.OwnedGarageInside = nil
		h.Model.PresentationMessage({ Owner = "RaceSession", Active = true, KeepTelemetry = true })
		expect(not state.Hidden and not state.ShowActionBar and not state.ShowStatus and not state.ShowMinimap, "telemetry only")
		expect(not state.MapLive, "the map pauses while racing (D1142)")
		h.Model.SetDriving(true)
		expect(state.ShowGauge and not state.ShowBottomButtons, "gauge stays, buttons go")
		h.Model.PresentationMessage({ Owner = "RaceResults", Active = true })
		expect(state.Hidden, "a non-telemetry owner hides the HUD")
		expect(not h.Model.IsMinimapShowing(), "minimap not showing")
	end)

	case("driving an owned vehicle makes its tier and rating known", function()
		local h = harness()
		local humanoid = h.Seat()
		local vehicle = humanoid.SeatPart.Parent
		vehicle.Attributes.PerformanceTier = "A"
		vehicle.Attributes.PerformanceIndex = 812
		h.Model.SetDriving(true)
		local state = h.Model.GetState()
		expect(state.Vehicle ~= nil and state.Vehicle.Tier == "A" and state.Vehicle.Rating == 812, "read from the seated vehicle")
		h.Model.SetDriving(false)
		expect(state.Vehicle ~= nil, "a parked vehicle stays known until it is despawned")
	end)

	case("driving shows the gauge and the bottom buttons; unchanged value fires nothing", function()
		local h = harness()
		h.Model.SetDriving(true)
		local count = #h.Reasons
		h.Model.SetDriving(true)
		expect(#h.Reasons == count, "no change, no signal")
		local state = h.Model.GetState()
		expect(state.ShowGauge and state.ShowBottomButtons, "driving")
	end)

	-- Car panel --------------------------------------------------------------------------------------------------
	case("car panel: open fetches once and builds sorted rows; close clears the cache (D863-875)", function()
		local h = harness()
		h.Model.ToggleCarPanel()
		local state = h.Model.GetState()
		expect(state.CarPanelOpen and h.FetchCount == 1 and #h.Calls == 0, "one catalogue fetch, no direct invoke")
		expect(#state.Rows == 4 and state.Rows[1].VehicleId == "v1", "rating order")
		expect(not state.ShowMinimap, "the minimap and rank hide while the panel is open")
		expect(table.concat(state.CategoryOptions, "|") == "ALL|EXOTIC|PIERCER", "options")
		h.Model.SelectCategory("PIERCER")
		expect(#state.Rows == 2 and h.FetchCount == 1, "filter inside the refresh interval uses the cache (D351)")
		h.Now += 5
		h.Model.SelectSort("A-Z")
		expect(h.FetchCount == 2 and state.Rows[1].Name == "KESTREL", "a stale cache is re-read, as renderCars does")
		h.Model.ToggleCarPanel()
		expect(not state.CarPanelOpen, "closed")
		h.Model.ToggleCarPanel()
		expect(h.FetchCount == 3, "a new open always reads (D869)")
		expect(#h.Player.Writes == 0, "no touch attribute on a non-touch device")
	end)

	case("car panel on touch writes MobileFreeRoamCarMenuOpen and closes when hidden (M284, M397)", function()
		local h = harness({ Touch = true })
		h.Model.SetCarPanelOpen(true)
		expect(h.Wrote("MobileFreeRoamCarMenuOpen", true), "open write")
		h.Player.Attributes.GarageSessionActive = true
		h.Model.AttributeChanged("GarageSessionActive")
		expect(not h.Model.GetState().CarPanelOpen and h.Player.Attributes.MobileFreeRoamCarMenuOpen == false, "closed by hide")
	end)

	-- Remote call sites ------------------------------------------------------------------------------------------
	case("spawn: remote, action, payload keys, events and toasts (D746-751)", function()
		local h = harness()
		h.Model.ToggleCarPanel()
		h.Replies.SpawnOwnedVehicleFromFreeRoam = { Success = true }
		h.Model.SpawnVehicle("v3")
		expect(#h.Calls == 1, "one call")
		local call = h.Calls[1]
		expect(call.Remote == "GarageInvoke" and call.Action == "SpawnOwnedVehicleFromFreeRoam" and call.Count == 2, "remote and action")
		expect(keys(call.Payload) == "CockpitId,VehicleId" and call.Payload.VehicleId == "v3" and call.Payload.CockpitId == "kestrel", "payload")
		expect(h.Toasts[1][1] == "SPAWNING VEHICLE..." and h.Toasts[1][2] == 2.2, "first toast and its duration")
		expect(h.LastToast() == "VEHICLE SPAWNED", "success toast")
		expect(h.Fires[1].Name == "FreeRoamVehicleSpawned" and h.Fires[1].Count == 0, "bindable fired with no argument")
		local state = h.Model.GetState()
		expect(not state.CarPanelOpen and state.Vehicle.Tier == "C" and not state.Busy, "panel closed, vehicle known, not busy")
		h.Model.SpawnVehicle("v3")
		expect(#h.Calls == 1, "rows were cleared with the panel: an unknown id sends nothing")
	end)

	case("spawn failure: toast from the reply, panel stays, never retried", function()
		local h = harness()
		h.Model.ToggleCarPanel()
		h.Replies.SpawnOwnedVehicleFromFreeRoam = { Success = false, Error = "NO SPACE" }
		h.Model.SpawnVehicle("v1")
		expect(h.LastToast() == "NO SPACE" and h.Model.GetState().CarPanelOpen and #h.Calls == 1, "one failed call")
		expect(#h.Fires == 0, "no spawned event")
		h.Replies.SpawnOwnedVehicleFromFreeRoam = "not a table"
		h.Model.SpawnVehicle("v1")
		expect(h.LastToast() == "not a table", "an untrusted reply shape becomes the failure text (D346)")
	end)

	case("busy guard: a second action during a pending call sends nothing (D747, D826, D997)", function()
		local h = harness()
		h.Model.ToggleCarPanel()
		h.Seat()
		local inner = 0
		h.Replies.SpawnOwnedVehicleFromFreeRoam = function()
			h.Model.SpawnVehicle("v2")
			h.Model.Despawn()
			h.Model.ExitVehicle()
			inner = #h.Calls
			return { Success = false }
		end
		h.Model.SpawnVehicle("v1")
		expect(inner == 1 and #h.Calls == 1, "nothing else was sent while busy")
		expect(not h.Model.GetState().Busy, "released after the reply")
	end)

	case("despawn: event first, remote, stand up, toast (D825-836)", function()
		local h = harness()
		local humanoid = h.Seat()
		h.Replies.DespawnVehicle = {}
		h.Model.Despawn()
		local call = h.Calls[1]
		expect(call.Remote == "GarageInvoke" and call.Action == "DespawnVehicle" and keys(call.Payload) == "" and call.Count == 2, "call")
		expect(h.Fires[1].Name == "FreeRoamVehicleExited", "exited event")
		expect(humanoid.Sit == false and h.LastToast() == "VEHICLE DESPAWNED", "stood up and toasted (only Success == false fails, D834)")
		local silent = harness()
		silent.Model.Despawn()
		expect(silent.LastToast() == "nil", "a non-table reply is the Classic failure table (D346): its text is the toast")
		local failing = harness()
		failing.Replies.DespawnVehicle = { Success = false }
		failing.Model.Despawn()
		expect(failing.LastToast() == "DESPAWN FAILED", "failure text")
	end)

	case("exit: needs the owned seat; event, remote, stand up, toast (D996-1008)", function()
		local h = harness()
		h.Model.ExitVehicle()
		expect(#h.Calls == 0 and #h.Fires == 0, "no seat, nothing sent")
		local humanoid = h.Seat()
		h.Model.ExitVehicle()
		local call = h.Calls[1]
		expect(call.Remote == "GarageInvoke" and call.Action == "ExitVehicle" and keys(call.Payload) == "" and call.Count == 2, "call")
		expect(h.Fires[1].Name == "FreeRoamVehicleExited" and humanoid.Sit == false and h.LastToast() == "VEHICLE PARKED", "sequence")
	end)

	case("teleport: only behind the confirmation; loading Begin then Complete (D508-534)", function()
		local h = harness()
		h.Model.RequestTeleport()
		expect(#h.Calls == 0 and #h.Confirms == 1, "nothing is sent before YES")
		local confirm = h.Confirms[1]
		expect(confirm.Title == "TELEPORT TO DEALERSHIP?" and confirm.Body == "Your current vehicle will be despawned.", "copy")
		expect(confirm.ConfirmText == "YES" and confirm.CancelText == "NO", "buttons")
		h.Replies.TeleportToDealership = { Success = true }
		confirm.OnConfirm()
		local call = h.Calls[1]
		expect(call.Remote == "FreeRoamHudTeleportInvoke" and call.Action == "TeleportToDealership" and call.Count == 1, "one argument only (D519)")
		expect(h.Loading[1].Action == "Begin" and keys(h.Loading[1].Payload) == "Destination,Status", "Begin keys")
		expect(h.Loading[1].Payload.Destination == "DealershipExterior" and h.Loading[1].Payload.Status == "TRAVELLING TO DEALERSHIP", "Begin values")
		expect(h.Loading[2].Action == "Complete" and h.Loading[2].Payload.Generation == 41 and h.Loading[2].Payload.Status == "READY", "Complete")
		expect(h.Fires[1].Name == "FreeRoamVehicleExited" and h.LastToast() == "TELEPORTED TO DEALERSHIP", "event and toast")
	end)

	case("teleport failure: loading Fail with the reason (D527-529)", function()
		local h = harness()
		h.Model.RequestTeleport()
		h.Replies.TeleportToDealership = { Success = false, Message = "TOO SOON" }
		h.Confirms[1].OnConfirm()
		local fail = h.Loading[2]
		expect(fail.Action == "Fail" and keys(fail.Payload) == "Generation,Reason,Status", "Fail keys")
		expect(fail.Payload.Status == "RETURNING" and fail.Payload.Reason == "TOO SOON" and h.LastToast() == "TOO SOON", "values")
		expect(#h.Fires == 0, "no exited event on failure")
		local broken = harness()
		broken.Model.RequestTeleport()
		broken.Confirms[1].OnConfirm()
		expect(broken.LastToast() == "DEALERSHIP TELEPORT FAILED", "a nil reply uses the Classic text")
	end)

	case("buy more: straight to the confirmation; on touch the panel closes first (D777, M301)", function()
		local h = harness({ Touch = true })
		h.Model.SetCarPanelOpen(true)
		h.Model.BuyMore()
		expect(not h.Model.GetState().CarPanelOpen and #h.Confirms == 1 and #h.Calls == 0, "closed, confirmation shown")
	end)

	case("passenger access: remote, action, key, failure toast (D607-616)", function()
		local h = harness()
		h.Replies.SetPassengerAccess = { Ok = true }
		h.Model.SetPassengerAccess("ANYONE")
		local call = h.Calls[1]
		expect(call.Remote == "ActivityInvoke" and call.Action == "SetPassengerAccess" and keys(call.Payload) == "Access", "call")
		expect(call.Payload.Access == "Anyone" and #h.Toasts == 0, "value, no toast on Ok")
		h.Replies.SetPassengerAccess = { Ok = false }
		h.Model.SetPassengerAccess("NOBODY")
		expect(h.LastToast() == "PASSENGER SETTING NOT SAVED", "failure toast")
		h.Model.SetPassengerAccess("EVERYONE")
		expect(#h.Calls == 2, "an unknown label sends nothing")
		expect(h.Model.GetPassengerAccess() == "FRIENDS", "default label")
		h.Player.Attributes.PassengerAccess = "Nobody"
		expect(h.Model.GetPassengerAccess() == "NOBODY", "label follows the attribute")
		local missing = harness({ NoActivity = true })
		missing.Model.SetPassengerAccess("ANYONE")
		expect(#missing.Calls == 0 and #missing.Toasts == 0, "no remote, nothing happens (D610)")
	end)

	case("action bar bindables and their NOT READY toasts (D878-884)", function()
		local h = harness()
		h.Model.OpenGarages()
		h.Model.OpenRaces()
		expect(h.Fires[1].Name == "OpenOwnedGarageBrowser" and h.Fires[2].Name == "OpenRaceBrowser" and #h.Toasts == 0, "fired")
		local missing = harness({ NoEvents = true })
		missing.Model.OpenGarages()
		expect(missing.LastToast() == "MY GARAGES NOT READY", "garages")
		missing.Model.OpenRaces()
		expect(missing.LastToast() == "RACE BROWSER NOT READY", "races")
	end)

	case("full map, arrived and cash pack toasts (D962, D964, D577)", function()
		local h = harness()
		h.Model.OpenFullMap()
		expect(h.LastToast() == "MAP NOT AVAILABLE", "map refused")
		local opening = harness({ MapOpens = true })
		opening.Model.OpenFullMap()
		expect(#opening.Toasts == 0, "map opened")
		h.Model.Arrived({ Label = "GARAGE" })
		expect(h.LastToast() == "ARRIVED: GARAGE", "arrived")
		h.Model.CashPackPressed()
		expect(h.LastToast() == "CASH PRODUCTS ARE NOT ENABLED YET" and #h.Calls == 0, "no purchase remote")
	end)

	-- Modals -----------------------------------------------------------------------------------------------------
	case("modal open and close write DrivingControlsOpen (D434, D470)", function()
		local h = harness()
		h.Model.OpenModal("Settings")
		expect(h.Model.GetState().ActiveModal == "Settings" and h.Wrote("DrivingControlsOpen", false), "settings")
		h.Model.OpenModal("Controls")
		expect(h.Wrote("DrivingControlsOpen", true), "controls")
		h.Model.CloseModal()
		expect(h.Model.GetState().ActiveModal == nil and h.Player.Attributes.DrivingControlsOpen == false, "closed")
		h.Model.OpenModal("Nope")
		expect(h.Model.GetState().ActiveModal == nil, "unknown modal ignored")
		expect(not h.Wrote("MobileMajorMenuOpen", true), "no touch attribute on a non-touch device")
	end)

	case("touch modals write MobileMajorMenuOpen (M188, M190)", function()
		local h = harness({ Touch = true })
		h.Model.OpenModal("Cash")
		expect(h.Player.Attributes.MobileMajorMenuOpen == true, "open")
		h.Model.CloseModal()
		expect(h.Player.Attributes.MobileMajorMenuOpen == false, "closed")
	end)

	case("first-drive reveal: attribute, input gate, refused close, timed finish (D442-462, D987-994)", function()
		local h = harness()
		h.Model.OpenControlsFromOnboarding({ FirstDrive = true })
		local state = h.Model.GetState()
		expect(state.ActiveModal == "Controls" and state.ControlsReveal, "reveal")
		expect(h.Wrote("FirstDrivePresentationPending", true) and h.Wrote("DrivingControlsOpen", true), "attributes")
		expect(h.Gate[1][1] == "Acquire" and h.Gate[1][2] == "FirstDriveControls" and h.Gate[1][3] == "V1", "gate acquired")
		h.Model.CloseModal()
		expect(state.ActiveModal == "Controls", "close is refused during the reveal (D442)")
		h.Model.PresentationMessage({ Owner = "RaceBrowser", Active = true })
		expect(state.ActiveModal == "Controls", "a presentation owner does not close it either")
		h.Model.PresentationMessage({ Owner = "RaceBrowser", Active = false })
		h.Model.CompleteControls()
		expect(state.ControlsFading and #h.Delays == 1 and h.Delays[1][1] == 0.55, "fade started")
		h.Model.CompleteControls()
		expect(#h.Delays == 1, "NEXT is inactive during the fade")
		expect(h.Player.Attributes.FirstDrivePresentationPending == true, "still pending during the fade")
		h.Delays[1][2]()
		expect(state.ActiveModal == nil and not state.ControlsReveal and not state.ControlsFading, "finished")
		expect(h.Player.Attributes.FirstDrivePresentationPending == false and h.Player.Attributes.DrivingControlsOpen == false, "attributes cleared")
		expect(h.Gate[2][1] == "Release" and h.Gate[2][2] == "token" and h.Gate[2][3] == true, "gate released, neutral required")
	end)

	case("a reopened controls modal cancels a running fade (D458, D466)", function()
		local h = harness()
		h.Model.OpenControlsFromOnboarding({ FirstDrive = true })
		h.Model.CompleteControls()
		h.Model.OpenControlsFromOnboarding({ FirstDrive = true })
		h.Delays[1][2]()
		expect(h.Model.GetState().ActiveModal == "Controls" and not h.Model.GetState().ControlsFading, "the stale fade did nothing")
		expect(#h.Gate == 1, "the token is acquired once")
	end)

	case("plain controls: Done closes at once; onboarding without FirstDrive holds no gate", function()
		local h = harness()
		h.Model.OpenControlsFromOnboarding(nil)
		expect(#h.Gate == 0 and not h.Wrote("FirstDrivePresentationPending", true), "no gate, no pending")
		h.Model.CompleteControls()
		expect(h.Model.GetState().ActiveModal == nil and #h.Delays == 0, "closed without a fade")
	end)

	case("FullMapOpen closes Settings but never the controls modal (D1351-1353)", function()
		local h = harness()
		h.Model.OpenModal("Settings")
		h.Player.Attributes.FullMapOpen = true
		h.Model.AttributeChanged("FullMapOpen")
		expect(h.Model.GetState().ActiveModal == nil, "settings closed")
		h.Player.Attributes.FullMapOpen = nil
		h.Model.OpenModal("Controls")
		h.Player.Attributes.FullMapOpen = true
		h.Model.AttributeChanged("FullMapOpen")
		expect(h.Model.GetState().ActiveModal == "Controls", "controls kept")
	end)

	case("a presentation owner closes the car panel and the modal (D1345)", function()
		local h = harness()
		h.Model.ToggleCarPanel()
		h.Model.OpenModal("Settings")
		h.Model.PresentationMessage({ Owner = "RaceEntry", Active = true })
		local state = h.Model.GetState()
		expect(not state.CarPanelOpen and state.ActiveModal == nil, "both closed")
	end)

	-- Settings ---------------------------------------------------------------------------------------------------
	case("minimap mode and control mode writes (D634, M201)", function()
		local h = harness({ Touch = true })
		expect(h.Model.GetMinimapMode() == "ROTATE" and h.Model.GetControlMode() == "Arrows", "defaults")
		h.Model.SetMinimapMode("NORTH UP")
		expect(h.Player.Attributes.MinimapMode == "NORTH UP" and h.Model.GetMinimapMode() == "NORTH UP", "minimap mode")
		h.Model.SetMinimapMode("SIDEWAYS")
		expect(h.Player.Attributes.MinimapMode == "NORTH UP", "unknown option ignored")
		h.Model.SetControlMode("Thumbstick")
		expect(h.Player.Attributes.MobileControlMode == "Thumbstick", "control mode")
		h.Model.SetControlMode("Tilt")
		expect(h.Player.Attributes.MobileControlMode == "Thumbstick" and h.Model.IsControlModeLocked("Tilt"), "Tilt needs a gyroscope")
		local gyro = harness({ Touch = true, Gyro = true })
		gyro.Model.SetControlMode("Tilt")
		expect(gyro.Player.Attributes.MobileControlMode == "Tilt", "Tilt with a gyroscope")
		local desktop = harness()
		desktop.Model.SetControlMode("Thumbstick")
		expect(desktop.Player.Attributes.MobileControlMode == nil, "never written on a non-touch device")
	end)

	return results
end
