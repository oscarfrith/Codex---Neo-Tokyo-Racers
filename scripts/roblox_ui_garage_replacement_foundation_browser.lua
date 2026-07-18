-- Neo Tokyo Racers - Canonical Garage Replacement: shared shell + vehicle browser
-- Run in Studio Edit mode. Replaces CockpitShop presentation and exposes already-calculated owned headline stats; gameplay/data remain authoritative.
-- NTR_GARAGE_REPLACEMENT_BROWSER_V1_4

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function need(parent, name, className)
	local object = parent and parent:FindFirstChild(name)
	assert(object and (not className or object:IsA(className)), "Missing " .. tostring(name))
	return object
end
local function ensure(parent, className, name)
	local object = parent:FindFirstChild(name)
	if object and not object:IsA(className) then object:Destroy(); object = nil end
	if not object then object = Instance.new(className); object.Name = name; object.Parent = parent end
	return object
end
local function countPlain(text, needle)
	local count, cursor = 0, 1
	while true do local a, b = string.find(text, needle, cursor, true); if not a then return count end; count += 1; cursor = b + 1 end
end
local function replaceOnce(text, old, new, label)
	assert(countPlain(text, old) == 1, label .. " anchor count changed")
	local a, b = string.find(text, old, 1, true)
	return string.sub(text, 1, a - 1) .. new .. string.sub(text, b + 1)
end
local function value(parent, className, name, default)
	local object = ensure(parent, className, name)
	if object:GetAttribute("GarageReplacementDefault") ~= true and object.Value == (className == "StringValue" and "" or 0) then object.Value = default; object:SetAttribute("GarageReplacementDefault", true) end
	return object
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local clientRoot = need(StarterPlayer.StarterPlayerScripts, "NeoTokyoRacersClient", "Folder")
local uiControllers = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local bootstrap = need(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript")
local garageServer = need(need(need(need(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder"), "Garage", "Folder"), "GarageActionController_Shadow_Disabled", "Script")
assert(string.find(bootstrap.Source, "NTR_GARAGE_CANONICAL_PRESENTATION_OWNS_GEOMETRY", 1, true), "Refresh/current V3 bootstrap required")
assert(countPlain(bootstrap.Source, "renderCockpitShop = function()") == 1, "Cockpit browser owner missing")
assert(countPlain(bootstrap.Source, "local function channelTitle(channel)") == 1, "Cockpit browser end missing")

local config = ensure(ensure(ensure(kit, "Folder", "Config"), "Folder", "UI"), "Folder", "GarageReplacement")
value(config, "NumberValue", "BaseWidth", 1600)
value(config, "NumberValue", "BaseHeight", 900)
value(config, "NumberValue", "DesktopMinScale", 0.68)
value(config, "NumberValue", "MobileMinScale", 0.42)
value(config, "NumberValue", "MaxScale", 1.02)
value(config, "NumberValue", "Margin", 18)
value(config, "NumberValue", "Gap", 14)
value(config, "NumberValue", "CategoryWidth", 214)
value(config, "NumberValue", "StatsWidth", 354)
value(config, "NumberValue", "CarouselHeight", 166)
value(config, "NumberValue", "CardWidth", 226)
value(config, "NumberValue", "CardHeight", 146)
local cardImageHeight = value(config, "NumberValue", "CardImageHeight", 136)
if cardImageHeight:GetAttribute("GarageReplacementDefault") == true and cardImageHeight.Value == 112 then cardImageHeight.Value = 136 end
value(config, "NumberValue", "ModuleCardImageHeight", 104)
local arrowWidth = value(config, "NumberValue", "ArrowWidth", 42)
if arrowWidth:GetAttribute("GarageReplacementDefault") == true and arrowWidth.Value == 30 then arrowWidth.Value = 42 end
value(config, "NumberValue", "ArrowHeight", 72)
value(config, "NumberValue", "CategoryButtonHeight", 46)
value(config, "NumberValue", "CategoryCarouselClearance", 82)
value(config, "NumberValue", "EconomyHeight", 46)
value(config, "NumberValue", "StatReference", 180)

local componentsSource = [==[
-- NTR_GARAGE_REPLACEMENT_SHARED_COMPONENTS_V1
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Racing=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local inRace=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing"):WaitForChild("InRace")
local M={}
local function metricNumber(name,fallback) local v=inRace:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function gradient(parent,a,b,rotation)
	local g=Instance.new("UIGradient"); g.Name="SurfaceGradient"; g.Color=ColorSequence.new(a,b); g.Rotation=rotation or 90; g.Parent=parent; return g
end
function M.Panel(parent,name,props)
	props=props or {}; local p=Racing.Panel(parent,{Name=name,Color=props.Color or Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),Transparency=props.Transparency or .12,StrokeColor=props.StrokeColor or Racing.Colour("Outline",Color3.fromRGB(244,46,151)),StrokeTransparency=props.StrokeTransparency or .12,StrokeWidth=props.StrokeWidth,NoStroke=props.NoStroke==true,NoGlow=props.NoGlow==true})
	gradient(p,Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90); return p
end
function M.MetricCard(parent,name)
	local p=Racing.Panel(parent,{Name=name,Color=Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Transparency=metricNumber("MetricCardTransparency",.34),NoStroke=true}); local corner=p:FindFirstChildOfClass("UICorner"); if corner then corner.CornerRadius=UDim.new(0,metricNumber("MetricCardCornerRadius",9)) end; local g=gradient(p,Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90); g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(1,.28)}); return p
end
function M.Card(parent,props)
	props=props or {}; local selected=props.Selected==true; local accent=selected and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175))
	local card=Racing.Button(parent,{Name=props.Name or "GarageCard",Text="",Size=props.Size or UDim2.fromOffset(226,146),Color=selected and Color3.fromRGB(18,45,54) or Racing.Colour("Panel",Color3.fromRGB(15,19,24)),StrokeColor=accent,FocusColor=Racing.Colour("Telemetry"),StrokeWidth=selected and 2 or 1.2})
	card:SetAttribute("CanonicalGarageCard",true); card.ClipsDescendants=false
	local imageH=props.ImageHeight or 136
	local holder=Instance.new("Frame"); holder.Name="ImageSlot"; holder.BackgroundTransparency=1; holder.BorderSizePixel=0; holder.ClipsDescendants=true; holder.Position=UDim2.fromOffset(5,4); holder.Size=UDim2.new(1,-10,0,imageH); holder.ZIndex=card.ZIndex+2; holder.Parent=card
	Racing.Corner(holder,5)
	local imageZoom=props.ImageZoom or 1.06; local image=Instance.new("ImageLabel"); image.Name="Artwork"; image.BackgroundTransparency=1; image.BorderSizePixel=0; image.AnchorPoint=Vector2.new(.5,.5); image.Position=UDim2.fromScale(.5,.5); image.Size=UDim2.fromScale(imageZoom,imageZoom); image.ScaleType=props.ImageScaleType or Enum.ScaleType.Fit; image.Image=props.Image or ""; image.ZIndex=holder.ZIndex+1; image.Parent=holder; Racing.Corner(image,5)
	local overlayName=props.NameOverlay~=false
	if overlayName then local plate=Instance.new("Frame"); plate.Name="NamePlate"; plate.BackgroundColor3=Color3.fromRGB(5,8,12); plate.BackgroundTransparency=.16; plate.BorderSizePixel=0; plate.Position=UDim2.new(0,5,1,-29); plate.Size=UDim2.new(1,-10,0,25); plate.ZIndex=holder.ZIndex+2; plate.Parent=card; Racing.Corner(plate,4); local fade=Instance.new("UIGradient"); fade.Rotation=90; fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.46),NumberSequenceKeypoint.new(1,.06)}); fade.Parent=plate; local name=Racing.Label(plate,{Name="ItemName",Text=props.DisplayName or "",Position=UDim2.fromOffset(8,1),Size=UDim2.new(1,-16,1,-2),TextSize=12,XAlignment=Enum.TextXAlignment.Center,Truncate=Enum.TextTruncate.AtEnd,Role="Button"}); name.ZIndex=plate.ZIndex+1 else local name=Racing.Label(card,{Name="ItemName",Text=props.DisplayName or "",Position=UDim2.fromOffset(9,imageH+6),Size=UDim2.new(1,-18,0,20),TextSize=10,XAlignment=Enum.TextXAlignment.Center,Truncate=Enum.TextTruncate.AtEnd}); name.ZIndex=card.ZIndex+4 end
	if props.Rating then local badge=Instance.new("Frame"); badge.Name="RatingBadge"; badge.AnchorPoint=Vector2.new(1,0); badge.Position=UDim2.new(1,-8,0,8); badge.Size=UDim2.fromOffset(68,21); badge.BackgroundColor3=props.RatingColor or accent; badge.BorderSizePixel=0; badge.ZIndex=card.ZIndex+6; badge.Parent=card; Racing.Corner(badge,4); local t=Racing.Label(badge,{Text=props.Rating,Size=UDim2.fromScale(1,1),TextSize=9,XAlignment=Enum.TextXAlignment.Center}); t.ZIndex=badge.ZIndex+1 end
	return card
