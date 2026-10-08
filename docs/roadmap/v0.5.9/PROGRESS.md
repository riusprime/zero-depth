# v0.5.9 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/keen-volta-ht74pz`, built over `claude/lucid-fermat-9wv2tf` at `5e5b3f9`
(owner, 2026-10-08), not `main`.

## Owner decisions (2026-10-08)
- The target look is [`../../art/look_reference.webp`](../../art/look_reference.webp). Priority: "the lighting and
  occlusion ambience".
- The owner makes 10–20 pieces with an AI 3D generator, and seeded rules place them.
- One shared kit for all 3 biomes, retinted per palette, with a lighting mood per biome.
- The pixel look is decided at the G2 mockup.
- Its own version and branch, merged after the owner verifies it.
- Start now, over the other agent's v0.4.0/v0.5.0 branch: "we can build over that code".

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Draft plan and art list | this commit |

## Goldens changed on purpose
- None

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| G2 Look (A today / B lit / C lit + pixel) | — | pending (Step 2) | |
| Q2 wall heights | 2026-10-08 (PLAN) | pending | |
| Q3 hero light | 2026-10-08 (PLAN) | pending | |

## Open
- `origin/main` has a stray upload of the kit at the repo root (`5bc2917`, 16 `.glb` + 2 `.png`). It is the owner's
  call to remove it from `main` through a PR; this branch takes `dead_tree.glb` from it.
- Kit pieces: [`../../art/KIT_REQUESTS.md`](../../art/KIT_REQUESTS.md), all `requested`.

## Blockers
- None.

## History
- 2026-10-08 — The owner sent the target image and answered four planning questions. Draft PLAN and the kit list
  committed (docs only). Next: the owner makes the pieces; after v0.5.0 merges, Step 0 and the lighting lab.
- 2026-10-08 — Core kit received (15 models, 2 textures) plus `dead_tree`. The owner moved the start forward: merged
  `claude/lucid-fermat-9wv2tf`. Next: Step 1, the lighting lab.
