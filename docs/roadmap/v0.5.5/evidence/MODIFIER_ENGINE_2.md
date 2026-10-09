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

## Tests added or changed
- New: `tests/unit/sim/test_build_slots.gd` (16: what takes a slot, pick order = compile order, level-up without a
  slot, utility and stat cards outside, the 7th modifier's swap in place, the GRANT swap and its skip, the altar's
  swap and skip back to the cards, the shop's swap paid only on the answer, salvage, a v0.5 carry's migration
  (twice, equal), a carry with slots, a snapshot round trip with equal hashes and a pending swap, a snapshot without
  the MX2 fields migrating, CatchUp per modifier level); `tests/unit/sim/test_modifier_abilities.gd` (9: every
  ability spec's numbers at L1–L5 equal its v0.5 numbers; Bomb Lobber's 4th attack and 22 damage; a bomb burning
  with the Blade's Ember Edge; the drone's copy of a ricochet Gun and its keyed bolts; orbit touches 8 and Razor
  Orbit's bleed; Arc Field's field 12; Frost Nova's frost element and ring 10; Flame Trail from the dash and from a
  bolt's end; the six together replay); `tests/e2e/test_e2e_swap.gd` (4, through `main.tscn`: Swap by keyboard
  3 + Enter, by a mouse click, by pad d-pad + A then a skip with B, a skip with Esc that doesn't pause).
- Extended: `test_modifier_smoke.gd` (+4: every shipped modifier with the six ability modifiers at L3 on each weapon,
  replayed; every form (LOB, ZONE, RING, ORBITER, BURST, BEAM) as an ON_HIT and an ON_KILL hook, replayed; every form
  as a first and a second layer (8 × 4) on each weapon; the ability specs carry the weapon). Mechanics only, no bot.
- Updated for the new rules: `test_abilities.gd`, `test_abilities_ab.gd` (Arc Field, Frost Nova, Flame Trail
  rewritten to their MX2 triggers with the v0.5 numbers), `test_card_pool.gd`, `test_offers.gd`, `test_shop.gd`,
  `test_rewards.gd`, `test_modifier_validation.gd`, `test_e2e_abilities.gd` and `test_e2e_abilities_ab.gd` (the player
  attacks and dashes while waiting), `test_e2e_combo.gd` (its helper fills the slots: it swaps out an item not of
  the pair).

## Goldens
- `tests/golden/fixtures/modifier_equivalence.json`, changed on purpose: the two cases that hold abilities changed
  because the abilities are now weapon modifiers (blade_all with Flame Trail and Orbit Blades, gun_all with Drone
  Buddy and Arc Field). The other 20 cases still match their v0.5 recording. Command and raw output:
  ```
  godot --headless --path . -s tests/golden/generate_modifier_equivalence.gd
  GOLD| blade_all 548a3bde866f5502e390926af9ae80e3c768225982974340a80cba16c46c48ef hits=135 damage=4160 kills=14
  GOLD| gun_all ce0f34c75d4f3ff4d0eb5d6d12b685e68aadca8a9246bceae3d8f5fd74c1a516 hits=472 damage=4160 kills=14
  ```
  (was blade_all `7fc5eac5…` hits 185, gun_all `973bc961…` hits 469; `git diff` of the fixture: those 4 lines only).
  The equivalence digest now leaves out the projectiles' spec keys (outcomes only), as it left out the spec digest.
- The replay golden and the export-smoke hash did not change (`test_replay_ground_plane` 2/2; export smoke "600-tick
  World run hash e5365ddb6dcb matches").

## Full suite
Command: `bash /tmp/claude-0/vd.sh <worktree> mx2` (import, gdformat/gdlint, `scripts/verify.sh`) on `094a8e4` (MX2
merged with `claude/lucid-fermat-9wv2tf` at `977de38`: CU, UI, SR), worktree clean. Raw summary:
```
verify exit 0
Tests              1253
Passing Tests      1253
check_gut_log: ok (1253 passing, minimum 1218)
```
From the clean log (`/tmp/claude-0/vd_mx2.clean.log`): `Scripts 198`, `Time 2175.949s`; 0 "SCRIPT ERROR", 0
"Ignoring script"; `test_build_slots.gd` 16/16, `test_modifier_abilities.gd` 9/9, `test_modifier_smoke.gd` 8/8,
`test_modifier_equivalence.gd` 3/3, `test_e2e_swap.gd` 4/4, `test_abilities_ab.gd` 26/26, `test_e2e_abilities.gd`
2/2, `test_e2e_combo.gd` 1/1, `test_replay_ground_plane.gd` 2/2 passed. MIN_TEST_COUNT 1218 → 1253.

An earlier full run on `688a70e` (before the last fixes and merge) was 1244/1249: the arch layering test (the two new
HUD nodes named the sim's `BuildSlots`; now `WorldReader.MOD_SLOTS`), the modifier count in
`test_modifier_validation` (16, two tests), `test_e2e_combo` (its helper's held items now fill the slots) and
`test_e2e_damage_soak` (an orphan `PanelContainer` in `SwapPanel`); all fixed in `b2fa406`.

## Export smoke
Command: `cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh` (on `094a8e4`). Raw output (the check list):
```
manifest: b22f3301eada451b08db0146544739c75898bf676d808c7af92596398eafa8c1 (248 files, 0 errors)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash b22f3301eada matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is Play / Jugar
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```
exit 0.

## Owner only
Feel, whether the swap should put the new card last instead of in place, the starting values (every 4th attack, the
4-kill streak, the 1.6 m field), how the fields and rings read on screen: `OWNER ONLY`.
