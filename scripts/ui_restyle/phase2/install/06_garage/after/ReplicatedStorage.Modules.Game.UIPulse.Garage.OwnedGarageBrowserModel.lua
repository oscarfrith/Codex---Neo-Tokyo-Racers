-- Owns the owned-garage browser state and every call it makes (OwnedGarageInvoke, the stream-ready acknowledgement, loading transitions, the HUD presentation fire); not any GuiObject, and not the desk, the interior HUD or the server's decisions.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.OwnedGarageBrowserModel. Requires: none.
-- Logic carried from Classic UI.OwnedGarageBrowserUI lines 47-59 and 62-144; the line numbers below refer to it.

local ACCESS_TEXT = {
	Public = "Open to everyone in this server.",
	FriendsOnly = "Open to the owner's friends.",
	InviteOnly = "You are on the owner's invite list.",
}
local VISIT_ENDED = {
	OwnerLeft = "The owner left the garage. Your visit ended.",
	AccessRevoked = "The owner closed the garage to you.",
	Disabled = "Garage visits are closed right now.",
}

local Model = {}
Model.__index = Model

-- A minimal Luau signal: Connect returns {Disconnect}. The second result is the emit function, kept private to the
-- model, which calls handlers in connection order.
local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(handler)
		local connection = { Connected = true }
		function connection:Disconnect()
			connection.Connected = false
			local index = table.find(handlers, connection)
			if index then
				table.remove(handlers, index)
			end
		end
		connection._handler = handler
		table.insert(handlers, connection)
		return connection
	end
	local function emit(...)
		for _, connection in ipairs(table.clone(handlers)) do
			if connection.Connected then
				connection._handler(...)
			end
		end
	end
	return signal, emit
end

-- A reply list is an untrusted shape (API2 6.6 rule 6): keep only table rows, in order.
local function rowsOf(value)
	local result = {}
	if type(value) == "table" then
		for _, row in ipairs(value) do
			if type(row) == "table" then
				table.insert(result, row)
			end
		end
	end
	return result
end

local function bindableEvent(folder, name)
	local event = folder and folder:FindFirstChild(name)
	if event and event:IsA("BindableEvent") then
		return event
	end
	return nil
end

-- deps: {
--   Remotes = {OwnedGarageInvoke: RemoteFunction, OwnedGarageEvent: RemoteEvent},
--   Bindables = {LoadingTransitionInvoke: BindableFunction},
--   RuntimeUi: Folder (PlayerScripts.Runtime.UI; FreeRoamHudPresentationMode and ShowTopNotification are looked up
--              in it at use, as Classic lines 50 and 55 do),
--   Player: Player, Workspace: Workspace,
--   Clock: (() -> number)?, Spawn: ((() -> ()) -> ())?, Wait: ((number) -> ())?,
--   CanOpen: (() -> boolean)?   -- the controller's "the view exists" gate; nil means always
-- }
function Model.new(deps)
	assert(type(deps) == "table", "OwnedGarageBrowserModel.new needs deps")
	local self = setmetatable({}, Model)
	self._remote = deps.Remotes.OwnedGarageInvoke
	self._push = deps.Remotes.OwnedGarageEvent
	self._loadingInvoke = deps.Bindables.LoadingTransitionInvoke
	self._runtimeUi = deps.RuntimeUi
	self._player = deps.Player
	self._workspace = deps.Workspace
	self._clock = deps.Clock or os.clock
	self._spawn = deps.Spawn or task.spawn
	self._wait = deps.Wait or task.wait
	self._canOpen = deps.CanOpen

	self._state = nil -- the last successful GetState reply
	self._selected = nil -- a row of state.Properties
	self._busy = false
	self._generation = 0
	self._physicalLoadingGeneration = nil
	self._mode = "Mine"
	self._visitRows = nil
	self._selectedVisit = nil
	self._open = false
	self._replacement = nil -- {Slots = {...}} while the "garage full" choice is offered

	-- What the view draws. It changes only where Classic wrote its labels, so a status change alone never
	-- re-derives the rows (Classic `render` against `setStatus`).
	self._snapshot = {
		Open = false,
		Mode = "Mine",
		TabsVisible = false,
		Rows = {},
		SelectedKey = nil,
		Detail = { Title = "", District = "", Description = "", Capacity = "", Image = "", Facts = {} },
		Enter = { Visible = true, Enabled = true, Text = "ENTER GARAGE" },
		Status = { Text = "", Good = false, Visible = false },
		Replacement = nil,
	}
	self.Changed, self._emitChanged = newSignal()
	return self
