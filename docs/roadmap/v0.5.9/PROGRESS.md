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
- G2: **B** (not pixelated), keep wall heights, add the hero light: "B, keep wall heights, yes to the hero light".
- New line L8 (room layouts): "rework of how rooms generate … distinct objects and combinations of them while keeping
  a logical and structured way of items to spawn, I dont want the slabs doing a 9x9 diagonal wall design, I want it
  kinda like the image reference … saving the spacing we have now so the game still has its mobility". Design
  proposal in PLAN "L8"; not built until the owner answers its questions.

- Bot sims: "okay bot runs don't matter anymore, i cleared every single time I played v0.5 really easy, so sims
  here are almost useless" (2026-10-08). The bots die on floor 1 in most runs (evidence/LOOK.md §4), so they are far
  weaker than the owner. Balance and difficulty go by the owner's play, not the scorecard, until the bots are
  rebuilt. Step 7 doesn't wait on scorecard re-runs.

- Scope (owner, 2026-10-08): "the feedback from v0.50 fix does not belong to you, you are just in charge of the art
  rework". This version's lead does the look, the kit and the themed rooms; the v0.5.0 feedback fixes and tuning
  belong to the other agent.

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Draft plan and art list | this commit |

## Goldens changed on purpose
- None

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| G2 Look (A today / B lit + kit / C B pixelated) | 2026-10-08 (`scripts/shots/mock_look.gd`, 3 biomes, hero and fire views) | **B** ("B, keep wall heights, yes to the hero light") | 2026-10-08 |
| Q2 wall heights | 2026-10-08 (PLAN) | keep (1.0 m / 1.8 m) | 2026-10-08 |
| Q3 hero light | 2026-10-08 (PLAN) | yes | 2026-10-08 |
| Q4-Q6 room rework (where, timing, mockup first) | 2026-10-08 (PLAN L8) | in v0.5.9; after the balancing (done); mockups first | 2026-10-08 |
| G2 Rooms (room themes, mock_rooms.gd) | 2026-10-08 (4 themes) | all 4; density "about right"; cars max 2 per room of the mockups' size, more in proportion in bigger rooms; "go ahead and implement these variants" | 2026-10-08 |

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
- 2026-10-08 — Step 7 themed rooms (`8616a2d`, fixes `a8f6958`): full suite 1107/1107 at `a8f6958`. Scorecard
  before and after in evidence/LOOK.md §4: floor-1 deaths 86.8 % → 91.8 % (normal policies), Ruins +11 pp, biome
  spread 11.6 → 2.9 pp; competent floor-1 clears 19 → 17 of 160. Not tuned (the v0.5.0 feedback and tuning belong to
  the other agent).
- 2026-10-09 — After the merge: VFX pass for fire, bombs and electric (`docs/art/VFX_REQUESTS.md`). The owner's 9
  textures prepared (`281e4f1`); VfxLayer wired into the attack forms (`8a5af92`); G2 Effects: **after** ("Yep I
  love the after this is the direction I want"); polish `a78648e`. Full suite (`bash scripts/verify.sh`, clean
  worktree at `a78648e`): 1354/1354 passing. Next: the fading fireball and smoke still read weakly; frost, venom,
  void and bleed; burning enemies.
- 2026-10-09 — VFX phase 2 (`docs/art/VFX_REQUESTS.md`): the owner's 8 textures prepared (`ee773f0`; ice shards not
  delivered, built as 3D crystals); frost, venom, void and bleed on every form, enemy statuses and payoffs in the
  effects layer (`a2eb4da`); fixes `99ded37`, `4258c13`. Full suite (`bash scripts/verify.sh`, clean worktree at
  `a2eb4da`): 1358/1358 passing. The fixes after it ran the VFX tests only (10/10). G2 Effects phase 2: OWNER ONLY.