end
function M.ModuleCard(parent,props) props=props or {}; props.ImageHeight=props.ImageHeight or 104; props.ImageZoom=props.ImageZoom or 1; props.NameOverlay=false; props.ImageScaleType=props.ImageScaleType or Enum.ScaleType.Fit; return M.Card(parent,props) end
function M.Popup(root)
	local shell=Instance.new("Frame"); shell.Name="CardActionPopup"; shell.BackgroundTransparency=1; shell.BorderSizePixel=0; shell.AnchorPoint=Vector2.new(.5,1); shell.Size=UDim2.fromOffset(194,38); shell.Visible=false; shell.ZIndex=100; shell.Parent=root
	local button=Racing.Button(shell,{Name="Action",Text="",Size=UDim2.fromScale(1,1),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),FocusColor=Racing.Colour("Telemetry"),ZIndex=102})
	local target,callback,scaleObject
	button.Activated:Connect(function() if callback then callback() end end)
	local connection=RunService.RenderStepped:Connect(function()
		if not (shell.Visible and target and target.Parent and root.Visible) then return end
		local scale=scaleObject and scaleObject.Scale or 1; local rootPos=root.AbsolutePosition
		shell.Position=UDim2.fromOffset((target.AbsolutePosition.X+target.AbsoluteSize.X*.5-rootPos.X)/math.max(scale,.01),(target.AbsolutePosition.Y-rootPos.Y)/math.max(scale,.01)-8)
	end)
	return {Shell=shell,Set=function(_,newTarget,text,fn,newScale) target=newTarget; callback=fn; scaleObject=newScale; button.Text=string.upper(text or ""); shell.Visible=target~=nil end,Hide=function() shell.Visible=false; target=nil; callback=nil end,Destroy=function() connection:Disconnect(); shell:Destroy() end}
