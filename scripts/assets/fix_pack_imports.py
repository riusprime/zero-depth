"""v0.10.0 VX0: makes the Binbun VFX pack (assets/BinbunVFX) import the same on every machine and load without
warnings. Run it after installing or re-installing a pack, then `godot --headless --path . --editor --import --quit`:

    python scripts/assets/fix_pack_imports.py

1. Textures the vendor saved VRAM-compressed (compress/mode=2, an s3tc file only a GPU import can write) become
   lossless (mode 0, a plain .ctex), so the headless import (CI, the tests) writes what the game loads. The uid in the
   .import file stays, so nothing that refers to it breaks.
2. A `[sub_resource type="CompressedTexture2D"]` with a `load_path` into the vendor's own .godot cache (three
   materials) becomes a normal reference to the texture's source file.
3. An `ext_resource` whose uid does not match its target's (the packs share a `shared/` folder but ship different
   .import uids for the same texture) gets the target's uid.
"""

import os
import re
import sys

ROOT = "assets/BinbunVFX"
EXT = re.compile(r'(\[ext_resource [^\]]*?uid=")(uid://[^"]+)("[^\]]*?path="(res://[^"]+)")')


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def uid_of(res_path):
    """The uid the engine will give res://path: from its .import, its .uid, or its own header."""
    p = res_path[len("res://"):]
    if os.path.exists(p + ".import"):
        m = re.search(r'^uid="(uid://[^"]+)"', read(p + ".import"), re.M)
        return m.group(1) if m else None
    if os.path.exists(p + ".uid"):
        return read(p + ".uid").strip()
    if p.endswith((".tres", ".tscn")) and os.path.exists(p):
        m = re.match(r'\[gd_(?:resource|scene)[^\]]*uid="(uid://[^"]+)"', read(p))
        return m.group(1) if m else None
    return None


def normalize_import(path):
    text = read(path)
    if "compress/mode=2" not in text and "detect_3d/compress_to=1" not in text:
        return False
    src = re.search(r'^source_file="(res://[^"]+)"', text, re.M).group(1)
    cache = re.search(r'path(?:\.s3tc)?="(res://\.godot/imported/[^"]+?)(?:\.s3tc)?\.ctex"', text).group(1)
    ctex = cache + ".ctex"
    head = (
        '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n'
        + re.search(r'^uid="[^"]+"\n', text, re.M).group(0)
        + 'path="%s"\nmetadata={\n"vram_texture": false\n}\n\n' % ctex
        + '[deps]\n\nsource_file="%s"\ndest_files=["%s"]\n\n' % (src, ctex)
    )
    params = text[text.index("[params]"):]
    params = params.replace("compress/mode=2", "compress/mode=0").replace(
        "detect_3d/compress_to=1", "detect_3d/compress_to=0"
    )
    write(path, head + params)
    return True


def fix_load_paths(path):
    text = read(path)
    if "load_path" not in text:
        return False
    for m in list(re.finditer(r'\[sub_resource type="CompressedTexture2D" id="([^"]+)"\]\nload_path = "([^"]+)"\n\n?', text)):
        sid, cache = m.group(1), m.group(2)
        name = os.path.basename(cache).split(".png-")[0] + ".png"
        src = None
        for dp, _, files in os.walk(ROOT):
            if name in files:
                src = "res://" + os.path.join(dp, name).replace("\\", "/")
                break
        uid = uid_of(src)
        text = text.replace(m.group(0), "")
        text = text.replace('SubResource("%s")' % sid, 'ExtResource("%s")' % sid)
        last = list(re.finditer(r"\[ext_resource [^\n]*\n", text))[-1]
        line = '[ext_resource type="Texture2D" uid="%s" path="%s" id="%s"]\n' % (uid, src, sid)
        text = text[: last.end()] + line + text[last.end():]
    write(path, text)
    return True


def fix_uids(path):
    text = read(path)
    changed = [0]

    def sub(m):
        want = uid_of(m.group(4))
        if want and want != m.group(2):
            changed[0] += 1
            return m.group(1) + want + m.group(3)
        return m.group(0)

    out = EXT.sub(sub, text)
    if changed[0]:
        write(path, out)
    return changed[0]


def main():
    imports = loads = uids = 0
    files = []
    for dp, _, names in os.walk(ROOT):
        for n in names:
            files.append(os.path.join(dp, n))
    for p in files:
        if p.endswith(".import") and normalize_import(p):
            imports += 1
    for p in files:
        if p.endswith(".tres") and fix_load_paths(p):
            loads += 1
    for p in files:
        if p.endswith((".tres", ".tscn")):
            uids += fix_uids(p)
    print("imports made lossless:", imports, "| load_paths fixed:", loads, "| uids corrected:", uids)
    return 0


if __name__ == "__main__":
    sys.exit(main())
