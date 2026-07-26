-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
-- NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1
-- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
-- NTR_GARAGE_FLOW_REFINEMENT_V2_1
-- NTR_GARAGE_FLOW_REFINEMENT_V2
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
-- NTR_GARAGE_WORKSPACE_CONTROLLER_V3
-- NTR_OWNED_GARAGE_PHASE8_INCREMENTAL_WORKSPACE
-- NTR_OWNED_GARAGE_VEHICLE_CARD_KIND_V1_6
-- NTR_OWNED_GARAGE_SELECTED_ACTION_CONTRACT_V1_7
-- NTR_GARAGE_WORKSPACE_CATEGORY_LISTING_V3
-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS
-- NTR_OWNED_GARAGE_ICON_CONFIG_V1
-- NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Racing=require(kit.Shared.Modules.UI.RacingUIComponents)
local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents"))
local cfg=kit.Config.UI:WaitForChild("GarageReplacement")
-- NTR_GARAGE_EMBEDDED_ARTWORK_FALLBACK_V1
local artworkRoot=cfg:FindFirstChild("ModuleArtwork")
local artworkDefinitions={
	{Name="All",DisplayName="All",TargetId="ALL",SortOrder=10,ShowInBuild=false,ShowInCustomise=true},
	{Name="Cockpit",DisplayName="Cockpit",TargetId="Cockpit",SortOrder=20,ShowInBuild=false,ShowInCustomise=true},
	{Name="ThrustColour",DisplayName="Thrust Colour",TargetId="THRUST_COLOR",SortOrder=30,ShowInBuild=false,ShowInCustomise=true},
	{Name="FrontEngine",DisplayName="Front Engine",TargetId="Engine1",SortOrder=40,ShowInBuild=true,ShowInCustomise=true},
	{Name="RearEngine",DisplayName="Rear Engine",TargetId="Engine2",SortOrder=50,ShowInBuild=true,ShowInCustomise=true},
	{Name="Stabilisers",DisplayName="Stabilisers",TargetId="Stabilisers",SortOrder=60,ShowInBuild=true,ShowInCustomise=true},
	{Name="Boost",DisplayName="Boost",TargetId="Boost",SortOrder=70,ShowInBuild=true,ShowInCustomise=true},
	{Name="FrontBumper",DisplayName="Front Bumper",TargetId="FrontBumper",SortOrder=80,ShowInBuild=true,ShowInCustomise=true},
	{Name="RearBumper",DisplayName="Rear Bumper",TargetId="RearBumper",SortOrder=90,ShowInBuild=true,ShowInCustomise=true},
	{Name="SidePods",DisplayName="Side Pods",TargetId="SidePods",SortOrder=100,ShowInBuild=true,ShowInCustomise=true},
	{Name="Spoiler",DisplayName="Spoiler",TargetId="RearSpoiler",SortOrder=110,ShowInBuild=true,ShowInCustomise=true},
}
local Artwork={}; local artworkAuditPrinted=false
local function artworkBool(folder,name,fallback) if not folder then return fallback end; local value=folder:GetAttribute(name); if value==nil then return fallback end; return value==true end
local function artworkRow(definition)
	local folder=artworkRoot and artworkRoot:FindFirstChild(definition.Name)
	return {Name=definition.Name,DisplayName=tostring(folder and folder:GetAttribute("DisplayName") or definition.DisplayName),TargetId=tostring(folder and folder:GetAttribute("TargetId") or definition.TargetId),SortOrder=tonumber(folder and folder:GetAttribute("SortOrder")) or definition.SortOrder,ShowInBuild=artworkBool(folder,"ShowInBuild",definition.ShowInBuild),ShowInCustomise=artworkBool(folder,"ShowInCustomise",definition.ShowInCustomise),Image=tostring(folder and folder:GetAttribute("Image") or ""),Folder=folder}
end
function Artwork.ForPage(page) local result={}; for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition); if (page=="Build" and item.ShowInBuild) or (page=="Customise" and item.ShowInCustomise) then table.insert(result,item) end end; table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Artwork.ResolveImage(key) for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition); if item.Name==key or item.TargetId==key then return item.Image end end; return "" end
function Artwork.Audit()
	if not artworkAuditPrinted then local available=0; for _,definition in ipairs(artworkDefinitions) do local folder=artworkRoot and artworkRoot:FindFirstChild(definition.Name); if folder and folder:IsA("Folder") then available+=1 end end; if available==#artworkDefinitions then print("[NTR Garage Artwork] ATTRIBUTE FOLDERS PASS") else warn("[NTR Garage Artwork] FALLBACK ACTIVE folders="..tostring(available).."/"..tostring(#artworkDefinitions).."; cards remain functional with blank optional images") end; artworkAuditPrinted=true end
	return true,{}
end

local desktop=kit.Config.UI:WaitForChild("DesktopFreeRoamHud")
local inRace=kit.Config.UI.Racing:WaitForChild("InRace")
local function N(name,fallback) local attribute=cfg:GetAttribute(name); if typeof(attribute)=="number" then return attribute end; local v=cfg:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function RN(name,fallback) local v=inRace:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function asset(name) local f=desktop:FindFirstChild("Assets"); local v=f and f:FindFirstChild(name); return v and v.Value or "" end
local function generated(o) o:SetAttribute("GeneratedGarageWorkspace",true); return o end
local function clear(parent) for _,o in ipairs(parent:GetChildren()) do if o:GetAttribute("GeneratedGarageWorkspace") then o:Destroy() end end end
local WorkspaceUI={}; WorkspaceUI.__index=WorkspaceUI
local headerTitleSize,headerSubtitleSize=Shared.HeaderTextSizes() -- NTR_GARAGE_FLOW_REFINEMENT_V2

