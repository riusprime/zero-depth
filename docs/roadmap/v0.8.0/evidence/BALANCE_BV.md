# BALANCE_BV: does the balance pass give developing builds, with exceptional builds in roughly 10–20 % of runs?

Owner line O91 ([`../BALANCE_PASS.md`](../BALANCE_PASS.md) "BV: validation"). Owner's words: "Measure actual offers,
purchases and rerolls; weights are not run-completion probabilities. Initial target: exceptional builds in roughly
10–20% of representative completed normal-route runs, usually assembled late; early jackpots much rarer. Treat this as
a playtest target. … Track damage, projectile rate, proc rate and time-to-kill; distinguish 60 projectiles/sec from
60 weapon casts/sec. Audit CatchUp.power after changing stat semantics; hidden enemy scaling must not cancel earned
synergy. … Use seeded reward sampling plus scripted fights, then report what still requires human playtesting."

- **Status:** NOT YET RUN
- **Build:** — (filled from `git rev-parse HEAD` when run) on `v080-bv` (from FL's WIP `0f2b1322`; it carries MR, RM
  and FL, not SG); Godot — ; OS —
- **Date:** —
- **Who ran it:** —

## Status

| Check | Status |
|---|---|
| `gdformat --check` + `gdlint` on the new files | passed locally (phase 1) |
| Godot import, `tests/unit/application/test_balance_tools.gd` | NOT YET RUN |
| `scripts/checks/loot_sample.gd -- seeds=200 weapon=both` | NOT YET RUN |
| `scripts/checks/build_fights.gd -- seconds=20` | NOT YET RUN |
| `scripts/checks/build_fights.gd -- from_loot=build/loot_wands.txt` | NOT YET RUN |
| CatchUp P and m before / after SG (the same tool on a tree with SG merged) | NOT YET RUN (SG is on `v080-sg`, not in this base) |
| Replay goldens, old-save fixtures, the every-card × every-slot smoke, launch caps, one horde perf probe | NOT YET RUN (the lead's seams / GitHub's full suite) |
| What only the owner can say (below) | OWNER ONLY |

## The tools and their model

- `scripts/checks/loot_sample.gd` over `tests/support/loot_sampler.gd` (`LootSampler`): each seed is a real run built
  floor by floor through `FloorPlan` (as Main builds it: the carry, slots 4 → 6 → 8, the catch-up, the shop's
  cadence, the events, `data/rewards/pacing.tres`, the floor-1 guarantee and the jackpots). Normal route only. Per
  floor: every altar and chest the floor placed (rolled and taken through `Offers.roll` / `Rewards._take`), every
  event pedestal placed (`Events.roll` / `Events.take`; fights and defences taken as won), the shop on its cadence
  (`Shop.restock` / `Shop.buy` / `Shop.reroll`), the boss's altar with every pick it gives.
  - **Assumptions, not measurements:** `income=200` shards added at each floor's entry (kills are not simulated; the
    economy is unchanged; the carry keeps the run's shard share); `cores=1` elite core stolen a floor
    (`CoreTheft.draw_card`); at most `rerolls=2` shop rerolls, only when no unsold card fits; the shop buys pick
    ranks ≤ `shop_rank=3`. Not modelled: Overrun's and ambushes' extra rewards, boss cores, Marked's card, the gamble
    shrine, Deep floors, deaths (every sampled run completes its normal route).
  - **The pick** (deterministic, both weapons): a held wand card's level-up first, then a new wand card that
    `LootPacing.compatible` accepts / a mutation / the weapon's level, then a trigger, then a stat card or another
    ability, then a passive; a new wand card with the slots full is passed over (no swap).
