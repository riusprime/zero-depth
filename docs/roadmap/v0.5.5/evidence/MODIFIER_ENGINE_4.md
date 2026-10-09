# Step MX4: the modifier engine, stage 4 (v0.6.0): the M-list's modifiers

Design: [`../../../design/MODIFIER_ENGINE.md`](../../../design/MODIFIER_ENGINE.md) ("Order of work" step 4). PLAN rows
B2–B9 and the M-list M1–M30 (owner: "keep all M1–M30", 2026-10-08). Contracts:
[`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8d; [`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md)
"Modifiers" and "Item rarity".

## What was built
- **All 30 modifiers M1–M30 as data** (`data/modifiers/<id>.tres`, each a `ModifierDefinition` of ops, and a card
  `data/items/<id>.tres` of the new kind `MODIFIER` that names it), names and descriptions in en and es, a card family
  each (`CardFrames.FAMILY_OF`; trinkets indigo), plus three **legendary versions** for the boss's tier.
- **The runner features the list needed, each general** (SIM_CONTRACTS §8d): hook triggers `ON_END` (in data),
  `ON_LAUNCH`, `EVERY_NTH`; a hook's delay (the launch queue) and its `when` (Overclock); a hook's child ops;
  the child form `WEAPON` (a copy of the weapon's last attack); `directions` (circle), `back_permille`, `aim_offset`;
  `chains` (a beam that chains on), `homing`, `returns`, `orbit_ticks`, `pierce` on projectiles (`ProjectileMoves`),
  `intangible` (the dash); `pull_m` (a burst that pulls); the virtual `range`; form changes that keep the attack's
  reach (`SpecForms.change_form`); `mirror` (Mirror Drone, Blade Orbit); compile-time **lineage** (a modifier never
  rides its own hook's child); repeats for every root attack (Twin Cast); the poison engine (`Venom`); the body rules
  (Aether Shell, Ascension, Resonance; `ModifierRuntime`).
- **MX2's gaps closed:** the dash, walking, a blink and Vent launch from specs (`dash`, `move`, `blink`, `vent`
  base specs; Vent's blast runs through `Attacks.launch` with the v0.5 numbers); an inherited every-N status counts its
  own form's hits (`ModifierRuntime.every_hit`); Cluster Payload, Overclocked Drone and Afterimage are modifiers of ops.
- **Offer pools:** the cards join the item pool (altars, chests, the shop, an elite's core draw them; trinkets and the
  merges are rare; a merge only while its ability is held, `requires_ability`; a heat card only with heat). Rarity
  `LEGENDARY` is drawn only by the boss's legendary altar and a boss's core: `data/legendary/boss.tres` now offers the
  three legendary versions and the five trinkets (plus the legendary stat cards, unchanged). `CoreTheft` draws from
  the same pools. `CatchUp.power` (still the one function) counts a slot's M-list card as 1, rare 2, legendary 3.
- **Views:** every card shows through its spec (form, count, directions, elements, hooks: MX3 draws them). An overlay
  only where no spec shows it, in its own file `src/presentation/world_view/modifier_overlays.gd` (`ModifierOverlays`,
  three lines in `world_view_root.gd`): Aether Shell's shell, Ascension's charged ring, Phase Dash's veil, a drop over
  poisoned enemies, a mark where a queued launch (Long Shadow, Twin Cast) will fire. Read through
  `WorldReader.modifier_marks`. Nothing of the v0.5.9 visual rework touched.
- **Dev panel:** `NextMod` picks the card `GrantMod` gives (TEST HELPER for the e2e; string `UI_DEV_NEXT_MOD`).

## M1–M30 as built (every number a starting value)
Target: the tags a spec must carry (empty = every attack: the weapon's, the Skill's, the abilities', a hook's; never
the moments `dash`/`move`/`blink`/`body`). Stage in brackets. Rarity c = common, r = rare (indigo = trinket).

| # | Id | Card (en / es) | Target | Ops | Reading I chose |
|---|---|---|---|---|---|
| M1 | `storm_core` | Storm Core / Núcleo de Tormenta, c, area | all | ELEMENT storm; HOOK ON_HIT BEAM reach 4 m, 500 ‰, child `chains 1` | "chain to 2 more" = the jump plus one further jump, each to the nearest enemy not hit yet |
| M2 | `ember_core` | Ember Core / Núcleo de Brasa, c, fire | all | STATUS burn 1; ELEMENT ember; HOOK ON_KILL BURST 1.5 m, 600 ‰ (ember) | burn engine numbers on the card (2 a tick-period of 0.5 s, 3 s, 5 stacks) |
| M3 | `frost_core` | Frost Core / Núcleo de Escarcha, c, projectile | all | STATUS slow 1; STATUS frost 1 (every hit); ELEMENT frost | **merged** with the v0.5 Frost Core item (same id): now every attack and both weapons; frost threshold 4 → 3, so the 3rd hit (each one slows) freezes for 1 s |
| M4 | `venom_core` | Venom Core / Núcleo de Veneno, c, damage | all | STATUS poison 1; ELEMENT venom | a new poison engine: 2 per stack each 0.5 s for 4 s, 8 stacks, a death spreads its stacks within 2.5 m |
| M5 | `echo_slash` | Echo Slash / Tajo Eco, c, time | melee | HOOK ON_LAUNCH BOLT r 0.35, 600 ‰, child 14 m/s, 0.5 s | a crescent as wide as the arc, on every slash (the Twin Arc echo and Rearguard's back slash too); Blade only |
| M6 | `edge_rounds` | Edge Rounds / Balas Filo, c, damage | projectile | ADD pierce 1; HOOK ON_HIT ARC reach 1.1 m, 100°, 500 ‰ | the slash faces the projectile's way |
| M7 | `shock_circles` | Shock Circles / Círculos de Choque, r trinket | projectile | SET_FORM RING; STATUS shock 1; ELEMENT storm | the ring grows from the player to half the shot's flight (1.5–6 m) over 0.3 s; shock numbers on the card |
| M8 | `halo_shot` | Halo Shot / Disparo Halo, r trinket | projectile | MUL count ×3; SET directions circle; MUL range ×0.5 | ×3 of the shot's count, evenly round (a plain Gun: 3) |
| M9 | `boomerang` | Boomerang / Bumerán, r trinket | projectile | SET returns 1 | turns back at half its life, passes through every enemy both ways, ends at the player |
| M10 | `orbit_rounds` | Orbit Rounds / Balas en Órbita, r trinket | projectile | SET orbit_seconds 0.5 | circles the player at 1.4 m for 0.5 s, then leaves along its aim |
| M11 | `split_shot` | Split Shot / Disparo Dividido, c, projectile | projectile | HOOK ON_HIT BOLT r 0.12, reach 4 m, 500 ‰, child count 3, 90° fan | splits on each hit, never the splits (lineage) |
| M12 | `twin_cast` | Twin Cast / Doble Lanzamiento, c, time | all | SET repeat 0.2 s; MAX repeat damage 500 ‰ | a root attack repeats from where the player is then; a combo step repeats through its Twin Arc echo (one echo; with Twin Arc the later pick's delay wins) |
| M13 | `rearguard` | Rearguard / Retaguardia, c, projectile | all | MAX back_damage_permille 600 | arcs, shots, beams and bombs only (round forms have no back) |
| M14 | `wide_arc` | Wide Arc / Arco Amplio, c, area | all | ADD arc 40°; MUL radius ×1.3 | the radius also grows bursts, rings and patches |
| M15 | `gravity_well` | Gravity Well / Pozo Gravitatorio, c, dash | all | HOOK ON_HIT BURST 2.5 m, 200 ‰, child pull 0.8 m, void | bosses are not pulled |
| M16 | `shatter` | Shatter / Estallido, c, projectile | all | HOOK ON_KILL BOLT r 0.12, reach 3.5 m, 400 ‰, child count 4 circle | |
| M17 | `aftershock` | Aftershock / Réplica, c, area | all | HOOK ON_END BURST 1.2 m, 400 ‰ | every attack's end (bombs, rings, bursts too), not only arcs and projectiles |
| M18 | `seeker` | Seeker / Buscador, r, projectile | all | SET homing 360°/s | projectiles turn 6° a tick toward the nearest enemy within 8 m; an arc snaps to the nearest within its reach + 2 m |
| M19 | `long_shadow` | Long Shadow / Sombra Larga, r, dash | dash | HOOK ON_LAUNCH WEAPON 800 ‰, delay 0.15 s | the afterimage swings or shoots your last attack (the Blade's current step at its last swing's angle; the Gun's shot at the aim) where the dash began |
| M20 | `phase_dash` | Phase Dash / Esquiva de Fase, r, dash | dash | SET intangible; HOOK ON_END BOLT r 0.12, reach 4 m, 12 flat, child 6 circle, void | i-frames and no body collisions for the whole dash |
| M21 | `ember_trail` | Ember Trail / Rastro de Brasas, c, fire | move | HOOK ON_LAUNCH ZONE 0.7 m, 3 flat, child burn 2, ember, 2.5 s, a hit each 0.5 s | a patch every 1.4 m walked (not dashing); burn 2 at the hook's 50 % proc = 1 stack |
| M22 | `aether_shell` | Aether Shell / Coraza de Éter, r, healing | body | SET barrier 3 s | out of combat = no damage dealt or taken (the regen's clock); the absorbed hit restarts it |
| M23 | `ascension` | Ascension / Ascensión, r, crit | body | SET charge 3 s, ×3 | "attacking" = a root weapon or Skill attack |
| M24 | `resonance_core` | Resonance / Resonancia, r, damage | body | SET resonance 150 ‰ | per status on the enemy: burning, shocked, bleeding, chilled or frozen, slowed, poisoned. Id `resonance_core` because the v0.3 combo is also called Resonance (see owner questions) |
| M25 | `heat_sink_rounds` | Heat Sink Rounds / Balas Disipadoras, r, fire | weapon | HOOK ON_LAUNCH BOLT r 0.15, reach 9 m, 600 ‰, when Overclock, child aim +8° | the Blade at Overclock also throws a bolt; heat runs only |
| M26 | `meltdown_edge` | Meltdown Edge / Filo de Fusión, r, fire | vent | HOOK ON_LAUNCH WEAPON 1000 ‰, child circle, count 8 | the Blade: the current step as a full-circle arc; the Gun: 8 shots round; Meltdown's overheat blast counts as a vent |
| M27 | `mirror_drone` | Mirror Drone / Dron Espejo, r, projectile | drone | SET mirror 1 | a Gun drone copies the shot's pattern and behaviour; a Blade drone throws crescents as wide as the arc; every hook of the weapon (MX2 gave ON_HIT / ON_KILL) |
| M28 | `bomb_rounds` | Bomb Rounds / Balas Bomba, r, area | weapon + projectile | HOOK EVERY_NTH 5 LOB 1.6 m, reach 5 m, 1500 ‰, 0.5 s | needs Bomb Lobber held and the Gun; the bomb is a `bomb` (Cluster Payload splits it) |
| M29 | `blade_orbit` | Blade Orbit / Órbita de Hojas, r, damage | orbit | SET mirror 2; ADD count 1 | MX2 already carried the weapon's element and ON_HIT / ON_KILL hooks on every ability (owner B7), so the card adds the rest: the weapon's ON_END / ON_LAUNCH hooks fire on each touch, and +1 blade |
| M30 | `short_fuse` | Short Fuse / Mecha Corta, r trinket | all | MUL range ×0.6; MUL damage ×1.4 | "range" = an arc's reach, a bolt's flight, a ring's, burst's or patch's radius |

Legendary (rarity `LEGENDARY`, the boss's tier only): `tempest_core` (M1+: chains 3 at 750 ‰, reach 5 m),
`inferno_core` (M2+: burn 2, the kill burst 2.5 m at 1000 ‰ burning 2), `echo_storm` (M5+: 3 crescents in a 40° fan
at 800 ‰). The ability mods' modifiers: `cluster_payload` (bomb: ON_END LOB 3 evenly round at 2 m, 1 m, 400 ‰,
0.25 s), `overclocked_drone` (drone: heat rate 8 ‰ per heat point), `afterimage` (blink: ON_LAUNCH BURST 1.8 m, 18,
0.4 s later).

### Overlaps with v0.5 items (how they merged)
- **Frost Core (M3)** is the v0.5 item, generalised (one card, same id; the equivalence fixture's Frost Core cases
  changed on purpose, below).
- **Ember Core (M2)** and Ember Edge / Cinder Shot: kept apart (Ember Edge is the Blade's, Cinder Shot the Gun's every-3rd
  burn; Ember Core burns everything and adds the kill burst). They share the burn engine; the strongest numbers win.
- **Storm Core (M1)** and Static Chain: kept apart (Static Chain shocks and chains every 3rd bolt; Storm Core chains
  every hit of every attack).
- **Twin Cast (M12)** and Twin Arc: one repeat per attack; on a combo step both set the same echo (the later pick's
  delay, the higher share).
- **Wide Arc (M14)** and Long Edge: they stack (width vs reach).
- **Heat Sink Rounds (M25)** / **Meltdown Edge (M26)** and Heat Sink / Meltdown: kept apart (the v0.5 items change
  the vent's numbers and the overheat).
- **Long Shadow (M19)**, **Phase Dash (M20)** and Kinetic Dash / Phase Strike / Afterimage: kept apart.
- **Resonance (M24)** and the v0.3 combo Resonance (Overcharge + Twin Arc): different effects, the same name.

## Tests added or changed
- New: `tests/unit/sim/test_mx4_modifiers.gd` (M1–M15) and `test_mx4_modifiers_2.gd` (M16–M30, the legendaries,
  the three ability mods as modifiers, the dash and Vent as specs, the every-N rule on inherited forms): each card's
  rewrite and its effect in a scripted scenario; `tests/unit/sim/test_modifier_smoke_mx4.gd` (every modifier card held
  alone on each weapon and replayed, every card with the six ability modifiers, every pair, the M-list all at once and
  replayed, and a snapshot taken mid-fight round-tripping and playing on the same); `tests/e2e/test_e2e_modifiers_mx4.gd`
  (Echo Slash + Split Shot through `main.tscn`: the crescent splits in three where it hits); `tests/support/mx4_world.gd`.
- Updated: the counts (`test_item_validation` 63 items, `test_modifier_validation` 51 modifiers + MX4 validation and
  conversion cases, `test_modifier_smoke` 51), `test_combo_validation` (the 3–4 members per engine rule counts the
  v0.3 items, not the M-list's cards), `test_card_pool` (Cluster Payload's bomblets deal 8, the hook rule's round-down
  of 40 % of 22; the bomblet fields left the item).

NOT YET RUN: the results below are filled from the runs.
