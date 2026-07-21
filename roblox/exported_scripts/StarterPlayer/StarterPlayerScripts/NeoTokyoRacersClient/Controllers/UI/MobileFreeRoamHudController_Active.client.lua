-- NTR_MOBILE_FREEROAM_UI_PHASE1O_MAJOR_MENU_SUPPRESSION
-- NTR_OWNED_GARAGE_PHASE8_HUD_POLICY
-- NTR_OWNED_GARAGE_MANAGEMENT_HUD_SUPPRESSION_V1_6
-- NTR_RACING_UI_MOBILE_PHASE2_IN_RACE_HUD
-- NTR_MOBILE_FREEROAM_UI_PHASE1L_MODAL_SAFE_AREA_PC_CASH
-- NTR_MOBILE_FREEROAM_UI_PHASE1K_BOOST_PLATE_EXIT_ALIGNMENT
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
if not UserInputService.TouchEnabled then return end

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("MobileFreeRoamHud")
local desktop=kit.Config.UI:WaitForChild("DesktopFreeRoamHud")
local colours=desktop:WaitForChild("Colours")
local desktopLayout=desktop:WaitForChild("Layout")
local desktopAssets=desktop:WaitForChild("Assets")
local desktopDefaults=desktop:WaitForChild("Defaults")
local desktopEffects=desktop:WaitForChild("Effects")
local remotes=kit:WaitForChild("Shared"):WaitForChild("Remotes")
local garage=remotes:WaitForChild("Garage")
local garageInvoke=garage:WaitForChild("GarageInvoke")
local interiorInvoke=garage:FindFirstChild("GarageInteriorInvoke")
local teleportInvoke=remotes:WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportInvoke")
local loadingInvoke=script.Parent:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE1_DEALERSHIP_TELEPORT_MOBILE_V1
local categories=kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local drive=require(kit.Shared.Modules.Client.Controllers:WaitForChild("MobileDriveInputState"))
local uiFolder=script.Parent

local FONT=Enum.Font.Michroma
local function read(folder,name,fallback) local v=folder and folder:FindFirstChild(name); if v and v:IsA("ValueBase") then return v.Value end local a=folder and folder:GetAttribute(name); if a~=nil then return a end return fallback end
local function B(folder,name,fallback) local value=read(folder,name,fallback); return value==true end
local function C(name,fallback) local value=read(colours,name,nil); return typeof(value)=="Color3" and value or fallback end
local function E(name,fallback) return tonumber(read(desktopEffects,name,fallback)) or fallback end
local PANEL=C("Panel",Color3.fromRGB(15,19,24)); local DEEP=C("PanelDeep",Color3.fromRGB(9,12,16)); local SOFT=C("PanelSoft",Color3.fromRGB(24,29,36)); local PINK=C("Outline",Color3.fromRGB(244,46,151)); local PINK_SOFT=C("OutlineSoft",Color3.fromRGB(214,74,175)); local CYAN=C("Telemetry",Color3.fromRGB(43,225,218)); local BLUE=C("ElectricBlue",Color3.fromRGB(25,116,255)); local WHITE=C("Text",Color3.fromRGB(246,248,252)); local MUTED=C("Muted",Color3.fromRGB(163,171,184)); local DANGER=C("Danger",Color3.fromRGB(196,57,75))
local function asset(folder,name) local s=tostring(read(folder,name,"") or ""); if tonumber(s) then return "rbxassetid://"..s end return s end
local function new(class,props,parent) local x=Instance.new(class); for k,v in pairs(props or {}) do x[k]=v end x.Parent=parent; return x end
local function corner(parent,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 10)},parent) end
local function stroke(parent,color,width,transparency) return new("UIStroke",{Color=color,Thickness=width or 2,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent) end
local function label(parent,name,text,size,pos,textSize,color,align)
	return new("TextLabel",{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Size=size,Position=pos,Text=text,TextColor3=color or WHITE,TextSize=textSize or 12,Font=FONT,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=parent.ZIndex+2},parent)
end
local function panel(parent,name,size,pos,z) local p=new("Frame",{Name=name,BackgroundColor3=DEEP,BackgroundTransparency=.14,BorderSizePixel=0,Size=size,Position=pos,ZIndex=z or 4},parent); corner(p,10); stroke(p,PINK,2,.08); return p end
local function button(parent,name,text,size,pos,accent)
	local b=new("TextButton",{Name=name,Text=text,TextColor3=WHITE,TextSize=11,Font=FONT,AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=.08,BorderSizePixel=0,Size=size,Position=pos,ZIndex=parent.ZIndex+2},parent); corner(b,8); stroke(b,accent or PINK,1.7,.04); return b
end
local function surfaceGradient(parent,topColor,bottomColor,rotation) return new("UIGradient",{Name="SurfaceGradient",Color=ColorSequence.new(topColor,bottomColor),Transparency=NumberSequence.new(E("GradientTransparency",.12)),Rotation=rotation or 90},parent) end
local function buttonGradient(parent)
	local strength=math.clamp(E("ButtonGradientStrength",.10),0,.35); local overlay=new("Frame",{Name="GradientOverlay",Active=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1-strength,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=parent.ZIndex},parent); corner(overlay,6); new("UIGradient",{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(95,95,95)),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.20),NumberSequenceKeypoint.new(.52,.70),NumberSequenceKeypoint.new(1,.28)}),Rotation=E("ButtonGradientRotation",90)},overlay); return overlay
end
local function addFacetPattern(parent)
	local pattern=new("Frame",{Name="FacetPattern",BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Size=UDim2.fromScale(1,1),ZIndex=parent.ZIndex},parent); for i=1,3 do new("Frame",{Name="Facet"..i,BackgroundColor3=PINK_SOFT,BackgroundTransparency=math.clamp(E("PatternTransparency",.94)+i*.012,0,1),BorderSizePixel=0,Position=UDim2.new(-.15+i*.28,0,.12+i*.18,0),Size=UDim2.new(.52,0,0,2),Rotation=-18,ZIndex=parent.ZIndex},pattern) end; return pattern
end
local function carNeutralSurface(parent,name,size,pos,z)
	local item=new("Frame",{Name=name,BackgroundColor3=SOFT,BackgroundTransparency=E("DropdownTransparency",.06),BorderSizePixel=0,ClipsDescendants=true,Size=size,Position=pos,ZIndex=z or 30},parent); corner(item,7); surfaceGradient(item,SOFT,PANEL,90); return item
end
local function styleCarButton(item,accent,thickness,withGlow)
	local line=item:FindFirstChildOfClass("UIStroke"); if line then line.Color=accent or PINK; line.Thickness=thickness or 1.4; line.Transparency=.08 end; buttonGradient(item); if withGlow then local glow=stroke(item,accent or PINK,4,E("GlowTransparency",.82)); glow.Name="GlowStroke" end; return item
