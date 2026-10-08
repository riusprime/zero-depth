# DIFFICULTY: does Step DS (D3–D8, D10, S5, B1) build, and do its mechanics hold?

- **Status:** suite NOT YET RUN; export smoke NOT YET RUN. Balance, difficulty and feel: **OWNER ONLY** (no bot
  sims or band tests, owner P1: every number below is a starting value, not a measurement).
- **Build:** — (filled from the run below)
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

## Raw output
NOT YET RUN
