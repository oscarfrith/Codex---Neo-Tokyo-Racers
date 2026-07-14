-- Neo Tokyo Racers - Mobile Free-Roam UI Phase 1L Modal Safe Area + PC Cash
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
--
-- Guarded patch to the isolated MobileFreeRoamHudController_Active only.
-- It gives Settings, Cash, and confirmation popups fixed reference sizes and
-- scales them into the same safe-area proportions approved for mobile Racing UI.
-- Cash ports the PC 2x2 card composition; purchases remain intentionally disabled.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Mobile Free-Roam UI Phase 1L"
local MARKER = "NTR_MOBILE_FREEROAM_UI_PHASE1L_MODAL_SAFE_AREA_PC_CASH"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message) error("[" .. PHASE .. "] " .. tostring(message), 2) end
local function log(message) print("[" .. PHASE .. "] " .. tostring(message)) end
local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. (parent and parent:GetFullName() or "nil") .. "." .. name)
	end
	return item
end
local function setDefaultAttribute(item, name, value)
	if item:GetAttribute(name) == nil then item:SetAttribute(name, value) end
end
local function replaceRange(source, firstAnchor, nextAnchor, replacement, label)
	local first = string.find(source, firstAnchor, 1, true)
	if not first then fail("Could not find " .. label .. " start anchor. Refresh the Studio mirror before another repair.") end
	local nextStart = string.find(source, nextAnchor, first + #firstAnchor, true)
	if not nextStart then fail("Could not find " .. label .. " end anchor. Refresh the Studio mirror before another repair.") end
	return string.sub(source, 1, first - 1) .. replacement .. "\n\n" .. string.sub(source, nextStart)
end
local function replaceOnce(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then fail("Could not find " .. label .. " anchor. Refresh the Studio mirror before another repair.") end
	if string.find(source, oldText, last + 1, true) then fail("Duplicate " .. label .. " anchors found; no source was changed.") end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = must(must(must(kit, "Config", "Folder"), "UI", "Folder"), "MobileFreeRoamHud", "Folder")
local racingMobileConfig = must(must(kit.Config.UI, "Racing", "Folder"), "MobileScaledDesktop", "Folder")

local playerScripts = must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = must(playerScripts, "NeoTokyoRacersClient", "Folder")
local controllers = must(clientRoot, "Controllers", "Folder")
local uiControllers = must(controllers, "UI", "Folder")
local owner = must(uiControllers, "MobileFreeRoamHudController_Active", "LocalScript")

if tonumber(racingMobileConfig:GetAttribute("SafeTop")) ~= 72 then
	fail("Mobile Racing UI Phase 1B SafeTop=72 is not present. Refresh the mirror before installing modal parity.")
end
if not string.find(owner.Source, "NTR_MOBILE_FREEROAM_UI_PHASE1K_BOOST_PLATE_EXIT_ALIGNMENT", 1, true) then
	fail("The confirmed Phase 1K mobile HUD owner is not installed.")
end

local MODAL_BLOCK = [====[
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
local function closeModal() shade.Visible=false; modal.Visible=false; clear(modalBody) end
shade.Activated:Connect(closeModal)
local function openModal(title,width,height) clear(modalBody); setModalReference(width,height); modalTitle.Text=title; shade.Visible=true; modal.Visible=true end

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

local function showTeleport()
	openModal("TELEPORT TO DEALERSHIP?",tonumber(read(config,"ConfirmModalWidth",650)) or 650,tonumber(read(config,"ConfirmModalHeight",270)) or 270)
	label(modalBody,"Message","Your current vehicle will be despawned.",UDim2.new(1,-20,0,60),UDim2.fromOffset(10,46),12,WHITE,Enum.TextXAlignment.Center)
	local no=button(modalBody,"No","NO",UDim2.fromOffset(270,54),UDim2.fromOffset(16,126),PINK); local yes=button(modalBody,"Yes","YES",UDim2.fromOffset(270,54),UDim2.fromOffset(336,126),CYAN); buttonGradient(no); buttonGradient(yes)
	no.Activated:Connect(closeModal); yes.Activated:Connect(function() closeModal(); local ok,result=pcall(function() return teleportInvoke:InvokeServer("TeleportToDealership") end); if ok and typeof(result)=="table" and result.Success then fire("FreeRoamVehicleExited"); showToast(result.Message or "TELEPORTED",true) else showToast(typeof(result)=="table" and (result.Message or result.Error) or "TELEPORT FAILED",false) end end)
end
]====]

local OLD_LAYOUT = 'local modalW=math.floor(math.clamp(vp.X*.72,430,720)); local modalH=math.floor(math.clamp(vp.Y*.72,300,470)); modal.Size=UDim2.fromOffset(modalW,modalH)'
local NEW_LAYOUT = 'layoutModal(vp)'

local function configure()
	local defaults = {
		ModalSafeTop = 72, ModalSafeBottom = 10, ModalSafeSide = 10,
		ModalScaleMin = 0.25, ModalScaleMax = 1,
		SettingsModalWidth = 720, SettingsModalHeight = 420,
		CashModalWidth = 840, CashModalHeight = 650,
		ConfirmModalWidth = 650, ConfirmModalHeight = 270,
	}
	for name, value in pairs(defaults) do setDefaultAttribute(config, name, value) end
	config:SetAttribute("InstalledBy", MARKER)
end

local function install()
	if string.find(owner.Source, MARKER, 1, true) then configure(); log("Already installed; refreshed missing config defaults."); return end
	local staged = replaceRange(owner.Source, 'local shade=new("TextButton"', 'local profileCache=nil', MODAL_BLOCK, "mobile modal family")
	staged = replaceOnce(staged, OLD_LAYOUT, NEW_LAYOUT, "mobile modal viewport layout")
	configure()
	owner.Source = "-- " .. MARKER .. "\n" .. staged
	log("Installed safe-area Settings/confirmation popups and the scaled PC-parity Cash composition.")
	log("Restart Play before testing. Cash product buttons remain intentionally non-transactional.")
end

local function smoke()
	local source = owner.Source
	for _, expected in ipairs({ MARKER, 'local function layoutModal(vp)', 'openModal("SETTINGS"', 'openModal("GET CASH"', 'openModal("TELEPORT TO DEALERSHIP?"', 'Name="SafeAreaScale"', '"BEST VALUE"', 'layoutModal(vp)' }) do
		if not string.find(source, expected, 1, true) then fail("Smoke missing " .. expected) end
	end
	if string.find(source, OLD_LAYOUT, 1, true) then fail("Old one-size responsive modal layout remains.") end
	for _, name in ipairs({ "ModalSafeTop", "ModalSafeBottom", "ModalSafeSide", "ModalScaleMin", "ModalScaleMax", "SettingsModalWidth", "SettingsModalHeight", "CashModalWidth", "CashModalHeight", "ConfirmModalWidth", "ConfirmModalHeight" }) do
		if config:GetAttribute(name) == nil then fail("Missing config attribute " .. name) end
	end
	log("SMOKE PASS: modal family uses config-driven safe-area scaling and PC-parity Cash cards.")
end

if MODE == "INSTALL" then install()
elseif MODE == "SMOKE" then smoke()
else fail("Unknown MODE " .. tostring(MODE)) end
