# v0.10.5 W3-O9 G2: three shop layouts

PLAN row F24. The owner, 2026-11-04 (playtest): "The current card format is too large. Having more than 10 cards
makes the shop excessively crowded. It's difficult to see all available cards and elements simultaneously. The
reroll cost is not clearly visible. The interface feels like everything has been placed together without a cohesive
layout. Overall, the shop doesn't feel like a polished video game store." Then: "it should only show the heal, reroll
and the 4 cards". W3-O9 part A built that (no selling, no curse lift); this is the G2 for the layout of that smaller
shop. **Decide:** A, B, C or a mix. Nothing here is built yet.

**How the shots were made.** `scripts/shots/mock_shop.gd` (a prototype, not game code) starts the dev stage run
(fixed seed `Main.STAGE_SEED`, floor 1, 120 shards, half HP), opens the real shop by the stall with E, takes the
current panel, then hides it and lays each mockup over the same game frame. The mockups use the game's own pieces
(the stone cards with their element and star glyph badges, the shard icon, the stone plates) and only existing
translated strings. 1920×1080, English and Spanish:

```
godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/mock_shop.gd [-- --lang=es]
```

Files (in `build/shots/v0.10.5/w3o9/`, not tracked): `current_shop.png`, `mock_a.png`, `mock_b.png`, `mock_c.png`,
and the same with `_es`. Card prices in every shot are the sim's (`Shop.read`).

**Current (after part A).** The 4 cards at 0.92 of the pick's size, prices in small type under them, then the heal
and reroll plaques. With selling gone the crowding is gone, but the heal's and the reroll's prices are only a tiny
shard on the plaque, and the pieces float on the dimmed world with no frame.

## A: the counter (recommended)

One framed store window. A header bar: the title, the buys left as four shard pips, and your shards in a wallet box.
The 4 cards at 0.74 of the pick's size in one row (all four, with their element badges, read at once), each with a
price tag hung under it. Under them a counter bar of two wide buttons, heal on the left and reroll on the right, each
with its pad button (X, Y) and **its price large on the right** (as large as the wallet). The hint line closes the
frame. Trade-off: the most familiar store layout and the least change to how the panel works now (cards row, then the
services row: today's keyboard, mouse and pad focus rules carry over unchanged); the card text is a little smaller
than now. **Lead's recommendation:** A. It answers each point (smaller cards, all at once, reroll price obvious, one
cohesive frame) without new navigation rules.

## B: the ledger

The cards in a 2×2 grid on the left (0.72), each with its price under it; a right rail with the title, the wallet
large, the buys-left pips, then the heal and the reroll as tall buttons whose price is the biggest text on the
screen. Trade-off: money and services are impossible to miss and the cards are a little larger than in A, but the
cards no longer sit in one row (the 1-4 keys map to a grid), focus needs two axes plus a jump to the rail, and the
frame is tall.

## C: the shelf

A storefront banner (title, pips, wallet), the 4 cards smallest (0.66) side by side on a lit shelf with their prices
along the shelf's edge, and the heal and the reroll as two medallions at the shelf's ends on the shoulder buttons
(LB, RB), price under each. Under the shelf a wide read-out shows the focused card's full name and sentence with its
price and the buy button (A), so the small cards stay readable. Trade-off: the most "store" look and the services work
from anywhere on the pad, but it adds a read-out that changes with focus (more to build and test) and the cards' own
text is the smallest of the three.

## What none of them changes

The sim (prices, buy limit, reroll rules), the 1-4 keys, Enter or A to buy, Esc or B to leave, hover and click.
Every mockup shows only the heal, the reroll and the 4 cards.