end
return M
]==]

local browserSource = [==[
-- NTR_GARAGE_REPLACEMENT_BROWSER_CONTROLLER_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Racing=require(kit.Shared.Modules.UI.RacingUIComponents)
local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents"))
local cfg=kit.Config.UI:WaitForChild("GarageReplacement")
local desktop=kit.Config.UI:WaitForChild("DesktopFreeRoamHud")
local inRace=kit.Config.UI.Racing:WaitForChild("InRace")
local function N(name,fallback) local v=cfg:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function RN(name,fallback) local v=inRace:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function asset(name) local f=desktop:FindFirstChild("Assets"); local v=f and f:FindFirstChild(name); return v and v.Value or "" end
local Browser={}; Browser.__index=Browser
local function clear(parent) for _,o in ipairs(parent:GetChildren()) do if o:GetAttribute("GeneratedGarageUI") then o:Destroy() end end end
local function generated(o) o:SetAttribute("GeneratedGarageUI",true); return o end
local function cockpitFor(category,id) for _,c in ipairs((category and category.Cockpits) or {}) do if tostring(c.CockpitId)==tostring(id) then return c end end end
local function cockpitId(profile,vehicle) local i=vehicle and vehicle.CockpitInstanceId and profile and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; return i and tostring(i.TemplateId or "") or "" end
function Browser.new(gui,legacyScale)
	local self=setmetatable({},Browser); self.Gui=gui; self.LegacyScale=legacyScale; self.Legacy={}; self.Context=nil
	self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageBrowser"; self.Root.BackgroundTransparency=1; self.Root.BorderSizePixel=0; self.Root.Visible=false; self.Root.Parent=gui
	self.Scale=Instance.new("UIScale"); self.Scale.Name="CanonicalScale"; self.Scale.Parent=self.Root
	self.Header=Shared.MetricCard(self.Root,"Header"); self.Title=Racing.Label(self.Header,{Text="DEALERSHIP",Position=UDim2.fromOffset(12,3),Size=UDim2.new(1,-24,0,28),TextSize=RN("MetricHeadingSize",15)+2,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"}); self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,29),TextSize=12,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Metric"})
	self.Categories=Shared.Panel(self.Root,"Categories",{NoStroke=true}); self.CategoryList=Instance.new("ScrollingFrame"); self.CategoryList.BackgroundTransparency=1; self.CategoryList.BorderSizePixel=0; self.CategoryList.ScrollBarThickness=0; self.CategoryList.AutomaticCanvasSize=Enum.AutomaticSize.Y; self.CategoryList.CanvasSize=UDim2.fromOffset(0,0); self.CategoryList.Position=UDim2.fromOffset(7,7); self.CategoryList.Size=UDim2.new(1,-14,1,-14); self.CategoryList.Parent=self.Categories; local catLayout=Instance.new("UIListLayout"); catLayout.Padding=UDim.new(0,8); catLayout.Parent=self.CategoryList; local catPad=Instance.new("UIPadding"); catPad.PaddingTop=UDim.new(0,6); catPad.PaddingBottom=UDim.new(0,6); catPad.PaddingLeft=UDim.new(0,6); catPad.PaddingRight=UDim.new(0,6); catPad.Parent=self.CategoryList
	self.Right=Instance.new("Frame"); self.Right.BackgroundTransparency=1; self.Right.AutomaticSize=Enum.AutomaticSize.Y; self.Right.Parent=self.Root
	self.Stats=Shared.Panel(self.Right,"Stats",{NoStroke=true}); self.Stats.AutomaticSize=Enum.AutomaticSize.Y; self.Stats.Size=UDim2.new(1,0,0,0); local statsPad=Instance.new("UIPadding"); statsPad.PaddingTop=UDim.new(0,10); statsPad.PaddingBottom=UDim.new(0,10); statsPad.PaddingLeft=UDim.new(0,12); statsPad.PaddingRight=UDim.new(0,12); statsPad.Parent=self.Stats; local statsLayout=Instance.new("UIListLayout"); statsLayout.Padding=UDim.new(0,5); statsLayout.SortOrder=Enum.SortOrder.LayoutOrder; statsLayout.Parent=self.Stats
	self.Economy=Instance.new("Frame"); self.Economy.BackgroundTransparency=1; self.Economy.Size=UDim2.new(1,0,0,N("EconomyHeight",46)); self.Economy.Parent=self.Right
	local economyOutline=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)); self.Cash=Shared.Panel(self.Economy,"Cash",{StrokeColor=economyOutline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true}); self.Capacity=Shared.Panel(self.Economy,"Capacity",{StrokeColor=economyOutline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true})
	self.Carousel=Instance.new("Frame"); self.Carousel.BackgroundTransparency=1; self.Carousel.Parent=self.Root
	self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.Name="VehicleScroller"; self.Scroller.BackgroundTransparency=1; self.Scroller.BorderSizePixel=0; self.Scroller.ScrollBarThickness=0; self.Scroller.CanvasSize=UDim2.fromOffset(0,0); self.Scroller.ScrollingDirection=Enum.ScrollingDirection.X; self.Scroller.ClipsDescendants=true; self.Scroller.Parent=self.Carousel; self.CarLayout=Instance.new("UIListLayout"); self.CarLayout.FillDirection=Enum.FillDirection.Horizontal; self.CarLayout.VerticalAlignment=Enum.VerticalAlignment.Center; self.CarLayout.Padding=UDim.new(0,12); self.CarLayout.Parent=self.Scroller; self.CarPad=Instance.new("UIPadding"); self.CarPad.PaddingLeft=UDim.new(0,6); self.CarPad.PaddingRight=UDim.new(0,6); self.CarPad.Parent=self.Scroller
	local function arrow(name,text) local b=Instance.new("TextButton"); b.Name=name; b.Text=text; b.AutoButtonColor=false; b.BackgroundColor3=Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)); b.BackgroundTransparency=.3; b.BorderSizePixel=0; b.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); b.TextSize=30; b.ZIndex=20; Racing.Font(b,"Heading"); Racing.Corner(b,5); b.Parent=self.Root; return b end
	self.Left=arrow("Previous","<"); self.RightArrow=arrow("Next",">")
	self.Exit=Racing.Button(self.Root,{Name="Exit",Text="EXIT",Size=UDim2.fromOffset(88,30),Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})
	self.Popup=Shared.Popup(self.Root)
	self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end); self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end); self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:UpdateCarousel() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)
	local camera=Workspace.CurrentCamera; if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if self.Root.Visible then self:Layout() end end) end
	return self
