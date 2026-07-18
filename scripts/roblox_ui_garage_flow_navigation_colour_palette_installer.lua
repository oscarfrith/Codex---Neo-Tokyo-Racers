-- Neo Tokyo Racers - Canonical garage flow/navigation/colour installer V1.1
-- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
-- V1.1 repairs the post-install audit: ModuleScripts have no Disabled property.
--
-- Run once from the Studio Edit Command Bar, then restart Play.
-- One atomic client-presentation transaction: shared action buttons and money
-- formatting, the new hub/source-picker route, the wider H/S/B colour picker,
-- palette swatches, and popup-safe responsive navigation.

local MODE = "INSTALL" -- INSTALL or AUDIT
local REVISION = "NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1"
local PREFIX = "[NTR Garage Flow Navigation Colour V1.1]"

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
local uiConfig = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")
local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local uiRoot = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local shared = need(uiRoot, "GarageReplacementComponents", "ModuleScript")
local workspaceController = need(uiRoot, "GarageWorkspaceController", "ModuleScript")
local browserController = need(uiRoot, "GarageBrowserController", "ModuleScript")
local applicationController = need(uiRoot, "ModuleShopUIController", "ModuleScript")

local sharedSource = shared.Source
local workspaceSource = workspaceController.Source
local browserSource = browserController.Source
local applicationSource = applicationController.Source

assert(string.find(sharedSource, "NTR_GARAGE_RESPONSIVE_SCALED_TOUCH_V1_2", 1, true), "Confirmed responsive V1.2 shared baseline missing")
assert(string.find(workspaceSource, "NTR_GARAGE_RESPONSIVE_BUDGET_V1_2", 1, true), "Confirmed responsive V1.2 workspace baseline missing")
assert(string.find(applicationSource, "NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE_V1", 1, true), "Transient preview lifecycle baseline missing")
assert(string.find(applicationSource, "NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1", 1, true), "Atomic module transaction baseline missing")

if not string.find(sharedSource, REVISION, 1, true) then
	local sharedUtilities = [====[
local M={}
-- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
function M.FormatNumber(value)
	local numeric=tonumber(value) or 0; local negative=numeric<0; local digits=tostring(math.floor(math.abs(numeric)+.5)); local reversed=string.gsub(string.reverse(digits),"(%d%d%d)","%1,"); local grouped=string.gsub(string.reverse(reversed),"^,",""); return (negative and "-" or "")..grouped
end
function M.FormatMoney(value) return "$"..M.FormatNumber(value) end
function M.ActionButton(parent,props)
	props=props or {}; local button=Racing.Button(parent,{Name=props.Name or "GarageAction",Text="",Size=props.Size or UDim2.fromOffset(170,46),Color=props.Color or Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=props.StrokeColor or Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),FocusColor=props.FocusColor or Racing.Colour("Telemetry")}); button:SetAttribute("CanonicalGarageAction",true)
	local group=Instance.new("Frame"); group.Name="ActionContent"; group.AnchorPoint=Vector2.new(.5,.5); group.Position=UDim2.fromScale(.5,.5); group.Size=UDim2.new(0,0,1,0); group.AutomaticSize=Enum.AutomaticSize.X; group.BackgroundTransparency=1; group.ZIndex=button.ZIndex+1; group.Parent=button
	local layout=Instance.new("UIListLayout"); layout.FillDirection=Enum.FillDirection.Horizontal; layout.HorizontalAlignment=Enum.HorizontalAlignment.Center; layout.VerticalAlignment=Enum.VerticalAlignment.Center; layout.Padding=UDim.new(0,8); layout.Parent=group
	local image=Instance.new("ImageLabel"); image.Name="ActionIcon"; image.BackgroundTransparency=1; image.BorderSizePixel=0; image.Size=UDim2.fromOffset(22,22); image.ImageColor3=Racing.Colour("Text",Color3.new(1,1,1)); image.ZIndex=group.ZIndex+1; image.Parent=group
	local glyph=Instance.new("TextLabel"); glyph.Name="ActionGlyph"; glyph.BackgroundTransparency=1; glyph.Size=UDim2.fromOffset(22,26); glyph.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); glyph.TextSize=22; glyph.TextXAlignment=Enum.TextXAlignment.Center; glyph.TextYAlignment=Enum.TextYAlignment.Center; glyph.ZIndex=group.ZIndex+1; Racing.Font(glyph,"Heading"); glyph.Parent=group
	local label=Instance.new("TextLabel"); label.Name="ActionText"; label.BackgroundTransparency=1; label.AutomaticSize=Enum.AutomaticSize.X; label.Size=UDim2.new(0,0,1,0); label.TextColor3=Racing.Colour("Text",Color3.new(1,1,1)); label.TextSize=14; label.TextXAlignment=Enum.TextXAlignment.Center; label.TextYAlignment=Enum.TextYAlignment.Center; label.ZIndex=group.ZIndex+1; Racing.Font(label,"Heading"); label.Parent=group
	M.SetActionButton(button,props.Text,props.Icon,props.IconText); return button