function WorkspaceUI.new()
	local self=setmetatable({},WorkspaceUI); self.Host=Shared.CanonicalHost(); self.Gui=self.Host.Gui; self.Scale=self.Host.Scale; self.Context=nil; self.Dynamic={}
	self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageWorkspace"; self.Root:SetAttribute("TutorialWorkspace",true); self.Root.BackgroundTransparency=1; self.Root.BorderSizePixel=0; self.Root.Visible=false; self.Root.Parent=self.Host.Canvas
	self.Header=Shared.MetricCard(self.Root,"Header")
	self.Title=Racing.Label(self.Header,{Text="GARAGE",Position=UDim2.fromOffset(12,3),Size=UDim2.new(1,-24,0,28),TextSize=headerTitleSize,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"}) -- NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1
	self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,29),TextSize=headerSubtitleSize,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"})
	self.Categories=Shared.Panel(self.Root,"Categories",{NoStroke=true})
	self.CategoryList=Instance.new("ScrollingFrame"); self.CategoryList.BackgroundTransparency=1; self.CategoryList.BorderSizePixel=0; self.CategoryList.ScrollBarThickness=0; self.CategoryList.AutomaticCanvasSize=Enum.AutomaticSize.Y; self.CategoryList.CanvasSize=UDim2.fromOffset(0,0); self.CategoryList.Position=UDim2.fromOffset(7,7); self.CategoryList.Size=UDim2.new(1,-14,1,-14); self.CategoryList.Parent=self.Categories
	local categoryLayout=Instance.new("UIListLayout"); categoryLayout.Padding=UDim.new(0,8); categoryLayout.Parent=self.CategoryList; self.CategoryLayout=categoryLayout -- NTR_GARAGE_FLOW_REFINEMENT_V2_1
	local categoryPad=Instance.new("UIPadding"); categoryPad.PaddingTop=UDim.new(0,6); categoryPad.PaddingBottom=UDim.new(0,6); categoryPad.PaddingLeft=UDim.new(0,6); categoryPad.PaddingRight=UDim.new(0,6); categoryPad.Parent=self.CategoryList
	self.CategoryWheelConnection=UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseWheel or not (self.Root.Visible and self.Categories.Visible and self.CategoryList.Visible) then return end
		local point=UserInputService:GetMouseLocation(); local position,size=self.CategoryList.AbsolutePosition,self.CategoryList.AbsoluteSize
		if point.X<position.X or point.X>position.X+size.X or point.Y<position.Y or point.Y>position.Y+size.Y then return end
		local maximum=math.max(0,self.CategoryList.AbsoluteCanvasSize.Y-size.Y); if maximum<=0 then return end
		self.CategoryList.CanvasPosition=Vector2.new(0,math.clamp(self.CategoryList.CanvasPosition.Y-input.Position.Z*(tonumber(cfg:GetAttribute("CategoryWheelStep")) or 48),0,maximum))
	end) -- NTR_GARAGE_FLOW_REFINEMENT_V2
	self.Right=Instance.new("Frame"); self.Right.BackgroundTransparency=1; self.Right.Parent=self.Root
	self.Right.AutomaticSize=Enum.AutomaticSize.Y
	self.Stats=Shared.Panel(self.Right,"Stats",{NoStroke=true}); self.Stats.AutomaticSize=Enum.AutomaticSize.Y; self.Stats.Size=UDim2.new(1,0,0,0); local statsPad=Instance.new("UIPadding"); statsPad.PaddingTop=UDim.new(0,10); statsPad.PaddingBottom=UDim.new(0,10); statsPad.PaddingLeft=UDim.new(0,12); statsPad.PaddingRight=UDim.new(0,12); statsPad.Parent=self.Stats; local statsLayout=Instance.new("UIListLayout"); statsLayout.Padding=UDim.new(0,5); statsLayout.SortOrder=Enum.SortOrder.LayoutOrder; statsLayout.Parent=self.Stats
	self.Economy=Instance.new("Frame"); self.Economy.BackgroundTransparency=1; self.Economy.Parent=self.Right
	local outline=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)); self.Cash=Shared.Panel(self.Economy,"Cash",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=Racing.StrokeWidth("Emphasis"),NoGlow=true}); self.Capacity=Shared.Panel(self.Economy,"Capacity",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=Racing.StrokeWidth("Emphasis"),NoGlow=true})
	self.StopCashBinding=Racing.BindReplicatedCash(nil,function(value) if self.Root.Visible and self.CashValue and self.CashValue.Parent then self.CashValue.Text=Shared.FormatMoney(value) end end)
	self.Carousel=Instance.new("Frame"); self.Carousel.Name="TutorialCardCarousel"; self.Carousel:SetAttribute("TutorialTargetId","CardCarousel"); self.Carousel.BackgroundTransparency=1; self.Carousel.Parent=self.Root
	self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.Name="TutorialCardScroller"; self.Scroller:SetAttribute("TutorialTargetId","CardScroller"); self.Scroller.BackgroundTransparency=1; self.Scroller.BorderSizePixel=0; self.Scroller.ScrollBarThickness=0; self.Scroller.CanvasSize=UDim2.fromOffset(0,0); self.Scroller.ScrollingDirection=Enum.ScrollingDirection.X; self.Scroller.ClipsDescendants=true; self.Scroller.Size=UDim2.fromScale(1,1); self.Scroller.Parent=self.Carousel
	self.CardLayout=Instance.new("UIListLayout"); self.CardLayout.FillDirection=Enum.FillDirection.Horizontal; self.CardLayout.VerticalAlignment=Enum.VerticalAlignment.Center; self.CardLayout.Padding=UDim.new(0,12); self.CardLayout.Parent=self.Scroller
	self.CardPad=Instance.new("UIPadding"); self.CardPad.PaddingLeft=UDim.new(0,6); self.CardPad.PaddingRight=UDim.new(0,6); self.CardPad.Parent=self.Scroller
	self.Paint=Instance.new("Frame"); self.Paint.BackgroundTransparency=1; self.Paint.Visible=false; self.Paint.Parent=self.Carousel
	local function arrow(name,text,parent) local b=Instance.new("TextButton"); b.Name=name; b.Text=text; b.AutoButtonColor=false; b.BackgroundColor3=Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)); b.BackgroundTransparency=.3; b.BorderSizePixel=0; b.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); b.TextSize=30; b.ZIndex=20; Racing.Font(b,"Heading"); Racing.Corner(b,5); b.Parent=parent or self.Root; return b end
	self.Left=arrow("Previous","<"); self.RightArrow=arrow("Next",">")
	self.CategoryPrevious=arrow("CategoryPrevious","^",self.Categories); self.CategoryNext=arrow("CategoryNext","v",self.Categories); self.CategoryPrevious.TextSize=22; self.CategoryNext.TextSize=22; self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false -- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
	self.Back=Shared.ActionButton(self.Root,{Name="Back",Text="BACK",IconText="<",Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})
	self.Next=Shared.ActionButton(self.Root,{Name="Continue",Text="DRIVE",Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=outline})
	self.Exit=Shared.ActionButton(self.Root,{Name="Exit",Text="EXIT",IconText="X",Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")}) -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
	self.Budget=Shared.Panel(self.Root,"UpgradeBudget",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true}); self.Budget.Visible=false; self.Budget.ZIndex=30 -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1
	self.Popup=Shared.Popup(self.Root)
	self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end); self.CategoryPrevious.Activated:Connect(function() self:ScrollCategories(-1) end); self.CategoryNext.Activated:Connect(function() self:ScrollCategories(1) end)
	self.Back.Activated:Connect(function() if self.Context and self.Context.OnBack then self.Context.OnBack() end end)
	self.Next.Activated:Connect(function() if self.Context and self.Context.OnNext then self.Context.OnNext() end end)
	self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end)
	self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)
	self.CategoryList:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:UpdateCategoryArrows() end); self.CategoryList:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() self:UpdateCategoryArrows() end); self.CategoryList:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:UpdateCategoryArrows() end); self.CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCategoryUpdate() end)
	local camera=Workspace.CurrentCamera; if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if self.Root.Visible then self:Layout() end end) end
	return self
