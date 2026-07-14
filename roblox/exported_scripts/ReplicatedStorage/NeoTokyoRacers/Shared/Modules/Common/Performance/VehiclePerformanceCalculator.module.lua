-- NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_CALCULATOR
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local V2 = require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))
local Calculator = {}
local function number(value, fallback) return typeof(value) == "number" and value or fallback end
local function enabled()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local shared = kit and kit:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("VehiclePerformanceV2_EditAttributes")
	return config and config:GetAttribute("RuntimeRatingEnabled") == true
end
local function read(source, name, fallback)
	if typeof(source) == "Instance" then return number(source:GetAttribute(name), fallback) end
	if typeof(source) == "table" then return number(source[name], fallback) end
	return fallback
end
function Calculator.FromLegacyStats(source)
	local compatibility = Definitions.GetCompatibilityDefaults()
	local handling, drift = read(source, "Handling", 48), read(source, "Drift", 46)
	local boost = read(source, "BoostForce", read(source, "Boost", 0))
	return { TopSpeed=read(source,"TopSpeed",read(source,"MaxSpeed",126)), EngineOutput=read(source,"EngineOutput",read(source,"Acceleration",42)), Weight=read(source,"Weight",118), LateralGrip=read(source,"LateralGrip",handling), SteeringResponse=read(source,"SteeringResponse",handling), HoverStability=read(source,"HoverStability",handling), DriftControl=read(source,"DriftControl",drift), DriftGrip=read(source,"DriftGrip",drift), DriftChargeRate=read(source,"DriftChargeRate",drift), BrakingForce=read(source,"BrakingForce",read(source,"Braking",44)), BoostForce=boost, BoostDuration=read(source,"BoostDuration",compatibility.DefaultBoostDuration), BoostRecharge=read(source,"BoostRecharge",compatibility.DefaultBoostRecharge), BoostRechargeDelay=read(source,"BoostRechargeDelay",compatibility.DefaultBoostRechargeDelay), BoostEfficiency=read(source,"BoostEfficiency",compatibility.NeutralBoostEfficiency), Drag=read(source,"Drag",compatibility.NeutralDrag), Downforce=read(source,"Downforce",compatibility.NeutralDownforce) }
end
function Calculator.CloneRaw(raw) if enabled() then return V2.CloneRaw(raw) end; local result={}; for _,name in ipairs(Definitions.RawVariableOrder) do result[name]=number(raw and raw[name],0) end; return result end
function Calculator.AddRaw(target,delta,multiplier) if enabled() then return V2.AddRaw(target,delta,multiplier) end; target=target or {}; multiplier=number(multiplier,1); for _,name in ipairs(Definitions.RawVariableOrder) do target[name]=number(target[name],0)+number(delta and delta[name],0)*multiplier end; return target end
function Calculator.NormalizeVariable(variableName,rawValue) local d=Definitions.GetNormalization(variableName); local minimum,maximum=number(d.Min,0),number(d.Max,100); local score=math.clamp((number(rawValue,minimum)-minimum)/math.max(maximum-minimum,0.0001)*100,0,100); return d.LowerIsBetter==true and 100-score or score end
function Calculator.NormalizeRaw(raw) local r={}; for _,name in ipairs(Definitions.RawVariableOrder) do r[name]=Calculator.NormalizeVariable(name,raw[name]) end; return r end
local function average(values,weights) local total,weightTotal=0,0; for key,weight in pairs(weights or {}) do if typeof(weight)=="number" and typeof(values[key])=="number" then total+=values[key]*weight; weightTotal+=weight end end; return weightTotal>0 and total/weightTotal or 0 end
function Calculator.CalculateHeadline(normalized) local r={}; for _,name in ipairs(Definitions.HeadlineOrder) do r[name]=average(normalized,Definitions.GetHeadlineWeights(name)) end; return r end
function Calculator.TierForIndex(index) if enabled() then return V2.TierForIndex(index) end; local b=Definitions.GetTierBands(); for _,item in ipairs({{"S",number(b.S,850)},{"A",number(b.A,725)},{"B",number(b.B,600)},{"C",number(b.C,450)},{"D",number(b.D,300)},{"E",number(b.E,100)}}) do if index>=item[2] then return item[1] end end; return "E" end
function Calculator.CalculateOverall(headline) if enabled() then return V2.CalculateOverall(headline) end; local s=Definitions.GetOverallSettings(); local base=average(headline,s); local values={}; for _,name in ipairs(Definitions.HeadlineOrder) do table.insert(values,number(headline[name],0)) end; table.sort(values); local balance=(values[1]+values[2]+values[3])/3; local score=math.clamp(base*number(s.BaseContribution,0.85)+balance*number(s.BalanceContribution,0.15),0,100); local minimum,maximum=number(s.PerformanceIndexMin,100),number(s.PerformanceIndexMax,999); local index=math.round(minimum+score/100*(maximum-minimum)); return {Score=score,PerformanceIndex=index,Tier=Calculator.TierForIndex(index),BaseScore=base,BalanceScore=balance} end
function Calculator.Calculate(raw) if enabled() then return V2.Calculate(raw) end; local rawCopy=Calculator.CloneRaw(raw); local normalized=Calculator.NormalizeRaw(rawCopy); local headline=Calculator.CalculateHeadline(normalized); return {Raw=rawCopy,Normalized=normalized,Headline=headline,Overall=Calculator.CalculateOverall(headline)} end
function Calculator.CalculateLegacy(source) return Calculator.Calculate(Calculator.FromLegacyStats(source)) end
return Calculator
