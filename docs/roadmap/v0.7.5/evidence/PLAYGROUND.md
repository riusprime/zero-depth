# Evidence: v0.7.5 PG, the Playground (owner N19)

**Question:** can the owner reach a creative-mode room from the real main menu, take any card at any level, place
and delete dummies (endless or with an HP), enemies and bosses by click, read a DPS meter by source, and switch the
room between the five biomes? Design and owner picks: [`../../../tools/PLAYGROUND.md`](../../../tools/PLAYGROUND.md).

Branch `claude/playground`, cut from `claude/v0.7.5-new-ground` at `d5a5602` (BM done, BF not started).

## Runs (agent, Linux, Godot 4.7.2.stable, 2026-10-13)

| What | Command | Tree | Result |
|---|---|---|---|
| Lint | `gdformat --check src scripts tests && gdlint src scripts tests` | `d1ed9ac` | `777 files would be left unchanged`; `Success: no problems found` |
| Shards | `bash scripts/ci/gut_shard.sh --check` | `431b543` | `gut_shard: ok (277 test files in 6 shards)` |
| Seams | `bash scripts/ci/seams.sh` | `431b543` | `Tests 288`, `Passing Tests 288`, `check_gut_log: ok (288 passing, minimum 1)` |
| Presentation units + 11 e2e (codex, credits, spanish, builds, options, attacks, bosses, bosses_2, boss_challenge, after_boss, playground) | `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gtest=<the 11 e2e files> -gexit` | `431b543` | `Tests 516`, `Passing Tests 516` |
| After the gate fix: playground, portal, run_flow, ascension, routes e2e | `… -gtest=<those 5 files> -gexit` | `d1ed9ac` (working tree) | `Tests 9`, `Passing Tests 9` |
| After the gate fix: portal gate + playground units | `… -gtest=res://tests/unit/presentation/test_portal_gate.gd,res://tests/unit/application/test_playground.gd -gexit` | `d1ed9ac` (working tree) | `Tests 28`, `Passing Tests 28` |

Not run locally: the full suite (the PR into `main` runs it on GitHub, CLAUDE.md), export smoke, the hitch probe.

## Screenshots

`godot --path . --rendering-driver opengl3 --resolution 1280x720 -s scripts/shots/playground.gd -- lang=<en|es>
size=1280x720` under `xvfb-run` (llvmpipe, gl_compatibility) → `build/shots/v0.7.5/playground/` (not tracked): menu,
dps, panel_build, panel_spawn, frozen_shore, starfall, in en and es. The first set showed a portal gate drawn in the
room (the room has none in the sim) and the HUD showing through the panel; both fixed in `d1ed9ac`, then re-shot.

## Findings

- A base-branch bug met on the way: `ActorViews._drop_missing` (v0.7.5 BM) called `get_meta(&"enemy_avatar", null)`,
  which reports an error for any body without an avatar (Godot reads a null default as none); a deleted dummy hit it.
  Fixed with `has_meta` first (`431b543`).
- `effect_id` names every damage source the meter shows (a probe over a Gun and a Blade build with cards and every
  ability: empty for the basic attack, else the card / ability / engine id).
- Owner-only: whether it covers what you want to test, and how it feels: **OWNER ONLY**.
