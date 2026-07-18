-- Neo Tokyo Racers - Mobile Racing UI Phase 2: In-Race HUD
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Run INSTALL, restart Play, verify on a touch device, then run SMOKE.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Mobile Racing UI Phase 2"
local MARKER = "NTR_RACING_UI_MOBILE_PHASE2_IN_RACE_HUD"
local REFINEMENT_MARKER = "NTR_RACING_UI_MOBILE_PHASE2_LARGE_SESSION_CONTROLS"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function must(parent, name, className)
	local item = parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. parent:GetFullName() .. "." .. name)
	end
	return item
end

local function replaceOnce(source, anchor, replacement, label)
	if string.find(source, replacement, 1, true) then
		return source
	end
	local first, last = string.find(source, anchor, 1, true)
	if not first then
		fail("Could not find " .. label .. " anchor. Refresh the Studio mirror before another source repair.")
	end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local function replaceAll(source, anchor, replacement, expectedCount, label)
	local count = 0
	local cursor = 1
	local output = {}
	while true do
		local first, last = string.find(source, anchor, cursor, true)
		if not first then break end
		table.insert(output, string.sub(source, cursor, first - 1))
		table.insert(output, replacement)
		cursor = last + 1
		count += 1
	end
	table.insert(output, string.sub(source, cursor))
	if count ~= expectedCount then
		fail(label .. " expected " .. expectedCount .. " anchors, found " .. count .. ". No source was changed.")
	end
	return table.concat(output)
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers")
local config = must(must(must(must(kit, "Config"), "UI"), "Racing"), "InRace")
local starterScripts = must(StarterPlayer, "StarterPlayerScripts")
local clientRoot = must(starterScripts, "NeoTokyoRacersClient")
local controllers = must(clientRoot, "Controllers")
local racing = must(controllers, "Racing")
local ui = must(controllers, "UI")
local session = must(racing, "RaceSessionPresentationController_Active", "LocalScript")
local mobileHud = must(ui, "MobileFreeRoamHudController_Active", "LocalScript")

local defaults = {
	{"BoolValue", "Enabled", true},
	{"NumberValue", "ProgressOffsetX", 30},
	{"NumberValue", "ProgressOffsetY", 150},
	{"NumberValue", "ProgressWidth", 150},
	{"NumberValue", "ProgressHeight", 78},
	{"NumberValue", "MetricOffsetY", 28},
	{"NumberValue", "MetricWidth", 260},
	{"NumberValue", "MetricHeight", 80},
	{"NumberValue", "BoardOffsetX", 24},
	{"NumberValue", "BoardOffsetY", 30},
	{"NumberValue", "BoardWidth", 330},
	{"NumberValue", "BoardHeight", 280},
	{"NumberValue", "MetricHeadingSize", 13},
	{"NumberValue", "MetricValueSize", 30},
	{"NumberValue", "DataRowHeight", 38},
	{"NumberValue", "DataRowGap", 4},
	{"NumberValue", "DataRowTextSize", 14},
	{"NumberValue", "DataRowMetricSize", 15},
	{"NumberValue", "BoardAvatarSize", 27},
	{"NumberValue", "SessionControlsCenterX", 700},
	{"NumberValue", "SessionControlsBottomOffset", 24},
	{"NumberValue", "SessionButtonWidth", 126},
	{"NumberValue", "SessionButtonHeight", 48},
	{"NumberValue", "SessionButtonGap", 18},
	{"NumberValue", "SessionButtonTextSize", 15},
}

local configUpgrades = {
	SessionControlsCenterX = {Old = {800, 760}, New = 700},
	SessionButtonWidth = {Old = 84, New = 126},
	SessionButtonHeight = {Old = 32, New = 48},
	SessionButtonGap = {Old = 6, New = 18},
}

local function ensureConfig()
	local mobile = config:FindFirstChild("Mobile")
	if not mobile then
		mobile = Instance.new("Folder")
		mobile.Name = "Mobile"
		mobile.Parent = config
	elseif not mobile:IsA("Folder") then
		fail(mobile:GetFullName() .. " must be a Folder")
	end
	for _, definition in ipairs(defaults) do
		local className, name, value = table.unpack(definition)
		local existing = mobile:FindFirstChild(name)
		if not existing then
			existing = Instance.new(className)
			existing.Name = name
			existing.Value = value
			existing:SetAttribute("NTRMobileRacingPhase2Created", true)
			existing.Parent = mobile
		elseif not existing:IsA(className) then
			fail(existing:GetFullName() .. " must be a " .. className)
		else
			local upgrade = configUpgrades[name]
			if upgrade and existing:GetAttribute("NTRMobileRacingPhase2Created") == true then
				local oldValues = type(upgrade.Old) == "table" and upgrade.Old or {upgrade.Old}
				if table.find(oldValues, existing.Value) then existing.Value = upgrade.New end
			end
		end
	end
	return mobile
