-- Neo Tokyo Racers - Shared garage presentation refinement
-- NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1
-- Run once in Roblox Studio EDIT mode from the Command Bar.

local MODE="INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Edit mode, not Play mode")
local REVISION="NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1"

local function need(parent,name,className)
	local object=parent:FindFirstChild(name); assert(object and object:IsA(className),"Missing "..parent:GetFullName().."."..name.." ("..className..")"); return object
end
local function compile(name,source) local fn,err=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(err)) end
local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true); assert(first,"Missing source anchor: "..label); assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label); return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end
local function replaceRange(source,firstMarker,nextMarker,replacement,label)
	local first=string.find(source,firstMarker,1,true); assert(first,"Missing source start anchor: "..label); assert(not string.find(source,firstMarker,first+#firstMarker,true),"Duplicate source start anchor: "..label)
	local nextAt=string.find(source,nextMarker,first+#firstMarker,true); assert(nextAt,"Missing source end anchor: "..label); return string.sub(source,1,first-1)..replacement..string.sub(source,nextAt)
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local replacementConfig=need(need(need(kit,"Config","Folder"),"UI","Folder"),"GarageReplacement","Folder")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local ui=need(need(clientRoot,"Controllers","Folder"),"UI","Folder")
local shared=need(ui,"GarageReplacementComponents","ModuleScript")
local workspace=need(ui,"GarageWorkspaceController","ModuleScript")
local application=need(ui,"ModuleShopUIController","ModuleScript")

assert(string.find(shared.Source,"NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1",1,true),"Shared garage component baseline missing")
assert(string.find(workspace.Source,"NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1",1,true),"Shared module-card forwarding baseline missing")
assert(string.find(application.Source,"NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1",1,true),"Shared module modal/name baseline missing")

local configDefaults={
	ModuleColourIcon="",ModuleCosmeticsIcon="",ModulePerformanceIcon="",ModuleNeonIcon="",
	HeaderTitleTextSize=20,HeaderSubtitleTextSize=14,PerformanceRatingTextSize=20,PerformanceHeadingTextSize=11,PerformanceStatNameTextSize=11,PerformanceStatValueTextSize=12,
	EconomyCashTextSize=17,EconomySpacesTextSize=13,CustomiseCategoryCardHeight=118,CustomiseCategoryImageHeight=78,BuildLeftPanelPadding=14,
}

local sharedSource=shared.Source
if not string.find(sharedSource,REVISION,1,true) then
	local renderPerformance=[==[
-- NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1
function M.RenderPerformance(parent,options)
	options=options or {}; local attribute=options.GeneratedAttribute or "GeneratedGarageUI"
	for _,child in ipairs(parent:GetChildren()) do if child:GetAttribute(attribute) then child:Destroy() end end
	local function generated(object) object:SetAttribute(attribute,true); return object end
	local performance=options.Performance
	if not performance then generated(Racing.Label(parent,{Text=options.EmptyText or "NO PERFORMANCE DATA",Size=UDim2.new(1,0,0,42),TextSize=options.StatNameTextSize or 11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"})); return end
	local overall=performance.Overall or {}; local tier=tostring(overall.Tier or "E"); local index=math.floor(tonumber(overall.PerformanceIndex) or 100); local tierColor=typeof(options.TierColor)=="function" and options.TierColor(tier) or Racing.Colour("PanelSoft")
	local header=generated(Instance.new("Frame")); header.Name="Rating"; header.LayoutOrder=1; header.BackgroundColor3=tierColor; header.BorderSizePixel=0; header.Size=UDim2.new(1,0,0,42); header.Parent=parent; Racing.Corner(header,4)
	Racing.Label(header,{Text=tier.."  "..index,Position=UDim2.fromOffset(8,0),Size=UDim2.new(.5,-8,1,0),TextSize=options.RatingTextSize or 20,Role="Metric"})
	Racing.Label(header,{Text="PERFORMANCE",Position=UDim2.fromScale(.5,0),Size=UDim2.new(.5,-8,1,0),TextSize=options.HeadingTextSize or 11,XAlignment=Enum.TextXAlignment.Right,Role="Heading"})
	local baseline=options.Baseline; local reference=tonumber(options.Reference) or 180
	for order,name in ipairs({"Speed","Acceleration","Handling","Drift","Braking","Boost"}) do
		local value=tonumber(performance.Headline and performance.Headline[name]) or 0; local baseValue=tonumber(baseline and baseline.Headline and baseline.Headline[name]); local delta=baseValue and (math.floor(value+.5)-math.floor(baseValue+.5)) or 0; local deltaText=delta==0 and "-" or ((delta>0 and "+" or "")..tostring(delta)); local deltaColor=delta>0 and Color3.fromRGB(89,255,102) or (delta<0 and Color3.fromRGB(255,105,116) or Racing.Colour("Text"))
		local stat=generated(Instance.new("Frame")); stat.Name=name; stat.LayoutOrder=order+1; stat.BackgroundTransparency=1; stat.Size=UDim2.new(1,0,0,38); stat.Parent=parent
		Racing.Label(stat,{Text=string.upper(name),Size=UDim2.new(.55,0,0,17),TextSize=options.StatNameTextSize or 11,Role="Heading"})
		Racing.Label(stat,{Text=tostring(math.floor(value+.5)),Position=UDim2.new(.55,0,0,0),Size=UDim2.new(.25,0,0,17),TextSize=options.StatValueTextSize or 12,XAlignment=Enum.TextXAlignment.Right,Role="Metric"})
		Racing.Label(stat,{Text=deltaText,Position=UDim2.new(.82,0,0,0),Size=UDim2.new(.18,0,0,17),TextSize=options.StatValueTextSize or 12,Color=deltaColor,XAlignment=Enum.TextXAlignment.Right,Role="Metric"})
		local track=Instance.new("Frame"); track.BackgroundColor3=Racing.Colour("PanelSoft"); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(0,22); track.Size=UDim2.new(1,0,0,9); track.Parent=stat; Racing.Corner(track,5)
		local fill=Instance.new("Frame"); fill.BackgroundColor3=Racing.Colour("Telemetry"); fill.BorderSizePixel=0; fill.Size=UDim2.fromScale(math.clamp(value/reference,0,1),1); fill.Parent=track; Racing.Corner(fill,5); local barGradient=Instance.new("UIGradient"); barGradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry")); barGradient.Parent=fill
	end
end
]==]
	sharedSource=replaceRange(sharedSource,"function M.RenderPerformance(parent,options)","-- NTR_GARAGE_SHARED_SHELL_V2",renderPerformance,"shared performance renderer")
end
compile("GarageReplacementComponents",sharedSource)

local workspaceSource=workspace.Source
if not string.find(workspaceSource,REVISION,1,true) then
	workspaceSource=replaceOnce(workspaceSource,
		[[self.Title=Racing.Label(self.Header,{Text="GARAGE",Position=UDim2.fromOffset(12,3),Size=UDim2.new(1,-24,0,28),TextSize=RN("MetricHeadingSize",15)+2,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"})]],
		[[self.Title=Racing.Label(self.Header,{Text="GARAGE",Position=UDim2.fromOffset(12,3),Size=UDim2.new(1,-24,0,28),TextSize=N("HeaderTitleTextSize",20),Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"}) -- NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1]],
		"larger shared garage header")
	workspaceSource=replaceOnce(workspaceSource,
		[[self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,29),TextSize=12,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Metric"})]],
		[[self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,29),TextSize=N("HeaderSubtitleTextSize",14),Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"})]],
		"larger shared garage description")

	local layoutAndLeft=[==[
function WorkspaceUI:Layout()
	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); local shell=Shared.LayoutGarageShell(self,{Number=N,Viewport=viewport,MinimumScale=minimum,Actions={self.Exit,self.Next,self.Back}})
	if self.Context and self.Categories.Visible then
		if self.Context.LeftFitContent then local count=#(self.Context.LeftItems or {}); local buttonHeight=N("CategoryButtonHeight",46); local height=N("BuildLeftPanelPadding",14)*2+12+count*buttonHeight+math.max(0,count-1)*8; self.Categories.Size=UDim2.fromOffset(self.Categories.Size.X.Offset,height) end
		if self.Context.LeftAlignCarouselBottom then local top=self.Categories.Position.Y.Offset; self.Categories.Size=UDim2.fromOffset(self.Categories.Size.X.Offset,math.max(170,shell.CarouselTop+N("CarouselHeight",166)-top)) end
	end
	self:QueueCarouselUpdate()
end

function WorkspaceUI:ResolveImage(key,explicit)
	if explicit and explicit~="" then return explicit end; return Artwork.ResolveImage(key)
end
function WorkspaceUI:ArtworkDefinitions(page) return Artwork.ForPage(page) end
function WorkspaceUI:RenderLeft(context)
	clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	if not self.Categories.Visible then return end
	for order,item in ipairs(context.LeftItems or {}) do
		local button
		if context.LeftCardMode then
			local cardHeight=context.LeftCardHeight or N("CustomiseCategoryCardHeight",118); local imageHeight=context.LeftCardImageHeight or N("CustomiseCategoryImageHeight",78)
			button=generated(Shared.ModuleCategoryCard(self.CategoryList,{DisplayName=item.Text or item.Id or "",Image=self:ResolveImage(item.ImageKey or item.Id,item.Image),Selected=item.Selected==true,Size=UDim2.new(1,0,0,cardHeight),ImageHeight=imageHeight,ImageZoom=item.ImageZoom or 1.04}))
		else button=generated(Racing.Button(self.CategoryList,{Text=string.upper(item.Text or item.Id or ""),Size=UDim2.new(1,0,0,N("CategoryButtonHeight",46)),Color=item.Selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})) end
		button.LayoutOrder=order; button.Activated:Connect(function() if item.OnSelect then item.OnSelect() end end)
	end
end
function WorkspaceUI:RenderEconomy(context)
	clear(self.Cash); clear(self.Capacity)
	generated(Racing.Label(self.Cash,{Text="$"..tostring(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=N("EconomyCashTextSize",17),Color=Color3.fromRGB(89,255,102),Role="Heading"})); local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if context.OnCash then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity
	generated(Racing.Label(self.Capacity,{Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=N("EconomySpacesTextSize",13),Role="Heading"})); local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if context.OnCapacity then context.OnCapacity() end end)
end
]==]
	workspaceSource=replaceRange(workspaceSource,"function WorkspaceUI:Layout()","function WorkspaceUI:DrawPerformance",layoutAndLeft,"shared shell left rail and economy")
	workspaceSource=replaceOnce(workspaceSource,
		[[function WorkspaceUI:DrawPerformance(parent,performance,baseline,tierColor) Shared.RenderPerformance(parent,{Performance=performance,Baseline=baseline,TierColor=tierColor,Reference=N("StatReference",180),GeneratedAttribute="GeneratedGarageWorkspace"}) end]],
		[[function WorkspaceUI:DrawPerformance(parent,performance,baseline,tierColor) Shared.RenderPerformance(parent,{Performance=performance,Baseline=baseline,TierColor=tierColor,Reference=N("StatReference",180),GeneratedAttribute="GeneratedGarageWorkspace",RatingTextSize=N("PerformanceRatingTextSize",20),HeadingTextSize=N("PerformanceHeadingTextSize",11),StatNameTextSize=N("PerformanceStatNameTextSize",11),StatValueTextSize=N("PerformanceStatValueTextSize",12)}) end]],
		"shared performance typography forwarding")

	local paintRenderer=[==[
function WorkspaceUI:RenderPaint(context)
	self.Popup:Hide(); self.Scroller.Visible=false; self.Paint.Visible=true; clear(self.Paint); local channels=context.ColorChannels or {}; local selected=context.SelectedChannel or channels[1]; if not selected then return end
	local current=(context.Colors and context.Colors[selected]) or Color3.new(1,1,1); local h,s,v=Color3.toHSV(current); self.PaintHSV={h,s,v}; self.PaintChannel=selected
	local width=math.min(N("WorkspacePaintWidth",720),self.ReferenceCarouselWidth or 720); local panel=generated(Shared.Panel(self.Paint,"PaintControls",{StrokeColor=Racing.Colour("ElectricBlue"),StrokeTransparency=.35,NoGlow=true})); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(width,142)
	local tabWidth=math.max(96,(width-16-math.max(0,#channels-1)*8)/math.max(1,#channels)); for index,channel in ipairs(channels) do local b=generated(Racing.Button(panel,{Text=string.upper(channel),Position=UDim2.fromOffset(8+(index-1)*(tabWidth+8),7),Size=UDim2.fromOffset(tabWidth,30),Color=channel==selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); b.Activated:Connect(function() context.OnChannel(channel) end) end
	local gradients={}
	local function refreshGradients()
		if gradients[1] then gradients[1].Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.17,Color3.fromHSV(.17,1,1)),ColorSequenceKeypoint.new(.33,Color3.fromHSV(.33,1,1)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(.5,1,1)),ColorSequenceKeypoint.new(.67,Color3.fromHSV(.67,1,1)),ColorSequenceKeypoint.new(.83,Color3.fromHSV(.83,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))}) end
		if gradients[2] then gradients[2].Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromHSV(self.PaintHSV[1],1,1)) end
		if gradients[3] then gradients[3].Color=ColorSequence.new(Color3.new(0,0,0),Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],1)) end
	end
	local function emit(commit) if context.OnColor then context.OnColor(selected,Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],self.PaintHSV[3]),commit==true) end end
	local function slider(labelText,index,y)
		generated(Racing.Label(panel,{Text=labelText,Position=UDim2.fromOffset(10,y-7),Size=UDim2.fromOffset(24,24),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}))
		local track=generated(Instance.new("Frame")); track.Active=true; track.BackgroundColor3=Color3.new(1,1,1); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(42,y); track.Size=UDim2.new(1,-58,0,10); track.Parent=panel; Racing.Corner(track,5)
		local g=Instance.new("UIGradient"); g.Parent=track; gradients[index]=g
		local knob=generated(Instance.new("Frame")); knob.AnchorPoint=Vector2.new(.5,.5); knob.Position=UDim2.fromScale(self.PaintHSV[index],.5); knob.Size=UDim2.fromOffset(5,18); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=8; knob.Parent=track; Racing.Corner(knob,3)
		local function update(input) local x=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); self.PaintHSV[index]=x; knob.Position=UDim2.fromScale(x,.5); refreshGradients(); emit(false) end
		table.insert(self.Dynamic,track.InputBegan:Connect(function(input) if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; update(input); local move,endConnection; move=UserInputService.InputChanged:Connect(function(changed) if changed.UserInputType==Enum.UserInputType.MouseMovement or changed.UserInputType==Enum.UserInputType.Touch then update(changed) end end); endConnection=UserInputService.InputEnded:Connect(function(ended) if ended.UserInputType==input.UserInputType then move:Disconnect(); endConnection:Disconnect(); emit(true) end end) end))
	end
	slider("H",1,55); slider("S",2,86); slider("B",3,117); refreshGradients()
end
]==]
	workspaceSource=replaceRange(workspaceSource,"function WorkspaceUI:RenderPaint(context)","function WorkspaceUI:QueueCarouselUpdate",paintRenderer,"bright dynamic colour sliders")
end
compile("GarageWorkspaceController",workspaceSource)

local applicationSource=application.Source
if not string.find(applicationSource,REVISION,1,true) then
	applicationSource=replaceOnce(applicationSource,
		[[State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or "Preview, then buy or equip."; c.NextText="Customise"; c.ShowLeft=State.ModuleMode~="Slots"; c.LeftItems={}; c.Cards={}]],
		[[State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or "Preview, then buy or equip."; c.NextText="Customise"; c.ShowLeft=State.ModuleMode~="Slots"; c.LeftFitContent=State.ModuleMode~="Slots"; c.LeftItems={}; c.Cards={} -- NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1]],
		"content-fitted Build navigation")

	local customiseRenderer=[==[
renderCustomise=function()
	State.Stage="Customise"; local target=State.CustomizeTarget; local c=common("Customise"); c.Subtitle="Tune installed modules, change colours, or unlock lights."; c.NextText="Start Driving"; c.LeftCardMode=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78; c.LeftItems={}; c.Cards={}
	for _,art in ipairs(workspaceUI:ArtworkDefinitions("Customise")) do
		local id=art.TargetId
		if id=="ALL" or id=="Cockpit" or id=="THRUST_COLOR" or installedForSlot(id) then
			table.insert(c.LeftItems,{Id=id,Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,Image=art.Image,Selected=target==id,OnSelect=function() State.CustomizeTarget=id; State.CustomizeMode=(id=="ALL" or id=="THRUST_COLOR") and "Colour" or "Overview"; if id~="ALL" and id~="Cockpit" and id~="THRUST_COLOR" then section(id) end; renderCustomise() end})
		end
	end
	if target=="ALL" or target=="THRUST_COLOR" or State.CustomizeMode=="Colour" then
		local channels=colourChannels(target); local colours={}
		for _,ch in ipairs(channels) do if target=="THRUST_COLOR" then colours[ch]=State.Profile.ThrustColor elseif target=="Cockpit" or target=="ALL" then colours[ch]=(State.Profile.CockpitColors or {})[ch] else colours[ch]=((State.Profile.ModuleColors or {})[target] or {})[ch] end; colours[ch]=colours[ch] or Color3.new(1,1,1) end
		c.ColorChannels=channels; c.SelectedChannel=State.SelectedColorChannel or channels[1]; c.Colors=colours; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderCustomise() end; c.OnColor=function(ch,color,commit) handlePaint(target,ch,color,commit) end
	elseif State.CustomizeMode=="Cosmetics" then
		local id=installedForSlot(target); local owned=State.Profile.NeonOwned and State.Profile.NeonOwned[target]
		table.insert(c.Cards,{Id="Neon",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),DisplayName="Neon Lights",Badge=owned and "OWNED" or "$5000",BadgeColor=owned and tierColor("S") or tierColor("A"),Selected=State.PreviewNeonSlot==target,ActionText=not owned and State.PreviewNeonSlot==target and "BUY" or nil,OnSelect=function() State.PreviewNeonSlot=target; buildPreview(); renderCustomise() end,OnAction=function() local r=action:Call("BuyNeon",{SlotId=target}); State.PreviewNeonSlot=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})
	elseif State.CustomizeMode=="Upgrades" then
		local moduleId,m=installedModule(); local upgrades=(m and m.Upgrades) or {}; local variant=ModuleCards.Variant(m)
		if #upgrades==0 then c.EmptyMessage=variant=="Standard" and "STANDARD MODULES CANNOT BE UPGRADED" or "UPGRADE DATA UNAVAILABLE FOR THIS MODULE"; if variant~="Standard" then warn("[NTR Garage Upgrades] Missing catalogue paths for "..tostring(moduleId)) end end
		for _,u in ipairs(upgrades) do
			local level=math.floor(tonumber(((State.Profile.ModuleUpgradeLevels or {})[moduleId] or {})[u.UpgradeId]) or 0); local max=tonumber(u.MaxLevel) or 3; local price=math.floor((tonumber(u.BasePrice) or 0)*((tonumber(u.PriceMultiplier) or 1)^level)); local selected=State.PreviewUpgradeId==u.UpgradeId
			table.insert(c.Cards,{Id=u.UpgradeId,Image=imageValue(replacementConfig:GetAttribute("ModulePerformanceIcon")),DisplayName=u.DisplayName or u.UpgradeId,Badge="LVL "..level.."/"..max,BadgeColor=level>=max and tierColor("S") or tierColor("A"),Selected=selected,ActionText=selected and level<max and ("BUY $"..price) or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderCustomise() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})
		end
	else
		table.insert(c.Cards,{Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),DisplayName=target=="Cockpit" and "Change Colour" or "Colour",OnSelect=function() State.CustomizeMode="Colour"; renderCustomise() end})
		if target~="Cockpit" then
			table.insert(c.Cards,{Id="Cosmetics",Image=imageValue(replacementConfig:GetAttribute("ModuleCosmeticsIcon")),DisplayName="Cosmetics",OnSelect=function() State.CustomizeMode="Cosmetics"; renderCustomise() end})
			table.insert(c.Cards,{Id="Performance",Image=imageValue(replacementConfig:GetAttribute("ModulePerformanceIcon")),DisplayName="Performance",OnSelect=function() State.CustomizeMode="Upgrades"; renderCustomise() end})
		end
	end
	c.OnBack=function() if State.CustomizeMode~="Overview" and target~="ALL" then State.CustomizeMode="Overview"; renderCustomise() else State.ModuleMode="Slots"; renderBuild() end end
	c.OnNext=function() action:Session("End",{ReturnToEntry=false}); local r=action:Call("SpawnVehicle",{}); if not r.Success then message(r.Message); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end end
	buildPreview(); workspaceUI:Show(c)
end
]==]
	applicationSource=replaceRange(applicationSource,"renderCustomise=function()","local function open(mode)",customiseRenderer,"canonical Customise presentation")
end
compile("ModuleShopUIController",applicationSource)

local failures={}; local function expect(ok,message) if not ok then table.insert(failures,message) end end
expect(string.find(workspaceSource,"ColorSequence.new(Color3.new(1,1,1),Color3.fromHSV(self.PaintHSV[1],1,1))",1,true)~=nil,"bright saturation gradient missing")
expect(string.find(workspaceSource,"LeftFitContent",1,true)~=nil,"content-fitted Build panel missing")
expect(string.find(workspaceSource,"LeftAlignCarouselBottom",1,true)~=nil,"Customise rail alignment missing")
expect(string.find(sharedSource,"options.StatNameTextSize",1,true)~=nil,"shared performance typography missing")
expect(string.find(applicationSource,"ModuleColourIcon",1,true)~=nil and string.find(applicationSource,"ModuleCosmeticsIcon",1,true)~=nil and string.find(applicationSource,"ModulePerformanceIcon",1,true)~=nil and string.find(applicationSource,"ModuleNeonIcon",1,true)~=nil,"configurable Customise icons missing")
expect(string.find(applicationSource,"STANDARD MODULES CANNOT BE UPGRADED",1,true)~=nil,"explicit Standard upgrade state missing")
if #failures>0 then error("[NTR Garage Presentation Refinement] AUDIT FAIL: "..table.concat(failures," | "),0) end
print("[NTR Garage Presentation Refinement] PREFLIGHT PASS")
if MODE=="AUDIT" then return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local oldSharedSource=shared.Source; local oldWorkspaceSource=workspace.Source; local oldApplicationSource=application.Source; local oldAttributes={}
for name in pairs(configDefaults) do oldAttributes[name]={Present=replacementConfig:GetAttribute(name)~=nil,Value=replacementConfig:GetAttribute(name)} end
local ok,err=xpcall(function()
	for name,value in pairs(configDefaults) do if replacementConfig:GetAttribute(name)==nil then replacementConfig:SetAttribute(name,value) end end
	shared.Source=sharedSource; workspace.Source=workspaceSource; application.Source=applicationSource
	assert(shared.Source==sharedSource and workspace.Source==workspaceSource and application.Source==applicationSource,"Source readback mismatch")
	print("[NTR Garage Presentation Refinement] INSTALL PASS")
	print("Restart Play. Verify bright H/S/B sliders, compact Build navigation, full-height shorter Customise cards, larger header/stats/economy text, icon attribute slots, Standard non-upgradeable messaging, and Lightweight/Power upgrade cards.")
end,debug.traceback)
if not ok then
	pcall(function() shared.Source=oldSharedSource end); pcall(function() workspace.Source=oldWorkspaceSource end); pcall(function() application.Source=oldApplicationSource end)
	for name,state in pairs(oldAttributes) do pcall(function() replacementConfig:SetAttribute(name,state.Present and state.Value or nil) end) end
	error("[NTR Garage Presentation Refinement] INSTALL ABORTED and rolled back: "..tostring(err),0)
end
