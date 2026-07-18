-- NTR_GARAGE_CANONICAL_EXPERIENCE_V1
-- NTR_GARAGE_CANONICAL_DESIGN_SYSTEM_V3
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer; local camera=Workspace.CurrentCamera
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local uiConfig=kit:WaitForChild("Config"):WaitForChild("UI")
local cfg=uiConfig:WaitForChild("GarageExperience")
local desktop=uiConfig:WaitForChild("DesktopFreeRoamHud")
local colours=desktop:WaitForChild("Colours")
local effects=desktop:WaitForChild("Effects")
local assets=desktop:FindFirstChild("Assets")
local request=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("GarageSessionRequest")
local function value(folder,name,fallback) local v=folder and folder:FindFirstChild(name); return v and v.Value~=nil and v.Value or fallback end
local function C(name,fallback) local v=value(colours,name,nil); return typeof(v)=="Color3" and v or fallback end
local function N(name,fallback) return tonumber(value(cfg,name,fallback)) or fallback end
local function E(name,fallback) return tonumber(value(effects,name,fallback)) or fallback end
local panel=C("Panel",Color3.fromRGB(15,19,24)); local deep=C("PanelDeep",Color3.fromRGB(9,12,16)); local soft=C("PanelSoft",Color3.fromRGB(24,29,36)); local panelBlue=C("PanelBlue",Color3.fromRGB(8,42,84)); local pink=C("Outline",Color3.fromRGB(244,46,151)); local pinkSoft=C("OutlineSoft",Color3.fromRGB(214,74,175)); local cyan=C("Telemetry",Color3.fromRGB(43,225,218)); local purchase=C("ElectricBlue",Color3.fromRGB(25,116,255)); local text=C("Text",Color3.fromRGB(246,248,252)); local muted=C("Muted",Color3.fromRGB(163,171,184))
local activeGui; local ending=false; local popupShell; local popupButton; local scrollingUntil=0; local layout; local stageVisible; local leftArrow; local rightArrow; local nextLayoutRefresh=0
local panelNames={TopHUD=true,Categories=true,GarageCapacityPinnedLeft=true,CashPinnedBottomLeft=true,PersistentStats=true,NextPinnedBottomRight=true,ModuleSlotBarPanel=true,ModuleOptionsPanel=true,CockpitPaintPanel=true,CustomiseListPanel=true}
local function textButton(root,wanted) for _,o in ipairs(root and root:GetDescendants() or {}) do if o:IsA("TextButton") and string.upper(o.Text)==string.upper(wanted) then return o end end end
local function ensureCorner(parent,radius) local o=parent:FindFirstChild("GarageCorner") or parent:FindFirstChildOfClass("UICorner"); if not o then o=Instance.new("UICorner"); o.Name="GarageCorner"; o.Parent=parent end; o.CornerRadius=UDim.new(0,radius or 5); return o end
local function ensureStroke(parent,name,color,thickness,transparency) local o=parent:FindFirstChild(name); if not (o and o:IsA("UIStroke")) then if o then o:Destroy() end; o=Instance.new("UIStroke"); o.Name=name; o.Parent=parent end; o.Color=color; o.Thickness=thickness; o.Transparency=transparency; o.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return o end
local function ensureSurfaceGradient(parent,top,bottom)
	local g=parent:FindFirstChild("GarageSurfaceGradient"); if not (g and g:IsA("UIGradient")) then if g then g:Destroy() end; g=Instance.new("UIGradient"); g.Name="GarageSurfaceGradient"; g.Parent=parent end
	g.Color=ColorSequence.new(top,bottom); g.Transparency=NumberSequence.new(E("GradientTransparency",.12)); g.Rotation=90; return g
