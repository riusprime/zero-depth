# v0.9.0 SV: survival across five floors (evidence)

The owner's row in [`../PLAN.md`](../PLAN.md) ("EL, SV"): "enemies almost oneshot you because the scaling per floor,
but you hp or resistance doeasnt stack, we should not make the player rely on picking dmg reduction cards this hard,
just a bit to be safer but not a must … I am not able to get to the finall boss due to dying way too fast"; then "Hero
grows each floor (Recommended)"; "A bit safer, never a must (Recommended)".

Build SHA: `da3dc7fc` (branch `v090-sv`, cut from the local `claude/world-combat-v090` head `cd0e6ad8`). Machine: the
owner's PC (i7-10700K, RTX 3060), Godot 4.7.2, headless.

## What changed

- `data/run/five_floors.tres`: `max_hp_per_floor = 15` (new RunDefinition field, default 0) and
  `heal_between_floors` 0.4 → **0.6**. New `max_hp_floor_cap` (default 0 = no cap): **chosen: no cap**, so the loops
  keep growing +15 a floor (loop 2 floor 1 = run floor 6 = +75). `three_floors.tres` (old saves) is unchanged: no
  growth, 40 %.
- The growth is `RunCarry.floor_hp_bonus(table, run_floor) = 15 × (run floor − 1)`: 100, 115, 130, 145, 160 on floors
  1-5; the final arena stays on floor 5, so it's 160 there too. It's added to the table HP **before** the max HP stat
  (`Stats.max_hp_at`), so max HP cards, Fortune's max HP win (a stat win in a run with stat cards) and Glass Heart all
  scale the base and the growth together.
- When the bonus arrives, the hero gains the same HP: `RunState.finish_floor` (via `RunCarry.grow`) adds the max HP the
  growth adds (through the max HP stat) to the carry's HP, after the 60 % heal (which is taken of the old max). Clamped
  to the new max.
- Saves: `World.floor_hp_bonus` isn't saved. `RunState.prepare` derives it from the run's floor (in
  `WorldSnapshot.WORLD_KEPT`: "rebuilt"), so a resumed floor gets it back. **Old saves:** the bonus is derived from the
  floor index. A v0.8.0 save runs `three_floors` (0 a floor), so nothing changes for it. A v0.9.0 five-floor save from
  before SV resumes with its floor's growth in the max HP and its saved HP as it was. The state hash doesn't include
  the field, so no golden changes.
- HUD: the floor's arrival card adds a green line, `HUD_MAX_HP_GROWN` "Max HP +%d" / "Vida máxima +%d". It shows on a
  floor the hero grew into, but not on floor 1, a resumed floor, or the final arena (`RunCarry.hp_grown`).

## The check: whole five-floor runs, scripted heroes

`scripts/balance/survival.gd` + `tests/support/survival_run.gd`. This is **not** the retired balance bots (SCORECARD,
owner 2026-10-08: "they do not represent reality"); the owner's SV row asked for this check. Each run follows
`RunLab`, floor by floor, built as Main builds them. On every floor the hero takes 3 stat cards (offence round-robin
Damage / Attack speed / Crit chance; common on floors 1-2, rare on 3-4, epic on 5). The defence policy swaps the first
card of each floor for Max HP or Armour, alternating. It then fights 90 s of the floor's spawns from the start hall (a
kiting `Survivor` bot that dashes out of wind-ups). Then it fights the boss room, entered at the door, with
test_final_pace's `Hero` (dashes every boss attack's telegraph). Then it takes the portal, and after floor 5 the final
arena (`FinalLab.arena` on the run's own state and carry). No wand or ability cards beyond the start.

**What the scripted hero can and can't show:** at full HP it dies on floor 1 or 2 on every seed. Its mean HP lost on
floor 1 alone is 171 (Blade) and 276 (Gun), against 100 max HP. So the runs are a **damage ledger**: the hero is healed
every tick (as test_boss_pace and test_final_pace fight), it plays every floor, and the HP it lost is counted per floor
(floor fighting, boss). `SurvivalRun.pool` then replays the HP pool from each ledger under both rule sets: **before
SV** (no growth, 40 % heal) and **after SV** (data: +15, 60 %), with floor 1's boss-room heal. It does this at several
**shares of the bot's damage** a player might take (100 % = the bot itself), and per seed finds the largest share that
still reaches the final boss. Same seeds, same code, same ledger, so before and after differ only in the owner's two
numbers.

Command (from the worktree, own `APPDATA`; took 4465 s):

```
godot --headless --path . -s scripts/balance/survival.gd -- seeds=20 from=1 floor_s=90
```

### Summary (from the output below)

| Build (seeds 1-20) | Largest share of the bot's damage that still reaches the final boss: median (min-max), before → after | Reach the final boss at 10 % of the bot's damage, before → after |
|---|---|---|
| Blade, no defence card | 7 % (6-8) → **12 %** (11-14) | 0/20 → **20/20** |
| Gun, no defence card | 4 % (3-5) → **7 %** (5-9) | 0/20 → 0/20 (deaths F2/F3/F4 1/18/1 → F3/F4 4/16) |
| Blade, a defence card a floor | 9 % (8-10) → **15 %** (13-17) | 3/20 → **20/20** |
| Gun, a defence card a floor | 5 % (5-6) → **9 %** (8-11) | 0/20 → 7/20 |

Read honestly:
- **At the bot's own damage (100 %) nothing reaches the final boss, before or after.** 15/20 Blade runs and 20/20 Gun
  runs die on floor 1, the rest on floor 2. The scripted hero is far below a player, so this can't say whether the
  owner now reaches the final boss. That's `OWNER ONLY` (playtest).
- What it does show: with the same damage taken, SV lets a no-defence run take about **1.7×** as much damage and still
  reach the final boss (Blade 7 → 12 %, Gun 4 → 7 %). That's more than a defence card a floor gave before SV (Blade 9 %,
  Gun 5 %). Defence cards still add on top after SV (Blade 12 → 15 %, Gun 7 → 9 %): "a bit safer, never a must".
