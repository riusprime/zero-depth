# BALANCE_SG: with stats adding up and one attack-speed curve, does the hidden catch-up now cancel earned synergy?

- **Status:** RUN
- **Build:** the working tree of step SG (branch `v080-sg`, cut from `db725a0`), run before it was committed as the
  step's commit (no code changed between the run and the commit); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux
  (cloud container, 4 CPUs)
- **Date:** 2026-10-20
- **Who ran it:** agent

Owner's words (O91): "Audit CatchUp.power after changing stat semantics; hidden enemy scaling must not cancel earned
synergy." Plan: [`../BALANCE_PASS.md`](../BALANCE_PASS.md) SG item 6.

## Command
```
godot --headless --path . -s scripts/checks/catch_up_probe.gd
```

`scripts/checks/catch_up_probe.gd` builds each loadout on a Gun floor world (`SaveLab.floor_world(31, 1, &"gun")`,
as Main), takes the wand card with `BuildSlots.take` and the stat cards with `Stats.add_card`. **after** is the real
code: `CatchUp.power`, then `CatchUp.multiplier` against the shipped `data/scaling/catch_up.tres` expected power and
cap for floors 1-3 (enemy and boss rows; no threat, loop 1). **before** is the pre-SG formula re-computed inside the
probe (not the old tree: no baseline checkout, CLAUDE.md "Keep steps fast"): the stat cards compounding, the old crit
amounts (4/8/12 and 15/30/50 points), `P = weapon × DAMAGE × GLASS_CANNON × (1 + ONRUSH) × crit × ATTACK_SPEED stat`
(the wand's rate bonus not read) × the same levels term.

## Raw output
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

build | P before | P after | enemy m f1 / f2 / f3 before -> after | boss m f1 / f2 / f3 before -> after
fresh | 1000 | 1000 | [1000, 1000, 1000] -> [1000, 1000, 1000] | [1000, 1000, 1000] -> [1000, 1000, 1000]
5 damage (rare) | 2011 | 1750 | [1418, 1002, 1000] -> [1322, 1000, 1000] | [1002, 1000, 1000] -> [1000, 1000, 1000]
5 attack speed (rare) + Rapid Fire | 1972 | 2072 | [1404, 1000, 1000] -> [1439, 1017, 1000] | [1000, 1000, 1000] -> [1017, 1000, 1000]
3 Glass Cannon (rare) | 1954 | 1750 | [1397, 1000, 1000] -> [1322, 1000, 1000] | [1000, 1000, 1000] -> [1000, 1000, 1000]
crit: 3 chance + 2 damage (rare) | 1286 | 1151 | [1134, 1000, 1000] -> [1072, 1000, 1000] | [1000, 1000, 1000] -> [1000, 1000, 1000]
synergy: 5 dmg + 5 AS + RF + 3 GC | 7748 | 6343 | [1500, 1968, 1391] -> [1500, 1780, 1259] | [1968, 1391, 1052] -> [1780, 1259, 1000]
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Catch-up vs earned power | m must not cancel the build's gain ("hidden enemy scaling must not cancel earned synergy") | O91; BALANCE_PASS SG 6 |

## Result
| Build | P before → after | enemy m floor 1 / 2 / 3, after | Gain kept? |
|---|---|---|---|
| fresh | 1000 → 1000 | 1000 / 1000 / 1000 | — |
| 5 damage | 2011 → 1750 | 1322 / 1000 / 1000 | yes: m = √(P/E) ≤ √P, below the gain |
| 5 attack speed + Rapid Fire | 1972 → 2072 | 1439 / 1017 / 1000 | yes |
| 3 Glass Cannon | 1954 → 1750 | 1322 / 1000 / 1000 | yes |
| crit stack | 1286 → 1151 | 1072 / 1000 / 1000 | yes |
| synergy (all of the above but crit) | 7748 → 6343 | 1500 (cap) / 1780 / 1259 | yes |

## Interpretation
- With the additive rules P falls for every damage, Glass Cannon and crit build (the builds themselves are weaker
  than under compounding), and m falls with it, on every floor. The one rise is the attack-speed build (+5 % P):
  P now counts Rapid Fire's +60 % rate, which it ignored before, through the curve (raw +120 % → +85 %).
- m is the capped square root of P / E, so a build that is k times the expected power meets enemies with at most
  √k more HP: the player keeps √k of the gain at the least. No build here comes near cancelling: the synergy build
  meets ×1.78 HP on floor 2 with ×6.3 power, ×1.26 on floor 3 (it met ×1.97 and ×1.39 before SG).
- So `data/scaling/catch_up.tres` is **not** retuned (BALANCE_PASS SG 6: only if the numbers show cancelling).
- Not proved: how the builds play. Real damage per second also depends on the Blade's swing now scaling as a whole,
  projectile counts (MR) and enemy behaviour; BV compares runs. Whether this feels right is OWNER ONLY.

## Tests run for the step (same tree)
- Lint: `gdformat --check src scripts tests && gdlint src scripts tests` → `1057 files would be left unchanged`,
  `Success: no problems found`.
- `tests/unit/sim` (all but `test_curse_room.gd`), `tests/content`, `tests/arch`, `tests/unit/application`,
  `tests/golden` in one GUT run (`-gtest=<those files>`): my 90-minute `timeout` stopped it during
  `test_starglow_patches.gd`; the 146 files that finished passed `1405/1405`, no failure. The 19 files from
  `test_starglow_patches.gd` on, with `tests/unit/presentation/test_reward_cards.gd`, `test_gun_pulse.gd`,
  `test_blade_feel.gd`, `test_four_slash_view.gd`, re-run: `Tests 227`, `Passing Tests 226`, `Failing Tests 1`:
  `test_wand.gd` "a reorder never changes P" (`[1480] expected to equal [1036]`: P had read the compiled weapon
  attack's bonus, which a reorder past a trigger changes). Fixed by `CatchUp.wand_rate_bonus` (order-free) and
  re-run below.
- `test_wand.gd`, `test_attack_rate.gd`, `test_catch_up.gd`, `test_card_pool.gd` and the e2e
  `test_e2e_curses.gd`, `test_e2e_shop.gd`, `test_e2e_reward_cards.gd`, `test_e2e_old_save.gd`,
  `test_e2e_card_levels.gd`, `test_e2e_card_pool.gd`, `test_e2e_saves.gd`: `Tests 69`, `Passing Tests 69`,
  `Asserts 753`, `Time 184.39s`.
- `tests/golden` (`test_replay_ground_plane.gd`) and `test_modifier_equivalence.gd` passed unchanged: no golden
  changed.