end
function Browser:Layout()
	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); local scale=math.clamp(math.min(viewport.X/N("BaseWidth",1600),viewport.Y/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); self.Scale.Scale=scale; local vw,vh=viewport.X/scale,viewport.Y/scale; self.Root.Size=UDim2.fromOffset(vw,vh)
	local margin,gap=N("Margin",18),N("Gap",14); local carouselH=N("CarouselHeight",166); local carouselTop=vh-margin-carouselH; local arrowW=N("ArrowWidth",42); local railReserve=30
	self.LayoutScale=scale; self.ReferenceWidth=vw
	self.Header.AnchorPoint=Vector2.new(.5,0); self.Header.Position=UDim2.fromOffset(vw*.5,28); self.Header.Size=UDim2.fromOffset(420,62)
	self.Categories.Position=UDim2.fromOffset(margin,72); self.Categories.Size=UDim2.fromOffset(N("CategoryWidth",214),math.max(170,carouselTop-72-N("CategoryCarouselClearance",82)))
	self.Right.AnchorPoint=Vector2.new(1,0); self.Right.Position=UDim2.fromOffset(vw-margin,28); self.Right.Size=UDim2.fromOffset(N("StatsWidth",354),0); self.Stats.LayoutOrder=1; self.Economy.LayoutOrder=2; self.Economy.Size=UDim2.new(1,0,0,N("EconomyHeight",46)); local rl=self.Right:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout"); rl.Padding=UDim.new(0,gap); rl.SortOrder=Enum.SortOrder.LayoutOrder; rl.Parent=self.Right
	local chipGap=gap; self.Cash.Position=UDim2.fromOffset(0,0); self.Cash.Size=UDim2.new(.5,-chipGap*.5,1,0); self.Capacity.AnchorPoint=Vector2.new(1,0); self.Capacity.Position=UDim2.fromScale(1,0); self.Capacity.Size=UDim2.new(.5,-chipGap*.5,1,0)
	self.Carousel.Position=UDim2.fromOffset(margin+railReserve+gap,carouselTop); self.Carousel.Size=UDim2.fromOffset(vw-2*(margin+railReserve+gap),carouselH); self.Scroller.Size=UDim2.fromScale(1,1); self.ReferenceCarouselWidth=vw-2*(margin+railReserve+gap)
	self.Left.AnchorPoint=Vector2.new(0,.5); self.Left.Position=UDim2.fromOffset(margin,carouselTop+carouselH*.5); self.Left.Size=UDim2.fromOffset(arrowW,N("ArrowHeight",72)); self.RightArrow.AnchorPoint=Vector2.new(1,.5); self.RightArrow.Position=UDim2.fromOffset(vw-margin,carouselTop+carouselH*.5); self.RightArrow.Size=UDim2.fromOffset(arrowW,N("ArrowHeight",72))
	self.Exit.AnchorPoint=Vector2.new(1,1); self.Exit.Position=UDim2.fromOffset(vw-margin,carouselTop-gap)
	self:QueueCarouselUpdate()
end
function Browser:QueueCarouselUpdate()
	if self.CarouselUpdateQueued then return end; self.CarouselUpdateQueued=true; task.defer(function() RunService.Heartbeat:Wait(); self.CarouselUpdateQueued=false; if self.Root.Visible then self:UpdateCarousel() end end)
end
function Browser:UpdateCarousel()
	if not self.Scroller or self.UpdatingCarousel then return end; self.UpdatingCarousel=true; local count=0; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then count+=1 end end; local content=count*N("CardWidth",226)+math.max(0,count-1)*12; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local window=self.ReferenceCarouselWidth or (self.Scroller.AbsoluteSize.X/scale); if self.Scroller.AbsoluteSize.X>0 then window=self.Scroller.AbsoluteSize.X/scale end; local side=math.max(6,(window-content)*.5); if content>=window then side=6 end; self.CarPad.PaddingLeft=UDim.new(0,side); self.CarPad.PaddingRight=UDim.new(0,side); local canvas=math.max(window,content+side*2); self.Scroller.CanvasSize=UDim2.fromOffset(canvas,0); local max=math.max(0,canvas-window); self.MaxScroll=max; if max<=1 then self.Scroller.CanvasPosition=Vector2.zero end; local x=self.Scroller.CanvasPosition.X; self.Left.Visible=max>1 and x>1; self.RightArrow.Visible=max>1 and x<max-1; self.UpdatingCarousel=false
end
function Browser:Scroll(direction) local max=self.MaxScroll or 0; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*(N("CardWidth",226)+12),0,max),0); self:UpdateCarousel() end
function Browser:Rows(context)
	local rows={}; local profile=context.State.Profile or {}; local category=context.Category
	if context.Mode=="Customisation" then
		for vehicleId,vehicle in pairs(profile.Vehicles or {}) do local id=cockpitId(profile,vehicle); local cockpit=cockpitFor(category,id); if cockpit then local summary=(profile.VehicleSummaries and profile.VehicleSummaries[vehicleId]) or {}; local performance=summary; if not summary.Headline then local fallback=context.ResolvePerformance(cockpit); performance={Overall=summary.Overall or fallback.Overall,Headline=fallback.Headline} end; table.insert(rows,{VehicleId=vehicleId,CockpitId=id,Cockpit=cockpit,Performance=performance,CategoryId=cockpit.NTRCategoryId or context.State.CategoryId}) end end
	else
		for _,cockpit in ipairs((category and category.Cockpits) or {}) do table.insert(rows,{CockpitId=cockpit.CockpitId,Cockpit=cockpit,Performance=context.ResolvePerformance(cockpit),CategoryId=cockpit.NTRCategoryId or context.State.CategoryId}) end
	end
	table.sort(rows,function(a,b) local av=tonumber(a.Performance and a.Performance.Overall and a.Performance.Overall.PerformanceIndex) or math.huge; local bv=tonumber(b.Performance and b.Performance.Overall and b.Performance.Overall.PerformanceIndex) or math.huge; if av~=bv then return av<bv end; return tostring(a.Cockpit.DisplayName or a.CockpitId)<tostring(b.Cockpit.DisplayName or b.CockpitId) end); return rows
