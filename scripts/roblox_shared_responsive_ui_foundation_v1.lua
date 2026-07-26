-- Neo Tokyo Racers - Shared Responsive UI Foundation V1
-- Run in Roblox Studio Edit mode from the Command Bar.
--
-- Modes:
--   INSTALL  - preflight, compile projected sources, mutate transactionally, then audit.
--   AUDIT    - read-only source/config/hierarchy audit.
--
-- This is the single canonical installer for the approved shared visual/layout/state-projection scope.
-- It creates no in-game backup folders or scripts and does not touch vehicle-picker composition.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Roblox Studio Edit mode.")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local TAG = "[NTR Shared Responsive UI V1]"
local REVISION = "NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1"
local MARKER = "-- " .. REVISION
local RUN_ID = HttpService:GenerateGUID(false)

local function countPlain(source, needle)
	local count, cursor = 0, 1
	while true do
		local first, last = source:find(needle, cursor, true)
		if not first then return count end
		count += 1
		cursor = last + 1
	end
end

local function replaceOnce(source, needle, replacement, label)
	assert(type(source) == "string", label .. " source missing")
	assert(countPlain(source, needle) == 1, label .. " anchor count changed for: " .. needle:sub(1, 80))
	local first = assert(source:find(needle, 1, true), label .. " anchor missing")
	return source:sub(1, first - 1) .. replacement .. source:sub(first + #needle)
end

local function insertAfterOnce(source, needle, insertion, label)
	return replaceOnce(source, needle, needle .. insertion, label)
end

local function compile(source, label)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local shared = assert(kit:FindFirstChild("Shared"), "NeoTokyoRacers.Shared missing")
local modules = assert(shared:FindFirstChild("Modules"), "NeoTokyoRacers.Shared.Modules missing")
local uiModules = assert(modules:FindFirstChild("UI"), "NeoTokyoRacers.Shared.Modules.UI missing")
local config = assert(kit:FindFirstChild("Config"), "NeoTokyoRacers.Config missing")
local uiConfig = assert(config:FindFirstChild("UI"), "NeoTokyoRacers.Config.UI missing")
local themeConfig = assert(uiConfig:FindFirstChild("Theme"), "NeoTokyoRacers.Config.UI.Theme missing")

local clientRoot = assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient"),
	"StarterPlayerScripts.NeoTokyoRacersClient missing"
)
local controllers = assert(clientRoot:FindFirstChild("Controllers"), "NeoTokyoRacersClient.Controllers missing")
local uiControllers = assert(controllers:FindFirstChild("UI"), "NeoTokyoRacersClient.Controllers.UI missing")
local racingControllers = assert(controllers:FindFirstChild("Racing"), "NeoTokyoRacersClient.Controllers.Racing missing")

local targets = {
	RacingUI = assert(uiModules:FindFirstChild("RacingUIComponents"), "RacingUIComponents missing"),
	UITheme = assert(uiModules:FindFirstChild("UITheme"), "UITheme missing"),
	UIFactory = assert(uiModules:FindFirstChild("UIFactory"), "UIFactory missing"),
	GarageShared = assert(uiControllers:FindFirstChild("GarageReplacementComponents"), "GarageReplacementComponents missing"),
	GarageWorkspace = assert(uiControllers:FindFirstChild("GarageWorkspaceController"), "GarageWorkspaceController missing"),
	GarageBrowser = assert(uiControllers:FindFirstChild("GarageBrowserController"), "GarageBrowserController missing"),
	ModuleShop = assert(uiControllers:FindFirstChild("ModuleShopUIController"), "ModuleShopUIController missing"),
	OwnedGarageWorkspace = assert(uiControllers:FindFirstChild("OwnedGarageWorkspaceController"), "OwnedGarageWorkspaceController missing"),
	DesktopHud = assert(uiControllers:FindFirstChild("DesktopFreeRoamHudController_Active"), "Desktop free-roam HUD missing"),
	MobileHud = assert(uiControllers:FindFirstChild("MobileFreeRoamHudController_Active"), "Mobile free-roam HUD missing"),
	TopNotification = assert(uiControllers:FindFirstChild("SharedTopNotificationController_Active"), "Shared top-notification owner missing"),
	RaceCountdown = assert(racingControllers:FindFirstChild("RaceCountdownPresentationController_Active"), "Race countdown owner missing"),
	RaceClient = assert(racingControllers:FindFirstChild("RaceClient_Active"), "Race HUD owner missing"),
	RacePersonalBest = assert(racingControllers:FindFirstChild("RacePersonalBestBoardClient_Active"), "Race PB board owner missing"),
	RaceRouteGuide = assert(racingControllers:FindFirstChild("RaceRouteGuideClient_Active"), "Race route guide owner missing"),
	RaceSessionControls = assert(racingControllers:FindFirstChild("RaceSessionControlsClient_Active"), "Race session controls owner missing"),
	RaceSession = assert(racingControllers:FindFirstChild("RaceSessionPresentationController_Active"), "Race session presentation owner missing"),
	RaceResults = assert(racingControllers:FindFirstChild("RaceTimeTrialResultCoachClient_Active"), "Race result owner missing"),
}

for label, object in pairs(targets) do
	assert(object:IsA("LuaSourceContainer"), label .. " must be a LuaSourceContainer")
	if object:IsA("LocalScript") then assert(object.Disabled == false, label .. " must remain enabled") end
end