end
local function call(action,payload) local ok,result=pcall(function() return garageInvoke:InvokeServer(action,payload or {}) end); if ok and typeof(result)=="table" then return result end return {Success=false,Message=tostring(result)} end
local function fire(name,payload) local event=uiFolder:FindFirstChild(name); if event and event:IsA("BindableEvent") then event:Fire(payload); return true end return false end
local function loadingAction(action,payload) local ok,result=pcall(function() return loadingInvoke:Invoke(action,payload or {}) end); if ok then return result end; warn("[NTR Mobile HUD] Loading transition "..tostring(action).." failed: "..tostring(result)); return nil end

local old=playerGui:FindFirstChild("NTR_MobileFreeRoamHud_Phase1"); if old then old:Destroy() end
local gui=new("ScreenGui",{Name="NTR_MobileFreeRoamHud_Phase1",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=88,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui)
local root=new("Frame",{Name="Root",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=1},gui)
local legacyItemConnections=setmetatable({},{__mode="k"})
local legacyDescendantConnection=nil
local legacyHudWatched=nil
local legacyVisualNames={MobileDriveControls=true,DriveHUD=true,DriveMenu=true}
local function hideExactLegacyVisual(item)
	if not (item and item:IsA("GuiObject") and legacyVisualNames[item.Name]) then return end
	item.Visible=false
	if not legacyItemConnections[item] then legacyItemConnections[item]=item:GetPropertyChangedSignal("Visible"):Connect(function() if item.Parent and item.Visible then item.Visible=false end end) end
end
local function suppressExactLegacyHud()
	local legacy=playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD")
	if not (legacy and legacy:IsA("ScreenGui")) then return end
	for _,item in ipairs(legacy:GetDescendants()) do hideExactLegacyVisual(item) end
	if legacy~=legacyHudWatched then if legacyDescendantConnection then legacyDescendantConnection:Disconnect() end; legacyHudWatched=legacy; legacyDescendantConnection=legacy.DescendantAdded:Connect(function(item) task.defer(function() hideExactLegacyVisual(item) end) end) end
end
playerGui.ChildAdded:Connect(function(child) if child.Name=="HOVER_RACING_V2_DriveHUD" then task.defer(suppressExactLegacyHud) end end)
suppressExactLegacyHud()
local toast=label(root,"Toast","",UDim2.fromOffset(420,34),UDim2.fromScale(.5,.12),12,WHITE,Enum.TextXAlignment.Center); toast.AnchorPoint=Vector2.new(.5,0); toast.BackgroundColor3=DEEP; toast.BackgroundTransparency=.15; toast.Visible=false; corner(toast,8); stroke(toast,PINK,1.5,.1)
local function showToast(text,positive) toast.Text=tostring(text); toast.TextColor3=positive and CYAN or WHITE; toast.Visible=true; local stamp=os.clock(); toast:SetAttribute("Stamp",stamp); task.delay(2.2,function() if toast.Parent and toast:GetAttribute("Stamp")==stamp then toast.Visible=false end end) end

local mapFrame=new("Frame",{Name="Minimap",BackgroundColor3=DEEP,BackgroundTransparency=.28,BorderSizePixel=0,Size=UDim2.fromOffset(170,170),Position=UDim2.fromOffset(0,0),ClipsDescendants=true,ZIndex=5},root); corner(mapFrame,9)
local mapCanvas=new("Frame",{Name="MapCanvas",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(170,170),ZIndex=6},mapFrame)
local tileNames={"MapTileTopLeft","MapTileTopRight","MapTileBottomLeft","MapTileBottomRight"}; local tilePos={UDim2.fromScale(0,0),UDim2.fromScale(.5,0),UDim2.fromScale(0,.5),UDim2.fromScale(.5,.5)}
local anyTile=false
for i,name in ipairs(tileNames) do local image=asset(desktopAssets,name); if image~="" then anyTile=true end; new("ImageLabel",{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Image=image,ScaleType=Enum.ScaleType.Stretch,Position=tilePos[i],Size=UDim2.fromScale(.5,.5),ZIndex=6},mapCanvas) end
local mapMissing=label(mapFrame,"Missing",anyTile and "" or "ADD MAP TILE IDS",UDim2.fromScale(1,.2),UDim2.fromScale(0,.4),9,MUTED,Enum.TextXAlignment.Center)
local playerMarker=new("ImageLabel",{Name="PlayerMarker",AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"MapPlayerIcon"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(18,18),ZIndex=9},mapFrame)
if playerMarker.Image=="" then playerMarker:Destroy(); playerMarker=label(mapFrame,"PlayerMarker","▲",UDim2.fromOffset(24,24),UDim2.fromScale(.5,.5),18,CYAN,Enum.TextXAlignment.Center); playerMarker.AnchorPoint=Vector2.new(.5,.5) end
local north=new("ImageLabel",{Name="North",AnchorPoint=Vector2.new(1,0),BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"MapNorthArrow"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(22,22),ZIndex=9},mapFrame)
if north.Image=="" then north:Destroy(); north=label(mapFrame,"North","N",UDim2.fromOffset(22,22),UDim2.new(1,-28,0,6),10,PINK,Enum.TextXAlignment.Center) end
local function edgeFade(name,position,size,rotation)
	local edge=new("Frame",{Name=name,BackgroundColor3=DEEP,BackgroundTransparency=0,BorderSizePixel=0,Position=position,Size=size,ZIndex=8},mapFrame)
	new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.18),NumberSequenceKeypoint.new(1,1)}),Rotation=rotation},edge)
end
edgeFade("EdgeLeft",UDim2.fromScale(0,0),UDim2.new(.2,0,1,0),0)
edgeFade("EdgeRight",UDim2.new(.8,0,0,0),UDim2.new(.2,0,1,0),180)
edgeFade("EdgeTop",UDim2.fromScale(0,0),UDim2.new(1,0,.2,0),90)
edgeFade("EdgeBottom",UDim2.new(0,0,.8,0),UDim2.new(1,0,.2,0),-90)

local cash=panel(root,"Cash",UDim2.fromOffset(170,34),UDim2.fromOffset(0,0),5); cash.BackgroundColor3=Color3.fromRGB(8,42,84); cash.ClipsDescendants=true; local cashText=label(cash,"Value","$0",UDim2.new(1,-52,1,0),UDim2.fromOffset(6,0),14,WHITE); cashText.TextWrapped=false; cashText.TextScaled=true; cashText.TextTruncate=Enum.TextTruncate.None; new("UITextSizeConstraint",{MinTextSize=5,MaxTextSize=14},cashText); local cashPlus=button(cash,"Plus","+",UDim2.fromOffset(28,26),UDim2.new(1,-32,.5,-13),BLUE); cashPlus.TextSize=18

