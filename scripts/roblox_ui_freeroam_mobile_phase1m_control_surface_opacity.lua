-- Neo Tokyo Racers - Mobile Free-Roam UI Phase 1M Control Surface Opacity
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
--
-- Visual-only guarded patch to MobileDriveControlsController_Active:
--   * turn/drift cards have no border/glow and receive a configurable gradient;
--   * turn/drift card and image opacity are independently configurable;
--   * pedal cards default to fully invisible while pedal image opacity is configurable.
-- Input, hitboxes, layout, steering/drift logic, throttle/brake, boost, Thumbstick,
-- Tilt, and the register-limited bootstrap are unchanged.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Mobile Free-Roam UI Phase 1M"
local MARKER = "NTR_MOBILE_FREEROAM_UI_PHASE1M_CONTROL_SURFACE_OPACITY"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message) error("[" .. PHASE .. "] " .. tostring(message), 2) end
local function log(message) print("[" .. PHASE .. "] " .. tostring(message)) end
local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then fail("Missing " .. (parent and parent:GetFullName() or "nil") .. "." .. name) end
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

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = must(must(must(kit, "Config", "Folder"), "UI", "Folder"), "MobileFreeRoamHud", "Folder")
local playerScripts = must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = must(playerScripts, "NeoTokyoRacersClient", "Folder")
local controllers = must(clientRoot, "Controllers", "Folder")
local runtime = must(controllers, "Runtime", "Folder")
local ui = must(controllers, "UI", "Folder")
local owner = must(runtime, "MobileDriveControlsController_Active", "LocalScript")
local hudOwner = must(ui, "MobileFreeRoamHudController_Active", "LocalScript")

if not string.find(owner.Source, "NTR_MOBILE_FREEROAM_UI_PHASE1K_BOOST_PLATE_EXIT_ALIGNMENT", 1, true) then fail("Confirmed Phase 1K control owner is missing.") end
if not string.find(hudOwner.Source, "NTR_MOBILE_FREEROAM_UI_PHASE1L_MODAL_SAFE_AREA_PC_CASH", 1, true) then fail("Confirmed Phase 1L mobile HUD owner is missing.") end

local VISUAL_BLOCK = [====[
local allButtons={}
local function visualKind(name)
	if name=="TurnLeft" or name=="TurnRight" or name=="DriftLeft" or name=="DriftRight" then return "Arrow" end
	if name=="Accelerator" or name=="Brake" then return "Pedal" end
	return "Default"
end
local function opacity(name,fallback) return math.clamp(tonumber(A(name,fallback)) or fallback,0,1) end
local function controlButton(name,imageName,fallback,rotation)
	local kind=visualKind(name); local cardOpacity=kind=="Arrow" and opacity("ArrowCardOpacity",.72) or kind=="Pedal" and opacity("PedalCardOpacity",0) or .88
	local b=new("TextButton",{Name=name,Text="",AutoButtonColor=false,BackgroundColor3=PANEL,BackgroundTransparency=1-cardOpacity,BorderSizePixel=0,ClipsDescendants=true,ZIndex=5},root); b:SetAttribute("NTRControlVisual",kind)
	corner(b,16); local s=nil
	if kind~="Arrow" and kind~="Pedal" then s=stroke(b,PINK,2,.05) end
	if kind=="Arrow" then new("UIGradient",{Name="CardGradient",Color=ColorSequence.new(SOFT,PANEL),Rotation=tonumber(A("ArrowCardGradientRotation",90)) or 90},b) end
	local image=asset(imageName); local imageOpacity=kind=="Arrow" and opacity("ArrowImageOpacity",.92) or kind=="Pedal" and opacity("PedalImageOpacity",.92) or 1
	if image~="" then new("ImageLabel",{Name="Art",BackgroundTransparency=1,BorderSizePixel=0,Image=image,ImageTransparency=1-imageOpacity,Rotation=rotation or 0,ScaleType=Enum.ScaleType.Fit,Size=UDim2.fromScale(1,1),ZIndex=6},b)
	else local fallbackSize=(name=="Accelerator" or name=="Brake") and 10 or name=="Boost" and 9 or name:find("Drift") and 22 or 28; local t=label(b,"Fallback",fallback,UDim2.fromScale(1,1),UDim2.fromScale(0,0),fallbackSize,WHITE); t.TextWrapped=true; t.TextTransparency=1-imageOpacity; t.Rotation=rotation or 0 end
	allButtons[b]=s
	return b
end
local function pressed(b,on)
	local s=allButtons[b]
	if b.Name=="Boost" then b.BackgroundTransparency=1; if s then s.Transparency=1 end; return end
	local kind=tostring(b:GetAttribute("NTRControlVisual") or "Default")
	if kind=="Arrow" then
		local cardOpacity=math.clamp(opacity("ArrowCardOpacity",.72)+(on and opacity("ArrowPressedOpacityBoost",.12) or 0),0,1); b.BackgroundTransparency=1-cardOpacity
	elseif kind=="Pedal" then
		b.BackgroundTransparency=1-opacity("PedalCardOpacity",0)
	else
		b.BackgroundTransparency=on and 0 or .12; if s then s.Color=on and CYAN or PINK; s.Thickness=on and 3 or 2 end
	end
	local imageOpacity=kind=="Arrow" and opacity("ArrowImageOpacity",.92) or kind=="Pedal" and opacity("PedalImageOpacity",.92) or .92
	if on and (kind=="Arrow" or kind=="Pedal") then imageOpacity=math.clamp(imageOpacity+opacity("ControlPressedImageOpacityBoost",.08),0,1) end
	local art=b:FindFirstChild("Art"); if art then art.ImageTransparency=1-imageOpacity end
	local fallback=b:FindFirstChild("Fallback"); if fallback and (kind=="Arrow" or kind=="Pedal") then fallback.TextTransparency=1-imageOpacity end
end
]====]

