-- Owns the dealership and customise session: state, page transitions, every GarageInvoke and GarageSessionRequest call, loading generations, preview and camera orchestration; it does not own any GuiObject, ScreenGui, price, Cash value or ownership decision.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageModel. Requires: Garage.GarageRoutes, Kit.Data.
--
-- A port of the Classic garage controller ("GarageUI" below = classic/sources/ReplicatedStorage.Modules.Game.Garage.
-- GarageUI.lua). Every state field, selector, transition and remote call site is carried with its Classic line in a
-- comment. What Classic handed to its two views as a context table is built here as a plain page table; the view
-- draws it and calls the intent functions at the bottom. Nothing here decides that a purchase is valid: the same
-- checks Classic makes before sending are made, and no others.
local Routes = require(script.Parent.GarageRoutes)
local Data = require(script.Parent.Parent.Kit.Data)

local Model = {}

local TEXT = Routes.Text
local LOADING = Routes.Loading

-- GarageUI L18: outcome sounds by action. L29-30 override two of them on success.
local ACTION_AUDIO_KIND = table.freeze({
	BuyCockpitInstance = "Purchase",
	BuyGarageProperty = "Purchase",
	BuyModuleInstance = "Purchase",
	BuyNeon = "Purchase",
	BuyVehicleCosmetic = "Purchase",
	EquipModuleInstance = "ModuleEquip",
	UpgradeModule = "Upgrade",
})

-- Every remote call this model can send: one row per Classic call site. tests compare it with actions.json
-- (generated from the Classic source by gen_actions.py), and gen_actions.py --check compares each call(...) line
-- below with the Classic line it cites.
local GARAGE = "Remotes.Garage.GarageInvoke"
local SESSION = "Remotes.UI.GarageSessionRequest"
Model.Actions = table.freeze({
	table.freeze({ Id = "L35.GetInitial", Remote = GARAGE, Action = "GetInitial", Keys = table.freeze({}), Line = 35 }),
	table.freeze({ Id = "L115.SetVehicleCosmeticColor", Remote = GARAGE, Action = "SetVehicleCosmeticColor", Keys = table.freeze({ "CosmeticId", "Color", "ReturnProfile" }), Line = 115 }),
	table.freeze({ Id = "L116.SetVehicleCosmeticColor", Remote = GARAGE, Action = "SetVehicleCosmeticColor", Keys = table.freeze({ "CosmeticId", "Color", "ReturnProfile" }), Line = 116 }),
	table.freeze({ Id = "L117.SetCockpitColor", Remote = GARAGE, Action = "SetCockpitColor", Keys = table.freeze({ "Channel", "Color", "Scope", "ReturnProfile" }), Line = 117 }),
	table.freeze({ Id = "L119.SetAllNeonColor", Remote = GARAGE, Action = "SetAllNeonColor", Keys = table.freeze({ "Color", "ReturnProfile" }), Line = 119 }),
	table.freeze({ Id = "L120.SetCockpitColor", Remote = GARAGE, Action = "SetCockpitColor", Keys = table.freeze({ "Channel", "Color", "Scope", "ReturnProfile" }), Line = 120 }),
	table.freeze({ Id = "L121.SetCockpitColor", Remote = GARAGE, Action = "SetCockpitColor", Keys = table.freeze({ "Channel", "Color", "Scope", "ReturnProfile" }), Line = 121 }),
	table.freeze({ Id = "L122.SetModuleColor", Remote = GARAGE, Action = "SetModuleColor", Keys = table.freeze({ "SlotId", "Channel", "Color", "ReturnProfile" }), Line = 122 }),
	table.freeze({ Id = "L174.BuyGarageProperty", Remote = GARAGE, Action = "BuyGarageProperty", Keys = table.freeze({ "PropertyId" }), Line = 174 }),
	table.freeze({ Id = "L183.End", Remote = SESSION, Action = "End", Keys = table.freeze({ "ReturnToEntry" }), Line = 183 }),
	table.freeze({ Id = "L185.SpawnVehicle", Remote = GARAGE, Action = "SpawnVehicle", Keys = table.freeze({}), Line = 185 }),
	table.freeze({ Id = "L194.SelectVehicleInstance", Remote = GARAGE, Action = "SelectVehicleInstance", Keys = table.freeze({ "VehicleId", "CockpitId" }), Line = 194 }),
	table.freeze({ Id = "L194.BuyCockpitInstance.1", Remote = GARAGE, Action = "BuyCockpitInstance", Keys = table.freeze({ "CockpitId", "CategoryId" }), Line = 194 }),
	table.freeze({ Id = "L195.End", Remote = SESSION, Action = "End", Keys = table.freeze({ "ReturnToEntry" }), Line = 195 }),
	table.freeze({ Id = "L288.EquipModuleInstance", Remote = GARAGE, Action = "EquipModuleInstance", Keys = table.freeze({ "ModuleInstanceId", "VehicleId", "SlotId", "AllowReassign" }), Line = 288 }),
	table.freeze({ Id = "L358.BuyModuleInstance", Remote = GARAGE, Action = "BuyModuleInstance", Keys = table.freeze({ "ModuleId", "VehicleId", "SlotId" }), Line = 358 }),
	table.freeze({ Id = "L437.UpgradeModule", Remote = GARAGE, Action = "UpgradeModule", Keys = table.freeze({ "SlotId", "ModuleId", "UpgradeId" }), Line = 437 }),
	table.freeze({ Id = "L558.BuyVehicleCosmetic", Remote = GARAGE, Action = "BuyVehicleCosmetic", Keys = table.freeze({ "CosmeticId" }), Line = 558 }),
	table.freeze({ Id = "L604.BuyNeon", Remote = GARAGE, Action = "BuyNeon", Keys = table.freeze({ "SlotId" }), Line = 604 }),
	table.freeze({ Id = "L678.EnsureCustomisationAccess", Remote = GARAGE, Action = "EnsureCustomisationAccess", Keys = table.freeze({}), Line = 678 }),
	table.freeze({ Id = "L684.End", Remote = SESSION, Action = "End", Keys = table.freeze({ "ReturnToEntry" }), Line = 684 }),
	table.freeze({ Id = "L689.End", Remote = SESSION, Action = "End", Keys = table.freeze({ "ReturnToEntry" }), Line = 689 }),
	table.freeze({ Id = "L691.DespawnVehicle", Remote = GARAGE, Action = "DespawnVehicle", Keys = table.freeze({}), Line = 691 }),
	table.freeze({ Id = "L691.SelectVehicleInstance.1", Remote = GARAGE, Action = "SelectVehicleInstance", Keys = table.freeze({ "VehicleId" }), Line = 691 }),
})

local HEADLINE = table.freeze({ "Speed", "Acceleration", "Handling", "Drift", "Braking", "Boost" }) -- GarageComponents L214
-- Display labels that differ from the headline key (previews r01, r03: "ACCEL"; the full word ran into its bar).
local HEADLINE_LABEL = table.freeze({ Acceleration = "ACCEL" })
local TIERS = table.freeze({ E = true, D = true, C = true, B = true, A = true, S = true })

-- GarageUI L413: display names of upgrade effects.
local FRIENDLY = table.freeze({
	TopSpeed = "TOP SPEED", EngineOutput = "ENGINE OUTPUT", Weight = "WEIGHT", LateralGrip = "LATERAL GRIP",
	SteeringResponse = "STEERING RESPONSE", HoverStability = "HOVER STABILITY", DriftControl = "DRIFT CONTROL",
	DriftGrip = "DRIFT GRIP", DriftChargeRate = "DRIFT CHARGE", BrakingForce = "BRAKING", BoostForce = "BOOST FORCE",
	BoostDuration = "BOOST DURATION", BoostRecharge = "BOOST RECHARGE", BoostRechargeDelay = "RECHARGE DELAY",
	BoostEfficiency = "BOOST EFFICIENCY", Drag = "DRAG", Downforce = "DOWNFORCE",
})

local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(handler)
		local entry = { handler }
		table.insert(handlers, entry)
		return {
			Disconnect = function()
				local index = table.find(handlers, entry)
				if index then
					table.remove(handlers, index)
				end
			end,
		}
	end
	function signal:Fire(...)
		for _, entry in ipairs(table.clone(handlers)) do
			entry[1](...)
		end
	end
	return signal
end

-- Pure. The tier letter a badge may show, or nil for a value that is not a tier (Classic drew those with a
-- default colour, GarageUI L54; the kit badge takes the six tiers only).
function Model._tier(value: any): string?
	local text = tostring(value or "E")
	return TIERS[text] and text or nil
end

-- Pure. GarageComponents L204-224 (RenderPerformance) as data: the six headline rows with the value shown and the
-- baseline it is compared with. reference is the bar's full scale (StatReference).
function Model._statRows(performance: any, baseline: any, reference: number): { any }
	local rows = {}
	for _, name in ipairs(HEADLINE) do
		local value = tonumber(performance and performance.Headline and performance.Headline[name]) or 0
		local baseValue = tonumber(baseline and baseline.Headline and baseline.Headline[name])
		local shown = math.floor(value + 0.5)
		local base = baseValue and math.floor(baseValue + 0.5) or shown
		table.insert(rows, {
			Id = name,
			Label = HEADLINE_LABEL[name] or string.upper(name),
			Value = base,
			Preview = shown ~= base and shown or nil,
			Max = reference,
		})
	end
	return rows
end

-- Pure. The Shop / Owned switch: a filter over the two row lists the shared card view model builds.
function Model._filterRows(lists: any, source: any): { any }
	return (lists and lists[source]) or {}
end

-- Pure. GarageUI L74 (coreReady) on already-resolved installed values, then L180: Drive needs one engine,
-- stabilisers and boost.
function Model._canDrive(engine1: any, engine2: any, stabilisers: any, boost: any): boolean
	local function yes(value)
		return value ~= nil and tostring(value) ~= ""
	end
	return (yes(engine1) or yes(engine2)) and yes(stabilisers) and yes(boost)
end

-- Pure. GarageUI L414-422 (effectText).
function Model._effectText(upgrade: any): string
	local bestName, bestValue = nil, nil
	for name, value in pairs(upgrade.EffectsPerLevel or {}) do
		if typeof(value) == "number" and value ~= 0 and (not bestValue or math.abs(value) > math.abs(bestValue)) then
			bestName, bestValue = name, value
		end
	end
	if not bestName then
		return "PERFORMANCE UPGRADE"
	end
	local rounded = math.abs(bestValue) >= 1 and tostring(math.floor(math.abs(bestValue) * 10 + 0.5) / 10)
		or string.format("%.2f", math.abs(bestValue))
	return (bestValue > 0 and "+" or "-") .. rounded .. " " .. tostring(FRIENDLY[bestName] or string.upper(bestName))
end

-- GarageUI L88 (imageValue).
local function imageValue(value: any): string
	local text = tostring(value or "")
	if text == "" then
		return ""
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end
Model._imageValue = imageValue

