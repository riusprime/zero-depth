# FX: the VFX cleanup (the owner's brief, 2026-10-31)

Branch `claude/v0100-cleanup` in the owner's folder, from `claude/v095-feedback` at `29c061c6`. Done by the lead alone
(the brief: "do not use sub-agents"). Machine: the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2, Windows.
Build SHA: the commit that carries this file.

## What changed, per point of the brief

| # | Point | Root cause found | Change |
|---|---|---|---|
| 1 | Laser + Homing + Pierce | The sim traces a bent beam as short straight legs; VX2 drew each leg as its own pack beam scene with its own start flare (the "7-8 overlapping segments"). Homing turned the aim toward the nearest enemy at 120 °/s (the stiff aim). Targets were picked with no wall check | `laser_view.gd`: the old ribbons are back (`PACK_LASER` off); a lane's legs are one strip through the sim's points, corners rounded (`_join`, `_round`, `_lay_path`). `laser_mods.gd`: Homing keeps the player's aim (`home_dps` removed from the code, `attack_slots.tres` and the validator); a target is at most 90° off the aim and in sight of the one before it in the chain (`World.sees`); legs 0.75 m and 12° (were 1.5 m, 25°), up to 24 |
| 2 | Death explosions and smoke | VX1 added a pack smoke and flash to every kill; VX0 laid a 4.1 s smoke cloud after every pack fire explosion | Both removed (`hit_feel.gd`, `vfx_layer.gd`; rows `vx1_death_smoke`, `vx1_death_pop`, `smoke_after` gone). A kill is the old lit chunks |
| 3 | Sprites in the wrong place, light artifacts | (a) The pack's particles are in world space and Godot does not size them by their node's scale, so every scaled-down effect drew its flares full size. (b) Enemy lob and rain effects were keyed by their index in the frame's list: a landed shot handed its effect, and its trail, to the next one across the screen | (a) `PackFx.WORLD_SPACE`: only projectiles, enemy shots and trails keep world-space particles; the rest are local, so their scale sizes them. (b) Keys by drone id and by drop (`fireball_views.gd`); any held effect that jumps over 1.5 m in a frame restarts its particles (`PackFx.settle`, called by the three holds) |
| 4 | Stack indicators | Pips and dots, one quad a stack | `status_badges.gd` (new): an icon drawn in code and `xN` (`STATUS_STACK_COUNT`, en/es) for burn, bleed, poison, shock and frost, one row facing the camera over the bar |
| 5 | Foundry | VX5's pack fire areas stood on the molten floor's shader (up to 4 a piece, 10 round the meltdown): two looks at once, filling the area family | The flames, their code and rows (`bx_lava_a/b`) removed; the floor shader stays. The rain and lob keys (point 3) were the Foundry's other duplicate |
| 6 | Blink | The pack flash played its full 1.1 s at each end | `PackFx.spawn(..., speed)`: the flash plays its whole animation in 0.28 s; the old fallback is 0.22 s (was 0.36 s) |
| 7 | Seekers | Search 10.8 m, darts flew 10 m (10 m/s, 1 s): edge targets were picked and never reached | Search 12 m, dart life 1.3 s (`gun_seekers.tres`), a target must be in sight of the hero |
| 8 | Void | — | v0.9.5 look back: `VoidView.PACK_VOID`, `PACK_SPARKS`, `GapPack.PACK_RIFT` off; rows `vx2_void_body`, `vx2_void_collapse`, `vx7_void_rift`, `vx7_void_spark` removed |
| 9 | Clutter | Judged one by one | Removed: the frozen pack effects on floor marks (7 s, on the decals: `vx7_mark_frost`, `vx7_mark_splat` and the VfxCore code), the bleed splatter on the splat decal (`vx7_bleed_splat`), the puddle after venom/bleed bursts (`burst_puddle`). Kept: hits, impacts, zones, enemy shots, lightning, blade |

The effect audit behind point 9 (every table row's family and the life PackFx gives it), a tool run, not a test:
`godot --headless --path . -s build/fx_audit/audit.gd` → `build/fx_audit/rows.tsv` (141 rows before this step). The
long-lived rows were the smokes (`smoke_after` 4.1 s, `bx_smoke_big` 6.1 s), puddles and mist (4.1 s), burn flames
(4.1-5.1 s); the boss strikes' smokes keep their 1.1 s cap (`DUST_LIFE_S`).

## Tests (headless, run on this machine)

Lint: `gdformat --check` and `gdlint` on the 36 touched `.gd`: "36 files would be left unchanged", "Success: no
problems found".

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<the 20 effect unit files: test_boss_signature_views(_2), test_enemy_fireball_views, test_hit_feel, test_laser_view, test_movement_vfx, test_pack_explosion, test_pack_fx, test_status_visuals, test_void_view, test_vx1_hits..test_vx8_blade, test_vx5_bosses_views, test_vx_looks; content: test_pack_fx_scenes, test_vfx_manifest> -gexit
Tests               227
Passing Tests       226
Failing Tests         1      (test_vx5_bosses_views: the Foundry lava test; rewritten for point 5, then 12/12 passing)
```
```
-gtest=test_laser_mods (unit) + test_e2e_laser_homing
Passing Tests        21
FC1 e2e: 5 of 5 dummies hurt after 240 frames held; one curved ribbon: true
```
```
-gtest=test_seekers, test_seeker_mods
Tests                36
Passing Tests        36
```
```
-gtest=test_attack_slots, test_card_levels_clv, test_glaive, test_bomb_mods, test_e2e_laser_homing, test_e2e_void_homing, test_e2e_attack_slots, test_attack_slot_views
Tests                66
Passing Tests        65
Failing Tests         1      (test_e2e_laser_homing, before the chain-sight change and its ribbon count; then 5 of 5, above)
```
```
PATH=build/bin:$PATH bash scripts/ci/seams.sh      (goldens, content, arch, old saves, soak, run/save/menu e2e)
Tests               592
Passing Tests       592
Time              1619.854s
```
(Run before the last change to `LaserMods._pick`, sight along the chain; the files that reach it, `test_laser_mods`
and `test_e2e_laser_homing`, were run again after it: 21/21. No golden changed.)

## Shots (off screen, `--position -10000,-10000`, once)

- `build/shots/v0.10.0/vx6/strikes.png`: the white starbursts and discs at the bolts' ends are gone (point 3a).
- `build/shots/v0.10.0/vx1/1_bolt_hits.png`: the pack hits are the old sprites' size.
- `build/shots/v0.9.0/fc1/1_homing_pierce.jpg`: one smooth beam through the dummies (the shot tool now aims at the
  first dummy: it passed the aim distance as the aim, and the old Homing swung the aim for it).
- `build/shots/v0.10.0/fx/badges.png` (`build/fx_audit/badges_shot.gd`, a throwaway tool): icons and counts at the
  game's zoom.

## Not done, or for the owner

- **Feel in play:** OWNER ONLY (the aim of Homing, the badges' size, Blink's pop, the Seekers' reach).
- **Frame time in a Foundry fight:** NOT YET RUN (owner hardware; the cause, a doubled look, is removed, not measured).
- The hero's fire patch still reads pale (I7, the owner's call): unchanged.
