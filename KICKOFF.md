# Kickoff

How to start the first development session in this repo.

## Before you start (owner)

- [ ] **`main` exists.** The kit was committed on `claude/lucid-fermat-9wv2tf`. Merge it into `main` (or ask the
  session to push `main` from it), then set `main` as the default branch on GitHub.
- [ ] **Gap analysis pasted.** Put the full *Roguelike Gap Analysis & Initial Development Roadmap v0.1* into
  `docs/design/ROGUELIKE_GAP_ANALYSIS_v0.1.md`. Optional for v0.0.1, required before v0.1.0. You can also paste
  it into the first message and the session will commit it.
- [ ] **Reference image added** as `docs/art/reference/biomes_reference.png`. Optional; the session can't create
  it from chat.
- [ ] **Deathventory available read-only.** Start the session with both `riusprime/zero-depth` and
  `riusprime/deathventory`, or let the session add `riusprime/deathventory` itself.

## The first message (paste this)

```text
You are the lead for v0.0.1 of this game.

1. Read CLAUDE.md completely, then docs/roadmap/ROADMAP.md §0, then docs/roadmap/v0.0.1/PLAN.md and PROGRESS.md.
2. Make riusprime/deathventory available to this session READ-ONLY. Use it only to copy the PORT files listed in
   docs/architecture/ARCHITECTURE.md §12 (Step 0), and later to read the ADAPT files when a step needs them.
   Never push, branch, comment or open PRs there.
3. Execute docs/roadmap/v0.0.1/PLAN.md from Step 0, one commit per step ("v0.0.1 Step N: <outcome>"),
   updating PROGRESS.md after each step. Follow the testing-before-a-push table in CLAUDE.md.
4. Stop and ask me at each owner gate in the PLAN: renderer pick, camera pitch, occlusion technique, and the
   Windows check. Keep building the steps those gates don't block.
5. Evidence honesty: never write a result you didn't produce. NOT YET RUN is fine. Owner-only fields stay empty.
6. If you hit a session limit, commit WIP, push, and add a dated History line to PROGRESS.md.
```

## Later sessions

The prompt is shorter, because the pickup protocol lives in the repo:

```text
Read CLAUDE.md and continue the active version from docs/roadmap/ROADMAP.md §0.
```

For a new version after an owner playtest, paste the feedback after that line. The lead turns it into the next
PLAN's owner-lines table before building anything.