- Beating the final boss: 0 in every cell. The healed bot needs minutes against the final boss and loses 2643 (Blade)
  / 3654 (Gun) HP on average there, more than any pool. That's a fact about the bot's final fight, and this check
  doesn't measure it.
- The Gun bot takes more than the Blade bot (the Hero script stands in melee reach, inside boss attacks' bands), so its
  numbers are the less trustworthy of the two.
- No retune beyond the owner's two numbers. The cap stays 0 (none).

### Raw output (`build/balance/survival.txt`, SHA da3dc7fc)

```
survival: seeds 1..20, 90 s of floor fighting a floor, 3 stat cards a floor; after SV: +15 max HP a floor, heal 600 permille

== blade, no defence card (20 runs)
  the bot's HP lost (mean) floor/boss: F1 48/123 (max HP 100 before, 100 after); F2 193/240 (max HP 100 before, 115 after); F3 258/428 (max HP 100 before, 130 after); F4 329/711 (max HP 100 before, 145 after); F5 438/431 (max HP 100 before, 160 after);
  final fight: HP lost 2643 (mean), the healed bot beat it 20/20
  share of the bot's damage | before SV | after SV
  100% | reach 0/20, beat 0, died on F1-F5 [15, 5, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [15, 5, 0, 0, 0]
  50% | reach 0/20, beat 0, died on F1-F5 [1, 19, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [1, 19, 0, 0, 0]
  35% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 19, 1, 0, 0]
  25% | reach 0/20, beat 0, died on F1-F5 [0, 11, 9, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 7, 13, 0, 0]
  20% | reach 0/20, beat 0, died on F1-F5 [0, 5, 15, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 0, 17, 3, 0]
  15% | reach 0/20, beat 0, died on F1-F5 [0, 0, 19, 1, 0] | reach 0/20, beat 0, died on F1-F5 [0, 0, 2, 16, 2]
  10% | reach 0/20, beat 0, died on F1-F5 [0, 0, 0, 20, 0] | reach 20/20, beat 0, died on F1-F5 [0, 0, 0, 0, 0]
  before SV: the largest share that still reaches the final boss, per seed (%): median 7, min 6, max 8
  after SV: the largest share that still reaches the final boss, per seed (%): median 12, min 11, max 14
  HP by floor at 100% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 51 | 5
    2 | 5 | 60 | 0 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 100% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 51 | 5
    2 | 5 | 95 | 0 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 88 | 69
    2 | 20 | 98 | 50 | 4
    3 | 9 | 49 | 0 | 0
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 88 | 69
    2 | 20 | 115 | 67 | 12
    3 | 13 | 103 | 41 | 0
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -

== gun, no defence card (20 runs)
  the bot's HP lost (mean) floor/boss: F1 50/226 (max HP 100 before, 100 after); F2 267/502 (max HP 100 before, 115 after); F3 400/662 (max HP 100 before, 130 after); F4 576/1252 (max HP 100 before, 145 after); F5 652/784 (max HP 100 before, 160 after);
  final fight: HP lost 3654 (mean), the healed bot beat it 20/20
  share of the bot's damage | before SV | after SV
  100% | reach 0/20, beat 0, died on F1-F5 [20, 0, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [20, 0, 0, 0, 0]
  50% | reach 0/20, beat 0, died on F1-F5 [18, 2, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [18, 2, 0, 0, 0]
  35% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0]
  25% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0]
  20% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0]
  15% | reach 0/20, beat 0, died on F1-F5 [0, 15, 5, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 10, 10, 0, 0]
  10% | reach 0/20, beat 0, died on F1-F5 [0, 1, 18, 1, 0] | reach 0/20, beat 0, died on F1-F5 [0, 0, 4, 16, 0]
  before SV: the largest share that still reaches the final boss, per seed (%): median 4, min 3, max 5
  after SV: the largest share that still reaches the final boss, per seed (%): median 7, min 5, max 9
  HP by floor at 100% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 49 | 0
    2 | 0 | - | - | -
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 100% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 49 | 0
    2 | 0 | - | - | -
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 87 | 43
    2 | 20 | 83 | 19 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 100 | 87 | 43
    2 | 20 | 113 | 47 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -

== blade, a defence card a floor (20 runs)
  the bot's HP lost (mean) floor/boss: F1 48/126 (max HP 108 before, 108 after); F2 198/258 (max HP 108 before, 124 after); F3 251/469 (max HP 124 before, 161 after); F4 323/748 (max HP 124 before, 180 after); F5 431/475 (max HP 155 before, 248 after);
  final fight: HP lost 3082 (mean), the healed bot beat it 20/20
  share of the bot's damage | before SV | after SV
  100% | reach 0/20, beat 0, died on F1-F5 [14, 6, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [14, 6, 0, 0, 0]
  50% | reach 0/20, beat 0, died on F1-F5 [1, 19, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [1, 19, 0, 0, 0]
  35% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 18, 2, 0, 0]
  25% | reach 0/20, beat 0, died on F1-F5 [0, 13, 7, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 5, 15, 0, 0]
  20% | reach 0/20, beat 0, died on F1-F5 [0, 3, 17, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 0, 9, 11, 0]
  15% | reach 0/20, beat 0, died on F1-F5 [0, 0, 12, 8, 0] | reach 12/20, beat 0, died on F1-F5 [0, 0, 0, 8, 0]
  10% | reach 3/20, beat 0, died on F1-F5 [0, 0, 0, 12, 5] | reach 20/20, beat 0, died on F1-F5 [0, 0, 0, 0, 0]
  before SV: the largest share that still reaches the final boss, per seed (%): median 9, min 8, max 10
  after SV: the largest share that still reaches the final boss, per seed (%): median 15, min 13, max 17
  HP by floor at 100% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 59 | 5
    2 | 6 | 61 | 0 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 100% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 59 | 5
    2 | 6 | 98 | 0 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 96 | 76
    2 | 20 | 107 | 57 | 4
    3 | 7 | 73 | 7 | 0
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 96 | 76
    2 | 20 | 124 | 74 | 14
    3 | 15 | 129 | 67 | 0
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -

== gun, a defence card a floor (20 runs)
  the bot's HP lost (mean) floor/boss: F1 49/239 (max HP 108 before, 108 after); F2 265/466 (max HP 108 before, 124 after); F3 393/797 (max HP 124 before, 161 after); F4 511/1173 (max HP 124 before, 180 after); F5 598/782 (max HP 155 before, 248 after);
  final fight: HP lost 4115 (mean), the healed bot beat it 20/20
  share of the bot's damage | before SV | after SV
  100% | reach 0/20, beat 0, died on F1-F5 [20, 0, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [20, 0, 0, 0, 0]
  50% | reach 0/20, beat 0, died on F1-F5 [16, 4, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [16, 4, 0, 0, 0]
  35% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0]
  25% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0]
  20% | reach 0/20, beat 0, died on F1-F5 [0, 20, 0, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 16, 4, 0, 0]
  15% | reach 0/20, beat 0, died on F1-F5 [0, 9, 11, 0, 0] | reach 0/20, beat 0, died on F1-F5 [0, 5, 15, 0, 0]
  10% | reach 0/20, beat 0, died on F1-F5 [0, 0, 17, 3, 0] | reach 7/20, beat 0, died on F1-F5 [0, 0, 1, 12, 0]
  before SV: the largest share that still reaches the final boss, per seed (%): median 5, min 5, max 6
  after SV: the largest share that still reaches the final boss, per seed (%): median 9, min 8, max 11
  HP by floor at 100% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 58 | 0
    2 | 0 | - | - | -
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 100% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 58 | 0
    2 | 0 | - | - | -
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, before SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 95 | 48
    2 | 20 | 91 | 28 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
  HP by floor at 25% of the bot's damage, after SV: floor | reached | arrive | boss door | after boss
    1 | 20 | 108 | 95 | 48
    2 | 20 | 122 | 56 | 0
    3 | 0 | - | - | -
    4 | 0 | - | - | -
    5 | 0 | - | - | -
    final arena arrival HP (mean of 0): -
took 4465 s
```

## test_final_pace (the owner's accepted red)

Before (`FIVE_FLOORS.md`, the FV step, floor 5): `N2 pace base blade: bodies (s) [112.8, 101.0, 146.7]`, `strong
blade: [71.0, 73.9, 148.8]`. After (da3dc7fc's code, the unit run below): **identical**. Its hero is healed every
tick, so max HP doesn't move it.

```
    N2 pace base blade: won=true, bodies (s) [112.8, 101.0, 146.7], [max HP, measured dps] [[2849, 18], [684, 33], [3801, 33]], hits taken 97
    N2 pace strong blade: won=true, bodies (s) [71.0, 73.9, 148.8], [max HP, measured dps] [[8256, 137], [2353, 217], [13077, 217]], hits taken 43
    [Failed]:  [146.7] expected to be >= than [147.8]:  strong blade body 2: no slower than the base build
    N2 pace absurd gun (Chain Blast + Split + Spread Lv 5, loop 3): won=true, bodies (s) [64.9, 70.8, 80.7], [max HP, measured dps] [[6253, 90], [1249, 111], [6941, 111]], hits taken 39
    N2 pace absurd blade (Chain Blast + Double Slash + On Hit x2 Lv 5, loop 3): won=true, bodies (s) [64.3, 74.2, 100.2], [max HP, measured dps] [[8868, 147], [2468, 228], [13713, 228]], hits taken 40
```

## Tests (owner's PC, own APPDATA, one Godot process at a time)

| Run | Result |
|---|---|
| `gdformat --check src scripts tests && gdlint src scripts tests` | `1298 files would be left unchanged` / `Success: no problems found` |
| test_hero_growth (new), test_floor_card_growth (new), test_run_saves, test_old_saves, test_world_snapshot, test_state_hasher, test_balance_tools, test_five_floors, test_layering, test_sim_purity, test_routes_view, test_final_pace | `Scripts 12 / Tests 88 / Passing 85 / Failing 3`: test_five_floors `[600] expected to equal [400]` (the heal assert, updated on purpose to 600, passing in the next run); test_five_floors `test_a_run_never_meets_a_boss_twice` ("floors 4 and 5 have no pool yet", "floor 4 can meet any of the six" `[2] expected to equal [6]`: **not SV**, NB1-NB3's floor-4/5 boss pools); test_final_pace (above) |
| test_e2e_run_flow, test_e2e_old_save, test_e2e_saves, test_e2e_after_boss, test_five_floors | `Scripts 5 / Tests 16 / Passing 14 / Failing 2`: test_e2e_run_flow "healed 40 % of max HP" `[115] expected to equal [100]` (updated on purpose: max HP 115, `min(100, hp + 60) + 15`, the card's "Max HP +15"); the NB boss-pool test as above |
| tests/content (all, -ginclude_subdirs) + test_e2e_run_flow | `Scripts 30 / Tests 153 / Passing 153` |

Goldens changed on purpose: **none** (the growth is 0 on floor 1, and `floor_hp_bonus` is outside the hash).
Not run locally: the full suite (GitHub), seams.sh (the lead's).

Found, not fixed (older than SV): `RunCarry.apply` sets the max HP (`Gamble.after_carry`) before the floor's stat tables
are set (Main and the labs set them after the carry). So a Fortune max HP win also counts as its flat +8 on the next
floors, until something recomputes max HP. test_hero_growth checks the formula through `Stats.max_hp` for that reason.

Owner checks: `OWNER ONLY`. Does a run with no defence card now reach the final boss? Does floor 5 still feel
dangerous? Is "Max HP +15" readable on the arrival card?
