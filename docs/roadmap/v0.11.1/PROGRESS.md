# v0.11.1 — progress

Plan: [`PLAN.md`](PLAN.md). Branch `claude/v0110` (shared with v0.11.0), from `c339458a`.

## Where we are
(The lead keeps this block current at every push. Updated 2026-11-10.)

- **Planned, nothing built.** The audit ([`../../audits/CODE_AUDIT_2026-11-10.md`](../../audits/CODE_AUDIT_2026-11-10.md))
  and the plan are written; the owner answered the decisions the same day.
- **Next:** Wave 1 (faster tests), starting with step 1 (time the seams run per file).
- **v0.11.0 playtest feedback goes first** whenever a round arrives.
- **Waiting on the owner:** the OK for the golden reset (steps 37–38) and which devices get aim assist (step 33; a
  default is planned).

## Owner decisions (2026-11-10)
- Tests: speed them up; some are unnecessary.
- The four brainstorm HUD styles go; the Astral look stays and becomes the only one, menus included.
- Dead code and history comments are cleaned up.
- The line cap: the lead decides → 1,000 stays; no splits just to fit; exemptions listed and tested.
- Old run saves: refused from this version on ("old saves don't really matter until the release").
- e2e tests may skip the hub walk through a test-only switch.
- Seeds: 200 if that is enough → 200 locally, 1,000 in the GitHub full suite.
- Aim assist: wired in, "10% or so".
- Repo size and the golden reset: the owner asked for the implications; both are answered in the PLAN with the
  lead's recommendation (leave the repo; one reset, last).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| 0 | Audit, plan and docs | this commit |

## Goldens changed on purpose
- None.

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| The golden reset (steps 37–38) | PLAN "The golden reset" | pending | |
| Aim assist devices (step 33) | PLAN "Open items" | pending (default: mouse and gamepad, on) | |
| Feel of aim assist | after step 33 | OWNER ONLY | |
| Feel of enemies on the crowd | after each batch of step 39 | OWNER ONLY | |

## Open
- See PLAN "Open items".

## Blockers
- None.

## History
- 2026-11-10 — Audit run (read-only), plan written, the owner's decisions recorded. Next: step 1.