local FOUNDATION_SOURCE = [==[
-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")

local M={}
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local theme=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Theme")

local function number(name,fallback)
	local child=theme:FindFirstChild(name)
	if child and child:IsA("NumberValue") then return tonumber(child.Value) or fallback end
	local value=theme:GetAttribute(name)
	return typeof(value)=="number" and value or fallback
end

function M.IsMobile()
	return UserInputService.TouchEnabled
end

function M.CornerScale()
	return M.IsMobile() and number("CornerScaleMobile",.5) or number("CornerScaleDesktop",.7)
end

function M.CornerRadius(baseRadius)
	return math.max(0,(tonumber(baseRadius) or 0)*M.CornerScale())
end

function M.SetCorner(corner,baseRadius)
	assert(corner and corner:IsA("UICorner"),"SetCorner requires a UICorner")
	corner:SetAttribute("NTRBaseCornerRadius",tonumber(baseRadius) or 0)
	corner.CornerRadius=UDim.new(0,M.CornerRadius(baseRadius))
	return corner
end

function M.Corner(parent,baseRadius)
	local corner=Instance.new("UICorner")
	M.SetCorner(corner,baseRadius)
	corner.Parent=parent
	return corner
end

function M.FormatNumber(value)
	local numeric=tonumber(value) or 0
	local negative=numeric<0
	local digits=tostring(math.floor(math.abs(numeric)+.5))
	local reversed=string.gsub(string.reverse(digits),"(%d%d%d)","%1,")
	local grouped=string.gsub(string.reverse(reversed),"^,","")
	return (negative and "-" or "")..grouped
end

function M.FormatCompactMoney(value)
	local amount=math.max(0,math.floor(tonumber(value) or 0))
	if amount<1000000 then return "$"..M.FormatNumber(amount) end
	local tenths=math.floor(amount/100000)
	return "$"..string.format("%.1f",tenths/10).."M"
end

function M.StyleMetric(label,kind)
	assert(label and (label:IsA("TextLabel") or label:IsA("TextButton")),"StyleMetric requires text UI")
	label:SetAttribute("NTRSharedMetric",true)
	label:SetAttribute("NTRMetricKind",tostring(kind or "Metric"))
	label.TextWrapped=false
	label.TextTruncate=Enum.TextTruncate.None
	pcall(function()
		label.FontFace=Font.new("rbxasset://fonts/families/Michroma.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
	end)
	return label
end

function M.ProjectEconomy(response,fallback)
	local result=type(fallback)=="table" and {
		Cash=tonumber(fallback.Cash),
		Used=tonumber(fallback.Used),
		Capacity=tonumber(fallback.Capacity),
	} or {}
	if type(response)~="table" then return result end
	local profile=type(response.Profile)=="table" and response.Profile or nil
	local management=type(response.ManagementState)=="table" and response.ManagementState
		or (response.InGarage~=nil and response.Properties and response or nil)
	if tonumber(response.Cash) then result.Cash=tonumber(response.Cash) end
	if profile then
		result.Cash=tonumber(profile.Cash) or result.Cash
		local garage=type(profile.Garage)=="table" and profile.Garage or {}
		result.Used=tonumber(garage.OwnedVehicleCount) or result.Used
		result.Capacity=tonumber(garage.Capacity) or tonumber(profile.GarageCapacity) or result.Capacity
	end
	if management then
		result.Cash=tonumber(management.Cash) or result.Cash
		local currentId=tostring(management.CurrentPropertyId or "")
		for _,property in ipairs(management.Properties or {}) do
			if currentId=="" or tostring(property.PropertyId or "")==currentId then
				result.Used=tonumber(property.Filled) or result.Used
				result.Capacity=tonumber(property.Capacity) or result.Capacity
				if currentId~="" then break end
			end
		end
	end
	return result
end

function M.BindReplicatedCash(player,callback)
	player=player or Players.LocalPlayer
	assert(player and type(callback)=="function","BindReplicatedCash requires player and callback")
	local connections={}
	local valueConnection
	local stopped=false
	local function disconnectValue()
		if valueConnection then valueConnection:Disconnect(); valueConnection=nil end
	end
	local function bind()
		if stopped then return false end
		disconnectValue()
		local stats=player:FindFirstChild("leaderstats")
		local cash=stats and stats:FindFirstChild("Cash")
		if not (cash and (cash:IsA("IntValue") or cash:IsA("NumberValue"))) then return false end
		local function publish() if not stopped then callback(tonumber(cash.Value) or 0,cash) end end
		publish()
		valueConnection=cash:GetPropertyChangedSignal("Value"):Connect(publish)
		return true
	end
	table.insert(connections,player.ChildAdded:Connect(function(child)
		if child.Name=="leaderstats" then
			table.insert(connections,child.ChildAdded:Connect(function(value) if value.Name=="Cash" then bind() end end))
			bind()
		end
	end))
	local stats=player:FindFirstChild("leaderstats")
	if stats then table.insert(connections,stats.ChildAdded:Connect(function(value) if value.Name=="Cash" then bind() end end)) end
	bind()
	return function()
		stopped=true
		disconnectValue()
		for _,connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
	end
end

local function rootLogicalSize(root)
	local absolute=root.AbsoluteSize
	local width=root.Size.X.Offset>0 and root.Size.X.Offset or absolute.X
	local height=root.Size.Y.Offset>0 and root.Size.Y.Offset or absolute.Y
	return Vector2.new(math.max(1,width),math.max(1,height)),Vector2.new(math.max(1,absolute.X),math.max(1,absolute.Y))
end

function M.Confirmation(root,options,components)
	options=options or {}
	assert(root and root:IsA("GuiObject"),"Confirmation requires a GuiObject root")
	assert(type(components)=="table","Confirmation requires shared UI components")
	local oldSelection=GuiService.SelectedObject
	local connections={}
	local closed=false
	local exitAction="NTRSharedConfirmationExit_"..tostring(os.clock())
	local shade=Instance.new("Frame")
	shade.Name="NTRSharedConfirmation"
	shade.Active=true
	shade.BackgroundColor3=Color3.new(0,0,0)
	shade.BackgroundTransparency=.22
	shade.BorderSizePixel=0
	shade.Size=UDim2.fromScale(1,1)
	shade.ZIndex=300
	shade.Parent=root
	local panel=components.Panel(shade,{Name="Panel",StrokeColor=components.Colour("ElectricBlue"),NoGlow=true})
	panel.AnchorPoint=Vector2.new(.5,.5)
	panel.ZIndex=301
	local title=components.Label(panel,{Text=options.Title or "CONFIRM",TextSize=22,Role="Heading",XAlignment=Enum.TextXAlignment.Center})
	title.ZIndex=302
	local body=components.Label(panel,{Text=options.Body or "Continue?",TextSize=14,XAlignment=Enum.TextXAlignment.Center,Wrapped=true})
	body.ZIndex=302
	local no=components.Button(panel,{Text=options.CancelText or "NO",Color=Color3.fromRGB(116,120,128),ZIndex=303})
	local yes=components.Button(panel,{Text=options.ConfirmText or "YES",Color=components.Colour("PanelBlue"),StrokeColor=components.Colour("ElectricBlue"),ZIndex=303})
	no.Selectable=true
	yes.Selectable=true
	no.NextSelectionRight=yes
	yes.NextSelectionLeft=no

	local function disconnect()
		ContextActionService:UnbindAction(exitAction)
		for _,connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
	end
	local function close(confirmed)
		if closed then return end
		closed=true
		disconnect()
		if GuiService.SelectedObject==no or GuiService.SelectedObject==yes then GuiService.SelectedObject=oldSelection end
		shade:Destroy()
		if confirmed then
			if options.OnConfirm then options.OnConfirm() end
		elseif options.OnCancel then options.OnCancel() end
	end
	local function relayout()
		if closed or not shade.Parent then return end
		local logical,absolute=rootLogicalSize(root)
		local topLeft,bottomRight=GuiService:GetGuiInset()
		local sx=logical.X/absolute.X
		local sy=logical.Y/absolute.Y
		local safeLeft=math.max(12,topLeft.X*sx+12)
		local safeRight=math.max(12,bottomRight.X*sx+12)
		local safeTop=math.max(12,topLeft.Y*sy+12)
		local safeBottom=math.max(12,bottomRight.Y*sy+12)
		local width=math.max(280,math.min(620,logical.X-safeLeft-safeRight))
		local height=math.max(230,math.min(320,logical.Y-safeTop-safeBottom))
		panel.Position=UDim2.fromOffset(safeLeft+(logical.X-safeLeft-safeRight)*.5,safeTop+(logical.Y-safeTop-safeBottom)*.5)
		panel.Size=UDim2.fromOffset(width,height)
		title.Position=UDim2.fromOffset(24,22)
		title.Size=UDim2.new(1,-48,0,42)
		body.Position=UDim2.fromOffset(32,72)
		body.Size=UDim2.new(1,-64,1,-150)
		local gap=math.max(12,math.min(24,width*.035))
		local buttonWidth=math.max(112,math.min(190,(width-64-gap)*.5))
		local buttonHeight=math.max(48,M.IsMobile() and 52 or 48)
		no.AnchorPoint=Vector2.new(1,1)
		no.Position=UDim2.new(.5,-gap*.5,1,-24)
		no.Size=UDim2.fromOffset(buttonWidth,buttonHeight)
		yes.AnchorPoint=Vector2.new(0,1)
		yes.Position=UDim2.new(.5,gap*.5,1,-24)
		yes.Size=UDim2.fromOffset(buttonWidth,buttonHeight)
	end
	no.Activated:Connect(function() close(false) end)
	yes.Activated:Connect(function() close(true) end)
	ContextActionService:BindActionAtPriority(exitAction,function(_,state)
		if state==Enum.UserInputState.Begin then close(false) end
		return Enum.ContextActionResult.Sink
	end,false,10000,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
	table.insert(connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout))
	local camera=Workspace.CurrentCamera
	if camera then table.insert(connections,camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)) end
	relayout()
	task.defer(function() if not closed and no.Parent then GuiService.SelectedObject=no end end)
	return {Root=shade,Cancel=function() close(false) end,Confirm=function() close(true) end,Relayout=relayout}
end

function M.CreateTopNotificationController(playerGui)
	assert(playerGui and playerGui:IsA("PlayerGui"),"Top notification controller requires PlayerGui")
	local old=playerGui:FindFirstChild("NTR_SharedTopNotification")
	if old then old:Destroy() end
	local gui=Instance.new("ScreenGui")
	gui.Name="NTR_SharedTopNotification"
	gui.ResetOnSpawn=false
	gui.IgnoreGuiInset=true
	gui.DisplayOrder=1100
	gui.Parent=playerGui
	local stack=Instance.new("Frame")
	stack.Name="Stack"
	stack.AnchorPoint=Vector2.new(.5,0)
	stack.BackgroundTransparency=1
	stack.BorderSizePixel=0
	stack.AutomaticSize=Enum.AutomaticSize.Y
	stack.Parent=gui
	local layout=Instance.new("UIListLayout")
	layout.Padding=UDim.new(0,6)
	layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
	layout.SortOrder=Enum.SortOrder.LayoutOrder
	layout.Parent=stack
	local cards={}
	local serial=0
	local maxCards=math.max(1,math.floor(number("TopNotificationMaxCards",3)))
	local function relayout()
		local camera=Workspace.CurrentCamera
		local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
		local topLeft=GuiService:GetGuiInset()
		local mobile=M.IsMobile()
		local side=mobile and 12 or 24
		local width=math.min(mobile and 540 or 620,math.max(260,viewport.X-side*2))
		local height=mobile and (viewport.X>viewport.Y and 44 or 52) or 48
		stack.Position=UDim2.fromOffset(viewport.X*.5,math.max(12,topLeft.Y+10))
		stack.Size=UDim2.fromOffset(width,0)
		for _,card in ipairs(cards) do if card.Parent then card.Size=UDim2.fromOffset(width,height) end end
	end
	local camera=Workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout) end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local current=Workspace.CurrentCamera
		if current then current:GetPropertyChangedSignal("ViewportSize"):Connect(relayout) end
		relayout()
	end)
	local function remove(card)
		local index=table.find(cards,card)
		if index then table.remove(cards,index) end
		if card.Parent then card:Destroy() end
	end
	local function show(message,duration)
		local text=string.upper(tostring(message or ""))
		if text=="" then return end
		serial+=1
		while #cards>=maxCards do remove(cards[1]) end
		local card=Instance.new("TextLabel")
		card.Name="Message"..serial
		card.LayoutOrder=serial
		card.BackgroundColor3=Color3.fromRGB(72,76,84)
		card.BackgroundTransparency=.04
		card.BorderSizePixel=0
		card.Text=text
		card.TextColor3=Color3.new(1,1,1)
		card.TextSize=M.IsMobile() and 12 or 14
		card.TextWrapped=true
		card.ZIndex=2
		pcall(function() card.FontFace=Font.new("rbxasset://fonts/families/Michroma.json",Enum.FontWeight.Bold) end)
		card.Parent=stack
		M.Corner(card,6)
		local gradient=Instance.new("UIGradient")
		gradient.Name="GreyGradient"
		gradient.Color=ColorSequence.new(Color3.fromRGB(105,109,117),Color3.fromRGB(48,52,60))
		gradient.Rotation=90
		gradient.Parent=card
		table.insert(cards,card)
		relayout()
		task.delay(math.clamp(tonumber(duration) or 2.5,.5,10),function() remove(card) end)
	end
	relayout()
	return {Gui=gui,Show=show,Relayout=relayout,Count=function() return #cards end}
end

return M
]==]