local nav=new("Frame",{Name="Navigation",BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},root)
local navButtons={}
local function navButton(name,iconName,fallback)
	local b=button(nav,name,"",UDim2.fromOffset(42,42),UDim2.fromOffset(0,0),PINK); local image=asset(desktopAssets,iconName)
	if image~="" then new("ImageLabel",{Name="Icon",BackgroundTransparency=1,BorderSizePixel=0,Image=image,ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Position=UDim2.fromScale(.17,.17),Size=UDim2.fromScale(.66,.66),ZIndex=b.ZIndex+1},b) else label(b,"Fallback",fallback,UDim2.fromScale(1,1),UDim2.fromScale(0,0),8,WHITE,Enum.TextXAlignment.Center) end
	navButtons[name]=b; return b
end
local carButton=navButton("Car","CarIcon","CAR"); local garageButton=navButton("Garage","GarageIcon","HOME"); local raceButton=navButton("Race","RaceIcon","RACE"); local shopButton=navButton("Dealership","DealershipIcon","SHOP"); local settingsButton=navButton("Settings","SettingsIcon","SET")

local telemetry=new("Frame",{Name="Telemetry",AnchorPoint=Vector2.new(.5,1),BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(420,190),ZIndex=4,Visible=false},root)
local telemetryScale=new("UIScale",{Scale=.72},telemetry)
local boostIconBox=new("Frame",{Name="BoostIconContainer",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(303,145),Size=UDim2.fromOffset(34,34),ZIndex=5},telemetry)
local boostIcon=new("ImageLabel",{Name="BoostIcon",BackgroundTransparency=1,BorderSizePixel=0,Image=asset(desktopAssets,"BoostIcon"),ImageColor3=WHITE,ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromScale(1,1),ZIndex=6},boostIconBox)
local boostFallback=label(boostIconBox,"Fallback","⚡",UDim2.fromScale(1,1),UDim2.fromScale(0,0),20,CYAN,Enum.TextXAlignment.Center); boostFallback.Visible=boostIcon.Image==""
local boostTrack=new("Frame",{Name="BoostTrack",BackgroundColor3=SOFT,BorderSizePixel=0,Position=UDim2.fromOffset(311,42),Size=UDim2.fromOffset(18,96),ClipsDescendants=true,ZIndex=5},telemetry); corner(boostTrack,7)
local boostFill=new("Frame",{Name="BoostFill",AnchorPoint=Vector2.new(0,1),BackgroundColor3=CYAN,BorderSizePixel=0,Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,1),ZIndex=6},boostTrack); corner(boostFill,6); new("UIGradient",{Color=ColorSequence.new(BLUE,CYAN),Rotation=-90},boostFill)
local speedText=label(telemetry,"Speed","0",UDim2.fromOffset(190,78),UDim2.fromOffset(105,66),64,WHITE,Enum.TextXAlignment.Center); speedText.TextStrokeColor3=CYAN; speedText.TextStrokeTransparency=.8
local unitText=label(telemetry,"Unit","MPH",UDim2.fromOffset(190,28),UDim2.fromOffset(105,137),15,WHITE,Enum.TextXAlignment.Center)
local gauge={}; for i=1,16 do local alpha=(i-1)/15; local normalized=(alpha-.5)*2; local x=122+alpha*156; local y=18+normalized*normalized*18; local g=new("Frame",{Name="GaugeSegment"..i,BackgroundColor3=Color3.fromRGB(81,88,99),BackgroundTransparency=.42,BorderSizePixel=0,Position=UDim2.fromOffset(x-4,y),Size=UDim2.fromOffset(8,23),Rotation=normalized*10,ZIndex=5},telemetry); corner(g,3); table.insert(gauge,g) end
local exitButton=button(telemetry,"ExitVehicle","EXIT",UDim2.fromOffset(76,30),UDim2.fromOffset(24,111),PINK); exitButton.Visible=false; exitButton.TextSize=9; exitButton.BackgroundTransparency=.48

local carDismiss=new("TextButton",{Name="CarMenuOutsideTap",Text="",AutoButtonColor=false,Active=true,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=18},root)
local carPanel=panel(root,"CarPanel",UDim2.fromOffset(335,620),UDim2.fromOffset(3,84),21); carPanel.Visible=false; local carPanelStroke=carPanel:FindFirstChildOfClass("UIStroke"); if carPanelStroke then carPanelStroke:Destroy() end; surfaceGradient(carPanel,SOFT,DEEP,110); addFacetPattern(carPanel)
local function carDropdown(name)
	local b=button(carPanel,name,"",UDim2.fromOffset(158,28),UDim2.fromOffset(0,0),PINK)
	styleCarButton(b,PINK_SOFT,1.4,true)
	label(b,"Value","",UDim2.new(1,-30,1,0),UDim2.fromOffset(7,0),8,WHITE)
	label(b,"Chevron","v",UDim2.fromOffset(18,18),UDim2.new(1,-21,.5,-9),8,CYAN,Enum.TextXAlignment.Center)
	return b
end
local carCategory=carDropdown("Category")
local carSort=carDropdown("Sort")
local carScroll=new("ScrollingFrame",{Name="VehicleGrid",BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=4,ScrollBarImageColor3=CYAN,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=23},carPanel)
local carContent=new("Frame",{Name="Content",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(0,0),ZIndex=23},carScroll)
local carGrid=new("UIGridLayout",{CellPadding=UDim2.fromOffset(8,8),CellSize=UDim2.fromOffset(170,150),FillDirection=Enum.FillDirection.Horizontal,FillDirectionMaxCells=2,HorizontalAlignment=Enum.HorizontalAlignment.Left,SortOrder=Enum.SortOrder.LayoutOrder},carContent)
local carDespawn=button(carPanel,"Despawn","DESPAWN",UDim2.new(1,-10,0,20),UDim2.new(0,5,1,-22),DANGER); carDespawn.BackgroundColor3=DANGER; carDespawn.TextSize=7; local carDespawnStroke=carDespawn:FindFirstChildOfClass("UIStroke"); if carDespawnStroke then carDespawnStroke:Destroy() end; local carDespawnGradient=buttonGradient(carDespawn); carDespawnGradient.BackgroundTransparency=math.clamp(tonumber(read(config,"CarMenuDespawnGradientTransparency",.72)),0,1)
local carChoice=nil
local carChoiceAnchor=nil
local carMenuOpen=false
local carBusy=false
player:SetAttribute("NTRMobileFreeRoamCarMenuOpen",false)

