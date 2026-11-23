# Step 69: zd_avatar.cpp split by responsibility

Base `915fb4b8`, branch `v0120-s69`, the owner's PC (i7-10700K), no other agent running.

## What moved
`native/src/zd_avatar.cpp` was 1,079 lines (over the 1,000-line cap). Split:
- `native/src/zd_avatar.cpp` (820 lines): AvatarBase's shared code (the engine's sine and cosine, the hold, flinch,
  strike and tell clocks, the Basis builders, the row's transforms, `process`) and the avatars of the horde kinds and
  the Chargers. Their per-class bodies that sat inside the dispatch (`apply`'s Charger and horde branches, `drives`'
  Charger and horde branches) became `c_apply`, `h_apply`, `c_drives`, `h_drives`, beside `h_advance` and `c_advance`
  (now out of the anonymous namespace), all declared in `zd_avatar.h`.
- `native/src/zd_avatar_dispatch.cpp` (308 lines, new): the per-class dispatch, `advance`, `apply`, `glow_energy`,
  `body_offset`, `drives`, and `flinch_pivot`.

Same statements, same order, same float widths: code moved into functions only. The build flags keep contraction
off (`/fp:precise`, no `/arch:AVX*`; gcc `-ffp-contract=off`), so a call across files gives the same bits.
`native/SConstruct` builds `Glob("src/*.cpp")`: the build made `zd_avatar_dispatch.windows.template_debug.x86_64.obj`.

## Build
```
export PATH="/c/Users/extri/AppData/Local/Python/pythoncore-3.14-64/Scripts:/c/Users/extri/AppData/Local/Python/pythoncore-3.14-64:$PATH"
GODOT="$GODOT" bash scripts/native/ensure.sh
exit=0
```

## Tests (one Godot process; Godot processes before: 0, after: 0)
```
"$GODOT" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/native,res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
Totals
------
Scripts              23
Tests                62
Passing Tests        62
Asserts           30137
Time              89.899s

---- All tests passed! ----
exit=0
```
Scripts: the 18 in `tests/unit/native/` (`test_native_crowd.gd` and the 12 `test_native_crowd_<kind>.gd` files there,
plus ai, geom, nav, shots, strike), the 3 in `tests/arch/`, the 2 in `tests/golden/`.

`tests/golden/fixtures/native_kernels_hash.txt`: `git diff --quiet 915fb4b8 -- tests/golden/fixtures/native_kernels_hash.txt` gives no difference.

No GDScript touched (no lint needed). No twin probe, no timing, no e2e (the lead's next).
