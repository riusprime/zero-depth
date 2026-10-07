# Roadmap

> **Status (2026-10-07):** **Active version: v0.3.5 "Feedback pass"** ([plan](v0.3.5/PLAN.md)), the owner's notes
> on the v0.3.0 "Three Floors" finishing build ([plan](v0.3.0/PLAN.md), built and played). Next: v0.4.0 "Run Depth"
> with the owner's build direction ([plan](v0.4.0/PLAN.md)). Earlier: v0.2.0, v0.1.0 and v0.0.1 built and played;
> the bench's stress miss is still open.

This is the development guide for the game: how a session picks the work up, how versions are numbered and
released, what each version must prove, and who checks it. Gates replace dates. A version ends when its exit gate
passes, not on a calendar.

---

## 0. How to pick this up (read first)

1. Read [`../../CLAUDE.md`](../../CLAUDE.md), then this whole file.
2. Find the **active version** in the status line above and in §4. Open `docs/roadmap/vX.Y.Z/`.
   - **No folder yet:** you are that version's lead. Do Phase 0 (§0.2).
   - **Folder exists:** read `PLAN.md`, then `PROGRESS.md`. Take the first step that isn't in the Done table and
     isn't blocked by a gate.
3. Work on a session branch cut from `origin/main`. Commit the PLAN first if you wrote it.

### 0.1 Roles

- **One Claude lead per version.** The lead owns the PLAN, the code, the tests, the evidence, the goldens and the
  release.
- **Subagents** are only for read-only investigations (tracing an owner line to code, auditing a family of
  content) and for reviews of a finished diff. They never commit.
- Deathventory's first phase used a 54-task DAG (55 after a remediation task) with exclusive file leases and many worker sessions. It produced
  fabricated playtest and smoke evidence (DV-920, DV-930), and its leases left work unwired (the tooltip in
  CX-30). Deathventory moved to a solo lead from v0.2.0, and that's the model here
  ([`../LESSONS.md`](../LESSONS.md) L1, L2).

### 0.2 The per-version loop

1. **Owner brief or feedback arrives.** Phase 0: audit the **live code** (not the docs) for everything it
   touches.
2. **Read-only investigations** trace each owner line to `file:line`.
3. **Write `vX.Y.Z/PLAN.md` and commit it first** ([`../process/TEMPLATES.md`](../process/TEMPLATES.md) §1). It
   has these sections:
   - Context;
   - Every owner line → where it lands;
   - Steps, each marked *sim + tests + sims* or *presentation only*;
   - Open items;
   - Verification.
4. **Gates before anything that isn't a direct fix** ([`../process/OWNER_GATES.md`](../process/OWNER_GATES.md)):
   - G1 audits, approved row by row;
   - G2 mockups (2–3 per screen; the owner picks);
   - design questions.
5. **Steps, one commit each:** `vX.Y.Z Step N: <player-facing outcome>`. Update `PROGRESS.md` with:
   - the Done table, with SHAs;
   - Goldens changed on purpose;
   - Gates;
   - Open;
   - Blockers.
6. **Evidence** goes in `vX.Y.Z/evidence/*.md`: the question, the build SHA, the exact command, the raw output,
   the target bands and an interpretation.
7. **Release step** (checklist §0.4).
8. **PR, CI green, merge.**
9. **Owner playtest** on the real Windows export from CI. The feedback opens the `.5` pass or the next version.

### 0.3 The playtest rule

**No minor version starts until the owner has playtested the previous one.** Deathventory built v0.3.0 → v0.5.0
back to back and tested at the end. Its planned v0.2.5, v0.3.5 and v0.4.5 balance passes never shipped
([`../LESSONS.md`](../LESSONS.md) L10).

While a playtest is pending, the lead may still do presentation work, art, tooling, tests and docs for the
current version. Those changes ship as patch versions.

### 0.4 Release checklist

- [ ] Every PLAN step is in the Done table, or moved to Open with the owner's agreement.
- [ ] Full suite, export smoke, hitch probe and goldens pass on the release commit (CI green).
- [ ] `tests/MIN_TEST_COUNT` raised to the new passing count.
- [ ] Version bumped in `project.godot` (the single source). The version test confirms `export_presets.cfg`
  matches.
- [ ] Patch notes in `docs/patch-notes/vX.Y.Z.md` (English) and `vX.Y.Z.es.md` (Spanish). README index row added.
  In-game What's New copies rebuilt.
