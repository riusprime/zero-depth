# v0.9.5 Step HT: Gun heat fills with time spent firing; Vent has a cooldown

Owner line: "Hot has to be ease down and scaled to the players context, sometimes it just fills up so quick it doesnt really make sense eany more you just spam the vent button and we don't want that, also, only the pulse gun uses it, most of the attack forms just ignore it". Owner answer (Q12 a): "Heat per second of firing, the same for every form (~14 s to full); cools 1.0 s after you stop at 25/s; Vent needs >= 40 heat, 6 s cooldown."

Base build: d44ea53a (`claude/v095-feedback`) plus this step's commit on branch `v095-ht` (SHA in the lead's report). Machine: owner PC (i7-10700K, Windows 11), Godot 4.7.2 headless, English.

## What changed
- `data/heat/overclock.tres` and `HeatDefinition` / `HeatTable` / `ContentCompiler.compile_heat`: new `gun_fill_seconds = 14.0`, `vent_min_heat = 40.0`, `vent_cooldown_seconds = 6.0`; `decay_delay_seconds` / `decay_per_second` renamed `cool_delay_seconds = 1.0` / `cool_per_second = 25.0` (was 15). All validated positive. Compiled: `gun_fill_ticks 840`, `cool_delay_ticks 60`, `cool_per_tick 417` (25.02 per second after rounding), `vent_min_milli 40000`, `vent_cooldown_ticks 360`.
- `Heat.fire_tick` (called from `PlayerKit.advance`, the heat lines only): on every tick where `PlayerKit.shooting(w) and armed and swing_t == 0` (the one flag the Gun's shot, the Laser's `firing`, the Lance's charge and every form's `GunForms.hold` already use) heat += max / 840 in milli-points, with the remainder carried in `HeatState.fill_rem` (hashed) so 840 firing ticks fill the meter exactly. Attack speed, hits, pierce and projectile count do not enter.
- `Heat.on_hit`: a non-melee, non-skill hit adds nothing on a Gun run (`gain_bolt` is now unused there). Blade swing/finisher gains and skill `heat_gain` (Scatter Blast 2.5) are as before. The Blade has no projectiles of its own.
- Cooling: `cool_delay_ticks` after the last gain (a firing tick or a Blade hit), then `cool_per_tick`; both weapons (was 15/s). Curses' `heat_decay` still scales it.
- Vent: `Heat.vent` / `vent_ready` need heat >= `vent_min_milli`, not overheated, alive, and `KitState.vent_cd == 0`; a vent sets `vent_cd = 360`; `PlayerSkill.advance` counts it down. `vent_cd` is in `KitState` (hashed only while non-zero, so kits that never vented keep their hash; saved by the generic `WorldSnapshot` like the other kit fields). `Heat.read` also returns `vent_min`, `vent_cd`, `vent_cd_total`.
- A refused press: the sim still emits the silent `VENT_COLD` event (event sequence numbers are in the goldens: dropping it changed all 22 digests, which I tried first and reverted); `AudioEvents` no longer maps it to a sound.
- HUD: `KitHud` Vent plate has a `VentSweep` child that draws `AbilitySlot.draw_sweep` (the ability slots' clockwise wedge, now a static helper) and appends the seconds left to the label; the plate is dim whenever `vent_ready` is false (heat < 40, cooling down, overheated).
- `docs/design/SIGNATURE.md` table rows updated (cooling, Gun gain, Vent).
- Also touched `src/application/content_compiler.gd`: `compile_heat` lost its local `m` so the file stays at 1000 lines (lint max). `world.gd` was not touched.

## Hot / Overclock / Overheat on every form now
Unchanged in code. Read from the code, then measured by `test_hot_and_overclock_are_safe_on_every_form` (3 dummies in a line at 2.0 / 3.4 / 4.8 m, 150 ticks held then 60 released, heat held at the level; counts are player HIT events: [heat, hits, hits carrying the Overclock tag]):

| Form | Hot: +20 % reach | Hot: bolts pierce 1 | Overclock: +25 % damage |
|---|---|---|---|
| Orbs | no (only the Blade's `weapon` arcs) | yes (17 hits at 0, 34 at 45) | yes (34 of 34) |
| Laser | no | no (a beam, no projectile) | yes (25 of 25) |
| Bomb | no | no (its touch bursts it, `Bomb.touches`) | no (6 of 6 untagged: the blast is an area hit) |
| Void | no | no (passes bodies, `VoidShots`) | no (0 of 30: the aura is an area hit) |
| Lance | no | no (3 hits both) | yes (3 of 3) |
| Rune Explosion | no | no (a ring) | no (0 of 5: area) |
| Glaive | no | no (24 both; it already returns through) | yes (24 of 24) |
| Seekers | no | yes (27 to 54) | yes (54 of 54) |
| Wave | no | no (9 both) | yes (9 of 9) |
| Wisps | no | yes (34 to 51) | yes (51 of 51) |

No crash on any form at 0 / 45 / 80. Overheat (100, 1.2 s stall, no attacking) now happens after 14 s of continuous fire on every form. The Bomb, Void and Rune Explosion never get the Overclock damage bonus because their hits are `TAG_AREA` (`Heat.NOT_ATTACK`); I added no effect for them. That is an owner call if Overclock should reach them.

## Tests
Added `tests/unit/sim/test_gun_heat_fill.gd` (7 tests): 14 s of held fire from 0 reaches 100 within +-1 tick with Orbs, Bomb and Laser; the same with a Rapid Fire build and a faster Bomb, and landed hits add nothing; no gain while not firing; cooling starts 1.0 s after the last firing tick at 25/s (417 per tick); the Blade's swing still adds 2.5; Vent refused under 40 and during the 6 s cooldown, accepted after; the cooldown is saved, restored and hashed; Hot/Overclock safe on every form (the table above). Added to `test_kit_views.gd`: the Vent plate dims under 40 and counts its 6 s cooldown (seconds text and sweep share).

Existing tests changed (none deleted):
- `test_heat.gd` `test_the_data_compiles_to_the_starting_values`: decay names to cool names, 417 per tick, plus the new fields.
- `test_heat.gd` `test_each_landed_attack_adds_its_type_once`: a landed bolt adds 0; the one firing tick adds 119 (was 1157).
- `test_heat.gd` `test_heat_holds_a_second_then_decays_at_15_per_second` renamed `..._cools_at_25_per_second`: 25 per second.
- `test_heat.gd` `test_a_sustained_fight_reaches_the_thresholds_in_6_to_10_seconds`: the Gun branch expects Hot at 5.6 s and Overclock at 10.5 s (the Blade branch unchanged).
- `test_rune_explosion.gd` `test_it_adds_no_heat` renamed `test_its_heat_is_the_firing_time_only`: 17 points after 150 firing ticks (was 0); two doc lines re-wrapped.
- `test_curses.gd`, `test_trade_off_curses.gd`: `decay_delay_ticks` to `cool_delay_ticks`.
- `test_kit_views.gd` `test_the_skills_and_the_cold_vent_have_sounds`: the cold Vent is now silent (`assert_does_not_have`).
- `test_vent_button.gd`, `test_e2e_kit.gd`: only the message wording of the cold event assertions.

## Goldens changed on purpose
`tests/golden/fixtures/modifier_equivalence.json`, regenerated with `godot --headless --path . -s tests/golden/generate_modifier_equivalence.gd` (only the two cases that enable heat and hold a Gun changed; the other 20 and the replay golden are unchanged):
- `gun_all`: digest `017199d894fc44073d59b74ccbd65e8da0acddcb78c983598dbadea16beed033` to `b813b3d213fc420b6a2cb7cd3545c8eed1837b94bd6eb101694a4eedafdacdf2`; hits 377 to 420 (damage 4160, kills 14 unchanged).
- `both_all`: digest `7b49193f9a304121ee1e2b46282463f407f958b89b7d45f71cbd46b86855356e` to `a5eb26d3e0ba42bb4996488f0ba70b127acb5ee292f8c7536d0c0dd34395bc6c`; hits 194 to 191 (damage 4160, kills 14 unchanged).
- `blade_all` (heat on, Blade only) is unchanged.

## Commands and results
`gdformat --check` and `gdlint` on every touched file: clean. Each run: `APPDATA=<own dir> Godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://<file> -gexit --language en` (or `-gdir=res://<folder> -ginclude_subdirs`).

Final runs (tests, passing / asserts), all passing:
- `test_gun_heat_fill` 7 / 47; `test_heat` 18 / 175; `test_vent_button` 3 / 16; `test_rune_explosion` 15 / 74; `test_modifier_equivalence` 3 / 68.
- `test_player_skill` 13 / 294; `test_mx4_engine` 7 / 25; `test_mx4_modifiers_2` 16 / 55; `test_curses` 13 / 1318; `test_trade_off_curses` 9 / 563; `test_events` 15 / 84; `test_bomb` 10 / 274; `test_void` 17 / 738; `test_laser` 16 / 201; `test_lance` 13 / 126.
- Presentation: `test_heat_views` 7 / 47; `test_kit_views` 6 / 38; `test_kit_view` 4 / 25; `test_hud_style` 15 / 421.
- Folders: `tests/content` 157 / 12653; `tests/golden` 2 / 4; `tests/arch` 4 / 16457.
- E2E: `test_e2e_heat` 1 / 29; `test_e2e_curses` 2 / 34; `test_e2e_kit` 2 / 36.
- Not run (long, left to the lead / CI): `test_five_floors`, `test_curse_room`, `test_modifier_smoke`; and not run: the other `tests/e2e` and `tests/unit` folders (the full suite runs once on GitHub).
- Along the way, one failure that was mine: dropping the silent `VENT_COLD` event changed all 22 equivalence digests; reverted, as above. A `draw_colored_polygon` triangulation error on a near-empty or full wedge in `test_e2e_heat` was fixed by skipping wedges under 1 % and capping at 99 %.
- OWNER ONLY: how 14 s to full, the 25/s cooling and the 6 s Vent feel on his hardware; whether Overclock should reach the Bomb, Void and Rune Explosion (they are area hits).
