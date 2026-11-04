# v0.10.5 W3-O12 — the Effects gallery (F28)

Owner, 2026-11-04: "i'd like to see which assets from the pack we did not use that could be used, could there be a
repository of how all of the current effects look in the game for the premade pack and the already used or original
from the game enemies, and effects from all abilities and enemies so I can compare the pack to what we have and choose
which ones are the best."

A dev-only gallery that plays every effect live: the hero's, the enemies', the bosses', every pack effect the game uses
and every pack effect it doesn't. Nothing in the game changes; picks go into later steps.

## How to open it

Debug builds (the editor's Play, or a debug export): at the main menu (off a run) press **F10**; the master dev
panel's top bar has **Galleries** (the old showcase room) and, beside it, **Effects**. Effects opens the gallery as the
menu; **Back** (or Esc / pad B) returns to the main menu. The gallery takes a few seconds to open (it scans the pack and
the code once a session).

| Key / pad / mouse | One entry | Grid |
|---|---|---|
| Right, Left (d-pad) / Next, Previous | the next / previous entry | the next / previous page |
| Down, Up (d-pad), RB, LB / Group buttons | the next / previous group | the same |
| G (pad Y) / Grid | the group's grid, on the page of the entry | back to the one entry |
| click a cell | — | opens it as the one entry |
| Esc (pad B) / Back | back to the main menu | leaves the grid |

One entry fills the screen with its name, its **Source** and **Used by** lines; a sim entry also lists the **pack
effects its views drew so far** (the PackFx ids, refreshed twice a second), so a code look and a pack look can be told
apart. The grid shows 9 game views a page for the sim groups (3 × 3) and 12 for the pack groups (4 × 3), each cell
labelled with its name and source.

## How it works

`src/app/galleries/`: `effects_catalog.gd` (the lists), `effect_stage.gd` (one entry, live), `effects_gallery.gd` (the
screen, the keys). Every entry plays in its own SubViewport with its own World (the Playground's room, `PlaygroundScenario`,
in the Ruins) drawn by the real game view (`WorldViewRoot`: stage light, floor, ink, effects layer), so a look in the
gallery is the look in the game. Only this tool's own World is driven (input frames, its setup, as the Playground's
commands do); the views only read it (EI-07).

- **Sim entries** (hero, enemies, bosses): the stage plays its recipe in a loop: the build's attack (Shoot held 100
  ticks then let go 20, so charged forms release; a Blade swing every 30 ticks), the recipe's buttons (Skill, Utility,
  Dash, Vent) every 120 ticks, aimed at three training dummies (one endless, two of 1500 HP that come back 45 ticks
  after they fall, so on-kill procs play). The hero can't be hurt. An enemy or a boss stands 3.6–4.5 m away and fights
  the idle hero; it comes back if it dies (a Bomb Drone).
- **Pack entries**: the scene through a PackFx of the stage's own, 2 m from the idle hero (for scale). A used row plays
  with the game's table (its colours, its scale, its W3-S4 short life for the hit family); an unused scene plays at the
  pack's own scale and colours, as a family guessed from its folder name. Flying families (projectile, enemy_shot,
  trail, bolt) cross the stage in 1.2 s every 2 s; held families (area, cloud, status, beam, mark) loop where they
  stand; the rest play again every 2 s.
