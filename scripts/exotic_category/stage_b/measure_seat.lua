-- Exotic category, Stage B: read-only seat measurement for the pilot Play test.
-- Run it on the SERVER while Play is running and a player sits in the pilot Exotic (COCKPIT_EXOTIC_03).
-- It changes nothing and requires no module. Paste it into execute_luau (server), or load it with
--   return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:<port>/measure_seat.lua", true))()
-- For every seated player it reports, in CockpitRoot local space (+Y up):
--   the seat centre and seat top, the HumanoidRootPart centre, the lowest and highest point of the body,
--   and rootPartCentreAboveSeatTop = HumanoidRootPart centre Y - seat top Y.
-- That last number is data/seats.json rule.rootPartCentreAboveSeatTop (assumed 1.5). Record it in
-- data/seats.json pilotAcceptance (README.md, Seat acceptance). Compare "body low" with the tub underside and
-- "body high" with the roof underside to judge the trade-off described in data/seats.json.
local Players = game:GetService("Players")
local out = {}
local function add(text) table.insert(out, text) end

local function vehicleOf(seat)
	local current = seat.Parent
	local nearest = nil
	while current and current ~= workspace do
		if current:IsA("Model") then
			nearest = nearest or current
			if current:GetAttribute("OwnerUserId") ~= nil then return current end
		end
		current = current.Parent
	end
	return nearest
end

local found = 0
for _, player in ipairs(Players:GetPlayers()) do
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local seat = humanoid and humanoid.SeatPart
	if seat and rootPart and rootPart:IsA("BasePart") then
		local vehicle = vehicleOf(seat)
		local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
		if root and root:IsA("BasePart") then
			found += 1
			local frame = root.CFrame
			local seatLocal = frame:PointToObjectSpace(seat.Position)
			local rootPartLocal = frame:PointToObjectSpace(rootPart.Position)
			local seatTop = seatLocal.Y + seat.Size.Y / 2
			local low, high = math.huge, -math.huge
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part ~= rootPart and part:FindFirstAncestorOfClass("Accessory") == nil then
					local half = part.Size / 2
					for _, sx in ipairs({ -1, 1 }) do
						for _, sy in ipairs({ -1, 1 }) do
							for _, sz in ipairs({ -1, 1 }) do
								local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
								local y = frame:PointToObjectSpace(corner).Y
								low = math.min(low, y)
								high = math.max(high, y)
							end
						end
					end
				end
			end
			add(string.format("%s in %s of %s (CockpitId %s, %s, HipHeight %.3f, root part size Y %.3f)", player.Name, seat.Name, vehicle.Name,
				tostring(vehicle:GetAttribute("CockpitId")), humanoid.RigType.Name, humanoid.HipHeight, rootPart.Size.Y))
			add(string.format("  cockpit seat attributes: driver (%s, %s, %s) passenger (%s, %s, %s)",
				tostring(vehicle:GetAttribute("DriverSeatOffsetX")), tostring(vehicle:GetAttribute("DriverSeatOffsetY")), tostring(vehicle:GetAttribute("DriverSeatOffsetZ")),
				tostring(vehicle:GetAttribute("PassengerSeatOffsetX")), tostring(vehicle:GetAttribute("PassengerSeatOffsetY")), tostring(vehicle:GetAttribute("PassengerSeatOffsetZ"))))
			add(string.format("  seat centre (%.3f, %.3f, %.3f), seat top Y %.3f, seat size Y %.3f", seatLocal.X, seatLocal.Y, seatLocal.Z, seatTop, seat.Size.Y))
			add(string.format("  HumanoidRootPart centre (%.3f, %.3f, %.3f)", rootPartLocal.X, rootPartLocal.Y, rootPartLocal.Z))
			add(string.format("  rootPartCentreAboveSeatTop = %.3f", rootPartLocal.Y - seatTop))
			add(string.format("  body low Y %.3f, body high Y %.3f (accessories left out)", low, high))
		end
	end
end
if found == 0 then add("no seated player found: sit in the driver seat of the pilot Exotic first, and run this on the server") end
return table.concat(out, "\n")
