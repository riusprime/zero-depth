# Game blueprint

The game's design, organized so it can be built in the order of [`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md).
The design sources are:
- the owner's *Roguelike Gap Analysis & Initial Development Roadmap v0.1*
  ([`ROGUELIKE_GAP_ANALYSIS_v0.1.md`](ROGUELIKE_GAP_ANALYSIS_v0.1.md), "GA"; the report itself is pending);
- its audit framework, the five design pillars
  ([`ROGUELIKE_AUDIT_FRAMEWORK.md`](ROGUELIKE_AUDIT_FRAMEWORK.md)), committed verbatim.

- **This file reorganizes the GA; it doesn't restate its numbers.** It cites them as `GA §n`, or as `GA: <topic>`,
  which the GA file's citation map resolves to a section.
- **Numbers written out here** are either owner decisions recorded in
  [`../architecture/LOCKED_DECISIONS.md`](../architecture/LOCKED_DECISIONS.md) (PD-xx), or exit-gate targets from
  the roadmap.
- **Where a section says "from GA",** the version that builds it reads the GA in its Phase 0 and fills the table
  here, in the same commit as its PLAN.

This file shares rank 2 of the authority order with LOCKED_DECISIONS ([`../../CLAUDE.md`](../../CLAUDE.md)).
Changing a design rule here goes through the owner, like a PD flip.

---

## A. Definition

**Pitch.** A real-time action roguelike in low-poly isometric 3D. You move and aim freely, and fight with a
primary attack, one utility skill (guard or a mobile skill) and a dash. Items are **engines**: each is a trigger, a
condition and a payoff, and together they change *how you act* within a few rooms. Danger rises only when you
choose it.

**Pillars:**
1. **A run changes how you act.** By Room 4 your build has an identity you can name, and it changes what you do
   with your hands: where you stand, when you dash, what you hit first.
2. **Readable chaos.** Fights get busy, but every hit you take has a cause you could see coming: a telegraph, a
   projectile, a field or a status.
3. **Every archetype finishes the fight.** Each engine (bleed, guard, and the ones that follow) has a renewable,
   scaling payoff from its first item, and no engine is the only way to win.

**How the pillars cover the audit framework's five:**

| Framework pillar | Where this design answers it |
|---|---|
| 1. Engine building vs. flat stats | Pillar 1; §D (Trigger → Condition → Payoff, the plain-support limit, no flat per-hit reduction) |
| 2. Polar archetypes (aggro vs. control) | Pillar 3; §D (bleed vs. guard as the first two engines); scorecard M-GAP |
| 3. Compressed progression; build identity by Room 3–4; punish the generalist | Pillar 1; §B (reward schedule); scorecard M-DIVERGE, M-ENGINE, M-GENERALIST; run length 30–60 min |
| 4. Encounters as engine stress tests | Pillar 3; §E (stress matrix); scorecard §4. The framework's "false difficulty" examples are banned by PD-05 (no enrage timers) and pillar 2 (no unavoidable chip damage: M-CAUSE) |
| 5. Meaningful choice and non-dominance | §D (interaction matrix); scorecard M-PICK, M-DEAD; the G1 audits in [`../process/OWNER_GATES.md`](../process/OWNER_GATES.md) |

**Design filter:** *Does this create a more interesting decision in motion? If mostly no, remove it.* This is
adapted from Deathventory's rule that "the backpack question controls scope" (its hard lock 20). A feature that
only adds numbers, menus or breadth fails the filter.

## B. Core loop and run structure

- **Room loop:** enter → fight one or more waves → room clears → reward (when the schedule gives one) → choose a
  door.
- **Floor:** a room graph with a main path of **7–9 mandatory encounters**, **1–3 optional branches** and a
  **boss** (PD-03). Fork doors show their threat cost and their reward before you choose.
- **Run:** **3 floors**. Each run draws its biomes from the unlocked pool without repeats. Biome never sets
  difficulty; the floor index does (PD-04). Median run length is **35–45 minutes** (PD-03).
- **Reward schedule** (PD-07):
  - a starter after Room 1;
  - a guaranteed compatible payoff after Room 3;
  - a fallback offer in Room 4 if no engine has formed;
  - never more than 2 rooms in a row without a build-relevant offer.

  The exact pools and weights are from GA: rewards.
