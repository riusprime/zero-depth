# TOUR: the screenshot tour in en and es, and the v0.11.0 feature shots (ROADMAP §0.4)

- **Status:** RUN
- **Build:** `7c91af55` on `v0110-rel` (cut from `claude/v0110`), plus this commit's uncommitted docs and
  `data/patch_notes/v0.11.0.tres` (no code changes); Godot `4.7.2.stable.official.ed1daf0bf`; OS Windows 11 Pro
  (owner's PC, RTX 3060)
- **Date:** 2026-11-08
- **Who ran it:** agent

Images are not committed; they are in the `wt-rel` worktree's `build/shots/` on the owner's PC.

**The output folder is `v0.10.5`, not `v0.11.0`:** `tour.gd` names it from `GameVersion.label()`, and the version in
`project.godot` is still 0.10.5 (not bumped until the owner answers OWNER_QUESTIONS §J N11). Re-run the tour after
the bump if the release needs the folder name to match.

## Commands
`godot` is `C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`; run from
the worktree root in Git Bash, the two languages in parallel, each with its own `APPDATA`.
```
godot --headless --path . --editor --import --quit
APPDATA=$PWD/build/appdata_tour_en godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/tour.gd -- lang=en
APPDATA=$PWD/build/appdata_tour_es godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/tour.gd -- lang=es
```

## Raw output (en; es is the same with `/es/`)
```
tour: res://build/shots/v0.10.5/en/01_main_menu.png
tour: res://build/shots/v0.10.5/en/02_credits.png
tour: res://build/shots/v0.10.5/en/03a_build_picker.png
tour: res://build/shots/v0.10.5/en/03_stage.png
tour: res://build/shots/v0.10.5/en/04_stage_moved.png
tour: res://build/shots/v0.10.5/en/05_pause.png
tour: res://build/shots/v0.10.5/en/06_options.png
ERROR: 1 RID allocations of type 'N10RendererRD14TextureStorage7TextureE' were leaked at exit.
ERROR: Parameter "RenderingServer::get_singleton()" is null.
exit=0
```

## Shots
`build/shots/v0.10.5/en/` and `build/shots/v0.10.5/es/`, 7 each: `01_main_menu.png`, `02_credits.png`,
`03a_build_picker.png`, `03_stage.png`, `04_stage_moved.png`, `05_pause.png`, `06_options.png`.

`04b_fight.png` was **not** taken in either language: the tour waits until frame 320 for an enemy telegraph, and the
"stage" it reaches is now the hub (no enemies), so none came. One shot looked at (`es/04_stage_moved.png`): the hub
with the Spanish prompt line. The others were not looked at.

## The v0.11.0 feature shots
`tour.gd` covers menus and the hub only; it has no stop for anything v0.11.0 added. Instead of copying each feature's
staging into it, the existing v0.11.0 shot scripts (real game view, English only; none takes a language) were run on
the same build, five then four in parallel, each with its own `APPDATA`:
```
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/o10_spells.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/quake_pillars.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/nb_lantern_shade.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/o5_twin_wardens.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/o15_purpose_floor.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/o13a_variants.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/o13b_signatures.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/o13c_signatures.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/o13d_starfall.gd
```
Every run printed `exit=0`. The paths each printed (none of these images was looked at):

| Feature | Shots |
|---|---|
| Spells (cast, burst, four Lv 5 spells) | `build/shots/v0.11.0/o10/cast.png`, `burst.png`, `roster.png` |
| Gatekeeper quake pillars | `build/shots/v0.11.0/o3/quake_pillars_phase2.jpg` (printed `pillars=2`) |
| Lantern Shade in the dark | `build/shots/v0.11.0/o4/1_lantern_shade_dark.jpg` |
| Twin Wardens phase 3 | `build/shots/v0.11.0/o5/1_twin_wardens_phase3.jpg` |
| Purpose rooms | `build/shots/v0.11.0/o15/floor_camp_ruins.png`, `floor_hall_ruins.png`, `floor_hall_starfall.png`, `floor_quarry_red_canyon.png` |
| Variants | `build/shots/v0.10.5/o13a/rubble_warden.png`, `dim_needle.png`, `ember_charger.png`, `frost_charger.png`, `split_sniper.png` |
| Ruins, Night Rocks signatures | `build/shots/v0.10.5/o13b/wire_weaver.png`, `scrap_hound.png`, `rock_lurker.png`, `stone_thrower.png` |
| Red Canyon, Frozen Shore signatures | `build/shots/v0.10.5/o13c/kiln_beetle.png`, `cinder_priest.png`, `frost_spitter.png`, `glacier_turtle.png` |
| Starfall signatures | `build/shots/v0.10.5/o13d/star_warper.png`, `gravity_node.png` |

**Not shot:** a horde surge (no shot script exists for it; `tests/e2e/test_e2e_horde_surge.gd` reaches it), the Laser
lance (look waits for the owner's sketch), the hint arrow, the hidden room (being built by another step).

## Interpretation
The en and es tours ran to the end in both languages. They prove the menus, credits, build picker, hub, pause and
options render in each language; they say nothing about the v0.11.0 features. The feature shots are English only. Whether
any shot looks right is for the owner (OWNER ONLY).
