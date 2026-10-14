# ENEMY_COLOURS: the G2 sheet for enemy colours by role, palettes A / B / C (v0.8.0 Step EC)

- **Status:** RUN (tests, contrast numbers, renders). **Owner pick: OWNER ONLY (pending).** The game still ships
  today's red and grey (`EnemyPalettes.active = &"current"`).
- **Build:** the working tree of `v080-ec` (base `deb87b4` on `claude/lucid-fermat-9wv2tf`) with this step's changes,
  before its commit (the Step EC commit is that tree plus this file, the shots and the PROGRESS rows); Godot
  `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`; renders on llvmpipe (Mesa's software Vulkan,
  LLVM 20.1.2) under xvfb, in a cloud container. A real GPU may light them a little differently.
- **Date:** 2026-10-14
- **Who ran it:** agent

Owner O2 (verbatim in [`../PLAN.md`](../PLAN.md)): "the enemies are all red … differentiates the different enemies,
not only by what they do, but also color". Q1 answer (2026-10-14): "By role (Recommended)": melee rushers red / orange
(Charger, Hatchling, Swarmer, Splitter, Splitling), ranged casters blue / violet (Needle, Arc Caster, Sniper, Lens
Drone), bombers and mines yellow (Bomb Drone, Mine Layer), support green (Mender), tanks bronze (Warden, Shield
Bearer); every hostile keeps a glowing eye and the enemy outline.