- **Threat T** (PD-05). T rises only when the player chooses it: an optional branch, a cursed reward, a threat
  door. There is no global clock and no enrage timer. What T changes is in §H.
- **Death** ends the run. A recap shows the killing cause, the build and the timeline (v0.3.0).

## C. Player kit

| Verb | What it is | Numbers |
|---|---|---|
| Move | Screen-relative, 8-way on keys and analog on a stick; the sim reads −127..127 per axis | GA §5 |
| Aim | Mouse ray to the ground plane, or the right stick. Aim assist on the pad only (about a 12° cone) | GA §5; GA: input |
| Primary | **Melee and shooting on separate buttons** (owner, 2026-10-07): melee = a four-slash combo (owner, 2026-10-07, v0.3.0 L11: a horizontal slash, a backhand, a narrow forward thrust, a heavy spinning finisher; replaced the 3-hit swing combo); shooting = hold for continuous low-damage bolts (replaced the 2026-10-06 charged shot) | v0.1.0 PLAN L9–L10; v0.3.0 PLAN L11 (starting values) |
| Utility (one, chosen before the run, PD-01) | **Guard:** a directional defensive state (hits from the front cut to 20%). **Or a mobile skill: Blink**, a short teleport the way you're moving, through walls (owner, 2026-10-07) | v0.1.0 PLAN (starting values) |
| Dash | Short and fast, on a cooldown. Its distance, cooldown and any invulnerability window are from GA | GA §5 |

**Starting values in use.** These are tuning defaults that no source has given yet. Each one is replaced by the GA
value or by an owner decision, and the change is noted here.

| File | Field | Value | Status |
|---|---|---|---|
| `data/player/runner.tres` | `hp` | 100 | Starting value (v0.0.1); the owner tunes it |
| `data/player/runner.tres` | `radius_m` | 0.35 m | Starting value (v0.0.1) |
| `data/player/runner.tres` | `move_speed_mps` | 6.0 m/s | Starting value (v0.0.1); owner Windows check |
| `src/content/defs/dash_definition.gd` (defaults) | `distance_m` | 4.0 m | Starting value (v0.0.1); owner Windows check |
| same | `duration_seconds` | 0.15 s (9 ticks) | Starting value (v0.0.1) |
| same | `cooldown_seconds` | 1.4 s (84 ticks) | Owner F12 (v0.3.5 K; was 0.8 s, v0.0.1). The kernel goldens keep 0.8 s |
| same | `iframes_seconds` | 0.15 s (the whole dash) | Starting value (v0.1.0) |
| v0.1.0 primary, guard, blink, enemies | all fields | see [`../roadmap/v0.1.0/PLAN.md`](../roadmap/v0.1.0/PLAN.md) "Design" | Starting values (v0.1.0); the owner tunes them |

