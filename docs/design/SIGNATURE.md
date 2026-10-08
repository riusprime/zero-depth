# Signature systems

The owner's ask after the full-run playtest (v0.3.0 PLAN L18, verbatim in `docs/roadmap/v0.3.0/PLAYTEST_RUN.md`):
"combos feel alright, but nothing different from a poor mobile game, i'd like to have more original mechanics …
still missing something cool". The owner picked four systems, in this order: **Overclock heat** (v0.3.0), then
**Echoes**, **Core theft** and **Depth descent** (designed with the owner, built in v0.4.0). Every number below is
a starting value the owner tunes after playing.

## Overclock heat (v0.3.0, built)

Owner: "overclock heat should show a combo meter that shows you the overheat point".

### The loop
Attacking builds heat; heat makes your attacks stronger in steps; the top step is a cliff (overheat). The skill
is riding near the edge and venting at the right moment with the **Vent button** (F / pad B, remappable; v0.3.5 K,
owner F1: "this should be an different action button"), which turns the heat into a blast. Until v0.3.5 a dash or
a blink vented; they no longer do.

| Rule | Starting value | Where |
|---|---|---|
| Heat range | 0–100 points (the overheat point is 100) | `data/heat/overclock.tres` `max_heat` |
| Gain per landed attack | combo step +2.5, finisher +5, bolt +0.9 (a swing adds once however many it hits) | `gain_swing`, `gain_finisher`, `gain_bolt` |
| What never adds heat | payoffs (vent, Meltdown, shock discharge…), DoT ticks, Twin Arc echoes, chain jumps, dash bodies, thorn rings, shrapnel, whiffs | `Heat.is_attack` |
| Decay | after 1 s without a landed attack, −15/s | `decay_delay_seconds`, `decay_per_second` |
| **Hot** (≥ 40) | blade reach +20 %; each bolt pierces one enemy | `hot_threshold`, `hot_reach_bonus` |
| **Overclock** (≥ 75) | the player's attacks deal +25 % and leave embers; with a burn item owned (the fire engine), each Overclock hit adds 1 burn stack | `overclock_threshold`, `overclock_damage_bonus`, `overclock_burn_stacks` |
| **Overheat** (reaching 100) | a 1.2 s stall: you move at 60 % and can't swing or shoot; heat drains to 0 over the stall; steam vents | `overheat_seconds`, `overheat_move_multiplier` |
| **Vent** (v0.3.5 K) | pressing Vent while Hot (or Overclock) blasts every enemy within 2.5 m of you for heat vented × 0.5 (40 heat → 20, 99 → 49) and resets heat to 0; under Hot (or overheated) the press does nothing but a small cold click | `vent_radius_m`, `vent_damage_per_heat`; `PlayerSkill` (the button), `Heat.vent` |
| Skills (v0.3.5 K) | a landed build skill adds its own heat once per use: Lunge Cleave +5, Scatter Blast +2.5 | `data/builds/*.tres` `skill.heat` |

Tuning check (unit test `test_a_sustained_fight_reaches_the_thresholds_in_6_to_10_seconds`, mashing against a
still target): Blade reaches Hot at 4.60 s and Overclock at 8.60 s; Gun (shooting held) at 5.17 s and 9.72 s.
Overheat comes about 3 s after Overclock if you never vent.

### Details and choices (lead's reading; reversible)
- Heat is an integer in the sim, kept in milli-points (1000 = one point) so the −15/s decay runs every tick in
  whole numbers. It is hashed only in worlds whose loadout has heat (`World.heat` is null otherwise), so the
  kernel and item goldens keep their hashes.
- The gain per attack type is data, so the Blade and Gun builds (L15) can be tuned apart.
- The vent goes off where you stand when you press it (v0.3.5 K): dash or blink into a crowd first, then vent.
  Dash and blink no longer vent at all, so moving never spends your heat by accident. A press during hit-stop
  waits for it (the 6-tick buffer), as the other buttons do.
- A vent spends all the heat, so venting at Overclock trades the +25 % for the biggest blast. During the stall
  the Vent button does nothing (a cold click).
- The vent blast and the Meltdown blast are payoffs: their own root (vent) or the overheating attack's root
  (Meltdown, once per root), run inside the engines' ancestry (`Engines.begin`/`end`), are listed in
  `Engines.PAYOFFS` (they never add engine stacks) and never add heat.
- Overclock's damage bonus is an attacker multiplier in `Damage.hit` (like Cold Snap), tagged `TAG_OVERCLOCK` on
  the HIT; it applies to the player's swings and bolts only, not to payoffs or DoT.
- Hot bolts carry `TAG_PIERCE`; on their first enemy hit they go on along their path past the enemy's far edge.

### Items (tag `heat`; offered only when the run has heat)
| Item | Rarity | Effect |
|---|---|---|
| Heat Sink | common | vent blasts deal +50 % and reach 30 % farther (2.5 m → 3.25 m) |
| Thermal Edge | common | Hot from 30 heat instead of 40 (the vent threshold follows Hot) |
| Meltdown | rare | reaching the overheat point blows up as a full-heat blast (100 × 0.5 = 50 damage, 2.5 m) instead of the stall; heat resets to 0 |

### What you see
- **The meter** (HUD, bottom centre): a 25-segment arc filling left to right. Segments take their zone's colour
  (steel, amber Hot, red-orange Overclock, white-hot at the end); the filled part glows wider and brighter as it
  fills. The Hot and Overclock thresholds are notches with their names; the **overheat point** is a red bar and
  arrow at the arc's end, named OVERHEAT, pulsing once heat passes 88 %. Crossing a threshold flashes the arc;
  **VENT READY** pulses above it while the Vent button would blast (v0.3.5 K; beside the meter a small hint names
  the bound key, "[F] VENT", lit while Hot and dim otherwise); overheating
  flashes red and vents steam from the arc for the whole stall. The word under the arc names the state (HEAT,
  HOT, OVERCLOCK, OVERHEAT).
- **The hero**: the visor and the laser blade shift from cyan toward amber, then red-orange, then white-hot as heat
  rises (kept materials, colour and energy only; never `emission_enabled`).
- **The world**: a vent draws a flash disc and a ring that grows out to the blast's real radius, with embers;
  Overclock hits throw embers and the moving hero sheds an ember trail; overheat bursts steam and keeps venting
  it from the hero during the stall.

Evidence: `docs/roadmap/v0.3.0/evidence/HEAT.md` and `heat.png`.

## Echoes

Decided 2026-10-08 (owner: "yes to all three"): no separate system. Echoes are a family of modifiers in the
modifier engine (`MODIFIER_ENGINE.md`): Echo Slash (M5), Twin Cast (M12), Long Shadow (M19).

## Core theft

Decided 2026-10-08: elites and bosses carry a visible **core** (a modifier). Kill them during a short window
after a stagger to steal it as a free pick (it goes through the 6-slot Swap like any modifier).

## Depth descent

Decided 2026-10-08: it is the Deep route (v0.5.5 S5). Each Deep floor taken raises threat, so it raises the
cap of the hidden growth-matching difficulty, and the rewards.
