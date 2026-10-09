-- Pure tests for Garage.GarageModel: the action table against the Classic call sites, payload keys and value
-- sources, the transition table (entry, tabs, Shop / Owned, the empty-slot detour, Back, Drive gating, preview
-- clearing, preview rebuild rule), and the display inputs for tier and price. No remote, no instance, no yield:
-- every dependency is a fake passed through deps.
--
-- The block below is written by ../gen_actions.py from the Classic source (the same data as ../actions.json).
-- BEGIN GENERATED ACTIONS (gen_actions.py; do not edit)
local EXPECTED_ACTIONS = {
	{ Id = "L35.GetInitial", Remote = "Remotes.Garage.GarageInvoke", Action = "GetInitial", Keys = {  }, Line = 35 },
	{ Id = "L115.SetVehicleCosmeticColor", Remote = "Remotes.Garage.GarageInvoke", Action = "SetVehicleCosmeticColor", Keys = { "CosmeticId", "Color", "ReturnProfile" }, Line = 115 },
	{ Id = "L116.SetVehicleCosmeticColor", Remote = "Remotes.Garage.GarageInvoke", Action = "SetVehicleCosmeticColor", Keys = { "CosmeticId", "Color", "ReturnProfile" }, Line = 116 },
	{ Id = "L117.SetCockpitColor", Remote = "Remotes.Garage.GarageInvoke", Action = "SetCockpitColor", Keys = { "Channel", "Color", "Scope", "ReturnProfile" }, Line = 117 },
	{ Id = "L119.SetAllNeonColor", Remote = "Remotes.Garage.GarageInvoke", Action = "SetAllNeonColor", Keys = { "Color", "ReturnProfile" }, Line = 119 },
	{ Id = "L120.SetCockpitColor", Remote = "Remotes.Garage.GarageInvoke", Action = "SetCockpitColor", Keys = { "Channel", "Color", "Scope", "ReturnProfile" }, Line = 120 },
	{ Id = "L121.SetCockpitColor", Remote = "Remotes.Garage.GarageInvoke", Action = "SetCockpitColor", Keys = { "Channel", "Color", "Scope", "ReturnProfile" }, Line = 121 },
	{ Id = "L122.SetModuleColor", Remote = "Remotes.Garage.GarageInvoke", Action = "SetModuleColor", Keys = { "SlotId", "Channel", "Color", "ReturnProfile" }, Line = 122 },
	{ Id = "L174.BuyGarageProperty", Remote = "Remotes.Garage.GarageInvoke", Action = "BuyGarageProperty", Keys = { "PropertyId" }, Line = 174 },
	{ Id = "L183.End", Remote = "Remotes.UI.GarageSessionRequest", Action = "End", Keys = { "ReturnToEntry" }, Line = 183 },
	{ Id = "L185.SpawnVehicle", Remote = "Remotes.Garage.GarageInvoke", Action = "SpawnVehicle", Keys = {  }, Line = 185 },
	{ Id = "L194.SelectVehicleInstance", Remote = "Remotes.Garage.GarageInvoke", Action = "SelectVehicleInstance", Keys = { "VehicleId", "CockpitId" }, Line = 194 },
	{ Id = "L194.BuyCockpitInstance.1", Remote = "Remotes.Garage.GarageInvoke", Action = "BuyCockpitInstance", Keys = { "CockpitId", "CategoryId" }, Line = 194 },
	{ Id = "L195.End", Remote = "Remotes.UI.GarageSessionRequest", Action = "End", Keys = { "ReturnToEntry" }, Line = 195 },
	{ Id = "L288.EquipModuleInstance", Remote = "Remotes.Garage.GarageInvoke", Action = "EquipModuleInstance", Keys = { "ModuleInstanceId", "VehicleId", "SlotId", "AllowReassign" }, Line = 288 },
	{ Id = "L358.BuyModuleInstance", Remote = "Remotes.Garage.GarageInvoke", Action = "BuyModuleInstance", Keys = { "ModuleId", "VehicleId", "SlotId" }, Line = 358 },
	{ Id = "L437.UpgradeModule", Remote = "Remotes.Garage.GarageInvoke", Action = "UpgradeModule", Keys = { "SlotId", "ModuleId", "UpgradeId" }, Line = 437 },
	{ Id = "L558.BuyVehicleCosmetic", Remote = "Remotes.Garage.GarageInvoke", Action = "BuyVehicleCosmetic", Keys = { "CosmeticId" }, Line = 558 },
	{ Id = "L604.BuyNeon", Remote = "Remotes.Garage.GarageInvoke", Action = "BuyNeon", Keys = { "SlotId" }, Line = 604 },
	{ Id = "L678.EnsureCustomisationAccess", Remote = "Remotes.Garage.GarageInvoke", Action = "EnsureCustomisationAccess", Keys = {  }, Line = 678 },
	{ Id = "L684.End", Remote = "Remotes.UI.GarageSessionRequest", Action = "End", Keys = { "ReturnToEntry" }, Line = 684 },
	{ Id = "L689.End", Remote = "Remotes.UI.GarageSessionRequest", Action = "End", Keys = { "ReturnToEntry" }, Line = 689 },
	{ Id = "L691.DespawnVehicle", Remote = "Remotes.Garage.GarageInvoke", Action = "DespawnVehicle", Keys = {  }, Line = 691 },
	{ Id = "L691.SelectVehicleInstance.1", Remote = "Remotes.Garage.GarageInvoke", Action = "SelectVehicleInstance", Keys = { "VehicleId" }, Line = 691 },
}
-- END GENERATED ACTIONS

