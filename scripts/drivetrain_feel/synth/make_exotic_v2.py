"""Pulse Racers - drivetrain_feel: Exotic V10 hybrid sound set, version 2.

Renders the upload candidates for the drivetrain_feel delivery (CONTRACT section 10):

    py -3 scripts/drivetrain_feel/synth/make_exotic_v2.py

Output (not committed, `output/` is scratch space):

    output/drivetrain_feel_audio/exotic_v2/      upload candidates + manifest.json
    output/drivetrain_feel_audio/_today_regen/   today's Exotic loops and one-shots, re-synthesised
                                                 by scripts/hover_feel/synth/make_sounds.py (comparison
                                                 and listen pack only; never upload these again)

Every helper (wavetables, periodic noise, FFT filters, envelopes, loop finaliser, metrics) is imported
from scripts/hover_feel/synth/make_sounds.py by file path. That file is not modified.

The V10 set uses the SAME rpm points and load modes as the live EXOTIC_V10_AUDIO rev layers
(idle 1000; on 2000/3500/5000/6500/8000; off 3000/6000) and the same loop lengths, so each file
drops into the existing RevLayers slot one to one with no Rev/Pitch change.

numpy + stdlib only. Deterministic: every sound has a fixed seed.
"""
import importlib.util
import json
import os
import sys

import numpy as np

sys.dont_write_bytecode = True  # importing other folders' files by path must not leave __pycache__ there

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MAKE_SOUNDS = os.path.join(ROOT, "scripts", "hover_feel", "synth", "make_sounds.py")
OUT_BASE = os.path.join(ROOT, "output", "drivetrain_feel_audio")
OUT = os.path.join(OUT_BASE, "exotic_v2")
TODAY = os.path.join(OUT_BASE, "_today_regen")


def load_make_sounds():
    spec = importlib.util.spec_from_file_location("hover_feel_make_sounds", MAKE_SOUNDS)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # main() is guarded by __name__, so nothing is written
    return module


ms = load_make_sounds()
SR = ms.SR
TAU = ms.TAU


# --------------------------------------------------------------------------
# ENGINE: grungier V10 hybrid (v2)
# --------------------------------------------------------------------------
# Compared with make_sounds.ENGINE_MODES (round 3, live today):
#   bank/eng/half  stronger engine and half orders (lumpier, less "turbine-smooth")
#   jit            2x the cycle-to-cycle phase jitter
#   gainvar        3x per-firing level variation on load (uneven combustion)
#   cyl_skew       NEW: per-cylinder firing-time offsets (fraction of a firing interval), applied
#                  as a cycle-periodic phase wobble on the tonal core and as real timing offsets
#                  on the exhaust blat train
#   blat           NEW: one exhaust "blat" per firing (noise burst plus pipe resonance) at the
#                  uneven firing times, circularly convolved so the loop stays seamless
#   fold           NEW: share of the sine wavefolder (make_sounds.rasp) after the saturator
#   sub/rumble/exrasp  heavier low end and firing-pulsed rasp (round 3: 0.35/0.25/0.30)
#   half_sub       share of the half-firing tone inside sub (round 3: 1); kept low on overrun so the
#                  firing line stays the loop's pitch without a large anchor boost
#   low_orders     weight on the orders under the firing line (round 3: 2.2 for every mode)
#   bias           more asymmetric saturation (even harmonics)
#   *_rev          extra grunge per unit of rev (0 at 1000 rpm, 1 at 8000) for the on-load set, because the
#                  gearbox keeps the engine at 0.6-0.97 of redline: the 5000-8000 loops are heard most.
#                  smooth_rev replaces round 3's fixed 0.5 high-rev smoothing of the engine orders.
V2_MODES = {
    "on": dict(bank=0.34, eng=0.19, half=0.10, tilt=1.30, jit=0.0032, gainvar=0.16, cyl_skew=0.030,
               bias=0.62, noise=0.17, nband=(700.0, 8500.0),
               formants=[(380, 170, 6), (820, 320, 7), (1350, 420, 5), (2900, 800, 4), (5200, 1400, 2)],
               sub=0.40, half_sub=0.6, rumble=0.32, exrasp=0.45, blat=0.55, fold=0.30, pops=0.0, low_orders=2.4,
               smooth_rev=0.0, noise_rev=0.22, exrasp_rev=0.30, fold_rev=0.20, blat_rev=0.25, gainvar_rev=0.25, skew_rev=0.02),
    "off": dict(bank=0.32, eng=0.26, half=0.18, tilt=1.65, jit=0.006, gainvar=0.55, cyl_skew=0.040,
                bias=0.58, noise=0.28, nband=(220.0, 3200.0),
                formants=[(230, 90, 4), (680, 300, -6), (1650, 350, 5)],
                sub=0.36, half_sub=0.35, rumble=0.30, exrasp=0.40, blat=0.45, fold=0.22, pops=0.15, low_orders=2.0,
                smooth_rev=0.0, noise_rev=0.0, exrasp_rev=0.0, fold_rev=0.0, blat_rev=0.0, gainvar_rev=0.0, skew_rev=0.0),
    "idle": dict(bank=0.62, eng=0.36, half=0.28, tilt=1.40, jit=0.008, gainvar=0.32, cyl_skew=0.050,
                 bias=0.52, noise=0.20, nband=(200.0, 4500.0),
                 formants=[(170, 80, 6), (500, 200, 4), (1300, 400, 3)],
                 sub=0.45, half_sub=0.6, rumble=0.36, exrasp=0.35, blat=0.50, fold=0.25, pops=0.0, low_orders=2.4,
                 smooth_rev=0.0, noise_rev=0.0, exrasp_rev=0.0, fold_rev=0.0, blat_rev=0.0, gainvar_rev=0.0, skew_rev=0.0),
}
V2_DRIVE = {"on": (0.85, 0.50), "off": (0.90, 0.0), "idle": (0.85, 0.0)}  # base, extra at full rev
PRESENCE_V2_ON_DB = 1.5    # round 3: +4 dB at 3.3 kHz. Less whine, more chest.
PRESENCE_V2_OFF_DB = -3.0  # round 3: -2 dB
SHEEN_V2_DB = -25.0        # round 3: -20 dB. The sci-fi line now lives mostly in reactor_whine.
IDLE_CORE_V2 = 0.38        # round 3: 0.5 (energy-core hum share in the hybrid idle)
IDLE_WHISPER_V2 = 0.08     # round 3: 0.11


