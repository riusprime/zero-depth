# v0.6.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| BR | The Siege Engine (the cannon boss) fights in a 3×3 room, like the Gatekeeper (owner W2, "3×3"); its closing band now closes on both axes. Evidence: [`evidence/BOSS_ROOM.md`](evidence/BOSS_ROOM.md) | `v0.6.5 Step BR` |
| WN1 | The wand compiler: the cards apply in slot order (left to right), trigger cards (On Hit, On Kill, On End, On Finisher / On Crit; placeholder names, not offered yet) cut the wand and cast a small copy of the basic attack, the wand grows 4 → 6 → 8 by floor, a reorder is an input (`InputFrame.wand_move`), saves keep the order (payload 4), `WorldReader.wand()` and `Wand.describe()`. Evidence [`evidence/WAND_1.md`](evidence/WAND_1.md) | `8e50eb3`…final (WIP commits, then this step's commit) |
| WN2 | The wand can be rearranged: a Build row in the pause menu opens the Build page (the wand as a row of slots with each card's frame colour, icon, name and level, trigger cards cutting it with "cast on hit →", and the plain-words read-back, en + es); cards move with the keyboard, the mouse (drag or click-click) and the pad; the moves reach the sim as input on the first ticks after the pause. The Swap panel fits 8 slots at 1280 × 720 and can replace, insert or reorder; the HUD pips show the cuts. Evidence [`evidence/WAND_2.md`](evidence/WAND_2.md) (screenshots NOT YET RUN) | `e46995a` (WIP), then `v0.6.5 Step WN2` |
| WN3 | The Gun pool G1–G16: Big Shot, Rapid Fire, Twin, Spread, Split, Pierce, Ricochet, Homing, Boomerang, Orbit, Spiral, Mine, Charge (hold to grow, release to fire), Echo, Backfire, Halo; each rewrites the bolt left to right in the wand and shows on it (size, count, path, trail, the charge orb, the mine's ring); a duplicate levels a card 1–5 without a slot; Gun runs only. Evidence [`evidence/WAND_GUN.md`](evidence/WAND_GUN.md) | WIP commits, then `v0.6.5 Step WN3` |
| WN4 | The Blade pool B1–B16: every Blade card rebuilds the slash, left to right, and shows on it (Wide Arc's sweep, Wave's flying crescent, Split Wave, Whirl's spin, Double Slash's criss-cross, Thrust's stab, Heavy's slow crushing arcs with knockback, Flurry, Fissure's crack and eruption, Chain Cut, Parry Edge cutting shots, Afterimage's ghost slash, Lunge Step, Finisher+'s shockwave carrying every card, Orbit Blades, Counter's dash-slash wave); offered only in Blade runs; a duplicate levels a card up 1–5. Wide Arc, Echo Slash (Wave), Long Shadow (Afterimage) and Blade Orbit (Orbit Blades) became B1, B2, B12, B15 with their ids; 12 new cards; for WN5: `twin_arc` → `double_slash`. Evidence [`evidence/WAND_BLADE.md`](evidence/WAND_BLADE.md) | `ddb6e0a`…final (WIP commits, then this step's commit) |
| WN5b | The v0.6 cards leave the offers and old builds turn into wand cards: 43 old cards (13 v0.5 attack items, the 4 ability mods, 17 M-list cards, the 3 MX4 legendary versions, the six old abilities; Ember, Storm, Frost and Venom Core and Gravity Well stay as WN5a's S cards) are retired by one table (`data/wand/migration.tres`; the mapping in WAND.md) and never offered again; a save or carry that holds one maps each onto its WAND.md card in pick order (a duplicate levels up; Orbit Blades level 3 → B15 at level 3; a legendary version → level 5) and refunds the rest at the shop's salvage price; v0.6.1 saves load again (they failed on `World.tuning`); the boss's legendary altar offers the run's wand cards at level 5 ("Mod · Level 5 · Legendary") and three ×2 triggers (On Hit, On Kill, On End: the spell cast twice); names: the old Blink card is "Blink Echo", the old ability "Orbiting Copies". S5 `shared_bleed` and S7 `shared_explosive` targets pending WN5a's merge. Evidence [`evidence/WAND_MIGRATION.md`](evidence/WAND_MIGRATION.md) | WIP commits, then `v0.6.5 Step WN5b` |

## Goldens changed on purpose
- none (BR: the replay golden runs a boss-free kernel world; `test_replay_ground_plane.gd` passes unchanged)
- none (WN1: `tests/golden/fixtures/modifier_equivalence.json` still matches under the slot-order compile, 3/3; the
  replay golden 2/2; no fixture regenerated).
- none (WN2: no golden or fixture changed).
- none (WN3: no fixture regenerated; see `evidence/WAND_GUN.md` for the golden runs).
- none (WN4: the modifier equivalence fixture and the replay golden pass unchanged; no fixture regenerated).
- none (WN5b: no golden or fixture regenerated; the replay golden passes unchanged. New test fixtures, not goldens:
  `tests/fixtures/saves/v061_blade_floor1.save` and `v061_gun_floor2.save`, recorded with v0.6.1's code, `950add4`).

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Version number for this pass | — | pending (lead's pick v0.6.5) | |
| G1: the wand's modifier lists (WAND.md) | 2026-10-12 | "Approve all" | 2026-10-12 |
| Wand slots | 2026-10-12 | "Grows during the run" (4 → 6 → 8) | 2026-10-12 |
| Card pool size (WN3): the Gun pool is 86 cards (Blade 76) while the v0.6 cards wait for WN5's migration; the pool test's ceiling went 80 → 90 in the open (`tests/support/card_pool_survey.gd`). Keep, or prune old cards now? | — | pending (lead / owner) | |
| Card pool size (WN3 + WN4 merged): measured on the merged tree (`test_card_pool_reach.gd`: "blade pool: 88 in the data + 0 planned ([]) = 88", "gun pool: 83 in the data + 0 planned ([]) = 83"); the ceiling is 88 (WN3 had 90, WN4 92). Keep, or prune old cards now (WN5 prunes)? | — | pending (owner) | |
| Card pool size (WN5b): after the migration retired 43 v0.6 cards, measured on a trial merge with WN5a (`7e88f80`): `test_card_pool_reach.gd` "blade pool: 61 in the data + 0 planned ([]) = 61", "gun pool: 59 in the data + 0 planned ([]) = 59" (on the WN5b branch alone 55 / 53); `POOL_MAX` 88 → 61. The owner's target was 40–50. Not pruned past WAND.md: the 13 passives outside the wand (Bulwark, Cold Snap, Executioner, …) stay. Keep, or prune further? | — | pending (owner) | |

## History
- 2026-10-12: plan from the owner's v0.6.1 playtest.
- 2026-10-12: BR done (Siege Engine arena 3×1 → 3×3; data only, plus tests).
- 2026-10-12: WN1 built on a session branch (agent): the wand compiler, the four trigger cards, slots 4 → 6 → 8, the
  reorder input, payload 4. Not pushed; the lead's one full suite per wave is pending.
- 2026-10-12: wave BR + WN1, the lead's one full suite on `fb7dab3` from a clean worktree (`bash scripts/verify.sh`):
  `verify exit 0`, `Tests 1442`, `Passing Tests 1442`, `check_gut_log: ok (1442 passing, minimum 1405)`.
  MIN_TEST_COUNT 1405 → 1442. Pushed.
- 2026-10-12: WN2 built on a session branch (agent): the Build page, the Swap rebuilt for 8 slots (replace, insert,
  reorder), the HUD cuts; moves are queued in the latch and reach the sim on the ticks after the pause. Not pushed;
  the lead's one full suite per wave is pending; screenshots NOT YET RUN (the software renderer too slow under load).
- 2026-10-12: WN3 built on a session branch (agent): the 16 Gun cards (12 new, 4 v0.6 cards turned Gun cards with
  their ids), card levels 1–5, the twin / spiral / mine / charge runners and their looks. Not pushed; the lead's one
  full suite per wave is pending.
- 2026-10-12: WN4 built on a session branch (agent): the Blade pool B1–B16, card levels 1–5, BladeFormView. Open for
  the lead: the every-card soak (`test_combos`) peaks at 385 events a tick against its bound of 256 (reported, not
  changed: WAND_BLADE.md); the card-pool bound raised 80 → 92 in the open (the old cards leave in WN5). Not pushed.
- 2026-10-12: WN3 + WN4 merged (agent, branch `wn34-merge`, the merge commit "Merge v0.6.5 Step WN4: the Blade pool
  B1-B16"): one card-level system (WN3's `CardLevels`: the item tag `wand`, `World.card_levels`, `ModifierTable.at`;
  WN4's `ItemDefinition.max_level`, `World.item_levels` and precompiled `ModifierTable.levels` dropped, the 16 Blade
  cards tagged `wand`); `WAND` cards indexed pool by pool (`ModifierCompiler.WAND_POOL_ORDER`: Gun, then Blade), so
  the Gun's indices stay; SIM_CONTRACTS §8f Gun, §8g Blade. Card pool measured 88 (Blade) / 83 (Gun), ceiling 88.
  Folder runs on the merge tree: tests/unit/sim 874/875 (the every-card soak in `test_combos.gd` still peaks at 385
  events a tick against 256: reported, not changed), content 107/107, arch 4/4, golden 2/2, unit/application 29/29,
  unit/presentation 408/408, 12 e2e files 28/28; lint clean. The full suite is the lead's. Not pushed.
- 2026-10-12: owner: "Before the final push to main there is another branch with other updates that you need to merge
  with both and keep all the changes and then push to main the two versions merged, the branch is
  claude/keen-volta-ht74pz". Plan: merge keen-volta (at `cc843cb`: the dev panel Steps 1–6, the lighting pass, fire
  patches) into this branch in the WN2–WN4 wave, so the wave's one full suite covers both; then the PR into `main`.
- 2026-10-12: the every-card soak (`tests/unit/sim/test_combos.gd`, now all 91 items at once) peaks at 385 events in
  one tick (5861 over 5000 ticks; the watchdog, 512, never fires). Owner, after the numbers: "It's okay let's leave it
  like that then". The soak's bound is now the real watchdog (`Engines.MAX_EVENTS_PER_TICK`, 512); T-FUZZ keeps ≤ 256
  for builds of 10–30 stacks (TEST_MATRIX unchanged). Tick time at the peak: NOT YET RUN.
- 2026-10-12: wave WN2 + WN3 + WN4 + keen-volta (`cc843cb`), the lead's one full suite on `e31705e` from a clean
  worktree (`bash scripts/verify.sh`): `verify exit 1`, `Tests 1550`, `Passing Tests 1548`, `Failing Tests 2`:
  `test_dev_master_panel.gd` "data/wand is in the panel" (the two branches met: the dev panel didn't know the wand's
  new folder; fixed, `data/wand` is under Build pieces; `tests/unit/debug` 10/10) and the every-card soak, 385 ≥ 256
  (bound changed with the owner, line above; `test_combos.gd` 13/13). MIN_TEST_COUNT 1442 → 1550. Pushed.
- 2026-10-12: WN5b built on a session branch (agent, `wn5b` from `4787b38`): the old cards' migration table (43 retired,
  mapping in WAND.md), the load-time migration (`WandMigration`), v0.6.1 saves loading again (`World.tuning` in
  `ADDED_SINCE_V05`), the legendary tier's level-5 wand cards and the three ×2 triggers, the pools measured 61 (Blade) /
  59 (Gun) on a trial merge with WN5a (55 / 53 alone). WN5a's ids are in the table (lead's message); S5 and S7 are
  pending until the merge. Not pushed; the lead's one full suite per wave is
  pending.
- 2026-10-12: WN5b folder runs on `ea03123` (agent): tests/unit/sim 887/887; content + arch + golden +
  unit/application 150/150; unit/presentation + unit/debug 423/423; 23 e2e files 48/48; lint clean. On a trial merge
  with WN5a the recorded v0.6.1 saves need WN5a's new state fields in `WorldSnapshot.ADDED_SINCE_V05` (merge note in
  `evidence/WAND_MIGRATION.md`). The full suite is the lead's. Not pushed.
