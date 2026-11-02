# O16 evidence: the economy map and the three curves

Owner P15 ("we can try sure"), P16 ("sure"); overnight mode ("Pick and build"). **Evidence only: no tuning, no game
code changed.** The map: [`docs/balance/ECONOMY_MAP.md`](../../../balance/ECONOMY_MAP.md).

- **Build SHA:** `36382fddfd775d692478045e72d957a38f377b2e` (branch `v0105-o16`, cut from `claude/v0100-cleanup`).
  O7b (shard pickups) is not in that tree.
- **Machine:** the owner's PC (i7-10700K), Godot 4.7.2 console build, `--headless`, a fresh `APPDATA` per process.
  Four processes in parallel (owner, 2026-10-22). No timing is claimed.
- **Run length:** the brief said "a full 3-floor run". The shipped run is **five floors** (`RunSaver.RUN_ID` →
  `data/run/five_floors.tres`, `floors = 5`; `three_floors.tres` is only for v0.8.0 saves), so the sim plays all five.
  Floors 1-3 are the first three rows of every table.

## Method

`scripts/checks/three_curves.gd` (new, a check script; writes only `build/three_curves/`):
- Each floor built by `FloorPlan` exactly as Main builds it (`new_run`, then `RunState.finish_floor` and
  `FloorPlan.next_floor`: the catch-up, wand table, loot pacing, director, shop, events, secrets all on). Blade build,
  loop 1, no Deep route, no affinity.
- The hero: `tests/support/survival_run.gd`'s Survivor for **240 s of floor fighting** in the start hall, then the
  boss (entered at its door) fought by `test_final_pace.gd`'s Hero (dashes every boss telegraph), 300 s cap, then the
  portal. Floor 5's portal ends the run (the final arena is left out). **Healed to full every tick** (a damage ledger,
  as survival.gd): every run plays the whole way, and HP lost is counted, not suffered.
- The build: the survival bot's 3 offence stat cards a floor (damage, attack speed, crit chance, round robin; common
  on 1-2, rare on 3-4, epic on 5), plus a **shopper**: every 30 s of floor time and at the floor's end it takes every
  free altar and every chest it can afford, cheapest first, the first offered card that needs no swap. Arena locks and
  cursed chests ignored (`Curses.on_offer_rolled` not called), so **T stays 0** in every run. It never uses the shop,
  the Fortune shrine, the fountain or heal orbs.
- Sampled every 10 s. The three curves:
  1. **Avatar power:** `CatchUp.power(w)` (P, per mille of a fresh build), and the realised throughput (enemy HP removed
     per second, "dps").
  2. **Game challenge:** for each enemy that arrived, max HP / its kind's floor-scaled table HP × its damage factor
     (`ActorStore.power`), per mille, × the floor's HP × damage factors from `five_floors.tres` (applied in
     `three_curves_table.py`, because the kind's table is already floor-scaled). So it holds floor × tier × curve ×
     Overrun × m × √m.
  3. **Skill proxy:** the bot's skill is fixed by construction (it is a script). What it exposes: hit ticks a minute
     (ticks the hero lost HP), HP lost a minute, threat dashes a minute (Survivor dashing out of a wind-up; the Hero's
     boss dashes). There is **no "damage avoided" counter** in the sim (an attack the hero dodged leaves no record), so
     the proxy is "damage taken at constant skill": how hard the challenge is for an unchanging player.

### Commands

```bash
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --editor --import --quit
for from in 1 6 11 16; do ( export APPDATA=$(mktemp -d); "$G" --headless --path . -s scripts/checks/three_curves.gd -- from=$from seeds=5 floor_s=240 > build/three_curves/log_$from.txt 2>&1 ) & done; wait
python scripts/checks/three_curves_table.py
```

### Raw output: the runs' log lines (abridged to the status lines; every seed finished)

```
seed 1 done (173895 ms) ... seed 20 done (859571 ms)      (20 of 20 seeds, 4 x "wrote res://build/three_curves/seeds_*.csv")
seed 12 floor 4: boss out of time
seed 12 floor 5: boss out of time
seed 16 floor 5: boss out of time
seed 1 floor 3 end: shards 1367, P 6544, m 1000, boss m 977, cards 24
seed 1 floor 5 end: shards 1165, P 15776, m 1591, boss m 1616, cards 44
seed 2 floor 3 end: shards 1312, P 3426, m 1000, boss m 925, cards 24
seed 2 floor 5 end: shards 2099, P 9160, m 1084, boss m 1197, cards 43
seed 3 floor 3 end: shards 1552, P 4160, m 1000, boss m 1048, cards 23
seed 3 floor 5 end: shards 2303, P 10999, m 1326, boss m 1280, cards 39
seed 4 floor 3 end: shards 1498, P 3136, m 1000, boss m 965, cards 23
seed 4 floor 5 end: shards 2076, P 10123, m 1144, boss m 1259, cards 40
seed 5 floor 3 end: shards 1533, P 4835, m 1000, boss m 944, cards 23
seed 5 floor 5 end: shards 1607, P 13290, m 1429, boss m 1405, cards 41
```