--[[ deps (every handle is passed in, so pure tests pass fakes):
	Player, Workspace
	Remotes   = { GarageInvoke, GarageSessionRequest }
	Bindables = { LoadingTransitionInvoke }                 BindableFunction
	Folders   = { UI, Dealership }                          PlayerScripts.Runtime.UI and .Dealership
	Config    = { Replacement, Artwork? }                   Config.UI.GarageReplacement and its ModuleArtwork child
	CategoriesRoot                                          ReplicatedStorage.Assets.VehiclePreviews.Categories
	Modules   = { CatalogTransport, VehicleCatalog, ModuleCards, AudioBridge, PreviewVehicle, PreviewCamera,
	              InstancePreview, PreviewProfiles, PerformanceResolver, PropertyCatalog }   shared, unchanged
	Defer     = task.defer
	Warn      = warn
]]
function Model.new(deps: any)
	assert(type(deps) == "table", "[Pulse.GarageModel] deps table expected")
	local player = deps.Player
	local workspaceRef = deps.Workspace
	local garageInvoke = deps.Remotes.GarageInvoke
	local sessionRequest = deps.Remotes.GarageSessionRequest
	local loadingInvoke = deps.Bindables.LoadingTransitionInvoke
	local uiFolder = deps.Folders.UI
	local intro = deps.Folders.Dealership
	local replacementConfig = deps.Config.Replacement
	local artworkRoot = deps.Config.Artwork
	local categoriesRoot = deps.CategoriesRoot
	local CatalogTransport = deps.Modules.CatalogTransport
	local Catalog = deps.Modules.VehicleCatalog
	local ModuleCards = deps.Modules.ModuleCards
	local AudioBridge = deps.Modules.AudioBridge
	local PreviewVehicle = deps.Modules.PreviewVehicle
	local PreviewCamera = deps.Modules.PreviewCamera
	local InstancePreview = deps.Modules.InstancePreview
	local PreviewProfiles = deps.Modules.PreviewProfiles
	local PerformanceResolver = deps.Modules.PerformanceResolver
	local PropertyCatalog = deps.Modules.PropertyCatalog
	local defer = deps.Defer or task.defer
	local warnOut = deps.Warn or warn

	-- GarageUI L44. The same fields with the same start values; fields Classic adds later (Economy, CameraSection,
	-- NoPreviewYet, PreviewUpgradeId, PreviewNeonSlot, PreviewVFXMode, SelectedPaintAction, TargetFocus and the
	-- camera fields the shared camera module writes) appear as they are assigned.
	local State: any = {
		Stage = "Closed", ShopMode = "Dealership", Catalog = nil, Profile = nil, CategoryId = "bruiser",
		BrowseAll = true, SelectedCockpit = nil, SelectedVehicleId = nil, SelectedSlot = "Engine1",
		SelectedModuleId = nil, SelectedModuleInstanceId = nil, ModuleMode = "Slots", ModuleOptionMode = nil,
		CustomizeTarget = "ALL", CustomizeMode = "Colour", SelectedColorChannel = "Primary", PreviewModules = {},
		PreviewProfile = nil, ReturnWorkshop = nil, GarageCameraActive = false,
	}

	local self: any = {}
	local changed = newSignal()
	local busy = false -- GarageUI L20 Adapter.Busy: the only double-spend guard
	local active = false -- GarageUI L45
	local preview: any = {} -- GarageUI L45
	local previewKey: string? = nil -- inputs of the last PreviewVehicle.Build
	local modal: any = nil -- GarageUI L45
	local browserVisible = false -- Classic browser.Root.Visible
	local workspaceVisible = false -- Classic workspaceUI.Root.Visible
	local authoritativeCash = 0 -- GarageBrowserUI L34
	local page: any = { Id = "Closed", Token = 0 }
	local token = 0
	local cameraContext: any = { State = State, Workspace = workspaceRef, Camera = nil, Gui = deps.CameraGui, IsDriving = false }

	local renderBrowser, renderPaint, renderHub, renderBuild, renderUpgrade, renderPaintShop
	local selectTab

	local function emit(reason: string)
		changed:Fire(reason)
	end

	local function setPage(next: any)
		token += 1
		next.Token = token
		page = next
		emit("render")
	end

	------------------------------------------------------------------------------------------------------------
	-- Remotes. One function; every call site below is one line and cites its Classic line.
	------------------------------------------------------------------------------------------------------------
	local function call(remote: string, actionName: string, payload: any): any
		if remote == "GarageSessionRequest" then
			-- GarageUI L36 (Adapter:Session). A reply that is not a table is treated as no reply.
			local ok, result = pcall(function()
				return sessionRequest:InvokeServer(actionName, payload or {})
			end)
			if ok and type(result) == "table" then
				return result
			end
			return { Success = false, Message = TEXT.SessionNoReply }
		end
		-- GarageUI L21-34 (Adapter:Call).
		local audioKind = ACTION_AUDIO_KIND[actionName]
		if busy then
			local result = { Success = false, Message = TEXT.Busy }
			if audioKind then
				AudioBridge.Result(audioKind, result, { Action = actionName })
			end
			return result
		end
		busy = true
		local ok, result = pcall(function()
			if actionName == "GetInitial" then
				return CatalogTransport.Fetch(garageInvoke, payload)
			end
			return garageInvoke:InvokeServer(actionName, payload or {})
		end)
		busy = false
		if not ok or typeof(result) ~= "table" then
			result = { Success = false, Message = TEXT.NoReply }
			if audioKind then
				AudioBridge.Result(audioKind, result, { Action = actionName })
			end
			return result
		end
		if result.Catalog then
			State.Catalog = result.Catalog
		end
		if result.Profile then
			State.Profile = result.Profile
		end
		State.Economy = Data.ProjectEconomy(result, State.Economy)
		local outcomeAudioKind = audioKind
		if result.Success == true then
			if actionName == "BuyModuleInstance" then
				outcomeAudioKind = "ModuleEquip"
			elseif actionName == "BuyCockpitInstance" then
				outcomeAudioKind = "VehiclePurchase"
			end
		end
		if outcomeAudioKind then
			AudioBridge.Result(outcomeAudioKind, result, { Action = actionName })
		end
		return result
	end

	-- GarageUI L46.
	local function loadingAction(actionName: string, payload: any): any
		local ok, result = pcall(function()
			return loadingInvoke:Invoke(actionName, payload or {})
		end)
		if ok then
			return result
		end
		warnOut("[Pulse.GarageModel] Loading transition " .. tostring(actionName) .. " failed: " .. tostring(result))
		return nil
	end

	-- GarageUI L47-52.
	local function entryLoading(mode: string, payload: any): any
		payload = typeof(payload) == "table" and payload or {}
		if payload.LoadingGeneration then
			return payload.LoadingGeneration
		end
		local destination = mode == "Dealership" and LOADING.DestinationDealership
			or (mode == "DriveIn" and LOADING.DestinationDriveIn or LOADING.DestinationCustomisation)
		return loadingAction("Begin", {
			Destination = destination,
			Status = mode == "Dealership" and LOADING.StatusEnteringDealership or LOADING.StatusEnteringCustomisation,
		})
	end

	-- GarageUI L152.
	local function fire(name: string)
		local event = uiFolder:FindFirstChild(name)
		if event and event:IsA("BindableEvent") then
			event:Fire()
		end
	end

	-- GarageUI L186, L187, L195.
	local function fireClosed()
		local event = intro:FindFirstChild("GarageClosedFromDealershipExit")
		if event and event:IsA("BindableEvent") then
			event:Fire()
		end
	end

	-- The toast half of "errors as an inline line and a toast" (API2 5.7). Same bindable Classic fires at L682.
	local function notify(text: any)
		local notification = uiFolder:FindFirstChild("ShowTopNotification")
		if notification and notification:IsA("BindableEvent") then
			notification:Fire(text)
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Config readers.
	------------------------------------------------------------------------------------------------------------
	-- GarageWorkspaceUI L41: attribute first, then a child value.
	local function workspaceNumber(name: string, fallback: number): number
		local attribute = replacementConfig:GetAttribute(name)
		if typeof(attribute) == "number" then
			return attribute
		end
		local child = replacementConfig:FindFirstChild(name)
		return tonumber(child and child.Value) or fallback
	end

	-- GarageBrowserUI L14: a child value only.
	local function browserNumber(name: string, fallback: number): number
		local child = replacementConfig:FindFirstChild(name)
		return tonumber(child and child.Value) or fallback
	end

	------------------------------------------------------------------------------------------------------------
	-- Selectors. GarageUI L55-74.
	------------------------------------------------------------------------------------------------------------
	local function allCategories()
		return (State.Catalog and State.Catalog.Categories) or {}
	end

	local function categoryById(id)
		for _, c in ipairs(allCategories()) do
			if tostring(c.CategoryId) == tostring(id) then
				return c
			end
		end
		return nil
	end

	local function currentCategory()
		return categoryById(State.CategoryId) or allCategories()[1]
	end

	-- GarageUI L59.
	local function categoryListed(c)
		local hidden = "," .. tostring(replacementConfig:GetAttribute("DealershipHiddenCategories") or "") .. ","
		if c.PurchaseDisabled ~= true and not string.find(hidden, "," .. tostring(c.CategoryId) .. ",", 1, true) then
			return true
		end
		if State.ShopMode ~= "Customisation" then
			return false
		end
		local p = State.Profile or {}
		for _, vehicle in pairs(p.Vehicles or {}) do
			local item = vehicle.CockpitInstanceId and p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]
			local id = item and tostring(item.TemplateId or "") or ""
			for _, k in ipairs(c.Cockpits or {}) do
				if id ~= "" and tostring(k.CockpitId) == id then
					return true
				end
			end
		end
		return false
	end

	local function listedCategories()
		local result = {}
		for _, c in ipairs(allCategories()) do
			if categoryListed(c) then
				table.insert(result, c)
			end
		end
		return result
	end

	-- GarageUI L61.
	local function combinedCategory()
		local c = { CategoryId = "__ALL", DisplayName = "ALL", Cockpits = {}, Slots = {} }
		for _, source in ipairs(listedCategories()) do
			for _, cockpit in ipairs(source.Cockpits or {}) do
				local copy = {}
				for k, v in pairs(cockpit) do
					copy[k] = v
				end
				copy.SourceCategoryId = source.CategoryId
				table.insert(c.Cockpits, copy)
			end
		end
		return c
	end

	-- GarageUI L62.
	local function browserCategory()
		local c = currentCategory()
		if State.BrowseAll or (c and not categoryListed(c)) then
			return combinedCategory()
		end
		return c
	end

	-- GarageUI L63.
	local function cockpit(id, category)
		for _, c in ipairs((category or currentCategory() or {}).Cockpits or {}) do
			if tostring(c.CockpitId) == tostring(id) then
				return c
			end
		end
		return nil
	end

	-- GarageUI L64.
	local function moduleById(id, category)
		for _, list in pairs(((category or currentCategory() or {}).Modules) or {}) do
			for _, m in ipairs(list) do
				if tostring(m.ModuleId) == tostring(id) then
					return m
				end
			end
		end
		return nil
	end

	-- GarageUI L65.
	local function slots()
		local result = {}
		for _, s in ipairs((currentCategory() and currentCategory().Slots) or {}) do
			table.insert(result, s)
		end
		table.sort(result, function(a, b)
			return (tonumber(a.Order) or 99) < (tonumber(b.Order) or 99)
		end)
		return result
	end

	-- GarageUI L66.
	local function slot(id)
		for _, s in ipairs(slots()) do
			if tostring(s.SlotId) == tostring(id) then
				return s
			end
		end
		return nil
	end

	-- GarageUI L67.
	local function slotLabel(s, art)
		local label = tostring(s and s.RailLabel or "")
		if label ~= "" then
			return label
		end
		return art.DisplayName
	end

	-- GarageUI L68.
	local function enginePosition(m)
		local explicit = tostring(m and m.EnginePosition or "")
		if explicit ~= "" then
			return explicit
		end
		if m and (m.RearEngine == true or m.ModuleFolder == "Engines_B" or string.find(tostring(m.ModuleId), "MODULE_ENGINE_B_", 1, true)) then
			return "Rear"
		end
		return "Front"
	end

	-- GarageUI L69.
	local function moduleFits(m, s)
		if not m or not s or tostring(m.ModuleType) ~= tostring(s.ModuleType) then
			return false
		end
		if s.SlotId == "Engine1" then
			return enginePosition(m) ~= "Rear"
		end
		if s.SlotId == "Engine2" then
			return enginePosition(m) == "Rear"
		end
		return not s.AllowedModuleFolder or s.AllowedModuleFolder == "" or tostring(m.ModuleFolder) == tostring(s.AllowedModuleFolder)
	end

	-- GarageUI L70.
	local function modulesForSlot(id)
		local s = slot(id)
		local result = {}
		if not s then
			return result
		end
		for _, m in ipairs((((currentCategory() or {}).Modules or {})[s.ModuleType]) or {}) do
			if moduleFits(m, s) then
				table.insert(result, m)
			end
		end
		table.sort(result, function(a, b)
			return tostring(a.DisplayName or a.ModuleId) < tostring(b.DisplayName or b.ModuleId)
		end)
		return result
	end

	-- GarageUI L71.
	local function ownedCockpitCount(id)
		local n = 0
		for _, item in pairs((State.Profile and State.Profile.OwnedCockpitInstances) or {}) do
			if tostring(item.TemplateId) == tostring(id) then
				n += 1
			end
		end
		return n
	end

	-- GarageUI L72.
	local function capacity()
		local g = (State.Profile and State.Profile.Garage) or {}
		return tonumber(g.OwnedVehicleCount) or 0, tonumber(g.Capacity) or 2
	end

	-- GarageUI L73.
	local function installedForSlot(id)
		local p = State.Profile or {}
		local vehicle = p.CurrentVehicleId and p.Vehicles and p.Vehicles[p.CurrentVehicleId]
		local instanceId = vehicle and vehicle.InstalledModules and vehicle.InstalledModules[id]
		local instance = instanceId and p.OwnedModuleInstances and p.OwnedModuleInstances[instanceId]
		return (instance and instance.TemplateId) or (p.InstalledModules and p.InstalledModules[id]), instanceId
	end

	-- GarageUI L74.
	local function coreReady()
		local e1 = installedForSlot("Engine1")
		local e2 = installedForSlot("Engine2")
		local s = installedForSlot("Stabilisers")
		local b = installedForSlot("Boost")
		return Model._canDrive(e1, e2, s, b)
	end

	------------------------------------------------------------------------------------------------------------
	-- Performance. GarageUI L75-87.
	------------------------------------------------------------------------------------------------------------
	local function performanceForCockpit(c)
		return PerformanceResolver.Factory(categoriesRoot, c)
	end

	local function currentPerformance()
		local instanceNow, instanceBase = InstancePreview.Performance(State, categoriesRoot)
		if instanceNow then
			return instanceNow, instanceBase
		end
		if State.Stage == "Customise" and State.CustomizeMode == "Upgrades" and State.PreviewUpgradeId then
			local moduleId, instanceId = installedForSlot(State.CustomizeTarget)
			local instance = instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
			local after, before = PerformanceResolver.UpgradePreview(categoriesRoot, State.PreviewProfile or State.Profile,
				State.CustomizeTarget, { ModuleId = moduleId }, instance, State.PreviewUpgradeId)
			if after then
				return after, before
			end
		end
		local base = PerformanceResolver.Profile(categoriesRoot, State.PreviewProfile or State.Profile)
		return base, base
	end

	local function moduleRating(module, instance)
		return PerformanceResolver.ModuleRating(categoriesRoot, module, instance)
	end

	-- GarageUI L91.
	local function variantLabel(tag)
		local map = tostring(replacementConfig:GetAttribute("VariantLabels_" .. tostring(currentCategory() and currentCategory().CategoryId)) or "")
		for from, to in string.gmatch(map, "([^=;]+)=([^;]+)") do
			if from == tostring(tag) then
				return to
			end
		end
		return tag
	end

	-- GarageUI L92-98.
	local function cockpitImage(c)
		local keys = { "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }
		for _, k in ipairs(keys) do
			local v = imageValue(c and c[k])
			if v ~= "" then
				return v
			end
		end
		local record = Catalog.Get("CockpitId", c and c.CockpitId, true)
		if record then
			for _, k in ipairs(keys) do
				local v = imageValue(record[k])
				if v ~= "" then
					return v
				end
				v = imageValue(record[k .. "ChildValue"])
				if v ~= "" then
					return v
				end
			end
		end
		return ""
	end

	-- Pulse: the name on the stat panel header. Display only; read from the catalogue the server sent.
	local function selectedVehicleName(): string
		local id = State.SelectedCockpit or (State.Profile and State.Profile.CurrentCockpit)
		for _, category in ipairs(allCategories()) do
			local found = cockpit(id, category)
			if found then
				return tostring(found.DisplayName or found.CockpitId)
			end
		end
		return tostring(id or "")
	end

	-- The stat panel as data (Classic: stats() L176 with GarageWorkspaceUI L226, or GarageBrowserUI L73-75).
	local function statsData(performance, baseline, title, emptyText, reference)
		if not performance then
			return { Empty = emptyText, Title = title, Rows = {} }
		end
		local overall = performance.Overall or {}
		return {
			Title = title,
			Sub = { TEXT.Performance },
			Tier = Model._tier(overall.Tier),
			Rating = math.floor(tonumber(overall.PerformanceIndex) or 100),
			Rows = Model._statRows(performance, baseline, reference),
		}
	end

	------------------------------------------------------------------------------------------------------------
	-- Preview and camera. GarageUI L99-136, L147-150.
	------------------------------------------------------------------------------------------------------------
	-- GarageUI L99.
	local function clearPreview()
		if preview.Root and preview.Root.Parent then
			preview.Root:Destroy()
		end
		table.clear(preview)
		previewKey = nil
		State.PreviewModules = {}
		State.GarageCameraActive = false
	end

	-- GarageUI L100-102. Runs on every tab change, slot change and after every purchase.
	local function clearTransientModulePreview()
		State.SelectedModuleId = nil
		State.SelectedModuleInstanceId = nil
		State.PreviewModules = {}
		State.PreviewUpgradeId = nil
		State.PreviewNeonSlot = nil
	end

	-- GarageUI L103-109, with the one Pulse change of programme contract 5.1 rule 9: the vehicle is rebuilt only
	-- when something PreviewVehicle.Build reads has changed. The key covers the profile it draws (every field,
	-- through the shared fingerprint Classic already computes here), the cockpit, the previewed modules and neon
	-- slot, and the selection fields the instance adapter resolves colours from.
	local function buildPreview()
		local before = InstancePreview.ProfileFingerprint(State.Profile)
		State.GarageCameraActive = true
		local shown = State.PreviewProfile or State.Profile
		local shownPrint = shown == State.Profile and before or InstancePreview.ProfileFingerprint(shown)
		local key = table.concat({
			shownPrint,
			tostring(State.SelectedCockpit),
			InstancePreview.ProfileFingerprint(State.PreviewModules),
			tostring(State.PreviewNeonSlot),
			tostring(State.SelectedSlot),
			tostring(State.SelectedModuleId),
			tostring(State.SelectedModuleInstanceId),
			tostring(State.ThrustPreviewActive),
		}, "|")
		local alive = preview.Root and preview.Root.Parent and preview.Vehicle and preview.Vehicle.Parent
		if not (alive and key == previewKey) then
			previewKey = nil
			local vehicle, err = PreviewVehicle.Build({ State = State, CategoriesRoot = categoriesRoot, Preview = preview, Workspace = workspaceRef })
			if before ~= InstancePreview.ProfileFingerprint(State.Profile) then
				error("[Module Instance Preview] Read-only invariant failed: preview mutated the client profile")
			end
			if vehicle then
				previewKey = key
			else
				warnOut("[Pulse.GarageModel] Preview: " .. tostring(err))
			end
		end
		if preview.Root then
			preview.Root:SetAttribute("PreviewVFXMode", State.PreviewVFXMode or "Idle")
		end
	end

	-- GarageUI L110.
	local function setPreviewVFXMode(mode: string)
		State.PreviewVFXMode = mode
		local root = preview.Root
		if root and root.Parent then
			root:SetAttribute("PreviewVFXMode", mode)
		end
	end

	-- GarageUI L127.
	local function section(id)
		State.CameraSection = id or "ALL"
		PreviewCamera.SetCameraSection(State, id or "ALL")
	end

	-- GarageUI L128-132. The frame step itself is self.CameraStep, bound by the client through Kit.Perf.
	local function startCamera()
		PreviewCamera.BindInput({
			State = State,
			IsActive = function()
				return active and (browserVisible or workspaceVisible)
			end,
		})
	end

	-- GarageUI L133-136.
	local function stopCamera()
		PreviewCamera.Release()
	end

	-- GarageUI L137.
	local function hideAll()
		browserVisible = false
		workspaceVisible = false
		modal = nil
	end

	-- GarageUI L147-150.
	local function closeCamera()
		stopCamera()
		clearPreview()
		local camera = workspaceRef.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		State.Catalog = nil
		State.Profile = nil
		State.PreviewProfile = nil
		State.SelectedVehicleId = nil
		State.SelectedModuleId = nil
		State.SelectedModuleInstanceId = nil
		State.PreviewUpgradeId = nil
		State.PreviewNeonSlot = nil
		State.ReturnWorkshop = nil -- a detour left open must not reach the next garage session
		State.Stage = "Closed"
	end

	-- GarageUI L153, plus the toast. Shown only while a page is up, as in Classic.
	local function message(text: any)
		if not (workspaceVisible or browserVisible) then
			return
		end
		page.Message = tostring(text)
		notify(tostring(text))
		emit("message")
	end

	------------------------------------------------------------------------------------------------------------
	-- Paint. GarageUI L111-124.
	------------------------------------------------------------------------------------------------------------
	local function handlePaint(target, channel, color, commit)
		PreviewVehicle.ApplyPaint({ State = State, Preview = preview, Target = target, Channel = channel, Color = color })
		if commit ~= true then
			return
		end
		local result
		if target == "THRUST_COLOR" then
			result = call("GarageInvoke", "SetVehicleCosmeticColor", { CosmeticId = "ThrustColour", Color = color, ReturnProfile = true }) -- GarageUI L115
		elseif target == "UNDERGLOW" then
			result = call("GarageInvoke", "SetVehicleCosmeticColor", { CosmeticId = "Underglow", Color = color, ReturnProfile = true }) -- GarageUI L116
		elseif target == "WholeVehicle" then
			result = call("GarageInvoke", "SetCockpitColor", { Channel = channel, Color = color, Scope = "WholeVehicle", ReturnProfile = true }) -- GarageUI L117
		elseif target == "ALL" then
			if channel == "Neon" then
				result = call("GarageInvoke", "SetAllNeonColor", { Color = color, ReturnProfile = true }) -- GarageUI L119
			else
				result = call("GarageInvoke", "SetCockpitColor", { Channel = channel, Color = color, Scope = "WholeVehicle", ReturnProfile = true }) -- GarageUI L120
			end
		elseif target == "Cockpit" then
			result = call("GarageInvoke", "SetCockpitColor", { Channel = channel, Color = color, Scope = "CockpitOnly", ReturnProfile = true }) -- GarageUI L121
		else
			result = call("GarageInvoke", "SetModuleColor", { SlotId = target, Channel = channel, Color = color, ReturnProfile = true }) -- GarageUI L122
		end
		if not (result and result.Success) then
			local text = result and result.Message or TEXT.ColourNotSaved
			-- ApplyPaint painted the preview directly and the profile did not change, so the key still matches:
			-- drop it to force the rebuild that restores the saved colours (Classic rebuilt always).
			previewKey = nil
			buildPreview()
			if workspaceVisible then
				message(text)
			else
				warnOut("[Pulse.GarageModel] " .. tostring(text))
			end
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Modals. GarageUI L154-175. The view draws them; the state and the one remote call are here.
	------------------------------------------------------------------------------------------------------------
	local function setModal(next: any)
		modal = next
		emit("modal")
	end

	-- GarageUI L163-170.
	local function confirmModuleMove(vehicleName, onConfirm)
		setModal({ Kind = "Move", VehicleName = tostring(vehicleName), OnConfirm = onConfirm })
	end

	-- GarageUI L171.
	local function showCash()
		setModal({ Kind = "Cash" })
	end

	-- GarageUI L172-175.
	local showProperties
	showProperties = function()
		local rows = {}
		local owned = (State.Profile and State.Profile.Garage and State.Profile.Garage.OwnedGarageProperties) or {}
		for _, property in ipairs(PropertyCatalog.List()) do
			table.insert(rows, {
				Id = tostring(property.PropertyId),
				PropertyId = property.PropertyId,
				DisplayName = tostring(property.DisplayName),
				Owned = owned[property.PropertyId] ~= nil,
				PriceAmount = property.Price or 0,
			})
		end
		setModal({ Kind = "Properties", Rows = rows })
	end

	local function buyProperty(id: string)
		if not (modal and modal.Kind == "Properties") then
			return
		end
		for _, row in ipairs(modal.Rows) do
			if row.Id == id and not row.Owned then
				local r = call("GarageInvoke", "BuyGarageProperty", { PropertyId = row.PropertyId }) -- GarageUI L174
				if not r.Success then
					message(r.Message or TEXT.PurchaseFailed)
				else
					-- The status strip reads page.Spaces, which is from the last page build.
					local owned, cap = capacity()
					if page.Spaces ~= nil then
						page.CapacityText = tostring(owned) .. "/" .. tostring(cap) .. TEXT.Spaces
						page.Spaces = tostring(owned) .. " / " .. tostring(cap)
					end
				end
				showProperties()
				return
			end
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Drive. GarageUI L179-189.
	------------------------------------------------------------------------------------------------------------
	local function closeSession()
		active = false
		hideAll()
		closeCamera()
		player:SetAttribute("GarageEntryMode", nil)
	end

	local function driveFromGarage()
		if not coreReady() then
			message(TEXT.DriveBlocked)
			return
		end
		local generation = loadingAction("Begin", { Destination = LOADING.DestinationDrive, Status = LOADING.StatusPreparing })
		clearTransientModulePreview()
		local ended = call("GarageSessionRequest", "End", { ReturnToEntry = true }) -- GarageUI L183
		if not ended or ended.Success ~= true then
			local reason = (ended and ended.Message) or TEXT.LeaveCustomisationFailed
			loadingAction("Fail", { Generation = generation, Status = LOADING.StatusReturning, Reason = reason })
			message(reason)
			return
		end
		local result = call("GarageInvoke", "SpawnVehicle", {}) -- GarageUI L185
		if not result.Success then
			local reason = result.Message or TEXT.SpawnFailed
			closeSession()
			fireClosed()
			loadingAction("Fail", { Generation = generation, Status = LOADING.StatusReturning, Reason = reason })
			warnOut("[Pulse.GarageModel] Drive exit failed safely: " .. tostring(reason))
			setPage({ Id = "Closed" })
			return
		end
		closeSession()
		fire("FreeRoamVehicleSpawned")
		fireClosed()
		loadingAction("Complete", { Generation = generation, Status = LOADING.StatusReadyToDrive })
		setPage({ Id = "Closed" })
	end

	------------------------------------------------------------------------------------------------------------
	-- Shared page parts.
	------------------------------------------------------------------------------------------------------------
	-- GarageUI L178 (common): the VFX mode write, Cash and Spaces from the last reply, stats drawn at show time.
	local function common(title: string, showStats: boolean)
		setPreviewVFXMode(State.Stage == "Customise" and State.CustomizeTarget == "THRUST_COLOR" and "ThrustColour" or "Idle")
		local owned, cap = capacity()
		local stats = nil
		if showStats then
			local now, base = currentPerformance()
			stats = statsData(now, base, selectedVehicleName(), TEXT.NoPerformance, workspaceNumber("StatReference", 180))
		end
		return {
			Title = title,
			Cash = State.Profile and State.Profile.Cash or 0,
			CapacityText = tostring(owned) .. "/" .. tostring(cap) .. TEXT.Spaces,
			Spaces = tostring(owned) .. " / " .. tostring(cap),
			Stats = stats,
			Items = {},
			Select = {},
			Act = {},
		}
	end

	-- Adds a tile and its Classic closures. item.Selected and item.Action describe the Classic popup:
	-- Action = { Text, Amount?, Kind } is set only where Classic set ActionText.
	local function addItem(c: any, item: any, onSelect: any, onAction: any, unlisted: boolean?)
		if not unlisted then
			table.insert(c.Items, item)
		end
		c.Select[item.Key] = onSelect
		c.Act[item.Key] = onAction
		if item.Selected then
			c.Selected = item.Key
			c.Action = item.Action
		end
	end

	local function tabsFor(tabId: string?)
		return { Selected = tabId, Items = Routes.Tabs }
	end

	local function finishWorkspace(c: any, pageId: string, tabId: string?)
		c.Id = pageId
		c.Tab = tabId
		c.Tabs = tabsFor(tabId)
		local key = Routes.PageKey(State, c.PaintTarget)
		local back = key and Routes.Back[key]
		c.BackKey = key
		c.Buttons = {
			Back = { Visible = back ~= nil, Disabled = back ~= nil and not back.Available },
			Drive = { Visible = pageId ~= "PostPaint" },
			Next = { Visible = pageId == "PostPaint" },
		}
		workspaceVisible = true
		setPage(c)
	end

	------------------------------------------------------------------------------------------------------------
	-- Browser (dealership, and the owned-vehicle pick in Customisation). GarageUI L190-196, GarageBrowserUI L64-72
	-- and L113-124.
	------------------------------------------------------------------------------------------------------------
	local function cockpitIdOf(profile, vehicle)
		-- GarageBrowserUI L24.
		local item = vehicle and vehicle.CockpitInstanceId and profile and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		return item and tostring(item.TemplateId or "") or ""
	end

	-- GarageBrowserUI L64-72.
	local function browserRows(category)
		local rows = {}
		local profile = State.Profile or {}
		if State.ShopMode == "Customisation" then
			for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
				local id = cockpitIdOf(profile, vehicle)
				local found = cockpit(id, category)
				if found then
					local summary = (profile.VehicleSummaries and profile.VehicleSummaries[vehicleId]) or {}
					local performance = summary
					if not summary.Headline then
						local fallback = performanceForCockpit(found)
						performance = { Overall = summary.Overall or fallback.Overall, Headline = fallback.Headline }
					end
					table.insert(rows, { VehicleId = vehicleId, CockpitId = id, Cockpit = found, Performance = performance, CategoryId = found.SourceCategoryId or State.CategoryId })
				end
			end
		else
			for _, found in ipairs((category and category.Cockpits) or {}) do
				table.insert(rows, { CockpitId = found.CockpitId, Cockpit = found, Performance = performanceForCockpit(found), CategoryId = found.SourceCategoryId or State.CategoryId })
			end
		end
		table.sort(rows, function(a, b)
			local av = tonumber(a.Performance and a.Performance.Overall and a.Performance.Overall.PerformanceIndex) or math.huge
			local bv = tonumber(b.Performance and b.Performance.Overall and b.Performance.Overall.PerformanceIndex) or math.huge
			if av ~= bv then
				return av < bv
			end
			return tostring(a.Cockpit.DisplayName or a.CockpitId) < tostring(b.Cockpit.DisplayName or b.CockpitId)
		end)
		return rows
	end

	local function rowKey(row): string
		return row.VehicleId and ("V:" .. tostring(row.VehicleId)) or ("C:" .. tostring(row.CockpitId))
	end

	-- GarageComponents L92-99: affordability of a dealership tile is replicated Cash against the catalogue price.
	local function vehicleStatus(item: any): string
		if not item.OfferPurchase then
			return "Owned"
		end
		if (tonumber(authoritativeCash) or 0) < (tonumber(item.PriceAmount) or 0) then
			return "Unaffordable"
		end
		return item.OwnedVehicle and "Owned" or "None"
	end

	-- GarageUI L193 (OnSelect).
	local function selectVehicleRow(row)
		State.SelectedCockpit = row.CockpitId
		State.SelectedVehicleId = row.VehicleId
		State.CategoryId = row.CategoryId or State.CategoryId
		State.PreviewProfile = PreviewProfiles.ForBrowser(State, row)
		State.NoPreviewYet = false
		buildPreview()
		PreviewCamera.Reset(State, State.TargetFocus, {})
		renderBrowser()
	end

	-- GarageUI L194 (OnPrimary). The two call sites are the Classic ones; nothing is checked before sending.
	local function primaryOnRow(row)
		local selectionMode = State.ShopMode
		local selectingOwned = selectionMode == "Customisation"
		local r
		if selectingOwned then
			r = call("GarageInvoke", "SelectVehicleInstance", { VehicleId = row.VehicleId, CockpitId = row.CockpitId }) -- GarageUI L194
		else
			r = call("GarageInvoke", "BuyCockpitInstance", { CockpitId = row.CockpitId, CategoryId = row.CategoryId }) -- GarageUI L194
		end
		if not r.Success then
			-- Classic wrote the browser subtitle directly (no visibility test).
			page.Message = tostring(r.Message or TEXT.SelectFailed)
			notify(page.Message)
			emit("message")
			return
		end
		State.PreviewProfile = nil
		State.SelectedCockpit = State.Profile.CurrentCockpit or row.CockpitId
		State.SelectedVehicleId = State.Profile.CurrentVehicleId
		State.ModuleMode = "Slots"
		State.CustomizeTarget = "ALL"
		State.CustomizeMode = "Overview"
		buildPreview()
		if selectingOwned then
			renderHub()
		else
			renderPaint()
		end
	end

	-- GarageUI L195 (OnExit).
	local function exitBrowser()
		local generation = loadingAction("Begin", { Destination = LOADING.DestinationExit, Status = LOADING.StatusLeaving })
		local ended = call("GarageSessionRequest", "End", { ReturnToEntry = true }) -- GarageUI L195
		if not ended or ended.Success ~= true then
			local reason = (ended and ended.Message) or TEXT.LeaveGarageFailed
			loadingAction("Fail", { Generation = generation, Status = LOADING.StatusReturning, Reason = reason })
			message(reason)
			return
		end
		closeSession()
		fireClosed()
		loadingAction("Complete", { Generation = generation, Status = LOADING.StatusReady })
		setPage({ Id = "Closed" })
	end

	renderBrowser = function()
		State.Stage = "Browser"
		setPreviewVFXMode("Idle")
		hideAll()
		local owned, cap = capacity()
		local mode = State.ShopMode
		local category = browserCategory()
		local autoPreview = State.NoPreviewYet
		browserVisible = true

		-- GarageBrowserUI L115: ALL, then the listed categories by name.
		local categories = {}
		for _, c in ipairs(listedCategories()) do
			table.insert(categories, c)
		end
		table.sort(categories, function(a, b)
			return tostring(a.DisplayName or a.CategoryId) < tostring(b.DisplayName or b.CategoryId)
		end)
		local tabItems = { { Id = "__ALL", Text = TEXT.AllCategories } }
		for _, c in ipairs(categories) do
			table.insert(tabItems, { Id = "C:" .. tostring(c.CategoryId), Text = tostring(c.DisplayName or c.CategoryId), CategoryId = c.CategoryId })
		end
		local selectedTab = "__ALL"
		if not State.BrowseAll then
			selectedTab = "C:" .. tostring(State.CategoryId)
		end

		local rows = browserRows(category)
		local selected = nil
		for _, row in ipairs(rows) do
			-- GarageBrowserUI L117.
			if (row.VehicleId and row.VehicleId == State.SelectedVehicleId) or (not row.VehicleId and row.CockpitId == State.SelectedCockpit) then
				selected = row
			end
		end
		local pending = (autoPreview or not selected) and rows[1] ~= nil
		if pending then
			selected = nil
		end

		-- GarageBrowserUI L120.
		authoritativeCash = tonumber(State.Profile.Cash) or tonumber(authoritativeCash) or 0

		local c: any = {
			Id = "Dealership",
			Mode = mode,
			Title = mode == "Customisation" and TEXT.CustomisationTitle or TEXT.DealershipTitle,
			Sub = mode == "Customisation" and TEXT.CustomisationSub or TEXT.DealershipSub,
			Cash = State.Profile.Cash,
			CapacityText = tostring(owned) .. "/" .. tostring(cap) .. TEXT.Spaces,
			Spaces = tostring(owned) .. " / " .. tostring(cap),
			Categories = { Selected = selectedTab, Items = tabItems },
			Heading = tostring((category and (category.DisplayName or category.CategoryId)) or TEXT.AllCategories),
			Items = {},
			Select = {},
			Act = {},
			Rows = {},
			Buttons = { Exit = { Visible = true } },
		}
		for _, row in ipairs(rows) do
			local overall = row.Performance and row.Performance.Overall or {}
			local key = rowKey(row)
			local ownedCount = ownedCockpitCount(row.CockpitId)
			local sourceCategory = categoryById(row.CategoryId)
			local item: any = {
				Key = key,
				Kind = "Vehicle",
				Title = tostring(row.Cockpit.DisplayName or row.CockpitId),
				Sub = sourceCategory and tostring(sourceCategory.DisplayName or sourceCategory.CategoryId) or nil,
				Image = cockpitImage(row.Cockpit),
				Tier = Model._tier(overall.Tier),
				Rating = math.floor(tonumber(overall.PerformanceIndex) or 100),
				OfferPurchase = mode == "Dealership",
				OwnedVehicle = ownedCount > 0,
				PriceAmount = mode == "Dealership" and (row.Cockpit.Price or 0) or nil,
				Selected = row == selected,
				Card = true,
			}
			item.Status = vehicleStatus(item)
			if item.Selected then
				-- GarageBrowserUI L122. The price is the catalogue value; the view formats it.
				if mode == "Customisation" then
					item.Action = { Text = TEXT.Customise, Kind = "Main" }
				else
					item.Action = { Text = ownedCount > 0 and TEXT.BuyAnother or TEXT.Buy, Amount = row.Cockpit.Price or 0, Kind = "Buy" }
				end
			end
			c.Rows[key] = row
			addItem(c, item, function()
				selectVehicleRow(row)
			end, function()
				primaryOnRow(row)
			end)
		end
		-- GarageBrowserUI L73-75.
		c.Stats = statsData(selected and selected.Performance or nil, nil,
			selected and tostring(selected.Cockpit.DisplayName or selected.CockpitId) or "", TEXT.NoVehicles,
			browserNumber("StatReference", 180))
		if pending and page.Id == "Dealership" and page.Stats then
			c.Stats = page.Stats -- Classic left the panel as it was until the first row is selected (L118)
		end
		setPage(c)

		if pending then
			-- GarageBrowserUI L118: the first row is selected on the next step, if this page is still the one shown.
			local first = rows[1]
			local mine = page
			defer(function()
				if browserVisible and page == mine then
					selectVehicleRow(first)
				end
			end)
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Post-purchase paint. GarageUI L197-200.
	------------------------------------------------------------------------------------------------------------
	renderPaint = function()
		if State.CameraSection ~= "ALL" then
			section("ALL")
		end
		State.Stage = "Paint"
		browserVisible = false
		local c = common(TEXT.PostPaintTitle, true)
		c.Sub = TEXT.PostPaintSub
		c.Paint = {
			Target = "WholeVehicle",
			Channels = { "Primary", "Secondary", "Detail" },
			Selected = State.SelectedColorChannel,
			Colours = State.Profile.CockpitColors or {},
		}
		c.OnChannel = function(channel)
			State.SelectedColorChannel = channel
			renderPaint()
		end
		c.OnColour = function(channel, color, commit)
			handlePaint("WholeVehicle", channel, color, commit)
		end
		c.OnNext = function()
			clearTransientModulePreview()
			renderHub()
		end
		c.Action = { Text = TEXT.Customise, Kind = "Main", IsNext = true }
		finishWorkspace(c, "PostPaint", nil)
	end

	------------------------------------------------------------------------------------------------------------
	-- Hub. GarageUI L201-220. Classic drew three cards; Pulse opens Routes.HubTab, which runs the closure the
	-- matching card ran (L214-216, the same statements as the workshop rail L303-305).
	------------------------------------------------------------------------------------------------------------
	renderHub = function()
		if State.CameraSection ~= "ALL" then
			section("ALL")
		end
		State.Stage = "Hub"
		browserVisible = false
		selectTab(Routes.HubTab)
	end

	selectTab = function(tabId: string)
		local tab = Routes.Tab(tabId)
		if not tab then
			return
		end
		-- A tab press (or the hub) ends an empty-slot detour: without this the record outlived the detour and the
		-- next Back, purchase or equip in Parts jumped to the old tab.
		State.ReturnWorkshop = nil
		if tab.Workshop == "Add" then
			-- GarageUI L214 / L303.
			clearTransientModulePreview()
			State.ModuleMode = "Slots"
			State.ModuleOptionMode = nil
			buildPreview()
			renderBuild()
		elseif tab.Workshop == "Upgrade" then
			-- GarageUI L215 / L304.
			clearTransientModulePreview()
			State.CustomizeMode = "Upgrades"
			local chosen = State.SelectedSlot
			if not installedForSlot(chosen) then
				for _, candidate in ipairs(slots()) do
					if installedForSlot(candidate.SlotId) then
						chosen = candidate.SlotId
						break
					end
				end
			end
			State.CustomizeTarget = chosen or "Engine1"
			renderUpgrade()
		else
			-- GarageUI L216 / L305.
			clearTransientModulePreview()
			State.CustomizeTarget = "ALL"
			State.CustomizeMode = "Colour"
			State.SelectedPaintAction = nil
			State.SelectedColorChannel = "Primary"
			renderPaintShop()
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Parts (Classic "Add Modules"). GarageUI L239-378.
	------------------------------------------------------------------------------------------------------------
	-- GarageUI L222-237.
	local function moduleLineage(m)
		local category = currentCategory() or {}
		local categoryDisplay = tostring(category.DisplayName or category.CategoryId or "Vehicle")
		local categoryName = string.upper(categoryDisplay)
		local function fullName(name)
			name = tostring(name or "")
			if name == "" then
				return categoryDisplay .. " Vehicle"
			end
			if string.find(string.lower(name), string.lower(categoryDisplay), 1, true) == 1 then
				return name
			end
			return categoryDisplay .. " " .. name
		end
		local direct = tostring(m and m.SourceCockpitDisplayName or "")
		if direct ~= "" then
			return categoryName, fullName(direct)
		end
		local sourceId = tostring(m and m.SourceCockpitId or "")
		local source = sourceId ~= "" and cockpit(sourceId, category) or nil
		return categoryName, fullName(source and (source.DisplayName or source.CockpitId) or (sourceId ~= "" and sourceId or "Vehicle"))
	end

	-- GarageUI L239-245.
	local function ownedModuleCount(moduleId)
		local count = 0
		for _, item in pairs(State.Profile.OwnedModuleInstances or {}) do
			if tostring(item.TemplateId) == tostring(moduleId) then
				count += 1
			end
		end
		return count
	end

	-- GarageUI L247-255.
	local function vehicleDisplayName(vehicleId)
		local p = State.Profile or {}
		local vehicle = p.Vehicles and p.Vehicles[vehicleId]
		if not vehicle then
			return TEXT.AnotherVehicle
		end
		local owned = p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local category = categoryById(vehicle.CategoryId or State.CategoryId)
		local source = owned and cockpit(owned.TemplateId, category)
		return tostring(source and (source.DisplayName or source.CockpitId) or TEXT.AnotherVehicle)
	end

	-- GarageUI L257-260.
	local function sourceVehicleName(m)
		local _, name = moduleLineage(m)
		return tostring(name)
	end

	-- GarageUI L262-267.
	local function sourceVehicleRating(m)
		local category = currentCategory()
		local source = m and cockpit(m.SourceCockpitId, category)
		local value = source and performanceForCockpit(source)
		return math.floor(tonumber(value and value.Overall and value.Overall.PerformanceIndex) or 0)
	end

	-- GarageUI L269-273 and L349: the Owned row list, built by the shared view model, unchanged.
	local function compatibleOwnedRows(slotId)
		local s = slot(slotId)
		if not s then
			return {}
		end
		local _, installedInstance = installedForSlot(slotId)
		return ModuleCards.Owned({
			Instances = State.Profile.OwnedModuleInstances, Slot = s, ResolveModule = moduleById, Fits = moduleFits,
			CurrentVehicleId = State.Profile.CurrentVehicleId, InstalledInstanceId = installedInstance,
			VehicleName = vehicleDisplayName, SourceVehicleName = sourceVehicleName, Rating = moduleRating,
		})
	end

	-- GarageUI L355: the Shop row list, built by the shared view model, unchanged.
	local function shopRows(slotId)
		return ModuleCards.Shop({
			Modules = modulesForSlot(slotId),
			IsLocked = function(m)
				local source = tostring(m.SourceCockpitId or "")
				return source ~= "" and ownedCockpitCount(source) == 0
			end,
			SourceVehicleName = sourceVehicleName, SourceRating = sourceVehicleRating, OwnedCount = ownedModuleCount,
			Rating = moduleRating,
		})
	end

	-- GarageUI L274-279.
	local function returnFromModuleRoute()
		local route = State.ReturnWorkshop
		State.ReturnWorkshop = nil
		if not route then
			State.ModuleMode = "Slots"
			State.ModuleOptionMode = nil
			renderBuild()
			return
		end
		State.CustomizeTarget = route.Target
		if route.Workshop == "Upgrade" then
			State.CustomizeMode = "Upgrades"
			renderUpgrade()
		else
			State.CustomizeMode = "Overview"
			renderPaintShop()
		end
	end

	-- GarageUI L280-282: the empty-slot detour from Upgrades or Paint to Parts.
	local function routeToAddModule(slotId, workshop)
		clearTransientModulePreview()
		State.ReturnWorkshop = { Target = slotId, Workshop = workshop }
		State.SelectedSlot = slotId
		State.ModuleMode = "Sources"
		State.ModuleOptionMode = nil
		section(slotId)
		renderBuild()
	end

	-- GarageUI L283-286.
	local function missingModuleCard(c, target, workshop)
		local owned = #compatibleOwnedRows(target) > 0
		addItem(c, {
			Key = "__MODULE_UNLOCK", Kind = "Unlock", Title = owned and TEXT.EquipToUnlock or TEXT.BuyToUnlock,
			Icon = "plus", Status = "None", Card = true,
		}, function()
			routeToAddModule(target, workshop)
		end, nil)
	end

	-- GarageUI L287-299.
	local function equipInstance(row, allowReassign)
		local r = call("GarageInvoke", "EquipModuleInstance", { ModuleInstanceId = row.Id, VehicleId = State.Profile.CurrentVehicleId, SlotId = State.SelectedSlot, AllowReassign = allowReassign == true }) -- GarageUI L288
		if r.Success then
			State.ModuleMode = "Slots"
			State.SelectedModuleId = nil
			State.SelectedModuleInstanceId = nil
			State.PreviewModules = {}
			buildPreview()
			if State.ReturnWorkshop then
				returnFromModuleRoute()
			else
				renderBuild()
			end
		else
			message(r.Message or TEXT.NoReply)
		end
	end

	-- GarageUI L343 (Owned) and L344 (Buy): the two cards of the Classic "Sources" page, now the Shop / Owned switch.
	local function chooseSource(source: string)
		clearTransientModulePreview()
		State.ModuleMode = "Options"
		State.ModuleOptionMode = source
		renderBuild()
	end

	local function ratingOf(row): number?
		return row.Rating > 0 and row.Rating or nil
	end

	renderBuild = function()
		if State.ModuleMode == "Slots" and State.CameraSection ~= "ALL" then
			section("ALL")
		end
		State.Stage = "Build"
		browserVisible = false

		if State.ModuleMode == "Sources" then
			-- Classic drew "Owned Modules" (locked when there are none, L342) and "Buy Modules" here. Pulse has no
			-- such page: Routes.SourceDefault picks the card, and its closure runs.
			local rule = State.ReturnWorkshop and Routes.SourceDefault.Detour or Routes.SourceDefault.Slot
			local source = "Buy"
			if rule == "Owned" or rule == "OwnedIfAny" then
				source = #compatibleOwnedRows(State.SelectedSlot) > 0 and "Owned" or "Buy"
			end
			chooseSource(source)
			return
		end

		local c = common(TEXT.CustomiseTitle, true)
		c.TutorialPageId = "AddModules"
		c.Sub = State.ModuleMode == "Slots" and TEXT.PartsSlotsSub or TEXT.PartsOptionsSub
		c.Mode = State.ModuleMode
		local categoryId = currentCategory() and currentCategory().CategoryId
		if State.ModuleMode == "Slots" then
			c.Heading = TEXT.PartsHeading
			for _, art in ipairs(Routes.ArtworkForPage(artworkRoot, "Build", categoryId)) do
				local s = slot(art.TargetId)
				if s then
					local installed = installedForSlot(s.SlotId)
					-- GarageUI L337.
					addItem(c, {
						Key = tostring(s.SlotId), Kind = "Slot", SlotId = s.SlotId, Title = slotLabel(s, art), Image = art.Image,
						Status = installed and "Fitted" or "None",
						ChipRight = installed and TEXT.Equipped or TEXT.Empty,
						ChipRightKind = installed and "Tick" or "Pink",
						Card = true,
					}, function()
						clearTransientModulePreview()
						State.SelectedSlot = s.SlotId
						State.ModuleMode = "Sources"
						State.ModuleOptionMode = nil
						section(s.SlotId)
						renderBuild()
					end, nil)
				end
			end
		else
			local s = slot(State.SelectedSlot)
			local ownedRows = compatibleOwnedRows(State.SelectedSlot)
			local lists = { Owned = {}, Buy = {} }
			c.Heading = tostring(s and s.RailLabel ~= nil and tostring(s.RailLabel) ~= "" and s.RailLabel or State.SelectedSlot)
			for _, art in ipairs(Routes.ArtworkForPage(artworkRoot, "Build", categoryId)) do
				if s and art.TargetId == tostring(s.SlotId) then
					c.Heading = slotLabel(s, art)
				end
			end
			c.Source = { Selected = State.ModuleOptionMode, Items = Routes.Sources, OwnedLocked = #ownedRows == 0 }

			-- GarageUI L350-353. Built for both sources; only the selected source's rows carry closures.
			local ownedMode = State.ModuleOptionMode == "Owned"
			for _, row in ipairs(ownedRows) do
				local selected = ownedMode and State.SelectedModuleInstanceId == row.Id
				local item = {
					Key = "I:" .. row.Id, Kind = "Module", Title = tostring(row.Title), Sub = row.Status,
					ChipLeft = variantLabel(row.Tag), Rating = ratingOf(row),
					Status = row.State == "Equipped" and "Fitted" or "Owned",
					ChipRight = row.State == "Equipped" and TEXT.Equipped or (row.State == "InUse" and TEXT.InUse or nil),
					ChipRightKind = row.State == "Equipped" and "Tick" or "Neutral",
					RowState = row.State, Selected = selected, Card = true,
					Action = selected and row.State ~= "Equipped" and { Text = TEXT.Equip, Kind = "Main" } or nil,
				}
				table.insert(lists.Owned, item)
				if ownedMode then
					addItem(c, item, function()
						State.SelectedModuleId = row.Module.ModuleId
						State.SelectedModuleInstanceId = row.Id
						State.PreviewModules = { [State.SelectedSlot] = row.Module.ModuleId }
						buildPreview()
						renderBuild()
					end, function()
						if row.State == "InUse" then
							confirmModuleMove(vehicleDisplayName(row.OwnerVehicleId), function()
								equipInstance(row, true)
							end)
						else
							equipInstance(row, false)
						end
					end, true)
				end
			end
			-- GarageUI L355-359. No client affordability here: the server decides.
			for _, row in ipairs(shopRows(State.SelectedSlot)) do
				local selected = not ownedMode and State.SelectedModuleId == row.Id
				local item = {
					Key = "M:" .. row.Id, Kind = "Module", Title = tostring(row.Title), Sub = row.Status,
					ChipLeft = variantLabel(row.Tag), Rating = ratingOf(row), PriceAmount = row.Price,
					Status = row.Locked and "Locked" or "None", Selectable = true,
					RowState = row.State, Selected = selected, Card = true,
					Action = selected and not row.Locked and { Text = TEXT.Buy, Amount = row.Price, Kind = "Buy" } or nil,
				}
				table.insert(lists.Buy, item)
				if not ownedMode then
					addItem(c, item, function()
						State.SelectedModuleId = row.Id
						State.SelectedModuleInstanceId = nil
						State.PreviewModules = { [State.SelectedSlot] = row.Id }
						buildPreview()
						renderBuild()
					end, function()
						local buy = call("GarageInvoke", "BuyModuleInstance", { ModuleId = row.Id, VehicleId = State.Profile.CurrentVehicleId, SlotId = State.SelectedSlot }) -- GarageUI L358
						if not buy.Success then
							message(buy.Message or TEXT.PurchaseFailed)
							return
						end
						clearTransientModulePreview()
						State.ModuleMode = "Slots"
						State.ModuleOptionMode = nil
						buildPreview()
						if State.ReturnWorkshop then
							returnFromModuleRoute()
						else
							renderBuild()
						end
						message(TEXT.ModuleBought)
					end, true)
				end
			end
			c.Lists = lists
			c.Items = Model._filterRows(lists, State.ModuleOptionMode)
		end
		finishWorkspace(c, "Parts", "Parts")
	end

	------------------------------------------------------------------------------------------------------------
	-- Upgrades. GarageUI L380-481.
	------------------------------------------------------------------------------------------------------------
	-- GarageUI L380-383.
	local function installedModuleFor(target)
		local id, instanceId = installedForSlot(target)
		return id, moduleById(id), instanceId
	end

	-- GarageUI L385-393: the Classic left rail of slots, now the options of one picker.
	local function slotPicker(c, selected, onSelect)
		local options = {}
		c.Pick = {}
		local categoryId = currentCategory() and currentCategory().CategoryId
		for _, art in ipairs(Routes.ArtworkForPage(artworkRoot, "Build", categoryId)) do
			local s = slot(art.TargetId)
			if s then
				local installed = installedForSlot(s.SlotId)
				local id = tostring(s.SlotId)
				table.insert(options, { Id = id, Text = slotLabel(s, art), Muted = not installed })
				c.Pick[id] = function()
					onSelect(s.SlotId)
				end
			end
		end
		c.Picker = { Label = TEXT.ModulePicker, Options = options, Selected = tostring(selected) }
	end

	-- GarageUI L395-439.
	local function addUpgradeCards(c, target)
		local moduleId, m, instanceId = installedModuleFor(target)
		if not moduleId then
			missingModuleCard(c, target, "Upgrade")
			return
		end
		local upgrades = (m and m.Upgrades) or {}
		local instance = instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
		local allocation = (instance and instance.V2UpgradePoints) or ((State.Profile.ModuleUpgradeLevels or {})[moduleId] or {})
		local template = PerformanceResolver.FindModule(categoriesRoot, { ModuleId = moduleId })
		local budgetCapacity = math.max(0, math.floor(tonumber(template and template.UpgradePointCapacity) or 0))
		local used = 0
		for _, points in pairs(allocation) do
			used += math.max(0, math.floor(tonumber(points) or 0))
		end
		used = math.min(used, budgetCapacity)
		c.Budget = { Label = TEXT.UpgradePoints, Used = used, Capacity = budgetCapacity }
		if #upgrades == 0 then
			c.EmptyMessage = TEXT.UpgradeDataMissing
			warnOut("[Pulse.GarageModel] Missing upgrade catalogue paths for " .. tostring(moduleId))
			return
		end
		for _, u in ipairs(upgrades) do
			local level = math.clamp(math.floor(tonumber(allocation[u.UpgradeId]) or 0), 0, tonumber(u.MaxLevel) or 3)
			local max = tonumber(u.MaxLevel) or 3
			local selected = State.PreviewUpgradeId == u.UpgradeId
			local maxed = level >= max
			local budgetFull = used >= budgetCapacity
			local available = not maxed and not budgetFull
			local pointCost = PerformanceResolver.UpgradeCost(categoriesRoot, { ModuleId = moduleId }, instance, u.UpgradeId)
			local price = math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0)
			local footer = (maxed or budgetFull) and "" or Model._effectText(u)
			local semantic = (maxed or level > 0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade")
			addItem(c, {
				Key = tostring(u.UpgradeId), Kind = "Upgrade", Title = tostring(u.DisplayName or u.UpgradeId),
				ChipLeft = TEXT.Level .. tostring(level), Level = level, MaxLevel = max,
				PriceText = maxed and TEXT.MaxLevel or (budgetFull and TEXT.LimitReached or nil),
				PriceAmount = available and price or nil,
				Sub = footer ~= "" and footer or nil,
				RowState = semantic,
				Status = semantic == "Invested" and "Fitted" or (semantic == "Unavailable" and "Locked" or "None"),
				Selectable = true, Selected = selected, Card = true,
				Action = selected and available and { Text = TEXT.Upgrade, Amount = price, Kind = "Buy" } or nil,
			}, function()
				State.PreviewUpgradeId = u.UpgradeId
				renderUpgrade()
			end, function()
				local r = call("GarageInvoke", "UpgradeModule", { SlotId = target, ModuleId = moduleId, UpgradeId = u.UpgradeId }) -- GarageUI L437
				State.PreviewUpgradeId = nil
				-- Redrawn on a refusal too: the preview id is cleared, so the card must lose its selection, its stat
				-- preview and the enabled Upgrade button.
				renderUpgrade()
				if not r.Success then
					message(r.Message or TEXT.PurchaseFailed)
				end
			end)
		end
	end

	renderUpgrade = function()
		State.Stage = "Customise"
		State.CustomizeMode = "Upgrades"
		local target = State.CustomizeTarget
		if not slot(target) then
			local candidates = slots()
			target = candidates[1] and candidates[1].SlotId or "Engine1"
			State.CustomizeTarget = target
		end
		if State.CameraSection ~= target then
			section(target)
		end
		browserVisible = false
		local c = common(TEXT.CustomiseTitle, true)
		c.TutorialPageId = "UpgradeModules"
		c.Sub = TEXT.UpgradesSub
		slotPicker(c, target, function(id)
			-- GarageUI L469-475.
			clearTransientModulePreview()
			State.CustomizeTarget = id
			State.CustomizeMode = "Upgrades"
			section(id)
			renderUpgrade()
		end)
		c.Heading = tostring(target)
		for _, option in ipairs(c.Picker.Options) do
			if option.Id == tostring(target) then
				c.Heading = option.Text
			end
		end
		addUpgradeCards(c, target)
		buildPreview() -- GarageUI L479; a no-op unless the preview inputs changed
		finishWorkspace(c, "Upgrades", "Upgrades")
	end

	------------------------------------------------------------------------------------------------------------
	-- Paint. GarageUI L483-673.
	------------------------------------------------------------------------------------------------------------
	-- GarageUI L483-491.
	local function paintChannels(target)
		if target == "THRUST_COLOR" then
			return { "ThrustColor" }
		end
		if target == "UNDERGLOW" then
			return { "Underglow" }
		end
		if target == "Cockpit" then
			return { "Primary", "Secondary", "Detail", "FrontLights", "RearLights" }
		end
		if target == "ALL" then
			return { "Primary", "Secondary", "Detail", "Neon" }
		end
		local result = { "Primary", "Secondary", "Detail" }
		if State.Profile.NeonOwned and State.Profile.NeonOwned[target] == true then
			table.insert(result, "Neon")
		end
		return result
	end

	-- GarageUI L510-526. A channel with no saved colour is left out; the view starts it at white (Classic L523).
	local function paintColours(target, channels)
		local colours = {}
		for _, channel in ipairs(channels) do
			local value
			if target == "THRUST_COLOR" then
				value = State.Profile.ThrustColor
			elseif target == "UNDERGLOW" then
				local vehicle = State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]
				value = vehicle and vehicle.Cosmetics and vehicle.Cosmetics.Colours and vehicle.Cosmetics.Colours.Underglow
			elseif target == "Cockpit" or target == "ALL" then
				value = (State.Profile.CockpitColors or {})[channel]
			else
				value = ((State.Profile.ModuleColors or {})[target] or {})[channel]
			end
			if typeof(value) == "Color3" then
				colours[channel] = value
			end
		end
		return colours
	end

	-- GarageUI L528-533.
	local function currentCosmetics()
		local vehicle = State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]
		return vehicle and vehicle.Cosmetics
	end

	local function cosmeticOwned(id)
		local cosmetics = currentCosmetics()
		return cosmetics and cosmetics.Unlocks and cosmetics.Unlocks[id] == true
	end

	local function cosmeticDefinition(id)
		for _, item in ipairs((State.Catalog and State.Catalog.VehicleCosmetics) or {}) do
			if item.CosmeticId == id then
				return item
			end
		end
		return nil
	end

	-- GarageUI L534-539.
	local function modeForPaintTarget(id)
		if id == "ALL" or id == "Cockpit" then
			return "Colour"
		end
		if id == "THRUST_COLOR" then
			return cosmeticOwned("ThrustColour") and "Colour" or "Overview"
		end
		if id == "UNDERGLOW" then
			return cosmeticOwned("Underglow") and "Colour" or "Overview"
		end
		return "Overview"
	end

	-- GarageUI L540-552: the Classic left rail of paint targets, now the options of one picker.
	local function paintPicker(c, target)
		local options = {}
		c.Pick = {}
		local categoryId = currentCategory() and currentCategory().CategoryId
		for _, art in ipairs(Routes.ArtworkForPage(artworkRoot, "Customise", categoryId)) do
			local id = art.TargetId
			local special = id == "ALL" or id == "Cockpit" or id == "THRUST_COLOR"
			local physical = slot(id) ~= nil
			if special or physical then
				table.insert(options, {
					Id = id,
					Text = id == "THRUST_COLOR" and TEXT.Thrust or slotLabel(slot(id), art),
					Muted = physical and not installedForSlot(id),
				})
				c.Pick[id] = function()
					clearTransientModulePreview()
					State.CustomizeTarget = id
					State.CustomizeMode = modeForPaintTarget(id)
					State.SelectedPaintAction = nil
					local channels = paintChannels(id)
					State.SelectedColorChannel = channels[1]
					if physical then
						section(id)
					else
						section("ALL")
					end
					renderPaintShop()
				end
				if id == "THRUST_COLOR" then
					table.insert(options, { Id = "UNDERGLOW", Text = TEXT.Underglow, Muted = false })
					c.Pick.UNDERGLOW = function()
						clearTransientModulePreview()
						State.CustomizeTarget = "UNDERGLOW"
						State.CustomizeMode = modeForPaintTarget("UNDERGLOW")
						State.SelectedPaintAction = nil
						State.SelectedColorChannel = "Underglow"
						section("ALL")
						renderPaintShop()
					end
				end
			end
		end
		c.Picker = { Label = TEXT.AreaPicker, Options = options, Selected = tostring(target) }
	end

	-- GarageUI L554-561. Affordability is Profile.Cash from the last reply against the catalogue price (L556);
	-- it only mutes the price. BUY is sent whatever it says, as in Classic.
	local function addCosmeticPurchaseCard(c, target, id)
		local definition = cosmeticDefinition(id)
		if not definition or definition.Available == false then
			c.EmptyMessage = TEXT.CosmeticUnavailable
			return
		end
		local price = math.max(0, math.floor(tonumber(definition.Price) or 0))
		local affordable = (tonumber(State.Profile.Cash) or 0) >= price
		local selected = State.SelectedPaintAction == id
		addItem(c, {
			Key = tostring(id), Kind = "Action", Title = tostring(definition.DisplayName), Image = imageValue(definition.Icon),
			PriceAmount = price, Status = affordable and "None" or "Unaffordable", Selected = selected, Card = true,
			Action = selected and { Text = TEXT.Buy, Amount = price, Kind = "Buy" } or nil,
		}, function()
			State.SelectedPaintAction = id
			renderPaintShop()
		end, function()
			local result = call("GarageInvoke", "BuyVehicleCosmetic", { CosmeticId = id }) -- GarageUI L558
			State.SelectedPaintAction = nil
			if result and result.Success then
				State.CustomizeMode = "Colour"
				local channels = paintChannels(target)
				State.SelectedColorChannel = channels[1]
				buildPreview()
				renderPaintShop()
			else
				renderPaintShop()
				message(result and result.Message or TEXT.PurchaseFailed)
			end
		end)
	end

	-- GarageUI L563-617.
	local function addPaintOverviewCards(c, target)
		local physical = slot(target) ~= nil
		if physical and not installedForSlot(target) then
			missingModuleCard(c, target, "Paint")
			return
		end
		if target == "THRUST_COLOR" then
			addCosmeticPurchaseCard(c, target, "ThrustColour")
			return
		end
		if target == "UNDERGLOW" then
			addCosmeticPurchaseCard(c, target, "Underglow")
			return
		end
		addItem(c, {
			Key = "Paint", Kind = "Action", Title = TEXT.Paint, Icon = "paint",
			Image = imageValue(replacementConfig:GetAttribute("ModuleColourIcon")), Status = "None", Card = true,
		}, function()
			State.SelectedPaintAction = nil
			State.PreviewNeonSlot = nil
			State.CustomizeMode = "Colour"
			local channels = paintChannels(target)
			State.SelectedColorChannel = channels[1]
			renderPaintShop()
		end, nil)
		if not physical then
			return
		end
		local _, module = installedModuleFor(target)
		local available = module and module.NeonAvailable == true
		local owned = State.Profile.NeonOwned and State.Profile.NeonOwned[target] == true
		local price = math.max(0, math.floor(tonumber(module and module.NeonPrice) or 5000))
		local selected = State.SelectedPaintAction == "Neon"
		local neonImage = imageValue(replacementConfig:GetAttribute("ModuleNeonIcon"))
		if not available then
			addItem(c, {
				Key = "Neon", Kind = "Action", Title = TEXT.NeonLights, Sub = TEXT.NeonUnavailable, Image = neonImage,
				Status = "Locked", Selectable = false, RowState = "Unavailable", Card = true,
			}, nil, nil)
			return
		end
		local affordable = (tonumber(State.Profile.Cash) or 0) >= price
		addItem(c, {
			Key = "Neon", Kind = "Action", Title = TEXT.NeonLights, Image = neonImage,
			ChipRight = owned and TEXT.Owned or nil, ChipRightKind = "Neutral",
			PriceAmount = not owned and price or nil,
			Status = owned and "Owned" or (affordable and "None" or "Unaffordable"),
			Selected = selected, Card = true,
			Action = selected and (owned and { Text = TEXT.Customise, Kind = "Main" } or { Text = TEXT.Buy, Amount = price, Kind = "Buy" }) or nil,
		}, function()
			State.SelectedPaintAction = "Neon"
			State.PreviewNeonSlot = not owned and target or nil
			renderPaintShop()
		end, function()
			if owned then
				State.PreviewNeonSlot = nil
				State.SelectedPaintAction = nil
				State.CustomizeMode = "Colour"
				State.SelectedColorChannel = "Neon"
				renderPaintShop()
				return
			end
			local r = call("GarageInvoke", "BuyNeon", { SlotId = target }) -- GarageUI L604
			State.PreviewNeonSlot = nil
			State.SelectedPaintAction = nil
			if r.Success then
				State.CustomizeMode = "Colour"
				State.SelectedColorChannel = "Neon"
				renderPaintShop()
			else
				renderPaintShop()
				message(r.Message or TEXT.PurchaseFailed)
			end
		end)
	end

	renderPaintShop = function()
		State.Stage = "Customise"
		local target = State.CustomizeTarget or "ALL"
		if target ~= "ALL" and target ~= "Cockpit" and target ~= "THRUST_COLOR" and target ~= "UNDERGLOW" and not slot(target) then
			target = "ALL"
			State.CustomizeTarget = target
		end
		if slot(target) and State.CameraSection ~= target then
			section(target)
		elseif not slot(target) and State.CameraSection ~= "ALL" then
			section("ALL")
		end
		browserVisible = false
		setPreviewVFXMode(target == "THRUST_COLOR" and "ThrustColour" or "Idle")
		local c = common(TEXT.CustomiseTitle, false) -- GarageUI L631: no stat panel in the paint shop
		c.TutorialPageId = "PaintShop"
		c.Sub = State.CustomizeMode == "Colour" and TEXT.PaintColourSub or TEXT.PaintOverviewSub
		c.Mode = State.CustomizeMode
		c.PaintTarget = target
		paintPicker(c, target)
		c.Heading = tostring(target)
		for _, option in ipairs(c.Picker.Options) do
			if option.Id == tostring(target) then
				c.Heading = option.Text
			end
		end
		if State.CustomizeMode == "Colour" then
			local channels = paintChannels(target)
			local selected = State.SelectedColorChannel
			local valid = false
			for _, channel in ipairs(channels) do
				if channel == selected then
					valid = true
					break
				end
			end
			if not valid then
				selected = channels[1]
				State.SelectedColorChannel = selected
			end
			c.Paint = { Target = target, Channels = channels, Selected = selected, Colours = paintColours(target, channels) }
			c.OnChannel = function(channel)
				State.SelectedColorChannel = channel
				renderPaintShop()
			end
			c.OnColour = function(channel, color, commit)
				handlePaint(target, channel, color, commit)
			end
		else
			addPaintOverviewCards(c, target)
		end
		buildPreview() -- GarageUI L671; a no-op unless the preview inputs changed
		finishWorkspace(c, "Paint", "Paint")
	end

	------------------------------------------------------------------------------------------------------------
	-- Back. The steps come from Routes.Back; each step is the Classic statement list it names.
	------------------------------------------------------------------------------------------------------------
	local BACK_STEPS = {
		-- GarageUI L364-368. Classic then drew the Sources page; Pulse runs the next step instead.
		OptionsToSources = function()
			State.ModuleMode = "Sources"
			State.ModuleOptionMode = nil
			buildPreview()
		end,
		-- GarageUI L369-370.
		SourcesBack = function()
			if State.ReturnWorkshop then
				returnFromModuleRoute()
			else
				State.ModuleMode = "Slots"
				buildPreview()
				renderBuild()
			end
		end,
		-- GarageUI L372-373, L477, L664, L666-667.
		Hub = function()
			buildPreview()
			renderHub()
		end,
		-- GarageUI L664.
		PaintOverview = function()
			State.CustomizeMode = "Overview"
			renderPaintShop()
		end,
	}

	local function back()
		if not workspaceVisible then
			return
		end
		-- The paint Back reads the target captured when the page was drawn (GarageUI L621, L664).
		local key = Routes.PageKey(State, page.PaintTarget)
		local route = key and Routes.Back[key]
		if not route or not route.Available then
			return
		end
		for index, step in ipairs(route.Steps) do
			-- GarageUI L363, L477, L661: every Classic OnBack starts by clearing the transient preview.
			clearTransientModulePreview()
			if index == 1 and State.Stage == "Customise" and State.CustomizeMode ~= "Upgrades" then
				State.SelectedPaintAction = nil -- GarageUI L662
			end
			BACK_STEPS[step]()
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Entry. GarageUI L674-694.
	------------------------------------------------------------------------------------------------------------
	local function open(mode: string, payload: any)
		if active then
			if typeof(payload) == "table" and payload.LoadingGeneration then
				loadingAction("Complete", { Generation = payload.LoadingGeneration, Status = LOADING.StatusReady })
			end
			return
		end
		local generation
		if mode ~= "Dealership" then
			local access = call("GarageInvoke", "EnsureCustomisationAccess", {}) -- GarageUI L678
			if not access.Success then
				local reason = tostring(access.Message or TEXT.AccessUnavailable)
				notify(reason)
				if reason == TEXT.OwnVehicleReason then
					AudioBridge.Emit("UI.PurchaseRejected", { Reason = "VehicleRequired", Route = "CustomisationShortcut" })
				end
				call("GarageSessionRequest", "End", { ReturnToEntry = true }) -- GarageUI L684
				player:SetAttribute("GarageEntryMode", nil)
				return
			end
		end
		generation = entryLoading(mode, payload)
		local result = call("GarageInvoke", "GetInitial", {}) -- GarageUI L35
		if not result.Success then
			local reason = tostring(result.Message or TEXT.DataUnavailable)
			warnOut("[Pulse.GarageModel] " .. reason)
			call("GarageSessionRequest", "End", { ReturnToEntry = true }) -- GarageUI L689
			player:SetAttribute("GarageEntryMode", nil)
			loadingAction("Fail", { Generation = generation, Status = LOADING.StatusReturning, Reason = reason })
			return
		end
		active = true
		State.ShopMode = mode == "Dealership" and "Dealership" or "Customisation"
		State.CategoryId = State.Profile.CurrentCategory or (allCategories()[1] and allCategories()[1].CategoryId) or "bruiser"
		State.SelectedCockpit = State.Profile.CurrentCockpit
		if State.ShopMode == "Dealership" and currentCategory() and not categoryListed(currentCategory()) then
			State.SelectedCockpit = nil
		end
		State.SelectedVehicleId = nil
		State.BrowseAll = true
		State.NoPreviewYet = true
		State.GarageCameraActive = true
		startCamera()
		if mode == "DriveIn" then
			local vehicleId = State.Profile.CurrentVehicleId
			call("GarageInvoke", "DespawnVehicle", {}) -- GarageUI L691
			fire("FreeRoamVehicleExited")
			if vehicleId then
				call("GarageInvoke", "SelectVehicleInstance", { VehicleId = vehicleId }) -- GarageUI L691
			end
			State.SelectedVehicleId = State.Profile.CurrentVehicleId
			State.SelectedCockpit = State.Profile.CurrentCockpit
			State.NoPreviewYet = false
			buildPreview()
			renderHub()
		else
			renderBrowser()
		end
		loadingAction("Complete", { Generation = generation, Status = LOADING.StatusReady })
	end

	------------------------------------------------------------------------------------------------------------
	-- Public surface.
	------------------------------------------------------------------------------------------------------------
	self.Changed = changed
	self.State = State

	-- The page as it was last drawn. Views read it; they never write it.
	function self.Page(): any
		return page
	end

	function self.Modal(): any
		return modal
	end

	function self.IsActive(): boolean
		return active
	end

	-- Which Classic root would be showing: "Browser", "Workspace" or nil.
	function self.Showing(): string?
		return browserVisible and "Browser" or (workspaceVisible and "Workspace" or nil)
	end

	function self.AuthoritativeCash(): number
		return authoritativeCash
	end

	-- GarageUI L695-696: the three entry events call this with "Dealership", "Customisation" or "DriveIn".
	function self.Open(mode: string, payload: any)
		open(mode, payload)
	end

	-- GarageUI L131: the frame step of the preview camera. No lookups here; the client binds it through Kit.Perf.
	function self.CameraStep(dt: number)
		if active and State.GarageCameraActive then
			cameraContext.Camera = workspaceRef.CurrentCamera
			PreviewCamera.Update(cameraContext, dt)
		end
	end

	-- GarageBrowserUI L34: replicated Cash moved. Only the dealership tiles' muted-price state follows it.
	function self.SetReplicatedCash(value: any)
		authoritativeCash = tonumber(value) or 0
		if not (browserVisible and page.Id == "Dealership") then
			return
		end
		local moved = false
		for _, item in ipairs(page.Items) do
			local status = vehicleStatus(item)
			if status ~= item.Status then
				item.Status = status
				moved = true
			end
		end
		if moved then
			emit("cash")
		end
	end

	-- Dealership.
	function self.SelectCategory(tabId: string)
		if not (browserVisible and page.Id == "Dealership") then
			return
		end
		-- GarageUI L192 (OnCategory).
		local all = tabId == "__ALL"
		local id = nil
		for _, item in ipairs(page.Categories.Items) do
			if item.Id == tabId then
				id = item.CategoryId
			end
		end
		if not all and id == nil then
			return
		end
		State.BrowseAll = all == true
		if id then
			State.CategoryId = id
		end
		State.SelectedVehicleId = nil
		State.PreviewProfile = nil
		State.NoPreviewYet = true
		renderBrowser()
	end

	function self.Exit()
		if browserVisible and page.Id == "Dealership" then
			exitBrowser()
		end
	end

	-- Pulse only (no Classic line): the way out when the screen cannot be drawn. The client calls it after a render
	-- fault, when there is no Exit or Drive button to press. It runs the Exit sequence unchanged (GarageUI L195:
	-- loading Begin, session End, close, GarageClosedFromDealershipExit, loading Complete) from any page. When the
	-- server refuses or does not answer End, the client still closes its own side, as Classic does at L684 and L689
	-- where it ignores the End reply because it has no page to stay on. Sends nothing while no session is active.
	-- Returns true when a session was closed.
	function self.Abort(text: any): boolean
		if not active then
			return false
		end
		exitBrowser()
		if active then
			closeSession()
			fireClosed()
			setPage({ Id = "Closed" })
		end
		notify(tostring(text or TEXT.GarageUnavailable))
		return true
	end

	-- A tile was pressed (every page).
	function self.SelectItem(key: string)
		local handler = page.Select and page.Select[key]
		if handler then
			handler()
		end
	end

	-- The main button was pressed: the Classic popup action of the selected tile, or Next on post-purchase paint.
	-- A dealership BUY first asks for confirmation (preview c15); nothing is sent until the player says yes.
	function self.Action()
		local action = page.Action
		if not action then
			return
		end
		if action.IsNext then
			page.OnNext()
			return
		end
		local key = page.Selected
		local handler = key and page.Act and page.Act[key]
		if not handler then
			return
		end
		if page.Id == "Dealership" and page.Mode == "Dealership" then
			local row = page.Rows[key]
			setModal({
				Kind = "BuyVehicle",
				VehicleName = tostring(row.Cockpit.DisplayName or row.CockpitId),
				PriceAmount = row.Cockpit.Price or 0,
				OnConfirm = handler,
			})
			return
		end
		handler()
	end

	function self.SelectTab(tabId: string)
		if workspaceVisible and page.Tab ~= nil and Routes.Tab(tabId) then
			selectTab(tabId)
		end
	end

	function self.SelectSource(source: string)
		if not (workspaceVisible and page.Id == "Parts" and page.Source) then
			return
		end
		if source == "Owned" then
			if page.Source.OwnedLocked then
				return -- GarageUI L342: the Owned card is locked while the slot has no compatible owned module
			end
		elseif source ~= "Buy" then
			return
		end
		-- The switch is drawn on the Options page only, so a press is Classic's Back from Options (GarageUI
		-- L363-367: clear the transient preview, then buildPreview at L367) followed by the source card (L343 or
		-- L344). Without the rebuild the 3D vehicle kept a previewed, unbought module after the switch.
		clearTransientModulePreview() -- GarageUI L363
		buildPreview() -- GarageUI L367
		chooseSource(source) -- GarageUI L343 (Owned), L344 (Buy)
	end

	function self.SelectPicker(id: string)
		local handler = workspaceVisible and page.Pick and page.Pick[id]
		if handler then
			handler()
		end
	end

	function self.Back()
		back()
	end

	function self.Drive()
		if workspaceVisible and page.Buttons and page.Buttons.Drive and page.Buttons.Drive.Visible then
			driveFromGarage()
		end
	end

	function self.PaintChannel(channel: string)
		if workspaceVisible and page.OnChannel then
			page.OnChannel(channel)
		end
	end

	-- commit = true on slider release or a swatch press (GarageWorkspaceUI L276, L284); only then is a remote sent.
	function self.PaintColour(channel: string, color: any, commit: boolean)
		if workspaceVisible and page.OnColour then
			page.OnColour(channel, color, commit == true)
		end
	end

	function self.ShowCash()
		if active then
			showCash()
		end
	end

	function self.ShowProperties()
		if active and State.Profile then
			showProperties()
		end
	end

	function self.BuyProperty(id: string)
		buyProperty(id)
	end

	function self.CloseModal()
		if modal then
			setModal(nil)
		end
	end

	-- YES or NO on a confirmation (GarageUI L168-169): the modal goes first, then the confirmed step runs.
	function self.ResolveModal(confirmed: boolean)
		local current = modal
		if not current then
			return
		end
		setModal(nil)
		if confirmed and current.OnConfirm then
			current.OnConfirm()
		end
	end

	return self
end

return Model
