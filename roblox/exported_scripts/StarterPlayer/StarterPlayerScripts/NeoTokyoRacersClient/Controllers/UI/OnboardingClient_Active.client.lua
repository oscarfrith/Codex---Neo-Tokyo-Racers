-- NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_1
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_2
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1_3
-- NTR_PRESENTATION_AUDIO_OBJECTIVES_V1
-- NTR_PRESENTATION_AUDIO_ONBOARDING_HOVER_SILENT_V1_1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local TextService=game:GetService("TextService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("Onboarding_EditAttributes")
local loadingConfig=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")
local Racing=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local AudioBridge=require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioBridge"))
local GuideTrail=require(script.Parent:WaitForChild("OnboardingGuideTrailRenderer"))
local remotes=kit.Shared.Remotes:WaitForChild("Onboarding")
local invoke=remotes:WaitForChild("OnboardingInvoke")
local stateChanged=remotes:WaitForChild("OnboardingStateChanged")
local state={Stage=1,SeenPages={},Completed={}}
local stateReady=false
local guideTrail=GuideTrail.new(config)
local activePage,activeIndex
local presentationOwners={}
local GOLD=config:GetAttribute("TutorialGold") or Color3.fromRGB(255,196,66)
local DEEP=Color3.fromRGB(10,14,23)
local TEXT=Color3.fromRGB(246,248,252)
local FONT=Enum.Font.Michroma
local function setting(name,fallback) local value=config:GetAttribute(name); return value==nil and fallback or value end

local copy={
 G1="Vehicle categories group cars into families. Cars in the same category can share compatible modules.",
 G4="Tier shows the vehicle's performance class. Overall rating gives a quick summary of its total performance.",
 A2="You have limited vehicle space. Buy more garages to increase your capacity.",
 G2="Select a vehicle to preview it. Buy it to add it to your collection.",
 J1="Buy and equip modules in each vehicle slot. Modules can be swapped between vehicles in the same category.",
 J2="Upgrade the modules fitted to your vehicle. Each module has several upgrade paths and a limited point budget.",
 J3="Change your vehicle's paint and lighting per module. You can also customise thrust, neon and underglow.",
 K1="Choose a module location. Buy and swap modules from your different owned vehicles.",
 L1="Choose an equipped module to see its upgrades. Different modules offer different upgrade paths.",
 L2="Each module has a limited upgrade-point budget. Spending points on one upgrade leaves fewer for the others.",
 M1="Choose which part of the vehicle you want to customise. You can edit the whole vehicle, cockpit, effects or individual modules.",
 D7="Use the drift arrows while turning to slide around corners. Drifting helps with tighter turns.",
 D8="Hold Boost for a burst of speed. The boost meter shows how much energy remains.",
 B2="Open My Vehicles to spawn, switch or despawn your cars. New vehicles appear here after you buy them.",
 B4="Open the Race Browser to find events around the city. Events can support races, time trials or both.",
 N1="Select an event to view its route and details.",
 N6="Teleport to the selected event's starting area.",
 O1="Choose Race to compete against other players. Choose Time Trial to race against target times.",
 Q1="Choose a vehicle class for the time trial. Each class has separate target times, records and eligible vehicles.",
 Q5="This shows your selected class and the best available reward. Higher tiers have greater rewards.",
 Q8="Beat these target times to earn medals and cash. Faster times award higher medals.",
 Q4="Choose how many timed laps you want to run. Your best completed lap is used for the result.",
 P1="This shows the route, lap count and player limit. Multiplayer races use an open vehicle category.",
 B3="Open My Garages to view your owned properties. Each garage can display vehicles and has its own customisation.",
 X1="Choose one of your owned garage properties. Each card shows how many display spaces it contains.",
 X3="Enter the selected garage. You can manage its vehicles, assets and appearance from inside.",
 Z1="Choose which owned vehicles are displayed in your garage. Each vehicle is assigned to a physical display space.",
 Z2="Buy and equip different walls, floors, ceilings, decorations and lighting.",
 Z3="Customise the assets already equipped in your garage. Change their colours, materials and lighting.",
 AA1="Choose a display space to manage. Empty spaces can receive a vehicle, while occupied spaces can be changed.",
 AB1="Choose Structure, Decorations or Lighting. Build adds new assets; Style changes the look of equipped assets.",
 AC1="Choose which section of the garage you want to rebuild. The selected style is previewed in that location.",
 AD1="Choose where you want to place a decoration. Each location has its own compatible asset options.",
}
local pages={
 Dealership={"G1","G4","A2","G2"}, CustomisationHome={"J1","J2","J3"}, AddModules={"K1"},
 UpgradeModules={"L1","L2"}, PaintShop={"M1"}, MobileDriving={"D7","D8"}, VehicleShortcut={"B2"},
 RaceShortcut={"B4"}, RaceBrowser={"N1","N6"}, EventMode={"O1"}, TimeTrialSetup={"Q1","Q5","Q8","Q4"},
 RaceSetup={"P1"}, GarageShortcut={"B3"}, GarageBrowser={"X1","X3"},
 GarageHome={"Z1","Z2","Z3"}, DisplayCars={"AA1"}, GarageAssetFamilies={"AB1"}, BuildStructure={"AC1"}, BuildDecorations={"AD1"},
}
local actionSteps={N6=true,X3=true}
local placement={B2="Below",B3="Below",B4="Below",G4="Left",O1="Below",L2="Above",Z1="Above",Z2="Above",Z3="Above",AA1="Above",AB1="Above"}

local gui=Instance.new("ScreenGui"); gui.Name="NTR_OnboardingV1"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.DisplayOrder=math.max(1,(tonumber(loadingConfig:GetAttribute("DisplayOrder")) or 1000)-10); gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
pcall(function() gui.ScreenInsets=Enum.ScreenInsets.None end); pcall(function() gui.ClipToDeviceSafeArea=false end); gui.Parent=playerGui
local overlay=Instance.new("Frame"); overlay.Name="Overlay"; overlay.BackgroundTransparency=1; overlay.BorderSizePixel=0; overlay.Size=UDim2.fromScale(1,1); overlay.Parent=gui
local objectiveLayer=Instance.new("Frame"); objectiveLayer.Name="Objectives"; objectiveLayer.BackgroundTransparency=1; objectiveLayer.BorderSizePixel=0; objectiveLayer.Size=UDim2.fromScale(1,1); objectiveLayer.ClipsDescendants=false; objectiveLayer.ZIndex=10; objectiveLayer.Parent=gui
local objectiveCards={}
local shade={}; for i=1,4 do local f=Instance.new("TextButton"); f.Name="Shade"..i; f.Text=""; f.AutoButtonColor=false; f.BackgroundColor3=Color3.new(0,0,0); f.BackgroundTransparency=setting("DimTransparency",.35); f.BorderSizePixel=0; f.Visible=false; f.Active=true; f.ZIndex=20; f:SetAttribute("UIAudioHoverCue",""); f.Parent=overlay; shade[i]=f end
local catch=Instance.new("TextButton"); catch.Name="Advance"; catch.Text=""; catch.AutoButtonColor=false; catch.BackgroundTransparency=1; catch.Size=UDim2.fromScale(1,1); catch.Visible=false; catch.Active=true; catch.ZIndex=21; catch:SetAttribute("UIAudioHoverCue",""); catch.Parent=overlay; pcall(function() catch.Modal=true end)
local border=Racing.Panel(overlay,{Name="HighlightBorder",Color=DEEP,Transparency=1,StrokeColor=GOLD,StrokeWidth=3,GlowWidth=4,GlowTransparency=.72,Radius=8}); border.Visible=false; border.ZIndex=22
local connector=Instance.new("Frame"); connector.Name="Connector"; connector.BackgroundColor3=GOLD; connector.BorderSizePixel=0; connector.Visible=false; connector.ZIndex=22; connector.Parent=overlay; Racing.Corner(connector,2)
local bubble=Racing.Panel(overlay,{Name="Bubble",Color=DEEP,Transparency=.03,StrokeColor=GOLD,StrokeWidth=2,GlowWidth=4,GlowTransparency=.76,Radius=8}); bubble.Visible=false; bubble.ZIndex=23; bubble.Active=true
local bubbleText=Racing.Label(bubble,{Name="Copy",Text="",Color=TEXT,Wrapped=true,YAlignment=Enum.TextYAlignment.Center}); bubbleText.ZIndex=24
local nextButton=Racing.Button(bubble,{Name="Next",Text="NEXT",Color=GOLD,TextColor=DEEP,StrokeColor=GOLD,FocusColor=GOLD,FocusFill=GOLD,Radius=6,ZIndex=24}); nextButton.AnchorPoint=Vector2.zero; nextButton:SetAttribute("UIAudioHoverCue","")
local nextGradient=nextButton:FindFirstChild("GradientOverlay"); if nextGradient and nextGradient:IsA("Frame") then nextGradient.BackgroundTransparency=setting("NextGradientTransparency",.62) end

local function visible(object)
	if not (object and object:IsA("GuiObject") and object.AbsoluteSize.X>2 and object.AbsoluteSize.Y>2) then return false end
	local at=object
	while at and at~=playerGui do
		if at:IsA("GuiObject") and not at.Visible then return false end
		if at:IsA("LayerCollector") and not at.Enabled then return false end
		at=at.Parent
	end
	return at==playerGui
end
local function scopeRoot(object)
	if not object then return nil end
	local at=object
	while at.Parent and at.Parent~=playerGui do
		if at.Parent:IsA("ScreenGui") or at.Parent.Name=="CanonicalCanvas" then return at end
		at=at.Parent
	end
	return at
end
local function namedIn(root,name)
	if root and root.Name==name and visible(root) then return root end
	for _,object in ipairs(root and root:GetDescendants() or {}) do if object.Name==name and visible(object) then return object end end
end
local function named(name,root)
	if root then return namedIn(root,name) end
	for _,object in ipairs(playerGui:GetDescendants()) do if object.Name==name and visible(object) then return object end end
end
local function buttonWithText(text,root)
	text=string.upper(text); local search=root and root:GetDescendants() or playerGui:GetDescendants()
	for _,object in ipairs(search) do
		if (object:IsA("TextLabel") or object:IsA("TextButton")) and visible(object) and string.upper(object.Text)==text then
			local at=object
			while at and at~=playerGui do if at:IsA("GuiButton") and visible(at) then return at end; at=at.Parent end
		end
	end
end
local function labelStarts(prefix,root)
	prefix=string.upper(prefix); local search=root and root:GetDescendants() or playerGui:GetDescendants()
	for _,object in ipairs(search) do if object:IsA("TextLabel") and visible(object) and string.sub(string.upper(object.Text),1,#prefix)==prefix then return object end end
end
local function screenRoot(name)
	local screen=playerGui:FindFirstChild(name)
	if not (screen and screen:IsA("ScreenGui") and screen.Enabled) then return nil end
	for _,object in ipairs(screen:GetChildren()) do if object:IsA("GuiObject") and visible(object) then return object end end
	for _,object in ipairs(screen:GetDescendants()) do if object:IsA("GuiObject") and visible(object) then return scopeRoot(object) end end
end
local function canonicalBrowser()
	local screen=playerGui:FindFirstChild("CanonicalGarageGui"); local canvas=screen and screen:FindFirstChild("CanonicalCanvas"); local browser=canvas and canvas:FindFirstChild("CanonicalGarageBrowser")
	if browser and visible(browser) and buttonWithText("DEALERSHIP",browser)==nil then
		for _,object in ipairs(browser:GetDescendants()) do if object:IsA("TextLabel") and visible(object) and string.upper(object.Text)=="DEALERSHIP" then return browser end end
	elseif browser and visible(browser) then return browser end
end
local function group(root,...)
	local result={}; for _,name in ipairs({...}) do local object=named(name,root); if object then table.insert(result,object) end end; return #result>0 and result or nil
end
local function textGroup(root,...)
	local result={}; for _,value in ipairs({...}) do local object=buttonWithText(value,root); if object then table.insert(result,object) end end; return #result>0 and result or nil
end
local function cardGroup(root,...)
	local wanted={}; for _,id in ipairs({...}) do wanted[tostring(id)]=true end; local filter=next(wanted)~=nil; local result={}
	for _,object in ipairs(root and root:GetDescendants() or {}) do
		if object:IsA("GuiButton") and object:GetAttribute("CanonicalGarageCard")==true and visible(object) then
			local id=tostring(object:GetAttribute("CanonicalGarageCardId") or "")
			if not filter or wanted[id] then table.insert(result,object) end
		end
	end
	return #result>0 and result or nil
end
local function visibleScrollerCards(root,scrollerName)
	local scroller=named(scrollerName,root)
	if not scroller then return nil end
	local scrollerPosition,scrollerSize=scroller.AbsolutePosition,scroller.AbsoluteSize
	local result,fallback={},{}
	for _,object in ipairs(scroller:GetDescendants()) do
		if object:IsA("GuiButton") and object:GetAttribute("CanonicalGarageCard")==true and visible(object) then
			local position,size=object.AbsolutePosition,object.AbsoluteSize
			local intersects=position.X+size.X>scrollerPosition.X and position.X<scrollerPosition.X+scrollerSize.X
				and position.Y+size.Y>scrollerPosition.Y and position.Y<scrollerPosition.Y+scrollerSize.Y
			if intersects then
				table.insert(fallback,object)
				local fullyVisible=position.X>=scrollerPosition.X-1 and position.X+size.X<=scrollerPosition.X+scrollerSize.X+1
					and position.Y>=scrollerPosition.Y-1 and position.Y+size.Y<=scrollerPosition.Y+scrollerSize.Y+1
				if fullyVisible then table.insert(result,object) end
			end
		end
	end
	return #result>0 and result or #fallback>0 and fallback or nil
end
local function workspacePage(pageId)
	for _,root in ipairs(playerGui:GetDescendants()) do
		if root:IsA("GuiObject") and root:GetAttribute("TutorialWorkspace")==true and visible(root) and root:GetAttribute("TutorialPageId")==pageId then return root end
	end
end
local resolvers={
 G1=function(root) return group(root,"Categories") end, G4=function(root) return group(root,"Stats") end, A2=function(root) return group(root,"Capacity") end, G2=function(root) return visibleScrollerCards(root,"VehicleScroller") end,
 J1=function(root) return cardGroup(root,"AddModules") end, J2=function(root) return cardGroup(root,"UpgradeModules") end, J3=function(root) return cardGroup(root,"PaintShop") end,
 K1=function(root) return visibleScrollerCards(root,"TutorialCardScroller") end, L1=function(root) return group(root,"Categories") end, L2=function(root) return group(root,"UpgradeBudget") end, M1=function(root) return group(root,"Categories") end,
 D7=function(root) return group(root,"DriftLeft","DriftRight","DriftLeftButton","DriftRightButton") end, D8=function(root) return group(root,"Boost","BoostButton") end,
 B2=function(root) return group(root,"Car") end, B3=function(root) return group(root,"Garage") end, B4=function(root) return group(root,"Race") end,
 N1=function(root) return group(root,"CardContent") end, N6=function(root) return group(root,"TeleportToStart") end,
 O1=function(root) return textGroup(root,"TIME TRIAL","RACE") end, Q1=function(root) return group(root,"TierE","TierD","TierC","TierB","TierA","TierS") end, Q5=function(root) return group(root,"PrizeSummary") end, Q8=function(root) return group(root,"MedalTargets") end, Q4=function(root) return group(root,"LapSelector") end,
 P1=function(root) return group(root,"RaceFormat") or group(root,"DetailColumn") end,
 X1=function(root) return group(root,"GarageList") end, X3=function(root) return group(root,"Enter") end,
 Z1=function(root) return cardGroup(root,"DisplayCars") end, Z2=function(root) return cardGroup(root,"BuildGarage") end, Z3=function(root) return cardGroup(root,"StyleGarage") end,
 AA1=function(root) return visibleScrollerCards(root,"TutorialCardScroller") end, AB1=function(root) return cardGroup(root,"Structure","Decorations","Lighting") end, AC1=function(root) return group(root,"Categories") end, AD1=function(root) return group(root,"Categories") end,
}
local pageSignals={
 Dealership=function() return canonicalBrowser() end,
 CustomisationHome=function() return workspacePage("CustomisationHome") end,
 AddModules=function() return workspacePage("AddModules") end,
 UpgradeModules=function() return workspacePage("UpgradeModules") end,
 PaintShop=function() return workspacePage("PaintShop") end,
 MobileDriving=function() local object=UserInputService.TouchEnabled and (named("DriftLeft") or named("DriftLeftButton")); return object and scopeRoot(object) end,
 VehicleShortcut=function() local object=state.Stage>=2 and named("Car"); return object and scopeRoot(object) end,
 RaceShortcut=function() local object=state.SeenPages.GarageShortcut==true and named("Race"); return object and scopeRoot(object) end,
 RaceBrowser=function() return screenRoot("NTR_RaceBrowser") end,
 EventMode=function() local root=screenRoot("NTR_RaceEntryPresentation"); return root and buttonWithText("TIME TRIAL",root) and buttonWithText("RACE",root) and root end,
 TimeTrialSetup=function() local object=named("TierE"); local root=scopeRoot(object); return root and named("LapSelector",root) and root end,
 RaceSetup=function() local object=named("RaceFormat"); return object and scopeRoot(object) end,
 GarageShortcut=function() local object=state.SeenPages.VehicleShortcut==true and named("Garage"); return object and scopeRoot(object) end,
 GarageBrowser=function() return screenRoot("NTR_OwnedGarageBrowser") end,
 GarageHome=function() return workspacePage("GarageHome") end,
 DisplayCars=function() return workspacePage("DisplayCars") end,
 GarageAssetFamilies=function() return workspacePage("GarageAssetFamilies") end,
 BuildStructure=function() return workspacePage("BuildStructure") end,
 BuildDecorations=function() return workspacePage("BuildDecorations") end,
}
local pageOrder={"Dealership","CustomisationHome","AddModules","UpgradeModules","PaintShop","MobileDriving","VehicleShortcut","GarageShortcut","GarageBrowser","GarageHome","DisplayCars","GarageAssetFamilies","BuildStructure","BuildDecorations","RaceShortcut","RaceBrowser","EventMode","TimeTrialSetup","RaceSetup"}

local function canvasSize()
	local size=overlay.AbsoluteSize
	if size.X>2 and size.Y>2 then return size end
	local camera=workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function isLandscapePhone(canvas)
	local short=math.min(canvas.X,canvas.Y); local long=math.max(canvas.X,canvas.Y)
	return long>short and short<=setting("LandscapePhoneShortSidePixels",650)
end
local function ownerScale(objects,canvas)
	for _,object in ipairs(objects or {}) do
		local at=object
		while at and at~=playerGui do
			local scaler=at:FindFirstChildOfClass("UIScale")
			if scaler then return math.clamp(scaler.Scale,setting("TutorialMinimumScale",.38),setting("TutorialMaximumScale",1.08)) end
			at=at.Parent
		end
	end
	if isLandscapePhone(canvas) then return setting("LandscapePhoneScale",.6) end
	return math.clamp(math.min(canvas.X/1600,canvas.Y/900),setting("TutorialDesktopMinimumScale",.68),setting("TutorialMaximumScale",1.08))
end
local function tutorialMetrics(objects,canvas)
	local scale=ownerScale(objects,canvas); local phone=isLandscapePhone(canvas)
	local minimum=phone and setting("TutorialPhoneMinimumTextSize",9) or setting("TutorialDesktopMinimumTextSize",11)
	return scale,math.max(minimum,math.floor(setting("TutorialTextSize",14)*scale+.5)),phone
end
local function rect(objects,canvas)
	local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
	local origin=overlay.AbsolutePosition
	for _,object in ipairs(objects or {}) do
		if visible(object) then local p,s=object.AbsolutePosition-origin,object.AbsoluteSize; minX=math.min(minX,p.X); minY=math.min(minY,p.Y); maxX=math.max(maxX,p.X+s.X); maxY=math.max(maxY,p.Y+s.Y) end
	end
	if minX==math.huge then return end
	local scale=ownerScale(objects,canvas); local pad=math.max(3,setting("HighlightPaddingPixels",8)*scale)
	return math.floor(minX-pad),math.floor(minY-pad),math.ceil(maxX+pad),math.ceil(maxY+pad)
end
local layoutKey
local function hideOverlay() layoutKey=nil; for _,f in ipairs(shade) do f.Visible=false end; catch.Visible=false; border.Visible=false; bubble.Visible=false; connector.Visible=false end
local function guiInsets()
	local origin=overlay.AbsolutePosition
	local ok,topLeft,bottomRight=pcall(function() return GuiService:GetGuiInset() end)
	if not ok then return Vector2.zero,Vector2.zero end
	return topLeft-origin,bottomRight
end
local function safeRect(canvas,scale,reserveTopbar)
	local margin=math.max(6,setting("CalloutMarginPixels",12)*(scale or 1)); local left,top,right,bottom=margin,margin,canvas.X-margin,canvas.Y-margin
	local topLeft,bottomRight=guiInsets()
	left=math.max(left,topLeft.X+margin); right=math.min(right,canvas.X-bottomRight.X-margin); bottom=math.min(bottom,canvas.Y-bottomRight.Y-margin)
	if reserveTopbar~=false then top=math.max(top,topLeft.Y+margin) end
	return left,top,right,bottom
end
local function setShade(frame,x,y,w,h)
	frame.Position=UDim2.fromOffset(math.floor(x),math.floor(y)); frame.Size=UDim2.fromOffset(math.max(0,math.ceil(w)),math.max(0,math.ceil(h))); frame.Visible=true
end
local function placeConnector(x,y,right,bottom,bx,by,bw,bh,scale)
	local br,bottomBubble=bx+bw,by+bh; local thickness=math.max(2,math.floor(3*scale+.5))
	if bx>=right then connector.Position=UDim2.fromOffset(right,math.clamp((y+bottom)*.5,by,bottomBubble)); connector.Size=UDim2.fromOffset(math.max(thickness,bx-right),thickness)
	elseif br<=x then connector.Position=UDim2.fromOffset(br,math.clamp((y+bottom)*.5,by,bottomBubble)); connector.Size=UDim2.fromOffset(math.max(thickness,x-br),thickness)
	elseif by>=bottom then connector.Position=UDim2.fromOffset(math.clamp((x+right)*.5,bx,br),bottom); connector.Size=UDim2.fromOffset(thickness,math.max(thickness,by-bottom))
	else connector.Position=UDim2.fromOffset(math.clamp((x+right)*.5,bx,br),bottomBubble); connector.Size=UDim2.fromOffset(thickness,math.max(thickness,y-bottomBubble)) end
	connector.Visible=true
end
local function placeBubble(id,objects,x,y,right,bottom,canvas)
	local scale,textSize,phone=tutorialMetrics(objects,canvas); local safeLeft,safeTop,safeRight,safeBottom=safeRect(canvas,scale,not phone); local safeWidth=math.max(180,safeRight-safeLeft)
	local shortcut=id=="B2" or id=="B3" or id=="B4"; local phoneShortcut=phone and shortcut
	local stacked=safeWidth<setting("TutorialStackedWidthPixels",560); local pad=math.max(7,math.floor(16*scale+.5)); local gap=math.max(7,math.floor(14*scale+.5)); local buttonW=math.max(80,math.floor(104*scale+.5)); local buttonH=math.max(44,math.floor(44*scale+.5)); local action=actionSteps[id]==true
	local widthRatio=phoneShortcut and setting("LandscapePhoneShortcutWidthRatio",.34) or phone and setting("LandscapePhoneTextWidthRatio",.42) or .34; local widthCap=math.max(phone and 210 or 280,setting("TutorialMaximumTextWidth",520)*scale); local maxTextWidth=math.clamp(safeWidth*widthRatio,phone and 180 or 240,math.min(safeWidth,widthCap)); local bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(maxTextWidth,1000))
	local bw,bh
	if stacked and not action then
		bw=math.min(safeWidth,math.max(phone and 210 or 280,bounds.X+pad*2)); bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(bw-pad*2,1000)); bh=bounds.Y+pad*2+gap+buttonH
	else
		local reserve=action and 0 or gap+buttonW; local minimum=phone and math.max(220,300*scale) or math.max(300,360*scale)
		bw=math.min(safeWidth,math.max(minimum,bounds.X+pad*2+reserve)); local available=math.max(phone and 160 or 220,bw-pad*2-reserve); bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(available,1000)); bh=math.max(bounds.Y+pad*2,action and bounds.Y+pad*2 or buttonH+pad*2)
	end
	if phoneShortcut then
		local reserve=action and 0 or gap+buttonW; local cap=math.max(260,math.floor(safeWidth*setting("LandscapePhoneShortcutWidthRatio",.34)+.5))
		bw=math.min(bw,cap); local available=math.max(150,bw-pad*2-reserve); bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(available,1000)); bh=math.max(bounds.Y+pad*2,action and bounds.Y+pad*2 or buttonH+pad*2)
	end
	local targetW,targetH=right-x,bottom-y; local offset=phoneShortcut and math.max(1,math.floor(setting("LandscapePhoneShortcutGapPixels",2)+.5)) or shortcut and math.max(3,math.floor(setting("ShortcutCalloutGapPixels",7)*scale+.5)) or math.max(8,math.floor(18*scale+.5)); local above={x+(targetW-bw)*.5,y-bh-offset}; local below={x+(targetW-bw)*.5,bottom+offset}; local left={x-bw-offset,y+(targetH-bh)*.5}; local rightSide={right+offset,y+(targetH-bh)*.5}; local mode=placement[id] or (((y+bottom)*.5)>safeTop+(safeBottom-safeTop)*.62 and "Above" or "Auto")
	local candidates=mode=="Above" and {above,below,left,rightSide} or mode=="Below" and {below,above,left,rightSide} or mode=="Left" and {left,below,above,rightSide} or {rightSide,left,above,below}
	local bx,by
	for _,candidate in ipairs(candidates) do if candidate[1]>=safeLeft and candidate[2]>=safeTop and candidate[1]+bw<=safeRight and candidate[2]+bh<=safeBottom then bx,by=candidate[1],candidate[2]; break end end
	bx=math.clamp(bx or candidates[1][1],safeLeft,math.max(safeLeft,safeRight-bw)); by=math.clamp(by or candidates[1][2],safeTop,math.max(safeTop,safeBottom-bh))
	bubble.Position=UDim2.fromOffset(math.floor(bx),math.floor(by)); bubble.Size=UDim2.fromOffset(math.ceil(bw),math.ceil(bh)); bubbleText.Text=copy[id]; bubbleText.TextSize=textSize
	if stacked and not action then
		bubbleText.Position=UDim2.fromOffset(pad,pad); bubbleText.Size=UDim2.fromOffset(bw-pad*2,bounds.Y)
		nextButton.Position=UDim2.fromOffset(bw-pad-buttonW,bh-pad-buttonH); nextButton.Size=UDim2.fromOffset(buttonW,buttonH)
	else
		local reserve=action and 0 or gap+buttonW; bubbleText.Position=UDim2.fromOffset(pad,pad); bubbleText.Size=UDim2.fromOffset(bw-pad*2-reserve,bh-pad*2)
		nextButton.Position=UDim2.fromOffset(bw-pad-buttonW,(bh-buttonH)*.5); nextButton.Size=UDim2.fromOffset(buttonW,buttonH)
	end
	nextButton.TextSize=textSize; nextButton.Visible=not action; bubble.Visible=true; placeConnector(x,y,right,bottom,bx,by,bw,bh,scale)
