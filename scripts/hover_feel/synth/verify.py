"""Independent numeric check of the generated WAVs (reads the files back).

    py -3 scripts/hover_feel/synth/verify.py

Prints a table, exits non-zero on any failure, and writes a spectrogram
contact sheet PNG (numpy + zlib only) to output/hover_feel_audio/.
"""
import json
import os
import struct
import sys
import wave
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sounds as ms  # noqa: E402

SR = ms.SR


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getframerate() == SR and w.getsampwidth() == 2 and w.getnchannels() == 1, path
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    return raw.astype(np.float64) / 32768.0, raw


# ---- tiny PNG + 3x5 font --------------------------------------------------
FONT = {
    "a": "010101111101101", "b": "110101110101110", "c": "011100100100011", "d": "110101101101110",
    "e": "111100110100111", "f": "111100110100100", "g": "011100101101011", "h": "101101111101101",
    "i": "111010010010111", "j": "001001001101010", "k": "101101110101101", "l": "100100100100111",
    "m": "101111111101101", "n": "110101101101101", "o": "010101101101010", "p": "110101110100100",
    "q": "010101101110011", "r": "110101110101101", "s": "011100010001110", "t": "111010010010010",
    "u": "101101101101111", "v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
    "y": "101101010010010", "z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
    "2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
    "6": "011100110101010", "7": "111001010010010", "8": "111101111101111", "9": "111101111001110",
    "_": "000000000000111", ".": "000000000000010", " ": "000000000000000",
}


def draw_text(img, x, y, text, scale=2):
    for ch in text.lower():
        g = FONT.get(ch, FONT[" "])
        for row in range(5):
            for col in range(3):
                if g[row * 3 + col] == "1":
                    img[y + row * scale:y + (row + 1) * scale,
                        x + col * scale:x + (col + 1) * scale] = 255
        x += 4 * scale


def write_png(path, rgb):
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[r].tobytes() for r in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def spectrogram_tile(x, width=280, height=120, win=2048, wrap=False):
    """Log-frequency (40 Hz..20 kHz) dB spectrogram, 80 dB range."""
    x = np.concatenate([x, x[:win] if wrap else np.zeros(win)])
    starts = np.linspace(0, len(x) - win, width).astype(int)
    mag = np.abs(np.fft.rfft(x[starts[:, None] + np.arange(win)] * np.hanning(win), axis=1))
    freqs = np.fft.rfftfreq(win, 1.0 / SR)
    edges = np.geomspace(40.0, 20000.0, height + 1)
    rows = np.zeros((height, width))
    for i in range(height):
        sel = (freqs >= edges[i]) & (freqs < edges[i + 1])
        if not sel.any():
            sel = np.zeros_like(sel)
            sel[np.argmin(np.abs(freqs - edges[i]))] = True
        rows[height - 1 - i] = mag[:, sel].max(axis=1)
    d = 20.0 * np.log10(rows / (rows.max() + 1e-12) + 1e-9)
    v = np.clip((d + 80.0) / 80.0, 0.0, 1.0)
    stops = np.array([[0, 0, 0], [60, 10, 110], [200, 50, 60], [250, 170, 30], [255, 255, 230]], float)
    pos = v * (len(stops) - 1)
    i0 = np.clip(pos.astype(int), 0, len(stops) - 2)
    fr = (pos - i0)[..., None]
    return (stops[i0] * (1 - fr) + stops[i0 + 1] * fr).astype(np.uint8)


