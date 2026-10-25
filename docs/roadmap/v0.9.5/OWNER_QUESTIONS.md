# v0.9.5: questions and notes for the owner (written while you were away, 2026-10-25 night)

The owner (2026-10-25, going to sleep): "keep working on the plan as much as you can, if you have questions record them
and i'll pick up next morning, but do as much as you can withou those answers."

Everything below was built with the lead's default, so nothing waits on these unless it says **BLOCKS**. Answer
by number; "as built" is fine.

## Needs your eyes
| # | Question | Built as | Where |
|---|---|---|---|
| N1 | The backgrounds are about 25 % dimmer, as you asked (deep layers 0.85 → 0.65; Night Rocks' clouds 0.45 → 0.30). Dim enough? | dimmer | `build/shots/v0.9.5/bg/_sheet_dim.jpg` |
| N2 | The Fortune shrine's prize glyph (the won stat floating over the shrine) reads a little faint in the shot. Brighter or bigger? | as built | [`evidence/SS.md`](evidence/SS.md) |
| N3 | The new shrine sounds (`gamble_fail`, a falling crackle; `gamble_win`, a two-note chime) are synthesized. Listen in game: keep them, or would you rather provide files? | synthesized | `assets/audio/sfx/gamble_*.wav` |
| N4 | **The Pulse Gun's lost damage.** With the Pulse Gun out of the offers (CARD_LEVELS C19), a run that keeps the plain Orbs loses the ×1.12–1.48 its levels gave. I had proposed bringing the Damage stat card one room earlier, but the game has no per-card room gate (stat cards come by odds). Options: **(a)** nothing: stat cards make it up over a run; **(b)** the plain Orbs' base damage 5 → 6 (+20 %, about Pulse Gun Lv 2–3); **(c)** Damage stat cards weighted ×1.5 while you hold no form card | (a) for now | [`evidence/CLV.md`](evidence/CLV.md) |

## FYI (decided by the lead, say if you disagree)
| # | Note | Where |
|---|---|---|
| F1 | A save holding a removed card (Gravity Stitch, the mutations, the trigger cards) drops it and refunds its salvage price in shards, the same way earlier removals worked | [`evidence/RC.md`](evidence/RC.md) |
| F2 | With the mutations gone, a jackpot can only lift a card you hold at the level ceiling (its mutation branch is now unused) | [`evidence/RC.md`](evidence/RC.md) |
| F3 | Godot on your PC runs in Spanish, so a few tests that assert English names fail locally unless run with `--language en`; CI is English. Agents now pass `--language en` | — |
| F4 | Difficulty past minute 10 (DC): the room's enemy cap grows only up to ×1.4 (reached at tier 8, minute 7). After that the danger comes from tougher enemies (the tier tables: about ×2.0 enemy HP at minute 10, ×5.2 at minute 15 on floor 3), not from more of them at once, because 10–20 enemies already lag (your line 21). Without the ceiling the agent's plan reached 78 enemies alive at minute 10 and 156 at minute 15 | [`evidence/DC.md`](evidence/DC.md) |
