-- Neo Tokyo Racers - Canonical garage scaled-touch responsive installer V1.2
-- NTR_GARAGE_RESPONSIVE_SCALED_TOUCH_V1_2
--
-- Run once from the Studio Edit Command Bar, then restart Play.
-- V1.2 keeps one desktop composition and scales it uniformly on touch. Only
-- carousel arrows retain an intentional physical-size exception. Shared shell,
-- listing-card status text and the three-card upgrade budget are installed and
-- rolled back as one canonical transaction.

local MODE = "INSTALL" -- INSTALL or AUDIT
local REVISION = "NTR_GARAGE_RESPONSIVE_SCALED_TOUCH_V1_2"
local PREFIX = "[NTR Garage Responsive Scaled Touch V1.2]"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object, parent:GetFullName() .. "." .. name .. " missing")
	if className then assert(object:IsA(className), object:GetFullName() .. " must be " .. className) end
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local function replaceSection(source, startMarker, endMarker, replacement, label)
	local first = string.find(source, startMarker, 1, true)
	assert(first, "Missing section start: " .. label)
	assert(not string.find(source, startMarker, first + #startMarker, true), "Duplicate section start: " .. label)
	local endFirst = string.find(source, endMarker, first + #startMarker, true)
	assert(endFirst, "Missing section end: " .. label)
	return string.sub(source, 1, first - 1) .. replacement .. "\n" .. string.sub(source, endFirst)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")
local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local uiRoot = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local shared = need(uiRoot, "GarageReplacementComponents", "ModuleScript")
local browser = need(uiRoot, "GarageBrowserController", "ModuleScript")
local workspaceController = need(uiRoot, "GarageWorkspaceController", "ModuleScript")

local sharedSource = shared.Source
local workspaceSource = workspaceController.Source
local alreadyInstalled = string.find(sharedSource, REVISION, 1, true) ~= nil and string.find(workspaceSource, "NTR_GARAGE_RESPONSIVE_BUDGET_V1_2", 1, true) ~= nil

assert(string.find(sharedSource, "NTR_GARAGE_SHARED_SHELL_CANONICAL_HOST_V3", 1, true) or alreadyInstalled, "Confirmed canonical shared-shell baseline missing")
assert(string.find(sharedSource, "-- NTR_GARAGE_SHARED_SHELL_V2", 1, true), "Shared shell start marker missing")
assert(string.find(sharedSource, "-- NTR_GARAGE_INDEPENDENT_CANONICAL_HOST_V1", 1, true), "Shared shell end marker missing")
assert(string.find(browser.Source, "Shared.LayoutGarageShell", 1, true), "Browser no longer consumes the shared shell")
assert(string.find(workspaceSource, "Shared.LayoutGarageShell", 1, true), "Workspace no longer consumes the shared shell")

if not alreadyInstalled then
	if not string.find(sharedSource, [[local UserInputService=game:GetService("UserInputService")]], 1, true) then
		sharedSource = replaceOnce(sharedSource, [[local RunService=game:GetService("RunService")]], [[local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")]], "shared input service")
	end

	if not string.find(sharedSource, "NTR_GARAGE_RESPONSIVE_STATUS_TEXT_V1_2", 1, true) then
		sharedSource = replaceOnce(
			sharedSource,
			[[local priceText=props.PriceText or (props.Price~=nil and ("$"..tostring(props.Price)) or nil); if priceText~=nil and state~="Locked" then local price=Racing.Label(card,{Name="Price",Text=tostring(priceText),Position=UDim2.fromOffset(12,74),Size=UDim2.new(1,-24,0,23),TextSize=14,Color=props.PriceColor or Color3.fromRGB(89,255,102),Role="Heading"}); price.ZIndex=card.ZIndex+2 end -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1]],
			[[local priceText=props.PriceText or (props.Price~=nil and ("$"..tostring(props.Price)) or nil); if priceText~=nil and state~="Locked" then local price=Racing.Label(card,{Name="Price",Text=tostring(priceText),Position=UDim2.fromOffset(12,74),Size=UDim2.new(1,-24,0,23),TextSize=13,Color=props.PriceColor or Color3.fromRGB(89,255,102),Role="Heading",Truncate=Enum.TextTruncate.None}); price.TextScaled=false; price.TextWrapped=false; price.ZIndex=card.ZIndex+2 end -- NTR_GARAGE_RESPONSIVE_STATUS_TEXT_V1_2]],
			"shared terminal status label"
		)
	end

	local responsiveSection = [====[
-- NTR_GARAGE_SHARED_SHELL_V2
-- NTR_GARAGE_RESPONSIVE_SCALED_TOUCH_V1_2
local responsiveAuditKeys=setmetatable({},{__mode="k"})
local responsiveConfig=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local function responsiveNumber(N,name,fallback) local value=responsiveConfig:GetAttribute(name); if typeof(value)=="number" then return value end; return N(name,fallback) end
local function rememberSize(object)
	local original=object:GetAttribute("NTRResponsiveOriginalSize")
	if typeof(original)~="UDim2" then original=object.Size; object:SetAttribute("NTRResponsiveOriginalSize",original) end
	return original
end
local function restoreResponsive(root)
	for _,object in ipairs(root:GetDescendants()) do
		local originalSize=object:GetAttribute("NTRResponsiveOriginalSize"); if typeof(originalSize)=="UDim2" then object.Size=originalSize end
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			local originalText=object:GetAttribute("NTRResponsiveOriginalTextSize"); if type(originalText)=="number" then object.TextSize=originalText end
			local originalScaled=object:GetAttribute("NTRResponsiveOriginalTextScaled"); if type(originalScaled)=="boolean" then object.TextScaled=originalScaled end
			local constraint=object:FindFirstChild("NTRTouchTextConstraint"); if constraint then constraint:Destroy() end
		end
	end
end
local function targetSize(object,pixels,scale)
	if not (object and object:IsA("GuiObject")) then return end
	local original=rememberSize(object); local minimum=pixels/math.max(scale,.01); local xo,yo=original.X.Offset,original.Y.Offset
	if original.X.Scale==0 then xo=math.max(xo,math.ceil(minimum)) end
	if original.Y.Scale==0 then yo=math.max(yo,math.ceil(minimum)) end
	object.Size=UDim2.new(original.X.Scale,xo,original.Y.Scale,yo)
end
local function applyTouchPresentation(ui,N,scale)
	restoreResponsive(ui.Root)
	if not UserInputService.TouchEnabled then return end
	local arrow=math.max(28,responsiveNumber(N,"TouchArrowPixels",32))
	for _,button in ipairs({ui.Left,ui.RightArrow}) do targetSize(button,arrow,scale) end
end
local function queueResponsiveAudit(ui,options,N,viewport,scale,categoryTop)
	if not (UserInputService.TouchEnabled and ui.Root.Visible) then return end
	local title=ui.Context and ui.Context.Title or "Browser"; local key=string.format("%dx%d:%s",math.floor(viewport.X),math.floor(viewport.Y),tostring(title)); if responsiveAuditKeys[ui]==key then return end; responsiveAuditKeys[ui]=key
	task.defer(function()
		RunService.Heartbeat:Wait(); if not (ui.Root and ui.Root.Parent and ui.Root.Visible) then return end
		local failures={}; local function expect(ok,message) if not ok then table.insert(failures,message) end end; local arrow=math.max(28,responsiveNumber(N,"TouchArrowPixels",32))
		local canvas=ui.Host and ui.Host.Canvas; if canvas then local p,s=canvas.AbsolutePosition,canvas.AbsoluteSize; expect(p.X>=-1 and p.Y>=-1,"canvas begins outside viewport"); expect(p.X+s.X<=viewport.X+1 and p.Y+s.Y<=viewport.Y+1,"canvas ends outside viewport") end
		for _,button in ipairs({ui.Left,ui.RightArrow}) do if button and button.Visible then expect(button.AbsoluteSize.X>=arrow-1 and button.AbsoluteSize.Y>=arrow-1,"undersized carousel arrow "..button.Name) end end
		if ui.Categories and ui.Categories.Visible then expect(math.abs(ui.Categories.AbsolutePosition.Y-categoryTop)<=3,"category rail top differs from free-roam contract") end
		for _,container in ipairs({ui.Cash,ui.Capacity}) do if container then for _,button in ipairs(container:GetDescendants()) do if button:IsA("GuiButton") and button.Visible then local p,s=button.AbsolutePosition,button.AbsoluteSize; local cp,cs=container.AbsolutePosition,container.AbsoluteSize; expect(p.X>=cp.X-1 and p.Y>=cp.Y-1 and p.X+s.X<=cp.X+cs.X+1 and p.Y+s.Y<=cp.Y+cs.Y+1,"economy action escapes its card") end end end end
		for _,button in ipairs(options.Actions or {}) do if button.Visible then expect(button.AbsolutePosition.X+button.AbsoluteSize.X<=ui.Root.AbsolutePosition.X+ui.Root.AbsoluteSize.X+1,"action escapes viewport "..button.Name) end end
		for _,object in ipairs(ui.Root:GetDescendants()) do if object:IsA("TextLabel") and object.Name=="Price" and string.find(string.upper(tostring(object.Text)),"POINT LIMIT REACHED",1,true) then expect(object.TextTruncate==Enum.TextTruncate.None,"point-limit status truncation enabled"); expect(object.TextBounds.X<=object.AbsoluteSize.X+2,"point-limit status exceeds label") end end
		if ui.Categories and ui.Categories.Visible and ui.Carousel then expect(ui.Categories.AbsolutePosition.Y+ui.Categories.AbsoluteSize.Y<=ui.Carousel.AbsolutePosition.Y-2,"categories overlap carousel") end
		if ui.Popup and ui.Popup.Shell.Visible and ui.Budget and ui.Budget.Visible then expect(ui.Budget.AbsolutePosition.Y+ui.Budget.AbsoluteSize.Y<=ui.Popup.Shell.AbsolutePosition.Y-2,"budget overlaps card action") end
		if #failures==0 then print("[NTR Garage Responsive Runtime] PASS "..key.." scale="..string.format("%.3f",scale)) else warn("[NTR Garage Responsive Runtime] FAIL "..key.." | "..table.concat(failures," | ")) end
	end)
end
function M.LayoutGarageShell(ui,options)
	-- NTR_GARAGE_SHARED_SHELL_CANONICAL_HOST_V3
	options=options or {}; local N=assert(options.Number,"Garage shell Number resolver missing"); local viewport=options.Viewport or Vector2.new(1600,900); local touch=UserInputService.TouchEnabled and responsiveNumber(N,"ResponsiveTouchEnabled",1)~=0
	local safeTop=touch and math.max(0,responsiveNumber(N,"TouchSafeTop",4)) or 0; local safeBottom=touch and math.max(0,responsiveNumber(N,"TouchSafeBottom",4)) or 0; local safeSide=touch and math.max(0,responsiveNumber(N,"TouchSafeSide",4)) or 0; local availableWidth=math.max(1,viewport.X-safeSide*2); local availableHeight=math.max(1,viewport.Y-safeTop-safeBottom)
	local minimum=touch and math.max(.1,responsiveNumber(N,"TouchScaleMin",.25)) or (options.MinimumScale or .68); local scale=math.clamp(math.min(availableWidth/N("BaseWidth",1600),availableHeight/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); ui.Scale.Scale=scale; local vw,vh=availableWidth/scale,availableHeight/scale
	if ui.Host and ui.Host.Canvas then ui.Host.Canvas.Position=UDim2.fromOffset(safeSide,safeTop); ui.Host.Canvas.Size=UDim2.fromOffset(vw,vh) end; ui.Root.Position=UDim2.fromOffset(0,0); ui.Root.Size=UDim2.fromOffset(vw,vh)
	applyTouchPresentation(ui,N,scale)
	if ui.Right then ui.Right.Name="Right" end; if ui.Economy then ui.Economy.Name="Economy" end; if ui.Carousel then ui.Carousel.Name="Carousel" end; if ui.Paint then ui.Paint.Name="Paint" end; if ui.Scroller and ui.Scroller.Name=="Frame" then ui.Scroller.Name="CarouselScroller" end
	local margin,gap=N("Margin",18),N("Gap",14); local carouselH=N("CarouselHeight",166); local carouselTop=vh-margin-carouselH; local arrowW=N("ArrowWidth",42); local railReserve=30; ui.LayoutScale=scale; ui.ReferenceWidth=vw
	ui.Header.AnchorPoint=Vector2.new(.5,0); ui.Header.Position=UDim2.fromOffset(vw*.5,28); ui.Header.Size=UDim2.fromOffset(420,62)
	local categoryTop=touch and responsiveNumber(N,viewport.Y<500 and "TouchCategoryTopTiny" or "TouchCategoryTop",viewport.Y<500 and 68 or 82) or (safeTop+72*scale); local categoryY=touch and math.max(0,(categoryTop-safeTop)/math.max(scale,.01)) or 72
	local categoryWidth=ui.Context and ui.Context.LeftCardMode and N("ModuleCategoryRailWidth",238) or N("CategoryWidth",214); ui.Categories.Position=UDim2.fromOffset(margin,categoryY); ui.Categories.Size=UDim2.fromOffset(categoryWidth,math.max(170,carouselTop-categoryY-N("CategoryCarouselClearance",82)))
	ui.Right.AnchorPoint=Vector2.new(1,0); ui.Right.Position=UDim2.fromOffset(vw-margin,28); ui.Right.Size=UDim2.fromOffset(N("StatsWidth",354),0); ui.Stats.LayoutOrder=1; ui.Economy.LayoutOrder=2; ui.Economy.Size=UDim2.new(1,0,0,N("EconomyHeight",46)); local rightLayout=ui.Right:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout"); rightLayout.Padding=UDim.new(0,gap); rightLayout.SortOrder=Enum.SortOrder.LayoutOrder; rightLayout.Parent=ui.Right
	ui.Cash.Position=UDim2.fromOffset(0,0); ui.Cash.Size=UDim2.new(.5,-gap*.5,1,0); ui.Capacity.AnchorPoint=Vector2.new(1,0); ui.Capacity.Position=UDim2.fromScale(1,0); ui.Capacity.Size=UDim2.new(.5,-gap*.5,1,0)
	ui.Carousel.Position=UDim2.fromOffset(margin+railReserve+gap,carouselTop); ui.Carousel.Size=UDim2.fromOffset(vw-2*(margin+railReserve+gap),carouselH); if ui.Scroller then ui.Scroller.Size=UDim2.fromScale(1,1) end; if ui.Paint then ui.Paint.Size=UDim2.fromScale(1,1) end; ui.ReferenceCarouselWidth=vw-2*(margin+railReserve+gap)
	ui.Left.AnchorPoint=Vector2.new(0,.5); ui.Left.Position=UDim2.fromOffset(margin,carouselTop+carouselH*.5); ui.Left.Size=UDim2.fromOffset(math.max(arrowW,ui.Left.Size.X.Offset),math.max(N("ArrowHeight",72),ui.Left.Size.Y.Offset)); ui.RightArrow.AnchorPoint=Vector2.new(1,.5); ui.RightArrow.Position=UDim2.fromOffset(vw-margin,carouselTop+carouselH*.5); ui.RightArrow.Size=UDim2.fromOffset(math.max(arrowW,ui.RightArrow.Size.X.Offset),math.max(N("ArrowHeight",72),ui.RightArrow.Size.Y.Offset))
	local actionX=vw-margin; for _,actionButton in ipairs(options.Actions or {}) do if actionButton.Visible then actionButton.AnchorPoint=Vector2.new(1,1); actionButton.Position=UDim2.fromOffset(actionX,carouselTop-gap); actionX-=actionButton.Size.X.Offset+gap end end
	queueResponsiveAudit(ui,options,N,viewport,scale,categoryTop)
	return {Scale=scale,Width=vw,Height=vh,CarouselTop=carouselTop,Touch=touch,SafeTop=safeTop,SafeBottom=safeBottom,SafeSide=safeSide}
end
]====]

	sharedSource = replaceSection(sharedSource, "-- NTR_GARAGE_SHARED_SHELL_V2", "-- NTR_GARAGE_INDEPENDENT_CANONICAL_HOST_V1", responsiveSection, "canonical shared shell")

	if not string.find(workspaceSource, "NTR_GARAGE_RESPONSIVE_BUDGET_V1_2", 1, true) then
		workspaceSource = replaceOnce(
			workspaceSource,
			[[self.Budget.AnchorPoint=Vector2.new(.5,1); self.Budget.Position=UDim2.fromOffset(shell.Width*.5,shell.CarouselTop-N("UpgradeBudgetPopupClearance",48)); self.Budget.Size=UDim2.fromOffset(N("UpgradeBudgetWidth",430),N("UpgradeBudgetHeight",34))]],
			[[local budgetColumns=3; local budgetGap=12; local budgetWidth=math.min(budgetColumns*N("WorkspaceCardWidth",210)+(budgetColumns-1)*budgetGap,math.max(1,shell.Width-2*N("Margin",18))); self.BudgetWidth=budgetWidth -- NTR_GARAGE_RESPONSIVE_BUDGET_V1_2
	self.Budget.AnchorPoint=Vector2.new(.5,1); self.Budget.Position=UDim2.fromOffset(shell.Width*.5,shell.CarouselTop-N("UpgradeBudgetPopupClearance",48)); self.Budget.Size=UDim2.fromOffset(budgetWidth,N("UpgradeBudgetHeight",42))]],
			"workspace three-card budget layout"
		)

		local budgetFunction = [====[
function WorkspaceUI:RenderBudget(context)
	clear(self.Budget); local budget=context.UpgradeBudget; self.Budget.Visible=typeof(budget)=="table"; if not self.Budget.Visible then return end
	local capacity=math.max(0,math.floor(tonumber(budget.Capacity) or 0)); local used=math.clamp(math.floor(tonumber(budget.Used) or 0),0,capacity); local width=self.BudgetWidth or (3*N("WorkspaceCardWidth",210)+24); local height=N("UpgradeBudgetHeight",42); local textSize=13
	local budgetTitle=generated(Racing.Label(self.Budget,{Name="BudgetTitle",Text=string.upper(budget.Label or "UPGRADE POINTS"),Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(180,height),TextSize=textSize,Role="Heading",Truncate=Enum.TextTruncate.None})); budgetTitle.TextScaled=false; budgetTitle.TextWrapped=false; budgetTitle.ZIndex=self.Budget.ZIndex+2
	local pipWidth=N("UpgradeBudgetPipWidth",18); local pipGap=N("UpgradeBudgetPipGap",5); local totalWidth=capacity*pipWidth+math.max(0,capacity-1)*pipGap; local startX=(width-totalWidth)*.5; local pipY=(height-16)*.5
	for index=1,capacity do local pip=generated(Instance.new("Frame")); pip.Name="Point"..index; pip.Position=UDim2.fromOffset(startX+(index-1)*(pipWidth+pipGap),pipY); pip.Size=UDim2.fromOffset(pipWidth,16); pip.BorderSizePixel=0; pip.BackgroundColor3=index<=used and (used==capacity and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)); pip.ZIndex=self.Budget.ZIndex+2; pip.Parent=self.Budget; Racing.Corner(pip,4); if index<=used and used<capacity then local gradient=Instance.new("UIGradient"); gradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))); gradient.Parent=pip end end
	local budgetUsed=generated(Racing.Label(self.Budget,{Name="BudgetUsed",Text=tostring(used).."/"..tostring(capacity).." USED",Position=UDim2.new(1,-132,0,0),Size=UDim2.fromOffset(120,height),TextSize=textSize,XAlignment=Enum.TextXAlignment.Right,Role="Heading",Truncate=Enum.TextTruncate.None})); budgetUsed.TextScaled=false; budgetUsed.TextWrapped=false; budgetUsed.ZIndex=self.Budget.ZIndex+2
end -- NTR_GARAGE_RESPONSIVE_BUDGET_RENDERER_V1_2
]====]
		workspaceSource = replaceSection(workspaceSource, "function WorkspaceUI:RenderBudget(context)", "function WorkspaceUI:RenderCards(context)", budgetFunction, "workspace budget renderer")
	end
end

compile("GarageReplacementComponents", sharedSource)
compile("GarageWorkspaceController", workspaceSource)

local defaults = {
	ResponsiveTouchEnabled = 1,
	TouchSafeTop = 4,
	TouchSafeBottom = 4,
	TouchSafeSide = 4,
	TouchScaleMin = 0.25,
	TouchArrowPixels = 32,
	TouchCategoryTopTiny = 68,
	TouchCategoryTop = 82,
	TouchVisualControlScaling = 0,
}

local function audit()
	local pass, fail = 0, 0
	local function check(condition, message) if condition then pass += 1; print(PREFIX .. " PASS - " .. message) else fail += 1; warn(PREFIX .. " FAIL - " .. message) end end
	local installedShared, installedWorkspace = shared.Source, workspaceController.Source
	check(string.find(installedShared, REVISION, 1, true) ~= nil, "shared responsive owner installed")
	check(select(2,string.gsub(installedShared,REVISION,""))==1, "responsive revision is unique")
	check(string.find(installedWorkspace, "NTR_GARAGE_RESPONSIVE_BUDGET_V1_2", 1, true) ~= nil, "three-card budget installed")
	check(string.find(installedShared, "NTR_GARAGE_RESPONSIVE_STATUS_TEXT_V1_2", 1, true) ~= nil, "non-truncating terminal status installed")
	check(string.find(installedShared, "applyTouchPresentation(ui,N,scale)", 1, true) ~= nil, "touch presentation pass installed")
	check(not string.find(installedShared, "TouchActionPixels", 1, true), "touch action enlargement retired")
	check(not string.find(installedShared, "TouchPopupPixels", 1, true), "touch popup enlargement retired")
	check(not string.find(installedShared, "TouchCompactTargetPixels", 1, true), "touch economy enlargement retired")
	check(not string.find(installedShared, "fitDenseTouchText", 1, true), "automatic dense-text enlargement retired")
	check(string.find(installedShared, [[viewport.Y<500 and "TouchCategoryTopTiny" or "TouchCategoryTop"]], 1, true) ~= nil, "free-roam top-offset contract installed")
	check(string.find(installedWorkspace, [[local budgetTitle=generated(Racing.Label(self.Budget,{Name="BudgetTitle"]], 1, true) ~= nil, "fixed-size budget title installed")
	check(string.find(installedWorkspace, [[local budgetUsed=generated(Racing.Label(self.Budget,{Name="BudgetUsed"]], 1, true) ~= nil, "fixed-size budget used label installed")
	check(string.find(browser.Source, "Shared.LayoutGarageShell", 1, true) ~= nil, "Browser still consumes shared layout")
	check(string.find(installedWorkspace, "Shared.LayoutGarageShell", 1, true) ~= nil, "Workspace still consumes shared layout")
	for name,value in pairs(defaults) do check(config:GetAttribute(name)==value,name.."="..tostring(value)) end
	local sharedOk=pcall(function() compile("GarageReplacementComponentsReadback",installedShared) end); check(sharedOk,"installed shared source compiles on readback")
	local workspaceOk=pcall(function() compile("GarageWorkspaceControllerReadback",installedWorkspace) end); check(workspaceOk,"installed workspace source compiles on readback")
	print(string.format("%s SUMMARY pass=%d fail=%d",PREFIX,pass,fail)); assert(fail==0,"Post-install audit failed")
end

if MODE=="AUDIT" then audit(); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local oldSharedSource,oldWorkspaceSource=shared.Source,workspaceController.Source
local oldAttributes={}; for name in pairs(defaults) do oldAttributes[name]={Value=config:GetAttribute(name)} end
local oldInstalledBy=config:GetAttribute("ResponsiveInstalledBy")

local ok,err=pcall(function()
	shared.Source=sharedSource; workspaceController.Source=workspaceSource
	for name,value in pairs(defaults) do config:SetAttribute(name,value) end
	config:SetAttribute("ResponsiveInstalledBy",REVISION)
	audit()
end)

if not ok then
	pcall(function()
		shared.Source=oldSharedSource; workspaceController.Source=oldWorkspaceSource
		for name,record in pairs(oldAttributes) do config:SetAttribute(name,record.Value) end
		config:SetAttribute("ResponsiveInstalledBy",oldInstalledBy)
	end)
	error(PREFIX.." rolled back after failure: "..tostring(err),0)
end

print(PREFIX.." INSTALL COMPLETE - Restart Play and test Dealership, Build, Customise and Upgrades on phone/tablet Device Emulator profiles.")
