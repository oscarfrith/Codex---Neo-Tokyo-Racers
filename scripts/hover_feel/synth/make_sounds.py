"""Space Racers - Exotic category audio synthesis.

Regenerates every WAV in output/hover_feel_audio/exotic/ plus manifest.json:

    py -3 scripts/hover_feel/synth/make_sounds.py

numpy + stdlib only. Deterministic (every sound has a fixed seed).

Loop rule used everywhere
-------------------------
A loop of N samples is seamless when every component is periodic over N.
That is guaranteed here by construction:
  * tones sit on integer FFT bins (an integer number of cycles in N samples);
  * noise is synthesised in the FFT domain (random spectrum -> irfft), which
    makes it exactly N-periodic;
  * modulators (jitter, wobble, gusts) are themselves N-periodic noise;
  * nonlinearities are memoryless (tanh) so periodic in -> periodic out;
  * filtering is done by multiplying the whole-loop FFT (circular filtering).
One-shots use the same tools but with time envelopes and zero padding.
"""
import json
import os
import sys
import wave

import numpy as np

SR = 44100
TABLE = 1 << 16  # wavetable length (one engine cycle / one tone period)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "output", "hover_feel_audio", "exotic")
TAU = 2.0 * np.pi


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------
def amp(db_value):
    return 10.0 ** (db_value / 20.0)


def to_db(x):
    return 20.0 * np.log10(max(float(x), 1e-12))


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))) + 1e-20)


# Magnitude responses (functions of a frequency array in Hz). Butterworth-like.
def lp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def hp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-6)) ** (2 * order))


def bp(f, lo, hi, order=2):
    return hp(f, lo, order) * lp(f, hi, order)


def bump(f, fc, bw, gain_db):
    """Gaussian peak (or dip for negative gain) of +gain_db at fc."""
    return 1.0 + (amp(gain_db) - 1.0) * np.exp(-0.5 * ((f - fc) / bw) ** 2)


def pnoise(n, rng, shape):
    """N-periodic noise with spectral magnitude shape(f); unit RMS."""
    f = np.fft.rfftfreq(n, 1.0 / SR)
    spec = (rng.standard_normal(f.size) + 1j * rng.standard_normal(f.size)) * shape(f)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    return x / rms(x)


def slow(n, rng, lo, hi, slope=0.0):
    """N-periodic band-limited modulator noise (unit RMS), lo..hi Hz."""
    return pnoise(n, rng, lambda f: bp(f, lo, hi, 4) * np.maximum(f, 0.05) ** slope)


