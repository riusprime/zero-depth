# Templates

Copy these. Keep the headings so every version's docs read the same way. They follow the Deathventory formats
that worked (its v0.9.5–v0.9.7 PLAN and PROGRESS files), trimmed for one lead per version.

## 1. `docs/roadmap/vX.Y.Z/PLAN.md`

```markdown
# vX.Y.Z — <name>: <one-line goal> (plan, owner-approved YYYY-MM-DD | DRAFT)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- What is on `main` now (version, PR, SHA).
- What the owner played or sent, and when.
- Owner rule: anything that isn't a direct fix is decided before it's built.
- Gates in this version (G1 audits, G2 mockups, design questions) and what each blocks.

## Every owner line → where it lands
| # | Owner line (verbatim or close) | Decision | Step |
|---|---|---|---|
| L1 | … | … | 3 |

## Steps
### 0. Setup
- Branch from `origin/main` at `<sha>`. PLAN and PROGRESS committed first. LOCKED_DECISIONS and ROADMAP rows.

### N. <Player-facing outcome> (sim + tests + sims | presentation only)
- **Files:** …
- **Rule / design:** …
- **Tests:** test file names; the e2e test that reaches it through real input.
- **Reachable from the real game?** yes: <how>, proved by <e2e test>.
- **Done when:** …

### R. Release
- Version bump (one source), patch notes en + es, What's New, ROADMAP row + History, README status line,
  CLAUDE.md re-checked, PROGRESS final.

## Open items (what they block)
- …

## Verification
- Tests per step, sims and bench as evidence, goldens changed only on purpose, screenshot tour, CI green, then
  the owner's Windows playtest.
```

## 2. `docs/roadmap/vX.Y.Z/PROGRESS.md`

```markdown
# vX.Y.Z — progress

Plan: [`PLAN.md`](PLAN.md). Branch `<branch>`, cut from `main` at `<sha>`.

## Owner decisions (YYYY-MM-DD)
- …

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| 0 | Plan and docs | `abc1234` |

## Goldens changed on purpose
- **<golden>** (`<sha>`): why it moved. Old hash `…` → new hash `…`.
  (Write "None" when nothing moved.)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| G1 <audit> | link | approved rows / pending | |

## Open
- …

## Blockers
- None. (Or: what, since when, who unblocks it.)

## History
- YYYY-MM-DD HH:MM — what was done, what's next, any blocker. (One line per session or handoff.)
```

## 3. Evidence file: `docs/roadmap/vX.Y.Z/evidence/<NAME>.md`

```markdown
# <NAME>: <question this evidence answers>

- **Status:** RUN | NOT YET RUN | OWNER ONLY
- **Build:** `<git sha>` on `<branch>`; Godot `<godot --version output>`; OS `<os>`
- **Date:** YYYY-MM-DD
- **Who ran it:** agent | owner

## Command
```
<the exact command line, copy-pasteable>
```

## Raw output
```
<pasted output, trimmed only at the start or end, with "[… N lines trimmed …]" markers>
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| … | … | GA §n / SCORECARD §n / ARCHITECTURE §13 |

## Result
| Metric | Measured | In band? |
|---|---|---|

## Interpretation
<What it means, what it doesn't prove, and what the owner should decide, if anything.>
```

**Rules** (see [`../../CLAUDE.md`](../../CLAUDE.md), "Evidence honesty"):
- `NOT YET RUN` is a legal status. Write it rather than invent a result.
- Agents never fill owner-only fields (playtest answers, "feels good", hardware results on the owner's machine).
  Mark them `OWNER ONLY` and leave them empty.
- No placeholders that look like data (`a1b2c3d4`, `TBD ms`, round made-up numbers).
- Every number comes from the raw output on the same page.

## 4. Decision row (for `LOCKED_DECISIONS.md` change log)

```markdown
| YYYY-MM-DD | EI-nn / PD-nn (and docs touched) | <the new decision, one or two sentences> | <owner request, or evidence link for an EI> | Owner |
```

## 5. Patch notes: `docs/patch-notes/vX.Y.Z.md` (and `.es.md`)

```markdown
# {{TITLE}} vX.Y.Z — <Update name>
_YYYY-MM-DD_ · <one-sentence summary>

## New Features
### <Feature>
<2–4 sentences: what it is and why it matters.>
- <short bullet>

## Items
<one framing sentence>
- **<Item>:** <old> → <new>.

## Enemies
## Combat
## Floors
## User Interface
## Bug Fixes
```

- Short and direct, readable in two minutes. Leave out sections with nothing in them.
- The Spanish file has the same structure, written in natural Spanish (not word-for-word).
- In-game copies are built into `data/patch_notes/*.tres` by a script, because exports drop `*.md`.

## 6. Session handoff (PR body or the last PROGRESS History line)

```markdown
## vX.Y.Z Step N handoff
- **Branch / head:** `<branch>` @ `<sha>` (pushed: yes/no)
- **Done:** <player-facing outcomes, one line each>
- **Tests:** `<command>` → <N passed, 0 failed> (or "not run: docs only")
- **Evidence:** <links>
- **Goldens changed:** None | <list, also in PROGRESS>
- **Next:** <the next step and its first action>
- **Blockers / owner questions:** None | <list>
```
