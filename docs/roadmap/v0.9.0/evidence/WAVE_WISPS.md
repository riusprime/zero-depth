# v0.9.0 AF3: the Wave and Wisps forms (evidence)

Owner rows: Q7 ("F8 Seekers, F9 Wave, F10 Wisps", all cells as proposed) in [`../PLAN.md`](../PLAN.md); forms F9 and F10
in [`../ATTACK_FORMS.md`](../ATTACK_FORMS.md); the pattern of [`LANCE_SCATTER.md`](LANCE_SCATTER.md). Branch `v090-af3`,
cut from `52cac58c`; the step's commit is the one that adds this file. Machine: the owner's PC (Windows 11, Git Bash,
i7-10700K, RTX 3060), Godot 4.7.2; one Godot test process at a time, its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit
-gtest=<files>` (or `-gdir=<dir> -ginclude_subdirs`). Lint: `gdformat --check` + `gdlint` on every touched `.gd`:
`28 files would be left unchanged` / `Success: no problems found`.

## What was built

- **Wave** (`gun_wave`; Wave / Oleada, "A wide slow wave that rolls through everything." / "Una ola ancha y lenta que
  lo atraviesa todo."): Rare, Gun only, slot Form. The id is `gun_wave`, distinct from the Blade's Wave card
  (`echo_slash`, shown as "Wave" / "Onda"); its spec carries no `wave` tag, so Split Wave never reads it. Its modifier
  makes the Gun's bolt a band (`WaveShots`): `wave_width_mm` 3000 (the area stat scales it), one every 0.9 s (attack
  speed at half its bonus), 6 m/s for 1.8 s (10.8 m, as far as an orb flies), × 6 an orb hit (+5 % a level). It
  passes through enemies (World's projectile pass skips bodies for it, as the Void's); its band (3 m across its flight,
  0.5 m deep) hits every enemy its body covers once per wave; a wall ends it and shields what is behind (no hit through
  a wall). Row: Twin, Backfire + the five elements.
- **Wisps** (`gun_wisps`; Wisps / Fuegos fatuos, "Three wisps circle you and fire at the nearest foe." / "Tres fuegos
  fatuos te rodean y disparan al más cercano."): Rare, Gun only, slot Form. The hero keeps the orbs; 3 wisps circle
  at 1.1 m (a turn every 2.5 s). Each fires one orb of the Gun's shot at 40 % (+2 points a level) every 0.6 s, the three
  staggered 0.2 s apart, on its own (Shoot held or not), at the nearest enemy it can see within an orb's flight; no
  enemy, no shot. A wisp's orb is no root launch and flies at 650 ‰ of the orb's size. Row: the five elements only.
- **No migration**: ATTACK_FORMS.md names no card that either form replaces or retires (Q7 retires only Charge and
  Boomerang), so `data/wand/migration.tres` is unchanged.
- **State**: none new. The Wave's once-per-wave rule reuses the Void's per-shot wait list (`ModifierState.void_*`,
  keyed by shot id, already hashed and snapshotted); the wisps' places and turns are functions of `World.tick`.
- **Views**: `WaveView` (a curved standing crest as wide as the sim's band, bright at its lip, with a ground wash
  behind it, alpha-blended so it reads on light floors, in the element's colours); `WispsView` (three glowing orbs at
  body height, bobbing, swelling as their shot comes due, flaring on the shot). Wave shots are left out of the pulses
  and the bolt layer; a wisp's orb is drawn by the pulses.
- **Sound**: two placeholder recipes in `scripts/audio/generate_sfx.py` (`wave_fire`, a rolling whoosh; `wisp_fire`, a
  small chirp), rendered with numpy in a scratch copy of `scripts/audio` + `assets/audio`; only the two new wavs and
  their two manifest rows were taken; cue files `data/audio/cues/wave_fire.tres` (-7 dB) and `wisp_fire.tres` (-12 dB);
  `godot --headless --path . -s scripts/content/build_credits.gd` → `wrote res://data/credits/licences.tres (4
  entries)`. A wisp's orb plays `wisp_fire`, not the Gun's `bolt_fire`.

## Damage (single target against the orbs, `test_wave.gd` / `test_wisps.gd`, test_lance's harness)

Raw `gut.p` lines:

```
AF3 Wave one target 4 m, 28 s: 930 dmg in 31 hits; orbs 930 in 186; ratio 1.000
AF3 Wave five spread 2-8 m ahead, 1 m either side, 10 s: wave 1680, orbs 330, ratio 5.091
AF3 Wisps + orbs one target 4 m, 28 s: 1210 dmg in 326 hits; orbs alone 930 in 186; ratio 1.301
AF3 Wisps alone (SHOOT never held) one target 4 m, 28 s: 280 dmg in 140 hits; ratio to the orbs 0.301
AF3 Wisps + orbs held 10 s: most launched in any 60 ticks 12; wisp orbs 50 of 117
```

**For the owner:** ATTACK_FORMS.md gives the Wave no damage number. I set it to × 6 an orb hit so its single target is
**1.00 ×** the orbs, as you set the Lance (about 1.0 × at full charge); because it pierces a 3 m band, a crowd takes far
more (5.09 × the orbs on five spread enemies). The Wisps use the docs' numbers as written (3 × 40 % every 0.6 s): with
the hero shooting too, **1.30 ×** the orbs single target (0.30 × from the wisps alone); not far from 1.0 ×, but it is
always on top of the orbs.

## Tests (raw summary lines)

- Sim and view set (test_wave, test_wisps, test_wave_wisps_view, test_attack_slots, test_items, test_gun_pool_order,
  test_player_builds, test_rewards, test_modifier_smoke, test_wand_migration, test_shot_cap, test_lance, test_scatter,
  test_void, test_laser, test_bomb): `Tests 212 / Passing Tests 210 / Failing Tests 2` (the two audio tests in
  test_wave_wisps_view: the cue files were missing; added).
- test_layering, test_sim_purity, test_old_saves, test_state_hasher, test_world_snapshot, test_wave_wisps_view,
  test_audio_director, test_wisps + `-gdir=res://tests/content -ginclude_subdirs`: `Tests 203 / Passing Tests 203 /
  Asserts 31000` (an earlier content run: `Tests 160 / Passing Tests 158 / Failing Tests 2`: the credits needed
  rebuilding and `ITEM_GUN_WISPS_DESC` es was 63 characters over the 60 limit; both fixed before this run).
- test_wave after adding `test_it_flies_along_the_aim`, and test_wave_wisps_view after the looks changed:
  `Tests 18 / Passing Tests 18 / Asserts 125`.
- e2e `test_e2e_wave_wisps.gd` + `test_e2e_gun_pool.gd` + `test_e2e_old_save.gd`: `Tests 4 / Passing Tests 4 /
  Asserts 47`, with
  `AF3 e2e Wave: damage to the spread at 3 / 5 / 7 m (1 m either side) [90, 90, 60]; most waves drawn 2` and
  `AF3 e2e Wisps: 120 frames without shooting: 18 damage; 120 frames holding shoot: 86 more`.

E2e note (for the lead): `E2e.mouse_to` calls `_mouse_scale()` every time, which sends a probe motion to (100, 100) and
waits a frame; the game takes the probe as a real cursor move, so with Shoot held the aim alternates between the
target and the probe frame by frame. The Wave's 0.9 s period landed every shot on a probe frame (all three dummies
untouched in the first runs). `test_e2e_wave_wisps.gd` measures the scale once and sends single motion events
(`_aim_at`); the other e2e files that hold Shoot while calling `mouse_to` may be aiming half their shots at the probe.

## Shots

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/wave_wisps.gd` (RTX 3060) →
`build/shots/v0.8.0/af3/`, copied by hand to [`af3_shots/`](af3_shots/):

