# WAND_SHARED: are the shared cards S1–S7 offered in both runs and visible on the spell, are the triggers T1–T4 offered with their final names, and does a trigger's child spell show where it is cast?

- **Status:** RUN (agent: lint, the tests of the touched folders and their e2e; NOT the full suite, which is the
  lead's one run per wave). Screenshots: NOT YET RUN.
- **Build:** the agent's branch `wn5a`, cut from `claude/lucid-fermat-9wv2tf` at `4787b38`; WIP commits `588db57`,
  `5a87ad2` (the code as tested), `18ec475`, `3df5865` (tests and docs only after `5a87ad2`), then this step's commit;
  Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18 (cloud container)
- **Date:** 2026-10-12
- **Who ran it:** agent

Design: [`../../../design/WAND.md`](../../../design/WAND.md) S1–S7, T1–T4 (owner "Approve all", PLAN W7). Contracts:
[`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8h;
[`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md) "v0.6.5 WN5a". Scope split with WN5b (the old cards'
migration, the legendary tier, pruning the pools, `CardPoolSurvey.POOL_MAX`): not touched here.

## What was built
| # | Card (id) | The spell (starting values) | You see |
|---|---|---|---|
| S1 | Fire (`ember_core`, v0.6 card, id and index kept) | burn 1; an `ON_KILL` burst 1.5 m at 60 % (+10 % a level) | ember core and sparks; the kill burst drawn as fire |
| S2 | Lightning (`storm_core`, kept) | an `ON_HIT` seeking beam within 4 m at 50 % that jumps once more: 2 more enemies (+10 % a level) | storm core, the crackle and the chain arcs |
| S3 | Frost (`frost_core`, kept) | slow; frost 1 (threshold 3: the 3rd hit freezes 1 s); + 5 % damage a level | frost core and shards; the frozen enemy |
| S4 | Venom (`venom_core`, kept) | poison 1, spreads on death; + 5 % damage a level | venom core and drip; the drop over a poisoned enemy |
| S5 | Bleed (`shared_bleed`, new `WAND`) | bleed 1 (1 a stack every 0.5 s, **0.25 s while you move**, 4 s, 8 stacks); + 5 % a level | bleed core and its red drip |
| S6 | Void (`gravity_well`, kept; void now on the spell) | an `ON_HIT` burst 2.5 m at 20 % that pulls 0.8 m (+10 % a level) | violet core and smear; the pull burst drawn as void |
| S7 | Explosive (`shared_explosive`, new `WAND`) | an `ON_END` burst 1.4 m at 60 % where the spell ends (+10 % a level), drawn ember | the `blast` cue; the blast at the end |

- **Pool:** all seven `requires_weapon = ""` and tagged `wand` (levels 1–5): offered in Blade and Gun runs. The two
  new cards are indexed in the shared pool (`WAND_POOL_ORDER`'s `""`, after the Blade's), so every earlier item
  index is unchanged. Names in en + es: Fire / Fuego, Lightning / Rayo, Frost / Escarcha, Venom / Veneno, Bleed /
  Sangrado, Void / Vacío, Explosive / Explosivo (the five kept cards' name values edited in place).
- **Triggers:** `ItemPool` offers kind `TRIGGER` in both runs (and `CardPoolSurvey` counts them). Final names: On
  Hit, On Kill, On End; T4 shows **On Finisher** with the Blade and **On Crit** with the Gun (one card, a Gun face:
  `ItemDefinition.name_key_gun` / `desc_key_gun`, `Offers.item_keys`), on the pick cards, the Swap, the Build page and
  the wand's read.
- **The child spell drawn:** WandCompile tags a trigger's child `cast`; `Attacks.run_hook` notes each cast and each
  hook blast or slash no other view draws (`WandCasts`, view data in `World.mx`, not hashed); AttackFormView draws each
  once: a pale-gold sigil and a small ring where the trigger fired, then the small slash or blast from its own spec;
  a cast bolt flies with the `cast` cue (a rim). New cues `cast`, `blast` (`AttackFormLooks`).
- **Order fixes the cards needed** (SIM_CONTRACTS §8h): the v0.5 riders ride only on an engine from outside the wand
  (Fire right of ON HIT no longer burns the slash; Wildfire still does); a child slash feeds its own statuses, not the
  combo step's; a trigger's cast feeds its stacks whole (1 × 50 % was 0, so ON HIT · Fire never burned on the Blade);
  a hook's bolt leaves past the enemy measured from its centre (it spawned inside the enemy and hit it again).

## Commands and raw outputs
Lint (final tree):
```
gdformat --check src scripts tests && gdlint src scripts tests
681 files would be left unchanged
Success: no problems found
```

The whole `tests/unit/sim` folder (on `5a87ad2`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit
    blade pool: 94 in the data + 0 planned ([]) = 94
    gun pool: 89 in the data + 0 planned ([]) = 89
SOAK| kills=265 events=6696 most_in_a_tick=188 limits=0 (watchdog 0, heal cap 0)
    wand smoke: 1376 runs (86 cards × 8 slots × 2 weapons)
Tests               897
Passing Tests       895
Failing Tests         2
Time              3150.184s
exit 1
```
The two failures, pasted (`[Failed]` lines):
```
[94] expected to be between [40] and [88]:  blade: 40-88 cards
[89] expected to be between [40] and [88]:  gun: 40-88 cards
Expected [PACKED_INT32_ARRAY([1, 3, 5, 8, ... 91, 92])] to NOT contain value:  [40]:  a card without levels still leaves once held
```
- `test_card_pool_reach.gd`: the pools now hold the 4 triggers and the 2 new shared cards (blade 88 → 94, gun 83 →
  89) against `CardPoolSurvey.POOL_MAX` 88. **Not changed here** (`POOL_MAX` and the pruning are WN5b's); reported,
  not widened. It passes only once WN5b's pruning lands or the owner raises the bound.
- `test_gun_pool_order.gd`: the test used Ember Core as "a card without levels"; it is S1 Fire now and levels. The
  test now uses Splinter Shot (an unchanged v0.6 card). Run again with the pool test:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_gun_pool_order.gd,res://tests/unit/sim/test_card_pool_reach.gd -gexit
    blade pool: 94 in the data + 0 planned ([]) = 94
    gun pool: 89 in the data + 0 planned ([]) = 89
Tests                15
Passing Tests        14
Failing Tests         1
Time              64.699s
exit 1
```
(the one failure: the pool bound above.) The sim folder holds the new `test_wand_shared.gd` (11),
`test_wand_shared_order.gd` (11), `test_wand_smoke.gd`, `test_modifier_smoke.gd`, `test_modifier_equivalence.gd`: all
passed in it. The sim folder was not run again as a whole after `5a87ad2` (only tests and docs changed since).

Before that run, the count tests the new data moved were updated (`test_items.gd` 73 → 79 drawn, `test_items_j.gd`
91 → 93 items and 72 → 78 drawn, `test_modifier_smoke.gd` 79 → 81 modifiers, `test_wand.gd`'s read-back now "shaped
by Fire" / "por Fuego"), each count written with what it holds.

Content, arch and the goldens (final tree, `3df5865`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
REPLAY| final=70ac7ca24761c818e8e103b4281da76358e98e880d80ff54754adefa0bfd0add
Tests               114
Passing Tests       114
Time              25.152s
exit 0
```
(Its first run, on the first WIP tree, failed 4: two strings over 60 characters, the item and modifier counts 91 /
79, and the engines' member count, which now skips `WAND` cards as it skips `MODIFIER` cards (the rule is the
v0.3.0 items'); fixed before `588db57`.)

Presentation, application and the dev panel's tests (on `18ec475`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation,res://tests/unit/application,res://tests/unit/debug -ginclude_subdirs -gexit
Tests               457
Passing Tests       457
Time              292.573s
exit 0
```

The e2e tests that reach what changed (main.tscn, real input; on `18ec475`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_wand_shared.gd,res://tests/e2e/test_e2e_wand_blade.gd,res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_gun_pool.gd,res://tests/e2e/test_e2e_swap.gd,res://tests/e2e/test_e2e_modifiers_mx4.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_card_pool.gd,res://tests/e2e/test_e2e_rewards.gd,res://tests/e2e/test_e2e_shop.gd,res://tests/e2e/test_e2e_combo.gd,res://tests/e2e/test_e2e_attacks.gd,res://tests/e2e/test_e2e_kit.gd,res://tests/e2e/test_e2e_hud_style.gd,res://tests/e2e/test_e2e_four_slash.gd,res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_events.gd -gexit
Tests                38
Passing Tests        37
Failing Tests         1
Time              174.688s
exit 1
```
The failure: `test_e2e_combo.gd` "the floor's cards hold a combo pair in two rewards". Its TEST HELPER holds every
non-combo item so the floor draws combo items; the five shared cards now level, so held below level 5 they stayed
in the draws. The helper now holds them at level 5 (`CardLevels.set_level`). Run again (`3df5865`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_combo.gd -gexit
Tests                 1
Passing Tests         1
Time              24.324s
exit 0
```

## What the tests assert
- `test_wand_shared.gd` (11): the seven are wand cards of the shared pool, offered in a Blade and a Gun run, named
  Fire … Explosive in en; each shows on both weapons' spell (its element, or Explosive's `ON_END` burst); in scripted
  scenes on both weapons: Fire burns and a kill bursts (`ember_core` damage); Lightning hits 2 other enemies; Frost
  slows, the 3rd hit freezes for ≤ 1 s; Venom poisons and spreads on death; Bleed bleeds and ticks more often in 1 s
  while walking than standing (and `Engines.bleed_period` is the card's 0.25 s moving, v0.5's without the card); Void
  pulls a side enemy > 0.3 m toward the hit; Explosive blasts an enemy just past the slash's tip (the slash never
  reached it) and the Gun's bolt's neighbour, and leaves a burst mark; each levels with no slot (+10 % hook, +5 %
  damage).
- `test_wand_shared_order.gd` (11): Fire · ON HIT · Lightning burns the spell and builds a storm child; ON HIT · Fire ·
  Lightning leaves the spell plain (no rider) and builds a burning ember-then-storm child; in a scene (A where the
  spell hits, B where only the child reaches) the first order burns A and not B, the second burns B (and on the Gun
  not A; the Blade's child slash starts on A and sweeps it); the two orders' fights differ and each replays; Explosive
  left or right of ON END; no rider from a wand card right of a trigger, Wildfire's still rides; a child slash feeds
  only its own statuses; the four triggers offered on both weapons; T4's face (On Finisher / On Crit) in the offer,
  the reader and the wand's read; casts marked where they fire (tagged `cast`, depth 1) with the child's blast;
  marks bounded and out of the hash.
- `test_wand_cast_view.gd` (5, presentation): the cues `cast` and `blast`, the sigil never a telegraph hue; each
  shared card's core colour and particles on both weapons; a Blade ON HIT · Explosive cast draws its sigil, its slash
  and its blast, once each; a Gun cast bolt carries the `cast` cue; Fire's kill burst draws as a burst.
- `test_e2e_wand_shared.gd` (1, main.tscn): a Blade run takes On End then Explosive (dev panel clicks, TEST HELPER),
  the wand reads them in that order with its cut after On End; swinging with the mouse casts small slashes (the sim's
  marks) and AttackFormView draws their sigils, the small slashes and their blasts.
- `test_wand_smoke.gd` (unchanged code): every slot card, the new ones and the offered triggers included: 1376 runs.

## Goldens
None changed, none regenerated. The replay golden passed (`70ac7ca2…`, above); the MX1 equivalence fixture passed in
the sim folder run. The export smoke was NOT RUN.

## Screenshots
NOT YET RUN (the tour needs a renderer; not run in this container).

## Known limits (honest list)
- **The card-pool bound fails** (94 / 89 against 88) until WN5b prunes the old cards (WN5b's `POOL_MAX`).
- **For WN5b's migration:** the old cards these replace (suggested, WN5b decides): Cinder Shot, Ember Edge,
  Wildfire, Inferno Core → `ember_core` (Fire); Static Chain, Conductor, Tempest Core → `storm_core` (Lightning);
  Glacial Edge, Cold Snap, Frost Nova's card → `frost_core` (Frost); Serrated Edge, Barbed Bolts → `shared_bleed`
  (Bleed); Aftershock, Bomb Rounds → `shared_explosive` (Explosive). Their riders stop the moment they leave.
- **The Blade's child slash** starts on the hit and sweeps that enemy too (WN1's); the Gun's cast bolt leaves past it.
- **Bleed's "red streaks"** draw as the bleed element's existing red drip (no restyle of the v0.6.1 look).
- **Explosive's blast** is drawn ember (its child's element, view only); an explosion is not a burn.
- **The trigger cards' frame** stays WN1's (family `time`); a held trigger isn't offered again (no levels: a second
  On Hit is the legendary tier's, WN5b).
- **A hook's bolt from the enemy's centre** changes Split's (G5) and Shatter's shards too: they no longer hit the
  enemy that split them (MX4's documented rule; the WN3 tests pass).
- Feel, every number, the names: `OWNER ONLY`. The full suite, the export smoke, the tour: NOT RUN.
  `tests/MIN_TEST_COUNT` not raised (the lead's).
