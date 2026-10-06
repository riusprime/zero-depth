# Owner gates

The owner (Rius) decides what the game is. The lead builds it and proves it. This file defines the formats for
every point where the owner decides. They come from Deathventory's later versions:
- the owner-lines table first appeared in its v0.6.0 PLAN;
- the G1 and G2 gates first appeared in its v0.9.5 PLAN (`COMBOS.md`) and v0.9.6 PLAN (`EMBER_AUDIT.md`).

That loop worked, and it is kept here unchanged ([`../LESSONS.md`](../LESSONS.md) L11).

**The rule:** anything that isn't a direct fix is decided by the owner **before** it's built. A direct fix is a bug
with a clear root cause and only one sensible correction.

## 1. Owner lines table

Every owner message that asks for changes becomes a table in the version's PLAN, **one row per point**, before any
code changes:

| # | Owner line | Decision | Step |
|---|---|---|---|
| L1 | the owner's words, verbatim or very close | the decision, or "**Decide:** G1/G2/Q3" | the PLAN step that lands it |

- Feedback written in Spanish is translated in the table and the original is kept in a `<details>` block below
  it.
- No point is dropped silently. "No change, by owner decision" is a valid decision and gets a row.
- Read-only investigations trace each line to code (`file:line`) before the decision column is filled in.

## 2. Gate G1: audit list

Use G1 when the owner asks about a whole family ("check every item", "these combos feel useless").

- **Write** `docs/roadmap/vX.Y.Z/<NAME>_AUDIT.md` with:
  - the owner's request, quoted;
  - how the thing works today, with `file:line` references;
  - a table with one row per item:

    | Item | What it does today | Real impact (numbers or sim) | Verdict | Proposal (ID) |
    |---|---|---|---|---|
    | … | … | … | Dead / Niche / Fine / Duplicate | **A1:** … / Keep |

- **Ask** the owner to approve row by row ("A1 yes, A2 no, A3 with change …").
- **Record** the answers in a "Decisions (owner, date)" table at the bottom, with a "Built in" column filled in as
  the work lands.
- **Nothing in the audit is built before the answers arrive.**

## 3. Gate G2: mockups

Use G2 for every new screen and every screen redesign.

- **Make** 2–3 mockups per screen with `scripts/shots/mock_<screen>.gd`, using real data from a fixed seed. Make
  them in English and in Spanish, at 1920×1080.
- **Share** them as screenshots labelled A / B / C, with one line on each one's trade-off.
- **Owner picks** one per screen, or asks for a mix. Record the pick in PROGRESS "Gates".
- **Build** only the picked version. List any art it needs in that version's art requests
  ([`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md) §6).

## 4. Design questions

Use a design question when a rule has more than one reasonable answer, for example a cooldown length or how two
effects combine. Ask in batches, each question numbered, with options and a recommendation:

```markdown
**Q3. Does bleed stack in duration or in damage?**
- (a) Duration: each application adds 1 s; damage per tick is fixed. Simple to read; weaker scaling.
- (b) Damage: each stack adds damage per tick; duration refreshes. Stronger engine; needs a cap. ← recommended,
  because the bleed engine needs a multiplying source (L6)
- (c) Both, with a cap of N stacks.
```

The answers go into PLAN ("Owner decisions") the same day, and into `LOCKED_DECISIONS.md` if they change a PD.
**Decisions never live only in chat.**

## 5. Owner playtests

A version ends with a playtest on a **real Windows export**. CI uploads the build as an artifact. No version may
follow another without one ([`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) §0). Presentation and art work can
continue while the playtest is pending.

- **Before:** the lead writes `docs/roadmap/vX.Y.Z/PLAYTEST.md`, which holds:
  - how to get the build (the CI artifact link);
  - what's new, as a 30-second read;
  - 3–6 questions, taken from the version's exit gate ([`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) §4);
  - a free-notes section.
- **Questions are about experience,** for example "Did you know why you took damage each time?", "Could you
  explain your build after Room 4?", "Which fight felt longest?"
- **After:** the owner's answers go into `PLAYTEST.md` under "Owner answers (date)", **written by the owner or
  pasted verbatim from their message**. Agents never write or paraphrase them as if they were the owner's, and
  never fill them in ahead of time (L1).
- The owner's feedback then becomes the next PLAN's owner-lines table. That PLAN is the `.5` pass, or the next
  minor version if the owner says so.

## 6. Human sessions (balance alpha)

v0.6.0 calls for 8–12 sessions with other players, run by the owner.
- The lead prepares a session sheet: build, seed policy, what to watch, and a 5-question exit survey.
- The run recorder JSONL from each session is collected as evidence.
- Results from people are entered only from the owner's notes. Each row says who entered it.

## 7. What the owner verifies personally

These can't be proven by an agent, so they are marked **OWNER ONLY** in evidence:
- "fun without loot" (v0.1.0) and similar feel judgements;
- renderer and performance on the owner's own GPU;
- moving with both devices on the Windows export;
- the camera pitch and palette picks;
- launch readiness.