- [ ] Spanish strings for every new key, with the locale coverage test green.
- [ ] Screenshot tour run in en and es; output linked in evidence.
- [ ] §4 row status and the History entry below updated.
- [ ] README status line updated. CLAUDE.md re-read and corrected if anything it says is no longer true.
- [ ] `PLAYTEST.md` written for the owner ([`../process/OWNER_GATES.md`](../process/OWNER_GATES.md) §5).

### 0.5 Testing before a push

See [`../architecture/TEST_MATRIX.md`](../architecture/TEST_MATRIX.md) §5. In short:
- **docs only:** nothing locally;
- **assets:** the asset tests;
- **code, data, tests or project files:** the full suite.

CI runs everything on every PR.

### 0.6 Session continuity

- **Hitting a session limit or handing off:**
  1. Commit work in progress with a message starting `WIP:` and push it.
  2. Add a dated line to PROGRESS History saying what's done, what's next, and any blocker.
- Never leave uncommitted work.
- Decisions are written into the PLAN, PROGRESS or LOCKED_DECISIONS the same day. Never leave them only in chat.

---

## 1. Owner brief (2026-10-06)

- **The game:** a real-time action roguelike. The player has smooth movement and aim, a primary attack, a utility
  skill and a dash. Item **engines** (bleed, guard and others) change how a run plays. Threat rises only through
  the player's choices.
