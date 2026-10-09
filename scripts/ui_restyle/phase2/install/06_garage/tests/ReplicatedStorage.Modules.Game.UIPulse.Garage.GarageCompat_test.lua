-- Pure tests for Garage.GarageCompat: the Classic asset helper. ProjectEconomy and ConfirmationModal pass straight
-- to Kit.Data and Kit.Overlay (tested there); Notify fires a bindable and is a Play check.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("shape: the four functions the desk fork and the desk view call", function()
		for _, name in ipairs({ "ProjectEconomy", "ConfirmationModal", "Asset", "Notify" }) do
			expect(type(M[name]) == "function", name)
		end
	end)

	case("asset: nil and empty give an empty string", function()
		expect(M.Asset(nil) == "" and M.Asset("") == "", "empty")
	end)

	case("asset: a bare number, as a number or as text, becomes an asset id", function()
		expect(M.Asset(12345) == "rbxassetid://12345", "number")
		expect(M.Asset("12345") == "rbxassetid://12345", "numeric text")
	end)

	case("asset: asset and thumbnail urls and any other text pass through", function()
		expect(M.Asset("rbxassetid://77") == "rbxassetid://77", "asset url")
		expect(M.Asset("rbxthumb://type=Asset&id=77&w=150&h=150") == "rbxthumb://type=Asset&id=77&w=150&h=150", "thumb url")
		expect(M.Asset("plus") == "plus", "other text")
	end)

	return results
end