end

function WorkspaceUI:DisconnectDynamic() for _,connection in ipairs(self.Dynamic) do connection:Disconnect() end; table.clear(self.Dynamic) end
function WorkspaceUI:Message(text) self.Subtitle.Text=tostring(text or "") end
function WorkspaceUI:Layout()
	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); local shell=Shared.LayoutGarageShell(self,{Number=N,Viewport=viewport,MinimumScale=minimum,Actions={self.Exit,self.Next,self.Back}})
	local budgetColumns=3; local budgetGap=12; local budgetWidth=math.min(budgetColumns*N("WorkspaceCardWidth",210)+(budgetColumns-1)*budgetGap,math.max(1,shell.Width-2*N("Margin",18))); self.BudgetWidth=budgetWidth -- NTR_GARAGE_RESPONSIVE_BUDGET_V1_2
	self.Budget.AnchorPoint=Vector2.new(.5,1); self.Budget.Position=UDim2.fromOffset(shell.Width*.5,shell.CarouselTop-N("UpgradeBudgetPopupClearance",48)); self.Budget.Size=UDim2.fromOffset(budgetWidth,N("UpgradeBudgetHeight",42))
	if self.Context and self.Categories.Visible then
		if self.Context.LeftFitContent then local count=#(self.Context.LeftItems or {}); local buttonHeight=N("CategoryButtonHeight",46); local height=N("BuildLeftPanelPadding",14)*2+12+count*buttonHeight+math.max(0,count-1)*8; self.Categories.Size=UDim2.fromOffset(self.Categories.Size.X.Offset,height) end
		if self.Context.LeftAlignCarouselBottom then local top=self.Categories.Position.Y.Offset; local bottom=shell.CarouselTop+N("CarouselHeight",166); if self.Context.MaterialChannels then bottom=shell.CarouselTop-math.max(0,tonumber(cfg:GetAttribute("MaterialRailTabClearance")) or 48) end; self.Categories.Size=UDim2.fromOffset(self.Categories.Size.X.Offset,math.max(170,bottom-top)) end
	end
	self:QueueCarouselUpdate()
end

function WorkspaceUI:ResolveImage(key,explicit)
	if explicit and explicit~="" then return explicit end; return Artwork.ResolveImage(key)
