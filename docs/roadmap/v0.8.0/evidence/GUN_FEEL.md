# GUN_FEEL: the Gun's bigger, slower, harder-hitting blue pulse and the hero's cast (v0.8.0 GF1, owner O18, O19)

Owner, 2026-10-15 (verbatim in [`../PLAN.md`](../PLAN.md), third message): "make it a little bit bigger, maybe like 25%
bigger, and the gun should shoot less bullets per second, but do the enough more damage to be able to maintain the
DPS. So we lower the speed a bit, we make it bigger, and then we transform the square that comes out into a pulse,
like a fireball, but it will be blue. The main character needs to have like a casting animation, just spark of light
and swirl that comes out of him every time a bullet comes out … very light".

- **Status:** RUN (agent, headless CPU side and software-rendered shots). The feel, the look on the owner's PC and
  their fps: **OWNER ONLY**.
- **Build:** "before" = `bc2df91` (`claude/lucid-fermat-9wv2tf`, extracted with `git archive` into a scratch folder
  and imported) plus only the probe's two new flags (`scripts/checks/perf_probe.gd`: `--cards=none`, `--on-aim`;
  tool only, no behaviour change). "After" = the working tree of branch `v080-gf1` (parent `bc2df91`) holding the
  `v0.8.0 Step GF1` changes; the runs were made on that tree just before it was committed (only these docs were
  written after them). Godot `4.7.2.stable.official.ed1daf0bf`; Linux 6.18.44 cloud container, shared with other
  agents (timings drift ±15-40 % run to run; the before and after PF runs were interleaved for that reason).
- **Date:** 2026-10-15. **Who ran it:** agent.

## The numbers (data/player/runner.tres, compiled; whole ticks and whole points as the sim runs them)
| | Before | After | Asked | Note |
|---|---|---|---|---|
| Hit radius = drawn radius | 0.16 m (dart drawn 0.38 × 0.07 m, smaller than its hit) | **0.2 m** (pulse core 0.9 × 0.2 = 0.18 m, its glow fading out to 0.32 m) | ×1.25 | exact; what you see is what hits |
| Fire interval | 0.12 s = 7 ticks (8.57 shots/s) | **0.15 s = 9 ticks** (6.67 shots/s) | ×1/0.75 = 9.33 ticks | rate ×0.778 (9 whole ticks; 10 would be ×0.7) |
| Damage a bolt | 4 | **5** | ×4/3 = 5.33 | ×1.25 (whole points) |
| DPS (computed, no crit, no heat) | 4 × 60 / 7 = 34.29 | 5 × 60 / 9 = 33.33 | unchanged | **−2.8 %**: 5/9 against 4/7; the closest whole pair (10 ticks / 6 would be +5 %) |
| DPS on one dummy, measured (probe, below) | 34.2 /s | 33.2 /s | unchanged | −2.9 % (DpsTally, 60 s held Shoot, the Playground's heat on) |
| Flight speed | 18 m/s | **16.2 m/s** | ×0.9 | exact |
| Life / range | 0.6 s = 36 ticks / 10.8 m | **0.6667 s = 40 ticks / 10.8 m** | — | lead's reading: the range is kept (the owner asked for a slower shot, not a shorter one; Mine still stops at the same range) |
| Heat a landed shot | 0.9 | **1.157** (`data/heat/overclock.tres`) | — | ×9/7 so the Gun heats as fast a second with fewer shots; measured below |

The kernel worlds' `PlayerTable` defaults and `PrimaryDefinition`'s defaults take the same numbers (a content test
pins data = kernel starting values). Rounding: the interval rounds 9.33 → 9 ticks, the damage 5.33 → 5; their product
is the −2.8 %. Level multipliers (Pulse Gun +12 % a level), crits, heat and every card scale the 5 with the sim's
per-mille residue carry, as before.

**The cards on top** (their own multipliers, unchanged data; the texts quote relative numbers only, so they stay true):
- Big Shot: ×2 size → 0.4 m (was 0.32), ×1.6 damage → 8 (was 4 × 1.6 = 6.4 → 6), −25 % speed.
- Rapid Fire: ×0.6 size → 0.12 m, −30 % damage → 3 (5 × 0.7 = 3.5 rounded down in the spec; was 4 × 0.7 → 2),
  "+60 % fire rate": 9 / 1.6 = 5.6 → **6 ticks
  (+50 % in whole ticks)**; it was 7 / 1.6 = 4.4 → 4 ticks (+75 %). The text's +60 % is the card's rate bonus; whole
  ticks round it both times (reported, not changed).
- Rapid Coil "+40 %": 9 / 1.4 = 6.4 → 6 ticks (+50 %; was 7 → 5, +40 %).
- Splinter "60 % damage": 5 × 0.6 = 3 a bolt (was 4 × 0.6 = 2.4 → 2).
- Split: the shards keep the card's own 0.08 m (`hook_radius_m`; "half the bolt" of the old 0.16 m). Not grown with
  the bolt: the card's number, not a multiplier (lead's reading, reported).

