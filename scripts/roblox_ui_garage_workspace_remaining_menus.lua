-- Neo Tokyo Racers - Canonical Garage Workspace: paint, build modules and module customisation
-- Run in Roblox Studio Edit mode after the confirmed Garage Replacement Browser V1.4 installer.
-- NTR_GARAGE_WORKSPACE_REMAINING_MENUS_V3_1

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local function replaceRange(text, first, last, replacement, label)
	local a = assert(string.find(text, first, 1, true), label .. " start missing")
	local b = assert(string.find(text, last, a, true), label .. " end missing")
	return string.sub(text, 1, a - 1) .. replacement .. string.sub(text, b)
end
local function replaceOnce(text, old, new, label)
	assert(countPlain(text, old) == 1, label .. " anchor count changed")
	local a, b = string.find(text, old, 1, true)
	return string.sub(text, 1, a - 1) .. new .. string.sub(text, b + 1)
end
local function replaceAllPlain(text, old, new, label)
	local count = countPlain(text, old)
	assert(count > 0, label .. " anchor missing")
	local cursor = 1
	while true do
		local a, b = string.find(text, old, cursor, true)
		if not a then break end
		text = string.sub(text, 1, a - 1) .. new .. string.sub(text, b + 1)
		cursor = a + #new
	end
	return text, count
end
local function value(parent, className, name, default)
	local object = ensure(parent, className, name)
	if object.Value == (className == "StringValue" and "" or 0) then object.Value = default end
	return object
end
local function defaultAttribute(object, name, value)
	if object:GetAttribute(name) == nil then object:SetAttribute(name, value) end
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local clientRoot = need(StarterPlayer.StarterPlayerScripts, "NeoTokyoRacersClient", "Folder")
local uiControllers = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local bootstrap = need(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript")
assert(string.find(bootstrap.Source, "NTR_GARAGE_REPLACEMENT_BROWSER_BRIDGE_V1", 1, true), "Install/refresh the confirmed browser V1.4 first")
local components = need(uiControllers, "GarageReplacementComponents", "ModuleScript")
local browserController = need(uiControllers, "GarageBrowserController", "ModuleScript")
local propertyController = need(uiControllers, "GaragePropertyMenuController", "ModuleScript")

local config = ensure(ensure(ensure(kit, "Folder", "Config"), "Folder", "UI"), "Folder", "GarageReplacement")
value(config, "NumberValue", "WorkspaceCardWidth", 210)
value(config, "NumberValue", "WorkspaceCardHeight", 146)
value(config, "NumberValue", "WorkspacePaintWidth", 720)
local artwork = ensure(config, "Folder", "ModuleArtwork")
local legacyArtwork = {}
for _, object in ipairs(artwork:GetChildren()) do
	if object:IsA("StringValue") then legacyArtwork[object.Name] = object.Value end
end
local artworkDefinitions = {
	{Name="All", DisplayName="All", TargetId="ALL", SortOrder=10, ShowInBuild=false, ShowInCustomise=true, LegacyKeys={"ALL","Default"}},
	{Name="Cockpit", DisplayName="Cockpit", TargetId="Cockpit", SortOrder=20, ShowInBuild=false, ShowInCustomise=true, LegacyKeys={"Cockpit"}},
	{Name="ThrustColour", DisplayName="Thrust Colour", TargetId="THRUST_COLOR", SortOrder=30, ShowInBuild=false, ShowInCustomise=true, LegacyKeys={"THRUST_COLOR"}},
	{Name="FrontEngine", DisplayName="Front Engine", TargetId="Engine1", SortOrder=40, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"Engine1"}},
	{Name="RearEngine", DisplayName="Rear Engine", TargetId="Engine2", SortOrder=50, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"Engine2"}},
	{Name="Stabilisers", DisplayName="Stabilisers", TargetId="Stabilisers", SortOrder=60, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"Stabilisers"}},
	{Name="Boost", DisplayName="Boost", TargetId="Boost", SortOrder=70, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"Boost"}},
	{Name="FrontBumper", DisplayName="Front Bumper", TargetId="BumperFront", SortOrder=80, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"BumperFront"}},
	{Name="RearBumper", DisplayName="Rear Bumper", TargetId="BumperRear", SortOrder=90, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"BumperRear"}},
	{Name="SidePods", DisplayName="Side Pods", TargetId="SidePods", SortOrder=100, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"SidePods"}},
	{Name="Spoiler", DisplayName="Spoiler", TargetId="Spoiler", SortOrder=110, ShowInBuild=true, ShowInCustomise=true, LegacyKeys={"Spoiler"}},
}
local approvedArtworkFolders = {}
for _, definition in ipairs(artworkDefinitions) do approvedArtworkFolders[definition.Name] = true end
local function installArtworkSchema()
	local replaceRoot = false
	for _, object in ipairs(artwork:GetChildren()) do
		if not (object:IsA("Folder") and approvedArtworkFolders[object.Name]) or #object:GetChildren() > 0 then replaceRoot = true; break end
	end
	if replaceRoot then
		-- Detach the obsolete value-object tree as one unit. Do not Destroy its children:
		-- Studio mirror/import listeners may hold references and attempt to re-parent
		-- destroyed instances, producing a locked-Parent warning for every old value.
		local retired = artwork
		retired.Name = "ModuleArtwork_RetiredDuringInstall"
		retired.Parent = nil
		artwork = Instance.new("Folder")
		artwork.Name = "ModuleArtwork"
		artwork.Parent = config
	end
	for _, definition in ipairs(artworkDefinitions) do
		local folder = ensure(artwork, "Folder", definition.Name)
		local migratedImage = ""
		for _, key in ipairs(definition.LegacyKeys) do if legacyArtwork[key] and legacyArtwork[key] ~= "" then migratedImage = legacyArtwork[key]; break end end
		defaultAttribute(folder, "Image", migratedImage)
		defaultAttribute(folder, "DisplayName", definition.DisplayName)
		defaultAttribute(folder, "TargetId", definition.TargetId)
		defaultAttribute(folder, "SortOrder", definition.SortOrder)
		defaultAttribute(folder, "ShowInBuild", definition.ShowInBuild)
		defaultAttribute(folder, "ShowInCustomise", definition.ShowInCustomise)
	end
end
local function auditArtworkSchema()
	assert(#artwork:GetChildren() == #artworkDefinitions, "ModuleArtwork category count changed")
	for _, definition in ipairs(artworkDefinitions) do
		local folder = artwork:FindFirstChild(definition.Name)
		assert(folder and folder:IsA("Folder"), "Missing ModuleArtwork category folder: " .. definition.Name)
		assert(#folder:GetChildren() == 0, "ModuleArtwork category must contain attributes only: " .. definition.Name)
		assert(tostring(folder:GetAttribute("TargetId") or "") == definition.TargetId, "ModuleArtwork TargetId mismatch: " .. definition.Name)
	end
end
local categoriesRoot = need(need(need(kit, "Assets", "Folder"), "Vehicles", "Folder"), "Categories", "Folder")

local artworkRegistrySource = [==[
-- NTR_GARAGE_MODULE_ARTWORK_ATTRIBUTE_REGISTRY_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local root=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement"):WaitForChild("ModuleArtwork")
local Registry={}
local function definition(folder)
	return {Folder=folder,Name=folder.Name,Image=tostring(folder:GetAttribute("Image") or ""),DisplayName=tostring(folder:GetAttribute("DisplayName") or folder.Name),TargetId=tostring(folder:GetAttribute("TargetId") or folder.Name),SortOrder=tonumber(folder:GetAttribute("SortOrder")) or 0,ShowInBuild=folder:GetAttribute("ShowInBuild")==true,ShowInCustomise=folder:GetAttribute("ShowInCustomise")==true}
end
function Registry.All()
	local result={}
	for _,folder in ipairs(root:GetChildren()) do if folder:IsA("Folder") then table.insert(result,definition(folder)) end end
	table.sort(result,function(a,b) if a.SortOrder~=b.SortOrder then return a.SortOrder<b.SortOrder end; return a.Name<b.Name end)
	return result
end
function Registry.ForPage(page)
	local result={}; local attribute=page=="Build" and "ShowInBuild" or "ShowInCustomise"
	for _,item in ipairs(Registry.All()) do if item[attribute]==true then table.insert(result,item) end end
	return result
end
function Registry.Find(key)
	key=tostring(key or "")
	for _,item in ipairs(Registry.All()) do if item.Name==key or item.TargetId==key then return item end end
	return nil
end
function Registry.ResolveImage(key)
	local item=Registry.Find(key); return item and item.Image or ""
end
function Registry.Audit()
	local failures={}; local targetIds={}
	for _,object in ipairs(root:GetChildren()) do
		if not object:IsA("Folder") then table.insert(failures,object.Name.." is not a Folder")
		elseif #object:GetChildren()>0 then table.insert(failures,object.Name.." has child instances")
		else local item=definition(object); if item.TargetId=="" then table.insert(failures,object.Name.." has no TargetId") elseif targetIds[item.TargetId] then table.insert(failures,"duplicate TargetId "..item.TargetId) else targetIds[item.TargetId]=true end end
	end
	return #failures==0,failures
end
return Registry
]==]

local controllerSource = [==[
-- NTR_GARAGE_WORKSPACE_CONTROLLER_V3
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Racing=require(kit.Shared.Modules.UI.RacingUIComponents)
local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents"))
local Artwork=require(script.Parent:WaitForChild("GarageModuleArtworkRegistry"))
local cfg=kit.Config.UI:WaitForChild("GarageReplacement")
local desktop=kit.Config.UI:WaitForChild("DesktopFreeRoamHud")
local inRace=kit.Config.UI.Racing:WaitForChild("InRace")
local function N(name,fallback) local v=cfg:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function RN(name,fallback) local v=inRace:FindFirstChild(name); return tonumber(v and v.Value) or fallback end
local function asset(name) local f=desktop:FindFirstChild("Assets"); local v=f and f:FindFirstChild(name); return v and v.Value or "" end
local function generated(o) o:SetAttribute("GeneratedGarageWorkspace",true); return o end
local function clear(parent) for _,o in ipairs(parent:GetChildren()) do if o:GetAttribute("GeneratedGarageWorkspace") then o:Destroy() end end end
local WorkspaceUI={}; WorkspaceUI.__index=WorkspaceUI

function WorkspaceUI.new()
	local self=setmetatable({},WorkspaceUI); self.Host=Shared.CanonicalHost(); self.Gui=self.Host.Gui; self.Scale=self.Host.Scale; self.Context=nil; self.Dynamic={}
	self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageWorkspace"; self.Root.BackgroundTransparency=1; self.Root.BorderSizePixel=0; self.Root.Visible=false; self.Root.Parent=self.Host.Canvas
	self.Header=Shared.MetricCard(self.Root,"Header")
	self.Title=Racing.Label(self.Header,{Text="GARAGE",Position=UDim2.fromOffset(12,3),Size=UDim2.new(1,-24,0,28),TextSize=RN("MetricHeadingSize",15)+2,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"})
	self.Subtitle=Racing.Label(self.Header,{Text="",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,29),TextSize=12,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Metric"})
	self.Categories=Shared.Panel(self.Root,"Categories",{NoStroke=true})
	self.CategoryList=Instance.new("ScrollingFrame"); self.CategoryList.BackgroundTransparency=1; self.CategoryList.BorderSizePixel=0; self.CategoryList.ScrollBarThickness=0; self.CategoryList.AutomaticCanvasSize=Enum.AutomaticSize.Y; self.CategoryList.CanvasSize=UDim2.fromOffset(0,0); self.CategoryList.Position=UDim2.fromOffset(7,7); self.CategoryList.Size=UDim2.new(1,-14,1,-14); self.CategoryList.Parent=self.Categories
	local categoryLayout=Instance.new("UIListLayout"); categoryLayout.Padding=UDim.new(0,8); categoryLayout.Parent=self.CategoryList
	local categoryPad=Instance.new("UIPadding"); categoryPad.PaddingTop=UDim.new(0,6); categoryPad.PaddingBottom=UDim.new(0,6); categoryPad.PaddingLeft=UDim.new(0,6); categoryPad.PaddingRight=UDim.new(0,6); categoryPad.Parent=self.CategoryList
	self.Right=Instance.new("Frame"); self.Right.BackgroundTransparency=1; self.Right.Parent=self.Root
	self.Right.AutomaticSize=Enum.AutomaticSize.Y
	self.Stats=Shared.Panel(self.Right,"Stats",{NoStroke=true}); self.Stats.AutomaticSize=Enum.AutomaticSize.Y; self.Stats.Size=UDim2.new(1,0,0,0); local statsPad=Instance.new("UIPadding"); statsPad.PaddingTop=UDim.new(0,10); statsPad.PaddingBottom=UDim.new(0,10); statsPad.PaddingLeft=UDim.new(0,12); statsPad.PaddingRight=UDim.new(0,12); statsPad.Parent=self.Stats; local statsLayout=Instance.new("UIListLayout"); statsLayout.Padding=UDim.new(0,5); statsLayout.SortOrder=Enum.SortOrder.LayoutOrder; statsLayout.Parent=self.Stats
	self.Economy=Instance.new("Frame"); self.Economy.BackgroundTransparency=1; self.Economy.Parent=self.Right
	local outline=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)); self.Cash=Shared.Panel(self.Economy,"Cash",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true}); self.Capacity=Shared.Panel(self.Economy,"Capacity",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true})
	self.Carousel=Instance.new("Frame"); self.Carousel.BackgroundTransparency=1; self.Carousel.Parent=self.Root
	self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.BackgroundTransparency=1; self.Scroller.BorderSizePixel=0; self.Scroller.ScrollBarThickness=0; self.Scroller.CanvasSize=UDim2.fromOffset(0,0); self.Scroller.ScrollingDirection=Enum.ScrollingDirection.X; self.Scroller.ClipsDescendants=true; self.Scroller.Size=UDim2.fromScale(1,1); self.Scroller.Parent=self.Carousel
	self.CardLayout=Instance.new("UIListLayout"); self.CardLayout.FillDirection=Enum.FillDirection.Horizontal; self.CardLayout.VerticalAlignment=Enum.VerticalAlignment.Center; self.CardLayout.Padding=UDim.new(0,12); self.CardLayout.Parent=self.Scroller
	self.CardPad=Instance.new("UIPadding"); self.CardPad.PaddingLeft=UDim.new(0,6); self.CardPad.PaddingRight=UDim.new(0,6); self.CardPad.Parent=self.Scroller
	self.Paint=Instance.new("Frame"); self.Paint.BackgroundTransparency=1; self.Paint.Visible=false; self.Paint.Parent=self.Carousel
	local function arrow(name,text) local b=Instance.new("TextButton"); b.Name=name; b.Text=text; b.AutoButtonColor=false; b.BackgroundColor3=Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)); b.BackgroundTransparency=.3; b.BorderSizePixel=0; b.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); b.TextSize=30; b.ZIndex=20; Racing.Font(b,"Heading"); Racing.Corner(b,5); b.Parent=self.Root; return b end
	self.Left=arrow("Previous","<"); self.RightArrow=arrow("Next",">")
	self.Back=Racing.Button(self.Root,{Name="Back",Text="BACK",Size=UDim2.fromOffset(88,30),Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})
	self.Next=Racing.Button(self.Root,{Name="Continue",Text="NEXT",Size=UDim2.fromOffset(154,30),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=outline})
	self.Exit=Racing.Button(self.Root,{Name="Exit",Text="EXIT",Size=UDim2.fromOffset(76,30),Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})
	self.Popup=Shared.Popup(self.Root)
	self.Left.Activated:Connect(function() self:Scroll(-1) end); self.RightArrow.Activated:Connect(function() self:Scroll(1) end)
	self.Back.Activated:Connect(function() if self.Context and self.Context.OnBack then self.Context.OnBack() end end)
	self.Next.Activated:Connect(function() if self.Context and self.Context.OnNext then self.Context.OnNext() end end)
	self.Exit.Activated:Connect(function() if self.Context and self.Context.OnExit then self.Context.OnExit() end end)
	self.Scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:UpdateCarousel() end); self.Scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:QueueCarouselUpdate() end); self.CardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:QueueCarouselUpdate() end)
	local camera=Workspace.CurrentCamera; if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if self.Root.Visible then self:Layout() end end) end
	return self
