# v0.9.5 G1: element levels and level-3 pairs (ELEMENTS)

**Owner (2026-10-25, G3):** "Elements should have a reward for leveling up, now we modifying them to 3 max levels, for
example venom or blood, first level it is what it is, sencond it can jump to near enemies, and third you can stack it
and it does a little bit more damage per tick per stack, each element should have its own reward system for levling,
and maybe we could add some special combinations so something else happens when you have 2 level 3 elements they do
something special."

**How to answer:** row by row ("E1 yes, E4 change to …, X3 no"). Nothing is built before the answers.

## Today (live code)
- There are five elements on the Gun, which holds 2 of them:
  - Fire (`ember_core`): burns, and burning foes leave fire behind;
  - Lightning (`storm_core`): hits chain;
  - Frost (`frost_core`): slows, then freezes;
  - Venom (`venom_core`): poisons, and poison spreads on death;
  - Bleed (`shared_bleed`): bleeds.
- **Levels 1–5, and each level is only +5 % damage** (`per_level = 50` per mille in `data/modifiers/*_core.tres`).
  Lightning adds +10 % per level to its hook chance. You can't see a level working, which is the owner's point.
- **New rule:** an element has 3 levels. You level it by taking it again. Each level adds a visible behaviour, not a
  percentage. Saves above level 3 drop to 3.
- **Already taken names:** the run already has 16 named combos (`data/combos/`), and two of their names,
  *Superconductor* and *Plasma Arc*, sound elemental. The pair names below avoid them.

## Levels (Lv 1 is today's behaviour)
| ID | Element | Lv 2 | Lv 3 |
|---|---|---|---|
| E1 | **Venom** | *Contagion:* every 1.5 s, poison jumps from a poisoned enemy to 1 unpoisoned enemy within 2.5 m | *Virulence:* poison stacks up to 5; each stack adds +25 % damage per tick; a new hit refreshes the duration |
| E2 | **Bleed** | *Open wounds:* bleeding enemies that move take +50 % bleed damage (it punishes runners and chargers) | *Exsanguinate:* bleed stacks up to 5; at 5 stacks it bursts at once for the rest of its damage, then resets |
| E3 | **Fire** | *Wildfire:* the fire left behind is 50 % wider, lasts 1 s longer, and lights enemies that walk through it | *Heat sync:* burning enemies take +15 % damage from all your hits (no explosions, per v0.9.0 XP) |
| E4 | **Lightning** | *Fork:* +1 chain jump and +1.5 m chain range | *Overcharge:* every 6th hit calls down a strike on that enemy (1.5 m, ×2 hit damage) |
| E5 | **Frost** | *Frostbite:* frozen enemies take +25 % damage | *Shatter:* hitting a frozen enemy breaks the ice: 3 shards fly to enemies within 3 m (50 % hit damage, a short slow) |

## Level-3 pairs (both elements at Lv 3, so only in the 2 Gun element slots)
Each pair is one extra rule. It is shown as a named banner when it turns on, like today's combo banner.

| ID | Pair | Name | What happens |
|---|---|---|---|
| X1 | Fire + Frost | **Thermal Shock** | Hitting an enemy that is burning *and* frozen removes both and deals a burst: ×3 hit damage in 1.5 m |
| X2 | Fire + Venom | **Toxic Fumes** | A poisoned enemy that catches fire leaves a 2 m gas cloud for 3 s that poisons whatever walks in |
| X3 | Fire + Lightning | **Ignition Arc** | Chain jumps set enemies on fire |
| X4 | Fire + Bleed | **Boiling Blood** | Bleed ticks on a burning enemy deal double |
| X5 | Frost + Lightning | **Cold Circuit** | Chains jump to frozen enemies first and deal double to them |
| X6 | Frost + Venom | **Black Ice** | Poisoned enemies are slowed 20 % more, and their poison doesn't expire while they're frozen |
| X7 | Frost + Bleed | **Brittle** | When a frozen enemy is shattered or killed, its remaining bleed bursts on enemies within 2 m |
| X8 | Lightning + Venom | **Neurotoxin** | Chain jumps carry 1 poison stack |
| X9 | Lightning + Bleed | **Arterial Arc** | Chain jumps apply bleed |
| X10 | Venom + Bleed | **Sepsis** | An enemy with 3+ stacks of both takes +20 % damage from everything |

## Budget and performance
- Every jump, cloud and shard uses the existing status and burst pools: `BurstBudget.MAX_LIVE`, and ImpactFx's merge
  and caps.
- A Lv 3 status adds no new particle system. It adds one ring tint per stack count on the enemy's status pip.
- Pair rules are capped at 4 triggers a second each, so a 20-enemy pack can't chain into a lag spike (owner line 21).

## How it is built (once approved)
- **Data:** `level_max = 3` for the element cards in the card-level table ([`CARD_LEVELS.md`](CARD_LEVELS.md)).
- **Sim:** each Lv 2 / Lv 3 behaviour is a hook in `src/sim/effects/` next to the element's status code. Pairs are a
  table `data/combos/element_pairs.tres` checked when the wand compiles.
- **Steps:**
  1. Levels for Venom and Bleed (the owner's example).
  2. Levels for Fire, Lightning and Frost.
  3. The pairs.
- **Tests:** a unit test per level and per pair; the soak test with 20 enemies and two Lv 3 elements stays within
  the frame budget on the owner's PC.
- **Text:** card text shows the next level's behaviour in one short line (en and es).

## Decisions (owner, date)
| ID | Answer | Built in |
|---|---|---|
| | | |
