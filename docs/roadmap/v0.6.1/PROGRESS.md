# v0.6.1 — progress

Plan: [`PLAN.md`](PLAN.md). Local on `claude/lucid-fermat-9wv2tf` until v0.6.0's PR (riusprime/zero-depth#3) merges.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| SW2 | Owner A1: shard clusters round both portals, in the portal's own colour (the visor blue; the Deep gate violet), at the pillars' feet and on the lintel's ends with floating fragments; lit by the scene, brighter when open and in the flare; clear of the opening and the walk-in path; the gate's look, animations and cues unchanged (no clusters on the arrival column: a moment of light on the hero's spot, not a place). The shop terminal and the other audit rows kept. Owner A5: the build picker's title "CHOOSE YOUR WEAPON" / "ELIGE TU ARMA". Evidence [`evidence/SHARD_WORLD_2.md`](evidence/SHARD_WORLD_2.md) | `v0.6.1 Step SW2` commit |
| SD | Crystal-shard clusters: a hero cluster with a small cold light at the start room's back wall or corner, small clusters on the generated rooms' back walls (themed density, none in the boss arena, Deep floors violet); presentation only, replay golden unchanged ([evidence](evidence/SHARD_DRESSING.md)) | v0.6.1 Step SD |
| SW | The altars wear the crystal-shard look of the owner's card art (outlined faceted shards on a stone base in the tier's card-frame colour: blue, purple for the Deep epic, gold for the legendary; lit by the mood, a soft glow, floating fragments, brighter in reach); heal orbs, shard gems and dropped cores are outlined shards too. G1 audit of every world piece with model prompts: [`evidence/SHARD_AUDIT.md`](evidence/SHARD_AUDIT.md); evidence [`evidence/SHARD_WORLD.md`](evidence/SHARD_WORLD.md) | this commit |
| SD4 | Owner A3c: crystals on about a fifth of a room's free wall base (ordinary rooms 0.235, start rooms 0.205 measured), mostly in corners (94 % of the ordinary rooms' wall crystals within 6 m of a corner). They touch only stone (walls, rocks, stone slabs; never crates, wrecks, dead trees or light props), and the start room is no longer crystal-rich. 1–2 crystal rooms a floor (smaller rooms with bare stone walls first; never start, boss, shop, shrine or event rooms) have 0.72 of their wall base covered and big crystals about the 1 × 1 m stone blocks' size. The vein field was removed. Presentation only; replay golden unchanged ([evidence](evidence/SHARD_DRESSING_4.md)) | v0.6.1 Step SD4 |
| SD3 | Owner A3b: the crystals grow from the floor, never on or in a wall. They stand at the base of walls (within 0.7 m), fuller in the corners of some rooms, and round rocks, crates, wrecks and slabs. SD2's uneven veins, the denser small rooms, the crystal-rich start room and every room ≥ 1 are kept, and the boss arena stays bare. Camera-side faces stay under 0.6 m (0.9 m side-on). Doorway, reward, spawn, start and path clearances are kept, and no crystal footprint reaches past 0.7 m into the walkable floor. Presentation only; replay golden unchanged ([evidence](evidence/SHARD_DRESSING_3.md)) | v0.6.1 Step SD3 |
| SD2 | Owner A3: crystals in every room but the boss arena, uneven. A vein field per floor (3–5 dense zones on room walls) drives how often and how big the clusters are along every wall, and smaller rooms' walls get more. The start room is crystal-rich (the hero cluster plus about 99 % of its free wall length lined, median 73 clusters). Camera-side walls get only low tips (≤ 1.4 m, no fragments), and vein crystals are bigger and a little brighter. Presentation only; replay golden unchanged ([evidence](evidence/SHARD_DRESSING_2.md)). The placement on and in walls was replaced by SD3 | v0.6.1 Step SD2 |
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
- 2026-10-09: SD2 done (agent): denser, uneven shard dressing (owner A3). Targeted tests 31/31, lint clean; the boss arena stays bare (agent's call); the owner's look check is pending.
- 2026-10-09: SD3 done (agent, owner A3b): the crystals grow from the floor along walls, in corners and round obstacles. Targeted tests 32/32, lint clean. The shards2_* shots were replaced. The owner's look check is pending.
- 2026-10-09: SD4 done (agent, owner A3c): a fifth of a room, mostly corners, only on stone, and crystal rooms. Targeted tests 33/33, lint clean. The shards2_* shots were replaced. Open owner question: should crystal rooms follow a specific room template ("a themed one")?
- 2026-10-10: wave 2 merged (SW2, SD2→SD4); the wave's one full suite on `cbb530e`: 1395/1395, no SCRIPT ERROR; MIN_TEST_COUNT 1395.
