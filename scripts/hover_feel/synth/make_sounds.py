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
               pops=0.0, bias=0.25, noise=0.14, nband=(900.0, 9500.0),
               formants=[(650, 260, 5), (1500, 450, 8), (3100, 800, 9), (5600, 1400, 5)]),
    "off": dict(bank=0.25, eng=0.20, half=0.13, tilt=1.60, jit=0.004, gainvar=0.45,
                pops=0.12, bias=0.35, noise=0.25, nband=(250.0, 3500.0),
                formants=[(240, 90, 6), (700, 300, -7), (1700, 350, 5)]),
    "idle": dict(bank=0.50, eng=0.28, half=0.20, tilt=1.40, jit=0.006, gainvar=0.20,
                 pops=0.0, bias=0.30, noise=0.18, nband=(200.0, 5000.0),
                 formants=[(180, 80, 5), (520, 200, 4), (1400, 400, 3)]),
}


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
    env = np.where(f >= f_fire, (f / f_fire) ** -tilt, (f / f_fire) ** 0.6)
    for fc, bw, g in p["formants"]:  # exhaust/intake resonances
        env = env * bump(f, fc, bw, g)

    def table():
        w = np.where(h % 10 == 0, 1.0,
                     np.where(h % 5 == 0, p["bank"] * smooth,
                              np.where(h % 2 == 0, p["eng"] * smooth, p["half"])))
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
    drive = {"on": 0.5 + 0.35 * rev, "off": 0.6, "idle": 0.6}[mode]
    x = np.tanh(drive * x + p["bias"])
    x -= x.mean()

    if mode == "on":
        eq = lambda fr: hp(fr, 35.0, 2) * lp(fr, 13000.0, 4) * bump(fr, 3000.0, 1200.0, 3.0)
    elif mode == "off":
        fc = 1800.0 + 0.3 * rpm  # darker; the hollow scoop is in the formants
        eq = lambda fr: hp(fr, 35.0, 2) * lp(fr, fc, 2)
    else:
        eq = lambda fr: hp(fr, 30.0, 2) * lp(fr, 6000.0, 2)
    x = ffilt(x, eq)

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
    return finalize_loop(x), meta


# --------------------------------------------------------------------------
# SCI-FI LAYER LOOPS
# --------------------------------------------------------------------------
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
    for j, lvl in enumerate([1.0, 0.5, 0.28, 0.12, 0.05]):
        a[blades * (j + 1) - 1] = lvl
    eng1 = read_table(make_table(a, r.uniform(0, TAU, H)), ps)

    # Twin engine: blade-pass 10 bins (3.3 Hz) sharp, own phase wander.
    p2 = (k_bp + 10) * n / N + 0.08 * slow(N, r, 0.6, 14.0, -1.0)
    eng2 = read_table(make_table(np.array([1.0, 0.45, 0.2, 0.08]), r.uniform(0, TAU, 4)), p2)

    k_sp = int(round(blade_hz * 1.37 * N / SR))  # second spool, inharmonic
    p3 = k_sp * n / N + 0.06 * slow(N, r, 0.6, 14.0, -1.0)
    spool = np.sin(TAU * p3) + 0.35 * np.sin(2 * TAU * p3 + 1.0)

    tones = (eng1 + 0.75 * eng2 + 0.3 * spool) * (1.0 + 0.15 * slow(N, r, 4.0, 30.0))
    hiss = pnoise(N, r, lambda f: bp(f, blade_hz * 0.9, 14000.0, 2)
                  * bump(f, blade_hz * 2.3, blade_hz * 0.8, 6.0))
    hiss = hiss * (1.0 + 0.3 * slow(N, r, 20.0, 200.0)) * (1.0 + 0.25 * np.cos(TAU * ps))
    rumble = pnoise(N, r, lambda f: bp(f, 45.0 * scale, 400.0 * scale, 2))

    x = tones / rms(tones) + 0.7 * hiss / rms(hiss) + (0.3 / scale) * rumble
    x = np.tanh(0.7 * x)
    x = ffilt(x, lambda f: hp(f, 50.0, 2) * lp(f, 15000.0, 4))
    return finalize_loop(x), dict(main_tone_hz=round(k_bp * SR / N, 3),
                                  twin_beat_hz=round(10 * SR / N, 3))


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
    x = x * (1.0 + 0.25 * slow(N, r, 2.5, 18.0))         # instability
    x = x * (1.0 + 0.25 * np.cos(TAU * int(round(50.0 * N / SR)) * n / N))
    x = np.tanh(1.8 * x / rms(x))
    x = ffilt(x, lambda f: hp(f, 30.0, 2) * lp(f, 9000.0, 2) * bump(f, 320.0, 120.0, 5.0)
              * bump(f, 1150.0, 300.0, 6.0) * bump(f, 2700.0, 600.0, 5.0))
    crackle = spiky(pnoise(N, r, lambda f: bp(f, 2500.0, 9000.0, 2)), 3.0)
    crackle = crackle * np.clip(1.0 + 0.6 * slow(N, r, 3.0, 25.0), 0.0, None)
    x = x / rms(x) + 0.12 * crackle
    return finalize_loop(x), dict(main_tone_hz=round(k0 * SR / N, 3), beat_hz=round(7 * SR / N, 3))


