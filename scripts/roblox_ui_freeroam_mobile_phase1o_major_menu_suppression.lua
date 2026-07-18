-- Neo Tokyo Racers - Mobile Free-Roam UI Phase 1O Major Menu Suppression
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Guarded mobile-only visibility/input patch for major menus and popups.

local MODE="INSTALL" -- INSTALL or SMOKE
local PHASE="NTR Mobile Free-Roam UI Phase 1O"
local MARKER="NTR_MOBILE_FREEROAM_UI_PHASE1O_MAJOR_MENU_SUPPRESSION"
local BLOCK_ATTRIBUTE="NTRMobileMajorMenuOpen"

local StarterPlayer=game:GetService("StarterPlayer")

local function fail(message) error("["..PHASE.."] "..tostring(message),2) end
local function log(message) print("["..PHASE.."] "..tostring(message)) end
local function must(parent,name,className)
	local item=parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then fail("Missing "..(parent and parent:GetFullName() or "nil").."."..name) end
	return item
end
local function replaceOnce(source,oldText,newText,label)
	local first,last=string.find(source,oldText,1,true)
	if not first then fail("Missing "..label.." anchor. No source was changed; refresh the Studio mirror before another repair.") end
	if string.find(source,oldText,last+1,true) then fail("Duplicate "..label.." anchors. No source was changed.") end
	return string.sub(source,1,first-1)..newText..string.sub(source,last+1)
end

local playerScripts=must(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts")
local client=must(playerScripts,"NeoTokyoRacersClient","Folder")
local controllers=must(client,"Controllers","Folder")
local hudOwner=must(must(controllers,"UI","Folder"),"MobileFreeRoamHudController_Active","LocalScript")
local controlsOwner=must(must(controllers,"Runtime","Folder"),"MobileDriveControlsController_Active","LocalScript")

local HUD_MODAL_OLD=[=[local function closeModal() shade.Visible=false; modal.Visible=false; clear(modalBody) end
shade.Activated:Connect(closeModal)
local function openModal(title,width,height) clear(modalBody); setModalReference(width,height); modalTitle.Text=title; shade.Visible=true; modal.Visible=true end]=]
local HUD_MODAL_NEW=[=[player:SetAttribute("NTRMobileMajorMenuOpen",false)
local function closeModal() shade.Visible=false; modal.Visible=false; player:SetAttribute("NTRMobileMajorMenuOpen",false); clear(modalBody) end
shade.Activated:Connect(closeModal)
local function openModal(title,width,height) clear(modalBody); setModalReference(width,height); modalTitle.Text=title; shade.Visible=true; modal.Visible=true; player:SetAttribute("NTRMobileMajorMenuOpen",true) end]=]

local HUD_VISIBILITY_OLD=[=[mapFrame.Visible=not telemetryOnly cash.Visible=not telemetryOnly nav.Visible=not telemetryOnly
	if telemetryOnly then toast.Visible=false end
	if hidden then return end
	local driving=drive.IsDriving==true
	telemetry.Visible=driving and not carMenuOpen
	exitButton.Visible=driving and not carMenuOpen and not telemetryOnly]=]
local HUD_VISIBILITY_NEW=[=[local localMajorMenuOpen=modal.Visible or shade.Visible
	mapFrame.Visible=not telemetryOnly and not localMajorMenuOpen cash.Visible=not telemetryOnly and not localMajorMenuOpen nav.Visible=not telemetryOnly and not localMajorMenuOpen
	if telemetryOnly or localMajorMenuOpen then toast.Visible=false end
	if hidden then return end
	local driving=drive.IsDriving==true
	telemetry.Visible=driving and not carMenuOpen and not localMajorMenuOpen
	exitButton.Visible=driving and not carMenuOpen and not telemetryOnly and not localMajorMenuOpen]=]

local CONTROLS_OLD='layout(); local driving=M.IsDriving==true; local menuBlocked=player:GetAttribute("NTRMobileFreeRoamCarMenuOpen")==true; root.Visible=driving and not menuBlocked'
local CONTROLS_NEW='layout(); local driving=M.IsDriving==true; local menuBlocked=player:GetAttribute("NTRMobileFreeRoamCarMenuOpen")==true or player:GetAttribute("NTRMobileMajorMenuOpen")==true or not gui.Enabled; root.Visible=driving and not menuBlocked'

local function preflight()
	local hudMarked=string.find(hudOwner.Source,MARKER,1,true)~=nil
	local controlsMarked=string.find(controlsOwner.Source,MARKER,1,true)~=nil
	if hudMarked and controlsMarked then return nil,nil,true end
	if hudMarked or controlsMarked then fail("Partial Phase 1O install detected. Restore the immediately preceding Studio version before rerunning.") end
	if not string.find(hudOwner.Source,"NTR_MOBILE_FREEROAM_UI_PHASE1L_MODAL_SAFE_AREA_PC_CASH",1,true) then fail("Confirmed Phase 1L HUD owner is missing.") end
	if not string.find(controlsOwner.Source,"NTR_MOBILE_FREEROAM_UI_PHASE1N_SQUARE_PEDAL_LAYOUT",1,true) then fail("Confirmed Phase 1N controls owner is missing.") end
	local stagedHud=replaceOnce(hudOwner.Source,HUD_MODAL_OLD,HUD_MODAL_NEW,"mobile modal ownership")
	stagedHud=replaceOnce(stagedHud,HUD_VISIBILITY_OLD,HUD_VISIBILITY_NEW,"mobile HUD major-menu visibility")
	local stagedControls=replaceOnce(controlsOwner.Source,CONTROLS_OLD,CONTROLS_NEW,"mobile control major-menu input gate")
	return stagedHud,stagedControls,false
end

local function install()
	local stagedHud,stagedControls,already=preflight()
	if already then log("Already installed.") return end
	hudOwner.Source="-- "..MARKER.."\n"..stagedHud
	controlsOwner.Source="-- "..MARKER.."\n"..stagedControls
	log("Installed mobile major-menu HUD/control suppression and held-input release gating.")
	log("Restart Play, then verify Race Browser, dealership confirmation, Settings, and Get Cash on mobile.")
end

local function smoke()
	for _,item in ipairs({hudOwner,controlsOwner}) do if not string.find(item.Source,MARKER,1,true) then fail(item.Name.." marker missing") end end
	for _,expected in ipairs({'SetAttribute("'..BLOCK_ATTRIBUTE..'",true)','local localMajorMenuOpen=modal.Visible or shade.Visible','not localMajorMenuOpen'}) do if not string.find(hudOwner.Source,expected,1,true) then fail("HUD smoke missing "..expected) end end
	if not string.find(controlsOwner.Source,'GetAttribute("'..BLOCK_ATTRIBUTE..'")==true',1,true) then fail("Control input gate missing") end
	if not string.find(controlsOwner.Source,"or not gui.Enabled",1,true) then fail("External full-screen menu input gate missing") end
	if not string.find(controlsOwner.Source,"if menuBlocked then if not wasMenuBlocked then clearInputs() end",1,true) then fail("Held-input release path missing") end
	log("SMOKE PASS: mobile major popups hide free-roam HUD/telemetry and independently-owned vehicle controls while preserving modal presentation.")
end

if MODE=="INSTALL" then install()
elseif MODE=="SMOKE" then smoke()
else fail("MODE must be INSTALL or SMOKE") end
