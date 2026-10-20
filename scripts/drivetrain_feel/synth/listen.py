"""Pulse Racers - drivetrain_feel listen pack (offline WAV demos; nothing is uploaded).

    py -3 scripts/drivetrain_feel/synth/make_exotic_v2.py     # first: the v2 loops and today's set
    py -3 scripts/drivetrain_feel/synth/listen.py             # every demo
    py -3 scripts/drivetrain_feel/synth/listen.py --only full_run,spin
    py -3 scripts/drivetrain_feel/synth/listen.py --set FeelGearing=0.5 --tag gearing05

Writes output/drivetrain_feel_audio/listen/ (44.1 kHz, 16-bit, mono) plus README.txt and timeline.json.

What is modelled
----------------
* A straight-line port of the Exotic gearbox (CONTRACT 4.2/5.2 numbers, DRIVETRAIN below) on an S-tier stock
  Exotic (CAR below, calibrated to design_draft 3.3: top 174 mph, boosted 214, gears 47/68/89/111/134/158/184 mph).
  Physics runs at 240 Hz and publishes the Feel attributes at 60 Hz, quantised as CONTRACT 3.1 says.
* A Python port of VehicleAudioClient.updateFeel for the local car (load follower, bark, rev follower, the
  log-frequency equal-power rev-layer crossfade, neighbour detune, twin engines, life noise, ducks, the feel loops
  and one-shots) and of the remote-car path (three Load "Any" voices at 15 Hz).
* "new" adds the drivetrain_feel audio rules as drafted by the audio part: rpm -> rev mapping, upshift drop, dip,
  downshift blip, shift one-shots, reactor whine, spin strain, remote gears. Values are read at run time from
  scripts/drivetrain_feel/audio/after/VehicleAudioCatalog.lua (and audio/config.py when it exists), else the
  fallbacks below. Live profile values come from scripts/drivetrain_feel/before/config.json.

APPROXIMATE (labelled in README.txt and the synth README)
---------------------------------------------------------
* The engine sub-bus effects (AudioFilter Peak sweep, AudioEqualizer tilt, AudioTremolo) are approximated with an
  STFT magnitude filter and a hand-made tremolo LFO. Roblox's own DSP will differ.
* PlaybackSpeed changes are interpolated between update ticks; Roblox steps them per tick.
* Spin, power-brake hold and launch slip are scripted inputs, not the chassis model. The spin scrub is a constant.
* The pass-by adds doppler and the in-game distance curve {0:1, 12:1, 132:0.28, 240:0}; whether Roblox's
  AudioEmitter applies doppler is not verified.
* Toolbox sounds (BlowOff, generic idle/acceleration) are not in the pack; the blow-off/flutter vent is omitted.
"""
import argparse
import importlib.util
import json
import math
import os
import re
import sys
import wave

import numpy as np

sys.dont_write_bytecode = True  # importing other folders' files by path must not leave __pycache__ there

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DELIVERY = os.path.join(ROOT, "scripts", "drivetrain_feel")
OUT_BASE = os.path.join(ROOT, "output", "drivetrain_feel_audio")
V2_DIR = os.path.join(OUT_BASE, "exotic_v2")
TODAY_DIR = os.path.join(OUT_BASE, "_today_regen")
LISTEN_DIR = os.path.join(OUT_BASE, "listen")
BEFORE_CONFIG = os.path.join(DELIVERY, "before", "config.json")
BEFORE_CATALOG = os.path.join(DELIVERY, "before", "VehicleAudioCatalog.lua")
AUDIO_CATALOG = os.path.join(DELIVERY, "audio", "after", "VehicleAudioCatalog.lua")
AUDIO_CONFIG = os.path.join(DELIVERY, "audio", "config.py")

SR = 44100
FRAME_HZ = 60      # DrivingClient Heartbeat and the desktop LocalFeelUpdateHz
REMOTE_HZ = 15     # updateGraph ParameterUpdateHz (other players' cars)
SUBSTEPS = 4       # physics sub-steps per frame, so 30-60 ms cuts are time-weighted (CONTRACT 5.2 rule 5)
MPH = 0.625        # mph per stud/s
G = 35.1           # studs/s^2 per g
HALF_PI = math.pi / 2
MASTER_DB = -1.0   # one fixed master gain for every file, so today and new keep their real level difference

# --------------------------------------------------------------------------------------------------------
# Drivetrain.exotic (CONTRACT 4.1-4.5; only what a straight line needs). --set Name=value overrides any of them.
# --------------------------------------------------------------------------------------------------------
DRIVETRAIN = dict(
    FeelWeight=1.0, FeelGearing=1.0, FeelAcceleration=1.0, FeelGrip=1.0, FeelSpin=1.0, FeelEngineBrake=1.0,
    GearCount=7, GearRatios="3.15,2.18,1.66,1.33,1.10,0.93,0.80", IdleRpm=1100.0, RedlineRpm=8500.0, LimiterRpm=8600.0,
    TorqueCurve="0:0.55,0.3:0.80,0.5:0.93,0.7:1,0.85:0.98,1:0.86", GearTorqueExponent=0.8, TopGearOverspeed=1.06,
    LaunchRpmFraction=0.5, EngineRiseSeconds=0.06, EngineFallScale=1.5, ShiftRpmSeconds=0.05, ThrustSlipFlare=0.6,
    ShiftCutSeconds=0.06, ShiftCutTorque=0.45, ShiftBlendSeconds=0.06, DownshiftBlendSeconds=0.08, ShiftMinIntervalSeconds=0.25,
    UpshiftFlat=0.97, UpshiftPartLow=0.62, UpshiftPartHigh=0.85, UpshiftCruise=0.45, CruiseThrottleMin=0.05,
    UpshiftMinLand=0.33, LiftHoldSeconds=0.8, DownshiftBrakeLand=0.82, DownshiftCoastFraction=0.30, DownshiftCoastLand=0.65,
    KickdownThrottle=0.95, KickdownBelowFraction=0.45, KickdownLand=0.88, KickdownHoldSeconds=0.12,
    StopGearMph=3.0, LimiterOnSeconds=0.03, LimiterCutSeconds=0.045, LimiterHysteresisRpm=150.0,
    NeutralRevEnabled=1, NeutralRevTarget=1.02,
    TractionG=1.15, TractionTierBonusG=0.25, TractionAssist=0.35, SlideGripFraction=0.88,
    RollingDecel=0.8, RollingDecelPerStud=0.004, EngineBrakeDecel=1.5,
    BoostShapeEnabled=1, BoostShareMin=0.15, SpeedGuardStrength=2.0, SpeedGuardOverBoostTop=1.03, OverdriveEnabled=1,
    PowerBrakeDumpSlip=0.5, SpinWindowSeconds=0.7, SpinBuildRate=3.5, SpinDecayRate=2.5, SpinCatchRate=8.0,
    SpinThrustLoss=0.35,
)

# The demo car: an S-tier stock Exotic (Seraph-like), today's numbers from design_draft section 3.3.
CAR = dict(
    name="S-tier stock Exotic (PI about 900)",
    TopMph=174.0,           # Vt, today's drag-limited top speed (kept by construction)
    BoostTopMph=214.0,      # Vb, today's boosted top speed
    PlateauAccel=72.0,      # A1 = 80*EngineFactor*WeightFactor*Balance.Acceleration, studs/s^2 (critique: S about 72)
    TodayBrakeDecel=115.0,  # today's brake, studs/s^2 (100-0 mph in about 1.3 s)
    NewBrakeDecel=72.0,     # BrakeDecel 70 x stat, weight and Balance factors for this car (about 2 g)
    TractionGripScale=1.04, # clamp((LateralGrip/50)^0.15, 0.9, 1.15)
    TierAlpha=1.0,          # PI at or above TierFullPI
)
SPIN_SCRUB = 40.0           # studs/s^2 of sideways scrub at full spin amount (approximate; chassis not modelled)

# drivetrain_feel audio tunables (the audio part's VehicleAudioCatalog defaults). Used only if its files are missing.
AUDIO_FALLBACK = dict(
    RpmRevEnabled=1, RevRpmMin=1000, RevRpmMax=8600, RevRpmSmoothingSeconds=0.02, ShiftAudioEnabled=1,
    ShiftDropSeconds=0.035, ShiftDropMaxSeconds=0.25, ShiftDipDb=5, ShiftDipMinSeconds=0.07, ShiftDipMaxSeconds=0.25,
    ShiftDipAttackSeconds=0.008, ShiftDipReleaseSeconds=0.05, DownshiftBlipRev=0.08, DownshiftBlipSeconds=0.12,
    DownshiftBlipLoad=1, ShiftVentMinStrength=0.7, ShiftCrackleEnabled=1, ShiftCracklePop=0.55, ShiftPitchJitter=0.03,
    EngineBusEnabled=1, EngineSweepLowHz=350, EngineSweepHighHz=2600, EngineSweepRevShare=0.4, EngineSweepDb=3,
    EngineSweepQ=1.6, EngineTiltLowOffDb=-1, EngineTiltLowOnDb=2, EngineTiltMidOffDb=-0.5, EngineTiltMidOnDb=1.5,
    EngineTiltHighOffDb=-4, EngineTiltHighOnDb=0, LimiterTremoloEnabled=1, LimiterNearRpm=200, LimiterHoldSeconds=0.1,
    LimiterTremoloHz=13.3, LimiterTremoloDepth=0.7, LimiterTremoloDuty=0.4, LimiterTremoloSquare=0.6,
    ReactorEnabled=1, ReactorGain=0.16, ReactorLoadFloor=0.25, ReactorFullMph=200, ReactorPitchMin=0.7, ReactorPitchMax=1.4,
    ReactorChirpDepth=0.03, ReactorChirpSeconds=0.08, ReactorOverdriveGain=0.4, SpinStrainGain=1, SciFiRpmShare=0,
    RemoteGearsEnabled=1, RemoteVoiceLowFraction=0.4, RemoteVoiceHighFraction=1, RemoteRevSmoothingSeconds=0.06,
    ShiftThunk1Gain=0.5, ShiftThunk2Gain=0.5, ShiftVent1Gain=0.55, ShiftVent2Gain=0.55,
)


