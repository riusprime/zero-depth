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
| SH | One shop per floor in a side room (a terminal: E / pad X): 4 cards from the chests' pools priced by rarity × floor (30 / 55 / 90 × 1, 1.5, 2), a heal (30 % max HP, once, 40 × floor), a reroll (20, +50 % per use); salvage at the same panel (a mod or stat card for 40 % of its price, an ability but the weapon for 25 shards per level, freeing its slot); minimap icon, sounds, en + es ([`evidence/SHOP.md`](evidence/SHOP.md)) | `v0.5.0 Step SH: shops and salvage` (this branch) |

## Goldens changed on purpose
- none

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Card pool count: per build or whole game | 2026-10-07 | "Per build" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.

## Blockers
- none

## History
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
