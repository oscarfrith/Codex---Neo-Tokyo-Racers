-- Player-local handoff to the current driving owner. No UI renderer or driving equations live here.
local Client = {}
local started = false

-- HUD telemetry (drivetrain_feel contract 3.2): DrivingClient passes one preallocated table, only for a car whose
-- drivetrain is active. MobileDriveInputState.Reset does not know these six fields, so they are cleared here: with no
-- telemetry, and when driving stops. Classic HUDs never read them.
local function publishTelemetry(mobile, telemetry)
    if type(telemetry) == "table" then
        mobile.Gear = telemetry.Gear
        mobile.GearRevision = telemetry.GearRevision
        mobile.RpmFraction = telemetry.RpmFraction
        mobile.ShiftLight = telemetry.ShiftLight
        mobile.Spin = telemetry.Spin
        mobile.Overdrive = telemetry.Overdrive == true
    else
        mobile.Gear = nil
        mobile.GearRevision = nil
        mobile.RpmFraction = nil
        mobile.ShiftLight = nil
        mobile.Spin = nil
        mobile.Overdrive = nil
    end
end

function Client.start()
    if started then return end
    started = true
    local player = game:GetService("Players").LocalPlayer
    local playerScripts = player:WaitForChild("PlayerScripts")
    local modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
    local driving = require(modules.Game.Vehicles.DrivingClient)
    local mobile = require(modules.Game.Vehicles.MobileDriveInputState)
    local scope = require(modules.Core.ConnectionScope).new()
    local events = playerScripts:WaitForChild("Runtime"):WaitForChild("UI")
    local context = {
        GetCamera = function() return workspace.CurrentCamera end,
        GetMobileInput = function()
            return mobile.Throttle or 0, mobile.Steer or 0, mobile.Drift == true, mobile.Boost == true
        end,
        PublishMobile = function(speedMph, boostPercent, telemetry)
            mobile.SpeedMph = speedMph or 0
            mobile.BoostPercent = math.clamp(boostPercent or 0, 0, 100)
            mobile.IsDriving = true
            publishTelemetry(mobile, telemetry)
        end,
        SetMobileDriving = function(enabled)
            mobile.IsDriving = enabled == true
            if not enabled then
                mobile.Reset()
                publishTelemetry(mobile, nil)
            end
        end,
    }
    scope:connect(events:WaitForChild("FreeRoamVehicleSpawned").Event, function()
        task.defer(function() driving.Start(context) end)
    end)
    scope:connect(events:WaitForChild("FreeRoamVehicleExited").Event, function()
        driving.Stop()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.Sit = false end
        local camera = workspace.CurrentCamera
        if camera then
            camera.CameraType = Enum.CameraType.Custom
            if humanoid then camera.CameraSubject = humanoid end
        end
    end)
    scope:connect(playerScripts.Destroying, function()
        driving.Stop()
        scope:destroy()
    end)
end

return Client