end
local loadingState=script.Parent:WaitForChild("LoadingPresentationState")
local loadingChanged=script.Parent:WaitForChild("LoadingPresentationChanged")
local activeRoot,activeObjects
local targetConnections={}
local layoutGeneration=0
local resolveGeneration=0
local gateGeneration=0
local rootMissingAt
local warnedMissingTarget=false

local function loadingActive()
	return player:GetAttribute("NTR_StartScreenActive")==true or loadingState:GetAttribute("Active")==true
end
local function onboardingPresentationBlocked()
	return loadingActive()
		or player:GetAttribute("NTR_FirstDrivePresentationPending")==true
		or player:GetAttribute("NTR_DrivingControlsOpen")==true
end
local function disconnectTargets()
	for _,connection in ipairs(targetConnections) do connection:Disconnect() end
	table.clear(targetConnections)
end
local function geometryKey(id,objects,canvas)
	local x,y,right,bottom=rect(objects,canvas)
	if not x then return nil end
	x=math.clamp(x,0,canvas.X); y=math.clamp(y,0,canvas.Y); right=math.clamp(right,x,canvas.X); bottom=math.clamp(bottom,y,canvas.Y)
	local origin=overlay.AbsolutePosition
	return table.concat({id,x,y,right,bottom,math.floor(origin.X),math.floor(origin.Y),math.floor(canvas.X),math.floor(canvas.Y)},":"),x,y,right,bottom
