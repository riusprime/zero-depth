# Step MX2: the modifier engine, stage 2 (v0.6.0): the build model

Design: [`../../../design/MODIFIER_ENGINE.md`](../../../design/MODIFIER_ENGINE.md) "The build" (owner B7, B8) and "Order
of work" step 2. Contracts: [`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8c;
[`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md) §2 "Modifiers", §8 abilities;
[`PRESENTATION_CONTRACTS.md`](../../../architecture/PRESENTATION_CONTRACTS.md) §4, §9; BLUEPRINT §C, §D; PD-08.

## What was built
- **The build model** (`BuildSlots`): the weapon (with its Skill, dash, Vent; it still levels), one utility pick
  (Blink or Aegis) outside the slots, six modifier slots in pick order (`World.mod_slots`, the layer order the
  compile uses), unlimited stat cards. A held modifier levels up (1–5) without a slot. A new one with the six full
  needs a **Swap**: it replaces the chosen slot in place, or the player skips. The swap is a sim choice
  (`World.swap_code/source/ref`, answered by `InputFrame.pick` = `PICK_SWAP_BASE + n` / `PICK_SWAP_SKIP`) at the
  altar or chest pick (skip: back to the cards), the shop (skip: back to the shop; paid only on the answer) and
  for a card with no panel (an event's card, a floor pickup, the dev panel: the world waits; skip leaves the card).
  CU's core theft (`CoreTheft.grant`) opens a drop through the pick panel, so a stolen modifier goes through the
  same Swap. Salvage at the shop frees a modifier's slot (refund as before).
- **The six old abilities are weapon modifiers**, each launching its compiled spec (its v0.5 numbers at its level)
  that carries the weapon's statuses, elements and ON_HIT / ON_KILL hooks (`Modifiers.inherit`; the drone's copy of
  a Gun also its pattern and behaviour): Bomb Lobber lobs (form `LOB`) on every 4th weapon attack once its 2.5 s
  cooldown is ready; the drone fires a copy of the weapon's attack; Orbit Blades are orbiters (`ORBITER`); Arc
  Field leaves a shock field (`ZONE`) where an attack ends; Frost Nova gives the weapon the frost element
  (`data/modifiers/frost_nova.tres`) and sends a ring (`RING`) on a streak of 4 kills each within 2 s; Flame Trail's
  dash and projectiles leave fire (`ZONE`). Blink and Aegis stay the utility. The four ability mods are modifier
  cards (a slot each), offered only with their parent: Razor Orbit became a modifier on the orbit spec
  (`data/modifiers/razor_orbit.tres`, bleed); Cluster Payload, Overclocked Drone and Afterimage keep their numbers in
  `ItemMods` (their effects have no op yet: bomblets, a heat rate, a delayed echo) and target their parent through
  `requires_ability`.
- **Runners** for `LOB`, `ZONE`, `RING`, `ORBITER`, ON_END for bolts (where a projectile ends), and **projectiles
  carry their spec** (`ProjectileStore.spec_key`; `AttackBook` files every spec and hook child by key), so a drone's
  copy, a hook's projectile, a bomb, a patch and a ring each run their own payload and hooks.
- **Saves**: `PAYLOAD_VERSION` 3 (reads 2); a v0.5 carry or snapshot migrates into the slots deterministically
  (`BuildSlots.migrate`: the abilities in slot order, then the attack items in pickup order, the first six kept);
  the ability ids are the modifier ids. `WorldSnapshot.ADDED_SINCE_V05` lets an older snapshot restore (the
  missing fields keep the base's values, per-entry arrays padded). `CatchUp.power` reads the slots' levels.
- **HUD**: `BuildHud` (weapon, utility, six slot pips with levels, family colours) and `SwapPanel` (keyboard 1–6 /
  arrows + Enter / Esc, mouse, pad), each its own node; one line each in `hud.gd`, a 6-line skipped-swap reset in
  `pick_panel.gd`. Patch kinds and rings drawn in `ElementVisuals`. Strings en + es (7 UI, 6 ability descriptions,
  1 dev button). Nothing of the v0.5.9 visual rework touched.

### Items: which became modifiers, which stayed (step 4)
- Modifier cards (take a slot): the 14 MX1 attack items, Razor Orbit (now with its own modifier), Cluster Payload,
  Overclocked Drone, Afterimage (ability mods).
- Stay plain items (no slot), because their effect is not an attack rewrite the ops can express: Bulwark, Phase
  Strike, Thorn Mantle (guard / being hit), Kinetic Dash, Momentum, Swift Feet (dash, movement), Heat Sink,
  Meltdown, Thermal Edge (heat, Vent), Wildfire, Cold Snap (engine numbers: burn spread, slow / chill), Executioner
  (a target-HP multiplier in `Damage.hit`), Vampiric Core (sustain).

### Not done in MX2 (honest list)
- The Skills, Vent and dash do not launch from specs yet (the design's step 2 names them; the Skills already did in
  MX1; Vent's blast and Kinetic Dash's hits keep their v0.5 code).
- Blink's landing shock and Aegis's charges are not specs.
- Cluster Payload, Overclocked Drone and Afterimage are slot cards with their v0.5 code, not op-built modifiers.
- A status a spec inherits with an `every` (Cinder Shot's every-Nth burn) feeds on each hit of a bomb, an orbiter, a
  patch or a ring (the `every` counter is the bolts'); the drone's bolts keep counting as bolts.
- A swap puts the new modifier in the replaced slot's place (the owner may prefer it last).
- A v0.5 build with more than six modifiers loses the ones past six on load (deterministic, documented).
- Owner-only: feel, readability of the fields and rings, the starting values (every 4th attack, 4-kill streak,
  1.6 m field): `OWNER ONLY`.

## Results
NOT YET RUN (filled from the runs below).
