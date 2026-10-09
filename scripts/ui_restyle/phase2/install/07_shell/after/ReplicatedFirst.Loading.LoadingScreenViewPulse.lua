-- Owns the Pulse loading view (status line, progress bar and the unchanged artwork) that LoadingTransitionRuntime drives; not the runtime, the artwork catalogue or the start-screen flow.
-- Pulse UI (phase2). ReplicatedFirst.Loading.LoadingScreenViewPulse. Requires: Kit.Tokens, Kit.Metrics, Kit.Layers, Kit.Text, Kit.Presence (resolved on the first Create, never at require).

-- Same public interface as ReplicatedFirst.Loading.LoadingScreenView (Classic; line numbers below refer to it):
-- Create, Warm, SetArtwork, Show, SetProgressImmediate, StartMotion, SetStatus, SetProgress, FadeOut, Hide, Destroy.
-- Artwork handling (catalogue entry fields, grid tiles, motion) is carried from that file unchanged; type, bar and
-- status are Pulse. Nothing here writes ScreenGui.Enabled: the two roots are shown and hidden with Visible.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local View = {}
View.__index = View

local LAYER_NAME = "LoadingSafeContent"
local SURFACE = "Loading"
local STATUS_ROLE = "Button"
local TRACK_Y = 0.81 -- Classic 46: the bar starts at 81% of the safe height (Regular)
local KIT_WAIT_SECONDS = 20
local KIT_PATH = { "Modules", "Game", "UIPulse", "Kit" }
-- Every kit module the four used below reach through script.Parent, so none is required before it has replicated.
local KIT_MODULES = { "Sprites", "Contracts", "Presence", "Tokens", "Metrics", "Layers", "Text" }

local kitCache
-- YIELDS on the first call only, and for at most KIT_WAIT_SECONDS per instance; then errors (a reported failed state).
local function loadKit()
	if kitCache then
		return kitCache
	end
	local folder = ReplicatedStorage
	for _, name in ipairs(KIT_PATH) do
		local child = folder:WaitForChild(name, KIT_WAIT_SECONDS)
		assert(child, "[Pulse.LoadingScreenViewPulse] " .. name .. " did not arrive under " .. folder:GetFullName())
		folder = child
	end
	for _, name in ipairs(KIT_MODULES) do
		assert(folder:WaitForChild(name, KIT_WAIT_SECONDS), "[Pulse.LoadingScreenViewPulse] Kit." .. name .. " did not arrive")
	end
	kitCache = {
		Tokens = require(folder.Tokens),
		Metrics = require(folder.Metrics),
		Layers = require(folder.Layers),
		Text = require(folder.Text),
		Presence = require(folder.Presence),
	}
	return kitCache
end
-- Test and gallery seam: replace with a function returning {Tokens, Metrics, Layers, Text, Presence}.
View._kit = loadKit