end

function WorkspaceUI:DisconnectDynamic() for _,connection in ipairs(self.Dynamic) do connection:Disconnect() end; table.clear(self.Dynamic) end
function WorkspaceUI:Message(text) self.Subtitle.Text=tostring(text or "") end
function WorkspaceUI:Layout()
	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); Shared.LayoutGarageShell(self,{Number=N,Viewport=viewport,MinimumScale=minimum,Actions={self.Exit,self.Next,self.Back}})
	self:QueueCarouselUpdate()
end

function WorkspaceUI:ResolveImage(key,explicit)
	if explicit and explicit~="" then return explicit end; return Artwork.ResolveImage(key)
end
function WorkspaceUI:ArtworkDefinitions(page) return Artwork.ForPage(page) end
function WorkspaceUI:RenderLeft(context)
	clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	if not self.Categories.Visible then return end
	for order,item in ipairs(context.LeftItems or {}) do local b=generated(Racing.Button(self.CategoryList,{Text=string.upper(item.Text or item.Id or ""),Size=UDim2.new(1,0,0,N("CategoryButtonHeight",46)),Color=item.Selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); b.LayoutOrder=order; b.Activated:Connect(function() if item.OnSelect then item.OnSelect() end end) end
end
function WorkspaceUI:RenderEconomy(context)
	clear(self.Cash); clear(self.Capacity)
	generated(Racing.Label(self.Cash,{Text="$"..tostring(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=15,Color=Color3.fromRGB(89,255,102)})); local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if context.OnCash then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity; generated(Racing.Label(self.Capacity,{Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=11})); local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if context.OnCapacity then context.OnCapacity() end end)
end
function WorkspaceUI:DrawPerformance(parent,performance,baseline,tierColor) Shared.RenderPerformance(parent,{Performance=performance,Baseline=baseline,TierColor=tierColor,Reference=N("StatReference",180),GeneratedAttribute="GeneratedGarageWorkspace"}) end
function WorkspaceUI:RenderStats(context) clear(self.Stats); if context.RenderStats then context.RenderStats(self.Stats) else self:DrawPerformance(self.Stats,context.Performance,context.BaselinePerformance,context.TierColor) end end
function WorkspaceUI:RenderCards(context)
	self.Paint.Visible=false; self.Scroller.Visible=true; clear(self.Scroller); self.Popup:Hide(); local selectedCard
	for order,row in ipairs(context.Cards or {}) do local selected=row.Selected==true; local card=generated(Shared.ModuleCard(self.Scroller,{DisplayName=row.DisplayName or row.Id or "",Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Selected=selected,Size=UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or 1.04})); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end); if selected then selectedCard=card; if row.ActionText and row.OnAction then self.Popup:Set(card,row.ActionText,row.OnAction,self.Scale) end end end
	if context.EmptyMessage and #(context.Cards or {})==0 then local empty=generated(Racing.Label(self.Scroller,{Text=context.EmptyMessage,Size=UDim2.fromOffset(420,80),TextSize=13,XAlignment=Enum.TextXAlignment.Center})); empty:SetAttribute("CanonicalGarageCard",true) end
	self:QueueCarouselUpdate(); return selectedCard
end
function WorkspaceUI:RenderPaint(context)
	self.Popup:Hide(); self.Scroller.Visible=false; self.Paint.Visible=true; clear(self.Paint); local channels=context.ColorChannels or {}; local selected=context.SelectedChannel or channels[1]; if not selected then return end
	local current=(context.Colors and context.Colors[selected]) or Color3.new(1,1,1); local h,s,v=Color3.toHSV(current); self.PaintHSV={h,s,v}; self.PaintChannel=selected
	local width=math.min(N("WorkspacePaintWidth",720),self.ReferenceCarouselWidth or 720); local panel=generated(Shared.Panel(self.Paint,"PaintControls",{StrokeColor=Racing.Colour("ElectricBlue"),StrokeTransparency=.35,NoGlow=true})); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(width,142)
	local tabWidth=math.max(96,(width-16-math.max(0,#channels-1)*8)/math.max(1,#channels)); for index,channel in ipairs(channels) do local b=generated(Racing.Button(panel,{Text=string.upper(channel),Position=UDim2.fromOffset(8+(index-1)*(tabWidth+8),7),Size=UDim2.fromOffset(tabWidth,30),Color=channel==selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); b.Activated:Connect(function() context.OnChannel(channel) end) end
	local function emit() if context.OnColor then context.OnColor(selected,Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],self.PaintHSV[3])) end end
	local function slider(labelText,index,y)
		generated(Racing.Label(panel,{Text=labelText,Position=UDim2.fromOffset(10,y-7),Size=UDim2.fromOffset(24,24),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}))
		local track=generated(Instance.new("Frame")); track.Active=true; track.BackgroundColor3=Racing.Colour("PanelSoft"); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(42,y); track.Size=UDim2.new(1,-58,0,10); track.Parent=panel; Racing.Corner(track,5)
		local g=Instance.new("UIGradient"); if index==1 then g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.17,Color3.fromHSV(.17,1,1)),ColorSequenceKeypoint.new(.33,Color3.fromHSV(.33,1,1)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(.5,1,1)),ColorSequenceKeypoint.new(.67,Color3.fromHSV(.67,1,1)),ColorSequenceKeypoint.new(.83,Color3.fromHSV(.83,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))}) elseif index==2 then g.Color=ColorSequence.new(Color3.fromHSV(h,0,v),Color3.fromHSV(h,1,v)) else g.Color=ColorSequence.new(Color3.new(0,0,0),Color3.fromHSV(h,s,1)) end; g.Parent=track
		local knob=generated(Instance.new("Frame")); knob.AnchorPoint=Vector2.new(.5,.5); knob.Position=UDim2.fromScale(self.PaintHSV[index],.5); knob.Size=UDim2.fromOffset(5,18); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=8; knob.Parent=track; Racing.Corner(knob,3)
		local function update(input) local x=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); self.PaintHSV[index]=x; knob.Position=UDim2.fromScale(x,.5); emit() end
		table.insert(self.Dynamic,track.InputBegan:Connect(function(input) if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; update(input); local move,endConnection; move=UserInputService.InputChanged:Connect(function(changed) if changed.UserInputType==Enum.UserInputType.MouseMovement or changed.UserInputType==Enum.UserInputType.Touch then update(changed) end end); endConnection=UserInputService.InputEnded:Connect(function(ended) if ended.UserInputType==input.UserInputType then move:Disconnect(); endConnection:Disconnect() end end) end))
	end
	slider("H",1,55); slider("S",2,86); slider("B",3,117)
