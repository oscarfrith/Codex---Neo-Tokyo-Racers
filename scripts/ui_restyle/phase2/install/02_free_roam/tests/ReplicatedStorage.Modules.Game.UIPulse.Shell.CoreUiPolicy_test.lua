-- Pure tests for Shell.CoreUiPolicy: the decision rules and the policy object over fake services. start() claims a
-- surface and writes real core UI state, which is a Play check.
return function(M, _env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end
	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local function harness(options)
		options = options or {}
		local h = { Open = {}, Sets = {}, Core = { Chat = options.ChatOff ~= true }, AutoSelect = true, Warnings = {} }
		h.Presence = { Any = function(kind) return (h.Open[kind] or 0) > 0 end }
		h.Policy = M._new({
			Presence = h.Presence,
			SetCore = function(name, enabled)
				if options.Refuse == name then error("refused") end
				table.insert(h.Sets, name .. "=" .. tostring(enabled))
				h.Core[name] = enabled
			end,
			GetCore = function(name) return h.Core[name] end,
			SetAutoSelect = function(enabled) h.AutoSelect = enabled end,
			Warn = function(text) table.insert(h.Warnings, text) end,
		})
		function h.Count(text)
			local count = 0
			for _, entry in ipairs(h.Sets) do
				if entry == text then count += 1 end
			end
			return count
		end
		return h
	end

	case("_blocking: every kind except Race hides chat", function()
		for _, kind in ipairs({ "FullMenu", "Garage", "Results", "Map", "Modal", "SidePanel", "Loading" }) do
			expect(M._blocking({ Any = function(asked) return asked == kind end }) == true, kind .. " blocks")
		end
		expect(M._blocking({ Any = function(asked) return asked == "Race" end }) == false, "Race does not block")
		expect(M._blocking({ Any = function() return false end }) == false, "nothing open")
	end)

	case("_chatWanted: only when chat was on and nothing blocks", function()
		expect(M._chatWanted(true, false) == true, "on")
		expect(M._chatWanted(true, true) == false, "blocked")
		expect(M._chatWanted(false, false) == false, "never turned on by the policy")
	end)

	case("Start: player list, health and backpack off, auto-select off, chat untouched", function()
		local h = harness()
		h.Policy.Start()
		expect(h.Core.PlayerList == false and h.Core.Health == false and h.Core.Backpack == false, "three off")
		expect(h.AutoSelect == false, "auto-select off")
		expect(h.Count("Chat=true") == 0 and h.Count("Chat=false") == 0, "no chat write at start")
		expect(#h.Warnings == 0, "no warning")
	end)

	case("chat: hidden once while a menu is open, restored once after the last one closes", function()
		local h = harness()
		h.Policy.Start()
		h.Open.FullMenu = 1
		h.Policy.OnPresenceChanged()
		h.Open.Modal = 1
		h.Policy.OnPresenceChanged()
		expect(h.Core.Chat == false and h.Count("Chat=false") == 1, "hidden with one write")
		h.Open.Modal = 0
		h.Policy.OnPresenceChanged()
		expect(h.Core.Chat == false, "still hidden under the menu")
		h.Open.FullMenu = 0
		h.Policy.OnPresenceChanged()
		expect(h.Core.Chat == true and h.Count("Chat=true") == 1, "restored with one write")
	end)

	case("chat: stays through a race; a menu already open at start hides it", function()
		local h = harness()
		h.Policy.Start()
		h.Open.Race = 1
		h.Policy.OnPresenceChanged()
		expect(h.Core.Chat == true and h.Count("Chat=false") == 0, "kept in a race")
		local late = harness()
		late.Open.Garage = 1
		late.Policy.Start()
		expect(late.Core.Chat == false, "hidden at start")
	end)

	case("chat: never enabled if the game had it off", function()
		local h = harness({ ChatOff = true })
		h.Policy.Start()
		h.Open.Map = 1
		h.Policy.OnPresenceChanged()
		h.Open.Map = 0
		h.Policy.OnPresenceChanged()
		expect(h.Core.Chat == false and h.Count("Chat=true") == 0, "left off")
	end)

	case("the three off elements are asserted again on a presence change (trailer tool exception)", function()
		local h = harness()
		h.Policy.Start()
		h.Core.PlayerList = true -- something outside turned it back on
		h.Open.Map = 1
		h.Policy.OnPresenceChanged()
		expect(h.Core.PlayerList == false, "repaired")
	end)

	case("a refused engine call warns once and never throws", function()
		local h = harness({ Refuse = "Backpack" })
		h.Policy.Start()
		h.Policy.OnPresenceChanged()
		h.Policy.OnPresenceChanged()
		expect(#h.Warnings == 1, "one warning, got " .. #h.Warnings)
		expect(h.Core.PlayerList == false and h.Core.Health == false, "the others still applied")
		local chat = harness({ Refuse = "Chat" })
		chat.Policy.Start()
		chat.Open.Map = 1
		chat.Policy.OnPresenceChanged()
		expect(chat.Policy.ChatShown == true, "a refused chat write is not recorded as done")
	end)

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M.start) == "function" and M.Controller == nil, "owner shape")
	end)

	return results
end