local shade=new("TextButton",{Name="Shade",Text="",AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.35,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false,ZIndex=20},root)
local modal=panel(root,"Modal",UDim2.fromOffset(720,420),UDim2.fromScale(.5,.5),22); modal.AnchorPoint=Vector2.new(.5,.5); modal.ClipsDescendants=true; modal.Visible=false
surfaceGradient(modal,DEEP,PANEL,90); addFacetPattern(modal)
local modalScale=new("UIScale",{Name="SafeAreaScale",Scale=1},modal)
local modalReference=Vector2.new(720,420)
local modalTitle=label(modal,"Title","",UDim2.new(1,-32,0,44),UDim2.fromOffset(16,8),18,WHITE,Enum.TextXAlignment.Center)
local modalBody=new("Frame",{Name="Body",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(14,56),Size=UDim2.new(1,-28,1,-70),ZIndex=23},modal)
local function clear(parent) for _,x in ipairs(parent:GetChildren()) do if not x:IsA("UIListLayout") and not x:IsA("UIPadding") then x:Destroy() end end end
local function layoutModal(vp)
	local safeTop=math.max(0,tonumber(read(config,"ModalSafeTop",72)) or 72); local safeBottom=math.max(0,tonumber(read(config,"ModalSafeBottom",10)) or 10); local safeSide=math.max(0,tonumber(read(config,"ModalSafeSide",10)) or 10)
	local availableW=math.max(1,vp.X-safeSide*2); local availableH=math.max(1,vp.Y-safeTop-safeBottom); local minimum=math.max(.1,tonumber(read(config,"ModalScaleMin",.25)) or .25); local maximum=math.max(minimum,tonumber(read(config,"ModalScaleMax",1)) or 1)
	local fitted=math.min(availableW/math.max(1,modalReference.X),availableH/math.max(1,modalReference.Y)); modalScale.Scale=math.clamp(fitted,minimum,maximum)
	modal.Position=UDim2.fromOffset(safeSide+availableW*.5,safeTop+availableH*.5)
end
local function setModalReference(width,height)
	modalReference=Vector2.new(width,height); modal.Size=UDim2.fromOffset(width,height); local camera=workspace.CurrentCamera; if camera then layoutModal(camera.ViewportSize) end
end
player:SetAttribute("NTRMobileMajorMenuOpen",false)
local function closeModal() shade.Visible=false; modal.Visible=false; player:SetAttribute("NTRMobileMajorMenuOpen",false); clear(modalBody) end
shade.Activated:Connect(closeModal)
local function openModal(title,width,height) clear(modalBody); setModalReference(width,height); modalTitle.Text=title; shade.Visible=true; modal.Visible=true; player:SetAttribute("NTRMobileMajorMenuOpen",true) end

