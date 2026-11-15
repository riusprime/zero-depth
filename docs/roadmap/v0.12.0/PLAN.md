# v0.12.0 — Bosses you learn: mechanics and one signature per boss (plan, DRAFT 2026-11-14)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).
The design, row by row: [`BOSS_BRIEF.md`](BOSS_BRIEF.md). The owner's words:
[`feedback/ZeroDepth_Boss_Brief_2026-11-14.md`](feedback/ZeroDepth_Boss_Brief_2026-11-14.md).

## Context
- `main` holds v0.11.0 + v0.11.1 (PR riusprime/zero-depth#11, merged, `feedd802`; `config/version` still reads
  `0.10.5`: v0.11.0's bump was waiting on the owner). The bosses' skeleton animations (v0.11.1 steps 63–73) are in
  it; nobody has watched them in the game yet.
- The owner played v0.11 on 2026-11-09 and 2026-11-11 (ROADMAP §0.3). On 2026-11-14 they spoke the boss brief that
  v0.11.0's steps O6–O8 were waiting for, then asked for signature mechanics, then chose "v0.12.0" for this work.
- Owner rule: anything that isn't a direct fix is decided before it's built. The brief's rows are the gate (a G1
  list approved row by row). The owner's own rows (`CJ`, `TW`, `TC`) are decided by being theirs; the signatures
  (`SG`) are approved in kind ("Yes, go on"); the lead's rows for the other bosses (`WL`, `SE`, `FO`, `HL`) are
  **not approved yet** and are asked again when each boss's step starts.
- Phase 0 was two read-only surveys of the live boss code (BOSS_BRIEF §2). The sim and data are the same on `main`
  as at the survey's `e53b3e15` (checked: only `world_reader.gd` and `native/src/zd_avatar.cpp` differ, both for the
  animations).

## Every owner line → where it lands
| # | Owner line (verbatim or close) | Decision | Step |
|---|---|---|---|
| B1 | "more like a World of Warcraft kind of fight … doing something in exchange of something, or doing something so you don't receive damage, as we did with the pillars" | One "do X" mechanic per phase per reworked boss | all |
| B2 | "I want all bosses to have things that restrict the area where you could walk through" | BQ2, lead's default (a): the reworked bosses get one; Gatekeeper and Lantern Shade stay without. Supersedes RQ3 (2026-11-09) for those bosses | 2, 4, 6, 11 |
| B3 | "have the player die sometime at them … you would have to die maybe once … not like Hades 2" | A missed signature costs about 40 % of max HP, never a kill from full. Judged by the owner per boss (`OWNER ONLY`) | all |
| B4–B5 | "I need you to help me rework the other ones too … They don't need to repeat mechanics" | BOSS_BRIEF §4, asked per boss | 8–11 |
| B6 | "The rock boss is okay. The broad mother is also okay for now … the hive boss … kind of okay, but we have to go a little bit over it" | Gatekeeper, Brood Mother: no change. Hive Lens: light pass | 11 |
| B7 | "Phase 1 and 2 of the Hollow Crown are already pretty neat … rethink how phase 3 works" | Owner, 2026-11-14: "Remembers your run" (HC-A) + SG-HC | 7 |
| CJ1–CJ5 | The Clockwork Judge (Time Wave, three orbs, slow fields, blocked paths) | As the brief's rows. Owner, BQ4: "25 per orb" | 1–3 |
| TC1–TC6 | The Tidecaller (stronger pull, four strips, the soak) | As the brief's rows | 4–5 |
| TW1–TW8 | The Twin Wardens (no chain, fast Amber, Mirror Ward, the charge into the ward) | As the brief's rows. Owner, BQ7: "One pool, 3 bars" | 6 |
| S1 | "missing some signature mechanics that make it difficult and rememberable" | BOSS_BRIEF §5b, one per boss; owner: "Yes, go on" | with each boss |
| V1 | Which version: "v0.12.0" | This plan, branch `claude/v0120`. v0.11.0's O6–O8 are closed as moved here | 0 |
| V2 | "push it locally, i'll test all the bosses at the same time, then after playtest we decide if they are ready for main at github" (2026-11-14, after the Judge was built) | Nothing goes to GitHub until the owner has played. Every boss is built before the playtest, not one at a time: the lead's rows WL, SE, FO, HL and every SG row are built as written in BOSS_BRIEF (the lead's reading: the owner judges them by playing, and can throw any out then). "Locally" is read as: commits stay on `claude/v0120` on this PC | all |

