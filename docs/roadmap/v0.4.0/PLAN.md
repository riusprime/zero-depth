# v0.4.0 — Run Depth: four abilities, compounding stats and hordes that grow with you (plan, owner-directed 2026-10-07)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **Before this:** v0.3.0 "Three Floors" (built, played by the owner) and v0.3.5 "Feedback pass"
  ([`../v0.3.5/PLAN.md`](../v0.3.5/PLAN.md)) on `claude/lucid-fermat-9wv2tf`. `main` doesn't exist yet (O3).
- **The owner's direction (2026-10-07, verbatim in [`../v0.3.0/PLAYTEST_RUN_2.md`](../v0.3.0/PLAYTEST_RUN_2.md),
  numbered F7–F11, F13 in the v0.3.5 PLAN):** an incremental "god" feeling — you kill more and more enemies as you
  grow; a build is **four damage abilities** (the combo sword, auto-thrown bombs, a robot that follows you…); every
  other card is a stat (+% HP, damage, crit…) so you grow exponentially; enemies scale in HP, damage and numbers per
  floor and over time, just below your growth; blink becomes a spell found later; more objects, upgrades and combos.
- **ROADMAP v0.4.0 scope** (Run Depth): more bosses in each pool; 12 enemy behaviours; slot-cap prototype (here
  replaced by the owner's four ability slots); saves at every room entry plus save on close; threat T branches.
- This flips **PD-01** (utility chosen before the run → no starting utility; blink is an ability) and **PD-08**
  (6 + 3 mechanism slots behind a flag → four ability slots, always on). LOCKED_DECISIONS row 2026-10-07.
- **Signature systems** Echoes, Core theft and Depth descent (v0.3.0 L18) were planned for v0.4.0 "designed with the
  owner". They are **not** built here until the owner says how they fit the new direction (open question Q1).
- Every number below is a **starting value** the owner tunes after playing.

## Every owner line → where it lands
| # | Owner line (2026-10-07) | Decision | Step |
|---|---|---|---|
| F7 | "an incremental feeling that you can kill a lot of enemies as you grow on" | Hordes: spawn counts and on-screen caps grow per floor and with time; the sim and the view are made to carry them | SC |
| F8 | "each build showld focus on 4 items that have combo sword maybe auto throuwing bombos, a robot that follows you, like actual abilities than make damage" | **Four ability slots.** Slot 1 is the starting weapon (Blade: combo sword + Lunge Cleave; Gun: pulse gun + Scatter Blast). Slots 2–4 take ability cards; once full, ability offers only level up what you own (levels 1–5) | BS |
| F9 | "the rest of the upgrades and cards you get should be oriented into +%hp dmg crit and that kind of stats you you grow exponentially" | **Stat cards**: every other reward. Each stat stacks multiplicatively (two +10 % damage cards = ×1.21). **Crit** is new: chance and damage | BS |
| F10 | "the enemies must have an scaling system on damage and health that usually goes just a bit below of what you are growing, and spawning more enemies each floor and time, so it becomes this crazy hard huge battle but you feel like you are a "god" feeling" | Enemy HP, damage and count scale per floor and per danger tier, tuned against an "expected build" bot so time-to-kill falls slowly while the crowd grows (target below) | SC, TU |
| F11 | "blinking should be a later on spell you get" | No utility at the start. **Blink** is an ability card (Shift / LB), now with a landing shock | BS |
| F13 | "we need more objects or upgrades and combos to add variety" | 10 abilities, ~20 stat cards, 8 ability combos (pairs that evolve), the 27 v0.3.0 items kept as rarer **mods** | BS, AB |
| R1 | ROADMAP: "More bosses in each pool" | One new boss per floor pool (two per pool) | BO |
| R2 | ROADMAP: "12 enemy behaviours" | 6 today after v0.3.5 (Charger, Warden, Needle, Hatchling, Arc Caster, Bomb Drone) + 6 horde types | EN |
| R3 | ROADMAP: "Saves at every room entry plus save on close" | Save at each room entry and on close; quitting mid-room resumes at that room's entry with an equal state hash | SV |
| R4 | ROADMAP: "Threat T branches" | An optional **Overrun** door per floor: a harder side room (×1.5 scaling, more spawns) with a guaranteed ability-level reward | AB |

## Design (starting values)

### Abilities (BS, AB)
An **ability** is typed content (`AbilityDefinition`: id, slot kind manual/auto, cooldown, damage, shape, per-level
table, tags, view scene). Auto abilities fire on their own cooldown at a target chosen by a sim rule (nearest,
densest cluster, random from the `ability` stream). Damage uses the player's stat multipliers and can crit.

| Ability | Kind | Level 1 | Per level (to 5) |
|---|---|---|---|
| Combo Sword (Blade start) | manual | the four-slash combo + Lunge Cleave | +12 % damage; L3 +15 % reach; L5 finisher shockwave |
| Pulse Gun (Gun start) | manual | held bolts + Scatter Blast | +12 % damage; L3 +1 pierce; L5 twin bolts |
| **Bomb Lobber** | auto | every 2.5 s throws a bomb at the densest cluster within 8 m (radius 2 m, 22 dmg, ground circle shown) | +1 bomb at L2/L4; +15 % radius at L3/L5 |
| **Drone Buddy** (the robot that follows you) | auto | a drone trails you and fires a bolt at the nearest enemy 3×/s (5 dmg, 9 m) | +20 % fire rate; L3 second drone; L5 drone bolts chain once |
| **Orbit Blades** | auto | 3 blades orbit at 1.6 m, 8 dmg per touch (0.5 s per-enemy) | +1 blade per level; L5 radius 2.2 m |
| **Arc Field** | auto | every 1.5 s lightning strikes 3 enemies within 6 m (12 dmg, shock stack) | +1 target per level; −0.1 s cooldown |
| **Frost Nova** | auto | every 4 s a 3 m nova (10 dmg, 2 frost stacks) | +0.4 m; L3 freezes on 4 stacks faster; L5 every 3 s |
| **Flame Trail** | auto | while moving you leave fire for 2 s (6 dmg/s, burn) | +25 % duration and damage |
| **Blink** | manual (utility button) | the v0.3.0 blink (5 m, through walls by range) + a 2 m landing shock (15 dmg) | −0.2 s cooldown; L3 +1 charge; L5 shock 2.8 m |
| **Aegis** (the old guard) | manual (utility button) | guard from v0.1.0 + guard charges | +1 charge cap; L5 reflects bolts |

- Slots: 4. Blink and Aegis share the utility button (only one of them can be owned).
- Ability cards show at altars (each free altar offers ≥ 1 ability card while a slot is free) and chests.
- **Ability combos (AB):** owning both at L3+ evolves the pair: Bomb Lobber + Arc Field = *Storm Bombs* (bombs
  chain lightning), Drone Buddy + Flame Trail = *Napalm Drone*, Orbit Blades + Frost Nova = *Glacier Ring*, Blink +
  Bomb Lobber = *Blink Charge*, Combo Sword + Orbit Blades = *Blade Dance*, Pulse Gun + Drone Buddy = *Wingman*,
  Arc Field + Frost Nova = *Superconductor*, Flame Trail + Aegis = *Ember Ward*. Each with a card, badge and look,
  added to INTERACTIONS.md.

### Stat cards and crit (BS)
Every reward that isn't an ability is a **stat card**, in three rarities (common / rare / epic):

| Stat | Common / Rare / Epic | Cap |
|---|---|---|
| Max HP | +8 / +15 / +25 % | — |
| Damage | +8 / +15 / +25 % | — |
| Crit chance | +4 / +8 / +12 pts | 75 % |
| Crit damage | +15 / +30 / +50 pts (base ×1.5) | ×4.0 |
| Attack speed | +6 / +12 / +18 % | ×2.5 |
| Area | +8 / +15 / +25 % | ×2.5 |
| Cooldowns | −5 / −9 / −14 % | −60 % |
| Move speed | +4 / +7 / +10 % | ×1.6 |
| Regen | +0.3 / +0.6 / +1.0 %/s | — |
| Shard gain | +10 / +20 / +30 % | — |
| Pickup range | +15 / +30 / +45 % | — |
| Armour | −4 / −7 / −10 % damage taken | −60 % |

Multiplicative stacking (`value × (1 + bonus)` per card, per-mille integers in the sim). The v0.3.0 items stay as
**mods** (rarer, mostly from chests). The gamble shrine pays in the same stats. Crit: a roll on the `crit` stream
per hit (DoT ticks don't crit); a crit hit shows a bigger, yellow number and a sharper sound.

### Scaling and hordes (SC, TU)
- Enemy HP × `1.9^(floor−1) × 1.10^tier`, damage × `1.4^(floor−1) × 1.05^tier` (tier = the 30 s danger tier).
  Integer tables, not runtime powers (EI-02).
- Spawns: concurrent cap 14 / 30 / 50 at tier 0 of floors 1/2/3, +6 per tier (max 120); spawn interval shrinks
  10 % per tier. Groups spawn as packs at the edges of the player's room and neighbours.
- **Target (TU, measured by sims):** an "expected build" bot (picks the best-scoring card each time) sees the
  median time-to-kill of a normal enemy **fall** 20–40 % from the start to the end of each floor while the number of
  enemies on screen rises, and dies in < 30 % of runs on floor 1, 30–60 % by floor 3 (starting bands; the owner
  tunes the feel).
- **Performance (SC):** the stress target missed in v0.3.0 (6.8 ms/tick vs ≤ 2 ms). Hordes need: AI thinking
  staggered over ticks (each enemy re-plans every 4 ticks, moves every tick), the nav field computed once per tick for
  all, the uniform grid for every query, pooled projectiles; in the view, MultiMesh or pooled instances for crowds,
  no per-enemy lights. Target: 120 enemies + 200 projectiles ≤ 4 ms mean per tick on the CI runner, 60 fps view on
  the owner's PC (owner check). Bench evidence before and after.

### Saves (SV)
- A save is the run's seed, the floor, the room-entry snapshot of the full `World` (canonical serialization, the same
  fields the hasher reads) and the build. Written at each room entry (first entry into a room) and on close (pause
  menu → Main menu, window close). Resuming loads the last room-entry snapshot: test = save → load → hash equal, and
  stepping both 600 ticks with the same inputs gives equal hashes.
- Main menu: **Continue** when a save exists; a death or a win deletes it.

### Bosses (BO)
One new boss per pool, code-built in the enemy style (owner art replaces them when sent; prompts in `BOSSES_2.md`):
- Floor 1 **The Warlord** — a shielded knight that dashes and plants spear lines; weak point when it lifts its shield.
- Floor 2 **The Hive Lens** — a floating eye that splits into three drones at 50 %, beams that sweep.
- Floor 3 **The Foundry** — a furnace that floods lanes with molten floor and launches bomb drones.
Each keeps BX's anti-kite rules (ranged armour, punish move, closing hazard, weak point).

### Enemies (EN): six horde types → 12 behaviours
**Swarmer** (tiny, fast, 1 hit, packs of 8), **Splitter** (splits into 2 on death), **Shield Bearer** (front shield,
pushes), **Mender** (heals others, priority target), **Mine Layer** (drops mines with circles), **Sniper** (long
line telegraph, 1.0 s, high damage). All with readable telegraphs ≥ 24 ticks and code-built models.

### Threat branch (AB)
One **Overrun** door per floor (from floor 1, a side room with a red frame): ×1.5 HP/damage, +50 % spawns; clearing
it gives an ability level-up card and 2× shards. Optional, never on the path to the boss.

## Owner playtest feedback (2026-10-08, verbatim)
> okay, I tried one of these playable versions, it is extreamly hard from the beggining, I do like this level of difficulty, but only if the character has grown a bit on the scaling vector, we need to ease the difficulty curve on the first minutes of the game, and introduce the enemies by phases, and then reach this difficulty closer to the end of the floor, when the difficulty has reached its max,  difficulty should be "easy" the first minute so you can explore and gather some stuff and then it becomes harder and harder, what I felt is that there were too many hard enemies I could not really kill all before even reaching the first boss or getting enough spells or upgrades

| # | Owner line | Decision | Step |
|---|---|---|---|
| D1 | "ease the difficulty curve on the first minutes of the game" / "difficulty should be "easy" the first minute so you can explore and gather some stuff" | A calm first minute on every floor: few enemies, only the basic kinds, slow spawns, no tier scaling yet | TU |
| D2 | "introduce the enemies by phases" | Enemy kinds unlock in phases across the floor (basic → ranged → specialists → elites), each phase announced | TU |
| D3 | "reach this difficulty closer to the end of the floor, when the difficulty has reached its max" / "then it becomes harder and harder" | The floor's difficulty ramps to its peak (today's level) near the floor's expected end, then holds; the curve is data | TU |
| D4 | "I do like this level of difficulty, but only if the character has grown a bit on the scaling vector" / "too many hard enemies … before even reaching the first boss or getting enough spells or upgrades" | Tune against the expected-build bot: early rewards come sooner (an altar near the start hall), and the peak is reached only when a bot that picks normally has grown into it | TU |
| D5 | (2026-10-08) "we also have a lot of variety of enemies, let's distribute presenting them through the first 3 floors" | Enemy kinds are introduced across floors 1–3 (floor 1: basics + a few specialists; floor 2 and 3 add the rest), each first appearance announced; boss summons exempt | TU |

