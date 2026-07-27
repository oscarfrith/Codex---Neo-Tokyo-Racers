-- Neo Tokyo Racers - Free-Roam Cash Smoothing V1
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
--
-- INSTALL:
--   Leave MODE = "INSTALL", run once, require AUDIT PASS and INSTALL PASS,
--   then restart Play.
--
-- AUDIT:
--   Change MODE to "AUDIT". This is read-only.
--
-- ROLLBACK:
--   Change MODE to "ROLLBACK". This removes this exact presentation feature.
--
-- This is presentation-only. It does not mutate Cash, change leaderstats,
-- call an economy remote, alter ProfileService, or change drive reward cadence.
-- Exact source anchors intentionally abort before mutation if the live sources
-- have drifted. A failed INSTALL restores all source/config state from that run.

local MODE = "INSTALL" -- INSTALL, AUDIT, or ROLLBACK
local PHASE = "NTR Free-Roam Cash Smoothing V1"
local REVISION = "NTR_FREEROAM_CASH_SMOOTHING_V1"
local FOUNDATION_MARKER = "NTR_FREEROAM_CASH_PRESENTER_V1"
local DESKTOP_MARKER = "NTR_FREEROAM_CASH_SMOOTHING_DESKTOP_V1"
local MOBILE_MARKER = "NTR_FREEROAM_CASH_SMOOTHING_MOBILE_V1"

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. tostring(parent and parent:GetFullName() or "<nil>") .. "." .. tostring(name))
	end
	return item
end

local function countPlain(source, needle)
	local count = 0
	local cursor = 1
	while true do
		local first = string.find(source, needle, cursor, true)
		if not first then return count end
		count += 1
		cursor = first + #needle
	end
end

local function replaceOnce(source, anchor, replacement, label)
	local count = countPlain(source, anchor)
	if count ~= 1 then
		fail(label .. " anchor count expected 1, got " .. tostring(count)
			.. ". Refresh and inspect the live mirror; do not loosen this anchor.")
	end
	local first, last = string.find(source, anchor, 1, true)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local function insertAfterOnce(source, anchor, insertion, label)
	return replaceOnce(source, anchor, anchor .. insertion, label)
end

local function insertBeforeOnce(source, anchor, insertion, label)
	return replaceOnce(source, anchor, insertion .. anchor, label)
end

local function compile(source, label)
	if #source > 180000 then fail(label .. " projected source exceeds 180,000 bytes.") end
	local chunk, problem = loadstring(source, "=" .. tostring(label))
	if not chunk then fail(label .. " compile failed: " .. tostring(problem)) end
end

