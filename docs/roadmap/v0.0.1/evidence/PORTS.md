# PORTS: which Deathventory files are copied, from which commit, into which step

- **Status:** RUN (port map written; files are copied in the step listed)
- **Source:** `riusprime/deathventory` @ `1d69780339a3ddffb9dfe7e4b75b114b8376e0c1` (main, v0.9.7, 2026-10-06 09:00 +0200)
- **Date:** 2026-10-06
- **Who ran it:** agent

Every port in v0.0.1 and later uses the SHA above, even if Deathventory's `main` moves. Each copied file carries
`# Ported from riusprime/deathventory@1d697803:<path>. Changes: …`.

## Command
```
git -C deathventory rev-parse HEAD
for f in <paths below>; do printf "%s %s\n" "$(wc -l < $f)" "$f"; done
```

## Raw output
```
1d69780339a3ddffb9dfe7e4b75b114b8376e0c1
50 src/app/game_version.gd
49 tests/v2/v2_01/test_game_version.gd
11 tests/support/test_harness_self_test.gd
8 scripts/verify.sh
11 scripts/verify.ps1
53 .github/workflows/verify.yml
82 .github/workflows/windows-export.yml
179 scripts/export_windows.ps1
56 tests/export/export_smoke.gd
67 src/domain/core/deterministic_rng.gd
4 src/domain/core/rng_step.gd
124 src/domain/core/canonical_value.gd
22 src/domain/model/validation_issue.gd
176 src/application/profile_store.gd
102 src/application/run_save_store.gd
199 src/presentation/audio/sfx_mixer.gd
```

## Port map

| Deathventory path | Lines | New path | Copied in | Trim |
|---|---|---|---|---|
| `src/app/game_version.gd` | 50 | `src/app/game_version.gd` | Step 1 | Drop `PatchNoteEntry` helpers if any reference DV content |
| `tests/v2/v2_01/test_game_version.gd` | 49 | `tests/unit/app/test_game_version.gd` | Step 1 | Keep lines 14–22 (preset version check); drop patch-note checks (34–49) |
| `tests/support/test_harness_self_test.gd` | 11 | `tests/support/test_harness_self_test.gd` | Step 2 | — |
| `scripts/verify.sh`, `scripts/verify.ps1` | 8, 11 | `scripts/` | Step 2 | Add import step and summary guards |
| `.github/workflows/verify.yml` | 53 | `.github/workflows/verify.yml` | Step 3 | Rewrite steps per PLAN Step 3 |
| `.github/workflows/windows-export.yml` | 82 | `.github/workflows/windows.yml` | Step 3 | Keep console-exe step; add pin check, import, goldens |
| `scripts/export_windows.ps1` | 179 | `scripts/export_windows.ps1` | Step 3 | Replace `Deathventory.*` names with `game.*` |
| `tests/export/export_smoke.gd` | 56 | `tests/export/export_smoke.gd` | Step 3 | Keep the check/exit skeleton; replace every DV check |
| `src/domain/core/deterministic_rng.gd`, `rng_step.gd` | 67, 4 | `src/sim/core/` | Step 4 | Rejection sampling instead of modulo pick |
| `src/domain/core/canonical_value.gd` | 124 | `src/sim/core/canonical_value.gd` | Step 4 | float32 policy, vector types, hard error instead of `assert(false)` |
| `src/domain/model/validation_issue.gd` | 22 | `src/content/validation_issue.gd` | Step 6 | — |
| `src/application/profile_store.gd` | 176 | `src/application/profile_store.gd` | Step 8 | Replace DV sections; cut `JournalStore` |
| `src/application/run_save_store.gd` | 102 | `src/application/run_save_store.gd` | v0.4.0 | `RunState` envelope; `.bad` copy on failed load |
| `src/presentation/audio/sfx_mixer.gd` | 199 | `src/presentation/audio/sfx_mixer.gd` | v0.1.0 | Typed cue resources; `cosmetic` pitch jitter |

## Interpretation
All 16 source files exist at the recorded SHA. No file was copied in Step 0.
