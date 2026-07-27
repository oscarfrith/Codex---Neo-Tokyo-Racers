-- Neo Tokyo Racers - Garage Scroll Edge Safety V1
-- NTR_GARAGE_SCROLL_EDGE_SAFETY_V1
-- Run once in the Roblox Studio Edit-mode Command Bar, then restart Play.
-- One guarded transaction for shared card-canvas measurement, physical edge
-- clearance, owned-garage bottom padding, and the native landscape contract.

local MODE = "INSTALL" -- INSTALL or AUDIT
local REVISION = "NTR_GARAGE_SCROLL_EDGE_SAFETY_V1"
local PREFIX = "[NTR Garage Scroll Edge Safety V1]"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object, parent:GetFullName() .. "." .. name .. " missing")
	if className then assert(object:IsA(className), object:GetFullName() .. " must be " .. className) end
	return object
end

local function compile(name, source)
	local fn, problem = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(problem))
end

local function countPlain(source, needle)
	local count, start = 0, 1
	while true do
		local first, last = string.find(source, needle, start, true)
		if not first then return count end
		count += 1
		start = last + 1
	end
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local clientRoot = need(
	need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"),
	"NeoTokyoRacersClient",
	"Folder"
)
local controllers = need(clientRoot, "Controllers", "Folder")
local ui = need(controllers, "UI", "Folder")
local preview = need(controllers, "Preview", "Folder")

local shared = need(ui, "GarageReplacementComponents", "ModuleScript")
local browser = need(ui, "GarageBrowserController", "ModuleScript")
local workspace = need(ui, "GarageWorkspaceController", "ModuleScript")
local owned = need(ui, "OwnedGarageBrowserController", "ModuleScript")
local thrustPreview = need(preview, "ThrustPreviewController_Active", "LocalScript")
local cachedThrust = need(
	need(
		need(
			need(need(kit, "Shared", "Folder"), "Modules", "Folder"),
			"Client",
			"Folder"
		),
		"Visuals",
		"Folder"
	),
	"CachedThrustVisualRuntime",
	"ModuleScript"
)

local targets = {
	GarageReplacementComponents = shared,
	GarageBrowserController = browser,
	GarageWorkspaceController = workspace,
	OwnedGarageBrowserController = owned,
	ThrustPreviewController = thrustPreview,
	CachedThrustVisualRuntime = cachedThrust,
}

local function installed()
	for _, object in pairs(targets) do
		if countPlain(object.Source, "-- " .. REVISION .. "\n") ~= 1 then return false end
	end
	return StarterGui.ScreenOrientation == Enum.ScreenOrientation.LandscapeSensor
end

local function audit()
	assert(StarterGui.ScreenOrientation == Enum.ScreenOrientation.LandscapeSensor, "StarterGui must use LandscapeSensor")
	for label, object in pairs(targets) do
		assert(countPlain(object.Source, "-- " .. REVISION .. "\n") == 1, label .. " marker missing or duplicated")
		compile(label, object.Source)
	end
	assert(string.find(shared.Source, "function M.UpdateHorizontalCardCanvas", 1, true), "shared horizontal canvas helper missing")
	assert(string.find(browser.Source, "Shared.UpdateHorizontalCardCanvas(self.Scroller,self.CarLayout,self.CarPad,scale,6)", 1, true), "Dealership/Customisation canvas helper missing")
	assert(string.find(workspace.Source, "Shared.UpdateHorizontalCardCanvas(self.Scroller,self.CardLayout,self.CardPad,scale,6)", 1, true), "workspace canvas helper missing")
	assert(string.find(owned.Source, "local function layoutListEdges()", 1, true), "owned-garage edge layout missing")
	assert(string.find(owned.Source, "listPad.PaddingBottom=UDim.new(0,edge)", 1, true), "owned-garage bottom clearance missing")
	assert(not string.find(thrustPreview.Source, "ScreenOrientation", 1, true), "preview runtime still owns orientation")
	assert(not string.find(cachedThrust.Source, "ScreenOrientation", 1, true), "cached VFX runtime still owns orientation")
	assert(not string.find(cachedThrust.Source, "orientationTimer", 1, true), "cached VFX orientation poll remains")
	print(PREFIX .. " AUDIT PASS | native LandscapeSensor | measured mixed-width carousels | physical edge and bottom clearance")
end

