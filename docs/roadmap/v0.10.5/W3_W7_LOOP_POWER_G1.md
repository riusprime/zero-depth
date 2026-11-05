# W3-P10 G1: loop power, the "wow" in loops (owner W7)

Owner, 2026-11-05: "loops should be fun visually and broken builds, we have to add or modify the game to get this wow
moment at how strong you can get in loops. maybe adding some stackable cards, that make your attack jumps to a
closer enemy, growing crit damage, attack speed, more attacks". After the brainstorm: "Ookay A + B + C but don't get
crazy with visuals for explosions".

**Status: DRAFT, waiting on the owner row by row.** Nothing here is built. Every number is a starting value, not a
measurement.

## Why loops feel flat (from W3-P3, OWNER_QUESTIONS W7)

- Enemy HP is × 3.5 a loop, compounding (`loop_enemy_hp_permille = 3500`, `run_state.gd:275`).
- Player power adds against caps:
  - crit chance at most 75 % (`crit_chance.tres` cap 75);
  - crit damage at most × 4 (`crit_damage.tres` cap 400);
  - haste at most +150 % raw, +100 % after the curve (`attack_speed.tres` cap 2.5, `attack_rate.gd`);
  - hooks 2 deep (`Attacks.MAX_HOOK_DEPTH`);
  - overlevels +15 % a loop (W3-P3).
- Measured: a strong build at loop 2 floor 5 has about 53 % of its loop-1 floor-5 power against the HP, and about
  25 % at loop 3.
- Already true, no change: shots past ShotCap (12 a volley, 40 a second) merge into bigger shots that keep the damage
  (`shot_cap.gd`), so projectile count is not where power is lost.

## The target (to approve)

| # | Target | Owner |
|---|---|---|
| T1 | A **strong** build (the W3-P3 tracks: Gun Void stack, Blade elements, Orbs) at loop 2 floor 5 and at loop 3 floor 5 is at **80–120 %** of its loop-1 floor-5 power against the HP | |
| T2 | A **weak** build (no engine, plain stat cards) stays under 50 % at loop 2 floor 5: loops are still a wall for a build that didn't come together (W3-P4, "A wall") | |
| T3 | Loop 1 is unchanged: every loop-1 number in the goldens stays the same (all of A, B and C act from loop 2 only) | |

The measure is the W3-P3 loop probe, on the same tracks and seeds, before and after. A missed target is reported and
waits here, not retuned blind.

## A. Overflow: the caps keep paying off (from loop 2)