end
function Browser:RenderStats(row)
	clear(self.Stats); if not row then generated(Racing.Label(self.Stats,{Text="NO VEHICLES AVAILABLE",Size=UDim2.new(1,0,0,42),TextSize=10,XAlignment=Enum.TextXAlignment.Center})); return end
	local overall=row.Performance and row.Performance.Overall or {}; local tier=tostring(overall.Tier or "E"); local index=math.floor(tonumber(overall.PerformanceIndex) or 100); local header=generated(Instance.new("Frame")); header.Name="Rating"; header.LayoutOrder=1; header.BackgroundColor3=self.Context.TierColor(tier); header.BorderSizePixel=0; header.Size=UDim2.new(1,0,0,42); header.Parent=self.Stats; Racing.Corner(header,4); Racing.Label(header,{Text=tier.."  "..index,Position=UDim2.fromOffset(8,0),Size=UDim2.new(.5,-8,1,0),TextSize=19,Role="Metric"}); Racing.Label(header,{Text="PERFORMANCE",Position=UDim2.fromScale(.5,0),Size=UDim2.new(.5,-8,1,0),TextSize=9,XAlignment=Enum.TextXAlignment.Right,Role="Heading"})
	for order,name in ipairs({"Speed","Acceleration","Handling","Drift","Braking","Boost"}) do local value=tonumber(row.Performance and row.Performance.Headline and row.Performance.Headline[name]) or 0; local stat=generated(Instance.new("Frame")); stat.Name=name; stat.LayoutOrder=order+1; stat.BackgroundTransparency=1; stat.Size=UDim2.new(1,0,0,36); stat.Parent=self.Stats; Racing.Label(stat,{Text=string.upper(name),Size=UDim2.new(.55,0,0,16),TextSize=9,Role="Heading"}); Racing.Label(stat,{Text=tostring(math.floor(value+.5)),Position=UDim2.new(.55,0,0,0),Size=UDim2.new(.25,0,0,16),TextSize=10,XAlignment=Enum.TextXAlignment.Right,Role="Metric"}); Racing.Label(stat,{Text="-",Position=UDim2.new(.82,0,0,0),Size=UDim2.new(.18,0,0,16),TextSize=10,XAlignment=Enum.TextXAlignment.Right}); local track=Instance.new("Frame"); track.BackgroundColor3=Racing.Colour("PanelSoft"); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(0,20); track.Size=UDim2.new(1,0,0,9); track.Parent=stat; Racing.Corner(track,5); local fill=Instance.new("Frame"); fill.BackgroundColor3=Racing.Colour("Telemetry"); fill.BorderSizePixel=0; fill.Size=UDim2.fromScale(math.clamp(value/N("StatReference",180),0,1),1); fill.Parent=track; Racing.Corner(fill,5); local g=Instance.new("UIGradient"); g.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry")); g.Parent=fill end
end
function Browser:RenderEconomy(context)
	for _,p in ipairs({self.Cash,self.Capacity}) do for _,o in ipairs(p:GetChildren()) do if o:GetAttribute("GeneratedGarageUI") then o:Destroy() end end end
	local cash=generated(Racing.Label(self.Cash,{Text="$"..tostring(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=15,Color=Color3.fromRGB(89,255,102)})); cash.Name="CashValue"; local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if typeof(context.OnCash)=="function" then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity; generated(Racing.Label(self.Capacity,{Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=11})); local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if typeof(context.OnCapacity)=="function" then context.OnCapacity() end end)