end
local function ensureButtonGradient(parent)
	local overlay=parent:FindFirstChild("GarageGradientOverlay"); if overlay and not overlay:IsA("Frame") then overlay:Destroy(); overlay=nil end
	if not overlay then overlay=Instance.new("Frame"); overlay.Name="GarageGradientOverlay"; overlay.Active=false; overlay.BorderSizePixel=0; overlay.Size=UDim2.fromScale(1,1); overlay.Parent=parent; ensureCorner(overlay,5); local g=Instance.new("UIGradient"); g.Name="Gradient"; g.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(95,95,95)); g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.20),NumberSequenceKeypoint.new(.52,.70),NumberSequenceKeypoint.new(1,.28)}); g.Rotation=E("ButtonGradientRotation",90); g.Parent=overlay end
	overlay.BackgroundColor3=Color3.new(1,1,1); overlay.BackgroundTransparency=1-math.clamp(E("ButtonGradientStrength",.10),0,.35); overlay.ZIndex=parent.ZIndex; return overlay
end
local function stylePanel(o)
	if not (o and o:IsA("Frame")) then return end
	if o.Name=="CockpitGridPanel" or o.Name=="DealershipExitPinnedBottomRight" then
		o.BackgroundTransparency=1
		for _,child in ipairs(o:GetChildren()) do if child:IsA("UIStroke") then child.Transparency=1 elseif child:IsA("UIGradient") or child.Name=="GarageGlowStroke" or child.Name=="GarageSurfaceGradient" then child:Destroy() end end
		return
	end
	if not panelNames[o.Name] then return end
	o.BackgroundColor3=deep; o.BackgroundTransparency=math.min(o.BackgroundTransparency,.12); ensureCorner(o,5); ensureSurfaceGradient(o,soft:Lerp(deep,.55),deep)
	local main=o:FindFirstChildOfClass("UIStroke"); if main and main.Name~="GarageGlowStroke" then main.Color=pink; main.Thickness=1.2; main.Transparency=.14 end
	ensureStroke(o,"GarageGlowStroke",pink,3.5,E("GlowTransparency",.82))
end
local function styleButton(o,selected)
	if not (o and o:IsA("TextButton")) then return end
	local upper=string.upper(o.Text or ""); local positive=string.sub(upper,1,3)=="BUY" or upper=="CUSTOMISE" or upper=="GET MORE"
	local accent=positive and purchase or selected and cyan or pinkSoft
	if positive then o.BackgroundColor3=panelBlue elseif selected then o.BackgroundColor3=Color3.fromRGB(15,48,57) elseif o:GetAttribute("NTRGarageVehicleCard")==true then o.BackgroundColor3=panel end
	o.BackgroundTransparency=positive and .04 or .08; o.TextColor3=text; o.AutoButtonColor=false; ensureCorner(o,5); ensureButtonGradient(o)
	local main=o:FindFirstChildOfClass("UIStroke"); if main and main.Name~="GarageGlowStroke" then main.Color=accent; main.Thickness=selected and 2 or 1.3; main.Transparency=.08 end
	local glow=ensureStroke(o,"GarageGlowStroke",accent,selected and 4.5 or 3.5,E("GlowTransparency",.82))
	if o:GetAttribute("NTRGarageHoverConnected")~=true then o:SetAttribute("NTRGarageHoverConnected",true); o.MouseEnter:Connect(function() o.BackgroundTransparency=.02; glow.Transparency=math.max(.55,E("GlowTransparency",.82)-.14) end); o.MouseLeave:Connect(function() o.BackgroundTransparency=(string.sub(string.upper(o.Text or ""),1,3)=="BUY" or string.upper(o.Text or "")=="CUSTOMISE") and .04 or .08; glow.Transparency=E("GlowTransparency",.82) end) end
end
local function style(root)
	for _,o in ipairs(root:GetDescendants()) do
		if o:IsA("Frame") then stylePanel(o)
		elseif o:IsA("TextButton") and o:GetAttribute("NTRGarageVehicleCard")~=true then styleButton(o,false)
		elseif o:IsA("TextLabel") and o.TextColor3~=Color3.fromRGB(0,255,0) and o.TextSize<=10 then o.TextColor3=muted end
	end
