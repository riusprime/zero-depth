# v0.9.0 BR: the balance review (evidence)

Owner rows in [`../PLAN.md`](../PLAN.md): Q13 ("12 per attack (Recommended)": at most 12 projectiles an attack, a
regression test fails above 40 a second for the worst legal build), Q28 ("the most broken could be unlocked, maybe 2 of
them"), AF1 and AF1b (the Lance's full charge about 1.0× the orbs on one target). Open questions 3 and 5 in
[`../OWNER_QUESTIONS.md`](../OWNER_QUESTIONS.md) (the same ~1.0× rule for the other forms?) are **not answered**: this
step measures and changes **no tuning number in `data/`**.

Branch `v090-br`, cut from `4e39e38a`; the step's commit is the one that adds this file. It adds a test and a script
only (no `src/` or `data/` change), so every number below is the game as of `4e39e38a`. Machine: the owner's PC
(Windows 11, Git Bash, i7-10700K, RTX 3060), `Godot Engine v4.7.2.stable.official.ed1daf0bf`; one Godot job at a time,
with its own `APPDATA`. Lint: `gdformat` + `gdlint` on both new `.gd` files ("Success: no problems found").

## 1. The projectiles-a-second regression test (Q13)

`tests/unit/sim/test_shot_rate_all_forms.gd`: table-driven over the ten form rows of `data/wand/attack_slots.tres`. For
each form, every Pattern its row allows (Twin, Halo, Ring, Backfire; none too) with the motion Secondaries it allows
(Spiral, Swirl), the row read through `AttackSlots.usable`; every card at level 5; the top attack speed (20 Epic Attack
Speed cards, as `test_attack_slots`' worst-build test); a Gun run (shipped wand + slot table, floor 5); SHOOT held at a
wall of 18 tough dummies for 360 ticks (the Lance taps, SHOOT every other tick, its fastest release). Asserts: the
compiled volley (`ShotCap.shots` of the bolt × each split child's) ≤ 12, the most launched in one tick ≤ 12, the most in
any 60 ticks ≤ 40; the Laser launches 0 (a beam is no projectile); 23 builds.

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_shot_rate_all_forms.gd -gexit
```

Raw output (the `gut.p` line, then the totals):

```
BR shots (compiled a attack, most in a tick, most in 60 ticks): orbs[gun_spiral,gun_swirl] attack 1, tick 1, second 12; orbs[gun_twin,gun_spiral,gun_swirl] attack 3, tick 3, second 36; orbs[halo_shot,gun_spiral,gun_swirl] attack 7, tick 7, second 40; orbs[gun_ring,gun_spiral,gun_swirl] attack 1, tick 1, second 12; orbs[gun_backfire,gun_spiral,gun_swirl] attack 1, tick 2, second 24; laser[gun_laser] attack 1, tick 0, second 0; laser[gun_laser,gun_twin] attack 1, tick 0, second 0; bomb[gun_bomb] attack 1, tick 1, second 2; bomb[gun_bomb,gun_twin] attack 3, tick 3, second 6; void[gun_void] attack 1, tick 1, second 4; void[gun_void,gun_twin] attack 3, tick 3, second 12; lance[gun_lance] attack 1, tick 1, second 4; lance[gun_lance,gun_twin] attack 3, tick 3, second 12; scatter[gun_scatter] attack 6, tick 6, second 18; scatter[gun_scatter,gun_twin] attack 12, tick 12, second 36; scatter[gun_scatter,gun_backfire] attack 6, tick 12, second 36; glaive[gun_glaive,gun_swirl] attack 1, tick 1, second 3; glaive[gun_glaive,gun_twin,gun_swirl] attack 3, tick 3, second 9; seekers[gun_seekers] attack 3, tick 3, second 15; wave[gun_wave] attack 1, tick 1, second 2; wave[gun_wave,gun_twin] attack 3, tick 3, second 6; wave[gun_wave,gun_backfire] attack 1, tick 2, second 4; wisps[gun_wisps] attack 1, tick 2, second 17
2/2 passed.
Tests                 2
Passing Tests         2
Asserts             192
---- All tests passed! ----
```

**No breach.** The builds at a cap: Orbs + Halo Lv 5 at 40 a second (the per-second budget merging its extras, as
built in AS); Scatter + Twin Lv 5 at 12 an attack (18 pellets merged to 12) and Scatter + Backfire at 12 in one tick
(6 + the 6 behind). The worst Orbs builds with Split, Echo, Rapid Fire and triggers stay covered by
`test_attack_slots.gd`'s `test_the_worst_legal_builds_launch_at_most_forty_projectiles_a_second` (not re-run here).

## 2. Per-form DPS sheets

**Harness:** `test_lance.gd`'s `test_single_target_dps_against_the_orbs` (every DAMAGE event on a standing dummy that
isn't damage over time, counted from tick 120), **not the Playground's meter**. The meter (`DpsTally`) counts the same
events' HP taken plus damage over time; with no elements and 1 000 000 HP dummies the two count the same hits. Gun run
(shipped wand + slot table, floor 5, so ShotCap's merges apply), crit off, no attack speed, no elements; the hero
aims along +x and holds SHOOT (the Lance: hold 72 ticks = full charge, release, rest 23, as `test_lance`). Scenes:

- **single:** one dummy (radius 0.35) at 4 m; ticks 120–1800 (28 s);
- **line:** five at 2, 3.5, 5, 6.5, 8 m on the aim line; ticks 120–720 (10 s);
- **pack:** five on a 3 m arc of a 4 m circle (0.75 rad, centred on the aim); ticks 120–720 (10 s).

Each ratio is against the plain orbs (no cards) in the same scene. Twin Lv 5 only where the form's row allows Twin
(not Seekers, not Wisps). The Orbs have no form card, so no card level.

```
godot --headless --path . -s scripts/balance/forms_dps.gd
```

(writes `build/balance/forms_dps.txt`; run twice, the two outputs identical). Raw output:

```
orbs baseline (plain, no cards): single 930, line 335, pack 330
form | card Lv | Twin Lv 5 | single x | line x | pack x | single dmg | line dmg | pack dmg
orbs | - | no | 1.000 | 1.000 | 1.000 | 930 | 335 | 330
orbs | - | yes | 0.800 | 2.400 | 2.400 | 744 | 804 | 792
laser | 1 | no | 1.204 | 1.194 | 1.212 | 1120 | 400 | 400
laser | 1 | yes | 0.843 | 0.836 | 2.545 | 784 | 280 | 840
laser | 5 | no | 1.445 | 1.433 | 1.455 | 1344 | 480 | 480
laser | 5 | yes | 1.012 | 1.003 | 3.055 | 941 | 336 | 1008
bomb | 1 | no | 0.662 | 1.313 | 3.333 | 616 | 440 | 1100
bomb | 1 | yes | 0.452 | 2.687 | 6.818 | 420 | 900 | 2250
bomb | 5 | no | 0.813 | 1.612 | 4.091 | 756 | 540 | 1350
bomb | 5 | yes | 0.572 | 3.403 | 8.636 | 532 | 1140 | 2850
void | 1 | no | 1.011 | 4.955 | 4.576 | 940 | 1660 | 1510
void | 1 | yes | 1.370 | 6.519 | 8.018 | 1274 | 2184 | 2646
void | 5 | no | 1.213 | 5.946 | 5.491 | 1128 | 1992 | 1812
void | 5 | yes | 1.566 | 7.451 | 9.164 | 1456 | 2496 | 3024
lance | 1 | no | 0.998 | 5.194 | 1.055 | 928 | 1740 | 348
lance | 1 | yes | 0.705 | 3.916 | 2.236 | 656 | 1312 | 738
lance | 5 | no | 1.187 | 6.179 | 1.255 | 1104 | 2070 | 414
lance | 5 | yes | 0.826 | 4.585 | 2.618 | 768 | 1536 | 864
scatter | 1 | no | 0.548 | 1.612 | 1.636 | 510 | 540 | 540
scatter | 1 | yes | 1.097 | 2.149 | 3.273 | 1020 | 720 | 1080
scatter | 5 | no | 0.658 | 1.934 | 1.964 | 612 | 648 | 648
scatter | 5 | yes | 1.316 | 2.579 | 3.927 | 1224 | 864 | 1296
glaive | 1 | no | 0.688 | 3.415 | 0.703 | 640 | 1144 | 232
glaive | 1 | yes | 0.516 | 3.600 | 1.582 | 480 | 1206 | 522
glaive | 5 | no | 0.860 | 4.269 | 0.879 | 800 | 1430 | 290
glaive | 5 | yes | 0.602 | 4.200 | 1.845 | 560 | 1407 | 609
seekers | 1 | no | 0.600 | 0.591 | 0.600 | 558 | 198 | 198
seekers | 5 | no | 0.900 | 0.887 | 0.900 | 837 | 297 | 297
wave | 1 | no | 1.000 | 5.015 | 5.000 | 930 | 1680 | 1650
wave | 1 | yes | 2.100 | 9.027 | 9.100 | 1953 | 3024 | 3003
wave | 5 | no | 1.200 | 6.018 | 6.000 | 1116 | 2016 | 1980
wave | 5 | yes | 2.500 | 10.746 | 10.833 | 2325 | 3600 | 3575
wisps | 1 | no | 1.301 | 1.299 | 1.309 | 1210 | 435 | 432
wisps | 5 | no | 1.301 | 1.299 | 1.309 | 1210 | 435 | 432
```

The Lv 1 single-target ratios agree with the per-form tests' own reports (Lance 1.0 at full charge, Laser 1.2, Void
≈ 1.0, Glaive 0.68, Seekers 0.60, Wave 1.00, Wisps + orbs 1.30), though those ran in lab worlds without the slot table.

### Lv 5, against the orbs (the sheet's Lv 5 rows, copied)

| Form | Single | Line of 5 | Pack of 5 | Single, + Twin Lv 5 | Line, + Twin | Pack, + Twin |
|---|---|---|---|---|---|---|
| Orbs (no card) | 1.00 | 1.00 | 1.00 | 0.80 | 2.40 | 2.40 |
| Laser | 1.45 | 1.43 | 1.46 | 1.01 | 1.00 | 3.06 |
| Bomb | 0.81 | 1.61 | 4.09 | 0.57 | 3.40 | 8.64 |
| Void | 1.21 | 5.95 | 5.49 | 1.57 | 7.45 | 9.16 |
| Lance (full charge) | 1.19 | 6.18 | 1.26 | 0.83 | 4.59 | 2.62 |
| Scatter | 0.66 | 1.93 | 1.96 | 1.32 | 2.58 | 3.93 |
| Glaive | 0.86 | 4.27 | 0.88 | 0.60 | 4.20 | 1.85 |
| Seekers | 0.90 | 0.89 | 0.90 | — (row: no Twin) | — | — |
| Wave | 1.20 | 6.02 | 6.00 | 2.50 | 10.75 | 10.83 |
| Wisps (+ the orbs) | 1.30 | 1.30 | 1.31 | — (row: no Twin) | — | — |

### What the sheet shows (findings, nothing changed)

- **Card level 1 → 5 is × 1.2 for every form** (each form's `per_level` is 5 % of its value a level), except the
  **Wisps: Lv 5 adds nothing** (1.301 at both). Their orb is `wisp_permille` of the orb hit with integer rounding
  (`wisps.gd` `_fire`: `(dmg * wisp_permille + 500) / 1000`): 5 × 400 ‰ = 2, and 5 × 480 ‰ = 2.4 also rounds to 2. With
  damage cards the level would show.
- **Twin is a nerf on one target for the thin forms and a big buff for the wide ones.** Its copies (70 % each at Lv 5,
  Q8) fan apart, so on one dummy at 4 m only one lands for Orbs (0.80), Laser (0.84 at Lv 1), Lance (0.70), Glaive
  (0.52), Bomb (0.45); but all three land through the Wave's 3 m band (2.10× at Lv 1, 2.50× at Lv 5) and the Void's
  aura (1.37×, 1.57×), and both Scatter cones overlap (1.10×, 1.32×).
- The Seekers, the Wisps and (alone) the Laser hit one enemy at a time, so line and pack equal single.
- Stationary dummies: the Void's pull, the Wave's roll through a moving crowd and the Glaive's way back read
  differently on real enemies. Elements, attack speed and crit are out of this sheet.

## 3. The two strongest forms (Q28: the owner confirms; nothing locked)

**Wave and Void.** They are the only two forms that, alone at level 1, are at or above the orbs on one target (Wave
1.00×, Void 1.01×) **and** about 5× the orbs on both a line and a spread pack (Wave 5.02× / 5.00×, Void 4.96× / 4.58×);
every other form is strong on at most one of line or pack. With Twin Lv 5 (on both rows) they are also the top two of the
Twin builds on one target (Wave 2.10–2.50×, Void 1.37–1.57×; the Laser alone at Lv 5 is 1.45×) and on a pack (Wave
9.1–10.8×, Void 8.0–9.2×, the Bomb next at 6.8–8.6×). The runner-up is
the Lance (5.19× on a line at Lv 1, the best line alone, but 1.06× on a pack); the Bomb is next on a pack (3.33×, 6.82×
with Twin) but weak on one target (0.66×).

## 4. What the answers to questions 3 and 5 would change (computed, not applied)

If the owner applies the Lance's ~1.0× single-target rule (AF1) to every form: the field and the value that would bring
each form's **Lv 1, alone** single-target ratio to about 1.0×. Computed from the sheet (damage is linear in each field,
then rounded to whole damage a hit; the orbs deal 33.2 a second here: 930 in 28 s); **not measured** after a change.
`per_level` kept at 5 % of the new value keeps Lv 5 at about × 1.2.

| Form | Now (single, Lv 1) | Field (`data/modifiers/…`) | Now | For ~1.0× | Why that value |
|---|---|---|---|---|---|
| Laser | 1.20× | `gun_laser.tres` `beam_permille` | 800 | 600–699 (0.90×) or keep 800 (1.20×) | 4 a beam tick × 10 a second = 40/s; one less a tick is 3 (30/s, 0.90×); ~1.0× (3.3 a tick) isn't reachable at the orb's 5. The LZ test asserts about 1.2× (its doc cites Q8) |
| Bomb | 0.66× | `gun_bomb.tres` `damage` (× per mille of an orb hit) | 4500 | 6600 (per_level 330) | 22 a blast, 1 a second → 33 a blast ≈ 0.99× |
| Void | 1.01× | — | — | no change | already ~1.0× |
| Lance | 1.00× | — | — | no change | AF1 |
| Scatter | 0.55× | `gun_scatter.tres` `share_permille` | 1000 | 1800 (per_level 90) | 2 of 6 pellets reach one dummy at 4 m, every 0.55 s: 5 → 9 a pellet ≈ 0.99× |
| Glaive | 0.69× | `gun_glaive.tres` `share_permille` | 1600 | 2400 (per_level 120) | 2 passes a throw every 0.7 s: 8 → 12 a pass ≈ 1.03× (11, `share` 2100–2299, ≈ 0.95×) |
| Seekers | 0.60× | `gun_seekers.tres` `share_permille` | 450 | 500–699 (0.90×) or 700–899 (1.20×) | 3 darts every 0.3 s, 2 each now; ~1.0× needs 3.3 a dart, so 3 (0.90×) or 4 (1.20×). Lv 5 now is 538 ‰ = 3 a dart, 0.90× |
| Wave | 1.00× | — | — | no change on one target | AF3 set it to 1.00×; question 5's "lower on crowds" isn't a single-target change (its band width `wave_width_mm` 3000 sets the crowd number) |
| Wisps | 1.30× (with the orbs) | `gun_wisps.tres` `wisp_permille` | 400 | — | the form keeps the orbs (1.00× alone), so the wisps can only add; ~1.0× would mean no wisp damage. The wisps alone are 0.30× (`test_wisps`) |

The rounded values above are the computed nearest whole-damage step; whether a value lands exactly is for a measured
re-run after the owner answers (the same script).
