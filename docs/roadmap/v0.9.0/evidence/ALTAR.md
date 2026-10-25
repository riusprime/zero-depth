# v0.9.0 Step SA: the floor-1 arrival altar — evidence

Build: branch `v090-safa`, cut from `ce7ffad7` (Step CV); the Step SA commit is the one that adds this file.
Machine: the owner's PC (Windows 11, i7-10700K, RTX 3060), Godot 4.7.2, Git Bash.

## What changed

- `AltarStage` (`src/presentation/world_view/altar_stage.gd`): one altar scene with two looks (`AltarStage.arrival()`
  blue, `AltarStage.final()` purple for Step FA): colours, rune set (count, radius, sigil cells), jewels, timeline
  (fractions of a progress 0..1), sound cue and its peak, trigger (the caller's progress). Code stand-in: four faceted
  stone steps, 6.6 m across, top 4.4 m, 0.22 m high; ten carved rune panels and an inlay ring in the top; eight jewel
  sockets; ten floating runes and eight jewels as separate objects. The owner's `arrival_altar.glb` slots in through
  `ShopModels` (`arrival_altar`: 6.6 × 0.45 × 6.6 m box) when the models manifest lists it; the runes and jewels stay
  code objects.
- Floor 1 of a run only (`WorldReader.arrival_altar()`): the altar replaces the receiver in the start room. Later floors
  are unchanged (Step PT's).
- `arrival_first_seconds` 1.6 → 4.0 (`data/tuning/sim.tres`; `BossFlow.ARRIVE_FIRST_TICKS` 96 → 240,
  `SimTuningDefinition` default 4.0). Nothing spawns and the hero can't be hit until it ends, as before.
- The six stages (`PortalTransitView._land_first`): idle (0–0.08), runes and jewels light one after another
  (0.08–0.30), orbit from 0.22 speeding up to the pop, buildup from 0.38 (particles, swirl, glow, vibration climbing,
  zoom), the existing pop at 0.72 (2.88 s: overshoot, flash, burst ring, dust, `rig.thud`), release (runes slow, energy
  fades). The roll wobble is gone. Reduced motion: no orbit, particles, vibration or zoom; the runes light, the hero
  appears.
- Sound: `arrival_altar` (placeholder, procedural, `scripts/audio/generate_sfx.py` `s_arrival_altar`; 2.8 s, the
  pop's peak at 2.304 s in the file). `AudioEvents._arrival` starts it at progress `pop_at − cue_peak_s / length` so
  the peak lands on the pop. Caption `CAPTION_ARRIVAL_ALTAR` (en, es). Credits rebuilt
  (`scripts/content/build_credits.gd`).
- Footprint: the sim already keeps the start hall's cover and spawn spots `FloorParams.start_clear_radius` (3.5 m)
  from the start; a new test proves nothing in the sim stands within 3.3 m on 12 seeds. The presentation drops loose
  decoration within 3.5 m (`AltarStage.clear_decor`).

## Commands and raw summary lines

Import: `godot --headless --path . --editor --import --quit`.
Tests: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>`.

Goldens and replay (`tests/golden/test_replay_ground_plane.gd`, `tests/unit/sim/test_modifier_equivalence.gd`,
`tests/unit/sim/test_state_hasher.gd`, `tests/unit/sim/test_player_builds.gd`, `tests/content/test_content_valid.gd`):

```
Scripts               5
Tests                33
Passing Tests        33
Asserts             619
Time              24.082s
```

No golden hash moved (the goldens run `KernelScenario.golden`, which has no arrival).

Units, first run (`test_altar_stage`, `test_floor_receiver`, `test_sim_tuning`, `test_audio_assets`,
`test_credits_licences`, `test_arrival` (sim), `test_door_boom`, `tests/arch/test_layering.gd`):

```
Scripts               8
Tests                41
Passing Tests        36
Failing Tests         5
Asserts           29675/29685
Time              194.937s
```

The five failures: `test_arrival.gd` still expected 96 ticks (updated to 240), and the stand-in size test measured a
turned tier's AABB (7.01 m; now the unturned bottom step). Re-run of those two files:

```
Scripts               2
Tests                16
Passing Tests        16
Asserts             902
Time              55.446s
```

Neighbours (`test_camera_vibration`, `test_portal_transit_view`, `test_portal_transit` (sim), `test_floor_receiver`,
`test_floor_generator`):

```
Scripts               5
Tests                31
Passing Tests        31
Asserts           458867
Time              288.192s
```

e2e `tests/e2e/test_e2e_arrival.gd` (floor 1 on the altar: 240 ticks, the cue once; floor 2 unchanged):

```
Scripts               1
Tests                 2
Passing Tests         2
Asserts              98
Time              51.483s
```

e2e `test_e2e_loading_cover.gd`, `test_e2e_run_flow.gd`:

```
Scripts               2
Tests                 4
Passing Tests         4
Asserts             119
Time              97.782s
```

e2e `test_e2e_portal.gd`, `test_e2e_builds.gd`:

```
Scripts               2
Tests                 9
Passing Tests         9
Asserts             266
Time              99.109s
```

## Shot

`godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/altar_safa.gd`
(renderer forward_plus, NVIDIA GeForce RTX 3060) wrote `build/shots/v0.9.0/safa/`; copied by hand:
[`safa_shots/altar_floor1_buildup.png`](safa_shots/altar_floor1_buildup.png) (tick 149, progress 0.62: the runes
orbiting through the buildup).

Feel, the sound's quality and the timing on the owner's screen: OWNER ONLY.