end

function Model:Snapshot()
	return self._snapshot
end

function Model:IsOpen()
	return self._open
end

function Model:IsBusy()
	return self._busy
end

function Model:_changed(reason)
	self._emitChanged(reason)
end

-- The one remote call function (Classic `request`, line 56). Every call site below names its action literally.
function Model:_call(remote, action, payload)
	local ok, result = pcall(function()
		return remote:InvokeServer(action, payload or {})
	end)
	if ok and type(result) == "table" then
		return result
	end
	return { Success = false, Message = "Garage service unavailable." }
end

-- Classic line 55.
function Model:_presentation(active)
	local event = bindableEvent(self._runtimeUi, "FreeRoamHudPresentationMode")
	if event then
		event:Fire({ Owner = "OwnedGarageBrowser", Active = active == true, KeepTelemetry = false })
	end
end

-- Classic line 50.
function Model:_toast(text)
	local event = bindableEvent(self._runtimeUi, "ShowTopNotification")
	if event then
		event:Fire(text, 2.2)
	end
end

-- Classic line 57.
function Model:_loadingAction(action, payload)
	local loadingInvoke = self._loadingInvoke
	local ok, result = pcall(function()
		return loadingInvoke:Invoke(action, payload or {})
	end)
	if ok then
		return result
	end
	warn("[Pulse.OwnedGarageBrowserModel] Loading transition " .. tostring(action) .. " failed: " .. tostring(result))
	return nil
end

-- Classic line 58.
function Model:_beginPhysicalLoading(destination, status)
	if self._physicalLoadingGeneration then
		return
	end
	self._physicalLoadingGeneration = self:_loadingAction("Begin", { Destination = destination, Status = status })
end

-- Classic line 59.
function Model:_finishPhysicalLoading(success, message)
	local current = self._physicalLoadingGeneration
	if not current then
		return
	end
	self._physicalLoadingGeneration = nil
	self:_loadingAction(success and "Complete" or "Fail", { Generation = current, Status = success and "READY" or "RETURNING", Reason = message })
end

-- Classic line 60.
function Model:_setStatus(text, good)
	local status = self._snapshot.Status
	status.Text = tostring(text or "")
	status.Good = good == true
	status.Visible = status.Text ~= ""
	self:_changed("status")
end

-- Classic line 51.
function Model:_inVehicle()
	local character = self._player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

local function mineDetail(state, selected)
	if not selected then
		-- Classic line 65: the enter button is hidden and keeps its last text.
		return { Title = "NO GARAGES", District = "", Description = "No owned garage properties are available.", Capacity = "", Image = "", Facts = {} }, nil
	end
	local filled = tostring(selected.Filled or 0)
	local capacity = tostring(selected.Capacity or 0)
	local detail = {
		Title = string.upper(tostring(selected.DisplayName or selected.PropertyId or "")),
		District = string.upper(tostring(selected.District or "")),
		Description = tostring(selected.Description or ""),
		Capacity = filled .. " / " .. capacity .. " DISPLAY SPACES",
		Spaces = filled .. " / " .. capacity,
		Image = selected.Image or "",
		Facts = {
			{ Id = "District", Label = "DISTRICT", Value = string.upper(tostring(selected.District or "")) },
			{ Id = "Capacity", Label = "CAPACITY", Value = capacity .. " SPACES" },
			{ Id = "Filled", Label = "FILLED", Value = filled .. " / " .. capacity },
		},
	}
	local text = state and state.Visiting and "LEAVE GARAGE" or (state and state.InGarage and "RETURN TO CITY" or "ENTER GARAGE")
	return detail, { Visible = true, Enabled = true, Text = text }
end