if MODE == "AUDIT" then
	assert(installed(), "Garage Scroll Edge Safety V1 is not fully installed")
	audit()
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

if installed() then
	audit()
	print(PREFIX .. " already installed; no changes made.")
	return
end

for label, object in pairs(targets) do
	assert(countPlain(object.Source, "-- " .. REVISION .. "\n") == 0, "Partial installation detected at " .. label .. "; refresh/inspect before retrying")
end

assert(string.find(shared.Source, "NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1", 1, true), "unknown shared garage component baseline")
assert(string.find(browser.Source, "NTR_SHARED_VEHICLE_CARD_SYSTEM_V1_2", 1, true), "unknown garage browser baseline")
assert(string.find(workspace.Source, "NTR_OWNED_GARAGE_VEHICLE_CARD_KIND_V1_6", 1, true), "unknown garage workspace baseline")
assert(string.find(owned.Source, "NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1_1", 1, true), "unknown owned-garage browser baseline")
assert(string.find(thrustPreview.Source, "NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1", 1, true), "unknown thrust-preview baseline")
assert(string.find(cachedThrust.Source, "NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1", 1, true), "unknown cached-thrust baseline")

local projected = {}

projected.GarageReplacementComponents = replaceOnce(
	shared.Source,
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1",
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1\n-- " .. REVISION,
	"shared component marker"
)
projected.GarageReplacementComponents = replaceOnce(
	projected.GarageReplacementComponents,
	[=[function M.FormatFullMoney(value) return "$"..M.FormatNumber(value) end
function M.FormatDealershipPrice(value)]=],
	[=[function M.FormatFullMoney(value) return "$"..M.FormatNumber(value) end
function M.LogicalPixelsForPhysical(physicalPixels,scale,minimumLogical)
	return math.max(tonumber(minimumLogical) or 0,math.ceil(math.max(0,tonumber(physicalPixels) or 0)/math.max(.01,tonumber(scale) or 1)))
end
function M.UpdateHorizontalCardCanvas(scroller,layout,padding,scale,minimumLogical)
	assert(scroller and scroller:IsA("ScrollingFrame"),"horizontal card canvas requires a ScrollingFrame")
	assert(layout and layout:IsA("UIListLayout"),"horizontal card canvas requires a UIListLayout")
	assert(padding and padding:IsA("UIPadding"),"horizontal card canvas requires UIPadding")
	scale=math.max(.01,tonumber(scale) or 1)
	local window=scroller.AbsoluteSize.X/scale
	local content,count=0,0
	for _,child in ipairs(scroller:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible and child:GetAttribute("CanonicalGarageCard")==true then
			local width=child.AbsoluteSize.X/scale
			if width<=0 then width=child.Size.X.Offset+window*child.Size.X.Scale end
			content+=width; count+=1
		end
	end
	if count>1 then content+=(count-1)*(layout.Padding.Offset+window*layout.Padding.Scale) end
	local physicalClearance=Racing.StrokeWidth("Glow")+2
	local minimum=M.LogicalPixelsForPhysical(physicalClearance,scale,minimumLogical or 6)
	local side=content<window and math.max(minimum,(window-content)*.5) or minimum
	padding.PaddingLeft=UDim.new(0,side); padding.PaddingRight=UDim.new(0,side)
	scroller.CanvasSize=UDim2.fromOffset(math.max(window,content+side*2),0)
	return {Content=content,Window=window,Side=side,PhysicalClearance=physicalClearance}
end
function M.FormatDealershipPrice(value)]=],
	"shared physical scroll-edge helpers"
)

projected.GarageBrowserController = replaceOnce(
	browser.Source,
	"-- NTR_SHARED_VEHICLE_CARD_SYSTEM_V1_2",
	"-- NTR_SHARED_VEHICLE_CARD_SYSTEM_V1_2\n-- " .. REVISION,
	"garage browser marker"
)
projected.GarageBrowserController = replaceOnce(
	projected.GarageBrowserController,
	[=[	self.UpdatingCarousel=true; local count=0; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then count+=1 end end
	local content=count*N("CardWidth",226)+math.max(0,count-1)*12; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local window=self.ReferenceCarouselWidth or self.Scroller.AbsoluteSize.X/scale; if self.Scroller.AbsoluteSize.X>0 then window=self.Scroller.AbsoluteSize.X/scale end
	local side=content<window and math.max(6,(window-content)*.5) or 6; self.CarPad.PaddingLeft=UDim.new(0,side); self.CarPad.PaddingRight=UDim.new(0,side); self.Scroller.CanvasSize=UDim2.fromOffset(math.max(window,content+side*2),0); self.UpdatingCarousel=false; self:RefreshCarouselArrows()]=],
	[=[	self.UpdatingCarousel=true
	local scale=math.max(self.LayoutScale or self.Scale.Scale,.01)
	local metrics=Shared.UpdateHorizontalCardCanvas(self.Scroller,self.CarLayout,self.CarPad,scale,6)
	self.ScrollEdgeLogical=metrics.Side; self.UpdatingCarousel=false; self:RefreshCarouselArrows()]=],
	"Dealership and Customisation measured carousel"
)

projected.GarageWorkspaceController = replaceOnce(
	workspace.Source,
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1",
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1\n-- " .. REVISION,
	"garage workspace marker"
)
projected.GarageWorkspaceController = replaceOnce(
	projected.GarageWorkspaceController,
	[=[	self.Updating=true; local count=0; for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then count+=1 end end
	local cardWidth=N("WorkspaceCardWidth",210); local content=count*cardWidth+math.max(0,count-1)*12; local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local window=self.ReferenceCarouselWidth or self.Scroller.AbsoluteSize.X/scale; if self.Scroller.AbsoluteSize.X>0 then window=self.Scroller.AbsoluteSize.X/scale end
	local side=content<window and math.max(6,(window-content)*.5) or 6; self.CardPad.PaddingLeft=UDim.new(0,side); self.CardPad.PaddingRight=UDim.new(0,side); self.Scroller.CanvasSize=UDim2.fromOffset(math.max(window,content+side*2),0); self.Updating=false; self:RefreshCarouselArrows()]=],
	[=[	self.Updating=true
	local scale=math.max(self.LayoutScale or self.Scale.Scale,.01)
	local metrics=Shared.UpdateHorizontalCardCanvas(self.Scroller,self.CardLayout,self.CardPad,scale,6)
	self.ScrollEdgeLogical=metrics.Side; self.Updating=false; self:RefreshCarouselArrows()]=],
	"workspace mixed-width measured carousel"
)

projected.OwnedGarageBrowserController = replaceOnce(
	owned.Source,
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1_1",
	"-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1_1\n-- " .. REVISION,
	"owned-garage browser marker"
)
projected.OwnedGarageBrowserController = replaceOnce(
	projected.OwnedGarageBrowserController,
	[=[	local list=Instance.new("Frame"); list.Name="CardContent"; list.BackgroundTransparency=1; list.Position=UDim2.fromOffset(4,4); list.Size=UDim2.new(1,-(UserInputService.TouchEnabled and 12 or 16),0,0); list.AutomaticSize=Enum.AutomaticSize.Y; list.Parent=listScroller; local listLayout=Instance.new("UIListLayout"); listLayout.Padding=UDim.new(0,12); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=list]=],
	[=[	local list=Instance.new("Frame"); list.Name="CardContent"; list.BackgroundTransparency=1; list.Size=UDim2.new(1,-16,0,0); list.AutomaticSize=Enum.AutomaticSize.Y; list.Parent=listScroller; local listLayout=Instance.new("UIListLayout"); listLayout.Padding=UDim.new(0,12); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=list
	local listPad=Instance.new("UIPadding"); listPad.Parent=list
	local function layoutListEdges()
		local scale=math.max(layoutScale and layoutScale.Scale or 1,.01)
		local physical=UI.StrokeWidth("Glow")+2
		local edge=Shared.LogicalPixelsForPhysical(physical,scale,4)
		local right=Shared.LogicalPixelsForPhysical(physical+listScroller.ScrollBarThickness,scale,12)
		list.Position=UDim2.fromOffset(edge,edge)
		list.Size=UDim2.new(1,-(edge+right),0,0)
		listPad.PaddingBottom=UDim.new(0,edge)
	end
	layoutListEdges()
	if layoutScale then layoutScale:GetPropertyChangedSignal("Scale"):Connect(function() if overlay.Visible then task.defer(layoutListEdges) end end) end]=],
	"owned-garage physical edge and bottom clearance"
)

projected.ThrustPreviewController = replaceOnce(
	thrustPreview.Source,
	"-- NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1",
	"-- NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1\n-- " .. REVISION,
	"thrust-preview marker"
)
projected.ThrustPreviewController = replaceOnce(
	projected.ThrustPreviewController,
	'local RunService=game:GetService("RunService")\nlocal StarterGui=game:GetService("StarterGui")',
	'local RunService=game:GetService("RunService")',
	"retire preview StarterGui orientation dependency"
)
projected.ThrustPreviewController = replaceOnce(
	projected.ThrustPreviewController,
	[=[local function requestLandscape() if not UserInputService.TouchEnabled then return end; pcall(function() StarterGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeSensor end); pcall(function() playerGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeSensor end) end
local function garageOpen()]=],
	[=[local function garageOpen()]=],
	"retire preview orientation writer"
)
projected.ThrustPreviewController = replaceOnce(
	projected.ThrustPreviewController,
	"requestLandscape(); refreshTargets()",
	"refreshTargets()",
	"retire preview orientation request"
)

projected.CachedThrustVisualRuntime = replaceOnce(
	cachedThrust.Source,
	"-- NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1",
	"-- NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1\n-- " .. REVISION,
	"cached-thrust marker"
)
projected.CachedThrustVisualRuntime = replaceOnce(
	projected.CachedThrustVisualRuntime,
	'local UserInputService = game:GetService("UserInputService")\nlocal StarterGui = game:GetService("StarterGui")',
	'local UserInputService = game:GetService("UserInputService")',
	"retire cached VFX StarterGui dependency"
)
projected.CachedThrustVisualRuntime = replaceOnce(
	projected.CachedThrustVisualRuntime,
	"local UI_RATE = 0.2\nlocal ORIENTATION_RATE = 1",
	"local UI_RATE = 0.2",
	"retire orientation poll rate"
)
projected.CachedThrustVisualRuntime = replaceOnce(
	projected.CachedThrustVisualRuntime,
	"local uiTimer = 0\nlocal orientationTimer = 0",
	"local uiTimer = 0",
	"retire orientation timer state"
)
projected.CachedThrustVisualRuntime = replaceOnce(
	projected.CachedThrustVisualRuntime,
	[=[local function requestLandscape()
	if not UserInputService.TouchEnabled then return end
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
	if playerGui then
		pcall(function() playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor end)
	end
end

local function initControls()]=],
	[=[local function initControls()]=],
	"retire cached VFX orientation writer"
)
projected.CachedThrustVisualRuntime = replaceOnce(
	projected.CachedThrustVisualRuntime,
	"\tscanCandidates()\n\trequestLandscape()\n\tconnection = RunService.RenderStepped:Connect(function(dt)",
	"\tscanCandidates()\n\tconnection = RunService.RenderStepped:Connect(function(dt)",
	"retire cached VFX startup orientation request"
)
projected.CachedThrustVisualRuntime = replaceOnce(
	projected.CachedThrustVisualRuntime,
	"\t\tuiTimer += dt\n\t\torientationTimer += dt",
	"\t\tuiTimer += dt",
	"retire cached VFX orientation accumulation"
)
projected.CachedThrustVisualRuntime = replaceOnce(
	projected.CachedThrustVisualRuntime,
	[=[
		if orientationTimer >= ORIENTATION_RATE then
			orientationTimer = 0
			requestLandscape()
		end]=],
	"",
	"retire cached VFX recurring orientation request"
)

for label, source in pairs(projected) do
	assert(countPlain(source, "-- " .. REVISION .. "\n") == 1, label .. " projected marker missing or duplicated")
	compile(label, source)
end

local originals = {}
for label, object in pairs(targets) do originals[label] = object.Source end
local oldOrientation = StarterGui.ScreenOrientation
local changed = {}

local ok, problem = pcall(function()
	for label, object in pairs(targets) do
		if object.Source ~= projected[label] then
			table.insert(changed, label)
			object.Source = projected[label]
		end
	end
	StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	audit()
end)

if not ok then
	for _, label in ipairs(changed) do targets[label].Source = originals[label] end
	StarterGui.ScreenOrientation = oldOrientation
	error(PREFIX .. " INSTALL ROLLBACK: " .. tostring(problem))
end

print(PREFIX .. " INSTALL PASS | restart Play; verify landscape phone/tablet and PC end-card borders, then refresh the complete Studio mirror.")
