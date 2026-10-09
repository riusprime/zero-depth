# Step MX1: the modifier engine, stage 1 (v0.6.0)

Design: [`../../../design/MODIFIER_ENGINE.md`](../../../design/MODIFIER_ENGINE.md) ("Order of work" step 1). Contracts:
[`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §8b, §9;
[`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md) §2 "Modifiers";
[`PRESENTATION_CONTRACTS.md`](../../../architecture/PRESENTATION_CONTRACTS.md) §4.

## What was built
- `AttackSpec` (form, tags, pattern, size, payload with statuses and elements, behaviour, hooks, depth), `AttackHook`,
  `AttackBook`, `ModifierTable` / `ModifierOp` (sim, `src/sim/combat/`).
- `ModifierDefinition` / `ModifierOpDefinition` (`src/content/defs/`), `data/modifiers/*.tres` (14), discovered by
  `ContentScanner`, validated (`ModifierDefinition.validate`, `cross_check`), compiled by `ModifierCompiler`.
- `Modifiers.compile(w)`: stage order FORM → PATTERN → BEHAVIOUR → PAYLOAD → HOOK → SCALE, pick order inside a stage,
  tag filters, the form-layering rule, hooks compiled to depth 2, the two v0.5 riders. Cached on
  `World.attack_book`, dropped by every build change and by a snapshot restore, its digest in `World.state_hash`
  once the build has a modifier.
- `Attacks.launch(spec, ctx)`: the Blade's four steps, the Twin Arc echo, the Gun's bolt, Lunge Cleave and Scatter
  Blast all launch through it; hooks run under the guard (depth ≤ 2, proc 100 → 50 → 25, ancestry on
  `World.hook_chain`, 256 launches per tick then one `LIMIT`).
- The 14 items that touch those attacks moved into modifier data with their exact numbers (CONTENT_SCHEMA lists
  them); their attack fields left `ItemDefinition` / `ItemTable` / `ItemMods`.
- `AttackView` (presentation): the blade and bolt looks composed from the final specs (form, size, elements, behaviour,
  heat edge via `HeatLooks.attack_color`); the looks are the v0.5 looks. Nothing of the v0.5.9 rework was touched.
- No new card, no new string, no new randomness.