def ffilt(x, shape):
    """Zero-phase circular filter over the whole buffer (keeps loops periodic)."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x) * shape(f), len(x))


def ffilt_padded(x, shape, pad=8192):
    """Same filter for one-shots: zero padded so nothing wraps around."""
    y = np.concatenate([np.zeros(pad), x, np.zeros(pad)])
    return ffilt(y, shape)[pad:pad + len(x)]


def make_table(amps, phases):
    """One period of a harmonic series (harmonic h = index h-1) as a wavetable."""
    spec = np.zeros(TABLE // 2 + 1, dtype=complex)
    spec[1:len(amps) + 1] = amps * np.exp(1j * phases)
    tab = np.fft.irfft(spec, TABLE)
    return tab / rms(tab)


def read_table(tab, cycles):
    """Linear-interpolated wavetable read; `cycles` is phase in periods."""
    p = (cycles % 1.0) * TABLE
    i = p.astype(np.int64)
    fr = p - i
    i &= TABLE - 1
    return tab[i] * (1.0 - fr) + tab[(i + 1) & (TABLE - 1)] * fr


def spiky(x, power=3.0):
    """Memoryless expander: turns gaussian noise into sparse crackle."""
    y = np.sign(x) * np.abs(x) ** power
    return y / rms(y)


def rasp(x, amount=0.5, cutoff=9000.0):
    """Controlled rasp for a tonal signal: blend of soft clip and a sine
    wavefolder (both memoryless, so loops stay periodic), then a steep FFT
    low-pass so the fold products never turn into fizz."""
    u = x / rms(x)
    y = (1.0 - amount) * np.tanh(1.2 * u) + amount * np.sin(1.9 * u)
    return ffilt(y, lambda f: lp(f, cutoff, 4))


def saw_table(nh):
    """Sawtooth-like buzz partial series (1/h), band-limited to nh harmonics."""
    h = np.arange(1, nh + 1)
    return make_table(1.0 / h, np.full(nh, -np.pi / 2))


def wander_band(n, rng, k_centre, bw, dev_cycles, lo=0.3, hi=3.0):
    """N-periodic narrow noise band whose centre wanders: complex low-pass
    noise heterodyned by a carrier with periodic phase deviation. Sounds like
    a breathy whistle, never a fixed drone."""
    f = np.abs(np.fft.fftfreq(n, 1.0 / SR))
    z = np.fft.ifft((rng.standard_normal(n) + 1j * rng.standard_normal(n)) * lp(f, bw / 2.0, 2))
    ph = TAU * (k_centre * np.arange(n) / n + dev_cycles * slow(n, rng, lo, hi))
    x = np.real(z * np.exp(1j * ph))
    return x / rms(x)


def finalize_loop(x, rms_db=-17.0, ceil_db=-3.2):
    """DC-free, RMS-normalised, memoryless soft limit under the ceiling."""
    x = x - x.mean()
    x = x * (amp(rms_db) / rms(x))
    lim = amp(ceil_db)
    knee = lim * 0.7
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (lim - knee) * np.tanh((a[over] - knee) / (lim - knee)))
    y -= y.mean()
    pk = np.abs(y).max()
    if pk > lim:
        y *= lim / pk
    return y


# ---- one-shot helpers ----------------------------------------------------
def ad(tt, attack, decay):
    """Attack/decay envelope starting at tt = 0 (zero before)."""
    tp = np.maximum(tt, 0.0)
    return np.where(tt >= 0.0, (1.0 - np.exp(-tp / attack)) * np.exp(-tp / decay), 0.0)


def phase_of(freq):
    """Phase (radians) of an oscillator following freq[t] in Hz."""
    return TAU * np.cumsum(freq) / SR


def bandnoise(n, rng, lo, hi, order=2):
    return pnoise(n, rng, lambda f: bp(f, lo, hi, order))


def swept_noise(n, rng, fc, bw):
    """Band noise whose centre follows fc[t]: complex low-pass noise
    heterodyned up by a swept carrier."""
    f = np.abs(np.fft.fftfreq(n, 1.0 / SR))
    spec = (rng.standard_normal(n) + 1j * rng.standard_normal(n)) * lp(f, bw / 2.0, 2)
    z = np.fft.ifft(spec)
    x = np.real(z * np.exp(1j * phase_of(np.broadcast_to(fc, (n,)))))
    return x / rms(x)


def reverb(x, rng, decay=0.3, mix=0.2, lo=300.0, hi=7000.0, predelay=0.008):
    """Mono 'room' tail: convolution with exponentially decaying band noise."""
    n = len(x)
    m = int(min(n, decay * 7 * SR))
    t = np.arange(m) / SR
    ir = rng.standard_normal(m) * np.exp(-t / decay)
    ir = ffilt_padded(ir, lambda f: bp(f, lo, hi, 1), pad=1024)
    ir /= np.sqrt(np.sum(ir * ir))
    d = int(predelay * SR)
    nfft = 1 << int(np.ceil(np.log2(n + m + d)))
    wet = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)
    wet = np.concatenate([np.zeros(d), wet])[:n]
    return x + mix * wet


def finalize_oneshot(x, peak_db=-3.2, fade_frac=0.2, hp_hz=18.0):
    """High-pass (no DC), 0.3 ms de-click ramp, cosine tail fade, peak normalise."""
    x = ffilt_padded(x, lambda f: hp(f, hp_hz, 2))
    n = len(x)
    ramp = max(2, int(0.0003 * SR))
    x[:ramp] *= np.linspace(0.0, 1.0, ramp)
    nf = int(n * fade_frac)
    x[-nf:] *= 0.5 * (1.0 + np.cos(np.linspace(0.0, np.pi, nf)))
    return x * (amp(peak_db) / np.abs(x).max())


# --------------------------------------------------------------------------
# ENGINE: V10 loops
# --------------------------------------------------------------------------
ENGINE_MODES = {
    # bank / eng / half: level of the 2.5-order (one bank), whole engine orders
    # and half orders relative to the firing harmonics. tilt = spectral slope.
    "on": dict(bank=0.24, eng=0.11, half=0.05, tilt=1.30, jit=0.0015, gainvar=0.05,
               pops=0.0, bias=0.50, noise=0.14, nband=(900.0, 9500.0),
               formants=[(450, 200, 5), (900, 350, 7), (1500, 450, 5), (3100, 800, 7), (5600, 1400, 4)]),
    "off": dict(bank=0.25, eng=0.20, half=0.13, tilt=1.60, jit=0.004, gainvar=0.45,
                pops=0.12, bias=0.50, noise=0.25, nband=(250.0, 3500.0),
                formants=[(240, 90, 6), (700, 300, -7), (1700, 350, 5)]),
    "idle": dict(bank=0.50, eng=0.28, half=0.20, tilt=1.40, jit=0.006, gainvar=0.20,
                 pops=0.0, bias=0.45, noise=0.18, nband=(200.0, 5000.0),
                 formants=[(180, 80, 5), (520, 200, 4), (1400, 400, 3)]),
}


PRESENCE_ON_DB = 4.0    # EQ at 3.3 kHz, tuned so the 2-5 kHz 'whine' band lands 4-6 dB
PRESENCE_OFF_DB = -2.0  # under round 2 once the new low end and saturation are in
SHEEN_DB = -20.0    # ring-mod sheen level relative to the engine


def engine_length(rpm, target=3.0):
    """Pick M engine cycles (720 deg) and N samples so N is an exact integer
    number of cycles; prefer the length closest to `target` seconds."""
    f_cyc = rpm / 120.0
    best = None
    for m in range(int(f_cyc * 2.2), int(f_cyc * 3.8) + 1):
        n = m * SR / f_cyc
        if abs(n - round(n)) < 1e-6:
            if best is None or abs(n / SR - target) < abs(best[1] / SR - target):
                best = (m, int(round(n)))
    if best is None:
        m = int(round(f_cyc * target))
        best = (m, int(round(m * SR / f_cyc)))
    return best


def engine_loop(rpm, mode, seed):
    """V10 steady-state loop.

    One engine cycle (two crank revolutions, ten firings) is a wavetable built
    as a harmonic series of the cycle frequency: every 10th harmonic is a firing
    harmonic (dominant), every 5th is the per-bank 2.5 order, the rest are
    engine/half orders from cylinder-to-cylinder differences. The table is read
    with a jittered (but loop-periodic) phase, scaled per firing event, mixed
    with firing-synchronous noise, saturated and EQ'd in the FFT domain.
    """
    p = ENGINE_MODES[mode]
    r = np.random.default_rng(seed)
    M, N = engine_length(rpm)
    f_cyc = M * SR / N
    f_fire = 10.0 * f_cyc
    n = np.arange(N)
    rev = float(np.clip((rpm - 1000.0) / 7000.0, 0.0, 1.0))

    # Cycle-to-cycle jitter: slow periodic noise added to the phase. Because it
    # scales with harmonic number, top harmonics smear into noise (as they do
    # in a real exhaust) while the firing line stays tonal.
    ph = M * n / N + p["jit"] * slow(N, r, 0.7, 35.0, -1.0)

    H = int(min(15000.0 / f_cyc, TABLE // 2 - 1))
    h = np.arange(1, H + 1)
    f = h * f_cyc
    smooth = 1.0 - 0.5 * rev if mode == "on" else 1.0  # smoother at high revs
    tilt = p["tilt"] - (0.45 * rev if mode == "on" else 0.0)
    env = np.where(f >= f_fire, (f / f_fire) ** -tilt, (f / f_fire) ** 0.2)
    for fc, bw, g in p["formants"]:  # exhaust/intake resonances
        env = env * bump(f, fc, bw, g)

    def table():
        w = np.where(h % 10 == 0, 1.0,
                     np.where(h % 5 == 0, p["bank"] * smooth,
                              np.where(h % 2 == 0, p["eng"] * smooth, p["half"])))
        w = w * np.where(h < 10, 2.2, 1.0)  # weight on the orders under the firing line
        scatter = np.where(h % 10 == 0, 0.15, 0.40)
        a = env * w * np.exp(scatter * r.standard_normal(H))
        # The two tables share their base phases (so morphing never cancels a
        # line) and differ by a small per-harmonic offset.
        return make_table(a, base_phase + 0.35 * r.standard_normal(H))

    # near-zero phases = sharp exhaust pulse; scatter grows with frequency
    base_phase = r.standard_normal(H) * np.clip(0.8 + f / 3000.0, 0.0, 2.5)

    tab_a, tab_b = table(), table()
    morph = np.clip(0.5 + 0.3 * slow(N, r, 1.5, 11.0), 0.0, 1.0)
    x = (1.0 - morph) * read_table(tab_a, ph) + morph * read_table(tab_b, ph)

    # Per-firing gain: fixed per-cylinder offsets plus random event variation
    # (strong on overrun = burble). Stepped between pulses, then smoothed.
    fire_idx = np.floor(10.0 * ph + 0.5).astype(np.int64) % (10 * M)
    cyl = r.standard_normal(10)
    gains = 1.0 + p["gainvar"] * (0.3 * cyl[np.arange(10 * M) % 10] + 0.8 * r.standard_normal(10 * M))
    gains = np.clip(gains, 0.15, 1.6)
    g = ffilt(gains[fire_idx], lambda fr: lp(fr, 1.5 * f_fire, 2))
    x = x * g
    x /= rms(x)

    # Firing-synchronous gas noise.
    pulse = (0.5 + 0.5 * np.cos(TAU * 10.0 * ph)) ** 2
    lo, hi = p["nband"]
    nz = pnoise(N, r, lambda fr: bp(fr, lo, hi, 2) * np.maximum(fr, 1.0) ** -0.3)
    nz = nz * (0.35 + 1.3 * pulse)
    level = p["noise"] + (0.10 * rev if mode == "on" else 0.0)
    x = x + level * nz / rms(nz)

    # Depth and grunge, added BEFORE the saturator so they intermodulate with
    # the firing harmonics (growl): the sub-octave of the firing frequency, the
    # first and half engine orders, a low rumble bed, and firing-pulsed exhaust
    # rasp in the 300-1200 Hz band.
    sub = np.sin(TAU * 5.0 * ph) + 0.45 * np.sin(TAU * 2.0 * ph + 1.0) + 0.3 * np.sin(TAU * ph + 2.0)
    rumble = pnoise(N, r, lambda fr: bp(fr, 35.0, 220.0, 2)) * (1.0 + 0.4 * slow(N, r, 4.0, 30.0))
    exrasp = pnoise(N, r, lambda fr: bp(fr, 300.0, 1200.0, 2)) * (0.3 + 1.4 * pulse)
    x = x + 0.35 * sub + 0.25 * rumble + 0.30 * exrasp / rms(exrasp)

    # Overrun pops: sparse impulses on random firings, circularly convolved
    # with a short decaying noise burst.
    if p["pops"] > 0.0:
        starts = np.flatnonzero(np.diff(fire_idx) != 0) + 1
        chosen = starts[r.random(starts.size) < p["pops"]]
        imp = np.zeros(N)
        imp[chosen] = 0.5 + r.random(chosen.size)
        k = np.zeros(N)
        m = int(0.08 * SR)
        k[:m] = r.standard_normal(m) * np.exp(-np.arange(m) / (0.012 * SR))
        pops = np.fft.irfft(np.fft.rfft(imp) * np.fft.rfft(k), N)
        pops = ffilt(pops, lambda fr: bp(fr, 150.0, 2500.0, 2))
        x = x + 0.5 * pops / rms(pops)

    # Asymmetric saturation (even + odd harmonics): the hard edge.
    drive = {"on": 0.6 + 0.3 * rev, "off": 0.7, "idle": 0.7}[mode]
    x = np.tanh(drive * x + p["bias"])
    x -= x.mean()

    if mode == "on":
        eq = lambda fr: (hp(fr, 28.0, 2) * lp(fr, 11000.0, 4) * bump(fr, 3300.0, 1500.0, PRESENCE_ON_DB)
                         * bump(fr, 700.0, 350.0, 3.0) * bump(fr, 110.0, 80.0, 3.0))
    elif mode == "off":
        fc = 1800.0 + 0.3 * rpm  # darker; the hollow scoop is in the formants
        eq = lambda fr: (hp(fr, 28.0, 2) * lp(fr, fc, 2) * bump(fr, 3300.0, 1500.0, PRESENCE_OFF_DB)
                         * bump(fr, 700.0, 350.0, 2.0) * bump(fr, 110.0, 80.0, 3.0))
    else:
        eq = lambda fr: hp(fr, 30.0, 2) * lp(fr, 6000.0, 2)
    x = ffilt(x, eq)
    extra = {}

    if mode == "on":
        # Sci-fi sheen: ring-modulate the engine with a carrier at an inharmonic
        # multiple (2.76x) of the firing frequency. The carrier is derived from
        # the engine phase, so the metallic sidebands track the revs.
        c = int(round(27.6 * M))
        ring = ffilt(x * np.sin(TAU * c * ph / M), lambda fr: bp(fr, 1200.0, 5000.0, 2))
        x = x + amp(SHEEN_DB) * ring * rms(x) / rms(ring)
        extra = dict(sheen_db=SHEEN_DB, sheen_carrier_ratio=round(c / (10.0 * M), 4))
    elif mode == "idle":
        # Hybrid idle: an energy-core hum a fifth above the firing note that
        # throbs at 2 Hz, plus a faint turbine whisper.
        k_throb = int(round(2.0 * N / SR))
        kh = 15 * M
        hh = np.arange(1, 41)
        core = np.zeros(N)
        for k, lvl in [(kh, 1.0), (kh + k_throb, 0.5), (2 * kh + 3 * k_throb, 0.35)]:
            tab = make_table(hh ** -0.9, 0.6 * r.standard_normal(40))
            core += lvl * read_table(tab, k * n / N + 0.003 * slow(N, r, 0.5, 20.0, -1.0))
        core = rasp(core, 0.4, 6000.0)
        core = ffilt(core, lambda fr: bump(fr, 400.0, 150.0, 5.0) * bump(fr, 1250.0, 350.0, 6.0))
        core = core * (0.72 + 0.28 * np.cos(TAU * k_throb * n / N)) * (1.0 + 0.12 * slow(N, r, 60.0, 120.0))
        kt = int(round(2640.0 * N / SR))
        whisper = 0.6 * np.sin(TAU * kt * n / N + 1.5 * slow(N, r, 1.0, 20.0, -0.5))
        whisper = whisper + pnoise(N, r, lambda fr: bp(fr, 2500.0, 8000.0, 2)) * (1.0 + 0.3 * slow(N, r, 3.0, 20.0))
        x = x / rms(x) + 0.5 * core / rms(core) + 0.11 * whisper / rms(whisper)
        extra = dict(modulation_hz=round(k_throb * SR / N, 3), modulation="energy-core throb",
                     core_tone_hz=round(kh * SR / N, 3), whisper_tone_hz=round(kt * SR / N, 3))

    # Anchor: the firing line must be the strongest component (the game and the
    # verification both treat it as the loop's pitch). Raise that one FFT bin
    # only if a resonance has overtaken it.
    X = np.fft.rfft(x)
    kf = 10 * M
    mag = np.abs(X)
    other = np.delete(mag, kf)[1:].max()
    anchor_db = 0.0
    if mag[kf] < 1.26 * other:
        gain = 1.26 * other / mag[kf]
        X[kf] *= gain
        anchor_db = to_db(gain)
        x = np.fft.irfft(X, N)

    meta = dict(rpm=rpm, mode=mode, firing_hz=round(f_fire, 4), nominal_firing_hz=round(rpm / 12.0, 4),
                engine_cycles=M, firing_periods=10 * M, firing_anchor_gain_db=round(anchor_db, 2))
    meta.update(extra)
    return finalize_loop(x), meta


# --------------------------------------------------------------------------
# SCI-FI LAYER LOOPS
# --------------------------------------------------------------------------
BOOST_CHORD_HZ = 110.0  # boost_loop power-chord root; the ignite sweep resolves onto it
BOOST_PULSE_HZ = 10.0   # boost_loop pulse-jet thump rate


def turbine_loop(blade_hz, seed, T=3.0):
    """Jet turbine: blade-pass tone + harmonics, shaft-order 'buzz-saw' lines,
    a second detuned engine (beats), an inharmonic second spool and shaped hiss."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    blades = 24
    k_shaft = int(round(blade_hz / blades * N / SR))
    k_bp = k_shaft * blades
    scale = blade_hz / 1320.0
    ps = k_shaft * n / N + 0.004 * slow(N, r, 0.6, 14.0, -1.0)  # shaft phase, cycles

    H = blades * 5
    h = np.arange(1, H + 1)
    a = 0.05 * np.exp(0.5 * r.standard_normal(H)) / (1.0 + (h / 40.0) ** 2)  # buzz-saw
    for j, lvl in enumerate([0.30, 0.18, 0.12, 0.06, 0.03]):  # blade-pass set, 5 dB down in round 3
        a[blades * (j + 1) - 1] = lvl
    eng1 = read_table(make_table(a, r.uniform(0, TAU, H)), ps)

    # Twin engine: blade-pass 10 bins (3.3 Hz) sharp, own phase wander.
    p2 = (k_bp + 10) * n / N + 0.08 * slow(N, r, 0.6, 14.0, -1.0)
    eng2 = read_table(make_table(np.array([1.0, 0.45, 0.2, 0.08]), r.uniform(0, TAU, 4)), p2)

    k_sp = int(round(blade_hz * 1.37 * N / SR))  # second spool, inharmonic
    p3 = k_sp * n / N + 0.06 * slow(N, r, 0.6, 14.0, -1.0)
    spool = np.sin(TAU * p3) + 0.35 * np.sin(2 * TAU * p3 + 1.0)

    # Rasp: a sawtooth buzz series two octaves under the blade pass, a
    # band-limited fold over the whole tonal part, and 60-120 Hz roughness.
    k_buzz = k_bp // 4
    buzz = read_table(saw_table(int(min(9000.0 / (blade_hz / 4.0), 60))),
                      k_buzz * n / N + 0.02 * slow(N, r, 0.6, 14.0, -1.0))
    tones = (eng1 + 0.25 * eng2 + 0.3 * spool + 0.4 * buzz) * (1.0 + 0.15 * slow(N, r, 4.0, 30.0))
    tones = rasp(tones, 0.45, 9000.0) * (1.0 + 0.22 * slow(N, r, 60.0, 120.0))
    hiss = pnoise(N, r, lambda f: bp(f, blade_hz * 0.9, 14000.0, 2)
                  * bump(f, blade_hz * 2.3, blade_hz * 0.8, 6.0))
    hiss = hiss * (1.0 + 0.3 * slow(N, r, 20.0, 200.0)) * (1.0 + 0.25 * np.cos(TAU * ps))
    # Low roar bed (same band for both turbines) so the scream sits on a body.
    rumble = pnoise(N, r, lambda f: bp(f, 60.0, 500.0, 2)) * (1.0 + 0.4 * slow(N, r, 3.0, 40.0))

    x = 0.6 * tones / rms(tones) + 0.7 * hiss / rms(hiss) + 0.65 * rumble / rms(rumble)
    x = np.tanh(0.7 * x)
    x = ffilt(x, lambda f: hp(f, 50.0, 2) * lp(f, 7800.0, 8))
    return finalize_loop(x), dict(main_tone_hz=round(k_bp * SR / N, 3),
                                  modulation_hz=round(10 * SR / N, 3), modulation="twin-engine beat")


