-- Neo Tokyo Racers - Canonical garage navigation, overflow, and economy phase
-- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
-- Run once in the Studio Edit Command Bar, then restart Play.
-- Presentation-only: does not alter gameplay, persistence, preview physics, VFX, or lighting.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_NAV_SCROLL_ECONOMY_V1"
local PREFIX="[NTR Garage Navigation/Scroll/Economy V1]"

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local function need(parent,name,className)
	local object=parent:FindFirstChild(name)
	assert(object,parent:GetFullName().."."..name.." missing")
	if className then assert(object:IsA(className),object:GetFullName().." must be "..className) end
	return object
end

local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true)
	assert(first,"Missing source anchor: "..label)
	assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label)
	return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end

local function replaceBlock(source,startMarker,endMarker,replacement,label)
	local first=string.find(source,startMarker,1,true)
	assert(first,"Missing block start: "..label)
	local finish=string.find(source,endMarker,first+#startMarker,true)
	assert(finish,"Missing block end: "..label)
	assert(not string.find(source,startMarker,finish+1,true),"Duplicate block start: "..label)
	return string.sub(source,1,first-1)..replacement..string.sub(source,finish)
end

local function compile(name,source)
	local fn,err=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(err))
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local config=need(need(need(kit,"Config","Folder"),"UI","Folder"),"GarageReplacement","Folder")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local uiRoot=need(need(clientRoot,"Controllers","Folder"),"UI","Folder")
local sharedModule=need(uiRoot,"GarageReplacementComponents","ModuleScript")
local workspaceModule=need(uiRoot,"GarageWorkspaceController","ModuleScript")
local browserModule=need(uiRoot,"GarageBrowserController","ModuleScript")
local applicationModule=need(uiRoot,"ModuleShopUIController","ModuleScript")

local originals={
	Shared=sharedModule.Source,
	Workspace=workspaceModule.Source,
	Browser=browserModule.Source,
	Application=applicationModule.Source,
}

local function markerCount()
	local count=0
	for _,source in pairs(originals) do if string.find(source,REVISION,1,true) then count+=1 end end
	return count
end

local function audit()
	local pass,fail=0,0
	local function check(ok,message)
		if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end
	end
	local shared,workspace,browser,application=sharedModule.Source,workspaceModule.Source,browserModule.Source,applicationModule.Source
	check(string.find(shared,REVISION,1,true)~=nil,"shared shell owner installed")
	check(string.find(workspace,REVISION,1,true)~=nil,"workspace overflow owner installed")
	check(string.find(browser,REVISION,1,true)~=nil,"browser overflow owner installed")
	check(string.find(application,REVISION,1,true)~=nil,"navigation copy installed")
	check(string.find(shared,"EconomyCardHeight",1,true)~=nil and string.find(shared,"EconomyStackGap",1,true)~=nil,"economy cards use configurable stacked geometry")
	check(string.find(shared,"ui.Capacity.Position=UDim2.fromOffset(0,0)",1,true)~=nil,"spaces card is above cash")
	check(string.find(workspace,"function WorkspaceUI:UpdateCategoryArrows()",1,true)~=nil,"vertical category overflow controls exist")
	check(string.find(workspace,"AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X",1,true)~=nil,"workspace carousel uses actual rendered bounds")
	check(string.find(browser,"AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X",1,true)~=nil,"browser carousel uses actual rendered bounds")
	check(string.find(application,'DisplayName="Edit & Upgrade"',1,true)~=nil and string.find(application,'Text="Edit & Upgrade"',1,true)~=nil,"all canonical navigation cards say Edit & Upgrade")
	check(not string.find(application,'DisplayName="Customise Modules"',1,true) and not string.find(application,'Text="Customise Modules"',1,true),"old card copy removed from canonical application")
	check(typeof(config:GetAttribute("EconomyCardHeight"))=="number" and typeof(config:GetAttribute("CategoryArrowStep"))=="number" and typeof(config:GetAttribute("CarouselEndTolerance"))=="number","new presentation tuning attributes exist")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail))
	return fail==0
