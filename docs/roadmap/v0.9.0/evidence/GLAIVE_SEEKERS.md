# v0.9.0 AF2: the Glaive and Seekers forms (evidence)

Owner rows: Q7 ("F5 Lance, F6 Scatter, F7 Glaive"; "F8 Seekers, F9 Wave, F10 Wisps"; "Lance replaces the Charge card and
Glaive the Boomerang card (both retired through `migration.tres`)") and Q8 (Twin and Spread merged) in
[`../PLAN.md`](../PLAN.md); forms F7 and F8 with their compatibility cells in [`../ATTACK_FORMS.md`](../ATTACK_FORMS.md);
the pattern of [`LANCE_SCATTER.md`](LANCE_SCATTER.md). Branch `v090-af2`, cut from `7881d345`; the step's commit is the
one that adds this file. Machine: the owner's PC (Windows 11, Git Bash, i7-10700K, RTX 3060), Godot 4.7.2; one GUT
job at a time, with its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit
-gtest=<files>` (or `-gdir=<dir> -ginclude_subdirs`). Lint: `gdformat --check` + `gdlint` on every touched `.gd` (clean).

## What was built

- **Glaive** (`gun_glaive`; Glaive / Disco, "A spinning disc that flies out and back." / "Un disco giratorio que va y
  vuelve."): Rare, Gun only, slot Form. The Gun's own bolt runner with the retired Boomerang's return rule (`returns`
  1): one disc every 0.7 s, 14 m/s for 1.0 s, so it turns 7 m out (half its life) and flies back to the hero, passing
  through every enemy both ways; `share_permille` 1600 (× 1.6 an orb hit a pass, +80 a level), radius 0.3 m, attack
  speed at half its bonus (`rate_scale_permille` 500, as AF1). `glaive` 1 marks it for the view. Row: Twin, Swirl + the
  five elements (Spiral off, as the cell says). Two sim rules for the disc only (`ProjectileMoves`): its life never runs
  out on the way home, and going out a pierce's push past a body spends the ticks that distance takes (without them, a
  point-blank enemy took one pass, not two, and three enemies in a row sent it 11.6 m out).
- **Seekers** (`gun_seekers`; Seekers / Buscadores, "Darts that curve to the nearest foes." / "Dardos que se curvan hacia
  los enemigos cercanos."): Rare, Gun only, slot Form. The bolt runner with `count` 3 over 40°, every 0.3 s,
  `homing` 360 °/s, `share_permille` 450 (+22 a level), 10 m/s for 1 s, radius 0.1 m, `rate_scale_permille` 500. Each
  dart curves to its own enemy (`Seekers.target`: the enemies within 10.8 m of the hero, nearest first, the dart taking
  the one at its rank, its id modulo 3; no new state). The darts past the centre are secondary (statuses at the
  secondary proc: the "lower status chance per dart"). Row: the five elements only (every pattern and motion card off).
- **Boomerang retired**: `boomerang` added to `data/wand/migration.tres` (gun_into `gun_glaive`, blade_into "" =
  refunded as shards); it left the Orbs row (the validator refuses a retired card in a row). Its item and modifier
  stay so old saves resolve.
- **Views**: `GlaiveView` (a flat spinning blade-disc on the core plane, three curved blades round a hot hub and a
  bright rim, two fading afterimages; on the way back it spins the other way and burns brighter); `SeekersView` (each
  dart a thin camera-facing needle along its flight, trailing five fading motes). Element looks from `BeamLooks`. Discs
  and darts are left out of the pulses and the bolt layer.
- **Sound**: two placeholders from `scripts/audio/generate_sfx.py` (numpy, the venv's Python 3.11), rendered one by one
  with the scratch `render_one.py` (only the two new wavs written) and their manifest rows pasted by hand:
  `glaive_throw` (0.38 s whir chopped at a 22 Hz spin, a metallic ring) and `seekers_fire` (0.2 s, three glassy chirps).
  Cues `data/audio/cues/glaive_throw.tres` (−6 dB), `seekers_fire.tres` (−9 dB). Credits rebuilt:
  `godot --headless --path . -s scripts/content/build_credits.gd` → `wrote res://data/credits/licences.tres (4 entries)`.

## Damage (single target against the orbs, `test_glaive.gd` / `test_seekers.gd`, the harness of test_scatter)

Raw `gut.p` lines (the Glaive's after the push rule; the Seekers' after the 10 m/s change):

```
AF2 Glaive flight: farthest 7.70 m, last seen 0.70 m from the hero
AF2 Glaive flight through three in a row: farthest 7.40 m
AF2 Glaive one target 1.5 m, 28 s: 640 dmg in 80 hits; orbs (3 m) 935 in 187; ratio 0.684
AF2 Glaive one target 3.0 m, 28 s: 640 dmg in 80 hits; orbs (3 m) 935 in 187; ratio 0.684
AF2 Glaive one target 6.0 m, 28 s: 640 dmg in 80 hits; orbs (3 m) 935 in 187; ratio 0.684
AF2 Glaive five in a line 2-6.8 m, 10 s: glaive 1160, orbs 335, ratio 3.463
AF2 Glaive venom feeds in 10 s at 3 m: 15 (29 hits)
AF2 Seekers one volley at an enemy 90° off the aim, 4 m: 3 hits
AF2 Seekers one volley over three spread enemies (4, 5, 6 m): hits [1, 1, 1]
AF2 Seekers one target 1.5 m, 28 s: 558 dmg in 279 hits; orbs (3 m) 935 in 187; ratio 0.597
AF2 Seekers one target 3.0 m, 28 s: 564 dmg in 282 hits; orbs (3 m) 935 in 187; ratio 0.603
AF2 Seekers one target 6.0 m, 28 s: 564 dmg in 282 hits; orbs (3 m) 935 in 187; ratio 0.603
AF2 Seekers three spread enemies, aim straight, 10 s: seekers 194, orbs 330, ratio 0.588
AF2 Seekers venom feeds in 10 s at 3 m: seekers 66 (99 dart hits), orbs 66
AF2 Seekers: most launched in any 60 ticks 12
```

**For the owner:** with the docs' numbers read literally, both forms land well under the orbs on one target: the
**Glaive 0.68 ×** (× 1.6 a pass, two passes every 0.7 s = 3.2 orb hits per 0.7 s against 4.7 for the orbs) and the
**Seekers 0.60 ×** (3 × 45 % every 0.3 s is 0.675 × on paper; 45 % of a 5-damage hit rounds to 2, so 0.60 × in play).
The Glaive pays off on a line (3.46 × on five in a row: every disc hits each twice); the Seekers' payoff is aim-free
hits on enemies off the aim (one volley spread over three enemies, all hit), not more damage: on three spread enemies
with the aim straight they did 0.59 × what the orbs did to the one ahead. The docs give no DPS target, so nothing was
tuned; this is the same question as the Lance at 0.46 ×.

## Tests (raw summary lines)

- New sim and view tests (test_glaive, test_seekers, test_glaive_view, test_seekers_view, + test_wand_migration), first
  run: `Tests 45 / Passing Tests 43 / Failing Tests 2` (the Seekers at 16.2 m/s circled an enemy 90° off the aim and
  never hit it; one Fire-on-each-enemy check after a single volley). Fixed (darts at 10 m/s; Fire over 2 s), re-run of
  the four new files: `Tests 28 / Passing Tests 28 / Asserts 186`.
- Sim, arch and view set (25 files: test_attack_slots, test_wand_migration, test_shot_cap, test_lance, test_scatter,
  test_void, test_laser, test_bomb, test_modifier_smoke, test_items, test_gun_pool_order, test_player_builds,
  test_rewards, test_old_saves, test_world_snapshot, test_state_hasher, test_layering, test_sim_purity,
  test_card_pool_reach, test_gun_pool, test_mx4_modifiers, test_mx4_engine, test_modifier_smoke_mx4, test_lance_view,
  test_scatter_view): `Tests 275 / Passing Tests 274 / Failing Tests 1 / Asserts 73124/73125`. The failure, **not
  fixed, for the lead**: `test_card_pool_reach.gd` `[67] expected to be between [40] and [66]: gun: 40-66 cards`
  (`gun pool: 67 in the data`): the Gun pool was at the ceiling (66, raised in the open in v0.8.0 FL, D69) and AF2 adds
  two cards and retires one. I did not raise `CardPoolSurvey.POOL_MAX`.
- `-gdir=res://tests/content -ginclude_subdirs`: first `Tests 140 / Passing Tests 139 / Failing Tests 1` (the credits
  count before the rebuild), then `Tests 140 / Passing Tests 140 / Asserts 10496`.
- e2e `test_e2e_glaive_seekers.gd` + `test_e2e_gun_pool.gd` + `test_e2e_old_save.gd`: `Tests 4 / Passing Tests 4 /
  Asserts 49`; `AF2 e2e Glaive: the enemy at 3 m took 48 in 6 hits; most discs drawn 2, coming back 1`,
  `AF2 e2e Seekers: hits on the enemy ahead / left / right [5, 5, 5]; most darts drawn 3, trail motes 15`.
- After the Glaive's push rule (`ProjectileMoves.pierce`): test_glaive, test_glaive_view, test_gun_pool,
  test_mx4_modifiers: `Tests 50 / Passing Tests 50 / Asserts 362`.
- Then the files that rule reaches or that ran before it: test_seekers, test_modifier_smoke, test_modifier_smoke_mx4,
  test_e2e_glaive_seekers, test_seekers_view: `Tests 30 / Passing Tests 30 / Asserts 46827` (the e2e lines as above).

E2e note: `E2e.mouse_to` sends a probe motion to (100, 100) before every move, so for one tick in each frame the hero
aims at that probe point. A form whose period is an even number of ticks (the Glaive's 42, the Seekers' 18) always
fired on that tick and missed; the new e2e keeps the cursor with its own `_hover` (no probe). The Scatter's 33-tick
period alternates, so half its cones in `test_e2e_lance_scatter.gd` fly toward the probe point too.

## Shots

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/glaive_seekers.gd` (RTX 3060) →
`build/shots/v0.8.0/af2/`, copied by hand to [`af2_shots/`](af2_shots/):

```
glaive_seekers: res://build/shots/v0.8.0/af2/1_glaive_coming_back.jpg (tick 21, discs 1 coming back 1, darts 0 motes 0)
glaive_seekers: res://build/shots/v0.8.0/af2/2_seekers_curve.jpg (tick 26, discs 0 coming back 0, darts 3 motes 15)
```

## Perf (one horde probe per form, headless: CPU side only)

`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde=60 --cards=gun_glaive,gun_twin
--level=5 --seconds=10` and `... --cards=gun_seekers,gun_twin --level=5 --seconds=10` (avg / p95 / max):

```
== glaive
grant gun_glaive L5 -> ok
grant gun_twin L5 -> ok
sim_ms            2.384     3.949     6.717
sync_ms           4.457     6.789    10.939
total_ms          9.611    14.009    19.807
projectiles       3.357     6.000     6.000
verdict: avg 9.61 ms per tick+frame against 12.0 ms -> within
== seekers
grant gun_seekers L5 -> ok
grant gun_twin L5 -> ok
sim_ms            2.396     3.852     7.142
sync_ms           3.962     5.382     8.541
total_ms          8.566    11.528    16.685
projectiles       0.863     5.000     8.000
verdict: avg 8.57 ms per tick+frame against 12.0 ms -> within
```

Both within the 12 ms average, one run each; the Glaive's p95 (14.0) and both worst ticks are over it. Twin is off in
the Seekers' row, but the probe's `grant_now` granted it anyway; the run is the worst case. GPU frame time: NOT YET RUN
(owner hardware).

## Goldens

None changed (no golden file touched; the new spec fields hash only when not 0; the two disc rules run only for a
Glaive disc and `Seekers.target` only for a Seekers dart).

## Not run here

The full suite (GitHub runs it); the seams (the lead's).