end
function M.SetActionButton(button,text,icon,iconText)
	local group=button and button:FindFirstChild("ActionContent"); if not group then button.Text=string.upper(tostring(text or "")); return end
	local image=group:FindFirstChild("ActionIcon"); local glyph=group:FindFirstChild("ActionGlyph"); local label=group:FindFirstChild("ActionText"); local imageText=tostring(icon or ""); if image then image.Image=imageText; image.Visible=imageText~="" end; if glyph then glyph.Text=tostring(iconText or ""); glyph.Visible=imageText=="" and glyph.Text~="" end; if label then label.Text=string.upper(tostring(text or "")) end
end
]====]
	sharedSource = replaceOnce(sharedSource, "local M={}", sharedUtilities, "shared utility insertion")
	sharedSource = replaceOnce(sharedSource,
		[[local priceText=props.PriceText or (props.Price~=nil and ("$"..tostring(props.Price)) or nil)]],
		[[local priceText=props.PriceText or (props.Price~=nil and M.FormatMoney(props.Price) or nil)]],
		"listing-card money formatting")
	sharedSource = replaceOnce(sharedSource,
		[[for _,object in ipairs(ui.Root:GetDescendants()) do if object:IsA("TextLabel") and object.Name=="Price" and string.find(string.upper(tostring(object.Text)),"POINT LIMIT REACHED",1,true) then expect(object.TextTruncate==Enum.TextTruncate.None,"point-limit status truncation enabled"); expect(object.TextBounds.X<=object.AbsoluteSize.X+2,"point-limit status exceeds label") end end]],
		[[for _,object in ipairs(ui.Root:GetDescendants()) do if object:IsA("TextLabel") and object.Name=="Price" and string.find(string.upper(tostring(object.Text)),"LIMIT REACHED",1,true) then expect(object.TextTruncate==Enum.TextTruncate.None,"limit status truncation enabled"); expect(object.TextBounds.X<=object.AbsoluteSize.X+2,"limit status exceeds label") end end]],
		"responsive limit audit")
	sharedSource = replaceOnce(sharedSource,
		[[local actionX=vw-margin; for _,actionButton in ipairs(options.Actions or {}) do if actionButton.Visible then actionButton.AnchorPoint=Vector2.new(1,1); actionButton.Position=UDim2.fromOffset(actionX,carouselTop-gap); actionX-=actionButton.Size.X.Offset+gap end end]],
		[[local actionWidth=(N("StatsWidth",354)-gap)*.5; local actionHeight=responsiveNumber(N,"NavigationButtonHeight",N("EconomyHeight",46)); local actionBottom=carouselTop-responsiveNumber(N,"NavigationPopupClearance",48); local actionX=vw-margin; for _,actionButton in ipairs(options.Actions or {}) do if actionButton.Visible then actionButton.AnchorPoint=Vector2.new(1,1); actionButton.Size=UDim2.fromOffset(actionWidth,actionHeight); actionButton.Position=UDim2.fromOffset(actionX,actionBottom); actionX-=actionWidth+gap end end]],
		"popup-safe action lane")
	sharedSource = replaceOnce(sharedSource,
		[[if ui.Popup and ui.Popup.Shell.Visible and ui.Budget and ui.Budget.Visible then expect(ui.Budget.AbsolutePosition.Y+ui.Budget.AbsoluteSize.Y<=ui.Popup.Shell.AbsolutePosition.Y-2,"budget overlaps card action") end]],
		[[if ui.Popup and ui.Popup.Shell.Visible then for _,button in ipairs(options.Actions or {}) do if button.Visible then expect(button.AbsolutePosition.Y+button.AbsoluteSize.Y<=ui.Popup.Shell.AbsolutePosition.Y-2,"navigation overlaps card action popup") end end; if ui.Budget and ui.Budget.Visible then expect(ui.Budget.AbsolutePosition.Y+ui.Budget.AbsoluteSize.Y<=ui.Popup.Shell.AbsolutePosition.Y-2,"budget overlaps card action") end end]],
		"navigation popup overlap audit")
end