local TOP_NOTIFICATION_SOURCE = [==[
-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Foundation=require(kit.Shared.Modules.UI:WaitForChild("ResponsiveUIFoundation"))
local event=script.Parent:FindFirstChild("ShowTopNotification") or Instance.new("BindableEvent")
event.Name="ShowTopNotification"
event.Parent=script.Parent
local controller=Foundation.CreateTopNotificationController(playerGui)
event.Event:Connect(function(message,duration)
	controller.Show(message,duration)
end)
]==]

local projected = {}
local function project(label, transform)
	local source = targets[label].Source
	if countPlain(source, MARKER) > 0 then projected[label] = source return end
	local nextSource = transform(source)
	compile(nextSource, label)
	projected[label] = nextSource
end

project("UITheme", function(source)
	source=insertAfterOnce(source,
		"local UITheme = {}",
		"\nlocal Foundation = require(script.Parent:WaitForChild(\"ResponsiveUIFoundation\"))",
		"UITheme")
	source=insertAfterOnce(source,
		"\tButtonCornerRadius = 4,",
		"\n\tCornerScaleDesktop = .7,\n\tCornerScaleMobile = .5,",
		"UITheme defaults")
	source=insertAfterOnce(source,
		"\t\tButtonCornerRadius = number(folder, \"ButtonCornerRadius\", defaults.ButtonCornerRadius, 0),",
		"\n\t\tCornerScaleDesktop = number(folder, \"CornerScaleDesktop\", defaults.CornerScaleDesktop, 0, 1),\n\t\tCornerScaleMobile = number(folder, \"CornerScaleMobile\", defaults.CornerScaleMobile, 0, 1),",
		"UITheme read")
	source=replaceOnce(source,"return UITheme",MARKER.."\nUITheme.CornerRadius=Foundation.CornerRadius\nUITheme.Corner=Foundation.Corner\nUITheme.SetCorner=Foundation.SetCorner\n\nreturn UITheme","UITheme return")
	return source
end)

