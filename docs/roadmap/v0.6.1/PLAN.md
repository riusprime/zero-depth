# v0.6.1 — Shard look: plaques, the build picker and shard-style world pieces (plan, owner-directed 2026-10-09)

Progress: [`PROGRESS.md`](PROGRESS.md). Built while v0.6.0 (riusprime/zero-depth#3) waits for the owner's playtest;
this work stays local until that PR is merged, so the PR's test run isn't restarted (owner: "we can start working
on that and leave the current PR for playtest running its test").

## Owner lines (2026-10-09, verbatim)
| # | Owner line | Decision | Status | Step |
|---|---|---|---|---|
| R1 | [12 empty wide crystal plaques, `refs/plaque_templates_empty.webp`] "does this fit the arts missing for the old card look?" | Yes. Cropped like the card frames, drawn as three-part (nine-slice) plaques so they stretch to any width; used for the combo badges and pop-up, event choices, shop rows, the shrine's gamble cards, item/pickup pop-ups and banners. Colour by card family (the card-frame table) | Decided | PQ |
| R2 | "give me a prompt for the build picker, to generate the elements based on what we have" | Prompts in [`../../art/requests/v0.6.1_build_picker.md`](../../art/requests/v0.6.1_build_picker.md). Until the art arrives the build picker moves to Cold glass (the menus' style) | Decided | PQ |
| R3 | "we'd have to also modify some renders in game to match the more shard like style like altars or other elements" | G1 audit of every world piece vs the shard style (altars, reward pedestals, shop terminal, event pedestal, portals, heal orbs, shard pickups, cores, the boss-room door…); altars restyled now (code-built shard look, lit by v0.5.9); the rest by the owner's G1 pick, with art prompts where a model is better | Decided (altars) / G1 (rest) | SW |
| R4 | "we could also add to the generation map or the initial room the shard looks, but that would be for v0.6.1" | Crystal-shard clusters as dressing: the start room gets a hero cluster; ordinary rooms get small clusters through the v0.5.9 dresser (presentation only, seeded, the same spacing rules); glow lit by the scene | Decided | SD |

## Rules
- Nothing from the v0.5.9 visual rework or v0.6.0 is removed; shard pieces layer on top.
- Testing (owner, 2026-10-09): agents run lint + the tests of what they touched; the lead runs one full suite after
  the wave.

## Steps
| Step | Scope | Rows |
|---|---|---|
| PQ | Plaques installed and used; the build picker in Cold glass; the art request for the build picker | R1, R2 |
| SW | Shard-style world pieces: G1 audit, altars restyled, prompts for model requests | R3 |
| SD | Shard dressing: the start room and the generated rooms | R4 |