Still the lead's defaults, not the owner's words (the owner can change any; each is marked in BOSS_BRIEF
"Decisions"): BQ1 (Lantern Shade unchanged), BQ2, BQ5 (the Time Wave slows the weapon, not the auto-spells), BQ6 (a
shot's clock slows with it inside a field), BQ8 (the Mirror Ward), BQ10 (floor-1 bosses keep a plain phase 1), BQ11
(the order below), BQ12's two details.

## Steps
One boss at a time; the owner plays each from the dev panel before the next starts. Every number in the brief is a
starting value.

### 0. Setup
- Branch `claude/v0120` from `origin/main` at `feedd802`. This PLAN, PROGRESS, the ROADMAP row.

### 1. The Judge's building blocks (sim + tests)
- **Rule / design:** three reusable pieces, declared in boss data: (a) a timed debuff on the player's attack speed
  with a source and a way to return part of it; (b) floor pickups a boss places and the player collects by walking
  through; (c) slow fields for the player's shots (in the script step that steers shots before the C++ sweep; read
  `NATIVE_CORE.md` first; no C++ change expected, stop and report if one is needed).
- **Tests:** unit tests per piece in `tests/unit/sim/`; determinism (same seed, same hash).
- **Reachable from the real game?** Not on its own: step 2 uses it.
- **Done when:** the three pieces pass their tests with no boss using them yet and the goldens are unchanged.

### 2. The Clockwork Judge fights with time (sim + tests + sims)
- **Rule / design:** CJ1–CJ5 and SG-CJ (Rewind). Gear walls through `World.add_barrier`.
- **Tests:** `test_boss_judge*.gd`; two bots (one collects the orbs and minds its copy, one ignores both): the
  second loses clearly more HP and is not killed outright by one miss. The Judge's e2e.
- **Reachable from the real game?** Yes: floor 5's boss pool; proved by the Judge's e2e through `main.tscn`.
- **Done when:** both bots' numbers are in evidence and the goldens that moved are named.

### 3. The Judge's fight is readable (presentation only)
- Basic Area VFX 04 registered and used for the orbs with a clock above; the golden wave; the slow fields; the gear
  walls; the pale copy; hint arrows; the attack-speed state on the HUD; strings en + es; the new attacks on the
  Judge's skeleton clips. One shot. Then the owner plays it.

### 4–5. The Tidecaller (sim + tests + sims, then presentation)
- TC1–TC6 and SG-TC. New shared piece: "inside this area or hurt" (strips and circles). The pull before/after in
  the Playground for the owner.

### 6. The Twin Wardens (sim + tests + sims, then presentation)
- TW1–TW8 and SG-TW. New shared pieces: the charge that bursts where it ends; one boss body hitting the other; the
  Mirror Ward (touches the shot sweep). The chain's removal changes O5's tests and the twin views.

### 7. The Fallen (sim + tests + sims, then presentation)
- HC-A and SG-HC. Replaces the interphases; reuses the mechanics built in steps 2–6.

### 8–11. Warlord, Siege Engine, Foundry, Hive Lens
- Each starts by asking the owner its rows (WL, SE, FO, HL and its SG row). SG-FO needs a G2 mockup of the gauge.

