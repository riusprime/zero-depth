# v0.3.0 Step EG — the gamble shrine (evidence)

Build: the working tree of the Step EG commit on top of `5e24bf7`, before it was committed. Godot
`4.7.2.stable.official.ed1daf0bf`, headless on Linux; renders on llvmpipe (software Vulkan). Owner-only fields
(feel, fun, whether it fixes the "too much money" problem, results on the owner's hardware): `OWNER ONLY`.

Owner line L19: "overstaying the first level gave me a ton of money that I did not have how to spend, so a gamble
feature where you spend money on incrementing steps and have a random stat increase could fix that".

## What was built
- **One shrine per floor, in the start hall** (always reachable, and you can come back to it). Placement rule
  (data: `spot_distance_m` 2.6, `clear_radius_m` 0.9): 2.6 m from the start point on the side of the hall away from
  its exit, turning by 45° steps (left before right) until the spot is inside the hall and clear of every wall by
  0.9 m; without one, the hall's clear spawn point nearest the start, then the same in the rooms next to the hall.
  A pure function of the layout: no stream is drawn, so the floor's loot rolls don't change. The plinth's footprint
  (a 1 m square turned 45°) is a wall, like the gate's, so you walk up to it, not through it.
- **Interact** (the existing action: E, pad X) within 1.8 m pays and grants one stat at once. An altar or chest in
  reach takes the press first (none stands in the start hall, so in play they never compete).
- **Price** 25 shards on floor 1, × 1.5 per use rounded half up: 25, 38, 57, 86, 129, 194 … **The count resets on
  each floor** (it is not carried): every floor offers cheap first spins again, which is what turns a pile of spare
  shards into stats. A later floor's base is raised like the chests' (× 1.5 on floor 2 = 37, × 2 on floor 3 = 50).
- **The pool** (loot stream, weighted over the stats still under their cap; starting values):

  | Stat | One win | Weight | Cap (wins) | Max total |
  |---|---|---|---|---|
  | max HP | +8 (healed by as much) | 3 | 6 | +48 |
  | melee damage | +6 % | 3 | 5 | +30 % |
  | shot damage | +6 % | 3 | 5 | +30 % |
  | move speed | +4 % | 2 | 4 | +16 % |
  | dash cooldown | −6 % | 2 | 4 | −24 % |
  | out-of-combat regen | +0.5 % of max HP per second | 2 | 4 | +2 %/s |
  | heat capacity | +8 % | 2 | 4 | +32 % |
  | shard gain | +5 % | 2 | 4 | +20 % |

  You can't afford it, or every stat is capped: nothing is paid and the world records the refusal (the shrine
  shakes). Data: `data/gamble/shrine.tres` (`GambleDefinition` + `GambleStatEntry`, validated).
- **Run carry and hash.** `World.gamble_stacks` (wins per stat) is in `RunCarry.FIELDS`; max HP is rebuilt from it
  on the next floor before the carried HP is clamped. Hashed (with `gamble_id`, `gamble_uses`, `gamble_last_stat`,
  `gamble_tick`, `gamble_denied_tick`, `gamble_pos`) once a shrine exists or a stat was won, so worlds without one
  (the kernel goldens) keep their hashes.
