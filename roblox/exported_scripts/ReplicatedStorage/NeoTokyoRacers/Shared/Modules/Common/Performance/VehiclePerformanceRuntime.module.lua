-- NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_RUNTIME
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceCalculator"))
local V2Runtime = require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local Runtime = {}
local function config() local kit=ReplicatedStorage:FindFirstChild("NeoTokyoRacers"); local shared=kit and kit:FindFirstChild("Shared"); return shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("VehiclePerformanceV2_EditAttributes") end
local function v2Enabled() local c=config(); return c and (c:GetAttribute("RuntimeRatingEnabled")==true or c:GetAttribute("RuntimePhysicsEnabled")==true) end
local function numberAttribute(item,name) local value=item and item:GetAttribute(name); return typeof(value)=="number" and value or nil end
local function installed(root) local r={}; if root then for _,item in ipairs(root:GetChildren()) do if item:IsA("Model") and item:GetAttribute("ModuleId")~=nil then table.insert(r,item) end end end; return r end
function Runtime.CalculateBuild(legacyTotals,cockpit,installedRoot)
	if v2Enabled() and cockpit and cockpit:GetAttribute("V2Materialised")==true then return V2Runtime.CalculateComponents(cockpit,installed(installedRoot)) end
	local raw=Calculator.FromLegacyStats(legacyTotals)
	for _,name in ipairs(Definitions.RawVariableOrder) do local override=numberAttribute(cockpit,"PerformanceOverride_"..name); if override~=nil then raw[name]=override end; local delta=numberAttribute(cockpit,"PerformanceDelta_"..name); if delta~=nil then raw[name]=(raw[name] or 0)+delta end end
	for _,module in ipairs(installed(installedRoot)) do for _,name in ipairs(Definitions.RawVariableOrder) do local delta=numberAttribute(module,"PerformanceDelta_"..name); if delta~=nil then raw[name]=(raw[name] or 0)+delta end end end
	return Calculator.Calculate(raw)
end
local function rewrite(vehicle,name,values) local folder=vehicle:FindFirstChild(name); if folder and not folder:IsA("Folder") then folder:Destroy(); folder=nil end; if not folder then folder=Instance.new("Folder"); folder.Name=name; folder.Parent=vehicle end; folder:ClearAllChildren(); for key,value in pairs(values or {}) do if typeof(value)=="number" then local n=Instance.new("NumberValue"); n.Name=key; n.Value=value; n.Parent=folder end end end
function Runtime.WriteToVehicle(vehicle,result)
	rewrite(vehicle,"RAW_PERFORMANCE_Runtime",result.Raw or {}); rewrite(vehicle,"NORMALIZED_PERFORMANCE_Runtime",result.Normalized or result.EffectiveFactor or {}); rewrite(vehicle,"HEADLINE_STATS_Runtime",result.Headline or {})
	for key,value in pairs(result.Raw or {}) do if typeof(value)=="number" then vehicle:SetAttribute("Performance_"..key,value) end end
	local overall=result.Overall or {}; vehicle:SetAttribute("PerformanceIndex",overall.PerformanceIndex or 100); vehicle:SetAttribute("PerformanceTier",overall.Tier or "E"); vehicle:SetAttribute("PerformanceScore",overall.Score or 0); vehicle:SetAttribute("PerformanceRuntimeVersion",v2Enabled() and "V2_PHASE8_LIVE" or "AM_1")
end
return Runtime