end

local installed=markerCount()
if MODE=="AUDIT" then assert(installed==4,"Expected all four revision markers; found "..tostring(installed)); assert(audit(),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
if installed==4 then assert(audit(),"Existing installation audit failed"); print(PREFIX.." ALREADY INSTALLED"); return end
assert(installed==0,"Partial prior installation detected ("..tostring(installed).."/4 markers). Refresh the mirror/live source before retrying.")

assert(string.find(originals.Workspace,"NTR_GARAGE_FLOW_REFINEMENT_V2_1",1,true),"Confirmed Workspace V2.1 baseline missing")
assert(string.find(originals.Application,"NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2",1,true),"Confirmed compact Customise rail V2.2 application baseline missing")
assert(string.find(originals.Browser,"NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1",1,true),"Confirmed Browser navigation baseline missing")
assert(string.find(originals.Shared,"NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1",1,true),"Confirmed shared garage-flow baseline missing")

local defaults={
	EconomyCardHeight=46,
	EconomyStackGap=10,
	CarouselEndTolerance=4,
	CategoryArrowStep=124,
	CategoryArrowWidth=46,
	CategoryArrowHeight=27,
	CategoryArrowGutter=36,
}
local oldAttributes={}
for name in pairs(defaults) do local value=config:GetAttribute(name); oldAttributes[name]={Had=value~=nil,Value=value} end

local shared=originals.Shared
shared=replaceOnce(shared,
	[[ui.Right.AnchorPoint=Vector2.new(1,0); ui.Right.Position=UDim2.fromOffset(vw-margin,28); ui.Right.Size=UDim2.fromOffset(N("StatsWidth",354),0); ui.Stats.LayoutOrder=1; ui.Economy.LayoutOrder=2; ui.Economy.Size=UDim2.new(1,0,0,N("EconomyHeight",46)); local rightLayout=ui.Right:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout"); rightLayout.Padding=UDim.new(0,gap); rightLayout.SortOrder=Enum.SortOrder.LayoutOrder; rightLayout.Parent=ui.Right
	ui.Cash.Position=UDim2.fromOffset(0,0); ui.Cash.Size=UDim2.new(.5,-gap*.5,1,0); ui.Capacity.AnchorPoint=Vector2.new(1,0); ui.Capacity.Position=UDim2.fromScale(1,0); ui.Capacity.Size=UDim2.new(.5,-gap*.5,1,0)]],
	[[local economyCardHeight=responsiveNumber(N,"EconomyCardHeight",N("EconomyHeight",46)); local economyStackGap=responsiveNumber(N,"EconomyStackGap",10)
	ui.Right.AnchorPoint=Vector2.new(1,0); ui.Right.Position=UDim2.fromOffset(vw-margin,28); ui.Right.Size=UDim2.fromOffset(N("StatsWidth",354),0); ui.Stats.LayoutOrder=1; ui.Economy.LayoutOrder=2; ui.Economy.Size=UDim2.new(1,0,0,economyCardHeight*2+economyStackGap); local rightLayout=ui.Right:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout"); rightLayout.Padding=UDim.new(0,gap); rightLayout.SortOrder=Enum.SortOrder.LayoutOrder; rightLayout.Parent=ui.Right
	ui.Capacity.AnchorPoint=Vector2.new(0,0); ui.Capacity.Position=UDim2.fromOffset(0,0); ui.Capacity.Size=UDim2.new(1,0,0,economyCardHeight); ui.Cash.AnchorPoint=Vector2.new(0,0); ui.Cash.Position=UDim2.fromOffset(0,economyCardHeight+economyStackGap); ui.Cash.Size=UDim2.new(1,0,0,economyCardHeight) -- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1]],
	"shared stacked economy geometry")
shared="-- "..REVISION.."\n"..shared

local workspace=originals.Workspace
workspace=replaceOnce(workspace,
	[[local function arrow(name,text) local b=Instance.new("TextButton"); b.Name=name; b.Text=text; b.AutoButtonColor=false; b.BackgroundColor3=Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)); b.BackgroundTransparency=.3; b.BorderSizePixel=0; b.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); b.TextSize=30; b.ZIndex=20; Racing.Font(b,"Heading"); Racing.Corner(b,5); b.Parent=self.Root; return b end
	self.Left=arrow("Previous","<"); self.RightArrow=arrow("Next",">")]],
	[[local function arrow(name,text,parent) local b=Instance.new("TextButton"); b.Name=name; b.Text=text; b.AutoButtonColor=false; b.BackgroundColor3=Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)); b.BackgroundTransparency=.3; b.BorderSizePixel=0; b.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); b.TextSize=30; b.ZIndex=20; Racing.Font(b,"Heading"); Racing.Corner(b,5); b.Parent=parent or self.Root; return b end
	self.Left=arrow("Previous","<"); self.RightArrow=arrow("Next",">")
	self.CategoryPrevious=arrow("CategoryPrevious","^",self.Categories); self.CategoryNext=arrow("CategoryNext","v",self.Categories); self.CategoryPrevious.TextSize=22; self.CategoryNext.TextSize=22; self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false -- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1]],
	"workspace overflow controls")
