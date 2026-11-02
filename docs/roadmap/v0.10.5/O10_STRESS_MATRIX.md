# v0.10.5 O10: the stress matrix (P3)

**Status: overnight pick, owner reviews** (owner, 2026-11-01, P3: "yes"; overnight mode: "Pick and build"). Every
row is a starting value the owner keeps or changes. Source: [`THEORY_AUDIT.md`](THEORY_AUDIT.md) P3 (Schreiber:
intransitive and situational balance). Built in v0.10.5 Step O10; measured in
[`evidence/O10_STRESS_MATRIX.md`](evidence/O10_STRESS_MATRIX.md).

## The rule

- Every enemy kind (the 14 in `data/enemies/`; not bosses, not elites) is **weak to** one form or element and
  **resists** another (`EnemyDefinition.weak_to`, `resists`).
- A weak hit takes **×1.25** (`weak_permille = 1250`), a resisted one **×0.75** (`resist_permille = 750`), both in
  each enemy's data. They are per-mille multipliers in the damage step (SIM_CONTRACTS §8 step 3), never a flat cut. A
  resisted hit that had damage keeps at least 1.
- **What counts as the form or element:** a form is the card that made the shot (its modifier id on the attack:
  `gun_laser`, `gun_lance`, `gun_wave`, `gun_glaive`). An element is one the attack carries (`ember`, `storm`,
  `venom`), so any shot with Fire on it counts as Fire. The Ring is a shock ring, so it counts as Lightning.
  Damage-over-time ticks count by their element: burn is `ember`, poison is `venom`, bleed is `bleed`.
- A hit that matches both the weakness and the resistance (a Laser shot with a Wave on it, on a Sniper) cancels
  to ×1.
- **Readability:** a weak hit's damage number is bigger and red-pink; a resisted one is smaller and dim grey. Both
  come from the hit event's flag (`TAG_WEAK_TO`, `TAG_RESISTED`). The Codex's enemy entry lists "Weak to" and
  "Resists".

## The ids (7): each good against 2 kinds, bad against 2

| Id | Name | Weak to it (good against) | Resists it (bad against) |
|---|---|---|---|
| `gun_laser` | Laser | Shield Bearer, Sniper | Swarmer, Lens Drone |
| `gun_lance` | Lance | Charger, Arc Caster | Splitling, Hatchling |
| `gun_wave` | Wave | Swarmer, Splitling | Needle, Sniper |
| `gun_glaive` | Glaive | Needle, Mine Layer | Splitter, Shield Bearer |
| `ember` | Fire | Hatchling, Bomb Drone | Mender, Mine Layer |
| `storm` | Lightning (also the Ring) | Mender, Lens Drone | Warden, Arc Caster |
| `venom` | Venom | Warden, Splitter | Charger, Bomb Drone |

No id is best everywhere and none is worst everywhere: each is someone's answer and someone's wrong choice. Every
other form (Seekers, Wisps, Void, Rune, the plain bolt, the Blade's slashes) is neutral against every kind.

## The matrix

| Kind | Weak to (×1.25) | Why | Resists (×0.75) | Why |
|---|---|---|---|---|
| Charger | Lance | A charged lance punishes its daze after the charge, down the same lane | Venom | It's in and out before the stacks build |
| Warden | Venom | Slow and tanky: poison keeps stacking through a long fight, and damage over time already skips its front armour | Lightning | Its stone body earths the shock |
| Needle | Glaive | The returning glaive catches it while it backs off | Wave | It keeps its distance, so a slow wave never reaches it |
| Swarmer | Wave | A wide wave rolls through the whole pack | Laser | One beam on one small, fast body at a time |
| Arc Caster | Lance | A fragile caster: one heavy lance from range ends it | Lightning | It is made of lightning |
| Splitter | Venom | Poison soaks the big soft body before it splits | Glaive | The glaive's cuts only split it sooner |
| Splitling | Wave | The split pieces come in a pack; area clears them | Lance | Too small for one heavy shot; most of it is wasted |
| Hatchling | Fire | Soft young burn | Lance | Too small for one heavy shot |
| Shield Bearer | Laser | The beam reaches past the shield's edge | Glaive | The shield turns thrown blades |
| Sniper | Laser | The beam out-reaches it down its own line | Wave | It fights from far beyond a wave's reach |
| Mender | Lightning | Burst and shock cut through its heals | Fire | It heals through damage over time |
| Mine Layer | Glaive | The glaive sweeps its trail and comes back for it | Fire | A sapper in a blast-proof shell |
| Bomb Drone | Fire | Its own fire payload cooks off | Venom | A machine: nothing for poison to work on |
| Lens Drone | Lightning | Shock shorts its circuits | Laser | Its lens bends the beam |

## Room mixes that change the best pick

The point of the matrix (Schreiber, situational): which build is best depends on the room.
- **Floor 1** (Charger, Needle, Swarmer, Warden, Arc Caster, Splitter): Lance (Charger, Arc Caster) and Venom
  (Warden, Splitter) are strong. Wave is good against Swarmer packs but bad against Needles.
- **Floor 2** adds Shield Bearer, Bomb Drone and Mine Layer: Laser (Shield Bearer) and Glaive (Mine Layer, Needle)
  rise. Venom falls against the Bomb Drone.
- **Floor 3** adds Mender, Sniper and Swarmer packs of 8: Lightning (Mender) and Laser (Sniper) are strong, and Wave
  (the packs) is strong but bad against Snipers. A Fire build meets the Mender, which resists it.
- A Swarmer-pack room with a Sniper behind it splits Wave (good against the pack, bad against the Sniper) from Laser
  (the reverse), so a build that carries both covers the room.

## Picks for the owner

1. **The 14 rows above**, with the ids and reasons: keep, change or cut each one.
2. **×1.25 / ×0.75** (starting values, in each enemy's data): stronger (×1.5 / ×0.5) makes the matchup a rule the
   player must follow; weaker makes it a hint.
3. **Seven ids only.** The four Gun forms and three elements cover 14 kinds at exactly 2 good / 2 bad each. Frost,
   Bleed, Seekers, Wisps, Void, Rune and every Blade form are neutral everywhere. A Blade run meets the matrix only
   through its elements (Fire, Lightning, Venom).
4. **The Ring counts as Lightning** (it carries the `storm` element), so it is good against the Mender and Lens Drone
   and resisted by the Warden and Arc Caster.
5. **The Shield Bearer's shield still blocks the Laser from the front.** "Pierced by Laser" is ×1.25 on the hits
   that reach it. Letting the beam through the front is a separate rule if the owner wants it.
6. **A hit that matches both cancels** (×1), instead of ×1.25 × 0.75 = ×0.94.