def contact_sheet(items, path, cols=6):
    tw, th, label = 280, 120, 16
    rows = (len(items) + cols - 1) // cols
    sheet = np.zeros((rows * (th + label + 6) + 6, cols * (tw + 6) + 6, 3), np.uint8) + 24
    for i, (name, x, wrap) in enumerate(items):
        ox = 6 + (i % cols) * (tw + 6)
        oy = 6 + (i // cols) * (th + label + 6)
        draw_text(sheet, ox, oy + 2, name)
        sheet[oy + label:oy + label + th, ox:ox + tw] = spectrogram_tile(x, tw, th, wrap=wrap)
    write_png(path, sheet)


RASPY = {"turbine_low", "turbine_high", "energy_hum", "stabiliser_strain", "boost_loop"}
MAX_SECONDS = {"boost_ignite": 2.5, "boost_release": 1.5, "turbo_flutter": 1.0, "drift_release": 0.8,
               "pop": 0.6, "bang": 0.9, "land_thump": 0.8, "impact_light": 1.5, "impact_medium": 1.5,
               "impact_heavy": 1.5, "impact_severe": 1.5}


def main():
    with open(os.path.join(ms.OUT, "manifest.json"), encoding="utf-8") as fh:
        manifest = json.load(fh)["files"]
    fails, items, engine_rms = [], [], []
    print("%-24s %-7s %6s %7s %7s  %s" % ("file", "kind", "sec", "peak", "rms", "checks"))
    for e in manifest:
        x, raw = read_wav(os.path.join(ms.OUT, e["name"]))
        items.append((e["name"][:-4], x, e["kind"] == "loop"))
        lv = ms.level_metrics(x)
        notes = []

        def check(ok, text):
            if not ok:
                fails.append("%s: %s" % (e["name"], text))
                notes.append("FAIL " + text)

        check(lv["peak_dbfs"] <= -3.0, "peak %.2f dBFS" % lv["peak_dbfs"])
        check(abs(lv["dc_offset"]) < 1e-3, "dc %.5f" % lv["dc_offset"])
        check(np.abs(raw).max() < 32767, "clipping")
        check(len(x) / SR < 7.0, "over 7 s")
        if e["kind"] == "loop":
            s = ms.seam_metrics(x)
            notes.append("seam jump/rms %.4f (x%.2f of max step), flux/med %.2f, flux/max %.2f" % (
                s["jump_over_rms"], s["jump_over_max_step"], s["flux_seam_over_median"],
                s["flux_seam_over_max"]))
            check(s["jump_over_max_step"] <= 1.0, "seam step larger than any step inside the loop")
            notes.append("click %+.1f dB vs max" % s["hf_click_seam_over_max_db"])
            # Flux is a statistic of the content; a seam only counts as bad when the
            # broadband click detector agrees or the flux is far outside the loop's range.
            check(s["hf_click_seam_over_max_db"] <= 0.0, "broadband click at the seam")
            check(s["flux_seam_over_max"] <= 1.25, "seam flux far above any flux inside the loop")
            check(2.0 <= len(x) / SR <= 4.0, "loop length")
            if e["name"][:-4] in RASPY:
                hf = ms.hf_ratio_db(x)
                notes.append("energy >9 kHz %.1f dB" % hf)
                check(hf <= -25.0, "fizz above 9 kHz")
            if e["family"] == "engine":
                pk = ms.spectral_peak_hz(x)
                periods = e["nominal_firing_hz"] * len(x) / SR
                notes.append("firing %.3f Hz (target %.3f), %.4f periods" % (pk, e["nominal_firing_hz"], periods))
                check(abs(pk - e["nominal_firing_hz"]) < 1.0, "firing peak off target")
                check(abs(periods - round(periods)) < 1e-3, "non-integer firing periods")
                engine_rms.append(lv["rms_dbfs"])
        else:
            o = ms.oneshot_metrics(x)
            notes.append("lead %.2f ms, tail %.1f dBFS" % (o["leading_silence_ms"], o["tail_last10ms_dbfs"]))
            check(o["leading_silence_ms"] <= 10.0, "leading silence")
            check(o["tail_last10ms_dbfs"] <= -60.0, "tail not silent")
            notes.append("peak at %.1f ms" % o["transient_peak_ms"])
            limit = MAX_SECONDS.get(e["name"][:-4].rstrip("_1234"))
            if limit:
                check(len(x) / SR < limit, "longer than %.1f s" % limit)
            if e["name"] == "boost_ignite.wav":
                check(o["transient_peak_ms"] <= 150.0, "peak later than 150 ms")
        print("%-24s %-7s %6.3f %7.2f %7.2f  %s" % (
            e["name"][:-4], e["kind"], len(x) / SR, lv["peak_dbfs"], lv["rms_dbfs"], "; ".join(notes)))
    # ---- spectral balance vs the round 2 files (baseline_round2.json) ----
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "baseline_round2.json")) as fh:
        base = json.load(fh)
    audio = {name: x for name, x, _ in items}
    print("\nengine energy share %   <250 Hz          250-2000 Hz      >2000 Hz        2-5 kHz change")
    for e in manifest:
        if e["family"] != "engine":
            continue
        n = e["name"][:-4]
        s, o = ms.band_shares(audio[n]), base[n]
        d = 10.0 * np.log10(s["whine_2k_5k"] / o["whine_2k_5k"])
        print("%-16s r2 %5.1f -> %5.1f   r2 %5.1f -> %5.1f   r2 %5.1f -> %5.1f   %+5.1f dB" % (
            n, o["below_250"], s["below_250"], o["mid_250_2000"], s["mid_250_2000"],
            o["above_2000"], s["above_2000"], d))
        if e["mode"] != "idle":
            if not (s["below_250"] > o["below_250"] and -8.0 <= d <= -3.0):
                fails.append("%s: balance target missed (2-5 kHz %+.1f dB)" % (n, d))
    print("\nspectral distance (octave energy cosine / third-octave contour)")
    pairs = [("boost_loop", "v10_on_6500"), ("boost_loop", "turbine_low"), ("boost_loop", "supercharger_whine"),
             ("boost_loop", "thruster_roar"), ("v10_on_6500", "v10_on_5000"), ("v10_on_6500", "v10_on_8000")]
    dist = {p: ms.spectral_distance(audio[p[0]], audio[p[1]]) for p in pairs}
    for p in pairs:
        print("  %-12s vs %-20s %.3f / %.3f" % (p[0], p[1], dist[p], ms.spectral_shape_distance(audio[p[0]], audio[p[1]])))
    if dist[pairs[0]] < 10.0 * max(dist[pairs[4]], dist[pairs[5]]):
        fails.append("boost_loop is not clearly a different family from the engine")
    tb = ms.band_shares(audio["thruster_roar"])
    print("thruster_roar energy below 250 Hz: %.1f %%; boost_loop: %s" % (tb["below_250"], ms.band_shares(audio["boost_loop"])))
    if tb["below_250"] < 90.0:
        fails.append("thruster_roar is not confined to the low end")
    spread = max(engine_rms) - min(engine_rms)
    print("engine loop RMS spread: %.2f dB" % spread)
    if spread > 3.0:
        fails.append("engine RMS spread %.2f dB" % spread)
    sheet = os.path.join(os.path.dirname(ms.OUT), "exotic_contact_sheet.png")
    contact_sheet(items, sheet)
    print("contact sheet:", sheet)
    print("FAILURES:" if fails else "ALL CHECKS PASSED")
    for f in fails:
        print("  " + f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