if not string.find(workspaceSource, REVISION, 1, true) then
	workspaceSource = replaceOnce(workspaceSource,
		[[self.Back=Racing.Button(self.Root,{Name="Back",Text="BACK",Size=UDim2.fromOffset(88,30),Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})
	self.Next=Racing.Button(self.Root,{Name="Continue",Text="NEXT",Size=UDim2.fromOffset(154,30),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=outline})
	self.Exit=Racing.Button(self.Root,{Name="Exit",Text="EXIT",Size=UDim2.fromOffset(76,30),Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})]],
		[[self.Back=Shared.ActionButton(self.Root,{Name="Back",Text="BACK",IconText="<",Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})
	self.Next=Shared.ActionButton(self.Root,{Name="Continue",Text="DRIVE",Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=outline})
	self.Exit=Shared.ActionButton(self.Root,{Name="Exit",Text="EXIT",IconText="X",Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")}) -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1]],
		"workspace shared action buttons")

	local economyRenderer = [====[
function WorkspaceUI:RenderEconomy(context)
	clear(self.Cash); clear(self.Capacity)
	generated(Racing.Label(self.Cash,{Text=Shared.FormatMoney(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=N("EconomyCashTextSize",17),Color=Color3.fromRGB(89,255,102),Role="Heading"})); local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if context.OnCash then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity
	generated(Racing.Label(self.Capacity,{Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=N("EconomySpacesTextSize",13),Role="Heading"})); local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if context.OnCapacity then context.OnCapacity() end end)
end
]====]
	workspaceSource = replaceSection(workspaceSource, "function WorkspaceUI:RenderEconomy(context)", "function WorkspaceUI:DrawPerformance", economyRenderer, "workspace economy renderer")

	local paintRenderer = [====[
function WorkspaceUI:RenderPaint(context)
	self.Popup:Hide(); self.Budget.Visible=false; self.Scroller.Visible=false; self.Paint.Visible=true; clear(self.Paint); local channels=context.ColorChannels or {}; local selected=context.SelectedChannel or channels[1]; if not selected then return end
	local current=(context.Colors and context.Colors[selected]) or Color3.new(1,1,1); local h,s,v=Color3.toHSV(current); self.PaintHSV={h,s,v}; self.PaintChannel=selected
	local configuredWidth=tonumber(cfg:GetAttribute("WorkspacePaintWideWidth")) or 900; local width=math.min(configuredWidth,self.ReferenceCarouselWidth or configuredWidth); local panel=generated(Shared.Panel(self.Paint,"PaintControls",{StrokeColor=Racing.Colour("ElectricBlue"),StrokeTransparency=.35,NoGlow=true})); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(width,156)
	local tabWidth=math.max(96,(width-16-math.max(0,#channels-1)*8)/math.max(1,#channels)); for index,channel in ipairs(channels) do local b=generated(Racing.Button(panel,{Text=string.upper(channel),Position=UDim2.fromOffset(8+(index-1)*(tabWidth+8),7),Size=UDim2.fromOffset(tabWidth,30),Color=channel==selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); b.Activated:Connect(function() context.OnChannel(channel) end) end
	local gradients,knobs={},{}
	local function refreshGradients()
		if gradients[1] then gradients[1].Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.17,Color3.fromHSV(.17,1,1)),ColorSequenceKeypoint.new(.33,Color3.fromHSV(.33,1,1)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(.5,1,1)),ColorSequenceKeypoint.new(.67,Color3.fromHSV(.67,1,1)),ColorSequenceKeypoint.new(.83,Color3.fromHSV(.83,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))}) end
		if gradients[2] then gradients[2].Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromHSV(self.PaintHSV[1],1,1)) end
		if gradients[3] then gradients[3].Color=ColorSequence.new(Color3.new(0,0,0),Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],1)) end
	end
	local function refreshKnobs() for index,knob in ipairs(knobs) do knob.Position=UDim2.fromScale(self.PaintHSV[index],.5) end end
	local function emit(commit) if context.OnColor then context.OnColor(selected,Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],self.PaintHSV[3]),commit==true) end end
	local sliderGap=16; local sliderX=14; local sliderWidth=(width-28-sliderGap*2)/3
	local function slider(labelText,index,column)
		local x=sliderX+(column-1)*(sliderWidth+sliderGap); generated(Racing.Label(panel,{Text=labelText,Position=UDim2.fromOffset(x,42),Size=UDim2.fromOffset(sliderWidth,17),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}))
		local track=generated(Instance.new("Frame")); track.Active=true; track.BackgroundColor3=Color3.new(1,1,1); track.BorderSizePixel=0; track.Position=UDim2.fromOffset(x,64); track.Size=UDim2.fromOffset(sliderWidth,10); track.Parent=panel; Racing.Corner(track,5)
		local gradient=Instance.new("UIGradient"); gradient.Parent=track; gradients[index]=gradient
		local knob=generated(Instance.new("Frame")); knob.AnchorPoint=Vector2.new(.5,.5); knob.Position=UDim2.fromScale(self.PaintHSV[index],.5); knob.Size=UDim2.fromOffset(5,18); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=8; knob.Parent=track; Racing.Corner(knob,3); knobs[index]=knob
		local function update(input) local xValue=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); self.PaintHSV[index]=xValue; refreshKnobs(); refreshGradients(); emit(false) end
		table.insert(self.Dynamic,track.InputBegan:Connect(function(input) if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; update(input); local move,endConnection; move=UserInputService.InputChanged:Connect(function(changed) if changed.UserInputType==Enum.UserInputType.MouseMovement or changed.UserInputType==Enum.UserInputType.Touch then update(changed) end end); endConnection=UserInputService.InputEnded:Connect(function(ended) if ended.UserInputType==input.UserInputType then move:Disconnect(); endConnection:Disconnect(); emit(true) end end) end))
	end
	slider("HUE",1,1); slider("SATURATION",2,2); slider("BRIGHTNESS",3,3); refreshGradients()
	local columns=math.clamp(math.floor(tonumber(cfg:GetAttribute("PaintPaletteColumns")) or 12),10,15); local swatchGap=6; local swatchX=14; local swatchWidth=(width-28-(columns-1)*swatchGap)/columns; local swatchHeight=24
	local function paletteColour(column,row)
		if column==1 then return row==1 and Color3.new(1,1,1) or Color3.fromRGB(168,168,168) end
		if column==columns then return row==1 and Color3.fromRGB(62,62,68) or Color3.new(0,0,0) end
		local hue=(column-2)/math.max(1,columns-3); return row==1 and Color3.fromHSV(hue,.48,1) or Color3.fromHSV(hue,.86,.42)
	end
	for row=1,2 do for column=1,columns do local colourValue=paletteColour(column,row); local swatch=generated(Instance.new("TextButton")); swatch.Name="Palette"..row.."_"..column; swatch.Text=""; swatch.AutoButtonColor=false; swatch.BackgroundColor3=colourValue; swatch.BorderSizePixel=0; swatch.Position=UDim2.fromOffset(swatchX+(column-1)*(swatchWidth+swatchGap),84+(row-1)*(swatchHeight+7)); swatch.Size=UDim2.fromOffset(swatchWidth,swatchHeight); swatch.ZIndex=7; swatch.Parent=panel; Racing.Corner(swatch,4); local stroke=Instance.new("UIStroke"); stroke.Color=Racing.Colour("Text",Color3.new(1,1,1)); stroke.Transparency=.56; stroke.Thickness=1; stroke.Parent=swatch; swatch.Activated:Connect(function() local ph,ps,pv=Color3.toHSV(colourValue); self.PaintHSV={ph,ps,pv}; refreshKnobs(); refreshGradients(); emit(true) end) end end