return function(M, env)
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

	local function sortedKeys(payload)
		local keys = {}
		for key in pairs(payload or {}) do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		return table.concat(keys, ",")
	end

	local function sortedList(list)
		local copy = table.clone(list)
		table.sort(copy)
		return table.concat(copy, ",")
	end

	-- Every (remote, action, keys) the model sent in any case; checked against the action table at the end.
	local seen = {}

	-- Kit.Data.ProjectEconomy reaches a Classic module in the game; tests give it a pure stand-in and put it back.
	local okData, Data = pcall(env.Load, "ReplicatedStorage.Modules.Game.UIPulse.Kit.Data")
	local savedFoundation = okData and type(Data) == "table" and Data._foundation or nil
	if okData and type(Data) == "table" then
		Data._foundation = function()
			return {
				ProjectEconomy = function(response, fallback)
					local result = type(fallback) == "table" and { Cash = fallback.Cash, Used = fallback.Used, Capacity = fallback.Capacity } or {}
					if type(response) == "table" and type(response.Profile) == "table" then
						result.Cash = tonumber(response.Profile.Cash) or result.Cash
					end
					return result
				end,
			}
		end
	end

	-- The shared card view model, unchanged, when the harness can load it; else a stand-in with the same fields.
	local okCards, ModuleCards = pcall(env.Load, "ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel")
	if not okCards or type(ModuleCards) ~= "table" or type(ModuleCards.Owned) ~= "function" then
		ModuleCards = {}
		function ModuleCards.Owned(context)
			local rows = {}
			for instanceId, item in pairs(context.Instances or {}) do
				local module = context.ResolveModule(item.TemplateId)
				if module and context.Fits(module, context.Slot) then
					local owner = tostring(item.EquippedVehicleId or "")
					local state, status
					if tostring(instanceId) == tostring(context.InstalledInstanceId or "") then
						state, status = "Equipped", "EQUIPPED"
					elseif owner ~= "" and owner ~= tostring(context.CurrentVehicleId or "") then
						state, status = "InUse", "IN USE BY " .. string.upper(context.VehicleName(owner))
					else
						state, status = "Available", "AVAILABLE"
					end
					table.insert(rows, { Id = tostring(instanceId), Module = module, Item = item, State = state, Status = status,
						Title = context.SourceVehicleName(module), Tag = "Standard", Rating = 0, OwnerVehicleId = owner })
				end
			end
			table.sort(rows, function(a, b)
				return a.Id < b.Id
			end)
			return rows
		end
		function ModuleCards.Shop(context)
			local rows = {}
			for _, module in ipairs(context.Modules or {}) do
				local locked = context.IsLocked(module)
				table.insert(rows, { Id = tostring(module.ModuleId), Module = module, State = locked and "Locked" or "Shop",
					Status = locked and "LOCKED" or ("OWNED x" .. tostring(context.OwnedCount(module.ModuleId))),
					Title = context.SourceVehicleName(module), Tag = "Standard", Rating = 0, Locked = locked, Price = tonumber(module.Price) or 0 })
			end
			table.sort(rows, function(a, b)
				if a.Locked ~= b.Locked then
					return not a.Locked
				end
				return a.Id < b.Id
			end)
			return rows
		end
	end

	local function encode(value, active)
		if type(value) ~= "table" then
			return typeof(value) .. ":" .. tostring(value)
		end
		active = active or {}
		if active[value] then
			return "<cycle>"
		end
		active[value] = true
		local keys = {}
		for key in pairs(value) do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local parts = { "{" }
		for _, key in ipairs(keys) do
			table.insert(parts, tostring(key) .. "=" .. encode(value[key], active) .. ";")
		end
		table.insert(parts, "}")
		active[value] = nil
		return table.concat(parts)
	end

	local function catalog()
		local function module(id, kind, source, price)
			return { ModuleId = id, ModuleType = kind, DisplayName = id, Price = price, SourceCockpitId = source,
				NeonAvailable = true, NeonPrice = 5000,
				Upgrades = { { UpgradeId = "u1", DisplayName = "Intake", MaxLevel = 3, BasePrice = 12000, EffectsPerLevel = { TopSpeed = 3 } },
					{ UpgradeId = "u2", DisplayName = "Cooling", MaxLevel = 3, BasePrice = 18000, EffectsPerLevel = { Drag = -0.25 } } } }
		end
		return {
			Categories = { {
				CategoryId = "exotic", DisplayName = "Exotic",
				Cockpits = {
					{ CockpitId = "ck1", DisplayName = "Stinger", Price = 1000, TestTier = "E", TestIndex = 220 },
					{ CockpitId = "ck2", DisplayName = "Zephyr", Price = 150000, TestTier = "D", TestIndex = 390 },
				},
				Slots = {
					{ SlotId = "Engine1", ModuleType = "Engine", Order = 1 },
					{ SlotId = "Stabilisers", ModuleType = "Stabiliser", Order = 3 },
					{ SlotId = "Boost", ModuleType = "Boost", Order = 4 },
					{ SlotId = "RearSpoiler", ModuleType = "Spoiler", Order = 5 },
				},
				Modules = {
					Engine = { module("eng1", "Engine", "ck1", 500) },
					Stabiliser = { module("stab1", "Stabiliser", "ck1", 600) },
					Boost = { module("boost1", "Boost", "ck1", 700) },
					Spoiler = { module("sp1", "Spoiler", "ck1", 3000), module("sp2", "Spoiler", "ck2", 42000) },
				},
			} },
			VehicleCosmetics = { { CosmeticId = "ThrustColour", DisplayName = "Thrust Colour", Price = 5000 } },
		}
	end

	-- options.Owned = false: a profile with no vehicle. options.Boost = false: the vehicle has no boost fitted.
	local function world(options)
		options = options or {}
		local w = { calls = {}, fired = {}, loading = {}, attrs = { GarageEntryMode = "Dealership" }, deferred = {},
			builds = 0, paints = {}, audio = {}, replies = {}, warnings = {} }
		local cat = catalog()
		local profile = {
			Cash = 100000, CurrentCategory = "exotic", Garage = { OwnedVehicleCount = 0, Capacity = 2, OwnedGarageProperties = {} },
			Vehicles = {}, OwnedCockpitInstances = {}, OwnedModuleInstances = {}, InstalledModules = {},
			CockpitColors = {}, ModuleColors = {}, NeonOwned = {},
		}
		if options.Owned ~= false then
			profile.Garage.OwnedVehicleCount = 1
			profile.CurrentVehicleId = "V1"
			profile.CurrentCockpit = "ck1"
			profile.OwnedCockpitInstances.CI1 = { TemplateId = "ck1" }
			profile.OwnedModuleInstances.MI1 = { TemplateId = "eng1", EquippedVehicleId = "V1" }
			profile.OwnedModuleInstances.MI2 = { TemplateId = "stab1", EquippedVehicleId = "V1" }
			local installed = { Engine1 = "MI1", Stabilisers = "MI2" }
			if options.Boost ~= false then
				profile.OwnedModuleInstances.MI3 = { TemplateId = "boost1", EquippedVehicleId = "V1" }
				installed.Boost = "MI3"
			end
			if options.SpareSpoiler then
				profile.OwnedModuleInstances.MI9 = { TemplateId = "sp1", EquippedVehicleId = options.SpareSpoiler ~= true and options.SpareSpoiler or nil }
			end
			profile.Vehicles.V1 = { CockpitInstanceId = "CI1", CategoryId = "exotic", InstalledModules = installed }
		end
		w.profile = profile
		local nextInstance = 100

		local function record(remote, action, payload)
			table.insert(w.calls, { Remote = remote, Action = action, Payload = payload })
			seen[remote .. "|" .. action .. "|" .. sortedKeys(payload)] = true
		end

		local garageInvoke = {}
		function garageInvoke:InvokeServer(action, payload)
			record("Remotes.Garage.GarageInvoke", action, payload)
			if w.onInvoke then
				w.onInvoke(action, payload)
			end
			local scripted = w.replies[action]
			if scripted ~= nil then
				w.replies[action] = nil
				return scripted
			end
			if action == "GetInitial" then
				return { Success = true, Catalog = cat, Profile = profile }
			elseif action == "BuyCockpitInstance" then
				profile.OwnedCockpitInstances.CI2 = { TemplateId = payload.CockpitId }
				profile.Vehicles.V2 = { CockpitInstanceId = "CI2", CategoryId = payload.CategoryId, InstalledModules = {} }
				profile.CurrentVehicleId = "V2"
				profile.CurrentCockpit = payload.CockpitId
			elseif action == "SelectVehicleInstance" then
				profile.CurrentVehicleId = payload.VehicleId
				profile.CurrentCockpit = profile.OwnedCockpitInstances[profile.Vehicles[payload.VehicleId].CockpitInstanceId].TemplateId
			elseif action == "BuyModuleInstance" then
				nextInstance += 1
				local id = "MI" .. nextInstance
				profile.OwnedModuleInstances[id] = { TemplateId = payload.ModuleId, EquippedVehicleId = payload.VehicleId }
				profile.Vehicles[payload.VehicleId].InstalledModules[payload.SlotId] = id
			elseif action == "EquipModuleInstance" then
				profile.OwnedModuleInstances[payload.ModuleInstanceId].EquippedVehicleId = payload.VehicleId
				profile.Vehicles[payload.VehicleId].InstalledModules[payload.SlotId] = payload.ModuleInstanceId
			elseif action == "BuyNeon" then
				profile.NeonOwned[payload.SlotId] = true
			end
			return { Success = true, Profile = profile }
		end

		local sessionRequest = {}
		function sessionRequest:InvokeServer(action, payload)
			record("Remotes.UI.GarageSessionRequest", action, payload)
			local scripted = w.replies["Session." .. action]
			if scripted ~= nil then
				w.replies["Session." .. action] = nil
				return scripted
			end
			return { Success = true }
		end

		local function folder(label)
			local events = {}
			return {
				FindFirstChild = function(_, name)
					events[name] = events[name] or {
						IsA = function(_, className)
							return className == "BindableEvent"
						end,
						Fire = function(_, ...)
							table.insert(w.fired, { Folder = label, Name = name, Args = { ... } })
						end,
					}
					return events[name]
				end,
			}
		end

		local previewRoot = { Parent = true, Attributes = {} }
		function previewRoot:SetAttribute(name, value)
			self.Attributes[name] = value
		end
		function previewRoot:Destroy()
			self.Parent = nil
		end

		local deps = {
			Player = {
				Character = nil,
				SetAttribute = function(_, name, value)
					w.attrs[name] = value
				end,
			},
			Workspace = { CurrentCamera = {} },
			Remotes = { GarageInvoke = garageInvoke, GarageSessionRequest = sessionRequest },
			Bindables = { LoadingTransitionInvoke = {
				Invoke = function(_, action, payload)
					table.insert(w.loading, { Action = action, Payload = payload })
					return action == "Begin" and 7 or nil
				end,
			} },
			Folders = { UI = folder("UI"), Dealership = folder("Dealership") },
			Config = {
				Replacement = {
					GetAttribute = function()
						return nil
					end,
					FindFirstChild = function()
						return nil
					end,
				},
				Artwork = nil,
			},
			CategoriesRoot = {},
			Modules = {
				CatalogTransport = {
					Fetch = function(remote, payload)
						return remote:InvokeServer("GetInitial", payload)
					end,
				},
				VehicleCatalog = {
					Get = function()
						return nil
					end,
				},
				ModuleCards = ModuleCards,
				AudioBridge = {
					Result = function(kind, result, payload)
						table.insert(w.audio, { Kind = kind, Success = result.Success, Action = payload.Action })
					end,
					Emit = function(cue)
						table.insert(w.audio, { Cue = cue })
					end,
				},
				PreviewVehicle = {
					Build = function(context)
						w.builds += 1
						previewRoot.Parent = true
						context.Preview.Root = previewRoot
						context.Preview.Vehicle = { Parent = true }
						context.State.TargetFocus = "focus"
						return context.Preview.Vehicle, nil
					end,
					ApplyPaint = function(context)
						table.insert(w.paints, { Target = context.Target, Channel = context.Channel })
						return true
					end,
				},
				PreviewCamera = {
					SetCameraSection = function(state, id)
						state.CameraSection = id or "ALL"
					end,
					Reset = function(state)
						state.CameraSection = "ALL"
					end,
					BindInput = function(context)
						w.cameraBound = context
					end,
					Release = function()
						w.cameraReleased = true
					end,
					Update = function()
						w.cameraUpdates = (w.cameraUpdates or 0) + 1
					end,
				},
				InstancePreview = {
					ProfileFingerprint = function(value)
						return encode(value or {})
					end,
					Performance = function()
						return nil, nil
					end,
				},
				PreviewProfiles = {
					ForBrowser = function(_, row)
						return { PreviewKind = "Factory", CurrentCockpit = row.CockpitId, InstalledModules = {} }
					end,
				},
				PerformanceResolver = {
					Factory = function(_, cockpit)
						return { Overall = { Tier = cockpit.TestTier, PerformanceIndex = cockpit.TestIndex },
							Headline = { Speed = 77.4, Acceleration = 74, Handling = 74, Drift = 72, Braking = 73, Boost = 72 } }
					end,
					Profile = function()
						return { Overall = { Tier = "D", PerformanceIndex = 321.7 },
							Headline = { Speed = 80, Acceleration = 74, Handling = 63, Drift = 61, Braking = 62, Boost = 61 } }
					end,
					UpgradePreview = function()
						return nil, nil
					end,
					ModuleRating = function()
						return 316
					end,
					FindModule = function()
						return { UpgradePointCapacity = 10 }
					end,
					UpgradeCost = function()
						return nil
					end,
				},
				PropertyCatalog = {
					List = function()
						return { { PropertyId = "P1", DisplayName = "Kanda Lift Bay", Price = 50000 } }
					end,
				},
			},
			Defer = function(callback)
				table.insert(w.deferred, callback)
			end,
			Warn = function(text)
				table.insert(w.warnings, text)
			end,
		}
		w.model = M.new(deps)
		w.reasons = {}
		w.model.Changed:Connect(function(reason)
			table.insert(w.reasons, reason)
		end)
		function w.flush()
			local queue = w.deferred
			w.deferred = {}
			for _, callback in ipairs(queue) do
				callback()
			end
		end
		function w.actions(from)
			local list = {}
			for index = from or 1, #w.calls do
				table.insert(list, w.calls[index].Action)
			end
			return table.concat(list, ",")
		end
		function w.last()
			return w.calls[#w.calls]
		end
		function w.firedNames()
			local list = {}
			for _, entry in ipairs(w.fired) do
				table.insert(list, entry.Name)
			end
			return table.concat(list, ",")
		end
		function w.item(key)
			for _, item in ipairs(w.model.Page().Items) do
				if item.Key == key then
					return item
				end
			end
			return nil
		end
		return w
	end

	-- Opens straight into Customise (the DriveIn entry), on the Parts tab.
	local function customise(options)
		local w = world(options)
		w.model.Open("DriveIn", { LoadingGeneration = 3 })
		return w
	end

	------------------------------------------------------------------------------------------------------------
	-- The action table.
	------------------------------------------------------------------------------------------------------------
	case("actions: the model's table equals the Classic call sites (actions.json)", function()
		expect(#EXPECTED_ACTIONS > 0, "generated block is empty: run gen_actions.py")
		expect(#M.Actions == #EXPECTED_ACTIONS, "count " .. #M.Actions .. " against " .. #EXPECTED_ACTIONS)
		for index, wanted in ipairs(EXPECTED_ACTIONS) do
			local have = M.Actions[index]
			expect(have.Id == wanted.Id, "id at " .. index .. ": " .. tostring(have.Id))
			expect(have.Remote == wanted.Remote, wanted.Id .. " remote")
			expect(have.Action == wanted.Action, wanted.Id .. " action")
			expect(have.Line == wanted.Line, wanted.Id .. " line")
			expect(table.concat(have.Keys, ",") == table.concat(wanted.Keys, ","), wanted.Id .. " keys")
		end
	end)

	------------------------------------------------------------------------------------------------------------
	-- Entry.
	------------------------------------------------------------------------------------------------------------
	case("entry Dealership: GetInitial only, browser page, first row selected on the next step", function()
		local w = world({ Owned = false })
		w.model.Open("Dealership", nil)
		expect(w.actions() == "GetInitial", "calls: " .. w.actions())
		expect(w.model.State.Stage == "Browser" and w.model.State.ShopMode == "Dealership", "stage")
		expect(w.model.Showing() == "Browser", "browser showing")
		expect(w.model.Page().Selected == nil, "no selection before the deferred step")
		expect(w.loading[1].Action == "Begin" and w.loading[1].Payload.Destination == "Dealership"
			and w.loading[1].Payload.Status == "ENTERING DEALERSHIP", "Begin payload")
		expect(w.loading[2].Action == "Complete" and w.loading[2].Payload.Generation == 7 and w.loading[2].Payload.Status == "READY", "Complete")
		w.flush()
		local page = w.model.Page()
		expect(page.Id == "Dealership" and page.Selected == "C:ck1", "first row selected: " .. tostring(page.Selected))
		expect(w.builds == 1, "one preview build")
		expect(w.model.State.NoPreviewYet == false and w.model.State.SelectedCockpit == "ck1", "selection state")
		expect(w.cameraBound ~= nil and w.cameraBound.IsActive() == true, "camera input bound and active")
	end)

	case("entry Dealership: tier, rating and price inputs are the server's values; affordability is replicated Cash", function()
		local w = world({ Owned = false })
		w.model.Open("Dealership", nil)
		w.flush()
		local cheap, dear = w.item("C:ck1"), w.item("C:ck2")
		expect(cheap.Tier == "E" and cheap.Rating == 220 and cheap.PriceAmount == 1000, "ck1 inputs")
		expect(dear.Tier == "D" and dear.Rating == 390 and dear.PriceAmount == 150000, "ck2 inputs")
		expect(cheap.Status == "None" and dear.Status == "Unaffordable", "statuses at 100000")
		expect(w.model.Page().Action.Text == "Buy" and w.model.Page().Action.Amount == 1000, "action carries the catalogue price")
		w.model.SetReplicatedCash(200000)
		expect(w.item("C:ck2").Status == "None", "affordable after Cash moved")
		expect(w.reasons[#w.reasons] == "cash", "cash reason")
		local before = #w.reasons
		w.model.SetReplicatedCash(200001)
		expect(#w.reasons == before, "no change, no signal")
		expect(w.model.Page().Stats.Tier == "E" and w.model.Page().Stats.Rating == 220, "stat header")
		expect(w.model.Page().Stats.Rows[1].Id == "Speed" and w.model.Page().Stats.Rows[1].Value == 77
			and w.model.Page().Stats.Rows[1].Max == 180, "stat row")
	end)

	case("dealership buy: confirmation first, then BuyCockpitInstance {CockpitId, CategoryId}, then post-purchase paint", function()
		local w = world({ Owned = false })
		w.model.Open("Dealership", nil)
		w.flush()
		w.model.SelectItem("C:ck1")
		local sent = #w.calls
		w.model.Action()
		expect(#w.calls == sent, "nothing sent before the confirmation")
		expect(w.model.Modal().Kind == "BuyVehicle" and w.model.Modal().PriceAmount == 1000, "confirmation shows the catalogue price")
		w.model.ResolveModal(false)
		expect(#w.calls == sent and w.model.Modal() == nil, "NO sends nothing")
		w.model.Action()
		w.model.ResolveModal(true)
		expect(#w.calls == sent + 1, "exactly one call")
		local last = w.last()
		expect(last.Action == "BuyCockpitInstance" and sortedKeys(last.Payload) == "CategoryId,CockpitId", "keys")
		expect(last.Payload.CockpitId == "ck1" and last.Payload.CategoryId == "exotic", "values from the row")
		expect(w.model.State.Stage == "Paint" and w.model.Page().Id == "PostPaint", "post-purchase paint")
		expect(w.model.State.CustomizeTarget == "ALL" and w.model.State.CustomizeMode == "Overview" and w.model.State.ModuleMode == "Slots", "L194 state")
		expect(w.model.State.SelectedVehicleId == "V2", "current vehicle from the reply")
		expect(w.audio[#w.audio].Kind == "VehiclePurchase", "success sound override")
		expect(w.model.Page().Tab == nil and w.model.Page().Buttons.Back.Visible == false, "no tabs, no Back")
		w.model.Action()
		expect(w.model.State.Stage == "Build" and w.model.State.ModuleMode == "Slots" and w.model.Page().Id == "Parts", "Customise opens the Parts tab")
	end)

	case("dealership buy refused: inline line and toast, page stays, nothing retried", function()
		local w = world({ Owned = false })
		w.model.Open("Dealership", nil)
		w.flush()
		w.replies.BuyCockpitInstance = { Success = false, Message = "NOT ENOUGH CASH" }
		local sent = #w.calls
		w.model.Action()
		w.model.ResolveModal(true)
		expect(#w.calls == sent + 1, "one call, no retry")
		expect(w.model.State.Stage == "Browser" and w.model.Page().Message == "NOT ENOUGH CASH", "inline line")
		expect(w.fired[#w.fired].Name == "ShowTopNotification" and w.fired[#w.fired].Args[1] == "NOT ENOUGH CASH", "toast")
		expect(w.audio[#w.audio].Kind == "Purchase" and w.audio[#w.audio].Success == false, "reject sound kind")
	end)

	case("dealership exit: End {ReturnToEntry}, attribute cleared, closed event, loading Complete", function()
		local w = world({ Owned = false })
		w.model.Open("Dealership", nil)
		w.flush()
		local sent = #w.calls
		w.model.Exit()
		expect(w.actions(sent + 1) == "End" and w.last().Payload.ReturnToEntry == true, "End")
		expect(w.last().Remote == "Remotes.UI.GarageSessionRequest", "session remote")
		expect(w.attrs.GarageEntryMode == nil, "GarageEntryMode cleared")
		expect(w.fired[#w.fired].Name == "GarageClosedFromDealershipExit", "closed event")
		expect(w.model.State.Stage == "Closed" and w.model.IsActive() == false and w.model.Page().Id == "Closed", "closed")
		expect(w.loading[#w.loading].Action == "Complete" and w.loading[#w.loading - 1].Payload.Destination == "DealershipExterior", "loading")
		expect(w.cameraReleased == true and w.model.State.Profile == nil, "camera released, profile dropped")
	end)

	case("dealership exit refused: stays open, Fail with the reason", function()
		local w = world({ Owned = false })
		w.model.Open("Dealership", nil)
		w.flush()
		w.replies["Session.End"] = { Success = false, Message = "BUSY" }
		w.model.Exit()
		expect(w.model.IsActive() == true and w.model.State.Stage == "Browser", "still open")
		expect(w.loading[#w.loading].Action == "Fail" and w.loading[#w.loading].Payload.Reason == "BUSY", "Fail")
		expect(w.attrs.GarageEntryMode == "Dealership", "attribute untouched")
	end)

	case("entry Customisation: access check, GetInitial, pick an owned vehicle with {VehicleId, CockpitId}", function()
		local w = world()
		w.model.Open("Customisation", nil)
		expect(w.actions() == "EnsureCustomisationAccess,GetInitial", "calls: " .. w.actions())
		expect(w.loading[1].Payload.Destination == "Customisation" and w.loading[1].Payload.Status == "ENTERING CUSTOMISATION", "Begin")
		w.flush()
		expect(w.model.Page().Selected == "V:V1", "owned row selected")
		expect(w.model.Page().Action.Text == "Customise" and w.model.Page().Action.Amount == nil, "no price on Customise")
		local sent = #w.calls
		w.model.Action()
		expect(w.model.Modal() == nil, "no purchase confirmation in Customisation")
		expect(w.actions(sent + 1) == "SelectVehicleInstance" and sortedKeys(w.last().Payload) == "CockpitId,VehicleId", "keys")
		expect(w.last().Payload.VehicleId == "V1" and w.last().Payload.CockpitId == "ck1", "values")
		expect(w.model.State.Stage == "Build" and w.model.Page().Id == "Parts" and w.model.Page().Tab == "Parts", "hub is the Parts tab")
	end)

	case("entry refused: toast, End, attribute cleared, nothing shown", function()
		local w = world({ Owned = false })
		w.replies.EnsureCustomisationAccess = { Success = false, Message = "OWN A VEHICLE TO CUSTOMISE" }
		w.model.Open("Customisation", nil)
		expect(w.actions() == "EnsureCustomisationAccess,End", "calls: " .. w.actions())
		expect(w.fired[1].Name == "ShowTopNotification" and w.fired[1].Args[1] == "OWN A VEHICLE TO CUSTOMISE", "toast")
		expect(w.audio[#w.audio].Cue == "UI.PurchaseRejected", "reject cue")
		expect(w.attrs.GarageEntryMode == nil and w.model.IsActive() == false, "cleared")
		expect(#w.loading == 0, "no loading generation was begun")
	end)

	case("entry GetInitial failed: End, attribute cleared, Fail", function()
		local w = world()
		w.replies.GetInitial = { Success = false, Message = "DOWN" }
		w.model.Open("Dealership", nil)
		expect(w.actions() == "GetInitial,End", "calls: " .. w.actions())
		expect(w.loading[#w.loading].Action == "Fail" and w.loading[#w.loading].Payload.Reason == "DOWN", "Fail")
		expect(w.model.IsActive() == false and w.attrs.GarageEntryMode == nil, "closed")
	end)

	case("entry DriveIn: despawn, exited event, select {VehicleId}, Parts tab, generation passed through", function()
		local w = customise()
		expect(w.actions() == "EnsureCustomisationAccess,GetInitial,DespawnVehicle,SelectVehicleInstance", "calls: " .. w.actions())
		expect(sortedKeys(w.last().Payload) == "VehicleId" and w.last().Payload.VehicleId == "V1", "select keys")
		expect(w.firedNames() == "FreeRoamVehicleExited", "fired: " .. w.firedNames())
		expect(#w.loading == 1 and w.loading[1].Action == "Complete" and w.loading[1].Payload.Generation == 3, "no Begin when a generation is passed")
		expect(w.model.State.Stage == "Build" and w.model.State.ModuleMode == "Slots", "Parts, slot list")
		expect(w.model.Showing() == "Workspace", "workspace showing")
		expect(w.builds == 1, "one preview build")
	end)

	case("entry while open: only completes the passed generation", function()
		local w = customise()
		local sent, loads = #w.calls, #w.loading
		w.model.Open("Dealership", { LoadingGeneration = 9 })
		expect(#w.calls == sent, "no remote")
		expect(#w.loading == loads + 1 and w.loading[#w.loading].Payload.Generation == 9, "Complete 9")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Parts: slots, Shop / Owned, buy, equip.
	------------------------------------------------------------------------------------------------------------
	case("parts: slot tiles from the catalogue, fitted and empty", function()
		local w = customise()
		local page = w.model.Page()
		expect(#page.Items == 4, "four slots, got " .. #page.Items)
		expect(page.Items[1].Key == "Engine1" and page.Items[1].Status == "Fitted" and page.Items[1].ChipRight == "EQUIPPED", "engine fitted")
		expect(w.item("RearSpoiler").Status == "None" and w.item("RearSpoiler").ChipRight == "EMPTY", "spoiler empty")
		expect(page.TutorialPageId == "AddModules" and page.Tabs.Selected == "Parts", "tutorial page id and tab")
		expect(page.Buttons.Back.Visible == true and page.Buttons.Back.Disabled == true, "Back has no destination on the slot list")
		expect(page.Stats.Rating == 321 and page.Stats.Tier == "D", "stats from the profile")
	end)

	case("parts: a slot opens the Shop list (the Sources page is skipped); Owned is locked with no owned module", function()
		local w = customise()
		w.model.SelectItem("RearSpoiler")
		local state = w.model.State
		expect(state.SelectedSlot == "RearSpoiler" and state.ModuleMode == "Options" and state.ModuleOptionMode == "Buy", "state")
		expect(state.CameraSection == "RearSpoiler", "camera section")
		local page = w.model.Page()
		expect(page.Source.Selected == "Buy" and page.Source.OwnedLocked == true, "switch")
		expect(#page.Items == 2 and page.Items[1].Key == "M:sp1" and page.Items[2].Key == "M:sp2", "shop rows, unlocked first")
		expect(page.Items[1].PriceAmount == 3000 and page.Items[1].Status == "None", "price is the catalogue value, no affordability")
		expect(page.Items[2].Status == "Locked" and page.Items[2].Selectable == true, "locked row can still be previewed")
		w.model.SelectSource("Owned")
		expect(w.model.State.ModuleOptionMode == "Buy", "locked Owned does nothing")
		expect(M._filterRows(page.Lists, "Owned") == page.Lists.Owned and M._filterRows(page.Lists, "Buy") == page.Items, "filter over the two lists")
	end)

	case("parts: selecting a shop row previews it; BUY sends {ModuleId, VehicleId, SlotId}; back on the slot list", function()
		local w = customise()
		w.model.SelectItem("RearSpoiler")
		local builds = w.builds
		w.model.SelectItem("M:sp1")
		expect(w.model.State.SelectedModuleId == "sp1" and w.model.State.PreviewModules.RearSpoiler == "sp1", "preview state")
		expect(w.builds == builds + 1, "preview rebuilt for a new module")
		expect(w.model.Page().Action.Text == "Buy" and w.model.Page().Action.Amount == 3000, "action")
		w.model.SelectItem("M:sp2")
		expect(w.model.Page().Action == nil, "no BUY on a locked row")
		local sentLocked = #w.calls
		w.model.Action()
		expect(#w.calls == sentLocked, "nothing sent for a locked row")
		w.model.SelectItem("M:sp1")
		local sent = #w.calls
		w.model.Action()
		expect(#w.calls == sent + 1 and w.last().Action == "BuyModuleInstance", "one call")
		expect(sortedKeys(w.last().Payload) == "ModuleId,SlotId,VehicleId", "keys")
		expect(w.last().Payload.ModuleId == "sp1" and w.last().Payload.VehicleId == "V1" and w.last().Payload.SlotId == "RearSpoiler", "values")
		expect(w.model.State.ModuleMode == "Slots" and w.model.State.SelectedModuleId == nil and next(w.model.State.PreviewModules) == nil, "cleared")
		expect(w.model.Page().Message == "Module purchased and equipped.", "message")
		expect(w.audio[#w.audio].Kind == "ModuleEquip", "success sound override")
		expect(w.item("RearSpoiler").Status == "Fitted", "slot now fitted")
	end)

	case("parts: buy refused keeps the page and the selection; inline line and toast", function()
		local w = customise()
		w.model.SelectItem("RearSpoiler")
		w.model.SelectItem("M:sp1")
		w.replies.BuyModuleInstance = { Success = false, Message = "NOT ENOUGH CASH" }
		w.model.Action()
		expect(w.model.State.ModuleMode == "Options" and w.model.State.SelectedModuleId == "sp1", "unchanged")
		expect(w.model.Page().Message == "NOT ENOUGH CASH" and w.fired[#w.fired].Name == "ShowTopNotification", "message and toast")
	end)

	case("parts: Owned list, EQUIP sends {ModuleInstanceId, VehicleId, SlotId, AllowReassign=false}", function()
		local w = customise({ SpareSpoiler = true })
		w.model.SelectItem("RearSpoiler")
		expect(w.model.Page().Source.OwnedLocked == false, "Owned available")
		w.model.SelectSource("Owned")
		expect(w.model.State.ModuleOptionMode == "Owned" and #w.model.Page().Items == 1, "owned rows")
		w.model.SelectItem("I:MI9")
		expect(w.model.State.SelectedModuleInstanceId == "MI9" and w.model.Page().Action.Text == "Equip", "selected")
		local sent = #w.calls
		w.model.Action()
		expect(#w.calls == sent + 1 and w.last().Action == "EquipModuleInstance", "one call")
		expect(sortedKeys(w.last().Payload) == "AllowReassign,ModuleInstanceId,SlotId,VehicleId", "keys")
		expect(w.last().Payload.AllowReassign == false and w.last().Payload.ModuleInstanceId == "MI9", "values")
		expect(w.model.State.ModuleMode == "Slots", "back on the slot list")
	end)

	case("parts: a module in use elsewhere asks first; YES sends AllowReassign=true, NO sends nothing", function()
		local w = customise({ SpareSpoiler = "V7" })
		w.model.SelectItem("RearSpoiler")
		w.model.SelectSource("Owned")
		w.model.SelectItem("I:MI9")
		expect(w.item("I:MI9").RowState == "InUse", "in use")
		local sent = #w.calls
		w.model.Action()
		expect(w.model.Modal().Kind == "Move" and w.model.Modal().VehicleName == "ANOTHER VEHICLE", "move confirmation")
		expect(#w.calls == sent, "nothing sent yet")
		w.model.ResolveModal(false)
		expect(#w.calls == sent and w.model.Modal() == nil, "NO")
		w.model.Action()
		w.model.ResolveModal(true)
		expect(#w.calls == sent + 1 and w.last().Payload.AllowReassign == true, "YES")
	end)

	case("parts: Back from the list returns to the slot list; tab change clears the transient preview", function()
		local w = customise()
		w.model.SelectItem("RearSpoiler")
		w.model.SelectItem("M:sp1")
		expect(w.model.Page().Buttons.Back.Disabled == false, "Back available")
		w.model.Back()
		local state = w.model.State
		expect(state.ModuleMode == "Slots" and state.ModuleOptionMode == nil and state.SelectedModuleId == nil, "slot list")
		expect(next(state.PreviewModules) == nil and state.CameraSection == "ALL", "preview cleared, camera on the whole car")
		w.model.SelectItem("RearSpoiler")
		w.model.SelectItem("M:sp1")
		w.model.SelectTab("Upgrades")
		expect(state.SelectedModuleId == nil and next(state.PreviewModules) == nil and state.PreviewUpgradeId == nil, "cleared on tab change")
		expect(state.Stage == "Customise" and state.CustomizeMode == "Upgrades" and w.model.Page().Tab == "Upgrades", "upgrades")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Upgrades and the empty-slot detour.
	------------------------------------------------------------------------------------------------------------
	case("upgrades: target is the selected slot when fitted, else the first fitted; selecting a card rebuilds no preview", function()
		local w = customise()
		w.model.State.SelectedSlot = "RearSpoiler"
		w.model.SelectTab("Upgrades")
		expect(w.model.State.CustomizeTarget == "Engine1", "first fitted slot: " .. tostring(w.model.State.CustomizeTarget))
		local page = w.model.Page()
		expect(page.TutorialPageId == "UpgradeModules" and page.Picker.Selected == "Engine1" and #page.Picker.Options == 4, "picker")
		expect(page.Budget.Used == 0 and page.Budget.Capacity == 10, "budget")
		expect(#page.Items == 2 and page.Items[1].PriceAmount == 12000 and page.Items[1].Sub == "+3 TOP SPEED", "upgrade card")
		expect(page.Items[2].Sub == "-0.25 DRAG", "second effect text")
		local builds = w.builds
		w.model.SelectItem("u1")
		expect(w.model.State.PreviewUpgradeId == "u1" and w.model.Page().Action.Text == "Upgrade" and w.model.Page().Action.Amount == 12000, "selected")
		w.model.SelectItem("u2")
		expect(w.builds == builds, "no preview rebuild on a card selection (Classic rebuilt on each)")
		local sent = #w.calls
		w.model.Action()
		expect(#w.calls == sent + 1 and w.last().Action == "UpgradeModule", "one call")
		expect(sortedKeys(w.last().Payload) == "ModuleId,SlotId,UpgradeId", "keys")
		expect(w.last().Payload.SlotId == "Engine1" and w.last().Payload.ModuleId == "eng1" and w.last().Payload.UpgradeId == "u2", "values")
		expect(w.model.State.PreviewUpgradeId == nil, "cleared")
		expect(w.audio[#w.audio].Kind == "Upgrade", "sound")
	end)

	case("upgrades: maxed and budget-full cards carry no action", function()
		local w = customise()
		w.profile.OwnedModuleInstances.MI1.V2UpgradePoints = { u1 = 3 }
		w.model.SelectTab("Upgrades")
		w.model.SelectItem("u1")
		local item = w.item("u1")
		expect(item.PriceText == "MAX LEVEL" and item.PriceAmount == nil and item.RowState == "Invested", "maxed")
		expect(w.model.Page().Action == nil, "no UPGRADE on a maxed card")
		local sent = #w.calls
		w.model.Action()
		expect(#w.calls == sent, "nothing sent")
		expect(w.model.Page().Budget.Used == 3, "used points")
	end)

	case("detour: an empty slot in Upgrades goes to Parts and BUY returns to Upgrades on that slot", function()
		local w = customise()
		w.model.SelectTab("Upgrades")
		w.model.SelectPicker("RearSpoiler")
		expect(w.model.State.CustomizeTarget == "RearSpoiler", "target")
		local page = w.model.Page()
		expect(#page.Items == 1 and page.Items[1].Key == "__MODULE_UNLOCK" and page.Items[1].Title == "BUY TO UNLOCK", "unlock card")
		w.model.SelectItem("__MODULE_UNLOCK")
		local state = w.model.State
		expect(state.Stage == "Build" and state.ModuleMode == "Options" and state.ModuleOptionMode == "Buy", "in Parts, Shop list")
		expect(state.ReturnWorkshop.Target == "RearSpoiler" and state.ReturnWorkshop.Workshop == "Upgrade", "return route")
		expect(state.SelectedSlot == "RearSpoiler" and w.model.Page().Tab == "Parts", "slot and tab")
		w.model.SelectItem("M:sp1")
		w.model.Action()
		expect(state.Stage == "Customise" and state.CustomizeMode == "Upgrades" and state.CustomizeTarget == "RearSpoiler", "back in Upgrades")
		expect(state.ReturnWorkshop == nil and w.model.Page().Tab == "Upgrades", "route consumed")
		expect(#w.model.Page().Items == 2, "upgrade cards for the new module")
	end)

	case("detour: with an owned module the card reads EQUIP TO UNLOCK and lands on Owned; Back returns without buying", function()
		local w = customise({ SpareSpoiler = true })
		w.model.SelectTab("Paint")
		w.model.SelectPicker("RearSpoiler")
		expect(w.model.State.CustomizeMode == "Overview", "slot targets open on Overview")
		expect(w.model.Page().Items[1].Title == "EQUIP TO UNLOCK", "unlock card")
		w.model.SelectItem("__MODULE_UNLOCK")
		local state = w.model.State
		expect(state.ModuleOptionMode == "Owned" and state.ReturnWorkshop.Workshop == "Paint", "Owned list, paint route")
		local sent = #w.calls
		w.model.Back()
		expect(#w.calls == sent, "Back sends nothing")
		expect(state.Stage == "Customise" and state.CustomizeMode == "Overview" and state.CustomizeTarget == "RearSpoiler", "back in Paint on that slot")
		expect(state.ReturnWorkshop == nil and w.model.Page().Tab == "Paint", "route consumed")
	end)

	case("detour: EQUIP returns to Paint on that slot", function()
		local w = customise({ SpareSpoiler = true })
		w.model.SelectTab("Paint")
		w.model.SelectPicker("RearSpoiler")
		w.model.SelectItem("__MODULE_UNLOCK")
		w.model.SelectItem("I:MI9")
		w.model.Action()
		local state = w.model.State
		expect(w.last().Action == "EquipModuleInstance", "equip sent")
		expect(state.Stage == "Customise" and state.CustomizeMode == "Overview" and state.CustomizeTarget == "RearSpoiler", "back in Paint")
		expect(w.model.Page().Items[1].Key == "Paint" and w.model.Page().Items[2].Key == "Neon", "paint and neon cards")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Back targets.
	------------------------------------------------------------------------------------------------------------
	case("back: Upgrades and Paint go to the hub tab; a slot in Colour mode goes to its Overview", function()
		local w = customise()
		w.model.SelectTab("Upgrades")
		w.model.Back()
		expect(w.model.State.Stage == "Build" and w.model.State.ModuleMode == "Slots", "Upgrades back")
		w.model.SelectTab("Paint")
		expect(w.model.State.CustomizeMode == "Colour" and w.model.State.CustomizeTarget == "ALL", "paint opens on ALL, Colour")
		expect(w.model.Page().Stats == nil, "no stat panel in the paint shop")
		w.model.Back()
		expect(w.model.State.Stage == "Build", "paint area back")
		w.model.SelectTab("Paint")
		w.model.SelectPicker("Engine1")
		w.model.SelectItem("Paint")
		expect(w.model.State.CustomizeMode == "Colour" and w.model.State.SelectedColorChannel == "Primary", "slot colour mode")
		w.model.Back()
		expect(w.model.State.Stage == "Customise" and w.model.State.CustomizeMode == "Overview" and w.model.State.CustomizeTarget == "Engine1", "slot back")
		w.model.Back()
		expect(w.model.State.Stage == "Build", "overview back")
		local sent = #w.calls
		w.model.Back()
		expect(#w.calls == sent and w.model.State.Stage == "Build" and w.model.State.ModuleMode == "Slots", "Back on the slot list does nothing")
	end)

	case("back: the route table covers every page key a state can produce", function()
		local Routes = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageRoutes")
		local states = {
			{ { Stage = "Build", ModuleMode = "Slots" }, "Parts.Slots" },
			{ { Stage = "Build", ModuleMode = "Sources" }, "Parts.Sources" },
			{ { Stage = "Build", ModuleMode = "Options" }, "Parts.Options" },
			{ { Stage = "Customise", CustomizeMode = "Upgrades" }, "Upgrades" },
			{ { Stage = "Customise", CustomizeMode = "Overview", CustomizeTarget = "Engine1" }, "Paint.Overview" },
			{ { Stage = "Customise", CustomizeMode = "Colour", CustomizeTarget = "ALL" }, "Paint.Colour.Area" },
			{ { Stage = "Customise", CustomizeMode = "Colour", CustomizeTarget = "UNDERGLOW" }, "Paint.Colour.Area" },
			{ { Stage = "Customise", CustomizeMode = "Colour", CustomizeTarget = "Engine1" }, "Paint.Colour.Slot" },
		}
		for _, pair in ipairs(states) do
			local key = Routes.PageKey(pair[1])
			expect(key == pair[2], "key " .. tostring(key) .. " for " .. pair[2])
			expect(Routes.Back[key] ~= nil and #Routes.Back[key].Steps >= 1, "route for " .. key)
		end
		expect(Routes.PageKey({ Stage = "Browser" }) == nil and Routes.PageKey({ Stage = "Paint" }) == nil, "no Back in the browser or post-purchase paint")
		expect(Routes.PageFor({ Stage = "Browser" }) == "Dealership" and Routes.PageFor({ Stage = "Paint" }) == "PostPaint", "pages")
		expect(Routes.TabFor({ Stage = "Customise", CustomizeMode = "Colour" }).Id == "Paint", "tab")
		expect(Routes.Tabs[1].TutorialPageId == "AddModules" and Routes.Tabs[2].TutorialPageId == "UpgradeModules"
			and Routes.Tabs[3].TutorialPageId == "PaintShop", "saved page ids unchanged")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Paint.
	------------------------------------------------------------------------------------------------------------
	case("paint: a drag only previews; a commit sends the Classic action for each target", function()
		local w = customise()
		local red = Color3.new(1, 0, 0)
		w.model.SelectTab("Paint")
		local sent = #w.calls
		w.model.PaintColour("Primary", red, false)
		expect(#w.calls == sent and #w.paints == 1 and w.paints[1].Target == "ALL", "preview only")
		w.model.PaintColour("Primary", red, true)
		expect(w.last().Action == "SetCockpitColor" and sortedKeys(w.last().Payload) == "Channel,Color,ReturnProfile,Scope", "ALL keys")
		expect(w.last().Payload.Scope == "WholeVehicle" and w.last().Payload.ReturnProfile == true and w.last().Payload.Color == red, "ALL values")
		w.model.PaintChannel("Neon")
		expect(w.model.State.SelectedColorChannel == "Neon", "channel")
		w.model.PaintColour("Neon", red, true)
		expect(w.last().Action == "SetAllNeonColor" and sortedKeys(w.last().Payload) == "Color,ReturnProfile", "neon keys")
		w.model.SelectPicker("Cockpit")
		expect(#w.model.Page().Paint.Channels == 5, "cockpit channels")
		w.model.PaintColour("FrontLights", red, true)
		expect(w.last().Action == "SetCockpitColor" and w.last().Payload.Scope == "CockpitOnly" and w.last().Payload.Channel == "FrontLights", "cockpit")
		w.model.SelectPicker("Engine1")
		w.model.SelectItem("Paint")
		w.model.PaintColour("Detail", red, true)
		expect(w.last().Action == "SetModuleColor" and sortedKeys(w.last().Payload) == "Channel,Color,ReturnProfile,SlotId", "module keys")
		expect(w.last().Payload.SlotId == "Engine1", "module slot")
	end)

	case("paint: thrust and underglow commits; cosmetic and neon purchases", function()
		local w = customise()
		local red = Color3.new(1, 0, 0)
		w.model.SelectTab("Paint")
		w.model.SelectPicker("THRUST_COLOR")
		expect(w.model.State.CustomizeMode == "Overview", "not owned: overview")
		local item = w.model.Page().Items[1]
		expect(item.Key == "ThrustColour" and item.PriceAmount == 5000 and item.Status == "None", "cosmetic card from the catalogue")
		w.profile.Cash = 10
		w.model.SelectItem("ThrustColour")
		expect(w.item("ThrustColour").Status == "Unaffordable" and w.model.Page().Action.Text == "Buy", "muted price, BUY still offered")
		w.model.Action()
		expect(w.last().Action == "BuyVehicleCosmetic" and sortedKeys(w.last().Payload) == "CosmeticId" and w.last().Payload.CosmeticId == "ThrustColour", "cosmetic buy")
		expect(w.model.State.CustomizeMode == "Colour" and w.model.State.SelectedColorChannel == "ThrustColor", "colour mode after buying")
		w.model.PaintColour("ThrustColor", red, true)
		expect(w.last().Action == "SetVehicleCosmeticColor" and w.last().Payload.CosmeticId == "ThrustColour", "thrust commit")
		expect(sortedKeys(w.last().Payload) == "Color,CosmeticId,ReturnProfile", "thrust keys")
		w.profile.Vehicles.V1.Cosmetics = { Unlocks = { Underglow = true }, Colours = {} }
		w.model.SelectPicker("UNDERGLOW")
		expect(w.model.State.CustomizeMode == "Colour" and w.model.State.SelectedColorChannel == "Underglow", "underglow owned: colour")
		w.model.PaintColour("Underglow", red, true)
		expect(w.last().Action == "SetVehicleCosmeticColor" and w.last().Payload.CosmeticId == "Underglow", "underglow commit")
		w.model.SelectPicker("Engine1")
		w.model.SelectItem("Neon")
		expect(w.model.State.PreviewNeonSlot == "Engine1" and w.model.Page().Action.Amount == 5000, "neon preview and price")
		w.model.Action()
		expect(w.last().Action == "BuyNeon" and sortedKeys(w.last().Payload) == "SlotId" and w.last().Payload.SlotId == "Engine1", "neon buy")
		expect(w.model.State.CustomizeMode == "Colour" and w.model.State.SelectedColorChannel == "Neon" and w.model.State.PreviewNeonSlot == nil, "neon colour mode")
	end)

	case("paint: a refused commit rebuilds the preview, shows the message, sends once", function()
		local w = customise()
		w.model.SelectTab("Paint")
		w.replies.SetCockpitColor = { Success = false, Message = "RATE LIMITED" }
		local sent = #w.calls
		w.model.PaintColour("Primary", Color3.new(0, 1, 0), true)
		expect(#w.calls == sent + 1, "one call")
		expect(w.model.Page().Message == "RATE LIMITED" and w.reasons[#w.reasons] == "message", "message, page not redrawn")
	end)

	case("post-purchase paint commits with target WholeVehicle", function()
		local w = world({ Owned = false })
		w.model.Open("Dealership", nil)
		w.flush()
		w.model.Action()
		w.model.ResolveModal(true)
		expect(w.model.Page().Paint.Target == "WholeVehicle" and #w.model.Page().Paint.Channels == 3, "three channels")
		w.model.PaintChannel("Secondary")
		expect(w.model.State.SelectedColorChannel == "Secondary" and w.model.State.Stage == "Paint", "channel")
		w.model.PaintColour("Secondary", Color3.new(0, 0, 1), true)
		expect(w.last().Action == "SetCockpitColor" and w.last().Payload.Scope == "WholeVehicle" and w.last().Payload.Channel == "Secondary", "commit")
		expect(w.paints[#w.paints].Target == "WholeVehicle", "preview target")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Drive.
	------------------------------------------------------------------------------------------------------------
	case("drive: blocked without boost; nothing sent, message shown", function()
		local w = customise({ Boost = false })
		local sent, loads = #w.calls, #w.loading
		w.model.Drive()
		expect(#w.calls == sent and #w.loading == loads, "no remote, no loading")
		expect(w.model.Page().Message == "Equip one engine, stabilisers, and boost before driving.", "message")
		expect(w.model.IsActive() == true, "still open")
		expect(M._canDrive("e", nil, "s", "b") == true and M._canDrive(nil, "e", "s", "b") == true, "either engine")
		expect(M._canDrive(nil, nil, "s", "b") == false and M._canDrive("e", nil, "", "b") == false and M._canDrive("e", nil, "s", nil) == false, "each part needed")
	end)

	case("drive: End then SpawnVehicle {}, events, attribute, loading", function()
		local w = customise()
		local sent = #w.calls
		w.fired = {}
		w.model.Drive()
		expect(w.actions(sent + 1) == "End,SpawnVehicle", "calls: " .. w.actions(sent + 1))
		expect(next(w.last().Payload) == nil, "SpawnVehicle payload is empty")
		expect(w.firedNames() == "FreeRoamVehicleSpawned,GarageClosedFromDealershipExit", "fired: " .. w.firedNames())
		expect(w.attrs.GarageEntryMode == nil and w.model.IsActive() == false and w.model.State.Stage == "Closed", "closed")
		local begin, complete = w.loading[#w.loading - 1], w.loading[#w.loading]
		expect(begin.Action == "Begin" and begin.Payload.Destination == "FreeRoamDrive" and begin.Payload.Status == "PREPARING VEHICLE", "Begin")
		expect(complete.Action == "Complete" and complete.Payload.Generation == 7 and complete.Payload.Status == "READY TO DRIVE", "Complete")
	end)

	case("drive: End refused keeps the garage open; spawn refused closes safely; neither is retried", function()
		local w = customise()
		w.replies["Session.End"] = { Success = false, Message = "NOT NOW" }
		local sent = #w.calls
		w.model.Drive()
		expect(w.actions(sent + 1) == "End" and w.model.IsActive() == true, "End only, still open")
		expect(w.loading[#w.loading].Action == "Fail" and w.loading[#w.loading].Payload.Reason == "NOT NOW", "Fail")
		w.replies.SpawnVehicle = { Success = false, Message = "NO SPACE" }
		sent = #w.calls
		w.fired = {}
		w.model.Drive()
		expect(w.actions(sent + 1) == "End,SpawnVehicle", "one End, one Spawn")
		expect(w.model.IsActive() == false and w.attrs.GarageEntryMode == nil, "closed")
		expect(w.firedNames() == "GarageClosedFromDealershipExit", "closed event only: " .. w.firedNames())
		expect(w.loading[#w.loading].Action == "Fail" and w.loading[#w.loading].Payload.Reason == "NO SPACE", "Fail")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Guards, modals, camera, pure helpers.
	------------------------------------------------------------------------------------------------------------
	case("busy guard: a second GarageInvoke while one is in flight is refused locally", function()
		local w = customise()
		w.model.SelectItem("RearSpoiler")
		w.model.SelectItem("M:sp1")
		local inner
		w.onInvoke = function(action)
			if action == "BuyModuleInstance" then
				w.onInvoke = nil
				local sent = #w.calls
				w.model.ShowProperties()
				w.model.BuyProperty("P1")
				inner = { Sent = #w.calls - sent, Message = w.model.Page().Message }
			end
		end
		w.model.Action()
		expect(inner ~= nil and inner.Sent == 0, "the nested purchase never reached the remote")
		expect(inner.Message == "Please wait.", "busy message: " .. tostring(inner.Message))
	end)

	case("a reply that is not a table is a failure, not an error", function()
		local w = customise()
		w.model.SelectItem("RearSpoiler")
		w.model.SelectItem("M:sp1")
		w.replies.BuyModuleInstance = "nonsense"
		w.model.Action()
		expect(w.model.Page().Message == "Garage server did not respond.", "message")
		w.replies["Session.End"] = true
		w.model.Drive()
		expect(w.model.IsActive() == true and w.model.Page().Message == "Garage session did not respond.", "session reply shape")
	end)

	case("modals: cash, properties and the property purchase {PropertyId}", function()
		local w = customise()
		w.model.ShowCash()
		expect(w.model.Modal().Kind == "Cash", "cash")
		w.model.CloseModal()
		expect(w.model.Modal() == nil, "closed")
		w.model.ShowProperties()
		local row = w.model.Modal().Rows[1]
		expect(row.Id == "P1" and row.Owned == false and row.PriceAmount == 50000, "row from the catalogue")
		w.model.BuyProperty("P1")
		expect(w.last().Action == "BuyGarageProperty" and sortedKeys(w.last().Payload) == "PropertyId" and w.last().Payload.PropertyId == "P1", "call")
		expect(w.model.Modal().Kind == "Properties", "list redrawn")
		w.profile.Garage.OwnedGarageProperties.P1 = true
		w.model.ShowProperties()
		local sent = #w.calls
		w.model.BuyProperty("P1")
		expect(#w.calls == sent, "an owned property sends nothing")
	end)

	case("camera step runs only while the session is open", function()
		local w = world()
		w.model.CameraStep(0.016)
		expect(w.cameraUpdates == nil, "closed: no update")
		w.model.Open("DriveIn", nil)
		w.model.CameraStep(0.016)
		expect(w.cameraUpdates == 1, "open: one update")
	end)

	case("preview: rebuilt only when an input changed", function()
		local w = customise()
		local builds = w.builds
		w.model.SelectTab("Upgrades")
		w.model.SelectTab("Paint")
		w.model.PaintChannel("Secondary")
		w.model.SelectTab("Parts")
		expect(w.builds == builds, "tab and channel changes with the same inputs build nothing, got " .. (w.builds - builds))
		w.model.SelectItem("RearSpoiler")
		w.model.SelectItem("M:sp1")
		expect(w.builds == builds + 1, "a previewed module builds once")
		w.model.SelectItem("M:sp1")
		expect(w.builds == builds + 1, "the same module again builds nothing")
		w.model.Back()
		expect(w.builds == builds + 2, "clearing the preview builds once")
	end)

	case("pure helpers: tier, stat rows, effect text, image value", function()
		expect(M._tier("S") == "S" and M._tier(nil) == "E" and M._tier("Z") == nil, "tier")
		local rows = M._statRows({ Headline = { Speed = 83.2, Boost = 59 } }, { Headline = { Speed = 80, Boost = 61 } }, 180)
		expect(#rows == 6 and rows[1].Value == 80 and rows[1].Preview == 83, "gain")
		expect(rows[6].Id == "Boost" and rows[6].Value == 61 and rows[6].Preview == 59, "loss")
		expect(rows[2].Value == 0 and rows[2].Preview == nil, "missing value, no delta")
		expect(M._effectText({ EffectsPerLevel = {} }) == "PERFORMANCE UPGRADE", "no effect")
		expect(M._imageValue(123) == "rbxassetid://123" and M._imageValue("") == "" and M._imageValue("rbxassetid://9") == "rbxassetid://9", "image value")
	end)

	------------------------------------------------------------------------------------------------------------
	-- Last: every call observed above is in the action table, and every row of the table was exercised.
	------------------------------------------------------------------------------------------------------------
	case("actions: nothing outside the table was sent, and every row was sent", function()
		local allowed = {}
		for _, action in ipairs(M.Actions) do
			allowed[action.Remote .. "|" .. action.Action .. "|" .. sortedList(action.Keys)] = true
		end
		for key in pairs(seen) do
			expect(allowed[key] == true, "sent but not in the table: " .. key)
		end
		for key in pairs(allowed) do
			expect(seen[key] == true, "in the table but never sent by a test: " .. key)
		end
	end)

	if okData and type(Data) == "table" then
		Data._foundation = savedFoundation
	end
	return results
end