project("UIFactory", function(source)
	source=insertAfterOnce(source,
		"local UITheme = require(script.Parent:WaitForChild(\"UITheme\"))",
		"\nlocal Foundation = require(script.Parent:WaitForChild(\"ResponsiveUIFoundation\"))",
		"UIFactory require")
	source=replaceOnce(source,
		"function UIFactory.Corner(parent, radius)\n\tlocal corner = Instance.new(\"UICorner\")\n\tcorner.CornerRadius = UDim.new(0, radius or 4)\n\tcorner.Parent = parent\n\treturn corner\nend",
		"function UIFactory.Corner(parent, radius)\n\treturn Foundation.Corner(parent, radius or 4)\nend",
		"UIFactory corner")
	source=replaceOnce(source,"return UIFactory",MARKER.."\nUIFactory.FormatMoney=Foundation.FormatCompactMoney\nUIFactory.StyleMetric=Foundation.StyleMetric\n\nreturn UIFactory","UIFactory return")
	return source
end)

project("RacingUI", function(source)
	source=insertAfterOnce(source,
		"local kit = ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")",
		"\nlocal Foundation = require(kit:WaitForChild(\"Shared\"):WaitForChild(\"Modules\"):WaitForChild(\"UI\"):WaitForChild(\"ResponsiveUIFoundation\"))",
		"RacingUI require")
	source=replaceOnce(source,
		"function Components.Corner(parent, radius)\n\tlocal corner = Instance.new(\"UICorner\")\n\tcorner.CornerRadius = UDim.new(0, radius or Components.Layout(\"CornerRadius\", 5))\n\tcorner.Parent = parent\n\treturn corner\nend",
		"function Components.Corner(parent, radius)\n\treturn Foundation.Corner(parent, radius or Components.Layout(\"CornerRadius\", 5))\nend",
		"RacingUI corner")
	source=replaceOnce(source,
		"return Components",
		MARKER.."\nComponents.SetCorner=Foundation.SetCorner\nComponents.FormatMoney=Foundation.FormatCompactMoney\nComponents.ProjectEconomy=Foundation.ProjectEconomy\nComponents.BindReplicatedCash=Foundation.BindReplicatedCash\nfunction Components.MetricLabel(parent,properties)\n\tproperties=properties or {}\n\tproperties.Role=\"Metric\"\n\tlocal label=Components.Label(parent,properties)\n\treturn Foundation.StyleMetric(label,properties.Kind)\nend\nfunction Components.ConfirmationModal(root,options)\n\treturn Foundation.Confirmation(root,options,Components)\nend\n\nreturn Components",
		"RacingUI return")
	return source
end)

project("GarageShared", function(source)
	source=replaceOnce(source,
		"function M.FormatMoney(value) return \"$\"..M.FormatNumber(value) end",
		"function M.FormatMoney(value) return Racing.FormatMoney(value) end\nfunction M.ProjectEconomy(response,fallback) return Racing.ProjectEconomy(response,fallback) end\nfunction M.EconomyMetric(parent,props) return Racing.MetricLabel(parent,props) end",
		"Garage shared money")
	source=replaceOnce(source,
		"if corner then corner.CornerRadius=UDim.new(0,metricNumber(\"MetricCardCornerRadius\",9)) end",
		"if corner then Racing.SetCorner(corner,metricNumber(\"MetricCardCornerRadius\",9)) end",
		"Garage shared metric corner")
	local first=assert(source:find("function M.ConfirmationModal(root,options)",1,true),"Garage confirmation start missing")
	local last=assert(source:find("\nend\n\n-- NTR_OWNED_GARAGE_ANCHORED_DROPDOWN_V2",first,true),"Garage confirmation end missing")
	source=source:sub(1,first-1).."function M.ConfirmationModal(root,options)\n\treturn Racing.ConfirmationModal(root,options)\nend"..source:sub(last+5)
	source=replaceOnce(source,"return M",MARKER.."\nreturn M","Garage shared return")
	return source
end)

