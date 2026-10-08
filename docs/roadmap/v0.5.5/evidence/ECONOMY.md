# ECONOMY: does Step EC (P1, D1, D9, S1–S4, Q-S4) build and pass the full suite?

- **Status:** RUN (suite and export smoke). Balance and feel: **OWNER ONLY** (no bot sims, owner P1).
- **Build:** `afa3c70` on `worktree-agent-a286b39d0a426786b` (branched from `claude/lucid-fermat-9wv2tf` at
  `8e248ab`); Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v80`
- **Date:** 2026-10-08
- **Who ran it:** agent

## What changed (player-facing)
| Row | Change (starting values) | Where |
|---|---|---|
| P1 | Bot balance sims retired: no scorecard, no tuning sims, no bot-band tests | files below |
| D1 | Floor 1: calm phase 0–30 s (holds), then STIR 30 s, HUNT 50 s, SWARM 70 s, PEAK 90 s (the ramp is 60 s, was 84 s from 60 s to 144 s). Floors 2–3: no calm; they open at the warm-up (STIR) level with the basic kinds, HUNT 10 s, SWARM 20 s, PEAK 30 s | `data/curves/floor_*.tres` |
| D9 | New stat card **Lifesprout** (en "Lifesprout", es "Brote vital"): first card 10 % heal-orb chance per kill, each further card +5 %, cap 30 %. The floor's base chance is 0: no card, no orbs. In the stat-card pool of both builds (chests, altars, shop). The floor-1 boss-room heal stays | `data/stat_cards/lifesprout.tres`, `data/rewards/floor.tres` |
| S1 | At most 2 placed altars per floor; altars rolled past the cap become chests (same draws, same spots) | `altars_cap` |
| S2 | A shop reroll redraws only the unsold slots; bought slots stay "Sold"; no reroll once every slot is sold | `Shop.reroll` |
| S3 | At most 4 card buys per floor's shop (heal, rerolls, cleanse and salvage don't count); the panel shows "Cards you can still buy on this floor: N", then in red "No buys left on this floor (4 of 4 bought)"; buys and rerolls past it are refused | `max_buys`, `ShopPanel` |
| S4 | Every kill's shards × 0.7; shop card and heal prices × 1.5 on floors 2–3 on top of the floor step (× 1, 2.25, 3); salvage refunds stay on the floor step alone | `shard_scale`, `late_floor_price` |
| Q-S4 | Owner "Keep half": a portal carries half the unspent shards (rounded down); floor 2/3's arrival card says "The portal kept half your shards: -N" | `shard_carry`, `RunCarry`, `Hud.show_floor` |

## P1: removed files and tests
Removed files: `scripts/sims/scorecard.gd`, `scripts/sim/tuning_sim.gd`, `tests/support/score_bot.gd`,
`tests/support/score_cells.gd`, `tests/support/score_run.gd`, `tests/support/score_stats.gd`,
`tests/support/score_suite.gd`, `tests/support/run_bot.gd`, `tests/support/tuning_run.gd` (each with its `.uid`),
`tests/unit/scorecard/` and `tests/unit/sim/test_expected_build_bot.gd`.

Removed test functions (17):
- `tests/unit/scorecard/test_score_bot.gd`: `test_every_policy_is_deterministic`, `test_policy_names_set_the_knobs`,
  `test_idle_never_moves_or_presses`, `test_specialists_prefer_their_focus_cards`, `test_novice_picks_from_its_own_stream`,
  `test_salvage_exploit_buys_and_sells_back`, `test_competent_can_finish_a_floor`,
  `test_chain_exploit_starts_with_every_combo_item`;
- `tests/unit/scorecard/test_scorecard.gd`: `test_every_scorecard_metric_has_a_well_formed_cell`,
  `test_the_document_and_table_serialise`, `test_a_run_record_is_byte_reproducible`, `test_tasks_parse_back`,
  `test_wilson_and_distributions`, `test_drought_engine_and_divergence_rules`, `test_a_flat_synergy_curve_is_not_a_rise`;
- `tests/unit/sim/test_expected_build_bot.gd`: `test_card_scores_put_abilities_first`,
  `test_floor_1_opens_calm_and_lets_the_build_grow`.

Mixed tests kept with the band dropped (`tests/unit/sim/test_boss_fights.gd`):
- `test_melee_and_near_shooting_fall_within_the_band` → `test_melee_and_near_shooting_kill_every_boss`: the 25–90 s /
  25–120 s fight-length bands are gone; kept: each boss takes hits and dies.
- `test_kiting_from_afar_is_clearly_slower_than_fighting_close` → `test_kiting_from_afar_is_deflected_and_punished`:
  the "far ≥ 1.5 × close" ratio is gone; kept: far hits are deflected and staying far is punished.
- `TuningRun.peak_ticks` (the bots' measured boss-door times) no longer sets the curve peaks: tests read the peak
  from the curve data (`tests/unit/sim/test_difficulty_curve.gd`, `test_heal_orbs.gd`).

Kept (mechanics, not balance): the `FightBot` scripted driver in the readable-cause, determinism and save tests, and
the bench. `tests/MIN_TEST_COUNT`: 1086 → 1076 (the real count of the run below).

## Command
```
bash /tmp/claude-0/vd.sh /home/user/zero-depth/.claude/worktrees/agent-a286b39d0a426786b ec
```
(import, `gdformat --check` + `gdlint`, then `bash scripts/verify.sh`: the full GUT suite and `check_gut_log.sh`.)

## Raw output
```
verify exit 0
Tests              1076
Passing Tests      1076
check_gut_log: ok (1076 passing, minimum 1076)
```
From `/tmp/claude-0/vd_ec.clean.log` (the new and changed tests, trimmed):
```
[… trimmed …]
* test_a_kill_drops_a_heal_orb_and_walking_onto_it_heals
1/1 passed.
[… trimmed …]
* test_into_the_portal_and_out_on_floor_two
1/1 passed.
[… trimmed …]
* test_rerolls_keep_sold_slots_and_four_buys_per_floor
2/2 passed.
[… trimmed …]
* test_melee_and_near_shooting_kill_every_boss
BOSSFIGHT| gatekeeper MELEE ticks=2008 seconds=33.5 hits=86 deflected=0 exposed=28 punished=0
BOSSFIGHT| gatekeeper RANGED_NEAR ticks=3387 seconds=56.5 hits=474 deflected=0 exposed=0 punished=0
[… trimmed …]
* test_kiting_from_afar_is_deflected_and_punished
BOSSFIGHT| gatekeeper RANGED_FAR ticks=5257 seconds=87.6 hits=735 deflected=533 punished=0 gap_closed=13
[… trimmed …]
* test_floor_1_is_calm_for_30_s_then_ramps_faster
* test_floors_2_and_3_start_at_the_warm_up_level
[… trimmed …]
* test_without_lifesprout_no_orb_ever_drops
* test_lifesprout_stacks_its_chance_up_to_the_cap
* test_about_one_kill_in_ten_drops_one_with_a_lifesprout
[… trimmed …]
* test_the_portal_keeps_half_the_shards_rounded_down
[… trimmed …]
* test_a_reroll_keeps_the_sold_slots_sold
* test_at_most_max_buys_cards_per_floor
19/19 passed.
[… trimmed …]
Totals
------
Scripts             168
Tests              1076
Passing Tests      1076
Asserts           483050
Time              1439.461s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (1076 passing, minimum 1076)
```
(The BOSSFIGHT lines are printed for the record; no test asserts a time band on them any more.)

## Export smoke
```
cd /tmp && bash /home/user/zero-depth/.claude/worktrees/agent-a286b39d0a426786b/scripts/ci/export_smoke.sh
```
```
manifest: 20975c8d5692785e86cfcfb268c577bc5bfe87b4293da828a0581d18926c1d96 (221 files, 0 errors)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash 20975c8d5692 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
exit 0
```

## Target bands
None: P1 retires bot-measured bands. Every number above is a starting value the owner tunes by playing.

## Result
| Check | Result |
|---|---|
| Full suite | 1076 / 1076 passing |
| Export smoke | 0 misses |
| Goldens (replay, export-smoke hash) | unchanged (the kernel replay doesn't use curves, rewards or the shop) |
| Feel: calm 30 s, ramp speed, Lifesprout rarity, shop limits, shard cut, keep-half | OWNER ONLY |

## Interpretation and open points for the owner
- **Card pool size:** Lifesprout makes the Blade's pool 51 distinct cards (the Gun's 49). The v0.5.0 rule was 40–50
  (ROADMAP); the owner's D9 (PLAN, higher rank) adds the card, so the test's bound is now 40–51. The v0.6.0 pruning
  can bring it back to 50.
- **Altars beyond the floor's two:** the Overrun room's clear reward (an ability-card altar) and a Deep floor's epic
  altar (stat cards and level-ups only, no new abilities) are not counted in the cap of 2; S1 caps the floor's
  placed reward spots. Owner: should the Overrun clear give a chest instead?
- **Lifesprout rarity:** every rarity gives the owner's numbers (10 % first, +5 % each further card); rarity only
  changes its frame. Shop and chest offers stop once it reaches the 30 % cap.
- **S3 with S2:** since bought slots never refill, a 4-slot stock already allows at most 4 buys per shop; the
  explicit limit (data `max_buys`) also refuses rerolls once it is reached, so no shards are spent for nothing.
- **Salvage refunds** keep the floor-step price (not the floors 2–3 × 1.5), so selling doesn't become a shard source.
