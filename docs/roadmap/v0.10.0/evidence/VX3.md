# v0.10.0 Step VX3: zones, element bursts and status effects use the VFX pack; hero fire patches cooler

Machine: the owner's PC (Windows 11, Godot 4.7.2 console). Branch `v0100-vx3`, cut from `claude/v0100-vfx` (`2aeb4b5c`) plus
this step's tree. No frame-time measurement was taken (lead measures at the end). **OWNER ONLY:** whether any of these
looks right.

## Rows done and id -> scene (data/vfx/pack_fx_vx3.tres)

| Row | Ids (family) | Scene(s) |
|---|---|---|
| R21 fire patch | zone_fire_a/b (area) hero; zone_fire_foe_a/b enemy | fire_area_01/02; fire_area_06/07 |
| R22 frost field | zone_frost_a..d + zone_frost_mist (area) | ice_area_vfx_01..04 + ice_mist_vfx_01 |
| R23 venom field | zone_venom_a/b (area) | poison_puddle_vfx_01/02 |
| R25 bleed pool | zone_bleed (area) | poison_puddle_vfx_01, bleed colours |
| R24 Toxic Fumes | fumes_cloud (cloud, cap 4) | poison_cloud_vfx_01 |
| R26 rings | ring_fire / ring_frost / ring_venom / ring_bleed (area) | rim_area_04 (Ember Ward) / pulse_area_02 (Frost Nova) / pulse_area_03 / rim_area_01 |
| R19 frost burst, shatter | burst_frost (explosion), burst_shatter (impact) | vfx_explosion_07; ice_area_vfx_01 small |
| R20 venom/bleed bursts | burst_venom, burst_bleed (impact), burst_puddle (area) | poison_bubble_vfx_01/03, poison_puddle_vfx_01 |
| Wildfire payoff | burst_wildfire (explosion) | fire_area_03 |
| R28 burn | status_burn_a/b/c (status) | fire_07, fire_05, fire_02 (by enemy) |
| R29 poison | status_poison, status_poison_bubble (status) | stink_small_vfx_01, poison_bubble_vfx_01 |
| R30 frost | status_frost_a/b (status) | ice_mist_vfx_02/03 |
| R41 guard orbs | guard_orb (status) | magic_orb_small_vfx_01 |

Bleed bursts at status (`status_visuals`) use R20's bleed look; shatter and wildfire payoffs now call `burst(&"shatter")` /
`burst(&"wildfire")`. Discharge, jump, strike (storm) untouched.

## How

- New `PackHold` (`vfx/pack_hold.gd`): held effects are touched every frame they should exist; untouched ones go back to
  PackFx at `finish()`. Looping, and per-instance material copies (see findings).
- New `VfxPackViews` (`vfx/vfx_pack_views.gd`): all VX3 pack logic; `vfx_layer.gd` keeps one-line branches (it was at the
  1000-line lint cap). Flags `PACK_ZONES`, `PACK_BURSTS`, `PACK_STATUS`, `ElementVisuals.PACK_ELEMENTS` = old look.
- No room in a family -> that instance draws the old look (tests cover patches, bursts, statuses, clouds).
- I7: `VfxPackViews.kind_colors(kind, true)` runs core/hot/deep through `AttackFormLooks.ground_safe`; the fire area's
  shader colours are set from it. Enemy patches (new `hostile` parameter of `VfxLayer.field`, no caller yet: boss/enemy
  patches are VX5) keep the scene's own warm colours.
- Minimal touch outside the listed files: `world_view_root.gd` (one line giving `element_fx` the PackFx) and
  `test_pack_fx.gd` (warm_all asserts hard-coded 4 ids; now table-size independent).

## Findings for the lead

1. **PackFx instances of one scene share their ShaderMaterials**: a recolour on one recolours all (venom green puddle
   turned bleed puddles red in the first shot). VX3 copies materials per instance after spawn (`PackHold.play`). Suggest doing
   it in `PackFx._take`. Other agents recolouring a scene should do the same.
2. PackFx releases an effect when its "main" animation ends; pack scenes are meant to loop, so held effects set the
   animation to loop (shared resource, so every user of that scene loops; transient users still end by life).
3. `PackHold` reads `PackFx._live` to know an instance was not evicted; a public `is_live(node)` would be cleaner.
4. `vfx_layer.gd` is at 996 lines of 1000.
5. `tests/e2e` element tests (`test_e2e_element_levels`, `test_e2e_element_pairs`) fail before reaching my code: they load
   the missing `tests/e2e/test_e2e_bomb.gd` (Bomb removed). Not caused by this step.

## Shots (NOT final-state: the orb scale was lowered 0.1 -> 0.07 and not re-shot; one run, top old / bottom new)

`build/shots/v0.10.0/vx3/zones.png`, `status.png`, `bursts.png` (build/, untracked). Command:
`godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx3_zones.gd`
Seen: venom/frost/rings read well; hero fire patch is a pale cream disc (ground-safe lean); enemy fire_area_06 is a dim
molten spot; burn wraps the body; frost mist is a wide strip; guard orbs may still be too big. Owner judgement.

## Tests (all `--headless`)

- `tests/unit/presentation/test_vx3_zones.gd`: 28/28 (138 asserts).
- Existing views' batch (25 scripts incl. the above): 288 tests, 286 passed; the 2 failures were `test_pack_fx` warm_all
  assertions, then fixed; rerun of the key subset (11 scripts): 115/115.
- content + arch + golden (34 scripts): 172/172. Goldens unchanged.
- e2e element tests: failing on the missing `test_e2e_bomb.gd` (finding 5), not run to green.
- gdformat/gdlint clean on every touched .gd.

## Not done

- Bleed status and shock: unchanged by design (N2, N1). Frozen cage: ours.
- Frost field crystals, venom bubbles etc. are dropped under the pack (old look is the fallback).
- Fumes, Nova and Ward were not in the shots (tested by unit tests only).