end
local function renderPinned()
	if onboardingPresentationBlocked() or not (activePage and activeObjects) then hideOverlay(); return end
	local id=pages[activePage][activeIndex]; local canvas=canvasSize()
	local nextLayoutKey,x,y,right,bottom=geometryKey(id,activeObjects,canvas); if not nextLayoutKey then hideOverlay(); return end
	local action=actionSteps[id]==true
	if layoutKey==nextLayoutKey and border.Visible and bubble.Visible then catch.Visible=not action; nextButton.Visible=not action; return end
	layoutKey=nextLayoutKey
	local overscan=setting("EdgeOverscanPixels",8)
	setShade(shade[1],-overscan,-overscan,canvas.X+overscan*2,y+overscan)
	setShade(shade[2],-overscan,y,x+overscan,bottom-y)
	setShade(shade[3],right,y,canvas.X-right+overscan,bottom-y)
	setShade(shade[4],-overscan,bottom,canvas.X+overscan*2,canvas.Y-bottom+overscan)
	local scale=ownerScale(activeObjects,canvas); local stroke=border:FindFirstChild("Stroke"); local glow=border:FindFirstChild("GlowStroke"); if stroke then stroke.Thickness=math.max(1.5,3*scale) end; if glow then glow.Thickness=math.max(2,4*scale) end
	local bubbleStroke=bubble:FindFirstChild("Stroke"); local bubbleGlow=bubble:FindFirstChild("GlowStroke"); if bubbleStroke then bubbleStroke.Thickness=math.max(1.5,2*scale) end; if bubbleGlow then bubbleGlow.Thickness=math.max(2,4*scale) end
	border.Position=UDim2.fromOffset(x,y); border.Size=UDim2.fromOffset(right-x,bottom-y); border.Visible=true
	placeBubble(id,activeObjects,x,y,right,bottom,canvas); catch.Visible=not action
