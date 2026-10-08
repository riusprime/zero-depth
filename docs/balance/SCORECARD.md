# Balance scorecard

What "balanced" means for this game, how each part is measured, and how sims may and may not be used. The
metrics follow the five pillars and report sections of the audit framework
([`../design/ROGUELIKE_AUDIT_FRAMEWORK.md`](../design/ROGUELIKE_AUDIT_FRAMEWORK.md)). Bands come from the gap
analysis report (GA §1–3) unless another source is named. Every number here is a
**target band**, not a measurement. Measurements live in each version's `evidence/`.

## 1. Rules for using sims

Deathventory's sims kept win rates in band while the owner found the game "too easy". Some simulated deaths were
simulator mistakes ([`../LESSONS.md`](../LESSONS.md) L20). So:

1. **Sims are for mechanics, exploits and relative strength.** Use them for chain safety, loops, caps, which
   archetype is ahead, which pickup dominates, and whether the generator's offers arrive.
2. **Sims set numbers, not direction.** They can say "bleed clears Room 4 in <N> s at the average preset". They
   can't say whether that's fun.
3. **A failed gate goes to the owner.** Never retune blind to pass a band, and never widen a band. Report the
   numbers, propose options, and let the owner decide ([`../process/OWNER_GATES.md`](../process/OWNER_GATES.md)
   §4).
4. **Distributions, not averages.** Report medians, p10/p90 and win rates with 95% Wilson intervals.
5. **Paired seeds.** When comparing two variants, run them on identical `map` and `loot` seeds.
6. **One family at a time.** Change one family of numbers per sim round (enemy HP, item values, threat, rewards),
   and name it in the evidence.

## 2. Metrics

| ID | Metric | Definition | Band | P |
|---|---|---|---|---|
| M-CAUSE | Readable damage | Share of the player's `DAMAGE` events whose root is a telegraphed attack, a visible projectile, a visible field or a shown status | 100% | P0 |
| M-LIMIT | Chain safety | `LIMIT` events per run | 0 | P0 |
| M-GAP | Archetype parity | Win rate of each archetype's specialist policy compared with the best | GA §1–3 | P0 |
| M-WIN | Win rate | Per policy and skill preset, per floor and per run | GA §1–3 | P1 |
| M-ENGINE | Engine by Room 4 | Share of seeds where the reward schedule has offered a compatible engine payoff by Room 4 | ≥ 90% (v0.3.0 gate) | P0 |
| M-DROUGHT | Reward drought | Longest run of rooms without a build-relevant offer | ≤ 2 (PD-07) | P1 |
| M-PICK | Pickup dominance | Pick rate of each item when offered, per archetype | No item universally dominant (GA §1–3) | P0 |
| M-DEAD | Dead starters | Each starter's win rate and pick-through rate | No dead starter (GA §1–3) | P0 |
| M-TTK | Time to kill | Seconds to kill each enemy type, per archetype and floor | GA §1–3 | P1 |
| M-ENC | Encounter length | Seconds per encounter, median and p90, by floor | GA §1–3 | P1 |
| M-FLOOR | Floor length | Minutes per floor | 10–15 (v0.3.0 gate) | P0 |
| M-RUN | Run length | Minutes per run | median 35–45 (PD-03); every full run 30–60 (v0.5.0) | P1 |
| M-THREAT | Threat trade | Win rate and reward value against the T chosen | Win rate falls as T rises; rewards make choosing T worth it (GA: threat) | P1 |
| M-CAP | Cap pressure | Requested vs applied heal, barrier and refund amounts | Reported every version; bands from GA: caps | P1 |
| M-STRESS | Stress matrix | §4 rules hold | All rules | P0 |
| M-HAZARD | Biome fairness | Difference in a floor's death rate between biomes | ≤ 10 percentage points (v0.7.0 gate) | P0 |
| M-BENCH | Sim cost | Tick cost in the bench | stress scene: mean ≤ 2 ms, p99 ≤ 4 ms; reference encounter: ≥ 15× real time ([`../architecture/ARCHITECTURE.md`](../architecture/ARCHITECTURE.md) §13) | P0 |
| M-MORT | Floor mortality | Share of deaths per floor and per room index, by archetype (framework §1) | Reported every version; bands from GA §1–3 | P1 |
| M-POWER | Power curve | Damage per second and effective HP, by room index, per archetype (framework §1, §3) | No plateau longer than GA §3 allows, and no vertical spike | P1 |
| M-SYNERGY | Synergy density | Share of a build's damage or mitigation that comes from multiplicative item interactions rather than additive stats (framework §2) | Rises with stacks for every engine (GA §2) | P1 |
| M-LOOP | Degenerate loops | Any resource spend that returns ≥ its cost, found by `exploit:<case>` bots and the chain fuzz (framework §2) | 0 | P0 |
| M-DIVERGE | Build divergence | First room where each specialist's behaviour (positioning, ability use, picks) separates from the generalist's (framework §3) | By Room 3–4 (framework pillar 3) | P0 |
| M-GENERALIST | Generalist trap | Win rate of the unbiased `competent` policy compared with the best specialist (framework pillar 3) | The generalist is below the best specialist | P1 |

