# v0.5.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3).

## Owner decisions (2026-10-07)
- "skip the rule, keep going to v0.5.0" (ROADMAP §0.3 waived once).
- The 40–50 card pool moves here and is built now; counted **per build** (owner pick: "Per build").

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| CP | Five new stat cards that force choices (Glass Cannon, Onrush, Overkill, Hoarder, Fast Hands) and four ability mods (Cluster Payload, Overclocked Drone, Razor Orbit, Afterimage), offered only with their ability; pool per build Blade 50 / Gun 48 (58 in all); no dead cards over 300 seeds per build ([`evidence/CARD_POOL.md`](evidence/CARD_POOL.md)) | `2f7951f`, merge `1dbd7fb` |
| SH | A shop terminal per floor (a side room, usually a dead end; never the Overrun room): 4 cards (30/55/90 × floor step), a heal (30 %), rerolls (20, +50 %); sell a mod or stat card for 40 %, salvage an ability for 25/level to free its slot ([`evidence/SHOP.md`](evidence/SHOP.md)) | `706f033`, `e98c807`, merge `0f86c77`, fix `b010603` |
| RT | After floors 1–2 the boss room opens a normal and a violet **Deep** portal; Deep floors ×1.25 enemies, +1 chest, a free epic altar; floor card/label/recap name the route; routes are saved ([`evidence/ROUTES.md`](evidence/ROUTES.md)) | `7db9887`, `5174057`, merge `e4fec48` |
| SH | One shop per floor in a side room (a terminal: E / pad X): 4 cards from the chests' pools priced by rarity × floor (30 / 55 / 90 × 1, 1.5, 2), a heal (30 % max HP, once, 40 × floor), a reroll (20, +50 % per use); salvage at the same panel (a mod or stat card for 40 % of its price, an ability but the weapon for 25 shards per level, freeing its slot); minimap icon, sounds, en + es ([`evidence/SHOP.md`](evidence/SHOP.md)) | `v0.5.0 Step SH: shops and salvage` (this branch) |
| EV | 1–2 event rooms per floor (a lit pedestal, a panel of costed choices and "Leave it"; eight events), six curses (each +1 threat T) on 25 % of chest offers and on some event choices, a cleanse (the Cleansing Font, and a hook for shops), T on the HUD, in the pause menu and the recap ([`evidence/EVENTS.md`](evidence/EVENTS.md)) | `v0.5.0 Step EV` commit |

## Goldens changed on purpose
- none

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Card pool count: per build or whole game | 2026-10-07 | "Per build" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.
- EV (lead, for the owner): curses are fixed drawbacks, not CONTENT_SCHEMA §7's T-indexed `ThreatModifier` tables
  (still unbuilt); the elite rule (+100 % HP, a crown) is EV's own until SC sets a shared one; Echo Mirror repeats
  the stat raised most and Wandering Drone is a defence (PLAN, step EV). The three new streams are sub-streams
  (`map:event`, `loot:event`, `ai:elite`), like `ai:enemy`; EI-05's named list is unchanged: confirm or amend.

## Blockers
- none

## History
- 2026-10-08 — EV merged with the lead branch (`d5450d9`: SC, AB, SV, SH) in the EV worktree: 1012 tests pass,
  readable cause 0 violations over 36 runs, export smoke 0 misses; goldens unchanged. The three EV sub-streams
  (`map:event`, `loot:event`, `ai:elite`) await the owner's approval.
- 2026-10-08 — EV built on `ac62796` (events, curses, threat T); goldens unchanged; evidence in
  [`evidence/EVENTS.md`](evidence/EVENTS.md).
- 2026-10-07 — CP built (on v0.4.0 BS) and merged on top of v0.4.0 EN + BO: 864 tests pass; goldens unchanged. The
  brief's "≈8 stat cards + ≈6–8 mods" would have overshot 50 per build; CP added 5 + 4 to fit. Owner: count per
  build. PLAN written for the rest of v0.5.0.
- 2026-10-08 — `main` now exists (from `55a895d`); Windows/Shots CI run only on `main`. Owner: PRs into `main` only for a
  playable version ("only push to main when we get something"): the next PR is the v0.4.0 + v0.5.0 build.
- 2026-10-08 — SH built on `ac62796`: shops (ShopPlacement: its own pass and stream `shop_room`; 1,000 seeds, every
  floor one shop, 963 in a dead end) and salvage in the sim (`Shop`, `ShopState`, `ShopTable`, `data/shop/terminal.tres`),
  the terminal model, the shop panel (FACET cards, keyboard / pad / mouse), minimap icon + legend, three generated
  sounds; suite 891 (minimum raised from 864); goldens unchanged. Lead calls the owner may change: ability cards
  are priced by their rarity like the rest (common 30 / rare 55); the reroll's price doesn't rise by floor; the heal
  is refused at full HP; a salvaged ability's mods stay owned (inert) and can be sold; selling a stat card rebuilds
  the stat values from the cards left in the order taken, then the gamble shrine's stat wins.
- 2026-10-08 — SH merged with v0.4.0 SC (`55a895d`): `test_e2e_horde_enemies` failed on the Shield Bearer (bash never
  landed in 900 frames). Root cause, not a sim bug: the shop terminal takes one entity id at floor setup
  (`Shop.place` → `take_root`), shifting every later actor id by one; SC's AI is staggered by id, so the crowd's
  schedule moved, and the floor's own Chargers and Needle plus the earlier-spawned Swarmer and Splitter knocked the
  God-mode player out of both of the Bearer's locked bash lanes during their windups (traced; confirmed by giving the
  terminal an id outside the counter: the test passed). The test assumed a player standing still stays in front of a
  slow-turning enemy; it now stands up to the Bearer with the left stick (steps back within 1.4 m whenever knocked
  away), same bar (telegraph drawn and its HIT on the player), and passes with the shop, with the id shift removed
  and with no shop. Suite 918 / 918 (minimum 918); export smoke 0 misses.
- 2026-10-08 — SH merged on AB+SV (shop kept out of the Overrun room; shop state in saves; a sell test fixed for ability
  combos): 974 tests. RT merged (its agent integrated AB+SV+SH; routes in the save, PAYLOAD_VERSION 2): 996 tests.
  Open: +1 threat per Deep floor waits for EV; entry particles stay light blue on the Deep gate.
