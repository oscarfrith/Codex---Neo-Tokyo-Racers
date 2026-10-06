"""Driving tune, balance part (contract: ../CONTRACT.md). Notes and evidence: NOTES.md, model.py.

Model.Balance(vehicle) in VehicleDynamics turns the vehicle's PerformanceIndex into a table of multipliers
(1 = unchanged). StepLongitudinal and StepHandling apply their own; DrivingClient applies top speed, boost,
mini-boost and turn rate. Every number is in Config.Vehicles.Dynamics.08_Balance; BalanceEnabled 0 returns all
ones, and x * 1 is exact, so that is a behavioural rollback.
"""

BALANCE_PATH = ["ReplicatedStorage", "Config", "Vehicles", "Dynamics"]

# name, value, minimum, maximum, _RaisingThisDoes
TUNING = [
    ("BalanceEnabled", 1, 0, 1, "1 turns the performance balance nerf on. 0 turns all of it off (every multiplier becomes 1)."),
    ("BalanceLowPerformanceIndex", 200, 0, 2000, "Moves the start of the curve up: cars at or below this PerformanceIndex get BalanceLowNerf."),
    ("BalanceHighPerformanceIndex", 900, 0, 2000, "Moves the end of the curve up: cars at or above this PerformanceIndex get BalanceHighNerf, so cars below it are nerfed less."),
    ("BalanceLowNerf", 0.10, 0, 0.6, "Nerfs the slowest cars more. 0.10 = 10 percent base nerf at BalanceLowPerformanceIndex."),
    ("BalanceHighNerf", 0.25, 0, 0.6, "Nerfs the fastest cars more. 0.25 = 25 percent base nerf at BalanceHighPerformanceIndex."),
    ("BalanceCurveEase", 0.5, 0, 1, "Bends the line between the low and high nerf into an S: 0 is a straight line, 1 is flat at both ends and steepest in the middle."),
    ("BalanceFallbackPerformanceIndex", 525, 0, 2000, "PerformanceIndex assumed for a vehicle that has none. Raising it nerfs such vehicles more."),
    ("BalanceRefreshSeconds", 0.25, 0, 5, "Makes edits to this folder take longer to reach a car being driven (the multipliers are recomputed this often). No effect on feel."),
    ("BalanceAccelBrakeExtraNerf", 0.15, 0, 0.6, "Extra nerf on top of the base nerf for acceleration, braking and boost push (each scaled by its ExtraShare)."),
    ("BalanceDriftExtraNerf", 0.20, 0, 0.6, "Extra nerf on top of the base nerf for drifting (each drift value scaled by its ExtraShare)."),
    ("BalanceDragCoupling", 1, 0, 1, "1 retunes air drag so real top speed falls by exactly the top speed nerf and no more. 0 leaves drag alone, so the acceleration nerf also lowers top speed further."),
    ("BalanceTopSpeedBaseShare", 1, 0, 2, "Takes more of the base nerf off top speed."),
    ("BalanceAccelerationBaseShare", 1, 0, 2, "Takes more of the base nerf off forward acceleration."),
    ("BalanceAccelerationExtraShare", 1, 0, 2, "Takes more of BalanceAccelBrakeExtraNerf off forward acceleration."),
    ("BalanceBrakingBaseShare", 1, 0, 2, "Takes more of the base nerf off braking."),
    ("BalanceBrakingExtraShare", 1, 0, 2, "Takes more of BalanceAccelBrakeExtraNerf off braking."),
    ("BalanceReverseBaseShare", 1, 0, 2, "Takes more of the base nerf off reverse acceleration."),
    ("BalanceReverseExtraShare", 0, 0, 2, "Takes more of BalanceAccelBrakeExtraNerf off reverse acceleration."),
    ("BalanceBoostBaseShare", 1, 0, 2, "Takes more of the base nerf off the held boost push."),
    ("BalanceBoostExtraShare", 1, 0, 2, "Takes more of BalanceAccelBrakeExtraNerf off the held boost push. At 1 boosted top speed falls by the same share as normal top speed."),
    ("BalanceSteeringBaseShare", 0.4, 0, 2, "Takes more of the base nerf off turn rate (all steering, drifting included)."),
    ("BalanceGripBaseShare", 0.25, 0, 2, "Takes more of the base nerf off normal (non-drift) sideways grip, so cars slide wider in fast corners."),
    ("BalanceDriftSideForceBaseShare", 1, 0, 2, "Takes more of the base nerf off the drift slide-out push. At 1 the slide angle stays about the same as speeds drop."),
    ("BalanceDriftSideForceExtraShare", 0, 0, 2, "Takes more of BalanceDriftExtraNerf off the drift slide-out push. Raising it makes drifts slide out less (tidier, not weaker)."),
    ("BalanceDriftTurnBaseShare", 0, 0, 2, "Takes more of the base nerf off the extra turning a drift gives (on top of the steering share)."),
    ("BalanceDriftTurnExtraShare", 1, 0, 2, "Takes more of BalanceDriftExtraNerf off the extra turning a drift gives, so drifts take corners wider."),
    ("BalanceDriftEngineAssistBaseShare", 0, 0, 2, "Takes more of the base nerf off the extra engine push while drifting."),
    ("BalanceDriftEngineAssistExtraShare", 1, 0, 2, "Takes more of BalanceDriftExtraNerf off the extra engine push while drifting, so drifts lose more speed."),
    ("BalanceDriftAlignmentBaseShare", 0.5, 0, 2, "Takes more of the base nerf off the pull that swings momentum round to where the car points in a drift."),
    ("BalanceDriftAlignmentExtraShare", 1, 0, 2, "Takes more of BalanceDriftExtraNerf off that momentum pull, so drifts carry wider."),
    ("BalanceDriftChargeBaseShare", 0, 0, 2, "Takes more of the base nerf off how fast a drift charges its mini-boost."),
    ("BalanceDriftChargeExtraShare", 0.5, 0, 2, "Takes more of BalanceDriftExtraNerf off how fast a drift charges its mini-boost."),
    ("BalanceMiniBoostBaseShare", 1, 0, 2, "Takes more of the base nerf off the drift mini-boost push."),
    ("BalanceMiniBoostExtraShare", 1, 0, 2, "Takes more of BalanceDriftExtraNerf off the drift mini-boost push."),
]
VALUES = {name: (value, lo, hi) for name, value, lo, hi, _ in TUNING}