local function configure()
	local defaults = {
		ArrowCardOpacity = 0.72,
		ArrowImageOpacity = 0.92,
		ArrowPressedOpacityBoost = 0.12,
		ArrowCardGradientRotation = 90,
		PedalCardOpacity = 0,
		PedalImageOpacity = 0.92,
		ControlPressedImageOpacityBoost = 0.08,
	}
	for name, value in pairs(defaults) do setDefaultAttribute(config, name, value) end
	config:SetAttribute("InstalledByControls", MARKER)
end

local function install()
	if string.find(owner.Source, MARKER, 1, true) then configure(); log("Already installed; refreshed missing config defaults."); return end
	local staged = replaceRange(owner.Source, "local allButtons={}", "local turnLeft=controlButton", VISUAL_BLOCK, "control surface visual factory")
	configure()
	owner.Source = "-- " .. MARKER .. "\n" .. staged
	log("Installed borderless gradient arrow cards and image-only pedal defaults with opacity tuning.")
	log("Restart Play before testing. Input actions, hitboxes, and layout are unchanged.")
end

local function smoke()
	local source=owner.Source
	for _, expected in ipairs({ MARKER, 'return "Arrow"', 'return "Pedal"', 'Name="CardGradient"', 'kind~="Arrow" and kind~="Pedal"', 'opacity("ArrowCardOpacity"', 'opacity("ArrowImageOpacity"', 'opacity("PedalCardOpacity"', 'opacity("PedalImageOpacity"' }) do
		if not string.find(source,expected,1,true) then fail("Smoke missing " .. expected) end
	end
	for _, name in ipairs({ "ArrowCardOpacity", "ArrowImageOpacity", "ArrowPressedOpacityBoost", "ArrowCardGradientRotation", "PedalCardOpacity", "PedalImageOpacity", "ControlPressedImageOpacityBoost" }) do
		if config:GetAttribute(name)==nil then fail("Missing config attribute " .. name) end
	end
	log("SMOKE PASS: arrows are borderless gradient cards and pedals default to image-only presentation.")
end

if MODE=="INSTALL" then install()
elseif MODE=="SMOKE" then smoke()
else fail("Unknown MODE " .. tostring(MODE)) end
