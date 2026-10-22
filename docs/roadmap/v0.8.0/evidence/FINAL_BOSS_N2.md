# FINAL_BOSS_N2: does each body last 1–2 minutes whatever the build, with harder dodges and The Fallen on and off?

- **Status:** RUN (sim, content, e2e checks and renders); the feel, the difficulty in play and whether it is "intense"
  are **OWNER ONLY**
- **Build:** the working tree of the commit `v0.8.0 Step N2` on `v080-n2` (parent `d7c4454`); Godot
  `4.7.2.stable.official.ed1daf0bf`; a shared Linux cloud container (headless; renders on software Vulkan, llvmpipe,
  under xvfb), not the owner's hardware
- **Date:** 2026-10-16
- **Who ran it:** agent

Owner (PLAN O41, O42, O52, verbatim in [`../FINAL_BOSS.md`](../FINAL_BOSS.md) "N2"): each phase 1–2 minutes, 1
minute at the most OP, longer if not, never killed in seconds; really hard to dodge spells; the Nemesis becomes The
Fallen, mimics and nerfs you, only at certain times, on and off.

## The change (design: [`../FINAL_BOSS.md`](../FINAL_BOSS.md) "N2"; contract: SIM_CONTRACTS §10i)
- **Pace** (`src/sim/ai/final_pace.gd`): each body's HP from the measured damage per second so that at that rate it
  lasts 120 s × √(30 / dps), clamped 60..180 s; set as it rises (Prism, The Fallen) or once 5 s are measured (the
  Colossus, keeping its fill).
- **Rate cap:** a body takes at most max HP / 60 s a second (banked up to 10 s); the world's own hit (dev panel Kill
  boss) passes.
- **Why both:** the HP rule gives the gradient (stronger is quicker, weaker longer); the cap is the floor no build can
  break, even one whose measured rate understates it.
- **New attacks:** Colossus `leap_slam_3` (double quake ring, `colossus_quake_double`) and `spike_chase_3`; Prism
  `cross_weave` (`prism_crown_weave`, bolts by `prism_bolt_fan`); The Fallen `fallen_storm` and `fallen_rush`.
- **The Fallen:** renamed (en "The Fallen", es "El Caído"); mimic windows 7 s every 20 s (first at 12 s, warned
  1.5 s); in a window it copies the build and your damage on it × 30 / dps (≥ 10 %), your move speed ≤ base; outside,
  its own kit. Hits by O27: 22 / 30 / 34 % of your max HP, cards 50 %, cap 50 %.