```
wave_wisps: res://build/shots/v0.8.0/af3/1_wave_band.jpg (tick 35, waves 1 widths [3.0], wisps 0)
wave_wisps: res://build/shots/v0.8.0/af3/2_wisps_ring.jpg (tick 44, waves 0 widths [], wisps 3)
```

(1: a Frost Wave rolling through the dummies, three of them hit for 30; 2: the Fire Wisps round the hero, a wisp's orb
landing for 2, Shoot never held.)

## Perf (one horde probe per form, headless: CPU side only)

`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde=60 --cards=gun_wave,gun_twin
--level=5 --seconds=10` and `... --cards=gun_wisps,ember_core --level=5 --seconds=10` (Twin is off for the Wisps, so
their probe takes Fire instead) (avg / p95 / max):

```
== wave
perf_probe: gun + gun_wave, gun_twin, level 5, 0 dummies, 60 horde, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
sim_ms            2.257     3.900     4.540
sync_ms           3.924     5.335    12.615
total_ms          8.352    10.655    18.392
projectiles       5.430     6.000     6.000
verdict: avg 8.35 ms per tick+frame against 12.0 ms -> within
== wisps
perf_probe: gun + gun_wisps, ember_core, level 5, 0 dummies, 60 horde, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
sim_ms            2.355     3.675     6.560
sync_ms           4.428     6.052    13.792
total_ms          9.750    12.730    22.719
projectiles       1.440     5.000     6.000
verdict: avg 9.75 ms per tick+frame against 12.0 ms -> within
```

Both within the 12 ms average, one run each; the Wisps' p95 (12.7) and both forms' worst ticks are over it. GPU frame
time: NOT YET RUN (owner hardware).

## Goldens

None changed (no golden file touched; the new spec fields hash only when not 0).

## Not run here

The full suite (GitHub runs it); the seams (the lead's).
