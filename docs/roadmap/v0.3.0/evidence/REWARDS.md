# v0.3.0 E — shards, altars, chests, pick 1 of 3 (evidence)

Build: the working tree of the merge of `48a0d37` (Step E) with `f13bcfb` (workstream G), plus the lead's
follow-ups (rare items, utility-gated offers), before it was committed. Godot `4.7.2.stable.official.ed1daf0bf`,
headless on Linux; renders on llvmpipe (software Vulkan). Owner-only fields (feel, fun, results on the owner's
hardware): `OWNER ONLY`.

## What was built
- **Shards.** A kill pays its kind's `shards` (data: Charger 3, Needle 4, Warden 6) × (1 + 0.25 × danger tier),
  rounded half up; a kind with `shards_by_floor` (bosses, workstream C) pays `shards` × floor. `World.shards` is
  sim state (hashed once rewards are in use). Gems burst from the body and fly into the player (frame time); a
  counter with a crystal icon sits top right.
- **Altars and chests** replace v0.2.0's pedestals: 2–3 altars (free) and 2–3 chests per floor (counts and order
  from the loot stream), one per room on the layout's item spots, never in the start hall. Chest prices by chest
  order: 40 / 60 / 80 on floor 1, × 1.5 on floor 2, × 2 on floor 3 (`World.floor_index`, default 1).
  Data: `data/rewards/floor.tres` (`RewardsDefinition`, validated).
- **Interact** opens the altar or chest in reach (1.6 m): the existing `interact` action, **E** on the keyboard,
  **X / Square** on the pad (no clash: X was bound to `interact` and unused; remappable through the bindings
  store). Altars also open with interact, not by walking on: walking on would reopen an altar right after you
  leave it for later, and would freeze the game on an accidental walk-over in a fight. A chest you can't afford
  shows its price in red, its prompt reads "Not enough shards · n / price" in red, and it shakes and stays shut.
- **Pick 1 of 3.** Opening rolls the offer once: up to 3 different items not owned, not on offer elsewhere, and
  usable with the chosen utility (`ItemDefinition.requires_utility`; Bulwark needs the guard). Chests weight rare
  items × 3 (Wildfire, Conductor, Cold Snap, Bulwark are rare). **Choosing rule:** while the choice is open the
  sim runs only the pick (`InputFrame.pick`: 1–3 or cancel); every gameplay phase waits (enemies, projectiles,
  statuses, spawns, the danger clock), and `World.tick` still counts. A pick grants the item (a `PICKUP` event, so
  the HUD card shows it), pays a chest's price, consumes the reward and returns the other cards to the pool.
  Cancel keeps the reward and its rolled cards (no reroll). Presses made during the choice are dropped.
- **Pick UI.** Three compact item cards in rarity frames (grey common, gold rare), the chest's price in the title.
  Mouse: hover + click. Keyboard: ←/→ or 1/2/3, Enter takes, Esc leaves. Pad: d-pad / left stick, A takes, B
  leaves. Space never confirms (it's dash). The pause menu doesn't open while choosing.

## Tests
```
$ bash scripts/verify.sh
...
Scripts              74
Tests               394
Passing Tests       394
Asserts           202262
Time              151.683s
check_gut_log: ok (394 passing, minimum 394)
```
Lines printed by the new tests in that run:
```
    rare hits in 400 draws: chest 97, altar 31
    kills 1, shards 3 after 739 ticks
    combo frozen_bastion from 4 rewards
```
New: `tests/unit/sim/test_rewards.gd` (21), `tests/unit/presentation/test_reward_views.gd` (8),
`tests/e2e/test_e2e_rewards.gd` (3: shards from shooting, a chest shut then bought with 3 + Enter, Esc leaves
it). Rewritten for the reward objects: `tests/e2e/test_e2e_floor.gd` (altars and chests on the floor; walk to an
altar, pad X, d-pad right, A takes the 2nd card) and G's `tests/e2e/test_e2e_combo.gd` (open every reward, leave
it with B, then take a combo pair's two cards). The chest e2e and the combo e2e set `World.shards` directly with
a labelled test helper; earning shards by input is `test_kills_earn_shards`.

```
$ gdformat --check src scripts tests && gdlint src scripts tests
229 files would be left unchanged
Success: no problems found
```

```
$ bash scripts/ci/export_smoke.sh
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ok    content player: 1
  ok    content biomes: 1
  ok    content validates inside the pack (0 errors)
  ok    manifest hash caa423492d22 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```

## Goldens
None changed by this merge: reward state joins the hash only once it leaves its defaults, so the kernel replay
keeps workstream G's values (replay final `5171fdad…`, export smoke `9c324d3d…`). Before the merge, Step E alone
(`48a0d37`) had regenerated them (replay `c798f9e5…` → `9004c560…`, export smoke `921997d9…` → `0893e92d…`)
because it hashed the new fields unconditionally; with the hash removed the old replay still matched
(`REPLAY| final=c798f9e5…`, 2/2 passed), so that diff was the new fields only. The gated hash supersedes it.

## Renders
```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/rewards.gd
rewards: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
rewards: 3 gems in flight, shards 3, kills 1
rewards: res://build/shots/v0.3.0/rewards/shards.png (frame 201, tick 744)
rewards: res://build/shots/v0.3.0/rewards/altar.png (frame 335, tick 1280)
rewards: pick open, title 'Altar · choose one'
rewards: res://build/shots/v0.3.0/rewards/pick_row_centre.png (frame 345, tick 1320)
rewards: res://build/shots/v0.3.0/rewards/pick_row_low.png (frame 351, tick 1344)
rewards: res://build/shots/v0.3.0/rewards/pick_column_right.png (frame 357, tick 1368)
rewards: took item thorn_mantle
rewards: chest price 60, shards 3, prompt 'Not enough shards · 3 / 60'
rewards: res://build/shots/v0.3.0/rewards/chest.png (frame 419, tick 1616)
rewards: res://build/shots/v0.3.0/rewards/rewards_sheet.png 2160x810 ["shards+", "altar+", "chest+", "pick_row_centre", "chest", "shards"]
rewards: res://build/shots/v0.3.0/rewards/pick_mockups.png 720x1215 ["pick_row_centre", "pick_row_low", "pick_column_right"]
```
- [`rewards.png`](rewards.png) (516,644 bytes; copied by hand from `rewards_sheet.png`). Top row, 2× close-ups:
  the shards moment (the gems had already left the crop when the frame was grabbed; only the bolts show), the
  altar with its rune crystal by the player, the chest with its red lock glow and its price (60) in red. Bottom
  row, whole frames: the pick screen, the chest with the red prompt and the shard counter (top right), the fight
  where the shards were earned. Known gap: the shard gems are small and fast, and no frame shows them clearly;
  `test_shard_gems_fly_from_the_kill_to_the_player` and the e2e prove they spawn and arrive.
- [`pick_mockups.png`](pick_mockups.png) (G2, 436,994 bytes): **top, shipped default** — a row of three cards
  centred over a dimmed world; **middle** — a row low on the screen over a lightly dimmed world; **bottom** — a
  column on the right. This floor's altar offered three common items, so no gold frame shows in these shots; the
  rare frame is covered by `test_the_pick_panel_shows_the_offer_with_rarity_frames`.
- Owner's choice of layout, and how any of it feels: `OWNER ONLY`.