project("GarageWorkspace", function(source)
	source=insertAfterOnce(source,
		"local outline=Racing.Colour(\"ElectricBlue\",Color3.fromRGB(25,116,255)); self.Cash=Shared.Panel(self.Economy,\"Cash\",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true}); self.Capacity=Shared.Panel(self.Economy,\"Capacity\",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true})",
		"\n\tself.StopCashBinding=Racing.BindReplicatedCash(nil,function(value) if self.Root.Visible and self.CashValue and self.CashValue.Parent then self.CashValue.Text=Shared.FormatMoney(value) end end)",
		"Garage workspace Cash reconciliation")
	source=replaceOnce(source,
		"generated(Racing.Label(self.Cash,{Text=Shared.FormatMoney(context.Cash or 0)",
		"self.CashValue=generated(Shared.EconomyMetric(self.Cash,{Kind=\"Cash\",Text=Shared.FormatMoney(context.Cash or 0)",
		"Garage workspace Cash metric")
	source=replaceOnce(source,
		"generated(Racing.Label(self.Capacity,{Text=context.CapacityText or \"0/0 Spaces\"",
		"generated(Shared.EconomyMetric(self.Capacity,{Kind=\"GarageSpaces\",Text=context.CapacityText or \"0/0 Spaces\"",
		"Garage workspace Spaces metric")
	return MARKER.."\n"..source
end)

project("GarageBrowser", function(source)
	source=insertAfterOnce(source,
		"local economyOutline=Racing.Colour(\"ElectricBlue\",Color3.fromRGB(25,116,255)); self.Cash=Shared.Panel(self.Economy,\"Cash\",{StrokeColor=economyOutline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true}); self.Capacity=Shared.Panel(self.Economy,\"Capacity\",{StrokeColor=economyOutline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true})",
		"\n\tself.StopCashBinding=Racing.BindReplicatedCash(player,function(value) if self.Root.Visible and self.CashValue and self.CashValue.Parent then self.CashValue.Text=Shared.FormatMoney(value) end end)",
		"Garage browser Cash reconciliation")
	source=replaceOnce(source,
		"local cash=generated(Racing.Label(self.Cash,{Text=Shared.FormatMoney(context.Cash or 0)",
		"self.CashValue=generated(Shared.EconomyMetric(self.Cash,{Kind=\"Cash\",Text=Shared.FormatMoney(context.Cash or 0)",
		"Garage browser Cash metric")
	source=replaceOnce(source,")); cash.Name=\"CashValue\";", ")); self.CashValue.Name=\"CashValue\";", "Garage browser Cash reference")
	source=replaceOnce(source,
		"generated(Racing.Label(self.Capacity,{Text=context.CapacityText or \"0/0 Spaces\"",
		"generated(Shared.EconomyMetric(self.Capacity,{Kind=\"GarageSpaces\",Text=context.CapacityText or \"0/0 Spaces\"",
		"Garage browser Spaces metric")
	return MARKER.."\n"..source
end)

project("ModuleShop", function(source)
	source=replaceOnce(source,
		"if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end",
		"if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end; self.State.Economy=Shared.ProjectEconomy(result,self.State.Economy)",
		"Module shop authoritative transaction projection")
	return MARKER.."\n"..source
end)

project("OwnedGarageWorkspace", function(source)
	source=replaceOnce(source,
		"if ok and type(result)==\"table\" then return result end; return {Success=false,Message=\"Garage management is unavailable.\"} end",
		"if ok and type(result)==\"table\" then local economy=Shared.ProjectEconomy(result,state and {Cash=state.Cash} or nil); result.ProjectedEconomy=economy; if state and economy.Cash then state.Cash=economy.Cash end; return result end; return {Success=false,Message=\"Garage management is unavailable.\"} end",
		"Owned garage authoritative transaction projection")
	return MARKER.."\n"..source
end)

local function projectFreeRoam(source,label,mobile)
	local kitAnchor=mobile
		and "local kit=ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")"
		or "local kit = ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")"
	source=insertAfterOnce(source,kitAnchor,
		mobile
			and "\nlocal SharedUI=require(kit.Shared.Modules.UI:WaitForChild(\"RacingUIComponents\"))\nlocal Foundation=require(kit.Shared.Modules.UI:WaitForChild(\"ResponsiveUIFoundation\"))"
			or "\nlocal SharedUI = require(kit.Shared.Modules.UI:WaitForChild(\"RacingUIComponents\"))\nlocal Foundation = require(kit.Shared.Modules.UI:WaitForChild(\"ResponsiveUIFoundation\"))",
		label.." foundation require")
	if mobile then
		source=replaceOnce(source,
			"local function corner(parent,r) return new(\"UICorner\",{CornerRadius=UDim.new(0,r or 10)},parent) end",
			"local function corner(parent,r) return Foundation.Corner(parent,r or 10) end",
			label.." corner")
		source=replaceOnce(source,
			"local function bindCash() local stats=player:FindFirstChild(\"leaderstats\"); local value=stats and stats:FindFirstChild(\"Cash\"); if not value then return false end; local function update() cashText.Text=\"$\"..tostring(math.floor(tonumber(value.Value) or 0)) end; update(); value:GetPropertyChangedSignal(\"Value\"):Connect(update); return true end\nif not bindCash() then task.spawn(function() local stats=player:WaitForChild(\"leaderstats\",15); if stats then stats:WaitForChild(\"Cash\",15) end; bindCash() end) end",
			"Foundation.StyleMetric(cashText,\"Cash\")\nFoundation.BindReplicatedCash(player,function(value) cashText.Text=Foundation.FormatCompactMoney(value) end)",
			label.." replicated Cash")
		source=replaceOnce(source,
			"local cash=panel(root,\"Cash\",UDim2.fromOffset(170,34),UDim2.fromOffset(0,0),5); cash.BackgroundColor3=Color3.fromRGB(8,42,84); cash.ClipsDescendants=true;",
			"local cash=panel(root,\"Cash\",UDim2.fromOffset(170,34),UDim2.fromOffset(0,0),5); cash.BackgroundColor3=Color3.fromRGB(8,42,84); cash.ClipsDescendants=true; local cashStroke=cash:FindFirstChildOfClass(\"UIStroke\"); if cashStroke then cashStroke.Color=BLUE end;",
			label.." Cash surface")
		local confirmStart=assert(source:find("local teleportBusy=false\nlocal function showTeleport()",1,true),label.." confirmation start missing")
		local confirmEnd=assert(source:find("\n\n\nlocal profileCache=nil",confirmStart,true),label.." confirmation end missing")
		local replacement=[==[local teleportBusy=false
local function showTeleport()
	Foundation.Confirmation(root,{
		Title="TELEPORT TO DEALERSHIP?",
		Body="Your current vehicle will be despawned.",
		ConfirmText="YES",
		CancelText="NO",
		OnConfirm=function()
			if teleportBusy then return end
			teleportBusy=true
			local generation=loadingAction("Begin",{Destination="DealershipExterior",Status="TRAVELLING TO DEALERSHIP"})
			local ok,result=pcall(function() return teleportInvoke:InvokeServer("TeleportToDealership") end)
			if ok and typeof(result)=="table" and result.Success then
				fire("FreeRoamVehicleExited")
				loadingAction("Complete",{Generation=generation,Status="READY"})
				showToast(result.Message or "TELEPORTED",true)
			else
				local message=typeof(result)=="table" and (result.Message or result.Error) or "TELEPORT FAILED"
				loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=message})
				showToast(message,false)
			end
			teleportBusy=false
		end,
	},SharedUI)