end -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
]====]
	workspaceSource = replaceSection(workspaceSource, "function WorkspaceUI:RenderPaint(context)", "function WorkspaceUI:QueueCarouselUpdate()", paintRenderer, "workspace colour picker")
	workspaceSource = replaceOnce(workspaceSource,
		[[self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy); self:Layout(); self.Title.Text=string.upper(context.Title or "GARAGE"); self.Subtitle.Text=context.Subtitle or ""; self.Back.Visible=context.BackVisible~=false; self.Next.Visible=context.NextVisible~=false; self.Next.Text=string.upper(context.NextText or "NEXT"); self.Exit.Visible=context.ExitVisible==true]],
		[[self.Root.Visible=true; Shared.AcquirePresentation(self.Root,context.Legacy); self:Layout(); self.Title.Text=string.upper(context.Title or "GARAGE"); self.Subtitle.Text=context.Subtitle or ""; self.Back.Visible=context.BackVisible==true; self.Next.Visible=context.NextVisible~=false; self.Exit.Visible=context.ExitVisible==true; Shared.SetActionButton(self.Back,context.BackText or "BACK",context.BackIcon,context.BackIconText or "<"); Shared.SetActionButton(self.Next,context.NextText or "DRIVE",context.NextIcon,context.NextIconText); Shared.SetActionButton(self.Exit,context.ExitText or "EXIT",context.ExitIcon,context.ExitIconText or "X")]],
		"workspace context action presentation")
end