end
local function selectedVehicleCard(gui) local grid=gui:FindFirstChild("CockpitGrid",true); if not grid then return end; for _,o in ipairs(grid:GetChildren()) do if o:IsA("GuiButton") and o:GetAttribute("NTRGarageVehicleCard")==true and o:GetAttribute("NTRGarageSelected")==true then return o end end end
local function ensurePopup(gui)
	if popupShell and popupShell.Parent==gui then return popupShell end
	popupShell=Instance.new("Frame"); popupShell.Name="VehicleCardActionPopup"; popupShell.AnchorPoint=Vector2.new(.5,1); popupShell.Size=UDim2.fromOffset(190,46); popupShell.BackgroundColor3=deep; popupShell.BackgroundTransparency=.03; popupShell.BorderSizePixel=0; popupShell.Visible=false; popupShell.ZIndex=85; popupShell.Parent=gui
	ensureCorner(popupShell,6); ensureSurfaceGradient(popupShell,panelBlue:Lerp(deep,.45),deep); ensureStroke(popupShell,"PopupStroke",cyan,1.5,.04); ensureStroke(popupShell,"GarageGlowStroke",cyan,4.5,E("GlowTransparency",.82)); return popupShell
end
local function decorateVehicleCards(gui)
	local grid=gui:FindFirstChild("CockpitGrid",true); if not grid then return end
	for _,card in ipairs(grid:GetChildren()) do if card:IsA("TextButton") and card:GetAttribute("NTRGarageVehicleCard")==true then
		local selected=card:GetAttribute("NTRGarageSelected")==true; local cardH=N("CarouselCardHeight",154); local imageH=cardH-36; card.Text=""; card.ClipsDescendants=false; styleButton(card,selected)
		local icon; local badge
		for _,child in ipairs(card:GetChildren()) do if child:IsA("Frame") and child:GetAttribute("PooledDynamic")==true then local image=child:FindFirstChildWhichIsA("ImageLabel",true); local label=child:FindFirstChildWhichIsA("TextLabel",true); if image then icon=child elseif label then badge=child elseif not icon then icon=child end end end
		if icon then icon.BackgroundTransparency=1; icon.BorderSizePixel=0; icon.Position=UDim2.fromOffset(4,3); icon.Size=UDim2.new(1,-8,0,imageH); icon.ClipsDescendants=true; icon.ZIndex=card.ZIndex+2; for _,d in ipairs(icon:GetDescendants()) do if d:IsA("UIStroke") then d.Transparency=1 end end; local image=icon:FindFirstChildWhichIsA("ImageLabel",true); if image then image.BackgroundTransparency=1; image.BorderSizePixel=0; image.AnchorPoint=Vector2.new(.5,.5); image.Position=UDim2.fromScale(.5,.5); image.Size=UDim2.fromScale(1.38,1.38); image.ScaleType=Enum.ScaleType.Fit; image.ZIndex=card.ZIndex+3 end end
		if badge and badge~=icon then badge.AnchorPoint=Vector2.new(1,0); badge.Position=UDim2.new(1,-8,0,8); badge.ZIndex=card.ZIndex+6; for _,d in ipairs(badge:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex=badge.ZIndex+1 end end end
		local nameLabel; local ownedLabel
		for _,child in ipairs(card:GetChildren()) do if child:IsA("TextLabel") then local upper=string.upper(child.Text); if string.sub(upper,1,1)=="$" then child.Visible=false elseif string.find(upper,"OWNED X",1,true) then ownedLabel=child else nameLabel=nameLabel or child end end end
		if nameLabel then nameLabel.Position=UDim2.fromOffset(9,cardH-32); nameLabel.Size=UDim2.new(1,-18,0,16); nameLabel.TextXAlignment=Enum.TextXAlignment.Left; nameLabel.TextSize=9; nameLabel.TextColor3=text; nameLabel.ZIndex=card.ZIndex+4 end
		if ownedLabel then ownedLabel.Position=UDim2.fromOffset(9,cardH-16); ownedLabel.Size=UDim2.new(1,-18,0,12); ownedLabel.TextXAlignment=Enum.TextXAlignment.Left; ownedLabel.TextSize=7; ownedLabel.TextColor3=muted; ownedLabel.ZIndex=card.ZIndex+4 end
	end end
	if grid:GetAttribute("NTRGarageScrollConnected")~=true then grid:SetAttribute("NTRGarageScrollConnected",true); grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function() scrollingUntil=os.clock()+.14; if popupShell then popupShell.Visible=false end; task.delay(.16,function() if activeGui then layout(activeGui) end end) end) end
