# v0.8.0 N11: the arrival on the receiver (owner O69)

Build: branch `v080-n11`, cut from `aa7f710`; the runs below are on the working tree of this step's commit (the same
files committed). Machine: the cloud container (headless Godot 4.7.2; shots under Xvfb + llvmpipe), not the owner's
hardware. Feel, timing and "fun": **OWNER ONLY** (D52).

## What was built
- **The receiver** (`src/presentation/world_view/floor_receiver.gd`): a code-made stand-in on every run floor (Deep
  floors too) at `floor_start_pos`, the middle of the first room: a faceted stone disc (2.2 m), a dark metal inset, a
  glowing pale cyan-white landing circle with a ring, four short metal arms rising from the rim and bending inward, a
  soft light, a burst ring and a dust puff for the landing. No arch, no opening. Its colour (`#C9F3FA` / `#F4FDFF`,
  saturation 0.2) is apart from the gate's visor blue (same hue, saturation 0.8), the Deep gate's violet, the
  Ascension portal's gold and the Loop device's green (`test_floor_receiver.gd` checks it). Not on the final arena or
  the Playground (`WorldReader.floor_receiver` = `has_gate`). StageView adds the start to the dresser's `keep_clear`
  (no prop within 1.5 m); the sim already keeps walls 3.5 m off the start (`FloorParams.start_clear_radius`). The sim
  has no body for it: you walk over it.
- **The model**: when `assets/models/manifest.json` lists `floor_receiver` and its file exists, `ShopModels.get_model`
  turns it into our frame, fills a 2.2 × 1.2 × 2.2 m box, and it replaces the disc and the arms (the glow, light, burst
  and dust stay). Not listed yet, so the stand-in draws.