def thruster_roar_loop(seed=41, T=3.5):
    """Afterburner body: turbulent low rumble, a jittered low growl, crackle."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    rumble = pnoise(N, r, lambda f: hp(f, 30.0, 2) / (1.0 + (f / 120.0) ** 1.3))
    rumble = rumble * (1.0 + 0.45 * slow(N, r, 3.0, 45.0))
    k = int(round(48.0 * N / SR))
    h = np.arange(1, 13)
    growl = read_table(make_table(1.0 / h, r.uniform(0, TAU, 12)),
                       k * n / N + 0.02 * slow(N, r, 0.5, 25.0, -1.0))
    crackle = spiky(pnoise(N, r, lambda f: bp(f, 600.0, 7000.0, 1)), 3.5)
    crackle = crackle * np.clip(slow(N, r, 8.0, 60.0), 0.0, None)
    x = rumble + 0.3 * growl + 0.35 * crackle / rms(crackle)
    x = np.tanh(1.5 * x / rms(x) * 0.6)
    x = ffilt(x, lambda f: hp(f, 28.0, 2) * bump(f, 90.0, 50.0, 4.0) * lp(f, 9000.0, 1))
    return finalize_loop(x), dict(main_tone_hz=round(k * SR / N, 3))


def supercharger_whine_loop(seed=51, T=3.0):
    """Gear whine: mesh orders 1..4 phase/amplitude modulated at shaft rate
    (sidebands) plus a little jitter and air noise. Mesh tone 1000 Hz."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    n = np.arange(N)
    k_shaft = int(round(62.5 * N / SR))
    k = k_shaft * 16  # 16-tooth mesh
    shaft = TAU * k_shaft * n / N
    pm = 0.25 * np.sin(shaft) + 0.10 * np.sin(2 * shaft + 0.7) + 0.05 * slow(N, r, 1.0, 40.0)
    ph = TAU * k * n / N + pm
    x = np.zeros(N)
    for order, lvl in [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.12), (0.25, 0.12), (1.5, 0.08)]:
        x += lvl * np.sin(order * ph + r.uniform(0, TAU))
    x = x * (1.0 + 0.12 * np.sin(shaft + 0.4) + 0.05 * slow(N, r, 5.0, 60.0))
    air = pnoise(N, r, lambda f: bp(f, 2000.0, 7000.0, 2))
    x = np.tanh(0.9 * x / rms(x)) + 0.06 * air
    x = ffilt(x, lambda f: hp(f, 120.0, 2) * lp(f, 12000.0, 2))
    return finalize_loop(x), dict(main_tone_hz=round(k * SR / N, 3))


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
    rough = 1.0 + 0.3 * slow(N, r, 50.0, 110.0)
    narrow = pnoise(N, r, lambda f: np.exp(-0.5 * ((f - 2350.0) / 45.0) ** 2)
                    + 0.6 * np.exp(-0.5 * ((f - 3525.0) / 70.0) ** 2))
    hiss = pnoise(N, r, lambda f: bp(f, 1800.0, 11000.0, 2) * np.maximum(f, 1.0) ** -0.3)
    hiss = hiss * (1.0 + 0.25 * slow(N, r, 10.0, 90.0))
    x = (0.8 * shriek / rms(shriek) + 0.5 * narrow) * rough + 0.9 * hiss
    x = np.tanh(0.8 * x / rms(x))
    x = ffilt(x, lambda f: hp(f, 500.0, 2) * lp(f, 14000.0, 2))
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
    return finalize_loop(x), dict(main_tone_hz=round(int(round(330 * N / SR)) * SR / N, 3))