end
function WorkspaceUI:QueueCarouselUpdate() if self.CarouselQueued then return end; self.CarouselQueued=true; task.defer(function() RunService.Heartbeat:Wait(); self.CarouselQueued=false; if self.Root.Visible then self:UpdateCarousel() end end) end
function WorkspaceUI:UpdateCarousel()
	if not self.Scroller.Visible or self.Updating then self.Left.Visible=false; self.RightArrow.Visible=false; return end; self.Updating=true; local count=0; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then count+=1 end end; local cardWidth=N("WorkspaceCardWidth",210); local content=count*cardWidth+math.max(0,count-1)*12; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local window=self.ReferenceCarouselWidth or self.Scroller.AbsoluteSize.X/scale; if self.Scroller.AbsoluteSize.X>0 then window=self.Scroller.AbsoluteSize.X/scale end; local side=content<window and math.max(6,(window-content)*.5) or 6; self.CardPad.PaddingLeft=UDim.new(0,side); self.CardPad.PaddingRight=UDim.new(0,side); local canvas=math.max(window,content+side*2); self.Scroller.CanvasSize=UDim2.fromOffset(canvas,0); self.MaxScroll=math.max(0,canvas-window); if self.MaxScroll<=1 then self.Scroller.CanvasPosition=Vector2.zero end; local x=self.Scroller.CanvasPosition.X; self.Left.Visible=self.MaxScroll>1 and x>1; self.RightArrow.Visible=self.MaxScroll>1 and x<self.MaxScroll-1; self.Updating=false
end
function WorkspaceUI:Scroll(direction) self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*(N("WorkspaceCardWidth",210)+12),0,self.MaxScroll or 0),0); self:UpdateCarousel() end
function WorkspaceUI:Audit(selectedCard)
	task.defer(function()
		RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:Layout(); RunService.Heartbeat:Wait(); if not self.Root.Visible then return end; self:UpdateCarousel()
		local failures={}; local function expect(ok,message) if not ok then table.insert(failures,message) end end; local roots=0; for _,child in ipairs(self.Host.Canvas:GetChildren()) do if child.Name=="CanonicalGarageWorkspace" then roots+=1 end end; expect(roots==1,"expected one workspace root"); expect(self.Gui.Name=="CanonicalGarageGui","workspace is not in CanonicalGarageGui"); expect(self.Scale.Parent==self.Host.Canvas,"workspace does not use the shared canonical scale"); local artOk,artFailures=Artwork.Audit(); expect(artOk,"module artwork schema: "..table.concat(artFailures,", "))
		Shared.AuditPresentation(self.Root,"Workspace")
		if self.Categories.Visible then expect(self.Categories.AbsolutePosition.Y+self.Categories.AbsoluteSize.Y<=self.Carousel.AbsolutePosition.Y-8,"categories overlap carousel") end
		local combined=self.Cash.AbsoluteSize.X+self.Capacity.AbsoluteSize.X+N("Gap",14); expect(math.abs(combined-self.Stats.AbsoluteSize.X)<=3,"economy width does not match stats"); local rightEdge=self.Root.AbsolutePosition.X+self.Root.AbsoluteSize.X+2; for _,object in ipairs({self.Right,self.Stats,self.Economy,self.Exit,self.Next,self.Back,self.RightArrow}) do if object.Visible then expect(object.AbsolutePosition.X+object.AbsoluteSize.X<=rightEdge,"right edge clipped: "..object.Name) end end
		local maxScroll=self.MaxScroll or 0; local x=self.Scroller.CanvasPosition.X; expect(self.Left.Visible==(self.Scroller.Visible and maxScroll>1 and x>1),"left arrow state mismatch"); expect(self.RightArrow.Visible==(self.Scroller.Visible and maxScroll>1 and x<maxScroll-1),"right arrow state mismatch")
		if self.Scroller.Visible and maxScroll<=1 then local first,last; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then if not first or child.AbsolutePosition.X<first.AbsolutePosition.X then first=child end; if not last or child.AbsolutePosition.X>last.AbsolutePosition.X then last=child end end end; if first and last then expect(math.abs((first.AbsolutePosition.X+last.AbsolutePosition.X+last.AbsoluteSize.X)*.5-(self.Root.AbsolutePosition.X+self.Root.AbsoluteSize.X*.5))<=3,"short card row is not centred") end end
		if self.Popup.Shell.Visible and selectedCard and selectedCard.Parent then expect(math.abs((self.Popup.Shell.AbsolutePosition.X+self.Popup.Shell.AbsoluteSize.X*.5)-(selectedCard.AbsolutePosition.X+selectedCard.AbsoluteSize.X*.5))<=3,"action popup is not card-centred") end
		if #failures==0 then print("[NTR Garage Workspace Runtime] GEOMETRY PASS "..tostring(self.Context and self.Context.Title)) else warn("[NTR Garage Workspace Runtime] GEOMETRY FAIL: "..table.concat(failures," | ")) end
	end)
end
function WorkspaceUI:Show(context)
	self:DisconnectDynamic(); self.Context=context
	self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy); self:Layout(); self.Title.Text=string.upper(context.Title or "GARAGE"); self.Subtitle.Text=context.Subtitle or ""; self.Back.Visible=context.BackVisible~=false; self.Next.Visible=context.NextVisible~=false; self.Next.Text=string.upper(context.NextText or "NEXT"); self.Exit.Visible=context.ExitVisible==true
	self:RenderLeft(context); self:RenderStats(context); self:RenderEconomy(context); local selectedCard; if context.ColorChannels then self:RenderPaint(context) else selectedCard=self:RenderCards(context) end; self:Layout(); self:Audit(selectedCard)
end
function WorkspaceUI:Hide() self:DisconnectDynamic(); self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root) end
return WorkspaceUI
]==]

local function compile(name, source)
	if typeof(loadstring) == "function" then local fn, err = loadstring(source); assert(fn, name .. " compile failed: " .. tostring(err)) end
end
local componentsSource = components.Source
if not string.find(componentsSource, "NTR_GARAGE_INDEPENDENT_CANONICAL_HOST_V1", 1, true) then
	componentsSource = replaceOnce(componentsSource, "\nreturn M", [[
-- NTR_GARAGE_INDEPENDENT_CANONICAL_HOST_V1
local canonicalHost=nil
function M.CanonicalHost()
	local player=game:GetService("Players").LocalPlayer; local playerGui=player:WaitForChild("PlayerGui")
	if canonicalHost and canonicalHost.Gui.Parent==playerGui and canonicalHost.Canvas.Parent==canonicalHost.Gui and canonicalHost.Scale.Parent==canonicalHost.Canvas then return canonicalHost end
	local gui=playerGui:FindFirstChild("CanonicalGarageGui")
	if gui and not gui:IsA("ScreenGui") then gui:Destroy(); gui=nil end
	if not gui then gui=Instance.new("ScreenGui"); gui.Name="CanonicalGarageGui"; gui.Parent=playerGui end
	gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=40; gui.Enabled=true
	local canvas=gui:FindFirstChild("CanonicalCanvas")
	if canvas and not canvas:IsA("Frame") then canvas:Destroy(); canvas=nil end
	if not canvas then canvas=Instance.new("Frame"); canvas.Name="CanonicalCanvas"; canvas.Parent=gui end
	canvas.BackgroundTransparency=1; canvas.BorderSizePixel=0; canvas.Position=UDim2.fromOffset(0,0); canvas.Size=UDim2.fromOffset(1600,900)
	local scale=canvas:FindFirstChild("CanonicalScale")
	if scale and not scale:IsA("UIScale") then scale:Destroy(); scale=nil end
	if not scale then scale=Instance.new("UIScale"); scale.Name="CanonicalScale"; scale.Parent=canvas end
	for _,child in ipairs(canvas:GetChildren()) do if child:IsA("UIScale") and child~=scale then child:Destroy() end end
	canonicalHost={Gui=gui,Canvas=canvas,Scale=scale}; return canonicalHost
end
return M]], "Independent canonical host")
end
if not string.find(componentsSource, "NTR_GARAGE_PRESENTATION_SINGLE_OWNER_V1", 1, true) then
	componentsSource = replaceOnce(componentsSource, "\nreturn M", [[
-- NTR_GARAGE_PRESENTATION_SINGLE_OWNER_V1
local presentationOwner = nil
local retiredSurfaces = {}
local ownerConnection = nil
local function suppressRetiredSurfaces()
	if not (presentationOwner and presentationOwner.Parent and presentationOwner.Visible) then return end
	for object in pairs(retiredSurfaces) do
		if object.Parent and object.Visible then object.Visible = false end
	end
end
function M.AcquirePresentation(owner, surfaces)
	if presentationOwner and presentationOwner ~= owner and presentationOwner.Parent then presentationOwner.Visible = false end
	presentationOwner = owner
	for _, object in pairs(surfaces or {}) do
		if typeof(object) == "Instance" and object:IsA("GuiObject") then retiredSurfaces[object] = true; object.Visible = false end
	end
	if not ownerConnection then ownerConnection = RunService.RenderStepped:Connect(suppressRetiredSurfaces) end
	suppressRetiredSurfaces()
end
function M.ReleasePresentation(owner)
	if presentationOwner == owner then presentationOwner = nil end
	-- Legacy garage surfaces are retired and intentionally never restored.
	for object in pairs(retiredSurfaces) do if object.Parent then object.Visible = false end end
end
function M.AuditPresentation(owner, labelText)
	task.defer(function()
		RunService.Heartbeat:Wait(); suppressRetiredSurfaces(); local failures = {}
		if presentationOwner ~= owner then table.insert(failures, "canonical owner changed") end
		for object in pairs(retiredSurfaces) do if object.Parent and object.Visible then table.insert(failures, object.Name) end end
		if #failures == 0 then print("[NTR Garage Presentation Owner] PASS " .. tostring(labelText or owner.Name)) else warn("[NTR Garage Presentation Owner] FAIL " .. table.concat(failures, " | ")) end
	end)
end
return M]], "Shared presentation owner")
end

