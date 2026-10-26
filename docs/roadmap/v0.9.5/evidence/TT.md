# Step TT: the game is named Zero Depth (saves carried over)

Owner 2026-10-26 (PLAN "### MM."): the name is "Zero Depth", in English and in Spanish. Machine: owner PC, Godot 4.7.2,
headless, `--language en`, temp `APPDATA` for every run (the real `%APPDATA%` was never touched).

## Files changed
- `project.godot` `config/name` and `export_presets.cfg` `application/product_name`: "Zero Depth" (the window title follows `config/name`; no code sets another title).
- `locale/strings.csv` `UI_TITLE` (en and es) and the regenerated `locale/strings.en.translation`, `strings.es.translation`.
- `README.md`, `CLAUDE.md` (line 4: the game is Zero Depth, token rule dropped), `docs/patch-notes/*.md` (all 8), `docs/patch-notes/README.md`, `docs/process/TEMPLATES.md`, `docs/architecture/ARCHITECTURE.md` (line 341), `scripts/content/text_review.py` (name rule).
- `data/patch_notes/v0.0.1.tres`, `v0.8.0.tres`, `v0.9.0.tres`, `v0.9.5.tres`: rebuilt with `scripts/content/build_patch_notes.gd`.
- New `src/application/user_dir_migration.gd` (+ `.uid`); one line in `src/app/main.gd` `_ready()` (kept at 1000 lines by merging a var comment onto its var line).
- New `tests/unit/application/test_user_dir_migration.gd` (+ `.uid`).
- Left alone: historical `docs/roadmap/v0.*` docs. `tests/v9/v096/test_export_paths.gd` named in ARCHITECTURE.md does not exist in the tree; nothing asserted the token or the product name (`grep -rn TITLE tests scripts/ci .github` found only unrelated `*_TITLE` names).
- `git diff project.godot` after the import: only the `config/name` line.

## The save folder
`project.godot` has no custom user dir, so `user://` is `%APPDATA%/Godot/app_userdata/<config/name>/`, and the exported .exe
uses the same rule (`export_presets.cfg` sets only the product name, no custom dir). Renaming would start empty, so
`UserDirMigration.run_for_user_dir()` runs first in `Main._ready()`:
- skips if the marker `migrated_from_title_token` exists in the new dir, if the old sibling folder `{{TITLE}}` is missing,
  if the new dir already has `profile.json` or `saves/run.save`, or if the old one has neither;
- else COPIES every file and subfolder old -> new (never moves or deletes), writes the marker, prints one line;
- on a copy error: `push_error`, no marker, old folder untouched, the game still starts (it retries next launch).
Paths come from `OS.get_user_data_dir()`.

## Results (raw)
Unit + content, `-gtest=` migration, test_patch_notes, test_locale_coverage: `Tests 13, Passing 13, Asserts 5713` (first run had 1 failure: the failure test did not expect the engine's own "Failed to open" error; fixed with `assert_engine_error`, re-ran).
`-gdir=res://tests/arch -ginclude_subdirs`: `Tests 4, Passing 4, Asserts 18306`.
`-gtest=` test_e2e_main_menu, test_e2e_saves, test_e2e_old_save: `Tests 7, Passing 7, Asserts 73`.
Real boot (`--headless --path . --quit-after 120`, temp APPDATA, fake old folder with `profile.json` + `saves/run.save`):
- boot 1 printed `UserDirMigration: copied the saves from '.../{{TITLE}}' to '.../Zero Depth'`; new dir had profile.json, saves/run.save, marker.
- boot 2 (new profile edited, run.save removed): no copy; profile stayed "NEWER", run.save not restored.
- old folder unchanged (same two files, profile `{"version":3}`).
- empty old folder: no marker, no copy.
Lint: gdformat + gdlint on touched .gd files: no problems.

## NOT RUN
- `scripts/ci/export_smoke.sh` (needs export templates and an out-of-tree export; not attempted).
- seed-loop tests, `seams.sh`, full suite (GitHub PR).
- The visual check of the window title/taskbar.

## OWNER ONLY
- First launch on your PC: confirm the window says "Zero Depth" and your profile and run save are still there (copied from `%APPDATA%/Godot/app_userdata/{{TITLE}}/`; the old folder stays, you can delete it later).