local function restoreAttributes(instance, snapshot)
	for name in pairs(instance:GetAttributes()) do
		if snapshot[name] == nil then instance:SetAttribute(name, nil) end
	end
	for name, value in pairs(snapshot) do instance:SetAttribute(name, value) end
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local uiConfig = must(must(kit, "Config", "Folder"), "UI", "Folder")
local theme = must(uiConfig, "Theme", "Folder")
local shared = must(must(kit, "Shared", "Folder"), "Modules", "Folder")
local sharedUI = must(shared, "UI", "Folder")
local foundation = must(sharedUI, "ResponsiveUIFoundation", "ModuleScript")
local starterScripts = must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = must(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = must(clientRoot, "Controllers", "Folder")
local uiControllers = must(controllers, "UI", "Folder")
local desktop = must(uiControllers, "DesktopFreeRoamHudController_Active", "LocalScript")
local mobile = must(uiControllers, "MobileFreeRoamHudController_Active", "LocalScript")
if desktop.Disabled or mobile.Disabled then fail("Both canonical free-roam Cash presentation owners must remain enabled.") end

local CONFIG_DEFAULTS = {
	CashCountAnimationEnabled = true,
	CashCountDurationSeconds = 0.4,
	CashCountEveryDollarLimit = 12,
	CashCountLargeIncreaseMaximumSteps = 20,
	FreeRoamCashUseFullFormatting = true,
}

local CONFIG_DESCRIPTIONS = {
	CashCountAnimationEnabled = "Presentation-only free-roam Cash counting. Does not change authoritative Cash or reward cadence.",
	CashCountDurationSeconds = "Target duration for a positive free-roam Cash count animation. Runtime clamps to 0.15-0.75 seconds.",
	CashCountEveryDollarLimit = "Positive gains at or below this value display every whole dollar. Runtime clamps to 1-24.",
	CashCountLargeIncreaseMaximumSteps = "Maximum bounded display updates for a larger positive grant. Runtime clamps to 4-60.",
	FreeRoamCashUseFullFormatting = "True shows full grouped free-roam Cash such as $10,000,000. False restores compact formatting.",
}

local FOUNDATION_FORMAT_ANCHOR = [==[
function M.FormatCompactMoney(value)
	local amount=math.max(0,math.floor(tonumber(value) or 0))
	if amount<1000000 then return "$"..M.FormatNumber(amount) end
	local tenths=math.floor(amount/100000)
	return "$"..string.format("%.1f",tenths/10).."M"
end
]==]

local FOUNDATION_INSERT = [==[

-- NTR_FREEROAM_CASH_PRESENTER_V1
-- Presentation state only. Authoritative Cash remains leaderstats.Cash and is
-- never inferred from, delayed by, or written through this presenter.
local function cashPresentationFlag(name,fallback)
	local child=theme:FindFirstChild(name)
	if child and child:IsA("BoolValue") then return child.Value end
	local value=theme:GetAttribute(name)
	return typeof(value)=="boolean" and value or fallback
end

function M.FormatFullMoney(value)
	return "$"..M.FormatNumber(math.max(0,math.floor(tonumber(value) or 0)))
end

function M.FormatFreeRoamMoney(value)
	if cashPresentationFlag("FreeRoamCashUseFullFormatting",true) then
		return M.FormatFullMoney(value)
	end
	return M.FormatCompactMoney(value)
end

function M.CreateCashDisplayPresenter(render,options)
	assert(type(render)=="function","Cash presenter requires a render callback")
	options=type(options)=="table" and options or {}
	local displayed=nil
	local authoritative=nil
	local generation=0
	local destroyed=false

	local function publish(value)
		if destroyed then return end
		displayed=math.max(0,math.floor(tonumber(value) or 0))
		render(displayed,authoritative)
	end

	local presenter={}
	function presenter:SetTarget(value,forceSnap)
		if destroyed then return end
		local target=math.clamp(math.floor(tonumber(value) or 0),0,2000000000)
		authoritative=target
		generation+=1
		local token=generation
		local enabled=options.Enabled
		if enabled==nil then enabled=cashPresentationFlag("CashCountAnimationEnabled",true) end
		if forceSnap==true or displayed==nil or enabled~=true or target<=displayed then
			publish(target)
			return
		end

		local start=displayed
		local delta=target-start
		local duration=math.clamp(tonumber(options.DurationSeconds)
			or number("CashCountDurationSeconds",0.4),0.15,0.75)
		local everyDollarLimit=math.clamp(math.floor(tonumber(options.EveryDollarLimit)
			or number("CashCountEveryDollarLimit",12)),1,24)
		local maximumSteps=math.clamp(math.floor(tonumber(options.MaximumSteps)
			or number("CashCountLargeIncreaseMaximumSteps",20)),4,60)
		local steps=delta<=everyDollarLimit and delta or math.min(delta,maximumSteps)
		local stepDelay=duration/math.max(1,steps)

		task.spawn(function()
			for step=1,steps do
				task.wait(stepDelay)
				if destroyed or token~=generation then return end
				local nextValue
				if delta<=everyDollarLimit then
					nextValue=start+step
				else
					nextValue=start+math.floor(delta*step/steps)
				end
				publish(math.min(target,nextValue))
			end
			if not destroyed and token==generation and displayed~=target then publish(target) end
		end)
	end

	function presenter:Snap(value)
		self:SetTarget(value,true)
	end

	function presenter:GetDisplayed()
		return displayed
	end

	function presenter:GetAuthoritative()
		return authoritative
	end

	function presenter:Destroy()
		if destroyed then return end
		destroyed=true
		generation+=1
	end

	return presenter
end
]==]

local DESKTOP_MARKER_INSERT = "-- " .. DESKTOP_MARKER .. "\n"

local DESKTOP_FORMAT_ORIGINAL = [==[
local function formatCash(value)
	return Foundation.FormatCompactMoney(value)
end
]==]

local DESKTOP_FORMAT_NEW = [==[
local function formatCash(value)
	return Foundation.FormatFreeRoamMoney(value)
end
]==]

local DESKTOP_CASH_ORIGINAL = [==[
local cashConnection
local function bindReplicatedCash()
	if cashConnection then cashConnection:Disconnect(); cashConnection = nil end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not (cash and cash:IsA("IntValue")) then return false end
	local function updateCash()
		if not (moneyLabel and moneyLabel.Parent) then return end
		moneyLabel.Text = formatCash(cash.Value)
		local balanceChip = modalPanels.Cash and modalPanels.Cash:FindFirstChild("BalanceChip")
		if balanceChip and balanceChip:IsA("TextButton") then balanceChip.Text = "BALANCE  " .. moneyLabel.Text end
	end
	updateCash()
	cashConnection = cash:GetPropertyChangedSignal("Value"):Connect(updateCash)
	return true
end
if not bindReplicatedCash() then
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 15)
		if leaderstats then leaderstats:WaitForChild("Cash", 15) end
		bindReplicatedCash()
	end)
end
]==]

