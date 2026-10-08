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
| — | Plan: every line of the feedback | `8e248ab` |
| CD | Altar, chest and shop picks show the owner's crystal card frames (12 cropped frames in `assets/ui/cards/`, colour by card family from one table in `CardFrames`, coloured caps title, sentence, rarity line with the card's icon and a rarity gem, glow for rare/epic/ability, cursed offers in the curse frame; text fits in en and es); 3 HUD + pause mockups for the A5 pick ([`evidence/CARDS.md`](evidence/CARDS.md), [`evidence/UI_MOCKUPS.md`](evidence/UI_MOCKUPS.md)) | v0.5.5 Step CD commit |
| EC | Floor 1 is calm for 30 s then ramps faster, floors 2–3 start warm (D1); heal orbs only with the new Lifesprout card (D9); at most 2 altars a floor, the rest chests (S1); shop rerolls keep sold slots and 4 buys a floor (S2, S3); shards −30 %, floor 2–3 shop prices ×1.5 and a portal keeps half the unspent shards (S4, Q-S4); bot balance sims retired (P1). Evidence: [`evidence/ECONOMY.md`](evidence/ECONOMY.md) | `afa3c70` |

## Goldens changed on purpose
- none (Step EC: the replay and export-smoke goldens did not change; the full suite passed against them)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| X1 direction: open floor, sealed arenas, or Isaac rooms | 2026-10-08 | "Time"; "Mostly stream in"; "Yes to the arenas, we are also missing a big reward from killing the boss"; "Others go dark when sealed" → open floor, sealed arenas | 2026-10-08 |
| D4 / D7 growth-matching scaling with a cap | 2026-10-08 | "Yes, but hidden" | 2026-10-08 |
| G1 modifiers M1–M30 | 2026-10-08 | "keep all M1–M30" | 2026-10-08 |
| G1 curses C1–C8 | 2026-10-08 | "curses look good too" | 2026-10-08 |
| Q-S4 unspent shards carry to the next floor? | 2026-10-08 | "Keep half" | 2026-10-08 |
| X2 Echoes / Core theft / Depth descent proposals | 2026-10-08 | "yes to all three, go ahead" (also Deep S5 and Blade B1) | 2026-10-08 |
| X3 EI-05 sub-streams | 2026-10-08 | "Approve" | 2026-10-08 |
| X1b boss reward | 2026-10-08 | "Pick a legendary card" | 2026-10-08 |
| A5 UI mockup pick: A Crystal crown / B Ember stone / C Cold glass ([`evidence/UI_MOCKUPS.md`](evidence/UI_MOCKUPS.md)) | 2026-10-08 | "Menu from C (we don't need to have those crystal those there, or what is the purpose? but ingame UI, heat, health and minimap  from B(we should remove the black background tho)" → pause/menus in C's style without the build cards; HUD, heat bar, health and minimap in B's style, minimap without the black background | 2026-10-08 |
| A4 card family → frame colour mapping (as built in `CardFrames.FAMILY_OF`; see [`evidence/CARDS.md`](evidence/CARDS.md)) | 2026-10-08 | pending (starting mapping) | |

## History
- 2026-10-08: plan written from the owner's v0.5.0 playtest; wave 1 (EC, CD, LK) started.
- 2026-10-08: Step CD done: crystal pick cards and the A5 mockups (the in-game HUD is unchanged until the pick).
- 2026-10-08: Step EC built (`afa3c70`), full suite 1076/1076 and export smoke green; MIN_TEST_COUNT 1086 → 1076
  (the bot tests left, P1). Owner answered Q-S4 "Keep half" (built in EC). Open for the owner: whether the Overrun
  clear's altar counts toward S1's two, and the Blade's card pool at 51 (evidence/ECONOMY.md).
