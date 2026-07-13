-- Neo Tokyo Racers - Racing UI Phase 16C1 Map Anchor / Size Repair
-- Paste into Roblox Studio Command Bar in Edit mode after Phase 16C.
-- Config-only repair: no LuaSourceContainer is modified.

local PHASE="NTR Racing UI Phase 16C1"
local ROUTE_ID="ShiftedCanalSprint"
local SOURCE_IMAGE_PIXELS=512
local MAP_WIDTH=420
local MAP_HEIGHT=420

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local Workspace=game:GetService("Workspace")
local function fail(message) error("["..PHASE.."] "..tostring(message),2) end
local function log(message) print("["..PHASE.."] "..tostring(message)) end

local controller=StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):FindFirstChild("RaceSessionPresentationController_Active")
if not (controller and controller:IsA("LuaSourceContainer") and string.find(controller.Source,"NTR_RACING_UI_PHASE16C_CONFIG_DRIVEN_HUD_MAP",1,true)) then fail("Confirmed Phase 16C controller marker missing") end

local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local ui=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing"):WaitForChild("InRace")
local maps=kit.Config:WaitForChild("Racing"):WaitForChild("HudMapCatalog")
local map=maps:FindFirstChild(ROUTE_ID)
if not map then fail("Missing HudMapCatalog."..ROUTE_ID) end

local function number(parent,name,value)
	local item=parent:FindFirstChild(name)
	if not (item and item:IsA("NumberValue")) then fail(parent:GetFullName().."."..name.." must be a NumberValue") end
	item.Value=value
end
local function stringValue(parent,name,value)
	local item=parent:FindFirstChild(name)
	if not (item and item:IsA("StringValue")) then fail(parent:GetFullName().."."..name.." must be a StringValue") end
	item.Value=value
end
local function bool(parent,name,value)
	local item=parent:FindFirstChild(name)
	if not (item and item:IsA("BoolValue")) then fail(parent:GetFullName().."."..name.." must be a BoolValue") end
	item.Value=value
end

local world=Workspace:FindFirstChild("NeoTokyoRacersWorld")
local routes=world and world:FindFirstChild("RaceRoutes")
local route=routes and routes:FindFirstChild(ROUTE_ID)
local grid=route and route:FindFirstChild("SpawnGrid")
local anchor=grid and grid:FindFirstChild("Grid_01")
if not (anchor and anchor:IsA("BasePart")) then fail("Missing authoritative route anchor SpawnGrid.Grid_01") end

-- The uploaded source is square. Calibration stays in original 512px space;
-- only the HUD geometry doubles, matching the free-roam separation of map
-- scale, coordinate calibration and marker size.
number(map,"ImageWidthPixels",SOURCE_IMAGE_PIXELS)
number(map,"ImageHeightPixels",SOURCE_IMAGE_PIXELS)
stringValue(map,"AnchorPartName","Grid_01")
bool(map,"UseConfiguredWorldAnchor",false)
number(ui,"MapWidth",MAP_WIDTH)
number(ui,"MapHeight",MAP_HEIGHT)

assert(map.ImageWidthPixels.Value==512 and map.ImageHeightPixels.Value==512,"Source image dimensions did not apply")
assert(map.AnchorPartName.Value=="Grid_01" and map.UseConfiguredWorldAnchor.Value==false,"Grid anchor did not apply")
assert(ui.MapWidth.Value==420 and ui.MapHeight.Value==420,"HUD map geometry did not apply")

log("Applied 512x512 source calibration, 420x420 HUD geometry and Grid_01 world anchor at X="..string.format("%.2f",anchor.Position.X).." Z="..string.format("%.2f",anchor.Position.Z))
log("Kept StartPixelX/Y, StudsPerPixel, MapRotationDegrees, FlipX/Y and marker size unchanged. Restart Play.")
