-- Pure tests for Garage.GarageInteriorHud: the option lists and the rule that keeps an open list open. Start() is
-- never called here (it waits for remotes, creates the layer and starts the touch camera guard): a Play check.
return function(M, _env)
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

	local function state(invited)
		return {
			Success = true,
			AccessMode = "Private",
			AccessModes = { "Private", "FriendsOnly", "Public" },
			InvitationRows = { { UserId = 11, DisplayName = "Aki", Invited = invited }, { UserId = 12, DisplayName = "Ren", Invited = false } },
		}
	end

	case("options: access modes and invitation rows; the row keeps the server's own value", function()
		local options, rows = M._accessOptions(state(false))
		expect(#options == 3 and options[2].Id == "FriendsOnly" and options[2].Text == "FRIENDS ONLY", "mode text")
		expect(rows.FriendsOnly.Id == "FriendsOnly", "mode row")
		local invites, inviteRows = M._inviteOptions(state(true))
		expect(#invites == 2 and invites[1].Text == "Aki - REVOKE" and invites[2].Text == "Ren - INVITE", "what a press does")
		expect(inviteRows["11"].Id == 11 and inviteRows["11"].Invited == true and M._inviteCount(state(true)) == 1, "row and count")
		local none = M._inviteOptions({ InvitationRows = {} })
		expect(#none == 1 and none[1].Text == "NO OTHER PLAYERS", "no other players")
	end)

	case("options key: an unchanged list has the same key, so a refresh does not close an open list", function()
		local first = M._optionsKey((M._inviteOptions(state(false))))
		local again = M._optionsKey((M._inviteOptions(state(false))))
		expect(first == again and first ~= "", "the same reply twice: the same key")
		expect(M._optionsKey((M._inviteOptions(state(true)))) ~= first, "an invitation changes a row text, and the key")
		expect(M._optionsKey((M._accessOptions(state(false)))) == M._optionsKey((M._accessOptions(state(true)))), "access modes did not change")
		expect(M._optionsKey({}) == "" and M._optionsKey(nil) == "", "no options")
		expect(M._optionsKey({ { Id = "a", Text = "b=c" } }) ~= M._optionsKey({ { Id = "a=b", Text = "c" }, { Id = "x", Text = "y" } }), "different lists differ")
	end)

	case("visible: owner inside, desk closed, no major touch menu, not a visitor", function()
		expect(M._visible(true, false, false, nil) == true, "shown")
		expect(M._visible(true, true, false, nil) == false and M._visible(true, false, true, nil) == false, "desk or menu open")
		expect(M._visible(false, false, false, nil) == false and M._visible(true, false, false, true) == false, "outside, or a visitor")
	end)

	return results
end