if not string.find(browserSource, REVISION, 1, true) then
	browserSource = replaceOnce(browserSource,
		[[local function asset(name) local f=desktop:FindFirstChild("Assets"); local v=f and f:FindFirstChild(name); return v and v.Value or "" end]],
		[[local function asset(name) local f=desktop:FindFirstChild("Assets"); local v=f and f:FindFirstChild(name); return v and v.Value or "" end
local navigationIcons=cfg:FindFirstChild("NavigationIcons")
local function navIcon(name) return tostring(navigationIcons and navigationIcons:GetAttribute(name) or "") end -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1]],
		"browser navigation icon resolver")
	browserSource = replaceOnce(browserSource,
		[[self.Exit=Racing.Button(self.Root,{Name="Exit",Text="EXIT",Size=UDim2.fromOffset(88,30),Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})]],
		[[self.Exit=Shared.ActionButton(self.Root,{Name="Exit",Text="EXIT",Icon=navIcon("ExitIcon"),IconText="X",Color=Color3.fromRGB(166,61,70),StrokeColor=Racing.Colour("Outline")})]],
		"browser large exit action")
	local browserEconomy = [====[
function Browser:RenderEconomy(context)
	for _,p in ipairs({self.Cash,self.Capacity}) do for _,o in ipairs(p:GetChildren()) do if o:GetAttribute("GeneratedGarageUI") then o:Destroy() end end end
	local cash=generated(Racing.Label(self.Cash,{Text=Shared.FormatMoney(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=15,Color=Color3.fromRGB(89,255,102)})); cash.Name="CashValue"; local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if typeof(context.OnCash)=="function" then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity; generated(Racing.Label(self.Capacity,{Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=11})); local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if typeof(context.OnCapacity)=="function" then context.OnCapacity() end end)
end
]====]
	browserSource = replaceSection(browserSource, "function Browser:RenderEconomy(context)", "function Browser:Audit(selectedCard)", browserEconomy, "browser economy renderer")
	browserSource = replaceOnce(browserSource,
		[[local text=context.Mode=="Customisation" and "CUSTOMISE" or ((owned and "BUY ANOTHER $" or "BUY $")..tostring(selected.Cockpit.Price or 0))]],
		[[local text=context.Mode=="Customisation" and "CUSTOMISE" or ((owned and "BUY ANOTHER " or "BUY ")..Shared.FormatMoney(selected.Cockpit.Price or 0))]],
		"vehicle popup money formatting")
end

