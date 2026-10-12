# WAND_GUN: does the Gun pool (G1–G16) rebuild the bolt left to right, show on it, level up and stay in Gun runs?

- **Status:** RUN (agent: lint and the tests of the touched folders and their e2e; NOT the full suite, which is the
  lead's one run per wave)
- **Build:** the WIP commits `13c9483` … `9e09b3b` and this step's commit on the agent's session branch (cut from
  `claude/lucid-fermat-9wv2tf` at `fb7dab3`); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18 (cloud container)
- **Date:** 2026-10-12
- **Who ran it:** agent

Design: [`../../../design/WAND.md`](../../../design/WAND.md) (owner "Approve all", PLAN W7). Contracts:
[`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8f; [`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md)
"v0.6.5 WN3: the Gun pool".

## What was built
| # | Card (id) | The rewrite (starting values) | What shows on the bolt |
|---|---|---|---|
| G1 | Big Shot (`gun_big_shot`) | radius × 2, speed × 0.75, flight × 1.333 (range kept), damage × 1.6; per level + 0.1× radius and damage | a thicker, heavier dart (radius, weight 1.3 width) |
| G2 | Rapid Fire (`gun_rapid_fire`) | radius × 0.6, rate + 600 ‰ (+150 a level), damage × 0.7 | many small bolts |
| G3 | Twin (`gun_twin`) | `twin` + 1: each bolt fires with a parallel twin 2.6 radii apart; + 10 % damage a level | paired bolts (cue `twin`) |
| G4 | Spread (`gun_spread`) | count + 2, spread + 30° (+2, +10° a level) | a fan |
| G5 | Split (`split_shot`, id kept) | ON_HIT: 3 bolts of 0.08 m (half the bolt) at 50 % (+1 a level) | shards at the hit |
| G6 | Pierce (`gun_pierce`) | pierce + 2 (+1 a level) | streak cue |
| G7 | Ricochet (`gun_ricochet`) | bounces + 2 (+1 a level) | bounce flashes |
| G8 | Homing (`gun_homing`) | homing + 360°/s (+90 a level) | curved trails (live trail) |
| G9 | Boomerang (`boomerang`, id kept) | returns; + 10 % damage a level | the loop, a tether |
| G10 | Orbit (`orbit_rounds`, id kept) | 0.5 s round you first; + 10 % a level | a ring, then a volley |
| G11 | Spiral (`gun_spiral`) | `spiral` 35°: heading swings ± 35° × cos(2π age / 24 ticks); + 10 % a level | a helix (live trail, cue `helix`) |
| G12 | Mine (`gun_mine`) | stops where its flight ends, waits 3 s (+0.5 s a level); ON_END burst 1.2 m at 100 % (+10 % a level), effect `gun_mine` | still bolts with a ground ring (cue `mine`) |
| G13 | Charge (`gun_charge`) | hold SHOOT to charge up to 1 s; release (or full charge) fires × up to 3 size and damage (+0.25× a level) | an orb swelling at the muzzle; the shot drawn at its own radius |
| G14 | Echo (`gun_echo`) | again after 0.3 s at 60 % (+10 % a level) | a second volley |
| G15 | Backfire (`gun_backfire`) | back copy at 100 %; + 10 % a level | shots both ways |
| G16 | Halo (`halo_shot`, id kept) | count × 3 (+1× a level), circle, range × 0.5 | a ring of shots |

- **Order:** every card is ops through WN1's left-to-right compile; nothing order-specific was hand-written. The
  tests below show where order matters (a child-building card: Split, a trigger) and where it doesn't (two cards
  rewriting the one bolt).
- **Runner features** (`src/sim/combat/gun_forms.gd`, new): twin lanes (`Attacks._bolts`, small additive edit),
  spiral and mine (two new `ProjectileStore` columns, `ProjectileMoves.steer` calls in), charge (`PlayerKit` shot
  block, `ModifierState.hold_t`, `AttackContext.size_permille`). Spec fields appended to `AttackSpec.INT_FIELDS`.
- **Levels 1–5** (`src/sim/abilities/card_levels.gd`, new; `World.card_levels`): an item tagged `wand` levels up
  when taken again (no slot, no swap), stays offered below 5 (altars, chests, shop, events, cores, the dev panel's
  grant), compiles at its level (`ModifierOpDefinition.per_level` → `ModifierTable.at`), carries across floors and
  snapshots, counts in `CatchUp.power`.