def energy_hum_loop(seed=31, T=3.0):
    """Podracer energy-binder hum: detuned buzzy pulse voices beating against
    each other, ring roughness, heavy saturation, arc crackle."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    k0 = int(round(80.0 * N / SR))
    H = 70
    h = np.arange(1, H + 1)
    amps = h ** -0.8 * np.where(h % 2 == 1, 1.6, 1.0)

    def voice(k, nh=H):
        tab = make_table(amps[:nh], 0.6 * r.standard_normal(nh))
        return read_table(tab, k * n / N + 0.003 * slow(N, r, 0.5, 20.0, -1.0))

    x = (voice(k0) + 0.8 * voice(k0 + 7)                 # 2.33 Hz beat
         + 0.5 * voice(int(round(1.5 * k0)) + 4)         # fifth, 1.33 Hz off
         + 0.5 * voice(k0 // 2, 6))                      # sub octave
    x = x + 0.35 * rms(x) * read_table(saw_table(50), 2 * k0 * n / N + 0.004 * slow(N, r, 0.5, 20.0, -1.0))
    x = x * (1.0 + 0.25 * slow(N, r, 2.5, 18.0))         # instability
    x = x * (1.0 + 0.25 * np.cos(TAU * int(round(50.0 * N / SR)) * n / N))
    x = np.tanh(1.8 * x / rms(x))
    x = rasp(x, 0.5, 9000.0) * (1.0 + 0.2 * slow(N, r, 60.0, 120.0))
    x = ffilt(x, lambda f: hp(f, 30.0, 2) * lp(f, 9000.0, 3) * bump(f, 320.0, 120.0, 5.0)
              * bump(f, 1150.0, 300.0, 6.0) * bump(f, 2700.0, 600.0, 5.0))
    crackle = spiky(pnoise(N, r, lambda f: bp(f, 2500.0, 8000.0, 2)), 3.0)
    crackle = crackle * np.clip(1.0 + 0.6 * slow(N, r, 3.0, 25.0), 0.0, None)
    x = x / rms(x) + 0.12 * ffilt(crackle, lambda f: lp(f, 9000.0, 4))
    return finalize_loop(x), dict(main_tone_hz=round(k0 * SR / N, 3),
                                  modulation_hz=round(7 * SR / N, 3), modulation="voice beat")


def thruster_roar_loop(seed=41, T=3.5):
    """Body layer under boost_loop: sub/rumble and fire texture only, low-passed
    at 300 Hz (4th order) so it stacks without masking."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    rumble = pnoise(N, r, lambda f: hp(f, 28.0, 2) / (1.0 + (f / 90.0) ** 1.5))
    rumble = rumble * (1.0 + 0.45 * slow(N, r, 3.0, 45.0))
    k = int(round(48.0 * N / SR))
    growl = read_table(saw_table(6), k * n / N + 0.02 * slow(N, r, 0.5, 25.0, -1.0))
    tex = spiky(pnoise(N, r, lambda f: bp(f, 60.0, 300.0, 2)), 2.5) * np.clip(slow(N, r, 8.0, 40.0), 0.0, None)
    x = rumble + 0.3 * growl + 0.3 * tex / rms(tex)
    x = np.tanh(0.9 * x / rms(x))
    x = ffilt(x, lambda f: hp(f, 28.0, 2) * bump(f, 90.0, 50.0, 4.0) * lp(f, 300.0, 4))
    return finalize_loop(x), dict(main_tone_hz=round(k * SR / N, 3))