## What the player sees (presentation)
- **The pulse** (`src/presentation/world_view/hero_pulse_views.gd`, new): every hero shot that isn't a hostile
  fireball or a shrapnel shard is a lit 3D pulse instead of the cyan box dart: a core using the boss orbs' shader
  (`FireballShaders.core`: noise swirl and flicker inside; pale cyan centre `player_core` lerp white 0.5, falling off
  to the body colour at the rim), a soft additive glow that swells and settles on each shot's own seed (the "pulse";
  a new small shader), and a short tapered trail (`FireballShaders.trail`, additive). Body colour: the hero's cyan
  `#2BC4E2` leaned 35 % toward blue `#2F6BFF` = hue 202° (normal colour mode only; the colour-blind modes keep their
  own core colour). No dark edge: a dark rim is the hostile orbs' mark.
- **Colour family.** A shot keeps the bolt colour it was fired with (`ActorViews.bolt_color`: Cinder Shot's orange
  tint, Barbed Bolts', Splinter's green, Ricochet's white, the heat tier's orange / red from Hot up), as the darts did.
  A test pins every hostile look's core and trail ≥ 0.2 (RGB) from the pulse's body, glow and trail, and the body off
  the hostile hue band. Not bluer: the Arc Caster's hostile plasma is periwinkle `#6E9CFF` (trail) on a `#C8DCFF` core;
  a deeper blue would read as an enemy shot (owner question below).
- **Batching.** Three MultiMeshes per look (core, glow, trail), however many shots fly (a test: 300 shots, no new
  node). The game view draws once a frame (blended between ticks), not at the sync too; the rows are written in place.
- **Cards and elements** keep working on top: the bolt look's tint and its stretch (Rapid Coil / Rapid Fire draw the
  pulse drawn-out with a longer trail), the hit radius (Big Shot, Charge, the splits) sizes the pulse, and
  AttackFormView still adds the element darts, particles and cues over it.
- **The cast** (`src/presentation/world_view/hero_cast_fx.gd`, new): on each shot (`WorldReader.shot_fired()`, new,
  read-only: the shot cooldown was just set to the full period) a spark of light (a four-ray star, 0.6 m at its peak,
  0.12 s) at the casting hand (0.32 m along the aim, 0.22 m to the right, 0.62 m up) and a small swirl of light
  winding round the aim (1.25 turns, 0.24 s, 2.6 turns/s). Pooled (4 flourishes built once, round-robin); a shot
  within 6 ticks of the live flourish re-lights its spark and keeps its swirl (Rapid Fire + Rapid Coil: fewer
  flourishes than shots, every shot shown). On the hero model (`player_avatar.gd`): a quick accent (0.13 s): the body
  kicks back 0.07, the head turns 0.14 rad toward the casting side, the hood flicks back 0.09 rad and the visor flares
  ×1.5; shots faster than that hold it up instead of stacking. Reduced motion keeps only the spark (no swirl, no
  accent; the pulse's swirl and swell hold still).

## Commands
```
# DPS of a plain Gun (no cards) on one dummy 4 m out on the aim, 60 s held Shoot, sim only (before and after trees)
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --cards=none --dummies=1 --seconds=60 --sim-only --on-aim --tag=gf1_dps
# the PF probes (Spread + Split + Explosive at level 5, 6 dummies; and + Twin), three runs a side, interleaved in batch 2
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --twin
# a plain Gun with the view (the pulse's own cost with a few shots)
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --cards=none --dummies=1 --seconds=10 --on-aim --tag=gf1_plainview
# shots (one render at a time)
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/gun_feel.gd
```
The probe writes only under `build/perf/`; the numbers below are copied by hand from its printed output.

## DPS: the result
- **Plain Gun, one dummy: 34.2 → 33.2 per s (−2.9 %),** the −2.8 % that whole ticks and whole points leave
  (above). Fewer shots: 0.132 → 0.103 launches a tick. Target "DPS unchanged": met within that rounding.
- **Not asked, reported:** the PF build (Spread + Split + Explosive, L5, 6 dummies) deals **778.1 → 871.8 per s
  (+12 %)**, and with Twin **1,014.8 → 1,457.7 per s (+44 %)**. The bigger bolt (0.2 m) lands more of a fan's and a
  twin pair's bolts on the crowd, and each landed bolt seeds its splits and blasts. Not retuned (no target was given
  for the stacks, and blind retuning is not allowed); an owner question below.
