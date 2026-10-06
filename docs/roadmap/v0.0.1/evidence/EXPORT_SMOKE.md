# EXPORT_SMOKE: does the exported pack ship the game and nothing it shouldn't?

- **Status:** RUN (locally, Step 3). CI runs the same script on every push; links are added when CI is green.
- **Build:** working tree on top of `0bca5b4` (Step 3 changes uncommitted at run time); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux x86_64 (cloud container)
- **Date:** 2026-10-06
- **Who ran it:** agent

## Command
```
bash scripts/ci/export_smoke.sh
```

## Raw output
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
exit=0
```

## Finding while building this check
Run from the repository root, `godot --main-pack build/check/game.pck -s …` printed "project folder": Godot used the
`project.godot` in the working directory instead of the pack, so every pack-only check was skipped without a
miss. Deathventory's CI ran it exactly that way. The script now runs the smoke from `build/check/`, and the
smoke takes `expect_pack=1`, which turns "not inside the pack" into a miss.

## Checks live after Step 3
| Check | Since |
|---|---|
| running inside the exported pack | Step 3 |
| the main scene ships | Step 3 |
| the test framework (GUT) is not shipped | Step 3 |
| tests are not shipped | Step 3 |
| 600-tick World run hash | Step 4 (pending) |
| content counts, manifest hash | Step 6 (pending) |
| Spanish loads | Step 10 (pending) |