- **The arrival in the sim**: BossFlow's existing arrival hold (v0.3.5 PT: the world holds; no input, no AI, no hits,
  no spawns, no run clock) now opens every run floor, floor 1 included. Lengths are data
  (`data/tuning/sim.tres` → `SimTuning.arrival_first_ticks` / `arrival_ticks` / `arrival_calm_ticks`;
  `BossFlow.arrival_length`): floor 1 of a run 1.6 s = 96 ticks, a later floor 0.8 s = 48, reduced motion 0.3 s = 18.
  Floor 1 is by `run_floor_index() == 1` (a loop's first floor is a later floor). The final arena keeps its 48-tick
  arrival with the old light column. No new hashed or saved field: `arrive_ticks` / `arrive_left` were already in the
  hash and the snapshot, so a save made mid-arrival resumes the rest of it, and an older save (no arrival in it)
  resumes with none.
- **The arrival waits for the cover**: `SimDriver.hold` (Main: `loads.cover.showing`) keeps the world at tick 0 while
  the loading cover or the portal's iris still shows and the arrival hasn't run; the load flow is untouched (N12).
- **The arrival in the view** (`PortalTransitView._land`): floor 1: no hero; the receiver charges; a light tremble
  (`IsoRig.shake_to`) and a wobble (`IsoRig.set_flourish`: a small sine roll and scale), a quick zoom in (×1.16 at
  the pop); at 58 % the hero pops in (an overshooting scale, a pale flash and screen flash, the ring burst, dust), a
  kick (0.5 m) and a rumble (shake 0.6); the view settles. Later floors: the receiver flares and the hero rises out of
  it from 1.1 m under the floor, a small burst, kick and shake. Reduced motion: no shake, wobble, zoom, kick or rise; the
  receiver's light flares and fades and the hero appears in it at 30 %. Off with "shake off" like the other shakes.
- **HUD and hints** wait: the HUD is hidden while arriving (the floor card's clock waits), the hints neither show nor
  count; both come on at the landing.

## Tests
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/sim/test_arrival.gd,res://tests/unit/sim/test_portal_transit.gd -gexit
Scripts               2
Tests                11
Passing Tests        11
Asserts             599
Time              48.913s
```
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/presentation/test_floor_receiver.gd,res://tests/unit/presentation/test_portal_transit_view.gd -gexit
Scripts               2
Tests                10
Passing Tests        10
Asserts            3551
Time              38.577s
```
e2e, first run (arrival, portal, run_flow, saves, old_save, loading_cover, routes, ascension, pad_aim, builds,
horde_enemies, enemies, damage_soak, dev_panel, dev_master_panel, hints):
```
Scripts              16
Tests                32
Passing Tests        25
Failing Tests         7
Asserts           1193/1203
Time              371.314s
```
The 7 failures (raw):
```
test_e2e_run_flow.gd  test_through_the_boss_door_and_down_the_portal_to_floor_two
    [Failed]:  ["Floor 2 · "] expected to equal ["Floor 2 · Red Canyon"]:   at line 155
test_e2e_run_flow.gd  test_restart_run_from_the_pause_menu
    [Failed]:  [0] expected to be > than [0]:  and it runs   at line 198
test_e2e_loading_cover.gd  [Failed]:  [0] expected to be > than [0]:  the run is on   at line 71
test_e2e_ascension.gd  test_the_loop_device_carries_the_build_into_loop_two
    [Failed]:  ["Loop 2 · Floor 1 · "] expected to equal ["Loop 2 · Floor 1 · Night Rocks"]   at line 161
test_e2e_pad_aim.gd  [Failed]: the hero walked west / and faces west / the right trigger shoots / the aim is the hero's facing
test_e2e_builds.gd  [Failed]:  [0] expected to be >= than [2]:  the right trigger shoots   at line 91
test_e2e_builds.gd  [Failed]:  [0] expected to be > than [0]:  left click swings   at line 117
```
Causes: the floor's first tick now waits for the cover and the arrival, so tests that acted (or counted ticks) right
after the run started did so during the arrival; they now wait for the landing (`E2e.landed`, a read-only wait;
`start_from_menu` waits by default). The two HUD-text failures were a real stale line: the floor line named the biome
only on the next tick, which now waits for the cover; `Hud.show_floor` now refreshes it at once.
Re-run of the five failing files after the fixes:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<run_flow, loading_cover, ascension, pad_aim, builds> -gexit
Scripts               5
Tests                15
Passing Tests        15
Asserts             226
Time              151.363s
```
Re-run after the `Hud.show_floor` fix of the e2e that reach the change (arrival, portal, saves, old_save, routes,
hints):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<those six> -gexit
Scripts               6
Tests                10
Passing Tests        10
Time              115.356s
```
Seams dirs and the touched presentation/app files:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application,res://tests/unit/app,res://tests/unit/debug \
  -ginclude_subdirs -gtest=<test_world_snapshot, test_intensity_director, test_shot_cap, test_onboarding_hints,
  test_hud_style, test_ui_polish, test_hit_feel, test_shop_stall_view, test_health_bars, test_routes_view,
  test_blade_feel, test_e2e_camera, test_e2e_shake_option, test_e2e_shell, test_e2e_floor> -gexit
Scripts              63
Tests               386
Passing Tests       386
Asserts           30786
Time              290.009s
```
Lint: `gdformat --check src scripts tests && gdlint src scripts tests` → `Success: no problems found`;
`bash scripts/ci/gut_shard.sh --check` → `gut_shard: ok (364 test files in 6 shards)`.
Not run: the full suite (owner rule: GitHub runs it), the bot tests, the rest of `tests/unit/sim` and
`tests/unit/presentation`.

## Goldens
None changed: the kernel replays and the export smoke have no BossFlow, and no golden fixture holds a run floor
(`tests/golden` passed in the seams-dirs run above). Run floors' hashes and replays change on purpose: floor 1 now
holds 96 ticks of arrival (later floors 48, as before).

## Shots
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
  godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/arrival_n11.gd
arrival_n11: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
arrival_n11: res://build/shots/v0.8.0/n11/1_receiver_alone.png tick=1 progress=0.01041666666667
arrival_n11: res://build/shots/v0.8.0/n11/2_mid_shake.png tick=44 progress=0.45833333333333
arrival_n11: res://build/shots/v0.8.0/n11/3_pop.png tick=58 progress=0.60416666666667
arrival_n11: res://build/shots/v0.8.0/n11/4_settle.png tick=87 progress=0.90625
arrival_n11: res://build/shots/v0.8.0/n11/5_floor2_step_out.png tick=15 progress=0.3125
```
The run then stopped without its sixth shot or the contact sheet (no error in the log; most likely the command's
`timeout 900` under llvmpipe while other agents' tests ran). Copied by hand into [`n11_shots/`](n11_shots/):
the receiver alone (1), mid-shake with the zoom (2), the pop with the flash (3), the settle with the burst ring and dust
(4), floor 2's step-out (5). A still can't show the wobble or the shake: OWNER ONLY.
Frame cost: not measured (one small CPU particle burst, a few meshes and one light per floor; no new shader).
