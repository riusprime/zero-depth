# Step WB: wisp shots deal 80 % of an orb and pierce one enemy

Owner Q13 a. Built on top of 27b2dfe0 (v095-wb branch). Machine: owner PC (Windows, Godot 4.7.2 console).

Change: gun_wisps.tres wisp_permille 400 (+20/level) -> 800 (no per level); AttackContext.extra_pierce (wisps set 1) ->
World.set_pending_pierce -> ProjectileMoves.on_spawn adds it to pierce_left.

## DPS (scripts/balance/forms_dps.gd, row "wisps | 1 | no": whole build = orbs + wisps, vs the plain orbs)

| | single x | line x | pack x | single dmg | line dmg | pack dmg |
|---|---|---|---|---|---|---|
| before | 1.301 | 1.299 | 1.309 | 1210 | 435 | 432 |
| after | 1.602 | 1.800 | 1.618 | 1490 | 603 | 534 |

Orbs baseline: 930 / 335 / 330. Wisps alone, single target 4 m, 28 s (test_wisps output): 560 dmg = 0.602 of the orbs.
The row includes the hero's own orbs, so the whole-build ratio rises less than the wisp part alone (about x2 single).

## Tests (own APPDATA, --language en; raw "Passing Tests")
- tests/unit/sim/test_wisps.gd: 13/13
- test_shot_rate_all_forms + test_modifier_equivalence + test_e2e_wave_wisps: 7/7 (3 scripts)
- tests/content + tests/arch: 161/161 (32 scripts)
- tests/golden: 2/2 (no digest changed)
