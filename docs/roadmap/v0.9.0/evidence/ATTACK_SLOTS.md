# v0.9.0 AS: attack slots, categories and one compatibility table (evidence)

Owner rows: Q2–Q7, Q13, Q14 and C36–C67, C78, C87 in [`../PLAN.md`](../PLAN.md); forms in
[`../ATTACK_FORMS.md`](../ATTACK_FORMS.md). Branch `v090-as`, cut from `b6a780b0`. Machine: the owner's PC (Windows 11,
Git Bash, i7-10700K, RTX 3060), Godot 4.7.2; GUT jobs in parallel, each with its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit
-gtest=<files>` (or `-gdir=<dir> -ginclude_subdirs`). Lint: `gdformat` + `gdlint` on every touched `.gd` (clean).

## What was built

- **Data.** `slot_category` on every live wand card (`data/items/*.tres`: form / pattern / secondary / element / free;
  `ItemDefinition.SLOT_CATEGORIES`, not `loot_category`). `data/wand/attack_slots.tres` (`AttackSlotsDefinition`, its
  own file so `wand.tres`'s `slots_per_floor` stays the five-floors step's): Gun limits Form 1 / Pattern 1 /
  Secondary 2 / Element 2, Blade limits Pattern 1 only, 12 shots an attack, 40 a second, the merge's radius cap, and the
  form table with one live row, **Orbs** (no card: the Gun's own shot), every live Gun Pattern, Secondary and Element
  card on (C61 "Orbs: all yes"); a cell not listed is off (C62). `AttackSlotsDefinition.cross_check` (ContentValidator):
  every live wand card names its slot, every table id is a live card of the right category, exactly one default form.
- **Sim.** `AttackSlots` (equip/replace, the form row, compatibility, the old-save trim), `SlotTable` (compiled by
  `WandCompiler.slots`, `World.slot_table`, loadout), `ShotCap` (the caps). `BuildSlots.take` replaces the category's
  card; `needs_swap` asks for the Swap only when the card's slot has room; `ItemPool.usable` drops cards off for the
  form (so altars, chests, the shop, events, cores and the loot pacing never offer one); `Modifiers.build_modifiers`
  never compiles a held card off for the form; `WandCompile` no longer layers a second form (C63); Ring's count-pulses,
  the storm's staggered rings and the spinning group are gone (unreachable with one Pattern).
- **Presentation (G2 option A).** The pick card's slot line (`PickSlot`: the slot mark `SlotGlyph`, the tag, and
  "· [icon] Replaces Twin" in ember), the same face in the shop, events and the Swap panel; the replaced card's chip
  burns with N8's dissolve when the card is picked; the wand tiles add the tag to the level line ("Lv 1 · Pattern");
  the Build page's note counts the slots ("Form: Orbs · Pattern 1/1 · Secondary 2/2 · Element 1/2"). en + es.

## Rules decided (simplest reading; listed for the owner)

| Question | Rule |
|---|---|
| A full Secondary or Element slot (Q5 left it open) | The same as Form/Pattern: the card reads "Replaces <the leftmost card of that slot>", picking it puts it in that card's place and the old card burns. The player picks which one goes by ordering the wand (Build page). |
| The Blade (Q6) | Only the Pattern limit (1) applies; no Form, Secondary or Element limit, and no tag but Pattern shows on a Blade run. Blade Patterns: Wide Arc, Double Slash, Whirl, Thrust (the four the owner named). Every other Blade card is Free (conservative). |
| Gun classification | Patterns: Twin, Halo, Ring, Backfire. Secondaries: Pierce, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Mine, Charge, Orbit, Boomerang, Threadline, Spiral, Swirl. Elements: Fire, Lightning, Frost, Venom, Bleed, Void (`gravity_well`, until VP). Free: triggers, mutations, Faultline, Gravity Stitch, Stress Mark, Chain Blast. |
| Free cards and the table | The table's columns are Patterns, Secondaries and Elements (ATTACK_FORMS.md); Free cards are always allowed. |
| Halo / storm (Q3) | Halo and Ring are both Patterns, so they never share a wand and the Ring · count · Swirl storm can't form. Removed: take_in's pulses (`AttackSpec.ring_pulses`, `PULSES_MAX`, `PULSE_GROW_PERMILLE`), the storm's one-after-another gap, the several-ring spin and the multi-ring share. Kept: Ring · Swirl (thrown its own way) and Swirl · Ring (wobbles along the aim). Saves still load (the ring store's columns stay). |
| Old saves | After `WandMigration`, `AttackSlots.trim` keeps the leftmost cards of each over-full category up to its limit; the rest leave the build and are refunded as shards at the shop's salvage price. Idempotent; runs on a save's resume and at every floor start. |
| 40 a second (Q13) | The 12-per-attack cap alone gives the worst legal builds 270–1693 projectiles a second at the top attack speed (measured below), so the 40 is also a data value enforced in play: the player's own shot always fires; every other shot (a volley's extra copies, Split's shards, Echo's repeat, a trigger's cast) is an extra, and the extras of any 60 ticks stay within 40 − the Gun's fastest shots a second; a volley that doesn't fit merges into fewer, bigger shots carrying its damage. |
| Forms (Q7) | The framework only: the Form category and its table row; one live member, Orbs. A test gives two lab cards rows to prove a form card replaces the form and its table rules the offers and the compile. |

## Tests (raw summary lines)

Final code (after the last edit), raw GUT summary lines:

| Run (`-gtest` / `-gdir`) | Summary |
|---|---|
| test_wand, test_wand_compile, test_combos, test_attack_order, test_attack_slots, test_shot_cap, test_build_slots, test_wand_migration, test_gun_pool, test_gun_pool_order, test_attack_slot_views | `Tests 146 / Passing Tests 146 / Asserts 3490` |
| goldens: test_modifier_equivalence, test_state_hasher, tests/golden/test_replay_ground_plane, tests/arch (layering, sim purity) | `Tests 13 / Passing Tests 13 / Asserts 13097` (no golden moved) |
| test_modifier_smoke (the every-card soak) | `Tests 8 / Passing Tests 8 / Asserts 12188` |
| test_modifier_smoke_mx4, test_wand_smoke, test_wand_order_fight, test_wand_shared(_order), test_wand_blade(_order), test_wand_preview (with test_modifier_smoke before its fix) | `Tests 71 / Passing Tests 70 / Failing Tests 1` (the one: test_modifier_smoke's all-95-cards run, 243 LIMITs vs 241: the player-shot cap's 2 events, now counted as a cap holding; re-run above) |
| tests/content (whole folder) | `Tests 138 / Passing Tests 138 / Asserts 9952` |
| presentation: build_views, card_frames, card_level_views, item_cards, reward_cards, reward_views, shop_views, wand_views, wand_cast_view | `Tests 61 / Passing Tests 61 / Asserts 7798` |
| sim: items, items_j, loot_pacing, loot_rewards, offers, rewards, shop, events, attack_rate; application: run_saves, ascension_saves | `Tests 151 / Passing Tests 150 / Failing Tests 1` (test_ascension_saves `test_an_older_payload_is_loop_one`: "World.walls: the snapshot's floor differs", pre-existing, below) |
| e2e: attack_slots, attack_order, reward_cards, builds | `Tests 13 / Passing Tests 13 / Asserts 128` |
| e2e: saves, old_save, wand_build | `Tests 6 / Passing Tests 5 / Failing Tests 1` (test_e2e_old_save, pre-existing, below) |

The worst legal builds at level 5 and the top attack speed (test_attack_slots, its `gut.p` line):
`AS shots a second: halo_split_rapid 40/s (12-per-attack cap alone: 270/s); hit_then_halo_split_echo 40/s (12-per-attack
cap alone: 300/s); twin_split_echo 40/s (12-per-attack cap alone: 1224/s); ring_split_rapid 40/s (12-per-attack cap
alone: 1693/s); backfire_split_echo 40/s (12-per-attack cap alone: 612/s)`

**Pre-existing failures (not AS):** the v0.6.1 save fixtures no longer restore on `b6a780b0` ("World.walls: the
snapshot's floor differs from the one generated from its inputs"): test_old_saves (2 tests), test_e2e_old_save,
test_ascension_saves `test_an_older_payload_is_loop_one`. The lead's bisect log (`bis_pt`) shows the same failures on
the PT merge `84b541fb`, before AS. AS's own old-save test therefore records its pre-AS save in the test (a run on
floor 2 whose wand holds Twin + Halo and three Secondaries, snapshotted, restored, migrated, trimmed, played).

## G2 mockups (owner picks)

`godot --path . --resolution 1920x1080 -s scripts/shots/mock_attack_slots.gd` (RTX 3060) → `build/shots/v0.9.0/as/`,
copied by hand to [`as_mockups/`](as_mockups/): `<a|b|c>_<pick|build>_<en|es>.png`, 1920 × 1080, seed 5.

- **A (built):** a slot line under the card (mark, tag, "· [icon] Replaces Twin"); tiles "Lv 1 · Pattern"; the note
  counts the slots. Trade-off: the card face is untouched and the line burns on pick; it's small and sits under the card.
- **B:** a ribbon across the card ("REPLACES TWIN") and the tag in the rarity line; pips per slot over the wand.
  Trade-off: impossible to miss, but covers part of the card's art and title area.
- **C:** a corner badge with the tag and a crossed-out mini tile "old → new"; a column per slot under the wand.
  Trade-off: reads by picture without words, but adds the most to the screen (and duplicates A's note on the page).
