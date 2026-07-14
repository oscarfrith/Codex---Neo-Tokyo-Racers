-- Neo Tokyo Racers - Mobile Free-Roam UI Phase 1N Square Pedal Layout
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Geometry-only guarded patch: Accelerator and Brake become equal square image slots.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Mobile Free-Roam UI Phase 1N"
local MARKER = "NTR_MOBILE_FREEROAM_UI_PHASE1N_SQUARE_PEDAL_LAYOUT"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message) error("[" .. PHASE .. "] " .. tostring(message), 2) end
local function log(message) print("[" .. PHASE .. "] " .. tostring(message)) end
local function must(parent, name, className)
	local item=parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then fail("Missing " .. (parent and parent:GetFullName() or "nil") .. "." .. name) end
	return item
end
local function setDefaultAttribute(item,name,value) if item:GetAttribute(name)==nil then item:SetAttribute(name,value) end end
local function replaceOnce(source,oldText,newText,label)
	local first,last=string.find(source,oldText,1,true)
	if not first then fail("Could not find " .. label .. " anchor. Refresh the Studio mirror before another repair.") end
	if string.find(source,oldText,last+1,true) then fail("Duplicate " .. label .. " anchors found; no source was changed.") end
	return string.sub(source,1,first-1)..newText..string.sub(source,last+1)
end

local kit=must(ReplicatedStorage,"NeoTokyoRacers","Folder")
local config=must(must(must(kit,"Config","Folder"),"UI","Folder"),"MobileFreeRoamHud","Folder")
local assets=must(config,"Assets","Folder")
must(assets,"AcceleratorImage","StringValue")
must(assets,"BrakeImage","StringValue")

local playerScripts=must(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts")
local clientRoot=must(playerScripts,"NeoTokyoRacersClient","Folder")
local runtime=must(must(clientRoot,"Controllers","Folder"),"Runtime","Folder")
local owner=must(runtime,"MobileDriveControlsController_Active","LocalScript")
if not string.find(owner.Source,"NTR_MOBILE_FREEROAM_UI_PHASE1M_CONTROL_SURFACE_OPACITY",1,true) then fail("Confirmed Phase 1M control owner is missing.") end

local OLD_LAYOUT=[==[local pedalH=math.floor(math.clamp(vp.Y*.205,96,134)); local pedalW=math.floor(pedalH*.78)
	accelerator.Position=UDim2.fromOffset(vp.X-margin-pedalW,vp.Y-margin-pedalH); accelerator.Size=UDim2.fromOffset(pedalW,pedalH)
	brake.Position=UDim2.fromOffset(vp.X-margin-pedalW*2-gap,vp.Y-margin-pedalH*.78); brake.Size=UDim2.fromOffset(pedalW,pedalH*.78)]==]
local NEW_LAYOUT=[==[local pedalSize=math.max(44,math.floor(tonumber(A("PedalSize",104)) or 104)); local pedalBottom=math.max(0,math.floor(tonumber(A("PedalBottomOffset",10)) or 10)); local pedalRight=math.max(0,math.floor(tonumber(A("PedalRightOffset",10)) or 10)); local pedalGap=math.max(0,math.floor(tonumber(A("PedalGap",10)) or 10))
	accelerator.Position=UDim2.fromOffset(vp.X-pedalRight-pedalSize,vp.Y-pedalBottom-pedalSize); accelerator.Size=UDim2.fromOffset(pedalSize,pedalSize)
	brake.Position=UDim2.fromOffset(vp.X-pedalRight-pedalSize*2-pedalGap,vp.Y-pedalBottom-pedalSize); brake.Size=UDim2.fromOffset(pedalSize,pedalSize)]==]

local function configure()
	setDefaultAttribute(config,"PedalSize",104)
	setDefaultAttribute(config,"PedalBottomOffset",10)
	setDefaultAttribute(config,"PedalRightOffset",10)
	setDefaultAttribute(config,"PedalGap",10)
	config:SetAttribute("InstalledByPedalLayout",MARKER)
end

local function install()
	if string.find(owner.Source,MARKER,1,true) then configure(); log("Already installed; refreshed missing config defaults."); return end
	local staged=replaceOnce(owner.Source,OLD_LAYOUT,NEW_LAYOUT,"Phase 1M pedal geometry")
	configure()
	owner.Source="-- "..MARKER.."\n"..staged
	log("Installed equal square Accelerator/Brake image slots with configurable size and offsets.")
	log("Restart Play before testing. Pedal input, opacity, assets, and hit actions are unchanged.")
end

local function smoke()
	local source=owner.Source
	for _,expected in ipairs({MARKER,'A("PedalSize",104)','A("PedalBottomOffset",10)','A("PedalRightOffset",10)','A("PedalGap",10)','accelerator.Size=UDim2.fromOffset(pedalSize,pedalSize)','brake.Size=UDim2.fromOffset(pedalSize,pedalSize)'}) do
		if not string.find(source,expected,1,true) then fail("Smoke missing "..expected) end
	end
	if string.find(source,'local pedalH=math.floor(math.clamp(vp.Y*.205,96,134))',1,true) then fail("Old unequal pedal geometry remains.") end
	for _,name in ipairs({"PedalSize","PedalBottomOffset","PedalRightOffset","PedalGap","PedalCardOpacity","PedalImageOpacity"}) do if config:GetAttribute(name)==nil then fail("Missing config attribute "..name) end end
	log("SMOKE PASS: both pedal targets are equal squares with config-driven size, bottom/right offsets, and gap.")
end

if MODE=="INSTALL" then install()
elseif MODE=="SMOKE" then smoke()
else fail("Unknown MODE "..tostring(MODE)) end