if not string.find(componentsSource, "NTR_GARAGE_SHARED_PERFORMANCE_V2", 1, true) then
	componentsSource = replaceOnce(componentsSource,
		[[TextSize=10,XAlignment=Enum.TextXAlignment.Center,Truncate=Enum.TextTruncate.AtEnd}); name.ZIndex=card.ZIndex+4]],
		[[TextSize=props.NameTextSize or 10,XAlignment=Enum.TextXAlignment.Center,Truncate=Enum.TextTruncate.AtEnd,Role=props.NameRole}); name.ZIndex=card.ZIndex+4]], "Shared configurable card name")
	componentsSource = replaceOnce(componentsSource,
		[[function M.ModuleCard(parent,props) props=props or {}; props.ImageHeight=props.ImageHeight or 104; props.ImageZoom=props.ImageZoom or 1; props.NameOverlay=false; props.ImageScaleType=props.ImageScaleType or Enum.ScaleType.Fit; return M.Card(parent,props) end]],
		[[function M.ModuleCard(parent,props) props=props or {}; props.ImageHeight=props.ImageHeight or 104; props.ImageZoom=props.ImageZoom or 1; props.NameOverlay=false; props.NameTextSize=props.NameTextSize or 15; props.NameRole=props.NameRole or "Heading"; props.ImageScaleType=props.ImageScaleType or Enum.ScaleType.Fit; return M.Card(parent,props) end]], "Shared bold module names")
	componentsSource = replaceOnce(componentsSource, "\nreturn M", [[
-- NTR_GARAGE_SHARED_PERFORMANCE_V2
function M.RenderPerformance(parent,options)
	options=options or {}; local attribute=options.GeneratedAttribute or "GeneratedGarageUI"
	for _,child in ipairs(parent:GetChildren()) do if child:GetAttribute(attribute) then child:Destroy() end end
	local function generated(object) object:SetAttribute(attribute,true); return object end
	local performance=options.Performance
	if not performance then generated(Racing.Label(parent,{Text=options.EmptyText or "NO PERFORMANCE DATA",Size=UDim2.new(1,0,0,42),TextSize=10,XAlignment=Enum.TextXAlignment.Center})); return end
	local overall=performance.Overall or {}; local tier=tostring(overall.Tier or "E"); local index=math.floor(tonumber(overall.PerformanceIndex) or 100); local tierColor=typeof(options.TierColor)=="function" and options.TierColor(tier) or Racing.Colour("PanelSoft")
	local header=generated(Instance.new("Frame")); header.Name="Rating"; header.LayoutOrder=1; header.BackgroundColor3=tierColor; header.BorderSizePixel=0; header.Size=UDim2.new(1,0,0,42); header.Parent=parent; Racing.Corner(header,4); Racing.Label(header,{Text=tier.."  "..index,Position=UDim2.fromOffset(8,0),Size=UDim2.new(.5,-8,1,0),TextSize=19,Role="Metric"}); Racing.Label(header,{Text="PERFORMANCE",Position=UDim2.fromScale(.5,0),Size=UDim2.new(.5,-8,1,0),TextSize=9,XAlignment=Enum.TextXAlignment.Right,Role="Heading"})
	local baseline=options.Baseline; local reference=tonumber(options.Reference) or 180
	for order,name in ipairs({"Speed","Acceleration","Handling","Drift","Braking","Boost"}) do
		local value=tonumber(performance.Headline and performance.Headline[name]) or 0; local baseValue=tonumber(baseline and baseline.Headline and baseline.Headline[name]); local delta=baseValue and (math.floor(value+.5)-math.floor(baseValue+.5)) or 0; local deltaText=delta==0 and "-" or ((delta>0 and "+" or "")..tostring(delta)); local deltaColor=delta>0 and Color3.fromRGB(89,255,102) or (delta<0 and Color3.fromRGB(255,105,116) or Racing.Colour("Text"))
		local stat=generated(Instance.new("Frame")); stat.Name=name; stat.LayoutOrder=order+1; stat.BackgroundTransparency=1; stat.Size=UDim2.new(1,0,0,36); stat.Parent=parent; Racing.Label(stat,{Text=string.upper(name),Size=UDim2.new(.55,0,0,16),TextSize=9,Role="Heading"}); Racing.Label(stat,{Text=tostring(math.floor(value+.5)),Position=UDim2.new(.55,0,0,0),Size=UDim2.new(.25,0,0,16),TextSize=10,XAlignment=Enum.TextXAlignment.Right,Role="Metric"}); Racing.Label(stat,{Text=deltaText,Position=UDim2.new(.82,0,0,0),Size=UDim2.new(.18,0,0,16),TextSize=10,Color=deltaColor,XAlignment=Enum.TextXAlignment.Right,Role="Metric"})
		local track=Instance.new("Frame"); track.BackgroundColor3=Racing.Colour("PanelSoft"); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(0,20); track.Size=UDim2.new(1,0,0,9); track.Parent=stat; Racing.Corner(track,5); local fill=Instance.new("Frame"); fill.BackgroundColor3=Racing.Colour("Telemetry"); fill.BorderSizePixel=0; fill.Size=UDim2.fromScale(math.clamp(value/reference,0,1),1); fill.Parent=track; Racing.Corner(fill,5); local gradient=Instance.new("UIGradient"); gradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry")); gradient.Parent=fill
	end
end
return M]], "Shared performance renderer")
end

if not string.find(componentsSource, "NTR_GARAGE_SHARED_SHELL_V2", 1, true) then
	componentsSource = replaceOnce(componentsSource, "\nreturn M", [[
-- NTR_GARAGE_SHARED_SHELL_V2
function M.LayoutGarageShell(ui,options)
	-- NTR_GARAGE_SHARED_SHELL_CANONICAL_HOST_V3
	options=options or {}; local N=assert(options.Number,"Garage shell Number resolver missing"); local viewport=options.Viewport or Vector2.new(1600,900); local minimum=options.MinimumScale or .68; local scale=math.clamp(math.min(viewport.X/N("BaseWidth",1600),viewport.Y/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); ui.Scale.Scale=scale; local vw,vh=viewport.X/scale,viewport.Y/scale; if ui.Host and ui.Host.Canvas then ui.Host.Canvas.Position=UDim2.fromOffset(0,0); ui.Host.Canvas.Size=UDim2.fromOffset(vw,vh) end; ui.Root.Position=UDim2.fromOffset(0,0); ui.Root.Size=UDim2.fromOffset(vw,vh)
	local margin,gap=N("Margin",18),N("Gap",14); local carouselH=N("CarouselHeight",166); local carouselTop=vh-margin-carouselH; local arrowW=N("ArrowWidth",42); local railReserve=30; ui.LayoutScale=scale; ui.ReferenceWidth=vw
	ui.Header.AnchorPoint=Vector2.new(.5,0); ui.Header.Position=UDim2.fromOffset(vw*.5,28); ui.Header.Size=UDim2.fromOffset(420,62)
	ui.Categories.Position=UDim2.fromOffset(margin,72); ui.Categories.Size=UDim2.fromOffset(N("CategoryWidth",214),math.max(170,carouselTop-72-N("CategoryCarouselClearance",82)))
	ui.Right.AnchorPoint=Vector2.new(1,0); ui.Right.Position=UDim2.fromOffset(vw-margin,28); ui.Right.Size=UDim2.fromOffset(N("StatsWidth",354),0); ui.Stats.LayoutOrder=1; ui.Economy.LayoutOrder=2; ui.Economy.Size=UDim2.new(1,0,0,N("EconomyHeight",46)); local rightLayout=ui.Right:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout"); rightLayout.Padding=UDim.new(0,gap); rightLayout.SortOrder=Enum.SortOrder.LayoutOrder; rightLayout.Parent=ui.Right
	ui.Cash.Position=UDim2.fromOffset(0,0); ui.Cash.Size=UDim2.new(.5,-gap*.5,1,0); ui.Capacity.AnchorPoint=Vector2.new(1,0); ui.Capacity.Position=UDim2.fromScale(1,0); ui.Capacity.Size=UDim2.new(.5,-gap*.5,1,0)
	ui.Carousel.Position=UDim2.fromOffset(margin+railReserve+gap,carouselTop); ui.Carousel.Size=UDim2.fromOffset(vw-2*(margin+railReserve+gap),carouselH); if ui.Scroller then ui.Scroller.Size=UDim2.fromScale(1,1) end; if ui.Paint then ui.Paint.Size=UDim2.fromScale(1,1) end; ui.ReferenceCarouselWidth=vw-2*(margin+railReserve+gap)
	ui.Left.AnchorPoint=Vector2.new(0,.5); ui.Left.Position=UDim2.fromOffset(margin,carouselTop+carouselH*.5); ui.Left.Size=UDim2.fromOffset(arrowW,N("ArrowHeight",72)); ui.RightArrow.AnchorPoint=Vector2.new(1,.5); ui.RightArrow.Position=UDim2.fromOffset(vw-margin,carouselTop+carouselH*.5); ui.RightArrow.Size=UDim2.fromOffset(arrowW,N("ArrowHeight",72))
	local actionX=vw-margin; for _,action in ipairs(options.Actions or {}) do if action.Visible then action.AnchorPoint=Vector2.new(1,1); action.Position=UDim2.fromOffset(actionX,carouselTop-gap); actionX-=action.Size.X.Offset+gap end end
	return {Scale=scale,Width=vw,Height=vh,CarouselTop=carouselTop}
end
return M]], "Shared garage shell layout")
end
if string.find(componentsSource, "NTR_GARAGE_SHARED_SHELL_V2", 1, true) and not string.find(componentsSource, "NTR_GARAGE_SHARED_SHELL_CANONICAL_HOST_V3", 1, true) then
	componentsSource = replaceOnce(componentsSource, [[function M.LayoutGarageShell(ui,options)
	options=options or {}; local N=assert(options.Number,"Garage shell Number resolver missing"); local viewport=options.Viewport or Vector2.new(1600,900); local minimum=options.MinimumScale or .68; local scale=math.clamp(math.min(viewport.X/N("BaseWidth",1600),viewport.Y/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); ui.Scale.Scale=scale; local vw,vh=viewport.X/scale,viewport.Y/scale; ui.Root.Size=UDim2.fromOffset(vw,vh)]], [[function M.LayoutGarageShell(ui,options)
	-- NTR_GARAGE_SHARED_SHELL_CANONICAL_HOST_V3
	options=options or {}; local N=assert(options.Number,"Garage shell Number resolver missing"); local viewport=options.Viewport or Vector2.new(1600,900); local minimum=options.MinimumScale or .68; local scale=math.clamp(math.min(viewport.X/N("BaseWidth",1600),viewport.Y/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); ui.Scale.Scale=scale; local vw,vh=viewport.X/scale,viewport.Y/scale; if ui.Host and ui.Host.Canvas then ui.Host.Canvas.Position=UDim2.fromOffset(0,0); ui.Host.Canvas.Size=UDim2.fromOffset(vw,vh) end; ui.Root.Position=UDim2.fromOffset(0,0); ui.Root.Size=UDim2.fromOffset(vw,vh)]], "Shared shell canonical-host sizing")
end

local browserSource = browserController.Source
if not string.find(browserSource, "NTR_GARAGE_BROWSER_INDEPENDENT_HOST_V1", 1, true) then
	browserSource = replaceOnce(browserSource, [[-- NTR_GARAGE_REPLACEMENT_BROWSER_CONTROLLER_V1]], [[-- NTR_GARAGE_REPLACEMENT_BROWSER_CONTROLLER_V1
-- NTR_GARAGE_BROWSER_INDEPENDENT_HOST_V1]], "Browser independent-host marker")
	browserSource = replaceOnce(browserSource, [[function Browser.new(gui,legacyScale)
	local self=setmetatable({},Browser); self.Gui=gui; self.LegacyScale=legacyScale; self.Legacy={}; self.Context=nil
	self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageBrowser"; self.Root.BackgroundTransparency=1; self.Root.BorderSizePixel=0; self.Root.Visible=false; self.Root.Parent=gui
	self.Scale=Instance.new("UIScale"); self.Scale.Name="CanonicalScale"; self.Scale.Parent=self.Root]], [[function Browser.new()
	local self=setmetatable({},Browser); self.Host=Shared.CanonicalHost(); self.Gui=self.Host.Gui; self.Scale=self.Host.Scale; self.Context=nil
	self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageBrowser"; self.Root.BackgroundTransparency=1; self.Root.BorderSizePixel=0; self.Root.Visible=false; self.Root.Parent=self.Host.Canvas]], "Browser independent-host constructor")
	browserSource = replaceOnce(browserSource, [[self.Context=context; if not self.Root.Visible and self.LegacyScale then self.OldScale=self.LegacyScale.Scale; self.LegacyScale.Scale=1 end; self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy);]], [[self.Context=context; self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy);]], "Browser legacy-scale acquire removal")
	browserSource = replaceOnce(browserSource, [[function Browser:Hide() self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root); if self.LegacyScale and self.OldScale then self.LegacyScale.Scale=self.OldScale end end]], [[function Browser:Hide() self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root) end]], "Browser legacy-scale release removal")
	browserSource = replaceOnce(browserSource, [[local roots=0; for _,child in ipairs(self.Gui:GetChildren()) do if child.Name=="CanonicalGarageBrowser" then roots+=1 end end; expect(roots==1,"expected one canonical browser root")
		for legacy in pairs(self.Legacy) do expect(not legacy.Visible,"legacy browser surface remained visible: "..legacy.Name) end]], [[local roots=0; for _,child in ipairs(self.Host.Canvas:GetChildren()) do if child.Name=="CanonicalGarageBrowser" then roots+=1 end end; expect(roots==1,"expected one canonical browser root"); expect(self.Gui.Name=="CanonicalGarageGui","browser is not in CanonicalGarageGui"); expect(self.Scale.Parent==self.Host.Canvas,"browser does not use the shared canonical scale")]], "Browser independent-host audit")
end
if not string.find(browserSource, "NTR_GARAGE_PRESENTATION_OWNER_BROWSER_V1", 1, true) then
	browserSource = replaceOnce(browserSource, [[-- NTR_GARAGE_REPLACEMENT_BROWSER_CONTROLLER_V1]], [[-- NTR_GARAGE_REPLACEMENT_BROWSER_CONTROLLER_V1
-- NTR_GARAGE_PRESENTATION_OWNER_BROWSER_V1]], "Browser owner marker")
	browserSource = replaceOnce(browserSource,
		[[self.Context=context; if not self.Root.Visible then self.Legacy={}; for _,o in ipairs(context.Legacy or {}) do if o then self.Legacy[o]=o.Visible; o.Visible=false end end; if self.LegacyScale then self.OldScale=self.LegacyScale.Scale; self.LegacyScale.Scale=1 end end; self.Root.Visible=true;]],
		[[self.Context=context; if not self.Root.Visible and self.LegacyScale then self.OldScale=self.LegacyScale.Scale; self.LegacyScale.Scale=1 end; self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy);]], "Browser acquire owner")
	browserSource = replaceOnce(browserSource,
		[[function Browser:Hide() self.Root.Visible=false; self.Popup:Hide(); for o,v in pairs(self.Legacy) do if o.Parent then o.Visible=v end end; self.Legacy={}; if self.LegacyScale and self.OldScale then self.LegacyScale.Scale=self.OldScale end end]],
		[[function Browser:Hide() self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root); if self.LegacyScale and self.OldScale then self.LegacyScale.Scale=self.OldScale end end]], "Browser release owner")
	browserSource = replaceOnce(browserSource, [[function Browser:Audit(selectedCard)]], [[function Browser:Audit(selectedCard)
	Shared.AuditPresentation(self.Root,"Browser")]], "Browser owner audit")