workspace=replaceOnce(workspace,
	[[self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end)
	self.Back.Activated:Connect(function() if self.Context and self.Context.OnBack then self.Context.OnBack() end end)
	self.Next.Activated:Connect(function() if self.Context and self.Context.OnNext then self.Context.OnNext() end end)
	self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end)
	self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:UpdateCarousel() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)]],
	[[self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end); self.CategoryPrevious.Activated:Connect(function() self:ScrollCategories(-1) end); self.CategoryNext.Activated:Connect(function() self:ScrollCategories(1) end)
	self.Back.Activated:Connect(function() if self.Context and self.Context.OnBack then self.Context.OnBack() end end)
	self.Next.Activated:Connect(function() if self.Context and self.Context.OnNext then self.Context.OnNext() end end)
	self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end)
	self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)
	self.CategoryList:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:UpdateCategoryArrows() end); self.CategoryList:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() self:UpdateCategoryArrows() end); self.CategoryList:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:UpdateCategoryArrows() end); self.CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCategoryUpdate() end)]],
	"workspace overflow event ownership")
workspace=replaceOnce(workspace,
	[[clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	self.Categories.BackgroundTransparency=context.LeftFloating and 1 or .12; local surface=self.Categories:FindFirstChild("SurfaceGradient"); if surface and surface:IsA("UIGradient") then surface.Enabled=not context.LeftFloating end; if self.CategoryLayout then self.CategoryLayout.HorizontalAlignment=context.LeftSharedCardSize and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left end
	if not self.Categories.Visible then return end]],
	[[clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false; self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false
	self.CategoryList.Position=UDim2.fromOffset(7,7); self.CategoryList.Size=UDim2.new(1,-14,1,-14); self.CategoryList.CanvasPosition=Vector2.zero; self.CategoryRailReserved=false
	self.Categories.BackgroundTransparency=context.LeftFloating and 1 or .12; local surface=self.Categories:FindFirstChild("SurfaceGradient"); if surface and surface:IsA("UIGradient") then surface.Enabled=not context.LeftFloating end; if self.CategoryLayout then self.CategoryLayout.HorizontalAlignment=context.LeftSharedCardSize and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left end
	if not self.Categories.Visible then return end]],
	"workspace category reset")