def _attributes():
    out = {}
    for name, value, _, _, text in TUNING:
        out[name] = value
        out[name + "_RaisingThisDoes"] = text
    return out


def _num(name):
    value, lo, hi = VALUES[name]
    return 'numberAttribute(config, "%s", %s, %s, %s)' % (name, repr(value), repr(lo), repr(hi))


def _channel(key, name, extra):
    """result.<key> = (1 - base * BaseShare) * (1 - extra * ExtraShare); a channel with no ExtraShare has no extra."""
    text = "(1 - base * %s)" % _num("Balance%sBaseShare" % name)
    if ("Balance%sExtraShare" % name) in VALUES:
        text += " * (1 - %s * %s)" % (extra, _num("Balance%sExtraShare" % name))
    return "\tresult.%s = math.clamp(%s, 0.1, 1.5)\n" % (key, text)


BALANCE_LUA = (
    "-- Performance balance (driving tune 2026-10-06). Multipliers applied where stats become forces; 1 = unchanged.\n"
    "-- Tuning: Config.Vehicles.Dynamics.08_Balance. Stats, ratings and PerformanceIndex are not touched.\n"
    "local BALANCE_OFF = table.freeze({Enabled=false, PerformanceIndex=0, BaseNerf=0, TopSpeed=1, Acceleration=1, Braking=1, Reverse=1, Drag=1, Boost=1, MiniBoost=1,\n"
    "\tSteering=1, Grip=1, DriftSideForce=1, DriftTurn=1, DriftEngineAssist=1, DriftAlignment=1, DriftCharge=1})\n"
    "local balanceCacheVehicle, balanceCacheIndex, balanceCacheTime, balanceCacheRefresh, balanceCacheResult\n"
    "local function setIfChanged(instance, name, value)\n"
    "\tif instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end\n"
    "end\n"
    "\n"
    "-- Returns a frozen table; callers read it and never write it. Cheap to call several times a frame: the result\n"
    "-- is reused until the vehicle, its PerformanceIndex or BalanceRefreshSeconds of time changes.\n"
    "function Model.Balance(vehicle)\n"
    "\tlocal index = vehicle and vehicle:GetAttribute(\"PerformanceIndex\")\n"
    "\tif typeof(index) ~= \"number\" or index ~= index then index = nil end\n"
    "\tlocal now = os.clock()\n"
    "\tif balanceCacheResult and balanceCacheVehicle == vehicle and balanceCacheIndex == index and now - balanceCacheTime < balanceCacheRefresh then\n"
    "\t\treturn balanceCacheResult\n"
    "\tend\n"
    "\tlocal config = configFolder()\n"
    "\tlocal result\n"
    "\tif " + _num("BalanceEnabled") + " < 0.5 then\n"
    "\t\tresult = BALANCE_OFF\n"
    "\telse\n"
    "\t\tresult = Model.ComputeBalance(config, index)\n"
    "\tend\n"
    "\tbalanceCacheVehicle, balanceCacheIndex, balanceCacheTime, balanceCacheResult = vehicle, index, now, result\n"
    "\tbalanceCacheRefresh = " + _num("BalanceRefreshSeconds") + "\n"
    "\tif vehicle and boolAttribute(config, \"DebugAttributes\", true) then\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceBaseNerf\", result.BaseNerf)\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceTopSpeed\", result.TopSpeed)\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceAcceleration\", result.Acceleration)\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceBraking\", result.Braking)\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceDrag\", result.Drag)\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceSteering\", result.Steering)\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceDriftTurn\", result.DriftTurn)\n"
    "\t\tsetIfChanged(vehicle, \"DynamicsBalanceMiniBoost\", result.MiniBoost)\n"
    "\tend\n"
    "\treturn result\n"
    "end\n"
    "\n"
    "-- index = PerformanceIndex or nil. Pure: reads config only.\n"
    "function Model.ComputeBalance(config, index)\n"
    "\tlocal lowIndex = " + _num("BalanceLowPerformanceIndex") + "\n"
    "\tlocal highIndex = math.max(" + _num("BalanceHighPerformanceIndex") + ", lowIndex + 1)\n"
    "\tif index == nil then index = " + _num("BalanceFallbackPerformanceIndex") + " end\n"
    "\t-- Straight line from the low to the high nerf, blended towards a smoothstep by BalanceCurveEase.\n"
    "\t-- Continuous and never decreasing in PerformanceIndex, flat outside the two ends: no steps at tier boundaries.\n"
    "\tlocal alpha = math.clamp((index - lowIndex) / (highIndex - lowIndex), 0, 1)\n"
    "\talpha += (smoothstep(alpha) - alpha) * " + _num("BalanceCurveEase") + "\n"
    "\tlocal lowNerf = " + _num("BalanceLowNerf") + "\n"
    "\tlocal base = lowNerf + (" + _num("BalanceHighNerf") + " - lowNerf) * alpha\n"
    "\tlocal accelExtra = " + _num("BalanceAccelBrakeExtraNerf") + "\n"
    "\tlocal driftExtra = " + _num("BalanceDriftExtraNerf") + "\n"
    "\tlocal result = {Enabled = true, PerformanceIndex = index, BaseNerf = base}\n"
    + _channel("TopSpeed", "TopSpeed", None)
    + _channel("Acceleration", "Acceleration", "accelExtra")
    + _channel("Braking", "Braking", "accelExtra")
    + _channel("Reverse", "Reverse", "accelExtra")
    + _channel("Boost", "Boost", "accelExtra")
    + _channel("Steering", "Steering", None)
    + _channel("Grip", "Grip", None)
    + _channel("DriftSideForce", "DriftSideForce", "driftExtra")
    + _channel("DriftTurn", "DriftTurn", "driftExtra")
    + _channel("DriftEngineAssist", "DriftEngineAssist", "driftExtra")
    + _channel("DriftAlignment", "DriftAlignment", "driftExtra")
    + _channel("DriftCharge", "DriftCharge", "driftExtra")
    + _channel("MiniBoost", "MiniBoost", "driftExtra")
    + "\t-- Top speed is set by air drag, not by the mapped cap (drag stops the cars well below it). Drag-limited speed\n"
    "\t-- goes as sqrt(acceleration / drag), so drag = acceleration / topSpeed^2 makes real top speed fall by exactly\n"
    "\t-- the top speed multiplier and the whole acceleration curve keep its shape.\n"
    "\tresult.Drag = math.clamp(1 + (result.Acceleration / (result.TopSpeed * result.TopSpeed) - 1) * " + _num("BalanceDragCoupling") + ", 0.25, 4)\n"
    "\treturn table.freeze(result)\n"
    "end\n"
    "\n"
)

