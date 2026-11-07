# v0.11.0 G1 — where the Pierce card is offered (approve or change)

From the owner's answers Q5 and Q28 (2026-11-07): "piercing would not appear for all the attacks that don't need it like
lance, void, wave, etc, it would only appear as an option if you have a compatible attack form"; the Laser pierces
everything and never offers the card.

## What the code does today
Each Gun form has an `allowed` card list (`data/wand/attack_slots.tres`). A card is offered only if the form you fire
now allows it (`AttackSlots.usable`, `src/sim/abilities/attack_slots.gd:154`). Pierce (`gun_pierce`) is **already
allowed only** for: the plain bolt, the Laser, Seekers and Wisps. Lance, Void, Wave, Glaive and Rune Explosion don't
allow it.

**Why you still saw it:** before you take a form card, your form is the plain bolt, which allows Pierce. So Pierce can
be offered early, and then do nothing once you switch to Lance, Void or Wave (a held card a form doesn't allow is not
compiled; it stays in the wand, inactive).

## The list (approve or change each)

| Form | Pierce offered? | Why |
|---|---|---|
| Plain bolt | yes | it changes the bolt (passes through enemies) |
| Seekers | yes | each dart hits more enemies |
| Wisps | yes | adds to the wisps' own +1 pierce |
| Laser | **no** (change) | it pierces everything from v0.11.0 (Q28) |
| Lance, Void, Wave, Glaive, Rune Explosion | no (as today) | they already pass through everything, or burst |

## One extra the lead proposes (approve or cut)
- **P1.** Pierce is never offered before you hold a form card (so the plain bolt's early offers skip it).
- **P2.** Keep the early offer, but when you take a form that doesn't use Pierce, the held Pierce card shows a "does
  nothing with this form" flag on the wand screen (like the v0.8.0 MR flag for a card placed where it can't act) and
  can be swapped.

The lead recommends **P2**: early runs keep the bolt's Pierce, and the wand tells you plainly when it stops working.

Built with the Laser (O1) and S6.
