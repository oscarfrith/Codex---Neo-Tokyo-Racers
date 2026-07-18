-- NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1
-- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
-- NTR_GARAGE_FLOW_REFINEMENT_V2
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- NTR_GARAGE_REPLACEMENT_BROWSER_CONTROLLER_V1
-- NTR_GARAGE_BROWSER_INDEPENDENT_HOST_V1
-- NTR_GARAGE_PRESENTATION_OWNER_BROWSER_V1
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
local navigationIcons=cfg:FindFirstChild("NavigationIcons")
local function navIcon(name) return tostring(navigationIcons and navigationIcons:GetAttribute(name) or "") end -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
local Browser={}; Browser.__index=Browser
local headerTitleSize,headerSubtitleSize=Shared.HeaderTextSizes() -- NTR_GARAGE_FLOW_REFINEMENT_V2
local function clear(parent) for _,o in ipairs(parent:GetChildren()) do if o:GetAttribute("GeneratedGarageUI") then o:Destroy() end end end
local function generated(o) o:SetAttribute("GeneratedGarageUI",true); return o end
local function cockpitFor(category,id) for _,c in ipairs((category and category.Cockpits) or {}) do if tostring(c.CockpitId)==tostring(id) then return c end end end
local function cockpitId(profile,vehicle) local i=vehicle and vehicle.CockpitInstanceId and profile and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; return i and tostring(i.TemplateId or "") or "" end
function Browser.new()
	local self=setmetatable({},Browser); self.Host=Shared.CanonicalHost(); self.Gui=self.Host.Gui; self.Scale=self.Host.Scale; self.Context=nil
	self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageBrowser"; self.Root.BackgroundTransparency=1; self.Root.BorderSizePixel=0; self.Root.Visible=false; self.Root.Parent=self.Host.Canvas
	self.Header=Shared.MetricCard(self.Root,"Header"); self.Title=Racing.Label(self.Header,{Text="DEALERSHIP",Position=UDim2.fromOffset(12,3),Size=UDim2.new(1,-24,0,28),TextSize=headerTitleSize,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"}); self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,29),TextSize=headerSubtitleSize,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"})
	self.Categories=Shared.Panel(self.Root,"Categories",{NoStroke=true}); self.CategoryList=Instance.new("ScrollingFrame"); self.CategoryList.BackgroundTransparency=1; self.CategoryList.BorderSizePixel=0; self.CategoryList.ScrollBarThickness=0; self.CategoryList.AutomaticCanvasSize=Enum.AutomaticSize.Y; self.CategoryList.CanvasSize=UDim2.fromOffset(0,0); self.CategoryList.Position=UDim2.fromOffset(7,7); self.CategoryList.Size=UDim2.new(1,-14,1,-14); self.CategoryList.Parent=self.Categories; local catLayout=Instance.new("UIListLayout"); catLayout.Padding=UDim.new(0,8); catLayout.Parent=self.CategoryList; local catPad=Instance.new("UIPadding"); catPad.PaddingTop=UDim.new(0,6); catPad.PaddingBottom=UDim.new(0,6); catPad.PaddingLeft=UDim.new(0,6); catPad.PaddingRight=UDim.new(0,6); catPad.Parent=self.CategoryList
	self.Right=Instance.new("Frame"); self.Right.BackgroundTransparency=1; self.Right.AutomaticSize=Enum.AutomaticSize.Y; self.Right.Parent=self.Root
	self.Stats=Shared.Panel(self.Right,"Stats",{NoStroke=true}); self.Stats.AutomaticSize=Enum.AutomaticSize.Y; self.Stats.Size=UDim2.new(1,0,0,0); local statsPad=Instance.new("UIPadding"); statsPad.PaddingTop=UDim.new(0,10); statsPad.PaddingBottom=UDim.new(0,10); statsPad.PaddingLeft=UDim.new(0,12); statsPad.PaddingRight=UDim.new(0,12); statsPad.Parent=self.Stats; local statsLayout=Instance.new("UIListLayout"); statsLayout.Padding=UDim.new(0,5); statsLayout.SortOrder=Enum.SortOrder.LayoutOrder; statsLayout.Parent=self.Stats
	self.Economy=Instance.new("Frame"); self.Economy.BackgroundTransparency=1; self.Economy.Size=UDim2.new(1,0,0,N("EconomyHeight",46)); self.Economy.Parent=self.Right
	local economyOutline=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)); self.Cash=Shared.Panel(self.Economy,"Cash",{StrokeColor=economyOutline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true}); self.Capacity=Shared.Panel(self.Economy,"Capacity",{StrokeColor=economyOutline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true})
	self.Carousel=Instance.new("Frame"); self.Carousel.BackgroundTransparency=1; self.Carousel.Parent=self.Root
	self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.Name="VehicleScroller"; self.Scroller.BackgroundTransparency=1; self.Scroller.BorderSizePixel=0; self.Scroller.ScrollBarThickness=0; self.Scroller.CanvasSize=UDim2.fromOffset(0,0); self.Scroller.ScrollingDirection=Enum.ScrollingDirection.X; self.Scroller.ClipsDescendants=true; self.Scroller.Parent=self.Carousel; self.CarLayout=Instance.new("UIListLayout"); self.CarLayout.FillDirection=Enum.FillDirection.Horizontal; self.CarLayout.VerticalAlignment=Enum.VerticalAlignment.Center; self.CarLayout.Padding=UDim.new(0,12); self.CarLayout.Parent=self.Scroller; self.CarPad=Instance.new("UIPadding"); self.CarPad.PaddingLeft=UDim.new(0,6); self.CarPad.PaddingRight=UDim.new(0,6); self.CarPad.Parent=self.Scroller
	local function arrow(name,text) local b=Instance.new("TextButton"); b.Name=name; b.Text=text; b.AutoButtonColor=false; b.BackgroundColor3=Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)); b.BackgroundTransparency=.3; b.BorderSizePixel=0; b.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); b.TextSize=30; b.ZIndex=20; Racing.Font(b,"Heading"); Racing.Corner(b,5); b.Parent=self.Root; return b end
	self.Left=arrow("Previous","<"); self.RightArrow=arrow("Next",">")
	self.Exit=Shared.ActionButton(self.Root,{Name="Exit",Text="EXIT",Icon=navIcon("ExitIcon"),IconText="X",Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})
	self.Popup=Shared.Popup(self.Root)
	self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end); self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end); self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)
	local camera=Workspace.CurrentCamera; if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if self.Root.Visible then self:Layout() end end) end
	return self
