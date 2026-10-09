# v0.6.0 Step SR — the owner's gamble shrine model (evidence)

The owner uploaded `assets/models/gamble-shrine.glb` (their own art, made with an AI 3D generator like the v0.5.9 kit).
This step installs it the way v0.5.9 installed the kit. Build SHA: the step is `b421e17`, merged with
`claude/lucid-fermat-9wv2tf` (`a541e49`, Step UI + CU) at `75f10e07c972e3e2a39c47504e0ca167260787b8`; the suite, the
export smoke and the screenshot below ran on `75f10e0` (with `tests/MIN_TEST_COUNT` already at 1218, committed with
this file). Godot `4.7.2.stable.official.ed1daf0bf`, Linux cloud container, lavapipe (`llvmpipe`) for the shot.
Presentation only: no sim file changed, so the shrine's spot (`Gamble.spot`), its solid square
(`Gamble.collider`, 1 × 1 m turned 45°) and its 1.8 m reach are what they were.

## What was done
| Piece | Where |
|---|---|
| The raw upload moved to the kit drop folder under its id (`unprocessed_images/kit/gamble_shrine.glb`, `git mv`); the Godot import files of the old path went with it | `unprocessed_images/kit/` |
| `kit_prep.py` prepared it like every kit piece: texture 4096 → 1024 px, brightened (raw mean 0.225 → 0.505), JPEG. New: file names on the command line prepare only those uploads, so the rest of the kit and the ground textures are not rewritten | `scripts/assets/kit_prep.py`, `assets/models/kit/gamble_shrine.glb` (+ its `.import` and extracted texture) |
| Manifest entry (owner's art; sha256 `de311867…0cf0d663`) and a "Set pieces" row in the kit requests | `assets/models/manifest.json`, `docs/art/KIT_REQUESTS.md` |
| `KitModels.SPECS["gamble_shrine"]`: yaw 0 (its front, the slot window, is already glTF +Z; long side already on X), height 1.7 m, role `shrine`. KitModels normalises it like every piece (bottom at y = 0, centred) and gives it generated LODs (`_with_lods`) | `src/presentation/world_view/kit_models.gd` |
| `GambleShrineView`: with the v0.5.9 look (`kit_model`, set by `WorldViewRoot` exactly as `kit_chest` is: when the floor has a lighting mood) the body is the model at its natural size 1.58 × 1.12 × 1.7 m, turned 45° so its front faces the iso camera and its sides line up with the sim's square. A missing file draws the old code-built obelisk (L15) | `src/presentation/world_view/gamble_shrine_view.gd`, `world_view_root.gd` |
| Cues kept: the price floating above (red when you can't pay, hidden far away); the shrine's own light (range 4 m, unshadowed, as before) now sits at the model's crystal and takes the crystal's magenta (`#D46BFF`, the minimap's shrine colour) instead of the old cyan; it brightens ×1.35 in reach; three shards orbit the crystal and spin fast on a use; the whole model flashes on the landing (flashable copy of its material: only energies change, no shader swap) and shakes and turns the light red on a refusal | same file |
| Shot script | `scripts/shots/shrine_model.gd` |

Not touched: the v0.5.9 lighting, dresser, rooms and other kit pieces; the HUD (Step UI); the attack engine (MX).

## Tests
- `tests/content/test_model_manifest.gd` (unchanged): the new file is in the manifest with its hash, and every
  `KitModels.SPECS` id (now including `gamble_shrine`) is delivered.
- `tests/unit/presentation/test_kit_models.gd` (unchanged): the shrine loads into the unit box with its 1.7 m height
  and its textured material, like every spec.
- New `tests/unit/presentation/test_kit_shrine.gd` (4): the view loads the kit's mesh and places it at the sim
  position, standing on the floor, centred; turned like the footprint, which is unchanged, and its half extents cover
  the 0.5 m square and stay under 0.8 m (the old plinth was 0.78 m); the cues on the model (price, light brighter in
  reach, spin, landing flash with no shader change, shake on a refusal); a missing model and the old look draw the
  obelisk.
- `tests/e2e/test_e2e_gamble.gd` (main.tscn, input only) gains two asserts: the real game's shrine uses the model, at
  the sim's shrine position. The rest of the test (walk up, refused use, two wins, pause menu stats) is unchanged.
- `tests/MIN_TEST_COUNT` 1214 → 1218.

## Commands
```
python3 -I scripts/assets/kit_prep.py gamble_shrine.glb
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash /tmp/claude-0/vd.sh <worktree> sr        # import + lint + bash scripts/verify.sh
cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh
XDG_DATA_HOME=<empty folder> xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy \
  --resolution 1920x1080 -s scripts/shots/shrine_model.gd
cp build/shots/v0.6.0/shrine_model/near.png docs/roadmap/v0.6.0/evidence/shrine_model.png   # by hand
```

## Raw output
`kit_prep.py`:
```
de311867124089b3b2e56c6fea0aabfe7e6d3ad7a3d37a7a53c84b590cf0d663    978724  assets/models/kit/gamble_shrine.glb
```

Full suite at `75f10e0` (`/tmp/claude-0/vd_sr.clean.log`; 0 lines with "SCRIPT ERROR" or "Ignoring script"):
```
verify exit 0
Tests              1218
Passing Tests      1218
check_gut_log: ok (1218 passing, minimum 1218)
```
Tail of the log:
```
Scripts             195
Tests              1218
Passing Tests      1218
Asserts           1242312
Time              2064.044s

---- All tests passed! ----
```
An earlier run on the same commit failed 12 e2e tests with `String formatting error` in `pause_menu.gd:34`. The cause
was my own: I had `git restore`d `locale/strings.{en,es}.translation` after an import regenerated them, and the
committed copies on `claude/lucid-fermat-9wv2tf` are older than `strings.csv` (`UI_PAUSE_RUN` takes 5 arguments in the
CSV, fewer in the committed binary). A fresh clone regenerates them on import. After `touch locale/strings.csv` and a
re-import, the run above passed. The regenerated `.translation` files are left unstaged (not this step's change).

Export smoke (from `/tmp`):
```
manifest: 52da1bcc5ac32a0846cd86cb332faae6bde54650fa2f43c65186a5b0544c9878 (246 files, 0 errors)
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash 52da1bcc5ac3 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is Play / Jugar
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
exit 0
```

Screenshot run (renderer, 1920 × 1080):
```
shrine_model: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1920, 1080)
shrine_model: uses_model=true view_pos=(36.755, 0.0, -7.065001) sim_pos=(36.755, 7.065001) price='25'
shrine_model: res://build/shots/v0.6.0/shrine_model/near.png (frame 89, tick 296)
shrine_model: spinning=true
shrine_model: res://build/shots/v0.6.0/shrine_model/spin.png (frame 103, tick 352)
exit 0
```
`view_pos` is `SimPlane.to_3d(sim_pos)`: the model stands at the sim's shrine.
[`shrine_model.png`](shrine_model.png) is `near.png` (sha256 `b1ae6a97…0cc46421`): floor 1, Ruins mood, the hero in
reach, the price in red (no shards), the crystal's magenta light on the floor. `spin.png` (sha256 `83beec76…01552a83`,
after a use with shards granted by the labelled SHOT HELPER) stays in `build/`.
The first attempt "gave up in step boot": a saved run from another build in the shared `user://` turned Enter into
Continue. That run moved the bad save aside as `user://saves/run.bad.2026-10-09T01-44-20.save`. Hence the empty
`XDG_DATA_HOME`.

## Owner
- How the model reads in play, its size (1.7 m, the old obelisk reached 2.2 m) and the magenta light in place of the
  old cyan: **OWNER ONLY**.
