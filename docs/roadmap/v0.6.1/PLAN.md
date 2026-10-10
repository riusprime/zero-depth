# v0.6.1 — Shard look: plaques, the build picker and shard-style world pieces (plan, owner-directed 2026-10-09)

Progress: [`PROGRESS.md`](PROGRESS.md). Built while v0.6.0 (riusprime/zero-depth#3) waits for the owner's playtest;
this work stays local until that PR is merged, so the PR's test run isn't restarted (owner: "we can start working
on that and leave the current PR for playtest running its test").

## Owner lines (2026-10-09, verbatim)
| # | Owner line | Decision | Status | Step |
|---|---|---|---|---|
| R1 | [12 empty wide crystal plaques, `refs/plaque_templates_empty.webp`] "does this fit the arts missing for the old card look?" | Yes. Cropped like the card frames, drawn as three-part (nine-slice) plaques so they stretch to any width; used for the combo badges and pop-up, event choices, shop rows, the shrine's gamble cards, item/pickup pop-ups and banners. Colour by card family (the card-frame table) | Decided | PQ |
| R2 | "give me a prompt for the build picker, to generate the elements based on what we have" | Prompts in [`../../art/requests/v0.6.1_build_picker.md`](../../art/requests/v0.6.1_build_picker.md). Until the art arrives the build picker moves to Cold glass (the menus' style) | Decided | PQ |
| R2b | [the build-picker art: `refs/build_title_plaque.webp`, `refs/build_card_frames.webp` (Blade cyan, Gun amber), `refs/build_emblems.webp` (crystal sword, crystal pistol), delivered 2026-10-09] | Installed in the build picker instead of the Cold-glass stand-in: cropped like the card frames, the title in the plaque, each build card = frame + emblem + name/description drawn by the game (en + es) | Decided | PQ |
| R3 | "we'd have to also modify some renders in game to match the more shard like style like altars or other elements" | G1 audit of every world piece vs the shard style (altars, reward pedestals, shop terminal, event pedestal, portals, heal orbs, shard pickups, cores, the boss-room door…); altars restyled now (code-built shard look, lit by v0.5.9); the rest by the owner's G1 pick, with art prompts where a model is better | Decided (altars) / G1 (rest) | SW |
| R4 | "we could also add to the generation map or the initial room the shard looks, but that would be for v0.6.1" | Crystal-shard clusters as dressing: the start room gets a hero cluster; ordinary rooms get small clusters through the v0.5.9 dresser (presentation only, seeded, the same spacing rules); glow lit by the scene | Decided | SD |

## Owner answers (2026-10-09, verbatim)
| # | Question | Owner answer | Decision | Step |
|---|---|---|---|---|
| A1 | Which other world pieces get the shard look (SHARD_AUDIT.md) | "the shop terminal is fine, the portals could have some of them around matching the color of the portal" | The shop terminal stays; portals get shard clusters around them in the portal's colour (normal blue, Deep violet); the other audit rows stay as they are | SW2 |
| A2 | Epic altar gold instead of violet? | "no" | Stays violet | — |
| A3 | Room crystals bigger, brighter or more frequent? | "Very frequent on the starting room and be an element of all rooms, but disparity not all equally distributid some zones have more density than others, specially walls at smaller rooms" | Start room: many clusters. Every room gets crystals. Uneven: a few dense zones (veins) per floor and sparse stretches; walls of smaller rooms get more | SD2 |
| A3b | (after SD2's shots) | "yeah but not on top of the walls it should be floor closed to the walls, corners of some rooms, and other obstacle like they grow from the ground" | No crystals on or in walls; clusters grow from the floor at wall bases, in the corners of some rooms and round obstacles; decorative (no collision), kept tight so the hero rarely overlaps them | SD3 |
| A3c | (after SD3's shots) | "okay you sent an image of a big room full of crystals, that should be not happening only about a 20% of the room should have, and mostly corners, the only items that should be touching these are rock materials, no cars, barrels, or wood, just stone, the small room I was talking about was a themed one, where there is a noticable higher percentage with bigger cristals, size of the 1x1 rock stones that are in some rooms as walls and smaller ones, but always close to the walls" | Ordinary rooms (the start room included, lead's reading): crystals on about 20 % of the room's wall base, mostly in corners. They touch only stone: walls, rocks and stone slabs; never cars, barrels, crates or wood. One or two **crystal rooms** per floor (smaller rooms first, presentation-only pick on the cosmetic stream) with a clearly higher share and big crystals the size of the 1×1 m rock blocks plus smaller ones, always close to the walls | SD4 |
| A4 | Violet vs purple, amber vs orange plaques | "that's fine" | Kept | — |
| A5 | Build picker title | "yes, choose weapon" | "Choose your weapon" / "Elige tu arma" | SW2 |

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