def wind_rush_loop(seed=81, T=4.0):
    """High-speed air: shaped broadband noise with mild fast gusting."""
    r = np.random.default_rng(seed)
    N = int(T * SR)
    x = pnoise(N, r, lambda f: bp(f, 120.0, 9000.0, 1) * np.maximum(f / 600.0, 1e-3) ** -0.5
               * bump(f, 900.0, 500.0, 5.0) * bump(f, 2800.0, 1200.0, 3.0)
               * bump(f, 2100.0, 80.0, 4.0))
    x = x * (1.0 + 0.18 * slow(N, r, 0.8, 7.0))
    return finalize_loop(x), {}


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


def boost_ignite(seed=101):
    """Suck-in (rising swept noise + tone, hard gate) -> 12 ms of vacuum ->
    crack (click + snap + saturated body) with sub drop, falling whoosh and a
    twin turbine scream spooling up."""
    r = np.random.default_rng(seed)
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    tc = 0.26
    s = np.clip(t / tc, 0.0, 1.0)
    gate = np.clip((tc - 0.012 - t) / 0.006, 0.0, 1.0)
    fc = 250.0 * (6000.0 / 250.0) ** s
    suck = 0.8 * swept_noise(n, r, fc, 900.0) + 0.4 * swept_noise(n, r, fc * 1.9, 2500.0)
    suck += 0.35 * np.sin(phase_of(140.0 * (1500.0 / 140.0) ** s) + 3.0 * np.sin(TAU * 38.0 * t))
    x = 0.45 * suck * (0.04 + s ** 3) * gate

    tt = t - tc
    on = (tt >= 0.0).astype(float)
    tp = np.maximum(tt, 0.0)
    click = r.standard_normal(n) * ad(tt, 0.0002, 0.0018)
    snap = bandnoise(n, r, 900.0, 9000.0) * ad(tt, 0.0005, 0.028)
    body = np.tanh(3.0 * np.sin(phase_of((70.0 + 170.0 * np.exp(-tp / 0.03)) * on))) * ad(tt, 0.001, 0.11)
    sub = np.sin(phase_of((30.0 + 70.0 * np.exp(-tp / 0.30)) * on)) * ad(tt, 0.004, 0.40)
    sub = np.tanh(1.5 * sub)
    whoosh = swept_noise(n, r, 700.0 + 6500.0 * np.exp(-tp / 0.35), 3500.0) * ad(tt, 0.012, 0.38)
    whoosh += 0.5 * bandnoise(n, r, 150.0, 2500.0) * ad(tt, 0.03, 0.5)
    fs = (2300.0 - 1500.0 * np.exp(-tp / 0.10)) * on
    p1, p2 = phase_of(fs), phase_of((fs * 1.004 + 9.0) * on)
    scream = (np.sin(p1) + 0.5 * np.sin(2 * p1) + 0.8 * np.sin(p2) + 0.3 * np.sin(2 * p2))
    scream = scream * ad(tt, 0.03, 0.42) * (1.0 + 0.2 * np.sin(TAU * 31.0 * t))
    x = x + 1.0 * click + 0.8 * snap + 0.9 * body + 1.0 * sub + 0.6 * whoosh + 0.3 * scream
    x = np.tanh(1.5 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.32, mix=0.18)
    return finalize_oneshot(x), dict(crack_at_s=tc)


