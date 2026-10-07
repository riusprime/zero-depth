# DAMAGE_LAG: why did the game lag (and sometimes crash) when the player took damage? (PLAN L11)

- **Status:** RUN for the lag (reproduced, root-caused, fixed, re-measured). The crash: **not reproduced** (see
  "Not reproduced"). The owner's Windows hardware: **OWNER ONLY**.
- **Build:** before = `1a02ecb` (a clean `git archive` of it, imported separately); after = the working tree of the
  `v0.2.0 H` commit on branch `worktree-agent-a067ad9c486c42bfc` (measured before committing; `src/` identical to
  the commit except one reworded comment in `hit_feel.gd`). Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux
  6.18.44-fc-v77 x86_64`, 4 cores shared with other agents' jobs; renderer for the rendered runs: Vulkan 1.4.318
  Forward+ on **llvmpipe** (software, Xvfb). Absolute times are therefore far slower than a real GPU; only the
  before/after and hit/no-hit ratios mean anything.
- **Date:** 2026-10-07
- **Who ran it:** agent

## Owner's report
"when receiving dmg the game sometime lags and even crash" (Windows build, PLAYTEST_FLOOR, PLAN L11).

## What runs when the player is hit
`Damage._apply` (sim): HP, DAMAGE event, `invuln = hurt_iframe_ticks`, `add_freeze(hurt_freeze_ticks)` (capped).
Next `WorldViewRoot.sync`: `HitFeel` reads DAMAGE → `ActorViews.flash(player)` and `IsoRig.shake`. `Hud.sync`
(bar, text). On KILL of an enemy: a shard burst. On death: the end panel after 45 ticks, Restart rebuilds the stage.

## Root cause
**The hit flash swapped the hurt actor's shader on every hit.** `ActorViews._set_flash` set
`emission_enabled = true` on the actor's body materials for 3 frames, then back to `false`. `emission_enabled` is
a *feature* of `StandardMaterial3D`: it selects a different generated shader. Godot keeps one shader per feature
combination and frees it when no material uses it any more, so every flash on/off compiled a shader variant (and
its stencil-outline pass) on the main thread, mid-frame. The wanderer is hit hardest: its hood (cull disabled)
and poncho (vertex colour) materials share their feature set with nothing else, so their "emission on" variants
never stay alive between hits; each hit re-compiled them. Shader compilation cost depends on the driver (a real GPU is much faster than llvmpipe, but a
compile per hit still stalls a frame), so this is the likely source of the "lag" there. Whether it is
also the crash is **not proven** (see below).

Secondary, same mechanism: every projectile got a **fresh** material (unshaded + emission, a feature set no
persistent node uses), so when the last shot of a look was freed its shader went with it and the next shot
compiled it again; enemy shots are what hit the player.

Ruled out by measurement or reading: the event log (`events_since` scans ≤ 112 events in these runs; the log is
capped), node or object growth (flat across deaths, 0 orphans), script/engine errors (none in any run), the
hit-stop (sim-side, by design, ≤ `FREEZE_CAP_TICKS`), CPU cost of the damage path (headless frames right after a
hit are no slower than others).

## Reproduction and measurements

### 1. Micro-probe: toggling `emission_enabled` vs changing only the energy (rendered)
Six outlined boxes; every 20 frames all six flash on or off. Scratch harness (not committed):
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 640x360 -s <scratch>/flash_probe.gd -- mode=toggle
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 640x360 -s <scratch>/flash_probe.gd -- mode=energy
```
```
mode=toggle toggle frames: n=30 median=844.2ms max=1670.8ms | other frames: n=569 median=19.4ms max=119.4ms
mode=energy toggle frames: n=30 median=13.4ms max=27.7ms | other frames: n=569 median=12.8ms max=63.6ms
```
Every toggle (not just the first) stalls: the variant is freed and rebuilt each time.

A projectile-like node with a fresh unshaded+emission material, spawned every 20 frames and freed 3 frames later,
vs one reused material (scratch `respawn_probe.gd`, same command shape, `mode=fresh` / `mode=cached`):
```
mode=fresh spawn frames: n=30 median=105.1ms max=223.5ms | other frames: n=569 median=23.0ms max=202.2ms
mode=cached spawn frames: n=30 median=24.3ms max=257.8ms | other frames: n=569 median=20.0ms max=99.2ms
```

