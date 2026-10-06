# TOUR: the real game, driven by input, in English and Spanish

- **Status:** RUN locally (12 shots). CI's `shots` workflow re-runs it on every push and uploads `build/shots/` as
  the `shots` artifact.
- **Build:** working tree on `fa455ef` + Step 13 changes (tour extended to credits and options, version `0.0.1`);
  Godot `4.7.2.stable.official.ed1daf0bf`
- **Machine:** cloud container, Xvfb, Forward+ through lavapipe (software Vulkan). Not a GPU.
- **Date:** 2026-10-06
- **Who ran it:** agent

## Command
```
for l in en es; do
  VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/tour.gd -- lang=$l
done
```
The script boots `main.tscn` and presses keys through `Input.parse_input_event`: menu → Credits → Back → Play →
move right then up → Esc (pause) → Main menu → Options.

## Raw output (lines with `tour:` or `ERROR`)
```
tour: res://build/shots/v0.0.1/en/01_main_menu.png
tour: res://build/shots/v0.0.1/en/02_credits.png
tour: res://build/shots/v0.0.1/en/03_stage.png
tour: res://build/shots/v0.0.1/en/04_stage_moved.png
tour: res://build/shots/v0.0.1/en/05_pause.png
tour: res://build/shots/v0.0.1/en/06_options.png
tour: res://build/shots/v0.0.1/es/01_main_menu.png
tour: res://build/shots/v0.0.1/es/02_credits.png
tour: res://build/shots/v0.0.1/es/03_stage.png
tour: res://build/shots/v0.0.1/es/04_stage_moved.png
tour: res://build/shots/v0.0.1/es/05_pause.png
tour: res://build/shots/v0.0.1/es/06_options.png
```

## The shots (committed contact sheets in `shots/`)
`shots/tour_en.png` and `shots/tour_es.png`, in tour order (top row: menu, credits, stage; bottom row: moved,
pause, options).

## Interpretation
- Every screen the tour reaches is translated in Spanish (JUGAR, CRÉDITOS, PAUSA, OPCIONES, accents rendered).
- The title reads `{{TITLE}}`: the game is untitled, by design.
- The credits' owner line shows "—" until owner action O4.
- The menu shows Galleries because the tour runs a debug build; release exports hide it (Step 8 test).
- Whether the screens *look* right is the owner's call (PLAYTEST.md): `OWNER ONLY`.