## Steps
| Wave | Step | Scope |
|---|---|---|
| 2 | BS | Ability slots and framework, Blink/Aegis as abilities, Bomb Lobber, Drone Buddy, Orbit Blades, stat cards + crit, offers rework, ability HUD (4 slots + cooldowns + levels) |
| 2 | SC | Scaling tables, horde spawning, sim + view performance for crowds, bench |
| 2 | EN | Six horde enemy types |
| 2 | BO | Three new bosses (one per pool) |
| 3 | AB | Arc Field, Frost Nova, Flame Trail, 8 ability combos, Overrun branch, mods re-filed |
| 3 | SV | Saves at room entry and on close, Continue |
| 3 | TU | Tuning against the expected-build bot (bands above), readable-cause rerun, bench rerun |
| 3 | CP | (v0.5.0 scope, pulled into this sprint by the owner) A 40–50 card candidate pool: abilities, stat cards and mods together, starting after BS merges |
| — | R | Build for the owner + playtest sheet |

## Open items (what they block)
- **Q1 (owner):** Echoes, Core theft and Depth descent — still wanted with the new direction, and where? (blocks
  only those systems).
- **Q2 (owner), answered 2026-10-07:** "skip the rule, keep going to v0.5.0" — v0.5.0 follows without a v0.4.0 playtest.
- G2 for the ability HUD and the card look (mockups, default ships).
- O3 `main`; O4 credit line.

## Verification
- Unit + e2e tests per step; sims (expected-build bot) and bench as evidence; goldens changed only on purpose;
  full suite, lint, export smoke before every merge push; CI green; then the owner's playtest of v0.4.0.
