# v0.10.5 O7b evidence: kill shards lie on the floor until you pick them up

- **Owner line (P6, 2026-11-01):** "can we also make the shards stay on the floor instead of flying around". Overnight
  mode: "Pick and build". Every number below is a starting value, the lead's pick.
- **Build:** branch `v0105-o7b`, cut from `241658ed`; measured on the working tree with the O7b code uncommitted. The
  code commit follows this file (its SHA is in the commit log, not here).
- **Machine:** the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2. No timing is claimed.

## The rules as built

| Rule | Value | Where |
|---|---|---|
| Who drops | a normal enemy's kill (not a boss, not a `shards_by_floor` kind) | `Rewards.lies_on_floor` |
| What a drop holds | the kill's whole amount, fixed at the kill: shrine, shard-gain stat, Tunnel Vision, rune affinity | `Rewards.on_kill` |
| Merge | a new drop within **0.5 m** of another adds to the nearest one (which keeps its spot) | `ShardDrops.MERGE_M` |
| Cap | **24** drops on a floor; past it the oldest merges into its nearest neighbour (nothing lost) | `ShardDrops.MAX_ON_FLOOR` |
| Pickup | every drop within **1.2 m** × the pickup-range stat (`Stats.reach`) of the live hero, tick phase 9 after heal orbs; `World.shards +=` amount, a SHARDS event at the drop (effect `shard_pickup`) | `ShardDrops.REACH_M`, `advance` |
| Portal | `RunState.finish_floor` credits every drop left (no events) before the carry, so none are lost; the run's carry share then applies as before | `ShardDrops.collect_all` |
| Still instant | boss shards, chests, events, containers, the Overrun bonus. The Overrun counts a kill's shards at the kill | unchanged |
| Scavenger (O9) | its crit bonus is computed at the kill and joins the same drop (paid when taken); on a boss it is still paid at once | `RuleCards.on_kill` |
| Hoarder (O9), shop, chests | read `World.shards`, so they count only the shards taken | unchanged |
| Save | `World.shard_drops` (`ShardDropStore`: seqs, amounts, positions, next_seq) is saved; an older save lacks it (ADDED_SINCE_V05) and starts with none lying | `WorldSnapshot` |
| Hash | only once a drop was ever made (`touched`) | `World.state_hash` |

Integer amounts; no RNG; no entity ids taken (a drop's sequence number is the store's own count, so later ids are
unchanged).

View (`ShardViews`): each drop is a small cluster of the same violet shard gems (`ShardMesh.cluster` with the gem
material, 2 gems + 1 per 4 shards, at most 4; 0.34 m tall) with a soft glow, turning slowly. When the hero takes one,
the cluster is pulled into the hero over 0.15 s, shrinking, then freed. A drop that left by merging just goes. Instant
payouts still burst and fly as before.

## Tests

Lint (the whole tree):

```
$ gdformat --check src scripts tests
1564 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
```

Command for each batch (a fresh `APPDATA` per run, after `--headless --path . --editor --import --quit`):

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -ginclude_subdirs -gexit -gtest=<files>
```

1. Unit batch (21 files: test_rewards, test_heal_orbs, test_rule_cards, test_world_snapshot, test_old_saves,
   test_reward_views, test_shard_altar, test_overrun, test_affinities, test_card_pool, test_stats, test_shop,
   test_events, test_breakables, test_run_flow, test_gamble, test_catch_up, test_curses, test_trade_off_curses,
   test_arenas, test_shrines):

```
Scripts              21
Tests               274
Passing Tests       268
Failing Tests         6
```

   Two of the 6 were this change's (test_overrun's clear payout and test_gamble's shard gain read `w.shards` straight
   after kills that now lie on the floor). Both tests now credit the drops first; the re-run:

```
-gtest=res://tests/unit/sim/test_overrun.gd,res://tests/unit/sim/test_gamble.gd,res://tests/unit/sim/test_rewards.gd
Tests                58
Passing Tests        58
```

   The other 4 fail the same way on the base `241658ed` without O7b (run in a detached worktree of `241658ed`:
   `Tests 36, Passing 31, Failing 5` over test_arenas, test_old_saves, test_reward_views, test_e2e_old_save):
   - test_old_saves (2 tests): `["World.player_hp_floor: not in the snapshot"] expected to equal [""]` (a field from
     O17 missing from ADDED_SINCE_V05);
   - test_arenas `test_rewards_fill_the_arenas_first_and_keep_two_altars`: `[3] expected to be <= than [2]: seed 2:
     S1's cap holds` (and 11 more seeds);
   - test_reward_views `test_the_pick_panel_shows_the_offer_with_rarity_frames`: `[STRING_NAME(red)] expected to
     equal [STRING_NAME(amber)]: card 0 colour`.