### R. Release
- Version bump (one source: 0.12.0; whether 0.11.x is bumped first is the owner's open item from v0.11.0), patch
  notes en + es, What's New, ROADMAP row + History, README status line, CLAUDE.md re-checked, PROGRESS final,
  PLAYTEST.md.

## Open items (what they block)
- The lead's default answers listed above: they block nothing now; the owner can change them before the step that
  uses each.
- The rows WL, SE, FO, HL: block steps 8–11 only.
- The Twins' new animations for TW2 (the owner: "with the new animations, this will be greater"): whether the
  v0.11.1 skeleton clips cover the new attacks is checked at step 6.
- A clock icon or model for the hour orbs, if the pack has none: step 3.

## Verification
- Per step: lint, the touched test folders and the e2e that reach the change. The lead runs `scripts/ci/seams.sh`
  after merging; the PR into `main` runs the full suite once.
- Per boss: two scripted bots (plays the mechanic / ignores it), numbers in `evidence/`. Goldens that pin boss
  fights change on purpose and are named in PROGRESS.
- "Difficult but learnable" (B3) is `OWNER ONLY`, per boss, then the owner's playtest of the version.

## The owner's first play of the Tidecaller (2026-11-15)

The owner's words, verbatim: "one thing i NOTICED PLAYING THE TIDES CALLER yesterday is that there is too much going
on and too frequently so it is very difficult to pay attention to everything, for example the pull and pussh happens
to often and you are pushed into balls that cant be dodged because dash is still on cooldown, and the wave dance
happens a bit too quick and somethimes where there is also a pull so it makes it ver hard, the wave dance is smaller
than the room so you can always walk out of it and ignore it, TDLR we have to space mechanics a bit a give it a good
fight rythm not everything happening at the same time, because every single player will die here".

| # | Owner line | Finding (data at `a9ba965d`) | Decision | Step |
|---|---|---|---|---|
| R1 | "too much going on and too frequently … not everything happening at the same time" | The Pull, the ring stream (a ring every 2.2 / 1.9 / 1.6 s), the crossing waves (every 3.5 s), Riptide and High Tide each run on their own clock and overlap freely | **One big mechanic at a time.** A single order of beats per phase; while a big mechanic runs (the Pull, a Riptide row, a High Tide) the ring stream and the crossing waves stop and the Tidecaller starts no other attack; at least 3 s of calm between two big mechanics | 4c |
| R2 | "the pull and pussh happens to often" | Every 8 s (`signature_every_seconds`) | Every 18 s in phase 1, every 30 s in phase 2 (it shares the cycle with Riptide) | 4c |
| R3 | "you are pushed into balls that cant be dodged because dash is still on cooldown" | Rings keep leaving the boss through the Pull and the push; the dash's cooldown is 10 s | The stream stops when the Pull's bell starts and resumes 1.5 s after the push lands; the push throws 4 m, not 6 m; no hostile shot is within 3 m of where the push sets you down (those pop) | 4c |
| R4 | "the wave dance happens a bit too quick" | 2.0 s of warning a cast (2.5 s the last), whatever the room's size | 2.5 s (3.0 s the last), and never less than the time to walk from the last safe strip to the next one plus 30 % | 4c |
| R5 | "sometimes where there is also a pull" | Nothing stops the Pull during a Riptide row | Covered by R1: never together | 4c |
| R6 | "the wave dance is smaller than the room so you can always walk out of it and ignore it" | The strips are cut from `w.bosses.arena`; to be traced: that rectangle against the room's walkable floor | The four strips cover the whole walkable floor of the boss room, wall to wall | 4c |
| R7 | "every single player will die here" | — | The owner judges again after 4c (`OWNER ONLY`). The Maelstrom's strengths are not changed in 4c; phase 3 gets the same "one at a time" order and no crossing waves | 4c |

Agent rule from the same message (owner): "just deploy 2 opus subagents at max now, no more fable subagents, you can
do some thinking and then send the request to the opus agent".
