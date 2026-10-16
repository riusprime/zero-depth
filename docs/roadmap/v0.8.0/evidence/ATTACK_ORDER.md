# ATTACK_ORDER: how much does the wand's card order matter, and what does Step AO change? (v0.8.0 AO, owner O37)

- **Status:** RUN (part 1, before AO; part 2, after AO, below); the feel and the look in play: OWNER ONLY
- **Build:** part 1 on `f1e2ab1` (branch `v080-ao`, before any AO code); Godot `4.7.2.stable.official.ed1daf0bf`;
  OS `Linux 6.18.44-fc-v139` (cloud container, headless)
- **Date:** 2026-10-16
- **Who ran it:** agent

Owner (O37): "make the order of the attacks be more important … Not every single mod should have an impact on the
order but they should have it, currently the order does not matter that much".

## Part 1: how order works today (before AO)

### The rule in the code
`WandCompile.run` (`src/sim/combat/wand_compile.gd`) reads the wand left to right: each card rewrites the spell built
so far. So order is "real" in the compiler, but it only shows where a card's effect is **not** a plain number on the
one shot:

1. **Hooks are built where their card sits.** Split Shot's splits and Explosive's blast are child attacks; a card to
   their right reaches the child, a card to their left doesn't. Big · Split = one big shot with normal shards;
   Split · Big = big shards too (`tests/unit/sim/test_gun_pool_order.gd`).
2. **Triggers cut the wand** (On Hit, On Kill, On End, On Finisher / On Crit): the cards to their right build the
   cast spell instead of the shot. Moving any card across a trigger changes everything.
3. **Non-commuting numbers:** Halo's count is ×3 (`MUL_PERMILLE`), Spread's is +2 (`ADD`): Halo · Spread = 5 shots,
   Spread · Halo = 9. Rapid Fire's ×0.7 and Big Shot's ×1.6 damage round differently in the two orders (5 → 3 → 4 or
   5 → 8 → 5).
4. **Everything else commutes.** The Gun's pattern and path cards (Twin, Spread, Pierce, Ricochet, Homing, Boomerang,
   Orbit, Spiral, Echo, Backfire, Charge) all write separate fields of the one bolt, so any order of them gives the
   same shot. The elements' and statuses' list order follows the cards, but the fight doesn't change (below).
5. **No card changes what the attack *is* in a way that depends on what is left of it.** A form card (Shock Circles'
   ring) was retired in v0.6.5 WN5b (`data/wand/migration.tres`: `shock_circles` maps to nothing on both weapons), so
   no shipped wand card turns the shot into another shape; a `count` on a ring is ignored (one ring however many).

### Command
The pair audit ran from a scratch copy of the pair half of `scripts/checks/order_audit.gd` (the committed script adds
the AO chains, whose fields don't exist at `f1e2ab1`, so it can't compile there; part 2 re-runs the committed one):
```
godot --headless --path . -s <scratch>/order_audit.gd
godot --headless --path . -s <scratch>/order_fight.gd -- "--pairs=storm_core|ember_core,frost_core|venom_core,gun_rapid_fire|gun_big_shot,halo_shot|gun_spread,shared_explosive|storm_core,gun_mine|ember_core,gun_spread|gun_homing,gun_twin|gun_spread,gun_pierce|gun_ricochet,gun_big_shot|split_shot,gun_spread|gun_echo,gun_backfire|gun_homing"
```
What it measures: every pair of wand cards a run of that weapon can hold (its pool, the shared pool, the triggers),
compiled both ways; a pair "matters" when the attack book differs once the list of card ids (which always follows
the order) is cleared. The fight check runs WandLab's 360-tick AttackScenario both ways and compares the event digest.