end
local function scheduleLayout()
	layoutGeneration+=1; local generation=layoutGeneration
	task.spawn(function()
		local stableFrames=math.max(2,math.floor(setting("TargetStabilityFrames",2))); local previous
		for _=1,stableFrames do
			RunService.RenderStepped:Wait()
			if generation~=layoutGeneration or onboardingPresentationBlocked() or not (activePage and activeObjects) then return end
			local canvas=canvasSize(); local id=pages[activePage][activeIndex]; local key=geometryKey(id,activeObjects,canvas)
			if not key then hideOverlay(); return end
			if previous and previous~=key then scheduleLayout(); return end
			previous=key
		end
		if generation==layoutGeneration then renderPinned() end
	end)
end
overlay:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() if activePage then scheduleLayout() end end)
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if activePage then scheduleLayout() end end)
local scheduleResolve
local advance
local syncObjectives
local function pinObjects(objects)
	disconnectTargets(); activeObjects=objects; rootMissingAt=nil; warnedMissingTarget=false
	local id=activePage and pages[activePage] and pages[activePage][activeIndex]
	for _,object in ipairs(objects) do
		table.insert(targetConnections,object:GetPropertyChangedSignal("AbsolutePosition"):Connect(scheduleLayout))
		table.insert(targetConnections,object:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleLayout))
		table.insert(targetConnections,object:GetPropertyChangedSignal("Visible"):Connect(scheduleResolve))
		table.insert(targetConnections,object.AncestryChanged:Connect(scheduleResolve))
		if actionSteps[id] and object:IsA("GuiButton") then
			table.insert(targetConnections,object.Activated:Connect(function()
				local expectedPage,expectedIndex,expectedId=activePage,activeIndex,id
				task.defer(function()
					if activePage==expectedPage and activeIndex==expectedIndex and pages[activePage][activeIndex]==expectedId then advance() end
				end)
			end))
		end
	end
	scheduleLayout()