end]==]
		source=source:sub(1,confirmStart-1)..replacement..source:sub(confirmEnd)
	else
		source=replaceOnce(source,
			"local function corner(parent, radius)\n\treturn new(\"UICorner\", { CornerRadius = UDim.new(0, radius or 6) }, parent)\nend",
			"local function corner(parent, radius)\n\treturn Foundation.Corner(parent, radius or 6)\nend",
			label.." corner")
		local formatStart=assert(source:find("local function formatCash(value)",1,true),label.." formatCash start missing")
		local formatEnd=assert(source:find("\nend\n\nlocal function callGarage",formatStart,true),label.." formatCash end missing")
		source=source:sub(1,formatStart-1).."local function formatCash(value)\n\treturn Foundation.FormatCompactMoney(value)\nend"..source:sub(formatEnd+5)
		source=replaceOnce(source,
			"moneyLabel = label(money, \"Amount\", \"$0\", UDim2.new(1, -52, 1, 0), UDim2.fromOffset(12, 0), T(\"CashMetric\", 18), C(\"Text\"))",
			"moneyLabel = Foundation.StyleMetric(label(money, \"Amount\", \"$0\", UDim2.new(1, -52, 1, 0), UDim2.fromOffset(12, 0), T(\"CashMetric\", 18), C(\"Text\")),\"Cash\")",
			label.." Cash metric")
		local sharedConfirm=[==[
local function showSharedTeleportConfirmation()
	Foundation.Confirmation(root,{
		Title="TELEPORT TO DEALERSHIP?",
		Body="Your current vehicle will be despawned.",
		ConfirmText="YES",
		CancelText="NO",
		OnConfirm=function()
			if busy then return end
			busy = true
			local generation = loadingAction("Begin", { Destination = "DealershipExterior", Status = "TRAVELLING TO DEALERSHIP" })
			local ok, result = pcall(function()
				return teleportInvoke:InvokeServer("TeleportToDealership")
			end)
			if ok and typeof(result) == "table" and result.Success == true then
				fireUiEvent("FreeRoamVehicleExited")
				lastProfileRead = 0
				loadingAction("Complete", { Generation = generation, Status = "READY" })
				showToast(result.Message or "TELEPORTED TO DEALERSHIP", true)
			else
				local message = (typeof(result) == "table" and (result.Message or result.Error)) or "DEALERSHIP TELEPORT FAILED"
				loadingAction("Fail", { Generation = generation, Status = "RETURNING", Reason = message })
				showToast(message, false)
			end
			busy = false
		end,
	},SharedUI)
end

]==]
		source=replaceOnce(source,
			"local function buildModals()",
			sharedConfirm.."local function buildModals()",
			label.." shared confirmation")
		local legacyStart=assert(source:find("\tlocal teleport = modalShell(\"Teleport\"",1,true),label.." legacy confirmation start missing")
		local legacyEnd=assert(source:find("\n\tlocal controls = modalShell(\"Controls\"",legacyStart,true),label.." legacy confirmation end missing")
		source=source:sub(1,legacyStart-1)..source:sub(legacyEnd+1)
		assert(countPlain(source,"openModal(\"Teleport\")")==2,label.." expected two teleport modal call sites")
		source=source:gsub("openModal%(\"Teleport\"%)","showSharedTeleportConfirmation()")
	end
	return MARKER.."\n"..source
end

project("DesktopHud", function(source) return projectFreeRoam(source,"Desktop HUD",false) end)
project("MobileHud", function(source) return projectFreeRoam(source,"Mobile HUD",true) end)

project("RaceCountdown", function(source)
	source=replaceOnce(source,
		"local corner=Instance.new(\"UICorner\") corner.CornerRadius=UDim.new(0,18) corner.Parent=card",
		"UI.Corner(card,18)",
		"Race countdown corner")
	return MARKER.."\n"..source
end)

project("RaceClient", function(source)
	source=insertAfterOnce(source,
		"local kit = ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")",
		"\nlocal SharedUI = require(kit:WaitForChild(\"Shared\"):WaitForChild(\"Modules\"):WaitForChild(\"UI\"):WaitForChild(\"RacingUIComponents\"))",
		"Race client shared UI")
	source=replaceOnce(source,
		"local corner = Instance.new(\"UICorner\")\ncorner.CornerRadius = UDim.new(0, 7)\ncorner.Parent = panel",
		"SharedUI.Corner(panel,7)",
		"Race client panel corner")
	source=replaceOnce(source,
		"\tlocal labelCorner = Instance.new(\"UICorner\")\n\tlabelCorner.CornerRadius = UDim.new(0, 6)\n\tlabelCorner.Parent = label",
		"\tSharedUI.Corner(label,6)",
		"Race client label corner")
	return MARKER.."\n"..source