-- Classic lines 73-78.
function Model:_visitDetail()
	local state = self._state
	local row = self._selectedVisit
	if not row then
		local loaded = self._visitRows ~= nil
		local detail = {
			Title = loaded and "NO OPEN GARAGES" or "LOADING...",
			District = "",
			Description = loaded and "Garages appear here while their owner is inside and has opened them to you." or "",
			Capacity = "",
			Image = "",
			Facts = {},
		}
		local visible = state ~= nil and state.Visiting ~= nil
		return detail, { Visible = visible, Enabled = true, Text = "LEAVE GARAGE" }
	end
	local visitors = tostring(row.VisitorCount or 0) .. " / " .. tostring(row.MaxVisitors or 0)
	local message = tostring(row.Message or "")
	local detail = {
		Title = string.upper(tostring(row.GarageName or "")),
		District = "HOSTED BY " .. string.upper(tostring(row.OwnerName or "")),
		Description = (ACCESS_TEXT[row.AccessMode] or "") .. (message ~= "" and (" " .. message) or ""),
		Capacity = visitors .. " VISITORS",
		Image = row.Image or "",
		Facts = {
			{ Id = "Host", Label = "HOST", Value = string.upper(tostring(row.OwnerName or "")) },
			{ Id = "Visitors", Label = "VISITORS", Value = visitors },
		},
	}
	local enter
	if row.Visiting then
		enter = { Visible = true, Enabled = true, Text = "LEAVE GARAGE" }
	elseif self:_inVehicle() then
		enter = { Visible = true, Enabled = false, Text = "EXIT YOUR CAR TO VISIT" }
	elseif not row.CanVisit then
		enter = { Visible = true, Enabled = false, Text = tostring(row.Message or "UNAVAILABLE") }
	else
		enter = { Visible = true, Enabled = true, Text = "VISIT" }
	end
	return detail, enter
end

-- Classic `render` (lines 69-72 and 79-85): the only place rows, detail, tabs and the enter button are derived.
function Model:_render()
	local state = self._state
	local snapshot = self._snapshot
	local tabsVisible = state ~= nil and (state.VisitsEnabled == true or state.Visiting ~= nil)
	if not tabsVisible and self._mode == "Visit" then
		self._mode = "Mine"
	end
	snapshot.TabsVisible = tabsVisible
	snapshot.Mode = self._mode

	local rows = {}
	local selectedKey = nil
	local detail, enter
	if self._mode == "Visit" then
		local selectedVisit = self._selectedVisit
		for _, row in ipairs(self._visitRows or {}) do
			local key = "Visit_" .. tostring(row.OwnerUserId)
			local isSelected = selectedVisit ~= nil and selectedVisit.OwnerUserId == row.OwnerUserId
			if isSelected then
				selectedKey = key
			end
			table.insert(rows, {
				Key = key,
				Title = string.upper(tostring(row.OwnerName or "")),
				Sub = tostring(row.VisitorCount or 0) .. "/" .. tostring(row.MaxVisitors or 0),
				Image = row.Image or "",
				Selected = isSelected,
				Muted = row.CanVisit ~= true and row.Visiting ~= true,
			})
		end
		detail, enter = self:_visitDetail()
	else
		local selected = self._selected
		for _, property in ipairs(state and state.Properties or {}) do
			local key = "Garage_" .. tostring(property.PropertyId)
			local isSelected = selected ~= nil and selected.PropertyId == property.PropertyId
			if isSelected then
				selectedKey = key
			end
			table.insert(rows, {
				Key = key,
				Title = tostring(property.DisplayName or property.PropertyId or ""),
				Sub = tostring(property.Filled or 0) .. " / " .. tostring(property.Capacity or 0) .. " SPACES FILLED",
				Image = property.Image or "",
				Selected = isSelected,
				Muted = false,
			})
		end
		detail, enter = mineDetail(state, selected)
	end
	snapshot.Rows = rows
	snapshot.SelectedKey = selectedKey
	snapshot.Detail = detail
	if enter then
		snapshot.Enter = enter
	else
		snapshot.Enter = { Visible = false, Enabled = snapshot.Enter.Enabled, Text = snapshot.Enter.Text }
	end
	self:_changed("render")