-- The loading view exists before ClientBase has committed the routes, and Claim refuses until then. The latch
-- publishes UIStyleCommitted on its own ModuleScript, so the claim is made when that turns true, and never if the
-- session was downgraded to Classic.
local function claimWhenCommitted(surface)
	local latchModule = ReplicatedFirst:FindFirstChild("UIStyleSwitch")
	if not latchModule then
		return
	end
	local okLatch, latch = pcall(require, latchModule)
	if not okLatch or type(latch) ~= "table" then
		return
	end
	local connection = nil
	local function try()
		if latch.Style ~= "Pulse" then
			return true
		end
		if latchModule:GetAttribute("UIStyleCommitted") ~= true then
			return false
		end
		local ok, problem = pcall(latch.Claim, surface)
		if not ok then
			warn("[Pulse.LoadingScreenViewPulse] " .. tostring(problem))
		end
		return true
	end
	if try() then
		return
	end
	connection = latchModule:GetAttributeChangedSignal("UIStyleCommitted"):Connect(function()
		if try() and connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

local function new(className, properties, parent)
	local item = Instance.new(className)
	for key, value in pairs(properties or {}) do item[key] = value end
	item.Parent = parent
	return item
end

-- Builds the view on two given roots. Create passes the layer's roots; the gallery and the tests pass their own.
-- setShown(visible) shows or hides both roots.
function View._mount(kit, safeRoot, backgroundRoot, ctx, config, setShown)
	local Tokens, Text = kit.Tokens, kit.Text
	local Space, Colour, Opacity = Tokens.Space, Tokens.Colour, Tokens.Opacity
	local self = setmetatable({}, View)
	self.Config = config
	self.Kit = kit
	self.Context = ctx
	self.Tweens = {}
	self.MotionTween = nil
	self.ProgressTween = nil
	self.GridImages = {}
	self.ArtworkGeneration = 0
	self.Fading = false
	self.SetShown = setShown
	self.TrackTransparency = 1 - Opacity.SegmentEmpty

	-- Artwork and the input blocker: Classic 33-38, same names, classes and properties.
	local background = new("Frame", { Name = "BlackBacking", Active = true, BackgroundColor3 = Colour.Black, BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, backgroundRoot)
	local artworkClip = new("Frame", { Name = "ArtworkClip", Active = false, BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, background)
	local artworkMotion = new("Frame", { Name = "ArtworkMotion", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.08, 1.08), ZIndex = 2 }, artworkClip)
	local artwork = new("ImageLabel", { Name = "SingleArtwork", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Image = "", ImageTransparency = 0, Position = UDim2.fromScale(0.5, 0.5), ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, artworkMotion)
	local gridComposite = new("Frame", { Name = "GridArtwork", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3 }, artworkMotion)
	local blocker = new("TextButton", { Name = "InputBlocker", Active = true, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Modal = true, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 10 }, background)

	-- Status and bar: the names and classes the start-screen flow reads (Status is a TextLabel it writes Text and
	-- Visible on; ProgressFill is a childless Frame it clones and whose X scale is the progress).
	local status = new("TextLabel", { Name = "Status", BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = Text.Font(STATUS_ROLE), Text = "LOADING", TextColor3 = Colour.White, TextTransparency = 0, TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 22 }, safeRoot)
	local track = new("Frame", { Name = "ProgressTrack", BackgroundColor3 = Colour.White, BackgroundTransparency = self.TrackTransparency, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 22 }, safeRoot)
	local fill = new("Frame", { Name = "ProgressFill", BackgroundColor3 = Colour.Cyan, BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 23 }, track)

	self.SafeRoot = safeRoot
	self.BackgroundRoot = backgroundRoot
	self.Background = background
	self.ArtworkClip = artworkClip
	self.ArtworkMotion = artworkMotion
	self.Artwork = artwork
	self.GridComposite = gridComposite
	self.Blocker = blocker
	self.Status = status
	self.Track = track
	self.Fill = fill

	-- Regular: a centred bar at Classic's height with the status centred above it. Compact: a full-width bar on the
	-- bottom margin with the status at its left end. Whole pixels.
	local function layout()
		local size = safeRoot.AbsoluteSize
		local width, height = math.floor(size.X), math.floor(size.Y)
		if width <= 0 or height <= 0 then
			width, height = math.floor(ctx.Size.X), math.floor(ctx.Size.Y)
		end
		local compact = ctx.Class == "Compact"
		local textSize = (Text.SizeFor(STATUS_ROLE, ctx))
		local gap = ctx.Px(Space.Gap)
		local trackHeight = ctx.Px(Space.SegmentHeight)
		local margin = ctx.Px(compact and Space.CompactMargin or Space.MenuMargin)
		local trackWidth = math.max(1, width - margin - margin)
		local trackX, trackY = margin, height - ctx.Px(Space.CompactBottom) - trackHeight
		if not compact then
			trackWidth = math.min(trackWidth, ctx.Px(Space.ToastMaxWidth))
			trackX = math.floor((width - trackWidth) / 2)
			trackY = math.floor(height * TRACK_Y)
		end
		local lineHeight = textSize + textSize
		status.TextSize = textSize
		status.TextXAlignment = compact and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		status.Position = UDim2.fromOffset(trackX, trackY - gap - lineHeight)
		status.Size = UDim2.fromOffset(trackWidth, lineHeight)
		track.Position = UDim2.fromOffset(trackX, trackY)
		track.Size = UDim2.fromOffset(trackWidth, trackHeight)
	end
	layout()
	self.Relayout = layout
	self.Connections = {
		safeRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout),
		artworkClip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_UpdateCompositeCover()
		end),
	}
	if ctx.Changed then
		table.insert(self.Connections, ctx.Changed:Connect(layout))
	end
	return self
end

function View.Create(_playerGui, config, _colours)
	local kit = View._kit()
	-- LoadingSafeContent (1001, safe area) holds SafeRoot; LoadingSafeContentScrim (1000, whole screen) holds the
	-- artwork and the input blocker. Layers.Create is the only ScreenGui factory in Pulse.
	local layer = kit.Layers.Create(LAYER_NAME, { Frame = "Bare", Scrim = true, RootName = "SafeRoot" })
	layer.SetVisible(false)
	local self = View._mount(kit, layer.Root, layer.ScrimRoot, layer.Metrics, config, layer.SetVisible)
	self.Layer = layer
	self.BackgroundGui = layer.ScrimGui
	self.SafeGui = layer.Gui
	claimWhenCommitted(SURFACE)
	task.spawn(function()
		local ok, problem = pcall(kit.Text.Preload)
		if not ok then warn("[Pulse.LoadingScreenViewPulse] Text.Preload failed: " .. tostring(problem)) end
	end)
	return self
end

-- Classic 70-205, unchanged ------------------------------------------------------------------------------------
function View:_UpdateCompositeCover()
	if not self.GridComposite then return end
	local size = self.ArtworkClip.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	local viewportAspect = size.X / size.Y
	local sourceAspect = tonumber(self.Entry and self.Entry.AspectRatio) or (16 / 9)
	if viewportAspect >= sourceAspect then
		self.GridComposite.Size = UDim2.fromScale(1, viewportAspect / sourceAspect)
	else
		self.GridComposite.Size = UDim2.fromScale(sourceAspect / viewportAspect, 1)
	end
end

function View:_EnsureGridImages(count)
	while #self.GridImages < count do
		local image = new("ImageLabel", {
			Name = "Tile",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = "",
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 3,
		}, self.GridComposite)
		pcall(function() image.ResampleMode = Enum.ResamplerMode.Default end)
		table.insert(self.GridImages, image)
	end
	for index, image in ipairs(self.GridImages) do
		image.Visible = index <= count
		if index > count then image.Image = "" end
	end
end

local function allLoaded(images, count)
	for index = 1, count do
		if not images[index].IsLoaded then return false end
	end
	return true
end

local function fetchStatusName(contentId)
	local ok, status = pcall(function() return ContentProvider:GetAssetFetchStatus(contentId) end)
	return ok and status and status.Name or "Unknown"
end

local function failedTiles(tiles, resolved)
	local failures = {}
	for _, tile in ipairs(tiles or {}) do
		local status = resolved[tile.ImageAssetId]
		if status ~= "Success" then
			table.insert(failures, ("%s=%s(%s)"):format(tile.Name, tostring(status or fetchStatusName(tile.ImageAssetId)), tile.ImageAssetId))
		end
	end
	return failures
end

function View:SetArtwork(entry)
	self.ArtworkGeneration += 1
	local generation = self.ArtworkGeneration
	self.Fading = false
	self.Entry = entry
	self.Artwork.Image = tostring(entry and entry.ImageAssetId or "")
	local focalPoint = Vector2.new(tonumber(entry and entry.FocalPointX) or 0.5, tonumber(entry and entry.FocalPointY) or 0.5)
	self.Artwork.AnchorPoint = focalPoint
	self.Artwork.Position = UDim2.fromScale(0.5, 0.5)
	self.Artwork.Visible = self.Artwork.Image ~= ""
	self.GridComposite.AnchorPoint = focalPoint
	self.GridComposite.Position = UDim2.fromScale(0.5, 0.5)
	self.GridComposite.Visible = false
	self:_UpdateCompositeCover()

	local tiles = entry and entry.Tiles or {}
	local columns = math.max(1, tonumber(entry and entry.Columns) or 3)
	local rows = math.max(1, tonumber(entry and entry.Rows) or 2)
	self:_EnsureGridImages(#tiles)
	local overlap = math.clamp(tonumber(self.Config:GetAttribute("GridOverlapPixels")) or 1, 0, 4)
	for index, tile in ipairs(tiles) do
		local image = self.GridImages[index]
		image.Name = tostring(tile.Name or ("Tile%02d"):format(index))
		image.Image = tostring(tile.ImageAssetId or "")
		image.Position = UDim2.new((tile.Column - 1) / columns, -overlap, (tile.Row - 1) / rows, -overlap)
		image.Size = UDim2.new(1 / columns, overlap * 2, 1 / rows, overlap * 2)
		image.ImageTransparency = 0
	end

	if entry and entry.Layout == "Grid3x2" and entry.GridReady == true and #tiles == 6 then
		local targets = {}
		for index = 1, #tiles do table.insert(targets, self.GridImages[index]) end
		task.spawn(function()
			local attempts = math.clamp(math.floor(tonumber(self.Config:GetAttribute("GridPreloadAttempts")) or 2), 1, 4)
			local retryDelay = math.clamp(tonumber(self.Config:GetAttribute("GridPreloadRetrySeconds")) or 0.25, 0, 2)
			local fetched = false
			local lastFailures = {}
			for attempt = 1, attempts do
				local resolved = {}
				local ok, problem = pcall(function()
					ContentProvider:PreloadAsync(targets, function(contentId, fetchStatus)
						resolved[tostring(contentId)] = fetchStatus and fetchStatus.Name or "Unknown"
					end)
				end)
				lastFailures = failedTiles(tiles, resolved)
				if ok and #lastFailures == 0 then fetched = true; break end
				warn(("[Loading Grid] artwork=%s attempt=%d/%d preload=%s failures=%s"):format(
					tostring(entry.ArtworkId), attempt, attempts, ok and "completed" or tostring(problem), table.concat(lastFailures, ", ")))
				if attempt < attempts and retryDelay > 0 then task.wait(retryDelay) end
			end
			if generation ~= self.ArtworkGeneration or self.Fading then return end
			if not fetched then
				warn(("[Loading Grid] artwork=%s retained single fallback; unresolved tiles=%s"):format(tostring(entry.ArtworkId), table.concat(lastFailures, ", ")))
				return
			end

			-- Render the fetched grid behind the opaque single fallback first. This
			-- avoids the documented hidden-ImageLabel unload race before promotion.
			self.GridComposite.Visible = true
			local deadline = os.clock() + math.clamp(tonumber(self.Config:GetAttribute("GridPromotionWaitSeconds")) or 3, 0.25, 8)
			while generation == self.ArtworkGeneration and not self.Fading and os.clock() < deadline and not allLoaded(self.GridImages, #tiles) do
				RunService.RenderStepped:Wait()
			end
			if generation ~= self.ArtworkGeneration or self.Fading then return end
			if allLoaded(self.GridImages, #tiles) then
				self.Artwork.Visible = false
				print(("[Loading Grid] artwork=%s promoted Grid3x2 composite."):format(tostring(entry.ArtworkId)))
			else
				self.GridComposite.Visible = false
				local unresolved = {}
				for index, tile in ipairs(tiles) do
					if not self.GridImages[index].IsLoaded then table.insert(unresolved, tile.Name .. "=" .. fetchStatusName(tile.ImageAssetId)) end
				end
				warn(("[Loading Grid] artwork=%s retained single fallback after render deadline; unresolved=%s"):format(tostring(entry.ArtworkId), table.concat(unresolved, ", ")))
			end
		end)
	elseif entry and entry.Layout == "Grid3x2" then
		warn(("[Loading Grid] artwork=%s grid config incomplete; retaining single fallback."):format(tostring(entry.ArtworkId)))
	end
end

-- Classic 207-226, unchanged.
function View:Warm(entries, limit)
	limit = math.max(0, math.floor(tonumber(limit) or 0))
	if limit == 0 then return end
	task.spawn(function()
		for index = 1, math.min(limit, #(entries or {})) do
			local entry = entries[index]
			local temporary = {}
			local function add(imageAssetId)
				if tostring(imageAssetId or "") == "" then return end
				local image = Instance.new("ImageLabel")
				image.Image = tostring(imageAssetId)
				table.insert(temporary, image)
			end
			add(entry.ImageAssetId)
			if entry.GridReady then for _, tile in ipairs(entry.Tiles or {}) do add(tile.ImageAssetId) end end
			if #temporary > 0 then pcall(function() ContentProvider:PreloadAsync(temporary) end) end
			for _, image in ipairs(temporary) do image:Destroy() end
		end
	end)
end

-- Classic 228-246: the same resets; the roots are shown with Visible and the screen registers as Loading.
function View:Show(statusText)
	if self.ProgressTween then self.ProgressTween:Cancel(); self.ProgressTween = nil end
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	self.Fading = false
	self.Background.BackgroundTransparency = 0
	self.Artwork.ImageTransparency = 0
	for _, image in ipairs(self.GridImages) do image.ImageTransparency = 0 end
	self.Status.TextTransparency = 0
	self.Track.BackgroundTransparency = self.TrackTransparency
	self.Fill.BackgroundTransparency = 0
	self.Fill.Size = UDim2.fromScale(0, 1)
	self.Status.Text = tostring(statusText or "LOADING")
	local startScale = tonumber(self.Config:GetAttribute("MotionStartScale")) or 1.06
	self.ArtworkMotion.Position = UDim2.fromScale(0.5, 0.5)
	self.ArtworkMotion.Size = UDim2.fromScale(startScale, startScale)
	self.Relayout()
	self.SetShown(true)
	self.Blocker.Active = true
	if not self.ReleasePresence and self.Kit.Presence then
		self.ReleasePresence = self.Kit.Presence.Open(SURFACE, "Loading")
	end
end

function View:SetStatus(text)
	self.Status.Text = tostring(text or "LOADING")
end

function View:SetProgress(value, duration)
	value = math.clamp(tonumber(value) or 0, 0, 1)
	if self.ProgressTween then self.ProgressTween:Cancel() end
	self.ProgressTween = TweenService:Create(self.Fill, TweenInfo.new(math.max(0.03, tonumber(duration) or 0.18), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(value, 1) })
	self.ProgressTween:Play()
end

function View:SetProgressImmediate(value)
	value = math.clamp(tonumber(value) or 0, 0, 1)
	if self.ProgressTween then self.ProgressTween:Cancel(); self.ProgressTween = nil end
	self.Fill.Size = UDim2.fromScale(value, 1)
end

-- Classic 265-280, unchanged.
function View:StartMotion(enabled)
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	if not enabled or not self.Entry or self.Entry.MotionPreset == "None" then return end
	local startScale = tonumber(self.Config:GetAttribute("MotionStartScale")) or 1.06
	local endScale = tonumber(self.Config:GetAttribute("MotionEndScale")) or 1.10
	local travel = tonumber(self.Config:GetAttribute("MotionTravelPercent")) or 0.012
	local duration = tonumber(self.Config:GetAttribute("MotionDurationSeconds")) or 5
	local targetX, targetY = 0.5 + travel, 0.5
	if self.Entry.MotionPreset == "SlowPanLeft" then targetX = 0.5 - travel
	elseif self.Entry.MotionPreset == "SlowPanUp" then targetX, targetY = 0.5, 0.5 - travel
	elseif self.Entry.MotionPreset == "SlowPanDown" then targetX, targetY = 0.5, 0.5 + travel
	elseif self.Entry.MotionPreset == "SlowZoom" then targetX, targetY = 0.5, 0.5 end
	self.ArtworkMotion.Size = UDim2.fromScale(startScale, startScale)
	self.MotionTween = TweenService:Create(self.ArtworkMotion, TweenInfo.new(math.max(1, duration), Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, true), { Position = UDim2.fromScale(targetX, targetY), Size = UDim2.fromScale(endScale, endScale) })
	self.MotionTween:Play()
end

-- Classic 282-297. YIELDS until the fade ends, as the runtime expects.
function View:FadeOut(duration)
	duration = math.max(0.03, tonumber(duration) or 0.3)
	self.Fading = true
	if self.ProgressTween then self.ProgressTween:Cancel(); self.ProgressTween = nil end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweens = {
		TweenService:Create(self.Background, info, { BackgroundTransparency = 1 }),
		TweenService:Create(self.Artwork, info, { ImageTransparency = 1 }),
		TweenService:Create(self.Status, info, { TextTransparency = 1 }),
		TweenService:Create(self.Track, info, { BackgroundTransparency = 1 }),
		TweenService:Create(self.Fill, info, { BackgroundTransparency = 1 }),
	}
	for _, image in ipairs(self.GridImages) do table.insert(tweens, TweenService:Create(image, info, { ImageTransparency = 1 })) end
	for _, tween in ipairs(tweens) do tween:Play() end
	tweens[1].Completed:Wait()
end

-- Classic 299-305.
function View:Hide()
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	self.ArtworkGeneration += 1
	self.Blocker.Active = false
	self.SetShown(false)
	if self.ReleasePresence then
		self.ReleasePresence()
		self.ReleasePresence = nil
	end
end

function View:Destroy()
	for _, connection in ipairs(self.Connections or {}) do connection:Disconnect() end
	self.Connections = {}
	if self.ReleasePresence then
		self.ReleasePresence()
		self.ReleasePresence = nil
	end
	if self.Layer then
		self.Layer.Destroy()
		self.Layer = nil
	else
		for _, item in ipairs({ self.Background, self.Status, self.Track }) do
			if item then item:Destroy() end
		end
	end
end

return View
