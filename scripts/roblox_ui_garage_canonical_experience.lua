-- Neo Tokyo Racers - Canonical Dealership / Customisation Experience
-- Consolidated install + static audit. Run once in Studio Edit mode.
-- NTR_GARAGE_CANONICAL_EXPERIENCE_V1

local MODE = "INSTALL" -- INSTALL or AUDIT

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local MARKER = "NTR_GARAGE_CANONICAL_EXPERIENCE_V1"
local function need(parent, name, className)
	local value = parent and parent:FindFirstChild(name)
	assert(value and (not className or value:IsA(className)), "Missing " .. tostring(name))
	return value
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local clientRoot = need(StarterPlayer.StarterPlayerScripts, "NeoTokyoRacersClient", "Folder")
local controllers = need(clientRoot, "Controllers", "Folder")
local intro = need(controllers, "Intro", "Folder")
local uiControllers = need(controllers, "UI", "Folder")
local bootstrap = need(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript")
local services = need(need(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder")
local garageServices = need(services, "Garage", "Folder")
local oldSession = garageServices:FindFirstChild("GarageSessionService_Active") or need(garageServices, "DriveInCustomisationSessionService_Active", "Script")
local garageAction = need(garageServices, "GarageActionController_Shadow_Disabled", "Script")
local oldOnFoot = need(intro, "CockpitCustomisationZoneClient_Active", "LocalScript")
local oldDriveIn = need(intro, "DriveInCustomisationZoneClient_Active", "LocalScript")
local introClient = need(intro, "DealershipIntroClient_Active", "LocalScript")

local requiredMarkers = {
	"NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE11_SORTED_COCKPIT_CARDS",
	"NTR_DRIVE_IN_CUSTOMISATION_PHASE3_UNLOCK_BEFORE_SPAWN",
	"NTR_DEALERSHIP_INTRO_PHASE3_GATE_BEGIN",
}
for _, marker in ipairs(requiredMarkers) do
	assert(string.find(bootstrap.Source, marker, 1, true), "Bootstrap preflight failed: " .. marker)
end
assert(string.find(oldSession.Source, "NTR_DRIVE_IN_CUSTOMISATION_PHASE2_SESSION_SERVICE", 1, true) or string.find(oldSession.Source, MARKER, 1, true), "Unknown session service source")
assert(string.find(oldOnFoot.Source, "Cockpit Customisation Zone Client", 1, true), "Unknown on-foot customisation source")
assert(string.find(oldDriveIn.Source, "NTR_DRIVE_IN_CUSTOMISATION_PHASE3_COUNTDOWN_ONLY_PROMPT", 1, true), "Unknown drive-in source")
assert(string.find(garageAction.Source, "local function V84_buyCockpitInstance", 1, true), "Unknown garage action controller source")

local function countPlain(text, needle)
	local count, cursor = 0, 1
	while true do
		local startAt, endAt = string.find(text, needle, cursor, true)
		if not startAt then return count end
		count += 1; cursor = endAt + 1
	end
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_ALL_CATEGORY", 1, true) then
	assert(countPlain(bootstrap.Source, "local function getCategory()\n\tfor _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do") == 1, "All-category resolver preflight failed")
	assert(countPlain(bootstrap.Source, "\tfor _, category in ipairs(sortedCategories) do\n\t\tlocal b = pooledButton(categoryPool, category.DisplayName or category.CategoryId") == 1, "All-category button preflight failed")
	assert(countPlain(bootstrap.Source, "\t\t\tState.CategoryId = category.CategoryId\n\t\t\tState.SelectedVehicleId = nil") == 1, "Category selection preflight failed")
	assert(countPlain(bootstrap.Source, "local aPrice = tonumber(a and a.Price) or math.huge") == 1, "Dealership sort preflight failed")
	assert(countPlain(bootstrap.Source, "\t\t\tcockpitPool:Connect(card, card.MouseButton1Click, function()\n\t\t\t\tState.SelectedCockpit = cockpit.CockpitId") == 1, "Ownership card preflight failed")
	assert(countPlain(bootstrap.Source, "callServer(\"BuyCockpitInstance\", { CockpitId = State.SelectedCockpit })") == 1, "Dealership purchase preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_OWNED_STARTS_AT_PAINT", 1, true) then
	assert(countPlain(bootstrap.Source, "setCameraSection(State.SelectedSlot or \"Engine1\")\n\t\t\t\tshowStage(\"ModuleShop\")\n\t\t\t\trenderModuleShop()") == 1, "Owned-flow preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_DRIVE_STARTS_AT_PAINT", 1, true) then
	assert(countPlain(bootstrap.Source, "showStage(\"ModuleShop\")\n\t\trenderModuleShop()\n\tend)\nend\n-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END") == 1, "Drive-in flow preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_VEHICLE_CARD_METADATA", 1, true) then
	assert(countPlain(bootstrap.Source, "local card = pooledButton(cockpitPool, \"\", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), row.VehicleId == State.SelectedVehicleId and Theme.CardHot or Theme.Card)") == 1, "Owned vehicle-card preflight failed")
	assert(countPlain(bootstrap.Source, "local card = pooledButton(cockpitPool, \"\", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)") == 1, "Dealership vehicle-card preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_STAT_COLUMNS", 1, true)
	and not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_LAYOUT_V3", 1, true) then
	assert(countPlain(bootstrap.Source, "function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)") == 1, "Stat-column function preflight failed")
	assert(countPlain(bootstrap.Source, "function NTRVehiclePhaseAO.formatRaw(variableName, value)") == 1, "Stat-column end preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_OWNER", 1, true) then
	assert(countPlain(bootstrap.Source, "applyDealershipLayout = function()") == 1, "Bottom-carousel layout start preflight failed")
	assert(countPlain(bootstrap.Source, "makeArrowScroller(UI.CockpitGridPanel, UI.CockpitGrid, \"Y\", 296)") == 1, "Bottom-carousel arrow owner preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_EARLY_CAMERA", 1, true) then
	assert(countPlain(bootstrap.Source, "if not State or State.NoPreviewYet == true or State.Phase5PreviewOrbitInitialized == true then") == 1, "Early garage-camera guard preflight failed")
	assert(countPlain(bootstrap.Source, "State.NoPreviewYet = true\n\tState.GarageCameraActive = false") == 1, "Initial garage-camera state preflight failed")
	assert(countPlain(bootstrap.Source, "State.GarageCameraActive = false\n\t\t\t\tState.NoPreviewYet = true") == 1, "Re-entry garage-camera state preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_COCKPIT_CAMERA", 1, true) then
	assert(countPlain(bootstrap.Source, "local cameraPoint = cameraFolder and cameraFolder:FindFirstChild(\"GaragePreviewCameraPoint\")") == 1, "Cockpit-edit camera preflight failed")
	assert(countPlain(bootstrap.Source, "State.TargetDistance = distance") == 1, "Cockpit-edit distance preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_ASCENDING_RATING", 1, true) then
	local descendingCount = countPlain(bootstrap.Source, "return aRating > bRating")
	local canonicalAlreadyInstalled = string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_ALL_CATEGORY", 1, true) ~= nil
	assert(descendingCount == (canonicalAlreadyInstalled and 2 or 1), "Ascending-rating sort preflight failed")
end
if not string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_LEFTMOST_PREVIEW", 1, true) then
	assert(countPlain(bootstrap.Source, "\t\tfor index, row in ipairs(rows) do") == 1, "Owned leftmost-preview preflight failed")
	assert(countPlain(bootstrap.Source, "\n\t\tfor _, cockpit in ipairs(sortedCockpits) do") == 1, "Dealership leftmost-preview preflight failed")
end
if not string.find(garageAction.Source, "NTR_GARAGE_CANONICAL_CATEGORY_PURCHASE", 1, true) then
	assert(countPlain(garageAction.Source, "\t\targs = typeof(args) == \"table\" and args or {}\n\t\tlocal cockpitId = tostring(args.CockpitId or \"\")\n\t\tlocal cockpit = V56_findCockpit(profile.CurrentCategory, cockpitId)") == 1, "Server purchase preflight failed")
end

local function ensure(parent, className, name)
	local value = parent:FindFirstChild(name)
	if value and not value:IsA(className) then value:Destroy(); value = nil end
	if not value then value = Instance.new(className); value.Name = name; value.Parent = parent end
	return value
end
local function setValue(parent, className, name, value)
	local object = parent:FindFirstChild(name)
	local created = false
	if object and not object:IsA(className) then object:Destroy(); object = nil end
	if not object then object = Instance.new(className); object.Name = name; object.Parent = parent; created = true end
	if created then object.Value = value; object:SetAttribute("NTRDefault", true) end
	return object
end

local configRoot = ensure(ensure(kit, "Folder", "Config"), "Folder", "UI")
local config = ensure(configRoot, "Folder", "GarageExperience")
setValue(config, "Color3Value", "PanelDeep", Color3.fromRGB(9, 12, 16))
setValue(config, "Color3Value", "Panel", Color3.fromRGB(15, 19, 24))
setValue(config, "Color3Value", "PanelSoft", Color3.fromRGB(27, 33, 41))
setValue(config, "Color3Value", "Structure", Color3.fromRGB(236, 92, 168))
setValue(config, "Color3Value", "Selected", Color3.fromRGB(49, 220, 255))
setValue(config, "Color3Value", "Purchase", Color3.fromRGB(51, 132, 255))
setValue(config, "Color3Value", "Text", Color3.fromRGB(244, 247, 252))
setValue(config, "Color3Value", "Muted", Color3.fromRGB(163, 171, 184))
setValue(config, "Color3Value", "Danger", Color3.fromRGB(190, 53, 68))
setValue(config, "NumberValue", "BaseWidth", 1600)
setValue(config, "NumberValue", "BaseHeight", 900)
setValue(config, "NumberValue", "MinScale", 0.68)
setValue(config, "NumberValue", "MobileMinScale", 0.42)
setValue(config, "NumberValue", "MaxScale", 1.02)
local carouselHeightValue = setValue(config, "NumberValue", "CarouselHeight", 156)
if carouselHeightValue:GetAttribute("NTRDefault") == true and carouselHeightValue.Value == 142 then carouselHeightValue.Value = 156 end
if carouselHeightValue:GetAttribute("NTRDefault") == true and carouselHeightValue.Value == 156 then carouselHeightValue.Value = 174 end
local categoryWidthValue = setValue(config, "NumberValue", "CategoryWidth", 224)
if categoryWidthValue:GetAttribute("NTRDefault") == true and categoryWidthValue.Value == 196 then categoryWidthValue.Value = 224 end
local statsWidthValue = setValue(config, "NumberValue", "StatsWidth", 336)
if statsWidthValue:GetAttribute("NTRDefault") == true and statsWidthValue.Value == 276 then statsWidthValue.Value = 336 end
if statsWidthValue:GetAttribute("NTRDefault") == true and statsWidthValue.Value == 336 then statsWidthValue.Value = 360 end
setValue(config, "NumberValue", "Margin", 18)
setValue(config, "NumberValue", "Gap", 14)
setValue(config, "NumberValue", "CategoryCarouselGap", 26)
setValue(config, "NumberValue", "HeaderWidth", 440)
setValue(config, "NumberValue", "HeaderHeight", 64)
local statsHeightValue = setValue(config, "NumberValue", "StatsHeight", 308)
if statsHeightValue:GetAttribute("NTRDefault") == true and (statsHeightValue.Value == 338 or statsHeightValue.Value == 300) then statsHeightValue.Value = 308 end
setValue(config, "NumberValue", "EconomyChipHeight", 58)
local cardWidthValue = setValue(config, "NumberValue", "CarouselCardWidth", 240)
if cardWidthValue:GetAttribute("NTRDefault") == true and cardWidthValue.Value == 204 then cardWidthValue.Value = 240 end
local cardHeightValue = setValue(config, "NumberValue", "CarouselCardHeight", 154)
if cardHeightValue:GetAttribute("NTRDefault") == true and cardHeightValue.Value == 132 then cardHeightValue.Value = 154 end
setValue(config, "NumberValue", "CarouselArrowWidth", 30)
setValue(config, "NumberValue", "StatBarReference", 180)
setValue(config, "NumberValue", "PromptDistance", 14)
setValue(config, "StringValue", "FontFamily", "rbxasset://fonts/families/Michroma.json")

local diagrams = ensure(config, "Folder", "ModuleDiagrams")
local slots = { "Engine1", "Engine2", "Stabilisers", "Boost", "FrontBumper", "RearBumper", "RearSpoiler", "SidePods" }
local labels = { Engine1="FRONT ENGINE", Engine2="REAR ENGINE", Stabilisers="STABILISERS", Boost="BOOST", FrontBumper="FRONT BUMPER", RearBumper="REAR BUMPER", RearSpoiler="REAR SPOILER", SidePods="SIDE PODS" }
local bruiser = ensure(diagrams, "Folder", "BRUISER")
for _, slotId in ipairs(slots) do
	local folder = ensure(bruiser, "Folder", slotId)
	setValue(folder, "StringValue", "Image", "")
	setValue(folder, "StringValue", "Label", labels[slotId] or string.upper(slotId))
end

local serverSource = [==[
-- NTR_GARAGE_CANONICAL_EXPERIENCE_V1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local remotes = kit:WaitForChild("Shared"):WaitForChild("Remotes")
local uiRemotes = remotes:FindFirstChild("UI") or Instance.new("Folder")
uiRemotes.Name = "UI"; uiRemotes.Parent = remotes
local request = uiRemotes:FindFirstChild("GarageSessionRequest") or Instance.new("RemoteFunction")
request.Name = "GarageSessionRequest"; request.Parent = uiRemotes
local legacy = uiRemotes:FindFirstChild("DriveInCustomisationSession") or Instance.new("RemoteEvent")
legacy.Name = "DriveInCustomisationSession"; legacy.Parent = uiRemotes

local sessions = {}
local function worldParts()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	local intro = dealership and dealership:FindFirstChild("Intro")
	local desk = intro and intro:FindFirstChild("Desk")
	local custom = dealership and dealership:FindFirstChild("Customisation")
	return {
		Dealership = desk and desk:FindFirstChild("GarageDeskTrigger"),
		Customisation = custom and custom:FindFirstChild("CustomisationDeskTrigger"),
		DriveIn = custom and custom:FindFirstChild("DriveInCustomisationTrigger"),
		Hold = custom and custom:FindFirstChild("DriveInCustomisationPlayerHoldPoint"),
	}
end
local function character(player)
	local model = player.Character
	return model, model and model:FindFirstChildOfClass("Humanoid"), model and model:FindFirstChild("HumanoidRootPart")
end
local function saveVisuals(model)
	local values = {}
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			values[object] = { object.Transparency, object.CanCollide, object.CanTouch, object.CanQuery }
			object.Transparency = 1; object.CanCollide = false; object.CanTouch = false; object.CanQuery = false
		elseif object:IsA("Decal") or object:IsA("Texture") then
			values[object] = { object.Transparency }; object.Transparency = 1
		elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then
			values[object] = { object.Enabled }; object.Enabled = false
		end
	end
	return values
end
local function restoreVisuals(values)
	for object, value in pairs(values or {}) do
		if object.Parent then
			if object:IsA("BasePart") then object.Transparency=value[1]; object.CanCollide=value[2]; object.CanTouch=value[3]; object.CanQuery=value[4]
			elseif object:IsA("Decal") or object:IsA("Texture") then object.Transparency=value[1]
			elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then object.Enabled=value[1] end
		end
	end
end
local function finish(player, returnToEntry)
	local state = sessions[player]
	local _, humanoid, root = character(player)
	if state then
		restoreVisuals(state.Visuals)
		if humanoid then humanoid.WalkSpeed=state.WalkSpeed; humanoid.JumpPower=state.JumpPower; humanoid.JumpHeight=state.JumpHeight; humanoid.AutoRotate=state.AutoRotate end
		if root then root.Anchored=state.RootAnchored; if returnToEntry and state.ReturnCFrame then root.CFrame=state.ReturnCFrame end end
	end
	sessions[player] = nil
	player:SetAttribute("NTR_GarageSessionActive", false)
	player:SetAttribute("NTR_GarageSessionMode", nil)
	player:SetAttribute("NTR_DriveInCustomisationActive", false)
	return { Success=true }
end
local function begin(player, mode)
	if sessions[player] then return { Success=false, Message="A garage session is already active." } end
	if player:GetAttribute("NTR_RaceQueueActive") == true or player:GetAttribute("NTR_RaceSessionActive") == true then return { Success=false, Message="Leave the race session first." } end
	local model, humanoid, root = character(player)
	if not model or not humanoid or not root then return { Success=false, Message="Character is not ready." } end
	local parts = worldParts(); local trigger = parts[mode]
	if not trigger or not trigger:IsA("BasePart") then return { Success=false, Message="Garage entrance is unavailable." } end
	local distancePoint = root.Position
	if mode == "DriveIn" and humanoid.SeatPart then distancePoint = humanoid.SeatPart.Position end
	if (distancePoint-trigger.Position).Magnitude > math.max(20, trigger.Size.Magnitude*0.7) then return { Success=false, Message="Move closer to the entrance." } end
	if mode == "DriveIn" and not humanoid.SeatPart then return { Success=false, Message="Drive your vehicle into the bay first." } end
	sessions[player] = { ReturnCFrame=root.CFrame, WalkSpeed=humanoid.WalkSpeed, JumpPower=humanoid.JumpPower, JumpHeight=humanoid.JumpHeight, AutoRotate=humanoid.AutoRotate, RootAnchored=root.Anchored }
	humanoid.Sit=false; humanoid.WalkSpeed=0; humanoid.JumpPower=0; humanoid.JumpHeight=0; humanoid.AutoRotate=false
	if parts.Hold and parts.Hold:IsA("BasePart") then root.CFrame=parts.Hold.CFrame+Vector3.new(0,3,0) end
	root.Anchored=true; sessions[player].Visuals=saveVisuals(model)
	player:SetAttribute("NTR_GarageSessionActive", true); player:SetAttribute("NTR_GarageSessionMode", mode)
	player:SetAttribute("NTR_DriveInCustomisationActive", mode == "DriveIn")
	return { Success=true, Mode=mode }
end
request.OnServerInvoke = function(player, action, payload)
	payload = typeof(payload)=="table" and payload or {}
	if action=="Begin" then return begin(player, tostring(payload.Mode or "Dealership")) end
	if action=="End" then return finish(player, payload.ReturnToEntry==true) end
	if action=="State" then return { Success=true, Active=sessions[player]~=nil, Mode=player:GetAttribute("NTR_GarageSessionMode") } end
	return { Success=false, Message="Unknown garage session action." }
end
legacy.OnServerEvent:Connect(function(player, locked) if locked~=true then finish(player, false) end end)
Players.PlayerRemoving:Connect(function(player) sessions[player]=nil end)
Players.PlayerAdded:Connect(function(player) player.CharacterAdded:Connect(function() if sessions[player] then task.defer(function() finish(player, false) end) end end) end)
]==]

local entranceSource = [==[
-- NTR_GARAGE_CANONICAL_EXPERIENCE_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local request=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("GarageSessionRequest")
local cfg=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageExperience")
local function c(name, fallback) local v=cfg:FindFirstChild(name); return v and v:IsA("Color3Value") and v.Value or fallback end
local function n(name, fallback) local v=cfg:FindFirstChild(name); return v and v:IsA("NumberValue") and v.Value or fallback end
local function paths()
	local dealer=Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("Dealership")
	local intro=dealer:WaitForChild("Intro"); local custom=dealer:WaitForChild("Customisation")
	return {
		{Mode="Dealership", Part=intro:WaitForChild("Desk"):WaitForChild("GarageDeskTrigger"), Event="OpenGarageFromIntro", Label="ENTER DEALERSHIP"},
		{Mode="Customisation", Part=custom:WaitForChild("CustomisationDeskTrigger"), Event="OpenOwnedCockpitCustomisation", Label="ENTER CUSTOMISATION"},
		{Mode="DriveIn", Part=custom:WaitForChild("DriveInCustomisationTrigger"), Event="OpenDrivingVehicleCustomisation", Label="ENTER CUSTOMISATION"},
	}
end
local function drivingOwnVehicle()
	local ch=player.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); local seat=h and h.SeatPart
	if not seat then return false end
	local model=seat:FindFirstAncestorOfClass("Model")
	return model and tonumber(model:GetAttribute("OwnerUserId"))==player.UserId
end
local gui=Instance.new("ScreenGui"); gui.Name="NTR_GarageEntrancePrompt"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.Parent=player:WaitForChild("PlayerGui")
local status=Instance.new("TextLabel"); status.AnchorPoint=Vector2.new(.5,1); status.Position=UDim2.new(.5,0,1,-28); status.Size=UDim2.fromOffset(420,42); status.BackgroundColor3=c("PanelDeep",Color3.fromRGB(9,12,16)); status.BackgroundTransparency=.08; status.TextColor3=c("Text",Color3.new(1,1,1)); status.FontFace=Font.new("rbxasset://fonts/families/Michroma.json"); status.TextSize=13; status.Visible=false; status.Parent=gui
Instance.new("UICorner",status).CornerRadius=UDim.new(0,4); local ss=Instance.new("UIStroke",status); ss.Color=c("Structure",Color3.fromRGB(236,92,168)); ss.Thickness=1
local function flash(text) status.Text=text; status.Visible=true; task.delay(2,function() status.Visible=false end) end
for _, item in ipairs(paths()) do
	local prompt=Instance.new("ProximityPrompt"); prompt.Name="NTRCanonical"..item.Mode; prompt.Style=Enum.ProximityPromptStyle.Custom; prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.GamepadKeyCode=Enum.KeyCode.ButtonX; prompt.MaxActivationDistance=n("PromptDistance",14); prompt.RequiresLineOfSight=false; prompt.HoldDuration=0; prompt.Parent=item.Part
	local bill=Instance.new("BillboardGui"); bill.Name="NTRCanonicalPrompt"; bill.Adornee=item.Part; bill.AlwaysOnTop=true; bill.LightInfluence=0; bill.Size=UDim2.fromOffset(300,52); bill.StudsOffsetWorldSpace=Vector3.new(0,item.Part.Size.Y*.5+3,0); bill.Enabled=false; bill.Parent=gui
	local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundColor3=c("PanelDeep",Color3.fromRGB(9,12,16)); label.BackgroundTransparency=.08; label.TextColor3=c("Text",Color3.new(1,1,1)); label.FontFace=Font.new("rbxasset://fonts/families/Michroma.json"); label.TextScaled=true; label.Parent=bill; Instance.new("UICorner",label).CornerRadius=UDim.new(0,4); local st=Instance.new("UIStroke",label); st.Color=c("Structure",Color3.fromRGB(236,92,168)); st.Thickness=1
	prompt.PromptShown:Connect(function() if item.Mode~="DriveIn" or drivingOwnVehicle() then label.Text=(UserInputService.TouchEnabled and "TAP  " or "E  ")..item.Label; bill.Enabled=true end end)
	prompt.PromptHidden:Connect(function() bill.Enabled=false end)
	prompt.Triggered:Connect(function()
		bill.Enabled=false
		if item.Mode=="DriveIn" and not drivingOwnVehicle() then flash("Drive your owned vehicle into the bay first."); return end
		local ok,result=pcall(function() return request:InvokeServer("Begin",{Mode=item.Mode}) end)
		if not ok or not result or result.Success~=true then flash((result and result.Message) or "Could not enter garage."); return end
		player:SetAttribute("NTR_GarageEntryMode",item.Mode)
		local event=script.Parent:FindFirstChild(item.Event) or script.Parent:WaitForChild(item.Event,5)
		if event and event:IsA("BindableEvent") then event:Fire() else request:InvokeServer("End",{ReturnToEntry=true}); flash("Garage UI handoff is unavailable.") end
	end)
end
]==]

local presentationSource = [==[
-- NTR_GARAGE_CANONICAL_EXPERIENCE_V1
-- NTR_GARAGE_CANONICAL_DESIGN_SYSTEM_V3
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer; local camera=Workspace.CurrentCamera
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local uiConfig=kit:WaitForChild("Config"):WaitForChild("UI")
local cfg=uiConfig:WaitForChild("GarageExperience")
local desktop=uiConfig:WaitForChild("DesktopFreeRoamHud")
local colours=desktop:WaitForChild("Colours")
local effects=desktop:WaitForChild("Effects")
local assets=desktop:FindFirstChild("Assets")
local request=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("GarageSessionRequest")
local function value(folder,name,fallback) local v=folder and folder:FindFirstChild(name); return v and v.Value~=nil and v.Value or fallback end
local function C(name,fallback) local v=value(colours,name,nil); return typeof(v)=="Color3" and v or fallback end
local function N(name,fallback) return tonumber(value(cfg,name,fallback)) or fallback end
local function E(name,fallback) return tonumber(value(effects,name,fallback)) or fallback end
local panel=C("Panel",Color3.fromRGB(15,19,24)); local deep=C("PanelDeep",Color3.fromRGB(9,12,16)); local soft=C("PanelSoft",Color3.fromRGB(24,29,36)); local panelBlue=C("PanelBlue",Color3.fromRGB(8,42,84)); local pink=C("Outline",Color3.fromRGB(244,46,151)); local pinkSoft=C("OutlineSoft",Color3.fromRGB(214,74,175)); local cyan=C("Telemetry",Color3.fromRGB(43,225,218)); local purchase=C("ElectricBlue",Color3.fromRGB(25,116,255)); local text=C("Text",Color3.fromRGB(246,248,252)); local muted=C("Muted",Color3.fromRGB(163,171,184))
local activeGui; local ending=false; local popupShell; local popupButton; local scrollingUntil=0; local layout; local stageVisible; local leftArrow; local rightArrow; local nextLayoutRefresh=0
local panelNames={TopHUD=true,Categories=true,GarageCapacityPinnedLeft=true,CashPinnedBottomLeft=true,PersistentStats=true,NextPinnedBottomRight=true,ModuleSlotBarPanel=true,ModuleOptionsPanel=true,CockpitPaintPanel=true,CustomiseListPanel=true}
local function textButton(root,wanted) for _,o in ipairs(root and root:GetDescendants() or {}) do if o:IsA("TextButton") and string.upper(o.Text)==string.upper(wanted) then return o end end end
local function ensureCorner(parent,radius) local o=parent:FindFirstChild("GarageCorner") or parent:FindFirstChildOfClass("UICorner"); if not o then o=Instance.new("UICorner"); o.Name="GarageCorner"; o.Parent=parent end; o.CornerRadius=UDim.new(0,radius or 5); return o end
local function ensureStroke(parent,name,color,thickness,transparency) local o=parent:FindFirstChild(name); if not (o and o:IsA("UIStroke")) then if o then o:Destroy() end; o=Instance.new("UIStroke"); o.Name=name; o.Parent=parent end; o.Color=color; o.Thickness=thickness; o.Transparency=transparency; o.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return o end
local function ensureSurfaceGradient(parent,top,bottom)
	local g=parent:FindFirstChild("GarageSurfaceGradient"); if not (g and g:IsA("UIGradient")) then if g then g:Destroy() end; g=Instance.new("UIGradient"); g.Name="GarageSurfaceGradient"; g.Parent=parent end
	g.Color=ColorSequence.new(top,bottom); g.Transparency=NumberSequence.new(E("GradientTransparency",.12)); g.Rotation=90; return g
end
local function ensureButtonGradient(parent)
	local overlay=parent:FindFirstChild("GarageGradientOverlay"); if overlay and not overlay:IsA("Frame") then overlay:Destroy(); overlay=nil end
	if not overlay then overlay=Instance.new("Frame"); overlay.Name="GarageGradientOverlay"; overlay.Active=false; overlay.BorderSizePixel=0; overlay.Size=UDim2.fromScale(1,1); overlay.Parent=parent; ensureCorner(overlay,5); local g=Instance.new("UIGradient"); g.Name="Gradient"; g.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(95,95,95)); g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.20),NumberSequenceKeypoint.new(.52,.70),NumberSequenceKeypoint.new(1,.28)}); g.Rotation=E("ButtonGradientRotation",90); g.Parent=overlay end
	overlay.BackgroundColor3=Color3.new(1,1,1); overlay.BackgroundTransparency=1-math.clamp(E("ButtonGradientStrength",.10),0,.35); overlay.ZIndex=parent.ZIndex; return overlay