end
scheduleResolve=function()
	resolveGeneration+=1; local generation=resolveGeneration; hideOverlay(); disconnectTargets(); activeObjects=nil
	task.delay(.08,function()
		if generation~=resolveGeneration or onboardingPresentationBlocked() or not activePage then return end
		if not (activeRoot and activeRoot.Parent and visible(activeRoot)) then
			local signal=pageSignals[activePage]; local ok,newRoot=signal and pcall(signal)
			if ok and newRoot then activeRoot=newRoot; rootMissingAt=nil
			else
				rootMissingAt=rootMissingAt or os.clock()
				if os.clock()-rootMissingAt>=setting("PageAbandonSeconds",3) then
					print("[NTR Tutorial] page closed before completion: "..tostring(activePage)); activePage=nil; activeIndex=nil; activeRoot=nil; resolveGeneration+=1
				else scheduleResolve() end
				return
			end
		end
		local id=pages[activePage][activeIndex]; local objects=resolvers[id] and resolvers[id](activeRoot)
		if objects then pinObjects(objects)
		else
			if not warnedMissingTarget and rootMissingAt and os.clock()-rootMissingAt>1 then warnedMissingTarget=true; warn("[NTR Tutorial] waiting for target "..tostring(activePage).." "..tostring(id)) end
			rootMissingAt=rootMissingAt or os.clock(); scheduleResolve()
		end
	end)
end
local function beginPage(pageId,root)
	activePage=pageId; activeIndex=1; activeRoot=root; rootMissingAt=nil
	print("[NTR Tutorial] begin "..pageId.." "..pages[pageId][1]); scheduleResolve()
end
local function markSeen(pageId)
	local ok,result=pcall(function() return invoke:InvokeServer("MarkSeen",{PageId=pageId}) end)
	if ok and type(result)=="table" and result.Success then state=result end
end
local lastAdvance=0
advance=function()
	if not activePage or os.clock()-lastAdvance<.18 then return end
	lastAdvance=os.clock()
	activeIndex+=1
	if activeIndex>#pages[activePage] then
		local done=activePage; state.SeenPages[done]=true; activePage=nil; activeIndex=nil; activeRoot=nil; activeObjects=nil; resolveGeneration+=1; disconnectTargets(); hideOverlay(); print("[NTR Tutorial] complete "..done); task.defer(function() if syncObjectives then syncObjectives() end end); task.spawn(markSeen,done)
	else
		print("[NTR Tutorial] advance "..activePage.." "..pages[activePage][activeIndex]); scheduleResolve()
	end
end
catch.Activated:Connect(advance); nextButton.Activated:Connect(advance)

local function visibleRoot(name)
	local object=named(name)
	return object and scopeRoot(object) or nil
end
local function controlsOpen()
	if player:GetAttribute("NTR_DrivingControlsOpen")==true then return true end
	local screen=playerGui:FindFirstChild("NTR_DesktopFreeRoamHud")
	local design=screen and screen:FindFirstChild("DesignRoot")
	local modal=design and design:FindFirstChild("ModalLayer")
	local controls=modal and modal:FindFirstChild("Controls")
	return modal and controls and visible(modal) and visible(controls)