local DESKTOP_CASH_NEW = [==[
local cashBindingState={}
cashBindingState.Presenter=Foundation.CreateCashDisplayPresenter(function(displayedCash)
	if not (moneyLabel and moneyLabel.Parent) then return end
	moneyLabel.Text=formatCash(displayedCash)
	local balanceChip=modalPanels.Cash and modalPanels.Cash:FindFirstChild("BalanceChip")
	if balanceChip and balanceChip:IsA("TextButton") then balanceChip.Text="BALANCE  "..moneyLabel.Text end
end)
local function bindReplicatedCash()
	if cashBindingState.Connection then cashBindingState.Connection:Disconnect(); cashBindingState.Connection=nil end
	local leaderstats=player:FindFirstChild("leaderstats")
	local cash=leaderstats and leaderstats:FindFirstChild("Cash")
	if not (cash and cash:IsA("IntValue")) then return false end
	local function updateCash()
		-- leaderstats remains authoritative; only the rendered integer is smoothed.
		cashBindingState.Presenter:SetTarget(cash.Value)
	end
	updateCash()
	cashBindingState.Connection=cash:GetPropertyChangedSignal("Value"):Connect(updateCash)
	return true
end
if not bindReplicatedCash() then
	task.spawn(function()
		local leaderstats=player:WaitForChild("leaderstats",15)
		if leaderstats then leaderstats:WaitForChild("Cash",15) end
		bindReplicatedCash()
	end)
end
]==]

local MOBILE_MARKER_INSERT = "-- " .. MOBILE_MARKER .. "\n"

local MOBILE_CASH_ORIGINAL = [==[
Foundation.StyleMetric(cashText,"Cash")
Foundation.BindReplicatedCash(player,function(value) cashText.Text=Foundation.FormatCompactMoney(value) end)
]==]

local MOBILE_CASH_NEW = [==[
Foundation.StyleMetric(cashText,"Cash")
local cashPresenter=Foundation.CreateCashDisplayPresenter(function(displayedCash)
	if cashText and cashText.Parent then
		cashText.Text=Foundation.FormatFreeRoamMoney(displayedCash)
		local balanceChip=modalBody and modalBody:FindFirstChild("BalanceChip")
		if balanceChip and balanceChip:IsA("TextButton") then balanceChip.Text="BALANCE  "..cashText.Text end
	end
end)
Foundation.BindReplicatedCash(player,function(authoritativeCash)
	-- Presentation target only; leaderstats remains the real balance.
	cashPresenter:SetTarget(authoritativeCash)
end)
]==]

