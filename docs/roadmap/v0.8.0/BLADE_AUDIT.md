# G1: Blade combinations against the Gun's (v0.8.0 O10; status: approved by the owner 2026-10-14)

Owner, 2026-10-14: "the combinations for gun are way better than the combinations for blade. Blade is way more
difficult to get a good, you know, combination of items. And the, I haven't tried them yet, but... Feels like
sometimes you're not getting that that many modifiers in the blade as you get in the gun".

## How it works today (live code, 2026-10-14)
- **Pools:** a card with `requires_weapon` is offered only to that weapon (`src/sim/items/item_pool.gd:58-71`); there
  is **no weapon weighting** in offers (`item_pool.gd:22-33`, `reward_table.gd:16-28`; altar mods are 10 % of altar
  cards, chest mods 30 %). Offerable cards: Blade-only 18, Gun-only 16, shared 24 (the shared ones: triggers,
  elements, Explosive, Bleed, …). So **the Blade isn't offered fewer cards**; it feels that way for the reasons below.
- **Why the Gun stacks and the Blade doesn't:** a Gun card mostly **multiplies the number of shots**, and every shot
  hits and fires the shared cards (On Hit, Explosive, elements) on its own:
  - Spread +2 shots a level (11 at level 5), Twin ×2, Halo ×3, Echo +1, Backfire +1, Split +3 on the first hit
    (+1 a level), Pierce +2 targets, Ricochet +2 bounces.
  - Spread 11 × Twin 2 × Split 4+ × Explosive = **close to 100 explosions a trigger pull**: the owner's 50K-per-enemy
    build (O11) and the lag (O9).
- A Blade card mostly **reshapes the one slash** (Wide Arc, Thrust, Whirl, Long Edge) or **trades** (Heavy ×1.7 but
  30 % slower; Flurry +50 % speed but −25 % damage; Thrust reach ×2 but arc ×0.4). Only Double Slash, Wave (Echo
  Slash), Split Wave and the legendary Echo Storm add hits, and none of them grows with its level the way Spread does.
  A slash hits each enemy once, so the shared on-hit cards fire about once per enemy per swing.
- **Result:** the Gun's cards multiply each other; the Blade's mostly add or trade. Two good Gun cards make a combo;
  two good Blade cards make a bigger slash.

## Rows
| Row | What | Today | Verdict | Proposal |
|---|---|---|---|---|
| **B1** | Blade hit-multipliers grow with level | Double Slash, Wave, Split Wave: fixed count | Weak | **Double Slash** +1 repeat a level (up to 5 slashes at L5, each 70 %); **Wave** +1 crescent a level; **Split Wave** +1 split a level. The Blade gets its own "Spread" |
| **B2** | Trade-off cards | Heavy, Flurry, Thrust lose as much as they give | Niche | Remove the drawbacks at levels 3+ (Heavy's slowdown −10 % a level; Flurry's damage loss shrinks to 0 at L5; Thrust's arc widens a level) |
| **B3** | Blade triggers | On Hit fires once per enemy per swing | Weak for the Blade | A slash hit fires the shared triggers **twice** (Blade only), so trigger builds work on both weapons |
| **B4** | New Blade multiplier cards (2) | none | Missing | **Blade Storm:** each slash throws 2 spinning blades that fly out and back (+1 a level). **Riposte Chain:** a slash that kills slashes again at the next enemy in 4 m (chains 2, +1 a level) |
| **B5** | Offer weighting | none | Fine in numbers, feels thin | A wand card offer favours the run's weapon: its own cards ×1.5 weight against shared cards |
| **B6** | The Gun's top end (O9, O11) | Spread × Twin × Split × Explosive ≈ 100 explosions | Too strong; lags | **Split** shots and hook children can't split or explode again (the first ones do), and Explosive's blasts from one trigger merge past 8. The Gun keeps its feel; the 150K build drops by roughly an order. Numbers measured in PF's probe, not guessed |
| **B7** | Blade elements | Ember Edge, Glacial Edge, Serrated Edge are on-swing statuses | Fine | Keep |

Numbers are starting values; the owner judges the feel in the Playground (DPS meter) and in runs. No bot sims
(LOCKED 2026-10-08).

## Decisions (owner, date)
| Row | Answer | Built in |
|---|---|---|
| B1 | Yes, as proposed (owner, 2026-10-14: "blade audit … OK") | |
| B2 | Yes, as proposed (owner, 2026-10-14: "blade audit … OK") | |
| B3 | Yes, as proposed (owner, 2026-10-14: "blade audit … OK") | |
| B4 | Yes, as proposed (owner, 2026-10-14: "blade audit … OK") | |
| B5 | Yes, as proposed (owner, 2026-10-14: "blade audit … OK") | |
| B6 | Yes, as proposed (owner, 2026-10-14: "blade audit … OK") | |
| B7 | Yes, as proposed (owner, 2026-10-14: "blade audit … OK") | |