end
local function majorMenuOpen()
	for _,active in pairs(presentationOwners) do if active then return true end end
	if canonicalBrowser() then return true end
	for _,root in ipairs(playerGui:GetDescendants()) do if root:IsA("GuiObject") and root:GetAttribute("TutorialWorkspace")==true and visible(root) then return true end end
	for _,name in ipairs({"NTR_RaceBrowser","NTR_RaceEntryPresentation","NTR_OwnedGarageBrowser"}) do if screenRoot(name) then return true end end
	return playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true
		or (player:GetAttribute("NTR_GarageSessionActive")==true and player:GetAttribute("NTR_GarageSessionMode")~="Dealership") -- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
		or player:GetAttribute("NTR_RaceSessionActive")==true
		or player:GetAttribute("NTRMobileFreeRoamCarMenuOpen")==true
		or player:GetAttribute("NTRMobileMajorMenuOpen")==true
		or visibleRoot("CarPanel")~=nil
		or visibleRoot("ModalLayer")~=nil
		or controlsOpen()==true
end
local objectiveContent={
	[1]={Title="BUY AND CUSTOMISE A CAR"},
	[2]={Title="EXPLORE YOUR GARAGE",Hint="Enter your garage and open customisation."},
	[3]={Title="ENTER AN EVENT",Hint="Join a race or start a time trial."},
}
local objectiveCompletionSnapshot=nil
local objectiveLayout={Left=16,Top=66,Width=350,Height=98,Gap=8,Scale=1,Safe=6,Phone=false}
local function objectiveComplete(index)
	if index==1 then return state.Completed.FirstVehiclePurchased==true and state.Completed.FirstVehicleDriven==true and state.SeenPages.VehicleShortcut==true end
	if index==2 then return state.Completed.GarageManagementEntered==true end
	return state.Completed.FirstEventEntered==true
end
local function objectiveDesired(index)
	if index==1 then return not objectiveComplete(1) end
	if index==2 then return objectiveComplete(1) and state.SeenPages.GarageShortcut==true and not objectiveComplete(2) end
	return state.SeenPages.RaceShortcut==true and not objectiveComplete(3)
end
local function objectiveHint(index)
	if index==1 then return state.Completed.FirstVehiclePurchased==true and "Start driving your new vehicle." or "Follow the trail to the dealership." end
	return objectiveContent[index].Hint
end
local function objectiveOrder()
	local result={}
	for _,index in ipairs({1,2,3}) do if objectiveDesired(index) then table.insert(result,index) end end
	return result
end
local function createObjectiveCard(index)
	local group=Instance.new("CanvasGroup"); group.Name="Objective"..index; group.BackgroundTransparency=1; group.BorderSizePixel=0; group.GroupTransparency=1; group.ZIndex=10; group.Parent=objectiveLayer
	local panel=Racing.Panel(group,{Name="Panel",Color=DEEP,Transparency=.08,StrokeColor=GOLD,StrokeWidth=2,GlowWidth=5,GlowTransparency=.78,Radius=8}); panel.Size=UDim2.fromScale(1,1); panel.ZIndex=10; panel.Active=true
	local label=Racing.Label(panel,{Text="OBJECTIVE "..index,Color=GOLD,Role="Heading"}); label.ZIndex=11
	local title=Racing.Label(panel,{Text=objectiveContent[index].Title,Color=TEXT,Role="Heading",Wrapped=true,YAlignment=Enum.TextYAlignment.Top}); title.ZIndex=11
	local hint=Racing.Label(panel,{Text=objectiveHint(index),Color=Color3.fromRGB(190,196,210),Wrapped=true,YAlignment=Enum.TextYAlignment.Top}); hint.ZIndex=11
	local progress=Racing.Label(panel,{Text=index.."/3",Color=GOLD,XAlignment=Enum.TextXAlignment.Right,Role="Heading",Truncate=Enum.TextTruncate.None}); progress.ZIndex=11
	local card={Index=index,Group=group,Panel=panel,Label=label,Title=title,Hint=hint,Progress=progress,Animating=false,Exiting=false}
	objectiveCards[index]=card
	return card
end
local function styleObjectiveCard(card)
	local layout=objectiveLayout; local scale=layout.Scale; local safe=layout.Safe; local phone=layout.Phone; local pad=math.max(phone and 7 or 9,math.floor(setting("ObjectiveCardPaddingPixels",16)*scale+.5)); local textMultiplier=phone and 1 or setting("ObjectiveDesktopTextMultiplier",1.5)
	local function textSize(name,fallback,minimum) return math.max(minimum,math.floor(setting(name,fallback)*scale*textMultiplier+.5)) end
	local numberSize=textSize("ObjectiveNumberTextSize",10,8); local titleSize=textSize("ObjectiveTitleTextSize",13,9); local hintSize=textSize("ObjectiveHintTextSize",10,8); local progressSize=textSize("ObjectiveProgressTextSize",9,8)
	card.Group.Size=UDim2.fromOffset(layout.Width+safe*2,layout.Height+safe*2)
	card.Group.ClipsDescendants=false
	card.Panel.Position=UDim2.fromOffset(safe,safe); card.Panel.Size=UDim2.fromOffset(layout.Width,layout.Height); card.Panel.ClipsDescendants=false
	if phone then
		local labelY=3; local labelH=math.max(9,math.ceil(numberSize*1.1)); local titleY=labelY+labelH; local titleH=math.max(12,math.ceil(titleSize*1.25)); local hintY=titleY+titleH+1
		local hintLineH=math.max(9,math.ceil(hintSize*1.15)); local descriptionBottom=math.min(layout.Height-3,hintY+hintLineH*2); local progressH=14
		card.Label.Position=UDim2.fromOffset(pad,labelY); card.Label.Size=UDim2.new(1,-pad*2,0,labelH)
		card.Title.Position=UDim2.fromOffset(pad,titleY); card.Title.Size=UDim2.new(1,-pad*2,0,titleH)
		card.Hint.Position=UDim2.fromOffset(pad,hintY); card.Hint.Size=UDim2.new(1,-66,0,math.max(hintLineH,descriptionBottom-hintY))
		card.Progress.Position=UDim2.fromOffset(layout.Width-57,descriptionBottom-progressH); card.Progress.Size=UDim2.fromOffset(48,progressH)
	else
		card.Label.Position=UDim2.fromOffset(pad,6); card.Label.Size=UDim2.new(1,-pad*2,0,18)
		card.Title.Position=UDim2.fromOffset(pad,22); card.Title.Size=UDim2.new(1,-pad*2,0,38)
		local hintY=57; local hintLineH=math.max(12,math.ceil(hintSize*1.15)); local descriptionBottom=layout.Height-7; local progressH=18
		card.Hint.Position=UDim2.fromOffset(pad,hintY); card.Hint.Size=UDim2.new(1,-82,0,math.max(hintLineH,descriptionBottom-hintY)) -- NTR_ONBOARDING_DESKTOP_TWO_LINE_OBJECTIVE_V1
		card.Progress.Position=UDim2.fromOffset(layout.Width-66,hintY+math.floor((descriptionBottom-hintY-progressH)*.5)); card.Progress.Size=UDim2.fromOffset(52,progressH)
	end
	card.Label.TextSize=numberSize
	card.Title.TextSize=titleSize
	card.Hint.Text=objectiveHint(card.Index); card.Hint.TextSize=hintSize
	card.Progress.TextSize=progressSize
	local stroke=card.Panel:FindFirstChild("Stroke"); local glow=card.Panel:FindFirstChild("GlowStroke"); if stroke then stroke.Thickness=math.max(1,2*scale) end; if glow then glow.Thickness=math.max(2,4*scale) end