local function projectSources()
	local foundationSource=foundation.Source
	local desktopSource=desktop.Source
	local mobileSource=mobile.Source

	local foundationCount=countPlain(foundationSource,FOUNDATION_MARKER)
	if foundationCount==0 then
		foundationSource=insertAfterOnce(foundationSource,FOUNDATION_FORMAT_ANCHOR,FOUNDATION_INSERT,
			"ResponsiveUIFoundation Cash presenter")
	elseif foundationCount~=1 then
		fail("ResponsiveUIFoundation contains an unexpected Cash presenter marker count.")
	end

	local desktopCount=countPlain(desktopSource,DESKTOP_MARKER)
	if desktopCount==0 then
		desktopSource=insertBeforeOnce(desktopSource,"-- NTR_SHARED_VEHICLE_CARD_SYSTEM_V1_1\n",
			DESKTOP_MARKER_INSERT,"Desktop free-roam marker")
		desktopSource=replaceOnce(desktopSource,DESKTOP_FORMAT_ORIGINAL,DESKTOP_FORMAT_NEW,
			"Desktop full Cash formatting")
		desktopSource=replaceOnce(desktopSource,DESKTOP_CASH_ORIGINAL,DESKTOP_CASH_NEW,
			"Desktop Cash presenter")
	elseif desktopCount~=1 then
		fail("Desktop free-roam controller contains an unexpected smoothing marker count.")
	end

	local mobileCount=countPlain(mobileSource,MOBILE_MARKER)
	if mobileCount==0 then
		mobileSource=insertBeforeOnce(mobileSource,"-- NTR_SHARED_VEHICLE_CARD_SYSTEM_V1_1\n",
			MOBILE_MARKER_INSERT,"Mobile free-roam marker")
		mobileSource=replaceOnce(mobileSource,MOBILE_CASH_ORIGINAL,MOBILE_CASH_NEW,
			"Mobile Cash presenter")
	elseif mobileCount~=1 then
		fail("Mobile free-roam controller contains an unexpected smoothing marker count.")
	end
	return foundationSource,desktopSource,mobileSource
end

local function descriptionFolder()
	local folder=theme:FindFirstChild("Descriptions")
	if folder and not folder:IsA("Folder") then fail(folder:GetFullName().." must be a Folder.") end
	return folder
end

local function setDescription(name,text)
	local folder=descriptionFolder()
	if not folder then
		folder=Instance.new("Folder")
		folder.Name="Descriptions"
		folder.Parent=theme
	end
	local item=folder:FindFirstChild(name)
	if item and not item:IsA("StringValue") then fail(item:GetFullName().." must be a StringValue.") end
	if not item then
		item=Instance.new("StringValue")
		item.Name=name
		item.Parent=folder
	end
	item.Value=text
end