- **Hooks.** Melee swing damage (after Overcharge, Momentum, Bulwark), bolt damage, move speed and the dash cooldown
  (added to the items' bonuses; the cut stays capped at 90 %), and the shards a kill pays. Regen and heat capacity
  are exposed as `Gamble.regen_bonus_permille(w)` (per mille of max HP per second) and
  `Gamble.heat_capacity_bonus_permille(w)`: **not wired yet** — the regen (P) and heat (H) workstreams aren't on
  this branch. Until the lead wires them, a regen or heat win does nothing in play.
- **Views.** The shrine: an angular robotic obelisk on a hexagonal plinth, split by a window where a cyan core
  crystal floats and turns, light strips up its faces, two fins. The next price floats above it with a shard gem,
  red when you can't pay. A use spins the core fast and lands with a flash; a refusal shakes it and dims the core.
  Glowing materials have emission on from creation and the body is `ActorViews.flashable`: only energies change
  (flash-safe; pinned by a test). The HUD: the prompt ("[E / X] Gamble · 25 shards", red "Not enough shards · 0 / 25",
  or "The shrine has nothing left to give"); a result card above the player that spins through the stat icons
  (slowing down, 0.9 s, frame time, cosmetic: the sim decided at once) and lands on the one won ("+6 % shot
  damage"); a "Shrine stats" panel (icon, total, wins / cap per stat) while you stand at the shrine and for 4 s after
  a win, and in the pause menu. Eight vector stat icons, no external art. Every string in en and es.
- No new `SimEvent` kind (the view reads `gamble_tick` / `gamble_last_stat`), to keep the shared enum untouched.

## Renders
`docs/roadmap/v0.3.0/evidence/gamble.png` (2 × 2, 1600 × 900): top left, the shrine up close with its price in red
(no shards yet); top right, the card mid-spin; bottom left, the landed result with the stats panel; bottom right, a
second win (price now 57). The shrine flashes on landing in the bottom row.

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/gamble.gd
gamble: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
gamble: prompt 'Not enough shards · 0 / 25'
gamble: res://build/shots/v0.3.0/gamble/poor.png (frame 79, tick 256)
gamble: res://build/shots/v0.3.0/gamble/spin.png (frame 93, tick 312)
gamble: won '+8 % heat capacity'
gamble: res://build/shots/v0.3.0/gamble/result.png (frame 98, tick 332)
gamble: won '+6 % shot damage', shards 97, next price 57
gamble: res://build/shots/v0.3.0/gamble/second.png (frame 117, tick 408)
gamble: res://build/shots/v0.3.0/gamble/gamble_sheet.png 1600x900 ["poor+", "spin+", "result", "second"]
```
The shot script grants the shards with a labelled helper before the first use.

## Tests
New: `tests/unit/sim/test_gamble.gd` (18: shipped data, price steps per use and per floor, pay and grant, can't
afford, out of reach, determinism, draws follow the weights, a weightless stat never drawn, caps and a spent shrine,
every stat's hook, shard gain on a real kill, melee on a real swing, carry across floors with the price reset,
hashing, an altar in reach goes first, placement on 40 seeds, the fallback, a real floor),
`tests/content/test_gamble_validation.gd` (3), `tests/unit/presentation/test_gamble_views.gd` (5: flash-safe
shrine, red price, the card's spin landing, icons and lines in en/es, the stats panel), `tests/e2e/test_e2e_gamble.gd`
(1: walk to the shrine with the stick, E refused with no shards, E pays 25 with shards, the card lands on the stat
won, the price steps to 38, pad X pays 38, the pause menu lists the stats). The e2e sets `World.shards` with a
labelled test helper; earning shards by input is `test_e2e_rewards`' `test_kills_earn_shards`.

```
$ bash scripts/verify.sh
...
Scripts              91
Tests               509
Passing Tests       509
Asserts           410692
Time              884.088s
---- All tests passed! ----
check_gut_log: ok (509 passing, minimum 482)
```
Lines printed by the new tests in that run:
```
    won heat_capacity then shot_damage
    draws per stat in 1900: [286, 285, 306, 196, 206, 210, 194, 217]
```
(Weights 3 : 3 : 3 : 2 × 5 of 19 expect 300 and 200 per stat.) `tests/MIN_TEST_COUNT` 482 → 509.

```
$ gdformat --check src scripts tests && gdlint src scripts tests
285 files would be left unchanged
Success: no problems found
```
`world.gd` and `world_reader.gd` passed gdlint's 1000-line limit; both now disable `max-file-lines` next to their
existing `max-public-methods` disable.

```
$ bash scripts/ci/export_smoke.sh
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash 0aa7c013c67e matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```

## Goldens
None changed: the kernel worlds have no shrine and win no stat, so their hashes are untouched (export smoke hash
`9c324d3dbf34` as before; the replay golden test passes).

## Open
- Wire `Gamble.regen_bonus_permille` into P's regen and `Gamble.heat_capacity_bonus_permille` into H's heat cap.
- With P's Blade/Gun split, melee damage is dead weight on a Gun run and shot damage on a Blade run: the pool should
  leave out the other build's stat (a `requires` field per entry, or weight 0 per build).
- Owner: is the price curve right for how many shards a long floor 1 gives? `OWNER ONLY`.
