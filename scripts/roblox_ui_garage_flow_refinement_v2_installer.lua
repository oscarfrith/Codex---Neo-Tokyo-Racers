-- Neo Tokyo Racers - Canonical garage flow refinement installer V2
-- NTR_GARAGE_FLOW_REFINEMENT_V2
-- Run once from the Studio Edit Command Bar in Edit mode, then restart Play.
-- Atomic and rollback-safe: routing, shared headers, paint palette, floating
-- build navigation, Customise/All actions, and category-wheel forwarding.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_FLOW_REFINEMENT_V2"
local PREFIX="[NTR Garage Flow Refinement V2]"
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local function need(parent,name,className)
	local object=parent:FindFirstChild(name); assert(object,parent:GetFullName().."."..name.." missing")
	if className then assert(object:IsA(className),object:GetFullName().." must be "..className) end
	return object
end
local function compile(name,source) local fn,err=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(err)) end
local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true); assert(first,"Missing source anchor: "..label)
	assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label)
	return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end
local function replaceSection(source,startMarker,endMarker,replacement,label)
	local first=string.find(source,startMarker,1,true); assert(first,"Missing section start: "..label)
	assert(not string.find(source,startMarker,first+#startMarker,true),"Duplicate section start: "..label)
	local finish=string.find(source,endMarker,first+#startMarker,true); assert(finish,"Missing section end: "..label)
	return string.sub(source,1,first-1)..replacement.."\n"..string.sub(source,finish)
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local uiConfig=need(need(need(kit,"Config","Folder"),"UI","Folder"),"GarageReplacement","Folder")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local uiRoot=need(need(clientRoot,"Controllers","Folder"),"UI","Folder")
local shared=need(uiRoot,"GarageReplacementComponents","ModuleScript")
local workspaceController=need(uiRoot,"GarageWorkspaceController","ModuleScript")
local browserController=need(uiRoot,"GarageBrowserController","ModuleScript")
local applicationController=need(uiRoot,"ModuleShopUIController","ModuleScript")

local sharedSource,workspaceSource,browserSource,applicationSource=shared.Source,workspaceController.Source,browserController.Source,applicationController.Source
for name,source in pairs({Shared=sharedSource,Workspace=workspaceSource,Browser=browserSource,Application=applicationSource}) do
	assert(string.find(source,"NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1",1,true),name.." confirmed V1 navigation baseline missing")
	assert(not string.find(source,REVISION,1,true),name.." already contains V2; use MODE=AUDIT instead of reinstalling")
end
assert(string.find(sharedSource,"NTR_GARAGE_RESPONSIVE_SCALED_TOUCH_V1_2",1,true),"Responsive shared baseline missing")

sharedSource=replaceOnce(sharedSource,
	[[local function responsiveNumber(N,name,fallback) local value=responsiveConfig:GetAttribute(name); if typeof(value)=="number" then return value end; return N(name,fallback) end]],
	[[local function responsiveNumber(N,name,fallback) local value=responsiveConfig:GetAttribute(name); if typeof(value)=="number" then return value end; return N(name,fallback) end
function M.HeaderTextSizes() return responsiveNumber(function(_,fallback) return fallback end,"HeaderTitleTextSize",22),responsiveNumber(function(_,fallback) return fallback end,"HeaderSubtitleTextSize",15) end -- NTR_GARAGE_FLOW_REFINEMENT_V2]],
	"shared header token owner")
sharedSource=replaceOnce(sharedSource,
	[[ui.Header.AnchorPoint=Vector2.new(.5,0); ui.Header.Position=UDim2.fromOffset(vw*.5,28); ui.Header.Size=UDim2.fromOffset(420,62)]],
	[[ui.Header.AnchorPoint=Vector2.new(.5,0); ui.Header.Position=UDim2.fromOffset(vw*.5,28); ui.Header.Size=UDim2.fromOffset(420,responsiveNumber(N,"HeaderHeight",68))]],
	"shared header geometry")
sharedSource="-- "..REVISION.."\n"..sharedSource

workspaceSource=replaceOnce(workspaceSource,
	[[local WorkspaceUI={}; WorkspaceUI.__index=WorkspaceUI]],
	[[local WorkspaceUI={}; WorkspaceUI.__index=WorkspaceUI
local headerTitleSize,headerSubtitleSize=Shared.HeaderTextSizes() -- NTR_GARAGE_FLOW_REFINEMENT_V2]],
	"workspace shared header sizes")
workspaceSource=replaceOnce(workspaceSource,
	[[TextSize=N("HeaderTitleTextSize",20)]],[[TextSize=headerTitleSize]],"workspace header title")
workspaceSource=replaceOnce(workspaceSource,
	[[TextSize=N("HeaderSubtitleTextSize",14)]],[[TextSize=headerSubtitleSize]],"workspace header subtitle")
workspaceSource=replaceOnce(workspaceSource,
	[[local categoryPad=Instance.new("UIPadding"); categoryPad.PaddingTop=UDim.new(0,6); categoryPad.PaddingBottom=UDim.new(0,6); categoryPad.PaddingLeft=UDim.new(0,6); categoryPad.PaddingRight=UDim.new(0,6); categoryPad.Parent=self.CategoryList]],
	[[local categoryPad=Instance.new("UIPadding"); categoryPad.PaddingTop=UDim.new(0,6); categoryPad.PaddingBottom=UDim.new(0,6); categoryPad.PaddingLeft=UDim.new(0,6); categoryPad.PaddingRight=UDim.new(0,6); categoryPad.Parent=self.CategoryList
	self.CategoryWheelConnection=UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.MouseWheel or not (self.Root.Visible and self.Categories.Visible and self.CategoryList.Visible) then return end
		local point=UserInputService:GetMouseLocation(); local position,size=self.CategoryList.AbsolutePosition,self.CategoryList.AbsoluteSize
		if point.X<position.X or point.X>position.X+size.X or point.Y<position.Y or point.Y>position.Y+size.Y then return end
		local maximum=math.max(0,self.CategoryList.AbsoluteCanvasSize.Y-size.Y); if maximum<=0 then return end
		self.CategoryList.CanvasPosition=Vector2.new(0,math.clamp(self.CategoryList.CanvasPosition.Y-input.Position.Z*(tonumber(cfg:GetAttribute("CategoryWheelStep")) or 48),0,maximum))
	end) -- NTR_GARAGE_FLOW_REFINEMENT_V2]],
	"category wheel forwarding")
workspaceSource=replaceOnce(workspaceSource,
	[[clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	if not self.Categories.Visible then return end]],
	[[clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	self.Categories.BackgroundTransparency=context.LeftFloating and 1 or .12; local surface=self.Categories:FindFirstChild("SurfaceGradient"); if surface and surface:IsA("UIGradient") then surface.Enabled=not context.LeftFloating end
	if not self.Categories.Visible then return end]],
	"floating category presentation")

local paintRenderer=[====[
function WorkspaceUI:RenderPaint(context)
	self.Popup:Hide(); self.Budget.Visible=false; self.Scroller.Visible=false; self.Paint.Visible=true; clear(self.Paint); local channels=context.ColorChannels or {}; local selected=context.SelectedChannel or channels[1]; if not selected then return end
	local current=(context.Colors and context.Colors[selected]) or Color3.new(1,1,1); local h,s,v=Color3.toHSV(current); self.PaintHSV={h,s,v}; self.PaintChannel=selected
	local configuredWidth=tonumber(cfg:GetAttribute("WorkspacePaintWideWidth")) or 900; local width=math.min(configuredWidth,self.ReferenceCarouselWidth or configuredWidth)
	local tabs=generated(Instance.new("Frame")); tabs.Name="PaintTabs"; tabs.BackgroundTransparency=1; tabs.AnchorPoint=Vector2.new(.5,1); tabs.Position=UDim2.new(.5,0,.5,-86); tabs.Size=UDim2.fromOffset(width,34); tabs.Parent=self.Paint
	local panel=generated(Shared.Panel(self.Paint,"PaintControls",{StrokeColor=Racing.Colour("ElectricBlue"),StrokeTransparency=.35,NoGlow=true})); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(width,156)
	local tabWidth=math.max(96,(width-math.max(0,#channels-1)*8)/math.max(1,#channels)); for index,channel in ipairs(channels) do local b=generated(Racing.Button(tabs,{Text=string.upper(channel),Position=UDim2.fromOffset((index-1)*(tabWidth+8),1),Size=UDim2.fromOffset(tabWidth,32),Color=channel==selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); b.Activated:Connect(function() context.OnChannel(channel) end) end
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
]====]
workspaceSource=replaceSection(workspaceSource,"function WorkspaceUI:RenderPaint(context)","function WorkspaceUI:QueueCarouselUpdate()",paintRenderer,"paint V2 renderer")
workspaceSource="-- "..REVISION.."\n"..workspaceSource

browserSource=replaceOnce(browserSource,
	[[local Browser={}; Browser.__index=Browser]],
	[[local Browser={}; Browser.__index=Browser
local headerTitleSize,headerSubtitleSize=Shared.HeaderTextSizes() -- NTR_GARAGE_FLOW_REFINEMENT_V2]],
	"browser shared header sizes")
browserSource=replaceOnce(browserSource,[[TextSize=RN("MetricHeadingSize",15)+2]],[[TextSize=headerTitleSize]],"browser title size")
browserSource=replaceOnce(browserSource,[[TextSize=12,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Metric"}]],[[TextSize=headerSubtitleSize,Color=Racing.Colour("Text",Color3.new(1,1,1)),XAlignment=Enum.TextXAlignment.Center,Role="Heading"}]],"browser subtitle size")
browserSource="-- "..REVISION.."\n"..browserSource

applicationSource=replaceOnce(applicationSource,
	[[OnPrimary=function(row) local r;if State.ShopMode=="Customisation" then r=action:Call("SelectVehicleInstance",{VehicleId=row.VehicleId,CockpitId=row.CockpitId}) else r=action:Call("BuyCockpitInstance",{CockpitId=row.CockpitId,CategoryId=row.CategoryId}) end; if not r.Success then browser.Subtitle.Text=r.Message or "Could not select vehicle."; return end; State.PreviewProfile=nil; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"; State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; buildPreview(); if State.ShopMode=="Customisation" then renderHub() else renderPaint() end end,]],
	[[OnPrimary=function(row) local selectionMode=State.ShopMode; local selectingOwned=selectionMode=="Customisation"; local r;if selectingOwned then r=action:Call("SelectVehicleInstance",{VehicleId=row.VehicleId,CockpitId=row.CockpitId}) else r=action:Call("BuyCockpitInstance",{CockpitId=row.CockpitId,CategoryId=row.CategoryId}) end; if not r.Success then browser.Subtitle.Text=r.Message or "Could not select vehicle."; return end; State.PreviewProfile=nil; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"; State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; buildPreview(); print("[NTR Garage Route] selection="..selectionMode.." destination="..(selectingOwned and "Hub" or "Paint")); if selectingOwned then renderHub() else renderPaint() end end, -- NTR_GARAGE_FLOW_REFINEMENT_V2]],
	"immutable selection route")
applicationSource=replaceOnce(applicationSource,
	[[{Id="CustomiseModules",Image=navIcon("CustomiseModulesIcon"),ImageZoom=.5,DisplayName="Customise Modules",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; buildPreview(); renderCustomise() end},]],
	[[{Id="CustomiseModules",Image=navIcon("CustomiseModulesIcon"),ImageZoom=.5,DisplayName="Customise Modules",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; buildPreview(); renderCustomise() end},]],
	"hub customise overview route")
applicationSource=replaceOnce(applicationSource,
	[[State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or (State.ModuleMode=="Sources" and "Choose owned modules or buy modules." or "Preview, then buy or equip."); c.ShowLeft=false; c.BackVisible=true;]],
	[[State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or (State.ModuleMode=="Sources" and "Choose owned modules or buy modules." or "Preview, then buy or equip."); c.ShowLeft=true; c.LeftFloating=true; c.LeftCardMode=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78; c.LeftItems={{Id="BuildModules",Text="Build Modules",Image=navIcon("BuildModulesIcon"),Selected=true,OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},{Id="CustomiseModules",Text="Customise Modules",Image=navIcon("CustomiseModulesIcon"),Selected=false,OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; buildPreview(); renderCustomise() end}}; c.BackVisible=true;]],
	"build floating shared sidebar")
applicationSource=replaceOnce(applicationSource,
	[[local function colourChannels(target) if target=="THRUST_COLOR" then return {"ThrustColor"} end; if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end; if target=="ALL" then return {"Primary","Secondary","Detail","Neon"} end; return {"Primary","Secondary","Detail","Neon"} end]],
	[[local function colourChannels(target) if target=="THRUST_COLOR" then return {"ThrustColor"} end; if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end; if target=="ALL" then return {"Primary","Secondary","Detail"} end; return {"Primary","Secondary","Detail","Neon"} end]],
	"All change-colour channel scope")
applicationSource=replaceOnce(applicationSource,
	[[State.CustomizeMode=(id=="ALL" or id=="THRUST_COLOR") and "Colour" or "Overview"]],
	[[State.CustomizeMode=id=="THRUST_COLOR" and "Colour" or "Overview"]],
	"All overview selection")
applicationSource=replaceOnce(applicationSource,
	[[if target=="ALL" or target=="THRUST_COLOR" or State.CustomizeMode=="Colour" then
		local channels=colourChannels(target); local colours={}]],
	[[if target=="THRUST_COLOR" or State.CustomizeMode=="Colour" or State.CustomizeMode=="Underglow" then
		local channels=State.CustomizeMode=="Underglow" and {"Neon"} or colourChannels(target); local colours={}]],
	"All colour and underglow editor")
applicationSource=replaceOnce(applicationSource,
	[[else
		table.insert(c.Cards,{Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName=target=="Cockpit" and "Change Colour" or "Colour",OnSelect=function() State.CustomizeMode="Colour"; renderCustomise() end})]],
	[[else
		if target=="ALL" then
			table.insert(c.Cards,{Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName="Change Colour",OnSelect=function() State.CustomizeMode="Colour"; renderCustomise() end})
			table.insert(c.Cards,{Id="Underglow",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),ImageZoom=actionIconScale,DisplayName="Underglow",OnSelect=function() State.CustomizeMode="Underglow"; renderCustomise() end})
		else table.insert(c.Cards,{Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName=target=="Cockpit" and "Change Colour" or "Colour",OnSelect=function() State.CustomizeMode="Colour"; renderCustomise() end}) end]],
	"All bottom actions")
applicationSource=replaceOnce(applicationSource,
	[[if target~="Cockpit" then
			table.insert(c.Cards,{Id="Cosmetics"]],
	[[if target~="Cockpit" and target~="ALL" then
			table.insert(c.Cards,{Id="Cosmetics"]],
	"All generic action suppression")
applicationSource=replaceOnce(applicationSource,
	[[c.OnBack=function() clearTransientModulePreview(); if State.CustomizeMode~="Overview" and target~="ALL" then State.CustomizeMode="Overview"; renderCustomise() else buildPreview(); renderHub() end end]],
	[[c.OnBack=function() clearTransientModulePreview(); if State.CustomizeMode~="Overview" then State.CustomizeMode="Overview"; renderCustomise() else buildPreview(); renderHub() end end]],
	"customise nested back route")
applicationSource=replaceOnce(applicationSource,
	[[for name,mode in pairs({OpenGarageFromIntro="Dealership",OpenOwnedCockpitCustomisation="Customisation",OpenDrivingVehicleCustomisation="DriveIn"}) do introEvent(name).Event:Connect(function() open(mode) end) end]],
	[[local function bindGarageOpen(name,mode) introEvent(name).Event:Connect(function() print("[NTR Garage Route] event="..name.." mode="..mode); open(mode) end) end
bindGarageOpen("OpenGarageFromIntro","Dealership"); bindGarageOpen("OpenOwnedCockpitCustomisation","Customisation"); bindGarageOpen("OpenDrivingVehicleCustomisation","DriveIn") -- NTR_GARAGE_FLOW_REFINEMENT_V2]],
	"explicit entrance bindings")
applicationSource="-- "..REVISION.."\n"..applicationSource

compile("GarageReplacementComponents",sharedSource); compile("GarageWorkspaceController",workspaceSource); compile("GarageBrowserController",browserSource); compile("ModuleShopUIController",applicationSource)
for name,source in pairs({GarageReplacementComponents=sharedSource,GarageWorkspaceController=workspaceSource,GarageBrowserController=browserSource,ModuleShopUIController=applicationSource}) do assert(#source<199000,name.." projected Source is too large for safe Studio assignment ("..#source..")") end

local numericValues={PaintPaletteColumns=15,HeaderTitleTextSize=22,HeaderSubtitleTextSize=15,HeaderHeight=68,CategoryWheelStep=48}
local function audit()
	local pass,fail=0,0; local function check(ok,message) if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end end
	check(string.find(shared.Source,REVISION,1,true)~=nil,"shared header owner installed")
	check(string.find(workspaceController.Source,REVISION,1,true)~=nil,"workspace paint/rail owner installed")
	check(string.find(browserController.Source,REVISION,1,true)~=nil,"browser shared header installed")
	check(string.find(applicationController.Source,REVISION,1,true)~=nil,"application flow owner installed")
	check(string.find(applicationController.Source,"local selectionMode=State.ShopMode",1,true)~=nil,"selection route captures immutable mode")
	check(string.find(applicationController.Source,'bindGarageOpen("OpenOwnedCockpitCustomisation","Customisation")',1,true)~=nil,"entrance events explicitly bound")
	check(string.find(workspaceController.Source,'Name="CurrentColour"',1,true)~=nil and string.find(workspaceController.Source,"local columns=15",1,true)~=nil,"15-column palette and current swatch installed")
	check(string.find(applicationController.Source,"c.LeftFloating=true",1,true)~=nil,"floating build/customise rail installed")
	check(string.find(applicationController.Source,'DisplayName="Underglow"',1,true)~=nil,"Customise All actions installed")
	check(string.find(workspaceController.Source,"CategoryWheelConnection",1,true)~=nil,"category wheel forwarding installed")
	check(string.find(shared.Source,"HeaderTextSizes",1,true)~=nil,"shared header text contract installed")
	check(uiConfig:GetAttribute("PaintPaletteColumns")==15 and uiConfig:GetAttribute("HeaderHeight")==68,"V2 layout config applied")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail)); return fail==0
end
if MODE=="AUDIT" then assert(audit(),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
local oldSources={Shared=shared.Source,Workspace=workspaceController.Source,Browser=browserController.Source,Application=applicationController.Source}; local oldNumeric={}; for name in pairs(numericValues) do oldNumeric[name]=uiConfig:GetAttribute(name) end
local ok,err=pcall(function()
	for name,value in pairs(numericValues) do uiConfig:SetAttribute(name,value) end
	shared.Source=sharedSource; workspaceController.Source=workspaceSource; browserController.Source=browserSource; applicationController.Source=applicationSource
	assert(audit(),"Post-install audit failed")
end)
if not ok then
	shared.Source=oldSources.Shared; workspaceController.Source=oldSources.Workspace; browserController.Source=oldSources.Browser; applicationController.Source=oldSources.Application
	for name,value in pairs(oldNumeric) do uiConfig:SetAttribute(name,value) end
	error("Garage flow refinement V2 rolled back: "..tostring(err))
end
print(PREFIX.." INSTALL COMPLETE - restart Play; verify Customisation routes to Garage, Dealership routes to Paint, the 15-column palette, both floating build nav cards, All actions, wheel scrolling, and shared headers.")