HANDLING_OLD = 'local result={Enabled=true,LateralGrip=lateralGrip,DriftSideForce=numberAttribute(config,"BaseDriftSideForce",26,5,100)*driftControlFactor,DriftTurnMultiplier=driftControlFactor,DriftChargeMultiplier=driftChargeFactor,AlignResponsiveness=numberAttribute(config,"BaseAlignResponsiveness",22,4,60)*stabilityFactor,DriftEngineAssist=numberAttribute(config,"DriftEngineAssist",0.20,0,1)*engineDriftFactor,DriftVelocityAlignmentRate=numberAttribute(config,"DriftVelocityAlignmentRate",2.0,0,10)*driftControlFactor,DriftVelocityAlignmentMaxAcceleration=numberAttribute(config,"DriftVelocityAlignmentMaxAcceleration",30,1,100)*driftGripFactor}'
HANDLING_NEW = 'local result={Enabled=true,LateralGrip=lateralGrip,DriftSideForce=numberAttribute(config,"BaseDriftSideForce",26,5,100)*driftControlFactor*balance.DriftSideForce,DriftTurnMultiplier=driftControlFactor*balance.DriftTurn,DriftChargeMultiplier=driftChargeFactor*balance.DriftCharge,AlignResponsiveness=numberAttribute(config,"BaseAlignResponsiveness",22,4,60)*stabilityFactor,DriftEngineAssist=numberAttribute(config,"DriftEngineAssist",0.20,0,1)*engineDriftFactor*balance.DriftEngineAssist,DriftVelocityAlignmentRate=numberAttribute(config,"DriftVelocityAlignmentRate",2.0,0,10)*driftControlFactor*balance.DriftAlignment,DriftVelocityAlignmentMaxAcceleration=numberAttribute(config,"DriftVelocityAlignmentMaxAcceleration",30,1,100)*driftGripFactor*balance.DriftAlignment}'

