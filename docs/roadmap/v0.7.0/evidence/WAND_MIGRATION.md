# WAND_MIGRATION: do the v0.6 cards leave the offers, do old saves load and map, and does the legendary tier offer level-5 wand cards?

- **Status:** RUN (agent: lint and the tests of the touched folders and their e2e; NOT the full suite, which is the
  lead's one run per wave)
- **Build:** the code of `ea03123` on the agent's branch `wn5b` (cut from `claude/lucid-fermat-9wv2tf` at `4787b38`;
  WIP commits `dc123ca` … `ea03123`, then this step's commit, docs only); Godot `4.7.2.stable.official.ed1daf0bf`; OS
  Linux 6.18 (cloud container)
- **Date:** 2026-10-12
- **Who ran it:** agent

Design: [`../../../design/WAND.md`](../../../design/WAND.md) "What happens to the v0.6 cards" (owner G1 "Approve all";
the mapping table is there). Contracts: [`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8i;
[`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md) "v0.6.5 WN5b". PLAN rows W4, W7.

## What was built
- **One table** (`data/wand/migration.tres`, `WandMigrationDefinition`, category `wand`): 43 retired v0.6 cards, each
  with its Blade-run and Gun-run target (or none: a refund). Validated (sizes, duplicates, unknown ids, a target that
  is itself retired); `pending` lists the targets WN5a brings (`shared_bleed`, `shared_explosive`).
- **Retired = never offered:** `ItemTable.retired` / `AbilityTable.retired` (compiled from the table);
  `ItemPool._usable` (altars, chests, the shop, events, cores, the legendary tier) and `Abilities.can_take` (altars,
  the shop, events, the overrun) refuse them. Nothing deleted: indices and old saves resolve; `World.add_item`,
  `Abilities.grant` and the dev panel still take them.
- **The migration** (`WandMigration.run`): at `Abilities.start_floor` (a carry) and after a save's snapshot is written
  (`Main._start_floor`). Each retired card becomes its target in its place in the wand; a target held or met twice
  levels up (levels add: an ability its level, a legendary version 5, else 1; at most 5); no target → refunded at the
  shop's salvage price on that floor (`ShopTable.sell_price` by rarity: 12 / 22 / 36 shards on floor 1 for a common,
  rare, legendary/epic mod; `ability_refund_per_level` 10 a level for an ability). The payload stays version 4 (the
  migration reads the content, not the version).
- **v0.6.1 saves load again:** `World.tuning` (keen-volta's dev panel Step 6) was missing from v0.6.1 snapshots, so
  `WorldSnapshot.apply` rejected them ("World.tuning: not in the snapshot"); it is in `ADDED_SINCE_V05` now.
- **The legendary tier:** `LegendaryDefinition.wand_level` 5: the boss's altar offers every wand card of the run's
  pool besides the legendary stat cards; a pick there takes it at level 5 (`BossReward.on_pick`); the card reads
  "Mod · Level 5 · Legendary" (`WorldReader.legendary_card_level`, `PickPanel.legendary_face`). Three legendary
  triggers (`trigger_on_hit_twice`, `trigger_on_kill_twice`, `trigger_on_end_twice`; `ModifierOpDefinition.hook_casts`
  2, 0.15 s apart: the cast repeats), indexed after every pool. The pick of 3 and its 60 / 40 weights are unchanged.
- **Names:** the old Blink card `afterimage` is "Blink Echo" / "Eco del Salto" (B12 keeps "Afterimage"); the old
  ability `orbit_blades` is "Orbiting Copies" / "Copias orbitales" (B15 keeps "Orbit Blades"); Razor Orbit's text with
  it. 6 new strings (the triggers, en + es).
- **Recorded old saves** (`tests/fixtures/saves/`): two payload-3 saves made by v0.6.1's own code (main `950add4`,
  exported with `git archive 950add4`, imported, then the script below), used by `test_old_saves.gd` and
  `test_e2e_old_save.gd`.