- **Pool:** `requires_weapon` gun on all 16; 12 new items of a new kind `WAND` (indices after the triggers, so saves
  keep their codes). Seeker, Twin Cast, Rearguard became Blade-only (their Gun job is G8, G14, G15); no card deleted.
- **Views:** `AttackFormLooks.cues_of` (`twin`, `helix`, `mine`, `swell`), `AttackFormView._sync_charge` and
  `live_scale`, the canvas's mine ring; `WorldReader.projectile_radius`, `gun_charge`. Card frames for the 12.
- **Strings:** 24 new keys (en + es), 7 edited (Split, Halo, Orbit names; their descriptions, Boomerang's).

## Commands and raw outputs
Lint (final tree):
```
gdformat --check src scripts tests && gdlint src scripts tests
649 files would be left unchanged
Success: no problems found
```

The whole `tests/unit/sim` folder (started on `0f6e87f`; the docs and one content validation came after, nothing in
`src/sim`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit
    gun pool: 86 in the data + 0 planned ([]) = 86
    blade pool: 76 in the data + 0 planned ([]) = 76
    wand smoke: 1152 runs (72 cards × 8 slots × 2 weapons)
Tests               846
Passing Tests       843
Failing Tests         3
Time              3092.971s
exit 1
```
The three failures, pasted (`[Failed]` lines):
```
[60] expected to equal [48]:  the v0.3.0 pool of 24 + the M-list's 24 usable here (v0.6.0 MX4: no heat, no ability, no legendary)
[60] expected to equal [48]:  no repeats
[55] expected to equal [43]:  48 - owned - 4 placed
[67] expected to equal [55]:  the 14 migrated attack items (MX1), ...; v0.6.5 WN1: 4 triggers
ARRAY(["barbed_bolts", "bomb_rounds", "boomerang", "cinder_shot", "gun_backfire", "gun_big...c_chain"]) != ARRAY(["barbed_bolts", "bomb_rounds", "cinder_shot", "rapid_coil", "ricochet_core", "splin...c_chain"]).
ARRAY(["bulwark", "conductor", "echo_slash", "echo_storm", "ember_edge", "glacial_edge", "...in_cast"]) != ARRAY(["bulwark", "conductor", "echo_slash", "echo_storm", "ember_edge", "glacial_edge", "...win_arc"]).
```
All are counts and lists of the shipped data (`test_items.gd` pool sizes, `test_modifier_smoke.gd` modifier count,
`test_player_builds.gd` weapon tags), now holding the Gun pool. Updated in `9e09b3b` and the three files run again:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_player_builds.gd,res://tests/unit/sim/test_items.gd,res://tests/unit/sim/test_modifier_smoke.gd -gexit
Tests                44
Passing Tests        44
Time              153.982s
exit 0
```
The sim folder was not run again as a whole after `9e09b3b`. Before that run, the same kind of count fixes were made
and checked file by file (`test_items_j.gd`, `test_rewards.gd`, `test_card_pool_reach.gd`, `test_wand.gd`,
`test_wand_compile.gd`); those passed inside the folder run above.

The new tests alone (on `0f6e87f`): `test_gun_pool.gd` 19/19, `test_gun_pool_order.gd` 12/12 (both also inside the
folder run).

Content, arch, the goldens and the application tests (final tree, `9e09b3b` + docs):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application -ginclude_subdirs -gexit
REPLAY| final=70ac7ca24761c818e8e103b4281da76358e98e880d80ff54754adefa0bfd0add
Tests               140
Passing Tests       140
Time              30.358s
exit 0
```

Presentation (started on `0f6e87f`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Tests               392
Passing Tests       392
Time              415.383s
exit 0
```

The e2e tests that reach what changed (main.tscn, real input; on `d3b9b71`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_gun_pool.gd,res://tests/e2e/test_e2e_swap.gd,res://tests/e2e/test_e2e_modifiers_mx4.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_attacks.gd,res://tests/e2e/test_e2e_kit.gd,res://tests/e2e/test_e2e_rewards.gd,res://tests/e2e/test_e2e_hud_style.gd,res://tests/e2e/test_e2e_combo.gd -gexit
Tests                26
Passing Tests        26
Time              162.15s
exit 0
```

## What the tests assert
- `test_gun_pool.gd` (19): each of G1–G16's compiled rewrite and its effect in a scripted Gun scene (a big bolt in
  flight at radius × 2 and its damage; more spawns a second with Rapid Fire; two parallel bolts 2.6 radii apart; a
  3-bolt fan; 3 half-size shards at the hit; one bolt through three enemies in a line; a bolt off a wall with one
  bounce left; a bolt turning into an enemy off its line; out and back to the player; round the player then out; a
  bolt swinging to both sides of its line, crossing it, while it flies on; a mine still at its flight's end that a
  touch sets off (blast hits) and that, untouched, waits its 3 s; a charge with no shot while held, × 2 at half
  charge on release, × 3 by itself at full; an echo 18 ticks later at 60 %; a back copy that hits behind; a ring of
  3); every card changes the AttackScenario fight's events and replays exactly; the view's look per card (width,
  count or cue).
- `test_gun_pool_order.gd` (12): Big·Split vs Split·Big (shards 0.08 vs 0.16 m, weight 1000 vs 1600, different
  fights); Spread·Homing = Homing·Spread (same spec fields and the same fight events: two rewrites of one bolt
  commute) while Split·Homing ≠ Homing·Split (only the first's shards seek); Spread·Split vs Split·Spread (shards 3
  vs 5); Big·ON HIT·Spread vs Spread·ON HIT·Big; Split·Mine vs Mine·Split; a duplicate levels up with no slot and no
  swap, hashed, read by `Wand.read`; levels stop at 5 and the card leaves the offers (and the shop); each card's
  level step on the compiled bolt; levels through `RunCarry` and a snapshot (equal hashes, playing on the same); a
  snapshot mid-charge with waiting spiralling mines plays on the same; `CatchUp.power` rises with a level; the 16 in
  the Gun's pool and none in the Blade's, Seeker / Twin Cast / Rearguard the other way.
- `test_gun_looks.gd` (4, presentation): the cues; the charge orb drawn and growing while held; `live_scale`; a
  waiting mine's ground ring, never a telegraph hue.
- `test_e2e_gun_pool.gd` (1, main.tscn): a Gun run takes Big Shot then Charge through the dev panel (TEST HELPER
  clicks); the wand holds them in that order; the view's spec read is big and charging; holding right click fires
  nothing and the charge rises past 0.3; the release fires one bolt bigger than Big Shot alone; granting Charge again
  levels it to 2 with no new slot and a higher charge.
- `test_wand_smoke.gd` (WN1's, unchanged): now 72 cards × 8 slots × 2 weapons = 1152 runs, all within the caps and
  replaying.

## Goldens
None changed, none regenerated. The replay golden passed (above, final `70ac7ca2…`); the MX1 equivalence fixture
3/3 in the sim folder run. The export smoke was NOT RUN.

## Known limits (honest list)
- **The pool's ceiling was raised 80 → 90** (`tests/support/card_pool_survey.gd`): the Gun pool measures 86 until WN5
  retires the old cards it duplicates (Splinter Shot, Rapid Coil, Ricochet Core, ...). Written as a gate in PROGRESS
  for the lead / owner; not decided here.
- **Blade's pool lost four cards** (Split Shot, Halo Shot, Boomerang, Orbit Rounds became Gun-only, per WAND.md's
  mapping): 80 → 76. The MX4 e2e that grants Split Shot to a Blade run still passes (the dev panel ignores the pool).
- **Rules that stay root-only** (MX4's): Echo and Backfire act on the shot you fire, not on a trigger's child spell;
  a charged shot's echo is normal size; Charge means nothing right of a trigger (a child is never held).
- A mine's ON_END children leave along angle 0 (a still projectile has no heading).
- Level-up offers show like a new card: the pick panel does not yet say "Level 2" for an item card (WN2's UI).
- `CardLevels` is generic (any item tagged `wand`); WN4's Blade pool can reuse it — merge note for the lead, who
  may see the same mechanism built twice.
- The view's charge orb and mine ring are checked by the presentation tests only; NOT looked at on a renderer (no
  screenshot tour run).
- `tests/MIN_TEST_COUNT` not raised (the lead's, after the full run). Full suite, export smoke, tour: NOT RUN.

## Owner only
Feel, the starting values (every number in the table), the names (en, es), whether Charge should auto-fire at full:
`OWNER ONLY`.