(A boss "out of time" was killed by script after 300 s so the run went on; its 300 s count in "boss s".)

### Raw output: `python scripts/checks/three_curves_table.py`

```
three_curves: 20 seeds (1..20), 3461 rows

## Per floor (median over seeds; rates over the phase's seconds; [p10..p90] where shown)
floor | P start | P end [p10..p90] | P/E end | m | boss m | chal (x floor factor) | chal/P end | dps floor | dps boss | boss s [p10..p90] | kills/min | HP lost/min floor | hits/min floor | HP lost/min boss | dashes/min | shards earned | spent | held at portal | unbought chests | cards end
1 | 1160 | 1600 [1377..1815] | 1.60 | 1000 | 981 | 506 | 0.307 | 24.1 | 45.2 | 94 [67..128] | 40.1 | 90.9 | 16.4 | 220.3 | 4.5 | 766 | 100 | 671 | 0 | 7
2 | 1843 | 2692 [1872..3207] | 1.35 | 1000 | 1003 | 1203 | 0.454 | 53.7 | 117.1 | 75 [48..114] | 54.1 | 143.1 | 16.9 | 241.4 | 4.7 | 1158 | 270 | 1259 | 0 | 16
3 | 3444 | 4535 [3136..5499] | 1.13 | 1000 | 990 | 1948 | 0.432 | 80.2 | 160.3 | 66 [39..106] | 60.9 | 139.6 | 14.1 | 408.0 | 4.7 | 1318 | 280 | 1559 | 0 | 24
4 | 5644 | 7000 [5239..8693] | 1.75 | 1064 | 1032 | 3502 | 0.485 | 140.2 | 497.2 | 74 [36..143] | 72.9 | 168.9 | 12.6 | 435.5 | 4.8 | 1566 | 450 | 1829 | 0 | 32
5 | 9214 | 11262 [9160..15338] | 2.82 | 1322 | 1270 | 8048 | 0.690 | 250.2 | 544.7 | 82 [42..143] | 77.0 | 212.6 | 13.0 | 329.0 | 7.2 | 1736 | 540 | 2088 | 0 | 42

## Per minute of floor fighting (all seeds pooled; floor phase only)
floor | minute | P | chal (x floor factor) | dps | kills/min | HP lost/min | hits/min | shards earned/min | shards held
1 | 1 | 1362 | 220 | 6.5 | 20.4 | 33.2 | 7.8 | 50.5 | 15
1 | 2 | 1547 | 457 | 18.5 | 34.8 | 76.5 | 13.7 | 130.7 | 62
1 | 3 | 1588 | 587 | 31.1 | 50.8 | 127.7 | 21.1 | 219.7 | 210
1 | 4 | 1598 | 646 | 34.7 | 49.2 | 142.8 | 23.2 | 277.2 | 460
2 | 1 | 2269 | 919 | 34.2 | 43.9 | 104.0 | 15.9 | 125.1 | 262
2 | 2 | 2638 | 1182 | 50.8 | 53.8 | 148.6 | 16.5 | 210.2 | 360
2 | 3 | 2643 | 1318 | 57.5 | 56.6 | 155.8 | 16.7 | 270.9 | 602
2 | 4 | 2653 | 1465 | 75.2 | 63.6 | 190.4 | 20.0 | 392.7 | 944
3 | 1 | 3922 | 1495 | 52.4 | 48.2 | 91.7 | 10.4 | 143.1 | 506
3 | 2 | 4362 | 1874 | 76.8 | 62.1 | 151.4 | 14.2 | 240.9 | 585
3 | 3 | 4364 | 2187 | 85.1 | 63.2 | 163.9 | 15.1 | 303.2 | 864
3 | 4 | 4378 | 2374 | 106.0 | 72.1 | 190.1 | 18.2 | 449.6 | 1238
4 | 1 | 6454 | 2712 | 86.5 | 55.0 | 115.6 | 10.8 | 176.5 | 598
4 | 2 | 7193 | 3376 | 153.5 | 77.7 | 188.3 | 14.1 | 316.8 | 636
4 | 3 | 7200 | 3853 | 145.5 | 73.1 | 184.8 | 14.1 | 357.2 | 975
4 | 4 | 7222 | 4195 | 182.4 | 87.4 | 202.1 | 14.8 | 531.2 | 1422
5 | 1 | 10998 | 6538 | 165.8 | 58.4 | 152.0 | 9.7 | 173.9 | 705
5 | 2 | 12046 | 7596 | 223.7 | 76.9 | 210.1 | 12.7 | 299.4 | 725
5 | 3 | 12122 | 8741 | 250.7 | 75.0 | 238.8 | 13.3 | 400.6 | 1067
5 | 4 | 12157 | 9764 | 326.1 | 92.8 | 266.5 | 15.5 | 591.2 | 1559
```