workspace=replaceOnce(workspace,
	[[		button.LayoutOrder=order; button.Activated:Connect(function() if item.OnSelect then item.OnSelect() end end)
	end
end
function WorkspaceUI:RenderEconomy(context)]],
	[[		button.LayoutOrder=order; button.Activated:Connect(function() if item.OnSelect then item.OnSelect() end end)
	end
	self:QueueCategoryUpdate()
end
function WorkspaceUI:RenderEconomy(context)]],
	"workspace category post-render update")

local categoryFunctions=[[
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
]]
workspace=replaceOnce(workspace,
	[[function WorkspaceUI:QueueCarouselUpdate()]],
	categoryFunctions..[[function WorkspaceUI:QueueCarouselUpdate()]],
	"workspace vertical overflow functions")

local workspaceCarousel=[[
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
]]
workspace=replaceBlock(workspace,"function WorkspaceUI:UpdateCarousel()","function WorkspaceUI:Scroll(direction)",workspaceCarousel,"workspace carousel bounds")
workspace=replaceOnce(workspace,
	[[function WorkspaceUI:Scroll(direction) self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*(N("WorkspaceCardWidth",210)+12),0,self.MaxScroll or 0),0); self:UpdateCarousel() end]],
	[[function WorkspaceUI:Scroll(direction) local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local step=(N("WorkspaceCardWidth",210)+12)*scale; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*step,0,self.MaxScroll or 0),0); self:RefreshCarouselArrows() end]],
	"workspace scaled carousel step")
workspace=replaceOnce(workspace,
	[[local combined=self.Cash.AbsoluteSize.X+self.Capacity.AbsoluteSize.X+N("Gap",14); expect(math.abs(combined-self.Stats.AbsoluteSize.X)<=3,"economy width does not match stats"); local rightEdge=]],
	[[expect(math.abs(self.Cash.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3 and math.abs(self.Capacity.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3,"stacked economy cards do not match stats width"); expect(self.Capacity.AbsolutePosition.Y+self.Capacity.AbsoluteSize.Y<=self.Cash.AbsolutePosition.Y+2,"spaces card is not above cash"); local rightEdge=]],
	"workspace stacked economy audit")
workspace=replaceOnce(workspace,
	[[local maxScroll=self.MaxScroll or 0; local x=self.Scroller.CanvasPosition.X; expect(self.Left.Visible==(self.Scroller.Visible and maxScroll>1 and x>1),"left arrow state mismatch"); expect(self.RightArrow.Visible==(self.Scroller.Visible and maxScroll>1 and x<maxScroll-1),"right arrow state mismatch")]],
	[[local maxScroll=self.MaxScroll or 0; local x=self.Scroller.CanvasPosition.X; local tolerance=math.max(2,N("CarouselEndTolerance",4)); expect(self.Left.Visible==(self.Scroller.Visible and maxScroll>tolerance and x>tolerance),"left arrow state mismatch"); expect(self.RightArrow.Visible==(self.Scroller.Visible and maxScroll>tolerance and x<maxScroll-tolerance),"right arrow state mismatch")]],
	"workspace endpoint audit")
workspace=replaceOnce(workspace,
	[[self.Budget.Visible=false; for _,parent in ipairs({self.CategoryList,self.Scroller,self.Paint,self.Stats,self.Cash,self.Capacity,self.Budget}) do clear(parent) end]],
	[[self.Budget.Visible=false; self.CategoryPrevious.Visible=false; self.CategoryNext.Visible=false; for _,parent in ipairs({self.CategoryList,self.Scroller,self.Paint,self.Stats,self.Cash,self.Capacity,self.Budget}) do clear(parent) end]],
	"workspace vertical arrows hide cleanup")
workspace="-- "..REVISION.."\n"..workspace

local browser=originals.Browser
browser=replaceOnce(browser,
	[[self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end); self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end); self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:UpdateCarousel() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)]],
	[[self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end); self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end); self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function() self:RefreshCarouselArrows() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)]],
	"browser overflow event ownership")