end
local function targetObjectivePosition(orderIndex)
	local layout=objectiveLayout
	return UDim2.fromOffset(layout.Left-layout.Safe,layout.Top-layout.Safe+(orderIndex-1)*(layout.Height+layout.Gap))
end
local function cancelObjectiveTween(card)
	if card.Tween then card.Tween:Cancel(); card.Tween=nil end
end
local function layoutObjectives(animate)
	for orderIndex,index in ipairs(objectiveOrder()) do
		local card=objectiveCards[index]
		if card and not card.Exiting then
			styleObjectiveCard(card)
			local target=targetObjectivePosition(orderIndex)
			if not card.Animating then
				cancelObjectiveTween(card)
				if animate then
					card.Animating=true
					card.Tween=TweenService:Create(card.Group,TweenInfo.new(setting("ObjectiveReflowSeconds",.45),Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=target})
					card.Tween.Completed:Once(function() card.Animating=false; card.Tween=nil end)
					card.Tween:Play()
				else card.Group.Position=target end
			end
		end
	end
end
local function enterObjective(index,stagger)
	if not objectiveDesired(index) or objectiveCards[index] then return end
	task.delay(stagger or 0,function()
		if not objectiveDesired(index) or objectiveCards[index] then return end
		local card=createObjectiveCard(index); styleObjectiveCard(card)
		local orderIndex=table.find(objectiveOrder(),index) or 1; local target=targetObjectivePosition(orderIndex)
		card.Group.Position=UDim2.fromOffset(objectiveLayout.Left-objectiveLayout.Width-objectiveLayout.Safe*2-setting("ObjectiveOffscreenPaddingPixels",24),target.Y.Offset)
		card.Animating=true
		card.Tween=TweenService:Create(card.Group,TweenInfo.new(setting("ObjectiveEnterSeconds",.55),Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=target,GroupTransparency=0})
		card.Tween.Completed:Once(function() card.Animating=false; card.Tween=nil end)
		card.Tween:Play()
	end)
end
local function exitObjective(index)
	local card=objectiveCards[index]
	if not card or card.Exiting then return end
	card.Exiting=true; cancelObjectiveTween(card)
	task.delay(setting("ObjectiveExitHoldSeconds",.15),function()
		if objectiveCards[index]~=card then return end
		card.Animating=true
		local target=UDim2.fromOffset(objectiveLayout.Left-objectiveLayout.Width-objectiveLayout.Safe*2-setting("ObjectiveOffscreenPaddingPixels",24),card.Group.Position.Y.Offset)
		card.Tween=TweenService:Create(card.Group,TweenInfo.new(setting("ObjectiveExitSeconds",.4),Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=target,GroupTransparency=1})
		card.Tween.Completed:Once(function()
			if objectiveCards[index]==card then objectiveCards[index]=nil end
			card.Group:Destroy()
		end)
		card.Tween:Play()
	end)
end
syncObjectives=function()
	if not stateReady then return end
	local objectiveOneWasComplete=objectiveCompletionSnapshot and objectiveCompletionSnapshot[1] or false
	local objectiveOneNowComplete=objectiveComplete(1)
	for _,index in ipairs({1,2,3}) do if objectiveCards[index] and not objectiveDesired(index) then exitObjective(index) end end
	local unlockDelay=objectiveCompletionSnapshot and not objectiveOneWasComplete and objectiveOneNowComplete
		and setting("ObjectiveExitHoldSeconds",.15)+setting("ObjectiveExitSeconds",.4) or 0
	for orderIndex,index in ipairs(objectiveOrder()) do
		if not objectiveCards[index] then enterObjective(index,unlockDelay+(orderIndex-1)*setting("ObjectiveStaggerSeconds",.1)) end
	end
	local nextCompletion={objectiveComplete(1),objectiveComplete(2),objectiveComplete(3)}
	if objectiveCompletionSnapshot then for index=1,3 do if objectiveCompletionSnapshot[index]~=true and nextCompletion[index]==true then AudioBridge.Emit("Objective.Complete",{Key="Objective:"..tostring(index),ObjectiveIndex=index}) end end end
	objectiveCompletionSnapshot=nextCompletion
	if unlockDelay>0 then task.delay(unlockDelay*.45,function() layoutObjectives(true) end) else layoutObjectives(true) end
