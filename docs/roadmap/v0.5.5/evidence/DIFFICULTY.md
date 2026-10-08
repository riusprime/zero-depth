# DIFFICULTY: does Step DS (D3–D8, D10, S5, B1) build, and do its mechanics hold?

- **Status:** RUN. Full suite: **1134/1135, 1 FAILED** (`test_e2e_heal_orbs`, which fails the same way on the base
  `85084e9` without this step: see below). Export smoke: passed. Balance, difficulty and feel: **OWNER ONLY** (no
  bot sims or band tests, owner P1: every number below is a starting value, not a measurement).
- **Build:** `f5113bb` on `worktree-agent-a8bbb38795d359772` (with `claude/lucid-fermat-9wv2tf` at `85084e9`, v0.5.9
  "Embers", merged in); Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v80`. The step commit on top
  of it changes only these docs.
- **Date:** 2026-10-08
- **Who ran it:** agent

## What changed (player-facing)
| Row | Change (starting values) | Where |
|---|---|---|
| D4 (D3, D5, D10, B1) | **Hidden catch-up.** At each floor entry the build's power P (weapon level × damage × Glass Cannon × Onrush × expected crit ÷ base crit × attack speed × (1 + 0.12 per non-weapon ability level + 0.08 per item + 0.15 per combo); never how you play) is compared with E = 1.0 / 2.0 / 4.0 on floors 1/2/3: m = clamp(√(P/E), 1, cap), cap = ×1.5 / ×2 / ×2.5 + 0.25 per threat T. Every arriving enemy: HP × m, damage × √m. Fixed for the floor, hashed, saved; not shown to the player (dev panel only) | `CatchUp`, `data/scaling/catch_up.tres`, `World.catch_up` |
| D6, D7 | **Bosses**: their own m when they spawn, against E at the floor's end (2.0 / 4.0 / 7.0) with the boss cap ×2 / ×3 / ×4 + 0.25 per T; HP × m, attacks × √m. **Phase gates** on all six bosses at 66 % and 33 %: a burst stops at the gate; a 1 s invulnerable transition (violet shell, "PHASE SHIFT" / "CAMBIO DE FASE" on the bar) that deals no damage; 2–4 adds of the floor's mix rise around the boss (floor 1: 2, 2; floor 2: 2, 3; floor 3: 3, 4); then the phase's entry attack. Phase 2 = v0.4.0's phase two; phase 3 adds the punish move to the rotation, cooldowns ×0.75, speed ×1.1. Floor-1 boss-room heal unchanged | `BossGates`, `data/bosses/*.tres` |
| S5 | **Deep floors bite**: the violet haze layered on the biome's v0.5.9 mood (fog, ambient, sun, void pulled toward violet); an elite in every combat room (the first pack in each room); +1 T (already in `Curses.threat`; verified) which raises both caps; the epic altar on the free spot nearest the boss door; a Deep-only event, **Whispering Deep** / **Abismo susurrante** (Listen to the voice: an epic stat card for a random curse; Feed it your blood: 30 % HP for a mod), drawn first on every Deep floor with an event room and never on a normal one | `StageView`, `SpawnDirector.deep_elite`, `Routes.end_first`, `data/events/whispering_deep.tres` |
| D8 | The principle in the blueprint: "a normal build feels strong but challenged; a lucky build past the cap feels like a god" | `GAME_BLUEPRINT.md` §H |

Choice made by the agent, for the owner to confirm: the "guaranteed epic chest at the floor's end" is the existing
free, curse-free **epic altar**, moved next to the boss door (not a priced chest).

## Command
```
bash /tmp/claude-0/vd.sh /home/user/zero-depth/.claude/worktrees/agent-a8bbb38795d359772 ds
```

(import, `gdformat --check` + `gdlint`, then `bash scripts/verify.sh`: the full GUT suite and `check_gut_log.sh`.)

## Raw output (`/tmp/claude-0/vd_ds.clean.log`)
```
verify exit 1
Tests              1135
Passing Tests      1134
Failing Tests         1

res://tests/e2e/test_e2e_heal_orbs.gd
* test_a_kill_drops_a_heal_orb_and_walking_onto_it_heals
    [Failed]:  with the card a kill dropped a heal orb
      at line 69
0/1 passed.
...
Asserts           1236607/1236608
Time              1860.363s
```

The failure is not this step's: with `src data locale tests` checked out at `85084e9` (the branch before DS) the
same test fails the same way:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_heal_orbs.gd -gexit
    [Failed]:  with the card a kill dropped a heal orb
Passing Tests      none
Failing Tests         1
```
(EC's Lifesprout e2e after the v0.5.9 merge; left for the lead / EC, not touched here.)

## Export smoke
```
cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content validates inside the pack (0 errors)
  ok    manifest hash d6e957ddcb51 matches the project's
  ok    Spanish translation is loaded
  ...
0 miss(es)
export exit 0
```

## Tests added (mechanics only)
- `tests/unit/sim/test_catch_up.gd` (11): P = 1000 fresh; P from a forced loadout = 2680 by hand; the capped
  square root; floor 2's m at entry and the cap +0.25 per T (Deep: 2250); m fixed for the floor; arrival HP × m and
  power × √m; the boss's own m and cap (floor 1: ×2; floor 3 after two Deep floors: ×4.5); m hashed and a save
  round-trips it with equal hashes; untouched without the table; no reader or view sees it.
- `tests/unit/sim/test_boss_gates.gd` (6): all six bosses gate at 66 / 33 with a harder last phase; a burst stops
  at each gate and the gate can't be hurt; the gate deals no damage, emits its event and lasts about a second; the
  dev Kill boss passes; adds 2/2, 2/3, 3/4 on floors 1/2/3 from the floor's mix, rising with the spawn-in; none
  without spawning.
- `tests/unit/sim/test_deep_bite.gd` (6), `tests/unit/presentation/test_deep_look.gd` (3),
  `tests/e2e/test_e2e_difficulty.gd` (1: through `main.tscn` with real input, a strong build via the dev panel, the
  boss's m and gates, the HUD shows nothing, floor 2 Deep with its m, cap, haze and event).

## Tests changed on purpose
- Boss kills in tests made with `Damage.hit(…, 999999, 1, 1, …)` (the player's burst) now use owner 0 (the world's
  hit, like the dev panel's Kill boss), since a player's burst now stops at the gate: `test_run_flow`,
  `test_after_boss`, `test_heal_orbs`, `test_routes`, `test_bosses`, `test_world_snapshot`, `test_portal_transit`,
  `test_routes_view`, `test_portal_transit_view`, `test_boss_views` (its 900-damage hit now stops at 66 %).
- Phase-two tests step through the gate first (`BossLab.through_gate`): `test_bosses`, `test_bosses_2`,
  `test_boss_challenge` (the closing-arena test holds the boss staggered again after the gate).
- Nine events, not eight: `test_event_validation`, `test_event_views`.

## Goldens
None changed: the replay golden and the export-smoke world hash (`e5365ddb6dcb`) are the kernel's and still match.
