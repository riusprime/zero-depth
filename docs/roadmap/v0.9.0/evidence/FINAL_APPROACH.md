# v0.9.0 Step FA: the final approach — evidence

Build: branch `v090-safa`, on top of the Step SA commit `f16b8ad4`; the Step FA commit is the one that adds this file.
Machine: the owner's PC (Windows 11, i7-10700K, RTX 3060), Godot 4.7.2, Git Bash.

## What changed

- Sim layout (`FinalArena.approach_layout`, `src/sim/map/final_arena.gd`): the plateau is the hollow arena's ring
  (radius 15 m, 32 segments) with the three segments on the hero's side left open; a causeway 25 m long and as wide as
  the gap (about 8.7 m) runs out from the gap, walled on both sides and at its foot. The hero arrives 2.5 m up from the
  foot (22.5 m from the plateau's edge). Two pylons at 0.62 × the radius across the causeway's axis; the altar at the
  centre, where the boss rises. Flat sim; the steps are drawn.
- Sim flow (`FinalApproach`, `src/sim/world/final_approach.gd`, `World.approach`): WALK → each pylon switches on with
  one interact press within 2.0 m (order free; slotted after the boss door in `World.step`'s interact order) → the
  second starts the BUILDUP (180 ticks, 3.0 s) → FIGHT: the three light walls are added (`World.add_walls_now`), a
  hero still on the causeway is set back on the plateau, and `FinalBoss.begin` raises the Colossus at the altar. The
  fight itself is unchanged. Hashed (`hash_into`) and snapshotted (`STATE_CLASSES`, old saves: `ADDED_SINCE_V05`).
- The run's way in (`FloorPlan`): the Ascension portal now opens the approach (`FinalArenaScenario.build(…, approach
  = true)`); the fight is not begun at build. `FloorPlan.approach_of(save)`: a save made on the approach or in its
  fight resumes there; a save made in the final arena before FA (no `approach` in its world) resumes the ring arena
  bare, as before. The tests' and tools' direct path (`FinalLab.arena`, `FinalArenaScenario.build` without
  `approach`) is unchanged.
- Presentation: `FinalApproachView` (the purple `AltarStage.final()`; two code-made rune pylons that lock in with a
  punch, a flash, motes and a light, and sink once the fight begins; the walls of light rising; `rig.thud` on the
  landing and when the walls rise, `rig.vibrate_to` climbing through the buildup), `FinalArenaStage` draws the
  causeway (14 treads with lit edges over a rock spine; no pillar or brazier in the gap), `FinalApproachHud` (the
  prompt `APPROACH_PYLON_PROMPT`: "[E / X] Awaken" / "[E / X] Despertar"). `WorldReader.has_gate()` is false on the
  approach (no run gate, no receiver there).
- Sounds (placeholders, procedural, `scripts/audio/generate_sfx.py`): `pylon_lock` (1.26 s), `final_altar` (2.9 s,
  its peak at 2.235 s, timed so the peak lands on the buildup's end); the walls rising reuse `boss_door_seal`.
  Captions `CAPTION_PYLON_LOCK`, `CAPTION_FINAL_ALTAR` (en, es). Credits rebuilt.

## Commands and raw summary lines

Tests: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>`.

Goldens and replay (`test_replay_ground_plane`, `test_modifier_equivalence`, `test_state_hasher`,
`test_player_builds`), after FA:

```
Scripts               4
Tests                26
Passing Tests        26
Asserts             525
Time              16.799s
```

No golden hash moved (the approach's state is hashed only in a world that has one).

Existing final-boss and save units (`test_final_boss`, `test_colossus`, `test_final_pace`, `test_nemesis`,
`test_prism`, `test_world_snapshot`, `test_final_achievements`, `test_run_saves`, `tests/arch/test_layering.gd`),
run with FA's sim in place (before the `has_gate` fix below, which only touches approach worlds):

```
Scripts               9
Tests               132
Passing Tests       132
Asserts           33851
Time              567.21s
```

The new sim test `tests/unit/sim/test_final_approach.gd` printed: `arrival to the Colossus at a walk: 760 ticks
(12.7 s)`.

e2e `test_e2e_nemesis.gd`, `test_e2e_prism.gd`:

```
Scripts               2
Tests                 4
Passing Tests         4
Asserts            4608
Time              98.227s
```

e2e `test_e2e_final_boss.gd`, `test_e2e_ascension.gd`, first run: the ascension file passed (2/2); the final boss
file failed one assert, `Expected [... (portal_gate.gd)] to be NULL: no portal`: the approach world counted as having
a run gate (`WorldReader.has_gate()` read `final_fight == null`). Fixed (`has_gate` is false with an approach); the
re-runs follow.

```
Scripts               2
Tests                 3
Passing Tests         2
Failing Tests         1
Asserts           147/148
Time              141.25s
```

After the fix, e2e `test_e2e_final_boss.gd` (now through the approach: `E2e.awaken_final_altar`, then the Prism's
save and Continue, the win) and the new `test_e2e_final_approach.gd` (from the Ascension portal through real input:
E far from a pylon does nothing; by pylon A the prompt, E locks it in with its sound and still no boss; by pylon B
the buildup, the purple runes spin, the walls of light rise, the Colossus rises at the altar, a save at its start).
It printed `landing to the Colossus through real input: 912 ticks (15.2 s)`.

```
Scripts               2
Tests                 2
Passing Tests         2
Asserts             112
Time              85.032s
```

FA units after the fix (`test_final_approach` (sim), `test_final_approach_view`, `test_final_boss_views`,
`test_floor_receiver`, `test_altar_stage`, `tests/arch/test_layering.gd`, `test_audio_assets`,
`test_credits_licences`, `test_content_valid`):

```
Scripts               9
Tests                58
Passing Tests        58
Asserts           32112
Time              163.833s
```

After the fix, e2e `test_e2e_nemesis.gd`, `test_e2e_prism.gd`, `test_e2e_ascension.gd`:

```
Scripts               3
Tests                 6
Passing Tests         6
Asserts            4684
Time              152.389s
```

## Shots

`godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/approach_fa.gd` (a SubViewport with the
real `WorldViewRoot` and its iso camera, renderer forward_plus, NVIDIA GeForce RTX 3060) wrote
`build/shots/v0.9.0/safa/`; copied by hand:
[`safa_shots/approach_causeway.png`](safa_shots/approach_causeway.png) (the stair causeway up to the plateau, the
pylons dark) and [`safa_shots/approach_plateau_buildup.png`](safa_shots/approach_plateau_buildup.png) (both pylons
lit, the purple altar 120 ticks into its buildup).

Feel, the sounds' quality and the walk's length on the owner's screen: OWNER ONLY.