end
if not string.find(browserSource, "NTR_GARAGE_BROWSER_SHARED_PERFORMANCE_V2", 1, true) then
	browserSource = replaceRange(browserSource, "function Browser:RenderStats(row)", "function Browser:RenderEconomy(context)", [[function Browser:RenderStats(row)
	-- NTR_GARAGE_BROWSER_SHARED_PERFORMANCE_V2
	Shared.RenderPerformance(self.Stats,{Performance=row and row.Performance or nil,TierColor=self.Context and self.Context.TierColor,Reference=N("StatReference",180),GeneratedAttribute="GeneratedGarageUI",EmptyText="NO VEHICLES AVAILABLE"})
end
]], "Browser shared performance renderer")
end
if not string.find(browserSource, "NTR_GARAGE_BROWSER_SHARED_SHELL_V2", 1, true) then
	browserSource = replaceRange(browserSource, "function Browser:Layout()", "function Browser:QueueCarouselUpdate()", [[function Browser:Layout()
	-- NTR_GARAGE_BROWSER_SHARED_SHELL_V2
	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); Shared.LayoutGarageShell(self,{Number=N,Viewport=viewport,MinimumScale=minimum,Actions={self.Exit}})
	self:QueueCarouselUpdate()
end
]], "Browser shared shell layout")
end

local propertySource = propertyController.Source
if not string.find(propertySource, "NTR_GARAGE_PROPERTY_CANONICAL_REFRESH_V1", 1, true) then
	propertySource = replaceOnce(propertySource,
		[[				ctx.renderGarageCapacityPanel()
				GaragePropertyMenuController.Render(ctx)]],
		[[				ctx.renderGarageCapacityPanel()
				-- NTR_GARAGE_PROPERTY_CANONICAL_REFRESH_V1
				if ctx.onProfileChanged then ctx.onProfileChanged() end
				GaragePropertyMenuController.Render(ctx)]], "Property canonical refresh")
end