**P0** cells are exit-gate material: a P0 miss blocks the version's exit gate until the owner decides. **P1** cells
are reported every version and discussed with the owner when they drift.

Every cell must be fillable from a reproducible command by v0.5.0 (that is its exit gate). The command is §7.

## 3. Bot policies

Bots produce an `InputFrame` per tick, exactly like the player
([`../architecture/SIM_CONTRACTS.md`](../architecture/SIM_CONTRACTS.md) §3), so every bot run can be replayed.
Policies are adapted from Deathventory's registry (`scripts/balance/sim/policy_registry.gd`).

The framework names four playstyles: Aggro/Burst, Control/Attrition, Combo/Engine and Generalist. The policies
map onto them like this:
- `bleed` is Aggro/Burst;
- `guard` is Control/Attrition;
- a Combo/Engine specialist arrives with its engine;
- `competent` is the Generalist.

| Policy | Plays like | Reward choices |
|---|---|---|
| `idle` | Stands still; a floor reference | — |
| `novice` | Moves toward enemies, fires often, dodges rarely | Random |
| `competent` | Kites, keeps distance, dodges telegraphs, uses its utility | Best score, no build bias |
| `bleed` | `competent` movement | Biased toward the bleed engine |
| `guard` | `competent` movement, guard-forward | Biased toward the guard engine |
| other archetype specialists | added as each engine lands | Biased to that engine |
| `exploit:<case>` | Scripted to look for one exploit (a proc loop, cap abuse, a doorway cheese) | — |

**Skill knobs** (every policy takes them; presets combine them):

| Knob | Meaning | Presets (**starting values**: novice / average / expert) |
|---|---|---|
| `reaction_ticks` | Delay before reacting to a new telegraph | 24 / 14 / 8 |
| `aim_error_deg` | Standard deviation of aim error, drawn from the bot's own `ai` stream | 10 / 5 / 2 |
| `dodge_permille` | Chance to dodge a telegraph it has reacted to | 300 / 650 / 900 |
| `greed` | How much it weighs threat rewards against risk | 0.2 / 0.5 / 0.8 |

Skill presets are calibrated against owner and human-session recordings from v0.6.0 onward. Until then they are
starting values, and every result names the preset it used.

## 4. Enemy × archetype stress matrix

Each enemy is tagged for each archetype engine:
- **S, stresses:** it makes that engine work hard, but the engine can answer it;
- **D, drains:** it shuts that engine down;
- **–:** neutral.

The matrix lives in [`../design/GAME_BLUEPRINT.md`](../design/GAME_BLUEPRINT.md) §E, and `EnemyDefinition.stress_tags`
carries the same information.

**Rules** (checked by `tests/content/test_stress_matrix.gd` from v0.3.0, and confirmed by sims):
- every archetype is stressed (**S**) by at least one enemy on each floor;
- no archetype is drained (**D**) by every enemy;
- no enemy drains more than one archetype.

Why: in Deathventory the weakest archetype was drained by 6 enemy mechanics, while the strongest faced none aimed
at its engine (DV `docs/roadmap/v0.9.5/ROGUELIKE_GAP_ANALYSIS.md` §4.1).

