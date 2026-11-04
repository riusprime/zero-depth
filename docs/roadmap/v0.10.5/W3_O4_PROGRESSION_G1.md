# W3-O4 G1: the progression audit (PLAN F18)

**Gate G1: measured, then proposals. No game code or data changed.** The owner approves the proposals row by row
("P1 yes, P2 no, P3 with change …"); nothing below is built before the answers.

## The owner's request (2026-11-04, summarised from the owner's words)

> "Picking a different attack form doesn't always feel like an upgrade over the default attack. Some forms are
> significantly more rewarding than others." "Wave + Fire + Venom already produced an extremely powerful build by
> Floor 2. Adding Chain Blast, Bleed, and Split created something resembling an endgame broken build before Floor 5.
> This doesn't happen in every run, but extreme power can arrive much too early." "Player power grows extremely quickly
> with certain combinations, but later progression feels limited … builds eventually hit a ceiling, with insufficient
> opportunities to continue scaling across multiple loops." "The strongest builds rely heavily on Wave or Void, stacked
> elements, and supporting upgrades such as Tuning. A small number of particularly powerful cards dominate upgrade
> decisions. Other interesting cards become less appealing … Elemental combinations contribute disproportionately to
> overall power." "The desired experience is to gradually build toward extreme power rather than reach it almost
> immediately and then plateau." Ideas, not solutions: "Additional scaling mechanics, miscellaneous cards, and the
> previously removed Attack Speed." Void is S-tier on purpose ("part of its appeal"): keep it on top.

Two things to check with the owner (Q1, Q2 at the bottom): **"Wave"** is two cards: the Blade's form (`echo_slash`,
"Wave") and the Gun's form (`gun_wave`, "Wave"). Fire + Venom + Bleed together fit only on the Blade (the Gun holds
two elements, `data/wand/attack_slots.tres` `gun_limits = [1, 1, 2, 2]`; the Blade has no element limit,
`blade_limits = [-1, 1, -1, -1]`), so the owner's run reads as the **Blade's** Wave; both are measured. **"Tuning"**
is no card name in `locale/strings.csv` (en or es); I could not tell which card it is.

## Build, machine, commands