- **The unused list is computed, not typed**: every `.tscn` under `assets/BinbunVFX/` and `assets/vfx_zd/` is a scene;
  it is used when a PackFx row names it, a script / scene / content file under `src/` or `data/` quotes its path, or a
  used scene names it (a part: the fire balls' `sparks.tscn`). Everything else is in the unused group. A pack added
  later shows up by itself.

## The groups and the counts

Counted by `EffectsCatalog.build()` on this step's tree (`build/fxg_smoke.gd`, a throwaway probe, not tracked):

| Group | Entries | What |
|---|---|---|
| 1 Hero | 73 | each build (Gun, Blade): attack, skill, dash, vent (8); the two abilities that aren't a start weapon (Aegis, Blink); every card in `data/items` (63: the Gun and Blade forms, the element cores and engines, Chain Blast, the dash, guard and heat cards) |
| 2 Enemies | 17 | every enemy kind the Playground can place (their shots, attacks, telegraphs) |
| 3 Bosses | 26 | the 13 boss bodies (10 bosses, the final boss's three) × first phase / last phase (HP set just under the last threshold) |
| 4 Pack in use | 159 | every PackFx row (`data/vfx/*.tres`), with its id, scene, table file, family and the scripts that name it |
| 5 Pack not in use | 148 | every pack scene nothing uses |

Pack scenes: **263** found, **115 used, 148 unused**.

| Pack folder | Used | Unused |
|---|---|---|
| BinbunVFX/beam_vfx | 14 | 4 |
| BinbunVFX/fire_effects | 15 | 18 |
| BinbunVFX/ice_effects | 9 | 11 |
| BinbunVFX/impact_explosions | 18 | 6 |
| BinbunVFX/magic_areas | 11 | 25 |
| BinbunVFX/magic_orbs | 17 | 19 |
| BinbunVFX/magic_projectiles | 11 | 4 |
| BinbunVFX/muzzle_flash | 7 | 17 |
| BinbunVFX/poison_effects | 7 | 23 |
| BinbunVFX/smoke_effects | 3 | 21 |
| vfx_zd (ours) | 3 | 0 |

## Contact sheets

`build/shots/v0.10.5/w3o12/` (not tracked): `hero_1.png` … `hero_9.png`, `enemies_1.png`, `enemies_2.png`,
`bosses_1.png` … `bosses_3.png`, `pack_used_1.png` … `pack_used_14.png`, `pack_unused_1.png` … `pack_unused_13.png`:
each a grid page of the gallery, every cell labelled. A hero page is taken 8 ticks after the first Skill / Dash /
Vent press and a swing (tick 68), an enemy or boss page at tick 308, a pack page 0.1 s into its second play.

```
godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/vfx_gallery.gd -- --sheets
```
(`--groups=hero,bosses` and `--pages=N` narrow it.) Run once on the owner's PC (RTX 3060) at `7ce235fd` + this step;
it printed the 41 paths above and `vfx_gallery: 41 sheets`. A page whose first cell is a held effect waits its
900-frame limit (held effects play once, so that cell never reaches a second play); the picture is still taken.

One frame per page catches each entry at one moment of its loop; the gallery itself plays them.

## Unused pack effects that look like strong fits (suggestions; the owner picks)

From the unused sheets I looked at (`pack_unused_2`, `_3`, `_5`, `_7`, `_9`); the other pages (fire 01-11, the
magic orb basic / flash, the stink, smoke and thin smoke families) were not looked at for this list:

- **Venom ground: `poison_area_vfx_01` / `_02`** (a green bubbling pool): Venom Core's ground pool or Toxic Fumes.
  `_03` / `_04` are the same pool in violet: a void / curse floor hazard, or a violet boss's puddle.
- **Boss strike markers: `pillar_area_vfx_02`** (an ice-blue light column on a ring) and **`_04`** (orange): where a
  slam or a falling strike lands, or Frost Nova (02).
- **Healing: `lift_area_vfx_05`** (a green swirling ring) and **`pulse_area_vfx_05`** (a green wave disc): the Mender's
  heal, or the hero's heal. `pulse_area_vfx_04` (an orange ring wave): the Vent's or Thermal Edge's shockwave.
- **Shield / arrival: `rim_area_vfx_03`** (a lilac ring of light): Aegis's ring or Blink's arrival.
- **Frost bolts: `ice_ball_vfx_02` / `_03`** (a pale ball with a long icy plume) for a frost bolt; **`ice_shard_vfx_03`
  / `_04`** (a long thin shard) for the Needle's or the Sniper's shot; `ice_mist_vfx_04` (a burst of ice spikes) for a
  frost hit.
- **Fire: `fire_ball_02`** (a striped molten ball) for Big Shot in fire; **`fire_area_08`** (a ring of embers on the
  floor) for Wildfire's burning ground; **`fire_forcefield_01`** (an orange dome) for Ember Ward or Bulwark.
- **Explosions: `vfx_explosion_02`** (a big orange cloud) for the Bomb Drone's or a mine's blast, or Meltdown.
- **Big halos: `magic_orb_huge_vfx_01`–`_06`** (a 2 m ring of light in six colours): a boss's phase change or the
  Prism's shatter. Too big for a shot.
- Weak fits: the muzzle and wide flashes (`muzzle_flash_*`, `wide_flash_*`) are a few pixels at the game's camera;
  `vfx_explosion_05` / `_06` read as a pale grey puff; `fire_candle` is barely visible; the ice clouds are faint on the
  warm floors.

## The short_flash "parse errors"

The two errors (`short_flash_02.tscn:42 - Parse Error`, `short_flash_03.tscn:179 - Parse Error`, seen in the W3-S6
agent's run of `test_pack_fx_session_warm`) are **not a broken file**. Both scenes load and instance cleanly: all 263
pack scenes were loaded and instanced one by one, headless and with the renderer (Vulkan, RTX 3060), with no error.
The errors come from **quitting while PackFx's threaded loads are still running**: `PackFx.request_scenes()` (the
session warm-up at the main menu) asks the loader threads for every table scene; a process that quits a few frames
later aborts the scenes still in flight, and each reports a "Parse Error" on the ext-resource line it was resolving
(line 42 of short_flash_02 is its `shader = ExtResource(...)`, line 179 of short_flash_03 its `script = ExtResource(...)`).
Which scenes fail depends on timing: a probe that calls `PackFx.request_scenes()` and quits after 1, 5 or 20 frames
printed 1–4 such errors per run, on other scenes (`vfx_hit_05`, `vfx_explosion_01/03/04`). In play nothing fails: a
spawn waits for its scene (`load_threaded_get`). No file was changed. If the noise in test logs matters, a test (or
Main's quit) could wait for the pending requests before quitting; that is outside this step. **No other pack scene
fails to load.**

## Tests (owner PC, Windows, RTX 3060; `7ce235fd` + this step)

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/app/test_effects_catalog.gd,res://tests/e2e/test_e2e_effects_gallery.gd -gexit
Scripts 2, Tests 6, Passing Tests 6, Asserts 847
godot ... -gtest=res://tests/e2e/test_e2e_dev_master_panel.gd,res://tests/e2e/test_e2e_dev_gate.gd -gexit
Scripts 2, Tests 3, Passing Tests 3, Asserts 30
godot ... -gdir=res://tests/arch -ginclude_subdirs -gexit      Scripts 2, Tests 4, Passing Tests 4, Asserts 19473
godot ... -gdir=res://tests/content -ginclude_subdirs -gexit   Scripts 31, Tests 166, Passing Tests 166, Asserts 12956
```
`test_effects_catalog` (new, 5): every pack scene is used or listed unused (never both), every PackFx row is an entry,
a scene named by a file and its part are used, `code_uses` finds an id's scripts, the sim groups hold each build's
moves, every card and the abilities. `test_e2e_effects_gallery` (new, 1): F10, Enter on Effects, Right / Left, Down to
the pack group, G, Right (the grid's next page, a pack cell plays), Esc, Esc (the main menu), through
`Input.parse_input_event` only.

## Found on the way (not fixed here)

**A World drawn by a WorldViewRoot outlives the view.** A probe (`build/fxg_leak5.gd`, not tracked) builds a
Playground World, calls `WorldViewRoot.setup(WorldReader.new(world), ...)`, frees the view and drops every reference:
a weakref to the World is still alive, and about 680 objects stay per World (headless). Without the view the World is
freed. So something the view's setup makes keeps the World (a static or a reference cycle; not found). In the gallery
this is about 80 MB of RAM per grid page (measured on the pack groups' pages); in the game it would be each floor's
World after its view is freed. For the lead to look at.

Lint: `gdformat --check` and `gdlint` clean on the touched and new scripts.

Which look is best, and feel in motion: OWNER ONLY.
