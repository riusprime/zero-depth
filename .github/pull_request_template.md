## vX.Y.Z Step(s) N: <player-facing outcome>

**Plan:** `docs/roadmap/vX.Y.Z/PLAN.md` · **Progress:** `docs/roadmap/vX.Y.Z/PROGRESS.md`
**Base:** `main` @ `<sha>` · **Head:** `<sha>`

## What changed for the player
- <one line per outcome>

## Owner lines covered
- L<n>: <short> → Step <n>

## Verification
- Full suite: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
  → <N passing, 0 failing> (or "docs only: not run, CI covers it")
- e2e tests that reach the new paths through real input: <test names>
- Evidence: <links to `evidence/*.md`>
- Goldens changed on purpose: None | <list; the same as PROGRESS>
- Screenshot tour (UI changes): <link> | n/a

## Honesty checklist
- [ ] Every result above came from a command I ran on this head; the raw output is in the linked evidence.
- [ ] No owner-only field (playtest answers, feel, the owner's hardware) is filled in by an agent.
- [ ] No placeholder values that look like data (checksums, timings, counts).
- [ ] Every new player-facing feature is reachable from the real game, and an e2e test proves it with real input.
- [ ] `src/sim/` stays pure (arch lint green). Presentation doesn't write sim state. Forecasts call sim functions.
- [ ] Every new visible string uses `tr()`, with `en` and `es` in `locale/strings.csv`.
- [ ] Only `.uid` files for scripts I added or moved are staged.
- [ ] Decisions made in chat are written into PLAN, PROGRESS or LOCKED_DECISIONS.

## Open / blockers / owner questions
- None | <list>
