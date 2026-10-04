--!strict
-- Client camera arbitration for field of view and player zoom limits. Owners submit keyed requests with a
-- priority; the highest priority (latest on ties) is applied. With no requests the values captured before
-- the first request are restored. Every value is validated (finite, clamped, min <= max) so no owner can
-- write NaN or an inverted zoom range into the camera. Owners never write these properties directly.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CameraService = {}

type Request = { value: any, priority: number, order: number }
local fovRequests: { [string]: Request } = {}
local zoomRequests: { [string]: Request } = {}
local order = 0
local baseFov: number? = nil
local baseZoom: { number }? = nil

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function winner(requests: { [string]: Request }): Request?
	local best: Request? = nil
	for _, request in pairs(requests) do
		if not best or request.priority > best.priority or (request.priority == best.priority and request.order > best.order) then
			best = request
		end
	end
	return best
end

local function applyFov()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local best = winner(fovRequests)
	local value = best and best.value or baseFov
	if value and math.abs(camera.FieldOfView - value) > 1e-4 then camera.FieldOfView = value end
end

local function applyZoom()
	local player = Players.LocalPlayer
	if not player then return end
	local best = winner(zoomRequests)
	local range = best and best.value or baseZoom
	if not range then return end
	local minimum, maximum = range[1], range[2]
	if math.abs(player.CameraMinZoomDistance - minimum) < 1e-4 and math.abs(player.CameraMaxZoomDistance - maximum) < 1e-4 then return end
	-- Order writes so the engine never observes min > max.
	if minimum > player.CameraMaxZoomDistance then
		player.CameraMaxZoomDistance = maximum
		player.CameraMinZoomDistance = minimum
	else
		player.CameraMinZoomDistance = minimum
		player.CameraMaxZoomDistance = maximum
	end
end

function CameraService.SetFieldOfView(owner: string, fov: number, priority: number?)
	if not finite(fov) then return end
	local camera = Workspace.CurrentCamera
	if baseFov == nil and camera then baseFov = camera.FieldOfView end
	order += 1
	fovRequests[owner] = { value = math.clamp(fov, 1, 120), priority = priority or 0, order = order }
	applyFov()
end

function CameraService.ClearFieldOfView(owner: string)
	if fovRequests[owner] == nil then return end
	fovRequests[owner] = nil
	applyFov()
	if next(fovRequests) == nil then baseFov = nil end
end

function CameraService.SetZoomLimits(owner: string, minimum: number, maximum: number, priority: number?)
	if not (finite(minimum) and finite(maximum)) then return end
	local player = Players.LocalPlayer
	if baseZoom == nil and player then
		local currentMin, currentMax = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
		if finite(currentMin) and finite(currentMax) and currentMin <= currentMax then
			baseZoom = { currentMin, currentMax }
		else
			local starter = game:GetService("StarterPlayer")
			baseZoom = { starter.CameraMinZoomDistance, starter.CameraMaxZoomDistance }
		end
	end
	minimum = math.clamp(minimum, 0.5, 400)
	maximum = math.clamp(maximum, minimum, 400)
	order += 1
	zoomRequests[owner] = { value = { minimum, maximum }, priority = priority or 0, order = order }
	applyZoom()
end

function CameraService.ClearZoomLimits(owner: string)
	if zoomRequests[owner] == nil then return end
	zoomRequests[owner] = nil
	applyZoom()
	if next(zoomRequests) == nil then baseZoom = nil end
end

-- Diagnostics: current winning owners.
function CameraService.Owners(): (string?, string?)
	local fovOwner, zoomOwner = nil, nil
	local fovBest, zoomBest = winner(fovRequests), winner(zoomRequests)
	for owner, request in pairs(fovRequests) do if request == fovBest then fovOwner = owner end end
	for owner, request in pairs(zoomRequests) do if request == zoomBest then zoomOwner = owner end end
	return fovOwner, zoomOwner
end

return CameraService
