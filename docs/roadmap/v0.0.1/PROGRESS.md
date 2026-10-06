# v0.0.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (`main` doesn't exist yet: O3). Version: `0.0.1`.

## Owner decisions (2026-10-06)
- **Engine:** Godot 4 3D with a fixed orthographic iso camera. The simulation is a flat 2D plane.
- **Floors:** procedural. 3 biomes first (Ruins, Night Rocks, Red Canyon); more are added during balancing,
  before content complete.
- **Platform:** Windows, with mouse+keyboard and twin-stick gamepad parity from day one.
- **Kickoff deliverable:** the starter doc kit.
- **The audit framework is the only design source** (no gap-analysis report). GA numbers are owner decisions; see
  `LOCKED_DECISIONS.md`.
- **Bench:** stress scene mean ≤ 2 ms, p99 ≤ 4 ms; reference encounter ≥ 15× real time.
- **Start building:** the owner asked to start v0.0.1 now, on `claude/lucid-fermat-9wv2tf` (no `main` yet).
- **Design sources:** the reference image is in the repo (`docs/art/biomes_reference.png`). The audit framework
  is committed verbatim (`docs/design/ROGUELIKE_AUDIT_FRAMEWORK.md`).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Starter doc kit (all docs; no code) | `1e1a046` |
| — | Reference image (owner upload) | `566e3cb` |
| — | Kit review fixes, audit framework, sampled palette; owner decisions recorded | `f1c0e8f`, `231b7da` |
| 0 | Repo hygiene and the Deathventory port map | `e960628` |
| 1 | The project opens: settings, version single source, Windows preset | `ecbef02` |
| 2 | Tests run, and a run that tested nothing fails | `0bca5b4` |
| 3 | CI on every push: verify (ubuntu) and windows | `e44c69e`, fixes `2aade11`, `818ac81` |
| 4 | A deterministic 60 Hz kernel: the cube moves, aims and dashes | `e9c6edd`; cross-OS evidence `9cc6e40` |
| 5 | Bench: reference 31.2× real time; stress scene **missed** | `5b03b97` |
| 6 | Content: typed, validated, found by a remap-safe scanner | `e92ad27` |
| 7 | The iso view, occlusion and the gate galleries | `dc61ab8` |
| 8–9 | Boots to a menu; play with keyboard+mouse or gamepad | `e67e9c0` |
| 10 | English and Spanish everywhere, in a real font | `e4a5bba`, fix `fa455ef` |
| 11 | Credits: the owner's line, Godot's and the font's licences | `5944b47` |
| 12 | Dev panel stub (debug builds) | `3454ed0` |
| 13 | Release items: patch notes (+ in-game copy), version `0.0.1`, tour, PLAYTEST | see `git log` (this commit) |

Step 13's own "done when" (PR merged, owner's Windows check recorded) is **not met**: it waits on O3 and the owner.

## Deviations from the PLAN (recorded, none changes scope)
- The default bindings live in `src/application/input_defaults.gd` (applied by `Main`), not in `project.godot`.
- `GameVersion` moved from `src/app/` to `src/application/` in Step 8: the profile store needs it and nothing may
  import `app/` (the layering lint caught it).
- `ContentRepository` and `ContentCompiler` live in `src/application/`; the galleries live in `src/app/galleries/`.
- Steps 8 and 9 were one commit: the shell's e2e tests need input, and input's need the shell.
- `scripts/shots/tour.gd` was written in Step 8 (it drives the shell) and extended in Step 13.
- The dev panel is built in code (`src/debug/dev_panel.gd`); there is no `dev_panel.tscn`.
- The patch-note copy is `data/patch_notes/v0.0.1.tres` with id `v0_0_1` (ids are snake_case).
- The UI theme is applied by `Main` at boot instead of `gui/theme/custom`: the project setting loaded it before a
  fresh checkout's first import had produced the font, and CI's import check went red on Steps 10–11 (fixed in
  `fa455ef`).

## Goldens changed on purpose
- Created in Step 4: the replay golden (`tests/golden/fixtures/replay_ground_plane.json`) and the export-smoke
  hash. None changed since.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Renderer pick (Forward+ / Compatibility) | after Step 7 ([GALLERIES](evidence/GALLERIES.md)) | pending | |
| Camera pitch (30° / 35.26° / 45°) | after Step 7 | pending | |
| Occlusion technique (fade / X-ray / both) | after Step 7 | pending | |
| Bench reading (O5) | 2026-10-06 | 15× applies to the reference scene | 2026-10-06 |
| Bench stress miss (mean 3.457 ms, p99 5.988 ms vs 2 / 4 ms) | Step 5 ([BENCH](evidence/BENCH.md)) | pending | |
| Player-kit starting values | with the Step 7 gates; again in PLAYTEST | pending | |
| Owner Windows check | after Step 13 ([PLAYTEST](PLAYTEST.md)) | Played: "just the box moving no enemies or no attacking so I could not really try it". Too little to judge; feeds v0.1.0 | 2026-10-06 |

## Open
- O3 `main` branch exists (owner). Blocks the PR to `main`.
- O4 the owner's credit line (owner). The credits show "—" until then.
- Pins: Godot `4.7.2` (`4.7.2.stable.official.ed1daf0bf`), `gdtoolkit==4.5.0`, GUT 9.7.1.

## Blockers
- None for the lead. Everything left is an owner gate.

## History
- 2026-10-06 — Starter doc kit committed, then reviewed by two read-only reviewers and corrected. The owner
  added the reference image and the audit framework. Next: Step 0 (repo hygiene, the Deathventory port map).
- 2026-10-06 — Steps 0–12 built and pushed; Step 13 release items done (version `0.0.1`, patch notes en/es and
  their in-game copy, tour en/es, PLAYTEST.md). 83 tests pass from a clean worktree; export smoke 0 misses. CI
  was red on Steps 10–11 (fresh-checkout import errors from the project theme), fixed in `fa455ef`. Next: the
  owner's gates and playtest; then the PR to `main` once O3 is done.
- 2026-10-06 — The owner played the Windows build: too bare to judge (no enemies, no attack). Recorded verbatim in
  PLAYTEST.md. Next: v0.1.0 "Combat Lab" Phase 0 (design questions to the owner, then its PLAN).
