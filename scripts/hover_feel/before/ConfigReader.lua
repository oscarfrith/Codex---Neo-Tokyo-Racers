local ConfigReader = {}

-- A present-but-invalid config value (wrong class, NaN/infinite, out of bounds) is a real authoring gap:
-- report it once per key instead of silently substituting. A missing optional value stays silent.
local reported = {}
local function report(owner, name, message)
	local key = (owner and owner:GetFullName() or "?") .. "." .. tostring(name) .. ":" .. message
	if reported[key] then return end
	reported[key] = true
	warn("[ConfigReader] " .. key)
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function bound(owner, name, value, minValue, maxValue)
	if minValue and value < minValue then
		report(owner, name, "below minimum " .. tostring(minValue) .. " (" .. tostring(value) .. "); clamped")
		value = minValue
	end
	if maxValue and value > maxValue then
		report(owner, name, "above maximum " .. tostring(maxValue) .. " (" .. tostring(value) .. "); clamped")
		value = maxValue
	end
	return value
end

function ConfigReader.Color(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("Color3Value") then
		return item.Value
	end
	if item then report(folder, name, "expected Color3Value, found " .. item.ClassName) end
	return fallback
end

function ConfigReader.Number(folder, name, fallback, minValue, maxValue)
	local item = folder and folder:FindFirstChild(name)
	local raw, fromItem = fallback, false
	if item and item:IsA("NumberValue") then
		if finite(item.Value) then
			raw, fromItem = item.Value, true
		else
			report(folder, name, "non-finite value; using fallback")
		end
	elseif item then
		report(folder, name, "expected NumberValue, found " .. item.ClassName)
	end
	local value = raw
	if minValue then value = math.max(minValue, value) end
	if maxValue then value = math.min(maxValue, value) end
	if fromItem and value ~= raw then
		report(folder, name, "outside [" .. tostring(minValue) .. ", " .. tostring(maxValue) .. "] (" .. tostring(raw) .. "); clamped")
	end
	return value
end

function ConfigReader.String(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("StringValue") then
		return item.Value
	end
	if item then report(folder, name, "expected StringValue, found " .. item.ClassName) end
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

-- Typed numeric attribute: wrong type or non-finite falls back (reported once); optional bounds clamp (reported).
function ConfigReader.NumberAttribute(instance, name, fallback, minValue, maxValue)
	local value = instance and instance:GetAttribute(name)
	if value == nil then return fallback end
	if not finite(value) then
		report(instance, name, "expected finite number attribute, found " .. typeof(value))
		return fallback
	end
	return bound(instance, name, value, minValue, maxValue)
end

function ConfigReader.BoolAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	if value == nil then return fallback end
	if type(value) ~= "boolean" then
		report(instance, name, "expected boolean attribute, found " .. typeof(value))
		return fallback
	end
	return value
end

ConfigReader.IsFinite = finite

return ConfigReader
