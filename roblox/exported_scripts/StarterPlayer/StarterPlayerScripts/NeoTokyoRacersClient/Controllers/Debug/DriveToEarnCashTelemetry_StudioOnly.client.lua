-- NTR_DRIVE_TO_EARN_STUDIO_TELEMETRY_V1_1
-- Read-only Studio presentation. No GUI is created in a published server and no
-- remote or mutation control exists.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
if not RunService:IsStudio() then return end

local player=Players.LocalPlayer
local config=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("DriveToEarnCash_EditAttributes")
if config:GetAttribute("StudioTelemetryEnabled")~=true then return end
local playerGui=player:WaitForChild("PlayerGui")
local old=playerGui:FindFirstChild("NTR_DriveToEarnCashTelemetry")
if old then old:Destroy() end

local gui=Instance.new("ScreenGui")
gui.Name="NTR_DriveToEarnCashTelemetry"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=2000
gui.Parent=playerGui
local panel=Instance.new("Frame")
panel.Name="ReadOnlyPanel"
panel.AnchorPoint=Vector2.new(1,0)
panel.Position=UDim2.new(1,-12,0,12)
panel.Size=UDim2.fromOffset(470,286)
panel.BackgroundColor3=Color3.fromRGB(12,17,25)
panel.BackgroundTransparency=0.08
panel.BorderSizePixel=0
panel.Parent=gui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=panel
local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(0,220,255); stroke.Thickness=1; stroke.Transparency=0.15; stroke.Parent=panel
local label=Instance.new("TextLabel")
label.Name="TelemetryText"
label.Position=UDim2.fromOffset(12,10)
label.Size=UDim2.new(1,-24,1,-20)
label.BackgroundTransparency=1
label.Font=Enum.Font.Code
label.TextSize=14
label.TextColor3=Color3.fromRGB(225,245,255)
label.TextXAlignment=Enum.TextXAlignment.Left
label.TextYAlignment=Enum.TextYAlignment.Top
label.TextWrapped=true
label.Parent=panel

local function value(name,fallback)
	local result=player:GetAttribute(name)
	return result==nil and fallback or result
end
local function update()
	if config:GetAttribute("StudioTelemetryEnabled")~=true then
		gui.Enabled=false
		return
	end
	gui.Enabled=true
	local camera=Workspace.CurrentCamera
	local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
	panel.Size=UDim2.fromOffset(math.max(280,math.min(470,viewport.X-24)),math.max(240,math.min(286,viewport.Y-24)))
	label.TextSize=viewport.X<600 and 11 or 14
	label.Text=table.concat({
		"DRIVE-TO-EARN ECONOMY TELEMETRY  [STUDIO / READ ONLY]",
		"accepted studs:       "..tostring(value("NTR_DriveCashAcceptedStuds",0)),
		"rejected studs:       "..tostring(value("NTR_DriveCashRejectedStudsByReason","none")),
		"ungranted Cash:       $"..tostring(value("NTR_DriveCashAccumulatedUngranted",0)),
		"granted Cash:         $"..tostring(value("NTR_DriveCashGranted",0)),
		"current hourly:       $"..tostring(value("NTR_DriveCashCurrentHourly",0)),
		"projected hourly:     $"..tostring(value("NTR_DriveCashProjectedHourly",0)),
		"cap usage:            "..tostring(value("NTR_DriveCashCapUsage",0)).."%  ($"..tostring(value("NTR_DriveCashCapUsed",0))..")",
		"last sample:          "..tostring(value("NTR_DriveCashLastReason","waiting")),
		"vehicle/session:",
		"  "..tostring(value("NTR_DriveCashVehicleIdentity","none")),
		"  "..tostring(value("NTR_DriveCashSessionIdentity","none")),
	},"\n")
end
while gui.Parent do
	update()
	task.wait(0.25)
end