end
local function stylePanel(o)
	if not (o and o:IsA("Frame")) then return end
	if o.Name=="CockpitGridPanel" or o.Name=="DealershipExitPinnedBottomRight" then
		o.BackgroundTransparency=1
		for _,child in ipairs(o:GetChildren()) do if child:IsA("UIStroke") then child.Transparency=1 elseif child:IsA("UIGradient") or child.Name=="GarageGlowStroke" or child.Name=="GarageSurfaceGradient" then child:Destroy() end end
		return
	end
	if not panelNames[o.Name] then return end
	o.BackgroundColor3=deep; o.BackgroundTransparency=math.min(o.BackgroundTransparency,.12); ensureCorner(o,5); ensureSurfaceGradient(o,soft:Lerp(deep,.55),deep)
	local main=o:FindFirstChildOfClass("UIStroke"); if main and main.Name~="GarageGlowStroke" then main.Color=pink; main.Thickness=1.2; main.Transparency=.14 end
	ensureStroke(o,"GarageGlowStroke",pink,3.5,E("GlowTransparency",.82))
end
local function styleButton(o,selected)
	if not (o and o:IsA("TextButton")) then return end
	local upper=string.upper(o.Text or ""); local positive=string.sub(upper,1,3)=="BUY" or upper=="CUSTOMISE" or upper=="GET MORE"
	local accent=positive and purchase or selected and cyan or pinkSoft
	if positive then o.BackgroundColor3=panelBlue elseif selected then o.BackgroundColor3=Color3.fromRGB(15,48,57) elseif o:GetAttribute("NTRGarageVehicleCard")==true then o.BackgroundColor3=panel end
	o.BackgroundTransparency=positive and .04 or .08; o.TextColor3=text; o.AutoButtonColor=false; ensureCorner(o,5); ensureButtonGradient(o)
	local main=o:FindFirstChildOfClass("UIStroke"); if main and main.Name~="GarageGlowStroke" then main.Color=accent; main.Thickness=selected and 2 or 1.3; main.Transparency=.08 end
	local glow=ensureStroke(o,"GarageGlowStroke",accent,selected and 4.5 or 3.5,E("GlowTransparency",.82))
	if o:GetAttribute("NTRGarageHoverConnected")~=true then o:SetAttribute("NTRGarageHoverConnected",true); o.MouseEnter:Connect(function() o.BackgroundTransparency=.02; glow.Transparency=math.max(.55,E("GlowTransparency",.82)-.14) end); o.MouseLeave:Connect(function() o.BackgroundTransparency=(string.sub(string.upper(o.Text or ""),1,3)=="BUY" or string.upper(o.Text or "")=="CUSTOMISE") and .04 or .08; glow.Transparency=E("GlowTransparency",.82) end) end
