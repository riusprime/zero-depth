# v0.8.0 FL: floor-paced loot (evidence)

Owner line O91 ([`../BALANCE_PASS.md`](../BALANCE_PASS.md) "FL"). Contract: SIM_CONTRACTS §8m; schema:
CONTENT_SCHEMA (`LootPacingDefinition`, `ItemDefinition.loot_category`, `LegendaryDefinition.upgrade_choice` /
`card_categories`). Branch `v080-fl` from RM's WIP `360daca0`.

## Status

| Check | Status |
|---|---|
| `gdformat --check src scripts tests` + `gdlint src scripts tests` | passed locally (phase 1) |
| Godot import, the touched tests and their e2e | NOT YET RUN |
| `scripts/checks/rarity_odds.gd` | NOT YET RUN |
| `scripts/checks/card_pool.gd` | NOT YET RUN |
| Whether builds feel like they develop; the jackpot's rarity in play | OWNER ONLY |

## The category mapping (`loot_category` in `data/items/*.tres`)

Rule used: **form** changes the attack's shape or path on its own; **element** is a shared status card (S1–S7);
**advanced** multiplies, repeats, or builds on other cards or on a play pattern (the remnant cards, the legendary ×2
triggers); **trigger** is T1–T4; **mutation** is a mutation. Stat cards are their own category (an `Offers` STAT code,
weights unchanged). Every other live item (the v0.3–v0.5 passives: Bulwark, Cold Snap, Executioner, Heat Sink, Kinetic
Dash, Meltdown, Momentum, Phase Strike, Swift Feet, Thermal Edge, Thorn Mantle, Vampiric Core, Wildfire) and every
retired card is `other` (× 1 everywhere).

| Pool | form | advanced |
|---|---|---|
| Gun | Big Shot, Rapid Fire, Spread, Pierce, Ricochet, Homing, Boomerang, Orbit, Spiral, Mine, Backfire, Ring, Swirl | Twin, Split, Charge, Echo, Halo, Threadline |
| Blade | Wide Arc, Wave, Whirl, Thrust, Heavy, Flurry, Fissure, Chain Cut, Parry Edge, Lunge Step, Orbit Blades, Counter | Split Wave, Double Slash, Dodge Imprint, Fracture Bank, Blade Storm, Riposte Chain |
| Shared | — | Chain Blast (Legendary), Faultline, Gravity Stitch, Stress Mark |

- **element:** Fire (`ember_core`), Lightning (`storm_core`), Frost (`frost_core`), Venom (`venom_core`), Bleed
  (`shared_bleed`), Void (`gravity_well`), Explosive (`shared_explosive`).
- **trigger:** On Hit, On Kill, On End, On Finisher / On Crit.
- **advanced (legendary triggers):** On Hit ×2, On Kill ×2, On End ×2.
- **mutation:** Double Exposure, Grand Finale.

Judgement calls, for the owner to change in the data if they read otherwise:
- **Spread** is `form` (BALANCE_PASS's table lists it there), though it multiplies like Twin and Halo.
- **Ring** and **Swirl** (v0.8.0 AO, rare) are `form`: each turns the shot into a new shape on its own.
- **Dodge Imprint** is `advanced`: it acts only with a dash pattern, and it is one of RM's reworked remnant-era cards.
- **Gravity Stitch, Stress Mark** (shared, S9–S10) are `advanced` as remnant cards, not elements.
- **Chain Blast** (Legendary, "your attack and its splits all explode") is `advanced`.

## Starting values (`data/rewards/pacing.tres`)

| Stage | form | element | advanced | trigger | mutation | ceiling | guaranteed altars |
|---|---|---|---|---|---|---|---|
| Floor 1 | 1400 | 1400 | 400 | 600 | 20 | 2 | 2 |
| Floor 2 | 1000 | 1000 | 1000 | 1200 | 100 | 3 | 0 |
| Floor 3 | 900 | 900 | 1200 | 1200 | 300 | 5 | 0 |
| Deep floors and loops ≥ 2 | 800 | 800 | 1300 | 1200 | 600 | 5 | 0 |

`jackpot_permille` 15. Weights are per mille of the card's weight before FL; integer math rounds down, so a mutation on
floor 1 (legendary tier 20 × its own 150 ‰ = 3, × 20 ‰) weighs 0 at an altar: on floor 1 it comes only by a jackpot.

## Where each source meets the rule

| Source | How |
|---|---|
| Altars, chests | `Offers.draw` → `ItemPool.available` (ceiling) + `card_weight` (× category); `Offers.roll` adds the guarantee (regular altars) and the jackpot (regular altars and chests) |
| Shop restock, reroll | `Offers.draw(w, true, n)`; buying checks `Shop.can_apply` (ceiling) |
| Events | `Events._mod`: `ItemPool.available` + weights × category; the choice's block is `Shop.can_apply` |
| Stolen cores, Marked | `CoreTheft.draw_card`: `ItemPool.available` + weights × category; at the drop `Shop.can_apply` re-checks and redraws |
| Boss's altar | `Offers.roll_legendary`: upgrade to the next stage's ceiling, an advanced / trigger card, legendary stats |
| Overrun, Deep epic altar | ability cards and epic stat cards only: no wand card, nothing to pace |
| Dev panel grants | exempt (`CardLevels.can_take(..., MAX_LEVEL)`) |

## Measurements

NOT YET RUN. Phase 2 pastes the exact commands, the raw output and the build SHA here (`scripts/checks/rarity_odds.gd`
with the shipped pacing and with `pacing=0`; `scripts/checks/card_pool.gd`, which builds its worlds without a pacing
table and so measures the pool, not the pacing).
