# v0.4.0 — progress

Plan: [`PLAN.md`](PLAN.md). Branch: `claude/lucid-fermat-9wv2tf` (no `main` yet: O3). Starts when v0.3.5 wave 1 is
merged.

## Owner decisions (2026-10-07)
- The build direction F7–F11, F13 (verbatim in `../v0.3.0/PLAYTEST_RUN_2.md`).

## Done
| Step | What (player-facing) | Commit |
|---|---|---|
| — | Plan | this commit |
| BS | Four ability slots (slot 1 = Combo Sword / Pulse Gun; Bomb Lobber, Drone Buddy, Orbit Blades, Blink with a landing shock, Aegis as cards; full slots level up to L5); no utility at the start (F11); 12 stat cards × 3 rarities and crit (5 %, ×1.5, `crit` stream); altars and chests offer abilities, stat cards and the items as mods; the shrine pays into the same stats; ability HUD, card faces, damage numbers (crits big and yellow), bombs / drones / blades / shock in the world; dev panel grants abilities. Evidence: [`evidence/BUILD_SYSTEM.md`](evidence/BUILD_SYSTEM.md) | `7a4a453` + this commit |

## Goldens changed on purpose
- none (BS: the replay golden passes unchanged; the new hash block is added only once a slot, a stat card or a crit
  chance is in play, which the kernel worlds never have. The export smoke, `scripts/ci/export_smoke.sh`, was not run
  locally: CI covers it)

## Gates (owner)
| Gate | Asked | Answer | Date |
|---|---|---|---|
| Q1 Echoes / Core theft / Depth descent in the new direction | 2026-10-07 | pending | |
| Q2 v0.5.0 before a v0.4.0 playtest | 2026-10-07 | "skip the rule, keep going to v0.5.0" | 2026-10-07 |

## Open
- O3 `main`; O4 credit line.
- ~~BS: EI-05 still lists four streams~~ — updated with the owner's OK (2026-10-07).
  An EI text change needs the owner: confirm the two names join the list.
- BS deferred (PLAN levels table): Aegis L5 "reflects bolts"; Pulse Gun L3 "+1 pierce" shares the Hot bolt's single
  pierce (a Hot L3 bolt still pierces once). Attack speed shortens a swing's recovery and the shot/drone periods, not
  a swing's wind-up. Regen cards heal in and out of combat (the PLAN doesn't say; the old regen stays out of combat).
- BS: `scripts/shots/vfx_cards.gd` still sets the removed utility pick in its profile (it no longer gets Blink); not
  run in CI.

## Blockers
- none

## History
- 2026-10-07 — BS: build system built and verified on `7a4a453` (743 / 743, lint clean); final commit adds the
  evidence and this file. Owner note mid-step ("spell cooldowns have to be a bit bigger"): the ability slots are 52 px
  with a sweep and seconds left; their frames follow `CardStyle.current`.
- 2026-10-07 — PLAN drafted from the owner's direction while v0.3.5 wave 1 runs.
- 2026-10-07 — Owner: "skip the rule, keep going to v0.5.0". ROADMAP §0.3 waived once: v0.5.0 follows v0.4.0
  without a v0.4.0 playtest; both are played together afterwards.
- 2026-10-07 — Owner: "okay let's bove the bigger card pool to v0.5 and make it in this current development sprint". The
  40–50 card pool (ROADMAP v0.6.0 → v0.5.0) runs as step CP in wave 3, after BS.
- 2026-10-07 — Owner on the altar mix (43 % ability cards while a slot is free): "ill test it after"; on EI-05: "change the
  locked rule yea" → EI-05 lists `crit` and `ability` (and the `ai:enemy` sub-stream).
- 2026-10-07 — BS merged on top of v0.3.5 (keep-both conflicts in world, debug API, dev panel, strings, SIM_CONTRACTS,
  LOCKED_DECISIONS). 777 tests pass; goldens unchanged.
