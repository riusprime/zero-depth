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

## Goldens changed on purpose
- none (BR: the replay golden runs a boss-free kernel world; `test_replay_ground_plane.gd` passes unchanged)
- none (WN1: `tests/golden/fixtures/modifier_equivalence.json` still matches under the slot-order compile, 3/3; the
  replay golden 2/2; no fixture regenerated).
- none (WN2: no golden or fixture changed).
- none (WN3: no fixture regenerated; see `evidence/WAND_GUN.md` for the golden runs).

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Version number for this pass | — | pending (lead's pick v0.6.5) | |
| G1: the wand's modifier lists (WAND.md) | 2026-10-12 | "Approve all" | 2026-10-12 |
| Wand slots | 2026-10-12 | "Grows during the run" (4 → 6 → 8) | 2026-10-12 |
| Card pool size (WN3): the Gun pool is 86 cards (Blade 76) while the v0.6 cards wait for WN5's migration; the pool test's ceiling went 80 → 90 in the open (`tests/support/card_pool_survey.gd`). Keep, or prune old cards now? | — | pending (lead / owner) | |

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