## Commands
```
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_prism.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=<dir> -ginclude_subdirs -gexit
  (each of res://tests/content, res://tests/arch, res://tests/golden, res://tests/unit/application, res://tests/unit/debug)
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<file> -gexit
  (each of tests/e2e/test_e2e_final_boss.gd, test_e2e_nemesis.gd, test_e2e_prism.gd, test_e2e_ascension.gd,
   test_e2e_boss_strikes.gd, test_e2e_old_save.gd, test_e2e_saves.gd; tests/unit/presentation/test_nemesis_views.gd,
   test_final_boss_views.gd, test_prism_views.gd)
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/final_boss_n2.gd -- <n>   (n = 1..6)
```
The scripted fights are `tests/unit/sim/test_final_pace.gd` (`test_boss_pace.gd`'s BladeRun hero: stands in melee
reach and attacks every 4 ticks while the body can be hurt, holds the Gun's trigger on a Gun run, dashes big attacks,
**is healed to full every tick**, so this proves the fight's length, not that a script survives). The builds hold
their cards as the hero walks in (the catch-up reads them). Seed 21.

## The phase-time table (raw: the `N2 pace` lines below)
Each body from its rise to the next one's (its rise, its fight, its shatter; the last to the win).

| Build | Loop | Colossus | Prism | The Fallen | Measured dps (Colossus) |
|---|---|---|---|---|---|
| base Blade (no cards) | 1 | 130.8 s | 95.5 s | 128.3 s | 29 |
| strong Blade (Double Slash 3, Wave 3, Explosive 3) | 1 | 76.5 s | 75.7 s | 121.4 s | 232 |
| absurd Gun (Chain Blast + Split + Spread, all Lv 5) | 3 | 60.7 s | 73.0 s | 86.0 s | 241 |
| absurd Blade (Chain Blast + Double Slash + On Hit ×2, all Lv 5) | 3 | 62.4 s | 76.3 s | 110.4 s | 262 |
| *before N2 (same harness, `d7c4454` + the harness):* base Blade | 1 | 75.8 s | 58.6 s | 21.2 s | — |
| *before N2:* strong Blade | 1 | 14.7 s | 40.2 s | 17.3 s | — |
| *before N2:* absurd Gun, loop 3 | 3 | 298.0 s | 64.0 s | 12.3 s | — |
| *before N2:* absurd Blade, loop 3 | 3 | 191.2 s | 59.5 s | 14.4 s | — |

The "before" rows: the same harness run on the parent's code (`d7c4454`, before any N2 sim change), early in this
session (`godot … -gtest=res://tests/unit/sim/test_final_pace.gd -gexit`, the harness then held only the pace test):
```
    N2 pace base blade: won=true, bodies (s) [75.8, 58.6, 21.2]
    N2 pace strong blade: won=true, bodies (s) [14.7, 40.2, 17.3]
    N2 pace absurd gun (Chain Blast + Split + Spread Lv 5, loop 3): won=true, bodies (s) [298.0, 64.0, 12.3]
    N2 pace absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3): won=true, bodies (s) [191.2, 59.5, 14.4]
```

Reading it:
- No body falls in under 60 s; the absurd builds' Colossus is at the floor (60.7, 62.4 s), as asked ("1 minute being
  the most op"). The base build takes about 2 minutes a body (95.5–130.8 s), within "≤ 2–3 min".
- The Prism's bodies sit at 73–76 s for the strong builds rather than 60 s: her damage lands only in the 2.5 s
  window of each 8.5 s Cross, so her time comes in whole cycles.
- **The Fallen is the longest for strong builds (86–121 s), longer than "≈ 60 s at the most OP"**: its windows pull
  the hero's damage to the base level for 7 s of every 20, and it is harder for the scripted melee hero to keep in
  reach (it backs off, dashes). Within 1–2 min; the owner decides (OWNER_TODO D44).
- The measured dps of the "absurd" builds (241–262) is only ~8–9× the base: once the rate cap empties, hits land for 0
  and on-hit chains (which need a landed hit) stop, so the meter sees less than an uncapped build would deal.
- The cap alone: a scripted 100,000 damage every tick took the Colossus in exactly 60.0 s (`N2 cap` line).
- The BP Blade-only final (test_boss_pace.gd): won in 354.7 s (was 155.6 s in BP); its `FINAL_LIMIT` raised from 6 to
  10 minutes on purpose (each body is now 1–3 min).

## The harder attacks: fair (dash after the telegraph) and real (they hit who stands)
`test_each_new_attack_is_dashable_after_its_telegraph`: BP's dodge (dash 0.3 s after the telegraph, or at the lock of
a tracking move, then keep running 2.5 s more). `test_standing_still_each_new_attack_hits`: each hits a hero who
stands. Honest note: in this scripted dodge several are clean every way (the double ring at a dash's distance, the
crescent storm); the dodge test proves a path exists, not how hard it feels. That is OWNER ONLY.

Shot caps (`test_the_new_patterns_keep_the_shot_caps`, PF: `BulletPatterns.MAX_ALIVE` 900): cross_weave at most 214
hostile shots alive (the old cross_spiral 131), leap_slam_3 48 (leap_slam_2 21); no cap event. Frame time on the
owner's hardware: NOT YET RUN (not measured here).