end
function WorkspaceUI:ArtworkDefinitions(page) return Artwork.ForPage(page) end
function WorkspaceUI:RenderLeft(context)
	clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false; self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false
	self.CategoryList.Position=UDim2.fromOffset(7,7); self.CategoryList.Size=UDim2.new(1,-14,1,-14); self.CategoryList.CanvasPosition=Vector2.zero; self.CategoryRailReserved=false
	self.Categories.BackgroundTransparency=context.LeftFloating and 1 or .12; local surface=self.Categories:FindFirstChild("SurfaceGradient"); if surface and surface:IsA("UIGradient") then surface.Enabled=not context.LeftFloating end; if self.CategoryLayout then self.CategoryLayout.HorizontalAlignment=context.LeftSharedCardSize and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left end
	if not self.Categories.Visible then return end
	for order,item in ipairs(context.LeftItems or {}) do
		local button
		if context.LeftCardMode then
			local cardHeight=context.LeftSharedCardSize and N("WorkspaceCardHeight",146) or (context.LeftCardHeight or N("CustomiseCategoryCardHeight",118)); local imageHeight=context.LeftSharedCardSize and N("ModuleCardImageHeight",104) or (context.LeftCardImageHeight or N("CustomiseCategoryImageHeight",78))
			local cardSize=context.LeftSharedCardSize and UDim2.fromOffset(N("WorkspaceCardWidth",210),cardHeight) or UDim2.new(1,0,0,cardHeight); button=generated(Shared.ModuleCategoryCard(self.CategoryList,{DisplayName=item.Text or item.Id or "",Image=self:ResolveImage(item.ImageKey or item.Id,item.Image),Selected=item.Selected==true,Size=cardSize,ImageHeight=imageHeight,ImageZoom=item.ImageZoom or 1.04}))
		else button=generated(Racing.Button(self.CategoryList,{Text=string.upper(item.Text or item.Id or ""),Size=UDim2.new(1,0,0,N("CategoryButtonHeight",46)),Color=item.Selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})) end
		button.LayoutOrder=order; button.Activated:Connect(function() if item.OnSelect then item.OnSelect() end end)
	end
	self:QueueCategoryUpdate()
end
function WorkspaceUI:RenderEconomy(context)
	clear(self.Cash); clear(self.Capacity)
	self.CashValue=generated(Shared.EconomyMetric(self.Cash,{Kind="Cash",Text=Shared.FormatMoney(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=N("EconomyCashTextSize",17),Color=Color3.fromRGB(89,255,102),Role="Heading"})); local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Visible=context.ShowCashPlus~=false; plus.Activated:Connect(function() if context.OnCash then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=(type(context.CapacityIcon)=="string" and context.CapacityIcon~="") and context.CapacityIcon or asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity
	generated(Shared.EconomyMetric(self.Capacity,{Kind="GarageSpaces",Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=N("EconomySpacesTextSize",13),Role="Heading"})); local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Visible=context.ShowCapacityPlus~=false; gp.Activated:Connect(function() if context.OnCapacity then context.OnCapacity() end end)
end

function WorkspaceUI:DrawPerformance(parent,performance,baseline,tierColor) Shared.RenderPerformance(parent,{Performance=performance,Baseline=baseline,TierColor=tierColor,Reference=N("StatReference",180),GeneratedAttribute="GeneratedGarageWorkspace",RatingTextSize=N("PerformanceRatingTextSize",20),HeadingTextSize=N("PerformanceHeadingTextSize",11),StatNameTextSize=N("PerformanceStatNameTextSize",11),StatValueTextSize=N("PerformanceStatValueTextSize",12)}) end
function WorkspaceUI:RenderStats(context) clear(self.Stats); self.Stats.Visible=context.ShowStats~=false; if not self.Stats.Visible then return end; if context.RenderStats then context.RenderStats(self.Stats) else self:DrawPerformance(self.Stats,context.Performance,context.BaselinePerformance,context.TierColor) end end
function WorkspaceUI:RenderBudget(context)
	clear(self.Budget); local budget=context.UpgradeBudget; self.Budget.Visible=typeof(budget)=="table"; if not self.Budget.Visible then return end
	local capacity=math.max(0,math.floor(tonumber(budget.Capacity) or 0)); local used=math.clamp(math.floor(tonumber(budget.Used) or 0),0,capacity); local width=self.BudgetWidth or (3*N("WorkspaceCardWidth",210)+24); local height=N("UpgradeBudgetHeight",42); local textSize=13
	local budgetTitle=generated(Racing.Label(self.Budget,{Name="BudgetTitle",Text=string.upper(budget.Label or "UPGRADE POINTS"),Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(180,height),TextSize=textSize,Role="Heading",Truncate=Enum.TextTruncate.None})); budgetTitle.TextScaled=false; budgetTitle.TextWrapped=false; budgetTitle.ZIndex=self.Budget.ZIndex+2
	local pipWidth=N("UpgradeBudgetPipWidth",18); local pipGap=N("UpgradeBudgetPipGap",5); local totalWidth=capacity*pipWidth+math.max(0,capacity-1)*pipGap; local startX=(width-totalWidth)*.5; local pipY=(height-16)*.5
	for index=1,capacity do local pip=generated(Instance.new("Frame")); pip.Name="Point"..index; pip.Position=UDim2.fromOffset(startX+(index-1)*(pipWidth+pipGap),pipY); pip.Size=UDim2.fromOffset(pipWidth,16); pip.BorderSizePixel=0; pip.BackgroundColor3=index<=used and (used==capacity and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)); pip.ZIndex=self.Budget.ZIndex+2; pip.Parent=self.Budget; Racing.Corner(pip,4); if index<=used and used<capacity then local gradient=Instance.new("UIGradient"); gradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))); gradient.Parent=pip end end
	local budgetUsed=generated(Racing.Label(self.Budget,{Name="BudgetUsed",Text=tostring(used).."/"..tostring(capacity).." USED",Position=UDim2.new(1,-132,0,0),Size=UDim2.fromOffset(120,height),TextSize=textSize,XAlignment=Enum.TextXAlignment.Right,Role="Heading",Truncate=Enum.TextTruncate.None})); budgetUsed.TextScaled=false; budgetUsed.TextWrapped=false; budgetUsed.ZIndex=self.Budget.ZIndex+2
end -- NTR_GARAGE_RESPONSIVE_BUDGET_RENDERER_V1_2