end
local function style(root)
	for _,o in ipairs(root:GetDescendants()) do
		if o:IsA("Frame") then stylePanel(o)
		elseif o:IsA("TextButton") and o:GetAttribute("NTRGarageVehicleCard")~=true then styleButton(o,false)
		elseif o:IsA("TextLabel") and o.TextColor3~=Color3.fromRGB(0,255,0) and o.TextSize<=10 then o.TextColor3=muted end
	end
end
local function selectedVehicleCard(gui) local grid=gui:FindFirstChild("CockpitGrid",true); if not grid then return end; for _,o in ipairs(grid:GetChildren()) do if o:IsA("GuiButton") and o:GetAttribute("NTRGarageVehicleCard")==true and o:GetAttribute("NTRGarageSelected")==true then return o end end end
local function ensurePopup(gui)
	if popupShell and popupShell.Parent==gui then return popupShell end
	popupShell=Instance.new("Frame"); popupShell.Name="VehicleCardActionPopup"; popupShell.AnchorPoint=Vector2.new(.5,1); popupShell.Size=UDim2.fromOffset(190,46); popupShell.BackgroundColor3=deep; popupShell.BackgroundTransparency=.03; popupShell.BorderSizePixel=0; popupShell.Visible=false; popupShell.ZIndex=85; popupShell.Parent=gui
	ensureCorner(popupShell,6); ensureSurfaceGradient(popupShell,panelBlue:Lerp(deep,.45),deep); ensureStroke(popupShell,"PopupStroke",cyan,1.5,.04); ensureStroke(popupShell,"GarageGlowStroke",cyan,4.5,E("GlowTransparency",.82)); return popupShell