EDITS = {
    "VehicleDynamics": [
        # Model.Balance and Model.ComputeBalance, defined before the functions that use them.
        ("function Model.ResolveStats(vehicle, legacy)\n", BALANCE_LUA + "function Model.ResolveStats(vehicle, legacy)\n", 1),
        # StepLongitudinal
        ("\tlocal stats = params.Stats or {}\n",
         "\tlocal stats = params.Stats or {}\n\tlocal balance = Model.Balance(params.Vehicle)\n", 1),
        ('*effectiveEngineFactor*weightFactor*launchShape*highFade\n',
         '*effectiveEngineFactor*weightFactor*launchShape*highFade*balance.Acceleration\n', 1),
        ('local brakeAcceleration = numberAttribute(config,"BaseBrakeDeceleration",30,8,90)*brakingFactor*brakeWeightFactor\n',
         'local brakeAcceleration = numberAttribute(config,"BaseBrakeDeceleration",30,8,90)*brakingFactor*brakeWeightFactor*balance.Braking\n', 1),
        ('*forwardMph*math.abs(forwardMph)*dragFactor\n', '*forwardMph*math.abs(forwardMph)*dragFactor*balance.Drag\n', 1),
        ('local reverseAcceleration = numberAttribute(config,"ReverseAcceleration",12,2,40)*engineFactor*weightFactor\n',
         'local reverseAcceleration = numberAttribute(config,"ReverseAcceleration",12,2,40)*engineFactor*weightFactor*balance.Reverse\n', 1),
        # StepHandling
        ("local driftBlend=math.clamp(tonumber(params.DriftBlend) or 0,0,1)\n",
         "local driftBlend=math.clamp(tonumber(params.DriftBlend) or 0,0,1)\n\tlocal balance=Model.Balance(vehicle)\n", 1),
        ('local normalGrip=numberAttribute(config,"BaseNormalLateralGrip",6.6,1,20)*lateralFactor*downforceFactor\n',
         'local normalGrip=numberAttribute(config,"BaseNormalLateralGrip",6.6,1,20)*lateralFactor*downforceFactor*balance.Grip\n', 1),
        (HANDLING_OLD, HANDLING_NEW, 1),
    ],
    "DrivingClient": [
        # stats block: read the balance once, scale the top speed cap and the legacy-path forces
        ("\t\tlocal maxMph = math.clamp(dynamicsStats.TopSpeed, 40, absoluteTopSpeedSafetyMph)\n",
         "\t\t-- Performance balance: multipliers from PerformanceIndex (1 = unchanged). VehicleDynamics applies the\n"
         "\t\t-- acceleration, braking, drag, grip and drift ones itself; the rest are applied below.\n"
         "\t\tlocal balance = VehicleDynamicsModel.Balance(state.Vehicle)\n"
         "\t\tlocal maxMph = math.clamp(dynamicsStats.TopSpeed * balance.TopSpeed, 40, absoluteTopSpeedSafetyMph)\n", 1),
        ("\t\tbraking *= math.clamp(115 / weight, 0.68, 1.15)\n",
         "\t\tbraking *= math.clamp(115 / weight, 0.68, 1.15)\n"
         "\t\tacceleration *= balance.Acceleration\n"
         "\t\tbraking *= balance.Reverse\n", 1),
        ("\t\t\tdriveForce += forward * mass * (boostPower + 32) * 0.75\n",
         "\t\t\tdriveForce += forward * mass * (boostPower + 32) * 0.75 * balance.Boost\n", 1),
        ("\t\t\tdriveForce += forward * mass * state.MiniBoostPower * forceMultiplier\n",
         "\t\t\tdriveForce += forward * mass * state.MiniBoostPower * forceMultiplier * balance.MiniBoost\n", 1),
        ("\t\tlocal turnRate = (handling / 58) * 1.08 * speedFactor\n",
         "\t\tlocal turnRate = (handling / 58) * 1.08 * speedFactor * balance.Steering\n", 1),
    ],
}

INSTANCES = [
    {"parent": BALANCE_PATH, "name": "08_Balance", "class": "Folder", "attributes": _attributes()},
]

ATTRIBUTES = []