def boost_loop(seed=45, T=3.5):
    """Whole-boost loop, a different family from the engines: thunderous
    afterburner. Broadband fire with an 80-400 Hz body and crackle, a pulse-jet
    train of sub thumps (10 per second, each with a detonation noise burst), and
    a modest saturated power chord (root, fifth, octave on 110 Hz) for lift."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    fire = pnoise(N, r, lambda f: hp(f, 40.0, 2) * bump(f, 200.0, 140.0, 10.0) / (1.0 + (f / 600.0) ** 1.1))
    fire = fire * (1.0 + 0.4 * slow(N, r, 3.0, 40.0))
    crackle = spiky(pnoise(N, r, lambda f: bp(f, 500.0, 6000.0, 1)), 3.5)
    crackle = crackle * np.clip(slow(N, r, 8.0, 60.0), 0.0, None)

    # Pulse train: an integer number of pulses per loop, slightly uneven in
    # level and timing, circularly convolved with each kernel (so it loops).
    k_p = int(round(BOOST_PULSE_HZ * N / SR))
    imp = np.zeros(N)
    for j in range(k_p):
        imp[int(round(j * N / k_p + r.normal(0.0, 0.0015) * SR)) % N] = 1.0 + 0.15 * r.standard_normal()
    m = int(0.25 * SR)
    tk = np.arange(m) / SR

    def train(kernel):
        kern = np.zeros(N)
        kern[:m] = kernel
        return np.fft.irfft(np.fft.rfft(imp) * np.fft.rfft(kern), N)

    thump = train(np.sin(phase_of(42.0 + 25.0 * np.exp(-tk / 0.02))) * np.exp(-tk / 0.04) * (1.0 - np.exp(-tk / 0.002)))
    det = ffilt(train(r.standard_normal(m) * np.exp(-tk / 0.022)), lambda f: bp(f, 100.0, 1500.0, 2))
    pump = train(np.exp(-tk / 0.05))
    pump = pump / pump.max()

    chord = np.zeros(N)
    k_root = int(round(BOOST_CHORD_HZ * N / SR))
    for kk, lvl in [(k_root, 1.0), (k_root + 3, 0.6), (int(round(1.5 * k_root)), 0.7),
                    (int(round(1.5 * k_root)) + 3, 0.4), (2 * k_root, 0.6), (2 * k_root + 3, 0.3)]:
        chord += lvl * read_table(saw_table(18), kk * n / N + 0.004 * slow(N, r, 0.5, 12.0, -1.0))
    chord = np.tanh(1.5 * chord / rms(chord))
    chord = ffilt(chord, lambda f: hp(f, 80.0, 2) * lp(f, 2800.0, 3)) * (0.75 + 0.25 * pump)

    x = (fire / rms(fire) + 0.35 * crackle / rms(crackle) + 1.1 * thump / rms(thump)
         + 0.5 * det / rms(det) + 0.4 * chord / rms(chord))
    x = np.tanh(0.75 * x / rms(x))
    x = ffilt(x, lambda f: hp(f, 28.0, 2) * lp(f, 8000.0, 4))
    return finalize_loop(x), dict(main_tone_hz=round(k_root * SR / N, 3),
                                  modulation_hz=round(k_p * SR / N, 3), modulation="pulse-jet thump train",
                                  chord="root, fifth, octave")


def supercharger_whine_loop(seed=51, T=3.0):
    """Gear-drive growl-whine: an 8-tooth mesh series on 501 Hz with heavy
    shaft-rate sidebands, a sawtooth shaft growl underneath, fold rasp,
    60-120 Hz roughness and pulsing air noise."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    k_shaft = int(round(62.5 * N / SR))
    k = k_shaft * 8
    shaft = TAU * k_shaft * n / N
    pm = 0.6 * np.sin(shaft) + 0.25 * np.sin(2 * shaft + 0.7) + 0.08 * slow(N, r, 1.0, 40.0)
    ph = TAU * k * n / N + pm
    mesh = np.zeros(N)
    for order in range(1, 9):
        mesh += np.sin(order * ph + r.uniform(0, TAU)) / order ** 0.9
    growl = read_table(saw_table(30), k_shaft * n / N + 0.01 * slow(N, r, 0.5, 20.0, -1.0))
    x = mesh / rms(mesh) + 0.5 * growl
    x = x * (1.0 + 0.2 * np.sin(shaft + 0.4) + 0.15 * slow(N, r, 60.0, 120.0))
    x = rasp(x, 0.45, 7000.0)
    air = pnoise(N, r, lambda f: bp(f, 800.0, 5000.0, 2)) * (1.0 + 0.3 * np.sin(shaft))
    x = x / rms(x) + 0.12 * air
    x = ffilt(x, lambda f: hp(f, 50.0, 2) * lp(f, 8000.0, 4))
    return finalize_loop(x), dict(main_tone_hz=round(k * SR / N, 3), shaft_hz=round(k_shaft * SR / N, 3))


def stabiliser_strain_loop(seed=61, T=3.0):
    """Drift 'squeal': strained jet hiss plus warbling FM shrieks a fifth
    apart, with stick-slip style roughness."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    k = int(round(2350.0 * N / SR))
    shriek = np.zeros(N)
    for ratio, lvl in [(1.0, 1.0), (1.5, 0.6), (2.0, 0.35)]:
        kk = int(round(k * ratio))
        shriek += lvl * np.sin(TAU * kk * n / N + 2.5 * ratio * slow(N, r, 4.0, 60.0, -0.5))
    shriek = shriek + 0.45 * rms(shriek) * read_table(
        saw_table(7), (k // 2) * n / N + 0.2 * slow(N, r, 4.0, 60.0, -0.5))
    shriek = rasp(shriek, 0.5, 9000.0)
    rough = 1.0 + 0.3 * slow(N, r, 60.0, 120.0)
    narrow = pnoise(N, r, lambda f: np.exp(-0.5 * ((f - 2350.0) / 45.0) ** 2)
                    + 0.6 * np.exp(-0.5 * ((f - 3525.0) / 70.0) ** 2))
    hiss = pnoise(N, r, lambda f: bp(f, 1800.0, 11000.0, 2) * np.maximum(f, 1.0) ** -0.3)
    hiss = hiss * (1.0 + 0.25 * slow(N, r, 10.0, 90.0))
    x = (0.8 * shriek / rms(shriek) + 0.5 * narrow) * rough + 0.9 * hiss
    x = np.tanh(0.8 * x / rms(x))
    x = ffilt(x, lambda f: hp(f, 500.0, 2) * lp(f, 7800.0, 8))
    return finalize_loop(x), dict(main_tone_hz=round(k * SR / N, 3))


def drift_charge_loop(seed=71, T=3.0):
    """Charge tone: just-intonation stack on 330 Hz (root, fifth, octave,
    twelfth, double octave, major third above that). Each partial is a detuned
    pair with a different beat rate so nothing fades in and out together."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    x = np.zeros(N)
    for hz, lvl, det in [(330, 1.0, 3), (495, 0.55, 4), (660, 0.5, 5),
                         (990, 0.25, 6), (1320, 0.18, 7), (1650, 0.08, 8)]:
        k = int(round(hz * N / SR))
        x += lvl * (np.sin(TAU * k * n / N + r.uniform(0, TAU))
                    + 0.5 * np.sin(TAU * (k + det) * n / N + r.uniform(0, TAU)))
    x = x * (1.0 + 0.2 * np.sin(TAU * 24 * n / N))  # 8 Hz tension pulse
    x = np.tanh(0.8 * x / rms(x))
    shimmer = pnoise(N, r, lambda f: bp(f, 4000.0, 9000.0, 2)) * (1.0 + 0.6 * np.sin(TAU * 48 * n / N))
    x = x + 0.03 * shimmer
    x = ffilt(x, lambda f: hp(f, 100.0, 2) * lp(f, 12000.0, 2))
    return finalize_loop(x), dict(main_tone_hz=round(int(round(330 * N / SR)) * SR / N, 3),
                                  modulation_hz=round(24 * SR / N, 3), modulation="tension pulse")


