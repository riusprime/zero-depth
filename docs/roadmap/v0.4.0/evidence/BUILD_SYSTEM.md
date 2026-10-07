# BUILD_SYSTEM: does v0.4.0 Step BS (four ability slots, stat cards, crit, the offers rework) pass the suite and reach the real game?

- **Status:** RUN
- **Build:** `7a4a453` on the BS worktree branch (cut from `claude/lucid-fermat-9wv2tf` at `f8b551d`); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS Linux (cloud container), screenshots under Xvfb with Vulkan on llvmpipe
- **Date:** 2026-10-07
- **Who ran it:** agent

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan -s scripts/shots/build_system.gd
```

## Raw output
Import (`build/evidence/import.log`): exit 0, 0 lines starting `ERROR` or `SCRIPT ERROR`.

Lint:
```
390 files would be left unchanged
Success: no problems found
```

`bash scripts/verify.sh` (tail):
```
Totals
------
Scripts             126
Tests               743
Passing Tests       743
Asserts           421247
Time              458.411s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (743 passing, minimum 743)
```

The e2e through `main.tscn` (input only; the dev panel's buttons clicked with the mouse):
```
res://tests/e2e/test_e2e_abilities.gd
* test_pick_an_ability_card_at_an_altar_and_see_it_fire
    took orbit_blades
* test_blink_card_then_shift_blinks
2/2 passed.
```

The offer mix over 120 seeds (`tests/unit/sim/test_offers.gd`, cards counted by type and stat-card rarity):
```
    altar [mod, ability, stat, common, rare, epic] [26, 155, 179, 118, 48, 13]; chest [114, 61, 185, 80, 69, 36]
```

The replay golden (`tests/golden/test_replay_ground_plane.gd`) and the readable-cause test
(`tests/unit/sim/test_readable_cause.gd`) pass unchanged: no golden was regenerated.

Screenshots (`build/evidence/shots.log`):
```
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
build_system: renderer=forward_plus
build_system: shot …/build/shots/v0.4.0/build_system/01_ability_hud.png
build_system: shot …/build/shots/v0.4.0/build_system/02_pick_with_ability_card.png
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Suite | all pass, ≥ the committed minimum | CLAUDE.md "Testing before a push" |
| Free altar | ≥ 1 ability card while a slot is free | v0.4.0 PLAN, BS; lead's step brief |
| Stat cards | most cards | v0.4.0 PLAN "Stat cards and crit" |
| Crit | 5 %, ×1.5, deterministic on `crit` | v0.4.0 PLAN |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Suite | 743 / 743 (was 701) | yes |
| Free altar | 40 of 40 seeds open with a new ability (`test_every_altar_offers_a_new_ability_while_a_slot_is_free`) | yes |
| Stat cards | altars 179 / 360 cards (50 %), chests 185 / 360 (51 %); the largest type in both | yes |
| Chest rarity | rare + epic stat cards: altars 61 / 179 (34 %), chests 105 / 185 (57 %) | yes (chests roll more) |
| Crit | 4000 rolls at 5 % within 160–240 (`test_crit_rate_over_many_hits`), same seed same rolls | yes |

## Interpretation
The build system is in the sim, reachable from the real game, and covered by tests. Altars lean heavily on ability
cards (43 % of altar cards, because the first card is a guaranteed new ability while a slot is free); whether that
feels right, and every number in the PLAN tables, is the owner's call after playing (OWNER ONLY: feel, fun, balance).
Nothing here measures balance: the expected-build bot and the scaling targets are Steps SC and TU.

## Screenshots
Shot setup (not play): the script grants Bomb Lobber L3, Drone Buddy L3 and Orbit Blades L1 directly and moves the
hero next to an altar before pressing E; the input path is the e2e above.
- [`build_system_ability_hud.png`](build_system_ability_hud.png): the four slots above the HP plate (Combo Sword with
  its key, Bomb Lobber, Drone Buddy, Orbit Blades; level pips under each), the drones by the hero, a damage number.
- [`build_system_pick.png`](build_system_pick.png): with all four slots full, the altar offers a mod (Long Edge), an
  ability level-up (Orbit Blades, "Level 2", the ability mark) and a stat card (Greed, +10 % shards).