end

local SESSION_SERVICE_ANCHOR = [[local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")]]
local SESSION_SERVICE_REPLACEMENT = [[local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")]]

local SESSION_CONFIG_ANCHOR = [[local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end]]
local SESSION_CONFIG_REPLACEMENT = [[local function N(name,fallback) local item=config:FindFirstChild(name) return item and item:IsA("NumberValue") and item.Value or fallback end
local touch=UserInputService.TouchEnabled
local mobileConfig=config:FindFirstChild("Mobile")
local function MN(name,fallback) local item=mobileConfig and mobileConfig:FindFirstChild(name) return item and (item:IsA("NumberValue") or item:IsA("BoolValue")) and item.Value or fallback end
touch=touch and MN("Enabled",true)
local function HN(name,fallback) return touch and MN(name,fallback) or N(name,fallback) end]]

local SESSION_SUPPRESSION_ANCHOR = [[local suppressed={}
local function suppress(_active) end -- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP]]
local SESSION_SUPPRESSION_REPLACEMENT = [[local suppressed={}
local legacyHudNames={NTR_RaceHud=true,NTR_RaceHud_Phase3=true,NTR_RaceCheckpointBadge_Phase5D=true,NTR_RaceQueue_Phase8=true,NTR_RaceSessionControls_Phase8D=true}
local function suppress(active)
	if not (touch and active) then return end
	for name in pairs(legacyHudNames) do
		local other=playerGui:FindFirstChild(name)
		if other and other:IsA("ScreenGui") then other.Enabled=false end
	end
end -- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP]]

local SESSION_LAYOUT_ANCHOR = [[local left=metricCard(panel("LapProgress",UDim2.fromOffset(N("ProgressOffsetX",30),N("ProgressOffsetY",105)),UDim2.fromOffset(N("ProgressWidth",178),N("ProgressHeight",92))))
local center=metricCard(panel("PrimaryMetric",UDim2.new(.5,-N("MetricWidth",300)/2,0,N("EdgeY",30)),UDim2.fromOffset(N("MetricWidth",300),N("MetricHeight",92))))
local right=borderless(panel("SessionBoard",UDim2.new(1,-N("BoardOffsetX",30)-N("BoardWidth",380),0,N("BoardOffsetY",38)),UDim2.fromOffset(N("BoardWidth",380),N("BoardHeight",300))))
local map=borderless(panel("RaceMap",UDim2.new(0,N("MapOffsetX",30),1,-N("MapOffsetY",30)-N("MapHeight",210)),UDim2.fromOffset(N("MapWidth",280),N("MapHeight",210))))]]
local SESSION_LAYOUT_REPLACEMENT = [[local left=metricCard(panel("LapProgress",touch and UDim2.fromOffset(MN("ProgressOffsetX",30),MN("ProgressOffsetY",150)) or UDim2.fromOffset(N("ProgressOffsetX",30),N("ProgressOffsetY",105)),touch and UDim2.fromOffset(MN("ProgressWidth",150),MN("ProgressHeight",78)) or UDim2.fromOffset(N("ProgressWidth",178),N("ProgressHeight",92))))
local center=metricCard(panel("PrimaryMetric",UDim2.new(.5,-HN("MetricWidth",touch and 260 or 300)/2,0,touch and MN("MetricOffsetY",28) or N("EdgeY",30)),UDim2.fromOffset(HN("MetricWidth",touch and 260 or 300),HN("MetricHeight",touch and 80 or 92))))
local right=borderless(panel("SessionBoard",UDim2.new(1,-HN("BoardOffsetX",touch and 24 or 30)-HN("BoardWidth",touch and 330 or 380),0,HN("BoardOffsetY",touch and 30 or 38)),UDim2.fromOffset(HN("BoardWidth",touch and 330 or 380),HN("BoardHeight",touch and 280 or 300))))
local map=borderless(panel("RaceMap",UDim2.new(0,N("MapOffsetX",30),1,-N("MapOffsetY",30)-N("MapHeight",210)),UDim2.fromOffset(N("MapWidth",280),N("MapHeight",210))))
map.Visible=not touch]]

local SESSION_CONTROLS_ANCHOR = [[local controls=Instance.new("Frame") controls.Name="SessionControls" controls.BackgroundTransparency=1 controls.AnchorPoint=Vector2.new(.5,1) controls.Position=UDim2.new(.5,0,1,-N("BottomY",30)) controls.Size=UDim2.fromOffset(360,38) controls.Parent=canvas
local resetButton=UI.Button(controls,{Text="RESET",Position=UDim2.fromOffset(10,3),Size=UDim2.fromOffset(150,32),Color=C("PanelDeep"),StrokeColor=C("OutlineSoft"),TextSize=13}) resetButton.BackgroundTransparency=.48 resetButton.TextTransparency=.12
local exitButton=UI.Button(controls,{Text="EXIT",Position=UDim2.fromOffset(180,3),Size=UDim2.fromOffset(170,32),Color=C("PanelDeep"),StrokeColor=C("OutlineSoft"),TextSize=13}) exitButton.BackgroundTransparency=.48 exitButton.TextTransparency=.12]]
local SESSION_CONTROLS_REPLACEMENT = [[local controls=Instance.new("Frame") controls.Name="SessionControls" controls.BackgroundTransparency=1 controls.AnchorPoint=Vector2.new(.5,1) controls.Position=UDim2.new(.5,0,1,-N("BottomY",30)) controls.Size=UDim2.fromOffset(360,38) controls.Parent=canvas
local resetButton=UI.Button(controls,{Text="RESET",Position=UDim2.fromOffset(10,3),Size=UDim2.fromOffset(150,32),Color=C("PanelDeep"),StrokeColor=C("OutlineSoft"),TextSize=13}) resetButton.BackgroundTransparency=.48 resetButton.TextTransparency=.12
local exitButton=UI.Button(controls,{Text="EXIT",Position=UDim2.fromOffset(180,3),Size=UDim2.fromOffset(170,32),Color=C("PanelDeep"),StrokeColor=C("OutlineSoft"),TextSize=13}) exitButton.BackgroundTransparency=.48 exitButton.TextTransparency=.12
if touch then
	local buttonWidth=MN("SessionButtonWidth",126) local buttonHeight=MN("SessionButtonHeight",48) local buttonGap=MN("SessionButtonGap",18) local buttonTextSize=MN("SessionButtonTextSize",15)
	controls.Position=UDim2.fromOffset(MN("SessionControlsCenterX",700),1080-MN("SessionControlsBottomOffset",24))
	controls.Size=UDim2.fromOffset(buttonWidth,buttonHeight*2+buttonGap)
	resetButton.Position=UDim2.fromOffset(0,0) resetButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) resetButton.TextSize=buttonTextSize
	exitButton.Position=UDim2.fromOffset(0,buttonHeight+buttonGap) exitButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) exitButton.TextSize=buttonTextSize
end]]

local SESSION_MAP_UPDATE_ANCHOR = [[local function updateHudMapMarker(dt)
	if not active then resetHudMapMarker() return end]]
local SESSION_MAP_UPDATE_REPLACEMENT = [[local function updateHudMapMarker(dt)
	if touch then resetHudMapMarker() return end
	if not active then resetHudMapMarker() return end]]

local SESSION_SHOW_ANCHOR = [[prepareHudMapSession(mode,active.EventId) mapArt.Image=hudMapImage(mode,active.EventId) resetHudMapMarker() canvas.Visible=true]]
local SESSION_SHOW_REPLACEMENT = [[prepareHudMapSession(mode,active.EventId) mapArt.Image=touch and "" or hudMapImage(mode,active.EventId) resetHudMapMarker() canvas.Visible=true]]

local MOBILE_PRESENTATION_ANCHOR = [[local presentationOwners={}
local presentation=uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
if presentation and presentation:IsA("BindableEvent") then presentation.Event:Connect(function(message) if typeof(message)=="table" then local owner=tostring(message.Owner or "Racing"); presentationOwners[owner]=message.Active==true and true or nil else presentationOwners.Racing=tostring(message)=="Racing" and true or nil end end) end]]
local MOBILE_PRESENTATION_REPLACEMENT = [[local presentationOwners={}
local presentation=uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
if presentation and presentation:IsA("BindableEvent") then presentation.Event:Connect(function(message)
	if typeof(message)=="table" then
		local owner=tostring(message.Owner or "Racing")
		presentationOwners[owner]=message.Active==true and {KeepTelemetry=message.KeepTelemetry==true} or nil
	else
		presentationOwners.Racing=tostring(message)=="Racing" and {KeepTelemetry=true} or nil
	end
	if next(presentationOwners)~=nil then if carMenuOpen then setCarMenuOpen(false) end closeModal() end
end) end]]

local MOBILE_RENDER_ANCHOR = [[RunService.RenderStepped:Connect(function(dt)
	suppressExactLegacyHud(); layout(); local hidden=next(presentationOwners)~=nil or majorMenu(); if hidden and carMenuOpen then setCarMenuOpen(false) end; gui.Enabled=not hidden; if hidden then return end
	local driving=drive.IsDriving==true; telemetry.Visible=driving and not carMenuOpen; exitButton.Visible=driving and not carMenuOpen]]
local MOBILE_RENDER_REPLACEMENT = [[RunService.RenderStepped:Connect(function(dt)
	suppressExactLegacyHud(); layout()
	local presentationActive=next(presentationOwners)~=nil
	local telemetryOnly=presentationActive
	for _,state in pairs(presentationOwners) do if not state.KeepTelemetry then telemetryOnly=false break end end
	local hidden=(presentationActive and not telemetryOnly) or majorMenu()
	if hidden and carMenuOpen then setCarMenuOpen(false) end
	gui.Enabled=not hidden
	mapFrame.Visible=not telemetryOnly cash.Visible=not telemetryOnly nav.Visible=not telemetryOnly
	if telemetryOnly then toast.Visible=false end
	if hidden then return end
	local driving=drive.IsDriving==true
	telemetry.Visible=driving and not carMenuOpen
	exitButton.Visible=driving and not carMenuOpen and not telemetryOnly]]

local function patchedSources()
	local sessionSource = session.Source
	local mobileSource = mobileHud.Source
	if string.find(sessionSource, MARKER, 1, true) and string.find(mobileSource, MARKER, 1, true) then
		if string.find(sessionSource, REFINEMENT_MARKER, 1, true) then
			return sessionSource, mobileSource, true
		end
		sessionSource = replaceOnce(sessionSource,
			[[local buttonWidth=MN("SessionButtonWidth",84) local buttonHeight=MN("SessionButtonHeight",32) local buttonGap=MN("SessionButtonGap",6)
	controls.Position=UDim2.fromOffset(MN("SessionControlsCenterX",800),1080-MN("SessionControlsBottomOffset",24))
	controls.Size=UDim2.fromOffset(buttonWidth,buttonHeight*2+buttonGap)
	resetButton.Position=UDim2.fromOffset(0,0) resetButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) resetButton.TextSize=10
	exitButton.Position=UDim2.fromOffset(0,buttonHeight+buttonGap) exitButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) exitButton.TextSize=10]],
			[[local buttonWidth=MN("SessionButtonWidth",126) local buttonHeight=MN("SessionButtonHeight",48) local buttonGap=MN("SessionButtonGap",18) local buttonTextSize=MN("SessionButtonTextSize",15)
	controls.Position=UDim2.fromOffset(MN("SessionControlsCenterX",700),1080-MN("SessionControlsBottomOffset",24))
	controls.Size=UDim2.fromOffset(buttonWidth,buttonHeight*2+buttonGap)
	resetButton.Position=UDim2.fromOffset(0,0) resetButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) resetButton.TextSize=buttonTextSize
	exitButton.Position=UDim2.fromOffset(0,buttonHeight+buttonGap) exitButton.Size=UDim2.fromOffset(buttonWidth,buttonHeight) exitButton.TextSize=buttonTextSize]],
			"installed Phase 2 session-control refinement")
		sessionSource = "-- " .. REFINEMENT_MARKER .. "\n" .. sessionSource
		return sessionSource, mobileSource, false
	end
	if string.find(sessionSource, MARKER, 1, true) ~= string.find(mobileSource, MARKER, 1, true) then
		fail("Partial Phase 2 marker state detected. Refresh the mirror and inspect both isolated controllers before rerunning.")
	end

	sessionSource = replaceOnce(sessionSource, SESSION_SERVICE_ANCHOR, SESSION_SERVICE_REPLACEMENT, "session service")
	sessionSource = replaceOnce(sessionSource, SESSION_CONFIG_ANCHOR, SESSION_CONFIG_REPLACEMENT, "mobile config reader")
	sessionSource = replaceOnce(sessionSource, SESSION_SUPPRESSION_ANCHOR, SESSION_SUPPRESSION_REPLACEMENT, "targeted legacy HUD suppression")
	sessionSource = replaceOnce(sessionSource, SESSION_LAYOUT_ANCHOR, SESSION_LAYOUT_REPLACEMENT, "touch layout")
	sessionSource = replaceOnce(sessionSource, SESSION_CONTROLS_ANCHOR, SESSION_CONTROLS_REPLACEMENT, "vertical reset/exit controls")
	sessionSource = replaceOnce(sessionSource, SESSION_MAP_UPDATE_ANCHOR, SESSION_MAP_UPDATE_REPLACEMENT, "mobile map update gate")
	sessionSource = replaceOnce(sessionSource, SESSION_SHOW_ANCHOR, SESSION_SHOW_REPLACEMENT, "mobile map image gate")
	sessionSource = replaceAll(sessionSource, [[N("MetricHeadingSize",15)]], [[HN("MetricHeadingSize",15)]], 2, "metric heading sizes")
	sessionSource = replaceAll(sessionSource, [[N("MetricValueSize",36)]], [[HN("MetricValueSize",36)]], 2, "metric value sizes")
	sessionSource = replaceAll(sessionSource, [[local rowH=N("DataRowHeight",42) local gap=N("DataRowGap",5)]], [[local rowH=HN("DataRowHeight",42) local gap=HN("DataRowGap",5)]], 2, "board row layout")
	sessionSource = replaceAll(sessionSource, [[N("DataRowTextSize",16)]], [[HN("DataRowTextSize",16)]], 4, "board row text sizes")
	sessionSource = replaceAll(sessionSource, [[N("DataRowMetricSize",18)]], [[HN("DataRowMetricSize",18)]], 2, "board metric sizes")
	sessionSource = replaceAll(sessionSource, [[N("BoardAvatarSize",30)]], [[HN("BoardAvatarSize",30)]], 1, "board avatar size")
	sessionSource = "-- " .. REFINEMENT_MARKER .. "\n-- " .. MARKER .. "\n" .. sessionSource

	mobileSource = replaceOnce(mobileSource, MOBILE_PRESENTATION_ANCHOR, MOBILE_PRESENTATION_REPLACEMENT, "mobile KeepTelemetry state")
	mobileSource = replaceOnce(mobileSource, MOBILE_RENDER_ANCHOR, MOBILE_RENDER_REPLACEMENT, "mobile telemetry-only render state")
	mobileSource = "-- " .. MARKER .. "\n" .. mobileSource
	return sessionSource, mobileSource, false
end

local function install()
	local sessionSource, mobileSource, alreadyInstalled = patchedSources()
	-- Do not change hierarchy or source until every current-source anchor has passed.
	ensureConfig()
	if alreadyInstalled then
		log("Already installed; preserved existing config values.")
		return
	end
	-- Both sources are assigned only after every anchor has passed.
	session.Source = sessionSource
	mobileHud.Source = mobileSource
	log("Installed. PC race HUD is unchanged; touch reuses its top widgets, hides race maps, preserves free-roam telemetry, and uses 1.5x RESET/EXIT controls shifted farther left with an increased vertical gap.")
end

local function smoke()
	local mobile = must(config, "Mobile", "Folder")
	for _, definition in ipairs(defaults) do must(mobile, definition[2], definition[1]) end
	if not string.find(session.Source, MARKER, 1, true) then fail("Race session controller marker missing") end
	if not string.find(session.Source, REFINEMENT_MARKER, 1, true) then fail("Larger session-control refinement marker missing") end
	if not string.find(mobileHud.Source, MARKER, 1, true) then fail("Mobile free-roam HUD controller marker missing") end
	if not string.find(session.Source, "map.Visible=not touch", 1, true) then fail("Touch race-map suppression missing") end
	if not string.find(session.Source, "resetButton.Position=UDim2.fromOffset(0,0)", 1, true) then fail("Vertical RESET/EXIT layout missing") end
	if not string.find(mobileHud.Source, "KeepTelemetry=message.KeepTelemetry==true", 1, true) then fail("Mobile KeepTelemetry bridge missing") end
	if not string.find(mobileHud.Source, "exitButton.Visible=driving and not carMenuOpen and not telemetryOnly", 1, true) then fail("Vehicle EXIT race suppression missing") end
	for _, name in ipairs({"RaceClient_Active", "RaceSessionControlsClient_Active", "RaceHudExitCleanupClient_Active"}) do
		local item = must(racing, name, "LocalScript")
		if not item.Disabled then fail(name .. " must remain retired") end
	end
	log("SMOKE PASS: shared PC race widgets reused on touch, mobile race maps off, legacy owners retired, bottom telemetry preserved, and 1.5x RESET/EXIT controls are stacked without changing drive-control geometry.")
end

if MODE == "INSTALL" then
	install()
elseif MODE == "SMOKE" then
	smoke()
else
	fail("MODE must be INSTALL or SMOKE")
end
