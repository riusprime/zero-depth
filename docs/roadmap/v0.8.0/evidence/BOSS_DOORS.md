# BOSS_DOORS: each biome's boss door, and opening it by a press (v0.8.0 Step BD)

- **Status:** RUN (agent: offline preparation, the tests below, llvmpipe shots under xvfb; not the owner's hardware).
  How it looks, sounds and feels: **OWNER ONLY**.
- **Build:** branch `v080-bd` from lead merge `5ff24af`, with `origin/claude/lucid-fermat-9wv2tf` merged in at
  `2ee84c5` (the door request and raw doors, `cb6a601`) and `73d64a3` (the raw door sounds, `123acce`). The step's
  commit: `9cac95f` (`v0.8.0 Step BD: …`), merged with `origin/claude/lucid-fermat-9wv2tf` at `6f0de2c` (LD, N19) before it. Godot `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 (cloud container, 4 cores, no GPU;
  llvmpipe 20.1.2). The machine was shared with other agents' runs (load average 6-10 on 4 cores): **times are not
  comparable between runs**.
- **Date:** 2026-10-18
- **Who ran it:** agent

Owner (verbatim in [`../PLAN.md`](../PLAN.md), O82 and O83): "Next missing 3D models are doors for each biome, we
should have 5 doors that match each biome for the boss room … they should be similar buyt with small different details
and colors based on the biome"; "your prompt generates the full dor closed, can't you just slice the door like you did
with other assets?"; "Inscrease the size of this just a bit so they get more detail ingame compared to the original
ones like 15-20% bigger"; "add this to the rework of the doors, one is sound of opening and the other one is the impact
when the dor opens completly, opening the door now is a press button (X on controller F on keyboard) and when opened
the sound play".

## 1. Cutting the doors offline
```
python3 -I scripts/assets/bd_prep.py            # the five doors (re-runnable; raw files untouched)
```
Needs what `mi_prep.py` needs (numpy, Pillow, `meshoptimizer==0.2.30a0`, `xatlas==0.0.11`, scipy) and reuses its
reader, simplifier, bake and glb writer. How it cuts, per door:
- **Where the slab is** (`CUTS` in the script): measured by hand from front and back depth renders of each raw file
  (the median depth over bands of rows and columns): the groove round the slab on each side, the groove over its top,
  and the slab's front and back faces. Every door has the groove the request asked for, so the cut goes down its
  middle.
- **The frame** turns into the game's frame (the gap along Z, +X into the boss room, the front toward the approach).
  It is scaled evenly so the slab is **2.6 m tall: the code-made door's 2.2 m × 1.18**. The depth is scaled to 0.65 of
  that (`DEPTH_SHARE`): the raw frames are about twice as deep as the request's 1.0 m, and at full scale they would
  stand 2.8-3.4 m deep in a 1.1 m doorway.
- **The cut:** every triangle that crosses a cut plane is split on it: the opening's two sides, the slab's top, and
  the slab's box (its faces ± 0.03 raw units for the chains and carvings). The pieces sort into four parts:
  - `jamb_n` and `jamb_p`: the frame beyond each side, at every height;
  - `lintel`: the frame over the opening, and in front of the slab's box;
  - `slab`.
- **Simplifying:** each part apart, with its borders locked so the cuts stay on their planes. The budgets are 5,000
  triangles over the frame (the lintel weighted ×2, because it carries the crest) and 1,500 for the slab.
- **Capping:** flat quads over the slab's thickness on the cut planes: the jambs' inner faces and the lintel's
  underside where the slab was, and the slab's top and sides. Nothing looks hollow when the slab is down.
- **Textures:** one xatlas atlas for the four parts, and the raw colour map baked onto it at 1024 px (mi_prep's bake
  and brightening).
- **The socket:** found on each face of the slab, as the disc of cells sunk under the slab's face on a 0.008-unit
  grid. Its height, floor depth and radius go into `BossDoorModels.SPECS`, and the game's seal sits there. All five
  doors had it on both faces.

Raw output (`build/bd_prep_out.txt`; the script prints one line per door):
```
{"id": "boss_door_ruins", "raw_tris": 46307, "raw_bytes": 13030632, "tris": {"jamb_n": 1891, "jamb_p": 1790, "lintel": 1315, "slab": 1496}, "frame_tris": 4996, "tex": 1024, "opening_w": 2.672, "slab_h": 2.6, "slab_x": [-0.098, 0.102], "frame_size_xyz": [1.823, 4.218, 6.533], "height": 4.218, "scale": 6.533, "depth_scale": 4.246, "seal": {"front": {"y": 1.564, "z": -0.052, "x": -0.045, "r": 0.381}, "back": {"y": 1.585, "z": -0.05, "x": 0.053, "r": 0.393}}, "path": "assets/models/doors/boss_door_ruins.glb", "bytes": 1118760, "sha256": "4fe9b31c744965565616afcc82613b3ccc16f48cad04071237b415071570266b"}
{"id": "boss_door_night_rocks", "raw_tris": 46485, "raw_bytes": 12309456, "tris": {"jamb_n": 1660, "jamb_p": 1701, "lintel": 1630, "slab": 1494}, "frame_tris": 4991, "tex": 1024, "opening_w": 2.666, "slab_h": 2.6, "slab_x": [-0.208, 0.216], "frame_size_xyz": [1.955, 4.287, 6.032], "height": 4.287, "scale": 6.032, "depth_scale": 3.921, "seal": {"front": {"y": 1.448, "z": 0.007, "x": -0.075, "r": 0.266}, "back": {"y": 1.418, "z": 0.001, "x": 0.076, "r": 0.283}}, "path": "assets/models/doors/boss_door_night_rocks.glb", "bytes": 1134680, "sha256": "dc39de425e0e74a33d65d8a68e6670e1638822f3711ad7f65b2db8eeb8f33f36"}
{"id": "boss_door_red_canyon", "raw_tris": 48512, "raw_bytes": 11864528, "tris": {"jamb_n": 1769, "jamb_p": 1632, "lintel": 1581, "slab": 1506}, "frame_tris": 4982, "tex": 1024, "opening_w": 2.655, "slab_h": 2.6, "slab_x": [-0.226, 0.124], "frame_size_xyz": [2.309, 4.108, 6.824], "height": 4.108, "scale": 6.824, "depth_scale": 4.436, "seal": {"front": {"y": 1.536, "z": -0.003, "x": -0.14, "r": 0.325}, "back": {"y": 1.559, "z": -0.027, "x": 0.037, "r": 0.328}}, "path": "assets/models/doors/boss_door_red_canyon.glb", "bytes": 1054792, "sha256": "b171f13187228efe01946f735c230e013bada2ae57e097fbfc7e7618d9ad789e"}
{"id": "boss_door_frozen_shore", "raw_tris": 48578, "raw_bytes": 11735216, "tris": {"jamb_n": 1581, "jamb_p": 1697, "lintel": 1717, "slab": 1503}, "frame_tris": 4995, "tex": 1024, "opening_w": 2.547, "slab_h": 2.6, "slab_x": [-0.152, 0.222], "frame_size_xyz": [2.218, 4.22, 6.684], "height": 4.22, "scale": 6.684, "depth_scale": 4.344, "seal": {"front": {"y": 1.48, "z": -0.009, "x": -0.068, "r": 0.319}, "back": {"y": 1.466, "z": -0.001, "x": 0.135, "r": 0.326}}, "path": "assets/models/doors/boss_door_frozen_shore.glb", "bytes": 1087900, "sha256": "87d641445ef0be3785fa58ea78eb69084842368a9cdef44a0b1ce3d4e08feaed"}
{"id": "boss_door_starfall", "raw_tris": 46173, "raw_bytes": 12010396, "tris": {"jamb_n": 1666, "jamb_p": 1739, "lintel": 1594, "slab": 1502}, "frame_tris": 4999, "tex": 1024, "opening_w": 2.594, "slab_h": 2.6, "slab_x": [-0.249, 0.186], "frame_size_xyz": [1.961, 4.305, 6.5], "height": 4.305, "scale": 6.5, "depth_scale": 4.225, "seal": {"front": {"y": 1.483, "z": 0.016, "x": -0.183, "r": 0.328}, "back": {"y": 1.493, "z": 0.002, "x": 0.12, "r": 0.327}}, "path": "assets/models/doors/boss_door_starfall.glb", "bytes": 1109996, "sha256": "7ea0365fbbc3d34acbf110752d87ffdf29435dbd9d4d70d8e07389f01678a392"}
```
Per door (frame = the two jambs and the lintel; the frame's size is the prepared one, depth × height to the crest's
tip × width at the prepared opening):

| Door | Raw triangles | Frame triangles (jamb, jamb, lintel) | Slab | Opening as prepared | Frame D × H × W (m) | Seal centre, radius (m) |
|---|---|---|---|---|---|---|
| ruins | 46,307 | 4,996 (1,891, 1,790, 1,315) | 1,496 | 2.672 | 1.82 × 4.22 × 6.53 | 1.56 up, 0.38 |
| night_rocks | 46,485 | 4,991 (1,660, 1,701, 1,630) | 1,494 | 2.666 | 1.96 × 4.29 × 6.03 | 1.45 up, 0.27 |
| red_canyon | 48,512 | 4,982 (1,769, 1,632, 1,581) | 1,506 | 2.655 | 2.31 × 4.11 × 6.82 | 1.54 up, 0.33 |
| frozen_shore | 48,578 | 4,995 (1,581, 1,697, 1,717) | 1,503 | 2.547 | 2.22 × 4.22 × 6.68 | 1.48 up, 0.32 |
| starfall | 46,173 | 4,999 (1,666, 1,739, 1,594) | 1,502 | 2.594 | 1.96 × 4.31 × 6.50 | 1.48 up, 0.33 |

**Size against the code-made door.** The code door is a 2.2 m slab, 2.5 m jambs and a 0.5 m lintel, so its top is
3.0 m. Each owner's door has a 2.6 m slab (+18 %). The crest's tip is 4.1-4.3 m up, about 40 % over the code door's
top, because the owner's crests stand high above the lintel. The frames are wide: 6.0-6.8 m at the prepared opening,
and the jambs are about 1.7-2.1 m each. The game keeps the jambs unscaled at the sim's gap and stretches only the lintel
and the slab along the gap (`BossDoorView._build_model`), so the slab is exactly the sim's doorway (2.2-3.4 m; 3.0 m on
most floors: a stretch of 1.12-1.18).

## 2. The sounds
```
python3 -I scripts/audio/bd_audio_prep.py
```
Each sound is mixed to mono, resampled to 44.1 kHz 16-bit (the project's sound format, as the manifest gives it) and
trimmed of silence under −54 dBFS. The peak is never raised. Raw output:
```
{"id": "boss_door_opening", "raw": "unprocessed_images/audio_v080/door_opening.wav", "raw_seconds": 2.713, "trimmed_from_s": 0.0, "cut_at_max": false, "seconds": 2.71, "gain_db": 0.0, "peak_dbfs": -10.63, "rms_dbfs": -22.53, "path": "assets/audio/sfx/boss_door_opening.wav", "bytes": 239332, "sha256": "06094087d59376616cd7def418cf9dc0b0bd71480d4b2486230cc368830dc06e"}
{"id": "boss_door_impact", "raw": "unprocessed_images/audio_v080/door_impact.wav", "raw_seconds": 7.537, "trimmed_from_s": 0.09, "cut_at_max": true, "seconds": 2.95, "gain_db": 0.0, "peak_dbfs": -8.33, "rms_dbfs": -21.12, "path": "assets/audio/sfx/boss_door_impact.wav", "bytes": 260234, "sha256": "b9e4bff4e63fdaa7d132767a6e680bb263f888bfd53e427ad951ed56f0c8c98c"}
```
- **The opening** is 2.71 s, its whole length. `BossFlow.DOOR_OPEN_TICKS` = 162 ticks, which is 2.7 s at 60 Hz, so
  the opening lasts as long as the sound.
- **The impact** rings for about 5.5 s before it fades under −54 dBFS (the raw file is 7.54 s). The project's sound
  effects stop at 3 s (`tests/content/test_audio_assets.gd`), so it is **cut at 2.95 s with a 0.9 s fade**. This is a
  choice the owner can reverse (OWNER_TODO §3.0b).

Both are listed in `assets/audio/manifest.json` as `"source": "owner"`. `generate_sfx.py` keeps those rows, and
`--check` reports `0 difference(s)`. The licence line names them, and the credits were rebuilt
(`godot --headless --path . -s scripts/content/build_credits.gd`: `wrote res://data/credits/licences.tres (4
entries)`). The cues are `boss_door_opening` and `boss_door_impact`, positional at the door, with captions
`CAPTION_DOOR_OPENING` / `CAPTION_DOOR_IMPACT` in en and es.

## 3. The press (sim)
The door has a state, `BossFlow.Door`: `PASSAGE`, `SET`, `SHUT`, `OPENING`, `OPEN`.
- On today's floors (floor rules 9, set by `RunState.prepare`; N19 took 8) the door starts at `SET`. On the floor's first
  simulated tick its collider joins the walls (`SHUT`); the arrival hold comes first.
- The interact press within 2.2 m of the door's outer face (`DOOR_REACH_M`) starts `OPENING` and emits
  `BOSS_DOOR_OPENING`. This happens in tick phase 2b, after the altar, chest, shop and shrine: they take the press
  first. The prompt is `BOSS_DOOR_PROMPT`, "[E / X] Open the door".
- 162 ticks later the collider leaves the walls (`OPEN`, `BOSS_DOOR_OPENED`). The flow field is kept for the shut door
  (`World.remove_wall_now(o, true)`), so the sealing swaps it back in without rebuilding it.
- Walking in seals the door as before. A hero put inside past a shut door (tests, shot scripts) seals it once, not
  twice.
- A floor saved before BD (rules 1-8), and a world built without a run, keep `PASSAGE`: the doorway is open until it
  is sealed, as before. `WorldSnapshot.ADDED_SINCE_V05` lists `door` and `door_press_tick`, and the door is hashed only
  when it is not `PASSAGE`, so older floors hash as before.
- The key is the existing `interact` action, E or pad X. The owner wrote "F", but F is Vent, so it is not rebound
  (OWNER_TODO §3.0b).
- The view's slab follows `WorldReader.boss_door_progress()`, not its own rate. When it lands the camera shakes
  (`DOOR_LAND_SHAKE` 0.3; off with shake off or reduced motion). There is **no dust**: there was no small dust effect
  to reuse.

## 4. Tests
Lint, on the final tree (`9cac95f`):
```
$ gdformat --check src scripts tests && gdlint src scripts tests
1039 files would be left unchanged
Success: no problems found
```
New tests:
- `tests/unit/sim/test_boss_door_press.gd` (5): the door is shut and solid until pressed; a press out of reach does
  nothing; in reach it opens over the 162 ticks with both events; it stays solid while it slides, then the passage
  opens and the kept flow field swaps back in at the sealing; a floor saved before BD keeps its open doorway; a hero
  put inside seals it once; same seed same hash, and a snapshot mid-opening restores and finishes the same.
- `tests/unit/presentation/test_boss_door_view.gd` (5): each biome draws its own door (jambs at the gap, the slab
  exactly the gap, a 2.6 m slab, five different meshes); no biome, or the file missing, gives the code-made door; the
  slab follows the sim's opening and lands once (the shake); the seal goes dark once the boss is dead; a floor before
  BD opens by nearness.

Every gut command was `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gdir|-gtest> -gexit`
(logs in `build/bd_tests/`).

**After merging `6f0de2c`** (LD and N19; floor rules 9), on the committed tree:

| Run | Result |
|---|---|
| test_boss_door_press, test_boss_door_view, test_arenas, test_view_build_queue, test_old_saves, test_audio_assets, test_model_manifest | `Tests 50; Passing Tests 50` (5, 5, 14, 5, 8, 7, 6). The run also named `tests/content/test_licences.gd`, which does not exist: `[GUT ERROR]: Could not find script` |
| tests/content/test_credits_licences.gd | `Tests 4; Passing Tests 4` (run on its own after the credits rebuild) |
| tests/e2e/test_e2e_run_flow.gd | `Tests 3; Passing Tests 3`. The door stays shut when you walk into it, its prompt shows, E opens it, the slab slides with the sim, the passage clears, it seals behind you |
| tests/e2e/test_e2e_ascension.gd | `Tests 2; Passing Tests 2` |

**Before that merge** (the same BD code on `73d64a3`, floor rules 8 then):

| Run | Result |
|---|---|
| tests/unit/presentation | `Tests 794; Passing Tests 793; Failing Tests 1`: `test_a_view_built_in_slices_is_the_view_built_in_one_call`. The model door's four parts were all named "Model". Named apart (JambN, JambP, Lintel, Slab), it passed `1/1`, and later `5/5` after the merge |
| tests/content | `Tests 134; Passing Tests 134` |
| tests/arch | `Tests 4; Passing Tests 4` |
| tests/golden | `Tests 2; Passing Tests 2` |
| tests/unit/application | `Tests 99; Passing Tests 99` |
| tests/unit/sim | **cut by the run's 1 h timeout** in `test_ice_patches.gd`: 64 files, 745 tests started. The one failure was `test_arenas.gd` `test_waves_spawn_inside_one_after_another_then_the_doors_open`: `[800] expected to equal [799]: the doors open` (the shut door's collider joins the walls on the first tick). The test now counts it, and passes `14/14` above. **The other sim files, `test_ice_patches.gd` to the end, were NOT RUN locally** (owner rule, 2026-10-18: GitHub runs them) |
| e2e: after_boss 1/1, arenas 2/2, arrival 2/2, boss_challenge 1/1, difficulty 1/1, final_boss 1/1, loading_cover 1/1, nemesis 3/3, portal 1/1, routes 1/1, old_save 1/1, saves 2/2, dev_master_panel 2/2, run_flow 3/3 | all passing. Every e2e that walks through the boss door now presses E first (`E2e.open_boss_door`) |
| tests/e2e/test_e2e_ascension.gd | **crashed once**: `ERROR: /root: The caller thread can't call the function propagate_notification() on this node` then `handle_crash: Program crashed with signal 11`, in `test_the_loop_device_carries_the_build_into_loop_two`. It passed `2/2` on the one re-run after the merge. Cause not found. A worker job touching the tree is the suspect: BD adds the door model's read to `ViewWarmup.warm` (instantiate and free, off the tree, as the enemy models already do) |