end
local function updateActionPopup(gui)
	local shell=ensurePopup(gui); local newAction=gui:FindFirstChild("VehicleActionButton",true)
	if newAction and newAction~=popupButton then if popupButton and popupButton.Parent then popupButton:Destroy() end; popupButton=newAction; popupButton.Parent=shell; popupButton.AnchorPoint=Vector2.zero; popupButton.Position=UDim2.fromOffset(5,5); popupButton.Size=UDim2.new(1,-10,1,-10); popupButton.ZIndex=87 end
	if popupButton and popupButton.Parent==shell then styleButton(popupButton,false); popupButton.BackgroundColor3=panelBlue end
	local card=selectedVehicleCard(gui)
	if not (card and popupButton and popupButton.Parent==shell and os.clock()>=scrollingUntil and stageVisible(gui,"CockpitShop")) then shell.Visible=false; return end
	local scaler=gui:FindFirstChildOfClass("UIScale"); local scale=scaler and scaler.Scale or 1; shell.Position=UDim2.fromOffset((card.AbsolutePosition.X+card.AbsoluteSize.X*.5)/math.max(scale,.01),(card.AbsolutePosition.Y-8)/math.max(scale,.01)); shell.Visible=true
end
stageVisible=function(gui,name) local f=gui:FindFirstChild(name,true); return f and f.Visible end
local function decorateModuleButtons(gui)
	local diagrams=cfg:FindFirstChild("ModuleDiagrams"); local category=diagrams and (diagrams:FindFirstChild("BRUISER") or diagrams:GetChildren()[1]); if not category then return end
	for _,containerName in ipairs({"ModuleSlotBar","CustomiseList"}) do
		local container=gui:FindFirstChild(containerName,true)
		if container then
			for _,button in ipairs(container:GetChildren()) do
				if button:IsA("TextButton") then
					styleButton(button,false)
					if not button:FindFirstChild("NTRModuleDiagram") then
						local lower=string.lower(button.Text)
						local compact=string.gsub(lower," ","")
						local slotId
						for _,id in ipairs({"Engine1","Engine2","Stabilisers","Boost","FrontBumper","RearBumper","RearSpoiler","SidePods"}) do
							local folder=category:FindFirstChild(id)
							local label=folder and folder:FindFirstChild("Label")
							if label and string.find(compact,string.gsub(string.lower(label.Value)," ",""),1,true) then slotId=id end
						end
						if not slotId then
							if string.find(lower,"front engine",1,true) then slotId="Engine1"
							elseif string.find(lower,"rear engine",1,true) then slotId="Engine2"
							elseif string.find(lower,"stabilis",1,true) then slotId="Stabilisers"
							elseif string.find(lower,"boost",1,true) then slotId="Boost" end
						end
						local folder=slotId and category:FindFirstChild(slotId)
						local imageValue=folder and folder:FindFirstChild("Image")
						if folder then
							button.Size=UDim2.fromOffset(containerName=="ModuleSlotBar" and 156 or 176,96)
							button.TextYAlignment=Enum.TextYAlignment.Bottom
							local image=Instance.new("ImageLabel"); image.Name="NTRModuleDiagram"; image.BackgroundTransparency=1; image.Size=UDim2.new(1,-12,1,-34); image.Position=UDim2.fromOffset(6,4); image.ScaleType=Enum.ScaleType.Fit; image.Image=imageValue and imageValue.Value or ""; image.ZIndex=button.ZIndex+2; image.Parent=button
						end
					end
				end
			end
		end
	end
end
local function decorateStats(gui)
	local stats=gui:FindFirstChild("PersistentStats",true); if not stats then return end
	stats:SetAttribute("NTRGarageStatReference",N("StatBarReference",180))
	for _,o in ipairs(stats:GetDescendants()) do
		if o:IsA("Frame") and o.Name=="NTRGarageStatTrack" then o.BackgroundColor3=soft; o.BackgroundTransparency=.12
		elseif o:IsA("Frame") and o.Name=="NTRGarageStatFill" then
			o.BackgroundColor3=cyan
			local g=o:FindFirstChild("GarageStatGradient") or Instance.new("UIGradient"); g.Name="GarageStatGradient"; g.Color=ColorSequence.new(purchase,cyan); g.Rotation=0; g.Parent=o
		end
	end