end
local function decorateVehicleCards(gui)
	local grid=gui:FindFirstChild("CockpitGrid",true); if not grid then return end
	for _,card in ipairs(grid:GetChildren()) do if card:IsA("TextButton") and card:GetAttribute("NTRGarageVehicleCard")==true then
		local selected=card:GetAttribute("NTRGarageSelected")==true; local cardH=N("CarouselCardHeight",154); local imageH=cardH-36; card.Text=""; card.ClipsDescendants=false; styleButton(card,selected)
		local icon; local badge
		for _,child in ipairs(card:GetChildren()) do if child:IsA("Frame") and child:GetAttribute("PooledDynamic")==true then local image=child:FindFirstChildWhichIsA("ImageLabel",true); local label=child:FindFirstChildWhichIsA("TextLabel",true); if image then icon=child elseif label then badge=child elseif not icon then icon=child end end end
		if icon then icon.BackgroundTransparency=1; icon.BorderSizePixel=0; icon.Position=UDim2.fromOffset(4,3); icon.Size=UDim2.new(1,-8,0,imageH); icon.ClipsDescendants=true; icon.ZIndex=card.ZIndex+2; for _,d in ipairs(icon:GetDescendants()) do if d:IsA("UIStroke") then d.Transparency=1 end end; local image=icon:FindFirstChildWhichIsA("ImageLabel",true); if image then image.BackgroundTransparency=1; image.BorderSizePixel=0; image.AnchorPoint=Vector2.new(.5,.5); image.Position=UDim2.fromScale(.5,.5); image.Size=UDim2.fromScale(1.38,1.38); image.ScaleType=Enum.ScaleType.Fit; image.ZIndex=card.ZIndex+3 end end
		if badge and badge~=icon then badge.AnchorPoint=Vector2.new(1,0); badge.Position=UDim2.new(1,-8,0,8); badge.ZIndex=card.ZIndex+6; for _,d in ipairs(badge:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex=badge.ZIndex+1 end end end
		local nameLabel; local ownedLabel
		for _,child in ipairs(card:GetChildren()) do if child:IsA("TextLabel") then local upper=string.upper(child.Text); if string.sub(upper,1,1)=="$" then child.Visible=false elseif string.find(upper,"OWNED X",1,true) then ownedLabel=child else nameLabel=nameLabel or child end end end
		if nameLabel then nameLabel.Position=UDim2.fromOffset(9,cardH-32); nameLabel.Size=UDim2.new(1,-18,0,16); nameLabel.TextXAlignment=Enum.TextXAlignment.Left; nameLabel.TextSize=9; nameLabel.TextColor3=text; nameLabel.ZIndex=card.ZIndex+4 end
		if ownedLabel then ownedLabel.Position=UDim2.fromOffset(9,cardH-16); ownedLabel.Size=UDim2.new(1,-18,0,12); ownedLabel.TextXAlignment=Enum.TextXAlignment.Left; ownedLabel.TextSize=7; ownedLabel.TextColor3=muted; ownedLabel.ZIndex=card.ZIndex+4 end
	end end
	if grid:GetAttribute("NTRGarageScrollConnected")~=true then grid:SetAttribute("NTRGarageScrollConnected",true); grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function() scrollingUntil=os.clock()+.14; if popupShell then popupShell.Visible=false end; task.delay(.16,function() if activeGui then layout(activeGui) end end) end) end
end
local function updateActionPopup(gui)
	local shell=ensurePopup(gui); local newAction=gui:FindFirstChild("VehicleActionButton",true)
	if newAction and newAction~=popupButton then if popupButton and popupButton.Parent then popupButton:Destroy() end; popupButton=newAction; popupButton.Parent=shell; popupButton.AnchorPoint=Vector2.zero; popupButton.Position=UDim2.fromOffset(5,5); popupButton.Size=UDim2.new(1,-10,1,-10); popupButton.ZIndex=87 end
	if popupButton and popupButton.Parent==shell then styleButton(popupButton,false); popupButton.BackgroundColor3=panelBlue end
	local card=selectedVehicleCard(gui)
	if not (card and popupButton and popupButton.Parent==shell and os.clock()>=scrollingUntil and stageVisible(gui,"CockpitShop")) then shell.Visible=false; return end
	local scaler=gui:FindFirstChildOfClass("UIScale"); local scale=scaler and scaler.Scale or 1; shell.Position=UDim2.fromOffset((card.AbsolutePosition.X+card.AbsoluteSize.X*.5)/math.max(scale,.01),(card.AbsolutePosition.Y-8)/math.max(scale,.01)); shell.Visible=true
end
stageVisible=function(gui,name) local f=gui:FindFirstChild(name,true); return f and f.Visible end
local function decorateModuleButtons(gui)
	local diagrams=cfg:FindFirstChild("ModuleDiagrams"); local category=diagrams and (diagrams:FindFirstChild("BRUISER") or diagrams:GetChildren()[1]); if not category then return end
	for _,containerName in ipairs({"ModuleSlotBar","CustomiseList"}) do
		local container=gui:FindFirstChild(containerName,true)
		if container then
			for _,button in ipairs(container:GetChildren()) do
				if button:IsA("TextButton") then
					styleButton(button,false)
					if not button:FindFirstChild("NTRModuleDiagram") then
						local lower=string.lower(button.Text)
						local compact=string.gsub(lower," ","")
						local slotId
						for _,id in ipairs({"Engine1","Engine2","Stabilisers","Boost","FrontBumper","RearBumper","RearSpoiler","SidePods"}) do
							local folder=category:FindFirstChild(id)
							local label=folder and folder:FindFirstChild("Label")
							if label and string.find(compact,string.gsub(string.lower(label.Value)," ",""),1,true) then slotId=id end
						end
						if not slotId then
							if string.find(lower,"front engine",1,true) then slotId="Engine1"
							elseif string.find(lower,"rear engine",1,true) then slotId="Engine2"
							elseif string.find(lower,"stabilis",1,true) then slotId="Stabilisers"
							elseif string.find(lower,"boost",1,true) then slotId="Boost" end
						end
						local folder=slotId and category:FindFirstChild(slotId)
						local imageValue=folder and folder:FindFirstChild("Image")
						if folder then
							button.Size=UDim2.fromOffset(containerName=="ModuleSlotBar" and 156 or 176,96)
							button.TextYAlignment=Enum.TextYAlignment.Bottom
							local image=Instance.new("ImageLabel"); image.Name="NTRModuleDiagram"; image.BackgroundTransparency=1; image.Size=UDim2.new(1,-12,1,-34); image.Position=UDim2.fromOffset(6,4); image.ScaleType=Enum.ScaleType.Fit; image.Image=imageValue and imageValue.Value or ""; image.ZIndex=button.ZIndex+2; image.Parent=button
						end
					end
				end
			end
		end
	end
end
local function decorateStats(gui)
	local stats=gui:FindFirstChild("PersistentStats",true); if not stats then return end
	stats:SetAttribute("NTRGarageStatReference",N("StatBarReference",180))
	for _,o in ipairs(stats:GetDescendants()) do
		if o:IsA("Frame") and o.Name=="NTRGarageStatTrack" then o.BackgroundColor3=soft; o.BackgroundTransparency=.12
		elseif o:IsA("Frame") and o.Name=="NTRGarageStatFill" then
			o.BackgroundColor3=cyan
			local g=o:FindFirstChild("GarageStatGradient") or Instance.new("UIGradient"); g.Name="GarageStatGradient"; g.Color=ColorSequence.new(purchase,cyan); g.Rotation=0; g.Parent=o
		end
	end
end
local function decorateEconomy(gui)
	local cash=gui:FindFirstChild("CashPinnedBottomLeft",true); local capacity=gui:FindFirstChild("GarageCapacityPinnedLeft",true)
	if cash then
		cash.BackgroundColor3=panelBlue; local g=ensureSurfaceGradient(cash,purchase:Lerp(panelBlue,.72),panelBlue); g.Rotation=0; ensureStroke(cash,"CashStroke",purchase,1.7,0)
		for _,o in ipairs(cash:GetChildren()) do if o:IsA("TextLabel") then if string.upper(o.Text)=="AVAILABLE CASH" then o.Visible=false else o.Position=UDim2.fromOffset(12,0); o.Size=UDim2.new(1,-58,1,0); o.TextXAlignment=Enum.TextXAlignment.Left; o.TextSize=16 end elseif o:IsA("TextButton") and string.upper(o.Text)=="GET MORE" then o.Text="+"; o.Name="GarageCashPlus"; o.AnchorPoint=Vector2.new(1,.5); o.Position=UDim2.new(1,-8,.5,0); o.Size=UDim2.fromOffset(32,30); o.TextSize=19 end end
	end
	if capacity then
		capacity.BackgroundColor3=panelBlue; local g=ensureSurfaceGradient(capacity,purchase:Lerp(panelBlue,.72),panelBlue); g.Rotation=0; ensureStroke(capacity,"CashStroke",purchase,1.7,0)
		for _,o in ipairs(capacity:GetChildren()) do if o:IsA("TextLabel") then if string.upper(o.Text)=="GARAGE SPACES" or o.Name=="GarageCapacityPrice" then o.Visible=false elseif o.Name=="GarageCapacityCount" then o.Visible=true; o.Text=string.gsub(o.Text,"spaces","Spaces"); o.Position=UDim2.fromOffset(40,0); o.Size=UDim2.new(1,-92,1,0); o.TextXAlignment=Enum.TextXAlignment.Left; o.TextSize=13 end elseif o:IsA("TextButton") and o.Name=="GarageCapacityUpgradeButton" then o.Text="+"; o.AnchorPoint=Vector2.new(1,.5); o.Position=UDim2.new(1,-8,.5,0); o.Size=UDim2.fromOffset(32,30); o.TextSize=19 end end
		local icon=capacity:FindFirstChild("GarageChipIcon"); if not icon then icon=Instance.new("ImageLabel"); icon.Name="GarageChipIcon"; icon.BackgroundTransparency=1; icon.BorderSizePixel=0; icon.Position=UDim2.fromOffset(8,13); icon.Size=UDim2.fromOffset(30,30); icon.ScaleType=Enum.ScaleType.Fit; icon.ZIndex=capacity.ZIndex+2; icon.Parent=capacity end
		local assetValue=assets and assets:FindFirstChild("GarageIcon"); icon.Image=assetValue and assetValue.Value or ""; icon.ImageColor3=text
	end
end
local function decorateHeader(gui)
	local top=gui:FindFirstChild("TopHUD",true); if not top then return end
	top.BackgroundColor3=soft; top.BackgroundTransparency=.34; local g=ensureSurfaceGradient(top,soft,deep); g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(1,.28)}); for _,o in ipairs(top:GetChildren()) do if o:IsA("UIStroke") then o.Transparency=1 end end
	local title=top:FindFirstChildWhichIsA("TextLabel"); if title then title.Position=UDim2.fromOffset(12,7); title.Size=UDim2.new(1,-24,0,25); title.TextSize=15 end
	for _,o in ipairs(top:GetChildren()) do if o:IsA("TextLabel") and o~=title then o.Position=UDim2.fromOffset(12,31); o.Size=UDim2.new(1,-24,0,22); o.TextSize=8 end end
