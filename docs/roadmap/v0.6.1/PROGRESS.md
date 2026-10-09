# v0.6.1 — progress

Plan: [`PLAN.md`](PLAN.md). Local on `claude/lucid-fermat-9wv2tf` until v0.6.0's PR (riusprime/zero-depth#3) merges.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| SW2 | Owner A1: shard clusters round both portals, in the portal's own colour (the visor blue; the Deep gate violet), at the pillars' feet and on the lintel's ends with floating fragments; lit by the scene, brighter when open and in the flare; clear of the opening and the walk-in path; the gate's look, animations and cues unchanged (no clusters on the arrival column: a moment of light on the hero's spot, not a place). The shop terminal and the other audit rows kept. Owner A5: the build picker's title "CHOOSE YOUR WEAPON" / "ELIGE TU ARMA". Evidence [`evidence/SHARD_WORLD_2.md`](evidence/SHARD_WORLD_2.md) | `v0.6.1 Step SW2` commit |
| SD | Crystal-shard clusters: a hero cluster with a small cold light at the start room's back wall or corner, small clusters on the generated rooms' back walls (themed density, none in the boss arena, Deep floors violet); presentation only, replay golden unchanged ([evidence](evidence/SHARD_DRESSING.md)) | v0.6.1 Step SD |
| SW | The altars wear the crystal-shard look of the owner's card art (outlined faceted shards on a stone base in the tier's card-frame colour: blue, purple for the Deep epic, gold for the legendary; lit by the mood, a soft glow, floating fragments, brighter in reach); heal orbs, shard gems and dropped cores are outlined shards too. G1 audit of every world piece with model prompts: [`evidence/SHARD_AUDIT.md`](evidence/SHARD_AUDIT.md); evidence [`evidence/SHARD_WORLD.md`](evidence/SHARD_WORLD.md) | this commit |
| PQ | The owner's 12 wide crystal plaques (nine-slice, family colours from the card frames' table) on the item and combo pop-ups, the combo badges, event choices, the shop's services and salvage rows, the shrine's result and the phase / "New: X" banner; the build picker built from the owner's art (title plaque, Blade and Gun frames, emblems) over the Cold-glass backdrop, no glitch. Evidence [`evidence/PLAQUES.md`](evidence/PLAQUES.md) | `v0.6.1 Step PQ` commit |

## Goldens changed on purpose
- none

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| R3 G1: which world pieces get the shard look (answered: shop terminal stays, portals get clusters in their colour; PLAN A1) | 2026-10-09 ([`evidence/SHARD_AUDIT.md`](evidence/SHARD_AUDIT.md)) | A1: shop terminal fine, portals get clusters in their colour; other rows kept (built in SW2) | 2026-10-09 |

## History
- 2026-10-09: plan from the owner's plaque art and shard-look direction; wave 1 (PQ, SW, SD) started.
- 2026-10-09: SD done (shard dressing); targeted tests 27/27, lint clean; owner look check pending.
- 2026-10-09: SW: `ShardMesh` (shared shard builder, for SD too), the shard altars, heal orbs, shard gems and dropped
  cores restyled; the G1 audit (20 rows) waits for the owner's pick.
- 2026-10-09: PQ done (agent): plaques installed and used; the owner's build-picker art (R2b) arrived mid-step and
  replaced the Cold-glass stand-in. Flagged for the owner: the slate plaque is filed as `indigo` (the trinket
  family), purple/violet and amber/orange plaques are close in hue, the boss bar's PHASE SHIFT stays a plain label.
- 2026-10-09: wave 1 merged (SD, SW, PQ); the wave's one full suite on `c2a0f40`: 1383/1383, no SCRIPT ERROR; MIN_TEST_COUNT 1383.
- 2026-10-09: owner answers A1–A5 (PLAN); wave 2 (SW2, SD2) started.
- 2026-10-09: SW2 done (agent): portal shard clusters (A1) and the "Choose your weapon" title (A5); targeted tests
  (presentation 372/372, e2e + arch 16/16), lint clean; owner look check pending.