end
local function decorateEconomy(gui)
	local cash=gui:FindFirstChild("CashPinnedBottomLeft",true); local capacity=gui:FindFirstChild("GarageCapacityPinnedLeft",true)
	if cash then
		cash.BackgroundColor3=panelBlue; local g=ensureSurfaceGradient(cash,purchase:Lerp(panelBlue,.72),panelBlue); g.Rotation=0; ensureStroke(cash,"CashStroke",purchase,1.7,0)
		for _,o in ipairs(cash:GetChildren()) do if o:IsA("TextLabel") then if string.upper(o.Text)=="AVAILABLE CASH" then o.Visible=false else o.Position=UDim2.fromOffset(12,0); o.Size=UDim2.new(1,-58,1,0); o.TextXAlignment=Enum.TextXAlignment.Left; o.TextSize=16 end elseif o:IsA("TextButton") and string.upper(o.Text)=="GET MORE" then o.Text="+"; o.Name="GarageCashPlus"; o.AnchorPoint=Vector2.new(1,.5); o.Position=UDim2.new(1,-8,.5,0); o.Size=UDim2.fromOffset(32,30); o.TextSize=19 end end
	end
	if capacity then
		capacity.BackgroundColor3=panelBlue; local g=ensureSurfaceGradient(capacity,purchase:Lerp(panelBlue,.72),panelBlue); g.Rotation=0; ensureStroke(capacity,"CashStroke",purchase,1.7,0)
		for _,o in ipairs(capacity:GetChildren()) do if o:IsA("TextLabel") then if string.upper(o.Text)=="GARAGE SPACES" or o.Name=="GarageCapacityPrice" then o.Visible=false elseif o.Name=="GarageCapacityCount" then o.Visible=true; o.Text=string.gsub(o.Text,"spaces","Spaces"); o.Position=UDim2.fromOffset(40,0); o.Size=UDim2.new(1,-92,1,0); o.TextXAlignment=Enum.TextXAlignment.Left; o.TextSize=13 end elseif o:IsA("TextButton") and o.Name=="GarageCapacityUpgradeButton" then o.Text="+"; o.AnchorPoint=Vector2.new(1,.5); o.Position=UDim2.new(1,-8,.5,0); o.Size=UDim2.fromOffset(32,30); o.TextSize=19 end end
		local icon=capacity:FindFirstChild("GarageChipIcon"); if not icon then icon=Instance.new("ImageLabel"); icon.Name="GarageChipIcon"; icon.BackgroundTransparency=1; icon.BorderSizePixel=0; icon.Position=UDim2.fromOffset(8,13); icon.Size=UDim2.fromOffset(30,30); icon.ScaleType=Enum.ScaleType.Fit; icon.ZIndex=capacity.ZIndex+2; icon.Parent=capacity end
		local assetValue=assets and assets:FindFirstChild("GarageIcon"); icon.Image=assetValue and assetValue.Value or ""; icon.ImageColor3=text
	end
end
local function decorateHeader(gui)
	local top=gui:FindFirstChild("TopHUD",true); if not top then return end
	top.BackgroundColor3=soft; top.BackgroundTransparency=.34; local g=ensureSurfaceGradient(top,soft,deep); g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.04),NumberSequenceKeypoint.new(1,.28)}); for _,o in ipairs(top:GetChildren()) do if o:IsA("UIStroke") then o.Transparency=1 end end
	local title=top:FindFirstChildWhichIsA("TextLabel"); if title then title.Position=UDim2.fromOffset(12,7); title.Size=UDim2.new(1,-24,0,25); title.TextSize=15 end
	for _,o in ipairs(top:GetChildren()) do if o:IsA("TextLabel") and o~=title then o.Position=UDim2.fromOffset(12,31); o.Size=UDim2.new(1,-24,0,22); o.TextSize=8 end end