local browserCarousel=[[
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
]]
browser=replaceBlock(browser,"function Browser:UpdateCarousel()","function Browser:Scroll(direction)",browserCarousel,"browser carousel bounds")
browser=replaceOnce(browser,
	[[function Browser:Scroll(direction) local max=self.MaxScroll or 0; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*(N("CardWidth",226)+12),0,max),0); self:UpdateCarousel() end]],
	[[function Browser:Scroll(direction) local max=self.MaxScroll or 0; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local step=(N("CardWidth",226)+12)*scale; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*step,0,max),0); self:RefreshCarouselArrows() end]],
	"browser scaled carousel step")
browser=replaceOnce(browser,
	[[local combined=self.Cash.AbsoluteSize.X+self.Capacity.AbsoluteSize.X+N("Gap",14); expect(math.abs(combined-self.Stats.AbsoluteSize.X)<=3,"cash/capacity width does not match stats")]],
	[[expect(math.abs(self.Cash.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3 and math.abs(self.Capacity.AbsoluteSize.X-self.Stats.AbsoluteSize.X)<=3,"stacked economy cards do not match stats width"); expect(self.Capacity.AbsolutePosition.Y+self.Capacity.AbsoluteSize.Y<=self.Cash.AbsolutePosition.Y+2,"spaces card is not above cash")]],
	"browser stacked economy audit")
browser=replaceOnce(browser,
	[[local maxScroll=self.MaxScroll or 0; local scrollX=self.Scroller.CanvasPosition.X; expect(self.Left.Visible==(maxScroll>1 and scrollX>1),"left arrow visibility does not match overflow"); expect(self.RightArrow.Visible==(maxScroll>1 and scrollX<maxScroll-1),"right arrow visibility does not match overflow")]],
	[[local maxScroll=self.MaxScroll or 0; local scrollX=self.Scroller.CanvasPosition.X; local tolerance=math.max(2,N("CarouselEndTolerance",4)); expect(self.Left.Visible==(maxScroll>tolerance and scrollX>tolerance),"left arrow visibility does not match overflow"); expect(self.RightArrow.Visible==(maxScroll>tolerance and scrollX<maxScroll-tolerance),"right arrow visibility does not match overflow")]],
	"browser endpoint audit")
browser="-- "..REVISION.."\n"..browser

local application=originals.Application
application=replaceOnce(application,'DisplayName="Customise Modules"','DisplayName="Edit & Upgrade"',"hub Edit & Upgrade card copy")
application=replaceOnce(application,'Text="Customise Modules"','Text="Edit & Upgrade"',"sidebar Edit & Upgrade card copy")
application="-- "..REVISION.."\n"..application

compile("GarageReplacementComponents",shared)
compile("GarageWorkspaceController",workspace)
compile("GarageBrowserController",browser)
compile("ModuleShopUIController",application)
assert(#shared<199000 and #workspace<199000 and #browser<199000 and #application<199000,"Projected ModuleScript source exceeds Studio's safe Source limit")

local ok,err=pcall(function()
	for name,value in pairs(defaults) do if config:GetAttribute(name)==nil then config:SetAttribute(name,value) end end
	sharedModule.Source=shared
	workspaceModule.Source=workspace
	browserModule.Source=browser
	applicationModule.Source=application
	assert(audit(),"Post-install audit failed")
end)
if not ok then
	sharedModule.Source=originals.Shared; workspaceModule.Source=originals.Workspace; browserModule.Source=originals.Browser; applicationModule.Source=originals.Application
	for name,record in pairs(oldAttributes) do config:SetAttribute(name,record.Had and record.Value or nil) end
	error("Garage navigation/scroll/economy install rolled back: "..tostring(err))
end

print(PREFIX.." INSTALL COMPLETE")
print(PREFIX.." Restart Play and verify: Edit & Upgrade copy, mobile carousel endpoint arrows, vertical Customise rail arrows/final-card selection, and full-width Spaces-above-Cash cards on Browser and Workspace pages.")