end
local function decorateCarouselArrows(gui)
	local shop=gui:FindFirstChild("CockpitShop",true); local gridPanel=gui:FindFirstChild("CockpitGridPanel",true); if not (shop and gridPanel) then return end
	if not (leftArrow and leftArrow.Parent) or not (rightArrow and rightArrow.Parent) then
		for _,o in ipairs(gridPanel:GetChildren()) do if o:IsA("TextButton") and o.Text=="<" then leftArrow=o elseif o:IsA("TextButton") and o.Text==">" then rightArrow=o end end
		if leftArrow then leftArrow.Name="CockpitCarouselPrevious"; leftArrow.Parent=shop end
		if rightArrow then rightArrow.Name="CockpitCarouselNext"; rightArrow.Parent=shop end
	end
	for _,arrow in ipairs({leftArrow,rightArrow}) do if arrow then arrow.BackgroundColor3=deep; arrow.BackgroundTransparency=.22; arrow.TextColor3=text; arrow.ZIndex=82; styleButton(arrow,false) end end
end
layout=function(gui)
	local viewport=camera and camera.ViewportSize or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("MinScale",.68); local scale=math.clamp(math.min(viewport.X/N("BaseWidth",1600),viewport.Y/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); local scaler=gui:FindFirstChildOfClass("UIScale"); if scaler then scaler.Scale=scale end
	local vw=viewport.X/scale; local vh=viewport.Y/scale; local margin=N("Margin",18); local gap=N("Gap",14); local categoryGap=N("CategoryCarouselGap",26); local left=N("CategoryWidth",224); local right=N("StatsWidth",360); local carousel=N("CarouselHeight",174); local arrowW=N("CarouselArrowWidth",30); local top=72; local bottom=vh-margin; local carouselTop=bottom-carousel
	local shop=gui:FindFirstChild("CockpitShop",true); local categories=gui:FindFirstChild("Categories",true); local cash=gui:FindFirstChild("CashPinnedBottomLeft",true); local capacity=gui:FindFirstChild("GarageCapacityPinnedLeft",true); local grid=gui:FindFirstChild("CockpitGridPanel",true); local stats=gui:FindFirstChild("PersistentStats",true); local exit=gui:FindFirstChild("DealershipExitPinnedBottomRight",true); local topPanel=gui:FindFirstChild("TopHUD",true)
	if topPanel then topPanel.AnchorPoint=Vector2.new(.5,0); topPanel.Position=UDim2.fromOffset(vw*.5,28); topPanel.Size=UDim2.fromOffset(N("HeaderWidth",440),N("HeaderHeight",64)) end
	if shop and shop.Visible then
		decorateCarouselArrows(gui)
		if categories then categories.AnchorPoint=Vector2.zero; categories.Position=UDim2.fromOffset(12,top); categories.Size=UDim2.fromOffset(left,math.max(160,carouselTop-categoryGap-top)) end
		local gridX=margin+arrowW+gap; local gridW=math.max(320,vw-2*(margin+arrowW+gap)); if grid then grid.AnchorPoint=Vector2.new(0,1); grid.Position=UDim2.fromOffset(gridX,bottom); grid.Size=UDim2.fromOffset(gridW,carousel); grid.ClipsDescendants=true end
		local scroller=grid and grid:FindFirstChildWhichIsA("ScrollingFrame",true); local gl=scroller and scroller:FindFirstChildWhichIsA("UIGridLayout"); if scroller then scroller.Position=UDim2.zero; scroller.Size=UDim2.fromScale(1,1); scroller.ClipsDescendants=true; scroller.AutomaticCanvasSize=Enum.AutomaticSize.X; scroller.ScrollingDirection=Enum.ScrollingDirection.X; scroller.CanvasSize=UDim2.fromOffset(0,0) end; if gl then gl.FillDirection=Enum.FillDirection.Vertical; gl.FillDirectionMaxCells=1; gl.CellSize=UDim2.fromOffset(N("CarouselCardWidth",240),N("CarouselCardHeight",154)); gl.CellPadding=UDim2.fromOffset(12,0) end
		if leftArrow then leftArrow.AnchorPoint=Vector2.new(0,.5); leftArrow.Position=UDim2.fromOffset(margin,carouselTop+carousel*.5); leftArrow.Size=UDim2.fromOffset(arrowW,math.max(72,carousel-20)); leftArrow.Visible=true end
		if rightArrow then rightArrow.AnchorPoint=Vector2.new(1,.5); rightArrow.Position=UDim2.fromOffset(vw-margin,carouselTop+carousel*.5); rightArrow.Size=UDim2.fromOffset(arrowW,math.max(72,carousel-20)); rightArrow.Visible=true end
		local statsH=N("StatsHeight",308); if stats then stats.AnchorPoint=Vector2.new(1,0); stats.Position=UDim2.fromOffset(vw-margin,28); stats.Size=UDim2.fromOffset(right,statsH) end
		local chipGap=gap; local chipW=(right-chipGap)*.5; local chipH=N("EconomyChipHeight",58); local chipY=28+statsH+gap; if capacity then capacity.AnchorPoint=Vector2.new(1,0); capacity.Position=UDim2.fromOffset(vw-margin-chipW-chipGap,chipY); capacity.Size=UDim2.fromOffset(chipW,chipH) end; if cash then cash.AnchorPoint=Vector2.new(1,0); cash.Position=UDim2.fromOffset(vw-margin,chipY); cash.Size=UDim2.fromOffset(chipW,chipH) end
		if exit then exit.AnchorPoint=Vector2.new(1,1); exit.Position=UDim2.fromOffset(vw-margin,carouselTop-gap); exit.Size=UDim2.fromOffset(88,30); local b=textButton(exit,"Exit"); if b then b.Position=UDim2.zero; b.Size=UDim2.fromScale(1,1); b.TextSize=9 end end
	end
	local back=textButton(gui,"Back"); if back then back.Visible=not (stageVisible(gui,"CockpitPaint") and player:GetAttribute("NTR_GarageEntryMode")~=nil) end
	style(gui); decorateHeader(gui); decorateEconomy(gui); decorateStats(gui); decorateModuleButtons(gui); decorateVehicleCards(gui); updateActionPopup(gui)
end
local function attach(gui)
	activeGui=gui; ending=false; task.defer(function() layout(gui) end)
	local exitPanel=gui:FindFirstChild("DealershipExitPinnedBottomRight",true); local exit=textButton(exitPanel,"Exit"); if exit then exit.MouseButton1Click:Connect(function() if ending then return end; ending=true; pcall(function() request:InvokeServer("End",{ReturnToEntry=true}) end); player:SetAttribute("NTR_GarageEntryMode",nil) end) end
	gui:GetPropertyChangedSignal("Enabled"):Connect(function() if not gui.Enabled and player:GetAttribute("NTR_GarageSessionActive")==true and not ending then ending=true; pcall(function() request:InvokeServer("End",{ReturnToEntry=false}) end); player:SetAttribute("NTR_GarageEntryMode",nil) end end)
	gui.DescendantAdded:Connect(function() task.defer(function() if gui.Parent then layout(gui) end end) end); for _=1,20 do if not gui.Parent or not gui.Enabled then break end; layout(gui); task.wait(.1) end
end
player.PlayerGui.ChildAdded:Connect(function(child) if child.Name=="HOVER_RACING_V2_GarageUI" then task.defer(function() attach(child) end) end end)
local existing=player.PlayerGui:FindFirstChild("HOVER_RACING_V2_GarageUI"); if existing then attach(existing) end
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if activeGui and activeGui.Parent then layout(activeGui) end end) end
RunService.RenderStepped:Connect(function()
	if not (activeGui and activeGui.Parent and activeGui.Enabled) then return end
	local browsing=stageVisible(activeGui,"CockpitShop")
	if browsing and os.clock()>=nextLayoutRefresh then nextLayoutRefresh=os.clock()+.12; layout(activeGui) end
	if leftArrow then leftArrow.Visible=browsing end
	if rightArrow then rightArrow.Visible=browsing end
	if browsing then updateActionPopup(activeGui) end
end)
]==]