local function audit()
	local blockers={}
	local warnings={}
	local function requireCheck(condition,message) if not condition then table.insert(blockers,message) end end
	local function warnCheck(condition,message) if not condition then table.insert(warnings,message) end end
	requireCheck(countPlain(foundation.Source,FOUNDATION_MARKER)==1,"Shared Cash presenter marker is missing.")
	requireCheck(countPlain(desktop.Source,DESKTOP_MARKER)==1,"Desktop smoothing marker is missing.")
	requireCheck(countPlain(mobile.Source,MOBILE_MARKER)==1,"Mobile smoothing marker is missing.")
	requireCheck(foundation:GetAttribute("FreeRoamCashPresentationRevision")==REVISION,
		"ResponsiveUIFoundation revision attribute is missing.")
	requireCheck(desktop:GetAttribute("FreeRoamCashPresentationRevision")==REVISION,
		"Desktop free-roam revision attribute is missing.")
	requireCheck(mobile:GetAttribute("FreeRoamCashPresentationRevision")==REVISION,
		"Mobile free-roam revision attribute is missing.")
	requireCheck(theme:GetAttribute("FreeRoamCashPresentationRevision")==REVISION,
		"Theme revision attribute is missing.")
	for name in pairs(CONFIG_DEFAULTS) do
		requireCheck(theme:GetAttribute(name)~=nil,"Theme attribute "..name.." is missing.")
	end
	requireCheck(string.find(foundation.Source,"function M.FormatFullMoney",1,true)~=nil,
		"Full grouped money formatter is missing.")
	requireCheck(string.find(foundation.Source,"function M.CreateCashDisplayPresenter",1,true)~=nil,
		"Cash display presenter is missing.")
	requireCheck(string.find(desktop.Source,"Foundation.FormatFreeRoamMoney",1,true)~=nil,
		"Desktop free-roam does not use full-configurable money formatting.")
	requireCheck(string.find(mobile.Source,"Foundation.FormatFreeRoamMoney",1,true)~=nil,
		"Mobile free-roam does not use full-configurable money formatting.")
	requireCheck(string.find(desktop.Source,"cashBindingState.Presenter:SetTarget(cash.Value)",1,true)~=nil,
		"Desktop authoritative Cash target bridge is missing.")
	requireCheck(string.find(mobile.Source,"cashPresenter:SetTarget(authoritativeCash)",1,true)~=nil,
		"Mobile authoritative Cash target bridge is missing.")
	requireCheck(string.find(foundation.Source,"RemoteEvent",1,true)==nil
		and string.find(foundation.Source,"RemoteFunction",1,true)==nil,
		"Shared presenter must not add an economy remote.")
	warnCheck(theme:GetAttribute("FreeRoamCashUseFullFormatting")==true,
		"FreeRoamCashUseFullFormatting is tuned away from the approved full grouped format.")
	if #blockers>0 then
		for _,message in ipairs(blockers) do warn("["..PHASE.."] BLOCKER "..message) end
		fail("AUDIT FAIL blockers="..#blockers.." warnings="..#warnings)
	end
	for _,message in ipairs(warnings) do warn("["..PHASE.."] WARN "..message) end
	log(string.format(
		"AUDIT PASS authority=leaderstats.Cash surfaces=Desktop+Mobile duration=%.2fs everyDollarLimit=%d maximumSteps=%d fullFormatting=%s noRemotes=true warnings=%d",
		tonumber(theme:GetAttribute("CashCountDurationSeconds")) or 0,
		math.floor(tonumber(theme:GetAttribute("CashCountEveryDollarLimit")) or 0),
		math.floor(tonumber(theme:GetAttribute("CashCountLargeIncreaseMaximumSteps")) or 0),
		tostring(theme:GetAttribute("FreeRoamCashUseFullFormatting")==true),#warnings))
end

local function rollback()
	local foundationSource=foundation.Source
	local desktopSource=desktop.Source
	local mobileSource=mobile.Source
	if countPlain(foundationSource,FOUNDATION_MARKER)>0 then
		foundationSource=replaceOnce(foundationSource,FOUNDATION_INSERT,"","Rollback shared Cash presenter")
	end
	if countPlain(desktopSource,DESKTOP_MARKER)>0 then
		desktopSource=replaceOnce(desktopSource,DESKTOP_MARKER_INSERT,"","Rollback desktop marker")
		desktopSource=replaceOnce(desktopSource,DESKTOP_FORMAT_NEW,DESKTOP_FORMAT_ORIGINAL,
			"Rollback desktop Cash format")
		desktopSource=replaceOnce(desktopSource,DESKTOP_CASH_NEW,DESKTOP_CASH_ORIGINAL,
			"Rollback desktop Cash presenter")
	end
	if countPlain(mobileSource,MOBILE_MARKER)>0 then
		mobileSource=replaceOnce(mobileSource,MOBILE_MARKER_INSERT,"","Rollback mobile marker")
		mobileSource=replaceOnce(mobileSource,MOBILE_CASH_NEW,MOBILE_CASH_ORIGINAL,
			"Rollback mobile Cash presenter")
	end
	compile(foundationSource,"ResponsiveUIFoundation rollback")
	compile(desktopSource,"Desktop free-roam rollback")
	compile(mobileSource,"Mobile free-roam rollback")
	foundation.Source=foundationSource
	desktop.Source=desktopSource
	mobile.Source=mobileSource
	for name in pairs(CONFIG_DEFAULTS) do theme:SetAttribute(name,nil) end
	theme:SetAttribute("FreeRoamCashPresentationRevision",nil)
	foundation:SetAttribute("FreeRoamCashPresentationRevision",nil)
	desktop:SetAttribute("FreeRoamCashPresentationRevision",nil)
	mobile:SetAttribute("FreeRoamCashPresentationRevision",nil)
	local descriptions=descriptionFolder()
	if descriptions then
		for name in pairs(CONFIG_DEFAULTS) do
			local item=descriptions:FindFirstChild(name)
			if item and item:IsA("StringValue") then item:Destroy() end
		end
		if #descriptions:GetChildren()==0 then descriptions:Destroy() end
	end
	ChangeHistoryService:SetWaypoint(PHASE.." rollback")
	log("ROLLBACK PASS. Authoritative Cash was never changed.")
end

if MODE=="AUDIT" then
	audit()
	return
elseif MODE=="ROLLBACK" then
	rollback()
	return
elseif MODE~="INSTALL" then
	fail("Unknown MODE "..tostring(MODE))
end

local projectedFoundation,projectedDesktop,projectedMobile=projectSources()
compile(projectedFoundation,"ResponsiveUIFoundation projected")
compile(projectedDesktop,"Desktop free-roam projected")
compile(projectedMobile,"Mobile free-roam projected")

local existingRevision=theme:GetAttribute("FreeRoamCashPresentationRevision")
if existingRevision~=nil and existingRevision~=REVISION then
	fail("Theme already contains a different free-roam Cash presentation revision.")
end
local sourcesAlreadyInstalled=countPlain(foundation.Source,FOUNDATION_MARKER)==1
	and countPlain(desktop.Source,DESKTOP_MARKER)==1
	and countPlain(mobile.Source,MOBILE_MARKER)==1
for name in pairs(CONFIG_DEFAULTS) do
	if existingRevision==nil and not sourcesAlreadyInstalled and theme:GetAttribute(name)~=nil then
		fail("Theme attribute "..name.." already exists outside this installer revision.")
	end
end

local descriptionsBefore=descriptionFolder()
local descriptionValues={}
if descriptionsBefore then
	for name in pairs(CONFIG_DEFAULTS) do
		local item=descriptionsBefore:FindFirstChild(name)
		if item then
			if not item:IsA("StringValue") then fail(item:GetFullName().." must be a StringValue.") end
			descriptionValues[name]=item.Value
		end
	end
end
local snapshot={
	FoundationSource=foundation.Source,
	DesktopSource=desktop.Source,
	MobileSource=mobile.Source,
	FoundationAttributes=foundation:GetAttributes(),
	DesktopAttributes=desktop:GetAttributes(),
	MobileAttributes=mobile:GetAttributes(),
	ThemeAttributes=theme:GetAttributes(),
	DescriptionsExisted=descriptionsBefore~=nil,
	DescriptionValues=descriptionValues,
}

local ok,problem=pcall(function()
	if foundation.Source~=projectedFoundation then foundation.Source=projectedFoundation end
	if desktop.Source~=projectedDesktop then desktop.Source=projectedDesktop end
	if mobile.Source~=projectedMobile then mobile.Source=projectedMobile end
	for name,value in pairs(CONFIG_DEFAULTS) do
		if theme:GetAttribute(name)==nil then theme:SetAttribute(name,value) end
		setDescription(name,CONFIG_DESCRIPTIONS[name])
	end
	theme:SetAttribute("FreeRoamCashPresentationRevision",REVISION)
	foundation:SetAttribute("FreeRoamCashPresentationRevision",REVISION)
	desktop:SetAttribute("FreeRoamCashPresentationRevision",REVISION)
	mobile:SetAttribute("FreeRoamCashPresentationRevision",REVISION)
	audit()
end)

if not ok then
	foundation.Source=snapshot.FoundationSource
	desktop.Source=snapshot.DesktopSource
	mobile.Source=snapshot.MobileSource
	restoreAttributes(foundation,snapshot.FoundationAttributes)
	restoreAttributes(desktop,snapshot.DesktopAttributes)
	restoreAttributes(mobile,snapshot.MobileAttributes)
	restoreAttributes(theme,snapshot.ThemeAttributes)
	local descriptions=descriptionFolder()
	if descriptions then
		for name in pairs(CONFIG_DEFAULTS) do
			local item=descriptions:FindFirstChild(name)
			local oldValue=snapshot.DescriptionValues[name]
			if item and oldValue~=nil then item.Value=oldValue
			elseif item and oldValue==nil then item:Destroy() end
		end
		if not snapshot.DescriptionsExisted and #descriptions:GetChildren()==0 then descriptions:Destroy() end
	end
	fail("INSTALL ROLLED BACK: "..tostring(problem))
end

ChangeHistoryService:SetWaypoint(PHASE.." install")
log("INSTALL PASS. Restart Play and verify free-roam counting, full formatting, purchases, device layouts, and lifecycle cleanup.")
