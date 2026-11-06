# Evidence: v0.9.5 Step EE2 (Fire, Lightning and Frost levels)

Base build SHA: `679af4df` (branch `v095-ee2`, cut from `claude/v095-feedback` HEAD, before the EE2 commit). Machine: owner's
PC, Windows 11, Godot 4.7.2 headless, `--fixed-fps 60 --language en`. Each run used its own `APPDATA`; up to five Godot
processes ran at once (other agents' too), so the wall times below are noise and not recorded.

## What was built
- `src/sim/items/element_levels_fsf.gd` (new, `ElementLevelsFsf`): the Lv 2 and Lv 3 behaviours. Numbers are the cards'
  (`data/items/ember_core.tres`, `storm_core.tres`, `frost_core.tres`, `el_*` fields, validated in
  `ItemDefinition._check_element_levels_fsf`, each element's set must come whole). The three cards' modifier `per_level`
  is now 0 (Lightning's hook share too; its Lv 1 value 500 is kept).
- **Fire.** Lv 2 Wildfire: `Attacks._zone` makes the patch of the `ember_core` hook 1.5 x wider (1.2 m -> 1.8 m) and 60
  ticks longer (120 -> 180); the view reads the patch radius, so the existing fire patch view scales by itself (its fade
  length follows: `ElementAbilities._fire_life`). Lv 3 Heat sync: `Damage.hit` multiplies a hero hit on a burning enemy by
  1150/1000 (after Overclock's multiplier; a burn tick never comes through `Damage.hit`). Rounding: `amount * m / 1000`.
- **Lightning.** Lv 2 Fork: `Attacks._seek` and `_chain` read `ElementLevelsFsf.fork_reach` (4.0 -> 5.5 m) and
  `fork_chains` (1 -> 2). Lv 3 Overcharge: `Attacks.run_hook` calls `ElementLevelsFsf.overcharge` after the chain hook
  launched; the 6th such hook launch (`World.el_chain_hits`) strikes the hit enemy: `enemies_near` 1.5 m, damage =
  2 x the hit's base damage, TAG_AREA, through `Damage.hit` (so it never chains), proc 50.
- **Frost.** Lv 2 Frostbite: `Damage.hit` multiplies a hero hit on a frozen enemy by 1250/1000. Lv 3 Shatter: a hero hit
  that found its target frozen (read at the top of `Damage.hit`, so the hit that freezes does not shatter) breaks the
  freeze and sends one shard each to the 3 nearest other enemies within 3 m (`Engines.nearest_enemies`), each
  `max(1, hit * 500 / 1000)`, TAG_SHRAPNEL, a 45-tick slow. Shard hits carry `EFFECT_FROST_SHARD`, which `Damage.hit`
  treats as already scaled (as an Overkill splash), so the damage stat is not applied twice and Heat sync/Frostbite do
  not stack on a shard.
- **Budgets** (`World.el_strike_log`, `el_shatter_log`: the ticks of the strikes and shatters of the last 60 ticks;
  4 each). Saved in the snapshot (`ADDED_SINCE_V05`, so an older save keeps the empty base value), hashed together with
  `el_chain_hits` only while Lightning or Frost runs at Lv 3. Fire adds no state. Lv 1 and Lv 2 hash exactly as before.
- **View** (`status_visuals.gd`, `WorldReader.element_plus`): a small "+" (a bigger billboard dot beside the bar, orange
  for a burning enemy at Fire Lv 3, ice blue for a frozen one at Frost Lv 3); an Overcharge strike = a storm line from
  3.5 m above plus a storm burst of the strike's radius (new look) or a bolt and a ring (old look); a Shatter = the
  existing frost burst; each shard = a frost line from where the ice broke to the enemy it hits. All go through the
  effects layer's pooled `line` and `burst` (their caps, merge and Effects density); nothing new is pooled.
- **Sound**: existing cues only, from `audio_events.gd` on the STATUS_APPLY event: `arc_field` for a strike,
  `frost_nova` for a shatter. No new wav.
- New events on `SimEvent`: `EFFECT_STORM_STRIKE`, `EFFECT_FROST_SHATTER`, `EFFECT_FROST_SHARD`.

## Finding: Wildfire already lights what stands in the ground
The brief's Lv 2 line "set enemies that walk through them burning (one burn application per enemy per patch per second)"
is already today's behaviour: the patch's child spec carries a burn status and `Attacks._feed` applies it on every patch
hit, once per enemy per 0.5 s (`period_seconds = 0.5` in `data/modifiers/ember_core.tres`). So Lv 2 adds nothing there;
it adds the width and the life (a test shows an enemy at 1.6 m is lit at Lv 2 and not at Lv 1). Not added on top, to keep
Lv 1 exactly as it is and avoid a second burn source. Owner call if a separate rule is wanted.

## Text lengths (content test caps a description at 60)
| Key | en | es |
|---|---|---|
| `ITEM_EMBER_CORE_DESC` | 52 | 56 |
| `ITEM_STORM_CORE_DESC` | 51 | 54 |
| `ITEM_FROST_CORE_DESC` | 46 | 51 |

No change from the brief's text. The Lightning lines contain a comma, so both fields are quoted in the CSV.

## Commands and raw totals
```
APPDATA=<own> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://<file>[,...] -gexit --language en
```
| Run | Result |
|---|---|
| `tests/unit/sim/test_element_levels_fsf.gd` (new) | 17/17: Lv 1 pins (patch 1.2 m / 120 ticks, plain hits, 2 chain hits, a 4.5 m gap not crossed, no count, no shatter), Wildfire 1.8 m / 180, Heat sync x1.15 at Lv 3 only and not on burn ticks, Fork +1 jump and +1.5 m (4.5 m crossed, 6 m not), Overcharge on the 6th hit (2 enemies in 1.5 m hit for exactly 2 x the bolt hit, one out at 2.6 m), strikes 4 a second, Frostbite x1.25 at Lv 2 and 3, Shatter (3 nearest, not the 4th at 3.4 m, 50 %, TAG_SHRAPNEL, slow, a frozen neighbour not shattered again), the freezing hit not shattering, shatters 4 a second, determinism, hash gating, snapshot round trip |
| `tests/e2e/test_e2e_element_levels_fsf.gd` (new, main.tscn, real input) | 1/1: "10 shatters, 10 shards on the neighbour, 0 bolts on it" (Frost taken at the altar with the real E key, then twice with the dev panel's Grant, Lv 3; a dummy shot with the shoot button held) |
| `tests/unit/presentation/test_status_visuals.gd` | 7/7 (a new test for the "+" and the three events) |
| `tests/e2e/test_e2e_element_levels.gd` (EE1) | 1/1 |
| `test_wand_shared`, `test_modifier_equivalence`, status visuals, the two new files (final run, after the last import) | 38/38 |
| `tests/content/`, `tests/golden/`, `tests/arch/` (final run, after the last import) | 163/163 (33 scripts) |
| batch A: engines, thermal_break, items, items_j, combos, damage, abilities, abilities_ab, modifier_abilities, modifier_equivalence, card_levels_clv, mx4_engine, mx4_modifiers(_2), modifiers | 199 tests, 197 pass, 2 fail (below) |
| batch B: wand_shared(+order), wand_compile, wand_migration, wand, wand_preview, affinities, attack_slots, build_slots, stress_marks, remnants, player_builds, card_pool_reach, loot_pacing, element_levels_venom_bleed, world_snapshot, heat, gun_heat_fill, old_saves | 228 tests, 222 pass, 6 fail (below) |
| `test_wand_migration.gd -gunit_test_name=test_the_legendary_tier` alone | 1/1, 245 s on the busy machine (80 floors) |
| batch D: world_snapshot, old_saves, venom_bleed, the new file, status_visuals, heat, loot_pacing | 87 tests, 86 pass, 1 fail (loot_pacing, below) |

## Existing tests changed
- `tests/unit/sim/test_wand_shared.gd::test_each_shared_card_levels_up_without_a_slot_and_grows`: Fire, Lightning and Frost
  expected the spell digest to change per level (Fire's patch +5 %, Lightning's hook +10 %, Frost +5 % damage). Their
  levels are behaviours now, so every card of the list expects the same digest, the same bolt damage and the same hook
  share at Lv 2. The EE1 exemption for Venom and Bleed became the rule for all five. Nothing else was edited.

## Changed digests and goldens
None. `test_modifier_equivalence` passes unchanged (3/3): the Lv 1 digests of the three cards did not move. No golden
changed.

## Failures not caused by EE2 (pasted from the runs, not fixed; not run on a clean base)
- `test_items_j::test_the_data_has_distinct_kinds` (117 vs 116 items) and `test_the_pool_draws_every_item_without_repeats`
  (59 vs 64): item counts; EE2 adds no item (the Rune Explosion of FC0 is the 117th).
- `test_wand_compile` (`[2]` vs `[3]`, "x3 of one shot"): Halo/Split Shot, the same two failures EE1 listed.
- `test_remnants` (level 3 threads `[6]` vs `[10]`, "6 cracks at most", "the oldest was replaced"): remnant card levels (CLV).
- `test_card_pool_reach` ("ability:pulse_gun is offered somewhere") and `test_loot_pacing::test_a_held_card_at_the_floors_ceiling_is_offered_no_more`
  (`gun_big_shot` at its ceiling): pool and level-ceiling rules (CLV). EE2 touches no offer code.

## Not run
`test_five_floors.gd`, `test_curse_room.gd`, `test_modifier_smoke.gd` (excluded by the brief); the full suite (GitHub).
`tests/e2e/test_e2e_old_save.gd`. No frame-time probe or 20-enemy soak was run (the budgets are unit-tested: 4 strikes and 4
shatters a second); the soak with two Lv 3 elements on the owner's PC is `NOT YET RUN (owner hardware)`. Look and feel of
the "+", the bolt and the shards: OWNER ONLY (no screenshot taken).