local function compile(name, source)
	assert(type(source) == "string" and #source > 100, "Empty generated source for " .. name)
	if typeof(loadstring) == "function" then
		local fn, err = loadstring(source)
		assert(fn, "Compile preflight failed for " .. name .. ": " .. tostring(err))
	else
		warn("[NTR Garage Canonical] loadstring unavailable; Studio will parse " .. name .. " when the installed script starts.")
	end
end
compile("GarageSessionService", serverSource)
compile("GarageEntranceController", entranceSource)
compile("GarageExperienceController", presentationSource)

if MODE == "AUDIT" then
	print("[NTR Garage Canonical] AUDIT PASS: preflight sources and hierarchy are compatible.")
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

oldSession.Source = serverSource
oldSession.Name = "GarageSessionService_Active"
oldSession:SetAttribute("CanonicalGarageExperience", MARKER)
oldOnFoot.Disabled = true
oldDriveIn.Disabled = true
oldOnFoot:SetAttribute("SupersededBy", MARKER)
oldDriveIn:SetAttribute("SupersededBy", MARKER)
introClient:SetAttribute("CanonicalPromptOwnsGarageEntry", true)

local world = need(game:GetService("Workspace"), "NeoTokyoRacersWorld", "Folder")
local dealership = need(world, "Dealership", "Folder")
local introWorld = need(dealership, "Intro", "Folder")
introWorld:SetAttribute("AutoOpenGarageAtDesk", false)
local deskTrigger = need(need(introWorld, "Desk", "Folder"), "GarageDeskTrigger", "BasePart")
deskTrigger:SetAttribute("AutoOpenGarageAtDesk", false)

local entrance = ensure(intro, "LocalScript", "GarageEntranceController_Active")
entrance.Source = entranceSource
entrance.Disabled = false
entrance:SetAttribute("InstalledBy", MARKER)
local presentation = ensure(uiControllers, "LocalScript", "GarageExperienceController_Active")
presentation.Source = presentationSource
presentation.Disabled = false
presentation:SetAttribute("InstalledBy", MARKER)
presentation:SetAttribute("PresentationRevision", "NTR_GARAGE_CANONICAL_DESIGN_SYSTEM_V3")

local source = bootstrap.Source
local function replaceOnce(text, old, new, label)
	local firstStart, firstEnd = string.find(text, old, 1, true)
	assert(firstStart, label .. " anchor missing")
	assert(not string.find(text, old, firstEnd + 1, true), label .. " anchor is ambiguous")
	return string.sub(text, 1, firstStart - 1) .. new .. string.sub(text, firstEnd + 1)
end

if not string.find(source, "NTR_GARAGE_CANONICAL_ALL_CATEGORY", 1, true) then
	local getCategoryOld = [[local function getCategory()
	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do]]
	local getCategoryNew = [[local function getCategory()
	-- NTR_GARAGE_CANONICAL_ALL_CATEGORY
	if State.BrowseAll == true then
		local combined = { CategoryId = "__ALL", DisplayName = "ALL", Cockpits = {}, Slots = {} }
		for _, sourceCategory in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
			for _, sourceCockpit in ipairs(sourceCategory.Cockpits or {}) do
				local copy = {}
				for key, value in pairs(sourceCockpit) do copy[key] = value end
				copy.NTRCategoryId = sourceCategory.CategoryId
				table.insert(combined.Cockpits, copy)
			end
		end
		return combined
	end
	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do]]
	source = replaceOnce(source, getCategoryOld, getCategoryNew, "All-category resolver")

	local categoryLoopOld = [[	for _, category in ipairs(sortedCategories) do
		local b = pooledButton(categoryPool, category.DisplayName or category.CategoryId, UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), category.CategoryId == State.CategoryId and Theme.CardHot or Theme.Card)]]
	local categoryLoopNew = [[	local allButton = pooledButton(categoryPool, "ALL", UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), State.BrowseAll == true and Theme.CardHot or Theme.Card)
	categoryPool:Connect(allButton, allButton.MouseButton1Click, function()
		State.BrowseAll = true
		State.SelectedVehicleId = nil
		renderCockpitShop()
	end)
	for _, category in ipairs(sortedCategories) do
		local b = pooledButton(categoryPool, category.DisplayName or category.CategoryId, UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), State.BrowseAll ~= true and category.CategoryId == State.CategoryId and Theme.CardHot or Theme.Card)]]
	source = replaceOnce(source, categoryLoopOld, categoryLoopNew, "All-category button")
	source = replaceOnce(source,
		[[			State.CategoryId = category.CategoryId
			State.SelectedVehicleId = nil]],
		[[			State.BrowseAll = false
			State.CategoryId = category.CategoryId
			State.SelectedVehicleId = nil]],
		"Category selection mode")

	local priceSortOld = [[		table.sort(sortedCockpits, function(a, b)
			local aPrice = tonumber(a and a.Price) or math.huge
			local bPrice = tonumber(b and b.Price) or math.huge
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end]]
	local ratingSortNew = [[		table.sort(sortedCockpits, function(a, b)
			local _, aRating = NTR_phase8CockpitRatingParts(a)
			local _, bRating = NTR_phase8CockpitRatingParts(b)
			aRating = tonumber(aRating) or -math.huge
			bRating = tonumber(bRating) or -math.huge
			if aRating ~= bRating then
				return aRating > bRating
			end]]
	source = replaceOnce(source, priceSortOld, ratingSortNew, "Dealership rating sort")

	local cardClickOld = [[			cockpitPool:Connect(card, card.MouseButton1Click, function()
				State.SelectedCockpit = cockpit.CockpitId
				State.SelectedVehicleId = nil]]
	local cardClickNew = [[			local ownedCount = 0
			for _, ownedVehicle in pairs((State.Profile and State.Profile.Vehicles) or {}) do
				if cockpitIdForVehicle(ownedVehicle) == cockpit.CockpitId then ownedCount += 1 end
			end
			if ownedCount > 0 then
				local ownedLabel = label(card, "OWNED x" .. tostring(ownedCount), UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 1, -16), 9, Enum.TextXAlignment.Center)
				ownedLabel.Name = "OwnedCount"
				ownedLabel.TextColor3 = Theme.Muted
			end
			cockpitPool:Connect(card, card.MouseButton1Click, function()
				if cockpit.NTRCategoryId then State.CategoryId = cockpit.NTRCategoryId end
				State.SelectedCockpit = cockpit.CockpitId
				State.SelectedVehicleId = nil]]
	source = replaceOnce(source, cardClickOld, cardClickNew, "Dealership ownership card")
	source = replaceOnce(source,
		[[callServer("BuyCockpitInstance", { CockpitId = State.SelectedCockpit })]],
		[[callServer("BuyCockpitInstance", { CockpitId = State.SelectedCockpit, CategoryId = cockpit.NTRCategoryId or State.CategoryId })]],
		"Dealership category purchase")
end
if not string.find(source, "NTR_GARAGE_CANONICAL_VEHICLE_CARD_METADATA", 1, true) then
	local ownedCardOld = [[			local card = pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), row.VehicleId == State.SelectedVehicleId and Theme.CardHot or Theme.Card)]]
	local ownedCardNew = [[			local card = pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), row.VehicleId == State.SelectedVehicleId and Theme.CardHot or Theme.Card)
			card:SetAttribute("NTRGarageVehicleCard", true) -- NTR_GARAGE_CANONICAL_VEHICLE_CARD_METADATA
			card:SetAttribute("NTRGarageSelected", row.VehicleId == State.SelectedVehicleId)
			card:SetAttribute("NTRGarageVehicleKey", tostring(row.VehicleId))]]
	local dealershipCardOld = [[			local card = pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)]]
	local dealershipCardNew = [[			local card = pooledButton(cockpitPool, "", NTR_phase6CockpitCardSize(), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)
			card:SetAttribute("NTRGarageVehicleCard", true)
			card:SetAttribute("NTRGarageSelected", cockpit.CockpitId == State.SelectedCockpit)
			card:SetAttribute("NTRGarageVehicleKey", tostring(cockpit.CockpitId))]]
	source = replaceOnce(source, ownedCardOld, ownedCardNew, "Owned vehicle-card metadata")
	source = replaceOnce(source, dealershipCardOld, dealershipCardNew, "Dealership vehicle-card metadata")
end
if not string.find(source, "NTR_GARAGE_CANONICAL_STAT_COLUMNS", 1, true)
	and not string.find(source, "NTR_GARAGE_CANONICAL_LAYOUT_V3", 1, true) then
	local statStart = assert(string.find(source, "function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)", 1, true), "Stat renderer start missing")
	local formatStart = assert(string.find(source, "function NTRVehiclePhaseAO.formatRaw(variableName, value)", statStart, true), "Stat renderer end missing")
	local statReplacement = [[function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)
	-- NTR_GARAGE_CANONICAL_STAT_COLUMNS
	local numericValue = tonumber(value) or 0
	local numericBase = tonumber(baseValue) or numericValue
	label(parent, string.upper(tostring(name)), UDim2.new(0.29, 0, 0, 18), UDim2.fromOffset(0, y), 8, Enum.TextXAlignment.Left)
	local bar = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(39, 48, 49),
		BorderSizePixel = 0,
		Size = UDim2.new(0.40, 0, 0, 10),
		Position = UDim2.new(0.29, 0, 0, y + 4),
	}, parent)
	corner(bar, 3)
	local amount = math.clamp(numericValue / 100, 0, 1)
	local baseAmount = math.clamp(numericBase / 100, 0, 1)
	local fill = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(math.min(amount, baseAmount), 1) }, bar)
	corner(fill, 3)
	if amount > baseAmount + 0.002 then
		local deltaFill = new("Frame", { BackgroundColor3 = Color3.fromRGB(84, 255, 126), BorderSizePixel = 0, Position = UDim2.fromScale(baseAmount, 0), Size = UDim2.fromScale(amount - baseAmount, 1) }, bar)
		corner(deltaFill, 3)
	elseif amount < baseAmount - 0.002 then
		local deltaFill = new("Frame", { BackgroundColor3 = Color3.fromRGB(230, 64, 74), BorderSizePixel = 0, Position = UDim2.fromScale(amount, 0), Size = UDim2.fromScale(baseAmount - amount, 1) }, bar)
		corner(deltaFill, 3)
	else
		fill.Size = UDim2.fromScale(amount, 1)
	end
	local valueText = tostring(math.floor(numericValue + 0.5))
	label(parent, valueText, UDim2.new(0.14, 0, 0, 18), UDim2.new(0.71, 0, 0, y), 9, Enum.TextXAlignment.Right)
	local difference = numericValue - numericBase
	local deltaText = "—"
	if math.abs(difference) >= 0.05 then deltaText = (difference > 0 and "+" or "") .. tostring(math.round(difference)) end
	local deltaLabel = label(parent, deltaText, UDim2.new(0.13, 0, 0, 18), UDim2.new(0.87, 0, 0, y), 9, Enum.TextXAlignment.Right)
	deltaLabel.TextColor3 = difference > 0.05 and Color3.fromRGB(84, 255, 126) or difference < -0.05 and Color3.fromRGB(230, 90, 98) or Theme.Muted
end

]]
	source = string.sub(source, 1, statStart - 1) .. statReplacement .. string.sub(source, formatStart)
end
if not string.find(source, "NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_OWNER", 1, true) then
	local layoutStart = assert(string.find(source, "applyDealershipLayout = function()", 1, true), "Bottom-carousel layout start missing")
	local layoutEnd = assert(string.find(source, "local function renderDealershipPanel()", layoutStart, true), "Bottom-carousel layout end missing")
	local layoutReplacement = [[applyDealershipLayout = function()
	-- NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_OWNER
	if not UI.CockpitShop or not camera then return end
	local scale = UI.Scale and UI.Scale.Scale or 1
	local viewport = camera.ViewportSize
	local vw = viewport.X / math.max(scale, 0.1)
	local vh = viewport.Y / math.max(scale, 0.1)
	local margin = 18
	local gap = 14
	local topY = 104
	local leftW = 196
	local rightW = 336
	local carouselH = 156
	local bottomY = vh - BOTTOM_MARGIN
	local leftPanelH = BOTTOM_HEIGHT
	local leftStackGap = 10
	local cashBottomY = bottomY
	local garageBottomY = cashBottomY - leftPanelH - leftStackGap
	local categoryBottomY = garageBottomY - leftPanelH - gap
	local categoryH = math.max(96, categoryBottomY - topY)
	local centerX = margin + leftW + gap
	local rightLeft = vw - margin - rightW
	local centerW = math.max(320, rightLeft - gap - centerX)
	local exitButtonH = UserInputService.TouchEnabled and 48 or 42
	local exitPad = math.max(5, NTR_phase6RawConfigNumber("ExitPanelVerticalPadding", 9))
	local exitPanelH = exitButtonH + exitPad * 2
	local exitTopY = bottomY - exitPanelH
	local statsH = math.min(520, math.max(250, exitTopY - gap - topY))

	if UI.CategoryPanel then
		UI.CategoryPanel.Position = UDim2.fromOffset(margin, topY)
		UI.CategoryPanel.Size = UDim2.fromOffset(leftW, categoryH)
	end
	if UI.GarageCapacityPanel then
		UI.GarageCapacityPanel.AnchorPoint = Vector2.new(0, 1)
		UI.GarageCapacityPanel.Position = UDim2.fromOffset(margin, garageBottomY)
		UI.GarageCapacityPanel.Size = UDim2.fromOffset(leftW, leftPanelH)
	end
	if UI.CashPanel then
		UI.CashPanel.AnchorPoint = Vector2.new(0, 1)
		UI.CashPanel.Position = UDim2.fromOffset(margin, cashBottomY)
		UI.CashPanel.Size = UDim2.fromOffset(leftW, leftPanelH)
	end
	if UI.CockpitGridPanel then
		UI.CockpitGridPanel.AnchorPoint = Vector2.new(0, 1)
		UI.CockpitGridPanel.Position = UDim2.fromOffset(centerX, bottomY)
		UI.CockpitGridPanel.Size = UDim2.fromOffset(centerW, carouselH)
	end
	if UI.StatsPanel and State.Stage == "CockpitShop" then
		UI.StatsPanel.AnchorPoint = Vector2.new(1, 0)
		UI.StatsPanel.Position = UDim2.fromOffset(vw - margin, topY)
		UI.StatsPanel.Size = UDim2.fromOffset(rightW, statsH)
	end
	if UI.DealershipExitPanel then
		UI.DealershipExitPanel.AnchorPoint = Vector2.new(1, 1)
		UI.DealershipExitPanel.Position = UDim2.fromOffset(vw - margin, bottomY)
		UI.DealershipExitPanel.Size = UDim2.fromOffset(rightW, exitPanelH)
	end
	if UI.DealershipExitButton then
		UI.DealershipExitButton.Size = UDim2.new(1, -18, 0, exitButtonH)
		UI.DealershipExitButton.Position = UDim2.new(0, 9, 1, -exitPad - exitButtonH)
	end
	if UI.CockpitGrid then
		UI.CockpitGrid.AutomaticCanvasSize = Enum.AutomaticSize.X
		UI.CockpitGrid.ScrollingDirection = Enum.ScrollingDirection.X
		UI.CockpitGrid.CanvasSize = UDim2.fromOffset(0, 0)
		UI.CockpitGrid.CanvasPosition = Vector2.new(UI.CockpitGrid.CanvasPosition.X, 0)
	end
	if UI.CockpitGridLayout then
		UI.CockpitGridLayout.FillDirection = Enum.FillDirection.Vertical
		UI.CockpitGridLayout.FillDirectionMaxCells = 1
		UI.CockpitGridLayout.CellSize = UDim2.fromOffset(184, 132)
		UI.CockpitGridLayout.CellPadding = UDim2.fromOffset(10, 0)
	end
end

]]
	source = string.sub(source, 1, layoutStart - 1) .. layoutReplacement .. string.sub(source, layoutEnd)
	source = replaceOnce(source,
		[[makeArrowScroller(UI.CockpitGridPanel, UI.CockpitGrid, "Y", 296)]],
		[[makeArrowScroller(UI.CockpitGridPanel, UI.CockpitGrid, "X", 204) -- NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_ARROWS]],
		"Bottom-carousel arrow owner")
