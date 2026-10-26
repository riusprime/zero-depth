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
| N5 | **Rune Explosion's strength.** Measured against the plain orbs (dummies within reach): ×0.50 on one target, ×2.46 in a line, ×2.42 in a pack at ×3.75 damage (the agent's limit was +25 % over the planned ×3.0). The plan aimed at ×0.55 / ×3.0 in a pack. Raise it further (×4.5 ≈ ×2.9 pack), or try it first? | ×3.75, try it first | [`evidence/FC0.md`](evidence/FC0.md) |
| N6 | **The Brood Mother's body.** Solid bodies (SB) widened the bosses whose push circle was well inside their model (Gatekeeper, Siege Engine, Lantern Shade, Prism, Colossus). The Brood Mother's model suggests 2.09 m instead of 1.55 m, but at 2.09 m its Leap never locks on in the dodge lab and its burrow eruption misses. Keep 1.55 m (you can clip its legs a little), or widen it and retune Leap and Burrow? | 1.55 m | [`evidence/SB.md`](evidence/SB.md) |
| N7 | **The Wisps are still weak.** At 80 % with pierce 1 (your Q13 pick), the Wisps form measures ×1.60 the plain orbs on one target, ×1.80 in a line, ×1.62 in a pack (was ×1.30 everywhere). My ×1.9 / ×3.0 estimate was wrong: the wisps fire from beside you, so most shots miss a pack's back rows. Bomb, Void, Lance and Wave sit at ×2–5 in groups. Options: **(a)** wisp shots 80 % → 120 % (≈ ×2.0 pack); **(b)** each wisp shot bursts in a small 1 m blast on hit (≈ ×2.8 pack, more particles); **(c)** play it first | (c), built as you picked | [`evidence/WB.md`](evidence/WB.md) |

## FYI (decided by the lead, say if you disagree)
| # | Note | Where |
|---|---|---|
| F1 | A save holding a removed card (Gravity Stitch, the mutations, the trigger cards) drops it and refunds its salvage price in shards, the same way earlier removals worked | [`evidence/RC.md`](evidence/RC.md) |
| F2 | With the mutations gone, a jackpot can only lift a card you hold at the level ceiling (its mutation branch is now unused) | [`evidence/RC.md`](evidence/RC.md) |
| F3 | Godot on your PC runs in Spanish, so a few tests that assert English names fail locally unless run with `--language en`; CI is English. Agents now pass `--language en` | — |
| F4 | Difficulty past minute 10 (DC): the room's enemy cap grows only up to ×1.4 (reached at tier 8, minute 7). After that the danger comes from tougher enemies (the tier tables: about ×2.0 enemy HP at minute 10, ×5.2 at minute 15 on floor 3), not from more of them at once, because 10–20 enemies already lag (your line 21). Without the ceiling the agent's plan reached 78 enemies alive at minute 10 and 156 at minute 15 | [`evidence/DC.md`](evidence/DC.md) |
| F5 | Rune Explosion's bursts aren't projectiles, so they don't count toward the 40-shots-a-second cap; the retired Scatter's row is gone (only the dev panel can still grant it) | [`evidence/FC0.md`](evidence/FC0.md) |
| F6 | Solid props (altars, chests, pedestals, rune pillars, the dais, pylons, the Loop device) block you and enemies but not shots, beams or blasts, like the shrines already did. The arrival portal collapses before you can move, so it needed no body | [`evidence/SB.md`](evidence/SB.md) |