## The Fallen's windows
`N2 windows` line: warn at 631, open at 721 (90 ticks = 1.5 s later), close at 1141 (420 = 7 s), the next open at
1921 (1200 = 20 s). Unit tests: outside a window no card, its own kit, its own arcs, no dash answer, hits 30 % of HP
for a slash; in a window your cards, only your weapon's moves, your combo's arcs, the dash answered, your hit × 100 ‰
for a 10× build, the move-speed stat capped at the base; a 10× in-window card hit capped at half your HP. e2e
(`test_e2e_nemesis.gd`, real input through `main.tscn`): the warning's line and rings, the window's line, rings and
thread, the dash answered in the window, the cards cast, the win.

## Raw output
`tests/unit/sim` (117 scripts), the N2 and BP lines and the totals:
```
    BP blade final: won=true in 354.7 s, bodies [[22, 60], [23, 7910], [24, 13640]], 4269 swings, 0 dashes, hits taken 143 (5638 damage)
    N2 pace base blade: won=true, bodies (s) [130.8, 95.5, 128.3], [max HP, measured dps] [[3573, 29], [1029, 28], [3502, 28]], hits taken 143
    N2 pace strong blade: won=true, bodies (s) [76.5, 75.7, 121.4], [max HP, measured dps] [[13932, 232], [3676, 208], [12504, 208]], hits taken 74
    N2 pace absurd gun (Chain Blast + Split + Spread Lv 5, loop 3): won=true, bodies (s) [60.7, 73.0, 86.0], [max HP, measured dps] [[14484, 241], [4664, 264], [15867, 264]], hits taken 70
    N2 pace absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3): won=true, bodies (s) [62.4, 76.3, 110.4], [max HP, measured dps] [[15732, 262], [8671, 491], [29496, 491]], hits taken 66
    N2 cap: 100,000 a tick took the Colossus in 60.0 s (max HP 5000000)
    N2 windows (cue, ticks after the test began): [[&"fallen_warn", 631], [&"fallen_open", 721], [&"fallen_close", 1141], [&"fallen_warn", 1831], [&"fallen_open", 1921], [&"fallen_close", 2341]]
    N2 dodge colossus leap_slam_3 at 4.5 m: clean by ["left", "right", "away", "toward"] (damage left/right/away/toward [0, 0, 0, 0])
    N2 dodge colossus leap_slam_3 at 8.0 m: clean by ["left", "right", "away", "toward"] (damage left/right/away/toward [0, 0, 0, 0])
    N2 dodge colossus spike_chase_3 at 2.8 m: clean by ["left", "right", "away"] (damage left/right/away/toward [0, 0, 0, 100])
    N2 dodge colossus spike_chase_3 at 8.0 m: clean by ["left", "right", "away"] (damage left/right/away/toward [0, 0, 0, 90])
    N2 dodge prism prism_bolt_fan at 2.7 m: clean by ["left", "right"] (damage left/right/away/toward [0, 0, 22, 22])
    N2 dodge prism prism_bolt_fan at 8.0 m: clean by ["left", "right"] (damage left/right/away/toward [0, 0, 22, 22])
    N2 dodge nemesis fallen_storm at 3.5 m: clean by ["left", "right", "away", "toward"] (damage left/right/away/toward [0, 0, 0, 0])
    N2 dodge nemesis fallen_storm at 8.0 m: clean by ["left", "right", "away", "toward"] (damage left/right/away/toward [0, 0, 0, 0])
    N2 dodge nemesis fallen_rush at 1.9 m: clean by ["left", "right", "away"] (damage left/right/away/toward [0, 0, 0, 60])
    N2 dodge nemesis fallen_rush at 3.5 m: clean by ["left", "right", "away"] (damage left/right/away/toward [0, 0, 0, 60])
    N2 shots cross_spiral: at most 131 hostile shots alive, 0 cap events
    N2 shots cross_weave: at most 214 hostile shots alive, 0 cap events
    N2 shots leap_slam_2: at most 21 hostile shots alive, 0 cap events
    N2 shots leap_slam_3: at most 48 hostile shots alive, 0 cap events
res://tests/unit/sim/test_items.gd
- test_the_pool_never_repeats_and_skips_owned_and_placed
    [Failed]:  [57] expected to equal [55]:  the v0.3.0 pool of 24 + ... v0.8.0 BL: + 2
          at line 313
    [Failed]:  [57] expected to equal [55]:  no repeats
          at line 326
    [Failed]:  [52] expected to equal [50]:  55 - owned - 4 placed
          at line 339
res://tests/unit/sim/test_prism.gd
- test_the_prism_is_a_skill_phase_in_data
    [Failed]:  [5] expected to equal [4]:
          at line 77
Totals
------
Scripts             117
Tests              1264
Passing Tests      1262
Failing Tests         2
Asserts           2831918/2831922
Time              6682.656s
```
- `test_prism.gd` line 77 was N2's own (the new `cross_weave` fires `prism_bolt_fan`, the test still expected the
  plain bolt); fixed and re-run: `Tests 24, Passing Tests 24, Asserts 1842`.