end
function Browser:Audit(selectedCard)
	task.defer(function()
		RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:Layout(); RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:UpdateCarousel()
		local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.zero; local key=tostring(math.floor(viewport.X)).."x"..tostring(math.floor(viewport.Y))..":"..tostring(self.Context and self.Context.Mode)
		if self.LastAuditKey==key then return end; self.LastAuditKey=key
		local failures={}; local function expect(ok,message) if not ok then table.insert(failures,message) end end
		local roots=0; for _,child in ipairs(self.Gui:GetChildren()) do if child.Name=="CanonicalGarageBrowser" then roots+=1 end end; expect(roots==1,"expected one canonical browser root")
		for legacy in pairs(self.Legacy) do expect(not legacy.Visible,"legacy browser surface remained visible: "..legacy.Name) end
		expect(self.Categories.AbsolutePosition.Y+self.Categories.AbsoluteSize.Y<=self.Carousel.AbsolutePosition.Y-8,"categories overlap carousel")
		expect(self.Exit.AbsolutePosition.Y+self.Exit.AbsoluteSize.Y<=self.Carousel.AbsolutePosition.Y-6,"exit overlaps carousel")
		local combined=self.Cash.AbsoluteSize.X+self.Capacity.AbsoluteSize.X+N("Gap",14); expect(math.abs(combined-self.Stats.AbsoluteSize.X)<=3,"cash/capacity width does not match stats")
		local lowest=self.Stats.AbsolutePosition.Y; for _,child in ipairs(self.Stats:GetChildren()) do if child:GetAttribute("GeneratedGarageUI") then lowest=math.max(lowest,child.AbsolutePosition.Y+child.AbsoluteSize.Y) end end; expect(lowest<=self.Stats.AbsolutePosition.Y+self.Stats.AbsoluteSize.Y+3,"stats content exceeds fitted panel")
		local maxScroll=self.MaxScroll or 0; local scrollX=self.Scroller.CanvasPosition.X; expect(self.Left.Visible==(maxScroll>1 and scrollX>1),"left arrow visibility does not match overflow"); expect(self.RightArrow.Visible==(maxScroll>1 and scrollX<maxScroll-1),"right arrow visibility does not match overflow")
		if maxScroll<=1 then local first,last; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then if not first or child.AbsolutePosition.X<first.AbsolutePosition.X then first=child end; if not last or child.AbsolutePosition.X>last.AbsolutePosition.X then last=child end end end; if first and last then local cardsCenter=(first.AbsolutePosition.X+last.AbsolutePosition.X+last.AbsoluteSize.X)*.5; local screenCenter=self.Root.AbsolutePosition.X+self.Root.AbsoluteSize.X*.5; expect(math.abs(cardsCenter-screenCenter)<=3,"non-overflowing cards are not screen-centred") end end
		if self.Popup.Shell.Visible and selectedCard and selectedCard.Parent then local popupCenter=self.Popup.Shell.AbsolutePosition.X+self.Popup.Shell.AbsoluteSize.X*.5; local cardCenter=selectedCard.AbsolutePosition.X+selectedCard.AbsoluteSize.X*.5; expect(math.abs(popupCenter-cardCenter)<=3,"action popup is not card-centred") end
		if #failures==0 then print("[NTR Garage Replacement Runtime] GEOMETRY PASS "..key) else warn("[NTR Garage Replacement Runtime] GEOMETRY FAIL: "..table.concat(failures," | ")) end
	end)
