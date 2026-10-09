-- Owns the three functions the desk fork (Garage.OwnedGarageWorkspaceUI) asked its two Classic component tables for: ProjectEconomy, ConfirmationModal and Asset; not any look, state, remote or Cash arithmetic.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageCompat. Requires: Kit.Data, Kit.Overlay.
local kit = script.Parent.Parent.Kit
local Data = require(kit.Data)
local Overlay = require(kit.Overlay)

local Compat = {}
local warnedConfirm = false

-- The Classic projection, unchanged (API2 3.5): {Cash, Used, Capacity} from a server reply. It may yield once, on the
-- first call of the session; the desk fork calls it only after its own remote call has returned.
function Compat.ProjectEconomy(response, fallback)
	return Data.ProjectEconomy(response, fallback)
end

-- The desk fork calls `modal:Destroy()` on what this returns (Classic line 34) and sets its own `modal` to nil in
-- OnConfirm and OnCancel. Overlay.Confirm keeps the Classic behaviour list (API1 7.5); Destroy closes it as a cancel.
function Compat.ConfirmationModal(root, options)
	local ok, handle = pcall(Overlay.Confirm, root, options)
	if not ok or type(handle) ~= "table" then
		if not warnedConfirm then
			warnedConfirm = true
			warn("[Pulse.GarageCompat] confirmation could not open; nothing was confirmed: " .. tostring(handle))
		end
		-- Neither callback runs: an unanswered confirmation never moves a vehicle.
		return { Destroy = function() end }
	end
	local object = { Root = handle.Root, Cancel = handle.Cancel, Confirm = handle.Confirm, Relayout = handle.Relayout }
	function object:Destroy()
		handle.Cancel()
	end
	return object
end

-- The Classic asset helper (racing components, lines 36-42), copied: a bare number becomes an asset id; anything else passes through.
function Compat.Asset(value)
	local text = tostring(value or "")
	if text == "" then
		return ""
	end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then
		return text
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end

return Compat