- `test_items.gd`: **FAILS, not N2's** (N2 touches no item, card or pool file); the item pool counts 57 where the
  test expects 55. Left for the lead (it is in shard sim_b).

The other runs (totals as printed):
```
tests/content                 Tests 132  Passing 131  Failing 1  Asserts 9329/9330
  [Failed] test_credits_licences.gd: the committed list doesn't match a fresh build ("rebuild with: godot --headless
  --path . -s scripts/content/build_credits.gd"): not N2's (it is built from the assets' manifests; N2 adds none)
tests/arch                    Tests 4    Passing 4    Asserts 11501
tests/golden                  Tests 2    Passing 2    Asserts 4
tests/unit/application        Tests 99   Passing 99   Asserts 1025
tests/unit/debug              Tests 15   Passing 15   Asserts 250
test_e2e_final_boss.gd        Tests 1    Passing 1    Asserts 68
test_e2e_nemesis.gd           Tests 3    Passing 3    Asserts 4189
test_e2e_prism.gd             Tests 1    Passing 1    Asserts 167
test_e2e_ascension.gd         Tests 2    Passing 2    Asserts 74
test_e2e_boss_strikes.gd      Tests 1    Passing 1    Asserts 27
test_e2e_old_save.gd          Tests 1    Passing 1    Asserts 11
test_e2e_saves.gd             Tests 2    Passing 2    Asserts 26
test_nemesis_views.gd         Tests 9    Passing 9
test_final_boss_views.gd      Tests 10   Passing 10
test_prism_views.gd           Tests 9    Passing 9
gdformat --check / gdlint     970 files unchanged / Success: no problems found
```
Found on the way (fixed in N2): `test_nemesis.gd`'s card-tie order was stale since RR (Twin's tier); the e2e at
loop 2 closed the dev panel (which drops God mode) before the Nemesis part: with O27's hits the hero now died while
waiting for the window, so the panel stays open (its buttons take no focus) and Space still dashes.

## Renders (`n2_shots/`, copied by hand from `build/shots/v0.8.0/n2/`)
1. `1_colossus_double_quake_ring.jpg`: both rings out, the gaps turned.
2. `2_colossus_double_spike_chase.jpg`: the two chasing lines' marks.
3. `3_prism_cross_weave_and_bolt_fans.jpg`: the Cross, the crossing spiral arms, a bolt fan's aim line.
4. `4_fallen_crescent_storm.jpg`: the seven locked lines, the first crescents.
5. `5_fallen_window_warning.jpg`: the rings at both feet, "The Fallen reaches for your power…".
6. `6_fallen_window_open.jpg`: the window's rings and the line "… (7 s)" (it stood next to the hero, so the thread
   is short here).

## For the owner (OWNER ONLY)
Does each phase feel 1–2 minutes and intense on your build; are the new attacks hard enough; are The Fallen's windows
readable and the nerf fair (D44).