| # | Change | Starting value | Owner |
|---|---|---|---|
| A1 | **Double crit.** From loop 2 the crit-chance cap rises to 200 %. Chance past 100 % is a chance of a *double crit*: the hit takes the crit multiplier twice (one roll on the `crit` stream, as now: the roll picks none / crit / double) | cap 75 % → 200 % from loop 2; a double crit at most × 10 | |
| A2 | **Double-crit number.** A double crit's damage number is the crit number, larger, in ice-white `#CFE4FF` with a thin ink edge. No new effect in the world | + 25 % size over a crit | |
| A3 | **Crit damage cap.** From loop 2 the crit-damage cap rises a step each loop | × 4 → × 6 at loop 2, × 8 at loop 3+ | |
| A4 | **Haste overflow.** From loop 2 the raw haste cap lifts (2.5 → none). Haste past the curve's top (+100 % rate) turns into damage instead of nothing | every 2 % of raw haste past it = + 1 % damage | |
| A5 | **Deeper chains.** From loop 2 hooks (Split, Chain Blast's children, Echo's repeats) go one level deeper a loop. The proc halving stays (100 → 50 → 25 → 12). `MAX_LAUNCHES_PER_TICK` (256) and ShotCap stay as they are (performance) | depth 2 → 3 at loop 2, 4 at loop 3+ | |
| A6 | **Overlevels** (W3-P3) stay at + 15 % a loop. If T1 is still missed after A + B + C, they are the first number to raise (owner's pick then) | + 15 % | |

## B. Starbound cards: stackable, loop-only

A new card kind, **Starbound**. It is offered only from loop 2, with no level cap: each pick adds a stack. It works
with both weapons. It shows in the normal card picks as one of the four cards with its own frame accent, and is never
in the shop.

| # | Card | What a stack does | Starting value | Owner |
|---|---|---|---|---|
| B0 | **Offer rate** | the chance that one of a pick's four cards is a Starbound card | loop 2: 35 %, loop 3+: 50 % | |
| B1 | **Arc Jump** (your idea) | each direct hit of yours jumps to the nearest enemy within 4 m that this chain hasn't hit; + 1 jump a stack; each jump deals 70 % of the one before. A jump hits but doesn't jump again (one activation per root, as every proc). Chain Cut (Blade) stays as it is; Arc Jump adds on top | 4 m, 70 %, + 1 jump a stack | |
| B2 | **Rising Edge** | each of your crits adds crit damage until the room is cleared, then resets | + 3 % a crit a stack, at most + 150 % a stack | |
| B3 | **Echo Cast** | a chance that an attack repeats (as Gun Echo's repeat: the REPEAT bit, a repeat never repeats); + 25 % a stack; past 100 % the repeat is sure and the rest is the chance of a second | + 25 % a stack, at most 3 repeats | |
| B4 | **Fervour** | each kill adds haste until the room is cleared, then resets; it counts toward A4's overflow | + 2 % a kill a stack, at most + 60 % a stack | |
| B5 | **Detonation** | an enemy you kill bursts for a share of its max HP to enemies within 2 m; a burst that kills can set off the next | 20 % of its max HP a stack; bosses and elites take half; at most 24 bursts a tick (the rest dropped, one LIMIT event) | |

**Explosions stay plain** (owner: "don't get crazy with visuals for explosions"):

| # | Rule | Owner |
|---|---|---|
| V1 | Detonation reuses the existing small blast (Chain Blast's, at its W3 smaller size), tinted moon-blue. No new effect, no screen shake, no flash, no lingering particles | |
| V2 | At most 8 bursts are drawn a frame; the others deal their damage undrawn | |
| V3 | Arc Jump is a thin moon-blue arc line for 0.15 s, at most 16 drawn a frame. Echo Cast, Rising Edge and Fervour add nothing in the world, only a stack count on the HUD's buff row | |

## C. Constellations: one rule-breaker a loop

When a loop starts (through the loop gate, before floor 1), the player picks **1 of 3 Constellations** on a pick
screen in the Astral style. Each changes one rule for the rest of the run. They stack across loops. A run never offers
one it already holds.

| # | Constellation | The rule it breaks | Needs | Owner |
|---|---|---|---|---|
| C1 | **Resonance** | every element you apply also applies your other held elements at half stacks | the element tables | |
| C2 | **Skill Tide** | every 10th attack also casts your Skill, with no cooldown spent | the Skill cast path | |
| C3 | **Orb Communion** | your orbiting attacks (Blade Orbit, Orbit Rounds, Wisps) carry your weapon's elements and crit | the orb hits | |
| C4 | **Overkill Tide** | damage past a kill carries on to the nearest enemy within 4 m | the damage pipeline | |
| C5 | **Twin Star** | your overlevels count twice (+ 30 % instead of + 15 %) | CardLevels | |
| C6 | **Glass Sky** | + 100 % damage, max HP halved | Stats | |
| C7 | **Starfall** | every 5th crit drops a star on the nearest other enemy for 100 % of that hit (drawn as a thin falling line, V-rules apply) | the crit roll | |
| C8 | **Heart of the Engine** | your engines (bleed, guard, …) gain stacks 50 % faster | Engines | |

## What it needs besides the sim

- **Strings:** names and texts for 5 Starbound cards and 8 Constellations, `en` and `es`.
- **Art:** 13 icons (5 cards and 8 Constellations) as one new sheet row in `docs/art/prompts/ZD_CARD_ICONS.xlsx`, in
  the card-icon style, for your n8n workflow. Until then each uses `icon_unknown`.
- **Codex** entries, and the Build page lists the held Constellations.
- **Saves and determinism:** stacks and Constellations are saved, hashed and replay-exact. Old saves load with none.
- **e2e:** a test that drives `main.tscn` into loop 2, picks a Constellation and a Starbound card, and sees them work.

## Build order once approved

1. **A** (Opus): the overflow rules and the double-crit number.
2. **B** (Opus): the Starbound card kind, its offers, then B1–B5 and the V-rules.
3. **C** (Opus): the pick screen and C1–C8. C can run beside B, since their files barely overlap.
4. **Art row and strings** (Sonnet).
5. **Measure** T1–T3 with the W3-P3 probe, then report. A missed target waits here.

## Questions for the owner

| # | Question | Owner |
|---|---|---|
| Q1 | Starbound cards in the normal picks (B0), or only from a special chest or the boss pick? | |
| Q2 | Constellations at the start of each loop, or after each loop's final boss instead? | |
| Q3 | Can a Constellation pick be rerolled (with shards), or is it fixed? | |
| Q4 | Any of C1–C8 to drop, or one of your own to add? | |