end
if not string.find(source, "NTR_GARAGE_CANONICAL_EARLY_CAMERA", 1, true) then
	source = replaceOnce(source,
		[[if not State or State.NoPreviewYet == true or State.Phase5PreviewOrbitInitialized == true then]],
		[[if not State or State.Phase5PreviewOrbitInitialized == true then -- NTR_GARAGE_CANONICAL_EARLY_CAMERA]],
		"Early garage-camera guard")
	source = replaceOnce(source,
		[[State.NoPreviewYet = true
	State.GarageCameraActive = false]],
		[[State.BrowseAll = true
	State.NoPreviewYet = true
	State.GarageCameraActive = true]],
		"Initial garage-camera state")
	source = replaceOnce(source,
		[[State.GarageCameraActive = false
				State.NoPreviewYet = true]],
		[[State.GarageCameraActive = true
				State.BrowseAll = true
				State.NoPreviewYet = true]],
		"Re-entry garage-camera state")
end
if not string.find(source, "NTR_GARAGE_CANONICAL_COCKPIT_CAMERA", 1, true) then
	local cameraOld = [[	local focus = NTR_phase4PreviewPosition()
	local intro = NTR_phase4Intro()
	local cameraFolder = intro and intro:FindFirstChild("Camera")
	local cameraPoint = cameraFolder and cameraFolder:FindFirstChild("GaragePreviewCameraPoint")

	State.TargetFocus = focus
	State.CameraFocus = focus

	if cameraPoint and cameraPoint:IsA("BasePart") then
		local offset = cameraPoint.Position - focus
		local distance = math.max(offset.Magnitude, 8)
		State.TargetDistance = distance
		State.CameraDistance = distance
		State.TargetYaw = math.atan2(offset.X, offset.Z)
		State.CameraYaw = State.TargetYaw
		State.TargetPitch = math.clamp(math.asin(math.clamp(-offset.Y / distance, -1, 1)), math.rad(-45), math.rad(10))
		State.CameraPitch = State.TargetPitch
	end

	State.Phase5PreviewOrbitInitialized = true]]
	local cameraNew = [[	local focus = NTR_phase4PreviewPosition()
	-- NTR_GARAGE_CANONICAL_COCKPIT_CAMERA: match Cockpit Colour / Engine1 framing.
	State.TargetFocus = focus
	State.CameraFocus = focus
	State.TargetYaw = math.rad(135)
	State.CameraYaw = State.TargetYaw
	State.TargetPitch = math.rad(-12)
	State.CameraPitch = State.TargetPitch
	State.TargetDistance = 33
	State.CameraDistance = State.TargetDistance
	State.Phase5PreviewOrbitInitialized = true]]
	source = replaceOnce(source, cameraOld, cameraNew, "Cockpit-edit garage camera")
end
if not string.find(source, "NTR_GARAGE_CANONICAL_ASCENDING_RATING", 1, true) then
	local descending = "return aRating > bRating"
	local firstStart, firstEnd = string.find(source, descending, 1, true)
	assert(firstStart, "First descending-rating sort missing")
	local secondStart, secondEnd = string.find(source, descending, firstEnd + 1, true)
	assert(secondStart and not string.find(source, descending, secondEnd + 1, true), "Descending-rating sort count changed")
	local ascending = "return aRating < bRating -- NTR_GARAGE_CANONICAL_ASCENDING_RATING"
	source = string.sub(source, 1, secondStart - 1) .. ascending .. string.sub(source, secondEnd + 1)
	source = string.sub(source, 1, firstStart - 1) .. ascending .. string.sub(source, firstEnd + 1)
	source = replaceOnce(source,
		[[local aRating = tonumber(aSummary and aSummary.Overall and aSummary.Overall.PerformanceIndex) or -math.huge
			local bRating = tonumber(bSummary and bSummary.Overall and bSummary.Overall.PerformanceIndex) or -math.huge]],
		[[local aRating = tonumber(aSummary and aSummary.Overall and aSummary.Overall.PerformanceIndex) or math.huge
			local bRating = tonumber(bSummary and bSummary.Overall and bSummary.Overall.PerformanceIndex) or math.huge]],
		"Owned unrated sort fallback")
	source = replaceOnce(source,
		[[aRating = tonumber(aRating) or -math.huge
			bRating = tonumber(bRating) or -math.huge]],
		[[aRating = tonumber(aRating) or math.huge
			bRating = tonumber(bRating) or math.huge]],
		"Dealership unrated sort fallback")
end
if not string.find(source, "NTR_GARAGE_CANONICAL_LEFTMOST_PREVIEW", 1, true) then
	local ownedLoop = [[		for index, row in ipairs(rows) do]]
	local ownedPreview = [[		if #rows > 0 and State.NoPreviewYet == true then
			-- NTR_GARAGE_CANONICAL_LEFTMOST_PREVIEW
			State.SelectedVehicleId = rows[1].VehicleId
			State.SelectedCockpit = rows[1].CockpitId
			State.NoPreviewYet = false
			State.GarageCameraActive = true
			State.Phase5PreviewOrbitInitialized = false
			buildPreview()
			NTR_phase4ApplyGaragePreviewCamera()
			renderDealershipPanel()
		end
		for index, row in ipairs(rows) do]]
	source = replaceOnce(source, ownedLoop, ownedPreview, "Owned leftmost preview")
	local dealershipLoop = [[
		for _, cockpit in ipairs(sortedCockpits) do]]
	local dealershipPreview = [[
		if #sortedCockpits > 0 and State.NoPreviewYet == true then
			State.SelectedCockpit = sortedCockpits[1].CockpitId
			if sortedCockpits[1].NTRCategoryId then State.CategoryId = sortedCockpits[1].NTRCategoryId end
			State.SelectedVehicleId = nil
			State.NoPreviewYet = false
			State.GarageCameraActive = true
			State.Phase5PreviewOrbitInitialized = false
			buildPreview()
			NTR_phase4ApplyGaragePreviewCamera()
			renderDealershipPanel()
		end

		for _, cockpit in ipairs(sortedCockpits) do]]
	source = replaceOnce(source, dealershipLoop, dealershipPreview, "Dealership leftmost preview")
	source = replaceOnce(source,
		[[		State.BrowseAll = true
		State.SelectedVehicleId = nil
		renderCockpitShop()]],
		[[		State.BrowseAll = true
		State.SelectedVehicleId = nil
		State.NoPreviewYet = true
		renderCockpitShop()]],
		"All-category leftmost reset")
	source = replaceOnce(source,
		[[			State.BrowseAll = false
			State.CategoryId = category.CategoryId
			State.SelectedVehicleId = nil
			renderCockpitShop()]],
		[[			State.BrowseAll = false
			State.CategoryId = category.CategoryId
			State.SelectedVehicleId = nil
			State.NoPreviewYet = true
			renderCockpitShop()]],
		"Category leftmost reset")
	local clickPreviewOld = [[				buildPreview()
				renderCockpitShop()]]
	local clickPreviewNew = [[				State.NoPreviewYet = false
				State.GarageCameraActive = true
				State.Phase5PreviewOrbitInitialized = false
				buildPreview()
				NTR_phase4ApplyGaragePreviewCamera()
				renderCockpitShop()]]
	local clickCount = 0
	while true do
		local clickStart, clickEnd = string.find(source, clickPreviewOld, 1, true)
		if not clickStart then break end
		source = string.sub(source, 1, clickStart - 1) .. clickPreviewNew .. string.sub(source, clickEnd + 1)
		clickCount += 1
	end
	assert(clickCount == 2, "Expected two vehicle click-preview handlers, got " .. tostring(clickCount))
