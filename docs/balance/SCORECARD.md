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

Every cell must be fillable from a reproducible command by v0.5.0 (that is its exit gate).

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

v0.4.0 TU builds the first whole-run bot, `tests/support/run_bot.gd` ("expected build": `competent`-style movement,
best-score picks, the reaction and dodge knobs below), run by `scripts/sim/tuning_sim.gd`
(`docs/roadmap/v0.4.0/evidence/TUNING.md`); the `run.v1` record and `run_sim.gd` above are still to come.

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
