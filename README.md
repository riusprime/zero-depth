# {{TITLE}}

A real-time action roguelike in low-poly isometric 3D. Move and aim freely; fight with a primary attack, a utility
skill (guard or a mobile skill) and a dash. Build item **engines** (bleed, guard and more) that change how you
play. Push through procedural floors across distinct biomes, where danger rises only when you choose it.

**Status:** v0.0.1 "Ground Plane" built: a cube moves, aims and dashes on a test stage, menus in English and
Spanish, every CI guard live. Waiting on the owner's playtest ([plan](docs/roadmap/v0.0.1/PLAN.md),
[playtest](docs/roadmap/v0.0.1/PLAYTEST.md)). Windows, mouse+keyboard and gamepad. English and Spanish.

## Run and test

[`CLAUDE.md`](CLAUDE.md) has the full list of commands.

```bash
godot --headless --path . --editor --import --quit   # first import
godot --path .                                       # play (Godot 4.7.x)
bash scripts/verify.sh                               # full test suite with CI guards
```

CI (`.github/workflows/`) runs the suite, lint, the hitch probe, an export smoke test and a sim smoke on
ubuntu. It also runs cross-OS replay goldens and a Windows export on windows. The Windows build is uploaded as
an artifact for playtests.

## Docs

| Start with | |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | How work is done here (read first, every session) |
| [`KICKOFF.md`](KICKOFF.md) | How to start the first development session |
| [`docs/roadmap/ROADMAP.md`](docs/roadmap/ROADMAP.md) | Versions, exit gates, release checklist |
| [`docs/design/GAME_BLUEPRINT.md`](docs/design/GAME_BLUEPRINT.md) | The game design |
| [`docs/LESSONS.md`](docs/LESSONS.md) | Lessons from the owner's previous game and the rules they became |
| [`docs/architecture/`](docs/architecture/) | Locked decisions, architecture, sim, content, presentation, tests |
| [`docs/patch-notes/`](docs/patch-notes/README.md) | What changed in each version |
