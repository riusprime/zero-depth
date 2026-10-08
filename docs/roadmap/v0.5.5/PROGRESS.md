# v0.5.5 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf`; a PR into `main` when the build is playable.

## Owner decisions (2026-10-08)
- The owner's feedback on the v0.4.0 + v0.5.0 build, verbatim in [`../v0.5.0/PLAYTEST.md`](../v0.5.0/PLAYTEST.md);
  every line is a row in PLAN.md.
- "From now on not run bot tests, because they do not represent reality" (P1).
- "Spawn 3 agents parallel at max at the same time" (P2).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan: every line of the feedback | this commit |
| CD | Altar, chest and shop picks show the owner's crystal card frames (12 cropped frames in `assets/ui/cards/`, colour by card family from one table in `CardFrames`, coloured caps title, sentence, rarity line with the card's icon and a rarity gem, glow for rare/epic/ability, cursed offers in the curse frame; text fits in en and es); 3 HUD + pause mockups for the A5 pick ([`evidence/CARDS.md`](evidence/CARDS.md), [`evidence/UI_MOCKUPS.md`](evidence/UI_MOCKUPS.md)) | v0.5.5 Step CD commit |

## Goldens changed on purpose
- none

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| X1 direction: open floor, sealed arenas, or Isaac rooms | 2026-10-08 | pending | |
| D4 / D7 growth-matching scaling with a cap | 2026-10-08 | pending | |
| G1 modifiers M1–M30 | 2026-10-08 | pending | |
| G1 curses C1–C8 | 2026-10-08 | pending | |
| Q-S4 unspent shards carry to the next floor? | 2026-10-08 | pending | |
| X2 Echoes / Core theft / Depth descent proposals | 2026-10-08 | pending | |
| X3 EI-05 sub-streams | 2026-10-08 | pending | |
| A5 UI mockup pick: A Crystal crown / B Ember stone / C Cold glass ([`evidence/UI_MOCKUPS.md`](evidence/UI_MOCKUPS.md)) | 2026-10-08 | pending | |
| A4 card family → frame colour mapping (as built in `CardFrames.FAMILY_OF`; see [`evidence/CARDS.md`](evidence/CARDS.md)) | 2026-10-08 | pending (starting mapping) | |

## History
- 2026-10-08: plan written from the owner's v0.5.0 playtest; wave 1 (EC, CD, LK) started.
- 2026-10-08: Step CD done: crystal pick cards and the A5 mockups (the in-game HUD is unchanged until the pick).
