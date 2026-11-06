"""v0.10.0 VX0: inlines the `#include` lines of the Binbun VFX pack's shaders (assets/BinbunVFX/**/*.gdshader).

Why: Godot's headless dummy renderer does not run the shader preprocessor, so a shader with `#include` logs
"Tokenizer: Unknown character #35" every time it loads, and GUT fails the test that loaded it. Inlined, a shader loads
the same everywhere and draws the same (an include is textual). Run it again after re-installing a pack:

    python scripts/assets/inline_pack_shader_includes.py

The `.gdshaderinc` files stay where they are (nothing includes them any more); only `.gdshader` files change. A file
with no `#include` is left alone, so a second run changes nothing.
"""

import os
import re
import sys

ROOT = "assets/BinbunVFX"
INCLUDE = re.compile(r'^[ \t]*#include[ \t]+"([^"]+)"[ \t]*\r?$', re.M)


def expand(path, text, seen):
    base = os.path.dirname(path)

    def sub(m):
        inc = os.path.normpath(os.path.join(base, m.group(1)))
        if inc in seen:  # an include already pasted in (the preprocessor pastes each file once as well)
            return ""
        seen.add(inc)
        with open(inc, encoding="utf-8", newline="") as f:
            body = f.read()
        return "// --- inlined from %s ---\n%s\n" % (m.group(1), expand(inc, body, seen))

    return INCLUDE.sub(sub, text)


def main():
    changed = 0
    for dirpath, _, files in os.walk(ROOT):
        for name in files:
            if not name.endswith(".gdshader"):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8", newline="") as f:
                text = f.read()
            if not INCLUDE.search(text):
                continue
            out = expand(path, text, {os.path.normpath(path)})
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(out)
            changed += 1
            print("inlined", path)
    print(changed, "shaders changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