## What was built (presentation only)
- **One table:** `src/presentation/world_view/enemy_palettes.gd` (`EnemyPalettes`). Four palettes (`current`, `a`,
  `b`, `c`) x 14 kinds x four slots: **body** (the main plate: hood, shell, cube, robe, hull, helm), **trim** (the
  second plate: the Charger's back flap, the Warden's visor frame, the Needle's pods, a hem, a cap or dome, the
  Splitter's right half, the Shield Bearer's shield bands, the Sniper's scope housing), **grey** (limbs and frame)
  and **eye** (the glowing eye, slit or visor). The pick is one line: `static var active := CURRENT` becomes the
  picked key.
- **The avatars read it** when they build (ChargerAvatar, now told its kind so the Hatchling has its own colours;
  WardenAvatar, NeedleAvatar, ArcCasterAvatar, BombDroneAvatar, LensDroneAvatar, HordeAvatar). Their old colour
  constants are gone; the neutral parts (faces, joints, bone, dark chassis, the bomb) keep theirs.
- **`current` is today's look exactly** (the old constants, value for value), so nothing changes in game until the
  owner picks. Keeping red as the default needed no special case.
- **Every hostile shows an eye in A / B / C:** the Splitter / Splitling (whose glow is its seam, the telegraph colour)
  and the Mender (whose glow is the heal crystal, `#7CF29A`) get a small eye slit in the palette's eye colour
  (`"eyes_on_all"`); `current` leaves them as today.
- **Unchanged:** the outline, the team ring, the red HP bar, the X-ray twin (all `ThemePalette`, so a colour-blind
  mode still recolours them); the Splitter's seam (`telegraph_hostile`), the Mender's crystal and beam (heal green),
  the Arc Caster's crystal (`proj_hostile`), the Warden's back cracks; the bosses; the elites' crown.
- **Biome cast:** `ActorViews.tint_greys` only touches materials under `GREY_SATURATION` (0.3). Every role colour is
  at or above it (tested), so a biome casts on the greys only, as before; C's grey bodies take the cast.

## The three candidates (one line each, for the pick)
- **A, saturated role colours:** the clearest read of the five families at a glance, in both biomes; the darkest
  shades (Sniper, Arc Caster, Shield Bearer) still go dark under Ruins' evening light, and it is the loudest next to
  the kit's worn stone.
- **B, muted and weathered:** sits best with the kit's worn look, but in Ruins' warm light most kinds read as dark
  brown and the families only separate up close (ranged blue-grey and bomber olive hold; melee, tank and support
  blur).
- **C, grey bodies with role trims and glowing eyes:** the most uniform, "one army" look and the hostile read rests on
  the eyes; the role shows only on the trim and eye, small at game zoom (clear on the Splitter, Bomb Drone, Mine
  Layer, Arc Caster's shards; faint on the Charger, Hatchling, Warden, Shield Bearer).

## Hex tables
Slots as above. Eye `#FF2A22` is today's hostile red.

### current (shipped default)
| Kind | Role | body | trim | grey | eye |
|---|---|---|---|---|---|
| Charger | melee | `#D8433A` | `#C63B34` | `#6E605D` | `#FF2A22` |
| Hatchling | melee | `#D8433A` | `#C63B34` | `#6E605D` | `#FF2A22` |
| Swarmer | melee | `#D8433A` | `#5F5551` | `#5F5551` | `#FF2A22` |
| Splitter | melee | `#D8433A` | `#A9302B` | `#5F5551` | `#FF2A22` |
| Splitling | melee | `#D8433A` | `#A9302B` | `#5F5551` | `#FF2A22` |
| Needle | ranged | `#E03C30` | `#5F5551` | `#5F5551` | `#FF2A22` |
| Arc Caster | ranged | `#D8433A` | `#A9302B` | `#5F5551` | `#FF2A22` |
| Sniper | ranged | `#D8433A` | `#24272D` | `#5F5551` | `#FF2A22` |
| Lens Drone | ranged | `#D8433A` | `#5F5551` | `#5F5551` | `#FF2A22` |
| Bomb Drone | bomber | `#D8433A` | `#5F5551` | `#5F5551` | `#FF2A22` |
| Mine Layer | bomber | `#D8433A` | `#5F5551` | `#5F5551` | `#FF2A22` |
| Mender | support | `#D8433A` | `#5F5551` | `#5F5551` | `#FF2A22` |
| Warden | tank | `#DA4036` | `#2E2B2E` | `#6E5B53` | `#FC2824` |
| Shield Bearer | tank | `#D8433A` | `#D8433A` | `#5F5551` | `#FF2A22` |

### A: saturated role colours
| Kind | Role | body | trim | grey | eye |
|---|---|---|---|---|---|
| Charger | melee | `#D8433A` | `#A8302A` | `#6E605D` | `#FF2A22` |
| Hatchling | melee | `#C93A1E` | `#9A2C16` | `#6E605D` | `#FF2A22` |
| Swarmer | melee | `#B82A48` | `#8A1E36` | `#5F5551` | `#FF2A22` |
| Splitter | melee | `#D8682A` | `#A84E1E` | `#5F5551` | `#FF2A22` |
| Splitling | melee | `#EE8E62` | `#C06C46` | `#5F5551` | `#FF2A22` |
| Needle | ranged | `#3A6BD4` | `#2A50A0` | `#5F5551` | `#FF2A22` |
| Arc Caster | ranged | `#8A50D8` | `#6A3CA8` | `#5F5551` | `#FF2A22` |
| Sniper | ranged | `#3A55C0` | `#2C4092` | `#5F5551` | `#FF2A22` |
| Lens Drone | ranged | `#A855C8` | `#7E3E96` | `#5F5551` | `#FF2A22` |
| Bomb Drone | bomber | `#E8C22E` | `#B09222` | `#5F5551` | `#FF2A22` |
| Mine Layer | bomber | `#C29A14` | `#92740E` | `#5F5551` | `#FF2A22` |
| Mender | support | `#44A856` | `#337E40` | `#5F5551` | `#FF2A22` |
| Warden | tank | `#9A6232` | `#744A26` | `#6E5B53` | `#FF2A22` |
| Shield Bearer | tank | `#80592E` | `#A87A48` | `#5F5551` | `#FF2A22` |

### B: muted, weathered role colours on the plates
| Kind | Role | body | trim | grey | eye |
|---|---|---|---|---|---|
| Charger | melee | `#9E4A40` | `#7A3A32` | `#6E605D` | `#FF2A22` |
| Hatchling | melee | `#8E3E2E` | `#6E3024` | `#6E605D` | `#FF2A22` |
| Swarmer | melee | `#8A3A4A` | `#6C2C3A` | `#5F5551` | `#FF2A22` |
| Splitter | melee | `#A0603A` | `#7C4A2C` | `#5F5551` | `#FF2A22` |
| Splitling | melee | `#B47E62` | `#8C624C` | `#5F5551` | `#FF2A22` |
| Needle | ranged | `#4E6898` | `#3C5076` | `#5F5551` | `#FF2A22` |
| Arc Caster | ranged | `#6A5294` | `#523F72` | `#5F5551` | `#FF2A22` |
| Sniper | ranged | `#44528A` | `#343F6A` | `#5F5551` | `#FF2A22` |
| Lens Drone | ranged | `#86609A` | `#684A78` | `#5F5551` | `#FF2A22` |
| Bomb Drone | bomber | `#B4A048` | `#8C7C38` | `#5F5551` | `#FF2A22` |
| Mine Layer | bomber | `#94803A` | `#72622C` | `#5F5551` | `#FF2A22` |
| Mender | support | `#4E8056` | `#3C6242` | `#5F5551` | `#FF2A22` |
| Warden | tank | `#7C5E40` | `#5E4832` | `#6E5B53` | `#FF2A22` |
| Shield Bearer | tank | `#6E5A44` | `#8C7458` | `#5F5551` | `#FF2A22` |

### C: grey bodies, role colour on trims and glow
| Kind | Role | body | trim | grey | eye |
|---|---|---|---|---|---|
| Charger | melee | `#6B6360` | `#D8433A` | `#6E605D` | `#FF2A22` |
| Hatchling | melee | `#6B6360` | `#C93A1E` | `#6E605D` | `#FF3A3A` |
| Swarmer | melee | `#6B6360` | `#B82A48` | `#5F5551` | `#FF2058` |
| Splitter | melee | `#6B6360` | `#D8682A` | `#5F5551` | `#FF7A1A` |
| Splitling | melee | `#6B6360` | `#EE8E62` | `#5F5551` | `#FFA070` |
| Needle | ranged | `#6B6360` | `#3A6BD4` | `#5F5551` | `#3E7BFF` |
| Arc Caster | ranged | `#6B6360` | `#8A50D8` | `#5F5551` | `#A060FF` |
| Sniper | ranged | `#6B6360` | `#3A55C0` | `#5F5551` | `#5A62FF` |
| Lens Drone | ranged | `#6B6360` | `#A855C8` | `#5F5551` | `#E070FF` |
| Bomb Drone | bomber | `#6B6360` | `#E8C22E` | `#5F5551` | `#FFE03A` |
| Mine Layer | bomber | `#6B6360` | `#C29A14` | `#5F5551` | `#E8B000` |
| Mender | support | `#6B6360` | `#44A856` | `#5F5551` | `#2EE05A` |
| Warden | tank | `#6B6360` | `#9A6232` | `#6E5B53` | `#C88A4A` |
| Shield Bearer | tank | `#6B6360` | `#A87A48` | `#5F5551` | `#A87040` |

## The shots
`scripts/shots/mock_enemy_colours.gd`: the 14 kinds in a 7 x 2 grid (top: the four ranged, the two bombers and the
Mender, so the drones float into the empty space; bottom: the five melee and the two tanks), each held on its spot
in a real `World` (an empty 19 m room) drawn by the game's `WorldViewRoot` with the biome's mood, stage and look and
the fixed iso camera (view size 8.8 m, tighter than play so the colours show); the hero stands below the middle, so
the kinds face the camera and its warm light reaches them as in play. Labels (kind and role, English) are drawn by
the script. 1920 x 1080.

Copied into [`ec_shots/`](ec_shots/) (from `build/shots/v0.8.0/ec/`):

| Palette | Ruins | Frozen Shore (the biome's cold cast on greys) |
|---|---|---|
| today (reference) | [current_ruins_off.png](ec_shots/current_ruins_off.png) | — (in `build/` only) |
| A | [a_ruins_off.png](ec_shots/a_ruins_off.png) | [a_frozen_shore_off.png](ec_shots/a_frozen_shore_off.png) |
| B | [b_ruins_off.png](ec_shots/b_ruins_off.png) | [b_frozen_shore_off.png](ec_shots/b_frozen_shore_off.png) |
| C | [c_ruins_off.png](ec_shots/c_ruins_off.png) | [c_frozen_shore_off.png](ec_shots/c_frozen_shore_off.png) |

What the renders show (agent's reading; the call is the owner's): see the trade-off lines above. Ruins' evening light
is dark away from the hero, so every palette's darkest shades lose their hue there; Frozen Shore's blue grade pulls
everything cooler, and A's families still separate in it.

### Commands and raw output
```
$ XDG_DATA_HOME=<empty scratch dir> VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 900 \
  xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 \
  -s scripts/shots/mock_enemy_colours.gd -- palettes=current,a,b,c biomes=ruins,frozen_shore modes=off
Terminated
exit=124
```
That run hit its 15-minute `timeout` (the container was shared, load average 9 on 4 cores) after writing
`current_ruins_off.png`, `current_frozen_shore_off.png` and `a_ruins_off.png`; its printed lines were lost in the
grep buffer when it was killed. The rest were rendered by these runs (same environment):
```
$ ... -s scripts/shots/mock_enemy_colours.gd -- palettes=a biomes=frozen_shore modes=off
mock_enemy_colours: res://build/shots/v0.8.0/ec/a_frozen_shore_off.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
$ ... -s scripts/shots/mock_enemy_colours.gd -- palettes=b,c biomes=ruins,frozen_shore modes=off
mock_enemy_colours: res://build/shots/v0.8.0/ec/b_ruins_off.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
mock_enemy_colours: res://build/shots/v0.8.0/ec/b_frozen_shore_off.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
mock_enemy_colours: res://build/shots/v0.8.0/ec/c_ruins_off.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
mock_enemy_colours: res://build/shots/v0.8.0/ec/c_frozen_shore_off.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
```

## Colour-blind check
Two parts, both run.

**1. Numbers** (`scripts/checks/enemy_palette_contrast.gd`, the same simulation and ΔE as
`tests/unit/presentation/test_colour_modes.gd`; identity colour = body, or C's trim):
```
$ godot --headless --path . -s scripts/checks/enemy_palette_contrast.gd
== palette current (identity slot: body)
  normal       closest in a role   0.0 (charger/hatchling); across roles   0.0 (charger/arc_caster)
  protanopia   closest in a role   0.0 (charger/hatchling); across roles   0.0 (charger/arc_caster)
  deuteranopia closest in a role   0.0 (charger/hatchling); across roles   0.0 (charger/arc_caster)
  tritanopia   closest in a role   0.0 (charger/hatchling); across roles   0.0 (charger/arc_caster)
  nearest reserved colour: 11.0 (charger eye vs heat_overclock)
  vs ruins ground cbad91: luminance contrast 2.04:1 (needle) .. 2.08:1
  vs frozen_shore ground d1dae4: luminance contrast 3.06:1 (needle) .. 3.12:1
== palette a (identity slot: body)
  normal       closest in a role  10.0 (needle/sniper); across roles  26.0 (splitling/warden)
  protanopia   closest in a role   4.9 (needle/lens_drone); across roles   4.8 (charger/shield_bearer)
  deuteranopia closest in a role   2.8 (needle/arc_caster); across roles   8.2 (swarmer/shield_bearer)
  tritanopia   closest in a role   5.5 (charger/hatchling); across roles  19.9 (mine_layer/warden)
  nearest reserved colour: 11.0 (charger eye vs heat_overclock)
  vs ruins ground cbad91: luminance contrast 1.14:1 (splitling) .. 3.06:1
  vs frozen_shore ground d1dae4: luminance contrast 1.22:1 (bomb_drone) .. 4.59:1
== palette b (identity slot: body)
  normal       closest in a role   6.6 (charger/hatchling); across roles  18.1 (splitling/warden)
  protanopia   closest in a role   0.8 (needle/lens_drone); across roles   1.3 (charger/shield_bearer)
  deuteranopia closest in a role   3.4 (needle/arc_caster); across roles   3.5 (charger/warden)
  tritanopia   closest in a role   5.3 (hatchling/swarmer); across roles  10.5 (needle/mender)
  nearest reserved colour: 11.0 (charger eye vs heat_overclock)
  vs ruins ground cbad91: luminance contrast 1.23:1 (bomb_drone) .. 3.56:1
  vs frozen_shore ground d1dae4: luminance contrast 1.84:1 (bomb_drone) .. 5.34:1
== palette c (identity slot: trim)
  normal       closest in a role  10.0 (needle/sniper); across roles  24.7 (splitling/shield_bearer)
  protanopia   closest in a role   4.9 (needle/lens_drone); across roles   6.7 (hatchling/warden)
  deuteranopia closest in a role   2.8 (needle/arc_caster); across roles   6.4 (mender/shield_bearer)
  tritanopia   closest in a role   5.5 (charger/hatchling); across roles  11.0 (mine_layer/shield_bearer)
  nearest reserved colour: 11.0 (charger eye vs heat_overclock)
  vs ruins ground cbad91: luminance contrast 1.14:1 (splitling) .. 3.06:1
  vs frozen_shore ground d1dae4: luminance contrast 1.22:1 (bomb_drone) .. 4.59:1
```
Reading: under normal vision A and C keep kinds inside a role at least ΔE 10 apart and roles at least 24.7 apart
(B: 6.6 / 18.1). Under protanopia and deuteranopia the five families **collapse to two** (blue / violet vs everything
else: red, orange, yellow, green and bronze all become olive-yellow), closest across roles ΔE 4.8-8.2 for A, 1.3-3.5
for B, 6.4-6.7 for C. That is the role scheme itself (red / yellow / green / bronze), not one palette's tuning. Under
tritanopia A holds best (19.9 across roles). In every palette the identity colours sit at 1.14-3.56:1 luminance
against the Ruins ground (today's red: 2.04-2.08:1), so as PRESENTATION §3 already says, hostile identity rests on the
team ring, outline and bar (unchanged, and recoloured by the colour-blind modes), and the kind on its silhouette.

**2. Renders with the mode on, then simulated:** the views built with `ThemePalette.mode` set (rings and X-ray amber
in deuteranopia / protanopia, red in tritanopia), then `scripts/shots/cvd_sim.py` applies the deficiency to the
image (written under `build/` only). The renders:
```
$ ... -s scripts/shots/mock_enemy_colours.gd -- palettes=current,a,b,c biomes=ruins modes=deuteranopia,tritanopia
mock_enemy_colours: res://build/shots/v0.8.0/ec/current_ruins_deuteranopia.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
mock_enemy_colours: res://build/shots/v0.8.0/ec/current_ruins_tritanopia.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
mock_enemy_colours: res://build/shots/v0.8.0/ec/a_ruins_deuteranopia.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
mock_enemy_colours: res://build/shots/v0.8.0/ec/a_ruins_tritanopia.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
mock_enemy_colours: res://build/shots/v0.8.0/ec/b_ruins_deuteranopia.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
$ ... -s scripts/shots/mock_enemy_colours.gd -- palettes=b biomes=ruins modes=tritanopia
mock_enemy_colours: res://build/shots/v0.8.0/ec/b_ruins_tritanopia.png (ticks=61 risen=true projectiles=0 size=(1920, 1080))
rc=0
$ ... -s scripts/shots/mock_enemy_colours.gd -- palettes=c biomes=ruins modes=deuteranopia,tritanopia
Killed
rc=137
$ ... -- palettes=c biomes=ruins modes=deuteranopia      (retry, one shot)
Killed
rc=137
$ ... -- palettes=c biomes=ruins modes=tritanopia        (retry, one shot)
Killed
rc=5
```
The first of these runs ended after `b_ruins_deuteranopia.png` with no further line past the grep filter; the C
colour-blind renders were killed by the container (`Killed`, exit 137 / 5, while other sessions shared the
machine). **C rendered with a colour-blind mode on: NOT YET RUN** (its numbers above are run). The simulation:
```
$ python3 scripts/shots/cvd_sim.py deuteranopia build/shots/v0.8.0/ec/*_ruins_deuteranopia.png
$ python3 scripts/shots/cvd_sim.py protanopia build/shots/v0.8.0/ec/*_ruins_deuteranopia.png
$ python3 scripts/shots/cvd_sim.py tritanopia build/shots/v0.8.0/ec/*_ruins_tritanopia.png
cvd_sim: build/shots/v0.8.0/ec/a_ruins_deuteranopia_sim_deuteranopia.png
cvd_sim: build/shots/v0.8.0/ec/b_ruins_deuteranopia_sim_deuteranopia.png
cvd_sim: build/shots/v0.8.0/ec/current_ruins_deuteranopia_sim_deuteranopia.png
cvd_sim: build/shots/v0.8.0/ec/a_ruins_deuteranopia_sim_protanopia.png
cvd_sim: build/shots/v0.8.0/ec/b_ruins_deuteranopia_sim_protanopia.png
cvd_sim: build/shots/v0.8.0/ec/current_ruins_deuteranopia_sim_protanopia.png
cvd_sim: build/shots/v0.8.0/ec/a_ruins_tritanopia_sim_tritanopia.png
cvd_sim: build/shots/v0.8.0/ec/b_ruins_tritanopia_sim_tritanopia.png
cvd_sim: build/shots/v0.8.0/ec/current_ruins_tritanopia_sim_tritanopia.png
```
These stay in `build/shots/v0.8.0/ec/` (`*_sim_*.png`). In the deuteranopia simulation of A the rings read amber,
the ranged kinds read blue and the rest olive, as the numbers say.

## Tests (run locally)
```
$ gdformat --check src scripts tests && gdlint src scripts tests
807 files would be left unchanged
Success: no problems found
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_enemy_palettes.gd -gexit
Tests                 9
Passing Tests         9
Asserts            2683
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Tests               527
Passing Tests       527
Asserts           1911738
Time              557.612s
$ godot ... -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
Tests                 6
Passing Tests         6
$ godot ... -gdir=res://tests/golden -ginclude_subdirs -gexit
Tests                 2
Passing Tests         2
$ godot ... -gtest=res://tests/e2e/test_e2e_enemies.gd,res://tests/e2e/test_e2e_horde_enemies.gd -gexit
Tests                 3
Passing Tests         3
Asserts             584
$ godot ... -gtest=res://tests/e2e/test_e2e_new_enemies.gd -gexit
Tests                 1
Passing Tests         1
Asserts              12
```
`test_enemy_palettes.gd` (new): the table covers the 14 `data/enemies` kinds x 4 palettes x 4 slots; `current` is
today's colours and the shipped default (no new eyes); each candidate keeps each role in its hue family (tanks darker
than the Splitter); kinds in a role ≥ ΔE 5 apart and roles ≥ 15 (normal vision); no enemy colour within ΔE 10 of a
reserved one (player core, hostile shot, telegraph, hazard, heal green, the heat Hot and Overclock); role colours stay
out of the biome's grey cast; the avatars built by `ActorViews` draw the active palette's colours (all four palettes);
the Splitter and Mender eyes only in the candidates; a colour-blind mode still recolours the ring and X-ray twin and
leaves the palette alone. `test_needle_avatar.gd` reads the red from the table. Not run locally: the full suite
(CLAUDE.md; it runs once on the PR).

Goldens: none changed (presentation only; `tests/golden` 2/2).

## Owner
- **Pick (A / B / C, or a mix):** OWNER ONLY. On the pick, `EnemyPalettes.active` becomes its key; the step is Done
  then.