end)

project("RacePersonalBest", function(source)
	source=insertAfterOnce(source,
		"local kit = ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")",
		"\nlocal Foundation = require(kit:WaitForChild(\"Shared\"):WaitForChild(\"Modules\"):WaitForChild(\"UI\"):WaitForChild(\"ResponsiveUIFoundation\"))",
		"Race PB foundation")
	source=replaceOnce(source,
		"local function corner(parent, radius)\n\tlocal c = Instance.new(\"UICorner\")\n\tc.CornerRadius = UDim.new(0, radius or 7)\n\tc.Parent = parent\n\treturn c\nend",
		"local function corner(parent, radius)\n\treturn Foundation.Corner(parent,radius or 7)\nend",
		"Race PB corner")
	return MARKER.."\n"..source
end)

project("RaceRouteGuide", function(source)
	source=insertAfterOnce(source,
		"local kit = ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")",
		"\nlocal Foundation = require(kit:WaitForChild(\"Shared\"):WaitForChild(\"Modules\"):WaitForChild(\"UI\"):WaitForChild(\"ResponsiveUIFoundation\"))",
		"Race route foundation")
	source=replaceOnce(source,
		"\tlocal corner = Instance.new(\"UICorner\")\n\tcorner.CornerRadius = UDim.new(0, numberAttr(\"CheckpointPillCornerRadius\", 8))\n\tcorner.Parent = label",
		"\tFoundation.Corner(label,numberAttr(\"CheckpointPillCornerRadius\",8))",
		"Race route pill corner")
	source=replaceOnce(source,
		"local wrongCorner = Instance.new(\"UICorner\")\nwrongCorner.CornerRadius = UDim.new(0, 6)\nwrongCorner.Parent = wrongWay",
		"Foundation.Corner(wrongWay,6)",
		"Race route wrong-way corner")
	return MARKER.."\n"..source
end)

project("RaceSessionControls", function(source)
	source=insertAfterOnce(source,
		"local kit = ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")",
		"\nlocal Foundation = require(kit:WaitForChild(\"Shared\"):WaitForChild(\"Modules\"):WaitForChild(\"UI\"):WaitForChild(\"ResponsiveUIFoundation\"))",
		"Race controls foundation")
	source=replaceOnce(source,
		"local function corner(parent, radius)\n\tlocal item = Instance.new(\"UICorner\")\n\titem.CornerRadius = UDim.new(0, radius or 7)\n\titem.Parent = parent\n\treturn item\nend",
		"local function corner(parent, radius)\n\treturn Foundation.Corner(parent,radius or 7)\nend",
		"Race controls corner")
	return MARKER.."\n"..source
end)

project("RaceSession", function(source)
	source=replaceOnce(source,
		"local corner=object:FindFirstChildOfClass(\"UICorner\") or Instance.new(\"UICorner\") corner.CornerRadius=UDim.new(0,N(\"MetricCardCornerRadius\",9)) corner.Parent=object",
		"local corner=object:FindFirstChildOfClass(\"UICorner\") or Instance.new(\"UICorner\") UI.SetCorner(corner,N(\"MetricCardCornerRadius\",9)) corner.Parent=object",
		"Race session metric corner")
	source=replaceOnce(source,
		"local corner=Instance.new(\"UICorner\") corner.CornerRadius=UDim.new(0,N(\"DataRowCornerRadius\",7)) corner.Parent=row",
		"UI.Corner(row,N(\"DataRowCornerRadius\",7))",
		"Race session row corner")
	source=replaceOnce(source,
		"local corner=Instance.new(\"UICorner\") corner.CornerRadius=UDim.new(0,5) corner.Parent=image",
		"UI.Corner(image,5)",
		"Race session avatar corner")
	return MARKER.."\n"..source
end)

project("RaceResults", function(source)
	source=replaceOnce(source,
		"local corner = Instance.new(\"UICorner\") corner.CornerRadius = UDim.new(0, touch and 4 or 6) corner.Parent = image",
		"UI.Corner(image,touch and 4 or 6)",
		"Race results image corner")
	source=replaceOnce(source,
		"local c=Instance.new(\"UICorner\") c.CornerRadius=UDim.new(0,6) c.Parent=f",
		"UI.Corner(f,6)",
		"Race results silhouette corner")
	return MARKER.."\n"..source
end)

projected.TopNotification = TOP_NOTIFICATION_SOURCE
compile(FOUNDATION_SOURCE,"ResponsiveUIFoundation")
compile(TOP_NOTIFICATION_SOURCE,"SharedTopNotificationController")

local function ensureNumberValue(name,value)
	local item=themeConfig:FindFirstChild(name)
	if item then assert(item:IsA("NumberValue"),item:GetFullName().." must be a NumberValue") end
	return item,value
end

local desktopScale=ensureNumberValue("CornerScaleDesktop",.7)
local mobileScale=ensureNumberValue("CornerScaleMobile",.5)