local function segmented(parent,y,titleText,options,selected,onPick,disabled)
	label(parent,titleText.."Label",titleText,UDim2.new(1,-20,0,20),UDim2.fromOffset(10,y),10,WHITE)
	local gap=6; local logicalWidth=math.max(1,modal.Size.X.Offset-28); local width=math.floor((logicalWidth-20-gap*(#options-1))/#options)
	for i,option in ipairs(options) do local active=option==selected; local b=button(parent,titleText..option,option,UDim2.fromOffset(width,34),UDim2.fromOffset(10+(i-1)*(width+gap),y+22),active and CYAN or PINK); b.BackgroundColor3=active and Color3.fromRGB(8,42,84) or PANEL; buttonGradient(b); if disabled and disabled[option] then b.TextColor3=MUTED; b.Active=false else b.Activated:Connect(function() onPick(option) end) end end
end

local function showSettings()
	openModal("SETTINGS",tonumber(read(config,"SettingsModalWidth",720)) or 720,tonumber(read(config,"SettingsModalHeight",420)) or 420)
	local selected=tostring(player:GetAttribute("NTRMobileControlMode") or read(config,"DefaultControlMode","Arrows"))
	segmented(modalBody,0,"MOBILE CONTROLS",{"Arrows","Thumbstick","Tilt"},selected,function(option) player:SetAttribute("NTRMobileControlMode",option); showSettings() end,{Tilt=not UserInputService.GyroscopeEnabled})
	label(modalBody,"TopHint",UserInputService.GyroscopeEnabled and "Tilt includes DRIFT and RECENTER controls." or "Tilt unavailable: this device has no gyroscope.",UDim2.new(1,-20,0,22),UDim2.fromOffset(10,59),9,MUTED)
	segmented(modalBody,88,"GRAPHICS",{"LOW","MEDIUM","HIGH"},"HIGH",function() end)
	segmented(modalBody,154,"UI SCALE",{"85%","100%","115%"},"100%",function() end)
	segmented(modalBody,220,"SPEED UNIT",{"MPH","KPH"},"MPH",function() end)
	local done=button(modalBody,"Done","DONE",UDim2.fromOffset(150,38),UDim2.new(1,-160,1,-42),CYAN); buttonGradient(done); done.Activated:Connect(closeModal)
end

local function showCash()
	openModal("GET CASH",tonumber(read(config,"CashModalWidth",840)) or 840,tonumber(read(config,"CashModalHeight",650)) or 650)
	local balance=button(modalBody,"BalanceChip","BALANCE  "..tostring(cashText.Text),UDim2.fromOffset(310,42),UDim2.fromOffset(251,10),BLUE); balance.BackgroundColor3=Color3.fromRGB(8,42,84); balance.TextScaled=true; new("UITextSizeConstraint",{MinTextSize=7,MaxTextSize=11},balance); buttonGradient(balance)
	local packs={{"$10,000","49 ROBUX"},{"$30,000","99 ROBUX"},{"$75,000","199 ROBUX"},{"$200,000","399 ROBUX"}}
	local secure
	for index,pack in ipairs(packs) do
		local col=(index-1)%2; local row=math.floor((index-1)/2); local card=panel(modalBody,"Pack"..index,UDim2.fromOffset(375,215),UDim2.fromOffset(21+col*395,69+row*230),46); card.ClipsDescendants=true; surfaceGradient(card,DEEP,PANEL,90); addFacetPattern(card)
		if index==4 then local best=label(card,"Best","BEST VALUE",UDim2.fromOffset(120,28),UDim2.new(1,-130,0,10),9,WHITE,Enum.TextXAlignment.Center); best.BackgroundColor3=CYAN; best.BackgroundTransparency=.12; corner(best,5) end
		label(card,"Coins",index==1 and "C" or "C  C  C",UDim2.new(1,-30,0,70),UDim2.fromOffset(15,35),27,BLUE,Enum.TextXAlignment.Center)
		label(card,"Amount",pack[1],UDim2.new(1,-30,0,42),UDim2.fromOffset(15,105),24,WHITE,Enum.TextXAlignment.Center)
		local buy=button(card,"Buy",pack[2],UDim2.new(1,-60,0,42),UDim2.fromOffset(30,160),index==4 and BLUE or PINK); buy.BackgroundColor3=index==4 and Color3.fromRGB(8,42,84) or PANEL; buttonGradient(buy); buy.Activated:Connect(function() if secure then secure.Text="CASH PRODUCTS ARE NOT ENABLED YET"; secure.TextColor3=PINK end end)
	end
	local closeCash=button(modalBody,"Close","CLOSE",UDim2.fromOffset(150,42),UDim2.fromOffset(21,539),PINK); buttonGradient(closeCash); closeCash.Activated:Connect(closeModal)
	secure=label(modalBody,"Secure","CASH PRODUCTS ARE NOT ENABLED YET",UDim2.fromOffset(500,42),UDim2.new(.5,0,0,539),10,MUTED,Enum.TextXAlignment.Center); secure.AnchorPoint=Vector2.new(.5,0)
end
cashPlus.Activated:Connect(showCash)

local teleportBusy=false
local function showTeleport()
	openModal("TELEPORT TO DEALERSHIP?",tonumber(read(config,"ConfirmModalWidth",650)) or 650,tonumber(read(config,"ConfirmModalHeight",270)) or 270)
	label(modalBody,"Message","Your current vehicle will be despawned.",UDim2.new(1,-20,0,60),UDim2.fromOffset(10,46),12,WHITE,Enum.TextXAlignment.Center)
	local no=button(modalBody,"No","NO",UDim2.fromOffset(270,54),UDim2.fromOffset(16,126),PINK); local yes=button(modalBody,"Yes","YES",UDim2.fromOffset(270,54),UDim2.fromOffset(336,126),CYAN); buttonGradient(no); buttonGradient(yes)
	no.Activated:Connect(closeModal)
	yes.Activated:Connect(function()
		if teleportBusy then return end
		teleportBusy=true
		closeModal()
		local generation=loadingAction("Begin",{Destination="DealershipExterior",Status="TRAVELLING TO DEALERSHIP"})
		local ok,result=pcall(function() return teleportInvoke:InvokeServer("TeleportToDealership") end)
		if ok and typeof(result)=="table" and result.Success then
			fire("FreeRoamVehicleExited")
			loadingAction("Complete",{Generation=generation,Status="READY"})
			showToast(result.Message or "TELEPORTED",true)
		else
			local message=typeof(result)=="table" and (result.Message or result.Error) or "TELEPORT FAILED"
			loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=message})
			showToast(message,false)
		end
		teleportBusy=false
	end)
end


local profileCache=nil
local lastProfile=0
local function profile(force) if profileCache and not force and os.clock()-lastProfile<2 then return profileCache end; local r=call("GetInitial",{}); profileCache=r.Profile or r; lastProfile=os.clock(); return profileCache or {} end
local function cockpitModel(id) local target=string.lower(tostring(id or "")); if target=="" then return nil end; for _,x in ipairs(categories:GetDescendants()) do if x:IsA("Model") then local xid=string.lower(tostring(x:GetAttribute("CockpitId") or x:GetAttribute("TemplateId") or x.Name)); if xid==target or string.gsub(xid,"^cockpit_","")==target or string.find(xid,target,1,true) then return x end end end end
local function vehicleCategory(vehicle,cockpitId) local explicit=tostring(vehicle and (vehicle.CategoryId or vehicle.Category) or ""); if explicit~="" then return string.upper(explicit) end; return string.upper(string.match(tostring(cockpitId or ""),"^([^_]+)") or "OTHER") end
local function tierColor(tier) return ({E=Color3.fromRGB(132,142,145),D=Color3.fromRGB(105,190,129),C=Color3.fromRGB(74,204,211),B=Color3.fromRGB(82,137,235),A=Color3.fromRGB(244,188,65),S=Color3.fromRGB(236,92,168)})[string.upper(tostring(tier or ""))] or PINK end
local function vehicleRows()
	local p=profile(false); local rows={}
	for vehicleId,v in pairs(p.Vehicles or {}) do local cockpitId=tostring(v.CockpitId or ""); if cockpitId=="" and v.CockpitInstanceId and p.OwnedCockpitInstances then local inst=p.OwnedCockpitInstances[v.CockpitInstanceId]; cockpitId=tostring(inst and inst.TemplateId or "") end; local model=cockpitModel(cockpitId); local summary=p.VehicleSummaries and p.VehicleSummaries[vehicleId]; local overall=summary and summary.Overall or {}; local image=tostring(model and (model:GetAttribute("MenuImage") or model:GetAttribute("CockpitImage")) or ""); if tonumber(image) then image="rbxassetid://"..image end; table.insert(rows,{VehicleId=tostring(vehicleId),CockpitId=cockpitId,Category=vehicleCategory(v,cockpitId),Name=string.upper(string.gsub(tostring(model and model:GetAttribute("DisplayName") or cockpitId or "VEHICLE"),"_"," ")),Image=image,Tier=tostring(overall.Tier or "E"),Rating=tonumber(overall.PerformanceIndex) or 0,Price=tonumber(model and model:GetAttribute("Price")) or 0,Selected=tostring(p.CurrentVehicleId or "")==tostring(vehicleId)}) end
	return rows
end
local selectedCategory="ALL"
local selectedSort="RATING"
local renderCars
local function closeCarChoice() if carChoice then carChoice:Destroy(); carChoice=nil end; carChoiceAnchor=nil end
local function setCarMenuOpen(open)
	carMenuOpen=open==true; closeCarChoice(); carDismiss.Visible=carMenuOpen; carPanel.Visible=carMenuOpen; player:SetAttribute("NTRMobileFreeRoamCarMenuOpen",carMenuOpen)
	if carMenuOpen then closeModal(); renderCars() end
end
local function showCarChoices(anchor,options,onPick)
	if carChoice and carChoiceAnchor==anchor then closeCarChoice(); return end; closeCarChoice(); carChoiceAnchor=anchor; local height=#options*31+8; carChoice=carNeutralSurface(carPanel,"ChoiceList",UDim2.fromOffset(anchor.AbsoluteSize.X,height),UDim2.fromOffset(anchor.Position.X.Offset,anchor.Position.Y.Offset+anchor.AbsoluteSize.Y+4),32)
	for i,option in ipairs(options) do local item=new("TextButton",{Name="Choice"..i,AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=.12,BorderSizePixel=0,Size=UDim2.new(1,-8,0,27),Position=UDim2.fromOffset(4,4+(i-1)*31),Text=option,TextColor3=WHITE,TextSize=9,Font=FONT,ZIndex=34},carChoice); corner(item,5); buttonGradient(item); item.Activated:Connect(function() closeCarChoice(); onPick(option) end) end
end
local function makeCarCard(row,order)
	local card=button(carContent,"Vehicle"..order,"",UDim2.fromOffset(92,80),UDim2.fromOffset(0,0),row.Selected and CYAN or PINK); card.LayoutOrder=order; card.BackgroundColor3=row.Selected and Color3.fromRGB(8,42,84) or PANEL; styleCarButton(card,row.Selected and CYAN or PINK,row.Selected and 1.3 or .8,true)
	local imageY=math.clamp(tonumber(read(config,"CarMenuVehicleImageYOffset",.13)),0,.3); if row.Image~="" then new("ImageLabel",{Name="Image",BackgroundTransparency=1,BorderSizePixel=0,Image=row.Image,ScaleType=Enum.ScaleType.Fit,Position=UDim2.new(.07,0,imageY,0),Size=UDim2.new(.86,0,.59,0),ZIndex=card.ZIndex+1},card) else label(card,"Fallback","HOVERCAR",UDim2.new(1,-6,.57,0),UDim2.new(0,3,imageY+.02,0),5,MUTED,Enum.TextXAlignment.Center) end
	local badge=label(card,"Badge",row.Tier.."  "..math.floor(row.Rating),UDim2.new(.46,0,0,12),UDim2.new(.52,0,0,3),5,WHITE,Enum.TextXAlignment.Center); badge.BackgroundColor3=tierColor(row.Tier); badge.BackgroundTransparency=.04; corner(badge,3)
	local name=label(card,"Name",row.Name,UDim2.new(1,-6,.21,0),UDim2.new(0,3,.75,0),5,WHITE,Enum.TextXAlignment.Center); name.TextWrapped=false; name.TextScaled=true; name.TextTruncate=Enum.TextTruncate.None; new("UITextSizeConstraint",{MinTextSize=4,MaxTextSize=6},name)
	card.Activated:Connect(function() if carBusy then return end; carBusy=true; showToast("SPAWNING VEHICLE...",true); local r=call("SpawnOwnedVehicleFromFreeRoam",{VehicleId=row.VehicleId,CockpitId=row.CockpitId}); if r.Success then profileCache=r.Profile or profileCache; lastProfile=0; fire("FreeRoamVehicleSpawned"); setCarMenuOpen(false); showToast("VEHICLE SPAWNED",true) else showToast(r.Message or r.Error or "SPAWN FAILED",false) end; carBusy=false end)
end
renderCars=function()
	for _,item in ipairs(carContent:GetChildren()) do if item~=carGrid then item:Destroy() end end
	local rows=vehicleRows(); local categoriesSet={ALL=true}; for _,row in ipairs(rows) do categoriesSet[row.Category]=true end
	local filtered={}; for _,row in ipairs(rows) do if selectedCategory=="ALL" or row.Category==selectedCategory then table.insert(filtered,row) end end
	table.sort(filtered,function(a,b) if selectedSort=="PRICE" and a.Price~=b.Price then return a.Price<b.Price elseif selectedSort=="A-Z" and a.Name~=b.Name then return a.Name<b.Name elseif selectedSort=="RATING" and a.Rating~=b.Rating then return a.Rating>b.Rating end return a.Name<b.Name end)
	local buy=button(carContent,"BuyMore","",UDim2.fromOffset(92,80),UDim2.fromOffset(0,0),PINK); buy.LayoutOrder=1; styleCarButton(buy,PINK,.8,true); label(buy,"Plus","+",UDim2.new(1,0,.54,0),UDim2.fromScale(0,.08),14,CYAN,Enum.TextXAlignment.Center); local buyName=label(buy,"Name","BUY MORE",UDim2.new(1,-6,.21,0),UDim2.new(0,3,.75,0),5,WHITE,Enum.TextXAlignment.Center); buyName.TextScaled=true; new("UITextSizeConstraint",{MinTextSize=4,MaxTextSize=6},buyName); buy.Activated:Connect(function() setCarMenuOpen(false); showTeleport() end)
	for i,row in ipairs(filtered) do makeCarCard(row,i+1) end
	local categoryOptions={}; for name in pairs(categoriesSet) do table.insert(categoryOptions,name) end; table.sort(categoryOptions,function(a,b) if a==b then return false elseif a=="ALL" then return true elseif b=="ALL" then return false end return a<b end); carCategory:SetAttribute("Options",table.concat(categoryOptions,"|")); local categoryValue=carCategory:FindFirstChild("Value"); local sortValue=carSort:FindFirstChild("Value"); if categoryValue then categoryValue.Text=selectedCategory end; if sortValue then sortValue.Text=selectedSort end
	task.defer(function() if carGrid.Parent then local topSafe=tonumber(read(config,"CarMenuCardTopSafePadding",3)); local bottomSafe=tonumber(read(config,"CarMenuCardBottomSafePadding",3)); local h=carGrid.AbsoluteContentSize.Y; carContent.Size=UDim2.new(1,0,0,h); carScroll.CanvasSize=UDim2.fromOffset(0,topSafe+h+bottomSafe) end end)
end

carDismiss.Activated:Connect(function() setCarMenuOpen(false) end)
carCategory.Activated:Connect(function() showCarChoices(carCategory,string.split(tostring(carCategory:GetAttribute("Options") or "ALL"),"|"),function(option) selectedCategory=option; renderCars() end) end)
carSort.Activated:Connect(function() showCarChoices(carSort,{"RATING","PRICE","A-Z"},function(option) selectedSort=option; renderCars() end) end)
carDespawn.Activated:Connect(function() if carBusy then return end; carBusy=true; fire("FreeRoamVehicleExited"); local r=call("DespawnVehicle",{}); setCarMenuOpen(false); showToast(r.Success==false and (r.Message or "DESPAWN FAILED") or "VEHICLE DESPAWNED",r.Success~=false); carBusy=false end)
carButton.Activated:Connect(function() setCarMenuOpen(true) end)
settingsButton.Activated:Connect(showSettings)
shopButton.Activated:Connect(showTeleport)
raceButton.Activated:Connect(function() if not fire("OpenRaceBrowser") then showToast("RACE BROWSER NOT READY",false) end end)
-- NTR_OWNED_GARAGE_PHASE6_HOME_SWITCH_V1
garageButton.Activated:Connect(function() if not fire("OpenOwnedGarageBrowser") then showToast("MY GARAGES NOT READY",false) end end)
exitButton.Activated:Connect(function() fire("FreeRoamVehicleExited"); local r=call("ExitVehicle",{}); showToast(r.Success==false and (r.Message or "EXIT FAILED") or "VEHICLE PARKED",r.Success~=false) end)

local presentationOwners={}
local presentation=uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
if presentation and presentation:IsA("BindableEvent") then presentation.Event:Connect(function(message)
	if typeof(message)=="table" then
		local owner=tostring(message.Owner or "Racing")
		presentationOwners[owner]=message.Active==true and {KeepTelemetry=message.KeepTelemetry==true} or nil
	else
		presentationOwners.Racing=tostring(message)=="Racing" and {KeepTelemetry=true} or nil
	end
	if next(presentationOwners)~=nil then if carMenuOpen then setCarMenuOpen(false) end closeModal() end
end) end
local function majorMenu() return player:GetAttribute("NTR_GarageSessionActive")==true or playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true end
local function subject() local c=player.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); local seat=h and h.SeatPart; return seat or (c and c:FindFirstChild("HumanoidRootPart")) end
local displayedPos=nil; local displayedHeading=0; local displayedBoost=1; local lastSize=Vector2.zero; local lastInside=nil
local function bindCash() local stats=player:FindFirstChild("leaderstats"); local value=stats and stats:FindFirstChild("Cash"); if not value then return false end; local function update() cashText.Text="$"..tostring(math.floor(tonumber(value.Value) or 0)) end; update(); value:GetPropertyChangedSignal("Value"):Connect(update); return true end
if not bindCash() then task.spawn(function() local stats=player:WaitForChild("leaderstats",15); if stats then stats:WaitForChild("Cash",15) end; bindCash() end) end
local function layout()
	local camera=workspace.CurrentCamera; local vp=camera and camera.ViewportSize or Vector2.new(1280,720); local inside=player:GetAttribute("NTR_OwnedGarageInside")==true; if vp==lastSize and inside==lastInside then return end; lastSize=vp; lastInside=inside
	local tiny=vp.Y<500; local margin=tiny and 10 or tonumber(read(config,"EdgeMargin",14)); local mapSize=math.floor(math.clamp(vp.Y*.27,tiny and 128 or 145,tiny and 160 or tonumber(read(config,"MinimapSize",180))))
	local navSize=tiny and 34 or tonumber(read(config,"NavButtonSize",42)); local navGap=tiny and 4 or tonumber(read(config,"NavGap",6)); local carWidth=navSize*2+navGap; local navWidth=carWidth+navSize*4+navGap*4; local mapX=vp.X-margin-mapSize; local clusterGap=tiny and 4 or tonumber(read(config,"TopClusterGap",6)); nav.Position=UDim2.fromOffset(mapX-clusterGap-navWidth,margin); nav.Size=UDim2.fromOffset(navWidth,navSize)
	local x=0; carButton.Position=UDim2.fromOffset(x,0); carButton.Size=UDim2.fromOffset(carWidth,navSize); x+=carWidth+navGap
	for _,name in ipairs({"Garage","Race","Dealership","Settings"}) do local b=navButtons[name]; b.Position=UDim2.fromOffset(x,0); b.Size=UDim2.fromOffset(navSize,navSize); x+=navSize+navGap end
	local cashHeight=tiny and 30 or tonumber(read(config,"CashHeight",34))
	if inside then
		nav.Position=UDim2.fromOffset(vp.X-margin-navSize,margin); nav.Size=UDim2.fromOffset(navSize,navSize); settingsButton.Position=UDim2.fromOffset(0,0)
		cash.Position=UDim2.fromOffset(margin,vp.Y-margin-cashHeight); cash.Size=UDim2.fromOffset(mapSize,cashHeight)
	else
		mapFrame.Position=UDim2.fromOffset(mapX,margin); mapFrame.Size=UDim2.fromOffset(mapSize,mapSize)
		cash.Position=UDim2.fromOffset(mapX,margin+mapSize+clusterGap); cash.Size=UDim2.fromOffset(mapSize,cashHeight)
	end
	local telemetryScaleValue=tiny and .62 or .72; local telemetryBottom=tonumber(read(config,"TelemetryBottomMargin",2)); telemetryScale.Scale=telemetryScaleValue; telemetry.Position=UDim2.fromOffset(vp.X*.5,vp.Y-telemetryBottom); local steeringBottomMargin=tiny and 10 or 16; local exitHeight=30; local exitY=math.floor(190+(telemetryBottom-steeringBottomMargin)/telemetryScaleValue-exitHeight+.5); exitButton.Position=UDim2.fromOffset(24,exitY)
	local carTop=tiny and 68 or tonumber(read(config,"CarMenuTop",82)); local carBottom=math.max(0,tonumber(read(config,"CarMenuBottomMargin",2))); local carH=math.max(260,vp.Y-carTop-carBottom); local panelPad=math.max(3,tonumber(read(config,"CarMenuPanelPadding",5))); local cardGap=math.max(2,tonumber(read(config,"CarMenuCardGap",5))); local topSafe=math.max(0,tonumber(read(config,"CarMenuCardTopSafePadding",3))); local bottomSafe=math.max(0,tonumber(read(config,"CarMenuCardBottomSafePadding",3))); local strokeSafe=math.max(0,tonumber(read(config,"CarMenuCardStrokeSafePadding",5))); local visibleRows=math.max(1,math.floor(tonumber(read(config,"CarMenuVisibleRows",3))+.5)); local aspect=math.max(.4,tonumber(read(config,"CarMenuCardAspect",.88))); local targetCardW=math.max(64,tonumber(read(config,"CarMenuTargetCardWidth",92))); local despawnH=math.max(18,tonumber(read(config,"CarMenuDespawnHeight",20))); local footerGap=math.max(2,tonumber(read(config,"CarMenuFooterGap",3))); local footerBottom=math.max(2,math.floor(panelPad*.5)); local scrollY=math.max(30,tonumber(read(config,"CarMenuHeaderHeight",36))); local despawnY=carH-footerBottom-despawnH; local scrollBottom=despawnY-footerGap; local scrollH=math.max(60,scrollBottom-scrollY)
	local heightFit=math.max(24,math.floor((scrollH-topSafe-bottomSafe-cardGap*(visibleRows-1))/visibleRows)); local maxPanelW=math.max(180,math.floor(vp.X*math.clamp(tonumber(read(config,"CarMenuMaxWidthRatio",.42)),.25,.6))); local viewportCardFit=math.floor((maxPanelW-panelPad*2-cardGap)/2); local cardW=math.max(64,math.min(targetCardW,viewportCardFit,math.floor(heightFit/aspect))); local cardH=math.max(24,math.floor(cardW*aspect)); local carW=panelPad*2+cardW*2+cardGap; local leftMargin=math.max(0,tonumber(read(config,"CarMenuLeftMargin",3))); carPanel.Position=UDim2.fromOffset(leftMargin,carTop); carPanel.Size=UDim2.fromOffset(carW,carH)
	local dropdownH=math.max(24,tonumber(read(config,"CarMenuDropdownHeight",28))); local fieldGap=math.max(3,cardGap-2); local fieldW=math.floor((carW-panelPad*2-fieldGap)/2); local dropdownY=4; carCategory.Position=UDim2.fromOffset(panelPad,dropdownY); carCategory.Size=UDim2.fromOffset(fieldW,dropdownH); carSort.Position=UDim2.fromOffset(panelPad+fieldW+fieldGap,dropdownY); carSort.Size=UDim2.fromOffset(fieldW,dropdownH)
	carScroll.Position=UDim2.fromOffset(panelPad-strokeSafe,scrollY); carScroll.Size=UDim2.fromOffset(carW-(panelPad-strokeSafe)*2,scrollH); carContent.Position=UDim2.fromOffset(0,topSafe); carContent.Size=UDim2.new(1,0,0,carContent.Size.Y.Offset); carGrid.HorizontalAlignment=Enum.HorizontalAlignment.Center; carGrid.CellPadding=UDim2.fromOffset(cardGap,cardGap); carGrid.CellSize=UDim2.fromOffset(cardW,cardH); carDespawn.Position=UDim2.fromOffset(panelPad,despawnY); carDespawn.Size=UDim2.new(1,-panelPad*2,0,despawnH)
	layoutModal(vp)
