# v0.3.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | `0c44b40`, `0ea126b` |
| A | Walls 0.6–3.0 m thick (two drawn halves per partition); a blink crosses a wall only when the free landing beyond it is within range, never into void, wall, gate or a sealed pocket; doors 2.2–3.4 m anywhere along the shared wall; cell size per floor; parametrised templates + colonnade and diagonals ([WALLS](evidence/WALLS.md)) | `435b0dd`, merge `54cf6d1` |
| N | The blade is a four-slash combo: slash, backhand, thrust, spinning finisher (10/10/12/24); per-step shapes drawn from the hit's own arc/reach; Overcharge = the finisher; Twin Arc echoes the step ([FOUR_SLASHES](evidence/FOUR_SLASHES.md)) | `880c48a`, merge `7014a75` |
| G | Engines (burn, shock, bleed, frost, guard charges) with loop rules and a watchdog; tags on all items; 8 more items (24); 8 named combos with a combo card, HUD badges and status visuals; INTERACTIONS.md 24×24 matrix ([COMBOS](evidence/COMBOS.md)) | `27b2c5f`, merge `494e9b3` |
| C | Boss framework (BossDefinition, stagger meter, phases, punish windows, one shape function per attack) and three bosses from the owner's sheet: Gatekeeper / Stone Sentinel (HP 1400), Brood Mother / Crawler Queen (1600, hatchlings), Siege Engine / Fortress Turret (1800, deploys Needles); boss bar; death-recap causes; dev panel spawn ([BOSSES](evidence/BOSSES.md)) | `12132b6`, `a8a1caa`, `f85bdeb`, merge `a07795e` |
| E | Shards per kill (× danger tier; bosses 60 × floor, hatchlings 1); 2–3 free altars and 2–3 chests per floor (40/60/80 × floor step), opened with interact (E / pad X); pick 1 of 3 (sim waits while choosing); rarity (4 rares) and utility-gated offers (Bulwark only with guard); shard gems, HUD counter, pick panel; G2 layout mockups ([REWARDS](evidence/REWARDS.md)) | `48a0d37`, `d43ebf8`, merge `995dc44` |

## Goldens changed on purpose
- **N** (`World.echo_step` hashed; the scripted input never swings — the old golden passes with the field un-hashed):
  replay final `c798f9e5…a309df` → `5171fdad…d841ae`; export-smoke `921997d9…5e4234` → `9c324d3d…81fa17f2`.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Design questions (run, combos, items, blink walls) | 2026-10-07 | answered (PLAN "Owner answers") | 2026-10-07 |
| Boss reference sheets (from the PLAN's prompts) | 2026-10-07 | received: `docs/art/first-three-bosses-concept.png` | 2026-10-07 |
| G2: 3-card pick screen, run recap | — | not yet asked | |
| Blink vs thick walls | 2026-10-07 | "Thicker room walls" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.

## Blockers
- none

## History
- 2026-10-07 — Owner closed v0.2.0 and directed a full run (three floors, bosses, economy, pick-1-of-3, engines +
  combos, wall thickness for blink). PLAN committed before code. Workstreams A, B, C, E, G run in parallel.
- 2026-10-07 — Owner uploaded the boss sheet (`docs/art/first-three-bosses-concept.png`, L10; sent to workstream C as the 1:1 reference) and asked for a 4-slash melee combo with a stronger 4th (L11, workstream N).
- 2026-10-07 — A and N merged (one comment conflict in PlayerKit). 318 tests pass. A found that from close up a blink (5.0 m range) still crosses walls up to 4.3 m thick, i.e. every wall: asked the owner (shorter range or thicker walls). The PLAN said blink range 4.5 m; the data has 5.0 m since v0.1.0 — the PLAN line was wrong and is corrected.
- 2026-10-07 — Owner chose "Thicker room walls" (L12). B finished (7cfcaa2) but was built before A: merging gives parse errors (the boss room builder uses the removed `wall_half`). Merge aborted; B is adapting to A's wall model, applying L12 (walls up to 5 m) and sealing the boss room against blink.
- 2026-10-07 — G merged clean; 362 tests pass; goldens unchanged (engine state is hashed only with item tables). Open for the owner: Bulwark (guard charges) is dead with Blink; Twin Arc's echo adds no extra stacks. For B: carry `items_owned`, `combos_owned` (via `World.set_items_owned`) and `guard_charges`. For E: rare = Wildfire, Conductor, Cold Snap, Bulwark. For C: set `freeze_immune` on bosses.
- 2026-10-07 — C merged clean; 403 tests pass; goldens unchanged (boss state hashed only with boss tables). An item-less, unkillable bot needed 56.3 / 71.8 / 55.2 s per boss (test band 30–90 s); a real player's fight length is NOT YET RUN. Open for the owner: breakable pillars/cover (now normal cover); bosses not scaled per floor yet.
- 2026-10-07 — E merged with C (conflicts in SimEvent, World, WorldReader, HUD, ContentCompiler, strings, SIM_CONTRACTS; kept both). Two merge slips fixed in the merge: the shard payout had slid inside the boss branch (4 failing tests caught it) and two functions lost their final `return`. Lead additions: `RewardsDefinition.boss_shards` (60 × floor, data + test), hatchling shards 1. 436 tests pass; goldens unchanged. G2 pick layout: centred row ships as default, owner to pick from `pick_mockups.png`.
- 2026-10-07 — Owner uploaded three boss models (L13; generated with Tripo per the glTF metadata). Workstream C2 installs them. Open for the owner: the models' licence terms (check the Tripo plan used; a credit line may be required, O4).