local function audit()
	local failures={}
	local warnings={}
	local function expect(condition,message)
		if not condition then table.insert(failures,message) end
	end
	local foundation=uiModules:FindFirstChild("ResponsiveUIFoundation")
	expect(foundation and foundation:IsA("ModuleScript"),"ResponsiveUIFoundation ModuleScript missing")
	if foundation then
		expect(countPlain(foundation.Source,REVISION)==1,"foundation revision marker missing/duplicated")
		local ok,module=pcall(require,foundation)
		expect(ok and type(module)=="table","foundation require failed: "..tostring(module))
		if ok then
			expect(module.FormatCompactMoney(350000)=="$350,000","$350,000 formatter case failed")
			expect(module.FormatCompactMoney(999999)=="$999,999","$999,999 formatter case failed")
			expect(module.FormatCompactMoney(1000000)=="$1.0M","$1.0M formatter case failed")
			expect(module.FormatCompactMoney(9900000)=="$9.9M","$9.9M formatter case failed")
			expect(module.FormatCompactMoney(10000000)=="$10.0M","$10.0M formatter case failed")
		end
	end
	local desktop=themeConfig:FindFirstChild("CornerScaleDesktop")
	local mobile=themeConfig:FindFirstChild("CornerScaleMobile")
	expect(desktop and desktop:IsA("NumberValue") and math.abs(desktop.Value-.7)<.0001,"desktop corner scale is not 0.70")
	expect(mobile and mobile:IsA("NumberValue") and math.abs(mobile.Value-.5)<.0001,"mobile corner scale is not 0.50")
	for label,object in pairs(targets) do
		expect(countPlain(object.Source,REVISION)==1,label.." revision marker missing/duplicated")
		local ok,problem=pcall(compile,object.Source,label.." committed")
		expect(ok,label.." committed compile failed: "..tostring(problem))
	end
	expect(not targets.TopNotification.Source:find("UIStroke",1,true),"top notification still creates a border")
	expect(targets.TopNotification.Source:find("CreateTopNotificationController",1,true)~=nil,"top notification does not use shared owner")
	expect(targets.GarageShared.Source:find("Racing.ConfirmationModal",1,true)~=nil,"garage confirmation does not use shared contract")
	expect(targets.DesktopHud.Source:find("Foundation.Confirmation",1,true)~=nil and targets.DesktopHud.Source:find("modalShell(\"Teleport\"",1,true)==nil,"desktop confirmation does not have one shared owner")
	expect(targets.MobileHud.Source:find("Foundation.Confirmation",1,true)~=nil,"mobile confirmation does not use shared owner")
	expect(targets.ModuleShop.Source:find("Shared.ProjectEconomy",1,true)~=nil,"garage transaction response projection missing")
	expect(targets.OwnedGarageWorkspace.Source:find("result.ProjectedEconomy",1,true)~=nil,"owned-garage transaction response projection missing")
	expect(targets.DesktopHud.Source:find("FormatCompactMoney",1,true)~=nil,"desktop Cash does not use compact formatter")
	expect(targets.MobileHud.Source:find("FormatCompactMoney",1,true)~=nil,"mobile Cash does not use compact formatter")
	expect(targets.MobileHud.Source:find("cashStroke.Color=BLUE",1,true)~=nil,"mobile Cash still lacks explicit non-pink outline")
	expect(targets.DesktopHud.Source:find("while task.wait(2",1,true)==nil and targets.MobileHud.Source:find("while task.wait(2",1,true)==nil,"free-roam HUD contains a two-second polling loop")
	local bootstrap=clientRoot:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	if bootstrap and bootstrap.Source:find("CornerRadius",1,true) then
		table.insert(warnings,"legacy register-limited bootstrap retains retired hard-coded corners; canonical active garage surfaces supersede them")
	end
	if #failures>0 then error(TAG.." AUDIT FAIL | "..table.concat(failures," | ")) end
	print(TAG.." AUDIT PASS | formatter=5/5 corners=desktop70/mobile50 metrics=shared confirmations=shared notifications=bounded")
	for _,message in ipairs(warnings) do warn(TAG.." WARN | "..message) end
	return true
end

if MODE=="AUDIT" then
	audit()
	return
end

assert(MODE=="INSTALL","Unknown MODE: "..tostring(MODE))

if countPlain(targets.RacingUI.Source,REVISION)==1 then
	audit()
	print(TAG.." INSTALL PASS (already installed)")
	return
end

local createdFoundation=false
local foundation=uiModules:FindFirstChild("ResponsiveUIFoundation")
local foundationSourceBefore
if foundation then
	assert(foundation:IsA("ModuleScript"),foundation:GetFullName().." must be a ModuleScript")
	foundationSourceBefore=foundation.Source
else
	foundation=Instance.new("ModuleScript")
	foundation.Name="ResponsiveUIFoundation"
	createdFoundation=true
end

local sourceSnapshot={}
for label,object in pairs(targets) do
	sourceSnapshot[label]=object.Source
end
local configSnapshot={}
for _,entry in ipairs({{"CornerScaleDesktop",desktopScale},{"CornerScaleMobile",mobileScale}}) do
	local name,item=entry[1],entry[2]
	configSnapshot[name]=item and {Exists=true,Value=item.Value} or {Exists=false}
end

local ok,problem=pcall(function()
	foundation.Source=FOUNDATION_SOURCE
	foundation:SetAttribute("InstallerRevision",REVISION)
	foundation.Parent=uiModules
	for label,source in pairs(projected) do targets[label].Source=source end
	for _,entry in ipairs({{"CornerScaleDesktop",.7},{"CornerScaleMobile",.5}}) do
		local name,value=entry[1],entry[2]
		local item=themeConfig:FindFirstChild(name)
		if not item then item=Instance.new("NumberValue"); item.Name=name; item:SetAttribute("InstallerRevision",REVISION); item.Parent=themeConfig end
		item.Value=value
		item:SetAttribute("Description",name=="CornerScaleDesktop" and "Scale applied by shared renderers to active desktop corner radii." or "Scale applied by shared renderers to active touch/mobile corner radii.")
	end
	themeConfig:SetAttribute("SharedResponsiveUIRevision",REVISION)
	audit()
end)

if not ok then
	for label,object in pairs(targets) do
		object.Source=sourceSnapshot[label]
	end
	if foundationSourceBefore then
		foundation.Source=foundationSourceBefore
	elseif createdFoundation and foundation.Parent then foundation:Destroy() end
	for _,name in ipairs({"CornerScaleDesktop","CornerScaleMobile"}) do
		local saved=configSnapshot[name]
		local current=themeConfig:FindFirstChild(name)
		if saved.Exists and current then current.Value=saved.Value elseif not saved.Exists and current and current:GetAttribute("InstallerRevision")==REVISION then current:Destroy() end
	end
	themeConfig:SetAttribute("SharedResponsiveUIRevision",nil)
	error(TAG.." INSTALL ROLLED BACK | "..tostring(problem))
end

print(TAG.." INSTALL PASS | runId="..RUN_ID)
print(TAG.." Verify desktop/controller, phone portrait/landscape, transaction projection, confirmation exits, notification stacking, and free-roam Cash styling before refreshing the full Studio mirror.")
