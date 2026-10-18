"""v0.8.0 Step BD (owner O83): prepares the owner's two boss door sounds (unprocessed_images/audio_v080/
door_opening.wav and door_impact.wav: 24-bit stereo 96 kHz) in the project's sound format (assets/audio/manifest.json:
wav mono 44100 Hz 16-bit; the world's sounds are positional mono): the two channels averaged, resampled to 44.1 kHz
(polyphase), the leading and trailing silence trimmed (under SILENCE_DBFS, with PAD_S kept), a FADE_S fade-out at
the end, and the peak brought down to PEAK_DBFS only if it is over it (never raised). The raw files stay untouched.

It prints, per sound, the raw and prepared length, the peak and RMS (dBFS) and the sha256 (paste them into
assets/audio/manifest.json and the evidence by hand).

Run from the repo root:  python3 -I scripts/audio/bd_audio_prep.py
Needs: numpy, scipy (offline tool, not shipped).
"""

import hashlib
import json
import os
import sys
import wave

import numpy as np
from scipy.signal import resample_poly

SRC = "unprocessed_images/audio_v080"
OUT = "assets/audio/sfx"
## raw file -> the cue id it is installed as.
SOUNDS = {"door_opening": "boss_door_opening", "door_impact": "boss_door_impact"}
RATE = 44100
SILENCE_DBFS = -54.0
PAD_S = 0.02
FADE_S = 0.15
## A sound cut at MAX_S fades over its last FADE_CUT_S instead (the impact's rumble decays into the cut).
FADE_CUT_S = 0.9
PEAK_DBFS = -1.0
## The longest a sound effect runs (tests/content/test_audio_assets.gd: an sfx is 0.05-3.0 s): a longer tail is cut
## there and faded over FADE_CUT_S (the owner's impact rings for about 5.5 s down to the silence floor).
MAX_S = 2.95


def read(path):
    w = wave.open(path)
    ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    raw = w.readframes(n)
    w.close()
    assert width == 3, "24-bit expected"
    b = np.frombuffer(raw, np.uint8).reshape(-1, 3)
    v = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
    v = np.where(v >= 1 << 23, v - (1 << 24), v).astype(np.float64) / float(1 << 23)
    return v.reshape(-1, ch), rate


def dbfs(x):
    return 20.0 * np.log10(max(x, 1e-12))


def prepare(name, out_id):
    src = os.path.join(SRC, name + ".wav")
    x, rate = read(src)
    raw_s = len(x) / rate
    mono = x.mean(1)
    g = np.gcd(RATE, rate)
    y = resample_poly(mono, RATE // g, rate // g)
    # Trim: the first and last samples over the silence floor (a 10 ms window's peak), PAD_S kept round them.
    win = int(RATE * 0.01)
    env = np.array([np.abs(y[k : k + win]).max() for k in range(0, len(y), win)])
    loud = np.where(env > 10 ** (SILENCE_DBFS / 20.0))[0]
    start = max(0, loud[0] * win - int(PAD_S * RATE))
    end = min(len(y), (loud[-1] + 1) * win + int(PAD_S * RATE))
    cut = False
    if (end - start) / RATE > MAX_S:
        end = start + int(MAX_S * RATE)
        cut = True
    y = y[start:end].copy()
    fade = min(int((FADE_CUT_S if cut else FADE_S) * RATE), len(y))
    y[-fade:] *= np.linspace(1.0, 0.0, fade) ** 2
    peak = np.abs(y).max()
    gain = min(1.0, 10 ** (PEAK_DBFS / 20.0) / peak)
    y *= gain
    pcm = np.clip(np.round(y * 32767.0), -32768, 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    dst = os.path.join(OUT, out_id + ".wav")
    w = wave.open(dst, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(pcm.tobytes())
    w.close()
    yy = pcm.astype(np.float64) / 32768.0
    return {
        "id": out_id, "raw": src, "raw_seconds": round(raw_s, 3), "trimmed_from_s": round(start / RATE, 3),
        "cut_at_max": cut, "seconds": round(len(pcm) / RATE, 2), "gain_db": round(dbfs(gain), 2),
        "peak_dbfs": round(dbfs(np.abs(yy).max()), 2), "rms_dbfs": round(dbfs(np.sqrt((yy**2).mean())), 2),
        "path": dst, "bytes": os.path.getsize(dst), "sha256": hashlib.sha256(open(dst, "rb").read()).hexdigest(),
    }


def main():
    for name, out_id in SOUNDS.items():
        print(json.dumps(prepare(name, out_id)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