- **The look:** low-poly isometric 3D. A white cube with a cyan core is the player, red cubes are enemies, slabs
  and rocks are cover, and there are four biome palettes ([`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md)).
- **Design source:** *Roguelike Gap Analysis & Initial Development Roadmap v0.1*
  ([`../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md`](../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md); the report is pending)
  and its audit framework, the five design pillars
  ([`../design/ROGUELIKE_AUDIT_FRAMEWORK.md`](../design/ROGUELIKE_AUDIT_FRAMEWORK.md)). Both are organized into
  [`../design/GAME_BLUEPRINT.md`](../design/GAME_BLUEPRINT.md).
- **Owner decisions:**
  - **Engine:** Godot 4 in 3D with a fixed orthographic iso camera. The sim is a flat 2D plane.
  - **Floors:** procedural. Three biomes ship first; more are added during balancing, before the game is content
    complete.
  - **Platform:** Windows, with mouse+keyboard and twin-stick gamepad parity from day one.
  - **Kickoff deliverable:** a starter doc kit (this repo's first commit). The kit:
    - copies Deathventory's process that worked;
    - turns every Deathventory lesson into a rule;
    - rebuilds the architecture as a deterministic real-time sim behind a 3D view.

## 2. Versioning and patch notes

- **Numbering:**
  - A new minor version (`v0.2.0`) adds mechanics or content milestones and ends with an owner playtest.
  - `.5` (`v0.2.5`) is the owner-feedback pass on that minor version.
  - Other patch digits (`v0.2.1`) are presentation, art, fixes and tooling, which may ship while a playtest is
    pending.
- **Single source:** `application/config/version` in `project.godot`, read through `GameVersion`.
  `export_presets.cfg` `file_version`/`product_version` must equal it plus `.0`; a test checks this. The main menu
  shows the version.
- **Patch notes:** `docs/patch-notes/vX.Y.Z.md` and `.es.md`, plus the README index, from v0.0.1. The format is in
  [`../process/TEMPLATES.md`](../process/TEMPLATES.md) §5.

## 3. Authority and superseded rules

The authority order is in [`../../CLAUDE.md`](../../CLAUDE.md). When an owner decision replaces an earlier rule,
add a row here and a change-log row in
[`../architecture/LOCKED_DECISIONS.md`](../architecture/LOCKED_DECISIONS.md):

| Old rule | Source | New rule | Date / version |
|---|---|---|---|
| — | — | Nothing superseded yet | — |

---

## 4. Roadmap overview

Each version maps to a milestone (M0–M6) from the gap analysis (GA: milestones). M4 is split here into M4a and
M4b. Exit gates name who checks each item:
- **test:** automated, in CI;
- **bench / sims:** measured, with an evidence file;
- **owner:** the owner personally;
- **humans:** other players, run by the owner.

| Version | Name | Milestone | Scope | Exit gate (who checks) | Status |
|---|---|---|---|---|---|
| **v0.0.1** | Ground Plane | M0 | Project scaffold and layers. GUT and CI (verify, export smoke, hitch probe, Windows golden and export, lint). Sim kernel: tick, `InputFrame`, entities, collision grid, RNG streams, hasher, event log. `sim_bench`. The player cube moves, aims and dashes with mouse+keyboard and gamepad on an iso stage, with interpolation. Renderer and occlusion proof scenes. `InputMap` and a remap store. Settings store. `tr()` with `strings.csv` en/es and a TTF font. Version single source and patch notes. Credits and license stub. Dev panel stub. `ContentScanner` | CI green, including export smoke (**test**). Replay hash stable over 10k ticks and identical on ubuntu and windows (**test**). Bench within budget (**bench**). Renderer picked (**owner**, on their GPU). The owner moves the cube with both devices on a Windows export (**owner**) | Built; owner gates pending. CI, replay cross-OS: met. Bench: reference met, stress **missed** |
| **v0.1.0** | Combat Lab | M1 | One arena. Primary, utility (guard / mobile skill) and dash. Charger, Warden and Needle with telegraphs. Hit feel: hit-stop as sim freeze ticks, flash, shake toggle. Death and restart. Provenance events. Options screen: audio, display, remap, shake, reduced motion, colour-blind modes. Placeholder SFX hooks with captions. e2e real-input tests | No damage without a readable cause (**test** + **owner**). `sim_bench` with real enemy AI stays within budget (**bench**). **Fun without loot (owner)** | Active |
| **v0.2.0** | Engine Kernel | M2 | Effect queue; data-driven triggers, conditions and payoffs. Statuses: bleed, slow, stagger. Barrier and sustain caps, proc coefficients, the ancestry guard. 8–12 items. Dev panel: forced loadouts, exact stacks, seed, event-chain inspector, replay. Run recorder JSONL. Bot policies and encounter sims | The bleed engine and the guard engine both work (**test**). Chain and resource-loop tests pass (**test**). Both engines clear the reference encounters within bands (**sims**) | — |
| **v0.3.0** | Three Floors | M3+M4a | (Owner-directed 2026-10-07, [`v0.3.0/PLAN.md`](v0.3.0/PLAN.md).) A full run: 3 floors in random biome order (Ruins, Night Rocks, Red Canyon), each ending in a sealed boss room; bosses from per-floor pools (Gatekeeper, Brood Mother, Siege Engine) with stagger and phases; the portal works. Shards economy; 2–3 free altars and 2–3 chests per floor, pick 1 of 3. Engines (burn, shock, bleed, frost, guard) and 8 named combos; 24 items. Wall thickness and blink by range; more generation variety. Pause, run recap. Later in the version: Options (G2), SFX hooks, bench with real AI, readable-cause test | A full run is playable start to finish on Windows (**owner**). Every boss is beatable by two different builds (**test** + **owner**). Generation property tests over 1,000 seeds (**test**) | Built and played by the owner (2026-10-07); feedback → v0.3.5 |
| v0.3.5 | Feedback pass | — | The owner's feedback on the v0.3.0 finishing build (F1–F22, [`v0.3.5/PLAN.md`](v0.3.5/PLAN.md)): Vent and Skill buttons, slower dash, smarter bosses and enemies, Arc Caster and Bomb Drone, calmer HUD and cards, minimap fix, portal animations | **Owner** | Active |
| **v0.4.0** | Run Depth | M4a | (Owner-directed 2026-10-07, [`v0.4.0/PLAN.md`](v0.4.0/PLAN.md).) Four ability slots (the starting weapon + abilities such as bombs, a drone, orbit blades, blink), stat cards with crit that compound, enemy scaling and hordes just below the player's growth, crowd performance. More bosses in each pool. 12 enemy behaviours. Saves at every room entry plus save on close: quitting mid-room resumes at that room's entry. Threat T branches (Overrun rooms) | Generation property tests over 1,000 seeds (**test**). Save/resume round trip with equal hashes (**test**). A full run (**owner**) | — |
| **v0.5.0** | Roads Between | M4b | Shops and events, cursed rewards, salvage, optional routes. **A 40–50 card candidate pool** (abilities, stat cards, mods; moved from v0.6.0 by the owner, 2026-10-07). A full run of 30–60 minutes. All scorecard data collected | Every scorecard cell can be filled from reproducible commands (**sims** + **test**) | — |
| v0.5.5 | Feedback pass | — | | **Owner** | — |
| **v0.6.0** | Balance Alpha | M5 | A paired-seed sim program. 8–12 human sessions run by the owner. Revisions. Pruning the 40–50 card pool built in v0.5.0. The slot-cap decision (PD-08). A gap-analysis report ([`../balance/SCORECARD.md`](../balance/SCORECARD.md) §6) | No archetype is excluded, no pickup is universally dominant, no starter is dead (**sims** + **humans**) | — |
| **v0.7.0** | New Ground | balance | 4th biome, Frozen Shore (water edges and ice props), plus any others the owner picks. Added as balance and variety tests of the generator | No biome shifts a floor's death hazard by more than 10 percentage points (**sims**) | — |
| **v0.8.0** | Content Beta | M6 | 60–80 items if the evidence justifies them. A second kit or character. Meta unlocks (alternatives, information, cosmetics). A journal/codex. The final visual and audio language. Full onboarding | New content adds variety without reopening any P0 failure (**sims** + **owner**) | — |
| v0.9.x | Launch line | — | Final credits and licenses, local achievements, an accessibility pass, a Steam build, trailer moments | The owner's launch list (**owner**) | — |

- A minor version starts only after the previous one's playtest (§0.3).
- A `.5` pass takes priority whenever owner feedback arrives.
- "P0 failure" means a failed exit gate from v0.1.0–v0.6.0, or a scorecard band marked P0 in
  [`../balance/SCORECARD.md`](../balance/SCORECARD.md).

## 5. Scheduled early, because Deathventory added them late

| Feature | Here | In Deathventory |
|---|---|---|
| Localization (`tr()`, en + es, a real font) | v0.0.1 | v0.9.6 |
| Version single source and patch notes | v0.0.1 | v0.2.0 |
| Credits and license notice | v0.0.1 | v0.9.6 |
| Export smoke in CI | v0.0.1 | v0.9.6 |
| Dev panel | v0.0.1 (stub) | v0.5.5 |
| Options and remapping | v0.1.0 (store from v0.0.1) | v0.5.7 |
| Colour-blind modes | v0.1.0 | v0.9.6 |
| Reduced motion | v0.1.0 | v0.8.2 |
| Onboarding hints | v0.3.0 | v0.9.6 |
| App icon | v0.3.0 | v0.9.6 |
| Autosave | v0.4.0 | v0.9.6 |

## 6. Non-goals

- Multiplayer, crafting, persistent stat trees, a mod editor, ten characters (PD-12).
- **An Endless mode before balance alpha.** Deathventory redesigned its Endless scaling three times
  ([`../LESSONS.md`](../LESSONS.md) L8).
- Time pressure: a global clock or enrage timers (PD-05).
- Balancing only by raising enemy HP.
- Replacing owner playtests or human sessions with sims.
- Godot physics in the sim, or a height axis in gameplay.

## 7. Definition of success

| Version | Success means |
|---|---|
| v0.0.1 | The cube moves, aims and dashes well on both devices on a Windows build. Every CI guard is live. The kernel is deterministic across operating systems and within budget |
| v0.1.0 | One arena with three enemies is fun with no items at all, and every hit taken is readable |
| v0.2.0 | Two opposite engines (bleed, guard) exist in data, chain safely, and win in sims |
| v0.3.0 | One 10–15 minute floor gives a build identity by Room 4, and the production decision says go |
| v0.4.0–v0.5.0 | A full 30–60 minute run is complete, savable and fully measured |
| v0.6.0 | Balance alpha passes its three tests with sims and humans |
| v0.8.0 | Content beta adds variety without breaking v0.6.0's results |

---

## History

- 2026-10-06 — Starter doc kit written from the Deathventory retrospective and the owner's decisions of
  2026-10-06. v0.0.1 is planned and not started.
- 2026-10-06 — v0.0.1 "Ground Plane" built, Steps 0–13 (83 tests). Replay golden identical on Linux and Windows.
  Bench: reference scene 31.2× real time (met); stress scene mean 3.457 ms / p99 5.988 ms against 2 / 4 ms
  (**missed**, reported, not retuned). Waiting on: the renderer, pitch and occlusion picks, the player-kit values,
  O3 (`main`), O4 (credit line) and the owner's Windows playtest. No PR to `main` until O3.
- 2026-10-06 — The owner played v0.0.1 (too bare to judge) and answered v0.1.0's design questions. v0.1.0
  "Combat Lab" is active, fight first.