### 2. The real game: hits on the wanderer, before and after (rendered)
`scripts/checks/damage_probe.gd` (committed, so it can be run on the owner's machine): boots `main.tscn`, Enter
twice to the floor, stands still, and every 30 frames lands one hit on the player through `Damage.hit` (the call
an enemy attack makes), topping HP up so it never dies. Before (in the clean `1a02ecb` copy, with the same probe
file) then after, back to back:
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 640x360 -s scripts/checks/damage_probe.gd -- hits=20 period=30 target=player
```
Before (`1a02ecb`):
```
target=player hits=20 period=30
  frame +1 after the hit: n=20 mean=260.8ms p50=227.9ms max=941.7ms
  frame +2 after the hit: n=20 mean=1220.9ms p50=1248.7ms max=2043.5ms
  frame +3 after the hit: n=20 mean=204.0ms p50=186.1ms max=357.6ms
  frame +4 after the hit: n=20 mean=1039.5ms p50=1004.3ms max=1628.3ms
  frames >10 after a hit: n=400 mean=231.4ms p50=178.2ms max=1723.1ms
  nodes=1424 orphans=0 objects=4433
```
After (fix):
```
target=player hits=20 period=30
  frame +1 after the hit: n=20 mean=201.0ms p50=223.6ms max=333.9ms
  frame +2 after the hit: n=20 mean=241.0ms p50=226.1ms max=519.7ms
  frame +3 after the hit: n=20 mean=195.8ms p50=198.7ms max=337.9ms
  frame +4 after the hit: n=20 mean=192.6ms p50=185.5ms max=331.4ms
  frames >10 after a hit: n=400 mean=210.2ms p50=199.1ms max=883.8ms
  nodes=1424 orphans=0 objects=4433
```
Frame +2 is the frame the flash turns on, +4 the frame it turns off. Before: those frames are ~7x and ~5.6x a
quiet frame (p50 1248.7 / 1004.3 ms vs 178.2 ms). After: within the noise of a quiet frame (p50 226.1 / 185.5 ms
vs 199.1 ms). An earlier before-run at 960x540 (25 hits, heavier machine load) showed the same pattern: +2 p50
1959.1 ms, +4 p50 1483.5 ms, quiet p50 392.2 ms.

### 3. Soak: real input, take hits, die, restart (headless)
Scratch harness `soak.gd`: boots `main.tscn`, Enter twice, walks a square with W/A/S/D key events so enemies reach
the player, waits for the end panel, presses Enter (Restart), repeats; prints Performance monitors.
```
godot --headless --path . --audio-driver Dummy -s <scratch>/soak.gd -- deaths=3 max_frames=30000 report=3000
```
Before (`1a02ecb`, `deaths=3 max_frames=12000`; it reached 1 death in 12000 frames):
```
[frame 1200] t=8.9s nodes=1382 orphans=0 objects=4227 resources=102 events_log=13 hits=0 fps=136
[death 1] t=43.7s nodes=1426 orphans=0 objects=4385 resources=102 events_log=53 hits=7 fps=142
[frame 7200] t=51.6s nodes=1384 orphans=0 objects=4241 resources=102 events_log=17 hits=8 fps=143
[end] t=85.7s nodes=1428 orphans=0 objects=4388 resources=102 events_log=53 hits=12 fps=141
frames=11999 deaths=1 hits=12
all:  n=11999 mean=7.14ms p50=6.88ms p95=8.71ms p99=25.27ms max=264.04ms
near player hits (-3..+3 frames): n=84 mean=7.02ms p50=6.89ms p95=9.93ms p99=35.35ms max=35.35ms
elsewhere: n=11915 mean=7.14ms p50=6.88ms p95=8.67ms p99=25.16ms max=264.04ms
worst 10 [us, frame, hit-frame]: [[264042, 6140, false], [261636, 14, false], [59570, 4793, false], ...]
```
After (fix):
```
[frame 3000] t=21.7s nodes=1394 orphans=0 objects=4272 resources=102 events_log=25 hits=1 fps=142
[death 1] t=72.7s nodes=1453 orphans=0 objects=4499 resources=102 events_log=99 hits=8 fps=136
[frame 12000] t=86.7s nodes=1396 orphans=0 objects=4279 resources=102 events_log=22 hits=9 fps=138
[death 2] t=152.4s nodes=1454 orphans=0 objects=4513 resources=102 events_log=110 hits=16 fps=140
[frame 24000] t=173.5s nodes=1406 orphans=0 objects=4287 resources=102 events_log=15 hits=18 fps=141
[death 3] t=200.9s nodes=1425 orphans=0 objects=4366 resources=102 events_log=36 hits=21 fps=139
frames=27851 deaths=3 player_hits=21
all frames: n=27851 mean=7.22ms p50=6.88ms p95=10.38ms p99=29.25ms max=277.09ms
0..2 frames after a player hit: n=63 mean=5.22ms p50=6.20ms p95=7.77ms p99=9.77ms max=9.77ms
no hit in the last 3 frames: n=27788 mean=7.22ms p50=6.88ms p95=10.41ms p99=29.26ms max=277.09ms
worst 12 [us, frame, player-hit, enemy-hit]: [[277093, 10142, false, false], [248642, 21096, false, false], [239734, 14, false, false], ...]
```
`grep -ciE "error"` on both logs: `0`. Nodes return to ~1390-1450 after every restart; orphans stay 0. Headless
does not compile shaders, which is why the damage frames are not slow here in either build: the cost is in the
renderer, not in the damage code.

A rendered (llvmpipe) version of this soak on `1a02ecb` ran 2100 frames (1 death, 11 hits, 0 errors) at 1-6 fps
and was stopped before its summary; it is not used as evidence.

## The fix
- `ActorViews`: body materials are built **flashable**: `emission_enabled = true`, energy 0 (no visible change).
  `_set_flash` (hit flash, burn tint) now changes only `emission` and `emission_energy_multiplier`, never a
  feature, so no shader is compiled or freed during play.
- `PlayerAvatar._mesh_piece`: the wanderer's body materials are flashable too.
- `ActorViews._make_projectile`: one material per bolt look, kept for the view's life (no compile on the next shot).
- `HitFeel._burst`: one shard material per colour, kept (no allocation per kill).

Not changed (outside the damage path, owned by workstream K): `ItemVisuals._unshaded` makes a fresh unshaded +
alpha + no-cull material per effect (Twin Arc echo, Overcharge ring, Kinetic Dash afterimages); no persistent node
shares that feature set, so the first effect after a quiet spell compiles its shader (the `respawn_probe` pattern).
Its alpha fade is per effect, so a fix there is a kept "template" material holding the shader alive.

### Does "emission on at energy 0" change the look?
`scripts/shots/outlines.gd -- style=ink` (the same input-driven moment, tick 260) rendered in both builds at
1600x900 and diffed with Pillow (`ImageChops.difference`, channel threshold 8):
```
size (1600, 900) (1600, 900) bbox (327, 0, 1357, 345)
pixels differing >8: 412 of 1440000 max 159
```
The 412 pixels are the two spinning pedestal gems and an enemy at the top edge, both animated in frame time,
which differs between any two llvmpipe runs; the wanderer, the walls and the floor are identical.

## Regression tests
- `tests/unit/presentation/test_damage_flash.gd` (4 tests): a hit on the wanderer flashes (energy > 1) without
  changing any material's shader key (features, flags, modes) during or after the flash; an enemy flash and a
  burn tint change no shader; shots share one kept material per look across expiry; kill bursts share their
  material. On `1a02ecb` all 4 fail (shader keys differ; the burst test sees 2 materials; the projectile test has
  no accessor).
- `tests/e2e/test_e2e_damage_soak.gd`: real input only (left stick into the nearest enemy, Enter on the end panel):
  2 deaths and restarts; on every hit the wanderer's shader keys are unchanged; no engine/script error (GUT error
  tracker); 0 orphan nodes; node count back within 10% of the first fight's. Its output in the suite run:
  `soak: 2 deaths, 10 hits, 9290 frames; nodes 1441 -> 1440`. On `1a02ecb` it fails:
  `[10] expected to equal [0]:  no hit swapped a shader on the wanderer`.
- A frame-time budget assertion is **not** in the suite: the stall is shader compilation, which headless runs
  never do, and llvmpipe timings on a shared CI box are too noisy for a fixed budget. The structural assertion
  (no shader swap) is what catches the cause; `scripts/checks/damage_probe.gd` measures the frame times by hand.

## Not reproduced
- **The crash.** Tried: 3 deaths/restarts with 21 hits headless (real input), 2 deaths/10 hits in the e2e, 20-25
  forced hits on the wanderer rendered (twice), 2100 rendered frames of real play with 11 hits; no crash, no
  `ERROR`/`SCRIPT ERROR` line, no orphan or node growth. All on Linux/llvmpipe Vulkan; the owner's build runs on
  Windows (D3D12 or Vulkan there; neither tried here). A plausible link is a GPU driver failing under
  repeated shader/pipeline creation, which this fix removes from the hit path, but that is a hypothesis, not a
  result.
- **Owner hardware check:** OWNER ONLY. On the Windows machine: does taking damage still hitch or crash? Optional
  numbers: `godot --path . -s scripts/checks/damage_probe.gd -- hits=20 period=30 target=player` from a checkout.

## Other observation (not the damage path)
Restart (and boot) costs one ~240-280 ms frame headless (`worst` lists above: frames 6140, 10142, 21096 are the
frame after Enter on the end panel). It is the stage rebuild (`Main.start_stage`), happens behind the end panel,
and is the same before and after. Not changed here.
