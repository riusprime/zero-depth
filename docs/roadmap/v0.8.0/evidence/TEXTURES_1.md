# TEXTURES_1: the owner's orb, trail, beam, aim-line and sigil textures (v0.8.0 Step TX1)

The request: [`docs/art/requests/v0.8.0_textures.md`](../../../art/requests/v0.8.0_textures.md), part A (owner
2026-10-15: "itd be better looking if we created real textures like with the player animations"). TX1 installs the
eight attack textures the owner delivered on 2026-10-16 in place of the code-made looks named in that file.

- **Status:** RUN (agent; headless tests and the CPU probe in the container; shots on software Vulkan, llvmpipe, under
  xvfb). How it looks and feels on the owner's PC: **OWNER ONLY**.
- **Build:** `ab51a15` on `claude/lucid-fermat-9wv2tf` plus the TX1 working tree, committed as
  `v0.8.0 Step TX1: …` on branch `v080-tx1` (every command below ran on that tree before the commit; only these docs
  were written after).
- `fx_rail_streak` was not delivered: the Siege Engine's rail keeps its code look (its strike tubes are drawn as
  before; a test-visible marker keeps it apart from the Focus Beam, below).

## What each texture replaced

| texture | file (installed) | replaced (code) | drawn on | tint |
|---|---|---|---|---|
| `fx_orb_cores` (2×2: ember rock, acid glob, magenta crystal, molten drop) | 512² LA | the noise swirl inside the hostile fireballs (`FireballShaders.CORE`) | Gatekeeper `ember_stone` (and the Colossus's boulder shards, which use the same look), Brood Mother `acid_glob`, Hive Lens `prism_orb`, Foundry `molten_drop` | each look's own core, edge and body colours |
| `fx_orb_cores_2` (spear ember, cannon ember, plasma, violet fireball) | 512² LA | the same | Warlord `spear_ember`, Siege Engine `cannon_ember`, Arc Caster `arc_plasma`, Bomb Drone `bomb_cinder` | the same |
| `fx_orb_cores_final` (stone shard, rose crystal orb, rose crystal bolt, void orb) | 512² LA | the final boss's shots | the Prism's `crown_orb` and `crown_bolt`, the Nemesis's `nemesis_bolt` and `nemesis_crescent` | the same |
| `fx_trails` (1×4: flame, smoke, acid drips, crystal) | 1024² LA | the noise and drip ribbons behind every hostile fireball (`FireballShaders.TRAIL`) | every look: smoke for the Siege Engine, drips for the acid and molten looks, crystal for the gems and the Prism's bolts, flame for the rest | the look's trail and head colours |
| `fx_beam` (1×4) | 1024² LA | the beams' scrolling noise (`BossSignatureShaders.BEAM`, `BossStrikeMeshes.GLOW`) | the Hive Lens's Gaze and Focus Beam, the Prism's Cross | the Gaze magenta, the Cross red, the Focus Beam's strike glow |
| `fx_beam_impact` (2×2) | 1024² LA | the plain glowing sphere where a beam hits a wall | the Gaze, each Cross arm | the beam's colour to its white core |
| `fx_aim_lines` (1×4: dashed, laser with an end point, chevrons, shimmer) | 512² LA | the plain glowing aim cylinders | the Gaze's windup (dashed), the Cross's spin-up (chevrons running outward), the Prism's bolt line (the laser, its end point at the target) | the same colours as before |
| `fx_cast_sigils` (2×2, from a 1536×1024 upload) | 1024² LA | the Nemesis's plain glowing cast disc; the Arc Caster's code rune (an inner ring and turning spokes) | the Nemesis's card casts (cell 0), the Arc Caster's rune (cell 3) | the Nemesis violet; the hostile telegraph colour |

How the uploads were turned into game textures (`scripts/assets/vfx_prep_attacks.py`, new; the earlier installs'
`vfx_prep.py` is untouched): these uploads came with an alpha channel already (a transparent background, its colour
left as junk), so each is first laid on black, then saved as a **greyscale mask** (an LA PNG): for the glows (beams,
impacts, aim lines, sigils, trails) A = the brightest channel (brightness becomes coverage, as `vfx_prep.py`'s glow
kind) and L = the whiteness (darkest channel over brightest); for the orb cores A = the upload's own alpha and L = the
lightness. The game draws `mix(tint, hot, L) × A` with the colours the code already gives each boss, enemy and look,
so palette A and the enemy colours are unchanged; the painted colours themselves are not used. 2×2 sheets are cut in
quarters, each variant trimmed and centred in its cell (as `vfx_prep.regrid`); 1×4 strips are cut into their four bands
and each band stretched to fill a row at full width (a beam's seamless ends stay seamless).

How they are drawn (`src/presentation/world_view/fx_textures.gd`, new, plus the shaders named above): a **uniform swap**
on meshes that already drew. The fireball cores and trails stay three MultiMeshes per look; the orb painting is
projected onto the 3D body from three sides and turns with it (a spear-shaped painting turned to point along the
flight). The beams and aim lines stay the same cylinders; the strip is laid across each cylinder as the camera sees it
and tiled along it. The Focus Beam stays in the strike pool's one MultiMesh (its tubes carry `r = 4 + alpha` in their
custom data; the rail's stay `2 + alpha`, drawn as before). The impact flare is the same node with a camera-facing quad
in place of its sphere; the Nemesis sigil the same node with a floor quad in place of its disc. The Arc Caster's rune
adds a floor quad to its telegraph node and leaves the node's deco mesh empty, so its draws stay the same. When a
texture is not installed `FxTextures.get_tex` returns null and every user keeps the code look (a test points it at an
empty folder).

## Commands and raw output

Prep (from the repo root):
```
$ python3 -I scripts/assets/vfx_prep_attacks.py
feca4e1d6563a04f03ff417ed39f32b4b50c33d08bdc9af482c8ca41aee0251c    173148  assets/textures/vfx/fx_orb_cores.png
ea32f5632e5849b00129a87e2b63b0489b1e42472c624f085c57a7959a610e9f    192882  assets/textures/vfx/fx_orb_cores_2.png
6db8cac60f2c8b2101c2ece5c5fcdd4056649609d5ffeccb25e1b5b25fd02549    154135  assets/textures/vfx/fx_orb_cores_final.png
135f06cb7c171b750f7223724aeaa003588a4bffad220a2b307a5d60a8aef367    599446  assets/textures/vfx/fx_trails.png
83bb2028c6f02a4606ccaa813295ef710ef630473ff6ce8748b8bafbf4b94a0e    728249  assets/textures/vfx/fx_beam.png
05be95058c0c435d049d6117336dcff42657294091f78f1f65c22460ffc7772c    578201  assets/textures/vfx/fx_beam_impact.png
b02bf60a35943b9cff99560589e7076e2f46339116cd17604ade0347c7494be0    182950  assets/textures/vfx/fx_aim_lines.png
150a9fd8cbebd2c23037ad34d8d9a9b27859424171b5d691684d00f7da83cd75    654487  assets/textures/vfx/fx_cast_sigils.png
```
The eight are listed with these hashes in `assets/models/manifest.json` ("textures"); their `.import` files use the
earlier VFX textures' settings (VRAM compressed, mipmaps). Then `godot --headless --path . --editor --import --quit`.

Lint:
```
$ gdformat --check src scripts tests
964 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
```

Tests (the touched presentation files, the new `test_fx_textures.gd`, the asset test, the arch tests and the e2e that
draw these effects; no full suite, no bot tests):
```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/unit/presentation/test_fx_textures.gd,…/test_enemy_fireball_views.gd,…/test_boss_signature_views.gd,…/test_boss_signature_views_2.gd,…/test_prism_views.gd,…/test_nemesis_views.gd,…/test_final_boss_views.gd,…/test_telegraph_parity.gd,…/test_boss_telegraph_parity.gd,…/test_melee_strikes.gd,…/test_attack_visuals.gd,…/test_attack_visuals_2.gd,…/test_vfx_budget.gd,…/test_vfx_layer.gd,…/test_new_enemy_avatars.gd,…/test_boss_fight_views.gd,…/test_boss_fight_views_3.gd,…/test_boss_fights_2_views.gd,…/test_boss_views.gd,…/test_bosses_2_views.gd,res://tests/content/test_model_manifest.gd
Totals
Scripts              21
Tests               168
Passing Tests       168
Asserts           39079
Time              409.23s

$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=res://tests/arch/test_layering.gd,res://tests/arch/test_sim_purity.gd,res://tests/e2e/test_e2e_boss_strikes.gd,…/test_e2e_boss_signatures.gd,…/test_e2e_boss_signatures_2.gd,…/test_e2e_enemy_fireballs.gd,…/test_e2e_prism.gd,…/test_e2e_nemesis.gd,…/test_e2e_final_boss.gd,…/test_e2e_damage_soak.gd,…/test_e2e_boss_dodge.gd,…/test_e2e_boss_dodge_2.gd,…/test_e2e_boss_dodge_3.gd,…/test_e2e_new_enemies.gd,…/test_e2e_attacks.gd
Totals
Scripts              15
Tests                25
Passing Tests        25
Asserts           12330
Time              382.898s
```
(`…` is `res://tests/unit/presentation` and `res://tests/e2e`; the runs wrote `build/tx1_unit.txt` and
`build/tx1_e2e.txt`, deleted after.)

## PF probe (no frame regression)

`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10`, the base (`ab51a15`'s
`src/`) and TX1 alternately, twice each, on the same tree (the probe is the Gun's level-5 Spread + Split + Explosive
build on the Playground: it draws no boss shots, so it checks the shared layers, not the swapped effects; those are
drawn on the same MultiMeshes and nodes as before, which the tests above pin). The container was shared with two
other agents rendering and testing, so the timings swing between runs; the counts are identical:

```
== base (ab51a15 src) run 1
sim_ms            3.110    10.078    37.627
sync_ms           8.837    15.927   409.171
frame_ms          6.317    12.042   109.820
total_ms         18.264    37.507   415.687
sprites_drawn   411.363   564.000   601.000
lights_on         9.807    10.000    10.000
verdict: avg 18.26 ms per tick+frame against 12.0 ms -> OVER
== TX1 run 1
sim_ms            3.207     9.237    68.862
sync_ms           6.382    15.381    85.597
frame_ms          5.784    11.906   356.582
total_ms         15.374    32.893   365.561
sprites_drawn   411.363   564.000   601.000
lights_on         9.807    10.000    10.000
  TelegraphViews              0.021
verdict: avg 15.37 ms per tick+frame against 12.0 ms -> OVER
== base (ab51a15 src) run 2
sim_ms            4.267     8.270   937.978
sync_ms           5.593    12.387    84.417
frame_ms          5.126    11.626    30.042
total_ms         14.986    29.210   959.992
sprites_drawn   411.363   564.000   601.000
lights_on         9.807    10.000    10.000
  TelegraphViews              0.017
verdict: avg 14.99 ms per tick+frame against 12.0 ms -> OVER
== TX1 run 2
sim_ms            1.960     5.997    27.514
sync_ms           4.086     9.089   116.755
frame_ms          3.688     7.897    37.094
total_ms          9.734    20.999   123.936
sprites_drawn   411.363   564.000   601.000
lights_on         9.807    10.000    10.000
  TelegraphViews              0.007
verdict: avg 9.73 ms per tick+frame against 12.0 ms -> within
```
(the rows kept: the timings, the draw counts and the frame cost of the nodes TX1 touched that the probe draws.) TX1
is not slower than its base on either pair. The base itself goes OVER on three of the four runs on this loaded
machine. PERF.md's own after numbers (8.961 ms average) were measured on an idle container, so these runs are not
comparable with them.

## Shots (before | after)

`docs/roadmap/v0.8.0/evidence/tx_shots/tx1_*.jpg`: each has the code look on top and the owner's texture underneath,
from the same tick and camera. Renders:
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 -s <script> [-- <n>]`
with `scripts/shots/tx1_attacks.gd` (new: the six bosses' orbs and trails, the Focus Beam), `boss_signatures_2.gd -- 7`
and `-- 8` (the Gaze), `final_boss_2.gd -- 2`, `-- 3`, `-- 5` (the Cross, its spin-up, the bolt line),
`final_boss_3.gd -- 3` (the Nemesis's cast) and `enemy_fireballs.gd` (the Arc Caster's plasma, the Bomb Drone's
cinders). The "before" frames ran on `ab51a15`'s `src/`. The "after" frames of tx1_1–tx1_7 and tx1_13 ran on the
committed code. tx1_8–tx1_12, tx1_14 and tx1_15 ran during tuning, after the beam fix (the strip laid across the full
beam) and before two later constant changes: the cracked fireballs' glow floor (0.35) and the sigil's brightness (×2.4,
was ×1.8). The Gaze's and the Cross's beams, aim lines and impacts in them are as committed. One full `tx1_attacks.gd`
run was killed by the container's memory limit after its third shot (`exit 137`), so shots 4–7 were rendered one at a
time (`-- <n>`).

| shot | shows |
|---|---|
| tx1_1 … tx1_6 | Gatekeeper ember stones, Brood acid globs, Hive prism orbs, Warlord spear embers, Siege cannon embers (smoke trail), Foundry molten drops |
| tx1_7 | the Focus Beam (three lanes) |
| tx1_8, tx1_9 | the Gaze: its dashed aim line; its beam and the impact flare at the wall |
| tx1_10, tx1_11, tx1_12 | the Cross: chevron aim lines, the beams and their impact flares, the bolt's laser line |
| tx1_13 | the Nemesis's cast sigil |
| tx1_14, tx1_15 | the Arc Caster's plasma, the Bomb Drone's cinders |

The Arc Caster's rune has no shot (none of the shot scripts stages it); `test_fx_textures.gd` checks that it draws the
sigil in place of the code ring and spokes.

## What didn't fit, and what to look at

- **The orbs are small on screen** (about 20–30 px at the game's camera), so most of each painting is lost to the
  texture's smaller mip levels: at that size the swap reads as a change of grain and glow, not as the painting. The
  Gatekeeper's ember rock is darker than the code's bright ember (the painting is dark plates with glowing cracks); I
  raised the glow floor of the cracked looks so the core still reads bright. Whether the orbs still read as "bright core,
  dark edge" at play speed: **OWNER ONLY**.
- **Tinted, not painted colours:** every texture is drawn as a greyscale mask in the code's colours, so the owner's
  hues (the blue, orange, green and purple beam rows, the coloured impacts) are not seen; their shapes are.
- **Aim lines:** the thin lines were stretched to fill their rows (the shader maps the row's height to the line's
  thickness). Dashes and chevrons read; the laser's end point becomes a short bright tip. The shimmer row (row 3) is
  installed but not used.
- **The stone-shard cell** of `fx_orb_cores_final` is installed but not used: the Colossus's boulder shards use the
  Gatekeeper's `ember_stone` look (in their bullet-pattern data), so they draw the ember rock. Giving them their own look
  is a data change outside TX1.
- **Not swapped:** the Lens Drone's orbs (`lens_orb`, not in the request) and DEFAULT_LOOK keep the code noise; the
  Sniper has no aim line any more (v0.8.0 TG took its ground line away; its muzzle glow is a gem), and the Nemesis's
  card volleys draw their lines as boss markers (TX2's ground textures), so neither has a line to texture.
- `fx_orb_cores_2` arrived at 500 px (the request asked for 1024); at the shots' size it doesn't show, so it is
  installed at 512 px like the other orb sheets.
