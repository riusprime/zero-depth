# FC7: the Seekers accept eleven more cards (v0.9.5 Step FC7, FORM_COMBOS.md S1-S11)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc7` (cut from `claude/v095-feedback` at b358d62b, which
  holds FC4, FC5 and FC6); a file cannot name its own commit, the SHA is in the step report. Godot 4.7.2 stable;
  Windows 11 Pro, owner PC, several Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/seeker_mods.gd` (pure, one handler per card; `SeekerMods.DEFAULTS` = the data row, 22 keys). A dart
  ignores the eleven cards' generic ops (`WandCompile.run` notes the id in `modifier_ids`), the handlers read them.
  - Volley (`Attacks._bolts`, the player's own volley only): Twin doubles the count to 6 darts, each 60 %; Halo spreads
    the darts at even angles round 360 degrees (3 darts: 0/120/240 from the aim; with Twin 6, every 60); Big Shot is 2
    darts, damage x2.0, radius x1.5; Rapid Fire is 5 darts, damage x0.65, radius x0.7 (Big and Rapid together keep the
    plain 3; they multiply damage and radius); Ricochet launches with 3 wall bounces; Pierce launches with 2 more
    pierces (`World.set_pending_pierce`, the Wisps' mechanism: 3 hits in all); Echo: each dart leaves a row, and 18
    ticks later a ghost dart flies the same line from the same muzzle at 50 % of that dart's damage.
  - Flight (`ProjectileMoves.steer` -> `SeekerMods.steer`, before the homing rule): from the dart's birth, Orbit flies
    one 60-tick lap at 2.5 m round the hero, then Mine hangs still 36 ticks, then Halo flies straight 18 ticks; then
    the plain homing runs. Out of Orbit the dart leaves along its launch heading; out of Mine (without Halo) it is set
    straight at its target (`Seekers.target`) and dives together with the rest. A dart's life is its flight plus the lap
    and the hold. Target picks: `Seekers.target` ranks the enemies nearest the hero (a tie: the lower index), now with
    the volley's real dart count (Twin's 6).
  - Hits (`World._projectile_hits` -> `SeekerMods.on_hit`): Pierce notes the enemy hit; `Seekers.target` ->
    `SeekerMods.pick` then gives the nearest un-hit enemy to the dart, or `Seekers.STRAIGHT` (fly on, no homing) when
    none is left. Ring: each hit makes a ring row at the enemy (1 m, `Stats.area`, 30 % of the dart's damage, lands next
    tick once on each enemy in it, shown 12 ticks). Split, once per dart: two children leave just past the body at
    +-30 degrees from the dart's heading, 35 % damage, a normal 1 s flight, each seeking the 1st / 2nd nearest enemy
    that is not the one split from (`pick`); they start no follow-ups (no Split, Echo or Ring of their own).
  - Bound: at most `live_max` = 24 live darts per hero (`SeekerMods.cull` after `World._apply_spawns` and in
    `advance`; the oldest end first), rows capped at 64 (`ROWS_MAX`; a row that does not fit is not added). The shot
    caps (12 an attack, 40 a second) apply to the volley as before; Echo's ghosts and Split's children are bounded by
    the 24-dart cap, not the shot cap.
  - Rows in `ModifierState.sk_*` (a live dart, a dart to open, a ring, Pierce's hits), hashed only while set, listed in
    `WorldSnapshot.ADDED_SINCE_V05` (an older save loads with none); `WorldReader.seeker_rings()`.
- Data: `data/wand/attack_slots.tres` seekers row `allowed` += `gun_twin`, `halo_shot`, `gun_ring`, `gun_pierce`,
  `gun_ricochet`, `gun_echo`, `gun_big_shot`, `gun_rapid_fire`, `split_shot`, `gun_mine`, `orbit_rounds`; a `params`
  dictionary (22 keys); `AttackFormRow.SEEKER_KEYS`; one line in `attack_slots_definition.gd::_keys_of`. Backfire,
  Homing, Spiral, Swirl and Threadline stay off. Twin was not on for the Seekers before, so S1 is new, not a change.
- View `seekers_view.gd`: Ring's lightning ring where a dart hit (the Glaive's ring look); `DARTS_MAX` 18 -> 24 so the
  bound's 24 darts are all drawn. Every other card reuses the dart look. No new art.
- `scripts/balance/forms_dps.gd`: `SEEKER_COMBOS` (plain + the eleven) and a `["seekers", ...]` entry in the combo list.
- Test counts: `test_shot_rate_all_forms.gd` builds 37 -> 40 (+3: the Seekers row's Pattern and Secondary combinations).
  `test_seekers.gd`'s list of cards the row takes (`SEEKERS_ON`) gains the eleven.

## Deviations to flag (numbers or readings the spec left open)

- Integer damage: the plain dart deals 2 (45 % of 5, rounded). The shares floor to a whole number with a minimum of 1:
  Twin's 60 % of 2 is 1 (6 x 1 = 6 = the plain 3 x 2), Rapid Fire's 65 % is 1 (5 x 1 = 5 against 6), Ring's 30 %, Echo's
  50 % and Split's 35 % are each 1. So on the sheet Twin reads x1.00 and Rapid Fire x0.83, not the x1.2 / x1.08 the
  percentages promise; at a higher dart damage (more levels, damage stats) they approach those. Big Shot is exactly x2.
  No retune made.
- Halo reads x0.33: the darts fly straight 18 ticks (3 m) away from targets that stand 4 m ahead, then must turn
  at 360 degrees a second on a 1.6 m circle; most miss. That is the spec's "fly straight, then seek as normal".
- Big Shot and Rapid Fire together keep the plain 3 darts (the two counts cancel); Twin doubles whatever the count is.
- Ring includes the enemy the dart just hit (the ring hits every enemy in 1 m, once). On one target that is x1.5.
- Split children's radius equals the dart's, their life is the plain 1 s, their heading is +-30 degrees from the dart's
  (the Glaive's `split_deg`); children keep Ricochet's bounces. The spec did not give these.
- Echo's ghost darts are launched from the original muzzle and angle (the hero may have moved), as the Glaive's and
  Lance's; they carry Pierce, Ricochet, Ring, Mine, Orbit and Halo of their own, but not Echo or Split.
- Orbit and Mine are measured from the dart's birth, in the order Orbit, Mine, Halo's straight flight; combined, the
  lap comes first. Mine with Halo launches along the dart's heading (no snap to the target).
- The rear dummy of the e2e (180 degrees behind the aim) is not asserted hurt: it is past a dart's 1.6 m turning circle.
  The e2e run printed `[true, true, false, true]` for the dummies ahead, left, behind, right.
- Pierce: the third hit ends the dart in the same tick, so the hit list of a row never shows more than 2 entries to a
  poll after the tick; the unit test asserts the three hits from the damage events instead.

## Commands and raw results (all `--language en`, own `APPDATA` per process, project.godot untouched)

- `godot --headless --path . --editor --import --quit`: no SCRIPT ERROR lines (after the work).
- `gdformat` + `gdlint` (src/sim, src/content, src/presentation/world_view/attack_forms, scripts/balance and the touched
  tests): "Success: no problems found".
- New unit test `tests/unit/sim/test_seeker_mods.gd`: 21/21 passing, 238 asserts.
- `-gtest=res://tests/unit/sim/test_seekers.gd,test_attack_slots.gd,test_shot_rate_all_forms.gd,test_world_snapshot.gd,
  test_modifier_equivalence.gd`: 47 tests, 45 passing; the 2 failures were the stale list in `test_seekers.gd` and the
  build count (37, now 40), both updated. Re-run after the updates of
  `test_seeker_mods.gd, test_seekers.gd, test_shot_rate_all_forms.gd, test_seekers_view.gd`: 37 tests, 37 passing,
  1182 asserts. `test_attack_slots`, `test_world_snapshot` and `test_modifier_equivalence` were not re-run after the
  last change (Split's children spawn just past the body, active only with Split); they passed in the first run.
- `tests/unit/presentation/test_seekers_view.gd` (a Ring test added): 5/5 passing, 16 asserts.
- `-gdir=res://tests/golden,res://tests/arch,res://tests/content -ginclude_subdirs`: 33 scripts, 163 tests, 163
  passing, 30758 asserts. No golden digest moved.