end
function Browser:Layout()
	-- NTR_GARAGE_BROWSER_SHARED_SHELL_V2
	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); Shared.LayoutGarageShell(self,{Number=N,Viewport=viewport,MinimumScale=minimum,Actions={self.Exit}})
	self:QueueCarouselUpdate()
end
function Browser:QueueCarouselUpdate()
	if self.CarouselUpdateQueued then return end; self.CarouselUpdateQueued=true; task.defer(function() RunService.Heartbeat:Wait(); self.CarouselUpdateQueued=false; if self.Root.Visible then self:UpdateCarousel() end end)
end
function Browser:RefreshCarouselArrows()
	local maximum=math.max(0,self.Scroller.AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X); local x=self.Scroller.CanvasPosition.X; local tolerance=math.max(2,N("CarouselEndTolerance",4)); self.MaxScroll=maximum
	self.Left.Visible=maximum>tolerance and x>tolerance; self.RightArrow.Visible=maximum>tolerance and x<maximum-tolerance
end
function Browser:UpdateCarousel()
	if not self.Scroller or self.UpdatingCarousel then return end
	self.UpdatingCarousel=true; local count=0; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then count+=1 end end
	local content=count*N("CardWidth",226)+math.max(0,count-1)*12; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local window=self.ReferenceCarouselWidth or self.Scroller.AbsoluteSize.X/scale; if self.Scroller.AbsoluteSize.X>0 then window=self.Scroller.AbsoluteSize.X/scale end
	local side=content<window and math.max(6,(window-content)*.5) or 6; self.CarPad.PaddingLeft=UDim.new(0,side); self.CarPad.PaddingRight=UDim.new(0,side); self.Scroller.CanvasSize=UDim2.fromOffset(math.max(window,content+side*2),0); self.UpdatingCarousel=false; self:RefreshCarouselArrows()
end
function Browser:Scroll(direction) local max=self.MaxScroll or 0; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local step=(N("CardWidth",226)+12)*scale; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*step,0,max),0); self:RefreshCarouselArrows() end
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
	-- NTR_GARAGE_BROWSER_SHARED_PERFORMANCE_V2
	Shared.RenderPerformance(self.Stats,{Performance=row and row.Performance or nil,TierColor=self.Context and self.Context.TierColor,Reference=N("StatReference",180),GeneratedAttribute="GeneratedGarageUI",EmptyText="NO VEHICLES AVAILABLE"})