- **Tree:** `3f53e3c2d38d6a9aa6907385bfd2ea53d4e53e70` (`claude/v0100-cleanup`, after W3-S2's Seekers +11 %,
  Glaive and Laser +15 %), plus the new script `scripts/balance/progression_audit.gd` (committed with this doc;
  the committed copy differs from the run's only in two header lines wrapped for the 120-column lint and a `%%` →
  `%` in section d's header).
- **Machine:** the owner's PC (i7-10700K), Godot 4.7.2 console build, `--headless`, six processes in parallel, each
  with its own `APPDATA`. No timing is claimed.
- **Lint:** not run locally (gdtoolkit is not installed on this machine); CI runs it.

```bash
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$G" --headless --path . --editor --import --quit
# each line with its own APPDATA; logs in build/progression_audit/log_<name>.txt (not tracked)
"$G" --headless --path . -s scripts/balance/progression_audit.gd -- section=a seconds=12
"$G" --headless --path . -s scripts/balance/progression_audit.gd -- section=b part=pairs seconds=12
"$G" --headless --path . -s scripts/balance/progression_audit.gd -- section=b part=tracks seconds=12
"$G" --headless --path . -s scripts/balance/progression_audit.gd -- section=c bases=gun_orbs,gun_void seconds=12
"$G" --headless --path . -s scripts/balance/progression_audit.gd -- section=c bases=blade_default,blade_wave seconds=12
"$G" --headless --path . -s scripts/balance/progression_audit.gd -- section=d seconds=12
```

Every log ends `determinism: MATCH` (the same Void + Fire + Venom crowd fight run twice, equal world hashes).

## Method (what a number means)

The fights reuse `tests/support/build_fight.gd`'s arena: the Playground's world (one walled room, every wand slot,
heat on, crit on, the hero unhurtable; the Gun holds Shoot and stands still; the Blade presses Primary every tick and
walks at the nearest dummy). The Lance is held to full charge and released (`forms_dps.gd`'s cycle). Each fight lasts
12 s.
- **single:** one endless dummy 5 m ahead (Gun) or 1.6 m (Blade, and the Rune Explosion, which bursts around the hero);
  DPS = all HP it lost, hits and damage over time (`DpsTally`).
- **crowd:** BuildFight's pack: 12 dummies in a 4 × 3 grid, a dead one back at its spot 1 s later (so on-kill effects
  count). DPS over the fight, and **clear s**: the time to kill the first 12 ("12+" = not cleared).
- **Crowd HP:** the Charger's floor-1 HP in the Playground (45) × `five_floors.tres`' floor HP factor / floor 1's
  (850 → 1380 / 1900 / 2620 / 3610) × 3.5 per loop past the first × the catch-up m, worked out with `CatchUp.multiplier`
  on the build's P at floor entry, E by floor, cap + 0.25 × T + 0.5 a loop, T = 2 a loop (as `run_state.gd:347-349`).
- **eff:** DPS ÷ (crowd HP / 45): DPS against floor 1's plain HP. A flat eff across floors means power grows as fast as
  enemy HP; a rising eff means the player out-grows the floors.
- **Tracks (section b3):** hand-written builds by floor, inside the slots (4/5/6/7/8 by floor, `wand.tres`) and the
  level ceilings (2/3/5/5, `pacing.tres`; Gun forms, patterns and secondaries have one level; elements, Twin, Halo, Split
  three). Every track also holds three offence stat cards a floor (Power / Haste / Precision round robin, common on
  floors 1-2, rare 3-4, epic 5: `three_curves.gd`'s bot). The tracks' cards are in the script (`TRACKS`).

**Limits of the method (read before the numbers):**
1. Dummies never move or attack: Counter and Parry Edge never trigger (they read 1.00), Bleed Lv 2's Open Wounds
   never pays, Frost's slow is worth nothing, and an endless standing dummy is the best case for returning and
   multi-hit attacks (Blade Storm's single-target number below must be re-checked on a moving boss: P8).
2. **The crowd has a ceiling:** 12 dummies coming back 1 s after death cap the crowd DPS near 12 × HP a second (540 on
   floor 1, ~2 300 on floor 5). A crowd number near the ceiling, or a clear under ~1.5 s, means "kills everything as
   it arrives"; differences above it are not visible. The clear time is the better crowd read on the strong builds.
3. One fixed seed (the Playground's), hand-picked builds, no rule cards' conditions met (Close Quarters, Third Strike
   count as their plain bonus), no O10 matchups (dummies have no weak form), no legendary boss picks.
4. Section c's Gun scene has the targets in a line ahead: Halo and Swirl (shots around the hero) read near 0 there.
   That is the scene, not the card (the O16/FC6 scenes cover them); they are left out of the ranking.

## The numbers

### a. Every form at its first level vs the default (no elements, no stats; crowd HP 45)

| Weapon | Form | Lv | Single DPS | × default | Crowd DPS | × default | Clear s |
|---|---|---|---|---|---|---|---|
| Gun | default (Orbs) | - | 33.7 | 1.00 | 51.8 | 1.00 | 12+ |
| Gun | Laser | 1 | 48.2 | 1.43 | 46.4 | **0.90** | 12+ |
| Gun | Void | 1 | 35.6 | 1.06 | 175.3 | **3.39** | 3.3 |
| Gun | Lance | 1 | 38.7 | 1.15 | 105.0 | 2.03 | 12+ |
| Gun | Rune Explosion (near) | 1 | 12.0 | **0.36** | 96.3 | 1.86 | 12+ |
| Gun | Glaive | 1 | 27.6 | **0.82** | 79.3 | 1.53 | 12+ |
| Gun | Seekers | 1 | 24.5 | **0.73** | 35.0 | **0.68** | 12+ |
| Gun | Wave | 1 | 37.8 | 1.12 | 249.0 | **4.81** | 3.0 |
| Gun | Wisps | 1 | 53.8 | 1.60 | 84.5 | 1.63 | 12+ |
| Blade | default | - | 47.8 | 1.00 | 160.8 | 1.00 | 4.4 |
| Blade | Wave (echo_slash) | 1 / 5 | 72.4 / 271.8 | 1.52 / **5.69** | 200.3 / 272.1 | 1.25 / 1.69 | 2.8 / 3.7 |
| Blade | Orbit Blades | 1 / 5 | 92.7 / 128.8 | 1.94 / 2.70 | 262.6 / 293.0 | 1.63 / 1.82 | 2.8 / 2.0 |
| Blade | Chain Cut | 1 / 5 | 47.8 / 47.8 | 1.00 / 1.00 | 258.4 / 405.0 | 1.61 / 2.52 | 2.4 / 1.0 |
| Blade | Fissure | 1 / 5 | 67.2 / 79.9 | 1.41 / 1.67 | 219.5 / 209.2 | 1.37 / 1.30 | 2.4 / 2.4 |
| Blade | Flurry | 1 / 5 | 41.0 / 42.9 | **0.86 / 0.90** | 158.8 / 161.5 | **0.99 / 1.00** | 3.5 / 4.6 |
| Blade | Heavy | 1 / 5 | 56.5 / 89.1 | 1.18 / 1.87 | 142.9 / 260.8 | **0.89** / 1.62 | 5.7 / 3.2 |
| Blade | Lunge Step | 1 / 5 | 47.8 / 47.8 | 1.00 / 1.00 | 182.5 / 139.2 | 1.14 / **0.87** | 3.4 / 8.5 |
| Blade | Counter, Parry Edge | 1 / 5 | 47.8; Parry L5 65.8 | 1.00; 1.38 | 160.8; 219.8 | 1.00; 1.37 | (need enemy attacks) |

- **Forms below the default on an axis at Lv 1:** Gun Seekers (both), Glaive and Rune Explosion (single), Laser
  (crowd); Blade Flurry (both, and it does not improve with levels), Heavy L1 (crowd), Lunge Step (crowd, and worse at
  L5: 0.87).
- **Two Gun forms dwarf the rest in a crowd:** Wave × 4.81 and Void × 3.39; the next is Lance × 2.03.
- **Gun forms have one level** (`level_max = 1` on all eight): taking a Gun form is a one-time step that never grows.
  Blade forms level to 5; Blade Wave grows the most (single × 1.52 → × 5.69).

### b1. Form × element (the element alone at Lv 1 / Lv 3, × the form alone)

Single × / crowd × the form alone (the full table, every form, is in the log):

| Form | Fire L1 / L3 | Venom L1 / L3 | Bleed L1 / L3 | Lightning L1 / L3 | Frost L1 / L3 |
|---|---|---|---|---|---|
| Gun Orbs | 1.56 / 1.57; 1.90 / 2.51 | 1.89 / 2.12; **3.41 / 4.12** | 1.44 / 2.71; 1.40 / 1.71 | 1.00 / 1.30; 1.71 / 2.99 | 1.00 / 1.05; 1.00 / 1.28 |
| Gun Void | 1.52 / 1.62; 1.32 / 1.35 | 1.80 / 2.03; 1.48 / 1.52 | 1.40 / 1.85; 1.17 / 1.18 | 1.00 / 1.28; 1.62 / 2.01 | 1.00 / 1.05; 1.00 / 1.18 |
| Gun Wave | 1.42 / 1.54; 1.16 / 1.36 | 1.57 / 1.79; 1.19 / 1.19 | 1.28 / 1.28; 1.00 / 1.00 | 1.00 / 1.26; 1.63 / 1.67 | 1.00 / 1.05; 1.00 / 1.00 |
| Gun Laser | 1.39 / 1.39; 1.48 / 2.16 | 1.62 / 1.78; **4.22 / 4.62** | 1.31 / 2.13; 1.12 / 1.29 | 1.00 / 1.19; 1.61 / 2.52 | 1.00 / 1.03; 1.00 / 1.24 |
| Gun Seekers | 1.78 / 1.78; 2.59 / 2.97 | 2.22 / 2.54; **5.14 / 5.75** | 1.61 / 3.32; 1.80 / 2.37 | 1.00 / 1.39; 1.87 / 3.57 | 1.00 / 1.00; 1.00 / 1.19 |
| Gun Glaive | 1.62 / 1.73; 1.96 / 2.19 | 1.90 / 2.21; 2.57 / 2.53 | 1.45 / 1.51; 1.11 / 1.11 | 1.00 / 1.27; 1.80 / 2.61 | 1.00 / 1.03; 1.00 / 1.00 |
| Blade default | 1.34 / 1.46; 1.40 / 1.64 | 1.52 / 1.67; 1.47 / 1.52 | 1.51 / 2.03; 1.21 / 1.26 | 1.00 / 1.33; 1.67 / 2.18 | 1.00 / 1.10; 1.00 / 1.02 |
| Blade Wave L3 | 1.11 / 1.23; 1.22 / 1.25 | 1.18 / 1.22; 1.27 / 1.36 | 1.18 / **2.21**; 1.08 / 1.08 | 1.00 / 1.31; 1.50 / 1.71 | 1.00 / 1.05; 1.00 / 1.09 |
| Blade Flurry L3 | 1.38 / 1.50; 1.43 / 1.70 | 1.59 / 1.76; 1.65 / 1.76 | 1.60 / 2.35; 1.23 / 1.25 | 1.00 / 1.32; 2.01 / 2.21 | 1.00 / 1.09; 1.00 / 1.04 |

- **One element card at Lv 1 is worth more than a Gun form on the single axis:** Venom L1 on the Orbs is × 1.89 single,
  × 3.41 crowd; the best form (Wisps) is × 1.60 / × 1.63. Elements' big gain is at Lv 1 (Venom L1 → L3 adds 12-30 %),
  so they front-load.
- **Venom is the best element on 5 of 6 Gun forms and lifts the weakest forms most** (Seekers × 5.14 crowd): the
  elements, not the forms, decide most of a Gun build's power. Frost adds almost nothing to damage (1.00-1.10; its
  value is the slow, which the dummies cannot show).

### b2. Element stacking on one form (each step adds one element at Lv 3)

| Build | Single DPS | × previous | × form alone | Crowd DPS | × form alone |
|---|---|---|---|---|---|
| Blade Wave L3 | 149.8 | - | 1.00 | 228.3 | 1.00 |
| + Fire | 184.5 | 1.23 | 1.23 | 285.9 | 1.25 |
| + Venom | 217.8 | 1.18 | 1.45 | 344.1 | 1.51 |
| + Bleed | 424.3 | **1.95** | 2.83 | 355.3 | 1.56 |
| + Lightning | 481.4 | 1.13 | 3.21 | 424.1 | 1.86 |
| + Frost | 541.8 | 1.13 | **3.62** | 422.3 | 1.85 |
| Blade default | 47.8 | - | 1.00 | 160.8 | 1.00 |
| + Fire, + Venom, + Bleed | 170.0 | 1.46, 1.47, 1.66 | **3.56** | 358.7 | 2.23 |
| + Lightning, + Frost | 203.9 | 1.11, 1.08 | **4.27** | 413.3 | 2.57 |
| Gun Void | 35.6 | - | 1.00 | 175.3 | 1.00 |
| + Fire, + Venom | 94.2 | 1.62, 1.64 | **2.65** | 299.8 | 1.71 |
| + Bleed, Lightning, Frost | 94.2 | 1.00 (no slot) | 2.65 | 299.8 | 1.71 |
| Gun Wave + Fire + Venom | 88.0 | 1.54, 1.51 | 2.33 | 318.8 | 1.28 |

- **Elements multiply, they don't add:** on the Blade default each of the first three elements adds × 1.46-1.66 to the
  previous total (an additive rule would shrink each step). Three elements: × 3.56 single; five: × 4.27. Bleed on top
  of Fire (X4 Boiling Blood, `element_pairs.gd`: "bleed ticks on a burning enemy are doubled") is the biggest single
  step (× 1.95 on Wave).
- **The Gun's two element slots already stop the stack** at × 2.33-2.65. The Blade has no element limit.

### b3. The stacked builds by floor and loop (eff = DPS against floor 1's plain HP)

Loop 1 (m = 1.00 on every floor of every track: P never reaches E, so the catch-up never acts in loop 1):

| Track | F1 eff single / crowd (clear s) | F2 | F3 | F4 | F5 | F5 / F1 single |
|---|---|---|---|---|---|---|
| Gun Orbs plain | 62 / 151 (12+) | 58 / 201 (4.1) | 62 / 210 (2.5) | 54 / 221 (2.4) | 85 / 329 (2.0) | × 1.37 |
| Gun Void + Fire + Venom | **92 / 308 (1.7)** | 65 / 262 (2.2) | 74 / 261 (2.1) | 72 / 280 (1.7) | 73 / 269 (2.0) | **× 0.79** |
| Gun Wave + Fire + Venom | **85 / 355 (1.5)** | 59 / 310 (2.0) | 69 / 331 (2.0) | 66 / 304 (1.9) | 77 / 298 (1.8) | × 0.91 |
| Blade plain | 84 / 294 (1.6) | 103 / 301 (1.9) | 128 / 304 (1.1) | **365** / 375 (1.2) | **2 017** / 395 (1.2) | × 24 |
| Blade Wave, no elements | 84 / 245 (1.6) | 134 / 263 (4.3) | 323 / 320 (1.1) | 623 / 383 (1.1) | **2 760** / 410 (0.8) | × 33 |
| Blade Wave + elements (the owner's) | **129 / 327 (1.4)** | 164 / 324 (1.3) | 312 / 360 (0.8) | 458 / 409 (0.8) | 794 / 422 (0.7) | × 6.2 |

Loops (the same track's F5 build plus 15 more stat cards a loop; the catch-up E restarts at floor 1's 1000):

| Track | L1 F5 eff single | L2 F1 (m) | L2 F5 (m) | L3 F1 (m) | L3 F5 (m) |
|---|---|---|---|---|---|
| Gun Orbs plain | 85 | **18 (2.50)** | 46 (1.00) | **7.0 (3.50)** | 18 (1.19) |
| Gun Void + Fire + Venom | 73 | **23 (2.50)** | 33 (1.17) | **7.5 (3.50)** | 11 (1.52) |
| Gun Wave + Fire + Venom | 77 | 19 (2.50) | 32 (1.17) | 5.8 (3.50) | 8.9 (1.52) |
| Blade Wave + elements | 794 | 32 (2.50) | 324 (1.17) | 10 (3.50) | 113 (1.52) |

Crowd clear time for the owner's build: 1.4 s on floor 1 → 0.7 s on floor 5 (at the ceiling: kills each enemy as it
arrives), 4.7 s on loop 2 floor 1, 12+ s on loop 3 floors 1-2.

### c. Which cards raise power most (one card added to a floor-3 build with floor-3 stats; × the base)

The base builds: Gun Orbs and Gun Void, Blade default and Blade Wave L3, each with nine floor-3 stat cards; crowd HP
101. "P ×" is what the catch-up's P sees of the same card (`catch_up.gd:36`: +12 % a level for a slot card, the stat
for a stat card).

| Card | Gun Orbs single / crowd | Gun Void single / crowd | Blade default single / crowd | Blade Wave single / crowd | P × |
|---|---|---|---|---|---|
| **Blade Storm L3** (legendary) | - | - | **47.76** / 1.90 | **14.43** / 1.47 | 1.35-1.48 |
| Blade Storm L1 | - | - | 1.75 / 1.45 | 1.24 / 1.28 | 1.18-1.24 |
| **Ring** (Gun pattern) | 1.14 / **6.01** | 1.00 / 1.04 | - | - | 1.19-1.24 |
| **Venom L1 / L3** | 1.61 / **3.30**; 1.77 / **3.97** | 1.65 / 1.46; 1.82 / 1.54 | 1.39 / 1.46; 1.50 / 1.53 | 1.13 / 1.38; 1.17 / 1.33 | 1.09-1.36 |
| Echo (Blade Wave) L3 | - | - | 3.10 / 1.34 | (base) | 1.36 |
| Mine | 1.55 / 2.76 | 1.14 / **0.60** | - | - | 1.10-1.12 |
| Double Slash L3 | - | - | 2.54 / 2.04 | 2.62 / 1.79 | 1.26-1.36 |
| Faultline | 1.54 / 2.46 | 1.98 / 1.61 | 1.64 / 1.63 | 1.83 / 1.65 | 1.18-1.24 |
| Chain Blast L1 / L3 | 1.28 / 2.12; 1.35 / 2.46 | **1.00 / 1.00** | 1.53 / 1.43; 1.69 / 1.38 | 1.52 / 1.55; 1.70 / 1.74 | 1.26-1.60 |
| Split Wave L3 / Split L3 | 1.00 / 1.73 | 0.92 / **0.69** | 2.33 / 1.99 | 1.93 / 1.44 | 1.26-1.48 |
| Bleed L3 | 2.27 / 2.09 | 1.71 / 1.19 | 2.02 / 1.32 | 2.13 / 1.27 | 1.26-1.36 |
| Lightning L3 | 1.30 / 3.27 | 1.34 / 2.06 | 1.35 / 2.21 | 1.30 / 2.14 | 1.26-1.36 |
| Fire L3 | 1.51 / 2.18 | 1.51 / 1.34 | 1.38 / 1.58 | 1.21 / 1.38 | 1.26-1.36 |
| Big Shot | 1.70 / 1.77 | 1.83 / 1.51 | - | - | 1.10-1.12 |
| Twin L3 | 0.72 / 1.63 | 1.99 / 1.42 | - | - | 1.39-1.48 |
| Chain Cut L3 | - | - | 1.00 / 2.28 | 1.00 / 2.04 | 1.26-1.36 |
| Echo (Gun) | 1.56 / 1.44 | 1.00 / 1.00 | - | - | 1.10-1.12 |
| Glass Cannon (rare stat) | 1.14 / 1.14 | - | 1.26 / 1.31 | 1.26 / 1.28 | 1.25 |
| Power (rare stat) | **1.00 / 1.00** | 1.15 / 1.07 | 1.12 / 1.30 | 1.13 / 1.12 | 1.11 |
| Haste (rare stat) | **1.00 / 1.00** | 1.12 / 1.14 | 1.03 / 1.06 | 1.06 / 1.05 | 1.10 |
| Precision (rare stat) | 1.03 / 0.99 | - | 1.03 / 0.99 | 1.02 / 1.10 | 1.02 |
| Close Quarters (rare) | 1.00 / 1.00 | - | 1.26 / 1.14 | 1.26 / 1.25 | **1.00** |

Cards that change **nothing** (≤ 1.05 on both axes) on a base they are allowed on:
- **Gun Void** (16 cards allowed, `attack_slots.tres` Form_void): Ring, Backfire, Pierce, Ricochet, Homing, Echo,
  Threadline, Spiral, Swirl, Chain Blast, Stress Mark, Halo; and three make it **worse**: Rapid Fire (crowd 0.40),
  Mine (crowd 0.60), Split L3 (crowd 0.69).
- **Gun Orbs:** Ricochet, Homing, Spiral, Stress Mark, Frost L1; Rapid Fire 0.89 crowd.
- **Blade:** Flurry (0.83-0.87 on both bases: a loss), Lunge Step (crowd 0.69 at L3 on the default), Riposte Chain
  single 1.00, Stress Mark single ~1.0.
- **Power and Haste on the Orbs read 1.00:** a rare +15 % / +12 % card moved nothing on that build. Not explained here
  (an integer step in the orb's damage or its shot period is the likely reason); a probe is part of P9.

### d. Where power stops growing

| Track | Extra stat floors | Stat cards | Power % | Haste raw % | Rate % | Precision % | Single DPS | × at L1 F5 |
|---|---|---|---|---|---|---|---|---|
| Gun Void + Fire + Venom | 0 / 5 / 10 / 15 | 15 / 30 / 45 / 60 | 71 / 196 / 321 / 446 | 54 / 144 / **150** / 150 | 52 / 97 / **100** / 100 | 29 / 69 / **75** / 75 | 310 / 838 / 1 195 / 1 558 | 1.00 / 2.71 / 3.86 / 5.03 |
| Blade Wave + elements | same | same | same | same | same | same | 3 371 / 8 333 / 11 978 / 15 580 | 1.00 / 2.47 / 3.55 / 4.62 |
| Gun Orbs plain | same | same | same | same | same | same | 360 / 926 / 1 428 / 1 828 | 1.00 / 2.57 / 3.97 / 5.08 |

What caps, from the data:

| Source of power | Cap | Reached |
|---|---|---|
| Slots | 4 / 5 / 6 / 7 / 8 by floor (`wand.tres`), then 8 for ever | floor 5 of loop 1 |
| Card levels | ceilings 2 / 3 / 5 / 5 by floor (`pacing.tres`); Gun forms, patterns, secondaries **1**; elements, Twin, Halo, Split **3**; Blade cards 5 | elements by floor 2-3; Gun forms on pick-up |
| Haste | raw cap +150 % (`attack_speed.tres` cap 2.5), through the curve: full to +50 %, half to +150 %, a quarter above (`attack_rate.gd`): rate +100 % at most | ~10 floors of stat cards (loop 2) |
| Precision | 75 % | ~10 floors of stat cards |
| Power, Glass Cannon | additive, no cap (Glass Cannon 3.0) | never; but each card is a smaller share of a growing sum (+25 % on +300 % is +6 %) |
| Shop | heal, reroll and four cards every second floor (W3-O9) | - |
| Loops | legendary chance +5 % a loop, one extra boss pick a loop (max 3) (`legendary/boss.tres`) | - |

Against that, **the challenge per loop is × 3.5 HP** (`loop_enemy_hp_permille = 3500`, compounding:
`run_state.gd:220`), and the catch-up's **E restarts at floor 1** while P carries, so the first floor of each loop
starts at the cap m (2.5 on loop 2, 3.5 on loop 3).

## Diagnosis (tied to the five pillars)

1. **Front-loaded power (pillar 3, "abrupt vertical spikes").** On the Gun the stack's power arrives with its first
   three cards: Void + Fire + Venom on floor 1 is eff 92 single / 308 crowd (clear 1.7 s) against the plain track's 62
   / 151 (12+), × 1.5 / × 2.0, and then **never grows faster than the floors** (F5 eff 73: × 0.79 of its F1). Its
   lead over the plain track is gone by floor 5 (73 vs 85 single). The cause: an element pays most at Lv 1 (b1), a Gun
   form has one level, and the Gun's two element slots fill on floor 1. So "extreme power almost immediately, then a
   plateau" is the Gun's measured shape: a step, not a ramp.
2. **The Blade has no element ceiling and its levels multiply (pillar 1 and 5).** Elements multiply (× 1.46-1.95 a
   step, b2), Wave/Double Slash/Split Wave levels multiply with them, and the legendary Blade Storm L3 multiplies the
   single-target number by × 14-48 (b3's floor-4/5 jumps to eff 2 000-2 760). The owner's Blade build clears 12
   floor-scaled enemies in 0.7-1.4 s on every floor of loop 1: the crowd is solved from floor 1.
3. **The catch-up is blind to what dominates (pillar 5; ECONOMY_MAP L12).** P counts every slot card as +12 % a level;
   the real gain of Venom L1 is +61 % / +230 %, Ring's crowd + 500 %, Blade Storm L3's single + 4 676 %. The one
   negative loop that should answer a strong build sees a flat number, and m stays 1.00 on every floor of loop 1 for
   all six tracks. Rule cards (Close Quarters × 1.26) are invisible to it entirely (P × 1.00).
4. **The late plateau is a cliff, not a ceiling (pillar 3).** After loop 1's floor 5 the only growth is stat cards:
   × 2.5-2.7 over the next five floors, × 1.4 over the five after (Haste and Precision hit their caps), × 1.3 after
   that. Enemy HP grows × 3.5 a loop on top of the reset m, so eff falls from 73 at L1 F5 to 23 at L2 F1 (÷ 3.2) and
   7.5 at L3 F1 (÷ 10) on the Gun stack. There is nothing renewable to take: slots, levels and forms are all full.
5. **Form parity (pillars 2, 5).** Four Gun forms and three Blade forms are below the default on one axis at their
   first level (a); Gun Wave and Void are × 4.8 / × 3.4 in a crowd, so the choice between forms is decided by crowd
   clear. A Gun form cannot be improved after it is taken.
6. **A few cards dominate, many are dead on the dominant forms (pillar 5).** The top single gains: Blade Storm, Blade
   Wave levels, Double Slash, Bleed L3, Faultline, Venom; the top crowd gains: Ring (on the Orbs), Venom, Mine (Orbs),
   Faultline, Lightning, Chain Blast. On the Void, 12 of its 16 allowed cards do nothing and 3 hurt (c): a Void player's
   real choices are Big Shot, Faultline, Twin and the elements, which is why the same few are always picked.
7. **Attack Speed is not removed:** Haste (`attack_speed.tres`, weight 10) is in the pool today; a rare one adds
   +3-14 % (c) because of the curve's knee at +50 % and the cap. What the owner remembers as removed may be Rapid Coil
   (O1's removal list, row 4: its effect moved into Rapid Fire) or the curve itself (v0.8.0 SG). Q3.

## Proposals (G1: approve row by row)

Expected effects are **estimates read off the tables above, not measurements**; each row's "verify" re-runs this
script (and the e2e and seams a code change needs).

| # | What | Why (finding) | Expected effect on the curve | Cost / risk | Verify | Rec. |
|---|---|---|---|---|---|---|
| **P1** | **Elements add with diminishing returns on one target.** Each element's damage on an enemy that already carries k other elements counts at 100 / 70 / 50 / 35 % (k = 0 / 1 / 2 / 3+), data in `element_pairs.tres`. Pair rules (X1-X10) stay. | b2: elements multiply (× 1.46-1.95 a step); the Blade's five reach × 4.27. | Blade default + 5 elements × 4.27 → ~× 2.5; owner's Blade stack F1 eff 129 → ~105, F5 794 → ~520. Gun pair × 2.65 → ~× 2.2. | Medium: sim code in the status damage path; goldens move (named). Elements still the best single card. | b2 and b3 tables: no stacking step above × 1.35 after the first element. | **Yes** |
| **P2** | **Synergy gates by floor: element levels follow the floor.** Element ceilings Lv 1 on floor 1, Lv 2 on floors 2-3, Lv 3 from floor 4 (`pacing.tres`: a ceiling per category), and move part of each element's Lv 1 power to Lv 2-3 (e.g. Venom L1 × 0.75 of today's, L3 × 1.15). | a/b1/b3: the Gun stack peaks on floor 1 (eff 92 → 73 at F5); Venom L1 is most of Venom. | Gun Void stack F1 eff single 92 → ~75, F5 73 → ~85: the curve rises across the run instead of falling (F5/F1 × 0.79 → ~× 1.15). | Low-medium: data plus a ceiling per category in LootPacing; offers change, goldens move. | b3: every track's F5/F1 eff ≥ 1.1 in loop 1; no floor-1 crowd clear under 2 s. | **Yes** |
| **P3** | **Renewable scaling across loops: overlevels.** From loop 2, each card's level cap is +1 a loop (Gun forms and one-level cards Lv 2-3, elements Lv 4-5, Blade cards Lv 6-7), each overlevel +15 % of that card's effect; offered on altars, chests and the shop like a level-up. | d: after loop 1 slots and levels are full; only stat cards grow (× 1.4 then × 1.3 per five floors). | Adds ~× 1.4-1.7 a loop on an 8-card build (8 cards × 15 % compounding over levels), so L2 F5 eff on the Gun stack 33 → ~50. | Medium: CardLevels / LootPacing / forecast / HUD level pips; art: none (pips exist). Engine-preserving (pillar 1: cards grow, not stats). | b3 loop rows; the every-card soak at the new levels. | **Yes** |
| **P4** | **The loop curve meets the build: E continues across loops, loop HP × 3.5 → × 2.5.** The catch-up reads E (and its cap) by run floor (6-10 continue the 1000 / 2000 / 4000 / 7000 / 11000 steps, e.g. 16000-40000), so a loop's first floor no longer starts at the cap; `loop_enemy_hp_permille` 3500 → 2500. | b3: L2 F1 m = 2.50, L3 F1 = 3.50; eff ÷ 3.2 then ÷ 10 per loop. | L2 F1 eff on the Gun stack 23 → ~45-55 (m ~1.0-1.3 and HP × 2.5); with P3, loop 2 ends near loop 1's level instead of a third of it. | Low: data (`catch_up.tres` 10 entries, `five_floors.tres`); boss pace entries for loop floors too. Loops get easier: Q4. | b3 loop rows; `loop_scaling.gd`, boss_pace_probe on loop floors. | **Yes** |
| **P5** | **Form parity: every form ≥ the default at Lv 1 on both axes, ≥ × 1.3 on its own axis; Void stays the top.** Gun: Seekers single and crowd to ≥ 1.0 / 1.3, Glaive single ≥ 1.0, Rune Explosion single ≥ 0.8 (it is a near form), Laser crowd ≥ 1.0; Wave crowd × 4.8 → ~× 3.0 so Void (× 3.4) is the crowd top. Blade: Flurry ≥ 1.1 both and gains with levels, Lunge Step not worse with levels, Heavy L1 crowd ≥ 1.0. | a: seven forms below the default on an axis; Wave above Void. | The form pick becomes a choice of style, not of "Wave or Void". | Low-medium: data per form (`attack_slots.tres` params, form items), one step a form like W3-S2. | Section a: every row ≥ 1.00. | **Yes** |
| **P6** | **Dominant cards: verify, then trim.** (a) **Blade Storm L3**: re-measure on a moving boss (Playground summon) and, if × 10+ holds, add a per-target hit rate (one hit per returning blade per target per pass). (b) **Ring on the Orbs** (crowd × 6.0): check it on the shipped scene (O16) and trim its share if it holds. (c) **Venom**: covered by P2's level shift. | c: × 47.8 / × 6.0 / Venom best on 5 of 6 forms. | Blade plain F5 eff single 2 017 → a few hundred; Orbs + Ring stops being the only crowd answer on the default. | (a) sim code in hits (goldens), (b)-(c) data. | c and b3 after; the every-card soak. | **Yes** |
| **P7** | **No dead pairs: prune or give every allowed card an effect on each form.** Void: 12 no-ops and 3 losses (Rapid Fire 0.40, Mine 0.60, Split L3 0.69); Orbs: Ricochet, Homing, Spiral; Blade: Flurry, Riposte single. Either the form's `allowed` drops them (they stop being offered) or each gets a form-specific effect (a Void Echo = a second pull, etc.). | c: pillar 5 (no mathematically dead loot); the dominant few are the only live choices. | Choices per Void pick from ~4 live cards to ~10 (prune) or ~16 (effects). | Prune: data, low. Effects: one G2/G1 per form, medium-high. | c: no allowed card ≤ 1.02 on both axes. | **Yes (prune now, effects later)** |
| **P8** | **Haste made renewable, not stronger early.** Keep today's curve for loop 1; each loop raises Haste's raw cap +50 % and moves the curve's knees +50 % (`sim.tres`, read by loop). | d: Haste caps at rate +100 % by ~10 stat floors; owner idea "Attack Speed". | + ~25 % rate a loop for a build that keeps taking Haste: a slow, renewable stat channel. | Low: data and AttackRate reads the loop. Pillar 1 risk: a flat stat; it multiplies procs too. | d with loops. | Optional (P3 first) |
| **P9** | **Precision for small stat cards on small hits.** Probe why rare Power / Haste read × 1.00 on the Orbs (c); if it is integer rounding of a small base damage or a whole-tick period, carry damage in tenths (or the period's remainder) so every +% shows. | c: two of the three most common stat cards did nothing on the default Gun. | Every stat card ≥ its nominal gain on every form. | Probe low; a fix may be a direct fix (one cause, one correction) or touch damage maths (goldens). | A probe line per stat card on the Orbs. | **Yes (probe)** |
| **P10** | **The catch-up reads card weights.** Each card gets a `power_weight_permille` in data from section c (Venom 1.6, Ring 2.0, Blade Storm 3.0 a level …) instead of the flat 12 %, so m answers a dominant build. | Diagnosis 3: P is blind (m = 1.00 everywhere in loop 1). | Strong builds get m 1.2-1.6 on floors 2-5. | Medium; a hidden rubber band that punishes good picks (pillar 5 risk; the owner liked builds feeling strong). | b3: m by floor. | No (P1, P2, P6 fix the cause) |

**Recommended set: P1, P2, P3, P4, P5, P6, P7 (prune), P9 (probe).** P8 optional after P3; P10 not recommended.

Order if approved: P9 probe and P6(a) check first (they may change the picture), then P2 + P1 (front-loading), P5 + P7
(forms and dead cards), then P3 + P4 together (loops), then re-run this audit.

## Questions for the owner

- **Q1.** Your Wave + Fire + Venom + Bleed run: the Blade's Wave (crescents) or the Gun's Wave? (Bleed as a third
  element fits only on the Blade.)
- **Q2.** Which card is "Tuning"? No card has that name in English or Spanish.
- **Q3.** "The previously removed Attack Speed": Haste is in the pool today (weight 10). Did you mean Rapid Coil (removed
  in O1), or that Haste feels too weak (the curve halves it above +50 %)?
- **Q4.** P4 makes loops easier than today. Should loop 2 end near loop 1's power (the table's target), or should loops
  stay a wall that only strong builds climb?

## Decisions (owner, date)

| # | Answer | Built in |
|---|---|---|
| P1 | Approved (owner, 2026-11-04: "Approve the set") | — |
| P2 | Approved | — |
| P3 | Approved; it is the way through the loops (see P4) | — |
| P4 | **Not as written.** Owner: loops stay "A wall"; "to overcome loop difficulty we need a way of scale the player build further in strength so loops feel more difficult but possible to overcome, based on the strength of the build". So loop HP stays × 3.5 and the catch-up is unchanged; P3 (overlevels) is sized so a build that keeps investing can climb loop 2–3 and a weak one cannot | — |
| P5 | Approved; built (W3-P5). Wave: its run halved (10.8 → 5.4 m), owner 2026-11-04: "Keep shorter reach" | W3-P5 |
| P6 | Approved; measured (PROGRESS W3-P6): Storm × 1.65–3.80 on real bosses, Ring × 2.2 on a real floor: under the trim line, no trim | — |
| P7 | Approved (prune) | — |
| P8 | Not wanted: Q3 below | — |
| P9 | Approved; probed (two roundings). Owner, 2026-11-04: "lets do only A then": carry the damage and shot-timer remainders (not tenths, not a bigger slower bolt) | — |
| P10 | Not recommended, not picked | — |

Owner's answers to the questions (2026-11-04):
- **Q1:** "Gun's Wave". (So the owner's run stacked Fire + Venom on the Gun's Wave; Bleed came from elsewhere.)
- **Q2:** not answered yet.
- **Lance ball (W3-O7):** "A: element fireball". **Violet bolt:** "before chosing i'd like to see comparations with new assets from the premade pack … that I added" → W3-O7b.
- **Q3:** "we nerfed it so it doesnt get crazy and new attack forms are way slower so you never get +20 attacks in a
  second that's what I meant with that": the attack-speed nerf is intended; Haste stays as it is (P8 not wanted).
- **Q4:** "A wall"; with P4 as above.