Two derived numbers from the same CSVs (a one-off `python -c` over `build/three_curves/seeds_*.csv`):

```
earned 129937 spent 35140 share 27.0%
floor 1 HP per hit tick 7.8
floor 2 HP per hit tick 9.7
floor 3 HP per hit tick 12.6
floor 4 HP per hit tick 14.2
floor 5 HP per hit tick 19.1
```

## Findings (numbers only; each with where it comes from)

1. **Dead loop: shards pile up.** The shopper spent **27.0 %** of the shards it earned (35 140 of 129 937 over 20
   runs) and still bought **every** chest on every floor ("unbought chests" 0 at each floor's end). The median bank at
   the portal is 671 / 1259 / 1559 / 1829 / 2088 against 100 / 270 / 280 / 450 / 540 spent a floor. The converter
   (1-2 chests by room band + S7's 12 %, `rewards.gd:82`, `:119`; prices `reward_table.gd:59`) runs out by minute 2;
   the source keeps flowing. The only thing that removes the surplus is the portal's 50 % drain (`run_carry.gd:34-42`).
   Not measured: the shop (every 2nd floor, at most 4 buys, `shop.gd:201`) and the Fortune shrine (`gamble.gd:308`),
   which the bot never uses; they are the sinks that could take it.
2. **O7a's taper holds the tier, not the income.** Shards earned a minute still climb through minute 4 on every
   floor (floor 1: 51 → 131 → 220 → 277; floor 5: 174 → 299 → 401 → 591), because the kill rate climbs (floor 1: 20 →
   49 kills/min) while the tier bonus is capped (`rewards.gd:43-51`). The 240 s of floor time here is past the 180 s
   minimum, so the cap is live; the climb is volume.
3. **Power is a staircase; challenge is a ramp (a plateau inside every floor).** P rises in the first 2 minutes of a
   floor (the chests and altars) and is then flat (floor 2: 2638 → 2653 from minute 2 to 4; floor 4: 7193 → 7222),
   while the challenge index keeps rising every minute (floor 1: 220 → 646, × 2.9 in 4 minutes; floor 5: 6538 →
   9764). Source: power only comes from cards (`catch_up.gd:36`), challenge from the danger tier and curve on each
   arrival (`spawn_table.gd:86`, `:92`).
4. **Across floors, challenge outgrows P on floor 5 (a spike).** Floor end P: 1600 → 2692 → 4535 → 7000 → 11262 (×
   7.0 floor 1 → 5); challenge: 506 → 1203 → 1948 → 3502 → 8048 (× 15.9). Challenge / P is 0.31 / 0.45 / 0.43 / 0.49 /
   **0.69**: flat on floors 2-4, then a jump on floor 5 (challenge × 2.3 from floor 4 while P × 1.6). Floor 5's
   enemy tables: HP × 3.61, damage × 1.96 (`five_floors.tres`); its m is 1.32. The constant-skill proxy agrees: HP
   lost a minute 91 → 143 → 140 → 169 → 213, HP a hit 7.8 → 19.1, while hits a minute fall slightly (16.4 → 13.0).
   No runaway loop: P never outgrows the challenge here.
5. **The catch-up is off on floors 1-3 and stretched on 4-5.** m at floor entry is 1000 on floors 1-3 in the median
   (P at entry is under E: P/E at floor end 1.60 / 1.35 / 1.13, but m reads P at entry, before that floor's cards,
   `catch_up.gd:149`). On floors 4 and 5 the tables have run out: `expected_power_permille` and `cap_permille` have 3
   entries for a 5-floor run, and `CatchUpTable.at_floor` (`catch_up_table.gd:27`, `spawn_table.gd:135`) reuses floor
   3's E = 4000, cap 2.5, for both. So P/E reads 1.75 and 2.82 and m becomes 1.06 and 1.32. The same holds for
   `boss_expected_power_permille` (7000) and `boss_pace_permille` (4450) on floors 4-5; only `boss_cap_permille` has
   five entries. Whether floors 4-5 meant to reuse floor 3's E is not written anywhere I found: an owner question, not
   a bug claim.
6. **Boss pace holds (O2b), with a tail.** The median boss fight lasts 94 / 75 / 66 / 74 / 82 s (p90 128 / 114 / 106
   / 143 / 143 s); 3 of 100 fights hit the 300 s cap (seed 12 floors 4 and 5, seed 16 floor 5). The boss m (damage
   √m side) is 0.98-1.27.
7. **Loops not measured here:** T (the bot takes no curse, no Deep route: T = 0 throughout), the director's
   STRUGGLING branch (the hero is healed every tick, so `read_standing` never sees low HP, `intensity.gd:166`), heal
   orbs (never picked: the hero is never hurt at the start of a tick), loops 2+ (O5), Hoarder, and the rule cards and
   matchups (the bot's cards are the altars' and chests' first offers; P does not read O9's rule cards or O10's × 1.25
   weak hits, `catch_up.gd:36-68`, so the catch-up cannot answer them by construction).

## What to look at next (no changes made)

- A shard sink for the late floors, or fewer shards: the shop and shrine with a bot that uses them, then re-measure the
  27 % spend.
- The catch-up tables for floors 4-5 (`data/scaling/catch_up.tres`: 3 entries for 5 floors): an owner decision.
- Floor 5's challenge jump (× 2.3 vs P × 1.6): re-read with real players' HP on floor 5 before any change.
- In-floor power plateau: whether a card source after minute 2 (O7b's pickups, events, the shop) is wanted.
- A sim with T > 0 (cursed chests, Deep) and with the ledger off (HP really lost), so the director's STRUGGLING branch
  and the heal orbs enter the curves.
- A "damage avoided" counter (the attacks whose hitbox the hero left), if the skill curve should be more than a
  constant bot's damage taken.

## Q7: floors 4 and 5 get their own catch-up and boss-pace entries (2026-11-02, agent)

- **Status:** RUN (probe, catch_up + boss_pace unit 23/23, content 166/166, golden 2/2). Boss pace target **MISSED on floor 5** (below).
- **Derivation (starting values, no new measurement behind them):** floors 1-3 had E at entry = the previous floor's boss
  E (2000, 4000), so E(4) = 7000, E(5) = 11000. Boss E steps were +2000, +3000, so +4000, +5000 = 11000 / 16000. Enemy
  caps +0.5 a floor: 3000 / 3500. Boss pace steps +680 (O2b): 5130 / 5810. `boss_cap_permille` already had 5 entries.
  `data/scaling/catch_up.tres` is the only data change; tests that pinned the 3-entry arrays now pin 5.
- **Probe:** `scripts/checks/boss_pace_probe.gd` gained pools for floors 4-5 (tidecaller, twin_wardens, clockwork_judge,
  lantern_shade). Command: `godot --headless --path . -s scripts/checks/boss_pace_probe.gd -- floors=4,5` (Godot 4.7.2,
  Windows 11, the owner's PC; per-fight lines in `build/q7_probe.txt`, not tracked).

```
F4 tidecaller weak ALL | mean 97.3 s, min 95.7, max 98.7
F4 tidecaller expected ALL | mean 97.4 s, min 95.7, max 98.7
F4 tidecaller strong ALL | mean 97.4 s, min 95.7, max 98.7
F4 tidecaller extreme ALL | mean 57.2 s, min 54.3, max 62.5
F4 twin_wardens weak ALL | mean 69.0 s, min 67.1, max 70.0
F4 twin_wardens expected ALL | mean 69.0 s, min 67.1, max 70.0
F4 twin_wardens strong ALL | mean 69.0 s, min 67.1, max 70.0
F4 twin_wardens extreme ALL | mean 45.3 s, min 41.5, max 48.9
F5 clockwork_judge weak ALL | mean 57.7 s, min 49.5, max 68.6
F5 clockwork_judge expected ALL | mean 57.7 s, min 49.5, max 68.6
F5 clockwork_judge strong ALL | mean 57.7 s, min 49.5, max 68.6
F5 clockwork_judge extreme ALL | mean 34.6 s, min 32.1, max 38.2
F5 lantern_shade weak ALL | mean 58.4 s, min 53.5, max 63.9
F5 lantern_shade expected ALL | mean 58.4 s, min 53.5, max 63.9
F5 lantern_shade strong ALL | mean 58.4 s, min 53.5, max 63.9
F5 lantern_shade extreme ALL | mean 29.2 s, min 26.1, max 32.0
determinism: MATCH
```

- **Result:** floor 4 lands in 60-120 s (97.4 / 69.0 s means). Floor 5 means are 57.7 / 58.4 s, **under the 60 s floor**
  (some seeds 49.5 s). Per the task, not retuned; a floor 5 pace of about 5810 x 90 / 58 = ~9000 would be the O2b-style
  one-step correction, left for the lead/owner.