if not string.find(applicationSource, REVISION, 1, true) then
	applicationSource = replaceOnce(applicationSource,
		[[local function imageValue(value) local text=tostring(value or ""); if text=="" then return "" end; if tonumber(text) then return "rbxassetid://"..text end; return text end]],
		[[local function imageValue(value) local text=tostring(value or ""); if text=="" then return "" end; if tonumber(text) then return "rbxassetid://"..text end; return text end
local navigationIcons=replacementConfig:WaitForChild("NavigationIcons")
local function navIcon(name) return imageValue(navigationIcons:GetAttribute(name)) end -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1]],
		"application navigation icon resolver")
	applicationSource = replaceOnce(applicationSource,
		[[for _,property in ipairs(catalog.List()) do local owned=(State.Profile.Garage.OwnedGarageProperties or {})[property.PropertyId]~=nil; local b=Racing.Button(list,{Text=(owned and "OWNED - " or ("BUY $"..tostring(property.Price or 0).." - "))..tostring(property.DisplayName),Size=UDim2.new(1,-8,0,48),Color=owned and Racing.Colour("PanelSoft") or Racing.Colour("PanelBlue")});]],
		[[for _,property in ipairs(catalog.List()) do local owned=(State.Profile.Garage.OwnedGarageProperties or {})[property.PropertyId]~=nil; local b=Racing.Button(list,{Text=(owned and "OWNED - " or ("BUY "..Shared.FormatMoney(property.Price or 0).." - "))..tostring(property.DisplayName),Size=UDim2.new(1,-8,0,48),Color=owned and Racing.Colour("PanelSoft") or Racing.Colour("PanelBlue")});]],
		"garage property money formatting")
	applicationSource = replaceOnce(applicationSource,
		[[local renderBrowser,renderPaint,renderBuild,renderCustomise]],
		[[local renderBrowser,renderPaint,renderHub,renderBuild,renderCustomise]],
		"hub renderer declaration")
	applicationSource = replaceOnce(applicationSource,
		[[local function common(title) local owned,cap=capacity(); return {Title=title,Cash=State.Profile and State.Profile.Cash or 0,CapacityText=tostring(owned).."/"..tostring(cap).." Spaces",RenderStats=stats,OnCash=showCash,OnCapacity=showProperties,ExitVisible=false,Legacy={}} end]],
		[[local function common(title) local owned,cap=capacity(); return {Title=title,Cash=State.Profile and State.Profile.Cash or 0,CapacityText=tostring(owned).."/"..tostring(cap).." Spaces",RenderStats=stats,OnCash=showCash,OnCapacity=showProperties,ExitVisible=false,Legacy={}} end
local function driveFromGarage()
	local engine,stabilisers,boost=coreReady(); if not(engine and stabilisers and boost) then message("Equip one engine, stabilisers, and boost before driving."); return end
	clearTransientModulePreview(); action:Session("End",{ReturnToEntry=false}); local result=action:Call("SpawnVehicle",{}); if not result.Success then message(result.Message); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local event=intro:FindFirstChild("GarageClosedFromDealershipExit"); if event and event:IsA("BindableEvent") then event:Fire() end
end]],
		"shared drive action")
	applicationSource = replaceOnce(applicationSource,
		[[State.PreviewProfile=nil; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"; State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; buildPreview(); renderPaint() end,]],
		[[State.PreviewProfile=nil; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"; State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; buildPreview(); if State.ShopMode=="Customisation" then renderHub() else renderPaint() end end,]],
		"browser selection route")

	local paintAndHub = [====[
renderPaint=function()
	State.Stage="Paint"; browser:Hide(); local c=common("Paint Vehicle"); c.Subtitle="Choose a whole-vehicle colour, then continue to your garage."; c.ShowLeft=false; c.BackVisible=false; c.NextText="Customise"; c.NextIcon=navIcon("CustomiseIcon"); c.NextIconText="*"; c.ColorChannels={"Primary","Secondary","Detail"}; c.SelectedChannel=State.SelectedColorChannel; c.Colors=State.Profile.CockpitColors or {}; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderPaint() end; c.OnColor=function(ch,color,commit) handlePaint("WholeVehicle",ch,color,commit) end; c.OnNext=function() clearTransientModulePreview(); renderHub() end; workspaceUI:Show(c)
end
renderHub=function()
	State.Stage="Hub"; browser:Hide(); local c=common("Garage"); c.Subtitle="Choose what to work on, or drive your vehicle."; c.ShowLeft=false; c.BackVisible=false; c.NextText="Drive"; c.NextIcon=navIcon("DriveIcon"); c.NextIconText=">"; c.Cards={
		{Id="BuildModules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,DisplayName="Build Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},
		{Id="CustomiseModules",Image=navIcon("CustomiseModulesIcon"),ImageZoom=.5,DisplayName="Customise Modules",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; buildPreview(); renderCustomise() end},
	}; c.OnNext=driveFromGarage; workspaceUI:Show(c)
end
]====]
	applicationSource = replaceSection(applicationSource, "renderPaint=function()", "local function moduleLineage", paintAndHub, "paint and garage hub routes")

	local buildRenderer = [====[
renderBuild=function()
	State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or (State.ModuleMode=="Sources" and "Choose owned modules or buy modules." or "Preview, then buy or equip."); c.ShowLeft=false; c.BackVisible=true; c.BackIcon=navIcon("BackIcon"); c.BackIconText="<"; c.NextText="Drive"; c.NextIcon=navIcon("DriveIcon"); c.NextIconText=">"; c.Cards={}
	if State.ModuleMode=="Slots" then
		for _,art in ipairs(workspaceUI:ArtworkDefinitions("Build")) do local s=slot(art.TargetId); if s then local installed=installedForSlot(s.SlotId); table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,BadgeColor=tierColor("S"),OnSelect=function() clearTransientModulePreview(); State.SelectedSlot=s.SlotId; State.ModuleMode="Sources"; State.ModuleOptionMode=nil; section(s.SlotId); renderBuild() end}) end end
	elseif State.ModuleMode=="Sources" then
		table.insert(c.Cards,{Id="Owned",Image=navIcon("OwnedModulesIcon"),ImageZoom=.5,DisplayName="Owned Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; renderBuild() end})
		table.insert(c.Cards,{Id="Buy",Image=navIcon("BuyModulesIcon"),ImageZoom=.5,DisplayName="Buy Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Buy"; renderBuild() end})
	else
		local s=slot(State.SelectedSlot); local _,installedInstance=installedForSlot(State.SelectedSlot)
		if State.ModuleOptionMode=="Owned" then
			local rows=ModuleCards.Owned({Instances=State.Profile.OwnedModuleInstances,Slot=s,ResolveModule=moduleById,Fits=moduleFits,CurrentVehicleId=State.Profile.CurrentVehicleId,InstalledInstanceId=installedInstance,VehicleName=vehicleDisplayName,SourceVehicleName=sourceVehicleName,Rating=moduleRating})
			for _,row in ipairs(rows) do local selected=State.SelectedModuleInstanceId==row.Id; table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and row.State~="Equipped" and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=row.Module.ModuleId; State.SelectedModuleInstanceId=row.Id; State.PreviewModules={[State.SelectedSlot]=row.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() if row.State=="InUse" then confirmModuleMove(vehicleDisplayName(row.OwnerVehicleId),function() equipInstance(row,true) end) else equipInstance(row,false) end end}) end
		else
			local rows=ModuleCards.Shop({Modules=modulesForSlot(State.SelectedSlot),IsLocked=function(m) local source=tostring(m.SourceCockpitId or ""); return source~="" and ownedCockpitCount(source)==0 end,SourceVehicleName=sourceVehicleName,SourceRating=sourceVehicleRating,OwnedCount=ownedModuleCount,Rating=moduleRating})
			for _,row in ipairs(rows) do local selected=State.SelectedModuleId==row.Id; table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Locked=row.Locked,LockImage=imageValue(replacementConfig:GetAttribute("ModuleLockIcon")),Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and not row.Locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=row.Id; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=row.Id}; buildPreview(); renderBuild() end,OnAction=function() local buy=action:Call("BuyModuleInstance",{ModuleId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if not buy.Success then message(buy.Message); return end; clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild(); message("Module purchased and equipped.") end}) end
		end
	end
	c.OnBack=function() clearTransientModulePreview(); if State.ModuleMode=="Options" then State.ModuleMode="Sources"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() elseif State.ModuleMode=="Sources" then State.ModuleMode="Slots"; buildPreview(); renderBuild() else buildPreview(); renderHub() end end; c.OnNext=driveFromGarage; workspaceUI:Show(c)
end -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
]====]
	applicationSource = replaceSection(applicationSource, "renderBuild=function()", "local function installedModule()", buildRenderer, "build-module route")
	applicationSource = replaceOnce(applicationSource,
		[[c.NextText="Start Driving"; c.LeftCardMode=true]],
		[[c.BackVisible=true; c.BackIcon=navIcon("BackIcon"); c.BackIconText="<"; c.NextText="Drive"; c.NextIcon=navIcon("DriveIcon"); c.NextIconText=">"; c.LeftCardMode=true]],
		"customise shared navigation")
	applicationSource = replaceOnce(applicationSource,
		[[Badge=owned and "OWNED" or "$5000"]],
		[[Badge=owned and "OWNED" or Shared.FormatMoney(5000)]],
		"neon price formatting")
	applicationSource = replaceOnce(applicationSource,
		[[local priceText=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or ("$"..tostring(price)))]],
		[[local priceText=maxed and "MAX LEVEL" or (budgetFull and "LIMIT REACHED" or Shared.FormatMoney(price))]],
		"upgrade price and limit copy")
	applicationSource = replaceOnce(applicationSource,
		[[c.OnBack=function() clearTransientModulePreview(); if State.CustomizeMode~="Overview" and target~="ALL" then State.CustomizeMode="Overview"; renderCustomise() else State.ModuleMode="Slots"; buildPreview(); renderBuild() end end
	c.OnNext=function() clearTransientModulePreview(); action:Session("End",{ReturnToEntry=false}); local r=action:Call("SpawnVehicle",{}); if not r.Success then message(r.Message); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end end]],
		[[c.OnBack=function() clearTransientModulePreview(); if State.CustomizeMode~="Overview" and target~="ALL" then State.CustomizeMode="Overview"; renderCustomise() else buildPreview(); renderHub() end end
	c.OnNext=driveFromGarage]],
		"customise back and drive routes")
	applicationSource = replaceOnce(applicationSource,
		[[State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.SelectedCockpit=State.Profile.CurrentCockpit; State.NoPreviewYet=false; buildPreview(); renderPaint() else renderBrowser() end]],
		[[State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.SelectedCockpit=State.Profile.CurrentCockpit; State.NoPreviewYet=false; buildPreview(); renderHub() else renderBrowser() end]],
		"drive-in hub route")
end

compile("GarageReplacementComponents", sharedSource)
compile("GarageWorkspaceController", workspaceSource)
compile("GarageBrowserController", browserSource)
compile("ModuleShopUIController", applicationSource)
for name,source in pairs({GarageReplacementComponents=sharedSource,GarageWorkspaceController=workspaceSource,GarageBrowserController=browserSource,ModuleShopUIController=applicationSource}) do assert(#source<199000,name.." projected Source is too large for safe Studio assignment") end

local desktopAssets = need(need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "DesktopFreeRoamHud", "Folder"), "Assets", "Folder")
local function assetValue(name)
	local value=desktopAssets:FindFirstChild(name); return value and value:IsA("StringValue") and value.Value or ""
end
local navigationDefaults = {
	BackIcon = "",
	ExitIcon = "",
	DriveIcon = assetValue("CarIcon"),
	CustomiseIcon = tostring(uiConfig:GetAttribute("ModuleCosmeticsIcon") or ""),
	BuildModulesIcon = assetValue("GarageIcon"),
	CustomiseModulesIcon = tostring(uiConfig:GetAttribute("ModuleCosmeticsIcon") or ""),
	OwnedModulesIcon = assetValue("GarageIcon"),
	BuyModulesIcon = assetValue("DealershipIcon"),
}
local numericDefaults = {NavigationButtonHeight=46,NavigationPopupClearance=48,WorkspacePaintWideWidth=900,PaintPaletteColumns=12}

local function audit()
	local pass, fail = 0, 0
	local function check(condition, message) if condition then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end end
	check(string.find(shared.Source,REVISION,1,true)~=nil,"shared navigation/format owner installed")
	check(string.find(workspaceController.Source,REVISION,1,true)~=nil,"workspace colour/action owner installed")
	check(string.find(browserController.Source,REVISION,1,true)~=nil,"browser action owner installed")
	check(string.find(applicationController.Source,REVISION,1,true)~=nil,"application route owner installed")
	check(string.find(applicationController.Source,"renderHub=function()",1,true)~=nil,"garage hub route installed")
	check(string.find(applicationController.Source,'State.ModuleMode="Sources"',1,true)~=nil,"owned/buy source-picker route installed")
	check(string.find(applicationController.Source,'"LIMIT REACHED"',1,true)~=nil and not string.find(applicationController.Source,'"POINT LIMIT REACHED"',1,true),"short limit copy installed")
	check(string.find(workspaceController.Source,"PaintPaletteColumns",1,true)~=nil,"two-row colour palette installed")
	check(string.find(shared.Source,"FormatMoney",1,true)~=nil,"shared comma money formatter installed")
	check(string.find(shared.Source,"navigation overlaps card action popup",1,true)~=nil,"navigation/popup overlap audit installed")
	local icons=uiConfig:FindFirstChild("NavigationIcons"); check(icons and icons:IsA("Folder"),"navigation icon config folder installed")
	check(browserController:IsA("ModuleScript") and applicationController:IsA("ModuleScript") and browserController.Parent==uiRoot and applicationController.Parent==uiRoot,"canonical UI modules retained in controller folder")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail)); return fail==0