compile("GarageWorkspaceController", controllerSource)
compile("GarageModuleArtworkRegistry", artworkRegistrySource)
compile("GarageReplacementComponents", componentsSource)
compile("GarageBrowserController", browserSource)
compile("GaragePropertyMenuController", propertySource)
assert(not string.find(controllerSource, "UDim2.zero", 1, true), "Invalid UDim2.zero in workspace controller")
assert(string.find(controllerSource, "Shared.LayoutGarageShell", 1, true), "Workspace is not using the shared garage shell")
assert(string.find(controllerSource, "Shared.RenderPerformance", 1, true), "Workspace is not using shared performance stats")
assert(string.find(componentsSource, "NTR_GARAGE_SHARED_SHELL_V2", 1, true), "Shared garage shell missing")
assert(string.find(componentsSource, "NTR_GARAGE_SHARED_PERFORMANCE_V2", 1, true), "Shared performance renderer missing")
assert(string.find(componentsSource, "NTR_GARAGE_INDEPENDENT_CANONICAL_HOST_V1", 1, true), "Independent canonical host missing")
assert(string.find(browserSource, "NTR_GARAGE_BROWSER_SHARED_SHELL_V2", 1, true), "Browser shared shell bridge missing")
assert(string.find(browserSource, "NTR_GARAGE_BROWSER_SHARED_PERFORMANCE_V2", 1, true), "Browser shared performance bridge missing")
assert(string.find(browserSource, "NTR_GARAGE_BROWSER_INDEPENDENT_HOST_V1", 1, true), "Browser independent host missing")
assert(string.find(controllerSource, "NTR_GARAGE_WORKSPACE_CONTROLLER_V3", 1, true), "Workspace independent host missing")
local source = bootstrap.Source
if not string.find(source, "NTR_GARAGE_WORKSPACE_BRIDGE_V1", 1, true) then
	local paintBridge = [=[renderCockpitPaint = function()
	-- NTR_GARAGE_WORKSPACE_BRIDGE_V1
	-- NTR_GARAGE_WORKSPACE_SHARED_REUSE_V2
	if not UI.CanonicalGarageWorkspace then UI.CanonicalGarageWorkspace = require(script.Parent.Controllers.UI:WaitForChild("GarageWorkspaceController")).new(UI.Gui, UI.Scale) end
	local ownedCount, capacity = NTR_phase8GarageCapacitySummary()
	local channels = { "Primary", "Secondary", "Detail" }
	UI.CanonicalGarageRefresh = function() renderCockpitPaint() end
	UI.CanonicalGarageWorkspace:Show({
		Title = "Paint Cockpit", Subtitle = "Choose primary, secondary, and detail colours.", ShowLeft = false, BackVisible = false, ExitVisible = false, NextText = "Build Modules",
		Cash = State.Profile and State.Profile.Cash or 0, CapacityText = tostring(ownedCount) .. "/" .. tostring(capacity) .. " Spaces", ColorChannels = channels, SelectedChannel = State.SelectedColorChannel or channels[1], Colors = State.Profile and State.Profile.CockpitColors or {},
		Legacy = { UI.Top, UI.CashPanel, UI.GarageCapacityPanel, UI.StatsPanel, UI.CockpitPaint, UI.CockpitPaintPicker, UI.ColorChannelFloat, UI.NextPanel },
		RenderStats = function(parent) local stats, base = currentStats(); local _, Calculator = NTRVehiclePhaseAO.performanceModules(); UI.CanonicalGarageWorkspace:DrawPerformance(parent, Calculator.CalculateLegacy(stats or {}), Calculator.CalculateLegacy(base or stats or {}), NTRVehiclePhaseAO.tierColor) end,
		OnChannel = function(channel) State.SelectedColorChannel = channel; renderCockpitPaint() end,
		OnColor = function(channel, color)
			callServer("SetCockpitColor", { Channel = channel, Color = color }); if State.Profile and State.Profile.CockpitColors then State.Profile.CockpitColors[channel] = color end
			if State.Profile and State.Profile.InstalledModules and State.Profile.ModuleColors then for slotId in pairs(State.Profile.InstalledModules) do State.Profile.ModuleColors[slotId] = State.Profile.ModuleColors[slotId] or {}; State.Profile.ModuleColors[slotId][channel] = color end end
			buildPreview()
		end,
		OnNext = function() clearPreviewModules(); State.ModuleMode = "Slots"; setCameraSection("Engine1"); showStage("ModuleShop"); renderModuleShop() end,
		OnExit = function() UI.CanonicalGarageWorkspace:Hide(); closeGarage(); NTR_phase7SignalDealershipExit() end, OnCash = function() showCashShop() end, OnCapacity = function() NTRPersistencePhase9.OpenGaragePropertyShop() end,
	})
end

]=]
	source = replaceRange(source, "renderCockpitPaint = function()", "local function renderSlotSelection()", paintBridge, "Paint renderer")
	-- The isolated workspace owns these presentations now. Removing only their obsolete
	-- renderer bodies keeps the register-limited bootstrap comfortably below Studio's
	-- 200,000-character Source ceiling while retaining the proven data/action helpers.
	source = replaceRange(source, "local function renderSlotSelection()", "-- NTR_PERSISTENCE_PHASE17_MODULE_POPUP_ANCHOR_TARGET", "-- NTR_GARAGE_WORKSPACE_RETIRED_LEGACY_SLOT_RENDERER\n", "Legacy slot renderer")
	source = replaceRange(source, "local function renderModuleOptions()", "renderModuleShop = function()", "-- NTR_GARAGE_WORKSPACE_RETIRED_LEGACY_MODULE_OPTIONS_RENDERER\n", "Legacy module options renderer")

	local moduleBridge = [=[renderModuleShop = function()
	if not UI.CanonicalGarageWorkspace then UI.CanonicalGarageWorkspace = require(script.Parent.Controllers.UI:WaitForChild("GarageWorkspaceController")).new(UI.Gui, UI.Scale) end
	local ownedCount, capacity = NTR_phase8GarageCapacitySummary()
	local cards, leftItems = {}, {}
	local function redraw() renderModuleShop() end
	UI.CanonicalGarageRefresh = redraw
	local function installedTemplateForSlot(slotId)
		local profile = State.Profile or {}; local currentVehicle = profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; local instanceId = currentVehicle and currentVehicle.InstalledModules and currentVehicle.InstalledModules[slotId]; local instance = instanceId and profile.OwnedModuleInstances and profile.OwnedModuleInstances[instanceId]; local templateId = instance and instance.TemplateId
		if templateId == nil or tostring(templateId) == "" then templateId = profile.InstalledModules and profile.InstalledModules[slotId] end
		return templateId, instanceId
	end
	local function coreModuleReadiness()
		local engine1 = installedTemplateForSlot("Engine1"); local engine2 = installedTemplateForSlot("Engine2"); local stabilisers = installedTemplateForSlot("Stabilisers"); local boost = installedTemplateForSlot("Boost")
		local function present(value) return value ~= nil and tostring(value) ~= "" end
		return present(engine1) or present(engine2), present(stabilisers), present(boost)
	end
	if State.ModuleMode == "Slots" then
		table.insert(leftItems, { Id = "Slots", Text = "Module Slots", Selected = true })
		for _, slot in ipairs(sortedSlots()) do
			local installedId = installedTemplateForSlot(slot.SlotId)
			table.insert(cards, { Id = slot.SlotId, ImageKey = slot.SlotId, DisplayName = slotDisplayName(slot), Badge = installedId and "EQUIPPED" or nil, BadgeColor = Theme.Accent, OnSelect = function() clearPreviewModules(); State.SelectedSlot = slot.SlotId; State.ModuleMode = "Options"; State.ModuleOptionMode = "Owned"; State.SelectedModuleId = nil; State.SelectedModuleInstanceId = nil; setCameraSection(slot.SlotId); redraw() end })
		end
	else
		table.insert(leftItems, { Id = "Slots", Text = "Module Slots", OnSelect = function() clearPreviewModules(); State.ModuleMode = "Slots"; State.ModuleOptionMode = nil; redraw() end })
		for _, mode in ipairs({"Owned", "Buy"}) do table.insert(leftItems, { Id = mode, Text = mode .. " Modules", Selected = State.ModuleOptionMode == mode, OnSelect = function() State.ModuleOptionMode = mode; State.SelectedModuleId = nil; State.SelectedModuleInstanceId = nil; clearPreviewModules(); redraw() end }) end
		local slotInfo = getSlot(State.SelectedSlot); local installed, installedInstanceId = installedTemplateForSlot(State.SelectedSlot)
		local function finish(result) if result.Success then clearPreviewModules(); State.ModuleMode = "Slots"; State.ModuleOptionMode = nil; buildPreview(); redraw() else UI.CanonicalGarageWorkspace:Message(result.Message or "Could not install module.") end end
		if State.ModuleOptionMode == "Owned" then
			for _, record in ipairs(NTRPersistencePhase15.OwnedModuleInstancesForSlot(State.Profile, slotInfo, getModule)) do
				local info, instance, instanceId = record.Module, record.Instance, record.InstanceId; local equippedHere = installedInstanceId == instanceId; local inUse = instance.EquippedVehicleId ~= nil and instance.EquippedVehicleId ~= "" and instance.EquippedVehicleId ~= (State.Profile and State.Profile.CurrentVehicleId); local selected = State.SelectedModuleInstanceId == instanceId
				local count = info and NTRPersistencePhase15.CountModuleCopies(State.Profile, info.ModuleId) or 1; local badge = equippedHere and "EQUIPPED" or (inUse and "IN USE" or ("OWNED x" .. tostring(count)))
				table.insert(cards, { Id = instanceId, ImageKey = info and info.ModuleId or State.SelectedSlot, DisplayName = tostring(info and (info.SourceCockpitDisplayName or info.SourceCockpitId) or "") .. " " .. tostring(info and info.VariantName or ""), Badge = badge, BadgeColor = equippedHere and Theme.Accent or Theme.CardHot, Selected = selected, ActionText = selected and not equippedHere and "EQUIP" or nil, OnSelect = function() if not info then return end; State.SelectedModuleId = info.ModuleId; State.SelectedModuleInstanceId = instanceId; State.PreviewModules = { [State.SelectedSlot] = info.ModuleId }; buildPreview(); redraw() end, OnAction = function() finish(callServer("EquipModuleInstance", { ModuleInstanceId = instanceId, VehicleId = State.Profile and State.Profile.CurrentVehicleId, SlotId = State.SelectedSlot })) end })
			end
		else
			for _, info in ipairs(modulesForSlot(State.SelectedSlot)) do
				local equipped = installed == info.ModuleId; local lockText = NTRPersistencePhase15.ModuleLockText(State.Profile, info); local selected = State.SelectedModuleId == info.ModuleId and State.SelectedModuleInstanceId == nil; local count = NTRPersistencePhase15.CountModuleCopies(State.Profile, info.ModuleId)
				local function buy() if lockText then UI.CanonicalGarageWorkspace:Message(lockText); return end; local before = State.Profile; local result = callServer("BuyModuleInstance", { ModuleId = info.ModuleId }); if not result.Success then UI.CanonicalGarageWorkspace:Message(result.Message or "Could not buy module."); return end; local instanceId = NTRPersistencePhase15.FindNewModuleCopyId(before, State.Profile, info.ModuleId); if not instanceId then UI.CanonicalGarageWorkspace:Message("Bought module, but could not find the new copy to equip."); redraw(); return end; finish(callServer("EquipModuleInstance", { ModuleInstanceId = instanceId, VehicleId = State.Profile and State.Profile.CurrentVehicleId, SlotId = State.SelectedSlot })) end
				table.insert(cards, { Id = info.ModuleId, ImageKey = info.ModuleId, DisplayName = tostring(info.SourceCockpitDisplayName or info.SourceCockpitId or "") .. " " .. tostring(info.VariantName or ""), Badge = equipped and "EQUIPPED" or (lockText and "LOCKED" or ("$" .. tostring(info.Price or 0))), BadgeColor = equipped and Theme.Accent or (lockText and Theme.Disabled or Theme.Cash), Selected = selected, ActionText = selected and not equipped and (lockText and "LOCKED" or "BUY") or nil, OnSelect = function() State.SelectedModuleId = info.ModuleId; State.SelectedModuleInstanceId = nil; State.PreviewModules = { [State.SelectedSlot] = info.ModuleId }; buildPreview(); redraw(); if lockText then UI.CanonicalGarageWorkspace:Message(lockText) end end, OnAction = buy })
			end
		end
	end
	UI.CanonicalGarageWorkspace:Show({
		Title = "Build Modules", Subtitle = State.ModuleMode == "Options" and "Preview, then buy or equip." or "Choose a fixed module slot.", ShowLeft = State.ModuleMode ~= "Slots", ExitVisible = false, LeftItems = leftItems, Cards = cards, EmptyMessage = State.ModuleMode == "Options" and "No compatible modules are available." or nil, NextText = "Customise",
		Cash = State.Profile and State.Profile.Cash or 0, CapacityText = tostring(ownedCount) .. "/" .. tostring(capacity) .. " Spaces", Legacy = { UI.Top, UI.CashPanel, UI.GarageCapacityPanel, UI.StatsPanel, UI.ModuleShop, UI.ModuleSlotPanel, UI.ModuleOptionsPanel, UI.NextPanel },
		RenderStats = function(parent) local stats, base = currentStats(); local _, Calculator = NTRVehiclePhaseAO.performanceModules(); UI.CanonicalGarageWorkspace:DrawPerformance(parent, Calculator.CalculateLegacy(stats or {}), Calculator.CalculateLegacy(base or stats or {}), NTRVehiclePhaseAO.tierColor) end,
		OnBack = function() if State.ModuleMode == "Options" then clearPreviewModules(); State.ModuleMode = "Slots"; State.ModuleOptionMode = nil; setCameraSection(nil); buildPreview(); redraw() else showStage("CockpitPaint"); renderCockpitPaint() end end,
		OnNext = function() local hasEngine, hasStabilisers, hasBoost = coreModuleReadiness(); if not (hasEngine and hasStabilisers and hasBoost) then UI.CanonicalGarageWorkspace:Message("Equip one engine, stabilisers, and boost first."); return end; clearPreviewModules(); State.CustomizeTarget = "ALL"; State.CustomizeMode = "Colour"; showStage("Customise"); renderCustomise() end,
		OnExit = function() UI.CanonicalGarageWorkspace:Hide(); closeGarage(); NTR_phase7SignalDealershipExit() end, OnCash = function() showCashShop() end, OnCapacity = function() NTRPersistencePhase9.OpenGaragePropertyShop() end,
	})
end

]=]
	source = replaceRange(source, "renderModuleShop = function()", "local function renderCustomiseLeft()", moduleBridge, "Module renderer")
	source = replaceRange(source, "local function renderCustomiseLeft()", "local function folderHasBuyableNeon(folder)", "-- NTR_GARAGE_WORKSPACE_RETIRED_LEGACY_CUSTOMISE_LEFT_RENDERER\n", "Legacy customise-left renderer")

	local customiseBridge = [=[renderCustomise = function()
	if not UI.CanonicalGarageWorkspace then UI.CanonicalGarageWorkspace = require(script.Parent.Controllers.UI:WaitForChild("GarageWorkspaceController")).new(UI.Gui, UI.Scale) end
	local ownedCount, capacity = NTR_phase8GarageCapacitySummary(); local target = State.CustomizeTarget; local leftItems, cards = {}, {}
	local function choose(newTarget, mode, cameraSlot) State.CustomizeTarget = newTarget; State.CustomizeMode = mode; State.SelectedSlot = cameraSlot or State.SelectedSlot; setCameraSection(cameraSlot); renderCustomise() end
	UI.CanonicalGarageRefresh = function() renderCustomise() end
	table.insert(leftItems, { Id = "ALL", Text = "Customise All", Selected = target == "ALL", OnSelect = function() choose("ALL", "Colour", nil) end })
	table.insert(leftItems, { Id = "THRUST_COLOR", Text = "Thrust Colour", Selected = target == "THRUST_COLOR", OnSelect = function() choose("THRUST_COLOR", "Colour", nil) end })
	table.insert(leftItems, { Id = "Cockpit", Text = "Cockpit", Selected = target == "Cockpit", OnSelect = function() choose("Cockpit", "Overview", nil) end })
	for _, slot in ipairs(sortedSlots()) do if State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[slot.SlotId] then table.insert(leftItems, { Id = slot.SlotId, Text = slotDisplayName(slot), Selected = target == slot.SlotId, OnSelect = function() choose(slot.SlotId, "Overview", slot.SlotId) end }) end end
	State.ThrustPreviewActive = target == "THRUST_COLOR" and State.CustomizeMode == "Colour"; if State.CustomizeMode ~= "ModuleUpgrades" then State.PreviewUpgradeId = nil end; if State.CustomizeMode ~= "Cosmetics" then State.PreviewNeonSlot = nil end; buildPreview()
	local context = { Title = "Customise", Subtitle = "Tune installed modules, change colours, or unlock lights.", LeftItems = leftItems, Cards = cards, NextText = "Start Driving", ExitVisible = false, Cash = State.Profile and State.Profile.Cash or 0, CapacityText = tostring(ownedCount) .. "/" .. tostring(capacity) .. " Spaces", Legacy = { UI.Top, UI.CashPanel, UI.GarageCapacityPanel, UI.StatsPanel, UI.Customise, UI.CustomiseLeft, UI.CustomisePanel, UI.ColorChannelFloat, UI.NextPanel }, RenderStats = function(parent) local stats, base = currentStats(); local _, Calculator = NTRVehiclePhaseAO.performanceModules(); UI.CanonicalGarageWorkspace:DrawPerformance(parent, Calculator.CalculateLegacy(stats or {}), Calculator.CalculateLegacy(base or stats or {}), NTRVehiclePhaseAO.tierColor) end, OnCash = function() showCashShop() end, OnCapacity = function() NTRPersistencePhase9.OpenGaragePropertyShop() end }
	context.OnExit = function() UI.CanonicalGarageWorkspace:Hide(); closeGarage(); NTR_phase7SignalDealershipExit() end
	context.OnNext = function() if player:GetAttribute("NTR_DriveInCustomisationActive") == true then player:SetAttribute("NTR_DriveInCustomisationActive", false); task.wait(.1) end; local result = callServer("SpawnVehicle", {}); if result.Success then UI.CanonicalGarageWorkspace:Hide(); local ok, err = pcall(closeGarage); if not ok then warn("[NTR Garage Workspace] closeGarage failed: " .. tostring(err)) end; task.defer(startDriving) else UI.CanonicalGarageWorkspace:Message(result.Message or "Could not spawn vehicle.") end end
	context.OnBack = function() if (State.CustomizeMode == "Colour" and target ~= "ALL") or State.CustomizeMode == "Cosmetics" or State.CustomizeMode == "ModuleUpgrades" then State.CustomizeMode = "Overview"; renderCustomise() else State.ModuleMode = "Slots"; showStage("ModuleShop"); renderModuleShop() end end
	if target == "ALL" or target == "THRUST_COLOR" or State.CustomizeMode == "Colour" then
		local channels = colourChannelsForTarget(target); local colors = {}; for _, channel in ipairs(channels) do if target == "THRUST_COLOR" or channel == "ThrustColor" then colors[channel] = State.Profile and State.Profile.ThrustColor or Color3.new(1,1,1) elseif target == "Cockpit" or target == "ALL" then colors[channel] = State.Profile and State.Profile.CockpitColors and State.Profile.CockpitColors[channel] or Color3.new(1,1,1) else colors[channel] = State.Profile and State.Profile.ModuleColors and State.Profile.ModuleColors[target] and State.Profile.ModuleColors[target][channel] or Color3.new(1,1,1) end end
		context.ColorChannels = channels; context.SelectedChannel = State.SelectedColorChannel or channels[1]; context.Colors = colors; context.OnChannel = function(channel) State.SelectedColorChannel = channel; renderCustomise() end
		context.OnColor = function(channel, color) if target == "THRUST_COLOR" or channel == "ThrustColor" then if State.Profile then State.Profile.ThrustColor = color end; callServer("SetThrustColor", { Color = color }); local root = Preview.Root or Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW"); if root then root:SetAttribute("ThrustColor", color); root:SetAttribute("ForceThrustPreview", true) end elseif target == "ALL" then callServer("SetModuleColor", { SlotId = "ALL", Channel = channel, Color = color }); if channel ~= "Neon" then callServer("SetCockpitColor", { Channel = channel, Color = color }) end elseif target == "Cockpit" then callServer("SetCockpitColor", { Channel = channel, Color = color }); if State.Profile and State.Profile.CockpitColors then State.Profile.CockpitColors[channel] = color end else callServer("SetModuleColor", { SlotId = target, Channel = channel, Color = color }); if State.Profile and State.Profile.ModuleColors then State.Profile.ModuleColors[target] = State.Profile.ModuleColors[target] or {}; State.Profile.ModuleColors[target][channel] = color end end; buildPreview() end
	elseif State.CustomizeMode == "Cosmetics" then
		local installedId = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[target]; local template = installedId and findTemplateByAttribute(categoriesRoot, "ModuleId", installedId); local owned = State.Profile and State.Profile.NeonOwned and State.Profile.NeonOwned[target]
		if target == "Cockpit" or target == "ALL" or target == "THRUST_COLOR" then context.EmptyMessage = "No purchasable cosmetics for this target." elseif not templateHasChannel(template, "Neon") then context.EmptyMessage = "This module has no optional neon." else table.insert(cards, { Id = "Neon", ImageKey = "Neon", DisplayName = "Neon Lights", Badge = owned and "OWNED" or "$5000", BadgeColor = owned and Theme.Accent or Theme.Cash, Selected = State.PreviewNeonSlot == target, ActionText = State.PreviewNeonSlot == target and not owned and "BUY" or nil, OnSelect = function() if not owned then State.PreviewNeonSlot = target; buildPreview(); renderCustomise() end end, OnAction = function() local result = callServer("BuyNeon", { SlotId = target }); State.PreviewNeonSlot = nil; buildPreview(); if not result.Success then UI.CanonicalGarageWorkspace:Message(result.Message or "Could not buy neon.") else renderCustomise() end end }) end
	elseif State.CustomizeMode == "ModuleUpgrades" then
		local slotId, moduleId, module = NTRVehiclePhaseAO.installedModule(); for _, upgrade in ipairs((module and module.Upgrades) or {}) do local level = NTRVehiclePhaseAO.moduleLevel(moduleId, upgrade.UpgradeId); local maxLevel = tonumber(upgrade.MaxLevel) or 3; local maximum = level >= maxLevel; local price = math.floor((tonumber(upgrade.BasePrice) or 0) * ((tonumber(upgrade.PriceMultiplier) or 1) ^ level)); local selected = State.PreviewUpgradeId == upgrade.UpgradeId; table.insert(cards, { Id = upgrade.UpgradeId, ImageKey = moduleId, DisplayName = upgrade.DisplayName or upgrade.UpgradeId, Badge = "LVL " .. tostring(level) .. "/" .. tostring(maxLevel), BadgeColor = maximum and Theme.Accent or Theme.Cash, Selected = selected, ActionText = selected and not maximum and ("BUY $" .. tostring(price)) or nil, OnSelect = function() if not maximum then State.PreviewUpgradeId = upgrade.UpgradeId; renderCustomise() end end, OnAction = function() local result = callServer("UpgradeModule", { SlotId = slotId, ModuleId = moduleId, UpgradeId = upgrade.UpgradeId }); if result.Success then State.PreviewUpgradeId = nil; renderCustomise() else UI.CanonicalGarageWorkspace:Message(result.Message or "Could not buy upgrade.") end end }) end; if #cards == 0 then context.EmptyMessage = "No upgrades are available for this module." end
	else
		table.insert(cards, { Id = "Colour", ImageKey = target, DisplayName = target == "Cockpit" and "Change Colour" or "Colour", OnSelect = function() State.CustomizeMode = "Colour"; renderCustomise() end })
		if target ~= "Cockpit" then table.insert(cards, { Id = "Cosmetics", ImageKey = "Neon", DisplayName = "Cosmetics", OnSelect = function() State.CustomizeMode = "Cosmetics"; renderCustomise() end }); table.insert(cards, { Id = "Performance", ImageKey = target, DisplayName = "Performance", OnSelect = function() State.CustomizeMode = "ModuleUpgrades"; State.PreviewUpgradeId = nil; renderCustomise() end }) end
	end
	UI.CanonicalGarageWorkspace:Show(context)
end

]=]
	source = replaceRange(source, "local function renderCosmetics()", "renderCustomise = function()", "-- NTR_GARAGE_WORKSPACE_RETIRED_LEGACY_COSMETICS_RENDERER\n", "Legacy cosmetics renderer")
	source = replaceRange(source, "renderCustomise = function()", "local function getHumanoid()", customiseBridge, "Customise renderer")

	source = replaceOnce(source,
		[[	if UI.CanonicalGarageBrowser and stage ~= "CockpitShop" then UI.CanonicalGarageBrowser:Hide() end]],
		[[	if UI.CanonicalGarageBrowser and stage ~= "CockpitShop" then UI.CanonicalGarageBrowser:Hide() end
	if UI.CanonicalGarageWorkspace and stage == "CockpitShop" then UI.CanonicalGarageWorkspace:Hide() end]], "Workspace page-router bridge")
