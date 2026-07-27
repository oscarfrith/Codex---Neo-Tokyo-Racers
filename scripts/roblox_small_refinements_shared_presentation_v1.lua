-- Neo Tokyo Racers - Small Refinements: Shared Presentation V1.1
-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1
-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1_1
-- Run once in the Roblox Studio Edit-mode Command Bar, then restart Play.
-- One guarded, transactional installer for the approved presentation-only scope.

local MODE = "INSTALL" -- INSTALL or AUDIT
local MARKER = "NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1"
local REVISION = "NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1_1"
local PREFIX = "[NTR Small Refinements Shared Presentation V1.1]"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object, parent:GetFullName() .. "." .. name .. " missing")
	if className then
		assert(object:IsA(className), object:GetFullName() .. " must be " .. className)
	end
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function countPlain(source, needle)
	local count, start = 0, 1
	while true do
		local first, last = string.find(source, needle, start, true)
		if not first then return count end
		count += 1
		start = last + 1
	end
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local function replaceSection(source, firstAnchor, nextAnchor, replacement, label)
	local first = string.find(source, firstAnchor, 1, true)
	assert(first, "Missing section start: " .. label)
	assert(not string.find(source, firstAnchor, first + #firstAnchor, true), "Duplicate section start: " .. label)
	local nextFirst = string.find(source, nextAnchor, first + #firstAnchor, true)
	assert(nextFirst, "Missing section end: " .. label)
	return string.sub(source, 1, first - 1) .. replacement .. "\n\n" .. string.sub(source, nextFirst)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = need(kit, "Shared", "Folder")
local modules = need(shared, "Modules", "Folder")
local commonModules = need(modules, "Common", "Folder")
local uiModules = need(modules, "UI", "Folder")
local foundation = need(uiModules, "ResponsiveUIFoundation", "ModuleScript")

local clientRoot = need(
	need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"),
	"NeoTokyoRacersClient",
	"Folder"
)
local controllers = need(clientRoot, "Controllers", "Folder")
local uiControllers = need(controllers, "UI", "Folder")
local runtimeControllers = need(controllers, "Runtime", "Folder")
local racingControllers = need(controllers, "Racing", "Folder")

local ownedBrowser = need(uiControllers, "OwnedGarageBrowserController", "ModuleScript")
local garageShared = need(uiControllers, "GarageReplacementComponents", "ModuleScript")
local garageWorkspace = need(uiControllers, "GarageWorkspaceController", "ModuleScript")
local desktopHud = need(uiControllers, "DesktopFreeRoamHudController_Active", "LocalScript")
local mobileHud = need(uiControllers, "MobileFreeRoamHudController_Active", "LocalScript")
local mobileControls = need(runtimeControllers, "MobileDriveControlsController_Active", "LocalScript")
local topNotification = need(uiControllers, "SharedTopNotificationController_Active", "LocalScript")
local raceSession = need(racingControllers, "RaceSessionPresentationController_Active", "LocalScript")

local services = need(need(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder")
local garageServices = need(services, "Garage", "Folder")
local management = need(garageServices, "OwnedGarageManagementRuntime", "ModuleScript")

local uiConfig = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")
local existingNames = commonModules:FindFirstChild("VehicleDisplayNames")

for label, object in pairs({
	ResponsiveUIFoundation = foundation,
	OwnedGarageBrowserController = ownedBrowser,
	GarageReplacementComponents = garageShared,
	GarageWorkspaceController = garageWorkspace,
	DesktopFreeRoamHudController = desktopHud,
	MobileFreeRoamHudController = mobileHud,
	MobileDriveControlsController = mobileControls,
	SharedTopNotificationController = topNotification,
	RaceSessionPresentationController = raceSession,
	OwnedGarageManagementRuntime = management,
}) do
	assert(object:IsA("LuaSourceContainer"), label .. " must be a LuaSourceContainer")
end

local DISPLAY_NAMES_SOURCE = [==[
-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1
-- Player-facing vehicle names only. Stable category/cockpit IDs remain unchanged.
local M={}

local function titleWords(value)
	local text=string.gsub(tostring(value or ""),"_"," ")
	text=string.gsub(text,"%s+"," ")
	text=string.gsub(text,"^%s+","")
	text=string.gsub(text,"%s+$","")
	return string.gsub(string.lower(text),"(%a)([%w']*)",function(first,rest) return string.upper(first)..rest end)
end

local function cockpitIdFrom(profile,vehicle)
	if type(vehicle)~="table" then return "" end
	local cockpitId=tostring(vehicle.CockpitId or "")
	if cockpitId=="" and vehicle.CockpitInstanceId and type(profile)=="table" and type(profile.OwnedCockpitInstances)=="table" then
		local instance=profile.OwnedCockpitInstances[tostring(vehicle.CockpitInstanceId)]
		cockpitId=tostring(type(instance)=="table" and instance.TemplateId or "")
	end
	return cockpitId
end

function M.FindCockpit(categoriesRoot,cockpitId)
	if not categoriesRoot then return nil,nil end
	local wanted=string.lower(tostring(cockpitId or ""))
	if wanted=="" then return nil,nil end
	for _,category in ipairs(categoriesRoot:GetChildren()) do
		for _,item in ipairs(category:GetDescendants()) do
			if item:IsA("Model") then
				local id=string.lower(tostring(item:GetAttribute("CockpitId") or item:GetAttribute("TemplateId") or item.Name))
				local compact=string.gsub(id,"^cockpit_","")
				if id==wanted or compact==wanted then return item,category end
			end
		end
	end
	return nil,nil
end

function M.CockpitName(categoriesRoot,cockpitId)
	local cockpit=M.FindCockpit(categoriesRoot,cockpitId)
	local display=cockpit and cockpit:GetAttribute("DisplayName")
	if display~=nil and tostring(display)~="" then return titleWords(display) end
	return titleWords(cockpitId~="" and cockpitId or "Vehicle")
end

function M.CategoryName(categoriesRoot,categoryId,cockpitId)
	local _,category=M.FindCockpit(categoriesRoot,cockpitId)
	if not category and categoriesRoot then
		local wanted=string.lower(tostring(categoryId or ""))
		for _,candidate in ipairs(categoriesRoot:GetChildren()) do
			if string.lower(candidate.Name)==wanted then category=candidate; break end
		end
		-- "bruiser" is a stable legacy data ID; PIERCER is its current player-facing asset family.
		if not category and wanted=="bruiser" then category=categoriesRoot:FindFirstChild("PIERCER") end
	end
	local display=category and category:GetAttribute("DisplayName")
	return titleWords(display~=nil and tostring(display)~="" and display or (category and category.Name or categoryId or "Other"))
end

function M.FullVehicleName(profile,vehicleId,categoriesRoot)
	local vehicle=type(profile)=="table" and type(profile.Vehicles)=="table" and profile.Vehicles[tostring(vehicleId or "")] or nil
	if type(vehicle)~="table" then return titleWords(vehicleId~="" and vehicleId or "Vehicle") end
	local cockpitId=cockpitIdFrom(profile,vehicle)
	local cockpit=M.CockpitName(categoriesRoot,cockpitId)
	local category=M.CategoryName(categoriesRoot,vehicle.CategoryId or vehicle.Category,cockpitId)
	if string.lower(string.sub(cockpit,1,#category))==string.lower(category) then return cockpit end
	return category~="" and (category.." "..cockpit) or cockpit
end

return M
]==]

local CONFIRMATION_SECTION_V1_1 = [==[
function M.ConfirmationLayout()
	return {
		ReferenceViewport=Vector2.new(1920,1080),
		PanelWidth=650,
		PanelHeight=270,
		TitlePosition=UDim2.fromOffset(20,8),
		TitleSize=UDim2.new(1,-40,0,54),
		TitleTextSize=22,
		BodyPosition=UDim2.fromOffset(20,88),
		BodySize=UDim2.new(1,-40,0,44),
		BodyTextSize=15,
		CancelPosition=UDim2.fromOffset(30,182),
		ConfirmPosition=UDim2.fromOffset(350,182),
		ButtonSize=UDim2.fromOffset(270,54),
		ButtonTextSize=13,
	}
end

function M.Confirmation(root,options,components)
	options=options or {}
	assert(root and root:IsA("GuiObject"),"Confirmation requires a GuiObject root")
	assert(type(components)=="table","Confirmation requires shared UI components")
	local sourceGui=root:FindFirstAncestorOfClass("ScreenGui")
	local playerGui=sourceGui and sourceGui.Parent
	assert(playerGui and playerGui:IsA("PlayerGui"),"Confirmation root must belong to PlayerGui")
	local oldSelection=GuiService.SelectedObject
	local connections={}
	local closed=false
	local exitAction="NTRSharedConfirmationExit_"..tostring(os.clock())
	local oldOverlay=playerGui:FindFirstChild("NTR_SharedConfirmationOverlay")
	if oldOverlay then oldOverlay:Destroy() end
	local gui=Instance.new("ScreenGui")
	gui.Name="NTR_SharedConfirmationOverlay"
	gui.ResetOnSpawn=false
	gui.IgnoreGuiInset=true
	gui.DisplayOrder=1250
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Global
	pcall(function() gui.ScreenInsets=Enum.ScreenInsets.None end)
	pcall(function() gui.ClipToDeviceSafeArea=false end)
	gui.Parent=playerGui
	local backdrop=Instance.new("Frame")
	backdrop.Name="Backdrop"
	backdrop.Active=true
	backdrop.BackgroundColor3=Color3.new(0,0,0)
	backdrop.BackgroundTransparency=.34
	backdrop.BorderSizePixel=0
	backdrop.Size=UDim2.fromScale(1,1)
	backdrop.ZIndex=300
	backdrop.Parent=gui
	local canvas=Instance.new("Frame")
	canvas.Name="ReferenceCanvas"
	canvas.AnchorPoint=Vector2.new(.5,.5)
	canvas.BackgroundTransparency=1
	canvas.BorderSizePixel=0
	canvas.Position=UDim2.fromScale(.5,.5)
	canvas.Size=UDim2.fromOffset(1920,1080)
	canvas.ZIndex=301
	canvas.Parent=gui
	local scale=Instance.new("UIScale")
	scale.Parent=canvas
	local shade=Instance.new("Frame")
	shade.Name="NTRSharedConfirmation"
	shade.BackgroundTransparency=1
	shade.BorderSizePixel=0
	shade.Size=UDim2.fromScale(1,1)
	shade.ZIndex=301
	shade.Parent=canvas
	local layout=M.ConfirmationLayout()
	local panel=components.Panel(shade,{Name="Panel",StrokeColor=components.Colour("ElectricBlue"),NoGlow=true})
	panel.AnchorPoint=Vector2.new(.5,.5)
	panel.Position=UDim2.fromScale(.5,.5)
	panel.Size=UDim2.fromOffset(layout.PanelWidth,layout.PanelHeight)
	panel.ZIndex=302
	local title=components.Label(panel,{Text=options.Title or "CONFIRM",Position=layout.TitlePosition,Size=layout.TitleSize,TextSize=layout.TitleTextSize,Role="Heading",XAlignment=Enum.TextXAlignment.Center})
	title.ZIndex=303
	local body=components.Label(panel,{Text=options.Body or "Continue?",Position=layout.BodyPosition,Size=layout.BodySize,TextSize=layout.BodyTextSize,XAlignment=Enum.TextXAlignment.Center,Wrapped=true})
	body.ZIndex=303
	local no=components.Button(panel,{Text=options.CancelText or "NO",Position=layout.CancelPosition,Size=layout.ButtonSize,TextSize=layout.ButtonTextSize,Color=components.Colour("PanelDeep"),StrokeColor=components.Colour("Outline"),ZIndex=304})
	local yes=components.Button(panel,{Text=options.ConfirmText or "YES",Position=layout.ConfirmPosition,Size=layout.ButtonSize,TextSize=layout.ButtonTextSize,Color=components.Colour("PanelBlue"),StrokeColor=components.Colour("Telemetry"),ZIndex=304})
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
		gui:Destroy()
		if confirmed then
			if options.OnConfirm then options.OnConfirm() end
		elseif options.OnCancel then options.OnCancel() end
	end
	local function safeViewportRect(viewport)
		local origin=Vector2.zero
		local size=viewport
		local ok,fullRect,deviceRect=pcall(function()
			return GuiService:GetInsetArea(Enum.ScreenInsets.None),GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
		end)
		if ok and fullRect and deviceRect then
			origin=deviceRect.Min-fullRect.Min
			size=deviceRect.Max-deviceRect.Min
		end
		origin=Vector2.new(math.clamp(origin.X,0,math.max(0,viewport.X-1)),math.clamp(origin.Y,0,math.max(0,viewport.Y-1)))
		size=Vector2.new(math.clamp(size.X,1,math.max(1,viewport.X-origin.X)),math.clamp(size.Y,1,math.max(1,viewport.Y-origin.Y)))
		return origin,size
	end
	local function relayout()
		if closed or not gui.Parent then return end
		local camera=Workspace.CurrentCamera
		local viewport=camera and camera.ViewportSize or gui.AbsoluteSize
		if viewport.X<1 or viewport.Y<1 then viewport=layout.ReferenceViewport end
		local origin,safeSize=safeViewportRect(viewport)
		local uniformScale=math.max(.01,math.min(safeSize.X/layout.ReferenceViewport.X,safeSize.Y/layout.ReferenceViewport.Y))
		scale.Scale=uniformScale
		canvas.Position=UDim2.fromOffset(origin.X+safeSize.X*.5,origin.Y+safeSize.Y*.5)
		canvas.Size=UDim2.fromOffset(safeSize.X/uniformScale,safeSize.Y/uniformScale)
	end
	no.Activated:Connect(function() close(false) end)
	yes.Activated:Connect(function() close(true) end)
	ContextActionService:BindActionAtPriority(exitAction,function(_,state)
		if state==Enum.UserInputState.Begin then close(false) end
		return Enum.ContextActionResult.Sink
	end,false,10000,Enum.KeyCode.Escape,Enum.KeyCode.ButtonB)
	local camera=Workspace.CurrentCamera
	if camera then table.insert(connections,camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)) end
	table.insert(connections,Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local current=Workspace.CurrentCamera
		if current then table.insert(connections,current:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)) end
		relayout()
	end))
	relayout()
	task.defer(function()
		if closed or not no.Parent then return end
		local lastInput=UserInputService:GetLastInputType()
		if lastInput==Enum.UserInputType.Keyboard or string.find(lastInput.Name,"Gamepad",1,true) then GuiService.SelectedObject=no end
	end)
	return {Root=gui,Cancel=function() close(false) end,Confirm=function() close(true) end,Relayout=relayout}
end
]==]

local TOP_NOTIFICATION_SECTION_V1_1 = [==[
function M.CreateTopNotificationController(playerGui)
	assert(playerGui and playerGui:IsA("PlayerGui"),"Top notification controller requires PlayerGui")
	local TextService=game:GetService("TextService")
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
	local function cardBounds(card,viewport)
		local mobile=M.IsMobile()
		local side=mobile and 12 or 24
		local maxWidth=math.min(viewport.X-side*2,mobile and 280 or 820)
		local minWidth=mobile and 120 or 170
		local horizontalPadding=mobile and 22 or 34
		local verticalPadding=mobile and 14 or 18
		local textSize=mobile and 12 or 15
		local text=card:GetAttribute("MessageText") or ""
		local availableTextWidth=math.max(40,maxWidth-horizontalPadding)
		local measured=TextService:GetTextSize(text,textSize,Enum.Font.Michroma,Vector2.new(availableTextWidth,1000))
		local width=math.clamp(measured.X+horizontalPadding,minWidth,maxWidth)
		local wrapped=measured.X>=availableTextWidth
		local finalTextWidth=math.max(40,width-horizontalPadding)
		measured=TextService:GetTextSize(text,textSize,Enum.Font.Michroma,Vector2.new(finalTextWidth,1000))
		local height=math.max(mobile and 30 or 38,measured.Y+verticalPadding)
		return width,height,textSize,wrapped or measured.Y>textSize*1.5,horizontalPadding
	end
	local function relayout()
		local camera=Workspace.CurrentCamera
		local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
		local topLeft=GuiService:GetGuiInset()
		local maxWidth=math.min(viewport.X-(M.IsMobile() and 24 or 48),M.IsMobile() and 280 or 820)
		stack.Position=UDim2.fromOffset(viewport.X*.5,math.max(12,topLeft.Y+10))
		stack.Size=UDim2.fromOffset(maxWidth,0)
		for _,card in ipairs(cards) do
			if card.Parent then
				local width,height,textSize,wrapped,horizontalPadding=cardBounds(card,viewport)
				card.Size=UDim2.fromOffset(width,height)
				local textLabel=card:FindFirstChild("Text")
				if textLabel then
					textLabel.Position=UDim2.fromOffset(horizontalPadding*.5,0)
					textLabel.Size=UDim2.new(1,-horizontalPadding,1,0)
					textLabel.TextSize=textSize
					textLabel.TextWrapped=wrapped
				end
			end
		end
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
		local card=Instance.new("Frame")
		card.Name="Message"..serial
		card.LayoutOrder=serial
		card.BackgroundColor3=Color3.fromRGB(72,76,84)
		card.BackgroundTransparency=.04
		card.BorderSizePixel=0
		card:SetAttribute("MessageText",text)
		card.ZIndex=2
		card.Parent=stack
		M.Corner(card,6)
		local gradient=Instance.new("UIGradient")
		gradient.Name="GreyGradient"
		gradient.Color=ColorSequence.new(Color3.fromRGB(105,109,117),Color3.fromRGB(48,52,60))
		gradient.Rotation=90
		gradient.Parent=card
		local textLabel=Instance.new("TextLabel")
		textLabel.Name="Text"
		textLabel.BackgroundTransparency=1
		textLabel.BorderSizePixel=0
		textLabel.Text=text
		textLabel.TextColor3=Color3.new(1,1,1)
		textLabel.TextXAlignment=Enum.TextXAlignment.Center
		textLabel.TextYAlignment=Enum.TextYAlignment.Center
		textLabel.ZIndex=card.ZIndex+1
		pcall(function() textLabel.FontFace=Font.new("rbxasset://fonts/families/Michroma.json",Enum.FontWeight.Bold) end)
		textLabel.Parent=card
		table.insert(cards,card)
		relayout()
		task.delay(math.clamp(tonumber(duration) or 2.5,.5,10),function() remove(card) end)
	end
	relayout()
	return {Gui=gui,Show=show,Relayout=relayout,Count=function() return #cards end}
end
]==]

local function applyRevision(foundationSource,ownedBrowserSource,mobileHudSource,raceSessionSource)
	foundationSource=replaceSection(foundationSource,"function M.Confirmation(root,options,components)","function M.CreateTopNotificationController(playerGui)",CONFIRMATION_SECTION_V1_1,"shared Race Exit confirmation layout")
	foundationSource=replaceSection(foundationSource,"function M.CreateTopNotificationController(playerGui)","return M",TOP_NOTIFICATION_SECTION_V1_1,"content-sized top notifications")
	foundationSource="-- "..REVISION.."\n"..foundationSource

	ownedBrowserSource=replaceOnce(
		ownedBrowserSource,
		'if object:IsA("GuiButton") then local original=object:GetAttribute("NTR_OwnedGarageOriginalSize");',
		'if object:IsA("GuiButton") and object:GetAttribute("NTRSkipTouchHardening")~=true then local original=object:GetAttribute("NTR_OwnedGarageOriginalSize");',
		"owned garage shared footer touch-hardening exclusion"
	)
	ownedBrowserSource=replaceSection(ownedBrowserSource,
	'\tlocal exit=Shared.ActionButton(shell,{Name="Exit"',
	'\tlocal function presentation(active)',
	[=[
	local footerPad=L("OuterPadding",24); local footerGap=L("Gap",16); local footerButtonY=-64; local footerButtonHeight=48
	status.Position=UDim2.new(0,footerPad,1,-58)
	local exit=UI.Button(shell,{Name="Exit",Text="EXIT",Position=UDim2.new(0,footerPad,1,footerButtonY),Size=UDim2.new(.5,-(footerPad+footerGap*.5),0,footerButtonHeight),Color=C("PanelSoft"),StrokeColor=C("Outline"),FocusColor=C("Telemetry")}); exit:SetAttribute("NTRSkipTouchHardening",true)
	local enter=UI.Button(shell,{Name="Enter",Text="ENTER GARAGE",Position=UDim2.new(.5,footerGap*.5,1,footerButtonY),Size=UDim2.new(.5,-(footerPad+footerGap*.5),0,footerButtonHeight),Color=C("PanelBlue"),StrokeColor=C("Telemetry"),FocusColor=C("Telemetry")}); enter:SetAttribute("NTRSkipTouchHardening",true)
]=], "owned garage Race Browser footer")
	ownedBrowserSource="-- "..REVISION.."\n"..ownedBrowserSource

	mobileHudSource=replaceOnce(
		mobileHudSource,
		'\tif telemetryOnly or localMajorMenuOpen then toast.Visible=false end\n',
		'',
		"retired mobile toast race-frame reference"
	)
	mobileHudSource="-- "..REVISION.."\n"..mobileHudSource

	raceSessionSource=replaceOnce(
		raceSessionSource,
		'local modal=UI.Panel(modalShade,{Name="ExitConfirmation",Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(650,270),Color=C("PanelDeep"),Transparency=.04,StrokeColor=C("Outline"),StrokeTransparency=.02}) modal.AnchorPoint=Vector2.new(.5,.5) modal.Position=UDim2.fromScale(.5,.5) modal.Size=UDim2.fromOffset(650,270) modal.ZIndex=101\nlocal modalTitle=UI.Label(modal,{Text="EXIT RACE?",Position=UDim2.fromOffset(20,8),Size=UDim2.new(1,-40,0,54),TextSize=22,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalTitle.ZIndex=102\nlocal modalCopy=UI.Label(modal,{Text="CURRENT PROGRESS WILL BE LOST.",Position=UDim2.fromOffset(20,88),Size=UDim2.new(1,-40,0,44),TextSize=15,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalCopy.ZIndex=102\nlocal noButton=UI.Button(modal,{Text="NO",Position=UDim2.fromOffset(30,182),Size=UDim2.fromOffset(270,54),Color=C("PanelDeep"),StrokeColor=C("Outline"),TextSize=13}) noButton.ZIndex=103\nlocal yesButton=UI.Button(modal,{Text="YES",Position=UDim2.fromOffset(350,182),Size=UDim2.fromOffset(270,54),Color=C("PanelBlue"),StrokeColor=C("Telemetry"),TextSize=13}) yesButton.ZIndex=103',
		'local confirmationLayout=require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ResponsiveUIFoundation")).ConfirmationLayout()\nlocal modal=UI.Panel(modalShade,{Name="ExitConfirmation",Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(confirmationLayout.PanelWidth,confirmationLayout.PanelHeight),Color=C("PanelDeep"),Transparency=.04,StrokeColor=C("Outline"),StrokeTransparency=.02}) modal.AnchorPoint=Vector2.new(.5,.5) modal.Position=UDim2.fromScale(.5,.5) modal.Size=UDim2.fromOffset(confirmationLayout.PanelWidth,confirmationLayout.PanelHeight) modal.ZIndex=101\nlocal modalTitle=UI.Label(modal,{Text="EXIT RACE?",Position=confirmationLayout.TitlePosition,Size=confirmationLayout.TitleSize,TextSize=confirmationLayout.TitleTextSize,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalTitle.ZIndex=102\nlocal modalCopy=UI.Label(modal,{Text="CURRENT PROGRESS WILL BE LOST.",Position=confirmationLayout.BodyPosition,Size=confirmationLayout.BodySize,TextSize=confirmationLayout.BodyTextSize,Color=C("Text"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}) modalCopy.ZIndex=102\nlocal noButton=UI.Button(modal,{Text="NO",Position=confirmationLayout.CancelPosition,Size=confirmationLayout.ButtonSize,Color=C("PanelDeep"),StrokeColor=C("Outline"),TextSize=confirmationLayout.ButtonTextSize}) noButton.ZIndex=103\nlocal yesButton=UI.Button(modal,{Text="YES",Position=confirmationLayout.ConfirmPosition,Size=confirmationLayout.ButtonSize,Color=C("PanelBlue"),StrokeColor=C("Telemetry"),TextSize=confirmationLayout.ButtonTextSize}) yesButton.ZIndex=103',
		"Race Exit shared confirmation geometry"
	)
	raceSessionSource="-- "..REVISION.."\n"..raceSessionSource
	return foundationSource,ownedBrowserSource,mobileHudSource,raceSessionSource
end

local function baseV1InstalledEverywhere()
	local displayNames = commonModules:FindFirstChild("VehicleDisplayNames")
	return displayNames
		and displayNames:IsA("ModuleScript")
		and string.find(displayNames.Source, MARKER, 1, true)
		and string.find(foundation.Source, MARKER, 1, true)
		and string.find(ownedBrowser.Source, MARKER, 1, true)
		and string.find(garageShared.Source, MARKER, 1, true)
		and string.find(garageWorkspace.Source, MARKER, 1, true)
		and string.find(desktopHud.Source, MARKER, 1, true)
		and string.find(mobileHud.Source, MARKER, 1, true)
		and string.find(mobileControls.Source, MARKER, 1, true)
		and string.find(management.Source, MARKER, 1, true)
end

local function installedEverywhere()
	return baseV1InstalledEverywhere()
		and string.find(foundation.Source, REVISION, 1, true)
		and string.find(ownedBrowser.Source, REVISION, 1, true)
		and string.find(mobileHud.Source, REVISION, 1, true)
		and string.find(raceSession.Source, REVISION, 1, true)
end

local function audit()
	local pass, fail = 0, 0
	local function check(ok, message)
		if ok then
			pass += 1
			print(PREFIX .. " PASS - " .. message)
		else
			fail += 1
			warn(PREFIX .. " FAIL - " .. message)
		end
	end
	local displayNames = commonModules:FindFirstChild("VehicleDisplayNames")
	check(displayNames and displayNames:IsA("ModuleScript") and string.find(displayNames.Source, MARKER, 1, true), "shared vehicle display-name resolver installed")
	check(string.find(foundation.Source, "function M.ConfirmationLayout()", 1, true) ~= nil and string.find(foundation.Source, "PanelWidth=650", 1, true) ~= nil, "shared confirmations use the Race Exit reference geometry")
	check(string.find(foundation.Source, 'gui.Name="NTR_SharedConfirmationOverlay"', 1, true) ~= nil and string.find(foundation.Source, "gui.DisplayOrder=1250", 1, true) ~= nil, "shared confirmation backdrop owns the physical top-level overlay")
	check(string.find(foundation.Source, 'lastInput==Enum.UserInputType.Keyboard', 1, true) ~= nil, "confirmation focus is conditional rather than forced on touch")
	check(string.find(foundation.Source, 'local TextService=game:GetService("TextService")', 1, true) ~= nil and string.find(foundation.Source, "mobile and 280 or 820", 1, true) ~= nil, "top notifications size to measured text with the compact mobile cap")
	check(string.find(foundation.Source, 'textLabel.TextColor3=Color3.new(1,1,1)', 1, true) ~= nil and string.find(foundation.Source, "gradient.Parent=card", 1, true) ~= nil, "notification gradient and white text have separate owners")
	check(string.find(ownedBrowser.Source, 'list.Name="CardContent"', 1, true) ~= nil and string.find(ownedBrowser.Source, "list.Position=UDim2.fromOffset(4,4)", 1, true) ~= nil, "owned garage list uses the race-browser physical inset")
	check(string.find(ownedBrowser.Source, 'capacityText.TextScaled=true', 1, true) ~= nil, "owned garage capacity metric scales responsively")
	check(string.find(ownedBrowser.Source, 'local exit=UI.Button(shell', 1, true) ~= nil and string.find(ownedBrowser.Source, 'local enter=UI.Button(shell', 1, true) ~= nil and string.find(ownedBrowser.Source, 'footerButtonHeight=48', 1, true) ~= nil, "owned garage footer reuses Race Browser button geometry and renderer")
	check(string.find(garageShared.Source, 'responsiveNumber(N,"HeaderHeight",82)', 1, true) ~= nil, "shared garage shell retains the 82 fallback")
	check(uiConfig:GetAttribute("HeaderHeight") == 82, "shared garage header height is 82")
	check(string.find(garageWorkspace.Source, "self.Subtitle.TextWrapped=true", 1, true) ~= nil and string.find(garageWorkspace.Source, "Enum.TextTruncate.None", 1, true) ~= nil, "shared garage subtitle supports two lines")
	check(string.find(desktopHud.Source, 'sharedNotificationEvent:Fire(text,2.2)', 1, true) ~= nil and not string.find(desktopHud.Source, 'toast = label(root, "Toast"', 1, true), "desktop HUD routes local notices to the shared owner")
	check(string.find(mobileHud.Source, 'sharedNotificationEvent:Fire(text,2.2)', 1, true) ~= nil and not string.find(mobileHud.Source, 'local toast=label(root,"Toast"', 1, true), "mobile HUD routes local notices to the shared owner")
	check(string.find(desktopHud.Source, 'child:IsA("UIStroke") then child:Destroy()', 1, true) ~= nil and string.find(desktopHud.Source, '"CashStroke"', 1, true) ~= nil, "desktop cash has one blue semantic border owner")
	check(string.find(mobileHud.Source, 'cashStroke.Name="CashStroke"', 1, true) ~= nil, "mobile cash stroke is explicitly blue and semantic")
	check(countPlain(mobileControls.Source, 'UIAudioSuppressClick') >= 2, "continuous mobile vehicle controls suppress global click audio")
	check(string.find(desktopHud.Source, "DisplayNames.CategoryName", 1, true) ~= nil and string.find(mobileHud.Source, "DisplayNames.CategoryName", 1, true) ~= nil, "both free-roam category dropdowns use the shared display resolver")
	check(string.find(management.Source, "DisplayNames.FullVehicleName", 1, true) ~= nil, "owned garage prompts use the shared full vehicle name")
	check(string.find(topNotification.Source, "CreateTopNotificationController", 1, true) ~= nil, "existing shared top-notification runtime owner retained")
	check(not string.find(mobileHud.Source, "toast.Visible=false", 1, true), "retired mobile toast cannot abort race telemetry rendering")
	check(string.find(raceSession.Source, "confirmationLayout.PanelWidth", 1, true) ~= nil, "Race Exit consumes the shared confirmation geometry")
	print(string.format("%s RESULT %d PASS / %d FAIL", PREFIX, pass, fail))
	return fail == 0
end

if MODE == "AUDIT" then
	assert(audit(), "Audit failed")
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

if installedEverywhere() then
	assert(audit(), "Existing installation audit failed")
	print(PREFIX .. " ALREADY INSTALLED - no mutation required.")
	return
end

if baseV1InstalledEverywhere() then
	local oldSources = {
		[foundation] = foundation.Source,
		[ownedBrowser] = ownedBrowser.Source,
		[mobileHud] = mobileHud.Source,
		[raceSession] = raceSession.Source,
	}
	local foundationSource,ownedBrowserSource,mobileHudSource,raceSessionSource=applyRevision(
		foundation.Source,
		ownedBrowser.Source,
		mobileHud.Source,
		raceSession.Source
	)
	for name,source in pairs({
		ResponsiveUIFoundation=foundationSource,
		OwnedGarageBrowserController=ownedBrowserSource,
		MobileFreeRoamHudController=mobileHudSource,
		RaceSessionPresentationController=raceSessionSource,
	}) do
		compile(name,source)
		assert(#source<199000,name.." projected Source exceeds the safe Studio assignment limit ("..#source..")")
	end
	local ok,err=pcall(function()
		foundation.Source=foundationSource
		ownedBrowser.Source=ownedBrowserSource
		mobileHud.Source=mobileHudSource
		raceSession.Source=raceSessionSource
		assert(audit(),"Post-upgrade audit failed")
	end)
	if not ok then
		for object,source in pairs(oldSources) do object.Source=source end
		error(PREFIX.." rolled back atomically: "..tostring(err))
	end
	print(PREFIX.." UPGRADE COMPLETE")
	print(PREFIX.." Restart Play and verify content-sized white notifications, Race Exit-sized confirmations, dimmed objectives, owned garage footer parity, and mobile race telemetry.")
	return
end

assert(not existingNames, "VehicleDisplayNames already exists with an unknown or partial source; stop and inspect before installing")
assert(string.find(foundation.Source, "NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1", 1, true), "Confirmed ResponsiveUIFoundation V1.1 baseline missing")
assert(string.find(ownedBrowser.Source, "NTR_OWNED_GARAGE_MOBILE_ACCESS_WORLD_ENTRIES_V1", 1, true), "Confirmed owned garage browser baseline missing")
assert(string.find(garageShared.Source, "NTR_GARAGE_SHARED_SHELL_CANONICAL_HOST_V3", 1, true), "Confirmed shared garage shell baseline missing")
assert(string.find(garageWorkspace.Source, "NTR_GARAGE_FLOW_REFINEMENT_V2_1", 1, true), "Confirmed garage workspace V2.1 baseline missing")
assert(string.find(desktopHud.Source, "NTR_FREEROAM_CASH_SMOOTHING_DESKTOP_V1", 1, true), "Confirmed desktop HUD cash baseline missing")
assert(string.find(mobileHud.Source, "NTR_FREEROAM_CASH_SMOOTHING_MOBILE_V1", 1, true), "Confirmed mobile HUD cash baseline missing")
assert(string.find(mobileControls.Source, "NTR_MOBILE_FREEROAM_UI_PHASE1N_SQUARE_PEDAL_LAYOUT", 1, true), "Confirmed mobile controls Phase 1N baseline missing")
assert(string.find(management.Source, "NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW", 1, true), "Confirmed owned garage management baseline missing")
assert(string.find(raceSession.Source, "NTR_RACING_PRESENTATION_LIFECYCLE_V1_4_ADAPTIVE_SAFE_EDGE_CANVAS", 1, true), "Confirmed Race Session V1.4 baseline missing")

for label, object in pairs({
	ResponsiveUIFoundation = foundation,
	OwnedGarageBrowserController = ownedBrowser,
	GarageReplacementComponents = garageShared,
	GarageWorkspaceController = garageWorkspace,
	DesktopFreeRoamHudController = desktopHud,
	MobileFreeRoamHudController = mobileHud,
	MobileDriveControlsController = mobileControls,
	OwnedGarageManagementRuntime = management,
}) do
	assert(not string.find(object.Source, MARKER, 1, true), label .. " contains a partial Phase 1 installation; stop and inspect")
end

local foundationSource = foundation.Source
local ownedBrowserSource = ownedBrowser.Source
local garageSharedSource = garageShared.Source
local garageWorkspaceSource = garageWorkspace.Source
local desktopHudSource = desktopHud.Source
local mobileHudSource = mobileHud.Source
local mobileControlsSource = mobileControls.Source
local managementSource = management.Source
local raceSessionSource = raceSession.Source

foundationSource = replaceOnce(foundationSource, [=[
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
]=], [=[
		local availableWidth=logical.X-safeLeft-safeRight
		local availableHeight=logical.Y-safeTop-safeBottom
		local actualAvailableWidth=availableWidth*sx
		local actualAvailableHeight=availableHeight*sy
		local mobile=M.IsMobile()
		local landscape=absolute.X>absolute.Y
		local actualWidth
		local actualHeight
		if mobile then
			actualWidth=math.clamp(actualAvailableWidth*(landscape and .58 or .86),280,520)
			actualHeight=math.clamp(actualAvailableHeight*(landscape and .46 or .32),200,250)
		else
			actualWidth=math.clamp(actualAvailableWidth*.38,520,680)
			actualHeight=math.clamp(actualAvailableHeight*.28,240,300)
		end
		actualWidth=math.min(actualWidth,actualAvailableWidth)
		actualHeight=math.min(actualHeight,actualAvailableHeight)
		local width=actualWidth/math.max(sx,.01)
		local height=actualHeight/math.max(sy,.01)
		panel.Position=UDim2.fromOffset(safeLeft+availableWidth*.5,safeTop+availableHeight*.5)
		panel.Size=UDim2.fromOffset(width,height)
		title.TextSize=(mobile and 18 or 22)/math.max(sy,.01)
		body.TextSize=(mobile and 12 or 14)/math.max(sy,.01)
		no.TextSize=(mobile and 13 or 14)/math.max(sy,.01)
		yes.TextSize=no.TextSize
		local topPad=(mobile and 16 or 22)/math.max(sy,.01)
		title.Position=UDim2.fromOffset(24/math.max(sx,.01),topPad)
		title.Size=UDim2.new(1,-48/math.max(sx,.01),0,34/math.max(sy,.01))
		body.Position=UDim2.fromOffset(28/math.max(sx,.01),(mobile and 56 or 72)/math.max(sy,.01))
		body.Size=UDim2.new(1,-56/math.max(sx,.01),1,-(mobile and 126 or 150)/math.max(sy,.01))
		local actualGap=math.clamp(actualWidth*.035,12,22)
		local actualButtonWidth=math.clamp((actualWidth-48-actualGap)*.5,112,190)
		local buttonWidth=actualButtonWidth/math.max(sx,.01)
		local buttonHeight=48/math.max(sy,.01)
		local bottomPad=(mobile and 18 or 24)/math.max(sy,.01)
		no.AnchorPoint=Vector2.new(1,1)
		no.Position=UDim2.new(.5,-actualGap*.5/math.max(sx,.01),1,-bottomPad)
		no.Size=UDim2.fromOffset(buttonWidth,buttonHeight)
		yes.AnchorPoint=Vector2.new(0,1)
		yes.Position=UDim2.new(.5,actualGap*.5/math.max(sx,.01),1,-bottomPad)
		yes.Size=UDim2.fromOffset(buttonWidth,buttonHeight)
]=], "shared confirmation physical viewport profile")

foundationSource = replaceOnce(foundationSource, [=[
		local mobile=M.IsMobile()
		local side=mobile and 12 or 24
		local width=math.min(mobile and 540 or 620,math.max(260,viewport.X-side*2))
		local height=mobile and (viewport.X>viewport.Y and 44 or 52) or 48
]=], [=[
		local mobile=M.IsMobile()
		local side=mobile and 12 or 24
		local landscape=viewport.X>viewport.Y
		local width=mobile
			and math.clamp(landscape and viewport.X*.52 or viewport.X-side*2,280,420)
			or math.clamp(viewport.X*.42,680,820)
		width=math.min(width,viewport.X-side*2)
		local height=mobile and (landscape and 42 or 48) or 54
]=], "shared top-notification responsive profile")
foundationSource = replaceOnce(foundationSource, "card.TextSize=M.IsMobile() and 12 or 14", "card.TextSize=M.IsMobile() and 12 or 15", "shared top-notification typography")
foundationSource = "-- " .. MARKER .. "\n" .. foundationSource

ownedBrowserSource = replaceOnce(
	ownedBrowserSource,
	'local list=Instance.new("Frame"); list.BackgroundTransparency=1; list.Size=UDim2.new(1,-14,0,0); list.AutomaticSize=Enum.AutomaticSize.Y; list.Parent=listScroller;',
	'local list=Instance.new("Frame"); list.Name="CardContent"; list.BackgroundTransparency=1; list.Position=UDim2.fromOffset(4,4); list.Size=UDim2.new(1,-(UserInputService.TouchEnabled and 12 or 16),0,0); list.AutomaticSize=Enum.AutomaticSize.Y; list.Parent=listScroller;',
	"owned garage race-browser physical inset"
)
ownedBrowserSource = replaceOnce(
	ownedBrowserSource,
	'local capacity=Shared.MetricCard(detail,"Capacity"); capacity.Position=UDim2.fromOffset(0,466); capacity.Size=UDim2.new(1,0,0,54); local capacityText=UI.Label(capacity,{Text="",Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-28,1,0),TextSize=T("Metric",16),Role="Metric",XAlignment=Enum.TextXAlignment.Center})',
	'local capacity=Shared.MetricCard(detail,"Capacity"); capacity.Position=UDim2.fromOffset(0,466); capacity.Size=UDim2.new(1,0,0,54); local capacityText=UI.Label(capacity,{Text="",Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-28,1,0),TextSize=T("Metric",16),Role="Metric",XAlignment=Enum.TextXAlignment.Center}); capacityText.TextScaled=true; capacityText.TextWrapped=false; capacityText.TextTruncate=Enum.TextTruncate.None; local capacityConstraint=Instance.new("UITextSizeConstraint"); capacityConstraint.MinTextSize=8; capacityConstraint.MaxTextSize=UserInputService.TouchEnabled and 30 or T("Metric",16); capacityConstraint.Parent=capacityText',
	"owned garage capacity responsive metric"
)
ownedBrowserSource = "-- " .. MARKER .. "\n" .. ownedBrowserSource

garageSharedSource = replaceOnce(
	garageSharedSource,
	'responsiveNumber(N,"HeaderHeight",68)',
	'responsiveNumber(N,"HeaderHeight",82)',
	"shared garage header resilient fallback"
)
garageSharedSource = "-- " .. MARKER .. "\n" .. garageSharedSource

garageWorkspaceSource = replaceOnce(
	garageWorkspaceSource,
	'self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,29),TextSize=headerSubtitleSize,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"})',
	'self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,31),Size=UDim2.new(1,-24,0,44),TextSize=headerSubtitleSize,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"}); self.Subtitle.TextWrapped=true; self.Subtitle.TextTruncate=Enum.TextTruncate.None; self.Subtitle.TextYAlignment=Enum.TextYAlignment.Center',
	"shared garage two-line subtitle"
)
garageWorkspaceSource = "-- " .. MARKER .. "\n" .. garageWorkspaceSource

mobileControlsSource = replaceOnce(
	mobileControlsSource,
	'local b=new("TextButton",{Name=name,Text="",AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=1-cardOpacity,BorderSizePixel=0,ClipsDescendants=true,ZIndex=5},root); b:SetAttribute("NTRControlVisual",kind)',
	'local b=new("TextButton",{Name=name,Text="",AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=1-cardOpacity,BorderSizePixel=0,ClipsDescendants=true,ZIndex=5},root); b:SetAttribute("NTRControlVisual",kind); b:SetAttribute("UIAudioSuppressClick",true)',
	"continuous mobile control click suppression"
)
mobileControlsSource = replaceOnce(
	mobileControlsSource,
	'local thumbHit=new("TextButton",{Name="ThumbstickHit",Text="",AutoButtonColor=false,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4},root)',
	'local thumbHit=new("TextButton",{Name="ThumbstickHit",Text="",AutoButtonColor=false,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4},root); thumbHit:SetAttribute("UIAudioSuppressClick",true)',
	"mobile thumbstick click suppression"
)
mobileControlsSource = "-- " .. MARKER .. "\n" .. mobileControlsSource

desktopHudSource = replaceOnce(
	desktopHudSource,
	'local Foundation = require(kit.Shared.Modules.UI:WaitForChild("ResponsiveUIFoundation"))',
	'local Foundation = require(kit.Shared.Modules.UI:WaitForChild("ResponsiveUIFoundation"))\nlocal DisplayNames = require(kit.Shared.Modules.Common:WaitForChild("VehicleDisplayNames"))',
	"desktop shared display-name dependency"
)
desktopHudSource = replaceOnce(
	desktopHudSource,
	"local toast",
	'local sharedNotificationEvent = script.Parent:WaitForChild("ShowTopNotification")',
	"desktop shared notification dependency"
)
desktopHudSource = replaceOnce(desktopHudSource, [=[
local function showToast(text, positive)
	toast.Text = tostring(text or "")
	toast.TextColor3 = positive and C("Telemetry", Color3.fromRGB(43, 225, 218)) or C("Text", Color3.new(1, 1, 1))
	toast.Visible = true
	local stamp = os.clock()
	toast:SetAttribute("Stamp", stamp)
	task.delay(2.2, function()
		if toast and toast.Parent and toast:GetAttribute("Stamp") == stamp then toast.Visible = false end
	end)
end
]=], [=[
local function showToast(text, _positive)
	sharedNotificationEvent:Fire(text,2.2)
end
]=], "desktop shared notification routing")
desktopHudSource = replaceOnce(desktopHudSource, [=[
local function categoryForVehicle(vehicle, cockpitId)
	local explicit = tostring(vehicle and (vehicle.CategoryId or vehicle.Category) or "")
	if explicit ~= "" then return string.upper(explicit) end
	return string.upper(string.match(tostring(cockpitId or ""), "^([^_]+)") or "OTHER")
end
]=], [=[
local function categoryForVehicle(vehicle, cockpitId)
	local explicit=tostring(vehicle and (vehicle.CategoryId or vehicle.Category) or "")
	return string.upper(DisplayNames.CategoryName(categoriesRoot,explicit,cockpitId))
end
]=], "desktop shared category display name")
desktopHudSource = replaceOnce(desktopHudSource, [=[
	toast = label(root, "Toast", "", UDim2.fromOffset(420, 36), UDim2.new(0.5, -210, 0, 82), T("Caption", 11), C("Text"), Enum.TextXAlignment.Center)
	toast.BackgroundColor3 = C("PanelDeep")
	toast.BackgroundTransparency = 0.12
	toast.BorderSizePixel = 0
	toast.Visible = false
	toast.ZIndex = 60
	corner(toast, 6)
	stroke(toast, C("Outline"), 1.2, 0.2)
]=], [=[
	-- Local toast visuals were retired; SharedTopNotificationController_Active owns notices.
]=], "desktop local toast retirement")
desktopHudSource = replaceOnce(
	desktopHudSource,
	'local money = panel(leftCluster, "Money", UDim2.fromOffset(mapSize, cashHeight), UDim2.fromOffset(0, 0), Vector2.zero, 9)\n\tmoneyPanel=money',
	'local money = panel(leftCluster, "Money", UDim2.fromOffset(mapSize, cashHeight), UDim2.fromOffset(0, 0), Vector2.zero, 9)\n\tfor _,child in ipairs(money:GetChildren()) do if child:IsA("UIStroke") then child:Destroy() end end\n\tmoneyPanel=money',
	"desktop cash duplicate stroke removal"
)
desktopHudSource = "-- " .. MARKER .. "\n" .. desktopHudSource

mobileHudSource = replaceOnce(
	mobileHudSource,
	'local Foundation=require(kit.Shared.Modules.UI:WaitForChild("ResponsiveUIFoundation"))',
	'local Foundation=require(kit.Shared.Modules.UI:WaitForChild("ResponsiveUIFoundation"))\nlocal DisplayNames=require(kit.Shared.Modules.Common:WaitForChild("VehicleDisplayNames"))',
	"mobile shared display-name dependency"
)
mobileHudSource = replaceOnce(
	mobileHudSource,
	"local uiFolder=script.Parent",
	'local uiFolder=script.Parent\nlocal sharedNotificationEvent=uiFolder:WaitForChild("ShowTopNotification")',
	"mobile shared notification dependency"
)
mobileHudSource = replaceOnce(
	mobileHudSource,
	'local toast=label(root,"Toast","",UDim2.fromOffset(420,34),UDim2.fromScale(.5,.12),12,WHITE,Enum.TextXAlignment.Center); toast.AnchorPoint=Vector2.new(.5,0); toast.BackgroundColor3=DEEP; toast.BackgroundTransparency=.15; toast.Visible=false; corner(toast,8); stroke(toast,PINK,1.5,.1)\nlocal function showToast(text,positive) toast.Text=tostring(text); toast.TextColor3=positive and CYAN or WHITE; toast.Visible=true; local stamp=os.clock(); toast:SetAttribute("Stamp",stamp); task.delay(2.2,function() if toast.Parent and toast:GetAttribute("Stamp")==stamp then toast.Visible=false end end) end',
	'-- Local toast visuals were retired; SharedTopNotificationController_Active owns notices.\nlocal function showToast(text,_positive) sharedNotificationEvent:Fire(text,2.2) end',
	"mobile shared notification routing"
)
mobileHudSource = replaceOnce(
	mobileHudSource,
	'local function vehicleCategory(vehicle,cockpitId) local explicit=tostring(vehicle and (vehicle.CategoryId or vehicle.Category) or ""); if explicit~="" then return string.upper(explicit) end; return string.upper(string.match(tostring(cockpitId or ""),"^([^_]+)") or "OTHER") end',
	'local function vehicleCategory(vehicle,cockpitId) local explicit=tostring(vehicle and (vehicle.CategoryId or vehicle.Category) or ""); return string.upper(DisplayNames.CategoryName(categories,explicit,cockpitId)) end',
	"mobile shared category display name"
)
mobileHudSource = replaceOnce(
	mobileHudSource,
	'local cash=panel(root,"Cash",UDim2.fromOffset(170,34),UDim2.fromOffset(0,0),5); cash.BackgroundColor3=Color3.fromRGB(8,42,84); cash.ClipsDescendants=true; local cashStroke=cash:FindFirstChildOfClass("UIStroke"); if cashStroke then cashStroke.Color=BLUE; Foundation.StyleStroke(cashStroke,"Structural") end;',
	'local cash=panel(root,"Cash",UDim2.fromOffset(170,34),UDim2.fromOffset(0,0),5); cash.BackgroundColor3=Color3.fromRGB(8,42,84); cash.ClipsDescendants=true; local cashStroke=cash:FindFirstChildOfClass("UIStroke"); if cashStroke then cashStroke.Name="CashStroke"; cashStroke.Color=BLUE; Foundation.StyleStroke(cashStroke,"Structural") end;',
	"mobile semantic blue cash stroke"
)
mobileHudSource = "-- " .. MARKER .. "\n" .. mobileHudSource

managementSource = replaceOnce(
	managementSource,
	'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local remotes=kit.Shared.Remotes.Garage;',
	'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local DisplayNames=require(kit.Shared.Modules.Common:WaitForChild("VehicleDisplayNames")); local categoriesRoot=kit.Assets.Vehicles:WaitForChild("Categories"); local remotes=kit.Shared.Remotes.Garage;',
	"owned garage shared display-name dependency"
)
managementSource = replaceOnce(
	managementSource,
	'local function vehicleName(profile,vehicleId)\n\t\tlocal vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId or "")]; return type(vehicle)=="table" and tostring(vehicle.DisplayName or vehicle.CockpitId or vehicleId) or tostring(vehicleId or "")\n\tend',
	'local function vehicleName(profile,vehicleId)\n\t\treturn DisplayNames.FullVehicleName(profile,vehicleId,categoriesRoot)\n\tend',
	"owned garage prompt full vehicle name"
)
managementSource = "-- " .. MARKER .. "\n" .. managementSource

foundationSource,ownedBrowserSource,mobileHudSource,raceSessionSource=applyRevision(
	foundationSource,
	ownedBrowserSource,
	mobileHudSource,
	raceSessionSource
)

local projected = {
	VehicleDisplayNames = DISPLAY_NAMES_SOURCE,
	ResponsiveUIFoundation = foundationSource,
	OwnedGarageBrowserController = ownedBrowserSource,
	GarageReplacementComponents = garageSharedSource,
	GarageWorkspaceController = garageWorkspaceSource,
	DesktopFreeRoamHudController = desktopHudSource,
	MobileFreeRoamHudController = mobileHudSource,
	MobileDriveControlsController = mobileControlsSource,
	OwnedGarageManagementRuntime = managementSource,
	RaceSessionPresentationController = raceSessionSource,
}
for name, source in pairs(projected) do
	compile(name, source)
	assert(#source < 199000, name .. " projected Source exceeds the safe Studio assignment limit (" .. #source .. ")")
end

local oldHeaderHeight = uiConfig:GetAttribute("HeaderHeight")
local oldSources = {
	[foundation] = foundation.Source,
	[ownedBrowser] = ownedBrowser.Source,
	[garageShared] = garageShared.Source,
	[garageWorkspace] = garageWorkspace.Source,
	[desktopHud] = desktopHud.Source,
	[mobileHud] = mobileHud.Source,
	[mobileControls] = mobileControls.Source,
	[management] = management.Source,
	[raceSession] = raceSession.Source,
}
local createdNames
local ok, err = pcall(function()
	createdNames = Instance.new("ModuleScript")
	createdNames.Name = "VehicleDisplayNames"
	createdNames.Source = DISPLAY_NAMES_SOURCE
	createdNames.Parent = commonModules

	foundation.Source = foundationSource
	ownedBrowser.Source = ownedBrowserSource
	garageShared.Source = garageSharedSource
	garageWorkspace.Source = garageWorkspaceSource
	desktopHud.Source = desktopHudSource
	mobileHud.Source = mobileHudSource
	mobileControls.Source = mobileControlsSource
	management.Source = managementSource
	raceSession.Source = raceSessionSource
	uiConfig:SetAttribute("HeaderHeight", 82)

	assert(audit(), "Post-install audit failed")
end)

if not ok then
	for object, source in pairs(oldSources) do object.Source = source end
	uiConfig:SetAttribute("HeaderHeight", oldHeaderHeight)
	if createdNames and createdNames.Parent then createdNames:Destroy() end
	error(PREFIX .. " rolled back atomically: " .. tostring(err))
end

print(PREFIX .. " INSTALL COMPLETE")
print(PREFIX .. " Restart Play and verify content-sized white notifications, Race Exit-sized confirmations, dimmed objectives, owned garage footer parity, mobile race telemetry, and the retained Phase 1 refinements.")