end
function Browser:RenderEconomy(context)
	for _,p in ipairs({self.Cash,self.Capacity}) do for _,o in ipairs(p:GetChildren()) do if o:GetAttribute("GeneratedGarageUI") then o:Destroy() end end end
	local cash=generated(Racing.Label(self.Cash,{Text=Shared.FormatMoney(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=15,Color=Color3.fromRGB(89,255,102)})); cash.Name="CashValue"; local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if typeof(context.OnCash)=="function" then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity; generated(Racing.Label(self.Capacity,{Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=11})); local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if typeof(context.OnCapacity)=="function" then context.OnCapacity() end end)
end

function Browser:Audit(selectedCard)
	Shared.AuditPresentation(self.Root,"Browser")
	task.defer(function()
		RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:Layout(); RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:UpdateCarousel()
		local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.zero; local key=tostring(math.floor(viewport.X)).."x"..tostring(math.floor(viewport.Y))..":"..tostring(self.Context and self.Context.Mode)
		if self.LastAuditKey==key then return end; self.LastAuditKey=key
		local failures={}; local function expect(ok,message) if not ok then table.insert(failures,message) end end
		local roots=0; for _,child in ipairs(self.Host.Canvas:GetChildren()) do if child.Name=="CanonicalGarageBrowser" then roots+=1 end end; expect(roots==1,"expected one canonical browser root"); expect(self.Gui.Name=="CanonicalGarageGui","browser is not in CanonicalGarageGui"); expect(self.Scale.Parent==self.Host.Canvas,"browser does not use the shared canonical scale")
		expect(self.Categories.AbsolutePosition.Y+self.Categories.AbsoluteSize.Y<=self.Carousel.AbsolutePosition.Y-8,"categories overlap carousel")
		expect(self.Exit.AbsolutePosition.Y+self.Exit.AbsoluteSize.Y<=self.Carousel.AbsolutePosition.Y-6,"exit overlaps carousel")
		expect(math.abs(self.Cash.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3 and math.abs(self.Capacity.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3,"stacked economy cards do not match stats width"); expect(self.Capacity.AbsolutePosition.Y+self.Capacity.AbsoluteSize.Y<=self.Cash.AbsolutePosition.Y+2,"spaces card is not above cash")
		local lowest=self.Stats.AbsolutePosition.Y; for _,child in ipairs(self.Stats:GetChildren()) do if child:GetAttribute("GeneratedGarageUI") then lowest=math.max(lowest,child.AbsolutePosition.Y+child.AbsoluteSize.Y) end end; expect(lowest<=self.Stats.AbsolutePosition.Y+self.Stats.AbsoluteSize.Y+3,"stats content exceeds fitted panel")
		local maxScroll=self.MaxScroll or 0; local scrollX=self.Scroller.CanvasPosition.X; local tolerance=math.max(2,N("CarouselEndTolerance",4)); expect(self.Left.Visible==(maxScroll>tolerance and scrollX>tolerance),"left arrow visibility does not match overflow"); expect(self.RightArrow.Visible==(maxScroll>tolerance and scrollX<maxScroll-tolerance),"right arrow visibility does not match overflow")
		if maxScroll<=1 then local first,last; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then if not first or child.AbsolutePosition.X<first.AbsolutePosition.X then first=child end; if not last or child.AbsolutePosition.X>last.AbsolutePosition.X then last=child end end end; if first and last then local cardsCenter=(first.AbsolutePosition.X+last.AbsolutePosition.X+last.AbsoluteSize.X)*.5; local screenCenter=self.Root.AbsolutePosition.X+self.Root.AbsoluteSize.X*.5; expect(math.abs(cardsCenter-screenCenter)<=3,"non-overflowing cards are not screen-centred") end end
		if self.Popup.Shell.Visible and selectedCard and selectedCard.Parent then local popupCenter=self.Popup.Shell.AbsolutePosition.X+self.Popup.Shell.AbsoluteSize.X*.5; local cardCenter=selectedCard.AbsolutePosition.X+selectedCard.AbsoluteSize.X*.5; expect(math.abs(popupCenter-cardCenter)<=3,"action popup is not card-centred") end
		if #failures==0 then print("[NTR Garage Replacement Runtime] GEOMETRY PASS "..key) else warn("[NTR Garage Replacement Runtime] GEOMETRY FAIL: "..table.concat(failures," | ")) end
	end)
end
-- BrowserScrollMemory preserves the vehicle carousel when selecting a visible card.
function Browser:CaptureScroll()
	self.ScrollMemory=self.ScrollMemory or {}; local context=self.Context; if context and context.CarouselScrollKey then self.ScrollMemory[context.CarouselScrollKey]=self.Scroller.CanvasPosition.X end
end
function Browser:QueueScrollRestore(context)
	task.defer(function()
		RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait(); if not (self.Root.Visible and self.Context==context) then return end
		self:UpdateCarousel(); local x=context.CarouselScrollKey and self.ScrollMemory and self.ScrollMemory[context.CarouselScrollKey]; if x then local maximum=math.max(0,self.Scroller.AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X); self.Scroller.CanvasPosition=Vector2.new(math.clamp(x,0,maximum),0) end; self:RefreshCarouselArrows()
	end)
end
function Browser:Show(context)
	self:CaptureScroll(); self.Context=context; self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy); self:Layout(); self.Title.Text=string.upper(context.Mode=="Customisation" and "CUSTOMISATION" or "DEALERSHIP"); self.Subtitle.Text=context.Mode=="Customisation" and "Choose one of your owned cockpits to customise." or "Choose a vehicle category, then pick a cockpit."
	clear(self.CategoryList); local buttonH=N("CategoryButtonHeight",46); local all=generated(Racing.Button(self.CategoryList,{Text="ALL",Size=UDim2.new(1,0,0,buttonH),Color=context.State.BrowseAll and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); all.Activated:Connect(function() context.OnCategory(nil,true) end); local categories={}; for _,c in ipairs((context.State.Catalog and context.State.Catalog.Categories) or {}) do table.insert(categories,c) end; table.sort(categories,function(a,b) return tostring(a.DisplayName or a.CategoryId)<tostring(b.DisplayName or b.CategoryId) end); for _,c in ipairs(categories) do local button=generated(Racing.Button(self.CategoryList,{Text=c.DisplayName or c.CategoryId,Size=UDim2.new(1,0,0,buttonH),Color=not context.State.BrowseAll and c.CategoryId==context.State.CategoryId and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); button.Activated:Connect(function() context.OnCategory(c.CategoryId,false) end) end
	local rows=self:Rows(context); local selected
	for _,row in ipairs(rows) do if (row.VehicleId and row.VehicleId==context.State.SelectedVehicleId) or (not row.VehicleId and row.CockpitId==context.State.SelectedCockpit) then selected=row end end
	if (context.AutoPreview or not selected) and rows[1] then task.defer(function() if self.Root.Visible and self.Context==context then context.OnSelect(rows[1]) end end); return end
	clear(self.Scroller); local selectedCard
	for _,row in ipairs(rows) do local overall=row.Performance and row.Performance.Overall or {}; local isSelected=row==selected; local card=generated(Shared.Card(self.Scroller,{DisplayName=row.Cockpit.DisplayName or row.CockpitId,Image=context.ResolveImage(row.Cockpit),Rating=tostring(overall.Tier or "E").." "..tostring(math.floor(tonumber(overall.PerformanceIndex) or 100)),RatingColor=context.TierColor(tostring(overall.Tier or "E")),Selected=isSelected,Size=UDim2.fromOffset(N("CardWidth",226),N("CardHeight",146)),ImageHeight=N("CardImageHeight",136)})); card.Activated:Connect(function() context.OnSelect(row) end); if isSelected then selectedCard=card end end
	self:RenderStats(selected); self:RenderEconomy(context); task.defer(function() self:Layout(); self:QueueCarouselUpdate(); self:QueueScrollRestore(context) end)
	if selectedCard and selected then local owned=context.OwnedCount(selected.CockpitId)>0; local text=context.Mode=="Customisation" and "CUSTOMISE" or ((owned and "BUY ANOTHER " or "BUY ")..Shared.FormatMoney(selected.Cockpit.Price or 0)); self.Popup:Set(selectedCard,text,function() context.OnPrimary(selected) end,self.Scale) else self.Popup:Hide() end
	self:Audit(selectedCard)
end
function Browser:Hide()
	self:CaptureScroll(); self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root); self.Context=nil
	for _,parent in ipairs({self.CategoryList,self.Scroller,self.Stats,self.Cash,self.Capacity}) do clear(parent) end
end
return Browser