function WorkspaceUI:RenderChannelTabs(parent,channels,selected,onChannel,position)
	local configuredWidth=tonumber(cfg:GetAttribute("WorkspacePaintWideWidth")) or 900; local width=math.min(configuredWidth,self.ReferenceCarouselWidth or configuredWidth); local tabs=generated(Instance.new("Frame")); tabs.Name="SharedChannelTabs"; tabs.BackgroundTransparency=1; tabs.AnchorPoint=Vector2.new(.5,1); tabs.Position=position; tabs.Size=UDim2.fromOffset(width,34); tabs.Parent=parent
	local tabWidth=math.max(96,(width-math.max(0,#channels-1)*8)/math.max(1,#channels)); for index,channel in ipairs(channels) do local b=generated(Racing.Button(tabs,{Text=string.upper(channel),Position=UDim2.fromOffset((index-1)*(tabWidth+8),1),Size=UDim2.fromOffset(tabWidth,32),Color=channel==selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); b.Activated:Connect(function() if onChannel then onChannel(channel) end end) end; return tabs
end

function WorkspaceUI:RenderCards(context)
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
	self.Paint.Visible=false; self.Scroller.Visible=true; self:RenderBudget(context); clear(self.Carousel); clear(self.Scroller); if context.MaterialChannels then self:RenderChannelTabs(self.Carousel,context.MaterialChannels,context.SelectedChannel or context.MaterialChannels[1],context.OnChannel,UDim2.new(.5,0,0,-6)) end; self.Popup:Hide(); local selectedCard; local explicitActionCard; local legacyAction; local selectedAction=context.SelectedAction
	for order,row in ipairs(context.Cards or {}) do
		-- NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1
		local selected=row.Selected==true; local vehicleCard=row.CardKind=="Vehicle"; local props={DisplayName=row.DisplayName or row.Id or "",EmptyPlus=row.EmptyPlus,Muted=row.Muted,Eyebrow=row.Eyebrow,Meta=row.Meta,Footer=row.Footer,Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,TagText=row.TagText,TagColor=row.TagColor,Price=row.Price,PriceText=row.PriceText,PriceColor=row.PriceColor,SemanticState=row.SemanticState,LockImage=row.LockImage,LockIconSize=N("LockedModuleIconSize",68),LockIconYScale=N("LockedModuleIconYScale",.46),Size=vehicleCard and UDim2.fromOffset(N("CardWidth",226),N("CardHeight",146)) or UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=vehicleCard and N("CardImageHeight",136) or N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or (vehicleCard and 1.06 or 1.04)}
		local card=generated(row.CardKind=="Listing" and Shared.ModuleListingCard(self.Scroller,props) or (vehicleCard and Shared.Card(self.Scroller,props) or Shared.ModuleCategoryCard(self.Scroller,props))); card:SetAttribute("CanonicalGarageCardId",tostring(row.Id or "")); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end) --[[NTR_ONBOARDING_V1_5_SHARED_WORKSPACE_SEMANTICS]]; if selected then selectedCard=card; if row.ActionText and row.OnAction then legacyAction={Card=card,Text=row.ActionText,OnActivate=row.OnAction} end end; if selectedAction and tostring(selectedAction.RowId or "")==tostring(row.Id or "") then explicitActionCard=card end
	end
	local action=selectedAction and explicitActionCard and {Card=explicitActionCard,Text=selectedAction.Text,OnActivate=selectedAction.OnActivate} or legacyAction; if action and action.Text and action.OnActivate then self.Popup:Set(action.Card,action.Text,action.OnActivate,self.Scale) end
	if context.EmptyMessage and #(context.Cards or {})==0 then local empty=generated(Racing.Label(self.Scroller,{Text=context.EmptyMessage,Size=UDim2.fromOffset(420,80),TextSize=13,XAlignment=Enum.TextXAlignment.Center})); empty:SetAttribute("CanonicalGarageCard",true) end
	self:QueueCarouselUpdate(); return selectedCard
end
function WorkspaceUI:RenderPaint(context)
	self.Popup:Hide(); self.Budget.Visible=false; self.Scroller.Visible=false; self.Paint.Visible=true; clear(self.Carousel); clear(self.Paint); local channels=context.ColorChannels or {}; local selected=context.SelectedChannel or channels[1]; if not selected then return end
	local current=(context.Colors and context.Colors[selected]) or Color3.new(1,1,1); local h,s,v=Color3.toHSV(current); self.PaintHSV={h,s,v}; self.PaintChannel=selected
	local configuredWidth=tonumber(cfg:GetAttribute("WorkspacePaintWideWidth")) or 900; local width=math.min(configuredWidth,self.ReferenceCarouselWidth or configuredWidth)
	self:RenderChannelTabs(self.Paint,channels,selected,context.OnChannel,UDim2.new(.5,0,.5,-86))
	local panel=generated(Shared.Panel(self.Paint,"PaintControls",{StrokeColor=Racing.Colour("ElectricBlue"),StrokeTransparency=.35,NoGlow=true})); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(width,156)
	local gradients,knobs,paletteStrokes={},{},{}; local currentSwatch
	local function liveColour() return Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],self.PaintHSV[3]) end
	local function refreshGradients()
		if gradients[1] then gradients[1].Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.17,Color3.fromHSV(.17,1,1)),ColorSequenceKeypoint.new(.33,Color3.fromHSV(.33,1,1)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(.5,1,1)),ColorSequenceKeypoint.new(.67,Color3.fromHSV(.67,1,1)),ColorSequenceKeypoint.new(.83,Color3.fromHSV(.83,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))}) end
		if gradients[2] then gradients[2].Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromHSV(self.PaintHSV[1],1,1)) end
		if gradients[3] then gradients[3].Color=ColorSequence.new(Color3.new(0,0,0),Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],1)) end
		if currentSwatch then currentSwatch.BackgroundColor3=liveColour() end
	end
	local function refreshKnobs() for index,knob in ipairs(knobs) do knob.Position=UDim2.fromScale(self.PaintHSV[index],.5) end end
	local function markPreset(chosen) for _,stroke in ipairs(paletteStrokes) do stroke.Color=stroke==chosen and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or Racing.Colour("Text",Color3.new(1,1,1)); stroke.Transparency=stroke==chosen and 0 or .56; stroke.Thickness=stroke==chosen and 2 or 1 end end
	local function emit(commit) if context.OnColor then context.OnColor(selected,liveColour(),commit==true) end end
	local sliderGap=16; local sliderX=14; local sliderWidth=(width-28-sliderGap*2)/3
	local function slider(labelText,index,column)
		local x=sliderX+(column-1)*(sliderWidth+sliderGap); generated(Racing.Label(panel,{Text=labelText,Position=UDim2.fromOffset(x,6),Size=UDim2.fromOffset(sliderWidth,17),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}))
		local track=generated(Instance.new("Frame")); track.Active=true; track.BackgroundColor3=Color3.new(1,1,1); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(x,29); track.Size=UDim2.fromOffset(sliderWidth,10); track.Parent=panel; Racing.Corner(track,5)
		local gradient=Instance.new("UIGradient"); gradient.Parent=track; gradients[index]=gradient
		local knob=generated(Instance.new("Frame")); knob.AnchorPoint=Vector2.new(.5,.5); knob.Position=UDim2.fromScale(self.PaintHSV[index],.5); knob.Size=UDim2.fromOffset(5,18); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=8; knob.Parent=track; Racing.Corner(knob,3); knobs[index]=knob
		local function update(input) self.PaintHSV[index]=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); markPreset(nil); refreshKnobs(); refreshGradients(); emit(false) end
		table.insert(self.Dynamic,track.InputBegan:Connect(function(input) if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; update(input); local move,ended; move=UserInputService.InputChanged:Connect(function(changed) if changed.UserInputType==Enum.UserInputType.MouseMovement or changed.UserInputType==Enum.UserInputType.Touch then update(changed) end end); ended=UserInputService.InputEnded:Connect(function(done) if done.UserInputType==input.UserInputType then move:Disconnect(); ended:Disconnect(); emit(true) end end) end))
	end
	slider("HUE",1,1); slider("SATURATION",2,2); slider("BRIGHTNESS",3,3)
	local columns=15; local gap=6; local x0=14; local swatchWidth=(width-28-(columns-1)*gap)/columns; local swatchHeight=24; local y0=88
	generated(Racing.Label(panel,{Text="CURRENT",Position=UDim2.fromOffset(x0,66),Size=UDim2.fromOffset(swatchWidth*2+gap,16),TextSize=9,XAlignment=Enum.TextXAlignment.Center,Role="Metric"}))
	currentSwatch=generated(Instance.new("Frame")); currentSwatch.Name="CurrentColour"; currentSwatch.BackgroundColor3=current; currentSwatch.BorderSizePixel=0; currentSwatch.Position=UDim2.fromOffset(x0,y0); currentSwatch.Size=UDim2.fromOffset(swatchWidth*2+gap,swatchHeight*2+7); currentSwatch.ZIndex=7; currentSwatch.Parent=panel; Racing.Corner(currentSwatch,5); local currentStroke=Instance.new("UIStroke"); currentStroke.Color=Racing.Colour("Text"); currentStroke.Transparency=.25; currentStroke.Parent=currentSwatch
	local hues={0,.07,.14,.31,.43,.51,.60,.68,.76,.86,.93}
	local function paletteColour(column,row) if column==3 then return row==1 and Color3.new(1,1,1) or Color3.fromRGB(180,180,184) end; if column==4 then return row==1 and Color3.fromRGB(66,66,72) or Color3.new(0,0,0) end; local hue=hues[column-4]; return row==1 and Color3.fromHSV(hue,.48,1) or Color3.fromHSV(hue,.86,.42) end
	for row=1,2 do for column=3,columns do local colour=paletteColour(column,row); local swatch=generated(Instance.new("TextButton")); swatch.Name="Palette"..row.."_"..column; swatch.Text=""; swatch.AutoButtonColor=false; swatch.BackgroundColor3=colour; swatch.BorderSizePixel=0; swatch.Position=UDim2.fromOffset(x0+(column-1)*(swatchWidth+gap),y0+(row-1)*(swatchHeight+7)); swatch.Size=UDim2.fromOffset(swatchWidth,swatchHeight); swatch.ZIndex=7; swatch.Parent=panel; Racing.Corner(swatch,4); local stroke=Instance.new("UIStroke"); stroke.Color=Racing.Colour("Text"); stroke.Transparency=.56; stroke.Thickness=1; stroke.Parent=swatch; table.insert(paletteStrokes,stroke); swatch.Activated:Connect(function() local ph,ps,pv=Color3.toHSV(colour); self.PaintHSV={ph,ps,pv}; markPreset(stroke); refreshKnobs(); refreshGradients(); emit(true) end) end end
	refreshKnobs(); refreshGradients()
