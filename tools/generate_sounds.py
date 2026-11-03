#!/usr/bin/env python3
"""Generate simple CC0 chess UI sounds (WAV + optional OGG via ffmpeg).

Usage:
  python3 tools/generate_sounds.py
  # writes to assets/sounds/*.wav and *.ogg if ffmpeg is available

License: output is CC0 (public domain). Script itself is also free to use.
"""

import struct
import math
import wave
import os
import subprocess

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def write_wav(path: str, samples: list) -> None:
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
        )
        w.writeframes(frames)


def env_adsr(n, a=0.01, d=0.05, s_level=0.5, r=0.08):
    a_n = max(1, int(a * SR))
    d_n = max(1, int(d * SR))
    r_n = max(1, int(r * SR))
    s_n = max(0, n - a_n - d_n - r_n)
    env = []
    for i in range(n):
        if i < a_n:
            env.append(i / a_n)
        elif i < a_n + d_n:
            t = (i - a_n) / d_n
            env.append(1.0 - t * (1.0 - s_level))
        elif i < a_n + d_n + s_n:
            env.append(s_level)
        else:
            t = (i - a_n - d_n - s_n) / r_n
            env.append(max(0.0, s_level * (1.0 - t)))
    return env


def tone(freq, dur, vol=0.4, a=0.005, d=0.03, s=0.4, r=0.05):
    n = int(dur * SR)
    e = env_adsr(n, a, d, s, r)
    out = []
    for i in range(n):
        t = i / SR
        s1 = math.sin(2 * math.pi * freq * t)
        s2 = 0.3 * math.sin(2 * math.pi * freq * 2 * t)
        out.append((s1 + s2) * e[i] * vol)
    return out


def noise_burst(dur, vol=0.3):
    n = int(dur * SR)
    e = env_adsr(n, 0.001, 0.02, 0.2, 0.05)
    out = []
    x = 1234567
    for i in range(n):
        x = (x * 1103515245 + 12345) & 0x7fffffff
        r = (x / 0x7fffffff) * 2 - 1
        out.append(r * e[i] * vol)
    return out


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return [math.tanh(v) for v in out]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    sounds = {
        "move": mix(
            tone(420, 0.09, 0.35, 0.002, 0.02, 0.2, 0.04),
            tone(840, 0.06, 0.15, 0.001, 0.015, 0.1, 0.03),
        ),
        "capture": mix(
            tone(120, 0.12, 0.5, 0.001, 0.04, 0.3, 0.06),
            tone(60, 0.15, 0.35, 0.001, 0.05, 0.2, 0.07),
            noise_burst(0.08, 0.25),
        ),
        "check": mix(
            tone(880, 0.18, 0.35, 0.005, 0.04, 0.5, 0.08),
            tone(1320, 0.15, 0.2, 0.005, 0.03, 0.4, 0.07),
        ),
        "checkmate": mix(
            tone(660, 0.2, 0.4, 0.01, 0.05, 0.5, 0.1),
            [0.0] * int(0.12 * SR) + tone(440, 0.25, 0.4, 0.01, 0.05, 0.5, 0.12),
            [0.0] * int(0.28 * SR) + tone(220, 0.35, 0.45, 0.01, 0.08, 0.4, 0.15),
        ),
        "select": tone(1200, 0.05, 0.25, 0.001, 0.015, 0.15, 0.025),
        "ui_click": mix(
            tone(1000, 0.04, 0.2, 0.001, 0.01, 0.1, 0.02),
            tone(1500, 0.03, 0.1, 0.001, 0.008, 0.05, 0.015),
        ),
    }

    for name, samples in sounds.items():
        wav_path = os.path.join(OUT_DIR, f"{name}.wav")
        write_wav(wav_path, samples)
        print("Wrote", wav_path)
        ogg_path = os.path.join(OUT_DIR, f"{name}.ogg")
        try:
            subprocess.run(
                ["ffmpeg", "-y", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "4", ogg_path],
                check=True,
                capture_output=True,
            )
            print("Wrote", ogg_path)
        except Exception as e:
            print("OGG skip (install ffmpeg for ogg):", e)


if __name__ == "__main__":
    main()
