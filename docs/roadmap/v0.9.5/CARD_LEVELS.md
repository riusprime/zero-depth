# v0.9.5 G1: which cards keep levels (CARD_LEVELS)

**Owner (2026-10-25, G6):** "some card have levels and doesnt make sense for them, for example pierce or swirl or
homing, we have to go every each card and get levels out of what are needed"
**Owner (G7):** "when you modify your form attack you should not be getting pulse gun anymore, since it doesnt really
make sense in the context, the levels for attack forms should also go, damage will come from stats cards."

**How to answer:** row by row ("C1 yes, C5 no keep 5 levels, …"). Blade cards wait for v0.10.0 (G11), as do the
ability cards (Blink, Drone, …) and the stat cards: they keep their levels, because their levels are their point.

## Today (live code)
- `CardLevels` (`src/sim/abilities/card_levels.gd`): every `wand` card goes from level 1 to 5. A duplicate levels it up
  and takes no slot. Per-level ops live in `data/modifiers/*.tres` (`per_level`).
- Most levels add +5–10 % of something you can't see.
- **Threadline, Swirl, Gravity Stitch and the trigger cards already do nothing per level**, yet they still level up,
  so their copies 2 to 5 are dead offers.

## Rule proposed
- **No-level card:** offered once. When you hold it, it never shows up again. That frees offers for cards you
  don't have.
- **Levelled card:** 3 levels at most, the same as elements. Each level is a step you can see (a count, a size).
- **Fixed value:** a no-level card keeps one value, picked as about its Lv 3 today, so taking it once is as good as
  three copies were.
- **Old saves:** a no-level card above Lv 1 drops to 1; a levelled card above 3 drops to 3. No refund, as with
  v0.9.0's trims.

## Gun cards
| ID | Card | Levels today | Proposal |
|---|---|---|---|
| C1 | Pierce | 2 +1 per level | **No level:** pierce 4 |
| C2 | Homing | 360 °/s +90 | **No level:** 540 °/s |
| C3 | Swirl | nothing per level | **No level** |
| C4 | Spiral | ×1.0 +0.1 | **No level** (×1.2) |
| C5 | Ricochet | 2 bounces +1 | **No level:** 3 bounces |
| C6 | Echo | 50 % +5 | **No level:** 60 % |
| C7 | Big Shot | ×2.0 radius / ×1.6 damage, +0.1 each | **No level:** ×2.2 radius, ×1.8 damage |
| C8 | Rapid Fire | ramp cap 60 % +15 | **No level:** ramp cap 90 % |
| C9 | Mine | waits 3.0 s +0.5 | **No level:** 4.0 s |
| C10 | Orbit | ×1.0 +0.1 | **No level** (×1.2) |
| C11 | Backfire | ×1.0 +0.1 | **No level** (×1.2) |
| C12 | Threadline† | nothing per level | **No level** (if kept, Q16) |
| C13 | Ring | radius 1.4 +0.2 | **No level:** 2.0 m |
| C14 | Twin | 2 copies 60 %→90 %, 3 at Lv 5 | **3 levels:** Lv 1 two copies at 70 %, Lv 2 two at 90 %, Lv 3 three at 75 % (fanned 15°) |
| C15 | Halo | 3 shots +1 | **3 levels:** 4 / 6 / 8 shots |
| C16 | Split | 3 pieces +1 | **3 levels:** 2 / 3 / 4 pieces |
| C17 | Elements (5) | +5 % damage | **3 levels**, each with a behaviour: [`ELEMENTS.md`](ELEMENTS.md) |

## Forms and the Pulse Gun (G7)
| ID | Card | Today | Proposal |
|---|---|---|---|
| C18 | The 9 form cards (Laser, Bomb, Void, Lance, Rune Explosion, Glaive, Seekers, Wave, Wisps) | 5 levels, +5 % damage each | **No level.** A form is offered only when you don't hold it. Its damage is fixed at today's Lv 1 (damage comes from stat cards, as the owner says) |
| C19 | Pulse Gun (the weapon ability: ×1.00 → ×1.48 damage, a second orb at Lv 5) | Always offered until Lv 5, whatever form you hold (`Abilities.can_take`, `abilities.gd:83`) | **Removed from offers.** No levels for anyone. The plain Orbs keep today's Lv 1 damage. To make up the lost ×1.48 for an Orbs-only build, the Damage stat card's first pick appears 1 room earlier. (**Alternative C19b:** the Pulse Gun stays, with 3 levels, offered only while you have no form card.) |

## Shared cards
| ID | Card | Proposal |
|---|---|---|
| C20 | Faultline | **No level** (its eruption fixed at today's Lv 3) |
| C21 | Stress Mark | Rebuilt without levels (Q14) |
| — | Gravity Stitch, Double Exposure, Grand Finale, the 7 trigger cards | Removed (G4, G8: direct, step RC) |

## How it is built (once approved)
- `CardLevels.max_level(id)` reads a new `level_max` field on the item (default 1; 3 for C14–C17).
- `Offers` filters out a held card at its max.
- The per-level ops move to their fixed values.
- The level pips on the Build page show only for levelled cards.
- **Tests:** offers never repeat a held no-level card; old saves trim; `test_e2e_card_levels.gd` follows the new caps.

## Decisions (owner, date)
| ID | Answer | Built in |
|---|---|---|
| C1–C21 (C19 as written: the Pulse Gun leaves the offers) | Approved as written (owner, 2026-10-25, in chat) | |