end -- NTR_GARAGE_FLOW_REFINEMENT_V2

function WorkspaceUI:QueueCategoryUpdate()
	if self.CategoryUpdateQueued then return end; self.CategoryUpdateQueued=true
	task.defer(function() RunService.Heartbeat:Wait(); self.CategoryUpdateQueued=false; if self.Root.Visible then self:UpdateCategoryArrows() end end)
end
function WorkspaceUI:UpdateCategoryArrows()
	if not (self.Root.Visible and self.Categories.Visible and self.CategoryList.Visible) then self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false; return end
	local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local fullWindow=math.max(0,self.Categories.AbsoluteSize.Y-14*scale); local content=self.CategoryLayout.AbsoluteContentSize.Y+12*scale; local overflow=content>fullWindow+2
	local gutter=N("CategoryArrowGutter",36); local arrowWidth=N("CategoryArrowWidth",46); local arrowHeight=N("CategoryArrowHeight",27)
	self.CategoryPrevious.AnchorPoint=Vector2.new(.5,0); self.CategoryPrevious.Position=UDim2.new(.5,0,0,2); self.CategoryPrevious.Size=UDim2.fromOffset(arrowWidth,arrowHeight)
	self.CategoryNext.AnchorPoint=Vector2.new(.5,1); self.CategoryNext.Position=UDim2.new(.5,0,1,-2); self.CategoryNext.Size=UDim2.fromOffset(arrowWidth,arrowHeight)
	if self.CategoryRailReserved~=overflow then self.CategoryRailReserved=overflow; if overflow then self.CategoryList.Position=UDim2.fromOffset(7,gutter); self.CategoryList.Size=UDim2.new(1,-14,1,-gutter*2) else self.CategoryList.Position=UDim2.fromOffset(7,7); self.CategoryList.Size=UDim2.new(1,-14,1,-14); self.CategoryList.CanvasPosition=Vector2.zero end; self:QueueCategoryUpdate() end
	if not overflow then self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false; return end
	local maximum=math.max(0,self.CategoryList.AbsoluteCanvasSize.Y-self.CategoryList.AbsoluteWindowSize.Y); local y=self.CategoryList.CanvasPosition.Y; local tolerance=math.max(2,N("CarouselEndTolerance",4))
	self.CategoryPrevious.Visible=maximum>tolerance and y>tolerance; self.CategoryNext.Visible=maximum>tolerance and y<maximum-tolerance