end
if not string.find(source, "NTR_GARAGE_CANONICAL_LAYOUT_V3", 1, true) then
	local drawStart = assert(string.find(source, "function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)", 1, true))
	local drawEnd = assert(string.find(source, "function NTRVehiclePhaseAO.formatRaw(variableName, value)", drawStart, true))
	local drawReplacement = [[function NTRVehiclePhaseAO.drawBar(parent, name, value, baseValue, y)
	-- NTR_GARAGE_CANONICAL_LAYOUT_V3
	local numericValue = tonumber(value) or 0
	local numericBase = tonumber(baseValue) or numericValue
	local difference = numericValue - numericBase
	local deltaText = "-"
	if math.abs(difference) >= 0.05 then deltaText = (difference > 0 and "+" or "") .. tostring(math.round(difference)) end
	if State.Stage ~= "CockpitShop" then
		label(parent, string.upper(tostring(name)), UDim2.new(0.29, 0, 0, 18), UDim2.fromOffset(0, y), 8, Enum.TextXAlignment.Left)
		local bar = new("Frame", { BackgroundColor3 = Color3.fromRGB(39, 48, 49), BorderSizePixel = 0, Size = UDim2.new(0.40, 0, 0, 10), Position = UDim2.new(0.29, 0, 0, y + 4) }, parent)
		corner(bar, 3)
		local amount = math.clamp(numericValue / 100, 0, 1)
		local fill = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(amount, 1) }, bar)
		corner(fill, 3)
		label(parent, tostring(math.floor(numericValue + 0.5)), UDim2.new(0.14, 0, 0, 18), UDim2.new(0.71, 0, 0, y), 9, Enum.TextXAlignment.Right)
		local deltaLabel = label(parent, deltaText, UDim2.new(0.13, 0, 0, 18), UDim2.new(0.87, 0, 0, y), 9, Enum.TextXAlignment.Right)
		deltaLabel.TextColor3 = difference > 0.05 and Color3.fromRGB(84, 255, 126) or difference < -0.05 and Color3.fromRGB(230, 90, 98) or Theme.Muted
		return
	end
	label(parent, string.upper(tostring(name)), UDim2.new(0.58, 0, 0, 18), UDim2.fromOffset(0, y), 8, Enum.TextXAlignment.Left)
	label(parent, tostring(math.floor(numericValue + 0.5)), UDim2.new(0.20, 0, 0, 18), UDim2.new(0.58, 0, 0, y), 9, Enum.TextXAlignment.Right)
	local deltaLabel = label(parent, deltaText, UDim2.new(0.20, 0, 0, 18), UDim2.new(0.80, 0, 0, y), 9, Enum.TextXAlignment.Right)
	deltaLabel.TextColor3 = difference > 0.05 and Color3.fromRGB(84, 255, 126) or difference < -0.05 and Color3.fromRGB(230, 90, 98) or Theme.Muted
	local bar = new("Frame", { Name = "NTRGarageStatTrack", BackgroundColor3 = Color3.fromRGB(39, 48, 49), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, y + 21) }, parent)
	corner(bar, 5)
	local reference = math.max(1, tonumber(parent:GetAttribute("NTRGarageStatReference")) or 180)
	local amount = math.clamp(numericValue / reference, 0, 1)
	local fill = new("Frame", { Name = "NTRGarageStatFill", BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(amount, 1) }, bar)
	corner(fill, 5)
end

]]
	source = string.sub(source, 1, drawStart - 1) .. drawReplacement .. string.sub(source, drawEnd)
	source = replaceOnce(source, [[			y += 28]], [[			y += State.Stage == "CockpitShop" and 40 or 28]], "Garage stat row spacing")
	source = replaceOnce(source,
		[[local nameText = tostring(row.Cockpit.DisplayName or row.CockpitId) .. " #" .. tostring(index)]],
		[[local nameText = tostring(row.Cockpit.DisplayName or row.CockpitId)]],
		"Owned card full name")
	source = replaceOnce(source,
		[[	applyDealershipLayout()
	clear(UI.StatsPanel)]],
		[[	applyDealershipLayout()
	if UI.VehicleActionButton then UI.VehicleActionButton:Destroy(); UI.VehicleActionButton = nil end
	clear(UI.StatsPanel)]],
		"Stable vehicle action cleanup")
	source = replaceOnce(source,
		[[local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, panelActionH), UDim2.new(0, 0, 1, -panelActionPad - panelActionH), Theme.Buy)]],
		[[local customiseButton = button(UI.CockpitShop, "Customise", UDim2.fromOffset(180, 36), UDim2.fromOffset(0, 0), Theme.Buy)
		customiseButton.Name = "VehicleActionButton"
		UI.VehicleActionButton = customiseButton]],
		"Stable customise action owner")
	source = replaceOnce(source,
		[[local actionButton = button(UI.StatsPanel, actionText, UDim2.new(1, 0, 0, panelActionH), UDim2.new(0, 0, 1, -panelActionPad - panelActionH), Theme.Buy)]],
		[[local actionButton = button(UI.CockpitShop, actionText, UDim2.fromOffset(180, 36), UDim2.fromOffset(0, 0), Theme.Buy)
	actionButton.Name = "VehicleActionButton"
	UI.VehicleActionButton = actionButton]],
		"Stable purchase action owner")
end
if not string.find(source, "NTR_GARAGE_CANONICAL_PRESENTATION_OWNS_GEOMETRY", 1, true) then
	local geometryStart = assert(string.find(source, "applyDealershipLayout = function()", 1, true), "Garage geometry owner start missing")
	local geometryEnd = assert(string.find(source, "local function renderDealershipPanel()", geometryStart, true), "Garage geometry owner end missing")
	local geometryReplacement = [[applyDealershipLayout = function()
	-- NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_OWNER
	-- NTR_GARAGE_CANONICAL_PRESENTATION_OWNS_GEOMETRY
	-- The isolated GarageExperienceController owns all cockpit-browser geometry.
	-- Keep only scroll-axis invariants here so render calls cannot restore legacy positions.
	if UI.CockpitGrid then
		UI.CockpitGrid.AutomaticCanvasSize = Enum.AutomaticSize.X
		UI.CockpitGrid.ScrollingDirection = Enum.ScrollingDirection.X
		UI.CockpitGrid.CanvasSize = UDim2.fromOffset(0, 0)
		UI.CockpitGrid.CanvasPosition = Vector2.new(UI.CockpitGrid.CanvasPosition.X, 0)
	end
	if UI.CockpitGridLayout then
		UI.CockpitGridLayout.FillDirection = Enum.FillDirection.Vertical
		UI.CockpitGridLayout.FillDirectionMaxCells = 1
	end
end

]]
	source = string.sub(source, 1, geometryStart - 1) .. geometryReplacement .. string.sub(source, geometryEnd)
end
local ownedOld = 'setCameraSection(State.SelectedSlot or "Engine1")\n\t\t\t\tshowStage("ModuleShop")\n\t\t\t\trenderModuleShop()'
local ownedNew = 'setCameraSection(State.SelectedSlot or "Engine1")\n\t\t\t\tshowStage("CockpitPaint")\n\t\t\t\trenderCockpitPaint() -- NTR_GARAGE_CANONICAL_OWNED_STARTS_AT_PAINT'
local driveOld = 'showStage("ModuleShop")\n\t\trenderModuleShop()\n\tend)\nend\n-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END'
local driveNew = 'showStage("CockpitPaint")\n\t\trenderCockpitPaint() -- NTR_GARAGE_CANONICAL_DRIVE_STARTS_AT_PAINT\n\tend)\nend\n-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END'
if not string.find(source, "NTR_GARAGE_CANONICAL_OWNED_STARTS_AT_PAINT", 1, true) then
	local s,e=string.find(source,ownedOld,1,true); assert(s,"Owned customisation stage anchor missing"); source=string.sub(source,1,s-1)..ownedNew..string.sub(source,e+1)
end
if not string.find(source, "NTR_GARAGE_CANONICAL_DRIVE_STARTS_AT_PAINT", 1, true) then
	local s,e=string.find(source,driveOld,1,true); assert(s,"Drive-in stage anchor missing"); source=string.sub(source,1,s-1)..driveNew..string.sub(source,e+1)
end
assert(countPlain(source, "NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_OWNER") == 1, "Bottom-carousel source audit failed")
assert(countPlain(source, "NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_ARROWS") == 1, "Horizontal carousel-arrow source audit failed")
assert(countPlain(source, "NTR_GARAGE_CANONICAL_EARLY_CAMERA") == 1, "Early camera source audit failed")
assert(countPlain(source, "NTR_GARAGE_CANONICAL_COCKPIT_CAMERA") == 1, "Cockpit-edit camera source audit failed")
assert(countPlain(source, "NTR_GARAGE_CANONICAL_ASCENDING_RATING") == 2, "Ascending-rating source audit failed")
assert(countPlain(source, "NTR_GARAGE_CANONICAL_LEFTMOST_PREVIEW") == 1, "Leftmost-preview source audit failed")
assert(not string.find(source, "return aRating > bRating", 1, true), "Descending rating sort remains")
assert(not string.find(source, "makeArrowScroller(UI.CockpitGridPanel, UI.CockpitGrid, \"Y\", 296)", 1, true), "Vertical cockpit-grid arrows remain")
bootstrap.Source = source
bootstrap:SetAttribute("CanonicalGarageExperienceBridge", MARKER)

local serverActionSource = garageAction.Source
if not string.find(serverActionSource, "NTR_GARAGE_CANONICAL_CATEGORY_PURCHASE", 1, true) then
	local purchaseOld = [[		args = typeof(args) == "table" and args or {}
		local cockpitId = tostring(args.CockpitId or "")
		local cockpit = V56_findCockpit(profile.CurrentCategory, cockpitId)]]
	local purchaseNew = [[		args = typeof(args) == "table" and args or {}
		-- NTR_GARAGE_CANONICAL_CATEGORY_PURCHASE
		local requestedCategory = tostring(args.CategoryId or profile.CurrentCategory or "")
		if requestedCategory ~= "" then profile.CurrentCategory = requestedCategory end
		local cockpitId = tostring(args.CockpitId or "")
		local cockpit = V56_findCockpit(profile.CurrentCategory, cockpitId)]]
	serverActionSource = replaceOnce(serverActionSource, purchaseOld, purchaseNew, "Server category purchase")
	garageAction.Source = serverActionSource
	garageAction:SetAttribute("CanonicalGarageCategoryPurchase", MARKER)
end

assert(oldSession.Name == "GarageSessionService_Active" and entrance.Parent == intro and presentation.Parent == uiControllers, "Post-install hierarchy verification failed")
assert(string.find(presentation.Source, "NTR_GARAGE_CANONICAL_DESIGN_SYSTEM_V3", 1, true), "Garage design-system presentation missing")
assert(string.find(presentation.Source, "GarageGradientOverlay", 1, true) and string.find(presentation.Source, "GarageGlowStroke", 1, true), "Garage gradient/glow presentation missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_OWNED_STARTS_AT_PAINT", 1, true), "Owned flow bridge missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_DRIVE_STARTS_AT_PAINT", 1, true), "Drive-in flow bridge missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_ALL_CATEGORY", 1, true), "All category bridge missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_VEHICLE_CARD_METADATA", 1, true), "Vehicle-card metadata bridge missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_STAT_COLUMNS", 1, true)
	or string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_LAYOUT_V3", 1, true), "Stat renderer missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_BOTTOM_CAROUSEL_OWNER", 1, true), "Bottom-carousel owner missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_EARLY_CAMERA", 1, true), "Early garage camera missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_COCKPIT_CAMERA", 1, true), "Cockpit-edit garage camera missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_ASCENDING_RATING", 1, true), "Ascending rating sort missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_LEFTMOST_PREVIEW", 1, true), "Leftmost preview missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_LAYOUT_V3", 1, true), "Garage V3 stat/action bridge missing")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_PRESENTATION_OWNS_GEOMETRY", 1, true), "Single garage geometry owner missing")
assert(string.find(bootstrap.Source, "VehicleActionButton", 1, true), "Stable vehicle action owner missing")
assert(string.find(garageAction.Source, "NTR_GARAGE_CANONICAL_CATEGORY_PURCHASE", 1, true), "Category purchase bridge missing")
print("[NTR Garage Canonical] INSTALL PASS")
print("[NTR Garage Canonical] Restart Play. Verify the floating carousel, edge arrows, compact header/economy chips, dynamic stats, selected-card BUY/CUSTOMISE popup, mobile scaling, all entry modes, and final spawn.")