end

-- Classic `close` (line 86). Like Classic it does not ask whether the browser is open: the transition owner calls
-- it on every garage exit and the presentation fire goes out each time.
function Model:Close(_reason)
	self._generation += 1
	self._replacement = nil
	self._snapshot.Replacement = nil
	self._open = false
	self._snapshot.Open = false
	self:_presentation(false)
	self:_setStatus("")
	self:_changed("close")
end

-- Classic `refreshVisits` (line 87).
function Model:_refreshVisits()
	local token = self._generation
	self._spawn(function()
		local result = self:_call(self._remote, "GetVisitableGarages", {})
		if token ~= self._generation or self._mode ~= "Visit" then
			return
		end
		if not result.Success then
			self:_setStatus(result.Message, false)
			return
		end
		self._visitRows = rowsOf(result.Garages)
		local keep = self._selectedVisit and self._selectedVisit.OwnerUserId
		self._selectedVisit = nil
		for _, row in ipairs(self._visitRows) do
			if row.OwnerUserId == keep then
				self._selectedVisit = row
			end
		end
		self._selectedVisit = self._selectedVisit or self._visitRows[1]
		self:_render()
	end)
end

-- Classic `setMode` (line 88).
function Model:_setMode(newMode)
	self._mode = newMode
	self:_setStatus("")
	if self._mode == "Visit" then
		self._visitRows = nil
		self._selectedVisit = nil
		self:_render()
		self:_refreshVisits()
	else
		self:_render()
	end
end

-- A tab press (line 71): ignored while busy or when the mode is already shown.
function Model:SetMode(newMode)
	if newMode ~= "Mine" and newMode ~= "Visit" then
		return
	end
	if not self._busy and self._mode ~= newMode then
		self:_setMode(newMode)
	end
end

-- A list row press (lines 63, 80, 84). `key` is the row key of the snapshot.
function Model:SelectKey(key)
	if self._mode == "Visit" then
		for _, row in ipairs(self._visitRows or {}) do
			if "Visit_" .. tostring(row.OwnerUserId) == key then
				self._selectedVisit = row
				self:_render()
				return
			end
		end
	else
		local state = self._state
		for _, property in ipairs(state and state.Properties or {}) do
			if "Garage_" .. tostring(property.PropertyId) == key then
				self._selected = property
				self:_render()
				return
			end
		end
	end
end

-- Classic `visitAction` (lines 89-93).
function Model:_visitAction()
	if self._busy then
		return
	end
	local state = self._state
	local selectedVisit = self._selectedVisit
	local leaving = state ~= nil and state.Visiting ~= nil and (self._mode ~= "Visit" or not selectedVisit or selectedVisit.Visiting == true)
	if not leaving and not (self._mode == "Visit" and selectedVisit and selectedVisit.CanVisit and not self:_inVehicle()) then
		return
	end
	self._busy = true
	local loadingGeneration = self:_loadingAction("Begin", {
		Destination = leaving and "OwnedGarageExterior" or "OwnedGarageInterior",
		Status = leaving and "RETURNING TO CITY" or "VISITING GARAGE",
	})
	local result
	if leaving then
		result = self:_call(self._remote, "LeaveVisit", {})
	else
		-- Classic reads the selected row here, after the loading call returned. If it is gone (Classic would
		-- throw and stay busy) nothing is sent and the attempt is reported as failed.
		local target = self._selectedVisit
		if target then
			result = self:_call(self._remote, "VisitGarage", { OwnerUserId = target.OwnerUserId })
		else
			result = { Success = false, Message = "Garage service unavailable." }
		end
	end
	self._busy = false
	if result.Success then
		self:Close()
		self:_loadingAction("Complete", { Generation = loadingGeneration, Status = "READY" })
	else
		self:_loadingAction("Fail", { Generation = loadingGeneration, Status = "RETURNING", Reason = result.Message })
		self:_setStatus(result.Message, false)
		if self._mode == "Visit" then
			self:_refreshVisits()
		end
	end
end

