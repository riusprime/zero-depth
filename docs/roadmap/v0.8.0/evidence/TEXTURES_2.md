# TEXTURES_2: are the owner's ground, impact and surface textures in place of the code looks? (v0.8.0 Step TX2)

- **Status:** RUN (agent: install, tests, shots on software Vulkan, llvmpipe, under xvfb; not the owner's hardware).
  How it looks and feels in play: **OWNER ONLY**.
- **Build:** branch `v080-tx2` from `ab51a15` (the step's commit, `v0.8.0 Step TX2: …`; the tests and the last shots
  ran on its tree before it was committed, only these docs were written after). The "before" shots: a detached
  worktree at `ab51a15`. Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18.44 (cloud container, no GPU).
- **Date:** 2026-10-16
- **Who ran it:** agent

## What replaced what
Request: [`../../../art/requests/v0.8.0_textures.md`](../../../art/requests/v0.8.0_textures.md). Every swap keeps
the code look as the fallback while its texture is missing (a `*_on` flag in the shaders, `VfxCore.has_tex`,
`BossStrikeMeshes.textured`).

| id (installed file) | prepared as | replaces (code) | where |
|---|---|---|---|
| `fx_ground_cracks` (vfx, 1024, 2×2) | colour kept, alpha = the glowing crack (it was painted on brown ground, not black: keyed on red over green or a bright red channel) | the cellular cracks: the Gatekeeper's shock-lane marker (`TelegraphViews.CRACK_SHADER`), the STONE marker pattern (`BossStrikeLooks.MARK_SHADER`: Gatekeeper slam, Colossus fists/slam/leap/boulders/spikes), the crater quads' veins (`BossStrikeMeshes.GROUND` p0: craters, leap impacts, eruptions, shells, javelins, light bursts, the vent's floor), and the floor marks a crater, a javelin or a spike row leaves (new decal kind `cracks`, in place of `scorch`) | tinted by the look's glow (the code colour) |
| `fx_rock_burst` (vfx, 1024, 2×2, its own alpha) | resized | the code rock and dust burst | new VfxCore sprite pool `rockburst` (cap 48): one burst per crater, leap impact or eruption disc (`BossStrikeFx._rock_burst`); the 3D rock chunks stay |
| `fx_dust_ring` (vfx, 1024, 2×2) | colour kept, alpha = pale dust or grey stones (painted on brown ground) | the code shockwave band (`band_mix` DUST) | crater fronts (Gatekeeper/Colossus slams and leaps, Brood leap), the burrow's eruption, shock rings up to 6 m (`DUST_RING_MAX_M`); the Warden's P1 slam dust ring (a textured quad, same radius, same neutral tint) |
| `fx_light_ring` (vfx, 512, its own alpha) | resized | the Hive Lens flare's tall glow band | a flat ring on the floor (`G_LIGHT_RING`), a low glow band kept on it |
| `fx_acid_splat` (vfx, 1024, 2×2, its own alpha) | resized | the code green splat (`GROUND` p2) | Brood Mother eggs and brood |
| `fx_steam_puffs` (vfx, 1024, 2×2; upload 1536×1024 re-gridded) | glow (alpha = brightest channel) | the steam wall (`band_mix` STEAM) | new VfxCore sprite pool `steam` (cap 96): the Foundry vent blast's ring of puffs (`BossStrikeFx._puff_ring`) |
| `fx_skid_marks` (vfx, 1024, 2×2, its own alpha) | resized | the scorch line of the lunge (`GROUND` p1) | `G_SKID`: cell 0 (two straight grooves) repeated down the lunge, sampled with gradients (no mip seam); embers cool as it fades |
| `fx_crystal_shatter` (vfx, 1024, 2×2; upload 1536×1024 re-gridded) | glow | (nothing drew a burst sprite; the shards and a light did) | new VfxCore pool `shatter` (cap 32, additive): `FinalBossViews.draw_fx`, four bursts for 0.55 s where a final-boss body bursts |
| `fx_lava_flow` (vfx, 512, tile) | colour + alpha = the bright veins, made to wrap | the molten noise | Foundry lava floor (`BossSignatureShaders.LAVA`), meltdown (`MELT`), the molten flood lanes (`GROUND` p3) |
| `tex_lava_crust` (kit, 512, tile) | colour + alpha = the hot seams | the crust noise | the same three, its plates closing in as the lava cools; the MOLTEN marker pattern (Foundry) |
| `tex_mark_steel` / `tex_mark_hazard` / `tex_mark_acid` / `tex_mark_light` (kit, 512, tiles) | colour + alpha = scratches / amber paint / acid / gold seams | the BLADE / HAZARD / ACID / LIGHT marker patterns | Warlord / Siege Engine / Brood Mother / Hive Lens locked markers and windup fills |
| `tex_stone_spike` (kit, 512, tile) | colour + alpha = the red-hot cracks | the spike stone noise | `StoneSpikeViews.SHADER` (Gatekeeper and Colossus spikes, pillars): albedo from the stone, its cracks the hot veins |

Not swapped: the VOID marker pattern (the Nemesis; no texture asked), the rail streak and the rail's scorched line
(`fx_rail_streak` not delivered), the Colossus/Gatekeeper sweep arcs (a swoosh of vertex-coloured triangles, the ring
texture has no arc to map onto), the Prism's window ring and shard flares (`PrismViews`, `PrismAvatar`: not swapped, they
need a new mesh or UVs for the ring and shatter textures), shock rings wider than 6 m (the Siege Engine's room-wide
shockwave: the ring blown up to the room covered the whole floor in the shots, so it keeps the rolling code band).

Readability: the owner's rule (red ground marks only for the Arc Caster rune, Mine Layer mines and the Warden's slam
circle) is untouched: no new mark is red; the textured patterns take each look's glow (orange, gold, amber, green,
steel) and the lock flash still drives `heat` (the tracking outline, the bright edge and the pulse are unchanged).
The Warden's red slam circle is TelegraphViews', untouched; only the dust ring after the impact changed.
Budgets: decals still 64 (one new decal kind, same pool, overlapping marks of a kind still merge); three new
sprite pools are one MultiMesh (one draw) each, inside `MAX_SPRITES` 2,000 (the pools' caps now sum to 2,656);
the ground quads take the new looks in the existing ground MultiMesh (no draw added); no draw per instance.

## Commands
```
python3 -I scripts/assets/tx2_prep.py                       # writes the 15 textures, prints hashes and seam checks
godot --headless --path . --editor --import --quit          # .import: VRAM compressed, mipmaps (as the earlier installs)
godot --headless --path . -s scripts/content/build_credits.gd
gdformat --check src scripts tests && gdlint src scripts tests
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_bosses.gd,res://tests/e2e/test_e2e_bosses_2.gd,res://tests/e2e/test_e2e_boss_strikes.gd,res://tests/e2e/test_e2e_boss_signatures.gd,res://tests/e2e/test_e2e_boss_signatures_2.gd,res://tests/e2e/test_e2e_boss_dodge.gd,res://tests/e2e/test_e2e_boss_dodge_2.gd,res://tests/e2e/test_e2e_boss_dodge_3.gd,res://tests/e2e/test_e2e_final_boss.gd,res://tests/e2e/test_e2e_damage_soak.gd,res://tests/e2e/test_e2e_enemies.gd -gexit
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_visuals_2.gd -- from=N to=M
    (also attack_visuals.gd -- from=12, final_boss.gd -- 7, boss_signatures_2.gd -- 10, melee_strikes.gd)
```

## Raw output
`tx2_prep.py` (seam: the mean step across the wrapped edge against the mean step between neighbouring pixels; equal
means no seam. The sources' edges did not wrap: each was cross-faded over 6 % of its width; the hazard stripes were
first cropped to two whole stripe periods so they run on across the wrap):
```
02bf2a4eab3b58c38ee0b5225133187e73bd973fa8ceee51530b6fd8b112c77e   1418568  assets/textures/vfx/fx_ground_cracks.png
397ee2eb3042e9682ddb259ac1540f97d2ce5e45bf7957da3099ee30c286c1d5   1353765  assets/textures/vfx/fx_rock_burst.png
b3d7e7f9026f707462fa866e86827fa4db7fc5a8e8d9d54d8c37b16607e36560   1456803  assets/textures/vfx/fx_dust_ring.png
e3166f8c23b559c27f4746605ed4baadc62a1ee4026212e045ccf38fe61356fc    141171  assets/textures/vfx/fx_light_ring.png
867bf4b95f210cc0bf1789378c9499e82ca45dc0df6b511002a12f205386953d   1126011  assets/textures/vfx/fx_acid_splat.png
4bb1985f464ffdc1543b3ba6b6cd1ede315228670bdc6ba1b21105b290005290    685444  assets/textures/vfx/fx_steam_puffs.png
0b3c6c6c88b0233605ad5fb6668dfaa91ac5aa504de1b3c15cebbf8e0d7e2205   1474583  assets/textures/vfx/fx_skid_marks.png
7789d42bdd637a23ec063cad2a184334f0967bf0e785867c508f92edc9107603    809336  assets/textures/vfx/fx_crystal_shatter.png
fx_lava_flow source:   seam x 4.2 (neighbours 1.3)  y 4.3 (neighbours 1.6)
fx_lava_flow installed: seam x 2.6 (neighbours 2.5)  y 3.8 (neighbours 3.2)
tex_lava_crust source:   seam x 4.2 (neighbours 2.5)  y 6.3 (neighbours 2.7)
tex_lava_crust installed: seam x 4.8 (neighbours 4.8)  y 6.5 (neighbours 5.3)
tex_mark_steel source:   seam x 6.9 (neighbours 3.7)  y 7.0 (neighbours 4.6)
tex_mark_steel installed: seam x 5.9 (neighbours 5.3)  y 7.0 (neighbours 6.4)
tex_mark_hazard: stripe period 563 px, 2 periods, crop 1201 px
tex_mark_hazard source:   seam x 21.2 (neighbours 6.5)  y 40.0 (neighbours 6.8)
tex_mark_hazard installed: seam x 8.0 (neighbours 7.4)  y 8.0 (neighbours 7.6)
tex_mark_acid source:   seam x 5.7 (neighbours 2.8)  y 6.5 (neighbours 3.1)
tex_mark_acid installed: seam x 3.9 (neighbours 5.4)  y 4.7 (neighbours 6.2)
tex_mark_light source:   seam x 5.0 (neighbours 2.2)  y 5.6 (neighbours 2.4)
tex_mark_light installed: seam x 4.7 (neighbours 3.3)  y 2.3 (neighbours 3.5)
tex_stone_spike source:   seam x 4.5 (neighbours 2.5)  y 5.9 (neighbours 2.7)
tex_stone_spike installed: seam x 5.1 (neighbours 4.5)  y 5.2 (neighbours 5.1)
[… 7 hash lines of the surfaces trimmed; they are the manifest's …]
```
Tests and checks (the runs' summary lines):
```
gdformat --check src scripts tests      961 files would be left unchanged
gdlint src scripts tests                Success: no problems found
tests/content                           Scripts 26  Tests 132  Passing Tests 132  Asserts 9284  (35.206 s)
tests/unit/presentation                 Scripts 101 Tests 701  Passing Tests 701  Asserts 1941088  (547.594 s)
e2e (the 11 files above)                Scripts 11  Tests 17   Passing Tests 17   Asserts 813  (224.513 s)
```
PF probe (the Gun's Spread + Split + Explosive build; it draws no boss, so it checks the shared VfxCore pools and budget
are unchanged by the new pools, not the boss looks themselves):
```
metric          avg       p95       max
sim_ms            1.504     3.861     9.847
sync_ms           3.079     6.177     8.462
frame_ms          2.896     5.724    10.163
total_ms          7.479    14.403    21.488
bursts_asked     17.993    24.000    25.000
bursts_drawn     12.938    16.000    16.000
sprites_asked   411.363   564.000   601.000
sprites_drawn   411.363   564.000   601.000
lights_on         9.807    10.000    10.000
decals           10.465    11.000    11.000
[… other rows trimmed …]
verdict: avg 7.48 ms per tick+frame against 12.0 ms -> within
```
(the container was shared with two other agents' renders; load average 5.6 when it started)

## Shots (`tx_shots/tx2_*.jpg`, before on the left, after on the right)
`gatekeeper_crater`, `gatekeeper_lanes_cracks`, `gatekeeper_spikes`, `colossus_leap_shockwave`, `brood_acid_marker`,
`brood_acid_splat`, `brood_burrow_eruption`, `hive_light_marker`, `hive_lens_flare_ring`, `siege_hazard_marker`,
`siege_shockwave` (unchanged on purpose: wider than 6 m), `foundry_molten_marker`, `foundry_molten_pouring`,
`foundry_molten_cooling`, `foundry_vent_steam`, `foundry_lava_floor`, `warden_slam_dust`.
The after shots of the crater, the burrow, the shockwave, the vent and the spikes were rendered on the final code; the
others an hour earlier, before the crater cracks were brightened and the dust ring was limited to 6 m (neither is in
those shots' looks). Not shot: the lunge skid (`attack_visuals_2.gd -- from=5 to=5` saved no frame in the `ab51a15` tree and a frame with
no skid visible in this one; not looked into further), the crystal shatter (the final-boss shot is
taken while the body gathers, before it bursts), the steel marker (no Warlord locked-marker shot in the scripts).

## Misfits and notes
- `fx_ground_cracks` and `fx_dust_ring` came painted on brown ground, not on black: keyed out by colour (shown fine in
  the shots); `fx_dust_ring` is 1287×1222 (resized to a square).
- `fx_steam_puffs` and `fx_crystal_shatter` came as 1536×1024 with the four variants in a 2×2 layout: re-gridded.
- None of the six surfaces tiled at the source (the seam rows above); `tex_mark_hazard` worst (the stripes did not line
  up). All fixed in preparation, no redo needed.
- The Warden's slam dust ring now reads fainter on the pale Playground sand than the old near-white band
  (`warden_slam_dust`): the owner's dust is beige. Asked as D41.
- The Siege Engine's room-wide shockwave keeps the code band (see above).

## Interpretation
The fifteen textures are installed, listed with their hashes and credited; each named code look draws the owner's
texture where it fits, the code look stays as the fallback, the telegraph colours and the lock flash are unchanged, and
the tests named above pass. It proves nothing about the GPU cost on the owner's machine or how the looks feel in play
(OWNER ONLY).
