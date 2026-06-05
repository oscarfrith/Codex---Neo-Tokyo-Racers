local ResponsiveLayout = {}

function ResponsiveLayout.ScaleForViewport(viewport, baseWidth, baseHeight, minScale, maxScale)
	baseWidth = baseWidth or 1600
	baseHeight = baseHeight or 900
	minScale = minScale or 0.68
	maxScale = maxScale or 1.02
	return math.clamp(math.min(viewport.X / baseWidth, viewport.Y / baseHeight), minScale, maxScale)
end

function ResponsiveLayout.BottomBands(viewport, scale, options)
	options = options or {}
	scale = math.max(scale or 1, 0.1)
	local vw = viewport.X / scale
	local vh = viewport.Y / scale
	local margin = options.Margin or 18
	local gap = options.Gap or 16
	local bottomHeight = options.BottomHeight or 108
	local leftWidth = options.LeftWidth or 190
	local rightWidth = options.RightWidth or 178

	local bottomY = vh - margin
	local left = {
		Size = UDim2.fromOffset(leftWidth, bottomHeight),
		Position = UDim2.fromOffset(margin, bottomY),
		AnchorPoint = Vector2.new(0, 1),
	}
	local right = {
		Size = UDim2.fromOffset(rightWidth, bottomHeight),
		Position = UDim2.fromOffset(vw - margin, bottomY),
		AnchorPoint = Vector2.new(1, 1),
	}
	local centerX = margin + leftWidth + gap
	local centerW = math.max(1, vw - margin - rightWidth - gap - centerX)
	local center = {
		Size = UDim2.fromOffset(centerW, bottomHeight),
		Position = UDim2.fromOffset(centerX, bottomY),
		AnchorPoint = Vector2.new(0, 1),
	}
	return left, center, right
end

return ResponsiveLayout
