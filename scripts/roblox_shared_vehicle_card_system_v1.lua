-- Neo Tokyo Racers - Shared Vehicle Card System V1.2
-- Run in Roblox Studio Edit mode from the Command Bar.
-- Modes: INSTALL (transactional) or AUDIT (read-only).
-- V1.2 is a source-only responsive refinement of the confirmed/mirrored V1.1 system.

local MODE="INSTALL" -- "INSTALL" or "AUDIT"
local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Shared Vehicle Cards V1.2]"
local BASE_MARKER="-- NTR_SHARED_VEHICLE_CARD_SYSTEM_V1_1\n"
local MARKER="-- NTR_SHARED_VEHICLE_CARD_SYSTEM_V1_2"
local RUN_ID=HttpService:GenerateGUID(false)

local function count(source,needle)
	local total,cursor=0,1
	while true do local first,last=source:find(needle,cursor,true); if not first then return total end; total+=1; cursor=last+1 end
end
local function replaceOnce(source,needle,replacement,label)
	assert(count(source,needle)==1,label.." anchor count changed")
	local first=assert(source:find(needle,1,true),label.." anchor missing")
	return source:sub(1,first-1)..replacement..source:sub(first+#needle)
end
local function compile(source,label) local fn,problem=loadstring(source,"="..label); assert(fn,label.." compile failed: "..tostring(problem)) end
local function mark(source) assert(count(source,MARKER)==0,"duplicate V1.2 marker"); return MARKER.."\n"..source end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local clientRoot=assert(StarterPlayer:FindFirstChild("StarterPlayerScripts") and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient"),"NeoTokyoRacersClient missing")
local controllers=assert(clientRoot:FindFirstChild("Controllers"),"Controllers missing")
local uiControllers=assert(controllers:FindFirstChild("UI"),"Controllers.UI missing")
local racingControllers=assert(controllers:FindFirstChild("Racing"),"Controllers.Racing missing")
local owners={
	GarageShared=assert(uiControllers:FindFirstChild("GarageReplacementComponents"),"GarageReplacementComponents missing"),
	GarageBrowser=assert(uiControllers:FindFirstChild("GarageBrowserController"),"GarageBrowserController missing"),
	DesktopHud=assert(uiControllers:FindFirstChild("DesktopFreeRoamHudController_Active"),"Desktop HUD missing"),
	MobileHud=assert(uiControllers:FindFirstChild("MobileFreeRoamHudController_Active"),"Mobile HUD missing"),
	RacePresentation=assert(racingControllers:FindFirstChild("RaceEntryPresentationController_Active"),"Race presentation missing"),
}
for label,object in pairs(owners) do
	assert(object:IsA("LuaSourceContainer"),label.." is not source")
	if object:IsA("LocalScript") then assert(not object.Disabled,label.." must be enabled") end
	assert(count(object.Source,BASE_MARKER)==1,label.." confirmed V1.1 baseline missing")
end

local OLD_ECONOMY=[==[	self.CashValue=generated(Shared.EconomyMetric(self.Cash,{Kind="Cash",Text=Shared.FormatFullMoney(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=17,Color=Color3.fromRGB(89,255,102)})); self.CashValue.Name="CashValue"; self.CashValue.TextScaled=true; local cashConstraint=generated(Instance.new("UITextSizeConstraint")); cashConstraint.MinTextSize=10; cashConstraint.MaxTextSize=17; cashConstraint.Parent=self.CashValue; local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if typeof(context.OnCash)=="function" then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity; self.CapacityValue=generated(Shared.EconomyMetric(self.Capacity,{Kind="GarageSpaces",Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=16})); self.CapacityValue.TextScaled=true; local capacityConstraint=generated(Instance.new("UITextSizeConstraint")); capacityConstraint.MinTextSize=10; capacityConstraint.MaxTextSize=16; capacityConstraint.Parent=self.CapacityValue; local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if typeof(context.OnCapacity)=="function" then context.OnCapacity() end end)]==]
local NEW_ECONOMY=[==[	local mobileEconomy=UserInputService.TouchEnabled
	local cashTextSize=mobileEconomy and 11 or 17; local cashMinimum=mobileEconomy and 8 or 10
	local capacityTextSize=mobileEconomy and 10 or 16; local capacityMinimum=mobileEconomy and 8 or 10
	self.CashValue=generated(Shared.EconomyMetric(self.Cash,{Kind="Cash",Text=Shared.FormatFullMoney(context.Cash or 0),Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-54,1,0),TextSize=cashTextSize,Color=Color3.fromRGB(89,255,102)})); self.CashValue.Name="CashValue"; self.CashValue.TextScaled=true; local cashConstraint=generated(Instance.new("UITextSizeConstraint")); cashConstraint.MinTextSize=cashMinimum; cashConstraint.MaxTextSize=cashTextSize; cashConstraint.Parent=self.CashValue; local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated:Connect(function() if typeof(context.OnCash)=="function" then context.OnCash() end end)
	local icon=generated(Instance.new("ImageLabel")); icon.BackgroundTransparency=1; icon.Image=asset("GarageIcon"); icon.ImageColor3=Racing.Colour("Text"); icon.Position=UDim2.fromOffset(9,9); icon.Size=UDim2.fromOffset(28,28); icon.Parent=self.Capacity; self.CapacityValue=generated(Shared.EconomyMetric(self.Capacity,{Kind="GarageSpaces",Text=context.CapacityText or "0/0 Spaces",Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-92,1,0),TextSize=capacityTextSize})); self.CapacityValue.TextScaled=true; local capacityConstraint=generated(Instance.new("UITextSizeConstraint")); capacityConstraint.MinTextSize=capacityMinimum; capacityConstraint.MaxTextSize=capacityTextSize; capacityConstraint.Parent=self.CapacityValue; local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated:Connect(function() if typeof(context.OnCapacity)=="function" then context.OnCapacity() end end)]==]