-- The enter button (lines 111-118). Never retried; one request in flight (`busy`).
function Model:Enter()
	local state = self._state
	if self._mode == "Visit" or (state and state.Visiting) then
		self:_visitAction()
		return
	end
	if self._busy or not self._selected then
		return
	end
	self._busy = true
	local returning = state and state.InGarage == true
	local loadingGeneration = self:_loadingAction("Begin", {
		Destination = returning and "OwnedGarageExterior" or "OwnedGarageInterior",
		Status = returning and "RETURNING TO CITY" or "ENTERING OWNED GARAGE",
	})
	local result
	if returning then
		result = self:_call(self._remote, "ExitOnFoot", {})
	else
		local selected = self._selected
		if selected then
			result = self:_call(self._remote, "EnterSelectedGarage", { PropertyId = selected.PropertyId })
		else
			result = { Success = false, Message = "Garage service unavailable." }
		end
	end
	self._busy = false
	if result.Success then
		self:Close()
		self:_loadingAction("Complete", { Generation = loadingGeneration, Status = "READY" })
	elseif result.NeedsReplacement then
		self:_loadingAction("Fail", { Generation = loadingGeneration, Status = "SELECT A DISPLAY SPACE", Reason = result.Message })
		-- Classic `replacementPrompt` (line 94): offer the display spaces of the reply.
		self._replacement = { Slots = rowsOf(result.Slots) }
		self._snapshot.Replacement = self._replacement
		self:_changed("replacement")
	else
		self:_loadingAction("Fail", { Generation = loadingGeneration, Status = "RETURNING", Reason = result.Message })
		self:_setStatus(result.Message, false)
	end
end

-- A slot button of the "garage full" choice (lines 98-103). `index` is the position in Replacement.Slots.
function Model:ChooseReplacement(index)
	local replacement = self._replacement
	local slot = replacement and replacement.Slots[index]
	if not slot then
		return
	end
	if self._busy then
		return
	end
	self._busy = true
	local loadingGeneration = self:_loadingAction("Begin", { Destination = "OwnedGarageInterior", Status = "ENTERING OWNED GARAGE" })
	local selected = self._selected
	local replaced
	if selected then
		replaced = self:_call(self._remote, "EnterSelectedGarage", { PropertyId = selected.PropertyId, ReplacementSlotId = slot.SlotId })
	else
		replaced = { Success = false, Message = "Garage service unavailable." }
	end
	self._busy = false
	if replaced.Success then
		self:Close()
		self:_loadingAction("Complete", { Generation = loadingGeneration, Status = "READY" })
	else
		self:_loadingAction("Fail", { Generation = loadingGeneration, Status = "RETURNING", Reason = replaced.Message })
		self:_setStatus(replaced.Message, false)
	end
end

-- The Cancel button of the choice (line 105).
function Model:CancelReplacement()
	if not self._replacement then
		return
	end
	self._replacement = nil
	self._snapshot.Replacement = nil
	self:_changed("replacement")
end

-- Classic `open` (lines 107-109).
function Model:Open(propertyId)
	if self._canOpen and not self._canOpen() then
		return
	end
	local requestedPropertyId = tostring(propertyId or "")
	self._generation += 1
	local token = self._generation
	self._open = true
	self._snapshot.Open = true
	self:_presentation(true)
	if self._state then
		self:_render()
	end
	self:_setStatus(self._state and "" or "LOADING GARAGES...", true)
	self:_changed("open")
	self._spawn(function()
		local result = self:_call(self._remote, "GetState", {})
		if token ~= self._generation then
			return
		end
		if not result.Success then
			self:_setStatus(result.Message, false)
			return
		end
		result.Properties = rowsOf(result.Properties)
		self._state = result
		self._selected = nil
		local desiredPropertyId = requestedPropertyId ~= "" and requestedPropertyId or tostring(result.ActiveGarageId or "")
		for _, property in ipairs(result.Properties) do
			if property.PropertyId == desiredPropertyId then
				self._selected = property
				break
			end
		end
		self._selected = self._selected or result.Properties[1]
		self:_render()
		self:_setStatus("")
		if self._mode == "Visit" then
			self:_refreshVisits()
		end
	end)
end

-- The OpenOwnedGarageBrowser bindable (line 119).
function Model:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