- **Heat:** with the old 0.9 a shot, the slower Gun reached Hot at 6.63 s and Overclock at 12.48 s (`test_heat`
  `test_a_sustained_fight_reaches_the_thresholds_in_6_to_10_seconds` failed: `[398] expected to be between [240] and
  [360]`). With 1.157 a shot: Hot 5.13 s, Overclock 9.63 s; before GF1 (`bc2df91`): Hot 5.17 s, Overclock 9.72 s.
  The test's own print (`gut.p`), after and before:
  ```
      blade: Hot at 4.60 s, Overclock at 8.60 s
      gun: Hot at 5.13 s, Overclock at 9.63 s
  ```
  ```
      blade: Hot at 4.60 s, Overclock at 8.60 s
      gun: Hot at 5.17 s, Overclock at 9.72 s
  ```

## Frame budget (the PF probes): the result
- **Missed: the probe got worse, not "must not get worse".** The pulse view is new work: 0.27-0.64 ms of frame a tick
  with ~100-117 live bolts (the darts were pooled nodes moved at the sync, ~0.005 ms of frame). The first version drew
  at the sync and again each frame (0.53-0.71 ms frame plus as much in the sync); it now draws once a frame with the
  rows written in place (batch 2). The sim also does more (bigger bolts land more, so more splits and blasts: events
  16.97 → 17.05 avg, damage +44 % with Twin).
