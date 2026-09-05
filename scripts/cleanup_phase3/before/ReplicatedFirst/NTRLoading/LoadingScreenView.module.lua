-- NTR_LOADING_SYSTEM_PHASE1_SCREEN_VIEW_V1_4_GRID_FETCH_STATUS
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local View = {}
View.__index = View

local function new(className, properties, parent)
	local item = Instance.new(className)
	for key, value in pairs(properties or {}) do item[key] = value end
	item.Parent = parent
	return item
end

local function color(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("Color3Value") and item.Value or fallback
end

function View.Create(playerGui, config, colours)
	local self = setmetatable({}, View)
	self.Config = config
	self.Tweens = {}
	self.MotionTween = nil
	self.ProgressTween = nil
	self.GridImages = {}
	self.ArtworkGeneration = 0
	self.Fading = false

	local displayOrder = tonumber(config:GetAttribute("DisplayOrder")) or 1000
	local backgroundGui = new("ScreenGui", { Name = "NTR_LoadingBackground", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = displayOrder, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false }, playerGui)
	pcall(function() backgroundGui.ScreenInsets = Enum.ScreenInsets.None end)
	local background = new("Frame", { Name = "BlackBacking", Active = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, backgroundGui)
	local artworkClip = new("Frame", { Name = "ArtworkClip", Active = false, BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, background)
	local artworkMotion = new("Frame", { Name = "ArtworkMotion", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.08, 1.08), ZIndex = 2 }, artworkClip)
	local artwork = new("ImageLabel", { Name = "SingleArtwork", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Image = "", ImageTransparency = 0, Position = UDim2.fromScale(0.5, 0.5), ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, artworkMotion)
	local gridComposite = new("Frame", { Name = "GridArtwork", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3 }, artworkMotion)
	local blocker = new("TextButton", { Name = "InputBlocker", Active = true, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Modal = true, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 10 }, background)

	local safeGui = new("ScreenGui", { Name = "NTR_LoadingSafeContent", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = displayOrder + 1, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false }, playerGui)
	pcall(function() safeGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
	local safeRoot = new("Frame", { Name = "SafeRoot", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 20 }, safeGui)
	local status = new("TextLabel", { Name = "Status", AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.Michroma, Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.new(0.72, 0, 0, 34), Text = "LOADING", TextColor3 = color(colours, "Text", Color3.fromRGB(246, 248, 252)), TextSize = 15, TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22 }, safeRoot)
	local statusConstraint = new("UISizeConstraint", { MinSize = Vector2.new(220, 34), MaxSize = Vector2.new(820, 34) }, status)
	statusConstraint.Name = "StatusWidthConstraint"
	local track = new("Frame", { Name = "ProgressTrack", AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = color(colours, "PanelSoft", Color3.fromRGB(24, 29, 36)), BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = true, Position = UDim2.fromScale(0.5, 0.81), Size = UDim2.new(0.58, 0, 0, 22), ZIndex = 22 }, safeRoot)
	new("UISizeConstraint", { MinSize = Vector2.new(220, 22), MaxSize = Vector2.new(720, 22) }, track)
	new("UICorner", { CornerRadius = UDim.new(0, 9) }, track)
	local fill = new("Frame", { Name = "ProgressFill", BackgroundColor3 = color(colours, "Telemetry", Color3.fromRGB(43, 225, 218)), BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 23 }, track)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, fill)
	new("UIGradient", { Color = ColorSequence.new(color(colours, "ElectricBlue", Color3.fromRGB(25, 116, 255)), color(colours, "Telemetry", Color3.fromRGB(43, 225, 218))), Rotation = 0 }, fill)

	self.BackgroundGui = backgroundGui
	self.SafeGui = safeGui
	self.Background = background
	self.ArtworkClip = artworkClip
	self.ArtworkMotion = artworkMotion
	self.Artwork = artwork
	self.GridComposite = gridComposite
	self.Blocker = blocker
	self.Status = status
	self.Track = track
	self.Fill = fill
	self.SizeConnection = artworkClip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_UpdateCompositeCover()
	end)
	return self
end

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
				warn(("[NTR Loading Grid] artwork=%s attempt=%d/%d preload=%s failures=%s"):format(
					tostring(entry.ArtworkId), attempt, attempts, ok and "completed" or tostring(problem), table.concat(lastFailures, ", ")))
				if attempt < attempts and retryDelay > 0 then task.wait(retryDelay) end
			end
			if generation ~= self.ArtworkGeneration or self.Fading then return end
			if not fetched then
				warn(("[NTR Loading Grid] artwork=%s retained single fallback; unresolved tiles=%s"):format(tostring(entry.ArtworkId), table.concat(lastFailures, ", ")))
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
				print(("[NTR Loading Grid] artwork=%s promoted Grid3x2 composite."):format(tostring(entry.ArtworkId)))
			else
				self.GridComposite.Visible = false
				local unresolved = {}
				for index, tile in ipairs(tiles) do
					if not self.GridImages[index].IsLoaded then table.insert(unresolved, tile.Name .. "=" .. fetchStatusName(tile.ImageAssetId)) end
				end
				warn(("[NTR Loading Grid] artwork=%s retained single fallback after render deadline; unresolved=%s"):format(tostring(entry.ArtworkId), table.concat(unresolved, ", ")))
			end
		end)
	elseif entry and entry.Layout == "Grid3x2" then
		warn(("[NTR Loading Grid] artwork=%s grid config incomplete; retaining single fallback."):format(tostring(entry.ArtworkId)))
	end
end

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

function View:Show(statusText)
	if self.ProgressTween then self.ProgressTween:Cancel(); self.ProgressTween = nil end
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	self.Fading = false
	self.Background.BackgroundTransparency = 0
	self.Artwork.ImageTransparency = 0
	for _, image in ipairs(self.GridImages) do image.ImageTransparency = 0 end
	self.Status.TextTransparency = 0
	self.Track.BackgroundTransparency = 0
	self.Fill.BackgroundTransparency = 0
	self.Fill.Size = UDim2.fromScale(0, 1)
	self.Status.Text = tostring(statusText or "LOADING")
	local startScale = tonumber(self.Config:GetAttribute("MotionStartScale")) or 1.06
	self.ArtworkMotion.Position = UDim2.fromScale(0.5, 0.5)
	self.ArtworkMotion.Size = UDim2.fromScale(startScale, startScale)
	self.BackgroundGui.Enabled = true
	self.SafeGui.Enabled = true
	self.Blocker.Active = true
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

function View:Hide()
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	self.ArtworkGeneration += 1
	self.Blocker.Active = false
	self.BackgroundGui.Enabled = false
	self.SafeGui.Enabled = false
end

function View:Destroy()
	if self.SizeConnection then self.SizeConnection:Disconnect(); self.SizeConnection = nil end
	if self.BackgroundGui then self.BackgroundGui:Destroy() end
	if self.SafeGui then self.SafeGui:Destroy() end
end

return View