## The mapping (summary; the full table is WAND.md's)
Kept their ids: Echo Slash (B2), Halo Shot (G16), Boomerang (G9), Orbit Rounds (G10), Split Shot (G5), Wide Arc (B1),
Long Shadow (B12), Blade Orbit (B15) (WN3/WN4); Ember Core (S1), Storm Core (S2), Frost Core (S3), Venom Core (S4),
Gravity Well (S6) (WN5a, lead's message 2026-10-12). Retired with a target: Long Edge → B1; Twin Arc → B5; Ember Edge,
Cinder Shot, Inferno Core (lvl 5), Flame Trail → S1; Static Chain, Conductor, Tempest Core (lvl 5), Arc Field → S2;
Glacial Edge, Frost Nova → S3; Serrated Edge, Barbed Bolts, Razor Orbit → S5; Aftershock → S7; Bomb Lobber, Bomb
Rounds, Cluster Payload → S7 (Blade) / G12 Mine (Gun); Splinter Shot → G4 (Gun); Rapid Coil → G2 (Gun); Ricochet Core →
G7 (Gun); Overcharge → B14 (Blade); Twin Cast → B5 (Blade) / G14 (Gun); Rearguard → G15 (Gun); Seeker → G8 (Gun);
Ascension → G13 (Gun); Echo Storm → B2 at level 5 (Blade); Orbit Blades (ability) → B15 (Blade) / G10 (Gun). Retired
with no row (refund): Overclocked Drone, Blink Echo (old Afterimage), Edge Rounds, Shock Circles, Shatter, Phase Dash,
Ember Trail, Aether Shell, Resonance, Heat Sink Rounds, Meltdown Edge, Mirror Drone, Short Fuse, Drone Buddy.

## Commands and raw outputs
Lint (on `ea03123`):
```
gdformat --check src scripts tests && gdlint src scripts tests
682 files would be left unchanged
Success: no problems found
```

Content, arch, the goldens and the application tests (on `ea03123`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application -ginclude_subdirs -gexit
REPLAY| final=70ac7ca24761c818e8e103b4281da76358e98e880d80ff54754adefa0bfd0add
Tests               150
Passing Tests       150
Time              34.979s
exit 0
```

The e2e tests that reach what changed (main.tscn, real input; on `ea03123`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_rewards.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_card_pool.gd,res://tests/e2e/test_e2e_shop.gd,res://tests/e2e/test_e2e_arenas.gd,res://tests/e2e/test_e2e_events.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_swap.gd,res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_wand_blade.gd,res://tests/e2e/test_e2e_gun_pool.gd,res://tests/e2e/test_e2e_modifiers_mx4.gd,res://tests/e2e/test_e2e_abilities.gd,res://tests/e2e/test_e2e_abilities_ab.gd,res://tests/e2e/test_e2e_utility.gd,res://tests/e2e/test_e2e_combo.gd,res://tests/e2e/test_e2e_curses.gd,res://tests/e2e/test_e2e_after_boss.gd,res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_hud_style.gd,res://tests/e2e/test_e2e_dev_panel.gd -gexit
Tests                48
Passing Tests        48
Time              221.748s
exit 0
```

Presentation and the dev panel (on `ea03123`; the pick panel's line and the frames changed):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation,res://tests/unit/debug -ginclude_subdirs -gexit
Tests               423
Passing Tests       423
Time              282.249s
exit 0
```

The whole `tests/unit/sim` folder (on `ea03123`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit
    blade pool: 55 in the data + 0 planned ([]) = 55
    gun pool: 53 in the data + 0 planned ([]) = 53
    wand smoke: 1392 runs (87 cards × 8 slots × 2 weapons)
Tests               887
Passing Tests       887
Time              3221.399s
exit 0
```

An earlier `tests/unit/sim` run (on `c17440c`, the 48-row table before WN5a's ids) failed 12 tests, all counts and
expectations of the shipped data that now hold retired cards (`test_abilities` "a level-up still applies",
`test_build_slots` the shop swap with Ember Edge, `test_card_pool` "once owned" ×4, `test_gun_pool_order` Seeker / Twin
Cast / Rearguard in the Blade pool, `test_items` / `test_items_j` pool sizes and item count, `test_modifier_smoke`
79 → 82, `test_mx4_engine` "the boss's tier draws it" (Inferno Core), `test_wand` the old cards in its fixtures). Each
was updated to the new data (retired cards never offered; counts derived from the run) and the run above is after it.
The first e2e run also failed `test_e2e_wand_build.gd` (its floor-3 save held old cards, which now migrate to fewer
cards) and left `test_e2e_abilities.gd` pending (an altar's ability card is now always Blink or Aegis); both updated.

The card pool, measured (`test_card_pool_reach.gd`):
```
WN5b alone (on 7e1f287):
    blade pool: 55 in the data + 0 planned ([]) = 55
    gun pool: 53 in the data + 0 planned ([]) = 53
A trial merge of WN5b (7e1f287) with WN5a (7e88f80), conflicts in wand_compile / item_pool / the survey resolved by
taking both sides, not committed:
    blade pool: 61 in the data + 0 planned ([]) = 61
    gun pool: 59 in the data + 0 planned ([]) = 59
```
`POOL_MAX` 88 → 61. The owner's target was 40–50; the rest is the owner's call (PROGRESS "Gates").

The recording of the old saves (v0.6.1's tree from `git archive 950add4`, imported; the script
`record_old_saves.gd` run in that tree, not committed: it builds `SaveLab` floors, takes the cards with
`BuildSlots.take` and writes `RunSaveStore.encode(RunSaver.payload_of(...))`):
```
REC_OUT=<scratch> godot --headless --path v061 -s record_old_saves.gd
RECORDED v061_blade_floor1.save version=3 floor=1 build=blade slots=[&"long_edge", &"orbit_blades", &"ember_core", &"twin_cast", &"drone_buddy", &"echo_storm"] levels=[1, 2, 1] shards=100 hash=d360cd53341567715cd4f00f1398575d0855d6790cbfa91cf1d3f1709aa2ad99
RECORDED v061_gun_floor2.save version=3 floor=2 build=gun slots=[&"splinter_shot", &"seeker", &"bomb_lobber", &"cluster_payload", &"storm_core", &"rapid_coil"] levels=[1, 2] shards=60 hash=7ebbcd120f46f78aca248696b3c5128b738607acedc905c7deded53543c899ad
sha256sum *.save
7f55e759983b93d3ebd23f6cf348dd879237391e7d2307a09f2a29f6e3e3a4c1  v061_blade_floor1.save
fc2214a1884784ad0b2d21ef657791da618f79f265d31cb9919a6ae1d006f940  v061_gun_floor2.save
```

## What the tests assert
- `test_wand_migration_validation.gd` (content, 4): the table is valid with 43 rows; every v0.6 slot card has a row or
  kept its id; every target fits its weapon; a bad table is reported.
- `test_wand_migration.gd` (sim, 12): 37 items and 6 abilities retired, the kept ids not; no altar, chest, legendary
  altar, shop stock, overrun or core offers a retired card over 12 seeds × both weapons; a direct grant still takes
  one; Blade and Gun builds map in pick order with levels and refunds; a held target levels up; a pending target maps
  once it exists; deterministic, idempotent, nothing without the wand table; a carry migrates at the floor's start; the
  legendary tier offers the run's wand cards and the legendary triggers (40 seeds); a wand card taken at the legendary
  altar is level 5 and an altar's is level 1; On Hit ×2 files two casts (delays 0 and 9 ticks) and lands more child
  hits than On Hit, replaying exactly.
- `test_old_saves.gd` (application, 3): the two recorded v0.6.1 saves decode, fit the floor, and map: Blade
  `[wide_arc, blade_orbit, ember_core, double_slash, echo_slash]` levels `[1, 2, 1, 1, 5]`, the Drone refunded; Gun
  `[gun_spread, gun_homing, gun_mine, storm_core, gun_rapid_fire]` levels `[1, 1, 3, 1, 1]`, no refund; idempotent; the
  run plays on.
- `test_e2e_old_save.gd` (main.tscn, 1): the recorded Blade save in the store, Continue focused, Enter resumes it; the
  wand reads as above; the shards are the save's plus the Drone's refund; the run goes on.
- `test_e2e_arenas.gd` (updated): when the legendary altar's first card is a wand card, its line says "Level 5" and
  taking it gives level 5.

## Goldens
None changed, none regenerated. The replay golden passed (above, final `70ac7ca2…`); the MX1 equivalence fixture
in the sim folder run. New fixtures (not goldens): the two recorded saves.

## Merge notes for the lead (WN5a)
- On the trial merge the recorded v0.6.1 saves failed to load again: WN5a's new state fields
  (`ItemMods.bleed_move_period_ticks`, `ModifierState.cast_tick` / `cast_key` / `cast_pos` / `cast_angle` /
  `cast_flag`) are missing from old snapshots. Adding them to `WorldSnapshot.ADDED_SINCE_V05` made
  `test_old_saves.gd` and `test_e2e_old_save.gd` pass on the trial merge (4/4). Not committed here (the fields don't
  exist on this branch).
- Conflicts: `WandCompile._cut` (keep this branch's `casts` loop and add WN5a's `WandCasts.TAG_CAST` inside it),
  `ItemPool._usable` (keep the `retired` check, drop the trigger skip as WN5a did), `card_pool_survey.gd` (keep the
  `retired` skip, drop the trigger skip); counts in the item/modifier tests, strings.csv (both sides), PLAN/PROGRESS.

## Known limits (honest list)
- The 13 passives outside the wand (Bulwark, Cold Snap, Executioner, Heat Sink, Kinetic Dash, Meltdown, Momentum, Phase
  Strike, Swift Feet, Thermal Edge, Thorn Mantle, Vampiric Core, Wildfire) are not in the table: WAND.md doesn't name
  them (WN5a suggested Cold Snap → Frost, Wildfire → Fire; left for the owner).
- With the six abilities retired, an altar's guaranteed first "new ability" card is now always Blink or Aegis until
  one is taken (`Offers.draw`); after that altars offer no ability card but the weapon's level-ups. Not changed.
- A held retired card's level-ups are no longer offered either (lab/dev-panel builds only; a real run migrates it).
- The legendary triggers' look is WN5a's trigger look; no own art. Their numbers (2 casts, 0.15 s) are starting values.
- Screenshots of the "Level 5" legendary card: NOT YET RUN. Full suite, export smoke, tour: NOT RUN.
- `tests/MIN_TEST_COUNT` not raised (the lead's, after the full run).

## Owner only
Which old cards map where (the table), the refund value, the legendary level and triggers, the pool size (61 / 59 vs
the 40–50 target): `OWNER ONLY`.