## Equivalence (the point of MX1)
The baseline was recorded **before any engine code**, on `6a83bae` (the lead's head), and committed as `d0af98c`
(`tests/golden/fixtures/modifier_equivalence.json`, generator `tests/golden/generate_modifier_equivalence.gd`,
scenarios `tests/support/attack_scenario.gd`: 22 scripted 900-tick fights, both weapons, each migrated item alone,
the riders, and all together with heat, combos and abilities). The digest covers every event's outcome fields
(seq, tick, kind, source, owner, target, root, parent, depth, amount, applied, tags, position, effect, ancestry) and
the attack state; it leaves out `HIT.proc_pct` (hooks now carry 50) and the new spec digest.

Command (after the engine, on the merged tree at `7f909b8`; the check script is a scratch copy of the test's loop):
```
godot --headless --path . -s <scratchpad>/check_equiv.gd
```
Raw output:
```
EQ| blade_plain same hits=165/165 damage=3208/3208 kills=2/2
EQ| gun_plain same hits=81/81 damage=384/384 kills=0/0
EQ| both_plain same hits=170/170 damage=2822/2822 kills=1/1
EQ| blade_long_edge same hits=189/189 damage=3723/3723 kills=8/8
EQ| blade_twin_arc same hits=276/276 damage=4077/4077 kills=11/11
EQ| blade_ember_edge same hits=131/131 damage=4096/4096 kills=11/11
EQ| blade_overcharge same hits=160/160 damage=4160/4160 kills=14/14
EQ| blade_conductor same hits=233/233 damage=3935/3935 kills=10/10
EQ| blade_serrated_edge same hits=152/152 damage=4063/4063 kills=11/11
EQ| blade_glacial_edge same hits=165/165 damage=3208/3208 kills=2/2
EQ| blade_wildfire_rider same hits=125/125 damage=4160/4160 kills=14/14
EQ| gun_splinter_shot same hits=205/205 damage=509/509 kills=0/0
EQ| gun_rapid_coil same hits=102/102 damage=474/474 kills=0/0
EQ| gun_ricochet_core same hits=87/87 damage=410/410 kills=0/0
EQ| gun_static_chain same hits=107/107 damage=565/565 kills=0/0
EQ| gun_frost_core same hits=81/81 damage=384/384 kills=0/0
EQ| gun_cinder_shot same hits=81/81 damage=688/688 kills=0/0
EQ| gun_barbed_bolts same hits=98/98 damage=635/635 kills=0/0
EQ| gun_glacial_rider same hits=81/81 damage=408/408 kills=0/0
EQ| blade_all same hits=185/185 damage=4160/4160 kills=14/14
EQ| gun_all same hits=469/469 damage=4160/4160 kills=14/14
EQ| both_all same hits=199/199 damage=4160/4160 kills=14/14
EQ| differing: 0
```
The same check is the test `tests/unit/sim/test_modifier_equivalence.gd` (3/3 passed in the full suite below).

## Full suite
Command: `bash /tmp/claude-0/vd.sh <worktree> mx1` (import, gdformat/gdlint, `scripts/verify.sh`), tree at
`7f909b8` (MX1 merged with `claude/lucid-fermat-9wv2tf`), worktree clean. Raw summary:
```
verify exit 0
Tests              1191
Passing Tests      1191
check_gut_log: ok (1191 passing, minimum 1159)
```
From the clean log (`/tmp/claude-0/vd_mx1.clean.log`): `Scripts 191`, `Time 2092.355s`; `test_modifiers.gd`
14/14, `test_modifier_equivalence.gd` 3/3, `test_modifier_smoke.gd` 4/4, `test_modifier_validation.gd` 5/5,
`test_attack_view.gd` 6/6, `test_replay_ground_plane.gd` 2/2 passed.

## Export smoke
Command: `cd /tmp && bash <worktree>/scripts/ci/export_smoke.sh`. Raw output (excerpt, the whole check list):
```
manifest: bf7a04b30450b5b1d26075d42fef3c37abd054f3fc1f6694ea1b79013397ae7d (239 files, 0 errors)
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash bf7a04b30450 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 87
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
exit 0
```

## Goldens
The replay golden and the export-smoke hash did not change (both kernel worlds: no modifier, so the spec digest
stays out of their hash). One new golden on purpose: `tests/golden/fixtures/modifier_equivalence.json` (recorded on
the v0.5 code, see above).

## Known limits (honest list, for MX stage 2)
- A projectile doesn't carry its spec: every player projectile's hit reads the Gun bolt spec's statuses and ON_HIT
  hooks (v0.5's rule, kept exact). A melee hit's statuses read the current combo step spec, so Lunge Cleave keeps
  feeding the Blade's shock / bleed / frost as in v0.5.
- Two v0.5 quirks are kept as riders, not fixed: the Blade burns with Wildfire or Flame Trail and no Ember Edge; the
  bolt slows with Glacial Edge or Cold Snap and no Frost Core.
- `HIT.proc_pct` is 50 on Overcharge's shockwave and Static Chain's jump (was 100). Nothing reads it in MX1 except a
  hook attack's own statuses (none in shipped data).
- Forms RING, ZONE, ORBITER, LOB have no runner yet; `ON_END` runs for arcs and bursts only (a bolt's end needs its
  spec, MX stage 2).
- The combinatorial smoke test covers singles (with replay), all pairs (120 ticks) and all-at-once on Blade and Gun.
  It applies each modifier alone (without its item's engine numbers). No bot, no balance (P1).
- Not done (out of MX1 scope): the 6 slots and Swap, the old abilities as modifiers, M1–M30, the form / element art,
  the momentum / executioner / bulwark / dash / heat items as modifiers.
- Owner-only: feel, "same as before" on their hardware: `OWNER ONLY`.