2. New and touched tests plus the e2e that reach the change (test_e2e_rewards, test_e2e_shop, test_e2e_old_save,
   test_e2e_portal, test_e2e_run_flow, test_reward_views, test_shard_drops, tests/golden/test_replay_ground_plane):

```
Scripts               8
Tests                34
Passing Tests        32
Failing Tests         2
```

   The 2 failures are the base's (test_e2e_old_save: "the old save is not set aside: it continues", the
   `player_hp_floor` warning above; test_reward_views' card colour). `test_e2e_rewards.test_kills_earn_shards` now
   walks the hero to the drop through real input: `kills 1, shards 2 after 915 ticks`.

3. `tests/unit/sim/test_shard_drops.gd` (new, 12 tests: lies unpaid out of reach, taken inside reach with one SHARDS
   event at the drop, the pickup-range stat widens it, a kill beside the hero pays the same tick, merge within 0.5 m,
   the cap merges the oldest and loses nothing, bosses pay at once, the portal takes what lies, `finish_floor`
   carries it, no drop no hash change, save round-trip, an older save starts with none): 12/12 passed.

4. Wider batch (15 files: test_e2e_boss_challenge, test_e2e_combo, test_e2e_curses, test_e2e_events,
   test_e2e_gamble, test_e2e_prompt, test_e2e_reward_cards, test_e2e_rune_combos, test_audio_director,
   test_shard_altar, test_catch_up, test_ascension, test_core_theft, test_twin_wardens, test_final_approach):

```
Scripts              15
Tests                98
Passing Tests        97
Failing Tests         1
[Failed]:  [0] expected to be > than [0]:  the shards, as any kill   (test_core_theft)
```

   This change's: an elite's shards now lie at the body. The test credits the drops first; the re-run of
   test_core_theft: `Tests 10, Passing Tests 10`.

Not run locally: the rest of the suite (GitHub runs it on the PR), the bot sims.

## Goldens

`tests/golden` (`-gdir=res://tests/golden`): `Tests 2, Passing Tests 2`. No golden moved, none re-recorded.

## Shot

```
godot --path . --audio-driver Dummy --resolution 1600x900 --position -10000,-10000 -s scripts/shots/shard_pickups.gd
shard_pickups: res://build/shots/v0.9.0/o7b/shards_on_the_floor.jpg (tick 125, kills 7, drops 7 holding 17, shards taken 0, view clusters 7)
```

(The folder name comes from `GameVersion.label()` on this tree.) Seven held enemies round the hero on the Ruins stage
are killed one every 12 ticks through `Damage.hit` (staged, the sim's own kill path); 30 ticks later the frame shows
seven small violet crystal clusters with a soft glow on the floor where each fell, none taken (all outside 1.2 m).
Looked at: readable against the sand, small next to the hero; one sits in a wall's shadow and still reads by its glow.

## Picks for the owner

1. Reach **1.2 m** × pickup range (heal orbs use 0.9 m, items 0.8 m). Bigger means less walking.
2. Merge radius **0.5 m**; at most **24** drops a floor (the oldest merges into its nearest).
3. Shards left lying are **taken with you at the portal** (no loss). The other choice: lost, which makes walking
   over them matter more.
4. Shard-gain modifiers (shrine, stat, curse, affinity, Scavenger) fix the amount **at the kill**; Hoarder and the shop
   count only shards **taken**.
5. Boss shards, chests, events, containers and the Overrun bonus stay instant (they still fly in as before).
6. Not measured here: the shop economy against the bot sims (bots that never walk to drops take their shards at the
   portal). `NOT YET RUN`.