end

RunService.RenderStepped:Connect(function(dt)
	layout()
	local presentationActive=next(presentationOwners)~=nil
	local telemetryOnly=presentationActive
	for _,state in pairs(presentationOwners) do if not state.KeepTelemetry then telemetryOnly=false break end end
	local hidden=(presentationActive and not telemetryOnly) or majorMenu()
	if hidden and carMenuOpen then setCarMenuOpen(false) end
	gui.Enabled=not hidden
	local localMajorMenuOpen=modal.Visible or shade.Visible
	-- NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1
	local ownedGarageInside=player:GetAttribute("NTR_OwnedGarageInside")==true
	mapFrame.Visible=not ownedGarageInside and not telemetryOnly and not localMajorMenuOpen; cash.Visible=not telemetryOnly and not localMajorMenuOpen; nav.Visible=not telemetryOnly and not localMajorMenuOpen; carButton.Visible=not ownedGarageInside; garageButton.Visible=not ownedGarageInside; raceButton.Visible=not ownedGarageInside; shopButton.Visible=not ownedGarageInside; settingsButton.Visible=true
	if telemetryOnly or localMajorMenuOpen then toast.Visible=false end
	if hidden then return end
	local driving=drive.IsDriving==true
	telemetry.Visible=driving and not carMenuOpen and not localMajorMenuOpen
	exitButton.Visible=driving and not carMenuOpen and not telemetryOnly and not localMajorMenuOpen
	local s=subject(); if s then local position=s.Position; local mapSize=mapFrame.AbsoluteSize.X; local mapPixels=math.max(1,tonumber(read(desktopLayout,"MapPixels",2048))); local calPixels=math.max(1,tonumber(read(desktopLayout,"MapCalibrationPixels",207))); local calStuds=math.max(1,tonumber(read(desktopLayout,"MapCalibrationStuds",2850))); local fullStuds=mapPixels*calStuds/calPixels; local visible=math.max(100,tonumber(read(desktopLayout,"MapVisibleStuds",2850))); local uiPerStud=mapSize/visible; local canvasSize=fullStuds*uiPerStud; mapCanvas.Size=UDim2.fromOffset(canvasSize,canvasSize); local dx=position.X-tonumber(read(desktopLayout,"MapWorldCenterX",0)); local dz=position.Z-tonumber(read(desktopLayout,"MapWorldCenterZ",0)); if B(desktopDefaults,"MapFlipX",false) then dx=-dx end; if B(desktopDefaults,"MapFlipZ",false) then dz=-dz end; local angle=math.rad(tonumber(read(desktopLayout,"MapCoordinateRotationDegrees",90))); local mx=dx*math.cos(angle)-dz*math.sin(angle); local mz=dx*math.sin(angle)+dz*math.cos(angle); local target=Vector2.new(mapSize*.5,mapSize*.5)-Vector2.new(mx*uiPerStud,mz*uiPerStud); displayedPos=displayedPos and displayedPos:Lerp(target,1-math.exp(-10*dt)) or target; mapCanvas.Position=UDim2.fromOffset(displayedPos.X,displayedPos.Y); mapCanvas.Rotation=0; local look=s.CFrame.LookVector; local lookX,lookZ=look.X,look.Z; if B(desktopDefaults,"MapFlipX",false) then lookX=-lookX end; if B(desktopDefaults,"MapFlipZ",false) then lookZ=-lookZ end; local lx=lookX*math.cos(angle)-lookZ*math.sin(angle); local lz=lookX*math.sin(angle)+lookZ*math.cos(angle); local heading=math.deg(math.atan2(lx,-lz))+tonumber(read(desktopLayout,"MapRotationOffsetDegrees",0)); local diff=(heading-displayedHeading+180)%360-180; displayedHeading+=diff*(1-math.exp(-10*dt)); playerMarker.Rotation=B(desktopDefaults,"MapPlayerIconRotates",true) and displayedHeading or 0 end
	if driving then local speed=math.max(0,tonumber(drive.SpeedMph) or 0); speedText.Text=tostring(math.floor(speed+.5)); local target=math.clamp((tonumber(drive.BoostPercent) or 100)/100,0,1); displayedBoost+=(target-displayedBoost)*(1-math.exp(-14*dt)); boostFill.Size=UDim2.fromScale(1,displayedBoost); local gaugeMax=math.max(1,tonumber(read(desktopLayout,"SpeedGaugeMaxMph",260)) or 260); local active=math.floor(math.clamp(speed/gaugeMax,0,1)*#gauge+.5); for i,g in ipairs(gauge) do g.BackgroundColor3=i<=active and (i>#gauge*.82 and PINK or CYAN) or Color3.fromRGB(81,88,99); g.BackgroundTransparency=i<=active and 0 or .42 end end
	-- Cash is event-driven from leaderstats; no recurring profile request.
end)
print("[NTR Mobile Free-Roam UI Phase 1K] Compact boost plate and steering-bottom-aligned Exit active.")
