-- Courier client view (map-markers-contract "World jobs"). Mounted by ActivityClient; presentation only.
-- Registers the Courier kind with the shared JobClient (offer markers, "Pick up parcel" prompt, strip,
-- route, CourierDrop marker, JOBS entry), builds the client-only parcel crate at streamed-in pickups and
-- forwards Courier:* events. No modes, hubs or chains.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local activities = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Activities")
local JobClient = require(activities:WaitForChild("JobClient"))
local JobRules = require(activities:WaitForChild("JobRules"))

local KIND = "Courier"
local View = {}

-- A small parcel stack on the pavement (client-only, non-colliding), children of the prompt anchor.
local function buildParcel(entry, anchor, ctx)
	local function box(name, size, offset, material, colour)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = size
		part.Material = material
		part.Color = colour
		part.CFrame = CFrame.new(entry.Position + offset)
		part.Parent = anchor
		return part
	end
	local cardboard = Color3.fromRGB(176, 128, 80) -- world prop colour, not a UI colour
	box("Parcel", Vector3.new(3.4, 2.4, 3.4), Vector3.new(0, 1.2, 0), Enum.Material.Cardboard, cardboard)
	box("ParcelTop", Vector3.new(2.2, 1.6, 2.2), Vector3.new(0.3, 3.2, -0.2), Enum.Material.Cardboard, cardboard)
	box("Band", Vector3.new(3.5, 0.35, 3.5), Vector3.new(0, 1.6, 0), Enum.Material.Neon, ctx.Theme.ElectricBlue)
end

function View.Mount(ctx)
	JobClient.Mount(ctx)
	JobClient.RegisterKind({
		Kind = KIND,
		Title = "PARCEL",
		Nearest = "NEAREST PARCEL",
		Icon = "CourierPickup",
		DropIcon = "CourierDrop",
		ActionText = "Pick up parcel",
		DropLabel = "DELIVERY",
		StripTitle = "COURIER",
		BoardingText = "COURIER · LOADING THE PARCEL...",
		Colour = ctx.Theme.ElectricBlue,
		Order = 10,
		DoneTitle = "DELIVERED",
		FailTitle = "DELIVERY FAILED: ",
		CancelTitle = "DELIVERY CANCELLED: ",
		BuildProp = buildParcel,
		StartedText = function(payload)
			local label = type(payload.Label) == "string" and (string.upper(payload.Label) .. " · ") or ""
			return "PARCEL LOADED · " .. label .. JobRules.Miles(payload.Distance) .. " RUN · FASTER PAYS MORE, CRASHES COST"
		end,
	})
end

function View.OnEvent(payload)
	if type(payload) ~= "table" or type(payload.Type) ~= "string" then return end
	if string.sub(payload.Type, 1, #KIND + 1) == KIND .. ":" then JobClient.OnEvent(KIND, payload) end
end

return View
