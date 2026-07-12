-- Neo Tokyo Racers - Racing UI Phase 14 Vehicle Grid Edge Padding
-- Paste into Roblox Studio Command Bar in Edit mode.
-- Keeps the scrolling clip while giving card strokes/glows safe internal space.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 14"
local StarterPlayer = game:GetService("StarterPlayer")
local MARKER = "NTR_RACING_UI_PHASE14_VEHICLE_GRID_SAFE_PADDING"

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end
local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end
local function controller()
	local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local ntr = scripts and scripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = ntr and ntr:FindFirstChild("Controllers")
	local racing = controllers and controllers:FindFirstChild("Racing")
	local item = racing and racing:FindFirstChild("RaceEntryPresentationController_Active")
	if not (item and item:IsA("LuaSourceContainer")) then fail("Missing active Race Entry presentation controller") end
	return item
end

local function install()
	local item = controller()
	local source = item.Source
	if string.find(source, MARKER, 1, true) then
		log("Vehicle grid safe padding already installed.")
		return
	end
	local anchor = [=[	grid.Name = "VehicleGrid" grid.BackgroundTransparency = 1 grid.BorderSizePixel = 0 grid.Position = UDim2.fromOffset(0, gridY) grid.Size = UDim2.new(1, 0, 1, -gridY) grid.ScrollBarThickness = touch and 3 or 6 grid.AutomaticCanvasSize = Enum.AutomaticSize.Y grid.CanvasSize = UDim2.fromOffset(0, 0) grid.Parent = content]=]
	local first, last = string.find(source, anchor, 1, true)
	if not first then fail("Could not find VehicleGrid construction anchor. Refresh the mirror before another repair.") end
	local addition = [=[
	local gridSafe = touch and 5 or 8 local gridPadding = Instance.new("UIPadding") gridPadding.Name = "CardEdgeSafePadding" gridPadding.PaddingTop = UDim.new(0, gridSafe) gridPadding.PaddingLeft = UDim.new(0, gridSafe) gridPadding.PaddingRight = UDim.new(0, gridSafe) gridPadding.PaddingBottom = UDim.new(0, gridSafe) gridPadding.Parent = grid -- NTR_RACING_UI_PHASE14_VEHICLE_GRID_SAFE_PADDING]=]
	item.Source = string.sub(source, 1, last) .. addition .. string.sub(source, last + 1)
	log("Installed responsive internal padding around VehicleGrid cards.")
end

local function smoke()
	local source = controller().Source
	assert(string.find(source, MARKER, 1, true), "Vehicle grid safe-padding marker missing")
	assert(string.find(source, "CardEdgeSafePadding", 1, true), "Vehicle grid UIPadding missing")
	log("SMOKE PASS")
end

if MODE == "INSTALL" then
	install()
	smoke()
	log("Install complete. Restart Play and reopen both vehicle pickers.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