- e2e `tests/e2e/test_e2e_seeker_combos.gd` (headless, drives main.tscn through `Input.parse_input_event`; Seekers at an
  altar, Twin and Echo by the dev panel's Grant): 1/1, 15 asserts; most darts drawn 20.
- Not run: the slow seed-loop tests, `seams.sh`, the full suite (GitHub runs them).

## forms_dps (`godot --headless --path . -s scripts/balance/forms_dps.gd`, floor 5, crit off, no elements)

Orbs baseline: single 930, line 335, pack 330. Plain Seekers: single 558, line 198, pack 198 (x0.600 / 0.591 / 0.600
of the orbs). The ratios below are against the plain Seekers (damage in the scenes: single / line / pack).

| Cards | single x | line x | pack x | single / line / pack dmg |
|---|---|---|---|---|
| (plain) | 1.000 | 1.000 | 1.000 | 558 / 198 / 198 |
| Twin | 1.000 | 1.000 | 1.000 | 558 / 198 / 198 |
| Halo | 0.333 | 0.333 | 0.333 | 186 / 66 / 66 |
| Ring | 1.500 | 1.500 | 2.333 | 837 / 297 / 462 |
| Pierce | 1.000 | 3.030 | 1.333 | 558 / 600 / 264 |
| Ricochet | 1.000 | 1.000 | 1.000 | 558 / 198 / 198 |
| Echo | 1.500 | 1.500 | 1.500 | 837 / 297 / 297 |
| Big Shot | 1.333 | 1.333 | 1.333 | 744 / 264 / 264 |
| Rapid Fire | 0.833 | 0.833 | 0.833 | 465 / 165 / 165 |
| Split | 1.000 | 2.015 | 2.010 | 558 / 399 / 398 |
| Mine | 1.000 | 1.000 | 1.000 | 558 / 198 / 198 |
| Orbit | 1.007 | 0.667 | 1.030 | 562 / 132 / 204 |

None exceeds x2.0 on a single target or x6.0 on a pack (the largest: Pierce line x3.03, Ring pack x2.33). Before
Split's children were moved past the body they read x2.00 single (they hit the enemy they split from); fixed, no
number was tuned.

## OWNER ONLY

- Whether Twin's six darts, Halo's circle, Mine's hang and dive, Orbit's lap and Split's children read well and feel
  right: OWNER ONLY (empty).
- Whether Halo at x0.33 and Twin / Rapid Fire at about x1.0 / x0.83 are acceptable: OWNER ONLY (empty).

## FC7b: the carry

**What changed.** A Seekers hit no longer floors to a whole number with a minimum of 1. Every dart is dealt in thousandths:
`milli = shot_damage * share_permille` (450 + 5 per level), times the cards' factor (Twin 600, Big Shot 2000, Rapid Fire 650) / 1000;
Echo ghosts, Split children and Rings take their share of the dart's milli (500, 350, 300). `SeekerMods.take` deals
`(sk_carry + milli) / 1000` whole damage and keeps the rest in `ModifierState.sk_carry` (one per world: there is one hero).
A short carry deals 0 (no minimum of 1); a 0-damage dart is still launched and goes through the same `Damage.hit` path as any hit.
`sk_carry` is hashed inside the `sk` block, which is now also hashed while the carry is non-zero, and is saved in `WorldSnapshot.ADDED_SINCE_V05`
(an older save loads with 0). Only the Seekers form changed (`Attacks._shared_form` skips the half-up share rounding for `spec.seekers > 0`;
`Attacks._bolts` computes the milli). `World.set_pending_milli` hands the dart's milli to `SeekerMods.on_spawn`, which keeps it in the dart's row (`sk_dmg`) for Ring and Split.

**Reading to flag.** The carry is paid out when a dart is launched (volley, Echo ghost opening, Split child opening, Ring landing), not when it hits,
because a projectile stores whole damage; the average is exact, but a dart that misses still spent its share. `sk_dmg` of a K_OPEN row now holds thousandths
(an older save with an Echo/Split row in flight would read it 1000 times small: one volley of a mid-flight save). Plain Seekers now has a carry,
so its `sk` block is hashed after the first volley (it was hashed only with card rows before).

**Commands and raw results** (all `--language en`, own `APPDATA`, headless, `--fixed-fps 60`, Godot 4.7.2; lint: gdformat + gdlint on the 6 touched files, "no problems found"):

| Test | Result |
|---|---|
| `tests/unit/sim/test_seeker_mods.gd` | 25/25 passed, 761 asserts (4 new FC7b tests; 5 old assertions reworded to totals; 3 asserted "plain Seekers has no state", now "no rows" / no shot) |
| `tests/unit/sim/test_seekers.gd` | 10/10, 79 asserts |
| `tests/unit/presentation/test_seekers_view.gd` | 5/5, 16 asserts |
| `tests/unit/sim/test_shot_rate_all_forms.gd` | 2/2, 336 asserts |
| `tests/unit/sim/test_world_snapshot.gd` | 15/15, 6291 asserts |
| `tests/unit/sim/test_modifier_equivalence.gd` | 3/3, 68 asserts |
| `tests/unit/sim/test_attack_slots.gd` | 17/17, 525 asserts |
| `tests/unit/sim/test_card_levels_clv.gd` | 9/9, 302 asserts |
| `tests/golden` | 2/2, 4 asserts |
| `tests/arch` | 4/4, 17998 asserts |
| `tests/content` | 157/157, 12760 asserts |
| `tests/e2e/test_e2e_seeker_combos.gd` | 1/1, 15 asserts |

Not run: seed-loop tests, `seams.sh`, the full suite (GitHub runs them).

**Goldens moved: none.** `tests/golden` (test_replay_ground_plane) passed with no digest regenerated; no golden includes a Seekers build.

**forms_dps** (`godot --headless --path . -s scripts/balance/forms_dps.gd`, floor 5, crit off, no elements). Orbs: single 930, line 335, pack 330.
Plain Seekers: single 628, line 223, pack 223 (x0.675 / 0.666 / 0.676 of the orbs; before 558 / 198 / 198). Ratios against plain Seekers (raw table rows in the script output; ratio = card dmg / plain dmg):

| Cards | single x | line x | pack x | single / line / pack dmg |
|---|---|---|---|---|
| (plain) | 1.000 | 1.000 | 1.000 | 628 / 223 / 223 |
| Twin | 1.199 | 1.202 | 1.197 | 753 / 268 / 267 |
| Halo | 0.333 | 0.332 | 0.336 | 209 / 74 / 74 |
| Ring | 1.299 | 1.300 | 1.798 | 816 / 290 / 401 |
| Pierce | 1.000 | 3.032 | 1.332 | 628 / 676 / 297 |
| Ricochet | 1.000 | 1.000 | 1.000 | 628 / 223 / 223 |
| Echo | 1.500 | 1.498 | 1.498 | 942 / 334 / 334 |
| Big Shot | 1.333 | 1.332 | 1.332 | 837 / 297 / 297 |
| Rapid Fire | 1.083 | 1.081 | 1.085 | 680 / 241 / 242 |
| Split | 0.998 | 1.704 | 1.700 | 627 / 380 / 379 |
| Mine | 0.998 | 1.000 | 0.996 | 627 / 223 / 222 |
| Orbit | 1.006 | 0.664 | 1.027 | 632 / 148 / 229 |

Twin x1.20, Rapid Fire x1.08, Echo x1.50 now match the percentages. Big Shot is x2.0 a dart but two darts replace three (x1.333 a volley). Nothing exceeds x2.0
single or x6.0 pack (largest: Pierce line x3.03, Ring pack x1.80). Other forms' rows in the same run are unchanged by this step (only the Seekers path was edited).
