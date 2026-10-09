-- Owns the gallery item for Kit.Minimap, with placeholder roads in its content; no map, game state, remote, profile or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Minimap. Requires: Tokens, Metrics, Minimap (resolved on the first mount).

local kitCache
local function kit()
	if not kitCache then
		local folder = script.Parent.Parent.Parent.Kit
		kitCache = {
			Tokens = require(folder.Tokens),
			Metrics = require(folder.Metrics),
			Minimap = require(folder.Minimap),
		}
	end
	return kitCache
end

local MINIMAP_FIXTURE_KEYS = { Rank = true, Fraction = true, Label = true, Heading = true, Arrow = true,
	Round = true, ShowRank = true, SizeKey = true, Roads = true }

-- Placeholder roads: where each bar crosses the content (fractions of it) and how far it is turned.
local ROADS = {
	{ X = 0.5, Y = 0.35, Turn = 25 },
	{ X = 0.6, Y = 0.5, Turn = -62 },
	{ X = 0.5, Y = 0.72, Turn = 0 },
	{ X = 0.62, Y = 0.5, Turn = 90 },
}

local function checkKeys(patch)
	assert(type(patch) == "table", "Minimap fixture expects a table")
	for key in pairs(patch) do
		if not MINIMAP_FIXTURE_KEYS[key] then error(string.format("Minimap fixture: unknown key '%s'", tostring(key)), 3) end
	end
end

-- Something to clip: a slate ground and a few bars that run past the edge of the round area.
local function buildRoads(k, content, ctx)
	local ground = Instance.new("Frame")
	ground.Name = "Ground"
	ground.BackgroundColor3 = k.Tokens.Colour.Slate
	ground.BorderSizePixel = 0
	ground.Size = UDim2.fromScale(1, 1)
	ground.Parent = content
	for index, road in ipairs(ROADS) do
		local bar = Instance.new("Frame")
		bar.Name = "Road" .. index
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BackgroundColor3 = k.Tokens.Colour.TextMuted
		bar.BackgroundTransparency = 1 - k.Tokens.Opacity.Locked
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromScale(road.X, road.Y)
		bar.Rotation = road.Turn
		bar.Size = UDim2.new(2, 0, 0, ctx.Px(k.Tokens.Space.Pad))
		bar.ZIndex = 2
		bar.Parent = content
	end
end

local function mountMinimap(parent, props, scope, ctx)
	local k = kit()
	checkKeys(props)
	ctx = ctx or k.Metrics.Of(parent)
	local current = {}
	for key, value in pairs(props) do current[key] = value end

	local size = nil
	if current.SizeKey then
		size = k.Tokens.Space[current.SizeKey]
		assert(type(size) == "number", "Minimap fixture: unknown SizeKey " .. tostring(current.SizeKey))
	end
	local clicks = 0
	local minimap
	minimap = k.Minimap.New(parent, {
		Size = size,
		Round = current.Round,
		ShowRank = current.ShowRank,
		Label = current.Label,
		-- The count lets a probe see that a click on the frame arrives once.
		OnActivated = function()
			clicks += 1
			minimap.Instance:SetAttribute("MinimapClicks", clicks)
		end,
	}, scope)
	minimap.Instance:SetAttribute("MinimapClicks", 0)
	if current.Roads ~= false then buildRoads(k, minimap.Content, ctx) end

	local function apply()
		minimap.SetRank(current.Rank or 0, current.Fraction or 0)
		minimap.SetHeading(current.Heading or 0)
		minimap.SetArrow(current.Arrow or 0)
	end
	apply()

	local destroyed = false
	local component = { Instance = minimap.Instance }
	function component.Set(patch)
		checkKeys(patch)
		for key, value in pairs(patch) do current[key] = value end
		if patch.Label ~= nil then minimap.SetLabel(patch.Label) end
		if patch.Round ~= nil then minimap.SetRound(patch.Round) end
		if patch.ShowRank ~= nil then minimap.Set({ ShowRank = patch.ShowRank }) end
		apply()
	end
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		minimap.Destroy()
	end
	scope:add(component.Destroy)
	return component
end

return {
	{
		Id = "Minimap.Minimap",
		Frame = "Hud",
		Slot = "Minimap",
		States = {
			{ Id = "Default", Props = { Rank = 6, Fraction = 0.42, Label = "Akane District", Heading = 180, Arrow = -20 } },
			{ Id = "RankEmpty", Props = { Rank = 1, Fraction = 0, Label = "Akane District" } },
			{ Id = "RankFull", Props = { Rank = 6, Fraction = 1, Label = "Akane District", Heading = 90, Arrow = 45 } },
			{ Id = "RankHundreds", Props = { Rank = 128, Fraction = 0.75, Label = "Akane District" } },
			{ Id = "LongLabel", Props = { Rank = 6, Fraction = 0.42, Heading = 270,
				Label = "Shifted canal sprint district, north entrance" } },
			{ Id = "NoLabel", Props = { Rank = 6, Fraction = 0.42 } },
			{ Id = "NoRank", Props = { ShowRank = false, Label = "Akane District" } },
			{ Id = "Square", Props = { Rank = 6, Fraction = 0.42, Round = false, Label = "Akane District" } },
			{ Id = "Empty", Props = { Rank = 6, Fraction = 0.42, Roads = false, Label = "Akane District" } },
		},
		Mount = mountMinimap,
	},
}