end

if MODE=="AUDIT" then assert(audit(),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local oldSources={Shared=shared.Source,Workspace=workspaceController.Source,Browser=browserController.Source,Application=applicationController.Source}
local existingIcons=uiConfig:FindFirstChild("NavigationIcons"); local createdIcons=false; local oldIconAttributes={}; if existingIcons then for name in pairs(navigationDefaults) do oldIconAttributes[name]=existingIcons:GetAttribute(name) end end
local oldNumeric={}; for name in pairs(numericDefaults) do oldNumeric[name]=uiConfig:GetAttribute(name) end
local ok,err=pcall(function()
	local icons=existingIcons; if not icons then icons=Instance.new("Folder"); icons.Name="NavigationIcons"; icons.Parent=uiConfig; createdIcons=true end; assert(icons:IsA("Folder"),icons:GetFullName().." must be Folder")
	for name,value in pairs(navigationDefaults) do if icons:GetAttribute(name)==nil then icons:SetAttribute(name,value) end end
	for name,value in pairs(numericDefaults) do if uiConfig:GetAttribute(name)==nil then uiConfig:SetAttribute(name,value) end end
	shared.Source=sharedSource; workspaceController.Source=workspaceSource; browserController.Source=browserSource; applicationController.Source=applicationSource
	assert(audit(),"Post-install audit failed")
end)
if not ok then
	shared.Source=oldSources.Shared; workspaceController.Source=oldSources.Workspace; browserController.Source=oldSources.Browser; applicationController.Source=oldSources.Application
	if createdIcons then local icons=uiConfig:FindFirstChild("NavigationIcons"); if icons then icons:Destroy() end elseif existingIcons then for name in pairs(navigationDefaults) do existingIcons:SetAttribute(name,oldIconAttributes[name]) end end
	for name in pairs(numericDefaults) do uiConfig:SetAttribute(name,oldNumeric[name]) end
	error("Garage flow/navigation install rolled back: "..tostring(err))
end
print(PREFIX.." INSTALL COMPLETE - restart Play and verify browser, paint, hub, build, customise, popup clearance, colour swatches, money formatting and Drive on PC/touch.")