## 5. Evidence format

Use the evidence template ([`../process/TEMPLATES.md`](../process/TEMPLATES.md) §3), plus these extras:
- **v0.5.0 SCD (2026-10-08):** the scorecard command (§7) is the command for every cell. Its run record is
  `scorecard_run.v1` (§7: the fields below plus rooms, picks, TTK, bouts, caps and damage by effect, ints and strings
  only); its `timings.tsv` keeps wall time out of the JSON, and `scorecard.md` is the summary. `run_sim.gd` below was
  never built.
- **Command:** `godot --headless --path . -s scripts/sim/run_sim.gd -- policy=<p> skill=<preset> seeds=1..N
  floor=<f> run_id=<id> out=docs/roadmap/vX.Y.Z/evidence/<id>/`
- **Outputs:**
  - `runs.jsonl`: one record per run, keys sorted, ints/strings/bools/null only;
  - `timings.tsv`: wall-clock time, kept out of the JSON so records stay byte-reproducible;
  - `SUMMARY.md`: tables per policy with win rate and Wilson intervals.
- **Run record** (`schema: "run.v1"`):
  - **identity:** `sim_version`, `content_hash`, `seed`, `policy`, `skill`;
  - **outcome:** `result`, `floor_reached`, `death` (`{tick, floor, room, source_id, attack_id, kind}`);
  - **encounters**, one entry each: `{id, ticks, damage_taken, damage_dealt_by_effect, kills, limit_events,
    cap_requested, cap_applied}`;
  - **rewards:** `offers` (`[{room, items, picked}]`), `engine_online_room`, `threat` (`[{room, t}]`).
- **Sample size:** at least 20 seeds per cell for a direction, and 100 or more before a P0 verdict, unless the
  owner agrees otherwise.

## 6. Gap-analysis reports

At three milestones the lead writes a **Roguelike Gap Analysis Report** for this game, in the audit framework's
five-section format:
1. the executive balance and archetype scorecard;
2. engine health and the item synergy matrix;
3. progression pacing and build crystallization;
4. encounter counterplay and stress-testing;
5. actionable redesign specifications.

The milestones are:
- v0.3.0, as input to the production decision;
- v0.6.0, balance alpha;
- v0.8.0, content beta.

Each report goes in that version's `evidence/GAP_ANALYSIS.md`. Every number in it comes from a reproducible
command, with the evidence template's honesty rules. Its redesign specifications are proposals: the owner
approves them row by row, as a G1 audit ([`../process/OWNER_GATES.md`](../process/OWNER_GATES.md) §2), before
anything is built. Deathventory's v0.9.5 gap analysis was written this way.

## 7. Filling every cell (v0.5.0 SCD, 2026-10-08)

One command fills every §2 cell (v0.5.0 exit gate, PLAN R7):

```bash
godot --headless --path . -s scripts/sims/scorecard.gd                 # full mode: evidence
godot --headless --path . -s scripts/sims/scorecard.gd -- --quick      # quick mode: well-formed cells, not bands
```

- **Arguments:** `seeds=N` or `seeds=A..B` (seed k plays run seed 20261000 + k), `policies=a,b,…`, `floors=3`,
  `floor_ticks=90000` (a floor longer than 25 min is a timeout), `jobs=4` (worker processes), `--no-bench`,
  `--fresh` (replay records already on disk), `out=<dir>`.
- **Full mode:** the 22 policy rows of `ScoreSuite.FULL_POLICIES` × seeds 1..20, 3 floors, then the bench
  (`scripts/bench/sim_bench.gd`, all scenes, after the sims). **Quick mode:** 11 rows × 2 seeds, 30 s of floor 1, the
  bench's reference scene. `tests/unit/scorecard/test_scorecard.gd` runs a smaller quick set in process and checks
  that all 23 cells are produced and well-formed (not that bands pass).