end
local function decorateCarouselArrows(gui)
	local shop=gui:FindFirstChild("CockpitShop",true); local gridPanel=gui:FindFirstChild("CockpitGridPanel",true); if not (shop and gridPanel) then return end
	if not (leftArrow and leftArrow.Parent) or not (rightArrow and rightArrow.Parent) then
		for _,o in ipairs(gridPanel:GetChildren()) do if o:IsA("TextButton") and o.Text=="<" then leftArrow=o elseif o:IsA("TextButton") and o.Text==">" then rightArrow=o end end
		if leftArrow then leftArrow.Name="CockpitCarouselPrevious"; leftArrow.Parent=shop end
		if rightArrow then rightArrow.Name="CockpitCarouselNext"; rightArrow.Parent=shop end
	end
	for _,arrow in ipairs({leftArrow,rightArrow}) do if arrow then arrow.BackgroundColor3=deep; arrow.BackgroundTransparency=.22; arrow.TextColor3=text; arrow.ZIndex=82; styleButton(arrow,false) end end
end
layout=function(gui)
	local viewport=camera and camera.ViewportSize or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("MinScale",.68); local scale=math.clamp(math.min(viewport.X/N("BaseWidth",1600),viewport.Y/N("BaseHeight",900)),minimum,N("MaxScale",1.02)); local scaler=gui:FindFirstChildOfClass("UIScale"); if scaler then scaler.Scale=scale end
	local vw=viewport.X/scale; local vh=viewport.Y/scale; local margin=N("Margin",18); local gap=N("Gap",14); local categoryGap=N("CategoryCarouselGap",26); local left=N("CategoryWidth",224); local right=N("StatsWidth",360); local carousel=N("CarouselHeight",174); local arrowW=N("CarouselArrowWidth",30); local top=72; local bottom=vh-margin; local carouselTop=bottom-carousel
	local shop=gui:FindFirstChild("CockpitShop",true); local categories=gui:FindFirstChild("Categories",true); local cash=gui:FindFirstChild("CashPinnedBottomLeft",true); local capacity=gui:FindFirstChild("GarageCapacityPinnedLeft",true); local grid=gui:FindFirstChild("CockpitGridPanel",true); local stats=gui:FindFirstChild("PersistentStats",true); local exit=gui:FindFirstChild("DealershipExitPinnedBottomRight",true); local topPanel=gui:FindFirstChild("TopHUD",true)
	if topPanel then topPanel.AnchorPoint=Vector2.new(.5,0); topPanel.Position=UDim2.fromOffset(vw*.5,28); topPanel.Size=UDim2.fromOffset(N("HeaderWidth",440),N("HeaderHeight",64)) end
	if shop and shop.Visible then
		decorateCarouselArrows(gui)
		if categories then categories.AnchorPoint=Vector2.zero; categories.Position=UDim2.fromOffset(12,top); categories.Size=UDim2.fromOffset(left,math.max(160,carouselTop-categoryGap-top)) end
		local gridX=margin+arrowW+gap; local gridW=math.max(320,vw-2*(margin+arrowW+gap)); if grid then grid.AnchorPoint=Vector2.new(0,1); grid.Position=UDim2.fromOffset(gridX,bottom); grid.Size=UDim2.fromOffset(gridW,carousel); grid.ClipsDescendants=true end
		local scroller=grid and grid:FindFirstChildWhichIsA("ScrollingFrame",true); local gl=scroller and scroller:FindFirstChildWhichIsA("UIGridLayout"); if scroller then scroller.Position=UDim2.zero; scroller.Size=UDim2.fromScale(1,1); scroller.ClipsDescendants=true; scroller.AutomaticCanvasSize=Enum.AutomaticSize.X; scroller.ScrollingDirection=Enum.ScrollingDirection.X; scroller.CanvasSize=UDim2.fromOffset(0,0) end; if gl then gl.FillDirection=Enum.FillDirection.Vertical; gl.FillDirectionMaxCells=1; gl.CellSize=UDim2.fromOffset(N("CarouselCardWidth",240),N("CarouselCardHeight",154)); gl.CellPadding=UDim2.fromOffset(12,0) end
		if leftArrow then leftArrow.AnchorPoint=Vector2.new(0,.5); leftArrow.Position=UDim2.fromOffset(margin,carouselTop+carousel*.5); leftArrow.Size=UDim2.fromOffset(arrowW,math.max(72,carousel-20)); leftArrow.Visible=true end
		if rightArrow then rightArrow.AnchorPoint=Vector2.new(1,.5); rightArrow.Position=UDim2.fromOffset(vw-margin,carouselTop+carousel*.5); rightArrow.Size=UDim2.fromOffset(arrowW,math.max(72,carousel-20)); rightArrow.Visible=true end
		local statsH=N("StatsHeight",308); if stats then stats.AnchorPoint=Vector2.new(1,0); stats.Position=UDim2.fromOffset(vw-margin,28); stats.Size=UDim2.fromOffset(right,statsH) end
		local chipGap=gap; local chipW=(right-chipGap)*.5; local chipH=N("EconomyChipHeight",58); local chipY=28+statsH+gap; if capacity then capacity.AnchorPoint=Vector2.new(1,0); capacity.Position=UDim2.fromOffset(vw-margin-chipW-chipGap,chipY); capacity.Size=UDim2.fromOffset(chipW,chipH) end; if cash then cash.AnchorPoint=Vector2.new(1,0); cash.Position=UDim2.fromOffset(vw-margin,chipY); cash.Size=UDim2.fromOffset(chipW,chipH) end
		if exit then exit.AnchorPoint=Vector2.new(1,1); exit.Position=UDim2.fromOffset(vw-margin,carouselTop-gap); exit.Size=UDim2.fromOffset(88,30); local b=textButton(exit,"Exit"); if b then b.Position=UDim2.zero; b.Size=UDim2.fromScale(1,1); b.TextSize=9 end end
	end
	local back=textButton(gui,"Back"); if back then back.Visible=not (stageVisible(gui,"CockpitPaint") and player:GetAttribute("NTR_GarageEntryMode")~=nil) end
	style(gui); decorateHeader(gui); decorateEconomy(gui); decorateStats(gui); decorateModuleButtons(gui); decorateVehicleCards(gui); updateActionPopup(gui)