- `scripts/checks/build_fights.gd` over `tests/support/build_fight.gd` (`BuildFight`): the Playground's room, the hero
  unhurtable; a pack of 12 dummies (Charger floor-1 HP, a dead one back at its spot 1 s later; the reference fight)
  and a single boss dummy (the first boss table's floor-1 HP). The Gun holds Shoot at the nearest dummy and stands;
  the Blade presses Primary and walks at the nearest one; Dodge Imprint's build dashes every 1.5 s. Projectiles a
  second (new player projectile ids) and weapon casts a second (Gun: `shot_cd` set; Blade: a new `swing_root`) are
  counted apart; procs a second are status applications + remnant activations + child hits (HIT at depth ≥ 1).
  CatchUp: P, the floor's m and the boss's m on floors 1–3 for the loadout, and the boss dummy's time to kill × the
  boss's m (what the hidden scaling leaves of the gain).
- **Exceptional** (BALANCE_PASS.md): a sampled build's pack-fight DPS ≥ 2.5 × the median of the same weapon, loop and
  floor.
- **Determinism:** each tool runs its first case twice and compares `World.state_hash()` (MATCH / MISMATCH).

## 1. Seeded reward sampling

### Command
```
godot --headless --path . -s scripts/checks/loot_sample.gd -- seeds=200 weapon=both
```

### Raw output
```
NOT YET RUN
```

### Target bands
| Metric | Target | Source |
|---|---|---|
| Floor 1: a compatible modifier in the first two regular rewards | always (the guarantee) | O91 pacing table; BALANCE_PASS.md "FL" |
| Early jackpots (floor 1) | "much rarer" than late ones | O91 |
| Mutations on floor 1 | "exceptionally rare" | O91 pacing table |
| Determinism | MATCH | EI-05 |

### Result
| Metric | Measured | In band? |
|---|---|---|
| Offers, purchases, rerolls per floor | NOT YET RUN | — |
| Jackpots seen / taken, floor 1 vs floors 2–3 | NOT YET RUN | — |
| Mutations seen / taken per floor | NOT YET RUN | — |
| Wand card levels at each floor's end | NOT YET RUN | — |
| CatchUp P and m per floor (sampled builds) | NOT YET RUN | — |
| Determinism | NOT YET RUN | — |

## 2. Scripted fights of the named builds

### Command
```
godot --headless --path . -s scripts/checks/build_fights.gd -- seconds=20
```

### Raw output
```
NOT YET RUN
```

### Target bands
| Metric | Target | Source |
|---|---|---|
| Twin / Echo / attack speed | "viable without dominating most runs" (no number set) | O91 |
| Projectiles a second vs casts a second | reported apart | O91 |
| Hidden scaling vs earned synergy | the boss dummy's time to kill × m still falls as the build grows | O91; BALANCE_PASS.md "SG" 6 |
| Determinism | MATCH | EI-05 |

### Result
| Metric | Measured | In band? |
|---|---|---|
| DPS (pack, boss) per archetype, levels 1 and 3 | NOT YET RUN | — |
| Projectiles/s, casts/s, procs/s | NOT YET RUN | — |
| Time to kill (pack, boss) | NOT YET RUN | — |
| Peak projectiles, LIMIT events | NOT YET RUN | — |
| CatchUp P, m, boss m on floors 1–3; boss TTK × m | NOT YET RUN | — |
| Determinism | NOT YET RUN | — |

## 3. The sampled builds' fights (the exceptional share)

### Command
```
godot --headless --path . -s scripts/checks/build_fights.gd -- from_loot=build/loot_wands.txt seconds=6
```

### Raw output
```
NOT YET RUN
```

### Target bands
| Metric | Target | Source |
|---|---|---|
| Exceptional builds at a completed normal route's end (floor 3) | roughly 10–20 % (a playtest target) | O91 |
| Assembled late | most floor-3 exceptional builds not yet exceptional at floor 1 or 2 | O91 |
| Early jackpots among exceptional builds | rare | O91 |

### Result
| Metric | Measured | In band? |
|---|---|---|
| Exceptional share at floor 3 (Blade, Gun) | NOT YET RUN | — |
| Exceptional share at floors 1 and 2 | NOT YET RUN | — |
| Of those, with a jackpot / an early card | NOT YET RUN | — |
| Already exceptional at floor 1 or 2 | NOT YET RUN | — |

## Interpretation

NOT YET RUN.

What the numbers cannot prove: the sampled runs never fight, so a build's power never changes which rooms are cleared
or which shards are earned; the shard income is an assumption; the reference fight is a still dummy pack (no
movement, no dodging, no enemy pressure), so builds that pay off under movement (Onrush) or against moving crowds read
low here and should be checked in play.

## OWNER ONLY

| Question | Answer |
|---|---|
| Does a build develop over a run (floor 1 identity → floor 3 complete)? | OWNER ONLY |
| Do Twin, Echo and attack speed still feel good? | OWNER ONLY |
| How rare do jackpots feel in play? | OWNER ONLY |
| Are the remnants (Faultline, Gravity Stitch, Stress Mark, Grand Finale, Threadline) readable in a fight? | OWNER ONLY |