def wind_rush_loop(seed=81, T=4.0):
    """Speed wind: shaped broadband noise, mild gusting, and two breathy
    'moving air' whistles whose centres wander (no fixed-pitch drone), so it
    still reads as wind when the game raises its gain and pitch."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    x = pnoise(N, r, lambda f: bp(f, 120.0, 9000.0, 1) * np.maximum(f / 600.0, 1e-3) ** -0.5
               * bump(f, 900.0, 500.0, 5.0) * bump(f, 2800.0, 1200.0, 3.0))
    x = x * (1.0 + 0.18 * slow(N, r, 0.8, 7.0))
    w1 = wander_band(N, r, int(round(2300.0 * N / SR)), 320.0, 40.0)
    w2 = wander_band(N, r, int(round(3900.0 * N / SR)), 500.0, 55.0)
    x = x + 0.30 * w1 * (1.0 + 0.4 * slow(N, r, 0.5, 5.0)) + 0.20 * w2 * (1.0 + 0.4 * slow(N, r, 0.5, 5.0))
    return finalize_loop(x), dict(whistle_centres_hz=[2300.0, 3900.0])


def wind_buffet_loop(seed=85, T=4.0):
    """Very-high-speed buffeting: low noise slammed by an irregular 3-14 Hz
    envelope, with a mid 'flap' band on the same envelope so it survives
    small speakers."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    env = 0.15 + np.clip(slow(N, r, 3.0, 14.0), 0.0, None) ** 1.5
    low = pnoise(N, r, lambda f: hp(f, 25.0, 2) / (1.0 + (f / 90.0) ** 1.5))
    mid = pnoise(N, r, lambda f: bp(f, 180.0, 1400.0, 1))
    x = (low + 0.35 * mid) * env
    x = np.tanh(0.8 * x / rms(x))
    x = ffilt(x, lambda f: hp(f, 25.0, 2) * lp(f, 4000.0, 2))
    return finalize_loop(x), dict(modulation_band_hz=[3.0, 14.0], modulation="irregular buffet")


def scrape_loop(seed=91, T=2.5):
    """Hull on wall: stick-slip modulated noise through narrow inharmonic
    'plate' resonances, plus sparse high grit, saturated."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    stick = 0.25 + np.clip(slow(N, r, 35.0, 160.0), 0.0, None) ** 1.5
    src = pnoise(N, r, lambda f: bp(f, 300.0, 10000.0, 1)) * stick
    modes = [(740, 25, 9), (1235, 30, 8), (1890, 35, 9), (2710, 45, 7),
             (3530, 50, 6), (4870, 60, 5), (6200, 80, 4)]

    def plate(f):
        g = 0.15 + np.zeros_like(f)
        for fc, bw, lvl in modes:
            g = g + lvl * np.exp(-0.5 * ((f - fc) / bw) ** 2)
        return g

    body = ffilt(src, plate)
    grit = spiky(pnoise(N, r, lambda f: bp(f, 3000.0, 9000.0, 2)), 3.0) * stick
    x = body / rms(body) + 0.3 * grit / rms(grit)
    x = np.tanh(1.2 * x)
    x = ffilt(x, lambda f: hp(f, 150.0, 2) * lp(f, 13000.0, 2))
    return finalize_loop(x), dict(main_tone_hz=740.0)


# --------------------------------------------------------------------------
# ONE-SHOTS
# --------------------------------------------------------------------------
def flutter_chuffs(n, rng, t0, count, rate0, rate1, amp_decay, bright=1.0):
    """Compressor-surge flutter: `count` chuffs, rate slowing rate0 -> rate1 Hz.
    Each chuff = downward-swept band noise + a pitched 'thup'."""
    out = np.zeros(n)
    tc = t0
    for i in range(count):
        u = i / max(count - 1, 1)
        i0 = int(tc * SR)
        m = min(n, i0 + int(0.15 * SR)) - i0
        if m <= 16:
            break
        ts = np.arange(m) / SR
        nz = swept_noise(m, rng, (900.0 + 1900.0 * np.exp(-ts / 0.012)) * bright, 1600.0 * bright)
        thup = np.sin(phase_of(200.0 + 260.0 * np.exp(-ts / 0.02)))
        a = amp_decay ** i * (1.0 + 0.1 * rng.standard_normal())
        out[i0:i0 + m] += a * ad(ts, 0.0012, 0.013 + 0.010 * u) * (nz + 0.7 * thup)
        tc += (1.0 / (rate0 + (rate1 - rate0) * u)) * (1.0 + 0.06 * rng.standard_normal())
    return out


def saw_sum(ph, nh):
    return sum(np.sin(h * ph) / h for h in range(1, nh + 1))


def boost_ignite(seed=101):
    """Afterburner lighting. 100 ms reverse suck-in (hard gate) -> cannon crack
    (click, snap, saturated body, low boom) with a 50 -> 30 Hz sub drop held
    for ~300 ms -> thick fire-blast whoosh -> a power-up sweep that dives then
    rises onto the boost_loop chord root while pulse-jet thumps fade in."""
    r = np.random.default_rng(seed)
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    tc, t_hand = 0.10, 0.70
    s = np.clip(t / tc, 0.0, 1.0)
    gate = np.clip((tc - 0.008 - t) / 0.004, 0.0, 1.0)
    fc = 400.0 * (7000.0 / 400.0) ** s
    suck = 0.8 * swept_noise(n, r, fc, 1200.0) + 0.4 * swept_noise(n, r, fc * 1.7, 3000.0)
    suck += 0.4 * np.sin(phase_of(200.0 * (2000.0 / 200.0) ** s))
    x = 0.5 * suck * (0.05 + s ** 2.5) * gate

    tt = t - tc
    on = (tt >= 0.0).astype(float)
    tp = np.maximum(tt, 0.0)
    click = r.standard_normal(n) * ad(tt, 0.0002, 0.0018)
    snap = bandnoise(n, r, 900.0, 9000.0) * ad(tt, 0.0005, 0.028)
    body = np.tanh(3.0 * np.sin(phase_of((60.0 + 180.0 * np.exp(-tp / 0.025)) * on))) * ad(tt, 0.001, 0.12)
    boom = bandnoise(n, r, 40.0, 350.0) * ad(tt, 0.002, 0.14)
    sub = np.tanh(1.6 * np.sin(phase_of((30.0 + 20.0 * np.exp(-tp / 0.15)) * on)) * ad(tt, 0.005, 0.30))
    blast = bandnoise(n, r, 90.0, 6000.0, 1) * ad(tt, 0.02, 0.32)
    blast += 0.6 * swept_noise(n, r, 600.0 + 5000.0 * np.exp(-tp / 0.3), 3500.0) * ad(tt, 0.012, 0.30)

    # Power-up sweep: 3x root diving below the root in 180 ms, then rising onto it.
    td = 0.18
    root = BOOST_CHORD_HZ
    f_sw = np.where(tp < td, 3.0 * root * (0.73 / 3.0) ** (tp / td),
                    root - 0.27 * root * np.exp(-(tp - td) / 0.12)) * on
    p1, p2 = phase_of(f_sw), phase_of(f_sw * 1.006)
    sw = saw_sum(p1, 14) + 0.6 * saw_sum(p2, 14) + 0.7 * saw_sum(1.5 * p1, 10) + 0.6 * saw_sum(2.0 * p1, 8)
    sw = ffilt_padded(np.tanh(1.5 * sw / rms(sw)), lambda f: lp(f, 3000.0, 3))
    env = (1.0 - np.exp(-tp / 0.04)) * np.where(t < t_hand, 1.0, np.exp(-np.maximum(t - t_hand, 0.0) / 0.35)) * on

    # Pulse-jet thumps at the loop's rate, fading in then out with the sweep.
    thumps = np.zeros(n)
    m = int(0.25 * SR)
    ts = np.arange(m) / SR
    kern = np.sin(phase_of(42.0 + 25.0 * np.exp(-ts / 0.02))) * np.exp(-ts / 0.04) * (1.0 - np.exp(-ts / 0.002))
    j = 0
    while True:
        tj = tc + 0.25 + j / BOOST_PULSE_HZ
        i0 = int(tj * SR)
        if i0 + m >= n:
            break
        thumps[i0:i0 + m] += kern * min(1.0, (j + 1) / 4.0) * np.exp(-max(tj - t_hand, 0.0) / 0.35)
        j += 1

    x = (x + 1.0 * click + 0.8 * snap + 0.9 * body + 0.7 * boom + 1.2 * sub + 0.55 * blast
         + 0.30 * sw / rms(sw) * 0.6 * env + 0.45 * thumps)
    x = np.tanh(1.5 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.25, mix=0.15)
    return finalize_oneshot(x), dict(suck_in_start_ms=0.0, crack_ms=tc * 1000.0,
                                     sweep_bottom_ms=(tc + td) * 1000.0, handover_ms=t_hand * 1000.0,
                                     first_thump_ms=(tc + 0.25) * 1000.0, thump_rate_hz=BOOST_PULSE_HZ,
                                     resolves_to_hz=root)


def boost_release(seed=111):
    """Decisive ending: the roar is cut (30 ms low tail), a pressure-release
    'pshh', a 'thunk' at 90 ms, a short falling chord tone, then four chuffs."""
    r = np.random.default_rng(seed)
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    cut = bandnoise(n, r, 60.0, 500.0) * np.exp(-t / 0.03)
    pshh = bandnoise(n, r, 2500.0, 10000.0) * ad(t, 0.003, 0.11)
    pshh += 0.6 * swept_noise(n, r, 1500.0 + 4000.0 * np.exp(-t / 0.10), 2500.0) * ad(t, 0.004, 0.14)
    t_th = 0.09
    tt = t - t_th
    on = (tt >= 0.0).astype(float)
    tp = np.maximum(tt, 0.0)
    thunk = np.tanh(2.5 * np.sin(phase_of((50.0 + 70.0 * np.exp(-tp / 0.015)) * on))) * ad(tt, 0.001, 0.07)
    thunk += 0.5 * r.standard_normal(n) * ad(tt, 0.0002, 0.002) + 0.6 * bandnoise(n, r, 100.0, 900.0) * ad(tt, 0.001, 0.03)
    p = phase_of(70.0 + (2.0 * BOOST_CHORD_HZ - 70.0) * np.exp(-t / 0.12))
    tone = np.tanh(1.5 * (saw_sum(p, 10) + 0.7 * saw_sum(1.5 * p, 8)))
    tone = ffilt_padded(tone, lambda f: lp(f, 3000.0, 3)) * ad(t, 0.005, 0.20)
    x = (0.7 * cut + 0.8 * pshh + 1.1 * thunk + 0.3 * tone
         + 0.8 * flutter_chuffs(n, r, 0.28, 4, 17.0, 12.0, 0.72))
    x = np.tanh(1.3 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.14, mix=0.12)
    return finalize_oneshot(x), dict(thunk_ms=t_th * 1000.0, flutter_start_ms=280.0,
                                     tone_start_hz=2.0 * BOOST_CHORD_HZ, tone_end_hz=70.0)


def gun_crack(n, rng, t0, bright, fast=0.004, slow_=0.018):
    """Gunshot-like crack: instant-onset noise, broadband up to `bright`,
    with a hard 4 ms spike and a short body."""
    tt = np.arange(n) / SR - t0
    tp = np.maximum(tt, 0.0)
    env = np.where(tt >= 0.0, np.exp(-tp / fast) + 0.35 * np.exp(-tp / slow_), 0.0)
    return (bandnoise(n, rng, 400.0, bright, 1) + 0.5 * rng.standard_normal(n) * np.exp(-tp / 0.0012)) * env


def pipe_tail(src, pipes):
    """Exhaust-pipe resonance: convolve the crack with damped resonances
    (freq Hz, decay s, level). Noise-excited, so it is a 'bark', not a note."""
    n = len(src)
    m = int(0.3 * SR)
    ts = np.arange(m) / SR
    ir = sum(lvl * np.exp(-ts / tau) * np.sin(TAU * f * ts) for f, tau, lvl in pipes)
    nfft = 1 << int(np.ceil(np.log2(n + m)))
    y = np.fft.irfft(np.fft.rfft(src, nfft) * np.fft.rfft(ir, nfft), nfft)[:n]
    return y / (np.abs(y).max() + 1e-12)


def low_thump(n, t0, hz, decay):
    """Short hard low thump: a damped cosine burst (starts at full pressure)."""
    tt = np.arange(n) / SR - t0
    tp = np.maximum(tt, 0.0)
    return np.where(tt >= 0.0, np.cos(TAU * hz * tp) * np.exp(-tp / decay), 0.0)


def pop(seed, pipes, bright, thump_hz, seconds, peak_db=-3.2):
    """Overrun / anti-lag backfire, gunshot-like: sub-millisecond crack with
    energy to 8 kHz, a hard 80-150 Hz thump, and a tight two-resonance
    exhaust-pipe tail (plus a very slight metallic pipe ring). Hard-clipped
    for violence; almost no reverb."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    crack = gun_crack(n, r, 0.0, bright)
    tail = pipe_tail(crack, [(pipes[0], 0.026, 1.0), (pipes[1], 0.020, 0.7), (pipes[2], 0.010, 0.12)])
    thump = np.tanh(2.0 * low_thump(n, 0.0, thump_hz, 0.018))
    x = 1.2 * crack / np.abs(crack).max() + 0.4 * thump + 0.8 * tail
    x = np.tanh(2.6 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.03, mix=0.04)
    return finalize_oneshot(x, peak_db=peak_db), dict(pipe_resonances_hz=list(pipes[:2]), pipe_ring_hz=pipes[2],
                                                      thump_hz=thump_hz, crack_bright_hz=bright)


