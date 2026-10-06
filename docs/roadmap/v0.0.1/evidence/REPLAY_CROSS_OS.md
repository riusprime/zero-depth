# REPLAY_CROSS_OS: does the kernel give bit-identical results on Linux and Windows (EI-11)?

- **Status:** RUN
- **Build:** `818ac816` on `claude/lucid-fermat-9wv2tf` (the Step 4 kernel plus a CI fix); Godot `4.7.2.stable.official.ed1daf0bf`
- **Date:** 2026-10-06
- **Who ran it:** CI (GitHub Actions) and agent (fixture generation, Linux container)

## Command
```
# Fixture (Linux container, on purpose):
godot --headless --path . -s tests/golden/generate_replay_ground_plane.gd
# Checked by tests/golden/test_replay_ground_plane.gd on both CI jobs:
#   verify (ubuntu-latest):  the full suite
#   windows (windows-latest): pwsh scripts/verify.ps1 -TestDirectory res://tests/golden
```

## Raw output
Fixture generation (Linux container):
```
GOLD| final=cc9224c81a5a357ff13b92238221619764611d8c11e8a43ab18436977cdcd8b2 checkpoints=166 (6493 ms)
```
Windows job 112480150211, run https://github.com/riusprime/zero-depth/actions/runs/37525151735 (step "Golden replays"):
```
res://tests/golden/test_replay_ground_plane.gd
* test_replay_matches_every_checkpoint
REPLAY| final=cc9224c81a5a357ff13b92238221619764611d8c11e8a43ab18436977cdcd8b2
* test_two_runs_in_one_process_agree
2/2 passed.
Passing Tests         2
verify: ok (2 passing)
```
Ubuntu verify run at the same SHA: https://github.com/riusprime/zero-depth/actions/runs/37525151727 (success).
Locally (Linux), `bash scripts/verify.sh` printed the same `REPLAY| final=cc9224c8…`.

## Target bands
| Metric | Target | Source |
|---|---|---|
| Checkpoint hashes (166, every 60 ticks over 10,000 ticks) | all equal to the fixture on both OSes | EI-11; ARCHITECTURE §13 risk 2 |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Linux final hash | `cc9224c8…cdcd8b2` | — |
| Windows final hash | `cc9224c8…cdcd8b2` | Yes (identical) |
| Every checkpoint matched (the test asserts each one) | yes, both jobs green | Yes |

## Interpretation
For this build of Godot on x86_64, the kernel (float32 kinematics with + − × ÷ and sqrt, the trig table, integer
RNG) gives bit-identical state on Linux and Windows across 10,000 ticks with 20 movers, projectiles and walls.
The fixed-point fallback is not needed. This must be re-proved whenever the Godot pin changes.