### Raw output (trimmed: the full pair lists, 234 and 312 entries, are left out)
```
gun cards=30 pairs=435 order_matters=234 order_free=201
gun per-card order-sensitive pairs: shared_explosive=15 split_shot=29 frost_core=15 venom_core=15 trigger_on_kill_twice=29 trigger_on_kill=29 trigger_on_hit_twice=29 trigger_on_hit=29 trigger_on_finisher=29 trigger_on_end_twice=29 trigger_on_end=29 storm_core=15 shared_bleed=15 orbit_rounds=8 halo_shot=9 gun_twin=8 gun_spread=9 gun_spiral=8 gun_ricochet=8 gun_rapid_fire=9 gun_pierce=8 gun_mine=15 gun_homing=8 gun_echo=8 gun_charge=8 gun_big_shot=9 gun_backfire=8 gravity_well=15 ember_core=15 boomerang=8
blade cards=32 pairs=496 order_matters=312 order_free=184
blade per-card order-sensitive pairs: counter=25 blade_storm=24 shared_explosive=22 frost_core=21 heavy=9 wide_arc=11 whirl=11 venom_core=21 trigger_on_kill_twice=30 trigger_on_kill=30 trigger_on_hit_twice=30 trigger_on_hit=30 trigger_on_finisher=29 trigger_on_end_twice=30 trigger_on_end=30 thrust=13 storm_core=22 split_wave=2 shared_bleed=21 riposte_chain=21 parry_edge=7 lunge_step=7 long_shadow=13 gravity_well=22 flurry=8 fissure=21 finisher_plus=18 ember_core=22 echo_slash=25 double_slash=7 chain_cut=21 blade_orbit=21
```
The Gun's 30 order-sensitive pairs with no trigger and no Split in them (from the full list):
```
frost_core|ember_core frost_core|gravity_well frost_core|gun_mine frost_core|shared_bleed frost_core|storm_core frost_core|venom_core gravity_well|ember_core gun_mine|ember_core gun_mine|gravity_well gun_rapid_fire|gun_big_shot halo_shot|gun_spread shared_bleed|ember_core shared_bleed|gravity_well shared_bleed|gun_mine shared_explosive|ember_core shared_explosive|frost_core shared_explosive|gravity_well shared_explosive|gun_mine shared_explosive|shared_bleed shared_explosive|storm_core shared_explosive|venom_core storm_core|ember_core storm_core|gravity_well storm_core|gun_mine storm_core|shared_bleed venom_core|ember_core venom_core|gravity_well venom_core|gun_mine venom_core|shared_bleed venom_core|storm_core
```
The fight check:
```
gun storm_core|ember_core fight_same=events=true hash=false
gun frost_core|venom_core fight_same=events=true hash=false
gun gun_rapid_fire|gun_big_shot fight_same=events=false hash=false
gun halo_shot|gun_spread fight_same=events=false hash=false
gun shared_explosive|storm_core fight_same=events=false hash=false
gun gun_mine|ember_core fight_same=events=true hash=false
gun gun_spread|gun_homing fight_same=events=true hash=false
gun gun_twin|gun_spread fight_same=events=true hash=false
gun gun_pierce|gun_ricochet fight_same=events=true hash=false
gun gun_big_shot|split_shot fight_same=events=false hash=false
gun gun_spread|gun_echo fight_same=events=true hash=false
gun gun_backfire|gun_homing fight_same=events=true hash=false
```
(`hash=false` everywhere: the state hash includes the book's digest, which lists the cards in their order; the
events are what the player sees.)

### What part 1 says
- On the Gun, 234 of 435 pairs compile differently, but 205 of those involve a trigger (7 cards, 29 pairs each) or
  Split; of the 30 left, 28 are element/status cards whose list order changes and the fight doesn't (storm·ember,
  frost·venom, mine·ember: same events), plus Explosive (a hook: an element to its right reaches the blast).
  Only **two** pairs of plain Gun cards change the fight: Halo · Spread (×3 vs +2 shots) and Rapid Fire · Big Shot
  (rounding).
- So the owner's read is right: outside triggers and Split, the **order of the Gun's shape/pattern cards doesn't
  change the attack**. Every one of them rewrites a separate number of one bolt.