end
function WorkspaceUI:ScrollCategories(direction)
	local maximum=math.max(0,self.CategoryList.AbsoluteCanvasSize.Y-self.CategoryList.AbsoluteWindowSize.Y); local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local y=math.clamp(self.CategoryList.CanvasPosition.Y+direction*N("CategoryArrowStep",124)*scale,0,maximum)
	self.CategoryList.CanvasPosition=Vector2.new(0,y); self:UpdateCategoryArrows()
end
function WorkspaceUI:QueueCarouselUpdate() if self.CarouselQueued then return end; self.CarouselQueued=true; task.defer(function() RunService.Heartbeat:Wait(); self.CarouselQueued=false; if self.Root.Visible then self:UpdateCarousel() end end) end
function WorkspaceUI:RefreshCarouselArrows()
	if not self.Scroller.Visible then self.Left.Visible=false; self.RightArrow.Visible=false; return end
	local maximum=math.max(0,self.Scroller.AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X); local x=self.Scroller.CanvasPosition.X; local tolerance=math.max(2,N("CarouselEndTolerance",4)); self.MaxScroll=maximum
	self.Left.Visible=maximum>tolerance and x>tolerance; self.RightArrow.Visible=maximum>tolerance and x<maximum-tolerance
end
function WorkspaceUI:UpdateCarousel()
	if not self.Scroller.Visible or self.Updating then self.Left.Visible=false; self.RightArrow.Visible=false; return end
	self.Updating=true; local count=0; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then count+=1 end end
	local cardWidth=N("WorkspaceCardWidth",210); local content=count*cardWidth+math.max(0,count-1)*12; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local window=self.ReferenceCarouselWidth or self.Scroller.AbsoluteSize.X/scale; if self.Scroller.AbsoluteSize.X>0 then window=self.Scroller.AbsoluteSize.X/scale end
	local side=content<window and math.max(6,(window-content)*.5) or 6; self.CardPad.PaddingLeft=UDim.new(0,side); self.CardPad.PaddingRight=UDim.new(0,side); self.Scroller.CanvasSize=UDim2.fromOffset(math.max(window,content+side*2),0); self.Updating=false; self:RefreshCarouselArrows()
