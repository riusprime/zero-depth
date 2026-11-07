# v0.11.0 S2b — room to dodge between the Lantern Shade's wisps (approve the target and the fix)

Owner, Q2 (2026-11-07): "some of the attack patterns have the wisps too close to each other and leave almost no space
to dodge". Measured, not estimated: one headless run of a real World per pattern (boss at the origin, the player at
4 m or 7 m, every wisp's crossing point logged each tick). Hero diameter 0.70 m (`player_table.gd:15`), wisp radius
0.24 m.

```
APPDATA=build/wisp_gap/appdata godot --headless --path . -s res://build/wisp_gap/wisp_gap.gd   (the lead's checkout, 2026-11-07; untracked script)
```

## Today

| Pattern | Wisps fired a wave | Waves | Escape lane in one wave, 4 m / 7 m | Lane − hero, 4 m / 7 m |
|---|---|---|---|---|
| Wisp Bloom (phase 1) | 25 | 3, 0.8 s apart | 1.18 / 2.43 m | **+0.48** / +1.73 m |
| Wisp Bloom 2 | 30 | 3, 0.75 s apart | 0.91 / 1.96 m | **+0.21** / +1.26 m |
| Wisp Bloom 3 | 30 | 4, 0.7 s apart | 0.91 / 1.96 m | **+0.21** / +1.26 m |
| Lights Out wisps | 8 | 3, 0.9 s apart | 5.18 / 9.42 m | +4.48 / +8.72 m |
| Lights Out wisps 3 | 10 | 3, 0.85 s apart | 4.51 / 8.25 m | +3.81 / +7.55 m |

- **Blooms 2 and 3 are the cramped ones.** Up close (4 m) the only way through a wave is the lane between two petals:
  0.91 m for a 0.70 m hero, so you must land within ±0.1 m of its centre. Each petal drops only one wisp at its valley
  (36 shots, 6 petals, cut 400 ‰).
- Each wave turns 30°, so it covers the last wave's lane: you can't stand still; you move to a new lane every 0.7–0.8 s.
  That is the pattern's idea and stays.
- Lights Out is fine.

## The fix (approve or change)
- **Target:** every Wisp Bloom wave leaves a lane of at least **hero + 0.45 m at 4 m** (Bloom 1 today: +0.48 m).
- **Fix:** Bloom 2 and Bloom 3 go from 36 to **30 shots a wave** (6 petals stay, so each lane is 24° like Bloom 1's,
  about 1.18 m at 4 m, +0.48 m). Fewer wisps a wave: 30 → 24 fired. Bloom 3 keeps its 4 waves and faster speed, so it
  stays the hardest. Bloom 1 unchanged.
- The lane numbers after the change are a hand estimate from the same formula; the step re-runs the measurement and
  pastes it. A test pins the target (every bloom wave's lane ≥ hero + 0.45 m at 4 m).
- Data only: `data/bullet_patterns/shade_wisp_bloom_2.tres:15` and `shade_wisp_bloom_3.tres:15` (`count`). The Lantern
  Shade's boss tests may change timings or hit counts on purpose.

## Owner answers (2026-11-07, asked one row at a time)
- **"Wider still":** aim for about **hero + 0.7 m** at 4 m, not + 0.45 m. Bloom 2 and Bloom 3 go to about **24 shots a
  wave** (the step measures the lane and picks the count that clears + 0.7 m; Bloom 1 is re-checked against the same
  target and changed only if it misses it, which is reported with its numbers first).