- **Outputs** (under `build/`, never `docs/`): `build/scorecard/<sha>/scorecard.json` (every cell:
  `{id, band, status, value, note}`, keys sorted, no wall time), `scorecard.md` (the table and each cell's value),
  `runs/<task>.json` (one `scorecard_run.v1` record per run), `timings.tsv` (wall time per run, the sims and the bench),
  `bench.json`. Finished records are kept, so a rerun after a restart plays only what is missing. The evidence file
  is written by hand from these.
- **Status:** `met` / `missed` against the band as written; `no band yet` where the band is an open design question
  (the old `GA §1–3`, `GA: caps`, `GA §3`); `no data` when the sample holds nothing to measure (for example no bot
  finished a run); `NOT YET RUN` with the reason.
- **Policies** (`tests/support/score_bot.gd`; §3): `idle`, `novice`, `competent` (also at the novice and expert
  presets), `competent+t` (takes every Overrun room), the specialists `element`, `ordnance` and `guard` on each build
  (Blade/Gun × ability focus: `element` = Combo/Engine through Arc Field, Frost Nova, Flame Trail and the fire, shock
  and frost mods; `ordnance` = Aggro/Burst through Bomb Lobber, Drone Buddy, Orbit Blades and the ability mods;
  `guard` = Control/Attrition through the Aegis, the guard mods and the armour, max HP and regen cards; §3's `guard`
  is this one; no `bleed` bot until the bleed engine has an ability), and `exploit:salvage`, `exploit:chain`. Every
  policy on a seed draws from the same `score_bot` stream and plays the same map and loot seeds (§1.5). `greed` is
  recorded but drives nothing yet (the Overrun choice is the `+t` policy).

**Mappings onto this game** (the definitions above predate continuous-spawn floors; these are lead calls the owner
may change, also written in each cell's `note`):

| Metric | How it is measured here |
|---|---|
| "Room N" (M-ENGINE, M-DIVERGE, M-MORT, M-POWER, M-DROUGHT) | The N-th distinct room the player walks into on a floor, the start hall being Room 0; `g` counts rooms over the whole run (start halls excluded) |
| M-ENC | An encounter is a combat bout (a living enemy within 12 m; gaps under 3 s merged) or a boss fight (door sealed to the boss's death); there is no fixed encounter list |
| M-ENGINE | Runs (competent + specialists) that reached floor 1's Room 4; an engine card is Arc Field, Frost Nova, Flame Trail or a mod tagged fire, shock, bleed, frost, guard or heat, offered at an altar, chest or shop opened in Rooms 0–4 |
| M-DROUGHT | A room is build-relevant when a card offered in it is an ability or a mod (competent) or of the specialist's focus |
| M-DEAD | Starters are the two builds; pick-through needs human picks: `NOT YET RUN` until v0.6.0's recordings |
| M-THREAT | No threat number T on this base: T is the Overrun room (the first T branch), `competent` (T = 0) against `competent+t` on the same seeds |
| M-STRESS | `EnemyDefinition.stress_tags` (S only; no D tag exists) against the kinds the runs met on each floor; the tags name the v0.2.0 engines (bleed, guard), so the untagged `element` and `ordnance` archetypes fail rule 1 until tagged |
| M-LIMIT | Every LIMIT event of non-exploit runs, split by effect: the chain watchdog and the Vampiric Core cap clip both emit LIMIT |
| M-LOOP | `exploit:salvage` (buy each shop card and sell it straight back; a loop returns ≥ its cost) and `exploit:chain` (every named combo's items from the start; a watchdog LIMIT counts). Not yet scripted: the gamble shrine's shard gain, doorway cheese, Overrun farming |
| M-SYNERGY | Damage from engine statuses, payoffs and combos (`ScoreCells.ENGINE_EFFECTS`) as a share of the floor's damage, by the engine's stacks at the floor's end; "rises" means strictly |
| M-WIN | Bands are open (GA §1–3); the status checks only v0.4.0 PLAN TU's starting band (competent dies on floor 1 in < 30 % of runs) |
| M-FLOOR / M-RUN | Floors and runs a bot finished; the bot explores every room, takes what it can afford, shops, farms for unaffordable chests and goes to the boss after 15 min at most (`explore_budget_used_up` counts floors that hit that cap) |
| M-BENCH | The bench's own bands; its timings are the only non-reproducible cell |