end
function WorkspaceUI:Scroll(direction) local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local logicalWidth=N("WorkspaceCardWidth",210); for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then logicalWidth=child.AbsoluteSize.X/math.max(scale,.01); break end end; local step=(logicalWidth+12)*scale; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*step,0,self.MaxScroll or 0),0); self:RefreshCarouselArrows() end
function WorkspaceUI:Audit(selectedCard)
	if not (cfg:GetAttribute("RuntimeAuditEnabled")==true and (not self.Context or self.Context.RuntimeAudit~=false)) then return end
	task.defer(function()
		RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:Layout(); RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:UpdateCarousel()
		local failures={}; local function expect(ok,message) if not ok then table.insert(failures,message) end end; local roots=0; for _,child in ipairs(self.Host.Canvas:GetChildren()) do if child.Name=="CanonicalGarageWorkspace" then roots+=1 end end; expect(roots==1,"expected one workspace root"); expect(self.Gui.Name=="CanonicalGarageGui","workspace is not in CanonicalGarageGui"); expect(self.Scale.Parent==self.Host.Canvas,"workspace does not use the shared canonical scale"); local artOk,artFailures=Artwork.Audit(); expect(artOk,"module artwork schema: "..table.concat(artFailures,", "))
		Shared.AuditPresentation(self.Root,"Workspace")
		if self.Categories.Visible then expect(self.Categories.AbsolutePosition.Y+self.Categories.AbsoluteSize.Y<=self.Carousel.AbsolutePosition.Y-8,"categories overlap carousel") end
		expect(math.abs(self.Cash.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3 and math.abs(self.Capacity.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3,"stacked economy cards do not match stats width"); expect(self.Capacity.AbsolutePosition.Y+self.Capacity.AbsoluteSize.Y<=self.Cash.AbsolutePosition.Y+2,"spaces card is not above cash"); local rightEdge=self.Root.AbsolutePosition.X+self.Root.AbsoluteSize.X+2; for _,object in ipairs({self.Right,self.Stats,self.Economy,self.Exit,self.Next,self.Back,self.RightArrow}) do if object.Visible then expect(object.AbsolutePosition.X+object.AbsoluteSize.X<=rightEdge,"right edge clipped: "..object.Name) end end
		local maxScroll=self.MaxScroll or 0; local x=self.Scroller.CanvasPosition.X; local tolerance=math.max(2,N("CarouselEndTolerance",4)); expect(self.Left.Visible==(self.Scroller.Visible and maxScroll>tolerance and x>tolerance),"left arrow state mismatch"); expect(self.RightArrow.Visible==(self.Scroller.Visible and maxScroll>tolerance and x<maxScroll-tolerance),"right arrow state mismatch")
		if self.Scroller.Visible and maxScroll<=1 then local first,last; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then if not first or child.AbsolutePosition.X<first.AbsolutePosition.X then first=child end; if not last or child.AbsolutePosition.X>last.AbsolutePosition.X then last=child end end end; if first and last then expect(math.abs((first.AbsolutePosition.X+last.AbsolutePosition.X+last.AbsoluteSize.X)*.5-(self.Root.AbsolutePosition.X+self.Root.AbsoluteSize.X*.5))<=3,"short card row is not centred") end end
		if self.Popup.Shell.Visible and selectedCard and selectedCard.Parent then expect(math.abs((self.Popup.Shell.AbsolutePosition.X+self.Popup.Shell.AbsoluteSize.X*.5)-(selectedCard.AbsolutePosition.X+selectedCard.AbsoluteSize.X*.5))<=3,"action popup is not card-centred"); if self.Budget.Visible then expect(self.Budget.AbsolutePosition.Y+self.Budget.AbsoluteSize.Y<=self.Popup.Shell.AbsolutePosition.Y-6,"upgrade budget overlaps action popup") end end
		if #failures==0 then print("[NTR Garage Workspace Runtime] GEOMETRY PASS "..tostring(self.Context and self.Context.Title)) else warn("[NTR Garage Workspace Runtime] GEOMETRY FAIL: "..table.concat(failures," | ")) end
	end)
end
-- WorkspaceScrollMemory preserves user position across card rerenders without sharing positions between unrelated views.
function WorkspaceUI:CaptureScroll()
	self.ScrollMemory=self.ScrollMemory or {Carousel={},Category={}}; local context=self.Context; if not context then return end
	if context.CarouselScrollKey then self.ScrollMemory.Carousel[context.CarouselScrollKey]=self.Scroller.CanvasPosition.X end
	if context.CategoryScrollKey then self.ScrollMemory.Category[context.CategoryScrollKey]=self.CategoryList.CanvasPosition.Y end
end
function WorkspaceUI:QueueScrollRestore(context)
	task.defer(function()
		RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait(); if not (self.Root.Visible and self.Context==context) then return end
		self.ScrollMemory=self.ScrollMemory or {Carousel={},Category={}}; self:UpdateCarousel(); self:UpdateCategoryArrows()
		local x=context.CarouselScrollKey and self.ScrollMemory.Carousel[context.CarouselScrollKey]; if x then local maximum=math.max(0,self.Scroller.AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X); self.Scroller.CanvasPosition=Vector2.new(math.clamp(x,0,maximum),0) end
		local y=context.CategoryScrollKey and self.ScrollMemory.Category[context.CategoryScrollKey]; if y then local maximum=math.max(0,self.CategoryList.AbsoluteCanvasSize.Y-self.CategoryList.AbsoluteWindowSize.Y); self.CategoryList.CanvasPosition=Vector2.new(0,math.clamp(y,0,maximum)) end
		self:RefreshCarouselArrows(); self:UpdateCategoryArrows()
	end)
end
function WorkspaceUI:RefreshCards(context)
	self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context; self.Root:SetAttribute("TutorialPageId",tostring(context.TutorialPageId or "")); self.Title.Text=string.upper(context.Title or "GARAGE"); self.Subtitle.Text=context.Subtitle or ""; self.Back.Visible=context.BackVisible==true; Shared.SetActionButton(self.Back,context.BackText or "BACK",context.BackIcon,context.BackIconText or "<"); local selected=self:RenderCards(context); self:QueueScrollRestore(context); self:Audit(selected); return selected
end
function WorkspaceUI:Show(context)
	self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context; self.Root:SetAttribute("TutorialPageId",tostring(context.TutorialPageId or ""))
	self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy); self:Layout(); self.Title.Text=string.upper(context.Title or "GARAGE"); self.Subtitle.Text=context.Subtitle or ""; self.Back.Visible=context.BackVisible==true; self.Next.Visible=context.NextVisible~=false; self.Exit.Visible=context.ExitVisible==true; Shared.SetActionButton(self.Back,context.BackText or "BACK",context.BackIcon,context.BackIconText or "<"); Shared.SetActionButton(self.Next,context.NextText or "DRIVE",context.NextIcon,context.NextIconText); Shared.SetActionButton(self.Exit,context.ExitText or "EXIT",context.ExitIcon,context.ExitIconText or "X")
	self:RenderLeft(context); self:RenderStats(context); self:RenderEconomy(context); local selectedCard; if context.ColorChannels then self:RenderPaint(context) else selectedCard=self:RenderCards(context) end; self:Layout(); self:QueueScrollRestore(context); self:Audit(selectedCard)
end
function WorkspaceUI:Hide()
	self:CaptureScroll(); self:DisconnectDynamic(); self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root); self.Context=nil
	self.Budget.Visible=false; self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false; for _,parent in ipairs({self.CategoryList,self.Carousel,self.Scroller,self.Paint,self.Stats,self.Cash,self.Capacity,self.Budget}) do clear(parent) end
end
return WorkspaceUI