Not run: the other agents' areas; `scripts/checks/hit_soak.gd` (it now presses pad X at the shut door; the script was
not run); the balance bots (`FightBot` never walks through the boss door; the bench and lab helpers put the hero
inside, which still seals).

## 5. Shots
The shots were taken with the game camera on llvmpipe at 1600 × 900, and saved as JPEG (quality 85) in
[`bd_shots/`](bd_shots/). For each biome the script boots `main.tscn` on the first run seed whose floor 1 is that
biome, presses Enter through the menu and the build pick, and sets the hero in place (a labelled shot helper):
```
XDG_DATA_HOME=<empty folder> xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --audio-driver Dummy \
  --resolution 1600x900 -s scripts/shots/boss_doors.gd -- biome=<biome> [closed_only]
```
Following the owner's "few shots" rule (2026-10-18), there is one shut-door shot per biome, and the opening, open and
sealed-with-the-boss-dead shots in Ruins only:

| Shot | What | Script's raw lines |
|---|---|---|
| `ruins_1_closed.jpg` | Ruins, shut; the hero 3.5 m in front (the floor's title card is still up: this run was before the script waited for it) | `run seed=6 floor biome=ruins` · `model=true door=2 open=0.00 walls_has_door=true` |
| `ruins_2_opening.jpg` | Half way down after E | `door=3 open=0.52 tick=280` |
| `ruins_3_open.jpg` | Open, the passage clear | `door=4 open=1.00 walls_has_door=false tick=360` |
| `ruins_4_sealed_boss_dead.jpg` | From inside the boss room, 6 m in: sealed behind you, the boss killed (shot helper), the seal dark | `sealed=true` · `boss_dead=true seal_energy=0.15 open=0.00` |
| `night_rocks_1_closed.jpg` | Night Rocks, shut | `run seed=5 floor biome=night_rocks` · `model=true door=2 open=0.00 walls_has_door=true` |
| `red_canyon_1_closed.jpg` | Red Canyon, shut | `run seed=3 floor biome=red_canyon` · `model=true door=2 open=0.00 walls_has_door=true` |
| `frozen_shore_1_closed.jpg` | Frozen Shore, shut | `run seed=2 floor biome=frozen_shore` · `model=true door=2 open=0.00 walls_has_door=true` |
| `starfall_1_closed.jpg` | Starfall, shut | `run seed=4 floor biome=starfall` · `model=true door=2 open=0.00 walls_has_door=true` |

The Ruins set was shot on `73d64a3` + BD (before the merge of `6f0de2c`). The other four were shot on the committed
tree.

The agent's reading of the shots: the door stands in the wall line with its jambs sunk into the wall on either side,
and the crest stands over the wall's top. In the night moods (Night Rocks) the door is dark, as the walls are. How it
looks: **OWNER ONLY**.

## 6. Load probe
Run once, headless, on the committed tree, as the owner's rule asks; a busy shared machine. The timing target is **NOT YET RUN (owner hardware)**.
```
$ godot --headless --fixed-fps 60 --path . -s scripts/checks/load_probe.gd
load_probe: idle      menu 91521 frames, 5000 ms; longest frame    4.2 ms; frames over 50 ms 0
load_probe: new_run   covered 142744 frames, 13827.4 ms; longest frame   46.2 ms; still mark frames 0; after-60 longest    4.3 ms; floor=1 hash=677a9e6cc00c
load_probe: new_run   frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 
load_probe: gate      covered 30638 frames,  4176.9 ms; longest frame   26.5 ms; still mark frames 1; after-60 longest    9.7 ms; floor=2 hash=c24c3e1bf7d1
load_probe: gate      frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 
load_probe: continue  covered 30576 frames,  3789.0 ms; longest frame   37.5 ms; still mark frames 0; after-60 longest    9.2 ms; floor=2 hash=c24c3e1bf7d1
load_probe: continue  frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 
load_probe: deep      covered 39831 frames,  5148.8 ms; longest frame  100.0 ms; still mark frames 1; after-60 longest    6.5 ms; floor=3 hash=530c2ec4b59c
load_probe: deep      frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 25618:100cv
load_probe: ascension covered 23497 frames,  3072.4 ms; longest frame   35.5 ms; still mark frames 0; after-60 longest    5.9 ms; floor=3 hash=03bef6eb1c0b
load_probe: ascension frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 
load_probe: restart   covered 35643 frames,  4169.9 ms; longest frame   27.5 ms; still mark frames 0; after-60 longest    4.1 ms; floor=1 hash=677a9e6cc00c
load_probe: restart   frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 
load_probe: loop      covered 27471 frames,  3675.9 ms; longest frame   27.0 ms; still mark frames 0; after-60 longest    6.2 ms; floor=1 hash=bd7a46b81ef3
load_probe: loop      frames over 50 ms (index from cover start: ms, c = covered, w/v = World/view building): 
```
The door is built in the view's `devices` job, which took 0.2-27.7 ms per load in its `phases` lines (in full in `build/bd_tests/load_probe.log`). Its model is read in the worker's `models` job, which stays on the worker, so there is no main-thread read of the .glb. The one frame over 50 ms (100 ms, the Deep load) is in the `views` job (`view:views=99.5`), not in the door's job: `view_longest_job=99.5`. No gross stall from BD was seen.

## 7. Not done / open
- No dust puff when the slab lands (camera shake only).
- The impact sound is cut at 2.95 s (see §2).
- The key is E, not F (see §3).
- The look of the doors, the size, the jambs' fit against the walls and the sounds: **OWNER ONLY**.
