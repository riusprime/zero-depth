# v0.6.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| BR | The Siege Engine (the cannon boss) fights in a 3×3 room, like the Gatekeeper (owner W2, "3×3"); its closing band now closes on both axes. Evidence: [`evidence/BOSS_ROOM.md`](evidence/BOSS_ROOM.md) | `v0.6.5 Step BR` |

## Goldens changed on purpose
- none (BR: the replay golden runs a boss-free kernel world; `test_replay_ground_plane.gd` passes unchanged)
| WN1 | The wand compiler: the cards apply in slot order (left to right), trigger cards (On Hit, On Kill, On End, On Finisher / On Crit; placeholder names, not offered yet) cut the wand and cast a small copy of the basic attack, the wand grows 4 → 6 → 8 by floor, a reorder is an input (`InputFrame.wand_move`), saves keep the order (payload 4), `WorldReader.wand()` and `Wand.describe()`. Evidence [`evidence/WAND_1.md`](evidence/WAND_1.md) | `8e50eb3`…final (WIP commits, then this step's commit) |
- none (WN1: `tests/golden/fixtures/modifier_equivalence.json` still matches under the slot-order compile, 3/3; the
  replay golden 2/2; no fixture regenerated).
| WN4 | The Blade pool B1–B16: every Blade card rebuilds the slash, left to right, and shows on it (Wide Arc's sweep, Wave's flying crescent, Split Wave, Whirl's spin, Double Slash's criss-cross, Thrust's stab, Heavy's slow crushing arcs with knockback, Flurry, Fissure's crack and eruption, Chain Cut, Parry Edge cutting shots, Afterimage's ghost slash, Lunge Step, Finisher+'s shockwave carrying every card, Orbit Blades, Counter's dash-slash wave); offered only in Blade runs; a duplicate levels a card up 1–5. Wide Arc, Echo Slash (Wave), Long Shadow (Afterimage) and Blade Orbit (Orbit Blades) became B1, B2, B12, B15 with their ids; 12 new cards; for WN5: `twin_arc` → `double_slash`. Evidence [`evidence/WAND_BLADE.md`](evidence/WAND_BLADE.md) | `ddb6e0a`…final (WIP commits, then this step's commit) |
- none (WN4: the modifier equivalence fixture and the replay golden pass unchanged; no fixture regenerated).

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Version number for this pass | — | pending (lead's pick v0.6.5) | |
| G1: the wand's modifier lists (WAND.md) | 2026-10-12 | "Approve all" | 2026-10-12 |
| Wand slots | 2026-10-12 | "Grows during the run" (4 → 6 → 8) | 2026-10-12 |

## History
- 2026-10-12: plan from the owner's v0.6.1 playtest.
- 2026-10-12: BR done (Siege Engine arena 3×1 → 3×3; data only, plus tests).
- 2026-10-12: WN4 built on a session branch (agent): the Blade pool B1–B16, card levels 1–5, BladeFormView. Open for
  the lead: the every-card soak (`test_combos`) peaks at 385 events a tick against its bound of 256 (reported, not
  changed: WAND_BLADE.md); the card-pool bound raised 80 → 92 in the open (the old cards leave in WN5). Not pushed.
- 2026-10-12: WN1 built on a session branch (agent): the wand compiler, the four trigger cards, slots 4 → 6 → 8, the
  reorder input, payload 4. Not pushed; the lead's one full suite per wave is pending.
