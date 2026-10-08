"""Prepares the owner's raw kit uploads (unprocessed_images/kit/) for the game (v0.5.9 Step 3).

- Each .glb keeps its mesh; its embedded texture is downscaled to TEXTURE_PX (the AI generator exports
  4096 px, the kit budget is 1024), brightened so its mean is MODEL_MEAN (the uploads average about 0.3, which
  reads black under the night moods; the biome hue is added in the game), and re-encoded as JPEG. Writes
  assets/models/kit/<id>.glb.
- ground-a.png (4 x 4 stone tiles) is cropped from one grout centre to the one two tiles later, so its edges cut
  grout lines in half and it tiles exactly. ground-b.png (dirt) is made seamless by offset-and-blend. Both are
  then neutralised: each channel scaled so its mean is GROUND_MEAN, which keeps the detail but drops the brown
  cast, so the biome's ground colour tints them (StageView). Writes assets/textures/kit/ground_a.png and
  ground_b.png.

Run from the repo root: python3 -I scripts/assets/kit_prep.py   (needs Pillow and numpy)
Then update assets/models/manifest.json with the new sha256 values (the script prints them).
"""

import hashlib
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

SRC = "unprocessed_images/kit"
OUT_MODELS = "assets/models/kit"
OUT_TEX = "assets/textures/kit"
TEXTURE_PX = 1024
JPEG_QUALITY = 90
MODEL_MEAN = 0.55 * 255
# ground-a: grout-line centres measured on the 1254 px upload (columns and rows: 313, 626.5, 940).
GROUND_A_CROP = (313, 313, 940, 940)
GROUND_PX = 1024
GROUND_MEAN = 0.82 * 255


def neutralise(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(float)
    a = a * (GROUND_MEAN / a.reshape(-1, 3).mean(0))
    return Image.fromarray(np.clip(a, 0, 255).round().astype(np.uint8))


def _pad4(b: bytes, fill: bytes) -> bytes:
    return b + fill * ((4 - len(b) % 4) % 4)


def shrink_glb(src: str, dst: str) -> None:
    data = open(src, "rb").read()
    json_len = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20 : 20 + json_len])
    bin_start = 20 + json_len + 8
    blob = data[bin_start : bin_start + struct.unpack("<I", data[20 + json_len : 24 + json_len])[0]]
    images = {im["bufferView"]: i for i, im in enumerate(gltf.get("images", []))}
    out = bytearray()
    for i, view in enumerate(gltf["bufferViews"]):
        chunk = blob[view.get("byteOffset", 0) : view.get("byteOffset", 0) + view["byteLength"]]
        if i in images:
            img = Image.open(io.BytesIO(chunk)).convert("RGB")
            if max(img.size) > TEXTURE_PX:
                img = img.resize((TEXTURE_PX, TEXTURE_PX), Image.LANCZOS)
            px = np.asarray(img).astype(float)
            px = px * (MODEL_MEAN / max(px.mean(), 1.0))
            img = Image.fromarray(np.clip(px, 0, 255).round().astype(np.uint8))
            buf = io.BytesIO()
            img.save(buf, "JPEG", quality=JPEG_QUALITY)
            chunk = buf.getvalue()
            gltf["images"][images[i]]["mimeType"] = "image/jpeg"
        while len(out) % 4:
            out.append(0)
        view["byteOffset"] = len(out)
        view["byteLength"] = len(chunk)
        out += chunk
    out = _pad4(bytes(out), b"\0")
    gltf["buffers"][0]["byteLength"] = len(out)
    js = _pad4(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(dst, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(out), b"BIN\0") + out)


def seamless_blend(img: np.ndarray) -> np.ndarray:
    """Offset by half, then keep the original in the middle and the offset copy at the edges (a wide feather)."""
    h, w = img.shape[:2]
    rolled = np.roll(np.roll(img, h // 2, axis=0), w // 2, axis=1)
    y = np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h / 2)
    x = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w / 2)
    wy = np.clip((y - 0.15) / 0.5, 0, 1)
    wx = np.clip((x - 0.15) / 0.5, 0, 1)
    m = (np.outer(wy, wx))[..., None]
    m = m * m * (3 - 2 * m)
    return img * m + rolled * (1 - m)


def main() -> int:
    os.makedirs(OUT_MODELS, exist_ok=True)
    os.makedirs(OUT_TEX, exist_ok=True)
    written = []
    for f in sorted(os.listdir(SRC)):
        if f.endswith(".glb"):
            dst = os.path.join(OUT_MODELS, f)
            shrink_glb(os.path.join(SRC, f), dst)
            written.append(dst)
    a = Image.open(os.path.join(SRC, "ground-a.png")).convert("RGB").crop(GROUND_A_CROP)
    a = a.resize((GROUND_PX, GROUND_PX), Image.LANCZOS)
    neutralise(a).save(os.path.join(OUT_TEX, "ground_a.png"))
    b = np.asarray(Image.open(os.path.join(SRC, "ground-b.png")).convert("RGB")).astype(float)
    b = Image.fromarray(seamless_blend(b).round().astype(np.uint8)).resize((GROUND_PX, GROUND_PX), Image.LANCZOS)
    neutralise(b).save(os.path.join(OUT_TEX, "ground_b.png"))
    written += [os.path.join(OUT_TEX, "ground_a.png"), os.path.join(OUT_TEX, "ground_b.png")]
    for p in written:
        print("%s  %8d  %s" % (hashlib.sha256(open(p, "rb").read()).hexdigest(), os.path.getsize(p), p))
    return 0


if __name__ == "__main__":
    sys.exit(main())
