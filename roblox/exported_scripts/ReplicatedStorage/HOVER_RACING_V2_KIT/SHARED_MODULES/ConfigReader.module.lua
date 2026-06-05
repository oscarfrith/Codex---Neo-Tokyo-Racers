local ConfigReader = {}

function ConfigReader.Color(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("Color3Value") then
		return item.Value
	end
	return fallback
end

function ConfigReader.Number(folder, name, fallback, minValue, maxValue)
	local item = folder and folder:FindFirstChild(name)
	local value = item and item:IsA("NumberValue") and item.Value or fallback
	if minValue then value = math.max(minValue, value) end
	if maxValue then value = math.min(maxValue, value) end
	return value
end

function ConfigReader.String(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("StringValue") then
		return item.Value
	end
	return fallback
end

function ConfigReader.Attribute(instance, name, fallback)
	if not instance then
		return fallback
	end
	local value = instance:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

return ConfigReader