def bang(seed, pipes, thump_hz, gap, seconds, peak_db=-3.2):
    """Shotgun backfire: two cracks `gap` seconds apart, each with a heavier
    60-90 Hz thump and a pipe-resonance tail, then a short flame whoosh."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    c1 = gun_crack(n, r, 0.0, 8500.0, 0.005, 0.025)
    c2 = gun_crack(n, r, gap, 7500.0, 0.005, 0.030)
    crack = c1 / np.abs(c1).max() + 0.9 * c2 / np.abs(c2).max()
    tail = pipe_tail(crack, [(pipes[0], 0.034, 1.0), (pipes[1], 0.026, 0.7), (pipes[2], 0.010, 0.10)])
    thump = np.tanh(2.2 * (low_thump(n, 0.0, thump_hz, 0.035) + low_thump(n, gap, thump_hz * 0.9, 0.040)))
    whoosh = bandnoise(n, r, 150.0, 2500.0, 1) * ad(t - gap, 0.04, 0.10)
    whoosh += 0.25 * spiky(bandnoise(n, r, 800.0, 5000.0), 3.0) * ad(t - gap, 0.02, 0.08)
    x = 1.2 * crack + 0.5 * thump + 0.8 * tail + 0.30 * whoosh
    x = np.tanh(2.8 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.05, mix=0.05)
    return finalize_oneshot(x, peak_db=peak_db), dict(pipe_resonances_hz=list(pipes[:2]), thump_hz=thump_hz,
                                                      second_crack_ms=gap * 1000.0,
                                                      whoosh_peak_ms=(gap + 0.06) * 1000.0)


def turbo_flutter(seed=121):
    """Lift-off flutter: 8 chuffs slowing 24 -> 13 Hz over a fading air hiss."""
    r = np.random.default_rng(seed)
    n = int(0.85 * SR)
    t = np.arange(n) / SR
    x = flutter_chuffs(n, r, 0.0, 8, 24.0, 13.0, 0.80)
    x += 0.12 * bandnoise(n, r, 1500.0, 8000.0) * ad(t, 0.003, 0.16)
    x = np.tanh(1.4 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.10, mix=0.10)
    return finalize_oneshot(x), dict(chuffs=8)


def drift_release(seed=131):
    """Mini-boost: pop, a 3-octave saturated upward zap (with a fifth), then
    bright harmonic pings and a short sparkle of high noise."""
    r = np.random.default_rng(seed)
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    pop = r.standard_normal(n) * ad(t, 0.0002, 0.002)
    pop += 1.2 * np.sin(phase_of(110.0 + 190.0 * np.exp(-t / 0.015))) * ad(t, 0.001, 0.05)
    rise = np.clip(t / 0.16, 0.0, 1.0)
    ph = phase_of(450.0 * 8.0 ** rise)
    zap = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.4 * np.sin(1.5 * ph)
    zap = np.tanh(1.5 * zap) * (1.0 - np.exp(-t / 0.003)) * np.where(t < 0.16, 1.0, np.exp(-(t - 0.16) / 0.05))
    tt = t - 0.14
    ping = np.zeros(n)
    for hz, lvl in [(2640.0, 1.0), (3960.0, 0.6), (5280.0, 0.4)]:
        ping += lvl * np.sin(TAU * hz * t + 1.5 * np.sin(TAU * 55.0 * t)) * ad(tt, 0.002, 0.10)
    sparkle = bandnoise(n, r, 6000.0, 13000.0) * ad(tt, 0.002, 0.07)
    x = 0.9 * pop + 0.7 * zap + 0.35 * ping + 0.4 * sparkle
    x = np.tanh(1.3 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.12, mix=0.2)
    return finalize_oneshot(x), {}


def crack_clicks(n, rng, times, level, decay=0.0008, hp_hz=1500.0):
    """Plastic/carbon cracks: very short broadband clicks at the given times."""
    out = np.zeros(n)
    m = int(0.012 * SR)
    ts = np.arange(m) / SR
    for when in times:
        i0 = int(when * SR)
        if i0 + m < n:
            out[i0:i0 + m] += rng.standard_normal(m) * np.exp(-ts / decay) * level * rng.uniform(0.4, 1.0)
    return ffilt_padded(out, lambda f: hp(f, hp_hz, 2))


def noise_grains(n, rng, times, f_lo, f_hi, bw_lo, bw_hi, dec_lo, dec_hi, fade):
    """Irregular bursts of narrow NOISE bands (never sines) at random
    inharmonic centres: each is a short damped resonance excited by noise, so
    a dense scatter reads as crumpling metal rather than a bell."""
    out = np.zeros(n)
    for when in times:
        dec = rng.uniform(dec_lo, dec_hi)
        m = int(min(6.0 * dec, 0.3) * SR)
        i0 = int(when * SR)
        if i0 + m >= n:
            continue
        ts = np.arange(m) / SR
        fc = np.exp(rng.uniform(np.log(f_lo), np.log(f_hi)))
        g = swept_noise(m, rng, fc, rng.uniform(bw_lo, bw_hi)) * ad(ts, 0.0004, dec)
        out[i0:i0 + m] += g * rng.uniform(0.35, 1.0) * np.exp(-when / fade)
    return out


def impact(seed, seconds, w, peak_db):
    """Real-car hull hit; w = weight 0 (light knock) .. 1 (severe crash).
    No sine, no sweep, no ring: everything is shaped noise.
      thud     low-passed noise burst + a fast-dying 60-120 Hz noise body
      crumple  dense irregular 400 Hz-3 kHz noise-band bursts, 20-60 ms each
      cracks   very short broadband clicks
      heavy+   low whump, sparse debris/glass ticks over 0.3-0.8 s, and a
               faint electrical fizz kept 18 dB under the crumple."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    body_lo, body_hi = 120.0 - 60.0 * w, 200.0 - 80.0 * w
    thud = bandnoise(n, r, 30.0, 380.0 - 130.0 * w) * ad(t, 0.0006, 0.022 + 0.035 * w)
    thud += 1.2 * bandnoise(n, r, body_lo, body_hi) * ad(t, 0.001, 0.028 + 0.045 * w)
    knock = bandnoise(n, r, 300.0, 1400.0) * ad(t, 0.0004, 0.010 + 0.012 * w)

    spread = 0.025 + 0.16 * w
    times = np.sort(0.002 + r.exponential(spread, int(7 + 70 * w)))
    crumple = noise_grains(n, r, times, 400.0, 3000.0, 90.0, 380.0, 0.006, 0.018, 0.05 + 0.3 * w)
    bed = bandnoise(n, r, 400.0, 3000.0) * np.clip(0.3 + pnoise(n, r, lambda f: bp(f, 12.0, 70.0, 2)), 0.0, None)
    crumple = crumple / (rms(crumple)) + 0.5 * bed * ad(t, 0.002, 0.03 + 0.14 * w)
    cracks = crack_clicks(n, r, np.concatenate([[0.0], r.exponential(spread * 0.8, int(2 + 9 * w))]), 1.0)

    x = (1.0 + 0.5 * w) * thud + 0.5 * knock + (0.35 + 0.5 * w) * crumple / rms(crumple) * 0.4 + 0.5 * cracks
    fizz_db = None
    if w >= 0.6:
        whump = bandnoise(n, r, 35.0, 220.0) * ad(t - 0.02, 0.025, 0.11 + 0.05 * w)
        debris_t = 0.05 + r.uniform(0.0, 0.3 + 0.5 * w, int(10 + 24 * w))
        glass = noise_grains(n, r, debris_t, 3500.0, 8500.0, 200.0, 900.0, 0.0015, 0.005, 0.25 + 0.3 * w)
        glass += crack_clicks(n, r, 0.05 + r.uniform(0.0, 0.3 + 0.5 * w, int(8 + 14 * w)), 0.6, 0.0006, 3000.0)
        x = x + 0.9 * whump + 0.16 * glass / (np.abs(glass).max() + 1e-12) * np.abs(x).max()
        # Sci-fi trace: a short electrical fizz, 18 dB under the crumple.
        fizz = spiky(bandnoise(n, r, 3000.0, 7000.0), 3.0)
        fizz = fizz * np.clip(pnoise(n, r, lambda f: bp(f, 20.0, 90.0, 2)), 0.0, None) * ad(t - 0.03, 0.01, 0.10)
        seg = slice(0, int(0.3 * SR))
        crunch_part = (0.35 + 0.5 * w) * crumple / rms(crumple) * 0.4
        fizz_db = -18.0
        x = x + fizz * amp(fizz_db) * rms(crunch_part[seg]) / rms(fizz[seg])
    x = np.tanh((1.3 + 1.2 * w) * x / np.abs(x).max())
    x = reverb(x, r, decay=0.04 + 0.05 * w, mix=0.06)
    return finalize_oneshot(x, peak_db=peak_db), dict(weight=w, body_band_hz=[body_lo, body_hi],
                                                      fizz_db_re_crumple=fizz_db)


