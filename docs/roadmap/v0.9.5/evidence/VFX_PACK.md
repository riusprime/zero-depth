# v0.9.5 evidence: the new VFX pack lab (for G1 [VFX_PACK](../VFX_PACK.md))

- **Build:** `17de13e3` (branch `claude/v095-feedback`); nothing in the game changed. The packs were run in throwaway
  lab projects outside the repo, one per pack, with the pack's `assets/` folder as is.
- **Machine:** the owner's PC, i7-10700K, RTX 3060, Windows 11, Godot `4.7.2.stable.official.ed1daf0bf`, Vulkan
  Forward+. Date 2026-10-31.
- **Tools:** `build/vfx_lab/tools/` on the owner's PC (`shoot.gd`, `shoot_mc.gd`, `sheet.gd`, `perf.gd`). They're not
  tracked, so nothing here can be re-run from a fresh clone.
- **Gallery:** `build/vfx_lab/index.html` on the owner's PC: every effect rendered alone, 3 frames each, from the
  game's camera angle (yaw 45°, pitch 35.26°, orthographic).

## Render
```
godot --headless --path <lab> --editor --import --quit                         # each lab: 0 import errors
godot --fixed-fps 60 --path <lab> -s shoot.gd -- <out> 6 [fast]               # per pack
```
Scenes rendered: Fire 32, Beam 18, Ice 20, Magic Orbs 36 (+1 demo scene that fails its own shader, dropped), Magic
Projectiles 15, Impact 24, Magic Area 36, Muzzle Flash 24, Poison 30, Smoke 24, Magic Circles 16 (2 kinds × 8
elements, built in code). Fire log: one `Node not found: "WaveMesh"` error (`fire_forcefield`), drawn anyway.

## Cost probe
```
godot --path <lab> -s perf.gd -- <out.csv> 24                                  # each pack alone, one after another
```
For the first effect of each family, the probe reports:
- the scene's contents;
- the wall time of the frame the first copy appears in (`first_frame_ms`);
- 24 copies in a 6 × 4 grid across the game's 17 m view at 1920×1080, vsync off, averaged over 120 frames. That's
  the measured GPU and CPU render time (`viewport_get_measured_render_time_*`) and the wall time, first with the
  effects' own lights on, then off.

The base scene is a floor, a shadowed sun and glow; it costs about 0.9 ms of GPU time (`gpu_base`).