def engine_loop_v2(rpm, mode, seed):
    """Grungier V10 hybrid loop, same structure and loop length as make_sounds.engine_loop.

    One engine cycle (two crank revolutions, ten firings) is a harmonic wavetable read with a
    jittered, cylinder-skewed phase; per-firing level variation; firing-synchronous gas noise;
    an uneven exhaust blat train; sub orders, rumble and firing-pulsed rasp; asymmetric tanh
    then a partial wavefolder; EQ; a quieter ring-mod sheen; and the firing-line anchor so the
    loop's pitch is exactly its rpm (the game's crossfade depends on it)."""
    p = dict(V2_MODES[mode])
    r = np.random.default_rng(seed)
    M, N = ms.engine_length(rpm)
    f_cyc = M * SR / N
    f_fire = 10.0 * f_cyc
    n = np.arange(N)
    rev = float(np.clip((rpm - 1000.0) / 7000.0, 0.0, 1.0))
    p["gainvar"] += p["gainvar_rev"] * rev
    p["cyl_skew"] += p["skew_rev"] * rev

    # Uneven firing on the tonal core: a smooth wobble that repeats every engine cycle (orders 1..3),
    # scaled so the firing line's timing moves by +-cyl_skew of a firing interval.
    base_ph = M * n / N
    skew = np.zeros(N)
    for order, level in ((1, 1.0), (2, 0.6), (3, 0.35)):
        skew += level * np.sin(TAU * order * base_ph + r.uniform(0.0, TAU))
    skew /= np.abs(skew).max()
    ph = base_ph + p["jit"] * ms.slow(N, r, 0.7, 35.0, -1.0) + (p["cyl_skew"] / 10.0) * skew

    H = int(min(15000.0 / f_cyc, ms.TABLE // 2 - 1))
    h = np.arange(1, H + 1)
    f = h * f_cyc
    smooth = 1.0 - p["smooth_rev"] * rev  # round 3 smoothed 0.5 at the top on load; keep more lump
    tilt = p["tilt"] - (0.40 * rev if mode == "on" else 0.0)
    env = np.where(f >= f_fire, (f / f_fire) ** -tilt, (f / f_fire) ** 0.25)
    for fc, bw, g in p["formants"]:
        env = env * ms.bump(f, fc, bw, g)
    base_phase = r.standard_normal(H) * np.clip(0.8 + f / 3000.0, 0.0, 2.5)

    def table():
        w = np.where(h % 10 == 0, 1.0,
                     np.where(h % 5 == 0, p["bank"] * smooth,
                              np.where(h % 2 == 0, p["eng"] * smooth, p["half"])))
        w = w * np.where(h < 10, p["low_orders"], 1.0)  # round 3: 2.2 for every mode
        scatter = np.where(h % 10 == 0, 0.15, 0.45)
        a = env * w * np.exp(scatter * r.standard_normal(H))
        return ms.make_table(a, base_phase + 0.4 * r.standard_normal(H))

    tab_a, tab_b = table(), table()
    morph = np.clip(0.5 + 0.35 * ms.slow(N, r, 1.5, 11.0), 0.0, 1.0)
    x = (1.0 - morph) * ms.read_table(tab_a, ph) + morph * ms.read_table(tab_b, ph)

    # Per-firing level: fixed per-cylinder offsets plus event-to-event variation.
    fire_idx = np.floor(10.0 * ph + 0.5).astype(np.int64) % (10 * M)
    cyl = r.standard_normal(10)
    gains = 1.0 + p["gainvar"] * (0.45 * cyl[np.arange(10 * M) % 10] + 0.8 * r.standard_normal(10 * M))
    gains = np.clip(gains, 0.1, 1.8)
    g = ms.ffilt(gains[fire_idx], lambda fr: ms.lp(fr, 1.5 * f_fire, 2))
    x = x * g
    x /= ms.rms(x)

    # Firing-synchronous gas noise.
    pulse = (0.5 + 0.5 * np.cos(TAU * 10.0 * ph)) ** 2
    lo, hi = p["nband"]
    nz = ms.pnoise(N, r, lambda fr: ms.bp(fr, lo, hi, 2) * np.maximum(fr, 1.0) ** -0.3)
    nz = nz * (0.3 + 1.4 * pulse)
    level = p["noise"] + p["noise_rev"] * rev
    x = x + level * nz / ms.rms(nz)

    # Uneven exhaust blats: one impulse per firing at its skewed time (fixed per-cylinder offset plus
    # a little per-event scatter), per-cylinder level offsets, circularly convolved with a short
    # noise burst plus a pipe resonance. Positions are inside the loop, so it stays seamless.
    k_idx = np.arange(10 * M)
    cyl_t = r.standard_normal(10)
    t_k = (k_idx + p["cyl_skew"] * 1.5 * cyl_t[k_idx % 10]
           + 0.25 * p["cyl_skew"] * r.standard_normal(10 * M)) * N / (10.0 * M)
    pos = np.round(t_k).astype(np.int64) % N
    amp_k = np.clip(1.0 + 0.9 * p["gainvar"] * cyl[k_idx % 10] + 0.6 * p["gainvar"] * r.standard_normal(10 * M),
                    0.1, 2.0)
    imp = np.zeros(N)
    np.add.at(imp, pos, amp_k)
    m = max(16, int(min(0.012, 0.8 / f_fire) * SR))
    tk = np.arange(m) / SR
    pipe_hz = max(120.0, 0.8 * f_fire)  # kept off the half-firing (bank) order so it never masks the firing line
    kern = r.standard_normal(m) * np.exp(-tk / 0.0025) + 0.8 * np.sin(TAU * pipe_hz * tk) * np.exp(-tk / 0.006)
    K = np.zeros(N)
    K[:m] = kern
    blat = np.fft.irfft(np.fft.rfft(imp) * np.fft.rfft(K), N)
    blat = ms.ffilt(blat, lambda fr: ms.bp(fr, 90.0, 3500.0, 2))
    x = x + (p["blat"] + p["blat_rev"] * rev) * blat / ms.rms(blat)

    # Depth: half-firing sub order, first and second engine orders, third order, rumble, rasp.
    sub = (p["half_sub"] * np.sin(TAU * 5.0 * ph) + 0.5 * np.sin(TAU * 2.0 * ph + 1.0) + 0.35 * np.sin(TAU * ph + 2.0)
           + 0.25 * np.sin(TAU * 3.0 * ph + 0.4))
    rumble = ms.pnoise(N, r, lambda fr: ms.bp(fr, 30.0, 200.0, 2)) * (1.0 + 0.5 * ms.slow(N, r, 4.0, 30.0))
    exrasp = ms.pnoise(N, r, lambda fr: ms.bp(fr, 280.0, 1400.0, 2)) * (0.25 + 1.5 * pulse)
    x = x + p["sub"] * sub + p["rumble"] * rumble + (p["exrasp"] + p["exrasp_rev"] * rev) * exrasp / ms.rms(exrasp)

    if p["pops"] > 0.0:  # overrun crackle on random firings (as round 3, a little denser)
        starts = np.flatnonzero(np.diff(fire_idx) != 0) + 1
        chosen = starts[r.random(starts.size) < p["pops"]]
        imp = np.zeros(N)
        imp[chosen] = 0.5 + r.random(chosen.size)
        k = np.zeros(N)
        mm = int(0.08 * SR)
        k[:mm] = r.standard_normal(mm) * np.exp(-np.arange(mm) / (0.012 * SR))
        pops = np.fft.irfft(np.fft.rfft(imp) * np.fft.rfft(k), N)
        pops = ms.ffilt(pops, lambda fr: ms.bp(fr, 150.0, 2500.0, 2))
        x = x + 0.55 * pops / ms.rms(pops)

    # Saturation: harder, more asymmetric tanh, then part of the signal through the wavefolder.
    base, extra = V2_DRIVE[mode]
    x = x / ms.rms(x)
    x = np.tanh((base + extra * rev) * 1.1 * x + p["bias"])
    x -= x.mean()
    folded = ms.rasp(x, 0.55, 8500.0)
    fold = p["fold"] + p["fold_rev"] * rev
    x = (1.0 - fold) * x / ms.rms(x) + fold * folded / ms.rms(folded)

    if mode == "on":
        eq = lambda fr: (ms.hp(fr, 28.0, 2) * ms.lp(fr, 10000.0, 4) * ms.bump(fr, 3300.0, 1500.0, PRESENCE_V2_ON_DB)
                         * ms.bump(fr, 700.0, 380.0, 4.0) * ms.bump(fr, 105.0, 75.0, 3.5) * ms.bump(fr, 1150.0, 350.0, 1.5))
    elif mode == "off":
        fc = 1600.0 + 0.28 * rpm
        eq = lambda fr: (ms.hp(fr, 28.0, 2) * ms.lp(fr, fc, 2) * ms.bump(fr, 3300.0, 1500.0, PRESENCE_V2_OFF_DB)
                         * ms.bump(fr, 700.0, 350.0, 2.5) * ms.bump(fr, 105.0, 75.0, 3.0))
    else:
        eq = lambda fr: ms.hp(fr, 30.0, 2) * ms.lp(fr, 5500.0, 2) * ms.bump(fr, 110.0, 70.0, 3.0)
    x = ms.ffilt(x, eq)
    extra_meta = {}

    if mode == "on":
        # Sci-fi sheen, 5 dB quieter than round 3: ring modulation at 2.76x the firing frequency,
        # derived from the engine phase so the metallic sidebands track the revs.
        c = int(round(27.6 * M))
        ring = ms.ffilt(x * np.sin(TAU * c * ph / M), lambda fr: ms.bp(fr, 1200.0, 5000.0, 2))
        x = x + ms.amp(SHEEN_V2_DB) * ring * ms.rms(x) / ms.rms(ring)
        extra_meta = dict(sheen_db=SHEEN_V2_DB, sheen_carrier_ratio=round(c / (10.0 * M), 4))
    elif mode == "idle":
        # Hybrid idle: the round 3 energy-core hum (a fifth above the firing note, 2 Hz throb) and
        # turbine whisper, both pulled back so the lumpy V10 leads.
        k_throb = int(round(2.0 * N / SR))
        kh = 15 * M
        hh = np.arange(1, 41)
        core = np.zeros(N)
        for k, lvl in [(kh, 1.0), (kh + k_throb, 0.5), (2 * kh + 3 * k_throb, 0.35)]:
            tab = ms.make_table(hh ** -0.9, 0.6 * r.standard_normal(40))
            core += lvl * ms.read_table(tab, k * n / N + 0.003 * ms.slow(N, r, 0.5, 20.0, -1.0))
        core = ms.rasp(core, 0.5, 6000.0)
        core = ms.ffilt(core, lambda fr: ms.bump(fr, 400.0, 150.0, 5.0) * ms.bump(fr, 1250.0, 350.0, 5.0))
        core = core * (0.72 + 0.28 * np.cos(TAU * k_throb * n / N)) * (1.0 + 0.15 * ms.slow(N, r, 60.0, 120.0))
        kt = int(round(2640.0 * N / SR))
        whisper = 0.6 * np.sin(TAU * kt * n / N + 1.5 * ms.slow(N, r, 1.0, 20.0, -0.5))
        whisper = whisper + ms.pnoise(N, r, lambda fr: ms.bp(fr, 2500.0, 8000.0, 2)) * (1.0 + 0.3 * ms.slow(N, r, 3.0, 20.0))
        x = x / ms.rms(x) + IDLE_CORE_V2 * core / ms.rms(core) + IDLE_WHISPER_V2 * whisper / ms.rms(whisper)
        extra_meta = dict(modulation_hz=round(k_throb * SR / N, 3), modulation="energy-core throb",
                          core_tone_hz=round(kh * SR / N, 3), whisper_tone_hz=round(kt * SR / N, 3))

    # Anchor: the firing line stays the strongest component (the loop's pitch for the game).
    X = np.fft.rfft(x)
    kf = 10 * M
    mag = np.abs(X)
    other = np.delete(mag, kf)[1:].max()
    anchor_db = 0.0
    if mag[kf] < 1.26 * other:
        gain = 1.26 * other / mag[kf]
        X[kf] *= gain
        anchor_db = ms.to_db(gain)
        x = np.fft.irfft(X, N)

    meta = dict(rpm=rpm, mode=mode, firing_hz=round(f_fire, 4), nominal_firing_hz=round(rpm / 12.0, 4),
                engine_cycles=M, firing_periods=10 * M, firing_anchor_gain_db=round(anchor_db, 2),
                cylinder_skew=p["cyl_skew"], gain_variation=p["gainvar"])
    meta.update(extra_meta)
    return ms.finalize_loop(x), meta


# --------------------------------------------------------------------------
# SCI-FI LINE: reactor / ion whine (TurboWhistle slot, follows road speed)
# --------------------------------------------------------------------------
def reactor_whine_loop(seed=301, T=3.0, f0=880.0):
    """Ion-drive whine ("A", recommended). Clean on purpose, against the grungy engine: an electric
    motor stack on 880 Hz (h1..h6), inverter-style sidebands round 4.37x, two detuned chorus
    voices (0.67 / 1 Hz beats), a sub octave, slow vibrato, a 6.67 Hz plasma pulse and a thin
    3-7 kHz ion shimmer. The game sweeps it 0.5-1.85x with road speed (440 Hz to 1.6 kHz)."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    k0 = int(round(f0 * N / SR))
    dev = 0.25 * ms.slow(N, r, 3.0, 7.0)  # vibrato, cycles of the fundamental (about 0.15 %)
    x = np.zeros(N)
    for hh, lvl in [(1, 1.0), (2, 0.32), (3, 0.20), (4, 0.08), (5, 0.06), (6, 0.03)]:
        x += lvl * np.sin(TAU * (hh * k0 * n / N + hh * dev) + r.uniform(0.0, TAU))
    kc = int(round(4.37 * k0))
    for dk, lvl in [(0, 0.05), (-k0, 0.07), (k0, 0.07), (-2 * k0, 0.04), (2 * k0, 0.04)]:
        x += lvl * np.sin(TAU * ((kc + dk) * n / N + 4.37 * dev) + r.uniform(0.0, TAU))
    x += 0.5 * np.sin(TAU * ((k0 + 2) * n / N + 0.8 * dev) + r.uniform(0.0, TAU))
    x += 0.35 * np.sin(TAU * ((k0 - 3) * n / N + 1.2 * dev) + r.uniform(0.0, TAU))
    x += 0.30 * np.sin(TAU * ((k0 // 2) * n / N + 0.5 * dev) + r.uniform(0.0, TAU))
    k_p = int(round(6.67 * N / SR))
    x = x * (1.0 + 0.06 * np.cos(TAU * k_p * n / N))
    shimmer = ms.pnoise(N, r, lambda f: ms.bp(f, 3000.0, 7000.0, 2)) * (1.0 + 0.6 * ms.slow(N, r, 20.0, 60.0))
    x = x / ms.rms(x) + 0.08 * shimmer
    x = np.tanh(0.9 * x / ms.rms(x))
    x = ms.ffilt(x, lambda f: ms.hp(f, 120.0, 2) * ms.lp(f, 9000.0, 4))
    return ms.finalize_loop(x), dict(main_tone_hz=round(k0 * SR / N, 3), modulation_hz=round(k_p * SR / N, 3),
                                     modulation="plasma pulse", chorus_beats_hz=[round(2 * SR / N, 3), round(3 * SR / N, 3)])


def reactor_core_loop(seed=311, T=3.0, f0=660.0):
    """Reactor-core alternative ("B"): darker and more unstable. A detuned stack on 660 Hz (root,
    fifth, octave; 1.33 / 2.33 / 1 Hz beats), a 4 Hz containment throb, FM wobble, a ring-mod
    metallic sheen 14 dB down and a light fold rasp."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    k0 = int(round(f0 * N / SR))
    dev = 0.4 * ms.slow(N, r, 2.0, 9.0)
    x = np.zeros(N)
    for kk, lvl, det in [(k0, 1.0, 4), (int(round(1.5 * k0)), 0.55, 7), (2 * k0, 0.45, 3)]:
        ratio = kk / k0
        x += lvl * (np.sin(TAU * (kk * n / N + ratio * dev) + r.uniform(0.0, TAU))
                    + 0.6 * np.sin(TAU * ((kk + det) * n / N + ratio * dev) + r.uniform(0.0, TAU)))
    k_t = int(round(4.0 * N / SR))
    x = x * (1.0 + 0.15 * np.cos(TAU * k_t * n / N))
    c = int(round(2.73 * k0))
    ring = ms.ffilt(x * np.sin(TAU * c * n / N), lambda f: ms.bp(f, 1500.0, 6000.0, 2))
    x = x / ms.rms(x) + ms.amp(-14.0) * ring / ms.rms(ring)
    x = 0.8 * x / ms.rms(x) + 0.2 * ms.rasp(x, 0.4, 8000.0)
    hiss = ms.pnoise(N, r, lambda f: ms.bp(f, 2500.0, 8000.0, 2)) * (1.0 + 0.5 * np.cos(TAU * k_t * n / N))
    x = x / ms.rms(x) + 0.06 * hiss
    x = np.tanh(0.9 * x / ms.rms(x))
    x = ms.ffilt(x, lambda f: ms.hp(f, 100.0, 2) * ms.lp(f, 8500.0, 4))
    return ms.finalize_loop(x), dict(main_tone_hz=round(k0 * SR / N, 3), modulation_hz=round(k_t * SR / N, 3),
                                     modulation="containment throb")


# --------------------------------------------------------------------------
# SHIFT ONE-SHOTS
# --------------------------------------------------------------------------
def shift_thunk(seed, seconds, gap, clack_band, modes, thump_hz, thump_decay, chirp, chirp_db, peak_db=-4.0):
    """Dual-clutch shift: a dry mechanical clack (two engagement clicks `gap` apart, each a sub-ms
    click plus a noise-excited metal burst, through short gearbox-housing modes), a driveline
    thump with a small downward glide, and a short electric actuator chirp underneath."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    clack = np.zeros(n)
    for t0, lvl in ((0.0, 1.0), (gap, 0.7)):
        tt = t - t0
        clack += lvl * (r.standard_normal(n) * ms.ad(tt, 0.00015, 0.0009)
                        + 0.8 * ms.bandnoise(n, r, clack_band[0], clack_band[1]) * ms.ad(tt, 0.0003, 0.007))
    housing = ms.pipe_tail(clack, modes)
    clack = 0.6 * clack / np.abs(clack).max() + 0.5 * housing
    tt = t - 0.002
    on = (tt >= 0.0).astype(float)
    tp = np.maximum(tt, 0.0)
    thump = np.cos(ms.phase_of(thump_hz * (1.0 + 0.35 * np.exp(-tp / 0.012)) * on)) * np.exp(-tp / thump_decay) * on
    thump = np.tanh(2.0 * thump)
    body = ms.bandnoise(n, r, 35.0, 260.0) * ms.ad(tt, 0.001, thump_decay * 0.8)
    tc = t - 0.009
    tcp = np.maximum(tc, 0.0)
    f_sw = chirp[0] * (chirp[1] / chirp[0]) ** np.clip(tcp / 0.028, 0.0, 1.0)
    cph = ms.phase_of(f_sw * (tc >= 0.0))
    zip_ = (np.sin(cph) + 0.35 * np.sin(2.0 * cph)) * ms.ad(tc, 0.0015, 0.012)
    zip_ += 0.3 * ms.bandnoise(n, r, 4000.0, 9000.0) * ms.ad(tc, 0.001, 0.006)
    # Clack leads (it is what small speakers reproduce); the thump is the weight under it.
    x = (1.6 * clack + 0.7 * thump / np.abs(thump).max() + 0.3 * body / np.abs(body).max()
         + 1.6 * ms.amp(chirp_db) * zip_ / np.abs(zip_).max())
    x = np.tanh(1.4 * x / np.abs(x).max())
    x = ms.reverb(x, r, decay=0.025, mix=0.03)
    return ms.finalize_oneshot(x, peak_db=peak_db, hp_hz=30.0), dict(
        engagement_gap_ms=gap * 1000.0, thump_hz=thump_hz, chirp_hz=list(chirp), chirp_db_re_clack=chirp_db)


def shift_vent(seed, seconds, sweep, zap, whoomp_hz, crackle_tau, snaps, peak_db=-4.0):
    """Hard-upshift plasma vent: a pressurised release (band noise sweeping down), sparse spiky
    arc crackle with snaps that thin out over `crackle_tau`, a short falling FM arc zap and a low
    gas whoomp. An electrical vent, deliberately unlike the exhaust pops (no gunshot crack)."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    fc = sweep[1] + (sweep[0] - sweep[1]) * np.exp(-t / 0.07)
    vent = ms.swept_noise(n, r, fc, 2600.0) * ms.ad(t, 0.0015, 0.09)
    vent += 0.5 * ms.bandnoise(n, r, 2500.0, 10000.0) * ms.ad(t, 0.001, 0.05)
    gust = np.clip(ms.pnoise(n, r, lambda f: ms.bp(f, 15.0, 80.0, 2)), 0.0, None)
    crackle = ms.spiky(ms.bandnoise(n, r, 1800.0, 9000.0), 3.5) * np.exp(-t / crackle_tau) * gust
    times = np.sort(0.004 + r.exponential(crackle_tau * 0.6, snaps))
    snap = ms.crack_clicks(n, r, times, 1.0, 0.0006, 2000.0)
    tz = t - 0.004
    tzp = np.maximum(tz, 0.0)
    fz = zap[1] + (zap[0] - zap[1]) * np.exp(-tzp / 0.03)
    zph = ms.phase_of(fz * (tz >= 0.0)) + 1.2 * np.sin(TAU * 70.0 * t)
    arc = np.tanh(2.0 * (np.sin(zph) + 0.4 * np.sin(2.0 * zph))) * ms.ad(tz, 0.001, 0.035)
    whoomp = ms.bandnoise(n, r, 45.0, 320.0) * ms.ad(t, 0.006, 0.07)
    whoomp += 0.6 * np.tanh(1.5 * ms.low_thump(n, 0.0, whoomp_hz, 0.03))
    x = (0.9 * vent / np.abs(vent).max() + 0.55 * crackle / np.abs(crackle).max() + 0.45 * snap / (np.abs(snap).max() + 1e-12)
         + 0.35 * arc + 0.7 * whoomp / np.abs(whoomp).max())
    x = np.tanh(1.5 * x / np.abs(x).max())
    x = ms.reverb(x, r, decay=0.12, mix=0.12, lo=400.0, hi=8000.0)
    return ms.finalize_oneshot(x, peak_db=peak_db), dict(sweep_hz=list(sweep), zap_hz=list(zap),
                                                         crackle_tau_ms=crackle_tau * 1000.0)


# --------------------------------------------------------------------------
# GRAV SKID (spin / slide loop, stabilisers fighting the slide; not a tyre)
# --------------------------------------------------------------------------
def grav_skid_loop(seed=401, T=3.0, stutter_hz=9.0):
    """Two stabiliser jets alternating at 9 Hz (matches the VFX SpinStutterHz), a strained grav-field
    buzz on 74/77 Hz (3 Hz beat, folded), a broad friction scrub with stick-slip roughness, a
    pulsing sub rumble and sparse static grit. No narrow 1-3 kHz tone, so it never reads as a tyre."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    k_st = int(round(stutter_hz * N / SR))
    st = TAU * k_st * n / N + 0.4 * ms.slow(N, r, 0.5, 3.0)
    e1 = (0.5 + 0.5 * np.cos(st)) ** 3
    e2 = (0.5 + 0.5 * np.cos(st + np.pi)) ** 3
    jet1 = ms.pnoise(N, r, lambda f: ms.bp(f, 800.0, 5500.0, 2) * ms.bump(f, 1650.0, 500.0, 8.0))
    jet2 = ms.pnoise(N, r, lambda f: ms.bp(f, 600.0, 4500.0, 2) * ms.bump(f, 1180.0, 380.0, 8.0))
    jets = (0.25 + e1) * jet1 + (0.25 + e2) * jet2
    k1 = int(round(74.0 * N / SR))
    k2 = int(round(77.0 * N / SR))
    saw = ms.saw_table(60)
    buzz = (ms.read_table(saw, k1 * n / N + 0.02 * ms.slow(N, r, 0.5, 15.0, -1.0))
            + 0.8 * ms.read_table(saw, k2 * n / N + 0.02 * ms.slow(N, r, 0.5, 15.0, -1.0)))
    buzz = ms.rasp(buzz, 0.5, 6000.0) * (1.0 + 0.35 * (e1 + e2))
    stick = 0.3 + np.clip(ms.slow(N, r, 25.0, 110.0), 0.0, None) ** 1.5
    scrub = ms.pnoise(N, r, lambda f: ms.bp(f, 220.0, 1800.0, 1)) * stick
    grit = ms.spiky(ms.pnoise(N, r, lambda f: ms.bp(f, 3000.0, 8500.0, 2)), 3.5) * np.clip(ms.slow(N, r, 5.0, 30.0), 0.0, None)
    rum = ms.pnoise(N, r, lambda f: ms.bp(f, 30.0, 140.0, 2)) * (0.5 + 0.8 * (e1 + e2))
    x = (0.8 * jets / ms.rms(jets) + 0.55 * buzz / ms.rms(buzz) + 0.6 * scrub / ms.rms(scrub)
         + 0.12 * grit / ms.rms(grit) + 0.6 * rum / ms.rms(rum))
    x = np.tanh(0.9 * x / ms.rms(x))
    x = ms.ffilt(x, lambda f: ms.hp(f, 35.0, 2) * ms.lp(f, 8500.0, 4))
    return ms.finalize_loop(x), dict(modulation_hz=round(k_st * SR / N, 3), modulation="alternating stabiliser jets",
                                     buzz_hz=[round(k1 * SR / N, 3), round(k2 * SR / N, 3)])


# --------------------------------------------------------------------------
# sound list: name, kind, family, live slot it maps to, builder
# --------------------------------------------------------------------------
P = "Config.Audio.VehicleProfiles.EXOTIC_V10_AUDIO"
SOUNDS = [
    ("v10_idle_1000", "loop", "engine", P + ".RevLayers.V10Idle1000@AssetId", lambda: engine_loop_v2(1000, "idle", 508)),
    ("v10_on_2000", "loop", "engine", P + ".RevLayers.V10On2000@AssetId", lambda: engine_loop_v2(2000, "on", 501)),
    ("v10_on_3500", "loop", "engine", P + ".RevLayers.V10On3500@AssetId", lambda: engine_loop_v2(3500, "on", 502)),
    ("v10_on_5000", "loop", "engine", P + ".RevLayers.V10On5000@AssetId", lambda: engine_loop_v2(5000, "on", 503)),
    ("v10_on_6500", "loop", "engine", P + ".RevLayers.V10On6500@AssetId", lambda: engine_loop_v2(6500, "on", 504)),
    ("v10_on_8000", "loop", "engine", P + ".RevLayers.V10On8000@AssetId", lambda: engine_loop_v2(8000, "on", 505)),
    ("v10_off_3000", "loop", "engine", P + ".RevLayers.V10Off3000@AssetId", lambda: engine_loop_v2(3000, "off", 506)),
    ("v10_off_6000", "loop", "engine", P + ".RevLayers.V10Off6000@AssetId", lambda: engine_loop_v2(6000, "off", 507)),
    ("reactor_whine", "loop", "scifi", P + "@TurboWhistleAssetId", reactor_whine_loop),
    ("reactor_core_alt", "loop", "scifi", P + "@TurboWhistleAssetId (alternative to reactor_whine)", reactor_core_loop),
    ("grav_skid", "loop", "scifi", P + "@SlipStrainAssetId (recommended; see README)", grav_skid_loop),
    ("shift_thunk_1", "oneshot", "shift", "ShiftThunk slot 1 (new, CONTRACT 6)",
     lambda: shift_thunk(601, 0.30, 0.006, (2200.0, 6000.0), [(2350.0, 0.010, 1.0), (3700.0, 0.008, 0.6), (5600.0, 0.005, 0.3)],
                         85.0, 0.040, (2800.0, 4400.0), -12.0)),
    ("shift_thunk_2", "oneshot", "shift", "ShiftThunk slot 2 (new, CONTRACT 6)",
     lambda: shift_thunk(602, 0.36, 0.009, (1500.0, 4500.0), [(1650.0, 0.014, 1.0), (2900.0, 0.010, 0.6), (4300.0, 0.006, 0.3)],
                         62.0, 0.055, (3600.0, 2400.0), -13.0)),
    ("shift_vent_1", "oneshot", "shift", "ShiftVent slot 1 (new, CONTRACT 6)",
     lambda: shift_vent(701, 0.45, (6000.0, 1400.0), (1800.0, 600.0), 70.0, 0.11, 9)),
    ("shift_vent_2", "oneshot", "shift", "ShiftVent slot 2 (new, CONTRACT 6)",
     lambda: shift_vent(702, 0.60, (5200.0, 1100.0), (1400.0, 450.0), 58.0, 0.17, 13)),
]

# Today's live set (round 3/4), re-synthesised from make_sounds.SOUNDS for comparison and the listen
# pack. Same names and seeds as the uploaded files listed in scripts/hover_feel/audio/asset_ids.json.
TODAY_NAMES = ["v10_idle_1000", "v10_on_2000", "v10_on_3500", "v10_on_5000", "v10_on_6500", "v10_on_8000",
               "v10_off_3000", "v10_off_6000", "supercharger_whine", "turbine_low", "turbine_high", "energy_hum", "thruster_roar",
               "boost_loop", "stabiliser_strain", "wind_rush", "wind_buffet", "boost_ignite",
               "pop_1", "pop_2", "pop_3", "pop_4", "bang_1", "bang_2"]


def unevenness_db(x, M, f_cyc, f_max=3000.0):
    """Energy at engine/half orders that are not firing harmonics, against the firing harmonics,
    below f_max (dB). Higher = lumpier, less even firing."""
    X = np.abs(np.fft.rfft(x)) ** 2
    H = int(f_max / f_cyc)
    hh = np.arange(1, H + 1)
    bins = hh * M
    e = X[bins]
    return round(float(10.0 * np.log10(e[hh % 10 != 0].sum() / e[hh % 10 == 0].sum())), 2)


def regenerate_today():
    os.makedirs(TODAY, exist_ok=True)
    table = {name: build for name, kind, family, build in ms.SOUNDS}
    audio = {}
    for name in TODAY_NAMES:
        x, meta = table[name]()
        audio[name] = (ms.write_wav(os.path.join(TODAY, name + ".wav"), x), meta)
    with open(os.path.join(TODAY, "README.txt"), "w", encoding="utf-8") as fh:
        fh.write("Today's live Exotic sounds re-synthesised by scripts/hover_feel/synth/make_sounds.py\n"
                 "(same names and seeds as the uploaded files). Comparison and listen pack only.\n"
                 "Do NOT upload these: they are already live (ids in scripts/hover_feel/audio/asset_ids.json).\n")
    return audio


def main():
    os.makedirs(OUT, exist_ok=True)
    print("re-synthesising today's set into", TODAY)
    today = regenerate_today()
    manifest = []
    audio = {}
    print("%-18s %-7s %7s %7s %7s  %s" % ("file", "kind", "secs", "peak", "rms", "slot"))
    for name, kind, family, slot, build in SOUNDS:
        x, meta = build()
        q = ms.write_wav(os.path.join(OUT, name + ".wav"), x)
        audio[name] = q
        entry = dict(name=name + ".wav", kind=kind, family=family, slot=slot,
                     seconds=round(len(q) / SR, 5), samples=len(q), sample_rate=SR, channels=1, bits=16)
        entry.update(ms.level_metrics(q))
        entry.update(meta)
        if kind == "loop":
            entry["seam"] = ms.seam_metrics(q)
            entry["hf_above_9k_db"] = ms.hf_ratio_db(q)
            if family == "engine":
                entry["band_energy_pct"] = ms.band_shares(q)
                entry["measured_peak_hz"] = round(ms.spectral_peak_hz(q), 4)
                f_cyc = meta["firing_hz"] / 10.0
                entry["unevenness_db"] = unevenness_db(q, meta["engine_cycles"], f_cyc)
                tq, tmeta = today[name]
                entry["today"] = dict(band_energy_pct=ms.band_shares(tq), unevenness_db=unevenness_db(tq, tmeta["engine_cycles"], f_cyc),
                                      same_length=len(tq) == len(q),
                                      octave_distance_to_today=ms.spectral_distance(q, tq))
        else:
            entry.update(ms.oneshot_metrics(q))
            entry.update(ms.oneshot_character(q))
        manifest.append(entry)
        print("%-18s %-7s %7.3f %7.2f %7.2f  %s" % (name, kind, entry["seconds"], entry["peak_dbfs"], entry["rms_dbfs"], slot))

    print()
    print("engine loops, v2 against today (re-synthesised round 3):")
    print("%-15s %9s %9s %7s %13s %13s %13s %9s %7s" % ("loop", "firing", "peak", "anchor", "<250 Hz %", "2-5 kHz %",
                                                        "uneven dB", "seam", "len="))
    for e in manifest:
        if e["family"] != "engine":
            continue
        b, tb = e["band_energy_pct"], e["today"]["band_energy_pct"]
        print("%-15s %9.2f %9.2f %7.2f %6.1f->%-6.1f %6.1f->%-6.1f %6.1f->%-6.1f %9.4f %7s" % (
            e["name"][:-4], e["firing_hz"], e["measured_peak_hz"], e["firing_anchor_gain_db"],
            tb["below_250"], b["below_250"], tb["whine_2k_5k"], b["whine_2k_5k"],
            e["today"]["unevenness_db"], e["unevenness_db"], e["seam"]["jump_over_rms"], e["today"]["same_length"]))
    for e in manifest:
        if e["kind"] == "loop" and e["family"] != "engine":
            print("%-17s seam jump/rms %.4f, hf>9k %.1f dB" % (e["name"][:-4], e["seam"]["jump_over_rms"], e["hf_above_9k_db"]))
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(dict(generator="scripts/drivetrain_feel/synth/make_exotic_v2.py", base="scripts/hover_feel/synth/make_sounds.py",
                       category="exotic", profile="EXOTIC_V10_AUDIO", files=manifest), fh, indent=2)
    print("wrote %d files to %s" % (len(manifest), OUT))


if __name__ == "__main__":
    sys.exit(main())
