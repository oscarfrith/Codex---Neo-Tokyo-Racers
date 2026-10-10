-- Owns the radio strip of the free-roam HUD: previous, the track name, next; no playback, remote, attribute or bindable.
-- Pulse UI (radio). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.RadioStripView. Requires: Kit.Controls, Kit.Text (resolved on the first mount).
--
-- Mounted by HudView on the static layer's BottomCentre slot, lifted clear of what the arrangement puts at the bottom
-- centre (the HUD buttons, or the gauge on TouchDrive). The radio is Audio.RadioClient; this view only calls
-- Next / Previous and redraws the name on Changed.

-- Design px (Regular) and dp (Compact). Page-specific: the strip is the only user of a fixed-width track name.
local TITLE_WIDTH = 320
local COMPACT_TITLE_WIDTH = 150

local RadioStripView = {}

local modulesCache
local function modules()
	if not modulesCache then
		local folder = script.Parent.Parent.Kit
		modulesCache = {
			Controls = require(folder.Controls),
			Text = require(folder.Text),
		}
	end
	return modulesCache
end
function RadioStripView._setModules(replacement) modulesCache = replacement end

-- Pure: whole-pixel strip geometry. Returns the strip width, the x of the next button and the title centre.
function RadioStripView._layout(buttonWidth, titleWidth, gap)
	local width = buttonWidth + gap + titleWidth + gap + buttonWidth
	return width, width - buttonWidth, math.floor(width * 0.5)
end

-- slot: the BottomCentre slot. radio: Audio.RadioClient. options = { Px, Gap, Lift, Compact, Touch }.
function RadioStripView.Mount(slot, radio, scope, options)
	local k = modules()
	local px = options.Px
	local compact = options.Compact == true
	-- A finger needs the larger tile; a mouse takes the small one.
	local buttonSize = (compact or options.Touch == true) and "Action" or "Small"
	local designWidth, designHeight = k.Controls._iconButtonSize(compact, buttonSize)
	local buttonWidth, height = px(designWidth), px(designHeight)
	local titleDesign = compact and COMPACT_TITLE_WIDTH or TITLE_WIDTH
	local width, nextX, centre = RadioStripView._layout(buttonWidth, px(titleDesign), options.Gap)

	local root = Instance.new("Frame")
	root.Name = "Radio"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.fromOffset(0, -options.Lift)
	root.Visible = false
	root.Parent = slot

	local previous = k.Controls.IconButton(root, { Name = "RadioPrevious", Icon = "chevron_left", Size = buttonSize,
		OnActivated = function() radio.Previous() end }, scope)
	local following = k.Controls.IconButton(root, { Name = "RadioNext", Icon = "chevron_right", Size = buttonSize,
		OnActivated = function() radio.Next() end }, scope)
	-- The strip is laid out with the buttons' real boxes: on touch a button is a hit box larger than its drawn tile.
	buttonWidth = math.max(buttonWidth, previous.Instance.Size.X.Offset)
	height = math.max(height, previous.Instance.Size.Y.Offset)
	width, nextX, centre = RadioStripView._layout(buttonWidth, px(titleDesign), options.Gap)
	root.Size = UDim2.fromOffset(width, height)
	previous.Instance.AnchorPoint = Vector2.new(0, 0)
	previous.Instance.Position = UDim2.fromOffset(0, 0)
	following.Instance.AnchorPoint = Vector2.new(0, 0)
	following.Instance.Position = UDim2.fromOffset(nextX, 0)

	local title = k.Text.Label(root, { Name = "Track", Text = radio.State().Title, Role = "Label", Colour = "White",
		Align = "Centre", MaxWidth = titleDesign, Upper = true, Shadow = true }, scope)
	title.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Instance.Position = UDim2.fromOffset(centre, math.floor(height * 0.5))

	local shownTitle = radio.State().Title
	scope:connect(radio.Changed, function(state)
		if type(state) == "table" and state.Title ~= shownTitle then
			shownTitle = state.Title
			title.Set({ Text = shownTitle })
		end
	end)

	local self = { Instance = root }

	function self.Set(patch)
		if patch.Visible ~= nil and root.Visible ~= patch.Visible then root.Visible = patch.Visible end
	end

	function self.Destroy()
		previous.Destroy()
		following.Destroy()
		title.Destroy()
		root:Destroy()
	end

	return self
end

return RadioStripView