end

if string.find(source, "NTR_GARAGE_WORKSPACE_BRIDGE_V1", 1, true) and not string.find(source, "NTR_GARAGE_WORKSPACE_SHARED_REUSE_V2", 1, true) then
	source = replaceOnce(source, "\t-- NTR_GARAGE_WORKSPACE_BRIDGE_V1", "\t-- NTR_GARAGE_WORKSPACE_BRIDGE_V1\n\t-- NTR_GARAGE_WORKSPACE_SHARED_REUSE_V2", "Workspace V2 marker")
	source = replaceOnce(source, [[ShowLeft = false, BackVisible = false, NextText = "Build Modules"]], [[ShowLeft = false, BackVisible = false, ExitVisible = false, NextText = "Build Modules"]], "Paint locked navigation")
	source = replaceOnce(source, [[RenderStats = function(parent) NTRVehiclePhaseAO.renderStats(parent, currentStats()) end,
		OnChannel]], [[RenderStats = function(parent) local stats, base = currentStats(); local _, Calculator = NTRVehiclePhaseAO.performanceModules(); UI.CanonicalGarageWorkspace:DrawPerformance(parent, Calculator.CalculateLegacy(stats or {}), Calculator.CalculateLegacy(base or stats or {}), NTRVehiclePhaseAO.tierColor) end,
		OnChannel]], "Paint shared stats")
	source = replaceOnce(source, [[	UI.CanonicalGarageRefresh = redraw
	if State.ModuleMode == "Slots" then]], [[	UI.CanonicalGarageRefresh = redraw
	local function installedTemplateForSlot(slotId)
		local profile = State.Profile or {}; local currentVehicle = profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; local instanceId = currentVehicle and currentVehicle.InstalledModules and currentVehicle.InstalledModules[slotId]; local instance = instanceId and profile.OwnedModuleInstances and profile.OwnedModuleInstances[instanceId]; local templateId = instance and instance.TemplateId
		if templateId == nil or tostring(templateId) == "" then templateId = profile.InstalledModules and profile.InstalledModules[slotId] end
		return templateId, instanceId
	end
	local function coreModuleReadiness()
		local engine1 = installedTemplateForSlot("Engine1"); local engine2 = installedTemplateForSlot("Engine2"); local stabilisers = installedTemplateForSlot("Stabilisers"); local boost = installedTemplateForSlot("Boost")
		local function present(value) return value ~= nil and tostring(value) ~= "" end
		return present(engine1) or present(engine2), present(stabilisers), present(boost)
	end
	if State.ModuleMode == "Slots" then]], "Unified module installation state")
	source = replaceOnce(source, [=[local installedId = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[slot.SlotId]]=], [[local installedId = installedTemplateForSlot(slot.SlotId)]], "Slot badge shared state")
	source = replaceOnce(source, [=[local slotInfo = getSlot(State.SelectedSlot); local installed = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[State.SelectedSlot]; local currentVehicle = State.Profile and State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]; local installedInstanceId = currentVehicle and currentVehicle.InstalledModules and currentVehicle.InstalledModules[State.SelectedSlot]]=], [[local slotInfo = getSlot(State.SelectedSlot); local installed, installedInstanceId = installedTemplateForSlot(State.SelectedSlot)]], "Module option shared state")
	source = replaceRange(source, "\tlocal function renderModuleStats(parent)", "\tUI.CanonicalGarageWorkspace:Show({", "", "Retired duplicate module stats")
	source = replaceOnce(source, [[Title = "Build Modules", Subtitle = State.ModuleMode == "Options" and "Preview, then buy or equip." or "Choose a fixed module slot.", LeftItems = leftItems, Cards = cards, EmptyMessage = State.ModuleMode == "Options" and "No compatible modules are available." or nil, NextText = "Customise Modules"]], [[Title = "Build Modules", Subtitle = State.ModuleMode == "Options" and "Preview, then buy or equip." or "Choose a fixed module slot.", ShowLeft = State.ModuleMode ~= "Slots", ExitVisible = false, LeftItems = leftItems, Cards = cards, EmptyMessage = State.ModuleMode == "Options" and "No compatible modules are available." or nil, NextText = "Customise"]], "Module shared shell")
	source = replaceOnce(source, [[RenderStats = renderModuleStats]], [[RenderStats = function(parent) local stats, base = currentStats(); local _, Calculator = NTRVehiclePhaseAO.performanceModules(); UI.CanonicalGarageWorkspace:DrawPerformance(parent, Calculator.CalculateLegacy(stats or {}), Calculator.CalculateLegacy(base or stats or {}), NTRVehiclePhaseAO.tierColor) end]], "Module shared stats")
	source = replaceOnce(source, [[OnNext = function() local hasEngine, hasStabilisers, hasBoost = NTRVehiclePhaseAK.coreModuleEquipState(); if not (hasEngine and hasStabilisers and hasBoost) then]], [[OnNext = function() local hasEngine, hasStabilisers, hasBoost = coreModuleReadiness(); if not (hasEngine and hasStabilisers and hasBoost) then]], "Unified core readiness gate")
	source = replaceOnce(source, [[NextText = "Start Driving", Cash =]], [[NextText = "Start Driving", ExitVisible = false, Cash =]], "Customise locked navigation")
	source = replaceOnce(source, [[RenderStats = function(parent) NTRVehiclePhaseAO.renderStats(parent, currentStats()) end]], [[RenderStats = function(parent) local stats, base = currentStats(); local _, Calculator = NTRVehiclePhaseAO.performanceModules(); UI.CanonicalGarageWorkspace:DrawPerformance(parent, Calculator.CalculateLegacy(stats or {}), Calculator.CalculateLegacy(base or stats or {}), NTRVehiclePhaseAO.tierColor) end]], "Customise shared stats")