local OLD_POPUP='if selectedCard and selected then local owned=context.OwnedCount(selected.CockpitId)>0; local text=context.Mode=="Customisation" and "CUSTOMISE" or ((owned and "BUY ANOTHER " or "BUY ")..Shared.FormatMoney(selected.Cockpit.Price or 0)); self.Popup:Set(selectedCard,text,function() context.OnPrimary(selected) end,self.Scale) else self.Popup:Hide() end'
local NEW_POPUP='if selectedCard and selected then local owned=context.OwnedCount(selected.CockpitId)>0; local mobilePopup=UserInputService.TouchEnabled; local text=context.Mode=="Customisation" and "CUSTOMISE" or (mobilePopup and (owned and "BUY ANOTHER" or "BUY") or ((owned and "BUY ANOTHER " or "BUY ")..Shared.FormatMoney(selected.Cockpit.Price or 0))); self.Popup:Set(selectedCard,text,function() context.OnPrimary(selected) end,self.Scale) else self.Popup:Hide() end'

local function projectBrowser(source)
	if count(source,MARKER)==1 then return source end
	source=replaceOnce(source,OLD_ECONOMY,NEW_ECONOMY,"responsive economy")
	source=replaceOnce(source,OLD_POPUP,NEW_POPUP,"mobile purchase popup")
	return mark(source)
end

local function audit()
	local failures={}
	local function expect(ok,message) if not ok then table.insert(failures,message) end end
	for label,object in pairs(owners) do local ok,problem=pcall(compile,object.Source,label.." committed"); expect(ok,label.." compile: "..tostring(problem)) end
	local browser=owners.GarageBrowser.Source
	expect(count(browser,MARKER)==1,"GarageBrowser V1.2 marker missing/duplicated")
	expect(browser:find("local mobileEconomy=UserInputService.TouchEnabled",1,true)~=nil,"mobile economy branch missing")
	expect(browser:find("mobileEconomy and 11 or 17",1,true)~=nil,"Cash mobile/PC scale contract missing")
	expect(browser:find("mobileEconomy and 10 or 16",1,true)~=nil,"Spaces mobile/PC scale contract missing")
	expect(browser:find('mobilePopup and (owned and "BUY ANOTHER" or "BUY")',1,true)~=nil,"mobile price-free popup contract missing")
	expect(browser:find('Shared.FormatMoney(selected.Cockpit.Price or 0)',1,true)~=nil,"desktop popup price missing")
	expect(count(browser,"BindReplicatedCash")==1,"Cash binding changed or duplicated")
	expect(count(browser,"Shared.VehicleCard(self.Scroller")==1,"browser shared-card call changed")
	expect(browser:find('OfferPurchase=context.Mode=="Dealership"',1,true)~=nil,"Dealership purchase gate missing")
	expect(owners.GarageShared.Source:find("function M.VehicleCard(parent,props)",1,true)~=nil,"canonical renderer missing")
	for label in pairs({DesktopHud=true,MobileHud=true,RacePresentation=true}) do expect(count(owners[label].Source,"VehicleCards.VehicleCard")==2,label.." shared-call count changed") end
	expect(owners.DesktopHud.Source:find("SpawnOwnedVehicleFromFreeRoam",1,true)~=nil and owners.MobileHud.Source:find("SpawnOwnedVehicleFromFreeRoam",1,true)~=nil,"spawn action missing")
	expect(owners.RacePresentation.Source:find('legacyAction:Fire("StartSelectedVehicle"',1,true)~=nil,"race-start action missing")
	local bootstrap=clientRoot:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"); expect(not bootstrap or count(bootstrap.Source,MARKER)==0,"bootstrap edited")
	if #failures>0 then error(TAG.." AUDIT FAIL | "..table.concat(failures," | ")) end
	print(TAG.." AUDIT PASS | mobile-economy=11/10 desktop-economy=17/16 mobile-popup=no-price desktop-popup=price-preserved")
end

if MODE=="AUDIT" then audit(); return end
assert(MODE=="INSTALL","Unknown MODE: "..tostring(MODE))
local browser=owners.GarageBrowser
if count(browser.Source,MARKER)==1 then audit(); print(TAG.." INSTALL PASS (already installed)"); return end
local snapshot=browser.Source
local projected=projectBrowser(snapshot)
compile(projected,"GarageBrowser projected")
local ok,problem=pcall(function() browser.Source=projected; audit() end)
if not ok then browser.Source=snapshot; error(TAG.." INSTALL ROLLED BACK | "..tostring(problem)) end
print(TAG.." INSTALL PASS | runId="..RUN_ID)
print(TAG.." Verify mobile Cash/Spaces size, price-free mobile BUY/BUY ANOTHER, price-bearing desktop popup, purchase action, affordability and repeated selector open/close; then refresh the complete Studio mirror.")
