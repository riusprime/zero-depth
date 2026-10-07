# v0.5.0 — Roads Between: shops, events, curses, salvage, routes and a 30–60 minute measured run (plan, owner-directed 2026-10-07)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **Before this:** v0.4.0 "Run Depth" ([`../v0.4.0/PLAN.md`](../v0.4.0/PLAN.md)) on `claude/lucid-fermat-9wv2tf`; `main`
  doesn't exist yet (O3).
- **Owner (2026-10-07):** "skip the rule, keep going to v0.5.0" — ROADMAP §0.3 waived once: v0.5.0 is built without a
  v0.4.0 playtest; the owner plays both together.
- **Owner (2026-10-07):** "okay let's bove the bigger card pool to v0.5 and make it in this current development
  sprint" — the 40–50 card pool is v0.5.0 scope, built as step CP (done). Owner on how to count it: **per build**
  (what one Blade or Gun run can be offered): Blade 50, Gun 48; all content together is 58.
- **ROADMAP v0.5.0 scope:** shops and events, cursed rewards, salvage, optional routes; a full run of 30–60 minutes;
  every scorecard cell fillable from reproducible commands (exit gate, **sims** + **test**).
- Every number below is a **starting value** the owner tunes after playing. Anything not directed here is a lead
  proposal the owner may change.

## Every owner line → where it lands
| # | Source | Decision | Step |
|---|---|---|---|
| C1 | Owner: the card pool moves to v0.5.0, built now; count per build | 40–50 cards per build, every card reachable (no dead cards) | CP |
| R1 | ROADMAP: "Shops" | One **shop** per floor in a side room (a terminal): 4 cards for shards (price by rarity × floor), a heal (30 % max HP), a reroll (price rises per use) | SH |
| R2 | ROADMAP: "salvage" | At a shop: **salvage** a mod or stat card for shards (40 % of its price); **free a slot** by salvaging an ability (refunds by level) so a later ability card can take it | SH |
| R3 | ROADMAP: "events" | 1–2 **event rooms** per floor (a lit pedestal; interact): a choice between two or three outcomes with a cost (HP, shards, a curse, a fight) and a reward; 8 events to start | EV |
| R4 | ROADMAP: "cursed rewards" | Some chest offers and events carry a **curse**: a strong card plus a lasting drawback (e.g. enemies +15 % speed, −20 % regen, Overclock decays faster); curses raise threat T (PD-05) and are listed on the stats panel | EV |
| R5 | ROADMAP: "optional routes" | After floors 1 and 2 the portal room offers **two portals**: the normal next floor or a **Deep** variant (×1.25 scaling, one extra chest, a curse-free epic altar); the choice shows on the floor card and the minimap | RT |
| R6 | ROADMAP: "A full run of 30–60 minutes" | Floors last 10–15 min (M-FLOOR) by measured pacing (boss door opens after the floor's last required room or a minimum time); a bot run is 30–60 min | TU5 |
| R7 | ROADMAP exit gate: "All scorecard data collected … every cell can be filled from reproducible commands" | `scripts/sims/scorecard.gd` writes every SCORECARD §2 cell to `build/`; the evidence file is filled by hand from its output | SCD |

## Steps
| Wave | Step | Scope |
|---|---|---|
| (done) | CP | The 40–50 card pool per build ([`evidence/CARD_POOL.md`](evidence/CARD_POOL.md)) |
| 4 | SH | Shops and salvage |
| 4 | EV | Events and cursed rewards (threat T) |
| 5 | RT | Optional routes (Deep portals) |
| 5 | TU5 | Pacing to a 30–60 minute run (with v0.4.0 TU's scaling tuning) |
| 5 | SCD | Scorecard collection: every cell from a reproducible command |
| — | R | Build for the owner (v0.4.0 + v0.5.0 together) + playtest sheet |

## Open items
- Q1 (from v0.4.0): Echoes, Core theft, Depth descent — still unanswered; not built.
- O3 `main`; O4 credit line.

## Verification
- Unit + e2e per step; generation property tests for new rooms (1,000 seeds); readable cause 0 violations; sims as
  evidence; goldens only on purpose; full suite, lint, export smoke before every merge push; CI green.