end

if string.find(source, "NTR_GARAGE_WORKSPACE_SHARED_REUSE_V2", 1, true) and not string.find(source, "NTR_GARAGE_INDEPENDENT_HOST_AND_ARTWORK_V3", 1, true) then
	source = replaceOnce(source, "\t-- NTR_GARAGE_WORKSPACE_SHARED_REUSE_V2", "\t-- NTR_GARAGE_WORKSPACE_SHARED_REUSE_V2\n\t-- NTR_GARAGE_INDEPENDENT_HOST_AND_ARTWORK_V3", "Workspace V3 marker")
	local constructorCount
	source, constructorCount = replaceAllPlain(source, ".new(UI.Gui, UI.Scale)", ".new()", "Canonical controller constructor")
	assert(constructorCount == 4, "Expected four canonical controller constructors, got " .. tostring(constructorCount))
	source = replaceOnce(source, [[		for _, slot in ipairs(sortedSlots()) do
			local installedId = installedTemplateForSlot(slot.SlotId)
			table.insert(cards, { Id = slot.SlotId, ImageKey = slot.SlotId, DisplayName = slotDisplayName(slot), Badge = installedId and "EQUIPPED" or nil, BadgeColor = Theme.Accent, OnSelect = function() clearPreviewModules(); State.SelectedSlot = slot.SlotId; State.ModuleMode = "Options"; State.ModuleOptionMode = "Owned"; State.SelectedModuleId = nil; State.SelectedModuleInstanceId = nil; setCameraSection(slot.SlotId); redraw() end })
		end]], [[		for _, artworkItem in ipairs(UI.CanonicalGarageWorkspace:ArtworkDefinitions("Build")) do
			local slot = getSlot(artworkItem.TargetId)
			if slot then local installedId = installedTemplateForSlot(slot.SlotId); table.insert(cards, { Id = slot.SlotId, ImageKey = artworkItem.TargetId, DisplayName = artworkItem.DisplayName, Badge = installedId and "EQUIPPED" or nil, BadgeColor = Theme.Accent, OnSelect = function() clearPreviewModules(); State.SelectedSlot = slot.SlotId; State.ModuleMode = "Options"; State.ModuleOptionMode = "Owned"; State.SelectedModuleId = nil; State.SelectedModuleInstanceId = nil; setCameraSection(slot.SlotId); redraw() end }) end
		end]], "Build category registry")
	local moduleImageCount
	source, moduleImageCount = replaceAllPlain(source, [[ImageKey = info and info.ModuleId or State.SelectedSlot]], [[ImageKey = State.SelectedSlot]], "Owned module category artwork")
	assert(moduleImageCount == 1, "Expected one owned-module artwork mapping")
	source, moduleImageCount = replaceAllPlain(source, [[ImageKey = info.ModuleId]], [[ImageKey = State.SelectedSlot]], "Buy module category artwork")
	assert(moduleImageCount == 1, "Expected one buy-module artwork mapping")
	source = replaceOnce(source, [[	table.insert(leftItems, { Id = "ALL", Text = "Customise All", Selected = target == "ALL", OnSelect = function() choose("ALL", "Colour", nil) end })
	table.insert(leftItems, { Id = "THRUST_COLOR", Text = "Thrust Colour", Selected = target == "THRUST_COLOR", OnSelect = function() choose("THRUST_COLOR", "Colour", nil) end })
	table.insert(leftItems, { Id = "Cockpit", Text = "Cockpit", Selected = target == "Cockpit", OnSelect = function() choose("Cockpit", "Overview", nil) end })
	for _, slot in ipairs(sortedSlots()) do if State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[slot.SlotId] then table.insert(leftItems, { Id = slot.SlotId, Text = slotDisplayName(slot), Selected = target == slot.SlotId, OnSelect = function() choose(slot.SlotId, "Overview", slot.SlotId) end }) end end]], [[	for _, artworkItem in ipairs(UI.CanonicalGarageWorkspace:ArtworkDefinitions("Customise")) do
		local targetId = artworkItem.TargetId; local special = targetId == "ALL" or targetId == "THRUST_COLOR" or targetId == "Cockpit"; local installed = State.Profile and State.Profile.InstalledModules and State.Profile.InstalledModules[targetId]
		if special or installed then table.insert(leftItems, { Id = targetId, Text = artworkItem.DisplayName, Selected = target == targetId, OnSelect = function() if targetId == "ALL" or targetId == "THRUST_COLOR" then choose(targetId, "Colour", nil) elseif targetId == "Cockpit" then choose(targetId, "Overview", nil) else choose(targetId, "Overview", targetId) end end }) end
	end]], "Customise category registry")
	source = replaceOnce(source, [[ImageKey = "Neon", DisplayName = "Neon Lights"]], [[ImageKey = target, DisplayName = "Neon Lights"]], "Cosmetic category artwork")
	source = replaceOnce(source, [[Id = upgrade.UpgradeId, ImageKey = moduleId]], [[Id = upgrade.UpgradeId, ImageKey = slotId]], "Upgrade category artwork")
end

if not string.find(source, "NTR_GARAGE_PRESENTATION_OWNER_BRIDGE_V1", 1, true) then
	source = replaceOnce(source, [[	-- NTR_GARAGE_REPLACEMENT_BROWSER_BRIDGE_V1]], [[	-- NTR_GARAGE_REPLACEMENT_BROWSER_BRIDGE_V1
	-- NTR_GARAGE_PRESENTATION_OWNER_BRIDGE_V1]], "Presentation owner bridge marker")
	source = replaceOnce(source,
		[[	local ownedCount, capacity = NTR_phase8GarageCapacitySummary()
	UI.CanonicalGarageBrowser:Show({]],
		[[	local ownedCount, capacity = NTR_phase8GarageCapacitySummary()
	UI.CanonicalGarageRefresh = function() renderCockpitShop() end
	UI.CanonicalGarageBrowser:Show({]], "Browser canonical refresh")
	if not string.find(source, "UI.CanonicalGarageRefresh = function() renderCockpitPaint() end", 1, true) then
		source = replaceOnce(source,
			[[	local channels = { "Primary", "Secondary", "Detail" }
	UI.CanonicalGarageWorkspace:Show({]],
			[[	local channels = { "Primary", "Secondary", "Detail" }
	UI.CanonicalGarageRefresh = function() renderCockpitPaint() end
	UI.CanonicalGarageWorkspace:Show({]], "Paint canonical refresh")
	end
	if not string.find(source, "UI.CanonicalGarageRefresh = redraw", 1, true) then
		source = replaceOnce(source,
			[[	local function redraw() renderModuleShop() end]],
			[[	local function redraw() renderModuleShop() end
	UI.CanonicalGarageRefresh = redraw]], "Module canonical refresh")
	end
	if not string.find(source, "UI.CanonicalGarageRefresh = function() renderCustomise() end", 1, true) then
		source = replaceOnce(source,
			[[	local function choose(newTarget, mode, cameraSlot) State.CustomizeTarget = newTarget; State.CustomizeMode = mode; State.SelectedSlot = cameraSlot or State.SelectedSlot; setCameraSection(cameraSlot); renderCustomise() end]],
			[[	local function choose(newTarget, mode, cameraSlot) State.CustomizeTarget = newTarget; State.CustomizeMode = mode; State.SelectedSlot = cameraSlot or State.SelectedSlot; setCameraSection(cameraSlot); renderCustomise() end
	UI.CanonicalGarageRefresh = function() renderCustomise() end]], "Customise canonical refresh")
	end
	source = replaceOnce(source,
		[[		renderGarageCapacityPanel = NTR_phase8RenderGarageCapacityPanel,
	}]],
		[[		renderGarageCapacityPanel = NTR_phase8RenderGarageCapacityPanel,
		onProfileChanged = function() if UI.CanonicalGarageRefresh then UI.CanonicalGarageRefresh() end end,
	}]], "Property refresh context")
end

compile("PatchedBootstrap", source)
assert(#source < 195000, "Patched bootstrap is too close to Studio's 200000-character Source limit: " .. tostring(#source))
assert(string.find(source, "NTR_GARAGE_WORKSPACE_SHARED_REUSE_V2", 1, true), "Workspace V2 bootstrap bridge missing")
assert(string.find(source, "NTR_GARAGE_INDEPENDENT_HOST_AND_ARTWORK_V3", 1, true), "Workspace V3 bootstrap bridge missing")
assert(not string.find(source, ".new(UI.Gui, UI.Scale)", 1, true), "Canonical controllers still depend on the legacy UI scale")
if MODE == "AUDIT" then auditArtworkSchema(); print("[NTR Garage Workspace V3.1] AUDIT PASS"); return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")
installArtworkSchema()
auditArtworkSchema()
local workspaceController = ensure(uiControllers, "ModuleScript", "GarageWorkspaceController")
local artworkRegistry = ensure(uiControllers, "ModuleScript", "GarageModuleArtworkRegistry")
components.Source = componentsSource
browserController.Source = browserSource
propertyController.Source = propertySource
workspaceController.Source = controllerSource
artworkRegistry.Source = artworkRegistrySource
bootstrap.Source = source
bootstrap:SetAttribute("CanonicalGarageWorkspace", "NTR_GARAGE_WORKSPACE_REMAINING_MENUS_V3_1")
assert(string.find(bootstrap.Source, "NTR_GARAGE_WORKSPACE_BRIDGE_V1", 1, true), "Workspace bridge missing")
assert(workspaceController.Parent == uiControllers, "Workspace controller missing")
assert(artworkRegistry.Parent == uiControllers, "Module artwork registry missing")
print("[NTR Garage Workspace V3.1] INSTALL PASS (bootstrap chars=" .. tostring(#source) .. ")")
print("[NTR Garage Workspace V3.1] CanonicalGarageGui is independent of legacy scaling. ModuleArtwork contains category folders with attributes only.")
print("[NTR Garage Workspace V3.1] Restart Play and verify Dealership -> Paint -> Slots -> Owned/Buy -> Customise -> Start Driving, property/cash modals, card-centred actions, repeated page transitions, and PC/mobile scaling.")
