-- Pure tests for ReplicatedFirst.Loading.LoadingScreenViewPulse: the interface LoadingTransitionRuntime calls, the
-- names the start-screen flow reads, and the non-yielding methods on detached roots. Create (ScreenGuis) and FadeOut
-- (yields) are Play checks.
return function(M, env)
	local results = {}
	local KIT = "ReplicatedStorage.Modules.Game.UIPulse.Kit."

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function mount(spec)
		local opened, released = {}, 0
		local kit = {
			Tokens = env.Load(KIT .. "Tokens"), Metrics = env.Load(KIT .. "Metrics"), Layers = env.Load(KIT .. "Layers"),
			Text = env.Load(KIT .. "Text"),
			Presence = { Open = function(surface, kind)
				table.insert(opened, surface .. ":" .. kind)
				return function() released += 1 end
			end },
		}
		local ctx = kit.Metrics.Fixed(spec)
		local safeRoot = env.Detached("Frame")
		local backgroundRoot = env.Detached("Frame")
		local config = {}
		function config:GetAttribute(_name) return nil end
		local shown = {}
		local view = M._mount(kit, safeRoot, backgroundRoot, ctx, config, function(visible) table.insert(shown, visible) end)
		return view, safeRoot, backgroundRoot, shown, opened, function() return released end
	end

	case("interface parity: every method LoadingTransitionRuntime and Classic's view expose", function()
		-- Classic LoadingScreenView: Create 20, _UpdateCompositeCover 70, _EnsureGridImages 83, SetArtwork 126, Warm 207,
		-- Show 228, SetStatus 248, SetProgress 252, SetProgressImmediate 259, StartMotion 265, FadeOut 282, Hide 299, Destroy 307.
		for _, name in ipairs({ "Create", "_UpdateCompositeCover", "_EnsureGridImages", "SetArtwork", "Warm", "Show", "SetStatus",
			"SetProgress", "SetProgressImmediate", "StartMotion", "FadeOut", "Hide", "Destroy" }) do
			expect(type(M[name]) == "function", name .. " is a function")
		end
		expect(M.__index == M, "methods are reached through the metatable, as the runtime calls view:Method()")
	end)

	case("names: Status (TextLabel), ProgressTrack > ProgressFill (childless Frame), and Classic's artwork tree", function()
		local view, safeRoot, backgroundRoot = mount({ Size = Vector2.new(1920, 1080) })
		local status = safeRoot:FindFirstChild("Status")
		local track = safeRoot:FindFirstChild("ProgressTrack")
		expect(status ~= nil and status:IsA("TextLabel"), "Status is a TextLabel the start screen can write Text on")
		expect(track ~= nil and track:IsA("Frame"), "ProgressTrack")
		local fill = track:FindFirstChild("ProgressFill")
		expect(fill ~= nil and fill:IsA("Frame") and #fill:GetChildren() == 0, "ProgressFill is a childless Frame")
		local clone = fill:Clone()
		expect(clone.Size == fill.Size and clone.BackgroundColor3 == fill.BackgroundColor3, "it clones as the completion overlay")
		clone:Destroy()
		local backing = backgroundRoot:FindFirstChild("BlackBacking")
		expect(backing ~= nil and backing.Active == true, "BlackBacking")
		local clip = backing:FindFirstChild("ArtworkClip")
		local motion = clip and clip:FindFirstChild("ArtworkMotion")
		expect(motion ~= nil and motion:FindFirstChild("SingleArtwork") ~= nil and motion:FindFirstChild("GridArtwork") ~= nil, "artwork tree")
		local blocker = backing:FindFirstChild("InputBlocker")
		expect(blocker ~= nil and blocker:IsA("TextButton") and blocker.Modal == true, "InputBlocker")
		expect(view.Status == status and view.Track == track and view.Fill == fill, "fields")
		view:Destroy()
	end)

	case("show, status, progress, hide: Visible only, Presence once", function()
		local view, _, _, shown, opened, released = mount({ Size = Vector2.new(1920, 1080) })
		view:SetProgressImmediate(0.5)
		view:Show("LOADING PULSE RACERS")
		expect(#shown == 1 and shown[1] == true, "shown")
		expect(view.Status.Text == "LOADING PULSE RACERS", "status text")
		expect(view.Fill.Size.X.Scale == 0 and view.Fill.Size.Y.Scale == 1, "bar reset")
		expect(view.Blocker.Active == true, "input blocked")
		expect(view.Status.TextTransparency == 0 and view.Fill.BackgroundTransparency == 0, "opaque")
		view:Show(nil)
		expect(view.Status.Text == "LOADING", "default status")
		expect(#opened == 1 and opened[1] == "Loading:Loading", "one Presence entry")
		view:SetStatus("LOADING WORLD")
		expect(view.Status.Text == "LOADING WORLD", "SetStatus")
		view:SetStatus(nil)
		expect(view.Status.Text == "LOADING", "SetStatus default")
		view:SetProgressImmediate(0.25)
		expect(view.Fill.Size.X.Scale == 0.25, "X scale is the progress")
		view:SetProgressImmediate(7)
		expect(view.Fill.Size.X.Scale == 1, "clamped high")
		view:SetProgressImmediate("x")
		expect(view.Fill.Size.X.Scale == 0, "clamped low")
		view:StartMotion(false)
		view:StartMotion(true)
		expect(view.MotionTween == nil, "no motion without an artwork entry")
		view:Hide()
		expect(shown[#shown] == false and view.Blocker.Active == false and released() == 1, "hidden, unblocked, released")
		view:Hide()
		expect(released() == 1, "released once")
		view:Destroy()
	end)

	case("artwork: entry fields are applied as Classic applies them; nil clears", function()
		local view = mount({ Size = Vector2.new(1920, 1080) })
		view:SetArtwork({ ArtworkId = "Test", ImageAssetId = "", FocalPointX = 0.25, FocalPointY = 0.75, MotionPreset = "None" })
		expect(view.Artwork.AnchorPoint == Vector2.new(0.25, 0.75), "focal point")
		expect(view.Artwork.Visible == false and view.GridComposite.Visible == false, "no image, no grid")
		expect(view.Entry ~= nil and view.ArtworkGeneration == 1, "entry kept")
		view:SetArtwork(nil)
		expect(view.Artwork.Image == "" and view.Artwork.AnchorPoint == Vector2.new(0.5, 0.5) and view.ArtworkGeneration == 2, "cleared")
		view:_EnsureGridImages(2)
		expect(#view.GridImages == 2 and view.GridImages[2].Visible == true, "grid pool")
		view:_EnsureGridImages(1)
		expect(#view.GridImages == 2 and view.GridImages[2].Visible == false, "pool kept, extra hidden")
		view:Destroy()
	end)

	case("layout: Regular bar centred at Classic's height; Compact bar on the bottom margin", function()
		local Tokens = env.Load(KIT .. "Tokens")
		local view = mount({ Size = Vector2.new(1920, 1080) })
		local width = Tokens.Space.ToastMaxWidth
		expect(view.Track.Size.X.Offset == width and view.Track.Size.Y.Offset == Tokens.Space.SegmentHeight, "bar size")
		expect(view.Track.Position.X.Offset == math.floor((1920 - width) / 2), "centred")
		expect(view.Track.Position.Y.Offset == math.floor(1080 * 0.81), "81% down")
		expect(view.Status.Position.Y.Offset + view.Status.Size.Y.Offset < view.Track.Position.Y.Offset, "status above the bar")
		expect(view.Status.TextXAlignment == Enum.TextXAlignment.Center, "centred text")
		view:Destroy()

		local compact = mount({ Size = Vector2.new(844, 390), TouchEnabled = true, Input = "Touch" })
		local margin = Tokens.Space.CompactMargin
		expect(compact.Track.Position.X.Offset == margin and compact.Track.Size.X.Offset == 844 - margin * 2, "full width")
		expect(compact.Track.Position.Y.Offset + compact.Track.Size.Y.Offset == 390 - Tokens.Space.CompactBottom, "on the bottom margin")
		expect(compact.Status.TextXAlignment == Enum.TextXAlignment.Left, "left text")
		compact:Destroy()
	end)

	case("destroy: leaves both roots empty and is repeat-safe", function()
		local view, safeRoot, backgroundRoot = mount({ Size = Vector2.new(1920, 1080) })
		view:Show("X")
		view:Destroy()
		view:Destroy()
		expect(#safeRoot:GetChildren() == 0 and #backgroundRoot:GetChildren() == 0, "empty")
	end)

	return results
end