- Means of the three avg totals (ms; the container drifted between batches, so compare within a batch): base
  batch 1 6.16 → 6.79 (first pulse view), batch 2 7.68 → 8.14; Twin batch 1 6.59 → 8.91, batch 2 8.41 → 11.05
  (medians 8.33 → 9.78; run 3, 15.35, was the batch's noisiest, its sim alone 3.2 ms against 1.8-2.2). Every avg is
  within the 12 ms target but that one; the p95s were already over (PERF.md) and stay over.
- Not tuned further blind. Cheaper options if the owner wants the frame back: drop the glow shell (one MultiMesh
  less a look: about a third of the pulse's cost), or draw the pulse only for the first N live bolts and the rest as
  cores (PF's LIVE_BOLTS_MAX rule).

All runs (avg / p95 / max, ms; copied from each run's output):

| Run | sim | sync | frame | total | HeroPulseViews frame |
|---|---|---|---|---|---|
| base before, batch 1, run 1 | 1.661 / 4.161 / 10.475 | 2.744 / 5.806 / 12.391 | 2.070 / 3.453 / 7.733 | 6.476 / 12.871 / 23.127 | — |
| base before, batch 1, run 2 | 1.527 / 3.448 / 7.680 | 2.561 / 4.810 / 7.995 | 1.932 / 2.604 / 7.050 | 6.019 / 10.641 / 14.459 | — |
| base before, batch 1, run 3 | 1.545 / 3.428 / 7.928 | 2.546 / 4.739 / 7.169 | 1.908 / 2.657 / 4.995 | 5.999 / 10.897 / 14.388 | — |
| base after, first pulse view (drew at sync and frame), batch 1, run 1 | 1.366 / 3.514 / 7.009 | 3.030 / 5.802 / 9.594 | 2.259 / 3.274 / 5.590 | 6.655 / 12.440 / 17.403 | 0.526 |
| base after, first pulse view (drew at sync and frame), batch 1, run 2 | 1.380 / 3.399 / 9.785 | 3.062 / 5.720 / 11.212 | 2.272 / 3.434 / 9.154 | 6.715 / 12.284 / 20.048 | 0.527 |
| base after, first pulse view (drew at sync and frame), batch 1, run 3 | 1.461 / 4.071 / 6.739 | 3.180 / 5.948 / 9.991 | 2.362 / 3.732 / 6.688 | 7.004 / 12.886 / 20.018 | 0.548 |
| base before, batch 2, run 1 | 1.787 / 4.468 / 9.980 | 3.068 / 6.555 / 12.912 | 2.220 / 3.596 / 5.788 | 7.076 / 13.822 / 19.994 | — |
| base before, batch 2, run 2 | 2.345 / 6.512 / 17.525 | 4.008 / 9.066 / 13.992 | 2.977 / 5.476 / 9.849 | 9.330 / 19.279 / 37.527 | — |
| base before, batch 2, run 3 | 1.728 / 4.415 / 13.537 | 2.856 / 6.025 / 22.431 | 2.050 / 3.328 / 8.309 | 6.635 / 13.359 / 35.199 | — |
| base after (as committed), batch 2, run 1 | 1.756 / 4.405 / 10.455 | 3.151 / 5.969 / 20.755 | 2.555 / 4.312 / 15.076 | 7.462 / 13.655 / 28.382 | 0.324 |
| base after (as committed), batch 2, run 2 | 1.426 / 3.656 / 7.729 | 2.582 / 4.682 / 7.869 | 2.083 / 3.197 / 6.297 | 6.090 / 10.839 / 17.821 | 0.274 |
| base after (as committed), batch 2, run 3 | 2.419 / 6.590 / 15.078 | 4.578 / 9.624 / 16.975 | 3.867 / 6.835 / 11.395 | 10.865 / 20.933 / 30.892 | 0.474 |
| twin before, batch 1, run 1 | 1.530 / 4.295 / 9.906 | 2.530 / 4.629 / 7.761 | 2.257 / 3.297 / 11.596 | 6.317 / 12.173 / 20.577 | — |
| twin before, batch 1, run 2 | 1.587 / 4.469 / 9.412 | 2.682 / 5.086 / 14.926 | 2.346 / 3.565 / 8.444 | 6.615 / 13.135 / 21.353 | — |
| twin before, batch 1, run 3 | 1.648 / 4.955 / 10.834 | 2.713 / 5.375 / 14.828 | 2.477 / 4.627 / 7.310 | 6.838 / 13.586 / 25.029 | — |
| twin after, first pulse view (drew at sync and frame), batch 1, run 1 | 1.764 / 4.779 / 9.538 | 3.939 / 7.730 / 13.255 | 3.520 / 6.709 / 11.316 | 9.224 / 17.942 / 26.708 | 0.705 |
| twin after, first pulse view (drew at sync and frame), batch 1, run 2 | 1.663 / 4.527 / 10.837 | 3.665 / 6.917 / 15.648 | 3.317 / 6.197 / 8.221 | 8.644 / 16.007 / 28.051 | 0.671 |
| twin after, first pulse view (drew at sync and frame), batch 1, run 3 | 1.717 / 4.907 / 8.502 | 3.800 / 7.732 / 20.261 | 3.343 / 6.336 / 18.829 | 8.859 / 17.597 / 32.291 | 0.677 |
| twin before, batch 2, run 1 | 1.757 / 5.089 / 9.070 | 3.056 / 5.946 / 10.534 | 2.721 / 5.036 / 13.141 | 7.535 / 14.341 / 22.076 | — |
| twin before, batch 2, run 2 | 1.980 / 6.008 / 14.428 | 3.392 / 7.146 / 13.026 | 2.961 / 5.193 / 9.534 | 8.334 / 18.062 / 24.658 | — |
| twin before, batch 2, run 3 | 2.205 / 6.392 / 14.292 | 3.790 / 8.048 / 13.375 | 3.364 / 6.370 / 9.660 | 9.359 / 19.662 / 32.100 | — |
| twin after (as committed), batch 2, run 1 | 1.794 / 5.046 / 13.157 | 3.186 / 6.024 / 9.917 | 3.043 / 5.285 / 8.409 | 8.022 / 15.870 / 23.821 | 0.343 |
| twin after (as committed), batch 2, run 2 | 2.194 / 6.453 / 23.777 | 3.929 / 8.448 / 14.764 | 3.657 / 7.096 / 11.702 | 9.780 / 20.135 / 38.925 | 0.436 |
| twin after (as committed), batch 2, run 3 | 3.220 / 9.689 / 20.021 | 6.054 / 12.277 / 25.151 | 6.076 / 10.897 / 18.922 | 15.350 / 30.903 / 52.711 | 0.635 |

## Tests (agent; the folders and files this step touches, and their e2e; no local full suite)
Commands (each `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd … -gexit`):
- `-gdir=res://tests/content -ginclude_subdirs` → `Tests 126, Passing Tests 126, Asserts 8706`
- `-gdir=res://tests/arch -ginclude_subdirs` → `Tests 4, Passing Tests 4, Asserts 11192`
- `-gdir=res://tests/golden -ginclude_subdirs` → `Tests 2, Passing Tests 2, Asserts 4` (unchanged)
- `-gtest=` the 49 files of `tests/unit/sim` that name the Gun or bolts (`grep -rli "gun\|bolt"`) +
  `test_movement_feel.gd` + the new `test_gun_feel.gd` (50 files) → `Tests 644, Passing Tests 644, Asserts 149739,
  Time 1788.34s`. The first run of the 49 + movement_feel on the new numbers, before the tests were updated:
  `Tests 640, Passing Tests 628, Failing Tests 12` (the failures were the old numbers and the fixture, listed in
  "Changed tests" below).
- `-gtest=` the 38 files of `tests/unit/presentation` that build ActorViews, PlayerAvatar, WorldViewRoot or the new
  views, + `test_attack_view.gd`, `test_item_visuals.gd` (new: `test_gun_pulse.gd`, 14 tests) → `Tests 288, Passing
  Tests 288, Asserts 277587, Time 448.427s` (on the committed views).
- `-gtest=` e2e `test_e2e_gun_pool.gd`, `test_e2e_wand_build.gd`, `test_e2e_wand_shared.gd`,
  `test_e2e_damage_soak.gd`, `test_e2e_playground.gd` → `Tests 7, Passing Tests 7, Asserts 137, Time 100.859s`; the
  soak's line: `soak: 2 deaths, 42 hits, 6005 frames; nodes 1403 -> 1429`.
- `-gtest=` e2e `test_e2e_old_save.gd`, `test_e2e_saves.gd` (old saves load) → `Tests 3, Passing Tests 3, Asserts 37,
  Time 39.28s`.
- Lint: `gdformat --check src scripts tests` → `930 files would be left unchanged`; `gdlint src scripts tests` →
  `Success: no problems found`.
- Not run locally: the full suite and `scripts/ci/seams.sh` (the lead's, after merging).

**New tests:** `tests/unit/sim/test_gun_feel.gd` (the compiled numbers, the kernel defaults = the data, the DPS on one
dummy measured by a 30 s fight with the old and the new table: ratio in 0.95..1.0, fewer shots; Big Shot and Rapid
Fire on top) and `tests/unit/presentation/test_gun_pulse.gd` (pulses not darts, one instance a shot in each part;
300 shots and no new node; drawn at the hit radius, Big Shot double; the colours vs every hostile look; cards' tints
and stretch and the ember layer on top; a shot keeps its fired colour; effects density Low; reduced motion; the game
view draws once a frame and clears the last shots; `shot_fired` true exactly on the 7 launch ticks of 60; one pooled
flourish a shot, none built; rapid shots merge, every shot shown; reduced motion keeps only the spark; the avatar's
accent, gone in a moment, none under reduced motion).

**Changed tests (old numbers, on purpose):** `test_items` (Splinter 3 a bolt; Rapid Coil 6 ticks, 3 plain shots in
25 ticks), `test_items_j` (Static Chain's bolts 5), `test_movement_feel` (0.2 m), `test_player_builds` (ten bolts over
ten periods, 5 each), `test_player_kit` (five shots in four periods + 1: the first is still alive at 40 ticks),
`test_heat` (1.157 a shot), `test_gun_pool` (Rapid Fire 10 vs 7 bolts a second; Split's shards keep 0.08 m; the
every-card fight runs Ricochet 8 s, since the bigger bolt lands every shot of the first 6 s and its first bounce
comes later), `test_heat_attack_colours` (the bolt colour read from the pulse view), `test_modifier_equivalence`
(header).

## Goldens changed on purpose
`tests/golden/fixtures/modifier_equivalence.json`, regenerated with
`godot --headless --path . -s tests/golden/generate_modifier_equivalence.gd`. Exactly the 12 cases that hold the Gun
changed; the 10 Blade-only cases are byte-identical (hits / damage before → after, from the fixture):

| Case | hits | damage |
|---|---|---|
| gun_plain | 81 → 70 | 384 → 388 |
| both_plain | 170 → 169 | 2822 → 2820 |
| gun_splinter_shot | 205 → 165 | 509 → 583 |
| gun_rapid_coil | 102 → 94 | 474 → 523 |
| gun_ricochet_core | 87 → 74 | 410 → 414 |
| gun_static_chain | 107 → 89 | 565 → 516 |
| gun_frost_core | 81 → 70 | 384 → 388 |
| gun_cinder_shot | 81 → 70 | 688 → 680 |
| gun_barbed_bolts | 98 → 88 | 635 → 601 |
| gun_glacial_rider | 81 → 70 | 408 → 434 |
| gun_all | 472 → 442 | 4160 → 4160 |
| both_all | 199 → 209 | 4160 → 4160 |

`tests/golden` (the kernel replay and the export smoke's hash) is unchanged: the kernel worlds never shoot. Old saves:
nothing new is saved or hashed (`WorldReader.shot_fired` is a read; the views are presentation), and a save's world is
rebuilt from the current data, so a run saved before GF1 resumes with the new shot.

## Shots (software renderer, Ruins stage, the real WorldViewRoot and iso camera; `--fixed-fps 60`)
`scripts/shots/gun_feel.gd` → `build/shots/v0.7.5-dev/gf1/` (the version label still reads v0.7.5-dev) → copied to
[`gf_shots/`](gf_shots/) as `gf1_*`:
```
gun_feel: res://build/shots/v0.7.5-dev/gf1/1_pulses_in_flight.jpg (tick 40, 2 pulses, 1 casts live of 5)
gun_feel: res://build/shots/v0.7.5-dev/gf1/2_cast_flourish_closeup.jpg (tick 37, 2 pulses, 2 casts live of 5)
gun_feel: res://build/shots/v0.7.5-dev/gf1/3_cast_flourish_swirl.jpg (tick 37, 2 pulses, 1 casts live of 5)
gun_feel: res://build/shots/v0.7.5-dev/gf1/4_big_shot_pulses.jpg (tick 40, 3 pulses, 1 casts live of 5)
gun_feel: res://build/shots/v0.7.5-dev/gf1/5_cinder_shot_pulses.jpg (tick 40, 2 pulses, 1 casts live of 5)
gun_feel: res://build/shots/v0.7.5-dev/gf1/6_rapid_fire_pulses.jpg (tick 40, 3 pulses, 2 casts live of 7)
```
- 1, 4, 6: the plain pulse in flight, Big Shot's doubled pulse, Rapid Fire's smaller drawn-out ones.
- 2: the spark at the hand on the shot's tick (two frames on), the new pulse leaving beside it. 3: six frames on, the
  swirl's wisps round the aim. **The swirl reads faint** on the bright sand in the software render (it is "very
  light" by the brief; whether it is too light is OWNER ONLY).
- 5: Cinder Shot's tint (the bolt look's cyan-to-orange mix) reads near white with the pale core; its ember layer
  (AttackFormView) flies with it. The other cards' tints likewise mix with the pulse.

## For the owner (OWNER ONLY; the lead copies these into OWNER_TODO)
- The feel: size, the slower rate, the heavier hit, the pulse, the spark and swirl, the body accent.
- **Blue:** the pulse is the hero's cyan leaned to blue (hue 202°). A deeper blue would sit on the Arc Caster's
  periwinkle plasma (hostile). Keep it, or go bluer and recolour the Arc Caster?
- **The stacks' DPS went up** (Spread + Split + Explosive +12 %, with Twin +44 %) because the bigger bolt lands more
  of a fan. Keep, or trim the stack (BL had just halved it)?
- **The frame:** the pulses cost 0.3-0.6 ms a tick at ~100 live bolts; drop the glow shell or cap the pulses (above)
  if your fps drops with the Gun stacks.
- The range: kept at 10.8 m (the life grew with the slower speed). Or should it shrink with the speed (9.7 m)?

## Raw output

Per run, the probe's full output (one run of each kind; the others are in the table above).

### Before (`bc2df91`): the plain Gun on one dummy
```
perf_probe: gun + , level 5, 1 dummies, 60 s of held Shoot (+60 warm-up ticks), sim only
metric          avg       p95       max
sim_ms            0.176     0.347     1.573
sync_ms           0.000     0.000     0.000
frame_ms          0.000     0.000     0.000
total_ms          0.176     0.347     1.573
projectiles       3.330     6.000     6.000
launches          0.132     1.000     1.000
events            0.396     2.000     2.000
shots_capped      0.000     0.000     0.000
alive_capped      0.000     0.000     0.000
damage: 2054 over 60.0 s -> 34.2 per s (34.2 per s per dummy; DpsTally overall 34.3)
  basic                          2054  100.0 %
verdict: avg 0.18 ms per tick+frame against 12.0 ms -> within
```

### After: the plain Gun on one dummy
```
perf_probe: gun + , level 5, 1 dummies, 60 s of held Shoot (+60 warm-up ticks), sim only
metric          avg       p95       max
sim_ms            0.166     0.289     4.970
sync_ms           0.000     0.000     0.000
frame_ms          0.000     0.000     0.000
total_ms          0.166     0.289     4.970
projectiles       2.867     5.000     5.000
launches          0.103     1.000     1.000
events            0.309     2.000     2.000
shots_capped      0.000     0.000     0.000
alive_capped      0.000     0.000     0.000
damage: 1995 over 60.0 s -> 33.2 per s (33.2 per s per dummy; DpsTally overall 33.3)
  basic                          1995  100.0 %
verdict: avg 0.17 ms per tick+frame against 12.0 ms -> within
```

### Before: the PF probe, base (batch 2, run 1)
```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            1.787     4.468     9.980
sync_ms           3.068     6.555    12.912
frame_ms          2.220     3.596     5.788
total_ms          7.076    13.822    19.994
projectiles     104.532   237.000   250.000
launches          1.783     8.000    10.000
events           15.673    53.000    75.000
shots_capped      0.033     0.000     1.000
alive_capped      0.000     0.000     0.000
bursts_asked     21.655    32.000    32.000
bursts_drawn     13.692    17.000    18.000
sprites_asked   265.732   305.000   308.000
sprites_drawn   265.732   305.000   308.000
lights_asked     11.753    12.000    12.000
lights_on         9.887    10.000    10.000
decals           10.132    11.000    11.000
form_effects     23.558    33.000    36.000
form_meshes      76.137   192.000   209.000
frame cost by node (ms per tick, avg):
  AttackFormView              1.855
  PlayerAvatar                0.185
  DamageNumbers               0.040
  HeatVisuals                 0.037
  BossChallengeView           0.012
  StageKit                    0.011
  TelegraphViews              0.008
  ActorViews                  0.007
  IsoRig                      0.007
  FinalBossViews              0.007
  BossSignatureViews          0.004
  HordeVisuals                0.004
damage: 7781 over 10.0 s -> 778.1 per s (129.7 per s per dummy; DpsTally overall 778.1)
  split_shot                     2807   36.1 %
  shared_explosive               2586   33.2 %
  basic                          2388   30.7 %
verdict: avg 7.08 ms per tick+frame against 12.0 ms -> within
```

### After: the PF probe, base (batch 2, run 1)
```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            1.756     4.405    10.455
sync_ms           3.151     5.969    20.755
frame_ms          2.555     4.312    15.076
total_ms          7.462    13.655    28.382
projectiles      96.663   217.000   237.000
launches          1.580     6.000    15.000
events           14.388    40.000    86.000
shots_capped      0.008     0.000     1.000
alive_capped      0.000     0.000     0.000
bursts_asked     17.993    24.000    25.000
bursts_drawn     12.938    16.000    16.000
sprites_asked   257.723   293.000   293.000
sprites_drawn   257.723   293.000   293.000
lights_asked     11.647    12.000    12.000
lights_on         9.807    10.000    10.000
decals           10.465    11.000    11.000
form_effects     19.827    27.000    32.000
form_meshes      66.033   147.000   171.000
frame cost by node (ms per tick, avg):
  AttackFormView              1.830
  HeroPulseViews              0.324
  PlayerAvatar                0.190
  DamageNumbers               0.045
  HeatVisuals                 0.036
  HeroCastFx                  0.020
  BossChallengeView           0.014
  StageKit                    0.010
  IsoRig                      0.009
  FinalBossViews              0.009
  TelegraphViews              0.008
  ActorViews                  0.006
damage: 8718 over 10.0 s -> 871.8 per s (145.3 per s per dummy; DpsTally overall 871.8)
  shared_explosive               3588   41.2 %
  basic                          2707   31.1 %
  split_shot                     2423   27.8 %
verdict: avg 7.46 ms per tick+frame against 12.0 ms -> within
```

### Before: the PF probe, Twin (batch 2, run 1)
```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
grant gun_twin L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, gun_twin, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            1.757     5.089     9.070
sync_ms           3.056     5.946    10.534
frame_ms          2.721     5.036    13.141
total_ms          7.535    14.341    22.076
projectiles     113.220   252.000   256.000
launches          2.032     8.000    12.000
events           16.965    68.000   104.000
shots_capped      0.217     1.000     1.000
alive_capped      0.000     0.000     0.000
bursts_asked     21.383    32.000    32.000
bursts_drawn     13.900    17.000    18.000
sprites_asked   265.765   299.000   311.000
sprites_drawn   265.765   299.000   311.000
lights_asked     11.583    12.000    12.000
lights_on         9.908    10.000    10.000
decals           10.367    12.000    12.000
form_effects     23.522    33.000    36.000
form_meshes     218.533   478.000   487.000
frame cost by node (ms per tick, avg):
  AttackFormView              2.351
  PlayerAvatar                0.190
  HeatVisuals                 0.038
  DamageNumbers               0.036
  BossChallengeView           0.014
  StageKit                    0.011
  TelegraphViews              0.009
  FinalBossViews              0.008
  IsoRig                      0.007
  ActorViews                  0.005
  HordeVisuals                0.004
  BlinkFlash                  0.004
damage: 10148 over 10.0 s -> 1014.8 per s (169.1 per s per dummy; DpsTally overall 1014.8)
  shared_explosive               4358   42.9 %
  basic                          2988   29.4 %
  split_shot                     2802   27.6 %
verdict: avg 7.53 ms per tick+frame against 12.0 ms -> within
```

### After: the PF probe, Twin (batch 2, run 1)
```
grant gun_spread L5 -> ok
grant split_shot L5 -> ok
grant shared_explosive L5 -> ok
grant gun_twin L5 -> ok
perf_probe: gun + gun_spread, split_shot, shared_explosive, gun_twin, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            1.794     5.046    13.157
sync_ms           3.186     6.024     9.917
frame_ms          3.043     5.285     8.409
total_ms          8.022    15.870    23.821
projectiles     117.108   248.000   252.000
launches          2.077    10.000    17.000
events           17.047    76.000   104.000
shots_capped      0.118     1.000     1.000
alive_capped      0.000     0.000     0.000
bursts_asked     23.072    32.000    32.000
bursts_drawn     14.275    16.000    18.000
sprites_asked   270.548   293.000   305.000
sprites_drawn   270.548   293.000   305.000
lights_asked     11.852    12.000    12.000
lights_on         9.953    10.000    10.000
decals           10.228    12.000    12.000
form_effects     25.245    33.000    38.000
form_meshes     241.927   469.000   485.000
frame cost by node (ms per tick, avg):
  AttackFormView              2.346
  HeroPulseViews              0.343
  PlayerAvatar                0.170
  HeatVisuals                 0.039
  DamageNumbers               0.035
  HeroCastFx                  0.014
  BossChallengeView           0.011
  StageKit                    0.011
  TelegraphViews              0.007
  IsoRig                      0.007
  FinalBossViews              0.007
  ActorViews                  0.005
damage: 14577 over 10.0 s -> 1457.7 per s (243.0 per s per dummy; DpsTally overall 1457.7)
  shared_explosive               5988   41.1 %
  split_shot                     4347   29.8 %
  basic                          4242   29.1 %
verdict: avg 8.02 ms per tick+frame against 12.0 ms -> within
```

### Before: the plain Gun with the view
```
perf_probe: gun + , level 5, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            0.283     0.441     1.880
sync_ms           0.893     1.235     8.717
frame_ms          0.399     0.536     7.274
total_ms          1.575     2.220     9.330
projectiles       3.473     6.000     6.000
launches          0.143     1.000     1.000
events            0.427     2.000     2.000
shots_capped      0.000     0.000     0.000
alive_capped      0.000     0.000     0.000
bursts_asked      0.000     0.000     0.000
bursts_drawn      0.000     0.000     0.000
sprites_asked     5.000     5.000     5.000
sprites_drawn     5.000     5.000     5.000
lights_asked      0.000     0.000     0.000
lights_on         0.000     0.000     0.000
decals            0.000     0.000     0.000
form_effects      0.015     0.000     1.000
form_meshes       0.015     0.000     1.000
frame cost by node (ms per tick, avg):
  PlayerAvatar                0.162
  AttackFormView              0.145
  DamageNumbers               0.017
  BossChallengeView           0.008
  StageKit                    0.007
  TelegraphViews              0.005
  IsoRig                      0.005
  FinalBossViews              0.005
  HeatVisuals                 0.004
  HordeVisuals                0.003
  ActorViews                  0.003
  BlinkFlash                  0.003
damage: 351 over 10.0 s -> 35.1 per s (35.1 per s per dummy; DpsTally overall 35.5)
  basic                           351  100.0 %
verdict: avg 1.57 ms per tick+frame against 12.0 ms -> within
```

### After: the plain Gun with the view
```
perf_probe: gun + , level 5, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
metric          avg       p95       max
sim_ms            0.405     0.769     2.699
sync_ms           1.418     2.298     4.686
frame_ms          0.627     1.030     1.568
total_ms          2.450     3.889     5.738
projectiles       2.970     5.000     5.000
launches          0.112     1.000     1.000
events            0.335     2.000     2.000
shots_capped      0.000     0.000     0.000
alive_capped      0.000     0.000     0.000
bursts_asked      0.000     0.000     0.000
bursts_drawn      0.000     0.000     0.000
sprites_asked     5.000     5.000     5.000
sprites_drawn     5.000     5.000     5.000
lights_asked      0.000     0.000     0.000
lights_on         0.000     0.000     0.000
decals            0.000     0.000     0.000
form_effects      0.023     0.000     1.000
form_meshes       0.023     0.000     1.000
frame cost by node (ms per tick, avg):
  PlayerAvatar                0.223
  AttackFormView              0.179
  HeroPulseViews              0.059
  HeroCastFx                  0.026
  DamageNumbers               0.025
  BossChallengeView           0.013
  StageKit                    0.011
  TelegraphViews              0.009
  FinalBossViews              0.008
  IsoRig                      0.008
  HeatVisuals                 0.006
  HordeVisuals                0.005
damage: 346 over 10.0 s -> 34.6 per s (34.6 per s per dummy; DpsTally overall 34.9)
  basic                           346  100.0 %
verdict: avg 2.45 ms per tick+frame against 12.0 ms -> within
```