end
local function attach(gui)
	activeGui=gui; ending=false; task.defer(function() layout(gui) end)
	local exitPanel=gui:FindFirstChild("DealershipExitPinnedBottomRight",true); local exit=textButton(exitPanel,"Exit"); if exit then exit.MouseButton1Click:Connect(function() if ending then return end; ending=true; pcall(function() request:InvokeServer("End",{ReturnToEntry=true}) end); player:SetAttribute("NTR_GarageEntryMode",nil) end) end
	gui:GetPropertyChangedSignal("Enabled"):Connect(function() if not gui.Enabled and player:GetAttribute("NTR_GarageSessionActive")==true and not ending then ending=true; pcall(function() request:InvokeServer("End",{ReturnToEntry=false}) end); player:SetAttribute("NTR_GarageEntryMode",nil) end end)
	gui.DescendantAdded:Connect(function() task.defer(function() if gui.Parent then layout(gui) end end) end); for _=1,20 do if not gui.Parent or not gui.Enabled then break end; layout(gui); task.wait(.1) end
end
player.PlayerGui.ChildAdded:Connect(function(child) if child.Name=="HOVER_RACING_V2_GarageUI" then task.defer(function() attach(child) end) end end)
local existing=player.PlayerGui:FindFirstChild("HOVER_RACING_V2_GarageUI"); if existing then attach(existing) end
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if activeGui and activeGui.Parent then layout(activeGui) end end) end
RunService.RenderStepped:Connect(function()
	if not (activeGui and activeGui.Parent and activeGui.Enabled) then return end
	local browsing=stageVisible(activeGui,"CockpitShop")
	if browsing and os.clock()>=nextLayoutRefresh then nextLayoutRefresh=os.clock()+.12; layout(activeGui) end
	if leftArrow then leftArrow.Visible=browsing end
	if rightArrow then rightArrow.Visible=browsing end
	if browsing then updateActionPopup(activeGui) end
end)