# --------------------------------------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------------------------------------
def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def smooth01(a):
    a = clamp(a, 0.0, 1.0)
    return a * a * (3.0 - 2.0 * a)


def smoothstep(first, last, value):
    return smooth01((value - first) / (last - first) if last != first else 1.0)


def range_alpha(value, first, last):
    return clamp((value - first) / (last - first), 0.0, 1.0) if last != first else 1.0


def follow(current, target, dt, seconds):
    return current + (target - current) * (1.0 - math.exp(-dt / max(0.001, seconds)))


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2, path
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.round(np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# --------------------------------------------------------------------------------------------------------
# tuning: live profile (before/config.json) + catalog defaults + the audio part's drafted values
# --------------------------------------------------------------------------------------------------------
def parse_catalog(path):
    """feelDefaults ({ default, min, max }) and defaultGains (Name = number) from a VehicleAudioCatalog source."""
    text = open(path, encoding="utf-8").read()
    feel = {k: float(v) for k, v in re.findall(r"^\s*(\w+)\s*=\s*\{\s*(-?[\d.]+)\s*,\s*-?[\d.]+\s*,\s*-?[\d.]+\s*\}", text, re.M)}
    gains = {}
    block = re.search(r"local defaultGains = \{(.*?)\n\}", text, re.S)
    if block:
        gains = {k + "Gain": float(v) for k, v in re.findall(r"^\s*(\w+)\s*=\s*(-?[\d.]+),?\s*$", block.group(1), re.M)}
    return feel, gains


def load_tuning():
    sources = []
    T = dict(AUDIO_FALLBACK)
    feel, gains = parse_catalog(BEFORE_CATALOG)
    T.update(gains)
    T.update(feel)
    sources.append("before/VehicleAudioCatalog.lua")
    if os.path.exists(AUDIO_CATALOG):
        feel, gains = parse_catalog(AUDIO_CATALOG)
        T.update(gains)
        T.update(feel)
        sources.append("audio/after/VehicleAudioCatalog.lua")
    else:
        sources.append("built-in fallbacks for the new audio tunables")
    rows = json.load(open(BEFORE_CONFIG, encoding="utf-8"))
    layers = []
    for row in rows:
        path, attrs = row.get("path", ""), row.get("attrs", {})
        if path == "Audio/VehicleProfiles/EXOTIC_V10_AUDIO":
            T.update({k: v for k, v in attrs.items() if isinstance(v, (int, float)) and not isinstance(v, bool)})
        elif path == "Audio/Global":
            T.update({"Global." + k: v for k, v in attrs.items() if isinstance(v, (int, float)) and not isinstance(v, bool)})
        elif path.startswith("Audio/VehicleProfiles/EXOTIC_V10_AUDIO/RevLayers/") and "Rev" in attrs:
            if attrs.get("Enabled") and not attrs.get("StandIn") and attrs.get("AssetId"):
                layers.append(dict(Name=path.rsplit("/", 1)[1], **attrs))
    sources.append("before/config.json (EXOTIC_V10_AUDIO, Audio.Global, RevLayers)")
    from_config = set()
    if os.path.exists(AUDIO_CONFIG):
        try:
            spec = importlib.util.spec_from_file_location("drivetrain_feel_audio_config", AUDIO_CONFIG)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            for parent, key, value in getattr(module, "ATTRIBUTES", []):
                if parent and parent[-1] == "EXOTIC_V10_AUDIO" and isinstance(value, (int, float)) and not isinstance(value, bool):
                    T[key] = value
                    from_config.add(key)
            sources.append("audio/config.py ATTRIBUTES on EXOTIC_V10_AUDIO")
        except Exception as error:  # the audio part may be mid-edit; the listen pack still renders
            sources.append("audio/config.py unreadable (%s); skipped" % type(error).__name__)
    if "ReactorEnabled" not in from_config:
        # The catalog default is 0 (it repurposes TurboWhistle); the Exotic profile turns it on.
        T["ReactorEnabled"] = 1
        sources.append("ReactorEnabled=1 for EXOTIC_V10_AUDIO (audio part's stated profile value)")
    layers.sort(key=lambda l: l["Rev"])
    return T, layers, sources


# --------------------------------------------------------------------------------------------------------
# gearbox profile and simulations
# --------------------------------------------------------------------------------------------------------
class Profile:
    """Per-car drivetrain profile (CONTRACT 5.1, design_draft 3.1), straight-line subset."""

    def __init__(self, d, car):
        self.d, self.car = d, car
        self.ratios = [float(v) for v in str(d["GearRatios"]).split(",")][: int(d["GearCount"])]
        self.top = len(self.ratios)
        self.R, self.I, self.L = d["RedlineRpm"], d["IdleRpm"], d["LimiterRpm"]
        points = sorted((float(a), float(b)) for a, b in (p.split(":") for p in str(d["TorqueCurve"]).split(",")))
        self.cx = np.array([p[0] for p in points])
        self.cy = np.array([p[1] for p in points])
        exponent = d["GearTorqueExponent"] * d["FeelGearing"]
        self.mult = [(r / self.ratios[0]) ** exponent for r in self.ratios]
        self.Vt, self.Vb = car["TopMph"], car["BoostTopMph"]
        over = d["TopGearOverspeed"]
        self.Vg = [self.Vt * over * self.ratios[-1] / r for r in self.ratios]
        self.A1 = car["PlateauAccel"] * d["FeelAcceleration"]
        self.Rb, self.Rs = d["RollingDecel"], d["RollingDecelPerStud"]
        mt = self.mult[-1]
        self.Kd = max(self.A1 * mt * self.tau(1.0 / over) - self.Rb - self.Rs * self.Vt / MPH, 0.5) / self.Vt ** 2
        self.trac = (d["TractionG"] * car["TractionGripScale"] + d["TractionTierBonusG"] * car["TierAlpha"]) * G * d["FeelGrip"]
        self.today_A1 = car["PlateauAccel"]
        self.today_c = car["PlateauAccel"] / self.Vt ** 2       # today's aero, studs/s^2 per mph^2
        self.boost_today = self.today_c * self.Vb ** 2 - car["PlateauAccel"]
        a_top = self.A1 * mt * self.tau(1.0)                     # Overdrive: held at tau(1), no cut
        need = self.Kd * self.Vb ** 2 + self.Rb + self.Rs * self.Vb / MPH - a_top
        self.share_hi = clamp(need / self.boost_today, d["BoostShareMin"], 1.0)
        w = d["FeelWeight"]
        self.brake = max(car["TodayBrakeDecel"] + (car["NewBrakeDecel"] - car["TodayBrakeDecel"]) * w, 0.5 * car["NewBrakeDecel"])

    def tau(self, x):
        return float(np.interp(clamp(x, 0.0, 1.0), self.cx, self.cy))

    def share(self, mph):
        if not self.d["BoostShapeEnabled"]:
            return 1.0
        return 1.0 - (1.0 - self.share_hi) * smooth01(mph / self.Vb)

    def gear_for_speed(self, mph, accelerating, braking, previous):
        """VehicleDynamics.GearForSpeed (CONTRACT 3.3): remote cars' gear and rpm from speed alone."""
        d = self.d
        g = previous if previous else 1
        moved_up = False
        for _ in range(self.top + 1):
            if mph < d["StopGearMph"]:
                g = 1
                break
            x = mph / self.Vg[g - 1]
            if g < self.top and x >= (0.92 if accelerating else 0.6):
                g += 1
                moved_up = True
                continue
            if g > 1 and not moved_up:
                land = x * self.ratios[g - 2] / self.ratios[g - 1]
                if (braking and land <= d["DownshiftBrakeLand"]) or (not braking and x < 0.45):
                    g -= 1
                    continue
            break
        x = mph / self.Vg[g - 1]
        return g, clamp(x * self.R, self.I, self.L)


class NewSim:
    """The contract gearbox on a straight line. One call = one 60 Hz frame of SUBSTEPS physics steps."""

    def __init__(self, prof, mph=0.0, gear=1, anchored=False):
        self.p = prof
        self.v = mph / MPH
        self.gear = 0 if anchored else gear
        self.rpm = prof.I if (anchored or mph <= 0) else max(prof.I, mph / prof.Vg[gear - 1] * prof.R)
        self.phase, self.phase_t = None, 0.0
        self.last_shift = -10.0
        self.lim_cut, self.lim_t, self.lim_on = False, 0.0, 1.0
        self.t_lift, self.kick_t, self.prev_thr = -10.0, 0.0, 0.0
        self.L, self.dump, self.dump_t = 0.0, 0.0, 99.0
        self.was_anchored, self.was_pb = anchored, False
        self.t = 0.0
        self.shift_rev = self.lim_rev = 0
        self.kind, self.strength = "Up", 0.0
        self.events = []
        self.ws_eff, self.od = 0.0, False

    def event(self, kind, strength, old, new):
        self.shift_rev += 1
        self.kind, self.strength = kind, round(strength / 0.05) * 0.05
        self.events.append(dict(t=round(self.t, 3), kind=kind, strength=round(strength, 2), gear_from=old, gear_to=new,
                                mph=round(max(self.v, 0) * MPH, 1), rpm=int(self.rpm)))

    def shift(self, new, kind, strength):
        old = self.gear
        self.gear = new
        self.last_shift = self.t
        self.phase, self.phase_t = ("cut" if kind == "Up" else "down"), 0.0
        self.event(kind, strength, old, new)

    def limiter(self, cond, neutral, dt):
        d = self.p.d
        if self.lim_cut:
            self.lim_t += dt
            if self.lim_t >= d["LimiterCutSeconds"] and (not neutral or self.rpm <= self.p.L - d["LimiterHysteresisRpm"]):
                self.lim_cut, self.lim_on = False, 0.0
        else:
            self.lim_on += dt
            if cond and self.lim_on >= d["LimiterOnSeconds"]:
                self.lim_cut, self.lim_t = True, 0.0
                self.lim_rev += 1
        return self.lim_cut

    def substep(self, u, dt):
        p, d = self.p, self.p.d
        thr, brk, boost = u["thr"], u["brake"], u["boost"]
        R, I = p.R, p.I
        dz = 0.02
        gearing = d["FeelGearing"]
        if thr < d["CruiseThrottleMin"] <= self.prev_thr:
            self.t_lift = self.t
        self.prev_thr = thr
        self.kick_t = self.kick_t + dt if thr >= d["KickdownThrottle"] else 0.0
        target = u["spin"] * d["FeelSpin"] if d["FeelSpin"] > 0 else 0.0
        target = clamp(target, 0.0, 1.0)
        rate = d["SpinBuildRate"] if target > self.L else (d["SpinCatchRate"] if u["catch"] else d["SpinDecayRate"])
        self.L = clamp(self.L + (target - self.L) * (1.0 - math.exp(-rate * dt)), 0.0, 1.0)

        if u["anchored"]:
            # Neutral revs (CONTRACT 5.2 rule 9): no force, gear N, the limiter bounces on rpm.
            self.gear, self.v, self.od, self.ws_eff = 0, 0.0, False, 0.0
            tgt = I + thr * (d["NeutralRevTarget"] * R - I) if d["NeutralRevEnabled"] else I
            cut = self.limiter(self.rpm >= p.L, True, dt)
            if cut:
                tgt = I
            tau = d["EngineRiseSeconds"] * (1.0 if tgt > self.rpm else d["EngineFallScale"])
            self.rpm += (tgt - self.rpm) * (1.0 - math.exp(-dt / tau))
            self.was_anchored = True
            self.t += dt
            return thr * (0.0 if cut else 1.0), 1.0 if cut else 0.0
        if self.was_anchored:
            # GO: gear 1, launch slip (approximated as a dump scaled by throttle), the grace begins.
            self.was_anchored = False
            self.gear = 1
            self.event("Launch", max(0.3, thr), 0, 1)
            self.dump, self.dump_t = d["PowerBrakeDumpSlip"] * thr, 0.0
        pb = u["pb_hold"]
        if self.was_pb and not pb:
            self.dump, self.dump_t = d["PowerBrakeDumpSlip"], 0.0
            self.event("Launch", 1.0, 1, 1)
        self.was_pb = pb
        if pb:
            self.v, self.gear = 0.0, 1

        g = self.gear
        fwd = max(self.v, 0.0) * MPH
        x = fwd / p.Vg[g - 1]
        rpm_road = x * R
        self.od = bool(d["OverdriveEnabled"]) and boost and g == p.top and rpm_road >= R
        base = max(rpm_road, I + thr * (d["LaunchRpmFraction"] * R - I)) if (g == 1 and thr > dz) else rpm_road
        base = max(base, I)
        a_raw = p.A1 * p.mult[g - 1] * p.tau(self.rpm / R) * thr
        ws = max(0.0, a_raw / p.trac - 1.0)
        ws_eff = ws * (1.0 - d["TractionAssist"])
        self.dump_t += dt
        window = d["SpinWindowSeconds"]
        if self.dump_t < window:
            ws_eff += self.dump * (1.0 - self.dump_t / window)
        self.ws_eff = ws_eff
        tgt = min(base * (1.0 + d["ThrustSlipFlare"] * min(ws_eff, 0.5)), 1.01 * R)
        if self.L > 0.1:  # spin: free-rev target 0.85*R*thr, gear held
            tgt += (max(I, 0.85 * R * thr) - tgt) * smooth01((self.L - 0.1) / 0.3)
        if self.od:
            tgt = R

        cut_len = d["ShiftCutSeconds"] * gearing
        blend_len = d["ShiftBlendSeconds"] * gearing
        k_cut = clamp(1.0 - (1.0 - d["ShiftCutTorque"]) * gearing, 0.0, 1.0)
        k, cutting = 1.0, False
        if self.phase == "cut":
            k, cutting = k_cut, True
            self.phase_t += dt
            if self.phase_t >= cut_len:
                self.phase, self.phase_t = "blend", 0.0
        elif self.phase == "blend":
            self.phase_t += dt
            k = k_cut + (1.0 - k_cut) * min(1.0, self.phase_t / max(blend_len, 1e-6))
            if self.phase_t >= blend_len:
                self.phase = None
        elif self.phase == "down":
            self.phase_t += dt
            if self.phase_t >= d["DownshiftBlendSeconds"]:
                self.phase = None
        if self.phase is not None:
            tau = d["ShiftRpmSeconds"] / max(gearing, 0.05)
        else:
            tau = d["EngineRiseSeconds"] * (1.0 if tgt > self.rpm else d["EngineFallScale"])
        self.rpm += (tgt - self.rpm) * (1.0 - math.exp(-dt / tau))
        if self.od:
            self.rpm = R
        lim = self.limiter(rpm_road >= R and not self.od and thr > dz, False, dt)

        a_drive = a_raw if a_raw <= p.trac else p.trac * (1.0 - (1.0 - d["SlideGripFraction"]) * smooth01(ws_eff / 0.6))
        a_drive *= k * (1.0 - d["SpinThrustLoss"] * self.L) * (0.0 if lim else 1.0)
        if self.od:
            a_drive = p.A1 * p.mult[-1] * p.tau(1.0) * thr
        if pb:
            a_drive = 0.0
        speed = abs(self.v)
        mph = speed * MPH
        sign = self.v / max(speed, 0.8)
        resist = p.Kd * mph * mph + p.Rb + p.Rs * speed
        engine_brake = 0.0
        if thr <= dz and g >= 1 and fwd > 0 and not cutting:
            engine_brake = d["EngineBrakeDecel"] * d["FeelEngineBrake"] * (p.mult[g - 1] / p.mult[-1]) * (0.35 + 0.65 * self.rpm / R)
        brake = 0.0 if pb else brk * p.brake
        boost_a = p.boost_today * p.share(mph) if boost else 0.0
        acc = a_drive + boost_a - sign * (resist + engine_brake + brake + SPIN_SCRUB * self.L)
        guard = d["SpeedGuardOverBoostTop"] * p.Vb
        if mph > guard:
            acc -= (mph - guard) / MPH * d["SpeedGuardStrength"]
        self.v = max(0.0, self.v + acc * dt)
        if pb:
            self.v = 0.0
        self.shift_logic(thr, brk)
        self.t += dt
        load = thr if pb else thr * (0.0 if cutting else k) * (0.0 if lim else 1.0)
        return load, 1.0 if (cutting or lim) else 0.0

    def shift_logic(self, thr, brk):
        p, d = self.p, self.p.d
        g = self.gear
        if g < 1:
            return
        fwd = max(self.v, 0.0) * MPH
        if fwd < d["StopGearMph"]:
            self.gear = 1
            return
        if self.t - self.last_shift < d["ShiftMinIntervalSeconds"]:
            return
        x = fwd / p.Vg[g - 1]
        hold = self.L > 0.1
        if g < p.top:
            on_limiter = x >= 1.0
            if thr >= 0.9:
                U = d["UpshiftFlat"]
            elif thr >= 0.3:
                U = d["UpshiftPartLow"] + (d["UpshiftPartHigh"] - d["UpshiftPartLow"]) * (thr - 0.3) / 0.6
            elif thr > d["CruiseThrottleMin"]:
                U = d["UpshiftCruise"]
            else:
                U = None
            lifted = self.t - self.t_lift < d["LiftHoldSeconds"]
            if U is not None and ((not hold and not lifted) or on_limiter):
                land = x * p.ratios[g] / p.ratios[g - 1]
                if (x >= U and (thr >= 0.3 or land >= d["UpshiftMinLand"])) or on_limiter:
                    self.shift(g + 1, "Up", 1.0 if thr >= 0.9 else 0.3 + 0.7 * thr)
                    return
        if g > 1 and not hold:
            land = x * p.ratios[g - 2] / p.ratios[g - 1]
            if brk > 0 and land <= d["DownshiftBrakeLand"]:
                self.shift(g - 1, "Down", 0.5)
                return
            if thr <= 0.02 and brk <= 0 and x < d["DownshiftCoastFraction"] and land <= d["DownshiftCoastLand"]:
                self.shift(g - 1, "Down", 0.5)
                return
            if self.kick_t >= d["KickdownHoldSeconds"] and x < d["KickdownBelowFraction"]:
                for g2 in range(1, g):
                    if x * p.ratios[g2 - 1] / p.ratios[g - 1] <= d["KickdownLand"]:
                        self.shift(g2, "Down", 0.5)
                        return

    def frame(self, inputs_at, t0):
        dt = 1.0 / (FRAME_HZ * SUBSTEPS)
        loads, cuts = 0.0, 0.0
        for s in range(SUBSTEPS):
            load, cut = self.substep(inputs_at(t0 + s * dt), dt)
            loads += load
            cuts += cut
        p = self.p
        return dict(mph=max(self.v, 0.0) * MPH, rpm=round(self.rpm / 10.0) * 10.0, gear=self.gear,
                    load=round(loads / SUBSTEPS / 0.02) * 0.02, cut=round(cuts / SUBSTEPS / 0.1) * 0.1,
                    shift_rev=self.shift_rev, shift_kind=self.kind, shift_strength=self.strength, lim_rev=self.lim_rev,
                    spin=round(self.L / 0.05) * 0.05, od=1.0 if self.od else 0.0,
                    thrust_slip=round(clamp(self.ws_eff, 0, 1) / 0.05) * 0.05, slip=0.9 * self.L,
                    x=(max(self.v, 0.0) * MPH / p.Vg[self.gear - 1]) if self.gear >= 1 else 0.0)


class TodaySim:
    """Today's longitudinal model for the same car (survey_pr98-drive-model section 1), no gears."""

    def __init__(self, prof, mph=0.0, **_):
        self.p, self.v, self.t, self.events = prof, mph / MPH, 0.0, []

    def frame(self, inputs_at, t0):
        p = self.p
        dt = 1.0 / (FRAME_HZ * SUBSTEPS)
        for s in range(SUBSTEPS):
            u = inputs_at(t0 + s * dt)
            if u["anchored"] or u["pb_hold"]:
                self.v = 0.0
                continue
            mph = self.v * MPH
            acc = p.today_A1 * (0.7 + 0.3 * smooth01(mph / 10.0)) * u["thr"] - p.today_c * mph * mph
            if u["thr"] <= 0.02 and u["brake"] <= 0:
                acc -= 3.2 + 0.06 * abs(self.v)
            acc -= p.car["TodayBrakeDecel"] * u["brake"]
            if u["boost"]:
                acc += p.boost_today
            self.v = max(0.0, self.v + acc * dt)
            self.t += dt
        return dict(mph=self.v * MPH, rpm=None, gear=None, load=None, cut=0.0, shift_rev=0, shift_kind="Up", shift_strength=0.0,
                    lim_rev=0, spin=0.0, od=0.0, thrust_slip=0.0, slip=0.0, x=0.0)


def run(sim, scenario):
    """Drive `sim` through a scenario at 60 Hz; returns per-frame telemetry plus pop events (DrivingClient producer)."""
    duration = scenario["duration"]
    n = int(duration * FRAME_HZ)
    frames = []
    rng = np.random.default_rng(scenario.get("seed", 7))
    pops, high_t, queue = [], 0.0, []

    def inputs_at(t):
        u = dict(thr=0.0, brake=0.0, boost=False, anchored=False, pb_hold=False, spin=0.0, catch=False)
        u.update(scenario["inputs"](t))
        return u

    for i in range(n):
        t = i / FRAME_HZ
        u = inputs_at(t)
        fr = sim.frame(inputs_at, t)
        fr.update(t=t, thr=u["thr"], brake=u["brake"], boost=u["boost"], anchored=u["anchored"])
        frames.append(fr)
        # Exhaust pops: after 0.8 s of throttle > 0.6 above 40 mph, a lift to <= 0.1 with no boost fires one bang
        # (0.9-1.0) and 3-6 pops (0.5-0.79) spaced 0.05-0.17 s (DrivingClient.publishFeelState).
        if u["thr"] > 0.6 and fr["mph"] > 40 and not u["boost"]:
            high_t += 1.0 / FRAME_HZ
        elif u["thr"] <= 0.1 and not u["boost"] and high_t >= 0.8:
            when = t
            queue.append((when, rng.uniform(0.9, 1.0)))
            for _ in range(int(rng.integers(3, 7))):
                when += rng.uniform(0.05, 0.17)
                queue.append((when, rng.uniform(0.5, 0.79)))
            high_t = 0.0
        elif u["thr"] <= 0.6:
            high_t = 0.0
    pops = sorted(queue)
    return frames, pops


# --------------------------------------------------------------------------------------------------------
# audio port
# --------------------------------------------------------------------------------------------------------
def load_sounds(mode, reactor="whine", slip_strain="grav_skid"):
    """mode "today": today's loops; "new": the v2 upload candidates; "interim": the new gearbox rules with only the
    sounds already uploaded (today's V10 loops, turbine_high in TurboWhistle, blank shift slots), i.e. what plays
    after the code install and before any new upload."""
    def rd(folder, name):
        path = os.path.join(folder, name + ".wav")
        if not os.path.exists(path):
            raise SystemExit("missing %s: run make_exotic_v2.py first" % path)
        return read_wav(path)

    snd = {}
    engine_dir = V2_DIR if mode == "new" else TODAY_DIR
    for name in ("v10_idle_1000", "v10_on_2000", "v10_on_3500", "v10_on_5000", "v10_on_6500", "v10_on_8000",
                 "v10_off_3000", "v10_off_6000"):
        snd[name] = rd(engine_dir, name)
    for slot, name in (("SuperchargerWhine", "supercharger_whine"), ("TurbineLow", "turbine_low"), ("EnergyHum", "energy_hum"),
                       ("BoostBody", "thruster_roar"), ("WindBuffet", "wind_buffet"), ("BoostLoop", "boost_loop"),
                       ("DriverWind", "wind_rush"), ("BoostIgnition", "boost_ignite"), ("Pop1", "pop_1"), ("Pop2", "pop_2"),
                       ("Pop3", "pop_3"), ("Pop4", "pop_4"), ("Bang1", "bang_1"), ("Bang2", "bang_2")):
        snd[slot] = rd(TODAY_DIR, name)
    snd["SlipStrain"] = rd(TODAY_DIR, "stabiliser_strain")
    if mode == "interim":
        snd["TurboWhistle"] = rd(TODAY_DIR, "turbine_high")
    if mode == "new":
        snd["TurboWhistle"] = rd(V2_DIR, "reactor_whine" if reactor == "whine" else "reactor_core_alt")
        if slip_strain == "grav_skid":
            snd["SlipStrain"] = rd(V2_DIR, "grav_skid")
        for slot, name in (("ShiftThunk1", "shift_thunk_1"), ("ShiftThunk2", "shift_thunk_2"),
                           ("ShiftVent1", "shift_vent_1"), ("ShiftVent2", "shift_vent_2")):
            snd[slot] = rd(V2_DIR, name)
    return snd


class Track:
    """One voice's per-tick gain (driveVoice follower) and pitch (PlaybackSpeed, clamped 0.5..2)."""

    def __init__(self, n):
        self.gain = np.zeros(n)
        self.pitch = np.ones(n)
        self.g = 0.0

    def drive(self, i, target, pitch, dt, rise, fall):
        target = max(0.0, target)
        self.g = follow(self.g, target, dt, rise if target > self.g else fall)
        if target <= 0 and self.g < 0.0005:
            self.g = 0.0
        self.gain[i] = self.g
        self.pitch[i] = clamp(pitch, 0.5, 2.0)


def render_loop(buf, track, hz, n_samples, start=0.0):
    if track.gain.max() <= 0:
        return np.zeros(n_samples)
    tf = np.arange(len(track.gain)) / hz
    ts = np.arange(n_samples) / SR
    g = np.interp(ts, tf, track.gain)
    p = np.interp(ts, tf, track.pitch)
    pos = start * len(buf) + np.cumsum(p) - p[0]
    i = np.floor(pos).astype(np.int64)
    fr = pos - i
    i %= len(buf)
    return g * (buf[i] * (1.0 - fr) + buf[(i + 1) % len(buf)] * fr)


def add_oneshot(out, buf, t0, gain, pitch):
    i0 = int(t0 * SR)
    if gain <= 0 or i0 >= len(out):
        return
    m = int((len(buf) - 1) / pitch)
    y = np.interp(np.arange(m) * pitch, np.arange(len(buf)), buf) * gain
    m = min(m, len(out) - i0)
    out[i0:i0 + m] += y[:m]


def stft_bus(x, frames_t, load_f, rev_f, on_f, T):
    """APPROXIMATE engine sub-bus: Peak sweep (AudioFilter) + 3-band tilt (AudioEqualizer), as an STFT magnitude
    filter driven per 60 Hz tick by load and rev (audio part's updateEngineBus rule)."""
    N, H = 2048, 512
    win = 0.5 - 0.5 * np.cos(2.0 * np.pi * np.arange(N) / N)
    pad = np.concatenate([np.zeros(N), x, np.zeros(N)])
    out = np.zeros_like(pad)
    f = np.fft.rfftfreq(N, 1.0 / SR)
    f[0] = 1.0
    w_low = 1.0 / (1.0 + (f / 400.0) ** 4)
    w_high = 1.0 / (1.0 + (4000.0 / f) ** 4)
    w_mid = np.clip(1.0 - w_low - w_high, 0.0, 1.0)
    lo_hz, hi_hz = T["EngineSweepLowHz"], T["EngineSweepHighHz"]
    for start in range(0, len(pad) - N, H):
        tc = (start + N / 2 - N) / SR
        load = float(np.interp(tc, frames_t, load_f))
        rev = float(np.interp(tc, frames_t, rev_f))
        on = float(np.interp(tc, frames_t, on_f)) > 0.5
        seg = pad[start:start + N] * win
        if on:
            pos = clamp(load + (rev - load) * T["EngineSweepRevShare"], 0.0, 1.0)
            hz = lo_hz * (hi_hz / lo_hz) ** pos
            bell = T["EngineSweepDb"] * load / (1.0 + ((f / hz - hz / f) * T["EngineSweepQ"]) ** 2)
            low = T["EngineTiltLowOffDb"] + (T["EngineTiltLowOnDb"] - T["EngineTiltLowOffDb"]) * load
            mid = T["EngineTiltMidOffDb"] + (T["EngineTiltMidOnDb"] - T["EngineTiltMidOffDb"]) * load
            high = T["EngineTiltHighOffDb"] + (T["EngineTiltHighOnDb"] - T["EngineTiltHighOffDb"]) * load
            gain = 10.0 ** ((bell + low * w_low + mid * w_mid + high * w_high) / 20.0)
            seg = np.fft.irfft(np.fft.rfft(seg) * gain, N)
        out[start:start + N] += seg
    return out[N:N + len(x)] / 2.0  # periodic Hann at 75 % overlap sums to 2


def tremolo(n_samples, active_f, frames_t, T):
    """APPROXIMATE AudioTremolo (Frequency, Depth, Duty, Square), free-running, only where active."""
    ts = np.arange(n_samples) / SR
    phase = (ts * T["LimiterTremoloHz"]) % 1.0
    square = np.clip((T["LimiterTremoloDuty"] - phase) * 200.0 + 0.5, 0.0, 1.0)
    sine = 0.5 + 0.5 * np.cos(2.0 * np.pi * phase)
    shape = (1.0 - T["LimiterTremoloSquare"]) * sine + T["LimiterTremoloSquare"] * square
    gain = 1.0 - T["LimiterTremoloDepth"] * (1.0 - shape)
    act = np.interp(ts, frames_t, active_f)
    return 1.0 + (gain - 1.0) * act


def ladder_weights(ladder, log_f):
    """Equal-power cos/sin crossfade between the two loops either side of the frequency (VehicleAudioClient)."""
    w = {}
    if not ladder:
        return w
    if len(ladder) == 1 or log_f <= ladder[0]["logf"]:
        w[ladder[0]["key"]] = 1.0
        return w
    if log_f >= ladder[-1]["logf"]:
        w[ladder[-1]["key"]] = 1.0
        return w
    for a, b in zip(ladder, ladder[1:]):
        if log_f <= b["logf"]:
            span = b["logf"] - a["logf"]
            alpha = (log_f - a["logf"]) / span if span > 0 else 1.0
            w[a["key"]] = math.cos(alpha * HALF_PI)
            w[b["key"]] = math.sin(alpha * HALF_PI)
            return w
    return w


def layer_file(layer):
    m = re.match(r"V10(Idle|On|Off)(\d+)", layer["Name"])
    return "v10_%s_%s" % (m.group(1).lower(), m.group(2))


def build_voices(T, layers, local, mode, prof):
    """buildFeel: local = every layer (+ twins inside MaxRevLayerPlayers 14); remote = three voices."""
    base = T["RevPitchBase"]
    chosen = [l for l in layers if local or l["Load"] != "Off"]
    if not local and len(chosen) > 3:
        if mode == "new":  # gearedVoices: loops nearest RemoteVoiceLow..HighFraction of redline
            picks = []
            for idx in range(3):
                frac = T["RemoteVoiceLowFraction"] + (T["RemoteVoiceHighFraction"] - T["RemoteVoiceLowFraction"]) * idx / 2
                rev = clamp((frac * prof.R - T["RevRpmMin"]) / (T["RevRpmMax"] - T["RevRpmMin"]), 0, 1)
                want = math.log(base + (1 - base) * rev)
                best = min((l for l in chosen if l not in picks), key=lambda l: abs(math.log(base + (1 - base) * l["Rev"]) - want))
                picks.append(best)
            chosen = [l for l in chosen if l in picks]
        else:  # thinned(): evenly through the list
            count = 3
            chosen = [chosen[int(math.floor(i * (len(chosen) - 1) / (count - 1) + 0.5))] for i in range(count)]
    voices = []
    for layer in chosen:
        load = layer["Load"] if local else "Any"
        freq = base + (1 - base) * layer["Rev"]
        voices.append(dict(key=layer["Name"], layer=layer, file=layer_file(layer), load=load, freq=freq, logf=math.log(freq), detune=1.0))
    has_on = any(v["load"] == "On" for v in voices)
    has_off = any(v["load"] == "Off" for v in voices)
    for v in voices:
        if (v["load"] == "On" and not has_off) or (v["load"] == "Off" and not has_on):
            v["load"] = "Any"
    on_ladder = [v for v in voices if v["load"] != "Off"]
    off_ladder = [v for v in voices if v["load"] != "On"]
    d = T["RevNeighbourDetune"]
    for idx, v in enumerate(on_ladder, 1):
        v["detune"] = 1 + (d if idx % 2 == 0 else -d)
    for idx, v in enumerate(off_ladder, 1):
        if v["load"] == "Off":
            v["detune"] = 1 + (d if idx % 2 == 0 else -d)
    budget = 14 - len(voices)
    if local:
        for v in on_ladder:
            if budget <= 0:
                break
            if v["layer"].get("Twin"):
                v["twin"] = True
                budget -= 1
    return voices, on_ladder, off_ladder


def render_local(frames, pops, snd, T, layers, prof, mode, bus_on=True, stems=False):
    """VehicleAudioClient.updateFeel for the local driver at 60 Hz, then audio. mode "today" runs today's rules;
    "new" and "interim" run the drivetrain_feel rules (they differ only in the sound set passed in)."""
    new_rules = mode != "today"
    n = len(frames)
    dt = 1.0 / FRAME_HZ
    n_samples = int(n * SR / FRAME_HZ)
    rng = np.random.default_rng(11)
    voices, on_ladder, off_ladder = build_voices(T, layers, True, mode, prof)
    tracks = {v["key"]: Track(n) for v in voices}
    twins = {v["key"]: Track(n) for v in voices if v.get("twin")}
    loop_names = ["SuperchargerWhine", "TurbineLow", "EnergyHum", "SlipStrain", "BoostBody", "WindBuffet", "BoostLoop", "DriverWind"]
    if new_rules and T["ReactorEnabled"] > 0:
        loop_names.append("TurboWhistle")
    loops = {name: Track(n) for name in loop_names}
    oneshots = []
    bus_load, bus_rev, bus_on_f, dip_f, lim_f = (np.zeros(n) for _ in range(5))
    smoothing = T.get("Global.RevLayerSmoothingSeconds", 0.025)
    fade_in, fade_out = T.get("Global.FeelLayerFadeInSeconds", 0.05), T.get("Global.FeelLayerFadeOutSeconds", 0.12)
    f = dict(Load=0.0, LoadSlow=0.0, Rev=0.0, LineRev=0.0, Duck=0.0, BoostDuck=0.0, LifePitch=0.0, LifeLevel=0.0,
             DropTimer=0.0, DropRev=0.0, BlipTimer=0.0, DipTimer=0.0, DipEnv=0.0, DipDb=0.0, ChirpTimer=0.0,
             LimiterAge=math.inf, ShiftRev=None, LimRev=None, Thunk=0, Vent=0, Boost=False)
    pop_bags = {"Pop": [], "Bang": []}
    last_pop = {}
    pop_i = 0
    twin_gain = T["TwinEngineGain"]
    twin_share = 1.0 / math.sqrt(1.0 + twin_gain * twin_gain)

    def gain_of(name):
        return T.get(name + "Gain", 0.5)

    def pitch_range(name, alpha):
        lo, hi = T.get(name + "PitchMin"), T.get(name + "PitchMax")
        base = T.get(name + "Pitch", 1.0)
        if lo is None or hi is None:
            return base
        return base * (lo + (hi - lo) * clamp(alpha, 0, 1))

    def play_pop(t, strength):
        kind = "Bang" if strength >= T["PopBangStrength"] else "Pop"
        bag = pop_bags[kind]
        if not bag:
            bag.extend(["Pop1", "Pop2", "Pop3", "Pop4"] if kind == "Pop" else ["Bang1", "Bang2"])
            rng.shuffle(bag)
            if len(bag) > 1 and bag[-1] == last_pop.get(kind):
                bag[-1], bag[0] = bag[0], bag[-1]
        name = bag.pop()
        last_pop[kind] = name
        oneshots.append((t, name, gain_of(name) * strength, 1 + T["PopPitchJitter"] * (2 * rng.random() - 1)))

    def play_pair(t, names, counter, strength):
        for _ in names:  # an empty slot gives way to the other; a blank pair is silent
            f[counter] = f[counter] % 2 + 1
            name = names[f[counter] - 1]
            if name in snd:
                oneshots.append((t, name, gain_of(name) * strength, 1 + T["ShiftPitchJitter"] * (2 * rng.random() - 1)))
                return True
        return False

    for i, fr in enumerate(frames):
        t = fr["t"]
        speed = fr["mph"]
        throttle = fr["thr"]
        engine_rpm = fr["rpm"] if (new_rules and T["RpmRevEnabled"] > 0) else None
        blip = 0.0
        if engine_rpm is not None:
            if f["ShiftRev"] is None:
                f["ShiftRev"] = fr["shift_rev"]
            elif fr["shift_rev"] != f["ShiftRev"]:
                f["ShiftRev"] = fr["shift_rev"]
                strength = clamp(fr["shift_strength"], 0, 1)
                if T["ReactorEnabled"] > 0:
                    f["ChirpTimer"] = T["ReactorChirpSeconds"]
                if T["ShiftAudioEnabled"] > 0:
                    play_pair(t, ("ShiftThunk1", "ShiftThunk2"), "Thunk", strength)
                    if fr["shift_kind"] == "Up":
                        f["BlipTimer"], f["DipTimer"], f["DipDb"], f["DropTimer"] = 0.0, 0.0, T["ShiftDipDb"] * strength, 0.0
                        if fr["gear"] >= 1:
                            land = clamp(speed / prof.Vg[fr["gear"] - 1] * prof.R, prof.I, prof.L)
                            f["DropRev"] = clamp((land - T["RevRpmMin"]) / (T["RevRpmMax"] - T["RevRpmMin"]), 0, 1)
                            f["DropTimer"] = T["ShiftDropMaxSeconds"]
                        if strength >= T["ShiftVentMinStrength"] and not play_pair(t, ("ShiftVent1", "ShiftVent2"), "Vent", strength)                                 and T["ShiftCrackleEnabled"] > 0:
                            play_pop(t, T["ShiftCracklePop"] * strength)  # direct pop, never via FeelPopRevision
                    elif fr["shift_kind"] == "Down":
                        f["DropTimer"], f["BlipTimer"] = 0.0, T["DownshiftBlipSeconds"]
            f["LimiterAge"] += dt
            if f["LimRev"] is None:
                f["LimRev"] = fr["lim_rev"]
            elif fr["lim_rev"] != f["LimRev"]:
                f["LimRev"], f["LimiterAge"] = fr["lim_rev"], 0.0
            if f["BlipTimer"] > 0:
                f["BlipTimer"] = max(0.0, f["BlipTimer"] - dt)
                blip = math.sin(math.pi * (1 - f["BlipTimer"] / T["DownshiftBlipSeconds"]))

        load_target = clamp(max(0.0, throttle), 0, 1)
        if engine_rpm is not None and fr["load"] is not None:
            load_target = clamp(fr["load"], 0, 1)
        if blip > 0:
            load_target = max(load_target, T["DownshiftBlipLoad"] * blip)
        f["Load"] = follow(f["Load"], load_target, dt, T["LoadAttackSeconds"] if load_target > f["Load"] else T["LoadReleaseSeconds"])
        f["LoadSlow"] = follow(f["LoadSlow"], f["Load"], dt, T["BarkSeconds"])
        load = clamp(f["Load"], 0, 1) ** T["LoadExponent"]
        bark = T["BarkGain"] * max(0.0, f["Load"] - f["LoadSlow"])
        on_w, off_w = math.sin(load * HALF_PI), math.cos(load * HALF_PI)

        boost_amount = 1.0 if fr["boost"] else 0.0
        rev_target = clamp(T["RevThrottleWeight"] * load + T["RevSpeedWeight"] * speed / T["RevReferenceMph"] + T["RevBoostWeight"] * boost_amount, 0, 1)
        rev_seconds = T["RevRiseSeconds"] if rev_target > f["Rev"] else T["RevFallSeconds"]
        if engine_rpm is not None:
            f["LineRev"] = follow(f["LineRev"], rev_target, dt, T["RevRiseSeconds"] if rev_target > f["LineRev"] else T["RevFallSeconds"])
            rev_target = clamp((engine_rpm - T["RevRpmMin"]) / (T["RevRpmMax"] - T["RevRpmMin"]), 0, 1)
            rev_seconds = T["RevRpmSmoothingSeconds"]
            if f["DropTimer"] > 0:
                f["DropTimer"] -= dt
                if f["DropTimer"] > 0 and rev_target > f["DropRev"] + 0.02:
                    rev_target, rev_seconds = f["DropRev"], T["ShiftDropSeconds"] / 3
                else:
                    f["DropTimer"] = 0.0
            if blip > 0:
                rev_target = min(1.0, rev_target + T["DownshiftBlipRev"] * blip)
        f["Rev"] = follow(f["Rev"], rev_target, dt, rev_seconds)
        if engine_rpm is None:
            f["LineRev"] = f["Rev"]
        rev = f["Rev"]
        line_rev = f["LineRev"] + (f["Rev"] - f["LineRev"]) * T["SciFiRpmShare"]

        theta = min(0.5, dt / T["LifeSeconds"])
        for key in ("LifePitch", "LifeLevel"):
            f[key] = clamp(f[key] - f[key] * theta + math.sqrt(2 * theta) * rng.standard_normal(), -2.5, 2.5)
        life_pitch = 1 + T["LifePitchDepth"] * f["LifePitch"]
        life_level = 10 ** (T["LifeLevelDb"] * f["LifeLevel"] / 20)

        slip_i = smoothstep(T["SlipStart"], T["SlipFull"], abs(fr["slip"]))
        if engine_rpm is not None and fr["spin"]:
            slip_i = max(slip_i, clamp(fr["spin"] * T["SpinStrainGain"], 0, 1))
        f["Duck"] = follow(f["Duck"], slip_i, dt, T["SlipDuckInSeconds"] if slip_i > f["Duck"] else T["SlipDuckOutSeconds"])
        f["BoostDuck"] = follow(f["BoostDuck"], boost_amount, dt, T["BoostDuckInSeconds"] if boost_amount > f["BoostDuck"] else T["BoostDuckOutSeconds"])
        engine_duck = 10 ** (-(T["SlipDuckDb"] * f["Duck"] + T["BoostDuckDb"] * f["BoostDuck"]) / 20)

        dip = 1.0
        if f["DipDb"] > 0:
            f["DipTimer"] += dt
            holding = f["DipTimer"] < T["ShiftDipMinSeconds"] or (fr["cut"] > 0 and f["DipTimer"] < T["ShiftDipMaxSeconds"])
            f["DipEnv"] = follow(f["DipEnv"], 1.0 if holding else 0.0, dt, T["ShiftDipAttackSeconds"] if holding else T["ShiftDipReleaseSeconds"])
            if not holding and f["DipEnv"] < 0.01:
                f["DipEnv"], f["DipDb"] = 0.0, 0.0
            dip = 10 ** (-f["DipDb"] * f["DipEnv"] / 20)
        bus_active = engine_rpm is not None and bus_on and T["EngineBusEnabled"] > 0
        limiter = False
        if engine_rpm is not None and T["LimiterTremoloEnabled"] > 0 and (fr["cut"] > 0 or f["LimiterAge"] < T["LimiterHoldSeconds"]):
            limiter = engine_rpm >= prof.L - T["LimiterNearRpm"]
        bus_load[i], bus_rev[i], bus_on_f[i] = load, rev, 1.0 if bus_active else 0.0
        dip_f[i] = dip
        lim_f[i] = 1.0 if (limiter and bus_active) else 0.0

        frequency = T["RevPitchBase"] + (1 - T["RevPitchBase"]) * rev
        log_f = math.log(frequency)
        on_ws, off_ws = ladder_weights(on_ladder, log_f), ladder_weights(off_ladder, log_f)
        engine_gain = T["RevMasterGain"] * engine_duck * life_level * (1.0 if bus_active else dip)
        for v in voices:
            layer = v["layer"]
            on, off = on_ws.get(v["key"], 0.0), off_ws.get(v["key"], 0.0)
            if v["load"] == "On":
                weight = on * on_w * (1 + bark)
            elif v["load"] == "Off":
                weight = off * off_w
            else:
                weight = on * on_w * on_w * (1 + bark) + off * off_w * off_w * T["RevOffLoadGain"]
            gain = layer["Gain"] * weight * engine_gain
            pitch = clamp(layer.get("Pitch", 1) * frequency / v["freq"], layer["PitchMin"], layer["PitchMax"]) * v["detune"]
            if v.get("twin"):
                tracks[v["key"]].drive(i, gain * twin_share, pitch * life_pitch, dt, smoothing, smoothing * 2)
                twins[v["key"]].drive(i, gain * twin_share * twin_gain, pitch * (1 + T["TwinEngineDetune"]) * (2 - life_pitch), dt, smoothing, smoothing * 2)
            else:
                tracks[v["key"]].drive(i, gain, pitch * life_pitch, dt, smoothing, smoothing * 2)

        # feel loops (local driver)
        if "TurboWhistle" in loops:
            chirp = 1.0
            if f["ChirpTimer"] > 0:
                f["ChirpTimer"] = max(0.0, f["ChirpTimer"] - dt)
                chirp = 1 - T["ReactorChirpDepth"] * math.sin(math.pi * (1 - f["ChirpTimer"] / T["ReactorChirpSeconds"]))
            r_gain = T["ReactorGain"] * (T["ReactorLoadFloor"] + (1 - T["ReactorLoadFloor"]) * load) * (1 + T["ReactorOverdriveGain"] * fr["od"])
            r_pitch = T.get("TurboWhistlePitch", 1) * chirp * (T["ReactorPitchMin"] + (T["ReactorPitchMax"] - T["ReactorPitchMin"]) * clamp(speed / T["ReactorFullMph"], 0, 1))
            loops["TurboWhistle"].drive(i, r_gain, r_pitch, dt, fade_in, fade_out)
        loops["SuperchargerWhine"].drive(i, gain_of("SuperchargerWhine") * rev ** T["SuperchargerGainExponent"]
                                         * (T["SuperchargerOffLoadGain"] + (1 - T["SuperchargerOffLoadGain"]) * load),
                                         pitch_range("SuperchargerWhine", rev), dt, fade_in, fade_out)
        t_gain = smoothstep(T["TurbineStartRev"], 1, line_rev) * (T["TurbineOffLoadGain"] + (1 - T["TurbineOffLoadGain"]) * load)
        octave = T["TurbineOctaveStart"] + T["TurbineOctaves"] * line_rev
        loops["TurbineLow"].drive(i, gain_of("TurbineLow") * t_gain, T.get("TurbineLowPitch", 1) * 2 ** octave, dt, fade_in, fade_out)
        loops["EnergyHum"].drive(i, gain_of("EnergyHum"), pitch_range("EnergyHum", speed / T["RevReferenceMph"]), dt, fade_in, fade_out)
        loops["SlipStrain"].drive(i, gain_of("SlipStrain") * slip_i, pitch_range("SlipStrain", slip_i), dt, fade_in, fade_out)
        loops["BoostBody"].drive(i, gain_of("BoostBody") * boost_amount, pitch_range("BoostBody", line_rev), dt,
                                 T["BoostFadeInSeconds"], T.get("Global.BoostFadeOutSeconds", 0.14))
        loops["WindBuffet"].drive(i, gain_of("WindBuffet") * smoothstep(T["WindBuffetStartMph"], T["WindBuffetFullMph"], speed),
                                  pitch_range("WindBuffet", range_alpha(speed, T["WindBuffetStartMph"], T["WindBuffetFullMph"])), dt,
                                  T.get("Global.WindFadeInSeconds", 0.35), T.get("Global.WindFadeOutSeconds", 0.45))
        # standard layers (updateGraph at 15 Hz in game; driven per tick here)
        b_pitch = T.get("BoostLoopRevPitchMin", 0.9) + (T.get("BoostLoopRevPitchMax", 1.15) - T.get("BoostLoopRevPitchMin", 0.9)) * line_rev
        loops["BoostLoop"].drive(i, gain_of("BoostLoop") * boost_amount, b_pitch, dt, T["BoostFadeInSeconds"], T.get("Global.BoostFadeOutSeconds", 0.14))
        wind = clamp(speed / T["DriverWindFullMph"], 0, 1) ** T["DriverWindExponent"] * range_alpha(speed, T["DriverWindStartMph"] * 0.6, T["DriverWindStartMph"])
        w_pitch = T["DriverWindSpeedPitchMin"] + (T["DriverWindSpeedPitchMax"] - T["DriverWindSpeedPitchMin"]) * clamp(speed / T["DriverWindFullMph"], 0, 1)
        loops["DriverWind"].drive(i, gain_of("DriverWind") * wind, w_pitch, dt, T.get("Global.WindFadeInSeconds", 0.35), T.get("Global.WindFadeOutSeconds", 0.45))
        if fr["boost"] and not f["Boost"]:
            oneshots.append((t, "BoostIgnition", gain_of("BoostIgnition"), 1.0))
        f["Boost"] = fr["boost"]
        while pop_i < len(pops) and pops[pop_i][0] <= t:
            play_pop(pops[pop_i][0], pops[pop_i][1])
            pop_i += 1

    # audio
    engine = np.zeros(n_samples)
    for v in voices:
        buf = snd[v["file"]]
        engine += render_loop(buf, tracks[v["key"]], FRAME_HZ, n_samples)
        if v.get("twin"):
            engine += render_loop(buf, twins[v["key"]], FRAME_HZ, n_samples, start=0.37)
    frames_t = np.arange(n) / FRAME_HZ
    if bus_on_f.max() > 0:
        engine = stft_bus(engine, frames_t, bus_load, bus_rev, bus_on_f, T)
        ts = np.arange(n_samples) / SR
        engine *= np.interp(ts, frames_t, dip_f)
        if lim_f.max() > 0:
            engine *= tremolo(n_samples, lim_f, frames_t, T)
    other = np.zeros(n_samples)
    for index, (name, track) in enumerate(loops.items()):
        if name in snd:
            other += render_loop(snd[name], track, FRAME_HZ, n_samples, start=(0.13 * index) % 1.0)
    shots = np.zeros(n_samples)
    for t0, name, gain, pitch in oneshots:
        if name in snd:
            add_oneshot(shots, snd[name], t0, gain, pitch)
    mix = engine + other + shots
    return (mix, dict(engine=engine, layers=other, oneshots=shots)) if stems else (mix, None)


def render_remote(frames15, snd, T, layers, prof, mode):
    """Another player's car (External route): three Load "Any" voices at 15 Hz, no feel loops or one-shots."""
    n = len(frames15)
    dt = 1.0 / REMOTE_HZ
    n_samples = int(n * SR / REMOTE_HZ)
    voices, on_ladder, off_ladder = build_voices(T, layers, False, mode, prof)
    tracks = {v["key"]: Track(n) for v in voices}
    f = dict(Load=0.0, LoadSlow=0.0, Rev=0.0, Gear=None)
    smoothing = T.get("Global.RevLayerSmoothingSeconds", 0.025)
    for i, fr in enumerate(frames15):
        speed = fr["mph"]
        accelerating = fr["thr"] > 0.05
        load_target = 1.0 if accelerating else 0.0
        f["Load"] = follow(f["Load"], load_target, dt, T["LoadAttackSeconds"] if load_target > f["Load"] else T["LoadReleaseSeconds"])
        f["LoadSlow"] = follow(f["LoadSlow"], f["Load"], dt, T["BarkSeconds"])
        load = clamp(f["Load"], 0, 1) ** T["LoadExponent"]
        bark = T["BarkGain"] * max(0.0, f["Load"] - f["LoadSlow"])
        on_w, off_w = math.sin(load * HALF_PI), math.cos(load * HALF_PI)
        rev_target = clamp(T["RevThrottleWeight"] * load + T["RevSpeedWeight"] * speed / T["RevReferenceMph"], 0, 1)
        rev_seconds = T["RevRiseSeconds"] if rev_target > f["Rev"] else T["RevFallSeconds"]
        if mode == "new" and T["RemoteGearsEnabled"] > 0:
            f["Gear"], rpm = prof.gear_for_speed(speed, accelerating, fr["brake"] > 0, f["Gear"])
            fr["gear"] = f["Gear"]
            rev_target = clamp((rpm - T["RevRpmMin"]) / (T["RevRpmMax"] - T["RevRpmMin"]), 0, 1)
            rev_seconds = T["RemoteRevSmoothingSeconds"]
        f["Rev"] = follow(f["Rev"], rev_target, dt, rev_seconds)
        frequency = T["RevPitchBase"] + (1 - T["RevPitchBase"]) * f["Rev"]
        log_f = math.log(frequency)
        on_ws, off_ws = ladder_weights(on_ladder, log_f), ladder_weights(off_ladder, log_f)
        for v in voices:
            layer = v["layer"]
            on, off = on_ws.get(v["key"], 0.0), off_ws.get(v["key"], 0.0)
            weight = on * on_w * on_w * (1 + bark) + off * off_w * off_w * T["RevOffLoadGain"]
            pitch = clamp(layer.get("Pitch", 1) * frequency / v["freq"], layer["PitchMin"], layer["PitchMax"]) * v["detune"]
            tracks[v["key"]].drive(i, layer["Gain"] * weight * T["RevMasterGain"], pitch, dt, smoothing, smoothing * 2)
    out = np.zeros(n_samples)
    for v in voices:
        out += render_loop(snd[v["file"]], tracks[v["key"]], REMOTE_HZ, n_samples)
    return out, [v["key"] for v in voices]


def doppler_passby(source, mph_track, t_pass, lane=10.0, height=3.0, T=None):
    """APPROXIMATE listener-side pass-by: doppler (sound at 343 m/s = 1225 studs/s) and the in-game distance curve."""
    c = 343.0 / 0.28
    n = len(source)
    ts = np.arange(n) / SR
    v = np.interp(ts, np.arange(len(mph_track)) / REMOTE_HZ, mph_track) / MPH
    X = np.cumsum(v) / SR
    X -= np.interp(t_pass, ts, X)
    dist = lambda tau: np.sqrt(np.interp(tau, ts, X) ** 2 + lane ** 2 + height ** 2)
    tau = ts - dist(ts) / c
    for _ in range(6):
        tau = ts - dist(tau) / c
    d = dist(tau)
    lo, mid, hi = T.get("Global.ExternalMinDistanceStuds", 12), T.get("Global.ExternalMidDistanceStuds", 132), T.get("Global.ExternalMaxDistanceStuds", 240)
    gain = np.interp(d, [0, lo, mid, hi], [1, 1, T.get("Global.ExternalMidDistanceGain", 0.28), 0])
    y = np.interp(tau * SR, np.arange(n), source, left=0.0, right=0.0) * gain
    return y


# --------------------------------------------------------------------------------------------------------
# scenarios (inputs are functions of time; spin and power-brake are scripted gestures)
# --------------------------------------------------------------------------------------------------------
def between(t, a, b):
    return a <= t < b


SCENARIOS = {
    "full_run": dict(
        file="new_01_full_throttle_run", duration=17.0, start_mph=0.0, gear=1,
        about="Idle 1 s, then full throttle from a standstill through all 7 gears towards top speed.",
        inputs=lambda t: dict(thr=1.0 if t >= 1.0 else 0.0)),
    "lift_off": dict(
        file="new_02_lift_off_engine_braking_downshifts", duration=12.0, start_mph=165.0, gear=7,
        about="Full throttle at 165 mph in 7th for 1.5 s, lift (pops, engine braking, coast downshifts) for 5 s, then brake to a stop (braking downshifts with blips) and idle.",
        inputs=lambda t: dict(thr=1.0 if t < 1.5 else 0.0, brake=1.0 if t >= 6.5 else 0.0)),
    "neutral_revs": dict(
        file="new_03_neutral_revs_limiter_then_launch", duration=9.5, start_mph=0.0, gear=1, anchored=True,
        about="Race countdown, car anchored in N: two blips, then held flat on the limiter; GO at 6.0 s launches in 1st with throttle held.",
        inputs=lambda t: dict(anchored=t < 6.0, thr=0.6 if between(t, 1.0, 1.3) else 1.0 if (between(t, 2.0, 2.35) or t >= 3.0) else 0.0)),
    "power_brake": dict(
        file="new_04_power_brake_launch", duration=8.0, start_mph=0.0, gear=1,
        about="W+S held at a standstill for 1.6 s (engine brake-torques up to the launch rpm: an assumption), S released at 2.6 s: dump slip, flare, launch through the gears.",
        inputs=lambda t: dict(thr=1.0 if t >= 1.0 else 0.0, pb_hold=between(t, 1.0, 2.6))),
    "spin": dict(
        file="new_05_spin_out_and_catch", duration=8.0, start_mph=0.0, gear=1,
        about="Pull away gently to about 14 mph, lift, then stab full throttle with full lock (spin window): the spin builds, the engine free-revs, grav skid and strain rise; lift at 4.6 s catches it; drive away.",
        inputs=lambda t: dict(thr=0.3 if between(t, 0.8, 2.3) else 1.0 if between(t, 2.6, 4.6) else 0.6 if t >= 5.4 else 0.0,
                              spin=1.0 if between(t, 2.7, 4.6) else 0.0, catch=between(t, 4.6, 5.4))),
    "part_throttle": dict(
        file="new_06_part_throttle_short_shifts_kickdown", duration=16.0, start_mph=0.0, gear=1,
        about="45% throttle short-shifting from rest (about 0.68 of redline), 20% cruise (cruise upshifts), a lift, then floor it: kickdown after 0.12 s.",
        inputs=lambda t: dict(thr=0.45 if between(t, 1.0, 8.0) else 0.2 if between(t, 8.0, 12.0) else 1.0 if t >= 12.6 else 0.0)),
    "overdrive": dict(
        file="new_07_overdrive_long_boost", duration=9.0, start_mph=160.0, gear=7,
        about="Flat in 7th at 160 mph, then a LONG boost (0.5-5.5 s, longer than a real tank of at most 2 s) so Overdrive is clearly audible: the engine pins at redline with no limiter, the reactor screams; boost ends and the revs fall back.",
        inputs=lambda t: dict(thr=1.0, boost=between(t, 0.5, 5.5))),
    "pass_by": dict(
        file="new_08_pass_by_remote_car", duration=5.5, start_mph=35.0, gear=1, remote=True, t_pass=2.8,
        about="Another player's car accelerating flat out past you (10 studs to the side), heard through the remote path: three voices, GearForSpeed gears, doppler and the distance curve (approximate).",
        inputs=lambda t: dict(thr=1.0)),
}


def frames_at(frames, hz):
    """Resample 60 Hz telemetry to `hz` (remote updates read the replicated state at that rate)."""
    step = int(round(FRAME_HZ / hz))
    return [dict(fr) for fr in frames[::step]]


def fade_edges(x, seconds=0.02):
    m = int(seconds * SR)
    if len(x) > 2 * m:
        x[:m] *= np.linspace(0, 1, m)
        x[-m:] *= np.linspace(1, 0, m)
    return x


def summary(frames, events):
    mph = np.array([fr["mph"] for fr in frames])
    ts = np.array([fr["t"] for fr in frames])

    def time_to(v):
        idx = np.flatnonzero(mph >= v)
        return round(float(ts[idx[0]]), 2) if idx.size else None
    return dict(top_mph=round(float(mph.max()), 1), end_mph=round(float(mph[-1]), 1),
                t_60=time_to(60), t_100=time_to(100), t_150=time_to(150), shifts=events)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", default="", help="comma list of: " + ",".join(SCENARIOS) + ",today_vs_new")
    ap.add_argument("--set", action="append", default=[], help="Drivetrain override Name=value (repeatable)")
    ap.add_argument("--tag", default="", help="suffix added to every file name; a tagged run skips the today_vs_new pairs and stems")
    ap.add_argument("--reactor", choices=["whine", "core"], default="whine")
    ap.add_argument("--slip-strain", choices=["grav_skid", "stabiliser_strain"], default="grav_skid")
    ap.add_argument("--no-bus", action="store_true", help="EngineBusEnabled = 0 (sub-bus bypassed)")
    args = ap.parse_args()
    d = dict(DRIVETRAIN)
    for item in args.set:
        key, value = item.split("=", 1)
        if key not in d:
            raise SystemExit("unknown drivetrain attribute %s" % key)
        d[key] = value if isinstance(d[key], str) else float(value)
    only = set(filter(None, args.only.split(",")))
    if "today_vs_new" in only:
        only |= {"full_run", "pass_by"}
    tag = ("_" + args.tag) if args.tag else ""
    T, layers, sources = load_tuning()
    prof = Profile(d, CAR)
    gain = 10 ** (MASTER_DB / 20)
    snd_new = load_sounds("new", args.reactor, args.slip_strain)
    snd_today = load_sounds("today")
    snd_interim = load_sounds("interim")
    os.makedirs(LISTEN_DIR, exist_ok=True)
    written, timeline = [], dict(car=CAR["name"], drivetrain=d, gear_redline_mph=[round(v, 1) for v in prof.Vg],
                                 derived=dict(Kd=round(prof.Kd, 6), traction_studs_s2=round(prof.trac, 1),
                                              boost_share_at_top=round(prof.share_hi, 3), brake_studs_s2=round(prof.brake, 1)),
                                 tuning_sources=sources, demos={})

    def out(rel, x):
        x = fade_edges(x * gain)
        peak = float(np.abs(x).max()) if len(x) else 0.0
        clipped = int(np.sum(np.abs(x) > 0.999))
        path = os.path.join(LISTEN_DIR, rel.replace(".wav", tag + ".wav"))
        write_wav(path, x)
        written.append((os.path.relpath(path, LISTEN_DIR), len(x) / SR, 20 * math.log10(max(peak, 1e-9)), clipped))

    bus = not args.no_bus
    for key, sc in SCENARIOS.items():
        if only and key not in only:
            continue
        sim = NewSim(prof, sc["start_mph"], sc["gear"], sc.get("anchored", False))
        frames, pops = run(sim, sc)
        timeline["demos"][sc["file"]] = dict(about=sc["about"], **summary(frames, sim.events))
        if sc.get("remote"):
            f15 = frames_at(frames, REMOTE_HZ)
            src, voice_keys = render_remote(f15, snd_new, T, layers, prof, "new")
            out(sc["file"] + ".wav", doppler_passby(src, [fr["mph"] for fr in f15], sc["t_pass"], T=T))
            timeline["demos"][sc["file"]]["remote_voices"] = voice_keys
            if not tag:
                tsim = TodaySim(prof, sc["start_mph"])
                tframes, _ = run(tsim, sc)
                t15 = frames_at(tframes, REMOTE_HZ)
                tsrc, tkeys = render_remote(t15, snd_today, T, layers, prof, "today")
                a = doppler_passby(tsrc, [fr["mph"] for fr in t15], sc["t_pass"], T=T)
                b = doppler_passby(src, [fr["mph"] for fr in f15], sc["t_pass"], T=T)
                out("today_vs_new/pass_by_A_today.wav", a)
                out("today_vs_new/pass_by_B_new.wav", b)
                out("today_vs_new/pass_by_A_then_B.wav", np.concatenate([a, np.zeros(int(0.8 * SR)), b]))
                timeline["demos"]["pass_by_today"] = dict(remote_voices=tkeys, **summary(tframes, []))
            continue
        mix, stems = render_local(frames, pops, snd_new, T, layers, prof, "new", bus_on=bus, stems=(key == "full_run"))
        out(sc["file"] + ".wav", mix)
        if key == "full_run" and not tag:
            out("stems/new_01_full_throttle_run_engine_only.wav", stems["engine"])
            # today vs new: today's physics and sound; today's sound on the new pace (isolates the sound change); new
            tsim = TodaySim(prof, 0.0)
            tframes, tpops = run(tsim, sc)
            a, astems = render_local(tframes, tpops, snd_today, T, layers, prof, "today", stems=True)
            c, _ = render_local(frames, pops, snd_today, T, layers, prof, "today")
            dd, _ = render_local(frames, pops, snd_interim, T, layers, prof, "interim", bus_on=bus)
            out("today_vs_new/full_run_A_today.wav", a)
            out("today_vs_new/full_run_B_new.wav", mix)
            out("today_vs_new/full_run_C_today_sound_on_new_pace.wav", c)
            out("today_vs_new/full_run_D_interim_new_gearbox_uploaded_loops.wav", dd)
            out("today_vs_new/full_run_A_then_B.wav", np.concatenate([a, np.zeros(int(0.8 * SR)), mix]))
            out("stems/today_01_full_throttle_run_engine_only.wav", astems["engine"])
            timeline["demos"]["full_run_today"] = summary(tframes, [])
    timeline_path = os.path.join(LISTEN_DIR, "timeline%s.json" % tag)
    if only and os.path.exists(timeline_path):  # a partial run keeps the other demos' entries
        try:
            previous = json.load(open(timeline_path, encoding="utf-8"))
            previous["demos"].update(timeline["demos"])
            timeline["demos"] = previous["demos"]
        except (ValueError, KeyError):
            pass
    with open(timeline_path, "w", encoding="utf-8") as fh:
        json.dump(timeline, fh, indent=1)
    write_readme(timeline, tag)
    print("tuning sources:", "; ".join(sources))
    print("gear redline mph:", " / ".join("%.0f" % v for v in prof.Vg))
    print("%-62s %7s %8s %s" % ("file (listen/)", "secs", "peak dB", "clipped"))
    for rel, secs, peak, clipped in written:
        print("%-62s %7.2f %8.2f %d" % (rel, secs, peak, clipped))
    for name, demo in timeline["demos"].items():
        if demo.get("shifts") is not None:
            print("%-44s top %6.1f mph, 0-60 %s s, 0-100 %s s, %d gearbox events" % (
                name, demo["top_mph"], demo["t_60"], demo["t_100"], len(demo["shifts"])))


def write_readme(timeline, tag):
    lines = [
        "drivetrain_feel listen pack (rendered by scripts/drivetrain_feel/synth/listen.py)",
        "",
        "Car: " + timeline["car"] + ". Gear redline speeds (mph): " + " / ".join("%.0f" % v for v in timeline["gear_redline_mph"]) + ".",
        "Tuning sources: " + "; ".join(timeline["tuning_sources"]) + ".",
        "",
        "APPROXIMATE, read before judging:",
        "- The engine sub-bus effects (Peak sweep, 3-band tilt, limiter tremolo) are an offline approximation;",
        "  Roblox's AudioFilter/AudioEqualizer/AudioTremolo will sound somewhat different.",
        "- Pitch changes are smoothed between update ticks; in game they step at 60 Hz (local) or 15 Hz (others).",
        "- Spin, the power-brake hold and launch slip are scripted inputs, not the chassis model.",
        "- The pass-by adds doppler and the in-game distance curve; Roblox may not apply doppler.",
        "- Toolbox sounds (blow-off, generic idle) are not included.",
        "- Every file uses the same master gain, so loudness differences between today and new are real.",
        "",
        "Files:",
    ]
    for name, demo in timeline["demos"].items():
        if "about" in demo:
            lines.append("  %s%s.wav: %s" % (name, tag, demo["about"]))
    lines += [
        "  today_vs_new/full_run_A_today: today's physics (no gears) and today's speed-based rev formula and loops.",
        "  today_vs_new/full_run_B_new: the same as new_01.",
        "  today_vs_new/full_run_C_today_sound_on_new_pace: today's sound driven by the new (slower, geared) speed trace,",
        "    so B against C isolates the sound change from the pace change.",
        "  today_vs_new/full_run_D_interim_new_gearbox_uploaded_loops: the new gearbox and audio rules with only the",
        "    sounds already uploaded (today's V10 loops, turbine_high as the reactor, blank shift slots, so hard upshifts",
        "    crackle with a pop): what the game sounds like after the code install and before any new upload.",
        "  today_vs_new/*_A_then_B: A, 0.8 s of silence, then B.",
        "  today_vs_new/pass_by_*: the same pair for another player's car passing.",
        "  stems/*_engine_only: the rev voices alone (after the bus for new), to judge the loops.",
        "",
        "Shift times, gears and speeds for each demo are in timeline%s.json." % tag,
    ]
    with open(os.path.join(LISTEN_DIR, "README%s.txt" % tag), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