Raw output (the CSV files, concatenated):
```
effect,nodes,emitters,particles,lights,meshes,first_frame_ms,gpu_base,gpu_x24,cpu_x24,wall_x24,gpu_x24_nolight,wall_x24_nolight
fire_01,5,3,66,0,1,217.8,1.25,1.07,0.25,1.60,1.21,6.77
base_beam_vfx,15,2,128,0,6,342.8,0.91,5.29,0.27,5.94,5.20,5.73
beam_vfx_01,15,2,128,0,6,47.1,0.91,2.63,0.19,3.13,2.66,3.16
blast_vfx_01,12,2,128,0,6,46.9,0.91,2.69,0.18,3.22,2.70,3.20
laser_vfx_01,15,2,128,0,6,2.3,0.91,2.63,0.18,3.16,2.64,3.14
ice_area_vfx_01,5,0,0,1,2,161.9,0.91,2.91,0.15,7.78,1.88,2.39
ice_ball_vfx_01,6,1,32,1,2,1721.0,0.91,6.48,0.18,7.09,5.36,5.87
ice_cloud_vfx_01,4,2,48,0,0,177.7,0.91,2.55,0.15,3.10,4.61,5.17
ice_mist_vfx_01,4,2,32,0,0,118.9,0.91,1.28,0.15,1.81,1.57,2.07
ice_shard_vfx_01,6,2,56,1,1,203.2,0.91,4.31,0.21,4.91,5.87,6.40
magic_orb_basic_vfx_01,7,0,0,1,4,144.5,0.92,1.75,0.14,2.23,1.25,1.71
magic_orb_big_vfx_01,6,0,0,1,3,95.0,0.92,2.13,0.15,6.82,1.45,1.91
magic_orb_flare_vfx_01,6,0,0,1,3,52.7,0.92,1.53,0.13,2.03,1.13,1.60
magic_orb_flash_vfx_01,6,0,0,1,3,8.6,0.92,1.77,0.14,2.29,1.27,1.75
magic_orb_huge_vfx_01,5,0,0,1,2,2.0,0.92,2.17,0.13,2.70,1.49,1.95
magic_orb_small_vfx_01,5,0,0,1,2,2.1,0.92,1.55,0.13,2.04,1.14,1.59
m_projectile_basic_vfx_05,6,0,0,1,3,86.8,0.91,1.48,0.14,2.04,1.36,2.35
m_projectile_javelin_vfx_05,6,0,0,1,3,2.5,0.91,1.46,0.14,1.95,1.11,1.59
mprojectile_wave_vfx_01,7,0,0,1,4,55.5,0.91,1.62,0.14,2.21,1.16,1.64
vfx_explosion_01,9,4,51,1,1,354.6,0.92,7.03,0.33,7.74,4.66,5.60
vfx_hit_01,7,3,3,1,1,4.8,0.92,2.02,0.21,2.70,1.27,2.12
vfx_impact_01,10,3,18,1,3,301.3,0.92,5.32,0.32,6.09,3.34,3.99
basic_area_vfx_01,9,2,2,1,4,414.2,0.91,4.23,0.22,4.80,1.86,2.33
lift_area_vfx_01,7,0,0,1,4,81.6,0.91,4.75,0.15,5.31,2.02,2.55
pillar_area_vfx_01,8,0,0,1,5,137.9,0.91,5.84,0.16,6.39,2.36,6.99
pulse_area_vfx_01,5,0,0,1,2,58.7,0.91,3.67,0.14,4.19,1.67,2.25
rim_area_vfx_01,8,0,0,1,5,99.1,0.91,6.14,0.17,6.85,2.39,2.91
ripple_area_vfx_01,6,0,0,1,3,67.2,0.91,6.49,0.16,7.12,2.08,2.54
big_flash_01,7,3,12,1,1,94.5,0.91,1.76,0.19,2.25,1.48,1.98
muzzle_flash_01,7,3,8,1,1,91.1,0.91,1.44,0.18,1.95,1.33,2.00
short_flash_01,6,2,4,1,1,2.4,0.91,1.26,0.16,1.74,1.11,1.59
wide_flash_01,6,2,5,1,1,2.5,0.91,1.24,0.16,1.74,1.12,5.66
poison_area_vfx_01,7,1,16,1,3,221.3,0.91,2.57,0.18,5.23,1.72,4.24
poison_bubble_vfx_01,6,1,16,1,2,101.2,0.91,2.82,0.18,3.39,1.29,1.87
poison_cloud_vfx_01,5,2,40,0,1,356.8,0.91,7.21,0.21,7.95,16.97,17.59
poison_puddle_vfx_01,6,1,24,1,2,94.6,0.91,3.00,0.20,3.72,1.97,2.59
stink_big_vfx_01,4,2,24,0,0,122.6,0.91,1.42,0.19,2.03,1.63,2.24
stink_small_vfx_01,4,2,16,0,0,2.1,0.91,1.35,0.20,1.93,1.52,2.03
smoke_vfx_01,3,2,72,0,0,1590.1,0.92,8.31,0.32,9.41,23.28,24.39
smoke_big_vfx_01,3,2,72,0,0,105.8,0.92,3.35,0.27,3.91,13.85,17.37
smoke_thin_vfx_01,3,2,48,0,0,106.1,0.92,2.42,0.26,2.95,5.24,5.81
```

## Reading it (and its limits)
- **`first_frame_ms` is a cold start:** a fresh lab project with no shader or pipeline cache. A player's first run is
  cold too. Effects later in a pack's list reuse shaders compiled earlier in the list, so they read lower (for example
  `laser_vfx_01` reads 2.3 ms after the beams before it). Take each pack's first row as the honest cold cost.
- **The no-light reading was taken 120 frames after the lit one.** Smoke and poison clouds keep growing over that time,
  so their no-light numbers are higher and are not a clean lights-off figure. The other families are steady loops, and
  for them the lit vs unlit gap is the lights' cost.
- **Single runs, no repeats:** small differences (±0.3 ms) are noise.
- **Not tested here:**
  - the effects inside the real game (with enemies, the HUD and the existing VFX);
  - the mid-run hitch probe (`scripts/checks/hitch_probe.gd`);
  - the 144 fps target (PLAN PF).