`PlayerTable.starting_values()` (the kernel tests' copy) must equal the compiled data; a content test checks this.

**Feel rules** (engineering, [`../architecture/SIM_CONTRACTS.md`](../architecture/SIM_CONTRACTS.md) §3):
- a tap shorter than one frame is never lost;
- presses buffer for 6 ticks;
- the aim reticle is drawn from the live cursor every frame.

## D. Items and engines

- **Every item is Trigger → Condition → Payoff**, except at most **4 plain-support items in a 24-item pool**
  (GA: items; enforced by the content validator).
- **An engine** is a set of items whose payoff is **renewable** (it comes back every fight or every few seconds)
  and **scales** (more stacks or more partners make it multiply, not just add). Every archetype gets one from its
  first item ([`../LESSONS.md`](../LESSONS.md) L6, L7).
- **The first two engines** (v0.2.0) are **bleed** (aggro) and **guard** (control), chosen to pull in opposite
  directions: bleed rewards pressure and repeated hits; guard rewards holding ground and answering attacks.
- **The slice: 12 item roles** (v0.3.0), from GA: items. The v0.2.0 lead fills this table in its PLAN commit:

  | # | Role | Engine | Trigger | Condition | Payoff | Scales by |
  |---|---|---|---|---|---|---|
  | 1–12 | from GA: items | | | | | |

- **Interaction matrix.** `docs/design/INTERACTIONS.md` (created in v0.2.0) is a table of item × item. Each cell
  says *synergy*, *anti-synergy* or *none*, with one line on why. A new item must add at least one synergy cell
  for its engine.
- **Rules on loops** (enforced in the sim; [`../architecture/SIM_CONTRACTS.md`](../architecture/SIM_CONTRACTS.md)
  §7–§8):
  - each item effect fires at most once per root chain;
  - an effect never re-triggers itself (ancestry);
  - internal cooldowns are in ticks;
  - children carry the parent's proc times their own;
  - damage-over-time never procs on-hit effects;
  - sustain (heal, barrier, refunds) is capped per window (GA: caps);
  - a watchdog stops any chain past its limits, and sims require 0 `LIMIT` events.
- **No flat per-hit damage reduction**, on either side. Reductions are per-mille multipliers or structural (block,
  guard arc, dodge).
- **Slot cap** (PD-08): 6 mechanism slots plus a 3-slot reserve, behind a flag from v0.4.0. Kept or dropped at
  balance alpha (GA: slots).

## E. Enemies and the stress matrix

**The six slice behaviours.** The names are fixed; each behaviour's spec is decided by the owner in the Phase 0 of
the version that builds it. `MIN_TELEGRAPH_TICKS = 24` (0.4 s; owner, 2026-10-06). Numbers: the v0.1.0 PLAN.

| Enemy | First in | Behaviour and attacks | Telegraph |
|---|---|---|---|
| Charger | v0.1.0 | Runs at you; locks a straight lane, charges along it, then is dazed (the punish window) | Lane, 0.6 s |
| Warden | v0.1.0 | Slow and tanky; armoured in front (−20 % damage) and soft behind (+10 %), so flanking pays; slams the ground around itself | Circle, 0.8 s |
| Needle | v0.1.0 | Keeps its distance; fires a 3-bolt burst down a locked aim line; backs off when you close in | Line, 0.5 s |
| Disruptor | v0.3.0 | from GA: enemies | ≥ `MIN_TELEGRAPH_TICKS` |
| Splitter | v0.3.0 | from GA: enemies | ≥ `MIN_TELEGRAPH_TICKS` |
| Anchor | v0.3.0 | from GA: enemies | ≥ `MIN_TELEGRAPH_TICKS` |

**Alpha adds 6 more behaviours** (12 in total, v0.4.0). They are named here as **roles only**. Each must:
- stress at least one archetype that the first six stress least;
- add a movement or spacing problem the first six don't pose.

Their names and specs are decided in v0.4.0 Phase 0.

**Stress matrix** (S = stresses the engine, D = drains it, – = neutral). The rules are in
[`../balance/SCORECARD.md`](../balance/SCORECARD.md) §4.

| Enemy | Bleed (aggro) | Guard (control) | (next engine) |
|---|---|---|---|
| Charger | from GA | from GA | |
| Warden | from GA | from GA | |
| Needle | from GA | from GA | |
| Disruptor | from GA | from GA | |
| Splitter | from GA | from GA | |
| Anchor | from GA | from GA | |

## F. Bosses

- **Boss 1** (v0.3.0) has three movements: **pursuit**, **lanes** and **recovery**. Recovery is the punish
  window.
  - **Stagger:** a meter fills from hits. When full, the boss is staggered for a fixed window and the meter resets.
    The meter size and decay are from GA: boss.
  - **Phases** start at HP thresholds (`BossDefinition.phases`).
  - Every boss attack is telegraphed like any other.
  - The boss must be beatable by both v0.2.0 engines within the scorecard bands.
- **Bosses 2–3** (v0.4.0): roles from GA: boss, decided in v0.4.0 Phase 0. Each tests a different engine harder
  than boss 1 does, without draining any.

## G. Procedural floors

- **Room graph:** see §B. The generator is specified in
  [`../architecture/ARCHITECTURE.md`](../architecture/ARCHITECTURE.md) §9.
- **Room size budget:** 1–1.5 screens at the chosen camera framing. Rare set-piece rooms may be larger.
- **Templates:** authored as scenes with markers (entries, exits, spawn slots, cover slots), then baked
  ([`../architecture/CONTENT_SCHEMA.md`](../architecture/CONTENT_SCHEMA.md) §5).
  - Seeded variation picks the template, fills a subset of cover slots, and scatters props.
  - Spawns are at least 6 m from the entry.
  - Exits must be reachable at the player's radius.
- **Biome** = palette + prop set + a **mild** hazard flavour (an ice edge, a void edge). It never changes the
  difficulty tables (PD-04).
- **Biomes:**
  - v0.3.0: Ruins.
  - v0.4.0: Night Rocks and Red Canyon. Biome order is drawn per run.
  - v0.7.0: Frozen Shore (water edges and ice props), plus any others the owner picks.

## H. Scaling and threat

- **Floor index and the danger tier drive scaling** (owner F7, F10; v0.4.0 SC). Enemies grow per floor and every
  30 s of a floor (the danger tier), "just a bit below" the player's growth: HP × 1.9^(floor − 1) × 1.10^tier,
  damage × 1.4^(floor − 1) × 1.05^tier, from integer `‰` tables (flat after tier 20). Bosses keep their own per-floor
  scaling (+40 % HP, +20 % damage a floor). **Hordes:** at most 14 / 30 / 50 enemies alive at tier 0 of floors 1/2/3,
  +6 a tier up to 120; packs (2-3, 3-4, 3-5 strong) arrive every 2.5 s, 10 % faster each tier (at least 0.4 s
  apart), at the edges of the player's room and its neighbours, never within 8 m of the player and never in the
  boss room. All starting values; the expected-build bot's bands (v0.4.0 TU) tune them.
- **T adds threat modifiers** (GA: threat), such as more elites, an extra wave or tougher enemies. Each one shows
  its cost and its reward on the door or card before you take it.
- **The formula is locked by evidence** in v0.3.0 ([`../architecture/SIM_CONTRACTS.md`](../architecture/SIM_CONTRACTS.md)
  §11). After that, changing it needs a new sim result that keeps the scorecard bands.
- **No Endless mode before balance alpha** (PD-12; [`../LESSONS.md`](../LESSONS.md) L8).

## I. Meta-progression limits

- Meta unlocks add **alternatives** (new starters, a second kit), **information** (codex entries, enemy notes)
  and **cosmetics** (PD-06; GA: meta). **No permanent stat increases.**
- The journal and codex arrive in v0.8.0. Unlock tracking lives in the profile, never in the run save.
- Dev-panel runs (`dev_touched`) never count toward unlocks or records.

## J. UX, accessibility, onboarding

- **Readability contracts:** [`../architecture/PRESENTATION_CONTRACTS.md`](../architecture/PRESENTATION_CONTRACTS.md)
  §3–§5. No damage without a readable cause.
- **HUD and item cards:** through gate G2 in v0.3.0. A card shows the trigger, condition and payoff in that order,
  with live numbers from the sim.
- **Options** (v0.1.0): audio, display, remapping on both devices, shake, reduced motion, colour-blind modes,
  captions.
- **Onboarding** (v0.3.0): first-time hints for the basics only, shown once per profile and toggleable. Advanced
  systems are left to discover. Full onboarding comes in v0.8.0.
- **Death recap** (v0.3.0): the killing cause with its telegraph, the build, and a damage-by-effect breakdown.
- **Languages:** English and Spanish from v0.0.1.

## K. Audio direction

- Readability first: every hostile windup is audible, and a hit on the player is the clearest cue in the mix.
- Short, punchy, synthetic-leaning sounds that suit clean geometry. One file per cue, with variety from the mixer.
- The list and rules are in [`../audio/SFX_NEEDS.md`](../audio/SFX_NEEDS.md). Music is decided with the owner by
  v0.8.0.

## L. Kill and redesign criteria

- **v0.1.0, "fun without loot":** if the owner doesn't find one arena with three enemies fun with no items, the
  next version iterates on movement, attacks and enemies. Item work doesn't start.
- **v0.3.0, the production decision:** *if the 12-item slice doesn't deliver two opposing playstyles and a Room 4
  build identity, revise the core before expanding.* The evidence is:
  - a 10–15 minute floor;
  - distinct aggro and control wins (sims + owner);
  - ≥ 90% of seeds offering an engine by Room 4 (sims);
  - testers explaining their build after Room 4 (humans).

  The owner decides go, revise or stop. The decision and its evidence are recorded in v0.3.0's PROGRESS and in
  LOCKED_DECISIONS.
- **v0.6.0, balance alpha:** no archetype excluded, no universally dominant pickup, no dead starter. A miss means
  more balance work before content beta, never more content to cover it.