def boost_release(seed=111):
    """Boost end: vent 'pssh', falling swept hiss, spool-down tone, then flutter."""
    r = np.random.default_rng(seed)
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    vent = bandnoise(n, r, 2500.0, 11000.0) * ad(t, 0.004, 0.20)
    vent += 0.7 * swept_noise(n, r, 1500.0 + 3500.0 * np.exp(-t / 0.18), 2200.0) * ad(t, 0.006, 0.26)
    ph = phase_of(500.0 + 1400.0 * np.exp(-t / 0.22))
    spool = (np.sin(ph) + 0.4 * np.sin(2 * ph)) * ad(t, 0.01, 0.30)
    x = vent + 0.18 * spool + 0.9 * flutter_chuffs(n, r, 0.13, 6, 20.0, 12.0, 0.78)
    x = np.tanh(1.3 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.16, mix=0.12)
    return finalize_oneshot(x), {}


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


def impact(seed, seconds, w, peak_db):
    """Hull hit; w = weight 0 (light) .. 1 (severe).
    click + pitched thud + low noise body + inharmonic plate ring (beating
    doublets) + scattered debris grains; heavier hits add crunch and a bounce."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    click = ffilt_padded(r.standard_normal(n) * ad(t, 0.0001, 0.001 + 0.002 * w),
                         lambda f: hp(f, 1500.0, 2))
    f0 = 150.0 - 80.0 * w
    thud = np.sin(phase_of(f0 * (1.0 + 1.2 * np.exp(-t / 0.018)))) * ad(t, 0.0008, 0.035 + 0.16 * w)
    lown = bandnoise(n, r, 60.0, 900.0 - 400.0 * w) * ad(t, 0.001, 0.03 + 0.09 * w)
    low = thud * (0.6 + 0.6 * w) + 0.6 * lown
    if w >= 0.6:  # second, softer bounce
        d = int((0.07 + 0.08 * w) * SR)
        low = low + 0.45 * np.concatenate([np.zeros(d), low])[:n]

    base = 1150.0 - 700.0 * w
    ring = np.zeros(n)
    for i, ratio in enumerate([1.0, 1.59, 2.14, 2.65, 3.16, 3.9, 4.6, 5.4]):
        fi = base * ratio
        a = r.uniform(0.6, 1.0) / (1.0 + i) ** 0.7
        dec = (0.05 + 0.30 * w) / (1.0 + 0.4 * i)
        ring += a * np.exp(-t / dec) * (np.sin(TAU * fi * t + r.uniform(0, TAU))
                                        + 0.7 * np.sin(TAU * fi * 1.007 * t + r.uniform(0, TAU)))
    ring *= 1.0 - np.exp(-t / 0.0006)

    debris = np.zeros(n)
    m = int(0.05 * SR)
    ts = np.arange(m) / SR
    for when in 0.004 + r.exponential(0.04 + 0.22 * w, int(6 + 50 * w)):
        i0 = int(when * SR)
        if i0 + m >= n:
            continue
        grain = swept_noise(m, r, r.uniform(1500.0, 8000.0), 1500.0) * ad(ts, 0.0003, r.uniform(0.002, 0.012))
        debris[i0:i0 + m] += grain * r.uniform(0.3, 1.0) * np.exp(-when / (0.08 + 0.35 * w))
    crunch = np.tanh(4.0 * bandnoise(n, r, 200.0, 3000.0) * ad(t, 0.002, 0.05 + 0.12 * w))

    x = (0.7 * click + low + 0.6 * ring / np.abs(ring).max()
         + (0.3 + 0.3 * w) * debris / (np.abs(debris).max() + 1e-9) + 0.5 * w * crunch)
    x = np.tanh((1.0 + 1.5 * w) * 1.2 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.08 + 0.25 * w, mix=0.15 + 0.10 * w)
    return finalize_oneshot(x, peak_db=peak_db), dict(weight=w, ring_base_hz=base, thud_hz=f0)


def land_thump(seed=181):
    """Hover bottoming out: saturated sub thump + jet compression hiss whose
    centre shoots up then relaxes."""
    r = np.random.default_rng(seed)
    n = int(0.75 * SR)
    t = np.arange(n) / SR
    sub = np.tanh(2.0 * np.sin(phase_of(40.0 + 45.0 * np.exp(-t / 0.05))) * ad(t, 0.003, 0.11))
    body = bandnoise(n, r, 50.0, 300.0) * ad(t, 0.002, 0.05)
    fc = 1200.0 + 3800.0 * (1.0 - np.exp(-t / 0.02)) * np.exp(-t / 0.18)
    hiss = swept_noise(n, r, fc, 2500.0) * ad(t, 0.02, 0.14)
    click = r.standard_normal(n) * ad(t, 0.0002, 0.0015)
    x = sub + 0.5 * body + 0.45 * hiss + 0.25 * click
    x = np.tanh(1.3 * x / np.abs(x).max())
    x = reverb(x, r, decay=0.10, mix=0.12)
    return finalize_oneshot(x), {}


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
    return dict(jump_over_rms=round(jump / rms(x), 5),
                jump_over_median_step=round(jump / (float(np.median(d)) + 1e-12), 3),
                jump_over_max_step=round(jump / float(d.max()), 4),
                flux_seam_over_median=round(float(seam / np.median(other)), 3),
                flux_seam_over_p99=round(float(seam / np.percentile(other, 99)), 3),
                flux_seam_over_max=round(float(seam / other.max()), 3))


def spectral_peak_hz(x, lo=20.0):
    mag = np.abs(np.fft.rfft(x))
    k0 = int(np.ceil(lo * len(x) / SR))
    return (k0 + int(np.argmax(mag[k0:]))) * SR / len(x)


def oneshot_metrics(x):
    above = np.flatnonzero(np.abs(x) > amp(-60.0))
    lead = above[0] / SR * 1000.0 if above.size else float("inf")
    tail = np.abs(x[-int(0.010 * SR):]).max()
    return dict(leading_silence_ms=round(float(lead), 3), tail_last10ms_dbfs=round(to_db(tail), 1))


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
    ("supercharger_whine", "loop", "scifi", supercharger_whine_loop),
    ("stabiliser_strain", "loop", "scifi", stabiliser_strain_loop),
    ("drift_charge", "loop", "scifi", drift_charge_loop),
    ("wind_rush", "loop", "scifi", wind_rush_loop),
    ("scrape_loop", "loop", "scifi", scrape_loop),
    ("boost_ignite", "oneshot", "boost", boost_ignite),
    ("boost_release", "oneshot", "boost", boost_release),
    ("turbo_flutter", "oneshot", "boost", turbo_flutter),
    ("drift_release", "oneshot", "boost", drift_release),
    ("impact_light", "oneshot", "impact", lambda: impact(141, 0.32, 0.0, -8.0)),
    ("impact_medium", "oneshot", "impact", lambda: impact(151, 0.55, 0.33, -6.0)),
    ("impact_heavy", "oneshot", "impact", lambda: impact(161, 0.95, 0.67, -4.0)),
    ("impact_severe", "oneshot", "impact", lambda: impact(171, 1.45, 1.0, -3.2)),
    ("land_thump", "oneshot", "impact", land_thump),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = []
    for name, kind, family, build in SOUNDS:
        x, meta = build()
        q = write_wav(os.path.join(OUT, name + ".wav"), x)
        entry = dict(name=name + ".wav", kind=kind, family=family,
                     seconds=round(len(q) / SR, 5), samples=len(q), sample_rate=SR,
                     channels=1, bits=16)
        entry.update(level_metrics(q))
        entry.update(meta)
        if kind == "loop":
            entry["seam"] = seam_metrics(q)
            if family == "engine":
                entry["measured_peak_hz"] = round(spectral_peak_hz(q), 4)
        else:
            entry.update(oneshot_metrics(q))
        manifest.append(entry)
        print("%-24s %-7s %6.3fs peak %6.2f rms %6.2f" % (
            name, kind, entry["seconds"], entry["peak_dbfs"], entry["rms_dbfs"]))
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(dict(generator="scripts/hover_feel/synth/make_sounds.py", category="exotic",
                       files=manifest), fh, indent=2)
    print("wrote %d files to %s" % (len(manifest), OUT))


if __name__ == "__main__":
    sys.exit(main())
