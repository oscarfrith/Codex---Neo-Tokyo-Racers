local ColourUtils = {}

function ColourUtils.ToHSV(color)
	local h, s, v = color:ToHSV()
	return h, s, v
end

function ColourUtils.FromHSV(h, s, v)
	return Color3.fromHSV(math.clamp(h or 0, 0, 1), math.clamp(s or 0, 0, 1), math.clamp(v or 0, 0, 1))
end

function ColourUtils.Sequence(color)
	return ColorSequence.new(color)
end

function ColourUtils.Lerp(a, b, alpha)
	return a:Lerp(b, math.clamp(alpha or 0, 0, 1))
end

return ColourUtils