- The Blade has more order-sensitive pairs (312 of 496): its flying-slash cards (Wave, Counter, Blade Storm) are
  hooks, which follow rule 1.

## Part 2: what AO changes (after)

- **Build:** the `v080-ao` working tree on `f1e2ab1` (the Step AO commit; its SHA is in PROGRESS's Done row); same
  Godot, OS and container. The probe ran with no other test of this agent running; other agents shared the machine.

### The rule (owner O37; the lead's proposal)
Each card has an order kind (`ModifierDefinition.order_kind`): **shape** cards change what the attack is, **count**
cards multiply what is left of them, **motion** cards move what is left of them, everything else stays order-free.
Each shape, count or motion card works on everything to its left in the wand:

| Card | Kind | What it does (left of it → result) |
|---|---|---|
| **Ring** (`gun_ring`, new, Gun, rare) | shape | the shot becomes a lightning circle (2.5 m, +0.3 m a level) in front of the hero along the aim, that shocks; a **count** left of it becomes the circle's **pulses** (concentric, 0.1 s apart, at most 5); a **Swirl** left of it throws the **whole group** to one random spot |
| **Spread** (`gun_spread`, existing: the "Triple") | count | unchanged on a bolt (a 3-shot fan, +2 a level); right of a Ring: **3 rings** (5, 7 … by level) laid round the circle's centre |
| **Halo** (`halo_shot`, existing) | count | unchanged on a bolt (×3 count, half range); right of a Ring: ×3 rings at half the radius |
| **Swirl** (`gun_swirl`, new, Gun, rare) | motion | right of rings: **each ring is thrown to its own random spot** round the hero, one every 4 ticks (the storm); on a plain bolt: each bolt leaves at a random angle within 60° of the aim |

With more than one ring or pulse each deals 0.85 of the hit (three rings: 2.55, "a bit less than 3 regular ones").
Each ring is its own root, so each feeds its own shock stack: three rings shock three times as fast and discharge
(the item's chain lightning) sooner. The random spots come from a named stream, `wand:swirl:<tick>:<launch>`, derived
from the run seed for that launch (nothing new saved; replays exactly).

The lead's five orders:

| Wand | Result | Shot |
|---|---|---|
| Ring | one lightning circle in front of you | `ao_shots/2_ring.jpg` |
| Ring · Spread | three circles round that spot, joined by shock arcs (covers ~3× the ground) | `ao_shots/3_ring_spread.jpg` |
| Spread · Ring | one circle that pulses three times on one spot | `ao_shots/4_spread_ring.jpg` |
| Ring · Spread · Swirl | three circles thrown out at random round you, one after another, a strike to each: the storm | `ao_shots/5_ring_spread_swirl.jpg` |
| Swirl · Ring · Spread | the three-circle group thrown as one to a random spot (arcs and strikes) | `ao_shots/6_swirl_ring_spread.jpg` |

(`ao_shots/1_plain_shot.jpg`: the plain shot. Rendered with
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/attack_order.gd`,
copied from `build/shots/v0.7.5-dev/ao/`; the look in play is OWNER ONLY.)

Visuals (presentation only): the rings use the existing storm ring (lightning round the edge); the rings of one
launch that start together are joined by shock arcs; a thrown ring gets a lightning strike from the hero as it lands
(`AttackFormView._sync_ring_arcs`, at most 12 a frame, the VfxLayer's storm line). The wand's tiles show each card's
slot and its mark (`3 · ← motion`); the order is changed on the Build page and the Swap panel as before (the reorder UI
already existed: WAND.md rule 4).

### Existing cards whose result now depends on order
- **Spread** and **Halo**: only when a Ring is in the wand (left of the Ring: pulses; right of it: rings). Without a
  Ring their bolts are exactly as before (`test_the_old_cards_results_dont_move`; the audit's 260 Gun pairs are part 1's
  234 plus the 26 that hold Ring or Swirl).
- **Split Shot** and the **triggers** with a Ring: built right of the Ring, their bolts come off every ring hit and are
  capped at 64 alive; left of the Ring, Ring reaches their children and they become rings too (rule 1, as before).
- No Blade card changes (312 of 496 pairs, as in part 1). No golden moves: `test_modifier_equivalence.gd` passes
  unchanged (its builds hold no Ring).

### Commands
```
godot --headless --path . -s scripts/checks/order_audit.gd -- "--chains=gun_ring,gun_ring+gun_spread,gun_spread+gun_ring,gun_ring+gun_spread+gun_swirl,gun_swirl+gun_ring+gun_spread"
godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --cards=<cards in wand order> --level=<1|5> [--dummies=1 --on-aim --sim-only]
```
The probe's cards: `none`, `gun_spread`, the five orders at level 1 (6 dummies, sim + WorldView; then 1 dummy on the
aim, sim only, for the single-target damage), and at level 5: the PF reference build `gun_spread,split_shot,shared_explosive`,
`gun_ring,gun_spread,gun_swirl`, `gun_spread,gun_ring,halo_shot,gun_swirl`, `gun_ring,gun_spread,halo_shot,gun_swirl,gun_echo`,
`gun_ring,gun_spread,split_shot`, `gun_spread,gun_ring,split_shot`. The probe now also prints `rings` (alive and
waiting) and `rings_capped` (ticks the ring cap held a launch back).

### Raw output: the order audit (the pair lists trimmed to the per-card counts and the pairs without a trigger or Split)
```
gun cards=32 pairs=496 order_matters=260 order_free=236
gun per-card order-sensitive pairs: shared_explosive=15 split_shot=31 frost_core=16 venom_core=16 trigger_on_kill_twice=31 trigger_on_kill=31 trigger_on_hit_twice=31 trigger_on_hit=31 trigger_on_finisher=31 trigger_on_end_twice=31 trigger_on_end=31 storm_core=15 shared_bleed=16 orbit_rounds=8 halo_shot=10 gun_twin=8 gun_swirl=9 gun_spread=10 gun_spiral=8 gun_ring=18 gun_ricochet=8 gun_rapid_fire=10 gun_pierce=8 gun_mine=15 gun_homing=8 gun_echo=8 gun_charge=8 gun_big_shot=10 gun_backfire=8 gravity_well=16 ember_core=16 boomerang=8
gun order-sensitive pairs without a trigger or Split: shared_explosive|frost_core shared_explosive|venom_core shared_explosive|storm_core shared_explosive|shared_bleed shared_explosive|gun_mine shared_explosive|gravity_well shared_explosive|ember_core frost_core|venom_core frost_core|storm_core frost_core|shared_bleed frost_core|gun_ring frost_core|gun_mine frost_core|gravity_well frost_core|ember_core venom_core|storm_core venom_core|shared_bleed venom_core|gun_ring venom_core|gun_mine venom_core|gravity_well venom_core|ember_core storm_core|shared_bleed storm_core|gun_mine storm_core|gravity_well storm_core|ember_core shared_bleed|gun_ring shared_bleed|gun_mine shared_bleed|gravity_well shared_bleed|ember_core halo_shot|gun_spread halo_shot|gun_ring gun_swirl|gun_ring gun_spread|gun_ring gun_ring|gun_rapid_fire gun_ring|gun_big_shot gun_ring|gravity_well gun_ring|ember_core gun_rapid_fire|gun_big_shot gun_mine|gravity_well gun_mine|ember_core gravity_well|ember_core
blade cards=32 pairs=496 order_matters=312 order_free=184
blade per-card order-sensitive pairs: blade_storm=24 shared_explosive=22 frost_core=21 heavy=9 wide_arc=11 whirl=11 venom_core=21 trigger_on_kill_twice=30 trigger_on_kill=30 trigger_on_hit_twice=30 trigger_on_hit=30 trigger_on_finisher=29 trigger_on_end_twice=30 trigger_on_end=30 thrust=13 storm_core=22 split_wave=2 shared_bleed=21 riposte_chain=21 parry_edge=7 lunge_step=7 long_shadow=13 gravity_well=22 flurry=8 fissure=21 finisher_plus=18 ember_core=22 echo_slash=25 double_slash=7 chain_cut=21 blade_orbit=21 counter=25
blade order-sensitive pairs without a trigger or Split: blade_storm|shared_explosive blade_storm|frost_core blade_storm|wide_arc blade_storm|whirl blade_storm|venom_core blade_storm|thrust blade_storm|storm_core blade_storm|shared_bleed blade_storm|riposte_chain blade_storm|gravity_well blade_storm|fissure blade_storm|finisher_plus blade_storm|ember_core blade_storm|echo_slash blade_storm|chain_cut blade_storm|blade_orbit blade_storm|counter shared_explosive|frost_core shared_explosive|venom_core shared_explosive|storm_core shared_explosive|shared_bleed shared_explosive|riposte_chain shared_explosive|long_shadow shared_explosive|gravity_well shared_explosive|fissure shared_explosive|finisher_plus shared_explosive|ember_core shared_explosive|echo_slash shared_explosive|chain_cut shared_explosive|blade_orbit shared_explosive|counter frost_core|venom_core frost_core|storm_core frost_core|shared_bleed frost_core|riposte_chain frost_core|long_shadow frost_core|gravity_well frost_core|fissure frost_core|ember_core frost_core|echo_slash frost_core|chain_cut frost_core|blade_orbit frost_core|counter heavy|thrust heavy|flurry wide_arc|thrust wide_arc|echo_slash wide_arc|counter whirl|thrust whirl|echo_slash whirl|counter venom_core|storm_core venom_core|shared_bleed venom_core|riposte_chain venom_core|long_shadow venom_core|gravity_well venom_core|fissure venom_core|ember_core venom_core|echo_slash venom_core|chain_cut venom_core|blade_orbit venom_core|counter thrust|echo_slash thrust|counter storm_core|shared_bleed storm_core|riposte_chain storm_core|long_shadow storm_core|gravity_well storm_core|fissure storm_core|finisher_plus storm_core|ember_core storm_core|echo_slash storm_core|chain_cut storm_core|blade_orbit storm_core|counter split_wave|echo_slash split_wave|counter shared_bleed|riposte_chain shared_bleed|long_shadow shared_bleed|gravity_well shared_bleed|fissure shared_bleed|ember_core shared_bleed|echo_slash shared_bleed|chain_cut shared_bleed|blade_orbit shared_bleed|counter riposte_chain|gravity_well riposte_chain|fissure riposte_chain|finisher_plus riposte_chain|ember_core riposte_chain|echo_slash riposte_chain|chain_cut riposte_chain|blade_orbit riposte_chain|counter long_shadow|gravity_well long_shadow|ember_core gravity_well|fissure gravity_well|finisher_plus gravity_well|ember_core gravity_well|echo_slash gravity_well|chain_cut gravity_well|blade_orbit gravity_well|counter fissure|finisher_plus fissure|ember_core fissure|echo_slash fissure|chain_cut fissure|blade_orbit fissure|counter finisher_plus|ember_core finisher_plus|echo_slash finisher_plus|chain_cut finisher_plus|blade_orbit finisher_plus|counter ember_core|echo_slash ember_core|chain_cut ember_core|blade_orbit ember_core|counter echo_slash|chain_cut echo_slash|blade_orbit echo_slash|counter chain_cut|blade_orbit chain_cut|counter blade_orbit|counter
chain gun_ring: form=2 count=1 ring_layout=1 pulses=0 share=850 swirl=0 swirl_group=0
  360 ticks: player hits=329 damage=2448 (408.0 per s) shock/storm events=408 rings alive max=7
chain gun_ring -> gun_spread: form=2 count=3 ring_layout=1 pulses=0 share=850 swirl=0 swirl_group=0
  360 ticks: player hits=590 damage=3920 (653.3 per s) shock/storm events=715 rings alive max=21
chain gun_spread -> gun_ring: form=2 count=1 ring_layout=1 pulses=3 share=850 swirl=0 swirl_group=0
  360 ticks: player hits=579 damage=4087 (681.2 per s) shock/storm events=759 rings alive max=13
chain gun_ring -> gun_spread -> gun_swirl: form=2 count=3 ring_layout=1 pulses=0 share=850 swirl=1 swirl_group=0
  360 ticks: player hits=532 damage=3574 (595.7 per s) shock/storm events=640 rings alive max=23
chain gun_swirl -> gun_ring -> gun_spread: form=2 count=3 ring_layout=1 pulses=0 share=850 swirl=0 swirl_group=1
  360 ticks: player hits=530 damage=3819 (636.5 per s) shock/storm events=694 rings alive max=21
```

### Raw output: the probe (each run's header, total, rings, projectiles, damage and verdict lines; the per-metric
table's other rows and the per-node costs trimmed)
```
perf_probe: gun + , level 1, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          2.939     4.689    12.649
projectiles       1.285     2.000     2.000
rings             0.000     0.000     0.000
rings_capped      0.000     0.000     0.000
damage: 534 over 10.0 s -> 53.4 per s (8.9 per s per dummy; DpsTally overall 53.8)
verdict: avg 2.94 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_spread, level 1, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          3.509     5.784    10.166
projectiles       7.030    12.000    12.000
rings             0.000     0.000     0.000
rings_capped      0.000     0.000     0.000
damage: 1107 over 10.0 s -> 110.7 per s (18.4 per s per dummy; DpsTally overall 111.3)
verdict: avg 3.51 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, level 1, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          4.075     5.896    12.351
projectiles       0.000     0.000     0.000
rings             2.000     2.000     2.000
rings_capped      0.000     0.000     0.000
damage: 3859 over 10.0 s -> 385.9 per s (64.3 per s per dummy; DpsTally overall 385.9)
verdict: avg 4.07 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, gun_spread, level 1, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          3.730     5.208    10.599
projectiles       0.000     0.000     0.000
rings             6.000     6.000     6.000
rings_capped      0.000     0.000     0.000
damage: 7084 over 10.0 s -> 708.4 per s (118.1 per s per dummy; DpsTally overall 712.0)
verdict: avg 3.73 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_spread, gun_ring, level 1, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          4.787     6.850    10.193
projectiles       0.000     0.000     0.000
rings             8.000     9.000     9.000
rings_capped      0.000     0.000     0.000
damage: 10710 over 10.0 s -> 1071.0 per s (178.5 per s per dummy; DpsTally overall 1071.0)
verdict: avg 4.79 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, gun_spread, gun_swirl, level 1, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          3.389     5.073    12.968
projectiles       0.000     0.000     0.000
rings             7.333     8.000     8.000
rings_capped      0.000     0.000     0.000
damage: 2788 over 10.0 s -> 278.8 per s (46.5 per s per dummy; DpsTally overall 278.8)
verdict: avg 3.39 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_swirl, gun_ring, gun_spread, level 1, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          4.324     6.589     9.127
projectiles       0.000     0.000     0.000
rings             6.000     6.000     6.000
rings_capped      0.000     0.000     0.000
damage: 2904 over 10.0 s -> 290.4 per s (48.4 per s per dummy; DpsTally overall 290.4)
verdict: avg 4.32 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + , level 1, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim only
total_ms          0.203     0.354     4.879
projectiles       2.970     5.000     5.000
rings             0.000     0.000     0.000
rings_capped      0.000     0.000     0.000
damage: 346 over 10.0 s -> 34.6 per s (34.6 per s per dummy; DpsTally overall 34.9)
verdict: avg 0.20 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, level 1, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim only
total_ms          0.184     0.311     1.044
projectiles       0.000     0.000     0.000
rings             2.000     2.000     2.000
rings_capped      0.000     0.000     0.000
damage: 542 over 10.0 s -> 54.2 per s (54.2 per s per dummy; DpsTally overall 54.2)
verdict: avg 0.18 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, gun_spread, level 1, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim only
total_ms          0.213     0.338     0.434
projectiles       0.000     0.000     0.000
rings             6.000     6.000     6.000
rings_capped      0.000     0.000     0.000
damage: 470 over 10.0 s -> 47.0 per s (47.0 per s per dummy; DpsTally overall 47.6)
verdict: avg 0.21 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_spread, gun_ring, level 1, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim only
total_ms          0.290     0.519     0.844
projectiles       0.000     0.000     0.000
rings             8.000     9.000     9.000
rings_capped      0.000     0.000     0.000
damage: 1440 over 10.0 s -> 144.0 per s (144.0 per s per dummy; DpsTally overall 144.0)
verdict: avg 0.29 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, gun_spread, gun_swirl, level 1, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim only
total_ms          0.293     0.589     1.323
projectiles       0.000     0.000     0.000
rings             7.333     8.000     8.000
rings_capped      0.000     0.000     0.000
damage: 378 over 10.0 s -> 37.8 per s (37.8 per s per dummy; DpsTally overall 38.6)
verdict: avg 0.29 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_swirl, gun_ring, gun_spread, level 1, 1 dummies, 10 s of held Shoot (+60 warm-up ticks), sim only
total_ms          0.271     0.521     4.239
projectiles       0.000     0.000     0.000
rings             6.000     6.000     6.000
rings_capped      0.000     0.000     0.000
damage: 332 over 10.0 s -> 33.2 per s (33.2 per s per dummy; DpsTally overall 33.6)
verdict: avg 0.27 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_spread, split_shot, shared_explosive, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          9.326    17.628    32.117
projectiles      96.663   217.000   237.000
rings             0.000     0.000     0.000
rings_capped      0.000     0.000     0.000
damage: 8718 over 10.0 s -> 871.8 per s (145.3 per s per dummy; DpsTally overall 871.8)
verdict: avg 9.33 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, gun_spread, gun_swirl, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          7.297    10.459    17.956
projectiles       0.000     0.000     0.000
rings            41.938    46.000    47.000
rings_capped      0.045     0.000     1.000
damage: 13526 over 10.0 s -> 1352.6 per s (225.4 per s per dummy; DpsTally overall 1352.6)
verdict: avg 7.30 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_spread, gun_ring, halo_shot, gun_swirl, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          5.197     7.630    10.765
projectiles       0.000     0.000     0.000
rings            41.130    46.000    46.000
rings_capped      0.112     1.000     1.000
damage: 4674 over 10.0 s -> 467.4 per s (77.9 per s per dummy; DpsTally overall 473.7)
verdict: avg 5.20 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, gun_spread, halo_shot, gun_swirl, gun_echo, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          6.463    10.060    15.583
projectiles       0.000     0.000     0.000
rings            43.693    48.000    48.000
rings_capped      0.112     1.000     1.000
damage: 4188 over 10.0 s -> 418.8 per s (69.8 per s per dummy; DpsTally overall 424.5)
verdict: avg 6.46 ms per tick+frame against 12.0 ms -> within
perf_probe: gun + gun_ring, gun_spread, split_shot, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms         13.362    21.017    35.671
projectiles      63.183    64.000    64.000
rings            22.000    22.000    22.000
rings_capped      0.000     0.000     0.000
damage: 39112 over 10.0 s -> 3911.2 per s (651.9 per s per dummy; DpsTally overall 3911.2)
verdict: avg 13.36 ms per tick+frame against 12.0 ms -> OVER
perf_probe: gun + gun_spread, gun_ring, split_shot, level 5, 6 dummies, 10 s of held Shoot (+60 warm-up ticks), sim + WorldView (headless: CPU side only)
total_ms          8.912    13.571    21.390
projectiles      64.000    64.000    64.000
rings            16.665    18.000    18.000
rings_capped      0.000     0.000     0.000
damage: 28687 over 10.0 s -> 2868.7 per s (478.1 per s per dummy; DpsTally overall 2868.7)
verdict: avg 8.91 ms per tick+frame against 12.0 ms -> within
```

### Target bands
| Metric | Target | Source |
|---|---|---|
| player shots alive | ≤ 256 | PERF.md (SimTuning.player_shots_max) |
| sim + sync + frame, per tick | under ~12 ms avg | PERF.md, PLAN O9 / PF |
| three rings' damage | a bit under 3 regular ones | O37; the lead's starting value 0.85 each |

### Result
| Build (level 5, 6 dummies) | Shots alive max | Rings max | Total avg / p95 / max (ms) | In band? |
|---|---|---|---|---|
| PF reference: Spread · Split · Explosive (same container, same session) | 237 | 0 | 9.33 / 17.63 / 32.12 | avg yes |
| Ring · Spread · Swirl | 0 | 47 | 7.30 / 10.46 / 17.96 | yes |
| Spread · Ring · Halo · Swirl | 0 | 46 | 5.20 / 7.63 / 10.77 | yes |
| Ring · Spread · Halo · Swirl · Echo | 0 | 48 (the cap) | 6.46 / 10.06 / 15.58 | yes |
| Ring · Spread · Split | 64 | 22 | **13.36** / 21.02 / 35.67 | **no: over by 1.36 ms avg** |
| Spread · Ring · Split | 64 | 18 | 8.91 / 13.57 / 21.39 | avg yes |

Every run kept under the 256-shot cap (at most 64 ring shards: the new cap). The worst order measured, **Ring ·
Spread · Split at level 5, is over the ~12 ms average** in this run; earlier runs of the same build in this session,
with the shard cap, gave 11.03 and 11.70 ms (the container is shared; not in the raw output above, which is the final
run). Before the two caps (pulses ≤ 5, ring shards ≤ 64 alive) the same two Split orders kept the 256-shot cap full
and measured 17.56 and 19.96 ms avg (also not in the raw output: an earlier run in this session, numbers copied from
its output). Reported, not retuned further: the rest is the Split shards' own cost, PF's p95 is over the same way.

Damage (starting values, untuned; the probe's DpsTally):
| Wand (level 1) | 6 dummies (per s) | 1 dummy on the aim (per s) |
|---|---|---|
| plain shot | 53.4 | 34.6 |
| Spread | 110.7 | — |
| Ring | 385.9 | 54.2 |
| Ring · Spread | 708.4 | 47.0 |
| Spread · Ring | 1,071.0 | 144.0 |
| Ring · Spread · Swirl | 278.8 | 37.8 |
| Swirl · Ring · Spread | 290.4 | 33.2 |

### Interpretation
- Order now matters for the three cards the owner named: the five orders compile to different attacks and fight
  differently (`tests/unit/sim/test_attack_order.gd`), and the audit's Gun count rose from 234 to 260 order-sensitive
  pairs (26 new: Ring's 18 and Swirl's 9, one shared). Swirl and Spread alone still commute (rule: a motion moves the
  rings; on bolts both just rewrite numbers), Ring is what makes them matter.
- The probe's crowd is tight, so the concentrated order (Spread · Ring: three pulses on the same ground) out-damages
  the spread one (Ring · Spread) both on the cluster and on one target, and the storm (random spots) lands less on a
  cluster. A wide horde should favour Ring · Spread and the storm; not measured here. The Ring itself is an area attack
  that hits every enemy in 2.5 m with the whole shot: ~7× the plain shot on 6 dummies, ~1.6× on one. All of this is
  the owner's call (OWNER_TODO D24); nothing was tuned to a number.
- Not proved: the feel, the look in motion, fps on the owner's PC (OWNER ONLY).