end
local function refreshObjective()
	local canvas=canvasSize(); local inside=player:GetAttribute("NTR_OwnedGarageInside")==true; local access=inside and named("AccessControls")
	local reference=access or named("Car") or named("Race") or named("Garage"); local objects=reference and {reference} or nil; local scale=ownerScale(objects,canvas); local phone=isLandscapePhone(canvas)
	local left,top,right,bottom=safeRect(canvas,scale,not phone); local width=math.min(math.floor(setting("ObjectiveCardWidthPixels",350)*scale+.5),math.max(math.floor(220*scale+.5),right-left)); local height=phone and math.floor(setting("ObjectivePhoneCardHeightPixels",48)+.5) or math.max(68,math.floor(setting("ObjectiveCardHeightPixels",98)*scale+.5)); local gap=phone and math.floor(setting("ObjectivePhoneCardGapPixels",4)+.5) or math.max(5,math.floor(setting("ObjectiveCardGapPixels",8)*scale+.5)); local safe=math.max(3,math.floor(setting("ObjectiveGlowSafePaddingPixels",6)*scale+.5)); local y=math.max(top,66)
	if phone then
		y=math.max(top,setting("ObjectivePhoneFallbackTopPixels",94))
		if reference and not access then
			local referencePosition=reference.AbsolutePosition-overlay.AbsolutePosition
			y=math.max(top,referencePosition.Y+reference.AbsoluteSize.Y+setting("ObjectivePhoneTopRowClearancePixels",14))
		end
	end
	if phone and not access then
		local boost=named("BoostButton") or named("Boost"); local count=math.max(1,#objectiveOrder())
		if boost then
			local position,size=boost.AbsolutePosition-overlay.AbsolutePosition,boost.AbsoluteSize
			local overlapsX=position.X+size.X>left and position.X<left+width
			if overlapsX then
				local available=position.Y-setting("ObjectivePhoneBoostGapPixels",4)-y-gap*(count-1)
				if available>0 then height=math.max(setting("ObjectivePhoneMinimumCardHeightPixels",46),math.min(height,math.floor(available/count))) end
			end
		end
	end
	if access then
		local localPosition=access.AbsolutePosition-overlay.AbsolutePosition
		left=math.clamp(localPosition.X,left,math.max(left,right-width))
		width=math.min(math.max(math.floor(200*scale+.5),access.AbsoluteSize.X),right-left)
		local count=math.max(1,#objectiveOrder()); local stackHeight=height*count+gap*(count-1)
		y=math.clamp(localPosition.Y+access.AbsoluteSize.Y+math.max(6,math.floor(8*scale+.5)),top,math.max(top,bottom-stackHeight))
	end
	objectiveLayout={Left=left,Top=y,Width=width,Height=height,Gap=gap,Scale=scale,Safe=safe,Phone=phone}
	layoutObjectives(false)
	local shortcutPrompt=activePage=="VehicleShortcut" or activePage=="RaceShortcut" or activePage=="GarageShortcut"
	objectiveLayer.Visible=stateReady and #objectiveOrder()>0 and not onboardingPresentationBlocked() and not majorMenuOpen() and (not activePage or shortcutPrompt)
end
local function nearestGarageDesk()
	local character=player.Character; local root=character and character:FindFirstChild("HumanoidRootPart"); if not root then return nil end
	local best,bestDistance
	for _,object in ipairs(workspace:GetDescendants()) do
		if object.Name=="DeskPromptAnchor" and object:IsA("BasePart") and object:FindFirstAncestor("ManagementDesk") then
			local distance=(object.Position-root.Position).Magnitude
			if not bestDistance or distance<bestDistance then best,bestDistance=object,distance end
		end
	end
	return best
end
local function updateGuideTrail()
	if onboardingPresentationBlocked() then guideTrail:Clear(); return end
	if state.Completed.FirstVehiclePurchased~=true then
		local world=workspace:FindFirstChild("NeoTokyoRacersWorld"); local intro=world and world:FindFirstChild("Dealership") and world.Dealership:FindFirstChild("Intro"); local desk=intro and intro:FindFirstChild("Desk") and intro.Desk:FindFirstChild("GarageDeskTrigger")
		guideTrail:SetTarget(desk)
	elseif player:GetAttribute("NTR_OwnedGarageInside")==true and state.Completed.GarageManagementEntered~=true and playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")~=true then
		guideTrail:SetTarget(nearestGarageDesk())
	else guideTrail:Clear() end
end
local function applyLocks()
	local unlocks={Car=state.SeenPages.VehicleShortcut==true,Race=state.SeenPages.RaceShortcut==true,Garage=state.SeenPages.GarageShortcut==true}
	for name,unlocked in pairs(unlocks) do
		for _,object in ipairs(playerGui:GetDescendants()) do if object.Name==name and object:IsA("GuiButton") then object.Active=unlocked; object.Selectable=unlocked; object.AutoButtonColor=unlocked end end
	end
end
local function activelyDriving()
	local world=workspace:FindFirstChild("NeoTokyoRacersWorld"); local runtime=world and world:FindFirstChild("Runtime"); local vehicles=runtime and runtime:FindFirstChild("PlayerVehicles")
	for _,vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do if vehicle:IsA("Model") and tonumber(vehicle:GetAttribute("OwnerUserId"))==player.UserId and tonumber(vehicle:GetAttribute("DriverUserId"))==player.UserId then local seat=vehicle:FindFirstChild("DriverSeat",true); local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if seat and seat:IsA("VehicleSeat") and humanoid and seat.Occupant==humanoid then return vehicle end end end
	return nil
end
local pcControlsAwaitClose=false
local firstDriveSpawnPending=false
local firstDriveSpawnDirect=false
local firstDriveRequestInFlight=false
local function tryBeginFirstDriveControls(allowSpawnSignal)
	if UserInputService.TouchEnabled or not stateReady or state.Stage<2 or state.SeenPages.PCDriving==true or firstDriveRequestInFlight then return false end
	local drivenVehicle=activelyDriving()
	local raceDriving=drivenVehicle and (drivenVehicle:GetAttribute("NTR_RaceParticipant")==true or drivenVehicle:GetAttribute("NTR_RaceRunId")~=nil)
	if raceDriving or (not drivenVehicle and not allowSpawnSignal) then return false end
	local event=script.Parent:FindFirstChild("OpenDrivingControlsFromOnboarding")
	if not (event and event:IsA("BindableEvent")) then
		firstDriveSpawnPending=false
		player:SetAttribute("NTR_FirstDrivePresentationPending",false)
		return false
	end
	player:SetAttribute("NTR_FirstDrivePresentationPending",true)
	firstDriveRequestInFlight=true
	pcControlsAwaitClose=true
	state.SeenPages.PCDriving=true
	event:Fire({FirstDrive=true})
	task.spawn(markSeen,"PCDriving")
	return true
end
local function pollPages()
	if firstDriveSpawnPending and tryBeginFirstDriveControls(firstDriveSpawnDirect) then firstDriveSpawnPending=false; firstDriveSpawnDirect=false; return end
	if onboardingPresentationBlocked() then return end
	if pcControlsAwaitClose then
		pcControlsAwaitClose=false
		firstDriveRequestInFlight=false
	end
	if activePage then return end
	if tryBeginFirstDriveControls() then return end
	for _,pageId in ipairs(pageOrder) do local signal=pageSignals[pageId]
		if state.SeenPages[pageId]~=true then local ok,result=pcall(signal); if ok and result then beginPage(pageId,result); return end end
	end
end
local freeRoamVehicleSpawned=script.Parent:WaitForChild("FreeRoamVehicleSpawned")
freeRoamVehicleSpawned.Event:Connect(function()
	if UserInputService.TouchEnabled or state.SeenPages.PCDriving==true then return end
	firstDriveSpawnPending=true
	firstDriveSpawnDirect=loadingActive() and tostring(loadingState:GetAttribute("Destination") or "")=="FreeRoamDrive"
	if tryBeginFirstDriveControls(firstDriveSpawnDirect) then firstDriveSpawnPending=false; firstDriveSpawnDirect=false end
end)
local function accept(newState)
	if type(newState)=="table" and newState.Success then state=newState; stateReady=true end
	if firstDriveSpawnPending and tryBeginFirstDriveControls(firstDriveSpawnDirect) then firstDriveSpawnPending=false; firstDriveSpawnDirect=false end
	applyLocks(); syncObjectives(); refreshObjective()
end
stateChanged.OnClientEvent:Connect(accept)
local presentation=script.Parent:FindFirstChild("FreeRoamHudPresentationMode")
if presentation and presentation:IsA("BindableEvent") then presentation.Event:Connect(function(payload) if type(payload)=="table" then presentationOwners[tostring(payload.Owner or "Unknown")]=payload.Active==true end end) end
local function refreshLoadingGate()
	gateGeneration+=1; local generation=gateGeneration
	if loadingActive() then gui.Enabled=false; hideOverlay(); return end
	task.spawn(function()
		RunService.RenderStepped:Wait(); RunService.RenderStepped:Wait()
		if generation~=gateGeneration or loadingActive() then return end
		gui.Enabled=true
		if onboardingPresentationBlocked() then hideOverlay(); objectiveLayer.Visible=false; return end
		if activePage then scheduleResolve() else refreshObjective(); pollPages() end
	end)
end
player:GetAttributeChangedSignal("NTR_StartScreenActive"):Connect(refreshLoadingGate)
player:GetAttributeChangedSignal("NTR_FirstDrivePresentationPending"):Connect(refreshLoadingGate)
player:GetAttributeChangedSignal("NTR_DrivingControlsOpen"):Connect(refreshLoadingGate)
loadingState:GetAttributeChangedSignal("Active"):Connect(refreshLoadingGate)
loadingChanged.Event:Connect(refreshLoadingGate)
task.spawn(function() local ok,result=pcall(function() return invoke:InvokeServer("GetState",{}) end); if ok then accept(result) end end)
local elapsed=0
RunService.RenderStepped:Connect(function(dt) elapsed+=dt; if elapsed<.2 then return end; elapsed=0; applyLocks(); refreshObjective(); updateGuideTrail(); pollPages() end)
refreshLoadingGate()
print("[NTR Onboarding] client active V1.13 | protected state imports | free-roam controls gate | two-line desktop objectives")