end
function Browser:Show(context)
	self.Context=context; if not self.Root.Visible then self.Legacy={}; for _,o in ipairs(context.Legacy or {}) do if o then self.Legacy[o]=o.Visible; o.Visible=false end end; if self.LegacyScale then self.OldScale=self.LegacyScale.Scale; self.LegacyScale.Scale=1 end end; self.Root.Visible=true; self:Layout(); self.Title.Text=string.upper(context.Mode=="Customisation" and "CUSTOMISATION" or "DEALERSHIP"); self.Subtitle.Text=context.Mode=="Customisation" and "Choose one of your owned cockpits to customise." or "Choose a vehicle category, then pick a cockpit."
	clear(self.CategoryList); local buttonH=N("CategoryButtonHeight",46); local all=generated(Racing.Button(self.CategoryList,{Text="ALL",Size=UDim2.new(1,0,0,buttonH),Color=context.State.BrowseAll and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); all.Activated:Connect(function() context.OnCategory(nil,true) end); local categories={}; for _,c in ipairs((context.State.Catalog and context.State.Catalog.Categories) or {}) do table.insert(categories,c) end; table.sort(categories,function(a,b) return tostring(a.DisplayName or a.CategoryId)<tostring(b.DisplayName or b.CategoryId) end); for _,c in ipairs(categories) do local button=generated(Racing.Button(self.CategoryList,{Text=c.DisplayName or c.CategoryId,Size=UDim2.new(1,0,0,buttonH),Color=not context.State.BrowseAll and c.CategoryId==context.State.CategoryId and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); button.Activated:Connect(function() context.OnCategory(c.CategoryId,false) end) end
	local rows=self:Rows(context); local selected
	for _,row in ipairs(rows) do if (row.VehicleId and row.VehicleId==context.State.SelectedVehicleId) or (not row.VehicleId and row.CockpitId==context.State.SelectedCockpit) then selected=row end end
	if (context.AutoPreview or not selected) and rows[1] then task.defer(function() if self.Root.Visible and self.Context==context then context.OnSelect(rows[1]) end end); return end
	clear(self.Scroller); local selectedCard
	for _,row in ipairs(rows) do local overall=row.Performance and row.Performance.Overall or {}; local isSelected=row==selected; local card=generated(Shared.Card(self.Scroller,{DisplayName=row.Cockpit.DisplayName or row.CockpitId,Image=context.ResolveImage(row.Cockpit),Rating=tostring(overall.Tier or "E").." "..tostring(math.floor(tonumber(overall.PerformanceIndex) or 100)),RatingColor=context.TierColor(tostring(overall.Tier or "E")),Selected=isSelected,Size=UDim2.fromOffset(N("CardWidth",226),N("CardHeight",146)),ImageHeight=N("CardImageHeight",136)})); card.Activated:Connect(function() context.OnSelect(row) end); if isSelected then selectedCard=card end end
	self:RenderStats(selected); self:RenderEconomy(context); task.defer(function() self:Layout(); self:QueueCarouselUpdate() end)
	if selectedCard and selected then local owned=context.OwnedCount(selected.CockpitId)>0; local text=context.Mode=="Customisation" and "CUSTOMISE" or ((owned and "BUY ANOTHER $" or "BUY $")..tostring(selected.Cockpit.Price or 0)); self.Popup:Set(selectedCard,text,function() context.OnPrimary(selected) end,self.Scale) else self.Popup:Hide() end
	self:Audit(selectedCard)
end
function Browser:Hide() self.Root.Visible=false; self.Popup:Hide(); for o,v in pairs(self.Legacy) do if o.Parent then o.Visible=v end end; self.Legacy={}; if self.LegacyScale and self.OldScale then self.LegacyScale.Scale=self.OldScale end end
return Browser
]==]

local function compile(name, source)
	if typeof(loadstring) == "function" then local fn, err = loadstring(source); assert(fn, name .. " compile failed: " .. tostring(err)) end
end
compile("GarageReplacementComponents", componentsSource)
compile("GarageBrowserController", browserSource)
assert(not string.find(browserSource, "UDim2.zero", 1, true), "Invalid UDim2.zero remained in browser source")
if MODE == "AUDIT" then print("[NTR Garage Replacement] AUDIT PASS"); return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local serverSource = garageServer.Source
if not string.find(serverSource, "NTR_GARAGE_REPLACEMENT_HEADLINE_SUMMARY_V1", 1, true) then
	serverSource = replaceOnce(serverSource,
		[[						Overall = performance and performance.Overall or nil,]],
		[[						Overall = performance and performance.Overall or nil,
						-- NTR_GARAGE_REPLACEMENT_HEADLINE_SUMMARY_V1
						Headline = performance and performance.Headline or nil,]], "Owned vehicle headline summary")
end
compile("GarageActionController headline summary", serverSource)
garageServer.Source = serverSource

local components = ensure(uiControllers, "ModuleScript", "GarageReplacementComponents")
components.Source = componentsSource
local browser = ensure(uiControllers, "ModuleScript", "GarageBrowserController")
browser.Source = browserSource
local oldPresentation = uiControllers:FindFirstChild("GarageExperienceController_Active")
if oldPresentation and oldPresentation:IsA("LocalScript") then oldPresentation.Disabled = true; oldPresentation:SetAttribute("SupersededBy", "NTR_GARAGE_REPLACEMENT_BROWSER_V1_4") end

local source = bootstrap.Source
if not string.find(source, "NTR_GARAGE_REPLACEMENT_BROWSER_BRIDGE_V1", 1, true) then
	local startAt = assert(string.find(source, "renderCockpitShop = function()", 1, true))
	local endAt = assert(string.find(source, "local function channelTitle(channel)", startAt, true))
	local replacement = [[renderCockpitShop = function()
	-- NTR_GARAGE_REPLACEMENT_BROWSER_BRIDGE_V1
	if not UI.CanonicalGarageBrowser then
		UI.CanonicalGarageBrowser = require(script.Parent:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GarageBrowserController")).new(UI.Gui, UI.Scale)
	end
	local customisationMode = State.ShopMode == "Customisation"
	local category = getCategory()
	local ownedCount, capacity = NTR_phase8GarageCapacitySummary()
	UI.CanonicalGarageBrowser:Show({
		Mode = customisationMode and "Customisation" or "Dealership", State = State, Category = category,
		Cash = State.Profile and State.Profile.Cash or 0, CapacityText = tostring(ownedCount) .. "/" .. tostring(capacity) .. " Spaces", AutoPreview = State.NoPreviewYet == true,
		Legacy = { UI.Top, UI.CashPanel, UI.GarageCapacityPanel, UI.StatsPanel, UI.CockpitShop, UI.DealershipExitPanel, UI.NextPanel },
		ResolveImage = function(cockpit) return NTR_phase5CockpitMenuImage(cockpit) end,
		ResolvePerformance = function(cockpit) local _, calculator = NTRVehiclePhaseAO.performanceModules(); return calculator.CalculateLegacy(NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit)) end,
		TierColor = function(tier) return NTRVehiclePhaseAO.tierColor(tier) end,
		OwnedCount = function(cockpitId) local count = 0; for _, vehicle in pairs((State.Profile and State.Profile.Vehicles) or {}) do local instance = vehicle.CockpitInstanceId and State.Profile.OwnedCockpitInstances and State.Profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; if instance and tostring(instance.TemplateId) == tostring(cockpitId) then count += 1 end end; return count end,
		OnCategory = function(categoryId, browseAll) State.BrowseAll = browseAll == true; if categoryId then State.CategoryId = categoryId end; State.SelectedVehicleId = nil; State.NoPreviewYet = true; renderCockpitShop() end,
		OnSelect = function(row) State.SelectedCockpit = row.CockpitId; State.SelectedVehicleId = row.VehicleId; if row.CategoryId then State.CategoryId = row.CategoryId end; State.NoPreviewYet = false; State.GarageCameraActive = true; State.Phase5PreviewOrbitInitialized = false; buildPreview(); NTR_phase4ApplyGaragePreviewCamera(); renderCockpitShop() end,
		OnPrimary = function(row)
			if customisationMode then
				local result = callServer("SelectVehicleInstance", { VehicleId = row.VehicleId, CockpitId = row.CockpitId })
				if not result.Success then UI.CanonicalGarageBrowser.Subtitle.Text = result.Message or "Could not customise vehicle."; return end
			else
				local result = callServer("BuyCockpitInstance", { CockpitId = row.CockpitId, CategoryId = row.CategoryId or State.CategoryId })
				if not result.Success then UI.CanonicalGarageBrowser.Subtitle.Text = result.Message or "Could not buy cockpit."; return end
			end
			NTR_phase4UnlockPreviewAfterPurchase(); UI.CanonicalGarageBrowser:Hide(); State.ModuleMode = "Slots"; State.SelectedModuleId = nil; State.SelectedModuleInstanceId = nil; State.CustomizeTarget = "ALL"; State.CustomizeMode = "Colour"; local firstSlot = sortedSlots()[1]; State.SelectedSlot = firstSlot and firstSlot.SlotId or "Engine1"; setCameraSection(State.SelectedSlot); showStage("CockpitPaint"); renderCockpitPaint()
		end,
		OnExit = function() UI.CanonicalGarageBrowser:Hide(); closeGarage(); NTR_phase7SignalDealershipExit() end,
		OnCash = function() showCashShop() end, OnCapacity = function() NTRPersistencePhase9.OpenGaragePropertyShop() end,
	})
end

]]
	source = string.sub(source, 1, startAt - 1) .. replacement .. string.sub(source, endAt)
	source = replaceOnce(source,
		[[	State.Stage = stage
	UI.CockpitShop.Visible = stage == "CockpitShop"]],
		[[	State.Stage = stage
	if UI.CanonicalGarageBrowser and stage ~= "CockpitShop" then UI.CanonicalGarageBrowser:Hide() end
	UI.CockpitShop.Visible = stage == "CockpitShop"]], "Page-router hide bridge")
end
local unsafeExitConnection = [[	UI.CanonicalGarageExit = function()
		if UI.CanonicalGarageBrowser then UI.CanonicalGarageBrowser:Hide() end
		closeGarage()
		NTR_phase7SignalDealershipExit()
	end
	UI.DealershipExitButton.MouseButton1Click:Connect(UI.CanonicalGarageExit)]]
local safeExitConnection = [[	UI.CanonicalGarageExit = function()
		if UI.CanonicalGarageBrowser then UI.CanonicalGarageBrowser:Hide() end
		closeGarage()
		NTR_phase7SignalDealershipExit()
	end
	UI.DealershipExitButton.MouseButton1Click:Connect(function()
		UI.CanonicalGarageExit()
	end)]]
local originalExitConnection = [[	UI.DealershipExitButton.MouseButton1Click:Connect(function()
		closeGarage()
		NTR_phase7SignalDealershipExit()
	end)]]
if countPlain(source, unsafeExitConnection) == 1 then
	source = replaceOnce(source, unsafeExitConnection, originalExitConnection, "V1 unsafe exit connection removal")
elseif countPlain(source, safeExitConnection) == 1 then
	source = replaceOnce(source, safeExitConnection, originalExitConnection, "V1 safe exit bridge removal")
end
assert(countPlain(source, originalExitConnection) == 1, "Original proven exit connection missing")
assert(not string.find(source, "Connect(UI.CanonicalGarageExit)", 1, true), "Unsafe canonical Exit connection remained")
compile("PatchedBootstrap", source)
bootstrap.Source = source
bootstrap:SetAttribute("CanonicalGarageReplacement", "NTR_GARAGE_REPLACEMENT_BROWSER_V1_4")

assert(string.find(bootstrap.Source, "NTR_GARAGE_REPLACEMENT_BROWSER_BRIDGE_V1", 1, true), "Replacement browser bridge missing")
assert(components.Parent == uiControllers and browser.Parent == uiControllers, "Replacement modules missing")
assert(not oldPresentation or oldPresentation.Disabled == true, "Legacy presentation still enabled")
assert(string.find(garageServer.Source, "NTR_GARAGE_REPLACEMENT_HEADLINE_SUMMARY_V1", 1, true), "Owned headline summary missing")
print("[NTR Garage Replacement] INSTALL PASS")
print("[NTR Garage Replacement] Restart Play; verify one browser root, no visible legacy browser, card-centred actions, preview, purchase/customise, Exit, and PC/mobile scaling.")
