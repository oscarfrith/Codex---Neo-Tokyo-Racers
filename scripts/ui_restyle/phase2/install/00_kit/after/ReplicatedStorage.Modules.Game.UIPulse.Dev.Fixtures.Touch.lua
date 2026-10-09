-- Owns the gallery fixtures for Kit.Touch (the look of the drive controls); it does not own the gallery, any input, any drive state or the controls' places on the screen.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Touch. Requires: Touch.
local Touch = require(script.Parent.Parent.Parent.Kit.Touch)

local function mount(parent, props, scope, _ctx)
	return Touch.Button(parent, props, scope)
end

-- Names are the Classic control names the touch fork passes. No state here presses anything: Pressed,
-- Disabled and Charge are canned looks.
local function states(control, name, mirrorName)
	local list = {
		{ Id = "Idle", Props = { Control = control, Name = name } },
		{ Id = "Pressed", Props = { Control = control, Name = name, Pressed = true } },
		{ Id = "Disabled", Props = { Control = control, Name = name, Disabled = true } },
	}
	if mirrorName ~= nil then
		table.insert(list, { Id = "MirrorIdle", Props = { Control = control, Name = mirrorName, Mirror = true } })
		table.insert(list, { Id = "MirrorPressed", Props = { Control = control, Name = mirrorName, Mirror = true, Pressed = true } })
		table.insert(list, { Id = "MirrorDisabled", Props = { Control = control, Name = mirrorName, Mirror = true, Disabled = true } })
	end
	return list
end

local accelerateItem = {
	Id = "Touch.Accelerate",
	Frame = "Bare",
	Slot = nil,
	Mount = mount,
	States = states("Accelerate", "Accelerator", nil),
}

local brakeItem = {
	Id = "Touch.Brake",
	Frame = "Bare",
	Slot = nil,
	Mount = mount,
	States = states("Brake", "Brake", nil),
}

local turnItem = {
	Id = "Touch.Turn",
	Frame = "Bare",
	Slot = nil,
	Mount = mount,
	States = states("Turn", "TurnLeft", "TurnRight"),
}

local driftItem = {
	Id = "Touch.Drift",
	Frame = "Bare",
	Slot = nil,
	Mount = mount,
	States = states("Drift", "DriftLeft", "DriftRight"),
}

local boostItem = {
	Id = "Touch.Boost",
	Frame = "Bare",
	Slot = nil,
	Mount = mount,
	States = {
		{ Id = "Empty", Props = { Control = "Boost", Name = "Boost", Charge = 0 } },
		{ Id = "Quarter", Props = { Control = "Boost", Name = "Boost", Charge = 0.25 } },
		{ Id = "Half", Props = { Control = "Boost", Name = "Boost", Charge = 0.5 } },
		{ Id = "MostlyCharged", Props = { Control = "Boost", Name = "Boost", Charge = 0.64 } },
		{ Id = "Full", Props = { Control = "Boost", Name = "Boost", Charge = 1 } },
		{ Id = "PressedDraining", Props = { Control = "Boost", Name = "Boost", Charge = 0.4, Pressed = true } },
		{ Id = "Disabled", Props = { Control = "Boost", Name = "Boost", Charge = 0.75, Disabled = true } },
		{ Id = "ImageButton", Props = { Control = "Boost", Name = "Boost", Class = "ImageButton", Charge = 0.5 } },
	},
}

return { accelerateItem, brakeItem, turnItem, driftItem, boostItem }