-- ProximityPromptService.PromptTriggered (lines 120-128).
function Model:OnPromptTriggered(prompt, triggeringPlayer)
	local player = self._player
	if triggeringPlayer and triggeringPlayer ~= player then
		return
	end
	if not prompt then
		return
	end
	if player:GetAttribute("OwnedGarageInside") == true then
		if prompt.Name == "FootExitPrompt" then
			self:_beginPhysicalLoading("OwnedGarageExterior", "RETURNING TO CITY")
		elseif prompt.Name == "DriveOutPrompt" and player:GetAttribute("OwnedGarageVisitor") ~= true then
			self:_beginPhysicalLoading("OwnedGarageDriveOut", "PREPARING VEHICLE")
		end
	elseif prompt:GetAttribute("OwnedGarageEntryPrompt") == true and not self._open then
		self:Open(prompt:GetAttribute("OwnedGaragePropertyId"))
	end
end

-- The player's OwnedGarageInside attribute changed (line 129).
function Model:OnInsideChanged()
	if self._player:GetAttribute("OwnedGarageInside") ~= true then
		self:_finishPhysicalLoading(true, "Ready")
	end
end

-- Classic `destinationReady` (lines 130-134). Classic's WaitForChild calls there follow a FindFirstChild of the same
-- child, so they never wait; they are FindFirstChild here.
function Model:_destinationReady(message)
	local workspace = self._workspace
	if message.DestinationType == "Interior" then
		local world = workspace:FindFirstChild("World")
		local interiors = world and world:FindFirstChild("Interiors")
		local pool = interiors and interiors:FindFirstChild("OwnedGarageInstances")
		local model = pool and pool:FindFirstChild(tostring(message.InteriorName or ""))
		return model and model:FindFirstChild(tostring(message.MarkerName or "CharacterSpawn"), true) ~= nil
	end
	if message.DestinationType == "Exterior" then
		local world = workspace:FindFirstChild("World")
		local root = world and world:FindFirstChild("OwnedGarageExteriors")
		local exterior = root and root:FindFirstChild(tostring(message.ExteriorId or ""))
		return exterior and exterior:FindFirstChild(tostring(message.MarkerName or ""), true) ~= nil
	end
	return false
end

-- OwnedGarageEvent.OnClientEvent (lines 135-144). This is the one stream-ready acknowledgement of the client.
function Model:OnPush(message)
	if type(message) ~= "table" then
		return
	end
	if message.Type == "OwnedGarageStreamRequest" then
		self._spawn(function()
			local player = self._player
			local position = message.Position
			local timeout = math.clamp(tonumber(message.TimeoutSeconds) or 8, 3, 15)
			local startedAt = self._clock()
			local ok, problem = pcall(function()
				assert(typeof(position) == "Vector3", "invalid streaming position")
				player:RequestStreamAroundAsync(position, timeout)
			end)
			-- The server's deadline, not a presence poll of ours: it ends at `timeout` whatever happens.
			while ok and not self:_destinationReady(message) and self._clock() - startedAt < timeout do
				self._wait(0.05)
			end
			local ready = ok and self:_destinationReady(message)
			self._push:FireServer({
				Type = "OwnedGarageStreamReady",
				Token = tostring(message.Token or ""),
				Success = ready,
				Message = ready and "" or tostring(problem or "Destination did not replicate before the streaming deadline."),
			})
		end)
	elseif message.Type == "DriveOut" then
		self:Close()
	elseif message.Type == "DriveOutResult" then
		self:_finishPhysicalLoading(message.Success == true, message.Message)
	elseif message.Type == "FootExitResult" then
		self:_finishPhysicalLoading(message.Success == true, message.Message)
	elseif message.Type == "VisitEnded" then
		self:_toast(VISIT_ENDED[tostring(message.Reason or "")] or "Your garage visit ended.")
		self:_finishPhysicalLoading(true, "Ready")
		if self._state then
			self._state.Visiting = nil
		end
		if self._open then
			if self._mode == "Visit" then
				self:_refreshVisits()
			else
				self:_render()
			end
		end
	end
end

return Model
