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
| G2 Look (A today / B lit + kit / C B pixelated) | 2026-10-08 (`scripts/shots/mock_look.gd`, 3 biomes, hero and fire views) | pending | |
| Q2 wall heights | 2026-10-08 (PLAN) | pending | |
| Q3 hero light | 2026-10-08 (PLAN) | pending | |

## Open
- `origin/main` has a stray upload of the kit at the repo root (`5bc2917`, 16 `.glb` + 2 `.png`). It is the owner's
  call to remove it from `main` through a PR; this branch takes `dead_tree.glb` from it.
- Kit pieces: [`../../art/KIT_REQUESTS.md`](../../art/KIT_REQUESTS.md). The 15 core models, both ground textures and
  `dead_tree` are delivered (`fbedd6d`); 5 biome extras are still requested.
- Step 1: `look_contrast.gd` (on-screen contrast evidence) NOT YET RUN.
- Step 2: the G2 pick (A / B / C) is the owner's; C is a post-processed approximation (evidence/LOOK.md §4).
- Step 4: the property tests run 40 seeds per rule; the PLAN asks for 1,000. NOT YET RUN at 1,000.
- Step 6: view bench with the dressed, lit floor NOT YET RUN. Kit pieces are 7-14k triangles; LODs are generated
  at load. Whether an exported build generates them is NOT YET checked.

## Blockers
- None.

## History
- 2026-10-08 — The owner sent the target image and answered four planning questions. Draft PLAN and the kit list
  committed (docs only). Next: the owner makes the pieces; after v0.5.0 merges, Step 0 and the lighting lab.
- 2026-10-08 — Core kit received (15 models, 2 textures) plus `dead_tree`. The owner moved the start forward: merged
  `claude/lucid-fermat-9wv2tf`. Next: Step 1, the lighting lab.
- 2026-10-08 — Step 1 (`9f4866c`): biome moods, geometric contact shadows (SSAO measured too weak under the
  ortho camera, evidence/LOOK.md §1), Lighting quality option; the full suite passes 1083/1083. Steps 3-4
  (`fbedd6d`): kit prep, KitModels, StageDresser, StageKit, textured ground. Step 5 (`cafb6db`): the owner's
  chest with an opening lid. G2 mockup renders A / B / C. Next: the G2 pick, contrast evidence, bench.