def land_thump(seed=181):
    """Hover bottoming out like heavy suspension: dead low thud (noise, no
    tone), a mechanical clunk, and a brief fixed-band air-compression huff."""
    r = np.random.default_rng(seed)
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    thud = bandnoise(n, r, 28.0, 190.0) * ad(t, 0.001, 0.06)
    thud += 1.2 * bandnoise(n, r, 45.0, 95.0) * ad(t, 0.002, 0.085)
    clunk = bandnoise(n, r, 300.0, 1000.0) * ad(t, 0.0004, 0.014)
    clunk += 0.6 * crack_clicks(n, r, [0.0, 0.011], 1.0)
    huff = bandnoise(n, r, 300.0, 2500.0, 1) * ad(t - 0.01, 0.03, 0.11)
    x = 1.6 * thud + 0.45 * clunk + 0.30 * huff
    x = np.tanh(1.6 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.05, mix=0.06)
    return finalize_oneshot(x, hp_hz=30.0), {}


# --------------------------------------------------------------------------
# analysis (shared with verify.py)
# --------------------------------------------------------------------------
def seam_metrics(x):
    """Discontinuity at the loop join of x played twice.
    jump_*: sample step across the join vs. RMS / vs. steps inside the loop.
    flux_*: STFT spectral flux of frames straddling the join vs. elsewhere."""
    n = len(x)
    jump = abs(float(x[0]) - float(x[-1]))
    d = np.abs(np.diff(x))
    y = np.concatenate([x, x])
    win, hop = 1024, 256
    idx = np.arange(0, 2 * n - win, hop)
    mag = np.abs(np.fft.rfft(y[idx[:, None] + np.arange(win)] * np.hanning(win), axis=1))
    nrm = np.linalg.norm(mag, axis=1)
    fl = np.linalg.norm(np.diff(mag, axis=0), axis=1) / (nrm[1:] + nrm[:-1] + 1e-12)
    span = (idx[1:] + win > n) & (idx[:-1] < n)
    seam, other = fl[span].max(), fl[~span]
    # Click detector: energy above 15 kHz in a short window. A real seam
    # discontinuity is broadband, so it would tower over every other window.
    w = 256
    pos = np.arange(w, 2 * n - w, w // 2)
    pos = np.concatenate([pos[np.abs(pos - n) > w], [n]])
    seg = y[(pos - w // 2)[:, None] + np.arange(w)] * np.hanning(w)
    hf = (np.abs(np.fft.rfft(seg, axis=1))[:, int(15000 * w / SR):] ** 2).sum(axis=1)
    return dict(jump_over_rms=round(jump / rms(x), 5),
                jump_over_median_step=round(jump / (float(np.median(d)) + 1e-12), 3),
                jump_over_max_step=round(jump / float(d.max()), 4),
                flux_seam_over_median=round(float(seam / np.median(other)), 3),
                flux_seam_over_p99=round(float(seam / np.percentile(other, 99)), 3),
                flux_seam_over_max=round(float(seam / other.max()), 3),
                hf_click_seam_over_median_db=round(float(10 * np.log10(hf[-1] / np.median(hf[:-1]) + 1e-20)), 1),
                hf_click_seam_over_max_db=round(float(10 * np.log10(hf[-1] / hf[:-1].max() + 1e-20)), 1))


def spectral_peak_hz(x, lo=20.0):
    mag = np.abs(np.fft.rfft(x))
    k0 = int(np.ceil(lo * len(x) / SR))
    return (k0 + int(np.argmax(mag[k0:]))) * SR / len(x)


def oneshot_metrics(x):
    above = np.flatnonzero(np.abs(x) > amp(-60.0))
    lead = above[0] / SR * 1000.0 if above.size else float("inf")
    tail = np.abs(x[-int(0.010 * SR):]).max()
    return dict(leading_silence_ms=round(float(lead), 3), tail_last10ms_dbfs=round(to_db(tail), 1),
                transient_peak_ms=round(float(np.argmax(np.abs(x))) / SR * 1000.0, 2))


def attack_ms(x):
    """Time from 10 % of peak to the first sample at 90 % of peak."""
    a = np.abs(x)
    pk = a.max()
    i0 = int(np.argmax(a > 0.1 * pk))
    i1 = int(np.argmax(a >= 0.9 * pk))
    return round((i1 - i0) / SR * 1000.0, 3)


def short_term_db(x, window=0.05):
    """Loudest 50 ms: maximum RMS over a sliding window (dBFS)."""
    w = int(window * SR)
    c = np.concatenate([[0.0], np.cumsum(np.square(x))])
    return round(to_db(np.sqrt((c[w:] - c[:-w]).max() / w)), 2)


def tonality_db(x):
    """How far the strongest narrow spectral line (15 Hz wide) stands above
    its 600 Hz neighbourhood, 150 Hz .. 8 kHz. Noise-like sounds score a few
    dB; a ringing tone scores 15 dB or more."""
    nfft = 1 << 17
    p = np.abs(np.fft.rfft(x, nfft)) ** 2
    hz = SR / nfft

    def box(v, width_hz):
        k = max(1, int(width_hz / hz))
        return np.convolve(v, np.ones(k) / k, mode="same")

    ratio = box(p, 15.0) / (box(p, 600.0) + 1e-20)
    lo, hi = int(150.0 / hz), int(8000.0 / hz)
    return round(float(10.0 * np.log10(ratio[lo:hi].max())), 1)


def oneshot_character(x):
    lv = level_metrics(x)
    return dict(attack_ms=attack_ms(x), crest_db=round(lv["peak_dbfs"] - lv["rms_dbfs"], 2),
                short_term_50ms_dbfs=short_term_db(x), tonality_db=tonality_db(x))


def hf_ratio_db(x, above=9000.0):
    """Energy above `above` Hz relative to the whole signal (dB)."""
    p = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    return round(float(10.0 * np.log10(p[f > above].sum() / p.sum() + 1e-20)), 1)


def band_shares(x):
    """Share (%) of energy below 250 Hz, 250-2000 Hz, above 2000 Hz, plus the
    2-5 kHz 'whine' band on its own."""
    p = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    tot = p.sum()
    pct = lambda lo, hi: round(float(100.0 * p[(f >= lo) & (f < hi)].sum() / tot), 2)
    return dict(below_250=pct(0, 250), mid_250_2000=pct(250, 2000), above_2000=pct(2000, SR),
                whine_2k_5k=pct(2000, 5000))


def third_octave(x):
    """Energy in third-octave bands from 25 Hz to 16 kHz (dB)."""
    p = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    centres = 25.0 * 2.0 ** (np.arange(29) / 3.0)
    e = np.array([p[(f >= c / 2 ** (1 / 6)) & (f < c * 2 ** (1 / 6))].sum() for c in centres])
    return 10.0 * np.log10(e / e.sum() + 1e-12)


def spectral_distance(a, b):
    """Cosine distance between octave-band energy distributions (linear power
    in nine octaves, 22 Hz .. 11 kHz). 0 = energy in the same octaves,
    1 = no octave in common. Robust to where individual tonal lines fall."""
    def octaves(x):
        e = 10.0 ** (third_octave(x) / 10.0)
        return e[:27].reshape(9, 3).sum(axis=1)  # 22 Hz .. 11 kHz in nine octaves
    u, v = octaves(a), octaves(b)
    return round(float(1.0 - u @ v / (np.linalg.norm(u) * np.linalg.norm(v))), 4)


def spectral_shape_distance(a, b):
    """1 - correlation of mean-removed third-octave dB levels (floored at
    -50 dB). A stricter 'overall contour' measure: 0 = same contour."""
    u = np.clip(third_octave(a), -50.0, None)
    v = np.clip(third_octave(b), -50.0, None)
    u, v = u - u.mean(), v - v.mean()
    return round(float(1.0 - u @ v / (np.linalg.norm(u) * np.linalg.norm(v))), 4)


def level_metrics(x):
    return dict(peak_dbfs=round(to_db(np.abs(x).max()), 2), rms_dbfs=round(to_db(rms(x)), 2),
                dc_offset=round(float(x.mean()), 7))


# --------------------------------------------------------------------------
# build
# --------------------------------------------------------------------------
def write_wav(path, x):
    pcm = np.round(np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return pcm.astype(np.float64) / 32768.0  # what a player will actually see


SOUNDS = [
    # name, kind, family, builder
    ("v10_on_2000", "loop", "engine", lambda: engine_loop(2000, "on", 1)),
    ("v10_on_3500", "loop", "engine", lambda: engine_loop(3500, "on", 2)),
    ("v10_on_5000", "loop", "engine", lambda: engine_loop(5000, "on", 3)),
    ("v10_on_6500", "loop", "engine", lambda: engine_loop(6500, "on", 4)),
    ("v10_on_8000", "loop", "engine", lambda: engine_loop(8000, "on", 5)),
    ("v10_off_3000", "loop", "engine", lambda: engine_loop(3000, "off", 6)),
    ("v10_off_6000", "loop", "engine", lambda: engine_loop(6000, "off", 7)),
    ("v10_idle_1000", "loop", "engine", lambda: engine_loop(1000, "idle", 8)),
    ("turbine_low", "loop", "scifi", lambda: turbine_loop(1320.0, 21)),
    ("turbine_high", "loop", "scifi", lambda: turbine_loop(2640.0, 22)),
    ("energy_hum", "loop", "scifi", energy_hum_loop),
    ("thruster_roar", "loop", "scifi", thruster_roar_loop),
    ("boost_loop", "loop", "scifi", boost_loop),
    ("supercharger_whine", "loop", "scifi", supercharger_whine_loop),
    ("stabiliser_strain", "loop", "scifi", stabiliser_strain_loop),
    ("drift_charge", "loop", "scifi", drift_charge_loop),
    ("wind_rush", "loop", "scifi", wind_rush_loop),
    ("wind_buffet", "loop", "scifi", wind_buffet_loop),
    ("scrape_loop", "loop", "scifi", scrape_loop),
    ("boost_ignite", "oneshot", "boost", boost_ignite),
    ("boost_release", "oneshot", "boost", boost_release),
    ("turbo_flutter", "oneshot", "boost", turbo_flutter),
    ("drift_release", "oneshot", "boost", drift_release),
    ("pop_1", "oneshot", "pop", lambda: pop(201, (240.0, 410.0, 2100.0), 8000.0, 110.0, 0.26)),
    ("pop_2", "oneshot", "pop", lambda: pop(202, (310.0, 480.0, 2600.0), 6500.0, 130.0, 0.22)),
    ("pop_3", "oneshot", "pop", lambda: pop(203, (205.0, 350.0, 1800.0), 9000.0, 90.0, 0.30)),
    ("pop_4", "oneshot", "pop", lambda: pop(204, (270.0, 455.0, 2350.0), 7500.0, 150.0, 0.24)),
    ("bang_1", "oneshot", "pop", lambda: bang(211, (220.0, 380.0, 1900.0), 80.0, 0.055, 0.55)),
    ("bang_2", "oneshot", "pop", lambda: bang(212, (190.0, 330.0, 1700.0), 65.0, 0.075, 0.68)),
    ("impact_light", "oneshot", "impact", lambda: impact(141, 0.22, 0.0, -8.0)),
    ("impact_medium", "oneshot", "impact", lambda: impact(151, 0.45, 0.33, -6.0)),
    ("impact_heavy", "oneshot", "impact", lambda: impact(161, 0.90, 0.67, -4.0)),
    ("impact_severe", "oneshot", "impact", lambda: impact(171, 1.30, 1.0, -3.2)),
    ("land_thump", "oneshot", "impact", land_thump),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = []
    audio = {}
    for name, kind, family, build in SOUNDS:
        x, meta = build()
        q = write_wav(os.path.join(OUT, name + ".wav"), x)
        entry = dict(name=name + ".wav", kind=kind, family=family,
                     seconds=round(len(q) / SR, 5), samples=len(q), sample_rate=SR,
                     channels=1, bits=16)
        audio[name] = q
        entry.update(level_metrics(q))
        entry.update(meta)
        if kind == "loop":
            entry["seam"] = seam_metrics(q)
            entry["hf_above_9k_db"] = hf_ratio_db(q)
            if family == "engine":
                entry["band_energy_pct"] = band_shares(q)
                entry["measured_peak_hz"] = round(spectral_peak_hz(q), 4)
        else:
            entry.update(oneshot_metrics(q))
            entry.update(oneshot_character(q))
        manifest.append(entry)
        print("%-24s %-7s %6.3fs peak %6.2f rms %6.2f" % (
            name, kind, entry["seconds"], entry["peak_dbfs"], entry["rms_dbfs"]))
    # Family separation: how far boost_loop's octave-band energy is from the engine's.
    by_name = {e["name"][:-4]: e for e in manifest}
    by_name["boost_loop"]["spectral_distance"] = {
        other: dict(octave_energy=spectral_distance(audio["boost_loop"], audio[other]),
                    third_octave_contour=spectral_shape_distance(audio["boost_loop"], audio[other]))
        for other in ("v10_on_6500", "turbine_low", "supercharger_whine", "thruster_roar")}
    by_name["v10_on_6500"]["spectral_distance"] = {
        other: dict(octave_energy=spectral_distance(audio["v10_on_6500"], audio[other]),
                    third_octave_contour=spectral_shape_distance(audio["v10_on_6500"], audio[other]))
        for other in ("v10_on_5000", "v10_on_8000")}
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(dict(generator="scripts/hover_feel/synth/make_sounds.py", category="exotic",
                       files=manifest), fh, indent=2)
    print("wrote %d files to %s" % (len(manifest), OUT))


if __name__ == "__main__":
    sys.exit(main())
